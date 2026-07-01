# 独立审查 · 阶段 1

## L2 盲审

### 🟡 R1 · AC-1 验证手段脆弱，存在漏检风险：grep 快照式检查不能可靠证明"单一定义"

**Symptom（症状）**：REQUIREMENT.md:24 的验证方式为两条 grep：第一条检查硬编码的 `00-gate.*01-transcript.*99-report` 字符串是否存在，第二条检查 `HOOK_MODULE_NAMES` 变量名是否被引用。第一条的匹配模式高度依赖当前三个模块名的顺序和拼写——若未来新增模块 `00-new-module`，该模式不再匹配，返回 0 却误判为"已去重"。第二条 `grep -l "HOOK_MODULE_NAMES"` 仅检测变量名是否在文件中出现，无法区分"真正用于遍历"与"出现在注释/死代码中"。

**Source（源头）**：审查 checklist"每条 AC 是否 Given/When/Then 三段齐全且可机器验证"——验证方式必须是**可靠**的机器验证，而非仅语法上可执行。grep 对字符串的模式匹配只能证明当前快照状态，不能证明设计约束（"列表只在一处定义"）被结构性地强制执行。

**Consequence（后果）**：若未来有人新增 hook 模块（如 `00-env-check`）并仅在 `common.sh` 的列表中追加，AC-1 的第一条 grep 将因字符串不匹配返回 0（假阴性），而第二条 grep 因变量名存在也返回匹配——整条 AC 被错误地判定为"通过"，但实际上 `install_hooks.sh` 或 `package-flow-kit.sh` 可能也已被人手动补了一条，形成新的重复维护。

**Remedy（修补）**：将第一条验证从"快照式字符串匹配"改为"结构性检查"。建议改为：
```bash
# 结构性检查：install_hooks.sh 和 package-flow-kit.sh 中是否存在独立的模块名列表
#（排除来自 common.sh 的 source 行和注释）
grep -oP '(?<!")(00-gate|01-transcript|99-report)(?!")' \
  flow-kit-bundle/lib/install_hooks.sh package-flow-kit.sh \
  | grep -v '#'
```
期望输出为空（即两个消费者文件中不出现任何模块名的独立文字，只能通过 `HOOK_MODULE_NAMES` 变量引用）。或更可靠地：在 AC 中要求 `shellcheck` 规则禁止在消费者文件中直接书写模块名字面量。

---

### 🟡 R2 · AC-3 API 契约在 Given 中声明但未验证：四个函数的存在性和签名均无对应检查

**Symptom（症状）**：REQUIREMENT.md:35 的 Given 子句定义了四个函数接口（`correction_file_write/read/clear/exists`），但验证方式（:38）仅检查两个消费者文件中是否残留旧的 `jq.*correction.*tmp` 模式——删旧代码不等于新 API 已正确实现。四个函数各自的参数签名、返回值约定、错误处理行为在 AC 中均未定义，也没有验证方法证明它们确实存在且行为一致。

**Source（源头）**：审查 checklist"需求之间是否有矛盾或歧义"——Given 子句构成 API 契约声明，When 子句描述消费者行为，但 Then 子句只验证消费者侧的代码清理，未闭环验证 Given 中的 API 是否被兑现。这违反了 AC 自洽性原则。

**Consequence（后果）**：实现者可以删除两个 lib 中的 jq 调用（满足验证条件），但 `correction-file.sh` 可能只实现了三个函数、或四个函数的参数签名互不一致——AC-3 的 grep 检查仍然返回 0（"通过"）。更严重的是，`flow-kit-resume.sh` 的行为不变（Then 后半句）完全依赖这四个函数的内部实现正确，而该依赖链在 AC 中是一条信任假设而非可验证断言。

**Remedy（修补）**：将 AC-3 拆为两个子 AC：
- **AC-3a（API 存在性）**: `Given lib/correction-file.sh` 已 source，`When` 执行 `declare -f correction_file_write correction_file_read correction_file_clear correction_file_exists`，`Then` 全部四个函数名存在（exit code 0）。验证方式：`bash -c 'source lib/correction-file.sh; declare -f correction_file_write correction_file_read correction_file_clear correction_file_exists'` 成功。
- **AC-3b（消费者清理）**: 保留现有的 jq 模式 grep 检查。
- 另外在 Given 中明确四个函数的参数和返回值约定（例如 `correction_file_write <key> <value> <file_path> -> stdout: JSON`），使 AC 本身成为可引用的 API 契约。

---

### 🟡 R3 · AC-4 前提条件覆盖不全：bats 安装失败路径无应对

**Symptom（症状）**：REQUIREMENT.md:42 的 Given 子句为"系统已安装 bats（`which bats` 成功）"，但 CHANGE.md:50-51 明确记录了风险——"bats 安装依赖系统包管理（dnf），若不可用需回退到 npm 全局安装"。AC 的 Given/Then 结构将 bats 安装视为外部前提条件，若前提不满足则 AC 退化为"不适用"状态，而 v1 范围表（:66）将 AC-4 标记为必做项。两条陈述之间存在冲突。

**Source（源头）**：审查 checklist"是否遗漏非功能性需求"的延伸——AC 应覆盖其自身前提条件的满足路径。当 CHANGE.md 将安装行为纳入交付范围，AC 却不能对安装过程做断言时，这条 AC 对"必做"交付物不提供质量保证。

**Consequence（后果）**：在 dnf 不可用的环境中，实施者可能因无法安装 bats 而将 AC-4 标记为"不适用"（Given 未满足），但实际上 v1 范围内的 SessionStart 测试覆盖目标未达成。更糟的是，若实施者通过 npm 安装了 bats（CHANGE.md 的 fallback 路径），Given 子句中的 `which bats` 会通过，但测试执行环境可能与预期不同（npm 全局安装的 bats 路径、版本行为与 dnf 安装可能不一致）。

**Remedy（修补）**：将 AC-4 的 Given 改为两条路径：
- **AC-4a（bats 可用性）**: `Given` 执行安装脚本后，`When` 运行 `which bats && bats --version`，`Then` 退出码为 0 且版本 ≥ 1.0。
- **AC-4b（测试通过）**: `Given` bats 已可用，`When` 运行 `bats test/`，`Then` 全部用例通过（保留现有 Then）。
两者的依赖关系在 AC 中显式标注：AC-4b 依赖 AC-4a。

---

### 🟡 R4 · 非功能性能声明无依据：AC-2（查表驱动）和 AC-3（函数封装）均涉及控制流变更

**Symptom（症状）**：REQUIREMENT.md:90 声明"性能: 无（hook 执行时间不因此 change 增加）"。然而 AC-2 将 `fk_artifact_check()` 从 if/elif 链改为 `declare -A` 关联数组查找，AC-3 为 correction file 操作引入额外的函数调用层。两项改造均改变了运行时执行路径，却没有任何测量数据或性能边界声明支撑"无影响"的结论。

**Source（源头）**：审查 checklist"是否遗漏非功能性需求（性能 / 安全 / 可观测性 / 容量 / 兼容性）"——声明"无影响"也是一种性能需求断言，它同样需要证据或明确的容忍边界。不能因为改动方向是"优化/清理"就默认性能无害。

**Consequence（后果）**：关联数组在 Bash 4.0+ 中的查找是 O(1)，if/elif 链对于 N 个 phase 是 O(N)——在小型 N 下理论上关联数组可能因哈希开销反而略慢。虽然绝对值极小（< 1ms），但"无影响"的声明在无测量支撑的情况下不可复核。未来若有人在此声明基础上做性能敏感改动（如批量调用 `fk_artifact_check()`），可能被误导。

**Remedy（修补）**：将性能声明改为可复核的形式，例如：
> **性能**: 无回归预期。`fk_artifact_check()` 的 phase 数量 < 10，查表驱动与 if/elif 链在微基准测试中差异 < 1ms/调用。correction file 函数调用开销 < 0.5ms/次。若要正式确认，可在 `DESIGN.md` 中附一个 `time` 微基准对比。

或者更简单地：将"无"改为"无显著影响（<1ms 量级，不改变 hook 端到端延迟）"，至少给出数量级承诺。

---

### 🟢 R5 · AC-1 Given 子句中的"或"引入设计歧义

**Symptom（症状）**：REQUIREMENT.md:21 的 Given 子句为"`common.sh` 已定义 `HOOK_MODULE_NAMES` 数组（或独立配置文件）"。括号中的"或独立配置文件"引入了二选一的设计决策点，但 AC 的 Then 和验证方式均未区分这两种实现路径。

**Source（源头）**：审查 checklist"需求之间是否有矛盾或歧义"——Given 子句应给出确定的前提条件，而非附带未决选项。若审查者判断两种路径均可，应在 scope/设计要求段说明，而非嵌入 AC 的前提条件。

**Consequence（后果）**：两个开发者可能各自选择不同路径（一人改 `common.sh`，另一人创建独立配置文件），导致代码库中出现不一致的实现风格。虽然功能等价，但增加了维护者的认知负担。

**Remedy（修补）**：在 REQUIREMENT.md 的"依赖与假设"段或 scope 说明中明确首选路径（如"优先在 `common.sh` 中定义，因为已有 6 个 hook 源此文件"），并从 AC-1 的 Given 子句中移除括号中的选项。若确需保留两种路径，则在 Then 中补充"且路径选择记录在 DESIGN.md 的 ADR 中"。

---

### 🟢 R6 · v1 范围表复用原始扫描严重度标记，与 AC 优先级混淆

**Symptom（症状）**：REQUIREMENT.md:65-71 的 v1 范围表中，AC-1 被标为"🔴 Critical"，AC-2~4 标为"🟡 Warning"，AC-5~6 标为"🟢 Suggestion"。这些标记来自原始健康扫描发现的严重度分类，而非 AC 本身的实现优先级。在 REQUIREMENT.md 中所有 6 条 AC 都是 v1 必做项，不存在"某些 AC 可以降级"的语义。

**Source（源头）**：审查 checklist 格式一致性要求——同一文档内同一符号不应承载两种语义。🔴/🟡/🟢 在同一份 REQUIREMENT.md 中既是"原始发现严重度"又是"AC 实现优先级"会使后续阶段（DESIGN/TASK）的读者困惑：是否 🟢 标记的 AC 可以走捷径？

**Consequence（后果）**：DESIGN 阶段或 TASK 阶段可能将 🟢 Suggestion 标记的 AC-5、AC-6 视为低优先级，在工期紧张时被"合理地"跳过——但实际上它们都在 v1 必做范围内。

**Remedy（修补）**：将 v1 范围表中的彩色标记替换为明确的优先级列或独立字段（如 `Priority: P0/P1/P2`），并在表上方注明"所有列为 v1 均必做，优先级仅表示实施顺序建议"。原始扫描严重度可保留在 CHANGE.md 的追溯引用中，无需在 REQUIREMENT.md 中重复。

---

### 🟢 R7 · 缺少回滚验证或部分失败应对准则

**Symptom（症状）**：REQUIREMENT.md 的 6 条 AC 全部定义正向行为（"改造后应该…"），但 CHANGE.md:48-52 列出的三项风险（correction file API 边界变更、bats 安装 fallback 路径、已有测试可能被破坏）均未在 AC 层面获得对应的防御性验证。文档未定义"若 AC-3 的实现导致 `flow-kit-resume.sh` 行为异常，应如何检测并回滚"。

**Source（源头）**：审查 checklist"是否遗漏非功能性需求"——可逆性（reversibility）和故障隔离是发布级需求文档应覆盖的非功能属性，尤其当 CHANGE.md 已识别出跨模块风险时。

**Consequence（后果）**：若实施过程中 AC-3 的 API 边界变更破坏了 `flow-kit-resume.sh` 的行为但 bats 测试未覆盖该路径（AC-4 只承诺 SessionStart 覆盖），缺陷可能逃逸到集成阶段才被发现，修复成本显著增加。

**Remedy（修补）**：在 REQUIREMENT.md 中增加一条防御性 AC，例如：
> **AC-7（回归护栏）**：`Given` 全部修改已完成，`When` 运行 `bats test/` 和 `bash -n` 对所有 34 个 `.sh` 文件，`Then` 全部通过且无新增语法错误，退出码总和为 0。

此 AC 可整合 CHANGE.md 验收线中的已有内容，使其获得正式 AC 地位和可追踪性。

---

**Verdict**: pass
