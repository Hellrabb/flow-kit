---
name: flow
description: flow-kit 状态管理 — start/stop/phase/checkpoint/task/doctor。管理 .flow-active 状态文件和阶段切换。
---

# /flow — flow-kit 状态管理

管理 flow-kit 的 `.flow-active` 状态文件。不代替 `/flow-go` 的流程路由——只做状态文件的增删改。

## 实现细节

- `.flow-active` 放在项目根目录（`$CLAUDE_PROJECT_DIR`）
- JSON 格式：
  ```json
  {
    "change_id": "xxx" | null,
    "phase": "0",
    "task_id": "T1" | null,
    "interrupt": {
      "active_file": "src/foo.ts",
      "last_action": "修复类型错误",
      "failing_check": "pnpm test foo.test.ts",
      "checkpoint_at": "2026-06-02T15:30:00+08:00"
    } | null,
    "token_spent": 0,
    "updated_at": "2026-06-02T15:30:00+08:00"
  }
  ```
- 操作 `.flow-active` 使用 `jq`（与 stop hook 保持一致），写入用临时文件 + mv 保证原子性
- 完成后简洁输出状态，不要啰嗦

## 子命令

### `/flow start`
初始化 flow-kit 状态。动作：
1. 检查项目根目录 `.flow-active` 是否存在
2. 如已存在：输出当前 change_id + phase，提示"已有活跃 change，如需新建请先 `/flow stop`"
3. 如不存在：创建 `.flow-active`，内容：
   ```json
   {"change_id": null, "phase": 0, "task_id": null, "interrupt": null, "token_spent": 0, "updated_at": "<当前ISO时间>"}
   ```
   用 `jq -n` 生成后写入
4. 输出：`flow-kit 已激活 (phase 0)。现在告诉我你想做什么，我来自动路由。`

### `/flow stop`
停止 flow-kit。动作：
1. 检查 `.flow-active` 是否存在
2. 不存在 → 输出："当前没有活跃的 flow。"
3. 存在 → 删除 `.flow-active`，输出 change_id 后提示已停止

### `/flow phase <n>`
手动切换阶段。动作：
1. 检查 `.flow-active` 是否存在，不存在 → 提示先 `/flow start`
2. 验证 n 为有效值：`0, 1, 2, 2a, 3, 4, 5, 6, 7`
3. 用 jq 更新 `.flow-active` 的 `phase` 和 `updated_at` 字段：
   ```bash
   jq ".phase = \"$n\" | .updated_at = \"$(date -Iseconds)\"" .flow-active > .flow-active.tmp && mv .flow-active.tmp .flow-active
   ```
4. 输出切换前后的阶段

### `/flow task <T<N>>`
切换当前 task。动作：
1. 检查 `.flow-active` 是否存在，不存在 → 提示先 `/flow start`
2. 用 jq 更新 `task_id` 和 `updated_at`：
   ```bash
   jq ".task_id = \"$tid\" | .updated_at = \"$(date -Iseconds)\"" .flow-active > .flow-active.tmp && mv .flow-active.tmp .flow-active
   ```
3. 输出：`task → T<N>`

### `/flow checkpoint <file> <description>`
保存中断恢复上下文。AI 应在每次关键操作后调用（如开始编辑文件、遇到测试失败）。
1. 检查 `.flow-active` 是否存在，不存在 → 提示先 `/flow start`
2. 用 jq 更新 `interrupt` 字段和 `updated_at`：
   ```bash
   jq --arg file "$file" --arg desc "$desc" --arg ts "$(date -Iseconds)" \
     '.interrupt = {active_file: $file, last_action: $desc, checkpoint_at: $ts} | .updated_at = $ts' \
     .flow-active > .flow-active.tmp && mv .flow-active.tmp .flow-active
   ```
3. 输出：`📍 checkpoint: <file> — <description>`

### `/flow`（无参数）
查看当前状态：
1. 读取 `.flow-active`，用 jq 格式化展示 change_id、phase、task_id、interrupt（如有）、token_spent
2. 不存在 → 输出："当前没有活跃的 flow。用 `/flow start` 开始。"

### `/flow doctor`
诊断 flow-kit hook 配置状态。动作：
1. 检查 `.flow-active` JSON 格式是否有效（`jq empty .flow-active`）
2. 检查 Stop Hook 配置：
   - 读 `.claude/stop-hook.json`，检查 `modules.workflow.enabled` 是否为 `true`
   - 检查 `26-workflow.sh` 是否存在且可执行
3. 检查 SessionStart 是否包含 flow-kit resume hook：
   - grep `.claude/settings.json` 中是否有 `flow-kit-resume.sh`
4. 检查 `.specs/STATE.md` 是否存在且字段完整
5. 如果有活跃 change_id，检查 `.specs/<id>/` 产物完整性（与 phase 对照）
6. 输出诊断报告，格式：
   ```
   🩺 flow-kit 诊断报告
   ✅ .flow-active: 有效 (phase 1, change=delivery-defer-backoff)
   ✅ Stop Hook G1: 已启用
   ❌ SessionStart flow-kit-resume: 未配置 → 运行 `echo ... >> settings.json`
   ✅ STATE.md: 存在 (last_intel_scan: 2026-06-01)
   ⚠️ Phase 1 产物: REQUIREMENT.md 存在但 DESIGN.md 缺失
   ```
