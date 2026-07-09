# SUMMARY: TD-002 stop 链 17 主脚本覆盖表

> **覆盖判定**：`covered` = 有 bash-n+shebang+grep 关键函数 smoke（test_stop_chain 范式）/ `partial` = 仅 bash-n（test_smoke_syntax 全量门禁）/ `gap` = 无
> **来源**：`test_stop_chain.bats`（22/24/26/99/00 显式 smoke）+ `test_smoke_syntax.bats`（全 .sh bash-n）+ grep `test/*.bats`

| 脚本 | 分类 | 状态 | test 引用 |
|---|---|---|---|
| 00-gate | coord | covered | test_stop_chain.bats:84（调度列表 grep 27/28/29）|
| 01-transcript-parse | coord | partial | test_smoke_syntax.bats（bash-n）|
| 20-claude-md | coord | partial | test_smoke_syntax.bats |
| 21-memory | coord | partial | test_smoke_syntax.bats |
| 22-git | business | covered | test_stop_chain.bats:14（bash-n+shebang+grep）|
| 23-quality | business | partial | test_smoke_syntax.bats |
| 24-session | coord | covered | test_stop_chain.bats:32 |
| 25-project | coord | partial | test_smoke_syntax.bats |
| 26-workflow | business | covered | test_stop_chain.bats:49 |
| 27-interactive-ui-check | business | partial | test_smoke_syntax.bats |
| 28-weak-model-compliance | business | partial | test_smoke_syntax.bats（lib 测试在 test_weak_model_compliance，非主脚本 smoke）|
| 29-independent-review | business | partial | test_smoke_syntax.bats（lib 测试在 test_independent_review_model，非主脚本 smoke）|
| 30-ai-analyze | business | partial | test_smoke_syntax.bats（lib 测试在 test_independent_review_model，非主脚本 smoke）|
| 31-auto-advance | coord | partial | test_smoke_syntax.bats |
| 32-fallback-guard | coord | partial | test_smoke_syntax.bats |
| 33-flow-active-integrity | business | partial | test_smoke_syntax.bats（lib 测试在 test_flow_active_integrity，非主脚本 smoke）|
| 99-report | aggrep | covered | test_stop_chain.bats:66 |

## 结论

- **covered**: 5（00-gate / 22-git / 24-session / 26-workflow / 99-report · test_stop_chain 显式 smoke）
- **partial**: 12（仅 test_smoke_syntax bash-n）
- **gap**: 0

## T03 补 smoke 范围（[business] + partial）

6 个 [business] 脚本缺主脚本 grep 关键函数 smoke：
- 23-quality
- 27-interactive-ui-check
- 28-weak-model-compliance
- 29-independent-review
- 30-ai-analyze
- 33-flow-active-integrity

（22-git / 26-workflow 已 covered；[coord] partial 留 v2；[aggrep] 99-report 已 covered）
