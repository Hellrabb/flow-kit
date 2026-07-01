# TASK: 独立 Review Agent

- **Change ID**: independent-review
- **关联**: `@.specs/independent-review/REQUIREMENT.md`、`@.specs/independent-review/DESIGN.md`

---

## 波次划分

```
Wave 1 (parallel): T01[P], T02[P], T03[P], T04[P]       # Lib + Schema 地基
Wave 2 (parallel): T05[P], T06[P]                          # 组件 A + 组件 B 核心
Wave 3 (parallel): T07[P], T08[P], T09[P]                  # L2 + Prompt + Skill
Wave 4:            T10                                      # 分发
Wave 5:            T11                                      # 同步 + 验证
```

---

## 任务清单

```xml
<task id="T01" parallel="true" status="done">
  <name>防线1: flow-kit-artifacts.sh 加 fk_independent_review_gate_active() + fk_auto_phase gate</name>
  <write_files>flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh</write_files>
  <action>新增 fk_independent_review_gate_active() 函数（双源读 gate_config + done 标志检查）；在 fk_auto_phase() 顶部加 gate 检查（gate 生效时 echo 空，阻断 check_g1 自动推进）</action>
  <verify>source flow-kit-artifacts.sh; fk_auto_phase with gate open → return empty; with done → return next phase</verify>
  <done>AC-3</done>
</task>

<task id="T02" parallel="true" status="done">
  <name>组件A: 29-independent-review.sh（L3 Stop 模块）</name>
  <write_files>flow-kit-bundle/hooks/stop/29-independent-review.sh</write_files>
  <action>仿 30-ai-analyze.sh 结构，不走频率门控，幂等 + 失败降级。Gate 链：module_enabled → phase∈{1,2,6} gate → 按阶段拼工件 → onecli proxy 调 deepseek → 落盘 INDEPENDENT-REVIEW-N.md + .flow-active.independent-review 握手</action>
  <verify>bash -n + 模拟 Stop 触发（无凭证 → 降级写 failed; fail_count 递增）</verify>
  <done>AC-1</done>
</task>

<task id="T03" parallel="true" status="done">
  <name>common.sh 加 write_failed_state() + stop-hook.json 扩展 schema</name>
  <write_files>flow-kit-bundle/hooks/stop/lib/common.sh, flow-kit-bundle/hooks/config/stop-hook.json</write_files>
  <action>common.sh 加 write_failed_state() 供 29 模块降级写状态；stop-hook.json 加 modules.independent_review + independent_review + pre_tool_use_gates 块</action>
  <verify>jq empty stop-hook.json; source common.sh → write_failed_state → verify .flow-active.independent-review content</verify>
  <done>AC-1</done>
</task>

<task id="T04" parallel="true" status="done">
  <name>flow-kit-resume.sh 加独立 review 摘要注入</name>
  <write_files>flow-kit-bundle/hooks/session-start/flow-kit-resume.sh</write_files>
  <action>仿 .flow-active.correction 模式：读 .flow-active.independent-review，status=done 且 done 标志不存在 → 打印独立 review 待确认框；status=failed + fail_count≥3 → 打印绕过提示</action>
  <verify>构造 ir_state_file + 模拟 stdin → 验证 banner 输出</verify>
  <done>AC-4</done>
</task>

<task id="T05" parallel="true" status="done">
  <name>组件B: PreToolUse independent-review-gate.sh</name>
  <write_files>flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh</write_files>
  <action>fai-open 原则。stdin 解析 tool_input.command + cwd。phase∈{1,2,6}+gate 开+done 不存在 → 匹配改阶段 jq/git commit/gh pr create → exit 2 + stderr。写信号必须同时存在防误伤</action>
  <verify>12 场景单元测试：gate 关放行/gate 开 commit deny/done 放行/jq 只读放行/写非 phase 字段放行/gh pr deny/stop-hook.json phases 兜底</verify>
  <done>AC-2</done>
</task>

<task id="T06" parallel="true" status="done">
  <name>L2: L2-blind-review.md 固化模板 + 三阶段 prompt 改造</name>
  <write_files>flow-kit-bundle/flow-kit/prompts/independent/L2-blind-review.md, flow-kit-bundle/flow-kit/prompts/{1-requirement,2-design,6-review}.md</write_files>
  <action>总纲：独立性硬约束（禁喂自评）+ 四要素输出格式 + 三阶段 checklist。三阶段 prompt 加「独立 review 调度」段（Agent tool 固化调用模板）。6-review §4.2 升级为 gate 控制</action>
  <verify>读 1/2/6 prompt 确认含「独立 review 调度」段 + 6-review §4.2 指向新机制</verify>
  <done>AC-1 (L2 部分)</done>
</task>

<task id="T07" parallel="true" status="done">
  <name>SKILL.md 加 /flow gate-config 子命令 + 放宽 key 校验</name>
  <write_files>flow-kit-bundle/skills/flow/SKILL.md</write_files>
  <action>新子命令 /flow gate-config <phase>=independent|off（jq patch .goal.gate_config）；放宽 gate_config key 校验接受阶段名（1-requirement/2-design/6-review）</action>
  <verify>grep 'gate-config <phase>' SKILL.md 确认存在；grep '1-requirement' 确认文档提及</verify>
  <done>AC-1 (使用方式)</done>
</task>

<task id="T08" parallel="true" status="done">
  <name>install_hooks.sh 补 27/28/29 + PreToolUse 接线</name>
  <write_files>flow-kit-bundle/lib/install_hooks.sh</write_files>
  <action>Stop 循环补 27/28/29（修 stale）；新增 pre-tool-use 目录拷贝；settings.json 接线 PreToolUse（jq 追加 matcher=Bash，仿 Stop 接线范式）</action>
  <verify>实际跑 install_hooks 到临时目录：验证 27/28/29 + pre-tool-use 文件存在 + settings.local.json 含 Stop 和 PreToolUse 双接线</verify>
  <done>AC-6</done>
</task>

<task id="T09" parallel="false" status="done">
  <name>同步 .claude/ + user scope + 端到端验证 + commit</name>
  <write_files>（部署操作，非 bundle 源改动）</write_files>
  <action>同步 bundle → .claude/ (project scope) + ~/.claude/ (user scope)；防线1/组件B(12场景)/组件A降级/SessionStart/jq转义/install_hooks 全量单元验证；commit 73b9edf</action>
  <verify>git log 73b9edf 存在；user scope ~/.claude/hooks/ 含 29/pre-tool-use；nanoclaw settings 已清理</verify>
  <done>AC-2/AC-3/AC-4/AC-6</done>
</task>

<task id="T10" status="done">
  <name>清理 project-scope flow-kit（当前目录 + nanoclaw）统一到 user scope</name>
  <write_files>（部署操作）</write_files>
  <action>删除当前目录 + nanoclaw 的 .claude/hooks/ + stop-hook.json + .flow-active；清理 settings.json/settings.local.json 的 flow-kit 接线</action>
  <verify>两个项目 settings.local.json hooks 为空；hooks 文件已删；nanoclaw settings.json 已清 flow-kit 接线</verify>
  <done>部署整理</done>
</task>
```

## Fix 任务（来自 REVIEW / INTEGRATION）

```xml
<!-- 占位 -->
```
