# REQUIREMENT: 吸收 superpowers v6.0 经验到 flow-kit

- **Change ID**: superpowers-v6-absorb
- **关联**: `@.specs/superpowers-v6-absorb/CHANGE.md`、`@.specs/CONTEXT.md`

---

## 用户故事

- **US-1**：作为 flow-kit 维护者，我想让 review phase 跑得更便宜，以便中型 change 的总 token 成本下降 25%+ 而质量不退。
  - **Traceability（结构性 AC 支撑，非空话）**：本故事由以下硬 AC 共同支撑——AC-B1（review 三轮合并为单次）、AC-B2/B3（spot-check 仅 Critical 触发而非每次）、AC-B4（task-brief 提取后 4-dev 有效负载 ≤15KB，对应当前 34KB/任务的削减）、AC-H1（GO.md 473→≤350 行）、AC-C1/C2（terse + narration 约束 -41%/-54% reviewer/controller output）。**结构性 AC 全过 = US-1 达成**；参考性 AC-J1/J2（端到端 token 测量）作证但不卡 toll-gate（端到端 token 测量误差大，依据 §范围决策框）
- **US-2**：作为 flow-kit 用户，我想 4-dev 阶段每个 task 的 prompt 加载量减半，以便 >5 task 的大 change 不再因为 per-task reload 占 40% 预算而失控。
- **US-3**：作为 flow-kit 维护者，我想让 reviewer 输出受结构化 schema 约束，以便 L2/L3 review 报告可机器解析、可对照、不啰嗦。
- **US-4**：作为 flow-kit 用户，我想 severity gating 自动把 Minor finding 延后到最终审查，以便单 task 不被 style nit 卡住 fix loop。
- **US-5**：作为 flow-kit 维护者，我想 progress ledger 在 compaction 后能恢复 per-task 状态，以便避免"重新分派已完成 task"这种最贵的失败。
- **US-6**：作为 flow-kit 用户，我想 TASK.md 能声明 model-tier，以便 mechanical task 自动走便宜 model 而不是 silently 继承 session 最贵 tier。

---

## 验收准则（AC）

> **范围决策（写 REQUIREMENT 时由我判断，可在 1→2 toll-gate 推翻）**：
> - **Token 测量协议**：结构性 + 参考性双轨。结构性 AC 是硬门槛（轮数、KB 数），参考性 AC 跑一次 pre/post 样例作证。
> - **Cross-model spot-check "加强"语义**：Critical-finding 触发（不每次跑）。
> - **task_progress vs T<N>-SUMMARY.md**：并存——task_progress = 机器读实时，SUMMARY = 人读事后。

### 类别 A · 新增脚本（G2 / G3）

#### AC-A1 · review-package 脚本存在且可用
- **Given** flow-kit-bundle/flow-kit/scripts/ 目录存在
- **When** 执行 `bash scripts/review-package <base> <head> <outfile>` 在任意 git 仓库
- **Then** `<outfile>` 含三段：`## Commits` (git log --oneline) / `## Files changed` (git diff --stat) / `## Diff` (git diff -U10)
- **验证方式**: `bash test/test_review_package.bats`（happy path）

#### AC-A1-ERR · review-package 非 git 目录错误路径
- **Given** 当前目录**非** git 仓库（无 `.git/`）
- **When** 执行 `bash scripts/review-package <base> <head> <outfile>`
- **Then** exit code ≠ 0，stderr 含可识别错误信息（如 `"review-package: not a git repository"` 或 `"fatal: not a git repository"`），且不产生 `<outfile>`
- **验证方式**: `bash test/test_review_package.bats` 的 error-path 用例（覆盖 set -euo pipefail 下 `git log` 返回非零的处理）

#### AC-A2 · task-brief 脚本存在且可用
- **Given** 一份合法 TASK.md（含 `<task id="T03">...</task>` XML 块）
- **When** 执行 `bash scripts/task-brief <TASK.md> T03 <outfile>`
- **Then** `<outfile>` 仅含 T03 block 的内容（不含其他 task，不含 TASK.md 头部）
- **验证方式**: `bash test/test_task_brief.bats`

#### AC-A3 · 脚本跨平台
- **Given** bash 4.4+ / awk mawk 或 gawk
- **When** 在 Linux 与 macOS（如可用）跑脚本
- **Then** 输出一致（行数差异 ≤ 1）
- **验证方式**: bats 测试 + CI（如有）

### 类别 B · Review phase 重构（G1 + spot-check 加强）

#### AC-B1 · 三轮合并为单次结构化审查
- **Given** prompts/6-review.md 已重构
- **When** review phase 跑完一次
- **Then** 产出单一 REVIEW.md，结构 = spec-compliance verdict → code-quality verdict → UI verdict → 综合评估（不再是 3 个独立 sub-section 各跑一次）
- **验证方式**: 人工 + grep `## Round 1` / `## Round 2` / `## Round 3` 不再出现

#### AC-B2 · Cross-model spot-check 保留为独立第 2 轮，Critical-finding 触发
- **Given** phase 6 第一轮合并审查完成
- **When** 综合评估含 ≥1 个 Critical finding
- **Then** 自动触发 cross-model spot-check（独立 subagent，外部模型盲审）
- **验证方式**: 人工 + hook 日志

#### AC-B3 · 不触发 spot-check 的情况
- **Given** phase 6 第一轮无 Critical finding
- **When** 综合评估为 pass
- **Then** spot-check 不跑（节省 ~10-15K tokens/change）
- **验证方式**: hook 日志 + .flow-active.goal.task_progress.spot_check_triggered = false

#### AC-B4 · task-brief 提取后 4-dev 有效负载 ≤ 15KB（结构性硬指标 · 对应 NFR）
- **Given** 一份典型 TASK.md（5 task，每 task XML block ~500-800 字节）
- **When** 执行 `bash scripts/task-brief <TASK.md> T03 /tmp/out_T03.txt`，并 cat `prompts/4-dev.md` + `/tmp/out_T03.txt`
- **Then** 合并内容字节数 ≤ 15360 字节（15KB）—— 4-dev.md 主体 + 当前 task 提取内容之和
- **验证方式**: `bash test/test_task_brief.bats` 含 size-budget 用例（`wc -c` 断言）

> **Addendum (final-debt-cleanup-2026-08 / L-066 fix · 2026-08-03)**:
> 
> 原版 AC-B4 仅测 task-brief 单独输出大小，未覆盖 task-brief + 4-dev.md **合并加载** 的真实 token 负载。
> 
> **新增测试**（`test/test_combined_metric.bats` · INT-COMBINED-1）：
> - `Given` 4-dev.md (352 lines post-compression) + task-brief 输出（典型 ~5KB）
> - `When` 测量两者合并字节大小
> - `Then` 合并大小 ≤20KB（token 预算友好阈值）
> 
> 此 addendum 不改变原版 AC-B4 的合规判定（已通过），仅补强测试深度。

### 类别 C · Terse contract + Narration constraint（G4 + G5）

#### AC-C1 · Reviewer prompt 顶部硬约束
- **Given** 所有 review 类 prompt（6-review.md / L2-blind-review.md / independent/*）
- **When** grep `"no preamble"` 或等价硬约束语句
- **Then** 命中（每文件至少 1 处）
- **验证方式**: `grep -r "no preamble\|verdict-first\|no closing summary" flow-kit-bundle/flow-kit/prompts/`

#### AC-C2 · Phase prompts 顶部 narration constraint
- **Given** 所有 phase prompts（0-change / 1-requirement / ... / 7-integration）
- **When** grep `"narrate at most one short line"` 或等价
- **Then** 命中（每文件顶部段至少 1 处）
- **验证方式**: `grep -r "narrate" flow-kit-bundle/flow-kit/prompts/`

### 类别 D · Severity gating（G6）

#### AC-D1 · Severity 三档分类
- **Given** 重构后的 review prompts
- **When** reviewer 输出 finding
- **Then** 每条 finding 必须标 `severity: Critical | Important | Minor`
- **验证方式**: grep REVIEW.md 输出格式

#### AC-D2 · Minor 入 ledger 延后
- **Given** review 发现 Minor finding
- **When** fix loop 判定是否进入
- **Then** Minor 不入 loop，写入 `.specs/<id>/MINOR-DEFERRED.md`（**单一固定路径**，hook 层可 grep 存在性检查；不再支持"T<N>-SUMMARY.md 的 deferred 段"等价路径）
- **验证方式**: bats 测试 `test -f .specs/<id>/MINOR-DEFERRED.md` + grep 内容含 finding 编号

#### AC-D3 · 旧 review 输出向后兼容
- **Given** 旧 REVIEW.md（无 severity 标签）
- **When** 解析器读
- **Then** 视为 Important（保守默认）
- **验证方式**: bats 测试

### 类别 E · TASK.md schema 扩展（G8）

#### AC-E1 · model-tier 属性支持
- **Given** TASK.md XML task 块
- **When** 解析
- **Then** 支持 `<task id="T03" model-tier="cheap|standard|top">` 属性
- **验证方式**: 4-dev.md 解析逻辑 + bats 测试

#### AC-E2 · 旧 TASK.md 向后兼容
- **Given** 旧 TASK.md（无 model-tier 属性）
- **When** 4-dev.md 解析
- **Then** fallback 到 `standard` tier
- **验证方式**: bats 测试

#### AC-E3 · model-tier 在 OpenCode 的实际生效路径（两条独立 AC · 不再延后到 DESIGN）

> 下列 E3a / E3b 是两条独立的 AC，DESIGN § 6 仅负责"实现哪一条 + 如何实现"，AC 本身在此处已完整可验证。

##### AC-E3a · OpenCode 支持 task-level model switching 时的生效断言
- **Given** DESIGN § 6 调研确认 OpenCode 支持 task-level model switching（API 或 task tool 字段）
- **When** 4-dev.md 派 task T03（含 `model-tier="cheap"` 属性）调度
- **Then** 实际调度的 task subagent 用 cheap-tier 模型（具体 API 字段或 task tool 参数由 DESIGN § 6 决定，但 AC 断言"cheap 模型生效"——可通过 transcript 中 subagent 元数据 `model` 字段为 cheap-tier 验证）
- **验证方式**: bats 测试注入 mock dispatcher，断言派发参数含 cheap-tier 模型 ID

##### AC-E3b · OpenCode 不支持 task-level model switching 时的 hint 格式契约
- **Given** DESIGN § 6 调研确认 OpenCode 不支持 task-level model switching
- **When** 4-dev.md 派 task T03（含 `model-tier="cheap"` 属性）调度
- **Then** dispatch prompt 含 hint 文本，**格式固定**为：`[MODEL-TIER hint]: 建议本 task 使用 cheap-tier 模型（<reason: 机械性 1-2 文件变更>）`。hint 位于 dispatch prompt 顶部段（首 10 行内），且可 grep `\[MODEL-TIER hint\]:` 提取
- **验证方式**: bats 测试 `grep -E "^\[MODEL-TIER hint\]:" <dispatch-prompt-text>`

### 类别 F · Progress ledger（G7）

#### AC-F1 · .flow-active schema 扩展
- **Given** 新 .flow-active schema
- **When** jq 检查
- **Then** `.goal.task_progress` 字段存在（数组，初始空）
- **验证方式**: `jq -e '.goal.task_progress' .flow-active`

#### AC-F2 · Task 完成自动追加
- **Given** task T03 完成（commit SHA abc1234，fix rounds = 2，deferred findings = ["M1", "M2"]）
- **When** 4-dev.md 完成时写
- **Then** `.goal.task_progress` 含 `{id:"T03", commit_sha:"abc1234", fix_rounds:2, deferred:["M1","M2"], completed_at:"<ISO>"}`
- **验证方式**: bats 测试 + 人工

#### AC-F3 · task_progress 与 T<N>-SUMMARY.md 职责划分 + 字段锁
- **Given** 两者并存
- **When** 查询
- **Then**：
  - `.flow-active.goal.task_progress[]` = 机器读、jq 友好、实时写、**字段锁**：仅允许 `{id, commit_sha, fix_rounds, deferred[], completed_at}` 5 字段，**禁止**新增字段（如 retry_count / estimated_tokens）；新字段需经新 ADR 批准
  - `.specs/<id>/T<N>-SUMMARY.md` = 人读、markdown、事后写、自由格式（"做了什么/为什么这么做/偏离 DESIGN 哪里"）
- **验证方式**: bats 测试断言 task_progress 数组每元素的字段集**完全等于** `["id","commit_sha","fix_rounds","deferred","completed_at"]`（用 `jq` 比对 keys 排序后等价）；DESIGN § 7 仅描述两者**写入时机**（task 完成时 vs 4-dev 完成时），不再定义字段集

#### AC-F4 · 旧 .flow-active 向后兼容
- **Given** 旧 .flow-active（无 task_progress 字段）
- **When** hook 读
- **Then** 视为 `[]`（空数组）
- **验证方式**: bats 测试

### 类别 G · Plan conflict scan（G9）

#### AC-G1 · phase 3 末段加冲突扫描子步骤
- **Given** TASK.md 已生成
- **When** phase 3 即将完成
- **Then** 跑一次 plan-conflict-scan：扫 TASK.md 内部矛盾 + 与 CONTEXT.md 禁动清单冲突 + 与既有 ADR 冲突
- **验证方式**: 3-task.md 末段含子步骤 + 实际产物

#### AC-G2 · 冲突批量呈现
- **Given** scan 发现 ≥1 个冲突
- **When** 输出
- **Then** 一次性 batch 给用户（不是每个冲突单独 interrupt）
- **验证方式**: 人工

### 类别 H · Bootstrap 压缩（G10）

#### AC-H1 · GO.md 体积削减
- **Given** 现 GO.md = 473 行 / ~30KB
- **When** 审计后压缩
- **Then** 行数 ≤ 350，bytes ≤ 22KB（削减 ≥25%）
- **验证方式**: `wc -l flow-kit-bundle/flow-kit/GO.md`

#### AC-H2 · 削减不破坏路由准确性
- **Given** 压缩后 GO.md
- **When** 跑 GO.md 路由测试（10 个代表性意图）
- **Then** 路由结果与压缩前一致
- **验证方式**: bats 测试（10 个 intent → expected phase）

### 类别 I · 测试覆盖（结构性硬指标）

#### AC-I1 · 新脚本 100% bats 覆盖
- **Given** scripts/review-package 和 scripts/task-brief
- **When** bats 跑
- **Then** exit code 0，覆盖核心路径（happy path + 边界）
- **验证方式**: `bash test/test_review_package.bats && bash test/test_task_brief.bats`

#### AC-I2 · 现有测试不退化
- **Given** test/ 下既有 bats 测试
- **When** 跑全套
- **Then** 通过率 = baseline（不引入新失败）
- **验证方式**: `bash test/run_all.bats`（或等价）

### 类别 J · 参考性指标（非硬门槛）

#### AC-J1 · Pipeline token 削减参考测量
- **Given** 一个固定样例 change（5 task 中型，DESIGN 阶段定义）
- **When** pre-change 跑一次 + post-change 跑一次
- **Then** post 总 token 比 pre 减少 ≥25%（参考值，不卡 toll-gate）
- **验证方式**: 在 7-integration 阶段记录两轮数据

#### AC-J2 · Review phase token 削减参考测量
- **Given** 同上样例 change
- **When** 对比 review phase 一轮
- **Then** post review token 比 pre 减少 ≥40%（参考值）
- **验证方式**: 同上

---

## 范围切分

### v1（本次必做 · G1-G10 全量）

- G1：review 三轮合并 + spot-check Critical 触发
- G2：scripts/review-package（46 行 bash）
- G3：scripts/task-brief（41 行 awk）
- G4：terse contract 加到所有 review prompts
- G5：narration constraint 加到所有 phase prompts
- G6：severity gating（Critical/Important/Minor 三档）
- G7：.flow-active.goal.task_progress per-task ledger
- G8：TASK.md XML 加 model-tier 属性 + OpenCode 生效路径验证
- G9：phase 3 末段 plan-conflict-scan
- G10：GO.md 审计压缩（473 → ≤350 行）

### v2（下一轮考虑，不本次）

- **基于 model-tier 的自动 model 切换 UI**——本次只在 dispatch prompt 注入 hint，UI 化的 tier 选择器留 v2
- **Severity 四档扩展（含 Info）**——本次三档够用，Info 留 v2
- **task_progress 的可视化工具**（jq query lib / CLI dumper）——本次字段先就位，工具化留 v2
- **plan-conflict-scan 的 LLM 增强**——本次只做规则扫描（grep / AST 匹配），LLM 判定留 v2

### out（永远不做）

- **不替换 flow-kit hook-driven enforcement 哲学**（保留 ADR-001 protect-the-weakest）
- **不引入 superpowers 周边设施**（bootstrap companion / sandboxed file server / per-session auth）
- **不引入 LLM-judged evals/ 子模块系统**（保留 bats）
- **不重写既有 13 个 ADR**（除非直接冲突）
- **不修改 brooks-lint 集成**（保持现状）
- **不引入 Codex / Kimi / Pi 等 harness 适配**（保持 vendor-neutral）

---

## 非功能性需求

- **性能**：
  - scripts/review-package 单次执行 ≤ 500ms（10 commit / 1000 行 diff 规模）
  - scripts/task-brief 单次执行 ≤ 100ms
  - 4-dev.md 加载后实际有效内容（task-brief 提取后）≤ 15KB
- **可访问性**：无（开发者工具，无 UI）
- **安全**：
  - 新增脚本不引入 shell injection（用 `--arg` 传参，禁止字符串拼接 eval）
  - task_progress 字段不存敏感数据（不存 prompt 全文 / 不存 token）
- **兼容性**：
  - bash 4.4+ / awk（mawk 或 gawk）
  - jq 1.6+
  - 旧 TASK.md / 旧 .flow-active / 旧 REVIEW.md 必须能跑（向后兼容 AC-E2/E4/D3）
- **可观测性**：
  - 新增脚本支持 `--debug` flag 输出中间步骤到 stderr
  - task_progress 字段可被 SessionStart hook 读取并展示在 resume banner

---

## 依赖与假设

- **依赖**：
  - flow-kit-bundle/ 现有结构（prompts/ + templates/ + scripts/ 新建）
  - 既有 bats 测试框架（test/）
  - jq / bash / awk / git（已有）
- **假设**：
  - OpenCode 环境的 task 调度 API 不会在本次 change 期间发生 breaking change
  - flow-kit 当前 13 个 ADR 与本次新增 ADR 不冲突（DESIGN § 0.5 验证）
  - 用户接受"参考性 token 测量不卡 toll-gate"的契约（结构性 AC 是硬门槛）

---

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
