# CHANGE: L3 独立审查异步化

- **Change ID**: l3-async-dispatch
- **创建日期**: 2026-07-07
- **路径建议**: 完整（REQUIREMENT → DESIGN → TASK → DEV → TEST → REVIEW → INTEGRATION）
- **状态: done（2026-07-07 · 2 commits · 9+9 tests · AC-1~7 + L2-gap · 全量回归 0 regressions）

---

## Why

flow-kit 的 L3 外部模型独立审查在 PreToolUse hook（`independent-review-gate.sh`）中通过 `l3_review_with_timeout(30s)` 同步调用外部模型 API。30s timeout 对于 Phase 6（git diff + REVIEW.md）和 Phase 7（全量产物）等需要外部模型仔细审查的场景严重不足，导致：

- API 调用大概率超时 → 写 `verdict=timeout` 的 `.done` 文件
- `verdict=timeout` 被 gate 校验接受 → L3 实际**没有完成有效审查**就放行
- 用户对独立审查机制的信任度下降

L2 独立审查已通过「派发提示 → agent 异步执行子 agent → 写结果 → 重试放行」的模式解决了此问题。L3 应当走同样的异步模式。

## What

1. 在 `l3-review.sh` 中新增 `l3_dispatch_prompt()` 函数（对标 `l2_dispatch_prompt()`），生成 L3 异步派发的 Agent 命令模板
2. 修改 `independent-review-gate.sh`：将 L3 同步调用（`l3_review_with_timeout 30`）替换为异步派发模式：
   - 检查 `.independent-review-<N>.done` 是否已存在且有效 → 放行（L3 已完成）
   - 否则 → 输出 `l3_dispatch_prompt()` 派发提示 → exit 2 拦截
   - agent 异步派发 L3 子 agent → 写 `.done` → 重试放行

## 影响面

- **修改文件**: `flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh`（~70 行删，~35 行增）、`flow-kit-bundle/hooks/stop/lib/l3-review.sh`（新增 ~65 行）
- **不动文件**: `29-independent-review.sh`（Stop hook 仍直接调 `l3_review_run`，无超时压力）、`flow-kit-resume.sh`（SessionStart F2 注入路径不变）、`l2-detect.sh`（L2 派发不变）
- **不影响**: L3 API 调用逻辑（`l3_review_run` 函数签名和行为不变）、`.done` 文件格式（6 键 KVP 不变）、gate_config 解析逻辑

## 范围排除（这次不做）

- 不改 `l3_review_run()` 的 API 调用逻辑（审查 prompt 构造、模型选择、响应解析）
- 不改 Stop hook 的 L3 触发机制（已支持无超时 async fallback）
- 不改 L2 派发逻辑
- 不增加 L3 重试/退避机制（v2）

## 验收线

- PreToolUse gate 不再调用 `l3_review_with_timeout`（无 30s 同步阻塞）
- `l3_dispatch_prompt()` 输出格式与 `l2_dispatch_prompt()` 一致（框线 + 子 agent 命令 + 参数说明）
- 当 `.done` 已存在且有效时直接放行（L3 已由 Stop hook 或手动派发完成）
- 当 `.done` 不存在时输出派发提示 + exit 2 拦截
- 现有 bats 测试全绿，新增 async dispatch 专项测试覆盖新分支
- `bash -n` 全部通过
