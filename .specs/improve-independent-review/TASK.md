# TASK: 独立 review 模型配置化 + gate-config 预设

- **Change ID**: improve-independent-review
- **关联**: `@.specs/improve-independent-review/REQUIREMENT.md`、`@.specs/improve-independent-review/DESIGN.md`
- **技术栈**: Bash 4+ / jq 1.6+ / bats-core 1.13.0

---

## 波次划分

```
Wave 1 (parallel): T01[P], T02[P], T03[P]     ← 三个独立文件，互不冲突
Wave 2:            T04 (depends on T01, T02, T03)  ← 验证所有改动
Wave 3:            T05 (depends on T04)            ← 集成冒烟
```

---

## 任务列表

```xml
<task id="T01" parallel="true">
  <name>29-independent-review.sh：env-var-first 模型 + API 直连</name>
  <read_files>
    ~/.claude/hooks/stop/29-independent-review.sh
    ~/.claude/hooks/stop/lib/common.sh
    ~/.claude/hooks/stop/lib/flow-kit-artifacts.sh
    ~/.claude/stop-hook.json
  </read_files>
  <write_files>
    ~/.claude/hooks/stop/29-independent-review.sh
  </write_files>
  <action>
    1. 模型名读取改为 env-var-first 三级 fallback：
       model="${ANTHROPIC_DEFAULT_HAIKU_MODEL:-$(config_get '.independent_review.model' 'deepseek-v4-flash')}"
       日志输出实际使用的模型名和来源（env var 或 config）
    2. API 调用路径改为直连优先：
       检测 ANTHROPIC_BASE_URL + ANTHROPIC_AUTH_TOKEN 均已设置 → 直连 curl
       onecli 存在时作为备选 fallback（有则用，无则跳过不报错）
       构造 curl 命令时使用 "$ANTHROPIC_BASE_URL/v1/messages"
       Header: "Authorization: Bearer $ANTHROPIC_AUTH_TOKEN"
    3. 确保 curl 错误信息不泄露 AUTH_TOKEN（错误信息中过滤或只输出 HTTP status）
    4. 保留所有现有 Gate 1-5 守卫逻辑不变
    5. 不引入 set -x，不将 AUTH_TOKEN 传入 echo/module_output
    6. 保持幂等（本阶段 L3 已成功则跳过）和失败降级（fail_count + max_failures）逻辑不变
  </action>
  <verify>cd ~/unisoc/flow-kit && npx bats test/test_independent_review_model.bats --filter "T01"</verify>
  <done>29号脚本中 grep ANTHROPIC_DEFAULT_HAIKU_MODEL 和 ANTHROPIC_BASE_URL 均返回 ≥1；AC-1, AC-3, AC-4, AC-9 通过 bats 测试</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true">
  <name>30-ai-analyze.sh：同步 env-var-first 模型 + API 直连</name>
  <read_files>
    ~/.claude/hooks/stop/30-ai-analyze.sh
    ~/.claude/hooks/stop/lib/common.sh
    ~/.claude/stop-hook.json
  </read_files>
  <write_files>
    ~/.claude/hooks/stop/30-ai-analyze.sh
  </write_files>
  <action>
    与 T01 同等策略（env-var-first + 直连优先 + token 安全），应用到 30 号脚本：
    1. 模型名：${ANTHROPIC_DEFAULT_HAIKU_MODEL:-$(config_get '.ai.model' 'deepseek-v4-flash')}
    2. API 路径：直连 $ANTHROPIC_BASE_URL 优先，onecli fallback
    3. 保持现有频率门控（frequency）逻辑不变
    4. 不引入 set -x，AUTH_TOKEN 不泄露到日志
  </action>
  <verify>cd ~/unisoc/flow-kit && npx bats test/test_independent_review_model.bats --filter "T02"</verify>
  <done>30号脚本中 grep ANTHROPIC_DEFAULT_HAIKU_MODEL 和 ANTHROPIC_BASE_URL 均返回 ≥1；AC-2, AC-9 通过 bats 测试</done>
  <depends_on></depends_on>
</task>

<task id="T03" parallel="true">
  <name>/flow skill：gate-config 预设名 + 数字简写解析</name>
  <read_files>
    ~/.claude/skills/flow/skill.md
  </read_files>
  <write_files>
    ~/.claude/skills/flow/skill.md
  </write_files>
  <action>
    在 /flow skill 的 "gate-config" 子命令段新增 resolve_gate_config() 解析逻辑：

    1. 定义 PRESET_MAP（8 种预设名 → 对应的 gate_config JSON）：
       - full           → {"1-requirement":"independent","2-design":"independent","6-review":"independent"}
       - code-only      → {"6-review":"independent"}
       - review         → {"6-review":"independent"}  （code-only 别名）
       - design         → {"2-design":"independent"}
       - requirement    → {"1-requirement":"independent"}
       - plan           → {"1-requirement":"independent","2-design":"independent"}
       - design-review  → {"2-design":"independent","6-review":"independent"}
       - requirement-review → {"1-requirement":"independent","6-review":"independent"}

    2. 定义数字映射：1→"1-requirement", 2→"2-design", 6→"6-review"

    3. 解析优先级（三段式 auto-detect）：
       a. echo "$value" | jq empty 成功 → 合法 JSON → 直接使用（向后兼容）
       b. value 在 PRESET_MAP keys 中 → 查表映射为 JSON
       c. value 匹配 /^[0-9](,[0-9])*$/ → 拆分逗号，逐数字映射，合成 JSON
       d. 以上都不匹配 → ❌ 报错：无效 gate-config，列出可用预设名

    4. 修改 /flow goal 的 --gate-config 解析段：
       将 echo "$GATE_JSON" | jq empty 验证替换为 resolve_gate_config() 调用
       保持 --pipeline + --from 组合逻辑不变
       保持单阶段 goal（无 --pipeline）行为不变

    5. /flow help 输出中追加 gate-config 预设名速查表
  </action>
  <verify>cd ~/unisoc/flow-kit && npx bats test/test_gate_config_presets.bats</verify>
  <done>8 种预设名 + 数字简写 + 完整 JSON 三种格式均能正确写入 .flow-active.goal.gate_config；AC-6, AC-7, AC-8 通过 bats 测试</done>
  <depends_on></depends_on>
</task>

<task id="T04">
  <name>bats 测试：env-var-first + gate-config 解析全覆盖</name>
  <read_files>
    ~/.claude/hooks/stop/29-independent-review.sh
    ~/.claude/hooks/stop/30-ai-analyze.sh
    ~/.claude/skills/flow/skill.md
    ~/.claude/stop-hook.json
    test/
  </read_files>
  <write_files>
    test/test_independent_review_model.bats
    test/test_gate_config_presets.bats
  </write_files>
  <action>
    编写两个 bats 测试文件：

    test/test_independent_review_model.bats（覆盖 AC-1~5, AC-9）：
    - T01-1: env var 已设 → model 取 env var 值
    - T01-2: env var 未设 → model 取 config 值
    - T01-3: env var 和 config 都未设 → model 取硬编码 "deepseek-v4-flash"
    - T01-4: ANTHROPIC_BASE_URL + AUTH_TOKEN 已设 → curl 命令含正确 Header
    - T01-5: ANTHROPIC_BASE_URL 未设 → 回退到 onecli（如有）或默认 API endpoint
    - T02-1: 30号脚本同样 env-var-first（与 T01-1 对称）
    - T09-1: AUTH_TOKEN 不出现在 echo/module_output 行中

    test/test_gate_config_presets.bats（覆盖 AC-6~8）：
    - T03-1: --gate-config full → 三个 key 均为 "independent"
    - T03-2: --gate-config code-only → 仅 6-review
    - T03-3: --gate-config 6 → 数字简写 → 仅 6-review
    - T03-4: --gate-config 1,2 → 数字简写 → 1-requirement + 2-design
    - T03-5: --gate-config '{"1-requirement":"independent"}' → 完整 JSON 直通
    - T03-6: --gate-config invalid_value → 报错不写入
    - T03-7: 8 种预设全部验证映射正确性（用 for 循环遍历 PRESET_MAP）
  </action>
  <verify>cd ~/unisoc/flow-kit && npx bats test/test_independent_review_model.bats test/test_gate_config_presets.bats</verify>
  <done>所有 bats 测试通过（零 fail）；覆盖 AC-1 到 AC-9 全部 AC</done>
  <depends_on>T01, T02, T03</depends_on>
</task>

<task id="T05">
  <name>集成冒烟：stop hook 链 + /flow goal 端到端</name>
  <read_files>
    ~/.claude/hooks/stop/29-independent-review.sh
    ~/.claude/hooks/stop/30-ai-analyze.sh
    ~/.claude/skills/flow/skill.md
    .flow-active
  </read_files>
  <write_files>
    （验证用临时文件，不修改既有代码）
  </write_files>
  <action>
    端到端验证，不修改代码：
    1. 模拟 stop hook 触发场景：
       - 设置 ANTHROPIC_DEFAULT_HAIKU_MODEL=test-model-v1
       - 设置 ANTHROPIC_BASE_URL=https://test.api.example.com
       - 设置 ANTHROPIC_AUTH_TOKEN=test-token-xxx
       - 手动 source 29-independent-review.sh 关键函数，验证 model 变量值 = "test-model-v1"
    2. 模拟 /flow goal --gate-config 全流程：
       - 用 8 种预设名逐一执行 /flow goal，jq 验证 gate_config 写入正确
       - 用数字简写 1,2,6 逐一执行，验证映射
       - 用完整 JSON 验证向后兼容
    3. 回归：现有 bats 测试套件全量通过
    4. 确认 stop-hook.json 未被修改（仅脚本层变更）
  </action>
  <verify>cd ~/unisoc/flow-kit && npx bats test/</verify>
  <done>全量 bats 测试套件零 fail（≥102 tests）；AC-5 运行时优先级验证通过；stop-hook.json 未修改</done>
  <depends_on>T04</depends_on>
</task>
```

---

> 所有任务的 `write_files` 均在 DESIGN 「触碰模块」范围内（29/30号脚本 + /flow skill + test/）。禁动清单无越界（未触碰 28号脚本、L2-blind-review.md、package-flow-kit.sh）。
