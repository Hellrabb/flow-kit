# T-FIX-18 SUMMARY（R5-14 🟡 / R5-10 🟡）

> `check-gate-sync` 缺文件 fail-closed + 补 AC-4 判别形态与 `$status` 断言
> 执行轮次：第 5 轮 fix loop · commit `ef6d88a` · `completed_at` `2026-09-28T04:11:48+08:00`

## 一、问题锚点

- **R5-14 🟡（缺件仍报绿）**：`flow-kit-bundle/flow-kit/reference/check-gate-sync.sh:198-201`（修复前）的 `check_gate_config_sync()` 在缺 `skills/flow/SKILL.md` 或 `test/test_gate_config_presets.bats` 时只打印 `⚠️  WARNING: 文件缺失，跳过 gate-config 同步校验`，随后 `:201` **裸 `return`** ⇒ rc=0 且汇总行仍打印 `✅ 校验对 3/14 一致`。主 agent 亲验见 REVIEW.md `R5-14` 段。
- **R5-10 🟡（判别形态未触达 + 弱断言）**：`test/test_check_gate_sync.bats` 的两条漂移用例只 `grep` 报文、**无 `$status` 断言**；且「两侧行数相同、内容不同」的判别形态无用例覆盖。
- **已核实**：`check_pair()` 的判定本就是内容比对（`:117 diff_out=$(diff "$tmp_p" "$tmp_s")`，无行数短路；`:119-124` 已把 rc≥2 当机械故障 fail-closed）。故 AC-4 判别形态的落地重点 = 用测试腿把该形态钉住，而非改判定逻辑。本任务未发现行数短路 ⇒ 不改实现，仅补测试腿。

## 二、修复实施

### 2.1 `check-gate-sync.sh`（fail-closed 缺件路径）

`check_gate_config_sync()` 的缺件分支（原 `:198-201`）从 `⚠️ WARNING + 裸 return` 改为同族 `🔴 MISSING + ERRORS + 具名文件路径`：

```bash
local missing=0
[ ! -f "$skill_file" ] && missing=1
[ ! -f "$bats_file" ] && missing=$((missing + 2))
if [ "$missing" -ne 0 ]; then
  echo "   🔴 MISSING: gate-config 同步无法校验（未比对）"
  [ $((missing & 1)) -ne 0 ] && echo "       skill: $skill_file"
  [ $((missing & 2)) -ne 0 ] && echo "       bats:  $bats_file"
  echo ""
  ERRORS=$((ERRORS + 1))
  return
fi
```

- 措辞与 `check_pair` 的 MISSING 分支（`:65-77`）同族（T-FIX-04 先例），但打印 gate-config 侧自身名号。
- 具名文件路径（不得只含泛化措辞「文件缺失」）：缺失文件的确切路径打印在 `skill:` / `bats:` 行。
- 用位掩码 `missing` 同时判两侧（bash 3.2 兼容，无 `declare -A`）；`local missing=0` 在函数作用域内，不影响 `set -euo pipefail`。

### 2.2 `test/test_check_gate_sync.bats`（补 4 条常设腿）

新增 `FXB18()` 夹具辅助（复用 FXB10 范式：mktemp -d + 真实生产件全量拷贝）与 4 条用例：

1. **R5-14 ①**：删 `test_gate_config_presets.bats` ⇒ `[ "$status" -ne 0 ]` + 输出含 `🔴 MISSING` + 含 `test/test_gate_config_presets.bats` 具名路径 + 不含 `✅ 校验对`。
2. **R5-14 ②**：删 `skills/flow/SKILL.md` ⇒ 同上，具名路径 `skills/flow/SKILL.md`。
3. **R5-10 ③**：仅改一行内容（行数不变）⇒ `[ "$status" -ne 0 ]` + 输出含 `漂移`。前提断言 `wc -l` 前后相等（钉住内容比对，非行数短路）。
4. **R5-14 ④ 反向控制**：完整树 ⇒ `[ "$status" -eq 0 ]` + 含 `✅` + 不含 `🔴 MISSING`。

每例都断言 `$status`（R5-13 同族弱点：不得只 grep 报文）。①/② 前置断言被删文件在副本中确实不存在（前提状态显式断言）。

## 三、先红留档（verify ①）

`bash /tmp/tfix18/pre.sh` 输出（修复前基线）：

```
=== RED-1: missing test_gate_config_presets.bats ===
   ⚠️  WARNING: 文件缺失，跳过 gate-config 同步校验
   ✅ 校验对 3/14 一致（仅覆盖上述 3 对，非全量 14 对全绿）。
rc=0

=== RED-2: missing skills/flow/SKILL.md ===
   ⚠️  WARNING: 文件缺失，跳过 gate-config 同步校验
   ✅ 校验对 3/14 一致（仅覆盖上述 3 对，非全量 14 对全绿）。
rc=0
```

缺陷态证据：缺件 ⇒ rc=0 + `WARNING: 文件缺失` + 仍打印 `✅ 校验对 3/14 一致`（缺件仍报绿）。

## 四、后绿证据（verify ②）

修复后用例全绿（含 4 条新腿）：

```
$ npx bats test/test_check_gate_sync.bats
1..15
ok 1  T02: check-gate-sync.sh 存在且可执行
...
ok 12 T-FIX-18 R5-14 ①: 缺 test_gate_config_presets.bats → rc≠0 + 🔴 MISSING + 具名路径（非 ✅ 一致）
ok 13 T-FIX-18 R5-14 ②: 缺 skills/flow/SKILL.md → rc≠0 + 🔴 MISSING + 具名路径（非 ✅ 一致）
ok 14 T-FIX-18 R5-10 ③: 仅改一行内容（行数不变）→ 判红（内容比对，非行数短路）
ok 15 T-FIX-18 R5-14 ④ 反向控制: 完整树 → rc=0 + ✅（判据有牙，非恒红）
```

- `test/test_check_gate_sync.bats` 用例数：基线 11 → 15（+4）。
- 全量 `npx bats --count test/`：基线 1086 → 1090（+4）。

## 五、变异反向控制（verify ③）

把 `check-gate-sync.sh` 的缺件分支临时还原为 `WARNING + return`（mutant）⇒ 同套 bats 的腿①/②转 `not ok`，腿③/④仍 `ok`：

```
not ok 12 T-FIX-18 R5-14 ①: ...
not ok 13 T-FIX-18 R5-14 ②: ...
ok 14 T-FIX-18 R5-10 ③: ...
ok 15 T-FIX-18 R5-14 ④ 反向控制: ...
```

还原 fix 后腿①/②/③/④全 `ok`。证明判据有牙（非恒绿、非恒红）。

## 六、具名性（verify ④）

腿① 输出含被删文件的确切路径字符串 `test/test_gate_config_presets.bats`（非泛化措辞「文件缺失」）；腿② 输出含 `skills/flow/SKILL.md`。

## 七、make check 汇总（verify ⑤）

`make check`：21 ✅ / 0 ❌（`make test-sync` ✅ · `package-dsh-plugin.sh` ✅ · `package-flow-kit.sh` ✅ · `make check-hooks-sync check-test-sync check-dist` ✅）。

## 八、六维自评

| 维度 | 自评 | 说明 |
|---|---|---|
| 判据不改写 | ✅ | `<verify>` ①–⑤ 原样实跑，未改写或放宽 |
| 锚点命中 | ✅ | `:198-211`（修复后行号）fail-closed；bats +4 腿 |
| 先红后绿 | ✅ | `pre.sh` 缺陷态 rc=0+WARNING+✅；修复后 rc=1+🔴MISSING |
| 变异有牙 | ✅ | 还原 WARNING+return ⇒ 腿①/② not ok |
| 具名性 | ✅ | 被删文件确切路径字符串出现在输出 |
| 工作树纪律 | ✅ | 夹具仅写 `/tmp/tfix18/`；逐路径 `git add`；禁 `-A`/`--no-verify` |

## 九、未验证边界 / 遗留风险

- **TC1/TC2（TD-033/TD-034）**：`check_gate_config_sync()` 的值比较逻辑属 v2 范围（DESIGN D5 边界），本任务只改缺件 fail-closed 路径，未碰值比较逻辑。
- **AC-4 判别形态**：本任务未发现 `check_pair` 存在行数短路（`:117` 已是内容 diff），故未改判定实现；R5-10 ③ 用测试腿钉住该形态不退化。
- **bash 3.2 兼容**：`local missing=0` + 位掩码算术，无 `declare -A`/`mapfile`/`readarray`/`realpath`/`stat -c`/GNU `sed -i`。

## 十、台账五字段

见 `.flow-active` 的 `goal.task_progress` 末尾 `T-FIX-18` 条目。
