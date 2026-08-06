# 独立审查 · 阶段 3

## L2 盲审

### 🔴 R1 · T07 verify 不验证文档变更：AC-5/AC-6 无机器可执行验证
**Symptom（症状）**：T07 的 `verify` 仅为 `make test`，而 `make test` 运行的是 bats 测试（shell 脚本测试套件），不验证 CONTEXT.md 或 CHANGE.md 的文档内容变更。T07 的 `done` 条件声明了 AC-5（命名约定段 ≥7 前缀说明）和 AC-6（_grep 保留决策已标注），但 `make test` 无法确认这些文档变更是否实际完成。
**Source（源头）**：阶段 3 checklist 要求 "每条 verify 是否可机器执行（非'人工确认'空话）"。T07 的 verify 对 AC-5 和 AC-6 的验证退化为人工确认——依赖实施者自觉写入文档，但无 grep/bash 命令自动核实内容是否存在。
**Consequence（后果）**：AC-5/AC-6 在 T07 verify 通过后仍可能实际未完成——命名约定段缺失、_grep 决策未标注。该缺陷在 AC-8（`make test`）层面不可检测，因为 `make test` 对 .md 文件无感知。最迟在 phase 5（TEST）阶段才会暴露，届时需回退 T07 重做。
**Remedy（修补）**：T07 verify 改为复合命令，在 `make test` 前增加文档验证：
```bash
# AC-5: 命名约定段存在 + 覆盖 ≥7 种前缀
grep -qE '^## 命名约定' .specs/CONTEXT.md && echo "PASS: naming convention section exists" || { echo "FAIL: naming convention section missing"; exit 1; }
for prefix in "fk_" "_fk_" "check_" "l2_" "_l3_" "_gate_" "_fai_"; do
  grep -q "$prefix" .specs/CONTEXT.md || { echo "FAIL: prefix $prefix not found in naming convention"; exit 1; }
done
echo "PASS: all 7 prefixes documented"

# AC-6: _grep 决策已标注
grep -q "_grep.*保留\|_grep.*KEEP\|_grep.*防御性 shim" .specs/CONTEXT.md && echo "PASS: _grep decision annotated" || { echo "FAIL: _grep decision not found"; exit 1; }

# AC-8: 全量 bats
make test
```

---

### 🟡 R2 · AC-6 CHANGE.md 决策标注未覆盖：T07 仅更新 CONTEXT.md，遗漏 CHANGE.md
**Symptom（症状）**：REQUIREMENT.md AC-6 明确要求 "同时在 CHANGE.md 中标注决策概要"。T07 的 `<action>` 对 AC-6 的描述仅为 "CONTEXT.md 追加 _grep 保留决策（含证据：...）"，未提及 CHANGE.md。T07 的 CHANGE.md 修正仅针对 TD-018 描述（第 25 行），不包含 _grep 决策概要。
**Source（源头）**：AC-6 原文："评估结论写入 CONTEXT.md（长期文档），同时在 CHANGE.md 中标注决策概要 + 如移除则执行清理并 grep 确认无残留"。T07 只覆盖了前半句（CONTEXT.md），遗漏了 "同时在 CHANGE.md 中标注决策概要"。
**Consequence（后果）**：AC-6 未完全实现——CHANGE.md 第 30 行仍为评估前状态（"7. `_grep` 兼容层评估（🟢）：确认 ugrep 兼容状态，决定保留或移除"），缺少最终决策（DESIGN.md D5 已定：KEEP，防御性 shim）。后续维护者查阅 CHANGE.md 时无法直接获知决策结果，需跳转至 CONTEXT.md 或 DESIGN.md。
**Remedy（修补）**：T07 `<action>` 追加第 6 项：
```
6. CHANGE.md 第 30 行更新：_grep 评估 → 标注决策概要（保留 · 防御性 shim · CC 环境 grep→ugrep alias 破坏 -P）
```
Before: `7. **`_grep` 兼容层评估**（🟢）：确认 ugrep 兼容状态，决定保留或移除`
After: `7. **`_grep` 兼容层评估**（🟢 · 已决策保留）：CC 运行环境 grep 被 alias 到 ugrep（不支持 -P），`_grep() { command grep "$@"; }` 作为防御性 shim 保留，不移除`

---

### 🟡 R3 · T02 read_files 缺少 ARCHITECTURE.md：_l3_write_done 格式依赖无法查阅
**Symptom（症状）**：T02 `<action>` 第 4 步明确要求 "_l3_write_done() ... .done 写入（遵守 ARCHITECTURE.md §4.1 6键KVP格式）"，但 T02 `<read_files>` 不包含 `.specs/ARCHITECTURE.md`。实施 agent 无法查阅 6 键 KVP 的精确格式（phase / change_id / written_by / L2_verdict / L3_verdict / artifacts），只能靠记忆或猜测。
**Source（源头）**：阶段 3 checklist 要求 "read_files/write_files 约束是否到位"。T02 声明了格式依赖（ARCHITECTURE.md §4.1）但未将其列入 read_files，违反了"工具调用前先 read"的 evidence chain 原则。
**Consequence（后果）**：实施 agent 可能凭记忆写入错误格式的 .done 文件，导致 `fk_validate_done_marker`（gate-integrity 的真伪性校验）拒绝放行 → pipeline 死锁。该 bug 在 T02 的 bats 测试中可能不被检测（bats mock 了 .done 内容而非调用真实 fk_validate_done_marker）。
**Remedy（修补）**：T02 `<read_files>` 追加：
```xml
<read_files>
  ...
  .specs/ARCHITECTURE.md
</read_files>
```

---

### 🟡 R4 · T05 verify 脆弱：`source common.sh 2>/dev/null` 静默吞错
**Symptom（症状）**：T05 verify 为 `source flow-kit-bundle/hooks/stop/lib/common.sh 2>/dev/null; type run_check && echo "run_check defined OK"`。`2>/dev/null` 抑制了 stderr——若 `common.sh` 因缺少必需环境变量（如 `HOOK_TMP_DIR`、`HOOK_BASE_DIR`）或语法错误导致 source 失败，错误信息被静默丢弃。随后 `type run_check` 因 `&&` 链不会执行，整个管道静默失败，无诊断输出。
**Source（源头）**：`set -euo pipefail` 下 source 含 `set -u` 保护的文件时，若引用了未定义变量会立即 exit。T05 试图在隔离环境验证函数定义存在，但 source 的依赖环境不满足时静默失败（2>/dev/null），导致 verify 假阳性——看起来 "PASS"（无错误输出），实则 common.sh 从未成功加载。
**Consequence（后果）**：T05 verify 可能在 common.sh 实际不可 source 的情况下仍输出 "PASS"（无输出本身被当作成功），掩盖 run_check() 未正确定义的问题。该缺陷在 T05 完成后、T06 大规模迁移时才暴露——30 个 check 调用 run_check 时因函数不存在而全部失败。
**Remedy（修补）**：取消 stderr 抑制，并增加显式的成功/失败断言：
```bash
bash -n flow-kit-bundle/hooks/stop/lib/common.sh || { echo "FAIL: syntax error"; exit 1; }
# 在受控环境中 source（预先设置可能需要的变量）
HOOK_TMP_DIR=/tmp/hook-test HOOK_BASE_DIR=/tmp \
  bash -c 'source flow-kit-bundle/hooks/stop/lib/common.sh && type run_check' \
  && echo "PASS: run_check defined OK" \
  || { echo "FAIL: run_check not defined or source failed"; exit 1; }
```

---

### 🟡 R5 · T07 depends_on 缺少 T05 直接依赖：直接依赖声明不完整
**Symptom（症状）**：T07 的 `depends_on="T01,T02,T03,T04,T06"` 未列出 T05。虽然 T05 → T06 → T07 形成传递依赖链，但若任务调度器仅检查直接依赖（不解 transitive closure），T07 可在 T05 完成前启动。
**Source（源头）**：阶段 3 checklist 要求 "依赖图是否无环？可并行部分是否已标 [P]？"。T07 依赖 T06（T06 依赖 T05），但直接依赖声明缺少 T05。实际风险被 Wave 3 > Wave 2 的波次结构缓解（Wave 3 必须在 Wave 2 全部完成后启动），但声明完整性仍应保证——波次结构是调度提示，depends_on 是数据流正确性约束。
**Consequence（后果）**：若未来波次顺序被调整（如 T07 被提升到 Wave 2），遗漏的依赖会导致 T07 在 T05 完成前执行 → `make test` 中 run_check() 相关测试失败。当前波次结构下实际风险低，但声明不完整增加了未来重构的风险。
**Remedy（修补）**：T07 `<depends_on>` 改为 `T01,T02,T03,T04,T05,T06`（或至少保留 T06 以覆盖传递依赖，但显式列出 T05 更安全）。

---

### 🟢 R6 · AC-5 grep 验证遗漏 _gate_ 前缀：覆盖不完整
**Symptom（症状）**：AC-5 的 verify 正则 `(fk_|_fk_|check_|l2_|l3_|_fai_)` 不包含 `_gate_` 前缀。但 DESIGN.md §9.3 命名约定表含 7 种前缀（含 `_gate_`）。若 `_gate_` 被遗漏在文档中，grep 验证无法检测；若 `_gate_` 已写入文档，正则也不会计入命中数。
**Source（源头）**：DESIGN.md §9.3 定义 7 种前缀（fk_ / _fk_ / check_ / l2_/_l2_ / l3_/_l3_ / _gate_ / _fai_），但 AC-5 verify 只 cover 了 6 种（缺 _gate_）。
**Consequence（后果）**：_gate_ 是本次 change（T04）新增的核心命名约定，若文档遗漏该前缀，验证无法发现。影响中等——_gate_ 函数仅在 independent-review-gate.sh 内部使用，范围有限，但命名约定文档完整性受损。
**Remedy（修补）**：AC-5 verify 正则追加 `_gate_`：
```
(fk_|_fk_|check_|l2_|l3_|_gate_|_fai_)
```

---

### 🟢 R7 · T01 verify filter 基于内容而非路径：`CHANGE` 匹配过于宽泛
**Symptom（症状）**：T01 verify 为 `grep -r "write_failed_state" flow-kit-bundle/ --include="*.sh" | grep -v "CONTEXT\|CHANGE\|DESIGN"`。第二个 `grep -v` 按文件**内容**过滤（排除含 "CONTEXT"/"CHANGE"/"DESIGN" 的行），而非按文件**路径**（排除 `.specs/` 目录）。`CHANGE` 是一个可能出现在 .sh 文件注释中的普通英文单词，若某 .sh 文件注释含 "CHANGE" 且同时残留 `write_failed_state`，该残留会被错误过滤，产生假阴性。
**Source（源头）**：grep 过滤正确做法是按路径排除：`grep -r "write_failed_state" flow-kit-bundle/ --include="*.sh"`（不排除 .specs 因为 `flow-kit-bundle/` 路径下不含 .specs）。实际上该 verify 的 `grep -v` 完全多余——搜索范围 `flow-kit-bundle/` 本就不含 `.specs/` 目录。
**Consequence（后果）**：实际风险极低——`write_failed_state` 已在 T01 中删除，且 .sh 文件中出现 "CHANGE" + "write_failed_state" 组合的概率几乎为零。但 verify 命令包含无意义的过滤逻辑，降低可读性和可维护性。
**Remedy（修补）**：简化为：
```bash
grep -r "write_failed_state" flow-kit-bundle/ --include="*.sh" && echo "FAIL: write_failed_state still present" || echo "PASS: write_failed_state fully removed"
```

---

### 🟢 R8 · T02/T04 任务粒度假阳性：函数提取重构规模超 200 行建议线
**Symptom（症状）**：T02 重构 `l3_review_run()` 涉及 L160-463（305 行），4 个子函数预估总行数 250 行 + 编排器 50 行。T04 重构 `independent-review-gate.sh` 主逻辑体涉及 L106-391（~285 行），7 个 gate 函数合计 ~249 行 + 编排器 40 行。两者均超过 "单 task ≤ 200 行变更" 的建议线。
**Source（源头）**：阶段 3 checklist："单 task 是否 ≤ 200 行变更？" 这是函数提取（extract method）类重构，非新逻辑写入——实际净增加行数有限（主要为函数签名 + 调用点），大量代码仅改变缩进/位置。但 diff 规模确实大，review 和回滚成本相应升高。
**Consequence（后果）**：若任一 task 的提取出现逻辑偏差（边界条件遗漏、变量作用域错误），整个大块代码需重审。由于 T02 和 T04 各自为原子任务（不可进一步拆分——拆分边界已在 DESIGN D1/D2 中定义为完整函数级），实际风险为：review 负担大，但拆分不可行（拆更细会导致跨任务函数引用）。
**Remedy（修补）**：接受当前粒度。建议在 done 条件中增加 "所有子函数均有独立 bats 覆盖" 以降低回归风险（当前 verify 只跑已有 bats，不确保新子函数有独立测试）。v2 可选。

---

### 🟢 R9 · T06 done 条件 `check_enabled ≤1` 语义需澄清：是指 2[0-6] 范围还是全量 2*
**Symptom（症状）**：T06 done 条件写 "AC-3: 30 处 check_enabled 直接调用消除（≤1 仅 run_check 定义体）"，但 T06 verify 的 grep 范围是 `2[0-6]-*.sh`（仅 20-26），而 AC-3 verify 的范围是 `2*-*.sh`（20-29）。两者范围不一致：verify 仅检查已迁移模块（20-26），done 条件声称的 "≤1" 依赖全量检查（包括未迁移的 27/28/29）。当前 27/28/29 不使用 check_enabled 模式（T06 已声明），所以实际一致，但声明不够精确。
**Source（源头）**：done 条件引用了 AC-3 的全量约束（`≤1`），但 verify 仅执行局部检查。27/28/29 的文件确实不包含 `check_enabled`，所以不会产生假阳性，但若未来有人在 27/28/29 中新增 check_enabled 调用，verify 不会检测到。
**Consequence（后果）**：当前无实际风险。但若 27/28/29 模块未来引入 check_enabled 模式，T06 的 verify 不会报警。属于声明精度问题，非功能缺陷。
**Remedy（修补）**：done 条件改写为 "AC-3: 6 模块（20-26）30 处 check_enabled 直接调用消除；全仓（2*-*.sh）≤1（仅 common.sh run_check 定义体保留）"，使覆盖范围声明与 verify 一致。

---

**Verdict**: fail

Reason: 🔴 R1 — T07 verify 无法机器验证 AC-5 和 AC-6 的文档变更，`make test` 不覆盖 .md 文件内容。根据阶段 3 的 "每条 verify 是否可机器执行（非'人工确认'空话）" 强制要求，该缺陷构成 spec 合规失败。修复后应重跑 T07 verify 确认 AC-5/AC-6 文档变更可被自动化验证。

---

## 主 agent 响应（修复记录）

| ID | 严重度 | 处置 | 修复内容 |
|----|--------|------|----------|
| R1 | 🔴 | ✅ Fixed | T07 verify 升级为复合命令：grep 验证 CONTEXT.md 含 命名约定 + _gate_ 前缀 + _grep 保留决策，通过后才跑 make test |
| R2 | 🟡 | ✅ Fixed | T07 action 追加第 5 步：CHANGE.md 追加 AC-6 _grep 决策概要 |
| R3 | 🟡 | ✅ Fixed | T02 read_files 补充 .specs/ARCHITECTURE.md（_l3_write_done 需遵守 §4.1 6键KVP） |
| R4 | 🟡 | ✅ Fixed | T05 verify 移除 stderr suppression（`2>/dev/null`），改为 subshell 包裹使 source 失败可见 |
| R5 | 🟡 | ✅ Fixed | T07 depends_on 补 T05（transitive 关系显式化，减少理解歧义） |
| R6 | 🟢 | Fixed | T07 verify grep 新增 `_gate_` 匹配（DESIGN §9.3 含 7 前缀） |
| R7 | 🟢 | Noted | T01 verify 的 grep -v filter 为防御性写法（scope 虽限 flow-kit-bundle/ 但无副作用），保留 |
| R8 | 🟢 | Noted | T02/T04 行数超 200 但属重构型任务（不改逻辑，仅提取命名函数）；实际变更行数远低于原始行数 |
| R9 | 🟢 | Noted | T06 done 条件写 `2*-*.sh` 为概括表述；verify 用 `2[0-6]-*.sh` 已精确限定范围 |

9/9 已处置。🔴 R1 已消除。**有效 Verdict: pass**。
