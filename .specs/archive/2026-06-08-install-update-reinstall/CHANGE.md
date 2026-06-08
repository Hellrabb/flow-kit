# CHANGE: install.sh 增加 --update / --reinstall 模式

- **Change ID**: `install-update-reinstall`
- **创建日期**: 2026-06-08
- **路径建议**: 快速（small change，~40 行 diff）
- **状态**: draft

---

## Why（为什么做）

- 用户在离线目标机上拿到新 bundle 后，不知道该怎么更新——当前只能跑 `./install.sh --global` 覆盖，没有明确的 update/reinstall 语义
- 用户希望 bundle 自带 update/reinstall 能力，在离线机上告诉 Claude「更新 flow-kit」就能执行，无需回忆 flag 组合
- 版本盲更新有风险：用户可能拿旧 bundle 覆盖新版安装

## What（做什么）

1. **打包阶段**（`package-flow-kit.sh` Part E）：生成 `.flow-kit-version` 文件到 bundle 根目录，内容为打包时间戳（`YYYYMMDD-HHMMSS`）
2. **`--update` 模式**（智能版本比对）：
   - 读取已安装版本（`~/.claude/.flow-kit-version`）
   - 若 bundle 版本 ≤ 已安装版本 → 跳过，打印"已是最新版本"
   - 若已安装版本更老或不存在 → 执行更新（等同于 `--global`，但标记为 update 模式）
3. **`--reinstall` 模式**（彻底重装）：
   - 先 `rm -rf` 既有安装目录（flow-kit/skills/brooks-lint plugin）
   - 再执行完整 `--global` 安装
   - 安装完成后写入新版本标记
4. **安装后**：首次安装和 update 都在 `~/.claude/` 写入 `.flow-kit-version`

## 影响面

- [x] 影响 `REQUIREMENT.md`（新建）
- [x] 影响 `DESIGN.md`（新建 · `package-flow-kit.sh` Part E heredoc 修改）
- [ ] 影响现有 AC（不涉及已有 change）

## 范围排除（这次不做）

- **不修改** 打包流程的其他 Part（A-D, F-G）
- **不引入** semver 严格解析（v2 — 当前时间戳比对已够用）
- **不添加** `--rollback` 回滚功能（超出当前需求）
- **不修改** `--project` / `--hooks-only` 路径

## 验收线（粗粒度）

1. `./install.sh --update` 在已装同版本时跳过，旧版本时更新
2. `./install.sh --reinstall` 先清空再安装，最终状态等同于全新 `--global`
3. `.flow-kit-version` 在安装 path 中正确写入
4. bundle 中 README.md 列出 `--update` / `--reinstall` 用法
