# 独立审查 · 阶段 1

## L2 盲审

> 审查日期：2026-07-03
> 审查工件：REQUIREMENT.md（参考 CHANGE.md）
> 独立审查员：L2 盲审（未经主 agent 上下文注入）

---

### 审查范围

针对 `.specs/flow-active-integrity/REQUIREMENT.md` 做阶段 1 需求审查，checklist：
- AC 是否 Given/When/Then 三段齐全且可机器验证
- v1/v2/out 范围切分是否合理、有无范围蔓延
- 是否遗漏非功能性需求
- 需求之间是否有矛盾或歧义

---

### 发现

#### 🔴 R1 · AC 验证缺口：AC-1 验证方式与行为定义不匹配

**Symptom**：AC-1 的 Then 定义自检表应包含具体内容（「确认 .flow-active 关键字段（phase / task_id / change_id / updated_at）已通过 jq 写入磁盘」），但验证方式仅为 `grep -l "flow-active" *.md | wc -l ≥ N`。grep 计数只验证 prompt 文件**是否提及** "flow-active" 字符串，不验证**提及的内容正确性**。一个文件只写了 `echo "flow-active"` 也能通过该验证。

**Source**：AC 可验证性原则——验收准则的验证方式必须能区分「正确实现」与「形式实现」；当前验证方式的假阳性可通过任意字符串匹配触发。

**Consequence**：实现者可仅在各 prompt 文件中写入无关的 "flow-active" 字符串即通过 AC-1，实际自检内容可能缺失、错误或形同虚设。该 AC 形同空文。

**Remedy**：将验证方式升级为内容级验证。Before:
```
验证方式: grep -l "flow-active" flow-kit/prompts/{0-change,...}.md | wc -l ≥ 需加固的阶段数
```
After（至少要求匹配关键词组合）:
```
验证方式: 对每个需加固的 prompt 文件，grep 同时匹配 "flow-active" 和 "jq" 和 "phase" 三个关键词（或等价的正则），确保提及了写入操作而非仅提及文件名
```
更彻底的方案：将 Then 改为可直接验证的形式，如「每个需加固的 prompt 文件中存在一行匹配模式 `/\.flow-active.*jq.*phase/`」。

---

#### 🔴 R2 · AC 定义缺口：AC-4 的 phase-artifact 映射仅覆盖 phase 0 和 1，其余阶段未定义

**Symptom**：AC-4 Then 子句逐项检查中，仅列出了 `phase 0→CHANGE.md, phase 1→REQUIREMENT.md` 两条映射。phases_done 可能包含 phases 2 至 7，但 REQUIREMENT.md 未定义这些阶段对应的必须产物。依赖段落引用了外部 `flow-active-artifacts.sh` 的 `PHASE_ARTIFACTS` 关联数组，但该数组的内容、格式、维护约定均未在 REQUIREMENT.md 中记录或引用为规范性定义。

**Source**：需求完整性原则——AC 必须自包含定义其验证的输入-输出映射，不得依赖未在此文档中引用的外部定义（尤其当该外部定义可能独立演进时）。

**Consequence**：测试者无法从 REQUIREMENT.md 独立推导出 AC-4 的完整测试用例；如果 `PHASE_ARTIFACTS` 的实际定义与实现者/测试者的理解不一致，AC-4 的验证范围将不可靠。

**Remedy**：在 REQUIREMENT.md 的依赖节或 AC-4 正文中引用 `PHASE_ARTIFACTS` 的规范性定义位置（具体文件路径 + 行号范围），或在 AC-4 中列出完整的 phase→artifact 映射表：
```
| phase | 必须产物        |
|-------|----------------|
| 0     | CHANGE.md      |
| 1     | REQUIREMENT.md |
| 2     | DESIGN.md      |
| 3     | TASK.md        |
| 4     | (实现产物)      |
| 5     | TEST.md        |
| 6     | REVIEW.md      |
| 7     | INTEGRATION.md |
```

---

#### 🔴 R3 · AC 定义缺口：AC-4 gates 字段结构无定义

**Symptom**：AC-4 Then 子句引用 `gates` 字段并使用 `"N-1→N"` 格式命名 gate（如 `"1→2"`），但 `.flow-active` 中 gates 字段的 JSON 结构与 gate 状态枚举（passed/failed/pending）未在任何 AC 或 REQUIREMENT.md 的依赖/假设段落中定义。AC-4 无法在不知道该结构的情况下被独立验证。

**Source**：规格完整性——任何被 AC 引用的数据字段必须有其 schema 或结构定义，否则验证准则不可执行。

**Consequence**：实现者与测试者对 gates 的结构有不同理解（例如 gates 可能是 `{"1→2": "passed"}` 或 `[{"from": 1, "to": 2, "status": "passed"}]` 或完全不同的形式），导致实现不一致、测试不匹配，AC-4 的实际覆盖率归零。

**Remedy**：在 REQUIREMENT.md 中新增一节 ".flow-active 字段引用"，列出本次 change 涉及的字段及其期望结构，或直接引用 `.flow-active` 的 schema 定义文件路径。至少应定义 gates 的键命名规则和值枚举。

---

#### 🟡 R4 · AC 可测试性缺口：AC-6 "transcript 含 jq .flow-active 操作" 场景构造方式未定义

**Symptom**：AC-6 的 Given 条件为「transcript 显示本次 session 中有过 `.flow-active` 写入操作（jq 修改）」，但该条件的构造方式（bats 测试中如何生成满足该条件的 transcript）未指定。transcript 的格式、jq 操作的识别规则（正则匹配？日志标记？）均缺失。

**Source**：AC 可测试性原则——Given 条件必须在测试环境中可重现构造，否则 AC 不可验证。

**Consequence**：测试实现者可能以与实现者不同假设的方式构造 transcript，导致 AC-6 的测试与实际行为脱节——测试通过但生产环境不工作（或反之）。

**Remedy**：在 AC-6 中补充 transcript 格式约定或示例内容——最少需要什么样的 transcript 行才能触发 token_spent 检测。例如：
```
验证方式: bats 测试——构造 token_spent=0 的 .flow-active +
          transcript 文件包含行: "jq '.phase = \"2\"' .flow-active"（或其他匹配 hook 识别规则的 jq 操作行），
          验证 hook 输出含 "token_spent 未维护"
```

---

#### 🟡 R5 · 非功能性需求遗漏：可靠性 / 错误处理行为未定义

**Symptom**：非功能性需求节仅覆盖性能、安全、兼容性、可观测性四项。缺失的类别包括：
- **可靠性**：当 jq 不可用、`.flow-active` JSON 解析失败、`.specs/` 目录遍历权限不足时，hook 应产生什么行为？（假设节提到「JSON 格式无效时 hook 应容错跳过，不崩溃」，但这是假设而非需求——未定义「容错跳过」的具体行为：静默？写错误日志？返回非零退出码？）
- **资源约束**：交叉验证涉及 `.specs/` 目录遍历 + transcript 文件读取——在大型项目（数百个 `.specs/` 子目录）下的时间上限是多少？200ms 的性能需求是否覆盖该场景？

**Source**：非功能性需求完整性——分布式/文件系统交互型功能必须覆盖异常路径的行为定义。

**Consequence**：实现者自行决定错误处理策略，可能导致：静默吞错（漂移检测失效但不报错）、崩溃退出（阻塞 Stop hook 链后续模块）、或不一致的日志级别（运维无法区分「检测无漂移」和「检测因错误未执行」）。

**Remedy**：在非功能性需求节新增「可靠性」子节：
```
- 可靠性:
  - .flow-active JSON 无效 → 写入矫正文件（type=hook-error, 含 jq parse error），跳过后续交叉验证，不阻塞其他 hook 模块
  - .specs/ 目录遍历失败（权限/IO 错误）→ 写入矫正文件并继续
  - Stop hook 模块本身错误不应导致 session 关闭失败（全部错误路径均写入矫正文件 + 返回 0 退出码）
- 资源: 新增模块总执行时间（含 `.specs/` 遍历）≤ 500ms（上限放宽以覆盖大型项目）
```

---

#### 🟡 R6 · CHANGE.md 与 REQUIREMENT.md 不一致：引用不存在的 AC-7

**Symptom**：CHANGE.md「风险与未知」节第 1 条写道「需控制在每阶段 ≤3 行，遵循 AC-7 反啰嗦约束」。REQUIREMENT.md 中最高 AC 编号为 AC-6，不存在 AC-7。

**Source**：文档一致性——参考文件与被参考文件之间不应存在未解析的外部引用。

**Consequence**：阅读者无法追溯 AC-7 的定义，不清楚「反啰嗦约束」的具体要求。实现者可能在无规范约束的情况下自行决定自检项长度。

**Remedy**：如果 AC-7 是在其他 change 中定义的全局约束，应在引用处写明完整引用路径（如「遵循 @.specs/<other-change>/REQUIREMENT.md 中 AC-7 反啰嗦约束」）。如果 AC-7 本应在本 REQUIREMENT.md 中定义但被遗漏，则应补上该 AC。

---

#### 🟡 R7 · 范围描述不一致：CHANGE.md 声称覆盖 4 种场景，REQUIREMENT.md 定义了 5 个检测 AC

**Symptom**：CHANGE.md「验收线」节说「覆盖全部四种漏更新场景的 L3 检测逻辑」，「Why」节列出 4 种漂移（phase/task 漏写、pipeline goal 字段漂移、change_id 不一致、token_spent 未维护）。REQUIREMENT.md 的 L3 AC（AC-2 至 AC-6）共 5 条，其中 AC-5（updated_at 时效性检测）对应的「updated_at 陈旧」漂移未在 CHANGE.md 的「Why」中作为独立类型列出。

**Source**：文档一致性——需求文档的 AC 应完整覆盖 change proposal 中声明的场景，且不超出已分析的问题范围（新增场景应有对应的问题陈述）。

**Consequence**：AC-5 缺乏 CHANGE.md 中的问题根因追溯，可能被视为「凭空新增」而非「解决已有问题」。reviewer 无法判断 AC-5 是合理的场景扩展还是 scope creep。

**Remedy**：在 CHANGE.md「Why」节补充第 5 种漂移类型（updated_at 陈旧），或确认 AC-5 属于 pipeline goal 字段漂移的子类并在 CHANGE.md 中注明。

---

#### 🟢 R8 · 数据表示歧义：AC-4 phases_done 使用字符串表示 phase 编号

**Symptom**：AC-4 的 Given 示例中 `phases_done = ["0","1"]` 使用 JSON 字符串表示 phase 编号，但 `current_phase = "2"` 同为字符串。如果 `.flow-active` 实际存储整数（根据初始定义），字符串比较可能失败。

**Source**：数据一致性——JSON 字段类型约定应在 AC 中明确；整数与字符串在不同 JSON 解析器中的严格比较行为不同。

**Consequence**：如果实际 `.flow-active` 存储整数而 AC 示例使用字符串，实现者可能按字符串假设实现比较逻辑（宽松匹配），而实际 JSON 解析返回整数，导致字符串 `"2"` !== 整数 `2` 的比较失败。

**Remedy**：统一 AC-4 示例中的数据类型表示——明确 phases_done 是 `[0, 1]`（整数数组）还是 `["0","1"]`（字符串数组），并在 AC 中注明比较时应做归一化处理（如 `jq` 的 `tostring`）。

---

#### 🟢 R9 · AC-2 与 AC-4 的 phase 2 产物验证重复定义

**Symptom**：AC-2 验证 phase 2 对应产物 DESIGN.md 是否存在；AC-4 也验证 phases_done 中每个 phase 产物是否存在。phase 2 的产物验证同时出现在两条 AC 中，但 AC-2 仅检测缺失（「若缺失 → 写入矫正文件」），AC-4 是逐项检查（「任一不一致 → 写入矫正文件」）。两条 AC 对同一不一致的处理方式（写入矫正文件）相同，但触发条件和检测路径不同。

**Source**：需求正交性——多条 AC 覆盖同一检测面时，应明确其关系（独立/互补/冗余）。

**Consequence**：测试实现时可能对同一场景写重复测试；或者实现者可能发现两处逻辑重复而自行合并，但合并方式可能与原始意图不一致。

**Remedy**：在 AC-2 或 AC-4 的注释中说明关系——例如「AC-2 是粗粒度快速检查（仅验证 phase 对应的关键产物存在性），AC-4 是细粒度全量检查（遍历 phases_done 中所有 phase 的产物 + gate 一致性）。两者互补，允许部分重叠。」

---

### 总结

REQUIREMENT.md 整体结构清晰，6 条 AC 均采用 Given/When/Then 三段式。v1/v2/out 范围切分合理，无非功能性范围的 scope creep。

三个关键缺陷需要修复：

1. **AC-1 的验证方式与行为定义不匹配**（R1）——当前 grep 验证可被无关字符串绕过，AC 形同空文。
2. **AC-4 的 phase-artifact 映射不完整**（R2）——仅定义了 phase 0 和 1 的映射，其他 phase 的产物未定义，导致 AC 无法独立验证。
3. **AC-4 引用的 gates 字段无结构定义**（R3）——引用了一个未在 REQUIREMENT.md 中定义的数据结构，验证准则不可执行。

此外还有 4 个 Major 问题：AC-6 的可测试性细化（R4）、可靠性 NFR 缺失（R5）、跨文档引用断裂（R6、R7），以及 2 个 Minor 问题（数据类型歧义 R8、重复覆盖 R9）。

**Verdict**: fail

---


---

## L3 盲审（deepseek-v4-flash[1m] 外部模型 · 2026-07-03 21:56）

> 自动生成于 2026-07-03 21:56。由 l3-review.sh 写入。

### 审查结论

```json
{
  "critical": [],
  "major": [
    {
      "file": "AC-1",
      "issue": "缺少阶段 prompt 文件路径定义，无法执行 grep 验证",
      "why": "AC-1 的验证方式要求在每个阶段 prompt 文件中搜索自检项，但工件未列出这些 prompt 文件的位置和命名规则，导致没有可操作的验证依据",
      "fix": "在工件中明确列出 8 个阶段 prompt 文件路径（例如 prompts/phase-0.md … prompts/phase-7.md）以及 GO.md transition 段的具体标识或行范围"
    },
    {
      "file": "AC-6",
      "issue": "transcript 文件路径未定义，无法构造测试场景",
      "why": "AC-6 的 Given 依赖 transcript 文件内容，但工件未指定 transcript 的存储路径（如 ~/.flow-kit/transcripts/…），导致 bats 测试无法编写",
      "fix": "在依赖与假设或 AC-6 中明确 transcript 文件路径（例如 <SESSION_DIR>/transcript），或说明如何通过环境变量获取"
    }
  ],
  "minor": [
    {
      "file": "AC-2",
      "issue": "硬编码产物名称 DESIGN.md，与前置定义 PHASE_ARTIFACTS 动态查表不一致",
      "why": "Then 语句直接写 \"DESIGN.md\"，而前置定义要求从 PHASE_ARTIFACTS 映射获取，若映射变化则 AC 需同步修改，增加维护成本",
      "fix": "修改为“检测 .specs/foo/ 下是否存在 phase 2 的必须产物（参照 PHASE_ARTIFACTS 中对应的文件列表）”"
    },
    {
      "file": "AC-1",
      "issue": "术语 PCSC 未定义，可能造成理解歧义",
      "why": "工件中首次出现 PCSC（Phase Completion Self-Check）表，但未给出定义或引用文档，审查者无法确认其具体内容和结构",
      "fix": "在 AC-1 前或备注中简要说明 PCSC 表的定义，或引用已有规范文档"
    },
    {
      "file": "非功能性需求-可靠性",
      "issue": "未说明如何检测 jq 可用性",
      "why": "要求 jq 不可用时跳过检查，但未提供检测方法（如 command -v jq），虽不影响 AC 验证，但实现细节可更明确",
      "fix": "补充检测方式：“通过 `command -v jq` 判断 jq 是否可用”"
    },
    {
      "file": "依赖与假设",
      "issue": "transcript 文件路径假设重复 AC-6 问题",
      "why": "假设 transcript 文件可读，但未指定具体路径，与 AC-6 的缺失相同",
      "fix": "合并到 AC-6 的修复建议中"
    }
  ],
  "verdict": "pass",
  "summary": "工件整体结构清晰，v1/v2/out 范围切分合理，非功能性需求基本覆盖。主要问题涉及 AC-1 和 AC-6 中验证依赖文件路径未定义，导致可验证性存在歧义；此外存在少量可优化的细节。无 critical 问题，verdict 为 pass。"
}
```
