# T04-SUMMARY — TD-043 收口：L3 提示词信封的 ADR 纳入策略双态验证（含 ADR-028、不含 ADR-011 正文）

- **Change ID**: health-fix-2026-09b
- **Task ID**: T04
- **完成时间**: 2026-09-23 10:47
- **AI 角色**: Dev（阶段 4 单任务执行者 · fresh context）
- **任务性质**: **独立验证 + 入库收口**（不是重新实现）—— 见下「任务性质与自指披露」

---

## 做了什么（一段话）

对主 agent 已在阶段 2/3 按用户裁决落地的 `flow-kit-bundle/hooks/stop/lib/l3-prompt.sh` ADR 纳入策略做**独立验证**：
逐字实跑任务 XML 的 `<verify>`（**rc=0**），再做**修复前/修复后双态对照**证明判据有判别力（before = ADR-011/015/019 各 1 命中、028 **0** 命中；after = 028/022/027/005 各 1 命中、011 **0** 命中 —— 两态结果**不同**，判据有判别力）；
另做 **RED 态实证**：把基线版本临时换回工作区再跑同一条 `<verify>`，得到 `🔴 本 change 引用的 ADR-028 未按正文纳入` + `rc=1`（随后逐字节还原，sha256 一致）。
源码形态四项核对通过（策略/常量在位、注释标记在位、无 `head -3` 可执行形态、副本漂移 0）。**双态 verify 成立 ⇒ 按任务 XML 硬约束「不改动实现、只提交」**，
故本任务的改动**仅为入库**（`l3-prompt.sh` 原样提交 + 本 SUMMARY + 两条 🟡 登记 + TASK.md 勾选）。
**偏离原计划处**：任务 XML 的 `<done>` 附带的历史实测值（「49468 B；ADR 正文标记命中 022/028/027/005/**008**」）与本次实测**不完全一致** —— 见下「与 `<done>` 历史实测值的差异（如实报告）」段。

## 任务性质与自指披露（CHANGE §4b（用户裁决 · 2026-09-23）· 必填）

- **被审门禁修改了自身**：本 change 修改的是**正在审查它自己**的 L3 提示词构造逻辑（`l3-prompt.sh`）。
- **缓解（CHANGE §4b / DESIGN §0.5.1 原文口径）**：该改动只**减少**提示词噪声、**不放宽任何判据** —— 提示词信封的内容不参与任何 gate 的判定，
  无判据可被它绕过；且实测证据齐备（双态对照 + RED 态 + 确定性三跑）、TD-043 由「缺陷登记」转「已修」而非隐藏。
- **T04 的身份边界**：实现由主 agent 在阶段 2/3 落地（工作区 `modified 未提交`），T04 只做**独立验证 + 入库收口**。
  验证者与实现者分离（fresh context 子 agent 复核主 agent 的改动），故本 SUMMARY 的结论不构成自证。

## 改动文件

| 文件 | 性质 | 说明 |
|---|---|---|
| `flow-kit-bundle/hooks/stop/lib/l3-prompt.sh` | **入库**（内容零改动） | 阶段 2/3 已落地的 TD-043 修复（`:344-375`）。T04 **未修改任何一行**：提交前 `sha256=dae9537f04c7024743ce7a65472c7e3370663608465a4d6b41dff634203bbe3c`，RED 态实测后还原，`sha256` 逐字节一致 |
| `.specs/health-fix-2026-09b/T04-SUMMARY.md` | 新增 | 本文件 |
| `.specs/health-fix-2026-09b/MINOR-DEFERRED.md` | 修改 | 追加「阶段 4 · T04 六维自查 🟡 登记」段（G-T04-1 / G-T04-2） |
| `.specs/health-fix-2026-09b/TASK.md` | 修改 | T04 的 `status="pending"` → `status="done"`（单点改动） |

> **未改动（有意）**：`flow-kit-bundle/hooks/stop/lib/l3-prompt.sh` 的**实现逻辑**（双态 verify 成立 ⇒ 任务 XML 明令不改）；
> `.specs/CONTEXT.md`、`.specs/STATE.md`、`.specs/adr/028-gate-baseline-allowlist.md`、CHANGE/REQUIREMENT/INDEPENDENT-REVIEW-*.md、
> `.specs/health/2026-09-22-FULL-SWEEP.md`（任务 XML 明令保持原样、不提交）。

---

## `<verify>` 命令与真实输出（逐字实跑）

### 逐字执行的命令（与任务 XML 完全一致）

```bash
export LC_ALL=C; P='--- .specs/adr/';
out=$(bash -c 'source flow-kit-bundle/hooks/stop/lib/l3-prompt.sh 2>/dev/null; _l3_build_prompt 2 .specs/health-fix-2026-09b 200000' 2>/dev/null);
[ -n "$out" ] || { echo "🔴 提示词为空（调用形态/预算错误）"; exit 1; };
printf '%s' "$out" | grep -q "^${P}028-gate-baseline-allowlist\.md ---" || { echo "🔴 本 change 引用的 ADR-028 未按正文纳入"; exit 1; };
if printf '%s' "$out" | grep -q "^${P}011-"; then echo "🔴 无关 ADR-011 仍被纳入正文"; exit 1; fi;
printf '%s' "$out" | grep -qE '预算|未纳入' || { echo "🔴 缺截断/未纳入显式标记"; exit 1; }
```

### 真实输出（关键行 · 逐字）

```text
VERIFY_RC=0
--- 提示词字节数 ---
92947
```

**三个判据的逐项复核**（把 `<verify>` 的三条 `grep` 拆开单独跑，证明不是「整体 rc=0」掩盖了分支）：

```text
  ✅ ADR-028 正文标记在位          (grep -q "^--- .specs/adr/028-gate-baseline-allowlist.md ---"  → rc=0)
  ✅ ADR-011 不在                  (grep -q "^--- .specs/adr/011-"                        → rc=1)
  ✅ 预算/未纳入标记在位            (grep -qE '预算|未纳入'                                  → rc=0)
```

**提示词非空**：`wc -c` = **92947 B**（> 0 ⇒ 未落入「调用形态/预算错误」分支；三参形态正确 —— 见下「三参调用形态核对」）。

> ⚠️ 上述 `92947` 是 `printf '%s' "$out" | wc -c`（命令替换 `$(...)` 剥掉尾随换行）的值；
> 重定向到文件后 `wc -c` = **92998 B**（差 51 B = 被剥掉的尾随换行/结尾空行）。两数都是实测，口径不同，非矛盾。

### 三参调用形态核对（任务 XML 点名「缺 `max_bytes` 会退化为 0 B 截断」）

```text
=== 现行版 _l3_build_prompt 签名 ===
322:_l3_build_prompt() {
=== 基线 534e3e8 版签名 ===
322:_l3_build_prompt() {
```

两版**签名逐字相同**：

```bash
# 用法: _l3_build_prompt <phase> <artifacts_dir> <max_bytes>   # 单位=字节（§B3）
_l3_build_prompt() {
  local phase="$1" artifacts_dir="$2" max_bytes="$3"
```

⇒ 任务 XML 的告警「**三参**，缺 `max_bytes` 会退化为 0 B 截断」**已被本次实跑覆盖**（传入 `200000`，得到 92947 B 非空输出）；
且**基线版本与现行版本签名相同** ⇒ 下节双态对照的两态调用口径完全一致，差异只能归因于 ADR 纳入策略本身（**无签名变量污染**）。

---

## 双态对照（`LESSONS.md` L-120 强制 · 判据判别力证明）

### 对照方法（沙箱内操作，临时文件不入仓）

```bash
d=$(mktemp -d);                                                              # /tmp/tmp.E28JhNFqLk
git show 534e3e8:flow-kit-bundle/hooks/stop/lib/l3-prompt.sh > "$d/before.sh" # 变更前基线版本（26287 B）
cp flow-kit-bundle/hooks/stop/lib/l3-prompt.sh             "$d/after.sh"     # 现行版本（28697 B）
# 两态用【同一条】调用把输出落盘：
bash -c "source $d/<state>.sh 2>/dev/null; _l3_build_prompt 2 .specs/health-fix-2026-09b 200000" 2>/dev/null > "$d/<state>.out"
```

### 对照表 · ADR 正文标记命中数（口径：`grep -c "^--- .specs/adr/<NNN>-"`）

| ADR 正文标记 | `before`（基线 534e3e8） | `after`（现行工作区） | 期望（任务 XML） | 判定 |
|---|---|---|---|---|
| ADR-**011** 正文标记 | **1** | **0** | before 有 / after 无 | ✅ |
| ADR-**015** 正文标记 | **1** | **0** | before 有（任务 XML 称「011/015/019 之一存在」） | ✅ |
| ADR-**019** 正文标记 | **1** | **0** | before 有 | ✅ |
| ADR-**028** 正文标记 | **0** | **1** | before 无 / after 有 | ✅ |
| ADR-022 正文标记 | 0 | **1** | —（额外实证「按引用频次」） | ✅ |
| ADR-027 正文标记 | 0 | **1** | — | ✅ |
| ADR-005 正文标记 | 0 | **1** | — | ✅ |
| ADR-026 正文标记 | 0 | 0 | — | ℹ️ |
| ADR-008 正文标记 | 0 | 0 | —（`<done>` 曾记为命中，本次实测未命中，见下差异段） | ⚠️ |

**两态结果不同 ⇒ 判据有判别力**（任务 XML：「两态必须给出**不同结果**，否则判据无判别力，须如实报告」——此处**不同**，故无需报「无判别力」）。

### 全部 ADR 正文标记清单（`grep -o` 原样）

```text
[before]
      1 --- .specs/adr/011-pipeline-goal-no-g1-autoadvance.md ---
      1 --- .specs/adr/015-task-progress-schema.md ---
      1 --- .specs/adr/019-writing-principles.md ---
[after]
      1 --- .specs/adr/005-gate-active-source-dependency.md ---
      1 --- .specs/adr/022-git-hook-deployment.md ---
      1 --- .specs/adr/027-gates-surface-not-threshold.md ---
      1 --- .specs/adr/028-gate-baseline-allowlist.md ---
```

- `before` = **目录序前 3 份**（`find "$adr_dir" -type f -name '*.md' | head -3`）—— 与本 change 无关，正是 TD-043 的病灶（CHANGE §4b 描述的「实测恒为 ADR-011 / ADR-015 / ADR-019」**逐字复现成立**）。
- `after` = **按工件引用频次降序**取前 N 份，且纳入顺序与频次表**完全吻合**（`028/022` 并列 113、`027` 53、`005` 11；`01/028` 的先后由 `sort` 字典序决定）：

```text
=== 工件中 ADR-0NN 引用频次（排序依据）===
    113 ADR-028
    113 ADR-022
     53 ADR-027
     11 ADR-005
      9 ADR-008
      …
```

```text
=== 纳入顺序（提示词内正文标记出现的先后）===
530:--- .specs/adr/022-git-hook-deployment.md ---
621:--- .specs/adr/028-gate-baseline-allowlist.md ---
689:--- .specs/adr/027-gates-surface-not-threshold.md ---
734:--- .specs/adr/005-gate-active-source-dependency.md ---
```

### `before` 版本源码（逐字，证明基线形态）

```text
343:      adr_dir="$(dirname "$artifacts_dir")/adr"
344-      if [ -d "$adr_dir" ]; then
345-        while IFS= read -r f; do
346-          [ -n "$f" ] || continue
347-          artifact="${artifact}"$'\n\n--- '"${f}"$' ---\n'"$(_l3_utf8_head_bytes 2000 "$f" 2>/dev/null || echo "")"
348-        done < <(find "$adr_dir" -type f -name '*.md' 2>/dev/null | head -3 || true)
349-      fi
```

---

## RED 态实证（把 `<verify>` 当测试用 —— 证明它不是恒真式）

仅「before/after 输出不同」还不足以证明 **`<verify>` 自身**有判别力（`<verify>` 是 bash 脚本，不是纯 grep）。故把**基线版本临时换回工作区**，用**同一条 `<verify>`** 再跑一次：

```text
swap 前 sha256=dae9537f04c7024743ce7a65472c7e3370663608465a4d6b41dff634203bbe3c
=== RED 态：把基线版本临时换上，逐字重跑同一 <verify> ===
🔴 本 change 引用的 ADR-028 未按正文纳入
RED 态 VERIFY_RC=1   (1 = 🔴 判据在基线版本上失败 ⇒ 有判别力)
restore 后 sha256=dae9537f04c7024743ce7a65472c7e3370663608465a4d6b41dff634203bbe3c
✅ 工作区文件已逐字节还原（sha 一致）
```

⇒ `<verify>` 在缺陷态**变红**（`rc=1` + 逐字命中文档里写好的 🔴 报文）、在修复态**变绿**（`rc=0`）—— 这是一个**真测试**，不是恒真断言。
还原后复跑现行态 `<verify>` 仍绿（`028 在位 / 011 不在 / 预算标记在位` 三项全 ✅），且 `git diff --numstat` 仍为 `31 4`（内容零漂移）。

### 确定性（排除「两态差异来自不确定性」）

```text
=== 确定性检验：同一命令跑 3 次 ===
  run1 bytes=92998 sha=d2eeb2c12d42195b
  run2 bytes=92998 sha=d2eeb2c12d42195b
  run3 bytes=92998 sha=d2eeb2c12d42195b
=== rep1 vs rep2 diff（应为空）===
  (无差异)
```

⇒ 输出**逐字节确定**（3 跑同 sha），两态差异只能归因于实现变更。

---

## 源码形态核对（任务 XML 关键要求 2 · 全部实测，勿凭推断）

### ① 策略与标记常量在位（`grep -n` 行号 + 内容逐字）

```text
=== [2] _adr_budget ===
352:        local _adr_ids _adr_id _adr_num _adr_f _adr_sz _adr_take _adr_used _adr_budget _adr_n
353:        _adr_budget=18000; _adr_used=0; _adr_n=0
363:          if [ $((_adr_used + _adr_take)) -gt "$_adr_budget" ] && [ "$_adr_n" -gt 0 ]; then
364:            artifact="${artifact}"$'\n\n（ADR 纳入预算（'"${_adr_budget}"$' B）已用尽；以下被工件引用的 ADR **未纳入**，需要时按工件给出的复现命令自行查阅：'"${_adr_ids}"$'）'
=== [3] 5000 ===
346:        # 只纳入**工件实际引用**的 ADR，按引用频次排序；每份预算 5000 B、总量预算 18000 B，
362:          _adr_take=$((_adr_sz < 5000 ? _adr_sz : 5000))
367:          artifact="${artifact}"$'\n\n--- '"${_adr_f}"$' ---\n'"$(_l3_utf8_head_bytes 5000 "$_adr_f" 2>/dev/null || echo "")"
368:          if [ "$_adr_sz" -gt 5000 ] 2>/dev/null; then
369:            artifact="${artifact}"$'\n…（本件 '"${_adr_sz}"$' B 超过 5000 B 预算，已按整行**截断**；全文见 `'"${_adr_f}"$'`。此为提示词预算标记，不构成工件缺陷。）'
=== [4] max 8 ===
357:          [ "$_adr_n" -lt 8 ] || break
=== [5] markers ===
364:            artifact="${artifact}"$'\n\n（ADR 纳入预算（'"${_adr_budget}"$' B）已用尽；以下被工件引用的 ADR **未纳入**，…
369:            artifact="${artifact}"$'\n…（本件 '"${_adr_sz}"$' B 超过 5000 B 预算，已按整行**截断**；…
374:          artifact="${artifact}"$'\n\n（本工件正文未引用任何 `ADR-0NN` ⇒ 按策略**不纳入** `.specs/adr/` 的任何文件。…
=== [8] 注释标记 ===
345:        # ADR 纳入策略（TD-043 修复 · health-fix-2026-09b · 2026-09-23）：
```

| 任务 XML 声称的形态 | 实测行号 | 结论 |
|---|---|---|
| 按工件引用频次 `grep -oE 'ADR-0[0-9]{2}'` | `:354-355` | ✅ 在位（`sort \| uniq -c \| sort -rn \| awk '{print $2}'`） |
| `_adr_budget` | `:352-353, 363-364` | ✅ 在位（**18000**） |
| 每份 **5000 B** | `:362, 367, 368, 369` | ✅ 在位 |
| 最多 **8 份** | `:357` | ✅ 在位 |
| **截断**显式标记 | `:369` | ✅ 在位（文案准确性另有 🟡 G-T04-2） |
| **未纳入**显式标记 | `:364` | ✅ 在位（文案准确性另有 🟡 G-T04-1） |
| **无引用**显式标记 | `:374` | ✅ 在位（任务 XML 未要求，实现多给了一种） |
| 注释标记 `ADR 纳入策略（TD-043 修复 · health-fix-2026-09b · 2026-09-23）` | `:345` | ✅ 在位，**逐字一致** |

> `=== [1] ADR id regex ===` 的 `grep -n "ADR-0\[0-9\]{02}"` 返回**空**：该写法把 ERE 语法当字面量（`grep` 默认 BRE，`{02}` 需转义且 `\[` 匹配字面 `[`）。**已在 `:354` 用实际存在的形态复核**：
> 提示词的纳入顺序与独立算出的频次表完全吻合（见上「双态对照」），故「按引用频次」这一策略**由行为证据确认**，不依赖该条 grep。

### ② `grep -c 'head -3'` 实测值 —— **3，不是 0**（如实报告 + 逐处归类）

任务 XML 称「应为 0；注意别把注释/标记里的字样算错，请贴原文」。**字面实测为 3**，但**三处全部是注释**，无一是可执行形态：

```text
=== [6] literal grep -c 'head -3' ===
3
rc=0
=== [7] grep -n 'head -3' ===
281:# 与 §B4 的 `head -30` 截断同源：**审查者只能看到我们喂进去的东西**。
347:        # **截断与未纳入都显式落标记**。原实现为 `find "$adr_dir" | head -3`：取**目录序前 3 份**
455:      #   ① 原 `ls -la | head -30` 对顶层条目 > 28 的 change 会截掉按名序靠后的文件
```

逐处归类（`grep -nF 'head -3'` 取首非空白字符判定）：

```text
  L281  COMMENT  # 与 §B4 的 `head -30` 截断同源：**审查者只能看到…
  L347  COMMENT  # **截断与未纳入都显式落标记**。原实现为 `find "$…
  L455  COMMENT  #   ① 原 `ls -la | head -30` 对顶层条目 > 28 的 change …
```

| 命中行 | 归类 | 理由 |
|---|---|---|
| `:281` | **子串假命中** | 原文是 `head -30`（**截断数字 30**），`head -3` 只是它的前 6 个字符。与 ADR 纳入无关 |
| `:347` | **历史说明注释** | 本次新增的注释，**记录已删除的旧实现**（`原实现为 … | head -3`）。是「证据」不是「代码」——删掉它反而丢失 TD-043 的病灶记录 |
| `:455` | **子串假命中** | 同 `:281`，原文是 ``ls -la | head -30`` |

**去注释后的权威计数（应 0，实测 0）**：

```text
=== B. 去注释行后，'head -3'（非 head -30）计数（应 0） ===
0
=== C. 去注释行后，字面 'head -3' 计数（应 0） ===
0
```

**ADR 段内唯一可执行的 `find`（`:359`，不是目录序前 3 份）**：

```text
=== D. ADR 段（L342-376）内可执行 find 形态 ===
18:          _adr_f=$(find "$adr_dir" -maxdepth 1 -type f -name "${_adr_num}-*.md" 2>/dev/null | head -1 || true)
```

⇒ **可执行代码中的 `head -3` 计数 = 0**（任务 XML 的真实意图）；**字面计数 = 3，全部为注释/子串**。
按任务 XML 明令「严禁改回 `find "$adr_dir" | head -3` 形态」—— 实测**未回退**：唯一活着的 `find` 是**按 `_adr_num` 精确匹配单份** + `head -1`（取该 id 的**唯一**文件，非目录序前 N 份）。

### ③ 副本一致性（`bash sync-hooks.sh --check` · 漂移必须 0）

```text
源: <repo>/flow-kit-bundle/hooks
镜像文件数: 47（stop 模块与 install_hooks.sh 同源计数）

  ✅ $HOME/.claude/hooks
  ✅ <repo>/dist/dsh-flow-kit/hooks
  ✅ <repo>/dist/dsh-flow-kit/vendor/flow-kit-bundle/hooks
  ✅ $HOME/.dsh/profiles/web/node_modules/dsh-flow-kit/hooks
  ✅ $HOME/.dsh/profiles/web/node_modules/dsh-flow-kit/vendor/flow-kit-bundle/hooks
  ✅ $HOME/.config/opencode/hooks

✅ hooks 副本一致（漂移 0）
SYNC_RC=0
```

**漂移 = 0** ⇒ 按任务 XML 第 3 条，**无需**运行 `./sync-hooks.sh`。6 个已安装镜像已带 TD-043 修复（独立复核）：

```text
  $HOME/.claude/hooks/stop/lib/l3-prompt.sh                   1
  dist/dsh-flow-kit/hooks/stop/lib/l3-prompt.sh                          1
  $HOME/.config/opencode/hooks/stop/lib/l3-prompt.sh          1
```

（计数值 1 = 命中 `ADR 纳入策略（TD-043 修复` 注释标记；`dist/` 是 gitignored 重建产物。）

### ④ 预算算术复核（`18000 B` 是否真的没被突破）

```text
  ADR-022  size=8873   take=5000
  ADR-028  size=10558  take=5000
  ADR-027  size=4439   take=4439
  ADR-005  size=2161   take=2161
  Σ take = 16600  (预算 18000)
```

⇒ 实际用 **16600 ≤ 18000**；下一份候选（ADR-008，3038 B）会使 `16600 + 3038 = 19638 > 18000` ⇒ 正确进入「未纳入」分支。**预算逻辑按设计工作**。

---

## TDD 适用性说明（本任务为何无法挂载 bats 载体）

按任务 XML：「本任务是「验证既有实现 + 入库」，若无法挂载 bats 载体须在 SUMMARY 说明理由（并以双态对照 + 判据真跑作为替代证据）」。理由如下（**三条，均已实测/查证**）：

1. **本任务无产品代码改动** —— `<write_files>` 只在「双态 verify **不成立**」时才解锁 `l3-prompt.sh` 的写入；实测**成立** ⇒ T04 的可写面只剩 SUMMARY / TASK.md / 登记档，**没有被测对象可驱动**。
2. **既有 bats 面对 ADR 纳入段零覆盖**（实测 0 命中）：
   ```text
   $ grep -rn 'adr_dir\|ADR 纳入' test/ flow-kit-bundle/test/  → 0 命中
   ```
   含 `l3-prompt` 的测试有 4 个（`test_l3_timeout.bats` / `test_l3_lifecycle_wiring.bats` / `test_l3_pipeline_fix.bats` / `test_l3_review_defects_2026_09.bats`），但**无一条**触及 `adr_dir` 或 ADR 纳入。⇒ **无既有载体可挂**。
3. **新增载体超出本 task 的 write_files**（且 DESIGN 已把它排给别的阶段）—— DESIGN §0.5.1 第 ③ 条逐字写着「并在 **5-test** 留一条 verify」，Task XML 的 `<write_files>` 未授权任何 `test/**` 路径 ⇒ 在 4-dev 内新增 bats 文件属**扩范围（R7.1）**。若 5-test 要落 bats 载体，应在那里开对应 write_files。

**替代证据（已齐备，非口头承诺）**：
- **双态对照**（before `011/015/019` ↔ after `028/022/027/005`，结果不同 ⇒ 有判别力）；
- **RED 态实证**（同一条 `<verify>` 在基线版本上 `rc=1` + 逐字 🔴 报文，在修复态 `rc=0`）—— 等价于「先见红、后见绿」的测试行为；
- **确定性三跑同 sha**（排除噪声）；
- **`make test` 全绿**（见下节）。

**遗留**：ADR 纳入策略**当前 0 bats 覆盖** ⇒ 任何未来对该段的回归都不会被 `make test` 捕获。已在 6 维自查登记为 🟢 转入 5-test（见「已知小问题」）。

---

## 门禁实跑（pre-commit · 未绕过）

提交走**标准路径**（`git commit`，**无** `--no-verify`／**无**任何绕过写法 · L-126 ②）。pre-commit 真跑 `make test`。

```text
🧪 make test: running bats...
ok 971 CF-01: write_compliance_correction creates valid JSON with all fields
ok 972 CF-02: write_compliance_correction merges with existing + dedup
ok 973 CF-03: clear_compliance_correction removes the file
✅ bats: all tests passed
[status: completed, exit code: 0]
```

**bats 全绿 · rc=0 · 0 not ok**（提交前独立预跑，与 TASK.md 的 `bats ≥ 973` 期望一致）。

---

## 6 维自查结果（内置 R1~R6 快查 · brooks-lint 未安装 ⇒ 按任务 XML 用内置回退）

| 维度 | 结论 | 计数 |
|---|---|---|
| R1 正确性 | 实现按设计工作（双态 + 预算算术 + 确定性均已实测） | 🟢 |
| R2 边界 | `_adr_n -gt 0` 守卫使「首份即超预算」时仍纳入 ≥1 份；`_adr_take` 上限 5000 < 18000 ⇒ 不会死循环/空转 | 🟢 |
| R3 契约 | **签名零变更**（三参，与基线逐字相同）；`l3-review.sh:117/140` 两处调用点未受影响 | 🟢 |
| R4 一致性 | 6 个镜像漂移 0；注释标记逐字在位 | 🟢 |
| R5 可测试性 | **ADR 纳入段 bats 覆盖 = 0**（既有测试面 0 命中）；本次以双态 + RED 态替代 | 🟢（已登记转 5-test） |
| R6 越界 | diff 边界 ⊆ write_files，0 越界（见下节） | 🟢 |
| **附加（标记文案准确性）** | **G-T04-1「未纳入」标记罗列全量引用清单（含已纳入的 4 件）** | **🟡** |
| **附加（标记文案准确性）** | **G-T04-2 标记称「整行截断」，实测为半行（仅 UTF-8 安全）** | **🟡** |

**计数：🔴 0 · 🟡 2 · 🟢 6**。

### 🔴 必修项

**无**（0 项）。双态 verify 成立、RED 态可复现、门禁全绿、无越界。

### 🟡 项处置（**登记不修** · 已写入 `MINOR-DEFERRED.md`）

两条均**登记**（不修）—— 依据：任务 XML 硬约束「若双态 verify 成立 ⇒ **不要改动实现**，只提交它（连同 SUMMARY）」。
两条都是**本次修复新写下的标记文案**的准确性问题（**不放宽任何判据**，无判据可被绕过），修它们属 4-dev 期内对已裁决实现的二次改写。

- **G-T04-1**（`:364`）：「未纳入」标记内插 `"${_adr_ids}"` = **全量引用清单**（实测列出 6 个 id：`ADR-022/028/027/005/008/001`），而真正被跳过的只有 `008/001` ⇒ 把**已带完整正文标记**的 `022/028/027/005` 也声明成「未纳入」。L3 是盲审者，会据此误判「本 change 的决策依据 ADR-028 不在提示词里」。
- **G-T04-2**（`:367` vs `:369`）：标记称「已按**整行**截断」，实测**半行**截断 —— `:367` 的 `_l3_utf8_head_bytes 5000` 只保证 UTF-8 码点安全（定义在 `:27`：`head -c` + `_l3_utf8_head_stream` 的边界回退），**未**补 `sed '$d'`（对照 `:304-309`：补充产物路径的「整行截断」成立**正是因为** `:309` 有 `sed '$d'`）。实测截断点：`022` 第 5000 字节 = `0xE9`、`028` 第 5000 字节 = `0x65`（均非 `\n`）。

### 已知小问题（🟢 · 转入 5-test）

- **G-T04-3**：ADR 纳入策略（`l3-prompt.sh:344-375`）**当前 bats 覆盖 = 0** —— `grep -rn 'adr_dir\|ADR 纳入' test/ flow-kit-bundle/test/` 无命中。⇒ 未来对该段的回归不会被 `make test` 捕获。**5-test 应补一条 bats**（判据可直接复用 T04 的 `<verify>`：phase 2 输出含 `028` 正文标记、不含 `011-`；对照态用 `534e3e8` 的基线版本 —— 本 SUMMARY 的双态方法可逐字复用）。
- **G-T04-4**：`<done>` 的历史实测值与本次实测存在差异（见下节）—— 属**工件元数据陈旧**，非代码缺陷。

---

## 与 `<done>` 历史实测值的差异（如实报告）

`<done>` 逐字写：「（实测基线：49468 B；ADR 正文标记命中 022/028/027/005/**008**）」。本次实测**两点不一致**：

| 项 | `<done>` 所记 | T04 本次实测 | 差异归因（已核实） |
|---|---|---|---|
| phase 2 提示词字节数 | 49468 B | **92947 B**（命令替换口径）/ 92998 B（重定向口径） | `.specs/health-fix-2026-09b/` 的工件在该次测量**之后**又被增补（T01/T02/T03-SUMMARY、`PROGRESS.md`、TASK.md 的 verify 段等），phase 2 提示词含 TASK.md/DESIGN.md 正文 ⇒ 体积随工件增长。**非实现变化**：实现自那次测量以来未再改动（T04 提交的内容零改动，sha 可查） |
| ADR-008 正文标记 | **命中** | **未命中**（命中集为 `022/028/027/005`） | 同上：`_adr_ids` 取自 `$artifact` 的**预览裁剪后**内容（必备件按 3000 B 预览预算），工件增补改变了各 ADR 的**可见引用频次**排序。实测频次 `005`=11 > `008`=9，而预算在第 5 份之前耗尽（`16600 + 3038 = 19638 > 18000`）⇒ 008 落入「未纳入」。**预算行为符合设计**，非缺陷 |

**两者都不影响 `<verify>` 的通过性**（`<verify>` 只断言「含 028」「不含 011」「含预算/未纳入标记」，三条均 ✅）；但按任务 XML「不许凭推断、以实测为准」，此处**逐字披露差异而不改写 `<done>`**（`<done>` 属阶段 3 工件正文，4-dev 期内不改 —— 与 T02 对 `<action>` 的处置同例）。

---

## 越界检查（R6.5 · 提交前 diff 边界 verify）

```
✅ 越界检查（R6.5）：
  - TASK write_files：1 项（`flow-kit-bundle/hooks/stop/lib/l3-prompt.sh`（仅当双态 verify 不成立时补齐））
                      + 协议要求的元数据写入（SUMMARY / TASK.md 勾选 / .flow-active 追加）
  - 实际 diff 涉及（提交面）：4 项
      · flow-kit-bundle/hooks/stop/lib/l3-prompt.sh   （入库 · 内容零改动 · 见下「内容零改动」）
      · .specs/health-fix-2026-09b/T04-SUMMARY.md     （新增 · 本文件）
      · .specs/health-fix-2026-09b/MINOR-DEFERRED.md  （修改 · 追加 T04 🟡 登记段）
      · .specs/health-fix-2026-09b/TASK.md            （修改 · T04 status 单点）
  - 越界：0
```

**保持原样、明确不提交**（任务 XML 明令）：`.specs/CONTEXT.md`、`.specs/STATE.md`、`.specs/adr/028-gate-baseline-allowlist.md`、
`.specs/health-fix-2026-09b/{CHANGE.md,REQUIREMENT.md,INDEPENDENT-REVIEW-1/2/3.md}`、`.specs/health/2026-09-22-FULL-SWEEP.md`。
`.flow-active` 是 **gitignored**（`.gitignore:50`）⇒ 只追加、**不入库**。

**未改 REQUIREMENT / DESIGN**（R3.2 ✅）；**未扩范围**（R7.1 ✅）；**未 mock 屏蔽真失败**（R5.2 ✅）；**无「应该可以工作」式表述**（R6.3 ✅）。

### 「内容零改动」的证据

```text
=== git diff --numstat（RED 态实测 + 还原之后）===
31	4	flow-kit-bundle/hooks/stop/lib/l3-prompt.sh
```

与 RED 态实测**之前**的 `git diff --stat` 完全一致（`+31/-4`，即阶段 2/3 落地时的形态，未增未减一行）；
且 `sha256` 在 swap 前 / restore 后**逐字节相同**（`dae9537f04c7024743ce7a65472c7e3370663608465a4d6b41dff634203bbe3c`）。
⇒ T04 对被测文件的唯一动作是**把它提交进库**。

---

## 破坏性变更（R4.6 / B4）

**N/A —— 无破坏性改动。**

- 删除既有代码：**否**（唯一的删除是 `l3-prompt.sh` 内 4 行被替换的 ADR 纳入循环，属 TD-043 修复本体，已在阶段 2/3 由用户裁决授权；
  净变化 `+31/-4`，且**签名与调用点零变更**）。
- 改公共导出（函数/类/接口签名）：**否** —— `_l3_build_prompt` 的三参签名与基线**逐字相同**（`:322-323`，两态比对见上）。
- 改公共 API：**否**。删文件/重命名导出符号：**否**。
- 引用图（`grep` 实证）：
  ```text
  flow-kit-bundle/hooks/stop/lib/l3-review.sh:117:      _prompt=$(_l3_build_prompt "$phase" "$artifacts_dir" "$max_bytes" 2>/dev/null || echo "")
  flow-kit-bundle/hooks/stop/lib/l3-review.sh:140:  prompt_text=$(_l3_build_prompt "$phase" "$artifacts_dir" "$max_bytes") || return 3
  ```
  ⇒ 两处调用点**均为三参**，与签名匹配，**无需改动**。

---

## 决策与偏离（如有）

1. **不改实现**（核心决策）：双态 verify 成立 ⇒ 按任务 XML 硬约束「不要改动实现，只提交它」，两条 🟡 一律**登记不修**（写进 `MINOR-DEFERRED.md`），未做任何「顺手修」。
2. **RED 态用「临时换文件 + 严格还原」而非另建沙箱仓**：为了让**同一条 `<verify>`**（`source flow-kit-bundle/…` 是仓库相对路径）真正跑到基线代码上。用 `trap restore EXIT` + 二次备份 + swap 前后 `sha256` 比对保证工作区安全；实测还原后 `sha256` 一致且 `git diff --numstat` 不变。
3. **`grep -c 'head -3'` 如实报 3 而非 0**：任务 XML 的期望值（0）是**可执行代码**口径，而字面 grep 会被 2 处 `head -30` 子串 + 1 处历史注释命中。未去「修正」源码来迎合期望值（那会删掉 TD-043 的病灶记录），而是**贴原文 + 去注释后给权威计数 0**。
4. **`<done>` 的历史实测值差异不改写 `<done>`**：改为在本 SUMMARY 如实披露（同 T02 对 `<action>` 的处置），并把「工件元数据陈旧」登记为 🟢 G-T04-4。
5. **未新增 bats 文件**：理由见「TDD 适用性说明」三条；已把「ADR 纳入段 0 bats 覆盖」登记为 🟢 G-T04-3 转 5-test。

## 是否触发新工作

- [ ] 触发新 fix-plan（未追加到 TASK.md）
- [ ] 触发 CONTEXT.md 更新（未更新）
- [ ] 发现需求/设计问题，已暂停并提交给人工
- [x] **登记 deferred**：2 🟡（`MINOR-DEFERRED.md` 的「阶段 4 · T04 六维自查 🟡 登记」段）+ 2 🟢（G-T04-3 转 5-test / G-T04-4 元数据陈旧）

## 完成判定

- TASK.md 中对应任务已勾选：**是**（`<task id="T04" … status="done">`）
- 提交 hash：`<commit-sha>`（见下「提交路径与 sha 自指说明」）
- `.flow-active` 的 `goal.task_progress` 已追加（五字段 · `jq … > .flow-active.tmp && mv` 原子写入）

### 提交路径与 sha 自指说明

- 提交走**标准 `git commit`**，**未**使用 `--no-verify` 或任何绕过写法；pre-commit 真跑 `make test` 并 **✅ 全绿（rc=0）**。
- **提交内容不可能写下自己的最终 sha**（`git commit` 之后才知道）。故权威源 = `.flow-active.goal.task_progress[]` 中 `id="T04"` 的 `commit_sha` 字段；
  本 SUMMARY 内的 sha 位置以 `<commit-sha>` 占位（与 T01/T03 的同类说明一致 —— 见 `MINOR-DEFERRED.md` 的 T01 行）。
