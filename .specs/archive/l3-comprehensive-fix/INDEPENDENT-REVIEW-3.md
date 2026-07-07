# 独立审查 · 阶段 3

## L2 盲审

> 审查日期：2026-07-07 | 审查对象：`.specs/l3-comprehensive-fix/TASK.md` | 参考：REQUIREMENT.md、DESIGN.md

---

### 🟡 R1 · T06-T09 verify 仅做语法检查（bash -n），不验证行为正确性：4 个核心 hook 任务可能"语法 OK 但逻辑错"地通过

**Symptom（症状）**：T06、T07、T08、T09 的 verify 均为 `bash -n <script> && echo "SYNTAX OK"`，仅校验 Bash 语法。这些任务承担了本次 change 最核心的行为变更——T06 将 phase 检测从 `jq -r '.phase'` 改为 `fk_resolve_phase()` 并插入 L2 检测逻辑；T07 修改 grep header 匹配和 phase 读取；T08 实现 AC-5 三选项交互状态机；T09 集成验证接口一致性。bash -n 对拼写错误、遗漏调用、逻辑缺陷、函数签名不匹配等问题零覆盖——所有这些缺陷都只能在 Wave 4/5 的 bats 测试中暴露。

**Source（源头）**：TASK.md T06:159 / T07:179 / T08:202 / T09:231。bats 测试任务（T10-T12）承担了全部行为正确性验证，但 T06-T09 作为其上游依赖却无自验证能力。如果 T06-T09 的任何一个实现错误，下游 bats 测试失败时定位根因需回溯 4 个任务。

**Consequence（后果）**：① 开发者标记 T06 为 done（语法 OK）→ 实际 fk_resolve_phase() 未调用或调用错误 → T10 bats 测试失败时需逐个排查 T01+T06。② 最坏情况：bats 测试本身也可能有 bug（T10-T12 的产物），导致错误实现通过全量测试而不被发现。③ 任务粒度设计假设"每个 task 可独立验证完成"，但 T06-T09 不具备独立可验证性。

**Remedy（修补）**：为 T06-T09 增加轻量级行为验证，不依赖完整 bats 框架。例如：
- T06 verify 追加：`grep -q "fk_resolve_phase" flow-kit-bundle/hooks/stop/29-independent-review.sh`
- T07 verify 追加：`grep -q "L3 盲审" flow-kit-bundle/hooks/session-start/flow-kit-resume.sh`
- T08 verify 追加：`grep -q "FLOW_KIT_SKIP_L2" flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh`
- T09 verify 追加：检查 3 个 hook 中 `fk_resolve_phase` 调用次数 ≥3，且无重复的 `case 1→"1-requirement"` 映射块

---

### 🟡 R2 · T05 verify 是零改动验证——6 个 prompt 文件已含目标匹配字符串，verify 在任务未做任何修改时即通过

**Symptom（症状）**：T05 的 verify（TASK.md:136-138）扫描 6 个 prompt 文件确认含 `独立 review 调度` 字符串。但经验证，全部 6 个文件**当前已含该字符串**（1-requirement.md:1 次, 2-design.md:1 次, 3-task.md:1 次, 5-test.md:1 次, 6-review.md:2 次, 7-integration.md:1 次）。这意味着 verify 在任务未做任何修改时即返回 OK——执行 `touch` 这 6 个文件不改内容也通过。

T05 的实际行动（action）是在调度段**顶部增加醒目标注**：`"> ⚠️ L2 盲审必须在本阶段产物完成后、toll-gate 前完成。跳过 L2 = gate deny transition。"` 这个新增内容完全不被 verify 覆盖。

**Source（源头）**：TASK.md:136-138 verify 使用 `grep -q "独立 review 调度"` 而非 `grep -q "L2 盲审必须在本阶段产物完成后"`（新增文本的特征串）。verify 检查的是"段存在"而非"段内容已加固"。

**Consequence（后果）**：T05 可以零改动标记 done，Prompt 加固实际未发生。但下游 L2 被动触发机制（AC-4）依赖 prompt 中的醒目标注来降低主 agent 跳过 L2 调度的概率——如果标注未实际写入，AC-4 的"prompt 层防线"形同虚设。Hook 层的 T06/T08 仍会输出提示，但缺少 prompt 层的进行中提醒。

**Remedy（修补）**：verify 改为：`for p in 1-requirement 2-design 3-task 5-test 6-review 7-integration; do grep -q "L2 盲审必须在本阶段产物完成后" "flow-kit-bundle/flow-kit/prompts/${p}.md" && echo "${p}: OK" || echo "${p}: MISSING"; done` ——用新增文本的特征串（而非已存在的段标题）作为验证锚点。

---

### 🟡 R3 · T09 缺少 common.sh 写入声明——共享辅助函数提取无处落笔

**Symptom（症状）**：T09 的 action（TASK.md:229）明确要求"消除重复的 phase_name 映射逻辑（case 1→"1-requirement" etc.），提取为共享辅助函数"。但 T09 的 write_files（TASK.md:218-222）仅列出 3 个 hook 脚本（29-independent-review.sh、flow-kit-resume.sh、independent-review-gate.sh），未列出 common.sh——而 common.sh 是放置共享辅助函数的唯一自然位置（T01 已将 `fk_resolve_phase()` 放入 common.sh）。

**Source（源头）**：TASK.md:218-222 write_files 清单 vs TASK.md:229 action 中的"提取为共享辅助函数"需求。如果函数放在 3 个 hook 脚本的任一个中，则不是"共享"——另外 2 个 hook 无法引用。如果放在 common.sh，则必须写入 common.sh。

**Consequence（后果）**：实施者面对此矛盾时有两种可能：(a) 将辅助函数冗余地写进 3 个 hook 各一份（违反 DRY，且 T09 的 action 明确要求消除重复）；(b) 意识到应该写入 common.sh 但担心超出 write_files 约束而不敢写。无论哪种，T09 交付物都不满足其自身 action 标准。

**Remedy（修补）**：T09 write_files 追加 `flow-kit-bundle/hooks/stop/lib/common.sh`。或者，如果 phase_name 映射提取为新独立 lib 文件，则追加其路径。

---

### 🟡 R4 · T04 verify 遗漏 done-validation.sh 修改的验证——AC-6 核心变更无独立校验

**Symptom（症状）**：T04 包含两个交付物：(a) 创建 `test/fixtures/l3-truncation-30k.md` 测试夹具；(b) 在 `done-validation.sh` 中确保 `fk_validate_done_marker()` 严格校验 6 键 KVP（缺必需键 → fail）。T04 的 verify（TASK.md:105）仅验证夹具大小（`wc -c test/fixtures/l3-truncation-30k.md | awk '{exit $1>=30000?0:1}'`），完全未涉及 done-validation.sh 的修改是否正确。

**Source（源头）**：TASK.md:104-105。T04 的 done 描述声称覆盖 AC-6（"done 校验正确拒绝缺必需键的 .done 文件"），但 verify 只覆盖了 AC-2 的夹具部分。

**Consequence（后果）**：done-validation.sh 的 6 键校验修改可能实际未实施、或有 bug，但 T04 标记 done。缺陷留到 T11 的 bats 测试才暴露，增加了返工成本和调试时间。考虑到 done 校验是 gate 放行的关键路径（AC-6 缺 L3_verdict → gate deny），校验实现错误可能导致 pipeline 误放行或误阻塞。

**Remedy（修补）**：T04 verify 追加 done-validation 的快速冒烟测试，例如：`bash -c 'source flow-kit-bundle/hooks/stop/lib/done-validation.sh && type fk_validate_done_marker &>/dev/null && echo "OK"'`。更进一步，可追加一个最小功能的冒烟用例：创建临时 .done 文件（缺 L3_verdict）→ 调用函数 → 断言返回非零。

---

### 🟢 R5 · Wave 4 依赖声明与任务级 depends_on 不一致——波次图写"depends on Wave 2+3"但 T10-T12 不依赖 T09

**Symptom（症状）**：TASK.md:14 波次划分图写"Wave 4 (parallel): T10[P], T11[P], T12[P] (depends on Wave 2+3)"。但各任务实际 depends_on：
- T10: T01, T02, T06, T07, T08（无 T09）
- T11: T04, T07（无 T09）
- T12: T03, T04（无 T09）

即 Wave 4 的三个任务实际均不依赖 Wave 3 的产物 T09（集成验证）。波次图与任务级依赖不一致。

**Source（源头）**：TASK.md:14 波次图 vs TASK.md:256/277/300 各任务 depends_on。波次图可能按"人类直觉"（集成验证后才写测试）画依赖，但任务级 depends_on 正确反映了"bats 测试只需被测试的 lib/hook 存在，不需要集成验证通过"这一工程事实。

**Consequence（后果）**：① 执行者按波次图排期可能不必要地推迟 T10-T12 至 Wave 3 完成后，损失并行度。② 若未来有人仅看波次图调整顺序，可能误认为"T09 必须完成后才能开始 T10"，造成不必要的串行化。不过实际影响较小，因为 T09 本身是轻量集成任务，且 depends_on 字段是正确的权威依赖。

**Remedy（修补）**：波次图改为"Wave 4 (parallel): T10[P], T11[P], T12[P] (depends on T01-T08)"，或直接标注"depends on Wave 2"，与 depends_on 字段一致。

---

### 🟢 R6 · T13 write_files 声明为空 XML 注释，但 action 可能触及 Makefile

**Symptom（症状）**：T13 的 write_files 为 `<!-- 无新增，仅修边已有文件中的 warning/error -->`（TASK.md:310），实际内容为空（XML 注释在解析时视为无内容）。但 T13 的 action（TASK.md:316）说"若 make check 不覆盖新增测试，更新 Makefile test target"——更新 Makefile 就是一个文件写入。同时"修边已有文件中的 warning/error"未指定文件范围，实施者可能阅读所有 shellcheck/lint 报错文件并修改。

**Source（源头）**：TASK.md:309-311 write_files 与 TASK.md:316 action 文本。T13 被设计为收尾任务，范围天然模糊。

**Consequence（后果）**：① 若 shellcheck 报错涉及 DESIGN.md 禁动清单中的文件（如 00-gate.sh），实施者可能"顺手"修复造成越界修改。② Makefile 变更不在 write_files 声明中，code review 时可能被忽略。③ 实际影响较小——T13 作为 Wave 5 最终修边任务，其"仅修边"语义是清晰的，但文件级别的精确度不够。

**Remedy（修补）**：T13 write_files 明确列出："若 Makefile 需更新则加入；仅修边本次 change 已动过的文件（common.sh / l3-review.sh / l2-detect.sh / done-validation.sh / 29-independent-review.sh / flow-kit-resume.sh / independent-review-gate.sh / 6 个 prompt 文件），禁止触碰禁动清单文件"。

---

### 🟢 R7 · TASK.md 第 311 行 write_files 块使用了 HTML/XML 注释语法，在 XML 解析下为空元素

**Symptom（症状）**：TASK.md:310 `<!-- 无新增，仅修边已有文件中的 warning/error -->` 是 XML 注释语法，在 DTD 中 XML 注释不被视为子元素内容。如果工具链解析 `<write_files>` 元素内容（而非原始文本），T13 的 write_files 将显示为空。这可能导致自动化合规检查误报"T13 未声明 write_files 但却有文件写入"。

**Source（源头）**：TASK.md:309-311。其他任务（如 T01-T12）的 write_files 均直接列出文件路径，仅 T13 使用了注释语法作为内容。

**Consequence（后果）**：如果项目以后引入自动化检查（解析 TASK.md 中的 `<read_files>` / `<write_files>` 与 git diff 对比），T13 会触发 false positive。当前影响为零（无此类自动化检查），但这是一个不一致的格式用法，应修正以保持 TASK.md 的格式一致性。

**Remedy（修补）**：将注释改为自描述的空元素声明，或在 write_files 中列出明确的修边文件。例如：`<!-- T13 为修边任务：若引入 shellcheck warning/error，修改对应文件；若无 linter 报错则无写入 -->` 并改为 `（修边，按需）` 文本内容，或直接用清晰的文字描述替代 HTML 注释。

---

**Verdict**: pass

---

## 主 agent 回应

| Ref | 判定 | 行动 |
|-----|------|------|
| R1 | ✅ 采纳 | T06-T09 verify 追加 grep 行为检查（fk_resolve_phase 调用、L3 盲审 header、FLOW_KIT_SKIP_L2、l2_detect_missing），bash -n + 行为断言双层 |
| R2 | ✅ 采纳 | T05 verify 改为检查新增文本特征串 `"L2 盲审必须在本阶段产物完成后"`（替代已存在的 `"独立 review 调度"` 匹配） |
| R3 | ✅ 采纳 | T09 write_files 追加 `flow-kit-bundle/hooks/stop/lib/common.sh` |
| R4 | ✅ 采纳 | T04 verify 追加 done-validation.sh source + type check 冒烟测试 |
| R5 | ✅ 采纳 | Wave 4 依赖标注改为 `(depends on Wave 2)`，与任务级 depends_on 一致 |
| R6 | ✅ 采纳 | T13 write_files 明确列出修边范围（本次已动过的全部文件 + Makefile）+ 禁动清单禁止触碰 |
| R7 | ✅ 采纳 | T13 write_files 注释改为明确范围描述，替代裸 XML 注释 |

**L2 Verdict**: pass（无 🔴 Critical）
**主 agent 确认**: 全部 7 条发现已修复入 TASK.md。
