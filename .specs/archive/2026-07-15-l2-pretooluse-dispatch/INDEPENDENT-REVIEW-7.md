# INDEPENDENT-REVIEW-7: L2 PreToolUse Dispatch — 阶段 7 集成审查

- **审查阶段**: 7 (集成审查)
- **Change ID**: `l2-pretooluse-dispatch`
- **审查日期**: 2026-07-15
- **审查模型**: L2 独立盲审员（固化指令）

---

## 审查范围

`.specs/l2-pretooluse-dispatch/` 全部产物，参考 `.specs/LESSONS.md`、`.specs/CHANGELOG.md`。

---

## 产物齐全检查

| 文件 | 预期 | 实际 | 状态 |
|---|---|---|---|
| CHANGE.md | 必须 | 4.6K, 72行 | ✅ |
| REQUIREMENT.md | 必须 | 11.5K, 165行 | ✅ |
| DESIGN.md | 必须 | 17.3K, 242行 | ✅ |
| TASK.md | 必须 | 19.2K, 417行 | ✅ |
| TEST.md | 必须 | 5.1K, 110行 | ✅ |
| REVIEW.md | 必须 | 3.3K, 81行 | ✅ |
| PROGRESS.md | 期望 | 1.3K, 31行 | ✅ |
| ADR-003 | DESIGN引用 | 存在, 83行 | ✅ |

**结论**: 核心六产物 (CHANGE/REQUIREMENT/DESIGN/TASK/TEST/REVIEW) 齐全。ADR 跟随 DESIGN 引用已创建。

---

## 发现清单

---

### R1 · CHANGELOG.md 未同步

- **严重度**: 🔴 Critical
- **Symptom**: `grep 'l2-pretooluse-dispatch' .specs/CHANGELOG.md` 返回 0 匹配。在 CHANGELOG.md 的 83 行倒序列表中，最新条目为 `2026-07-11 | l3-pipeline-fix-2026-07`，无 `l2-pretooluse-dispatch` 条目。
- **Source**: `.specs/CHANGELOG.md` 全文（83 行），按日期倒序排列。变更历史截止于 2026-07-11。`l2-pretooluse-dispatch` 的 CHANGE.md 创建日期为 2026-07-15，REVIEW.md verdict 为 pass，说明所有阶段已完成，应已归档。
- **Consequence**: 项目变更历史不完整。CHANGELOG 是跨 change 追溯的主要入口——缺少条目意味着此 change 在项目历史中不可见。其他开发者（或未来 AI agent）无法从 CHANGELOG 了解此 change 的范围、影响和教训引用。
- **Remedy**: 按 CHANGELOG 既有格式在顶部追加：

  ```
  | 2026-07-15 | l2-pretooluse-dispatch | L2 PreToolUse 前置拦截+Agent自动派发+L3写入管道原子化防竞态: _gate_check_l2扩展auto-dispatch分支+l2_dispatch_agent()异步fire-and-forget+l3-review.shtmp+mv原子写入+29号去2>/dev/null错误吞没 · 6 files, ~+437/-0 · 12 bats 0 fail · pipeline 0→7 全L2+L3 · ADR-003 | L-044, L-045 |
  ```

  其中 L-044/L-045 需与 R2 的 LESSONS 条目编号一致。

---

### R2 · LESSONS.md 未同步

- **严重度**: 🔴 Critical
- **Symptom**: `grep 'l2-pretooluse-dispatch' .specs/LESSONS.md` 返回 0 匹配。LESSONS.md 最新条目为 `L-043`（`l3-pipeline-fix-2026-07`，2026-07-11），无本次 change 的新教训。
- **Source**: `.specs/LESSONS.md` 全文。`L-043` 之后无新增条目，技术债清单最后更新于 2026-07-10。
- **Consequence**: 本次 change 的架构级决策和经验未被沉淀。以下至少 3 项值得记录：
  - (a) PreToolUse hook 内异步 fire-and-forget Agent dispatch 模式的权衡（DESIGN D3: 同步 vs 异步、`disown` 脱离进程组、Agent 结果反馈延迟）；
  - (b) `>>` 裸追加 vs `tmp+mv` 原子写入的竞态场景与选择标准（T09: L3 写入与主 agent Edit 的竞态——本 change 发现并修复）；
  - (c) gate 核心链函数内部扩展时禁动清单交叉验证的流程（R3 风险：`_gate_check_l2` 属 CONTEXT.md 禁动清单核心链，扩展需充分回归）。
  遗漏这些意味着后续 change 遇到相同模式时无法从 LESSONS 受益，可能重复踩坑。
- **Remedy**: 在 LESSONS.md 的技术债清单区域追加 2-3 条：

  ```
  ### L-044: PreToolUse hook 内异步 Agent dispatch——fire-and-forget 的取舍
  **严重程度**: 🟡 Major（设计级）
  **来源**: `l2-pretooluse-dispatch` change（2026-07-15）
  **发现**: PreToolUse hook 有 ~5s 超时限制，Agent API 调用需 15-60s。同步等待→hook被kill→dispatch丢失。异步 fire-and-forget（`curl ... &>/dev/null & disown`）解决了超时问题但引入了两个代价：(1) Agent 结果不能在同一轮返回；(2) Agent 静默失败时用户需等到 Stop hook 才知道。
  **建议**: (1) 异步 dispatch 仅限 PreToolUse 场景（有超时上限）；(2) 必须搭配 Stop hook 兜底提醒 + SessionStart 注入报告摘要；(3) dispatch 失败时必须降级为手动命令（不能只 silence fail）。

  ### L-045: 写入竞态——`>>` 裸追加 vs `tmp+mv` 原子写入
  **严重程度**: 🟡 Major（正确性级）
  **来源**: `l2-pretooluse-dispatch` change（2026-07-15）
  **发现**: hook 脚本写入 INDEPENDENT-REVIEW 文件使用 `} >> "$review_md"` 裸追加，与主 agent 的 Edit（字符串匹配替换）形成竞态——主 agent 可能在 hook 追加后立即做 Edit，导致 L3 段因锚点文本变化而丢失。修复方案：temp-file + mv 原子写入 + 写入后 `grep -q` 验证。
  **建议**: 任何 hook 脚本写入"主 agent 也可能同时读/写"的文件时，必须使用 `tmp+mv` 原子写入 + 写入后验证。不适用场景：仅 hook 独占写入的文件（如 hooks.log、correction 文件）可用裸追加。
  ```

---

### R3 · INDEPENDENT-REVIEW-4.md 缺失

- **严重度**: 🟡 Major
- **Symptom**: `.specs/l2-pretooluse-dispatch/` 目录下 INDEPENDENT-REVIEW-4.md 不存在。存在的是：INDEPENDENT-REVIEW-1.md (22.4K), 2 (16.5K), 3 (29.5K), 5 (13.3K), 6 (12.5K)。Phase 4 对应的审查文件缺失。
- **Source**: `ls -la .specs/l2-pretooluse-dispatch/` 输出。PROGRESS.md 显示 phase 4 仅 1 条记录 `| 2026-07-15 15:37 | fd049a1a-d58 | 4 | none | ? |`——仅 1 次会话，且 task 为 "none"。
- **Consequence**: Phase 4 (4-dev.md / 开发阶段) 的独立审查跟踪链断裂。无法确认：(a) 该阶段是否配置了独立审查 gate；(b) 若配置了，审查是否执行过但输出文件丢失；(c) 若未配置，是否有显式的跳过说明。若该阶段应审未审，则 dev 产物的质量未经独立验证。
- **Remedy**: (1) 检查 phase 4 的 gate_config 配置（`.flow-active.goal.gate_config["4-dev"]`）确认是否需要审查；(2) 若需要但缺失，执行事后审查并补写 INDEPENDENT-REVIEW-4.md；(3) 若不需要（gate_config 不含 L2/L3），在 PROGRESS.md 中追加跳过说明行。

---

### R4 · .done 标记缺失（Phase 5: verdict=pass 但无 .done）

- **严重度**: 🟡 Major
- **Symptom**: `INDEPENDENT-REVIEW-5.md` 存在（13.3K），其中 L3 盲审段明确包含 `"verdict": "pass"`（grep 命中 2 处），但 `.independent-review-5.done` 不存在。
- **Source**: (a) `ls -la` 仅显示 `.independent-review-1.done` 和 `.independent-review-2.done`；(b) `grep -c 'verdict.*pass' INDEPENDENT-REVIEW-5.md` = 2；(c) `test -f .independent-review-5.done` = MISSING。
- **Consequence**: L3 gate 的 .done 条件写入逻辑（仅 `verdict=pass` 时写入 `_l3_write_done()`）在 phase 5 执行时失效。这恰好是本 change T08/T09 修复的问题——旧的 L3 代码可能因 `2>/dev/null` 静默吞错误或 `>>` 竞态覆盖导致 .done 写入失败。该缺失标记意味着后续 phase 的 gate 可能不会识别 phase 5 的 L3 已完成，触发不必要的重审。
- **Remedy**: (1) 确认 T09 的原子写入 + 写入后验证修复已部署到运行环境；(2) 手工重建 `.independent-review-5.done`，KVP 内容从 INDEPENDENT-REVIEW-5.md 的 L3 盲审段提取（phase=5, change_id=l2-pretooluse-dispatch, L3_verdict=pass, 等）。

---

### R5 · .done 标记缺失（Phase 6: verdict 格式非结构化）

- **严重度**: 🟡 Major
- **Symptom**: `INDEPENDENT-REVIEW-6.md` 存在（12.5K），但 `.independent-review-6.done` 不存在。Phase 6 的 verdict 以 Markdown 粗体散文格式呈现（`**pass** — 11/11 AC 覆盖...`），而非结构化 JSON KVP。
- **Source**: INDEPENDENT-REVIEW-6.md line 155: `**pass** — 11/11 AC 覆盖，禁动清单无越界...`。全文无 `"verdict": "pass"` JSON 格式。
- **Consequence**: `done-validation.sh` 的 verdict 解析逻辑若依赖结构化 KVP 格式（如 `L3_verdict=pass`），则无法从散文格式中提取 verdict 值，可能导致：(a) .done 写入跳过（认为 verdict 不明确）；(b) gate 后续阶段误判 phase 6 审查未完成。Phase 6 是 REVIEW 阶段——其审查由主 agent 自身输出（非 L3 外部 Agent），格式与 L3 不一致是合理的，但导致 .done 缺失属于集成缺陷。
- **Remedy**: (1) 在 phase 6 的 prompt 模板中标准化 verdict 输出格式（要求明确输出 `L3_verdict=pass|fail` 或等效 KVP）；(2) 或修改 done-validation.sh 支持从 `**pass**` / `**fail**` 散文标记中提取 verdict；(3) 手工为 phase 6 重建 .done 标记。

---

### R6 · L2-blind-review.md 引用路径悬空

- **严重度**: 🟡 Major
- **Symptom**: DESIGN.md §4 R4 风险缓解说明和 TASK.md T01 action 步骤均引用 `flow-kit/prompts/independent/L2-blind-review.md` 作为 SYNC-POINT 锚点文件，但该路径不存在。
- **Source**: (a) DESIGN.md line 193: `# SYNC-POINT: keep aligned with flow-kit/prompts/independent/L2-blind-review.md`；(b) TASK.md line 41: `# SYNC-POINT: keep aligned with flow-kit/prompts/independent/L2-blind-review.md`；(c) `test -f flow-kit/prompts/independent/L2-blind-review.md` = MISSING。
- **Consequence**: shell heredoc 中固化的 Agent prompt 模板与审查标准的对齐关系无法通过文件存在性验证。若模板需要更新，开发者/AI 无法对照源文件确认差异。长期维护中模板可能与预期审查标准漂移。
- **Remedy**: (1) 定位项目内 L2 盲审指令的实际存储位置（可能在 `.specs/`、`prompts/` 其他子目录，或在 flow-kit-bundle 中）；(2) 若实际以 shell heredoc 为唯一真实来源，更新 DESIGN.md 和 TASK.md 中的引用，将 SYNC-POINT 指向 `l2-detect.sh::l2_dispatch_agent()` 函数自身；(3) 若文件确实存在但路径不同，修正路径引用。

---

### R7 · .done 标记缺失（Phase 3: 预期行为，但需确认）

- **严重度**: 🟢 Minor
- **Symptom**: `INDEPENDENT-REVIEW-3.md` 存在（29.5K）但 `.independent-review-3.done` 不存在。
- **Source**: `grep '"verdict"' INDEPENDENT-REVIEW-3.md` = `"verdict": "fail"`。L3 gate 的 `_l3_write_done()` 逻辑为：仅当 verdict=pass 时写入 .done 标记（此行为由 `fix-l3-gate` change 引入）。
- **Consequence**: 这是预期行为——verdict=fail 时不写 .done，防止下一阶段 gate 误判为已完成。**无功能影响**。但建议确认 phase 3 的 fail 发现是否已被修复并在后续阶段重新审查通过。
- **Remedy**: 确认 phase 3 审查发现的问题已解决。若已解决且重新审查 pass，补写 .done。否则保持现状。

---

### R8 · PROGRESS.md Token 列数据缺失

- **严重度**: 🟢 Minor
- **Symptom**: PROGRESS.md 全部 24 条会话记录的 Token 列均为 `?`，无实际 token 计数。
- **Source**: PROGRESS.md line 7-30: 所有行 `| ... | ... | ... | ? |`。
- **Consequence**: 无法分析此 change 的 token 消费（如各阶段消耗、L2/L3 审查开销、dispatch 成本）。不影响功能正确性，但降低项目成本可观测性。
- **Remedy**: 检查 Stop hook G5 的 token 记录功能是否正常工作。与本次 change 范围无关（本 change 不改 G5），属于独立观测项。

---

### R9 · CHANGE.md 状态仍为 draft

- **严重度**: 🟢 Minor
- **Symptom**: CHANGE.md line 5: `- **状态**: draft`。但 REVIEW.md verdict 为 pass，全部 11 AC 覆盖，表明所有阶段已完成。
- **Source**: CHANGE.md 头部元数据。
- **Consequence**: 元数据与实际进度不一致。若依赖 CHANGE.md 状态字段做自动化判断（如 change 是否可归档），可能误判此 change 未完成。
- **Remedy**: 将状态更新为 `implemented` 或 `done`。

---

### R10 · .independent-review-7.done 不存在

- **严重度**: 🟢 Minor（预期）
- **Symptom**: `.specs/l2-pretooluse-dispatch/.independent-review-7.done` 不存在。
- **Source**: `test -f .independent-review-7.done` = MISSING。
- **Consequence**: Phase 7 集成审查正在进行中（本文件即为审查产物），.done 标记应在审查完成且 verdict=pass 后写入。当前缺失是预期状态。
- **Remedy**: 若本次审查 verdict=pass，在审查结束后写入 `.independent-review-7.done`。

---

## 归档清洁检查

| 检查项 | 结果 |
|---|---|
| `.tmp` / `.bak` / `.swp` / `*~` / `.DS_Store` 残留 | ✅ 无残留临时文件 |
| 非预期文件（不属于 CHANGE/REQUIREMENT/DESIGN/TASK/TEST/REVIEW/ADR/PROGRESS/INDEPENDENT-REVIEW） | ✅ 无异常文件 |

---

## 汇总

| 严重度 | 数量 | 编号 |
|---|---|---|
| 🔴 Critical | 2 | R1 (CHANGELOG), R2 (LESSONS) |
| 🟡 Major | 5 | R3 (REVIEW-4缺失), R4 (phase5 .done缺失), R5 (phase6 .done缺失), R6 (L2-blind-review路径悬空), R4/R5 合并为 2 个独立发现 |
| 🟢 Minor | 4 | R7 (phase3 .done预期), R8 (Token数据), R9 (状态draft), R10 (phase7 .done预期) |

---

## Verdict

**fail**

CHANGELOG.md 和 LESSONS.md 均未同步本次 change——这是集成审查的硬性阻塞项（R1+R2，🔴 Critical）。两个文件是项目跨 change 追溯的核心资产，缺失条目意味着此 change 在项目历史中不可见，后续开发者/AI 无法从 CHANGELOG 了解范围、从 LESSONS 获取教训。

修复路径：
1. 按 R1 remedy 在 CHANGELOG.md 顶部追加条目
2. 按 R2 remedy 在 LESSONS.md 技术债清单区域追加 L-044、L-045
3. 解决 R4（phase 5 .done 缺失）和 R5（phase 6 .done 缺失）——验证 verdict 状态后手工重建标记
4. R3（REVIEW-4 缺失）和 R6（L2-blind-review 路径悬空）为非阻塞但建议修复
5. 上述修复完成后，重新执行阶段 7 集成审查（或主 agent 确认修复后由审查员验证并改 verdict 为 pass）

---
