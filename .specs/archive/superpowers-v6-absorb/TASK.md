# TASK: superpowers v6.0 经验吸收

- **Change ID**: superpowers-v6-absorb
- **关联**: `@.specs/superpowers-v6-absorb/REQUIREMENT.md`、`@.specs/superpowers-v6-absorb/DESIGN.md`、5 ADRs (`.specs/adr/014-018`)

---

## 波次划分

```
Wave 1 (parallel · 5 tasks): T01[P], T02[P], T03[P], T04[P], T05[P]
Wave 2 (parallel · 5 tasks): T06[P], T07[P], T08[P], T09[P], T10[P]
                              (T06←T03, T07←T01,T03,T04, T08←T02, T09←T03,T04, T10←ADR-016)
Wave 3 (sequential · 2 tasks): T11 ← T05, T10
                                T12 ← T01, T02, T11
```

> 同 wave = 可并行；跨 wave = 必须顺序执行。

---

## 任务清单

```xml
<task id="T01" parallel="true" status="done" model-tier="standard">
  <name>新增 scripts/review-package.sh + bats 测试</name>
  <read_files>
    flow-kit-bundle/flow-kit/scripts/*  <!-- 新目录 -->
    .specs/superpowers-v6-absorb/DESIGN.md
    .specs/adr/014-review-merge-and-spot-check.md
    .specs/CONTEXT.md  <!-- 命名约定段 fk_/_fk_/kebab-case -->
    test/test_common.bats  <!-- bats 写法参考 -->
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/scripts/review-package
    flow-kit-bundle/flow-kit/scripts/.gitignore
    test/test_review_package.bats
  </write_files>
  <action>
    新建 review-package bash 脚本（约 46 行），按 DESIGN D2/D3 实现：
    - 输入：base commit + head commit（默认 HEAD）
    - 输出：stdout markdown 三段（## Commits / ## Files changed / ## Diff）
    - 用 `git log --oneline`、`git diff --stat`、`git diff -U10` 收集
    - `set -euo pipefail`
    - 非 git 仓库 → exit ≠0 + stderr "not a git repository"（AC-A1-ERR）
    - 路径中无空格 / 特殊字符的 happy path + non-git error path
    同时新建 `flow-kit-bundle/flow-kit/scripts/.gitignore`（内容：`*.tmp`、`*.log`、`__pycache__/`、`.DS_Store`，覆盖 scripts 目录可能的临时产物）
    同时写 test_review_package.bats（≥5 tests）：happy path / non-git error / 空 diff / 大 diff 截断 / markdown 结构断言
    沿用命名约定：函数名 _fk_review_package（私有，文件内）。
  </action>
  <verify>cd /home/hellrabbit/unisoc/flow-kit && npx bats test/test_review_package.bats</verify>
  <done>脚本跨平台跑通 + bats ≥5 tests 全绿 + non-git error path 覆盖（AC-A1 / AC-A1-ERR / AC-I1）</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true" status="done" model-tier="standard">
  <name>新增 scripts/task-brief.awk + bats 测试</name>
  <read_files>
    flow-kit-bundle/flow-kit/scripts/*  <!-- 新目录 -->
    flow-kit-bundle/flow-kit/templates/TASK.md  <!-- 现有格式 -->
    .specs/superpowers-v6-absorb/DESIGN.md
    .specs/adr/015-task-progress-schema.md
    .specs/adr/016-model-tier-dispatch.md
    test/test_common.bats
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/scripts/task-brief
    test/test_task_brief.bats
  </write_files>
  <action>
    新建 task-brief awk 脚本（约 41 行），按 DESIGN D4 实现：
    - 输入：TASK.md 文件 + task ID（如 T03）
    - 输出：stdout = 该 task 的完整 XML block（从 `<task id="T03"` 到 `</task>`）
    - 用 awk 状态机：START → 寻找匹配 id 的 `<task` → 收集到 `</task>` → END
    - 找不到 → exit ≠0 + stderr "task <id> not found"
    - 输出大小 ≤ 15KB（AC-B4，由 4-dev 改造后保证，本任务只确保 task 块本身完整）
    同时写 test_task_brief.bats（≥4 tests）：happy path / task 不存在 / 多 task 文件 / XML 完整性
    脚本署名行 `#!/usr/bin/awk -f`，文件名无扩展名（与 review-package 一致）。
  </action>
  <verify>cd /home/hellrabbit/unisoc/flow-kit && npx bats test/test_task_brief.bats</verify>
  <done>脚本提取指定 task XML block 完整 + bats ≥4 tests 全绿（AC-A2 / AC-I1）</done>
  <depends_on></depends_on>
</task>

<task id="T03" parallel="true" status="done" model-tier="cheap">
  <name>新增 reference/terse-contract.md 共享片段</name>
  <read_files>
    flow-kit-bundle/flow-kit/reference/*  <!-- 现有 reference -->
    .specs/superpowers-v6-absorb/DESIGN.md  <!-- D5 -->
    .specs/adr/014-review-merge-and-spot-check.md
    flow-kit-bundle/flow-kit/prompts/independent/L2-blind-review.md  <!-- 既有 review 风格参考 -->
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/reference/terse-contract.md
  </write_files>
  <action>
    新建 reference/terse-contract.md（约 30-50 行），按 DESIGN D5 实现：
    - 内容：硬性输出 schema 约束的 markdown 片段，供 review/test 类 prompt 通过 `@see` 引用
    - 核心约束（逐条列出）：
      1. verdict-first（结论先行）
      2. no preamble（无引言）
      3. no process narration（不描述思考过程）
      4. no closing summary（无收尾总结）
      5. every line is verdict-or-finding-with-file:line-or-check（每行必是结论/含 file:line 的发现/检查项）
    - 给出"反例 vs 正例"对照（≥2 组）
    - 末尾标注 `<!-- @see 引用方式：复制本段到 prompt 顶部，或用 @flow-kit/reference/terse-contract.md 引用 -->`
    风格对齐既有 reference 文件（pipeline-gates.md / interactive-ui-guard.md）。
  </action>
  <verify>test -f flow-kit-bundle/flow-kit/reference/terse-contract.md && grep -c "verdict-first\|no preamble\|no process narration" flow-kit-bundle/flow-kit/reference/terse-contract.md</verify>
  <done>片段含 5 条核心约束 + ≥2 反例 + 引用说明（AC-C1 / AC-H1 准备）</done>
  <depends_on></depends_on>
</task>

<task id="T04" parallel="true" status="done" model-tier="cheap">
  <name>新增 reference/narration-constraint.md 共享片段</name>
  <read_files>
    flow-kit-bundle/flow-kit/reference/*
    .specs/superpowers-v6-absorb/DESIGN.md  <!-- D6 -->
    flow-kit-bundle/flow-kit/RULES.md  <!-- 既有 narration 风格参考 -->
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/reference/narration-constraint.md
  </write_files>
  <action>
    新建 reference/narration-constraint.md（约 20-30 行），按 DESIGN D6 实现：
    - 内容：phase prompts 顶部的 narration 约束片段
    - 核心句（必须 verbatim）："between tool calls, narrate at most one short line — the ledger and the tool results carry the record"
    - 适用范围：所有 phase prompts 顶部
    - 反例（≥2 个）：长篇 narration / 重复 tool 输出 / 解释接下来要做什么的"plan"
    - 引用方式标注（同 T03）
  </action>
  <verify>test -f flow-kit-bundle/flow-kit/reference/narration-constraint.md && grep -q "between tool calls, narrate at most one short line" flow-kit-bundle/flow-kit/reference/narration-constraint.md</verify>
  <done>片段含核心句 + ≥2 反例 + 引用说明（AC-C2 / AC-H1 准备）</done>
  <depends_on></depends_on>
</task>

<task id="T05" parallel="true" status="done" model-tier="cheap">
  <name>新增 reference/loading-artifacts.md（从 GO.md 迁移）</name>
  <read_files>
    flow-kit-bundle/flow-kit/GO.md  <!-- 第四步"加载工件"段 -->
    flow-kit-bundle/flow-kit/reference/*
    .specs/adr/018-go-md-bootstrap-compression.md
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/reference/loading-artifacts.md
  </write_files>
  <action>
    新建 reference/loading-artifacts.md（约 40-60 行），按 ADR-018 实现：
    - 把 GO.md "第四步 · 加载工件"段的操作指令迁移过来：
      a. 必读 vs 按需严格区分
      b. grep + read + offset/limit 操作范例
      c. reference 某一节的实际动作示例（# ± 查行号 # 取到 line N）
      d. 150 行 cap per phase
    - 在文件顶部加来源标注：`<!-- 迁移自 GO.md 第四步，本段为单一源，GO.md 仅保留 @see 引用 -->`
    - 文件本身不超 60 行（避免引入新 token 负担）
    T11（Wave 3）会从 GO.md 删原段 + 加 @see 引用。
  </action>
  <verify>test -f flow-kit-bundle/flow-kit/reference/loading-artifacts.md && wc -l flow-kit-bundle/flow-kit/reference/loading-artifacts.md</verify>
  <done>文件创建 + 含 4 个操作段 + ≤60 行（AC-H1 准备）</done>
  <depends_on></depends_on>
</task>

<task id="T06" parallel="true" status="done" model-tier="standard">
  <name>L2-blind-review.md 加 severity 强制 + test_severity_format.bats</name>
  <read_files>
    flow-kit-bundle/flow-kit/prompts/independent/L2-blind-review.md
    flow-kit-bundle/flow-kit/reference/terse-contract.md  <!-- T03 产出 -->
    .specs/adr/017-severity-gating-protocol.md
    .specs/superpowers-v6-absorb/DESIGN.md  <!-- D7 -->
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/prompts/independent/L2-blind-review.md
    test/test_severity_format.bats
  </write_files>
  <action>
    改造既有 L2-blind-review.md（115 行）：
    1. 在"输出格式（强制 · 四要素 + 严重度）"段加 severity 标记规范：每条发现必须以 `**Severity**: 🔴/🟡/🟢 Critical/Important/Minor` 行声明
    2. 加"Severity Gating 契约"段：🟢 Minor findings 不入 fix loop，主 agent 写入 `.specs/<id>/MINOR-DEFERRED.md`（单一路径，ADR-017）
    3. 引用 terse-contract.md（在文件顶部 @see 引用）
    4. 反例段加"无 severity 标记的发现 = 无效发现"
    同时写 test_severity_format.bats（≥3 tests）：
    - 断言 L2-blind-review.md 含 severity 标记规范
    - 断言 MINOR-DEFERRED.md 路径声明
    - 断言 terse-contract.md @see 引用存在
  </action>
  <verify>cd /home/hellrabbit/unisoc/flow-kit && npx bats test/test_severity_format.bats && grep -q "Severity.*Critical/Important/Minor" flow-kit-bundle/flow-kit/prompts/independent/L2-blind-review.md</verify>
  <done>L2 prompt 含 severity 强制 + gating 契约 + bats 全绿（AC-D1 / AC-D2 / AC-I1）</done>
  <depends_on>T03</depends_on>
</task>

<task id="T07" parallel="true" status="done" model-tier="top">
  <name>重构 prompts/6-review.md（4 轮→1 轮 + Critical 触发 spot-check）</name>
  <read_files>
    flow-kit-bundle/flow-kit/prompts/6-review.md  <!-- 既有 423 行 -->
    flow-kit-bundle/flow-kit/scripts/review-package  <!-- T01 产出 -->
    flow-kit-bundle/flow-kit/reference/terse-contract.md  <!-- T03 -->
    flow-kit-bundle/flow-kit/reference/narration-constraint.md  <!-- T04 -->
    .specs/adr/014-review-merge-and-spot-check.md
    .specs/adr/017-severity-gating-protocol.md
    .specs/superpowers-v6-absorb/DESIGN.md  <!-- D1 + §3 状态机 -->
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/prompts/6-review.md
  </write_files>
  <action>
    重构既有 6-review.md（423 行 → 目标 ~280 行）：
    1. 顶部加 narration-constraint.md @see 引用
    2. 删除 4 轮 review 流程（spec compliance / code quality / UI visual / cross-model spot-check），合并为单一审查段
    3. 单轮审查段引用 terse-contract.md（verdict-first schema）
    4. 改用 review-package 脚本：指示主 agent 先跑 `bash scripts/review-package BASE HEAD > /tmp/review-pkg.md` 再 read
    5. 加 severity 标记强制段（引用 L2-blind-review.md 的 severity 契约）
    6. 加 Critical-finding 触发 spot-check 段：
       - 触发条件：合并审查 verdict=fail 且至少 1 条 🔴 Critical
       - 触发动作：派独立 subagent 用不同模型做盲审第 2 轮
       - 写入 `.flow-active.goal.task_progress[].spot_check_triggered = true`
    7. 加 Minor findings 延后协议：写入 `.specs/<id>/MINOR-DEFERRED.md`
    8. 删除"3-4 review rounds"措辞，改为"1 轮合并审查 + 可选 Critical 触发 spot-check 第 2 轮"（Phase 2 L2 R4 修复）
    9. 保留 PCSC 段、Pipeline Toll-Gate 段、独立 review 调度段（gate_config=L2/both 时仍按原协议派 L2）
    预期：行数从 423 降到 ~280（-33%），单轮审查节省 token -40%（参考 AC-J2）。
  </action>
  <verify>test -f flow-kit-bundle/flow-kit/prompts/6-review.md && ! grep -q "Round [1234]\|3-4 review rounds" flow-kit-bundle/flow-kit/prompts/6-review.md && grep -q "review-package" flow-kit-bundle/flow-kit/prompts/6-review.md && grep -q "spot-check" flow-kit-bundle/flow-kit/prompts/6-review.md</verify>
  <done>6-review.md 单轮 + spot-check 触发逻辑就位 + 无"Round 1/2/3"残留（AC-B1 / AC-B2 / AC-B3）</done>
  <depends_on>T01, T03, T04</depends_on>
</task>

<task id="T08" parallel="true" status="done" model-tier="top">
  <name>改造 prompts/4-dev.md（task-brief 调用 + model-tier + task_progress）+ test_model_tier.bats</name>
  <read_files>
    flow-kit-bundle/flow-kit/prompts/4-dev.md  <!-- 既有 721 行 -->
    flow-kit-bundle/flow-kit/scripts/task-brief  <!-- T02 产出 -->
    flow-kit-bundle/flow-kit/reference/narration-constraint.md  <!-- T04 -->
    flow-kit-bundle/flow-kit/templates/TASK.md  <!-- 既有（T10 会加 model-tier） -->
    .specs/adr/015-task-progress-schema.md
    .specs/adr/016-model-tier-dispatch.md
    .specs/superpowers-v6-absorb/DESIGN.md  <!-- D8/D9/D10 -->
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/prompts/4-dev.md
    test/test_model_tier.bats
  </write_files>
  <action>
    改造既有 4-dev.md（721 行 → 目标 ~500 行）：
    1. 顶部加 narration-constraint.md @see 引用
    2. 入场加载段：把"读整个 TASK.md"改为"读 task-brief 输出"（脚本调用 + Read 单 task 块）
    3. 加 model-tier 解析段：
       - 入场 jq 读当前 task 的 model-tier 属性
       - 旧 TASK.md（无 model-tier）→ fallback standard（AC-E1）
       - 调度 subagent 时显式声明 model（按 tier_model_map：cheap=flash, standard=pro, top=glm-5.2）
       - 写 dispatch prompt 时含 `[MODEL-TIER hint]: <tier>` 行（AC-E3b，grep-verifiable）
    4. § 6 完成 task 时加 task_progress 写入段：
       - jq append `.flow-active.goal.task_progress += [{id, commit_sha, fix_rounds, deferred[], completed_at}]`
       - 字段集严格匹配 ADR-015 schema（5 字段，无扩展）
       - 旧 .flow-active（无 task_progress）→ fallback []（AC-F1）
    5. 加 severity gating 引用（Minor findings 写 MINOR-DEFERRED.md，AC-D2）
    6. 加 Phase 2 L2 R2 兼容性检查：写完后 grep 确认 33-flow-active-integrity hook 兼容（旧 .flow-active 无 task_progress 字段不报错）
    保留：TDD 流程、grep-before-code、5-submit、8 checkpoint、brooks-lint 自检、PCSC、Pipeline Toll-Gate、独立 review 调度段。
    同时写 test_model_tier.bats（≥4 tests）：
    - model-tier=cheap → dispatch prompt 含 [MODEL-TIER hint]: cheap
    - model-tier=standard → hint standard
    - 旧 TASK.md 无 model-tier → fallback standard
    - 4-dev.md grep 含 task_progress jq 模板
    - AC-F4 向后兼容：旧 .flow-active（无 task_progress 字段）jq 不报错，fallback 为 []
  </action>
  <verify>cd /home/hellrabbit/unisoc/flow-kit && npx bats test/test_model_tier.bats && grep -q "task-brief" flow-kit-bundle/flow-kit/prompts/4-dev.md && grep -q "task_progress" flow-kit-bundle/flow-kit/prompts/4-dev.md && grep -q "MODEL-TIER hint" flow-kit-bundle/flow-kit/prompts/4-dev.md</verify>
  <done>4-dev.md 用 task-brief + 含 model-tier 解析 + 含 task_progress 写入 + bats 全绿（AC-E1 / AC-E2 / AC-E3a/E3b / AC-F1 / AC-F2 / AC-F4 / AC-B4）</done>
  <depends_on>T02</depends_on>
</task>

<task id="T09" parallel="true" status="done" model-tier="standard">
  <name>3-task.md 加 plan-conflict-scan + 5-test.md / 7-integration.md 加 terse/narration</name>
  <read_files>
    flow-kit-bundle/flow-kit/prompts/3-task.md  <!-- 既有 250 行 -->
    flow-kit-bundle/flow-kit/prompts/5-test.md  <!-- 既有 471 行 -->
    flow-kit-bundle/flow-kit/prompts/7-integration.md  <!-- 既有 364 行 -->
    flow-kit-bundle/flow-kit/reference/terse-contract.md  <!-- T03 -->
    flow-kit-bundle/flow-kit/reference/narration-constraint.md  <!-- T04 -->
    .specs/adr/017-severity-gating-protocol.md
    .specs/superpowers-v6-absorb/DESIGN.md  <!-- D10 -->
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/prompts/3-task.md
    flow-kit-bundle/flow-kit/prompts/5-test.md
    flow-kit-bundle/flow-kit/prompts/7-integration.md
  </write_files>
  <action>
    改造 3 个 prompt：
    A) 3-task.md 末段（自检前）加 plan-conflict-scan 子步骤（约 20 行）：
       - 扫 TASK.md 内部矛盾（同 task id 重复 / depends_on 引用不存在的 task / verify 不可执行）
       - 扫 TASK.md 与 CONTEXT.md 禁动清单冲突（write_files 含禁动文件）
       - 扫 TASK.md 与既有 ADR 冲突（设计违反已锁决策）
       - 冲突一次性 batch 输出给用户，不逐条 interrupt
       - 无冲突 → 输出"✅ plan-conflict-scan 通过"
    B) 5-test.md 顶部加 narration-constraint.md @see 引用 + terse-contract.md @see 引用
    C) 7-integration.md 顶部加同样两个 @see 引用 + 在归档段加"扫描 .specs/<id>/MINOR-DEFERRED.md → 提示用户 triage"
    保留各 prompt 既有结构、PCSC、Toll-Gate、独立 review 调度段。
  </action>
  <verify>cd /home/hellrabbit/unisoc/flow-kit && grep -q "plan-conflict-scan" flow-kit-bundle/flow-kit/prompts/3-task.md && grep -q "terse-contract.md" flow-kit-bundle/flow-kit/prompts/5-test.md && grep -q "narration-constraint.md" flow-kit-bundle/flow-kit/prompts/5-test.md && grep -q "terse-contract.md" flow-kit-bundle/flow-kit/prompts/7-integration.md && grep -q "narration-constraint.md" flow-kit-bundle/flow-kit/prompts/7-integration.md && grep -q "MINOR-DEFERRED" flow-kit-bundle/flow-kit/prompts/7-integration.md</verify>
  <done>3-task 含 plan-conflict-scan + 5-test/7-integration 含 terse/narration 引用（AC-G1 / AC-G2 / AC-C1 / AC-C2 部分）</done>
  <depends_on>T03, T04</depends_on>
</task>

<task id="T10" parallel="true" status="done" model-tier="cheap">
  <name>templates/TASK.md 加 model-tier 属性</name>
  <read_files>
    flow-kit-bundle/flow-kit/templates/TASK.md  <!-- 既有 88 行 -->
    .specs/adr/016-model-tier-dispatch.md
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/templates/TASK.md
  </write_files>
  <action>
    改造 templates/TASK.md：
    1. 在 `<task id="T01" parallel="true" status="done">` 行加 model-tier 属性：
       `<task id="T01" parallel="true" status="done" model-tier="standard">`
    2. 在状态字段说明段加 model-tier 解释：
       - model-tier="cheap" — 1-2 文件 / 简单修改 / 类型 fix
       - model-tier="standard" — 多文件 / 标准功能
       - model-tier="top" — 架构 / review / 复杂逻辑
       - 缺省 → fallback standard（向后兼容）
    3. 注释段加："<!-- model-tier 决定调度时使用的模型 tier，详见 ADR-016 -->"
    4. 既有占位 task 块都加上 model-tier 属性（保持示例完整）
  </action>
  <verify>grep -q "model-tier" flow-kit-bundle/flow-kit/templates/TASK.md && grep -q "cheap\|standard\|top" flow-kit-bundle/flow-kit/templates/TASK.md</verify>
  <done>template 含 model-tier 属性 + 三 tier 解释（AC-E1 准备 / AC-E2）</done>
  <depends_on></depends_on>
</task>

<task id="T11" parallel="false" status="done" model-tier="standard">
  <name>GO.md 压缩 + test_go_routing.bats</name>
  <read_files>
    flow-kit-bundle/flow-kit/GO.md  <!-- 既有 473 行 -->
    flow-kit-bundle/flow-kit/reference/loading-artifacts.md  <!-- T05 产出 -->
    .specs/adr/018-go-md-bootstrap-compression.md
    .specs/superpowers-v6-absorb/DESIGN.md  <!-- D11 -->
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/GO.md
    test/test_go_routing.bats
  </write_files>
  <action>
    按 ADR-018 压缩 GO.md（473 → ~338 行）：
    1. 删除段（约 53 行）：
       - "真实成本影响因子（让估算更准）" 段（~20 行描述性）
       - "用户视角的取舍" 段（~15 行）
       - "3.3 为什么这步重要" 段（~10 行，理由一句话并入 3.2 末尾）
       - "可选 runtime adapter 检测" 段（~8 行，adapter 已废弃）
    2. 压缩段（约 82 行）：
       - "典型 token 成本表" 压缩为单行参考（保留数字，删周边说明，~30 行）
       - "何时不必跑这段" 3 行精简为 1 行（~2 行）
       - "加载工件" 操作指令移到 loading-artifacts.md，GO.md 仅留 @see 引用（~25 行）
       - "查 reference 某一节的实际动作示例" 移到 loading-artifacts.md（~15 行）
       - "Fallback 路由（mode=fallback · P1-3/F5 修复）" 技术债务说明压缩到 2 行（~10 行）
    3. 保留所有强制 gate 段（Token 预算红线 / Artifact Preflight / Phase Completion Gate / 路由主段 / 老项目检测主段 / 显式声明 / 执行 prompt / 6.0 Goal 检测）
    4. routing 逻辑零变更（10 个 intent 测试断言）
    同时写 test_go_routing.bats（≥10 tests）：
    - 10 个用户 intent（"加新功能"/"修 bug"/"重构"/"测试"/"review"/"上线"/"归档"/"继续"/"下一个 task"/"pause"）断言压缩前后路由结果一致
    - 用 grep GO.md 关键段方式断言（不是真实 LLM 调用）
    - 断言 GO.md 行数 ≤350（AC-H1）
    - 断言 loading-artifacts.md @see 引用存在
  </action>
  <verify>cd /home/hellrabbit/unisoc/flow-kit && npx bats test/test_go_routing.bats && lines=$(wc -l < flow-kit-bundle/flow-kit/GO.md) && [ "$lines" -le 350 ] && echo "GO.md: $lines lines (≤350 ✓)"</verify>
  <done>GO.md ≤350 行 + 路由测试 10 intents 全绿 + 强制 gate 段保留（AC-H1 / AC-H2 / AC-I1）</done>
  <depends_on>T05, T10</depends_on>
</task>

<task id="T12" parallel="false" status="done" model-tier="standard">
  <name>package-flow-kit.sh Part D 加 scripts/ + 文档同步 + 禁动例外声明</name>
  <read_files>
    package-flow-kit.sh  <!-- 既有打包脚本，禁动清单 Part A-E/G -->
    flow-kit-bundle/install.sh  <!-- 安装脚本，可能需要同步 -->
    .specs/CONTEXT.md  <!-- 禁动清单原句"Part A-E/G 禁顺手改" -->
    .specs/superpowers-v6-absorb/DESIGN.md  <!-- § 0.5.1 Part D 例外说明 -->
    README.md
    FLOW-KIT-用户指南.md
    .specs/CHANGELOG.md
  </read_files>
  <write_files>
    package-flow-kit.sh  <!-- 仅 Part D 改动，Part A-C/E/G 不动 -->
    .specs/CONTEXT.md  <!-- 加禁动例外声明 -->
    .specs/CHANGELOG.md  <!-- 加本 change 条目 -->
    README.md  <!-- 若有 scripts/ 段需同步 -->
  </write_files>
  <action>
    1. package-flow-kit.sh Part D（flow-kit 内容 cp 段）加 `cp flow-kit-bundle/flow-kit/scripts/* "$STAGE_DIR/flow-kit/scripts/"` 或 rsync 等价命令
       - 仅 Part D 改，Part A-C/E/G 不动（Phase 2 L2 R1 修复：CONTEXT.md 加禁动例外）
       - mkdir -p "$STAGE_DIR/flow-kit/scripts/"
    2. .specs/CONTEXT.md 禁动清单加例外声明：
       - 在 "package-flow-kit.sh（打包脚本核心逻辑，改动影响分发流程）" 条目下加：
         `- 例外（superpowers-v6-absorb · 2026-08-02）：Part D 允许新增 scripts/ 到 cp 清单`
    3. .specs/CHANGELOG.md 加条目（紧凑单行 pipe 格式）：
       `| 2026-08-02 | superpowers-v6-absorb | 吸收 superpowers v6.0 经验：review-package + task-brief + terse + narration + severity + model-tier + plan-conflict-scan + GO.md 压缩 | 待 phase 5 补 LESSONS |`
    4. install.sh 若有 scripts/ 安装路径需求则同步（预期不需要，scripts/ 通过 flow-kit/ 整体 cp 自动带）
    5. README.md 若提及 scripts/ 目录则同步（预期不需要，README 不细化到 scripts/）
  </action>
  <verify>cd /home/hellrabbit/unisoc/flow-kit && grep -q "scripts/" package-flow-kit.sh && grep -q "superpowers-v6-absorb.*例外" .specs/CONTEXT.md && grep -q "superpowers-v6-absorb" .specs/CHANGELOG.md && bash -n package-flow-kit.sh</verify>
  <done>Part D 含 scripts/ cp + CONTEXT.md 禁动例外登记 + CHANGELOG 加条目 + bash 语法检查通过（AC-I2 / Phase 2 L2 R1 修复）</done>
  <depends_on>T01, T02, T11</depends_on>
</task>
```

---

## 状态字段说明

- `status="done"` — 未开始
- `status="in_progress"` — 进行中（同时只允许一个非 [P] 任务为此状态）
- `status="done"` — 已完成（verify 通过）
- `status="blocked"` — 阻塞（必须在文件末尾「阻塞日志」记录）

## model-tier 字段说明（新 · ADR-016）

- `model-tier="cheap"` — 1-2 文件 / 简单修改 / 类型 fix → 调度到 flash 模型
- `model-tier="standard"` — 多文件 / 标准功能 → 调度到 pro 模型
- `model-tier="top"` — 架构 / review / 复杂逻辑 → 调度到 glm-5.2 / 顶级模型
- 缺省 → fallback standard（向后兼容，旧 TASK.md 无 model-tier 属性时）

---

## 阻塞日志

| 任务 | 阻塞原因 | 待人工决策项 | 时间 |
|---|---|---|---|
|  |  |  |  |

---

## Phase 2 L2 R1-R4 必检项映射

> Phase 2 L2 盲审 4 🟡 Major finding 在 phase 4 实施时必检，对应到本 TASK.md 任务：

- **R1（package-flow-kit.sh Part D 禁动例外）** → T12 处理
- **R2（33-flow-active-integrity hook + task_progress 兼容性测试）** → T08 处理（task_progress 写入逻辑 + bats）
- **R3（token 削减因果链薄弱）** → 留待 phase 7-integration 实测后 CHANGELOG 说明
- **R4（D1 命名"4轮→1轮" vs AC-B2"独立第2轮"冲突）** → T07 处理（措辞改"1~2 轮"）

## Fix 任务（来自 REVIEW / INTEGRATION）

> 此区域由 review/integration 阶段自动追加，编号 `T-FIX-XX`。

```xml
<!-- 占位 -->
```
