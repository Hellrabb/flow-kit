# 独立审查 · 阶段 2

## L2 盲审（阶段 2 · 2026-09-29）

> written_by: L2 独立盲审子代理（architect-reviewer · DSH 无宿主 l2_dispatch_agent · 直写代行）

**独立性声明**：输入仅含工件路径与固化指令，未检测到主 agent 自评/草稿/概述/辩护注入，无独立性受损事项。全程未读取 INDEPENDENT-REVIEW-1.md 与 MINOR-DEFERRED.md。

**审查方法**：通读 DESIGN.md（217 行）+ REQUIREMENT.md + ADR-030/031/032 + CONTEXT.md + ARCHITECTURE.md + CHANGE.md（仅作 C1–C14 事实上下文，非结论输入）。L-031 独立全仓 grep 锚点：`jq_atomic_write`、`health-fix-2026-09b`、`node --test`、Makefile×jq、`.flow-active` 内联解析、prompts↔skills 配对、`L2-first 契约未满足` 报文、`|| exit 0` fail-open 点、机器安装态软跳过模式；并对 §0.5.1 所引行号逐文件 sed 核对生产源。

---

### 🔴 R1 · L-031 触碰清单漏列/错挂（修复面文件缺失）：§0.5.1 至少漏 5 组必改文件，其中 C14-h 错挂到错误文件

**Severity**：🔴 Critical

**Symptom**：DESIGN.md:26-63（§0.5.1）vs 全仓独立 grep 实证——

1. **C3 脱敏 6 文件全部缺席**：`.specs/health/2026-09-22-FULL-SWEEP.md`、archive/09b 的 INDEPENDENT-REVIEW-1/2.md、STATE.md、LESSONS.md、CONTEXT.md（AC-4 的 30 行真名正位于这 6 个文件；清单只列了 check-path-privacy.sh 与 test_path_privacy_gate.bats 的「C2/C3 基线文件化」）。
2. **C6 行为断言 5 文件只列 1**：`test/test_fix_l3_gate.bats`（6 处）、`test/test_l2_pretooluse_dispatch.bats`（4 处）、`test/test_dual_review_merge.bats`（3 处）、`test/test_l3_lifecycle_wiring.bats`（1 处）均实测存在且不在清单——AC-9 要求 32 处，清单只覆盖 test_l3_review_defects_2026_09.bats 的 18 处。
3. **C5 mock 主战场缺席**：`test/test_gate_config_presets.bats`（实测 `grep -c '"independent"'` = 72；AC-7 要求归零、§2 数据流写「mock 值改 both」）不在清单。（注：DESIGN/CHANGE 称 90+/92 处，与实测 72 口径不一，但目标同为 0。）
4. **C14-c 软跳过测试文件零落点**：grep 实证 ≥4 文件含机器安装态软跳过（test_independent_review_model.bats、test_l3_pipeline_fix.bats、test_l3_review_defects_2026_09.bats、test_runtime_edit_guard.bats；CHANGE 以更宽模式计 11 文件），§0.5.1 无任何 C14-c 条目。
5. **C14-h 错挂文件**：7 处降级 skip 实测在 `test/test_hook_integration.bats:20-22,34-37`（`grep -q … || skip` ×7），DESIGN.md:45 却把「C14-h：7 处降级 skip 处置」挂在 test_l3_review_defects_2026_09.bats 名下（该文件只承载 be138c0 硬编码 SHA），test_hook_integration.bats 整文件不在清单。

附加（ADR 义务漏列，随主 finding 记录）：ADR-031 点名的白名单文件 `.specs/health-fix-2026-09c/flow-active-inline-whitelist.txt` 不在「新增模块」；ADR-030 决策 3 承诺 7-integration 同步的 `.specs/ARCHITECTURE.md` §2.2 增补行不在触碰清单。

**Source**：固化指令 L-031 教训（「§0.5.1 可能不完整，L2 必须独立全仓扫描，不信 DESIGN 清单」+「漏列属本次 C1–C14 修复面 = 🔴 Critical」）；REQUIREMENT AC-4 / AC-7 / AC-9 / AC-12-c / AC-12-h。

**Consequence**：3-task 阶段以 §0.5.1 为 write_files 边界——AC-4 的 6 文件不被触碰（`git grep` 真名 ≠0，AC-4 直接失败）；AC-9 的 14/32 位点、AC-12-c 的 11 位点、AC-12-h 的 7 skip 全部落空；C5 mock 值不改则 check-gate-sync 换生产源后 make check 立即真红（mock 仍写 independent，集合比对必不匹配）。

**Remedy**：§0.5.1 补 5 组文件（各含 flow-kit-bundle/test/ 镜像侧）+ 白名单文件 + ARCHITECTURE.md 行；C14-h 归属改为 test_hook_integration.bats（7 skip）与 test_l3_review_defects_2026_09.bats（be138c0）双文件并注记。

### 🔴 R2 · D6 与 AC-6 正面冲突且论据被生产代码证伪：告警级别 error≠warning、|| true 去留与规格相反

**Severity**：🔴 Critical

**Symptom**：DESIGN.md:103（D6「:200 保留 \|\| true … module_output "error" 告警」）与 DESIGN.md:198（§9.3「L3 backlog 失败必发 module_output "error"」）vs REQUIREMENT AC-6「29:200 删 \|\| true，module_output "warning" 实际打印」。生产实证：`flow-kit-bundle/hooks/stop/00-gate.sh:71` `timeout 120 bash "$script" … \|\| true`，注释明示 "Exit codes from modules are non-fatal — report generation always runs"——D6 否决备选①所依据的「Stop 链中断风险」不成立（模块 rc 在编排层已被吞）。现行为 `flow-kit-bundle/hooks/stop/29-independent-review.sh:200-203`：`l3_review_run … \|\| true` → `:201 local bl_rc=$?` 恒 0 → `:203 module_output "warning"` 永不打印。

**Source**：REQUIREMENT AC-6 验收判据（字面）；CONTEXT 已锁决策「门禁只拦 error 级不升 warning（TD-023）」——error 为拦截级语义，非拦截性通知标 error 违反级别纪律；Stop 链模块约定以 00-gate.sh 实现为准。

**Consequence**：5-test 按 AC-6 字面断言（warning 打印）则 D6 实现必红；按 D6 实现则 AC-6 未按规格实现（spec 合规失败），且 §9.3 把偏离固化进架构契约；L3 backlog 每次失败抬高报告 ERRORS 计数，error 级噪声污染真拦截信号。

**Remedy**：D6 改为「删 :200 \|\| true（bl_rc 直接捕获真实 rc；炸链由 00-gate.sh:71 兜底）+ module_output "warning"」；§9.3 C4 契约同步改 warning。若确要保留 \|\| true / error 级，须走 REQUIREMENT 修订流程显式改 AC-6 并登记偏离，不得静默改契约。

### 🟡 R3 · check-skills-sync「未配对目录必红」判据自相矛盾：16 目录 > 14 对，门禁上线即永久红

**Severity**：🟡 Important

**Symptom**：DESIGN.md:196（§9.3「任何未配对 skills/flow-* 目录 → rc≠0」）+ DESIGN.md:102（D5 自认「现 16 > 14」）vs 实测：`flow-kit-bundle/skills/flow-*/` 共 16 目录，14 个 prompts .md 与 14 个 skill 目录精确配对后，`flow-go/`、`flow-kit-install/` 无 prompt 对应（另有 `skills/flow/`（PRESET_MAP 所在，2 处命中）不匹配 flow-* glob）。两目录无豁免/配对映射设计；D5「新增第 5 个 skill 目录」计数亦含混（16−14=2，加 skills/flow/ 为 3，均非 5）。

**Source**：REQUIREMENT AC-13（make check rc=0 全绿）与 AC-11（14/14）联立——门禁判据必须可满足；Ousterhout《A Philosophy of Software Design》深模块原则：判据的例外面应在接口显式化，不留实现即兴。

**Consequence**：TASK 按 §9.3 字面实现，check-skills-sync 上线首日常驻红（AC-13 不可达），实现者只能私自发明豁免——文档与判据再次分叉（C13「清单自曝覆盖不足仍 rc=0」的反向复刻）。

**Remedy**：§9.3/D5 补配对映射或豁免清单：flow-go → flow-kit/GO.md、flow-kit-install → 安装文档（或登记白名单），并写明 skills/flow/（非 flow-* glob）不受此门禁管辖。

### 🟡 R4 · AC-11 反向探针判据欠定义：@see「锚点存在」未要求目标可解析，删 prompt 小节未必转红

**Severity**：🟡 Important

**Symptom**：DESIGN.md:99（D2 门禁三判据「14 对全覆盖 + @see 锚点存在 + 注入漂移 rc≠0」）与 DESIGN.md:138（§2 同表述）——「锚点存在」可读作仅查 SKILL.md 侧含 @see 字符串；而 REQUIREMENT AC-11 反向判据为「删一个 prompt 小节必转红」。

**Source**：CONTEXT 术语「反向控制（构造已知漂移断言门禁转红，无反向控制的门禁修复不可信）」；已锁决策「门禁判据必须比内容/结构禁只比计数」。

**Consequence**：若实现成「SKILL 侧含 @see 即绿」，删 prompt 小节不触发转红——权威载体内容被删而门禁照绿，正是 C11 类「更绿不更红」失效模式在新建门禁上复发；AC-11 反向验收必失败。

**Remedy**：D2 判据补第四项：每个 @see 锚点必须解析到 prompt 文件中实际存在的标题/行锚，目标缺失 → rc≠0；test_skills_sync.bats 固化「删 prompt 小节必红」反向用例。

### 🟡 R5 · AC-8「三个子库 declare -f 断言」落点错位：DESIGN/ADR-032 把子库断言安到 stop/lib（l3-*），AC-8 的三子库是 pre-tool-use 的 gate-*

**Severity**：🟡 Important

**Symptom**：DESIGN.md:35「flow-kit-bundle/hooks/stop/lib/ 下三个子库（C12：补 jq 依赖断言…）」+ ADR-032 决策 2（l3-review.sh/l3-prompt.sh/l3-section.sh）vs 实测：`flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh:42-46` 连续 source `${SCRIPT_DIR}/gate-helpers.sh`、`gate-checks-basic.sh`、`gate-checks-review.sh`（SCRIPT_DIR = hooks/pre-tool-use/，三文件实在此目录）且 source 后无 declare -f 断言；D4（DESIGN.md:101）只点名两种注入（jq 缺失/非法 JSON），其「三种注入各自转红」的第三种（函数缺失）无机制落点。

**Source**：REQUIREMENT AC-8（「三个子库 declare -f 断言」「三注入面 PATH 遮蔽 jq/非法 JSON/函数缺失均 exit 2」）；CHANGE C12 证据（independent-review-gate.sh:32-37 declare -f ✅ vs :42-46 三子库无断言 ❌，所指为 gate 侧）。

**Consequence**：TASK 照 §0.5.1 给 stop/lib 的 l3-* 三库加 jq 断言（超出 AC 的分外功），而 gate-* 三库 source 失败/被篡改仍静默半失效——AC-8 第一注记与「函数缺失 exit 2」注入面落空，AC-8 验收失败。

**Remedy**：§0.5.1 拆两行：① pre-tool-use 三子库（gate-helpers/gate-checks-basic/gate-checks-review）在 independent-review-gate.sh:42-46 各 source 后补 declare -f 断言（对齐 :33-37 既有范式），D4 明示第三注入面（函数缺失 → exit 2）；② stop/lib l3-* 三库 jq 断言作为 ADR-032 纵深保留，注明超出 AC-8 字面。

### 🟡 R6 · C14-b 预设名比对面漏第四载体：pre-tool-use/gate-helpers.sh:26 内联值域不在「三载体」断言内

**Severity**：🟡 Important

**Symptom**：DESIGN.md:197（§9.3「SKILL/bats/dsh JS 三载体以集合比对断言」）vs 实测 `flow-kit-bundle/hooks/pre-tool-use/gate-helpers.sh:26` jq 过滤器内联 `.value == "independent" or .value == "true" or .value == "both" or .value == "L2" or .value == "L3"`，:29-30 case 分支第二次内联同一值域（CHANGE C14-b 自己实证的 4 载体之一）。

**Source**：CHANGE C14-b（4 载体清单含 gate-helpers.sh:26）；AC-12-b「预设名三载体同一集合+反向漂移必红」——AC 与 DESIGN 同步少列一载体，但 CHANGE 证据在案，设计有义务覆盖全修复面。

**Consequence**：值域演进（新增别名/废弃 independent）时 gate-helpers.sh 漂移无门禁可检——该文件的快照篡改检测函数（:20-32）自身用旧值域判「合法值」，安全网静默退化，C14-b「反向漂移必红」留洞。

**Remedy**：§9.3 比对面扩为四载体（SKILL/bats/dsh JS/gate-helpers.sh），gate-helpers.sh 值域以提取器文本比对纳入 check-gate-sync（同 D1 数据化模式，不必 source）。

### 🟡 R7 · C14-g 检测锚点=「内联 jq」漏掉 Makefile:250-253 手搓 bash 解析；§2 数据流与 D3 自相矛盾；白名单基线 28 不可复现

**Severity**：🟡 Important

**Symptom**：DESIGN.md:100（D3「Makefile 实测内联计数已 = 0（天然满足）」）与 DESIGN.md:125-127（§2 数据流画「Makefile 调用 ▲ flow-active-query.sh」）互相矛盾；实测 Makefile 确无 jq（grep=0），但 `Makefile:250-253` 用纯 bash while/read/case 手工解析 `.flow-active` 的 change_id 键（格式知识内联、`|| true` 吞错；CHANGE 记 :251）。另：宽松 grep `jq×.flow-active` 全仓命中 43 文件（含 bundle 镜像与注释误配），「28 文件基线」设计期不可复现。

**Source**：ADR-031 自身目标「schema 变更单点收敛；多源解析漏改即静默漂移」——检测谓词只认 jq，则非 jq 解析器永久逃逸白名单计数与收敛。

**Consequence**：.flow-active schema 变更（如 change_id 改键名）时 Makefile:250-253 静默解析失败，.change-base 锚点定位失灵——ADR-031 要消灭的多源漂移恰留在白名单之外；TASK 无法用可复现判据重建基线。

**Remedy**：D3 补决策：Makefile:250-253 手搓解析一并改调 flow-active-query.sh（§2 箭头如实化）；白名单计数谓词定义为「任何读取 .flow-active 的解析代码（jq 或 bash）」，基线在 TASK 以可复现 grep 重建并落 .specs/health-fix-2026-09c/flow-active-inline-whitelist.txt。

### 🟡 R8 · 四项 AC 机制只落到文件名、无决策内容：C2 正则策略 / C7 单跑判据 / C10 lint 语义化 / C14-c skip 双计数

**Severity**：🟡 Important

**Symptom**：DESIGN.md:30（check-path-privacy.sh 仅注「C2/C3：基线文件化」——AC-3 核心是 PAT 收紧：实测 `check-path-privacy.sh:72` `PAT='/home/[a-z_][a-z0-9_-]*/'` 强制尾斜杠、与真实泄漏形态零交集，占位符按用户名成分排除（:74-76）如何与裸路径判定共存无决策）；DESIGN.md:39（Makefile 仅注「C7/C10：隔离」——实测 `Makefile:10-12` bats 跑两遍、`:46-47` `grep -ci error` 文本近似；单跑 PIPESTATUS[0] 与 shellcheck -S error 按 rc + 缺工具 fail-closed 均无决策）；C14-c「skip 显式双计数」判据零落点。

**Source**：REQUIREMENT AC-3/AC-10/AC-12-c 的机制性验收（裸路径/反引号探针命中、占位符不误伤、PATH shim 计数、双计数）；CONTEXT 已锁决策「门禁判据必须比内容/结构禁只比计数」——判据语义属设计层。

**Consequence**：TASK 即兴选正则策略可能重蹈尾斜杠盲区或反向误伤占位符（CHANGE 风险表警示：宽通配吞 31 处 <acct> 含 10+ 真实）；C10 若仍文本近似则 AC-10 反向探针必红。

**Remedy**：补三行微决策：C2=路径段边界判据 + 按用户名成分的占位符白名单（PLACEHOLDER_NAMES 扩全）；C7/C10=bats 单跑取 PIPESTATUS[0]、shellcheck -S error -f gcc 按 rc 判红、command -v 缺失即 exit 1；C14-c=skip 计数进用例计数判据（双计数显式断言）。

### 🟡 R9 · D7 把 AC-15-②「diff=空」重定义为「权威正文段 diff=空」并推迟决策到 TASK：保底正文选项与 AC 字面冲突未声明

**Severity**：🟡 Important

**Symptom**：DESIGN.md:104（D7「TASK 阶段实测 opencode agent 加载路径后定（保留最小触发段，判据：正文 diff 为空指权威正文段）」）vs REQUIREMENT AC-15-②「opencode 163 行复制段消除 diff=空」。实测双正文：`flow-kit-bundle/flow-kit/.opencode/agent/flow-kit-l2-reviewer.md`（198 行，:36-198 为复制段）与 `flow-kit-bundle/flow-kit/prompts/independent/L2-blind-review.md`（唯一权威）。

**Source**：阶段分工——机制可行性判定属 2-design 职责，TASK 只执行已决策方案；AC 偏离须显式降级登记（本 change 对 C9/AC-16 正是如此处理）。

**Consequence**：若 TASK 实测后选「保底正文」，复制段实质保留（仅缩短），AC-15-② 字面不可达且偏离无登记——口径漂移进入下一阶段。

**Remedy**：D7 预先二选一并写死：opencode 支持引用 → 纯 @see；不支持 → 壳内仅留 frontmatter + 触发段 + 指路文案（复制段清零，指令经派发 prompt 注入），判据写为「l2-reviewer.md 与 L2-blind-review.md 公共行数 = 0」。

### 🟡 R10 · 风险段遗漏执行顺序类关键风险：合法红窗口、C2→C3 强制顺序、值比较先于 mock 改值

**Severity**：🟡 Important

**Symptom**：DESIGN.md:154-162（R1–R5 全为实现/上线/债务/数据类）无一条执行顺序风险；而 REQUIREMENT 非功能明列「顺序依赖：先改值比较逻辑再改 mock 值」，CHANGE 风险表明列「C2→C3 排序、合法红、C5 连带真红」。本 change 向 make check 新挂/收紧 ≥3 门禁（check-skills-sync、path-privacy 收紧、fail-closed 化），开发中途必然出现长红窗口。

**Source**：CONTEXT 术语「合法红窗口（C2 修复后 C3 完成前必红，预期非回归）」；已锁决策 ①（C2→C3 强制顺序）。

**Consequence**：TASK 波次若无设计级顺序约束，会把合法红误判为回归（回滚正确修复），或为求绿推迟门禁挂链（修复不完整即合入）。

**Remedy**：§5 补 R6（执行顺序）：波次序 = C12 → C5/C11 值比较 → mock 改值 → C1 沙箱 → C2 正则 → C3 脱敏 → 新门禁挂链最后；注明合法红窗口判据（哪些 target 允许中途红、何时必须转绿）。

### 🟢 R11 · 行号锚点漂移削弱「grep 实证」可信度

**Severity**：🟢 Minor

**Symptom**：DESIGN.md:35/:72 与 ADR-032 引「common.sh:32-37 jq 依赖断言范式」——实测 common.sh:32-40 是 module_enabled()，真实断言在 `common.sh:226`（fk_resolve_phase 内 `command -v jq … \|\| return 1`）与 `common.sh:84-90`（hook_init 条件回退，fail-open 风格）；DESIGN.md:33「:114」实为 independent-review-gate.sh:113；C14-f 只注 :92-93，实测 SELF_EXCLUDE 六行（`check-path-privacy.sh:89-95`，含三条 09b 路径）与 `ALLOWLIST_CHANGE`（:102）同为硬编码面；`test/test_path_privacy_gate.bats:31,:656-659,:685` 亦有 09b 路径字面量（文件在清单但未注 C14-f 归属）。

**Source**：§0.5.1 自称「grep 实证」；TD-041 教训（引用以实有文件为准）。

**Consequence**：TASK 按错误行号找范式/改点，浪费往返或漏改（:102 与测试侧字面量残留使 AC-12-f「不再硬编码」判据口径含混）。

**Remedy**：TASK 首个任务固化行号重核（本审查实测行号可直接采用）；AC-12-f 判据明确 grep 范围（生产面 or 全仓含测试 fixture）。

### 🟢 R12 · STATE.md 文件名约定需确认

**Severity**：🟢 Minor

**Symptom**：REQUIREMENT AC-14/AC-16 以「STATE.md ≥14 条 / STATE.md 可 grep」为判据，DESIGN.md:168 亦写「登记 STATE.md」；实测 `.specs/health-fix-2026-09c/` 现役状态文件是 PROGRESS.md（无 STATE.md）。

**Source**：AC 判据可执行性（grep 目标必须存在）。

**Consequence**：5-test/6-review 按 STATE.md grep 验收时目标缺失，误判 AC-14/AC-16 未达成。

**Remedy**：需确认（向 REQUIREMENT 作者提问）：STATE.md 指 change 级新文件还是沿用 PROGRESS.md——统一文件名后同步 AC 判据。

### 🟢 R13 · 陈旧架构基线数字不在校准面内

**Severity**：🟢 Minor

**Symptom**：ARCHITECTURE.md §3「ADR 编号最大值 027」vs 实测 `.specs/adr/` 已有 028–032；§6 bats 基线 213 vs 现实 ≥1116；§2.1「17 skills / Stop 链 14 模块」vs 实测 17 个 skill 目录（16 flow-* + flow）、Stop 链 18 个编号模块。DESIGN §9 沉淀建议未含这些基线更正。

**Source**：TD-041（引用以实有文件为准）；文档漂移与 C13 载体分叉同构。

**Consequence**：后续 change 继续以过时基线做容量/编号判断。

**Remedy**：7-integration 顺带更正 ARCHITECTURE §3/§6 基线行（可与 ADR-030 决策 3 的 §2.2 增补同提交）；不入本 change fix loop，写入 MINOR-DEFERRED.md。

---

**AC 覆盖矩阵（摘要）**：AC-1 ✓（§0.5.2 F6 沿用）· AC-2 ✓ · AC-3 △（R8 机制无决策）· AC-4 ✗（R1 六文件漏列）· AC-5 ✓（R5 风险 + §0 git-filter-repo 2.47.0）· AC-6 ✗（R2 与 D6 冲突）· AC-7 △（D1+§2 有机制，mock 文件漏列见 R1）· AC-8 △（R5 子库错位）· AC-9 ✗（R1 4/5 文件漏列）· AC-10 △（R8）· AC-11 △（R3/R4 判据）· AC-12：a ✓ · b △(R6) · c ✗(R1) · d ✓（:76↔:84 实测确认）· e ✓（D8，:233 实测确认）· f △(R11) · g △(R7) · h ✗(R1) · i ✓（§6 操作项）· AC-13 ✓（受 R3 连带风险）· AC-14 △（R12）· AC-15：① ✓ ② △(R9) ③ ✓ · AC-16 ✓（§6 显式降级）· AC-17 ✓（install_hooks.sh + F6 沿用）

**Verdict**: fail

---

## 主 agent 响应（阶段 2 · 对 L2 盲审 · 2026-09-29）

> 处置原则：🔴/🟡 全部进入本响应并落盘修订；🟢 按规则进 MINOR-DEFERRED.md（R11/R12 已随修订顺手修正，仍留痕）。所有修订均落 DESIGN.md / ADR-030/031/032 实文件，行号锚点均已 grep 复核。

### 🔴 处置

- **R1（触碰清单漏列/错挂）— Fixed in**：DESIGN §0.5.1 重写测试面与文档面两块——① C3 六文件全列（2026-09-22-FULL-SWEEP.md / 09b archive 两份 INDEPENDENT-REVIEW / 仓库级 STATE.md / LESSONS.md / CONTEXT.md）+ ARCHITECTURE.md（§2.2 增补行）；② C6 32 处全清单（test_l3_review_defects 18 + test_fix_l3_gate 6 + test_l2_pretooluse_dispatch 4 + test_dual_review_merge 3 + test_l3_lifecycle_wiring 1）；③ C5 主战场 test_gate_config_presets.bats 入清单（72 处 both 改造与值比较同批不可拆）；④ C14-c 11 文件入口 + TASK 首任务 grep 重核条款；⑤ C14-h 错挂纠正：真实落点 test_hook_integration.bats（实测 :17,:20-22,:31,:34-37），test_l3_review_defects 改挂 be138c0 硬编码 SHA；⑥ C14-f 测试侧字面量（test_path_privacy_gate.bats:31,:656-659,:685）同步入清单。
- **R2（D6 与 AC-6 正面冲突）— Fixed in**：D6 整行重写为「删 `:200 || true` + `module_output "warning" "IR" "backlog L3 failed…"`」，逐字对齐 AC-6 Given/Then；「Stop 链中断风险」论据撤回并以 `00-gate.sh:71`（模块 rc 非致命，本设计 grep 复核）为兜底依据；error→warning 对齐 TD-023 级别纪律；备选栏显式记录被否方案与回退路径（若 TASK 实测推翻兜底假设 → 走变更流程改 AC-6，不静默偏离）。§2 告警流图与 §9.3 C4 契约行同步改 warning。ADR-032 不受影响（其 error 语义只辖 Stop 检查器注入告警，不辖 C4 backlog）。

### 🟡 处置

- **R3（配对判据 16>14 矛盾）— Fixed in**：D5 + §9.3 显式豁免映射——flow-go → GO.md（D7 同构）、flow-kit-install → 安装文档型（登记豁免+理由）；`skills/flow/`（PRESET_MAP 所在）不匹配 flow-* glob 不受辖；门禁只辖 flow-*。
- **R4（@see 锚点欠定义）— Fixed in**：D5 + §9.3 判据升级为「锚点**可解析**（目标文件存在且标题/行锚命中，目标缺失 → rc≠0）」。
- **R5（断言落点错位 + 漏注入面）— Fixed in**：D4 + ADR-032 重写——落点改为 pre-tool-use 三子库（gate-helpers / gate-checks-basic / gate-checks-review，被 independent-review-gate.sh:42-46 source，实测无断言）；注入面补第三类「source 后函数缺失 → exit 2」；bats 反向控制补函数遮蔽注入；范式锚点核正为 independent-review-gate.sh:33-37（declare -f）与 common.sh:226（jq 存在性）；stop/lib l3-* 三库标注为 AC-8 字面外的纵深（CHANGE 显式注明）。
- **R6（第四载体）— Fixed in**：D4 补 gate-helpers.sh:26 内联值域 + :29-30 case 二次内联；§9.3 gate_config 契约行改「四载体」集合比对（SKILL / bats / dsh JS / gate-helpers.sh:26）。
- **R7（Makefile:250-253 手搓解析逃逸）— Fixed in**：D3 重写——检测谓词 =「任何读 .flow-active 的解析代码（jq 内联 ∨ bash 手搓）」；:250-253 改调 flow-active-query.sh；「Makefile 恰为 0」表述撤回；白名单基线改为 TASK 严格谓词重建落盘（宽松 grep=43 / 巡检判读 28 均不可作机器基线）；ADR-031 背景与决策同步改写。
- **R8（四项机制无决策）— Fixed in**：新增决策行 **D9**——C2 字面量族（不引入正则）/ C7 mktemp+HOME 沿用 F6 / C10 安装清单文件化（记录→按单删，残留 diff=0）/ C14-c 双计数口径（文件数 + 位点数，各对 TASK 重建基线）。
- **R9（D7 重定义 AC 判据）— Fixed in**：D7 判据定死「复制段公共行数 = 0」并显式与 AC-15-②「正文 diff 为空」画等号（同义），TASK 零裁量；opencode 保底 = 装配参数 + @see 触发说明，正文本体零复制。
- **R10（执行顺序风险缺失）— Fixed in**：§5 新增 R6（执行顺序）——C2→C3 偏序、值比较先于 mock 改 both、门禁与薄壳化同 wave、C12 先于 AC-17；TASK 波次须显式编码此偏序，每 wave 收尾 make check 全绿才进下一 wave。

### 🟢 处置

- **R11（行号漂移）— Fixed in（顺手）**：common.sh:32-37 → :226（jq 断言真位）+ independent-review-gate.sh:33-37（declare -f 范式）；independent-review-gate.sh:114 → :113；C14-f :92-93 → :89-95（SELF_EXCLUDE）+ :102（ALLOWLIST_CHANGE）；§0.5.2 表格同步核正并留「行号漂移已核正」注记。
- **R12（STATE.md 文件名）— Fixed in（顺手）**：DESIGN §0.5.1 注明销账载体 = **仓库级** `.specs/STATE.md`（实测存在 107 行，阶段 1 已更新活跃段）；change 目录内 PROGRESS.md 是进度文件，AC-14 计数锚定前者——判据可 grep，无歧义。
- **R13（ARCHITECTURE 基线过时）— Deferred**：写入 MINOR-DEFERRED.md（M3），7-integration 与 ADR-030 决策 3 的 §2.2 增补同提交更正。

**处置结论**：🔴×2 Fixed in · 🟡×8 Fixed in · 🟢×3（2 顺手修正 + 1 defer）。AC 覆盖矩阵中 ✗ 项（AC-4/6/9/12c/12h）全部由 R1/R2 修复解除；△ 项由 R3–R9 对应解除。

## 主 agent 响应（阶段 2 · 对 L3 盲审 · 2026-09-29）

**7 major 全部 Fixed in，5 minor 全部 fixed in passing（无新增 defer）。**

- **major①（AC-7/AC-11 机制错位）**：Fixed。D1 重写——提取器函数名定死 `resolve_gate_config`、定义于 check-gate-sync.sh 内，测试双侧 source check-gate-sync.sh 获得同一实现（AC-7「双侧 source 同一实现」字面满足，非 source 生产 hook lib）；AC-11 When/验证改 `make check-skills-sync`（REQUIREMENT 已对账标注「2026-09-29 L3 阶段 2」）。
- **major②（白名单 per-change 失效）**：Fixed。常设路径 `flow-kit-bundle/flow-kit/reference/flow-active-inline-whitelist.txt` + `reference/path-privacy-baseline.txt`，读序沿用 ADR-028（常设 > 种子 > 双缺 fail-closed），09c 目录只放种子副本；ADR-031 决策 2 同步改写。
- **major③（C2 语义混叠 + 自指泄漏）**：Fixed。D9-C2 拆门禁面（AC-3 通用 PAT + PLACEHOLDER_NAMES）与脱敏面（AC-4/5 精确字面量集外置常设基线，文件自身 SELF_EXCLUDE）；远程 URL 真值仓外临时文件传递（AC-5 步骤 ⓪ 捕获/⑥ 删除）；本 change spec 内真名串已占位化（INDEPENDENT-REVIEW-1.md 两处 `git@github.com:<OWNER>/flow-kit.git`，DESIGN/REQUIREMENT 散文占位写法）——replace-text 不再命中本 change 决策记录。
- **major④（触碰清单五缺口）**：Fixed。§0.5.1 补 l3-* 三库纵深行、l2-detect.sh（承接 `_l2_first_deny()` 抽取）、pre-push.sh 本体（实测 flock=0，须内置并发闸）、check-skills-sync.sh 落点定死 reference/（ADR-030 豁免）、check-path-privacy 行核正（:72 PAT + PLACEHOLDER_NAMES + 头部锚点 + 四条 09b 锚点）。
- **major⑤（D7 判据互斥）**：Fixed。D7 收敛为单一判据 `comm -12 <(sort <权威正文段>) <(sort <载体B全文>) | wc -l` = 0；AC-15-② 机检同步改写并显式变更流程（原 diff 判据作废，对账标注），「两判据并存」不再。
- **major⑥（遮蔽检测机制不匹配）**：Fixed。注入面③收窄为「缺失/半安装」（declare -f 可证），「遮蔽」显式移出；ADR-032 决策 1/3 同步改写（反向控制 = PATH shim / 非法 JSON / 删函数·改名）；备选「行为探针」记 v2 再议。
- **major⑦（AC-12g 责任再分配未对账）**：Fixed。DESIGN 新增附录 A：严格谓词命令 + 条目格式（路径 + 理由行）；D3/ADR-031 同步引用——白名单定稿回到 DESIGN，TASK 只按附录 A 谓词重建计数基线，责任不再移交。
- **minor①-⑤**：全部 fixed in passing——09b 行 SELF_EXCLUDE 四条已在 §0.5.1 核正（allowlist + IR-1/2/3）；C14-c 终局权威 = TASK 严格谓词重算（HEALTH 附录 C 11/11 为种子，偏差回写 CHANGE 登记）；§2 图措辞改「读生产真源文本——非 mock、非 shell source」；§5 补 R7（.flow-active 写点 tmp+mv 核查 + exit 2 重试指引）与 R8（node 缺失 fail-closed 提示）；§9.2 补「skill→prompt 直引」决策行（7-integration 落 ARCHITECTURE §5）。


---

## L2 盲审（重审 · 第 2 轮 · 2026-09-29）

工件：`.specs/health-fix-2026-09c/DESIGN.md`（263 行）。参考：ADR-030/031/032、CONTEXT.md、ARCHITECTURE.md、REQUIREMENT.md；`flow-kit-bundle/` 全树只读核对。独立性：输入未含主 agent 自评，无污染需标注。

**锚点核对（L-031 通用必查，独立全仓 grep，抽样全过）**：AC-4 前提精确成立——`git grep -E '/home/<acct>' -- .` = 6 文件 30 行，与 AC-4 清单一一对应（FULL-SWEEP 11、09b REVIEW-1 6、REVIEW-2 9、STATE 2、LESSONS 1、CONTEXT 1）；`fk_normalize_gate_val` 实体 = `flow-kit-bundle/hooks/stop/lib/common.sh:405-412`（值域 both|L2|L3 + 别名归一，可当唯一值域来源）；CONTEXT 已锁决策 [2026-09-29]「权威载体=prompts」「门禁依赖统一 fail-closed」真实存在；以下 DESIGN 主张均核实为真：`29-independent-review.sh:200` ||true、gate 三子库 source(:40-46) 无断言、gate :64/:65/:114 三处 `|| exit 0`、Makefile :76 非递归 vs :84 递归口径分裂、Makefile :250-258 手搓解析、`jq_atomic_write` 全仓零调用、pre-push.sh 216 行无 flock、mock `"independent"` ×72、C8-② 163/163 全重合、AC-9 = 18+6+4+3+1 = 32 自洽。

### 🔴 R1 · 真名基线文件入 tracked+分发面：AC-4/AC-5/US-3 判据数学上不可满足

**Severity**：🔴 Critical
**Symptom（症状）**：`DESIGN.md:122`（D9(b)）「真名**精确字面量集**逐字列于**常设基线文件** `reference/path-privacy-baseline.txt`」；`DESIGN.md:68`「常设落点（终局，**随包分发**不受归档影响）」且「文件自身在 SELF_EXCLUDE，防自指命中」。落点 `flow-kit-bundle/flow-kit/reference/` 为 tracked 源树（同址 check-gate-sync.sh 等皆 tracked）。
**Source（源头）**：REQUIREMENT AC-4 Then `git grep -nE '/home/<realname>' -- .` = 0（无路径豁免）；AC-5 Then 逐 blob 扫描 = 0 对象 + 全新 clone 两分支 = 0；US-3 / 安全 NFR「分发面真名 0」；AC-5 Given 自立的卫生原则「真值不入任何 tracked 文件」（push-url 仓外临时文件先例）。SELF_EXCLUDE 只遮 check-path-privacy.sh 自身，遮不住 git grep / 逐 blob 扫描。
**Consequence（后果）**：基线文件自身即含真名 → AC-4 恒 ≠0、AC-5 恒 ≥1 对象、分发 NFR 破防——本 change 的核心目标（tracked 面 0 + 历史 0 + 分发 0）被设计自身的载体选择直接否决；且随包分发把唯一真名集主动复制进每个下游安装。5-test 阶段判据即转红，被迫现场改设计。
**Remedy（修补）**：tracked 基线只存通用 PAT 定义 + 占位形态；真名字面量集走仓外（AC-5 步骤 0 同款：执行时于 `../` 生成 replace-text，用毕删除）或仅存哈希形态（每字面量一行 sha256）供对账——checker 检测用通用 PAT（:72）本就不需要真名，精确字面量仅 filter-repo replace-text 一次性需要。DESIGN D9(b) 与 REQUIREMENT AC-4/AC-5/US-3 同步修订。

### 🟡 R2 · 0.5.1 把「无 .flow-active 放行」也列入 fail-closed 转换点：与 D4 自身定义 / AC-8 / 已锁决策三重矛盾

**Severity**：🟡 Important
**Symptom（症状）**：`DESIGN.md:33`「independent-review-gate.sh（C12：**:64**/:65/:113 fail-open → fail-closed）」。实测 `:64` = `[ -f "$flow_file" ] || exit 0`（无状态文件放行；`:15` 头注释明示该契约）。而 D4（`DESIGN.md:117`）注入面仅三类（①jq 缺失 ②非法 JSON ③source 后函数缺失）——不含「文件不存在」；AC-8 Given 只写 :114/:65；CONTEXT 已锁决策 [2026-09-29] 范围 =「依赖缺失 / `.flow-active` 非法 JSON」。另 `:113` 行号漂移（实际 `:114`，REQUIREMENT 正确；`DESIGN.md:88` 对 common.sh:32-37 同类漂移已自纠，此处漏网）。
**Source（源头）**：L-031 清单字面执行风险（任务执行者按 0.5.1 触碰清单机械改行）；D4 自身三注入面定义即本条判据。
**Consequence（后果）**：按 0.5.1 字面把 :64 转 exit 2 → 所有无 `.flow-active` 的项目（全部下游项目 + flow-kit change 间空窗期）每次 Bash/Write/Edit 全阻断，产品对非 flow-kit 用户即刻不可用。连带未入触碰清单的文档契约漂移：auto-checkpoint.sh:5/:11 头注释「fail-open·不阻断」、CONTEXT 域语言表「auto-checkpoint PreToolUse 层 v1 fail-open」行。
**Remedy（修补）**：0.5.1:33 收敛为「:65/:114 fail-open→fail-closed」；:64 保留放行并加注释「无状态文件 = 非本项目管辖，放行（:15 契约）」；:113 改 :114；触碰清单补 auto-checkpoint.sh 头注释与 CONTEXT 域语言表对应行的同步更新。

### 🟡 R3 · 附录 A 检测谓词双缺口：JS 平行解析器全域免检 + 变量间接读取漏检（旗舰 hook 自身即漏检实例）

**Severity**：🟡 Important
**Symptom（症状）**：`DESIGN.md:243-245` 谓词扫描根 = `flow-kit-bundle/ Makefile test/ .claude/`，`--include` 仅 *.sh / Makefile / *.bats。实测：(a) `dsh-flow-kit/lib/{index,flow-state,l2-review}.js` 均解析 `.flow-active`，整体在扫描域外；ADR-031 全文 grep「JS|dsh-flow-kit」0 命中 = 无豁免立场；仓库根 `verify-claims.sh` 亦在域外。(b) 三分支均要求同行字面 `.flow-active`——实测 `independent-review-gate.sh:63` `flow_file="$cwd"/.flow-active` + `:65` `jq empty "$flow_file"`：字面量只在 :63 赋值行，:65 的 jq 调用行不中任何分支 → 本 change 旗舰 hook 自身免检，且 0.5.1 未要求其改调 flow-active-query.sh。
**Source（源头）**：ADR-031「单一解析入口」目标 vs 谓词实际覆盖面；D3 自陈「只认 jq 的白名单会永久放走非 jq 解析器」——同类推理适用于「只认同行字面量」与「只扫 bash 域」。
**Consequence（后果）**：守卫对最大一块平行解析面（dsh JS）与最热路径（gate 自身变量间接读取）结构性失明；「唯一解析入口」承诺不可机检；白名单「只减不增」的分母从一开始就错——内联解析可经赋值间接化绕过计数。
**Remedy（修补）**：谓词入域 `dsh-flow-kit/`（.js 等价正则），或在 ADR-031 显式豁免 JS + 理由 + 替代同步机制（预设名集合比对已有 C14-b 承接，须写明它就是 JS 侧的替代闸）；补第四分支捕获变量赋值溯源（如 `=\s*.*\.flow-active` 命中即要求登记其全部下游使用）；independent-review-gate.sh 解析改调 flow-active-query.sh 或入白名单显式登记。

### 🟡 R4 · D7/AC-15-② comm 判据永假红：两侧平凡公共行未归一化

**Severity**：🟡 Important
**Symptom（症状）**：`DESIGN.md:120` / `REQUIREMENT.md:136` 判据 = `comm -12 <(sort <权威正文段>) <(sort <载体B全文>) | wc -l` = 0，无预过滤。实测 L2-blind-review.md 163 行含 37 空行、6「重点：」行、3 ``` 栅栏；薄壳化后载体B（flow-kit-l2-reviewer.md）保留 frontmatter+触发描述+装配参数——必含空行与 `---`/``` 平凡行。
**Source（源头）**：2026-09-22 已锁决策「门禁判据必须比内容/结构，禁止只比计数」同族：本判据比的是未归一化行集，平凡行噪声使 0 不可达。
**Consequence（后果）**：判据数学上不可满足——上线即永久红（空行公共即 wc -l ≥ 1），AC-15-② 不可过；被迫现场改判据，或团队习惯性忽略红（「假红换假绿」教训重演，门禁信用流失）。
**Remedy（修补）**：两侧归一化后比较：各经 `grep -vE '^[[:space:]]*$|^---$|^\x60\x60\x60'` 过滤 + `sort -u` 再 `comm -12 … | wc -l` = 0；DESIGN D7 与 REQUIREMENT AC-15-② 同步修订（沿用本 change 已有的显式机检变更流程）。

### 🟢 R5 · SELF_EXCLUDE 三条 09b 条目指向已归档死路径

**Severity**：🟢 Minor
**Symptom（症状）**：check-path-privacy.sh:93-95 豁免 `.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-{1,2,3}.md`——实测 live 路径不存在，三文件已随归档迁至 `.specs/archive/2026-09-28-health-fix-2026-09b/`；`:84` 注释「1/2/3 原文含真实账号路径」与实测漂移（REVIEW-3 现真名行 = 0；REVIEW-1/2 命中均为无尾斜杠形态）。
**Source（源头）**：DESIGN 0.5.1:30 已认领该块改造（D8 配置化），但未处置死路径与注释。
**Consequence（后果）**：豁免对现行文件落空（幸而按 R6 ① 顺序 archive 副本先脱敏，无红窗）；死条目误导后续维护者以为豁免生效。
**Remedy（修补）**：D8 配置化时同步删改三条死路径条目与 :84 注释（指向 archive 实址，或随 AC-4 脱敏完成直接移除豁免）。

### 🟢 R6 · 预设名第五载体 FLOW-KIT-用户指南.md 未入集合比对

**Severity**：🟢 Minor
**Symptom（症状）**：`DESIGN.md:218` 四载体 = SKILL/bats/dsh JS/gate-helpers.sh:26。grep `design-review` 实测另命中 FLOW-KIT-用户指南.md（分发面用户文档，枚举预设名）。
**Source（源头）**：C14-b 漂移检测完整性——第五载体是同名值域消费方。
**Consequence（后果）**：预设增删时用户指南静默漂移（用户面口径与实际不符），门禁不拦。
**Remedy（修补）**：§9.3 集合比对扩为五载体，或在 check-gate-sync 对指南做同款名集合断言；亦可显式豁免 + 理由登记。

### 🟢 R7 · check-skills-sync 配对映射未定死：@see 派生配对检测不了置换错配

**Severity**：🟢 Minor
**Symptom（症状）**：D5 / `DESIGN.md:217` 定「全对齐 + @see 锚点可解析 + 未配对须豁免」，但 14 对配对关系本身（flow-intel↔I-intel-scan.md、flow-ui-design↔2a-ui-design.md 等非字面对应）无常权威表；薄壳化后载体零内容，判据仅剩结构。
**Source（源头）**：2026-09-22 锁策「先锁唯一语义源」——配对关系是 skills↔prompts 的语义源之一，未锁。
**Consequence（后果）**：置换错配（skill A 的 @see 指向 prompt B）在「全对齐 + 锚点可解析」判据下不可检——恰是 C13 要拦的路由漂移形态之一。
**Remedy（修补）**：TASK 定死映射：SKILL frontmatter 自声明 `prompt: <file>`（或 check-skills-sync 内置 14 对表并断言 @see 目标与表一致）；反向用例：交换两 @see 目标必红。

### 🟢 R8 · 29-independent-review.sh 其余 ||true 未 triage

**Severity**：🟢 Minor
**Symptom（症状）**：D6 只修 :200；同文件实测另有 :96,:97,:159,:214,:220,:232,:237,:250,:273,:281,:297,:304,:313 处 ||true，其中 :237 `l2_dispatch_prompt … || true` 与 C4 同类（吞 L2 派发失败）。
**Source（源头）**：C4 的机理（静默吞失败）适用于所有同类位点；DESIGN 未给「留 / 修 / v2」triage 清单。
**Consequence（后果）**：下一轮巡检大概率再报 C4 同类项（返工循环）。
**Remedy（修补）**：DESIGN 或 TASK 附逐位点 triage（有意·Stop 链韧性 / 同类须修 / v2）；:237 建议同批改前置捕获 + warning。

**Verdict**: fail

---

## 主 agent 响应（阶段 2 · 对 L2 重审 · 2026-09-29）

**R1（🔴）Fixed in**：DESIGN.md:68 常设落点行 + :122 D9(b) 重写——tracked 基线 `reference/path-privacy-baseline.txt` 只存通用 PAT + 占位形态 + sha256 哈希对账行，**真名明文零 tracked**；filter-repo replace-text 运行时仓外组装（`git remote get-url origin` + `$HOME`/`pwd` 派生 → `../scrub-literals.tmp` → 用毕删除，AC-5 步骤 ⓪ 同款先例）；备选②「真名明文入 tracked 基线」写入被否决项并注明 R1 论据（SELF_EXCLUDE 只遮自检，遮不住 git grep/逐 blob/分发面）。
**R2（🟡）Fixed in**：DESIGN §0.5.1 gate 条目收敛为 **:65/:114** fail-open→fail-closed；**:64 保留放行**并补注释固化「无状态文件 = 非管辖」（:15 头注释契约）——转 exit 2 会阻断所有非 flow-kit 项目；:113→:114 行号核正；新增 auto-checkpoint.sh 0.5.1 条目（头注释 :5/:11 同步改写 + CONTEXT 域语言表行 7-integration 落）。
**R3（🟡）Fixed in**：附录 A 谓词重写——扫描根入域 `dsh-flow-kit/`（.js）+ 根 `*.sh`（verify-claims.sh）；新增分支④变量间接（赋值 `X="….flow-active"` 命中 → 下游 $X 读取同辖）；ADR-031 新增决策 4（JS 入域不豁免：存量三文件白名单登记 + 替代闸 = 五载体集合比对 + hook-bridge 长期整改挂 TD v2）；`independent-review-gate.sh:63-65` 变量间接读取列入 D3 **必须改调清单**（不进白名单，旗舰 hook 不自免检）。
**R4（🟡）Fixed in**：D7 与 REQUIREMENT AC-15-② 同步加归一化——两侧各经 `grep -vE '^[[:space:]]*$\|^---$\|^```'` 滤平凡行 + `sort -u` 再 comm -12 = 0；对账标注双记（L3 阶段 2 + L2 重审 R4）。
**R5-R8（🟢）deferred**：M4（09b 死路径条目，D8 同批）/ M5（预设名第五载体用户指南——§9.3 已顺手改五载体表述，断言 TASK 承接）/ M6（14 对配对映射权威表 + 置换反向用例）/ M7（其余 ||true 逐位点 triage，:237 建议同批）→ 全部落 MINOR-DEFERRED.md。
---
## L2 盲审（重审 · 第 3 轮 · 2026-09-29）

**Verdict**: pass（0 🔴 / 5 🟡 / 3 🟢；R1–R5 入 fix loop，R6–R8 转 MINOR-DEFERRED）。独立性声明：本轮输入未含主 agent 自评；DESIGN 内 5 处「L2 重审 R<N> 修订 2026-09-29」标注（:69/:117/:121/:123/:219/:241）已按防锚定条款逐条独立核验技术内容后采信（见下「实证通过面」），非因标注放行。

### 实证通过面（第 3 轮独立抽核，无发现）
- 行号/机制全部命中：check-gate-sync.sh `check_gate_config_sync()`:190、`PAIRS_TOTAL=14`:44；check-path-privacy.sh PAT≈:72、SELF_EXCLUDE 6 路径 :89-95（4×09b 行）、ALLOWLIST_CHANGE:102；29-independent-review.sh:200 `|| true`；auto-checkpoint.sh:64；independent-review-gate.sh :63 `flow_file` 赋值 / :64 存在性放行 / :65 `jq empty` / :114 jq 依赖；common.sh `jq_atomic_write`:192（全仓 0 调用者，死代码删除确认）、依赖断言范式 :226、`fk_normalize_gate_val`:405；gate-helpers.sh:26 + :29-30 case；Makefile:250-253 手搓（while/read/case）；package-dsh-plugin.sh:233 `node --test`；install_hooks.sh:187-194；pre-push.sh 全文无 flock ✓。
- 计数基线：test_gate_config_presets.bats `"independent"`=72（双源一致，AC-7 判据 72→0 有鉴别力）；prompts=14 / skills/flow-*=16（−2 豁免=14 对自洽）；CONTEXT `^| TD-`=132（AC-14 精确）；L2-blind-review.md=163 行 / flow-kit-l2-reviewer.md=198 行含复制段（D7 事实准确）。
- 架构对齐：flow-active-query.sh 落 `flow-kit-bundle/lib/`（非 reference/）不撞 ARCHITECTURE §2.2 禁止方向；Makefile 既有 `@bash reference/check-*.sh` 调用形态（:118/:127）与 ADR-030 豁免一致；JS 存量三文件实测 = dsh-flow-kit/lib/{index,flow-state,l2-review}.js；变量间接赋值分支实测命中生产 shell 14 处；R5 覆盖历史重写风险（bundle 备份+verify+净树前置）、R6 四条波次偏序显式。

### R1 · L-031 更名触点漏列：check-gate-sync→check-skills-sync 有三组文件不在 §0.5.1
**Severity**：🟡 Important
**Symptom（症状）**：全仓锚点扫描（`grep -rln 'check-gate-sync'`，剔除 .specs 账本/归档）命中而 DESIGN §0.5.1 未列：① `test/test_quality_baseline.bats:26,29-30,34-35`（+bundle 镜像）——`test -x …/check-gate-sync.sh` 与直接 `bash` 运行两类用例，更名后必红；② `FLOW-KIT-用户指南.md:1585` + bundle 副本——指名「并由 flow-kit/reference/check-gate-sync.sh 守护」；③ `flow-kit-bundle/flow-kit/reference/pipeline-gates.md:4`——「改完后运行 check-gate-sync.sh」。Makefile 已列（OK）。
**Source（源头）**：L-031 通用必查项（触点清单不信自报、独立全仓扫描）；AC-11 自身「载体修订对账」要求。
**Consequence（后果）**：TASK 按 §0.5.1 执行 → quality_baseline 改名后 `make test` 必红（AC-13 打断、返工一轮）；用户指南/pipeline-gates 成静默陈旧引用，无门禁捕捉（pipeline-gates 已是 TD-030 伪单一源，雪上加霜）。
**Remedy（修补）**：§0.5.1 测试面补 `test_quality_baseline.bats`（双源）、分发/docs 面补两份 `FLOW-KIT-用户指南.md` 与 `pipeline-gates.md`；TASK 增对应任务：quality_baseline 断言改新名、指南与 pipeline-gates 更名引用。

### R2 · AC-15-① 子判据恒真：'#7 bats' 全仓 0 命中，验不出「删内联表」
**Severity**：🟡 Important
**Symptom（症状）**：REQUIREMENT AC-15-① 判据 `grep -c '#7 bats' 4-dev.md = 0`——实测当前 flow-kit-bundle/ + test/ + Makefile 全仓 0 命中；而 4-dev.md:98-106 的 toll-gate 自检表（8 行，含 `| 7 | **1.8 触发时 bats 已跑且 0 fail**（L-010）`）是 markdown 表行格式，锚串与表内实存文本不对应。
**Source（源头）**：CONTEXT 已锁 L-090（AC 写时实跑确认修复前不成立）；TD-073（判据非判别性同族）。
**Consequence（后果）**：「4-dev.md:99-106 删内联表」半个 AC 无机检保护——删与不删判据同绿，TASK 判据块空转。
**Remedy（修补）**：AC-15-① 锚串改为表内实存文本：`grep -c '1.8 触发时 bats' flow-kit-bundle/flow-kit/prompts/4-dev.md = 0`（实测当前=1，删表后=0，恢复鉴别力）。

### R3 · AC-15-③ 判据=1 不可达：测试文件 2 处字面量未列去字面化动作
**Severity**：🟡 Important
**Symptom（症状）**：`grep -rn 'L2-first 契约未满足' flow-kit-bundle/ | wc -l` 当前=4（生产 29-independent-review.sh:138,:239 + 测试 test-l2-first-correction.bats:55,:56）。C8-③ 抽取 `_l2_first_deny()` 后生产 2→1，但测试两处字面量（@test 标题 + `grep -q 'deny reason: L2-first 契约未满足' "$HOOK_29"`）无任何条目要求同步处理 → 恒=3≠1。
**Source（源头）**：L-090；L-137（判据/探针字面量按拼接构造的既定定式）。
**Consequence（后果）**：TASK 仅做生产抽取则 AC-15-③ 恒红；执行者为凑 =1 可能误改生产文案或弱化测试断言（两个都是错修）。
**Remedy（修补）**：REQUIREMENT AC-15-③ 或 DESIGN C8-③ 显式注明 test-l2-first-correction.bats:55-56 同批改拼接构造（如 `'L2-first ''契约未满足'`），判据旁注基线构成 4→1（生产 2→1 + 测试 2→0）。

### R4 · 已锁决策推翻未沉淀：main 清理从 v2 提前到本 change v1，§9.2 无记录
**Severity**：🟡 Important
**Symptom（症状）**：CONTEXT.md 已锁决策 [2026-09-22]「本地 main 暂不清理只加 push 拦截（权威验证 8→0 归 v2，禁止当 bug 重报）」；REQUIREMENT AC-5 ②孤儿 main 单独重写 + ⑤强推两分支 + 逐 blob=0；DESIGN §9.2 沉淀表仅四行（门禁失败语义/reference 定位/权威载体/skill→prompt 直引），无一行记录此范围推翻；DESIGN 全文 grep 无「推翻/解锁/暂不清理」。
**Source（源头）**：CONTEXT 已锁决策段是决策账本权威；TD-041（账本失真是 ADR-027 编号事故同类土壤）；固化指令阶段 2 重点「是否撞既有已锁决策」。
**Consequence（后果）**：A-evolve 按 §9.2 沉淀时不追加推翻记录 → 阶段 6/7 复审或后续 agent 按 CONTEXT 旧锁判 AC-5 行为违规（「禁止当 bug 重报」字面冲突），无据可依地踩刹车。
**Remedy（修补）**：§9.2 增一行「main 历史清理：09c v1 提前落地（AC-5），显式推翻 2026-09-22『归 v2』锁，依据=阶段 1 REQUIREMENT 定稿」；7-integration 同步 CONTEXT 已锁段。

### R5 · AC-12-g Makefile 子判据恒真 + 基线数字「28」自相矛盾
**Severity**：🟡 Important
**Symptom（症状）**：① `grep -c 'jq .*\.flow-active' Makefile` 实测当前=0——:250-253 手搓解析是 while/read/case 形态本就无 jq 字样，D3 改调前后同值，对改调点零鉴别力（Makefile 实存 `.flow-active` 字面量 3 处：:250/:251/:264）；② AC-12-g 判值「生产 .sh 收敛白名单基线 28 文件」恰是 ADR-031 自己声明不可直接用的人工判读口径（「宽松 grep=43、人工判读 28 均不可直接用，TASK 以附录 A 严格谓词重建」）——重算若≠28，AC-12-g 按字面恒红或被迫凑数。
**Source（源头）**：L-090；D3 自述「只认 jq 的白名单会永久放走非 jq 解析器」——同一盲区在 AC-12-g 机检复现；ADR-031 决策 3。
**Consequence（后果）**：Makefile 改调没做也绿、回归重植手搓解析同样绿；白名单条目数与 28 不符时 AC 判据失真。
**Remedy（修补）**：AC-12-g 增正向断言 `grep -c 'flow-active-query' Makefile ≥ 1`（或 `grep -cE '\[ -f \.flow-active \]|done < \.flow-active' Makefile = 0`，实测当前=2）；判值改为「以附录 A 严格谓词重建并登记于常设白名单文件的条目数 N 为准（DESIGN 定稿时回填 N）」。

### R6 · 双「唯一解析入口」并存未声明边界：fk_resolve_phase vs flow-active-query.sh
**Severity**：🟢 Minor
**Symptom（症状）**：CONTEXT 已锁 [2026-07-01] phase 检测统一入口 `fk_resolve_phase()`（common.sh，hook 链内）；D3/ADR-031 立 flow-active-query.sh 为 .flow-active 唯一解析入口（lib/，Makefile/生产脚本）。DESIGN 仅 :89 行号引用 fk_resolve_phase，未声明两者管辖边界；§9.3 新增禁动「.flow-active 的读取必须经 flow-active-query.sh（白名单文件除外）」按字面覆盖 fk_resolve_phase 自身（靠白名单机制消解，未言明）。
**Source（源头）**：Ousterhout《A Philosophy of Software Design》深模块单入口原则；CONTEXT 已锁决策段。
**Consequence（后果）**：schema 演进存在双权威改点；后续读者/审查无法判断 hook 链内该调谁，易误改其一。
**Remedy（修补）**：ADR-031 或 §9.3 补一句：「hook 链内 phase 解析维持 fk_resolve_phase（common.sh，白名单登记）；链外脚本/Makefile 一律 flow-active-query.sh」。

### R7 · ARCHITECTURE §3 ADR 编号账本滞后未入沉淀面
**Severity**：🟢 Minor
**Symptom（症状）**：ARCHITECTURE.md §3 声明「当前 ADR 编号最大值 ADR-027」（2026-09-21 更正口径）；本 change 新增 ADR-030/031/032（09b 的 028/029 亦未回填）；DESIGN §0.5.1 specs 面只登记 ARCHITECTURE §2.2 增补行，§9.2 无 ADR 索引更新行。
**Source（源头）**：TD-041（ADR-027 编号事故根因=「依据过期的最大编号声明」）。
**Consequence（后果）**：下一个 ADR 继续依据过期声明取号 → 撞号事故风险复发。
**Remedy（修补）**：§9.2/A-evolve 清单增「ARCHITECTURE §3 ADR 编号最大值更正（027→032，含 028/029 追认）」。

### R8 · AC-9 残留白名单机检只覆盖单引号 $content 形态（2/32 位点）
**Severity**：🟢 Minor
**Symptom（症状）**：`grep -rn "grep -q '.*\$content" test/*.bats` 实测当前=2（test_l3_review_defects_2026_09.bats:726,:728 单引号形态）；同文件 :1241 双引号形态（`grep -q "_gate_path_guard …\$content…"`）及 test_fix_l3_gate/test_dual_review_merge/test_l3_lifecycle_wiring 的 C6 位点（grep -q 与 content 共现=0）均不在该 pattern 检测内；AC-9 Given 称 32 处/5 文件。
**Source（源头）**：TD-073（判据非判别性）；AC-9「白名单即该注释本身，无主观裁量」的完备性主张与实际覆盖面不符。
**Consequence（后果）**：双引号族文本断言残留或日后回归时残留机检恒绿（当前 2≠0 尚有部分鉴别力，故仅 Minor）。
**Remedy（修补）**：判据 pattern 放宽到双引号族（如 `grep -rnE "grep -q ['\"].*\\\$content" test/*.bats`），或按 C6 的 32 处清单做「改后文本断言计数=0」位点对账。

**Verdict**: pass

---

## 主 agent 响应（阶段 2 · 对 L2 三审 · 2026-09-29）

**Verdict=pass 收讫；R1-R5（🟡）全部 Fixed in，R6-R8（🟢）deferred 至 MINOR-DEFERRED.md（M8-M10）。**

- **R1 Fixed in**：DESIGN §0.5.1 新增「更名触点」组——test_quality_baseline.bats:26,29-30,34-35（+bundle 镜像，TASK 同批改断言目标：预设名断言归 check-skills-sync / 运行断言归 check-gate-sync）、FLOW-KIT-用户指南.md:1585（+bundle 副本）、pipeline-gates.md:4（只改引用不加承诺，TD-030 存量不动）。
- **R2 Fixed in**：REQUIREMENT AC-15-① 机检锚改 `grep -c '1\.8 触发时 bats' 4-dev.md`（当前=1 → 删表后=0），对账标注「L2 三审 R2」；原 `'#7 bats'` 恒绿锚作废注明。
- **R3 Fixed in**：REQUIREMENT AC-15-③ 显式注明基线构成（当前=4：生产 :138/:239 ×2 + 测试 :55-56 ×2）与同批测试字面量拼接构造化（`'L2-first ''契约未满足'`），生产 2→1 + 测试 2→0 = 1 可达。
- **R4 Fixed in**：DESIGN §9.2 沉淀表新增「main 历史清理提前到 v1」行——显式推翻 [2026-09-22] 锁、依据 = 阶段 1 REQUIREMENT 定稿、7-integration 同步 CONTEXT（旧锁不删加注）。
- **R5 Fixed in**：REQUIREMENT AC-12-g 改双锚（`grep -cE 'done < \.flow-active|\[ -f \.flow-active \]' Makefile` = 0，当前=2；正向 `grep -c 'flow-active-query' Makefile` ≥ 1）+ 基线口径改「附录 A 严格谓词重建后回填 N」（43/28 均不可直接用，ADR-031 决策 3 引用）。
- **R6-R8 deferred**：M8（fk_resolve_phase vs flow-active-query 边界一句，ADR-031 落地批）/ M9（ARCHITECTURE §3 ADR 最大值 027→032，7-integration 与 M3 同批）/ M10（AC-9 pattern 双引号族放宽，TEST 派生时）→ MINOR-DEFERRED.md。

---

## L3 重审（deepseek-v4-flash-0731 外部模型 · 2026-09-30 00:01）

> 自动生成于 2026-09-30 00:01。由 l3-review.sh 写入。

### 审查结论

```json
{
  "critical": [
    {
      "file": "DESIGN.md:122 (D9(b))",
      "issue": "D9(b) 要求真名精确字面量集逐字列于常设基线文件 path-privacy-baseline.txt（文中称“每字面量一行 sha256 哈希对账行”），但 AC-4/AC-5/US-3 要求真名零 tracked；哈希对账行本身就是真名精确字面量的可逆映射，grep -F 无法匹配，门禁判据与基线内容在数学上不可同时满足。",
      "why": "若基线只存哈希，则 check-path-privacy 无法用字面量比对拦截真名；若基线存真名，则 tracked 面真名不为 0。文中“只存通用 PAT + 占位形态 + 哈希对账行”使 AC-4/AC-5/US-3 判据不可判定，TASK 无法实现。",
      "fix": "将 AC-4/AC-5 的判据改为“允许基线内含真名，但基线文件本身列入 scrubbing/replace-text 处理范围并在最终 tracked 快照中清零”；或将 AC 判据改为“真名仅允许出现于 baseline 文件，其余 tracked 文件为 0”，并删除无法机检的哈希对账行或明确定义哈希行的验证用途。"
    }
  ],
  "major": [
    {
      "file": "DESIGN.md:33 / independent-review-gate.sh 改造点 (D4/C12)",
      "issue": "设计正文与自身决策冲突：D4/ADR-032 声称统一 fail-closed，但独立审查门禁 :64 保留 `[ -f \"$flow_file\" ] || exit 0`，并将该行为解释为“非 flow-kit 项目管辖契约”；同时 0.5.1 又要求 :42-46 source 三子库后补 declare -f 断言并 exit 2。",
      "why": "若“无状态文件=非管辖”是契约，则所有 PreToolUse 注入在无 flow 文件时仍整体 fail-open，与 AC-8/AC-12/D4 的 fail-closed 声明不一致；若必须 fail-closed，则保留 exit 0 是同一注入面的漏网。该决策在文本内无法自洽。",
      "fix": "将无状态文件的语义显式写入 REQUIREMENT/AC-8 判据（如“无 .flow-active = skip，不视为依赖缺失”），或在独立审查门禁同样改为 exit 2；二选一并删除“fail-closed 统一”的绝对化表述。"
    },
    {
      "file": "DESIGN.md:243-245 (附录 A 分支 ④) 与 ADR-031",
      "issue": "变量间接读取的检测谓词把 `X=\"….flow-active\"` 的赋值行命中当作“该变量全部下游读取同受辖”，但 grep 只查赋值行，不查 `$X` 的实际读取调用；若赋值行拆行、拼接、或经函数参数传递，则漏检。",
      "why": "旗舰 hook 自身 `flow_file=\"$cwd\"/.flow-active` + `jq empty \"$flow_file\"` 正是该模式，而谓词只登记赋值行，未登记 `jq … \"$flow_file\"` 使用行；这说明谓词自实例即漏检，白名单计数不可复现。",
      "fix": "谓词增加对变量使用点的跟踪（如 grep `\\$flow_file`/`${flow_file}` 的使用行并纳入白名单条目），或将分支 ④ 改为“对每个 .flow-active 赋值变量，grep 该变量全部下游引用，任何引用未走 flow-active-query.sh 即 rc≠0”。"
    },
    {
      "file": "DESIGN.md:120 (D7) 与 AC-15-②",
      "issue": "D7 将机检判据改为“各自 grep -vE '^[[:space:]]*$|^---$|^```' + sort -u + comm -12 | wc -l = 0”，但未说明该判据如何覆盖两侧的“差异化说明/装配参数”私有内容，也未说明如何防止平凡公共行换形（如带缩进、尾随空格、不同代码块标记）逃逸归一化。",
      "why": "原文只排除空行/`---`/代码栅栏，而 4-dev 与 6-review 等大量正文使用列表、表格、标题、`重点：` 行；若两侧同义异写（如“重点：X”vs“重点: X”），sort -u 后仍不相等则判红，若完全相同则任何正文改动的同步性无法验证；判据不可稳定机检。",
      "fix": "将比较判据改为“两侧规范化后 diff 中，仅允许差异行属于差异化说明/装配参数白名单”；或改为“@see 锚点存在 + 目标文件标题/行锚命中 + 抽查 N 个关键段存在”，放弃整文件 comm 判据。"
    },
    {
      "file": "DESIGN.md:9.3 / D8",
      "issue": "D8 引入 `package-dsh-plugin.sh --check`（内含 node --test）挂入 make check，但只定义“缺 node 时 rc≠0”，未定义 make check 聚合时该 rc 与其它检查器的关系；若 make check 直接以先决条件聚合，非零即 fail 是符合 fail-closed 的，但 R8 又要求“显式提示而非静默”，未说明输出通道。",
      "why": "R8 的缓解是“rc≠0 + 显式提示”，但 make check 目标若继续用既有先决条件聚合，则任何无 node 环境都永久红，撞 ADR-027②“长期红=被绕过”；若改用 if/警告不阻塞，则与 fail-closed 语义冲突。设计未钉死聚合语义。",
      "fix": "在 DESIGN 中明确 make check 的 JS 环节聚合方式：无 node 时 `make check` 返回非零并打印 install 指引（fail-closed），或在 Makefile 中按 ADR-028 三态显式区分 SKIP=3 且不挂 check: 先决条件，二选一并写进 D8/R8。"
    }
  ],
  "minor": [
    {
      "file": "DESIGN.md:0.5.3",
      "issue": "“基线管理：引入新模式 → path-privacy 基线从硬编码路径改为 .specs/health-fix-2026-09c/ 下文件”，但正文随后又改为常设 reference/path-privacy-baseline.txt，两处描述不一致。",
      "why": "0.5.3 与 D9(b)/常设落点段矛盾，TASK 可能按 0.5.3 落 change 目录导致归档后门禁失效（ADR-028 已实证）。",
      "fix": "统一为“常设 reference/ 路径 + change 目录仅种子副本”，修改 0.5.3 对应行。"
    },
    {
      "file": "DESIGN.md:5 R6",
      "issue": "执行顺序风险提到 C13 薄壳化先于 check-skills-sync 上线会“窗口内漂移无人拦”，但未提 check-skills-sync 自身与 ADR-030 豁免、reference 定位的落地顺序（豁免行写入 ARCHITECTURE 与门禁上线谁先谁后）。",
      "why": "若门禁先上线而 ARCHITECTURE §2.2 增补未落，门禁本身违例；若增补先落而门禁未上线，则豁免无执行者。这是 ADR 决策与 7-integration 的时序依赖。",
      "fix": "在 R6 或 TASK 波次中补“ADR-030 的 ARCHITECTURE 增补行与 check-skills-sync 同 wave 或先于门禁”。"
    },
    {
      "file": "DESIGN.md:附录 A 条目格式",
      "issue": "白名单条目格式为 `<path>:<line>:<content>` + 理由行，但 grep -vF 是字面匹配，若同一行内容因格式漂移（空格/缩进）与 grep 输出不一致，白名单失效导致误红。",
      "why": "行内容精确匹配脆弱，新增同一行号但内容不同的匹配会被当作新命中；这是实现噪音，非设计决策。",
      "fix": "指定按 `path:line` 匹配并附加 `grep -F` 内容校验（内容不匹配时 fail-closed 报“白名单条目漂移”），或直接用 path:line 作为匹配键。"
    },
    {
      "file": "DESIGN.md:D1 / ADR-030",
      "issue": "“数据化解析边界”规定检查器用文本提取生产 .sh 的契约，但未定义提取失败（如锚点注释被删）时检查器的具体输出形式（只要求 rc=1），也未定义锚点注释的命名规范。",
      "why": "R2 缓解只说了“Fail-closed 不误绿”，但 AC 的可追溯性要求（Given/Then）需要明确的失败信息，否则 TASK 无法写断言。",
      "fix": "补一句“提取失败输出 `check-gate-sync: contract anchor missing at <file>:<line>` 并 rc=1；锚点注释统一前缀 `# contract:`”。"
    },
    {
      "file": "DESIGN.md:D4 / ADR-032 决策 1",
      "issue": "“函数遮蔽/重定义为空体”显式移出注入面，但未说明检测手段（如 `declare -f` 只证存在）之外的替代控制或登记路径，等于承认该注入面无门禁。",
      "why": "遮蔽是现实攻击面（PATH/别名/环境函数注入），设计只说不承诺，未给 mitigation；至少应登记 TD 或加安装期校验。",
      "fix": "在 D4/ADR-032 中补“遮蔽注入面登记 TD-xxx v2 处理”，或加安装期对关键函数 SHA/内容断言（安装后只读校验）。"
    }
  ],
  "verdict": "fail",
  "summary": "D9(b) 的“哈希对账行基线”与真名零 tracked 判据不可同时满足，且独立审查门禁保留 exit 0 与统一 fail-closed 自相矛盾，存在两个 critical，设计不可照单实现。"
}
```

L3_artifact_hash: 76b3e30435d3a90db139ec6029da3e9aa2ad3c01ebf45af08e5566f5f6244cea

<!-- /L3-SECTION -->
