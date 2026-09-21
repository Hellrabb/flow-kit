# CHANGE: 用户指南与用户指南 PPT 同步至 2026-09-21 现状（第二轮）

- **Change ID**: user-guide-sync-2026-09b
- **创建日期**: 2026-09-21
- **路径建议**: 完整（REQUIREMENT → DESIGN → TASK → DEV → TEST → REVIEW → INTEGRATION；用户已指定 pipeline 0→7 + 阶段 6 L2/L3 双轨）
- **状态**: draft

---

## Why（为什么做）

- 上一轮同步 `user-guide-sync-2026-09`（2026-09-03 归档）之后，仓库又落地 **5 个 change**：`dsh-flow-kit-sync-2026-09`（install.sh dsh 分支 / 站点级默认模型 / doctor correction 卫生）、`l3-prompt-loop-fix`（L3 提示词反馈优先重排 + UTF-8 字节截断）、`l3-review-defects-2026-09`（L3 段契约 / 工件单位 / 不可信载荷守卫）、`health-fix-2026-09`（门禁盲区修复 → `make check` 六门 + `verify-claims.sh` 解耦 + ADR-027）、`brooks-review-fix-2026-09`（L3 工件上限 20000 → 80000 字节 + 打包映射收敛为一份）。
- 同期**安装面与配置面口径整体改写**：hooks 安装统一用户级（`install.sh` DEST_ROOTS 7 → 6，`--project` 只装 hooks/settings/.specs，**配置不再读写项目级 `stop-hook.json`**）、新增 `make dsh-sync` 刷新入口（此前只镜像 `hooks/**` 的 `sync-hooks.sh` 会让插件 `lib/*.js`、`docs/`、`vendor/` 静默漂移）。
- 结果是：读者按现行指南操作会得到与实现不一致的行为——例如去找项目级 `stop-hook.json` 当配置源、把 L3 工件上限理解成 20000 字节（实测提示词 74610 B 时丢 73% 工件）、以为 `make check` 是五门、不知道 L3 需要凭证模板与熔断语义、不知道 `dist/` 有新鲜度门禁。指南同时被打包进 `flow-kit-bundle/` 与 dsh 插件 `docs/`，单改根文件会造成副本漂移（`make check-dist` 会红）。

## What（做什么）

把用户可见文档面**全量**同步到 2026-09-21 仓库现状（内容同步型 · 不改任何运行时实现）：

- **`FLOW-KIT-用户指南.md` 全量修订**：安装面（用户级统一 / `--project` 语义收窄 / `make dsh-sync` / 配置走用户级）、配置面（`stop-hook.json` 现行位置与 12 开关模块口径）、L3 审查链（凭证模板与解析、熔断/降级、工件上限 80000 字节 + ÷3 换算）、门禁面（`make check` 六门 / `check-dist` / `verify-claims` / pre-commit）、新 ADR 口径（025 前轮反馈注入 / 026 不可信载荷边界 / 027 门禁只提高可见性）。
- **`flow-kit-用户指南.pptx` 大幅扩页重建**：沿用 `.specs/user-guide-deck-gen/`（slides.json + layouts + build.py + deck_checks.py），在 20 页基线上新增**安装面专页、L3 审查链专页、门禁专页**等（净增 ≥4 页），日期更新为 2026-09-21；生成器与断言同步改到新页数。
- **副本一致**：`flow-kit-bundle/FLOW-KIT-用户指南.md`、`dist/dsh-flow-kit/docs/FLOW-KIT-用户指南.md` 与根文件逐字节一致。
- **README 口径**：核对并**允许连改** `README.md` 与 `dsh-flow-kit/README.md` 中被 2026-09 后续 change 写成过时口径的段落。

## 影响面

- [x] 影响 `REQUIREMENT.md`（本 change 新建）
- [x] 影响 `DESIGN.md`（本 change 新建 · 纯文档/演示同步设计）
- [ ] 影响现有 AC（否——不改运行时，无既有 AC 涉及）
- [ ] 影响数据模型 / 迁移
- [ ] 影响外部 API 兼容性
- [x] 影响打包内容（bundle 副本 + `dist/dsh-flow-kit/docs/` 副本；`make check-dist` 为门禁）
- [x] 影响 demo 生成器（`.specs/user-guide-deck-gen/` 的 slides.json / deck_checks.py 页数与断言）
- [ ] 仅修复 bug，无范围变化（否）

> **0.4 架构级检测**：不命中（纯文档/演示产物同步，不触模块结构 / ADR 决策 / 公共契约 / 容量边界）。
> **0.5 前端识别**：不命中（无「界面 / UI / 页面 / app」类**产品**关键词；文档与演示 deck 不构成 UI 项目）→ 跳过 0.6 视觉调性预选。

## 范围排除（这次不做）

- **不改任何运行时实现**：`flow-kit-bundle/hooks/**`、`dsh-flow-kit/lib/**`、`skills/**`、`prompts/**` 一律不动；发现实现侧问题只在 REVIEW / LESSONS 登记，不夹带修改。
- **不更新 `flow-kit-技术设计.pptx`**（另一受众另一 change）。
- **不重写 `flow-kit-ecosystem-guide.md`**（生态清单不属用户指南两件套）。
- **不做 deck 视觉全面重设计**：沿用现有 theme/layouts，只做必要的新增版式以承载新专页。
- **不改动 `.specs/archive/**` 历史产物**（只读）。

## 验收线（粗粒度，不是 AC）

1. 读者按新版指南与 PPT 得到的行为描述与 2026-09-21 实现一致：安装入口与作用域、配置路径与键、L3 凭证与熔断、工件上限 80000 字节、`make check` 六门、ADR-025/026/027 口径。
2. 指南与 PPT 中不再出现已被推翻的硬事实（项目级 `stop-hook.json` 作配置源、20000 字节工件上限、五门门禁、旧模块计数、旧日期等；`.specs/archive/**` 历史除外）。
3. `flow-kit-用户指南.pptx` 由生成器重建成功、页数为新版结构（≥24 页）、日期 2026-09-21、关键页与 MD 一致、渲染验证无版式/缺字问题；生成器与 `deck_checks.py` 断言同步更新且可复跑。
4. 三处指南副本逐字节一致；`make check-dist` 通过；README 口径漂移已修正或登记。
5. 走完 pipeline 0→7，阶段 6 **L2 盲审 + L3 外部模型**双轨通过（`gate_config={"6-review":"both"}`）后归档至 `.specs/archive/2026-09-21-user-guide-sync-2026-09b/`。

## 风险与未知

- 指南 1631 行、覆盖 12 个章节，deck 生成器为声明式 slides.json（20 页）；本轮修订点多（安装/配置/L3/门禁四族），**漏改与"改了措辞但事实仍旧"**是主要风险 → TEST 用清单化断言（grep 正反例 + deck_checks）兜底，REVIEW 用独立视角复核。
- PPT 扩页会改变既有断言（页数、日期、禁词清单），若 `deck_checks.py` 与 slides.json 不同步会出现恒绿/恒红 → 断言需实测生效（注入→变红→还原）。
- L3 外部审查依赖凭证与站点默认模型（本机 `FLOW_KIT_L3_DEFAULT_MODEL=deepseek-v4-flash-0731`；API key 需在调用时解析）；若凭证不可用将出现 `l3-model-missing` 降级，按既有降挡口径透明记录，不伪造 pass。
- 本 change 是**纯文档**，容易产生"看起来同步了"的假绿（例如只改目录不改正文、只改根文件不改副本）→ 验收以**副本字节一致 + 反例 grep + 渲染实跑**三类机械证据为准。
