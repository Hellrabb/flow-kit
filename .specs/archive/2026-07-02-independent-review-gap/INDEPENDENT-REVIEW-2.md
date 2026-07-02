# 独立审查 · 阶段 2

## L2 盲审

### 🟡 R1 · D1 `spec-test` 备选方案分析不充分

**Symptom（症状）**：DESIGN.md D1 列出 3 个备选名（`plan-and-test` / `req-design-test` / `full-plus-test`），但未逐一给出排除理由。仅给了 `spec-test` 的选择理由。

**Source（源头）**：ADR 原则——每个被拒绝的备选方案应有明确的排除原因，否则决策不完整。Fowler · Refactoring · Divergent Change。

**Consequence（后果）**：PRESET_MAP 预设名一旦发布即锁定（9.5 禁动清单约束），命名决策不可逆。缺少排除理由意味着未来有人问"为什么不用 plan-and-test"时，只能靠猜测回答。

**Remedy（修补）**：在 D1 中为每个备选方案加一行排除理由：
- `plan-and-test`: "plan" 语义过宽——用户可能理解为"先规划后测试"的工作流指令而非阶段集合名
- `req-design-test`: 三个单词过长，与现有单/双词预设名风格不一致
- `full-plus-test`: "full" 暗示覆盖所有阶段（类似 `all`），但实际上只有 1+2+5，名不副实

---

### 🟡 R2 · D4 死锁风险未列入 §4 风险段

**Symptom（症状）**：DESIGN.md D4 的「取舍代价」段写到"用户可能对未补 prompt 的阶段开启 gate-config，造成 pipeline 死锁"，但 §4 风险段未收录此风险。

**Source（源头）**：风险完整性原则——设计决策中显式承认的取舍代价，若可能造成用户可见故障，必须升格为正式风险条目并配缓解方案。

**Consequence（后果）**：风险"藏"在 D4 取舍代价里而不到 §4，实施和测试阶段不会对此做专门验证。

**Remedy（修补）**：在 §4 新增 R4「gate-config 开启但 prompt 未补全导致死锁」风险条目。

---

### 🟡 R3 · R2 token 成本风险概率被低估

**Symptom（症状）**：DESIGN.md R2 将 `all` 预设的 token 成本风险评为"低概率"，但 CONTEXT.md 已锁决策明确说"3/5/7 L2 默认 off...理由：避免 pipeline token 成本爆炸"——如果概率真的低，就不会成为锁决策的理由。

**Source（源头）**：风险概率判定应与既有约束一致。

**Consequence（后果）**：概率低估导致缓解投入不足。`all` 预设名自带"全选"暗示，用户可能低估成本。

**Remedy（修补）**：将概率从"低"调为"中"，并在 PRESET_MAP 注释中追加 token 成本警告。

---

### 🟡 R4 · Prompt 模板设计仅覆盖正常路径

**Symptom（症状）**：D2 的参数替换表仅覆盖正常流程参数。REQUIREMENT.md 已定义的错误处理 NFR（L2 调用失败 / verdict=fail 行为 / .done 写入失败）未在 prompt 段结构中设计对应的错误处理指令。

**Source（源头）**：设计完备性原则——NFR 中定义的错误处理语义应有对应的设计级确认。

**Consequence（后果）**：不同主 agent 对失败场景处理不一致——有的跳过 .done、有的写一半、有的静默继续。

**Remedy（修补）**：在 D2 中追加错误处理指令设计：L2 调用失败→不写 done、verdict=fail→不写 done、verdict=pass→写 done。把这 3 条写入 3/5/7 prompt 模板尾部。

---

### 🟡 R5 · NFR 设计级验证缺失

**Symptom（症状）**：REQUIREMENT.md 已包含安全/可观测/错误处理 NFR，但 DESIGN.md 中对这些 NFR 的设计级确认为零引用。

**Source（源头）**：设计完整性原则——NFR 如果不在设计阶段被显式验证，实施阶段可能被遗漏。

**Consequence（后果）**：安全 NFR / 可观测 NFR / 错误处理 NFR 在设计层无确认——实施者可能不知道需要考虑。

**Remedy（修补）**：在 DESIGN.md 新增 §6「NFR 设计验证」表，逐条对照 REQUIREMENT.md 的 NFR 并写一句话确认。

---

### 🟢 R6 · 缺少 §3（详细设计）和 §8（测试策略）段

**Symptom（症状）**：DESIGN.md 从 §2 直接跳到 §4，缺少详细设计和测试策略段。

**Source（源头）**：设计模板完整性——这两个段在 DESIGN 模板中是可选但推荐填写。

**Consequence（后果）**：实施者参考 DESIGN 时需自行推断详细模板文本，可能产生风格不一致。

**Remedy（修补）**：§3 粘贴一个阶段的完整 prompt 段模板作为示例；§8 简要说明测试矩阵（unit + integration + regression）。

---

**Verdict**: pass（无 🔴 Critical。5 项 🟡 Major 都属设计完备性提升，不阻塞推进。）
