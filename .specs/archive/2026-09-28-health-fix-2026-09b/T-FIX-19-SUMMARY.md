# T-FIX-19 SUMMARY（R5-9 🟡）

> AC-1 载荷注入与 6 副本判据常设化（现有覆盖为一次性探针）
> 执行轮次：第 5 轮 fix loop · commit `40b909a` · `completed_at` `2026-09-28T05:05:42+08:00`

## 一、问题锚点

- **R5-9 🟡**：AC-1 核心判据（载荷不被执行 · 6 副本 + 归档归零）此前只有 change 期一次性探针覆盖（`.specs/health-fix-2026-09b/` 下的探针脚本）。归档后若守卫被改回 `eval` 求值形态，既有 9 例常设网全绿但 `$(touch 哨兵)` 载荷会被执行——现有常设网对载荷回归零判别力。
- **判别力在哨兵断言而非 `$status`**（主 agent 实测订正，见 TASK.md `<verify>①` 参照 `/tmp/p6d/tfix19-main/probe2.sh`）：三形态下新旧守卫对照——
  - (a) 运行面内载荷 `~/.claude/hooks/<载荷>/x.sh`（派生维护源不存在）：现实现 `rc=0 + 哨兵不存在` / 基线 eval `rc=0 + 哨兵存在`
  - (b) 同 (a) + 字面建出维护源：现实现 `rc=2 + 哨兵不存在` / 基线 eval `rc=0 + 哨兵存在`
  - (c) 运行面外载荷 `/tmp/<载荷>/x`：现实现 `rc=0 + 哨兵不存在` / 基线 eval `rc=0 + 哨兵存在`
  - 仅断 `$status` 无法区分 (a)/(c) 的新旧实现（两者 rc 都是 0），哨兵文件存在性是唯一判别量。

## 二、修复实施

### 2.1 先红探针（判据①）

一次性探针 `/tmp/tfix19/pre.sh`（不进仓库）：用 `payload()` 函数三段拼接构造 `$(touch <哨兵>)` 形态载荷（L-137：源件不出现可直接运行的整串），喂给现实现守卫 vs 基线 eval 形态守卫，输出三形态对照表。

结果：现实现 (a)(b)(c) 哨兵全 absent；基线 eval (a)(b)(c) 哨兵全 PRESENT。证明现有 9 例常设网对载荷回归零判别力。与主 agent 实测 `/tmp/p6d/tfix19-main/probe2.sh` 一致。

### 2.2 常设腿（判据②，+6 例共 15 例）

追加进 `test/test_runtime_edit_guard.bats`（9 原有 + 6 新）：

- **腿 10 (a)**：运行面内载荷（派生维护源不存在）⇒ `$status -eq 0` + 哨兵文件不存在 + 报文不含 `⛔`
- **腿 11 (b)**：运行面内载荷 + 字面建维护源（目录名 = 载荷串）⇒ `$status -eq 2` + 哨兵不存在 + 报文含 `⛔`
- **腿 12 (c)**：运行面外载荷 `/tmp/...` ⇒ `$status -eq 0` + 哨兵不存在
- **腿 13 副本面**：6 个部署副本（`sync-hooks.sh` 的 `DEST_ROOTS`）逐件 `cmp -s` 与源件一致 + `grep -acE` eval 形态静态计数 = 0
- **腿 14 dist 归档面**：`tar xzOf dist/dsh-flow-kit-0.2.0.tgz | grep -acE PAT` = 0
- **腿 15 产品侧变异腿**：setup `mut_guard()` 把守卫副本的 `case` 路径解析块还原为基线 `eval` 形态（`real_path=$(eval echo "$file_path" 2>/dev/null) || real_path="$file_path"`，对应 `534e3e8` 版第 46 行），用 bash `while-read` 拼接构造（源件不出现可运行整串）⇒ 腿 10-12 转红（哨兵被创建）⇒ `not ok` 成立；还原现实现即转绿

### 2.3 载荷拼接构造（L-137）

`payload()` 函数三段拼成：`$(` + `eval` + ` touch "$SENTINEL")`。哨兵落夹具 `$HOME_DIR/sentinel`（mktemp -d 派生），绝不碰真实家目录。测试源件内不出现可直接运行的整串 `$(eval touch ...)`。

### 2.4 注释污染修复

dist 重建后发现 tarball 内 `eval-echo` 计数 = 1，定位为 `test/test_runtime_edit_guard.bats:65` 注释里的 `$(eval` 字面串被打进 dist 归档面触发 AC-1 grep。修复：注释 `$(eval` → `dollar-paren-eval` 字面描述。重 `make test-sync` + 重建 dist + `check-dist` ✅ + tarball `eval-echo=0`。

**教训**：测试源件注释里的 `$(eval` 字面会打进 dist 归档面触发 AC-1 grep。AC-1 PAT（`\$\([[:space:]]*eval[[:space:]]`）只匹配 `$(eval` 不匹配 `$(touch`，但 `$(eval` 字面在注释里也必须避免。

## 三、判据④ make check 事实链

### 3.1 诊断过程（NFR 假红）

首次 `make check` 失败在 `check-nfr-portability`：`.specs/health-fix-2026-09b/reproduce-5-fixloop.sh:138-139` 的 `mapfile|readarray` 字面（作为 grep pattern 字符串，非真用 mapfile）被 NFR BAN pattern 命中。该文件是主 agent 的第 5 阶段判据脚本（未跟踪 → 后提交 `61d484a`），**不属于本任务写面**。

隔离验证：临时移走该文件后 `make check-nfr-portability-internals` EXIT=0 ✅，本写面 NFR 完全干净。此为**诊断过程**而非最终态。

### 3.2 最终态（主 agent 修复后）

主 agent 确认诊断并修复：`44f3693` 把 `reproduce-5-fixloop.sh:138-139` 的 `mapfile|readarray` 改为 `map[f]ile|readarr[a]y`（对 `grep -E` 语义等价），消除 NFR 对自身新增 .sh 的假红。

最终态 `make check` 实跑（HEAD=`44f3693`，5 min 超时）：

```
✅ make check: 全部通过
```

21 ✅ / 0 ❌（rc=0）。

## 四、验证留档

### 判据① 先红留档

`bash /tmp/tfix19/pre.sh`（一次性探针，不进仓库）三形态对照表：现实现 (a)(b)(c) 哨兵全 absent；基线 eval 形态（`git show 534e3e8…`）(a)(b)(c) 哨兵全 PRESENT。与主 agent 实测 `/tmp/p6d/tfix19-main/probe2.sh` 一致。

### 判据② bats 15/15 全绿

```
1..15
ok 1  ... ok 9  （原有）
ok 10 T-FIX-19 (a) 运行面内载荷（派生维护源不存在）⇒ exit 0 + 哨兵不存在
ok 11 T-FIX-19 (b) 运行面内载荷 + 字面建维护源 ⇒ exit 2 + 哨兵不存在 + 报文含 ⛔
ok 12 T-FIX-19 (c) 运行面外载荷 ⇒ exit 0 + 哨兵不存在
ok 13 T-FIX-19 副本面：6 个部署副本 cmp -s 源件 + eval 形态静态计数 = 0
ok 14 T-FIX-19 dist 归档面：tarball 内 eval 形态计数 = 0
ok 15 T-FIX-19 产品侧变异腿：还原基线 eval 形态 ⇒ 哨兵被创建（not ok）
```

### 判据③ 产品侧变异腿

setup `mut_guard()` 把守卫副本 `case` 路径解析块还原为基线 `eval` 形态（`534e3e8` 版第 46 行 `real_path=$(eval echo "$file_path" 2>/dev/null) || real_path="$file_path"`）⇒ 腿 10-12 转红（载荷被执行、哨兵被创建）；还原现实现即转绿。腿 15 断言此变异态 `not ok`。

### 判据④ make check 21 ✅ / 0 ❌

```
✅ make check: 全部通过
```

### 6 副本 + dist 归档面

PAT = `\$\([[:space:]]*eval[[:space:]]`

| 副本路径 | grep -acE PAT |
|---|---|
| `flow-kit-bundle/hooks/pre-tool-use/runtime-edit-guard.sh`（源） | 0 |
| `~/.claude/hooks/pre-tool-use/runtime-edit-guard.sh` | 0 |
| `dist/dsh-flow-kit/hooks/pre-tool-use/runtime-edit-guard.sh` | 0 |
| `dist/dsh-flow-kit/vendor/flow-kit-bundle/hooks/pre-tool-use/runtime-edit-guard.sh` | 0 |
| `~/.dsh/profiles/web/node_modules/dsh-flow-kit/hooks/pre-tool-use/runtime-edit-guard.sh` | 0 |
| `~/.dsh/profiles/web/node_modules/dsh-flow-kit/vendor/flow-kit-bundle/hooks/pre-tool-use/runtime-edit-guard.sh` | 0 |
| `~/.config/opencode/hooks/pre-tool-use/runtime-edit-guard.sh` | 0 |
| `dist/dsh-flow-kit-0.2.0.tgz`（tarball） | 0 |

## 五、提交

- commit `40b909a8ca7f02c9b886447e5a187934b6acec84`
- `%cI` = `2026-09-28T05:05:42+08:00`
- `--numstat`：
  ```
  138	0	flow-kit-bundle/test/test_runtime_edit_guard.bats
  138	0	test/test_runtime_edit_guard.bats
  ```
- 2 files changed, 276 insertions(+)

## 六、写面清单

- `test/test_runtime_edit_guard.bats`（追加 6 腿 + setup 扩展）
- `flow-kit-bundle/test/test_runtime_edit_guard.bats`（`make test-sync` 镜像）
- `T-FIX-19-SUMMARY.md`（本件）
- `.specs/health-fix-2026-09b/TASK.md`（`status="done"` + `<done>`）

## 七、遗留风险

- **无**。判据①②③④全满足。判据④ make check 的 NFR 假红已由主 agent 修复（`44f3693`），最终态全绿。
- 本任务未触碰任何非写面文件（主 agent 纪律通知已确认）。
