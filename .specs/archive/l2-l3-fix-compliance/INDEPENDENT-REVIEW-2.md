# 独立审查 · 阶段 2

## L2 盲审

### 🟡 R1 · D1 决策理由与实现路径矛盾：选项编号 ③ 指向 Stop hook，但描述将代码置于 PreToolUse hook

**Symptom（症状）**：DESIGN.md §1 D1 行。备选列将 ③ 标记为"在 Stop hook 中事后检测"，理由段写"选③：复用现有 transition 拦截点"，但决策段（同行 Column 2）明确将插入点定在 `independent-review-gate.sh` 的 `is_phase_write` → forward direction 分支。经核实，`flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh:1-2` 文件头注释证实这是 PreToolUse hook，而非 Stop hook。

**Source（源头）**：DESIGN.md 内部一致性。`independent-review-gate.sh` 位于 `pre-tool-use/` 目录，`is_phase_write` 逻辑在 PreToolUse 拦截 jq transition 命令时触发——这是 PreToolUse 时序，不是 Stop 时序。

**Consequence（后果）**：若后续开发者（或另一 AI）阅读理由段后按 Stop hook 上下文理解该逻辑的时序约束（如 `.done` 文件何时可见、session 状态是否已持久化），可能做出错误修改。PreToolUse 和 Stop hook 的触发时机完全不同——PreToolUse 在工具调用前拦截，Stop hook 在会话停止后执行——时序差异直接影响 `.done` 文件、git diff 的快照时机、以及 agent 当前上下文状态的可用性。

**Remedy（修补）**：二选一：
- 若实际实现确实在 PreToolUse `independent-review-gate.sh` 中：将理由段"选③"改为"选②"，并将备选 ② 的描述从"在 PreToolUse 中单独检测"修正为"在既有 PreToolUse transition 拦截点插入"。
- 若实际实现打算在 Stop hook 中：修正决策段插入路径为对应的 Stop hook 文件路径。

推荐前者——数据流图（§2）的时序（"L3 完成后、exit 0 前"）与 PreToolUse 匹配，且 `independent-review-gate.sh` 已有的 `is_phase_write` + forward direction 分支正是为此场景设计的。

---

### 🟡 R2 · AC-2a Symptom 字段解析策略在 hook 层未充分规范——从自由文本 Markdown 中提取文件路径并分类的规则仅在 REQUIREMENT 层定义，DESIGN 层缺少 Bash 实现策略

**Symptom（症状）**：DESIGN.md §2 数据流步骤 ② 写"统计源码级发现数量（AC-2a 判定规则）"——将整个 REQUIREMENT.md AC-2a 的三级判定规则（解析 Symptom 字段文件路径 → 判定扩展名 → 源码/文档/默认源码）压缩为一个括号引用。数据流图未展开以下关键细节：
- 如何在 Bash 中可靠地从 INDEPENDENT-REVIEW-\<N\>.md（人工可读 Markdown，非结构化数据）解析出每条发现的 Symptom 字段。
- 如何从 Symptom 自由文本中提取文件路径（正则模式、多文件引用、行号格式 `file:line`、内联代码块干扰）。
- 提取的文件路径如何与 D3 白名单做扩展名匹配。
- 当 Symptom 跨多行、含多个文件引用时，判定规则如何应用。

**Source（源头）**：REQUIREMENT.md AC-2a 定义了完整的判定规则，但 DESIGN.md 仅引用规则编号而未展开实现策略。对比同文件中其他 hook 侧逻辑（如 D4 的 git diff --name-only 比对，实现路径清晰），AC-2a 的解析策略在 DESIGN 层面严重欠规范。

**Consequence（后果）**：开发者（或 AI 在 4-dev 阶段）面对"从 Markdown 解析 Symptom 文件路径"这一 Parsing 任务时缺少明确指引。自由文本解析在 Bash 中本就脆弱——缺少规范意味着实现可能：
- 用过于简单的 grep 导致漏判（源码发现被误判为文档级 → 实效性校验不触发）
- 用过于宽泛的正则导致误判（文档路径被误判为源码 → 假阳性阻断）
这两种情况都直接破坏 AC-2 的核心保障。

**Remedy（修补）**：在 DESIGN.md §2 中为步骤 ② 补充至少以下内容：
1. Symptom 段落的 Markdown 定位规则（例如：从 `### 🔴/🟡/🟢` 行起，到下一个 `###` 或空行截止，提取 `**Symptom（症状）**：` 后的文本）
2. 文件路径提取正则骨架（如 `grep -oP '(?:^|\s)([^\s:]+\.[a-zA-Z0-9]+)(?::\d+)?(?:\s|$)'` 及其预期边界行为）
3. 多文件引用的处理策略（取第一个？全取并以最严重者为准？还是报告模糊不清？）
4. 未匹配到文件路径时的 fallback 策略确认（当前 REQUIREMENT 规定"默认判定为源码级"——DESIGN 应显式复述以确保实现不会反向处理）

---

### 🟡 R3 · Prompt 层与 Hook 层"已修复文件"标记格式不一致——`[FIXED in <filepath>]` vs `Fixed in: <file>`

**Symptom（症状）**：DESIGN.md §2 包含两个数据流图，分别描述 prompt 层和 hook 层的协议：

- **Prompt 层数据流**（行 132-136）：agent 响应分类格式为 `[FIXED in <filepath>]`（方括号 + 全大写 FIXED）
- **Hook 层数据流**（行 110-111）：步骤 ⑤ 写"解析 'Fixed in: <file>' 声明"（无方括号 + 首字母大写 Fixed）

两个组件通过 INDEPENDENT-REVIEW-\<N\>.md 文件耦合——prompt 指示 agent 写入声明，hook 读取解析声明。若两处格式字符串不一致，hook 的 grep/正则无法匹配 agent 写入的声明，AC-2b 逐发现校验全部静默失败（0 条匹配 → 0% 未通过 → 放行，但实际未执行任何校验）。

**Source（源头）**：跨层契约未统一。Prompt 层格式和 Hook 层格式在 DESIGN 中分别定义，但未做显式对齐声明。这种跨组件耦合点必须有单一明确的契约格式。

**Consequence（后果）**：静默失效——hook 解析 0 条声明，AC-2b 的百分比计算退化为 0/0=0%（或除零），所有"已修复"声明都未真正被校验。agent 可以声称修了任何文件而 hook 不会检测到不一致。这与 US-2 的"hook 层能自动检测纯文档响应"目标直接冲突。

**Remedy（修补）**：
1. 在 DESIGN.md §9.3（跨模块契约）中明确定义 `Fixed in` 声明的精确格式字符串，例如：
   ```
   契约格式: /\[FIXED in (?<filepath>[^\]]+)\]/
   示例: [FIXED in hooks/stop/lib/l3-review.sh]
   ```
2. 将 Hook 层数据流中的"解析 'Fixed in: <file>' 声明"替换为与 prompt 层一致的格式字符串。
3. 在 `fix-compliance.sh` 的 `fk_verify_finding_files()` 规格中显式引用此格式契约。

---

### 🟡 R4 · `fix-compliance.sh` 三个辅助函数仅有名称，缺少签名与错误语义

**Symptom（症状）**：DESIGN.md §9.3 行 202-204 给出了三个辅助函数名：
- `fk_classify_source_files()`
- `fk_check_doc_only_diff()`
- `fk_verify_finding_files()`

但未给出任何参数列表、返回码约定、或错误处理策略。对比同段中 `fk_fix_compliance_check()` 给出了完整的四状态返回码定义（0/1/2/3）。辅助函数决定了主函数的可靠性——若辅助函数内部对异常情况（git diff 失败、review 文件格式异常、空输入）的处理方式不一致，主函数的 1/2/3 返回码区分将不可靠。

**Source（源头）**：DESIGN.md §9.3 跨模块契约段的完整性。主函数签名已定义，辅助函数签名遗漏。CONTEXT.md 中 gate-integrity 的既有决策要求 fail-close 策略在所有 hook 校验层一致应用——辅助函数的错误语义必须明确才能保证 fail-close 不被意外绕过。

**Consequence（后果）**：4-dev 实现阶段，辅助函数的实现者可能：
- 对 `fk_check_doc_only_diff()` 中 git diff 返回空/失败的情况做不同处理（返回 0 放行 vs 返回 1 阻断），导致与 D7（fail-closed）决策冲突
- 对 `fk_verify_finding_files()` 中 review 文件格式异常静默返回 0（0 条声明 = 全部通过，见 R3 的后果），造成静默绕过
- 辅助函数间的错误传递链断裂（如 `fk_classify_source_files` 返回错误但 `fk_fix_compliance_check` 未将其映射到 return 3）

**Remedy（修补）**：在 DESIGN.md §9.3 中为三个辅助函数补充最小签名规格：
```
fk_classify_source_files <review_file> <extensions_list>
  返回: 0=成功（结果写入全局/临时变量或 stdout）; 1=文件不存在; 2=解析错误

fk_check_doc_only_diff <project_root>
  依赖: git diff --name-only (cached + working tree)
  返回: 0=含源码变更; 1=纯文档变更; 2=git diff 执行失败（fail-closed: 视同阻断）

fk_verify_finding_files <review_file> <diff_file_list>
  返回: 0=全部通过; 1=≥50%未通过（阻断）; 2=<50%未通过（告警但放行）; 3=解析错误（fail-closed: 视同阻断）
```
并确保主函数 `fk_fix_compliance_check()` 将所有辅助函数的 1/2/3 错误返回码正确映射到其自身的 1/2/3 返回码体系。

---

### 🟢 R5 · 章节编号跳过 7 和 8——§6 之后直接跳到 §9

**Symptom（症状）**：DESIGN.md 目录结构：§0 → §0.5 → §1 → §2 → §3 → §4 → §5 → §6 → §9。缺少 §7 和 §8。

**Source（源头）**：文档结构约定。flow-kit 的 DESIGN.md 模板通常将 §7 留给"接口契约"、§8 留给"迁移策略"。本 change 无迁移策略是合理的，但跳号本身暗示可能有未完成的章节。

**Consequence（后果）**：读者可能认为有内容被删除或遗漏，造成不必要的审查疑问。无功能性影响。

**Remedy（修补）**：将 §9 改为 §7（或 §7 写"无——本 change 无新增接口契约"、§8 写"无——无数据迁移需求"后保留 §9）。若计划保留 §7/§8 给未来扩展，至少加一行占位说明。

---

**Verdict**: pass

---


---

## L3 盲审（deepseek-v4-flash[1m] 外部模型 · 2026-07-07 15:18）

> 自动生成于 2026-07-07 15:18。由 l3-review.sh 写入。

### 审查结论

```json
{
  "critical": [
    {
      "file": "工件第3.2节（统一格式契约）与第2节数据流图",
      "issue": "缺少对 agent 未输出 'Fixed in:' 标记的阻断机制",
      "why": "当 review 中有源码级发现（≥1条）且 agent 声称已修复但未按统一格式提供 'Fixed in:' 声明时，hook 层 fk_verify_finding_files 的 grep 结果为空，不会输出任何 MISSING，也未被检测为阻断。按当前逻辑（无匹配则返回0），校验会误放行，导致实效性校验形同虚设。",
      "fix": "在 fk_verify_finding_files 或 fk_fix_compliance_check 中，当 review 源码发现数 >0 但解析到的 'Fixed in:' 行数为0时，应阻断并输出 'Agent did not provide any valid Fixed-in declarations for source-level findings'。"
    }
  ],
  "major": [
    {
      "file": "工件9.3节插入点代码",
      "issue": "涉及未定义变量 $HOOK_BASE_DIR",
      "why": "插入点脚本片段直接引用 $HOOK_BASE_DIR，但工件未说明该变量由谁定义或在何种上下文中可用。若执行环境中未设置该变量，脚本将出错，导致 gate 无法正常插入新校验逻辑。",
      "fix": "在工件中明确 $HOOK_BASE_DIR 的取值来源（例如从 independent-review-gate.sh 内已有的路径解析逻辑获得），或改用绝对路径拼接方式（如 $(dirname "$0")/../stop/lib/）。"
    },
    {
      "file": "工件9.3节 fk_classify_source_files 输出格式",
      "issue": "输出格式依赖隐式约定，但后续消费方式未明确",
      "why": "函数输出为 'source:<count>' 及逐文件 '<type>:<path>'，但 fk_fix_compliance_check 如何解析这些行以获取统计结果和文件列表未描述。若解析不匹配，可能导致误判。",
      "fix": "在工件中补充 fk_fix_compliance_check 调用 fk_classify_source_files 后的解析示例（如通过 while IFS=: read ...），或在函数签名中声明输出格式的稳定性保障。"
    }
  ],
  "minor": [
    {
      "file": "工件决策D5、D1",
      "issue": "四份prompt重复约60行内容，且插入点增加同一文件内分支复杂度",
      "why": "虽然总量不大，但未来维护需同步修改四份文件，且 independent-review-gate.sh 新增约60行条件分支，违反了深模块原则（深模块应封装逻辑，而非在网关处暴露细碎分支）。",
      "fix": "考虑将重复的prompt段抽取为独立片段或共享引用（@see），并将分支逻辑封装到单独的函数或lib中，减少gate文件的认知负载。"
    },
    {
      "file": "工件风险R2",
      "issue": "对 agent 重分类绕过缓解措施仅停在告警，未说明是否阻断",
      "why": "R2 缓解措施提到 'hook 层检测 → 告警'，但未给出告警后的行为（仅log还是阻断transition）。若仅告警，则风险实际未缓解。",
      "fix": "明确对于重分类绕过（agent将源码发现全标记为NOT-APPLICABLE且无证据）应视为阻断（返回非零），而非仅告警。"
    }
  ],
  "verdict": "fail",
  "summary": "工件在强制代码修复的实效性校验方案上总体结构合理，但存在一个严重漏洞：当 agent 不输出 'Fixed in:' 标记时，校验被完全绕过。另外存在两个major缺陷：插入点依赖未定义变量 $HOOK_BASE_DIR，以及函数输出格式解析未明确。建议修复critical和major问题后重新审查。"
}
```
