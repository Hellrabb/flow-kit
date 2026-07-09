# CHANGE: 修 TD-011 · independent-review-gate.sh `is_phase_write` regex 治理

- **Change ID**: refactor-independent-review-gate
- **创建日期**: 2026-07-08
- **路径建议**: 完整（用户选定；虽是 bugfix，因涉及禁动清单 gate 核心链，走完整闭环留 spec 证据链，TD-011 方可从禁动清单可信移除）
- **状态**: draft

---

## Why（为什么做）

TD-011（CONTEXT.md 禁动清单 · **v2 降级 🔴→🟡**）。`independent-review-gate.sh:69` 的 `is_phase_write` 用 `[[ "$c" =~ \.tmp[[:space:]]*&&[[:space:]]*mv ]]`，`&&` 被 bash 当逻辑与劈半（SC2157 恒真）。

**L2 阶段 2 实测修正（F1 · 推翻 0-change 叙事）**：0-change 实验2b 测的**孤立 L69 regex** 确实恒真 MATCH，但**完整 is_phase_write 函数** L69 命中后 fall-through 到 L73-75（phase 字段名检测 `\.phase=` / `current_phase=` / `phases_done`），函数级返回值由 L73-75 决定。全输入（含真 atomic-write `echo > .flow-active.tmp && mv ...` + `ls .flow-active.tmp bar`）实测 **rc=1**。→ **TD-011 无 gate 行为后果**（"误报 phase write"从未发生），真实性质 = SC2157 lint + L69 atomic-write 检测器意图损坏（泛匹配 `.tmp+空格` 而非精确 `.tmp&&mv`）。主 agent 0-change 实证方法缺陷（测孤立语句非完整函数）已记 INDEPENDENT-REVIEW-2.md。

**F2（新发现 · 比 TD-011 严重）**：`test/test_gate_integrity.bats` setup line 30 `set +e` 关闭 bats errexit → 全文件 23 测试断言失效（`false`/`[ 1 -eq 0 ]`/`fn(return 1)` 全报 ok）。阻塞本 change AC-1/AC-2/AC-5 验证 + 揭示 `test-setup-path-fix-2026-07` 未真正闭合 TD-012（修了路径让函数加载，但 set+e 让断言失效，假绿性质未变）。

## What（做什么）

1. **修 line 69**（D1）：regex 存变量（`local re='\.tmp[[:space:]]*&&[[:space:]]*mv'; [[ "$c" =~ $re ]]`），**清 SC2157 lint + 恢复 L69 精确意图**（v2：非修误报，因 L73-75 兜底，函数级返回值不变）。
2. **全文件 regex 治理**（用户选定维持）：18 处 `[[ =~ ]]` 统一变量存（17 处无 bug 防御性治理 + L69 修复）。实证确认其余 17 处无 shell-meta 误判（`|`/`()`/`\>` ERE 正常）。
3. **移除** line 68 `# shellcheck disable=SC1026,SC2203,SC2157` + TODO。
4. **修 F2 测试 setup**（D5 · v2 新增）：`test_gate_integrity.bats`（两副本同步）setup 去 `set +e` + D10 测试体改 `if is_phase_write ...; then 预期; else fail; fi`（吸收 return 2，恢复 errexit 失败检测）。**F2 阻塞 AC-1/AC-2/AC-5 验证，必须本 change 修**。
5. **补测试**：`@regress-TD011` atomic-write case + AC-5 反向断言（注入 false → make test non-zero）。
6. **修 L73-75 regex**（D6 · v3 新增 · 用户"扩大修全部"）：去 `.flow-active.*` 前缀（L67 已保证 .flow-active 涉及），恢复 is_phase_write 对 jq phase-write 的检测。**gate 核心逻辑修复**（禁动清单授权）· sandbox 修复版验证全 ✓。这是比 TD-011 严重得多的预存在 bug（gate phase-transition 检测对 jq 完全失效）。
7. **修 D10 测试**（D7 · v3 新增）：D10 测试体改 if/then/fail + 期望修正（return 0 现在可达 · L73-75 修复后）。配合 D5 setup 修复，消除 D10 假绿。

## 视觉调性（前端项目必填）

N/A —— 纯 Bash hook 项目，非前端，跳过 0-change 步骤 0.6。

## 影响面

- [x] 仅修复 bug，无范围变化（核心性质）
- [x] 影响 `REQUIREMENT.md`（完整闭环新建，作为 Given/When/Then AC 载体；无既有需求被改）
- [x] 影响 `DESIGN.md`（完整闭环新建，轻量；**无新 ADR** —— 修复手法 CONTEXT.md 早有定论，无架构决策）
- [ ] 影响现有 AC（无既有 AC 被 modified）
- [ ] 影响数据模型 / 迁移
- [ ] 影响外部 API 兼容性（gate 是项目内部 hook，无外部 API）
- [x] **触及禁动清单**（CONTEXT.md `independent-review-gate.sh` gate 核心链 + 校验顺序条目 · **内容锚定不依赖行号** —— L2 R6 证行号随编辑漂移）→ 本次经 `refactor-independent-review-gate` change 授权修改，非"顺手碰"。L1 hook 合规层应识别此 spec 依据

## 范围排除（这次不做）

- **不改 gate 校验顺序**（禁动清单 line 325：真实性 → 实效性 → 放行，不允许中间插逻辑）
- **不改 transition 方向检测逻辑**（CONTEXT line 144：目标<当前放行 / 目标>当前前进）
- **不重构** `is_phase_write` / `is_write_command` 的**函数结构**（只改 regex 表达方式：内联 → 变量）
- **不碰** `29-independent-review.sh` / `fk_validate_done_marker` / `l3-review.sh`（同属 gate 核心链，本次范围外）
- **不处理** TD-011 以外的技术债（TD-004/005/012 等各自独立 change）
- **不改 gate 的 transition 拦截业务逻辑**（line 175 / 366 调用点不动）

## 验收线（粗粒度，不是 AC）

1. `make test` 全绿（407 → 407+N，**0 BW01**），新增 atomic-write 正负 case + 回归对比断言全 pass
2. `shellcheck independent-review-gate.sh` **0 warning**（SC1026/2203/SC2157 消失，line 68 disable 标注移除）
3. TD-011 从 CONTEXT.md 禁动清单 / TD 表标记为 **resolved ✅**（含修复证据链：实证脚本 + 回归断言）

## 风险与未知

- **禁动清单 gate 大改（19 处 regex）** → 6-review 必须验"行为等价"：用 sandbox 实证脚本 + 测试覆盖证明 18 处治理零功能变化。用户已知情并选择此挡位（6-review 风险升高）
- **line 69 修复会改变 gate 对 atomic-write 命令的实际判定**（从"恒真误报" → "正确匹配"）—— 需在 6-review 确认没有上游逻辑**依赖**这个误报行为（理论上是 bug 不应有依赖，但需查证 line 175/366 调用链下游）
- **全文件治理 diff 较大**，增加 6-review + 完整模式跨模型 spot-check 负担（已纳入预算）
- 未知：是否存在其他 hook 文件复用了同一 regex 模式（`is_write_command` 是否被 import）—— 4-dev 阶段查证

---

> 后续 AC 与设计细节进入 `REQUIREMENT.md` / `DESIGN.md`，本文件不再扩展。
