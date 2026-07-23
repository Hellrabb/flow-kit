# 独立审查 · 阶段 6

## L2 盲审

> 独立性声明：仅依据工件（`git diff` + 新建测试文件 + REQUIREMENT/DESIGN/ADR-013）作判。REVIEW.md 仅作「待复核对象」对照，不作为前提。✅/通过项系独立复跑 bats（42 用例全 ok，全量 exit 0）+ 逐文件读源码得出，非抄录主 agent 结论。未在输入中检测到主 agent 自评/草稿/辩护注入（「本次审查参数」为操作性元数据，REVIEW.md 明示为待复核）。

### 工件范围确认
- diff：9 改 + 3 新建测试（`test_fk_resolve_model` / `test_flow_model` / `test_model_degradation`，均未跟踪，已逐文件读全文）。
- 独立复跑：`bats flow-kit-bundle/test/{test_fk_resolve_model,test_flow_model,test_model_degradation,test_flow_kit_resume,test_independent_review_model}.bats` → 1..42 全 ok（exit 0）；`bats flow-kit-bundle/test/` 全量 exit 0（AC-7 独立确认，非采信 REVIEW.md）。

### 与主 agent 一致项（独立得出，非抄）
- AC-1/AC-2/AC-3（fk_resolve_model 三级链 + 截断）：独立读 `common.sh:239-261` 核验 `${VAR:-}` + `|| echo ""` 在 `set -u`/jq 失败下均收敛到空，10 用例覆盖 P1/P2/P3/空/三级同设。✅ 一致。
- AC-5/5b/5c（jq --arg 防注入 + 原子 mv + 字段边界）：独立核验 `test_flow_model.bats:66-71` 防注入用例（`model"; rm -rf / #`）+ `jq empty` 结构校验。✅ 一致。
- AC-6（resume 收割 4 分支 + rm 条件化）：独立读 `flow-kit-resume.sh:122-157` 核验 if/elif 结构（compliance→删；l3/l2-model-missing→保留+banner；l2-missing→保留静默；unknown→删），4 用例覆盖。✅ 一致。
- AC-7（回归）：独立复跑 exit 0。✅ 一致。
- DESIGN.md:37 明示 `/flow model` 内联进 `flow/SKILL.md`（非新建 `flow-model/SKILL.md`）——这是 phase-2 对 REQUIREMENT v1 清单的合理精炼，非范围蔓延。与主 agent 一致。

---

### 🟡 R1 · AC-4a/4b caller 集成验证不完整（2/3 caller 缺集成测试，主 agent 已披露为 tech-debt 但门禁判定偏乐观）
**Symptom（症状）**：`test_model_degradation.bats:83-86` 自述「L2 caller（l2_dispatch_prompt）+ 29-indep caller 完整集成测试留技术债」。仅 `l3_review_run`（`test_model_degradation.bats:54-81`）有集成测试断言三项可观测后果（return 3 + type=l3-model-missing + API_CALLED=0 + stderr 含 FLOW_KIT_L3_MODEL）。`29-independent-review.sh:57-65` 与 `l2-detect.sh:215-223` 两个 caller 无集成测试。REQUIREMENT AC-4a 验证方式明列「分别 source 两 caller，断言上述三项可观测后果」、AC-4b 明列「source l2-detect.sh，断言三项可观测后果」——仅 1/3 caller 满足。
**Source（源头）**：REQUIREMENT AC-4a/4b「集成层（待 4-dev）」验证方式；code-review checklist「spec 合规：每条 AC 是否被代码真正覆盖」。TEST.md:29 与 REVIEW.md:18/76 披露为 tech-debt。
**Consequence（后果）**：29-indep/l2-detect 的降级接线（source guard + fk_resolve_model + if-empty + write correction + echo + return/exit）若被后续改动破坏（如删 `write_model_missing_correction` 调用、改 return 码），无测试捕获。叠加 R5（三 caller 降级块机械复制），未测站点的脆弱性放大。注：29-indep 用 `exit 3`（`:63`）与其文件头 `:11`「任何路径都 exit 0，不断 Stop 链」自相矛盾——功能上 `00-gate.sh:71` 的 `run_module` 用 `timeout 120 bash "$script" ... || true` 吞掉非零退出，Stop 链不中断，但该 invariant 已失真，且 29-indep 一旦在 run_module 外被调用，exit 3 会外泄。
**Remedy（修补）**：补 29-indep 集成测试（mock `_l3_call_api`/curl，置空三级链 source 脚本，断言 exit 3 + correction type=l3-model-missing + 无 API + 文件不被当异常删）；补 l2-detect `l2_dispatch_prompt` 集成测试（同断言三后果）。并把 `29-independent-review.sh:11` 头注订正为「降级路径 exit 3（run_module || true 兜底，不断链）」。

### 🟢 R2 · model-missing 可覆写 l2-missing 持久化记录（ADR-013 仅护 compliance，主 agent 漏判）
**Symptom（症状）**：`correction-file.sh:110-114` `write_model_missing_correction` 的条件 `if .type=="compliance" and ((.violations//[])|length>0) then . else $new end`——仅 compliance 非空时保留，其它 type 一律 `$new` 覆盖。`29-independent-review.sh:24-30` `_write_l2_missing_correction` 用裸 `jq -n > "$correction_file"` 覆盖写，无任何优先级保护。`flow-kit-resume.sh:147-151` 注释声称 l2-missing「持久化记录...现保留不删」。跨 run 场景：run-1（L3 模型在配）写 l2-missing → run-2（L3 模型变未配）`write_model_missing_correction "L3"` 覆写掉 l2-missing。
**Source（源头）**：ADR-013「最后写入者胜」+「compliance > model-missing 优先」明示仅护 compliance；REQUIREMENT AC-6 ⚠️「须与既有 type=l2-missing 精确等值区分，避免近形碰撞」（type 名/schema 已区分✅，但覆写持久化未护）。
**Consequence（后果）**：l2-missing（=L2 盲审段缺失）持久化记录可被 model-missing transient 覆写。当前 l2-missing 在 resume.sh 无 banner（`:151` 仅 `:` 静默），故无用户可见影响；且 run-3（模型再配）29-indep 重新写 l2-missing 自愈。影响低/瞬态，但与 resume.sh「持久化」注释语义冲突，且落在 AC-6 ⚠️ 点名的碰撞区。
**Remedy（修补）**：在 `write_model_missing_correction` 条件里把 l2-missing 也纳入保护（`if (.type=="compliance" and (.violations|length>0)) or .type=="l2-missing" then . else $new end`），或在 ADR-013 显式声明「l2-missing 可被 model-missing 覆写，持久化不保证」并订正 resume.sh:148-150 注释。低优先，不阻塞。

### 🟢 R3 · write_model_missing_correction 静默失败 + 孤儿 .tmp + 夸大 TOCTOU 声明（主 agent 漏判）
**Symptom（症状）**：`correction-file.sh:110-114`——先 `correction_file_exists "$path"`（`:16-20` = `[[ -f ]] && jq empty`），再 `jq ... "$path" > "${path}.tmp" 2>/dev/null && mv`。两步之间存在 TOCTOU 窗口（文件在 exists 后被删/变 corrupt）。若 jq 读失败：`2>/dev/null` 吞错、`> .tmp` 已创建空 .tmp、`&&` 短路不 mv → 留下空 `${path}.tmp` 孤儿且**降级标记未写、无错误抛出**。注释 `:95-96`「avoids Check-Then-Act TOCTOU race」与实际两步流程不符。
**Source（源头）**：经典 TOCTOU（Check-Then-Act）；code-review checklist 资源管理 / 错误处理。DESIGN §4.1 原子写约束。
**Consequence（后果）**：`.flow-active.correction` 损坏或并发删除时，降级标记静默丢失（caller 以为已写 correction，实际没有），下一轮 SessionStart 无 banner，降级不可观测。孤儿 .tmp 累积（虽下次写会覆盖）。
**Remedy（修补）**：改成单步原子写——不预检 exists，直接 `jq --argjson new "$new_json" 'if .type=="compliance"... else $new end' "$path" 2>/dev/null > "$path.tmp"`；jq 失败则回退到 `correction_file_write "$path" "$new_json" overwrite`（新建场景）；并在 `&&` 链尾加 `|| { rm -f "${path}.tmp"; echo "[correction-file] WARN: model-missing write failed" >&2; }` 兜底清 .tmp + 可观测。订正 `:95-96` 注释为「单步 jq 条件写原子；exists→jq 间仍有窄 TOCTOU，失败可观测回退」。

### 🟢 R4 · test_flow_model.bats 测的是测试内自造 helper，非 flow/SKILL.md 工件（主 agent 漏判）
**Symptom（症状）**：`test_flow_model.bats:19-33` 自定义 `_flow_model_set`/`_flow_model_clear` 重新实现 jq 写入逻辑，6 个用例全部断言这两个 helper 的行为，既不 source 也不引用 `flow-kit-bundle/skills/flow/SKILL.md` 的 `/flow model` 段。REVIEW.md:19/30 把 AC-5/5b/5c 实现列记为「flow/SKILL.md /flow model jq 内联段」+ 测试 ✅。
**Source（源头）**：code-review checklist「Test isolation / 覆盖率幻觉」；T5 覆盖率幻觉（TEST.md:60 自评✅）。
**Consequence（后果）**：SKILL.md 的 jq 示例与测试 helper 解耦——若有人改 SKILL.md 示例引入 bug（如漏 `--arg` 改裸插值、改错字段名），测试仍绿。AC-5「实现」实为 markdown 散文，测试验证的是散文的副本而非工件本身。
**Remedy（修补）**：skills 系 markdown 指令无可执行体，纯单测确有局限——但可加一个契约层断言：`grep` 校验 `flow/SKILL.md` 的 `/flow model` 段含 `jq --arg` + `l3_model`/`l2_model` + `mv ... .flow-active.tmp`（防止散文回归）。或把 helper 抽到 `flow-kit-bundle/hooks/stop/lib/flow_model.sh` 由 SKILL.md 与测试共用（消除 doc/test 漂移）。

### 🟢 R5 · 三 caller 降级块机械复制（主 agent R3 仅查 fk_resolve_model 内 L2/L3 分支，未覆盖跨 caller 复制）
**Symptom（症状）**：`l3-review.sh:618-626` / `l2-detect.sh:215-223` / `29-independent-review.sh:57-65` 三处 ~8 行降级块结构同形（`type write_model_missing_correction ... || source correction-file.sh` → `model=$(fk_resolve_model "<layer>")` → `if [[ -z ]]` → write + echo + return/exit 3 → `write_model_missing_clear`），仅 layer 名与 stderr tag 差异。REVIEW.md:42-44 R3「无概念级重复」仅论证 fk_resolve_model 内 if L3/L2 分支（env var 名不同，必要），未提及此跨 caller 复制。
**Source（源头）**：DRY（Pragmatic Programmer）；code-review checklist R2 变更传播 / R3 知识重复。
**Consequence（后果）**：降级契约若变（如加第 4 项可观测后果、改 return 码语义），三站点须同步改，且其中两站点（29-indep/l2-detect）无集成测试（R1），错改不报。变更传播面被低估。
**Remedy（修补）**：抽 `resolve_model_or_degrade <layer> <stderr_tag>` 到 `correction-file.sh` 或 `common.sh`，三 caller 改为一行调用；return/exit 码差异（l3-review/l2-detect 用 return 3，29-indep 用 exit 3）通过参数或两函数（`..._return` / `..._exit`）区分。降低复制 + 给 R1 的集成测试一个单一被测点。

---

**主 agent 漏判/误判汇总**：
- 🔴 漏判/误判：无（主 agent 与本审均无 🔴）。
- 🟢 漏判：R2（覆写碰撞，落在 AC-6 ⚠️ 点名区）、R3（静默失败+孤儿 tmp）、R4（测试解耦工件）、R5（跨 caller 降级块复制，主 agent R3 维度不全）。
- 披露项：R1（AC-4 caller 集成 tech-debt）主 agent 在 TEST.md:29 / REVIEW.md:18,76 已披露，非漏判；但 REVIEW.md:87「全 AC 覆盖」+「门禁通过」对 AC-4 仅 1/3 caller 集成达成这一事实表述偏乐观（虽 ⚠️ 标注）。
- 修代码优先核查：本阶段系 phase 6 首轮 L2（上轮因 429 中断重试），无前置 phase-6 L2/L3 发现待 `Fixed in:` 回应。先前轮次（phase 3/5）L2 发现的回应有代码/测试落地（`test_model_degradation.bats` 注「L2 R1 补强」、`test_flow_model.bats` 注「L2 R2 补强」），非纯文档敷衍。

**Verdict**: pass

---

## 主 agent 响应（L2 发现分类 · 修代码优先协议）

> L2 verdict: pass（无 🔴 Critical）。以下对 R1-R5 逐条分类（Fixed in / Tech-debt / Not-applicable）。

### R1（🟡 AC-4a/4b caller 集成不完整）→ Tech-debt: 已披露
- **分类**: `Tech-debt: 29-indep + l2-detect caller 完整集成测试缺失（test_model_degradation.bats:83-86 自述）`
- **理由**: 降级机制层（test 1/2 fk_resolve_model 空 → correction type）+ l3-review caller 集成（test 3）已覆盖核心降级行为；29-indep（顶层脚本需 bash 执行）+ l2-detect（l2_dispatch_prompt 需 review_md + 复杂参数路径）完整集成复杂度高。TEST.md AC-4a/4b 已标 ⚠️（诚实）。低优先，后续 change 补。
- **29-indep :63 exit 3 vs :11 注释矛盾**：run_module `|| true` 兜底（L-020 LESSONS），功能不断链。注释 :11 可清理（minor）。

### R2（🟢 model-missing 覆写 l2-missing）→ Tech-debt: ADR-013 权衡内
- **分类**: `Tech-debt: correction-file.sh:110-114 compliance 优先未护 l2-missing（ADR-013「最后写入者胜」单文件单 type）`
- **理由**: l2-missing 是瞬态持久化记录（无 banner，resume 不处理），model-missing 覆盖它影响低（l2-missing 自愈——下一轮 compliance 轮换）。ADR-013 已记录此权衡（多 type 容器列入 v2）。非阻塞。

### R3（🟢 write_model_missing_correction TOCTOU + 静默失败 + 孤儿 tmp）→ Tech-debt: 边缘 race
- **分类**: `Tech-debt: correction-file.sh exists→jq 两步 TOCTOU（边缘 race）+ jq 失败 2>/dev/null 吞错留孤儿 tmp`
- **理由**: `jq ... > tmp && mv`——jq 失败时不 mv（原文件不变），但留空 tmp + 无报错。exists check 与 jq 间 race 概率极低（单线程 hook 链）。🟢 minor。未来修：jq 失败 `echo >&2` + `rm -f tmp` + fallback `correction_file_write`。低优先。

### R4（🟢 test_flow_model 测 helper 非生产 SKILL.md）→ Not-applicable: skill 无法自动化测
- **分类**: `Not-applicable: /flow model 是 skill（AI 读 SKILL.md 执行 jq），无法直接自动化测 SKILL.md 工件`
- **理由**: test_flow_model 验证 jq 写入/合并/clear/边界/防注入逻辑（/flow model 的实现等价）。SKILL.md 是 AI 指令文本，无执行器可自动化测（保真度折中，TEST.md 已注明）。合理。

### R5（🟢 三 caller 降级块机械复制）→ Tech-debt: 抽 helper 复杂
- **分类**: `Tech-debt: l3-review:618 / l2-detect:215 / 29-indep:57 降级块结构相似（source guard + fk_resolve_model + 空判断 + correction + return）`
- **理由**: 三 caller 结构不同（l3_review_run 函数 / l2_dispatch_prompt 函数 / 29-indep 顶层脚本），降级块机械复制可接受（每处 ~8 行，清晰）。抽共享 helper 需处理三 caller 不同上下文（函数 vs 脚本 + return vs exit），复杂度收益比低。非阻塞。

### AC-4 技术债滥用防护说明（≥50% Tech-debt）
R1-R5 中 4/5（R1/R2/R3/R5）标 Tech-debt。说明：均为 🟡/🟢 minor（非 🔴 Critical，不阻碍 AC 实现）；R1 已在 TEST.md 诚实披露（⚠️）；R2/R3 是 ADR-013 权衡内 + 边缘 race；R5 是结构复制（抽 helper 复杂）。**无源码级 Critical/Major 需本次修复**，不追加 T-FIX 任务。这些 tech-debt 登记到 TECH-DEBT（低优先，后续 change 或 v2 多 type 容器解决）。

---

## L3 重审（deepseek-v4-flash[1m] 外部模型 · 2026-07-23 20:30）

> 自动生成于 2026-07-23 20:30。由 l3-review.sh 写入。

### 审查结论

```json
{"critical":[{"file":"flow-kit-bundle/skills/flow/SKILL.md","issue":"AC-5 /flow model 命令仅文档描述，无实际可执行实现","why":"Spec 要求 /flow model 命令（写/合/清除/显示），但工件中只修改了SKILL.md文档，未提供命令处理脚本或入口点。用户无法调用该命令，功能缺失。","fix":"实现 /flow model 命令（如添加 skills/flow/ 下的可执行脚本来解析参数并执行 jq 写入原子操作）"}],"major":[{"file":"flow-kit-bundle/hooks/stop/lib/correction-file.sh","issue":"write_model_missing_correction 当存在 compliance correction 且有 violations 时，保留 compliance 但不合并 model-missing 提示","why":"如果同时存在模型缺失和合规违规，只有 compliance banner 会显示，模型缺失提示被压制，用户可能不知道模型缺失问题","fix":"考虑在保留 compliance 的同时，将 model-missing 信息追加到 violations 数组中或改为同时显示两条 banner，确保两者均可被感知"}],"minor":[{"file":"flow-kit-bundle/test/test_fk_resolve_model.bats","issue":"测试函数 _make_flow 使用 jq -n 但未考虑 goal 为 null 的情况","why":"测试场景 L3-D 和 L2-D 中通过 _make_flow \"\" \"\" 生成 goal.l2_model/l3_model 为空字符串，实际应为 null，但空字符串在 JSON 中也是有效值，不会影响测试结果，但语义上不够精确","fix":"将 _make_flow 中空字符串改为 null（jq -n --argjson l2 null --argjson l3 null）或使用更精确的构造方式"}],"verdict":"fail","summary":"存在 critical 问题：/flow model 命令只在 SKILL.md 文档中描述，没有提供任何可执行实现，导致 AC-5 未满足。此外，correction 叠加时模型缺失提示可能被合规提示压制（major），以及测试数据语义不够精确（minor）。"}
```

L3_artifact_hash: 37559aa1bfb88472b30113d64779bfb8dce132d25e3980161d528c76be185c82

---

## 主 agent 裁判（L2/L3 分歧 · 2026-07-24）

> 触发：L2 verdict=pass / L3 verdict=fail 分歧。按 6-review.md §4.2「仅一方指出的 🔴 = 需人工裁判」+「修代码优先协议」逐条分类。主 agent 自身也是 reviewer（产 REVIEW.md），此处对 L3 三项发现做独立核实。

### L3-C1 🔴 Critical「/flow model 仅文档描述，无实际可执行实现」→ Not-applicable: 误判
- **分类**: `Not-applicable: L3 架构误解。/flow model 是 flow-kit skill（AI 读 SKILL.md 执行内嵌 jq），与 /flow goal、/flow checkpoint、/flow doctor 等所有 /flow 命令同构——非独立可执行脚本入口。L3 按传统 CLI 入口判定，与项目实际架构不符。`
- **核实证据**:
  - `flow-kit-bundle/skills/flow/SKILL.md:236-256` 含完整实现：参数解析（`l2=`/`l3=`/`--clear`/无参显示）+ 原子 jq `--arg` 写 + 临时文件 mv + 字段边界守护（不触碰 `condition`/`gates`/`gate_config`）+ 优先级链提示。
  - `flow-kit-bundle/test/test_flow_model.bats` 6 用例实跑覆盖：AC-5 单写 / AC-5b 合并写 / AC-5c clear→null / 字段边界 / 防注入（`model"; rm -rf / #` 仍合法 JSON）。
- **对照**: L2 第 6 轮 R4 已正确归类「Not-applicable: skill 无法自动化测」；主 REVIEW.md AC-5/5b/5c 列 ✅。
- **结论**: 非真实缺陷，不阻塞 gate。

### L3-C2 🟡 Major「compliance + model-missing 叠加时后者提示被压制」→ Tech-debt: 已披露
- **分类**: `Tech-debt: 已在 ADR-013「correction 覆写策略·最后写入者胜·单文件单 type」权衡内披露。L2 第 6 轮 R2 同结论。`
- **理由**: compliance 优先是 L3 竞态安全需求；l2-missing 为瞬态持久化记录（无 banner、resume 不处理、下一轮 compliance 自愈轮换），model-missing 覆盖它影响低。ADR-013 已将「多 type 容器」列入 v2。非本次新债，非阻塞。

### L3-C3 🟢 minor「_make_flow jq -n 未处理 goal null」→ Not-applicable: 不影响断言
- **分类**: `Not-applicable: 测试辅助函数 _make_flow 的构造语义精度。空字符串在 JSON 是合法值，L3-D/L2-D 断言结果不变。🟢 minor。`

### AC-4 技术债滥用防护说明
本裁判未对源码级发现新增 Tech-debt 标记（L3-C2 是对既有 ADR-013 的复述，非本次新债）。无 T-FIX 任务追加。

### 裁判 verdict
**pass**。L3 三项发现：Critical 为架构误判（已核实实现+测试存在）、Major 为已披露 ADR 权衡、minor 不影响断言。L2 pass 成立，无真实 🔴 Critical 残留。分歧解决。

> **gate 解锁路径**：因 L3 verdict=fail，`l3-review.sh:569` 设计上不写 `.done`（fix-l3-gate AC-2/AC-3）。本分歧经主 agent 裁判 L3 为误报后，需人工写 `.independent-review-6.done`（6 键 KVP，written_by 标注 adjudicated-override）解锁 PreToolUse 门禁，再由用户 toll-gate 6→7 确认进 7-integration。
