---
name: flow
description: flow-kit 状态管理 — start/stop/phase/checkpoint/task/doctor。管理 .flow-active 状态文件和阶段切换。
---

# /flow — flow-kit 状态管理

管理 flow-kit 的 `.flow-active` 状态文件。不代替 `/flow-go` 的流程路由——只做状态文件的增删改。

## 实现细节

- `.flow-active` 放在项目根目录：dsh 用 `$FLOW_KIT_PROJECT_DIR`（插件注入），claude code 用 `$CLAUDE_PROJECT_DIR`，opencode 用 `$OPENCODE_PROJECT_DIR`/`$CLAUDE_PROJECT_DIR`；未设置时回退当前工作目录
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
      "start_phase": "4",
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
     先从 `start_phase`（缺失默认 "4"）确定阶段链，动态生成进度行：
     ```
     🎯 [pipeline] Goal: <condition>
        起始: <start_phase> | 进度: <start> <✅/🔄/⏸> → <start+1> <✅/🔄/⏸> → ... → 7 <✅/🔄/⏸>
        toll-gates: <start>→<start+1> <pending/passed/skipped> | ... | 6→7 <pending/passed/skipped>
        auto_advance: <true/false>
        状态: <status> | 已执行: <turns> turns | 模式: <mode>
        设定于: <active_since>
     ```
     进度图标规则：✅=已完成(在 phases_done 中) | 🔄=当前(current_phase) | ⏸=待开始
     阶段链由 `start_phase` 派生（0→1→...→7），`start_phase` 缺失时默认 "4"（向后兼容）。
   - 否则（单阶段 goal）→ 保持原有格式：
     ```
     🎯 Goal: <condition>
        状态: <status> | 已执行: <turns> turns | 模式: <mode>
        设定于: <active_since>
     ```

### `/flow goal <条件文本> [--pipeline] [--from <n>] [--gate-config <JSON>]`
设定 goal。动作：
1. 检查 `.flow-active` 是否存在，不存在 → 提示先 `/flow start`
2. 解析 `--from <n>` flag（从 args 中提取 `--from\s+([0-7])`）：
   - 匹配到 → 校验值 ∈ {0,1,2,3,4,5,6,7}，无效则输出 `❌ 无效起始阶段: <值>。有效值: 0, 1, 2, 3, 4, 5, 6, 7` 并 exit 1
   - 未匹配 → 默认 `FROM=4`
3. 判断模式：
   - 有 `--pipeline` flag → pipeline 模式，动态生成 gates：
     ```bash
     # 动态生成 gates JSON（根据 FROM 生成 "N→N+1" keys）
     GATES_JSON=$(jq -n --arg from "$FROM" \
       '[range($from|tonumber; 7) | "\(.)→\(.+1)"] | reduce .[] as $k ({}; .[$k] = "pending")')
     # 写入 pipeline goal
     jq --arg cond "$condition" --arg ts "$(date -Iseconds)" --arg from "$FROM" \
       --argjson gates "$GATES_JSON" \
       --arg sub4 "${SUB_GOAL_4:-}" --arg sub5 "${SUB_GOAL_5:-}" \
       --arg sub6 "${SUB_GOAL_6:-}" --arg sub7 "${SUB_GOAL_7:-}" \
       '.goal = {condition: $cond, status: "active", active_since: $ts, turns: 0, mode: "pending", scope: "pipeline", start_phase: $from, current_phase: $from, phases_done: [], gates: $gates, gate_config: {}, auto_advance: false, phase_sub_goals: {"4": $sub4, "5": $sub5, "6": $sub6, "7": $sub7}}' \
       .flow-active > .flow-active.tmp && mv .flow-active.tmp .flow-active
     # 写 gate_config 快照（D8 ⑥检测 · G3 · .goal-snapshot.json 入 .specs/<id>/ 受 git 跟踪）
     change_id=$(jq -r '.change_id' .flow-active) && mkdir -p ".specs/${change_id}" \
       && jq '{gate_config: .goal.gate_config, created_at: now}' .flow-active \
          > ".specs/${change_id}/.goal-snapshot.json"
     ```
     注：phase_sub_goals 仍按 4/5/6/7 存储（与 pipeline 执行链后半段对应的 sub-goal）。若 FROM > 4（如 FROM=5），则 sub4 为空串不展示。
   - 有 `--pipeline` + `--gate-config '<VALUE>'` → 同上 + gate_config。解析策略（三段式 auto-detect）：

     **第一段：解析 gate_config 值**（`resolve_gate_config()`）：
     ```bash
     # 预设名映射表（PRESET_MAP）— 值统一为 "both"（L2+L3 双层，等价于旧 "independent"）
     # full               → {"1-requirement":"both","2-design":"both","6-review":"both"}
     # all                → {"1-requirement":"both","2-design":"both","3-task":"both","5-test":"both","6-review":"both","7-integration":"both"}  ⚠️ 预计增加 30k-75k tokens/pipeline run
     # code-only          → {"6-review":"both"}
     # review             → {"6-review":"both"}   (code-only 别名)
     # design             → {"2-design":"both"}
     # requirement        → {"1-requirement":"both"}
     # plan               → {"1-requirement":"both","2-design":"both"}
     # design-review      → {"2-design":"both","6-review":"both"}
     # requirement-review → {"1-requirement":"both","6-review":"both"}
     # task               → {"3-task":"both"}
     # test               → {"5-test":"both"}
     # integration        → {"7-integration":"both"}
     # task-review        → {"3-task":"both","6-review":"both"}
     # test-review        → {"5-test":"both","6-review":"both"}
     # task-test          → {"3-task":"both","5-test":"both"}
     # task-test-review   → {"3-task":"both","5-test":"both","6-review":"both"}
     # spec-test          → {"1-requirement":"both","2-design":"both","5-test":"both"}
     #
     # 数字映射：1→"1-requirement"  2→"2-design"  3→"3-task"  5→"5-test"  6→"6-review"  7→"7-integration"
     #
     # ── L2/L3 独立开关（l2-l3-granular-gate）──
     # gate_config 值规范: "both"(L2+L3) | "L2"(仅子agent) | "L3"(仅外部模型)
     # "independent" / "true" → 自动映射为 "both"（向后兼容）
     # 额外 flag（可选，解析 VALUE 后整体覆盖所有 phase 的值）：
     #   --l2-only → gate_config 所有 key 的 value 覆写为 "L2"
     #   --l3-only → gate_config 所有 key 的 value 覆写为 "L3"
     #   同时传入 → 后者覆盖 + 输出 warning

     # 三段式 auto-detect：
     # a. echo "$VALUE" | jq -e 'type == "object"' 成功 → 合法 JSON 对象 → 直接使用（向后兼容）
     #    （注意：必须是 object 类型——"6"/"1" 等裸数字也是合法 JSON，会被误拦截，需 type check）
     # b. VALUE 匹配预设名 → 查 PRESET_MAP 映射为 JSON
     # c. VALUE 匹配 /^[0-9](,[0-9])*$/ → 拆分逗号，逐数字映射，合成 JSON（如 "1,2"→{"1-requirement":"both","2-design":"both"}）
     # d. 以上都不匹配 → ❌ 报错并列出可用预设名
     #
     # 额外 flag 覆写（在 GATE_JSON 解析完成后执行）：
     #   --l2-only → jq 'with_entries(.value = "L2")'  # 仅顶层 key → "L2"，不触碰嵌套值
     #   --l3-only → jq 'with_entries(.value = "L3")'  # 仅顶层 key → "L3"，不触碰嵌套值
     ```

     **第二段：写入 goal**（与原逻辑一致，`$GATE_JSON` 替换为解析结果）：
     ```bash
     GATES_JSON=$(jq -n --arg from "$FROM" \
       '[range($from|tonumber; 7) | "\(.)→\(.+1)"] | reduce .[] as $k ({}; .[$k] = "pending")')
     jq --arg cond "$condition" --arg ts "$(date -Iseconds)" --arg from "$FROM" \
       --argjson gates "$GATES_JSON" --argjson custom_gates "$GATE_JSON" \
       --arg sub4 "${SUB_GOAL_4:-}" --arg sub5 "${SUB_GOAL_5:-}" \
       --arg sub6 "${SUB_GOAL_6:-}" --arg sub7 "${SUB_GOAL_7:-}" \
       '.goal = {condition: $cond, status: "active", active_since: $ts, turns: 0, mode: "pending", scope: "pipeline", start_phase: $from, current_phase: $from, phases_done: [], gates: $gates, gate_config: $custom_gates, auto_advance: false, phase_sub_goals: {"4": $sub4, "5": $sub5, "6": $sub6, "7": $sub7}}' \
       .flow-active > .flow-active.tmp && mv .flow-active.tmp .flow-active
     # 写 gate_config 快照（D8 ⑥检测 · G3 · 入 .specs/<id>/ 受 git 跟踪）
     change_id=$(jq -r '.change_id' .flow-active) && mkdir -p ".specs/${change_id}" \
       && jq '{gate_config: .goal.gate_config, created_at: now}' .flow-active \
          > ".specs/${change_id}/.goal-snapshot.json"
     ```
     注：jq key 含特殊字符（如 `6-review` 中的 `-`、gate key `4→5` 中的 `→`）时必须用 bracket 引用 `.["key"]`（见 LESSONS L-011）。
   - 无 `--pipeline` → 保持原有行为（单阶段 goal）：
     ```bash
     jq --arg cond "$condition" --arg ts "$(date -Iseconds)" \
       '.goal = {condition: $cond, status: "active", active_since: $ts, turns: 0, mode: "pending"}' \
       .flow-active > .flow-active.tmp && mv .flow-active.tmp .flow-active
     ```
4. 检测 CC 原生 `/goal` 可用性：
   - 尝试 `claude --version 2>/dev/null | head -1` 获取版本号；若 ≥ 2.1.139 → mode=native
   - pipeline 模式 + native：输出执行链（动态：`FROM→...→7`）：
     `✅ Pipeline Goal 已设定（原生模式）。执行链：<FROM>→...→7`
   - pipeline 模式 + fallback：同上但标注回退模式
   - 单阶段模式：输出保持原有格式
5. 输出 goal 条件摘要（同 `/flow goal` 无参数格式）

### `/flow goal clear`
清除 goal。动作：
1. 用 jq 将 goal 置为 null：
   ```bash
   jq '.goal = null | .updated_at = "'$(date -Iseconds)'"' .flow-active > .flow-active.tmp && mv .flow-active.tmp .flow-active
   ```
2. 输出："✅ Goal 已清除"
3. 接受别名：`/flow goal stop` / `off` / `reset` / `none` / `cancel` 均等同 clear

### `/flow gate-config <phase>=<value>`
单独 patch 某阶段的独立 review gate（无需重建 goal）。动作：
1. 检查 `.flow-active` 是否存在 + `.goal` 非 null（gate_config 是 goal 子字段；无 goal → 提示先 `/flow goal`）
2. 解析参数：
   - `<phase>`：阶段名字符串，合法值 `1-requirement` / `2-design` / `3-task` / `5-test` / `6-review` / `7-integration`。提示：开启前确认对应阶段 prompt 已含独立审查段（3/5/7 由 independent-review-gap change 补齐）
   - `<value>`：`independent`（或 `true`）= 开启该阶段独立 review；`off`（或 `false`）= 关闭
   - 无参数 → 输出当前 `goal.gate_config`（jq 格式化）即可，不要改文件
3. 用 jq patch 单个 key（bracket 引用，见 LESSONS L-011）：
   ```bash
   # 开启：/flow gate-config 6-review=independent
   jq --arg pn "6-review" --arg val "independent" --arg ts "$(date -Iseconds)" \
     '.goal.gate_config[$pn] = $val | .updated_at = $ts' \
     .flow-active > .flow-active.tmp && mv .flow-active.tmp .flow-active
   # 关闭：/flow gate-config 6-review=off → 同上但 val="off"
   ```
4. 输出：`✅ gate_config[<phase>] = <value>。` + 当前完整 gate_config 摘要
5. 副作用提示：开启某阶段后，进入/处于该阶段时，Stop hook `29-independent-review.sh` 会跑 L3，PreToolUse hook `independent-review-gate.sh` 会拦 commit / PR / 切阶段直到主 agent 写 `.specs/<id>/.independent-review-<phase>.done`（机制见 `@flow-kit/prompts/independent/L2-blind-review.md` 与各阶段 prompt 的「独立 review 调度」段）

### `/flow model`
配置 L2/L3 审查模型（跨平台兼容，l2-l3-model-config ADR-012）。读 / 写 `.flow-active.goal.l2_model` / `l3_model`（可选字段）。动作：
1. 检查 `.flow-active` 存在 + `.goal` 非 null
2. 解析参数：
   - 无参数 → 显示当前 L2/L3 模型配置（jq 格式化 `.goal.l2_model` / `.goal.l3_model`，并提示优先级链）
   - `l2=<model>` → 设置 L2 模型
   - `l3=<model>` → 设置 L3 模型
   - `l2=<m> l3=<m>` → 同时设置
   - `--clear l2` / `--clear l3` → 清除（回到 env var / 降级）
3. 原子写（jq `--arg` 防注入 + 临时文件 mv，bracket 引用见 LESSONS L-011）：
   ```bash
   # 设置：/flow model l3=deepseek-v4-flash
   jq --arg m "deepseek-v4-flash" --arg ts "$(date -Iseconds)" \
     '.goal.l3_model = $m | .updated_at = $ts' \
     .flow-active > .flow-active.tmp && mv .flow-active.tmp .flow-active
   # 清除：/flow model --clear l3 → .goal.l3_model = null
   # 合并：/flow model l2=<m> l3=<m> → 同一次 jq 设两个字段
   ```
4. 输出：`✅ model[l3] = <value>。` + 当前 L2/L3 配置摘要
5. **优先级链提示**：解析顺序 `ANTHROPIC_*` env var > `FLOW_KIT_*` env var > `.flow-active.goal.l*_model` > 降级。env var 优先；此处设置的是持久化兜底。
6. **字段边界**：仅写 `.goal.l2_model` / `.goal.l3_model`，**不触碰** `.goal.condition` / `gates` / `gate_config` 等 `/flow goal` 字段（平行配置维度，DESIGN §5）。

### 自动 checkpoint（PreToolUse hook）

**无需手动操作**。每当 AI 调用 Write 或 Edit 工具前，`auto-checkpoint.sh` PreToolUse hook 自动更新 `.flow-active` 的 `interrupt` 字段：

- **触发条件**：`.flow-active` 存在且 `change_id` 非 null（有活跃 change）
- **触发工具**：Write / Edit（Read / Bash 等不触发）
- **写入字段**：
  - `active_file` — 正在编辑的文件路径
  - `last_action` — 动作描述（"编辑 `<filepath>`"）
  - `failing_check` — 空字符串（PreToolUse 路径不适用）
  - `checkpoint_at` — ISO8601 时间戳
- **恢复方式**：
  - 会话中断后，下一轮 SessionStart 的 `flow-kit-resume.sh` 检测到 `interrupt` 非空，在 banner 中展示"上次编辑: `<active_file>`"
  - `/flow`（无参数）查看当前状态时也会展示 `interrupt` 信息
- **与手动 checkpoint 的关系**：互补不冲突。自动 hook 覆盖每次 Write/Edit；手动 `/flow checkpoint` 用于额外标注（测试失败、阶段切换等）。最后写入者覆盖。
- **安装**：claude/opencode 由 `install.sh` 注册到 `.claude/settings.json` 的 `PreToolUse` 数组（matcher: `"Write|Edit"`）；dsh 由 `dsh-flow-kit` 插件 `hook-bridge.js` 监听 `tools/pre-execute` 自动触发，无需 settings.json

### `/flow checkpoint <file> <description>`
手动保存中断恢复上下文。AI 应在关键操作后调用（如遇到测试失败、切换任务时）。自动 hook 已覆盖 Write/Edit，本命令用于额外标注。
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
1. 检查 `.flow-active` JSON 格式是否有效（`jq empty .flow-active`），包括 goal 字段结构（如非 null，需含 condition/status/active_since/turns/mode；pipeline 模式还需含 scope/start_phase/current_phase/phases_done/gates/gate_config/auto_advance/phase_sub_goals；start_phase 缺失时默认 "4" 兼容旧数据）
2. 检查 Stop Hook 配置（按运行时选择配置路径）：
   - dsh：读 `.flow-kit/stop-hook.json`；claude/opencode：读 `.claude/stop-hook.json`；检查 `modules.workflow.enabled` 是否为 `true`
   - 检查 `26-workflow.sh` 是否存在且可执行
3. 检查 SessionStart 是否包含 flow-kit resume hook：
   - dsh：确认 profile 已挂载 `dsh-flow-kit` 插件（`dsh --profile <name> --dump-config | grep flow-kit`）
   - claude/opencode：grep `.claude/settings.json` 中是否有 `flow-kit-resume.sh`
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
