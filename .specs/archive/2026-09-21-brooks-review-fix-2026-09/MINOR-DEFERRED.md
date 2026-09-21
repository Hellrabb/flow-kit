# Minor Findings Deferred · brooks-review-fix-2026-09

> 单一路径（ADR-017）。🟢 不入 fix loop；phase 7-integration 由用户 triage。
> 本 change 的 3🟡 + 3🟢 **全部当场修复**（无延后）；下表是修复过程中发现/确认的**新延后项**与**维持不变的既有决策**。

| # | Task | Finding ID | Description | Deferred reason | Date |
|---|------|------------|-------------|-----------------|------|
| M1 | — | DESIGN §9.1 v2 | **§0.5.1 结构化**：把"被改文件契约"从自然语言段落改为可解析结构（YAML front-matter / 表格），使 §10c 能**双向**核（既查"改动未列"，也查"列了但未改"） | 文本提取规则脆弱（路径带中文注解、嵌套清单），收益（多一个方向）小于误报风险；列入 REQUIREMENT v2 | 2026-09-21 |
| M2 | — | DESIGN D3 边界 | **映射自检**：从打包步骤的实际 `cp` 调用反推映射表，与 `COPY_*` 比对，彻底消除"表与实现"的残余信息泄漏 | 当前已由"打包循环与检查循环同读一份表"结构性覆盖；再加一层反推属过度设计（Ousterhout：不要为不存在的变化点建抽象） | 2026-09-21 |
| M3 | — | 既有 | `sync-hooks.sh` 的 SC2221/SC2222（`stop/*.sh|stop/lib/*.sh|…` 的 case 臂）—— 已复核为**假阳性**（外层 `_d` 循环限定取值域） | 与 `health-fix-2026-09` 的登记一致，**维持不修**（`make lint` 只卡 error 级，不阻塞） | 2026-09-21 |
| M4 | — | 上轮 R6 决策 (b) | `install_hooks.sh` 对 `pre-tool-use/*.sh` **一律** `chmod +x`，而 exec 判据只要求 3 个真入口 —— 两处对同一契约的视角仍不同 | 上轮 brooks-review R6 已裁定 (b)：保留行为 + 注释交叉引用 + 白名单为单一事实源。本 change 把白名单提到文件作用域并提供自检出口，**已进一步降低误配风险**；改 chmod 行为会影响部署面（超出本 change 范围） | 2026-09-21 |
