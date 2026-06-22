# CHANGE: 修复 brooks-tools bin/ 下缺少可执行 wrapper 导致 shim 生成失败

- **Change ID**: fix-shim-bin-path
- **创建日期**: 2026-06-22
- **路径**: 单点修复（直修，不走全 pipeline）

## 问题
离线环境测试时 `install_brooks_tools.sh` 报：
`⚠️ 工具 depcheck 未找到于 ~/.claude/tools/brooks-lint/bin/，跳过 shim 生成`

## 根因
`package-flow-kit.sh` Part G 只复制 npm 包的 `package/bin/*`（含 .js 源文件），
未生成无后缀的可执行 wrapper。`install_brooks_tools.sh` 查找 `bin/depcheck`（无 .js），找不到就跳过。

此外 `cp -r`（rsync 不可用时的回退）不保留执行权限，tar 解压也可能丢失 x-bit。

## 修复
1. package-flow-kit.sh Part G：循环后自动为 .js 文件生成 shell wrapper + node_modules/.bin/ 兜底合并
2. install_brooks_tools.sh：find + chmod +x 兜底确保 bin/ 下所有文件可执行
