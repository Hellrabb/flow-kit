# DESIGN: is_phase_write 重构 + gate 测试 setup 修复（refactor-independent-review-gate）

- **Change ID**: refactor-independent-review-gate
- **关联**: REQUIREMENT.md / CONTEXT.md / ARCHITECTURE.md
- **修订**: v4 · L2 第三轮 fail（Critical 1/2 · L71 变量化单词边界）增量修订。范围 = is_phase_write 重构（L69 + L73-75 + **L71**）+ regex 治理 + 测试 setup 修复。L2 三轮 + sandbox 验证（修复版 `[>][^=]` 端到端全 ✓）。
  - v3→v4 关键：L71 从"风格治理"重分类为"变量化 bug 修复"——内联 `\>[^=]` 是字面 `>`（正常），但 D2 变量化 `re='\>[^=]'` 触发 GNU 单词边界（任何含字母命令误判 redirect）。修复：变量化用 `[>][^=]` 字符类（D8）。
- **重大变更声明**: 本 change 修复 is_phase_write 的 **L73-75 regex 顺序 bug**（预存在 · gate 对 jq phase 切换漏检），恢复 gate 的 phase-transition 检测能力。这是 **gate 行为改变**（禁动清单核心链），有 spec 授权。

---

## Context（v3 · is_phase_write 重构）

L2 两轮盲审 + sandbox 实测揭示 is_phase_write 有**多层失效**，TD-011（L69 `&&` lint）只是表层：

| 层 | 问题 | 后果 | 严重度 |
|---|---|---|---|
| L69 `&&` | SC2157 lint + 意图损坏 | 无函数级行为后果（L73-75 兜底/失效）| 🟡（TD-011）|
| L73-75 regex 顺序 | `\.flow-active.*\.phase=` 要求 .flow-active 在字段名前，但真实 jq 命令字段在前 | **is_phase_write 对所有真实 jq phase-write 漏检（rc=1）→ gate phase-transition 检测对 jq 完全失效** | 🔴（新发现 · 安全隐患）|
| test setup `set +e` | 断言失效 | 全文件假绿（掩盖上述漏检 + D10 期望错）| 🔴 |
| D10 测试期望 | 期望 return 0 但 is_phase_write rc=1 | 假绿掩盖 | 🟡 |

**核心修复**：L73-75 去 `.flow-active.*` 前缀（L67 `[[ "$c" == *.flow-active* ]]` 已保证命令涉及 .flow-active，L73-75 只需测 phase 字段名存在）。sandbox 修复版验证全 ✓（真 phase-write return 0 / 非 phase-write return 1）。

**gate 行为改变**：修复后 gate 恢复正确行为——jq phase 切换（transition jq）会被 is_phase_write 检测 → 走 gate（L175 `_fk_phase_direction` forward → 查 .done）。这是 gate 设计本意（transition 要求 L2/L3 完成）。合法 transition（.done 已写）放行；裸 transition（无 .done）被拦（正确）。**不破坏合法流程**（合法 transition 必有 .done）。

## 0. 技术栈（已锁）
纯 Bash + bats-core + shellcheck + jq。

## 0.5 既有架构对齐（grep 实证 · v3）

### 0.5.1 触碰模块（gate 核心链 · 授权修改）

```
flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh：
- is_handshake_write()  L27-45  （8 regex L30-37 · 风格治理）
- is_phase_write()      L65-77  （重构核心）：
    L67  *.flow-active* 前置       不变
    L69  .tmp&&mv atomic 预筛     修复（变量存 regex · D1）
    L70  tee .flow-active 预筛    风格治理
    L71  > redirect 预筛          风格治理
    L72  else return 1            不变
    L73  .phase= 检测             修复（去 .flow-active.* 前缀 · D6）
    L74  current_phase= 检测      修复（同 D6）
    L75  phases_done 检测         修复（同 D6）
    L76  return 1                 不变
- is_git_commit() L91-92 / is_gh_pr_create() L94-95（风格治理）
- 内联 L143 / L292（风格治理）

test/test_gate_integrity.bats + flow-kit-bundle/test/test_gate_integrity.bats（两副本同步）：
- setup L30 set+e → 去除（D5）
- D10 测试体 → 改 if/then/fail + 期望修正（return 0 现在可达 · D7）
- 新增 @regress-TD011 + L73-75 回归 case

禁动（仍不碰）：
- 29-independent-review.sh / fk_validate_done_marker / l3-review.sh
- gate 校验顺序（真实性→实效性→放行 · L175/366 调用链逻辑不变）
- _fk_phase_direction() 逻辑 / 报错文案 L223/246/256
```

> **授权说明**：L73-75 在禁动清单「independent-review-gate.sh gate 核心链」内。本次修改经 `refactor-independent-review-gate` change 授权（用户"扩大修全部"决策），7-integration 在禁动清单条目加注脚。修改性质 = **修复 regex 使检测逻辑符合设计意图**（gate 本该检测 jq phase-write，L73-75 顺序 bug 导致漏检），非改变 gate 设计。

### 0.5.2 is_phase_write 设计意图（v3 · 修复依据）

```
L67  涉及 .flow-active?           → 否则 return 1（非 .flow-active 操作不关 gate 事）
L69-71  是写入模式?                → atomic-write(.tmp&&mv) / tee / redirect 三类写入
                                    非写入（纯读 cat/ls）→ return 1
L73-75  写的是 phase 字段?          → .phase= / current_phase= / phases_done
                                    是 → return 0（phase write · gate 要查 .done）
                                    否 → return 1（写 .flow-active 但非 phase 字段 · 不查 .done）
```

L73-75 的 `.flow-active.*` 前缀是**冗余且有害**的：L67 已保证 .flow-active 涉及，L73-75 只需测字段名。前缀的顺序要求（.flow-active 在前）与真实 jq 命令布局（字段名在前）相反 → 漏检。

### 0.5.3 调用链下游（AC-7）
L175 `is_phase_write` → `_fk_phase_direction`（方向判定）/ L366 → `deny_reason`。修复后 is_phase_write 对真实 jq 命令 return 0（之前漏检 return 1）→ gate 正确进入 phase-write 分支查 .done。**这是恢复 gate 设计行为，非新增逻辑**。

## 1. 决策清单

| # | 决策 | 备选 | 理由 | 代价 |
|---|---|---|---|---|
| D1 | L69 regex 存变量 | 内联转义 / grep -E | 清 SC2157 + 恢复意图 | +1 local |
| D2 | 17 处无 bug regex 统一变量存（含 L70/71/73-75 修复后）| 仅修 L69/L73-75 | 防御 + 风格一致 | diff 大 |
| D3 | 变量名 `local re_<语义>` | UPPER_SNAKE | 既有 local 风格 | 函数内重复（v2 抽 lib）|
| D4 | 不立 ADR（gate regex 变量存约定已 CONTEXT L223）；**L73-75 修复记入 CONTEXT 决策**（gate 检测逻辑修正）| 立 ADR-010 | 修复符合设计意图，无新架构决策 | — |
| D5 | test setup 去 set+e + **9 条期望非零的测试体**改 if/then/fail（或 run+$status）| 子 shell 模式 | F2 阻塞验证；**L2 第四轮 F1 实测：去 set+e 后 13 项断裂（非只 D10）**，需改 AC-1 ①-⑥（rc=2/2/2/2/1）+ D9 fail-close（rc=1）+ D7 #17-18（rc=1）+ D10 #21（rc=1）= 9 条 `[ $? -eq N ]`（N≠0）模式 | 改 setup + 9 条测试体 |
| **D6** | **L73-75 去 `.flow-active.*` 前缀，只测字段名**（`\.phase=` / `\.goal\.current_phase=` / `\.goal\.phases_done`）| 双向 regex / 重写检测逻辑 | L67 已保证 .flow-active 涉及；最小改动恢复检测；sandbox 全 ✓ | gate 行为改变（恢复正确，见 R5）|
| **D7** | **D10 测试期望修正**（修复后 is_phase_write 对 jq phase-write return 0，D10 期望 return 0 现在可达）| 豁免 D10 | D10 原期望正确，只是被 L73-75 漏检 + set+e 双重掩盖 | 改 D10 测试体 |
| **D8**（v4 新增 · v5 扩 L30）| **所有 `\>[^=]`（L30 + L71）变量化用 `[>][^=]` 字符类** | 保留 `\>[^=]` 变量化 | **实测铁证**：内联 `\>[^=]` 是字面 `>`，但变量化 `re='\>[^=]'` 触发 GNU 单词边界 → 误判。**L2 第四轮 F3**：`is_handshake_write` L30 同款 `\>[^=]`，D2 变量化同触发。`[>][^=]` 全 ✓ | **L30 + L71** regex 变量化时改 `[>][^=]` |

## 2. 数据流（v3 · 修复后）
```
工具调用 → PreToolUse independent-review-gate.sh
  → is_phase_write(cmd)?  [L67 .flow-active + L69-71 写入模式 + L73-75 phase字段]
       ↑ 修复后对 jq phase-write 正确 return 0（之前漏检 return 1）
  → L175 _fk_phase_direction（rollback / **noop** / forward 三分支）
       rollback → 放行不查 .done
       noop → 放行不查 .done（AC-3b · **L2 第四轮 F2：Case A 双引号转义 jq 走此路径, pre-existing _fk_phase_direction 限制**）
       forward → 查 .done 真实性 → 合法(.done 存在)放行 / 裸 transition deny
```

## 3. 关键状态机
N/A（gate 检测逻辑，无状态机变化）。

## 4. ADR 索引
无（D4）。L73-75 修复符合 is_phase_write 设计意图（gate 本该检测 jq phase-write），记入 CONTEXT 已锁决策（gate 检测逻辑修正）。

## 5. 风险

| # | 风险 | 影响 | 概率 | 缓解 |
|---|---|---|---|---|
| R1 | 18 处治理 + L73-75 修复 diff 大，笔误 | gate 误判 | 中 | AC-3 sandbox 对照 + bats（D5 修复后可信）|
| R2 | L69/L73-75 改变 is_phase_write 行为 | 下游 | **已分析**：L175/366 消费布尔返回值，修复恢复设计意图（AC-7 对照）| 低 |
| R3 | local 变量重复 | 长期债 | 中 | v2 抽 lib |
| R4 | F2 setup 假绿 | 验证失效 | 已确认 | D5 修 |
| **R5**（v3 新增）| **gate 行为改变：jq transition 恢复被检测**（之前漏检放行）| 合法 transition 放行；裸 transition 拦（**Case B 单引号 jq filter**）。**⚠️ Caveat（L2 第四轮 F2）**：`_fk_phase_direction` L85 grep 抓不到双引号+转义 jq filter（`current_phase = \"7\"` · Case A）→ noop → 裸 transition 放行。这是 **pre-existing `_fk_phase_direction` 限制**（禁动清单），本 change 不修，记 LESSONS + 7-integration 评估独立 change | flow skill transition（Case B）全量回归；Case A 限制记 LESSONS |
| **R6**（v4 新增）| **全文件治理（变量化）改变 regex 行为**：`\>` 内联=字面 vs 变量=GNU 单词边界（D8）；其他 regex 可能也有内联/变量差异 | 治理引入新 bug | 中 | AC-3 sandbox 对照**变量化后**完整版（非内联）+ 每处 regex 变量化后单独验证；LESSONS 记 `\>`/`\<` 内联 vs 变量教训 |

## 6. 不在范围
- 共享 regex lib 抽取（v2）
- 基线 warning 清理 SC1090/SC2034（v2）
- macOS bash 3.2 smoke（v2）
- gate shellcheck CI 门禁（v2）

## 9. 架构沉淀建议
- **9.2**：gate regex 变量存（CONTEXT L223）+ **gate 检测逻辑修正**（L73-75 顺序 bug 教训：regex 前缀冗余且与命令布局冲突 → 漏检）
- **9.5**：TD-011 降 🟡 resolved；is_phase_write 仍 gate 核心链；**新增 LESSONS**：bats setup 禁 set+e（假绿）+ regex 设计勿加与命令布局冲突的顺序前缀
- 其余 N/A

---

> R3.1：不含完整代码实现。
