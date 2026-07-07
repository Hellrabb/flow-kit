# REQUIREMENT: L2/L3 review 发现强制代码修复

- **Change ID**: l2-l3-fix-compliance
- **关联**: `@.specs/l2-l3-fix-compliance/CHANGE.md`、`@.specs/CONTEXT.md`

---

## 用户故事

- **US-1**：作为 flow-kit pipeline 用户（开启了 L2/L3 gate），我希望独立审查发现的问题**必须落到代码变更上**，而不是被 agent 用文档敷衍掉，以便审查的 token/时间成本真正转化为代码质量提升。
- **US-2**：作为 flow-kit 维护者，我希望 hook 层能**自动检测** agent 对 review 发现的"纯文档响应"，并在 gate 处阻断，以便弱模型无法绕过 prompt 层的修复指令。

---

## 验收准则（AC）

每条用 Given / When / Then，必须可验证。

### AC-1 · Prompt 层「修代码优先」协议

- **Given** 5-test / 6-review / 7-integration 阶段，L2 或 L3 独立审查产出了 INDEPENDENT-REVIEW-<N>.md，其中包含 ≥1 条源码级发现（非纯文档问题）
- **When** 主 agent 处理这些发现并声称"已完成修复"
- **Then** 每条源码级发现必须对应以下二者之一：
  - (a) 一个实际代码变更（git diff 中可见的非 `.md` 文件修改，且与发现描述匹配）
  - (b) 一条显式技术债登记，包含：登记理由（为何本次不修）、严重度评估、计划修复版本
- **验证方式**: `grep -l "修代码优先\|fix.code.first\|code.fix.required" flow-kit/prompts/{5-test,6-review,7-integration}.md flow-kit/prompts/independent/L2-blind-review.md` 确认四份文件均含协议关键词；人工构造"文档敷衍"场景确认 agent 不再仅产出 .md 修改（端到端验收）

### AC-2 · Hook 层纯文档响应检测

- **Given** 5/6/7 阶段结束时，INDEPENDENT-REVIEW-<N>.md 包含 ≥1 条标记为"源码问题"的发现
- **When** 主 agent 执行 phase transition（如 5→6 或 6→7）前的 gate 检查
- **Then** hook 扫描 git diff：
  - 若 diff 中**仅含 `.md` 文件**修改（不含任何源码文件变更）→ gate 阻断，输出"检测到纯文档响应，请修复代码或为每条发现登记技术债理由"
  - 若 diff 中含源码文件变更 → 继续 AC-2b 的逐发现文件级校验（不做变更内容的语义校验——那是 v2 范围）
- **验证方式**: `npx bats test/test_l2_l3_fix_compliance.bats`（新增测试用例：纯 .md diff 被阻断、含源码 diff 放行）

### AC-2a · 源码级发现分类判定规则

- **Given** INDEPENDENT-REVIEW-<N>.md 包含若干发现条目，每条有严重度标记（🔴/🟡/🟢）和四要素描述
- **When** hook 需要判断某条发现是否为"源码级发现"（触发 AC-2 检测）还是"文档级发现"（不触发）
- **Then** 采用以下判定规则（按优先级）：
  1. 若发现的 Symptom 字段明确引用了非 `.md` 文件路径（如 `hooks/stop/lib/l3-review.sh:42`）→ 判定为源码级
  2. 若发现的 Symptom 字段仅引用 `.md` / `.json` / `.yaml` 等文档/配置文件 → 判定为文档级
  3. 若无法从 Symptom 字段解析出文件路径（如仅描述逻辑问题未指名文件）→ 默认判定为源码级（宁可多检不漏检）
- **验证方式**: `npx bats test/test_l2_l3_fix_compliance.bats`（新增：Symptom 含 .sh 路径→判定源码级；Symptom 仅含 .md 路径→判定文档级；Symptom 无文件路径→默认源码级）

### AC-2b · 逐发现文件修改校验

- **Given** AC-2a 判定存在 ≥1 条源码级发现，且主 agent 对其中 N 条标记为"已修复（Fixed in code: <file>）"
- **When** hook 执行实效性校验
- **Then** 对每条标记为"已修复"的发现：
  - 提取声明的目标文件路径（`<file>`）
  - 在 git diff 中检查该文件是否被修改
  - 若某条发现的 `<file>` 未出现在 diff 中 → 该条标记为"修复声明未验证"并输出告警
  - 若 ≥50% 的"已修复"声明未通过文件级校验 → gate 阻断
- **验证方式**: `npx bats test/test_l2_l3_fix_compliance.bats`（新增：声明修复 a.sh 但 diff 无 a.sh→告警；声明修复 a.sh 且 diff 含 a.sh→通过；50% 未通过→阻断）
- **注意**: 本 AC 仅校验"目标文件是否被修改"（文件级），不校验"修改内容是否正确解决了问题"（语义级——那是 v2 范围）

### AC-3 · 实效性校验与现有真实性校验共存

- **Given** 现有的 gate-integrity `.done` 真实性校验（空文件检测 / 假内容识别 / 跳过子进程拦截）已生效
- **When** 新增的实效性校验（AC-2）在同一 gate 点执行
- **Then** 两层校验互不干扰：
  - 真实性校验先跑（`.done` 是否存在、是否合法内容）
  - 实效性校验后跑（diff 是否含源码变更）
  - 任一层失败 → gate 阻断，但两层各自输出独立错误信息，便于定位
- **验证方式**: 构造混合场景（假 .done + 纯文档 diff）→ 两层均报错且信息不重叠；`npx bats test/` 现有 gate-integrity 测试全部通过

### AC-4 · 技术债登记的滥用防护

- **Given** 某阶段 L2/L3 发现了源码级问题
- **When** 主 agent 将其中 ≥50% 标记为"技术债登记"而非代码修复（百分比基数为源码级发现总数）
- **Then** prompt 层要求 agent 输出一段显式说明（为何半数以上问题不能本次修复），但不硬阻断（保留人工判断空间）
- **验证方式**: 构造场景（如 4 条发现中 2 条登记为技术债 = 50% → 触发说明要求；4 条中 1 条 = 25% → 不触发）；`grep` 确认 prompt 含此约束文本

### AC-5 · 阶段精准限定

- **Given** phase 1（requirement）/ phase 2（design）的 L2/L3 审查产出了发现
- **When** 主 agent 处理这些发现
- **Then** 遵循现有的 review 响应协议，**不触发** AC-1/AC-2 的代码修复强制逻辑（因为 1/2 阶段的产物本就是文档）
- **验证方式**: `grep` 确认 AC-2 hook 逻辑中硬编码了触发阶段白名单（仅 5/6/7）；在 phase 1 构造"纯文档响应"→ gate 不阻断

---

## 范围切分

### v1（本次必做）

- Prompt 层：5-test.md / 6-review.md / 7-integration.md / L2-blind-review.md 增加「修代码优先」协议段
- Hook 层：扩展 `independent-review-gate.sh`（PreToolUse）增加实效性检测逻辑（纯文档 diff 检测）
- 共享 lib：若检测逻辑可复用，抽取到 `hooks/stop/lib/` 下
- 阶段限定：实效性校验仅对 phase 5/6/7 触发
- 技术债登记滥用防护（AC-4 的 prompt 层部分）
- 测试：新增 `test/test_l2_l3_fix_compliance.bats` 覆盖 AC-2/AC-3

### v2（下一轮考虑，不本次）

- 语义级 diff 校验：不仅检查"有没有改源码文件"，还检查修改内容是否真的对应发现描述
- 严重度分级响应：Critical → 必须修代码；Minor → 允许技术债登记
- 自动修复建议：L2/L3 发现附带建议 patch（diff 格式），agent 可直接 apply
- 修复覆盖率统计：产出 `FIX-COVERAGE.md` 报告本次 review 发现的修复率

### out（永远不做）

- 改动 L2/L3 审查内容生成逻辑（审查发现的质量、格式、深度不在本次范围）
- 新增独立 hook 模块（复用现有 gate-integrity + independent-review-gate 框架，不创建 33-xxx.sh）
- 自动修代码（agent 仍需人工确认和执行修复，本次只加固"必须修"的约束）
- 修改 gate_config 预设体系或 PRESET_MAP

---

## 非功能性需求

- **性能**: 无（hook 层检测为本地 git diff + jq 操作，<1s 完成，不影响 transition 延迟）
- **可访问性**: 无
- **安全**: 无
- **兼容性**: 向后兼容——未开启 gate_config 的 change 不受影响；现有 `.done` 格式不破坏
- **可观测性**: hook 阻断时输出明确的阻断原因（"纯文档响应" vs "真实性校验失败" vs "逐发现文件校验未通过"），写入 hook log
- **容错（fail-closed）**: 若 hook 层实效性校验自身出错（如 git diff 执行失败、jq 解析异常），默认阻断 transition（fail-closed），并输出 `L2_L3_FIX_COMPLIANCE_ERROR: <错误描述>`。不静默放行——宁可误阻断也不漏过

## 依赖与假设

- **依赖**: `gate-integrity`（已归档，.done 真实性校验框架就绪）、`independent-review-gap`（已归档，L2-blind-review.md 各阶段 checklist 就绪）、`dual-review-merge-fix`（已归档，L2/L3 合并写入机制就绪）
- **假设**: 5/6/7 阶段的 prompt 中已有"独立 review 调度"段（由 independent-review-gap 补齐），本次在其基础上追加"修代码优先"协议
- **假设**: `independent-review-gate.sh`（PreToolUse hook）的 transition 拦截点可直接扩展实效性检测逻辑，无需新增 hook 文件
- **假设**: git diff 能可靠区分"源码文件"与"文档文件"（通过文件扩展名白名单/黑名单）
- **已知风险（待 DESIGN 解决）**: 主 agent 可将 L2/L3 发现自行重分类为"文档级问题"以绕过 AC-1 的代码修复强制——自我监督闭环存在。DESIGN 阶段需给出防护方案（如：分类由 review 报告原文决定、禁止主 agent 降级发现分类）
