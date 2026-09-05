# ADR-025 · L3 重审反馈注入协议（prior-feedback injection）

- **状态**: proposed（2026-09-04 · l3-prompt-loop-fix）
- **关联**: ADR-005（独立审查体系）、ADR-006（弱模型鲁棒性）
- **来源 change**: `l3-prompt-loop-fix`（外部证据：~/chisel_env/.specs/archive/2026-08-29-traceweave-skill-mining/INDEPENDENT-REVIEW-7.md 登记 Claim 1/2，2026-09-04 核查裁定为真）

## Context

L3 外部模型重审（artifact hash 变化触发）在 chisel_env 项目连续 3 轮产出相同假阳性发现（CHANGELOG/ARCHITECTURE.md 不在归档目录），触发 `max_failures_before_bypass: 3` 人工旁路。核查确认两个机制性根因：

1. **反馈永不入 prompt**：`_l3_inject_context` 只注入「主 agent 已响应（详见 INDEPENDENT-REVIEW-N.md）」指针——外部 API 模型无法读该文件，前轮发现与处置结果从不进入模型视野，模型每轮从零断言（Claim 2）。
2. **尾部追加必被截断**：prompt 总预算 `head -c 20000` 按字节截断；CHANGELOG/LESSONS 段追加在 7 文件循环（各 head -c 3000）之后，确定性被切掉；弱模型按 checklist 字面要求（含"归档产物含 SUMMARY/CHANGELOG"）对照 ls 输出 → 必然误报（Claim 1 真因，非"未用 project_root"）。

## Decision

L3 重审 prompt 构造采用**反馈优先协议**：

1. **段顺序固定**：前轮反馈段（Step 0）> 项目级 CHANGELOG/LESSONS（phase 7）> 工件 7 文件循环 > checklist。任何未来新增的"必要段"必须前置于工件循环之前，禁止尾部追加。
2. **前轮发现单行摘要**：`severity|file|一行摘要`，critical > major，minor 不注入；配额 600B，溢出折叠 `(+k more)`。
3. **主 agent 响应要点**：`Fixed in: / Tech-debt: / Not-applicable:` 分类行，配额 200B；无响应段时标注「主 agent 未响应前次发现」；摘要与响应皆空时整段静默（首轮语义）。
4. **文件级字节截断必须 UTF-8 边界安全**（`_l3_utf8_head_bytes`：尾部多字节序列回退至上一完整字符）。

## Consequences

- **正向**：重审循环有了确定性打破机制——模型每轮都看到前轮发现与处置状态；CHANGELOG/LESSONS 注入确定性存活；弱模型按 checklist 字面执行不再必然误报。
- **代价**：prompt 构造复杂度上升（提取器两类格式 + 配额折叠）；既有 bats 断言需按新段序更新；字节预算语义仍是近似（UTF-8 混排），根治留给 v2（smart_truncate 统一）。
- **推翻信号**：若未来 L3 迁移到可读文件的多模态/长上下文模型，指针式注入可替代摘要式——届时本 ADR 可 supersede，但"尾部追加必被截断"教训仍约束段顺序规则。
