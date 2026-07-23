# REVIEW — L2/L3 模型配置解耦（三轮审查）

- **Change ID**: l2-l3-model-config
- **diff 范围**: 9 文件改 + 3 测试新建（229 insertions, 18 deletions）
- **项目类型**: Bash 脚本（非前端 → 第三轮 UI 跳过）

---

## 第一轮 · Spec 合规审查

逐条对照 REQUIREMENT.md AC：

| AC | 实现 | 测试覆盖 | 合规 |
|---|---|---|---|
| AC-1（L3 全链 5 场景）| common.sh fk_resolve_model L3 三级链 | test_fk_resolve_model.bats L3-A..E（5/5）| ✅ |
| AC-2（L3 P1 命中·CC 不变）| fk_resolve_model P1 优先 | L3-A（真实 ANTHROPIC_DEFAULT_HAIKU_MODEL + 截断断言）| ✅ |
| AC-3（L2 全链 5 场景，无 fallback）| fk_resolve_model L2 三级链 | L2-A..E（5/5，场景 D 验证无 fallback）| ✅ |
| AC-4a/4b（降级不崩溃）| caller（l3-review/29-indep/l2-detect）model 空 → return + correction + 无 API | test_model_degradation（机制 + L3 caller 集成）| ⚠️ l3-review caller ✅；29-indep/l2-detect caller 集成 Tech-debt（机制层覆盖降级标记） |
| AC-5/5b/5c（/flow model 写/合/clear）| flow/SKILL.md /flow model jq 内联段 | test_flow_model.bats（6/6：写/合/clear/边界/防注入）| ✅ |
| AC-5d（/flow model 显示）| flow/SKILL.md | UAT 执行证据 | ✅ |
| AC-6（SessionStart 收割）| flow-kit-resume.sh 4 分支 + rm 条件化 | test_flow_kit_resume.bats（l3/l2-model-missing 不删 + compliance 删 + l2-missing 持久化）| ✅ |
| AC-7（全量回归）| — | npx bats exit 0（cp 同步双副本后）| ✅ |

**范围蔓延检查**：无（CHANGE.md out 段：不改 package-flow-kit/install/00-gate — diff 确认无越界）。
**out of scope 触动**：无。
**架构触动**：ADR-006 supersede（ADR-012，DESIGN §9 已声明）。

---

## 第二轮 · 代码质量审查（6 维衰退风险 · 内置路径 B）

> brooks-lint 已装（SessionStart 检测）。本 change diff 小（~230 行），内置 6 维手判足够；如需更全可补跑 `/brooks-review`。每维引用经典书源。

### R1 · Cognitive Overload 认知过载
- **诊断**：fk_resolve_model ~20 行单函数（三级链清晰）；caller 降级段 ~8 行（model 解析 → 空 → correction + return）；resume.sh 4 分支 if/elif（每分支单一职责）
- **结论**：✅ 无过载。Source: Code Complete · Refactoring · DDD（函数单一职责）

### R2 · Change Propagation 变更传播
- **诊断**：3 caller 改 model 解析（:?/fallback → fk_resolve_model），传播限于 caller 函数内；fk_resolve_model 是新函数（不改既有 6 个 fk_*）；correction-file.sh 追加（不改既有 4 helper）
- **结论**：✅ 传播可控。Source: Refactoring · Clean Architecture

### R3 · Knowledge Duplication 知识重复
- **诊断**：L2/L3 三级链结构相似（fk_resolve_model 内 if L3/L2），但 env var 名不同（ANTHROPIC_DEFAULT_HAIKU_MODEL vs ANTHROPIC_L2_MODEL），必要重复；compliance 优先 + correction 写入集中在 correction-file.sh（write_model_missing_correction 单一 lib 函数，DESIGN §4.2 强制），无散弹枪
- **结论**：✅ 无概念级重复。Source: Pragmatic Programmer · DRY

### R4 · Accidental Complexity 偶然复杂
- **诊断**：三级链是业务需求（ADR-012）；compliance 优先原子写是安全需求（L3 竞态）；resume rm 条件化是 bug 修复——无过度抽象
- **结论**：✅ 无偶然复杂。Source: Refactoring · Brooks No Silver Bullet

### R5 · Dependency Disorder 依赖混乱
- **诊断**：fk_resolve_model（common.sh lib）← caller source；correction-file.sh LEAF lib（无依赖）；caller → lib 方向一致（高层调低层）；source guard（type ... || source correction-file.sh）兜底
- **结论**：✅ 依赖一致。Source: Clean Architecture · 依赖倒置

### R6 · Domain Model Distortion 领域扭曲
- **诊断**：layer（L2/L3）/ model（模型名）/ correction（降级标记）/ write_model_missing（动作）—— 领域词清晰，无 data/info/item 技术词
- **结论**：✅ 无扭曲。Source: DDD · Ubiquitous Language

### 2.0 TEST.md 5 轮金字塔完整性
- 5 轮状态明确（功能✅ / 性能❌ Bash 非热路径 / 安全⚠️ jq--arg / 兼容⚠️ 跨平台核心 / 可观测⚠️ correction+banner）✅
- 跳过轮次有理由 ✅；第 1 轮每 AC 覆盖 ✅

**6 维 + 金字塔结论**：无 🔴 Critical，无 🟡 Major。代码质量合格。

---

## 第三轮 · UI 视觉审查

**跳过**：Bash 脚本项目，无 UI 文件（.css/.tsx/.vue 等均无）。非前端，第三轮不适用。

---

## 第四轮 · 补充审查

### 4.1 技术债评估
- **触发**：本 change 产生 1 项 Tech-debt（AC-4a/4b 的 29-indep + l2-detect caller 完整集成测试）
- **登记**：L2/29 caller 集成测试（l2_dispatch_prompt/29-indep 脚本复杂度高），降级机制层（test_model_degradation test 1/2）已覆盖核心标记。登记于 INDEPENDENT-REVIEW-6.md §主 agent 裁判（R1-R5 逐条分类）+ ADR-013 §Consequences（项目无独立 TECH-DEBT.md 文件，tech-debt 散落 REVIEW/LESSONS/ADR）。

### 4.2 跨模型 spot-check
- 由独立 review 机制接管（gate_config["6-review"]=both → L2 子 agent + L3 外部模型双盲，INDEPENDENT-REVIEW-6.md）

---

## 动态门禁判定（AC-9）

| 检查项 | 结果 | 级别 |
|---|---|---|
| spec 合规（AC 覆盖）| 全 AC 覆盖（AC-4 caller 部分 Tech-debt）| ✅ |
| 6 维 🔴 Critical | 无 | — |
| 6 维 🟡 Major | 无 | — |

**门禁通过**（无 🔴 Critical）。

---

## 修复任务

无 Critical，无必修 Major。Tech-debt（AC-4 caller 集成）登记，不阻塞。

## 结论

代码质量合格，spec 合规，无 Critical。可进 toll-gate 6→7。

---

## 关联发现 · 另立 change（非本 change scope）

**独立 review gate `.done` 作者性校验缺口**（握手机制死代码）：本 change phase 6 裁判 L2/L3 分歧期间核实——Gate 3 仅凭 `.done` 存在即短路放行 transition，不验作者；原用于作者性证明的握手 `.flow-active.independent-review` 写入已死（无生产 writer），检查在 gate 主流程不可达（但 4 个单元测试仍断言其安全意图）。属安全设计任务，非简单死代码；本 change（scope=模型解析）不修，**另立 `gate-done-authorship` change**（种子见 `.specs/gate-done-authorship/CHANGE.md`，含证据链 + 两种修法候选）。不阻塞本 change 交付。

**依赖关系**（phase 7 L2 R2 登记）：本 change 的 6→7 transition 合法性建立在 phase 6 的 `.done`（`written_by=main-agent-adjudicated`）上，正是该作者性缺口的具体实例。过渡期可信度由基于工件的独立核实支撑（L2 phase 7 独立复跑确认 L3 Critical 为架构误报），非机制保证。**本 change 过关依赖 `gate-done-authorship` fix 尽早落地**——建议提升为下一优先 change。
