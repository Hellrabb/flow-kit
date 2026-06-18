# TASK: 整合 CC /goal 到 flow-kit

- **Change ID**: integrate-goal-command
- **关联**: `@.specs/integrate-goal-command/REQUIREMENT.md`、`@.specs/integrate-goal-command/DESIGN.md`

---

## 波次划分

```
Wave 1 (parallel): T01[P], T03[P]
Wave 2 (parallel): T02, T04[P], T05[P]   (T02 depends on T01; T04 & T05 无代码冲突可与 T02 并行)
Wave 3:            T06                    (depends on T02)
```

> 同 wave = 可并行；跨 wave = 必须顺序执行。

---

## 任务清单

```xml
<task id="T01" parallel="true" status="done">
  <name>.flow-active schema 扩展 — 新增 goal 字段定义</name>
  <read_files>
    ~/.claude/skills/flow/SKILL.md
  </read_files>
  <write_files>
    ~/.claude/skills/flow/SKILL.md
  </write_files>
  <action>
    在 flow SKILL.md 的 .flow-active JSON schema 定义中新增 goal 可选字段。
    字段结构（见 D1、D6）：
    {
      "condition": "<string>",        # goal 条件文本
      "status": "active" | "done",    # 当前状态
      "active_since": "<ISO时间>",    # 设定时刻
      "turns": 0,                      # 完成 turns 计数
      "mode": "native" | "fallback"   # 当前使用模式
    } | null

    更新 schema 示例 JSON 为含 goal 字段版本。
    同时更新 /flow start、/flow doctor 子命令中引用 .flow-active 的部分，确保 goal 字段在初始化时写入 null。
  </action>
  <verify>jq -n '{goal: {condition: "test", status: "active", active_since: "2026-01-01T00:00:00Z", turns: 0, mode: "fallback"}}' | jq '.goal.condition'</verify>
  <done>flow SKILL.md 的 .flow-active schema 包含 goal 可选字段结构；/flow start 初始化写入 goal: null</done>
  <depends_on></depends_on>
</task>

<task id="T02" status="done">
  <name>flow skill 新增 /flow goal 子命令</name>
  <read_files>
    ~/.claude/skills/flow/SKILL.md
  </read_files>
  <write_files>
    ~/.claude/skills/flow/SKILL.md
  </write_files>
  <action>
    在 flow SKILL.md 子命令表中新增 /flow goal 子命令（3 个变体），遵循既有子命令模式（jq 操作 .flow-active + 临时文件原子写入）。

    ### /flow goal &lt;condition&gt;
    1. 检查 .flow-active 是否存在
    2. 用 jq 写入 goal 字段（condition + status=active + active_since=当前ISO时间 + turns=0 + mode=auto）
    3. 检测 CC 原生 /goal 可用性：
       - 尝试 `claude --help 2>&1 | grep -q "/goal"` 或直接尝试调 `/goal`
       - 可用 → mode=native，输出："✅ Goal 已设定（原生模式）：&lt;condition&gt;"
       - 不可用 → mode=fallback，输出："✅ Goal 已设定（回退模式）：&lt;condition&gt;"
    4. 输出 goal 状态摘要

    ### /flow goal（无参数）
    1. 读取 .flow-active 的 goal 字段
    2. 如 goal 为 null → 输出："当前无活跃 goal"
    3. 如 goal 非空 → 输出：condition / status / active_since / turns / mode

    ### /flow goal clear
    1. 用 jq 将 goal 置为 null
    2. 如 CC 原生 /goal 可用 → 额外执行 /goal clear
    3. 输出："✅ Goal 已清除"

    参数接受：clear / stop / off / reset / none / cancel（对齐 CC 原生）
  </action>
  <verify>bash -c 'cd /tmp && echo "{\"change_id\":null,\"phase\":\"4\",\"task_id\":null,\"goal\":null,\"interrupt\":null,\"token_spent\":0,\"updated_at\":\"2026-01-01\"}" > .flow-active && jq ".goal.condition = \"test passes\" | .goal.status = \"active\" | .goal.active_since = \"2026-01-01T00:00:00Z\" | .goal.turns = 0 | .goal.mode = \"fallback\" | .updated_at = \"2026-01-01\"" .flow-active > .flow-active.tmp && mv .flow-active.tmp .flow-active && jq -e ".goal.condition == \"test passes\"" .flow-active'</verify>
  <done>/flow goal set/status/clear 三个变体均可执行，AC-1/AC-2/AC-3 可验证</done>
  <depends_on>T01</depends_on>
</task>

<task id="T03" parallel="true" status="done">
  <name>GO.md 路由声明新增 goal 展示</name>
  <read_files>
    ~/.claude/flow-kit/GO.md
  </read_files>
  <write_files>
    ~/.claude/flow-kit/GO.md
  </write_files>
  <action>
    在 GO.md 的「第五步 · 显式声明执行计划」路由声明模板中新增 goal 行。
    位置：在 "✅ Change-ID：&lt;id&gt;" 之后追加一行"✅ Goal：&lt;condition&gt; (active, N turns)"（仅当 .flow-active.goal 非空时显示）。
    同时在「第四步 · 自动准备」加载工件步骤中增加：进入任何阶段前读取 .flow-active.goal 字段并注入路由声明。

    另外在 GO.md 的「第二步 · 路由表」中新增强关键字匹配：
    - `/flow goal` / `设定目标` → 提示"使用 /flow goal &lt;条件&gt; 设定目标"
  </action>
  <verify>grep -q "Goal" ~/.claude/flow-kit/GO.md && grep -q "goal" ~/.claude/flow-kit/GO.md</verify>
  <done>GO.md 路由声明模板含 goal 行；AC-6 可验证</done>
  <depends_on></depends_on>
</task>

<task id="T04" parallel="true" status="done">
  <name>4-dev.md 入场新增 goal 自动提取与迭代</name>
  <read_files>
    ~/.claude/flow-kit/prompts/4-dev.md
    ~/.claude/flow-kit/templates/REQUIREMENT.md
  </read_files>
  <write_files>
    ~/.claude/flow-kit/prompts/4-dev.md
  </write_files>
  <action>
    在 4-dev.md 的「入场恢复」段之前新增「#### 入场 Goal 检测」段：

    1. 读取 .flow-active.goal
       - 如果 status=active → 直接进入 goal 迭代模式（见步骤 3）
       - 如果 null → 进入步骤 2

    2. Goal 自动提取（AC-5）：
       - 读取 REQUIREMENT.md
       - 解析所有 "### AC-N ·" 标题行
       - 取第一条 AC 的 Given/When/Then 文本拼接为 goal 条件建议
       - 展示："📋 建议 goal：&lt;条件&gt;  输入 /flow goal 确认或修改，或输入 'skip' 跳过"

    3. Goal 迭代模式：
       - 原生模式（mode=native）：提示"🚀 启动自主迭代（CC 原生 /goal），Ctrl+C 可中断"
       - 回退模式（mode=fallback）：提示"🚀 启动自主迭代（回退模式），每个 turn 后检查条件，Ctrl+C 可中断"
         + 内置回退循环说明：
           while goal.status == "active":
             1. 执行当前 task action
             2. turn 结束，用 prompt 自检："用工具验证条件是否满足：&lt;condition&gt;"
             3. 满足 → goal.status = "done"，停止
             4. 不满足 → turns++，继续
             5. turns ≥ 20 → 停止并警告

    引用 D2（双路径策略）、D3（内置回退）、D4（自动提取）、D5（建议不强制）。
  </action>
  <verify>grep -q "Goal\|goal" ~/.claude/flow-kit/prompts/4-dev.md</verify>
  <done>4-dev.md 入场含 goal 检测/提取/迭代三段逻辑；AC-4/AC-5 可验证</done>
  <depends_on></depends_on>
</task>

<task id="T05" parallel="true" status="done">
  <name>flow-kit-resume.sh 恢复时输出 goal</name>
  <read_files>
    ~/flow-kit-bundle/hooks/session-start/flow-kit-resume.sh
    ~/.claude/hooks/session-start/flow-kit-resume.sh
  </read_files>
  <write_files>
    ~/flow-kit-bundle/hooks/session-start/flow-kit-resume.sh
  </write_files>
  <action>
    在 flow-kit-resume.sh 的恢复横幅输出中新增 goal 检测。
    修改维护源 `~/flow-kit-bundle/hooks/session-start/flow-kit-resume.sh`：
    1. 读 .flow-active 的 goal 字段（jq）
    2. 如果 goal 非空且 status=active：
       追加输出："📍 恢复目标: &lt;condition&gt;（已执行 N turns，模式: &lt;mode&gt;）"
    3. 重置 turns 计数为 0（新 session 重新计数）

    注意：只改 flow-kit-bundle 维护源，不改 `~/.claude/hooks/` 安装副本（后者由 install.sh 同步）。
  </action>
  <verify>bash -c 'source ~/flow-kit-bundle/hooks/session-start/flow-kit-resume.sh 2>&1 | grep -q "goal\|Goal" || echo "OK - no goal output when no goal set"'</verify>
  <done>SessionStart 恢复横幅含 goal 信息；AC-7 可验证</done>
  <depends_on></depends_on>
</task>

<task id="T06" status="done">
  <name>bats 测试：/flow goal 子命令</name>
  <read_files>
    ~/.claude/skills/flow/SKILL.md
    test/test_common.bats
  </read_files>
  <write_files>
    test/test_flow_goal.bats
  </write_files>
  <action>
    新增 test/test_flow_goal.bats，测试 /flow goal 子命令的三个变体：
    1. test_goal_set：验证 goal 写入 .flow-active，字段完整（condition/status/active_since/turns/mode）
    2. test_goal_status：验证 /flow goal（无参数）输出含 condition + status
    3. test_goal_clear：验证 /flow goal clear 将 goal 置为 null
    4. test_goal_no_active_flow：验证无 .flow-active 时提示
    5. test_goal_clear_variants：验证 clear/stop/off/reset/none/cancel 等别名

    测试模式：创建临时 .flow-active 文件（jq -n），调用 flow goal 逻辑（内联 jq 命令），验证结果。
    沿用 bats-core 测试框架和 test_common.bats 的 setup/teardown 模式。
  </action>
  <verify>npx bats test/test_flow_goal.bats</verify>
  <done>5 条 bats 测试全部通过</done>
  <depends_on>T02</depends_on>
</task>
```

---

## 状态字段说明

- `status="done"` — 未开始
- `status="in_progress"` — 进行中
- `status="done"` — 已完成（verify 通过）

---

## 阻塞日志

| 任务 | 阻塞原因 | 待人工决策项 | 时间 |
|---|---|---|---|
|  |  |  |  |

---

## Fix 任务（来自 REVIEW / INTEGRATION）

```xml
<!-- 占位 -->
```
