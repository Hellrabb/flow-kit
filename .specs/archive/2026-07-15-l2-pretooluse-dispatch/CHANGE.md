# CHANGE: L2 PreToolUse Dispatch — 阶段切换时前置触发 L2 独立审查

- **Change ID**: `l2-pretooluse-dispatch`
- **创建日期**: 2026-07-15
- **路径建议**: 完整
- **状态**: archived

---

## Why（为什么做）

当前 L2 独立审查仅在 **Stop hook**（`29-independent-review.sh`）中触发——即对话结束后才检测 L2 缺失并提醒用户。这导致一个问题：AI 在阶段切换（写 `.flow-active.phase`）时不会被告知"目标阶段需要 L2 审查"，从而可能在 L2 缺失的情况下继续推进后续阶段，等到 Stop hook 才补救，浪费 token 且可能基于未经审查的中间产物做决策。

L3 已有 PreToolUse dispatch（`independent-review-gate.sh` 中集成），L2 却缺失这一前置拦截能力。补齐后可让 L2/L3 在 PreToolUse 层保持一致的分发模型。

## What（做什么）

### 主体：L2 PreToolUse Dispatch

在现有 `independent-review-gate.sh`（PreToolUse hook）中扩展 L2 dispatch 能力：

1. **检测**：阶段切换时（`is_phase_write` 命中），检查目标阶段在 `gate_config` 中是否配置了 `L2` 或 `both`
2. **判断缺失**：调用 `l2_detect_missing()` 检查 `INDEPENDENT-REVIEW-<phase>.md` 是否已有 L2 段
3. **硬拦截**：L2 缺失 → `exit 2` deny 阶段切换（fail-close，与现有 L3 拦截同策略）
4. **自动派发**：在拦截前自动调用 Anthropic API 派发 L2 审查 Agent（异步 fire-and-forget），失败时降级为手动命令
5. **接线**：验证 `install_hooks.sh` 的 PreToolUse matcher 配置覆盖 L2 dispatch 触发场景

### 附带修复：L3 写入管道（Stop hook）

本次排查发现 Stop hook 的 L3 审查结果存在**静默丢失**问题——`2>/dev/null` 吞错误 + `>>` 非原子写入。一并修复：

6. **去错误静默吞没**：`_l3_scan_backlog` + 当前阶段 L3 调用的 `2>/dev/null` 移除，stderr 正常输出，失败时 `module_output` 记录
7. **原子写入**：L3 段 + .done 改用 temp-file + mv 原子写入（防主 agent Edit 竞态覆盖）
8. **写入后验证**：`grep -q "^## L3 盲审"` 验证持久化成功

## 影响面

- [x] 影响 `REQUIREMENT.md`
- [x] 影响 `DESIGN.md` / 引入新 ADR（涉及 PreToolUse gate 核心链扩展，需记录设计决策）
- [ ] 影响现有 AC（无既有 AC 被修改）
- [ ] 影响数据模型 / 迁移
- [ ] 影响外部 API 兼容性
- [ ] 仅修复 bug，无范围变化

## 范围排除（这次不做）

- **不改 L3 dispatch 逻辑**：L3 PreToolUse gate 判定（`_gate_check_l3` / `_gate_do_transition`）保持现状。L3 写入管道修复（29 号 + l3-review.sh）属于 Stop hook 侧，不影响 PreToolUse L3 gate
- **不改 Stop hook L2 检测逻辑**：`29-independent-review.sh` 的 L2 检测/done-validation 逻辑不变；本次只修复同一文件中 L3 调用的错误吞没问题
- **不建新 hook 脚本**：不新增独立 PreToolUse/Stop hook 文件，全部在既有文件中扩展
- **不做 L2/L3 统一 dispatch 框架抽象**：TD-008（拆 `l3-review.sh`）留给后续 change
- **不改 stop-hook.json 顶层结构**：不引入新的配置范式

## 验收线（粗粒度，不是 AC）

- 当 `gate_config` 中某阶段配置了 `L2` 或 `both`，且该阶段 L2 审查未完成时，AI 写 `.flow-active.phase` 切换阶段会被 PreToolUse hook 硬拦截（exit 2）
- L2 审查完成后（`INDEPENDENT-REVIEW-<phase>.md` 含 `## L2 盲审` 段），同一阶段切换不再被拦截
- 现有 L3 PreToolUse dispatch 行为不受影响（回归验证）
- 现有 Stop hook L2 检测行为不受影响（独立路径验证）
- L3 backlog 扫描 + 当前阶段 L3 调用的错误不再被 `2>/dev/null` 静默吞没，失败时 hooks.log 有 `module_output` 记录
- L3 内容 + .done 使用原子写入（temp-file + mv），写入后有 grep 验证持久化成功

## 风险与未知

- **Agent API 调用在 hook 内的稳定性**：PreToolUse hook 内同步调用 Claude Agent API 派发 L2 审查，需处理 API 超时/失败降级（不能因派发失败卡死工具流）
- **gate 核心链改动风险**：`independent-review-gate.sh` 属禁动清单核心链（CONTEXT.md line 383），改动需充分回归测试，覆盖 L2/L3/commit/PR/path-guard 全部场景
- **与 auto_advance 的交互**：pipeline auto_advance 模式下阶段切换由 hook 自动触发，L2 硬拦截会打断自动推进——需在设计阶段明确 auto_advance 下的行为
- **Token 成本**：每次阶段切换额外派发一个 L2 Agent（~15k-30k tokens），需在 gate_config 中谨慎控制哪些阶段开启 L2 PreToolUse

---

> 后续 AC 与设计细节进入 `REQUIREMENT.md` / `DESIGN.md`，本文件不再扩展。
