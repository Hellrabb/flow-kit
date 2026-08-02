# MINOR-DEFERRED.md · superpowers-absorb-followup-1

> 🟢 Minor findings from L2 reviews, deferred per ADR-017 severity gating protocol. To be addressed by future changes or when relevant code is touched.

## Phase 1 L2 (R7-R9)

| ID | Finding | Suggested Action |
|---|---|---|
| R7 | AC-A3 'macOS（如可用）' weak cross-platform | Split into AC-A3a (Linux hard) + AC-A3b (macOS optional, CI skip) |
| R8 | AC verification contains 'manual' — automated coverage gap | Promote grep-verifiable parts to bats tests |
| R9 | 范围决策 embedded in REQUIREMENT (REQUIREMENT/DESIGN boundary) | Move design decisions to CHANGE.md or DESIGN-NOTES.md |

## Phase 2 L2 (R5-R7)

| ID | Finding | Suggested Action |
|---|---|---|
| R5 | ADR-016 detection script path unverified | Live-test OpenCode task tool support |
| R6 | task_progress lifecycle diagram details | Annotate state diagram with field transitions |
| R7 | D5/D6 weak model mitigation references ADR-001 | Re-evaluate after weak-model live tests (L-063) |

## Phase 6 L2 (R6-R8)

| ID | Finding | Suggested Action |
|---|---|---|
| R6 | SEC-1/SEC-3 structural duplication | Parameterize when ≥10 SEC tests |
| R7 | Mock coupling (FLOW_KIT_L3_MODEL env) | Resolved by L-072 (independent change) |
| R8 | Cross-change git diff contamination | Future workflow improvement: per-change diff scoping |
