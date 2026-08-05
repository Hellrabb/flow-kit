# T01-SUMMARY — pre-commit.sh 新建

## 做了什么

新建 `flow-kit-bundle/hooks/pre-commit/pre-commit.sh`（30 行）—— git commit 前跑 `make test` 硬门禁。

## 实现

- `#!/bin/bash + set -euo pipefail`（仓库默认 · L2 #8）
- PATH 补齐（D2 R9）：source /etc/profile + ~/.profile + NVM_DIR + ~/.local/bin
- 四分支：无 Makefile → skip / npx 不可见 → skip / make test fail → exit 1 / make test pass → exit 0
- 英文契约串（N1）：`no Makefile, skipping test gate` / `test failed, commit rejected`
- chmod +x

## verify

```
bash -n flow-kit-bundle/hooks/pre-commit/pre-commit.sh → ✅
test -x → ✅
四分支 grep 检查 → 1/1/1/3 ✅
```

## 6 维自查（内置快查 · 30 行单职责脚本）

- R1 ✅ 30 行无嵌套 / R2 ✅ 仅新建文件 / R3 ✅ 无重复 / R4 ✅ 无过度抽象 / R5 ✅ 无依赖 / R6 ✅ 语义清晰

## 越界检查

diff 仅含 `flow-kit-bundle/hooks/pre-commit/pre-commit.sh`（新建）→ 0 越界 ✅

## 沿用既有抽象

无既有 pre-commit 抽象可复用（全新文件）。set -euo pipefail 对齐仓库默认。
