## L2 盲审

- 审查阶段：阶段 1（需求） · 盲审对象：REQUIREMENT.md（134 行）+ CHANGE.md（55 行）
- 事实抽检：a) stop-hook.json modules 键含 12 个模块（claude-md/memory/git/quality/session/project/workflow/interactive_ui_check/weak_model_compliance/flow_active_integrity/archive_commit_check/independent_review），无 33/34 编号字样，flow_active_integrity 描述为 ".flow-active state integrity cross-validation (L3)"、archive_commit_check 为 "归档后未 commit 检测 (AC-3)"；b) common.sh:240-275 fk_resolve_model L2/L3 各五级链与注释"显式配置永远压过默认级"与 AC-3c/f 一致 ✓；c) gen/slides.json = 25 页、首 slide 标题 "flow-kit 技术设计"；d) dsh plugin lib 显示按 dsh.bundle 声明自动 reconcile bundles，支撑 AC-3b 插件安装描述 ✓。
- 总评：AC-1/4/7/8/9 Given/When/Then 齐备且可机器验证；AC-2/3/5/6 存在条件含糊或验证缺口。v1/v2/out 切分清晰无蔓延（v2 技术设计 deck/README/common.sh:238 注释均正确排除），NFR 覆盖性能/安全/兼容/可观测/可维护（可访问性声明"无"合理）。

### 🔴 R1 · PPT 生成器源归属事实错误：AC-5/CHANGE 引用的生成器产出的是 25 页技术设计 deck
**Severity**：🔴 Critical
**Symptom**：REQUIREMENT.md:55-58（AC-5）与 CHANGE.md:21 称沿用 `.specs/archive/2026-07-31-user-guide-ppt-sync/gen/`（slides.json + masters.py）重建"19 页 flow-kit-用户指南.pptx"；实抽 c)：该目录唯一 slides.json 含 25 页且首 slide 标题为 "flow-kit 技术设计"——源文件归属技术设计 deck，非用户指南 deck。
**Source**：仓库归档事实（gen/slides.json 内容）对照 REQUIREMENT.md AC-5 / CHANGE.md What 的引用路径。
**Consequence**：按字面执行会用技术设计源重建用户指南，页数断言（25≠19）与内容断言必失败，AC-5 无法实现，错误会传导到 DESIGN/TASK。
**Remedy**：核实真实用户指南 deck 的生成源（此归档是否实为技术设计 PPT 的同步目录），改正 AC-5/CHANGE 的路径引用，或在新 change 内自带用户指南 slides.json；AC-5 Given 中路径/页数/首页标题须与实际源一致。

### 🟡 R2 · AC-3e "33（状态完整性）/34（archive-commit）号模块"与 stop-hook.json 事实不符且锚点不明
**Severity**：🟡 Important
**Symptom**：REQUIREMENT.md:42 要求指南含"33/34 号模块"且清单与 hooks/config/stop-hook.json 一致；实抽 a)：该 json modules 键仅 12 个、无任何 33/34 编号，语义对应项是 flow_active_integrity 与 archive_commit_check（需确认"33/34"编号源自哪份模块序号清单）。
**Source**：stop-hook.json 全文（137 行）对照 AC-3e 验证方式（"每条一项 grep -q"）。
**Consequence**：验证若 grep 字面 "33/34" 会落空或误命中无关数字；grep -q 也无法证明"模块清单与 json 一致"（漏列/多列均通过），AC-3e 可机器性不成立。
**Remedy**：明确编号来源或在 AC 中改用 json 实际键名（flow_active_integrity / archive_commit_check），并把验证固化为一对 json 模块键集合与指南模块清单的差集/diff 断言。

### 🟡 R3 · AC-5 页数与 dsh 插件页要求存在条件化/悬空：边界留给 DESIGN、CHANGE 与 AC 口径冲突
**Severity**：🟡 Important
**Symptom**：REQUIREMENT.md:57 "slide 数 = 生成器产出页数（≥19，由 DESIGN 定稿）"将验收数下放给未产出的 DESIGN；CHANGE.md:21 "（如版面允许）新增 dsh 插件页"给 AC-5 的无条件要求（"含 dsh 插件或等价页面/文案"）加了未定义的前置条件。
**Source**：REQUIREMENT.md AC-5 vs CHANGE.md What/验收线（line 48 未含 dsh 插件页要求）——验收口径不一致。
**Consequence**：DESIGN 可自行把页数定到任意 ≥19 的值造成范围漂移；"版面允许"不可判真伪，DEV 可用版面理由跳过 AC-5 内容要求，AC 变为可谈判条款。
**Remedy**：在 REQUIREMENT 直接定死页数下限与来源（如按现有 deck 19 页 + 新增页上限）并删除"由 DESIGN 定稿"；统一 CHANGE 与 AC-5 的 dsh 插件表述（无条件内容要求，页面可作载体而非前提）。

### 🟢 R4 · AC-2 "（如原存在）"条件化与"不得宣称独占"缺独立断言
**Severity**：🟢 Minor
**Symptom**：REQUIREMENT.md:30 对「仅 Claude Code」加"（如原存在）"，且 Then 后半"可保留但不得宣称独占"无对应 grep 断言，验证方式（grep -c=0）只覆盖前半否定清单。
**Source**：AC-2 正文与"验证方式"行不一致。
**Consequence**：若原文并无该串则 AC 空转通过；"宣称独占"类残余表述（如"只为 Claude Code 优化"）可能漏网，与 US-1/US-2 目标不符。
**Remedy**：去掉"如原存在"；为独占表述加固定否定断言（如 grep -n '仅为 Claude Code\|只为 Claude Code' = 0），或明确由 AC-3a 的独占性检查兜底并互引。

### 🟢 R5 · AC-6/AC-1 存在非机器部分与前置含糊
**Severity**：🟢 Minor
**Symptom**：REQUIREMENT.md:64-65 AC-6 "无异常页（抽查 3 页渲染为 PNG 人工/审查可见）"把人工目视判据写进机器验收；AC-1 Given 只写"根目录指南文件"，具体文件名在验证命令才出现（:21-24）。
**Source**：验收准则"必须可验证"声明（:17）与具体 AC 措辞。
**Consequence**：AC-6 的"无异常页"无法由脚本终结判定（因人而异）；AC-1 前置对象未命名，若文件缺名则 Given 无落点。
**Remedy**：AC-6 将人工抽检明确降级为"辅助抽查、不作 gate"或给出可判定的异常判据（空白页像素比/文本缺失）；AC-1 Given 直接写文件名 FLOW-KIT-用户指南.md。

**Verdict**: fail---

## L2 重审

- 审查阶段：阶段 1（需求）复审 · 对象：REQUIREMENT.md + CHANGE.md（全读）；交叉核对 DESIGN.md / TASK.md 与工作区实物（只读），未引用任何主 agent 自评。
- 实物抽检：a) `.specs/archive/2026-07-31-user-guide-ppt-sync/gen/slides.json` = 25 张、首 slide（cover）标题「flow-kit 技术设计」→ 与 AC-5「25 页技术设计 deck」标注吻合；根 `flow-kit-用户指南.pptx` = 19 页 → 与 AC-5 Given「现有 19 页」吻合（另见工作区有 `.bak` 18 页残留，需确认 git 跟踪状态，AC-7 白名单未含 `.bak`）；b) `flow-kit-bundle/hooks/config/stop-hook.json` modules = 12 键，与 AC-3e 所列键名/顺序全同；`hooks/stop/` 存在 33-flow-active-integrity.sh、34-archive-commit-check.sh、00-gate.sh、01-transcript-parse.sh、99-report.sh → 「33/34 为脚本编号」「00/01 与 99 为基础设施」表述有实物支撑；c) 现指南两副本实际含「17 个模块」×2、「三级优先级链」×2、「20260713」×1，与 AC-2 禁词表字面一致。

### 修复核实（a）
- R1 ✅ 落地且自洽：REQUIREMENT.md:55-58（AC-5）/132 与 CHANGE.md:21/48 均指向本 change 新建 `.specs/user-guide-deck-gen/`（slides.json 20 页 + build.py），并明示归档 gen 为 25 页技术设计 deck、仅布局参考；DESIGN.md:27/46/66/86 与 TASK.md（T06/T07/T08）均为同一新生成器 19→20 页口径，无残留引用旧源。
- R2 ✅ 大体落地：AC-3e（REQUIREMENT.md:42）改为 config 键列 + 差集断言（:44），与 12 键实物全同；「33/34」由「模块号」改为「脚本编号」表述；残留仅为表述层（见 R6/R7）。
- R3 ✅ 落地：AC-5（:57）「slide 数 = 20」定死 + 验证页数断言（:58）；dsh 专页无条件（:57「专页（无条件内容要求）」）；CHANGE.md:21「无条件新增 1 页」、:48「20 页」口径一致；「由 DESIGN 定稿」「版面允许」均已清除。

### AC 可机器验证性（b）
- 9 条 AC 均具 Given/When/Then 结构；AC-1/2/4/5/7/8/9 验证命令可直接脚本化；AC-3 a-d/f 逐条 grep -q、e 集合差集断言（固化于 TEST.md，见 R7）；AC-6「无异常页」人工抽查判据维持 Minor（MINOR-DEFERRED M2 已登记，不阻塞）。
- 上一轮 R4 已吸收（禁词表含「仅为 Claude Code」、验证加查「只为 Claude Code」，「如原存在」已删）；R5 按 M2 登记维持。本轮无新增 Critical/Important，仅以下 Minor。

### 🟢 R6 · AC-3e「上述两个模块」指代悬空，33/34 对应模块名未点名
**Severity**：🟢 Minor
**Symptom**：REQUIREMENT.md:42「并注明 … 33/34 号为上述两个模块的脚本编号」——该句前文只列 12 个模块键名，无先行词表明「上述两个」指哪两个模块。
**Source**：REQUIREMENT.md AC-3e 正文；对照实物 hooks/stop/33-flow-active-integrity.sh、34-archive-commit-check.sh 及 TASK.md T03（已显式命名「33-flow-active-integrity（…ADR-024）、34-archive-commit-check（…）」）。
**Consequence**：执行方须自行对照 hooks 目录推断映射，指南注释行易错标归属；TEST 若按字面 grep「33/34」可能误命中无关数字。
**Remedy**：AC-3e 改为点名：「33 号 = flow_active_integrity、34 号 = archive_commit_check（对应 hooks/stop/33-flow-active-integrity.sh、34-archive-commit-check.sh）」，与 TASK T03 表述对齐。

### 🟢 R7 · AC-3 验证方式对 e 的 Then 子句只锚定集合差集，其余子句在 REQUIREMENT 层无断言落点
**Severity**：🟢 Minor
**Symptom**：REQUIREMENT.md:44 对 e 只固化「modules 键集合 ↔ config 键列集合差集为空」，而 :42 的 config 键列、00/01/99 基础设施注释、33/34 脚本编号注释、pre-commit 门禁说明等 Then 子句无对应 grep/断言（仅 TASK.md T01/T03 verify 以 grep 兜底）。
**Source**：REQUIREMENT.md AC-3 验证方式 vs AC-3e 正文；TASK.md:40/83 verify 行。
**Consequence**：若尚未产出的 TEST.md 漏写这些断言，AC-3e 将只验证键集合等价而放行缺失注释的指南——R2 所批「部分 Then 子句不可机器验证」的残留形态。
**Remedy**：验证方式为 e 补子句断言清单（如 grep -q '00-gate\|00 号'、'99-report\|99 号'、'33-flow-active-integrity\|33 号'、'34-archive-commit-check\|34 号'、'pre-commit'），或明示由 T01/T03 verify 承接；TEST.md 落地时逐条对账。

### 🟢 R8 · AC-1 来源行断言未限定「文件头 5 行」，存在假通过面
**Severity**：🟢 Minor
**Symptom**：REQUIREMENT.md:24 验证用整文件 `grep -n 'github.com/hellrabbit/flow-kit/tree/develop'`，而 :22 When 限定「打开文件头 5 行」、:23 Then 限定「来源行」。
**Source**：REQUIREMENT.md AC-1 三段与验证方式的范围不一致。
**Consequence**：来源 URL 若只残留在正文而非文件头，AC-1 仍判通过，头 5 行声明未真正被校验。
**Remedy**：验证改为 `head -5 FLOW-KIT-用户指南.md | grep -n 'github.com/hellrabbit/flow-kit/tree/develop'`（与版本行断言同域）。

### 🟢 R9 · CHANGE 现状描述与指南字面/目标口径漂移
**Severity**：🟢 Minor
**Symptom**：CHANGE.md:13 引述指南仍写「17 模块 Stop Hook」「仅 Claude Code」，实物为「17 个模块」（无「仅 Claude Code」表述，见 :41「为 Claude Code（也支持 …）」）；:53 风险段「PPT 19 页」未标注为更新前口径，与 AC-5 目标 20 页、CHANGE.md:48「20 页」并读易生歧义。
**Source**：CHANGE.md Why/风险 vs FLOW-KIT-用户指南.md:3/41/49/842 现状及 AC-5/验收线。
**Consequence**：引号串若被 TEST 直接复制为禁词清单会产生空断言或误伤；19/20 页口径读者需自行推断时态。
**Remedy**：CHANGE.md:13 引号改为与实文一致（「17 个模块」…），或注明为意译；:53 写「PPT 现 19 页（重建后 20 页）」。

**Verdict**: pass


---


---


---

## L3 重审（deepseek-v4-flash-0731 外部模型 · 2026-09-03 22:12）

> 自动生成于 2026-09-03 22:12。由 l3-review.sh 写入。

### 审查结论

```json
{
  "critical": [],
  "major": [
    {
      "file": "AC-3 f) / .specs/CONTEXT.md",
      "issue": "AC-3 f) 验证方式要求 grep 决策条目 `L2/L3 模型解析链加入站点级默认 tier` 存在于 .specs/CONTEXT.md，但本工件未提供该 CONTEXT.md 的具体内容或该决策条目的定义；同时 AC-3 g) 要求追加块含至少 3 条术语但列出 4 个候选项，未明确去重计数规则。",
      "why": "验收准则的可验证性依赖外部文件的内容断言，而工件本身未展示这些断言对应的实际文本是否存在、格式如何；若 CONTEXT.md 中决策条目表述与 grep 模式不一致，或术语计数按出现行数而非术语条目数计算，会导致 AC 在实现时产生歧义或验证口径分歧。",
      "fix": "在 REQUIREMENT 中固化 CONTEXT.md 决策条目的精确文本（或明确该决策条目由本 change 新增并给出标准表述），并明确 g) 的计数规则：按术语表条目（如 `- **dsh-flow-kit**` 行）统计，且至少包含 3 个 distinct 术语。"
    },
    {
      "file": "AC-7 / 范围切分 v2",
      "issue": "AC-7 要求 `git status --porcelain` 每一行路径都命中白名单，但 AC-9 归档会把活动目录移动到 `.specs/archive/2026-09-03-user-guide-sync-2026-09/`，该归档路径不在 AC-7 白名单前缀中；同时 AC-7 又说“白名单仅约束阶段 5 提交前状态”，与“When 运行仓库质量门禁并核对 git 改动集 / Then 每一行路径都命中白名单”这一无条件表述存在时序歧义。",
      "why": "验收准则的 Given/When/Then 必须无歧义；若按字面执行，AC-9 归档后 `git status --porcelain` 会出现不在白名单中的新路径（除非归档发生在阶段 5 之前，但 AC-9 是阶段 7），导致 AC-7 与 AC-9 互相矛盾，无法同时通过。",
      "fix": "将 AC-7 的 When 明确为“阶段 5 提交前”，或把白名单扩展为包含 `.specs/archive/2026-09-03-user-guide-sync-2026-09/`；并在验证方式中注明 AC-9 完成后单独执行“git status 为空”检查，与 AC-7 的路径白名单检查分离。"
    },
    {
      "file": "AC-6 / 验证方式",
      "issue": "AC-6 要求“抽查页固定 = 首页 / 模型配置（五级链）页 / dsh 插件页”并对页 1/14/20 做 pdftoppm，但 AC-5 中“模型配置 slide（页 14）”“dsh 插件专页（页 20）”的页码是对生成器输出的固定假设，AC-6 的 PDF 页数断言也只检查了总页数 = 20，未将 PDF 页 14/20 与内容语义绑定。",
      "why": "若 slides.json 或 build.py 在实现中插入/删除页，页码会漂移，AC-5 的固定页码断言和 AC-6 的抽查将可能通过但实际抽查的不是目标页，或目标页内容存在但页码断言失败——验收准则的可验证性依赖生成器的内部实现细节，未提供对“模型配置页/DSH 插件页”的独立定位机制。",
      "fix": "在 deck_checks.py 中按内容特征（如页文本含 `l2-default=`、含 `dsh-flow-kit` 插件安装）定位目标页并断言其存在，再由 AC-6 对定位到的页做 PDF 抽查；或明确说明“页 14/20 由生成器固定模板保证，生成器本身是 AC 产物的一部分”，将页码约束纳入生成器测试。"
    }
  ],
  "minor": [
    {
      "file": "AC-1 / 验证方式",
      "issue": "AC-1 的日期正则 `grep -oE '20[0-9]{6}'` 会匹配 `2026-09-03` 中的 `20260903`（去掉连字符后）？实际不会，因为 `2026-09-03` 中间有连字符，`20[0-9]{6}` 要求连续 8 位数字，`2026-09-03` 中 `2026` 后是 `-`，不匹配；但该命令输出的是独立的 8 位连续数字，若文件中出现 `20260903`（无连字符）会被排除，而 AC-2 的禁词表不含 `20260903`。",
      "why": "AC-1 只限制文件头 5 行，而 AC-2 的禁词 `20260713` 针对全文；AC-1 的“无其他 8 位日期”与 AC-2 的禁词清单在时间格式上不一致——如果正文出现合法的 `20260903` 无连字符写法，AC-2 能通过但 AC-3 等内容可能引用；更重要的是验证命令中 `grep -vx '20260903'` 实际排除了所有等于 20260903 的行，但 `head -5` 输出中一行可能同时包含其他日期和 `20260903`，此时该行被排除导致漏检。",
      "fix": "将无其他 8 位日期改为对提取结果逐项检查是否等于 20260903，而非按行排除；或明确日期格式统一为 `2026-09-03`，禁词表增加 `20260903` 无连字符变体。"
    },
    {
      "file": "AC-3 e) / stop-hook.json 模块表",
      "issue": "AC-3 e) 要求指南模块表与 `hooks/config/stop-hook.json` 的 modules 键集合双向相等，但未说明若 json 中 modules 键顺序变化、或指南表中除 config 键外还有备注列（如脚本路径/编号）时如何解析；且“00/01 与 99 为基础设施脚本”中的 01 未在 12 键集合中列出，可能造成混淆。",
      "why": "验证方式的 python 断言只说了“取 config 键列值集合”和“双向相等”，但未定义表格解析规则（如 markdown 表格分隔行、表头定位、单元格内多个键的切分方式），不同实现可能得到不同集合，导致 AC 结果不稳定。",
      "fix": "在验证方式中给出 python 断言的伪代码或明确规则：按 `|` 分割行、定位表头 `config 键` 所在列、逐行取该列并 strip，非空值加入集合；并单独注明 00/01/99 不参与 12 键集合比较，避免编号与键名混淆。"
    },
    {
      "file": "AC-8 / 独立审查文件命名",
      "issue": "AC-8 要求 N ∈ {1,2,3,5,6,7}，但阶段 1 的产物中 REQUIREMENT 本身也要被审查；AC-8 的“每启用阶段（1/2/3/5/6/7）产物就绪后执行独立审查”与 AC-9 归档文件清单中 `INDEPENDENT-REVIEW-{1,2,3,5,6,7}.md` 一致，但未说明阶段 1 的 INDEPENDENT-REVIEW-1.md 是针对本 REQUIREMENT 的审查还是针对阶段 1 全部产物（CHANGE/REQUIREMENT/DESIGN/TASK 等）的审查。",
      "why": "“产物就绪”中的“产物”范围未定义，若针对每个阶段所有产物，则独立审查文件应覆盖多个文档；若仅针对阶段 1 的 REQUIREMENT，则命名与阶段号对应关系不清晰，执行者可能漏审或重复审。",
      "fix": "在 AC-8 中明确每个 INDEPENDENT-REVIEW-N.md 对应的审查对象范围（例如 N=1 审 CHANGE/REQUIREMENT/DESIGN，N=2 审 TASK/TEST 等），或改为按产物文件命名。"
    },
    {
      "file": "非功能性需求 / 安全验证",
      "issue": "NFR 安全要求“指南与 PPT 不得出现真实凭证/API key/内部绝对用户路径”，但“NFR 验证口径”中安全自动断言只检查 `sk-sp-` 前缀与 `/home/hellrabbit` 绝对路径，未覆盖其他凭证格式（如 `FLOW_KIT_L3_AUTH_TOKEN` 的实际值、通用 token 模式）。",
      "why": "安全 NFR 与自动断言覆盖范围不一致，存在绕过断言的凭证泄漏风险，例如其他 API key 前缀或用户路径变体（如 `/Users/...`、`C:\\Users\\...`）。",
      "fix": "扩大自动断言的正则范围（如 `sk-[A-Za-z0-9]{20,}`、`/home/[a-z]+/`、常见云厂商 key 前缀），或明确“自动断言为最低门槛，完整审查靠 L2/L3 人工检查”并将该说明写入 REVIEW 检查项。"
    },
    {
      "file": "范围切分 v2 / 依赖假设",
      "issue": "v2 列表包含“上游 minor：`common.sh:238`「3-tier」注释头修正（MINOR-DEFERRED D1 同类）”，但 AC-7 白名单和 out 范围声明“任何运行时行为改动（flow-kit-bundle/hooks、dsh-flow-kit/lib、skills、prompts 一律不动）”，未明确注释修正是否属于运行时行为改动；若 v2 未来执行，可能突破 out 范围。",
      "why": "范围切分中 v2 与 out 存在潜在冲突：注释头修正虽不改运行逻辑，但会触碰 hooks 相关文件，而 out 声明“一律不动”可能被解释为禁止任何文件修改，导致 v2 无法执行或范围蔓延争议。",
      "fix": "在 out 范围中补充“仅允许注释/文档性修改需单独变更评审”，或把 v2 的 common.sh 注释修正明确为“不触碰运行时逻辑的注释修复，走独立小 change”。"
    }
  ],
  "verdict": "pass",
  "summary": "AC 整体可验证、范围切分清晰，无阻塞性缺陷；主要问题集中在 AC-7 与 AC-9 的时序矛盾、AC-3 对 CONTEXT.md 内容的外部依赖未固化、以及 AC-5/6 固定页码与内容语义绑定不足，建议在实现前细化验证口径。"
}
```

L3_artifact_hash: d4c1ddfe3bbb3078a8bf0ceccfc65854809f653a195cac2d3dd5c62bd05d40d2
