# CHANGE: 用户指南与用户指南 PPT 同步至 2026-09 功能集

- **Change ID**: user-guide-sync-2026-09
- **创建日期**: 2026-09-03
- **路径建议**: 完整
- **状态**: done（2026-09-03 归档 · 阶段 7 门禁 IR-7 L2 pass + L3 终审 pass）

---

## Why（为什么做）

- 2026-08~09 完成一轮大更新：dsh 插件化（f45bec5/868f362，dsh-flow-kit v0.2.0）、L2/L3 站点默认模型五级解析链（2999024，tier-4/5 + `/flow model l2-default=/l3-default=/--clear`）、`/flow doctor` correction 卫生报告（ADR-024）、archive-commit/pre-commit 门禁、correction 卫生与外来状态守卫等。
- 面向用户的 `FLOW-KIT-用户指南.md` 停在 **20260713**，`flow-kit-用户指南.pptx` 停在 2026-07-31 快照：仍写「17 个模块」Stop Hook、「L2/L3 三级优先级链」旧口径，且通篇以 Claude Code 为主（含安装路径），无 dsh 平台与插件安装章节、无 `/flow doctor` 与新门禁描述——按指南操作会得到与 2026-09 实现不一致的行为，误导新老用户。
- 该指南同时被打包进 `flow-kit-bundle/` 与 dsh 插件 `docs/`（package-dsh-plugin.sh §3 拷贝），单改根文件会造成三处漂移。

## What（做什么）

把 `FLOW-KIT-用户指南.md` 与 `flow-kit-用户指南.pptx` 同步到 2026-09 功能集（内容同步型 · 纯文档/演示产物，不改任何运行时代码），并保持 bundle 内指南副本一致：

- MD 增量修订：版本号/日期、安装章节补 dsh 平台（插件化安装路径）、核心概念与命令表补 `/flow doctor` 与新 `/flow model` 五级链语义、Stop Hook 章节按现行模块清单重写、审查机制补 L2/L3 双层与降级说明、生命周期章节补新阶段门禁（archive-commit/pre-commit）、全文去除「仅 CC」等过时表述。
- PPTX 重生成：新建 tracked 生成器 `.specs/user-guide-deck-gen/`（声明式 slides.json 20 页 + 布局库 + build.py；`.specs/archive/2026-07-31-user-guide-ppt-sync/gen/` 为 25 页技术设计 deck 生成器，仅作布局参考），重建 `flow-kit-用户指南.pptx`：更新过时 slide（模型五级链/Stop Hook 模块口径/dsh 平台化），**无条件新增 1 页「dsh 插件化安装与挂载」**；日期更新为 2026-09-03。
- 一致性：`flow-kit-bundle/FLOW-KIT-用户指南.md` 与根目录版本同步。

## 影响面

- [x] 影响 `REQUIREMENT.md`（本 change 新建）
- [x] 影响 `DESIGN.md`（本 change 新建 · 纯文档同步设计）
- [ ] 影响现有 AC（否——本 change 不改运行时，无既有 AC 涉及）
- [ ] 影响数据模型 / 迁移
- [ ] 影响外部 API 兼容性
- [x] 影响打包内容（flow-kit-bundle 指南副本 → 下次 package-dsh-plugin.sh 自动带入插件 docs/）
- [ ] 仅修复 bug，无范围变化（否）

> 0.4 架构级检测：不命中（文案/演示产物改动）。0.5 前端识别：不命中（无 界面/UI 类关键词；文档与演示 deck 不属于 UI 项目），跳过 0.6 视觉调性。

## 范围排除（这次不做）

- **不改任何运行时实现**：flow-kit-bundle/hooks、dsh-flow-kit/lib、skills/prompts 一律不动；上游 minor（如 common.sh:238 「3-tier」注释头，MINOR-DEFERRED D1）不借本 change 夹带。
- **不更新 `flow-kit-技术设计.pptx`**（技术设计演示属另一受众；若需补 v0.2.0 架构另开 change）。
- **不重写 `flow-kit-ecosystem-guide.md` / 根 `README.md`**（内容同步 change 聚焦用户指南两件套；生态清单入 v2）。
- **不做 PPT 视觉全面重设计**：沿用现有生成器主题/版式，只更新文案与必要页面。
- **不改动归档历史**：`.specs/archive/` 内既有产物只读。

## 验收线（粗粒度，不是 AC）

- 读者按新版指南操作得到的**行为描述**与 2026-09 实现一致：Stop Hook 模块清单、模型五级解析链与 `/flow model` 子命令、`/flow doctor` correction 报告、dsh 插件安装与挂载、阶段门禁（含 archive-commit/pre-commit）。
- 指南中不再出现已过时的硬事实（「17 模块」「三级优先级链」「仅 Claude Code」「版本 20260713」等，归档目录除外）。
- `flow-kit-用户指南.pptx` 由 `.specs/user-guide-deck-gen/` 重建成功（20 页）、日期为 2026-09-03、关键 slide 与 MD 一致、渲染验证无版式/缺字问题；生成器源入库可复跑；根目录与 bundle 的 MD 副本一致。
- 走完整流程：REQUIREMENT → DESIGN → TASK → DEV → TEST → REVIEW → INTEGRATION，L2 盲审 + L3 外部审查（gate_config=all）通过后归档至 `.specs/archive/2026-09-03-user-guide-sync-2026-09/`。

## 风险与未知

- 指南 ~70KB、PPT 现 19 页（重建目标 20 页），增量修订点多，存在漏改/事实漂移风险 → TEST 阶段用清单化 grep 断言兜底。
- PPTX 生成/渲染依赖 python-pptx 与系统字体，无 GUI 环境下版式细节需用 LibreOffice 转 PDF/PNG 抽查验证。
- 本会话（web host）无 `FLOW_KIT_L3_*` 环境 → L3 外部审查需在调用 l3-review.sh 时显式注入 env（沿用 dsh-tui 已配置的站点默认值），hook 自动路径可能降级为 model-missing，按降挡记录处理。
