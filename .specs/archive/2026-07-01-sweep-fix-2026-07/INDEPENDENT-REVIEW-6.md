# 独立审查 · 阶段 6

## L2 盲审

### 🔴 R1 · 合规矫正断裂：`correction_file_write` merge 模式将 JSON 对象变异为数组，`flow-kit-resume.sh` 读取后即删，合规矫正机制完全失效

**Symptom（症状）**：`write_compliance_correction()`（`weak-model-compliance.sh:70-103`）调用 `correction_file_write` 时传入策略 `"layer,rule,location"`（第 97 行）进入 merge 模式。merge 模式内部将输入数据归一化为数组：`jq 'if type == "array" then . else [.] end'`（`correction-file.sh:65`），然后用 `$existing + $new` 合并，结果必然是一个 JSON 数组 `[{type:"compliance", violations:[...], ...}]`，写入文件。而 `flow-kit-resume.sh:94` 读取时用 jq `.type` 查询——jq 无法用字符串索引数组，`// "unknown"` 兜底返回 `"unknown"`；`.violations | length` 同样失败返回 `"0"`。于是走到 `flow-kit-resume.sh:126`——判为"格式异常"——随即 `rm -f` 删除文件（第 129 行）。矫正文件被创建、被检测为破损、被删除，用户永远看不到违规提示。

**Source（源头）**：DESIGN.md §9.3 定义的跨模块契约：`correction_file_write(path, violations_json, dedup_key)` 的语义是对已有 violations 做 merge-dedup。但实现没有区分"调用方传入的是完整 compliance 对象 `{type, violations, written_at}`"还是"裸 violations 数组"。merge 模式把传入数据当裸数组处理，归一化到数组后再拼接，丢失了外层结构。`write_compliance_correction` 把完整 JSON 对象传给 merge 模式，却期望文件保持对象格式——契约错配。

**Consequence（后果）**：合规矫正（weak-model-compliance）是 L1/L2/L3 扫描发现违规后唯一的用户通知渠道。此 bug 使得所有合规违规被静默丢弃——用户在上轮会话中触碰了禁动文件、自检表缺标记、引用幻觉路径，下轮会话开启时没有任何警告。这是**静默功能丧失**，影响安全关键路径（禁动清单执行）。merge 模式自 `correction-file.sh` 创建以来即存在此 bug，但 `write_compliance_correction` 是该模式的唯一调用方——也就是说合规矫正从重构第一天起就是坏的。

**Remedy（修补）**：两种修复方向，推荐方案 A（不改 correction-file.sh API，改调用方）：

方案 A（最小改动）：`write_compliance_correction` 改为仅传 violations 数组，外层包装留在调用方自己做：
```bash
# Before (line 89-97):
merged_json=$(jq -n --arg type "compliance" --argjson violations "$new_violations" --arg timestamp "$timestamp" \
    '{type: $type, violations: $violations, written_at: $timestamp}')
correction_file_write "$COMPLIANCE_CORRECTION_FILE" "$merged_json" "layer,rule,location"

# After:
# Pass violations only to correction_file_write (it does merge+dedup)
correction_file_write "$COMPLIANCE_CORRECTION_FILE" "$new_violations" "layer,rule,location"
# Wrap the merged result back into compliance object format
local merged_violations
merged_violations=$(correction_file_read "$COMPLIANCE_CORRECTION_FILE")
jq -n --arg type "compliance" --argjson violations "$merged_violations" --arg timestamp "$timestamp" \
    '{type: $type, violations: $violations, written_at: $timestamp}' > "$COMPLIANCE_CORRECTION_FILE"
```

方案 B（改 correction-file.sh API）：让 merge 模式接受可选的"wrapper"参数，内部保持 wrapper 结构，仅对 violations 数组做 merge-dedup。改动面更大但 API 语义更清晰。

**独立验证**：已用隔离脚本复现——传入 `{type:"compliance", violations:[{...}], written_at:"..."}` 经 merge 模式后文件内容变为 `[{type:"compliance", violations:[{...}], written_at:"..."}]`，`jq '.type'` 报错 `Cannot index array with string "type"`。复现成功。

---

### 🟡 R2 · 测试文件未跟踪（untracked），`git diff HEAD` 无法捕获 AC-4 交付物

**Symptom（症状）**：`test_flow_kit_resume.bats`、`test_stop_report_reminder.bats`、`test_correction_file.bats` 三个文件存在于文件系统，但 `git status` 显示为"未跟踪的文件"。执行 `git diff HEAD`（本审查的指定工件来源）不包含这些文件。

**Source（源头）**：TASK.md T11/T12/T13 要求创建这三个测试文件。文件已创建（磁盘上存在），但未 `git add`。AC-4 要求"现有 17 个 bats 文件的 176 个断言无回归"——此验证无法通过 diff 完成。

**Consequence（后果）**：如果评审者只依赖 `git diff HEAD`（本审查的指定输入工件），会判定 AC-4 未交付（测试文件不存在于 diff 中）。提交前须 `git add` 这三个文件。此外 bats 未实际运行验证——无法确认新增测试通过、176 个既有断言无回归。

**Remedy（修补）**：提交前执行：
```bash
git add flow-kit-bundle/test/test_correction_file.bats \
        flow-kit-bundle/test/test_flow_kit_resume.bats \
        flow-kit-bundle/test/test_stop_report_reminder.bats
```
并运行 `bats test/` 确认全量通过后再 commit。

---

### 🟡 R3 · Merge 模式 dedup 作用域错误：对 wrapper 对象去重而非对 violations 条目去重

**Symptom（症状）**：即使 R1 的格式 bug 被修复，merge 模式的去重逻辑也存在第二层问题。`correction_file_write` 收到完整 compliance 对象后，normalize 为数组 `[{type:"compliance", violations:[...], ...}]`，然后 `unique_by(.[$fields[]])` 尝试在数组元素级别按 `layer,rule,location` 去重。但 `layer`、`rule`、`location` 是 violations 数组内部每个条目的字段，不是 wrapper 对象的字段。在 wrapper 对象上 `.["layer"]` 返回 null——所有 wrapper 对象在这些字段上都是 null，导致 `unique_by` 认为所有条目都不同（null !== null 在 jq 比较中实际是相等的，但由于每轮的 `written_at` 时间戳不同，wrapper 对象本身就不等）。

**Source（源头）**：`correction-file.sh:67-74`——dedup 逻辑假设输入数据是扁平的 violations 条目数组 `[{rule:..., location:..., fix:...}]`，但 `write_compliance_correction` 实际传入的是包装后的完整对象。契约不匹配：`dedup_key` 参数描述的字段位于 violations 子数组中，但 dedup 作用在 wrapper 对象层。

**Consequence（后果）**：合规矫正文件中的 violations 会随每次会话累积重复（同一违规多轮不合并），文件膨胀 + 用户看到重复的矫正提示。虽然不如 R1 的完全断裂严重，但违反 "dedup by layer,rule,location" 的设计意图。

**Remedy（修补）**：与 R1 绑定修复。方案 A（R1 的方案 A）天然解决此问题——改为只传 violations 数组进入 merge 模式，dedup 就直接作用在正确的层级。同时需要在修复后验证：相同 rule+location 的违规只出现一次。

---

### 🟡 R4 · 主 agent 漏判：REVIEW.md 声明的 AC-3 合规实际不成立

**Symptom（症状）**：REVIEW.md 第 17 行判定 AC-3 ✅ 合规，列出证据"均已 source + delegate"，但没有验证跨模块契约的正确性。具体来说：
- DESIGN.md 风险 R1 明确指出"correction_file_write() 的 merge-write 逻辑与原来不同，导致 flow-kit-resume.sh SessionStart 读取到异常格式"是中概率风险，并声称缓解措施为"新增 test_correction_file.bats 覆盖全流程"
- 但 `test_correction_file.bats` 未实际运行（untracked + bats 未跑），且即使运行了，如果测试只验证 write→read 往返（TASK.md T11 的描述是"写入 2 条 violation，读回验证内容"），可能不会模拟完整合规对象的场景
- 主 agent 没有实际执行端到端验证（write_compliance_correction → flow-kit-resume.sh 读取），仅检查了"文件存在 + source + delegate"的表层证据

**Source（源头）**：审查 checklist——"每条 AC 是否被代码真正覆盖（不是'看起来覆盖'）"。主 agent 做了表层语法检查（source 语句存在、函数调用存在），但没做数据流验证（实际 JSON 结构是否正确传递到消费者）。

**Consequence（后果）**：AC-3 实际未满足（合规矫正路径断裂），但 REVIEW.md 给出 PASS。这导致 change 可能被合入而携带一个静默功能丧失的 bug。

**Remedy（修补）**：修复 R1 bug 后重新验证 AC-3——模拟完整调用链：`scan_l1_rules()` 发现违规 → `write_compliance_correction()` 写入 → `flow-kit-resume.sh` 可正确读取并展示违规。仅修复代码不够，需端到端验证。

---

### 🟡 R5 · AC-1 验证方式无法通过：回退列表触发 grep 误判

**Symptom（症状）**：REQUIREMENT.md 定义 AC-1 验证方式为 `grep -c "00-gate.*01-transcript.*99-report" install_hooks.sh package-flow-kit.sh` 返回 0。`install_hooks.sh:46` 的回退列表（`HOOK_MODULE_NAMES=(00-gate 01-transcript-parse ... 99-report)`）为单行，匹配该 grep 模式，grep 返回 1（非 0）。`package-flow-kit.sh` 的回退列表跨多行，不匹配单行 grep，返回 0。

**Source（源头）**：回退列表是防御性设计（`common.sh` 不可用时的兜底），与"单一来源"目标不矛盾——它只在异常路径激活。但 AC-1 的 grep 验证写得过于严格，未区分"主路径硬编码"和"回退路径硬编码"。

**Consequence（后果）**：严格按 AC-1 验证方式执行会判定为 FAIL；但实际上主路径已正确引用 `HOOK_MODULE_NAMES`。这是 AC 验证方式的精度问题而非实现 bug。若 change gate 依赖自动化 AC 验证脚本，可能造成误拦截。

**Remedy（修补）**：二选一：(a) 修改 AC-1 验证方式——改为检查主路径（非回退分支）是否引用 `"${HOOK_MODULE_NAMES[@]}"` 而非 grep 硬编码字符串；(b) 将回退列表提取为独立变量或从文件读取，消除行内硬编码。推荐 (a)——回退列表的存在是合理的防御。

---

### 🟢 R6 · `PHASE_ARTIFACTS` 声明位置与 DESIGN.md 不一致

**Symptom（症状）**：DESIGN.md §2.3 伪代码将 `declare -A PHASE_ARTIFACTS=(...)` 放在 `fk_artifact_check()` 函数外部（作为模块级数据）。实际实现在 `flow-kit-artifacts.sh:47-56` 将其声明在函数内部——每次调用 `fk_artifact_check()` 时重新声明关联数组。

**Source（源头）**：DESIGN.md 的架构意图——数据与逻辑分离，"新增 phase = 新增一行数据而非修改控制流"。放在函数外部更明确地表达"这是数据表，不是执行逻辑"的意图。

**Consequence（后果）**：功能正确（每次调用重新声明不改变行为），但：(a) 微小的运行时开销（每次调用重新分配关联数组）；(b) 放在函数内部弱化了"查表驱动"的设计意图——读者可能误以为是局部临时变量而非核心数据表。

**Remedy（修补）**：将 `declare -A PHASE_ARTIFACTS=(...)` 移到 `fk_artifact_check()` 函数定义之前（例如第 35 行附近），与 DESIGN.md §2.3 对齐。同时删除函数内部第 67 行的 `unset IFS`（IFS 从未被修改，该行是无操作噪音）。

---

### 🟢 R7 · `unset IFS` 无操作噪音

**Symptom（症状）**：`flow-kit-artifacts.sh:67` 的 `unset IFS` 前面没有对应的 `IFS=` 保存/修改操作。函数内的 `for f in $files` 依赖默认 IFS（空格/制表符/换行符）进行单词分割，IFS 在此函数中从未被修改。

**Source（源头）**：常见 shell 编码模式：`old_IFS="$IFS"; IFS=...; ...; IFS="$old_IFS"`。此处缺少保存/修改，`unset IFS` 是防御性编程的残余（可能从重构前的代码遗留，旧代码可能设置了 IFS）。

**Consequence（后果）**：无功能影响——`unset IFS` 将 IFS 恢复为默认值，已经是默认值，执行后仍为默认值。但增加读者认知负荷：看到 `unset IFS` 会去寻找何处设置了 IFS，找不到则产生困惑。

**Remedy（修补）**：删除第 67 行 `unset IFS`。

---

### 🟢 R8 · Merge 模式 jq 构造复杂度过高，错误输出被静默抑制

**Symptom（症状）**：`correction-file.sh:67-74` 的 dedup jq 构造包含 4 层嵌套命令替换（`printf` 内嵌 `for` 循环内嵌 `IFS=` 赋值内嵌 `echo`），且所有管道均以 `2>/dev/null` 或 `|| echo "$existing"` 静默吞掉错误。若 jq 构造中的任何环节失败（例如 `--argjson fields` 的 JSON 格式错误），合并结果直接回退到 `$existing`，文件内容不变但没有任何错误提示。

**Source（源头）**：单元操作"构建 dedup fields 的 JSON 数组"被内联实现而非提取为独立函数，导致复杂度集中。`2>/dev/null` 的静默错误处理在 shell 脚本中是常见模式，但在数据合并路径中不应使用——合并失败应该显式报错。

**Consequence（后果）**：当 `dedup_key` 参数包含特殊字符或格式异常时，jq 构造可能失败，文件保持旧内容，调用方（write_compliance_correction）收到 return 0（成功）但实际未写入新数据。静默失败可能导致合规违规未被记录。

**Remedy（修补）**：(a) 提取 dedup fields JSON 数组构造为独立 helper 函数 `_build_dedup_fields_json()`；(b) merge 失败时应 return 1 并输出错误到 stderr（而非静默回退到 `$existing`）；(c) 至少将 `2>/dev/null` 替换为捕获 stderr 并在失败时显式报错。

---

**Verdict**: fail

（存在 🔴 Critical R1：`correction_file_write` merge 模式格式变异导致合规矫正机制完全失效，`flow-kit-resume.sh` 读取后即删。AC-3 实际未满足，REVIEW.md 漏判。）
