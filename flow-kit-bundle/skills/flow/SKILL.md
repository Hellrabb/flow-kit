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
    "goal": {
      "condition": "pnpm test passes and lint is clean",
      "status": "active",
      "active_since": "2026-06-02T15:30:00+08:00",
      "turns": 3,
      "mode": "native",
      "scope": "phase",
      "current_phase": "4",
      "phases_done": [],
      "gates": {},
      "gate_config": {},
      "auto_advance": false,
      "phase_sub_goals": {}
    } | null,
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
   {"change_id": null, "goal": null, "phase": 0, "task_id": null, "interrupt": null, "token_spent": 0, "updated_at": "<当前ISO时间>"}
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

### `/flow goal`（无参数）
查看当前 goal 状态。动作：
1. 读取 `.flow-active` 的 `goal` 字段（`jq '.goal' .flow-active`）
2. 如 goal 为 null → 输出："当前无活跃 goal。用 `/flow goal <条件>` 设定。"
3. 如 goal 非空：
   - 若 `scope` 为 `"pipeline"` → 格式化输出 pipeline 进度：
     ```
     🎯 [pipeline] Goal: <condition>
        进度: 4 <✅/🔄/⏸> → 5 <✅/🔄/⏸> → 6 <✅/🔄/⏸> → 7 <✅/🔄/⏸>
        toll-gates: 4→5 <pending/passed/skipped> | 5→6 <pending/passed/skipped> | 6→7 <pending/passed/skipped>
        auto_advance: <true/false>
        状态: <status> | 已执行: <turns> turns | 模式: <mode>
        设定于: <active_since>
     ```
     进度图标规则：✅=已完成(在 phases_done 中) | 🔄=当前(current_phase) | ⏸=待开始
   - 否则（单阶段 goal）→ 保持原有格式：
     ```
     🎯 Goal: <condition>
        状态: <status> | 已执行: <turns> turns | 模式: <mode>
        设定于: <active_since>
     ```

### `/flow goal <条件文本> [--pipeline] [--gate-config <JSON>]`
设定 goal。动作：
1. 检查 `.flow-active` 是否存在，不存在 → 提示先 `/flow start`
2. 判断模式：
   - 有 `--pipeline` flag → pipeline 模式，写入完整 pipeline goal。
     若 4-dev 已自动提取 phase_sub_goals（见 4-dev.md 入场 Goal 检测步骤 2c），则传入：
     ```bash
     jq --arg cond "$condition" --arg ts "$(date -Iseconds)" \
       --arg sub4 "${SUB_GOAL_4:-}" --arg sub5 "${SUB_GOAL_5:-}" \
       --arg sub6 "${SUB_GOAL_6:-}" --arg sub7 "${SUB_GOAL_7:-}" \
       '.goal = {condition: $cond, status: "active", active_since: $ts, turns: 0, mode: "pending", scope: "pipeline", current_phase: "4", phases_done: [], gates: {"4→5": "pending", "5→6": "pending", "6→7": "pending"}, gate_config: {}, auto_advance: false, phase_sub_goals: {"4": $sub4, "5": $sub5, "6": $sub6, "7": $sub7}}' \
       .flow-active > .flow-active.tmp && mv .flow-active.tmp .flow-active
     ```
     未自动提取时（sub-goal 为空），phase_sub_goals 值为空字符串（各 prompt 检查非空才展示，空串等价于不展示）。
   - 有 `--pipeline` + `--gate-config '<JSON>'` → 同上 + gate_config：
     ```bash
     # 先验证 JSON 有效
     echo "$GATE_JSON" | jq empty || { echo "❌ gate-config JSON 无效"; exit 1; }
     # 再写入（合并 pipeline goal + gate_config + phase_sub_goals）
     jq --arg cond "$condition" --arg ts "$(date -Iseconds)" --argjson gates "$GATE_JSON" \
       --arg sub4 "${SUB_GOAL_4:-}" --arg sub5 "${SUB_GOAL_5:-}" \
       --arg sub6 "${SUB_GOAL_6:-}" --arg sub7 "${SUB_GOAL_7:-}" \
       '.goal = {condition: $cond, status: "active", active_since: $ts, turns: 0, mode: "pending", scope: "pipeline", current_phase: "4", phases_done: [], gates: {"4→5": "pending", "5→6": "pending", "6→7": "pending"}, gate_config: $gates, auto_advance: false, phase_sub_goals: {"4": $sub4, "5": $sub5, "6": $sub6, "7": $sub7}}' \
       .flow-active > .flow-active.tmp && mv .flow-active.tmp .flow-active
     ```
     注：jq key 含特殊字符（如 `6-review` 中的 `-`、gate key `4→5` 中的 `→`）时必须用 bracket 引用 `.["key"]`（见 LESSONS L-011）。
   - 无 `--pipeline` → 保持原有行为（单阶段 goal）：
     ```bash
     jq --arg cond "$condition" --arg ts "$(date -Iseconds)" \
       '.goal = {condition: $cond, status: "active", active_since: $ts, turns: 0, mode: "pending"}' \
       .flow-active > .flow-active.tmp && mv .flow-active.tmp .flow-active
     ```
3. 检测 CC 原生 `/goal` 可用性：
   - 尝试 `claude --version 2>/dev/null | head -1` 获取版本号；若 ≥ 2.1.139 → mode=native
   - pipeline 模式 + native：输出："✅ Pipeline Goal 已设定（原生模式）。CC /goal 将自主迭代直到条件满足。执行链：4→5→6→7"
   - pipeline 模式 + fallback：输出："✅ Pipeline Goal 已设定（回退模式）。4-dev 将使用内置迭代循环。执行链：4→5→6→7"
   - 单阶段模式：输出保持原有格式
4. 输出 goal 条件摘要（同 `/flow goal` 无参数格式）

### `/flow goal clear`
清除 goal。动作：
1. 用 jq 将 goal 置为 null：
   ```bash
   jq '.goal = null | .updated_at = "'$(date -Iseconds)'"' .flow-active > .flow-active.tmp && mv .flow-active.tmp .flow-active
   ```
2. 输出："✅ Goal 已清除"
3. 接受别名：`/flow goal stop` / `off` / `reset` / `none` / `cancel` 均等同 clear

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
1. 检查 `.flow-active` JSON 格式是否有效（`jq empty .flow-active`），包括 goal 字段结构（如非 null，需含 condition/status/active_since/turns/mode；pipeline 模式还需含 scope/current_phase/phases_done/gates/gate_config/auto_advance/phase_sub_goals）
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
