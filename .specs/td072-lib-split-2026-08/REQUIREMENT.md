# REQUIREMENT · td072-lib-split-2026-08

> 收尾 TD-072 🟡：l3-api.sh 371 行 + gate-helpers.sh 253 行两个超目标 lib 文件按职责语义切分。

## 用户故事

### US-1 · 行为零退化（功能正确性）
作为维护者，我希望 lib 拆分后所有既有调用方零感知，这样 662 测试基线保持 0 fail。

### US-2 · 文件大小达标（可维护性）
作为维护者，我希望每个 lib 文件 ≤250 行、关键 lib（gate-helpers.sh / l3-api.sh）≤150 / ≤250 行，这样单文件可一次读完。

### US-3 · API 完整保留（兼容性）
作为下游调用者（l3-review.sh / independent-review-gate.sh slim orchestrators），我希望所有既有函数名和签名零变更，这样 source + 调用语句不需修改。

### US-4 · 文档与状态同步（可追溯性）
作为项目维护者，我希望 CONTEXT.md 禁动清单 + LESSONS.md + CHANGELOG.md / STATE.md 同步更新，这样下次 health 扫描不会复发 TD-072。

---

## 验收准则（AC）

### 类别 A · 功能正确性（硬门槛）

#### AC-A1 · bash 语法检查通过所有变更文件
`Given` lib 文件 l3-api.sh / l3-truncate.sh / gate-helpers.sh / gate-helpers-types.sh（新增）已写入磁盘
`When` 执行 `for f in <4 files>; do bash -n "$f"; done`
`Then` exit code = 0
`验证方式`: bats 测试 `test/test_smoke_syntax.bats::"AC-4: 所有生产 .sh 脚本通过 bash -n 语法检查"`（已存在，自动发现目录下全部 .sh）

#### AC-A2 · 测试基线不退化（≥662 通过 / 0 fail）
`Given` 完整测试套件 `test/` 实施前 662 ok / 0 fail 基线，本 change 新增 4 个 metrics 测试后变 666 ok / 0 fail
`When` 执行 `npx bats test/ 2>&1 | tail -3`
`Then` 输出含 `0 failures` 且 `tests` 数 ≥ 662（精确数由 DESIGN § 实施后快照确认，预期 666）
`验证方式`: bats 测试

#### AC-A3 · make lint 通过
`Given` 所有变更已应用
`When` 执行 `make lint 2>&1 | tail -5`
`Then` exit code = 0
`验证方式`: make lint

### 类别 B · 文件大小达标（结构性硬门槛）

#### AC-B1 · l3-api.sh ≤ 250 行
`Given` smart_truncate() 已移出 l3-api.sh 到 l3-truncate.sh
`When` 执行 `wc -l flow-kit-bundle/hooks/stop/lib/l3-api.sh`
`Then` 第一列数值 ≤ 250
`验证方式`: bats 测试 `test_health_metrics.bats::"l3-api.sh under 250 lines"`

#### AC-B2 · gate-helpers.sh ≤ 150 行
`Given` 6 个类型谓词函数（_is_dotdone_write / _gate_is_l2_only / is_phase_write / _fk_phase_direction / _command_has_write_context / is_git_commit）已移出 gate-helpers.sh 到 gate-helpers-types.sh
`When` 执行 `wc -l flow-kit-bundle/hooks/pre-tool-use/gate-helpers.sh`
`Then` 第一列数值 ≤ 150
`验证方式`: bats 测试 `test_health_metrics.bats::"gate-helpers.sh under 150 lines"`

#### AC-B3 · 本 change 触碰的 4 个 lib 文件 ≤ 250 行
`Given` lib 拆分完成
`When` 执行 `for f in flow-kit-bundle/hooks/stop/lib/l3-api.sh flow-kit-bundle/hooks/stop/lib/l3-truncate.sh flow-kit-bundle/hooks/pre-tool-use/gate-helpers.sh flow-kit-bundle/hooks/pre-tool-use/gate-helpers-types.sh; do wc -l "$f"; done`
`Then` 4 行输出第一列数值均 ≤ 250
`验证方式`: bats 测试 `test_health_metrics.bats::"td072 changed files under 250 lines"`
`范围说明`: 仅约束本 change 直接变更的 4 个文件；其他既有超限文件（flow-kit-artifacts.sh / weak-model-compliance.sh / common.sh / l2-detect.sh / fix-compliance.sh）按 v2 范围处理，本 change 不触碰

### 类别 C · API 兼容性（防回归）

#### AC-C1 · smart_truncate 函数名保留且调用方不变
`Given` smart_truncate() 从 l3-api.sh 移至 l3-truncate.sh
`When` 执行 `grep -rn 'smart_truncate' flow-kit-bundle/hooks/`
`Then` 函数定义在新位置 l3-truncate.sh 出现一次；调用方（如 l3-review.sh、test_l3_*.bats）不变更
`验证方式`: bats 测试 grep

#### AC-C2 · 6 个谓词函数名保留且定义在新位置
`Given` _is_dotdone_write / _gate_is_l2_only / is_phase_write / _fk_phase_direction / _command_has_write_context / is_git_commit 从 gate-helpers.sh 移至 gate-helpers-types.sh
`When` 执行 `for fn in _is_dotdone_write _gate_is_l2_only is_phase_write _fk_phase_direction _command_has_write_context is_git_commit; do grep -c "^${fn}()" flow-kit-bundle/hooks/pre-tool-use/gate-helpers-types.sh; done`
`Then` 6 行输出均为 1（每个函数定义恰好出现一次在新位置）
`验证方式`: bats 测试 grep

#### AC-C3 · gate-helpers.sh 作为聚合入口 source 子库（调用方零变更）
`Given` 采用聚合入口模式（CONTEXT.md 既有抽象）
`When` 执行 `grep -E '^(source|\.) ' flow-kit-bundle/hooks/pre-tool-use/gate-helpers.sh`
`Then` 输出含 `gate-helpers-types.sh`（slim 入口 source 子库）
`When` 执行 `grep -c 'gate-helpers-types' flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh flow-kit-bundle/hooks/pre-tool-use/gate-checks-basic.sh flow-kit-bundle/hooks/pre-tool-use/gate-checks-review.sh`
`Then` 3 行输出均为 0（外部调用方不直接 source 子库，由聚合入口 re-export）
`验证方式`: bats 测试 grep（聚合入口模式遵循 user-scope-install 既有先例）

### 类别 D · 文档与状态同步

#### AC-D1 · CONTEXT.md 禁动清单段更新（段内 grep 锚定）
`Given` 新增 gate-helpers-types.sh
`When` 执行 `sed -n '/## 既有抽象索引/,/## 项目结构/p' .specs/CONTEXT.md | grep -E 'gate-helpers-types|gate-checks-basic|gate-checks-review'`
`Then` 输出至少含 gate-helpers-types.sh 一次（锚定禁动清单/既有抽象索引段，避免技术债表/术语表的假绿命中）
`验证方式`: bats 测试 sed + grep 段内锚定

#### AC-D2 · LESSONS.md TD-072 标记 Resolved
`Given` 实施完成
`When` 执行 `grep 'TD-072' .specs/LESSONS.md`
`Then` 该行含 `✅` 标记
`验证方式`: bats 测试 grep

#### AC-D3 · CHANGELOG.md + STATE.md 同步
`Given` 归档前
`When` 执行 `grep -c 'td072-lib-split-2026-08' .specs/CHANGELOG.md` + `grep -c 'TD-072' .specs/STATE.md`
`Then` CHANGELOG 至少 1 处；STATE.md 至少 1 处
`验证方式`: bats 测试 grep

---

## 范围决策

| 主题 | 决策 | 理由 |
|---|---|---|
| 拆分粒度 | 按职责语义切（smart_truncate 是 truncation 工具归 l3-truncate.sh；6 谓词是 type 判定归 gate-helpers-types.sh） | 职责单一便于后续维护，符合 l3-truncate.sh 既有职责（_l3_check_rerun） |
| 聚合入口 | gate-helpers.sh 内部 source gate-helpers-types.sh + re-export，调用方零变更 | 遵循 CONTEXT.md 既有「聚合入口模式」抽象（user-scope-install / l3-review.sh 等） |
| 函数重命名 | 不重命名（保留原名） | slim orchestrator source + re-export，调用方零变更 |
| 测试策略 | bash -n（既有自动发现）+ 全量回归 ≥662 + 新增 4 个 metrics 测试 | 函数逻辑零变更，回归基线即足够；metrics 测试是结构性硬门槛 |
| 拆分文件位置 | 与源文件同目录（hooks/stop/lib/ 或 hooks/pre-tool-use/） | 保持 source 路径短，禁动清单同段管理 |
| gate_config | all=L2 预降级（不 both） | OpenOffice 无 ANTHROPIC API；预降级避免 l3-model-missing correction |
| 新增单元测试 | 不新增（仅 metrics 测试） | 函数逻辑零变更；新增单元测试成本高于收益；v2 task |
| AC-A2 数字 | ≥662 / 0 fail（不精确匹配） | 新增 4 测试后必然 666，精确匹配会自相矛盾（ADR-019） |

## v1 范围 / v2 范围 / Out

### v1（本次 change）
- l3-api.sh 拆分（smart_truncate 移走）
- gate-helpers.sh 拆分（6 谓词移走）
- CONTEXT.md / LESSONS.md / CHANGELOG.md / STATE.md 同步
- 4 个新 metrics bats 测试

### v2（未来 change）
- 拆分后函数内部进一步重构（如 smart_truncate 内部分段）
- 新增针对拆出函数的单元测试
- TD-072 之外的 file-level 长度优化（如 l3-prompt.sh / gate-checks-review.sh 接近 250）

### Out（不在本 change）
- 任何函数逻辑修改
- 任何调用方代码修改
- ADR（无架构决策，纯机械拆分）
- A-evolve 重扫
