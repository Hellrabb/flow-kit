# 独立审查 · 阶段 1

## L2 盲审

> 审查日期：2026-07-11
> 阶段：1 — 需求审查
> Change ID：health-fix-l3-2026-07
> 审查工件：REQUIREMENT.md（参考 CHANGE.md）
> 独立性声明：调用方输入仅含文件路径与阶段参数，未检测到主 agent 自评/草稿/概述/辩护注入。独立性未被污染。

---

### 总览

REQUIREMENT.md 共 9 条 AC，均含 Given/When/Then 三段且附机器可验证命令。v1/v2/out 范围切分清晰，v1 覆盖 CHANGE.md 列出的全部 12 项风险（3C + 6W + 3S），v2 将 2 项额外技术债显式延后并给出理由，out 区排除明确。无"系统应该正常工作"类空话 AC。整体质量良好，以下为具体发现。

---

### 发现

---

### 🟡 R1 · AC-6 验证依赖 `check-gate-sync.sh` 未定义

**Symptom（症状）**：AC-6 的 Then 子句与验证方式中均引用了 `check-gate-sync.sh`（第 59 行、第 60 行），但 REQUIREMENT.md 全文和 CHANGE.md 均未定义该脚本的用途、位置或预期行为。

**Source（源头）**：验收准则可机器验证原则——验证步骤引用的脚本必须在需求文档或其参考文档中有定义，否则验收者无法执行验证。

**Consequence（后果）**：实施完成后，验收者无法确定 `check-gate-sync.sh` 通过的标准是什么，AC-6 的 Then 条件存在一个不可验证的分支。若该脚本不存在，AC-6 在该检查点上永远为假（或永远无法执行）。

**Remedy（修补）**：二选一——
- 若 `check-gate-sync.sh` 是已有项目脚本，在 AC-6 验证方式中标注其路径（如 `flow-kit-bundle/scripts/check-gate-sync.sh`）并简述其检查内容。
- 若该脚本尚未创建，将 Then 子句改为 `make check`（已在验证方式中出现），移除对 `check-gate-sync.sh` 的独立引用，或补充定义该脚本为本次 v1 产物。

---

### 🟡 R2 · AC-1 awk 验证命令对嵌套花括号函数体不适用

**Symptom（症状）**：AC-1 验证方式（第 25 行）给出的 awk 命令为：
```
awk '/^<f>\(\)/,/^}/' <file> | wc -l
```
bash 函数体内部普遍包含 `if ... then ... fi`、`while ... do ... done`、`{ ... }` 复合命令等含 `}` 的语句。awk 的 range pattern `/^<f>\(\)/,/^}/` 遇到函数体内第一个行首 `}` 即终止匹配（例如 `if` 块的 `}`），导致计数严重偏低。

**Source（源头）**：验收准则可机器验证原则——验证命令必须能在目标语言语法下正确执行，否则给出的是虚假的通过/失败信号。

**Consequence（后果）**：拆分后的函数若含分支逻辑（几乎必然），awk 计数会远小于实际行数。可能出现 80 行函数被计为 35 行、误判通过的情况，导致拆分不彻底而无人察觉。

**Remedy（修补）**：将验证方法替换为更可靠的方案，例如用 grep -n 找函数定义行和下一个同级函数定义行，差值即为行数：
```bash
for f in _gate_check_l2 _gate_check_l3 _gate_do_transition; do
  start=$(grep -n "^${f}()" independent-review-gate.sh | cut -d: -f1)
  end=$(grep -n "^[a-zA-Z_][a-zA-Z0-9_]*()" independent-review-gate.sh | awk -F: -v s="$start" '$1>s{print $1; exit}')
  echo "$f: $(( end - start )) lines"
done
```
或在 AC 中直接声明使用 `wc -l` 手工确认，不绑定到有缺陷的 awk one-liner。

---

### 🟡 R3 · AC-8 死代码范围与 CHANGE.md 不一致

**Symptom（症状）**：CHANGE.md 第 35 行明确列出 3 个待清理死函数：`estimate_tokens()` / `read_correction_file()` / `file_not_empty()`。AC-8（第 69-73 行）的 Given 和 Then 仅涉及 `estimate_tokens()` 一项，`read_correction_file()` 和 `file_not_empty()` 未出现在任何 AC 中。

**Source（源头）**：需求与变更文档一致性原则——REQUIREMENT 是 CHANGE 的规格化，CHANGE 声明的范围若未全部映射到 AC，则实施时可能遗漏，或实施者需自行判断是否处理另外两项死代码。

**Consequence（后果）**：实施者可能只清理 `estimate_tokens()`，留下另外两处死代码。若在 TEST 阶段被发现，需额外修复循环；若未发现，死代码继续存在于源码中。

**Remedy（修补）**：
- 若 `read_correction_file()` 和 `file_not_empty()` 不在本次范围：在 CHANGE.md 的"范围排除"或 REQUIREMENT.md 的 v2/out 中显式说明延后原因。
- 若在本次范围：扩展 AC-8 的 Given 子句，将三个函数名列全；Then 子句增加对应的 grep 验证命令：
  ```
  grep -E 'estimate_tokens|read_correction_file|file_not_empty' transcript-parser.sh  # 期望无匹配
  ```

---

### 🟡 R4 · AC-7 timeout `.done` 不写入 的 bats 测试方法未指定

**Symptom（症状）**：AC-7 第 3 场景要求验证 "timeout 后 `.done` 不写入"（第 66 行）。但 REQUIREMENT.md 未说明如何在 bats 测试中（a）模拟 L3 API 超时，（b）验证一个文件在超时后确实未被创建或修改。这涉及 mock/fake 外部依赖和文件系统时间戳比对，比前两个场景复杂得多。

**Source（源头）**：验收准则的可实施性原则——AC 的验证方式应当指明关键技术手段，尤其是涉及外部依赖模拟的场景。

**Consequence（后果）**：TEST 阶段实施者可能因不知道如何模拟 timeout 而写出虚假通过的测试（例如直接检查 `.done` 文件在测试前的状态），导致 timeout 路径实际未覆盖。

**Remedy（修补）**：在 AC-7 的验证方式或 Given 中补充技术路径提示，例如：
```
Given: 通过 $HOOK_BASE_DIR/lib/l3-review.sh 提供的 mock 注入点（或用 bats mock 覆盖 l3_review_run 中
       的 curl 调用），设置 curl 返回码 28（超时）或注入 sleep 35 秒
When: 调用 l3_review_run()
Then: ① verdict=timeout ② 检查 .done 文件的 mtime 不晚于测试开始时间（或 .done 文件不存在）
```
若当前代码无 mock 注入点，则还需在 DESIGN 阶段补充可测试性改造。

---

### 🟡 R5 · `done-validation.sh` 在 CHANGE.md 触碰模块列表但未在 REQUIREMENT 中说明变更

**Symptom（症状）**：CHANGE.md 第 49 行将 `done-validation.sh` 列为触碰模块，但 REQUIREMENT.md 的 9 条 AC、v1 范围列表、v2 延后列表、out 排除列表中均未提及对该文件的任何变更。

**Source（源头）**：需求与变更文档一致性原则——若一个文件被列入影响面但没有任何 AC 或范围条目说明其变更性质，则变更范围存在不确定性。

**Consequence（后果）**：实施者不确定是否应修改 `done-validation.sh`、修改什么。若该文件因 `correction-types.sh` 提取或 `common.sh` DRY 改动而被间接影响（如 source 路径调整），应在 REQUIREMENT 中标注为被动变更并关联到相应 AC。

**Remedy（修补）**：二选一——
- 若 `done-validation.sh` 确需修改（如因解环而调整 source 路径）：在 AC-2 或新增范围条目中说明对该文件的被动变更。
- 若 `done-validation.sh` 实际不需修改：从 CHANGE.md 触碰模块列表中移除，避免误导。

---

### 🟡 R6 · AC-6 验证 grep 仅检查 6-review.md 未覆盖 7-integration.md

**Symptom（症状）**：AC-6 的 Then 子句要求"两 prompt 中不再含完整 jq goal 解析代码块"（指 6-review.md 和 7-integration.md），但验证方式（第 60 行）的 grep -L 命令仅针对 `6-review.md`，未检查 `7-integration.md`。

**Source（源头）**：验收准则的完整覆盖原则——验证命令必须覆盖 Then 子句声明的全部验收对象。

**Consequence（后果）**：即使 7-integration.md 中的 jq goal 解析代码块未被移除，验证脚本仍可能返回通过，因为验证命令根本不检查该文件。

**Remedy（修补）**：扩展验证命令，同时检查两个文件：
```bash
for f in flow-kit-bundle/flow-kit/prompts/6-review.md flow-kit-bundle/flow-kit/prompts/7-integration.md; do
  grep -q "goal.scope\|goal.current_phase\|goal.start_phase" "$f" && echo "FAIL: $f still contains jq goal parsing" && exit 1
done
echo "OK: both prompts cleaned"
```

---

### 🟢 R7 · AC-2 jscpd 工具引用可能不适用于 Bash

**Symptom（症状）**：AC-2 第 29 行 Given 子句写"jscpd/circular-deps 可检测"。jscpd（jscodeshift/jscpd）是 JavaScript/TypeScript 的 copy-paste 检测工具，其循环依赖检测能力主要针对 Node.js require/import 图，不原生支持 bash `source` 依赖分析。

**Source（源头）**：验收准则的精确性原则——引用的工具应与目标语言匹配，否则验收者可能花时间寻找/安装不适用的工具。

**Consequence（后果）**：验收者尝试用 jscpd 检测 bash 循环依赖时发现不适用，需自行寻找替代方案，浪费时间且可能产生不一致的检测结果。

**Remedy（修补）**：将 Given 中的工具引用改为已有的 grep-based 检测（与 AC-2 验证方式一致），或指明实际可用的循环依赖检测方法：
```
Given: correction-file.sh ↔ interactive-ui-check.sh ↔ weak-model-compliance.sh 三向 source 依赖环
       （可通过 grep -r "source.*correction-file.sh" hooks/ 交叉检测确认）
```

---

### 🟢 R8 · 非功能需求"性能: 无"过于绝对

**Symptom（症状）**：非功能性需求第 120 行写"性能: 无（纯重构，不改变运行时复杂度；L3 API 调用路径不变）"。虽然重构不改变算法复杂度，但 bash 函数调用有非零开销——AC-1 将 175 行内联代码拆为 3-4 个子函数调用，每次 Stop hook 执行时多 3-4 次函数调用帧。

**Source（源头）**：非功能需求完整性原则——即使是重构，也应评估并声明性能影响量级（哪怕为可忽略），而非写"无"。

**Consequence（后果）**：若某次回归测试发现 Hook 执行时间增加 50-200ms（bash 函数调用开销在循环热路径上可能累积），排查人员会因需求文档声称"无影响"而首先怀疑其他变更，延长定位时间。

**Remedy（修补）**：将"性能: 无"改为：
```
性能: 无显著影响（纯重构，不改变运行时复杂度；函数调用级拆分引入的额外开销预计 <100ms/hook 调用，
可在 AC-3 bats 全量测试中附带 time 对比确认）
```

---

### 🟢 R9 · AC-3 "128 个 L3 相关测试" 未提供来源或映射

**Symptom（症状）**：AC-3 第 38 行声明"现有 128 个 L3 相关测试 0 fail"，但未说明这个数字如何得出、哪些测试文件属于 L3 相关，也未给出在 test/ 目录中识别它们的正则或命名约定。

**Source（源头）**：验收准则的可追溯性原则——定量声明必须可复现，否则验收者无法独立验证数字的准确性。

**Consequence（后果）**：验收者执行 `npx bats test/` 后看到全量 407 tests 通过，但无法独立确认其中确实有 128 个与 L3 相关。若实际 L3 相关测试不足 128 个，全量通过可能掩盖 L3 专项覆盖不足。

**Remedy（修补）**：在 AC-3 或其注释中补充 L3 相关测试的范围定义，例如：
```
128 个 L3 相关测试 = test/test_l3_*.bats + test/test_independent_review_gate.bats +
test/test_fix_compliance.bats（可通过 grep "l3\|independent.review" test/*.bats | grep "^@test" | wc -l 确认）
```

---

**Verdict**: pass

> 0 项 Critical。6 项 Major（R1-R6）均为 AC 的可验证性和范围一致性缺陷，建议在进入 DESIGN 阶段前修正。3 项 Minor（R7-R9）为文档精确性改进。所有 AC 具备可执行的 Given/When/Then 骨架，无"空话 AC"，范围切分合理。修复 Major 项后质量可达 excellent。

---

## L3 重审（deepseek-v4-flash[1m] 外部模型 · 2026-07-11 01:43）

> 自动生成于 2026-07-11 01:43。由 l3-review.sh 写入。

### 审查结论

```json
{"critical":[{"file":"AC-4 (bash -n 语法门禁)","issue":"Given 中未列出具体修改文件，仅说“所有修改的.sh文件列表（9个源文件+1个新测试文件）”，但未提供文件名或可引用来源，导致验收准则无法直接验证。","why":"验收准则必须 Given/When/Then 可验证且无歧义；缺少文件列表意味着验证者无法确定哪些文件需执行 bash -n。","fix":"在 AC-4 Given 中显式列出 10 个文件名（或声明从 CHANGE.md 中的修改文件列表获取）。"}],"major":[{"file":"AC-1 (长函数拆分)","issue":"验证方式中 grep 命令使用了占位符 `<func>()`，未给出实际函数名列表，执行者需自行推断。","why":"虽然通过上下文可推知，但严格按模板执行时可能产生歧义，不同执行者可能选错函数名。","fix":"将验证方式中的 `start=$(grep -n \"^<func>()\" <file> ...)` 替换为具体函数名示例，或增加说明“将 <func> 替换为实际函数名”。"},{"file":"AC-1 (长函数拆分)","issue":"“_gate_phase_transition 编排器 ≤ 50 行”中的“编排器”未在 Given/When 中明确定义。","why":"编排器可能指拆分后的主函数，但未指定该主函数的名称，若拆分后名称变化则验证困难。","fix":"在 When 中明确编排器名称，例如“`_gate_phase_transition` 变为编排器函数（仍命名为 `_gate_phase_transition`）且 ≤ 50 行”。"}],"minor":[{"file":"AC-3 (行为零回归)","issue":"Given 提到“6 个 hook/lib 源文件 + 测试补齐”，但未与 AC-4 的文件列表对齐（AC-4 说 9 个源文件）。","why":"数量不一致可能引起混淆，但 AC-3 本身不依赖具体数目，仅要求全量测试通过；属于文档内部不一致。","fix":"统一两处文件计数（如修改范围实际涉及 9 个源文件，则 AC-3 Given 也应改为 9 个）。"},{"file":"AC-2 (依赖环消除)","issue":"验证方式中 `grep -r` 的搜索路径为 `hooks/`，但工件未明确说明所有相关文件位于 `hooks/` 下（可能也在 `lib/` 等其他目录）。","why":"搜索范围过窄可能导致漏检，但根据上下文大部分 hook 文件在 hooks/ 下，风险较低。","fix":"明确指定搜索路径如 `hooks/ lib/` 或使用更宽泛的 `flow-kit-bundle/`。"}],"verdict":"fail","summary":"存在 1 个 critical 问题（AC-4 Given 缺少具体文件列表导致不可验证），2 个 major 问题（AC-1 验证命令占位符和编排器未定义），以及 2 个 minor 问题（AC-3/AC-4 文件数不一致、AC-2 搜索路径不完整）。需修复 critical 后方可进入下一阶段。"}
```

---

## L3 重审（deepseek-v4-flash[1m] 外部模型 · 2026-07-11 01:49）

> 自动生成于 2026-07-11 01:49。由 l3-review.sh 写入。

### 审查结论

```json
{
  "critical": [
    {
      "file": "AC-3",
      "issue": "验收准则中测试总数内部矛盾",
      "why": "AC-3 的 Given 标明新增一个 `.bats` 测试文件（含3个测试场景），但 Then 要求全量测试结果为 `407 tests, 0 failures`。新增测试后总测试数应为至少 410（假设原数为407），该条件无法同时满足，导致验收不可达且验证方式失效。",
      "fix": "修正 Then 为 `npx bats test/` 全量通过（退出码0），不写死具体数字；或明确说明原407个测试基础上新增后总数为410并更新对应验证命令。"
    }
  ],
  "major": [
    {
      "file": "非功能性需求/性能",
      "issue": "性能要求无可验证的验收准则",
      "why": "工件在非功能性需求中声明性能无显著影响（预计<100ms），但未提供对应的 AC 来实际验证该指标。仅依赖 AC-3 的 time 附带对比（并未强制），导致性能退化可能漏检。",
      "fix": "新增一条轻量 AC，例如：`When` 执行修改前后各一次 `time npx bats test/test_independent_review_gate.bats`，`Then` 耗时差异 ≤200ms。"
    },
    {
      "file": "AC-1 / 验证方式",
      "issue": "make lint 目标未在工件中定义",
      "why": "验证方式提到 `make test && make lint`，但整个工件未定义 `make lint` 目标，可能导致验证步骤失败或不可执行。",
      "fix": "将验证方式中的 `make lint` 替换为工件已有或明确的目标（如 `bash -n` 检查），或确保 `make lint` 在项目中存在并说明。"
    }
  ],
  "minor": [
    {
      "file": "AC-3",
      "issue": "Given 文件清单与 AC-4 不一致",
      "why": "AC-3 的 Given 列出10个.sh + 1个.bats + 2个.md，但 AC-4 仅列出10个.sh，未包含 .bats 和 .md 文件。虽然不影响可验证性，但造成工件内部引用不统一。",
      "fix": "统一在 AC-3 或 AC-4 中完整列出所有修改文件，或使 AC-3 直接引用 AC-4 清单并注明额外文件。"
    }
  ],
  "verdict": "fail",
  "summary": "AC-3 存在测试总数矛盾，导致验收条件不可满足，构成 critical 缺陷。此外性能验证缺失、验证命令依赖未定义目标，需修正后方可通过。"
}
```

---

## L3 重审（deepseek-v4-flash[1m] 外部模型 · 2026-07-11 02:06）

> 自动生成于 2026-07-11 02:06。由 l3-review.sh 写入。

### 审查结论

```json
{"critical":[],"major":[],"minor":[{"file":"AC-1","issue":"函数行数验证命令不稳健","why":"grep命令可能因函数定义格式不同而失败","fix":"建议改用更精确的方法，如 awk '/^[a-zA-Z_]+\(\)/{if(s) print NR-s; s=NR}' 或手工 wc -l。"},{"file":"AC-5","issue":"依赖未定义的测试文件 test/test_common.bats","why":"该测试文件可能不存在，导致AC-5的测试验证无法执行","fix":"需确认 test_common.bats 存在，或在验证方式中改为 `npx bats test/` 或指定其他文件。"},{"file":"AC-6","issue":"make check 目标未定义","why":"未在工件中说明 make check 的具体行为，可能不存在","fix":"应明确 make check 的具体命令或使用 npx bats 替代。"},{"file":"AC-9","issue":"grep 命令缺少 -E 选项","why":"使用 \\| 作为或操作符需要 grep -E 或 egrep，否则可能不生效","fix":"改为 grep -E 或使用 grep -P 等。"},{"file":"非功能性需求","issue":"无对应的验收准则","why":"兼容性、可观测性等要求没有对应的 AC 来验证","fix":"建议为关键非功能性需求添加 AC，例如增加 bash 版本检测或日志格式检查。"}],"verdict":"pass","summary":"AC整体可验证且无歧义，范围切分合理，但存在若干验证方式的实现细节及测试依赖问题，建议修复后实施。"}
```
