# TEST: 用户指南全量更新 + interrupt/checkpoint 自动写入

- **Change ID**: user-guide-update
- **关联**: `@.specs/user-guide-update/REQUIREMENT.md`

## 测试矩阵

| # | AC (REQUIREMENT.md) | 测试用例 | 验证方式 | 结果 |
|---|---|---|---|---|
| 1 | AC-1 三份文档覆盖全部功能 | 逐项对照 .feature-checklist.md 14 项功能，在 FLOW-KIT-用户指南.md / README.md / flow-kit-ecosystem-guide.md 三份文档中确认 | 人工逐项对照 | ✅ 全部覆盖 |
| 2 | AC-2 interrupt/checkpoint 章节覆盖5点 | 阅读 FLOW-KIT-用户指南.md §interrupt/checkpoint：字段结构表、/flow checkpoint 用法+示例、中断恢复流程、手动时机、/flow 展示格式 | 人工确认5点 | ✅ |
| 3 | AC-3 auto-checkpoint 4种触发 | ① Write/Edit: edit FLOW-KIT-用户指南.md → check interrupt；② 测试失败: `(exit 1)` → check interrupt；③ phase transition: jq write .goal.current_phase → check interrupt；④ toll-gate pause: 选项2 → check interrupt。每次检查: active_file(相对路径)、last_action(≤200chars)、checkpoint_at(ISO8601)、updated_at 刷新 | `jq -e '.interrupt.active_file'` + `jq -e '.interrupt.checkpoint_at'` + 人工确认格式 | ✅ 4场景通过 |
| 4 | AC-4 auto不干扰手动 | 自动 checkpoint → `/flow checkpoint "test.sh" "manual override"` → 确认 interrupt 覆盖为手动值 | `jq '.interrupt.last_action'` 输出 "manual override" | ✅ test_checkpoint.bats:2 |
| 5 | AC-5 中断恢复上下文注入 | ① GO.md 路由表 "继续" 含 interrupt 字段引用 (grep 确认)；② 阶段 prompt 恢复段含 interrupt 上下文注入逻辑 (grep active_file/last_action/checkpoint_at 确认) | `grep -cE "interrupt|active_file|last_action|checkpoint_at" GO.md` ≥3 | ✅ 5 matching lines |
| 6 | AC-6 文档与代码一致 | 逐条执行用户指南中 /flow checkpoint、/flow goal --gate-config 命令示例 | 手动执行 | ✅ 一致 |

## 非功能性需求验证

| NFR | 测试 | 结果 |
|---|---|---|
| 可靠性：原子写入 | test_checkpoint.bats:11 "preserves old value on JSON validation failure" | ✅ |
| 可靠性：JSON 校验 | test_checkpoint.bats:8 "passes valid JSON" + :9 "rejects invalid JSON" | ✅ |
| 兼容性：向后兼容 .flow-active 格式 | 现有 331 bats tests pass（含 checkpoint-lib 新增 11 tests） | ✅ |
| 可观测性：失败时 stderr warn | checkpoint_write 失败路径含 `echo ... >&2`（源码审查确认） | ✅ |

## 全量回归

```bash
npx bats test/  # 331/332 pass
```

1 个已知失败：`test_quality_baseline.bats` AC-7 (test/ 与 flow-kit-bundle/test/ 目录一致性) — 新增 test_checkpoint.bats 尚未同步到 bundle，属打包步骤（Phase 7 处理），非功能缺陷。

## 与 TASK.md 的追溯

| TASK.md verify | 对应 AC | 通过 |
|---|---|---|
| T01: test -f .feature-checklist.md + wc -l ≥20 | AC-1 前置 | ✅ |
| T03: grep -cE L2/L3/both ≥5 + checkpoint/interrupt ≥10 | AC-1, AC-2 | ✅ |
| T06: bash -n + 函数数 ≥3 | AC-3, AC-4 前置 | ✅ |
| T09: npx bats test/test_checkpoint.bats (11/11) | AC-3, AC-4 | ✅ |
| T10: grep -cE ≥3 in GO.md | AC-5 | ✅ |
| T11: npx bats test/ (331/332) | AC-6, 全量回归 | ✅ |
