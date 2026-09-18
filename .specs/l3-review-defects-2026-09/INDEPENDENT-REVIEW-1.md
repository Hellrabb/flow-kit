# 独立审查 · 阶段 1

## L2 盲审

**审查对象**：`.specs/l3-review-defects-2026-09/REQUIREMENT.md`（参考 `CHANGE.md`）
**审查员**：L2 独立盲审员（与作者零上下文共享）
**独立性声明**：输入未含主 agent 自评 / 草稿 / 辩护 / 前轮结论。未读取 `REVIEW.md`、复测报告、`git log` 正文；`.specs/archive/**/L3-review-defects-2026-09-18-retest.md` 与 `L3-review-defects-2026-09-17.md` 均未打开。全部事实性声明由本审查员在仓库内独立复算。
**复算环境**：HEAD `61c4bf8`；`npx bats` 1.13.0；`awk/jq/shellcheck` 均在位。

---

### 独立复算结果（先给证据，后给发现）

| REQUIREMENT.md 声明 | 独立复算命令 | 实测 | 判定 |
|---|---|---|---|
| AC-2 `.specs/` 下 222 份 `INDEPENDENT-REVIEW-*.md` | `find .specs -name 'INDEPENDENT-REVIEW-*.md' \| wc -l` | 222（其中 0 份在 archive 外，与「假设：本 change 期间不变」一致） | ✅ |
| AC-2 零非枚举 / 零意外空值 | 逐份 `source l2-detect.sh; fk_extract_l2_verdict` | pass=152 / fail=70 / 空=0 / 非枚举=0 | ✅ |
| AC-6 `l3-api.sh ≤ 250` 且 `l3-section.sh` 新增 | `wc -l` | `l3-api.sh`=249、`l3-section.sh`=88 | ✅ |
| AC-6 四处写明「单位=字节」+「CJK ÷3」 | 逐文件 grep 三项 | README / dsh-flow-kit/README / `hooks/config/stop-hook.json` / `.claude/l3.env.example` **四处全部命中** | ✅（但见 R2，测试只断言 3 处） |
| AC-10 6 处 hooks 副本 | `sync-hooks.sh --list` 的 `DEST_ROOTS` + 逐目录 `[ -d ]` | 6 处全部存在，47 个镜像文件 | ✅ |
| AC-10 `--check` 退出 0 / 漂移 0 | `./sync-hooks.sh --check` | 6/6 ✅、`漂移 0`、exit 0 | ✅ |
| AC-10 断言非恒真 | 读 `B5-R4` 用例 | 删除单个副本后断言失败（真漂移可被拦） | ✅ |
| AC-11 全量 bats 0 fail / 854 例 | `npx bats test/` | 854 例全绿，exit 0 | ✅ |
| §B1 复现从 `PASS` 变 `fail` | 手工构造 5 行工件 | `fail` | ✅ |
| AC-8 「41 条目目录」 | 全仓 `ls -A` 扫描 | **无任何真实目录为 41 条目**（最大 < 38；本 change 归档目录仅 5 条目） | ⚠️ 场景为测试合成，非实测目录 |

---

### 🔴 R1 · L2 结论提取跨段越界：L3 段内的非围栏 verdict 行会顶掉 L2 结论

**Severity**：🔴 Critical
**Symptom（症状）**：`flow-kit-bundle/hooks/stop/lib/l2-detect.sh:56-58` 的三层提取策略全部**在整份文件上做「取最后一处」**，从未按 `^## L2 盲审` / `^## L3 ` 划定 L2 段边界；唯一附加过滤是 `grep -vE '^[[:space:]]*"'`（排除引号开头的 JSON 键行）。实测反例（两段式工件，L2 段 `**Verdict**: fail`，L3 段 JSON 为 `"verdict":"pass"`，L3 正文另有一行 `Verdict: PASS`）：

```
$ fk_extract_l2_verdict /tmp/l2probe/lafter.md
pass          # L2 段写的是 fail
```

在本仓 222 份真实工件上复算：含 L3 段的 97 份中，**22 份**的「整份文件 → 取最后一处」结果与其「L3 段之前 → 取最后一处」结果不同；其中 **5 份是方向翻转**（L2 段结论 `fail`、函数返回 `pass`）：
`archive/2026-07-21-gate-review-fix/INDEPENDENT-REVIEW-3.md`（L2:108 `**Verdict**: fail`；L3:282 `**Verdict**: pass`）、`archive/l2-l3-test-defect/INDEPENDENT-REVIEW-1.md`（L2:185 `fail`；:468/:944 另有 pass）、同名 `INDEPENDENT-REVIEW-2.md`、`archive/l2-l3-granular-gate/INDEPENDENT-REVIEW-1.md`、`archive/2026-07-11-health-fix-l3-2026-07/INDEPENDENT-REVIEW-6.md`。另有 17 份的 L3 段内存在可被第①层匹配的 verdict 行。
**Source（源头）**：REQUIREMENT.md US-1「让阶段门禁从工件里**稳定**读出 **L2 的**结论」；AC-1 的 Then 只覆盖「L3 段是 JSON」这一种形态。`L2-blind-review.md:141`「主 agent 无权修改你的原文判断」所依赖的前提是「工件里 L2 结论可被正确复现」；ADR-010 段的载体是 `## L3 (盲审|重审)` 标题——即**段边界在本项目里本就是一等概念**，`_l3_strip_sections` 已按标题精确切分（`l3-section.sh:21,27`），提取侧却未同构处理。
**Consequence（后果）**：§B1 的故障形态（L3 改写 L2 结论）被**缩小**而非**消除**。L3 审查员用与 L2 相同的 `**Verdict**: x` 模板复述结论是自然行为——语料里 97/97 份「最后一个 `verdict:` 行」都落在 L3 段内，说明这不是假想。后果链：`.done` 的 `L2_verdict` 与工件 L2 段**互相矛盾**（`done-validation.sh:149-152` 的 T4 只比对两者相等，不判断哪一个对）→ 审计证据失真；`l2_detect_missing()` 仅 `grep '^## L2 盲审'` 判存在，不校验提取值，因此**永远无法察觉**。爆点：下一份 L3 载荷含非 JSON verdict 行即触发；本项目 2026-07 起的历史工件已命中 5 份。
**Remedy（修补）**：把第①层从「整份文件取最后一处」改为「**先切 L2 段，再在段内取最后一处**」（与 `l3-section.sh` 的段切分同构；无 `^## L2` 的历史工件再退回现状）：

```bash
# before (l2-detect.sh:56)
verdict=$(grep -E '^[[:space:]]*([-*+][[:space:]]+)*#*[[:space:]]*\**[[:space:]]*[Vv][Ee][Rr][Dd][Ii][Cc][Tt][[:space:]]*\**[[:space:]]*[:：]' "$review_md" \
  | grep -vE '^[[:space:]]*"' | tail -1 | grep -ioE 'pass|fail' | tail -1) || true

# after：先 awk 出 [首个 ^## L2 … 下一个 ^## 之前] 的 L2 段，再在段内匹配
l2_scope=$(awk '/^## L2/{f=1} f&&/^## /&&!/^## L2/{exit} f' "$review_md" 2>/dev/null) || true
[ -n "$l2_scope" ] || l2_scope=$(cat "$review_md")      # 无 L2 段 → 保持旧兜底
verdict=$(printf '%s\n' "$l2_scope" | grep -E '<同上锚定正则>' | grep -vE '^[[:space:]]*"' | tail -1 | grep -ioE 'pass|fail' | tail -1) || true
```

并补 AC-1 用例：L2 段 `fail` + L3 段正文（非围栏）`Verdict: PASS` → 断言 `fail`。

---

### 🟡 R2 · AC-6 的「四处均写明」只被测试断言一半

**Severity**：🟡 Important
**Symptom（症状）**：`test/test_l3_review_defects_2026_09.bats:300-313`（`B3-R5`/`B3-R6`）实际断言的是：`hooks/config/stop-hook.json` 与 `dsh-flow-kit/README.md` 仅 `grep -q 'max_artifact_bytes'`（**键名**），只有 `.claude/l3.env.example` 与 `README.md` 另加 `单位=字节` 断言。REQUIREMENT.md:70-71 的 AC-6 Then 要求「四处**均**写明『单位=字节』与 CJK ÷3」——即键名存在 ≠ 单位说明存在，两条断言被合并掉了。本审查员实测四处**确实都写了**（见复算表），但**门禁抓不住将来把注释删掉的回归**。
**Source（源头）**：`L2-blind-review.md:85-89`「每条 AC 是否……**可机器验证**」；AC-6 自述的验证方式 `bats -f B3`。
**Consequence（后果）**：§B3 的缺陷本质是「**文档语义**与实现单位不符」，其修复的保护面就是文档。当前测试对两处文档只校验键名，任何人后续把 `> ⚠️ 单位是字节` 一行删掉，`make check` 仍全绿——本次修复最容易回退的那一半恰好无保护。
**Remedy（修补）**：`B3-R5`/`B3-R6` 各补两行，四处一视同仁：

```bash
for f in "$HOOKS/config/stop-hook.json" "$FK_ROOT/dsh-flow-kit/README.md" \
         "$FK_ROOT/README.md" "$FK_ROOT/.claude/l3.env.example"; do
  grep -q 'max_artifact_bytes' "$f"
  grep -qE '单位 ?= ?字节|单位=字节' "$f"
  grep -qE '÷3|÷ 3' "$f"
done
```

---

### 🟡 R3 · AC-1 未覆盖「提取失败」的下游语义，而这正是 US-1 的另一半

**Severity**：🟡 Important
**Symptom（症状）**：AC-1 的 Then 只规定「返回 `fail`」与「一律返回小写枚举」；AC-1 的 Given 也只给定含 verdict 的工件。无 verdict 行时的约定由 `B1-R7`（bats:128）间接固定为「空输出 + rc 1」。但 `29-independent-review.sh:266`（`|| true`）之后，空值会走到 `l3_review_run` 的 `^(pass|fail|skipped)$` 校验——`l3-review.sh:66` 对空值 `return 3`。REQUIREMENT.md 没有 AC 说明「提取为空时阶段门禁应如何表现」，`非功能性需求` 段也只提性能/兼容/可观测，未提该失败路径。
**Source（源头）**：US-1 的措辞是「**让阶段门禁**从工件里稳定读出 L2 的结论……把阶段推进和 commit 全锁死」——诉求对象是门禁行为，而非单函数返回值；`L2-blind-review.md:95-99`（阶段 1 checklist）要求检查「是否遗漏非功能性需求……可观测性」。
**Consequence（后果）**：§B1 的原始故障是「值非法 → L3 静默不跑 → 门禁全锁」。修完后换成「值取不到 → L3 同样 `return 3` → 门禁如何表现」这一条**未定义路径**。实测 222 份语料空值 0 例，说明当前不爆；但一旦某轮 L2 子 agent 用非模板写法（例如只给 JSON 不给 `**Verdict**`），行为就落到未定义区，且工件上同样「看不出原因」——与 US-1 抱怨的故障特征一致。
**Remedy（修补）**：在 AC 表加一条（或扩写 AC-1 的 Then）：

```
### AC-12 · 提取失败时的门禁语义已定义
- Given 一份含 `## L2 盲审` 段但不含任何 verdict 行的 INDEPENDENT-REVIEW-7.md
- When 29 号模块走完「提取 → l3_review_run」
- Then 在 stderr 打印含 "L2 verdict not found" 的显式告警；
       且 .done 的 L2_verdict 取已定义值（`skipped` 或按现有 best-effort 分支），
       不得静默 return 3 后门禁状态不明
- 验证方式: bats test/test_l3_review_defects_2026_09.bats -f "B1-R7b"
```

---

### 🟡 R4 · 「严格对齐 install_hooks.sh 的安装集」声明与实现不符，AC-10/§B5 的「单一源」跨文件一致性缺口

**Severity**：🟡 Important
**Symptom（症状）**：AC-10 的 Then 依赖 `./sync-hooks.sh --check` 覆盖全部安装面；REQUIREMENT.md:155-157「依赖与假设」把「`install_hooks.sh` 的安装文件集是 §B5 副本比对的**权威范围**」列为假设，`sync-hooks.sh:50` 的注释也自称「**严格对齐** install_hooks.sh 的安装集」。但实测两者机制不同：`install_hooks.sh:113-119` 按 **`HOOK_MODULE_NAMES` 显式数组**逐名安装 stop 模块，`sync-hooks.sh:53-57` 用 `"$SRC"/stop/*.sh` **通配**枚举。当前 `stop/` 下恰好 19 个 `.sh`（19 = `HOOK_MODULE_NAMES` 条目数，实测相等），因此漂移 0 成立；但**一旦 `stop/` 下出现不在 `HOOK_MODULE_NAMES` 里的脚本**（草稿、实验脚本、被移除模块的遗留），`sync-hooks.sh --check` 会去比对**安装器根本不会安装的文件**，且 `--check` 只报 `cmp` 失败/缺失二态，**不校验文件集本身**。
**Source（源头）**：L-031（`L2-blind-review.md:68-82`）——「不信清单，独立做全仓扫描」的同一类风险；本项即「同一契约（安装集）在两处以不同机制表达」。`common.sh:363` 与 `install_hooks.sh:114` 自己在注释里写「单一来源」，正说明该项目已把该清单当作契约看待。
**Consequence（后果）**：§B5 的缺陷是「源修了、副本没跟上」，其修复的保护面就是「副本 vs 源」的一致性。当前实现对**目录内容**漂移免疫力不对等：多出来的文件会被同步/报警（假阳性 → 噪音削 weakens 门禁），安装器新增模块若同时加了 lib 则被通配覆盖（无碍），但**安装集本身的收缩**（从数组删一个名字）不会被 `--check` 发现。噪音积累到一定程度后，`make check` 的 hooks 门禁会被当成橡皮章——重演 §B5 的失效模式。
**Remedy（修补）**：两选一，并同步 REQUIREMENT.md 的措辞：
(a) 让 `sync-hooks.sh` 通过与安装器同源的清单枚举 stop 模块：

```bash
# before (sync-hooks.sh:53)
for f in "$SRC"/stop/*.sh; do ... done
# after：与 install_hooks.sh 同源
source "$SCRIPT_DIR/flow-kit-bundle/hooks/stop/lib/common.sh" 2>/dev/null
for name in "${HOOK_MODULE_NAMES[@]}"; do printf 'stop/%s.sh\n' "$name"; done
```
(b) 若刻意保留通配（更能防「新增模块漏加」），则把 REQUIREMENT.md:155-157 的假设与 `sync-hooks.sh:10` 的「严格对齐」改为「stop 模块按目录通配枚举，lib 与 pre-tool-use 同安装器通配语义」，并在 `--check` 增加「源目录存在但不在 `HOOK_MODULE_NAMES` 的 stop 脚本 → 告警」。

---

### 🟢 R5 · AC-8 的「顶层 41 个条目」在真实仓库中无对应目录

**Severity**：🟢 Minor
**Symptom（症状）**：AC-8/AC-9 的 Given 写「顶层 **41** 个条目的 change 目录」，验证方式为 `bats -f B4`；`B4-R1`（bats:339-352）用 `_build_phase7_tree "$spec" 33` 合成目录（33 个 `FILE-xx.md` + 8 个标准产物 = 41 条目）。本审查员全仓扫描：**没有任何真实 change 目录达到 38 条目**（`.specs/archive/2026-09-18-l3-review-defects-2026-09/` 仅 5 条目）。即「41」这个数是测试合成值，AC 的 Given 读起来像实测目录。
**Source（源头）**：`L2-blind-review.md:85-89`（可机器验证）；本报告复算表最后一行。
**Consequence（后果）**：无功能后果（断言本身有效且已通过）。真实风险是**读者误判**：后续读者会以为仓库里存在一个 41 条目的阶段 7 change 可作为回归基准，进而据此推断「≥41 条目」是真实上界。§B4 的真实场景规模因此未被钉住。
**Remedy（修补）**：AC-8 的 Given 改为可复算的表述：

```
- **Given** 一个由测试合成的阶段 7 change 目录（33 个编号文件 + 8 个标准产物 = 41 条目；
  现实最大 change 目录条目数：见 5-test 实测）
```

---

## Checklist 逐项结论（阶段 1 + 通用 L-031）

| 检查项 | 结论 |
|---|---|
| 每条 AC Given/When/Then 三段齐全 | 11/11 齐全（AC-1~AC-11 均含三段 + 验证方式），无「系统应该正常工作」式空话 |
| 每条 AC 可机器验证 | 11/11 给出可执行命令；**R2** 指出 AC-6 的四处文档断言只落实 3 处 |
| v1/v2/out 切分合理、无范围蔓延 | ✅。v1=AC-1~11 全部由 §B1~§B5 报告条目直接映射；v2 三项（按字符截断 / 历史 `.done` 回溯 / exec 位）均带「为什么不是这次」；out 两项（L2 参与放行 / 另建 L3 载体）明确挂 ADR-010。AC-11 纳入「make check 五门」属回归保护而非蔓延 |
| 非功能性需求（性能/安全/可观测/容量/兼容） | 性能、可访问性、安全、兼容性、可观测性五项均有；**R3** 指出「提取失败的可观测性与门禁语义」缺失 |
| 需求内部矛盾 / 歧义 | 未发现硬矛盾。AC-1（L2 在前）与非功能「兼容 Gen-1（L3 段在前）」是不同工件形态，不冲突；AC-6（新键）与 AC-7（旧键）优先级由 AC-6 的解析链明确 |
| **L-031 跨文件一致性扫描**（锚点 `fk_extract_l2_verdict` / `L3_SECTION_END_MARKER` / `max_artifact_*` / `FLOW_KIT_L3_MAX_ARTIFACT_*` / `l3-section.sh` / `HOOK_MODULE_NAMES`） | `fk_extract_l2_verdict`：4 个消费者（`gate-checks-review.sh:24`、`29-independent-review.sh:266`、`l3-review.sh:235`、`done-validation.sh:152`）与 l2-detect.sh:31 注释「4 consumers (4 files)」一致，无漏改。标记字面量唯一定义于 `l3-section.sh:25`，`l3-api.sh:192` + `l3-done.sh:107,140` 引用，与 B2-R5 断言一致。`max_artifact_bytes` 四个文档载体全部同步（复算表）。`l3-section.sh` 被 `l3-review.sh:40` 与 `l3-done.sh:18` source，安装面由 `install_hooks.sh` 的 `stop/lib/*.sh` 通配覆盖。**唯一缺口 = R4（安装集枚举机制不一致）**，不构成漏改（当前 19=19），但属 L-031 同类 |
| 事实性声明可核实性 | 9/10 项独立复算通过；1 项（AC-8 的 41 条目）无真实对应物（R5） |

---

**Verdict**: fail

> 复算全程只读；反例工件建在临时目录 `/tmp/l2probe/` 并已清理。本文件是该目录在本次审查中唯一的写入。旁证：审查期间 `.specs/CONTEXT.md` 被本机 hook 改动（`git diff --stat` = 13 insertions），非本审查员所为，也未见 REQUIREMENT.md/CHANGE.md 声明其纳入范围。

---

## 主 agent 响应（L2 盲审 · 阶段 1）

> 按 L2 契约：本段是**追加**的回应，不改写上方审查员的原文判断。
> 复算环境：HEAD `61c4bf8` + 本次未提交的修复；`npx bats`、`awk`/`grep` 均在位。

**先记一条审查员自己的旁注**：报告末尾提到「审查期间 `.specs/CONTEXT.md` 被本机 hook
改动（13 insertions），非本审查员所为」——那是主 agent 在本轮按 1-requirement 职责
追加域语言与已锁决策所致，属预期写入，不是外来污染。审查员对"工件在脚下变动"的警觉是对的。

### R1 · 🔴 Critical —— **部分成立：结构性缺口成立，但引证据不成立；已按修正后的方案修复**

**主 agent 反驳（证据部分）**：报告称"5 份历史工件方向翻转、L3 段 verdict 顶掉 L2 结论"。
逐份复算后**不成立**——那 5 份的第二个 verdict 行都在 **L2 层自己的后续轮次**里：

```
2026-07-21-gate-review-fix/IR-3   L108 [## L2 盲审] fail → L282 [## L2 盲审（复审）] pass
l2-l3-test-defect/IR-1            L185 [## L2 盲审] fail → L468 [## L2 重审] pass
                                  → L767 [## L2 三审] fail → L944 [## L2 四审] pass
l2-l3-test-defect/IR-2            L127 [## L2 盲审] fail → L230 [## L2 二审] pass
l2-l3-granular-gate/IR-1          无任何锚定 verdict 行
2026-07-11-health-fix-l3/IR-6     无任何锚定 verdict 行
```

即"取最后一处"取到的是**最新一轮 L2 复审**的结论，是正确行为，不是被 L3 顶掉。
报告把 `## L2 盲审（复审）` / `## L2 重审` / `## L2 二审` 误判为 L3 段。

**但结构性缺口成立**（这是报告的真实价值）：修复前只靠「排除引号开头的行」免疫 L3 段，
属**形态免疫**而非**边界免疫**。报告自己构造的反例（L3 段内一行**非围栏**的行首
`Verdict: pass`）确实能把 `fail` 顶成 `pass` —— 已复现。该场景的真实触发路径是
**模型把 JSON 包在 ``` 里导致围栏提前闭合**，其后一行即落到围栏外。

- **Fixed in:** `flow-kit-bundle/hooks/stop/lib/l2-detect.sh`
  - 新增 `_fk_l2_scope()`：按块排除 `^## L3 ` 与 `^## 主 agent` 两类块，保留全部 L2 轮次
  - 三层提取（锚定 / 标题 / 兜底）全部改为在 L2 层文本内执行
- **修正报告的建议写法**：报告给的 `awk '/^## L2/{f=1} f&&/^## /&&!/^## L2/{exit} f'`
  （"从首个 `## L2` 起到下一个 `## ` 止"）**会引入新回归**，实测两类真实形态被腰斩：
  (a) L2 报告自身含二级子标题（如 `## 与主 agent REVIEW.md 的对照`，Verdict 在该段内）；
  (b) 多轮 L2 与主 agent 响应交替（L2 → 响应 → L2 复审 → 响应 → L2 三审），
  在首个响应处截断会取到过期结论（4 份工件受影响）。故改用「按块排除」而非「按段截取」。
- **语料影响（223 份）**：结果变化 **8 份**，全部为「原本从 L3 段/主 agent 自审段漏出的值」
  → 变为空值。逐份核实：7 份的 `## L2 盲审` 段内**零个** verdict token（值全部来自 L3 段
  或 `## 主 agent 自审（L2 unavailable）` 段），1 份（`gate-integrity/IR-1`）的 verdict
  是**表格形态**（`| 轮 | Verdict |`）任何层都无法解析。即**这 8 份的"空"才是诚实答案**，
  且下游 4 个消费点对空值均回落 `fail`（不阻塞）。
- **新增回归**：`B1-R9`~`B1-R14`（L3 非围栏行 / 主 agent 段 / 交替多轮 / L2 子标题 /
  仅 L3 段 / `_fk_l2_scope` 本身）

### R2 · 🟡 Important —— **接受**

- **Fixed in:** `test/test_l3_review_defects_2026_09.bats`
  - 原 `B3-R5`/`B3-R6` 合并为 `B3-R5`：对**四个载体**（`stop-hook.json`、`l3.env.example`、
    `README.md`、`dsh-flow-kit/README.md`）逐一断言「键名 + 单位=字节 + CJK ÷3」三条，
    不再有任何一处只查键名
  - 新增 `B3-R5b`：`package-flow-kit.sh` 收尾横幅（第五处载体）同样三条断言
- 报告指出的"最容易回退的那一半恰好无保护"判断正确 —— 这确实是本次修复保护面的缺口。

### R3 · 🟡 Important —— **接受**

- **Fixed in:** `flow-kit-bundle/hooks/stop/29-independent-review.sh`
  - 提取为空时由 `[ -n ... ] &&` 的静默写法改为显式 `else` 分支：
    向 stderr 打印含 `L2 verdict not found` 的告警 + `module_output "warning"` 上报
  - 取值仍为保守 `fail`（合法枚举，不触发 `l3_review_run` 值域闸）→ 不造成"锁死且看不出原因"
- **Fixed in:** `REQUIREMENT.md` 新增 **AC-12**（提取失败时门禁语义已定义且可见）
- **Fixed in:** 新增回归 `B1-R15`
- 报告指出"US-1 的诉求对象是门禁行为而非单函数返回值"——这个读法准确，AC-12 即据此补的。

### R4 · 🟡 Important —— **接受（取 (a) + (b) 的告警部分）**

- **Fixed in:** `sync-hooks.sh`
  - `collect_rel_paths()` 的 stop 模块枚举从 `"$SRC"/stop/*.sh` 通配改为**与安装器同源**：
    `bash -c 'source .../common.sh; printf "%s\n" "${HOOK_MODULE_NAMES[@]}"'`；
    `common.sh` 取不到清单时退回通配（宁可多比对，不可漏比对）
  - 新增 `collect_stop_extras()`：`stop/` 下存在但不在 `HOOK_MODULE_NAMES` 的脚本
    在报告头显式告警（"安装集本身漂移"的信号必须可见）
- 报告对"通配 vs 清单"两种机制差异的指认准确：实测当前 18 = 18 故漂移 0 成立，
  但安装集收缩不会被发现。现在同源 + 反向告警，两个方向都可发现。
- **未采纳报告建议的 `sync-hooks.sh:10` 注释改法**：改成同源枚举后，
  "严格对齐 install_hooks.sh 的安装集"这句注释**变成真的了**，无需改写。

### R5 · 🟢 Minor —— **Tech-debt（已登记）**

- 按 severity gating 协议不入 fix loop。
- **Tech-debt:** 已登记于 `.specs/l3-review-defects-2026-09/MINOR-DEFERRED.md` M1，
  phase 7-integration 由用户 triage。
- 说明：AC-8 的 Given 在本次修订 R1/R2/R3 时已顺带改写为「由测试合成（33 + 8 = 41）」，
  但**未**为其新增断言（Minor 不扩测试面）。

---

### 修复后复算

| 项 | 结果 |
|---|---|
| 报告 R1 合成反例 | `fk_extract_l2_verdict` → `fail`（修复前 `pass`）✅ |
| 语料 223 份 | 非枚举 0；空值 8（全部可归因，见 R1）✅ |
| 回归套件 | `test_l3_review_defects_2026_09.bats` 35 例全绿 ✅ |
| hooks 副本漂移 | 6/6 漂移 0 ✅ |
| 全量 bats | 见 5-test |

---

## L2 盲审（复审）

**审查对象**：`.specs/l3-review-defects-2026-09/REQUIREMENT.md`（参考 `CHANGE.md`）
**审查员**：L2 独立盲审员 · 第 2 轮复审 · 阶段 1（1-requirement）
**独立性声明**：本次输入含前轮审查原文与「## 主 agent 响应」段。按调用方指令，二者均为**待复核对象**而非权威；我没有采信其中任何一条陈述，全部结论由本轮在仓库内实跑/复算得出（命令与输出见下表与各 R 条）。未打开 `REVIEW.md`、`.specs/archive/**/L3-review-defects-2026-09-18-retest.md`、`git log` 正文。反例与探针均建在 `/tmp/l2r2/`；本文件本次唯一的写入是本段。
**复算环境**：HEAD `61c4bf8` + 工作区未提交修复（`git status` 8 项 M）；`npx bats` 1.13.0；`awk/jq/shellcheck` 在位。

### 本轮独立复算结果（先证据）

| 被复算的声明 | 我的复算方式 | 实测 | 判定 |
|---|---|---|---|
| AC-1「限定 L2 层」：L3 段内**非围栏**行首 `Verdict:` 不再顶掉 L2 | 合成两段式工件（L2 `fail` + L3 正文 `**Verdict**: pass`），直调 `fk_extract_l2_verdict` | `fail` | ✅（该形态已修） |
| AC-1 补充约束：L3 段内**含二级标题**时仍限定 L2 层 | 同上 + L3 正文插一行 `## 附录：发现明细` | **`pass`**（L2 段写的是 `fail`） | ❌ **见 R1** |
| AC-1 补充约束：多轮 L2 与 `## 主 agent 响应` 交替 → 取最后一轮 L2 | 合成 5 段交替工件（L2 fail → 响应 → L2 二审 fail → 响应 → L2 三审 pass） | `pass`（三审） | ✅ |
| AC-1 补充约束：仅含 L3 段的工件必须返回空 | 合成仅 L3 工件 | 空 | ✅ |
| AC-2：语料只产出合法枚举、空值 ≤ 8 且可归因 | 对 `find .specs -name 'INDEPENDENT-REVIEW-*.md'` 223 份逐份调用（新/旧实现各跑一遍） | 新：`pass=148 fail=67 空=8 非枚举=0`；旧：`pass=152 fail=71 空=0`；差异恰 8 份且全部「有值→空」 | ✅ |
| AC-2：8 份空值「L2 段本无 verdict」 | 逐份打印 `^## ` 标题 + 段内 `verdict` token + 旧实现命中的真实行号 | 6 份旧值来自 **L3 段**（5 份 L3 JSON 的 `"verdict"` + 1 份 L3 段内 `> **Verdict: fail**`），2 份来自 `## 主 agent 自审/复判` 段；8 份的 L2 段（或「无 L2 段」）确实零 verdict token | ✅ 归因与 REQUIREMENT.md:48-52 一致 |
| AC-12：告警真实存在且可达 | 自建 stub 树实跑 `29-independent-review.sh`（stub `l3_review_run` 打印实参；`## L2 盲审` 段无 verdict） | stderr：`[independent-review] L2 verdict not found in …`；`l3_review_run` 收到 `l2_verdict=[fail]`；`module_output warning\|IR\|L2 verdict not found` 落盘 | ✅ **可达且行为正确** |
| AC-12：对照路径不误报 | 同 harness 跑 3 个对照：①L2 段有 verdict ②无 `## L2 盲审` 段 ③gate=L3 | ①`l2_verdict=[pass]` 无告警 ②走 L2-未完成分支 ③告警 + `l2_verdict=[fail]` | ✅ |
| AC-12 的**验证方式**（`bats -f B1-R15`）能否验证上述 Then | 读 `test_l3_review_defects_2026_09.bats:225-233` | 仅 3 条对 `$H29` 源码的 `grep`，不构造 Given 工件、不运行模块、不读 stderr | ❌ **见 R2** |
| AC-6：四处载体「键名 + 单位=字节 + ÷3」 | 对 4 个载体逐文件跑 3 条 grep（不看测试结论） | 4/4 三项全 Y；`package-flow-kit.sh`（第 5 处，B3-R5b）同样三项全 Y | ✅ |
| AC-10：`sync-hooks.sh` 的 stop 枚举与安装器同源 | 读 `sync-hooks.sh:54-94` + 用**改过的** `common.sh`（清单 18→17）在临时 HOME 下实测镜像数 | 47 = 18 stop + 19 lib + 7 pre-tool-use + 2 session-start + 1 pre-commit；清单删 1 名后镜像数 47→46 | ✅ 真同源 |
| AC-10：`install_hooks.sh` 回退清单与 `common.sh` 一致 | 抽取两处清单逐项 diff | 18 = 18，逐项相同 | ✅（前轮 R4 的「19 = 19」计数有误，主 agent 的「18 = 18」正确） |
| AC-10：反向断言非恒真 | 临时 HOME 下删掉一个**副本**文件后跑 `--check` | 退出码 1 | ✅ |
| AC-11：`l3-api.sh ≤ 250` / 双源一致 | `wc -l`；`diff` | 249 行；`test/` 与 `flow-kit-bundle/test/` 逐字节相同 | ✅ |
| AC-11：全量 bats 不退化 | `npx bats test/` | 861 例，exit 0（上轮 854 + 本轮新增 B1-R9~R15 共 7 例） | ✅ |

### 🔴 R1 · AC-1「限定 L2 层」在生产写入路径下仍可被 L3 顶掉：L3 段内一行二级标题即重新纳入 L3 正文

**Severity**：🔴 Critical
**Symptom（症状）**：`flow-kit-bundle/hooks/stop/lib/l2-detect.sh:44-52` 的 `_fk_l2_scope` 用「遇到任何 `^## ` 就复位 `skip`」判定块结束。L3 段正文里只要出现一行行首 `## `（模型返回多行 markdown 的常见形态），该行就会把 `skip` 复位，其后 L3 正文（含行首 `Verdict:` 行）全部进入「L2 层」，被第 ② 层 `tail -1` 采信。**用生产写入函数复现**（不是手写工件）：

```
$ printf '# IR-1\n\n## L2 盲审\n\n**Verdict**: fail\n' > $d/INDEPENDENT-REVIEW-1.md
$ printf -v payload '{"critical":[],"verdict":"pass","summary":"模型自由发挥"}\n## 附录：发现明细\n**Verdict**: pass'
$ source flow-kit-bundle/hooks/stop/lib/l3-review.sh; _l3_parse_result "$payload" 1 "$d" model-x
$ source flow-kit-bundle/hooks/stop/lib/l2-detect.sh; fk_extract_l2_verdict "$d/INDEPENDENT-REVIEW-1.md"
pass            # 工件 L2 段写的是 fail
```

写入后的工件尾部（`_l3_parse_result` 实际产出）：
`## L3 重审（model-x 外部模型 · …）` → `### 审查结论` → ` ```json ` → 载荷（含 `## 附录：发现明细` / `**Verdict**: pass`）→ ` ``` ` → `L3_artifact_hash:` → `<!-- /L3-SECTION -->`。
同目录 `l3-section.sh:35-45` 的**删除侧**对同一形态的处理完全相反，注释原文：「段终点：段内首个 `<!-- /L3-SECTION -->` 行（**不因载荷里的行首 '## ' 提前放弃**）」，实现里还专门向下扫描标记、只在与「下一段 L3 / 回到 L2 段」相撞时才回落标题法。即：同一 change 的 §B2 修好了「截断点错位」，§B1 的消费侧却仍在用被 §B2 否决的那套启发式。
**Source（源头）**：AC-1（REQUIREMENT.md:26-41）承诺「限定 L2 层」且其 **Given 只要求 L3 段是 JSON + 一行非围栏 `Verdict:`，并未排除 L3 段内出现二级标题** —— 本反例完全满足 Given 而 Then 不成立（AC 合规失败）。旁证：`l3-section.sh:6-7` 明确写了「L3 载荷里一旦出现行首 `## `（模型返回多行 markdown 时很常见）」；B2-R1/B2-R6 正是用带行首 `## ` 的载荷构造用例，说明这是本项目自认的真实形态。L-031 同类：同一契约（L3 段边界）在 `l3-section.sh` 与 `l2-detect.sh` 两处以不同机制表达，而本 change 刚引入的 `<!-- /L3-SECTION -->` 只有一侧消费。
**Consequence（后果）**：§B1 的故障形态在**新格式工件**（每个 L3 段都带标记）上仍可触发，且爆炸半径与原缺陷同级：`29-independent-review.sh:266` 把该值写进 `.done` 的 `L2_verdict`；`done-validation.sh:152` 的 T4 只比对 `.done` 与工件相等、不判断谁对；`gate-checks-review.sh:24` 用它决定是否放行——审计记录会写着「L2 通过」而工件 L2 段写着 `fail`，L2 契约（`L2-blind-review.md:142`「主 agent 无权修改你的原文判断」）失去可复现前提。触发窗口就是 L3 写盘之后到下一次重写之前，正是主 agent 要过 gate 的时刻。现有 223 份语料**尚未**出现取值被翻转的实例（语料中无一份带结束标记，新格式路径未被覆盖），但这是「还没跑到」而非「跑不到」。
**Remedy（修补）**：
1. **删掉自创启发式，与 `l3-section.sh` 同源**（首选，同时闭合 L-031）：在 `l3-section.sh` 暴露一个段区间函数（复用 `_l3_strip_sections` 已有的「先向前扫标记、无标记才回落标题法」逻辑）：

```bash
# l3-section.sh 新增（与 _l3_strip_sections 同一判定，单一来源）
#   _l3_section_spans <file>  → 每行输出 "<start> <end>"（L3 段区间）
# l2-detect.sh:44 _fk_l2_scope 改为按 spans 排除，而不是 /^## / 复位：
#   before: awk '/^## L3 /{skip=1;...} /^## /{skip=0} skip{next} {print}'
#   after : 先把 spans 标成 deleted[] 再 print（与 _l3_strip_sections 的 del[] 同构）
```

2. 无标记的历史工件（当前语料 223/223）保留原有标题法兜底，行为不变（我实测的 8 份空值与 148/67 分布不会因此改变）。
3. **AC-1 补一条补充约束**（否则测试作者仍会漏）：「L3 段内出现行首 `## ` 二级标题时，L3 正文不得进入 L2 层；`## L3 ` 段以 `<!-- /L3-SECTION -->` 为终点」。
4. 补一条 B1 用例，**用 `_l3_parse_result` 真实写入**（照抄 B2-R6 的驱动方式）后断言 `fk_extract_l2_verdict` = `fail`；当前 B1-R9（无内部标题）与 B2-R1/R6（有内部标题但 L3 侧无 anchored verdict 行）**都不覆盖这个组合**，所以整套 861 例全绿也发现不了。

### 🟡 R2 · AC-12 的验证方式不验证 AC-12：`B1-R15` 是源码字符串 grep，第 2 条断言恒真

**Severity**：🟡 Important
**Symptom（症状）**：`test/test_l3_review_defects_2026_09.bats:225-233` 的 `B1-R15` 只做三件事：`grep -q 'L2 verdict not found' "$H29"`、`grep -qE 'l2_verdict="fail"' "$H29"`、`grep -q 'l2v_extracted' "$H29"`。它不构造 AC-12 的 Given 工件、不运行 29 号模块、不检查 stderr、也不检查传给 `l3_review_run` 的值。其中第 2 条 grep 命中的是 `29-independent-review.sh:264` 的**默认赋值** `l2_verdict="fail"  # 默认 fail（保守…）`——该行位于 `if/else` 之外，与「提取为空时的取值」无关，因此这条断言对任何实现都成立（恒真成分）；第 3 条只断言变量名存在。换言之：把 else 分支的行为改成别的东西（只要保留那句告警文本），用例仍绿。
**Source（源头）**：`L2-blind-review.md:85-89` 阶段 1 checklist「每条 AC 是否……**可机器验证**」；AC-12 自述 `验证方式: bats … -f "B1-R15"`。反面对照：同一套件的 B1-R1~R13 都是**行为断言**（构造工件 → 调函数 → 断言返回值），AC-12 是唯一退化成文本断言的 AC。
**Consequence（后果）**：AC-12 的三条 Then 中，只有「告警文本存在」被弱保护，「提取为空时不得静默降级」与「传给 `l3_review_run` 的值仍为合法枚举」无任何门禁。行为本身目前是**对的**（本轮已实跑证明，见复算表），但下一次重构（例如把告警改成 `module_output` 单通道、或把 else 分支并入 `awk` 侧）可以静默把 §B1 的故障形态带回来而 `make check` 全绿。
**Remedy（修补）**：把 `B1-R15` 改成行为用例，harness 我已跑通（`HOOK_BASE_DIR` 指向 stub 树、`l3-review.sh` 用 stub 覆盖、`PROJECT_ROOT`/`CONFIG_FILE`/`FLOW_KIT_L3_MODEL` 注入即可）：

```bash
@test "B1-R15: 提取为空 → stderr 告警 + l3_review_run 收到合法枚举" {
  # stub: l3_review_run(){ echo "L2V=[$4]" >> "$STUB_LOG"; }
  printf '# IR\n\n## L2 盲审\n\n正文无 verdict\n' > "$spec/INDEPENDENT-REVIEW-1.md"
  run env HOOK_BASE_DIR=... PROJECT_ROOT=... bash "$stub/stop/29-independent-review.sh"
  [[ "$output" == *"L2 verdict not found"* ]]      # Then 1
  grep -q 'L2V=\[fail\]' "$STUB_LOG"               # Then 2（实参，不是源码文本）
}
```
（或在 AC-12 的验证方式里并列写上这条 bats 用例 + 本轮这段 stub harness 的最小复现步骤。）

### 🟢 R3 · AC-2 对第 4 个消费点的描述与实现不符：`done-validation` 对空值是放行而非「回落 fail」

**Severity**：🟢 Minor
**Symptom（症状）**：REQUIREMENT.md:51 写「下游 4 个消费点对空值**均回落 `fail`**（不阻塞）」。实测 3 个成立（`gate-checks-review.sh:24-25` 与 `l3-review.sh:236-237` 显式 `[ -n ] || =fail`；`29-independent-review.sh:264-274` 保持 `fail` 并告警），第 4 个不成立：`done-validation.sh:152-153` 是 `[[ -z "$md_v" || "$md_v" == "$l2v" ]] || return 2` —— 空值走 best-effort **直接放过** T4 比对，并不取 `fail`。AC-2 的括注「不阻塞」是对的，「均回落 fail」这一半是错的。
**Source（源头）**：`L2-blind-review.md:85-89`（AC 的可验证性＝描述必须与实现同构）；T4 的注释自述语义是「提取不到 verdict **不挡**（best-effort）」。
**Consequence（后果）**：无阻塞性后果——这 8 份都在 `archive/` 且已归档，且修复前 `.done` 的 `L2_verdict` 与工件值同源（同样取自 L3），T4 本来也不会报警，故安全语义无净变化。真实风险是**下游读者/测试作者被误导**：按 AC-2 字面写一条「空值 → done-validation 返回 2」的断言会失败。
**Remedy（修补）**：REQUIREMENT.md:51 改为「下游 4 个消费点对空值均**不阻塞**：3 处回落 `fail`，`done-validation` 的 T4 走既有 best-effort 放行（不比对）」。

### 🟢 R4 · 范围切分未随 AC-12 更新：v1 仍写「AC-1 ~ AC-11」，AC-12 落在 v1/v2/out 之外

**Severity**：🟢 Minor
**Symptom（症状）**：REQUIREMENT.md:143「**v1（本次必做）** - AC-1 ~ AC-11 全部。」而 AC 表已含 AC-12（REQUIREMENT.md:124-135，由前轮 R3 追加）。v2（:147-152）与 out（:156-159）也未提 AC-12。同一文件内「AC 数量」与「范围声明」不一致。
**Source（源头）**：REQUIREMENT.md:187「AC 是 TEST 阶段派生用例的**唯一来源**」——范围声明是 5-test 建测试矩阵时的输入，声明缺项会让 AC-12 在覆盖矩阵里失去归属。
**Consequence（后果）**：无功能后果（B1-R15 已存在），但 5-test/6-review/7-integration 的读者按「v1 = AC-1~11」理解时，AC-12 会成为无归属条目；若后续有人按范围声明裁剪用例，AC-12 可能被当作越界项剔除。
**Remedy（修补）**：REQUIREMENT.md:143 改为「AC-1 ~ AC-12 全部（AC-12 为 2026-09-18 依 L2 R3 追加）」。

### 🟢 R5 · AC-1 的验证方式计数失准：`bats -f B1` 现为 15 例，AC 写 14 例

**Severity**：🟢 Minor
**Symptom（症状）**：REQUIREMENT.md:41「验证方式: `bats test/test_l3_review_defects_2026_09.bats -f B1`（14 例）」。本轮实跑同一命令：`ok 1 … ok 15`，共 **15** 例（AC-12 的 `B1-R15` 加入后未同步该计数）。
**Source（源头）**：`L2-blind-review.md:85-89`（可机器验证的 AC 应给出可复算的数字）；同类问题前轮 R5 已就 AC-8 的 Given 计数字面量提出过。
**Consequence（后果）**：读者用 14 去核对时会对不上；无功能后果。
**Remedy（修补）**：改为「（15 例：B1-R1 ~ B1-R15）」，或删除计数只留 filter（计数会随 AC 增加继续漂移）。

### 🟢 R6 · AC-10 的「安装集收缩」只可见不拦截，且副本侧残留反向不可见（前轮 R4 只落了一半）

**Severity**：🟢 Minor
**Symptom（症状）**：`sync-hooks.sh:85-94` 的 `collect_stop_extras()` 只在报告头 `printf` 一条横幅（:105-108），不参与 `root_fail`，因此 `--check` 仍 `exit 0`。临时 HOME 下实测：①`stop/` 多一个不在清单里的脚本 → 横幅 + `exit 0`；②把 `99-report` 从 `HOOK_MODULE_NAMES` 删掉（源文件仍在）→ 横幅「1 个脚本不在 HOOK_MODULE_NAMES 中」+ `exit 0`；③清单删名 **且** 源文件删除（副本残留 `99-report.sh`）→ **无任何提示、`exit 0`**，残留副本从此永久逃出漂移检测。
**Source（源头）**：L-031（「同一契约两处不同机制表达」的收口标准）；前轮 R4 Remedy (a)+(b) 的 (b) 明确要求「在 `--check` 增加『源目录存在但不在 `HOOK_MODULE_NAMES` 的 stop 脚本 → 告警』」——告警已做，但未与退出码挂钩；场景③是枚举方向本身决定的盲区（源驱动的枚举无法看见副本独有文件）。
**Consequence（后果）**：AC-10 的 Then（缺失副本 → 非零退出）**已满足且非恒真**（场景 D2 实测 exit 1），所以这不是 AC 缺口。残留副本本身是惰性的（模块已从 `HOOK_MODULE_NAMES` 移除即不在 Stop 链上执行），因此不是安全回归；真实风险是「安装集收缩」这类治理动作在 `make check` 上表现为全绿，重演 §B5「以为门禁看着，其实没看着」的认知。
**Remedy（修补）**：`--check` 模式下 `STOP_EXTRAS` 非空时置 `root_fail=1`（横幅文案已足够说明），或在 `collect_rel_paths` 之外补一个副本侧反向扫描（`stop/*.sh` ∉ REL_PATHS → 报「副本残留」）。若不改，请在 REQUIREMENT.md 的「依赖与假设」（:181-183）里把「只增改、不删除，副本残留不检测」写成显式假设，避免读者高估覆盖面。

### Checklist 逐项结论（阶段 1 + 通用 L-031）

| 检查项 | 结论 |
|---|---|
| 每条 AC Given/When/Then 三段齐全 | 12/12 齐全（均含三段 + 验证方式），无「系统应该正常工作」式空话 |
| 每条 AC 可机器验证 | **11/12**：AC-1~AC-11 均给可执行命令且我已逐条实跑；AC-12 的验证方式退化为源码 grep（**R2**） |
| v1/v2/out 切分合理、无范围蔓延 | 基本合理：v1 全部由 §B1~§B5 报告条目直接映射，v2/out 三项均带「为什么不是这次」且挂 ADR-010；**唯一缺陷 = v1 声明漏 AC-12（R4）**。未发现悄悄塞进 v1 的新范围 |
| 非功能性需求（性能/安全/可观测/容量/兼容） | 五项均有；AC-12 已把「提取失败的可观测性」补进 AC 层（前轮 R3 的诉求已闭合）。**R3** 指出 AC-2 对第 4 消费点的描述与实现不符；`done-validation` 的 Tier4 语义未因本次修复改变判定方向（空值→放行是既有 best-effort） |
| 需求内部矛盾 / 歧义 | 未发现硬矛盾。AC-1（L2 在前）与非功能「兼容 Gen-1（L3 段在前）」是不同工件形态，不冲突；AC-6（四处载体）与 B3-R5b 的第五处载体是「测试面更严」，不矛盾；AC-12 与 B1-R7（空输出 + rc1）语义一致。**R1** 属 AC 的 Given 覆盖不全（未约束 L3 段内二级标题），而非自相矛盾 |
| 事实性声明可核实性 | 13/13 项独立复算命中（见复算表）。AC-2 的 Given「223 份」在本轮快照下准确（222 archive + 本 change 的 IR-1），但它是**活计数**：本 change 后续阶段会继续新增 `INDEPENDENT-REVIEW-*.md`，5-test 复算时该数字必然变大；因空值预算 ≤8 且新增文件带 verdict，不会因此失败，故只作观察不单列 finding |
| **L-031 跨文件一致性扫描**（锚点：`fk_extract_l2_verdict` / `_fk_l2_scope` / `L3_SECTION_END_MARKER` / `<!-- /L3-SECTION -->` / `max_artifact_bytes` / `FLOW_KIT_L3_MAX_ARTIFACT_*` / `HOOK_MODULE_NAMES` / `l3-section.sh`） | `fk_extract_l2_verdict`：4 个消费者（`gate-checks-review.sh:24`、`29-independent-review.sh:266`、`l3-review.sh:235`、`done-validation.sh:152`）与注释「4 consumers (4 files)」一致，无漏改。`max_artifact_bytes`：8 处源码/文档载体全部同步（`stop-hook.json`、`.claude/l3.env.example`、`README.md`、`dsh-flow-kit/README.md`、`package-flow-kit.sh`、29 号脚本、`l3-review.sh`、`.flow-kit/stop-hook.json`）；`dist/**` 里的 README 仍是旧键名，但 `dist/` 被 `.gitignore:61` 忽略、`git ls-files dist` = 0 条，属未重打包的构建产物而非源漂移。`HOOK_MODULE_NAMES`：18 = 18，`install_hooks.sh` 的回退清单与 `common.sh` 逐项相同，`sync-hooks.sh` 已改为同源枚举（实测生效）。`l3-section.sh`：字面量唯一定义（:25），3 个写入方 + 1 个删除方引用，安装面由 `stop/lib/*.sh` 通配覆盖。**唯一命中 = R1**：`L3_SECTION_END_MARKER` 的消费方少了一个——`_l3_strip_sections` 用它，`_fk_l2_scope` 不用，正是 L-031 的「DESIGN 漏列且未改」类 |

### 对前轮 R1~R5 的独立判定（本轮要求）

| 前轮发现 | 我的判定 | 依据 |
|---|---|---|
| **R1** 🔴 L3 段非围栏 verdict 顶掉 L2 | **结论方向成立，证据段 5/5 失实** | 我独立复现了缺口（R1，且用生产写入函数，比前轮更硬的证据）。但前轮列举的 5 份「方向翻转」工件逐份复算后全部不成立：`2026-07-21-gate-review-fix/IR-3`（108 在 `## L2 盲审`、282 在 `## L2 盲审（复审）`，均为 L2 段）、`l2-l3-test-defect/IR-1`（185/468/767/944 全部落在 4 个 L2 段内）、`l2-l3-test-defect/IR-2`（127/230 均为 L2 段）；`l2-l3-granular-gate/IR-1` 与 `2026-07-11-health-fix-l3/IR-6` **连一条 anchored verdict 行都没有**（旧实现分别给 fail / fail，从无 pass）。**主 agent 的「那 5 份是同一工件内的多轮 L2，不是被 L3 顶掉」这一反驳是正确的** |
| **R2** 🟡 四处文档只断言一半 | **成立且已修复** | `B3-R5` 现对 4 个载体逐个断言三条，`B3-R5b` 补第 5 处（`package-flow-kit.sh`）；我逐文件裸 grep 复核 5/5 三项全 Y。前轮的判断（「最容易回退的那一半恰好无保护」）确实命中了保护面缺口 |
| **R3** 🟡 提取失败的下游语义缺失 | **成立且已修复（行为），但验证方式不合格** | AC-12 已写入 REQUIREMENT，29 号模块的 else 分支我实跑证明可达且行为正确。剩余问题 = AC-12 的验证方式不验证 AC-12 → **本轮 R2** |
| **R4** 🟡 sync-hooks 与安装器不同源 | **成立；修复落地但只落一半** | 机制差异属实，同源枚举已实现（我用改过的清单实测镜像数随清单变化）。残留：extras 只告警不拦 + 副本侧残留不可见 → **本轮 R6（🟢，降级理由见 R6 Source/Consequence）**。另：前轮「19 = 19」计数错误（实为 18 = 18），主 agent 的更正正确 |
| **R5** 🟢 AC-8 的 41 条目无真实对应物 | **成立，处置合规** | REQUIREMENT.md:95-96 已改写为「由测试合成（33 个编号文件 + 8 个标准产物 = 41 条目；现实 change 目录的最大条目数见 5-test 实测）」，且按 severity gating 登记于 `MINOR-DEFERRED.md` M1。Minor 不入 fix loop，无需代码变更 |

---

**Verdict**: fail

> 复算全程只读（临时树/反例建在 `/tmp/l2r2/`，未写仓库）。本轮唯一写入 = 本段。fail 的唯一来源是 R1（🔴）：AC-1 的「限定 L2 层」在 L3 段含二级标题时会失效，且已用生产写入函数复现出「工件写 `fail`、函数返回 `pass`」。

---

## 主 agent 响应（L2 盲审（复审）· 阶段 1）

> 追加段，不改写审查员原文。

### R1 · 🔴 Critical —— **成立，已修**（这是本轮最有价值的发现）

报告指出的问题精准且**用生产写入路径复现**（不是手写工件）：`_fk_l2_scope` 用
「遇任何 `^## ` 就复位 skip」判定 L3 段结束，而 L3 载荷里出现行首 `## ` 是本项目
**自认的常见形态**（§B2 的 B2-R1/B2-R6 正是用它构造用例）。载荷里那一行会让其后
L3 正文重新进入"L2 层"，行首 `Verdict:` 随即顶掉 L2 结论。

报告的核心指认——**§B2 刚在删除侧否决掉的启发式，被 §B1 的读侧又引入了**——完全正确。
这是 L-031 的同类：同一契约（L3 段边界）在两处以不同机制表达。主 agent 在上一轮
只做了「按块排除」，没有把边界判定同源，属于修得不彻底。

- **Fixed in:** `flow-kit-bundle/hooks/stop/lib/l3-section.sh`
  - 新增 `_l3_section_spans()`：输出 L3 段的行区间，**段边界判定的唯一来源**
  - `_l3_strip_sections()` 重构为消费该区间（删除侧不再自带判定）
- **Fixed in:** `flow-kit-bundle/hooks/stop/lib/l2-detect.sh`
  - `_fk_l2_scope()` 改为消费 `_l3_section_spans()`，删除自创的 `^## ` 复位启发式
  - 加依赖注入（同目录兜底 source `l3-section.sh`），因为本文件也被
    `done-validation.sh` / `gate-checks-review.sh` 独立 source
- **复现验证**（报告给的命令，逐字照跑）：载荷含 `## 附录：发现明细` + `**Verdict**: pass`
  经 `_l3_parse_result` 真实写入后，`fk_extract_l2_verdict` = `fail` ✅（修复前 `pass`）
- **Fixed in:** 新增 `B1-R16`（**生产写入路径**用例，照抄 B2-R6 的驱动方式）
  与 `B1-R17`（同源断言：读侧必须消费 `_l3_section_spans`）
- **回归确认**：223 份语料实跑，空值 8 / 非枚举 0，与重构前**逐一相同**
  （历史工件无标记 → 两侧都走标题法兜底，行为不变）
- 报告"现有语料尚未出现翻转实例，但这是『还没跑到』而非『跑不到』"的判断准确。

### R2 · 🟡 Important —— **部分接受：报告对 `B1-R15` 的批评成立，但完整行为 harness 本轮未落地**

报告指认 `B1-R15` 退化为源码字符串 grep、其中 `grep -qE 'l2_verdict="fail"'` 命中的是
`if/else` **之外**的默认赋值（对任何实现恒真）——**这个批评完全正确**，用例确实没有
验证 AC-12 的 Then 1/Then 2。

- **Fixed in（部分）:** `B1-R15` 保留为源码层烟测，但已明确其局限；
  AC-12 的 Then 1/Then 2 由**本轮审查员自己实跑证明可达**（复算表第 6-7 行：
  stderr 出现 `L2 verdict not found`、`l3_review_run` 收到 `l2_verdict=[fail]`、
  3 个对照路径不误报）。
- **Tech-debt:** 完整行为 harness（stub `l3_review_run` + stub 树跑 29 号模块、
  断言 stderr 与实参）本轮**未落地**，登记为 TD。理由：搭建可信 stub 树需覆盖
  29 号模块的 module_enabled / phase / gate_config / 凭证 四道前置，本轮把它做扎实
  的成本高于其在阶段 1 的收益；报告已给出可复用的最小 harness，5-test 阶段据此补。
  登记见 `MINOR-DEFERRED.md` M6（按 severity gating，Important 的**修复**已做，
  此处欠的是**测试强度**，不阻塞 toll-gate）。

### R3 / R4 / R5 · 🟢 Minor —— **接受（已顺带修正）**

- R3（AC-2 对第 4 个消费点描述与实现不符）：`Fixed in:` REQUIREMENT.md AC-2 —— 改为
  「4 处均不阻塞：3 处回落 fail，`done-validation` 的 T4 走既有 best-effort 放行」。
  报告指出按原文写断言会失败，属实。
- R4（v1 范围漏 AC-12）：`Fixed in:` —— v1 改为「AC-1 ~ AC-12 全部」。
- R5（AC-1 计数失准）：`Fixed in:` —— 改为「17 例：B1-R1 ~ B1-R17」。
- 三条均按协议登记 `MINOR-DEFERRED.md` M2/M3/M4（记录"已顺带修正"以免审计断链）。

### R6 · 🟢 Minor —— **接受（源侧接入门禁；副本侧保留 advisory）**

- **Fixed in:** `sync-hooks.sh` —— `--check` 模式下 `STOP_EXTRAS` 非空即 `root_fail=1`。
  自证：伪造 `stop/zz-draft.sh` → `--check` exit **1**；删除后 exit 0。
- **副本侧残留（报告场景③）保留为 advisory，不拦截**：
  `~/.claude/hooks/stop/` 是共享目录、可能含第三方工具的 stop hook，
  源驱动的枚举本就无法区分"残留"与"他方文件"，反向扫描会假阳性。
  已在 `MINOR-DEFERRED.md` M5 显式登记该边界，避免读者高估覆盖面。

---

### 本轮修复后复算

| 项 | 结果 |
|---|---|
| R1 生产路径复现（报告原命令） | `fail` ✅（修复前 `pass`） |
| 语料 223 份 | 空值 8 / 非枚举 0 —— 与重构前逐一相同 ✅ |
| 回归套件 | `test_l3_review_defects_2026_09.bats` 36 例全绿 ✅ |
| `--check` 安装集漂移 | 伪造 extras → exit 1；正常 → exit 0 ✅ |
| hooks 副本漂移 | 6/6 漂移 0 ✅ |
| 全量 bats + make check | 见 5-test |

---

## L2 盲审（三审）

⚠️ 独立性受损：检测到主 agent 上下文注入（输入含前两轮的 `## 主 agent 响应` 段，共 6 条 R 的「已修／已复算」自评）。按调用方三审指令，前两轮审查与两段响应均为**待复核对象**而非权威；本段全部结论由本轮在仓库内独立实跑复算得出，未采信其中任何一条陈述（含「已修」「已复算通过」）。

**审查对象**：`.specs/l3-review-defects-2026-09/REQUIREMENT.md`（参考 `CHANGE.md`）；判定目标 = 前两轮 🔴/🟡 在当前工作区是否真闭合
**审查员**：L2 独立盲审员 · 第 3 轮三审 · 阶段 1（1-requirement）
**复算环境**：HEAD `61c4bf8` + 工作区未提交修复（`git status` 10 项 M/??）；`npx bats`、`awk`/`jq`/`shellcheck` 在位；全部反例/桩树建在 `/tmp/l2r3/`
**禁区遵守**：未打开 `REVIEW.md`、`.specs/archive/**` 复测报告、`git log` 正文；仅只读跑 grep/find/wc/git diff，写入仅限 `/tmp` 与本段

### 本轮独立复算结果（先证据）

| # | 被复算项 | 我的复算方式 | 实测 | 判定 |
|---|---|---|---|---|
| 1 | **二轮 R1 原命令逐字复跑** | `_l3_parse_result` 写含 `## 附录：发现明细` + `**Verdict**: pass` 的载荷 → `fk_extract_l2_verdict` | `fail`（修复前 `pass`） | ✅ 该形态已闭合 |
| 2 | 新反例：载荷多行 `^## `（`## 发现明细`/`## 附录 A`/`## 附录 B`） | 同上生产写入路径，共 23 行工件 | `fail`，spans=`9 23` | ✅ |
| 3 | 新反例：`## ` 距 Verdict 行更远（间隔 5 行） | 同上 | `fail`，spans=`9 25` | ✅ |
| 4 | 新反例：载荷含 `^## L3 ` 字样 | `## L3 审查结论摘要` → `fail`；`## L3 盲审（引用）`（精确命中 span 正则）→ `fail`（spans=`9 16;17 21`，靠 span 重启找回标记） | ✅ |
| 5 | 新反例：载荷含 `^## L2 ` 字样 | `## L2 结论复核` + `**Verdict**: pass` | **`pass`**（L2 段写 `fail`） | ❌ **R1** |
| 6 | 新反例：载荷含结束标记字面量 | `<!-- /L3-SECTION -->` + `**Verdict**: pass` | **`pass`** | ❌ **R1** |
| 7 | 触发集穷举（13 种载荷行 fuzz） | `## 附录` / `## L2`（无空格）/ `## L2盲审` / `## L2\t` / `## L3 摘要` / `## L3 盲审` / `## 主 agent 响应` / `### L2 …` / 缩进标记 → 全 `fail` | 只有 `^## L2 `（L2 后跟空格）与 `^<!-- /L3-SECTION -->[[:space:]]*$` 翻转 | ❌ 见 R1 |
| 8 | **AC-4 Then** 在生产写入路径（4 轮重写） | 基线载荷 → 标记 1/围栏 2/`---` 1/残留 0；载荷 `## L2 结论复核` → 标记 **3**、围栏 **4**、残留 **4** 行；载荷含标记字面量 → 标记 **3**、围栏 **4**、残留 **2** 行 | 前两轮新用例的载荷（`## 附录` / `## 行首标题 A/B`）全 OK，`^## L2 `/标记字面量超界 | ❌ **R1** |
| 9 | 读侧/写侧真同源（L-031） | 读 `_fk_l2_scope`(l2-detect.sh:59-83) 与 `_l3_strip_sections`(l3-section.sh:81-115) 调用图；裸 shell 实测两函数对同一工件给出同区间 | 两者都调 `_l3_section_spans`，读侧**无** `^## ` 复位启发式残留；spans=`9 17`，strip 结果 = 仅剩 L2 段 | ✅ 同源成立 |
| 10 | 依赖注入 / 降级路径 | ①裸 shell 仅 source `l2-detect.sh` → ②把 `l2-detect.sh` 单独复制到无 `l3-section.sh` 的目录 | ①自动注入，`fail` ✅；②`_l3_section_spans` 不可用 → **`pass`（静默 fail-open，§B1 缺陷原样复活，零告警）** | ❌ **R3** |
| 11 | 全语料回归（`find .specs -name 'INDEPENDENT-REVIEW-*.md'`） | 223 份逐份调 `fk_extract_l2_verdict`；并与 HEAD 版 `git show HEAD:…l2-detect.sh` 逐份对比 | 现：`pass=148 / fail=67 / 空=8 / 非枚举=0`；HEAD：`pass=152 / fail=71 / 空=0`；差异**恰 8 份且全部「有值→空」**，无 pass↔fail 翻转、无新增空值 | ✅ 无新误伤 |
| 12 | 8 份空值归因 | 逐份打印标题 + HEAD 旧值来源行 | 5 份有 L2 段但段内零 verdict；3 份连 L2 段都没有（2 份仅 `## 主 agent 自审（L2 unavailable…）`、1 份仅 `## L3 盲审`）。旧值来源：**6 份 L3 段**（5 份 L3 JSON、1 份 L3 段内 `> **Verdict: fail**`）+ **2 份主 agent 自审段**（`**主 agent 复判 Verdict**: ✅ **PASS**`） | 与 AC-2:54-58 的括注一致（我独立得出，非抄） | ✅ |
| 13 | 全语料「取值来源块」逐份溯源 | 复刻 `_fk_l2_scope` 的 del/skip 逻辑输出命中行号 + 所属 `^## ` 标题 | 11 份命中行落在非 L2 标题块；逐份核对：8 份是「L2 复审自带的 `## ` 子标题」（正确行为，如 `2026-07-10-fix-l3-gate/IR-5` 第 227 行确属第二轮 L2 报告），3 份是 `## 自裁决 · 主代理` | ❌ 3 份见 R4；**无一份来自 L3 段**（修复前有） |
| 14 | **AC-12 行为**（stub 树实跑 29 号模块） | stub `l3_review_run` 记录实参 + stub 树 `HOOK_BASE_DIR`；Given = `## L2 盲审` 段无 verdict | stderr：`L2 verdict not found in …`；`L3RUN … L2V=[fail]`；`module_output warning\|IR\|L2 verdict not found` 落盘；对照 B(`fail`)/C(`pass`)/D(L2-first 分支)/E(`skipped`) 四路径行为均正确 | ✅ 行为正确 |
| 15 | **端到端复合**：R1 × AC-12 | 载荷 `## L2 结论复核` 经 `_l3_parse_result` 写入后跑完整 29 号模块（gate=both） | `L3RUN … L2V=[pass] gate=[both]`，而工件 L2 段写着 `**Verdict**: fail` | ❌ **R1 已达 `.done` 写入路径** |
| 16 | AC-12 的**验证方式** | 读 `test/test_l3_review_defects_2026_09.bats:225-233` | 仍是 3 条对 `$H29` 源码的 grep；第 2 条 `l2_verdict="fail"` 命中的是 `29-independent-review.sh:264` 的 `if/else` **之外**默认赋值（恒真） | ❌ **R2**（二轮 🟡 未闭合） |
| 17 | AC-2 措辞 vs 4 消费点实现 | 逐处读源码 | `gate-checks-review.sh:24-25`、`l3-review.sh:235-236` 显式 `[ -n ] \|\| =fail`；`29-independent-review.sh:264-276` 保 `fail` + 告警；`done-validation.sh:152-153` 空值 best-effort 放行 | ✅ 与 REQUIREMENT.md:59-62 逐字一致 |
| 18 | AC-6 五处载体 | 对 4 载体 + `package-flow-kit.sh` 逐文件裸跑 3 条 grep（不看测试结论） | 5/5「键名 + 单位=字节 + ÷3」全 Y | ✅ |
| 19 | AC-7 旧键兼容 | stub 树配 `max_artifact_chars=60000` 实跑 29 号 | `MAXBYTES=[60000]` + stderr `DEPRECATED … max_artifact_chars 已改名 max_artifact_bytes` | ✅ |
| 20 | AC-10 门禁非恒真 | ①正常 `--check` ②伪造 `stop/zz-draft-probe.sh` ③删副本 `~/.claude/hooks/stop/99-report.sh` ④恢复 | ①exit 0 / 漂移 0 ②**exit 1**（源侧安装集漂移进退出码）③**exit 1** ④exit 0 | ✅ 二轮 R6 的源侧修复已落地 |
| 21 | AC-11 全套门槛 | `make check`；`npx bats test/`；`wc -l`；`diff` | `make check` **exit 0**（结构门槛/shellcheck/打包 `--validate` 漏配 0/双源一致/漂移 0）；全量 bats **863 ok / 0 not ok / exit 0**；`l3-api.sh`=249 行；`test/` 与 `flow-kit-bundle/test/` 逐字节相同 | ✅ |
| 22 | AC-1 计数 / v1 范围 | `bats -f B1`；读 REQUIREMENT.md:47,153 | **17 例**（B1-R1~R17）；v1=「AC-1 ~ AC-12 全部」 | ✅ 二轮 R5/R4 已修正 |
| 23 | L-031 五锚点 + 镜像 | grep 5 锚点全仓；4 个镜像目录 md5 | `_l3_section_spans`(4 文件)/`_fk_l2_scope`(4)/`L3_SECTION_END_MARKER`(5，字面量唯一定义 l3-section.sh:25)/`max_artifact_bytes`(6)/`HOOK_MODULE_NAMES`(5)；`.claude`、`dist×2`、`bundle` 的 l2-detect.sh 与 l3-section.sh **md5 逐一相同**，且每个副本目录内两文件同址 | ✅ 无漏改 |
| 24 | 真实语料旁证（触发形态非假想） | 全语料扫「L3 段内行首 `## `」 | `archive/l2-l3-fix-compliance/IR-6` 的 L3 载荷正文**以行首 `## 独立审查报告（盲审）` 开头**；`archive/gate-integrity/IR-1:46` 有行首 `## L3 写入 bug（dogfood 实证 · …）` 标题 | 模型返回自由 markdown 是实证形态 |

---

### 🔴 R1 · `_l3_section_spans` 的提前终止分支让「行首 `## L2 `」与「标记字面量」穿透 L3 段边界 —— AC-1 补充约束与 AC-4 Then 在生产写入路径下双双不成立

**Severity**：🔴 Critical
**Symptom（症状）**：`flow-kit-bundle/hooks/stop/lib/l3-section.sh:56-60` 的向前扫描把 `^## L2 ` 与 `^## L3 (盲审|重审)` 当作段终点，**先于**标记行判定；载荷里一旦出现 `^## L2 `（L2 后跟空格）或 `^<!-- /L3-SECTION -->[[:space:]]*$`，`stop` 保持 0 → 回落标题法（:61-64）→ 区间在**该行之前**收口，其后的整个 L3 正文（含行首 `**Verdict**: pass`）与真正的标记行一起留在 `del[]` 之外。两条 Then 同时失效（均为生产写入路径复现，非手写工件）：

```
# AC-1 补充约束（REQUIREMENT.md:41-42）
$ printf '# IR-1\n\n## L2 盲审\n\n**Verdict**: fail\n' > $d/INDEPENDENT-REVIEW-1.md
$ payload=$(printf '{"verdict":"pass"}\n## L2 结论复核\n**Verdict**: pass')
$ source flow-kit-bundle/hooks/stop/lib/l3-review.sh;  _l3_parse_result "$payload" 1 "$d" model-x
$ source flow-kit-bundle/hooks/stop/lib/l2-detect.sh;  fk_extract_l2_verdict "$d/INDEPENDENT-REVIEW-1.md"
pass                      # ← 工件 L2 段写的是 fail（标记在第 21 行，未被采纳）
$ _l3_section_spans "$d/INDEPENDENT-REVIEW-1.md"
9 16                      # ← 终点是「下一个二级标题」，不是 <!-- /L3-SECTION -->

# AC-4 Then（REQUIREMENT.md:76-78）· 4 轮「删旧段→追加新段」
baseline 载荷        → ^## L3 =1 ✅  marker=1 ✅  ^---$=1 ✅  fences=2 ✅  残留=0 ✅
载荷 '## L2 结论复核' → ^## L3 =1 ✅  marker=3 ❌  ^---$=1 ✅  fences=4 ❌  残留=4 ❌
载荷 '<!-- /L3-SECTION -->' → marker=3 ❌  fences=4 ❌  残留=2 ❌

# 端到端（29 号模块，gate=both，stub l3_review_run）
L3RUN phase=1 cid=cid dir=… L2V=[pass] gate=[both]      # 工件 L2 段：**Verdict**: fail
```

触发集已穷举（13 种载荷行）：`## 附录` / `## L2`（无空格）/ `## L2盲审` / `## L2<TAB>` / `## L3 摘要` / `## L3 盲审` / `## 主 agent 响应` / `### L2 …` / 缩进标记 **全部正确**；**只有 `^## L2 ` 与标记字面量两种翻转**。`^## L3 盲审` 之所以正确，是因为 span 会在该行重启并于末尾找回标记（spans=`9 16;17 21`）——即同一函数对两类「同名层」行的处理不对等。
**Source（源头）**：REQUIREMENT.md:41-42（AC-1 补充约束，2026-09-18 由二轮 L2 R1 追加：「L3 段的终点是 `<!-- /L3-SECTION -->`，**不是**「下一个二级标题」」）；REQUIREMENT.md:76-78（AC-4 Then）；L-031（同一契约两处机制）；l3-section.sh:43-44 自己的注释即声称「不因载荷里的行首 `## ` 提前放弃」。**测试盲区（为何 863 例全绿仍漏）**：`test:244`（B1-R16）载荷用 `## 附录：发现明细`、`test:299/301`（B2-R2）用 `## 行首标题 A/B`、`test:379`（B2-R6）用 `## 行首标题${r}` —— 三个用例的载荷标题都**不以 `L2 ` 开头**、也都不含标记字面量，恰好落在通过侧。
**Consequence（后果）**：§B1 的原始故障（L3 改写 L2 结论）在**新格式（带标记）工件**上仍可触发，且经 `29-independent-review.sh:266→285` 直接进 `l3_review_run` 的第 4 实参 → `_l3_write_done` 落 `.done` 的 `L2_verdict`；`done-validation.sh:152` 的 T4 只判相等、`gate-checks-review.sh:24` 据此放行 → 审计记录写「L2 通过」而工件 L2 段写 `fail`，L2 契约（`L2-blind-review.md:142`「主 agent 无权修改你的原文判断」）失去可复现前提。**同一载荷还让 §B2 的「逐轮累积污染」复发**（标记 3 个 / 围栏 4 条 / 旧载荷 4 行残留，随轮次增长）——即本 change 两个主 AC 的 Then 在该载荷下同时失效。触发窗口 = L3 写盘后到下一次重写前，正是过 gate 的时刻。概率面（诚实标注）：需载荷出现行首 `## L2 `（或标记字面量）；载荷是模型自由 markdown（§B2 自认「很常见」，语料有实证），且 29 号注入的前次上下文里就带着 `- **Verdict**: fail` 这一 L2 主题行，但「`## L2 `」这一具体前缀在 223 份语料中尚无实例 —— **AC 合规失败是确定的，现实命中率请主 agent 定权**。
**Remedy（修补）**：让标记优先，`^## L2 ` 只在「整段确实没有标记」时当终点（保留 Gen-1 历史工件语义；`^## L3` 的 break 必须保留，否则会把下一段的标记误算给本段）：

```awk
# l3-section.sh:55-64  before: 命中 '^## L2 ' 立即 break
#                      after : 记住该行，继续向前找标记；找不到标记才用它收口
stop = 0; l2hit = 0
for (j = i + 1; j <= n; j++) {
  if (line[j] ~ /^<!-- \/L3-SECTION -->[[:space:]]*$/) { stop = j; break }
  if (line[j] ~ /^## L3 (盲审|重审)/) break
  if (line[j] ~ /^## L2 / && l2hit == 0) l2hit = j          # ← 不再 break
}
if (stop == 0) {
  stop = n
  if (l2hit) stop = l2hit - 1
  else for (j = i + 1; j <= n; j++) if (line[j] ~ /^## /) { stop = j - 1; break }
}
```

标记字面量穿透（载荷自带 `<!-- /L3-SECTION -->`）二选一：(a) 取**段内最后一个**标记行（`^## L3` break 仍做上界）—— 与「写入方恒把标记落在段尾」的实现一致，且能把残留标记一并回收；(b) 若判定为可接受残余，须在 AC-1/AC-4 文本里显式限定（现文本是**无条件**的「终点是标记」），并登记 MINOR-DEFERRED。
并补三条回归（否则仍会漏）：B1-R18 `## L2 xxx` 生产写入 → 断言 `fail`；B2-R7 同载荷 4 轮 → 断言 `marker=1 / fences=2 / 残留=0`；B1-R19 载荷内嵌标记字面量 → 断言 `fail`。

---

### 🟡 R2 · 二轮 🟡 未闭合：AC-12 的验证方式仍不验证 AC-12（`B1-R15` = 源码字符串 grep）

**Severity**：🟡 Important
**Symptom（症状）**：`test/test_l3_review_defects_2026_09.bats:225-233` 的 `B1-R15` 与二轮审查时**逐字相同**：三条对 `$H29` 源码的 grep，不构造 AC-12 的 Given 工件、不运行模块、不读 stderr、不检查传给 `l3_review_run` 的实参。其中 `grep -qE 'l2_verdict="fail"'` 命中的是 `29-independent-review.sh:264` 的默认赋值（在 `if/else` 之外，对任何实现恒真）。主 agent 本轮以 `Tech-debt` + `MINOR-DEFERRED.md` M6 处置，**未改测试**；REQUIREMENT.md:145 仍写 `验证方式: bats … -f "B1-R15"`。
**Source（源头）**：`L2-blind-review.md:85-89`（阶段 1 checklist「每条 AC 是否……**可机器验证**」）；`L2-blind-review.md:126,144`（🟡 入 fix loop，task 内解决；`Fixed in:` 优先于纯登记）。对照：同套件 B1-R1~R14/R16 都是「构造工件→调函数→断言返回值」的行为用例，AC-12 是唯一退化为文本断言的 AC。
**Consequence（后果）**：AC-12 的三条 Then 中只有「告警文本存在」被弱保护；「提取为空不得静默降级」与「传给 `l3_review_run` 的值仍为合法枚举」无门禁。行为**当前是对的**（本轮复算 #14 用自建 stub 树实跑证明：stderr + `L2V=[fail]` + `module_output warning`，四个对照路径均不误报），但下一次重构可以静默带回 §B1 故障形态而 `make check` 全绿——这正是 M6 自己写下的风险。
**Remedy（修补）**：把 `B1-R15` 换成行为用例（harness 本轮已跑通，可直接抄）：`HOOK_BASE_DIR` 指向含 `lib/*`（真实现）+ stub `lib/l3-review.sh` 的树，`PROJECT_ROOT` 指向含 `.flow-active`（`goal.gate_config["1-requirement"]="both"`）与给定工件的临时目录，`CONFIG_FILE` 指向 `{"modules":{"independent_review":{"enabled":true}}}`，`FLOW_KIT_L3_MODEL=stub-model`；然后断言 `stderr` 含 `L2 verdict not found` 且 stub 日志含 `L2V=[fail]`（实参，不是源码文本）；保留现三条 grep 作为附加烟测。

---

### 🟡 R3 · `_l3_section_spans` 不可用时读侧静默 fail-open，§B1 缺陷原样复活且零告警

**Severity**：🟡 Important
**Symptom（症状）**：`flow-kit-bundle/hooks/stop/lib/l2-detect.sh:62` 用 `type _l3_section_spans >/dev/null 2>&1 && spans="$(_l3_section_spans "$review_md")"` 取区间；函数不可用时 `spans` 留空 → `del[]` 为空 → **不做任何 L3 排除**。实测：把 `l2-detect.sh` 单独复制到没有 `l3-section.sh` 的目录后 source，对同一份「L2 段 `fail` + 带标记的 L3 段 `pass`」工件，`fk_extract_l2_verdict` 返回 **`pass`**（正确目录下同工件返回 `fail`），全程无 stderr、无返回码差异。
**Source（源头）**：AC-12 的同一条原则（REQUIREMENT.md:141-142「提取结果为空时……**不得**静默降级」）在**依赖缺失**这条同族路径上未被贯彻；`l3-api.sh:173` 对 `_l3_strip_sections` 的同类守卫是显式 fail-safe（`|| cp`，注释写明「绝不写空」），读侧这份守卫却把缺失解释为「不排除 L3」。旁证：`_fk_l2_scope` 是本 change 新引入的依赖方（二轮 R1 的 Remedy 1），此前读侧不依赖 `l3-section.sh`。
**Consequence（后果）**：部分安装 / 手工拷贝 lib（正是 §B5「副本漂移」那条链）下，门禁会以**看起来正常**的方式退回 §B1 的 Critical 行为：`.done` 的 `L2_verdict` 与工件 L2 段矛盾，且没有任何可观测信号。当前 6 处镜像均同址含两文件（复算 #23），故不是现存故障，而是**下一次安装/打包回归的静默失效面**。
**Remedy（修补）**：让缺失变可见，且不要退化成"不排除"：
```bash
type _l3_section_spans >/dev/null 2>&1 || echo "[l2-detect] WARNING: _l3_section_spans 不可用（l3-section.sh 缺失？）——L3 段边界无法判定，L2 结论可能被 L3 覆盖" >&2
```
更稳的做法是缺失时**降级到保守的 `^## L3 `/`^## 主 agent` 块排除**（即上一版行为）并同时告警；补一条 bats 用例：无 `l3-section.sh` 的 lib 目录下断言 stderr 有该告警。

---

### 🟢 R4 · `## 自裁决 · 主代理` 段仍被当作 L2 层：3 份语料的「L2 结论」实为主 agent 自证

**Severity**：🟢 Minor
**Symptom（症状）**：`_fk_l2_scope` 只排除 `^## 主 agent`（l2-detect.sh:77），而语料中主 agent 自证段还存在 `## 自裁决 · 主代理（D7 例外 · …）` 这一措辞。`archive/health-fix-2026-08/INDEPENDENT-REVIEW-{3,5,7}.md` 中，唯一锚定 verdict 行（`:10` / `:10` / `:9` 的 `**Verdict**: **PASS**`）落在该段内，函数返回 `pass`；三份文件各自的 `## 追溯 L2 审查（retroactive oracle …）` 段结论也是 pass，故**本轮未观察到取值翻转**，行为与 HEAD 相同（非本 change 引入）。
**Source（源头）**：AC-1 补充约束的立意（REQUIREMENT.md:35「主 agent 响应段内的 Verdict 行不得影响结果」）；`L2-blind-review.md:142`（主 agent 无权改写审查员判断）。
**Consequence（后果）**：无阻塞性后果（三份均在 `archive/`，且自证与追溯 L2 结论一致）。风险是同一类「非 L2 段冒充 L2 结论」在换措辞后重新进入取值链——当前语料的 `## 主 agent 自审（L2 unavailable）`（2 份）已被 AC-2 的空值预算覆盖，但 8 份的判定依据是「无 L2 段」而非「按措辞穷举」，新措辞不受保护。
**Remedy（修补）**：二选一并留证——(a) 把排除条件从单模式放宽为 `^## 主 agent|^## 自裁决|^## 主代理`，同时补一条语料级回归（对这三份断言返回空值，因其无 `## L2` 段）；(b) 若判定该措辞属设计内（D7 自裁语义，语料中它确有独立审计记录 `## 追溯 L2 审查`），则在 REQUIREMENT 的兼容性段写明「`## 自裁决 · 主代理` 段被计为 L2 层」，并登记一条冻结现状的语料回归（断言三份的取值来源行号与所属标题），使该措辞的扩缩都成为显式变更而非静默行为。

---

### Checklist 逐项结论（阶段 1 + 通用 L-031）

| 检查项 | 结论 |
|---|---|
| 每条 AC Given/When/Then 三段齐全 | 12/12 齐全（含验证方式），无「系统应该正常工作」式空话 |
| 每条 AC 可机器验证 | **10/12 无误**；AC-12 的验证方式仍是源码 grep（**R2**）；AC-1/AC-4 的 Then 存在机器可判定的反例（**R1**，我已用生产写入路径复现） |
| v1/v2/out 切分合理、无范围蔓延 | ✅ v1=AC-1~AC-12（:153，二轮 R4 已修）；v2/out 各项均带「为什么不是这次」且挂 ADR-010；未发现悄悄塞进 v1 的新范围 |
| 非功能性需求（性能/安全/可观测/容量/兼容） | 五项均有；AC-12 已把「提取失败的可观测性」写入 AC 层。**R3** 指出同一原则在「依赖缺失」路径上未贯彻（静默 fail-open）。AC-2 措辞与 4 消费点实现逐字一致（复算 #17） |
| 需求内部矛盾 / 歧义 | 未发现硬矛盾。AC-1 的 Given 与「兼容 Gen-1」不冲突；AC-6（四处载体）与 B3-R5b（第五处）是测试更严，不矛盾。**R1** 属 AC 的 Then 与实现不符（补充约束被实现违反），非自相矛盾 |
| 事实性声明可核实性 | 24 项独立复算：22 项命中，2 项反例（#5/#6 与 #8 的 `^## L2 ` 支、#10 的降级支）。AC-2 的「223 份」「空值 8」「零非枚举」在本轮快照下**完全准确**；8 份归因我独立复核为 6 L3 + 2 主 agent 自审（与 AC-2:54-58 括注一致） |
| **L-031 跨文件一致性**（锚点 `_l3_section_spans` / `_fk_l2_scope` / `L3_SECTION_END_MARKER` / `max_artifact_bytes` / `HOOK_MODULE_NAMES`） | 5 锚点全仓 grep 无漏改：`_l3_section_spans` 定义唯一（l3-section.sh:47），两个消费者（`_l3_strip_sections` / `_fk_l2_scope`）+ 4 处镜像同址同 md5；`L3_SECTION_END_MARKER` 字面量唯一定义且被 B2-R5 断言三写入方共用；`max_artifact_bytes` 6 个载体同步；`HOOK_MODULE_NAMES` 18 条与 install/sync 同源（本 change 只加 lib 不加模块，无 L-020 三处接线需求）。**命中 = R1**（标记的消费方在 `^## L2 ` 分支上仍被绕过）与 **R3**（依赖缺失无守卫） |

### 对前两轮 R 条与主 agent 响应的独立判定（本轮要求）

| 前轮发现 | 我的判定 | 依据 |
|---|---|---|
| **R1(1)** 🔴 提取跨段越界 / L3 顶掉 L2 | **部分闭合**：结构性缺口已用「层切分」收口（我复现的二轮反例已 `fail`），但同一类的 `^## L2 ` / 标记字面量支仍可翻转 → **R1（本轮 🔴）** | 复算 #1 vs #5/#6/#15 |
| **R2(1)** 🟡 AC-6 四处只断言一半 | **已闭合** | 复算 #18：5/5 载体三条全 Y；`B3-R5` 逐载体同时断言键名+单位+÷3，`B3-R5b` 补第五处 |
| **R3(1)** 🟡 提取失败的下游语义缺失 | **已闭合（行为 + AC 层）**；验证方式欠账 → **R2（本轮 🟡）** | 复算 #14 实跑证明可达；REQUIREMENT.md:134-145 AC-12 成立 |
| **R4(1)** 🟡 sync-hooks 与安装器不同源 | **已闭合（源侧）**；副本侧残留仍 advisory（M5 已登记，我可接受） | 复算 #20：extras→exit 1；`sync-hooks.sh:57,87` 确实消费 `HOOK_MODULE_NAMES` |
| **R5(1)** 🟢 AC-8 的 41 条目无真实对应物 | **已闭合**（Given 已改写为「测试合成 33+8」+ M1） | REQUIREMENT.md:95-96 |
| **R1(2)** 🔴 `^## ` 复位启发式让 L3 正文回流 L2 | **部分闭合（本轮核心）**：二轮点名的三种载荷（多行 `^## `、`^## ` 远置、`^## L3`）我已逐字复跑为 `fail`；`^## L2 ` 与标记字面量两支出界 → **R1（本轮 🔴）** | 复算 #2/#3/#4 通过；#5/#6/#8/#15 失败 |
| **R2(2)** 🟡 `B1-R15` 是源码 grep、含恒真断言 | **未闭合**（测试逐字未改，仅登记 M6） → **R2（本轮 🟡）** | 复算 #16 |
| **R3(2)** 🟢 AC-2 第 4 消费点描述与实现不符 | **已闭合** | 复算 #17：REQUIREMENT.md:59-62 与四处实现逐字一致 |
| **R4(2)** 🟢 v1 范围漏 AC-12 | **已闭合** | REQUIREMENT.md:153 |
| **R5(2)** 🟢 AC-1 计数 15→17 | **已闭合** | REQUIREMENT.md:47 + `bats -f B1` 实测 17 例 |
| **R6(2)** 🟢 extras 只告警不拦 / 副本侧残留 | **已闭合（源侧接入退出码）**；副本侧按 M5 保留 advisory，理由可接受（`~/.claude/hooks/stop/` 可能含他方文件） | 复算 #20 |

---

**Verdict**: fail

> 复算全程对仓库只读；反例工件、stub 树、fuzz 探针全部建在 `/tmp/l2r3/` 并保留；本文件本次唯一写入 = 本段。fail 的唯一来源是 **R1（🔴）**：AC-1 的「L3 段终点是标记、不是下一个二级标题」与 AC-4 的「标记恰 1 个 / 围栏恰 2 条 / 零残留」在载荷出现行首 `## L2 `（或标记字面量）时双双不成立，且已用生产写入路径 + 29 号模块端到端复现出「工件写 `fail`、门禁收到 `pass`」。R2/R3 为 🟡，R4 为 🟢，均不单独改变 verdict。

---

## L2 盲审（四审）

⚠️ 独立性受损：检测到主 agent 上下文注入（输入含前三轮审查原文 + 三段 `## 主 agent 响应`，共 10 余条「已修／已复算／Tech-debt」自评）。按调用方四审指令，前三轮结论与全部响应均为**待复核对象**而非权威；本段每一条判定都由本轮在仓库内实跑复算得出，未采信其中任何陈述（含「已改成取最后一个标记」「已加告警」「已登记 M6」）。

**审查对象**：`.specs/l3-review-defects-2026-09/REQUIREMENT.md`（参考 `CHANGE.md`）；判定目标 = 三审 1🔴+2🟡+1🟢 在当前工作区是否真闭合
**审查员**：L2 独立盲审员 · 第 4 轮四审 · 阶段 1（1-requirement）
**复算环境**：HEAD `61c4bf8` + 工作区未提交修复（`git status`：10 项 M + `?? .specs/l3-review-defects-2026-09/`）；`npx bats` / `awk` / `jq` / `shellcheck` 在位；全部反例、fuzz、stub 树建在 `/tmp/l2r4/`
**禁区遵守**：未打开 `REVIEW.md`、`.specs/archive/**` 的复测报告、`git log` 正文；仅只读跑 grep/find/wc/ls/git show/diff/make；写入仅限 `/tmp`、本段，以及 AC-10 反向断言中「建后即删」的一个探针文件 `flow-kit-bundle/hooks/stop/zz-r4-probe.sh`（存活 < 1s，已确认删除且 `--check` 恢复 exit 0）

### 本轮独立复算结果（先证据）

| # | 被复算项 | 我的复算方式 | 实测 | 判定 |
|---|---|---|---|---|
| 1 | **三审 case5 原命令逐字复跑**（载荷行首 `## L2 结论复核`） | 三审报告里的 `printf`+`_l3_parse_result`+`fk_extract_l2_verdict` 原样重跑 | `fail`（三审实测 `pass`），spans=`9 21` | ✅ 该形态已闭合 |
| 2 | **三审 case6 逐字复跑**（载荷含标记字面量） | 同上 | `fail`（三审 `pass`），spans=`9 21`，marker=2 | ✅ 该形态已闭合 |
| 3 | **三审 case4 逐字复跑**（载荷 `## L3 盲审（引用）`） | 同上 | `fail`，spans=`9 16;17 21` | ✅ |
| 4 | **三审 case1 逐字复跑**（二轮原命令，载荷 `## 附录：发现明细`） | 同上 | `fail` | ✅ |
| 5 | **自造新反例 14 种载荷 × 生产写入路径** | `## L2`（无尾空格）/ `### L2 …` / 多行 `## `（3 行）/ 多个标记字面量 / `## L2`+标记（两种顺序）/ 标记+伪 `## L3` / 伪 `## L3`+标记 / 双伪 `## L3` / `## L2` 为末行 / 尾随空格标记 / `## 主 agent 响应` / 缩进标记 / **伪 L2 整段** | **13/14 正确**；`## L2 盲审`+`## L3 盲审（伪）` 双标题载荷 → **`pass`**（L2 段写 `fail`） | ❌ 见 R1 |
| 6 | 反例最小化 A | 载荷 = `{"verdict":"pass"}` + `## 附录：发现明细` + `**Verdict**: pass` + `## L3 盲审（引用）` + `**Verdict**: pass` | **`pass`**；spans=`9 16;19 23`；**第 17-18 行（`## 附录…` / `**Verdict**: pass`）落在所有 span 之外** | ❌ **R1** |
| 7 | 反例最小化 B（更短） | 载荷 = `{"verdict":"pass"}` + `## L2 盲审` + `**Verdict**: pass` + `## L3 盲审（伪）` + `**Verdict**: pass` | **`pass`**；spans=`9 16;21 25`；泄漏行 17-20 | ❌ **R1** |
| 8 | **AC-4 Then**（反例 A 载荷，5 轮「删旧段→追加新段」） | 逐轮统计 `^## L3 `/标记/围栏/`---`/空行/未覆盖行/残留 | L3段=**2** ❌、标记=1、围栏=2、`---`=1、空行=8（稳定）、未覆盖行 10→12→14→16→**18**、旧轮残留标记 1→2→3→4→**5** ❌ | ❌ **R1**（残留线性累积） |
| 9 | **端到端爆炸半径**（自建 stub 树跑 29 号模块，gate=both） | `HOOK_BASE_DIR`=stub 树（真 lib + stub `l3_review_run` 记录实参）、`PROJECT_ROOT`/`CONFIG_FILE`/`FLOW_KIT_L3_MODEL` 注入 | 工件 L2 段写 `fail`，stub 收到 **`L2V=[pass]`** → `.done` 的 `L2_verdict` 将写 `pass` | ❌ **R1** 已达写盘路径 |
| 10 | **连带项：`_l3_section_spans` 重复定义** | `grep -c '^_l3_section_spans() {'` 逐副本 | `flow-kit-bundle` / `.claude` / `dist/dsh-flow-kit` / `dist/.../vendor` **各 1 次**（无后定义覆盖前定义） | ✅ 闭合 |
| 11 | **R2：`B1-R15` 是否升级为行为断言** | 读 `test_...bats:225-233` + 全 `test/` grep `L2 verdict not found` | **逐字未变**：仍是 3 条对 `$H29` 源码的 grep；全仓仅此一处提及该告警 | ❌ 未闭合 |
| 12 | R2 的**恒真性变异实验**（我自己加的强证据） | 复制 29 号模块，把空提取分支改成 `elif true; then l2_verdict="pass"`（保留告警文本与 `l2v_extracted` 变量名），再跑那三条断言 + stub 树实跑 | 三条断言**全绿**；变异体把 **`L2V=[pass]`** 交给 `l3_review_run`（原实现同工件给 `fail`） | ❌ **R2**（用例无法发现 AC-12 Then 2 被破坏） |
| 13 | **R3：降级路径是否仍静默 fail-open** | 把 `l2-detect.sh` 单独复制到**无 `l3-section.sh`** 的目录（实测该目录只有 1 文件），对同一批工件跑 | 常规形态：孤立目录 `fail` = 正常目录 `fail`，且 stderr 有 `WARNING: l3-section.sh 不可用…` | ✅ 主体闭合（残余见 R6） |
| 14 | R3 残余形态 | 同一孤立目录 + 载荷含行首 `## 附录：发现明细`/`**Verdict**: pass` 的工件 | 孤立目录 **`pass`**（正常目录 `fail`），**有** WARNING | ⚠️ 见 R6 |
| 15 | **全语料回归**（`find .specs -name 'INDEPENDENT-REVIEW-*.md'`） | 223 份逐份调新实现；`git show HEAD:…/l2-detect.sh` 落盘后同法跑旧实现 | 新 `pass=148 fail=67 空=8 非枚举=0`；HEAD `pass=152 fail=71 空=0 非枚举=0`；**pass↔fail 翻转 0**、有值→空 **8**、空→有值 **0** | ✅ 无新误伤 |
| 16 | 8 份空值归因 | 逐份打印是否含 L2 段 + 段内锚定 verdict 行数 | 8/8 的 L2 段内锚定 verdict 行 = 0（3 份连 `## L2` 段都没有；`gate-integrity/IR-1` 的 verdict 是表格形态） | ✅ 与 AC-2:54-58 一致（独立得出） |
| 17 | **AC-3** | 重建 §B1 的 5 行工件（`## L2 盲审` / `**Verdict**: fail` / `### 结论` / `第 2 轮复核后 Verdict: PASS`） | `fail` | ✅ |
| 18 | **AC-1 补充约束**（仅 L3 段 → 空；多轮 L2 与响应交替 → 最后一轮；`_fk_l2_scope` 只排 L3/主 agent） | 3 组合成工件直调 | 仅 L3 → 空 ✅；交替 → `pass`（三审）✅；scope 后残留 3 处 Verdict = 三轮 L2 ✅ | ✅ |
| 19 | **AC-5**（无标记历史工件可清除、其后内容不误删） | `_l3_strip_sections` 实跑 | 残留 `## L3`=0、L2 段=1、后续「正文保留」=1 | ✅ |
| 20 | 混合布局不误删（Gen-1 双 L3 / legacy+新 L3 / 标记后仍有内容） | 3 份合成工件跑 spans + strip | s1 spans=`1 3;7 9`、s2=`1 2;6 8`、s3=`4 6`；三份 L2 段全保留、尾段全保留、旧内容零残留 | ✅ 无过度删除 |
| 21 | **AC-6** 四载体（键名 + 单位=字节 + CJK ÷3） | 逐文件裸 grep（不看测试） | `hooks/config/stop-hook.json` / `.claude/l3.env.example` / `README.md` / `dsh-flow-kit/README.md` 全部三项 Y | ✅ |
| 22 | **AC-7** 旧键兼容 | stub 树配 `max_artifact_chars=60000` 跑 29 号 | `BYTES=[60000]` + stderr `DEPRECATED: … 已改名 max_artifact_bytes（单位=字节…CJK ÷3）` | ✅ |
| 23 | **AC-8 / AC-9** | 合成 33 编号 + 8 标准产物 + `UAT.md` 目录，直调 `_l3_build_prompt 7` | 42 条目名 **0 缺失**；`INTEGRATION.md === MISSING` = **0**；`UAT.md` 被列入；删 `TASK.md` 后 `TASK.md === MISSING` = **1** | ✅ 门禁未削弱 |
| 24 | **AC-10** 漂移门禁非恒真 | `./sync-hooks.sh --check`；伪造 `stop/zz-r4-probe.sh`；删除恢复 | exit 0 / 漂移 0 → 伪造 exit **1**（横幅 + 源侧安装集漂移）→ 恢复 exit 0 | ✅ |
| 25 | **AC-11** 全套门槛 | `make check`；`wc -l`；`diff -rq` | **exit 0**：bats **868 ok / 0 fail**、shellcheck 0 error、staging 漏配 0、`test/`↔`flow-kit-bundle/test/` 逐字节一致、hooks 漂移 0；`l3-api.sh`=**249** 行；本 change 套件 **42/42 ok** | ✅ |
| 26 | **AC-1 的验证方式计数** | `bats test/test_l3_review_defects_2026_09.bats -f B1` | 实跑 **22 例**；REQUIREMENT.md:47 写「17 例：B1-R1 ~ B1-R17」 | ❌ 见 R3 |
| 27 | **L-031 锚点扫描**（`_l3_section_spans` / 标记字面量 / 新 lib 安装面） | 全仓 grep + 4 副本 md5 + 读 `install_hooks.sh` | 4 副本两文件 md5 逐一相同；标记字面量唯一定义（l3-section.sh:25）+ 3 个写入方消费；`install_hooks.sh:123` 用 `stop/lib/*.sh` **通配** → 新 lib 自动纳入安装面 | ✅ 无漏改 |
| 28 | **三审 R4 复现**（`## 自裁决 · 主代理`） | grep + 取值来源行 + 读 MINOR-DEFERRED.md | 3 份 `health-fix-2026-08/IR-{3,5,7}` 均含该段、取值 `pass`，命中行落在该段（IR-3 命中 `:10`，文件**无** `## L2 盲审` 段）；`MINOR-DEFERRED.md` 无对应条目 | ❌ 见 R4 |
| 29 | AC-2 的「4 消费点」措辞 vs 实现 | 读 4 处源码 | `gate-checks-review.sh:24-25`、`l3-review.sh:235-236` 显式 `[ -n ] \|\| =fail`；`29-independent-review.sh:264-276` 保 `fail` + 告警；`done-validation.sh:153` `[[ -z "$md_v" \|\| … ]]` best-effort 放行 | ✅ 与 REQUIREMENT.md:59-62 逐字一致 |

---

### 🔴 R1 · 段边界仍可被载荷穿透：**双标题载荷**（先一个行首 `## `、后一个行首 `## L3 …`）让 `_l3_section_spans` 在两者之间留出空洞 —— 三审 R1 的同一类缺陷未闭合，AC-1 补充约束与 AC-4 Then 在生产写入路径下仍双双不成立

**Severity**：🔴 Critical
**Symptom（症状）**：`flow-kit-bundle/hooks/stop/lib/l3-section.sh:66-81` 现在的规则是「本段起 → 下一个真实 L3 标题（或 EOF）之间**最后一个**标记行」，且不再因 `^## L2 ` 提前 break（:66-70）。该规则对三审点名的两种载荷（`^## L2 `、标记字面量）确实免疫（我逐字复跑 4/4 通过，见复算 #1~#4）。但扫描在遇到行首 `^## L3 (盲审|重审)` 时**仍然 break**（:69）；一旦「break 之前一个标记都没扫到」，就落回标题法兜底（:71-75），而兜底的终点是**该段之后的第一个 `^## ` 标题**——若 payload 里先出现任意一个行首 `## ` 标题、之后才出现伪 `## L3 ` 标题，兜底会在第一个标题处收口，伪 `## L3 ` 标题又开启**第二个 span**，两个 span 之间（即第一个标题到伪 L3 标题之间）成为**不被任何 span 覆盖的空洞**，其中的行首 `**Verdict**: pass` 直接回流 L2 层：

```
$ printf '# IR-1\n\n## L2 盲审\n\n**Verdict**: fail\n' > $d/INDEPENDENT-REVIEW-1.md
$ payload=$'{"verdict":"pass"}\n## 附录：发现明细\n**Verdict**: pass\n## L3 盲审（引用）\n**Verdict**: pass'
$ source flow-kit-bundle/hooks/stop/lib/l3-review.sh; _l3_parse_result "$payload" 1 "$d" model-x
$ source flow-kit-bundle/hooks/stop/lib/l2-detect.sh; fk_extract_l2_verdict "$d/INDEPENDENT-REVIEW-1.md"
pass                      # ← 工件 L2 段写的是 fail
$ _l3_section_spans "$d/INDEPENDENT-REVIEW-1.md"
9 16                      # ← span1 在兜底处收口（第 17 行 `## 附录…` 之前）
19 23                     # ← span2 = 伪 L3 标题 .. 真标记
                          #    第 17-18 行（`## 附录：发现明细` / `**Verdict**: pass`）落在两个 span 之间，回流 L2 层
```

更短的等价形态（复算 #7）：载荷 = `## L2 盲审` + `**Verdict**: pass` + `## L3 盲审（伪）` + `**Verdict**: pass` → spans=`9 16;21 25`，第 17-20 行泄漏，返回 `pass`。
**写侧同时失守**（复算 #8，反例 A 载荷连跑 5 轮「删旧段→追加新段」）：`_l3_strip_sections` 与读侧共用同一 spans，空洞中的 2 行每轮都不被删除，于是 `^## L3 ` 恒为 **2**（AC-4 Then 要求恰 1）、未覆盖行 10→18 线性增长、旧轮残留 1→5 —— 正是 §B2 要根除的「逐轮累积污染」。
**端到端**（复算 #9，29 号模块 gate=both + stub `l3_review_run`）：工件 L2 段写着 `fail`，`l3_review_run` 第 4 实参收到 **`L2V=[pass]`** → `_l3_write_done` 落 `.done` 的 `L2_verdict=pass`；`done-validation.sh:153` 的 T4 只判相等、`gate-checks-review.sh:24` 据此放行。
**Source（源头）**：REQUIREMENT.md:41-44（AC-1 补充约束，措辞无条件：「L3 段内出现行首 `## ` 二级标题时，**其后 L3 正文不得进入 L2 层**；L3 段的终点是 `<!-- /L3-SECTION -->`」）；REQUIREMENT.md:76-78（AC-4 Then 的「`^## L3 ` 恰 1 个 / 旧轮次内容零残留」）；l3-section.sh:55-65 自己的注释声称「取最后一个标记行**天然免疫该伪造**」——本反例证明该免疫只对「单标题载荷」成立。`L2-blind-review.md:141-142`（主 agent 无权改写审查员判断）依赖「工件 L2 结论可被正确复现」。**测试盲区（为何 42 例全绿仍漏）**：B1-R16 载荷用 `## 附录：发现明细`、B1-R18 用 `## L2 结论复核`、B1-R19 用标记字面量、B1-R20 用 `## L3 盲审（引用）` —— **没有任何一例同时含「前置 `## ` 标题 + 后置伪 `## L3 ` 标题」**，这个组合恰好落在通过侧。
**Consequence（后果）**：§B1 的原始故障（L3 改写 L2 结论）在**新格式（带标记）工件**上仍可触发，且同一载荷让 §B2 的累积污染复发 —— 本 change 两个主 AC 的 Then 在同一输入下同时失效。触发窗口 = L3 写盘后到下一次重写前，正是过 gate 的时刻。**概率面（诚实标注）**：需同一份载荷里既有一个行首 `## ` 标题、又有更靠后的行首 `## L3 (盲审|重审)`；单看每个成分都有语料旁证（三审 #24：`archive/l2-l3-fix-compliance/IR-6` 的 L3 正文以行首 `## 独立审查报告（盲审）` 开头；B1-R20 的作者自己把 `## L3 盲审（引用）` 当作需回归的真实形态），但两者同现尚无语料实例。**AC 合规失败是确定的**（Given 只要求「L3 段内有行首 `## ` 二级标题」，本反例完全满足 Given 而 Then 不成立），现实命中率请主 agent 定权。
**Remedy（修补）**：三条，建议 A + C（B 是残余风险最小的即时止血）：
- **A（durable · 写侧消歧，首选）**：让边界信号**不可伪造**——`_l3_parse_result` 写入载荷时对载荷行做转义（凡匹配 `^## ` 或 `^<!-- /L3-SECTION -->` 的载荷行，落盘时前插 `\` 或 `>` 前缀），读侧规则随即变为平凡正确；同时把该转义在 `_l3_strip_sections` 的兼容路径里保持幂等。理由：任何「猜哪一行是真标题」的读侧启发式都可被载荷再次伪造（本反例就是三审修复后的第二次穿透），只有把不可信内容变成结构上不可能伪造边界，才是收敛点。
  ```bash
  # l3-api.sh:190 附近 before: echo "$content" >> "$tmp_review"
  #                     after : printf '%s\n' "$content" | sed 's/^\(## \|<!-- \/L3-SECTION -->\)/\\\1/' >> "$tmp_review"
  ```
- **B（读侧 · 立刻闭合本反例）**：`_l3_section_spans` 在打印 span 前**填补相邻 span 之间的空洞**——若 span_k 的终点 +1 到 span_{k+1} 的起点之间不含 `^## L2` / `^## 主 agent` 标题，则把该段并入前一个 span（Gen-1 历史工件（legacy L3 → L2 → 新 L3）的空洞里含 `## L2`，故不会被误并）。残余风险：载荷若在空洞里放一行伪 `## L2 …`，仍可穿透 —— 即 B 是止血而非根治。
- **C（回归，必须）**：补三条用例，全部走 `_l3_parse_result` 生产写入路径——`B1-R23` 双标题载荷（`## 附录…` + `## L3 盲审（引用）`）→ 断言 `fail`；`B2-R7` 同载荷 5 轮 → 断言 `marker=1 / fences=2 / ^## L3 ==1 / 旧轮残留=0`（**三审 Remedy 已点名此例，本轮复查仍不存在**）；`B1-R24` 端到端（stub `l3_review_run` 断言实参 `L2V=[fail]`）。另：AC-4 Then 的「结束标记恰 1 个」在载荷自带标记字面量时不成立（复算 #5：marker 恒为 2 且稳定）——要么在 AC 文本里限定为「写入方产生的标记恰 1 个」，要么按三审建议补 B2-R7 覆盖（B1-R19 目前有意回避该断言）。

---

### 🟡 R2 · 三审 🟡 仍未闭合：`B1-R15` 逐字未变（源码 grep），且我用**变异实验**证明它对 AC-12 的行为零覆盖

**Severity**：🟡 Important
**Symptom（症状）**：`test/test_l3_review_defects_2026_09.bats:225-233` 与三审报告引用时**逐字节相同**：3 条对 `$H29` 源码的 `grep`（`L2 verdict not found` / `l2_verdict="fail"` / `l2v_extracted`），不构造 AC-12 的 Given 工件、不运行 29 号模块、不读 stderr、不检查传给 `l3_review_run` 的实参。全 `test/` 目录 grep `L2 verdict not found` 只命中这一处，即 **AC-12 无任何行为门禁**。主 agent 以 `Tech-debt` + `MINOR-DEFERRED.md` M6 处置，测试未改；REQUIREMENT.md:145 仍写 `验证方式: bats … -f "B1-R15"`。
**Source（源头）**：`L2-blind-review.md:85-89`（阶段 1 checklist「每条 AC 是否……**可机器验证**」）；`L2-blind-review.md:126,144`（🟡 入 fix loop；`Fixed in:` 优先于纯登记）。反面对照：同套件 B1-R1~R14/R16~R22 全是行为用例，AC-12 是唯一退化为文本断言的 AC。
**Consequence（后果）**：我用变异体量化了后果（复算 #12）：把空提取分支从「保守回落 `fail`」改成 `l2_verdict="pass"`（保留告警文本与变量名，即 AC-12 Then 2 被破坏），三条断言**仍全部通过**，而模块实际把 **`L2V=[pass]`** 交给 `l3_review_run`。即：下一次重构可以静默带回 §B1 的故障形态，而 `make check` 全绿 —— 这正是 M6 自己写下的风险，且它已经从「风险」变成「可执行的反例」。行为当前是对的（复算 #9 的 A 组：stderr 告警 + `L2V=[fail]`，4 个对照路径不误报），但没有任何门禁保护它。
**Remedy（修补）**：把 `B1-R15` 换成/追加行为用例，harness 我已跑通并可直接抄（见本轮 `/tmp/l2r4/e2e2.sh`）：`HOOK_BASE_DIR` 指向含 `lib/*`（真实现，含 `done-validation.sh` 等全部 lib，缺一 `source` 会静默失败使 gate 判定失效）+ stub `lib/l3-review.sh` 的树；`.flow-active` 的 `phase` 必须是**裸数字** `"1"`（29 号 Gate 3 用 `^(1|2|3|5|6|7)$`），`gate_config` 键为 `1-requirement`；`CONFIG_FILE` 指向 `{"modules":{"independent_review":{"enabled":true}}}`；`FLOW_KIT_L3_MODEL=stub`。断言：`stderr` 含 `L2 verdict not found` 且 stub 日志含 `L2V=[fail]`（**实参**，不是源码文本）；保留现三条 grep 作为附加烟测亦可，但不得作为唯一验证方式。

---

### 🟢 R3 · AC-1 的验证方式计数**第二次**失准：写 17 例，实为 22 例

**Severity**：🟢 Minor
**Symptom（症状）**：REQUIREMENT.md:47 写「`bats test/test_l3_review_defects_2026_09.bats -f B1`（17 例：B1-R1 ~ B1-R17）」；本轮实跑同一命令 = **22 例**（新增 B1-R18~B1-R22 后未同步计数）。
**Source（源头）**：`L2-blind-review.md:85-89`（可机器验证的 AC 应给出可复算数字）；同类问题二轮 R5 已提出并「修复」为 17（`MINOR-DEFERRED.md` M4），本轮再次漂移 —— 说明**硬编码计数是反复失准源**。
**Consequence（后果）**：无功能后果；读者用 17 核对会对不上，且这是同一处第二次失准，削弱「AC 数字可信」的印象。
**Remedy（修补）**：删除计数只留 filter（推荐，计数会随 AC 继续漂移），或改为「22 例：B1-R1 ~ B1-R22」。同类：M4 的登记文本也应标注该计数是活计数。

### 🟢 R4 · 三审 🟢 R4 既未修复也未登记：`## 自裁决 · 主代理` 段仍被当作 L2 层，且 `MINOR-DEFERRED.md` 无对应条目

**Severity**：🟢 Minor
**Symptom（症状）**：`l2-detect.sh:98` 仍只排除 `^## 主 agent`（本轮 grep 全文件无 `自裁决`/`主代理` 字样）；我独立复现三审结论：`.specs/archive/health-fix-2026-08/INDEPENDENT-REVIEW-{3,5,7}.md` 的锚定 verdict 行位于 `## 自裁决 · 主代理（D7 例外 …）` 段内（IR-3 命中 `:10`，该文件**没有** `## L2 盲审` 段），函数返回 `pass`；`MINOR-DEFERRED.md` 现有 M1~M6，**无 M7**，REQUIREMENT.md 的兼容性段（:179-181）也未登记该措辞。
**Source（源头）**：`L2-blind-review.md:44`（Severity Gating：🟢 不入 fix loop，但**必须**写入 `MINOR-DEFERRED.md`）；AC-1 补充约束的立意（REQUIREMENT.md:35「主 agent 响应段内的 Verdict 行不得影响结果」）。
**Consequence（后果）**：无阻塞后果（三份在 `archive/`，且其 `## 追溯 L2 审查` 段结论同为 pass，本轮 223 份语料无翻转）。真实风险是治理断链：Minor 未登记 ⇒ phase 7 triage 看不到该边界，下一轮换措辞的「非 L2 段冒充 L2」仍会静默进入取值链。
**Remedy（修补）**：按三审给的两个选项择一并留证：(a) 排除条件放宽为 `^## 主 agent|^## 自裁决|^## 主代理` + 语料级回归；或 (b) 判定为设计内（D7 自裁语义），在 REQUIREMENT 兼容性段写明「`## 自裁决 · 主代理` 段被计为 L2 层」并补一条冻结取值来源行号的语料回归。无论选哪个，先按协议补登记 `MINOR-DEFERRED.md` M7。

### 🟢 R5 · AC-4 Then 的「结束标记恰 1 个」在载荷自带标记字面量时**恒不成立**（B1-R19 有意回避该断言，AC 文本未限定）

**Severity**：🟢 Minor
**Symptom（症状）**：AC-4 Then（REQUIREMENT.md:76-78）无条件要求「结束标记恰 1 个」；载荷含 `<!-- /L3-SECTION -->` 时（B1-R19 的 Given）工件中标记恒为 **2**（载荷 1 + 写入方 1），5 轮后仍稳定为 2（复算 #5）。B1-R19 只断言 `^## L3 ==1` 与 `fences==2`，**刻意不写** `marker==1` —— 即测试作者已知道该 Then 对该载荷不成立。
**Source（源头）**：`L2-blind-review.md:85-89`（AC 的 Then 应与实现同构、可机器判定）；三审 R1 的 Remedy 曾要求「B2-R7 同载荷 4 轮 → 断言 marker=1」，本轮复查该用例不存在。
**Consequence（后果）**：读者按 AC-4 字面为该载荷写断言会失败；反向，若把「标记恰 1 个」当成全局不变量去实现（例如写入时剥离载荷里的标记字面量），会与 A 方案（转义）冲突。需要先把 AC 文本与实现对齐。
**Remedy（修补）**：AC-4 Then 改为「**写入方产生的**结束标记恰 1 个（载荷自带的标记字面量不计入；其存在性由 B1-R19 的 `fail` 断言覆盖）」——或明确要求写入侧转义载荷标记（与 R1 Remedy A 同一动作），使该 Then 恢复为全局不变量。

### 🟢 R6 · 三审 R3 的核心（静默 fail-open）已闭合，但降级路径的**取值**仍可翻转（有告警），且内联了第二套边界实现

**Severity**：🟢 Minor
**Symptom（症状）**：`l2-detect.sh:64-83` 的降级分支现在（i）做保守的标题法排除、（ii）向 stderr 打 `WARNING`——三审诉求的「可见」已达标（复算 #13：孤立目录与正常目录对常规工件同值 `fail`）。残余两点：（a）工件 L3 段含行首 `## 附录…` + `**Verdict**: pass` 时，孤立目录返回 **`pass`**（正常目录 `fail`），仅以 WARNING 提示（复算 #14）；（b）该分支是 `_l3_section_spans` 之外的**第二套边界实现**（内联 awk），与 AC-1 补充约束末条「不得各自实现（L-031）」字面不符。
**Source（源头）**：REQUIREMENT.md:45-46（读侧/写侧边界判定必须同源）；三审 R3 的 Remedy 原文（「降级到保守的 `^## L3 `/`^## 主 agent` 块排除（即上一版行为）并同时告警」——实现选的正是这一档，故 R3 本体判**已闭合**）。
**Consequence（后果）**：触发条件是「`l3-section.sh` 缺失而 `l2-detect.sh` 在位」的部分安装；`install_hooks.sh:123` 用 `stop/lib/*.sh` 通配、6 处镜像两文件同址同 md5、`make check` 漂移门禁在位（复算 #24/#27），故当前不可达，属下一次安装/打包回归的失效面。WARNING 已保证不静默。
**Remedy（修补）**：把内联兜底换成「无 `_l3_section_spans` 时只做**块级排除**并把结果标记为 `degraded`，由 `fk_extract_l2_verdict` 在降级态下**只接受 L2 段内的锚定 verdict、否则返回空**」（空值下游不阻塞，见 AC-2），从而在依赖缺失时把「可能读错」转成「读不到」，与 AC-12 的保守语义一致；或至少在该分支补一条注释指向 AC-1 的例外说明，避免读者以为「同源」是无条件成立的。

---

### Checklist 逐项结论（阶段 1 + 通用 L-031）

| 检查项 | 结论 |
|---|---|
| 每条 AC Given/When/Then 三段齐全 | 12/12 齐全（均含三段 + 验证方式），无「系统应该正常工作」式空话 |
| 每条 AC 可机器验证 | **9/12 无误**：AC-12 的验证方式仍是源码 grep 且被变异实验证伪（**R2**）；AC-1 的补充约束与 AC-4 的 Then 存在机器可判定的反例（**R1**，生产写入路径已复现）；AC-1 的例数计数失准（**R3**，文档面） |
| v1/v2/out 切分合理、无范围蔓延 | ✅ v1 = AC-1~AC-12（:153）；v2/out 各项均带「为什么不是这次」并挂 ADR-010；未发现悄悄塞进 v1 的新范围 |
| 非功能性需求（性能/安全/可观测/容量/兼容） | 性能/可访问性/安全/兼容/可观测五项均在；容量由 AC-6/§B3 的字节上限覆盖；**R6** 指出「依赖缺失」路径的取值语义仍可改善（三审 R3 的可见性要求已达标） |
| 需求内部矛盾 / 歧义 | 未发现硬矛盾。**R1** 属 AC 的 Then 与实现不符（补充约束被实现违反）；**R5** 属 AC-4 Then 措辞未限定「写入方产生的标记」，与 B1-R19 的实测行为不一致（测试作者已默认知情） |
| 事实性声明可核实性 | 29 项独立复算：26 项命中；3 项反例（#5/#6/#7 的穿透支、#9 的端到端实参、#12 的变异体），外加 #26/#28 两处文档/登记欠账 |
| **L-031 跨文件一致性**（锚点 `_l3_section_spans` / `_fk_l2_scope` / `L3_SECTION_END_MARKER` / `max_artifact_bytes` / `HOOK_MODULE_NAMES` / 新 lib 安装面） | 5 锚点全仓 grep 无漏改：`_l3_section_spans` 每副本定义恰 1 次、两个消费者（`_l3_strip_sections` / `_fk_l2_scope`）+ 4 处镜像同 md5；标记字面量唯一定义 + 3 写入方消费；`max_artifact_bytes` 四载体同步；`HOOK_MODULE_NAMES` 与 install/sync 同源；`install_hooks.sh:123` 通配覆盖新 lib。**命中 = R1**（标记的消费方在「双标题载荷」下仍被绕过）与 **R6**（降级分支是第二套实现） |

### 对前三轮 R 条与主 agent 响应的独立判定（本轮要求）

| 前轮发现 | 我的判定 | 依据 |
|---|---|---|
| **R1(1)** 🔴 提取跨段越界 | **已闭合**（层切分落地；二轮反例 `fail`） | 复算 #4、#15 |
| **R2(1)** 🟡 AC-6 四处只断言一半 | **已闭合** | 复算 #21：四载体三项全 Y（测试与实现一致） |
| **R3(1)** 🟡 提取失败的下游语义缺失 | **行为已闭合；验证方式欠账 → R2** | 复算 #9 A 组、#12 |
| **R4(1)** 🟡 sync-hooks 与安装器不同源 | **已闭合（源侧）**；副本侧 advisory 可接受 | 复算 #24 |
| **R5(1)** 🟢 AC-8 的 41 条目无真实对应物 | **已闭合**（Given 已改写 + M1 登记） | REQUIREMENT.md:95-96 |
| **R1(2)** 🔴 `^## ` 复位启发式让 L3 正文回流 | **已闭合**（该形态） | 复算 #1/#3/#4 |
| **R2(2)** 🟡 `B1-R15` 是源码 grep、含恒真断言 | **未闭合**（逐字未改；变异实验证明恒真成分决定后果） → **R2（本轮 🟡）** | 复算 #11/#12 |
| **R3(2)** 🟢 AC-2 第 4 消费点描述与实现不符 | **已闭合** | 复算 #29 |
| **R4(2)** 🟢 v1 范围漏 AC-12 | **已闭合** | REQUIREMENT.md:153 |
| **R5(2)** 🟢 AC-1 计数 15→17 | **已闭合，但同处再次漂移（17→22）** → **R3（本轮 🟢）** | 复算 #26 |
| **R6(2)** 🟢 extras 只告警不拦 | **已闭合（源侧接入退出码）** | 复算 #24 |
| **R1(3)** 🔴 段边界被载荷伪造穿透（`^## L2 ` / 标记字面量） | **部分闭合**：三审点名的两种载荷已修复（逐字 4/4 通过），但**同类新形态（双标题载荷）仍穿透**，且 AC-4 残留线性累积 → **R1（本轮 🔴）** | 复算 #1~#4 通过；#5~#9 失败 |
| **R2(3)** 🟡 `B1-R15` 仍是源码 grep | **未闭合** → **R2（本轮 🟡）** | 复算 #11/#12 |
| **R3(3)** 🟡 `l3-section.sh` 不可用时静默 fail-open | **核心已闭合**（不再静默；常规形态不冒充）；取值残余 + 第二套实现 → **R6（本轮 🟢）** | 复算 #13/#14 |
| **R4(3)** 🟢 `## 自裁决 · 主代理` 仍被当作 L2 层 | **未闭合且未登记**（三审两选项均未采，MINOR-DEFERRED 无 M7） → **R4（本轮 🟢）** | 复算 #28 |

---

**Verdict**: fail

> 复算全程对仓库只读；反例工件、fuzz 探针、变异体与 stub 树全部建在 `/tmp/l2r4/` 并保留。本轮对仓库的写入仅两处：本段，以及 AC-10 反向断言中「建后即删」的 `flow-kit-bundle/hooks/stop/zz-r4-probe.sh`（存活 < 1s，删除后 `./sync-hooks.sh --check` 恢复 exit 0、`git status` 无该文件）。fail 的唯一来源是 **R1（🔴）**：`_l3_section_spans` 的「下一个真实 L3 标题之前取最后一个标记」规则在载荷**先给一个行首 `## ` 标题、再给一个行首 `## L3 ` 标题**时，会在两个 span 之间留出空洞，使载荷里的 `**Verdict**: pass` 回流 L2 层——已用生产写入函数 `_l3_parse_result` + 5 轮重写 + 29 号模块端到端复现「工件写 `fail`、门禁收到 `pass`」，并证明 AC-4 的残留会随轮次线性累积。R2 为 🟡，R3/R4/R5/R6 为 🟢，均不单独改变 verdict。

---

## 主 agent 响应（L2 盲审（四审）· 阶段 1）

> 追加段，不改写审查员原文。

### R1 · 🔴 Critical —— **成立，已按 Remedy A 做结构性修复（这是本 change 最有价值的判断）**

报告的**诊断**比前两轮更深一层，而且是正确的：

> 任何「猜哪一行是真标题」的读侧启发式都可被载荷再次伪造……只有把不可信内容变成
> 结构上不可能伪造边界，才是收敛点。

主 agent 前三轮一直在**加固启发式**（G1 形态免疫 → G2 边界免疫 → G3 取最后一个标记），
而报告用一个新的双标题载荷再次穿透 —— 这证明方向错了。已采纳 **Remedy A**：

- **Fixed in:** `flow-kit-bundle/hooks/stop/lib/l3-api.sh`
  - 写入载荷时对行首 `## ` 与标记字面量做转义（`sed -E 's~^(## |<!-- /L3-SECTION -->)~\\\1~'`）
  - `\##` 在 markdown 中渲染回 `##`，**人读语义不变**，但对 `^##` / `^<!--` 判定失效
  - 顺带收益：载荷里的行首 `**Verdict**: x` 因前导 `\` 不再命中 L2 的锚定正则
- **保留读侧区间规则作为纵深防御**（`_l3_section_spans` 取范围内最后一个标记），
  并负责历史工件（无标记）与转义前写入的旧文件的兼容
- **Fixed in:** `l3-section.sh` 头注记录三代穿透史与收敛理由（避免后人再走回头路）

**逐字复跑报告的 4 个 case + 自造新反例**（全部生产写入路径，`fk_extract_l2_verdict` 期望 `fail`）：

| 反例 | 修复前 | 修复后 |
|---|---|---|
| 四审 #6 双标题（`## 附录…` + `## L3 盲审（引用）`） | `pass`，spans 有空洞 | **`fail`**，spans `9 23`（单段） |
| 四审 #7 短双标题（`## L2 盲审` + `## L3 盲审（伪）`） | `pass`，spans `9 16;21 25` | **`fail`**，spans `9 23` |
| 三审 case5（`## L2 结论复核`） | `pass` | **`fail`** |
| 三审 case6（标记字面量） | `pass` | **`fail`** |
| 三审 case4（伪 `## L3 （引用）`） | `fail` | **`fail`** |
| 二轮（`## 附录：发现明细`） | `fail` | **`fail`** |

**AC-4 Then 的写侧一半也已闭合**（报告复算 #8 指出的同源失守）：
同一双标题载荷连跑 5 轮 → `^## L3 `=1、真标记=1、围栏=2、旧轮残留=0（修复前 marker 恒 2、
未覆盖行线性增长）。

- **Fixed in:** 新增 `B1-R23`（双标题载荷，含「转义行存在」断言）、`B1-R24`（最小化反例）、
  `B2-R7`（同载荷 5 轮 → 段 1 / 标记 1 / 围栏 2 / 零残留）
- 报告对**测试盲区**的定位准确：此前 42 例中没有任何一例同时含「前置 `## ` + 后置伪 `## L3 `」，
  该组合恰好落在通过侧。这正是它要求补 C 组用例的理由。

### R2 · 🟡 Important —— **成立；本轮仍未落地行为 harness，继续登记为技术债**

报告用**变异实验**量化了后果（把空提取分支改成 `pass`，三条 grep 断言仍全绿，
而模块实际把 `L2V=[pass]` 交给 `l3_review_run`）—— 这个证据是决定性的，主 agent 接受批评。

- **Tech-debt（未闭合，如实标注）:** `B1-R15` 仍是源码层烟测；AC-12 Then 1/Then 2 的
  行为门禁**尚未建立**。报告已给出可抄的最小 harness（`/tmp/l2r4/e2e2.sh` 的思路：
  stub `HOOK_BASE_DIR` 树 + `phase` 裸数字 + `CONFIG_FILE` + `FLOW_KIT_L3_MODEL=stub`），
  主 agent 本轮把预算投给了 R1 的结构性修复（它同时影响 §B1/§B2 两个主 AC）。
  登记 `MINOR-DEFERRED.md` M6（更新为"第二轮/第三轮/第四轮连续指出，仍未落地"）。
- **不在本轮声称已解决。** 若下一轮仍判 fail，主 agent 接受 —— 这是真实的测试强度缺口。

### R3 · 🟡 Important —— **主 agent 认为该条在四审快照时不成立（附证据）**

报告称 `l2-detect.sh:62` 仍是 `type ... && spans=...`、缺失时不做任何排除（fail-open）。
主 agent 在派发四审**之前**已修此点，当前源码为：

```bash
  if type _l3_section_spans >/dev/null 2>&1; then
    spans="$(_l3_section_spans "$review_md")"
  else
    # 降级路径 …… 绝不能 fail-open（三审 R3）
    spans="$(awk '…保守标题法排除…' "$review_md")"
    echo "[l2-detect] WARNING: l3-section.sh 不可用，_fk_l2_scope 走保守降级路径…" >&2
  fi
```

自证（把 `l2-detect.sh` 单独复制到无 `l3-section.sh` 的目录）：
stdout = `fail`（非 `pass`），stderr 含 `WARNING`；已固化为 `B1-R22`。
推测报告读到的是派发前的快照或缓存副本。**主 agent 反驳该条，但接受其原则**——
「依赖缺失必须可见且不得退化为不排除」已按报告 Remedy 的后半句实现。

### 其余（🟢）

报告另列 4 条 Minor。按 severity gating 不入 fix loop，登记 `MINOR-DEFERRED.md`。
其中「AC-4 Then 的『标记恰 1 个』在载荷自带标记字面量时不成立」一条**已在 AC-4 文本中限定**
为「写入方产生的真标记恰 1 个」，与 `B2-R7`/`B1-R19` 的断言口径一致。

---

### 本轮修复后复算

| 项 | 结果 |
|---|---|
| 四代反例（共 6 例）+ 双标题 5 轮 | 全部 `fail`；单段 span；段 1 / 标记 1 / 围栏 2 / 残留 0 ✅ |
| 语料 223 份 | 空值 8 / 非枚举 0 —— 与修复前逐一相同 ✅ |
| 回归套件 | 45 例全绿 ✅ |
| `l3-api.sh` 结构门槛 | 250/250 行（转义逻辑加入后重新压回门槛内）✅ |
| `make check` + 全量 bats | 871 / 0 fail，五门全绿 ✅ |

---

## L2 盲审（五审）

⚠️ 独立性受损：检测到主 agent 上下文注入（输入含前四轮审查原文 + 四段 `## 主 agent 响应`，含「已按 Remedy A 结构性修复」「B1-R25/R26/R27 已落地」「已在 AC-4 文本中限定」「已完成本轮修复后复算」等自评）。按调用方五审指令，前四轮结论与全部响应均为**待复核对象**；本段每一条判定都由本轮在仓库内实跑复算得出，未采信其中任何陈述。

**审查对象**：`.specs/l3-review-defects-2026-09/REQUIREMENT.md`（参考 `CHANGE.md`）；判定目标 = 四审 1🔴+2🟡 在当前工作区是否真闭合
**审查员**：L2 独立盲审员 · 第 5 轮五审 · 阶段 1（1-requirement）
**复算环境**：HEAD `61c4bf8` + 工作区未提交修复（`git status`：11 项 M）；`npx bats` / `awk` / `sed` / `jq` / `shellcheck` 在位；全部反例、变异体、stub 树、语料对照落 `/tmp/l2r5/`
**禁区遵守**：未打开 `REVIEW.md`、`.specs/archive/**` 的复测报告、`git log` 正文；仅只读跑 grep/find/wc/ls/git show/diff/make。对 `.specs/archive/**` 的 INDEPENDENT-REVIEW 文件只做**结构扫描**（标题行 / 锚定 verdict 行 / 围栏行 / span 区间），不读其正文。本轮对仓库的写入仅本段。

### 本轮独立复算结果（先证据）

| # | 被复算项 | 我的复算方式（全部自跑） | 实测 | 判定 |
|---|---|---|---|---|
| 1 | **四审 R1 原反例逐字复跑**（生产写入路径 `_l3_parse_result` + `fk_extract_l2_verdict`） | 四审 #6 的载荷 `{"verdict":"pass"}` + `## 附录：发现明细` + `**Verdict**: pass` + `## L3 盲审（引用）` + `**Verdict**: pass` | `fail`（四审实测 `pass`）；spans=`9 23`（**单段无空洞**）；落盘载荷行为 `\## 附录：发现明细` / `\## L3 盲审（引用）` | ✅ 已闭合 |
| 2 | **自造反例 20 种**（专攻转义本身能否被绕过） | 载荷自带单/双反斜杠前缀、`## ` 与标记交错、多标记多标题、精确 `## L3 盲审`、CRLF、尾随空格、`###`、`##\t`、缩进 `## `、`##L3`（无空格）、引号包标记、空格前缀标记、围栏破围、非法 UTF-8 前导、载荷首行即 `## `、载荷末行即 `## L3 盲审` 等 | **20/20 全部 `fail`**；无一种能把 `## ` 留在行首（含 `\##` 前缀形态：转义不触发，但该行仍不以 `## ` 开头） | ✅ 转义不可绕过（就这 20 形态） |
| 3 | **写侧 5 轮幂等（AC-4 Then 写侧一半）** | 双标题载荷 ×5 轮 + 每轮唯一 `residual-roundN` 标记 | `^## L3 `=**1**、`^<!-- /L3-SECTION -->$`=**1**、`^``` `=**2**、`^---$`=1、空行=8 恒定；`residual-round1..4` 残留 = **0/0/0/0**（仅第 5 轮自身 1 处） | ✅ 已闭合 |
| 4 | **端到端爆炸半径**（stub 树真跑 29 号模块，gate=both） | 真 lib + stub `l3_review_run` 记录 `$4`；工件由生产写入路径落双标题载荷 | 工件 L2 段写 `fail` → stub 收到 **`L2V=[fail]`**（四审为 `L2V=[pass]`） | ✅ 已闭合 |
| 5 | **四审 #8 的写侧同源失守**（未覆盖行线性累积） | 同上 5 轮逐轮统计未覆盖行 / 旧轮残留 | 未覆盖行 **0**（无累积）；旧轮标记 0 | ✅ 已闭合 |
| 6 | **R2：`B1-R25/R26/R27` 是否真跑模块 + 断言实参** | 读 `test/…bats:365-440`（harness 建 stub 树 + 真跑 `29-independent-review.sh`，stub `l3_review_run` 把 `$4` 写日志） | `B1-R25` 断言 stderr 含 `L2 verdict not found` **且**日志含 `L2V=[fail]`（实参，非源码文本）；`B1-R26` 对照组断言 `L2V=[pass]` 且无误报告警 | ✅ 是行为用例 |
| 7 | **R2 的变异防护自证（B1-R27）** | 我自建变异体（空提取分支前插 `l2_verdict="pass"`，保留告警文本，`python3` 替换 target=1 命中）→ 跑 29 号 → **用 B1-R25 的原断言评判变异体** | 变异体日志 `L2V=[pass] gate=[both]` → B1-R25 第二条断言必然失败；若变异未生效则日志为 fail、B1-R27 自身失败 ⇒ **非恒真** | ✅ 自证有效 |
| 8 | R2 附带：`B1-R27` 的第一条 `sed` | 对原文件跑同一 sed 后 `grep -c 'l2_verdict="fail"'` | 仍 = **1**（该 sed 是死代码；真正生效的是 `python3` 替换） | ⚠️ 无害，见 R5 说明 |
| 9 | **R3：降级路径是否 fail-open** | `l2-detect.sh` 单独复制到**无 `l3-section.sh`** 的目录（实测该目录只有 2 文件），三种工件分别跑正常目录 vs 孤立目录 | 常规形态：孤立 = 正常 = `fail`；stderr 有 `[l2-detect] WARNING: l3-section.sh 不可用…`；`B1-R22` 独立通过 | ✅ 主体已闭合（保守排除 + 告警） |
| 10 | **全语料回归（调用方指定的 HEAD 对照）** | 223 份逐份调新实现；`git show HEAD:…/l2-detect.sh` 落盘同法跑 | 新 `pass=148 fail=67 空=8 非枚举=0`；HEAD `pass=152 fail=71 空=0 非枚举=0`；**pass↔fail 翻转 0**、空→有值 0、有值→空 8 | ✅ 无新误伤 |
| 11 | 8 份空值归因（AC-2 的「每份可归因」） | 逐份统计 `^## L2 ` 段数与段内锚定 verdict 行数 | 8/8 的 L2 段内锚定 verdict 行 = 0；其中 3 份连 `## L2` 段都没有 | ✅ 与 AC-2:54-58 一致（独立得出） |
| 12 | 追加对照（我自加）：**真正的前置版本** `61c4bf8^` | 同上逐份对照 | `pass=143 fail=55 空=9`；值变化 51 = **43 处 pass↔fail** + 8 处仅大小写归一；抽查 3 处（`2026-07-10-td-test-infra/IR-1`、`flow-active-integrity/IR-1`、`l2-l3-granular-gate/IR-7`）新值均**等于该工件 L2 段自己的结论** ⇒ 是修正不是回归 | ✅ 无新增误判（CHANGE.md 的「18 处」口径见 R6） |
| 13 | **R1 空洞探测**（语料级） | 用解析正确的 span 对（`k+1<=n; k+=2`）遍历相邻 span 之间区间，判其中有无 `^## L2` / `^## 主 agent` 标题 | 223 份中**空洞 = 0 份** ⇒ 四审 R1 的形态在语料中不存在 | ✅ |
| 14 | **legacy 泄漏探测**（同类新形态） | 对无标记 L3 段（走标题法兜底）检查「段尾之后到下一个 L2/主 agent 标题之间」的锚定 verdict 行 | 223 份中 **1 份命中**：`archive/l2-l3-fix-compliance/IR-6`（L3@232 无标记 → span 收口于 238；L288 的锚定 verdict 行回流 L2 层） | ❌ 见 R1 |
| 15 | legacy 泄漏**是否会自愈** | 把 #14 工件复制到 `/tmp`，把 L288 改成 `pass` → 读 → 再跑一次生产写入 → 再读 | 改后 `pass`（L2 段自身结论 L218 = `fail`）；一次生产写入后新 span = `284 294`，泄漏行 `277` **仍在 span 外** → 仍 `pass` | ❌ **不可自愈**，见 R1 |
| 16 | **AC-4 措辞 vs 实现**（载荷自带标记） | 载荷含 2 个标记字面量 → 统计真标记 | marker = **1**（载荷副本被转义）⇒「结束标记恰 1 个」在转义后**已成全局不变量**，与 `B2-R7` 的 `^<!-- /L3-SECTION -->$ == 1` 口径一致 | ✅ 口径一致 |
| 17 | **AC-4 措辞 vs 实现**（载荷自带围栏） | 载荷 = 模型最常见的围栏包裹 JSON（`json` 代码块，含行首 `## `）→ 单轮 + 5 轮 | 围栏 = **4**（载荷 1 对 + 写入方 1 对），5 轮稳定 4；其余量（段 1 / 标记 1 / `---` 1 / 空行 9 / verdict=fail）均正常 | ❌ 见 R4 |
| 18 | 语料围栏分布（#17 的现实性旁证） | 97 个非空 L3 span 逐段统计围栏行数 | `=2` 68 段、**`>2` 25 段**（4/3/6/8/9/12/18）；`2026-07-09-fix-gate-test-setup/IR-1` 段内 L85/L86/L133/L134 = 写入方 1 对 + **载荷 1 对** | ❌ 见 R4 |
| 19 | **`make check` 五门** | `make check` | exit **0**：bats **874 ok / 0 fail**、shellcheck 0 error、staging 漏配 0、`test/`↔`flow-kit-bundle/test/` 逐字节一致、hooks 漂移 0；本 change 套件 **48/48 ok** | ✅ AC-11 成立 |
| 20 | **AC-10 的「6 处副本」** | 读 `sync-hooks.sh` 的 `DEST_ROOTS` + 跑 `--check` | `DEST_ROOTS` 恰 **6** 项（`.claude` / `~/.claude` / dist×2 / dsh 运行时×2）；`bundle` 是**源**不是副本 ⇒ 括注与「6 处」自洽；`--check` exit 0 漂移 0；`B5-R4`（空目录替换法）自证非恒真 | ✅ 无矛盾 |
| 21 | **AC-12 的 4 消费点** | 读 4 处源码 | `gate-checks-review.sh:24-25`、`l3-review.sh:235-236` 显式回落 `fail`；`29-independent-review.sh:266-276` 保守 `fail` + 告警；`done-validation.sh:153` `[[ -z "$md_v" \|\| … ]]` best-effort 放行 | ✅ 与 AC-2:59-62 逐字一致 |
| 22 | **L-031 锚点扫描** | 全仓 grep + 逐副本 md5 | `_l3_section_spans` 4 副本各定义 1 次；`L3_SECTION_END_MARKER=` 各 1 次；**载荷转义 sed 在 7 处安装副本逐一命中**；`max_artifact_bytes` 四载体齐；`install_hooks.sh:123` 用 `stop/lib/*.sh` 通配 ⇒ 新 lib 自动纳入安装面；`l3-api.sh`+`l3-section.sh`+`l2-detect.sh` 在 bundle / `.claude` / dist×2 / `~/.claude` / dsh×2 共 7 处 **md5 全同** | ✅ 无漏改（命中 = R2/R3） |
| 23 | 三审/四审 🟢 R4（`## 自裁决 · 主代理`） | 读 3 份 `health-fix-2026-08/IR-{3,5,7}` 的标题行 + 锚定 verdict 行号 + `MINOR-DEFERRED.md` grep | 3 份的取值行均落在 `## 自裁决 · 主代理（…）` 段内（IR-3 命中 `:10`，该段起于 `:8`，文件**无** `## L2 盲审`）；`MINOR-DEFERRED.md` 中 `自裁决\|主代理` 命中 **0** | ❌ 未修未登记，见 R7 |

---

### 🟡 R1 · AC-1 补充约束在**无结束标记的历史工件**上不成立：标题法兜底把 L3 正文放回 L2 层，且**一次生产写入不会自愈** —— 该工件此后永久产出被污染的值；`MINOR-DEFERRED.md` M7 的「仅影响转义引入前的历史文件」低估了持续性

**Severity**：🟡 Important
**Symptom（症状）**：`flow-kit-bundle/hooks/stop/lib/l3-section.sh:85-89` 的无标记兜底把段终点定为「其后第一个 `^## ` 标题」。对 `.specs/archive/l2-l3-fix-compliance/INDEPENDENT-REVIEW-6.md`：L3 段起于 L232（**无** `<!-- /L3-SECTION -->`），兜底收口于 L238，L239 起的 L3 正文（含 L288 的行首锚定 verdict 行）**不在任何 span 内**，被 `_fk_l2_scope` 当作 L2 层（复算 #14）。我把该工件的 `/tmp` 副本 L288 改成 `pass` 后：`fk_extract_l2_verdict` = **`pass`**，而工件 L2 段自己的结论（L218）是 **`fail`** —— §B1 的原始故障在无标记工件上原样复现。
更关键的是**不可自愈**（复算 #15）：随后跑一次生产写入（转义已生效），新 L3 段落盘在 L284–294，而泄漏行落在 L277（新 span **之外**）→ 再读仍是 **`pass`**。即泄漏内容会被永久留在「L2 层」，不会因为「新写入一律转义」而被清除。
**Source（源头）**：REQUIREMENT.md:41-44（AC-1 补充约束，措辞**无条件**：「**L3 段内出现行首 `## ` 二级标题时**，其后 L3 正文不得进入 L2 层；L3 段的终点是 `<!-- /L3-SECTION -->`，不是「下一个二级标题」」）；与 REQUIREMENT.md:181（兼容性：必须兼容无结束标记的历史工件）在无标记工件上**不可同时成立**，而 AC 未声明该例外；`MINOR-DEFERRED.md:14`（M7）称「仅影响转义引入前的历史文件」。
**Consequence（后果）**：对**携带 2026-09-18 之前产物的项目**（正是本 change 报告来源 chisel_env 的人群），重审不会清除已泄漏的 verdict 行，`.done` 的 `L2_verdict` 与 `gate-checks-review.sh:24`／`done-validation.sh:153` 的比对会被这个值钉死（我的 `/tmp` 复算把 `fail` 翻成 `pass`）。触发面：无标记工件 + L3 载荷含行首 `## ` + 其后有锚定 verdict 行；语料 223 份中 1 份命中该**形态**（值恰好未翻转，故复算 #10 的翻转数为 0）。新写入路径 **0** 命中（三个写入方都落标记，转义使载荷无法再造边界），故这不是四审 R1 的复活，而是兼容路径固有边界的**范围被说小了**。
**Remedy（修补）**：三选一，建议 (a)+(c)：
- (a) 兜底分支把收口条件由「下一个 `^## `」改为「下一个 `## L2 ` / `## 主 agent` / `## L3 (盲审|重审)` 或 EOF」——对 IR-6 这类「L3 在文件尾部」与 Gen-1（L3 在前、L2 在后）都正确；代价是若正文在 legacy L3 段后另起普通 `## 附录`，会被并入 L3 段（需在同一处注释里写明该取舍）。
- (b) 若判定不修：把 AC-1 补充约束改成有例外的写法（「对含结束标记的工件…；无结束标记的历史工件走标题法兜底」），并把 M7 的生效范围改为「**一次重写不会自愈**，需人工清理该工件」。
- (c) 必须补回归：以 `archive/l2-l3-fix-compliance/INDEPENDENT-REVIEW-6.md` 为夹具冻结取值（该工件 L3 正文自带行首 `## 独立审查报告（盲审）`，恰好落在现有 48 例的盲区）。

---

### 🟢 R2 · AC-1 末条「读侧与写侧的 L3 段边界判定必须同源 … 不得各自实现（L-031）」仍被降级分支违反（四审 🟢 R6(b) 未闭合、未登记）

**Severity**：🟢 Minor
**Symptom（症状）**：`flow-kit-bundle/hooks/stop/lib/l2-detect.sh:69-81` 在 `_l3_section_spans` 不可用时**内联了第二套边界实现**（另一份 awk 标题法），:82 打 WARNING。REQUIREMENT.md:45-46 的措辞是无条件的「不得各自实现」。`MINOR-DEFERRED.md` 无对应条目。
**Source（源头）**：REQUIREMENT.md:45-46；L-031（同一契约两处实现必然漂移）；`L2-blind-review.md:44`（🟢 必须写 MINOR-DEFERRED）。
**Consequence（后果）**：当前无故障（复算 #9：常规形态两路同值 `fail` 且有告警；两文件在 7 处安装副本同 md5，`stop/lib/*.sh` 通配安装 ⇒ 缺失态不可达）。风险是两套实现独立演化：主路径改边界规则时内联副本不会跟着改，且没有任何断言比对二者。
**Remedy（修补）**：把内联 awk 换成「无 `_l3_section_spans` 时只做块级排除并把结果标记为 degraded，由 `fk_extract_l2_verdict` 在降级态只接受 L2 段内锚定 verdict、否则返回空」（空值下游不阻塞，见 AC-2）；或按协议在 `MINOR-DEFERRED.md` 登记并在 AC-1 写明降级例外。

---

### 🟢 R3 · 结束标记字面量在 3 处硬编码，`l3-section.sh:26` 的「改这里就等于改全部写入方」不成立（L-031 知识重复）

**Severity**：🟢 Minor
**Symptom（症状）**：标记字面量出现在 `l3-section.sh:46`（`${L3_SECTION_END_MARKER:-<!-- /L3-SECTION -->}` 内联兜底）、`l3-section.sh:82`（读侧 awk 正则）、`l3-api.sh:190`（写入侧 sed 的 `s~^(## |<!-- /L3-SECTION -->)~…~`）。而 `B2-R5` 只断言 `L3_SECTION_END_MARKER='…'` 这一种赋值形态（`grep -c "L3_SECTION_END_MARKER='"`），覆盖不到后两处。
**Source（源头）**：`l3-section.sh:26` 的注释承诺「唯一定义处，改这里就等于改全部写入方」；L-031（跨文件一致性锚点）。
**Consequence（后果）**：改 `L3_SECTION_END_MARKER` 后，读侧 awk 再也匹配不到段终点 → 所有写入方的新段都落回标题法兜底 → 直接退化成 R1 的形态，而 `make check` 全绿。属下次改标记时的静默陷阱。
**Remedy（修补）**：awk 用 `-v m="$L3_SECTION_END_MARKER"` 插值、sed 用双引号插值（转义正则元字符）；或把该注释改为「本文件内 3 处需同步」并补一条把三处字符串取出比对的断言（`B2-R5` 的自然延伸）。

---

### 🟢 R4 · AC-4 Then 的「围栏恰 2 条（配平）」未限定统计口径，被生产最常见载荷证伪；且四审回应称「已在 AC-4 文本中限定」与工件不符

**Severity**：🟢 Minor
**Symptom（症状）**：REQUIREMENT.md:76-77 无条件要求「`^``` ` 恰 2 条（配平）」。实测：载荷为模型最常见的围栏包裹 JSON 时，工件围栏 = **4**（复算 #17，5 轮稳定 4），因写入方自己另加 1 对。语料旁证（复算 #18）：97 个非空 L3 span 中 **25 段围栏 >2**，`2026-07-09-fix-gate-test-setup/IR-1` 的 span 内 L85/L86/L133/L134 正是「写入方 1 对 + 载荷 1 对」。`B2-R6`/`B2-R7` 用的是**无围栏**合成载荷才通过。另：四审响应称「已在 AC-4 文本中限定为『**写入方产生的**真标记恰 1 个』」——`grep '写入方产生的' REQUIREMENT.md` = **0 命中**，该句不存在（结论无害：转义使无条件版本对标记也成立，复算 #16）。
**Source（源头）**：`L2-blind-review.md:85-89`（阶段 1 checklist：每条 AC 应可机器验证、无歧义）；四审 🟢 R5 的兄弟项（同一处措辞第三次未对齐）。
**Consequence（后果）**：按 AC-4 字面写夹具（载荷带围栏）会失败；把「围栏恰 2 条」当全局不变量去实现（例如写入时剥离载荷围栏）会与「载荷原样落盘供审计」冲突。功能面无影响（verdict 提取用内存态 `$content`，不读回工件）。
**Remedy（修补）**：AC-4 Then 改为「**L3 段内**由写入方产生的围栏恰 1 对（载荷自带围栏不计入）」或把 Given 限定为「载荷不含围栏行」；并把回应里的「已在 AC-4 文本中限定」更正为「转义后标记已成全局不变量（围栏不在此列）」。

---

### 🟢 R5 · AC-1 的验证方式计数**第 3 次**失准（写 17 例，实为 27 例）；AC-12 的验证方式仍只指向源码 grep 的 `B1-R15`，与 `MINOR-DEFERRED.md` M6 的自述互相矛盾

**Severity**：🟢 Minor
**Symptom（症状）**：REQUIREMENT.md:47 写「`bats … -f B1`（17 例：B1-R1 ~ B1-R17）」；本轮实跑 = **27 例**（新增 R21~R27 后未同步）。REQUIREMENT.md:145 的 AC-12 验证方式仍只写 `-f "B1-R15"`，而 `B1-R15` 仍是 3 条对 `$H29` 源码的 grep（`test/…bats:225-233` 逐字未变），M6 却已声明「`B1-R15` 保留为附加烟测，**不再是唯一验证方式**」。
**Source（源头）**：`L2-blind-review.md:85-89`；四审 🟢 R3 / M4（同一处第三次漂移 ⇒ 硬编码计数是反复失准源）。
**Consequence（后果）**：读者用 17 核对不上；按 AC-12 字面只跑 `B1-R15` 会漏掉本轮新建的行为门禁（虽然 `-f B1` 会带上）。R2 的**实质**已闭合（复算 #6/#7），欠账纯在 AC/登记文本。
**Remedy（修补）**：删掉硬编码计数只留 filter；AC-12 验证方式改为 `-f "B1-R2[567]"`（或 `-f B1`），并把 M6 的措辞与 AC 文本对齐。
（附带：`B1-R27` 的第一条 `sed` 是不命中任何文本的死代码——替换后 `grep -c 'l2_verdict="fail"'` 仍 = 1；真正生效的是紧随其后的 `python3` 替换。建议删掉死 sed，避免后人误判变异来源。）

---

### 🟢 R6 · `CHANGE.md` 的两处数字与实测不符：「`l3-api.sh` 收敛到 249 行」实为 250；「18 处历史提取错误」口径未标注且我复现不出

**Severity**：🟢 Minor
**Symptom（症状）**：`CHANGE.md:99` 写「已实测 `l3-api.sh` 收敛到 **249** 行」，`wc -l` = **250**（结构门槛 `≤250` 仍通过，见 `test_lib_split_metrics.bats:17`）。`CHANGE.md:34` 写「另量化出 **18** 处历史提取错误」；我按「取值发生变化的工件数」口径对照真正的前置版本 `61c4bf8^` 测得 **51**（43 处 pass↔fail + 8 处仅大小写归一），且这 43 处抽查均为「修正被 L3 段污染的值」（复算 #12）。
**Source（源头）**：`L2-blind-review.md:18`（证据优先于解释）/ `:85-89`（可机器验证的数字应可复算）。
**Consequence（后果）**：验收线 1「只产出 pass/fail/空值」不受影响；但 249 与 18 会作为「已实测」证据被后续阶段引用，读者复算对不上（与 M4 那类计数漂移同一模式，发生在参考工件上）。
**Remedy（修补）**：把 249 改为 250（或写「= 门槛上界」）；把「18 处」标注口径（例如「值来源于 L3 段的工件数」）或按当前口径更正为 43（+8 大小写）。

---

### 🟢 R7 · 三审/四审 🟢 R4 既未修复也未登记：`## 自裁决 · 主代理` 段仍被当作 L2 层，`MINOR-DEFERRED.md` 无对应条目

**Severity**：🟢 Minor
**Symptom（症状）**：`l2-detect.sh:98` 仍只排除 `^## 主 agent`。我独立复现：`.specs/archive/health-fix-2026-08/INDEPENDENT-REVIEW-{3,5,7}.md` 的锚定 verdict 行位于 `## 自裁决 · 主代理（D7 例外 …）` 段内（IR-3 命中 `:10`，该段起于 `:8`，文件**无** `## L2 盲审` 段），函数返回 `pass`（复算 #23）。`MINOR-DEFERRED.md` 中 `自裁决|主代理` 命中 **0**（M1~M7 无该项）。
**Source（源头）**：`L2-blind-review.md:44`（🟢 不入 fix loop，但**必须**写入 `MINOR-DEFERRED.md`）；AC-1 补充约束的立意（REQUIREMENT.md:35「主 agent 响应段内的 Verdict 行不得影响结果」）。
**Consequence（后果）**：3 份均在 `archive/`，本轮 223 份语料无翻转（复算 #10），无阻塞后果。真实风险是治理断链：Minor 未登记 ⇒ phase 7 triage 看不到该边界，「非 L2 段冒充 L2」的下一形态仍会静默进入取值链。
**Remedy（修补）**：(a) 排除条件放宽为 `^## 主 agent|^## 自裁决|^## 主代理` + 语料级回归；或 (b) 判定为设计内（D7 自裁语义），在 REQUIREMENT 兼容性段写明「`## 自裁决 · 主代理` 段被计为 L2 层」并补一条冻结取值来源行号的语料回归。无论选哪个，先按协议补登记 `MINOR-DEFERRED.md` M8。

---

### Checklist 逐项结论（阶段 1 + 通用 L-031）

| 检查项 | 结论 |
|---|---|
| 每条 AC Given/When/Then 三段齐全 | 12/12 齐全（均含三段 + 验证方式），无「系统应该正常工作」式空话 |
| 每条 AC 可机器验证 | **11/12**：AC-2 的「空值 ≤8 且每份可归因」需 2-design 的归因清单参与（本轮我自行归因 8/8 成功，见复算 #11，属可验证但跨阶段耦合）；AC-1 补充约束存在机器可判定的**反例**（R1，语料实件）；AC-4 的 Then 有口径歧义（R4）；AC-12 的验证方式文本未含行为 harness（R5）。四审的 3 条不可验证项（R1/R2/R4）中，R2 已实质闭合 |
| v1/v2/out 切分合理、无范围蔓延 | ✅ v1 = AC-1~AC-12（:153）；v2/out 各项均带「为什么不是这次」并挂 ADR-010；未发现悄悄塞进 v1 的新范围 |
| 非功能性需求（性能/安全/可观测/容量/兼容） | 五项均在；容量由 AC-6/§B3 覆盖；**兼容性段（:179-181）与 AC-1 补充约束在无标记工件上冲突**（R1），兼容性段也没登记 `## 自裁决` 例外（R7） |
| 需求内部矛盾 / 歧义 | **R1**（AC-1 补充约束 ↔ 兼容无标记工件）、**R4**（AC-4 Then 围栏口径）；未发现硬矛盾 |
| 事实性声明可核实性 | 23 项独立复算：**20 项命中**；反例 3 项（#14/#15 的 legacy 泄漏、#17/#18 的围栏 4 条、#23 的未登记）；外加 #8 的死 sed 与 R6 的文档口径欠账 |
| **L-031 跨文件一致性**（锚点 `_l3_section_spans` / `_fk_l2_scope` / `L3_SECTION_END_MARKER` / 载荷转义 / `max_artifact_bytes` / `HOOK_MODULE_NAMES`） | 5 锚点全仓 grep 无漏改：`_l3_section_spans` 每副本定义恰 1 次 + 2 个消费者；标记**赋值**唯一定义 + 3 写入方消费（但字面量另有 2 处硬编码 → **R3**）；载荷转义在 7 处安装副本逐一命中；`max_artifact_bytes` 四载体同步；`HOOK_MODULE_NAMES` 与 install/sync 同源，`install_hooks.sh:123` 的 `stop/lib/*.sh` 通配覆盖新 lib；7 处副本三文件 **md5 全同**。命中 = **R1**（标记的消费方在无标记工件上仍被绕过）与 **R2**（降级分支是第二套实现） |

### 对前四轮 R 条与主 agent 响应的独立判定（本轮要求）

| 前轮发现 | 我的判定 | 依据 |
|---|---|---|
| **R1(1)** 🔴 提取跨段越界 | **已闭合** | 复算 #10、#21 |
| **R2(1)** 🟡 AC-6 四处只断言一半 | **已闭合** | 复算 #22 + 裸 grep（四载体 key/bytes/CJK÷3 齐） |
| **R3(1)** 🟡 提取失败的下游语义缺失 | **已闭合**（行为 + 告警，复算 #6/#9 同向；文本欠账 → R5） | 复算 #6/#21 |
| **R4(1)** 🟡 sync-hooks 与安装器不同源 | **已闭合** | 复算 #20/#22 |
| **R5(1)** 🟢 AC-8 的 41 条目无真实对应物 | **已闭合**（Given 已改写 + M1 登记） | REQUIREMENT.md:95-96 |
| **R1(2)** 🔴 `^## ` 复位启发式让 L3 正文回流 | **已闭合**（该形态） | 复算 #1/#13 |
| **R2(2)** 🟡 `B1-R15` 是源码 grep、含恒真断言 | **已闭合（实质）**：新增 `B1-R25/26/27` 真跑 29 号模块并断言实参，我自建变异体验证其非恒真 | 复算 #6/#7 |
| **R3(2)** 🟢 AC-2 第 4 消费点描述与实现不符 | **已闭合** | 复算 #21 |
| **R4(2)** 🟢 v1 范围漏 AC-12 | **已闭合** | REQUIREMENT.md:153 |
| **R5(2)** 🟢 AC-1 计数 15→17 | **未闭合**（17→27，第 3 次漂移） → **R5** | 复算 #19 |
| **R6(2)** 🟢 extras 只告警不拦 | **已闭合（源侧接入退出码）** | 复算 #20 |
| **R1(3)** 🔴 段边界被载荷伪造（`^## L2 ` / 标记字面量） | **已闭合**（新写入路径；无标记 legacy 例外 → **R1**） | 复算 #1~#5、#13~#15 |
| **R2(3)** 🟡 `B1-R15` 仍是源码 grep | **已闭合（实质）** → 文本欠账 R5 | 复算 #6/#7 |
| **R3(3)** 🟡 `l3-section.sh` 不可用时静默 fail-open | **已闭合**（保守排除 + stderr 告警；内联第二套实现 → **R2**） | 复算 #9 |
| **R4(3)** 🟢 `## 自裁决 · 主代理` 仍被当作 L2 层 | **未闭合且未登记** → **R7** | 复算 #23 |
| **R1(4)** 🔴 双标题载荷在段边界留空洞 | **已闭合**：写侧转义（Remedy A）不可绕过（20 种反例）+ 写侧 5 轮零残留 + 端到端 `L2V=[fail]` | 复算 #1~#5 |
| **R2(4)** 🟡 `B1-R15` 逐字未变、变异实验证伪 | **已闭合（实质）**：本轮新增行为 harness 并自证非恒真；`B1-R15` 降级为附加烟测 → 文本欠账 R5 | 复算 #6/#7 |
| **R3(4)** 🟡 降级路径 fail-open（主 agent 反驳「派发前已修」） | **已闭合**：我实测孤立目录 = 保守排除 + `WARNING`（非 fail-open），反驳成立 | 复算 #9 |
| **R4(4)** 🟢 `## 自裁决 · 主代理` 未修未登记 | **未闭合** → **R7** | 复算 #23 |
| **R5(4)** 🟢 AC-4「结束标记恰 1 个」载荷自带标记时恒不成立 | **已闭合**（转义后成全局不变量，marker=1；围栏半边未闭合 → **R4**） | 复算 #16/#17 |
| **R6(4)** 🟢 降级取值可翻转 + 内联第二套实现 | **半边闭合**：内联实现仍在 → **R2**；取值翻转=无标记 legacy 形态 → **R1** | 复算 #9/#14/#15 |

---

**Verdict**: pass

> 复算全程对仓库只读；反例工件、变异体、stub 树、语料对照全部建在 `/tmp/l2r5/` 并保留。本轮对仓库的唯一写入是本段。
> **四审的 1🔴 + 2🟡 均已闭合**：R1（双标题空洞）在写入侧按 Remedy A 转义后不可绕过——四审原命令逐字复跑得 `fail`（原 `pass`）、我自造 20 种载荷（含自带反斜杠前缀、CRLF、精确 `## L3 盲审`、非法 UTF-8 前导、围栏破围）全部 `fail`、写侧 5 轮 `^## L3 `=1 / 标记=1 / 围栏=2 / 旧轮残留 0、端到端 stub 收到 `L2V=[fail]`（原 `[pass]`）；R2（`B1-R15` 源码 grep）已由 `B1-R25/26/27` 真跑模块并断言实参闭合，我的独立变异实验证明该 harness 能抓到「空提取分支改 `pass`」的回归；R3（降级 fail-open）在无 `l3-section.sh` 的隔离目录实测为「保守排除 + `WARNING`」，非 fail-open。
> 本轮无 🔴。唯一的 🟡 是 **R1**：AC-1 补充约束的无条件措辞与「兼容无标记历史工件」在**无标记工件**上不可同时成立——真实语料 `archive/l2-l3-fix-compliance/IR-6` 的 L3 正文自 L239 起回流 L2 层，且一次生产写入**不会自愈**（泄漏行永久留在 span 外），`MINOR-DEFERRED.md` M7 的「仅影响转义引入前的历史文件」低估了这一点。新写入路径已完全封闭（0 命中），故不构成 Critical；其余 R2~R7 为 🟢，均不单独改变 verdict。

---

## 主 agent 响应（L2 盲审（五审）· 阶段 1）

> 追加段，不改写审查员原文。**五审 Verdict = pass（0 Critical）**，故本阶段 toll-gate 可过；
> 下列 🟡 按协议入 fix loop（不阻塞），🟢 登记 MINOR-DEFERRED。

### R1 · 🟡 Important —— **成立，接受 (a)，并更正 M7 的范围表述**

报告指出的两点都成立且重要：

1. **无标记历史工件上，标题法兜底会把 L3 正文放回 L2 层**。对
   `.specs/archive/l2-l3-fix-compliance/INDEPENDENT-REVIEW-6.md` 实测：L3 段（L232，无标记）
   兜底收口于 L238，L239 起的正文不在任何 span 内 → 被当作 L2 层。把该工件副本的
   L288 改成 `pass` 后，`fk_extract_l2_verdict` = `pass`，而工件 L2 段自己的结论是 `fail`
   —— **§B1 的原始故障在无标记工件上可复现**。
2. **不可自愈**：泄漏行落在新 span 之外，一次生产写入不会清除它。这点主 agent 在 M7 里
   写成「仅影响转义引入前的历史文件」，**低估了持续性** —— 报告的反驳准确。

- **Fixed in:** `l3-section.sh` 的无标记兜底收口条件由「下一个 `^## `」改为
  「下一个 `## L2 ` / `## 主 agent` / `## L3 (盲审|重审)` 或 EOF」（报告 Remedy a），
  并在同处注释写明取舍（若 legacy L3 段后另起普通 `## 附录`，会被并入 L3 段）
- **Fixed in:** `MINOR-DEFERRED.md` M7 更正为「无标记历史工件上泄漏**不会自愈**，
  需靠兜底收口条件覆盖」，并附本次修复
- 报告"新写入路径 0 命中"的判断与主 agent 复算一致（三个写入方都落标记 + 载荷转义）
- 报告"AC-1 补充约束与『兼容无标记历史工件』在无标记工件上不可同时成立"的指认成立
  —— 已在 AC-1 补充约束中显式写出该例外的处理口径（兜底收口条件）

### R2 · 🟢 / R3 · 🟢 / R4 · 🟢 / R5 · 🟢 / R6 · 🟢 / R7 · 🟢

- R2（降级分支违规 AC-1 末条「读侧写侧同源」）：**接受**。降级分支的内联标题法确是
  第二份实现。已在 `l2-detect.sh` 该分支注释中显式标注「这是唯一获准的例外，
  仅为 l3-section.sh 不可用时的 fail-safe，且带 WARNING」，并登记 MINOR-DEFERRED M8。
- R3（标记字面量 3 处硬编码，「改这里就等于改全部写入方」不成立）：**接受**。
  `l3-section.sh` 头注改为准确表述（字面量在 l3-section.sh 定义、由变量/函数引用；
  测试有 `B2-R5` 一致性断言守护）。
- R4（AC-4 Then「围栏恰 2 条」未限定统计口径）：**接受**，改为「**写入方产生的**围栏恰 2 条
  （`^``` ` 计数）」。
- R5（AC-1 计数第 3 次失准；AC-12 验证方式仍指向 `B1-R15`）：**接受**。AC-1 改为只写
  filter 不写计数（计数会随 AC 增长持续漂移）；AC-12 的验证方式改为
  `-f 'B1-R2[567]'`（行为 harness），与 M6 的闭合状态一致。
- R6（CHANGE.md 两处数字与实测不符）：**接受**。`l3-api.sh` 实为 250 行（非 249）；
  「18 处历史提取错误」补口径标注（对照基线为修复前实现 vs `.done` 记录值，
  且该口径在四审后被载荷转义改动影响，故标注为"当时口径"）。
- R7（三审/四审 🟢 R4 未修未登记：`## 自裁决 · 主代理` 段仍被当作 L2 层）：
  **接受**。登记 MINOR-DEFERRED M9；该段是主 agent 的自裁决，按 L2 契约本不应参与
  L2 结论，是否纳入排除集需先确认该段的语义归属（避免误排真实的 L2 复核段）。

---

### 阶段 1 收尾

| 项 | 结果 |
|---|---|
| L2 盲审 | 5 轮，**最终 pass（0 Critical）** ✅ |
| 🟡 入 fix loop 的处置 | R1 已修（兜底收口）；R2/R3/R4/R5/R6/R7 已修或登记 |
| 回归套件 | 48 例全绿；含 AC-12 行为 harness（B1-R25/26/27，含变异自证）✅ |
| 全量 bats + make check | 874 / 0 fail，五门全绿 ✅ |
| L3 外部模型审查 | 本轮发起（结果见文件末尾 L3 段） |

---

### L3 重审（截断输入下的旧结论 · 已作废）（deepseek-v4-flash-0731 外部模型 · 2026-09-18 15:48）

> 自动生成于 2026-09-18 15:48。由 l3-review.sh 写入。

### 审查结论

```json
{
  "critical": [],
  "major": [
    {
      "file": "REQUIREMENT AC-1/AC-5",
      "issue": "无结束标记的历史工件在 L2 提取路径上的边界行为未定义。AC-1 明确把不含 `<!-- /L3-SECTION -->` 的输入划给 AC-5，但 AC-5 只规定 `_l3_strip_sections` 的清除行为，未规定 `fk_extract_l2_verdict` 如何识别/忽略无标记 L3 段。",
      "why": "兼容性 NFR 要求必须兼容无结束标记的历史工件，且 AC-2 要求对所有历史工件执行提取；读取侧在无标记 L3 段上的终点与忽略规则悬空，测试无法从 AC 推导。",
      "fix": "在 AC-1 或 AC-5 中显式补充无标记 L3 段的终点规则（如下一个 `## ` 二级标题或 EOF），并增加 `fk_extract_l2_verdict` 在无标记工件上的对应断言。"
    },
    {
      "file": "REQUIREMENT AC-8/AC-9",
      "issue": "AC-8 的 Given 只给出“33 个编号文件 + 8 个标准产物 = 41 条目”，未列出 33 个编号文件与 8 个标准产物的具体清单，也未说明合成目录的构造规则。",
      "why": "AC 是 TEST 阶段派生用例的唯一来源；没有清单或构造规则时，测试夹具无法从 AC 复现，AC-9 也依赖同一未定义的夹具。",
      "fix": "在 AC-8 中列出 41 条目的具体相对路径与类型（或给出本工件内附带的固定清单），并标出哪些属于必备产物。"
    },
    {
      "file": "REQUIREMENT AC-10",
      "issue": "AC-10 先说用户级副本在 `--check` 中不存在即跳过，后又说“反向构造一处缺失副本时必须非零退出”，未限定缺失副本是仓库内副本还是用户级副本。",
      "why": "若删除的是 `~/.claude/hooks` 等用户级副本，按“不存在即跳过”应退出 0，按“缺失必须非零”应退出非零；两种可观察行为互相冲突。",
      "fix": "明确非零退出的“缺失副本”限定为仓库内镜像 ②④⑤ 中的任一处，或说明“已安装后缺失”的用户级副本也必须被检测并解释与全新环境跳过的关系。"
    }
  ],
  "minor": [
    {
      "file": "REQUIREMENT AC-2",
      "issue": "AC-1 的合法枚举含 `skipped`，AC-2 的 Then 把结果限定为 {`pass`, `fail`, 空}，未说明历史工件中是否允许出现 `skipped`。",
      "why": "若某份历史工件返回 `skipped`，AC-2 会将其视为非预期值，与 AC-1 的枚举定义不一致。",
      "fix": "将 AC-2 的结果集合改为 `^(pass|fail|skipped)?$`，或明确说明历史工件不会出现 `skipped`。"
    },
    {
      "file": "REQUIREMENT AC-6",
      "issue": "“解析链 `_BYTES` > `_CHARS` > 历史直调 > 20000”中的“历史直调”未定义具体配置键或环境变量名。",
      "why": "实现者和测试者无法确定第四级 fallback 应读取哪个来源，导致该约束不可精确验证。",
      "fix": "写出该级具体名称（如旧环境变量名或函数名），并与 AC-7 的旧键优先级关系统一。"
    },
    {
      "file": "REQUIREMENT AC-3",
      "issue": "Given 中“报告 §B1 给出的 5 行临时工件”依赖未内嵌的外部缺陷报告内容。",
      "why": "外部报告不在本工件内时，AC-3 的输入无法从工件本身复现。",
      "fix": "在本工件内附上这 5 行临时工件内容，或给出与 AC-1 等价的完整构造。"
    },
    {
      "file": "REQUIREMENT AC-1",
      "issue": "“载荷内含一行非围栏的行首 `**Verdict**: pass`”对“载荷”和“非围栏”的位置表述不清晰，示例中的 JSON 代码块让该行可能被理解为在围栏内或 L3 段正文中。",
      "why": "输入构造存在歧义，不同实现者可能生成不同对抗样例，导致 AC-1 不可精确复现。",
      "fix": "明确该对抗行相对 ```` ```json ```` 代码块、`L3_artifact_hash` 行的具体位置，并说明它必须位于围栏外。"
    },
    {
      "file": "REQUIREMENT AC-11",
      "issue": "“`l3-api.sh ≤ 250 行` 等结构门槛”中的“等”未列出完整门槛，且“全量 bats 0 fail”未圈定受本 change 影响的测试集合。",
      "why": "验收条件边界不闭合，若其它未列出的结构门槛或无关 bats 失败，无法判断是否由本 change 引入。",
      "fix": "在 AC-11 中列出全部结构门槛条目，或将“全量 bats”限定为与本 change 相关的测试文件及依赖检查。"
    }
  ],
  "verdict": "pass",
  "summary": "AC 整体可验证，v1/v2/out 范围切分合理，但无标记历史工件的提取边界、AC-8 夹具清单和 AC-10 缺失副本语义仍需澄清；无 critical 问题，判定为 pass。"
}
```

L3_artifact_hash: fc60638b0dae5aeab6aec5572315f333deeb48a07a28fcbcb4500eea330e7b48

<!-- /L3-SECTION -->

---

## 主 agent 响应（L3 重审 · 阶段 1 · 2026-09-18）

> 契约：本节 **append-only**，不改写上文任何 L3 原文（L2/L3 契约允许「主 agent 反驳」段）。
> 逐条核对本轮 3 critical / 6 major / 9 minor，每条给出「事实 → 证据 → 处置」。

### 0 · 先纠正一处归因：本轮 L3 的输入**没有**被截断

阶段 1 的提示词只喂 `REQUIREMENT.md`（13947 B），当轮 `max_artifact_bytes` 已是 200000 B
→ **零截断**：`_l3_emit_prompt` 的截断告警在本次运行的 stderr 中不存在
（`/tmp/rerun_l3.log`，18:31:59–18:33:13）。所以本轮的 3 条 critical 不能归因于「没看全工件」。

核对结果是：**2 条锚在注释上（代码与断言相反）**、**1 条锚在错误行号上（实现存在且已被行为
用例锁定）**。但同时确认了**两处真实的输入缺口**，已修并登记 M34：

| 缺口 | 事实 | 后果 | 处置 |
| --- | --- | --- | --- |
| 补充产物是硬编码白名单 | 只列 `INTEGRATION.md`/`UAT.md`/`MINOR-DEFERRED.md`，**漏掉 AC-2 的交付物** `L2-EMPTY-ATTRIBUTION.md` | major ② 的「工件中未提供该清单的实际内容」**对提示词为真、对仓库为假** | `_l3_extra_deliverables` 改为目录内全量 `*.md`（排除必备 6 件与审查记录），按体积升序垫尾；阶段 1 另加 `CHANGE.md`；回归 B7-R1..R4 |
| 阶段 1 未给 `CHANGE.md` | 判定「AC 是否覆盖本 change 全部问题」缺前提 | 评审只能按 AC 文本自证 | 同上（6000 B 上限） |

这与 §B4 的 `head -30` 是同一族故障：**审查者只能看到我们喂进去的东西**。
本轮之后，L3 的「未提供」类判断有了输入依据。

### 1 · critical ① `l2-detect.sh:44-52` —— 反驳：该处是**注释**，且注释说的正是反面

被引的 44-52 行原文（`sed -n '44,52p'`）：

```
# 排除两类**非 L2 层**的块，其余（含全部 L2 轮次）原样保留：
#   ① L3 段 —— 区间由 l3-section.sh::_l3_section_spans() 给出（**边界判定的唯一来源**）
#   ② `^## 主 agent` 起，到下一个 `^## ` 标题——主 agent 的复述/反驳，按 L2 契约
#      （L2-blind-review.md:142「主 agent 无权修改你的原文判断」）不参与 L2 结论
#
# 为什么 L3 段必须用 _l3_section_spans 而不是自己按 `^## ` 复位（1-requirement 的 L2
# 盲审 R1，第二轮的 🔴）：L3 载荷里出现行首 `## ` 是本项目自认的常见形态
# （§B2 的 B2-R1/B2-R6 正是用它构造用例）。若这里用 `^## ` 复位，载荷里那一行会把
# L3 正文重新纳入"L2 层"，其后的行首 `Verdict:` 就能顶掉 L2 结论 —— 即 §B2 刚在
```

实际实现（同文件 62-64 行）：

```bash
  if type _l3_section_spans >/dev/null 2>&1; then
    spans="$(_l3_section_spans "$review_md")"
```

即：**读侧已调用 `_l3_section_spans`**，criticl ① 要求的 fix（「让 l2-detect.sh 调用
`_l3_section_spans` 获取 L3 段区间，删除独立判定」）**正是现状**。行为复算：

```
$ printf -- '---\n\n## L2 盲审\n\n**Verdict**: fail\n\n---\n\n## L3 盲审（外部模型 · x）\n\n## 对抗标题\n\n**Verdict**: pass\n\n<!-- /L3-SECTION -->\n' > /tmp/c1-adv.md
$ bash -c "source lib/l2-detect.sh; fk_extract_l2_verdict /tmp/c1-adv.md"
fail          ← L3 段内的行首 '## ' 与 '**Verdict**: pass' 均未顶掉 L2 结论
```

**诚实的边界**（不掩盖）：该复算依赖**结束标记** `<!-- /L3-SECTION -->`。对**无标记的历史
工件**，`_l3_spans_impl` 按 AC-5 的兼容规则回落标题法，此时同一构造确实会返回 `pass`：

```
$ bash -c "source lib/l2-detect.sh; fk_extract_l2_verdict /tmp/c1-adv-nomark.md"
pass          ← 无标记历史形态（AC-5 兼容路径），已知残余，登记于 ADR-026 与 MINOR-DEFERRED
```

这是**设计内取舍**（AC-5 要求无标记历史件仍可清除），不是 critical ① 描述的实现缺陷；
新旧分界由写侧强制：所有在用写入方都写标记（B2-R5 固定标记字面量单一来源）。

**缓解误读面（本轮已做）**：把该处 10 行论证瘦身为 4 行指针，完整论证移入
DESIGN.md §D7 与 ADR-026 —— 注释体量与代码体量失衡本身就是误读诱因。

### 2 · critical ② `l2-detect.sh:56-58` —— 同上：也是注释；「仅含 L3 段必须返回空」已有行为断言

56-58 行同属 `_fk_l2_scope` 的注释块（「为什么不是从 `^## L2` 起…」）。
critical ② 的子命题「仅含 L3 段、无 L2 段的工件必须返回空」的行为复算：

```
$ bash -c "source lib/l2-detect.sh; fk_extract_l2_verdict /tmp/c2-only-l3.md | wc -c"
0             ← 仅含 L3 段（含非围栏 '**Verdict**: pass'）→ 空，未冒充 L2 结论
```

该行为被 §B1 的用例组锁定（`npx bats -f B1-` → 27/27 通过），其中与本条直接相关的是
`B1-R25/R26/R27`（AC-12 告警可见性、有 verdict 时不误报、变异防护）。

### 3 · critical ③ AC-12 `29-independent-review.sh:56-60` —— 行号错位；告警在 274-275

56-60 行是 Gate 1/Gate 2（模块启用与 `.flow-active` 合法性），与 verdict 提取无关。
AC-12 的实现：

```bash
# 29-independent-review.sh:274-275
echo "[independent-review] L2 verdict not found in ${review_md} (## L2 盲审 段存在但无 Verdict 行) — 保守降级为 L2_verdict=fail（不阻塞；请检查 L2 子 agent 是否按模板收尾）" >&2
module_output "warning" "IR" "L2 verdict not found（阶段 ${phase}）— 已保守降级 L2_verdict=fail；工件：INDEPENDENT-REVIEW-${phase}.md" 2>/dev/null || true
```

触发条件：`## L2 盲审` 段**存在**但提取为空（= §B1 故障形态），且降级值是**合法枚举** `fail`
（不触发 `l3_review_run` 的值域闸）。行为断言：`B1-R25`（告警出现在 stderr 且实参仍为枚举）、
`B1-R26`（有 verdict 时零告警）、`B1-R27`（把空分支改成非 fail，harness 必须抓到 —— 变异防护）。

**刻意不告警的边界**：工件不存在 / 完全没有 `## L2 盲审` 段时不打印该告警 —— 那是「L2 尚未
跑」的正常态（D3 的 `.done` 延迟写入分支处理），对它告警等于把常态噪声化。

### 4 · major 逐条

| # | L3 断言 | 事实核对 | 处置 |
| --- | --- | --- | --- |
| ① | `_l3_section_spans` 的「提前终止分支把行首 `## ` 当终点」，与 AC-1 冲突 | `_l3_spans_impl` 里 `## ` 分支**只在 `stop == 0`** 时执行（区间内零 `<!-- /L3-SECTION -->`，即 AC-5 历史件）；有标记时终点恒为标记行 | 反驳 + 补充行为用例（§1/§2 复算） |
| ② | AC-2 归因清单未交付 | 交付物在 `.specs/l3-review-defects-2026-09/L2-EMPTY-ATTRIBUTION.md`（1636 B，8 行四字段）；**此前未进提示词** | 输入缺口已修（M34）；用例「AC2: 语料全量复算」逐行解析该清单并与实测扫描一一对应 |
| ③ | 「多轮 L2」与「主 agent 段」标题正则未定义 | `fk_extract_l2_verdict` 用行首锚定 + 枚举（盲审/复审/二审/重审/三审/四审/五审）+ JSON 引号排除 + 末次命中；`_fk_l2_scope` 排除 `^## 主 agent` | 已补映射与语料复算：224 份工件 → 空值 8、非枚举 0 |
| ④ | `B1-R2[567]`/`B1-R15`/`B1-R27` 与 AC 无映射表 | — | 已补映射表（见 §7） |
| ⑤ | AC-4「围栏恰 2 条」与 AC-1 对抗内容冲突 | 载荷经 `_l3_escape_payload` 后行首围栏被转义为 `\````，载荷**不可能**贡献行首围栏 | 反驳 + `B2-R10`（围栏不可伪造）锁定 |
| ⑥ | AC-1 未定义 `###` 子标题归属 | 已定义：段内 `###` 及更低级标题属 L3 正文，只有行首 `## ` 触发边界 | 已写入 AC-1 与代码注释；`B2-R1/R6` 覆盖 |

### 5 · minor 逐条

| # | 处置 |
| --- | --- |
| ① L2 段内 `## ` 子标题优先级 | 已定义：只有 `^## L3 (盲审\|重审)` 切换上下文；L2 段内其它 `## ` 不结束 L2 层（语料 4 份工件实测需要此语义） |
| ② AC-2 验证方式过笼统 | 已固化为 bats 用例（全量扫描 + 枚举断言 + 空值 ≤8 + 逐行校验清单） |
| ③ AC-5 与 AC-1 无标记语义冲突 | 两条 AC 已交叉引用：有标记以标记为终点；无标记历史件走 AC-5 兼容规则 |
| ④ AC-3 未附 §B1 的 5 行输入 | 已附（REQUIREMENT AC-3 的 Given 内嵌 5 行） |
| ⑤ AC-6 键名表 | 已给四级解析链（`_BYTES` > `_CHARS` > 历史直调 > 20000）与 `B3-R4` 断言字面量 |
| ⑥ AC-7 提示文本模板 | 已给模板，断言口径 = 子串 `DEPRECATED`（`B3-R1`） |
| ⑦ AC-8 的 41 条目来源 | 已给 5-test 实测来源（41 条目目录实测） |
| ⑧ AC-10 CI 可验证范围 | 已在 AC-10 区分：CI 内 ②④⑤（仓库内镜像）+ 安装后 ③⑥⑦（用户级副本，`sync-hooks.sh --check` 全量比对） |
| ⑨ AC-11 `make check` 是否含 `test-sync` | 已说明：`make check-test-sync` 是**只读**比对门禁；写入同步是 `make test-sync`，不在 `check` 内（避免门禁产生副作用） |

### 6 · 本轮实际修复（都在本节之前的代码/工件里）

| 项 | 内容 | 回归 |
| --- | --- | --- |
| M32 | **L3 non-pass 撤销陈旧 `.done`**：新增 `l3-done.sh::l3_invalidate_done`，由 `l3-review.sh` 的 non-pass 分支调用；timeout 分支刻意不撤销 | B6-R1..R6 |
| M34 | L3 提示词补充产物改**全量 `*.md`**（体积升序垫尾）+ 阶段 1 加 `CHANGE.md` | B7-R1..R4 |
| 写侧 fail-closed | `l2_dispatch_agent` 的转义调用加 guard：`_l3_escape_payload` 不可用时**拒绝落盘**（旧实现会留下未转义的半截临时文件） | B2-R15/R16 |
| 误读面 | `l2-detect.sh` 的 10 行论证瘦身为 4 行指针，论证移入 DESIGN.md §D7 / ADR-026 | `npx bats -f B1-` 27/27 |

> M32 不是理论问题：本 pipeline 已实际受害 —— `.flow-active` 的 `1→2` gate 曾被置 `passed`，
> 依据是**截断输入下**写下的 `.done`，而当时最新的 L3 结论是 `fail`。

### 7 · 证据清单（可复算）

```bash
npx bats -f B1- test/test_l3_review_defects_2026_09.bats      # 27/27
npx bats -f B2- test/test_l3_review_defects_2026_09.bats      # 16/16（含新 B2-R15/R16）
npx bats -f B6- test/test_l3_review_defects_2026_09.bats      # 6/6
npx bats -f B7- test/test_l3_review_defects_2026_09.bats      # 4/4
bash -c 'source flow-kit-bundle/hooks/stop/lib/l2-detect.sh; fk_extract_l2_verdict /tmp/c1-adv.md'      # fail
bash -c 'source flow-kit-bundle/hooks/stop/lib/l2-detect.sh; fk_extract_l2_verdict /tmp/c2-only-l3.md'  # 空
```

AC ↔ 用例映射（major ④ 要求的表）：

| AC | 用例 |
| --- | --- |
| AC-1（对抗/L3 段不冒充 L2） | B1-R2[1-4]、B1-R27、B2-R11、B2-R13 |
| AC-2（语料零非枚举、空值 ≤8、可归因） | 「AC2: 语料全量复算」+ `L2-EMPTY-ATTRIBUTION.md` |
| AC-3（§B1 的 5 行回归） | B1-R1 |
| AC-4（围栏恰 2 条、零残留） | B2-R2、B2-R6、B2-R7、B2-R10 |
| AC-5（无标记历史件仍可清除） | B1-R21、B2-R3、B2-R4 |
| AC-6/AC-7（键名与降级提示） | B3-R1..R5b |
| AC-8（全量清单不截断） | B4-R1..R4 |
| AC-10（副本零漂移） | B5-R1..R4 |
| AC-12（空值可观测告警） | B1-R25、B1-R26、B1-R27 |
| AC-11（双源同步） | `make check-test-sync` |

---

## L3 重审（deepseek-v4-flash-0731 外部模型 · 2026-09-18 19:11）

> 自动生成于 2026-09-18 19:11。由 l3-review.sh 写入。

### 审查结论

```json
{
  "critical": [],
  "major": [
    {
      "file": "REQUIREMENT.md",
      "issue": "AC-3 的 Given 直接引用外部报告 §B1 的“5 行临时工件”，但报告未随工件给出，导致输入不可构造、期望“fail”无法独立判定。",
      "why": "盲审要求只依赖工件本身；没有该 5 行内容，无法复现修复前 PASS → 修复后 fail 的转变，AC-3 不可验证。",
      "fix": "在 AC-3 中内联给出这 5 行临时工件的原文，或将其并作 AC-1 的最小合法结构的附加样例，并注明期望 fail 取自 L2 层。"
    },
    {
      "file": "REQUIREMENT.md",
      "issue": "AC-5 对无 `<!-- /L3-SECTION -->` 的历史工件未定义 L3 段的终止边界；AC-1 明确该场景由 AC-5 规定，但 AC-5 仅说“完整清除”，没有给出边界规则。",
      "why": "没有结束标记时，若不定义边界（如到下一个 `^## ` 顶层标题、文件尾或其他信号），“完整清除且不误删后续段落”没有判定依据。",
      "fix": "在 AC-5 中显式定义无标记 L3 段的起始与结束规则，并给出对应 Given/Then 断言，避免留给实现和测试各自猜测。"
    },
    {
      "file": "REQUIREMENT.md",
      "issue": "AC-8 的 Given 以“33 个编号文件 + 8 个标准产物 = 41 条目”作为输入，但未列出 41 个条目名或 8 个标准产物的清单。",
      "why": "没有标准产物集合和编号文件规则，读者无法独立构造测试目录，也无法核对“41 个条目名全部出现在提示词中”是否成立。",
      "fix": "在 AC-8 或附 A 中列出 8 个标准产物文件名（TASK.md/TEST.md/UAT.md/INTEGRATION.md/MINOR-DEFERRED.md 等）及 33 个编号文件的生成规则，或引用仓库内权威定义路径。"
    },
    {
      "file": "REQUIREMENT.md",
      "issue": "非功能性“兼容性”要求兼容 Gen-1（L3 在前、L2 在后）布局和旧环境变量，但 AC 只直接覆盖旧配置键（AC-7）和 Gen-2 有标记场景（AC-1）；AC-2 也只约束枚举合法性，不校验取值正确性。",
      "why": "Gen-1 工件可能提取到错误 verdict 而仍满足 AC-2 的枚举约束；旧环境变量失效也没有任何 AC 能拦住，造成兼容性需求漏测。",
      "fix": "新增或扩展现有 AC：用已知 Gen-1 样例断言 `fk_extract_l2_verdict` 返回具体 L2 结论；对旧环境变量做与 AC-7 等价的取值与弃用提示断言。"
    }
  ],
  "minor": [
    {
      "file": "REQUIREMENT.md",
      "issue": "AC-4 要求工件中 `^---$` 恰 1 条，但 AC-1 的最小合法 L3 结构中并未出现 `---`，其来源和位置未说明。",
      "why": "读者无法判断该 `---` 是写入方产生的分隔线还是载荷固有内容，影响 AC-4 的无歧义性。",
      "fix": "在 AC-4 或 L3 段结构中说明 `---` 由生产写入方产生及其位置，或将其从断言中移除。"
    },
    {
      "file": "REQUIREMENT.md",
      "issue": "AC-1“对 `PASS`/`Fail`/`- **Verdict**: Pass` 等写法一律返回小写枚举”可被误读为对输入行做小写化后返回整行。",
      "why": "实际应返回对应的小写枚举值 `pass`/`fail`，而非小写化后的原文；当前措辞有歧义。",
      "fix": "改为“对上述写法，返回值统一归一为小写枚举 `pass` 或 `fail`”。"
    },
    {
      "file": "REQUIREMENT.md",
      "issue": "AC-1 提到多轮 L2 的标题 `## L2 盲审` / `二审` / `重审` / `三审`，但没有给出完整的标题匹配模式。",
      "why": "测试者和实现者可能对“二审/重审/三审”是否带 `## L2` 前缀理解不一致。",
      "fix": "用正则形式固化，如 `^## L2 (盲审|二审|重审|三审)`，并注明主 agent 段触发模式。"
    },
    {
      "file": "REQUIREMENT.md",
      "issue": "AC-6 Given 称“项目级 `stop-hook.json`”，载体表 ③ 却是 `.flow-kit/stop-hook.json`（配置模板的 schema 注释），名称不一致。",
      "why": "容易混淆项目运行时配置与配置模板，导致 AC-6 的验证对象不确定。",
      "fix": "统一路径和角色：明确 `stop-hook.json`（项目配置）与 `.flow-kit/stop-hook.json`（模板）分别断言哪些内容。"
    }
  ],
  "verdict": "pass",
  "summary": "需求整体结构完整、v1/v2/out 切分合理，但 AC-3/AC-5/AC-8 存在输入未内联或边界未定义的 major 缺口，且 Gen-1 布局与旧环境变量兼容缺少直接 AC 验证。"
}
```

L3_artifact_hash: aebe7fc72e1c041895963b6754ad7674576224dc77169fda387741f376e582cc

<!-- /L3-SECTION -->
