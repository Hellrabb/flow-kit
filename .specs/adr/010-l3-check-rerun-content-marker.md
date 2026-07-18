# ADR-010: _l3_check_rerun 内容标记 + artifact hash 载体

## Context
`_l3_check_rerun`（l3-review.sh:386）现行用 mtime 比较（artifact_mtime > review_mtime → 重审）。mtime 不反映内容（touch 钻空子）。**L2 盲审 R-D4-1 指出**：DESIGN 初版"## L3 段 + hash"中 hash 无处存——`.done` 是 KVP 契约（ARCHITECTURE §4.1 / ADR-005）+ 禁动（仅 l3_review_run 写）+ fail-不写-.done 冲突；存 INDEPENDENT-REVIEW-N.md 的 ## L3 段则鸡生蛋（重审未跑不重写段）。

## Decision
判定基从 mtime 改为内容标记：
- `## L3` 段匹配 regex `^## L3 (盲审|重审)`（**前缀匹配真实 token**——l3-review.sh:439/441 写 `## L3 重审/盲审（模型 · 时间）`，与 l3-review.sh:461/529 自身判定 `^## L3 盲审\|^## L3 重审` 一致；回应 L3-task-R1 🔴：原 `(盲审|外部模型审查)$` 的 `$` 锚 + 臆造 token 零匹配真实标题。phase 2 R-D4-3 排除"重审"是误判——"重审"正是 l3-review.sh 写的真实 L3 段格式）
- artifact hash 存 **INDEPENDENT-REVIEW-N.md 末尾元数据行** `L3_artifact_hash: <sha256>`（由 l3_review_run 审查后追加；**不触 `.done`**）
- 判定优先级：当前 artifact sha ≠ 记录 hash → 重审；`## L3` 段缺失/空 → 重审；否则 skip
- **删除** _l3_check_rerun 内 `case "$phase"` + `artifact_mtime` 块（~22 行死代码，回应 L2-R-D4-2 · TD-009/TD-020 治理一致）

## Consequences
- ✅ 内容标记精确（touch 不误触发）+ hash 捕真实变更 + 不破坏 .done KVP 契约
- ✅ 删死代码（与 TD-009/TD-020 治理一致）
- ⚠️ hash 计算开销（sha256 小文件 <1ms）
- ⚠️ INDEPENDENT-REVIEW-N.md 增 1 行元数据（不影响审查内容）
- 同步：REQUIREMENT AC-J Then 补 hash（DESIGN-AC 一致，回应 L2-R-D4-1）
- ✅ hash 提取失败降级（回应 L3-minor）：INDEPENDENT-REVIEW-N.md 被并发修改/结构破坏导致 `L3_artifact_hash` 行提取失败 → 触发重审 + 警告日志（保守重审，不死锁）
