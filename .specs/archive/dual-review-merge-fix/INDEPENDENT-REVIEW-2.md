# 独立审查 · 阶段 2

---

## L2 盲审（子 agent 独立审查 · 2026-07-07）

> 独立盲审，依据：DESIGN.md、REQUIREMENT.md、CONTEXT.md。不接受主 agent 自评/概述/辩护。

### 🟡 R1 · L2-only .done 依赖 prompt 层而非 hook 层硬防线：违反项目自身 "protect the weakest" 哲学

**Symptom（症状）**：DESIGN.md D3 段（line 70-72）。L2-only 模式下 `.done` 的 6 键 KVP 写入完全依赖主 agent 遵循 prompt 指令（"主 agent 已能读取 L2 子 agent 输出并提取 verdict"），备选方案 A（hook 层自动检测 L2 完成并写 .done）被以"需新增 hook 模块（复杂度↑）"为由否决。

**Source（源头）**：CONTEXT.md 已锁决策 `[2026-07-01]` gate-integrity — "Q1 防线定在 hook 层（非 prompt 层）—— agent 无法绕过 hook"；`[2026-06-25]` protect-the-weakest — "规则/prompt 默认按'最弱模型能扛住'写"。DESIGN 自身风险段也承认此依赖为"中概率"（R2，line 188："主 agent 不遵循 L2-only 的 KVP .done 写入指令（弱模型跳步）"）。

**Consequence（后果）**：弱模型丢弃或简化 `.done` KVP 写入指令 → 产物为空 `touch .done` → `done-validation.sh` 拒绝（fail-close 正确）→ pipeline 卡住。缓解链（SessionStart resume 检测 → 注入矫正 banner）增加了三跳依赖（prompt → agent 合规 → hook 检测 → SessionStart 矫正），比 hook 层直接写入多两跳。在 protect-the-weakest 框架下，prompt 层仅应做 first-line guidance，hard enforcement 应由 hook 层兜底。

**Remedy（修补）**：在 `29-independent-review.sh`（已触碰模块）中增加 L2-only 路径：检测到 gate_config="L2" 且 L2 段存在但 `.done` 缺失时，hook 直接写入 6 键 KVP `.done`（`written_by=stop-hook-29`），而非依赖主 agent prompt 合规。这与 D1（hook 层硬拦 L3）的设计哲学一致。若担心 Stop hook 在 L2-only 模式下不会触发（因为无 L3 待跑），可在 `independent-review-gate.sh` 的 PreToolUse forward 分支中也加入此逻辑。

```
# Before (DESIGN D3): 纯 prompt 指令
# "主 agent grep verdict → cat > .done"

# After: hook 层兜底写入
# 29-independent-review.sh 或 independent-review-gate.sh:
if [[ "$gate_config" == "L2" ]]; then
  if [[ -f "$review_md" ]] && grep -q "^## L2 盲审" "$review_md"; then
    if [[ ! -f "$done_file" ]]; then
      local l2_v=$(grep -m1 "^\*\*Verdict\*\*: *\(pass\|fail\)" "$review_md" | grep -o 'pass\|fail' || echo "fail")
      cat > "$done_tmp" <<DONE_EOF
phase=$phase
change_id=$change_id
written_by=stop-hook-29
L2_verdict=$l2_v
L3_verdict=skipped
artifacts=${review_md}:${done_file}
DONE_EOF
      mv "$done_tmp" "$done_file"
    fi
  fi
fi
```

---

### 🟡 R2 · L3 重复调用的资源浪费未被识别为风险：awk 剥离使文件内容幂等，但掩盖了 API 重复调用

**Symptom（症状）**：DESIGN.md 风险段（R1-R4，line 185-190）未列出 "L3 因 PreToolUse + Stop hook 双路径被重复调用" 的风险。数据流图 section 2 显示 L3 可经 PreToolUse（主路径）和 Stop hook 29（兜底）两条路径触发，但 DESIGN 未明确 Stop hook 在 L3 已执行时是否会跳过重复调用。

**Source（源头）**：CONTEXT.md 已锁决策 `[2026-07-03]` L3 同步调用策略 — "Stop hook 29-independent-review.sh 保留为兜底（处理 transition 前 session 异常终止的补跑场景）"。"补跑"语义暗示仅当 L3 未执行时才跑，但 DESIGN 未将此约束编码为 hook 层的显式检查。l3-review.sh 的 awk 剥离逻辑（R4 描述）使文件内容层面幂等（旧 L3 段被替换），但每次调用均消耗 API token/时间/费用。

**Consequence（后果）**：PreToolUse 成功跑完 L3 并写入 L3 段 + .done → 用户关闭终端（session 异常终止）→ Stop hook 检测到 L2 段存在 → 再次调用 L3 API。文件内容正确（awk 剥离→追加，无重复段），但多消耗了一次 API 调用（~30s + token 成本）。若 L3 模型为付费 API，多次发生会产生可量化的资源浪费。

**Remedy（修补）**：在 `29-independent-review.sh` 的 L3 调用前增加已有 L3 段检测：

```bash
# 在调用 l3_review_run() 之前：
if grep -q "^## L3 盲审" "$review_md" 2>/dev/null; then
  echo "[independent-review] L3 already present in $review_md, skipping re-run (fallback path)" >&2
  # 仅处理 .done 写入（若 L2 也完成）
else
  l3_review_run "$review_md" "$done_file" ...
fi
```

---

### 🟢 R1 · D1 决策文本不精确：仅提及 hook 29，未包含 PreToolUse gate，可能导致实施遗漏

**Symptom（症状）**：DESIGN.md D1 行（line 69）："29 号 hook 在 gate_config='both' 时检查 L2 段是否存在，不存在则跳过 L3 并拒绝写 .done"。AC-1（line 21）明确要求两个执行点均受约束："Stop hook 29-independent-review.sh 或 PreToolUse independent-review-gate.sh 尝试触发 L3"。

**Source（源头）**：REQUIREMENT.md AC-1；DESIGN section 2 数据流图正确展示了两个执行点（PreToolUse 和 Stop hook 均做 L2 检测），但 D1 决策表的文字总结遗漏了 PreToolUse 路径。

**Consequence（后果）**：实施者若仅读 D1 决策表（跳过了数据流图细节），可能只在 hook 29 加 L2-wait，遗漏 `independent-review-gate.sh` 的 forward 分支。PreToolUse 是 L3 的主路径（per `[2026-07-03]`），遗漏会导致主路径可绕过 L2-wait，使 AC-1 失效。

**Remedy（修补）**：修正 D1 选择理由段：
```
D1 | **L2-wait gating**：29 号 hook **与 independent-review-gate.sh (PreToolUse forward 分支)** 
在 gate_config="both" 时检查...
```

---

### 🟢 R2 · AC-5（跨阶段一致性）在 DESIGN 中缺少显式验证路径追踪

**Symptom（症状）**：DESIGN.md 未包含展示 6 个阶段（1/2/3/5/6/7）在三种模式下行为一致的兼容矩阵或验证计划。Section 0.5.2 沿用对照表引用了 `fk_independent_review_gate_active()` 做 phase_name 映射，但未逐阶段验证 gate_config 的 phase 键与实际文件路径的对应关系。

**Source（源头）**：REQUIREMENT.md AC-5（line 47-51）要求所有阶段一致行为，含逐阶段 bats 验证。

**Consequence（后果）**：阶段 3（task）和阶段 7（integration）是 gate_config 3-5-7 扩展后新增的审查范围（per `[2026-07-02]` independent-review-gap），这两个阶段的文件命名约定（如 `INDEPENDENT-REVIEW-3.md` vs `INDEPENDENT-REVIEW-7.md`）或交互模式可能与 1/2/6 有细微差异。若不逐阶段追踪，实施可能漏掉阶段特定代码路径。

**Remedy（修补）**：在 DESIGN section 2 或新增 section 添加兼容矩阵：

| 阶段 | INDEPENDENT-REVIEW 文件 | gate_config key | both 行为 | L2-only 行为 | L3-only 行为 |
|------|------------------------|-----------------|-----------|-------------|-------------|
| 1    | INDEPENDENT-REVIEW-1.md | 1-requirement | AC-1~4 | AC-6 | AC-7 |
| ...  | ...                    | ...             | ...       | ...         | ...         |

---

### 🟢 R3 · 既有 .done 文件向后兼容未列入风险：语义漂移而非功能回归

**Symptom（症状）**：DESIGN 风险段（line 185-190）未提及修复前已存在的 `.done` 文件兼容性。修复前 L3-only 模式写入的 `.done` 中 `L2_verdict=fail`（旧默认），修复后同场景写入 `L2_verdict=skipped`（D2 修正）。

**Source（源头）**：DESIGN D2（line 70）修改了 `l2_verdict` 默认值；CONTEXT.md 已锁决策 `[2026-07-07]` dual-review-merge-fix。

**Consequence（后果）**：旧 `.done` 文件中 `L2_verdict=fail` 在 L3-only 场景下语义不精确（L2 是未启用而非失败），但 `done-validation.sh:137` 的值域正则已同时接受 `pass|fail|skipped`，故旧文件仍通过校验。功能无回归，仅语义漂移——下游消费者（如 30-ai-analyze.sh）若区分 `fail` vs `skipped` 语义，可能误读旧文件。

**Remedy（修补）**：在 DESIGN 风险表或 section 6 "不在范围" 后追加一条说明：
```
R5 | 旧 .done 文件中 L2_verdict=fail（L3-only 场景）语义不精确 | 下游分析误判 | 极低 | 
`done-validation.sh` 校验通过，无功能回归。旧文件数量有限且随 pipeline 推进自然被覆盖。
无需迁移脚本。
```

---

**Verdict**: pass

> 审查总结：DESIGN 在核心架构决策（D1 L2-wait gating、D2 skipped 默认值、D4 append-first）上严谨对齐 REQUIREMENT.md 的 8 条 AC。主要发现集中在 D3（L2-only .done 依赖 prompt 层而非 hook 层），这与项目自身的 protect-the-weakest + gate-integrity 的 hook-as-hard-defense 原则存在张力。建议在 v1 中加入 hook 层兜底写入，或在 DESIGN 中明确记录此技术债并承诺 v2 修复。其余为文档精度问题，不影响设计的正确性和完整性。

---

## 主 agent 反驳

### 🟡 R1（D3 protect-the-weakest）→ 接受核心论点，v1 不改方案但加固两层防线

L2-only `.done` KVP 确实应有两层防线。但 v1 已有两层，无需新增 hook 模块：

1. **prompt 层**（主 agent 指令）：告知主 agent 写 6 键 KVP `.done`（含 `L3_verdict=skipped`）。这是 first-line guidance。
2. **hook 层**（`done-validation.sh` fail-close）：即使主 agent 跳过 prompt 指令、写了空 `touch .done`，`fk_validate_done_marker()` 的 Tier 1 校验（≥6 行 + KVP 完整 + 值域合法）绝对拒绝。**空 `.done` 无法绕过 transition**。

这符合 protect-the-weakest 的分层防御（prompt 引导 + hook 硬拦），与 gate-integrity 的 `touch .done → 拒绝` 模式一致——`done-validation.sh` 正是为此设计的。R1 的担忧（弱模型跳步写空 .done）在 hook 层已被拦截。

**但接受建议**：在 v1 实施时，若 `29-independent-review.sh` 改动量允许，加入 L2-only 的 `.done` 兜底写入（R1 的 Remedy 伪代码可直接用）。这比新增独立模块成本低（复用现有 l3-review.sh 的 KVP 写入模式）。

### 🟡 R2（L3 重复调用）→ 已在现有代码处理，无需额外设计

`29-independent-review.sh:62-64` 在调用 L3 前先查 `.done` 是否存在 → 已存在则直接 exit 0。PreToolUse 成功后 `.done` 已写入 → Stop hook 完全跳过。唯一未覆盖场景是"L3 段存在但 .done 缺失"（both 模式 L2 未完成 → D1 阻止 L3 运行，此场景下无 L3 调用，不存在浪费）。

### 🟢 三条 Minor → 全部接受

- R1（D1 文本遗漏 PreToolUse）：已修正 DESIGN.md D1 决策描述，明确覆盖 29 号 hook + PreToolUse forward 两路径
- R2（缺少兼容矩阵）：将在 3-task 阶段生成测试矩阵时覆盖（非 DESIGN 层职责）
- R3（旧 .done 语义漂移）：已在 DESIGN § 5 追加 R5 风险记录

---

## L3 盲审（deepseek-v4-flash[1m] 外部模型 · 2026-07-07 02:09）

> 自动生成于 2026-07-07 02:09。由 l3-review.sh 写入。

### 审查结论

```json
{"critical":[],"major":[{"file":".specs/adr/002-l3-frontloading.md","issue":"未明确 PreToolUse hook 的触发时机与失败处理策略","why":"工件描述 L3 调用从 Stop hook 搬到 PreToolUse hook，但未说明该 hook 是仅在 transition 时触发还是每次 tool use 都会触发；同时未定义 API 调用失败（超时/网络错误/模型返回异常）时的处理流程，仅含糊提及"Stop hook 保留作兜底"，可能导致多次调用、资源浪费或 pipeline 阻塞。","fix":"显式说明 PreToolUse hook 的触发条件（例如仅在 pipeline stage transition 时调用一次），并补充明确的失败回退策略：如重试机制、超时阈值、以及当 PreToolUse 失败时如何降级至 Stop hook 兜底。"}],"minor":[{"file":".specs/adr/001-protect-the-weakest.md","issue":"opt-out 机制依赖用户声明 model_tier，未考虑误声明或遗忘的风险","why":"决策中强模型用户通过显式声明 model_tier: strong 触发轻量模式，但未讨论用户误将弱模型声明为 strong 导致安全降级，或忘记声明导致强模型被不必要加严的情况。这对实际使用的可靠性有潜在影响。","fix":"可考虑增加可选的自动模型能力探测作为辅助校验，或在文档中明确建议用户严格按实际模型声明 tier。"}],"verdict":"pass","summary":"ADR-002 解决了关键死锁问题，决策合理，但缺少 PreToolUse hook 的详细触发与容错设计；ADR-001 哲学方向正确，opt-out 机制留有轻微风险。无 critical 缺陷。"}
```
