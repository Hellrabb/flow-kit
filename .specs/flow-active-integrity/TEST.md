# TEST: flow-active-integrity

- **Change ID**: flow-active-integrity
- **日期**: 2026-07-03

---

## 0. 测试范围

本次测试覆盖 33-flow-active-integrity.sh 的 6 条 AC + NFR 可靠性场景。

---

## 1. 功能测试（5 轮金字塔 · 第 1 轮）

| AC | 测试用例 | Given/When/Then | 结果 |
|---|---|---|---|
| AC-1 | all user-scope prompts contain PCSC anchor text | Given: prompts 已编辑; When: grep anchor; Then: 9 hits | ✅ |
| AC-1 | all bundle prompts contain PCSC anchor text | Given: bundle 已同步; When: grep anchor; Then: 9 hits | ✅ |
| AC-2 | detects missing artifact for current phase | Given: phase=2, no DESIGN.md; When: run check; Then: violation | ✅ |
| AC-2 | no violation when all artifacts present | Given: phase=1, REQUIREMENT.md exists; When: run check; Then: no violation | ✅ |
| AC-3 | detects dangling change_id | Given: change_id=ghost, no dir; When: run check; Then: violation | ✅ |
| AC-3 | detects null change_id with active directories | Given: change_id=null, .specs/ has dirs; When: run check; Then: violation | ✅ |
| AC-4 | detects phases_done artifact missing | Given: phases_done=["0","1","2"], no DESIGN.md; When: check; Then: violation | ✅ |
| AC-4 | detects gate passed but phase not in phases_done | Given: gate "1→2"=passed, phases_done=["0"]; When: check; Then: violation | ✅ |
| AC-4 | detects current_phase gate not passed (R7) | Given: current_phase=2, gate "1→2"!="passed"; When: check; Then: violation | ✅ |
| AC-4 | no violation when pipeline fields are consistent | Given: all fields self-consistent; When: check; Then: no violation | ✅ |
| AC-5 | detects stale updated_at (>24h) | Given: updated_at 25h ago; When: check; Then: stale violation | ✅ |
| AC-5 | no violation for fresh updated_at | Given: updated_at <1h ago; When: check; Then: no violation | ✅ |
| AC-6 | detects token_spent=0 with .flow-active writes | Given: token=0, transcript has jq writes; When: check; Then: violation | ✅ |
| AC-6 | no violation when token_spent > 0 | Given: token>0; When: check; Then: no violation | ✅ |

**功能轮覆盖**: 6/6 AC (100%)

---

## 2. 性能测试（第 2 轮）

- **本轮状态**: ⏭️ 跳过
- **理由**: 33 号模块为纯 shell 脚本（jq + grep + find），无网络 I/O、无数据库查询。DESIGN R3 已评估：全部本地文件操作 < 200ms。性能风险低，不做专项压测。

---

## 3. 安全测试（第 3 轮）

- **本轮状态**: ⏭️ 跳过
- **理由**: 模块仅读取本地 `.flow-active` / `.specs/` 并写入 `.flow-active.correction`，无网络通信、无外部输入解析。路径脱敏已在代码中实现（仅写相对路径）。安全风险低。

---

## 4. 兼容性测试（第 4 轮）

- **本轮状态**: ⏭️ 跳过
- **理由**: 模块依赖 `jq`（已在 guard 中检查可用性）+ bash 4.x+（`set -euo pipefail` 已测试）。NFR 可靠性测试已覆盖 jq 缺失 / JSON 损坏 / 目录不可读 / PHASE_ARTIFACTS 回退 4 种降级路径。无跨平台兼容性需求（仅在 Linux 上运行）。

---

## 5. 可观测性测试（第 5 轮）

- **本轮状态**: ⏭️ 跳过
- **理由**: 模块通过 `correction-file.sh` 输出结构化 JSON（type + violations[] + written_at），无需额外日志/埋点。检测结果在 SessionStart 时通过矫正 banner 展示给用户，已满足可观测性需求。

---

## NFR 可靠性测试

| 场景 | 测试用例 | 结果 |
|---|---|---|
| jq 不可用 | handles missing jq gracefully — 返回 0 不崩溃 | ✅ |
| JSON 损坏 | handles corrupt JSON — 检测到并写入矫正文件 | ✅ |
| 目录不可读 | handles unreadable .specs/ directory — 返回 0 不崩溃 | ✅ |
| PHASE_ARTIFACTS 回退 | built-in fallback works — 返回正确产物名 | ✅ |
| 矫正文件合并 | read-merge-write preserves existing violations | ✅ |

---

## 覆盖率

- **AC 覆盖**: 6/6 (100%) — 14 test cases (含 AC-1 × 2)
- **NFR 覆盖**: 5/5 (100%)
- **新增测试**: 19 tests (14 AC + 5 NFR)

---

## 回归测试

```bash
npx bats test/
# 结果: 299 tests, 0 failures
# 新增 19 tests (test_flow_active_integrity.bats) + 既有 280 tests 全绿
```

修改 00-gate.sh (+9 lines) 和 common.sh (+1 word) 均为追加操作，不改变既有模块执行逻辑，回归全量通过确认无退化。
