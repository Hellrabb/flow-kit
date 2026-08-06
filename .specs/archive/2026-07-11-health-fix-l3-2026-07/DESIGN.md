# DESIGN — L3 审计子系统健康修复

- **Change ID**: `health-fix-l3-2026-07`
- **关联**: `REQUIREMENT.md`、`CHANGE.md`、`CONTEXT.md`、`ARCHITECTURE.md`
- **作者**: AI（Architect 角色）+ 人工 review

---

## 0. 技术栈选定

> 已在 CONTEXT.md 锁定，本 change 不引入新技术栈。

- **语言/运行时**: Bash 4.2+（`set -euo pipefail`）
- **测试**: bats-core 1.13.0（`npx bats`）
- **静态分析**: `bash -n` + shellcheck（error 级别，`-e SC1091`）
- **关键依赖**: jq ≥ 1.6、curl、GNU grep 3.x
- **理由**: 纯 Bash 重构项目，不引入新语言/框架/DB；CONTEXT.md `技术栈` 段已锁定
- **明确排除**: 不引入 Python/Node.js 辅助脚本（保持零外部运行时依赖）

---

## 0.5 既有架构对齐（brownfield · 证据驱动）

### 0.5.1 本次 change 触碰的既有模块

> 所有文件路径经 `test -f` 验证存在（2026-07-11）。

```
触碰模块（grep/验证出来的实际清单）：
- flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh（既有 · 主 gate 逻辑）
- flow-kit-bundle/hooks/stop/29-independent-review.sh（既有 · Stop hook L3 派发）
- flow-kit-bundle/hooks/stop/lib/l3-review.sh（既有 · L3 API 封装 + 超长函数目标）
- flow-kit-bundle/hooks/stop/lib/fix-compliance.sh（既有 · 实效性校验 + 超长函数目标）
- flow-kit-bundle/hooks/stop/lib/done-validation.sh（既有 · 被动变更：source 路径调整）
- flow-kit-bundle/hooks/stop/lib/common.sh（既有 · 新增 PHASE_GATE_KEY_MAP + run_check）
- flow-kit-bundle/hooks/stop/lib/correction-file.sh（既有 · 解环对象）
- flow-kit-bundle/hooks/stop/lib/interactive-ui-check.sh（既有 · 解环对象）
- flow-kit-bundle/hooks/stop/lib/weak-model-compliance.sh（既有 · 解环对象）
- flow-kit-bundle/hooks/stop/lib/transcript-parser.sh（既有 · 死代码清理）
- flow-kit-bundle/flow-kit/prompts/6-review.md（既有 · DRY jq 解析目标）
- flow-kit-bundle/flow-kit/prompts/7-integration.md（既有 · DRY jq 解析目标）

新增模块：
- flow-kit-bundle/hooks/stop/lib/correction-types.sh（新 · 解环共享接口）
- flow-kit-bundle/flow-kit/reference/goal-parsing.md（新 · DRY 共享片段）
- test/test_l3_timeout.bats（新 · timeout 测试覆盖）

禁动清单（与本次无关，AI 不许"顺手"碰）：
- package-flow-kit.sh（打包脚本 · CONTEXT 禁动清单）
- install.sh / install_hooks.sh（安装脚本 · CHANGE 范围排除）
- .flow-active schema（状态文件结构 · CHANGE 范围排除）
- flow-kit-bundle/hooks/stop/lib/checkpoint-lib.sh（CONTEXT 禁动清单 · 必须通过 checkpoint_write）
- 00-gate.sh / 01-transcript-parse.sh / 22-git.sh 等 Stop hook 协调层模块（与本次无关）
```

### 0.5.2 既有抽象沿用对照表

| 本次需要 | 既有有没有？路径 | 决定 |
|---|---|---|
| phase→gate_key 映射 | 无集中映射 · `independent-review-gate.sh:205-206/311-312` 硬编码 | **新建** `PHASE_GATE_KEY_MAP`（`declare -A` in common.sh） |
| jq goal 解析 | 有 · 但 6-review 和 7-integration 逐字重复 ~30 行 | **抽取** 为 `reference/goal-parsing.md` 共享片段 |
| correction 文件读写 | `correction-file.sh` 提供 4 函数（write/read/clear/exists） | **沿用**（不改变 API 签名） |
| 死代码清理 | `transcript-parser.sh:130 estimate_tokens()` | **移除**（全仓零引用已确认） |
| L3 API 调用 | `l3-review.sh::l3_review_run()` | **沿用**（v1 不拆主函数，仅拆子函数） |
| 函数行数验证 | 无 | **新建** grep-n 差值计数法（AC-1） |

### 0.5.3 沿用模式 vs 引入新模式

```
- Hook lib 架构：**沿用** hooks/stop/lib/ 扁平目录 + source 引用模式（符合 ARCHITECTURE §2.2 允许依赖方向）
- 函数命名：**沿用** 现有前缀约定（fk_/l3_/_gate_/_check_——CONTEXT § 命名约定）
- 拆分模式：**沿用** sweep-fix-2026-07-10 的"提取子函数 + 编排器"模式（已验证有效）
- 解环模式：**沿用** health-fix-2026-07 的"提取共享接口到独立文件"模式（correction-types.sh 对应当时的 correction-file.sh 提取）
- DRY 消除：**沿用** 现有 reference/ 共享片段 @see 引用模式（如 pipeline-gates.md 先例）
- 错误处理：**沿用** fail-open 兜底（checkpoint-lib 先例 · hook 脚本不可因自身错误阻断主流程）
```

---

## 1. 决策清单

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D1 | `_gate_phase_transition()` 拆为 `_gate_check_l2()` + `_gate_check_l3()` + `_gate_do_transition()` 编排器 | 拆更细（5+ 子函数）或保持现状 | 3 子函数 + 编排器 ≈ 每函数 35-55 行；与现有 gate 结构对应（L2 check → L3 check → transition）；编排器 ≤ 50 行满足 AC-1 | 编排器引入一层间接调用；但 gate 逻辑本就有 3 阶段，拆分是显式化而非增加复杂度 |
| D2 | `fk_fix_compliance_check()` 降级为编排层，复用现有子阶段函数 | 全量重写 / 保持现状 | 子阶段函数已存在（`fk_classify_findings` / `fk_check_diff_only` / `fk_verify_finding_fix`），主函数 126 行主要是编排 + 胶水代码；提取编排层 ≈ 40 行 | 编排层需要理解子函数的契约；但子函数接口已稳定（来自 independent-review-gap change） |
| D3 | `l3_review_run()` 主函数 v1 不拆 | v1 也拆（TD-008） | 主函数 307 行承担 L3 审查全流程编排，拆它需要改动 API 调用链 + mock 注入点；它的子函数（`_l3_build_prompt` / `_l3_parse_result` / `smart_truncate`）v1 先拆，主函数留 v2 与 TD-008 一起处理 | v1 后 l3-review.sh 仍有 ~200 行 main 函数（拆分后子函数减少）；但风险可控——main 不拆意味着 L3 API 调用路径不变 |
| D4 | 解环提取 `correction-types.sh`（仅常量 + 类型定义） | 合并到 common.sh / 保持现状 | 独立文件遵循 ADP（Acyclic Dependencies Principle）——三方依赖接口而非彼此；correction-types.sh 仅含 `declare -r` 常量 + 类型注释，零函数定义，零外部 source | 多一个文件（correction-types.sh ~20 行）；但解环收益远超文件数成本——消除三向循环使三模块可独立测试 |
| D5 | `PHASE_GATE_KEY_MAP` 放 `common.sh` 而非独立文件 | 放独立 reference / 放各调用方 | common.sh 已被所有 hook 模块 source（18 处），放这里零额外 source 改动；`declare -A` 关联数组符合 common.sh 现有风格（`HOOK_MODULE_NAMES` 先例） | common.sh 增加 ~10 行；但集中维护的收益（2 处硬编码 case-esac 替换为查表）大于代价 |
| D6 | `smart_truncate()` 按 header/artifact/CHANGELOG/优先级 拆 4 子函数 | 拆成通用 truncate 引擎 + 策略函数 | 4 段截断逻辑相互独立（header 截断、artifact 截断、CHANGELOG 截断、优先级回退），拆 4 函数每函数 ≤ 30 行；通用引擎方案过度设计——截断策略各异，统一抽象反而增加复杂度 | 4 函数增加 source 文件行数 ~20 行（函数签名 + 注释）；但每函数的独立可测试性提升显著 |
| D7 | 死代码清理策略：`estimate_tokens()` 删定义+注释块 | 标记 deprecated 保留一版 | 全仓零引用（grep 已确认），CONTEXT 清理窗口已标记≥30 天；直接删而非 deprecated——Bash 无编译期警告，deprecated 注释无人会看 | 删后无法回退（但 git history 保留） |
| D8 | `29-independent-review.sh` 主逻辑拆为 3 子函数 + 编排层 | 保持现状（线性脚本）/ 拆更多函数 | 3 子函数对应 3 职责（L2 检测 / gate 值解析 / L3 派发）；编排层 ≤30 行满足 AC-9；与 D1 拆分模式一致（编排器 + 职责子函数） | 编排层引入一层间接调用；但 29 号 hook 逻辑本身线性，拆分是显式化而非增加复杂度 |

---

## 2. 架构图

### 2.1 解环前后对比

```
BEFORE (三向依赖环):                    AFTER (单向依赖):
                                        
  correction-file.sh                     correction-types.sh (NEW)
       ↑       ↗                             ↑        ↑        ↑
       |     /                              /          \        \
       |   /                              /            \        \
  interactive-ui-check.sh         correction-file.sh  i-u-c.sh  w-m-c.sh
       ↑                                                
       |                                                
  weak-model-compliance.sh                          

修复: 三方均 source correction-types.sh（仅常量），互不 source
```

### 2.2 函数拆分模式（以 `_gate_phase_transition` 为例）

```
BEFORE:                                   AFTER:
                                          
_gate_phase_transition() 122L             _gate_phase_transition()  ~45L (编排器)
  ├── L2 check 段 (~55L)                   ├── _gate_check_l2()     ~50L
  ├── L3 check 段 (~60L)        ──→        ├── _gate_check_l3()     ~55L
  └── transition dispatch (~45L)           └── _gate_do_transition() ~40L
                                          
拆分原则: 每个子函数一个 gate 职责，编排器仅含调度逻辑 (if/else + 函数调用)
```

### 2.3 `fk_fix_compliance_check` 降级

```
BEFORE:                                   AFTER:
                                          
fk_fix_compliance_check() 126L            fk_fix_compliance_check() ~40L (编排层)
  ├── 分类 findings (~30L)                 ├── fk_classify_findings()    (既有)
  ├── diff-only 检测 (~35L)     ──→        ├── fk_check_diff_only()      (既有)
  ├── 逐 finding 验证 (~40L)               ├── fk_verify_finding_fix()   (既有)
  └── 结果汇总 (~20L)                      └── 编排: 循环调用 + 汇总结果
                                          
子函数已存在于 fix-compliance.sh，主函数降级为编排层（调度既有子函数）
```

### 2.4 `smart_truncate` 拆分

```
BEFORE:                                   AFTER:
                                          
smart_truncate() 112L                     smart_truncate() ~30L (编排器)
  ├── header 截断 (~30L)                   ├── _truncate_headers()      ~25L
  ├── artifact 截断 (~35L)      ──→        ├── _truncate_artifacts()    ~30L
  ├── CHANGELOG 截断 (~25L)                ├── _truncate_changelog()    ~20L
  └── 优先级回退 (~20L)                    └── _truncate_priority_fallback() ~20L
```

### 2.5 `_l3_parse_result` 拆分

```
BEFORE:                                   AFTER:
                                          
_l3_parse_result() 82L                    _l3_parse_result() ~15L (编排器)
  ├── verdict 解析 (~30L)                  ├── _l3_parse_verdict()      ~25L
  ├── KVP 格式校验 (~25L)      ──→         ├── _l3_validate_result()    ~25L
  └── 归档写入 (~25L)                      └── _l3_archive_result()     ~20L

拆分原则: 解析/校验/归档三阶段独立——解析 verdict+summary，校验 6 键 KVP，归档写入 .done + report
```

### 2.6 `_l3_build_prompt` 拆分

```
BEFORE:                                   AFTER:
                                          
_l3_build_prompt() 85L                    _l3_build_prompt() ~20L (编排器)
  ├── system prompt (~30L)                 ├── _l3_build_system_prompt()    ~25L
  ├── user prompt (~30L)       ──→         ├── _l3_build_user_prompt()      ~20L
  └── artifact context (~25L)              └── _l3_build_artifact_context()  ~20L

拆分原则: system/user/artifact 三段独立构造，编排器仅拼接三段为最终 prompt 字符串
```

### 2.7 `29-independent-review.sh` 函数化（AC-9）

```
BEFORE:                                   AFTER:
                                          
29-independent-review.sh (~80L 线性脚本)   main() ~30L (编排层)
  ├── L2 完成检测 (~25L)                   ├── _check_l2_complete()      ~25L
  ├── gate 值解析 (~25L)       ──→         ├── _resolve_gate_value()     ~25L
  └── L3 派发 (~30L)                       └── _dispatch_l3_review()    ~25L

拆分原则: 与 D1 拆分模式一致（编排器 + 职责子函数），编排层 ≤30 行满足 AC-9
```

---

## 3. 关键接口契约

### 3.1 `correction-types.sh`（新增 · 共享常量）

```bash
# correction-types.sh — 共享常量/类型定义
# 被 correction-file.sh / interactive-ui-check.sh / weak-model-compliance.sh 三方 source
# 本文件不 source 任何其他 lib（零外部依赖，保证无环）

# Correction file type enum
readonly CORRECTION_TYPE_COMPLIANCE="compliance"
readonly CORRECTION_TYPE_INTERACTIVE_UI="interactive-ui"

# Correction retry threshold
readonly CORRECTION_MAX_RETRY=2
```

### 3.2 `PHASE_GATE_KEY_MAP`（新增 · common.sh）

```bash
# PHASE_GATE_KEY_MAP — phase number → gate_config key
# Phase 0（change）和 Phase 4（dev）当前无独立审查 gate，有意不在此 MAP 中。
# 若未来新增，需同步更新四层架构：PRESET_MAP + Prompt 模板 + L2-blind-review.md checklist + 本 MAP。
# 用法: local gate_key="${PHASE_GATE_KEY_MAP[$phase]:-}"
declare -A PHASE_GATE_KEY_MAP=(
  [1]="1-requirement"
  [2]="2-design"
  [3]="3-task"
  [5]="5-test"
  [6]="6-review"
  [7]="7-integration"
)
```

### 3.3 `goal-parsing.md`（新增 · reference 共享片段）

```markdown
<!-- @see flow-kit/reference/goal-parsing.md -->
<!-- 提供 goal.scope / start_phase / current_phase / phases_done / gates 的 jq 解析片段 -->
<!-- 6-review.md 和 7-integration.md 通过 @see 引用，替代原有 ~30 行重复 jq 代码 -->
```

---

## 4. ADR 索引

本 change 不涉及不可逆决策。D1-D3、D5-D8 为内部重构；D4（解环引入 `correction-types.sh`）涉及三模块依赖拓扑变更——依赖方向从双向改为单向（共同依赖 correction-types.sh），外部 API 行为不变。属架构层面微调，符合 ARCHITECTURE §2.2 的依赖规则（消除双向引用）。

- ADR-003（Hook 系统架构）— **延续**：不新增 hook 模块编号；D4 解环消除 lib 间双向引用，强化 ADR-003 的依赖规则
- ADR-005（独立审查体系）— **延续**：gate 校验逻辑行为不变

---

## 5. 风险

| # | 类型 | 风险 | 影响 | 概率 | 缓解 |
|---|---|---|---|---|---|
| R1 | 实现 | 函数拆分引入 bash 作用域 bug（子函数中 `local` 变量遮蔽/未初始化） | 拆分后函数行为与拆分前不一致，gate 误判通过/拒绝 | 中 | AC-3 全量 bats 回归（407 tests）；每拆分完一个函数立即跑对应 test 文件；bash -n 兜底语法错误 |
| R2 | 实现 | 解环时 `correction-types.sh` 引入 source 路径错误（`$HOOK_BASE_DIR` 未定义或路径不对） | correction 功能完全失效，Stop hook 27/28 号模块静默失败 | 低 | correction-types.sh 不含外部 source，不需要 `$HOOK_BASE_DIR`；使用与现有 lib 一致的 source 模式（`source "${HOOK_BASE_DIR}/lib/correction-types.sh" 2>/dev/null \|\| true`） |
| R3 | 上线 | 拆分后 Stop hook 链执行时间增加（多 10+ 次 bash 函数调用） | PreToolUse hook 延迟增加，用户感知到卡顿 | 低 | AC-3 附带 time 对比（≤ 200ms）；bash 函数调用开销 ~1-5ms/次，10 次调用在非热路径上 < 50ms；PreToolUse gate 仅 transition 时触发，非每轮都执行 |
| R4 | 长期 | v1 不拆 `l3_review_run()` 主函数 → 技术债 TD-008 持续存在 | 下次改 L3 审查逻辑仍需理解 200+ 行 main 函数 | 高 | TD-008 已在 CONTEXT 登记且标为 v2 延后项；本次拆其子函数已将 main 从 307→~200 行（减 ~35%） |
| R5 | 长期 | jq goal 解析共享片段 `goal-parsing.md` 被修改后未同步更新两处 @see 引用 | 6-review 和 7-integration 行为不一致 | 低 | 当前无自动化漂移检测；`@see` 单源引用比两处独立维护更不易漂移，但非零风险；依赖 code review 和 `make check` 的提示性输出 |
| R6 | 实现 | 聚合变更面大（5 函数拆分 + 3 新文件 + 解环 + 死代码清理 + self-sourcing 修复），变更交互难预测 | 回归定位困难，bash source 链意外交互 | 中 | 分两批提交：第一批（解环 + 死代码 + self-sourcing，低风险基础设施）+ 第二批（函数拆分，高风险逻辑变更）；AC-3 全量 bats 回归（407 tests）作为集成兜底 |
| R7 | 实现 | `done-validation.sh` source 路径被动调整（`correction-file.sh` → `correction-types.sh`）遗漏 | done 校验的 correction 依赖静默失效（`2>/dev/null` 吞错） | 低 | AC-2 的 grep 交叉检测验证所有 source 引用正确；bats 测试覆盖 done-validation 路径 |

---

## 6. 不在范围

- `l3_review_run()` 主函数拆分（TD-008 · v2）
- `is_gh_pr_create()` 调用方主逻辑体独立拆分（TD-018 延后）
- 引入 mock/fake 框架用于 bats 测试（测试用 curl stub 函数即可，不过度工程化）
- 修改 gate 校验逻辑本身（如调整 L2 派发策略、修改 .done 格式）
- 新增 hook 模块编号（不改变 Stop hook 01-33 编号）
- CONTEXT.md 清理窗口专列的 3 条目（`estimate_tokens`/`read_correction_file`/`file_not_empty`）— 本次移除

---

## 9. 架构沉淀建议

### 9.1 新增的可复用抽象

| 路径 | 能力 | 触发场景 | 复用建议 |
|---|---|---|---|
| `hooks/stop/lib/correction-types.sh` | 三模块共享常量定义（correction type enum + retry threshold） | 任何需要引用 correction type 的模块 | 新增 correction 相关模块时 source 此文件而非直接 source correction-file.sh |
| `common.sh::PHASE_GATE_KEY_MAP` | phase number → gate_config key 集中映射 | 任何需要解析 phase→gate_key 的 hook/prompt | 替代所有 `case "$phase" in 1) "1-requirement" ;;` 硬编码 |
| `flow-kit/reference/goal-parsing.md` | pipeline goal jq 解析共享片段 | 任何需要读取 goal.scope/start_phase/current_phase 的 prompt | 通过 @see 引用，新增 prompt 需要 goal 解析时复用 |

### 9.2 新增/改变的项目级技术决策

| 决策 | 取值 | 影响范围 | 推翻代价 |
|---|---|---|---|
| 函数拆分最小单元 | 每子函数 ≤ 60 行，编排器 ≤ 50 行 | 本次及后续所有 hook lib 拆分 | 低（可调整为 80/60，不涉及架构） |
| 解环方法 | 提取共享类型/常量到独立零依赖文件 | 所有 lib 间循环依赖修复 | 低（成熟模式：ADP + 依赖倒置） |

### 9.3 跨模块契约变化

- `correction-file.sh` / `interactive-ui-check.sh` / `weak-model-compliance.sh` 的 source 依赖从"相互引用"改为"共同依赖 correction-types.sh"——所有调用方需调整 source 路径
- `done-validation.sh` 被动调整 source 路径（从 source correction-file.sh → source correction-types.sh）——外部调用方不受影响

### 9.4 依赖变动

无。不引入新外部依赖。

### 9.5 禁动清单变化

```
新增禁动：
- correction-types.sh 禁止添加函数定义（仅允许常量 + 类型注释）——保持零逻辑、零外部依赖
- common.sh PHASE_GATE_KEY_MAP 的 key 名必须与 gate_config key 一致——禁止单方面修改映射

解禁：
- CONTEXT.md 清理窗口专列（estimate_tokens/read_correction_file/file_not_empty 3 条目）— 本次清理后移除
```

---

> 本文件不包含完整代码实现。函数签名、伪代码、接口定义可以；函数体不行。
