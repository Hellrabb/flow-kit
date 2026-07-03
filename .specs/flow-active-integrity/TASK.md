# TASK: 将 .flow-active 状态完整性纳入 L2/L3 检查

- **Change ID**: flow-active-integrity
- **关联**: `@.specs/flow-active-integrity/REQUIREMENT.md`、`@.specs/flow-active-integrity/DESIGN.md`

---

## 波次划分

```
Wave 1 (parallel): T01[P], T02[P]
Wave 2 (parallel): T03[P], T04[P]   (depends on T01, T02)
```

> T01 和 T02 互不冲突（T01 新建文件 + 改 00-gate/common.sh，T02 编辑 prompt 文件）；T03 和 T04 均依赖 T01+T02 产出，但互不冲突。

---

## 任务清单

```xml
<task id="T01" parallel="true" status="pending">
  <name>创建 33-flow-active-integrity.sh + 执行链接线（L3 交叉验证模块）</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/correction-file.sh
    flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh
    flow-kit-bundle/hooks/stop/lib/common.sh
    flow-kit-bundle/hooks/stop/00-gate.sh
    flow-kit-bundle/hooks/stop/28-weak-model-compliance.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/33-flow-active-integrity.sh
    flow-kit-bundle/hooks/stop/00-gate.sh
    flow-kit-bundle/hooks/stop/lib/common.sh
  </write_files>
  <action>
    第一部分：新建 33 号模块。按 DESIGN D1-D5 + 数据流图实现。5 个检测函数 + 主编排器：

    1. check_change_id(): jq 读 .flow-active.change_id；若非 null 则 test -d .specs/$change_id；null 时检查 .specs/ 下是否有非 archive/health/ 子目录（有 → 报警）
    2. check_phase(): 读 change_id + phase → source flow-kit-artifacts.sh → 查 PHASE_ARTIFACTS → test -f 每个必须产物
    3. check_pipeline(): 若 goal.scope="pipeline" → phases_done 每个 phase 产物存在 + current_phase 对应的前一个 gate "N-1→N"=passed（未 passed → 报警）+ passed gate 的左侧 N 在 phases_done 中
    4. check_staleness(): 读 updated_at → 与当前时间比较 → 超过 FLOW_ACTIVE_STALE_HOURS（默认 24）→ 报警
    5. check_token(): 若 token_spent=0 → grep transcript 中 jq 写 .flow-active 的命令（模式：`jq.*'[.].*=' .flow-active` 或 `jq.*>.*\.flow-active`）→ 命中 → 报警

    错误处理（NFR 可靠性）：jq 不可用/JSON 损坏/.specs 遍历失败 → 跳过对应检查不崩溃
    矫正文件合并策略（R1 修复）：read-merge-write —— 先读现有 .flow-active.correction → 追加新 violations → 写回
    PHASE_ARTIFACTS 回退映射（R2 修复）：内置最小映射 {1:REQUIREMENT.md, 2:DESIGN.md, 3:TASK.md, 4:*-SUMMARY.md, 5:TEST.md, 6:REVIEW.md}
    路径脱敏（R4 修复）：矫正文件只写相对路径（.specs/<id>/...），不写绝对路径

    第二部分：执行链接线（R2 Critical 修复 —— 缺此则 33 永不执行）。
    a) 00-gate.sh：在 30-ai-analyze 的 run_module 之后、99-report 之前，插入：
       run_module "${HOOK_BASE_DIR}/33-flow-active-integrity.sh" "flow-active-integrity"
       同时补齐遗漏的 31/32 接线：
       run_module "${HOOK_BASE_DIR}/31-auto-advance.sh" "auto-advance"
       run_module "${HOOK_BASE_DIR}/32-fallback-guard.sh" "fallback-guard"
    b) common.sh：HOOK_MODULE_NAMES 数组追加 "33-flow-active-integrity"（在 32-fallback-guard 之后、99-report 之前）

    预估代码量：33 号模块 ~150-180 行（含 5 检查函数 + 主编排器 + 错误处理）；00-gate.sh +3 行；common.sh +1 字
  </action>
  <verify>shellcheck flow-kit-bundle/hooks/stop/33-flow-active-integrity.sh && bash -n flow-kit-bundle/hooks/stop/33-flow-active-integrity.sh && grep -q '33-flow-active-integrity' flow-kit-bundle/hooks/stop/00-gate.sh && grep -q '33-flow-active-integrity' flow-kit-bundle/hooks/stop/lib/common.sh</verify>
  <done>33 号模块语法正确；00-gate.sh 接线完成（含 31/32 补齐）；common.sh HOOK_MODULE_NAMES 已更新；5 检测函数 + 编排器 + 错误处理 + read-merge-write + 回退映射 + 路径脱敏全部实现</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true" status="pending">
  <name>L2 PCSC 自检表 — 所有阶段 prompt + GO.md 添加 .flow-active 确认项</name>
  <read_files>
    ~/.claude/flow-kit/prompts/0-change.md
    ~/.claude/flow-kit/prompts/1-requirement.md
    ~/.claude/flow-kit/prompts/2-design.md
    ~/.claude/flow-kit/prompts/3-task.md
    ~/.claude/flow-kit/prompts/4-dev.md
    ~/.claude/flow-kit/prompts/5-test.md
    ~/.claude/flow-kit/prompts/6-review.md
    ~/.claude/flow-kit/prompts/7-integration.md
    ~/.claude/flow-kit/GO.md
    flow-kit-bundle/flow-kit/prompts/0-change.md
    flow-kit-bundle/flow-kit/prompts/1-requirement.md
    flow-kit-bundle/flow-kit/prompts/2-design.md
    flow-kit-bundle/flow-kit/prompts/3-task.md
    flow-kit-bundle/flow-kit/prompts/4-dev.md
    flow-kit-bundle/flow-kit/prompts/5-test.md
    flow-kit-bundle/flow-kit/prompts/6-review.md
    flow-kit-bundle/flow-kit/prompts/7-integration.md
    flow-kit-bundle/flow-kit/GO.md
  </read_files>
  <write_files>
    ~/.claude/flow-kit/prompts/0-change.md
    ~/.claude/flow-kit/prompts/1-requirement.md
    ~/.claude/flow-kit/prompts/2-design.md
    ~/.claude/flow-kit/prompts/3-task.md
    ~/.claude/flow-kit/prompts/4-dev.md
    ~/.claude/flow-kit/prompts/5-test.md
    ~/.claude/flow-kit/prompts/6-review.md
    ~/.claude/flow-kit/prompts/7-integration.md
    ~/.claude/flow-kit/GO.md
    flow-kit-bundle/flow-kit/prompts/0-change.md
    flow-kit-bundle/flow-kit/prompts/1-requirement.md
    flow-kit-bundle/flow-kit/prompts/2-design.md
    flow-kit-bundle/flow-kit/prompts/3-task.md
    flow-kit-bundle/flow-kit/prompts/4-dev.md
    flow-kit-bundle/flow-kit/prompts/5-test.md
    flow-kit-bundle/flow-kit/prompts/6-review.md
    flow-kit-bundle/flow-kit/prompts/7-integration.md
    flow-kit-bundle/flow-kit/GO.md
  </write_files>
  <action>
    按 DESIGN D2+D6 在以下位置各加一条 PCSC 自检项：

    1. **8 个阶段 prompt**（0-change ~ 7-integration）：在每个文件的「阶段完成自检」表格末尾追加一行：
       ```
       | N | .flow-active 关键字段（phase/task_id/change_id/updated_at）已通过 jq 写入磁盘 | test -s .flow-active && jq -e '.updated_at' .flow-active >/dev/null | ✅ / ❌ |
       ```
       编号 N 根据各文件现有 PCSC 表行数递增

    2. **GO.md**：在 transition jq 命令块附近加一行 PCSC 风格的自检注释（含统一锚点文本），使 grep 验证能命中：
       ```
       <!-- PCSC: .flow-active 关键字段（phase/task_id/change_id/updated_at）已通过 jq 写入磁盘 — 上方 transition jq 已执行 -->
       ```

    3. **两处同步**：user-scope（~/.claude/flow-kit/）和 bundle 源（flow-kit-bundle/flow-kit/）同时修改，保持一致性

    统一锚点文本（AC-1 验证用）：`.flow-active 关键字段（phase/task_id/change_id/updated_at）已通过 jq 写入磁盘`
  </action>
  <verify>ANCHOR='\.flow-active 关键字段（phase/task_id/change_id/updated_at）已通过 jq 写入磁盘' && echo "=== user-scope ===" && grep -l "$ANCHOR" ~/.claude/flow-kit/prompts/{0-change,1-requirement,2-design,3-task,4-dev,5-test,6-review,7-integration}.md ~/.claude/flow-kit/GO.md | wc -l && echo "=== bundle ===" && grep -l "$ANCHOR" flow-kit-bundle/flow-kit/prompts/{0-change,1-requirement,2-design,3-task,4-dev,5-test,6-review,7-integration}.md flow-kit-bundle/flow-kit/GO.md | wc -l && echo "Expected: 9 each"</verify>
  <done>AC-1 验证通过：user-scope 9 文件 + bundle 9 文件（共 18 处）全含统一锚点文本</done>
  <depends_on></depends_on>
</task>

<task id="T03" parallel="true" status="pending">
  <name>创建 test_flow_active_integrity.bats — 覆盖全部 6 条 AC + NFR 可靠性</name>
  <read_files>
    flow-kit-bundle/hooks/stop/33-flow-active-integrity.sh
    flow-kit-bundle/hooks/stop/00-gate.sh
    flow-kit-bundle/hooks/stop/lib/correction-file.sh
    flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh
    flow-kit-bundle/hooks/stop/lib/common.sh
    test/test_correction_file.bats
    test/test_gate_integrity.bats
    test/test_flow_artifacts.bats
  </read_files>
  <write_files>
    test/test_flow_active_integrity.bats
  </write_files>
  <action>
    编写 bats 测试覆盖所有 6 条 AC 的检测逻辑 + NFR 可靠性场景。每个测试用例构造特定场景 → source 33 号模块的检测函数 → 验证矫正文件输出。

    **AC 覆盖（≥12 cases）**：

    AC-2 (phase-artifact 对齐):
    - test_phase2_missing_design: phase=2, change_id=test, .specs/test/DESIGN.md 不存在 → 检测到缺失
    - test_phase1_all_present: phase=1, 产物齐全 → 无报警

    AC-3 (change_id 一致性):
    - test_change_id_dangling: change_id=ghost, .specs/ghost/ 不存在 → 检测到悬空
    - test_change_id_null_with_active_dirs: change_id=null, .specs/ 下有非 archive/health 子目录 → 检测到不一致

    AC-4 (pipeline goal 字段交叉验证):
    - test_pipeline_phases_done_missing_artifact: phases_done=["0","1"], REQUIREMENT.md 缺失 → 报警
    - test_pipeline_gate_passed_but_phase_not_done: gates["1→2"]=passed, phases_done 不含 "1" → 报警
    - test_pipeline_current_phase_gate_not_passed: current_phase=2, gates["1→2"]!="passed" → 报警（R7 补充）
    - test_pipeline_all_consistent: 各字段自洽 → 无报警

    AC-5 (updated_at 时效性):
    - test_stale_updated_at: updated_at=24h+ 前 → 检测到 stale
    - test_fresh_updated_at: updated_at=1h 前 → 无报警

    AC-6 (token_spent 未维护):
    - test_token_spent_zero_with_writes: token_spent=0 + transcript 含 jq .flow-active 写操作 → 报警
    - test_token_spent_nonzero: token_spent>0 → 无报警

    **NFR 可靠性（R4 补充 · ≥4 cases）**：
    - test_jq_unavailable: 模拟 PATH 无 jq → 模块跳过不崩溃，返回 0
    - test_corrupt_json: .flow-active 内容非合法 JSON → 模块检测到并写入矫正文件，不崩溃
    - test_specs_traversal_failure: .specs/ 目录不可读 → 模块跳过不崩溃
    - test_phase_artifacts_fallback: PHASE_ARTIFACTS 未定义 → 使用内置回退映射正常工作

    使用 setup() 创建临时目录 + .flow-active + .specs/ + transcript fixture，teardown() 清理。
  </action>
  <verify>npx bats test/test_flow_active_integrity.bats --print-output-on-failure</verify>
  <done>≥16 cases 全部通过：12 AC 覆盖 + 4 NFR 可靠性，覆盖 6 条 AC + 4 种异常场景</done>
  <depends_on>T01</depends_on>
</task>

<task id="T04" parallel="true" status="pending">
  <name>注册 33 号模块 + 同步 bundle prompts + 集成验证</name>
  <read_files>
    flow-kit-bundle/hooks/config/stop-hook.json
    flow-kit-bundle/hooks/stop/33-flow-active-integrity.sh
    flow-kit-bundle/hooks/stop/00-gate.sh
    flow-kit-bundle/hooks/stop/lib/common.sh
    flow-kit-bundle/flow-kit/prompts/*.md
    flow-kit-bundle/flow-kit/GO.md
    ~/.claude/flow-kit/prompts/*.md
    ~/.claude/flow-kit/GO.md
    Makefile
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/config/stop-hook.json
  </write_files>
  <action>
    1. stop-hook.json（路径：flow-kit-bundle/hooks/config/stop-hook.json）新增 33 号模块条目。
       模块 key 遵循既有 snake_case 命名惯例：
       ```json
       "flow_active_integrity": {
         "enabled": true,
         "description": ".flow-active state integrity cross-validation (L3)"
       }
       ```
       位置：在 "weak_model_compliance" 条目之后（按编号排序）

    2. 确认 T01 的 00-gate.sh + common.sh 接线已完成（T01 verify 已覆盖）

    3. 确认 T02 的双写一致性：
       diff -rq ~/.claude/flow-kit/prompts/ flow-kit-bundle/flow-kit/prompts/
       diff -q ~/.claude/flow-kit/GO.md flow-kit-bundle/flow-kit/GO.md

    4. 集成验证：shellcheck 33 号模块 + npx bats test/test_flow_active_integrity.bats + 确认 stop-hook.json 的 jq 可读
  </action>
  <verify>jq -e '.modules.flow_active_integrity.enabled == true' flow-kit-bundle/hooks/config/stop-hook.json && echo "stop-hook.json OK" && diff -q <(grep 'flow-active.*关键字段' ~/.claude/flow-kit/GO.md) <(grep 'flow-active.*关键字段' flow-kit-bundle/flow-kit/GO.md) && echo "prompt sync OK"</verify>
  <done>33 号模块已注册（stop-hook.json snake_case key）；00-gate+common 接线完成；bundle 与 user-scope prompts 同步；集成验证通过</done>
  <depends_on>T01, T02</depends_on>
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
