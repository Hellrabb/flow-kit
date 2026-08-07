# T10-SUMMARY · package-flow-kit.sh 打包覆盖验证（含 .opencode/agent）

> change: `l2l3-cross-platform` · task: T10（AC-5 package 覆盖验证）· 完成日期: 2026-08-07

## 结论

**零改动**。rsync -a 自动覆盖 `.opencode/agent/` 成功，package-flow-kit.sh 未做任何修改，flow-kit-bundle/ 下无任何触碰。

## 验证步骤 1：确认 Part A 结构

`package-flow-kit.sh` L38-40 主路径：

```bash
if [ -f "$SCRIPT_DIR/flow-kit-bundle/flow-kit/GO.md" ]; then
  echo "   ℹ️  使用本地副本: flow-kit-bundle/flow-kit/"
  rsync -a --exclude='.git' "$SCRIPT_DIR/flow-kit-bundle/flow-kit/" "$STAGING/flow-kit/"
```

- `rsync -a` = `-rlptgoD`，**默认包含 dotfile**（无 `--exclude` dotfile 规则）
- 源文件已由 T08 就位：`flow-kit-bundle/flow-kit/.opencode/agent/flow-kit-l2-reviewer.md`（13955 字节）

## 验证步骤 2：真实打包 + tar/staging 检查

### 真实打包（bash 调用，见下方说明）

```
$ bash package-flow-kit.sh 2>&1 | tail -25
╔═══════════════════════════════════════════════════════════════╗
║  ✅ 打包完成!                                                ║
║  📁 flow-kit-full-20260807-001329.tar.gz (25M)
║  📂 解压后: /home/hellrabbit/flow-kit-export/flow-kit-full-20260807-001329/
...
║    🎯 17 个 flow skills                                     ║
╚═══════════════════════════════════════════════════════════════╝
```

### TASK verify 命令执行

```
$ ./package-flow-kit.sh 2>&1 | tail -20; echo "---VERIFY-CHECK---"; tar -tzf flow-kit-bundle.tar.gz 2>/dev/null | grep "opencode/agent" || (rsync -a --exclude='.git' flow-kit-bundle/flow-kit/ /tmp/fk-staging/ && test -f /tmp/fk-staging/.opencode/agent/flow-kit-l2-reviewer.md && echo "staging OK")
/bin/bash: 行 1: ./package-flow-kit.sh: 权限不够
---VERIFY-CHECK---
staging OK
```

> 说明：`./package-flow-kit.sh` 直跑失败因脚本无执行权限（mode 644）——仓库 README 亦规定 `bash package-flow-kit.sh` 调用方式，`./` 非预期入口，故**不属验证失败**。STAGING 回退路径随即通过（`staging OK`）。

### 打包产物检查（真实 tarball + staging 目录）

```
$ TARBALL=$(ls -t $HOME/flow-kit-export/flow-kit-full-*.tar.gz | head -1)
$ tar -tzf "$TARBALL" | grep "opencode/agent"
flow-kit-full-20260807-001329/flow-kit/.opencode/agent/
flow-kit-full-20260807-001329/flow-kit/.opencode/agent/flow-kit-l2-reviewer.md
$ stat -c '%s %n' <staging>/flow-kit/.opencode/agent/flow-kit-l2-reviewer.md
13955 /home/hellrabbit/flow-kit-export/flow-kit-full-20260807-001329//flow-kit/.opencode/agent/flow-kit-l2-reviewer.md
$ head -3 <staging>/flow-kit/.opencode/agent/flow-kit-l2-reviewer.md
---
name: flow-kit-l2-reviewer
description: flow-kit L2 独立盲审（gate_config both 各阶段）——按需路由命中专用，对 flow-kit 各阶段产物做独立盲审（L2-blind-review 固化指令）
```

## done 判据逐项核对

| 判据 | 结果 |
|---|---|
| 打包产物含 `flow-kit/.opencode/agent/flow-kit-l2-reviewer.md`（AC-5 package 覆盖） | ✅ tar 内两行命中（目录 + 文件）；staging 目录文件存在 13955 字节，内容抽查与 T08 产物一致 |
| rsync -a 自动覆盖 | ✅ 零改动达成，无需 `--include` 显式规则或 cp 行 |
| 禁动例外 | ✅ 未触发（例外登记仅作为后备授权，本次未使用） |

## 决策 / 偏离

- **零改动**：Part A 的 `rsync -a --exclude='.git'` 天然覆盖 `.opencode/`（rsync -a 默认含 dotfile），无需加显式 rsync include 或 cp。TASK 预设的「最小改动」分支未进入。
- 观察项（不处理）：`package-flow-kit.sh` mode 644 无执行位，`./` 直跑报「权限不够」。仓库既有约定即 `bash package-flow-kit.sh`（README 快开始段落），非本 change 引入，未修改文件属性。
- 验证产物留在 `~/flow-kit-export/flow-kit-full-20260807-001329.tar.gz`（25M）供主 agent 统一处理。
- 未 commit（按流程要求）。
