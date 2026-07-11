# 独立审查 · 阶段 3

---

## L2 盲审 · 任务拆解审查（3-task）

**审查日期**: 2026-07-11
**审查工件**: TASK.md（参考 REQUIREMENT.md、DESIGN.md）
**审查标准**: L2-blind-review 阶段 3 checklist（任务粒度 / 依赖链 / verify 可验证性 / 覆盖完整性 / 禁动清单）

---

### 1. 任务粒度

| 任务 | 变更估算 | 判定 |
|------|---------|------|
| T01 | ~50 行（1 新文件 ~20 行 + 4 文件 source 行调整 ~5-10 行/个） | PASS |
| T02 | ~50 行（1 新文件 ~35 行 + 2 prompt 删代码块 ~5-10 行/个） | PASS |
| T03 | ~35 行（删 estimate_tokens ~20 行 + l3-review.sh 1 行修复 + CONTEXT 3 条目移除） | PASS |
| T04 | ~30 行（common.sh 新增 MAP ~15 行 + 2 处硬编码替换 ~5-10 行/处） | PASS |
| T05 | ~70 行（122L→3 子函数 + 编排器；净增函数签名 + doc 注释 ~20 行 + 编排器逻辑 ~30 行） | PASS |
| T06 | ~130 行（3 父函数拆为 10 子函数 + 编排器；净增签名/注释/编排胶水） | PASS（接近上限，见 §W-04） |
| T07 | ~60 行（126L→编排层 ~40L；净减~20 行编排替换） | PASS |
| T08 | ~60 行（线性脚本 ~80L→3 子函数 + 编排层 ~30L） | PASS |
| T09 | ~70 行（新 .bats 文件 3 test cases + setup/teardown + stub helpers） | PASS |
| T10 | 0 行（纯验证回归，无代码变更） | PASS |

**结论**: 所有任务变更量 ≤ 200 行。T06 拆分 10 个子函数变更量最大（~130 行），仍在安全区间内。

波次划分清晰：
- Wave 1（基础设施 · 3 并行）：T01/T02/T03
- Wave 2（common.sh · 1 串行）：T04
- Wave 3（函数拆分 · 4 并行）：T05/T06/T07/T08
- Wave 4（测试+回归 · 2 并行）：T09/T10

---

### 2. 依赖链

**依赖图验证（无环）**：
```
T01[P] ──┐
T02[P] ──┤
T03[P] ──┼──→ T04 ──→ T05[P] ────────────┐
          │         T06[P] ← T03 ──→ T09[P] ┤
          │         T07[P] ────────────────┤
          │         T08[P] ────────────────┤
          └────────────────────────────────┴──→ T10
```
无环。所有边为单向，DAG 结构正确。

**并行标记验证**：
- T01[P] / T02[P] / T03[P] — 三者无共享 write_files，并行安全 ✓
- T05[P] / T06[P] / T07[P] / T08[P] — 四者 write_files 互不重叠（T05→independent-review-gate.sh, T06→l3-review.sh, T07→fix-compliance.sh, T08→29-independent-review.sh），并行安全 ✓
- T09[P] — 仅写 test/test_l3_timeout.bats，与其他任务无冲突 ✓

**W-01 · T04 波次放置保守**（严重度：MINOR）
T04 的 `<depends_on></depends_on>` 为空，自身无依赖，但被放在 Wave 2 而非 Wave 1。T04 写入 common.sh / independent-review-gate.sh / 29-independent-review.sh — 这三个文件在 Wave 1 中均未被写入（T01/T02/T03 的 write_files 不重叠）。因此 T04 在技术上可与 T01/T02/T03 并行执行。当前放置为保守策略（"common.sh 串行化"），牺牲一轮并行度换取变更隔离。不影响正确性，但降低吞吐效率 ~25%（4 波次→3 波次）。建议：在 TASK.md 波次划分图中明确注释原因（如 "T04 放 Wave 2 是为将 common.sh 修改与 lib 解耦操作隔开，降低 merge conflict 概率"），避免后续读者误以为存在隐藏依赖。

**W-02 · T06←T03 依赖合理性**（严重度：INFO）
T06 依赖 T03 是因为 T03 修复了 l3-review.sh 的 `source "$0"` self-sourcing 问题，而 T06 需在修复后的基础上拆分函数。此依赖链方向正确——若 T06 在 T03 前执行，拆分出的子函数基架可能包含 self-sourcing bug。确认合理。

---

### 3. verify 可验证性

**F-01 · T01 verify 管道缺陷——循环检测失效**（严重度：CRITICAL）

当前 verify：
```bash
grep -r "source.*correction-file.sh\|source.*interactive-ui-check.sh\|source.*weak-model-compliance.sh" flow-kit-bundle/hooks/ \
| grep -v correction-types.sh \
| grep -v ".sh:" \
| echo "PASS: no cross-source cycles"
```

缺陷分析：
1. `grep -r` 输出格式为 `filename.sh:line_number:matched_text`，每行必然包含 `.sh:`
2. `grep -v ".sh:"` 因此过滤掉**所有**匹配行（包括真正的交叉引用）
3. `echo "PASS"` 不读取 stdin，永远以 exit code 0 执行

**结果**：无论三文件间是否存在循环 `source`，此 verify 始终打印 PASS 并退出 0。循环依赖检测完全无效。

修复方向（给实现者，非本审查范围）：改为 `if grep -rq "PATTERN" flow-kit-bundle/hooks/ | grep -v correction-types.sh | grep -q "."; then echo "FAIL: cross-reference"; exit 1; fi; echo "PASS"`

---

**F-02 · T03 verify 管道缺陷——self-sourcing 和死代码检测失效**（严重度：CRITICAL）

当前 verify：
```bash
grep 'source "$0"' flow-kit-bundle/hooks/stop/lib/l3-review.sh | grep -v "^#" | echo "PASS: no self-sourcing"
```

```bash
grep -E 'estimate_tokens|read_correction_file|file_not_empty' ... | grep -v "^#" | echo "PASS: dead functions cleared"
```

缺陷相同：`echo "PASS"` 不消费 stdin，始终 exit 0。若 self-sourcing 或死函数残留，verify 无法检测。

---

**F-03 · 其余 verify 质量检查**

| 任务 | verify | 判定 |
|------|--------|------|
| T02 | `for f in ...; do grep -q "PATTERN" "$f" && echo "FAIL" && exit 1; done; echo "OK"` — grep -q + exit 1 链正确 | PASS |
| T04 | `bash -n ... && npx bats test/test_common.bats ...` — bash -n 可靠，bats 可机器执行 | PASS |
| T05 | `bash -n ... && npx bats test/test_independent_review_gate.bats` — 两段均可机器验证 | PASS |
| T06 | `bash -n ... && npx bats test/test_l3_review.bats \|\| npx bats test/ --filter "l3"` — fallback 健壮 | PASS |
| T07 | `bash -n ... && npx bats test/test_fix_compliance.bats` — 标准模式 | PASS |
| T08 | `bash -n ... && npx bats test/test_independent_review_gate.bats` | PASS |
| T09 | `npx bats test/test_l3_timeout.bats` — 纯 bats 门禁 | PASS |
| T10 | `for f in ...; do bash -n "$f" \|\| echo "FAIL: $f"; done && npx bats test/` — for 循环 + `||` 短路的 exit code 正确（最后一个 `&&` 决定整体退出码） | PASS |

**结论**：8/10 verify 可机器执行。F-01 和 F-02 为 CRITICAL，必须修正后才能通过本次审查。

**W-03 · verify 管道反模式扩散风险**（严重度：INFO）
T01 和 T03 共享同一缺陷模式：`grep ... | echo "PASS"`。该模式在 code review 中容易被复制粘贴到后续 task。建议在实现时全局搜索 `| echo` 结尾的 verify 管道并修复。

---

### 4. 覆盖完整性

**AC 覆盖矩阵验证**：

| AC | 覆盖任务 | 覆盖状态 |
|----|---------|---------|
| AC-1 长函数 ≤60L | T05 (_gate_phase_transition) + T06 (l3-review 3 函数) + T07 (fk_fix_compliance_check) | 完整 |
| AC-2 依赖环 | T01 (correction-types.sh + 三方 source 调整) | 完整 |
| AC-3 零回归 | T10 (全量 bats + bash -n) | 完整 |
| AC-4 bash -n | T10 (10 文件逐文件 bash -n) | 完整 |
| AC-5 DRY phase_name | T04 (PHASE_GATE_KEY_MAP + 2 处替换) | 完整 |
| AC-6 DRY jq goal | T02 (goal-parsing.md + 两 prompt @see 引用) | 完整 |
| AC-7 timeout 测试 | T09 (test_l3_timeout.bats 3 场景) | 完整 |
| AC-8 self-sourcing+死代码 | T03 (source "$0" 修复 + estimate_tokens 删除 + 残留确认 + CONTEXT 清理) | 完整 |
| AC-9 29 号 hook | T08 (_check_l2_complete / _resolve_gate_value / _dispatch_l3_review 三函数) | 完整 |

**结论**：9/9 AC 有明确对应 task，无遗漏。

**read_files / write_files 约束检查**：

- T01 的 write_files 包含 `done-validation.sh` — 这是 AC-2 解环的被动副作用（REQUIREMENT §假设第 5 条已明确记录为被动变更）。T01 的 read_files 也包含了 `done-validation.sh`，说明实施者需要先读后改。约束到位 ✓
- T04 同时写入 `independent-review-gate.sh` 且 T05 也写入同一文件。T05 的 `<depends_on>T04</depends_on>` 确保 T05 在 T04 之后执行（T05 看到 T04 的 PHASE_GATE_KEY_MAP 替换结果）。正确 ✓
- T03 的 read_files 包含 `interactive-ui-check.sh` 和 `common.sh`（用于验证死代码已清理），但 write_files 不包含它们 — 这是纯验证读取，不修改。正确 ✓
- T02 的 read_files 包含 `pipeline-gates.md`（参考 @see 引用格式）— 读取参考文件合理 ✓

**结论**：read_files/write_files 约束覆盖所有变更面，无不必要的读取或遗漏的写入。

---

### 5. 禁动清单

对照 DESIGN §0.5.1 禁动清单逐条检查所有 `write_files`：

| 禁动项 | T01 | T02 | T03 | T04 | T05 | T06 | T07 | T08 | T09 | T10 |
|--------|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|
| package-flow-kit.sh | - | - | - | - | - | - | - | - | - | - |
| install.sh / install_hooks.sh | - | - | - | - | - | - | - | - | - | - |
| .flow-active schema | - | - | - | - | - | - | - | - | - | - |
| checkpoint-lib.sh | - | - | - | - | - | - | - | - | - | - |
| 00-gate.sh / 01-transcript-parse.sh / 22-git.sh 等协调层 | - | - | - | - | - | - | - | - | - | - |

**附加检查** — CONTEXT.md 禁动清单条目中与本 change 相关的：

| CONTEXT 禁动条目 | 是否触碰 | 判定 |
|------------------|---------|------|
| `correction-file.sh` 4 函数签名（L367） | T01 修改 source 依赖但不改函数签名 | 合规（仅调整 source 行） |
| `independent-review-gate.sh` + `29-independent-review.sh` + `fk_validate_done_marker` 核心链（L373） | T04/T05 修改 gate.sh、T08 修改 29-*.sh | 合规（DESIGN 明确在触碰列表内，为本次重构目标文件） |
| `l3-review.sh` 不允许绕过直接调 curl（L381） | T06 拆分 l3-review.sh 子函数 | 合规（不改变 API 调用路径，仅重构内部函数结构） |
| `.independent-review-N.done` 仅 l3_review_run() 有写权限（L382） | 无任务写入 .done 文件 | 合规 |
| `checkpoint-lib.sh` 必须通过 checkpoint_write()（L383） | 无任务触碰 | 合规 |

**结论**：所有 write_files 均未触碰 DESIGN 或 CONTEXT 禁动清单中的禁止项。触碰的 gate 核心链文件（independent-review-gate.sh / 29-independent-review.sh / l3-review.sh）属于本次 change 的明确重构目标，合规。

---

### 6. 其他发现

**W-04 · T06 单任务变更面偏大**（严重度：MINOR）
T06 在单个 task 内拆分 3 个父函数为 10 个子函数（smart_truncate→4, _l3_parse_result→3, _l3_build_prompt→3），加上对应的编排器逻辑。净增函数签名、doc 注释、编排器胶水代码预估 ~130 行。虽未超过 200 行硬上限，但单一 task 拆分 10 个子函数的认知负荷偏高——若某一子函数引入 bash 作用域 bug（R1），定位需遍历 10 个新函数。建议：将 T06 拆为 T06a（smart_truncate 4 子函数）+ T06b（_l3_parse_result 3 子函数）+ T06c（_l3_build_prompt 3 子函数），三个子 task 设为 [P] 并行（它们拆分不同函数、无共享代码段）。如果当前波次不想再拆 task，至少在 T06 的 `<action>` 中加提示：每拆完一个父函数立即跑 `npx bats test/ --filter "l3"` 确认该函数拆分未引入回归，再继续下一个。

**W-05 · T05→T04 的测试耦合风险**（严重度：INFO）
T05 依赖 T04（T04 写入 PHASE_GATE_KEY_MAP 到 common.sh + 替换 independent-review-gate.sh 中的硬编码）。T05 运行 `npx bats test/test_independent_review_gate.bats` 作为 verify。如果 T04 的硬编码替换改变了 gate.sh 中 `case-esac` 段的控制流（例如 case 分支的 fall-through 行为因 MAP 查表而改变），T05 的 bats 测试会捕获。但 T05 不直接测试 PHASE_GATE_KEY_MAP 的正确性——这依赖 T04 自身的 verify。耦合点已通过 `<depends_on>` 正确排序，无需额外处理。

---

## 审查结论

| 维度 | 结果 |
|------|------|
| 任务粒度（≤200L/任务） | PASS |
| 波次划分 | PASS（4 波次清晰，见 W-01 微调建议） |
| 依赖图无环 | PASS |
| 并行标记 [P] | PASS |
| verify 可机器执行 | **FAIL** — F-01（T01）+ F-02（T03）verify 管道缺陷导致循环检测和死代码检测完全失效 |
| AC 覆盖完整性 | PASS（9/9 AC 覆盖） |
| read_files/write_files 约束 | PASS |
| 禁动清单合规 | PASS |

**最终判定**: **REJECT（有条件）** — 2 个 CRITICAL 缺陷（F-01、F-02）必须修复后重新审查。

修复要求：
1. **T01 verify**：重写为可产生非零 exit code 的检测逻辑（`if grep -rq ... | grep -v correction-types.sh | grep -q "."; then echo "FAIL" && exit 1; fi` 模式）
2. **T03 verify**：同上，修复 self-sourcing 检测和死函数检测两个子管道

F-01 和 F-02 修复后，本轮审查自动通过（其余维度均为 PASS，无新增阻塞项）。W-01/W-04 为 MINOR 建议，不阻塞通过。

---

## L3 重审（deepseek-v4-flash[1m] 外部模型 · 2026-07-11 16:47）

> 自动生成于 2026-07-11 16:47。由 l3-review.sh 写入。

### 审查结论

```json
{"critical":[],"major":[{"file":"T10","issue":"verify不能可靠检测所有bash -n失败","why":"for循环中每个文件的bash -n失败仅打印FAIL，未设置错误状态；循环退出码只取决于最后一个文件的bash -n结果，导致某个文件语法错误但最后一个文件正确时，for循环返回0，继续执行bats测试，可能掩盖错误。","fix":"修改verify：使用变量记录错误并最终exit非0，例如：err=0; for f in ...; do bash -n \"$f\" || { echo \"FAIL: $f\"; err=1; }; done; [ $err -eq 0 ] && npx bats test/ || exit 1"}],"minor":[{"file":"T05/T06/T07/T08","issue":"AC-1要求子函数≤60L，但verify未检查函数行数","why":"任务描述中明确了拆分后的行数限制，但verify仅通过bash -n和bats验证，不能保证实际行数满足要求，可能存在函数超长但bats通过的情况。","fix":"在verify中增加行数检查，例如：for func in _gate_check_l2 _gate_check_l3 _gate_do_transition; do length=$(awk '/^function $func/,/^}/' file.sh | wc -l); [ $length -le 60 ] || { echo \"FAIL: $func too long\"; exit 1; }; done"}],"verdict":"pass","summary":"任务拆解覆盖了所有9个AC，依赖图无环，write_files边界清晰。但T10的verify存在缺陷，可能无法正确捕获语法错误（major）。此外，多个任务的verify缺少对函数行数的直接验证（minor）。整体可接受。"}
```
