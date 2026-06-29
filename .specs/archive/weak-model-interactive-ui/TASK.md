# TASK: 弱模型交互式 UI 触发强化

- **Change ID**: `weak-model-interactive-ui`
- **关联**: `@.specs/weak-model-interactive-ui/REQUIREMENT.md`、`@.specs/weak-model-interactive-ui/DESIGN.md`

---

## 波次划分

```
Wave 1 (parallel): T01[P], T03[P], T05[P]        ← 互不依赖，并行
Wave 2 (parallel): T02[P], T06[P]                  ← T02 depends on T01; T06 depends on T03
Wave 3 (parallel): T04[P], T07[P], T08[P]          ← T04 depends on T02; T07 depends on T02; T08 depends on T01+T02
Wave 4:            T09                              ← depends on all above（全量测试验证）
Wave 5:            T10, T11                         ← T10 package update; T11 docs（均 depends on T09）
```

> 同 wave = 可并行；跨 wave = 必须顺序执行。

---

## 任务清单

```xml
<task id="T01" parallel="true" status="pending">
  <name>创建交互 UI 检测逻辑库 interactive-ui-check.sh</name>
  <read_files>
    flow-kit-bundle/hooks/lib/*
    flow-kit/reference/pipeline-gates.md
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/lib/interactive-ui-check.sh
  </write_files>
  <action>
    新建 hook 共享库，提供以下函数：
    1. `check_interaction_gate(transcript_path)` — 读取 transcript，grep prompt 部分是否含 GATE_MAP 关键词
    2. `check_tool_invocation(transcript_path)` — grep 模型回复是否含 AskUserQuestion/EnterPlanMode 工具调用
    3. `write_correction_file(gate_type, context, tool)` — 写入矫正文件 .flow-active.interactive-ui-fix (JSON)
    4. `clear_correction_file()` — 清除矫正文件
    5. GATE_MAP 关联数组（9 个关键词映射，见 DESIGN § 2 交互 gate 清单）

    沿用以有 lib 目录命名风格（snake_case 函数名，set -euo pipefail）。
    脚本顶层 source 到其他 hook 模块时不应有副作用（仅定义函数，不执行）。
  </action>
  <verify>bash -n flow-kit-bundle/hooks/lib/interactive-ui-check.sh &amp;&amp; echo "SYNTAX OK"</verify>
  <done>库文件语法检查通过；source 后 GATE_MAP 关联数组可访问、4 个函数经 `declare -F` 确认存在</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true" status="pending">
  <name>创建 Stop hook 模块 27-interactive-ui-check.sh</name>
  <read_files>
    flow-kit-bundle/hooks/lib/interactive-ui-check.sh
    flow-kit-bundle/hooks/stop/26-workflow.sh
    flow-kit-bundle/hooks/stop/22-git.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/27-interactive-ui-check.sh
  </write_files>
  <action>
    新建 Stop hook 第 27 号模块，在每次会话停止时执行：

    1. source hooks/lib/interactive-ui-check.sh
    2. 检测 transcript 文件路径（从环境变量或默认路径推断）
    3. 调用 check_interaction_gate → check_tool_invocation
    4. 两者 AND → write_correction_file；否则跳过
    5. 连续跳过保护：读取 retry_count，≥2 时停止矫正改为输出人工介入提示
    6. 顶层用 subshell 包裹（( ... ) || true），确保异常不影响 hook 链后续模块

    复用 26-workflow.sh 的 transcript 路径推断逻辑（如有）。
    不做任何文件写操作除了矫正文件（.flow-active.interactive-ui-fix）。
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/27-interactive-ui-check.sh &amp;&amp; echo "SYNTAX OK"</verify>
  <done>Stop hook 模块语法正确；在模拟 transcript 上手动运行，跳过 gate → 输出矫正文件，正常 gate → 无输出</done>
  <depends_on>T01</depends_on>
</task>

<task id="T03" parallel="true" status="pending">
  <name>创建 prompt 护栏参考模板 interactive-ui-guard.md</name>
  <read_files>
    flow-kit/reference/pipeline-gates.md
    flow-kit/reference/ui-anti-patterns.md
  </read_files>
  <write_files>
    flow-kit/reference/interactive-ui-guard.md
  </write_files>
  <action>
    新建共享参考片段，供各 prompt 通过 @see 引用。内容：

    1. **AskUserQuestion guard 模板**（2 层）：
       - 自检句: "❌ 如果你还没调用 AskUserQuestion，现在停下来调用它。不要假设用户的选择。"
       - 工具骨架: "AskUserQuestion({ questions: [{ question: '...', header: '...', options: [...] }] })"
    2. **EnterPlanMode guard 模板**（2 层）：
       - 自检句: "⚠️ 本步骤要求先进入计划模式。调用 EnterPlanMode 工具，不要直接在聊天里出方案。"
       - 前置 gate: "在进入计划模式之前，禁止开始写代码或出具体方案。"
    3. **使用说明**：告诉各 prompt 如何引用（内联自检句 + @see 此文件）
    4. **与 hook 脚本的关系**：说明 prompt 护栏是第一道防线，hook 是兜底

    沿用 reference/ 目录既有风格（markdown，含代码块）。
  </action>
  <verify>test -s flow-kit/reference/interactive-ui-guard.md &amp;&amp; grep -q "AskUserQuestion" flow-kit/reference/interactive-ui-guard.md &amp;&amp; grep -q "EnterPlanMode" flow-kit/reference/interactive-ui-guard.md &amp;&amp; echo "OK"</verify>
  <done>参考文件存在且含两种 guard 模板 + 使用说明；符合 reference/ 目录既有格式</done>
  <depends_on></depends_on>
</task>

<task id="T04" parallel="true" status="pending">
  <name>SessionStart flow-kit-resume.sh 集成矫正注入</name>
  <read_files>
    flow-kit-bundle/hooks/session-start/flow-kit-resume.sh
    flow-kit-bundle/hooks/lib/interactive-ui-check.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/session-start/flow-kit-resume.sh
  </write_files>
  <action>
    扩展既有 flow-kit-resume.sh，在 resume banner 之前插入矫正检测：

    1. 检测 .flow-active.interactive-ui-fix 是否存在
    2. 存在 → 读取 JSON，解析 gate_type / prompt_context / required_tool / retry_count
    3. 注入矫正 banner（格式见 DESIGN § 2 核心流程图）：
       - retry_count 0: 标准矫正指令
       - retry_count 1: 加急矫正指令（更强硬措辞："你上轮已经跳过一次。这是第二次提醒。"）
       - retry_count ≥ 2: 停止矫正 + 🛑 人工介入提示
    4. 注入后清除矫正文件（或标记 injected 状态，等模型补调后再彻底清除）
    5. 不存在 → 跳过，正常 resume

    遵循既有 resume hook 的输出格式（ASCII box banner）。
    不破坏原有的 interrupt resume 逻辑（检测 interrupt 字段的逻辑保持不变）。
  </action>
  <verify>bash -n flow-kit-bundle/hooks/session-start/flow-kit-resume.sh &amp;&amp; echo "SYNTAX OK"</verify>
  <done>resume hook 语法正确；手动创建矫正文件后运行 hook → 输出含矫正 banner；无矫正文件时正常 resume</done>
  <depends_on>T02</depends_on>
</task>

<task id="T05" parallel="true" status="pending">
  <name>添加 stop-hook.json 交互 UI 检查模块开关</name>
  <read_files>
    flow-kit-bundle/hooks/stop-hook.json
    .claude/stop-hook.json
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop-hook.json
  </write_files>
  <action>
    在 stop-hook.json 的 modules 中添加新条目：
    ```json
    "interactive_ui_check": {
      "enabled": true,
      "description": "检测弱模型是否跳过了交互式 UI 工具调用（AskUserQuestion/EnterPlanMode），跳过时写入矫正文件"
    }
    ```

    注意：flow-kit-bundle/hooks/stop-hook.json 是唯一维护源（CONTEXT.md 已锁决策）。
    .claude/stop-hook.json 是 install.sh 安装的运行时副本，不在本次修改范围（install.sh 会在下次安装时自动同步）。
  </action>
  <verify>jq -e '.modules.interactive_ui_check.enabled == true' flow-kit-bundle/hooks/stop-hook.json &amp;&amp; echo "OK"</verify>
  <done>stop-hook.json modules 含 interactive_ui_check 条目，enabled=true</done>
  <depends_on></depends_on>
</task>

<task id="T06" parallel="true" status="pending">
  <name>全链路 prompt 加轻量交互 UI 护栏（11 个点位）</name>
  <read_files>
    flow-kit/reference/interactive-ui-guard.md
    flow-kit/GO.md
    flow-kit/prompts/0-change.md
    flow-kit/prompts/1-requirement.md
    flow-kit/prompts/2-design.md
    flow-kit/prompts/4-dev.md
    flow-kit/prompts/6-review.md
    flow-kit/prompts/7-integration.md
    flow-kit/prompts/A-architect.md
  </read_files>
  <write_files>
    flow-kit/GO.md
    flow-kit/prompts/0-change.md
    flow-kit/prompts/1-requirement.md
    flow-kit/prompts/2-design.md
    flow-kit/prompts/4-dev.md
    flow-kit/prompts/6-review.md
    flow-kit/prompts/7-integration.md
    flow-kit/prompts/A-architect.md
  </write_files>
  <action>
    在 DESIGN § 2 标定的 11 个交互 gate 点位，加轻量护栏（每点 ≤3 行）：

    1. **自检句**（1 行）："❌ 如果你还没调用 <ToolName>，现在停下来调用它。"
    2. **工具骨架**（1-2 行）："<ToolName>({ ... })" 参数骨架
    3. 不加重型 L3 证据链（由 hook 脚本承担）

    以 0-change.md L48 "反问 gate (R3.5)" 为例：
    ```
    <!-- weak-model-guard: AskUserQuestion -->
    ❌ 如果你还没调用 AskUserQuestion，现在停下来调用它。不要幻觉用户的选择。
    AskUserQuestion({ questions: [{ question: "...", header: "...", options: [...] }] })
    ```

    点位清单（精确行号以实际 grep 为准）：
    - GO.md L252, L272 (反问用户 → AskUserQuestion)
    - 0-change.md L48, L58 (反问 gate + 架构预检 → AskUserQuestion)
    - 1-requirement.md L33 (反问 gate R3.5 → AskUserQuestion)
    - 2-design.md L48, L69 (架构预检 + 等用户选定 → AskUserQuestion)
    - 4-dev.md L48, L441 (goal extraction + 1.8.3 反问 → AskUserQuestion)
    - 6-review.md L48 (Critical 确认 → AskUserQuestion)
    - 7-integration.md L274 (归档确认 → AskUserQuestion)
    - A-architect.md L64, L77 (反问用户 ×2 → AskUserQuestion)

    注意：每个 prompt 文件的具体行号可能因版本漂移，以实际内容中的 gate 关键词位置为准。
  </action>
  <verify>for f in GO.md prompts/0-change.md prompts/1-requirement.md prompts/2-design.md prompts/4-dev.md prompts/6-review.md prompts/7-integration.md prompts/A-architect.md; do echo "=== $f ===" &amp;&amp; grep -c "AskUserQuestion\|EnterPlanMode" "flow-kit/$f"; done</verify>
  <done>11 个点位均已加护栏（每个 prompt 文件至少 1 处新增 AskUserQuestion/EnterPlanMode 引用）</done>
  <depends_on>T03</depends_on>
</task>

<task id="T07" parallel="true" status="pending">
  <name>创建回归演示（模拟 transcript + check.sh）</name>
  <read_files>
    flow-kit-bundle/hooks/stop/27-interactive-ui-check.sh
    flow-kit-bundle/hooks/lib/interactive-ui-check.sh
    flow-kit-bundle/flow-kit/regression-demos/weak-model-robustness/
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/regression-demos/weak-model-interactive-ui/prompt_askuser.txt
    flow-kit-bundle/flow-kit/regression-demos/weak-model-interactive-ui/response_skipped.txt
    flow-kit-bundle/flow-kit/regression-demos/weak-model-interactive-ui/prompt_enterplan.txt
    flow-kit-bundle/flow-kit/regression-demos/weak-model-interactive-ui/response_skipped_plan.txt
    flow-kit-bundle/flow-kit/regression-demos/weak-model-interactive-ui/check.sh
  </write_files>
  <action>
    创建 2 个回归演示场景：

    **Demo 1 · AskUserQuestion 跳过**：
    - prompt_askuser.txt: 模拟含"反问 gate (R3.5)"的 0-change prompt 片段
    - response_skipped.txt: 模拟弱模型的典型跳过输出（纯文本假设用户选择了选项 1，但无工具调用）

    **Demo 2 · EnterPlanMode 跳过**：
    - prompt_enterplan.txt: 模拟含"进入计划模式"的 prompt 片段
    - response_skipped_plan.txt: 模拟弱模型直接出方案文本（无 EnterPlanMode 工具调用）

    **check.sh**（沿用 regression-demos 既有风格）：
    - 构造模拟 transcript（拼接 prompt + response）
    - 调用 27-interactive-ui-check.sh 检测
    - Demo 1: 验证 exit code 0 + 矫正文件存在 + gate_type="AskUserQuestion"
    - Demo 2: 验证 exit code 0 + 矫正文件存在 + gate_type="EnterPlanMode"
    - 正向测试: 含工具调用的正常 response → 验证 exit code 0 + 无矫正文件
    - 清理矫正文件
    - 输出 TAP 兼容格式
  </action>
  <verify>cd flow-kit-bundle/flow-kit/regression-demos/weak-model-interactive-ui &amp;&amp; bash check.sh &amp;&amp; echo "ALL DEMOS PASSED"</verify>
  <done>check.sh 全绿：2 个跳过场景均检测到 + 写入矫正文件；1 个正常场景无矫正文件</done>
  <depends_on>T02</depends_on>
</task>

<task id="T08" parallel="true" status="pending">
  <name>编写 bats 测试 test_interactive_ui_check.bats</name>
  <read_files>
    flow-kit-bundle/hooks/lib/interactive-ui-check.sh
    flow-kit-bundle/hooks/stop/27-interactive-ui-check.sh
    flow-kit-bundle/hooks/session-start/flow-kit-resume.sh
    test/test_common.bats
    test/test_install.bats
    .specs/CONTEXT.md
  </read_files>
  <write_files>
    test/test_interactive_ui_check.bats
  </write_files>
  <action>
    编写 bats 测试文件，覆盖以下场景（参考 test_common.bats 的测试风格）：

    1. **GATE_MAP 完整性测试**：所有 9 个关键词 → 对应工具映射存在
    2. **check_interaction_gate 函数测试**：
       - 输入含"反问用户"的 prompt → 返回 0（检测到 gate）
       - 输入不含 gate 关键词的 prompt → 返回 0 但标记无 gate
    3. **check_tool_invocation 函数测试**：
       - 输入含 AskUserQuestion 工具调用的 response → 返回 0
       - 输入纯文本 response（无工具调用）→ 返回 1
    4. **write_correction_file / clear_correction_file 测试**：
       - write → 文件存在且 JSON 字段完整
       - clear → 文件不存在
    5. **矫正文件 JSON schema 验证**：必填字段 gate_type, prompt_context, required_tool, timestamp
    6. **retry_count 逻辑测试**：retry_count 递增 + ≥2 时特殊处理
    7. **SessionStart 矫正注入测试**：模拟矫正文件存在 → resume hook 输出含矫正 banner

    使用 bats 的 `setup()` / `teardown()` 管理临时 transcript 和矫正文件。
    遵循既有 bats 测试命名约定（`@test "..."` 格式）。
  </action>
  <verify>npx bats test/test_interactive_ui_check.bats --tap</verify>
  <done>所有新增 bats 测试通过；覆盖 GATE_MAP / 检测 / 矫正写入清除 / retry_count / SessionStart 注入</done>
  <depends_on>T01</depends_on>
</task>

<task id="T09" parallel="false" status="pending">
  <name>全量测试验证 + 回归检查</name>
  <read_files>
    test/*
    .specs/weak-model-interactive-ui/REQUIREMENT.md
  </read_files>
  <write_files>
  </write_files>
  <action>
    运行全量测试套件验证无回归：

    1. `npx bats test/` — 全量 bats（原有 102 + 新增）
    2. `bash flow-kit-bundle/flow-kit/regression-demos/weak-model-interactive-ui/check.sh` — 回归演示
    3. `bash -n` 语法检查所有新增/修改的 .sh 文件
    4. 如有 test 失败：诊断 + 修复 + 重新运行直到全绿

    对应 AC-6（现有测试全量通过）+ AC-4（回归演示全绿）。
  </action>
  <verify>npx bats test/ &amp;&amp; bash flow-kit-bundle/flow-kit/regression-demos/weak-model-interactive-ui/check.sh</verify>
  <done>npx bats test/ 全绿（0 failures）；regression demo check.sh 全绿；所有 .sh 语法检查通过</done>
  <depends_on>T08</depends_on>
</task>

<task id="T10" parallel="false" status="pending">
  <name>更新 package-flow-kit.sh 打包配置</name>
  <read_files>
    package-flow-kit.sh
  </read_files>
  <write_files>
    package-flow-kit.sh
  </write_files>
  <action>
    在 package-flow-kit.sh 的 Part F（hooks 打包段）中新增加以下文件到打包清单：

    1. `hooks/lib/interactive-ui-check.sh` → lib/ 段
    2. `hooks/stop/27-interactive-ui-check.sh` → stop/ 段
    3. `hooks/stop-hook.json` → 已存在，确认 interactive_ui_check 模块条目在打包范围内
    4. `hooks/session-start/flow-kit-resume.sh` → 已存在，确认矫正注入逻辑在打包范围内

    在 Part B（flow-kit 核心段）中新增：
    5. `flow-kit/reference/interactive-ui-guard.md`
    6. `flow-kit/regression-demos/weak-model-interactive-ui/` 整个目录

    打包后运行 `package-flow-kit.sh --validate` 验证新增文件全覆盖（AC 来自 L-012 打包完整性校验）。
  </action>
  <verify>bash package-flow-kit.sh --validate 2&gt;&amp;1 | grep -E "interactive.ui|PASS|FAIL"</verify>
  <done>package-flow-kit.sh --validate 通过，新增 6 个路径均在打包清单中，无漏配</done>
  <depends_on>T09</depends_on>
</task>

<task id="T11" parallel="false" status="pending">
  <name>更新 CONTEXT.md + LESSONS.md 文档收尾</name>
  <read_files>
    .specs/CONTEXT.md
    .specs/LESSONS.md
    .specs/weak-model-interactive-ui/CHANGE.md
    .specs/weak-model-interactive-ui/DESIGN.md
  </read_files>
  <write_files>
    .specs/CONTEXT.md
    .specs/LESSONS.md
  </write_files>
  <action>
    1. **CONTEXT.md 已锁决策追加**：
       - 交互 UI 检测策略：hook 脚本为主 + prompt 护栏为辅（2026-06-29）
       - 矫正文件机制：.flow-active.interactive-ui-fix（不入库）
    2. **LESSONS.md 追加**（如 T09 测试过程中发现任何坑）：
       - 按既有 LESSONS.md 格式记录
    3. **CONTEXT.md 既有抽象索引更新**：
       - hooks/lib/interactive-ui-check.sh 加入工具函数表
    4. **CONTEXT.md 禁动清单更新**（来自 DESIGN § 9.5）

    参考既有 CONTEXT.md 和 LESSONS.md 的书写风格与编号约定。
  </action>
  <verify>grep -q "交互 UI 检测策略" .specs/CONTEXT.md &amp;&amp; grep -q "interactive-ui-check" .specs/CONTEXT.md &amp;&amp; echo "CONTEXT UPDATED"</verify>
  <done>CONTEXT.md 已锁决策 + 既有抽象 + 禁动清单均已更新；LESSONS.md 追加（如有新发现）</done>
  <depends_on>T09</depends_on>
</task>
```

---

## 状态字段说明

- `status="pending"` — 未开始
- `status="in_progress"` — 进行中（同时只允许一个非 [P] 任务为此状态）
- `status="done"` — 已完成（verify 通过）
- `status="blocked"` — 阻塞（必须在文件末尾「阻塞日志」记录）

---

## 阻塞日志

| 任务 | 阻塞原因 | 待人工决策项 | 时间 |
|---|---|---|---|
|  |  |  |  |

---

## Fix 任务（来自 REVIEW / INTEGRATION）

> 此区域由 review/integration 阶段自动追加，编号 `T-FIX-XX`。

```xml
<!-- 占位 -->
```
