# TASK: L3 独立审查全面修复

- **Change ID**: l3-comprehensive-fix
- **关联**: `@.specs/l3-comprehensive-fix/REQUIREMENT.md`、`@.specs/l3-comprehensive-fix/DESIGN.md`

---

## 波次划分

```
Wave 1 (parallel): T01[P], T02[P], T03[P], T04[P], T05[P]
Wave 2 (parallel): T06, T07, T08        (depends on T01, T02)
Wave 3:            T09                   (depends on T06, T07, T08)
Wave 4 (parallel): T10[P], T11[P], T12[P] (depends on Wave 2)
Wave 5:            T13                   (depends on Wave 4)
```

> Wave 1 = 独立基础件 + 独立修复 | Wave 2 = hook 集成 | Wave 3 = prompt 加固 | Wave 4 = 测试 | Wave 5 = 回归验证

---

## 任务清单

```xml
<task id="T01" parallel="true" status="done">
  <name>fk_resolve_phase() 统一 phase 解析函数</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/common.sh
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh（参考 line 136-139 pipeline-aware 逻辑）
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/common.sh
  </write_files>
  <action>
    在 common.sh 中新增 fk_resolve_phase() 函数：
    - 读 .flow-active JSON
    - 若 goal.scope == "pipeline" 且 goal.current_phase ∈ {1,2,3,5,6,7} → 输出 current_phase
    - 否则 → 输出 .phase
    - 见 DESIGN D7 + §3.1 决策树
  </action>
  <verify>bash -c 'source flow-kit-bundle/hooks/stop/lib/common.sh && type fk_resolve_phase &>/dev/null && echo "OK"'</verify>
  <done>fk_resolve_phase() 函数可被 source 后调用，pipeline/单阶段模式均返回正确 phase（AC-7）</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true" status="done">
  <name>l2-detect.sh — L2 未完成检测 + 一键派发命令生成 lib</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/common.sh
    flow-kit-bundle/hooks/stop/lib/l3-review.sh（参考共享 lib 模式）
    flow-kit-bundle/flow-kit/prompts/independent/L2-blind-review.md（参考 L2 审查参数）
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/l2-detect.sh
  </write_files>
  <action>
    新建 l2-detect.sh，提供两个函数：
    - l2_detect_missing(phase, change_id): 检查 INDEPENDENT-REVIEW-<phase>.md 是否含 L2 段 → 返回 0=已完成, 1=缺失
    - l2_dispatch_prompt(phase, change_id): 生成一键 Agent 命令模板（含 subagent_type + description + prompt 骨架）
    见 DESIGN D4 + D5
  </action>
  <verify>bash -c 'source flow-kit-bundle/hooks/stop/lib/l2-detect.sh && type l2_detect_missing && type l2_dispatch_prompt && echo "OK"'</verify>
  <done>l2-detect.sh 提供 L2 缺失检测 + 派发命令生成，两个函数均可调用（AC-4, AC-5）</done>
  <depends_on></depends_on>
</task>

<task id="T03" parallel="true" status="done">
  <name>L3 智能截断算法实现（l3-review.sh）</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    flow-kit-bundle/hooks/stop/lib/common.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
  </write_files>
  <action>
    在 l3-review.sh 中新增 smart_truncate() 函数，替换现有 head -c 硬截断：
    - 两遍扫描：① 索引收集所有 ##/### 标题行 + Given/When/Then AC 行；② 按标题段填充至 max_chars
    - 硬约束：所有标题行必须保留；所有 AC Given/When/Then 行完整保留
    - 截断标记：原始大小 / 截断后大小 / 被移除的章节标题列表
    - 降级：单条 AC > 2000 chars → 保留但标注
    见 DESIGN D2 + §2.3 算法伪代码
  </action>
  <verify>bash -c 'source flow-kit-bundle/hooks/stop/lib/l3-review.sh && type smart_truncate &>/dev/null && echo "OK"'</verify>
  <done>l3-review.sh 使用 smart_truncate() 替代 head -c，截断保留标题+AC，输出截断元信息（AC-2）</done>
  <depends_on></depends_on>
</task>

<task id="T04" parallel="true" status="done">
  <name>L3 截断测试夹具 + done 校验边缘值修复</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/done-validation.sh
    .specs/l3-comprehensive-fix/REQUIREMENT.md（AC-2 测试夹具定义）
    .specs/l3-comprehensive-fix/DESIGN.md（§7.2 测试清单）
  </read_files>
  <write_files>
    test/fixtures/l3-truncation-30k.md
    flow-kit-bundle/hooks/stop/lib/done-validation.sh
  </write_files>
  <action>
    1. 创建 test/fixtures/l3-truncation-30k.md：30KB REVIEW.md，含 3 个故意植入缺陷（缺失 AC 验证 + 错误路径 + scope 不一致）
    2. 在 done-validation.sh 中确保 fk_validate_done_marker() 严格校验 6 键 KVP（phase/change_id/written_by/L2_verdict/L3_verdict/artifacts），缺必需键 → fail
    见 AC-2 + AC-6
  </action>
  <verify>wc -c test/fixtures/l3-truncation-30k.md | awk '{exit $1>=30000?0:1}' && bash -c 'source flow-kit-bundle/hooks/stop/lib/done-validation.sh && type fk_validate_done_marker &>/dev/null && echo "DONE_VALIDATION OK"'</verify>
  <done>30KB 测试夹具可用；done-validation.sh 可 source；done 校验正确拒绝缺必需键的 .done 文件（AC-2 夹具, AC-6）</done>
  <depends_on></depends_on>
</task>

<task id="T05" parallel="true" status="done">
  <name>Phase prompt L2 调度段加固</name>
  <read_files>
    flow-kit-bundle/flow-kit/prompts/1-requirement.md
    flow-kit-bundle/flow-kit/prompts/2-design.md
    flow-kit-bundle/flow-kit/prompts/3-task.md
    flow-kit-bundle/flow-kit/prompts/5-test.md
    flow-kit-bundle/flow-kit/prompts/6-review.md
    flow-kit-bundle/flow-kit/prompts/7-integration.md
    flow-kit-bundle/flow-kit/prompts/independent/L2-blind-review.md
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/prompts/1-requirement.md
    flow-kit-bundle/flow-kit/prompts/2-design.md
    flow-kit-bundle/flow-kit/prompts/3-task.md
    flow-kit-bundle/flow-kit/prompts/5-test.md
    flow-kit-bundle/flow-kit/prompts/6-review.md
    flow-kit-bundle/flow-kit/prompts/7-integration.md
  </write_files>
  <action>
    加固 6 个阶段 prompt 的「独立 review 调度」段：
    - 在调度段顶部增加醒目提示："> ⚠️ L2 盲审必须在本阶段产物完成后、toll-gate 前完成。跳过 L2 = gate deny transition。"
    - 确保 Agent 调用模板的参数完整（subagent_type、description、prompt 骨架）
    - Phase 6 的两处引用保持同步
    见 AC-4（L2 被动触发提示加固）
  </action>
  <verify>for p in 1-requirement 2-design 3-task 5-test 6-review 7-integration; do
  grep -q "L2 盲审必须在本阶段产物完成后" "flow-kit-bundle/flow-kit/prompts/${p}.md" && echo "${p}: OK" || echo "${p}: MISSING"
done</verify>
  <done>6 个阶段 prompt 的 L2 调度段均加固（含醒目标注），Agent 模板参数完整（AC-4 prompt 层）</done>
  <depends_on></depends_on>
</task>

<task id="T06" status="done">
  <name>Stop hook 29 号模块修复（phase 检测 + L2 检测）</name>
  <read_files>
    flow-kit-bundle/hooks/stop/29-independent-review.sh
    flow-kit-bundle/hooks/stop/lib/common.sh
    flow-kit-bundle/hooks/stop/lib/l2-detect.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/29-independent-review.sh
  </write_files>
  <action>
    修复 29-independent-review.sh 两处：
    1. Gate 3 phase 检测（line 27,32）：将 jq -r '.phase' 替换为 fk_resolve_phase() 调用（pipeline-aware）
    2. Gate 4 之后插入 L2 检测：gate_config=both 且 L2 未完成 → 调用 l2_dispatch_prompt() 输出派发提示 → exit 0
    见 DESIGN D3 + D4 + §2.1 Stop hook 分支
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/29-independent-review.sh && grep -q "fk_resolve_phase" flow-kit-bundle/hooks/stop/29-independent-review.sh && grep -q "l2_detect_missing\|l2_dispatch_prompt" flow-kit-bundle/hooks/stop/29-independent-review.sh && echo "BEHAVIOR OK"</verify>
  <done>Stop hook 使用 pipeline-aware phase 检测；L2 缺失时输出派发提示（AC-3, AC-4, AC-7）</done>
  <depends_on>T01, T02</depends_on>
</task>

<task id="T07" status="done">
  <name>SessionStart hook 修复（L3 header 匹配 + phase 检测）</name>
  <read_files>
    flow-kit-bundle/hooks/session-start/flow-kit-resume.sh
    flow-kit-bundle/hooks/stop/lib/common.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/session-start/flow-kit-resume.sh
  </write_files>
  <action>
    修复 flow-kit-resume.sh 两处：
    1. line 138: grep 字符串从 "## L3 外部模型审查" → 主匹配 "## L3 盲审" || 兼容 "## L3 外部模型审查"
    2. line 134: phase 读取改用 fk_resolve_phase()（与 Stop hook 一致）
    见 DESIGN D1 + D3
  </action>
  <verify>bash -n flow-kit-bundle/hooks/session-start/flow-kit-resume.sh && grep -q "L3 盲审" flow-kit-bundle/hooks/session-start/flow-kit-resume.sh && grep -q "fk_resolve_phase" flow-kit-bundle/hooks/session-start/flow-kit-resume.sh && echo "BEHAVIOR OK"</verify>
  <done>SessionStart 正确匹配新旧两种 L3 header，pipeline-aware phase 检测（AC-1, AC-7）</done>
  <depends_on>T01</depends_on>
</task>

<task id="T08" status="done">
  <name>PreToolUse gate AC-5 选项②③交互设计实现</name>
  <read_files>
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    flow-kit-bundle/hooks/stop/lib/l2-detect.sh
    flow-kit-bundle/hooks/stop/lib/done-validation.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
  </write_files>
  <action>
    在 PreToolUse gate 中实现 AC-5 完整 3 选项交互：
    - 选项① (已有): 输出一键 Agent 命令模板
    - 选项② (新增): 检测 FLOW_KIT_SKIP_L2=1 环境变量 → 写 .skip-L2-<phase> 标记文件 → 下次 gate 放行
    - 选项③ (已有默认): gate deny + 提示"完成 L2 后重新执行 transition"
    额外：L2 检测段改用 l2_detect_missing() 统一入口（替代内联 grep）
    见 DESIGN D5 + §2.2
  </action>
  <verify>bash -n flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh && grep -q "FLOW_KIT_SKIP_L2" flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh && grep -q "l2_detect_missing" flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh && echo "BEHAVIOR OK"</verify>
  <done>PreToolUse gate 支持 L2 skip 标记 + FLOW_KIT_SKIP_L2 确认；L2 检测统一走 l2-detect.sh（AC-5）</done>
  <depends_on>T02</depends_on>
</task>

<task id="T09" status="done">
  <name>端到端集成验证：pipeline 模式 L2/L3 联动</name>
  <read_files>
    flow-kit-bundle/hooks/stop/29-independent-review.sh
    flow-kit-bundle/hooks/session-start/flow-kit-resume.sh
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    flow-kit-bundle/hooks/stop/lib/l2-detect.sh
    flow-kit-bundle/hooks/stop/lib/done-validation.sh
    flow-kit-bundle/hooks/stop/lib/common.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/29-independent-review.sh
    flow-kit-bundle/hooks/session-start/flow-kit-resume.sh
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    flow-kit-bundle/hooks/stop/lib/common.sh
  </write_files>
  <action>
    端到端集成验证 + 修边：
    - 确保 3 个 hook 之间接口一致（l2-detect.sh 函数签名、done 文件路径构造、phase 获取方式）
    - 确保 fk_resolve_phase() 在 3 处均被调用（不遗漏）
    - 确保 gate_config 值标准化映射（independent/true → both）在 3 处一致
    - 消除重复的 phase_name 映射逻辑（case 1→"1-requirement" etc.），提取为共享辅助函数
    - 修边：日志输出格式统一（module_output + phase + verdict + skip_reason）
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/29-independent-review.sh && bash -n flow-kit-bundle/hooks/session-start/flow-kit-resume.sh && bash -n flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh && echo "SYNTAX OK" && [ $(grep -c "fk_resolve_phase" flow-kit-bundle/hooks/stop/29-independent-review.sh flow-kit-bundle/hooks/session-start/flow-kit-resume.sh flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh) -ge 3 ] && echo "PHASE_CALLS OK"</verify>
  <done>3 个 hook 接口一致、无重复逻辑、日志统一；端到端 L2/L3 联动就绪</done>
  <depends_on>T06, T07, T08</depends_on>
</task>

<task id="T10" parallel="true" status="done">
  <name>bats 测试：phase 检测 + L2 检测</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/common.sh
    flow-kit-bundle/hooks/stop/lib/l2-detect.sh
    test/（参考现有 bats 测试风格）
  </read_files>
  <write_files>
    test/phase-resolution.bats
    test/l2-detect.bats
  </write_files>
  <action>
    编写 bats 测试：
    - phase-resolution.bats (~4 tests): pipeline+current_phase=5→5; 单阶段+.phase=3→3; pipeline+current_phase=5+.phase=6(过期)→5; 无.flow-active→降级.phase=?
    - l2-detect.bats (~4 tests): L2 未完成→ret 1; L2 完成→ret 0; L3-only mode→ret 0; 无 gate_config→ret 0
    见 DESIGN §7.2
  </action>
  <verify>npx bats test/phase-resolution.bats test/l2-detect.bats --formatter tap</verify>
  <done>phase 检测 + L2 检测 bats 测试全部通过（AC-7, AC-4）</done>
  <depends_on>T01, T02, T06, T07, T08</depends_on>
</task>

<task id="T11" parallel="true" status="done">
  <name>bats 测试：done 校验 + L3 header 检测</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/done-validation.sh
    flow-kit-bundle/hooks/session-start/flow-kit-resume.sh
    test/（参考现有 bats 测试风格）
  </read_files>
  <write_files>
    test/done-validation.bats
    test/l3-header-detect.bats
  </write_files>
  <action>
    编写 bats 测试：
    - done-validation.bats (~4 tests): 6 键齐全→pass; 缺 L3_verdict→fail; 缺 L3_summary(非6键)→pass; 空文件→fail
    - l3-header-detect.bats (~3 tests): "## L3 盲审" 匹配; "## L3 外部模型审查" 兼容匹配; 无 header→skip
    见 DESIGN §7.2
  </action>
  <verify>npx bats test/done-validation.bats test/l3-header-detect.bats --formatter tap</verify>
  <done>done 校验 + L3 header 检测 bats 测试全部通过（AC-6, AC-1）</done>
  <depends_on>T04, T07</depends_on>
</task>

<task id="T12" parallel="true" status="done">
  <name>bats 测试：L3 智能截断</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    test/fixtures/l3-truncation-30k.md
    test/（参考现有 bats 测试风格）
  </read_files>
  <write_files>
    test/l3-truncation.bats
  </write_files>
  <action>
    编写 bats 测试 (~4 tests):
    - 30KB fixture 经 smart_truncate() 后所有 ##/### 标题行保留
    - 所有 Given/When/Then AC 行完整保留
    - 输出大小 ≤ 配置的 max_chars
    - 截断标记含原始大小 + 截断后大小 + 被移除章节
    见 DESIGN §2.3 + §7.2
  </action>
  <verify>npx bats test/l3-truncation.bats --formatter tap</verify>
  <done>L3 截断算法 bats 测试全部通过（AC-2 离线部分）</done>
  <depends_on>T03, T04</depends_on>
</task>

<task id="T13" status="done">
  <name>全量回归 + make check + 修边</name>
  <read_files>
    Makefile
    flow-kit-bundle/package-flow-kit.sh
  </read_files>
  <write_files>
    <!-- 仅修边本次已动过的文件：common.sh / l3-review.sh / l2-detect.sh / done-validation.sh / 29-independent-review.sh / flow-kit-resume.sh / independent-review-gate.sh / 6 prompt 文件 / Makefile（如需更新 test target）。禁动清单文件禁止触碰 -->
  </write_files>
  <action>
    1. 运行 npx bats test/ 全量回归，确认 94+ existing tests 不退化，~16 new tests 通过
    2. 运行 make lint（shellcheck），修复本次引入的 warning/error
    3. 运行 make check（test + lint + 打包校验），确保全绿
    4. 若 make check 不覆盖新增测试，更新 Makefile test target
    </action>
  <verify>make check 2>&1 | tail -5</verify>
  <done>全量 bats 通过 + make check 通过；change 验收线达标（AC-all）</done>
  <depends_on>T09, T10, T11, T12</depends_on>
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
