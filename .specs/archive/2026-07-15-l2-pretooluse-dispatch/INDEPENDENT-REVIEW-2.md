# 独立审查 · 阶段 2

---

## L2 盲审

### 🟡 R1 · l2_detect_missing() 依赖膨胀未显式声明：auto_advance 检测使纯文件检查函数获得 `.flow-active` 读取依赖

**Symptom**：DESIGN.md § 9.3 声明 `l2_detect_missing()` 新增返回码 3（auto_advance 模式），§ 0.5.2 标注"沿用，扩展返回值"。但当前实现（`l2-detect.sh:19-32`）仅检查 `INDEPENDENT-REVIEW-<phase>.md` 文件是否含 `## L2 盲审` 段——不读 `.flow-active`，不依赖 jq。新增 auto_advance 检测（DESIGN.md D4："读 `.flow-active.goal.auto_advance`"）使该函数获得一个它当前不具备的依赖（jq + `.flow-active` 文件），改变了函数的故障面（`.flow-active` 不存在/损坏/malformed 时影响 L2 检测结果）。

**Source**：ADP（Acyclic Dependencies Principle）——函数依赖应显式声明，不应静默膨胀。CONTEXT.md 禁动清单（L387）将 `29-independent-review.sh` 标记为核心链禁动模块，而该模块直接调用 `l2_detect_missing()`（`29-independent-review.sh:129`：`if l2_detect_missing ...; then`）。函数依赖膨胀 = 禁动模块的隐式行为变化。

**Consequence**：若 `.flow-active` 在 Stop hook 运行时刻不可读（如权限问题 / 正在被其他进程写入 / jq 不可用），`l2_detect_missing()` 可能因 jq 调用失败而返回错误码（2），导致 29 号模块将"L2 状态无法判定"误判为"L2 缺失"，生成误报警告。当前 `l2-detect.sh` 使用 `set -euo pipefail`，jq 失败会直接终止函数而非优雅降级。

**Remedy**：二选一：
- **方案 A（推荐）**：不把 auto_advance 检测放入 `l2_detect_missing()`，而是在 `_gate_check_l2()` 中独立读取 auto_advance（该函数已有 `.flow-active` 上下文），然后调用 `l2_detect_missing()` 获取纯净的 L2 完成状态。`l2_detect_missing()` 保持当前无 `.flow-active` 依赖的契约。
- **方案 B**：若必须放入 `l2_detect_missing()`，则在 DESIGN § 9.3 显式声明新增依赖（jq + `.flow-active`），并在函数内对 jq 失败做 fail-safe 降级（jq 失败 → 视为 auto_advance=false → 返回 1，不吞错也不误报）。

---

### 🟡 R2 · auto_advance L2 非阻塞的静默跳审累积风险：多阶段无人值守场景下缺少聚合告警

**Symptom**：DESIGN.md D4 规定 auto_advance=true 时 `_gate_check_l2` "不执行 exit 2，仅输出警告 + 异步派发 Agent"。DESIGN.md § 5 R2 仅讨论了 Agent 堆积风险（API rate limit），未讨论**审阅缺失的累积风险**：若用户快速确认 toll-gate 暂停点（或 toll-gate 在 auto_advance 模式下也被自动跳过），多个阶段可在短时间内完成 transition，每个阶段的 L2 dispatch 都是异步 fire-and-forget。用户仅看到 stderr 警告（容易被淹没在工具调用输出中），缺乏跨阶段的聚合视图（"目前有 N 个阶段的 L2 审查未完成"）。

**Source**：ADR-003（`.specs/adr/003-l2-pretooluse-dispatch.md`）D4 后果段仅讨论 Agent 资源堆积，未讨论审查覆盖缺口。CONTEXT.md 术语"pipeline goal"定义明确 toll-gate 是"暂停点"而非"自动通过"，但 auto_advance + L2 non-blocking 组合实际上掏空了 L2 gate 的保护作用——auto_advance 的本意是减少人工操作，而非降低审查覆盖率。

**Consequence**：最坏情况：auto_advance pipeline 4→5→6→7 全部完成，用户未注意到任何 stderr L2 警告，所有 4 个阶段的 L2 审查均未执行。Stop hook 29 号模块在会话结束时检测到 L2 缺失并提醒，但此时产物已经全部产出——审查发现的修改需要回滚式修复，成本远高于阶段内修复。

**Remedy**：在 DESIGN § 5 风险表中新增一条风险，或扩展现有 R2：
- 风险名："auto_advance 模式下 L2 审阅跳过累积"
- 缓解措施：在 Stop hook 29 号模块中增加聚合计数——若多个阶段的 L2 均未完成，输出 `[l2-detect] N phases have pending L2 reviews: <phase list>`，并在 resume banner 中展示待审列表。此项可作为 v2 跟进（DESIGN 已标注"v2 考虑 dispatch 去重"），但至少应在 DESIGN 风险段显式记录。

---

### 🟡 R3 · L2/L3 顺序执行的反馈延迟：`both` 配置下 L2 缺失会遮蔽 L3 缺失

**Symptom**：DESIGN.md 数据流图显示 gate 检查顺序为 `_gate_check_l2()` → `_gate_check_l3()`。当 gate_config="both" 且 L2 和 L3 均缺失时，hook 在 L2 检查失败处 `exit 2`，永远不会到达 L3 检查。用户在第一轮只看到"L2 缺失"的反馈；修复 L2 后第二轮 transition 才会发现"L3 也缺失"。REQUIREMENT.md AC-3 仅覆盖"L2 缺失 + L3 已完成"场景，未定义"两者均缺失"场景的反馈行为。

**Source**：ADR-005（ARCHITECTURE.md L176-182）将 L2/L3 定义为"独立判定"（"任缺其一即拦截"），但未规定执行独立性（是否应同时检查并同时报告所有缺失项）。当前顺序执行 + fail-fast 的设计是隐式的，DESIGN 未讨论"为何是顺序而非并行检查"的取舍。

**Consequence**：用户需要两轮交互才能发现所有缺失的审查（第一轮：L2；第二轮：L3），每轮都需等待 Agent dispatch + review 完成。在 pipeline 模式下，这会使阶段间 transition 延迟翻倍。虽然不影响正确性（最终两个审查都会完成），但影响用户体验和 pipeline 吞吐。

**Remedy**：在 DESIGN § 5 或 § 2（数据流）中显式记录此取舍：
```
已知限制：顺序 gate 检查在 gate_config="both" 时，若 L2 和 L3 均缺失，仅报告 L2 缺失。
用户需在 L2 通过后再次尝试 transition 才能触发 L3 检查。
并行检查（L2+L3 同时派发 + 聚合报告）视为 v2 优化，不在本次范围。
```
此限制不阻塞 v1，但必须在设计中显式记录以避免被视为 bug。

---

### 🟢 R4 · DESIGN § 4 ADR 引用路径错误

**Symptom**：DESIGN.md L179 引用 `@.specs/adr/006-l2-pretooluse-dispatch.md`，但实际文件路径为 `.specs/adr/003-l2-pretooluse-dispatch.md`（ADR 编号 003，非 006）。文件不存在于引用路径。

**Source**：文档准确性——ADR 索引是架构决策追溯的关键入口。路径错误导致读者无法定位决策记录。

**Consequence**：追溯 ADR 时浪费时间查找错误路径。不影响代码正确性，但降低文档可信度。

**Remedy**：将 L179 的引用路径修正为 `@.specs/adr/003-l2-pretooluse-dispatch.md`。

---

### 🟢 R5 · D6 固化模板与 L2-blind-review.md 的潜在同步漂移

**Symptom**：DESIGN.md D6 决定将 L2 Agent prompt 模板硬编码在 shell 函数 heredoc 中（~20 行），声称"与 L2-blind-review.md 结构一致"。但 L2-blind-review.md 已多次迭代（append-write 约束来自 `dual-review-merge-fix`、修代码优先协议来自 `l2-l3-fix-compliance`）。shell 函数中的 heredoc 是独立副本，与 L2-blind-review.md 之间不存在自动同步机制——任一侧修改需要人工检查另一侧。

**Source**：DRY（Don't Repeat Yourself）——同一份审查标准在两个位置（L2-blind-review.md + shell heredoc）以不同格式维护。CONTEXT.md 已锁决策 `[2026-07-07]` 要求 L2 prompt 遵循追加写入语义（`>>` 而非 `Write`），若 shell heredoc 遗漏此约束，派发的 Agent 可能覆写已有 L3 段。

**Consequence**：低概率但高影响：若 L2-blind-review.md 更新了审查规则但 shell heredoc 未同步，PreToolUse 派发的 Agent 将使用过时的审查标准，而主 agent 手动派发的 Agent（通过 prompt 指令引用 L2-blind-review.md）使用新标准——同一 change 的 L2 审查结果不一致。当前 L3 兜底可部分缓解（外部模型独立审查不依赖此模板）。

**Remedy**：在 shell 函数注释中添加 `# SYNC-POINT: keep aligned with flow-kit/prompts/independent/L2-blind-review.md` 标记，并建议在 DESIGN § 5 R4 中将概率从"低"调整为"中"（承认人工同步的脆弱性）。v2 考虑将 L2-blind-review.md 作为数据文件读取而非 heredoc 内嵌。

---

### 🟢 R6 · DESIGN 数据流图与 ADR 在进程脱离机制上不一致

**Symptom**：DESIGN.md L112 数据流图显示后台进程为 `&>/dev/null &`，但 ADR-003 D2 明确指定 `disown`（"后台进程 + disown 脱离 hook 进程组"）。`&` 启动的后台进程仍属于原进程组，若 hook 进程被 SIGTERM 杀死且 bash 启用了 `huponexit`，后台进程可能被连带终止。`disown` 是确保进程脱离的关键步骤。

**Source**：ADR-003（`.specs/adr/003-l2-pretooluse-dispatch.md` L33-38）与 DESIGN.md L112 表述不一致。ADR 是更权威的决策记录，DESIGN 应与之对齐。

**Consequence**：若实施者仅参照 DESIGN 数据流图实现（不加 `disown`），则 DESIGN § 5 R1 声称的缓解措施（"后台子进程脱离 hook 进程组"）实际上未生效。Agent 进程可能在 hook 被 kill 时连带终止，导致 dispatch 静默丢失。

**Remedy**：在 DESIGN.md L112 数据流图中将 `&>/dev/null &` 修正为 `&>/dev/null & disown` 以与 ADR-003 D2 一致。

---

### 🟢 R7 · DESIGN § 5 R3 引用的 CONTEXT.md 行号不准确

**Symptom**：DESIGN.md L189 称 `_gate_check_l2` 是"禁动清单核心链模块（CONTEXT.md line 383）"。但 CONTEXT.md L383 的内容是 `L2-blind-review.md checklist 条目 — 禁止降级为纯文本段落`（关于审查格式，非 gate 核心链）。gate 核心链引用实际在 CONTEXT.md L387：`independent-review-gate.sh + 29-independent-review.sh + fk_validate_done_marker — gate 校验核心链`。

**Source**：引用精度——行号引用偏差可能导致后续读者对禁动清单范围产生误解。

**Consequence**：文档可信度轻微受损。不影响技术决策。

**Remedy**：将 L189 的行号引用从 "line 383" 修正为 "line 387"；或改为描述性引用（"CONTEXT.md 禁动清单 § gate 校验核心链"），避免硬编码行号（行号随 CONTEXT.md 增长而漂移）。

---

## 审查总结

### 正面

- DESIGN 与 REQUIREMENT.md 的 AC 覆盖关系清晰——每条 AC 在数据流/状态机中均可追溯
- brownfield 对齐（§ 0.5）详尽——触碰模块、禁动模块、沿用模式均显式列出，减少实施盲区
- 跨模块契约变更（§ 9.3）明确标注——新增函数签名、返回值扩展、调用关系一目了然
- ADR-003 的取舍分析扎实——每个决策都有"为什么选 X 不选 Y"的理由和代价陈述
- 风险表覆盖了主要技术风险（超时、堆积、回归、模板一致性），缓解措施具体

### 待改进

- `l2_detect_missing()` 的依赖膨胀需显式化（R1）——当前 DESIGN 用"沿用，扩展返回值"暗示改动小，但新增 `.flow-active` 读取是非平凡的契约变更
- auto_advance + L2 non-blocking 组合的审查覆盖率风险需要更系统的缓解（R2）
- L2/L3 顺序执行的反馈延迟应作为已知限制记录（R3）
- 硬化模板与 L2-blind-review.md 的同步机制需显式标注（R5）
- 数据流图与 ADR 在 `disown` 细节上需对齐（R6）

### 未发现的问题

- 未发现架构碰撞——DESIGN 的修改范围（`_gate_check_l2` 内部 + `l2-detect.sh` 扩展）不违反 ARCHITECTURE.md 的模块依赖规则（PreToolUse → hooks/stop/lib/ 是允许方向）
- 未发现禁动清单违规——DESIGN § 0.5.1 禁动清单与 CONTEXT.md 禁动清单一致，改动范围未触碰 `_gate_check_l3`、`_gate_phase_transition`、`29-independent-review.sh` 等禁动模块
- 未发现 AC 覆盖缺失——9 条 AC 在数据流/状态机/ADR 中均有对应设计元素
- 未发现安全漏洞——API key 通过环境变量读取（非硬编码），Agent 权限边界明确（仅读阶段工件 + 仅写 review md 的 L2 段），dispatch 事件有 hooks.log 审计

**Verdict**: pass

---

## 主 agent 响应

### R1 · l2_detect_missing() 依赖膨胀 — Fixed in: DESIGN.md v2

✅ **已修复**。采用方案 A：auto_advance 检测保留在 `_gate_check_l2()` 中（该函数已有 `.flow-active` 上下文），`l2_detect_missing()` 签名和返回值不变，保持纯净契约（不读 `.flow-active`，不引入 jq 依赖）。DESIGN § 0.5.2 + § 9.3 已同步更新。

### R2 · auto_advance 静默跳审累积 — Fixed in: DESIGN.md v2

✅ **已修复**。DESIGN § 5 风险表新增 R2b，明确记录此风险及缓解措施：Stop hook 29 号模块聚合计数（`N phases have pending L2 reviews`）+ resume banner 展示待审列表。

### R3 · L2/L3 顺序执行反馈延迟 — Fixed in: DESIGN.md v2

✅ **已修复**。DESIGN § 6 新增「已知限制」子段，显式记录顺序 gate 检查的取舍：gate_config=both 且两者均缺失时仅报告 L2，需两轮交互。并行检查列为 v2 优化。

### R4 · ADR 路径 006→003 — Fixed in: DESIGN.md v2

✅ **已修复**。DESIGN § 4 ADR 引用路径修正为 `.specs/adr/003-l2-pretooluse-dispatch.md`。

### R5 · 模板同步漂移 — Fixed in: DESIGN.md v2

✅ **已修复**。DESIGN § 5 R4 缓解措施补充：shell 函数 heredoc 加 `# SYNC-POINT: keep aligned with flow-kit/prompts/independent/L2-blind-review.md` 标记。

### R6 · 数据流图缺 disown — Fixed in: DESIGN.md v2

✅ **已修复**。DESIGN § 2 数据流图 + § 0.5.3 沿用模式，两处 `&>/dev/null &` 均修正为 `&>/dev/null & disown`，与 ADR-003 D2 一致。

### R7 · CONTEXT.md 行号 383→387 — Fixed in: DESIGN.md v2

✅ **已修复**。DESIGN § 5 R3 行号引用修正为 "line 387"，同时改为描述性引用（"禁动清单 § gate 校验核心链"），避免行号漂移。


---

## L3 重审（deepseek-v4-flash[1m] 外部模型 · 2026-07-15 15:28）

> 自动生成于 2026-07-15 15:28。由 l3-review.sh 写入。

### 审查结论

```json
{
  "critical": [],
  "major": [
    {
      "file": "DESIGN.md",
      "issue": "Auto_advance 路径下异步 dispatch 失败后缺少降级处理，可能导致 L2 审查静默缺失且用户无感知",
      "why": "在数据流图和状态机中，auto_advance=true 分支仅在 stderr 打印日志后异步 dispatch，然后直接 return 0 放行，未检查 dispatch 是否成功，也未 fallback 到手动命令提示。若 curl 调用因网络或 API 错误失败，用户不会收到任何错误信号，L2 审查被静默跳过，直到会话结束 Stop hook 才报告，可能已造成多阶段累积缺失。这与 D5 声称的『dispatch 失败降级策略』不一致（D5 未区分 auto_advance 场景）。",
      "fix": "在 auto_advance 分支中，异步 dispatch 后应等待 (wait) 子进程退出码并做判断：若失败则在 stderr 输出显式警告并推荐手动命令 (l2_dispatch_prompt)，同时保持 return 0 放行，避免静默。或者至少添加注释说明该行为是预期设计（委托 Stop hook 兜底），但当前文档未明确，属于设计漏洞。"
    }
  ],
  "minor": [
    {
      "file": "DESIGN.md",
      "issue": "风险 R2b 的缓解措施缺乏具体实现细节",
      "why": "R2b 建议『v2 可考虑 dispatch 去重 + 跨阶段聚合视图』，但当前缓解仅依赖 Stop hook 聚合报告和 resume banner，未说明是否真的打算实现去重，也未描述如何防止同一阶段重复 dispatch。",
      "fix": "可明确将去重设为 v2 目标，或在当前版本中加入简单的锁文件机制（如 `touch .l2-dispatch-<phase>.lock`）避免同一阶段并发/重复 dispatch。"
    },
    {
      "file": "DESIGN.md",
      "issue": "ADR-003 在文档中不完整，仅截取部分内容",
      "why": "第 6 节 ADR 索引声称 ADR-003 是单独文件，但文档末尾附加的 ADR-003 仅显示 D1 和 D2 的部分内容，没有 D3-D6 的决策理由，造成审查者对完整决策链条的理解不完整。",
      "fix": "确保所附 ADR-003 内容完整（至少包含 D1-D6 所有决策及理由），或明确标注『全文见 @.specs/adr/003-l2-pretooluse-dispatch.md』，不在本设计文档中重复。"
    }
  ],
  "verdict": "pass",
  "summary": "设计文档整体严谨，决策合理，与既有架构对齐良好。主要问题在于 auto_advance 路径下异步 dispatch 失败后的降级处理缺失，可能导致 L2 审查静默跳过。该问题不构成系统致命缺陷（仍可被 Stop hook 兜底），且可通过补充逻辑修正。"
}
```
