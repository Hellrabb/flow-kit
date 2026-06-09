# REQUIREMENT: install.sh 增加 --update / --reinstall 模式

- **Change ID**: `install-update-reinstall`
- **关联**: `@.specs/archive/2026-06-08-install-update-reinstall/CHANGE.md`

---

## 用户故事

- **US-1**：作为离线机用户，我想用 `--update` 智能更新 flow-kit，以便拿到新 bundle 后一键更新而不需要记得 flag 组合。
- **US-2**：作为离线机用户，我想用 `--reinstall` 彻底重装，以便出问题时清空既有安装重新来过。

## 验收准则（AC）

### AC-1 · --update 版本比对
- **Given** 已装版本 `20260601-000000`，bundle 版本 `20260608-164203`
- **When** `./install.sh --update`
- **Then** 检测到 bundle 更新 → 执行安装；日志含 `20260601-000000 → 20260608-164203`
- **验证方式**: bundle 版本 > 已装版本时执行更新

### AC-2 · --update 跳过同版本
- **Given** 已装版本 = bundle 版本
- **When** `./install.sh --update`
- **Then** 打印"已是最新版本"并 exit 0
- **验证方式**: `echo $?` == 0

### AC-3 · --reinstall 清空重装
- **Given** 已有既有安装
- **When** `./install.sh --reinstall`
- **Then** 先 rm -rf 既有目录，再执行全新 --global 安装
- **验证方式**: 安装后 `~/.claude/.flow-kit-version` 等于 bundle 版本

### AC-4 · .flow-kit-version 写入
- **Given** 安装完成
- **When** global 或 reinstall 模式
- **Then** bundle 版本写入 `~/.claude/.flow-kit-version`
- **验证方式**: `cat ~/.claude/.flow-kit-version` 非空

---

## 范围切分

### v1（本次必做）
- --update / --reinstall 模式
- .flow-kit-version 生成与写入
- bundle README 更新

### v2（下一轮）
- semver 严格解析
- --rollback 回滚功能

### out
- 不修改打包流程其他 Part
- 不引入 npm/Node.js 依赖
