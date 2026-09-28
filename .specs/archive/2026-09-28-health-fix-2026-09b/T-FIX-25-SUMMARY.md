# T-FIX-25-SUMMARY · check-gate-sync diff 机械故障判别力常设化（TD-104 · L3 第 20/21 轮 major②）

> 收口 `TD-104`：把 `check-gate-sync.sh` 对 `diff` 机械故障（rc≥2）的判别力从「change 期静态 grep」升级为**常设网里的行为级 bats 用例**。
> 生产件本轮已修好（`diff_rc=$?` 显式捕获 + `rc≥2` 机械故障分支），缺的只是常设网。
> 既有 `T-FIX-10 R3-20` 腿断言较松（`rc≠0 + 含泛化 🔴`），本任务新增 +1 例更严的行为级腿。

## 写面

| 路径 | 变更 |
|---|---|
| `test/test_check_gate_sync.bats` | +1 例（T-FIX-25 TD-104 行为级腿，15→16）+ `FXB25` 独立夹具生成器 |
| `flow-kit-bundle/test/test_check_gate_sync.bats` | 镜像（`make test-sync` 生成，逐字相同） |
| `.specs/health-fix-2026-09b/T-FIX-25-SUMMARY.md` | 本文件 |
| `.specs/health-fix-2026-09b/TASK.md` | T-FIX-25 `status="done"` + `<done>` 注记 |

**未改**：`check-gate-sync.sh`（生产件本轮已修好）、其它任务判据、`.specs/**/reproduce-*.sh`。

## 新腿设计（`test/test_check_gate_sync.bats`）

```
@test "T-FIX-25 TD-104: PATH 影子 diff（恒 rc=2）→ rc≠0 + 具名 🔴 MECHANICAL + 不打印 ✅ 一致"
```

- **夹具**：`FXB25`（与 `FXB10` 同款构造：mktemp -d + 3 对 PCSC 载体 + `skills/flow/SKILL.md` + `test/test_gate_config_presets.bats`，独立避免与既有腿耦合）。
- **影子命令**：`$SBX/fk/shadows/diff`（`#!/bin/sh` + `exit 2`），以 `PATH="$SBX/fk/shadows:$PATH"` 运行 SUT。
- **前置自检**：`{ PATH=… command diff a b; } || shadow_rc=$?`；断言 `shadow_rc -eq 2`（确切值，L-173）。前置不成立 ⇒ 用例 `not ok`（不静默空转）。bats test body 在 `run` 之外 `set -e` 生效 ⇒ 用 `{ …; } || true` 包裹取 rc，不触发中止。
- **断言三条**：① `[ "$status" -ne 0 ]`（rc≠0）；② `[[ "$output" == *"🔴 MECHANICAL"* ]]`（具名 🔴 MECHANICAL，非泛化 🔴）；③ `[[ "$output" != *"✅"*"一致"* ]]`（不得打印 ✅ 一致 放行行）。

## 先红留档 + 变异反向控制（`<verify>` ①）

### 先红留档（真实仓 + 影子 diff rc=2）

```
前置自检：shadow-diff rc=2  ✅
真实仓 SUT 运行：rc=1（非 0）
输出含：🔴 MECHANICAL: diff 返回 rc=2（机械故障…）  ×4 处
输出含：🔴 MECHANICAL: gate-config diff 返回 rc=2…  ×1 处
输出含：🔴 发现 4 处问题…
无 ✅ 一致 行  ✅（符合预期：生产件已修好，缺的只是常设网）
```

### 变异反向控制（SUT 副本两处 `diff_rc=$?` → `|| true` 形态）

用 `python3` 精确替换 `/tmp/tfix25/cgs_mutated.sh` 两处：
- L117: `diff_out=$(diff "$tmp_p" "$tmp_s" 2>/dev/null); diff_rc=$?` → `diff_out=$(diff "$tmp_p" "$tmp_s" 2>/dev/null || true)`
- L241: `diff_out=$(diff <(printf …) <(printf …) 2>/dev/null); diff_rc=$?` → `diff_out=$(diff <(printf …) <(printf …) 2>/dev/null || true)`

变异后 `bash -n` 语法 OK。变异腿运行（影子 diff rc=2 + 缺陷形态 SUT）：

```
变异腿 rc=1
输出：flow-kit-bundle/flow-kit/reference/check-gate-sync.sh: 行 119: diff_rc: 未绑定的变量
无 🔴 MECHANICAL（rc=2 被 || true 吞掉）
无 ✅ 一致（set -u 下 diff_rc 未绑定即崩）
```

**bats 跑新腿断言（变异件）⇒ `not ok`**，失败在 `[[ "$output" == *"🔴 MECHANICAL"* ]]`：

```
not ok 1 变异腿: 变异 SUT(|| true) + 影子 diff(rc=2) ⇒ 新腿断言必须 not ok
#   `[[ "$output" == *"🔴 MECHANICAL"* ]]' failed
```

⇒ **新腿对 TD-104 所述缺陷形态有判别力**：缺陷形态（`|| true` 吞 rc）⇒ 不打印 🔴 MECHANICAL ⇒ 新腿 `not ok`；修复形态（`diff_rc=$?` + `rc≥2` 分支）⇒ 打印 🔴 MECHANICAL ⇒ 新腿 `ok`。

### 真件 sha256 前后一致

```
before: 36565810ed7f711c99f7af45d383c3a57d4efc44b67d3e9f1e4c87eeb3cc326e
after:  36565810ed7f711c99f7af45d383c3a57d4efc44b67d3e9f1e4c87eeb3cc326e
✅ 真件 sha256 前后一致（未触碰生产件）
```

## 复跑面（`<verify>` ②–⑤）

| # | 命令 | rc | 关键输出 |
|---|---|---|---|
| ② | `npx bats test/test_check_gate_sync.bats` | 0 | 16 ok / 0 not ok |
| ② | `cmp -s test/test_check_gate_sync.bats flow-kit-bundle/test/test_check_gate_sync.bats` | 0 | 两镜像相同 |
| ③ | `bash /tmp/tfix25/v_TFIX10-fixed.sh`（订正后 T-FIX-10 `<verify>` 现取实跑） | 0 | 真实仓 rc=0 · 基线夹具 rc=0 · diff rc=2 面 rc=1 · bats 1116 ok / 0 not-ok / count=1116 |
| ④ | `npx bats --count test/` | — | 1116 |
| ④ | `npx bats test/`（全量） | 0 | 1116 ok / 0 not ok |
| ⑤ | `make check` | 0 | 21 ✅ / 0 ❌ |

## 收尾顺序

`make test-sync`（✅ test 双源已同步）→ `package-dsh-plugin.sh`（✅ v0.2.0 · 6.0M）→ `make check-hooks-sync`（✅ 漂移 0）· `make check-test-sync`（✅ 双源一致）· `make check-dist`（✅ dist 与源一致）→ `make check`（21 ✅ / 0 ❌）。

## commit

- `380679b` · `2026-09-28T18:30:10+08:00` · `test(health-fix-2026-09b): T-FIX-25 check-gate-sync diff 机械故障判别力常设化（TD-104 · L3 第 20/21 轮 major②）`
- numstat: `41 0 flow-kit-bundle/test/test_check_gate_sync.bats` · `41 0 test/test_check_gate_sync.bats`（2 files, 82 insertions）

## 遗留风险

- 无。本任务无 deferred 项；`deferred=[]`。新腿与既有 `T-FIX-10 R3-20` 腿并存（后者断言较松仍保留，不冲突；新腿是更严的超集判据）。
- bash 3.2 兼容：新腿仅用 `mktemp -d` / `printf` / `chmod` / `command diff` / `[ ]` / `[[ ]]` / `run` / `||` —— 无 `declare -A`/`mapfile`/`realpath`/`grep -P`/GNU `sed -i`。NFR 门禁 `make check-nfr-portability` 通过。
