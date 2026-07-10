# TASK: 2026-07-10 Full Sweep 统一清理

- **Change ID**: `sweep-fix-2026-07-10`
- **关联**: `@.specs/sweep-fix-2026-07-10/REQUIREMENT.md`、`@.specs/sweep-fix-2026-07-10/DESIGN.md`

---

## 波次划分

```
Wave 1 (parallel):  T01[P], T02[P], T03[P], T04[P]
Wave 2:             T05 → T06[P]
                      (T06 depends on T05 — run_check() must exist before modules migrate)
Wave 3:             T07
                      (CONTEXT.md + CHANGE.md update after all code changes stable)
```

---

## 任务清单

```xml
<task id="T01" parallel="true" status="pending">
  <name>AC-4: 移除 write_failed_state 死代码</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/common.sh
    flow-kit-bundle/hooks/stop/lib/*.sh
    .specs/CONTEXT.md
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/common.sh
  </write_files>
  <action>
    从 common.sh 移除 write_failed_state() 函数定义（L135-159，21 行死代码）。
    全仓 0 调用已确认（grep 验证）。
  </action>
  <verify>grep -r "write_failed_state" flow-kit-bundle/ --include="*.sh" | grep -v "CONTEXT\|CHANGE\|DESIGN" ; [ $? -eq 1 ] &amp;&amp; echo "PASS: write_failed_state fully removed"</verify>
  <done>AC-4: write_failed_state 定义已从 common.sh 移除；grep 确认全仓 0 残留引用</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true" status="pending">
  <name>AC-1: 拆分 l3_review_run() 为 4 子函数 + 编排器</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    flow-kit-bundle/hooks/stop/lib/common.sh
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    flow-kit-bundle/hooks/stop/29-independent-review.sh
    .specs/ARCHITECTURE.md
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
  </write_files>
  <action>
    按 DESIGN D1 + ADR-001 拆分 l3_review_run()（当前 L160-463，305 行）：
    1. 提取 _l3_build_prompt(phase, change_id, artifacts_dir, max_chars) — L178-262 prompt 构造
    2. 提取 _l3_call_api(prompt_text, model) — L264-296 API 调用 + 响应解析
    3. 提取 _l3_parse_result(content, phase, review_md) — L298-411 重审检测 + verdict 提取（通过 stdout 返回 VERDICT= + SUMMARY=）
    4. 提取 _l3_write_done(phase, change_id, verdict, summary, l2_verdict, artifacts_dir, gate_config_value, model) — L413-463 .done 写入（遵守 ARCHITECTURE.md §4.1 6键KVP格式）
    5. l3_review_run() 重写为编排器 ≤50 行，签名不变
    子函数间数据传递：stdout 捕获（ADR-001）。
    l3_review_with_timeout / l3_dispatch_prompt / l3_write_timeout_done / _l3_format_result / smart_truncate 不变。
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/lib/l3-review.sh &amp;&amp; npx bats test/test_l3_review.bats test/test_fix_l3_gate.bats test/test_l2_l3_fix_compliance.bats</verify>
  <done>AC-1: l3_review_run ≤50 行；4 子函数各 ≤80 行；L3 相关 bats 全绿</done>
  <depends_on></depends_on>
</task>

<task id="T03" parallel="true" status="pending">
  <name>AC-7: 创建 DRY_RUN 安装测试</name>
  <read_files>
    flow-kit-bundle/lib/install_hooks.sh
    flow-kit-bundle/lib/install_brooks.sh
    flow-kit-bundle/lib/install_core.sh
    test/test_install.bats
    test/test_install_brooks_tools.bats
  </read_files>
  <write_files>
    test/test_install_dry_run.bats
  </write_files>
  <action>
    创建 test/test_install_dry_run.bats，≥4 条测试：
    1. install_hooks DRY_RUN: 验证不修改 settings.json（sha256 before/after 一致）
    2. install_hooks DRY_RUN: 验证输出包含 [DRY-RUN] 消息
    3. install_brooks_lint DRY_RUN: 验证不产生文件复制
    4. install_brooks_lint DRY_RUN: 验证输出包含预期消息
    setup/teardown 参考 test_install.bats 的路径查找模式。
  </action>
  <verify>npx bats test/test_install_dry_run.bats</verify>
  <done>AC-7: ≥4 条 DRY_RUN 测试全绿；覆盖副作用 + 输出内容双重验证</done>
  <depends_on></depends_on>
</task>

<task id="T04" parallel="true" status="pending">
  <name>AC-2: 重构 independent-review-gate.sh — 提取 7 _gate_* + _run_review_gates()</name>
  <read_files>
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    flow-kit-bundle/hooks/stop/lib/common.sh
    flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    flow-kit-bundle/hooks/stop/lib/done-validation.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
  </write_files>
  <action>
    按 DESIGN D2 + ADR-002 重构 independent-review-gate.sh 主逻辑体（L106-391，~285 行）：
    1. 提取 _gate_path_guard(tool_name, file_path, cmd) — ~18 行
    2. 提取 _gate_phase_filter(flow_file) — ~9 行，stdout 返回 PHASE= + CHANGE_ID=
    3. 提取 _gate_active_check(phase) — ~7 行
    4. 提取 _gate_done_validation(done_marker, phase, change_id) — ~7 行
    5. 提取 _gate_tamper_detect(flow_file, snapshot_file) — ~11 行
    6. 提取 _gate_phase_transition(cmd, phase, change_id, cwd) — ~179 行（L2/L3 派发，不进一步拆分，ADR-002）
    7. 提取 _gate_deny_reason(cmd, phase, change_id, cwd, done_marker) — ~18 行
    8. 新增 _run_review_gates() 编排器 ≤40 行
    9. 精简主入口块为 ~20 行（stdin 解析 + 调用 _run_review_gates）
    辅助谓词函数（L23-103）保持不变：is_handshake_write / fk_check_gate_config_tamper / is_phase_write / _fk_phase_direction / is_git_commit / is_gh_pr_create（3行谓词不拆）。
    Gate 检查顺序严格不变（禁动清单要求）。
  </action>
  <verify>bash -n flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh &amp;&amp; npx bats test/test_gate_integrity.bats test/test_phase_gate.bats test/test_gate_config_presets.bats</verify>
  <done>AC-2: _run_review_gates ≤40 行；≥7 个 _gate_* 函数；gate 相关 bats 全绿</done>
  <depends_on></depends_on>
</task>

<task id="T05" status="pending">
  <name>AC-3: common.sh 添加 run_check() 包装函数</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/common.sh
    flow-kit-bundle/hooks/stop/20-claude-md.sh
    .specs/CONTEXT.md
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/common.sh
  </write_files>
  <action>
    按 DESIGN D3 + ADR-003/004 在 common.sh 添加 run_check()：
    - 位置：紧接 check_enabled() 之后（L41 后）
    - 签名：run_check(module, check_id, precondition_file, body_fn)
    - 逻辑：check_enabled guard → 可选文件 precondition → 调用 $body_fn
    - precondition_file 为空字符串时跳过文件检查
    不添加 precondition_cmd 参数（YAGNI, ADR-003）。
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/lib/common.sh &amp;&amp; ( source flow-kit-bundle/hooks/stop/lib/common.sh &amp;&amp; type run_check &amp;&amp; echo "run_check defined OK" )</verify>
  <done>common.sh 含 run_check() 函数定义，语法检查通过</done>
  <depends_on>T01</depends_on>
</task>

<task id="T06" parallel="true" status="pending">
  <name>AC-3: 6 模块 check_* 迁移到 run_check()</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/common.sh
    flow-kit-bundle/hooks/stop/20-claude-md.sh
    flow-kit-bundle/hooks/stop/21-memory.sh
    flow-kit-bundle/hooks/stop/22-git.sh
    flow-kit-bundle/hooks/stop/23-quality.sh
    flow-kit-bundle/hooks/stop/24-session.sh
    flow-kit-bundle/hooks/stop/25-project.sh
    flow-kit-bundle/hooks/stop/26-workflow.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/20-claude-md.sh
    flow-kit-bundle/hooks/stop/21-memory.sh
    flow-kit-bundle/hooks/stop/22-git.sh
    flow-kit-bundle/hooks/stop/23-quality.sh
    flow-kit-bundle/hooks/stop/24-session.sh
    flow-kit-bundle/hooks/stop/25-project.sh
    flow-kit-bundle/hooks/stop/26-workflow.sh
  </write_files>
  <action>
    按 DESIGN D3 迁移 6 模块共 30 个 check_* 函数：
    模式：每个 check_XX() 提取逻辑到 check_XX_body()，原函数改为 1 行 run_check() 调用。
    示例（22-git.sh check_c1）：
      check_c1_body() { <原来的逻辑，去掉 check_enabled guard 行> }
      check_c1() { run_check "git" "C1" "" check_c1_body; }
    含 precondition_file 的 check（如 check_b1 依赖 gotcha-matches.txt）：
      check_b1() { run_check "memory" "B1" "gotcha-matches.txt" check_b1_body; }
    不迁移：27/28/29 模块（不使用 check_enabled 模式）。
    迁移前后行为一致：每个 check 的 state read + evaluate + module_output 逻辑不变。
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/2[0-6]-*.sh &amp;&amp; grep -c "check_enabled" flow-kit-bundle/hooks/stop/2[0-6]-*.sh | grep -v ":0$" ; echo "---" ; npx bats test/test_stop_chain.bats</verify>
  <done>AC-3: 30 处 check_enabled 直接调用消除（≤1 仅 run_check 定义体）；6 模块语法检查通过；stop chain bats 全绿</done>
  <depends_on>T05</depends_on>
</task>

<task id="T07" status="pending">
  <name>AC-5 + AC-6: CONTEXT.md 更新 + CHANGE.md 修正 + 全量回归</name>
  <read_files>
    .specs/CONTEXT.md
    .specs/sweep-fix-2026-07-10/CHANGE.md
    .specs/sweep-fix-2026-07-10/DESIGN.md
    .specs/sweep-fix-2026-07-10/REQUIREMENT.md
  </read_files>
  <write_files>
    .specs/CONTEXT.md
    .specs/sweep-fix-2026-07-10/CHANGE.md
  </write_files>
  <action>
    1. AC-5: CONTEXT.md 追加「命名约定」段（按 DESIGN §9.3 的 7 种前缀表：fk_ / _fk_ / check_ / l2_/l3_ / _gate_ / _fai_，含含义 / 可见性 / 使用场景）
    2. AC-6: CONTEXT.md 追加 _grep 保留决策证据段（宿主机 ugrep 未安装；GNU grep 3.11；grep -P 可用；CC 运行时环境 grep→ugrep alias 破坏 -P flag；结论：KEEP 防御性 shim）
    3. CONTEXT.md TD-020 条目标记 ✅（write_failed_state 已移除）
    4. CHANGE.md 第 25 行修正：TD-018 描述从 "拆分 is_gh_pr_create()" → "重构 independent-review-gate.sh 主逻辑体"
    5. CHANGE.md AC-6 决策概要追加：「_grep 保留（防御性 shim）」
    6. 全量 bats 回归
  </action>
  <verify>grep -q "命名约定" .specs/CONTEXT.md &amp;&amp; grep -q "_gate_" .specs/CONTEXT.md &amp;&amp; grep -q "_grep.*保留\|_grep.*KEEP\|_grep.*防御性" .specs/CONTEXT.md &amp;&amp; echo "DOC OK" &amp;&amp; make test</verify>
  <done>AC-5: CONTEXT.md 含命名约定段（≥7 前缀说明含 _gate_）；AC-6: _grep 保留决策已标注于 CONTEXT.md + CHANGE.md；AC-8: make test 全绿 0 fail；CHANGE.md TD-018 描述已修正</done>
  <depends_on>T01,T02,T03,T04,T05,T06</depends_on>
</task>
```

---

## 状态字段说明

- `status="pending"` — 未开始
- `status="in_progress"` — 进行中
- `status="done"` — 已完成（verify 通过）
- `status="blocked"` — 阻塞

---

## AC 覆盖矩阵

| AC | Task(s) | 验证 |
|----|---------|------|
| AC-1 | T02 | l3_review_run ≤50 行；L3 bats 全绿 |
| AC-2 | T04 | _run_review_gates ≤40 行；gate bats 全绿 |
| AC-3 | T05, T06 | check_enabled ≤1；stop chain bats 全绿 |
| AC-4 | T01 | grep write_failed_state 0 命中 |
| AC-5 | T07 | CONTEXT.md 命名约定段 ≥5 条说明 |
| AC-6 | T07 | _grep 决策已标注 |
| AC-7 | T03 | test_install_dry_run.bats ≥4 条全绿 |
| AC-8 | T07 | make test 全绿 0 fail |

## 阻塞日志

| 任务 | 阻塞原因 | 待人工决策项 | 时间 |
|---|---|---|---|
|  |  |  |  |
