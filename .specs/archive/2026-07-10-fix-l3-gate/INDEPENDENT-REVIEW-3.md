# 独立审查 · 阶段 3

## L2 盲审

### 🔴 R1 · T03 全部路径错误：read_files/write_files/verify 引用不存在的文件

**Symptom（症状）**：T03 的 `read_files`、`write_files`、`verify` 中所有 6 个文件路径均缺 `flow-kit-bundle/` 前缀。例如 `flow-kit/prompts/1-requirement.md` 解析为 `<repo_root>/flow-kit/prompts/1-requirement.md`，但实际文件位于 `<repo_root>/flow-kit-bundle/flow-kit/prompts/1-requirement.md`。已验证 6 个文件全部 MISSING 于声称路径，全部 EXISTS 于 `flow-kit-bundle/flow-kit/` 下。

**Source（源头）**：TASK.md T03 段 read_files/write_files/verify 均使用 `flow-kit/...` 而非 `flow-kit-bundle/flow-kit/...`。对比 T01/T02 正确使用了 `flow-kit-bundle/...` 前缀——这是 T03 自身的路径笔误。

**Consequence（后果）**：任务不可执行。`read_files` 找不到源文件导致实施者无参考；`write_files` 写到错误路径（可能创建新文件而非修改已有文件）；`verify` 在不存在文件上运行 grep，exit code 2 即 FAIL。T03 完全阻塞。

**Remedy（修补）**：将 T03 所有路径统一加 `flow-kit-bundle/` 前缀：
- `flow-kit/prompts/1-requirement.md` → `flow-kit-bundle/flow-kit/prompts/1-requirement.md`
- `flow-kit/prompts/2-design.md` → `flow-kit-bundle/flow-kit/prompts/2-design.md`
- `flow-kit/prompts/3-task.md` → `flow-kit-bundle/flow-kit/prompts/3-task.md`
- `flow-kit/prompts/5-test.md` → `flow-kit-bundle/flow-kit/prompts/5-test.md`
- `flow-kit/prompts/6-review.md` → `flow-kit-bundle/flow-kit/prompts/6-review.md`
- `flow-kit/GO.md` → `flow-kit-bundle/flow-kit/GO.md`

---

### 🔴 R2 · T04 verify 存在致命兜底掩码：`echo "MANUAL: ..."` 无条件 exit 0

**Symptom（症状）**：TASK.md T04 verify 命令链为 `npx bats ... --filter-tags "fix-l3-gate" 2>/dev/null || npx bats test/test_fix_l3_gate.bats 2>/dev/null || echo "MANUAL: run npx bats test/ and verify 0 fail"`。第三个 fallback `echo "MANUAL: ..."` 永远 exit 0。若前两个 `npx bats` 均失败（如测试文件不存在、bats 未安装、测试 asserting failure），verify 仍报 PASS。

**Source（源头）**：`||` 短路链末尾使用无条件的 `echo` 作为兜底，而非 `exit 1` 或 `false`。

**Consequence（后果）**：T04 的 verify 永远通过，无法检测测试失败。T04 承载全部 5 个 AC 的测试验证——若其 verify 虚设，整个 change 的回归保护失效。

**Remedy（修补）**：改为明确失败语义：
```bash
npx bats test/test_fix_l3_gate.bats --filter-tags "fix-l3-gate" 2>/dev/null || { npx bats test/test_fix_l3_gate.bats 2>/dev/null || { echo "FATAL: bats tests failed — cannot verify T04" >&2; exit 1; }; }
```
或更简洁地：移除 `|| echo "MANUAL:..."` 整段兜底，让 `npx bats` 退出码直接传递。

---

### 🟡 R3 · T01 verify 仅语法检查，不验证 3 项行为变更

**Symptom（症状）**：T01 verify 为 `bash -n flow-kit-bundle/hooks/stop/lib/l3-review.sh && echo "SYNTAX OK"`。该命令仅验证 Bash 语法无错，不验证：(a) mtime 比较逻辑正确触发重审，(b) 追加模式正确写入（vs 覆写），(c) .done 仅 pass 时写入。

**Source（源头）**：T01 是本次 change 最复杂的任务——l3-review.sh 574 行中 3 处行为变更——但 verify 采用了最低限度的语法检查。TASK.md `done` 字段声称 "AC-1 + AC-2 + AC-3 实现完成" 但 verify 无法证明。

**Consequence（后果）**：实施者可能写错重审逻辑但语法正确，verify 通过，缺陷推迟到 T04 集成测试才暴露，增加返工成本。但 T04 理论上会捕获这些缺陷，故严重度降为 Major。

**Remedy（修补）**：至少增加一项冒烟测试，例如：
```bash
# 最小冒烟：source l3-review.sh 后调用关键函数验证返回值
bash -c 'source flow-kit-bundle/hooks/stop/lib/l3-review.sh; type l3_review_run >/dev/null 2>&1 && echo "FUNC_OK"'
```

---

### 🟡 R4 · T02 verify 仅语法检查，不验证 .phase 同步逻辑

**Symptom（症状）**：T02 verify 为 `bash -n flow-kit-bundle/hooks/stop/31-auto-advance.sh && echo "SYNTAX OK"`。该命令不验证 transition jq 中是否实际包含了 `.phase = $next`。

**Source（源头）**：T02 仅需插入一个 jq 管道（5 字符 `.phase = $next | `），verify 用语法检查来证明"已插入"是逻辑跳跃。

**Consequence（后果）**：语法检查对"忘了加 `.phase`"的遗漏零敏感。同样由 T04 兜底，但在 CI 中 T02 单独完成时无法自我证明。

**Remedy（修补）**：增加 grep 断言验证修改已落地：
```bash
bash -n flow-kit-bundle/hooks/stop/31-auto-advance.sh && grep -q '\.phase\s*=\s*\$next' flow-kit-bundle/hooks/stop/31-auto-advance.sh && echo "PHASE_SYNC_OK"
```

---

### 🟡 R5 · T03 verify 管道无判别力：任意非零匹配数均 exit 0

**Symptom（症状）**：T03 verify 为 `grep -n '\.phase\s*=' <6files> | grep -c 'phase'`。此管道在任意文件有 ≥1 个 `.phase =` 匹配时 exit 0，不区分"6 个文件各 1 处正确修改"与"1 个文件写了 6 次"。更严重的是：若仅 3 个文件完成修改、另 3 个遗漏，verify 仍 PASS。

**Source（源头）**：`grep -c` 的退出码仅反映"是否有匹配"，不反映"匹配数量是否达到预期"。管道末尾缺少 `[ $(...) -eq 6 ]` 阈值校验。

**Consequence（后果）**：T03 完成度无法自动判定。实施者可能在 6 个文件中遗漏 1-2 个，verify 仍通过，导致部分 transition 路径缺少 `.phase` 同步。

**Remedy（修补）**：改为精确计数断言：
```bash
count=$(grep -c '\.phase\s*=' flow-kit-bundle/flow-kit/prompts/1-requirement.md ... flow-kit-bundle/flow-kit/GO.md)
[ "$count" -ge 6 ] && echo "PHASE_SYNC_COUNT_OK: $count" || { echo "FAIL: expected >=6, got $count"; exit 1; }
```
并建议增强为 `grep -n '\.phase\s*=\s*"[0-7]"'` 验证 phase 值为带引号的数字字符串。

---

### 🟡 R6 · T01 `l3_write_timeout_done()` 修改规格不足

**Symptom（症状）**：T01 action 末尾仅一句 "l3_write_timeout_done() 同步改为不写 .done（或直接走 fail 路径，调用方改为 return 1）" 描述该函数（DESIGN.md 记载 L453-499，约 47 行）的修改方案，且以括号给出两个互斥方案（"改成不写 .done" vs "直接走 fail 路径"），未做最终决策。

**Source（源头）**：DESIGN.md §3.2 明确要求 "同步修改: l3_write_timeout_done() L453-499 同样改为不写 .done（或直接移除该函数调用，让 timeout 走 fail 路径）"——两个方案用"或"连接，未在 TASK 中收窄为单一方案。

**Consequence（后果）**：实施者需自行决策两个方案之一，可能选错或引入不一致行为。若选"移除调用 + return 1"，需同步修改 `l3_review_run()` 中调用 `l3_write_timeout_done` 的路径；若选"函数内部改为不写 .done"，需确认调用方逻辑兼容。

**Remedy（修补）**：在 T01 action 中明确二选一并细化：
- 若选方案 A（函数内不改 .done 写逻辑，调用方改为 return 1）：写明调用方具体行号和修改内容。
- 若选方案 B（函数内改为不写 .done，保留调用）：写明需删除或注释 `l3_write_timeout_done()` 中写 .done 的代码段。

---

### 🟡 R7 · T02/T03 依赖理由不准确

**Symptom（症状）**：TASK 波次说明称 "T01 必须最先执行——它是核心修改，T02/T03 验证 transition 同步时需要 T01 的 .done 写逻辑已就绪。" 但 T02 和 T03 修改的是 transition jq（`.phase` 字段同步），与 T01 的 .done 写逻辑（`l3_review_run()` 内部）修改的是不同文件的不同关注点，不存在代码级耦合。

**Source（源头）**：T02/T03 的 `write_files` 是 `31-auto-advance.sh` 和 6 个 prompt/GO.md 文件；T01 的 `write_files` 是 `l3-review.sh`。三个任务修改的文件集合不相交，依赖关系仅存在于逻辑层面（统一发版），非构建/编译层面。

**Consequence（后果）**：若严格按 TEAM 分工，T02 或 T03 的实现者被理由误导，可能浪费时间等待 T01 完成，而实际上可完全并行实施（三个任务修改不同文件集）。依赖图本身正确（DAG 无环），但由于理由不当可能造成不必要的串行化。

**Remedy（修补）**：更正依赖理由为实际原因，例如："T02/T03 与 T01 构成同一 change 的完整改动集，建议合并 PR 前完成全部修改，确保 transition jq 的 `.phase` 同步与 .done 写逻辑修复在同一版本中发布。"

---

### 🟢 R8 · T04 read_files 中 `test/` 目录引用过于宽泛

**Symptom（症状）**：T04 read_files 列出 `test/` 作为参考文件，但未指定具体文件。`test/` 目录下包含多个 .bats 文件和子目录（fixtures/、regression-demos/、weak-model-robustness/），实施者无法确定需参考哪些既有测试。

**Source（源头）**：T04 read_files 应列出具体的参考测试文件（如 `test/done-validation.bats`、`test/done-skip.bats`），而非整个目录。

**Consequence（后果）**：实施者可能遗漏关键参考（如 done 相关的已有测试模式），或浪费精力阅读无关文件。

**Remedy（修补）**：将 `test/` 替换为具体的已有测试文件列表，至少包含：`test/done-validation.bats`、`test/done-skip.bats`。

---

### 🟢 R9 · T03 verify 不校验 per-file phase 值正确性

**Symptom（症状）**：T03 verify 只统计 `.phase =` 出现次数，不验证每个文件的 phase 值是否正确（如 1-requirement.md 应赋 `"2"`，2-design.md 应赋 `"3"` 等）。

**Source（源头）**：T03 action 明确列出了每个文件应赋的具体值（`"1"` 到 `"7"`），但 verify 未利用此信息做精确校验。

**Consequence（后果）**：实施者可能将所有文件统一赋成相同值（如全部 `.phase = "2"`），verify 仍 PASS，导致 transition 后 phase 值错误。

**Remedy（修补）**：增强 verify 为 per-file 校验，例如：
```bash
verify_phase_val() { grep -q "\.phase\s*=\s*\"$2\"" "$1" || { echo "FAIL: $1 missing .phase = \"$2\""; exit 1; }; }
verify_phase_val flow-kit-bundle/flow-kit/prompts/1-requirement.md "2"
# ... 其余 5 个文件依此类推
echo "ALL_PHASE_VALS_OK"
```

---

**Verdict**: fail

Reason: 2 项 🔴 Critical — R1（T03 全部路径错误导致任务不可执行）和 R2（T04 verify 存在致命兜底掩码导致验证虚设）。

---

## L2 盲审 · Round 2（修复后复审）

### ✅ 已确认修复

**R1**（🔴 → 已消解）：T03 全部路径修复。`read_files`（6 个）、`write_files`（6 个）、`verify`（6 个）已全部加 `flow-kit-bundle/` 前缀。路径与文件系统实际布局一致。T03 可执行。

**R2**（🔴 → 已消解）：T04 verify 修复。当前 verify 为 `npx bats test/test_fix_l3_gate.bats`，无 `|| echo "MANUAL:..."` 兜底、无 `||` 短路伪装。`npx bats` 退出码直接传递，测试失败则 verify 失败。

**R6**（🟡 → 已消解）：T01 `l3_write_timeout_done()` 方案收窄。T01 action 现明确指定单一方案："移除 .done 写入段，改为 return 1" + "调用方 `l3_review_with_timeout()` L445 改为 `return 1` 而非调用 `l3_write_timeout_done`"。不再有"或"二选一歧义。

---

### 🟡 持续关注（上次已报告，未修复）

以下问题在 Round 1 中已识别为 🟡 Major / 🟢 Minor，本轮未修复，但无新证据表明应升级为 🔴（任务均保持可执行，T04 集成测试提供兜底验证）。

- **R3**（🟡 持续）：T01 verify 仍为 `bash -n ... && echo "SYNTAX OK"`，仅语法检查，不验证 3 项行为变更（mtime 重审触发 / 追加 vs 覆写 / .done 条件写入）。
- **R4**（🟡 持续）：T02 verify 仍为 `bash -n ... && echo "SYNTAX OK"`，不验证 `.phase` 管道已插入。
- **R5**（🟡 持续）：T03 verify 简化了（移除无意义的 `| grep -c 'phase'` 管道），但仍无计数阈值——6 个文件中仅 1 个完成修改即 exit 0。未要求 `[ "$count" -ge 6 ]`。
- **R7**（🟡 持续）：波次说明仍称 "T02/T03 验证 transition 同步时需要 T01 的 .done 写逻辑已就绪"，但 T02/T03 修改的文件（`31-auto-advance.sh`、6 个 prompt/GO.md）与 T01 修改的文件（`l3-review.sh`）互不相交，不存在代码级耦合。依赖图本身正确（DAG 无环），但理由不当。
- **R8**（🟢 持续）：T04 `read_files` 仍写 `test/` 目录整体，未细化为具体已有测试文件（如 `test/done-validation.bats`）。
- **R9**（🟢 持续）：T03 verify 仍不校验 per-file phase 值正确性（如 `1-requirement.md` 应赋 `"2"`，`2-design.md` 应赋 `"3"` 等）。

---

### 🟢 本轮新发现

#### 🟢 N1 · T01 `l3_write_timeout_done()` 修改后残留死代码

**Symptom（症状）**：T01 action 要求：(a) `l3_write_timeout_done()` 函数体内移除 .done 写入段并改为 `return 1`，(b) 调用方 `l3_review_with_timeout()` L445 改为 `return 1` 而**不调用** `l3_write_timeout_done`。两步合在一起后，`l3_write_timeout_done()` 成为不再被调用的死函数。

**Source（源头）**：action 未说明函数体最终处置（保留为死代码 / 完整删除函数定义）。

**Consequence（后果）**：遗留死代码降低可维护性，未来维护者可能误以为该函数仍在活跃使用。不影响运行时行为。

**Remedy（修补）**：明确处置——建议直接删除 `l3_write_timeout_done()` 完整函数定义（L453-499），而非保留为 `return 1` 死代码；或在 action 末尾加一句 "确认 `l3_write_timeout_done()` 在修改后无其他调用方（`grep -rn l3_write_timeout_done flow-kit-bundle/`），可安全删除"。

#### 🟢 N2 · T04 `read_files` 包含尚不存在的目标文件

**Symptom（症状）**：T04 `read_files` 首项为 `test/test_fix_l3_gate.bats`，但 T04 action 第一句为"新建 test/test_fix_l3_gate.bats"。`read_files` 的语义是"实施前应阅读的参考文件"，列出尚未创建的目标文件造成矛盾。

**Source（源头）**：`read_files` 与 `write_files` 角色混淆——`test_fix_l3_gate.bats` 是产物（应在 `write_files`），不应出现在 `read_files`。

**Consequence（后果）**：实施者若严格按 `read_files` 顺序操作，尝试 `cat test/test_fix_l3_gate.bats` 会得到 "No such file or directory"，产生困惑。影响极小（任何有经验的开发者都能推断这是待创建文件）。

**Remedy（修补）**：从 T04 `read_files` 中移除 `test/test_fix_l3_gate.bats`（已在 `write_files` 中声明）。

---

### 复审结论

- Round 1 的 2 项 🔴 Critical（R1 路径错误、R2 verify 虚设）均已正确修复，T03 和 T04 现可正常执行。
- 1 项 🟡 Major（R6 方案歧义）已消解。
- 剩余 4 项 🟡 Major（R3/R4/R5/R7）和 2 项 🟢 Minor（R8/R9）为已知遗留，不阻塞执行，建议在后续迭代中逐步改进。
- 本轮新发现 2 项 🟢 Minor（N1 死代码、N2 read_files 矛盾），不影响任务可执行性。

**Verdict**: pass
