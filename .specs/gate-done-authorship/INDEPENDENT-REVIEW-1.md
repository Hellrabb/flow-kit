# 独立审查 · 阶段 1

## L2 盲审

> 审查日期：2026-07-24 | 审查人：L2 独立盲审员（子 agent） | 工件：REQUIREMENT.md（参考 CHANGE.md）

---

### 🟡 R1 · gate_config="both" 模式下 `.done` 生命周期未完整指定
**Symptom（症状）**：REQUIREMENT.md AC-2 指定 L3 的 `l3_review_run` 在 verdict=pass 时写入 `.done`，AC-4 指定 L2-only 模式下主 agent 写 `.done`。但 gate_config="both"（L2 审查 + L3 审查均要求）的模式下，`.done` 写入权的交互未覆盖：若 L2 完成但 L3 尚未运行或 L3 verdict=fail，主 agent 能否单独写入 `.done` 绕过 L3？AC-1 禁 agent 写 `.done` 的条件是 gate_config="L3 或 both"——这与 AC-4 的 L2-only 放行一致。但 "both" 模式下 L2 完成后、L3 运行前的窗口期，agent 写 `.done` 会被 AC-1 的 path-guard 拦截（正确行为），**但 REQUIREMENT 没有明确声明这一点**，也未规定 L3 verdict=fail 时 pipeline 应停在哪个 phase、是否允许人工 override。

**Source（源头）**：GWT 完整性原则——Given 必须明确系统所处状态的所有可能值（gate_config ∈ {L2, L3, both}），When 必须覆盖该状态下的所有关键分支。当前 AC-1 和 AC-4 覆盖了 L3-only 和 L2-only，但 "both" 的中间状态（L2 done + L3 pending, L2 done + L3 fail）缺少显式 AC。

**Consequence（后果）**：DESIGN 阶段可能对 "both" 模式下的 `.done` 写入时序做出与 REQUIREMENT 隐含假设不一致的决定；TEST 阶段可能遗漏 "both" 模式下的 bypass 测试用例；最坏情况：agent 在 "both" 模式下利用 L2 完成后 L3 运行前的时间窗口写入 `.done` 绕过 L3（虽然 AC-1 的 path-guard 字面上拦截此操作，但缺少显式测试用例覆盖此场景）。

**Remedy（修补）**：在 REQUIREMENT 中新增一条 AC，覆盖 gate_config="both" 的完整生命周期：
```
### AC-8 · gate_config="both" 下 agent 不可绕过 L3 写入 .done

- Given gate_config 对某阶段设置为 "both"（L2 已完成，L3 尚未运行或 verdict=fail），且 .done 不存在
- When 主 agent 尝试写入 .independent-review-<N>.done
- Then PreToolUse hook path-guard 拦截（exit 2），与 gate_config="L3" 行为一致；pipeline transition 被 done-validation 拦截（exit 4）
- 验证方式: npx bats test/test_gate_integrity.bats — 新增 both-mode bypass 测试
```
注意：若 DESIGN 最终判定 "both" 模式下 `.done` 必须由 L3 写入（agent 在任何情况下都不可写），则 AC-1/AC-4/AC-8 统一为：agent 仅在 gate_config="L2" 时可写 `.done`，其余模式一律禁止。此简化有利于降低实现复杂度，建议 REQUIREMENT 明确定向。

---

### 🟡 R2 · 安全威胁模型枚举被完全推迟到 DESIGN
**Symptom（症状）**：REQUIREMENT.md 非功能性需求·安全段写 "核心安全需求已在 AC-1/AC-4/AC-6 中覆盖——.done 作者性校验必须基于机制保证（path-guard + done-validation），不可依赖 agent 自律"。但未枚举 agent 可能绕过 `.done` 作者性校验的**所有路径**，包括：(a) 直接写 `.done`（AC-1 覆盖），(b) 在子目录写 `.done` 后 mv 到目标路径，(c) git checkout 恢复先前 session 的合法 `.done`，(d) symlink 攻击，(e) 修改 hook 代码本身关闭 path-guard，(f) 在 L2-only 模式下伪造 L3 verdict（因为 L2-only 模式 agent 有写权限）。

**Source（源头）**：OWASP ASVS V1.2.1 —— 安全需求应基于威胁建模，覆盖所有信任边界。CHANGE.md :97-100 声明 "2-design 新增 gate .done 作者性模型 ADR（方案 A vs B 抉择 + 威胁模型：agent 伪造 .done 的所有路径 + L2-only 例外处理）"，但 REQUIREMENT 本身未列出威胁清单——这意味着验收准则仅覆盖了 DESIGN 阶段决策者已知的威胁，而不是独立的、可审计的安全需求基线。

**Consequence（后果）**：DESIGN 阶段可能遗漏特定 bypass 路径（尤其是 b/c/d 这类间接操作）；TEST 阶段的集成测试（AC-6）只覆盖直接 Bash 写入，可能遗漏 mv/symlink/git-restore 路径；安全审计时无法从 REQUIREMENT 直接判断覆盖完整性。

**Remedy（修补）**：在 REQUIREMENT 非功能性需求·安全段下增加威胁枚举小节，形式如下：
```
### 威胁清单（agent 绕过 .done 作者性校验的路径）

| # | 绕过路径 | 对策归属 | 是否本 change 覆盖 |
|---|---------|---------|-------------------|
| T1 | Bash/Write/Edit 直接写 .done | path-guard D7 拦截 | 是 (AC-1/AC-6) |
| T2 | 子目录写后 mv 到目标 | path-guard 拦截 mv 目标匹配？需 DESIGN 定 | 待 DESIGN 判定 |
| T3 | git checkout 恢复旧 .done | path-guard 拦截 git checkout 目标匹配？ | 待 DESIGN 判定 |
| T4 | symlink 指向伪造 .done | done-validation 读 .done 内容验作者性 | 待 DESIGN 判定 |
| T5 | 修改 hook 代码关闭 path-guard | 超出本 change 范围（需代码完整性校验） | out |
| T6 | L2-only 模式下伪造 L3_verdict | done-validation 读 gate_config + .done 内容一致性 | 待 DESIGN 判定 |
```
对于 DESIGN 判定 "out" 的路径，在 DESIGN.md 中记录风险接受声明。

---

### 🟢 R3 · AC-3 和 AC-5 的 "When" 条件是过程里程碑，非可观测行为
**Symptom（症状）**：AC-3:22 "When 本 change 实施完成"，AC-5:24 "When 本 change 实施完成"——这两个 When 描述的是开发过程事件，不是被测系统在给定输入下的可观测行为。GWT 范式的 When 应描述触发被验证行为的具体操作或条件。

**Source（源头）**：GWT 写作规范——When 必须是可执行的操作或可观测的系统状态变更，不是项目里程碑。"When the implementation is complete" 等价于 "When someone tells you it's done"，不可机器验证。

**Consequence（后果）**：测试编写者需要自行推断 When 的含义（"执行 grep 验证死代码已删除吗？还是执行 bats 测试？"），增加沟通成本。AC-3 已有明确的 grep 验证方式，AC-5 已有 bats 验证方式——When 的模糊性不影响可验证性，但降低规范的严谨性。

**Remedy（修补）**：
- AC-3 When 改为：`When 执行死代码清理验证（grep -r "is_handshake_write\|state_file\|written_by=stop-hook-29\|T3.*handshake" flow-kit-bundle/hooks/）`
- AC-5 When 改为：`When 执行既有握手测试（npx bats test/test_gate_integrity.bats 中对应的握手测试用例）`

---

### 🟢 R4 · 性能 NFR 缺乏量化基线
**Symptom（症状）**：REQUIREMENT.md :104 "性能: 无（path-guard 拦截为 PreToolUse hook 同步执行，新增逻辑 ≤ 10 行 bash，延迟可忽略）"——"无" 随后又给出了非量化的 "≤ 10 行" 和 "可忽略" 判断。"10 行 bash" 不是性能指标，"可忽略" 不是可度量的阈值。

**Source（源头）**：非功能性需求应可量化验证。"可忽略" 是主观判断，不是需求。

**Consequence（后果）**：无法在 TEST 阶段验证性能是否合格；若未来 path-guard 逻辑增长（如扩展到 D7 其他敏感文件，v2 范围），没有基线可供回归对比。

**Remedy（修补）**：给定量化阈值（即使很宽松），例如：
> 性能: PreToolUse hook 的 path-guard 新增检查延迟 < 5ms（wall-clock，在典型 Linux 环境单次 jq 调用计），不对 PreToolUse hook 整体执行时间产生 > 5% 的回归。

---

### 🟢 R5 · AC-3 包含对 DESIGN 阶段决策的条件依赖
**Symptom（症状）**：AC-3 :29 "`independent-review-gate.sh` 的 `is_handshake_write`（L30）— 若方案 A 则删；若方案 B 则保留并修复"——验收准则中出现 "若方案 A 则…若方案 B 则…" 的条件分支，意味着 AC 本身在 REQUIREMENT 阶段不完整；其对 "通过" 的判定取决于 DESIGN 阶段的二选一结果。

**Source（源头）**：验收准则应在 REQUIREMENT 阶段完整确定。AC 含未决选项意味着 REQUIREMENT 的某些部分还未完成——这归属于 DESIGN 阶段（REQUIREMENT.md :128 本身也承认 "方案 A vs B 的最终选择在 DESIGN 阶段做出"）。

**Consequence（后果）**：REQUIREMENT 作为验收基线不完整；若 DESIGN 阶段选择了方案 B，AC-3 的 Then 段中部分条目（"若方案 A 则删"）自动失效，但 AC-3 整体仍是 "pass"——这制造了验收准则的内部不确定性。

**Remedy（修补）**：两种处理方式：
1. 将方案选择提前到 REQUIREMENT 阶段做完（即 REQUIREMENT 就直接指定方案 A），AC-3 变为确定性描述；或
2. 将 AC-3 拆为 AC-3a（方案 A 的清理范围）和 AC-3b（方案 B 的清理范围），DESIGN 选定方案后，对应的 AC 子集生效，另一组标记为 "not-applicable"。
推荐方式 1——CHANGE.md 已明确推荐方案 A，REQUIREMENT 可据此锁定。

---

### 🟢 R6 · AC-2 "When" 措辞可能混淆 hook 拦截与操作完成的时序
**Symptom（症状）**：AC-2 :21 "When pipeline transition 执行（jq 写 `.flow-active.phase`）"——在 PreToolUse hook 架构中，done-validation 在工具**执行前**运行（这是 hook 的基本语义）。当前措辞 "transition 执行" 可能被误读为 "transition 已经完成"，而实际触发点是 "agent 发起 transition 操作时，PreToolUse hook 触发 done-validation"。

**Source（源头）**：精准性——AC 的 When 应匹配系统的实际触发时序，避免给 TEST 阶段留下 "transition 执行后才校验" 的错误印象。

**Consequence（后果）**：测试编写者可能错误地设计测试场景（先让 transition 完成，再检查拦截——这不可行，因为 hook 是同步拦截的）。实际发生的可能性低（测试编写者熟悉 hook 机制），但措辞不够严谨。

**Remedy（修补）**：When 改为：
> When 主 agent 发起 pipeline transition（即将通过 jq 写入 `.flow-active.phase`），PreToolUse hook 触发 done-validation

---

### 🟢 R7 · 缺少 fail-safe 行为规范（path-guard 宕机时的默认行为）
**Symptom（症状）**：REQUIREMENT.md 未规定 path-guard 或 done-validation 自身执行失败（如 jq 不可用、文件系统错误、hook 自身 bug）时的行为——是 fail-open（放行，允许业务继续但安全降级）还是 fail-closed（拦截，安全优先但可能阻塞合法操作）？

**Source（源头）**：安全需求中的 fail-safe 原则——安全机制失效时的默认行为必须是安全状态（通常是 deny-by-default）。REQUIREMENT 中 AC-1 指定了拦截行为（exit 2 deny），但未指定 hook 自身错误（如 jq 解析失败）时的退出码和结果。

**Consequence（后果）**：若 hook 因 bug 或环境问题 exit 0（等价于放行），主 agent 可能利用 "使 hook 失败" 的方式绕过 path-guard（如传入超大 payload 导致 jq OOM，若 jq 失败后 hook 未正确 exit 非零，则工具调用被放行）。

**Remedy（修补）**：在非功能性需求·安全段增加：
> Fail-safe: path-guard 和 done-validation 的任何非预期错误（jq 解析失败、文件不可读、未知 gate_config 值）均导致 deny（exit 非零），不得 fall through 到放行。具体错误码由 DESIGN 分配。

---

**Verdict**: pass

---

## L3 重审（deepseek-v4-flash[1m] 外部模型 · 2026-07-24 02:15）

> 自动生成于 2026-07-24 02:15。由 l3-review.sh 写入。

### 审查结论

```json
{
  "critical": [
    {
      "file": "REQUIREMENT.md（阶段1）",
      "issue": "AC-3 的 Then 描述与验证方式矛盾：该 AC 列出了 `is_handshake_write`（L30）的清理规则为“若方案 A 则删；若方案 B 则保留并修复”，但验证方式要求 `grep` 在生产代码中无匹配。若最终采用方案 B，`is_handshake_write` 会被保留，则 `grep` 必然匹配，导致 AC 无法验证。",
      "why": "验收准则必须可验证且无歧义，该矛盾使 AC-3 的 Then 条件与验证方式不兼容，评审者或测试者无法确定满足 AC 的标准。",
      "fix": "明确最终方案（例如统一为方案 A，或在 DESCRIPTION 阶段确定后），并相应调整 AC-3 的 Then 描述与验证方式，确保一致性。可选项：若方案 B，则验证方式改为检查 `is_handshake_write` 是否按修复要求存在于指定位置且语义正确，而非全仓无匹配。"
    }
  ],
  "major": [],
  "minor": [
    {
      "file": "REQUIREMENT.md（阶段1）",
      "issue": "AC-5 中“改写后的测试全部通过”未明确改写后的测试数量或标识，虽不致命但降低可追溯性。",
      "why": "验收准则应尽量具体，便于测试执行时确认是否覆盖了所有改写项。",
      "fix": "建议在 AC-5 的 Then 中列举改写后的测试编号（如 `AC-1_③, AC-1_④, AC-1_⑤, D9`）或语义标识。"
    }
  ],
  "verdict": "fail",
  "summary": "AC-3 存在自身矛盾（清理规则与验证方式不匹配），导致该验收准则不可验证，故判定为 fail。其他 AC 可验证且范围切分合理，无重大遗漏。"
}
```

L3_artifact_hash: a1e558c4555c8d41fa6856c2e29e0bd372de16c4f9fdf2e3dce8f2aca051c1bc

---

## L3 重审（deepseek-v4-flash[1m] 外部模型 · 2026-07-24 02:18）

> 自动生成于 2026-07-24 02:18。由 l3-review.sh 写入。

### 审查结论

```json
{"critical":[],"major":[],"minor":[{"file":"工件（阶段1）中的AC-1","issue":"验证方式中指定了bats测试文件，但未给出具体的测试用例编号或标识，导致验证时难以对应特定AC。","why":"AC要求可验证且无歧义，缺失测试标识可能使得不同实现者或验证者对同一AC产生不同理解。","fix":"为AC-1、AC-2、AC-4、AC-5等引用bats的AC明确指定测试用例ID（如TEST-1），或在工件中说明DESIGN阶段会补充，当前阶段可接受。"},{"file":"工件（阶段1）中的AC-5","issue":"AC-5要求既有握手测试全部改写或删除，验证方式仅列出bats测试，未要求检查是否有测试被遗漏或删除。Given明确列出4个测试，但Then的验证仅依赖bats输出，可能无法覆盖所有握手测试被正确处理的用例。","why":"如果某个握手测试未被改写但未通过bats（例如被注释掉或改名），bats可能不会报错，造成AC-5不完整验证。","fix":"增加验证步骤：grep检查测试文件中是否还有`written_by=stop-hook-29`等废弃字符串，或者明确要求所有列出的测试必须被改写/删除，并列出它们的新ID。"}],"verdict":"pass","summary":"AC结构清晰，范围切分合理，无critical问题。存在少量验证指代不明确（未指定测试ID）和一个AC验证覆盖可能不足的minor问题，但不影响整体通过。"}
```

L3_artifact_hash: e80ea71c40f1c5735054655a9a422c08c44e6f799bbaf9112f315dd458a100f1
