# INTEGRATION — dsh-flow-kit-sync-2026-09（阶段 7 集成）

## 打包产物

- dist/dsh-flow-kit（包目录）+ dist/dsh-flow-kit-0.2.0.tgz
- 两 profile 的 package.json 依赖：
  `"dsh-flow-kit": "file:/home/hellrabbit/unisoc/flow-kit/dist/dsh-flow-kit"`

## 重装与验证命令

```bash
bash package-dsh-plugin.sh
rm -rf ~/.dsh/profiles/web/node_modules/dsh-flow-kit \
         ~/.dsh/profiles/flowkit-test/node_modules/dsh-flow-kit   # 强制刷新 file: 硬链
(cd ~/.dsh/profiles/web && pnpm install)
(cd ~/.dsh/profiles/flowkit-test && pnpm install)
dsh --profile web --dump-config | grep -A 5 '# == dsh-flow-kit'
dsh --profile flowkit-test --dump-config | grep -A 5 '# == dsh-flow-kit'
```

## 验证结果

- 两 profile node_modules 版本 0.2.0；hooks/stop/lib/common.sh 含
  DEFAULT_MODEL（tier-4/5），inode 与 dist 一致（硬链）
- dump-config：`- id: flow-kit / name: dsh-flow-kit / inject: [commands, skills,
  systemPrompt]`
- flowkit-test 顺带修复 pnpm 10 allowBuilds（node-pty/koffi/protobufjs/
  subprocess-local → true），原生构建恢复

## 注意事项

- 运行中的 dsh web 会话进程仍是旧版插件内存映像；磁盘已更新，重启会话生效。
- .done 锚点为运行时状态（.specs/<id>/.independent-review-7.done），按仓库惯例
  不入库。
