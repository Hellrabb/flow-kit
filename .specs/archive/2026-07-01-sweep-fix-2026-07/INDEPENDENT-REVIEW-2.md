# 独立审查 · 阶段 2

## L2 盲审

### 🔴 R1 · PHASE_ARTIFACTS 映射与既存代码完全不符：全部 7 个 phase 的产物映射均错误，实施即破坏 AC-2

**Symptom（症状）**：DESIGN.md:131-139 定义的 `declare -A PHASE_ARTIFACTS` 关联数组将 phase 映射到产物集合，但与既存代码 `flow-kit-artifacts.sh:44-130` 中 `fk_artifact_check()` 的实际分支逻辑逐项对比，全部 7 个 phase 的映射均不相同：

| Phase | 既存代码实际检查 | DESIGN.md 提议 |
|-------|-----------------|---------------|
| 1 | `CHANGE.md` | `REQUIREMENT.md` |
| 2/2a | `CHANGE.md` + `REQUIREMENT.md` | `DESIGN.md ADR/` |
| 3 | `REQUIREMENT.md` + `DESIGN.md` | `TASK.md` |
| 4 | `REQUIREMENT.md` + `DESIGN.md` + `TASK.md` + 按 task_id 条件查 SUMMARY | `*-SUMMARY.md` |
| 5 | `REQUIREMENT.md` + `DESIGN.md` + `TASK.md` + 统计 SUMMARY 文件数 | `TEST.md` |
| 6 | `TEST.md` | `REVIEW.md` |
| 7 | `REVIEW.md` | `CHANGELOG.md SUMMARY.md` |

此外，既存代码有 4 个设计未覆盖的关键特性：
- **累积检查**：每个 phase 的 case 分支会重复检查前面阶段的所有产物（如 phase 5 同时检查 REQUIREMENT.md / DESIGN.md / TASK.md），不是只检查当前 phase "新增"的产物
- **Phase 2a 变体**：既存代码匹配 `2|2a)`，DESIGN 只有 `["2"]`
- **Phase 4 条件逻辑**：根据 `.flow-active.task_id` 动态查找 `*-SUMMARY.md`，无法用静态数组表达
- **Phase 5 计数逻辑**：`find ... -name "*-SUMMARY.md" | wc -l` 检查 SUMMARY 数量是否 ≥ 1，非简单文件存在性检查

**Source（源头）**：AC-2（REQUIREMENT.md:26-31）要求"行为和返回值与改造前一致，所有现有 bats 测试（test_flow_artifacts.bats）全部通过"。DESIGN.md 第 2.3 节展示的"变更前"代码片段（:123-128）是对既有 if/elif 链的简化虚构——它把 phase 1 写成检查 REQUIREMENT.md、phase 2 写成检查 DESIGN.md，但实际代码 `flow-kit-artifacts.sh:44-130` 完全不是这个映射。设计者用了一个错误的心理模型来推导"变更后"的查表结构，导致两个模型都错。

**Consequence（后果）**：若按此设计实施，`fk_artifact_check()` 的全部行为将被破坏：每个 phase 会检查错误的文件，累积检查消失，phase 4 的条件 SUMMARY 逻辑丢失，phase 5 的计数逻辑丢失。`test_flow_artifacts.bats` 中现有的 16 个测试几乎必然全红。AC-2 无法通过。这是阻塞级缺陷——不修则后续实现全部无效。

**Remedy（修补）**：分两步修正 DESIGN.md：

**第一步**：用实际代码推导正确的数组结构。既存逻辑的核心不是"每个 phase 检查一个文件"，而是"phase N 检查 phase 1..N 所有产物的累积"。改表驱动方案建议如下：

```bash
# 每个 phase 需要检查的产物集合（累积）
declare -A PHASE_ARTIFACTS=(
  ["1"]="CHANGE.md"
  ["2"]="CHANGE.md REQUIREMENT.md"
  ["2a"]="CHANGE.md REQUIREMENT.md"
  ["3"]="CHANGE.md REQUIREMENT.md DESIGN.md"
  ["4"]="CHANGE.md REQUIREMENT.md DESIGN.md TASK.md"
  ["5"]="CHANGE.md REQUIREMENT.md DESIGN.md TASK.md"
  ["6"]="CHANGE.md REQUIREMENT.md DESIGN.md TASK.md TEST.md"
  ["7"]="CHANGE.md REQUIREMENT.md DESIGN.md TASK.md TEST.md REVIEW.md"
)
```

但此方案仍无法处理 phase 4 的条件 SUMMARY 检查和 phase 5 的 SUMMARY 计数逻辑——这两者不是简单文件存在性检查，需要特殊分支。**必须在 fk_artifact_check() 内部保留针对 phase 4/5 的特殊处理逻辑**，不能一刀切用循环替代。

**第二步**：修正 DESIGN.md 2.3 节的 before/after 代码示例，使其准确反映既存代码的实际结构和改造后的真实结构。移除虚构的 simplified if/elif 展示，替换为基于 `flow-kit-artifacts.sh:44-130` 的真实引用。

---

### 🟡 R2 · 查表驱动模型过度简化：glob 模式、目录检查、条件逻辑均无法用单一 `check` 循环表达

**Symptom（症状）**：DESIGN.md:141-144 的变更后代码为：
```bash
fk_artifact_check() {
    local files="${PHASE_ARTIFACTS[$phase]}"
    for f in $files; do check "$change_dir/$f"; done
}
```
此循环存在三个缺陷：(a) `*-SUMMARY.md` 作为 shell glob，在双引号内的 `for f in $files` 中不展开，需用 `find` 或 `compgen -G`；(b) `ADR/` 是目录，但既存代码的 `fk_file_nonempty()` 使用 `[[ -f ]]` 测试，目录必然失败；(c) `check` 函数在文档中未定义——既存代码实际调用 `fk_file_nonempty()`，两者签名不同。

**Source（源头）**：经典设计原则"Make it work before you make it pretty"的反面——设计者在未充分理解既有实现的边界条件（目录 vs 文件、glob 展开语义、条件分支）的情况下，就先做了抽象。

**Consequence（后果）**：实施阶段会遇到"数组定义好了但代码写不出来"的困境——开发者在代码层面发现 `ADR/` 无法用 `-f` 检查、`*-SUMMARY.md` 不展开、phase 4 的逻辑完全无法塞进数组。最终要么大幅修改设计（此时已是 4-dev 中途，成本高），要么引入 workaround（破坏设计的一致性）。

**Remedy（修补）**：在 DESIGN.md 中明确以下边界决策：
1. 目录型产物的检查方式（如果用 `-d` 替代 `-f`，需说明为何改变语义；如果坚持 `-f`，则 ADR/ 不能列入 PHASE_ARTIFACTS）
2. glob 模式的展开策略（用 `find`、`compgen -G` 还是拆分到外部逻辑）
3. 条件逻辑（phase 4 的 task_id 驱动 SUMMARY 查找）的处理方式——是保留在 `fk_artifact_check()` 内部作为特例，还是拆分出独立的 helper 函数

---

### 🟡 R3 · DESIGN 静默引入新行为：既存代码不检查 ADR/ 目录，DESIGN 新增但未声明

**Symptom（症状）**：DESIGN.md:132 在 `PHASE_ARTIFACTS["2"]` 中包含了 `ADR/`。但对 `flow-kit-artifacts.sh`（44-130 行）全文搜索，`fk_artifact_check()` 的各个 case 分支均不检查 ADR/ 目录的存在性。`ADR` 字符串仅出现在 `fk_auto_phase()` 的 line 204（用于判断 DESIGN.md 内容是否含架构决策关键字，不是检查 ADR/ 目录）。引入 `ADR/` 到 phase 2 产物检查是一个**新增功能**，而非重构。

**Source（源头）**：AC-2（REQUIREMENT.md:30）要求"行为和返回值与改造前一致"。新增检查项破坏了这一约束，但 DESIGN 未将其作为 scope change 申报。

**Consequence（后果）**：若实施时加入 ADR/ 检查，对于未创建 ADR/ 目录的既有 change（如仅使用了 DESIGN.md 内嵌决策清单），`fk_artifact_check` 会错误报 missing。这导致与既有 change 的兼容性断裂。

**Remedy（修补）**：二选一：(a) 从 PHASE_ARTIFACTS 中移除 `ADR/`，保持行为不变；(b) 若确实要加 ADR/ 检查，在 DESIGN 中单独列为 D7 决策并说明理由，同时在 REQUIREMENT.md 的 scope 中标注为 v1 新增行为。

---

### 🟡 R4 · test_correction_file.bats 仅在风险缓解中被引用，未列入 scope 的新增模块清单

**Symptom（症状）**：DESIGN.md:165 的 R1 风险缓解中写道"新增 `test_correction_file.bats` 覆盖 write→read→clear→exists 全流程"。但 DESIGN.md:39-41 的"新增模块"清单仅列出 `correction-file.sh`、`test_flow_kit_resume.bats`、`test_stop_report_reminder.bats` 三项。`test_correction_file.bats` 不在其中。

**Source（源头）**：一致性原则——同一个文档中，scope 声明段（0.5.1）和风险缓解段（5）对交付物的描述必须一致。不一致意味着部分交付物未受 scope 追踪。

**Consequence（后果）**：实施者可能忽略 `test_correction_file.bats` 的编写（因为 scome 清单没列），导致 R1 的缓解措施不完整——correction-file.sh 的 API 行为缺少测试验证。AC-3 的验证只靠消费者代码清理的 grep（已经不足以验证 API 正确性，见 Phase 1 独立审查 R2），缺少单元测试进一步放大了风险。

**Remedy（修补）**：将 `test_correction_file.bats` 加入 DESIGN.md 0.5.1 的"新增模块"清单。同时确认 AC-3 的验证方式是否需要补充对 correction-file.sh 函数签名的检查（参照 Phase 1 独立审查 R2 的建议：AC-3 拆分为 AC-3a API 存在性 + AC-3b 消费者清理）。

---

### 🟡 R5 · correction_file_write() merge-write 的字段级语义未定义，两个消费者的 JSON schema 不同

**Symptom（症状）**：DESIGN.md:201 定义 `correction_file_write(path, violations_json)` 的合并行为为"merge 已有 violations（去重 by rule+location）"。但两个消费者使用不同的 JSON schema：
- `interactive-ui-check.sh`（`.flow-active.interactive-ui-fix`）的字段是 `gate_type` / `required_tool` / `retry_count`
- `weak-model-compliance.sh`（`.flow-active.correction`）的字段是 `type: "compliance"` / `layer` / `violations[]`

'去重 by rule+location' 的语义仅适用于 compliance 类型的 violations 数组，对 interactive-ui-fix 的字段（`gate_type` + `required_tool` + `retry_count`）无意义。DESIGN 未说明通用函数如何处理这两种不同的 schema，也没有说明 merge 时的冲突解决策略（同名 rule+location 但不同 layer 算重复还是保留？）。

**Source（源头）**：API 设计原则——通用函数的契约必须覆盖所有调用者的使用场景，不能仅针对一个子集设计签名而让另一个调用者"碰巧也能用"。

**Consequence（后果）**：若 `correction_file_write()` 的实现仅按 compliance violations 的 schema 来设计 merge 逻辑，interactive-ui-check 的调用可能产生格式不匹配的 JSON，导致 SessionStart 的 `flow-kit-resume.sh` 解析失败——这正是 CHANGE.md:50 识别出的头号风险。

**Remedy（修补）**：在 DESIGN.md 的 9.3 跨模块契约段补充以下内容：
1. 明确 `correction_file_write()` 的 violations_json 参数结构——是通用 `{"violations": [...]}` 还是调用者自定义任意 JSON？如果是后者，"merge/dedup by rule+location" 就不能写在通用函数的契约中，而应由各调用者自行保证 JSON 结构。
2. 明确 merge 策略：新 violations 是 replace 全部、追加（append）、还是 key 级别的 merge（upsert by rule+location）。写清楚冲突解决规则。
3. 给出 interactive-ui-check 和 weak-model-compliance 各自调用 `correction_file_write()` 的完整示例，包括传入的 JSON 参数。

---

### 🟡 R6 · DESIGN 2.3 节的"变更前"代码是简化虚构，不反映真实代码

**Symptom（症状）**：DESIGN.md:122-128 展示的"变更前（if/elif 链）"代码为：
```
if phase == "1": check REQUIREMENT.md
elif phase == "2": check DESIGN.md
elif phase == "3": check TASK.md
```
但实际代码 `flow-kit-artifacts.sh:44-130` 中 phase 1 检查的是 CHANGE.md（不是 REQUIREMENT.md），phase 2 检查 CHANGE.md + REQUIREMENT.md（不是 DESIGN.md），phase 3 检查 REQUIREMENT.md + DESIGN.md（不是 TASK.md）。且实际代码有 4 个不在简化版中的特性：累积检查、2a 变体、条件 SUMMARY、SUMMARY 计数。

**Source（源头）**：设计审查的基本要求——before/after 对比必须基于真实代码，不能用"想象中的简化版"替代。错误的前置条件导致错误的后置方案。

**Consequence（后果）**：审查者和其他读者会基于这个错误的 before 状态来判断 after 方案的正确性，形成"方案看起来合理"的虚假共识。这种共识在实施阶段接触到真实代码时会瞬间瓦解。

**Remedy（修补）**：将"变更前"代码替换为对 `flow-kit-artifacts.sh:44-130` 的结构化描述（不需要逐行复制 86 行代码，但需准确列出每 phase 的检查项和特殊逻辑）。或者改为引用式："参见 flow-kit-artifacts.sh:44-130 fk_artifact_check() 的 case 分支"。

---

### 🟢 R7 · 段号跳跃：6 直接跳到 9，缺少 7 和 8

**Symptom（症状）**：DESIGN.md 的章节序号为 0 → 0.5 → 1 → 2 → 3 → 4 → 5 → 6 → 9。第 7 和第 8 节缺失。

**Source（源头）**：文档格式完整性——段号跳跃暗示可能遗漏了某些计划中的章节，或模板要求 9 个段但未填满。

**Consequence（后果）**：无功能影响，但降低文档可信度——读者可能怀疑其他章节是否也有跳过的内容。

**Remedy（修补）**：若 7/8 段确实不需要，将 9 重编号为 7（保持连续）。若 9 是模板固定编号（如"架构沉淀建议"固定在第 9 位），在图例或模板说明中标注 7/8 段为"保留/不适用"。

---

### 🟢 R8 · jq_atomic_write 的前置条件（文件须已存在）与 correction_file_write 的首次写入场景冲突

**Symptom（症状）**：DESIGN.md 0.5.2 声明 `correction-file.sh` 沿用 `common.sh::jq_atomic_write()`。但 `jq_atomic_write()` 的实现（`common.sh:160-164`）有一个硬前置条件：`[[ ! -f "$target" ]] && return 1`——目标文件必须已存在。在 correction file 的首次写入场景中，文件尚不存在，`jq_atomic_write` 会直接返回 1，导致 `correction_file_write()` 的首次调用失败。

**Source（源头）**：接口适配性——声称复用一个既有函数，但未验证函数的前置条件是否与新调用场景兼容。

**Consequence（后果）**：首次调用 `correction_file_write()` 时写入失败，correction 机制静默失效。弱模型跳过交互 gate 后不会被矫正记录，SessionStart 无法注入修复指令。

**Remedy（修补）**：在 DESIGN.md 中明确：correction_file_write 对于不存在的文件应走"创建"路径（直接 `echo "$json" > "$path"`），仅在文件已存在时使用 merge-write。或者给 `jq_atomic_write` 添加文件不存在时的创建逻辑——但这会改变既存函数的语义，影响其他调用者。

---

### 🟢 R9 · HOOK_MODULE_NAMES 数组内容硬编码了当前 14 个模块的精确拼写——未来新增模块若拼写不同，消费者静默失败

**Symptom（症状）**：DESIGN.md:204 将 `HOOK_MODULE_NAMES` 数组内容写死为 `(00-gate 01-transcript-parse ... 99-report)`。数组的定义位置（`common.sh`）解决了"多源重复"问题，但数组内容本身仍是手工维护的字符串列表，(a) 新增模块时拼写错误不会被编译器发现，(b) 序号命名约定（如 N0-gate）是约定俗成而非结构化约束。

**Source（源头）**：设计原则"Make invalid states unrepresentable"——如果能从文件系统的实际文件名推导出模块列表（`ls hooks/stop/[0-9]*.sh | sed ...`），则不存在拼写不同步的可能。当前的数组方案将"维护负担"从"两处对不齐"降为"一处写错"，但没有消除。

**Consequence（后果）**：未来新增 `30-new-check.sh` 但数组中误写为 `30-new_check.sh`（下划线 vs 连字符），`install_hooks.sh` 和 `package-flow-kit.sh` 都会引用错误的文件名——两处都错，但错得一致（不会发现不一致）。AC-1 的验证方式也难以捕捉这种错（因为"列表只在一处"的约束已满足）。

**Remedy（修补）**：考虑在 `common.sh` 中增加一个轻量验证函数，如 `hook_module_names_valid()`，在数组定义后检查每个名字是否实际存在对应的 hook 脚本文件（`[[ -f "${HOOK_BASE_DIR}/stop/${name}.sh" ]]`），或接受当前方案但将此项风险写入 DESIGN 第 5 节的风险清单。

---

**Verdict**: fail
