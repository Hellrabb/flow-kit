# TASK: L2 PreToolUse Dispatch — 阶段切换时前置触发 L2 独立审查

- **Change ID**: `l2-pretooluse-dispatch`
- **关联**: `@.specs/l2-pretooluse-dispatch/REQUIREMENT.md`、`@.specs/l2-pretooluse-dispatch/DESIGN.md`

---

## 波次划分

```
Wave 1 (parallel): T01[P], T02[P], T08[P], T09[P]
Wave 2:            T03 (depends on T01)
Wave 3:            T04 (depends on T02, T03)
Wave 4 (parallel): T05[P], T06[P] (depends on T04 and T03 respectively)
Wave 5:            T10 (depends on T08, T09)
Wave 6:            T07 (depends on T04, T05, T06, T10)
```

> 同 wave = 可并行；跨 wave = 必须顺序执行。

---

## 任务清单

```xml
<task id="T01" parallel="true" status="pending">
  <name>新增 l2_dispatch_agent() 到 l2-detect.sh — Agent 自动派发函数</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l2-detect.sh
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    flow-kit/prompts/independent/L2-blind-review.md
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/l2-detect.sh
  </write_files>
  <action>
    在 l2-detect.sh 中新增 l2_dispatch_agent(phase, change_id, specs_dir) 函数：

    1. 函数签名：接收 phase / change_id / specs_dir 三个参数
    2. Agent prompt 构造：固化 heredoc 模板，内容与 L2-blind-review.md 一致（四要素+严重度+阶段 checklist）
       — 模板顶部加注释：# SYNC-POINT: keep aligned with flow-kit/prompts/independent/L2-blind-review.md
    3. API 调用：curl + Anthropic Messages API（参考 l3-review.sh::_l3_call_api() 模式）
       — endpoint: ${ANTHROPIC_BASE_URL:-https://api.anthropic.com}/v1/messages
       — auth: x-api-key: ${ANTHROPIC_API_KEY:-}
       — model: claude-sonnet-5（固化，与其他 L2 审查保持一致）
       — max_tokens: 4096
       — --max-time 90
    4. 异步执行：后台进程 `&>/dev/null & disown`（脱离 hook 进程组）
    5. Agent 输出处理：解析 API 响应中的 content，写入 INDEPENDENT-REVIEW-<phase>.md
       — 追加模式（>>），保留已有 L3 段（遵循 CONTEXT.md 已锁决策：追加写入语义）
    6. 返回码：0 = dispatch 成功触发后台进程，1 = 失败（curl 不可用/API 不可达/凭证缺失/JSON 构造失败）
    7. 日志：dispatch 触发/成功/失败时输出 [l2-dispatch] 前缀 stderr 日志
    8. 环境变量：FLOW_KIT_L2_MOCK=1 时跳过真实 API 调用，使用 mock 响应（供 bats 测试用）
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/lib/l2-detect.sh && source flow-kit-bundle/hooks/stop/lib/l2-detect.sh && type l2_dispatch_agent >/dev/null && echo "OK: function defined"</verify>
  <done>l2_dispatch_agent() 函数可 source 且语法正确；mock 模式下可验证输出</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true" status="pending">
  <name>搭建 bats 测试基础设施 — mock Agent 端点 + 测试辅助函数</name>
  <read_files>
    test/test_gate_integrity.bats
    test/test_l2_l3_granular_gate.bats
    test/l2-detect.bats
    test/fixtures/
  </read_files>
  <write_files>
    test/test_l2_pretooluse_dispatch.bats
    test/fixtures/l2-dispatch/
  </write_files>
  <action>
    创建 bats 测试基础设施：

    1. 新建 test/test_l2_pretooluse_dispatch.bats — 测试文件骨架
       — setup()：source 被测脚本 + 准备 mock 文件
       — teardown()：清理临时文件（.flow-active mock, INDEPENDENT-REVIEW mock）

    2. 新建 test/fixtures/l2-dispatch/ 目录，包含：
       — mock-agent-response.json：模拟 Anthropic API 成功响应（含 L2 盲审报告文本）
       — mock-flow-active-L2.json：gate_config 含 L2 的 .flow-active fixture
       — mock-flow-active-both.json：gate_config 含 both 的 .flow-active fixture
       — mock-flow-active-auto-advance.json：auto_advance=true + gate_config=L2 的 fixture
       — mock-flow-active-no-L2.json：gate_config 不含 L2 的 fixture

    3. 辅助函数（写入 test_helpers.bash 或测试文件内）：
       — setup_mock_gate_env()：准备 mock .flow-active + INDEPENDENT-REVIEW + specs 目录
       — teardown_mock_gate_env()：清理
       — mock_agent_api()：使用 FLOW_KIT_L2_MOCK=1 + 自定义 ANTHROPIC_BASE_URL 指向 mock

    4. 验证 mock 机制：运行一个 smoke test — FLOW_KIT_L2_MOCK=1 下 dispatch 返回 0
  </action>
  <verify>FLOW_KIT_L2_MOCK=1 bats test/test_l2_pretooluse_dispatch.bats --filter 'smoke' 2>&1 | grep -E 'ok [0-9]+'</verify>
  <done>mock 基础设施 smoke test 通过；fixture 文件齐全</done>
  <depends_on></depends_on>
</task>

<task id="T03" status="pending">
  <name>扩展 _gate_check_l2() — auto-dispatch 分支 + auto_advance 检测 + 降级回退</name>
  <read_files>
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    flow-kit-bundle/hooks/stop/lib/l2-detect.sh
    flow-kit-bundle/hooks/stop/lib/common.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
  </write_files>
  <action>
    在 independent-review-gate.sh 的 _gate_check_l2() 函数中扩展以下分支（按执行顺序）：

    0. 保持现有逻辑不变（gate_val 检测 / L2 已完成检测 / FLOW_KIT_SKIP_L2 / skip_marker）
    1. **新增** auto_advance 检测（插入在 FLOW_KIT_SKIP_L2 检测之后、dispatch 之前）：
       — jq -r '.goal.auto_advance // false' .flow-active
       — 若 true → stderr 输出 "[l2-dispatch] auto_advance: L2 missing for phase <N> but not blocking in auto_advance mode"
       — 调用 l2_dispatch_agent() 异步派发
       — return 0（放行，不 exit 2）
    2. **新增** auto-dispatch 分支（替换原有的 l2_dispatch_prompt 直接生成命令）：
       — source l2-detect.sh
       — 调用 l2_dispatch_agent() 尝试自动派发
       — 成功（返回 0）→ stderr: "[l2-dispatch] Agent dispatched for phase <N>"
       — 失败（返回 1）→ **降级**：调用 l2_dispatch_prompt() 输出手动命令 + FLOW_KIT_SKIP_L2=1 指引
    3. exit 2（与现有行为一致）

    改动范围精确限定在 _gate_check_l2 函数内部。不碰 _gate_check_l3 / _gate_phase_transition / is_phase_write / _gate_path_guard。
  </action>
  <verify>
    bash -n flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh &&
    echo "OK: syntax check" &&
    grep -q 'l2_dispatch_agent' flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh &&
    echo "OK: l2_dispatch_agent referenced" &&
    grep -q 'auto_advance' flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh &&
    echo "OK: auto_advance detection present"
  </verify>
  <done>_gate_check_l2() 含 auto_advance 分支 + auto-dispatch 分支 + 降级回退；语法检查通过</done>
  <depends_on>T01</depends_on>
</task>

<task id="T04" parallel="true" status="pending">
  <name>编写 bats 测试 — L2 gate 功能场景（AC-1~AC-5c, AC-9）</name>
  <read_files>
    test/test_l2_pretooluse_dispatch.bats
    test/fixtures/l2-dispatch/*
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
  </read_files>
  <write_files>
    test/test_l2_pretooluse_dispatch.bats
  </write_files>
  <action>
    在 test_l2_pretooluse_dispatch.bats 中添加以下测试用例（每个对应一条 AC）：

    AC-1: gate_config=L2 + INDEPENDENT-REVIEW 缺失 + Bash 写 phase → assert exit 2
    AC-2: gate_config=L2 + INDEPENDENT-REVIEW 已有 L2 段 + Bash 写 phase → assert exit 0
    AC-3: gate_config=both + L2 缺失 + L3 done（合法 .done KVP）→ assert exit 2（仅 L2 拦截）
    AC-4: gate_config=L3（仅 L3）→ L2 检测不触发（不读 INDEPENDENT-REVIEW）
    AC-5a: L2 缺失 → assert stderr 含 [l2-dispatch] 派发标记 + exit 2
    AC-5b: Agent API 不可用（ANTHROPIC_BASE_URL=http://invalid）→ assert stderr 含 l2_dispatch_prompt 命令 + FLOW_KIT_SKIP_L2=1 指引 + exit 2
    AC-5c: FLOW_KIT_L2_MOCK=1 → assert INDEPENDENT-REVIEW 文件被创建含 ## L2 盲审 段
    AC-9: auto_advance=true + gate_config=L2 + L2 缺失 → assert exit 0 + stderr 含 "auto_advance: L2 missing"

    每条测试必须独立（自己的 setup/teardown），不依赖测试执行顺序。
  </action>
  <verify>FLOW_KIT_L2_MOCK=1 bats test/test_l2_pretooluse_dispatch.bats 2>&1 | tail -5</verify>
  <done>全部 9 条场景测试通过（AC-1~AC-5c + AC-9），0 fail</done>
  <depends_on>T02, T03</depends_on>
</task>

<task id="T05" status="pending">
  <name>编写 bats 测试 — 回归场景（AC-6 L3 行为 / AC-7 Stop hook L2）</name>
  <read_files>
    test/test_gate_integrity.bats
    test/test_l2_l3_granular_gate.bats
    test/test_stop_chain.bats
    test/test_l2_pretooluse_dispatch.bats
  </read_files>
  <write_files>
    test/test_l2_pretooluse_dispatch.bats
  </write_files>
  <action>
    在 test_l2_pretooluse_dispatch.bats 中添加回归测试用例：

    AC-6: L3 行为无回归
    — gate_config=L3 + L3 缺失 → assert exit 2（L3 dispatch 正常触发）
    — gate_config=L3 + L3 完成（合法 .done KVP）→ assert exit 0
    — path-guard：Write 写 .flow-active.independent-review 握手文件 → assert exit 2
    — gate_config 篡改检测：改了 gate_config 值 → assert exit 2

    AC-7: Stop hook L2 行为无回归
    — 验证 l2_detect_missing() 函数签名和返回值未变（返回 0=完成, 1=缺失, 2=错误）
    — 验证 l2_dispatch_prompt() 函数仍可正常调用（不受新增 l2_dispatch_agent 影响）

    另外，验证全量回归：
    — test/test_independent_review_gate.bats 全部现有用例通过
    — test/test_stop_chain.bats L2 相关用例通过
  </action>
  <verify>
    bats test/test_gate_integrity.bats test/test_l2_l3_granular_gate.bats 2>&1 | grep -c 'ok' &&
    echo "---" &&
    FLOW_KIT_L2_MOCK=1 bats test/test_l2_pretooluse_dispatch.bats --filter 'regression' 2>&1 | grep -c 'ok'
  </verify>
  <done>L3 gate 回归全绿；Stop hook L2 检测不受影响；gate_integrity + l2_l3_granular_gate 全绿</done>
  <depends_on>T04</depends_on>
</task>

<task id="T06" status="pending">
  <name>验证 install_hooks.sh 兼容性（AC-8）</name>
  <read_files>
    flow-kit-bundle/lib/install_hooks.sh
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
  </read_files>
  <write_files>
    无（仅验证，不需修改）
  </write_files>
  <action>
    验证 install_hooks.sh 的 PreToolUse 接线与本次改动兼容：

    1. 检查现有 matcher "Bash|Write|Edit" 是否覆盖 L2 dispatch 的触发场景
       — AI 写 .flow-active.phase 走 Bash 工具 → matcher 已覆盖 ✅
    2. 检查 independent-review-gate.sh 的安装路径是否不变
       — hook 安装到 .claude/hooks/pre-tool-use/independent-review-gate.sh → 不变
    3. 检查是否需要在 settings.json 新增 PreToolUse hook 条目
       — 本次不新增 hook 脚本，仅在既有脚本中扩展 → 无需新增条目

    若验证通过 → 无需修改 install_hooks.sh。
    若发现问题（如 matcher 不够精确）→ 仅在 install_hooks.sh 中微调 matcher，不新增 hook 条目。
  </action>
  <verify>
    grep -q 'Bash|Write|Edit' flow-kit-bundle/lib/install_hooks.sh &&
    echo "OK: matcher covers Bash/Write/Edit" &&
    grep -q 'independent-review-gate.sh' flow-kit-bundle/lib/install_hooks.sh &&
    echo "OK: independent-review-gate.sh referenced in install"
  </verify>
  <done>install_hooks.sh 兼容性验证通过（或完成必要的微调）；AC-8 满足</done>
  <depends_on>T03</depends_on>
</task>

<task id="T07" status="pending">
  <name>全量回归 + 集成冒烟测试</name>
  <read_files>
    .specs/l2-pretooluse-dispatch/REQUIREMENT.md
    .specs/l2-pretooluse-dispatch/DESIGN.md
    test/
  </read_files>
  <write_files>
    无（纯验证任务）
  </write_files>
  <action>
    最终全量回归验证：

    1. 全量 bats 测试：`make test`（或 `npx bats test/`）
       — 确认 407 测试全绿 / exit 0 / 无新增 fail
       — 重点关注 test_independent_review_gate.bats + test_stop_chain.bats + test_l2_pretooluse_dispatch.bats

    2. 语法检查：
       — bash -n 对所有修改过的 .sh 文件通过

    3. Source 完整性：
       — 确认 l2-detect.sh 可被独立 source（不影响现有 29-independent-review.sh 的调用）

    4. 手动冒烟（dry-run）：
       — 模拟 FLOW_KIT_L2_MOCK=1 下完整 gate 调用链：
         gate_config=L2 + L2 缺失 → _gate_check_l2 → l2_dispatch_agent(mock) → exit 2
       — 验证 stderr 输出包含所有预期标记

    5. CONTEXT.md 禁动清单交叉验证：
       — 确认 write_files 未触碰禁动清单中的任何文件
  </action>
  <verify>
    make test 2>&1 | tail -3 &&
    echo "---" &&
    bash -n flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh &&
    bash -n flow-kit-bundle/hooks/stop/lib/l2-detect.sh &&
    echo "OK: all syntax checks passed"
  </verify>
  <done>make test 全绿 0 fail；全部语法检查通过；禁动清单无越界</done>
  <depends_on>T04, T05, T06, T10</depends_on>
</task>

<!-- ═══════════════════════════════════════════════════════════════ -->
<!-- L3 写入管道修复（合并到本 change · 2026-07-15）                  -->
<!-- ═══════════════════════════════════════════════════════════════ -->

<task id="T08" parallel="true" status="pending">
  <name>修复 _l3_scan_backlog 错误静默吞没 — 去 2>/dev/null + 加错误日志</name>
  <read_files>
    flow-kit-bundle/hooks/stop/29-independent-review.sh
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/29-independent-review.sh
  </write_files>
  <action>
    修复 29-independent-review.sh 中两处 L3 错误静默吞没问题：

    1. **积压扫描器**：`l3_review_run ... 2>/dev/null || true`
       → 改为：去掉 `2>/dev/null`，保留 `|| true`（不阻断 Stop 链），但让 stderr 正常输出到 hooks.log
       → 新增：失败时 `module_output "warning" "IR" "backlog L3 failed for phase ${pn} (rc=${?})——see hooks.log"`

    2. **当前阶段 L3 调用**：`l3_review_run ... 2>/dev/null && rc=0 || rc=$?`
       → 改为：去掉 `2>/dev/null`，保留 rc 捕获逻辑
       → l3_review_run 内部的 stderr（API 错误、文件写入错误）可正常落到 hooks.log

    注意：`_l3_write_done()` 的写入后验证改造由 T09 负责（在 l3-review.sh 中统一处理）。
  </action>
  <verify>
    bash -n flow-kit-bundle/hooks/stop/29-independent-review.sh &&
    ! grep -n '2>/dev/null || true' flow-kit-bundle/hooks/stop/29-independent-review.sh | grep -q 'l3_review_run' &&
    echo "OK: no silent error suppression on l3_review_run calls" &&
    grep -q 'module_output.*backlog.*L3.*failed' flow-kit-bundle/hooks/stop/29-independent-review.sh &&
    echo "OK: backlog failure logging added" &&
    grep -q 'see hooks.log' flow-kit-bundle/hooks/stop/29-independent-review.sh &&
    echo "OK: hooks.log reference in error message"
  </verify>
  <done>l3_review_run 调用的 stderr 不再被吞；backlog 失败有 module_output 记录</done>
  <depends_on></depends_on>
</task>

<task id="T09" parallel="true" status="pending">
  <name>修复 L3 内容持久化竞态 — 原子写入替代裸 >> 追加</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
  </write_files>
  <action>
    修复 L3 内容写入与主 agent Edit 操作的竞态条件：

    1. **当前问题**：`l3-review.sh` 用 `} >> "$review_md"` 直接追加 L3 段。
       若主 agent 随后在同一文件上做 Edit（字符串匹配替换），L3 段可能因锚点文本变化而丢失。

    2. **原子写入**：改为 temp-file + mv 流程：
       a. 读当前文件内容到变量
       b. 追加 L3 段到变量末尾
       c. `echo "$content" > "${review_md}.tmp" && mv "${review_md}.tmp" "$review_md"`

    3. **写入后验证**：mv 后立即 `grep -q "^## L3 盲审" "$review_md"` → 失败则 `echo "[l3-review] CRITICAL: L3 content not persisted after write" >&2`，返回 rc=3

    4. **.done 同样原子化**：`cat > "${done_marker}.tmp" ... && mv "${done_marker}.tmp" "$done_marker"`

    5. **_l3_write_done() 防御**：写 .done 前检查 `[ -f "$review_md" ] && grep -q "^## L3 盲审" "$review_md"` → 未写入则 `module_output "error"` 并跳过 .done 写入
  </action>
  <verify>
    bash -n flow-kit-bundle/hooks/stop/lib/l3-review.sh &&
    grep -q '\.tmp.*mv' flow-kit-bundle/hooks/stop/lib/l3-review.sh &&
    echo "OK: atomic write pattern (tmp + mv) present" &&
    grep -q 'L3 content not persisted' flow-kit-bundle/hooks/stop/lib/l3-review.sh &&
    echo "OK: post-write verification added" &&
    grep -q 'grep.*L3 盲审.*review_md' flow-kit-bundle/hooks/stop/lib/l3-review.sh &&
    echo "OK: _l3_write_done pre-check added"
  </verify>
  <done>L3 内容使用原子写入（tmp+mv）；写入后有 grep 验证；.done 同样原子化</done>
  <depends_on></depends_on>
</task>

<task id="T10" status="pending">
  <name>编写 bats 测试 — L3 写入管道完整性</name>
  <read_files>
    test/test_l2_l3_fix_compliance.bats
    test/test_gate_integrity.bats
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
  </read_files>
  <write_files>
    test/test_l2_pretooluse_dispatch.bats
  </write_files>
  <action>
    在 test_l2_pretooluse_dispatch.bats 中添加 L3 写入管道测试：

    1. **T08 验证**：模拟 backlog 扫描 + l3_review_run 失败 → assert hooks.log 含 `[backlog]` 错误日志
    2. **T09 验证**：
       — 模拟 L3 写入 → assert INDEPENDENT-REVIEW 文件含 L3 段（`^## L3 盲审`）
       — 模拟并发写入场景：写入 L3 段后立即做一次 Edit → assert L3 段仍存在（原子写入防竞态）
       — 模拟 .done 写入 → assert .done 文件存在且含 6 键 KVP
    3. **回归验证**：
       — test_l2_l3_fix_compliance.bats 全绿
       — test_gate_integrity.bats 全绿
  </action>
  <verify>
    FLOW_KIT_L2_MOCK=1 bats test/test_l2_pretooluse_dispatch.bats --filter 'L3-pipeline' 2>&1 | tee /dev/stderr | grep -q '0 failures' &&
    echo "OK: L3 pipeline tests 0 failures" &&
    echo "---" &&
    bats test/test_l2_l3_fix_compliance.bats 2>&1; EC1=$? &&
    bats test/test_gate_integrity.bats 2>&1; EC2=$? &&
    [ $EC1 -eq 0 ] && echo "OK: fix_compliance regression 0" || echo "WARN: fix_compliance exit $EC1" &&
    [ $EC2 -eq 0 ] && echo "OK: gate_integrity regression 0" || echo "WARN: gate_integrity exit $EC2"
  </verify>
  <done>L3 写入管道测试通过；原子写入防竞态验证通过；回归 bats exit 0</done>
  <depends_on>T08, T09, T04</depends_on>
</task>
```

---

## 状态字段说明

- `status="pending"` — 未开始
- `status="in_progress"` — 进行中（同时只允许一个非 [P] 任务为此状态）
- `status="done"` — 已完成（verify 通过）
- `status="blocked"` — 阻塞（必须在文件末尾「阻塞日志」记录）

---

## 阻塞日志

| 任务 | 阻塞原因 | 待人工决策项 | 时间 |
|---|---|---|---|
|  |  |  |  |

---

## Fix 任务（来自 REVIEW / INTEGRATION）

> 此区域由 review/integration 阶段自动追加，编号 `T-FIX-XX`。

```xml
<!-- 占位 -->
```
