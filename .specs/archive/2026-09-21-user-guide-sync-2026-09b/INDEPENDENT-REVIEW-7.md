
---

## L2 盲审

**独立性声明**：本次输入仅有固化指令全文 + 阶段/change-id/仓库根/工件路径白名单（无主 agent 自评、草稿、概述、辩护）。所有结论来自我独立复跑或独立读原文；未修改任何文件、未 commit、未跑 `make check`。

**独立复跑指纹**（2026-09-21 23:3x，本容器）：
`verify-ac.sh` **128 通过 / 0 失败 rc=0**（分段 AC-1 4 · AC-2 39 · AC-3 **59** · AC-4 23）· `check-appendix-superset.py` **rc=1**（检查单元格 59 · 跳过 21 · **附录 A 缺失 1**）· `verify-boundary.sh` **rc=0**（16 条已核对 / 禁动域 0 / `check-dist` rc=0）· `npx bats test/test_guide_copy_parity.bats` **1..8 / 8 ok** · 四副本 md5 唯一值 **1**（`886d1c81c86ae4e0b8c43c07b8c1ee85`，各 1693 行）· pptx 24 页且正文与 `slides.json` 一致（pptx 文本 ↔ slides.json 标题/正文字符串比对，24/24 命中）。

### 🔴 R1 · 阶段 5/6 声称为绿的「附录 A ⊇ 母本」集合断言**当前 rc=1**，且失败明细已指名：D04 反例格为空缺；TEST.md/UAT.md 仍以陈旧数字宣称 `缺失 0`

**Severity**：🔴 Critical
**Symptom（症状）**：
- 实跑 `python3 .specs/user-guide-sync-2026-09b/check-appendix-superset.py` → `检查单元格：59 个；跳过（无可抽锚点）：21 个；附录 A 缺失：1 个` + `MISSING: D04 反例: 若走 dsh plugin add/update 重装`，**rc=1**（`check-appendix-superset.py:66-71`）。
- 该判据是**声明的验收判据**，不是我挑出来的额外要求：`TASK.md:337`（附录 A 母本声明）「附录 A 是它的**超集**……两者冲突时**以 AC 表为准**并回填本附录——阶段 5 的 TEST.md 含一条集合断言 `附录 A ⊇ AC-2/AC-3 表`（逐条比对锚点串，**缺失即失败**）」；`TASK.md:284`（T07 verify）把它写进硬判据 `… && python3 …/check-appendix-superset.py >/dev/null`；`UAT.md:17`（UAT-5）期望值 = `缺失 0`。
- 缺口本体可逐字复现：`REQUIREMENT.md:82`（母本 · D04 反例行）v4.6 已把反例改为字面串 `` `若走 dsh plugin add/update 重装` ``（并注明「判据实现在 `verify-ac.sh` 同步」）；而 `TASK.md:347`（附录 A · D04）仍是**另一个串** `` `dsh plugin --profile <profile 名> update dsh-flow-kit`（作为首选更新路径） ``，全文 `grep -F '若走 dsh plugin add/update 重装' TASK.md` = **0**。三处写法互不相同：母本 / 附录 A / `verify-ac.sh:101`。
- 证据链已过期：`TEST.md:78-79` 贴的「实时输出」是 `58 个 / 跳过 20 / 缺失 0`，`UAT.md:17` 记 `✅ rc=0`。而我实跑得 `59 / 21 / 1`（rc=1）。`REQUIREMENT.md` 与 `TASK.md` mtime 均为 **23:31**，晚于该证据的采集时点——母本在证据采集后被改，附录 A 没回填，**没有任何人复跑过这条判据**。
**Source（源头）**：`TASK.md:337` 母本声明（v4.5 · L2 R24/R1）+ `TASK.md:284` T07 verify + `UAT.md:17` UAT-5；L-108（锚点必须逐字且三处一致）/ L-102（「核错对象」是假绿复发形态）。
**Consequence（后果）**：① 归档产物里同时存在「缺失 0」的结论与「缺失 1 / rc=1」的实现，任何审计者复跑即推翻；② 权威序列（母本）与执行序列（附录 A）分叉，D04 这条反例在附录 A 里**没有可执行判据**——「旧的首选更新路径不得回流」这件事既没被断言也不知道该断言哪个串；③ 该缺陷与 `REVIEW.md:14`（AC-2/AC-3 全过）、`REVIEW.md:85`（「全绿」）直接冲突，而归档就在本轮之后。
**Remedy（修补）**（二选一，且**三处同改**）：
```text
A) 以母本为准回填附录 A：
   TASK.md:347  D04 反例格 → `若走 dsh plugin add/update 重装`（保留「作为首选更新路径」仅作说明文字，勿写成锚点）
B) 以附录 A/脚本为准回退母本：
   REQUIREMENT.md:82 反例格 → `执行 \`dsh plugin --profile <profile 名> update dsh-flow-kit\``
   （IR-3 第七轮 R4 的原始建议；实测该串四副本 0 命中，改前不成立，有判定力）
然后二者都必须：
   python3 .specs/user-guide-sync-2026-09b/check-appendix-superset.py   # 期望 rc=0 · 缺失 0
   bash    .specs/user-guide-sync-2026-09b/sync-counters.sh             # 由实跑回填 TEST/UAT 数字
```
**注**：不要用「反例改用旧的首选更新路径整句」这句注释里的 `verify-ac.sh` 被抽成锚点这件事来判脚本错——`check-appendix-superset.py:47` 的 NOISE 过滤已含 `（`/`）`，说明句整体被剥掉；抽出 `verify-ac.sh` 属次要（见 R2 的副项）。

### 🟡 R2 · 「计数类事实」三源仍分裂：TEST.md 自引 129（分段和 126+3）、同文件贴的出参是 128（分段和 125）、REVIEW.md 与 CHANGELOG 又各写一套

**Severity**：🟡 Important
**Symptom（症状）**（全部为独立复跑，命令：`bash .specs/user-guide-sync-2026-09b/verify-ac.sh`）：
- 实跑出参：`AC-1 4 / AC-2 39 / AC-3 59 / AC-4 23` → 段内和 **125**，行 `断言通过：128`，`段外单元：3` —— 125 + 3 = 128 **自洽**。
- `TEST.md:68` 同段贴的出参也是 `断言通过：128`，但 `TEST.md:62` 的分段行写 **`AC-3 通过 60`**（实跑 59）；按它自己的分段 4+39+60+23 = **126** + 3 = 129。即 **TEST.md §2 段落内部对不上**（因为「先有 129 结论、后改脚本」，脚本输出是回填时手抄/漏抄）。
- `TASK.md:316`（T08 步骤 4）写「现为 **8 用例 / 129 通过**（分段 4+39+60+23 = 126 + 段外 3）」；`REVIEW.md:85` 写「`verify-ac.sh` **106 通过 / 0 失败**……（分段 AC-1 4 · AC-2 39 · AC-3 59 · AC-4 23 + 段外 3）」——分段和 125 + 3 = 128 ≠ 106。**同一份 change 的验收数字在 4 个文件里并存 106 / 128 / 129 三个值**，且 106 的那处连自己的分段都对不上。
- `REVIEW.md:23` 另有「计时 **0.002 s**」「8 用例全绿」等与 `TEST.md` 不同轮的残留（本轮未逐条核，仅说明该文件是多轮拼接、数字未收敛）。
**Source（源头）**：MINOR-DEFERRED **M17**（「计数类事实应**从实跑输出生成**而非手抄」）+ `sync-counters.sh:2-8` 自述「让数字只有一个来源」+ L-108。
**Consequence（后果）**：`sync-counters.sh` 是 v4.5 为**根治**这一类缺陷而写的回填器，而它自己产出的数字仍与脚本实跑不符（说明回填器未在最终态跑过，或跑在旧脚本上）；归档 commit 会把三套数字一并固化，下一个读到 `REVIEW.md:85` 的人复跑必得 128 → 审计结论自相抵消。**距归档只有一步，属于「现在不修就永远带着走」的窗口。**
**Remedy（修补）**：以实跑为唯一来源做一次全量回填，并**加一条可复算的自检**（回填器已有全部素材，只差断言）：
```bash
# 1) 回填
bash .specs/user-guide-sync-2026-09b/sync-counters.sh
# 2) 自检：分段和 + 段外 3 == 断言通过（防止再次手抄）
VA=$(bash .specs/user-guide-sync-2026-09b/verify-ac.sh)
seg=$(printf '%s\n' "$VA" | awk '/^  AC-[0-9]/{s+=$3} END{print s}')
tot=$(printf '%s\n' "$VA" | sed -n 's/^- 断言通过：//p')
[ "$((seg+3))" = "$tot" ] || { echo "❌ 分段和不等于总数：$seg+3 != $tot"; exit 1; }
```
另：`sync-counters.sh:36-37` 的 `pat_seg` 只匹配 `AC-1 N · AC-2 N · …` 这一种书写，`REVIEW.md:85` 用的是 `（分段 AC-1 4 · AC-2 39 · …）`，**结构上匹配不到**（静默漏回填）——把该正则放宽为 `AC-1\s*(\d+)[^0-9]+AC-2\s*(\d+)[^0-9]+AC-3\s*(\d+)[^0-9]+AC-4\s*(\d+)`，或统一各文件的书写模板。

### 🟡 R3 · AC-7 的目视证据比终态 deck **早 26 分钟**，而 TEST.md 列的 6 张抽检页与其自述「重渲」不是同一批

**Severity**：🟡 Important
**Symptom（症状）**：
- `flow-kit-用户指南.pptx` mtime = **23:03:04**（其内部 zip entry 时间戳全部 = 2026-09-21 23:03:04，即它是**在 23:03 被完整重写**的，不是元数据触碰）；`render-preview/slide-01..24.png` mtime = **22:36:47**（`ls -la` 实测）。**目视证据比它声称渲染的 deck 早 26 分钟。**
- 上游处置自述与现状矛盾：`INDEPENDENT-REVIEW-6.md:247`（阶段 6 响应 R7）写「已删除并按**终态 pptx（22:30:58）**重新渲染 24 张 PNG（22:36:45）」；而现存 pptx 是 **23:03:04**、mtime 更晚的 PNG 为 **22:36:47**——「终态 pptx」这一前提在本轮已不成立，且 `TEST.md` 未记录 23:03 的重建与其后的重渲（`grep -n '23:0' TEST.md` 无命中）。
- `TEST.md:121`（§3.3 人工抽检）列的抽样页是「封面 + 21/22/23/24 + **改动页 10/11/16/19**」，而 IR-6 R7 的修复动作与 §3.3 的机检段都未声明 10/11/16/19 被重渲；机检的「无空页/尺寸」是**基于 22:36 那批 PNG**。
- 现存的守护**结构上盖不到这一条**：`test/test_guide_copy_parity.bats` 用例 4 只比「pptx 页数 == slides.json 页数」与「封面日期 == 指南版本行日期」，用例 8 只比「slides.json 标题出现在 pptx 文本」——**没有任何断言把 render-preview 与 pptx 的新鲜度绑起来**（IR-2 R23/IR-6 R7 两轮已提出同类缺口，本轮仍是缺口）。
**Source（源头）**：`REQUIREMENT.md:145`（AC-7 机检 + 人工抽检口径）+ L-109（守护要守「结果一致性」而非「过程动作」）——「pptx 重建后 render-preview 未重跑」正是「结果不一致」且当前无判据的形态。
**Consequence（后果）**：归档目录里作为 AC-7「无溢出 / 无缺字」唯一证据的 6 张目视 PNG，渲染的是**上一版** pptx 的对应页；23:03 的重建（`slides.json`、`build.py` 同批 23:00 改动之后）其排版从未被看过。AC-7 的人工结论因此**略超出其证据范围**（与 M7 的「替代字体」并列为第二处口径外延）。不修则下一轮任何人拿 PNG 复核都会对错版本。
**Remedy（修补）**：`build.py` 重建是幂等的，重渲即可闭合，并补一条**可复算的新鲜度判据**（mtime 比较即可，不必引新依赖）：
```bash
# TEST.md §3.3 增为 AC-7 的重跑判据
soffice --headless --convert-to pdf --outdir <tmp> flow-kit-用户指南.pptx
pdftoppm -png -r 80 <tmp>/flow-kit-用户指南.pdf .specs/user-guide-sync-2026-09b/render-preview/slide
# 判据：每张 PNG 的 mtime 必须晚于 pptx 的 mtime
find .specs/user-guide-sync-2026-09b/render-preview -name '*.png' -newer flow-kit-用户指南.pptx | wc -l   # 期望 24
```
并把该 `find -newer` 计数加进 `test_guide_copy_parity.bats` 用例 4（与现有「页数 + 封面日期」同一处），使「重建 pptx 忘重渲」必红。

### 🟡 R4 · T08 的 `verify` 里写死 `grep -q "972" .specs/STATE.md`，按现状**恒假**——T08 是阶段 7 归档动作的收官判据

**Severity**：🟡 Important
**Symptom（症状）**：`TASK.md:323`（T08 verify）逐字含 `... && grep -qE "last_change_archived.*user-guide-sync-2026-09b" .specs/STATE.md && grep -q "972" .specs/STATE.md && ...`；而 `.specs/STATE.md` 的 `test_framework` 行现状为 `bats-core 1.13.0 (npx) · 964 tests …`（`972` 在 STATE.md 全文 **0 命中**，我独立 grep 复核）。T08 步骤 5 只要求「更新 `last_change_archived` 链与 `test_framework` 计数」，**没有要求把计数改成 972**，两者口径不一致。
**Source（源头）**：`TASK.md:316` 同任务的自身口径「**以 `verify-ac.sh` 实跑输出为准**，本行不写死」；L-108（写死的数字断言没有判定力/必假）。
**Consequence（后果）**：两种走法都坏：① 执行者照 §5 只改归档链 → `verify` 永远 fail，T08 无法自证完成（而它是 `done` 里「AC-11 闭合」的载体）；② 执行者为了让 verify 过而把 `test_framework` 改成 972 → 写进 STATE.md 的计数是**错的**（本 change 全量 bats 实为 973 例，见 `bats-full.log` 与 `CHANGELOG.md:4`）。这是「判据驱动数据造假」的标准诱因。
**Remedy（修补）**：把写死值换成形态断言（与我给 R2 的同一手法）：
```diff
- grep -q "972" .specs/STATE.md
+ grep -qE "bats-core 1\.13\.0.*9[0-9]{2} tests" .specs/STATE.md
```
并在 §5 明写「计数从 `npx bats test/ --formatter tap | tail -1` 与 `bats-full.log` 生成」。

### 🟡 R5 · 归档清单（`ARCHIVE-MANIFEST.txt`）会记录一份**随后仍被改写**的 `INDEPENDENT-REVIEW-7.md` 的 sha256——清单在归档目录里出生即失真

**Severity**：🟡 Important
**Symptom（症状）**：`make-manifest.sh:24-33` 用 `find "$DEST" -maxdepth 1 -type f … sha256sum` 给**目录内每个文件**盖章；而本 change 的 `.specs/user-guide-sync-2026-09b/INDEPENDENT-REVIEW-7.md` 此刻只有 L3 段（我读到的全文 48 行），我的 L2 段（本段）与 T08 步骤 1 要求的 `## 主 agent 响应` 段都发生在清单生成**之后**。即清单记录的 hash 在生成瞬间就与最终件不同（且 `find` 会同时把 `make-manifest.sh` 自身与 `run-l3.sh`/`sync-counters.sh` 一并登记）。
**Source（源头）**：`TASK.md:314`（T08 step 2 「**先生成清单、后 mv**」的排序是对的，问题在「清单之后仍有写入者」）；对照上一轮归档 `2026-09-21-brooks-review-fix-2026-09/ARCHIVE-MANIFEST.txt`：其 `INDEPENDENT-REVIEW-6.md` 记录的 `sha256:d01fcc09a546010a` 与归档件实际值**逐位相同**（我独立复算）——说明上一轮是「先定稿、后盖章」，本轮若照 T08 字面执行则不是。
**Consequence（后果）**：清单的全部价值在于「归档件可验证未被篡改」；若被登记的 `INDEPENDENT-REVIEW-7.md` hash 与归档件不符，则整份清单的可信度对**最关键的那一份**失效，且失败形态是「看起来有清单」的假绿（受众不会去逐条复算 25 行 hash）。
**Remedy（修补）**（两条，任选其一，前者更省事）：
```bash
# A) 保持"先清单后 mv"，但把清单生成改为**最后一步**：定稿 L2 段 + 主 agent 响应段 → 生成清单 → mv
#    （即 T08 的 step 1 与 step 2 之间不得再有对产物目录的写操作；如需 L3 追加重审，就在 L3 之后再生成）
# B) 清单生成后加一条自校验，把"出生即失真"变成显式失败：
cd "$DEST" && while read -r f h; do
  [ "$(sha256sum "$f" | cut -c1-16)" = "$h" ] || { echo "❌ 清单自校验失败: $f"; exit 1; }
done < <(grep 'sha256:' ARCHIVE-MANIFEST.txt | awk '{print $1, substr($NF,8)}')
```
另建议：`make-manifest.sh` 把「生成时间」写入后，归档 commit 前对 `INDEPENDENT-REVIEW-*.md` 与 `.done` 之外的文件做一次 `git status` 空判据（T08 step 7 已有，但需与清单时点对齐）。

### 🟢 R6 · `INDEPENDENT-REVIEW-7.md` 缺阶段 7 要求的首行与分段标题，现有首行是空行

**Severity**：🟢 Minor
**Symptom（症状）**：文件首部现状为 `第 1 行 = 空行`、`第 2 行 = ---`、`第 4 行 = ## L3 盲审（…）`；而阶段 7 调度模板要求「若文件不存在则新建，**首行加 `# 独立审查 · 阶段 7`**」，固化指令 §输出要求同款。由 L3 子系统先手创建时未落该行，后续 L2 段也就无从遵循。同类形态在 `INDEPENDENT-REVIEW-5.md:1` 已出现（该文件第 1 行是空行），说明这不是偶发。
**Source（源头）**：`7-integration.md` §L2 调度模板（输出行）+ `L2-blind-review.md` §文件写入约束 2。
**Consequence（后果）**：文件级元数据缺失，人工/工具按 `^# 独立审查 · 阶段 7` 定位该产物会落空；不影响门禁（`l3-section.sh` 按 `^## L3` 判段）。
**Remedy（修补）**：归档前在 `INDEPENDENT-REVIEW-7.md` **第 1 行**插入 `# 独立审查 · 阶段 7`，并把 `## L2 盲审` / `## L3 盲审` 的层级保留（若插入一级标题，需同步确认 L3 子系统仍按 `^## L3` 追加）；随后**重生成清单**（与本条 R5 的时序耦合，务必在同一批完成）。

### 🟢 R7 · `CHANGELOG.md` 本 change 行的审查描述笼统到不可复算：「阶段 5/6 同规格」

**Severity**：🟢 Minor
**Symptom（症状）**：`.specs/CHANGELOG.md:4` 结尾「**审查**：pipeline 0→7 `gate_config` 六阶段 `both`；阶段 1 经 L2 五轮 + L3（首轮 fail→修→pass）· 阶段 2 经 L2 四轮 + L3 pass · 阶段 3 经 L2 五轮 · **阶段 5/6 同规格**；逐轮响应段留痕，全部 🔴 已入 fix loop 处置。| L-106 ~ L-109」。「同规格」未给轮数；实测 `INDEPENDENT-REVIEW-5.md` 有 **5 个** `## L2 盲审` 段、`INDEPENDENT-REVIEW-6.md` 只有 **1 个**——两者并不同规格，且阶段 6 的 L2 是**单轮 pass**（未走 fix loop），与「逐轮响应段留痕」的暗示不一致。
**Source（源头）**：L-082（「REVIEW.md 的处置表是 L3 主判最快的闭环载体」——即审查链现状必须可复核）；`REVIEW.md:71-79` 的表格本就是权威来源。
**Consequence（后果）**：CHANGELOG 是跨 change 的审计入口，读者无法据此判断本 change 的审查强度；「同规格」这类不可证伪表述在归档后无法回溯。
**Remedy（修补）**：把该句替换为 `REVIEW.md:73-79` 表格的逐阶段数字（阶段 5：L2 五轮 + L3 熔断 bypass；阶段 6：L2 单轮 pass + L3 pass），或直接指向 `REVIEW.md §5.1`。

### 归档就绪性结论（阶段 7 checklist 逐项）

| 检查项 | 判定 | 依据 |
|---|---|---|
| 产物齐全（CHANGE/REQUIREMENT/DESIGN/TASK/DEV-SUMMARY/TEST/UAT/REVIEW/MINOR-DEFERRED + IR-1/2/3/5/6/7 + 4 个验证脚本 + 日志 + render-preview ×24） | ✅ | 目录实测；6 键 PCSC 清单要求的 6 件全部在位；dev-summaries 以 DEV-SUMMARY.md 收敛亦为 DESIGN 声明口径 |
| `make-manifest.sh` 存在且自带双自检（目标不存在→rc=2 · 条目 <10→rc=1） | ✅ | `make-manifest.sh:17,41-42`，实测逻辑与我读到的源码一致 |
| 归档顺序「先原位生成清单、再 mv」 | ⚠️ | T08 step 2/3 顺序正确，但清单之后仍有写入者（**R5**） |
| `MINOR-DEFERRED` 完整性 | ✅ | M1–M26，逐条带 Task / Finding ID / 理由 / 日期；L3 熔断两条（M24/M25）含重试方式；表头格式符合 ADR-017 |
| 残留临时文件 | ✅ | 产物目录内无 `*.pyc`/`.l3-attempts-*`/`*.bak`/`*.orig`/`*.pdf`/`*~`；`render-preview/` 内 24 PNG 无 PDF 残留；`.specs/user-guide-deck-gen/__pycache__` 在 `.gitignore:69-70` 且不在归档面 |
| `.done` 锚点（1/2/3/5/6） | ✅ | 5 个文件均为 6 行 KVP，`written_by ∈ {pre-tool-use-gate, l3-bypass}`（非空 touch），与各 IR 的 L2/L3 段一致（1/2/6 = pass/pass；3/5 = pass/skipped 且 IR 内确有 bypass 审计段） |
| `.independent-review-7.done` | ⏳ 未写（正确） | 文件不存在 = 本轮 gate 仍生效；不得手工 touch（`gate-helpers.sh:116-126` path-guard） |
| LESSONS 同步 | ✅ | L-106~L-109 已入库于 `<!-- user-guide-sync-2026-09b 追加 ↓ -->` 段内，无重复行，表头 7 列与行一致 |
| CHANGELOG 更新 | ⚠️ | 本 change 行已在文件头部（符合 L-082 的采样口径）、整行完好无截断；但审查描述笼统（**R7**）、数字与实跑不符（**R2**） |
| STATE.md | ⏳ 待归档动作 | `last_change_archived` 仍指向上一个 change（正确）；T08 step 5 将顺延 |
| 验收证据与实跑一致性 | ❌ | **R1（rc=1）/ R2（三套数字）/ R3（证据早于成品 26 分钟）** |
| L-031 跨文件一致性扫描（独立全仓） | ✅（范围外残留已登记） | `三轮审查` 残留仅命中 `flow-kit-bundle/skills/flow-review/SKILL.md:6,24,196`、`flow-kit-bundle/flow-kit/README.md:304`、`templates/REVIEW.md:73` 及其 dist/vendor 再生镜像 —— 与 M8/F2 登记一致（AC-9 冻结域，不越界）；四份指南副本 `三轮审查` = 0、`20000 字节` 仅 1 处历史句、`五门` = 0、`.specs/lessons/` = 0 |
| 修代码优先（🔴/🟡 处置） | ⏳ 待主 agent 响应 | 本段 R1–R5 全部要求**代码/产物变更**，不接受 `Tech-debt:`（R1 是自身声明的验收判据失败；R2/R3/R4 是写死数字与过期证据，皆可在分钟内修完） |

**Verdict**: fail

（唯一 🔴 = R1：`check-appendix-superset.py` 是本 change **自己声明**的验收判据（`TASK.md:284` T07 verify / `UAT.md:17` UAT-5 / `TASK.md:337` 母本声明），当前 **rc=1 · 缺失 1**，而 TEST/UAT 仍以陈旧数字宣称 `缺失 0`。R1 修完（二选一 + 重跑两个脚本 + 回填数字）后 R2/R3/R4/R5 可在同一批内闭合，**R6/R7 按 ADR-017 记入 MINOR-DEFERRED**。归档动作（`mv`）建议在本段各项复跑为绿后再执行，以便 R5 的清单时序一次做对。）

---

## 主 agent 响应（阶段 7 · L2 首轮 R1–R7 · 2026-09-21）

| # | Sev | 处置 | 动作 |
|---|---|---|---|
| R1 | 🔴 | **Fixed in: TASK 附录 A D04 行（v4.6）** | 回填为与母本 REQUIREMENT 同串 `若走 dsh plugin add/update 重装`；实跑 `check-appendix-superset.py` 由 **缺失 1 → 缺失 0**（59 格 / 跳过 21）。同时 `verify-ac.sh` 的 D04 反例保持与两处同源（旧首选路径句四副本 0 命中） |
| R2 | 🟡 | **Fixed in: TEST/REVIEW/TASK 数字三源归一** | 以 `verify-ac.sh` 实跑为准：**128 通过 / 0 失败**（AC-1 4 · AC-2 39 · AC-3 **59** · AC-4 23 + 段外 3 = 128）；TEST.md §2 的分段行由 60 改 59、TASK 的「129」改 128、REVIEW.md 的 106 改 128。并记录 `sync-counters.sh` 的 `pat_seg` 匹配不到 REVIEW 写法这一缺陷（v2 改为从脚本分段输出直接生成段落） |
| R3 | 🟡 | **Fixed in: 重渲 + bats 用例 4 增新鲜度断言** | 已删除并按**终态 pptx**（23:03:04）重渲 24 张 PNG（`find render-preview -name '*.png' -newer pptx` = **24**）；用例 4 新增「全部 PNG 必须比 pptx 新」断言（旧证据 → 必红），bats 仍 **8/8 ok** |
| R4 | 🟡 | **Fixed in: TASK T08 verify（v4.6）** | 写死的 `grep -q "972"` 改为**形态断言** `grep -qE "bats-core 1\.13\.0.*9[0-9]{2} tests"`（v4.6 前恒假） |
| R5 | 🟡 | **Fixed in: TASK T08 步骤 2（v4.6）** | 清单生成**移到 L2 段与主 agent 响应段定稿之后**（避免给仍会被写入的 IR 文件盖章 → hash 出生即失真，与上一轮归档「先定稿后盖章」对齐） |
| R6 | 🟢 | **Tech-debt: MINOR-DEFERRED M27** | IR-7/IR-5 缺首行标题（格式洁癖，不影响判据） |
| R7 | 🟢 | **Fixed in: CHANGELOG 措辞** | 「阶段 5/6 同规格」改为**逐阶段实述**（阶段 1 五轮 + L3 / 阶段 2 四轮 + L3 / 阶段 3 七轮 + 熔断 / 阶段 5 五轮 + 熔断 / 阶段 6 单轮 pass + L3 pass / 阶段 7 本阶段）→ M28 留痕 |

**复审请求**：R1 为唯一 🔴，已闭合（集合断言 rc=0）。R2–R5 均已落地并实跑复验；R6/R7 入 MINOR-DEFERRED（M27/M28）。

---

## L3 重审（deepseek-v4-flash-0731 外部模型 · 2026-09-21 23:39）

> 自动生成于 2026-09-21 23:39。由 l3-review.sh 写入。

### 审查结论

```json
{
  "critical": [],
  "major": [
    {
      "file": ".specs/CHANGELOG.md",
      "issue": "归档条目疑似被截断：最后一行止于「L3 据残缺工件」，未给出该 change 的完整闭环结论（验证/审查/归档），也未提供 LESSONS 新增等收口信息。",
      "why": "CHANGELOG 是跨会话追溯依据，条目必须完整描述 change 的影响、验证与后续状态；当前条目在关键结论处中断，读者无法确认该 change 是否完整闭环。",
      "fix": "将 CHANGELOG 中 brooks-review-fix-2026-09 条目补全到完整收口语句（含验证与审查结论），或确认仓库中该条目实际完整并重新提供未截断版本。"
    },
    {
      "file": "REVIEW.md",
      "issue": "AC-11 在 REVIEW.md 中标注「⏳ 阶段 7 收口」，未给出最终通过结论；且阶段 7 的独立审查记录 INDEPENDENT-REVIEW-7.md 虽有文件存在，但其正文未纳入本次工件预览，无法核验其 L2/L3 结论。",
      "why": "REVIEW.md 是阶段 6 审查产物，职责应包含 AC-11 的审查结论；若 AC-11 依赖阶段 7 归档，REVIEW.md 至少应在阶段 7 完成后回填最终结论，否则审查链未闭合。",
      "fix": "在 REVIEW.md 的 AC-11 行补上阶段 7 完成后的最终结论（L2/L3 通过、归档完整），并将 INDEPENDENT-REVIEW-7.md 的关键结论（至少 L2/L3 判定）在预览范围内可见或明确引用。"
    },
    {
      "file": "TEST.md",
      "issue": "TEST.md 的 AC 覆盖矩阵中 AC-4 写「N1–N13 + N12」，N12 与 N1–N13 的范围重叠且 N13 未在 REQUIREMENT 预览中说明，计数口径混乱；同时 UAT.md 声称「母本集合断言缺失 0」，前次审查曾指出该数字陈旧，本次预览中 UAT.md 只给出「缺失见 TEST.md 实时输出」的引用，未提供实际数字。",
      "why": "计数与锚点范围不一致会削弱验收证据的可核验性；UAT 表以引用代替实测数字，无法确认陈旧数字问题是否已修复。",
      "fix": "统一 AC-4 的锚点编号范围（明确 N1–N11 + N12 或 N1–N13 的实际清单），并在 TEST.md/UAT.md 给出权威实测计数（如 AC-4 段 23 条、缺失 0 的实时输出），避免引用式留空。"
    }
  ],
  "minor": [
    {
      "file": "INDEPENDENT-REVIEW-6.md / .independent-review-6.done",
      "issue": "阶段 6 独立审查记录与 .done 锚点在产物目录中存在，但正文未提供，无法核验其 L2/L3 结论及与 REVIEW.md 的关系。",
      "why": "按审查要求，补充产物一旦给出正文须纳入审查；此处文件存在但正文未展示，至少应能通过 REVIEW.md 或阶段 7 记录交叉验证其结论。",
      "fix": "在阶段 7 记录中明确引用 IR-6 的 L2/L3 结论，或在后续审查中提供 IR-6 的关键段落。"
    },
    {
      "file": "UAT.md",
      "issue": "UAT-B4 引用 MINOR-DEFERRED 的 M1–M23，但预览中 MINOR-DEFERRED.md 仅展示到 M7，未确认是否确有 23 条。",
      "why": "M1–M23 是用户 triage 的范围声明，若实际只有 M7 则计数错误；若确有 23 条，宜在预览中确认总数。",
      "fix": "在 MINOR-DEFERRED.md 开头或 UAT-B4 中给出总条数（如 23）的明确声明，确保与表内条目一致。"
    },
    {
      "file": "CHANGELOG.md",
      "issue": "CHANGELOG 中 user-guide-sync-2026-09b 条目宣称「母本集合断言 59 检查格（跳过 21）（跳过 20 已列明）」，但「跳过 21」与「跳过 20」同时出现，计数表述疑似矛盾。",
      "why": "此类计数若不一致会削弱验证可信度，需要明确是两类跳过（如 21 个总跳过中含 20 个已列明）还是笔误。",
      "fix": "统一表述为「跳过 21（其中 20 已列明）」或类似无歧义句式。"
    }
  ],
  "verdict": "fail",
  "summary": "必备件与补充件基本齐全，但 CHANGELOG 条目截断、REVIEW 的 AC-11 未闭环、TEST/UAT 计数口径存在矛盾，需补全后方可通过。"
}
```

L3_artifact_hash: 42a8958485979d007db22d4747fdac2923e7ab8115ebec6c2314a4867bdeb7f7

<!-- /L3-SECTION -->

---

## L3 重审（bypass · 2026-09-21 23:39）

> **熔断触发**：本阶段外部模型 L3 已连续 3 次返回 fail 且未收敛
> （阈值来源：stop-hook.json 的 independent_review.max_failures_before_bypass）。
> 按 ADR-005 降级路径结案：写入 .done 且 L3_verdict=skipped，pipeline 继续推进。
> 本段即审计痕迹——不伪装 L3 pass，人工可据此复核。
> 清理计数：删除 `.l3-attempts-7` 即可重新尝试 L3。

<!-- /L3-SECTION -->