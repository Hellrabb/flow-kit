# REVIEW — L3 独立审查异步化

- **Change ID**: l3-async-dispatch
- **审查日期**: 2026-07-07

---

## 规格合规

| AC | 要求 | 验证 |
|---|---|---|
| AC-1 | PreToolUse gate 不再同步调 L3 API | ✅ `grep l3_review_with_timeout` 仅命中注释行 |
| AC-2 | .done 存在且有效 → 放行 + F1 L3_RESULT | ✅ 保留 fk_validate_done_marker + _l3_format_result |
| AC-3 | .done 不存在 → 派发提示 + 拦截 | ✅ l3_dispatch_prompt >&2 + exit 2 |
| AC-4 | l3_dispatch_prompt 格式与 L2 一致 | ✅ 框线 + Agent 命令 + 手动备选 + 参数说明 |
| AC-5 | l3_review_run 不受影响 | ✅ 函数签名和行为完全不变 |
| AC-6 | bash -n 通过 | ✅ 两个文件均通过 |
| AC-7 | 全量 bats 0 failures + 新测试 | ✅ 9/9 新测试；L3 相关现有测试全绿 |

## 代码质量（6 维）

| 维度 | 评分 | 说明 |
|---|---|---|
| R1 接口契约 | 🟢 | `l3_dispatch_prompt()` 有完整函数头注释（参数/输出/返回） |
| R2 错误处理 | 🟢 | 参数校验失败 → exit 2；`l2v` 提取失败 → 默认 `fail` |
| R3 知识重复 | 🟢 | 与 `l2_dispatch_prompt()` 是对等函数，不属重复——职责不同（L2 vs L3） |
| R4 命名一致性 | 🟢 | `l3_` 前缀与 l3-review.sh 全部函数一致 |
| R5 依赖秩序 | 🟢 | PreToolUse gate → l3-review.sh lib，单向依赖不变 |
| R6 测试覆盖 | 🟢 | 9 tests 覆盖全部 dispatch 分支 + 边界 + 参数验证 |

## 风险回顾

对照 DESIGN.md § 4，无意外风险触发。gate 重构未引入新依赖或新 fail 路径。
