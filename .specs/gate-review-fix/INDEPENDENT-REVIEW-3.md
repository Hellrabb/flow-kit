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
