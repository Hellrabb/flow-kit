# ADR-004 · gate 函数返回值语义（显式 rc 判定）

- **Status**: Accepted
- **Date**: 2026-07-17
- **Change**: l2-l3-test-defect（修 BUG-A/B）

## Context

`_run_review_gates`（independent-review-gate.sh）编排 7 个 Gate。Gate2 `_gate_phase_filter` / Gate3 `_gate_active_check` 用业务约定 `return 0 = skip/未开`、`return 1 = continue/开`。

但调用方用 bash `||` 惯例消费返回值：
```bash
pf_output=$(_gate_phase_filter "$flow_file") || exit 0   # 非0 → exit 0 放行
```

`||` 在 bash 中"非0退出码触发"。`return 1`（continue，应继续检查）→ 触发 `exit 0`（放行）；`return 0`（skip，应放行）→ 不触发 → 继续 gate 检查。**语义系统性反转**。

后果（BUG-A/B）：
- phase 0（return 0=skip）→ 继续 gate 检查 → 撞 Gate6 forward → 误拦死锁
- review phase（return 1=continue）→ `exit 0` 放行 → gate 完全失效（commit/transition 畅通无阻）

## Decision

调用方用**显式 rc 判定**，不依赖 `|| exit 0`：

```bash
local pf_output phase change_id
if pf_output=$(_gate_phase_filter "$flow_file" 2>/dev/null); then
  exit 0   # return 0 = skip → 放行
fi
# return 1 = continue → 提取 phase/change_id，继续 Gate3
```

Gate3 同理：`if _gate_active_check "$phase" "$cwd"; then exit 0; fi`（return 0=未开→放行）。

## Consequences

✅ review phase 正确 deny（return 1 → 继续 → deny）
✅ phase 0 正确放行（return 0 → exit 0）
✅ set -e 安全（`if cmd; then` 条件上下文不受 set -e 影响）
⚠️ 后续新增 gate 函数 return 0/1 语义须文档化（本 ADR + CONTEXT「返回值语义反转」术语）
⚠️ 调用方多 1 行（if 判定 vs ||），可接受
