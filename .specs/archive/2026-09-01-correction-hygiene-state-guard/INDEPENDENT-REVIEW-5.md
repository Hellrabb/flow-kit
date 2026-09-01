# INDEPENDENT-REVIEW-5 — Phase 5 (TEST) Blind Review

Change: `correction-hygiene-state-guard` | Reviewer: L2 independent (blind) | Date: 2026-09-01

## Verdict

**PASS** — 0 🔴 Critical, 1 🟡 Important, 2 🟢 Minor. All 10 ACs have at least one real test whose assertions exercise the AC's Given/When/Then. UAT-1 is a genuine chisel_env replay, reproduced independently. No red-line violations.

---

## Findings

1. 🟡 **Important — 29-independent-review.sh:97-104 duplicates the shared strip abstraction**
   - **Symptom**: `flow-kit-bundle/hooks/stop/29-independent-review.sh:97-104` implements the merged-label retirement as an inline `jq` (`'.type = (.type | split("+") | map(select(. != $seg)) | join("+"))'`, `$seg="l2-missing"`) instead of calling `correction_file_strip_type` from `flow-kit-bundle/hooks/stop/lib/correction-file.sh:269-310`. `33-flow-active-integrity.sh:38-40` does call the shared function on the same foreign path.
   - **Source**: TASK.md T03 action (L75) explicitly instructs "调 T01 的 `correction_file_strip_type file "l2-missing"` 剥离"; DESIGN §9.1 chose the shared abstraction because the strip logic is reused by 33 and 29. Comment at 29:79-81 admits T01 was not yet landed at T03 time and defers unification to "T02/T04 后续统一时再切换" — both T02 and T04 are marked done, but the inline remains.
   - **Consequence**: The strip semantics exist in two places with divergent contracts (lib: pure-type no-op / segment-absent no-op / degenerate unchanged; inline: always strips the segment when reachable). Any future boundary-contract change to the lib will silently leave 29 on the old behavior (R2/R3 decay); the R1 test (L307-308) only pins the inline copy.
   - **Remedy**: Replace L97-104 with a guarded `correction_file_strip_type "$correction_file" "l2-missing"` call (guarded by the existing pure-type `rm` branch, since the lib returns 1 on pure type), then re-run the AC-4b + AC-10 tests. No AC behavior changes; this is a compliance-with-TASK cleanup.

2. 🟢 **Minor — TEST.md:77 "白名单 49 条清空" arithmetic slip**
   - **Symptom**: `.specs/correction-hygiene-state-guard/TEST.md:77` expects "白名单 49 条清空", but the same UAT-1 result block (L79) reports "n=50→1" and the fixture carries 50 whitelist violations (43 corrupt_json + 1 phase_artifact_missing + 6 pipeline_phase_artifact_missing — all three names are whitelist-class). The reproduced run clears 50, not 49.
   - **Source**: Off-by-one while hand-writing the expectation line; the result line was written from the real run.
   - **Consequence**: None functional; cosmetic inconsistency inside TEST.md that could mislead a future auditor counting cleared items.
   - **Remedy**: Change L77 to "白名单 50 条清空" (or "全部清空").

3. 🟢 **Minor — baseline test-count figures inconsistent across artifacts**
   - **Symptom**: REQUIREMENT.md AC-8 states "实测当前 772"; TASK.md T04 done marker and TEST.md state baseline "752"; the actual suite is 764 green (754 before this change, +10 hygiene).
   - **Source**: Baselines captured at different points in the change lifetime without a single source of truth.
   - **Consequence**: None — AC-8's requirement is "基线 752+" and "bats 全绿", both satisfied by 764/764 (independently verified). Pure doc noise.
   - **Remedy**: Optionally pin the AC-8 wording to "≥752 baseline, green" without a hard snapshot number.

---

## AC Mapping Verification (each AC → real test, assertions checked against Given/When/Then)

| AC | Test (file:case) | Assertions exercise the AC? | Verdict |
|----|------------------|-----------------------------|---------|
| AC-1 | test_correction_hygiene.bats `AC-1` | 3 same check+field writes → COUNT=1, MSG=latest, TYPE=state-integrity | ✅ |
| AC-2 | test_correction_hygiene.bats `AC-2` | 12 fields → WL=10 FIFO, FIRST/LAST correct, compliance retained & unquota'd | ✅ |
| AC-3 | test_correction_hygiene.bats `AC-3` | whitelist cleared (0), compliance kept, merged type untouched, stderr count | ✅ |
| AC-4 | test_correction_hygiene.bats `AC-4a` + `AC-4b` | pure type → rm + audit; merged → strip to state-integrity, violations byte-identical; R2 (M0 before Gate 3) proven by L2-config run | ✅ |
| AC-5 | test_correction_hygiene.bats `AC-5/6` + test_flow_active_integrity.bats NFR corrupt JSON | YAML → corrupt_json=0, foreign_state=1, stderr 外来; NFR test asserts the new yield contract | ✅ |
| AC-6 | test_correction_hygiene.bats `AC-5/6` | type stripped to l2-missing, compliance preserved, idempotent re-run | ✅ |
| AC-7 | test_correction_hygiene.bats `AC-7` + NFR corrupt JSON | sha256+mtime of foreign .flow-active byte-identical before/after run | ✅ |
| AC-8 | make check (4 gates) + full suite | bats 764/764, shellcheck 0 error, validate 302/302, dual-source diff -r zero — all re-verified | ✅ |
| AC-9 | test_correction_hygiene.bats `AC-9` + UAT-1 | synthetic 50 → 2 entries, re-run stable; real chisel_env 50 → 1 foreign note, exit 0 | ✅ |
| AC-10 | test_correction_hygiene.bats `AC-10` + `R1` | compliance entry byte-identical (jq -c) across health-clear / foreign-yield / retirement paths; write protection test | ✅ |

Coverage: 10/10 ACs mapped, all exercised by real assertions. No AC mapped to a test that doesn't exercise it.

## UAT-1 Reproduction (independent)

Fixture: real `~/chisel_env/.flow-active` (YAML, traceweave-skill-mining) + `.flow-active.correction` (type `l2-missing+state-integrity`, 50 violations: 43 corrupt_json + 1 phase_artifact_missing + 6 pipeline_phase_artifact_missing).
Command: `HOOK_BASE_DIR=$PWD/flow-kit-bundle/hooks/stop bash flow-kit-bundle/hooks/stop/33-flow-active-integrity.sh <fixture>/.flow-active <fixture>/.specs <fixture>/.flow-active.correction ""`.
Result (verified): exit 0 · whitelist cleared (corrupt_json=0) · type stripped to `l2-missing` · exactly 1 `foreign_state` note · `.flow-active` sha256 **unchanged** · mtime unchanged · stderr line matches TEST.md verbatim. AC-7 PASS on real data.

## Red-Line Results

- **R5.3 (no deleted/weakened tests)**: ✅ `git diff` on test files: 0 `@test` deleted, 0 `@test` added in tracked files; only change is the NFR corrupt-JSON test, which is an **assertion update** to the new AC-5/6/7 behavior (old: expects corrupt_json; new: corrupt_json=0, foreign_state=1, sha256 unchanged), documented with F2/D5 rationale in the code and in TASK.md T04 done marker. Not a weakening.
- **R5.1 (tests derive from AC, not implementation)**: ✅ Test names/cases are AC-referenced and assert observable behavior (file contents, counts, exit codes, stderr, sha256). The two unit-level tests (AC-1, R1) target the public lib/hook functions at the appropriate layer, not private internals.
- **6-dim spot check** (AC-3, AC-7 cases): T1 readable names ✅ · T2 asserts behavior (jq counts, stderr contract) not impl detail ✅ · T3 unique per-AC mapping ✅ · T4 zero mocks, real subprocess runs ✅ · T5 real assertions (sha256, byte-compare) ✅ · T6 integration-level via `run_33`/`run_29` ✅.
- **L-031 anchors**: ✅ 9-value whitelist consistent across correction-file.sh:158-168 (const array), 33's `_fai_append_violation` calls (8 names — corrupt_json intentionally no longer appended, retained only as a clearable name), REQUIREMENT AC-3 enumeration (9), and TEST.md matrix.
- **Scope**: ✅ All 5 rounds claimed run with evidence; no skipped rounds; only UI round marked N/A (backend-only project — acceptable).
- **Security**: ✅ 0 hits for `sk-`/`Bearer`/`ANTHROPIC`/api-key patterns in changed hooks and both test files; shellcheck 0 errors.
- **Perf**: ✅ Spot 10-iteration runs: health-clear avg ~40ms, foreign-yield avg ~22ms — same order of magnitude as TEST.md's 41ms/24ms claim.

---
**Summary (5 lines)**: Verdict PASS — no Critical findings, 1 Important, 2 Minor. All 10 ACs verified against real tests; UAT-1 chisel_env replay reproduced (50→1, AC-7 PASS, exit 0). All 4 make-check gates green (764/764 bats, shellcheck 0, validate 302, dual-source diff zero). Red lines R5.1/R5.3/L-031 clean. Main follow-up: 29 should adopt the shared `correction_file_strip_type` (finding 1).

## 主 agent 响应（第 2 轮）

### F1（🟡）29 M0 内联 jq strip vs 共享 correction_file_strip_type — ✅ Fixed
修改：`flow-kit-bundle/hooks/stop/29-independent-review.sh` M0 块 else 分支改为 JIT source 共享函数——
- `[ -f "${HOOK_BASE_DIR}/lib/correction-file.sh" ] && source "${HOOK_BASE_DIR}/lib/correction-file.sh" 2>/dev/null || true`
- `correction_file_strip_type "$correction_file" "l2-missing" >/dev/null 2>&1 || true`
- **fallback 内联 jq 已删除**（单一源原则）。lib 缺失（HOOK_BASE_DIR 未注入的裸跑场景）→ 跳过 strip、fail-open 语义不变，下次 Stop 退场检测重试自愈。退化场景分歧（内联空 type vs lib no-op）随内联删除而消除——现统一走 lib 守卫（纯 type 无 `+` → rc1 文件不变）。
- 注释块原位更新（JIT source 理由：Stop 链由 00-gate runner 注入 HOOK_BASE_DIR，常规路径零开销；29 单独裸跑才需要 JIT）。

### F2（🟢）TEST.md:77「49 条」内部不一致 — ✅ Fixed
改为「白名单 50 条清空（43+1+6 全为白名单类）」，与 L79 n=50→1 一致。

### F3（🟢）基线数漂移 772/752/764 — ✅ Triaged（不改）
REQUIREMENT/TASK 中的数字是撰写时的历史快照；AC-8 判据为「全量 0 fail」语义，实际以 make check 当前输出（764/764）为准。不在文档间追逐同步常数（R3 知识重复：数字单一源 = make check 实跑输出）。

### 复验证据
- bash -n + shellcheck（-e SC1091 -S error）29 号 ✅
- 定向 bats：test_correction_hygiene 10/10 + test_flow_active_integrity 19/19 + test_independent_review_model 12/12 + test_stop_chain 43/43 ✅
- 全量 make check 四门 ✅（764/764 + shellcheck 0 + validate 302 项 + 双源一致）

### L2 复核（第 3 轮 · ses_fa680844cffe1qeQTutxK2i64d · 22s）
F1 ✅ Fixed（内联 jq 零命中 + JIT source + 共享函数落地 + bash-n/shellcheck 过）/ F2 ✅ Fixed / F3 ✅ Triaged / 回归 ✅（10/10 + 19/19）。**Verdict: pass** — Phase 5 盲审闭环。
