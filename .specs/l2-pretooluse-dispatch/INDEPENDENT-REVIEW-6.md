# INDEPENDENT-REVIEW-6: L2 PreToolUse Dispatch + L3 写入管道修复

- **审查日期**: 2026-07-15
- **审查阶段**: 6 (代码审查)
- **Change ID**: l2-pretooluse-dispatch
- **审查工件**: `git diff HEAD` — 4 个源文件变更 (l2-detect.sh, independent-review-gate.sh, 29-independent-review.sh, l3-review.sh)
- **参考**: REQUIREMENT.md, DESIGN.md, REVIEW.md, TASK.md, TEST.md

---

## Spec 合规逐 AC 验证

| AC | 代码覆盖点 | 文件:行号 | 判定 |
|---|---|---|---|
| AC-1 (L2 缺失 → exit 2) | `_gate_check_l2()` 在 dispatch 成功后 exit 2，失败降级后 exit 2 | independent-review-gate.sh:255, 279 | ✅ 覆盖 |
| AC-2 (L2 完成 → 放行) | `grep -q "^## L2 盲审"` → return 0 | independent-review-gate.sh:189 | ✅ 覆盖 |
| AC-3 (both 独立判定) | `_gate_check_l2` 先于 `_gate_check_l3` 执行，L2 缺失即 exit 2 | independent-review-gate.sh:374-376 | ✅ 覆盖 |
| AC-4 (gate_config 不含 L2 → 跳过) | `if [[ "$gate_val" != "both" && "$gate_val" != "L2" ]]; then return 0` | independent-review-gate.sh:188 | ✅ 覆盖 |
| AC-5a (自动派发 + 反馈) | `l2_dispatch_agent` 调用 → 成功输出 `[l2-dispatch] Agent dispatched` + exit 2 | independent-review-gate.sh:230-255 | ✅ 覆盖 |
| AC-5b (派发失败降级) | dispatch_ok=0 → `l2_dispatch_prompt` 降级 + `[l2-dispatch] dispatch failed` + exit 2 | independent-review-gate.sh:258-279 | ✅ 覆盖 |
| AC-5c (派发结果写入) | `l2_dispatch_agent()` 写入 `$review_md` 含 `## L2 盲审` 段 | l2-detect.sh:228-237 | ✅ 覆盖 |
| AC-6 (L3 PreToolUse 无回归) | `_gate_check_l3` 未修改；`_gate_phase_transition` 编排未改 | independent-review-gate.sh:286-319 | ✅ 覆盖 |
| AC-7 (Stop hook L2 无回归) | `29-independent-review.sh` 的 L2 检测逻辑未改；`l2_detect_missing()` 签名不变 | 29-independent-review.sh:128-142 | ✅ 覆盖 |
| AC-8 (install_hooks 兼容) | PreToolUse matcher `Bash\|Write\|Edit` 已覆盖 Bash 写 phase；无新增 hook 条目 | — | ✅ 覆盖 |
| AC-9 (auto_advance 非阻塞) | `jq -r '.goal.auto_advance // false'` → 异步派发 + return 0 | independent-review-gate.sh:214-227 | ✅ 覆盖 |
| AC-10 (backlog 错误日志) | 去 `2>/dev/null`；新增 `bl_rc=$?` 捕获 + `module_output "warning"` | 29-independent-review.sh:94-98 | ✅ 覆盖 |
| AC-11 (L3 原子写入) | tmp+mv 原子写入；写入后 `grep -q "^## L3 盲审\|^## L3 重审"` 验证 | l3-review.sh:443-464 | ✅ 覆盖 |

**AC 覆盖率**: 11/11 = 100%。主 agent REVIEW.md 的此项声明准确。

---

## 代码质量 6 维衰退风险

### R1 · 认知过载

- **Symptom**: REVIEW.md 声明"每个函数 ≤80 行"。实测: `_gate_check_l2()` = 95 行 (L185-L280), `l2_dispatch_agent()` = 149 行 (L102-L251)。
- **Source**: `.specs/l2-pretooluse-dispatch/REVIEW.md`, line 47
- **Consequence**: 审查报告低估了两个最大新函数的实际长度 (超标 19%/86%)，掩盖了潜在的认知负荷问题。`l2_dispatch_agent()` 合一了 mock 分支、凭证检查、prompt 构造 (heredoc + case)、curl 双路径调用、JSON 响应解析、文件写入、后台进程管理——7 个独立关注点挤在一个函数内。
- **Remedy**: (a) 修正 REVIEW.md 的 R1 声明为"核心新增函数 ≤150 行，职责分段清晰"；(b) 考虑拆分 `l2_dispatch_agent()` 为 `_l2_build_prompt()` + `_l2_call_api()` + `_l2_write_result()` 三个子函数，与 `l3-review.sh` 的分层模式对齐
- **Severity**: 🟢 Minor (代码分段标记清晰，当前可维护，但声明与事实不一致)

### R2 · 变更传播: ✅ Low

`l2_dispatch_agent()` 是独立函数，仅被 `_gate_check_l2()` 调用。改动半径小，设计合理。

### R3 · 知识重复: ⚠️ Medium (同主 agent 评估)

`l2_dispatch_agent()` 的 curl+API 调用模式 (~40 行) 与 `l3-review.sh::_l3_call_api()` 实质重复。两者共享相同的 API endpoint 构建、auth header 选择、HTTP 状态码检查、jq 响应解析逻辑。关联: AC-11 引入的原子写入模式仅在 L3 侧实现——L2 dispatch 仍用裸 `>>` (见下 Finding 1)。

### R4 · 偶然复杂: ✅ Low

Mock 模式通过单一环境变量 `FLOW_KIT_L2_MOCK=1` 控制，清晰简洁。

### R5 · 依赖混乱: ✅ Low

PreToolUse gate → stop/lib 方向是项目既有的合法依赖方向。`l2_detect_missing()` 保持纯净契约 (不读 .flow-active)。

### R6 · 领域扭曲: ✅ Low

命名遵循项目约定 (`l2_` 前缀, `_gate_` 前缀)。

---

## 发现

### Finding 1: L2 dispatch 写入使用裸 `>>`，与同期 L3 原子写入模式不一致

- **Symptom**: `l2_dispatch_agent()` 在 line 237 使用 `} >> "$review_md"` 直接追加 L2 审查结果。同一 change 在 `_l3_parse_result()` (AC-11) 引入了 tmp+mv 原子写入模式。L2 与 L3 写入同一文件 (`INDEPENDENT-REVIEW-<N>.md`) 但使用不同的写入安全性级别。
- **Source**: `flow-kit-bundle/hooks/stop/lib/l2-detect.sh`, line 237
- **Consequence**: 两个并发场景存在风险: (a) auto_advance 快速推进多阶段时，多个 L2 Agent 后台进程可能同时 `>>` 写入同一文件 (虽不同 phase 不同文件，但同 phase 的 L2+L3 并发写同一文件是 DESIGN 承认的场景)；(b) 主 agent 同时在用 Edit 修改同一文件时，裸 `>>` 可能产生交错内容。
- **Remedy**: 为 `l2_dispatch_agent()` 实现与 `_l3_parse_result()` 相同的 tmp+mv 原子写入模式：读当前文件 → 追加 L2 段 → 写入 tmp → mv。注: mock 路径 (line 129) 同样使用裸 `>>`，需一并修复。
- **Severity**: 🟡 Major

### Finding 2: `_gate_check_l2` 在调用 `l2_dispatch_agent` 时吞掉 stderr，dispatch 失败原因不可观测

- **Symptom**: Line 234: `l2_dispatch_agent "$phase" "$change_id" "${cwd}/.specs/${change_id}" 2>/dev/null` — 将 `l2_dispatch_agent()` 的全部 stderr 重定向到 /dev/null。函数内部输出的 `[l2-dispatch] no API credentials` / `API returned HTTP 500` / `jq payload construction failed` 等诊断信息全部丢失。
- **Source**: `flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh`, line 234
- **Consequence**: 当 dispatch 失败时，用户和 hooks.log 只能看到 "dispatch failed, see manual command above" 而无任何根因信息。无法区分"凭证缺失" vs "网络故障" vs "API 500"——失去了 NFR 要求的 `[l2-dispatch]` 日志对三种失败状态的可观测性。
- **Remedy**: 去掉 `2>/dev/null`，使 `l2_dispatch_agent` 的诊断 stderr 自然落到 hook 的 stderr 流中。同时注意 line 224 (auto_advance 路径) 使用了不一致的 `>&2 2>/dev/null` 重定向 (stdout→stderr, 然后 stderr→/dev/null——逻辑上自相矛盾)，应一并统一为不吞 stderr。
- **Severity**: 🟡 Major

### Finding 3: `l2_dispatch_agent` 后台进程的 `&>/dev/null & disown` 丢弃了所有 Agent 执行期诊断

- **Symptom**: Line 241: `) &>/dev/null & disown` — 后台子进程的全部 stdout+stderr 被丢弃。Agent 执行过程中的 API 错误、响应解析失败、文件写入错误均无法追踪。
- **Source**: `flow-kit-bundle/hooks/stop/lib/l2-detect.sh`, line 241
- **Consequence**: Agent dispatch 成功触发 (返回 0) 但 Agent 实际执行失败 (curl 超时/API 错误) 时，无任何途径感知失败。用户下一次 transition 时 L2 仍缺失，但不知道是 Agent 还在跑还是已静默失败。违反 NFR 中"审计: Agent dispatch 事件记录到 hooks.log"的要求。
- **Remedy**: 至少将后台进程的 stderr 重定向到一个日志文件 (如 `${specs_dir}/.l2-agent-${phase}.log`) 而非 `/dev/null`，使得 Agent 执行失败时可追溯。
- **Severity**: 🟡 Major

### Finding 4: REVIEW.md R1 声明 ("每个函数 ≤80 行") 与实测不符

- **Symptom**: REVIEW.md line 47 声明"每个函数 ≤80 行"，但 `_gate_check_l2()` 实际 95 行，`l2_dispatch_agent()` 实际 149 行。
- **Source**: `.specs/l2-pretooluse-dispatch/REVIEW.md`, line 47
- **Consequence**: 审查报告准确性受损。低严重度，因为代码本身有良好的分段标记和注释，实际可维护性并不差。
- **Remedy**: 修正 REVIEW.md 描述为实测值，或在代码侧拆分 `l2_dispatch_agent()` 以符合声明。
- **Severity**: 🟢 Minor

### Finding 5: auto_advance dispatch 路径的重定向逻辑自相矛盾

- **Symptom**: Line 224: `l2_dispatch_agent "$phase" ... >&2 2>/dev/null || true` — `>&2` 将 stdout 重定向到 stderr，随后 `2>/dev/null` 将 stderr 丢弃。净效果：stdout 和 stderr 全部被丢弃，但经过了多余的一次重定向。
- **Source**: `flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh`, line 224
- **Consequence**: 无功能影响 (输出最终都被丢弃)，但增加了阅读困惑，且与 line 234 的 `2>/dev/null` 重定向模式不一致。
- **Remedy**: 统一两处 `l2_dispatch_agent` 调用的重定向。建议: 正常路径保留 stderr (去掉 `2>/dev/null`)，auto_advance 路径因是 fire-and-forget 可保持 `2>/dev/null` 但去掉无意义的 `>&2`。
- **Severity**: 🟢 Minor

---

## 禁动清单交叉验证

| 禁动项 | 本次修改? | 授权来源 | 实际变更范围 | 判定 |
|---|---|---|---|---|
| `auto-checkpoint.sh` | 否 | — | — | ✅ 未触碰 |
| `29-independent-review.sh` | 是 | T08 — 去 `2>/dev/null` + 加日志 | 仅 line 94, 95-98, 185 三处 | ✅ 在授权范围内 |
| `l3-review.sh` | 是 | T09 — 原子写入 + 写入后验证 | 仅 `_l3_parse_result()` 写入逻辑 + `_l3_write_done()` 防御 | ✅ 在授权范围内 |
| `correction-file.sh` | 否 | — | — | ✅ 未触碰 |
| `.flow-active` schema | 否 | — | — | ✅ 未触碰 |
| `_gate_phase_transition` 编排逻辑 | 否 | — | — | ✅ 未触碰 |
| 校验顺序 | 否 | — | — | ✅ 未触碰 |

**无越界修改。** 主 agent REVIEW.md 此项声明准确。

---

## DESIGN.md 决策符合性

| 决策 | 设计要求 | 实现 | 判定 |
|---|---|---|---|
| D1 | 在 `_gate_check_l2` 中集成 dispatch | 已集成 | ✅ |
| D2 | curl + Anthropic Messages API | 已实现 | ✅ |
| D3 | 异步 fire-and-forget (`&` + `disown`) | 已实现 (line 241) | ✅ |
| D4 | auto_advance 读 `.flow-active.goal.auto_advance` | 已实现 (line 216) | ✅ |
| D5 | dispatch 失败 → 降级到 `l2_dispatch_prompt` | 已实现 (lines 258-262) | ✅ |
| D6 | 固化模板 + SYNC-POINT 标记 | 已实现 (line 93, lines 143-177) | ✅ |

全部 6 项决策正确实施。

---

## 主 agent REVIEW.md 漏判/误判项

| 项目 | REVIEW.md 声称 | 独立审查判定 | 说明 |
|---|---|---|---|
| R1 函数 ≤80 行 | ✅ Low | 🟢 Minor | 实测 `_gate_check_l2` 95 行、`l2_dispatch_agent` 149 行，超标但影响有限 |
| 无新增 🔴 风险 | ✅ | 同意 | 但发现 4 项 🟡 Major (主 agent 未识别) |
| L2 dispatch 写入安全性 | 未提及 | 🟡 Major | 裸 `>>` 非原子写入，与 AC-11 的 L3 模式不一致 |
| dispatch stderr 可观测性 | 未提及 | 🟡 Major | `2>/dev/null` 吞掉失败根因 + 后台 `&>/dev/null` 吞掉执行日志 |

主 agent 在 REVIEW.md 中正确地识别了 AC 覆盖率 (11/11)、禁动清单合规性、DESIGN 决策符合性三项核心指标，但遗漏了 3 项代码层面的质量问题 (F1, F2, F3) 和 1 项声明准确性偏差 (F4)。

---

## Verdict

**pass** — 11/11 AC 覆盖，禁动清单无越界，6 项 DESIGN 决策全部实施正确。发现 3 项 🟡 Major (L2 非原子写入、dispatch stderr 被吞、Agent 后台日志丢失) 和 2 项 🟢 Minor (REVIEW.md 声明偏差、auto_advance 重定向冗余)。Major 项不影响功能正确性但降低可观测性和并发安全性，建议在后续 change 中修复。

---

## 主 agent 响应

### M1 · L2 dispatch 非原子写入 — Fixed in: l2-detect.sh

✅ mock 路径 + 真实 dispatch 路径均改为 tmp+mv 原子写入（与 L3 一致）。

### M2 · dispatch stderr 被吞 — Fixed in: independent-review-gate.sh

✅ `_gate_check_l2` line 234 去掉了 `2>/dev/null`，dispatch 失败时 stderr 正常输出。

### M3 · Agent 后台日志丢失 — Fixed in: l2-detect.sh

✅ `&>/dev/null & disown` 改为 `1>/dev/null 2>"${specs_dir}/.l2-dispatch-${phase}.log" & disown`，Agent stderr 写入专用日志文件。

### m4 · auto_advance 重定向矛盾 — Fixed in: independent-review-gate.sh

✅ `>&2 2>/dev/null` 改为直接调用（stderr 自然流出）。

全部语法检查 + bats 12/12 回归通过。
