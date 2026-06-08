# CHANGE: 打包脚本离线化 brooks-lint 分发

- **Change ID**: `offline-brooks-bundle`
- **创建日期**: 2026-06-08
- **路径建议**: 完整
- **状态**: draft

---

## Why（为什么做）

- 当前 `package-flow-kit.sh` Part F 打包 brooks-lint 时使用 `git archive` 从 `~/.claude/plugins/marketplaces/brooks-lint-marketplace`（本地 git clone），**强依赖 git**。若 marketplace 缓存损坏或迁移到新机器，打包阶段就会失败
- 用户目标：完全离线环境（无 npm registry / 无 git clone / 无网络）下打包和安装
- 当前 `install_brooks_lint()` 已是纯文件复制（离线友好 ✅），但打包侧仍需加固
- 与 LESSONS.md L-002 关联：当前打包脚本的 brooks-lint 源路径硬编码，需改为可配置

## What（做什么）

1. **打包侧改造**（`package-flow-kit.sh` Part F）：
   - 用 `rsync` 从本地缓存目录（`~/.claude/plugins/cache/brooks-lint-marketplace/brooks-lint/<version>/`）替代 `git archive` 作为源
   - 支持 `--brooks-src <path>` 覆盖源路径，默认自动检测最新版本缓存
   - **不嵌入 Node.js**（已验证 brooks-lint 终端用户不需要：skills 纯 markdown，无二进制依赖）
2. **bundle 体积**：保持 ~300KB（不引入 node_modules 或 node 二进制）
3. **产物验证**：确保打包后的 brooks-lint 在未联网目标机上可被 Claude Code 加载（skills + commands + hooks 完整）

## 影响面

- [x] 影响 `REQUIREMENT.md`（新建）
- [x] 影响 `DESIGN.md`（新建 · `package-flow-kit.sh` 修改涉及 § 2.1 既有架构）
- [ ] 影响现有 AC（不涉及已有 change）
- [ ] 影响数据模型 / 迁移（不涉及）
- [ ] 影响外部 API 兼容性（不涉及）

## 范围排除（这次不做）

- **不修改** `install_brooks_lint()` 的安装逻辑（已是纯文件复制，离线兼容）
- **不支持** 多平台 Node.js（仅 Linux x64）
- **不升级** brooks-lint 版本（维持当前 1.3.0，升级另开 change）
- **不改变** bundle 外其他部分的打包逻辑（skills/hooks/core 保持不变）
- **不添加** Node.js 版本管理（如 nvm/n）—— 仅 bundle 一个固定版本 node 二进制

## 验收线（粗粒度，不是 AC）

1. `package-flow-kit.sh` 在离线环境（断网 + 无 npm registry）下成功打出含 brooks-lint 的 bundle
2. 目标机安装后 `~/.claude/commands/brooks-*.md` 存在，`~/.claude/plugins/marketplaces/brooks-lint-marketplace/` 有完整插件文件
3. brooks-lint 命令（`/brooks-review` 等 6 个）在 Claude Code 中可正常调用
4. `--brooks-src <path>` 参数生效，可指定自定义 brooks-lint 源目录

## 风险与未知

- **brooks-lint 缓存版本漂移**：若用户升级了 brooks-lint（如 1.3.0 → 1.4.0），缓存目录结构可能变化 → 自动检测 `<cache>/<latest-version>/` 或 fallback 到用户指定的 `--brooks-src`
- **离线验证困难**：无法在当前环境真正断网测试，需用户在实际离线目标机上验证
- **git archive 降级策略**：若本地缓存不可用且 `--brooks-src` 未指定，可回退到原有 `git archive` 路径（如果 marketplace git repo 可用）

---

> 后续 AC 与设计细节进入 `REQUIREMENT.md` / `DESIGN.md`，本文件不再扩展。
