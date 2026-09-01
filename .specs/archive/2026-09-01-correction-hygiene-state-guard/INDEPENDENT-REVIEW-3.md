# 独立审查 · 阶段 3

## L2 盲审（phase 3 · task）

审查对象：`.specs/correction-hygiene-state-guard/TASK.md`（4 tasks / 3 waves），对照 REQUIREMENT.md（10 AC）、DESIGN.md（D1-D8）、ADR-024、CONTEXT.md 禁动清单，并对源码逐条核实（correction-file.sh / 33号 / 29号 / test/ / Makefile / bats 路径）。

**核实通过项（非发现）**：
- 33 号 9 种 check 名与 T01 白名单、ADR-024 白名单逐字一致（corrupt_json / change_id_dangling / change_id_null_with_dirs / phase_artifact_missing / pipeline_phase_artifact_missing / pipeline_gate_not_passed / pipeline_gate_phase_mismatch / stale_updated_at / token_spent_unmaintained；源码 L26/68/79/116/146/163/178/200/219）。
- T01 "不改 4 函数签名" 属实：correction-file.sh 现有 exists/read/write/clear 四个函数（L16/25/47/83），T01 仅新增 helper。
- T03 引用锚点属实：29 号 `_write_l2_missing_correction` L24-30（`jq -n > file` 整文件覆写，确会摧毁 compliance）、Gate 3 `fk_independent_review_gate_active L3` early-exit L47-50、`## L2 盲审` grep 串存在（L69/L189）；T03 引 correction-file.sh:116-123 合规优先范式实际在 L115-119（jq 条件 L117），锚点可接受。
- T02 引用锚点属实：33 号入口 jq empty L25、`_fai_append_violation` L249-288、merge 标签逻辑 L267-274。
- CHANGE.md L41-42 已登记例外：29 号（jq 失败分支 + l2-missing 退场）、33 号（"有关修改"理由 + cleanup-debt-batch 先例格式）。write_files 全部 ⊆ DESIGN 0.5.1 触碰清单，与 CONTEXT 禁动清单零未登记重叠。
- 测试/工具基座：test_correction_file.bats / test_stop_chain.bats / test_independent_review_model.bats 存在；bats 二进制 `~/.npm/_npx/cd2c4d46c11457b7/node_modules/bats/bin/bats` 存在；Makefile test-sync target 存在（L47）；test/ 存在 BATS_ROOT 向上查找范式（test_severity_format.bats L6-8）。
- AC→task 映射：AC-1/2（T01+T02+T04）、AC-3（T02+T04）、AC-4 含 R1/R2（T03+T04）、AC-5/6（T02+T04）、AC-9（T04）、AC-10（T01+T02+T04）无孤儿；D1-D8 全部有 task 动作（D7 为设计期动作已核实）。波次图无环：T01/T03[P] → T02(dep T01) → T04(dep T01+T02+T03)；T02 依赖 T01 正确（33 号 source correction-file.sh）；T03 与 T01 并行安全（仅读 correction-file.sh 既有模式，无写冲突）。任务粒度均 ≤200 行。

### 🟡 R1 · T04 verify 管道吃 exit code（TD-012 假绿教训复发）：全量回归 leg 无法判定失败

**Severity**：🟡 Important
**Symptom（症状）**：TASK.md:107 T04 verify 末段 `~/.npm/_npx/.../bats test/ 2>&1 | tail -3`——管道退出码取最后命令 `tail`（恒 0），未设 pipefail 时 bats 失败被吞。
**Source（源头）**：CONTEXT.md TD-012 明文记录同款反模式及其后果与修复：「health-fix-2026-07-08 的 '169→0' 验证疑用 `bats|tail`（管道吃 exit code）误判全绿」；「修 Makefile test target 管道 exit code 漏洞（`bats|tail`→bats 直接判 exit）」。
**Consequence（后果）**：AC-8「全量回归 0 fail」的 verify 判定失效——基线回归失败仍可能显示通过，T04 done 断言「全量 752+ 基线 0 fail」不可证，重现仓库已修复过的假绿模式。
**Remedy（修补）**：去掉管道（verify 直接 `bats test/`），或前置 `set -o pipefail`；与 Makefile test target 既有 TD-012 修复对齐。before：`bats test/ 2>&1 | tail -3`；after：`bats test/`（如需 tail 精简输出，改 `bats test/ 2>&1 | tail -3; exit ${PIPESTATUS[0]}` 或 `set -o pipefail` 前缀）。

### 🟢 R2 · T03 动作缺 29 号 L38 jq 失败分支「yield 改造」项：touch 清单与 TASK 动作不一致

**Severity**：🟢 Minor
**Symptom（症状）**：TASK.md:72-77 T03 action 仅列两处改造（退场检测块 + `_write_l2_missing_correction` 写入函数体）；未覆盖 DESIGN 0.5.1 触碰清单中的 29 号 L38 `jq empty || exit 0` 分支。
**Source（源头）**：DESIGN.md:19（0.5.1「_write_l2_missing_correction L24-30 + L38 jq empty || exit 0」）、CHANGE.md:41（例外登记「允许修改 jq 失败分支（L36-40 yield 改造）」）、REQUIREMENT.md:84（v1「29 号：jq 失败 yield 改造（静默退出，不写 correction）」）。
**Consequence（后果）**：功能无影响（L38 现行为已静默且不写 correction，符合 AC-5 And），但 7-integration 按 DESIGN 清单对账 diff 时出现「DESIGN 列出但未改」的误报；若作者本意是加注释显式化，执行者会漏做。
**Remedy（修补）**：T03 action 补一行「确认 L38 jq empty || exit 0 静默语义保持，加注释显式化 yield 行为」；或将 DESIGN 0.5.1/CHANGE.md 中该 touch 点移除，两处取其一保持一致。

### 🟢 R3 · DESIGN §9.1「去重/剥离 helper」共享抽象未落地：剥离逻辑将 33/29 双份内联

**Severity**：🟢 Minor
**Symptom（症状）**：TASK.md:24-29 T01 仅新增 dedupe/trim 两函数；TASK.md:52（T02 外来清空 ②）与 TASK.md:74（T03 退场）各自内联实现 type 合并标签剥离语义。
**Source（源头）**：DESIGN.md:132（§9.1「新增可复用抽象：correction-file.sh 新增去重/剥离 helper——≥2 使用场景：33 号去重 + 29 号剥离」）。
**Consequence（后果）**：同一剥离语义在 33/29 两文件重复实现（R3 知识重复），未来合并标签规则演进需双点维护，与 DESIGN 声明的共享抽象偏离。
**Remedy（修补）**：T01 增加第三个共享函数（如 `correction_file_strip_type file`）供 T02/T03 复用；或在 T03 动作中显式声明引用 T02 已落地的剥离实现（避免第二份）。

### 🟢 R4 · T01 函数命名/签名偏离 DESIGN §9.2：架构沉淀对不上

**Severity**：🟢 Minor
**Symptom（症状）**：TASK.md:27 `correction_file_trim(file, max)` vs DESIGN.md:138 `correction_file_trim_state_integrity(correction_file)`；DESIGN 将白名单作函数参数，TASK 改作模块级 readonly 常量 `CORRECTION_STATE_INTEGRITY_CHECKS`。
**Source（源头）**：DESIGN.md:138（§9.2 抽象段签名）。
**Consequence（后果）**：功能等价（白名单内嵌常量同样达成作用域界定，常量命名符合 CONTEXT 命名约定），但 A-evolve 按 §9.2 同步架构沉淀时签名对不上，需人工消歧。
**Remedy（修补）**：T01 action 首行注明对 DESIGN §9.2 的命名/参数偏离及理由（内嵌常量 vs 传参），供 A-evolve 采纳实现而非字面签名。

### 🟢 R5 · AC-7（绝不触碰外来文件）无显式 action/verify 映射：缺回归防护

**Severity**：🟢 Minor
**Symptom（症状）**：TASK.md:52 T02 action ③ 仅写 correction 侧动作；无任何 task verify 断言「外来 .flow-active 文件 mtime/内容不变」（AC-7 Then）。
**Source（源头）**：REQUIREMENT.md:58（AC-7 Given/When/Then）。
**Consequence（后果）**：AC-7 依赖实现隐式成立（33 号只写 correction 自然不碰 .flow-active），但无测试拦截——未来改动若意外写外来文件不会被发现，AC-7 成为无回归保护的软约束。
**Remedy（修补）**：T04 AC-5/6 用例追加一行断言：记录 YAML fixture 的 mtime/内容，33 号跑完后 `diff`/mtime 比对不变。

### 🟢 R6 · AC-8「make check 四门」未完整纳入 T04 verify：验收依赖 integration 补跑

**Severity**：🟢 Minor
**Symptom（症状）**：TASK.md:107 T04 verify 仅 test-sync + 两个 bats 命令；AC-8 Then 要求「make check 四门（test/lint/check-validate/check-test-sync）通过」。
**Source（源头）**：REQUIREMENT.md:64（AC-8）。
**Consequence（后果）**：lint/validate 门未在 T04 verify 内覆盖（T01/T02/T03 verify 已各自含 shellcheck，test-sync 覆盖 check-test-sync，故实际风险低），但 AC-8 的完整四门验收在 task 层缺位，留待 integration。
**Remedy（修补）**：T04 verify 追加 `make check`；或在 T04 done 段注明「AC-8 四门中 lint/validate 由各 task verify + integration 补跑，task 层覆盖 test+双源同步」。

**Verdict**: pass

---

## 主 agent 响应（fix loop · 2026-09-01）

| 发现 | 严重度 | 处置 | 状态 |
|---|---|---|---|
| R1 T04 verify 管道吃 exit code（TD-012 复发） | 🟡 | 采纳全量：verify 末段去管道，改为 `bats test_correction_hygiene.bats && make check`（四门含全量 test，exit code 直判） | Fixed |
| R2 T03 缺 L38 yield 改造项 | 🟢 | 采纳 remedy A：T03 补第 3 条「L38 行为保持不变 + 注释显式化 yield 归属（33 号单一 actor）」，消除对账歧义 | Fixed |
| R3 剥离逻辑双份内联 | 🟢 | 采纳 remedy A：T01 新增第三个共享函数 `correction_file_strip_type(file, segment)`，T02 外来清空（剥 state-integrity 段）与 T03 退场（剥 l2-missing 段）均改引用，禁双份内联 | Fixed |
| R4 T01 命名偏离 DESIGN §9.2 | 🟢 | 采纳反向对齐：DESIGN §9.2 签名勘定为 `correction_file_dedupe(correction_file)` / `correction_file_trim(correction_file, max)` / `correction_file_strip_type(correction_file, segment)` + 白名单改模块级 readonly 常量 `CORRECTION_STATE_INTEGRITY_CHECKS`（理由：ADR-024 契约固定白名单，参数化会允许调用方削弱界定——常量单一源优于参数注入） | Fixed（DESIGN 侧勘定） |
| R5 AC-7 无 verify 映射 | 🟢 | 采纳：T04 补 AC-7 用例——外来 .flow-active（YAML）跑 33 号前后 sha256 + mtime 逐字节不变断言 | Fixed |
| R6 AC-8 四门未入 T04 verify | 🟢 | 采纳：T04 verify 末段 `make check`（test/lint/打包校验/双源 diff 四门一次跑齐，与 R1 修复合并落地） | Fixed |

**修代码优先声明**：6 项全部为 TASK/DESIGN 文档层修复（阶段 3 产物 = 任务清单；实现属阶段 4）。R1 直接触发 verify 语义变化，T04 执行时以 `make check` 退出码为唯一判定。

---

## 主 agent 响应（复核轮 2 · 2026-09-01）

| 发现 | 严重度 | 处置 | 状态 |
|---|---|---|---|
| N1 Makefile:44 check-validate 管道假绿（TD-012 复发） | 🟡 | **范围扩展采纳**：主 agent 已直接落地修复（check-validate 补权威直判行，对齐 test target 双行模式，exit 1 生效）；TASK T04 write_files += Makefile + action 补核验项；DESIGN 0.5.1 触碰清单同步登记。核实说明：`test` target L10 管道非缺陷（L11 权威直判行兜底，双行模式合法）；`check-validate` 仅单行缺直判，为真缺陷 | Fixed（已落地） |
| N2 T03 头注「两处改造」+ 编号 1,3,2 乱序 | 🟢 | T03 头注改「三处改造（D4/D8 + AC-4 + 盲审 R2/N2）」，编号重排 1 退场检测 / 2 L38 yield 显式化 / 3 写入保护 | Fixed |
| N3 strip_type 纯 type 边界语义未定义 | 🟢 | T01 边界契约补全：纯 type（无 `+` 连接符）时 no-op 返回非零——剥离仅对合并标签有意义，纯 type 场景由调用方走各自分支（退场→rm / 外来→保留） | Fixed |

**范围扩展声明（R7.1）**：Makefile 原不在 DESIGN 0.5.1 触碰清单——本次因 N1 属 AC-8 验收四门之一（check-validate 不可信 = AC-8 门禁失效），按最小扩展纳入（1 行修复 + 注释），TASK/DESIGN 双向登记，7-integration diff 对账已含。

---

## L2 复核（第 2 轮）

fix loop 复核：6 项修复逐一验证（R1 TASK.md:110、R2 TASK.md:76、R3 TASK.md:28/53/75、R4 DESIGN.md:138、R5 TASK.md:106、R6 TASK.md:108/110、响应表 INDEPENDENT-REVIEW-3.md L66-79）——**6 项全部落地**。复核确认 3 项新问题（1 🟡 + 2 🟢）。

### 🟡 N1 · R1 修复把 T04 终门路由到 `make check`，但 check-validate leg 仍用 `| tail -5` 吞 exit code：四门中一门假绿

**Severity**：🟡 Important
**Symptom（症状）**：TASK.md:110 T04 verify 末段 `&& make check`；Makefile:44 `check-validate` recipe `@bash package-flow-kit.sh --validate 2>&1 | tail -5` 为单管道行——POSIX sh（make 默认 /bin/sh）无 pipefail 时该行退出码 = tail（恒 0）。
**Source（源头）**：CONTEXT.md TD-012（同款 `cmd|tail` 吃 exit code 假绿教训）；Makefile:10-11 显示 `test` target 已用「装饰管道 + 权威直判」双行修复（TD-012 fix），L44 未同步——R1 响应「make check 四门 exit code 直判」对 4 门中仅 3 门成立。
**Consequence（后果）**：打包校验 leg 永远 exit 0——本 change 恰新增 `flow-kit-bundle/test/test_correction_hygiene.bats`（属 --validate 覆盖范围），若 package-flow-kit.sh cp 清单漏配该测试文件，AC-8「make check 四门通过」仍假绿，且 T04 done「全量 0 fail」不可证。
**Remedy（修补）**：对齐 test target 双行模式——L44 改 `bash package-flow-kit.sh --validate 2>&1 | tail -5; bash package-flow-kit.sh --validate >/dev/null 2>&1 && echo "✅ validate: ok" || { echo "❌ validate: failed"; exit 1; }`；或 recipe 前置 `set -o pipefail`。before/after 见 Makefile:10-11 既有范式。

### 🟢 N2 · R2 修复引入 T03 内部计数/编号不一致：「两处改造」头注 vs 三项动作（1,3,2 乱序）

**Severity**：🟢 Minor
**Symptom（症状）**：TASK.md:74 头注仍「两处改造（D4/D8 + AC-4）」；动作项 L75/76/77 编号为 1、3、2（乱序）；L78 改动范围注「退场检测块（新增）+ 写入函数体（改造）」遗漏第 3 项（L38 显式化）。
**Source（源头）**：TASK.md:74/76/78（R2 修复补了动作项但未同步头注与范围注）。
**Consequence（后果）**：执行者按「两处改造」+ 范围注判断，会疑 L38 注释改动是否越界——正是 R2 要消除的「touch 清单 vs 动作」对账歧义在 TASK 内部重现；7-integration 按范围注对账 diff 仍可能误报。
**Remedy（修补）**：重编号 1/2/3，头注改「三处改造（D4/D8/AC-4 + L38 yield 显式化）」，L78 范围注补 L38 分支。

### 🟢 N3 · strip_type 纯类型边界语义未定义：type 无 `+` 且等于 segment 时行为悬空

**Severity**：🟢 Minor
**Symptom（症状）**：TASK.md:28 仅定义「segment 不存在时 no-op」，未定义「type 为纯类型且 == segment」（如 strip_type file "state-integrity" 于纯 type "state-integrity"）——naive `split("+") | map(select(. != $segment)) | join("+")` 产出空串。
**Source（源头）**：TASK.md:28；DESIGN.md:132（§9.1「未来可复用」声明）。
**Consequence（后果）**：两个当前调用方（T02 ② / T03 ①）均以「type 为合并标签时」守卫，今日本不可达；但共享函数契约有洞——未来第三方调用方（DESIGN §9.1 复用意图）在纯类型上误调会产出空 type / 空文件。
**Remedy（修补）**：T01 spec 补一句「type 不含 `+` 时整体 no-op（纯类型不剥离，返回原文件）」；T04 补一用例：纯 state-integrity 跑 strip_type state-integrity → type 与 violations 逐字节不变。

**复核确认（非发现）**：
- **strip_type ↔ foreign_state note 去重交互安全**：① 清空白名单 violation（foreign_state 不在 9 白名单，存活）→ ② type 级剥离 → ③ 追加 note（check=foreign_state 存在性去重），三层作用域正交无竞态；`compliance+state-integrity`（33 号 merge L268-269 对既有 compliance 可产出）剥离后为 `compliance`，符合 AC-10；`l2-missing+state-integrity` 在 T02 外来路径剥为 `l2-missing`、在 T03 退场路径剥为 `state-integrity`，与 DESIGN 2.2 状态机一致。
- **R4 与 ADR-024 无矛盾**：ADR-024 将 9 check 白名单固定为作用域契约，模块级 readonly 常量单一源（`CORRECTION_STATE_INTEGRITY_CHECKS`）比参数注入更贴合契约——参数化允许调用方传入削弱后的白名单，反而削弱 ADR-024 界定；DESIGN.md:138 已注明理由。
- **全仓无旧签名残留**：`trim_state_integrity` / `type_whitelist` 零活引用（仅 review 历史记录提及），TASK 与 DESIGN §9.2 三函数签名逐字对齐。
- **make check 其余三门 exit code 正确**：test（L11 权威直判）、lint（L37 exit 1）、check-test-sync（L60 `|| exit 1`）。

**Verdict**: pass

---

## L2 复核（第 3 轮）

fix loop 终轮：N1/N2/N3 三项处置逐一验证（TASK.md、Makefile、DESIGN.md 0.5.1、INDEPENDENT-REVIEW-3.md 响应表）——**3 项全部落地**，未引入新问题。

| 发现 | 严重度 | 处置 | 状态 |
|---|---|---|---|
| N1 Makefile check-validate 管道假绿 | 🟡 | Makefile:42-46 双行模式（L45 装饰管道 + L46 权威直判 `... && echo "✅ validate: staging coverage OK" || { echo "❌ validate: coverage check failed"; exit 1; }`）；TASK.md T04 write_files += Makefile（L96）+ action item 0 核验/补齐双保险（L99）；DESIGN.md 0.5.1 触碰清单登记（L25-26 N1 范围扩展）；响应表含 R7.1 范围扩展声明 | Fixed（已落地） |
| N2 T03 头注/编号不一致 | 🟢 | TASK.md:74 头注「三处改造（D4/D8 + AC-4 + 盲审 R2/N2）」；L75/L76/L77 编号 1 退场检测 → 2 L38 yield → 3 写入保护，顺序恢复 | Fixed |
| N3 strip_type 纯 type 边界 | 🟢 | TASK.md:28 边界契约：纯 type（无 `+`）时 no-op 返回非零，纯 type 场景由调用方走各自分支（退场→rm / 外来→保留），共享函数不做隐式变更 | Fixed |

**实证复核（独立执行，非采信声明）**：
- 构造 `flow-kit-bundle/zzz-uncovered/stray.bats` → `make check-validate` 输出「🔴 漏配 (ERROR): 1」+ 权威行「❌ validate: coverage check failed」→ **make RC=2**（非零阻断生效，TD-012 修复真实落地）；清理后 clean tree → RC=0「✅ validate: staging coverage OK」。
- 注：初测空目录 `mkdir -p zzz-uncovered` 未触发（validate 按**文件**计数，301 项中空目录零贡献），为主 agent 所述「stray dir」方法的正确形态应含文件——不构成缺陷，仅记录测试方法边界。

**终轮确认（非发现）**：
- **任务数/波次无漂移**：仍 4 任务（T01-T04）；Wave 1 T01[P]+T03[P] / Wave 2 T02(dep T01) / Wave 3 T04(dep T01+T02+T03)（TASK.md:6-10）。
- **范围收敛**：round 3 增量仅 T03 头注/编号（L74-77）、T01 边界契约（L28）、T04 write_files+action item 0（L96/L99）、Makefile L42-46、DESIGN 0.5.1 L25-26——全部为 N1/N2/N3 直接对应，无其他文件漂移；Makefile 不在 CONTEXT 禁动清单，R7.1 范围扩展声明已登记，7-integration 对账口径一致。
- **边界契约自洽**：segment 不存在（合并标签内）→ no-op 返回 0；纯 type → no-op 返回非零（信号「不可用」）；两调用方仅合并标签时调用，非零分支今日不可达，契约闭合无歧义。

**Verdict**: pass
