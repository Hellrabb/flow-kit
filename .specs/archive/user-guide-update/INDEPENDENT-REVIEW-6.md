# 独立审查 . 阶段 6

## L2 盲审

### 🔴 R1 . AC-3 auto-checkpoint prompt 层未实现：REVIEW.md 误判为已覆盖
**Symptom**: REVIEW.md 声称 AC-3 由 "checkpoint-lib.sh + 8 prompts PCSC + PreToolUse hook 集成" 覆盖，状态标记为 ✅。但实际检查 `flow-kit-bundle/flow-kit/prompts/*.md` 全部 14 个 prompt 文件，**零个**文件包含 `auto-checkpoint` / `interrupt.checkpoint_at` / `checkpoint_write` 关键词。TASK.md 中的 T07（向 15 个 prompt 的 PCSC 段追加 auto-checkpoint 指令）实际状态为 **UNDONE**。
**Source**: 跨对照验证：（1）REVIEW.md AC-3 行；（2）TASK.md T07 描述；（3）`grep -rl "auto-checkpoint\|interrupt.checkpoint_at\|checkpoint_write" flow-kit-bundle/flow-kit/prompts/*.md` 返回空。
**Consequence**: 用户指南描述了 auto-checkpoint 的 prompt 层指令（每个阶段 PCSC 末尾自动写入 checkpoint），但 AI 在实际执行时收不到任何 auto-checkpoint 指令——prompt 模板中完全缺失该自检项。AC-3 的 4 种触发场景（Write/Edit、测试失败、阶段切换、toll-gate 暂停）在 prompt 层**全部不工作**。
**Remedy**: 执行 T07，向全部 14 个 prompt 文件（或至少主要阶段 prompt：1-requirement, 2-design, 3-task, 4-dev, 5-test, 6-review, 7-integration）的 PCSC 表末尾追加 auto-checkpoint 自检行。格式参照 DESIGN.md D3 和 TASK.md T07 action 段给出的模板。完成后用 `grep -rl "auto-checkpoint" flow-kit-bundle/flow-kit/prompts/ | wc -l` 验证 ≥ 7 个文件被修改。

---

### 🔴 R2 . AC-3 auto-checkpoint hook 层未实现：REVIEW.md 误判为已集成
**Symptom**: REVIEW.md 声称 "PreToolUse hook 集成" 已完成。但实际检查 `flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh`，**零处**包含 `checkpoint` / `interrupt` / `checkpoint_write` / `checkpoint_lib` 引用。TASK.md 中的 T08（修改 PreToolUse hook 集成 checkpoint-lib.sh 兜底写入）实际状态为 **UNDONE**。
**Source**: 跨对照验证：（1）REVIEW.md AC-3 行；（2）TASK.md T08 描述；（3）`grep -n "checkpoint\|interrupt" flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh` 返回 0 匹配。
**Consequence**: DESIGN.md D1 定义的双层防护（prompt 层 + hook 层兜底）完全缺失 hook 层。R1 已证明 prompt 层也未实现，因此 auto-checkpoint 的**双层均为空白**——用户指南描述的功能实际上完全不存在于运行时代码中。这对依赖 auto-checkpoint 进行中断恢复的用户是灾难性的：中断后 `.flow-active.interrupt` 永远是旧值或空。
**Remedy**: 执行 T08，在 `independent-review-gate.sh` 中追加 auto-checkpoint 兜底逻辑（参照 TASK.md T08 action 段）：
- 检测 Write/Edit 工具调用 → `source checkpoint-lib.sh` → `checkpoint_write(file, "edit $file")`
- 检测 Bash exit≠0 → `checkpoint_write("", "test failed: $cmd", "$cmd")`
- 检测 jq .goal.current_phase write → `checkpoint_write("", "phase transition to $phase")`
完成后用 `bash -n` 验证语法 + `grep -c "checkpoint_write"` 验证引用存在。

---

### 🔴 R3 . AC-5 中断恢复上下文注入未实现：GO.md 不存在于 bundle
**Symptom**: REVIEW.md 声称 AC-5 由 "GO.md 路由 '继续' + 步骤1 interrupt 读取" 覆盖，状态标记为 ✅。但实际检查 `flow-kit-bundle/flow-kit/prompts/` 目录，**GO.md 文件根本不存在**。`ls flow-kit-bundle/flow-kit/prompts/` 列出 0-change.md 到 M-health.md 共 14 个 prompt 文件 + 1 个 independent/ 目录，无 GO.md。TASK.md 中的 T10（更新 GO.md 中断恢复路由声明）无法验证且极可能 **UNDONE**。
**Source**: 跨对照验证：（1）REVIEW.md AC-5 行；（2）TASK.md T10 描述；（3）`test -f flow-kit-bundle/flow-kit/prompts/GO.md` 返回 false；（4）`ls flow-kit-bundle/flow-kit/prompts/` 列表中无 GO.md。
**Consequence**: 用户指南描述的中断恢复流程（`/flow-go 继续` → GO.md 路由命中最优先的"继续"条目 → 注入 interrupt 上下文）的关键环节——GO.md 路由声明——在分发包中**完全不存在**。中断恢复路径断裂：即使 `.flow-active.interrupt` 非空，路由引擎也无法找到"继续"入口来注入上下文。
**Remedy**: （1）确认 GO.md 在源码树中的实际位置（可能在 `~/.claude/flow-kit/prompts/GO.md` 或其他路径）；（2）执行 T10，修改 GO.md 路由表中"继续"条目，加入 interrupt 字段读取 + 上下文注入逻辑；（3）确保修改后的 GO.md 被同步到 `flow-kit-bundle/flow-kit/prompts/` 中或打包脚本正确包含。

---

### 🔴 R4 . AC-6 文档-代码一致性严重违反：文档描述功能但代码未实现
**Symptom**: 用户指南（FLOW-KIT-用户指南.md 第 1270-1288 行）详细描述了 auto-checkpoint 的双层防护机制（prompt 层 + hook 层）、4 种触发场景、原子写入策略、JSON 校验等。但 R1+R2 已证明 prompt 层和 hook 层均未实现。同时 GO.md 中断恢复路由（AC-5）也不存在。用户指南描述了一个**实际上不工作的功能**。
**Source**: 用户指南 §auto-checkpoint 自动触发（第 1270-1288 行） vs 实际代码验证（R1/R2/R3）。
**Consequence**: 用户根据文档操作时会发现 auto-checkpoint 从未触发、中断恢复流程无法走通。这直接违反 AC-6（"命令行为与文档描述一致"）。更严重的是，用户可能依据文档设计依赖 auto-checkpoint 的工作流，在中断后丢失上下文。
**Remedy**: 在 R1/R2/R3 修复完成并通过端到端验证之前，建议在用户指南 auto-checkpoint 章节头部增加醒目警告：`> ⚠️ 当前版本 auto-checkpoint 功能正在开发中，prompt 层和 hook 层尚未集成。手动 /flow checkpoint 可用。` 或直接执行 T07/T08/T10 完成全部实现。

---

### 🟡 R5 . checkpoint-lib.sh：checkpoint_clear 缺少 JSON 校验，与 checkpoint_write 不一致
**Symptom**: `checkpoint_write()`（第 52 行）在 `mv` 之前调用 `checkpoint_validate` 对 `${FLOW_ACTIVE}.tmp` 做 `jq empty` 校验，校验失败则丢弃并返回 1。但 `checkpoint_clear()`（第 113-126 行）直接 `mv` 而不校验临时文件的 JSON 合法性。
**Source**: `hooks/stop/lib/checkpoint-lib.sh` 第 52 行（checkpoint_write 有 validate） vs 第 124 行（checkpoint_clear 无 validate）。
**Consequence**: 虽然 `jq '.interrupt = null | .updated_at = $ts'` 产生非法 JSON 的概率极低（仅当输入文件本身就非法时），但若 `.flow-active` 因外部原因（磁盘错误、手动编辑损坏）已是非法的 JSON，`checkpoint_clear` 会静默用非法 JSON 覆盖合法备份，导致状态文件不可恢复。REQUIREMENT.md NFR 可靠性要求"写入后 MUST 校验 JSON 合法性"——`checkpoint_clear` 未满足此 NFR。
**Remedy**: 在 `checkpoint_clear` 的 `mv` 之前加入与 `checkpoint_write` 相同的校验：
```bash
if ! checkpoint_validate "${FLOW_ACTIVE}.tmp"; then
  echo "[checkpoint] WARNING: JSON validation failed after clear, discarding" >&2
  rm -f "${FLOW_ACTIVE}.tmp"
  return 1
fi
mv "${FLOW_ACTIVE}.tmp" "$FLOW_ACTIVE"
```

---

### 🟡 R6 . test_checkpoint.bats 原子性测试不完整：未真正测试 checkpoint_write 失败保留旧值
**Symptom**: 测试用例 "checkpoint_write preserves old value on JSON validation failure"（第 124-141 行）的测试逻辑是：(1) 正常写一次 checkpoint；(2) 手动 `echo "not json" > .flow-active.tmp` 制造非法 JSON；(3) 调用 `checkpoint_validate .flow-active.tmp` 确认返回 1；(4) 验证 `.flow-active` 旧值未变。但步骤 (3) 只测试了 `checkpoint_validate` 函数本身，**未调用 `checkpoint_write` 函数**，因此未真正验证 `checkpoint_write` 在遇到非法 JSON 临时文件时是否保留旧值。测试注释（第 131-133 行）也承认此局限："我们直接测试 validate 函数保护"。
**Source**: `test/test_checkpoint.bats` 第 124-141 行。
**Consequence**: 核心可靠性需求（REQUIREMENT.md NFR："auto-checkpoint 写入失败时 MUST 保留旧值不变"）的测试覆盖存在假阳性——测试声称覆盖了原子性保护，但实际上只验证了校验函数本身，未走完整的 `checkpoint_write` 失败路径。
**Remedy**: 重写该测试用例以真正调用 `checkpoint_write` 并触发其校验失败路径。可通过以下方式之一实现：(a) 在 `checkpoint_write` 执行期间将 `.flow-active.tmp` 替换为非法内容（利用 `FLOW_ACTIVE` 环境变量指向一个已损坏的路径）；(b) 为 `checkpoint_write` 添加可选的 mock 注入点；或 (c) 构建一个会导致 jq 输出非法 JSON 的边界场景。同时将测试名称改为准确描述实际测试内容，或拆分为两个独立测试：一个测 `checkpoint_validate`，一个测 `checkpoint_write` 的失败回滚。

---

### 🟡 R7 . REVIEW.md 漏判：未发现 T07/T08/T10 未完成
**Symptom**: REVIEW.md 对 AC-3 和 AC-5 均标记为 ✅（已覆盖），但 T07（prompt PCSC 修改）、T08（PreToolUse hook 集成）、T10（GO.md 中断恢复路由）三项任务实际均未完成。REVIEW.md 未通过逐一对照 TASK.md 任务清单验证每项任务的实际产出。
**Source**: REVIEW.md Spec 合规表（AC-3/AC-5 行） vs 实际代码检查（R1/R2/R3）。
**Consequence**: 主 agent 的自评 REIVEW.md 给后续阶段（Phase 7 INTEGRATION）传递了错误信号——认为 auto-checkpoint 已完整实现可归档，实际核心功能缺失。若按此 REVIEW 归档，分发包将包含一个不完整的 auto-checkpoint 实现（仅有 checkpoint-lib.sh 库文件，无 prompt 指令、无 hook 集成、无 GO.md 路由）。
**Remedy**: REVIEW.md 应：(1) 修正 AC-3 状态为 ❌ 或 ⚠️（部分完成：checkpoint-lib.sh 存在但 prompt/hook 层缺失）；(2) 修正 AC-5 状态为 ❌（GO.md 不存在于 bundle）；(3) 在风险段明确列出 T07/T08/T10 为未完成任务，阻塞 Phase 7 归档。

---

### 🟢 R8 . checkpoint-lib.sh：checkpoint_dedup_check 三次独立 jq 调用可合并
**Symptom**: `checkpoint_dedup_check()`（第 65-98 行）通过三次独立 `jq` 调用分别提取 `last_file`（第 74 行）、`last_type`（第 75 行）、`last_ts`（第 76 行），每次读取并解析 `.flow-active` 文件。
**Source**: `hooks/stop/lib/checkpoint-lib.sh` 第 74-76 行。
**Consequence**: 三次 jq 调用意味着三次文件读取和三次 JSON 解析。虽然 `.flow-active` 文件很小（通常 < 2KB），性能影响可忽略，但在两次 jq 调用之间文件可能被外部修改（TOCTOU），导致 `last_file`、`last_type`、`last_ts` 来自不一致的快照。
**Remedy**: 合并为单次 jq 调用：
```bash
read last_file last_type last_ts <<< "$(jq -r '[.interrupt.active_file // "", .interrupt.last_action // "", .interrupt.checkpoint_at // ""] | @tsv' "$FLOW_ACTIVE" 2>/dev/null)"
```
`last_type` 仍需要后续 `awk '{print $1}'` 提取，但至少 `last_file` 和 `last_ts` 来自同一原子快照。

---

### 🟢 R9 . REVIEW.md 计数不一致："8 prompts PCSC" vs 实际 14 个 prompt 文件
**Symptom**: REVIEW.md 称 "8 prompts PCSC" 已修改。TASK.md T07 称修改目标为 15 个 prompt。实际 `flow-kit-bundle/flow-kit/prompts/` 目录含 14 个 `.md` prompt 文件（不包括 GO.md）。三个数字互不一致（8 vs 15 vs 14），且实际修改数为 0。
**Source**: REVIEW.md 代码质量段 "8 prompts PCSC" vs TASK.md T07 "15 个 prompt" vs `ls flow-kit-bundle/flow-kit/prompts/*.md | wc -l` = 14。
**Consequence**: 数字不一致表明 REVIEW.md 的作者未实际检查 prompt 文件修改情况，而是基于假设或错误记忆填写。这削弱了整个 REVIEW.md 的可信度。
**Remedy**: 修正 REVIEW.md 中所有涉及 prompt 数量的描述，或改为实际完成状态（0/14 已修改）。

---

### 🟢 R10 . checkpoint-lib.sh 函数文档注释可改进
**Symptom**: `checkpoint_write` 的注释（第 17-19 行）说明了参数含义但未说明返回值约定（0=成功或去重跳过，1=失败）。`checkpoint_dedup_check` 注释（第 62-64 行）说明了返回值含义（0=可写入，1=跳过），这一点做得更好。`checkpoint_clear` 缺少参数和返回值文档。
**Source**: `hooks/stop/lib/checkpoint-lib.sh` 各函数头部注释。
**Consequence**: 调用方（未来可能扩展的其他 hook 模块）不清楚哪些返回值是错误、哪些是正常跳过，可能导致错误处理逻辑误判。
**Remedy**: 为所有 4 个函数补充完整的返回值文档。特别是 `checkpoint_write` 应明确说明：返回 0=成功写入或去重跳过（非错误），返回 1=写入失败（需关注）。

---

**Verdict**: fail

**总结**: REVIEW.md 声称全部 6 条 AC 通过，但实际代码验证发现 AC-3（auto-checkpoint 4 种触发）和 AC-5（中断恢复上下文注入）的**关键实现组件完全缺失**：14 个 prompt 文件零处 auto-checkpoint 引用（T07 UNDONE），PreToolUse hook 零处 checkpoint 集成（T08 UNDONE），GO.md 在 bundle 中不存在（T10 不可验证）。AC-6 因文档描述了不存在的功能而自动违反。REVIEW.md 未发现这 3 项任务缺口，存在严重漏判。checkpoint-lib.sh 自身质量尚可（语法正确、原子写入模式正确），但 `checkpoint_clear` 缺少 JSON 校验（NFR 违反）且测试的原子性用例为弱测试。建议在 R1/R2/R3 修复完成前，BLOCK Phase 7 归档。

---

## L3 盲审（deepseek-v4-flash[1m] 外部模型 · 2026-07-07 01:38）

> 自动生成于 2026-07-07 01:38。由 l3-review.sh 写入。

### 审查结论

```json
{"critical":[{"file":"hooks/stop/lib/checkpoint-lib.sh","issue":"文件内容不完整，函数 `checkpoint_validate` 被截断（仅显示 `checkpo`），导致无法运行和验证完整性","why":"工件中该文件末尾缺失，任何尝试 source 该文件都会报语法错误或未定义函数，直接破坏 auto-checkpoint 核心逻辑","fix":"补充完整文件内容，确保所有函数完整定义，并重新生成 diff"},{"file":"工件整体","issue":"spec 中声明的 auto-checkpoint 触发条件（4 种）、PreToolUse hook 集成、prompt 层指令、GO.md 中断恢复路由等均无对应代码实现","why":"文档声称已实现，但工件仅包含 checkpoint-lib.sh 单个库文件，缺乏 hook 调用点、prompt 模板修改和 GO.md 路由条目，导致 AC-3/AC-4/AC-5 实际未覆盖","fix":"实现 PreToolUse hook 调用 checkpoint-lib.sh 的逻辑、更新 8 个 prompts PCSC 条目、修改 GO.md 增加中断恢复路由，并提供完整代码"}],"major":[{"file":"test_checkpoint.bats","issue":"工件中未包含该测试文件，但主 agent REVIEW.md 声称有 11 个测试且通过","why":"缺少测试文件无法验证 checkpoint-lib.sh 的正确性和原子写入、去重等逻辑，构成交付质量风险","fix":"在工件中提供完整的测试文件 test_checkpoint.bats，并确保其通过"},{"file":"工件整体","issue":"gate_config、独立审查四层架构、Hook 31/32 等新功能仅有文档描述，无任何 bash 代码、hook 配置或 prompt 修改","why":"这些功能属于重大扩展，仅靠文档更新无法实现，导致 spec 合规严重不足，且后续维护需额外补充代码","fix":"为每一项功能提供对应的 hook 脚本、lib 函数、prompt 模板或配置变更，确保文档与代码一致"}],"minor":[{"file":"hooks/stop/lib/checkpoint-lib.sh","issue":"未处理 FLOW_ACTIVE 文件不存在的情况，jq 读取会报错但被静默吞掉；原子写入时若文件不存在会失败","why":"生产环境首次使用或文件被删除时可能导致 checkpoint 写入静默失败","fix":"在开头检查文件是否存在，若不存在则用 jq -n 创建初始 JSON 结构；或者使用 `if [[ ! -f "$FLOW_ACTIVE" ]]; then echo '{}' > "$FLOW_ACTIVE"; fi`"},
{"file":"hooks/stop/lib/checkpoint-lib.sh","issue":"checkpoint_dedup_check 中使用 awk 提取 action 第一个词作为类型，但如果 action 为空或非标准格式可能导致误判","why":"edge case 可能影响去重逻辑，导致不必要的写操作或跳过","fix":"增加空值检查，定义更明确的类型提取规则（如按空格分割取第一个非空字段）"}],"verdict":"fail","summary":"工件存在两项 critical 问题：checkpoint-lib.sh 文件被截断不完整，且 auto-checkpoint 核心触发逻辑（hook 集成、prompt 指令）完全缺失。spec 中最关键的 AC-3/4/5 实际无代码覆盖。整体质量不满足通过条件。"}
```
