# 独立审查 · 阶段 2

> **审查对象**: `.specs/cleanup-debt-batch-2026-08/DESIGN.md`
> **参考工件**: REQUIREMENT.md + CHANGE.md
> **审查日期**: 2026-08-03

---

## L2 盲审

### 🔴 R1 · L-070 validate_staging_coverage() 已正确退出非零 — D2 修复基于虚假前提

**Severity**: 🔴
**Symptom（症状）**: DESIGN.md:79-81, 86, 102-107
**Source（源头）**:
- DESIGN §1 D2 声称：`validate_staging_coverage()` 即使发现 error 也最终 exit 0，CI 假绿。
- 实际代码 `flow-kit-bundle/lib/validate_staging.sh:127-131`：
  ```bash
  if [ "$ERRORS" -gt 0 ]; then
    echo "   ❌ 校验失败：发现 $ERRORS 个漏配项。"
    exit 1
  ```
- 函数文档（line 8）明确约定：`# exit: 0=通过, 1=有漏配, 2=脚本自身错误`
- `package-flow-kit.sh:18-19` 以 `exit $?` 正确传播 exit code
**Consequence（后果）**: L-070 的"CI 假绿"问题描述为**事实性错误**。D2 决策基于虚假前提，实现时：
  1. 若按 DESIGN 的实现片段（array syntax `"${#ERRORS[@]}"`）修改，会操作不存在的数组而引入新 bug
  2. 若按正确方式修改，改动为 no-op（函数已有 `exit 1`，再添加冗余）
  3. 浪费 phase 3 任务拆分 + phase 4 开发 + phase 5 测试各阶段资源处理一个不存在的 bug
**Remedy（修补）**: 
  1. 确认 `validate_staging_coverage()` 当前行为（建议跑 `bash package-flow-kit.sh --validate; echo $?` 验证）
  2. 若确认 exit code 正确（预期 exit 0），则将 L-070 从本 change 移除，更新 LESSONS.md 标注 "已验证，非 bug"
  3. 若确实 exit 0 但按代码逻辑应 exit 1，说明存在更隐蔽的 bug（如被 `set +e` 的上层吞掉），需重新 root-cause 分析
  4. 无论哪种情况，DESIGN D2 需重写或移除

---

### 🔴 R2 · D2 实现文件定位错误 — validate_staging_coverage() 不在 package-flow-kit.sh

**Severity**: 🔴
**Symptom（症状）**: DESIGN.md:22, 37, 97-107
**Source（源头）**:
- DESIGN §0.5 表格第 2 行：`validate_staging_coverage() | package-flow-kit.sh | L-069/L-070 改造目标`
- DESIGN D2 实现片段（line 98-107）暗示在 `package-flow-kit.sh` 内修改
- 实际：`validate_staging_coverage()` 定义在 `flow-kit-bundle/lib/validate_staging.sh`，`package-flow-kit.sh:10` 仅 `source` + line 18 调用
**Consequence（后果）**: 按 DESIGN 实施会编辑错误的文件：
  1. `package-flow-kit.sh` 不包含 `validate_staging_coverage()` 函数体，无法在其中修改 exit code 逻辑
  2. 若误在 `package-flow-kit.sh` 加 `exit 1`，会在 `validate_staging_coverage` 调用后无条件退出（破坏正常打包流程）
  3. 若需加 M-health.md 到 cp 清单（L-069），正确位置是 Part B 内的 `install_file` 调用列表（在 `package-flow-kit.sh` 内），而非函数体
**Remedy（修补）**:
  1. §0.5 表格更正为：`validate_staging_coverage() | flow-kit-bundle/lib/validate_staging.sh | L-070 改造目标（实测已无此 bug，见 R1）`
  2. D2 明确区分两个修改点：① M-health.md cp（改 `package-flow-kit.sh` Part B）② exit code（改 `lib/validate_staging.sh`，或确认不需要改）
  3. TASK.md 拆分时确保 L-069 和 L-070 指向不同文件

---

### 🟡 R3 · L-068 D4 引用的 "§ 8" 段在 4-dev.md 中不存在

**Severity**: 🟡
**Symptom（症状）**: DESIGN.md:144, 157, 168
**Source（源头）**:
- DESIGN D4 计划抽取 "§ 8（checkpoint + auto-checkpoint + checkpoint_write() 用法）" 为 `reference/checkpoint-protocol.md`
- 实测：4-dev.md 当前结构从 §1 到 §7.2（行 198-710），**无 § 8 段**
- checkpoint 相关内容散落在：
  - `### 1.0` 行 227："关键节点 checkpoint"（3 行指令）
  - `## 中途断点` 行 716-747：入场恢复 + 中途暂停 + 任务完成后的 PROGRESS 清理
  - `### 7.1` 行 686：task_progress 写入（非 checkpoint 协议）
- CHANGE.md §5 段（行 605-665）含"提交前 diff 边界 verify"，与提交协议而非 checkpoint 有关
**Consequence（后果）**:
  1. `reference/checkpoint-protocol.md` 的抽取源不明确 — 抽取什么内容、抽取多少行均无确切锚点
  2. 若强行按 D4 规格实施，开发者需自行判断哪些行属于 "§ 8"，引入歧义
  3. 抽取后的 4-dev.md 行数估算（~220 行 + `@see` ≈ 230 行）基础不牢 — 实际能抽的行数可能少于预期
**Remedy（修补）**:
  1. 明确 checkpoint 协议的实际源：目前 4-dev.md 中 checkpoint 指令主要位于 `### 1.0`（行 232-236）和 `## 中途断点`（行 716-747），合计约 45 行
  2. D4 的抽取目标修正为：`reference/checkpoint-protocol.md` ← 从 `## 中途断点` + `### 1.0` 关键节点段 提取（约 45 行）
  3. 重新计算 4-dev.md 保留行数（D4 预期 230 行可能过于乐观，需基于实际可抽取量重估）

---

### 🟡 R4 · AC-E2 grep anchor 规格与当前 4-dev.md 标题层级不匹配

**Severity**: 🟡
**Symptom（症状）**: REQUIREMENT.md:88-91, DESIGN.md:173
**Source（源头）**:
- AC-E2 要求保留 8 个 grep anchor，其中 4 个为标题类：`^## 1.4`, `^## 5`, `^## 6$`, `^## 8`
- 实测当前 4-dev.md：
  - `### 1.4`（行 238）— h3 层级，非 `## 1.4`
  - `### 5.`（行 605）— h3 层级，非 `## 5`
  - `### 6.`（行 677）— h3 层级，非 `## 6`
  - **无 `## 8` 或 `### 8` 任何形式**（见 R3）
- DESIGN §1 D4 行 173："所有既有 `## 1.4` / `## 5` / `## 6` / `## 8` header 保留"——将 h3 标题误述为 h2
**Consequence（后果）**:
  1. 若改造后标题从 `###` 升为 `##`，既有 bats 测试中依赖 `###` 级别的 grep 会 break
  2. 若改造后保持 `###`，AC-E2 的 `^##` 正则不会命中，AC-E2 自身 fail
  3. `^## 8` 锚点在当前文件无对应内容，改造后也无法"保留"不存在的内容
**Remedy（修补）**:
  1. AC-E2 anchor 规格修正为与实际标题层级一致：`^### 1\.4` / `^### 5\.` / `^### 6\.` 
  2. `^## 8` 替换为 checkpoint 实际锚点（如 `中途断点` 或 `### 7\.2`）
  3. DESIGN §1 D4 行 173 中的标题层级描述同步修正

---

### 🟡 R5 · D2 实现片段使用数组语法操作标量变量

**Severity**: 🟡
**Symptom（症状）**: DESIGN.md:102-106
**Source（源头）**:
- DESIGN D2 实现片段：`if [[ "${#ERRORS[@]}" -gt 0 ]]; then` — 数组长度语法
- 实际 `validate_staging.sh:26`：`local ERRORS=0` — 标量整数，非数组
- `"${#ERRORS[@]}"` 对标量变量的行为依赖 bash 版本（旧版可能返回标量长度，非预期值）
**Consequence（后果）**: 若严格按此代码实施：
  1. 在标量变量上使用数组语法，实际行为不可预测
  2. 即使无运行时错误，语义错位降低代码可读性
  3. 与 R1 联动：实际函数已有正确 `[ "$ERRORS" -gt 0 ]` 检查
**Remedy（修补）**: 若 L-070 确实需修改（先验证 R1），代码应为 `if [[ "$ERRORS" -gt 0 ]]; then`，与既有代码风格一致

---

### 🟡 R6 · D3 禁动清单 exception 行号范围不精确

**Severity**: 🟡
**Symptom（症状）**: DESIGN.md:123
**Source（源头）**:
- DESIGN 行 123："L59-185 段顺序调整"
- 实测 29-independent-review.sh（204 行）：L3 model check 在 **L58-65**，L2 detection 在 **L180-185**
- 禁动清单在 `.specs/CONTEXT.md:439`："independent-review-gate.sh + 29-independent-review.sh + fk_validate_done_marker — gate 校验核心链"
**Consequence（后果）**: 
  1. "L59" 应为 "L58"（`type write_model_missing_correction` 起始行是 58，不是 59）
  2. 行号漂移是告警信号——可能后续改动（如函数重命名、注释增删）导致行号偏移，exception 文字失准
**Remedy（修补）**: 修正为 "L58-185 段顺序调整"，且 exception 段建议用语义描述备用（"L3 model check 段(L58-65) 与 L2 detection 段(L180-185) 顺序互换"），降低行号漂移风险

---

### 🟢 R7 · D3 状态机矩阵完整且正确

**Severity**: 🟢
**Symptom（症状）**: DESIGN.md:134-141
**Source（源头）**: DESIGN §1 D3 4 场景矩阵覆盖了 L2 段存在/缺失 × L3 model 配置/未配置 的全排列
**评估**: 
- 场景 1（均否）: 旧 l3-model-missing → 新 l2-missing ✓（符合 ADR-009 L2-first 契约）
- 场景 2（L2 否 L3 是）: 新旧一致 l2-missing ✓（L2 缺失优先检测）
- 场景 3（L2 是 L3 否）: 新旧一致 l3-model-missing ✓（L2 已完成，L3 是瓶颈）
- 场景 4（均是）: 新旧一致继续 L3 ✓
- 数据流图（§2）与状态机（§3）一致，无死锁/不可达状态
**Remedy**: 无需修改。D3 决策逻辑正确，仅建议 TASK.md 中 D3 相关 task 引用此矩阵作 verify 基线

---

### 🟢 R8 · D4 沿用 ADR-018 GO.md 压缩模式合理，禁动清单 exception 有据

**Severity**: 🟢
**Symptom（症状）**: DESIGN.md:49, 123, 152
**Source（源头）**:
- D4 抽取策略引用 ADR-018（GO.md bootstrap compression）已验证模式
- 禁动清单 exception 引用 `.specs/CONTEXT.md:439` 明确的核心链条目
- Exception 说明"内部逻辑顺序调整，不动函数签名/接口/gate 行为"合理
**评估**: 设计决策有先例支撑，exception 边界清晰。风险缓和措施（全量回归 + 4 场景矩阵）充分
**Remedy**: 无需修改。R6 行号修正后即可

---

### 🟢 R9 · D3/D4 风险识别真实且缓解措施可执行

**Severity**: 🟢
**Symptom（症状）**: DESIGN.md:270-304
**Source（源头）**: §5 列出 6 项风险，每项含类型/概率/影响/缓解
**评估**:
- R1（L-072 边界）: 全量回归 + 矩阵覆盖 → 充分
- R2（弱模型跳读）: 入场段保留摘要 → 合理但非银弹，建议 TASK.md 中 D4 task 额外加 `@see` 引用验证
- R3（validate exit code）: 标注 BREAKING + CHANGELOG → 充分；但前提是 R1 的"确实需要改"成立
- R4（M-health 放错 Part）: AC-B1 验证 → 充分
- R5（AC-F4 git log 依赖）: TASK.md 显式 commit message 格式 → 充分
- R6（gate_config=all 降级）: 已降级 L2-only → 充分
**Remedy**: R2 缓解建议增强——在 4-dev.md 每个 `@see` 行下加一行"⚠️ 必须读取该文件，不可跳过"（≤1 行 per @see，不显著增加行数）

---

### 🟢 R10 · 范围外清晰，沉淀建议有价值

**Severity**: 🟢
**Symptom（症状）**: DESIGN.md:307-356
**Source（源头）**: §6 清晰列出 7 项 out-of-scope；§9 识别 4 个新可复用抽象 + 5 项项目级决策 + 4 项跨模块契约 + 4 项新禁动清单条目
**评估**: 范围外与 CHANGE.md 一致。沉淀建议中 reference/ 片段提取是真实的复用价值；`git rev-parse --verify` 模式虽小但跨脚本可复用。禁动清单新增 4 条目边界清晰
**Remedy**: 无需修改

---

### 🟢 R11 · D1 review-package ref validation 决策合理

**Severity**: 🟢
**Symptom（症状）**: DESIGN.md:54-75
**Source（源头）**: 备选 (a) `git rev-parse --verify` vs (b) 正则白名单。选 (a) 理由充分（git 官方 API，覆盖所有合法 ref，无需维护正则）
**评估**: shell injection 防范有效（git 内置 ≠ 绕过 bash 参数解析，但 `set -euo pipefail` + `--verify` 双重保护）。代价 <10ms 满足 NFR。D1 无问题
**Remedy**: 无需修改

---

## Verdict: **FAIL**

🔴 2 Critical findings：R1（L-070 修复基于虚假前提 — `validate_staging_coverage()` 已正确 exit 1）+ R2（D2 实现文件定位错误 — 函数在 `lib/validate_staging.sh` 而非 `package-flow-kit.sh`）

🟡 4 Warning findings：R3（4-dev.md "§ 8" 不存在）、R4（AC-E2 anchor 层级不匹配）、R5（数组语法误用）、R6（exception 行号不精确）

R1 是阻断级——整个 D2 决策链的根前提被实证推翻。不修此问题，L-070 将浪费实施资源修改已正确工作的代码。R2 是实施级——即使 D2 逻辑正确，改错文件会导致打包脚本损坏。

**建议**: 先验证 R1（实测 `package-flow-kit.sh --validate; echo $?`），确认后重写 D2 段或移除 L-070 从 v1 范围。R3/R4/R6 同步修正。

---

## 主 agent 响应 · cleanup-debt-batch-2026-08

> 阶段 2 DESIGN.md 修订响应 INDEPENDENT-REVIEW-2 9 项 findings。
> 遵循 `修代码优先协议`：所有 🔴 + 🟡 finding 已对应到 DESIGN.md 实际修改。

### R1 🔴 接受 · L-070 移出范围

**响应**: 实测确认（m00283: `bash package-flow-kit.sh --validate; echo $?` → exit=0 + 0 ERROR + 2 WARNING）。`validate_staging_coverage()` 函数体 `flow-kit-bundle/lib/validate_staging.sh:127-131` 早已正确 `exit 1` 当 `ERRORS > 0`，调用方 `package-flow-kit.sh:18-19` 以 `exit $?` 正确传播。

**Fixed in**:
- DESIGN.md §0.5 表格第 2 行（移除 L-070 引用 + 添加注释段说明）
- DESIGN.md D2（重写，移除 L-070 子段，仅保留 L-069 M-health.md cp）
- DESIGN.md §5 R3（标注移出范围）
- DESIGN.md §9 项目级决策（移除 validate_staging_coverage exit 1 条目）
- DESIGN.md §9 新禁动清单条目（移除 validate exit code 语义条目）
- TASK.md 将不再为 L-070 拆分 task（仅 L-069 一个 task）

### R2 🔴 接受 · 文件位置修正

**响应**: §0.5 表格 + D2 实现片段均已修正。

**Fixed in**:
- DESIGN.md §0.5 表格 L38：`validate_staging_coverage()` 路径改为 `flow-kit-bundle/lib/validate_staging.sh`
- DESIGN.md §0.5 表格 L24：package-flow-kit.sh 改为 "Part B"（仅 L-069 cp 行的位置，不再提 L-070）
- DESIGN.md D2 实现片段：明确区分 cp 行位置（package-flow-kit.sh Part B）vs validate 函数体位置（lib/validate_staging.sh，本次不动）

### R3 🟡 接受 · § 8 不存在 → 实际 checkpoint 段定位

**响应**: 4-dev.md 实际无 § 8。checkpoint 内容定位：
- `### 1.0`（行 232-236）— 关键节点 checkpoint 摘要（3 行）
- `## 中途断点`（行 716-747）— 入场恢复 + 中途暂停 + 任务完成后 PROGRESS 清理（31 行）

**Fixed in**:
- DESIGN.md D4 抽取目标 L3 行：明确为 `## 中途断点` + `### 1.0` 共约 45 行
- DESIGN.md D4 保留段：`§ 8 单行 trigger` → `## 中途断点 单行 trigger`
- DESIGN.md D4 保留行数重估：220→240 行（基于实际可抽取量）

### R4 🟡 接受 · AC-E2 anchor 层级修正

**响应**: 当前 4-dev.md 用 h3（`###`）做节标题。AC-E2 原正则 `^##` 不会命中。

**Fixed in**:
- REQUIREMENT.md AC-E2：8 个 anchor 修正为实际层级（`^### 1\.4` / `^### 5\.` / `^### 6\.` / `^## 中途断点` / `task-brief` / `model-tier` / `task_progress` / `@see reference/`）
- DESIGN.md D4 grep anchors 保留段：明确"保持原 h3/h2 层级不变"

### R5 🟡 接受 · D2 数组语法移除

**响应**: L-070 整体移出范围，D2 实现片段中数组语法代码段同步删除。

### R6 🟡 接受 · D3 禁动清单行号修正

**响应**: "L59-185" → "L58-185"，并补充语义描述（"L3 model check 段(L58-65) 与 L2 detection 段(L180-185) 顺序互换"）作为行号漂移的备用锚点。

### R7-R11 🟢 确认

无修改。D3 矩阵 / D4 ADR-018 沿用 / 风险评估 / 范围外 / D1 决策均认可。

---

**Verdict reconciliation**: 全部 🔴 + 🟡 已对应 DESIGN.md/REQUIREMENT.md 实际修订。L-070 移出范围后，本 change 由 5 fix → 4 fix（L-068/L-069/L-071/L-072）。Phase 3 TASK.md 将基于修订后的 DESIGN 拆分（预计 8-10 tasks）。
