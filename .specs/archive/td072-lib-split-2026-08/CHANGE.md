# CHANGE · td072-lib-split-2026-08

> 收尾 final-debt-cleanup-2026-08 遗留的 TD-072 🟡 技术债：两个 lib 文件行数超标，按设计进一步拆分。

## 背景

`final-debt-cleanup-2026-08` 把 `l3-review.sh` 875 行拆为 5 文件、`independent-review-gate.sh` 597 行拆为 4 文件，但两个产物仍超目标行数：

| 文件 | 当前行数 | 目标 | 差距 |
|---|---|---|---|
| `flow-kit-bundle/hooks/stop/lib/l3-api.sh` | 372 | ≤250 | -122 |
| `flow-kit-bundle/hooks/pre-tool-use/gate-helpers.sh` | 254 | ≤150 | -104 |

列为 TD-072 🟡（file-level 行数超标，非功能缺陷）。

## 变更

### 1. `l3-api.sh` 372 → ~218 行（移 smart_truncate 到既有 l3-truncate.sh）

按 final-debt-cleanup-2026-08 TEST.md §1.9(b) 设计意图（truncation 类工具归 l3-truncate.sh）：
- 提取 `smart_truncate()` (149 行) 从 l3-api.sh 到既有 `l3-truncate.sh`（71 → ~230 行）
- `l3-api.sh` 保留 `_l3_call_api()` + `_l3_parse_result()`（API 编排入口）
- 不新建 l3-callparse.sh（既有 l3-truncate.sh 容量充足，避免文件增殖）

### 2. `gate-helpers.sh` 254 → ~144 行（拆出 1 个新文件）

按 final-debt-cleanup-2026-08 TEST.md §1.9(c) 设计：
- 拆出 6 个类型谓词函数（_is_dotdone_write / _gate_is_l2_only / is_phase_write / _fk_phase_direction / _command_has_write_context / is_git_commit）到新文件 `gate-helpers-types.sh`
- `gate-helpers.sh` 改为聚合入口（内部 source + re-export `gate-helpers-types.sh`），调用方零变更
- 聚合入口模式遵循 CONTEXT.md 既有抽象（user-scope-install 等）

### 3. 禁动清单例外注册

新增 lib 文件加入 CONTEXT.md 禁动清单「hook 校验核心链」段，与既有 5 个 lib 文件同等保护。

## 范围决策

| 决策 | 选项 | 选择 | 理由 |
|---|---|---|---|
| 拆分粒度 | (a) 单纯按行数机械切 (b) 按职责语义切 | (b) | 职责单一便于后续维护，避免把单个函数拦腰切 |
| 重命名 | (a) 保留原函数名 (b) 加前缀重命名 | (a) | slim orchestrator 已 source 子 lib + re-export，保留函数名减少调用方变更 |
| 测试覆盖 | (a) 仅 bash -n + 全量回归 (b) 新增单元测试 | (a) | 函数逻辑零变更，回归 662/0 即可；新增单元测试成本高于收益（v2 task） |
| gate_config | (a) all=both (b) all=L2 预降级 | (b) | OpenOffice 无 ANTHROPIC API，both 必触发 l3-model-missing correction；预降级避免噪声 |

## 验收线

- ✅ l3-api.sh ≤ 250 行
- ✅ gate-helpers.sh ≤ 150 行
- ✅ 每个新 lib 文件 ≤ 250 行
- ✅ 662 tests / 0 fail（不退化）
- ✅ `bash -n` 通过所有新文件
- ✅ `make lint` 通过（含 shellcheck）
- ✅ CONTEXT.md 禁动清单 + 命名约定段更新
- ✅ LESSONS.md TD-072 标 ✅ Resolved
- ✅ CHANGELOG.md + STATE.md 同步
