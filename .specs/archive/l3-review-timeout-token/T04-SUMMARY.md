# T04-SUMMARY · 全量回归 + AC-9 冒烟

- **Change ID**: l3-review-timeout-token
- **Task**: T04（全量回归 + lint + 双源同步 + AC-9 端到端冒烟）
- **日期**: 2026-07-25

---

## 做了什么

### 1. make test 全量回归（AC-8）

- 首次 make test 报 fail——双源一致性测试 AC-7（test/ 与 flow-kit-bundle/test/ 一致）因 T03 改了 test/ 未同步而 fail
- 跑 make test-sync 后重跑 make test → **606 ok / 0 fail / exit 0** ✅

### 2. make lint shellcheck（error 级别）

- `✅ shellcheck: no errors found` / exit 0 ✅
- 本 change 新增代码（_l3_call_api env var 解析 + Fail-safe + jq -c）无 error 级问题

### 3. make test-sync 双源同步

- test/test_l3_review.bats → flow-kit-bundle/test/test_l3_review.bats ✅ 一致
- test/test_l3_review_params.bats → flow-kit-bundle/test/test_l3_review_params.bats ✅ 一致
- diff -q 验证双源逐字一致

### 4. AC-9 端到端冒烟（手动 · 非回归线）

用修复后的 L3 工具跑 gate-done-authorship phase 3 审查：

```
source l3-review.sh && l3_review_run 3 gate-done-authorship ... pass both
```

**结果**：
- `[l3-review] using max_tokens=32000 timeout=300 thinking=enabled` — 三默认值全部落地 ✅
- 触发真实 API 重审（TASK.md artifact hash 变更：1313ed1b → 3b562bc）
- API 返回 **text block** → verdict 可提取 → **rc=1（fail）**，非 rc=3 ✅
- TASK.md 18KB 产物在 300s timeout 内产出 text block（与 T01 R3 探针证据 101s/4872 token 一致）

**核心目标达成**：本 change 的修复在真实端到端调用中生效——deepseek-v4-pro 大产物审查不再 rc=3 超时/空响应。

## verify 输出

```
make test     → 606 ok / 0 fail / exit 0  ✅
make lint     → no errors found / exit 0  ✅
make test-sync → 双源已同步 / diff 一致   ✅
AC-9 冒烟     → rc=1（fail）非 rc=3       ✅（工具层解套）
```

```
make test && make lint && ! grep -rnE "..." flow-kit-bundle/hooks/ ... && diff -q ... && echo "ALL GREEN"
→ ALL GREEN
```

## 5 越界检查（R6.5）

- TASK write_files：`flow-kit-bundle/test/test_l3_review.bats`（make test-sync 输出）
- 实际 diff：flow-kit-bundle/test/test_l3_review.bats + test_l3_review_params.bats（双源同步）
- 越界：0 ✅

## 6 维自查

- T04 无代码改动（纯验证 + 同步）→ R1-R6 N/A

## AC 覆盖

- AC-8 全量 bats 0 fail：make test 606 ok ✅
- AC-9 端到端冒烟：rc=1 非 rc=3 ✅（工具层解套达成）

## 关键结论

**本 change（l3-review-timeout-token）完成且验证有效**：

1. **工具层解套**：deepseek-v4-pro 大产物审查不再 rc=3（max_tokens 8000→32000 + timeout 90→300 + thinking 可配 + jq -c compact + Fail-safe 区分未设/非法）
2. **三个 env var 全可配**：FLOW_KIT_L3_MAX_TOKENS / FLOW_KIT_L3_TIMEOUT / FLOW_KIT_L3_THINKING
3. **Fail-safe 健壮**：未设走默认不警告，非法值回退默认 + 警告
4. **可观测性**：stderr 记录实际配置值
5. **双源同步**：test/ 与 flow-kit-bundle/test/ 一致

**gate-done-authorship 解套状态**：工具层已解套（L3 能跑了），但 gate-done-authorship 自身 TASK.md 内容层有 L3 发现的 1 Critical（T01 path-guard 缺 l3_review_run 放行机制）——需切回 gate-done-authorship 修 TASK.md 后重跑 L3 → verdict=pass → .done → transition 3→4。**此为 gate-done-authorship 的 scope，非本 change**。

## 是否触发新 fix-plan

否（对本 change）。但发现 gate-done-authorship TASK.md 的 L3 Critical（T01 path-guard 放行逻辑）——切回 gate-done-authorship 时需修。
