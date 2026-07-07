# TASK: 用户指南全量更新 + interrupt/checkpoint 自动写入

- **Change ID**: user-guide-update
- **关联**: `@.specs/user-guide-update/REQUIREMENT.md`、`@.specs/user-guide-update/DESIGN.md`

---

## 波次划分

```
Wave 1 (parallel): T01[P], T02[P]                                ← 信息收集（只读）
Wave 2:            T03 (depends on T01,T02)                       ← 主稿编写
                   T06[P] (独立，无依赖)                           ← checkpoint-lib 创建
Wave 3 (parallel): T04[P], T05[P] (depends on T03)               ← 文档同步
                   T07, T08, T09[P], T10 (depends on T06)         ← prompt/hook/skill 改造
Wave 4:            T11 (depends on T03,T04,T05,T07,T08,T09,T10)   ← 最终验证
```

> 同 wave = 可并行；跨 wave = 必须顺序执行。

---

## 任务清单

```xml
<task id="T01" parallel="true" status="pending">
  <name>阅读近期 4 个 change 归档，提取需文档化的功能清单</name>
  <read_files>
    .specs/archive/l2-l3-granular-gate/*
    .specs/archive/pipeline-fallback-fix/*
    .specs/archive/gate-integrity/*
    .specs/archive/independent-review-gap/*
    .specs/CONTEXT.md
  </read_files>
  <write_files>
    .specs/user-guide-update/.feature-checklist.md
  </write_files>
  <action>
    从 4 份归档的 DESIGN.md + REQUIREMENT.md 中提取用户可见功能清单：
    - l2-l3-granular-gate: gate_config L2/L3/both 值，--l2-only/--l3-only flags，向后兼容映射
    - pipeline-fallback-fix: L3 front-loading, transition 方向检测, gate_config 快照, 31/32 hook
    - gate-integrity: .done 真实性校验, 三种威胁模型, gate_config 3/5/7 扩展, 独立审查四层架构
    - independent-review-gap: PRESET_MAP 对齐, L2 checklist 补齐, all 预设端到端
    输出为结构化功能清单（写入临时文件 .specs/user-guide-update/.feature-checklist.md）
  </action>
  <verify>test -f .specs/user-guide-update/.feature-checklist.md && wc -l .specs/user-guide-update/.feature-checklist.md | awk '{exit $1<20?1:0}'</verify>
  <done>功能清单 ≥ 20 行，覆盖 4 个 change 的每个用户可见功能</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true" status="pending">
  <name>阅读 FLOW-KIT-用户指南.md 当前内容，标记需更新的章节</name>
  <read_files>
    FLOW-KIT-用户指南.md
  </read_files>
  <write_files>
    .specs/user-guide-update/.section-plan.md
  </write_files>
  <action>
    通读 FLOW-KIT-用户指南.md（~50KB），标注：
    - 哪些章节已过期（与 T01 功能清单对比）
    - 哪些章节缺失（功能清单有但文档无）
    - interrupt/checkpoint 现有内容不足的部分
    输出章节更新计划（写入临时文件 .specs/user-guide-update/.section-plan.md）
  </action>
  <verify>test -f .specs/user-guide-update/.section-plan.md && grep -c "更新\|新增\|保留" .specs/user-guide-update/.section-plan.md | awk '{exit $1<3?1:0}'</verify>
  <done>章节计划含 ≥3 处"更新"/"新增"/"保留"标记</done>
  <depends_on></depends_on>
</task>

<task id="T03" parallel="false" status="pending">
  <name>编写 FLOW-KIT-用户指南.md 全部新章节（主稿）</name>
  <read_files>
    FLOW-KIT-用户指南.md
    .specs/user-guide-update/.feature-checklist.md
    .specs/user-guide-update/.section-plan.md
    .specs/user-guide-update/DESIGN.md
  </read_files>
  <write_files>
    FLOW-KIT-用户指南.md
  </write_files>
  <action>
    按 .section-plan.md 的更新计划，编写/更新以下章节：
    - gate_config 章节：L2/L3/both 三值用法 + preset 表 + 数字简写 + --l2-only/--l3-only flags
    - pipeline goal 章节：--pipeline --from N --gate-config X 完整用法 + toll-gate 机制 + 门禁条件
    - auto_advance + fallback 章节：31/32 hook 兜底 + 触发条件 + 如何启用
    - 独立审查章节：四层架构图 + L2/L3 调度流程 + .done 真实性校验 + 三种威胁模型
    - interrupt/checkpoint 专项（重点）：字段结构表（active_file/last_action/failing_check/checkpoint_at）+
      手动用法 /flow checkpoint + 恢复流程 /flow-go 继续 + auto-checkpoint 触发时机（4 种）+
      中断恢复 4 步操作 /flow → 确认字段 → /flow-go 继续 → 恢复确认
    - 其他增量：gate_config 快照同步 + L3 前置 + transition 方向检测 + gate_config 3/5/7 扩展

    保留现有有效内容不变。末尾标注"最后同步日期: 2026-07-06"
  </action>
  <verify>grep -cE "L2|L3|both" FLOW-KIT-用户指南.md | awk '{exit $1<5?1:0}' && grep -cE "checkpoint|interrupt" FLOW-KIT-用户指南.md | awk '{exit $1<10?1:0}'</verify>
  <done>用户指南含 ≥5 处 gate_config 引用 + ≥10 处 checkpoint/interrupt 引用 + 最后同步日期标注</done>
  <depends_on>T01, T02</depends_on>
</task>

<task id="T04" parallel="true" status="pending">
  <name>同步 README.md（从用户指南提取摘要）</name>
  <read_files>
    FLOW-KIT-用户指南.md
    README.md
    .specs/user-guide-update/.feature-checklist.md
  </read_files>
  <write_files>
    README.md
  </write_files>
  <action>
    从 FLOW-KIT-用户指南.md 提取关键章节摘要同步到 README.md：
    - 功能列表更新（添加 gate_config L2/L3/both、pipeline goal、interrupt/checkpoint）
    - 快速入门示例更新（添加 /flow checkpoint 用法）
    - 保持 README 的简洁风格（速览，非操作手册）
  </action>
  <verify>grep -c "L2\|L3\|checkpoint" README.md | awk '{exit $1<3?1:0}'</verify>
  <done>README 含 gate_config + checkpoint 关键引用，内容与用户指南一致无矛盾</done>
  <depends_on>T03</depends_on>
</task>

<task id="T05" parallel="true" status="pending">
  <name>同步 flow-kit-ecosystem-guide.md（从用户指南提取架构摘要）</name>
  <read_files>
    FLOW-KIT-用户指南.md
    flow-kit-ecosystem-guide.md
    .specs/user-guide-update/.feature-checklist.md
  </read_files>
  <write_files>
    flow-kit-ecosystem-guide.md
  </write_files>
  <action>
    从 FLOW-KIT-用户指南.md 提取架构级内容同步到 ecosystem-guide：
    - 组件清单更新（添加 31-auto-advance.sh / 32-fallback-guard.sh / checkpoint-lib.sh）
    - hook 模块编号表更新（27/28/31/32 已占用，checkpoint-lib 为 lib 非独立模块）
    - 独立审查四层架构图
    保持 ecosystem-guide 的架构清单风格
  </action>
  <verify>grep -c "31-auto-advance\|32-fallback\|checkpoint-lib\|四层架构" flow-kit-ecosystem-guide.md | awk '{exit $1<3?1:0}'</verify>
  <done>ecosystem-guide 含新 hook 模块 + checkpoint-lib + 四层架构引用</done>
  <depends_on>T03</depends_on>
</task>

<task id="T06" parallel="true" status="pending">
  <name>创建 checkpoint-lib.sh（共享 checkpoint 写入 + 去重 + 校验函数）</name>
  <read_files>
    .specs/user-guide-update/DESIGN.md
    .specs/CONTEXT.md
  </read_files>
  <write_files>
    hooks/stop/lib/checkpoint-lib.sh
  </write_files>
  <action>
    创建 `hooks/stop/lib/checkpoint-lib.sh`，提供：
    - `checkpoint_write(file, action, [failing_check])`：原子写入 .flow-active.interrupt
    - `checkpoint_dedup_check(file, type, window_sec=30)`：30s 去重窗口
    - `checkpoint_validate()`：jq empty JSON 合法性校验
    遵循 DESIGN D1/D2/D5/D6 规格：
    - 相对路径（${PWD#"$PROJECT_ROOT"/}）
    - last_action ≤ 200 chars（截断+…）
    - checkpoint_at: ISO8601（date -Iseconds）
    - 原子写入：jq → .tmp → mv
    - 校验失败 → 保留旧值 + stderr warn
    沿用既有 jq 原子写入模式（见 /flow skill 全部子命令）
  </action>
  <verify>bash -n hooks/stop/lib/checkpoint-lib.sh && grep -c "checkpoint_write\|checkpoint_dedup_check\|checkpoint_validate" hooks/stop/lib/checkpoint-lib.sh | awk '{exit $1<3?1:0}'</verify>
  <done>checkpoint-lib.sh 语法正确，导出 3 个函数，符合 DESIGN D1/D2/D5/D6</done>
  <depends_on></depends_on>
</task>

<task id="T07" parallel="false" status="pending">
  <name>向 15 个 prompt 的 PCSC 段追加 auto-checkpoint 指令</name>
  <read_files>
    ~/.claude/flow-kit/prompts/0-change.md
    ~/.claude/flow-kit/prompts/1-requirement.md
    ~/.claude/flow-kit/prompts/2-design.md
    ~/.claude/flow-kit/prompts/3-task.md
    ~/.claude/flow-kit/prompts/4-dev.md
    ~/.claude/flow-kit/prompts/5-test.md
    ~/.claude/flow-kit/prompts/6-review.md
    ~/.claude/flow-kit/prompts/7-integration.md
    ~/.claude/flow-kit/prompts/2a-ui-design.md
    ~/.claude/flow-kit/prompts/A-architect.md
    ~/.claude/flow-kit/prompts/A-evolve.md
    ~/.claude/flow-kit/prompts/I-intel-scan.md
    ~/.claude/flow-kit/prompts/L-restyle.md
    ~/.claude/flow-kit/prompts/M-health.md
    hooks/stop/lib/checkpoint-lib.sh
  </read_files>
  <write_files>
    ~/.claude/flow-kit/prompts/0-change.md
    ~/.claude/flow-kit/prompts/1-requirement.md
    ~/.claude/flow-kit/prompts/2-design.md
    ~/.claude/flow-kit/prompts/3-task.md
    ~/.claude/flow-kit/prompts/4-dev.md
    ~/.claude/flow-kit/prompts/5-test.md
    ~/.claude/flow-kit/prompts/6-review.md
    ~/.claude/flow-kit/prompts/7-integration.md
    ~/.claude/flow-kit/prompts/2a-ui-design.md
    ~/.claude/flow-kit/prompts/A-architect.md
    ~/.claude/flow-kit/prompts/A-evolve.md
    ~/.claude/flow-kit/prompts/I-intel-scan.md
    ~/.claude/flow-kit/prompts/L-restyle.md
    ~/.claude/flow-kit/prompts/M-health.md
  </write_files>
  <action>
    在每个 prompt 的 PCSC 表末尾追加一行（DESIGN D3）：
    ```
    | N+1 | auto-checkpoint: .flow-active.interrupt 已通过 jq 写入当前操作上下文 | test -s .flow-active && jq -e '.interrupt.checkpoint_at' .flow-active >/dev/null | ✅ / ❌ |
    ```
    以及 PCSC 末尾追加 auto_advance 分支的 checkpoint 触发说明。
    每个 prompt 约 +3 行。
  </action>
  <verify>for f in ~/.claude/flow-kit/prompts/*.md; do grep -q "auto-checkpoint\|interrupt.checkpoint_at" "$f" || echo "MISSING: $f"; done | (! grep .)</verify>
  <done>全部 15 个 prompt 的 PCSC 段含 auto-checkpoint 自检项</done>
  <depends_on>T06</depends_on>
</task>

<task id="T08" parallel="false" status="pending">
  <name>修改 PreToolUse hook 集成 checkpoint-lib.sh 兜底写入</name>
  <depends_on>T07</depends_on>
  <read_files>
    hooks/stop/lib/checkpoint-lib.sh
    .claude/hooks/stop-hook.json
  </read_files>
  <write_files>
    ~/.claude/flow-kit/hooks/stop/independent-review-gate.sh
  </write_files>
  <action>
    在现有 PreToolUse hook（independent-review-gate.sh）中追加 auto-checkpoint 兜底逻辑：
    - 检测 Write/Edit 工具调用 → source checkpoint-lib.sh → checkpoint_write(file, "edit $file")
    - 检测 Bash exit≠0 → checkpoint_write("", "test failed: $cmd", "$cmd")
    - 检测 jq .goal.current_phase write → checkpoint_write("", "phase transition to $phase")
    - 30s 去重（checkpoint_dedup_check）
    - JSON 校验（checkpoint_validate）
    不新增独立 hook 模块号，内联调用 lib 函数（符合 DESIGN D1 CHECK-1）
  </action>
  <verify>bash -n ~/.claude/flow-kit/hooks/stop/independent-review-gate.sh && grep -c "checkpoint_lib\|checkpoint_write" ~/.claude/flow-kit/hooks/stop/independent-review-gate.sh | awk '{exit $1<1?1:0}'</verify>
  <done>PreToolUse hook 语法正确，含 checkpoint-lib 调用</done>
  <depends_on>T06</depends_on>
</task>

<task id="T09" parallel="true" status="pending">
  <name>写 checkpoint-lib 单元测试（bats-core）</name>
  <read_files>
    hooks/stop/lib/checkpoint-lib.sh
    test/test_common.bats
  </read_files>
  <write_files>
    test/test_checkpoint.bats
  </write_files>
  <action>
    创建 test/test_checkpoint.bats，覆盖：
    - checkpoint_write 正常写入 + jq 字段验证
    - checkpoint_write 覆盖手动 checkpoint（AC-4）
    - checkpoint_dedup_check 30s 去重窗口
    - checkpoint_validate 合法 JSON 通过 / 非法 JSON 失败
    - 原子性：写入失败保留旧值
    参考 test_common.bats 的 bats 风格（setup/teardown + assert）
  </action>
  <verify>npx bats test/test_checkpoint.bats</verify>
  <done>全部 checkpoint-lib 测试通过，≥ 6 条测试用例</done>
  <depends_on>T06</depends_on>
</task>

<task id="T10" parallel="false" status="pending">
  <name>更新 GO.md 中断恢复路由声明，展示 interrupt 上下文</name>
  <read_files>
    ~/.claude/flow-kit/prompts/GO.md
  </read_files>
  <write_files>
    ~/.claude/flow-kit/prompts/GO.md
  </write_files>
  <action>
    修改 GO.md 路由表中的"继续"条目：
    - 从 .flow-active 读 interrupt 字段
    - 路由声明中显式展示：active_file + last_action + checkpoint_at
    - 注入到对应阶段 prompt 的恢复段
    对应 AC-5：中断恢复时上下文注入
  </action>
  <verify>grep -c "interrupt\|active_file\|last_action\|checkpoint_at" ~/.claude/flow-kit/prompts/GO.md | awk '{exit $1<3?1:0}'</verify>
  <done>GO.md 路由声明含 interrupt 字段引用 + 上下文注入逻辑</done>
  <depends_on>T08</depends_on>
</task>

<task id="T11" parallel="false" status="pending">
  <name>文档一致性验证 + 完整流程集成测试</name>
  <read_files>
    FLOW-KIT-用户指南.md
    README.md
    flow-kit-ecosystem-guide.md
    .specs/user-guide-update/REQUIREMENT.md
    test/test_checkpoint.bats
  </read_files>
  <write_files>
    <!-- 验证任务，只读不写 -->
  </write_files>
  <action>
    最终验证（AC-1 ~ AC-6 全部覆盖）：
    1. 三份文档逐项对照 .feature-checklist.md 确认覆盖（AC-1）
    2. interrupt/checkpoint 章节人工阅读确认 5 点覆盖（AC-2）
    3. 模拟 4 种触发场景写 checkpoint → jq 验证字段（AC-3）
    4. 自动 checkpoint → 手动 /flow checkpoint → 确认覆盖（AC-4）
    5. 模拟中断 → /flow-go 继续 → GO.md 注入验证（AC-5）
    6. 逐条对照用户指南命令在环境执行（AC-6）
    7. 全量 bats 回归（npx bats test/）
  </action>
  <verify>npx bats test/</verify>
  <done>全部 AC 验证通过，bats 全量回归 0 fail，三份文档内容一致无矛盾</done>
  <depends_on>T03, T04, T05, T07, T08, T09, T10</depends_on>
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

```xml
<!-- 占位 -->
```
