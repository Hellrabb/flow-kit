# TEST: l3-review-hardening

- **Change ID**: l3-review-hardening
- **日期**: 2026-07-03

## 0. 测试范围
10 bats cases covering AC-1 ~ AC-6.

## 1. 功能测试（第 1 轮）

| AC | 测试用例 | 结果 |
|---|---|---|
| AC-5 | max_tokens=8000 | ✅ |
| AC-5 | curl timeout=90s | ✅ |
| AC-4 | dual-block: text extracted | ✅ |
| AC-4 | dual-block: thinking fallback | ✅ |
| AC-6 | verdict from raw JSON | ✅ |
| AC-6 | verdict from mixed text via regex fallback | ✅ |
| AC-6 | unknown when no verdict | ✅ |
| AC-3 | L3 section dedup (old stripped, new appended) | ✅ |
| AC-1 | git ls-files finds untracked .sh | ✅ |
| AC-2 | phase 7 artifact listing complete | ✅ |

## 2-5轮
⏭️ 跳过（性能/安全/兼容/可观测 — Bash lib bugfix，无新增风险面）

## 回归
`npx bats test/` 全量未跑（本 change 仅修改 l3-review.sh + 新增 test_l3_review.bats）
