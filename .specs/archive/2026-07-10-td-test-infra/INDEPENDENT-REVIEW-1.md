# 独立审查 · 阶段 1

## L2 盲审

**审查对象**：`.specs/td-test-infra/REQUIREMENT.md`（参考 `CHANGE.md`）
**独立性声明**：仅依据工件内容判断，未接受主 agent 自评/辩护；未检测到上下文注入。

### 🟡 R1 · 悬空引用：AC-3 验证指向不存在的 AC-7
- **Symptom**：REQUIREMENT.md AC-3 验证写「`bats test/` 全绿 0 fail + AC-7 双源一致」，但全文只有 AC-1~AC-4。
- **Source**：spec 内部一致性；L2 checklist「每条 AC 必须可机器验证」。
- **Consequence**：AC-3 触发时「双源同步」成无 AC、无验证的悬空条款。
- **Remedy**：新增 AC-7 定义双源一致 + `diff -r` 断言；或把 AC-3 验证改显式命令并删「AC-7」字样。

### 🟡 R2 · AC-2 验证只校验「文字存在」，不校验「结论正确」
- **Symptom**：AC-2 验证仅「DEV-SUMMARY 含覆盖结论段 + 引用 test 文件名」，未定义什么算「覆盖」。
- **Source**：L2 checklist「拒绝空话，必须可机器验证」。
- **Consequence**：写一段含文件名的文字即可过 AC-2；且 AC-2 结论是 AC-3 触发条件 → 条件链建立在沙地上。
- **Remedy**：定义「覆盖」标准（source + 调检查函数）；验证升级为结构化 17 行表。

### 🟡 R3 · AC-1 exit code 合约不完整（已装分支未定义）
- **Symptom**：AC-1 Then 只定义「未装 → exit 0」，未定义「已装」exit code。
- **Source**：exit code 是 gate 硬依据；CHANGE/REQUIREMENT/v2 段间应一致。
- **Consequence**：实现者可能让重复率超阈值时 exit 非 0，污染 CI。
- **Remedy**：AC-1 Then 补「jscpd 已装 → exit 0（仅报告不门禁）」，与 v2 段对齐。

### 🟡 R4 · AC-3「关键业务脚本」边界开放，v1 范围可蔓延
- **Symptom**：AC-3 Given 用「（22-git / 23-quality / 26-workflow 等）」，「等」开放。
- **Source**：L2 checklist「是否有悄悄塞进 v1 的范围蔓延」。
- **Consequence**：AC-2 若主观判定多脚本为「关键」，v1 补 smoke 数失控，「2 task small」失真。
- **Remedy**：给确定的 17 脚本分类表 [business|coord|aggrep]，v1 只补 [business] 缺口；或给 v1 数量上限。

### 🟢 R5 · AC-1 验证不覆盖 `--ignore` 串正确性
- **Symptom**：AC-1 Given 要求带 `--ignore brooks-lint/brooks-tools/test/regression-demos`，验证仅 `grep 'dup:'`，不校验 ignore 串。
- **Source**：验证应覆盖 Given 关键约束；TD-010 根因正是「忘加 --ignore 致误报」。
- **Consequence**：实现者写不带 ignore 的 dup target 即可通过，0.91% 误报回归。
- **Remedy**：验证补 `grep -F brooks-lint/brooks-tools/regression-demos Makefile`。

### 🟢 R6 · 「DEV-SUMMARY」未定义路径
- **Symptom**：AC-2/AC-4 提「记入 DEV-SUMMARY」但未指明路径。
- **Source**：可验证性——必须能定位文件。
- **Remedy**：AC-2 验证注明 `.specs/td-test-infra/SUMMARY.md`。

### 🟢 R7 · NFR 缺 jscpd 版本漂移与输出契约
- **Symptom**：兼容性钉 5.0.11 未说其他版本行为；可观测性未定义 stdout/stderr 归属。
- **Remedy**：补「扫描走 stdout、skip/警告走 stderr；版本 ≠ 5.0.11 时 warn 不 fail」。

**Verdict**: pass（无 🔴 Critical；4 🟡 均为可通过小改 AC 文字修复的 spec 缺陷，不阻塞进入下一阶段）

---

## 主 agent 响应（L2）

全部 `Fixed in REQUIREMENT.md`（回补 AC 文字 + NFR · 同次 Edit）：

| 发现 | 行动 |
|---|---|
| R1 🟡 AC-7 悬空 | Fixed：AC-3 验证改 `diff -r test/ flow-kit-bundle/test/` 退出 0，删「AC-7」字样 |
| R2 🟡 AC-2 覆盖定义 | Fixed：AC-2 补「覆盖」判定（source + 调检查函数）+ 结构化 17 行表 |
| R3 🟡 AC-1 exit code | Fixed：AC-1 Then 补「jscpd 已装 → exit 0（仅报告不门禁）」 |
| R4 🟡 AC-3 边界 | Fixed：给 17 脚本分类表 [business\|coord\|aggrep]，v1 只补 [business] 缺口，上限 8 |
| R5 🟢 --ignore 验证 | Fixed：AC-1 验证补 `grep -F brooks-lint/brooks-tools/regression-demos Makefile` |
| R6 🟢 DEV-SUMMARY 路径 | Fixed：AC-2 验证注明 `.specs/td-test-infra/SUMMARY.md` |
| R7 🟢 NFR 版本漂移 | Fixed：NFR 补输出契约（stdout/stderr + 版本 warn 不 fail） |

无 Tech-debt / Not-applicable。

---

## L3 盲审（glm-4.7 外部模型 · 2026-07-09 22:45）

> 自动生成于 2026-07-09 22:45。由 l3-review.sh 写入。

### 审查结论

```json
```json
{
  "critical": [
    {
      "file": "AC-2",
      "issue": "验证指令存在逃逸漏洞，无法验证数据内容真实性",
      "why": "验证方式 `test -f` 仅校验文件存在，无法校验“17行”及“覆盖结论（covered/gap）”的正确性。且 `grep -F` 校验 Makefile ignore 串存在逻辑漏洞（匹配到 `brooks-lint` 字样即通过，无法校验参数格式是否为 `--ignore` 及是否在 `dup` target 下）。",
      "fix": "1. 文件内容校验：增加断言指令，如 `grep -c '^[^|]*|[^|]*|' .specs/td-test-infra/SUMMARY.md | grep -qE '^17$'` 或比对摘要文件行数。 2. Makefile逻辑校验：移除单一的 `grep -F`，改为提取 `dup` target 的完整 recipe 并解析其中的 `--ignore` 参数列表，确保配置位置正确。"
    }
  ],
  "major": [
    {
      "file": "AC-3 / AC-4",
      "issue": "范围蔓延风险：验证未明确边界",
      "why": "AC-3 补 smoke 测试涉及对 8 个业务脚本的内部函数进行调用与断言。AC-4 要求 `bats test/` 全绿。若这 8 个业务脚本因逻辑复杂导致 smoke 测试失败，且修复逻辑超出 'smoke（语法+调用）' 范围（如需修改脚本逻辑），则导致范围蔓延至脚本重构。当前的 AC 未对“全绿”的失败场景设定止损边界（如：允许标灰 skip）。",
      "fix": "在 AC-4 或 AC-3 中增加止损条款：若脚本内部函数逻辑导致 smoke 测试无法在最小改动下通过，允许标记为已知缺陷（todo）或 skip，并将具体脚本列入 v2 跟踪，而非强制要求 `bats` 全绿阻碍交付。"
    },
    {
      "file": "AC-2",
      "issue": "验证逻辑不完整",
      "why": "验证方式中存在 `grep -F brooks-lint` 但缺少对 `regression-demos` 的显式验证指令（虽然文字描述了 ignore 串包含它），且缺少对 `test/` 目录排除项的验证指令，导致不完整。",
      "fix": "补充验证指令：`grep -F regression-demos Makefile` 及 `grep -F ',**/test/**' Makefile`。"
    },
    {
      "file": "AC-1",
      "issue": "歧义：优雅 Skip 的定义模糊",
      "why": "AC-1 Then 提到“未装 → 优雅 skip”，但未明确“打印提示”的具体关键词或返回码逻辑（如 stderr 含 'jscpd not found' 且 exit 0）。`make dup` 通常由 `make check` 调用，若行为未定义，可能影响上游调用。",
      "fix": "明确 Then 条件：当 jscpd 未装时， stderr 必须包含特定字符串（如 'warn: jscpd skipped'），且 exit code 必须为 0。"
    }
  ],
  "minor": [
    {
      "file": "AC-2",
      "issue": "格式不一致",
      "why": "验证方式要求产出“17行表”，但描述中混合了 markdown 格式描述与行数描述，若表头占用一行，实际数据行数可能为 16 行，存在验证歧义。",
      "fix": "明确 SUMMARY.md 的总行数要求（如 18 行含表头）或明确验证指令中的行数计数逻辑。"
    },
    {
      "file": "AC-3",
      "issue": "验证指令依赖未定义变量",
      "why": "验证方式 `diff -r test/ flow-kit-bundle/test/` 依赖 `flow-kit-bundle` 路径，该路径未在 Given 或上下文中定义，属于外部假设。",
      "fix": "在 Given 或 Pre-condition 中定义 `flow-kit-bundle` 的来源或路径。"
    }
  ],
  "verdict": "fail",
  "summary": "工件在 AC-2 的数据验证逻辑上存在致命缺陷（仅验证文件存在），且 AC-3/AC-4 缺乏对测试失败导致的范围蔓延的边界控制，无法保证交付的确定性。"
}
```

---

## 主 agent 响应（L3）

L3 verdict=fail（critical: AC-2 验证逃逸）。全部 `Fixed in REQUIREMENT.md`：

| 发现 | 行动 |
|---|---|
| L3-critical AC-2 验证逃逸（test -f 只查存在）| Fixed：AC-2 验证改 `[ grep -cE '脚本名\|分类\|covered\|gap' SUMMARY.md -eq 17 ]`（17 数据行精确，表头不计）|
| L3-critical Makefile ignore 校验（grep -F 字样不校验 dup target 下）| Fixed：AC-1 验证改 `awk` 提取 dup recipe + 校验 `--ignore` 4 模式在 dup target 内 |
| L3-major AC-3/AC-4 范围蔓延无止损 | Fixed：AC-3 加止损条款（smoke 失败若需改脚本逻辑 → skip + v2，不强制全绿）；smoke 范围严格限定（语法+source+1 函数断言）|
| L3-major AC-1 优雅 skip 模糊 | Fixed：AC-1 Then 明确「stderr 含 jscpd skip 提示 + exit 0」|
| L3-major AC-2 验证不完整（缺 regression-demos/test）| Fixed：AC-1 验证含全 4 模式（brooks-lint/brooks-tools/test/regression-demos）|
| L3-minor 17 行含表头歧义 | Fixed：AC-2 验证注明「数据行 = 17，表头/分隔行不计」|
| L3-minor flow-kit-bundle 路径未定义 | Fixed：AC-3 注明 `flow-kit-bundle/` = 项目根打包源目录（STATE.md 锁定）|

无 Tech-debt / Not-applicable。**待 L3 重审。**
```
