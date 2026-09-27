# T-FIX-20 执行回执（第 5 轮 fix loop · 2026-09-28）

## 任务

**T-FIX-20** · `R5-26` 🟡 + `R5-12` 🟢 · AC-7 删除注入封闭（去 `$HOME` 回落）+ combined metric 驱动真实路径。

## 提交

- **sha**：`75526996a6108815a7fc71882baaa53bf848310a`
- **%cI**：`2026-09-28T05:54:21+08:00`
- **写面**（`git show --numstat`）：

```
 test/test_combined_metric.bats                       | 50 ++++++++----
 test/test_independent_review_model.bats              | 95 +++++++++++++++-------
 flow-kit-bundle/test/test_combined_metric.bats       | 50 ++++++++----
 flow-kit-bundle/test/test_independent_review_model.bats | 95 +++++++++++++++-------
 4 files changed, 202 insertions(+), 88 deletions(-)
```

## verify 逐条实跑

### ① 先红留档（`bash /tmp/tfix20/pre.sh`）

- 命令：删 `flow-kit-bundle/hooks/stop/29-independent-review.sh` 后跑现版（pre-fix）`npx bats test/test_independent_review_model.bats`。
- rc=0 · **12 例全绿**（缺陷确认：`setup()` 的 `:18` 回落到 `$HOME/.claude/hooks/stop/29-independent-review.sh`，被已安装副本顶替通过）。
- 输出存档 `/tmp/tfix20/pre.txt`（尾行 `bats rc=0` + `RESTORED-OK`）。

### ② 两件 bats 全绿（post-fix）

- `npx bats test/test_independent_review_model.bats` ⇒ **13 例全绿** rc=0（12 原例 + 1 新增 AC-7 删除注入腿）。
- `npx bats test/test_combined_metric.bats` ⇒ **3 例全绿** rc=0（原 INT-COMBINED-1 + cleanup 改真实路径 + 新增注入腿）。

### ③ 删除注入双态（`bash /tmp/tfix20/inject.sh`）

- **leg 1**（删 bundle 29 源件 → 跑 bats）：rc=1 · **not ok 13 例**（setup fail-fast 命中，全转红）。
- **leg 2**（cp 回来 + cmp -s 校验 → 跑 bats）：rc=0 · not ok 0 例（全绿复原）。
- `INJECT-VERDICT: PASS`（输出存档 `/tmp/tfix20/inject.txt`）。

### ④ 封闭性（源树面）

```
$ grep -cE 'HOME/\.claude/hooks/stop' test/test_independent_review_model.bats
0
```
14 处直接引用全部改为仓库源树路径（`FK_SRC_29`/`FK_SRC_30`/`FK_L3_REVIEW`/`FK_L3_API`，由 setup 向上查找 `$d/flow-kit-bundle/hooks/stop/…`）。

### ⑤ 封闭性（环境面残留）

```
$ grep -nE 'HOME/\.claude' test/test_independent_review_model.bats
12:  # 禁止 $HOME/.claude/hooks 安装副本回落（R5-26 · ADR-014 spot-check F3）：
175:  if [ ! -f "$HOME/.claude/stop-hook.json" ]; then
176:    skip "环境面残留：$HOME/.claude/stop-hook.json 不存在（已安装态未部署）"
181:  model_val=$(jq -r '.ai.model' "$HOME/.claude/stop-hook.json")
```
剩余命中仅为 `stop-hook.json` 用例（`:175`/`:176`/`:181`）+ 叙述注释（`:12`）。该用例在文件缺失时显式 `skip`：

- **leg A**（文件存在态）：`npx bats -f 'stop-hook.json still has plain model string' …` ⇒ `ok 1` rc=0（实跑断言）。
- **leg B**（临时改名态）：同命令 ⇒ `ok 1 # skip 环境面残留：$HOME/.claude/stop-hook.json 不存在（已安装态未部署）` rc=0。

### ⑥ `make check`

- `make check` ⇒ **21 ✅ / 0 ❌** rc=0（`✅ make check: 全部通过`）。
- 前置链：`make test-sync` rc=0 · `make check-hooks-sync` rc=0（漂移 0）· `make check-test-sync` rc=0（双源一致）· `bash package-dsh-plugin.sh` 重建 dist rc=0 · `make check-dist` rc=0（dist 与源一致）。

## 台账（ADR-015）

`.flow-active` → `goal.task_progress` 末尾 append（写后 python 断言 `tp[-1]['id']=='T-FIX-20' and '.goal' not in d` 通过）：

```json
{"id":"T-FIX-20","commit_sha":"75526996a6108815a7fc71882baaa53bf848310a","fix_rounds":1,"deferred":[],"completed_at":"2026-09-28T05:54:33+08:00"}
```

- `completed_at` = `2026-09-28T05:54:33+08:00`；提交 `%cI` = `2026-09-28T05:54:21+08:00` ⇒ **Δ = 12 s**（≤ 120 s）。
- 顶层 `updated_at` 未改（epoch 整数 `1790544966` 保持）。

## 开工 / 收工 `git status --porcelain`

- **开工**：空（`a5e91c5` HEAD）。
- **收工**：空（提交后工作树干净，`7552699` HEAD）。

## 写面清单

- `test/test_independent_review_model.bats`（去 `$HOME` 回落 + 14 处改仓库源树 + setup fail-fast + AC-7 删除注入腿 + stop-hook.json 显式 skip）
- `test/test_combined_metric.bats`（cleanup 改真实 SUT 路径 + 注入腿 + 文件尾换行）
- `flow-kit-bundle/test/test_independent_review_model.bats`（`make test-sync` 镜像）
- `flow-kit-bundle/test/test_combined_metric.bats`（`make test-sync` 镜像）
- `.specs/health-fix-2026-09b/T-FIX-20-SUMMARY.md`（本件）
- `.specs/health-fix-2026-09b/TASK.md`（`status="done"` + `<done>`）

## 遗留风险

- `test/test_independent_review_model.bats:167`（AC-7 删除注入腿）：通过 `run bash -c` 在子壳内重放 setup 的向上查找 + fail-fast 逻辑，而非直接调用 setup 函数。若未来 setup 的查找逻辑变更而本腿未同步，该腿可能漂移为「重放逻辑」与「真实 setup」分叉。缓解：本腿与 setup 的查找循环逐字一致（同 `$d/flow-kit-bundle/hooks/stop/29-independent-review.sh` 判定），且 grep 口径 `HOME/\.claude/hooks/stop` = 0 已锁死回落路径。
- `test/test_combined_metric.bats:62`（INT-COMBINED-1-cleanup-injection 注入腿）：断言 `[ "$status" -eq 0 ]`（扫描命中残留）以证明判据有判定力，其「红」语义体现在正常 cleanup 用例（`:48` 的 `[ "$status" -ne 0 ]`）在注入态会失败。两腿分别独立断言，未在同一用例内做「注入 ⇒ 该用例自身红」的直接互证；若读者期望单腿自红形态，可后续重构为夹具驱动的变异腿。当前形态满足 AC-7「注入残留文件 ⇒ 红」的判据要求（REQUIREMENT.md:411 / TEST.md:60）。
- stop-hook.json 用例（`:175-182`）依赖 `$HOME/.claude/stop-hook.json` 已安装态；在无该文件的 CI/异机环境将统一 `skip`，不构成阻塞但不提供正向覆盖。
