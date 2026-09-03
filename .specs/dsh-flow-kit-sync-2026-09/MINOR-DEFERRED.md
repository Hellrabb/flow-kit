# MINOR-DEFERRED — dsh-flow-kit-sync-2026-09

> 各阶段 L2/L3 审查中登记的、判定为「上游跟进 / 刻意不改」的 minor 项，
> 供后续 round 与归档审计核销。

## D1 · 上游 common.sh:238 注释头仍写 3-tier（phase 2 L2 R3）

- 内容：flow-kit-bundle/hooks/stop/lib/common.sh:238 注释头
  `fk_resolve_model() · L2/L3 model resolution (3-tier priority chain)`，函数体
  已是五级链（commit 2999024 漏改注释头）；该注释随 vendor/内容层拷贝进 dist。
- 判定：属 flow-kit 核心内容层上游修正，超出本 change「搬运不重写」边界 →
  不在此改；待上游 flow-kit change 修正（一行注释）后重跑 package-dsh-plugin.sh
  自动带出。
- 复核锚点：grep -n 'tier priority chain' flow-kit-bundle/hooks/stop/lib/common.sh

## D2 · PROGRESS.md 单薄（L3 首审 Major 4）

- 判定：PROGRESS.md 由 Stop hook G5 自动追加（跨会话运行日志），人工改写会与
  G5 写入互踩；本 change 时间线由 CHANGE.md「独立审查」段 + REVIEW.md 承担。
- 复核锚点：.specs/dsh-flow-kit-sync-2026-09/REVIEW.md「审查前状态/补审记录」。

## D3 · CHANGELOG 行非 Conventional Commits 格式（L3 重审 Major 1）

- 判定：仓库 CHANGELOG 既定格式为 prose 管道行（L-073~L-080 同款），表头声明
  「按日期倒序」而非 CC；维持仓库惯例。
