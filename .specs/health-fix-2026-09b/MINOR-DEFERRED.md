# MINOR-DEFERRED · health-fix-2026-09b

- **Change ID**: health-fix-2026-09b
- **阶段**: 1~2（REQUIREMENT + DESIGN；N11 订正：初版仅写「阶段 1」）
- **建档日期**: 2026-09-22
- **依据**: L2 固化指令的 **Severity Gating 协议** —— 🟢 Minor **不入 fix loop**，记录于此供后续 change 取用
- **来源**: `@.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-1.md`（L2 第 1~6 轮，含并行实例）

## 未处置项（deferred）

| Task | Finding ID | Date | 发现 | 为何不本次修 | 后续动作 |
|---|---|---|---|---|---|
| 阶段 1 · 需求 | R7（第 5 轮）· R6-5（第 6 轮） | 2026-09-22 | AC-3④ `git push --tags` **无可拦截 fixture**（仓内唯一 tag `v0.3.0-gate-integrity` 零泄漏）⇒ 该形态无法在仓内证明被拦 | **R18 订正：该理由不成立** —— 实测在**沙箱 `HOME` + 临时 bare remote** 中 `git tag probe main` 即可造 fixture，无需在**本仓**写入泄漏对象 | v1 仍对 ④ 只做形态覆盖声明，但**理由改为**：④ 的 fixture 需在隔离仓构造，属 5-test 阶段工作量而非 v1 需求；旁注「四形态全部调用 pre-push」(stdin ref 数 1/1/2/1) 已实测成立 |
| 阶段 1 · 需求 | C7（第 3 轮） | 2026-09-22 | AC-3 的 Given 要求"**在干净 clone 上拦截仍生效**"的 verify，但验证方式段未提供（载体转 DESIGN 后 AC 内无锚点） | `pre-push` 载体本身待 DESIGN 定义，阶段 1 无法给出 verify | **L3 major2 已把该承诺移出 v1 的 AC-3 Given**（改为边界声明）⇒ 本行不再需要「回填」动作；「干净 clone 复现」正式列为 **v2**，依赖 DESIGN 定 `pre-push` 载体|
| 阶段 1 · 需求 | D5（第 4 轮）残留 | 2026-09-22 | AC-2 的"截断为 0 字节"行为**无法在仓内端到端复现**（需在真实 `$HOME` 跑 `install.sh`，会改真实 `settings.json`） | 超出只读/安全边界；L2 已在 `/tmp` 沙箱 HOME 复现（122B→0B） | 已在预检表补该实测行；端到端 UAT 留到 5-test 阶段（沙箱 HOME） |
| 阶段 1 · 需求 | D6（第 4 轮）残留 | 2026-09-22 | AC-8 与 `make lint`（error 级）**都检不出** bash 3.2 不兼容（`declare -A`/`mapfile`/GNU `timeout`） | 已在 NFR「兼容性」补可机器判据（变更全集枚举） | 判据已落 NFR；待 4-dev 落地后由 AC-8 覆盖 |
| 阶段 2 · 设计 | G1（第 7 轮） | 2026-09-23 | 历史注释内残留悬空行号（`DESIGN.md` 的 `:126/127/242/244/246`） | 那些数字是**漂移现象的实测记录**（`D10` 1 小时内 `:140`→`:168`），也是新判据「行号必须与内容锚点成对」的**原始证据** ⇒ 删数字即删证据；且每处均带「初版…／订正」标签，已与在用态引用区分 | **阶段 7 起**：若再被误读为在用态引用，则改为「初版此处曾引行号（已废弃）」并删除具体数字 |
| 阶段 2 · 设计 | G2（第 7 轮） | 2026-09-23 | 审查档膨胀（`INDEPENDENT-REVIEW-2.md` >250 KB）的本 change 内缓解完全外推到阶段 7 | **核实后影响远低于 DESIGN R7 的表述**：51200 B 处仅**告警不截断**，且 `_l3_extra_deliverables`（`l3-prompt.sh:294`）**排除** `INDEPENDENT-REVIEW-*.md` ⇒ 该档**不进入** L3 提示词（实测 phase 2 提示词 60,138 B，含完整 DESIGN.md）。真实影响仅**人读成本 + 后续阶段**，本 change 内无低风险缓解手段（拆分需用户确认） | 阶段 7 归档时拆分；**DESIGN R7 措辞已按实测定正**（原「51200 B 阈值必被触发」高估） |
| 阶段 2 · 设计 | **C5**（L3 #3 minor① · **第 3 次点名**：L2-G1 + L3#2 + L3#3） | 2026-09-23 | `DESIGN.md` 内「初版…／第 N 轮修正」的**过程性修订记录**与最终决策混排，决策被自证历史淹没（D3 代码块内的 `R2（第 5 轮）`/`R4 订正`/`第 6 轮补` 等注释最典型） | **不在阶段 2 内重构**：这些注释是「行号漂移 / 悬空自指 / 判据未实跑」三类失效的**原始证据**（新增判据「行号必须与内容锚点成对」即由其导出），删除会同时删掉证据；且重构 447→463 行的多行表格有引入**新**悬空引用的风险（本 change 已为此付出 3 轮代价） | **触发条件（明确）**：阶段 3 TASK 定稿后、4-dev 开工前，把 DESIGN 的修订史**整体移入**「附：修订史」小节（决策先行、历史靠后），逐条保留证据但移出决策路径 —— 列为 TASK 的一条 task，verify = 决策行内 `grep -cE '（第 [0-9]+ 轮|初版）'` ⇒ **0** |


## 已就地修复（不 deferred，仅留档说明为何出现在本文件讨论中）

| Task | Finding ID | Date | 发现 | 处置 |
|---|---|---|---|---|

| Task | Finding ID | Date | 发现 | 处置 |
|---|---|---|---|---|
| 阶段 1 · 需求 | C5（第 3 轮） | 2026-09-22 | AC-4 未声明 v1 覆盖边界（3/14），`check-gate-sync.sh:157` 的「✅ 所有校验对一致」易被读成 14 对全绿 | ✅ 就地修复：AC-4 新增「覆盖边界声明」+ 要求门禁打印覆盖度 |
| 阶段 1 · 需求 | C6（第 3 轮） | 2026-09-22 | 「已知未闭环项」§7 称 `CONTEXT.md` 的「`grep eval` 应成为常设检查项」已在 AC-1 取得追溯 —— **该追溯不成立**（AC-1 是更窄的精确 pattern，且非门禁接线） | ✅ 就地修复：§7 如实改写 + 登记 **TD-040**（区分「AC 级验证」vs「常设门禁项入册」） |
| 阶段 1 · 需求 | R10 残余（第 2 轮） | 2026-09-22 | NFR「兼容性」的判据文件清单**留占位符** `<本 change 新增/修改的脚本>`，既未修也未登记 | ✅ 就地修复：改为**变更全集枚举**（`git diff --name-only` + `ls-files -o`，遵循 L-107 口径） |
| 阶段 1 · 需求 | R11（第 1 轮） | 2026-09-22 | AC-3「四种 push 形态」与列举不符 | ✅ 已就地修复（第 2 轮） |
| 阶段 1 · 需求 | N5（第 2 轮） | 2026-09-22 | 3 处数字/行号不实 | ✅ 已就地修复（第 2 轮） |
| 阶段 1 · 需求 | D5（第 4 轮） | 2026-09-22 | 预检表路径截断 + 「见实测表」断链 | ✅ 就地修复：路径补全 + 补入 AC-2 截断实测行 |

---

## 阶段 3 · 新增未处置项（L2 第 1 轮 + 主 agent 复核）

| Task | Finding ID | Date | 发现 | 为何不本次修 | 后续动作 |
|---|---|---|---|---|---|
| 阶段 3 · 任务 | R2（L2 第 1 轮 🟢） | 2026-09-23 | T29 收口 task 的 verify 段同时承载 `make check` 全绿 + `bats ≥973` + 三道副本一致性 + 变更集非空守卫，单 task verify 负载显著高于其余 28 条，失败时定位成本高（`TASK.md` T29，`depends_on` 共 8 条） | 该粒度由 AC-8「无退化」的**整体语义**决定，拆分会割裂语义；无数据完整性 / 安全 / AC 未实现风险，verify 均可机器执行 | 下一 change 或阶段 7：可拆为 T29a（`make check` 全绿 + 三道副本一致性）与 T29b（`bats ≥973` + 变更集非空守卫）两条 serial 子 task。当前不拆不影响通过性 |
| 阶段 3 · 任务 | R3（主 agent 复核 R1 时自查发现 🟢） | 2026-09-23 | 自排除边界按「逐条精确路径」枚举审查档，而审查档按**阶段**递增（`-1/-2/-3`，后续 5/6/7 还会新增）。实测非占位符 PAT 命中：`INDEPENDENT-REVIEW-1.md` **22** 行、`-2.md` **18** 行、`-3.md` **0** 行 ⇒ 若阶段 5/6/7 的审查档出现命中而未被追加进排除表，AC-6 门禁会在收口时以「清单外命中 ≠ 0」变红（ADR-027②「长期红门禁」形态） | 今日 `-3.md` 实测命中 **0**，无现网影响；改成 `INDEPENDENT-REVIEW-*` 通配违反 D8 行「自排除边界（强制）」③「只允许逐条精确路径（强制）」，且 D10′② 实测通配会吞掉 31 处 `<acct>` 字样（含 10+ 处真实账号路径）且永久无界 | 规则已写死进 `TASK.md` 的 T17 action：**新增审查档只有在实际出现非占位符命中时才需要追加，且追加必须是显式动作并登记于响应段**；排除表当前已逐条枚举 `-1/-2/-3`。触发条件 = 任一后续审查档首次出现非占位符命中 |

## 阶段 4 · 过程偏差（T01 提交绕过门禁 · 已复核并订正）

| 项 | 等级 | 事实 | 处置 |
| --- | --- | --- | --- |
| T01 提交用 `git commit --no-verify` | 🟡 | 子 agent 报告 pre-commit（`flow-kit-bundle/hooks/pre-commit/pre-commit.sh` 跑 `make test`）命中「既有失败」`T06fix: L2 R1 - line cap truncation respects UTF-8 boundary`（`test/test_l3_pipeline_fix.bats:592`），并称 `DESIGN.md:329` / `INDEPENDENT-REVIEW-2` 记录了「纯文档提交的标准路径」 | **已复核：失败不可复现**（单跑 41 ok / 0 not ok；全量 `make test` 973 ok / 0 not ok / rc=0；测试面 0 命中本 change 目录）。`DESIGN.md:329` 原文是**风险描述**而非授权 ⇒ 该绕过**不被采纳为先例**：后续 task 的提交若遇门禁失败必须捕获真实输出并 **BLOCKED 上报**，禁止 `--no-verify`。订正补记写入 `T01-SUMMARY.md` 的「提交路径与 sha 自指说明」；教训登记为 **L-126** |
| `T01-SUMMARY.md` 的 commit sha 与 amend 后不一致（`3da5fa6` → `a674c56`） | 🟢 | 提交内容不可能写下自己的最终 sha（amend 必改 sha） | 权威源改为 `.flow-active.goal.task_progress[].commit_sha`；SUMMARY 内补记两个 sha 的关系（本节与 L-126 ③） |

## 阶段 4 · T02 六维自查 🟢 登记（2026-09-23）

| Task | Finding ID | Date | 发现 | 为何不本次修 | 后续动作 |
|---|---|---|---|---|---|
| 阶段 4 · 任务 | G-T02-1（六维自查 🟢） | 2026-09-23 | T02 的 `<action>` 口径（「在**任何修改之前**执行 `git rev-parse HEAD` 并写入 `.change-base`」）与 **AC-8 / NFR 兼容性判据的口径**（锚点必须是**变更前基线**；`REQUIREMENT.md:445` 的 `BASE8` 明令「**必须与 A 案同锚点**，否则纯删除态会「SKIP 当绿灯」、增量提交后会假红且**归因相反**」）**不一致** —— 逐字执行 `<action>` 会落到 `HEAD` 锚点，而该锚点在后续任务提交 `.sh` 变更后使 `git diff HEAD -- '*.sh'` 恒空，正是 `<action>` 末句自己禁止的「判据静默空转」 | 本任务已按主 agent 裁定取变更前基线 `534e3e842fc900045f39492badc66eabe3ffd4c4` 并在 `T02-SUMMARY.md` 的「对任务 XML `<action>` 的偏离」段显式披露；**不改 TASK.md 的 `<action>` 正文**（属阶段 3 工件正文，4-dev 期内越界改会与 R3.2 精神冲突） | 阶段 6-review / 阶段 7：若 TASK.md 对后续读者仍有误导风险，把 T02 的 `<action>` 改为「写入**本 change 的变更前基线** SHA（由主 agent 裁定 / 查 `git log` 确认），**禁止**写裸 `git rev-parse HEAD`」；并在 flow-task 模板中固化「锚点 task 必须写明取变更前基线而非 HEAD」 |
| 阶段 4 · 任务 | G-T02-2（六维自查 🟢） | 2026-09-23 | 「锚点判别力」的**证据边界**：`-- '*.sh'` 受检面在当前时点对两锚点取值**相同**（`ADDED(sh)=31` vs `31`），因本 change 迄今**已提交 0 个 `.sh` 变更**（基线可见而 `HEAD` 不可见的 5 个文件全为 `.md`）。分化效应要到 T03+ 提交 `.sh` 变更后才出现 | 属**测量时点**的客观事实而非缺陷；两锚点在**全部扩展名**面上已实测分化（变更文件数 9 vs 4），机制已由 T01 两次提交构成的既有实例证明（`F1b`） | 阶段 5-test / 阶段 6-review：以「`git diff <基线> -- '*.sh'` 的 ADDED 行数 ⊇ 已提交的 `.sh` 变更」为复核口径重跑，确认分化确实发生 —— 避免把「当前未分化」误读为「取 `HEAD` 亦可」 |

## 阶段 4 · T03 六维自查 🟡 登记（2026-09-23）

| Task | Finding ID | Date | 发现 | 为何不本次修 | 后续动作 |
|---|---|---|---|---|---|
| 阶段 4 · 任务 | **G-T03-1**（六维自查 🟡 · 已就地缓解） | 2026-09-23 | **ADR-022 的 supersede 语义落在文末小节，与 `ADR-014`~`021` 的「头部字段」约定不同形** —— 后者在标题后 3~6 行内以 `**Status**:` + `**Superseded by**: 无`（或 `[ADR-012](…)（<日期> · <理由>）`）承载；而 ADR-022 头部**原本没有**这两行字段（实测追加前 `grep -n 'Status'` = 0），故本次以文末 `## Superseded-by（部分 · 2026-09-23 · change \`health-fix-2026-09b\`）`（`:58`）承载 ⇒ **同一仓内的 ADR 头部形态存在两种约定**，按头部快速扫描的读者可能在 ADR-022 上**漏读该 supersede** | **任务 XML 硬约束「只追加，不改写/不重排原有正文」** —— 回头在头部补 `**Status**` / `**Superseded by**` 字段行即改写头部（且会移位原文行号）。「部分 supersede」本身已由追加段首 + `- **Superseded by**: **部分** —— …` 字段行承载，语义未丢 | 阶段 6-review / 阶段 7：① 若判定"ADR 头部形态不统一"值得治本，开一条独立 task 统一 `022`~`028` 的头部字段形态（**含行号位移的复核**）；② 或把「ADR 头部字段为强制形态」写入 ADR 模板/产出规范。**本任务不越界执行**（R7.1 不扩大范围） |
| 阶段 4 · 任务 | **G-T03-2**（六维自查 🟡 · 已就地缓解） | 2026-09-23 | **追加段引用的行号会随追加（及本 change 后续任何对 ADR-022 的追加）漂移** —— 追加段引用 `022-git-hook-deployment.md:17`（`## Decision` 的 symlink 句）与 `:25`（`### 优点` 的「最小侵入」句），二者**当前**已实测成对（`awk 'NR==N'` 逐行打印核对）；但 `:25` 会因未来在本段**之前**插入内容而移位，而 `:17` 亦然 | 任务形态**强制要求**「行号必须与内容锚点成对」，且**禁止**写未核实的行号；完全不写行号则无法精确定位被 supersede 的原句（正是本 ADR 的核心声明对象）。**已就地缓解**：两处引用**一律带小节名**（`## Decision` / `### 优点`），且段内显式标注「行号会随追加漂移」；小节名不受行号位移影响 | 阶段 6-review / 阶段 7：复核本段引用的 `:17`/`:25` 是否仍成对（对照口径 = `awk 'NR==17{…} NR==25{…}'`）；若已漂移，按「小节名 + 文件路径」修正或删除数字。**注**：本仓既有同类未处置项见上表 `阶段 2 · 设计 · G1`（`DESIGN.md` 的历史行号）—— 二者同族：**行号在活文档中必然漂移**，唯一可靠锚点是小节名/内容 |

## 阶段 4 · T04 六维自查 🟡 登记（2026-09-23）

> 背景：T04 = TD-043 的**独立验证 + 入库收口**。双态 verify **成立** ⇒ 按任务 XML 硬约束「**不改动实现、只提交**」，
> 故本次两条 🟡 一律**登记不修**（R7.1 不扩大范围）。两条均属**新引入的标记文案**（本次修复的产物本身），
> **不放宽任何判据**（无判据可被其绕过），但会让 L3 审查者对「提示词信封里到底有什么证据」产生误读 ——
> 与 TD-043 的原始失效（审查者据无关/残缺证据裁决）**同族**，故如实登记。

| Task | Finding ID | Date | 发现 | 为何不本次修 | 后续动作 |
|---|---|---|---|---|---|
| 阶段 4 · 任务 | **G-T04-1**（六维自查 🟡） | 2026-09-23 | **「未纳入」标记罗列的是「被工件的全部引用清单」，而非「实际被跳过的清单」** —— `l3-prompt.sh:364` 内插 `"${_adr_ids}"`（按频次排序的**全量** id 列表），故提示词里的标记原文为「以下被工件引用的 ADR **未纳入** …：ADR-022 / ADR-028 / ADR-027 / ADR-005 / ADR-008 / ADR-001」，而其中 **022/028/027/005 四件在上文已带完整正文标记**（`--- .specs/adr/0NN-… ---`，见 T04-SUMMARY「双态对照」段），**真正未纳入的只有 008 与 001 两件** ⇒ 标记把「已纳入」的 4 件一并声明为「未纳入」。L3 是盲审者，读该标记会以为本 change 的决策依据 ADR-028 **不在**提示词中 | **任务 XML 硬约束**：「若双态 verify 成立 ⇒ **不要改动实现**，只提交它（连同 SUMMARY）」。且该缺陷是**措辞口径过宽**，不改变任何一个 ADR 是否进来（判据零放宽）；修它属 4-dev 期内对已裁决实现的二次改写 | 阶段 5-test / 阶段 6-review：把内插值从 `${_adr_ids}` 改为**实际跳过的剩余 id**（循环里累加一个 `_adr_skip` 列表，或在 `break` 处用 `$(printf '%s' "$_adr_ids" | tail -n +$((_adr_n+1)))`）；或退一步把文案改为「以下为**工件引用的 ADR 全清单**（已纳入者见上文同名正文标记）」。**一行改动**，无判据影响 |
| 阶段 4 · 任务 | **G-T04-2**（六维自查 🟡） | 2026-09-23 | **标记声称「已按整行**截断**」，实测为半行截断（仅保证 UTF-8 码点安全、不保证行边界）** —— `l3-prompt.sh:367` 用 `_l3_utf8_head_bytes 5000`（`:27` 的定义只做 `head -c` + `_l3_utf8_head_stream` 的 UTF-8 边界回退），**未**像补充产物路径那样再补 `sed '$d'`（对照 `:304-309`：那里「整行截断」成立**正是因为** `:309` 的 `_head=$(printf '%s' "$_head" \| sed '$d')` 无条件丢掉末行）。实测：`.specs/adr/022-git-hook-deployment.md` 第 5000 字节 = `0xE9`（非 `\n`）、`.specs/adr/028-gate-baseline-allowlist.md` 第 5000 字节 = `0x65`（`e`，非 `\n`）⇒ 两件摘录均在**词中/句中**断开 | 同上（任务 XML 硬约束：不改实现）。**且非本次引入的回归**：原实现的 `_l3_utf8_head_bytes 2000` 同样无 `sed '$d'`，本次只是**新写下的文案**承诺了原实现没做的事。影响面被 `:369` 同句的「此为提示词预算标记，不构成工件缺陷」部分抵消 | 阶段 5-test / 阶段 6-review：二选一 —— ① 在 `:367` 之后补一行 `sed '$d'` 断行（与 `:309` 同形，代价 = 最多少 1 行正文）；② 把 `:369` 文案的「已按**整行**截断」改为「已按**字节**截断（UTF-8 边界安全，末行可能不完整）」。**文案与行为必须二者其一，不得继续不一致**（该文件 `:306` 记录的既有 critical 正是「截断处被读成工件缺陷」） |


## 阶段 4 · T05 六维自查 & 主 agent 裁定登记（2026-09-23）

### 🟢 六维自查 Minor 备注（R4 偶然复杂轻微，已接受，不改）

本任务 T05 无 🔴 必修项、也无需要登记的 🟡 Major 项。下表为本任务的 6 维快查全程（✅ = 通过）：

| 维度 | 判定 | 依据 |
|---|---|---|
| R1 认知过载 | ✅ | 新增路径解析段为单个 `case`（3 分支）+ 一个 `[[ == /* ]]` 绝对值校验，无 >3 层嵌套；`main()` 整体仍是单一线性 shell 函数 |
| R2 变更传播 | ✅ | 本次 diff 仅 `flow-kit-bundle/hooks/pre-tool-use/runtime-edit-guard.sh` 一个文件，与 write_files 完全一致，0 越界 |
| R3 知识重复 | ✅ | `~` 展开逻辑 DESIGN §0.5.2 明确「仓内唯一实现、新建内联、不建 helper」，未复制到别处 |
| R4 偶然复杂 | 🟢（轻微·接受）| `case` 三分支为满足 D6 语义的必要最小实现；未写任何「以后可能用到」的扩展点。可接受 |
| R5 依赖混乱 | ✅ | 纯 shell，无 import / 反向依赖 |
| R6 领域扭曲 | ✅ | 变量名 `real_path` / `file_path` / `source_path` / `runtime_kind` 均为领域词 |

### 🔴 主 agent 裁定（G-T04-1 / G-T04-2 处置排期 · 照抄原样落档）

## 阶段 4 · 主 agent 裁定（G-T04-1 / G-T04-2 处置排期）
- G-T04-1（`flow-kit-bundle/hooks/stop/lib/l3-prompt.sh:364` 的「未纳入」标记内插**全量**引用清单，把已纳入正文的 022/028/027/005 也声明为未纳入）与 G-T04-2（`:369` 称「整行截断」实为 UTF-8 边界半行截断）**定于 5-test 处置，且必须在阶段 5 门禁之前完成** —— 理由是这两处标记文案会进入每一次 L3 提示词，留着会在阶段 5/6/7 的 L3 轮次制造与 TD-043 同族的误判。
- T04 `<done>` 的历史实测值陈旧（49468 B → 实测 92947 B、命中集变化）**不改 TASK.md 正文**，由阶段 6/7 复核时加注。

### ⚙️ 工艺说明（非缺陷 · T05 提交复盘 · 2026-09-23）

> 本仓 `make test`（bats）内含**源↔安装副本一致性机器检查**（`B5-R2`、`B5-R5`）。
> 任何修改 `flow-kit-bundle/hooks/**` 或 `install_hooks.sh` 的 task，**必须先 `./sync-hooks.sh` 再提交**，
> 否则 pre-commit 的 `[archive-commit-gate]` 会因漂移（`B5-R2` 于 `test/test_l3_review_defects_2026_09.bats:968` 的
> `[ "$status" -eq 0 ]` 直接跑 `bash sync-hooks.sh --check`、`B5-R5` 于同文件 `:1330`）而红 —— 这是**门禁正常工作**，
> **不是缺陷**，应按此工艺先同步再提交（T05 实测：同步后 973 ok / 0 not ok / rc=0）。

### 🟡 T06 已知接受（settings 原子写副作用 · 2026-09-23）

| Task | Finding ID | Date | 发现 | 为何不本次修 | 后续动作 |
|---|---|---|---|---|---|
| T06 | T06-1 | 2026-09-23 | 原子写后 `settings.json` 权限 **644 → 600**（实测：`stat -c %a` 644 → 600）。成因：`mktemp` 默认 0600，`mv` 保留临时文件 mode，未回写原 mode | DESIGN D7/R4 明确指定「`mktemp` + `mv`」；仓内**既有** mktemp+mv 范式（`hooks/stop/lib/correction-file.sh:221/257/332`、`l2-detect.sh:318/433/477`、`l3-api.sh:99/168`、`l3-prompt.sh:499`）同样不保留 mode。回写 mode 需处理 GNU `chmod --reference`/BSD `stat -f` 差异，属 §0.5.2「原子写统一」v2（PC13）范围。影响：权限**更严**（owner-only），安装器与 Claude Code 同用户读写 ⇒ 无功能影响 | v2 统一原子写 helper 时一并处理 mode 保留 |
| T06 | T06-2 | 2026-09-23 | `settings.json` 若为**符号链接**（dotfiles 仓库软链），原子写后该路径被替换为普通文件（实测：`[ -L ]` 由 yes → no；link 目标仍留旧内容 40B）。成因：`mv` 覆盖的是链接本身，pre-fix `>` 跟随链接写目标 | `mv` 语义固有，修它需 `readlink -f` 解析真实路径后再原子写，超出 T06 写面（DESIGN 只说 mktemp+mv）。影响面：仅「settings.json 是软链」的少数配置，且安装后 settings 内容仍正确生效 | v2 评估 `readlink -f` 解析；当前可在安装后用真实路径替代软链 |
| T06 | T06-3 | 2026-09-23 | **有意行为变化**：`DRY_RUN=true` 下入口 jq 硬校验同样生效 ⇒ 无 jq 机器上 `install.sh --dry-run` 由 rc=0 变为 rc=1（dry-run 本身不写盘） | DESIGN §2.3 入口硬校验无 DRY_RUN 例外；dry-run 的价值正是提前暴露缺失依赖，fail-closed 一致 | 无（如需例外，v2 在入口判 DRY_RUN 时跳过校验） |
| T06 | T06-4 | 2026-09-23 | **有意行为变化**：merge/新建失败由「只打 ⚠️ 且 rc=0」改为「⚠️ + `return 1`」⇒ 安装整体非零退出（原「新建」分支即使 jq 失败也打 ✅ 且留下 0 字节文件） | 属 DESIGN「fail-closed」方向的加强，非缺陷；静默留半成品比非零退出更危险 | 无 |
| T06 | T06-5（工艺） | 2026-09-23 | `lib/install_hooks.sh` 的安装镜像**不在** `sync-hooks.sh` 同步面内：`collect_rel_paths` 只枚举 `hooks/{stop,stop/lib,pre-tool-use,session-start,pre-commit}` + `flow-kit/prompts/**` + opencode agent ⇒ 单跑 `./sync-hooks.sh` 无法同步 `~/.dsh/.../vendor/flow-kit-bundle/lib/install_hooks.sh` | 非 T06 缺陷，属工艺空洞：改 `lib/**` 后必须 `bash package-dsh-plugin.sh` 重建 dist + `make dsh-sync`，否则 `make check-dist` rc=2 报「陈旧: …/vendor/flow-kit-bundle/lib/install_hooks.sh」（T06 实测复现，已按此修复） | v2 把 `lib/**` 纳入 sync-hooks 面，或把 `check-dist` 接入 pre-commit |

### 🟢 T06 环境观察（`33-flow-active-integrity.sh` 裸跑 rc=1 · 2026-09-23）

| Task | Finding ID | Date | 发现 | 为何不本次修 | 后续动作 |
|---|---|---|---|---|---|
| T06 | T06-6 | 2026-09-23 | `bash flow-kit-bundle/hooks/stop/33-flow-active-integrity.sh`（仓库根 cwd）**裸跑 rc=1 且 stdout/stderr 全空、不写 `.flow-active.correction`**。根因：hook 只用局部变量 `hook_base=flow-kit-bundle/hooks/stop`，而它 source 的 `hooks/stop/lib/flow-kit-artifacts.sh:13` 依赖环境变量 `HOOK_BASE_DIR`（`source "${HOOK_BASE_DIR}/lib/done-validation.sh"`）⇒ hook 顶部 `set -euo pipefail` 的 `set -u` 立即退出。实测：`bash -c 'set -euo pipefail; source …/flow-kit-artifacts.sh'` rc=1 + `行 13: HOOK_BASE_DIR: 未绑定的变量`；加 `HOOK_BASE_DIR=…` 后 rc=0。唯一合法路径是 `hooks/stop/00-gate.sh:7`（`HOOK_BASE_DIR="$(cd "$(dirname "$0")" && pwd)"`）→ `:44 export HOOK_BASE_DIR …` → `:120 run_module "${HOOK_BASE_DIR}/33-flow-active-integrity.sh"` ⇒ **裸跑属 out-of-contract**，任何「裸跑该 hook 做 task_progress 自检」都会拿到误导性 rc=1 | 非 T06 缺陷：本仓既有 hook 结构问题，T06 只 append `goal.task_progress`，且**双态对照 4 态同值 rc=1**（含 T06 条目 / `jq 'del(.goal.task_progress[-1])'` 回到 T05 态 / 用 `534e3e8` 版 hook / 现状复跑）⇒ 与本次改动无关，修它属扩范围（R7.1） | v2：hook 内改 `HOOK_BASE_DIR="${HOOK_BASE_DIR:-$(cd "$(dirname "$0")" && pwd)}"`，使裸跑与 00-gate 编排行为一致 |
| T06 | T06-7 | 2026-09-23 | 补 `HOOK_BASE_DIR=… PROJECT_ROOT=…` 后该 hook 仍 rc=1，失败点前移到自身 `:235` 的算术展开：`行 235: 1790104581.736337: 语法错误：无效的算术运算符（错误记号是 ".736337"）` —— 因 `.flow-active` 顶层 `updated_at: 1790104581.736337` 是**浮点**时间戳（`534e3e8` 版 hook 同样在此炸） | 同上：状态文件/hook 双边的既有形态问题，不在 T06 写面（`install_hooks.sh`）。另注：本次 T06 的 `task_progress` 写入用 `mktemp` + `mv` 原子写，未触碰 `updated_at`（该浮点值早于本任务存在） | v2：把 `updated_at` 规范为整数秒，或 hook 侧对浮点/非整数做容错再进算术上下文 |

### 🟢 T07 已知接受（AC-5 源侧脱敏的固有代价 · 2026-09-23）

| Task | Finding ID | Date | 发现 | 为何不本次修 | 后续动作 |
|---|---|---|---|---|---|
| T07 | T07-1（R6 领域扭曲 · 🟢） | 2026-09-23 | 中性占位 `sample-proj_env` 的**信息量低于原文** `chisel_env`：原文「`<项目名>` + `_env`」能自解释命名约定（项目名+下划线环境后缀），而 `sample-proj` 是泛化名，后续读者无法从占位串反推真实命名约定；`test/test_correction_hygiene.bats:206-207` 的用例标题与 `test/test_l3_review_defects_2026_09.bats:4` 的溯源注释同此 | **该信息量损失正是 AC-5 的意图**（P3 = 切断雇主内部项目线索）；且保留任何可反推的命名结构都会削弱脱敏效果。语义位（skill 名 / 环境目录）已一一对应，测试可读性与判据均不受影响 ⇒ 属脱敏固有代价，非缺陷 | 无（如未来需要可读性更强的占位，须先确认不含可反推线索，且仍满足 `grep chisel` = 0） |

### ⚙️ 工艺说明（非缺陷 · T07 提交复盘 · 2026-09-23）

> 「先 `grep` 枚举消费方、再替换」这条工艺（AC-5 假设 3）**实测有效且必要**：T07 枚举出 12 处命中（4 文件 × 源码 6 处，双源各 6），
> 逐处判定后确认三处 fixture 值（`chisel-foreign` / `chisel-skill`）**只被写入、从不被断言读取** ⇒ 可安全替换而无需解耦；
> 若当时按「替换可能与断言耦合」直接改写断言，反而会引入无谓的断言改动（并触碰 out 段的「不得放宽断言」）。
> **定式**：脱敏/改名类任务必须先做「消费方枚举 + 逐处耦合判定」，把结论（命中总数 + 每个 `file:line` + 是否耦合）落档，
> 再做替换 —— 枚举是**证据**，不是形式步骤。

## 🧭 主 agent 裁定（阶段 4 · T07 两项遗留 · 2026-09-23）

**遗留 1「归档面未做」= 已分配，不必新建 task。** `REQUIREMENT.md:641` 的 AC-5 验收本就含分发件（`tar xzOf dist/dsh-flow-kit-0.2.0.tgz | grep -ac chisel` 由 **6 → 0**）；TASK 中该面归 **T24**（重建 `dist/dsh-flow-kit-0.2.0.tgz`、处置 `0.1.0.tgz`）与 **T27**（分发件复扫）。主 agent 实测「修复前」基线（2026-09-23 · **逐档、禁通配**，以免重演 `REQUIREMENT.md:642` 记录的 rc=2 构造性假绿）：`dist/dsh-flow-kit-0.2.0.tgz` = **6**、`dist/dsh-flow-kit-0.1.0.tgz` = **0**、`dist/dsh-flow-kit/vendor/flow-kit-bundle/test/test_correction_hygiene.bats` = **5**、`…/test_l3_review_defects_2026_09.bats` = **1**。⇒ 现阶段 `make check-dist` **预期为红**（dist/vendor 的 test 副本未随源更新）；**在 T24 之前不得据此判定任何 task 失败**。

**遗留 2「文档面」（`.specs/health/2026-09-22-FULL-SWEEP.md` 仍有 9 处 `chisel`）= 不扩大 AC-5 口径。** 理由：本 change 的全部工件（`REQUIREMENT.md` / `DESIGN.md` / `TASK.md` / 各审查档）**必须**指名被脱敏的目标串才能描述判据本身 —— 若把 `.specs/` 纳入 AC-5，则 AC-5 会与它自己的验收记录互相矛盾（判据档自身即含命中）。AC-5 的实测判据（`REQUIREMENT.md:640-642`）限定为 `flow-kit-bundle/test/` 与**分发件**（出厂面）；`.specs/` 属仓内过程记录、不随分发件出厂 ⇒ 保持在范围外。**若用户要求连仓内过程记录一并脱敏，那应另开 change**（换判据：逐档豁免清单 + 变更工件白名单），本 change 不夹带。


## 🟢 T08（AC-4 · check-gate-sync 内容比对）· 已知接受项（2026-09-23）

- **TC1/TC2（`check_gate_config_sync()` 值比较逻辑缺陷）= 🔴 留 v2。** 同文件内 `check_gate_config_sync()` 的 set-diff 值比较仍存在 TC1（390 行 mock 自证）与 TC2（值盲视）缺陷，严重度按巡检升级为 🔴（TD-033/TD-034）。**DESIGN D5 明确本 task 不收**：AC-4 只改 PCSC 判据，不碰值比较；强行并入会让本 change 范围失控。本 change 结束后 TC1/TC2 仍是活缺陷。
- **其余 11 对载体漂移无门禁覆盖 = 🟢 v1 边界接受。** v1 仅覆盖 3/14 对（内容本应一致、仅差 front-matter 的对）；其余 11 对已实质分叉（最惨 `6-review`↔`flow-review` 仅 28 行交集），强行纳入会让门禁立刻红且无法收敛。全量 14 对同步策略属 v2/TD-025（镜像 or 允许差异的精简版）。已在门禁输出打印覆盖度 `校验对 3/14` 防误读。
- **6 维自查无 🟡 / 🟢 需修项。** R1–R6 全 ✅（详见 `T08-SUMMARY.md` §9）。

### ⚙️ 工艺说明（非缺陷 · T08 台账复核 · 2026-09-23）

> T08 执行者写入的 `goal.task_progress[].completed_at` = `2026-09-23T05:05:14+08:00`，
> 而该提交自身的 git 时间（`git log -1 --format=%cI c3a1240`）= `2026-09-23T13:01:06+08:00` —— 同日、**相差 8 小时**，
> 而该值**格式完全合法**（带正确 `+08:00` 时区标签的 ISO 8601）⇒ 任何 schema / 正则校验都抓不到。
> 主 agent 已用 `jq` 原子改写为 `2026-09-23T13:01:06+08:00`（其余四字段未变）。
> **定式（已落 `.specs/LESSONS.md` L-127）**：五字段台账在写入后必须经**机器交叉校验**才可视为完成 ——
> `commit_sha` ⇒ `git cat-file -e <sha>^{commit}`；`completed_at` ⇒ 与 `git log -1 --format=%cI <sha>` 相差在**分钟级**（时区无关的正确比法）；
> `deferred` ⇒ 必须是数组；`id` ⇒ 与 `TASK.md` 中 `status="done"` 的集合一一对应。**「格式合法」≠「值正确」**（与 L-124 同族）。
> 该校验已写入阶段 4 执行者提示，并归 **T29**（收口）落为可执行判据。

## 🟢 T09（AC-7 前两条 · 恒真消除 + 断言对象订正）· 已知接受项（2026-09-23）

- **spec 自相矛盾的订正（1.8 fix loop 第 1 轮）**：TASK.md T09 原句「扫描根改为 `${TMPDIR:-/tmp}` 的单层 `tmp.*`…**禁用**裸 `/tmp/tmp.*`」本身自相矛盾 —— TMPDIR 未设时 `${TMPDIR:-/tmp}` **就是** `/tmp`，而本机 `/tmp` 现存 148 个无关 `tmp.*` ⇒ 默认环境恒红。责任在主 agent（spec 错，非执行错），修法已落**测试自身**（不靠调用者约定）。修复后断言面自带无噪声根（`$TEST_TMPDIR/scan`），`env TMPDIR="$root"` 驱动被测命令、只扫 `"$root"/tmp.*`，与环境 `/tmp` 彻底解耦 ⇒ **默认环境（TMPDIR 未设、/tmp 有 148 个无关文件）下 `make test` = 973 ok / 0 not ok / rc=0**，`env -u TMPDIR npx bats test/test_combined_metric.bats` = 2/2 ok。此前的「门禁须隔离 TMPDIR 驱动」口径随此订正**作废**。
- **本 test 现在断言什么（如实声明，不编造产品语义）**：`INT-COMBINED-1-cleanup` 断言的是**用例自身的临时文件生命周期在自有根内自洽且无残留** —— 在 `TMPDIR="$root"` 驱动下用 `mktemp` 造临时文件并随建随删（复刻 INT-COMBINED-1 的建/删模式），然后断言 `"$root"/tmp.*` 无残留（grep 无命中）。它**不直接测 task-brief 的输出正确性**（那是 INT-COMBINED-1 的 `≤20000` 字节断言），而是收敛 AC-7「恒真消除」的判据到可区分的真红/真绿，并外加上游裁决要求的「断言面自带扫描根、不回落环境 /tmp」卫生面。若未来要让该用例真测产品残余，需在 INT-COMBINED-1 与 cleanup 间共享一个文件级根（如 bats `setup_file`），属 v2，本变更不收。

> ### ⚙️ 工艺说明（非缺陷 · T09 反向对照 · 2026-09-23）
> 反向对照脚本初版因 `TEST_TMPDIR` 为空（在 bash -c 内未继承 bats `setup()` 的导出）导致
> `grep -vF ""` 过滤全部 ⇒ 注入态计数器恒 0 ⇒ 假红。已改为 `export TEST_TMPDIR=$(TMPDIR="$td2b" mktemp -d)`
> 复刻 bats `setup()` 形态后恢复正常（干净=0 / 注入=1）。**定式**：凡断言依赖 `setup()` 导出的变量，做反向对照时必须显式按 `setup()` 的形态构造环境，不可假设裸上下文继承。

## 🟢 T10（AC-7 后两条 · 反向断言补文件存在守卫 + AC-4 去过期 skip）· 已知接受项（2026-09-23）

- **AC-4 测试段遗留死脚手架（🟢 可接受，本次不修）**：AC-4 测试段在 skip 掩盖时期即存在的 `local tmp_script`、`cp package-flow-kit.sh "$tmp_script"` 与那段「重写 BUNDLE_DIR override」的注释块，在 skip 移除、测试现在真跑后成为**轻微 dead code**（`tmp_script` 未使用、`cp` 无副作用）。它**不影响断言正确性**（`TEST_ROOT` 由 `teardown` 清理；未用变量不改变断言路径），也**非 T10 目标**（T10 只要求移除 skip 并断言 exit 0）。为避免 T10 越界、保持 diff 最小，**留待后续 cleanup task** 清理，故登记于此。

> ### ⚙️ 工艺说明（非缺陷 · T10 verify 判据改写 ①）
> 任务 §4 ① 授权改写：**不得对真实 `$HOME` 执行 verify 的 `mv`**（真实
> `$HOME/.claude/hooks/stop/29-independent-review.sh` 是运行中 Stop hook/L3 门禁，移走期间被中断即全机门禁损坏）。
> 实做：HOME 沙箱 `sbx=$(mktemp -d)` + 复制真实文件进沙箱 + `HOME=$sbx npx bats …` 驱动 +
> 沙箱内 `rm` 副本验证红态 + `trap 'rm -rf "$sbx"' EXIT`。判据语义（文件缺失 ⇒ 反向断言必红，§4 实测
> 12ok→2not-ok rc=1）完全保留。**定式**：凡 verify 涉及 `$HOME/.claude/hooks/stop/*` 运行中门禁文件，一律
> 用 HOME 沙箱副本 + `rm`（非 `mv`）制造缺失态，不做任何对真实 HOME 的移走动作。

> ### ⚙️ 工艺说明（非缺陷 · T10 verify 判据改写 ②）
> 任务 §4 ② 授权改写：skip 检查不得用裸 `grep -q 'skip'` —— AC-4 段去 skip 后注释里含「原过期 skip
> 已移除」字样，裸 grep 会读成残留 skip ⇒ 假红（L-125 同族）。改用**行级锚定** `sed` 抽取 AC-4 段 +
> `grep -qE '^[[:space:]]*skip([[:space:]]|$)'`（只匹配真 `skip` 调用形态，不匹配注释文本），并保留
> 一条 的 AC-4 存在性前置 `grep -q 'AC-4: …exit = 0'` 防 sed 无匹配静默通过。双态实测：注释含「原 skip」
> 仍绿；注入真 `skip "临时注入"` 必红。
