# TEST: 弱模型交互式 UI 触发强化

- **Change ID**: `weak-model-interactive-ui`
- **关联**: `@.specs/weak-model-interactive-ui/REQUIREMENT.md`

---

## 测试基线

| 套件 | Tests | Pass | Fail | Skip |
|---|---|---|---|---|
| `test_interactive_ui_check.bats` | 24 | 24 | 0 | 0 |
| 既有测试套件 | 162 | 162 | 0 | 0 |
| Regression demo `check.sh` | 8 | 8 | 0 | 0 |
| **总计** | **194** | **194** | **0** | **0** |

## AC 对照

| AC | 描述 | 验证方式 | 结果 |
|---|---|---|---|
| AC-1 | 全链路交互 UI 点位扫描 | DESIGN § 2 — 11 个点位已标定 | ✅ |
| AC-2 | AskUserQuestion 触发护栏 | 13 guards 插入 8 个 prompt 文件 | ✅ |
| AC-3 | EnterPlanMode 触发护栏 | 2 EnterPlanMode guards + regression demo | ✅ |
| AC-4 | 回归演示 | `check.sh` 8/8 全绿 | ✅ |
| AC-5 | 强模型行为不变 | 护栏 ≤3 行/点；`weak-model-guard` 注释可跳过 | ✅ |
| AC-6 | 现有测试全量通过 | 194/194 tests pass | ✅ |

## 新增测试

- `test/test_interactive_ui_check.bats` — 24 tests covering GATE_MAP / check_interaction_gate / check_tool_invocation / correction file CRUD / retry_count logic / SessionStart injection / syntax check
