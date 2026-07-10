# TASK: 自动 checkpoint hook

- **Change ID**: `auto-checkpoint-hook`
- **关联**: `@.specs/auto-checkpoint-hook/REQUIREMENT.md`、`@.specs/auto-checkpoint-hook/DESIGN.md`

---

## 波次划分

```
Wave 1 (parallel): T01[P] + T02[P] + T03[P]  — 独立文件，互不冲突
Wave 2 (parallel): T04[P] + T05[P]            — 测试编写（需 T01+T02 产物就绪做参考）
Wave 3 (parallel): T06[P] + T07[P]            — 安装+文档（需 T02 就绪）
```

> 同 wave = 可并行；跨 wave = 必须顺序执行。

---

## 任务清单

```xml
<task id="T01" parallel="true" status="pending">
  <name>修改 checkpoint-lib.sh：移除去重逻辑</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/checkpoint-lib.sh
    flow-kit-bundle/test/test_checkpoint.bats
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/checkpoint-lib.sh
  </write_files>
  <action>
    1. 删除 CHECKPOINT_DEDUP_WINDOW 变量定义（L14-15）
    2. 从 checkpoint_write() 函数体中移除 checkpoint_dedup_check 调用（L32-35 的 if 块）
    3. 删除整个 checkpoint_dedup_check() 函数定义（L62-98）
    4. 更新文件头部 DESIGN 注释：移除 D6 "30s 去重窗口" 行
    5. 保留 checkpoint_validate() 和 checkpoint_clear() 不变
    （依据 D2：彻底删除 dedup，非保留标记 deprecated）
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/lib/checkpoint-lib.sh && ! grep -q "checkpoint_dedup_check\|CHECKPOINT_DEDUP_WINDOW" flow-kit-bundle/hooks/stop/lib/checkpoint-lib.sh</verify>
  <done>bash -n 通过；grep 确认无 dedup 相关代码残留；checkpoint_write() 每次调用必定更新 interrupt（AC-9）</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true" status="pending">
  <name>创建 PreToolUse hook：auto-checkpoint.sh</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/checkpoint-lib.sh
    flow-kit-bundle/hooks/stop/lib/common.sh
    hooks/pre-tool-use/independent-review-gate.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/pre-tool-use/auto-checkpoint.sh
  </write_files>
  <action>
    创建 hooks/pre-tool-use/auto-checkpoint.sh。
    参照 independent-review-gate.sh 的 stdin 解析模式（D7）：
    1. stdin 读 JSON → jq 解析 tool_name
       - 非 Write/Edit → exit 0（AC-4）
    2. jq 读取 .flow-active.change_id
       - 不存在或 null → exit 0（AC-3）
    3. source checkpoint-lib.sh（相对路径解析：HOOK_BASE_DIR）
    4. 从 stdin JSON 提取 tool_input.file_path（已验证字段名，见 DESIGN § 0.6）
    5. checkpoint_write "$file_path" "编辑 $file_path" ""
       - 截断 action ≤ 200 字符（checkpoint-lib.sh 内置）
       - failing_check="" （PreToolUse 路径无测试失败概念，D5）
    6. exit 0（fail-open · D4 · AC-5）
    7. 异常路径：jq 失败 / source 失败 → stderr 日志 + exit 0（AC-5）
    source-safe 模式：同 independent-review-gate.sh，helper 函数可被 source，主逻辑仅在直接执行时跑。
  </action>
  <verify>bash -n flow-kit-bundle/hooks/pre-tool-use/auto-checkpoint.sh && echo '{"tool_name":"Write","tool_input":{"file_path":"test.sh"}}' | bash flow-kit-bundle/hooks/pre-tool-use/auto-checkpoint.sh</verify>
  <done>bash -n 通过；smoke test（Write 路径）exit 0；全路径覆盖（Write/Edit/Read/无change）由 T04 bats 承担（AC-1~AC-5）</done>
  <depends_on></depends_on>
</task>

<task id="T03" parallel="true" status="pending">
  <name>更新 CONTEXT.md 已锁决策：推翻 [2026-07-04] 去重窗口</name>
  <read_files>
    .specs/CONTEXT.md
    .specs/auto-checkpoint-hook/DESIGN.md
  </read_files>
  <write_files>
    .specs/CONTEXT.md
  </write_files>
  <action>
    CONTEXT.md § 已锁决策中：
    1. 找到条目 `[2026-07-04] auto-checkpoint 双层防护 — ... 去重窗口 30s（同 file+同 type）... 来自 user-guide-update`
    2. 替换为：`[2026-07-10] auto-checkpoint 双层防护 — prompt 指令 + PreToolUse hook 兜底（auto-checkpoint-hook change 实现）。去重策略：不启用（移除去重）。推翻 [2026-07-04] 的 30s 去重窗口决定。来自 auto-checkpoint-hook`
    3. 确认域语言 "auto-checkpoint" 条目与已锁决策一致（均标注"不去抖"）——已在 REQUIREMENT 阶段更新
    （依据 DESIGN § 9.2 + L2 R3 修补）
  </action>
  <verify>grep -q "推翻.*2026-07-04.*30s" .specs/CONTEXT.md && grep -q "auto-checkpoint-hook" .specs/CONTEXT.md</verify>
  <done>grep 确认新旧两条决策均存在、推翻关系明确；域语言条目与决策一致</done>
  <depends_on></depends_on>
</task>

<task id="T04" parallel="true" status="pending">
  <name>创建 bats 测试：auto-checkpoint hook（AC-1~AC-6, AC-9）</name>
  <read_files>
    flow-kit-bundle/hooks/pre-tool-use/auto-checkpoint.sh
    flow-kit-bundle/hooks/stop/lib/checkpoint-lib.sh
    flow-kit-bundle/test/test_helper.bash
    .specs/auto-checkpoint-hook/REQUIREMENT.md
  </read_files>
  <write_files>
    flow-kit-bundle/test/test_auto_checkpoint.bats
  </write_files>
  <action>
    新建 test_auto_checkpoint.bats，覆盖 AC-1 至 AC-6 和 AC-9：
    - AC-1: Write 前自动 checkpoint（有活跃 change + phase）
    - AC-2: Edit 前自动 checkpoint（有活跃 change + phase）
    - AC-3: 无活跃 change 时静默跳过（.flow-active 不存在 / change_id=null）
    - AC-4: 非 Write/Edit 工具不触发（Read/Bash）
    - AC-5: Fail-open（损坏 JSON → exit 0 + 工具不阻断）——Write 和 Edit 双路径
    - AC-6: 恢复精度（预设 interrupt → 调用 resume banner 函数 → 断言输出含三字段）
    - AC-9: checkpoint-lib 去重已移除（连续两次 checkpoint_write 均返回 0，checkpoint_at 不同）
    参照 test/ 下已有 bats 文件的 setup/teardown 模式。
  </action>
  <verify>npx bats flow-kit-bundle/test/test_auto_checkpoint.bats --filter-tags auto-checkpoint 2>&1 || npx bats flow-kit-bundle/test/test_auto_checkpoint.bats</verify>
  <done>所有 AC-1~AC-6 + AC-9 的 bats tests 通过，无 fail</done>
  <depends_on>T01, T02</depends_on>
</task>

<task id="T05" parallel="true" status="pending">
  <name>改写 test_checkpoint.bats：dedup 测试 → 不 dedup 行为测试</name>
  <read_files>
    flow-kit-bundle/test/test_checkpoint.bats
    flow-kit-bundle/hooks/stop/lib/checkpoint-lib.sh
  </read_files>
  <write_files>
    flow-kit-bundle/test/test_checkpoint.bats
  </write_files>
  <action>
    test_checkpoint.bats L62-97 有 4 个 checkpoint_dedup_check 测试。
    checkpoint_dedup_check() 已被 T01 删除 → 这 4 个测试会失败（函数不存在）。
    改写为验证"不 dedup 行为"的测试：
    - "连续两次同文件 checkpoint_write 均成功"：两次调用间隔 < 1s，均返回 0
    - "checkpoint_at 每次不同"：两次调用后 interrupt.checkpoint_at 值不同
    保留其他与 dedup 无关的测试（checkpoint_write 原子写入、checkpoint_validate、checkpoint_clear 等）。
    （依据 DESIGN R3 缓解）
  </action>
  <verify>npx bats flow-kit-bundle/test/test_checkpoint.bats</verify>
  <done>test_checkpoint.bats 全量通过；无 dedup 函数引用；新版测试验证"不去抖"行为</done>
  <depends_on>T01</depends_on>
</task>

<task id="T06" parallel="true" status="pending">
  <name>更新 install_hooks.sh：注册 auto-checkpoint.sh</name>
  <read_files>
    flow-kit-bundle/install_hooks.sh
    .claude/settings.json
  </read_files>
  <write_files>
    flow-kit-bundle/install_hooks.sh
  </write_files>
  <action>
    在 install_hooks.sh 的 PreToolUse hook 注册段中：
    1. 参照 independent-review-gate.sh 的注册方式（install_hooks.sh:128 附近）
    2. 追加 auto-checkpoint.sh 的注册命令：
       - matcher: "Write|Edit"（缩窄于 gate 的 "Bash|Write|Edit"，D6）
       - 路径: hooks/pre-tool-use/auto-checkpoint.sh
    3. 确保 jq 追加逻辑处理 PreToolUse 键不存在的情况（创建空数组）
    （依据 AC-8 + D6）
  </action>
  <verify>bash -n flow-kit-bundle/install_hooks.sh && grep -q "auto-checkpoint" flow-kit-bundle/install_hooks.sh</verify>
  <done>bash -n 通过；grep 确认 auto-checkpoint 注册命令存在；安装后 settings.json 的 PreToolUse[] 含 auto-checkpoint.sh 条目（AC-8）</done>
  <depends_on>T02</depends_on>
</task>

<task id="T07" parallel="true" status="pending">
  <name>更新 flow SKILL.md：checkpoint 段说明自动机制</name>
  <read_files>
    flow-kit-bundle/skills/flow/SKILL.md
    .specs/auto-checkpoint-hook/DESIGN.md
  </read_files>
  <write_files>
    flow-kit-bundle/skills/flow/SKILL.md
  </write_files>
  <action>
    在 flow-kit-bundle/skills/flow/SKILL.md 的 `/flow checkpoint` 段（L236 附近）中：
    1. 在现有手动 checkpoint 说明**之前**插入自动机制说明段：
       - PreToolUse hook 自动触发（Write/Edit 前）
       - `interrupt` 三字段含义（active_file / last_action / checkpoint_at）
       - 如何读取 interrupt 恢复（`/flow` 无参数展示 / SessionStart resume 自动注入）
       - 与手动 `/flow checkpoint` 的关系（互补，不冲突）
    2. 保留原有手动 checkpoint 命令说明不变
    （依据 AC-7 + DESIGN D7）
  </action>
  <verify>grep -q "PreToolUse\|自动" flow-kit-bundle/skills/flow/SKILL.md && grep -q "active_file\|last_action\|checkpoint_at" flow-kit-bundle/skills/flow/SKILL.md</verify>
  <done>grep 确认文档含自动机制说明 + 三字段含义 + 恢复方式（AC-7）</done>
  <depends_on>T02</depends_on>
</task>
```

---

## 状态字段说明

- `status="pending"` — 未开始
- `status="in_progress"` — 进行中
- `status="done"` — 已完成（verify 通过）
- `status="blocked"` — 阻塞

---

## AC 覆盖矩阵

| AC | 任务 | 验证位置 |
|---|---|---|
| AC-1 (Write checkpoint) | T02 + T04 | auto-checkpoint.sh 主逻辑 + bats |
| AC-2 (Edit checkpoint) | T02 + T04 | auto-checkpoint.sh 主逻辑 + bats |
| AC-3 (无 change 跳过) | T02 + T04 | auto-checkpoint.sh change_id 检测 + bats |
| AC-4 (非 Write/Edit 不触发) | T02 + T04 | auto-checkpoint.sh tool_name 过滤 + bats |
| AC-5 (Fail-open) | T02 + T04 | auto-checkpoint.sh 异常处理 + bats |
| AC-6 (恢复精度) | T04 | bats 模拟 resume banner |
| AC-7 (文档) | T07 | grep SKILL.md |
| AC-8 (安装) | T06 | grep install_hooks.sh + bats |
| AC-9 (去重移除) | T01 + T04 | grep checkpoint-lib.sh + bats |

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
