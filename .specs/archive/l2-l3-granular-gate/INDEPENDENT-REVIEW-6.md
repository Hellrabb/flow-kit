# 独立审查 · 阶段 6

## L2 盲审

- **Verdict**: fail
- **Severity**: Critical
- **Finding**: `fk_check_gate_config_tamper` in `independent-review-gate.sh` (lines 54, 57) was NOT updated for the new gate_config values `L2`, `L3`, `both`. The tamper detection queries the snapshot with `select(.value == "independent" or .value == "true")`, which silently ignores keys whose value is `L2`, `L3`, or `both`. A malicious agent could change gate_config from `"both"` to `""` or `"false"`, and the tamper detection would not catch the modification because the key was never included in the comparison set. This is a security regression introduced by this diff: the D8 threat model (agent tampers gate_config to skip review) is partially unguarded for all changes that use the new values. The existing regression test at `test/regression-demos/gate-config-tamper/check.sh` tests only `"independent"` -> `"false"`, which is why this regression was not caught.
- **Recommendation**: Update line 54 to accept all valid gate_config values. Change the jq select from:
  ```
  select(.value == "independent" or .value == "true")
  ```
  to:
  ```
  select(.value == "independent" or .value == "true" or .value == "L2" or .value == "L3" or .value == "both")
  ```
  And update line 57 from:
  ```
  [[ "$cur" != "independent" && "$cur" != "true" ]]
  ```
  to:
  ```
  [[ "$cur" != "independent" && "$cur" != "true" && "$cur" != "L2" && "$cur" != "L3" && "$cur" != "both" ]]
  ```
  Additionally, extend the regression test in `check.sh` to cover `"both"` -> `""` (or `"L3"` -> `"false"`) tamper scenarios.

---

- **Verdict**: fail
- **Severity**: Critical
- **Finding**: `32-fallback-guard.sh` line 57 hardcodes a check for the old value: `jq -e '.goal.gate_config["7-integration"] // "" | . == "independent"'`. When `gate_config["7-integration"]` is set to `L2`, `L3`, or `both` (any of the new values), this jq expression evaluates to false, so the guard's PCSC check (`[ -f "${spec_dir}/.independent-review-7.done" ]`) is never reached. This means the fallback guard will allow the pipeline to reach `goal.status = "done"` even when the independent review at phase 7 is still incomplete under the new value system. It is an effective gate bypass for the fallback mode at the pipeline endpoint.
- **Recommendation**: Change the jq expression from a single-value equality check to a set membership check:
  ```
  jq -e '.goal.gate_config["7-integration"] // "" | . as $v | $v == "independent" or $v == "true" or $v == "L2" or $v == "L3" or $v == "both"' "$flow_file" >/dev/null 2>&1
  ```
  Alternatively, call `fk_independent_review_gate_active "7"` (the no-tier form) to reuse the centralized compatibility logic instead of duplicating value checks.

---

- **Verdict**: fail
- **Severity**: Major
- **Finding**: `l3-review.sh` line 47 validates `l2_verdict` with `[[ "$l2_verdict" =~ ^(pass|fail)$ ]]`, which rejects the value `"skipped"`. This creates an inconsistency with `done-validation.sh` lines 137 and 139, which were updated in this very diff to accept `"skipped"` for L2_verdict and L3_verdict. As a result, the shared L3 library cannot produce a `.done` file with `L2_verdict=skipped`, even though the done-marker validator will accept it. This mismatch means that the `"skipped"` value added in this diff cannot flow through the full pipeline from creation (`l3-review.sh`) to validation (`fk_validate_done_marker`).
- **Recommendation**: Extend the regex on line 47 to `[[ "$l2_verdict" =~ ^(pass|fail|skipped)$ ]]`. However, note that this interacts with Finding #5 below -- the callers of `l3-review.sh` (29-independent-review.sh and independent-review-gate.sh) both default l2_verdict to `"fail"` rather than `"skipped"` in L3-only mode, so expanding the regex alone is insufficient. Both callers should be updated to detect whether L2 is active and pass `"skipped"` when it is not.

---

- **Verdict**: fail
- **Severity**: Major
- **Finding**: The test cases `"L2_verdict=skipped is accepted (L3-only mode)"` and `"L3_verdict=skipped is accepted (L2-only mode)"` at lines 140-177 of `test_l2_l3_granular_gate.bats` suffer from a false positive. Both tests configure the `.flow-active` file with `"phases_done": ["6"]`, which triggers the `phases_done` shortcut in `fk_validate_done_marker` at line 114 (`[[ "$in_done" != "0" ]] && return 0`). The function returns 0 before ever reaching the L2_verdict/L3_verdict regex validation at lines 136-139. The tests pass because of the shortcut, not because the actual `"skipped"` value is accepted by the regex. This means the `"skipped"` value addition at lines 137 and 139 is effectively untested for the validation path.
- **Recommendation**: Remove `"6"` from the `phases_done` array in both test `.flow-active` fixtures (or set it to `[]` / a different phase), so that `fk_validate_done_marker` does not take the shortcut and actually exercises the new `skipped` regex branches at lines 137 and 139. This will also catch the interaction with Finding #4 (the `session_id` cross-check may need `CLAUDE_CODE_SESSION_ID` set in the test environment, or the test should use `tier="write"` which stops before the session-id check at line 159).

---

- **Verdict**: pass
- **Severity**: Minor
- **Finding**: `29-independent-review.sh` line 78 defaults `l2_verdict="fail"` before attempting to extract it from the L2 section of the review markdown. In L3-only mode (gate_config = `"L3"`), the L2 dispatch section in the prompts is skipped (the detection pattern `{L2,both}` excludes `"L3"`), so no `## L2 盲审` section is written. The grep at line 79 fails to match, and `l2_verdict` remains `"fail"`. This is semantically incorrect: L2 was intentionally skipped, not failed. The conservative default of `"fail"` is the safer choice (fail-closed), but it produces misleading artifact content (the L2 verdict in the `.done` file says "fail" when no L2 review occurred at all). This is currently "bug-compatible" with Finding #3 because `l3-review.sh` rejects `"skipped"`.
- **Recommendation**: After fixing Finding #3, add L2-active detection before line 78: call `fk_independent_review_gate_active "$phase" "L2"` to determine whether L2 is expected. If not active, set `l2_verdict="skipped"`. If active and the L2 section is missing, retain the `"fail"` default (missing expected L2 review is a real failure).

---

- **Verdict**: pass
- **Severity**: Minor
- **Finding**: All 6 prompt files (1-requirement.md, 2-design.md, 3-task.md, 5-test.md, 6-review.md, 7-integration.md) correctly update the L2 dispatch detection pattern from `{independent,true}` to `{L2,both}`. The backward compat parenthetical `(independent/true 向后兼容映射为 both)` is present and consistent across all 6 files. However, this backward compat mapping is purely a textual instruction to the LLM -- it relies on the LLM correctly interpreting that a gate_config value of `"independent"` or `"true"` should also trigger the L2 dispatch. If the LLM reads the gate_config value literally (e.g., using jq and comparing against "L2" or "both" without manual interpretation), it would fail to trigger L2 dispatch for old `"independent"`/`"true"` values. This is partially mitigated by the hook-level enforcement (PreToolUse gate, Stop hooks) which use the centralized `fk_independent_review_gate_active` function with proper mapping, but the L2 review output (INDEPENDENT-REVIEW-<N>.md contents) would be missing for old-value configurations if the LLM takes the literal route.
- **Recommendation**: Consider adding an explicit instruction in the prompt for the LLM to use the mapping -- e.g., instruct it to treat `"independent"` and `"true"` as equivalent to `"both"` when checking the condition. Alternatively, the LLM could call `fk_independent_review_gate_active` itself if shell access is available in the prompt context.

---

- **Verdict**: pass
- **Severity**: Minor (design observation)
- **Finding**: The backward compatibility mapping in `done-validation.sh` (lines 65-68: `independent|true) gate_val="both"`) is correct and complete. The tier filtering (lines 74-78) correctly gates L2 and L3 independently. The `fk_independent_review_gate_active` calls from existing consumers (`flow-kit-artifacts.sh:111`, `31-auto-advance.sh:71`, `independent-review-gate.sh:148`) all omit the tier parameter, which uses the default `""` (any tier active) -- this is the correct backward-compatible behavior because these callers need to block phase advancement regardless of which tier(s) are active. The L3-specific call in `29-independent-review.sh:33` correctly passes `"L3"` as the tier parameter. The test at `test_l2_l3_granular_gate.bats` lines 37-136 correctly covers: "independent" -> both mapping, "true" -> both mapping, invalid -> off, L2-only (L2=active, L3=inactive), L3-only (L3=active, L2=inactive), both mode, no gate_config, and invalid phase rejection. The done-marker validation at lines 136-139 correctly extends the L2_verdict value domain to include "skipped" (for L3-only mode) and the L3_verdict value domain to include "skipped" (for L2-only mode).

---

## Overall verdict

`L2_verdict=fail`

**Summary**: The core value-mapping and tier-filtering logic in `done-validation.sh` is correct and well-tested. The 6 prompt files are consistently updated. The `29-independent-review.sh` L3 skip correctly uses the new tier API. However, the diff introduced two CRITICAL regressions by not updating all direct consumers of gate_config values:

1. **`fk_check_gate_config_tamper`** (tamper detection) only tracks old values -- new values bypass the detection entirely.
2. **`32-fallback-guard.sh`** only triggers on the old `"independent"` value -- new values are invisible to the guard.

Two MAJOR issues were also found: `l3-review.sh` rejects the `"skipped"` verdict value that `done-validation.sh` now accepts (internal inconsistency), and the "skipped" verdict tests are false positives (phases_done shortcut bypasses the actual validation logic being tested).

All findings must be resolved before this diff can pass review.

---

## L3 盲审（外部模型 · 2026-07-06）

### 审查结论

```json
{"verdict":"fail","summary":"L2-only 模式存在架构级完成路径缺失：无组件可生成 .done 标志，导致 L2-only 模式无法推进阶段或执行 git commit/PR create。PreToolUse hook 的 L3 同步路径忽略 tier 参数，即使配置为 L2-only 仍强制调用 L3 API 并写入 .done 标志，使独立 L2 模式无法实现。向后兼容映射（independent/true → both）正确但不够完备；32-fallback-guard.sh 正则将 L2 排除在外。L3-only 模式下 L2_verdict 错误地默认设为 fail 而非 skipped。否定消息在所有 tier 配置下固定显示 'L2 + L3'，在 L2-only 或 L3-only 模式下产生误导。"}
```

### 发现

- **严重度**: Critical
- **发现**: L2-only 模式缺少 .done 标志完成路径。当 `gate_config[phase] = "L2"` 时：29-independent-review.sh 调用 `fk_independent_review_gate_active "$phase" "L3"` 返回 1（不活跃）并跳过执行；无其他组件写入 `.independent-review-{phase}.done`。PreToolUse hook (`independent-review-gate.sh:151`) 调用 `fk_independent_review_gate_active "$phase"`（无 tier 参数），对于 L2 返回 0，然后尝试验证 .done——因不存在而失败。对于 git commit / gh pr create（非阶段写入命令），流程直接进入第 239 行的 deny 段，不可能完成。对于阶段向前推进，第 207 行的 L3 同步路径调用 `l3_review_with_timeout`，该函数调用外部模型 API 并写入包含真正 L3_verdict 的 .done——但这与 L2-only 语义完全矛盾。结果是 L2-only 模式要么永久死锁（commit/PR），要么在用户不知情或未同意的情况下静默运行 L3（阶段推进）。
- **建议**: 引入替代完成路径。选项 A：在 `29-independent-review.sh` 的 L3 gate 检查失败时，回退写入 L3_verdict=skipped 的 .done 标志。选项 B：创建专用的 `28-independent-review-l2.sh` stop hook，在 L2-only 模式下运行并写入 .done。在任何一种情况下，PreToolUse hook 阶段推进 L3 同步路径都必须检查 `fk_independent_review_gate_active "$phase" "L3"`，并仅在 L3 或 both 模式下调用 `l3_review_with_timeout`。

- **严重度**: Critical
- **发现**: PreToolUse hook 第 207 行的 L3 同步路径忽略 gate_config tier。在 `independent-review-gate.sh` 第 193-213 行，当 L2 审查存在且 agent 尝试阶段向前推进时，代码无条件调用 `l3_review_with_timeout`。仅在调用后才重试 `.done` 校验。这意味着即使 `gate_config[phase] = "L2"`，PreToolUse hook 仍会针对阶段向前推进触发 L3 API 调用。`l3_review_run` 随后写入包含真正（已运行）L3_verdict 的 .done 标志，而该标志随后通过 Tier 2 校验——结果实际上如同配置为 both 一样。"L2-only" 模式无法通过阶段推进代码路径实现。
- **建议**: 在第 193 行之前增加一次专门检查：`if fk_independent_review_gate_active "$phase" "L3"; then`，仅在该条件成立时才执行 L3 同步。若仅启用 L2，则改为写入 L3_verdict=skipped 的 .done 标志，或直接放行阶段推进（因为 L2-only 模式下 L2 即满足条件）。

- **严重度**: Major
- **发现**: 32-fallback-guard.sh 第 57 行的正则表达式 `^(both|L3|independent|true)$` 排除了 `"L2"`。当 gate_config["7-integration"] = "L2" 时，if 条件为 false，`.independent-review-7.done` 检查被跳过。这实际上是 L2-only 管道不产生 .done 标志这一 bug 的权宜绕过，但它意味着对于 L2-only 模式，fallback guard 完全不执行独立审查——管道可直接到达 goal.status="done"，而无需检查 L2 审查是否完成。这与 L2-only 语义（L2 审查应作为 gate 条件）相矛盾。
- **建议**: 将 `L2` 加入正则表达式：`^(both|L3|L2|independent|true)$`，同时确保在 L2-only 模式下有完成路径（见 #1 修复）。或者，改用 `fk_independent_review_gate_active` 函数来复用集中式 tier 逻辑，而非在 hook 内重复值检查。

- **严重度**: Major
- **发现**: L3-only 模式下存在 L2_verdict 语义错误。在 `29-independent-review.sh` 第 78-82 行，l2_verdict 默认设为 `"fail"`，随后仅在从 INDEPENDENT-REVIEW-<N>.md 成功提取 L2 审查 verdict 时才更新。在 L3-only 模式下（gate_config = "L3"），L2 dispatch 段被跳过（prompt 检查 {L2,both}，不包括 "L3"），因此不存在 `## L2 盲审` 段，grep 失败，l2_verdict 保持为 `"fail"`。输出的 .done 文件包含 `L2_verdict=fail`，这在语义上不正确——L2 审查被跳过，而非失败。diff 在 done-validation.sh 第 137 行确实增加了 `"skipped"` 作为 L2_verdict 的合法值，但未引入任何实际写入它的机制。
- **建议**: 在默认设为 fail 之前，增加 L2 活跃度检测。在第 78 行之前调用 `fk_independent_review_gate_active "$phase" "L2"`。若返回 1（L2 不活跃），则设 `l2_verdict="skipped"`。若 L2 活跃但缺少 L2 段，才保留 `"fail"`（本应存在 L2 审查时缺失属于真正的失败）。

- **严重度**: Major
- **发现**: PreToolUse hook 的 deny 消息（第 242-243 行）硬编码为"L2 + L3"，忽略了实际 tier 配置：
  ```
  需先完成 L2（盲审子 agent → INDEPENDENT-REVIEW-${phase}.md）+ L3（Stop hook 调外部模型）
  ```
  在 L2-only 模式下，此消息错误地告知用户需要 L3 审查。在 L3-only 模式下，它错误地告知需要 L2 审查。这会误导用户尝试完成实际不存在的审查步骤。
  - **建议**: 在生成 deny 消息之前，检查 `fk_independent_review_gate_active "$phase" "L2"` 和 `fk_independent_review_gate_active "$phase" "L3"`，并根据活跃的 tier 动态调整消息：
    - L2-only："需先完成 L2（盲审子 agent → INDEPENDENT-REVIEW-${phase}.md）"
    - L3-only："需先完成 L3（Stop hook 调外部模型 → INDEPENDENT-REVIEW-${phase}.md）"
    - both："需先完成 L2（盲审子 agent）+ L3（Stop hook 调外部模型）"

- **严重度**: Major
- **发现**: L3 审查 lib 与 done 标志验证之间存在值域不一致问题。`l3-review.sh` 第 47 行验证 L2_verdict 参数时使用 `[[ "$l2_verdict" =~ ^(pass|fail)$ ]]`——该检查拒绝 `"skipped"`。但 diff 下的 `done-validation.sh` 第 137 行现已接受 `"skipped"` 作为合法 L2_verdict。这种不一致意味着 `l3-review.sh` 无法产出包含 `L2_verdict=skipped` 的 .done 文件，即使 L3-only 模式下需要该值。此问题与 #4 相关（29-independent-review.sh 默认设为 fail 而非 skipped），使得 `"skipped"` 值在当前变更集中仅存在于验证侧，全程无法实际流通。
- **建议**: 将 `l3-review.sh` 第 47 行的正则扩展为 `[[ "$l2_verdict" =~ ^(pass|fail|skipped)$ ]]`，并与 #4 的修复同步，确保 L3-only 模式传入 `l2_verdict="skipped"`。

- **严重度**: Minor
- **发现**: 6 个 prompt 文件将检测模式从 `{independent,true}` 更新为 `{L2,both}`，并附有向后兼容说明。这些更新在 6 个文件中保持一致。但 prompt 说 "检测：`.flow-active.goal.gate_config["1-requirement"]` ∈ {L2,both}"——未提及 `"L3"`。代码（`done-validation.sh` 第 67 行）也将 `L3` 视为合法 gate_config 值。若用户查看 stop-hook.json 文档或阅读代码后发现 `L3` 值并尝试使用，prompt 会给出误导性的检测标准描述。此问题影响所有 6 个已更新的 prompt。
- **建议**: 确认 `"L3"` 是否为预期的用户可设置值。若为内部值，在 prompt 注释中加以说明。若为用户可设置值，将 prompt 更新为 `{L2,L3,both}`。

- **严重度**: Minor
- **发现**: `l3-review.sh` 第 182 行将 `written_by` 硬编码为 `"pre-tool-use-gate"`。当从 `29-independent-review.sh`（stop hook）调用时，该值在审计跟踪中具有误导性——stop hook 产生的 .done 标志却被标记为 pre-tool-use-gate。此外，`done-validation.sh` 第 152 行的 Tier 2 握手验证检查 `hs_wby == "stop-hook-29"`，而非检查 .done 文件的 written_by——因此不构成功能性问题。但 .done 文件并非由 pre-tool-use hook 写入（pipeline 中实际是由 stop hook 或 PreToolUse 同步路径写入），这会引发审计困惑。
- **建议**: 从调用者处传递 `written_by` 参数，或自动检测：当 sourced 到 `29-independent-review.sh` 的调用链时使用 `"stop-hook-29"`，当 sourced 到 `independent-review-gate.sh` 时使用 `"pre-tool-use-gate"`。或者，在 l3_review_run 中增加第二个参数。

`L3_verdict=fail`
