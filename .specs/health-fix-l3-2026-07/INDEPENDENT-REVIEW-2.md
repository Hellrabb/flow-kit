# 独立审查 · 阶段 2

## L2 盲审

### 🟡 R1 · AC-1 覆盖缺口：`_l3_parse_result` 与 `_l3_build_prompt` 拆分无架构设计

**Symptom（症状）**：REQUIREMENT.md v1 范围明确要求拆分 `_l3_parse_result()`（82行→解析/校验/归档分离）和 `_l3_build_prompt()`（85行→system/user/artifact 三段），且 AC-1 将二者列为必须拆分的函数。DESIGN.md D3 仅在论述"v1 不拆主函数"时附带提及其子函数会拆分，但全文无架构图、无接口设计、无子函数描述。Section 2 的 4 幅架构图仅覆盖 `_gate_phase_transition`、`fk_fix_compliance_check`、`smart_truncate`，缺此二者。

**Source（源头）**：REQUIREMENT.md AC-1 与 v1 范围（L105-106）；DESIGN.md section 2（L113-150，仅含 3 函数拆分图，缺 `_l3_parse_result` 和 `_l3_build_prompt`）

**Consequence（后果）**：实现阶段 ad-hoc 拆分，与其他精心设计的拆分（D1/D2/D6）不一致；可能产生不符合 AC-1 ≤60 行的拆分方案；缺少子函数接口定义导致实现与测试脱节。

**Remedy（修补）**：在 DESIGN.md section 2 追加两幅架构图，遵循现有 2.2-2.4 的 before/after 模式：
- `_l3_parse_result` 82L → ~15L 编排器 + `_l3_parse_verdict()` ~25L（解析 verdict）+ `_l3_validate_result()` ~25L（校验 KVP 格式）+ `_l3_archive_result()` ~20L（写入 .done / report）
- `_l3_build_prompt` 85L → ~20L 编排器 + `_l3_build_system_prompt()` ~25L（system prompt 构造）+ `_l3_build_user_prompt()` ~20L（user prompt 构造）+ `_l3_build_artifact_context()` ~20L（产物上下文拼接）

---

### 🟡 R2 · AC-9 覆盖缺口：`29-independent-review.sh` 函数化无设计决策

**Symptom（症状）**：REQUIREMENT.md AC-9 要求将 `29-independent-review.sh` 主逻辑提取为 `_check_l2_complete()` / `_resolve_gate_value()` / `_dispatch_l3_review()` 三个函数，编排层 ≤30 行。DESIGN.md section 0.5.1 将此文件列为"既有 · Stop hook L3 派发"触碰模块，但决策清单 D1-D7 无一项涉及此函数化，section 2 无架构图，section 5 无对应风险。

**Source（源头）**：REQUIREMENT.md AC-9（L91-94）；DESIGN.md 决策清单 D1-D7（L82-91）无一覆盖此项

**Consequence（后果）**：此变更与 D1（gate 函数拆分）同属"主逻辑→编排器+子函数"模式，但缺失设计意味着实现可能与其他拆分风格不一致（如子函数命名、职责边界、编排器行数约束）；无风险覆盖意味着 Stop hook 链回归风险未被评估。

**Remedy（修补）**：追加 D8 决策项：
```
| D8 | `29-independent-review.sh` 主逻辑拆为 3 子函数 + 编排层 | 保持现状（线性脚本）/ 拆更多函数 | 3 子函数对应 3 职责（L2 检测 / gate 值解析 / L3 派发）；编排层 ≤30 行满足 AC-9；与 D1 拆分模式一致（编排器 + 职责子函数） | 编排层引入一层间接调用；但 29 号 hook 本身逻辑线性，拆分是显式化而非增加复杂度 |
```
并在 section 2 追加架构图。

---

### 🟡 R3 · 决策影响力低估：D4 解环声明为"架构层面无变化"不准确

**Symptom（症状）**：DESIGN.md section 4（L199）声明"所有决策（D1-D7）均为内部重构，架构层面无变化"，但 D4（提取 `correction-types.sh` 消除三向依赖环）改变了 `correction-file.sh` / `interactive-ui-check.sh` / `weak-model-compliance.sh` 三模块的依赖图，且 section 9.3 明确承认"cross-module contract change"（`done-validation.sh` 需被动调整 source 路径）。依赖拓扑的改变属于架构层面变化，即使外部 API 行为不变。

**Source（源头）**：DESIGN.md L199 vs L248-249 自相矛盾；ARCHITECTURE.md §2.2 将"任何两个 lib 间双向引用"列为禁止依赖方向

**Consequence（后果）**：低估 D4 风险——依赖图变更的级联效应（如 `done-validation.sh` source 路径漏改导致静默失败）在新成员或 AI agent 维护时被忽略；ADR-003（Hook 系统架构）和 ARCHITECTURE §2.2 的依赖规则被实际修改但未走 ADR 流程记录。

**Remedy（修补）**：将 section 4 声明修改为：
"本 change 不涉及不可逆决策。D1-D3、D5-D7 为内部重构；D4（解环）涉及三模块依赖拓扑变更，属架构层面微调——依赖方向从双向改为单向（共同依赖 correction-types.sh），外部 API 行为不变。ADR-003（Hook 系统架构）和 ADR-005（独立审查体系）延续。"

---

### 🟡 R4 · 风险缓解描述不准确：R5 声称 `check-gate-sync.sh` 检测 goal-parsing.md 漂移

**Symptom（症状）**：DESIGN.md R5（L214）将 `check-gate-sync.sh` / `make check` 列为 `goal-parsing.md` 漂移的缓解措施。但 CONTEXT.md L97 明确描述 `check-gate-sync.sh` 的职责为"diff prompt 和 skill 的 toll-gate 段"——即检测 toll-gate 协议漂移，而非 goal-parsing.md 共享片段漂移。当前无自动化机制检测 `goal-parsing.md` 被修改后两处 `@see` 引用是否同步更新。

**Source（源头）**：DESIGN.md R5 缓解列（L214）；CONTEXT.md L97（`check-gate-sync.sh` 实际职责定义）

**Consequence（后果）**：虚假安全感——团队可能认为漂移有自动化兜底，实际没有；一旦 `goal-parsing.md` 修改而引用者未更新，6-review 和 7-integration 的 goal 解析行为将不一致，且无人察觉直到 pipeline 行为异常。

**Remedy（修补）**：二选一：
1. 在 `check-gate-sync.sh` 或独立脚本中增加 `goal-parsing.md` 的哈希校验（两处 @see 引用的文件内容与 goal-parsing.md 源对比）
2. 更新 R5 缓解描述为真实情况："当前无自动化漂移检测，依赖 code review 和 `make check` 的提示性输出；`@see` 单源引用比两处独立维护更不易漂移，但非零风险"

---

### 🟡 R5 · 聚合变更面风险未评估：5+ 函数拆分 + 3 新文件 + 2 共享片段同时交付

**Symptom（症状）**：本次 change 同时引入：5 个函数拆分（`_gate_phase_transition`、`fk_fix_compliance_check`、`smart_truncate`、`_l3_parse_result`、`_l3_build_prompt`）+ 函数化（`29-independent-review.sh`）+ 3 个新文件（`correction-types.sh`、`goal-parsing.md`、`test_l3_timeout.bats`）+ 2 处 source 路径调整（解环三方 + `done-validation.sh` 被动调整）+ 死代码删除（`estimate_tokens`）+ self-sourcing 修复。RISK 段（section 5）仅评估了单点风险（bash 作用域 bug、source 路径错误、执行时间增加），未评估聚合风险——即多个变更交互产生的集成问题或 bisect 难度。

**Source（源头）**：DESIGN.md section 5（L206-214，5 项风险均为单点风险）；CHANGE.md（L9-35，12 项变更清单）

**Consequence（后果）**：若回归出现，定位根因需要在 10+ 文件的 diff 中 bisect；互不相关的变更（如解环 + 函数拆分）可能在 bash `source` 链中意外交互；AC-3 的全量回归测试能兜底大部分但无法覆盖所有交互路径。

**Remedy（修补）**：追加 R6 风险：
```
| R6 | 实现 | 聚合变更面大（5 函数拆分 + 3 新文件 + 解环 + 死代码清理），变更交互难预测 | 回归定位困难，bash source 链意外交互 | 中 | 高 | 分两批提交：第一批（解环 + 死代码 + self-sourcing，低风险基础设施）+ 第二批（函数拆分，高风险逻辑变更）；AC-3 全量 bats 回归（407 tests）作为集成兜底 |
```

---

### 🟢 R6 · 函数行数描述不一致：`_gate_phase_transition()` 在 DESIGN vs CHANGE 中行数不同

**Symptom（症状）**：DESIGN.md section 2.2（L118）标注 `_gate_phase_transition()` 为 175L；CHANGE.md（L15）标注为 122 lines。差额 53 行（~30%），远超注释/空行的正常浮动范围。

**Source（源头）**：DESIGN.md L118："`_gate_phase_transition() 175L`"；CHANGE.md L15："拆分 `_gate_phase_transition()` 122 行 (`independent-review-gate.sh:184-305`)"

**Consequence（后果）**：执行者无法确定函数实际规模，AC-1 的行数目标验证基准不一致；若 122 行为真（基于行号范围 184-305=122 行），则 175L 夸大规模，影响对拆分必要性的判断。

**Remedy（修补）**：统一为基于 `grep -n` 实测的行数（含注释和空行，因为 bash 函数拆分也影响注释块归属），标注实测方法。建议以 CHANGE.md 的 122 行为准（有具体行号范围可验证），更新 DESIGN.md 对应描述。

---

### 🟢 R7 · `PHASE_GATE_KEY_MAP` 缺失 phase 0 和 4 的文档说明

**Symptom（症状）**：DESIGN.md section 3.2（L175-183）的 `PHASE_GATE_KEY_MAP` 仅含 1/2/3/5/6/7 六个映射，不含 phase 0（change）和 phase 4（dev）。虽然当前 gate_config 系统不含 phase 0/4 的独立审查（排除是合理的），但 DESIGN 和接口契约均未文档化此排除的原因和使用约束。

**Source（源头）**：DESIGN.md L175-183（`PHASE_GATE_KEY_MAP` 定义缺注释）；ARCHITECTURE.md gate_config 预设中 phase 4 无独立审查

**Consequence（后果）**：未来若新增 phase 4 的独立审查，开发者可能直接往 MAP 中加 `[4]="4-dev"` 而不知道还需同步更新 PRESET_MAP、Prompt 模板、L2-blind-review.md checklist（独立审查四层架构的约束）。查表返回空字符串（`${PHASE_GATE_KEY_MAP[$phase]:-}` 的 fallback）可能导致静默跳过 gate 检查。

**Remedy（修补）**：在 `PHASE_GATE_KEY_MAP` 定义上方追加注释：
```bash
# Phase 0（change）和 Phase 4（dev）当前无独立审查 gate，有意不在此 MAP 中。
# 若未来新增，需同步更新四层架构：PRESET_MAP + Prompt 模板 + L2-blind-review.md checklist + 本 MAP。
```

---

### 🟢 R8 · `done-validation.sh` 被动变更无单独风险项

**Symptom（症状）**：DESIGN.md section 9.3（L248）提及 `done-validation.sh` 需被动调整 source 路径（从 `correction-file.sh` → `correction-types.sh`），但 section 5 风险表无此项。该文件使用 `2>/dev/null || true` 的 source 模式（CONTEXT.md 已锁定的惯例），若路径调整遗漏，失败将是静默的——done 校验逻辑悄悄跳过，而非崩溃报错。

**Source（源头）**：DESIGN.md L248；CONTEXT.md 禁动清单 L383（`.independent-review-<N>.done` 写权限归属约束）；ARCHITECTURE.md §4.1 .done KVP 格式依赖 `done-validation.sh`

**Consequence（后果）**：漏改情况下，`done-validation.sh` 的 correction 相关校验静默失效；.done 文件的 correction file 存在性检查不执行；无 crash/error 信号，问题可能长期未被发现。

**Remedy（修补）**：追加 R7 风险：
```
| R7 | 实现 | `done-validation.sh` source 路径调整遗漏 | done 校验的 correction 依赖静默失效（`2>/dev/null` 吞错） | 低 | 中 | AC-2 的 grep 交叉检测验证所有 source 引用正确；bats 测试覆盖 done-validation 路径 |
```

---

**Verdict**: pass

---

## L3 重审（deepseek-v4-flash[1m] 外部模型 · 2026-07-11 02:27）

> 自动生成于 2026-07-11 02:27。由 l3-review.sh 写入。

### 审查结论

```json
{"critical":[],"major":[],"minor":[{"file":"L3审计子系统健康修复设计","issue":"R6风险缓解的分批提交边界未明确；"self-sourcing修复"在决策中未提及，与变更面描述不一致","why":"工件R6提到分两批提交，但未给出第一批（解环+死代码+self-sourcing）和第二批（函数拆分）的具体文件清单及依赖验证方法，且"self-sourcing"修复未在D1-D8任一决策中说明，可能导致执行计划模糊","fix":"补充明确两批提交的详细文件列表、依赖关系及验证步骤（如第一批完成后全量bats通过），并解释self-sourcing修复的范围与决策关联"}],"verdict":"pass","summary":"设计整体严谨、步骤清晰，ADR决策与既有架构对齐，抽象层次合理，风险识别较全面。缺少分批执行的具体计划属于minor问题，不影响通过。"}
```
