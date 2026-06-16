# CHANGE: 健康巡检修复 — 消除技术债 + 引入测试

- **Change ID**: `health-fix`
- **创建日期**: 2026-06-16
- **路径建议**: 完整（涉及新工具引入 + 源码结构变更 + 测试）
- **状态**: active

---

## Why（为什么做）

2026-06-16 健康巡检得分 62/100，发现 2 项 🔴 Critical + 4 项 🟡 Warning + 2 项 🟢 Suggestion：

- **零测试覆盖**：19 个 shell 脚本 ~3700 行代码无任何自动验证。项目本身提倡 TDD 流程但自身无测试，最近 14 个 commit 有 11 个是 fix，全靠人工审查。
- **hooks 双重维护**：`.claude/hooks/` 与 `flow-kit-bundle/hooks/` 16 个文件 100% 相同，任何修改必须手动同步两处。
- **install.sh 517 行**：单体脚本混合 CLI 解析 + 5 类安装逻辑 + jq/sed 修补，修改任一部分需通读全文。
- **魔法数字散落**：5 个文件中裸数字阈值无命名常量，含义不透明。
- **外部路径依赖**：`package-flow-kit.sh` 从 `~/.claude/flow-kit/` 等机器特定路径读源，换机器打包失败。
- **模板重复**：settings.json 同时以 heredoc 和独立文件存在。
- **版本号硬编码**：brooks-lint 版本号 `1.3.0` 写死在 install.sh 中。

## What（做什么）

一次性修复全部 7 项健康问题：

1. **引入 bats-core 测试框架**，为 `common.sh` + `install.sh --dry-run` 编写 smoke test
2. **消除 hooks 双重维护**：保留 `flow-kit-bundle/hooks/` 为唯一源，删除 `.claude/hooks/`，更新 `package-flow-kit.sh` 引用路径
3. **拆分 install.sh**：提取 `lib/install_core.sh`、`lib/install_skills.sh`、`lib/install_brooks.sh`、`lib/install_hooks.sh`，主脚本仅保留 CLI 解析 + 调度
4. **定义命名常量**：在 `24-session.sh`、`flow-kit-resume.sh`、`flow-kit-artifacts.sh`、`23-quality.sh` 中用 `readonly` 常量替换裸数字
5. **修复外部路径依赖**：`package-flow-kit.sh` Part A 优先从 `flow-kit-bundle/flow-kit/` 本地副本读取，外部路径作为可选覆盖
6. **settings.json 模板去重**：`package-flow-kit.sh` 改为 `cp` 文件模板替代 heredoc
7. **brooks-lint 版本号动态读取**：从 `brooks-lint/plugin/.claude-plugin/plugin.json` 读取版本号

## 影响面

- [x] 影响 `REQUIREMENT.md`
- [x] 影响 `DESIGN.md` / 引入新 ADR
- [ ] 影响现有 AC（无既有 AC）
- [ ] 影响数据模型 / 迁移
- [ ] 影响外部 API 兼容性
- [ ] 仅修复 bug，无范围变化

## 范围排除（这次不做）

- 不修改 brooks-lint 插件本身的源码（vendor 副本，应在源仓库修）
- 不修改 flow-kit 核心引擎的 prompts/templates（来自上游 flow-kit repo）
- 不引入 CI/CD（测试框架只到本地运行级别）
- 不修改 `stop-hook.json` 模块配置结构

## 验收线（粗粒度，不是 AC）

- `bats test/` 全部通过，覆盖 `common.sh` 核心函数 + `install.sh` 参数解析
- `.claude/hooks/` 目录已删除，`package-flow-kit.sh` 从 `flow-kit-bundle/hooks/` 读取
- `install.sh` 拆分为 ≤ 5 个文件，主脚本 ≤ 150 行
- `package-flow-kit.sh` 在未装 `~/.claude/flow-kit` 的机器上仍可正常打包（Part A fallback 到本地副本）

## 风险与未知

- **bats-core 引入**：需确认目标环境（离线机器）是否支持 `apt install bats` 或 bundle 内携带 bats 二进制
- **hooks 去重**：`.claude/hooks/` 删除后需确认 install.sh 的用户级/项目级 hook 安装路径不受影响；当前 install.sh 从 `$SCRIPT_DIR/hooks/`（即 `flow-kit-bundle/hooks/`）读源，不受影响
- **install.sh 拆分**：source 路径变化可能影响 `--dry-run` 模式
- **外部路径 fallback**：Part B（skills）和 Part F（brooks-lint）同样依赖外部路径，需逐项评估是否一起修
