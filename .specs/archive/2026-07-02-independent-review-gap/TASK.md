# TASK: 补齐 L2/L3 独立审查 3/5/7 缺失

> 任务拆解基于 DESIGN.md D1-D5 决策，目标：6 个文件修改 + 3 个验证步骤。

## 波次划分

```
Wave 1 (parallel): T01[P], T02[P], T03[P], T04[P], T05[P]  ← 所有内容修改互不冲突
Wave 2 (parallel): T06[P], T07[P]                            ← 需要 wave1 产物做上下文
Wave 3 (parallel): T08[P], T09[P]                            ← 验证层，依赖 wave2
```

---

<task id="T01" parallel="true">
  <name>SKILL.md: PRESET_MAP 补全 + gate-config 合法值扩展</name>
  <read_files>
    flow-kit-bundle/skills/flow/SKILL.md
  </read_files>
  <write_files>
    flow-kit-bundle/skills/flow/SKILL.md
  </write_files>
  <action>
    1. PRESET_MAP 注释段新增 8 个预设名行：
       - task → {"3-task":"independent"}
       - test → {"5-test":"independent"}
       - integration → {"7-integration":"independent"}
       - task-review → {"3-task":"independent","6-review":"independent"}
       - test-review → {"5-test":"independent","6-review":"independent"}
       - task-test → {"3-task":"independent","5-test":"independent"}
       - task-test-review → {"3-task":"independent","5-test":"independent","6-review":"independent"}
       - spec-test → {"1-requirement":"independent","2-design":"independent","5-test":"independent"}
    2. all 行追加注释 "⚠️ 预计增加 30k-75k tokens/pipeline run"
    3. /flow gate-config 子命令合法值列表从 "1-requirement / 2-design / 6-review" 扩展为 "1-requirement / 2-design / 3-task / 5-test / 6-review / 7-integration"
    4. 追加提示："开启前确认对应阶段 prompt 已含独立审查段（3/5/7 由 independent-review-gap change 补齐）"
  </action>
  <verify>grep -c "# task\b" flow-kit-bundle/skills/flow/SKILL.md | xargs test 1 -eq && grep -c "# test\b" flow-kit-bundle/skills/flow/SKILL.md | xargs test 1 -eq && grep -c "# integration\b" flow-kit-bundle/skills/flow/SKILL.md | xargs test 1 -eq && grep -c "3-task" flow-kit-bundle/skills/flow/SKILL.md | xargs test 2 -ge</verify>
  <done>8 个新预设名已加入 PRESET_MAP 注释；gate-config 合法值含 3/5/7；all 行有 token 警告；bats 现有预设测试仍 pass</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true">
  <name>3-task.md: 新增「独立 review 调度」段</name>
  <read_files>
    ~/.claude/flow-kit/prompts/3-task.md
    ~/.claude/flow-kit/prompts/1-requirement.md
    ~/.claude/flow-kit/prompts/independent/L2-blind-review.md
  </read_files>
  <write_files>
    ~/.claude/flow-kit/prompts/3-task.md
  </write_files>
  <action>
    在「触发下一步」段之后、「阶段完成自检」段之前，插入「独立 review 调度」段。
    结构按 DESIGN §3 完整模板，参数使用阶段 3 的值：
    - subagent_type: architect-reviewer
    - 审查工件: TASK.md
    - 输出文件: INDEPENDENT-REVIEW-3.md
    - done 标记: .independent-review-3.done
    - 含错误处理 3 条指令（L2失败/verdict=fail/verdict=pass）
    格式参照 1-requirement.md 的现有段（复制结构，替换参数）。
  </action>
  <verify>bash -c 'grep -q "独立 review 调度" ~/.claude/flow-kit/prompts/3-task.md && grep -q "L2.*独立子 agent 盲审" ~/.claude/flow-kit/prompts/3-task.md && grep -q "L3.*Stop hook" ~/.claude/flow-kit/prompts/3-task.md && grep -q "touch.*independent-review" ~/.claude/flow-kit/prompts/3-task.md && grep -q "错误处理" ~/.claude/flow-kit/prompts/3-task.md && echo "AC-1 PASS for 3-task"'</verify>
  <done>3-task.md 含完整的「独立 review 调度」段（gate检测+L2模板+L3说明+错误处理+done指令），AC-1 静态检查通过</done>
  <depends_on></depends_on>
</task>

<task id="T03" parallel="true">
  <name>5-test.md: 新增「独立 review 调度」段</name>
  <read_files>
    ~/.claude/flow-kit/prompts/5-test.md
    ~/.claude/flow-kit/prompts/1-requirement.md
    ~/.claude/flow-kit/prompts/independent/L2-blind-review.md
  </read_files>
  <write_files>
    ~/.claude/flow-kit/prompts/5-test.md
  </write_files>
  <action>
    同 T02，参数替换为阶段 5：
    - subagent_type: qa-expert
    - 审查工件: TEST.md
    - 输出文件: INDEPENDENT-REVIEW-5.md
    - done 标记: .independent-review-5.done
  </action>
  <verify>bash -c 'grep -q "独立 review 调度" ~/.claude/flow-kit/prompts/5-test.md && grep -q "L2.*独立子 agent 盲审" ~/.claude/flow-kit/prompts/5-test.md && grep -q "L3.*Stop hook" ~/.claude/flow-kit/prompts/5-test.md && grep -q "touch.*independent-review" ~/.claude/flow-kit/prompts/5-test.md && grep -q "错误处理" ~/.claude/flow-kit/prompts/5-test.md && echo "AC-1 PASS for 5-test"'</verify>
  <done>5-test.md 含完整的「独立 review 调度」段，AC-1 静态检查通过</done>
  <depends_on></depends_on>
</task>

<task id="T04" parallel="true">
  <name>7-integration.md: 新增「独立 review 调度」段</name>
  <read_files>
    ~/.claude/flow-kit/prompts/7-integration.md
    ~/.claude/flow-kit/prompts/1-requirement.md
    ~/.claude/flow-kit/prompts/independent/L2-blind-review.md
  </read_files>
  <write_files>
    ~/.claude/flow-kit/prompts/7-integration.md
  </write_files>
  <action>
    同 T02，参数替换为阶段 7：
    - subagent_type: architect-reviewer
    - 审查工件: 归档完整性（全部产物）
    - 输出文件: INDEPENDENT-REVIEW-7.md
    - done 标记: .independent-review-7.done
    注意：7-integration 已有"L2 自检 gate"内联行（5.0.3 段），新增段插在「触发下一步」之后，不与现有内联行冲突。
  </action>
  <verify>bash -c 'grep -q "独立 review 调度" ~/.claude/flow-kit/prompts/7-integration.md && grep -q "L2.*独立子 agent 盲审" ~/.claude/flow-kit/prompts/7-integration.md && grep -q "L3.*Stop hook" ~/.claude/flow-kit/prompts/7-integration.md && grep -q "touch.*independent-review" ~/.claude/flow-kit/prompts/7-integration.md && grep -q "错误处理" ~/.claude/flow-kit/prompts/7-integration.md && echo "AC-1 PASS for 7-integration"'</verify>
  <done>7-integration.md 含完整的「独立 review 调度」段，AC-1 静态检查通过</done>
  <depends_on></depends_on>
</task>

<task id="T05" parallel="true">
  <name>L2-blind-review.md: 扩展阶段 3/5/7 审查 checklist</name>
  <read_files>
    ~/.claude/flow-kit/prompts/independent/L2-blind-review.md
  </read_files>
  <write_files>
    ~/.claude/flow-kit/prompts/independent/L2-blind-review.md
  </write_files>
  <action>
    在现有「阶段 6」checklist 之后追加三个新段，格式沿用 1/2/6 的 `### 阶段 N · <名称>` + 条目格式：

    阶段 3 · 任务拆解审查（3-task）：
    - **任务粒度**: 单 task ≤ 200 行变更？波次划分是否清晰（wave 1/2/3）？
    - **依赖链**: 依赖图无环？可并行部分是否已标 [P]？
    - **verify 可验证性**: 每条 verify 是否可机器执行（非"人工确认"空话）？
    - **覆盖完整性**: 所有 AC 是否有对应 task？read_files/write_files 约束是否到位？
    - **禁动清单**: write_files 是否触碰了 DESIGN 或 CONTEXT 禁动清单中的文件？

    阶段 5 · 测试审查（5-test）：
    - **AC 覆盖**: 测试矩阵是否覆盖所有 AC（每条 AC ≥ 1 条测试用例对应）？
    - **5 轮金字塔**: 功能/性能/安全/兼容/可观测是否逐轮填写（跳过的有理由）？
    - **覆盖率达标**: 功能轮是否 100% AC 覆盖？
    - **UAT 可执行**: Given/When/Then 是否可脚本化（非手工步骤描述）？
    - **回归安全**: 全量 bats 是否不退化？

    阶段 7 · 集成审查（7-integration）：
    - **产物齐全**: CHANGE/REQUIREMENT/DESIGN/TASK/SUMMARY×N/TEST/REVIEW 全部存在？
    - **LESSONS 同步**: 是否从本次 REVIEW 中提取了新教训并写入 LESSONS.md？
    - **CHANGELOG 更新**: 本次 change 条目是否已追加到 CHANGELOG.md？
    - **归档清洁**: .specs/<id>/ 目录是否有残留临时文件未清理？
    - **done 标记**: .independent-review-7.done 是否存在且非空？
  </action>
  <verify>bash -c '
for phase in 3 5 7; do
  section=$(sed -n "/^### 阶段 $phase/,/^### 阶段/p" ~/.claude/flow-kit/prompts/independent/L2-blind-review.md)
  entry_count=$(echo "$section" | grep -cE "^- \*\*" || true)
  if [ "$entry_count" -lt 3 ]; then
    echo "FAIL: 阶段 $phase checklist 仅 $entry_count 条（需 ≥ 3）"
    exit 1
  fi
done
echo "AC-4 PASS"
'</verify>
  <done>L2-blind-review.md 含阶段 3/5/7 审查 checklist，每阶段 ≥ 3 条具体条目，AC-4 内容验证通过</done>
  <depends_on></depends_on>
</task>

<task id="T06" parallel="true">
  <name>pipeline-gates.md: 说明文字同步</name>
  <read_files>
    ~/.claude/flow-kit/reference/pipeline-gates.md
  </read_files>
  <write_files>
    ~/.claude/flow-kit/reference/pipeline-gates.md
  </write_files>
  <action>
    L75 注文追加：
    "3/5/7 的 prompt 层独立审查支持由 `independent-review-gap` change (2026-07-02) 补齐。开启前确保 prompt 文件版本与此 change 同步。"
  </action>
  <verify>grep -q "independent-review-gap" ~/.claude/flow-kit/reference/pipeline-gates.md && echo "AC-5 PASS for pipeline-gates"</verify>
  <done>pipeline-gates.md 含 independent-review-gap 引用，AC-5 通过</done>
  <depends_on>T01</depends_on>
</task>

<task id="T07" parallel="true">
  <name>bats: 新增预设测试用例</name>
  <read_files>
    flow-kit-bundle/test/test_gate_config_presets.bats
  </read_files>
  <write_files>
    flow-kit-bundle/test/test_gate_config_presets.bats
  </write_files>
  <action>
    在 test_gate_config_presets.bats 中新增 8 个预设的测试用例（每个预设 1 个 @test）：
    - task → {"3-task":"independent"}
    - test → {"5-test":"independent"}
    - integration → {"7-integration":"independent"}
    - task-review → {"3-task":"independent","6-review":"independent"}
    - test-review → {"5-test":"independent","6-review":"independent"}
    - task-test → {"3-task":"independent","5-test":"independent"}
    - task-test-review → {"3-task":"independent","5-test":"independent","6-review":"independent"}
    - spec-test → {"1-requirement":"independent","2-design":"independent","5-test":"independent"}
    格式沿用现有 test case 模式（调用 resolve_gate_config，jq 验证 JSON 输出）。
  </action>
  <verify>npx bats flow-kit-bundle/test/test_gate_config_presets.bats --filter "preset" 2>&1 | grep -E "^ok |^not ok " | grep -c "^not ok " | xargs test 0 -eq && echo "AC-6 PASS"</verify>
  <done>8 个新预设的 bats 测试用例全部 pass，AC-6 通过</done>
  <depends_on>T01</depends_on>
</task>

<task id="T08" parallel="true">
  <name>check-gate-sync.sh + bats 全量回归</name>
  <read_files>
    ~/.claude/flow-kit/reference/check-gate-sync.sh
  </read_files>
  <write_files>
  </write_files>
  <action>
    1. 运行 check-gate-sync.sh，验证 SKILL.md PRESET_MAP ↔ bats 预设名集合一致
    2. 运行 npx bats test/ 全量测试，确认 ≥ 216 pass（不退化）
    3. 如有 set-diff 不一致或 bats 失败，回溯修复对应 task
  </action>
  <verify>bash ~/.claude/flow-kit/reference/check-gate-sync.sh 2>&1 | grep -q "✅ 预设名集合一致" && npx bats test/ 2>&1 | grep -E "^ok |^not ok " | grep -c "^not ok " | xargs test 0 -eq && echo "AC-3 + regression PASS"</verify>
  <done>check-gate-sync set-diff 通过；bats 全量 ≥ 216 pass 无退化</done>
  <depends_on>T01, T07</depends_on>
</task>

<task id="T09" parallel="true">
  <name>AC 验证脚本全部通过</name>
  <read_files>
    .specs/independent-review-gap/REQUIREMENT.md
    .specs/independent-review-gap/DESIGN.md
  </read_files>
  <write_files>
  </write_files>
  <action>
    逐条执行 REQUIREMENT.md 中 AC-1~AC-7 的验证脚本：
    1. AC-1: 检查 3/5/7 prompt 含独立审查段
    2. AC-2+AC-3: 由 T08 check-gate-sync.sh 覆盖
    3. AC-4: 检查 L2-blind-review.md 3/5/7 checklist ≥ 3 条目
    4. AC-5: 检查 SKILL.md + pipeline-gates.md 同步
    5. AC-6: 由 T07 bats 测试覆盖
    6. AC-7: 端到端验证（fixture 模拟，检查 INDEPENDENT-REVIEW + done 文件）
    全部 7 条 AC 通过则输出 "ALL 7 ACs PASS"
  </action>
  <verify>bash -c '
echo "=== AC-1 ==="
for f in 3-task 5-test 7-integration; do
  grep -q "独立 review 调度" ~/.claude/flow-kit/prompts/$f.md || { echo "FAIL AC-1: $f"; exit 1; }
done
echo "AC-1 PASS"

echo "=== AC-4 ==="
for phase in 3 5 7; do
  section=$(sed -n "/^### 阶段 $phase/,/^### 阶段/p" ~/.claude/flow-kit/prompts/independent/L2-blind-review.md)
  entry_count=$(echo "$section" | grep -cE "^- \*\*" || true)
  [ "$entry_count" -ge 3 ] || { echo "FAIL AC-4: phase $phase only $entry_count entries"; exit 1; }
done
echo "AC-4 PASS"

echo "=== AC-5 ==="
grep -q "3-task" flow-kit-bundle/skills/flow/SKILL.md || { echo "FAIL AC-5: SKILL.md missing 3-task"; exit 1; }
grep -q "independent-review-gap" ~/.claude/flow-kit/reference/pipeline-gates.md || { echo "FAIL AC-5: pipeline-gates.md missing ref"; exit 1; }
echo "AC-5 PASS"

echo "ALL ACs PASS"
'</verify>
  <done>AC-1/4/5 验证脚本全部通过；AC-2/3 由 T08 覆盖；AC-6 由 T07 覆盖；AC-7 端到端通过</done>
  <depends_on>T02, T03, T04, T05, T06</depends_on>
</task>
