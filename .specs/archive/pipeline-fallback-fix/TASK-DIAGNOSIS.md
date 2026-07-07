# TASK: 诊断 pipeline 自动推进 + 回退模式

- **Change ID**: pipeline-fallback-fix
- **关联**: `@.specs/pipeline-fallback-fix/REQUIREMENT.md`、`@.specs/pipeline-fallback-fix/DESIGN.md`

---

## 波次划分

```
Wave 1 (parallel): T01[P], T02[P], T04[P]   （独立诊断观察，互不冲突）
Wave 2:            T03                        （depends on T01 · 需 native 基线对比）
Wave 3:            T05                        （depends on T01, T02, T03, T04 · 汇总全部证据）
```

---

## 任务清单

```xml
<task id="T01" parallel="true" status="pending">
  <name>Native 路径剩余阶段诊断（phase 3→7）</name>
  <read_files>
    .flow-active
    .specs/pipeline-fallback-fix/*.md
    ~/.claude/flow-kit/prompts/3-task.md
    ~/.claude/flow-kit/prompts/4-dev.md
    ~/.claude/flow-kit/prompts/5-test.md
    ~/.claude/flow-kit/prompts/6-review.md
    ~/.claude/flow-kit/prompts/7-integration.md
    ~/.claude/flow-kit/GO.md
    ~/.claude/hooks/pre-tool-use/independent-review-gate.sh
  </read_files>
  <write_files>
    .specs/pipeline-fallback-fix/DIAGNOSIS.md（T01 段：native 路径观察记录）
  </write_files>
  <action>
    在当前 change（auto_advance=false, native 模式）上继续推进 pipeline：
    - 完成 phase 3→4→5→6→7 的 toll-gate 交互和 transition
    - 在每个 toll-gate 记录：PCSC 是否执行、toll-gate 提示是否输出、用户确认后 transition 是否成功
    - 在每个 transition 记录：PreToolUse hook 是否拦截（如适用）、jq 命令是否成功、current_phase 是否正确更新
    - 观察 gate_config 独立审查 gate 的行为（是否形成 L2+L3 异步死锁）
    - 记录所有发现的异常行为到 DIAGNOSIS.md 的 T01 段
    覆盖 AC: AC-3, AC-6a, AC-6b, AC-12（native 完成行为）
  </action>
  <verify>grep -c "### Phase" .specs/pipeline-fallback-fix/DIAGNOSIS.md | grep -E "^[4-9]|^[1-9][0-9]"</verify>
  <done>DIAGNOSIS.md T01 段含 phase 3→7 每个 toll-gate/transition 的观察记录 + transcript 摘录 + .flow-active 快照（AC-11 a/b/c）</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true" status="pending">
  <name>auto_advance=true 最小验证（独立分支）</name>
  <read_files>
    .specs/CONTEXT.md
    ~/.claude/flow-kit/prompts/0-change.md
    ~/.claude/flow-kit/prompts/1-requirement.md
    ~/.claude/flow-kit/prompts/4-dev.md
  </read_files>
  <write_files>
    .specs/pipeline-fallback-fix/DIAGNOSIS.md（T02 段：auto_advance 观察记录）
  </write_files>
  <action>
    在独立 git 分支上创建最小 change（change-id: auto-advance-smoke-test），设 auto_advance=true：
    - 创建最小 CHANGE.md + REQUIREMENT.md（1 个 AC）
    - 设 .flow-active.goal.auto_advance = true，pipeline scope，from=4
    - 跑 phases 4→5→6→7，观察每个阶段 PCSC 全✅后是否自动 transition（不输出 toll-gate 提示）
    - 故意在某个阶段制造 ❌（缺产物），观察 pipeline 是否暂停并输出缺失清单
    - 记录所有观察结果到 DIAGNOSIS.md 的 T02 段
    覆盖 AC: AC-1, AC-2
    隔离措施：独立分支 + 独立 .flow-active（不污染当前 change）
  </action>
  <verify>grep -c "auto_advance" .specs/pipeline-fallback-fix/DIAGNOSIS.md | grep -v "^0$"</verify>
  <done>DIAGNOSIS.md T02 段含 auto_advance=true 的自动推进行为观察（✅/❌）+ PCSC ❌阻塞行为观察 + 证据附件</done>
  <depends_on></depends_on>
</task>

<task id="T03" status="pending">
  <name>Fallback 模式模拟诊断</name>
  <read_files>
    .flow-active
    .specs/pipeline-fallback-fix/DIAGNOSIS.md（T01 段 · native 基线）
    ~/.claude/flow-kit/GO.md
    ~/.claude/flow-kit/prompts/4-dev.md
    ~/.claude/flow-kit/prompts/5-test.md
    ~/.claude/flow-kit/prompts/6-review.md
    ~/.claude/flow-kit/prompts/7-integration.md
  </read_files>
  <write_files>
    .specs/pipeline-fallback-fix/DIAGNOSIS.md（T03 段：fallback 路径观察记录 + 差异对比表）
  </write_files>
  <action>
    在完成 T01（native 基线）后，将当前 change 切换为 fallback 模式：
    - 设置 .flow-active.goal.mode = "fallback"
    - 从 phase 4 起步（或从当前 phase 继续），观察 fallback 迭代循环行为
    - 对比每个 toll-gate 的 native vs fallback 行为差异（暂停点、选项、transition 命令、终止消息）
    - 验证 fallback 终止条件：全阶段完成后是否正确终止（AC-9），中间阶段是否不提前终止（AC-10）
    - 记录差异对比表到 DIAGNOSIS.md 的 T03 段
    覆盖 AC: AC-7, AC-8, AC-9, AC-10
    注：T03 覆盖直接设 mode 路径；版本检测路径标记为诊断盲区（AC-7 注释）
  </action>
  <verify>grep -c "fallback" .specs/pipeline-fallback-fix/DIAGNOSIS.md | grep -v "^0$"</verify>
  <done>DIAGNOSIS.md T03 段含 native vs fallback 差异对比表 + 终止条件验证 + 证据附件（AC-11 a/b/c）</done>
  <depends_on>T01</depends_on>
</task>

<task id="T04" parallel="true" status="pending">
  <name>.done 文件真实性校验验证</name>
  <read_files>
    ~/.claude/hooks/pre-tool-use/independent-review-gate.sh
    .specs/pipeline-fallback-fix/.goal-snapshot.json
    .flow-active
  </read_files>
  <write_files>
    .specs/pipeline-fallback-fix/DIAGNOSIS.md（T04 段：done 真实性观察记录）
    /tmp/done-test-empty.done（测试用临时文件，诊断后删除）
    /tmp/done-test-fake.done（测试用临时文件，诊断后删除）
    /tmp/done-test-missing-key.done（测试用临时文件，诊断后删除）
  </write_files>
  <action>
    构造多种 .done 文件变体，验证 hook 的真实性校验：
    - 空文件：touch empty.done → 验证 hook 拒绝
    - 假内容：echo "done" > fake.done → 验证 hook 拒绝
    - 占位文本：echo "review completed" > placeholder.done → 验证 hook 拒绝
    - 缺键：创建含 phase/change_id/L2_verdict 但缺 L3_verdict 的 .done → 验证 hook 拒绝
    - 合法：创建含全部 5 键（phase/change_id/L2_verdict/L3_verdict/artifacts）的 .done → 验证 hook 接受
    记录每种变体的 hook 行为到 DIAGNOSIS.md 的 T04 段
    覆盖 AC: AC-4, AC-5, AC-5a
  </action>
  <verify>grep -c "\.done.*真实性\|done.*伪造\|done.*空文件" .specs/pipeline-fallback-fix/DIAGNOSIS.md | grep -v "^0$"</verify>
  <done>DIAGNOSIS.md T04 段含 5 种 .done 变体的 hook 行为记录（✅/❌）+ AC-5a 结构化字段校验结果</done>
  <depends_on></depends_on>
</task>

<task id="T05" status="pending">
  <name>汇总产出 DIAGNOSIS.md 最终报告</name>
  <read_files>
    .specs/pipeline-fallback-fix/DIAGNOSIS.md（T01-T04 段）
    .specs/pipeline-fallback-fix/REQUIREMENT.md
    .specs/pipeline-fallback-fix/CHANGE.md
    .flow-active
  </read_files>
  <write_files>
    .specs/pipeline-fallback-fix/DIAGNOSIS.md（最终版：汇总 + 根因 + 修复建议）
  </write_files>
  <action>
    汇总 T01-T04 的全部观察记录，产出最终诊断报告：
    - Per-AC 状态表（14 条 AC，逐条标记 ✅/⚠️/❌ + 根因分析）
    - Native vs Fallback 差异对比表（逐 toll-gate 对比）
    - 已发现的关键 issue 清单（含本次诊断中遭遇的 2 个死锁）
    - 按优先级排序的修复建议（P0/P1/P2，含影响的源文件路径）
    - 证据附录（所有 ❌/⚠️ AC 的 transcript 摘录 + .flow-active 快照）
    覆盖 AC: AC-11（诊断证据完整性）
  </action>
  <verify>grep -c "AC-[0-9]" .specs/pipeline-fallback-fix/DIAGNOSIS.md | grep -E "^1[4-9]|^[2-9][0-9]"</verify>
  <done>DIAGNOSIS.md 最终版含：逐 AC 状态表 + native/fallback 差异对比 + 根因分析 + 优先级修复建议 + 证据附录（AC-11 a/b/c 全覆盖）</done>
  <depends_on>T01, T02, T03, T04</depends_on>
</task>
```

---

## 状态字段说明

- `status="pending"` — 未开始
- `status="in_progress"` — 进行中
- `status="done"` — 已完成（verify 通过）
- `status="blocked"` — 阻塞

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
