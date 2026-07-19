# T01-SUMMARY — D1·F PHASE_GATE_KEY_MAP pure fn 单一来源

- **Task**: T01 (D1·F) — PHASE_GATE_KEY_MAP 抽 pure fn `fk_phase_gate_key` + 删重复 declare
- **Change**: l2-l3-mock-fix
- **关联**: ADR-007 / REQUIREMENT AC-F / DESIGN D1·R1 / NFR-3 / NFR-4
- **状态**: ✅ verify 全绿（唯一 fail AC-3 已证为 pre-existing 基线，与 T01 物理隔离）

## 改动清单（4 文件 + 1 AC-7 同步）

| 文件 | 改动 |
|---|---|
| flow-kit-bundle/hooks/stop/lib/common.sh | 删 `declare -A PHASE_GATE_KEY_MAP` + 新增 `fk_phase_gate_key` pure fn（case 7 分支 + 默认空）+ 注释单一来源（+27/-27） |
| flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh | 删 declare -A + BUG-F 注释；**加 `source common.sh`（方案A）**；2 消费者(:390/:408) 改 `fk_phase_gate_key` |
| flow-kit-bundle/hooks/stop/29-independent-review.sh | 3 消费者（:77 `$pn` / :117 / :155 `$phase`）改 `fk_phase_gate_key`（变量名不一刀切） |
| test/test-phase-gate-key-pure-fn.bats | 新建：Part A pure fn 单测(4) + Part B NFR-3 三要素集成(1) |
| flow-kit-bundle/test/test-phase-gate-key-pure-fn.bats | AC-7 一致性同步（test/ 镜像，`diff` IDENTICAL） |

## 方案 A 决策记录（gate.sh 访问 fk_phase_gate_key）

**缺口**：ADR-007 D1 选 pure fn 定义在 common.sh，但 gate.sh **不 source common.sh**（D7 为隔离 source 副作用改局部 declare）。gate.sh 2 消费者改调 `fk_phase_gate_key` 会 command not found → `_gate_phase_transition` 异常 → **BUG-F 重现**（INT-7 forward transition 从 deny exit2 变放行 exit0）。ADR-007 Consequences 只写"5 消费者机械改调用 + 1 注释更新"，未写 gate.sh 如何获得该函数。

**用户拍板（AskUserQuestion）**：方案 A — gate.sh 加 `source common.sh`。
**依据**：common.sh 顶层 source-safe（已核实：仅 `set -euo` + 函数定义 + `: "${VAR:=}"` 默认值，**无执行态调用**）；L3 当初担心的"config_get 污染"是误判（函数定义 source 不执行）；29 已 source common.sh 且 work（实证）；D7 注释自承"L2 验证有效"。
**验证**：INT-7 forward transition deny 回归 PASS（exit2，BUG-F 不重现）+ 全套 bats 505/506。

## verify 结果

| 检查 | 结果 |
|---|---|
| pure-fn 单测（AC-F oracle：逐 key + 0/4 排除 + 容错 + 幂等） | ✅ 5/5 pass |
| INT-7 forward transition deny exit2 回归 | ✅ pass（BUG-F 不重现，方案A 验证） |
| NFR-3 deny stderr 三要素（git commit → `_gate_deny_reason`） | ✅ phase_name(`1-requirement`) + `.independent-review-1.done` 路径 + `独立 review` 阻断原因 |
| NFR-4 `grep declare -A PHASE_GATE_KEY_MAP` == 0 | ✅ 0 |
| 语法 `bash -n`（3 文件） | ✅ OK |
| 全套 bats（1.8 破坏性变更回归） | ✅ 505 ok / 1 not ok（AC-3 基线，见下） |

### AC-3 基线 fail（与 T01 物理隔离，非回归）
- AC-3 grep `$HOME/.claude/hooks/stop/29`（user-scope 已装副本，inode **1884898**）
- T01 改 `flow-kit-bundle/hooks/stop/29`（仓库文件，inode **2020737**）—— 不同 inode = 不同物理文件
- T01 未跑 install，不影响已装副本；已装副本 `ANTHROPIC_DEFAULT_HAIKU_MODEL:-` 计数=0（旧版）
- 结论：pre-existing 基线 fail，属 model env-var change 范围（test_independent_review_model.bats），非 T01

## 6 维 self-review（内置快查 · 基于已验证证据）

1. **正确性** ✅：fk_phase_gate_key 逐 key=附录 oracle（pure-fn 测试）+ INT-7 deny 回归 + 全套 bats 505/506
2. **复用（reuse）** ✅：1.4 grep `fk_phase_gate_key` NOT-EXIST（新建无重复）；沿用 case 范式 + INT-1~7 集成测试范式；COMMON_SH/GATE_SH 路径范式沿用 test_l2（TD-012 修复后正确，含 flow-kit-bundle/ 层）
3. **简单性** ✅：pure fn（case 7 分支 + 默认）单一来源，消除 v1 两处 declare -A 重复（DRY）
4. **效率** ✅：函数调用 vs 数组查找开销（NFR-1 由 T07 实测填阈值）；gate.sh source common.sh 一次性
5. **可读性** ✅：`fk_phase_gate_key` 命名（fk_ 前缀符合 CONTEXT 命名约定）；注释标单一来源 + D1 决策；deny stderr 三要素保留
6. **测试质量** ✅：pure-fn 5 测试（oracle 强引用附录 + 边界 + 容错 + 幂等）+ NFR-3 三要素集成（git commit final deny 路径，精准守护 phase_name）+ INT-7 回归

## 越界检查（R6.5 / R7.3）

- ✅ 所有改动在 T01 write_files 内（common.sh / gate.sh / 29 / test-bats）
- ✅ flow-kit-bundle/test/ 副本 = AC-7 一致性强制（test/ 镜像），非范围扩展（R7.1 不触发）
- ✅ 未改 REQUIREMENT.md / DESIGN.md（R3.2）
- ✅ 未改 7 Gate 控制流（AC-F 边界）：`_run_review_gates` / Gate transition / 触发顺序全保留
- ✅ 未越界改其他 task 文件（T02-T08 文件未碰）

## 沿用既有抽象 grep（1.4 · R6.4）

- `fk_phase_gate_key` 全仓库 grep → NOT-EXIST（safe to create，无重复实现）
- phase→gate_key 映射 → 重构 common.sh 既有 `declare -A` 为 pure fn（D1）
- 集成测试范式 → 沿用 test_l2 INT-1~7（payload 注入 `bash gate.sh`）

## 扫 LESSONS（1.5 · R1.8）

- **L-027**（bats 禁 `|tail` 管道吃 exit code → 假绿）：T01 verify 全程 `npx bats ...; echo "EXIT=$?"` 直接判 exit，无管道吞 exit。确认仍适用，不重试错误。
- **L-010**（破坏性变更后立即验证恢复）：T01 删 2 处 declare -A（16 行）+ 改公共接口 = 破坏性变更 → 触发 1.8 → 已跑全套 bats 恢复验证（505/506，AC-3 基线隔离）。

## 破坏性变更（1.8 · R4.6）

- 删 `declare -A PHASE_GATE_KEY_MAP` ×2（common.sh:255-262 + gate.sh:25-32，共 16 行）
- 改公共接口：5 执行消费者 `${PHASE_GATE_KEY_MAP[$x]:-}` → `$(fk_phase_gate_key "$x")`
- grep 引用图：全仓库已查（5 消费者 + 1 Usage 注释 + correction-types.sh:13 注释）
- 用户确认：方案 A（gate.sh source common.sh）经 AskUserQuestion 拍板
- 回归覆盖：pure-fn 单测 + INT-7 + 全套 bats

## 遗留（非 T01 范围，记录供后续）

1. **correction-types.sh:13 注释**仍提 "PHASE_GATE_KEY_MAP"（纯文档，非执行消费者；不在 T01 write_files，改它越界 R6.5）。轻微文档过时，建议后续 change 清理。
2. **AC-3 基线 fail**：`$HOME/.claude/hooks/stop/29` 已装副本不含 `ANTHROPIC_DEFAULT_HAIKU_MODEL:-` pattern。属 model env-var 范围，需重 install user-scope hook 或独立修复，非 T01。
3. **NFR-1 性能阈值**：T07 实测 gate hook wall time 填 DESIGN（重构前后 <30%）。T01 未填，T07 负责。
