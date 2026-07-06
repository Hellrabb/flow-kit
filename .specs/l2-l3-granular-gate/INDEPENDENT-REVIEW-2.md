
---

## L2 盲审

### 审查范围

审查对象：`.specs/l2-l3-granular-gate/DESIGN.md`，对照 `.specs/l2-l3-granular-gate/REQUIREMENT.md` 的 8 项 AC。

同步阅读了实际源码以验证 brownfield 对齐声明：
- `flow-kit-bundle/hooks/stop/lib/done-validation.sh`（`fk_independent_review_gate_active`）
- `flow-kit-bundle/hooks/stop/29-independent-review.sh`（L3 调度）
- `flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh`（gate 拦截 + `fk_check_gate_config_tamper`）
- `flow-kit-bundle/flow-kit/prompts/6-review.md`（阶段 6 prompt）
- `~/.claude/skills/flow/SKILL.md`（`/flow goal` 预设解析）

---

### 发现

#### F1 · 篡改检测完全绕过新值且对存量流触发误报

- **Verdict**: fail
- **Severity**: Critical
- **Finding**: `fk_check_gate_config_tamper`（`independent-review-gate.sh:47-60`）的快照过滤条件是 `select(.value == "independent" or .value == "true")`，只检查快照中标记为 `independent`/`true` 的 key。新设计下：
  1. **新流绕过**：`/flow goal --gate-config review` 写入 `gate_config["6-review"] = "both"` → 快照中值为 `"both"` → `select()` 跳过该 key → tamper 检测完全不生效。
  2. **存量流误报（正向变更被挡）**：存量流快照值为 `"independent"`，用户用 `/flow gate-config 6-review=both` 调整为 `"both"`（合法操作）→ line 57 `cur != "independent" && cur != "true"` 触发 `changed=1` → 误报篡改，deny exit 2。
  3. **新值 `L2`/`L3` 同理**：快照写入 `"L2"` 后 tamper 检测被完全跳过；存量 `"independent"` → `"L2"`/`"L3"` 触发误报。

  这是安全不变量的破坏：tamper 检测是防 agent 绕过 review 的关键防线（D8 fail-close），新值使其对三种新模式全部失效或误伤。
- **Recommendation**: 更新 `fk_check_gate_config_tamper`，将快照过滤条件扩展为 `select(.value | IN("independent","true","both","L2","L3"))`，同时将 `cur` 的等价判定改为语义比较（`independent`/`true` ↔ `both` 视为等价，`L2`/`L3`/`both` 各自独立的开→关/删除视为篡改）。此外，存量 `independent`→`both` 应视为等价（非篡改）。建议同时将这段映射逻辑提取为共享函数，避免篡改检测和 gate 判定各自维护等价规则。

---

#### F2 · 6-review prompt 的 gate_config 存在标量/对象双模型冲突，DESIGN.md 完全未提及

- **Verdict**: fail
- **Severity**: Major
- **Finding**: `6-review.md` 对 `gate_config["6-review"]` 有两套互相排斥的语义：
  - **"动态门禁判定"段（line 30）**: 按 `gate_config["6-review"][<check>]` 索引，即期望值为 OBJECT（如 `{"brooks-review-critical":"critical"}`）。
  - **"独立 review 调度"段（line 95）**: 检测 `gate_config["6-review"] ∈ {L2,both}`，即期望值为 SCALAR 字符串。

  DESIGN.md 全文假定所有 `gate_config` 值为标量字符串（`"L2"`/`"L3"`/`"both"`），完全忽略 6-review 已有的 per-check 对象模型。当 `gate_config["6-review"] = "L2"` 时，`["6-review"]["brooks-review-critical"]` 索引返回 null → 所有检查降级为默认值（表面安全），但 per-check 精细门控功能被静默摧毁。DESIGN.md 的风险段（§4）未列出此冲突。
- **Recommendation**: (a) 在 DESIGN.md 中明确记录该冲突，承认 6-review 的 `gate_config` 为混合模型（既承载 independent-review 开关，又承载 per-check 门控级别）。 (b) 考虑将 independent-review 开关与 per-check 门控解耦到不同 key（如 `.goal.review_gate["6-review"]` vs `.goal.gate_config["6-review"]`），或规定 6-review 的 independent-review 开关单独用顶层 `independent_review` key。 (c) 若暂不解耦，至少在设计文档中记录：标量模式下 per-check 门控降级为默认值，且 `--l2-only`/`--l3-only` 会破坏 per-check 对象结构。

---

#### F3 · `--l2-only`/`--l3-only` 的 `walk` 覆写会破坏 6-review 的 per-check 对象

- **Verdict**: fail
- **Severity**: Major
- **Finding**: SKILL.md line 175 的 `jq 'walk(if type == "string" then "L2" else . end)'` 对 gate_config 做递归字符串替换。如果 `gate_config["6-review"]` 是 per-check 对象如 `{"brooks-review-critical":"critical","brooks-review-major":"warn"}`，`walk` 会把所有字符串 value 替换为 `"L2"`，结果是 `{"brooks-review-critical":"L2","brooks-review-major":"L2"}` —— per-check 门控语义完全丢失。DESIGN.md §4 风险表未列出此项。
- **Recommendation**: (a) `--l2-only`/`--l3-only` 仅应影响 `gate_config` 的顶层标量值，而非递归覆写所有嵌套字符串。将 `walk` 改为仅遍历顶层：`with_entries(.value = if .value | type == "string" then "L2" else .value end)`。 (b) 同时建议 `--l2-only` 仅覆写值为 `"both"` 或 `"L3"` 的 key（保留已为 `"L2"` 的和 per-check 对象），避免无差别破坏。

---

#### F4 · 风险段严重低估实际风险面

- **Verdict**: fail
- **Severity**: Major
- **Finding**: DESIGN.md §4 仅列出 3 项风险（R1: true 映射遗漏, R2: prompt 漏改, R3: flag 冲突），但遗漏了本审查发现的 F1（tamper 检测绕过/误报）、F2（6-review 双模型冲突）、F3（walk 破坏性覆写）。此外未覆盖：
  - `--l2-only` + 存量 `independent` 快照 → 篡改误报交互
  - L3-only 模式下 L2 verdict 提取始终为 `"fail"`（29 号 hook line 78: `l2_verdict="fail"` 默认值），需在 prompt 中告知 L3 当前处于 L3-only 模式，避免 L3 误解 `l2_verdict=fail` 的含义
  - prompt 内联映射（`independent`/`true` → `both` 注释）与 `fk_independent_review_gate_active` 函数映射的长期漂移风险
- **Recommendation**: 补充 F1-F3 所列风险到 §4，逐项标注缓解措施（如 F1 需改 `fk_check_gate_config_tamper`，F2 需记录混合模型限制，F3 需改 `walk` 为顶层遍历）。

---

#### F5 · D2 的 trade-off 未揭示双源映射维护成本

- **Verdict**: pass（决策本身合理）
- **Severity**: Minor
- **Finding**: D2 选择在 `fk_independent_review_gate_active` 内做读时映射（`independent`/`true` → `both`），代价列为"每次读取多做一次字符串比较（O(1)）"。但实际更大的代价是：6 个 prompt 的 L2 调度段**也**内联了相同的映射指令（如 `independent`/`true` 向后兼容映射为 `both`），形成双源映射。未来若需要新增向后兼容别名，需同时修改函数实现和 6 份 prompt 文本，DESIGN.md 未列出此维护成本。
- **Recommendation**: 在 D2 代价列补充"双源映射维护成本（函数 + 6 份 prompt 文本需同步更新）"。

---

#### F6 · AC-7 的 tier 适配设计缺乏显式机制说明

- **Verdict**: pass（实际实现正确）
- **Severity**: Minor
- **Finding**: AC-7 要求 gate 拦截的 done 检查按 tier 判定（L2-only 只要求 L2 done），但 DESIGN.md 的三值判定表只写了 "done 要求" 列，未说明实现机制。实际代码中 `independent-review-gate.sh:148` 调用 `fk_independent_review_gate_active "$phase"`（无 tier 参数，默认 `""` = any），依赖 `.done` 文件的存在性判定。这恰好正确——因为 L2 和 L3 都写同一个 `.done` marker——但设计文档建议补充说明机制原理。
- **Recommendation**: 在 §2 架构图或 §1 决策表中补充：gate 拦截的 done 检查复用 `fk_independent_review_gate_active` 无 tier 模式，依赖 L2/L3 共用同一个 `.done` marker 文件实现 tier 透明。

---

#### F7 · `/flow gate-config` 子命令未列出新合法值

- **Verdict**: pass（v1 范围内）
- **Severity**: Minor
- **Finding**: SKILL.md 的 `/flow gate-config <phase>=<value>` 段（line 223）合法值仅列 `independent`/`true`/`off`/`false`。新增 `L2`/`L3`/`both` 未列入。DESIGN.md §5 声明 `/flow gate-config` 的 `--l2-only`/`--l3-only` 为 v2 范围，但 `both`/`L2`/`L3` 作为 value 字面量应属 v1——否则用户无法通过此子命令设定细粒度开关。
- **Recommendation**: 在 v1 中将 `/flow gate-config` 的合法值扩展为 `both`/`L2`/`L3`/`off`/`false`，或将此变更明确列入 v2 范围并说明影响（用户暂时只能通过 `/flow goal --gate-config` 原始 JSON 设定细粒度值）。

---

### 逐 AC 覆盖核查

| AC | 要求 | DESIGN.md 覆盖 | 评价 |
|----|------|---------------|------|
| AC-1 | L2-only: L2 跑, L3 跳过 | D1/D3 + 判定表 + 架构图 | 充分 |
| AC-2 | L3-only: L3 跑, L2 跳过 | D1/D4 + 判定表 + 架构图 | 充分 |
| AC-3 | both/independent/true 向后兼容 | D2 + 判定表 + 架构图 | 功能设计充分；tamper 检测层不兼容（见 F1） |
| AC-4 | flow skill 预设写 "both" | 架构图 + 范围段 | 充分 |
| AC-5 | --l2-only flag 支持 | 架构图 + SKILL.md | 功能设计充分；walk 覆写存在破坏性（见 F3） |
| AC-6 | 29 号 hook L3 开关检测 | D4 + 架构图 | 充分 |
| AC-7 | gate 拦截 done 判定适配 | 判定表 done 列 | 功能隐含正确，但缺少显式机制说明（见 F6） |
| AC-8 | 全链路无回归 (>=309 tests) | 范围段提到 bats | 设计级无法验证，依赖实现 |

未发现覆盖盲区——所有 8 项 AC 在 DESIGN.md 中均有对应设计元素。AC-3 和 AC-5 存在实现层问题（F1、F3），但设计层意图正确。

---

### 逐决策评估

| 决策 | 备选明确 | 理由充分 | trade-off 准确 | 评价 |
|------|---------|---------|---------------|------|
| D1 | 是 | 是 | 是 | 字符串风格一致，改动最小 |
| D2 | 是 | 是 | 部分（遗漏双源维护成本） | 见 F5 |
| D3 | 是 | 是 | 是 | 单函数 + 可选 tier 设计合理 |
| D4 | 是 | 是 | 是 | 复用判定源，避免逻辑分散 |

---

### Brownfield 对齐核查

| 模块 | 声明变化 | 实际对齐 | 问题 |
|------|---------|---------|------|
| `done-validation.sh` | 新增 tier 参数 | 已实现（line 29-83） | 无 |
| `29-independent-review.sh` | 加 L3 开关检测 | 已实现（line 33） | 无 |
| `independent-review-gate.sh` | done 按 tier 适配 | gate 调用无 tier（line 148），依赖 done marker 共存 | 设计文档未说明（见 F6） |
| `fk_check_gate_config_tamper` | 未在设计中提及 | **未更新**，仅识别 `independent`/`true` | **Critical gap**（见 F1） |
| 6 个 prompt | L2 调度段更新 | 全部 6 个已更新为 `{L2,both}` | 无 |
| `flow` skill | 新增 flag + 预设写 `"both"` | SKILL.md 已更新 | walk 逻辑有问题（见 F3） |
| 禁动清单 | 6 项不碰 | 全部遵守 | 无 |

---

### 整体裁决

- **F1 (Critical)**: tamper 检测安全不变量被新值绕过，且对存量流误报——必须修复才能交付。
- **F2 (Major)**: 6-review 的双模型冲突是设计级缺口，DESIGN.md 未承认也未设计应对。
- **F3 (Major)**: `--l2-only`/`--l3-only` 的 `walk` 覆写破坏 6-review 的 per-check 门控语义。
- **F4 (Major)**: 风险段严重低估实际风险面，缺少 F1-F3 对应的缓解措施。

`L2_verdict=fail`

---

## L3 盲审（deepseek-v4-flash[1m] 外部模型 · 2026-07-06 13:37）

> 自动生成于 2026-07-06 13:37。由 l3-review.sh 写入。

### 审查结论

```json
{
  "critical": [],
  "major": [],
  "minor": [
    {
      "file": "DESIGN.md (本文档)",
      "issue": "缺失 `fk_independent_review_gate_active` 可选参数 `tier` 的默认值说明",
      "why": "若函数实现未设置默认值，已有调用方未传参将导致错误，影响向后兼容；且风险段未涵盖此问题。",
      "fix": "在 D3 或决定部分明确默认值为空字符串，并在实现中保证向后兼容；风险段增加此项。"
    },
    {
      "file": "DESIGN.md 风险段",
      "issue": "未评估与 ADR-002（L3 前置到 PreToolUse）的可能冲突",
      "why": "当前设计假设 L3 调度仍在 Stop hook，但 ADR-002 如被采纳，需要调整检测位置；若未协调，可能导致架构不一致或重复工作。",
      "fix": "在风险段增加一条：ADR-002 若被接收，当前 L3 开关检测逻辑需从 29 号 hook 迁移至 PreToolUse 拦截点。"
    },
    {
      "file": "DESIGN.md 架构图",
      "issue": "未展示函数 `fk_independent_review_gate_active` 对旧调用方（无 tier 参数）的处理流程",
      "why": "架构图仅示意新调用路径，未说明旧调用方如何触发默认行为，可能造成实现遗漏。",
      "fix": "在架构图或说明中补充：当 tier 为空或未传时，返回任一 gate 开启即成功（原行为）。"
    }
  ],
  "verdict": "pass",
  "summary": "设计整体合理，决策理由充分，向后兼容考虑到位，抽象层次得当；但存在几处信息缺失（默认值、ADR冲突、旧调用流程），建议补充后提升完整性。"
}
```
