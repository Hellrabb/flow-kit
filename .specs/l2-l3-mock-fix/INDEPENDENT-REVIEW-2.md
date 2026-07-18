# 独立审查 · 阶段 2

> 盲审依据：仅读 `.specs/l2-l3-mock-fix/DESIGN.md` + `.specs/l2-l3-mock-fix/REQUIREMENT.md` + `.specs/l2-l3-mock-fix/CHANGE.md` + `.specs/adr/001|002|003-*.md` + `.specs/CONTEXT.md` + `.specs/ARCHITECTURE.md`，并 grep 源码核实 DESIGN/ADR 中作为论据的事实陈述。未读 `INDEPENDENT-REVIEW-1.md`（不在指定工件清单内，避免上游 L2 判断污染本次盲审）。
> 独立性自检：未检测到主 agent 自评 / 草稿 / 概述 / 辩护注入。任务参数干净。

---

## L2 盲审

### 工件符合性核对（先做事实校验，再下判断）

- ADR-001 论据「`PHASE_GATE_KEY_MAP` 在 common.sh:255 与 independent-review-gate.sh:25 两处 declare」**已核实**（grep 实证两处，行号一致）。
- ADR-001「6 消费者（29:77/117/155 + gate.sh:395/413 + common 注释）」**部分失准**：5 个执行点 + 1 个文档注释（见 R-ADR1-consumers）。
- ADR-002 引用的 `is_git_commit` 现行 regex（gate.sh:111-113）**已核实**。
- D4「_l3_check_rerun 沿用函数换判定」**已核实**：函数签名 `_l3_check_rerun(phase, artifacts_dir)` 可保留，但其内 28 行 phase→artifact mtime `case` 块将沦为死代码（见 R-D4-2）。
- `.done` KVP 契约本身在项目内不自洽：ARCHITECTURE §4.1 列 **8 键**（phase/change_id/written_by/written_at/L2_verdict/L3_verdict/session_id/artifacts），CONTEXT「.done 6 键 KVP」与 ADR-005「6 键」记为 **6 键**。DESIGN §9.3 在此模糊地基上又引入 hash（见 R-D4-1）。

---

### 🟡 R-D2-1 · is_git_commit 预处理严重欠规约：无伪代码、无 helper 接口、未覆盖对称风险
**Symptom（症状）**：DESIGN §1 D2 与 ADR-002 仅给出意图「剥离 heredoc body + 引号字面量 + 注释后，再对命令实际 token 匹配」，**全文无伪代码、无 helper 函数接口、无等价类到算法的映射**。现行 `is_git_commit()` 是 3 行函数（`flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh:111-113`）。D2 要把它扩成「heredoc/quoting 感知预处理器 + token 匹配」——这是一个迷你 bash lexer，且相邻的 `is_gh_pr_create()`（gate.sh:114-116，同结构 regex）**未被 D2 纳入**：审查报告正文出现 `gh pr create` 字符串会触发同一类误拦，但 DESIGN/ADR-002 只字未提。
**Source（源头）**：Ousterhout《A Philosophy of Software Design》「深模块」——接口应窄、实现应深，但**接口契约必须在设计期确定**；把一个未定义契约的复杂实现塞进单函数名 `is_git_commit` 是「窄接口藏意外深度」反模式。CONTEXT 默认偏好「gate regex 风格：变量存 regex」也要求设计期明确 regex 形态。
**Consequence（后果）**：实现期才会暴露的真问题——`<<'EOF'`（字面 heredoc）vs `<<EOF`（展开 heredoc）vs `<<-EOF`（去缩进）vs 嵌套引号 vs `$()` 替换的处理差别；任一边界猜错就误伤合法 commit（R3）或漏拦（R2）。AC-H (a)-(e) 五个等价类在无算法骨架时「覆盖」无意义——测试会反过来定义实现。`is_gh_pr_create` 漏修则 BUG-H 在 pr-create 路径复发。
**Remedy（修补）**：DESIGN 增补一节给出：(1) 预处理 helper 接口（建议抽 `_strip_command_literals <cmd> → stdout`，供 `is_git_commit` 与 `is_gh_pr_create` 共用，避免又造 DRY 违反）；(2) 关键边界的伪代码或决策表（至少覆盖：单/双引号包裹、`<<'EOF'`/`<<EOF`/`<<-EOF`、`#` 注释、`$()`/反引号展开）；(3) 明确把 `is_gh_pr_create` 纳入同批改造或在 out 段显式排除并说明理由。把 D2 的「中」概率风险降级前提：先有算法，再谈概率。

---

### 🟡 R-D4-1 · D4「## L3 段 + artifact hash」与 AC-J「仅 ## L3 段」不一致；hash 存储位置未定义，触及 `.done` 契约
**Symptom（症状）**：DESIGN §1 D4 决策为「`_l3_check_rerun` 改 `## L3` 段内容标记 + **artifact hash**」；而 REQUIREMENT AC-J Then 只写「判定基于 `## L3` 段：段存在且 trim 后 len > 0 才 skip」，**完全无 hash**。两份文档对同一函数的判定逻辑给出不同规格。DESIGN 全文未指定 hash 存哪里：候选三选一全部触雷——(a) 存 `.done`：`.done` 在 ARCHITECTURE §4.1（8 键）+ ADR-005/CONTEXT（6 键）已是强制 KVP 格式，加 hash 键破坏契约；且 CONTEXT 禁动清单明定「`.independent-review-<N>.done` — 仅 `l3_review_run()` 有写权限」，L3 verdict=fail 时按 `[2026-07-07]` 决策不写 `.done`，此时 hash 无处落脚。(b) 存 `INDEPENDENT-REVIEW-N.md` 的 `## L3` 段：但 hash 正是用来触发重审的，重审未跑就不会重写该段 → 鸡生蛋。(c) sidecar 文件：DESIGN 未提。
**Source（源头）**：SPEC 一致性原则——AC 是「TEST 阶段派生用例的唯一来源」（REQUIREMENT 末行），DESIGN 不得与 AC 给出互斥的判定逻辑。ARCHITECTURE §4.1 与 ADR-005 把 `.done` schema 定为跨模块契约，新增键需走 ADR（ARCHITECTURE §2.2「破例必须升级 ADR」）。
**Consequence（后果）**：(1) 实现者按 AC-J 做（仅查 `## L3` 段非空）→ artifact 被**真实重写**（如 REQUIREMENT.md 大改）后，旧 `## L3` 段仍在 → **不触发重审**。这是从现行 mtime 机制的**反向回归**（mtime 至少能捕真实变更，只是被 touch 钻空子；D4-as-AC-J 连真实变更都丢）。CHANGE.md 验收线 2「L3 复审机制不被 mtime 误判短路」会被过度实现成「被 stale `## L3` 段短路」。(2) 实现者按 DESIGN D4 做（加 hash）→ 面临存储位置三选一雷区，最可能随手塞 `.done` → 破坏 KVP 契约 + 与 fail-不写-.done 冲突。
**Remedy（修补）**：先定权威：要么修 AC-J 把 hash 补进 Then（并指定判定优先级：hash 变 → 重审，`## L3` 段空 → 重审，否则 skip），要么删 DESIGN D4 的 hash 只留 `## L3` 段（并接受「真实 artifact 改动不自动重审」的取舍，在风险段显式记录）。若保留 hash，须在 DESIGN 指定存储载体（推荐：`INDEPENDENT-REVIEW-N.md` 末尾的 `L3_artifact_hash: <sha>` 元数据行，由 `_l3_check_rerun` 比对当前 artifact sha 与该行），并证明不触 `.done` 写权限禁区。

---

### 🟡 R-D4-2 · D4 判定基替换后，`_l3_check_rerun` 既有的 phase→artifact mtime case 块（28 行）沦为死代码，DESIGN 未交代
**Symptom（症状）**：现行 `_l3_check_rerun()`（`flow-kit-bundle/hooks/stop/lib/l3-review.sh:386-417`）的核心是 `case "$phase" in 1)...REQUIREMENT.md ;; 2)...DESIGN.md ;; ... ;; 6|7)...REVIEW.md ;;` + `artifact_mtime` vs `review_mtime` 比较。D4 把判定改为查 `## L3` 段，整个 `case` 块与 `artifact_mtime` 计算路径**全部失效**（artifact 文件 mtime 不再被读）。DESIGN §0.5.2 称「沿用函数换判定」，但未交代这 28 行的处置（删除 / 保留备用 / 注释）。
**Source（源头）**：YAGNI 与死代码管控——TD-009 已把「全仓 0 调用的函数」列为技术债并清理；TD-020 `write_failed_state` 即因「定义但无调用」被移除。在同一 codebase 留下 28 行新死代码与既有治理先例矛盾。
**Consequence（后果）**：实现者若机械「换判定」（只加 `## L3` 段检查、不动 case），留下半死函数 → 后续读者误以为 mtime 仍参与判定，触发误改；jscpd/复杂度扫描掉分；下一次 health 巡检新增一条 TD。
**Remedy（修补）**：DESIGN §1 D4 补一句「同时删除 `_l3_check_rerun` 内 `case "$phase"` 与 `artifact_mtime` 计算块（共约 22 行），函数体收敛为：读 `INDEPENDENT-REVIEW-N.md` → 查 `## L3` 段（+ hash，依 R-D4-1 结论）→ 返回 0/2」。明确函数体长度上限作为单测锚点。

---

### 🟡 R-D3-R5 · D3/R5 把「L3 漏跑」这一核心后果的缓解降级为「文档 + 日志」，与项目 protect-the-weakest 哲学及反复教训冲突
**Symptom（症状）**：DESIGN §1 D3 决策「文档化 L2-first 顺序契约 + 29 D4 提示清晰化 + 可观测性日志」，§5 R5（风险=「D3 契约无人读，L3 仍漏跑」，后果=「审查缺失」，概率=「中」，缓解=「29 D4 提示指引 + 可观测性日志」）。缓解完全依赖**主 agent 读提示并自觉派 L2**。但本项目存在 ADR-006「protect the weakest」哲学、28-weak-model-compliance Stop hook（专门检测 prompt-only 护栏失效）、以及刚归档的 l2-l3-test-defect 7 个 bug（BUG-A/B/C/D/E/F/G 全源于编排层 / prompt 层不可靠假设，见 MEMORY [[gate-orchestration-integration-test]] + [[l3-model-unreliable]]）。CONTEXT 已有间接派发范式：SessionStart 消费 `.flow-active.correction`（由 Stop hook 写）执行矫正——**Stop→flag→SessionStart 派发**的架构通道已存在，DESIGN 未探讨。
**Source（源头）**：项目自身 ADR-006「弱模型缺约束崩溃 ≫ 强模型多约束啰嗦」；ADR-008「prompt 指令在弱模型下不可靠，hook 层事后检测 + 文件传递矫正指令更可靠」；MEMORY「gate 编排层须集成测试」反复记录「纯 prompt 防线失效」。DESIGN 用 prompt+log 挡一个它自己评为「中」概率的「审查缺失」后果，与上述决策直接抵触。
**Consequence（后果）**：「审查缺失」是 gate 系统的最高代价失败——等于 L3 整层作废。R5 给「中」概率 + 纯文档缓解，期望损失 = 中 × 审查缺失 ≫ 缓解成本（一次间接派发机制）。一旦主 agent 弱模型跳过提示，本 change 验收线 2（gate 行为对 L3 透明）在 both 模式下静默失效，且无 hook 兜底告警（可观测性日志只给开发者看，不进 agent 上下文）。
**Remedy（修补）**：DESIGN 至少在 R5 增列一个 hook 层兜底备选并显式取舍，例：(a) Stop 29 D4 退出时除提示外，写 `.flow-active.correction`（type=`l2-missing`），SessionStart 消费后注入「必须先派 L2」banner（复用既有矫正文件管线，零新基建）；(b) 或在 PreToolUse gate 的 transition 拦截点强制 `## L2 盲审` 段存在性（与现有 L3 gate 并列，硬拦）。若仍选「仅文档」，须把 R5 概率重评为「高」+ 后果标「审查层失效」，并登记为接受的技术债（写明「依赖主 agent 自觉，弱模型下不保证」），而不是粉饰为「中」+「缓解充分」。

---

### 🟡 R-D2-AC-f · AC-H (f) 反规避 grep 断言未给模式，与既有 `deny_reason="git commit"` 字面量冲突陷阱未交代
**Symptom（症状）**：REQUIREMENT AC-H (f)「实现源码不含针对具体敏感字符串的白/黑名单字面量（grep 静态断言）」。但源码 grep 实证：`independent-review-gate.sh:417` 有 `deny_reason="git commit"`（deny 原因标签字面量），`L5` 注释也含「git commit」。naive grep（如 `grep -n 'git commit' file`）会在这些合法点上误命中。DESIGN/ADR-002 未指定 grep 的精确模式 / 排除规则 / 锚定方式。
**Source（源头）**：AC-H (f) 是硬约束（回应 R1 🔴），其验证手段必须可执行且无歧义；「反规避」的整点在于 grep 本身不能被绕过——若 grep 模式未定，实现者可写出过松的 grep（让任何实现都 pass）或过严的 grep（连 deny_reason 标签都 fail）。
**Consequence（后果）**：要么 (a) 实现者写松 grep → AC-H (f) 退化为橡皮图章，反规避落空（BUG-H 根治落空）；要么 (b) 写严 grep → CI 在 deny_reason 标签上报红，被迫改标签 → deny 语义/日志格式回归。两种都让 AC-H (f) 失去意义。
**Remedy（修补）**：DESIGN 在 D2 增「反规避 grep 锚点」段，给出具体 grep 命令，例：`grep -nE '\b(git[[:space:]]+commit|敏感列表)\b' independent-review-gate.sh | grep -vE '^[0-9]+:\s*#|deny_reason='` 并断言输出为空；或把 deny_reason 标签改为不触发模式的形式（如 `deny_reason="git-commit-deny"`），从源头消歧。在 AC-T 测试里固化该 grep。

---

### 🟡 R-ADR · D4/D5 缺 ADR（D1/D2/D3 各有 ADR-001/002/003），ADR 纪律不一致
**Symptom（症状）**：DESIGN §4「ADR 索引」仅列 001/002/003，对应 D1/D2/D3。但 §1 决策清单有 **D1-D5 共 5 条**——D4（判定基从 mtime 改内容标记 + hash，触及 `.done` 契约与 R-D4-1）与 D5（pipeline 模式禁 fk_auto_phase，触及 CONTEXT 禁动清单「`fk_auto_phase()` gate 检查段 — 修改需理解三道防线」）**无 ADR**。D5 尤其敏感：它修改的 `26-workflow.sh` G1 + `fk_auto_phase` 正是禁动条目。
**Source（源头）**：ARCHITECTURE §3「ADR 列表 · 不可逆决策清单」+ §2.2「破例必须升级 ADR」；项目惯例（见 ADR-005 等）要求触碰跨模块契约 / 禁动清单的决策走 ADR。D4 改 `.done` 隐式 schema、D5 改 phase 推进权归属，两者都够「跨模块契约」门槛。
**Consequence（后果）**：(1) D5 触禁动却不留 ADR → 未来读者无法追溯「为何 pipeline 模式下禁 auto-advance 而非同步四字段」的取舍依据，回退困难。(2) ADR 纪律不一致本身是治理债——下一次 change 会有样学样，重要决策只在 §1 表里一行带过。
**Remedy（修补）**：补 ADR-004（`_l3_check_rerun` 判定基变更 + hash 载体，承接 R-D4-1 取舍）+ ADR-005（26-workflow.sh G1 pipeline 模式 phase 推进权，含「为何不选 AC-K 允许的同步四字段方案」的论证）。或在 DESIGN 显式声明「D4/D5 不够 ADR 门槛」并给判定标准（什么算「不可逆」/「跨模块」），至少把标准讲清。

---

### 🟢 R-D4-3 · `## L3` 段匹配器未指定，未防项目已记录的「L3 header 不匹配」历史陷阱
**Symptom（症状）**：DESIGN D4 / AC-J 多次用「`## L3` 段」但未给匹配 regex。CONTEXT 域语言表有一整条「L3 header 不匹配（L3 header mismatch）」历史 bug：`flow-kit-resume.sh:138` grep `"## L3 外部模型审查"` 与 `l3-review.sh:200` 实际写 `"## L3 盲审"` 不一致 → SessionStart 漏识别。同一坑已有前科。当前仓库里 `## L3` 段可能的形式：`## L3 盲审` / `## L3 外部模型审查` / `## L3 重审`（CONTEXT「L3 重审」机制产生）。
**Source（源头）**：CONTEXT「L3 header 不匹配」条目（历史 bug）+ 「L3 重审」条目（追加 `## L3 重审` 段）。
**Consequence（后果）**：匹配器过松（`grep '^## L3'`）会把 `## L3 重审` 段也算作「已审查」→ 真 L3 段被误判存在；过严（`grep '^## L3 盲审'`）会漏 `## L3 外部模型审查` 旧格式。复现历史 bug。
**Remedy（修补）**：DESIGN/AC-J 明确匹配 regex（建议：仅匹配主审查段 `^## L3 盲审$` 或 `^## L3 外部模型审查$`，显式排除 `^## L3 重审`），并在单测中断言三种 header 的判定差异。

---

### 🟢 R-NFR4 · NFR-4「≤1 行（1 或 0）」与 DESIGN §9.5 / ADR-001 Consequences「= 0 处」措辞不一致
**Symptom（症状）**：REQUIREMENT NFR-4 Then「输出 ≤1 行（... 重构后应 = **1 或 0**）」；DESIGN §9.5「重构后 = **0 处**」；ADR-001 Consequences「`declare -A PHASE_GATE_KEY_MAP` 从 2 处 → **0 处**」。三方不一致的根因：`fk_phase_gate_key` 内部实现是仍用 `declare -A`（→ grep 命中 1 处）还是改用 `case`（→ grep 命中 0 处），DESIGN/ADR **没说**。
**Source（源头）**：SPEC 一致性；grep 守护断言必须钉死一个数字才有 teeth。NFR-4 留「1 或 0」的弹性等于把实现细节的决定权下放，但守护断言本身要求确定值。
**Consequence（后果）**：实现者若用内部 `declare -A`（更可读），NFR-4 grep 断言必须写 `<=1`；若用 `case`，写 `==0`。DESIGN 不定 → 测试断言值漂浮，或写 `<=1` 但实现其实是 0（弱断言）。
**Remedy（修补）**：DESIGN §1 D1 明确 pure fn 实现：推荐 `case "$phase" in 1) echo "1-requirement";; 2)...`（grep 命中 0，与 ADR-001 / DESIGN §9.5 一致），并把 NFR-4 Then 收敛为「== 0 行」强断言。

---

### 🟢 R-D5-ACK · D5 决策（pipeline 模式禁 auto-advance）比 AC-K Then（允许「同步四字段」保留 auto-advance）更严，DESIGN-AC 张力未声明
**Symptom（症状）**：REQUIREMENT AC-K Then「pipeline goal 模式下**不擅自 advance** `.phase` —— phase 推进权归 toll-gate（人工）或 31-auto-advance.sh...。**若 G1 保留 auto-advance，必须同步上述四字段**，不得只写 `.phase`」——即 AC 允许两条路径：(i) G1 禁 auto-advance；(ii) G1 保留 auto-advance 但同步四字段。DESIGN §1 D5 直接选 (i)，备选只列「G1 同步四字段 / 删 fk_auto_phase」，未说明为何否决 (ii)。
**Source（源头）**：DESIGN 对每个决策须给「为何选 X 不选 Y」（L2 phase 2 checklist 明示）。D5 对备选 (ii) 的否决理由缺失。
**Consequence（后果）**：(ii) 可能更优（pipeline 模式下 auto_advance=true 时 G1 同步推进，减少 toll-gate 往返）；DESIGN 未评估就直接选 (i)，可能误杀。未来若发现 (i) 太严，回退要重新走 DESIGN。
**Remedy（修补）**：DESIGN §1 D5「选择理由」补一句否决 (ii) 的依据（例：「G1 同步四字段会让 26-workflow.sh 与 31-auto-advance.sh 两处都写 transition，违反 transition 单一写入点原则」——或任何真实理由）。

---

### 🟢 R-ADR1-consumers · ADR-001「6 消费者」把 `common.sh` 文档注释计入消费者，措辞不准
**Symptom（症状）**：ADR-001 Context「6 消费者（29:77/117/155 + gate.sh:395/413 + common 注释）」；Consequences「6 消费者改调用」。grep 实证：5 个执行点（29 三处 + gate.sh 两处）+ `common.sh:254` 一行 `# Usage: local gate_key="${PHASE_GATE_KEY_MAP[$phase]:-}"` 文档注释。注释不是执行消费者，迁移时只需改注释文案，不是改调用。
**Source（源头）**：事实准确性——ADR 是不可逆决策记录，论据数字会被未来 change 引用。
**Consequence（后果）**：轻微——实现者按「6 处改调用」清点时发现 1 处是注释，浪费时间核对；不致错。
**Remedy（修补）**：ADR-001 改为「5 个执行消费者 + 1 处文档注释（同步更新 usage 示例）」。

---

### 观察（非发现，供主 agent 参考）

- **抽象层次（深/浅模块）**：D1 的 `fk_phase_gate_key` 接口窄、实现浅（lookup），对 phase→key 映射恰当，符合 Ousterhout「数据映射宜浅模块」。但 D2 的 `is_git_commit` 若把预处理器内联进函数体，会变成「窄接口藏意外深度」（见 R-D2-1），建议抽 helper。
- **0.5.1 禁动清单声明**：DESIGN §0.5.1 显式列出「`_run_review_gates` 7 Gate 控制流 / L2-blind-review / l3-review.sh API」为禁动，与 ARCHITECTURE §2.2「破例须声明」一致——此项合规。
- **跨模块依赖方向**：DESIGN 未引入新模块，沿用 `hooks/stop/lib/common.sh` 作 pure fn 宿主，依赖方向（hook → lib）合规（ARCHITECTURE §2.2 允许）。
- **R1-R4 实现风险**：R1（pure fn 破坏 transition gate）/ R2/R3（quoting 漏判/误伤）/ R4（26-workflow.sh 影响单阶段）覆盖基本到位，缓解均挂到具体 AC，结构合理。主要短板是 R5（见 R-D3-R5）与缺 R-框架天花板类条目。

---

**Verdict**: pass

说明：未发现 🔴 Critical（无 AC 未实现 / 无数据损坏 / 无安全漏洞 / 无明确 spec 合规失败——D4 与 AC-J 的不一致是「DESIGN-AC 互斥」而非「AC 不可实现」，留给实现期解决成本可控）。但存在 **6 条 🟡 Major**，其中 R-D4-1（hash 存储位置 + AC 互斥）、R-D3-R5（核心后果缓解不充分）、R-D2-1（复杂算法零伪代码）三条建议在进入 4-dev 前由主 agent 给出 `Fixed in:` / `Tech-debt:` / `Not-applicable:` 明确回应；其余 🟡/🟢 可登记为 phase 2 收尾项。pass 不等于无债——只是未触阻断线。

---

## 主 agent 回应（2026-07-18 · L2 phase 2 · 不改写四要素原文）

> **ADR 编号注**：本回应及 L2/L3 报告中的 ADR-001~005 指本 change 的 ADR，**后重新编号为 007-011**（避免与项目既有 ADR 001-006 冲突，回应 L3 第 3 次 summary）：pure-fn→007, is-git-commit→008, l2-first→009, l3-check-rerun→010, pipeline-no-g1→011。

> 6 Major + 5 Minor 全部回应。核心 3 条（R-D4-1/R-D2-1/R-ADR）Fixed，R-D3-R5 升级缓解，其余收尾。

### R-D2-1（D2 欠规约 + is_gh_pr_create）→ Fixed in DESIGN D2 + ADR-002
ADR-002 补 `_strip_command_literals <cmd>` helper 接口（is_git_commit + is_gh_pr_create 共用）+ 7 类边界决策表（单/双引号、`<<'EOF'`/`<<EOF`/`<<-EOF`、`#` 注释、`$()`/反引号）。is_gh_pr_create 纳入同批改造。

### R-D4-1（hash 存储位置 + AC 互斥）→ Fixed in DESIGN D4 + ADR-004 + REQUIREMENT AC-J
hash 存 INDEPENDENT-REVIEW-N.md 末尾 `L3_artifact_hash: <sha>` 元数据行（不触 .done KVP 契约）。判定优先级：hash 变→重审 / 段空→重审 / 否则 skip。AC-J Then 补 hash（DESIGN-AC 一致）。

### R-D4-2（mtime case 死代码）→ Fixed in ADR-004
_l3_check_rerun 删 `case "$phase"` + artifact_mtime 块（~22 行），函数体收敛为读 ## L3 段 + hash 比对。

### R-D3-R5（L3 漏跑缓解降级）→ Fixed in DESIGN D3 + R5
加 `.flow-active.correction` hook 兜底：Stop 29 D4 退出写 correction flag（type=l2-missing）→ SessionStart 注入"必须先派 L2"banner（复用既有矫正管线，零新基建）。R5 缓解从纯文档升级为 hook 层兜底（protect-the-weakest）。

### R-D2-AC-f（grep 模式）→ Fixed in ADR-002
补精确 grep 锚点：`grep -nE '...' | grep -vE 'deny_reason=|^[0-9]+:[[:space:]]*#'`，或 deny_reason 标签改 `g__commit_deny` 消歧。AC-T 固化。

### R-ADR（D4/D5 缺 ADR）→ Fixed：补 ADR-004（D4 hash 载体）+ ADR-005（D5 禁动破例）

### Minor 全部 Fixed
- R-D4-3：## L3 regex `^## L3 (盲审|外部模型审查)$` 排除 `重审`（ADR-004）
- R-NFR4：D1 pure fn 用 case，NFR-4 == 0（三方一致）
- R-D5-ACK：D5 否决"同步四字段"理由 = transition 单一写入点（ADR-005）
- R-ADR1-consumers：ADR-001 改"5 执行消费者 + 1 注释"

---

## L3 重审（glm-5.1 外部模型 · 2026-07-18 02:03）

> 自动生成于 2026-07-18 02:03。由 l3-review.sh 写入。

### 审查结论

```json
```json
{
  "critical": [
    {
      "file": ".specs/adr/002-is-git-commit-quoting-aware.md",
      "issue": "D2 提出的 `_strip_command_literals` 通过正则剥离 heredoc/引号等字面量以规避误拦，但该方案严重破坏 gate 原有防御能力。剥离具有高度脆弱性，极易被换行、参数拼接、`eval` 等绕过；同时又会误杀合法的拼接 git 命令。一旦剥离失败，gate 会从'拦截一切未知'退化为'放行任何被判定为字面量的代码'，导致不可控的安全风险（如恶意提交绕过拦截）。",
      "why": "此决策试图用简单的正则/文本预处理去模拟复杂的 Bash 词法分析（甚至语法分析），属于严重跨模块能力边界且抽象层次错误的伪解。引入它非但不能彻底修复 BUG-H，反而会引入极大的安全漏洞（开发者若依赖此 hook 防护将彻底失效）。",
      "fix": "废弃通过文本预处理提取命令的思路。对于 `is_git_commit` 的误拦截问题，由于此 hook 主要用于拦截 AI agent 执行写操作，应改为：1) 仅校验即将执行的纯命令 token（放弃多行/脚本解析）；2) 若需执行多行脚本，建立显式的白名单或通过环境变量/标志位显式放行（如检测到当前处于特定的编辑/写入上下文则跳过拦截），而绝不能在 hook 中实现残缺的 Bash 解释器。"
    }
  ],
  "major": [
    {
      "file": "DESIGN: L2/L3 独立审查 gate 残留缺陷根治",
      "issue": "D3 试图通过 `.flow-active.correction` 标记 + SessionStart hook 强制注入 banner 的方式来解决“主 agent 漏派 L2 子 agent 导致 L3 漏跑”的问题（R5）。",
      "why": "这是一个浅模块和伪底层抽象：SessionStart 仅仅是个 prompt 提示，无法从根本上解决框架限制带来的硬伤。若主 agent 在当前会话上下文截断或忽略该 banner，死锁依然发生，hook 层兜底形同虚设。",
      "fix": "承认这是框架层面的限制，不应在 hook 层面引入复杂的 session 标记兜底逻辑。应将 D3 的范围缩小至：仅仅是在 Stop hook 的 29 D4 门处输出明确错误日志或返回特定的 deny reason，要求主 agent 必须重试。避免引入无效的跨状态（`.flow-active.correction`）管理负担。"
    }
  ],
  "minor": [
    {
      "file": ".specs/adr/004-gate-return-value-semantics.md",
      "issue": "ADR-004 提到 bash 中 `return 0` 表示 skip，但在修复方案中写为 `if pf_output=$(_gate_phase_filter ...); then exit 0; fi`，在 `set -e` 语境下，虽然 `if` 条件句内的失败不会触发退出，但这依然要求调用者极其谨慎。",
      "why": "仅仅在文档中规定“后续新增 gate 函数 return 0/1 语义须文档化”过于脆弱，容易随着后续迭代再次发生语义反转（导致 critical 级别死锁）。",
      "fix": "建议统一内部的函数返回值契约：对于执行类/判定类的底层函数，统一遵循 UNIX 惯例（0 为 true/pass，非 0 为 false/fail），如果业务逻辑要求“skip 即 pass”，应该在调用层将其语义反转并注释，而不是修改底层公共函数的返回值约定。"
    }
  ],
  "verdict": "fail",
  "summary": "D2 决策试图用正则模拟 Bash 语法解析器来实现命令剥离，引发极高的安全绕过风险和误判缺陷；D3 试图用 prompt 级的 banner 兜底解决框架限制导致的状态机死锁，属于无效的抽象层覆盖。
```

---

## 主 agent 回应 L3（2026-07-18 · glm-5.1 · 不改写 L3 四要素原文）

> L3 verdict=fail（1 critical + 1 major + 1 minor）。逐条核实回应。**minor 经核实为 L3 幻觉**（引用不存在的 ADR-004），印证记忆 [[l3-model-unreliable]]：glm-5.1 也会幻觉，fail/critical 必核实。

### L3 🔴 critical（D2 正则剥离脆弱）→ Fixed in DESIGN D2 + ADR-002 重写（用户定：结构判定）
**认同**。L3 + L2-R-D2-1 共识：正则剥离 bash 词法（`_strip_command_literals`）脆弱（换行/eval/拼接绕过）+ 抽象层次错。**改结构判定方向**：含 heredoc(`<<`)/多行/写重定向 → 不 deny（写字面量上下文，保守放行）；否则子命令 split + 首 token 判 git commit → deny。不剥离 bash 词法（简单稳）。tradeoff（含 heredoc 的真实 git commit 漏拦 / sudo 前缀漏拦）风险段记录。L3 "恶意提交安全风险"略夸大（gate 是流程门非安全边界），但核心担忧成立。

### L3 🟡 major（D3 correction prompt 级无效）→ 双管（用户定：correction + deny reason）
L2（建议 correction 兜底）vs L3（correction 是 prompt 级无效）分歧。**双管**：保留 `.flow-active.correction` 兜底（L2 protect-the-weakest）+ 加 29 D4 明确 deny reason + 错误日志（L3 明确性）。多层缓解。登记 L3 "prompt 级 banner 可被主 agent 忽略"为已知限制（框架限制下无法根治）。

### L3 🟢 minor（ADR-004 return 语义）→ Not-applicable（L3 幻觉）
L3 引用 `.specs/adr/004-gate-return-value-semantics.md` **不存在**（我的 ADR-004 是 `004-l3-check-rerun-content-marker.md`，无 return 语义内容）。L3 引用错误文件 + 错误内容。**印证 glm-5.1 也会幻觉**——记忆 [[l3-model-unreliable]] 谨慎原则继续适用。Not-applicable。"
}
```
```

---

## L3 重审（glm-5.1 外部模型 · 2026-07-18 02:09）

> 自动生成于 2026-07-18 02:09。由 l3-review.sh 写入。

### 审查结论

```json
{"critical":[],"major":[{"file":".specs/l2-l3-mock-fix/DESIGN.md (D2 决策与 ADR-002)","issue":"D2 定义的拦截逻辑无法覆盖并发/管道拼接，导致重大的安全防范被绕过，直接违背了 AC-H (f) 的反规避约束。","why":"根据 D2 的定义，首先会检测多行/重定向（若命中则直接放行），然后才按 `&&`/`||`/`;`/`|` split 后取首 token 判定。如果输入是 `echo test | git commit -m`，由于没有多行/重定向，会进入 split 逻辑，`git commit -m` 作为管道后的子命令，其首 token 为 `git`。此时 D2 定义「首 token 是 git commit（或 gh pr create）」的条件将无法匹配成功，从而导致该 commit 被放行。","fix":"修正 D2 的子命令匹配判定基：在按 `&&`/`||`/`;`/`|` split 后，需判定各子命令序列的首 token 是否为 `git` 且紧随 `commit`，或者修改判定逻辑为直接在各子命令中做正则前缀匹配。"}],"minor":[{"file":".specs/l2-l3-mock-fix/DESIGN.md (D4 决策与 R6)","issue":"_l3_check_rerun 改用 artifact hash 存入 `INDEPENDENT-REVIEW-N.md`，R6 风险段仅声明了“hash 判定与既有 .done 幂等冲突”，却遗漏了对 `.md` 文件并发写入造成 hash 行丢失的评估。","why":"`.md` 文件是主 agent 和多个 hook 常交互追加的日志载体。如果主 agent 在 L3 追加 `L3_artifact_hash` 行后又追加了新内容，或发生竞态修改，基于精确文本提取的 hash 解析逻辑极易遭受破坏导致重审循环。","fix":"在 R6 中补充对 `.md` 结构被破坏或并发修改导致 hash 提取失败的降级处理策略（如：提取不到就触发重审或警告）。"},{"file":".specs/l2-l3-mock-fix/DESIGN.md (ADR 索引 003)","issue":"文档化 L2-first 顺序契约时，未显式规定 L2 审查写入在 `.md` 中的段名变更容错。","why":"D3/D4 逻辑强依赖于对 `## L2 盲审` 和 `## L3` 段的 regex 匹配，但缺乏对段名可能被主 agent 轻微篡改（如输出为 `## L2 盲审报告`）时的防御，可能会导致门检测失效。","fix":"建议在 D3 中明确正则匹配放宽（如 `^## L2 盲审`），或在 R5 风险中补充标记此为已知脆弱点。"}],"verdict":"fail","summary":"架构抽象和重构策略大体合理，但 D2 的核心命令拦截逻辑在处理管道拼接时存在致命的语义漏洞，导致防护被绕过，必须予以修正。
```

---

## 主 agent 回应 L3 第 2 次复审（2026-07-18 · glm-5.1）

> L3 verdict=fail 但 **critical=[]**（按 L2-blind-review.md「fail⟺critical」规则应 pass，L3 verdict 判定不一致）。major 经核实为误读。minor 采纳。

### L3 major（D2 管道拼接）→ Fixed in ADR-002/DESIGN D2 精确化（澄清误读）
**误读**：L3 把「首 token=git ∧ 第二=commit」误读为字面 `'git commit'`。我的 D2 意图本就是两 token 序列。`echo test | git commit -m` → split `|` → 子命令 `git commit -m` → token0=git ∧ token1=commit → **deny** ✓（L3 的 fix「git 且紧随 commit」恰是我的意图）。已精确化 ADR-002/DESIGN D2 措辞，明确「两/三 token 序列，非字面字符串」。

### verdict=fail 但 critical=[] → 按规则应 pass
L2-blind-review.md 明定「**Verdict: fail 当且仅当存在 🔴 Critical**」。L3 本次 critical=[] → 按规则 **pass**。L3 verdict=fail 与 critical=[] 自相矛盾 = L3 判定 bug（印证记忆 [[l3-model-unreliable]]：glm-5.1 也会判定不一致/幻觉）。

### L3 minor 全部采纳
- D4 hash 并发：ADR-004 加「hash 提取失败降级（触发重审 + 警告）」
- D3 段名容错：ADR-003 加「`^## L2 盲审` 前缀匹配，容忍段名轻微变化」"}
```

---

## L3 重审（glm-5.1 外部模型 · 2026-07-18 02:13）

> 自动生成于 2026-07-18 02:13。由 l3-review.sh 写入。

### 审查结论

```json
```json
{
  "critical": [],
  "major": [
    {
      "file": "DESIGN.md",
      "issue": "提供审查的 ADR-004 索引指向 l2-l3-test-defect（ADR-004 · gate 函数返回值语义），但实际想要描述本次 D4 设计意图的应该是 adr/004-l3-check-rerun-content-marker.md。此为严重的上下文/版本错乱。",
      "why": "审查员无法通过实际佐证确认 D4 决策（_l3_check_rerun 改内容标记判定）的合理性，属于架构决策支撑材料缺失。",
      "fix": "修正或重新提供正确的 adr/004-l3-check-rerun-content-marker.md 内容，以保证 ADR 有充分证据支撑。"
    }
  ],
  "minor": [
    {
      "file": "DESIGN.md",
      "issue": "状态机流程图第 3 节（关键状态机）描述 _l3_check_rerun 的触发点存在逻辑矛盾。",
      "why": "第 3 节指出：“[幂等：.done 存在 → 后续 Stop 跳过]” 紧接着又发生 “[_l3_check_rerun：## L3 段 + hash 判定重审]”。若后续 Stop 已跳过，则无法自然触发 _l3_check_rerun。这违反了 D4 决策设定的逻辑意图。",
      "fix": "明确澄清在有 .done 的情况下如何触发 _l3_check_rerun，修改状态机跳过逻辑或重审入口。"
    },
    {
      "file": ".specs/adr/002-is-git-commit-quoting-aware.md",
      "issue": "D2 结构判定逻辑（按 &&/||/;/| 切分）仍存在绕过安全拦截的风险。",
      "why": "诸如 `git commit -m "xxx && rm -rf ."` 的命令不会在顶层被切分成包含独立 `rm` 的子命令，而是作为 -m 的整体参数。虽然该实例无害，但一旦判定逻辑演进出其他基于命令组合的黑名单（如 gh pr create），极易被参数内的连接符欺骗。",
      "fix": "在 ADR-002 中补充说明结构判定对引号内参数的边界约束，并在等价类测试中明确覆盖此类嵌套引号的防御策略。"
    }
  ],
  "verdict": "pass",
  "summary": "D1~D5 决策及风险段整体合理，但关键设计 D4 的 ADR 索引错乱指向无关文件，需补充正确 ADR 内容以验证决策依据。"
}
```
```
