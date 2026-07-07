
---

## L3 盲审（deepseek-v4-flash[1m] 外部模型 · 2026-07-07 11:29）

> 自动生成于 2026-07-07 11:29。由 l3-review.sh 写入。

### 审查结论

```json
{
  "critical": [],
  "major": [
    {
      "file": "DESIGN.md",
      "issue": "R1 降级路径（写入文件 + prompt 模板注入）未在设计中详细说明，依赖外部 prompt 修改，可能引入实现复杂性和耦合度",
      "why": "D1 选择 stdout 的前提是 Claude Code hook 支持，若验证不通过需改 prompt 模板，此方案在当前工件中如何实现未定义，增加实现风险",
      "fix": "在设计中加入降级方案的具体接口定义（如临时文件名、prompt 注入指令格式），或确认 stdout 可用后删除此风险"
    },
    {
      "file": "DESIGN.md",
      "issue": "未处理 .done 文件 JSON 解析失败的情况（如写入半截 JSON）",
      "why": "脚本使用 `set -euo pipefail`，jq 解析失败会导致退出，阻断流程",
      "fix": "在读取 .done 时添加错误处理：`l3_verdict=$(jq -r '.L3_verdict // \"unknown\"' \"$done_file\") || warning; ...`"
    }
  ],
  "minor": [
    {
      "file": "DESIGN.md",
      "issue": "L3_RESULT 行中 summary 字段可能包含空格/换行符，单行格式缺乏转义约定",
      "why": "若 summary 含空格，agent 可见性可能被破坏；目前仅约定‘选为最后一个字段’不足以健壮解析",
      "fix": "定义转义规则（如用 URL 编码或双引号包裹），并在提取时做清理"
    },
    {
      "file": "DESIGN.md",
      "issue": "D3 决策明确保持 verdict 与 summary 提取逻辑重复，虽合理但未标注未来重构时机",
      "why": "当前 30 行重复可接受，但若 v2 增加字段将加剧重复；可添加注释指引重构点",
      "fix": "在 l3-review.sh 中增加注释：`# TODO(v2): extract to l3_extract_field()`"
    }
  ],
  "verdict": "pass",
  "summary": "设计合理，决策有充分理由，与既有架构对齐。主要风险（stdout 可见性）已识别，但降级方案细节缺失及 JSON 解析容错不足为 major 问题。"
}
```

---

## L2 盲审

**审查时间**: 2026-07-07 11:30 UTC  
**审查模型**: deepseek-v4-pro  
**审查工件**: `.specs/l3-feedback-visibility/DESIGN.md`（参考 REQUIREMENT.md, CHANGE.md, CONTEXT.md）  
**代码验证**: 已交叉验证 `l3-review.sh`（342行）, `done-validation.sh`（181行）, `independent-review-gate.sh`（270行）, `flow-kit-resume.sh`（259行）的实际实现

---

### 🔴 R1 · .done 文件格式假设错误：DESIGN 按 JSON 处理，实际是 key=value

**Symptom（症状）**：  
DESIGN.md D2 决策（第 72 行）声称 "`.done` 已是结构化 JSON（含 `L3_verdict` + 新增 `L3_summary`），jq 直接解析最可靠"。F3 数据流（第 165-170 行）将 `.done` 建模为 JSON 对象。F2 SessionStart 路径（第 136-137 行）直接使用 `jq -r '.L3_verdict // "unknown"' $done_file` 和 `jq -r '.L3_summary // ""' $done_file` 解析。

但实际代码 `l3-review.sh:250-257` 写入的是 **key=value 格式**：
```bash
cat > "$done_tmp" <<DONE_EOF
phase=${phase}
change_id=${change_id}
written_by=${written_by}
L2_verdict=${l2_verdict}
L3_verdict=${l3_verdict}
artifacts=${artifacts_list}
DONE_EOF
```
`done-validation.sh:90-95` 的 `_fk_done_kvp()` 函数也使用 `grep -E "^${key}="` 做 KVP 解析，确认全链路均为 key=value 格式。

**Source（源头）**：  
DESIGN.md 未读取实际 `.done` 文件格式就做出了格式假设。DESIGN §0.5.1 声称"grep/ls 确认的实际清单"但未包含对 `.done` 格式的验证。`l3-review.sh` 和 `done-validation.sh` 均位于触碰模块清单中但格式未被核实。

**Consequence（后果）**：  
- F2 SessionStart 路径的 `jq -r` 调用在 key=value 格式的 `.done` 文件上会直接报错退出（`set -euo pipefail`），导致整个 resume banner 构建失败，**AC-2 完全不可用**。
- R4 缓解措施"jq 合并而非裸 echo 覆写"在 key=value 格式下无意义。
- 若实施时不修正，4-dev 阶段首次集成测试即会暴露。

**Remedy（修补）**：  
1. **纠正 D2 理性说明**：将 `.done` 格式从"结构化 JSON"更正为"key=value properties 格式（`_fk_done_kvp()` 用 grep 解析）"。
2. **修正 F2 读取逻辑**（第 136-137 行），从：
   ```bash
   l3_verdict=$(jq -r '.L3_verdict // "unknown"' "$done_file")
   l3_summary=$(jq -r '.L3_summary // ""' "$done_file")
   ```
   改为：
   ```bash
   l3_verddict=$(_fk_done_kvp "$done_file" "L3_verdict")
   l3_verdict="${l3_verdict:-unknown}"
   l3_summary=$(_fk_done_kvp "$done_file" "L3_summary")
   l3_summary="${l3_summary:-}"
   ```
   （`_fk_done_kvp` 已由 `done-validation.sh` 提供，SessionStart 中 source 即可复用。）
3. **修正 F3 数据流伪代码**（第 165-170 行）：将 JSON 块替换为 key=value 格式。
4. **修正 R4 缓解措施**（第 207 行）：将"jq 合并"改为"追加新 key=value 行，或用 `_fk_done_kvp` + 完整重写方式新增键"。

---

### 🔴 R2 · AC-6 故障降级路径缺失：提取失败时输出 `verdict=fail` 而非 `verdict=error`

**Symptom（症状）**：  
REQUIREMENT AC-6 明确要求当 L3 响应 JSON 无法解析时输出 `L3_RESULT: verdict=error summary=L3 结果解析失败（verdict 不可用） report=<path>`。但 DESIGN.md F3（第 149-162 行）的三层提取设计没有错误分支——三层均失败后 verdict 为空，由 `l3-review.sh:217` 降级为 `"unknown"`，再由 `l3-review.sh:220-223` 的值域校验转为 `"fail"`。DESIGN.md 未提及任何 `verdict=error` 的产生路径。

同时，`done-validation.sh:139` 的值域 `^(pass|fail|timeout|error|skipped)$` 已经接受 `error` 作为合法 `L3_verdict` 值——基础设施已就绪，但 DESIGN 未利用。

**Source（源头）**：  
DESIGN.md §2 F3 数据流仅覆盖正常路径（三层提取成功），未设计故障降级分支。AC-6 在 §9 v1 范围中提到"畸变降级反馈"，但在数据流 / 决策 / 状态机中无对应设计条目。

**Consequence（后果）**：  
- L3 响应畸变时，agent 看到 `verdict=fail`，无法区分"L3 审查了且不通过"与"L3 响应本身损坏"。前者需修复设计，后者需排查 L3 API/模型问题——错误的 verdict 值会导致开发者做出错误决策。
- AC-6 无法通过验证，`verdict=error` 字符串永远不会出现在输出中。

**Remedy（修补）**：  
在 F3 summary 提取旁增加**第四层故障降级**（在所有三层提取之后）：
```bash
# Layer 4: 故障降级 — 所有提取层均失败
if [ -z "$l3_verdict" ] || [ "$l3_verdict" = "unknown" ]; then
  l3_verdict="error"
  l3_summary="L3 结果解析失败（verdict 不可用）"
fi
```
同时调整 `l3-review.sh:220-223` 的值域校验，将 `error` 加入合法值集合（当前仅 `pass|fail`），使其不被强制改写为 `fail`。

---

### 🔴 R3 · Verdict 值大小写不一致：AC 验证正则期望大写，实现产出小写

**Symptom（症状）**：  
REQUIREMENT AC-1 验证方式使用 `grep -qE '^L3_RESULT: verdict=(PASS|FAIL|WAIVER|TIMEOUT)...'`（大写值域）。但 `l3-review.sh:215` 的 grep 提取为 `(pass|fail)`（小写），`l3-review.sh:220` 的值域校验仅接受小写 `pass|fail`，`l3-review.sh:255` 写入的 `L3_verdict` 为小写，超时路径 `l3-review.sh:336` 写入 `L3_verdict=timeout`（小写）。全链路均为小写。DESIGN.md D4 格式行（第 74 行）使用 `<v>` 占位符，未指定大小写策略。

**Source（源头）**：  
DESIGN 未与 REQUIREMENT AC-1 的验证正则对齐。`done-validation.sh:139` 的值域 `^(pass|fail|timeout|error|skipped)$` 也是小写，说明项目既有约定是小写；但 AC-1 的 grep 验证使用了大写，形成 spec 与实现的双向不一致。

**Consequence（后果）**：  
AC-1 的 grep 验证脚本将**无法匹配**实际输出行。在 TEST 阶段，AC-1 会被标记为 FAIL，尽管功能上 agent 确实看到了 L3 结果。这属于可验证性缺陷（verifiability defect）——AC 写了一种验证方式但实际输出格式无法通过该验证。

**Remedy（修补）**：  
二选一（建议选方案 A，与既有代码库约定一致）：
- **方案 A（推荐）**：修改 REQUIREMENT.md AC-1 验证正则为大小写不敏感：
  `grep -qiE '^l3_result: verdict=(pass|fail|waiver|timeout)...'`
- **方案 B**：在 DESIGN.md 中明确增加大小写转换步骤，并在 F1/F2 输出前执行 `l3_verdict=$(echo "$l3_verdict" | tr '[:lower:]' '[:upper:]')`。代价：与既有 `.done` 存储格式不一致，且 `done-validation.sh:139` 的值域需同步改为大写。

无论选哪个方案，DESIGN.md 必须显式决策并记录。

---

### 🟡 R4 · AC-3 统一格式函数未定义：两路径使用内联 echo，无共享格式化入口

**Symptom（症状）**：  
DESIGN.md §0.5.2 明确声明"两条路径共用同一格式函数避免重复"。REQUIREMENT AC-3 验证方式也要求"代码审查验证两条路径调用同一格式化函数/模板输出 `L3_RESULT:` 行"。

但 F1 数据流（第 105 行）使用内联 `echo "L3_RESULT: verdict=${l3_verdict} summary=${l3_summary} report=.specs/${change_id}/INDEPENDENT-REVIEW-${phase}.md"`，F2 数据流（第 141 行）使用另一个内联 `echo "L3_RESULT: verdict=${l3_verdict} summary=${l3_summary} report=${report}"`。两处 `report` 字段的变量来源不同（F1 内联拼接，F2 预计算），无共享函数。

**Source（源头）**：  
D4 决策定义了统一格式但没有定义统一的格式生成函数/位置。AC-3 的"单元级"验证方式要求"同一格式化函数/模板"，但 DESIGN 未指定该函数签名或存放位置。

**Consequence（后果）**：  
- 两条路径的格式容易漂移——未来修改格式时可能只改一处。
- AC-3 的单元级验证方式无法通过（没有"同一格式化函数/模板"可审查）。
- 测试时需同时验证两处内联 echo 而非单一函数。

**Remedy（修补）**：  
在 `l3-review.sh` 或新建的共享 helper 中定义格式化函数：
```bash
# Usage: _l3_format_result <verdict> <summary> <report_relative_path>
_l3_format_result() {
  echo "L3_RESULT: verdict=${1} summary=${2} report=${3}"
}
```
F1 和 F2 均改为调用 `_l3_format_result "$l3_verdict" "$l3_summary" ".specs/${change_id}/INDEPENDENT-REVIEW-${phase}.md"`。

---

### 🟡 R5 · WAIVER 判决值在 AC 中出现但在提取逻辑和值域校验中缺失

**Symptom（症状）**：  
REQUIREMENT AC-1 判决值域包含 `WAIVER`（大写）/ `waiver`（若统一小写）。但 `l3-review.sh:215` 的提取正则仅匹配 `(pass|fail)`，`l3-review.sh:220` 的值域校验仅接受 `pass|fail`，`done-validation.sh:139` 的 L3_verdict 值域为 `^(pass|fail|timeout|error|skipped)$`。WAIVER 在全链路均不可产出、不可存储。

**Source（源头）**：  
REQUIREMENT 定义了 WAIVER 作为可能的判决值（可能是从 L3 prompt 的输出格式反推），但 DESIGN 的所有提取/校验层未覆盖该值。`done-validation.sh` 的值域表也未包含 `waiver`。

**Consequence（后果）**：  
若 L3 外部模型按 prompt 指令返回 `"verdict":"waiver"`，三层提取中前两层（jq 解析）可提取到 "waiver"，但第三层 grep 正则 `(pass|fail)` 无法匹配，值域校验会将其降级为 `fail`。WAIVER 语义（"有风险但可接受，不阻塞流程"）被错误转换为 FAIL（阻塞流程）。

**Remedy（修补）**：  
- 在 `l3-review.sh:215` 的 grep 中扩展为 `(pass|fail|waiver)`
- 在 `l3-review.sh:220` 的值域 case 中增加 `waiver)` 分支
- 在 `done-validation.sh:139` 的值域中增加 `waiver`
- 或在 DESIGN.md 中显式声明"v1 不支持 WAIVER，L3 prompt 中也移除 waiver 指令"。需同步修改 REQUIREMENT AC-1 的值域。

---

### 🟡 R6 · D2 决策依据错误：声称 .done 是 JSON 并以此为 jq 方案的优势论据

**Symptom（症状）**：  
D2 决策（第 72 行）对比备选方案时，选择 (c) 的理由是 "`.done` 已是结构化 JSON（含 `L3_verdict` + 新增 `L3_summary`），jq 直接解析最可靠"。此理由的事实前提（".done 是 JSON"）不成立——`.done` 是 key=value 格式（见 R1）。

**Source（源头）**：  
DESIGN 阶段的架构对齐步骤（§0.5）未验证 `.done` 文件的实际序列化格式。

**Consequence（后果）**：  
- 决策记录（D2）包含了错误的事实依据，未来读者可能基于此做后续决策。
- 方案 (c) 本身（从 .done 读取）仍然是正确的选择方向——只是理由中的格式描述和 jq 方案需要更正，不影响决策方向。

**Remedy（修补）**：  
修正 D2 的"选择理由"列：删除"`.done` 已是结构化 JSON"和"jq 直接解析最可靠"，改为 "`.done` 是 key=value 格式，通过 `_fk_done_kvp()` 函数（`grep -E`）可靠解析，比备选方案 (b) 的 markdown 解析更稳定"。

---

### 🟢 R7 · D4 格式行字段边界歧义：summary 若含 " report=" 字面量会破坏字段边界

**Symptom（症状）**：  
D4 决策（第 74 行）定义了 `L3_RESULT: verdict=<v> summary=<s> report=<p>` 格式行，其中 summary 字段是最后一个含空格的自由文本字段。若 L3 模型返回的 summary 恰好包含字面量 ` report=`（例如 "请检查 report= 字段"），grepper/parser 无法区分这是 summary 内容还是 report 字段的起始。

**Source（源头）**：  
D4 的取舍代价栏（第 74 行）仅提及"report 路径不含空格"，未考虑 summary 中意外出现 ` report=` 的情况。该格式使用空格分隔字段但无转义机制。

**Consequence（后果）**：  
自动化 grep 解析（如 AC-1 的验证脚本）可能提取到错误的 summary/report 值。概率低（需要 L3 模型恰好输出含 ` report=` 的 summary），但一旦触发会导致字段解析错误。

**Remedy（修补）**：  
- 在 D4 取舍代价中备注："summary 字段值若含 ` report=` 字面量将导致字段边界歧义。概率极低（L3 summary 为中文总评），v2 可考虑 base64 编码或 JSON 行格式。"
- 或调整格式为 `L3_RESULT: verdict=<v> | summary=<s> | report=<p>`（使用 ` | ` 分隔符降低冲突概率）。

---

### 🟢 R8 · §9.1 未来重构标注与 D3 决策的表述存在轻微矛盾

**Symptom（症状）**：  
D3 决策（第 73 行）明确将"抽取公共函数为过度工程"作为不抽取的理由。但 §9.1（第 228-230 行）建议"若 v2 增加更多字段，建议本次或下次重构为通用函数"——"本次"一词与 D3 的"过度工程"判断存在语气矛盾。

**Source（源头）**：  
DESIGN 不同段落的作者意图不完全一致——D3 强调"不抽取"（务实），§9.1 暗示"本次可考虑抽取"（前瞻）。

**Consequence（后果）**：  
读者（包括 3-task 阶段的 AI）可能对是否抽取公共函数产生歧义，导致实现偏离设计意图。

**Remedy（修补）**：  
将 §9.1 的"建议本次或下次重构"改为"建议下次重构（v2），本次保持 D3 的显式重复策略"。消除"本次"的歧义。

---

**Verdict**: fail

> 🔴 Critical 项: R1（.done 格式假设错误导致 AC-2 不可用）、R2（AC-6 错误降级路径缺失）、R3（AC-1 验证正则与实现不一致）。三项均为 spec 合规失败——REQUIREMENT 定义的 AC 在 DESIGN 中无对应实现路径或设计假设与实现事实矛盾。

