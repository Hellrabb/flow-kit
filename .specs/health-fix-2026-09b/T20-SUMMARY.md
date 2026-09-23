# T20-SUMMARY · AC-6 ③ pre-commit 仓库内源接入 `check-path-privacy`

> 变更 `health-fix-2026-09b` 阶段 4（DEV）· Wave 4 · 2026-09-23
> 产物：`flow-kit-bundle/hooks/pre-commit/pre-commit.sh`（产品件）+ `TASK.md`（仅 T20 状态 `pending`→`done`）
> 依 L-129 / L-137：本 SUMMARY 所有本机绝对路径已 de-shape 为 `<repo>` / `$HOME` / `/home/<acct>/` 形态；rc、命令、输出文本与数字保持原样。

## 0 结论

T20 **完成**：`pre-commit.sh` 已在 `make test` 之后接线 `make check-path-privacy`，失败必阻塞 commit（非零退出 + `[archive-commit-gate] path-privacy check failed, commit rejected`）。判据 rc=0，门禁全部绿，历史判据全过。判别力夹具证明新增调用有真牙：改桩 `check-path-privacy` 失败 ⇒ hook rc=1 拒绝；全 0 桩 ⇒ hook rc=0；而 pre-T20 钩子（只有 `make test`）在隐私门禁失败时 rc=0 会放行 ⇒ 对比成立。

## 1 交付物

### ① `flow-kit-bundle/hooks/pre-commit/pre-commit.sh`
- 行数：**before 32 → after 38**（+6：注释行改写 1 行（含 `make check-path-privacy` 字样）+ 新增 `check-path-privacy` 阻塞 6 行块）
- sha256：`728de9b3f377a61a138eb7c460b1bce5b1908d1d1029e9a16efb1d5b1f3f3dc4`
- 最终全文：

```bash
#!/bin/bash
set -euo pipefail

# pre-commit.sh — flow-kit 归档 commit 门禁
# make test 与 make check-path-privacy 非零退出码拒绝 commit。无 Makefile / npx 不可见时跳过。
# 部署：install_hooks.sh deploy_pre_commit() → symlink .git/hooks/pre-commit → 已安装 hooks 目录

# PATH 补齐（D2 R9 修复 · npx/node 可见性）
[ -f "$HOME/.profile" ] && { source "$HOME/.profile" 2>/dev/null || true; }
[ -n "${NVM_DIR:-}" ] && [ -f "$NVM_DIR/nvm.sh" ] && { source "$NVM_DIR/nvm.sh" 2>/dev/null || true; }
[ -d "$HOME/.local/bin" ] && export PATH="$HOME/.local/bin:$PATH"
[ -d /usr/local/bin ] && export PATH="/usr/local/bin:$PATH"

# 无 Makefile → 跳过
if [ ! -f Makefile ]; then
  echo "[archive-commit-gate] no Makefile, skipping test gate"
  exit 0
fi

# npx 不可见 → warn + 跳过
if ! command -v npx >/dev/null 2>&1; then
  echo "[archive-commit-gate] npx not found, skipping test gate"
  exit 0
fi

# make test
if ! make test; then
  echo "[archive-commit-gate] test failed, commit rejected" >&2
  exit 1
fi

# make check-path-privacy（路径隐私门禁 · health-fix-2026-09b AC-6 ③）
if ! make check-path-privacy; then
  echo "[archive-commit-gate] path-privacy check failed, commit rejected" >&2
  exit 1
fi

exit 0
```

### ② `TASK.md`
仅 line 882 一处属性翻转：`<task id="T20" parallel="true" status="pending" model-tier="cheap">` → `status="done"`。

### ③ `T20-SUMMARY.md`
本文件（新增）。

## 2 判据实跑

重抽 T20 `<verify>` 块（剥 4 空格缩进），`cmp /tmp/vblocks/v_T20.sh` rc=0（3 行），实跑：

```
$ bash /tmp/vblocks/v_T20.sh
源: <repo>/flow-kit-bundle/hooks
镜像文件数: 48（stop 模块与 install_hooks.sh 同源计数）

  ✅ $HOME/.claude/hooks
  ✅ <repo>/dist/dsh-flow-kit/hooks
  ✅ <repo>/dist/dsh-flow-kit/vendor/flow-kit-bundle/hooks
  ✅ $HOME/.dsh/profiles/web/node_modules/dsh-flow-kit/hooks
  ✅ $HOME/.dsh/profiles/web/node_modules/dsh-flow-kit/vendor/flow-kit-bundle/hooks
  ✅ $HOME/.config/opencode/hooks

✅ hooks 副本一致（漂移 0）
CRITERION rc=0
```

`wc -l /tmp/vblocks/v_T20.sh` = 3；判据含：`grep -q 'check-path-privacy'` 仓库内源 + `bash -n` 语法 + `bash sync-hooks.sh --check` 漂移 0。**不断言**仓外 symlink（L2 C2）。

## 3 门禁与回归

| 门禁 / 判据 | 结果 | rc |
|---|---|---|
| `bash sync-hooks.sh --check` | `✅ hooks 副本一致（漂移 0）` | **0** |
| `make check-hooks-sync` | `✅ hooks 副本一致（漂移 0）` | **0** |
| `npx bats test/` | **973 pass / 0 not ok / 0 skip**（plan `1..973`，末端 `ok 973 ...`） | **0** |
| `make lint` | `✅ shellcheck: no errors found` | **0** |
| `make check-path-privacy` | `允许清单 0 条` / `命中合计 0 条（含占位符排除后）` / `清单外命中 0 条` → `✅ 清单外命中 0 条` | **0** |
| `bash /tmp/vblocks/v_T17.sh`（check-path-privacy.sh 源 + 目标 + 接线） | — | **0** |
| `bash /tmp/vblocks/v_T18.sh`（Makefile 接线 + .PHONY + 反掩蔽） | — | **0** |
| `bash /tmp/vblocks/v_T20.sh`（本任务判据） | 见 §2 | **0** |
| `bash /tmp/vblocks/v_T21.sh`（允许清单页） | `自报=0 / 常设有效行=0` | **0** |
| `bash /tmp/vblocks/v_T22.sh` | — | **0** |
| `bash /tmp/vblocks/v_T23.sh` | — | **0** |
| `bash /tmp/vblocks/v_T25.sh`（镜像副本一致性） | `✅ 全部副本已一致，无需同步` + `✅ hooks 副本一致（漂移 0）` | **0** |

> `npx bats test/` 计数直跑（非装饰截断）：`grep -c '^ok '` = 973、`grep -c 'not ok'` = 0、真实 `skip` 状态行 = 0（输出中 "skip" 字样均为测试名，如 `ok 11 L2_verdict=skipped` 属 `ok` 行）。

## 4 判别力与反例（fake-`make` harness）

夹具（`$(mktemp -d)`，用完即删，不改仓库；用真实 `$HOME`，仅伪 `make` 经 **PATH 前缀**生效，子 shell 内注入 `FKMODE`）：

```
=== [1] BLOCKING CASE: fake make fails check-path-privacy (FKMODE=fail) ===
[stderr]
make test (fake): PASS
make check-path-privacy (fake): FAIL
[archive-commit-gate] path-privacy check failed, commit rejected
[1] BLOCKING rc=1

=== [2] CONTROL CASE: fake make always passes (FKMODE=pass) ===
[stderr]
make test (fake): PASS
make check-path-privacy (fake): PASS
[2] CONTROL rc=0

=== [3] PRE-T20 CONTRAST: old hook (only make test) with failing privacy gate ===
[stderr]
make test (fake): PASS
[3] PRE-T20 rc=0（隐私门禁被忽略，commit 会放行）
```

- 反例关键：pre-T20 钩子只跑 `make test`，隐私门禁失败时 rc=0 ⇒ 泄漏会随 commit 入库；加上新段后同一失败态 hook rc=1 并打印阻塞报文。**grep 判据只证存在，本夹具证其有牙。**
- 伪 `make` 为独立脚本：`test` 恒 0、`check-path-privacy` 依 `FKMODE`（`fail`→1 / 其它→0）；`make test` PASS 前置（避免夹具因 test 红而误判）。

## 5 6 维自查

- **正确性**：`check-path-privacy` 段镜像既有 `make test` 快失败惯用法（`if ! make ...; then echo ... >&2; exit 1; fi`），无 `|| true`、无回退放过红门；快速跳过路径（无 Makefile / 无 npx）行为与既有段一致 ✅
- **完整性**：判据验证的三件事全落地（源内 grep / `bash -n` / 镜像漂移 0）；判别力夹具三态全过 ✅
- **回归**：门禁 + 历史判据 v_T17/18/20/21/22/23/25 全 rc=0；973 pass / 0 not ok ✅（L-139②：改镜像钩子不破坏任何先前判据）
- **可维护性**：接线按既有块风格复制，注释说明 gate 归属（health-fix-2026-09b AC-6 ③）；行内无魔法值；`sha256` 与行数已记 ✅
- **安全与隐私**：不引入任何实义本机绝对路径字面量；SUMMARY 内 `<repo>` / `$HOME` / `/home/<acct>/` de-shape；自扫 `/home/[a-z_][a-z0-9_-]*/` 无命中 ✅
- **文档一致性**：`REQUIREMENT.md` AC-6 ③ + `TASK.md` T20 判据（仓库内源断言）与本实现逐字一致；L2 C2（不断言 symlink）遵守 ✅

## 6 遗留

- 无遗留。`make test` 与 `make check-path-privacy` 均绿；提交已由新门禁自验。
- 本 SUMMARY 无中途断点，不设 PROGRESS.md。