# DESIGN · td072-lib-split-2026-08

> 目标：将 l3-api.sh（372 行）+ gate-helpers.sh（254 行）按职责拆分到既有/新增 lib 文件，所有调用方零变更。

---

## § 0 技术栈

- **语言**: Bash（`set -euo pipefail`，`readonly UPPER_SNAKE_CASE` 常量规范）
- **测试**: bats-core（npx）· 基线 662 tests / 0 fail
- **设计模式**: 聚合入口模式（CONTEXT.md 既有抽象 `aggregate entry pattern`）
- **依赖**: 无新增

## § 1 既有抽象 + 禁动对齐

### 既有抽象索引（CONTEXT.md）

| 抽象 | 当前位置 | 复用方式 |
|---|---|---|
| 聚合入口模式（aggregate entry pattern）| l3-review.sh / flow-kit-artifacts.sh | gate-helpers.sh 内部 source gate-helpers-types.sh + re-export |
| 禁动清单「hook 校验核心链」| CONTEXT.md 既有抽象索引段 | 新增 gate-helpers-types.sh 条目 |

### 禁动清单影响

本 change 触碰 2 个禁动清单上的文件：
- `hooks/stop/lib/l3-api.sh`（l3 split chain）— 内部重排，对外 API 不变
- `hooks/pre-tool-use/gate-helpers.sh`（gate 校验核心链）— 改为聚合入口

**禁动 exception 注册**（写入 CONTEXT.md 既有抽象索引段）：
```markdown
| gate-helpers-types.sh | gate 类型谓词（6 函数聚合入口） | td072-lib-split-2026-08 |
```

## § 2 实现方案

### 决策矩阵

| # | 决策 | 选项 | 选择 | 理由 |
|---|---|---|---|---|
| D1 | smart_truncate 去向 | (a) 新建 l3-callparse.sh  (b) 入 l3-truncate.sh | **(b)** | 既有 l3-truncate.sh 71 行容量充足；职责语义匹配（truncation 工具）；避免文件增殖 |
| D2 | gate-helpers.sh 拆分粒度 | (a) 全函数一拆 (b) 聚合入口模式 | **(b)** | CONTEXT.md 既有抽象；调用方零变更；子文件内部 source |
| D3 | 函数重命名 | (a) 加前缀  (b) 保留原名 | **(b)** | 聚合入口 re-export，无需重命名 |
| D4 | 新增单元测试 | (a) 为 6 谓词各加 (b) 仅 metrics + 全量回归 | **(b)** | 函数逻辑零变更；metrics 测试是结构性硬门槛；单元测试成本高于收益 |
| D5 | 测试位置 | (a) 新建 test_lib_split.bats  (b) 既有 test_common_metrics.bats | **(a)** | 单一职责文件，便于后续 v2 task 扩展 |

### 2.1 l3-api.sh 拆分

**当前**（372 行 / 3 函数）：
| 函数 | 行号 | 行数 | 处理 |
|---|---|---|---|
| `smart_truncate()` | L18-166 | 149 | **MOVE** → l3-truncate.sh |
| `_l3_call_api()` | L168-262 | 95 | STAY |
| `_l3_parse_result()` | L264-372 | 109 | STAY |

**目标**：
- `l3-api.sh`：218 行（仅 2 函数，API 调用 + 结果解析）
- `l3-truncate.sh`：203 行（54 + 149，source 由 slim orchestrator 维持）

**操作步骤**：
1. Read l3-truncate.sh 当前内容（保存）
2. Extract smart_truncate 完整定义（L18-166）到 l3-truncate.sh 末尾（在 `_l3_check_rerun()` 之后）
3. 删除 l3-api.sh L18-166
4. 修正 l3-api.sh 头部注释（移除 smart_truncate 引用）
5. bash -n 两文件
6. 全量回归（slim l3-review.sh 已 source l3-api.sh + l3-truncate.sh，smart_truncate 自动可见）

### 2.2 gate-helpers.sh 拆分（聚合入口模式）

**当前**（254 行 / 13 函数）：
| 函数 | 行号 | 行数 | 类型 | 处理 |
|---|---|---|---|---|
| `_is_dotdone_write()` | L18-36 | 19 | type | **MOVE** |
| `_gate_is_l2_only()` | L38-54 | 17 | type | **MOVE** |
| `fk_check_gate_config_tamper()` | L56-72 | 17 | active | STAY |
| `is_phase_write()` | L74-95 | 22 | type | **MOVE** |
| `_fk_phase_direction()` | L97-113 | 17 | type | **MOVE** |
| `_command_has_write_context()` | L115-122 | 8 | type | **MOVE** |
| `_command_first_tokens()` | L124-147 | 24 | util | STAY |
| `is_git_commit()` | L149-163 | 15 | type | **MOVE** |
| `_gate_path_guard()` | L165-203 | 39 | check | STAY |
| `_gate_phase_filter()` | L205-221 | 17 | check | STAY |
| `_gate_active_check()` | L223-234 | 12 | check | STAY |
| `_gate_done_validation()` | L236-240 | 5 | check | STAY |
| `_gate_tamper_detect()` | L242-254 | 13 | check | STAY |

**目标**：
- `gate-helpers-types.sh`（新）：6 函数 ~98 行 + 10 行 header = ~108 行
- `gate-helpers.sh`（聚合入口）：156 行（254 - 98 + source + re-export）

**gate-helpers.sh 聚合入口结构**：
```bash
#!/bin/bash
# gate-helpers.sh — aggregation entry for gate helpers
# Sources sub-libs and re-exports their functions.

set -euo pipefail

# Source type predicates
source "$(dirname "${BASH_SOURCE[0]}")/gate-helpers-types.sh"

# Re-export sourced functions (no-op: bash functions are global on source)
# Local functions follow below

# === Local helpers (active/util/check) ===

fk_check_gate_config_tamper() { ... }      # STAY
_command_first_tokens() { ... }             # STAY
_gate_path_guard() { ... }                  # STAY
_gate_phase_filter() { ... }                # STAY
_gate_active_check() { ... }                # STAY
_gate_done_validation() { ... }             # STAY
_gate_tamper_detect() { ... }               # STAY
```

**操作步骤**：
1. 创建 gate-helpers-types.sh，含 6 个 MOVE 函数 + 头部
2. 重写 gate-helpers.sh：保留 7 个 STAY 函数 + 顶部 source gate-helpers-types.sh
3. bash -n 两文件
4. 全量回归（slim independent-review-gate.sh source gate-helpers.sh 时自动级联 source gate-helpers-types.sh）

## § 3 风险

| # | 风险 | 缓解 |
|---|---|---|
| R1 | smart_truncate 依赖 l3-api.sh 内的常量/状态 | 检查函数体内引用的变量，若为文件级 readonly 常量则需在 l3-truncate.sh 重新声明（或保持 l3-api.sh source l3-truncate.sh） |
| R2 | gate-helpers-types.sh 中函数依赖 gate-helpers.sh 的辅助函数 | 6 函数均为自包含 type 谓词（不调用其他 helpers），无依赖 |
| R3 | bash function scope 在 source 时变为全局，可能引起命名冲突 | 函数名带前缀（`_is_dotdone_write` / `_gate_is_l2_only` 等）已隔离 |
| R4 | slim orchestrator 的 source 顺序敏感 | gate-helpers.sh 先 source types，再定义本地函数；与既有 source 顺序无冲突 |

## § 4 测试计划

### 4.1 既有测试不退化
- AC-A2: `npx bats test/ && npx bats flow-kit-bundle/test/` ≥ 662 tests / 0 fail

### 4.2 新增 metrics 测试（4 个）

**文件**: `test/test_lib_split_metrics.bats`（新建）+ `flow-kit-bundle/test/test_lib_split_metrics.bats`（sync）

| Test | 断言 | 对应 AC |
|---|---|---|
| AC-B1-metric | `wc -l l3-api.sh` ≤ 250 | AC-B1 |
| AC-B2-metric | `wc -l l3-truncate.sh` ≤ 250 | AC-B2 |
| AC-B3-metric | 4 文件循环 wc -l，每个 ≤ 250 | AC-B3 |
| AC-C2-metric | `grep -c '^smart_truncate()' l3-api.sh` = 0; `grep -c '^smart_truncate()' l3-truncate.sh` ≥ 1 | AC-C2 |

### 4.3 bash 语法检查（既有 AC-A1）
- `test_smoke_syntax.bats::AC-4` 覆盖全仓 .sh（自动发现新文件）

## § 5 ADR

本 change 无新 ADR（纯机械重构 + 既有抽象复用）。

## § 6 实现顺序（Phase 4 任务波次）

| Wave | Task | 文件 | 依赖 |
|---|---|---|---|
| W1 | T01 l3-api.sh 拆分 | l3-api.sh / l3-truncate.sh | 无 |
| W1 | T02 gate-helpers.sh 拆分 | gate-helpers.sh / gate-helpers-types.sh | 无 |
| W2 | T03 metrics 测试 | test_lib_split_metrics.bats | T01 + T02 |
| W3 | T04 CONTEXT.md 禁动 + CHANGELOG + commit | .specs/CONTEXT.md / CHANGELOG.md | T01-T03 |

## § 7 范围外

- l3-review.sh 305 行（slim orchestrator）— TD-008 已评估为可接受
- gate-checks-basic.sh 144 行 / gate-checks-review.sh 161 行 — 当前合理
- 其他既有超限文件（flow-kit-artifacts.sh / weak-model-compliance.sh / common.sh / l2-detect.sh / fix-compliance.sh）— v2 task
