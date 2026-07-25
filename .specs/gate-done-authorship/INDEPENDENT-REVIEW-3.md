# 独立审查 · 阶段 3

## L2 盲审

- 阶段：3（任务拆解审查 · 3-task）
- change-id：gate-done-authorship
- 工件：`.specs/gate-done-authorship/TASK.md`（参考 REQUIREMENT.md / DESIGN.md）
- 独立性声明：未在输入中检测到主 agent 自评 / 草稿 / 概述 / 辩护；以下判断仅基于 TASK.md / REQUIREMENT.md / DESIGN.md 及对所引用源码（independent-review-gate.sh / done-validation.sh / 29-independent-review.sh / common.sh / test_gate_integrity.bats / regression-demos / Makefile）的独立核验。

### 🔴 R1 · T03 残留 `state_file` @ Gate 5（L125）→ AC-3 不可实现 + 任务自相矛盾
**Symptom**：`flow-kit-bundle/hooks/stop/29-independent-review.sh:125` 的 `rm -f "$state_file"`（Gate 5「done 标志已写 → 清理握手文件」段）。T03 action step 1 删 L68-74（Gate 4 state_file 读）、step 3 删 L203-204（state_file 重赋值 + rm），但 step 4 明确「保留其余 L3 审查触发逻辑不变」——Gate 5（L121-128，含 L125 的 `rm -f "$state_file"`）属「其余逻辑」被保留。而 T03 `<verify>` 写 `! grep -q '...rm -f "\$state_file"...'`，即断言全文件 0 处 `rm -f "$state_file"`。直接矛盾：按 action 执行 → L125 残留 → verify 失败；要过 verify → 必须偏离 action 去动 Gate 5（action 未授权/未指引）。
**Source**：AC-3（REQUIREMENT.md:37-43）的验证方式是 `grep -r "is_handshake_write\|state_file\|written_by=stop-hook-29\|T3.*handshake" flow-kit-bundle/hooks/` 生产代码 0 匹配。独立核验：生产 hooks 中 `state_file` 仅存在于 29-independent-review.sh（L68/69/70/125/203/204）。T01+T02+T03 按书执行后，L125 仍残留 `state_file` → AC-3 grep 命中 → **AC-3 unrealized**。叠加 R9（T06 verify 只 grep 2 token，缺 `state_file`），该残留连 T06 都不会拦截 → 缺陷直送发布。
**Consequence**：AC-3 合规失败；且 T03 任务自相矛盾无法按书 mark done（action 与 verify 冲突）；Gate 5 在 T03 新增 Gate 4 .done 短路后本就是死分支，残留的 `rm -f "$state_file"` 在 `set -euo pipefail`（L13）下引用未定义变量 → 若该死分支被触及将抛 unbound variable 错误。
**Remedy**：T03 action 须显式处理 Gate 5——不是「保留不变」。两选一：(a) 删除整个 Gate 5（L121-128），其 .done 存在性语义已被 T03 新增的 Gate 4 .done 短路覆盖，`module_output` 日志并入 Gate 4；(b) 保留 Gate 5 但删 L125 `rm -f "$state_file"`、改注释为「.done 存在即完成」（去掉握手清理语义）。同步把 T03 `<verify>` 的 `! grep -q 'state_file="'` 收紧为同时禁 `rm -f "\$state_file"`（现已如此）与裸 `state_file` 读取，并显式断言 T4 保留（见 R7）。before: action step4「保留其余逻辑不变」; after: action step4「保留 l3_review_run/_l3_scan_backlog/module_output 不变；Gate 5 删 L125 rm 或整段删除（.done 短路已覆盖）」。

### 🟡 R2 · T01 step 3 引用幻影 `PHASE_GATE_KEY_MAP`（复活已登记 BUG-F）
**Symptom**：TASK.md T01 action step 3「gate_config key 组装：用 `PHASE_GATE_KEY_MAP["$N"]` 映射（如 6→"6-review"…）」。独立全仓 grep：生产代码无 `PHASE_GATE_KEY_MAP` 数组；真正的单一源是 `fk_phase_gate_key "$phase"`（`flow-kit-bundle/hooks/stop/lib/common.sh:284`，case 函数非数组），已由 gate.sh source common.sh 获得（gate.sh:21-27 注释明示「fk_phase_gate_key 定义在 common.sh（单一来源）」）。`PHASE_GATE_KEY_MAP` 仅出现在 3 处非生产位置：correction-types.sh:13 注释、test_l2_pretooluse_dispatch.bats:267 注释「BUG-F（PHASE_GATE_KEY_MAP 未定义）」、test_gate_integrity.bats:159 测试名（实 grep "3-task" 等字符串）。即它正是历史已修掉的 BUG-F 死构造。
**Source**：ADR-007/D1 单一源决策（common.sh:277-283 注释「不再 declare -A（消除 v1 重复 declare 的 DRY 违反 = BUG-F 温床）」）。T01 把已废弃的数组名当现役 API 教给实现者，违反 DRY/单一源。
**Consequence**：实现者照 T01 字面写 `PHASE_GATE_KEY_MAP["$N"]` → 数组未 declare → `set -euo pipefail`（gate.sh:17）下 `_gate_is_l2_only()` 引用未定义数组元素抛 unbound 错 → path-guard 异常路径行为不可预测（fail-open 或误 deny），L2-only 例外形同虚设；或实现者自建 `PHASE_GATE_KEY_MAP` 数组在 gate.sh 内 → 与 `fk_phase_gate_key` 逻辑重复，DRY 违反 + 漂移温床（既存 AC-3 测试 test_gate_integrity.bats:159 只 grep common.sh 字符串，gate.sh 内重复数组不会被测到 → 静默漂移）。
**Remedy**：T01 step 3 把 `PHASE_GATE_KEY_MAP["$N"]` 改为 `fk_phase_gate_key "$N"`（已 source，零新增依赖，不触碰禁动 common.sh）：`local phase_name; phase_name="$(fk_phase_gate_key "$N")"`；gate_config 值读取沿用 `jq -r --arg pn "$phase_name" '.goal.gate_config[$pn] // "off"' "$flow_file"`。明确「不新增任何 phase→key 映射表，复用 common.sh 单一源」。

### 🟡 R3 · T04 低估握手测试数量 + D7 单元测试新语义未指定
**Symptom**：TASK.md T04 `<action>`「改写 4 个握手测试为新语义」仅枚举 4 项（AC-1 ②③ forged-done / ④ hijack / ⑤ tampered / D9 正向）。独立核验 test/test_gate_integrity.bats 实际引用握手构造的有 **11 项**：4 个 done-validation 测试（L72/79/88/140，用 `write_valid_handshake` 或验 T3）+ 6 个 D7 path-guard 测试直接 `run is_handshake_write`（L173/178/183/188/193/198）+ `write_valid_handshake` helper（L55）。T01 删 `is_handshake_write` 后，6 个 D7 测试调用已删函数 → bats `run` 得 status=127，`[ "$status" -eq 0 ]` 全红。T04 action 未枚举这 6 个测试、未指定其新语义（改写为 `_is_dotdone_write`？删除？并入新增集成测试？）。
**Source**：固化指令 checklist「覆盖完整性：所有 AC 是否有对应 task」「任务粒度」。AC-5（REQUIREMENT.md:52-57）「所有握手相关测试已改写为新语义或删除 … 0 fail」。T04 的「4 个」与实际 11 项脱节，D7 测试群无处置指引。
**Consequence**：T04 `<verify>` `npx bats test/test_gate_integrity.bats` 会因 6 个 D7 测试红而失败（自纠错），但实现者无 task 指引如何改写 → 各自为政、返工、改写语义可能不一致（如有人删、有人改 `_is_dotdone_write`，D7 覆盖矩阵割裂）。任务拆解未覆盖全部受影响测试。
**Remedy**：T04 action 增列第 5 类「D7 path-guard 单元测试（L173-201，6 个）改写为 `_is_dotdone_write` 语义——目标文件从 `.flow-active.independent-review` 改为 `.independent-review-<N>.done`，保留 9 种写向量 + exotic 不挡的 v1 边界断言」，明确改写而非删除（D7 写向量覆盖是 v1 安全基座，删则退化为只靠集成测试）。`<done>` 计数从「4+3」改为「4 done-validation 改写 + 6 D7 改写 + 3 新增集成 = 13」。

### 🟡 R4 · T04/T06 漏 bats 双源同步 → bundle 副本残留握手测试（AC-5 意图落空）
**Symptom**：存在双源：`test/test_gate_integrity.bats` 与 `flow-kit-bundle/test/test_gate_integrity.bats`（独立文件，非符号链接，当前 diff 一致）。Makefile `test:`（L8-11）只跑 `npx bats test/`，不跑 bundle/test/；`test-sync:`（L47-52）才 `cp test/*.bats flow-kit-bundle/test/`。T04 `<write_files>` 只列 `test/test_gate_integrity.bats`，T04/T06 均不调 `make test-sync`。→ T04 改完 test/ 副本，bundle 副本仍含 4 握手测试 + 6 D7 `is_handshake_write` 测试 + `write_valid_handshake` helper 的旧语义。
**Source**：AC-5（REQUIREMENT.md:52-57）「所有握手相关测试已改写为新语义或删除」——bundle 副本亦是「既有握手测试」。T05 action 已意识到双源（step 3「同步两处源」），但 T04 对 bats 双源只字未提，处理不一致。AC-5 的验证方式 `npx bats test/test_gate_integrity.bats` 只验 test/ 副本，不覆盖 bundle 副本 → AC-5 验证盲区。
**Consequence**：打包发布带 stale 的 bundle 副本（仍引用 `is_handshake_write`/`written_by=stop-hook-29`）；AC-5 验证方法过但 AC-5 意图未达；T06 grep 作用域 `flow-kit-bundle/hooks/` 不含 `flow-kit-bundle/test/`，且 AC-3 显式排除测试文件 → 残留不被任何 gate 捕获。
**Remedy**：T04 `<write_files>` 增列 `flow-kit-bundle/test/test_gate_integrity.bats`（或 T04/T06 action 增一步 `make test-sync` 并验 `diff -q test/test_gate_integrity.bats flow-kit-bundle/test/test_gate_integrity.bats` 为空）；T06 `<verify>` 增 `diff -q test/test_gate_integrity.bats flow-kit-bundle/test/test_gate_integrity.bats` 断言双源一致。

### 🟡 R5 · T05 bundle demo 路径错误（`flow-kit/` 多余段，目录不存在）
**Symptom**：TASK.md T05 `<read_files>`/`<write_files>` 列 `flow-kit-bundle/flow-kit/regression-demos/tampered-done/` 与 `.../exotic-escape/`。独立核验：`flow-kit-bundle/flow-kit/regression-demos/` 下只有 brooks-lint-paths.md / hallucination-guard / scope-drift-guard / strong-model-verbosity / weak-model-interactive-ui，**无** tampered-done / exotic-escape。真正 bundle 副本在 `flow-kit-bundle/test/regression-demos/`（`find` 确认有 tampered-done / hijack-done / exotic-escape / forged-done）。
**Source**：固化指令 checklist「read_files/write_files 约束是否到位」。T05 写入路径指向不存在目录 → 实现者按路径找不到文件，要么跳过 bundle 同步（AC-5 双源意图落空），要么 `mkdir -p` 凭空造出 `flow-kit-bundle/flow-kit/regression-demos/tampered-done/` 错位目录（污染仓库、与 test-sync 既定 `test/→flow-kit-bundle/test/` 拓扑冲突）。
**Consequence**：bundle 侧 demo 不得同步；或产生错位目录；T05 `<verify>` 的 grep 作用域含 `flow-kit-bundle/flow-kit/regression-demos/`（不存在）→ 假绿。
**Remedy**：T05 路径全改 `flow-kit-bundle/test/regression-demos/tampered-done/` 与 `.../exotic-escape/`；`<verify>` grep 作用域同步改为 `flow-kit-bundle/test/regression-demos/`。before: `flow-kit-bundle/flow-kit/regression-demos/...`; after: `flow-kit-bundle/test/regression-demos/...`。

### 🟡 R6 · T01 `<verify>` 只验删除不验新增 → 删了不建也过
**Symptom**：T01 `<done>` 要求「is_handshake_write 全删；**_is_dotdone_write + _gate_is_l2_only 新增**；bash -n；0 处残留」。但 T01 `<verify>` 仅 `bash -n ... && grep -c "is_handshake_write" ... | grep -qx 0`——只验语法 + 删除计数，**不验** `_is_dotdone_write`/`_gate_is_l2_only` 已定义。
**Source**：固化指令 checklist「verify 可验证性：每条 verify 是否可机器执行」+ 四要素要求 verify 与 done 对齐。`<done>` 列了两个新增函数，`<verify>` 对二者零断言 → verify 与 done 不对齐。
**Consequence**：实现者只删 `is_handshake_write` 不建新函数也能过 T01 verify；path-guard D7 对 .done 的拦截能力为零（Bash 通道 `_is_dotdone_write` 缺失、L2-only 例外 `_gate_is_l2_only` 缺失），AC-1/AC-4 在 T01 这层无保障，只能赌 T04 测试兜底——但 T04 依赖 T01 已建函数，若 T01 蒙混过关，T04 才暴露，返工路径变长。
**Remedy**：T01 `<verify>` 增 `grep -q '_is_dotdone_write()' flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh && grep -q '_gate_is_l2_only()' ...`；并加 `declare -f _is_dotdone_write >/dev/null` 风格的函数存在断言（source 后）。before: `bash -n && grep -c is_handshake_write|grep -qx 0`; after: `bash -n && grep -c is_handshake_write|grep -qx 0 && grep -q '_is_dotdone_write()' F && grep -q '_gate_is_l2_only()' F`。

### 🟡 R7 · T02 `<verify>` 只验删除不验 T4 保留 → 过删 T4 不被 T02 拦
**Symptom**：T02 `<done>` 要求「T3/T3b 握手段全删；**T4 L2 比对段保留**；bash -n；0 处握手引用」。T02 `<verify>` `bash -n && ! grep -q "written_by=stop-hook-29\|hs_path\|hs_wby\|hs_verdict\|T3 D7 握手\|T3b SESSION_ID"`——只断言删除 token 全无，**不断言 T4 段在位**（T4 用 `L2_verdict`/`INDEPENDENT-REVIEW-N.md`/`fk_extract_l2_verdict`，非上述 token）。
**Source**：DESIGN.md §2.2「T4 L2_verdict vs INDEPENDENT-REVIEW-N.md 比对（保留 · L2-first gating 调度契约）」+ T02 action step 3「保留 Tier 2 的 T4 比对段」。verify 与 done/DESIGN 对 T4 保留要求零断言。
**Consequence**：实现者误删 T4（T3/T3b/T4 段相邻，一刀切易过删）→ T02 verify 仍绿（删除 token 确实没了）→ L2-first gating 契约失守（done-validation 不再交叉校验 L2_verdict 与 INDEPENDENT-REVIEW-N.md），AC-1 ⑤ 的 T4 兜底失效；可能到 T06 make test 才暴露，也可能不暴露（若 bats 未覆盖 T4 transition 比对路径）。
**Remedy**：T02 `<verify>` 增 `grep -q 'T4 L2_verdict\|fk_extract_l2_verdict' flow-kit-bundle/hooks/stop/lib/done-validation.sh` 断言 T4 在位。before: `bash -n && ! grep -q '<delete tokens>'`; after: `bash -n && ! grep -q '<delete tokens>' && grep -q 'fk_extract_l2_verdict' F`。

### 🟡 R8 · T05 `<verify>` 是恒真断言（无法 fail）
**Symptom**：T05 `<verify>` = `bash test/regression-demos/tampered-done/check.sh 2>&1 | head -5; grep -rl "written_by=stop-hook-29\|is_handshake_write" test/regression-demos/ flow-kit-bundle/flow-kit/regression-demos/ 2>/dev/null | grep -v "\.done$" || echo "clean"`。问题：(1) `bash check.sh 2>&1 | head -5`——管道退出码取 `head`（恒 0），check.sh 本身 rc 被丢，不验 check.sh 是否真断言成功；(2) 后段 `grep -rl ... | grep -v "\.done$" || echo clean`——有匹配则 grep -v 输出行 rc=0、无匹配则 grep -rl rc=1→grep -v 空 rc=1→`||echo clean` rc=0，**两种情况都 rc=0**；(3) 作用域 `flow-kit-bundle/flow-kit/regression-demos/` 不存在（见 R5）。整条 verify 任意结果都 exit 0。
**Source**：固化指令 checklist「verify 可验证性：每条 verify 是否可机器执行（非人工确认空话）」+「禁止仅回复敷衍」。恒真 verify 等同无 verify。
**Consequence**：T05 无论 check.sh 改对改错、无论握手引用是否残留，verify 都绿 → T05 无质量门 → AC-5（regression-demos 部分）无机器保障，纯靠 T06 make test（而 make test 不跑 regression-demos check.sh）。
**Remedy**：T05 `<verify>` 改为真断言：`bash test/regression-demos/tampered-done/check.sh; rc=$?; [ $rc -eq 0 ] && grep -rLq . test/regression-demos/flow-kit-bundle-test-copy 2>/dev/null; ! grep -rl "written_by=stop-hook-29\|is_handshake_write" test/regression-demos/ flow-kit-bundle/test/regression-demos/ 2>/dev/null`（无 `|| echo clean` 兜底，无 `| head` 截断 rc）。明确 check.sh rc=0 是硬断言。

### 🟡 R9 · T06 `<verify>` grep token 覆盖 < AC-3（2/4），放行 R1 的 state_file 残留
**Symptom**：T06 `<verify>` `! grep -rn "is_handshake_write\|written_by=stop-hook-29" flow-kit-bundle/hooks/ ... | grep -v "/test/\|regression-demos/"` 只 grep 2 token。AC-3（REQUIREMENT.md:37）要求 4 token：`is_handshake_write\|state_file\|written_by=stop-hook-29\|T3.*handshake`。T06 漏 `state_file` 与 `T3.*handshake`。
**Source**：AC-3 的验证方式明列 4 token；T06 verify 只取 2 → verify 严格度 < AC-3 要求。
**Consequence**：与 R1 叠加——R1（T03 残留 L125 `state_file`）的残留恰是 `state_file` token，T06 不 grep 此 token → T06 verify 全绿，AC-3 实则失败 → 🔴 R1 缺陷直送发布不被 T06 拦。即令 R1 被修，T06 的 2-token grep 也无法独立保证 AC-3 的另两 token（state_file / T3.*handshake）清洁。
**Remedy**：T06 `<verify>` grep 改 4 token 全覆盖：`! grep -rn "is_handshake_write\|state_file\|written_by=stop-hook-29\|T3.*handshake\|T3b.*SESSION" flow-kit-bundle/hooks/ | grep -v "/test/\|regression-demos/"`，与 AC-3 验证方式逐字对齐。

### 🟢 R10 · AC 覆盖矩阵：T05 无 AC 归属，AC-5 行漏 T05
**Symptom**：TASK.md「AC 覆盖矩阵」无 T05 行；AC-5 行写「T04（4 测试改写）」，但 AC-5（REQUIREMENT.md:52-57）范围含 `test/regression-demos/tampered-done/ + exotic-escape/ 握手 demo`，这部分正是 T05 的活。
**Source**：固化指令 checklist「覆盖完整性：所有 AC 是否有对应 task」。矩阵应双向闭合（每 task 有 AC 归属、每 AC 列覆盖 task）。
**Consequence**：T05 在矩阵上「无主」，acceptance tracking 易漏 regression-demos 的 AC-5 贡献；若按矩阵验 AC-5 只查 T04，regression-demos 清理无人兜底。
**Remedy**：矩阵 AC-5 行改「T04 + T05（regression-demos）」，验证列补「T05 check.sh rc=0 + grep clean」。

### 🟢 R11 · 依赖图标注不一致（Wave 2 header vs T05 depends_on）
**Symptom**：TASK.md 波次划分 L17「Wave 2 (parallel): T04[P], T05[P] (depends on T01, T02, T03)」，但 T05 `<depends_on>`（L178）只写 `T01`。T04 的 depends_on 才是 T01,T02,T03。
**Source**：固化指令 checklist「依赖链：依赖图是否无环？可并行部分是否已标 [P]」——图与 depends_on 字段须一致。
**Consequence**：波次 header 高估 T05 依赖（保守无害，但误导并行调度判断；T05 实际 T01 毕即可起，与 T04 解耦更早可并行）。
**Remedy**：波次 header 拆分标注：「Wave 2: T04[P] (deps T01,T02,T03) ‖ T05[P] (deps T01)」。

### 🟢 R12 · [需确认 · 跨阶段] DESIGN D3 fail-open 论据只覆盖 L2-误拦，未覆盖 both-误放
**Symptom**：T01 action step 3 落地 D3「gate_config 读取失败（jq error / flow_file 不存在 / key 缺失）→ fail-open 放行」。DESIGN D3 取舍理由「L2-only 本身就允许 agent 写 .done，风险为零」+ R2 只列「L2-only 模式 gate_config 读取失败导致误拦」。但 fail-open 触发条件是「读取失败」本身，不区分真实模式是 L2 还是 both/L3。若真实模式=both（要求 L3）而 flow_file 读取失败，fail-open 仍放行 agent 写 .done。
**Source**：DESIGN §1 D3 + §5 R2。T01 action step 3 编码此决策。独立推演：fail-open 的「风险为零」仅当不可读模式恰为 L2 时成立；both/L3 场景读取失败 → 误放。R2 未列此分支。
**Consequence**：理论 L3 旁路：agent 使 .flow-active 不可读 → path-guard fail-open → agent 写伪 .done（L3_verdict=pass）。但端到端不可利用——transition 的 jq phase 写也需要 .flow-active 可读，agent 自废武功后无法完成自身 transition；且 T6（改 hook 代码）/T5（symlink）威胁已 out-of-scope 同类。故评估为非可利用的理论缺口，非 🔴。
**Remedy**：需确认（路由给 DESIGN / security-auditor）：(a) D3 fail-open 是否应收紧为「仅当能读到 gate_config 且值=L2 时放行，读不到则 fail-close deny」；(b) 或在 DESIGN R2 显式补「both/L3 模式读取失败 → 误放」分支并论证不可利用。T01 action 暂不擅改（忠实于 DESIGN），待 DESIGN 裁定。

---

**Verdict**: fail

存在 1 条 🔴 Critical（R1：T03 残留 `state_file` @ L125 → AC-3 不可实现 + 任务 action/verify 自相矛盾 + T06 不拦截）。另有 8 条 🟡 Major（R2-R9，覆盖幻影 API、测试低估算、双源漏同步、路径错误、verify 与 done 不对齐、恒真 verify、token 覆盖不足）与 3 条 🟢 Minor。R1 的 AC-3 失败被 R9（T06 token 缺失）放大为「连最终回归都不拦」，必须先修 R1+R9 再切阶段。其余 🟡 虽不单独触发 fail，但主 agent 须对每条给出 `Fixed in:` / `Tech-debt:` / `Not-applicable:` 具体行动，禁止敷衍回应。

---

## L2 盲审（第二轮 · 修复后复核）

- 阶段：3（任务拆解审查 · 3-task）
- change-id：gate-done-authorship
- 复核对象：首轮 R1-R12 修复后的 TASK.md / DESIGN.md
- 独立性声明：未在输入中检测到主 agent 自评 / 草稿 / 概述 / 辩护；以下判断基于重新核验 TASK.md / REQUIREMENT.md / DESIGN.md 及对所引用源码（29-independent-review.sh / independent-review-gate.sh / done-validation.sh / common.sh / test_gate_integrity.bats / Makefile / regression-demos/check.sh）的独立复核。未轻信主 agent 的 Fixed in 声明，逐条重验源码。

### 首轮 R1-R12 复核：全部修复到位

- **R1 🔴 → 已修复**：T03 action step 4 现显式处理 Gate 5（「删 L125 `rm -f "$state_file"`；Gate 5 module_output 并入 Gate 4 或保留日志行移除 state_file 引用」），step 5 改为枚举保留项（l3_review_run / _l3_scan_backlog / module_output），不再笼统「保留其余逻辑不变」。action/verify 矛盾消除。独立核验源码 `29-independent-review.sh` 确认 :125 `rm -f "$state_file"`、:68/:203 赋值、:69-70 裸读四站点存在；T03 step1+step3+step4 删除后，T03 verify（`state_file="` / `.flow-active.independent-review` / `rm -f "$state_file"` 三 token）+ T06 verify（含 `state_file`）双重拦截 → AC-3 state_file 0 匹配可达。Critical 解除。（附注：step4「保留日志行」选项会使 Gate 5 沦为死分支——Gate 4 新 .done 短路已先 exit，建议实现者优先选「并入 Gate 4」选项避免死代码，非阻塞。）
- **R2 🟡 → 已修复**：T01 step 3 改用 `fk_phase_gate_key "$N"`。核验 common.sh:284 确为 case 函数（非数组），注释 :279「不再 declare -A」；`PHASE_GATE_KEY_MAP` 在生产 hooks 仅 correction-types.sh:13 注释残留（非本 change 触碰模块，AC-3 不 grep 此 token，不阻塞）。
- **R3 🟡 → 已修复**：T04 action step 5 新增「6 个 D7 单元测试改写为 run _is_dotdone_write」；`<done>` 计数改「4+6+3=13」；L154「含 write_valid_handshake helper」。核验 test_gate_integrity.bats 确有 4 done-validation（L72/79/88/140）+ 6 D7（L173-198）+ write_valid_handshake helper（L55）= 11 项受影响，T04 现全覆盖。
- **R4 🟡 → 已修复**：T04 `<write_files>` 增列 `flow-kit-bundle/test/test_gate_integrity.bats`；action 增「make test-sync + diff -q」；verify 增 `make test-sync && diff -q ...`。核验 Makefile:47-52 test-sync 确为 `cp test/*.bats flow-kit-bundle/test/`，双源 diff 当前 rc=0，bundle 副本确含 11 处握手引用待同步改写。
- **R5 🟡 → 已修复**：T05 read_files/write_files/verify 路径全改 `flow-kit-bundle/test/regression-demos/`。核验 `flow-kit-bundle/flow-kit/regression-demos/tampered-done` 确不存在（该目录仅 hallucination-guard / scope-drift-guard / strong-model-verbosity / weak-model-interactive-ui / brooks-lint-paths.md），`flow-kit-bundle/test/regression-demos/tampered-done` 确存在。
- **R6 🟡 → 已修复**：T01 verify 增 `grep -q '_is_dotdone_write()' F && grep -q '_gate_is_l2_only()' F`，与 `<done>` 对齐。
- **R7 🟡 → 已修复**：T02 verify 增 `grep -q 'T4 L2_verdict\|fk_extract_l2_verdict\|INDEPENDENT-REVIEW' F` 断言 T4 在位。核验 done-validation.sh:165 确有 `fk_extract_l2_verdict`、:163 确有 `INDEPENDENT-REVIEW`。
- **R8 🟡 → 已修复**：T05 verify 改 `bash test/regression-demos/tampered-done/check.sh && ! grep -rl "..." test/regression-demos/ flow-kit-bundle/test/regression-demos/`——check.sh rc 成为硬断言（无 `| head` 截断、无 `|| echo clean` 兜底、无 `| grep -v` 恒真、作用域正确）。核验 check.sh 确为真断言（exit 0/1 by rc）。且 verify 的 `is_handshake_write` grep 反向强制 check.sh 必须清掉依赖检查（L21 `grep -qE 'is_handshake_write...'`）与调用点（L29）的 `is_handshake_write` 引用，否则 verify 失败——短路口被堵。
- **R9 🟡 → 已修复**：T06 verify grep 改 5 token（`is_handshake_write\|state_file\|written_by=stop-hook-29\|T3.*handshake\|T3b.*SESSION`），与 AC-3 4 token 逐字对齐 + T3b.*SESSION。
- **R10 🟢 → 已修复**：AC 覆盖矩阵 AC-5 行改「T04 + T05（regression-demos）」，验证列补「T05 check.sh rc=0 + grep clean」。
- **R11 🟢 → 已修复**：Wave 2 header 拆分「T04[P] (deps T01,T02,T03) ‖ T05[P] (deps T01)」，与 T05 depends_on=T01 一致。
- **R12 🟢 → 已修复**：DESIGN D3（L77）显式补「both/L3 模式读取失败 → 误放」分支 + 不可利用论证（transition jq 写也需 .flow-active 可读 → agent 自废武功）；R2（L199）镜像。T01 step 3 忠实实现 fail-open。

### 第二轮新发现（修复引入 / 首轮未逮）

### 🟡 RR1 · T4（done-validation L2_verdict 比对）改写后失专属单测覆盖
**Symptom**：T04 action step 1-4 将 4 个 done-validation 测试（AC-1 ②③ forged L74 / ④ hijack L83 / ⑤ tampered L95 / D9 正向 L144）全部「改写为新语义」——新语义为 path-guard（`_is_dotdone_write`/`_gate_path_guard`）拦截，不再调用 `fk_validate_done_marker`。独立核验 bats 全部 `fk_validate_done_marker` 调用点 5 处（L67/74/83/95/144）：改写后仅 L67 ① empty-done（Tier1 空文件 deny）保留。原 ⑤（L95）测的正是 T4 deny（L2_verdict ≠ INDEPENDENT-REVIEW.md → return 2）、原 D9（L144）测 T4 pass——T4 两条路径均失专属单测。T04 step 6（AC-6 集成测试）虽含「绕过写入直接 jq transition → done-validation Gate 4 拦截」，但 action 未指定该集成测试是否构造 L2_verdict 不一致场景来命中 T4——若仅构造格式非法场景，命中的是 Tier 1 而非 T4。
**Source**：固化指令 checklist「覆盖完整性：所有 AC 是否有对应 task」+「verify 可验证性」。DESIGN §2.2「T4 L2_verdict vs INDEPENDENT-REVIEW-N.md 比对（保留 · L2-first gating 调度契约）」+ T02 action step 3「保留 Tier 2 的 T4 比对段」+ done-validation.sh:160 注释「挡威胁⑤-L2 · v1 best-effort 提高成本」。保留的代码须有保留的测试，否则契约无机器保障。
**Consequence**：T4 成「保留代码 + 零专属测试」孤儿——后续 change 误删/误改 T4 比对逻辑（如 `fk_extract_l2_verdict` 调用或 `[[ "$md_v" == "$l2v" ]]` 断言）无人拦截；「L2-first gating 调度契约」退化为纸面声明。DESIGN §5 R4「path-guard 被绕过时无后置作者性兜底」的缓解「Tier 1 仍提供格式校验」不覆盖 T4 的 verdict 交叉校验语义——T4 是唯一能在 path-guard 失守后交叉检测 L2_verdict 伪造的后置层，失测即失守。
**Remedy**：T04 增一条 T4 专属测试（或在 step 6 显式指定 verdict 不一致路径）：构造合法格式 .done（过 Tier 1）但 `L2_verdict=pass` 与 INDEPENDENT-REVIEW-`<N>`.md 的 L2 verdict=fail 不一致 → 断言 `fk_validate_done_marker <done> <phase> <cid> transition` return 2（命中 T4 deny）；再构造一致场景断言 return 0（T4 pass）。before: step1-4 全改 path-guard、T4 deny/pass 无测；after: 增 T4 deny/pass 两条单测或 step6 显式覆盖 verdict 不一致路径。

### 🟢 RR2 · T05 action 散文残留不存在路径 `flow-kit-bundle/flow-kit/test/`
**Symptom**：TASK.md T05 action L177「双源测试同步（test/ + flow-kit-bundle/flow-kit/test/ 或 regression-demos/ 两处保持一致）」。独立核验 `flow-kit-bundle/flow-kit/test/` 不存在（flow-kit-bundle/flow-kit/ 下仅 prompts/ / reference/ / regression-demos/ / templates/ + md 文件，无 test/）。T05 的 read_files/write_files/verify 已用正确路径 `flow-kit-bundle/test/regression-demos/`（R5 修复），但散文仍引用幻影路径。
**Source**：固化指令 checklist「read_files/write_files 约束是否到位」——散文与文件清单不一致，实现者若按散文找同步目标会扑空。
**Consequence**：轻微——文件清单/verify 是权威，散文误导但不阻塞；R5 首轮同类路径错误的残留尾巴。
**Remedy**：L177 散文改「双源测试同步（test/regression-demos/ 开发源 + flow-kit-bundle/test/regression-demos/ 打包源）」。before: `flow-kit-bundle/flow-kit/test/`; after: `flow-kit-bundle/test/regression-demos/`。

### 🟢 RR3 · T01 step 3 注记「R12 待 DESIGN 裁定」与 DESIGN 已裁定矛盾
**Symptom**：TASK.md T01 action step 3「读取失败（...）→ fail-open 放行（D3 决策，R12 待 DESIGN 裁定是否收紧）」。但 DESIGN D3（L77）已裁定：显式补 both/L3 误放分支 + 不可利用论证，选择维持 fail-open（R12 落地选项 b）。「待 DESIGN 裁定」是首轮未裁定时的遗留措辞，与现已裁定的 DESIGN 矛盾。
**Source**：固化指令「不主动假设作者意图」+ 文档一致性。TASK 与 DESIGN 须对决策状态一致。
**Consequence**：轻微——T01 忠实实现 D3 fail-open（行为正确），仅措辞陈旧误导实现者以为决策待定、可能擅自收紧（偏离 DESIGN）。
**Remedy**：step 3 注记改「（D3 决策 · DESIGN 已裁定维持 fail-open，both/L3 误放为理论不可利用缺口，见 DESIGN §1 D3 / §5 R2）」。before: `R12 待 DESIGN 裁定是否收紧`; after: `D3 已裁定维持 fail-open`。

### 🟢 RR4 · [跨阶段] AC-3 的 `T3.*handshake`（英文）token 对中文注释 inert
**Symptom**：AC-3（REQUIREMENT.md:37）验证方式 grep `T3.*handshake`（英文），T06 verify 忠实复用此 token。但生产注释用中文「握手」（done-validation.sh:140「T3 D7 握手锚点」、29-independent-review.sh:6「握手文件」）——`T3.*handshake` 在生产代码 0 匹配（inert token）。同理 `written_by=stop-hook-29`（KVP 字面）在生产 hooks 亦 0 匹配（done-validation.sh:146 是 `== "stop-hook-29"`，bats/check.sh 用 JSON `"written_by":"stop-hook-29"`，均非 KVP `=` 形态）。AC-3 实际 4 token 中仅 `is_handshake_write` 与 `state_file` 命中生产代码。
**Source**：AC-3 验证方式 token 设计（REQUIREMENT 层）。T06 忠实实现 AC-3，但 AC-3 自身 token 覆盖弱于其字面 4-token 承诺。
**Consequence**：轻微 + 跨阶段——AC-3「握手死代码全部清理」验证实靠 T02 verify（中文 `T3 D7 握手` token）+ T06（英文 token inert）双重，而非 AC-3 单独成立。若 T02 verify 被弱化，T06 的 inert token 兜不住中文注释残留。属 REQUIREMENT 层 token 选择问题，非 TASK 缺陷。
**Remedy**：路由给 REQUIREMENT（下一轮 1-requirement 复核）：AC-3 的 `T3.*handshake` 改 `T3.*握手\|T3.*handshake`（中英双覆盖）；`written_by=stop-hook-29` 改 `stop-hook-29`（覆盖 KVP 与 JSON 两种引用形态）。T06 不擅改（须忠实 AC-3）。

---

**Verdict**: pass

首轮 R1 🔴 Critical（T03 残留 `state_file` @ L125 → AC-3 不可实现 + action/verify 自相矛盾）已修复——T03 action step 4 显式处理 Gate 5、删 L125，step 5 枚举保留项，action/verify 矛盾消除，AC-3 可达。R2-R9 🟡 与 R10-R12 🟢 共 11 条全部修复到位（经独立重新核验源码与 TASK.md，未轻信 Fixed in 声明）。第二轮新发现 1 🟡（RR1：T4 失专属单测）+ 3 🟢（RR2 路径散文 / RR3 措辞陈旧 / RR4 AC-3 token inert），无 🔴。RR1 须在切阶段前由主 agent 给出 `Fixed in:`（增 T4 deny/pass 单测或显式覆盖 step6 verdict 不一致路径）或 `Tech-debt:`；RR2-RR4 为可选改进 / 跨阶段路由。无 Critical 阻塞，本轮 pass。

---


---

## L3 重审（deepseek-v4-flash[1m] 外部模型 · 2026-07-25 15:20）

> 自动生成于 2026-07-25 15:20。由 l3-review.sh 写入。

### 审查结论

```json
{"critical":[],"major":[{"file":"T04 write_files","issue":"未声明 flow-kit-bundle/test/test_gate_integrity.bats 的写权限","why":"T04 action 要求通过 make test-sync 将 test/test_gate_integrity.bats 同步到 flow-kit-bundle/test/test_gate_integrity.bats，但 write_files 中仅列出 test/test_gate_integrity.bats，未包含目标文件。这导致实际修改范围超出声明边界，违反边界清晰要求和禁动清单遵守声明。","fix":"在 T04 的 write_files 中明确加入 flow-kit-bundle/test/test_gate_integrity.bats，或在注释中说明该文件通过同步命令间接写入；同时确保 make test-sync 不会触及未声明的其他文件。"}],"minor":[{"file":"T04 verify","issue":"verify 未校验测试数量为 16，无法保证全部预期测试用例被执行","why":"verify 仅执行 npx bats test/test_gate_integrity.bats，但若部分测试因 skip 跳过，bats 仍返回 exit 0，可能误通过。done 条件明确要求“16 个测试全绿”，但 verify 无法证明数量完整性。","fix":"在 verify 中添加测试计数断言，例如通过 grep 输出中 'N tests' 行，或使用 bats --count 参数，确保实际运行数等于 16。"}],"verdict":"pass","summary":"任务拆解覆盖了 AC 矩阵中全部 7 项，依赖图无环，各 task verify 基本可执行且能证伪，write_files 边界整体清晰。存在一个 major 问题：T04 的 write_files 未声明同步写入的目标文件，导致边界越界；另有一个 minor 问题：T04 verify 无法确保测试数量完整性。综上，无 critical 问题，判定为通过。"}
```

L3_artifact_hash: 0a2844f2670cf1d4015c88ff054d935d16ac8d6e034012b24529e6ba1bf1b7b1
