# 独立审查 · 阶段 3

## L2 盲审

审查范围：全读 `TASK.md`（233 行）/ `REQUIREMENT.md`（134 行）/ `DESIGN.md`（142 行）；只读核验（TASK verify 行原文、stop-hook.json modules 键、deck-gen 目录 glob、指南禁词 grep）。单次盲审 pass，未做修复、未跑测试；未检测到主 agent 自评/概述/辩护注入，独立性未受损。

### 核对通过项（证据）
- 七字段齐全：T01–T09 均有 id/name/read_files/write_files/action/verify/done；编号连续无跳号。
- 依赖图无环。MD 同文件串行链正确：T01→T02→T03→T04→T05（depends_on，TASK.md:43/64/86/102/119）；deck 链 T06→T07→T08→T09，T08 另依赖 T03（TASK.md:186）；T07/T08 仅同写 slides.json+pptx，已串行。
- [P] 同波并行无真实文件冲突：T01|T06、T02|T07、T04|T08、T05|T09 均写不同文件。
- write_files 零禁动命中：全部落在 DESIGN 0.5.1「触碰+新增」清单（DESIGN.md:24-33）；`flow-kit-bundle/FLOW-KIT-用户指南.md`（T05）在触碰清单内（DESIGN.md:26），放行；未触碰 hooks/skills/lib/install.sh/.specs/archive 既有文件/tech pptx/ecosystem guide/根 README/dsh-flow-kit README|DESIGN。
- 实物核对：stop-hook.json modules 键 = 12 个，与 AC-3e 所列 12 键名逐字一致（REQUIREMENT.md:42）。XML 实体（&amp; 等）解析后，T01–T06/T08 的 verify 为合法 shell；T06/T08 的 build.py/deck_checks.py 路径、T05 的 cmp/make test 用法正确。

### 发现

### 🔴 R1 · T07 verify 破损：非机器可执行、可假绿可假红
**Severity**：🔴 Critical
**Symptom**：TASK.md:164 verify 有三处硬伤：(1) `python3 - <<'PY' 2>/dev/null` 无终止符 PY，空 heredoc 喂给 python3 -——单行执行时空读退出 0，build/deck_check 失败被掩盖；若按多行脚本执行则吞掉其后全部断言；(2) 引用 `/tmp/deck_check.py`，TASK 内无任何 task 创建该文件（T08 创建的是 `.specs/user-guide-deck-gen/deck_checks.py`，TASK.md:178）；(3) 末命令对二进制 pptx 的 `grep -c '三级优先级链'` 无零命中断言（缺管道 `| grep -q '^0$'`），且作为整条 verify 的末命令直接决定退出码——无命中即整体 fail、有命中反而 pass，与「禁词 0」语义相反。
**Source**：阶段 3 checklist「verify 可机器执行」；REQUIREMENT.md:58（AC-5：python-pptx 文本断言 + 页数=20 固化于 deck_checks.py）。
**Consequence**：T07 门禁对 AC-5 失效：正确产物误 fail、build 失败可假 pass；DEV 执行者只能绕行或 hack，错误延迟到 T08/TEST 才暴露。
**Remedy**：改写为单一可执行链：build 后用带终止符 PY 的 heredoc python（python-pptx 提取文本）断言页数=20 与禁词 0，或把该断言移入 T08 deck_checks.py、T07 verify 只保留 build 成功；禁词检查作用于文本源而非二进制 pptx；删除 /tmp/deck_check.py 引用。

### 🟡 R2 · AC-2 禁词清单在 T04 verify/action 中被截断
**Severity**：🟡 Important
**Symptom**：TASK.md:99 verify 循环与 action a) 仅含 `20260713`/`17 个模块`/`三级优先级链`/`三级链`；AC-2 要求的「仅 Claude Code」「仅为 Claude Code」及加查串「只为 Claude Code」无任何 task verify 承接；「TODO/待补」占位只在 T04 action d) 删除（TASK.md:97），无 0-命中 verify。
**Source**：REQUIREMENT.md:30-31（AC-2 完整串清单）、REQUIREMENT.md:44（不得出现 TODO/待补占位）。
**Consequence**：执行者若在章节改写中引入/残留上述串，T01–T05 verify 全绿仍 AC-2 不达标，只能拖到 5-test/6-review 才爆。
**Remedy**：T04 verify 循环补入三个 Claude Code 独占串，并加一条 `grep -c 'TODO\|待补' FLOW-KIT-用户指南.md | grep -q '^0$'`（BRE 竖线转义）或等价 ERE。

### 🟡 R3 · AC-3e config 键列差集断言无 task 级承接
**Severity**：🟡 Important
**Symptom**：T03 done 声称对应 AC-3 e/f（TASK.md:84），但其 verify（TASK.md:83）只做 33/34 串与五级链串的存在性 grep、无「三级链 0」之外的集合比对；无任何 task verify 执行 REQUIREMENT.md:44 规定的 python 差集断言（stop-hook.json modules 12 键 ↔ 指南模块表 config 键列，差集为空）；T08 的 deck_checks.py 只断言 pptx（TASK.md:182），不校验 MD 表格。
**Source**：REQUIREMENT.md:42-44（AC-3e 验证方式，注明与 T01/T03 verify 对账）。
**Consequence**：「指南 config 键列 == stop-hook 实物 12 键」目前只靠执行者自觉（本次实物核验一致，属侥幸）；DEV 阶段无机器证据，差集泄漏要到 REVIEW 才可能被发现。
**Remedy**：T03 verify 内联 python 差集断言（解析 stop-hook.json modules 与指南表格 config 键列，差集非空则 exit 1），或在 TASK 显式注明该断言归 TEST.md 执行并指明 md 侧断言脚本由哪个 task 产出（当前无创建者）。

### 🟡 R4 · T07 依赖图与 read_files「§4/7 修订后文本」时序矛盾
**Severity**：🟡 Important
**Symptom**：T07 read_files 声明读 `FLOW-KIT-用户指南.md（§1/2/4/7 修订后文本）`（TASK.md:153），但 T07 depends_on 仅 T06（TASK.md:166），wave 2 与 T02（§4/5 修订）并行、早于 T03（§7，wave 3）——执行窗口内 §4/7 修订稿不存在；设计说明只声明「T08 在 T03 后」（TASK.md:18-19）。
**Source**：阶段 3 checklist「依赖链正确性、read_files 到位」。
**Consequence**：执行者照 read_files 会读到旧 §4/7 或被迫阻塞/编造；deck 文案与 MD 终稿临时漂移，只能由 T08 校准返工。
**Remedy**：给 T07 depends_on 追加 T03（移到 wave 4 与 T04/T08 同波），或删除 MD §4/7 的 read_files 并在 action 注明 slides 事实源 = 本 task 规格 + REQUIREMENT（T08 校准职责保留）。

### 🟡 R5 · T07 封面 URL 事实错误（hellrabb 漏写 rabbit）
**Severity**：🟡 Important
**Symptom**：TASK.md:161 页规划「1 cover（日期 2026-09-03 · github.com/hellrabb/flow-kit）」，仓库名缺 `it`。
**Source**：AC-1 来源行 `github.com/hellrabbit/flow-kit/tree/develop`（REQUIREMENT.md:23）；DESIGN 事实源口径。
**Consequence**：按页规划写入 slides.json 后，交付 PPT 首页出现不存在的仓库名；deck_checks 不查 URL，错误直接带出。
**Remedy**：改 `github.com/hellrabbit/flow-kit`；建议 deck_checks 增加首页 URL/来源串断言。

### 🟡 R6 · T06 粒度超 fresh-context / ≤200 行约束
**Severity**：🟡 Important
**Symptom**：TASK.md:121-145 单 task 同时新建 theme.py/layouts.py/build.py/README.md 并完成 19 页基线渲染与占位冒烟；DESIGN D4 自述生成器代码量约 600-800 行（DESIGN.md:66）。
**Source**：阶段 3 checklist「单 task ≤200 行变更、fresh-context 2-10 分钟」。
**Consequence**：单次 fresh context 执行量约数倍于上限，中途断点难恢复，阶段 4 diff 边界核验粒度变粗。
**Remedy**：拆分为 2-3 个串行 task（theme/layouts 移植；build+README+版本自检；基线渲染+冒烟），各 task 独立 verify。

### 🟢 R7 · DESIGN 与 TASK 对 deck-gen 文件状态描述矛盾
**Severity**：🟢 Minor
**Symptom**：DESIGN.md:32 称 theme.py/layouts.py/build.py/README.md「已建」；glob 确认四文件已存在于 .specs/user-guide-deck-gen/；TASK T06 却按「新建」写同一批文件（TASK.md:130-134,137-138）。
**Source**：DESIGN 0.5.1 与 TASK write_files 一致性；L-031 实物优先。
**Consequence**：T06 会覆写既有草稿或重复从零新建，diff 归属与 AC-7 白名单核验口径混乱。
**Remedy**：统一口径——若 T06 负责创建则改 DESIGN 文案，或 T06 注明「在 DESIGN 草稿上定稿并入库」，执行前用 git status 确认四文件为本次新增。

### 🟡 R8 · T09 verify 兜底路径无断言，页数错误可假通过
**Severity**：🟡 Important
**Symptom**：TASK.md:200 主链失败/缺 pdfinfo 时走 `|| python3 -c "...print(d.count(b'/Type /Page')-d.count(b'/Type /Pages'))"`，仅打印不比对，python exit 0 → verify 假绿；soffice 转换本身也无 exit-0 校验（TASK.md:198 仅 action 文字）。
**Source**：AC-6 验证方式（REQUIREMENT.md:64-65：转换 exit 0 + PDF 页数 = pptx slide 数）。
**Consequence**：PDF 页数≠20 或转换失败（残留旧 PDF）时 verify 仍可能整体 exit 0，AC-6 无机器保证；对压缩对象流的二进制计数亦不可靠。
**Remedy**：兜底改为真实断言（count==20 否则 sys.exit(1)），或将 verify 写成 `soffice ... && pdfinfo ... | awk '$1=="Pages" && $2!=20 {exit 1}'`。

### 🟢 R9 · T01 verify 未覆盖 AC-1 来源行
**Severity**：🟢 Minor
**Symptom**：TASK.md:40 verify 只断言版本行与 dsh 串，无来源 URL grep；AC-1 要求来源行仍指向 develop。
**Source**：REQUIREMENT.md:23（AC-1 验证方式）。
**Consequence**：头部编辑误删/改来源行时 T01 机器层不报。
**Remedy**：T01 verify 追加 `grep -q 'github.com/hellrabbit/flow-kit/tree/develop' FLOW-KIT-用户指南.md`。

### 🟢 R10 · AC-5「无空 slide」无机器断言承接
**Severity**：🟢 Minor
**Symptom**：AC-5 Then 含「无空 slide」（REQUIREMENT.md:57）；T08 deck_checks 描述仅列 20 页/首页日期/禁词 0/关键串（TASK.md:182），T07 action 提到的「无空页」自检（TASK.md:162）未固化进任何 verify。
**Source**：REQUIREMENT.md:57（AC-5 无空 slide 条款）。
**Consequence**：空页只能靠 T09 PNG 抽查/人工兜底，DEV 绿不代表该条款达成。
**Remedy**：deck_checks.py 增加逐 slide 提取文本、全空则 exit 1 的断言。

### 🟢 R11 · TASK 未注明 AC-8（L2/L3 门禁）承接位
**Severity**：🟢 Minor
**Symptom**：TASK.md 全文未写明本文件属 3-task 规划链、审查由 3-task 门禁承接（仅 T09 action 出现「人工/L2 审查可见」，TASK.md:198）。
**Source**：REQUIREMENT.md:74-79（AC-8）；DESIGN D6（DESIGN.md:68）已定义 gate_config=all 逐阶段走。
**Consequence**：执行侧可能误以为 AC-8 无人承接/漏审（实际由 3-task 门禁上的 L2/L3 审查完成）。
**Remedy**：TASK 头部或波次说明加一行：AC-8 的 3-task 门禁审查由 gate 上的 L2 盲审（本报告）与 L3 审查承接，实施链审查在 5/6/7 对应产物后执行。

**Verdict**: fail

## L2 重审

范围：只读 TASK.md 全量并对照上轮 R1–R11 逐项核验（单次快速复审）。

核验结果：
- R1 ✅ T07 verify = build.py && python-pptx 断言页数 20（无 heredoc、无 /tmp/deck_check、无二进制 grep）。
- R2 ✅ T04 禁词循环含「仅/仅为/只为 Claude Code」，另含 TODO|待补 0 命中。
- R3 ✅ T03 verify 内联 python 差集断言（stop-hook.json modules 各键均须出现在指南文本）。
- R4 ✅ T07 已移至 Wave 4，depends_on=T06,T03。
- R5 ✅ 封面/页规划 URL 为 github.com/hellrabbit/flow-kit。
- R6/R7 ✅ T06 action 注明骨架已于 DESIGN 收口前建好并通过冒烟，本任务为收尾核验+入库，含 git add tracked 收尾。
- R8 ✅ T09 verify = soffice && pdfinfo awk（Pages!=20 时 exit 1），无二进制兜底。
- R9 ✅ T01 verify 含 github.com/hellrabbit 来源 URL grep。
- R10 ✅ T08 action 含逐 slide 文本非空（无空页）断言描述。
- R11 ✅ 波次说明含 AC-8 承接句（规划链 3-task 门禁由 L2/L3 审查承接，实施链于 5/6/7 产物后执行）。

### 🟢 F1 · deck 侧禁词表述漏「仅为 Claude Code」
症状：T07 action 写「仅或只为 Claude Code」、T08 action 写「仅/只为 Claude Code」，均缺「仅为」，与 T04/R2 三串清单不一致，照写 deck_checks.py 可能漏查。
修法：两处统一为「仅/仅为/只为 Claude Code」；deck_checks 落地按完整三串断言。

### 🟢 F2 · 「T07 与 T04 并行（不同文件）」措辞有歧义
症状：T04 write_files 与 T07 read_files 同为 FLOW-KIT-用户指南.md，并行窗口可能读到 T04 清理前文本，并非完全「不同文件」。
修法：注明「写入对象不同；T07 只依赖 T03，T04 的清理由 T08 终校兜底」。

未发现 Critical/Important 残留。

**Verdict**: pass

---


---

## L3 重审（deepseek-v4-flash-0731 外部模型 · 2026-09-03 22:17）

> 自动生成于 2026-09-03 22:17。由 l3-review.sh 写入。

### 审查结论

```json
{
  "critical": [],
  "major": [
    {
      "file": "TASK 工件（整体）",
      "issue": "AC 覆盖无法验证：工件未给出 REQUIREMENT.md 的实际 AC 清单，仅在各 task 的 <done> 中以「对应 AC-x」形式自述覆盖。审查者无法仅凭工件确认「任务拆解覆盖 REQUIREMENT 全 AC」这一审查重点是否成立；T02 标注「对应 AC-3 c/d/f」与「AC-3 e」，但 AC-3 是否存在 c/d/e/f 子项、T04 的「AC-3 残留检查」是否覆盖全部残留，均无原始 AC 文本可核对。",
      "why": "盲审要求基于工件本身验证覆盖完整性，而工件未内嵌或被引用呈现 REQUIREMENT 的逐条 AC；<done> 中的 AC 编号是结论而非证据，无法证伪覆盖遗漏。",
      "fix": "在 TASK 工件中逐条列出 REQUIREMENT.md 的 AC（或摘录 AC 原文/id），并为每个 task 的 <done> 标注其满足的具体 AC 条目与验收点；至少保证审查者可核对 AC 全集与任务并集的映射。"
    },
    {
      "file": "T05 verify / depends_on",
      "issue": "T05 的 verify 中 `make test > /tmp/flowkit-make-test.log 2>&1; rc=$?; tail -1 ...; [ $rc -eq 0 ]` 在 shell 中实际等价于 `tail` 的退出码判断；在 set -e 环境下若 make test 失败会提前退出，但在普通 sh/bash 中该 verify 可能误报成功（make 失败但 tail 成功时返回 0）。",
      "why": "verify 必须是可执行且能证伪的；当前写法在常见 shell 语义下无法可靠地让「make test 失败」导致 verify 失败，存在假通过路径。",
      "fix": "改为显式捕获并判断 make 的退出码，例如：`make test >/tmp/flowkit-make-test.log 2>&1 && rc=0 || rc=$?; tail -5 /tmp/flowkit-make-test.log; exit $rc`；或在 verify 中直接以 `make test` 作为最后一条命令。"
    },
    {
      "file": "T04 read_files / write_files 边界",
      "issue": "T04 的 read_files 仅列出 FLOW-KIT-用户指南.md 与 stop-hook.json，但 action b 要求「文中章节互链锚点（#sec-*）与目录一致」，这需要读取指南的目录与锚点结构；action c 要求「模块编号表与文件实物一一对应」需核对 stop-hook.json 的模块编号，但 action a 的禁词「17 个模块」清零与 T03 的模块计数（12 逻辑模块 + 00/99 + PreToolUse 等）之间存在口径冲突风险：T03 已将 §7 改为「12 逻辑模块（00/99 为基础设施包装）」，而 T04 的禁词清单含「17 个模块」却未排除「12 逻辑模块」表述，且未说明「17 个模块」与「17 个 flow-* 技能」的区分（T01/T07 中 dsh 插件仍写「17 个 flow-* 技能」）。",
      "why": "审查重点为 write_files 边界与 verify 可证伪性：T04 的 action 隐含对目录/锚点/模块编号表的写入修正，但 read_files 未包含对应输入（如生成的目录结构或完整章节列表），存在越界或无法完成的风险；禁词清单与 T01/T03/T07 的口径若未定义精确排除规则，T04 的 `grep -c '17 个模块'` 可能误伤或漏检。",
      "fix": "明确 T04 的 read_files 增加「FLOW-KIT-用户指南.md 的目录/锚点清单（或全文）」；将禁词定义为精确串 `17 个模块` 且注明允许出现的上下文（如「17 个 flow-* 技能」不属于禁词），或统一改用模块计数口径（12 逻辑模块）并在 T01/T07 中同步将「17 个技能」改为「12 逻辑模块 + 17 技能（两者不同维度）」以避免歧义。"
    }
  ],
  "minor": [
    {
      "file": "T06 write_files",
      "issue": "T06 的 write_files 声明了 .specs/user-guide-deck-gen/theme.py、layouts.py、build.py、README.md，但 action 0 中说明这些文件「骨架已在 DESIGN 收口前建好」，任务实际是核验与补齐；write_files 声明为新建/写入而 action 是「核验对象」，存在声明与实际操作的不一致。",
      "why": "write_files 边界要求清晰：若文件已存在且可能不需要修改，应声明为 read_files+条件写入，或明确「可能存在修改」；否则审查者无法判断该任务是否真的会写这些文件。",
      "fix": "在 T06 的 write_files 中注明「目标文件已存在，本任务核验并补齐后再入库；若已满足则无 diff 也视为完成」，或在 read_files 中与 write_files 同时列出并说明以核验为主。"
    },
    {
      "file": "T08 verify 字符串断言",
      "issue": "T08 的 verify 用 python3 检查 deck_checks.py 源码中是否含 'len(p.slides)==20'、'2026-09-03'、'l2-default='、'dsh plugin'、'逐页文本非空' 等字符串；其中 '逐页文本非空' 是中文注释/说明性字符串，断言脚本本身不包含该字符串也能实现逐页非空检查，verify 可能因源码注释缺失而误报失败，或通过字符串拼接绕过。",
      "why": "verify 应验证行为而非源码字面量；对脚本源码做子串断言既弱（无法证伪错误实现）又脆（注释/写法变化导致误报）。",
      "fix": "直接运行 deck_checks.py 并让脚本输出结构化结果（如每页字符数统计、禁词命中列表），verify 仅检查 exit code 与输出；或增加一个 mock/样例 pptx 的负向测试（含空页/禁词时脚本必须非零退出）来证伪。"
    },
    {
      "file": "T09 verify 页 14 PNG 命名",
      "issue": "T09 verify 中 `pdftoppm -png -r 60 -f $n -l $n ... pg$n` 对 n=14 输出文件为 pg14-14.png，但检查条件 `test -s /tmp/ppt-render/pg$n-0$n.png -o -s /tmp/ppt-render/pg$n-01.png` 对 n=14 会检查 pg14-014.png 或 pg14-01.png，均与实际输出 pg14-14.png 不符（除非 pdftoppm 的命名规则是 pg14-14.png），导致 verify 恒失败。",
      "why": "verify 必须可执行；页 14 的 PNG 存在性检查命名不匹配，任务完成后会误报未完成。",
      "fix": "改用通配/glob 检查或统一命名规则，例如：`test -n \"$(ls /tmp/ppt-render/pg$n-*.png 2>/dev/null | head -n1)\"`，或直接检查 `pg14-14.png`。"
    }
  ],
  "verdict": "pass",
  "summary": "任务拆解覆盖 AC 的证据不足且 T05 verify 存在假通过路径、T04 边界口径需澄清，但均为 major 级可修复问题，不构成 critical。"
}
```

L3_artifact_hash: 015a7f69fc1b1092f23685ab9d345b1e8b931770ca7883e31220f244c9357339
