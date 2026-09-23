# T15 SUMMARY · AC-4 断言收紧：`test_check_gate_sync.bats` 由容忍 `exit 1` 改为断言 `exit 0`

- **task**: T15（`parallel="true"` · `model-tier="cheap"`）
- **change**: `health-fix-2026-09b` · 阶段 4（DEV）
- **仓库根**: `<repo>`（L-129：不入档机器绝对路径）

## 1. 任务理解

AC-4 的核心是「门禁能看见内容漂移，而不是只看行数」。T14 已把 `check-gate-sync.sh` 接入
`make check` 先决条件；T15 负责收掉**最后一条容忍永久红的测试断言**：
`<repo>/test/test_check_gate_sync.bats:30` 的 `[ "$status" -ne 2 ]` 允许脚本以 `exit 1`
（=发现漂移）退出却仍然判绿 ⇒ 门禁即使永久红也无人报警。本 task 把该断言收紧为
`[ "$status" -eq 0 ]`，并把同文件 `:6-9` 已失真（声称 toll-gate 段有 pre-existing PCSC 漂移、
故不依赖整脚本 exit 码）的头部注释改成与实测一致的表述。

## 2. 边界复述

- 写面（仅此 2 文件，双源逐字节一致）：`test/test_check_gate_sync.bats`、`flow-kit-bundle/test/test_check_gate_sync.bats`。
- 保持原样：本文件 `:31/:32/:38/:39/:45/:51/:52` 的行为断言未动（见 §4 diff）。
- 未触碰：`test/test_quality_baseline.bats`（AC-2 的 `-ne 2` 不在写面）、
  `flow-kit-bundle/flow-kit/reference/check-gate-sync.sh`（§5.3 证明零残留）、
  `TASK.md` 除 T15 状态行外无任何改动、暂存面冻结集 6 文件与 `CONTEXT/LESSONS/STATE` 一律未夹带。

## 3. 改动（`file:line` 前后对比）

### 3.1 `test/test_check_gate_sync.bats:31`（断言收紧）+ `:28`（测试名订正）

```diff
-@test "T02: 基线 SKILL↔bats 预设名一致 → gate-config 段报告一致（9 预设）" {
+@test "T02: 基线 SKILL↔bats 预设名一致 → gate-config 段报告一致（17 预设）" {
   run bash "$SCRIPT"
-  [ "$status" -ne 2 ]                                  # 非脚本错误（exit 2）
+  [ "$status" -eq 0 ]                                  # 健康态必须 exit 0（AC-4 收紧）
   [[ "$output" == *"预设名集合一致 (17 个预设)"* ]]     # gate-config 段 MATCH
   [[ "$output" != *"gate-config 预设名集合不一致"* ]]  # 无 gate-config 漂移
```

`（9 预设）`→`（17 预设）` 的改名前置条件已实测：`grep -rn '9 预设\|基线 SKILL↔bats 预设名一致'`
在 `test/`、`flow-kit-bundle/test/`、`flow-kit-bundle/hooks/`、`Makefile`、`flow-kit-bundle/flow-kit/`、
`.specs/health-fix-2026-09b/TASK.md` 全命中**仅 2 处、均为本文件双源自身**（rc=0，无外部按名引用）⇒ 可安全改名。

### 3.2 `test/test_check_gate_sync.bats:6-9`（订正过期注释）

```diff
-# 注：check-gate-sync.sh 同时跑 toll-gate 校验（4-dev↔flow-dev）+ gate-config 校验。
-# toll-gate 段基线有 pre-existing PCSC 漂移（prompt=9 vs skill=8，非本测试引入），
-# 故测试聚焦 gate-config 段的输出文本断言（"预设名集合一致" / "gate-config 预设名集合不一致"），
-# 不依赖整脚本 exit 码（被 toll-gate 段污染）。
+# 注：check-gate-sync.sh 同时跑 PCSC 校验对（3/14）+ gate-config 校验。
+# 实测健康态（T15/AC-4 修复后）：整脚本 rc=0，汇总行「✅ 校验对 3/14 一致」，
+# gate-config 段「✅ 预设名集合一致 (17 个预设)」⇒ 本用例在健康态断言 exit 0
+# （旧注释声称 toll-gate 段有 pre-existing 漂移、故只断言 -ne 2，已失真）。
+# 断言收紧为 -eq 0 后：任何内容漂移（含 gate-config 预设名漂移）都会让门禁非 0 ⇒ 本用例必红。
```

订正依据（实测，非推断）：

```console
$ bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh | tail -3
   ── 校验汇总 ──
   覆盖度: 校验对 3/14（v1 仅覆盖内容本应一致、仅差 front-matter 的对；其余 11 对已实质分叉，留 v2/TD-025）
   ✅ 校验对 3/14 一致（仅覆盖上述对，非全量 14 对全绿）。
$ echo $?
0
$ bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh | grep -n '预设名集合一致'
   ✅ 预设名集合一致 (17 个预设)
```

## 4. 双态真实输出（L-120 / L-123：收紧后的断言必须**真的能红**）

### 4.1 ⚠️ 重要偏差：工件规定的注入手法在本机是 **no-op**，已被证伪并替换为等价注入

TASK.md/T15 指定的注入是 `printf '\nexit 1\n' >> "$S"`（在脚本**末尾追加**）。逐字执行后
**bats 仍 5 ok / rc=0** —— 按 task 指令「若仍是 ok ⇒ 收紧无效，必须停下来报告」，我先做了归因，
结论是**追加行永不执行**（不是断言无效）：

```console
$ S=flow-kit-bundle/flow-kit/reference/check-gate-sync.sh
$ cp "$S" /tmp/cgs-t15.bak; sha256sum "$S"
ef994b2828243b36b477b1abab673c0fb686595e00605787e2423f9fc04e9a31  flow-kit-bundle/flow-kit/reference/check-gate-sync.sh
$ printf '\nexit 1\n' >> "$S"; sha256sum "$S"
6b7cef634e37f5884b6bf00642a855aa94e4f7214d5269e308cfe1724b9375f5  flow-kit-bundle/flow-kit/reference/check-gate-sync.sh
$ npx bats test/test_check_gate_sync.bats
1..5
ok 1 … ok 2 … ok 3 … ok 4 … ok 5 …
$ echo $?   # ⇒ 0：追加的 exit 1 没有生效
0
$ bash -x "$S" 2>&1 >/dev/null | tail -3
+ '[' 0 -gt 0 ']'
+ echo '   ✅ 校验对 3/14 一致（仅覆盖上述对，非全量 14 对全绿）。'
+ exit 0                      # ← 脚本自身的 exit 0 先终止进程，末尾追加的 exit 1 是死代码
$ strace -f -e trace=exit_group bash "$S" 2>&1 | tail -2
exit_group(0)                           = ?
+++ exited with 0 +++
```

该失败与我的改动无关（是**注入手法**在 `flow-kit-bundle/flow-kit/reference/check-gate-sync.sh:210`
的 `exit 0` 面前无效）。为提交可复现的判别力证据，改用**等价注入：把该行 `exit 0` 改成 `exit 1`**
（失败态 = 门禁自己在「一致」分支上返回非 0，即等价于「永久红」），其余逻辑与输出完全不变。

### 4.2 注入态 ⇒ 必红（真实输出）

```console
$ sed -i '210s/^  exit 0$/  exit 1/' "$S"; sed -n '208,211p' "$S"
else
  echo "   ✅ 校验对 ${#PAIRS[@]}/${PAIRS_TOTAL} 一致（仅覆盖上述对，非全量 14 对全绿）。"
  exit 1
fi
$ sha256sum "$S"
8a14d1fd78348100bba3431d5275d39c92dc1671f27718ef7151b90c6e013d4c  flow-kit-bundle/flow-kit/reference/check-gate-sync.sh
$ bash "$S" >/tmp/inj-out.txt 2>&1; echo "SCRIPT rc=$?"
SCRIPT rc=1
$ npx bats test/test_check_gate_sync.bats; echo "bats rc=$?"
1..5
ok 1 T02: check-gate-sync.sh 存在且可执行
not ok 2 T02: 基线 SKILL↔bats 预设名一致 → gate-config 段报告一致（17 预设）
# (in test file test/test_check_gate_sync.bats, line 31)
#   `[ "$status" -eq 0 ]                                  # 健康态必须 exit 0（AC-4 收紧）' failed
ok 3 T02: SKILL.md 注入假预设（有 →）→ gate-config 段报漂移 + 列出 fake-preset
ok 4 T02: SKILL.md 删除真预设 design → gate-config 段报漂移
ok 5 T02: 不依赖文本段 marker — 注入英文注释（无 →）不误报漂移
bats rc=1
```

### 4.3 反事实对照（证明「收紧」是这条红的原因，而非别的断言）

把**新**断言暂时换回**旧**形态（只在 `/tmp` 副本里，仓库文件不动），在同一注入态下重跑：

```console
$ sed 's/\[ "\$status" -eq 0 \]/[ "$status" -ne 2 ]/' test/test_check_gate_sync.bats > /tmp/t15-counterfactual.bats
$ grep -n 'status.*-ne 2' /tmp/t15-counterfactual.bats
31:  [ "$status" -ne 2 ]                                  # 健康态必须 exit 0（AC-4 收紧）
$ npx bats /tmp/t15-counterfactual.bats; echo "旧形态 bats rc=$?"
1..5
ok 1 … ok 2 … ok 3 … ok 4 … ok 5 …
旧形态 bats rc=0
```

⇒ **同一失败态**：旧形态 `-ne 2` 全绿（`exit 1` 被容忍），新形态 `-eq 0` 红并指名 `line 31`。
这正是「收紧有效」的差分证据。

### 4.4 复原 ⇒ 零残留 + 复跑全绿

```console
$ cp /tmp/cgs-t15.bak "$S"
$ cmp -s /tmp/cgs-t15.bak "$S" && echo "cmp: identical"
cmp: identical
$ sha256sum "$S"
ef994b2828243b36b477b1abab673c0fb686595e00605787e2423f9fc04e9a31  flow-kit-bundle/flow-kit/reference/check-gate-sync.sh   # 与注入前逐字一致
$ git diff -- "$S"
（空输出）
$ npx bats test/test_check_gate_sync.bats; echo "bats rc=$?"
1..5
ok 1 T02: check-gate-sync.sh 存在且可执行
ok 2 T02: 基线 SKILL↔bats 预设名一致 → gate-config 段报告一致（17 预设）
ok 3 T02: SKILL.md 注入假预设（有 →）→ gate-config 段报漂移 + 列出 fake-preset
ok 4 T02: SKILL.md 删除真预设 design → gate-config 段报漂移
ok 5 T02: 不依赖文本段 marker — 注入英文注释（无 →）不误报漂移
bats rc=0
```

## 5. verify（工件判据原样执行 · L-128）

### 5.1 工件 `<verify>` 原样抽取 + 执行

```console
$ flow-kit-bundle/flow-kit/scripts/task-brief .specs/health-fix-2026-09b/TASK.md T15 \
    | awk '/^  <verify>$/{f=1;next} /^  <\/verify>$/{f=0} f' > /tmp/t15v.sh && bash -n /tmp/t15v.sh && bash /tmp/t15v.sh; echo "rc=$?"
1..5
ok 1 T02: check-gate-sync.sh 存在且可执行
ok 2 T02: 基线 SKILL↔bats 预设名一致 → gate-config 段报告一致（17 预设）
ok 3 T02: SKILL.md 注入假预设（有 →）→ gate-config 段报漂移 + 列出 fake-preset
ok 4 T02: SKILL.md 删除真预设 design → gate-config 段报漂移
ok 5 T02: 不依赖文本段 marker — 注入英文注释（无 →）不误报漂移
rc=0
```

（判据首行 `grep -nE '\[ "\$status" -ne [0-9]+ \]' test/test_check_gate_sync.bats` 必须**无匹配**才继续 ——
实测无输出、未触发 `🔴 仍存在「容忍非零退出」形态的断言` ⇒ 负向穷举通过：`-ne [0-9]+` 任何形态均已被消除。）

### 5.2 双源一致

```console
$ cmp -s test/test_check_gate_sync.bats flow-kit-bundle/test/test_check_gate_sync.bats; echo "cmp rc=$?"
cmp rc=0
$ make check-test-sync; echo "rc=$?"
🔍 make check-test-sync: test/ ↔ flow-kit-bundle/test/ ...
✅ test 双源一致
rc=0
```

### 5.3 门禁

| 命令 | 结果 |
|---|---|
| `make test` | 见 §5.4（973 ok / 0 not ok / rc=0） |
| `make lint` | rc=0 · `✅ shellcheck: no errors found`（SCANNED_FILES: 67） |
| `make check-hooks-sync` | rc=0 · 6 个副本 `✅`、`✅ hooks 副本一致（漂移 0）` |
| `bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh` | rc=0 |
| `npx bats test/test_check_gate_sync.bats` | 5 ok / 0 not ok / rc=0 |

`make check` / `make check-dist` 在本 change 期间预期为红（T24 收口），未修、未据此判失败。

### 5.4 `make test` 全量输出（尾部）

```console
$ make test > /tmp/t15-make-test.log 2>&1; echo "make test rc=$?"
🧪 make test: running bats...
...
ok 971 CF-01: write_compliance_correction creates valid JSON with all fields
ok 972 CF-02: write_compliance_correction merges with existing + dedup
ok 973 CF-03: clear_compliance_correction removes the file
✅ bats: all tests passed
make test rc=0
```

判读依据：第 1 条 `npx bats test/ --formatter tap | tail -3` 打印的末条即 **`ok 973`**
（总用例数 973），第 2 条 `npx bats test/ > /dev/null` 成功才打印 `✅ bats: all tests passed`，
否则走 `❌ bats: some tests failed; exit 1`。实测两条均通过、`rc=0` ⇒ **973 ok / 0 not ok**。

## 6. 6 维自查（内置快查 · 本 task 为纯测试改动）

- **R1 认知过载**：无新增函数；改动为注释 + 1 行断言 + 1 行测试名 ⇒ 无
- **R2 变更传播**：diff 仅 2 个 bats 文件（`git diff --stat` = 2 files changed, 14 insertions(+), 12 deletions(-)），零越界 ⇒ 无
- **R3 知识重复**：断言逻辑本就由双源镜像承担（`make check-test-sync` 守护）⇒ 无新增重复
- **R4 偶然复杂**：未引入任何新抽象/扩展点 ⇒ 无
- **R5 依赖混乱**：未动 import/依赖 ⇒ 无
- **R6 领域扭曲**：注释措辞改为与门禁实测语义一致（「PCSC 校验对 3/14」「17 个预设」）⇒ 已修正一处语义失真

## 7. TDD 声明

纯测试断言收紧 + 注释订正（无生产代码改动），按 4-dev.md §2 属可跳过 TDD 的类型；
但已按 L-120 补足**双态对照**（§4.2 红 / §4.4 绿）与**反事实对照**（§4.3），
即「新形态可用」与「旧形态确实会漏」两条独立断言都实跑过（L-123 ②）。

## 8. 遗留 / 交接

1. **工件注入手法需订正（建议登记 LESSONS）**：TASK.md/T15 的 `<action>` 与主 agent 下发的
   「`printf '\nexit 1\n' >> "$S"` ⇒ 必须出现 `not ok 2`」在本机**不可能成立** ——
   `check-gate-sync.sh:210` 的 `exit 0` 使追加行为死代码（strace `exit_group(0)` 为证）。
   后续涉及「让脚本以非零退出」的双态注入，应改为**改自然出口行**（如 `sed -i '210s/exit 0/exit 1/'`）
   或在**失败分支**注入，且**断言注入后脚本自身 rc 非 0** 再跑 bats（否则会得到假绿）。
   同族风险：任何「末尾追加 exit N」的注入手法对**以显式 exit 结尾**的脚本都无效。
2. `:28` 测试名 `（9 预设）`→`（17 预设）` 已顺带订正（前置 grep 证明无外部按名引用）。
3. 冻结集 6 文件（staged `A`）与 `CONTEXT/LESSONS/STATE` 在本次提交中**未夹带**（`git status --short` 复查见回报）。
