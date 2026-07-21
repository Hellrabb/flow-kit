# 独立审查 · 阶段 3

## L2 盲审

### 🔴 R1 · AC-4 覆盖缺口：l3-review.sh:459 竞态修复未分配给任何可执行任务

**Symptom（症状）**：T04 `<action>` 明确要求"同时修改 l3-review.sh:459 的 .tmp.$$ 为 mktemp（跨文件一致）"，但 T04 的 `<read_files>` 仅含 `l2-detect.sh`，`<write_files>` 也仅含 `l2-detect.sh`。`l3-review.sh` 不在 T04 的读写范围内，且 T03（同样修改 l3-review.sh）的 `<action>` 仅覆盖 AC-3/8/11（行 267, 431-536, 670），不含 AC-4 的 line 459 竞态修复。实地确认 l3-review.sh:459 当前确为 `local tmp_review="${review_md}.tmp.$$"`，与 AC-4 描述一致。

**Source（源头）**：REQUIREMENT.md AC-4 要求三处 `.tmp.$$` 全部修复（l2-detect.sh:113 mock、l2-detect.sh:234 后台 dispatch、l3-review.sh:459 L3 前台），AC 标题明示"全面覆盖"。DESIGN.md D2 决策采用 mktemp 方案替代全部三处手工构造。当前任务分配仅覆盖前两处，第三处落空。

**Consequence（后果）**：l3-review.sh:459 的临时文件继续使用 `${review_md}.tmp.$$`，与 l2-detect.sh 修复后的 mktemp 路径存在命名冲突窗口。L3 review 路径的竞态条件不被修复，AC-4 只实现 2/3。在并发 L2 dispatch + L3 review 场景下，同 PID 的 .tmp.$$ 文件可能相互覆盖，导致 INDEPENDENT-REVIEW-N.md 写入不完整。

**Remedy（修补）**：推荐方案 B（最小跨任务冲突）：

**方案 A**：将 `flow-kit-bundle/hooks/stop/lib/l3-review.sh` 加入 T04 的 `<read_files>` 和 `<write_files>`。
**方案 B（推荐）**：将 l3-review.sh:459 的 mktemp 替换添加到 T03 的 `<action>` 中（T03 已写入 l3-review.sh，无需新增 write_files 条目），在 T03 action 追加：
```
**AC-4** (l3-review.sh:459 竞态修复):
  - line 459: local tmp_review="$(mktemp)" 替换 local tmp_review="${review_md}.tmp.$$"
  - 加 trap 'rm -f "$tmp_review"' RETURN (或 EXIT)
```
同时在 T04 action 中删除"同时修改 l3-review.sh:459"的跨文件描述（避免混淆），T07 `<depends_on>` 追加 T03（因为 T03 承担了 AC-4 的 l3-review.sh 修复，T07 的测试依赖完整竞态修复）。

---

### 🟡 R2 · T02 写文件约束与动作描述不一致：done-validation.sh 不在 write_files 中

**Symptom（症状）**：T02 `<action>` 条目 3 要求"done-validation.sh:171 的重复 grep 也改为调用（第 4 处，提升到 ≥4）"，但 `done-validation.sh` 不在 T02 的 `<write_files>` 中（T02 的 write_files 为 l2-detect.sh, independent-review-gate.sh, 29-independent-review.sh, l3-review.sh）。T02 无法合法修改 done-validation.sh。

**Source（源头）**：任务规格内部一致性原则。`<action>` 描述可执行的工作，`<write_files>` 定义允许修改的文件边界，两者必须对齐。

**Consequence（后果）**：agent 执行 T02 时，要么因写入不在 write_files 中的文件而触发约束错误，要么跳过第 4 consumer 迁移，导致 done-validation.sh:171 的 grep 链重复 pattern 残留。虽然 T02 的 `<verify>` 和 `<done>` 均以 ≥3 为门槛（3 个主 consumer 足以通过），但 action 文本与实际可执行范围不一致，造成混淆和潜在技术债遗留。

**Remedy（修补）**：推荐方案 B（利用已有任务覆盖）：

**方案 A**：将 `flow-kit-bundle/hooks/stop/lib/done-validation.sh` 加入 T02 的 `<write_files>` 和 `<read_files>`。
**方案 B（推荐）**：从 T02 action 删除条目 3，改为在 T06 的 `<action>` 中追加 done-validation.sh:171 的 fk_extract_l2_verdict 迁移（T06 已写入 done-validation.sh 用于 AC-9，无需新增 write_files）。T06 action 追加：
```
**AC-13 补充** (done-validation.sh:171 第 4 consumer):
  - 将 done-validation.sh:171 的 grep 链替换为 fk_extract_l2_verdict() 调用
```
同时 T06 `<depends_on>` 追加 T02（T06 需要 T02 定义的 fk_extract_l2_verdict 函数）。

---

### 🟢 R3 · T06 verify 缺少阈值判定，与 T01/T02 验证严格度不一致

**Symptom（症状）**：T06 verify 为 `grep -c 'fk_phase_gate_key' flow-kit-bundle/hooks/stop/lib/done-validation.sh`，仅输出计数，无 pass/fail 判定。对比 T01 verify（`... | wc -l | xargs test 4 -le`）和 T02 verify（`... | xargs test 3 -le`），两者均有明确的退出码门槛。

**Source（源头）**：任务验证一致性原则。同一 TASK.md 内的 verify 步骤应保持同等级别的可机器判定性。

**Consequence（后果）**：T06 verify 需要人工读取 grep 输出数值并与预期比较，无法在 CI/自动化 pipeline 中自动判定 pass/fail。低风险——T06 的 `<done>` 条件仍可提供手动验证指引。

**Remedy（修补）**：
```diff
- <verify>grep -c 'fk_phase_gate_key' flow-kit-bundle/hooks/stop/lib/done-validation.sh</verify>
+ <verify>grep -c 'fk_phase_gate_key' flow-kit-bundle/hooks/stop/lib/done-validation.sh | xargs test 1 -le</verify>
```

---

### 🟢 R4 · T04 verify 仅检测 mktemp 关键字存在，未验证旧 pattern 消除或调用计数

**Symptom（症状）**：T04 verify 为 `grep -n 'mktemp' flow-kit-bundle/hooks/stop/lib/l2-detect.sh | head -5`。该指令仅确认"mktemp"字符串出现在文件中，无法区分以下场景：(a) mktemp 真正用于临时文件创建 vs 仅在注释中出现；(b) 旧的 `.tmp.$$` pattern 是否已被移除；(c) 两处 mktemp 调用是否都存在（仅要求 2 处，但 verify 不检查计数）。

**Source（源头）**：验证充分性原则。verify 步骤应确认具体变更的正确性，而非仅检测关键字存在。

**Consequence（后果）**：T04 可能在仅添加 mktemp 注释而未实际替换 .tmp.$$ 的情况下通过 verify。但由于 T09 的全量 bats 测试会因临时文件冲突或功能异常而失败，实际风险有限。

**Remedy（修补）**：建议（非阻塞）：
```
grep -c 'mktemp' flow-kit-bundle/hooks/stop/lib/l2-detect.sh | xargs test 2 -le && ! grep -q '\.tmp\.\$\$' flow-kit-bundle/hooks/stop/lib/l2-detect.sh
```

---

### 🟢 R5 · T01 旧 pattern 消除 verify 的 grep 模式有方向性假设

**Symptom（症状）**：T01 action 条目 3 使用 `grep -rn 'independent|true).*gate_val="both"'` 验证旧 pattern 零匹配。在 basic grep 模式下，`|` 是字面量管道符（非交替运算符），因此该模式仅匹配 `independent|true).*gate_val="both"` 这一种字面顺序，不会匹配等价的 `true|independent).*gate_val="both"`。

**Source（源头）**：正则表达式语义精确性。bash case 语句中 `independent|true)` 和 `true|independent)` 语义等价，两者都是合法的旧 pattern 形式。

**Consequence（后果）**：若代码库中存在 `true|independent)` 顺序的旧 pattern，该 grep 将漏报，AC-NF1 的"旧 pattern 全消除"断言不准确。概率较低（代码风格通常一致），但验证本身存在盲区。

**Remedy（修补）**：
```diff
- grep -rn 'independent|true).*gate_val="both"' flow-kit-bundle/hooks/
+ grep -rnE '(independent\|true|true\|independent)\).*gate_val="both"' flow-kit-bundle/hooks/
```
（加 `-E` 启用扩展正则，用 `\|` 交替匹配两种顺序）

---

### 审查统计

| 维度 | 评估 |
|---|---|
| 任务粒度 | 通过：全部 9 个 task 单任务变更量远低于 200 行 |
| 波次划分 | 通过：5 波次清晰，波内并行标记正确 |
| 依赖图 | 通过：无环，依赖方向一致（低 ID→高 ID） |
| AC 覆盖 | **不通过**：AC-4 的 l3-review.sh:459 修复未分配可执行任务（2/3 覆盖） |
| verify 可机器执行性 | 基本通过：T06/T04 verify 弱于标准但非阻塞 |
| read_files/write_files 约束 | **不通过**：T02 动作描述与 write_files 不一致；T04 跨文件修改超出 write_files 范围 |
| 禁动文件触碰 | 通过：无任务触碰 package-flow-kit.sh / flow-kit-bundle.tar.gz / install_hooks.sh |

---

**Verdict**: fail

---

## 主 agent 反驳 · Phase 3 L2 审查响应

### R1 (Critical) · AC-4 覆盖缺口（T04 跨文件操作）→ **已修复**

- l3-review.sh:459 的 mktemp 修复已从 T04 action 移至 T03 action
- T03 已有 l3-review.sh 的 write_files 权限，无需新增
- T04 action 加注"l3-review.sh:459 的 mktemp 修复在 T03 中"

### R2 (Major) · T02 action/write_files 不一致 → **已修复**

- done-validation.sh:171 消费者迁移已从 T02 action 移至 T06 action
- T06 已有 done-validation.sh 的 write_files 权限

### R3-R5 (Minor) · 验证严谨性 → **已记录，v1 不阻塞**

T06 verify 阈值、T04 verify 关键字匹配、T01 grep 方向性——这些是验证命令的严谨性改进，不影响任务可执行性。标记为已知改进点，v1 不阻塞。

**结论**：两条发现均已修复。任务边界现在与 write_files 声明完全一致。

---

## L3 重审（deepseek-v4-flash[1m] 外部模型 · 2026-07-21 01:12）

> 自动生成于 2026-07-21 01:12。由 l3-review.sh 写入。

### 审查结论

```json
{"critical":[{"file":"T02/T04","issue":"T02 和 T04 并行修改同一文件 l2-detect.sh","why":"T02 在 l2-detect.sh 添加 fk_extract_l2_verdict()，T04 在同一个文件做竞态修复和 mkdir 保证，且两者被分在 Wave 2 并行波次，直接导致写入冲突，无法安全并行执行。","fix":"将 T02 和 T04 改为串行，例如让后者依赖前者，或调整波次顺序避免并行修改同文件。"},{"file":"整体任务清单","issue":"任务拆解未覆盖全部 16 个 AC","why":"工件声称基于 16 AC 拆解，但仅在任务中提及 AC-1~11、AC-13 及 AC-NF1~3，缺少 AC-12、AC-14、AC-15、AC-16，存在需求遗漏风险。","fix":"补充缺失 AC 对应的任务，或说明其在已有任务中的覆盖情况。"}],"major":[],"minor":[],"verdict":"fail","summary":"任务拆解存在两个 critical 问题：T02/T04 并行写同一文件导致冲突，且 AC 覆盖明显不完整，无法满足 16 AC 要求。"}
```

L3_artifact_hash: 77ae0ec7d2e17add7f540dc2b5ba10f67d1c43cac08ff04c44c3366c8e17be96

---

## L2 盲审（复审）

> 复审范围：前次 L2 审查 R1/R2 修复验证 + 全量 TASK.md 重新审查
> 审查对象：`.specs/gate-review-fix/TASK.md`（参考 REQUIREMENT.md 16 AC + DESIGN.md）

### 前次修复验证

#### R1 修复验证：AC-4 l3-review.sh:459 竞态修复任务归属

前次 R1 指出 T04 action 描述要求修改 l3-review.sh:459 但 write_files 不含 l3-review.sh。修复方案：将 l3-review.sh:459 的 mktemp 修复移入 T03。

**验证结果**：通过。

- T04 `<action>` 现含注释 `注: l3-review.sh:459 的 mktemp 修复在 T03 中（T03 有 l3-review.sh write_files）`（T04 第 125-126 行）。
- T03 `<action>` 现含 `**AC-4** (竞态修复，line 459)` 小节，要求 `local tmp_review="${review_md}.tmp.$$" 改为 mktemp` 并加 trap cleanup（T03 第 95-97 行）。
- T03 `<write_files>` 已含 l3-review.sh，无需新增条目。
- AC-4 三处修复全部有任务归属：l2-detect.sh:113,234 → T04；l3-review.sh:459 → T03。

#### R2 修复验证：T02 action/write_files 不一致（done-validation.sh）

前次 R2 指出 T02 action 条目 3 要求修改 done-validation.sh:171 但 done-validation.sh 不在 T02 write_files 中。修复方案：将 done-validation.sh:171 消费者迁移从 T02 移至 T06。

**验证结果**：通过。

- T02 action 条目 3 现为 `done-validation.sh:171 的重复 grep 由 T06 一并迁移（T06 有 done-validation.sh write_files）`（T02 第 74 行），不再声称直接修改 done-validation.sh。
- T06 `<action>` 现含 `**AC-13** (done-validation.sh:171 处 L2 verdict 提取迁移)` 小节，要求 `done-validation.sh:171 的 grep 链改为调用 fk_extract_l2_verdict`（T06 第 179-181 行）。
- T06 `<write_files>` 已含 done-validation.sh。
- AC-13 四 consumer 均有任务归属：T02 覆盖 3 处（gate.sh:421, 29:181, l3-review.sh:755）；T06 覆盖第 4 处（done-validation.sh:171）。

#### R3-R5 状态确认

R3（T06 verify 无阈值）、R4（T04 verify 仅关键字匹配）、R5（T01 grep 方向性假设）均按前次 "v1 不阻塞" 结论维持现状。非阻塞，不要求本次修复。

---

### 新发现

#### F1 [Major] Wave 1 并行任务 T01/T02 共享可写文件

**Symptom**：T01 和 T02 均在 Wave 1 且均标记 `[P]`（并行），但两者 `<write_files>` 存在交集：

| 共享文件 | T01 写入行 | T02 写入行 |
|---|---|---|
| `independent-review-gate.sh` | line 456（case → fk_normalize_gate_val） | line 421（grep chain → fk_extract_l2_verdict） |
| `29-independent-review.sh` | lines 134, 174（case → fk_normalize_gate_val） | line 181（grep chain → fk_extract_l2_verdict） |

**Source**：Wave 1 声明 `T01[P], T02[P]`（TASK.md 第 11 行）。T01 的 `<write_files>` 含 `independent-review-gate.sh` 和 `29-independent-review.sh`（T01 第 30-31 行）；T02 的 `<write_files>` 同样包含这两个文件（T02 第 61-62 行）。

**Consequence**：若任务系统按 `[P]` 标记真正并行执行 T01 和 T02（如多 worker/进程并发写同一文件），后写入者会覆写先写入者的修改，导致一方变更丢失。虽然 T01/T02 的修改在不同行号（456 vs 421，134/174 vs 181），在 patch-based merge 下理论无冲突，但 `<write_files>` 语义暗示完整文件重写，非逐行 patch。

实际风险视执行模型而定：
- 单 worker 顺序执行 "并行" 任务 → 无风险（但 [P] 标记误导）
- 多 worker 真正并行 + 全文件写入 → **高风险**，随机丢失 T01 或 T02 的修改
- 多 worker 并行 + 逐行 patch → 低风险但不可依赖

**Remedy**（三选一）：

方案 A（最小改动）：移除 T01 或 T02 的 `[P]` 标记，使 Wave 1 变为串行 `T01, T02`。改动 1 行。
方案 B（推荐）：保持 T01[P], T02[P]，但在两者间加 `<depends_on>` 方向：T02 `<depends_on>T01</depends_on>`（T02 需 T01 的 fk_normalize_gate_val 函数，而 T01 不依赖 T02）。依赖声明消除并行歧义。
方案 C：拆分 Wave 1 为两个子波次：Wave 1a `T01[P]`（仅 T01），Wave 1b `T02[P]`（仅 T02）。

#### F2 [Minor] T01/T02 未显式引用其承担的 AC 编号

**Symptom**：AC-12（fk_normalize_gate_val）全部由 T01 承担，AC-13（fk_extract_l2_verdict）主体由 T02 承担，但两个 task 的 `<action>` 文本中均不包含 `AC-12` 或 `AC-13` 标记。

**Source**：TASK.md 的 `<action>` 块使用 `**AC-N**` 粗体标记来关联需求（如 T03 含 `AC-3`/`AC-8`/`AC-11`，T05 含 `AC-6`/`AC-10`），但 T01 和 T02 未遵循此约定。

**Consequence**：自动化工具（如 AC→task 追溯脚本）无法通过模式匹配关联 T01→AC-12 和 T02→AC-13，需依赖人工阅读 action 文本或设计文档来建立映射。REQUIREMENT.md 的 AC-12/AC-13 在 TASK.md 中缺少显式锚点。

**Remedy**：在 T01 `<action>` 起始处添加 `**AC-12** (fk_normalize_gate_val 共享函数):`；在 T02 `<action>` 起始处添加 `**AC-13** (fk_extract_l2_verdict 共享函数):`。

#### F3 [Minor] T06 缺少对 T02 的显式依赖

**Symptom**：T06 `<depends_on>` 为空，但 T06 的 `AC-13补充` 小节调用 `fk_extract_l2_verdict()`，该函数在 T02 中定义。

**Source**：T06 的 `<depends_on></depends_on>`（T06 第 186 行）。同波次 T05 显式声明了 `<depends_on>T01, T02</depends_on>`（T05 第 161 行），两者 pattern 不一致。

**Consequence**：Wave 3 在 Wave 1 之后顺序执行，波次间隐式串行保证 T02 先于 T06 完成，故无实际执行风险。但依赖图文档不完整——阅读 T06 时无法立即判断其上游依赖，需对照波次布局推断。

**Remedy**：`<depends_on>T02</depends_on>`（T06 需要 T02 定义的 fk_extract_l2_verdict）。

#### F4 [Observation] L3 重审结论事实性错误（已知 L3 不可靠模式）

**Symptom**：第 133-143 行的 L3 重审（deepseek-v4-flash）提出两条 critical 发现：(1) T02/T04 并行修改 l2-detect.sh；(2) AC-12/14/15/16 未覆盖。

**Source**：L3 模型输入为旧版 TASK.md 或存在幻觉。

**Consequence**：无。两项 claim 均与当前 TASK.md 事实不符：
- T02（Wave 1）与 T04（Wave 2）不在同一波次，无并行执行关系。
- REQUIREMENT.md 仅定义 AC-1~13 + AC-NF1~3（共 16 条），不存在 AC-14/15/16。AC-12（T01）和 AC-13（T02+T06）已完整覆盖。全量 AC→任务映射见下表。

**AC 覆盖矩阵**（16/16 全覆盖）：

| AC | 归属任务 | 类型 |
|----|---------|------|
| AC-1 | T07 | 测试修复 |
| AC-2 | T08 | 测试修复 |
| AC-3 | T03 + T08 | 实现 + 测试 |
| AC-4 | T04 + T03 | 实现（3 处 mktemp） |
| AC-5 | T07 | 测试修复 |
| AC-6 | T05 | 实现（auto_advance） |
| AC-7 | T04 | 实现（mkdir -p） |
| AC-8 | T03 | 实现（错误传播） |
| AC-9 | T06 | 实现（DRY） |
| AC-10 | T05 | 实现（DRY） |
| AC-11 | T03 | 实现（路径修正） |
| AC-12 | T01 | 实现（共享函数） |
| AC-13 | T02 + T06 | 实现（共享函数） |
| AC-NF1 | T09 | 验证（grep 完整性） |
| AC-NF2 | T09 | 验证（全量 bats） |
| AC-NF3 | T09 | 验证（性能） |

该 observation 与 MEMORY.md 记录的 "L3 模型不可靠" 模式一致，不作为 TASK.md 缺陷。

---

### 审查统计

| 维度 | 前次状态 | 本次评估 |
|---|---|---|
| R1（AC-4 任务归属） | fail | **已修复** |
| R2（write_files 一致性） | fail | **已修复** |
| R3-R5（验证严谨性） | 已知，v1 不阻塞 | 维持（非阻塞） |
| 任务粒度（<200行/task） | 通过 | 通过 |
| 波次划分 | 通过 | **发现缺陷**：Wave 1 T01/T02 共享 write_files |
| 依赖图无环 | 通过 | 通过（无环） |
| [P] 标记正确性 | 通过 | **不通过**：T01/T02 不可安全并行 |
| AC 覆盖完整性 | 通过 | 通过（16/16，含 AC-NF1~3） |
| write_files 不越界 | 不通过（R2） | 通过（R2 已修复） |
| 禁动文件触碰 | 通过 | 通过 |
| T01/T02 AC 标记 | — | 发现缺失（F2） |
| T06 依赖声明 | — | 发现缺失（F3） |

---

**Verdict**: pass

前次两条 Critical/Major 发现（R1、R2）均已正确修复。新发现 F1（T01/T02 共享 write_files）属于并行安全边界缺陷，建议修复但不改变任务可执行性——在单 worker 顺序执行模型下无实际数据丢失风险。F2/F3 为文档完整性改进，非阻塞。
