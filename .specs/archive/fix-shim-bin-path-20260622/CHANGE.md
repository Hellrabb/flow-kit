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

## 第二轮修复 (2026-06-22)

### 新发现
- depcheck/knip wrapper 生成成功但 `--version` 失败：npm pack 不含 node_modules，工具依赖全部缺失
- jscpd/ts-prune 无 `bin/` 目录：bin 入口在 `package.json` 的 `bin` 字段中定义，路径为 `./run-jscpd.js` / `./lib/index.js`，未被复制
- ts-prune 的 `npm install` 因 devDependencies 中的 peer 冲突（ts-jest → typescript <4.0 vs 4.9.5）而失败

### 第二轮修复
1. Part G 在解压后执行 `npm install --omit=dev --ignore-scripts --legacy-peer-deps`，安装生产依赖
2. 用 jq 解析 `package.json` bin 字段（兼容对象和字符串两种格式），自动定位 entry 文件
3. 生成的 shell wrapper 保持 entry 文件在原位（`extracted/<tool>/package/`），通过相对路径引用
4. NODE_PATH 指向合并的 `node_modules/`，确保依赖可解析

### 验证结果
- depcheck 1.4.7 ✅
- jscpd cpd 5.0.11 ✅
- knip 6.17.1 ✅
- ts-prune 可执行（需 tsconfig.json，TypeScript 项目正常行为）⚠️
- bats 94/94 ✅
