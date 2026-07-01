# CHANGELOG

> 按日期倒序。每行：日期 / change-id / 摘要 / LESSONS 新增。

| 日期 | Change ID | 摘要 | LESSONS |
|---|---|---|---|
| 2026-07-01 | `health-fix-2026-07` | 修复 `package-flow-kit.sh` 末尾孤儿 `fi`（581-587 残留碎片）导致 `bash -n` 失败 + 正常打包退出码非 0 · 新增 5 回归测试（AC-1~4：package 专项 + 全量 `bash -n` 门禁 smoke）· flow-health SKILL 增补步骤 2.6 全量语法门禁（AC-5，堵 2026-06-30 巡检盲区）· 181 bats 全绿 | — |
| 2026-06-29 | `robustness-hook-hardening` | 弱模型鲁棒性 Hook 化升级：Stop hook 28 号模块 L1+L2+L3 系统级事后验证 + 统一矫正文件 `.flow-active.correction` + SessionStart 矫正注入 · 283 行净逻辑代码 · 14 个新增 bats 测试 · 176 tests 全绿 | L-014 |
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

## [weak-model-interactive-ui] — 2026-06-29

### 变更摘要

弱模型交互式 UI 触发强化：hook 脚本为主防线 + prompt 轻量护栏为辅，确保弱模型在 flow-kit 交互 gate 处实际调用 `AskUserQuestion` / `EnterPlanMode` 工具。

### 新增

- `hooks/stop/27-interactive-ui-check.sh` — Stop hook 模块：检测弱模型是否跳过了交互 gate
- `hooks/stop/lib/interactive-ui-check.sh` — 交互 UI 检测逻辑库（GATE_MAP + 检测函数 + 矫正文件管理）
- `reference/interactive-ui-guard.md` — Prompt 层护栏参考模板
- `regression-demos/weak-model-interactive-ui/` — 回归演示（模拟 transcript + check.sh）
- `test/test_interactive_ui_check.bats` — 24 个 bats 测试
- `stop-hook.json` 新增 `interactive_ui_check` 模块开关

### 修改

- 8 个 prompt 文件（GO.md + 7 个阶段 prompt）— 13 处轻量护栏（≤3 行/点）
- `session-start/flow-kit-resume.sh` — 矫正文件检测 + 矫正 banner 注入
- `package-flow-kit.sh` — 新文件打包覆盖
- `CONTEXT.md` — 术语 + 已锁决策更新

### 架构决策

- 双层防线：hook 脚本（系统级不可绕过）+ prompt 护栏（预防 ~60% 跳过）
- GATE_MAP 集中维护 9 个交互 gate 关键词映射
- 矫正文件 `.flow-active.interactive-ui-fix`（不入库）跨 turn 传递
- 连续跳过 ≥3 次时停止自动矫正提示人工介入

### 测试基线

194/194 tests pass（24 new + 162 existing + 8 regression demo）
| 2026-07-01 | independent-review | L2 盲审 + L3 hook 强制独立 review（1/2/6 阶段，默认关闭）| — |
| 2026-07-01 | sweep-fix-2026-07 | 修复全量健康扫描 6 项技术债（hook列表去重/查表驱动/correction统一/bats安装/格式审计/注释） | — |
