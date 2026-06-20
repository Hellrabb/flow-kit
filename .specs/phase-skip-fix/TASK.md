# TASK: 修复 pipeline toll-gate 阶段跳过漏洞

- **Change ID**: phase-skip-fix
- **关联**: `@.specs/phase-skip-fix/REQUIREMENT.md`、`@.specs/phase-skip-fix/DESIGN.md`

---

## 波次划分

```
Wave 1 (parallel): T01[P], T02[P], T03[P], T04[P], T05[P], T06[P]
Wave 2:            T07 (depends on T01-T06)
Wave 3:            T08 (depends on T07)
```

> 同 wave = 可并行；跨 wave = 必须顺序执行。

---

## 任务清单

```xml
<task id="T01" parallel="true" status="pending">
  <name>PCSC for early prompts: 1-requirement + 2-design + 3-task</name>
  <read_files>
    flow-kit/prompts/1-requirement.md
    flow-kit/prompts/2-design.md
    flow-kit/prompts/3-task.md
    .specs/phase-skip-fix/DESIGN.md
  </read_files>
  <write_files>
    flow-kit/prompts/1-requirement.md
    flow-kit/prompts/2-design.md
    flow-kit/prompts/3-task.md
  </write_files>
  <action>
    在三个 prompt 的「## Pipeline Toll-Gate」标题之前插入「## 阶段完成自检（Phase Completion Self-Check）」段。
    这三个 prompt 的 toll-gate 结构简单（无 auto_advance，无 start_phase 问题），PCSC 模板一致：

    产物清单：
    - Phase 1: REQUIREMENT.md exists + CONTEXT.md terms updated
    - Phase 2: DESIGN.md exists + ADR files (if applicable)
    - Phase 3: TASK.md exists

    每个自检段包含：产物表格（文件名 + 验证方式 + ✅/❌ 列）、阻断规则（任一 ❌ → 禁止进入 toll-gate）、auto_advance 分支（全 ✅ 自动 transition，有 ❌ 暂停）。
    确保不改变「## Pipeline Toll-Gate」段以下的内容。
  </action>
  <verify>grep -c "Phase Completion Self-Check" flow-kit/prompts/1-requirement.md flow-kit/prompts/2-design.md flow-kit/prompts/3-task.md | grep -E "^[^:]+:1$" | wc -l | xargs -I{} test {} -eq 3</verify>
  <done>AC-1（三个 prompt 含 PCSC）、AC-2（阻断规则明确）</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true" status="pending">
  <name>PCSC for 4-dev.md + auto_advance adaptation</name>
  <read_files>
    flow-kit/prompts/4-dev.md
    .specs/phase-skip-fix/DESIGN.md
  </read_files>
  <write_files>
    flow-kit/prompts/4-dev.md
  </write_files>
  <action>
    在 4-dev.md 的「## Pipeline Toll-Gate」标题之前插入「## 阶段完成自检（Phase Completion Self-Check）」段。

    产物清单：
    - TASK.md exists（所有 task status="done"）
    - 每个 task 的 *-SUMMARY.md 均已写入
    - 所有 verify 命令均已通过
    - Sub-goal 自检（若 phase_sub_goals["4"] 非空）

    特别注意：
    - 既有「6.2 Sub-goal 自检（AC-12 联动）」段应被 PCSC 引用或合并（避免重复）
    - 阻断规则明确：任一 ❌ → 禁止进入 toll-gate
    - auto_advance 分支：若 auto_advance=true → 全 ✅ 自动 transition；有 ❌ 暂停并告警
    - 4-dev 的 toll-gate 选项 4（全自动推进）保留不变——PCSC 嵌入在 toll-gate 之前，不影响用户选择
  </action>
  <verify>grep -c "Phase Completion Self-Check" flow-kit/prompts/4-dev.md | xargs -I{} test {} -eq 1</verify>
  <done>AC-1（4-dev 含 PCSC）、AC-2（阻断规则）、AC-3（auto_advance 适配）</done>
  <depends_on></depends_on>
</task>

<task id="T03" parallel="true" status="pending">
  <name>PCSC for 5-test.md + TD-003 start_phase fix</name>
  <read_files>
    flow-kit/prompts/5-test.md
    .specs/phase-skip-fix/DESIGN.md
  </read_files>
  <write_files>
    flow-kit/prompts/5-test.md
  </write_files>
  <action>
    两处修改：

    1. **入口 jq 修复（TD-003）**：在「Pipeline Goal 入场检测」段的 jq 命令中，将 `current_phase // "4"` 改为 `current_phase // .start_phase // "4"`（与 GO.md / 4-dev.md 一致）。

    2. **PCSC 插入**：在「### Toll-gate 5→6（测试完成后）」标题之前插入「## 阶段完成自检（Phase Completion Self-Check）」段。
       产物清单：
       - TEST.md exists（含测试结果）
       - 本次测试范围声明（步骤 0）已明确
       - 测试轮次（1~N）均已执行（按步骤 0 声明）
       - 覆盖率指标已记录（如适用）
       - 测试质量自检（1.4 段）已完成

       auto_advance 分支：若 auto_advance=true → 全 ✅ 自动 transition 到 6-review；有 ❌ 暂停
  </action>
  <verify>grep "start_phase" flow-kit/prompts/5-test.md | grep -c "current_phase.*start_phase" | xargs -I{} test {} -ge 1 && grep -c "Phase Completion Self-Check" flow-kit/prompts/5-test.md | xargs -I{} test {} -eq 1</verify>
  <done>AC-1（5-test 含 PCSC）、AC-3（auto_advance 适配）、AC-6（TD-003 修复）</done>
  <depends_on></depends_on>
</task>

<task id="T04" parallel="true" status="pending">
  <name>PCSC for 6-review.md + TD-003 start_phase fix</name>
  <read_files>
    flow-kit/prompts/6-review.md
    .specs/phase-skip-fix/DESIGN.md
  </read_files>
  <write_files>
    flow-kit/prompts/6-review.md
  </write_files>
  <action>
    两处修改：

    1. **入口 jq 修复（TD-003）**：在「Pipeline Goal 入场检测 + 门禁」段的 jq 命令中，将 `current_phase // "4"` 改为 `current_phase // .start_phase // "4"`。

    2. **PCSC 插入**：在「### Toll-gate 6→7（审查通过后）」标题之前插入「## 阶段完成自检（Phase Completion Self-Check）」段。
       产物清单：
       - REVIEW.md exists（含三轮审查结果）
       - 第一轮 Spec 合规审查已完成
       - 第二轮代码质量审查已完成
       - 第三轮 UI 审查已完成（前端项目）或已声明跳过
       - 动态门禁判定（AC-9）已通过（无 🔴 Critical，或已记录接受风险）
       - Gate 失败项（如有）已记录在 REVIEW.md

       auto_advance 分支：若 auto_advance=true → 全 ✅ 自动 transition 到 7-integration；有 ❌ 暂停
  </action>
  <verify>grep "start_phase" flow-kit/prompts/6-review.md | grep -c "current_phase.*start_phase" | xargs -I{} test {} -ge 1 && grep -c "Phase Completion Self-Check" flow-kit/prompts/6-review.md | xargs -I{} test {} -eq 1</verify>
  <done>AC-1（6-review 含 PCSC）、AC-3（auto_advance 适配）、AC-6（TD-003）</done>
  <depends_on></depends_on>
</task>

<task id="T05" parallel="true" status="pending">
  <name>PCSC for 7-integration.md + TD-003 start_phase fix</name>
  <read_files>
    flow-kit/prompts/7-integration.md
    .specs/phase-skip-fix/DESIGN.md
  </read_files>
  <write_files>
    flow-kit/prompts/7-integration.md
  </write_files>
  <action>
    两处修改：

    1. **入口 jq 修复（TD-003）**：在「Pipeline Goal 入场检测 + 完成」段的 jq 命令中，将 `current_phase // "4"` 改为 `current_phase // .start_phase // "4"`。

    2. **PCSC 插入**：在「### Pipeline 完成（AC-8）」标题之前（即在顶层 Goal 条件自检之后、pipeline 完成之前）插入「## 阶段完成自检（Phase Completion Self-Check）」段。
       产物清单：
       - 全量测试通过（步骤 1 全套自动化）
       - UAT 引导已完成（步骤 2）
       - 失败诊断已完成（步骤 3，如有失败）
       - LESSONS.md 提名已完成（步骤 4）
       - 顶层 Goal 条件自检通过

       注意：7-integration 无 toll-gate（它是最终阶段），PCSC 作为 pipeline 完成的前置条件。
  </action>
  <verify>grep "start_phase" flow-kit/prompts/7-integration.md | grep -c "current_phase.*start_phase" | xargs -I{} test {} -ge 1 && grep -c "Phase Completion Self-Check" flow-kit/prompts/7-integration.md | xargs -I{} test {} -eq 1</verify>
  <done>AC-1（7-integration 含 PCSC）、AC-6（TD-003 修复）</done>
  <depends_on></depends_on>
</task>

<task id="T06" parallel="true" status="pending">
  <name>Phase Completion Gate in GO.md（路由层拦截）</name>
  <read_files>
    flow-kit/GO.md
    .specs/phase-skip-fix/DESIGN.md
  </read_files>
  <write_files>
    flow-kit/GO.md
  </write_files>
  <action>
    在 GO.md 第二步「Artifact Preflight Gate」之后，新增「Phase Completion Gate」段。

    内容：
    1. **触发条件说明**：仅 pipeline goal 模式；当目标阶段 > current_phase 时触发（即 AI 试图推进阶段）
    2. **产物清单表**：

    | 退出阶段 | 必须产物（`.specs/<change-id>/` 下） | 验证命令 |
    |---|---|---|
    | 0 | CHANGE.md | test -f .specs/$CHANGE_ID/CHANGE.md |
    | 1 | REQUIREMENT.md | test -f .specs/$CHANGE_ID/REQUIREMENT.md |
    | 2 | DESIGN.md | test -f .specs/$CHANGE_ID/DESIGN.md |
    | 3 | TASK.md | test -f .specs/$CHANGE_ID/TASK.md |
    | 4 | TASK.md (all tasks done) | test -f .specs/$CHANGE_ID/TASK.md |
    | 5 | TEST.md | test -f .specs/$CHANGE_ID/TEST.md |
    | 6 | REVIEW.md | test -f .specs/$CHANGE_ID/REVIEW.md |

    3. **拦截逻辑**：读取 `change_id` 和 `current_phase`；对照上表检查产物；缺失 → 输出缺失清单 + 拒绝路由提示；完整 → 放行
    4. **guard**：若 change_id 为 null → 跳过 PCG + 警告（非 pipeline 模式）

    位置：在现有 Artifact Preflight Gate 表之后，作为其对称扩展。与 Artifact Preflight Gate 的区别：Preflight 检查「进入目标阶段需要什么」（前向），PCG 检查「离开当前阶段时产出了什么」（后向）。
  </action>
  <verify>grep -c "Phase Completion Gate" flow-kit/GO.md | xargs -I{} test {} -ge 1 && grep -c "test -f .specs" flow-kit/GO.md | xargs -I{} test {} -ge 5</verify>
  <done>AC-4（GO.md 含 PCG）、AC-5（产物清单与 prompt 一致需 T07 交叉验证）</done>
  <depends_on></depends_on>
</task>

<task id="T07" status="pending">
  <name>Write test_phase_gate.bats（PCSC + PCG 测试）</name>
  <read_files>
    test/test_flow_goal.bats
    test/test_pipeline_rollback.bats
    flow-kit/prompts/1-requirement.md
    flow-kit/prompts/2-design.md
    flow-kit/prompts/3-task.md
    flow-kit/prompts/4-dev.md
    flow-kit/prompts/5-test.md
    flow-kit/prompts/6-review.md
    flow-kit/prompts/7-integration.md
    flow-kit/GO.md
  </read_files>
  <write_files>
    test/test_phase_gate.bats
  </write_files>
  <action>
    创建 test/test_phase_gate.bats，参考 test_flow_goal.bats 的 setup/teardown 模式。

    测试用例（≥ 8 个）：

    1. `@test "AC-1: all 7 phase prompts contain Phase Completion Self-Check"` → grep -c 返回 ≥ 7
    2. `@test "AC-2: all 7 prompts contain blocking rule"` → grep "禁止进入 toll-gate" 或等效英文
    3. `@test "AC-3: 5-test auto_advance branch runs self-check"` → grep auto_advance 附近有 self-check 逻辑
    4. `@test "AC-3: 6-review auto_advance branch runs self-check"` → 同上
    5. `@test "AC-4: GO.md contains Phase Completion Gate"` → grep -c ≥ 1
    6. `@test "AC-5: GO.md PCG artifact list matches prompt PCSC (phase 1-6)"` → 提取 GO.md 产物清单，与各 prompt 的 PCSC 段对照
    7. `@test "AC-6: 5-test entry jq includes start_phase fallback"` → grep "start_phase" + "current_phase"
    8. `@test "AC-6: 6-review entry jq includes start_phase fallback"` → 同上
    9. `@test "AC-6: 7-integration entry jq includes start_phase fallback"` → 同上

    使用 FLOW_ACTIVE 临时文件（teardown 清理），避免污染真实状态。
  </action>
  <verify>npx bats test/test_phase_gate.bats</verify>
  <done>AC-7（新增 bats 测试全部通过）</done>
  <depends_on>T01,T02,T03,T04,T05,T06</depends_on>
</task>

<task id="T08" status="pending">
  <name>Full test run + repackage + commit + archive</name>
  <read_files>
    test/
    flow-kit-bundle/
    package-flow-kit.sh
    .specs/CONTEXT.md
  </read_files>
  <write_files>
    flow-kit-bundle.tar.gz
    flow-kit-bundle/flow-kit/prompts/1-requirement.md
    flow-kit-bundle/flow-kit/prompts/2-design.md
    flow-kit-bundle/flow-kit/prompts/3-task.md
    flow-kit-bundle/flow-kit/prompts/4-dev.md
    flow-kit-bundle/flow-kit/prompts/5-test.md
    flow-kit-bundle/flow-kit/prompts/6-review.md
    flow-kit-bundle/flow-kit/prompts/7-integration.md
    flow-kit-bundle/flow-kit/GO.md
    flow-kit-bundle/test/test_phase_gate.bats
  </write_files>
  <action>
    集成验证步骤：

    1. 运行全量测试：`npx bats test/` → 确认全部通过
    2. 若测试失败 → 回 T01-T07 修复
    3. 重新打包：`bash package-flow-kit.sh` → 生成新 flow-kit-bundle.tar.gz
    4. 同步 test 源到 bundle：`cp test/test_phase_gate.bats flow-kit-bundle/test/`
    5. Git 提交：`git add -A && git commit -m "feat(phase-skip-fix): 双层防护修复 pipeline toll-gate 阶段跳过漏洞"`
    6. 归档：更新 STATE.md last_change_archived，移动 .specs/phase-skip-fix/ 到 archive/
  </action>
  <verify>npx bats test/ && test -f flow-kit-bundle.tar.gz</verify>
  <done>AC-7（全量测试通过）、pipeline 完成</done>
  <depends_on>T07</depends_on>
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

> 此区域由 review/integration 阶段自动追加。

```xml
<!-- 占位 -->
```
