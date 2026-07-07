# REQUIREMENT — L3 独立审查异步化

- **Change ID**: l3-async-dispatch
- **版本**: v1

---

## 用户故事

- **作为** flow-kit 使用者（已开启 gate_config L3 的开发者）
- **我想** L3 外部模型审查以异步派发方式完成（而非 PreToolUse hook 内 30s 同步超时假放行）
- **以便** L3 审查能拿到真实 verdict，不因 API 响应慢而被跳过

---

## 验收准则（AC）

### AC-1 · PreToolUse gate 不再同步调 L3 API

- **Given** agent 尝试 phase transition / commit / PR，当前阶段 gate_config 含 L3（both 或 L3-only）
- **When** PreToolUse hook 拦截到此次操作
- **Then** hook **不调用** `l3_review_with_timeout` 或任何同步 L3 API 调用（无 30s timeout）

### AC-2 · L3 已完成时直接放行

- **Given** `.specs/<id>/.independent-review-<N>.done` 已存在且通过 `fk_validate_done_marker` "transition" tier 校验
- **When** agent 执行 phase transition / commit / PR
- **Then** PreToolUse hook 放行（exit 0），并输出 `L3_RESULT: verdict=... summary=... report=...` 到 stdout（F1 路径）

### AC-3 · L3 未完成时派发提示 + 拦截

- **Given** `.specs/<id>/.independent-review-<N>.done` 不存在或校验失败
- **When** agent 执行 phase transition / commit / PR
- **Then** PreToolUse hook:
  1. 调用 `l3_dispatch_prompt()` 输出派发提示到 stderr（含子 agent 命令模板 + 参数说明）
  2. 输出拦截说明文本到 stderr（含 3 个选项：子 agent / Stop hook / 手动 bash）
  3. exit 2 拦截本次操作

### AC-4 · l3_dispatch_prompt() 派发格式与 L2 一致

- **Given** l3-review.sh 已加载
- **When** 调用 `l3_dispatch_prompt <phase> <change_id> <specs_dir> <gate_val>`
- **Then** 输出内容包含:
  - ╔══ 框线格式（与 `l2_dispatch_prompt()` 一致）
  - 子 agent 派发命令模板（含 `subagent_type` + `description` + `prompt`）
  - 手动 bash 命令备选（`source l3-review.sh && l3_review_run ...`）
  - 参数说明（phase / change_id / specs_dir / L2_verdict / gate_config）

### AC-5 · 现有 L3 功能不受影响

- **Given** `l3_review_run()` 函数签名和行为不变
- **When** Stop hook（29号）或手动调用 `l3_review_run`
- **Then** L3 API 调用、响应解析、`.done` 写入、`INDEPENDENT-REVIEW-<N>.md` 追加 L3 段——全部照常工作

### AC-6 · bash -n 语法检查通过

- **Given** 修改后的 `independent-review-gate.sh` 和 `l3-review.sh`
- **When** 运行 `bash -n` 检查
- **Then** 无语法错误

### AC-7 · 现有 bats 测试全绿 + 新增 async dispatch 测试

- **Given** 修改后的代码 + 新增测试
- **When** 运行 `npx bats test/`（全量）
- **Then** 0 failures；新增测试覆盖 AC-2/AC-3/AC-4 三个分支

---

## 范围切分

### v1（本次必做）

- 新增 `l3_dispatch_prompt()` 到 `l3-review.sh`
- 修改 `independent-review-gate.sh`：移除两处同步 L3 调用，替换为异步派发模式（AC-1~AC-3）
- 新增 bats 测试覆盖 async dispatch 三个分支
- `bash -n` 通过
- 全量 bats 回归 0 failures

### v2（下次再说）

- L3 派发重试/退避机制（当前一次派发失败需手动重试）
- L3 派发超时告警（当前 L3 API 调用无应用层超时通知）
- PreToolUse 后台 fire-and-forget L3 模式（当前必须显式派发）

### out（永远不做）

- L3 异步化改造不涉及 L2 派发逻辑
- 不改 `l3_review_run()` 的审查 prompt 构造逻辑
- 不改 Stop hook 的 L3 触发（已是 async fallback）

---

## 非功能性需求

- **兼容性**: `.done` 文件格式（6 键 KVP）不变；gate_config 解析逻辑不变
- **性能**: PreToolUse hook 延迟降低（不再阻塞 30s 等 API 响应）
- **安全**: 无新增安全面（L3 API 调用仍走 env-var-first 鉴权）
