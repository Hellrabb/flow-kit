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
