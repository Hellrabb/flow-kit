# 独立审查 · 阶段 2

> 本文件含两层独立审查：L2（architect-reviewer 子 agent 盲审）+ L3（glm-4.7 外部模型盲审）。
> L2 审查**修订后**的 DESIGN（2026-07-02 两层时机版）；L3 段为**修订前** DESIGN 的审查（verdict=fail），其 findings 已在修订中闭环，保留作历史审计链。

---

## L2 盲审（architect-reviewer 子 agent · 独立盲审修订后 DESIGN · 2026-07-02）

> 主 agent 原样注入 `@flow-kit/prompts/independent/L2-blind-review.md` 固化指令 + 审查参数，未附任何主 agent 自评 / 修订说明 / L3 结论。以下为子 agent 原文，主 agent 无权改写。

# L2 盲审报告 · gate-integrity · 阶段 2（设计）

**审查对象**：`/home/hellrabbit/unisoc/flow-kit/.specs/gate-integrity/DESIGN.md` + ADR G1/G2/G4
**参考**：`/home/hellrabbit/unisoc/flow-kit/.specs/CONTEXT.md`、`REQUIREMENT.md`、`CHANGE.md`、既有代码（`independent-review-gate.sh` / `29-independent-review.sh` / `flow-kit-artifacts.sh`）
**盲审范围**：阶段 2 checklist（ADR 合理性、跨模块契约冲突、抽象层次、风险段遗漏）
**方法**：只读工件本身 + 对照既有代码 grep 实证；不接受设计文档自述。

---

### 🔴 R1 · D6「case 单一源」为伪命题：阶段判定与 phase_name 映射在 3+2 处重复硬编码，DESIGN 未识别真实耦合面

**Symptom（症状）**：DESIGN.md L77 D6 自述「case 语句存于 `independent-review-gate.sh` 代码（**单一源**，非配置文件 / 非 `aliases` 键）」。但 grep 既有代码实证：
- 阶段正则 `^(1|2|6)$` **硬编码在 3 处**：`flow-kit-artifacts.sh:109` / `29-independent-review.sh:33` / `independent-review-gate.sh:39`
- `case phase→phase_name` 映射**重复在 2 处**：`flow-kit-artifacts.sh:117-119` + `independent-review-gate.sh:58-60`

ADR-G2 Decision#1 也只提「case 映射存于 `independent-review-gate.sh`」，**完全没提** `flow-kit-artifacts.sh` 内的镜像副本。AC-3 Then#2 只点名 `independent-review-gate.sh:39` + `:57-60` 要改，同样**遗漏 `flow-kit-artifacts.sh:109/117-119`**。

**Source（源头）**：DRY / SSOT（Don't Repeat Yourself）。同一阶段集合在 3 处定义、同一 phase_name 映射在 2 处定义，必漂移。CONTEXT.md「已锁决策 [2026-07-01] Q1 防线定在 hook 层」也要求 hook 层一致性。

**Consequence（后果）**：本 change 落地时若只改 `independent-review-gate.sh` 一处（按 D6 字面执行），`flow-kit-artifacts.sh::fk_independent_review_gate_active` 仍 `[[ "$phase" =~ ^(1|2|6)$ ]] || return 1`——3/5/7 阶段在 L3 Stop hook 入口（`29 号` 通过 `fk_independent_review_gate_active`）和 `fk_auto_phase` 自动推进判定中**直接 return 1 放行**，gate 形同虚设。这是**实质性的 AC-3 未实现**，而非「同一处改两遍」的便利问题。DESIGN 把多源误标成「单一源」，掩盖了需要同步修改的真实位置数。

**Remedy（修补）**：
1. DESIGN.md D6 改述为：「`case phase→phase_name` 映射在 `independent-review-gate.sh` 与 `flow-kit-artifacts.sh` **两处镜像**，阶段判定正则在 3 处镜像，本 change 同步扩到全 6 阶段」——诚实标注真实耦合面。
2. AC-3 Then#2 显式补上「`flow-kit-artifacts.sh:109` 正则 + `:117-119` case 同步扩 3/5/7」，否则 TEST 阶段派生的用例会漏覆盖。
3. R1 缓解「bats 断言三处都调 `fk_validate_done_marker`」**与此无关**——R1 防的是「done 校验三处不闭环」，不是「阶段判定/映射多源」。两者不可混为一谈，DESIGN 风险段对多源漂移零提及。

---

### 🔴 R2 · AC-1 威胁③④⑤「v1 不完全挡」与 REQUIREMENT 范围锁定直接冲突，DESIGN 单方面缩小了合同

**Symptom（症状）**：
- REQUIREMENT.md L70「v1（本次必做）」明列「AC-1 .done 真实性（基础判定：写入者 / transcript 边界区分，**主 agent 自产一律拒**）」——即威胁③（本会话主 agent 自产）v1 **必须完全挡**。
- REQUIREMENT.md L82「v2」明列「`.done` 真实性的加密签名 / 内容哈希强化（**v1 基础判定必做，不整体降级**）」——即 v1 必须做基础判定，加密才降级 v2。
- 但 ADR-G1 Decision#4 + Consequences 写「威胁③（本会话主 agent 自产）v1 **不完全挡**」；DESIGN.md D5 + R5 + L135 三处重复「威胁③⑤ v1 均未完全挡，只提高成本」。

DESIGN 把 AC-1 威胁③④⑤ 中③的整体防御降级成「成本提升」，**这违反 REQUIREMENT v1 范围「主 agent 自产一律拒」**。威胁③是 CHANGE.md L17「agent 可不触发、或触发后自己写 `.done`」原始诉求的核心场景——agent 用 Write 自己写 `.done`（不派子 agent）正是本 change 要堵的头号洞。DESIGN 现方案 v1 对此只做「多文件交叉成本提升」，agent 写完 `.done` 再写一份 `.md` L2 段 + 写一份 `.flow-active.independent-review` 握手即可绕过——三处都是主 agent **同会话内可写**的文件，无外部不可伪造锚点。

**Source（源头）**：范围合同。DESIGN 阶段无权单方面把 REQUIREMENT v1 必做项降级为「v1 不完全挡，留 v2」。REQUIREMENT 风险段 L103 已规定「若 DESIGN 验证发现不可区分，AC-1 **block 不退化**（**不**降级为静态字段校验），此时需回 REQUIREMENT 重定义 AC-1」——DESIGN 既已实测 SESSION_ID 会话级共享不可区分子/主，正确流程是**回 REQUIREMENT 重新定义 AC-1 的可验证信号**，而非在 DESIGN 单边缩合同。

**Consequence（后果）**：本 change 落地后声称「挡 5 类威胁」，实际威胁③在 v1 仍可由主 agent 自产三文件绕过。这是**安全门禁的安全宣告 vs 实际防御落差**——用户/后续维护者读到「挡 5 类」会信任它，但 agent 一旦发现成本只是「多写两个文件」，gate 等于没加。且因为 DESIGN 把退化当成既成事实（「Gate 不声称防御③⑤」），REVIEW/INTEGRATION 阶段不会触发回归——缺陷被制度化掩盖。

**Remedy（修补）**：二选一，**不可继续维持现状**：
- 方案 A（守 v1 合同）：DESIGN 必须找到 agent **无法伪造**的外部锚点挡威胁③。候选：① transcript 工具调用历史（hook 可读 stdin/CC transcript，主 agent Write `.done` 时若 transcript 中无对应子 agent Task 调用 → 拒）；② Stop hook 写握手而非主 agent 自写（`.flow-active.independent-review` 由 29 号写，主 agent Write 该文件被 PreToolUse 拦）；③ 加密签名（v1 内置最小实现）。DESIGN 需明确指出选哪个 + 为什么 v1 可行。
- 方案 B（回 REQUIREMENT 重定义）：按 REQUIREMENT L103 既定流程，回 REQUIREMENT 把 AC-1 威胁③「主 agent 自产一律拒」重新定义为可验证信号（如「`.done` 须含 29 号 Stop hook 不可伪造的 token」），并在 v1 范围内落地。
现状（DESIGN 单边缩合同 + 「不声称」声明）= AC-1 部分未实现 + 合规风险。

---

### 🟡 R3 · D3「三层解析」决策的取舍代价被低估，①③ 双源漂移检测机制 check-gate-sync.sh 现状未被验证可承担新职责

**Symptom（症状）**：D3（L74）方案：① `/flow` skill 按 `SKILL.md` 的 `PRESET_MAP` 解析用户输入写 `gate_config`，③ `test_gate_config_presets.bats::resolve_gate_config()` 镜像 ① 的逻辑供测试，`check-gate-sync.sh` 断言 SKILL.md 预设名集合 ↔ bats 镜像一致。取舍代价标注「①③ 双源需人工同步（R4）」。

但 DESIGN/ADR-G4 都**未验证** `check-gate-sync.sh` 现状能承担「预设名集合 ↔ bats 镜像一致性」断言。grep CONTEXT.md「check-gate-sync.sh」定义（L96）=「diff prompt 和 skill 的 toll-gate 段，不一致时报错」——它当前 diff 的是 **prompt ↔ skill 的 toll-gate 文本段**，**不是**「SKILL.md PRESET_MAP 名集合 ↔ bats 镜像 resolve_gate_config() 输出」。现有脚本的 diff 粒度（文本段）与新增需求（语义一致性：预设名集合一致）**模型不同**，DESIGN 假设它能直接扩展。

**Source（源头）**：YAGNI 反例 / 决策前未验证承载能力。CONTEXT.md「check-gate-sync.sh」定义明确其当前职责，DESIGN 假定扩展而未给扩展规格。

**Consequence（后果）**：若 `check-gate-sync.sh` 实际只做文本段 diff（如 `diff <(sed -n '..' SKILL.md) <(sed -n '..' prompt)`），它**无法**检测「PRESET_MAP 加了 `all` 但 bats 镜像 resolve_gate_config() 没实现 `all`」这种语义漂移。R4 缓解措施失效，双源漂移窗口打开——下次有人改 SKILL.md 预设不改 bats，`check-gate-sync.sh` 静默放行，gate 行为分叉。

**Remedy（修补）**：DESIGN 第 9 节或 ADR-G4 显式给出 `check-gate-sync.sh` 的扩展规格：① 提取 SKILL.md PRESET_MAP 的预设名集合（grep / awk 提取）；② 提取 bats 镜像 resolve_gate_config() 支持的预设名集合；③ 集合 diff 不等则 exit 1。给一段伪代码或函数签名，而非「check-gate-sync.sh 扩展查一致性」一笔带过。

---

### 🟡 R4 · 风险段遗漏「session_id 锚点反成单点伪造」——威胁④的防御反而引入新攻击面，DESIGN 未识别

**Symptom（症状）**：ADR-G1 Decision#2 Tier 2 T3 用 `session_id=CLAUDE_CODE_SESSION_ID` 作「跨会话隔离锚点」挡威胁④（移花接木）。但 `CLAUDE_CODE_SESSION_ID` 是**环境变量**（DESIGN L135 自承「子 agent 仅能拿此会话级共享 ID」）。环境变量对主 agent **可读**——主 agent `echo $CLAUDE_CODE_SESSION_ID` 即可拿到当前会话 ID，写入伪造 `.done` 的 `session_id=` 字段。

威胁④原本要挡「复用**旧会话**的合法 `.done`」，但主 agent 用 Write 产新 `.done`（威胁③）+ 写当前 `$CLAUDE_CODE_SESSION_ID`（合法值）→ T3 session 锚点**必然通过**（session_id 与当前会话一致）。也就是说 session_id 锚点对威胁③完全失效，且 ADR-G1 Consequences 已诚实声明威胁③ v1 不完全挡——**但风险段没把「session_id 可读 → 锚点降级」列为独立风险**，只在威胁③大条目下零散提及。

更严重：`CLAUDE_CODE_SESSION_ID` 在 `.done` KVP 中持久化（`session_id=<id>`），意味着 `.done` 文件**固化**了会话 ID。如果用户用同一仓库跨 session（如同一个 change 跨天推进），新 session 的 `.done` session_id 与旧 session 不同——**合法场景**「同 change 跨 session 推进」会被 T3 误拦（除非 phases_done 短路兜住）。DESIGN 没分析此边界。

**Source（源头）**：威胁建模完整性。引入的防御机制本身成为攻击面是经典 threat-model 失误（CWE-693 Protection Mechanism Failure）。

**Consequence（后果）**：① session_id 锚点对威胁③无防御（已被承认）但其作为「独立锚点」的宣传价值误导后续维护者；② 跨 session 推进的合法用户可能在 transition 时被误拦（实际影响取决于 phases_done 短路是否兜住所有跨 session 路径——DESIGN 未给路径表）。

**Remedy（修补）**：① 风险段新增 R8：「session_id 锚点对主 agent 可读，仅挡跨会话复用（威胁④），不挡本会话自产（威胁③）——明确锚点边界，避免后续误用」；② 补分析「合法跨 session 推进」路径（如：用户 session A 写 `.done` 但未 transition，session B 继续推进时 T3 session_id 不匹配）是否会触发误拦，phases_done 短路是否覆盖。

---

### 🟡 R5 · D2「每次 jq 读 gate_config 不缓存」性能估算依据过弱，且 PreToolUse 高频路径未给出实测/量级

**Symptom（症状）**：D2（L73）+ ADR-G2 Decision#3：「每次 jq 读，不缓存。PreToolUse 每次新进程，缓存无载体；`.flow-active` <2KB，jq <5ms」。但：① 「<2KB / <5ms」**无实测**，纯估算；② PreToolUse 在每次 Bash 工具调用时触发（agent 高频用 Bash），单次 5ms 看似低，但单次 session 累计 Bash 调用量级未给；③ REQUIREMENT L94 非功能需求「新 hook 校验不显著拖慢 transition（增量 ≤ 现有 hook 单次耗时量级；`time` 对比）」要求**实测对比**，DESIGN 给的是估算。

**Source（源头）**：性能架构要求 — RESPONSE TIME 实测优先于估算。

**Consequence（后果）**：若 `.flow-active` 实际 >2KB（goal schema 累积字段：condition / start_phase / current_phase / turns / status / gates / gate_config / phases_done / scope / active_since…CONTEXT 域语言表里 goal 字段已有 9+ 项），jq 单次可能 >10ms。PreToolUse 每次 Bash 都跑 → agent 一 session 几百次 Bash → 累计秒级延迟。REQUIREMENT 非功能「不显著拖慢」可能不达标，TEST 阶段才发现需重构。

**Remedy（修补）**：DESIGN 补一行实测：`time (jq empty .flow-active; jq '.goal.gate_config' .flow-active)` ×1000，给真实数字。若 <5ms 维持 D2；若 >10ms 需评估「读一次缓存到 PreToolUse 进程内局部变量」（PreToolUse 每次新进程不假，但单次 PreToolUse 内可只读一次复用——D2 的「不缓存」若指跨次调用不缓存，单次内复用与 D2 不冲突）。

---

### 🟢 R6 · 风险段措辞含「主 agent 反驳」式自辩色彩，违反独立审查报告的可追溯原则

**Symptom（症状）**：DESIGN.md L6「基于 L3（glm-4.7）verdict=fail 修订（critical#1/2/3 校验时机 + #4 D3 三层解析 + major#2/3 + minor#1 误判澄清）」；ADR-G4 Decision#2「**命名语义**（回应 L3 minor#1 · 该 finding 误判）」、Consequences 正面项也带「L3 称『all 漏掉 7』系误读」。

这些是 DESIGN 文档对 L3 既有 review 结论的「反驳 / 澄清」措辞，混在决策正文里。

**Source（源头）**：ADR 单一职责——记录决策本身与理由，不应承载与既有 review 的辩论。辩论应放「主 agent 反驳」段或 review 回应表，决策文档保持中性。

**Consequence（后果）**：低。不构成功能缺陷，但 ADR 长期归档后，「该 finding 误判」「L3 称…系误读」这类措辞会让未来读者无法仅从 ADR 复盘决策——需回到 INDEPENDENT-REVIEW 文档对照才能判断当时真相。

**Remedy（修补）**：把「回应 L3 critical#X」与「该 finding 误判」类措辞移到独立的「review 回应」段或注释，决策正文只保留中性陈述：「`all` 预设 = 全部可独立审查阶段 1/2/3/5/6/7（0/4 按设计排除）」。

---

### 🟢 R7 · DESIGN 自承「9.3 跨模块契约」中 `INDEPENDENT-REVIEW-N.md L2 段首行加 `> session: <id>`，但未在 D5/ADR-G1 决策正文给格式契约

**Symptom（症状）**：DESIGN 9.3（L192）写「INDEPENDENT-REVIEW-N.md L2 段首行加 `> session: <id>`（session 锚点载体 · Tier 2 多文件交叉对象之一）」。这是 T3 多文件交叉的关键载体之一。但 D5 / ADR-G1 Decision 段**未**列此格式契约，ADR-G1 只列了 `.done` KVP 格式。T3 多文件交叉要校验「`.done` session_id ↔ `.md` L2 段 session 行」一致，但 `.md` 行的精确格式（是 `> session: <id>` 还是 `session: <id>` 还是 `Session-Id: <id>`）只在 9.3 一处出现，校验函数实现者（4-dev）需跨段拼接理解。

**Source（源头）**：契约完整性 — 跨文件一致性校验的格式契约须在决策正文明确，不应埋在沉淀建议段。

**Consequence（后果）**：低。4-dev 实现时大概率能拼出来，但若实现者按自己理解选了别的格式（如 `session_id: <id>`），T3 校验会全 fail，排查需回查契约源头。

**Remedy（修补）**：把 `.md` L2 段 session 行格式契约补到 ADR-G1 Decision#2 Tier 2 T3 段，与 `.done` KVP `session_id=` 并列给两文件格式契约。

---

## 总评

**Verdict**: fail

存在 2 项 🔴 Critical：
- R1：D6「case 单一源」为伪命题，AC-3 实际需同步改 3+2 处，DESIGN 隐瞒真实耦合面 → 落地按字面执行会致 AC-3 部分未实现（3/5/7 在 L3 入口/自动推进放行）。
- R2：DESIGN 单边把 AC-1 威胁③「主 agent 自产一律拒」（v1 必做）降级为「v1 不完全挡，只提成本」，违反 REQUIREMENT 范围合同 + L103「block 不退化」既定流程，需回 REQUIREMENT 重定义或换 v1 可行的外部锚点。

3 项 🟡 Major（R3/R4/R5）为风险段遗漏与决策依据薄弱，建议在切阶段前补；2 项 🟢 Minor（R6/R7）为文档措辞与契约组织，可选改进。

独立性声明：本报告基于对 DESIGN.md + ADR G1/G2/G4 + REQUIREMENT.md + CHANGE.md + 既有 hook 代码的独立 grep 实证，未引用任何主 agent 自评或外部陈述。

---

## 主 agent 回应（2026-07-02 · 不改写 L2 原文，按 L2-blind-review.md 规范另起段）

> 按 `L2-blind-review.md`「主 agent 无权修改你的原文判断；它若反驳，必须在你报告之后另起段标注」规范，本段为对 L2 findings 的逐条回应，不动 L2 原文。

- **R1（🔴）已采纳并修复**：主 agent 亲自 grep 复核证实——正则 `^(1|2|6)$` 镜像 3 处（gate.sh:39 / 29号:33 / artifacts.sh:109），case 映射镜像 2 处（gate.sh:58-60 / artifacts.sh:117-119）。D6 已改为「多源镜像」诚实声明 + grep 证据。**遗留**：REQUIREMENT AC-3 Then 仅点名 gate.sh，需回 REQUIREMENT 补 artifacts.sh 两站点（已记入 D6 取舍代价）。
- **R2（🔴）已解决（用户选 A · 守合同加强 v1）**：DESIGN 新增 D7——29 号 Stop hook 独占写 `.flow-active.independent-review` 握手（hook 子进程不经 agent Write tool → PreToolUse 不拦 hook 写、拦 agent 写），作威胁③ v1 不可伪造锚点，守 REQUIREMENT L70「主 agent 自产一律拒」。威胁③ + ⑤-L3 v1 **真挡**；⑤-L2 + ⑥ gate_config 篡改留 v2（R5/R8）。见下方"R2 已决"段。
- **R5（🟡）已闭环**：主 agent 实测 `.flow-active`=1723B，`jq empty`≈2.3ms/次、`jq '.goal.gate_config'`≈2.4ms/次（×1000 基准）。D2 已改引实测，估算不仅成立且更低。
- **R3/R4/R6/R7（🟡/🟢）已全部处理**：R3 `check-gate-sync.sh` 扩展为语义 diff（预设名集合，非文本段 diff）写入 ADR-G4 Decision#4 + DESIGN §9.3；R4 session_id 锚点边界（只挡跨会话④，不挡本会话③——③靠 D7）写入 DESIGN §3 实测注 + G1 T3b + 跨 session 合法推进由 phases_done 短路兜底；R6 ADR 决策正文去除「回应 L3/误判」自辩措辞（G2/G4 已中性化，备注移 G4 文末）；R7 `.md` L2 段 session 行格式契约补入 G1 Decision#1 + DESIGN §9.3。

### R2 已决（A 方案 · D7 29 号握手锚点 · 2026-07-02）

用户在 A/B/C 三方向中选 **A（守 v1 合同加强）**。落地为 DESIGN D7 + G1 Decision#4：

- **机制**：29 号 Stop hook 独占写 `.flow-active.independent-review` 握手 = `{phase, status:done, verdict, l3_token:hash(L3响应), written_by:stop-hook-29, written_at}`。PreToolUse 增路径保护规则——主 agent Write/Edit 该路径 → deny；29 号 hook 子进程 bash 直写（不经 agent Write tool）→ 放行。
- **为何 agent 不可伪造**：hook 子进程不是 agent tool 调用，PreToolUse 天然不拦；而 agent 的 Write/Edit 被路径保护拦。故握手存在 + `written_by=stop-hook-29` 即证明 29 号真跑过 L3。
- **挡住范围**：威胁③（本会话自产 .done）——agent 拿不到合法握手 → Tier 2 T3 拒；威胁⑤-L3（篡 .done L3_verdict）——必与不可伪造握手 verdict 不符 → 拒。守 REQUIREMENT L70「主 agent 自产一律拒」。
- **残留（诚实声明）**：威胁⑤-L2（.md L2 段 verdict agent 可同篡）v1 不完全挡，靠 T4 比对 + v2 加密（R5）；威胁⑥（agent 篡 `gate_config[phase]=false` 跳 gate）v1 仅检测，强防留 v1.5/v2（R8）。
- **下一步**：D7 属 v1 实现增量（PreToolUse 路径保护 + 29 号握手写入 + Tier 2 T3 改握手校验），在 4-dev 阶段实现，bats 覆盖（agent Write 握手文件被拒 / 29 号写后 Tier 2 通过）。

---

## L2 盲审 · 第 2 轮（architect-reviewer 子 agent · 独立盲审 D7-revised DESIGN · 2026-07-02）

> 主 agent 原样注入 `L2-blind-review.md` 固化指令 + 审查参数，未附任何上下文。以下为子 agent 原文。
> ⚠️ 本轮 R1/R6 证伪了第 1 轮 R2 决议"A（绝对挡）"——单机无 agent 不可访问锚点。用户重选 **B'**（见下方"主 agent 回应·第 2 轮"）。第 1 轮"### R2 已决（A 方案）"**已被推翻**，保留作历史。

### 🔴 R1 · D7 握手锚点的承载机制（PreToolUse 路径保护）未实现且未被识别为风险——威胁③的 v1 "真挡" 基础不存在

**Symptom**：`DESIGN.md`（D7）/ `G1` 断言「PreToolUse 增路径保护规则：主 agent Write/Edit `.flow-active.independent-review` → deny」，并以此声称威胁③「真挡」。但既有 PreToolUse 基础设施 matcher 硬编码 `"Bash"`（`install_hooks.sh:136/153`），`independent-review-gate.sh:27` `[ "$tool_name" = "Bash" ] || exit 0`。**Write/Edit 根本不触发任何 hook**。DESIGN 通篇未提及 matcher 扩面。

**Source**：Ousterhode《A Philosophy of Software Design》Ch.13「未实现的接口契约 = 幻想」。

**Consequence**：AC-1 威胁③ v1 防御根本不存在。TEST 阶段 regression-demo 直接挂。

**Remedy**：DESIGN 显式补 matcher 扩 `["Bash","Write","Edit"]` + path-guard + §0.5.1 加 install_hooks.sh 触碰 + 风险表加 fail-open + 修 G1 Consequences 措辞。

### 🔴 R2 · D6 引用不存在的文件 `gate.sh`——「grep 实证」基础事实失实

**Symptom**：DESIGN D6 反复引用 `gate.sh:54/57/58-60`。`find flow-kit-bundle -name 'gate.sh'` → 0 命中。实际是 `independent-review-gate.sh`。

**Source**：以"grep 实证"为方法论但核心证据文件名错——违反"证据优先于解释"。

**Consequence**：DEV 按图索骥扑空；下游 reviewer 无法复现。

**Remedy**：DESIGN 全文 `gate.sh` → `independent-review-gate.sh`，逐行核对行号。`grep -rn 'gate\.sh' .specs/gate-integrity/` 全清零。

### 🔴 R3 · R8/AC-6 的「`.flow-active` 纳 git 跟踪」防篡改前提与现实冲突

**Symptom**：DESIGN R8 写「`.flow-active` 纳入 git 跟踪...检测 gate_config 与快照不符 → 拒」。但 `.gitignore:40-41` 排除 `.flow-active*`，文件根本不在 git。

**Source**：CONTEXT.md 禁动清单 + 域语言「.flow-active 不入库」。用被排除的文件作防篡改锚点是逻辑自相矛盾。

**Consequence**：R8 v1 缓解无法实现。agent 改 gate_config 跳 gate，威胁⑥ v1 完全无防。

**Remedy**：二选一——A: 快照改 `.specs/<id>/.goal-snapshot.json`（入库）；B: 诚实承认⑥ v1 不防，风险表移除"v1 仅检测"。

### 🟡 R4 · ADR-G2 Consequences「单一源」与 D6「5 站点镜像」自相矛盾

**Symptom**：G2:24「单一源（gate_config）控制所有阶段开关」vs D6 承认 5 站点镜像。

**Source**：Ousterhode「single source of truth」+ shallow module / shotgun surgery。

**Consequence**：加阶段改 5 处，漂移概率线性增长。

**Remedy**：G2 Consequences 措辞修正：gate_config 是**阶段开关**单一源；phase→phase_name **映射**多源（5 站点），bats 兜底。

### 🟡 R5 · 风险表遗漏「PreToolUse matcher 扩面 fail-open」+「phases_done 短路被自产」

**Symptom**：(a) matcher 扩 Write/Edit 后，hook 挂了卡死 agent 正常 Write；(b) `is_phase_write` 只拦 `.phase =`/`.goal.current_phase =`，**不拦 `.goal.phases_done +=`**——agent jq 塞 phase 进 phases_done 短路绕过。

**Source**：CWE-710 fail-open + defense-in-depth；phases_done 短路写入路径未被拦截覆盖。

**Consequence**：(a) 4-dev 偶发卡死；(b) agent 绕开 D7 握手，gate 绕过路径 v1 就存在。

**Remedy**：(a) 风险表加 fail-open；(b) `is_phase_write` 补 `.goal\.phases_done` 拦截，或短路仅对 archive 生效。

### 🟡 R6 · D7「hook 子进程不经 agent Write tool」未堵 Bash echo/tee 伪造握手路径

**Symptom**：D7 只堵 Write/Edit tool 路径（且按 R1 连这条都没实施），没堵 Bash `echo >`/`tee`/`cp` 路径。`is_phase_write` 的写信号正则只看 `.flow-active`（不带 `.independent-review` 后缀）的 `.phase=`/`.current_phase=`，对 `.flow-active.independent-review` 的 Bash 写完全不拦。agent 一行 `echo '{...written_by:stop-hook-29...}' > .flow-active.independent-review` 即伪造。

**Source**：威胁建模「锚点不可伪造 = 锚点所有写入路径都不可被攻击者控制」。

**Consequence**：D7"不可伪造"全垮。

**Remedy**：`is_handshake_write` 显式拦 `>`/`>>`/`tee`/`cp`/`mv`/`sed -i` 写 `.flow-active.independent-review`；§9.3 路径保护契约覆盖 Write tool/Edit tool/Bash 重定向三种。

### 🟢 R7 · D3 三层解析的 check-gate-sync grep 提取依赖 Markdown 排版稳定

**Symptom**：check-gate-sync 用 grep 提取 SKILL.md PRESET_MAP 预设名，依赖代码围栏格式稳定。

**Source**：D3 自承"Bash 不解析 Markdown"却用 grep（更弱）提取——自相矛盾。

**Consequence**：排版变化致 grep 失效 → 空集合 diff → 静默通过，漂移不被发现。

**Remedy**：check-gate-sync 用 `bash -c 'source <(sed 提取代码块); declare -p PRESET_MAP'` 实际执行提取，或抽 PRESET_MAP 到独立 .sh 真单一源。

### 🟢 R8 · R7「Tier 1/2 误配」缓解只 bats，缺结构性防呆

**Symptom**：`fk_validate_done_marker <tier>` 字符串参数传错 silent 降级。

**Source**：Ousterhode「Declare types over test」。

**Consequence**：未来新调用方笔误 → 静默降级 Tier 1，威胁③窗口重开。

**Remedy**：可选——拆两函数 `fk_validate_done_marker_write`/`_transition`，消除字符串参数误配面。

**Verdict**: fail（R1/R2/R3 三项 🔴）

---

## 主 agent 回应 · 第 2 轮（2026-07-02c · 不改写 L2 原文）

> 第 1 轮 R2 决议"A（绝对挡）"被本轮 R1/R6 证伪。主 agent 亲自 grep 复核全部 critical（见各条复核），确认成立。用户重选 **B'（常见写向量挡 + 诚实降级 L70 · L103 重定义）**。逐条回应：

- **R1（🔴）已采纳**：复核 `independent-review-gate.sh:27` `[ "$tool_name" = "Bash" ] || exit 0` + `install_hooks.sh:136/153` matcher=Bash 属实。DESIGN §0.5.1 加 install_hooks.sh 触碰 + D7 增 matcher 扩 `["Bash","Write","Edit"]` + `is_handshake_write` path-guard。
- **R2（🔴）已采纳**：复核 `find gate.sh`=0 命中属实。DESIGN 全文 `gate.sh` → `independent-review-gate.sh`（D6/§0.5.1/§0.5.2）。
- **R3（🔴）已采纳（选 B）**：复核 `.gitignore:40-41` 排除 `.flow-active*` 属实。R8 改为 **v1 不防⑥**（强防留 v1.5 `.specs/<id>/.goal-snapshot.json` 入库快照 diff），DESIGN §6 显式列入不在范围，风险表 R8 措辞诚实化。
- **R4（🟡）已采纳**：G2 Consequences 改"阶段开关单一源 vs 映射多源（5 站点）"区分。
- **R5a（🟡）已采纳**：DESIGN 风险表新增 **R9 fail-open**（path-guard / is_handshake_write 在 lib 失败时 exit 0）。§3 + §9.3 + G1 Decision#4 明示。
- **R5b（🟡）已采纳**：DESIGN §3 + §9.3 + G1 Decision#5——`is_phase_write` 扩拦 `.goal.phases_done` 写信号；新增 **R10** 记此绕过堵漏。
- **R6（🟡）已采纳**：D7 path-guard 契约（§9.3 + G1 Decision#4）覆盖三类写向量——Write tool / Edit tool / Bash 重定向正则（`>`/`>>`/`tee`/`cp`/`mv`/`sed -i`/`dd of=`/heredoc）。**诚实边界**：exotic Bash（python-c/dd/变量间接）逃逸留 v2 加密（R5）。
- **R7（🟢）已采纳**：§9.3 check-gate-sync 改 `source <(sed 提取); declare -p PRESET_MAP` 实际执行提取（而非 grep）。
- **R8（🟢）延 4-dev 评估**：`fk_validate_done_marker` 拆两函数消除 `<tier>` 字符串参数——记入 4-dev 重构清单，v1 实现时评估（不阻塞 design gate）。
- **用户决议（A→B'）**：A「绝对挡」被证伪，用户选 B'——L70/L110 按 L103 重定义（v1 挡常见写向量 + 审计链，exotic + ⑤-L2 留 v2）。DESIGN D5/D7 + G1 Consequences 全改为 B' 措辞，不再声称"真挡"。

### D7 最终立场（B' · 2026-07-02c）

威胁③ v1：挡**常见写向量**（Write/Edit tool + Bash `>`/`>>`/`tee`/`cp`/`mv`/`sed -i`）+ 多文件交叉审计链；**exotic Bash 逃逸 + ⑤-L2 .md 同篡 留 v2 加密签名**。诚实声明 v1 非绝对挡（L70 已 L103 重定义）。威胁④ SESSION_ID 锚点挡；威胁⑥ gate_config 篡改 v1 不防（R8 留 v1.5）。

---

## L2 盲审 · 第 3 轮（architect-reviewer 子 agent · 独立盲审 B'-revised DESIGN · 2026-07-02）

> 主 agent 原样注入 `L2-blind-review.md` + 审查参数，未附任何上下文。以下为子 agent 原文。

### 🔴 R1 · AC-1 威胁③/⑤ 的"v1 不完全挡"与 REQUIREMENT AC-1 Then 验收语言冲突，TEST 阶段会卡死

**Symptom**：DESIGN §6 与 G1 Consequences 写"威胁③ v1 非绝对挡""⑤-L2 v1 不完全挡"，但 REQUIREMENT AC-1 Then① 仍要求"依赖 agent 无法伪造的外部锚点...挡①②③"，Then③ 要求"内容完整性校验（哈希/签名，挡⑤）"。握手文件本身 hook 能写 agent 经 Bash 也能写，不构成"agent 无法伪造的外部锚点"。

**Source**：DESIGN §0.5.3/§6/G1 Decision 6/Consequences 与 REQUIREMENT AC-1 Then①③ 自相矛盾。L103 重定义改了 v1 scope 但 AC-1 Then 字面未同步。

**Consequence**：TEST 无法派生可机器验证用例——按 REQUIREMENT 字面=AC 不达成=fail；按 DESIGN 宽松=绕开承诺。4-dev 前必须消歧。

**Remedy**：方案 A（诚实务事·推荐）——REQUIREMENT AC-1 Then①③ 改写为"v1 挡常见写向量 + 审计链；exotic + .md 同篡留 v2 加密"，与 DESIGN/G1 完全对齐。三方字面一致。

### 🔴 R2 · 威胁⑥（gate_config 篡改）v1 不防，但未在 AC-1 威胁清单显式列入——审计面漏洞

**Symptom**：DESIGN §6 + R8 把威胁⑥列为"v1 不防"，但 REQUIREMENT AC-1 Given 威胁清单只有①②③④⑤，完全没⑥。`.gitignore:40-41` 确认 `.flow-active*` 不入库，agent 可任意 jq 改 gate_config 而 hook 无校验。

**Source**：G2 Decision#2 把 gate 开关完全绑定 .flow-active.goal.gate_config，该文件 agent 经 Bash 可写。CWE-345 Insufficient Verification of Data Authenticity。AC-1 列 5 类威胁漏掉"agent 改配置关 gate"最直接 bypass。

**Consequence**：v1 上线后 agent 一行 jq 关闭全部防线。不在 AC-1 → TEST 不测 → 6-review 不查 → 生产事故。

**Remedy**：REQUIREMENT AC-1 威胁清单加⑥ + DESIGN 风险表标注"v1 检测"。廉价检测：transition hook 比对 .flow-active.goal.gate_config 与 .specs/<id>/.goal-snapshot.json（入库快照），phase key independent→false/缺失 → deny。不需加密，成本极低，应提到 v1。

### 🟡 R3 · D7 fail-open 与"加固 gate"目的语义自相矛盾

**Symptom**：DESIGN §3 + G1 Decision#4 + R9 规定 matcher 扩面后 hook 内任何 source 失败/jq 不可用 → fail-open（exit 0）。但本 change 目的是"gate 不可绕过"。fail-open 意味着 agent 让 hook 内部出错就放行。

**Source**：R9 混淆"matcher 扩面"与"校验失败"。path-guard 与 done 校验是同 hook 进程内两段逻辑：path-guard fail-open 合理，整体校验 fail-open 不合理。

**Consequence**：agent 注入畸形 .flow-active → jq 解析失败 → hook exit 0 → transition 放行。攻击面比自评更大。

**Remedy**：区分——path-guard（is_handshake_write）fail-open；done/transition 校验（fk_validate_done_marker）fail-close（exit 2 + 可读错误）。

### 🟡 R4 · D3 三层解析的 check-gate-sync 兜底依赖未实现的扩展

**Symptom**：D3/G4 Decision#4 说 check-gate-sync.sh 扩为语义 set-diff，但实测当前脚本是文本段 diff（check_pair 靠 marker grep），不支持 set-diff。ADR-G4 给伪代码但 DESIGN 没说"check-gate-sync.sh 改造属 v1 必做"。

**Consequence**：4-dev 改 SKILL.md 忘改 bats（或反之），check-gate-sync 仍报通过（文本 diff 通过 ≠ 语义一致），5-test 才发现。

**Remedy**：DESIGN §0.5.1 新增清单加 check-gate-sync.sh（重写 set-diff），AC-4/AC-5 加 bats 用例。

### 🟡 R5 · D6 多源镜像 5 站点 与 G2 Consequences "单一源" 措辞打架

**Symptom**：D6 自承 5 站点镜像诚实，但 G2 Consequences 仍写"单一源"。同 ADR 用了"单一源"未加限定。

**Consequence**：4-dev 按 G2 Consequences 字面可能漏改 5 站点中某处。AC-3 Then 只点名 gate.sh:39 + :57-60，未提 artifacts.sh 两站点。

**Remedy**：G2 Consequences 明确"阶段开关单一源 vs 映射多源"；REQUIREMENT AC-3 Then 列全 5 站点。

### 🟡 R6 · R8"v1 不防⑥"的理由"载体不存在"是循环论证

**Symptom**：R8 缓解列写"v1 不防⑥（.flow-active 被 .gitignore 排除，载体不存在）"。但 .specs/ 不在 .gitignore，.specs/<id>/.goal-snapshot.json 完全可入库。载体现成，只是 DESIGN 选择不写。

**Consequence**：见 R2——廉价检测被以"载体不存在"推到 v1.5，是设计偷懒。

**Remedy**：R8 改诚实"v1 检测⑥（.specs 快照 diff）"，或直接提到 v1（见 R2）。

### 🟢 R7 · D7 path-guard Bash 正则清单遗漏 printf/awk/install/rsync 等常见写向量

**Symptom**：§9.3 + G1 Decision#4 列 Bash 写向量正则 `> >> tee cp mv sed -i dd of= heredoc`。漏 printf/awk/install/gcc -o/rsync。这些是 Linux 常规工具非 exotic。

**Remedy**：正则补 printf/awk/install/dd（含 if=）/rsync；或明示"v1 列举非穷尽，完整穷尽留 v2 加密"，加入 regression-demos/exotic-escape。

### 🟢 R8 · 缺 ADR-G3——编号跳号暗示决策被悄悄删

**Symptom**：DESIGN §4 列 G1/G2/G4 跳过 G3。adr/ 只有三个文件。无说明 G3 去哪。

**Remedy**：§4 加说明，或新增 ADR-G3 记威胁⑥决策。

### 🟢 R9 · R3 phases_done 短路缓解 与 R10 phases_done 绕过堵漏 形成微妙依赖

**Symptom**：R3 缓解"phases_done 短路"，R10 又说 phases_done 有绕过要拦 `.goal.phases_done` 写。本 change 自己 transition 靠 phases_done 短路，又新增"拦 phases_done 写"——主 agent 怎么合法推进？

**Remedy**：§3 补"phases_done 合法写入通路"——只有 transition hook 子进程能写 .goal.phases_done，主 agent 写一律 deny。

**Verdict**: fail（R1/R2 两条 🔴 · 文档一致性 + 审计面遗漏，修复成本文档级 + 少量 bats）

---

## 主 agent 回应 · 第 3 轮（2026-07-02d · 硬上限最后一轮 · 不改写 L2 原文）

> 本轮是硬上限最后一轮。critical 均为文档一致性 + scope 诚实度（非架构返工），主 agent 全部采纳并在本轮闭环。residual 留 v2 已诚实声明。逐条：

- **R1（🔴）已采纳**：REQUIREMENT AC-1 Then 已重写对齐 B'（Then①③→常见写向量挡 + 审计链 + v2 边界），与 DESIGN/L70/G1 三方一致。TEST 可按"常见写向量挡"派生用例。
- **R2（🔴）已采纳（提到 v1）**：⑥ 加入 AC-1 威胁清单 + Then⑤；DESIGN 新增 **D8**（.specs/<id>/.goal-snapshot.json 入库快照 + transition diff）+ 新建 **ADR-G3** + R8 改诚实。廉价检测（~5 行 jq + 1 bats）入 v1。
- **R3（🟡）已采纳**：DESIGN 新增 **D9**（fail 策略区分：path-guard fail-open / 校验 fail-close）+ G1 Decision#7 + R11。agent 不能靠制造 hook 内部错误放行。
- **R4（🟡）已采纳**：DESIGN §0.5.1 加 check-gate-sync.sh（重写 set-diff）入 v1 必做；D3 + §9.3 标注实现 owner。
- **R5（🟡）已采纳**：G2 Consequences 已区分"开关单一源 vs 映射多源"；REQUIREMENT AC-3 Then 已补全 5 站点。
- **R6（🟡）已采纳**：R8 循环论证已修正——.specs 未 gitignored，⑥ 改"v1 检测"（D8）。
- **R7（🟢）已采纳**：DESIGN §9.3 Bash 向量补 printf/awk/install/dd if=/rsync + **非穷尽声明**；新增 R12 + regression-demos/exotic-escape 文档化。
- **R8（🟢）已采纳**：新建 **ADR-G3**（⑥ 检测决策），§4 索引补 G3。
- **R9（🟢）已采纳**：DESIGN 新增 **D10**（phases_done 合法写入通路——仅 transition hook 子进程能写）+ G1 Decision#8 + R10。dogfood 本 change transition 走 hook 通路，不自卡。

### 最终立场（2026-07-02d · 硬上限收尾）

L2 三轮 + L3 一轮全部 findings 已闭环或诚实声明 residual。v1 AC-1 现实立场（B'）：
- **完全挡**：①空 / ②KVP伪造 / ④跨会话复用
- **常见写向量挡 + 审计链**：③（D7 path-guard）/ ⑤-L3（握手 verdict 一致）
- **检测**：⑥（D8 .specs 快照 diff）
- **v1 不完全挡（诚实留 v2 加密）**：③ exotic Bash 逃逸 / ⑤-L2 .md 同篡 / ⑥ 强防

按硬上限，本轮后不再跑 L2。L3 段（下方）为修订前 DESIGN 的历史审查；B'-revised DESIGN 的 L3 复审由 Stop hook 自动跑（或下轮触发）。

---

## L3 盲审（glm-4.7 外部模型 · 针对修订前 DESIGN · 2026-07-02 01:01）

> ⚠️ 本段为**修订前** DESIGN（T3/T4 前置版）的 L3 审查，verdict=fail。其 4 条 critical（#1 T4 死锁 / #2 T3 session PreToolUse / #3 T3 多文件交叉 Gate / #4 D3 PRESET_MAP）已在 2026-07-02 DESIGN 修订（两层时机 + 三层解析）中闭环。保留作历史审计链，**非当前设计状态**。

### 审查结论

```json
{
  "critical": [
    {
      "file": "G1-done-authenticity.md / Decision",
      "issue": "T4 Verdict 绑定的逻辑闭环存在死锁风险",
      "why": "G1 定义 fk_validate_done_marker 校验 T4 依赖 .md 的 L2 段 Verdict 行与 .done 比对。但在 PreToolUse/Gate 执行校验时，L2 子进程尚未运行，.md 文件尚未写入，L2 段物理不存在。这导致初次生成 .done 时必校验失败（阻断），形成死锁。除非依赖遗留文件，否则新 flow 无法通过。",
      "fix": "将 T4 校验从 Write Gate 移至 Phase Transition/Stop Hook（后置检查）；或在 Write 时刻仅校验元数据，留 Verdict 校验给下游 Action。"
    },
    {
      "file": "DESIGN · 3. 关键状态机",
      "issue": "T3 Session 校验无法在 PreToolUse 执行",
      "why": "PreToolUse hook 在主 Agent 进程运行，此时 CLAUDE_CODE_SESSION_ID 必然为主 Agent 的 ID。而子 Agent（Review）尚未启动，其产出的 .done 中的 session_id 将永远不等于主 Agent ID，导致任何由子 Agent 生成的 .done 在 Write 时均会被 T3 拦截。",
      "fix": "明确跨会话锚点仅用于防篡改检测（如 Stop Hook），而非 Write Gate 的准入条件。"
    },
    {
      "file": "DESIGN · 3. 关键状态机",
      "issue": "T3 多文件交叉校验在 Gate 不可行",
      "why": "PreToolUse/Write 阶段，目标 INDEPENDENT-REVIEW-N.md 及 .flow-active 中的 L2 段/状态尚未生成。Gate 处校验 .done 与尚未存在的 .md/config 进行交叉比对，逻辑上无法成立。",
      "fix": "将多文件交叉校验限制在后置 Hook（如 29-independent-review.sh）的幂等性检查中，从 Gate 必要条件中移除。"
    },
    {
      "file": "DESIGN · 1. 决策清单 (D3)",
      "issue": "核心决策 PRESET_MAP 改 SKILL.md 实现方案不明确",
      "why": "SKILL.md 是人类指令文档，Bash 无法动态可靠读取 Markdown 文档中的映射逻辑作为运行时 Gate Config。D3 仅提到双源需 check-gate-sync，但未阐明 Bash 运行时如何解析 SKILL.md 来获得阶段开关。",
      "fix": "澄清双源机制：Bash 运行时只读 gate_config，不解析 SKILL.md；SKILL.md 与 bats 镜像由 check-gate-sync.sh 兜底。"
    }
  ],
  "major": [
    {
      "file": "G2-dynamic-gate-config.md",
      "issue": "stage 到 phase_name 映射未指明来源",
      "fix": "明确 1->requirement 等映射关系的存储位置（case 语句存 independent-review-gate.sh + flow-kit-artifacts.sh 两处镜像）。"
    },
    {
      "file": "DESIGN · 1. 决策清单 (D5)",
      "issue": "威胁③的缓解措施存在矛盾",
      "fix": "明确承认 v1 无法防御主 Agent 主动伪造，将防御重点放在事后审计或 v2 签名。"
    },
    {
      "file": "G1-done-authenticity.md",
      "issue": "FKV 格式缺少描述符定义",
      "fix": "定义 artifacts 的序列化格式（空格分隔列表）。"
    }
  ],
  "minor": [
    {
      "file": "G4-gate-config-357.md",
      "issue": "预设命名存在语义冲突（L3 误判 all 漏 7）",
      "fix": "all 本就含 7-integration（G4 Decision#2 集合明确）；补命名语义注。"
    }
  ],
  "verdict": "fail",
  "summary": "核心架构设计存在严重的时机与逻辑冲突：Gate 校验依赖尚未生成的下游产物，且无法区分 Agent 身份，导致在标准流程下无法放行。（注：此为修订前 DESIGN 的结论，已闭环。）"
}
```

<details><summary>API 原始响应（glm-4.7 · 修订前 DESIGN · 折叠）</summary>

原始响应已归档。L3 model=glm-4.7，input_tokens=4869，output_tokens=1405，verdict=fail。完整 API 原始 JSON 因 29 号旧 `>` 覆盖 bug（AC-6 T02 已修）残留在修订前文件版本中；本段为解析后报告，原始 JSON 可在 git 未跟踪前的本地历史查到（如有需要重跑 L3 可获新原始响应）。

</details>
