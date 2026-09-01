# 独立审查 · 阶段 2

> L2 盲审（correction-hygiene-state-guard · DESIGN）· 独立审查员 · 2026-09-01
> 审查对象：DESIGN.md / ADR-024 / REQUIREMENT.md / CHANGE.md / 实现基线（33·29·correction-file.sh·weak-model-compliance.sh）

## 结论先行

Verdict: **pass**（无 🔴）。设计总体自洽：AC 全部有对应设计决策且经源码核实可实现；ADR-024 白名单与 33 号实际写入的 9 种 check 名逐字一致；D7 调查结论有实证支撑；禁动合规。发现 2 🟡（风险段遗漏 ×2）+ 3 🟢。

## 发现

### 🟡 R1 · 风险遗漏：29 号 l2-missing 整文件覆写会摧毁 compliance 条目（与 ADR-024 契约直接冲突）

**Severity**：🟡 Important

**Symptom（症状）**：DESIGN.md 风险段（L108-115 六条）未登记此交互。源码基线 `flow-kit-bundle/hooks/stop/29-independent-review.sh:27-29`：`_write_l2_missing_correction` 用 `jq -n ... > "$correction_file"` **整文件覆写**，无 compliance 保护——对照 `lib/correction-file.sh:116-117` 的 `write_model_missing_correction` 有 ADR-013 compliance-priority 条件写（`if .type=="compliance" and ((.violations // []) | length > 0) then . else $new end` + mktemp 原子写）。

**Source（源头）**：ADR-024「compliance 安全数据永不被 correction 卫生逻辑误删」的 Consequences 承诺 + ADR-013 compliance 优先精神；29 号 L27-29 覆写式写入为既成事实。

**Consequence（后果）**：时序——28 号写入 compliance 矫正（弱模型合规安全数据）→ 29 号在 gate=both 且 IR 缺 `## L2 盲审` 段时执行 `_write_l2_missing_correction` → 整个 correction 文件被 `>` 覆写为单条 l2-missing → compliance 条目永久丢失 → SessionStart 收割不到合规矫正 banner（CONTEXT 术语 weak-model-compliance 的保护目的失效）。本 change 主题即 correction 卫生、且正在 29 号新增退场逻辑——恰是修复窗口，不登记属风险段遗漏（阶段 2 checklist 必查项）。

**Remedy（修补）**：
- before：`jq -n --arg phase ... '{type:"l2-missing", ...}' > "$correction_file" 2>/dev/null || true`
- after：复用 correction-file.sh 的 compliance-priority 条件写模式（单步 jq `if .type=="compliance" and violations>0 then . else $new end` + mktemp 原子写，对齐 write_model_missing_correction L116-123）；同时在 DESIGN 风险段登记该交互，或显式移入 v2 范围。

### 🟡 R2 · AC-4「gate 非 both 触发退场」在 29 号当前结构不可达（设计-实现衔接缺口）

**Severity**：🟡 Important

**Symptom（症状）**：DESIGN.md 2.1 图 M/N 节点（L76-77「l2-missing 退场检测 → contains 匹配 → 纯 type rm / 合并标签剥离」）未标注相对 Gate 3 的插入位置；源码 `29-independent-review.sh:47-50` 中 `fk_independent_review_gate_active "$phase" "L3"` 不激活（L2-only / L3-only 模式）即 `exit 0`——退场逻辑按图所示位于其后的 K/L2 缺失判定之后，gate 非 both 时永远到不了。

**Source（源头）**：REQUIREMENT.md AC-4 触发条件「IR 文件已含 `## L2 盲审` 段（**或 gate_config 非 both**）」+ 29 号 L47-50 的 early-exit 结构。

**Consequence（后果）**：场景——gate_config 从 both 切到 L2（既有 l2-missing 残留）→ 29 号 Gate 3 直接 exit 0 → l2-missing 永不清除 → SessionStart 持续误报「L2 缺失」——恰是本 change 要消除的核心表象（CHANGE.md Why 段）。验收时 AC-4 的「gate 非 both」分支无法通过 bats 验证。

**Remedy（修补）**：DESIGN 显式指定退场检测插入点——置于 Gate 3（L47-50）**之前**、与 L3 激活判定解耦（before：图中未定；after：标注「退场检测须先于 L3 激活 early-exit，独立判断 gate 非 both / IR 含 L2 段」，并补该分支的 bats 用例）。

### 🟢 R3 · DESIGN 0.5.2 引用 28 号函数行号错误

**Severity**：🟢 Minor

**Symptom（症状）**：DESIGN.md L37 引用「28-weak-model-compliance.sh 的 write_compliance_correction + clear_compliance_correction（L81-87）」——实测 `write_compliance_correction` 在 `weak-model-compliance.sh:74`、`clear_compliance_correction` 在 `:119`；L81-87 实为 write_compliance_correction 函数体内 violations 打 layer 标签段。

**Source（源头）**：`flow-kit-bundle/hooks/stop/lib/weak-model-compliance.sh:74,119`（grep 核实）。

**Consequence（后果）**：3-task/4-dev 按行号定位会读错段；行号引用不可验证，轻微违背 DESIGN 引用惯例。

**Remedy（修补）**：L81-87 → L74（write）/ L119（clear）。

### 🟢 R4 · 2.2 状态机外来清空行未表达 foreign-state note 追加

**Severity**：🟢 Minor

**Symptom（症状）**：DESIGN.md 2.2（L86）「l2-missing+state-integrity ──33 号外来清空──> l2-missing（violations 清空）」——按 AC-9 终态，外来清空后 violations 终态 = **1 条 foreign-state note**（非空）。

**Source（源头）**：REQUIREMENT.md AC-9（终态 = 1 条 foreign-state note + l2-missing 独立条目）；DESIGN.md 2.1 图 Y 分支已画「foreign-state note 单条化」——两图综合理解一致，但单读 2.2 行会产生「清空后 violations 为空」的误导。

**Consequence（后果）**：实现者按 2.2 行实现可能漏写 note（AC-9 验收失败）；表述不一致属 ADR-019「图表须引用可验证产物」的轻微违反。

**Remedy（修补）**：2.2 该行补注「随后写入 1 条去重 foreign-state note（check=foreign_state）」，与 2.1 Y 分支对齐。

### 🟢 R5 · 工作区无关杂改（README.md / staged 文件）

**Severity**：🟢 Minor

**Symptom（症状）**：git status 显示 `README.md` +2 行「// test change 1786860884 / live-test」及 staged `dsh-scm-test-untracked.txt`——与本 change 无关（L-031 扫描确认 DESIGN 0.5.1 清单无 README.md，§5 无此内容）。

**Source（源头）**：`git status --short` / `git diff README.md`。

**Consequence（后果）**：归档阶段若一并 commit 会污染 change 边界（本 change 应为纯 hook 源码 + spec 产物）。

**Remedy（修补）**：归档前还原 README.md 并撤销无关 staged 文件；或确认其为既有测试残留后清理。

## L-031 全仓锚点扫描结果

锚点：9 check 名白名单 / `l2-missing` 合并标签 / `foreign-state` note。

| 锚点 | 命中位置 | 判定 |
|---|---|---|
| 9 check 名（corrupt_json…token_spent_unmaintained） | 33-flow-active-integrity.sh 9 处 `_fai_append_violation` 调用（L26/L68/L79/L116/L146/L163/L178/L200/L219）↔ ADR-024 L22-24 白名单 ↔ CONTEXT.md 术语表（state-integrity 类 violation） | **三处逐字一致 ✓** |
| `l2-missing` 写入/读取 | 29 号 L24-30（写，`>` 覆写）/ L69-73（both 判定）/ L189（grep `^## L2 盲审`） | 与 DESIGN 引用行号一致 ✓ |
| foreign-state / 外来判据 | 33 号 L25（`jq empty`）→ 本 change 改造点 | 一致 ✓ |

git diff 已改文件 vs DESIGN 0.5.1 触碰清单：**无源码改动**（33/29/correction-file.sh 均未改——阶段 2 正常，无「DESIGN 漏列且未改」第 4 类）；新增 `.specs/adr/024-correction-violations-scope.md`、`.specs/correction-hygiene-state-guard/`、CONTEXT.md 术语追加（+8 行）均不在禁动清单冲突面；README.md 杂改为无关项（R5）。

## 核对方向结论

1. **AC ↔ D 一一对应**：AC-1↔D1、AC-2↔D2（先去重后 FIFO ✓）、AC-3↔D3（9 种 check 枚举逐字核实 ✓）、AC-4↔D4（双态清除 + contains 匹配 ✓，触发路径缺口见 R2）、AC-6↔2.2/2.1、AC-10↔ADR-024 ✓——全部可实现。
2. **2.1/2.2 图与 D1-D7 自洽**：外来路径 type 剥离终态（l2-missing）+ AC-9 终态（1 条 foreign-state note）一致（仅 2.2 行表述瑕疵，R4）。
3. **ADR-024 白名单 9 check vs 33 号实际写入**：逐字一致 ✓（含顺序）。
4. **D7 调查支撑「外来判定边界固定」**：实证支撑 ✓——auto-checkpoint.sh（chisel-skill）L19 `jq -r '.change_id // empty'` 失败即 exit 0（jq/JSON 路径，不产 YAML）；prompts/7-integration.md:49「更新 .flow-active（change_id → null, phase → 0）」确为无格式规范的模糊指令；SKILL.md 声明 .flow-active 为 JSON。已知写入源全为 jq/JSON，「AI 手写 YAML」为最可能根因，边界固定结论成立。
5. **风险段遗漏**：R1（29 号覆写 compliance）、R2（AC-4 触发不可达）为本次发现的遗漏；28 号并发写竞争（风险 4）与合并标签组合（风险 3）已列。
6. **禁动合规**：write_files 边界符合 0.5.1；29 号例外已在 CHANGE.md 例外段登记且 DESIGN 0.5.1 引用 ✓；correction-file.sh 4 函数签名不改（新增 helper）✓；不触碰 chisel_env / gate 核心链 / 31/32/34 ✓；28 号零改动 ✓。

**Verdict: pass**

---

## 主 agent 响应（fix loop · 2026-09-01）

| 发现 | 严重度 | 处置 | 状态 |
|---|---|---|---|
| R1 29 号 l2-missing 覆写 compliance | 🟡 | 采纳全量：DESIGN 新增 **D8**（写入改 compliance-priority 条件写，复用 write_model_missing_correction correction-file.sh:116-123 范式）+ 风险段登记见 D8 引用；REQUIREMENT **AC-4 补第 2 条 And**（写入保护） | Fixed |
| R2 AC-4 退场 Gate 3 不可达 | 🟡 | 采纳全量：DESIGN 2.1 图重排——新增 M0 节点（退场检测★置于 Gate 3 L47-50 之前、与 L3 激活解耦）+ G3/O2 节点显式化 early-exit；REQUIREMENT **AC-4 补第 1 条 And**（插入点约束）；bats 用例要求由 AC-4 Given/When/Then 覆盖（gate 非 both 分支可验证） | Fixed |
| R3 28 号行号引用错误 | 🟢 | 修正 DESIGN 0.5.2 表：write:74 / clear:119（标注勘出来源） | Fixed |
| R4 2.2 状态机缺 note 追加 | 🟢 | 修正状态机行：外来清空终态 = l2-missing（state-integrity 清空 + 追加 1 条去重 foreign-state note） | Fixed |
| R5 工作区无关杂改 | 🟢 | 登记 MINOR-DEFERRED M9（README.md / dsh-scm-test-untracked.txt 非本 change 产物，归档前提醒用户处置，不在本 change 范围内动） | Deferred → M9 |

**修代码优先声明**：R1/R2 均为源码级风险的**设计层修复**（阶段 2 产物 = 设计文档；实现属阶段 4 T02/T03）。D8 + AC-4 双 And 已把 R1/R2 转为可实现、可验证的硬约束，阶段 4 verify 将逐条断言（compliance 保护冒烟 + gate 非 both 退场 bats 用例）。

---

## L2 复核（第 2 轮）

> 复核对象：主 agent fix loop 对 R1~R5 的处置 · 2026-09-01 · 全部 8 项处置逐一源码核对

### 结论先行

Verdict: **pass**。R1~R5 五项发现全部处置到位，无新增/未解决问题。D8/AC-4 引用的源码锚点（29 号 L27-29 覆写、correction-file.sh:116-123 条件写、weak-model-compliance.sh:74/:119、Gate 3 L47-50 early-exit）逐行核实均准确。

### 处置核对（Symptom/Source/Consequence/Remedy 复核）

#### R1 · 29 号 l2-missing 写入 compliance 保护 — **Fixed 确认**

- **Symptom**：DESIGN 新增 D8（L55）「29 号 l2-missing 写入改 compliance-priority 条件写（L2 盲审 R1）」，完整论证覆写危害 + 修复窗口 + 对齐范式。
- **Source**：D8 引用 `_write_l2_missing_correction`（29 号 L27-29）——源码 `29-independent-review.sh:27-29` 实测 `jq -n --arg phase ... > "$correction_file" 2>/dev/null || true` 整文件覆写 ✓ 引用准确；引用 `write_model_missing_correction`（correction-file.sh:116-123）——源码 L116-117 实测条件写 `if .type=="compliance" and ((.violations // []) | length > 0) then . else $new end` + L115 mktemp + L119 mv 原子写 ✓ 引用的 jq 条件与源码**逐字一致**。
- **Consequence**：REQUIREMENT.md AC-4 已补 **And（盲审 R1）**（L39），写入保护成为可验证硬约束（阶段 4 verify 断言点）；D8 与 AC-4 双处引用 correction-file.sh:116-123 行号一致。
- **Remedy**：已落实——D8 决策 + AC-4 第 2 条 And 子句；无残留。

#### R2 · 退场检测 Gate 3 前置 — **Fixed 确认**

- **Symptom**：DESIGN 2.1 图新增 **M0 节点**（L75）「l2-missing 退场检测（★ 置于 Gate 3 L47-50 之前 · 与 L3 激活判定解耦 · 盲审 R2）」，位于 J（jq empty 判定）之后、K（L2 缺失判定）与 G3 之前；G3（L79）`{Gate 3：L3 激活?}` + O2（L80）`exit 0（既有 early-exit；AC-4 退场已在 M0 完成）` 显式化早退路径。
- **Source**：源码 `29-independent-review.sh:47-50` 实测 `if ! fk_independent_review_gate_active "$phase" "L3"; then ... exit 0` —— Gate 3 L3 early-exit 行号引用准确 ✓；M0 置于其前 = gate 非 both 时退场仍可达（both→L2 切换场景）。
- **Consequence**：REQUIREMENT.md AC-4 已补 **And（盲审 R2）**（L38）「退场检测置于 29 号 Gate 3（fk_independent_review_gate_active L3 early-exit，L47-50）之前执行、与 L3 激活判定解耦」——AC-4「gate 非 both」分支转为可验证。
- **Remedy**：已落实——M0 节点 + G3/O2 早退 + AC-4 第 1 条 And 子句；无残留。

#### R3 · 0.5.2 行号勘正 — **Fixed 确认**

- **Symptom**：DESIGN.md L37 已改为「write_compliance_correction（:74）+ clear_compliance_correction（:119）（盲审 R3 行号勘正）」。
- **Source**：`weak-model-compliance.sh:74` `write_compliance_correction()` / `:119` `clear_compliance_correction()` 实测逐字命中 ✓。
- **Consequence**：行号引用可验证，符合 DESIGN 引用惯例。
- **Remedy**：已落实；无残留。

#### R4 · 2.2 状态机补 note 追加 — **Fixed 确认**

- **Symptom**：DESIGN.md L89 已改「l2-missing+state-integrity ──33 号外来清空──> l2-missing（state-integrity 类 violation 清空 + 追加 1 条去重 foreign-state note，盲审 R4）」。
- **Source**：与 2.1 图 Y 分支「foreign-state note 单条化」及 REQUIREMENT.md AC-9 终态（1 条 foreign-state note）三方对齐 ✓。
- **Consequence**：实现者按 2.2 行实现不会再漏写 note；AC-9 验收可达。
- **Remedy**：已落实；无残留。

#### R5 · 工作区杂改 — **Deferred → M9 确认**

- **Symptom**：INDEPENDENT-REVIEW-2.md 主 agent 响应表（L99-109）已追加处置表：R1/R2 Fixed、R3/R4 Fixed、R5 Deferred → M9；MINOR-DEFERRED.md L15 已登记 **M9**（phase 2 · 盲审 R5 · README.md test change 标记 + staged dsh-scm-test-untracked.txt · triaged(提醒) · 7-integration 归档前提醒用户处置）。
- **Source**：README.md 尾部「// test change 1786860884 / live-test」仍在（未动）——与「不在本 change 范围内动」的处置一致 ✓。
- **Consequence**：变更边界保持纯净（本 change = hook 源码 + spec 产物）；归档提醒点已登记。
- **Remedy**：已落实；无残留。

### 源码锚点二次核对

| D8/AC-4 引用锚点 | 声明行号 | 源码实测 | 判定 |
|---|---|---|---|
| 29 号 `_write_l2_missing_correction` 覆写 | L27-29 | `jq -n ... > "$correction_file"`（L27-29）| ✓ |
| `write_model_missing_correction` 条件写 | correction-file.sh:116-123 | L116-117 jq 条件 + L115 mktemp + L119 mv | ✓ 逐字一致 |
| Gate 3 L3 early-exit | 29 号 L47-50 | `if ! fk_independent_review_gate_active "$phase" "L3"; then ... exit 0`（L47-50）| ✓ |
| `write_compliance_correction` / `clear_compliance_correction` | :74 / :119 | weak-model-compliance.sh:74 / :119 | ✓ |
| M0 前置 vs 既有 L2-first quick gate（L60-73）| 设计目标态 | 现源码 L2 检测仍在 Gate 3 后——设计已规定 M0 前移，属阶段 4 实现项（T02/T03）| 设计一致，无缺口 |

**无新增发现、无未解决问题**：R1/R2 处置未引入新契约冲突（D8 条件写与 ADR-024 承诺方向一致；M0 前移不改 change_id Gate 2 语义）；R3/R4 纯行号/表述修正无副作用；M9 登记完整。

**Verdict: pass**
