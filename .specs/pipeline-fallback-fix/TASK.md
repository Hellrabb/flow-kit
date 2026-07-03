# TASK: 修复 pipeline 诊断发现的全部问题

- **Change ID**: pipeline-fallback-fix
- **关联**: `@.specs/pipeline-fallback-fix/REQUIREMENT.md`、`@.specs/pipeline-fallback-fix/DESIGN.md`

---

## 波次划分

```
Wave 1 (parallel): T01[P], T04[P], T05[P], T07[P]   （独立文件，互不依赖）
Wave 2 (parallel): T02[P] (dep T01), T03[P] (dep T01), T06[P] (dep T05), T09[P]
Wave 3:            T08                               （dep T06, T07 概念依赖）
```

---

## 任务清单

```xml
<task id="T01" parallel="true" status="pending">
  <name>新建 l3-review.sh 共享 lib（L3 API 调用抽取）</name>
  <read_files>
    flow-kit-bundle/hooks/stop/29-independent-review.sh（L3 API 代码提取源）
    flow-kit-bundle/hooks/stop/lib/common.sh（共享常量/函数）
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
  </write_files>
  <action>
    从 29-independent-review.sh 中提取 L3 API 调用逻辑，新建 l3-review.sh：
    - 函数 l3_review_run(phase, change_id, artifacts_dir, L2_verdict)：执行 L3 审查 → 写 INDEPENDENT-REVIEW-<N>.md L3 段 → 写完整 6 键 .done 文件
    - 函数 l3_review_with_timeout()：timeout 30s 降级 wrapper
    - 沿用既有 ANTHROPIC_BASE_URL + ANTHROPIC_AUTH_TOKEN + ANTHROPIC_DEFAULT_HAIKU_MODEL 环境变量（DESIGN §0.5.2 沿用对照表）
    - L3_verdict 取值: pass|fail|timeout|error（AC-1a AC-1b）
    - .done 写入用原子操作（先写 .tmp 再 mv，AC NFR 可靠性要求）
    见 DESIGN D1/D2 + ADR-002。
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/lib/l3-review.sh && grep -q "l3_review_run()" flow-kit-bundle/hooks/stop/lib/l3-review.sh && grep -q "l3_review_with_timeout()" flow-kit-bundle/hooks/stop/lib/l3-review.sh</verify>
  <done>l3-review.sh 语法正确，含 l3_review_run + l3_review_with_timeout 两个公共函数，L3_verdict 枚举值完整（AC-1c, AC-1a）</done>
  <depends_on></depends_on>
</task>

<task id="T04" parallel="true" status="pending">
  <name>/flow gate-config + /flow goal --gate-config 快照同步</name>
  <read_files>
    ~/.claude/skills/flow/SKILL.md（/flow gate-config 段 + /flow goal --pipeline 段）
    .flow-active（参考当前 gate_config 结构）
    .specs/pipeline-fallback-fix/.goal-snapshot.json（参考快照格式）
  </read_files>
  <write_files>
    flow-kit-bundle/skills/flow/SKILL.md（或 ~/.claude/skills/flow/SKILL.md）
  </write_files>
  <action>
    修改 flow skill 的两处 jq 命令：
    1. /flow gate-config <phase>=<value>：在更新 .flow-active.goal.gate_config 后，追加 jq 同步更新 .specs/<id>/.goal-snapshot.json
    2. /flow goal --pipeline --gate-config <VALUE>：在写入 goal 后，确认 .goal-snapshot.json 同步写入（与现有 snapshot 写入逻辑合并）
    单一写入点原则：skill 负责同步，hook D8 ⑥ 只检测不修复（DESIGN D3/D4）
    见 DESIGN D3/D4。
  </action>
  <verify>bash -n ~/.claude/skills/flow/SKILL.md 2>/dev/null; grep -c "goal-snapshot.json" ~/.claude/skills/flow/SKILL.md | xargs echo "snapshot 引用次数:"</verify>
  <done>/flow gate-config 和 /flow goal --gate-config 均引用 .goal-snapshot.json 路径（AC-2, AC-2a）</done>
  <depends_on></depends_on>
</task>

<task id="T05" parallel="true" status="pending">
  <name>flow-kit-artifacts.sh: .done 6键统一 + Tier1 补 L2/L3_verdict + artifacts 检查</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh（fk_validate_done_marker() 函数）
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh
  </write_files>
  <action>
    修改 fk_validate_done_marker() 函数：
    - MIN_MEANINGFUL_LINES 从 3 提升到 6（AC-7 要求 6 键）
    - Tier1 KVP 检查扩充为 6 键：phase= / change_id= / written_by= / L2_verdict= / L3_verdict= / artifacts=
    - L2_verdict 值合法性：枚举 {pass, fail}
    - L3_verdict 值合法性：枚举 {pass, fail, timeout, error}
    - artifacts= 至少含 1 个逗号分隔文件名（非空）
    - 缺任一键 → return 2（校验失败，输出具体缺失键名）
    见 DESIGN D10/D11/D12 + AC-7/AC-7a/AC-8/AC-8a。
  </action>
  <verify>npx bats test/test_flow_artifacts.bats --filter "done" 2>/dev/null || echo "(manual verify: 构造 6键 .done → fk_validate_done_marker → 确认返回0; 构造缺 artifacts= .done → 确认返回2)"</verify>
  <done>fk_validate_done_marker() Tier1 检查 6 键（含 artifacts/L2_verdict/L3_verdict），缺键返回 2（AC-7, AC-7a, AC-8, AC-8a）</done>
  <depends_on></depends_on>
</task>

<task id="T07" parallel="true" status="pending">
  <name>新建 32-fallback-guard.sh（Fallback hook 兜底）</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/common.sh（共享常量/函数）
    .flow-active（goal 结构参考）
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/32-fallback-guard.sh
  </write_files>
  <action>
    新建 32-fallback-guard.sh Stop hook 模块：
    - 检测 goal.mode == "fallback" → 否则跳过（exit 0）
    - 检测 goal.scope == "pipeline" → 否则跳过
    - 检测 current_phase == "7" → 否则跳过（中间阶段不触发，见 REQUIREMENT 覆盖边界声明）
    - 检查 phase 7 PCSC 全✅（硬编码产物清单比对，见 DESIGN D8）
    - 满足 → jq 更新 goal.status = "done"
    见 DESIGN D8 + AC-5/AC-5a。
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/32-fallback-guard.sh && grep -q "fallback" flow-kit-bundle/hooks/stop/32-fallback-guard.sh && grep -q "goal.status" flow-kit-bundle/hooks/stop/32-fallback-guard.sh</verify>
  <done>32-fallback-guard.sh 语法正确，检测 fallback+phase7 → 自动标记 done（AC-5, AC-5a）</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true" status="pending">
  <name>independent-review-gate.sh: L3 前置 + 三向 gate 方向判定</name>
  <read_files>
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh（当前实现）
    flow-kit-bundle/hooks/stop/lib/l3-review.sh（T01 产出 · l3_review_run 函数签名）
    flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh（fk_validate_done_marker 函数）
    .flow-active（goal 结构参考）
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
  </write_files>
  <action>
    修改 independent-review-gate.sh：
    1.【F1 L3前置】在 transition 拦截分支中（前进 + gate开启 + L2完成 + L3未完成）：source l3-review.sh → 调用 l3_review_run() → 写 L3段 + .done → 放行（AC-1）
    2.【F3 方向判定】重写 is_phase_write() 为三向判定：回退放行 / no-op放行（含空值守卫） / 前进查 gate（AC-3/AC-3a/AC-3b + DESIGN §3.1 状态机）
    3.【D8 ⑥ 保留】gate_config snapshot 一致性检查不变（仅修复同步源在 T04）
    见 DESIGN D1/D2/D5 + §2.1/§2.3 数据流图。
  </action>
  <verify>bash -n flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh && grep -q "l3-review.sh" flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh && grep -q "ROLLBACK\|rollback\|回退" flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh</verify>
  <done>independent-review-gate.sh 含 L3前置调用 + 三向方向判定 + 空值守卫（AC-1, AC-3, AC-3a, AC-3b）</done>
  <depends_on>T01</depends_on>
</task>

<task id="T03" parallel="true" status="pending">
  <name>29-independent-review.sh: 切换为 l3_review_run 共享函数</name>
  <read_files>
    flow-kit-bundle/hooks/stop/29-independent-review.sh（当前实现）
    flow-kit-bundle/hooks/stop/lib/l3-review.sh（T01 产出 · l3_review_run 函数签名）
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/29-independent-review.sh
  </write_files>
  <action>
    修改 29-independent-review.sh：
    - 删除内联 L3 API 调用代码（已抽取到 T01 的 l3-review.sh）
    - source l3-review.sh → 调用 l3_review_run(phase, change_id, artifacts_dir, L2_verdict)
    - 兜底逻辑不变：检测 L2 已完成 + L3 缺失 → 补跑 L3（AC-1b）
    - 去除内联的 .done 写入逻辑（l3_review_run 已负责写入完整 .done）
    见 DESIGN D1/D2 + ADR-002 + AC-1b。
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/29-independent-review.sh && grep -q "l3-review.sh" flow-kit-bundle/hooks/stop/29-independent-review.sh && grep -q "l3_review_run" flow-kit-bundle/hooks/stop/29-independent-review.sh</verify>
  <done>29-independent-review.sh 改用 l3_review_run 共享函数，兜底逻辑保留（AC-1b, AC-1c）</done>
  <depends_on>T01</depends_on>
</task>

<task id="T06" parallel="true" status="pending">
  <name>新建 31-auto-advance.sh（auto_advance hook 兜底 + gate 意识）</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh（fk_validate_done_marker 函数 · T05 修改后版本）
    flow-kit-bundle/hooks/stop/lib/common.sh（共享常量/函数）
    .flow-active（goal.auto_advance / current_phase 字段参考）
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/31-auto-advance.sh
  </write_files>
  <action>
    新建 31-auto-advance.sh Stop hook 模块：
    - 检测 goal.auto_advance == true → 否则跳过（AC-4b）
    - 检测 current_phase ∈ {4,5,6,7} → 否则跳过
    - 检查 PCSC 全✅（硬编码产物清单比对，见 DESIGN D7 + PCSC 参照路径注释）
    - 【gate 意识 · DESIGN R2修复】若 gate_config 对当前阶段开启：调用 fk_validate_done_marker() 检查 .independent-review-<N>.done → 无效则跳过并输出告警
    - 全部满足 → 执行 transition jq（格式与各 prompt toll-gate 段一致，见 DESIGN §2.4）
    见 DESIGN D6/D7 + §2.4 数据流 + AC-4/AC-4a/AC-4b。
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/31-auto-advance.sh && grep -q "auto_advance" flow-kit-bundle/hooks/stop/31-auto-advance.sh && grep -q "fk_validate_done_marker\|independent-review.*done" flow-kit-bundle/hooks/stop/31-auto-advance.sh</verify>
  <done>31-auto-advance.sh 语法正确，含 gate 意识检查 + PCSC 硬编码清单 + 参照路径注释（AC-4, AC-4a, AC-4b）</done>
  <depends_on>T05</depends_on>
</task>

<task id="T09" parallel="true" status="pending">
  <name>install_hooks.sh + stop-hook.json: 注册 31/32 号模块</name>
  <read_files>
    flow-kit-bundle/lib/install_hooks.sh（HOOK_MODULE_NAMES 数组）
    flow-kit-bundle/hooks/stop/（确认 31/32 文件已存在）
    ~/.claude/stop-hook.json（或项目 .claude/stop-hook.json，模块配置参考）
  </read_files>
  <write_files>
    flow-kit-bundle/lib/install_hooks.sh
  </write_files>
  <action>
    1. 在 install_hooks.sh 的 HOOK_MODULE_NAMES 数组中追加 "31-auto-advance" 和 "32-fallback-guard"（放在 30-ai-analyze 之后）
    2. 确认 hook 模块执行顺序：29 → 30 → 31 → 32（编号天然排序）
    3. 如项目有 stop-hook.json 且含模块开关，同步更新
    见 DESIGN §0.5.1 编号依赖注释。
  </action>
  <verify>grep -c "31-auto-advance\|32-fallback-guard" flow-kit-bundle/lib/install_hooks.sh | xargs echo "模块注册命中次数:"</verify>
  <done>install_hooks.sh 含 31/32 模块注册，编号顺序 29→30→31→32（DESIGN §0.5.1 依赖注释）</done>
  <depends_on></depends_on>
</task>

<task id="T08" status="pending">
  <name>GO.md mode 路由 + 4-dev.md fallback 段去重</name>
  <read_files>
    ~/.claude/flow-kit/GO.md（当前路由逻辑）
    ~/.claude/flow-kit/prompts/4-dev.md（fallback 迭代段 + auto_advance 段）
    flow-kit-bundle/hooks/stop/31-auto-advance.sh（T06 产出 · 确认 hook 能力边界）
    flow-kit-bundle/hooks/stop/32-fallback-guard.sh（T07 产出 · 确认 hook 能力边界）
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/GO.md
    flow-kit-bundle/flow-kit/prompts/4-dev.md
  </write_files>
  <action>
    1.【GO.md mode 路由】在 GO.md "第二步 · 解析用户意图，路由到阶段" 中添加：检测 goal.mode == "fallback" → 在 4/5/6/7 阶段路由时加载 fallback 迭代指令段（含 turns 自检 + 每 turn 条件评估 + 20 turns 上限）。新增 "§ Fallback 路由" 段（~20 行），作为 fallback 迭代逻辑的单一源。
    2.【4-dev.md 去重】删除 4-dev.md 中 fallback 迭代循环的完整描述（~30 行），替换为 `@see GO.md § Fallback 路由` 引用（2 行）。保留 4-dev 的 auto_advance 分支和 PCSC 逻辑不变。
    见 DESIGN D9 + AC-6/AC-6a。
  </action>
  <verify>grep -c "fallback\|Fallback" flow-kit-bundle/flow-kit/GO.md | xargs echo "GO.md fallback 引用:"; grep -c "@see.*GO.md\|@see.*Fallback" flow-kit-bundle/flow-kit/prompts/4-dev.md | xargs echo "4-dev.md @see 引用:"</verify>
  <done>GO.md 含 fallback 路由段（≥3 处 mode 引用），4-dev.md fallback 迭代改为 @see 引用（AC-6, AC-6a）</done>
  <depends_on></depends_on>
</task>
```

---

## 状态字段说明

- `status="pending"` — 未开始
- `status="in_progress"` — 进行中
- `status="done"` — 已完成（verify 通过）
- `status="blocked"` — 阻塞

---

## 阻塞日志

| 任务 | 阻塞原因 | 待人工决策项 | 时间 |
|---|---|---|---|
|  |  |  |  |

---

## Fix 任务（来自 REVIEW / INTEGRATION）

```xml
<!-- 占位 -->
```
