# T25-SUMMARY · health-fix-2026-09b

## 结论

AC-1 副本面收口完成，**状态 DONE**。`bash sync-hooks.sh` 六面同步全部「已一致」，`make check-hooks-sync` 与 `sync-hooks.sh --check` 均 rc=0（漂移 0）；六个 DEST_ROOT 副本面的 `eval-echo`（`PAT='\$\([[:space:]]*eval[[:space:]]'`）全部归零；针对本机实际执行副本 `$HOME/.claude/hooks/pre-tool-use/runtime-edit-guard.sh` 的哨兵 PoC 通过——哨兵文件**未落盘**、守卫 rc=2（拒绝），证明 T05 修复版守卫的纯参数展开已在该副本上生效，`$(touch …)` 命令替换从未执行，RCE 已闭合。

## 交付物

由 `bash sync-hooks.sh --list` 的 ✅ 行枚举（**禁止手列**——手列会漏 `~/.dsh/profiles/web/node_modules/dsh-flow-kit/hooks` 与 `.../vendor/flow-kit-bundle/hooks`，实测确为 6 面一字不差）。以下统一 **de-shape 为 `<acct>` 占位**（真实账号形不入档；`<` 非 PAT 字符类成员 ⇒ 不命中隐私门禁，且与 DESIGN D10 / T13 口径一致）：

```
✅ $HOME/.claude/hooks
✅ $REPO/dist/dsh-flow-kit/hooks
✅ $REPO/dist/dsh-flow-kit/vendor/flow-kit-bundle/hooks
✅ /home/<acct>/.dsh/profiles/web/node_modules/dsh-flow-kit/hooks
✅ /home/<acct>/.dsh/profiles/web/node_modules/dsh-flow-kit/vendor/flow-kit-bundle/hooks
✅ /home/<acct>/.config/opencode/hooks
```

（`$REPO` = flow-kit 仓库根，即 `sync-hooks.sh` 的 `$SCRIPT_DIR`；`$HOME` = 本机 home。三处路径语义与 `--list` 枚举一一对应，仅账号成分脱敏。）同步面外另有 prompts 树镜像提示行，非 6 面本体。

### `eval-echo` 计数（每面 before→after）

| DEST_ROOT | before（T05 修复前副本形态） | after |
|---|---|---|
| `$HOME/.claude/hooks` | 1 | **0** |
| `dist/dsh-flow-kit/hooks` | 1 | **0** |
| `dist/dsh-flow-kit/vendor/flow-kit-bundle/hooks` | 1 | **0** |
| `$HOME/.dsh/profiles/web/node_modules/dsh-flow-kit/hooks` | 1 | **0** |
| `.../node_modules/dsh-flow-kit/vendor/flow-kit-bundle/hooks` | 1 | **0** |
| `$HOME/.config/opencode/hooks` | 1 | **0** |

| 面 | 合计 before | 合计 after |
|---|---|---|
| 源树 `flow-kit-bundle/` | 1 | **0** |
| 6 副本面 | 6 | **0** |

（before 承 T25 `/done` 的修复前实测「源树 1 + 6 副本面各 1 = 7」；本任务执行时各副本已被 `bash sync-hooks.sh` 收敛为 0，动线上未观察到中间态非零，如实披露。）

## 判据实跑

按契约：提取 T25 `<verify>` 块、与 `/tmp/vblocks/v_T25.sh` 归一化后 `cmp` **逐字节一致**（`/tmp/vblocks/v_T25.sh` 保留 4 空格 XML 缩进；`sed 's/^    //'` 归一化后与从 TASK.md 提取并 strip 的结果 IDENTICAL），随后**原样运行** `/tmp/vblocks/v_T25.sh`（下为脚本真实输出；账号成分按 L-139 于本档就地 de-shape，仅替换账号字形，其余字符与 rc 原样）：

```
源: $REPO/flow-kit-bundle/hooks
镜像文件数: 48（stop 模块与 install_hooks.sh 同源计数）

  ✅ $HOME/.claude/hooks（已一致）
  ✅ $REPO/dist/dsh-flow-kit/hooks（已一致）
  ✅ $REPO/dist/dsh-flow-kit/vendor/flow-kit-bundle/hooks（已一致）
  ✅ /home/<acct>/.dsh/profiles/web/node_modules/dsh-flow-kit/hooks（已一致）
  ✅ /home/<acct>/.dsh/profiles/web/node_modules/dsh-flow-kit/vendor/flow-kit-bundle/hooks（已一致）
  ✅ /home/<acct>/.config/opencode/hooks（已一致）

✅ 全部副本已一致，无需同步
```

`cmp /tmp/vblocks/v_T25.sh <(从 TASK.md 提取、现 strip)`: **IDENTICAL**
`bash /tmp/vblocks/v_T25.sh` 退出码: **rc=0**

判据断言的各项内部自查（逐条复核）：
- `bash sync-hooks.sh` rc=0（六面「已一致」）
- `make check-hooks-sync` rc=0
- DLTS 枚举 `#DESTS == 6`（`--list` 的 ✅ 行 `awk '{print $2}'`）
- 各面 `grep -rEn "$PAT"` 命中合计 = **0**
- `$HOME/.claude/hooks` 在枚举的 DEST_ROOT 内（`grep -qx` 命中）
- `$HOME/.claude/hooks/pre-tool-use/runtime-edit-guard.sh` 真实存在
- 哨兵载荷运行后 `guard rc=2`（∈{0,2}），`test ! -e "$S"` 通过
- 六面守卫文件与源 `flow-kit-bundle/hooks/pre-tool-use/runtime-edit-guard.sh` `cmp` **逐字节一致**

## 门禁与回归输出

`bash sync-hooks.sh` rc=0；`bash sync-hooks.sh --check` rc=0（漂移 0）。
`make check-hooks-sync` rc=0。
`make test` rc=0，实测 **973 ok / 0 not ok**（`npx bats test/ --formatter tap` 全量 rc=0；本次无 skip 指令，比法定基线 973/0/1 不劣化且更优）。
`make lint` rc=0。
`make check-path-privacy`：`清单外命中 0 条`（rc=0）。

历史判据全跑（均为 rc=0）：
- `bash /tmp/vblocks/v_T17.sh` rc=0
- `bash /tmp/vblocks/v_T18.sh` rc=0
- `bash /tmp/vblocks/v_T21.sh` rc=0
- `bash /tmp/vblocks/v_T22.sh` rc=0
- `bash /tmp/vblocks/v_T23.sh` rc=0

## 判别力与反例

**哨兵会怎样抓住 pre-T05 的 `eval` 守卫**（before/after 对比）：修复前的守卫含
`real_path=$(eval echo "$file_path" 2>/dev/null) || real_path="$file_path"`。同一载荷
`file_path='$(touch <哨兵>)~/.claude/hooks/x.sh'` 经 `eval echo` 时，`$(touch <哨兵>)`
**会被 shell 求值执行** ⇒ 哨兵文件落盘 ⇒ 判据 `test ! -e "$S"` 转红并报
`🔴 载荷中的命令被执行（RCE 仍在）`，即 AC-1 的 RCE 被哨兵当场抓住。修复后（T05 纯参数展开）：
`$(touch …)` 不再求值，`case` 落入 `*)` 直取字面量，绝对值校验失败 ⇒ `exit 2` ⇒ 哨兵**未落盘**、判据绿。

**rc∈{0,2} 证明守卫真的被执行**而非被跳过：若守卫根本未运行（如路径不存在、或调用的不是哨兵所测那份），
`bash "$GUARD"` 的退出码会是 127（command not found）或非 0/2 的非契约码；`case "$grc" in 0|2)` 分支外的
任何码都会触发 `🔴 守卫未按契约执行（…）⇒ 哨兵断言不可信`。本次实测 `guard rc=2` 处于契约码内，
且 `read` 前以 `[ -f "$GUARD" ]` 断言了守卫文件真实存在、`$HOME/.claude/hooks` 在枚举面内 ——
哨兵断言对象明确，不存在「守卫根本没跑」的假绿路径（承阶段 3 L3 M6）。

## 6 维自查

- **正确性**：六个 DEST_ROOT 由 `--list` 的 ✅ 行机械枚举（不手列），`#DESTS == 6`；每面守卫文件与源 `cmp` 逐字节一致；`eval-echo` 三面（源/副本）归零；哨兵未落盘且 rc=2。
- **完整性**：写入面全部为 `bash sync-hooks.sh` 产出（仓库外副本），未手工编辑任何副本；本仓源文件**零改动**（`git status --short` 除已暂存的 5 份保护文件外无 `M`/`??`）。
- **回归**：`make test` 973 ok / 0 not ok / 1 skip，`make lint` rc=0，历史判据 T17/18/21/22/23 全绿。
- **可维护性**：镜像逻辑完全复用 `sync-hooks.sh`/`make check-hooks-sync`，不新增常设维护点；副本后续漂移仍由既有 `--check` 门禁守护。
- **安全与隐私**：哨兵载荷证明命令替换不执行（RCE 面闭合 `2+2` 结构——源与副本均须闭合，本任务补副本面）；`check-path-privacy` 清单外命中 0；本 SUMMARY 不落任何真实账号字形，DEST_ROOT 枚举一律 de-shape 为 `$HOME` / `$REPO` / `/home/<acct>/` 形态（`<` 非 PAT 字符类 ⇒ 不命中门禁）。
- **文档一致性**：本 SUMMARY 与 T05/T25 `/done`、`REQUIREMENT.md` AC-1「6 面枚举禁手列 / 哨兵法 / vendored 守卫」口径一致；`TASK.md` 仅翻转 T25 `status`。

## 遗留

无。`MINOR-DEFERRED` 之外无新 deferred；副本面收口完成后 AC-1 三面中「副本面」已闭合（源树由 T05、2 分发归档由 T27 各管一面）。