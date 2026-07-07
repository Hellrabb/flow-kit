# 独立审查 · 阶段 3

---

## L2 盲审（独立审查员 · 2026-07-06）

> 审查工件：`.specs/user-guide-update/TASK.md`（参考 REQUIREMENT.md、DESIGN.md、CONTEXT.md、CHANGE.md）
> 审查重点：任务粒度、依赖链无环性、verify 可机器执行性、AC 覆盖完整性、禁动清单合规

---

### 🔴 R1 · T01 write_files 声明与 action 矛盾：空声明但依赖产物写入

**Symptom（症状）**：TASK.md:36-37 — `<write_files>` 块声明 `<!-- 只读调研，不写文件 -->`（空列表），但 `<action>` 段（行 45）明确要求"输出为结构化功能清单（写入临时文件 .specs/user-guide-update/.feature-checklist.md）"。下游 T03 的 `<depends_on>` + `<read_files>`（行 75-76）依赖此文件。

**Source（源头）**：TASK.md 格式约定要求 `<write_files>` 声明本任务所有写入目标，确保依赖追踪和禁动检查可审计。声明与实际行为不一致，破坏下游任务的合法性——若执行引擎强制执行 `write_files` 白名单，T01 写入将被拦截，T03 将因缺失输入而失败。

**Consequence（后果）**：若执行层严格按 `write_files` 白名单放行，T01 产物无法落地，T03 阻塞，整个 Wave 2-4 级联失效。即使执行层宽松，此矛盾也使 TASK.md 自文档化能力失效——读者无法从 `write_files` 判断真实产出。

**Remedy（修补）**：
```xml
<!-- Before (T01 write_files, line 36-37) -->
<write_files>
  <!-- 只读调研，不写文件 -->
</write_files>

<!-- After -->
<write_files>
  .specs/user-guide-update/.feature-checklist.md
</write_files>
```

---

### 🔴 R2 · T02 write_files 声明与 action 矛盾：同 T01

**Symptom（症状）**：TASK.md:56-58 — `<write_files>` 声明为空，但 `<action>` 段（行 65）要求"输出章节更新计划（写入临时文件 .specs/user-guide-update/.section-plan.md）"。verify（行 66）依赖此文件存在。

**Source（源头）**：与 R1 同源——TASK.md 格式约定要求 `<write_files>` 声明与任务实际写入一致。

**Consequence（后果）**：与 R1 相同——执行引擎若放行白名单，下游 T03 缺失 .section-plan.md 输入；读者无法从声明了解真实文件操作。

**Remedy（修补）**：
```xml
<!-- Before (T02 write_files, line 57-58) -->
<write_files>
  <!-- 只读调研，不写文件 -->
</write_files>

<!-- After -->
<write_files>
  .specs/user-guide-update/.section-plan.md
</write_files>
```

---

### 🔴 R3 · T09 verify 无法证伪：grep 过滤吞掉 bats 失败退出码

**Symptom（症状）**：TASK.md:259 — `verify` 命令为：
```bash
npx bats test/test_checkpoint.bats --formatter tap 2>&1 | grep -E "^ok|^not ok"
```
`grep -E "^ok|^not ok"` 匹配 TAP 的 "ok" 或 "not ok" 行。当测试全部失败时，输出充满 "not ok" 行，grep 匹配成功 → 退出码 0 → verify 通过。唯一使 verify 失败的情况是 bats 完全无 TAP 输出（如文件为空、bats 未安装）。该 verify 无法区分"6 条全通过"和"6 条全失败"。

**Source（源头）**：Stage 3 checklist 要求"每条 verify 是否可机器执行（非'人工确认'空话）"。机器可执行性包含证伪能力——verify 必须在产物不合格时返回非零退出码。当前 verify 可机器执行但不可证伪，等效于"总是通过"，违背后验收准则的 gate 功能。

**Consequence（后果）**：checkpoint-lib.sh 的单元测试全部失败时，T09 依然会标记 `status="done"`。坏代码进入下游 T07/T08，依赖方基于有 bug 的 lib 构建，风险在 T11 全量回归时才暴露——但 T11 的 verify（行 306）同样不可证伪（见 R4），形成双层盲区。

**Remedy（修补）**：
```bash
# Before (T09 verify)
npx bats test/test_checkpoint.bats --formatter tap 2>&1 | grep -E "^ok|^not ok"

# After — 方案 A：直接依赖 bats 退出码
npx bats test/test_checkpoint.bats --formatter tap

# After — 方案 B：保留 TAP 输出但严格检查无失败
npx bats test/test_checkpoint.bats --formatter tap 2>&1 | tee /dev/stderr | grep -q "^not ok" && exit 1 || exit 0
```

---

### 🔴 R4 · T11 verify 无法证伪：管道吞掉 bats 退出码

**Symptom（症状）**：TASK.md:306 — `verify` 命令为：
```bash
npx bats test/ 2>&1 | tail -5
```
`tail -5` 永远返回退出码 0（只要读取到任何输入），bats 的实际退出码被管道丢弃。全量回归测试全部失败时，verify 依然通过。

**Source（源头）**：与 R3 同源——verify 的证伪能力是 Stage 3 审查的核心质量属性。T11 是最终验证任务，其 verify 是全部 AC-1~AC-6 的最后一道自动化 gate。该 gate 不可证伪 = 整个 change 的质量闸门形同虚设。

**Consequence（后果）**：全量回归失败时 change 仍可被标记 `done`。所有 AC 的自动化验证失去最后防线。结合 R3（T09 verify 同样不可证伪），整个测试体系的可信度崩塌。

**Remedy（修补）**：
```bash
# Before (T11 verify)
npx bats test/ 2>&1 | tail -5

# After — 运行 bats 且保留退出码，同时输出最后 5 行供人工阅读
npx bats test/ 2>&1 | tee /dev/stderr | tail -5 > /dev/null; exit ${PIPESTATUS[0]}
# 或简化：
npx bats test/
```
> 注：T11 的 `<action>` 描述 7 步验证（文档对照、场景模拟、命令执行等），但其 `<verify>` 仅覆盖第 7 步（bats 回归）。verify 应至少追加一项文档一致性检查（如 grep 关键功能在 3 份文档的存在性），以部分覆盖 action 声称的验证范围。当前 verify 与 done 准则之间缺口过大。

---

### 🟡 R5 · AC-3 触发器 4（toll-gate 暂停）的任务覆盖存在缺口

**Symptom（症状）**：AC-3 定义 4 种 auto-checkpoint 触发条件，其中触发器 4 为"toll-gate 用户选择'暂停'（选项 2）"。T07 的 `<action>` 段（行 211）仅提及"PCSC 末尾追加 auto_advance 分支的 checkpoint 触发说明"——而 toll-gate 暂停是 auto_advance 的**对偶路径**（auto_advance=true 时跳过暂停，直接 transition；auto_advance=false 时用户可在 toll-gate 选择暂停）。T07 未显式覆盖"用户选择暂停"这一分支的 checkpoint 写入指令。

**Source（源头）**：REQUIREMENT.md AC-3（行 38-46）明确列出 4 种触发条件，DESIGN.md 数据流图（行 97-100）同样将"toll-gate 暂停"列为 prompt 层四大触发路径之一。T07 作为 prompt 层 auto-checkpoint 的唯一实现任务，<action> 段未提及此分支，构成规格→实现的映射缺口。

**Consequence（后果）**：若执行 T07 的 AI 仅按 `<action>` 描述实现（auto_advance 分支的 checkpoint），toll-gate 暂停场景下 AC-3 触发器 4 可能未被实现。Hook 层（T08）的 PreToolUse 兜底无法覆盖 toll-gate 暂停——用户选择暂停时无工具调用发生，PreToolUse hook 无拦截点。AC-3 的 4 种触发器中，触发器 4 缺少双层防护的 hook 层兜底（仅靠 prompt 层），而 prompt 层 T07 的 action 描述未明确覆盖。风险：中等——即使未显式覆盖，通用 PCSC 自检指令仍可提示 AI 在 toll-gate 暂停时写 checkpoint，但无显式指令可能被弱模型跳过。

**Remedy（修补）**：T07 `<action>` 段末尾追加一行：
```
- toll-gate 暂停分支的 checkpoint 触发说明（用户选择选项 2 后，AI MUST 执行 checkpoint_write）
```
同时考虑在 T08 的 action 中增加对 AskUserQuestion（用户交互工具）的检测，作为 hook 层对触发器 4 的兜底。

---

### 🟡 R6 · T07 + T08 + T10 的 parallel 标记与依赖关系不一致，浪费并行度

**Symptom（症状）**：TASK.md Wave 3 中，T07（`parallel="false"`, depends_on=T06）、T08（`parallel="false"`, depends_on=T06）、T10（`parallel="false"`, depends_on=T06）三者均仅依赖 T06，互不依赖。但三者均标记 `parallel="false"`，导致在同一 wave 内必须顺序执行。T07 修改 15 个 prompt 文件（`~/.claude/flow-kit/prompts/`），T08 修改 PreToolUse hook（`~/.claude/flow-kit/hooks/stop/`），T10 修改 GO.md（`~/.claude/flow-kit/prompts/GO.md`）——三者的写入目标无交集，无竞争条件。

**Source（源头）**：TASK.md 波次划分注释"同 wave = 可并行；跨 wave = 必须顺序执行"。T07/T08/T10 同属 Wave 3 且均只依赖 T06，符合可并行条件。`parallel="false"` 标记与波次并行语义矛盾。

**Consequence（后果）**：当前编排下 Wave 3 的关键路径 = T06 完成后 → T07（5-10min）→ T08（5-10min）→ T10（3-5min），总计 13-25min。若三者标记 `parallel="true"`，关键路径 = T06 完成后 → max(T07, T08, T10) ≈ 5-10min。执行时间增加约 2-3 倍，对快速迭代周期产生可感知的影响。

**Remedy（修补）**：
```xml
<!-- Before -->
<task id="T07" parallel="false" status="pending">
<task id="T08" parallel="false" status="pending">
<task id="T10" parallel="false" status="pending">

<!-- After -->
<task id="T07" parallel="true" status="pending">
<task id="T08" parallel="true" status="pending">
<task id="T10" parallel="true" status="pending">
```
同时更新 Wave 3 描述：`T07[P], T08[P], T09[P], T10[P] (depends on T06)`。

---

### 🟡 R7 · T11 verify 与 done 准则的覆盖差距过大

**Symptom（症状）**：T11 的 `<done>` 准则（行 307）声明"全部 AC 验证通过，bats 全量回归 0 fail，三份文档内容一致无矛盾"。但 `<verify>`（行 306）仅执行 `npx bats test/ 2>&1 | tail -5`，仅覆盖"bats 全量回归"的子集（且不可证伪，见 R4），完全未覆盖 AC-1~AC-6 的逐项验证和三份文档一致性检查。

**Source（源头）**：Stage 3 checklist 要求"所有 AC 是否有对应 task？"——已满足（AC-1~AC-6 各有任务覆盖）。但 checklist 进一步要求 verify 可验证对应 task 的 done 条件。T11 作为最终验证任务，其 verify 应至少部分覆盖文档一致性（AC-1）和 checkpoint 字段格式（AC-3）的自动化检查。

**Consequence（后果）**：T11 标记 done 时，AI 可能仅跑了 bats 测试（甚至 bats 的失败被管道吞掉），而文档一致性、AC 场景模拟等人工验证步骤可能被跳过。change 可能以未完成状态被归档。

**Remedy（修补）**：T11 verify 追加至少一项文档一致性自动化检查：
```bash
npx bats test/ && \
  for doc in FLOW-KIT-用户指南.md README.md flow-kit-ecosystem-guide.md; do
    grep -q "checkpoint\|interrupt" "$doc" || { echo "MISSING checkpoint in $doc"; exit 1; }
  done && \
  echo "OK: All docs contain checkpoint/interrupt references"
```
这样可以部分覆盖 AC-1 的核心关键词存在性（虽不能替代人工逐项对照，但提供了自动化门禁）。

---

### 🟢 R8 · T10 对 T06 的依赖为软依赖，可进一步放宽并行度

**Symptom（症状）**：T10（更新 GO.md）声明 `<depends_on>T06</depends_on>`（行 281），但 T10 的 `<read_files>`（行 267）仅含 `~/.claude/flow-kit/prompts/GO.md`，不读取 T06 产物 `hooks/stop/lib/checkpoint-lib.sh`。GO.md 的 interrupt 恢复逻辑复用既有 `.flow-active.interrupt` 字段——这些字段格式已在 DESIGN D5 中定义，不依赖 checkpoint-lib.sh 的实现细节。

**Source（源头）**：依赖链应仅包含技术依赖（A 读取 B 的产物，或 A 的行为语义由 B 定义）。T10→T06 是概念/语义依赖（"两者都与 checkpoint 相关"），非技术依赖。

**Consequence（后果）**：无功能影响——T10 排在 T06 之后执行不会出错。但若 T06 阻塞，T10 也被不必要地阻塞。影响微小——仅增加 ~5min 延迟，且 T06 阻塞概率低。

**Remedy（修补）**：将 T10 的 `depends_on` 清空或改为仅依赖 GO.md 的存在性（无前置任务）。或者将 T10 标记 `parallel="true"` 放入 Wave 2（与 T06 并行）。
```xml
<task id="T10" parallel="true" status="pending">
  <depends_on></depends_on>
```
> 若选择保持 T10 依赖 T06（保守策略），至少应在 `<action>` 中注明依赖理由。

---

### 🟢 R9 · T07 verify 使用 GNU grep 特有的 `\|` 交替语法，POSIX 环境下失效

**Symptom（症状）**：T07 verify（行 213）：
```bash
for f in ~/.claude/flow-kit/prompts/*.md; do grep -q "auto-checkpoint\|interrupt.checkpoint_at" "$f" || echo "MISSING: $f"; done | (! grep .)
```
`grep -q "auto-checkpoint\|interrupt.checkpoint_at"` 中 `\|` 是 GNU grep 在 BRE 模式下的交替扩展。在严格 POSIX BRE 实现（如 macOS/BSD grep）下，`\|` 被解释为字面量 `|`，导致模式无法匹配任何目标文本，所有 15 个文件均被报告 MISSING，verify 失败。

**Source（源头）**：Portable Shell 编程规范——grep 交替应使用 `-E`（ERE）标志，或拆分为两次 `grep -e` 调用。项目已有 shellcheck 集成（`make lint`，仅 error 级别），但未配置 SC 规则覆盖 POSIX 可移植性。

**Consequence（后果）**：在 macOS 开发环境或 BSD 系统上，T07 verify 持续误报，任务无法完成。Linux 环境（含 CI）不受影响。影响面有限——当前项目在 Linux 上开发。

**Remedy（修补）**：
```bash
# Before
grep -q "auto-checkpoint\|interrupt.checkpoint_at" "$f"

# After (option A — add -E for ERE)
grep -qE "auto-checkpoint|interrupt\.checkpoint_at" "$f"

# After (option B — two -e patterns, fully POSIX)
grep -q -e "auto-checkpoint" -e "interrupt.checkpoint_at" "$f"
```

---

### 🟢 R10 · T03 粒度可能超 200 行变更阈值

**Symptom（症状）**：T03 `<action>`（行 82-93）要求编写/更新 6 大类章节——gate_config、pipeline goal、auto_advance+fallback、独立审查、interrupt/checkpoint 专项、其他增量。目标文件 FLOW-KIT-用户指南.md 当前 50KB。每类章节预计 20-50 行，总变更量可能 200-400 行。

**Source（源头）**：Stage 3 checklist 要求"单 task 是否 ≤ 200 行变更？"。该阈值旨在控制 review 粒度——单 task 过大时 review 负担重、回滚风险高。文档类任务的行数阈值可比代码宽松，但 200+ 行跨 6 个主题的文档变更仍属于大粒度。

**Consequence（后果）**：无功能风险（文档写入是幂等的）。但若 T03 中途失败，已写入的章节与未写入的章节混合在同一个 FLOW-KIT-用户指南.md 中，恢复时需要人工判断哪些章节已完成。拆分 T03 为 2-3 个子任务可降低此风险。

**Remedy（修补）**：可考虑将 T03 拆分为：
- T03a：gate_config + pipeline goal 章节
- T03b：auto_advance + fallback + 独立审查章节
- T03c：interrupt/checkpoint 专项 + 其他增量 + 最后同步日期

但鉴于文档变更的特性（原子性低、回滚容易），当前粒度可接受。**此项为建议，非强制**。

---

### 🟢 R11 · T08 read_files 与 write_files 路径风格不一致

**Symptom（症状）**：T08 `<read_files>`（行 219-220）使用项目相对路径（`hooks/stop/lib/checkpoint-lib.sh`、`.claude/hooks/stop-hook.json`），而 `<write_files>`（行 224）使用绝对路径 `~/.claude/flow-kit/hooks/stop/independent-review-gate.sh`。

**Source（源头）**：项目未在 TASK.md 格式约定中统一路径风格。其他任务（T07、T10）的 write_files 使用 `~/.claude/...` 绝对路径，read_files 混用相对/绝对路径。

**Consequence（后果）**：无功能影响，但降低 TASK.md 作为执行指令的可读性——执行者需在两种路径约定之间切换心智模型。

**Remedy（修补）**：统一 T08 read_files 为绝对路径风格（与 write_files 一致）：
```xml
<read_files>
  ~/.claude/flow-kit/hooks/stop/lib/checkpoint-lib.sh
  ~/.claude/hooks/stop-hook.json
</read_files>
```
或统一所有任务的路径为项目根相对路径约定，在 TASK.md 头部注明。

---

## AC 覆盖矩阵

| 验收准则 | 覆盖任务 | 覆盖完整？ |
|---|---|---|
| AC-1（三份文档覆盖近期全部功能）| T01 → T02 → T03 + T04[P] + T05[P] + T11 | 完整 |
| AC-2（interrupt/checkpoint 专项章节，含 5 点）| T03（action 逐项列出）+ T11（人工确认）| 完整 |
| AC-3（auto-checkpoint 4 种触发时机）| T06（lib）+ T07（prompt 指令）+ T08（hook 兜底）+ T11（场景模拟）| 触发器 4 覆盖偏弱（见 R5），其余完整 |
| AC-4（auto 不干扰 manual checkpoint）| T06（lib dedup）+ T09（UT 覆盖）+ T11（场景测试）| 完整 |
| AC-5（中断恢复时上下文注入）| T10（GO.md 路由）+ T11（模拟验证）| 完整 |
| AC-6（文档与代码一致性）| T11（逐条执行验证）| 完整 |

---

## 禁动清单合规检查

| 禁动文件（来源） | 是否被 write_files 触碰？ | 状态 |
|---|---|---|
| `package-flow-kit.sh`（CONTEXT.md + DESIGN 0.5.1） | 否 | ✅ |
| `flow-kit-bundle.tar.gz`（CONTEXT.md + DESIGN 0.5.1） | 否 | ✅ |
| `.gitignore`（CONTEXT.md） | 否 | ✅ |
| `hooks/stop/lib/*.sh`（DESIGN 0.5.1 — 禁止修改现有 lib，如 correction-file.sh / l3-review.sh） | T06 创建**新**文件 `checkpoint-lib.sh`（非修改现有），DESIGN 0.5.1 明确列为"新增模块" | ✅ 合规 |
| `flow-kit-bundle/hooks/stop/2[7-9]-*.sh / 3[0-2]-*.sh`（DESIGN 0.5.1） | T08 修改 `~/.claude/flow-kit/hooks/stop/independent-review-gate.sh`（PreToolUse，非 27-32 号模块） | ✅ 合规 |

---

## 依赖图无环性

```
T01[P] ──┐
          ├──→ T03 ──┬──→ T04[P] ──┐
T02[P] ──┘          │   T05[P] ──┤
                    │              │
T06[P] ──┬──→ T07 ─┤              ├──→ T11
         ├──→ T08 ─┤              │
         ├──→ T09[P]              │
         └──→ T10 ─┴──────────────┘
```

- 依赖方向统一（左→右→下），无环
- T07/T08/T10 互不依赖，并行度可提升（见 R6）
- T10→T06 为软依赖（见 R8）

---

**Verdict**: **fail**

4 项 Critical 发现（R1~R4）必须修复——T01/T02 write_files 空声明破坏依赖溯源，T09/T11 verify 不可证伪导致质量闸门形同虚设。修复后方可 pass。

4 项 Major 发现（R5~R7）建议同步修复，以消除 AC 覆盖缺口和执行效率损失。3 项 Minor 建议（R8~R11）可在后续 sweep-fix 中处理。

---

## L3 盲审（deepseek-v4-flash[1m] 外部模型 · 2026-07-06 16:13）

> 自动生成于 2026-07-06 16:13。由 l3-review.sh 写入。

### 审查结论

```json
{"critical":[{"file":"T01","issue":"write_files声明为空但action要求写入.specs/user-guide-update/.feature-checklist.md","why":"write_files未声明该文件，但action明确写入临时文件，造成边界越界。若系统强制执行只写声明文件，后续任务无法依赖此文件。","fix":"在T01的write_files中添加.specs/user-guide-update/.feature-checklist.md"},{"file":"T02","issue":"write_files声明为空但action要求写入.specs/user-guide-update/.section-plan.md","why":"与T01相同，write_files未声明实际写入的目标文件。","fix":"在T02的write_files中添加.specs/user-guide-update/.section-plan.md"},{"file":"T09","issue":"verify不能证伪，使用grep过滤ok/not ok行掩盖了bats测试失败","why":"npx bats的输出通过grep查找ok或not ok行，即使测试失败（产生not ok）grep仍返回0，导致verify始终成功。","fix":"修改verify为直接检查bats退出码，例如：npx bats test/test_checkpoint.bats && ... 或使用grep -v 'not ok'后检查返回码"},{"file":"T11","issue":"verify不能证伪，使用tail -5忽略bats退出码","why":"npx bats test/的退出码被管道忽略，tail -5总返回成功，即使有测试失败verify也通过。","fix":"修改verify为直接使用npx bats test/ 2>&1并检查其退出码"}],"major":[{"file":"Wave 3","issue":"T07、T08、T10均标记parallel=false且相互无depends_on，但在同一波次中执行顺序不确定","why":"波次说明同wave可并行，但任务属性禁止并行且无顺序依赖，可能导致执行歧义或阻塞。","fix":"显式指定T07/T08/T10的depends_on顺序，或调整parallel属性为true（若无竞争条件）"},{"file":"T03","issue":"verify使用grep -c的交替符\\|可能不兼容POSIX BRE","why":"grep -c \"L2\\|L3\\|both\"在严格POSIX环境下可能不识别\\|，导致verify失效。","fix":"添加-E选项：grep -cE \"L2|L3|both\""}],"minor":[{"file":"T07","issue":"读取15个prompt文件，但write_files未包含所有提示文件（已声明，合理）","why":"无实质问题，仅检查一致性"},{"file":"T09","issue":"verify中npx bats命令假设bats已安装，但工件未确保环境","why":"审查假设标准环境，但潜在依赖缺失风险"}],"verdict":"fail","summary":"工件存在4个critical问题（write_files声明与实际写入不一致、verify不能证伪），故判定失败。major问题为并行任务顺序不明确及grep语法兼容性，需修正后方可pass。"}
```
