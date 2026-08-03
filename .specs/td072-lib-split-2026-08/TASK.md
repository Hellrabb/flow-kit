# TASK · td072-lib-split-2026-08

> 来源: DESIGN.md §6 · 4 tasks in 3 waves · mechanical lib file split

---

## Wave 1（2 并行）

### T01 · l3-api.sh smart_truncate 移至 l3-truncate.sh

**model-tier**: standard
**read_files**:
- `flow-kit-bundle/hooks/stop/lib/l3-api.sh`
- `flow-kit-bundle/hooks/stop/lib/l3-truncate.sh`

**write_files**:
- `flow-kit-bundle/hooks/stop/lib/l3-api.sh` (modify: 删除 smart_truncate)
- `flow-kit-bundle/hooks/stop/lib/l3-truncate.sh` (modify: 追加 smart_truncate)

**actions**:
1. Read l3-api.sh L1-167 (smart_truncate 完整定义 L18-166 + 头部)
2. Append smart_truncate 函数到 l3-truncate.sh 末尾（保留原 _l3_check_rerun）
3. Delete L18-166 from l3-api.sh
4. 修正 l3-api.sh 头部注释（移除 smart_truncate 引用）
5. `bash -n` 两文件

**verify**:
- `wc -l flow-kit-bundle/hooks/stop/lib/l3-api.sh` ≤ 250
- `wc -l flow-kit-bundle/hooks/stop/lib/l3-truncate.sh` ≤ 250
- `grep -c '^smart_truncate()' flow-kit-bundle/hooks/stop/lib/l3-api.sh` = 0
- `grep -c '^smart_truncate()' flow-kit-bundle/hooks/stop/lib/l3-truncate.sh` ≥ 1
- `bash -n flow-kit-bundle/hooks/stop/lib/l3-api.sh && bash -n flow-kit-bundle/hooks/stop/lib/l3-truncate.sh` exit 0

**done**:
- T01-completed.md 含行数前后对比 + bash -n 输出

---

### T02 · gate-helpers.sh 拆分聚合入口

**model-tier**: standard
**read_files**:
- `flow-kit-bundle/hooks/pre-tool-use/gate-helpers.sh`

**write_files**:
- `flow-kit-bundle/hooks/pre-tool-use/gate-helpers.sh` (modify: 改聚合入口)
- `flow-kit-bundle/hooks/pre-tool-use/gate-helpers-types.sh` (new: 6 type 谓词)

**actions**:
1. 创建 `gate-helpers-types.sh`，含 6 个 MOVE 函数（_is_dotdone_write / _gate_is_l2_only / is_phase_write / _fk_phase_direction / _command_has_write_context / is_git_commit）+ 头部注释 + `set -euo pipefail`
2. 重写 `gate-helpers.sh`：顶部 `source "$(dirname "${BASH_SOURCE[0]}")/gate-helpers-types.sh"` + 保留 7 个 STAY 函数（fk_check_gate_config_tamper / _command_first_tokens / _gate_path_guard / _gate_phase_filter / _gate_active_check / _gate_done_validation / _gate_tamper_detect）
3. `bash -n` 两文件

**verify**:
- `wc -l flow-kit-bundle/hooks/pre-tool-use/gate-helpers.sh` ≤ 250
- `wc -l flow-kit-bundle/hooks/pre-tool-use/gate-helpers-types.sh` ≤ 250
- `bash -n` 两文件 exit 0
- `grep -c 'source.*gate-helpers-types' flow-kit-bundle/hooks/pre-tool-use/gate-helpers.sh` = 1

**done**:
- T02-completed.md 含行数对比 + source 链验证

---

## Wave 2（1 serial，依赖 T01+T02）

### T03 · metrics 测试

**model-tier**: standard
**read_files**:
- `test/test_common_metrics.bats`（参考格式）

**write_files**:
- `test/test_lib_split_metrics.bats` (new)
- `flow-kit-bundle/test/test_lib_split_metrics.bats` (sync copy)

**actions**:
1. 创建 `test/test_lib_split_metrics.bats`，含 4 个测试：
   - AC-B1-metric: l3-api.sh ≤ 250
   - AC-B2-metric: l3-truncate.sh ≤ 250
   - AC-B3-metric: 4 文件循环 ≤ 250
   - AC-C2-metric: smart_truncate 定义位置校验
2. `cp test/test_lib_split_metrics.bats flow-kit-bundle/test/`

**verify**:
- `npx bats test/test_lib_split_metrics.bats` 4/4 ok
- `npx bats flow-kit-bundle/test/test_lib_split_metrics.bats` 4/4 ok

**done**:
- T03-completed.md 含双源测试输出

---

## Wave 3（1 serial，依赖 T01-T03）

### T04 · CONTEXT.md 禁动 + CHANGELOG + commit

**model-tier**: standard
**read_files**:
- `.specs/CONTEXT.md`（既有抽象索引段 + 禁动清单段）
- `.specs/CHANGELOG.md`
- `.specs/LESSONS.md`

**write_files**:
- `.specs/CONTEXT.md` (modify: 既有抽象索引段加 gate-helpers-types.sh 条目)
- `.specs/CHANGELOG.md` (modify: 追加 td072-lib-split-2026-08 条目)
- `.specs/LESSONS.md` (modify: TD-072 标 ✅ Resolved)

**actions**:
1. CONTEXT.md 既有抽象索引段（`### flow-kit 核心抽象`）追加：`| gate-helpers-types.sh | gate 类型谓词聚合入口（6 函数：_is_dotdone_write/_gate_is_l2_only/is_phase_write/_fk_phase_direction/_command_has_write_context/is_git_commit） | td072-lib-split-2026-08 |`
2. CHANGELOG.md 追加单行：`| 2026-08-03 | td072-lib-split-2026-08 | l3-api.sh+gate-helpers.sh 拆分到职责单一子文件（聚合入口模式） | - |`
3. LESSONS.md TD-072 状态改为 ✅
4. `git add -A .specs/ flow-kit-bundle/hooks/ flow-kit-bundle/test/ test/ && git commit -m "feat: td072-lib-split-2026-08 — l3-api.sh + gate-helpers.sh 职责拆分"`

**verify**:
- `npx bats test/ && npx bats flow-kit-bundle/test/` ≥ 666 tests / 0 fail
- `git log --oneline -1` 含 td072-lib-split
- `git status` clean (除 .omo/ + pptx)

**done**:
- T04-completed.md 含 commit SHA + 全量回归输出
