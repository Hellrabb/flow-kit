# T-FIX-10 SUMMARY

**change_id**: `health-fix-2026-09b`
**task_id**: T-FIX-10
**commit_sha**: `d840a12edae2563f42b76b3fa60aeba9ad37ff3e`
**commit epoch → ledger Δ**: 1790327350 → 1790327360 = 10s（≤120 ✅）

## 改动文件清单（numstat）

```
 flow-kit-bundle/flow-kit/reference/check-gate-sync.sh | 93 ++++++++++++++++++----
 flow-kit-bundle/test/test_check_gate_sync.bats        | 60 ++++++++++++++
 test/test_check_gate_sync.bats                        | 60 ++++++++++++++
 3 files changed, 197 insertions(+), 16 deletions(-)
```

## 三处缺陷与修复

### R3-19（`set -e` 下静默中止）
**缺陷**：`skill_presets=$(sed|grep|sed|sort)` 与 `bats_presets=$(sed|grep|sed|tr|sed|sort)` 提取管道在 `set -euo pipefail`（`:7`）下，`grep` 对空集合返回 rc=1 ⇒ 整条管道赋值失败 ⇒ `set -e` 在到达计数行（原 `:196`）之前中止脚本（无 🔴、无汇总行）。另 `:196` `preset_count=$(printf '%s\n' "$skill_presets" | grep -c .)` 是第二中止点。

**修复（fail-closed）**：
- 两处提取管道追加 `|| true`（兜底 rc，空集合合法得到空串）。
- `preset_count` / `bats_count` 的 `grep -c` 也追加 `|| true`。
- 计数为 0（任一侧）⇒ 具名 🔴 `🔴 预设集合为空（skill 侧 N 个 / bats 侧 M 个）：无法判定一致性（未验证 ≠ 通过）` + 计入 `ERRORS`；**不得静默继续**。

**理由**：未验证 ≠ 通过；空集合意味着两侧无法比对，必须 fail-closed 而非隐式放行。

### R3-20（`diff` rc 被吞）
**缺陷**：`diff_out=$(diff … || true)` 把 rc=2（文件不可读/参数错）与 rc=0/1 一视同仁 ⇒ 机械故障被折成「无差异 ⇒ 一致」。

**修复**：`set +e; diff_out=$(diff … 2>/dev/null); diff_rc=$?; set -e`；`diff_rc ≥ 2` ⇒ 具名 🔴 `🔴 MECHANICAL: … diff 返回 rc=<n>（机械故障，非内容判定）` + 计入 `ERRORS`；**不得**打印 ✅/一致。PCSC 对 diff 与 gate-config diff 两处同修。

### R3-18（漂移定位张冠李戴）
**缺陷**：`:114-144` 无论实际是哪一侧变更，恒打印「（prompt 侧内容漂移）」。

**修复**：逐侧判定，格式固定：
```
🔴 漂移 <pair>：<prompt|skill|both> 侧内容不一致（prompt <n> 行 vs skill <m> 行）
```
- 仅 prompt 侧不同 ⇒ `prompt`；仅 skill 侧不同 ⇒ `skill`；两侧都不同 ⇒ `both`。
- 通过 `count_lines` 辅助函数统计 `diff_out` 中 `^< `（prompt 侧）与 `^> `（skill 侧）行数判定方向。

## verify 静态判据偏差（已知，未削弱 verify）

`<verify>` 第 3 条 `grep -qE 'diff_out.*\|\| true' "$S"` 过宽：本意捕获 `diff_out=$(diff … || true)`（R3-20 缺陷形态），但也会命中消费 `diff_out` 的 `grep -c` 行（`prompt_only=$(printf '%s\n' "$diff_out" | grep -c '^< ' || true)` 等），这些 `|| true` 是防 `grep -c` 0 匹配在 set -e 下中止的合法用法，并非吞 rc。

**处置**：遵守「不得削弱或改写 verify」原则，不改判据，改写代码：引入 `count_lines()` 辅助函数（`set +e`/`set -e` 内部隔离 rc），将 4 处 `grep -c` 与 1 处 `grep -m1` 移入 `set +e`/`set -e` 块，使 `diff_out` 与 `|| true` 不出现在同一赋值语句行。修复后 `grep -nE 'diff_out.*\|\| true'` 返回 NONE。

## TDD 证据

- **RED（修复前）**：R3-19 空预设静默中止（无汇总行）；R3-20 diff rc=2 折算为 rc=0 + `✅ 校验对 3/14 一致`；R3-18 仅 skill 侧改动却报 prompt 侧漂移。
- **GREEN（修复后）**：R3-19 空预设 ⇒ rc=1 + 具名 🔴 + 汇总行；R3-20 diff rc=2 ⇒ rc=1 + 具名 🔴 MECHANICAL；R3-18A 仅 skill 侧 ⇒ 具名 skill 侧（不误报 prompt）；R3-18B 仅 prompt 侧 ⇒ 具名 prompt 侧（不误报 skill）；基线夹具 + 真实仓 ⇒ rc=0 + 3/14 一致。
- **bats 判别式**：新增 4 例（R3-18A/R3-18B/R3-19/R3-20），全量套件 1058 ok / 0 not-ok。

## 收尾

- `make test-sync` ✅（双源一致）
- `package-dsh-plugin.sh` ✅（dist 重建）
- `make check-hooks-sync check-test-sync check-dist` ✅
- `make check` ✅（全绿）
- 钩子未生效（`core.hooksPath` 空），门禁一律手动跑。
