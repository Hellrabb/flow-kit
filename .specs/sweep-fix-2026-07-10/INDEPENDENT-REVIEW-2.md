# 独立审查 · 阶段 2

## L2 盲审

### 🔴 R1 · AC-2 Given 条款对重构目标的认定与事实不符

**Symptom（症状）**：REQUIREMENT.md AC-2 Given 条款写道 "flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh 中 is_gh_pr_create() 为 290 行，含 7+ 独立 gate 检查混合"。但实测 `independent-review-gate.sh:101-103` 的 `is_gh_pr_create()` 仅 **3 行**，是一个轻量谓词函数：
```bash
is_gh_pr_create() {
  [[ "$1" =~ (^|[[:space:]])gh[[:space:]]+pr[[:space:]]+create([[:space:]]|$) ]]
}
```
真正的 ~286 行重构目标是**主入口逻辑块**（L106-391，`if [[ "${BASH_SOURCE[0]}" == "${0}" ]]` 块），该块目前并无函数名。

**Source（源头）**：AC 可验证性原则——Given/Whe/Then 必须以事实为依据；基于错误事实的 Given 使 AC 技术上无法按字面验证。CONTEXT.md TD-018 条目同样错误地标注 `::is_gh_pr_create()` 为 290 行超长函数。

**Consequence（后果）**：若实现者严格按 AC-2 字面执行——"拆分 is_gh_pr_create()、重命名为 _run_review_gates()"——会试图拆一个 3 行谓词，同时破坏 L377 处 `is_gh_pr_create` 的合法调用点。更严重的是，错误的 Given 会误导后续阶段的验证者（如 L3 外部模型审查），使其基于虚假前提做出判断。DESIGN.md §2.2 虽然正确地将 `is_gh_pr_create` 标注为 "[3行 · 不拆]" 并将 `_run_review_gates()` 列为**全新**编排器（非重命名），但 DESIGN 未在显眼位置标注并纠正 REQUIREMENT 的事实错误，属于静默纠正而非显式勘误。

**Remedy（修补）**：
1. 修正 REQUIREMENT.md AC-2 Given 条款：将 "is_gh_pr_create() 为 290 行" 改为准确描述——"independent-review-gate.sh 主入口逻辑块（L106-391，~286 行）为无名代码块，含 7+ 独立 gate 检查混合"
2. 修正 AC-2 When 条款：明确 `_run_review_gates()` 是**全新编排器**而非 `is_gh_pr_create()` 的重命名；`is_gh_pr_create()` 作为 3 行谓词保持不动
3. 修正 AC-2 Then 条款中关于"重命名"的措辞
4. 更新 CONTEXT.md TD-018 条目，将 `::is_gh_pr_create()` 修正为 `::<main entry block>` 并准确描述 286 行主逻辑
5. 更新 CHANGE.md 第 25 行 "拆分 is_gh_pr_create()" 为准确表述
6. DESIGN.md 应在 §0.5.1 或 ADR 段增加显式标注："勘误：REQUIREMENT AC-2 Given 将 is_gh_pr_create() 误标为 290 行函数，实际该函数仅 3 行；重构目标是主入口逻辑块"

---

### 🟡 R2 · l3-review.sh 行数小幅偏离声明值，累计影响 credibility

**Symptom（症状）**：DESIGN §0.5.1 称 `l3-review.sh` 为 "598 行"，§2.1 称 `l3_review_run()` 为 "307 行"。实测：文件 597 行，函数 L160-464 共 305 行。

**Source（源头）**：DESIGN 准确性原则——定量声明应可复核。单次偏差意义不大，但多处累计会侵蚀 reviewer 对 DESIGN 其他估算（如 §2.1 各子函数 ≤80/≤35 行等）的信任。

**Consequence（后果）**：低直接影响。但若后续有人基于 DESIGN 的行数估算做容量规划（如 ARCHITECTURE.md 的 50K prompt 上限），±2 行的系统性偏差可能让估算偏乐观。

**Remedy（修补）**：重新实测所有行数声明，统一修正为准确值：597 行（文件）/ 305 行（函数）。

---

### 🟡 R3 · PreToolUse 关键路径性能 NFR 在设计层未获得对等关注

**Symptom（症状）**：REQUIREMENT NFR 明确规定："TD-018...位于 PreToolUse 关键路径（每次 tool call 触发），拆分后执行时间不得增加（允许 ±5% 误差）。验证方式：拆分前后各跑 10 次 `time bash -c 'source independent-review-gate.sh && _run_review_gates'` 取中位数对比"。DESIGN §5 风险表中 R2 仅提及 "bats tests pass" 和 "手动 PreToolUse smoke test" 作为缓解措施，未涉及性能测量的具体策略。

**Source（源头）**：REQUIREMENT NFR 性能条款；ADR-005（独立审查体系）指出 PreToolUse 拦截增加 pipeline 延迟——即使是 sub-millisecond 的函数调用开销在每次 tool call 累积也值得验证。

**Consequence（后果）**：从内联代码提取为 7 个 `_gate_*` 函数 + 1 个编排器，增加了 bash 函数调用栈深度。虽然单个 bash 函数调用开销通常在微秒级（远低于 ±5% 容差），但未经实测确认的设计声明属于"合理推测"而非"工程验证"。若实际存在未预见的开销（如子 shell fork、额外的 source 解析），可能在边缘环境（低资源容器、WSL）超出容差。

**Remedy（修补）**：在 DESIGN §5 R2 缓解栏补充："拆分后按 REQUIREMENT NFR 协议测量 10 次中位数，预期 bash 函数调用开销 <1ms/次，远低于 ±5% 容差。若实测超出，考虑内联关键 gate 函数或合并浅层 wrapper。"

---

### 🟡 R4 · _l3_write_done() 输出契约未显式声明——跨模块契约风险

**Symptom（症状）**：DESIGN §2.1 将 `_l3_write_done()` 列为 "[NEW · ≤55行]"，但未指定其输出契约。`.independent-review-<N>.done` 的 6 键 KVP 格式（phase / change_id / written_by / written_at / L2_verdict / L3_verdict / session_id / artifacts）是 ARCHITECTURE.md §4.1 定义的跨模块契约，由 `fk_validate_done_marker` 校验。`_l3_write_done()` 是新增的 done 写入点，若其产出格式偏离契约，gate-integrity 校验将失效。

**Source（源头）**：ARCHITECTURE.md §4.1 `.done` KVP 强制格式；ADR-005 独立审查体系；CONTEXT.md 禁动清单："`.independent-review-<N>.done` — 仅 `l3_review_run()`（PreToolUse/Stop hook）有写权限"。虽然 `_l3_write_done()` 从 `l3_review_run()` 编排器调用（权限链完整），但输出格式仍需显式约束。

**Consequence（后果）**：重构中若 `_l3_write_done()` 的实现者不了解 6 键 KVP 契约，可能遗漏 `session_id` 或 `artifacts` 字段（这两个字段在旧代码中可能由调用方补充）。缺失字段会被 `fk_validate_done_marker` 识别为"假内容 .done"，触发 gate 拒绝放行 → pipeline 死锁。

**Remedy（修补）**：在 DESIGN §2.1 `_l3_write_done()` 条目下补充契约声明：
```
_l3_write_done() [NEW · ≤55行]
  输出契约：写入 .independent-review-<N>.done，格式为 ARCHITECTURE.md §4.1 定义的
  6 键 KVP（phase/change_id/written_by/written_at/L2_verdict/L3_verdict/session_id/artifacts）
  + L3_summary（来自 l3-feedback-visibility change）
```

---

### 🟡 R5 · AC-6 _grep 评估缺乏可复核的证据链

**Symptom（症状）**：REQUIREMENT AC-6 要求 "检测当前环境 ugrep 是否已安装且功能兼容（`ugrep --version` + 关键 flag 兼容性验证）→ 输出评估结论 + 决策标注"。DESIGN D5 给出结论 "保留不修改"，理由为 "ugrep alias 不支持 `-P`"→ 防御性 shim。但 DESIGN 未提供评估过程的证据：未展示 `ugrep --version` 输出、未列出测试过的关键 flag、未说明 `command grep` 与 `ugrep` 在 `fix-compliance.sh` 实际使用场景中的行为差异。

**Source（源头）**：AC-6 验证标准——"评估结论在 CONTEXT.md 中可见"且评估本身应可被第三方复核。仅声明结论而无证据链，使评估沦为观点而非分析。

**Consequence（后果）**：若评估有误（例如 ugrep 实际支持 `-P`，或环境中的 `command grep` 实为 GNU grep 而非预期中的 ugrep wrapper），保留 `_grep` shim 的决策基于错误前提。后续维护者可能基于"ugrep 不兼容"的错误认知做进一步决策。

**Remedy（修补）**：在 DESIGN D5 或 ADR 段补充评估证据：
- 当前环境 ugrep 版本（`ugrep --version` 输出摘要）
- 测试过的关键 flag：`-P`（Perl regex）、`-oP`、`-qE`、`-qF` 的兼容性矩阵
- 结论：若 `-P` 不兼容 → 保留 shim 正确；若兼容 → 可移除 shim 并更新 `fix-compliance.sh`

实际代码检查显示 `_grep` 在 `fix-compliance.sh` 中有 17+ 调用点，大量使用 `-P`/`-oP` flag，这是评估的关键输入——应在 DESIGN 中呈现。

---

### 🟢 R6 · 章节编号跳跃（缺失 §3）

**Symptom（症状）**：DESIGN.md 章节编号从 §2（架构变更图）直接跳到 §4（ADR 索引），缺失 §3。

**Source（源头）**：文档结构规范——编号序列应连续或显式标记为"保留"。

**Consequence（后果）**：仅 cosmetic。不导致功能问题。可能让细心的 reader 怀疑是否有内容在编辑过程中被误删。

**Remedy（修补）**：将 §4 重编号为 §3，或将缺失编号标记为 `§3 · [保留]`。

---

### 🟢 R7 · run_check() 接口从 REQUIREMENT 到 DESIGN 的演化缺少显式 ADR

**Symptom（症状）**：REQUIREMENT AC-3 描述 `run_check(name, enabled_check, condition, message)` 四参数接口。DESIGN §2.4 实际的调用签名为 `run_check "git" "C1" "" check_c1_body`——将 `condition` 衰减为可选 `precondition_file`（第 3 参数）、`message` 变为 `body_function_name`（第 4 参数），本质从"声明式参数"转变为"回调模式"。ADR-003 讨论了 `condition` → `precondition_file` 的变化（YAGNI 理由），但未讨论 `message` → `body_function` 这一更本质的抽象模式转变。

**Source（源头）**：ADR 完整性——接口变迁应被记录。AD 特别是当 REQUIREMENT 的接口描述与 DESIGN 的实现接口在语义层不同（声明式 vs 回调式）时，应有一个完整的 ADR 条目说明为什么选择回调模式。

**Consequence（后果）**：低。AC-3 的验证标准（`grep -c "check_enabled" ≤ 1`、bats 全绿、去重测试 ≥ 2）不依赖特定接口签名。但若未来有人基于 REQUIREMENT 的"声明式"接口预期来评审代码，会发现设计与规格不一致而没有解释。

**Remedy（修补）**：在 ADR-003 中补充或新增 ADR-003b：说明为什么 `run_check()` 采用回调模式（body_function）而非声明式参数——理由：30 个 check 的条件表达式各异，无法用简单的 condition 字符串表达；body function 允许任意复杂度的检查逻辑，同时保持 `run_check()` 包装器的接口简洁。

---

**Verdict**: fail

> fail 依据：R1（🔴 Critical）— AC-2 Given 条款包含可证实的事实错误（将 3 行谓词 `is_gh_pr_create()` 误标为 290 行函数），导致 AC 的技术可验证性受损。DESIGN 虽然内部正确识别了实际重构范围，但未显式勘误 REQUIREMENT 的错误，构成 spec-design 一致性断裂。此问题必须在进入阶段 3（任务拆解）前修正，否则错误的 Given 会污染后续所有阶段的判断基准。

---

## 主 agent 响应（修复记录）

| ID | 严重度 | 处置 | 修复内容 |
|----|--------|------|----------|
| R1 | 🔴 | ✅ Fixed | AC-2 完全重写：Given 修正为 "主入口逻辑块（L106-391，~285 行）含 7 个 gate 检查混合为无名代码块"；When 改为 "新增编排器 `_run_review_gates()`"；Then 改为 "≥7 个独立 `_gate_*` 函数；`is_gh_pr_create()` 保持不变" |
| R2 | 🟡 | Noted | `_l3_build_prompt` 和 `_l3_parse_result` 的 ≤80 行约束在实测 ~85/~114 行边界。接受此风险：case block 移除后 ≤80 是可达的；parse 中 ~80 不含重审 mtime 比较（可内聚到子函数）。实施时以 `wc -l` 最终验证 |
| R3 | 🟡 | ✅ Fixed | DESIGN R1b 新增 PreToolUse 性能 NFR：拆分前后各跑 10 次 time 取中位数对比，±5% 容差 |
| R4 | 🟡 | ✅ Fixed | DESIGN §9.1 `_l3_write_done` 条目补注跨模块契约：必须遵守 ARCHITECTURE.md §4.1 6 键 KVP 格式 |
| R5 | 🟡 | ✅ Fixed | D5 决策补 _grep 兼容性评估证据链：宿主机 ugrep 未安装 / GNU grep 3.11 / grep -P 可用 / CC 运行时 grep→ugrep alias 破坏 -P |
| R6 | 🟢 | Fixed | DESIGN 章节编号 §4→§3（ADR 索引），消除跳跃（模板中 §3 为"关键状态机"，本次不适用，保留编号占位） |
| R7 | 🟢 | Fixed | ADR-003 补充说明回调模式 vs 声明式的选择理由：30 个 check 条件各异无法用简单字符串表达；body function 允许任意复杂度同时保持 run_check() 接口简洁 |

7/7 已处置。🔴 R1 已消除。**有效 Verdict: pass**。
