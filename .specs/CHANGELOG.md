# CHANGELOG

> 按日期倒序。每行：日期 / change-id / 摘要 / LESSONS 新增。

| 日期 | Change ID | 摘要 | LESSONS |
|---|---|---|---|
| 2026-06-17 | `debt-cleanup` | 清理剩余技术债（3 合 1）：STAGING 前置校验 · CONFIG_FILE 覆盖修复 · jq bracket 引用防连字符解析 | L-005/L-009/L-011 resolved |
| 2026-06-16 | `health-fix` | 健康巡检修复（7 项技术债）：引入 bats-core 28 测试 · hooks 去重 · install.sh 拆分（517→202行+4 lib）· 魔法数字 readonly · 外部路径 fallback · settings.json 去重 · brooks-lint 动态版本号 | L-009 ~ L-011 |
| 2026-06-14 | `brooks-lint-hook-fix` | brooks-lint SessionStart hook 空 commands 目录容错：cp glob → for f + [ -f ] 保护；package-flow-kit.sh 安装后自动修补 hook | L-006 |
| 2026-06-10 | `fix-brooks-bundle-full` | 全包 offline brooks-lint 安装修复（5 合 1）：(1) installed_plugins.json 写 CC v2 格式 (2) installPath: marketplaces→cache (3) 双写 cache+marketplaces (4) known_marketplaces.json 注册 (5) 移除 F1 commands 防 skill 重复。含 --reinstall 全量清理。全量 E2E 测试通过 | — |
| 2026-06-09 | `user-scope-install` | 支持 flow-kit 核心引擎 user-scope 全局安装：install.sh --user + flow-go FLOW_KIT_ROOT 两级查找 + symlink 方案。修复 jq 退出码 5 导致 hooks 静默不安装的 bug | — |
| 2026-06-09 | `hook-user-scope` | Hook 系统 user scope 支持：--user flag + common.sh CONFIG_FILE 优先 ~/.claude/ + 全组件双 scope 审计（7/7 通过） | — |
| 2026-06-08 | `install-update-reinstall` | install.sh 增加 --update（版本比对智能跳过）和 --reinstall（清空重装），.flow-kit-version 版本标记 | — |
| 2026-06-08 | `offline-brooks-bundle` | 打包脚本 Part F 离线化：rsync 本地缓存替代 git archive（三级优先级：--brooks-src > 本地缓存 > git archive），自动版本选择 | — |
| 2026-06-08 | `init-git-repo` | 初始化 Git 仓库（main 分支 + Conventional Commits），建立 .gitignore / README / 技术债基线（LESSONS.md 5 条），同步 CONTEXT 和 STATE | L-001 ~ L-005 |