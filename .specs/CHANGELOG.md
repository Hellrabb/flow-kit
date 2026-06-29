# CHANGELOG

> 按日期倒序。每行：日期 / change-id / 摘要 / LESSONS 新增。

| 日期 | Change ID | 摘要 | LESSONS |
|---|---|---|---|
| 2026-06-29 | `lessons-cleanup` | 消除 LESSONS.md 三条活跃技术债：L-013 归档双向校验（清理工作目录+扫描孤儿change）+ L-012 打包完整性校验（--validate）+ L-010 1.8 破坏性变更自动 bats 验证 · 16 bats tests 全绿 | L-010/L-012/L-013 |
| 2026-06-29 | `quality-baseline` | 质量基础设施补强：E 协议 DRY（pipeline-gates.md + check-gate-sync.sh）+ F Makefile（test/lint/check/all）+ pre-push hook + G stop 链 smoke test（12 tests）+ H shellcheck 集成 + I test 双源 diff 校验 · 122 bats 全绿 | — |
| 2026-06-25 | `weak-model-robustness` | 提升 flow-kit 弱模型（幻觉多）鲁棒性 · L1+L2+L3 三层防御：RULES R3.5 禁跳反问 / R6.1 引用前证据链 / R7.4 动手前复述边界 + SYSTEM 原则节 + GO goal 锚定 + 4 prompts 反问gate/证据链/checkpoint/复述边界 · ADR-001 protect-the-weakest · 8 bats + 3 regression-demo check.sh · 102 bats 全绿 · 全链路 pipeline 0→7 | — |
| 2026-06-22 | `fix-pcsc-gaps` | 补齐 PCSC 表两个缺失检查项：7-integration 新增 T-FIX 关闭检查行 + 6-review 新增 CONTEXT 技术债写入检查行 | — |
| 2026-06-22 | `security-privacy-audit` | 安全与隐私泄露全面审查（push 前最后防线）：六大维度（凭证/路径/PII/注入/端点/Git历史）全量扫描 · 零🔴Critical 发现 · 60🟡WARNING（仅.specs/归档路径）· 判定：✅ 可安全 Push 公开仓库 · full pipeline 0→7 自动执行 | — |
| 2026-06-22 | `fix-shim-bin-path` | 修复 brooks-tools 离线安装失败（3 轮迭代）：① .js→wrapper + chmod 兜底 ② npm install 安装依赖 + jq 解析 bin 字段（兼容对象/字符串）③ printf 防注入 + 安全校验 · 4/4 工具 --version 通过 · bundle 27M (10699 文件) | — |
| 2026-06-22 | `docs-sync` | 三文档同步更新：FLOW-KIT-用户指南.md §8 新增 brooks-tools 离线打包 · README.md 结构树 + 快速开始修正 · flow-kit-ecosystem-guide.md 新增 PCSC/PG/Rollback/brooks-tools · 全局版本号 + 过时内容清理 | — |
| 2026-06-22 | `bundle-packaging` | brooks-lint npm 工具离线打包：package-flow-kit.sh 新增 Part G（npm pack 4 工具 + 依赖树）· install_brooks_tools.sh 新建（shim 生成 + PATH 检测）· install.sh 集成 check_node + --no-brooks-tools flag · 5 个 bats 测试 · 全链路 0→7 pipeline 自动执行 | — |
| 2026-06-22 | `docs-update` | 更新 FLOW-KIT-用户指南.md (+145行)：新增 §4.1 Goal 系统与 Pipeline 执行模型 | — |
| 2026-06-18 | `integrate-goal-command` | 整合 CC /goal 到 flow-kit：.flow-active goal 字段 + /flow goal 子命令（set/status/clear）+ GO.md/4-dev.md/resume hook 集成 + 内置回退 + AC 自动提取 + 7 bats 测试 | — |
| 2026-06-17 | `debt-cleanup` | 清理剩余技术债（3 合 1）：STAGING 前置校验 · CONFIG_FILE 覆盖修复 · jq bracket 引用防连字符解析 | L-005/L-009/L-011 resolved |
| 2026-06-17 | `bundle-packaging` | 修复打包脚本 Part E 漏 `lib/` 目录导致安装失败；打包 v20260617-171947 验证通过 | L-012 |
| 2026-06-16 | `health-fix` | 健康巡检修复（7 项技术债）：引入 bats-core 28 测试 · hooks 去重 · install.sh 拆分（517→202行+4 lib）· 魔法数字 readonly · 外部路径 fallback · settings.json 去重 · brooks-lint 动态版本号 | L-009 ~ L-011 |
| 2026-06-14 | `brooks-lint-hook-fix` | brooks-lint SessionStart hook 空 commands 目录容错：cp glob → for f + [ -f ] 保护；package-flow-kit.sh 安装后自动修补 hook | L-006 |
| 2026-06-10 | `fix-brooks-bundle-full` | 全包 offline brooks-lint 安装修复（5 合 1）：(1) installed_plugins.json 写 CC v2 格式 (2) installPath: marketplaces→cache (3) 双写 cache+marketplaces (4) known_marketplaces.json 注册 (5) 移除 F1 commands 防 skill 重复。含 --reinstall 全量清理。全量 E2E 测试通过 | — |
| 2026-06-09 | `user-scope-install` | 支持 flow-kit 核心引擎 user-scope 全局安装：install.sh --user + flow-go FLOW_KIT_ROOT 两级查找 + symlink 方案。修复 jq 退出码 5 导致 hooks 静默不安装的 bug | — |
| 2026-06-09 | `hook-user-scope` | Hook 系统 user scope 支持：--user flag + common.sh CONFIG_FILE 优先 ~/.claude/ + 全组件双 scope 审计（7/7 通过） | — |
| 2026-06-08 | `install-update-reinstall` | install.sh 增加 --update（版本比对智能跳过）和 --reinstall（清空重装），.flow-kit-version 版本标记 | — |
| 2026-06-08 | `offline-brooks-bundle` | 打包脚本 Part F 离线化：rsync 本地缓存替代 git archive（三级优先级：--brooks-src > 本地缓存 > git archive），自动版本选择 | — |
| 2026-06-08 | `init-git-repo` | 初始化 Git 仓库（main 分支 + Conventional Commits），建立 .gitignore / README / 技术债基线（LESSONS.md 5 条），同步 CONTEXT 和 STATE | L-001 ~ L-005 |
- **pipeline-goal** (2026-06-18): Goal 从单阶段自循环扩展到跨阶段 Pipeline — 6 files, +396/-15, 12 AC covered, review passed

## 2026-06-22 — pcsc-audit-v2

PCSC/PG 双层防护全面审计（12 项发现：1🔴 + 4🟡 + 7🟢）

| # | 严重度 | 维度 | 简述 |
|---|---|---|---|
| A1 | 🔴 | Logic | 0-change 没有 PCSC 段 |
| A2 | 🟡 | Logic | 1/2/3 toll-gate 缺少 auto_advance 分支 |
| B1 | 🟡 | Coverage | 7-integration 缺少 Sub-goal 汇总 |
| C1 | 🟡 | PCG | Phase 4 PCG 不检查 SUMMARY 文件 |
| D1 | 🟡 | Install | 安装脚本无文件级校验 |
| A3 | 🟢 | Logic | 4-dev 选项4说明过时 |
| B2 | 🟢 | Coverage | 7-integration 缺少出PR步骤 |
| B3 | 🟢 | Coverage | 4-dev PCSC 未显式检查 self-review |
| B4 | 🟢 | Coverage | 5-test 矩阵/UAT 子步骤未展开 |
| C2 | 🟢 | PCG | PCG 延迟到下次路由触发 |
| C3 | 🟢 | PCG | PCG 表无 phase 7 |
| D2 | 🟢 | Install | 无 post-install 自检 |
