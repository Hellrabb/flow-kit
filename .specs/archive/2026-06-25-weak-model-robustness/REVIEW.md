# REVIEW: 提升 flow-kit 在弱模型（幻觉多）下的鲁棒性

- **Change ID**: weak-model-robustness
- **关联**: REQUIREMENT.md（7 AC）· DESIGN.md · TASK.md · TEST.md · git diff

> 审查路径：第二轮代码质量用**路径 B 内置 6 维快查**（未调 `/brooks-review` skill）。理由：本 change 产物为 markdown 规则 + 静态 bats/check.sh，6 维衰退风险低；全自动推进下内置快查性价比更高。用户若需更严格诊断可单独跑 `/brooks-review`。

---

## 第一轮 · Spec 合规审查

### AC 实现与测试覆盖

| AC | 实现（diff） | 测试覆盖（TEST.md） | 状态 |
|---|---|---|---|
| AC-1 禁跳反问 | RULES R3.5 + 0-change/1-requirement 反问 gate | `no-skip-clarify.bats`（3 test）| ✅ |
| AC-2 证据链防幻觉 | RULES R6.1 强化 + 4-dev/2-design 证据链 | `hallucination-guard/check.sh` | ✅ |
| AC-3 关键节点 checkpoint | 4-dev §1.0（非每操作） | `checkpoint-keynodes.bats`（3 test）| ✅ |
| AC-4 范围漂移防护 | RULES R7.4 + 4-dev 复述边界 | `scope-drift-guard/check.sh` | ✅ |
| AC-5 goal 锚定 | GO.md 第五步 + 模板 | `goal-anchored.bats`（2 test）| ✅ |
| AC-6 不破坏强模型 | 加固为叠加非替换 | 既有 94 bats 全绿（0 fail）| ✅ |
| AC-7 强模型不啰嗦 | 结构刚性 + 非唠叨设计 | `strong-model-verbosity/check.sh` | ✅（静态版）|

### 范围合规

- [x] 每条 AC 被实现（7/7）
- [x] 每条 AC 被测试覆盖（链接 TEST.md）
- [x] **未引入 out-of-scope**：L4 伪双轨未做 ✓ / 运行时自动探测未做 ✓ / 阶段划分未改 ✓ / hooks/skills/.flow-active 未碰 ✓ / 模型特化未做 ✓
- [x] **无范围蔓延**：仅加了 REQUIREMENT 声明的 L1+L2+L3
- [x] **未触动 DESIGN 外架构**：改的全在 DESIGN §0.5.1 触碰清单内

---

## 第二轮 · 代码质量审查

### 2.0 TEST.md 5 轮金字塔完整性

- [x] 5 轮状态都明确（1 必跑 + 4 跳过）
- [x] 跳过轮次都有理由（性能/安全/兼容/可观测各自理由，非"暂时跳过"）
- [x] 第 1 轮每条 AC 有覆盖（7/7）
- [x] 第 2-5 轮均不适用（meta 项目无运行时/DB/API/UI），声明充分

**完整性通过**，无 🔴。

### 2.1 代码质量 · 6 维衰退风险（路径 B 内置）

| R | 维度 | 诊断（具体引用） | 级别 |
|---|---|---|---|
| R1 | 认知过载 | RULES 三段增强每段净增 < 20 行（R3.5/R6.1/R7.4），prompt 新增段（4-dev §1.0）单一职责。无超长段落 | 🟢 |
| R2 | 变更传播 | 仅增强既有 R3/R6/R7 段 + 各 prompt 局部段，未触跨模块。`Source: Refactoring · Shotgun Surgery` | 🟢 |
| R3 | 知识重复 | protect-the-weakest 哲学在 SYSTEM.md（精简声明）/ RULES R3.5·R6.1·R7.4（完整规则）/ ADR-001（决策记录）三处出现，但**分工不同非概念重复**：SYSTEM 指向 RULES+ADR，RULES 是可执行规则，ADR 是决策溯源。`Source: Pragmatic Programmer · DRY` | 🟢 |
| R4 | 偶然复杂 | 填空式 gate / 证据链 / 关键节点 checkpoint 都是必要约束，无"以后可能用到"的扩展点。`Source: Philosophy of SD · deep module` | 🟢 |
| R5 | 依赖混乱 | N/A（markdown 规则 + 纯 grep 脚本，无模块依赖） | — |
| R6 | 领域扭曲 | N/A（无业务领域模型） | — |

**结论**：0 🔴 Critical / 0 🟡 Major / 2 🟢 Minor（R1/R3 可接受，无需修）。

### 2.2 架构依赖检查

**未触发**：本次未新增/重命名顶级模块、无危险 import、未引入新中间件、未跨 ≥5 模块重构（增强既有文件内段）。

---

## 第三轮 · UI 视觉审查

**跳过**：非前端项目（flow-kit 引擎 markdown + 脚本，无 UI 文件、无 UI-DESIGN.md）。

---

## 第四轮 · 补充审查

- **4.1 技术债评估**：**未触发**（本 change 非里程碑/季度大版本/重构；CONTEXT 技术债段无强制更新需求）。
- **4.2 跨模型 spot-check**：**未触发**（无安全/认证、无并发/分布式、无 >80 行函数、覆盖率未下降——反而新增测试）。

---

## 动态门禁判定（AC-9）

无 `gate_config["6-review"]`，用默认级别：

| 检查项 | 默认级别 | 本次 | 结果 |
|---|---|---|---|
| brooks-review 🔴 Critical | critical | 0 个 | ✅ pass |
| spec 合规失败 | critical | 0 个（7/7 AC 实现+覆盖）| ✅ pass |
| 跨模型分歧 | warn | 未触发 | ⚪ skip |

**门禁通过，无 PIPELINE PAUSE**。

---

## 修复任务

无 Critical / 决定修的 Major。无需追加 `T-FIX-*`。

## 技术债同步

无需（4.1 未触发）。

---

## 结论

三轮审查通过：spec 合规 7/7、代码质量 0🔴0🟡2🟢（可接受）、UI/补充轮不适用。门禁通过。**进入 7-integration**。
