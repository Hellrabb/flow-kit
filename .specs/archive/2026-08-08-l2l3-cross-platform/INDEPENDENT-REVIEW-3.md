# 独立审查 · 阶段 3

> **L2 盲审** · 审查日期: 2026-08-06 · 审查阶段: 3-task
> **独立性声明**：输入仅 `TASK.md` / `REQUIREMENT.md` / `DESIGN.md` 三个工件 + 仓内事实核查（grep/sed 实测，见各 finding 证据）。未收到主 agent 自评、草稿或辩护，未检测到上下文注入，独立性未受损。
> **方法**：3-task checklist（粒度 / 依赖链 / verify 可验证性 / 覆盖完整性 / 禁动清单）+ L-031 全仓锚点扫描（`subagent_type` / `ANTHROPIC_*` 直读 / `OPENCODE` 信号三组锚点实测，不信 DESIGN 清单）。

---

## L2 盲审

### 一、通过项核对（实测确认，非声明）

| 检查项 | 结论 | 证据 |
|---|---|---|
| AC-1~AC-8 全覆盖 | ✅ | AC-1→T01/T02/T03/T11；AC-2→T01/T11；AC-3→T02/T03/T06/T11；AC-4→T03/T04/T05/T07/T11；AC-5→T08/T09/T10；AC-6→T12；AC-7→T12；AC-8→T12 |
| 依赖图无环 + 波次 | ✅ | T01→T02/T03；T08→T09/T10；T11→{T01,T02,T03,T05,T06,T07}；T12→T11；Wave 1-4 划分与 depends_on 一致 |
| 粒度 ≤200 行/任务 | ✅ | 最大改动面 T03（l2-detect.sh 单文件 3 段）；T07 为 6 文件 × 1-2 行插入 |
| write_files 禁动合规 | ✅ | 全部落在 DESIGN §0.5.1 触碰/新增模块；gate 核心链（independent-review-gate.sh / 29 / fk_validate_done_marker）、correction-file.sh 签名、HOOK_MODULE_NAMES 零触碰；package-flow-kit.sh 禁动例外已在 CONTEXT 登记（2026-08-06 · Part A 仅新增 .opencode/agent 覆盖点）✅ |
| L-031 锚点实测（flow-kit 自有域） | ✅ | 实测 `subagent_type`：6 prompt 7 处（1:85/2:239/3:194/5:52/6:105/6:302 文本行/7:55，行号与 TASK 一致）+ l3-review.sh:212 + transcript-parser.sh:99 + l2-detect.sh:98，全部有 task 覆盖；`ANTHROPIC_*` 直读仅 l3-api.sh:20-21/69/84（T02）+ l2-detect.sh:175-176/229/253/263（T03），与 DESIGN 0.5.1 行号吻合；30-ai-analyze.sh L91-125 ANTHROPIC-only 链实测存在，DESIGN §6「登记不改」属实 |
| T09 安装载体 | ✅ | install_hooks.sh 实测 `install_hooks(project, scope)` 签名（L66-68）+ install_file 支持 DRY_RUN（L24）+ opencode 平台分支（L91/L100），T09 verify 的调用形态 `install_hooks "$HOME" user` 与签名匹配 |
| T10 打包载体 | ✅ | package-flow-kit.sh L40 `rsync -a`（含 dotfile）打包 flow-kit/，「预期零改动」可信；`.gitignore` 无 .opencode/agent 排除规则，新文件可提交 |
| 25 用例回归锚点 | ✅ | test_model_degradation.bats(3) + test_fk_resolve_model.bats(10) + test_independent_review_model.bats(12) = 25，三文件实测存在 |
| T06 source 可行性 | ✅ | flow-kit-resume.sh 实测已有 `${script_dir}/../stop/lib/*.sh` 相对 source 模式（L175/176/204），source common.sh 无技术障碍 |

---

### 二、发现

### 🟡 R1 · T06 允许「轻量内联平台判定」，与 DESIGN D2 单点封装决策冲突
**Severity**：🟡 Important
**Symptom**：TASK.md T06 action「若既有无 source 机制则用轻量内联判定并注释说明，二选一以最小 diff 为准」——为内联 `[[ -n $OPENCODE ]]` 开了一扇门；而 flow-kit-resume.sh 实测已有 L175/176/204 的 `${script_dir}/../stop/lib/*.sh` 相对 source 模式，source common.sh 本就零成本，「最小 diff」论据不成立。
**Source**：DESIGN D2（平台检测提取共享函数、消灭内联判定的绑定决策：l2-detect.sh:180 既有分支统一改调）+ DESIGN 0.5.3「单点封装防锚点漂移」。
**Consequence**：实施者按「最小 diff」选内联 → 平台判定出现第二个实现；未来 T03 侧共享函数语义演进（如加第三信号）时 resume 分支判定漂移（提示分支与派发分支判定不一致），D2 要消灭的锚点漂移在首个实现就复现。
**Remedy**：T06 action 固定为 source common.sh（沿用 L175/176 的 script_dir 相对模式），删除内联选项；若 session-start 链无 HOOK_BASE_DIR 属实的顾虑，用 `script_dir/../stop/lib/common.sh` 显式路径。

### 🟡 R2 · T06 verify 恒真空转，且被吞掉的正是必然失败
**Severity**：🟡 Important
**Symptom**：`<verify>OPENCODE=1 bash -c 'source flow-kit-bundle/hooks/session-start/flow-kit-resume.sh 2>/dev/null || true' 2>&1 | head -5`——`|| true` 使退出码恒 0，`2>/dev/null` 吞掉全部错误。实测：resume.sh 被 source 时 `$0`=bash → `script_dir=$(dirname "$0")`="." → `banner_lib=./../stop/lib/banner.sh` 不存在 → L209-211 走 `exit 1`——该失败被 verify 完全掩盖。done 判据「opencode 下 banner 含 FLOW_KIT_L3_BASE_URL/AUTH_TOKEN 指引行」在 verify 中零检查。
**Source**：3-task checklist「verify 可验证性：每条 verify 是否可机器执行（非"人工确认"空话）」；verify 必须能失败才有意义。
**Consequence**：banner 平台指引改动零验证（假绿）；T06 的 done 判据只能靠自觉完成，指引行缺失/写错一路漏到 T12 全量回归甚至上线。
**Remedy**：改为可失败断言并断言内容，如 `OPENCODE=1 bash -c 'source .../flow-kit-resume.sh' 2>&1 | grep -q "FLOW_KIT_L3_BASE_URL"`（CC 分支反向 `grep -q "ANTHROPIC_AUTH_TOKEN"` 对照）；去掉 `|| true`；source 方式改为先 set -- "$0" 或用 `BASH_SOURCE` 计算 script_dir 的脚本化调用。

### 🟡 R3 · T01 verify 的 rc=1 主场景被 set -e 吞掉，退出码与期望值重合 → 假绿陷阱
**Severity**：🟡 Important
**Symptom**：`<verify>env -i HOME=$HOME bash -c "source common.sh; fk_resolve_api_credentials; echo rc=$?; echo base=[$FK_API_BASE_URL]"`——common.sh L5 实测 `set -euo pipefail`。实测复现：`bash -c 'set -euo pipefail; f(){ return 1; }; f; echo rc=$?; echo after'` 输出为空、bash -c 退出码=1。即全空场景（期望 rc=1）下 `echo rc=$?` 永不执行，bash -c 退出码 1 恰与期望 rc 重合——dev 会把它当「通过」；而函数中途崩溃（如 set -u 未防护变量）也退出 1，两种情形无法区分。
**Source**：3-task checklist「verify 可机器执行」；bash errexit 语义（裸命令返回非零即退出，POSIX/`set -e`）。
**Consequence**：T01 的「空环境 rc=1」主场景实际永远测不到；凭证函数若实现有误（未清空全局/未防护变量），verify 仍 exit 1 → 假绿直达 T11。
**Remedy**：条件上下文捕获 rc：`bash -c 'source ...; if fk_resolve_api_credentials; then echo rc=0; else echo "rc=$?"; fi; echo "base=[${FK_API_BASE_URL:-}]"'`（条件上下文抑制 errexit）。

### 🟡 R4 · Path2 scheme 接口未定死 + T11 矩阵零 scheme/header 断言（AC-2 Path2 行为无覆盖）
**Severity**：🟡 Important
**Symptom**：T01 action「用第三个全局 FK_API_AUTH_SCHEME（bearer|x-api-key）或 FK_API_USE_X_API_KEY=1，二选一，DESIGN 未定死」——接口在 TASK 层仍未定死，T02/T03 各自实现；T11 的 test_l3_credential_resolution.bats 矩阵只断 rc/base_url/stderr，**没有任何** Path2→`x-api-key` header / Path1/3→`Bearer` header 的断言（T11 done 声称「覆盖 AC-1/2/3/4 全部验证方式」不实——AC-2 的 Path2 行为零覆盖）。
**Source**：DESIGN §2 数据流（Path2 必须 `-H "x-api-key: $key"`——行为已定，机制名未定）；DESIGN 页脚「函数签名、伪代码、接口定义可以」——第三个全局的命名/语义正是接口，应在本层定死而非留到实现时二选一。
**Consequence**：T02/T03 若选不同变量名或 header 逻辑分叉，无任何测试拦截 → legacy/opencode 用户 401，线上才发现；「两处一致使用」靠注释约定，是弱约束。
**Remedy**：TASK 层定死（如 common.sh 输出 `FK_API_AUTH_SCHEME`，取值 bearer|x-api-key）；T11 加 mock curl 或 bash -x 捕获断言：Path2 → header 含 x-api-key，Path1/3 → header 含 Bearer。

### 🟡 R5 · L-031 锚点清单缺 brooks-harness SKILL.md:26 分类登记
**Severity**：🟡 Important
**Symptom**：全仓实测 `subagent_type` 命中 `flow-kit-bundle/brooks-lint/plugin/.claude/skills/brooks-harness/SKILL.md:26`（Agent tool + subagent_type 编排段），REQUIREMENT AC-4 锚点清单（10 处）、DESIGN 0.5.1、TASK 三处均零提及零分类。
**Source**：L-031 教训（全仓扫描、不信清单、每个锚点必须有明确处置）；AC-4「本 change 范围枚举」的自证。
**Consequence**：4-dev 的 L-031 扫描撞到此锚点无处置依据——顺手改 vendored 插件越界、静默忽略则无记录；opencode 用户安装 brooks-lint 插件跑 harness 技能时复现 subagent_type 挂起，本 change 宣称的双平台兼容留有**已装载组件内的已知空洞**且无文档。
**Remedy**：TASK 执行说明显式分类一行（vendored 第三方组件 · 不在 L2/L3 派发域 · 登记不改/列入 v2，附理由），堵住实施期误改或漏记两向风险。

### 🟡 R6 · T02 verify 的 grep -c 与「文件头注释同步」自相矛盾（保证性失败）
**Severity**：🟡 Important
**Symptom**：`<verify>grep -c "ANTHROPIC_AUTH_TOKEN" l3-api.sh` 断言 0（注释可豁免时人工确认）；而 T02 action 同时要求「文件头注释同步（L18-22 加 FLOW_KIT_L3_* 两行）」——Path1 仍走 ANTHROPIC_AUTH_TOKEN（解析移至 common.sh），文件头保留该 env 名是**准确文档**，且 action 只要求「加」两行未要求删 ANTHROPIC 行 → grep -c ≥ 1 → verify 保证性失败，实施者被迫删准确注释或人工豁免。
**Source**：3-task checklist「verify 可机器执行（非"人工确认"空话）」；ADR-019 文档准确性原则。
**Consequence**：要么文档劣化（删合法 env 依赖说明），要么 verify 每次走人工豁免（等于形同虚设），两害必居其一。
**Remedy**：verify 改为排除注释行的可失败断言：`grep -n "ANTHROPIC_AUTH_TOKEN" l3-api.sh | grep -vE '^[0-9]+:\s*#'` 并断言输出为空；文件头注释保留准确 env 依赖说明。

### 🟢 R7 · l2-detect.sh 两处注释锚点未纳入 T03（L10 + L126-127）
**Severity**：🟢 Minor
**Symptom**：l2-detect.sh:10 注释「生成一键 Agent 命令模板（含 subagent_type + description + prompt 骨架）」在 L98 改双模式后变陈旧；l2_dispatch_agent 头注释 L126-127（「ANTHROPIC_AUTH_TOKEN / ANTHROPIC_API_KEY — API 鉴权」）在凭证共享化后需同步，但 T03 写的是「函数头注释（L2-9）同步」——行号指向文件头而非 L126-127。
**Source**：L-031 锚点纪律（注释也是锚点载体）；T03 action 自身行号引用与实测不符。
**Consequence**：文档漂移，后续维护者误以为 l2-detect 仍自持 ANTHROPIC 凭证链。
**Remedy**：T03 补 L10 与 L126-127 两处注释同步，行号引用修正为实际位置。

### 🟢 R8 · AC-6 验证方式 bats→shell grep 偏差未登记，且 T12 verify 元素不含红线断言
**Severity**：🟢 Minor
**Symptom**：REQUIREMENT AC-6 验证方式为「bats 断言拆两条」，TASK 只在 T12 action 文本里放 shell grep（「①…grep -s 退出码 1 ②…」），T12 `<verify>` 仅 `npx bats test/ && make check`——红线断言无任何机器强制，执行全靠 dev 自觉照做 action 细节。
**Source**：AC-6 验证方式原文；3-task「verify 可验证性」。
**Consequence**：dev 若只跑 verify 元素，AC-6 两条 token/env 名红线扫描实际未执行，泄露零检测。
**Remedy**：两条 grep 移入 T11 或 T12 verify 元素（`run grep -rsE ...; [[ $status -eq 1 ]]`），与 REQUIREMENT 的 bats 断言对齐。

### 🟢 R9 · prompt 双模式用「注释行」实现，弱模型可能忽略（protect the weakest 弱化）
**Severity**：🟢 Minor
**Symptom**：T07 在 `subagent_type: <agent>` 行后追加注释行（`# opencode 平台：改用 category 路由 → …`）；对比 T03/T04 的 box 模板是**并列双分支**（两行同为模板正文）。AC-4 结构断言只验子串存在（`category=` 命中注释即过），验不出「opencode 分支是否一等可执行」。
**Source**：CONTEXT 已锁哲学「protect the weakest」（弱模型跳过非结构化指令）；本 change 的根因正是 opencode 下 subagent_type 挂起——把规避手段写在注释里，弱模型主 agent 完全可能照抄挂起模板行。
**Consequence**：AC-4 意图在弱模型场景打折，opencode 下 L2 派发仍可能挂起，但结构断言全绿。
**Remedy**：可选增强——prompt 内 opencode 分支也写成并列正文行（与 box 风格一致，如 `category: "unspecified-high"（opencode 平台用）`），注释仅作补充；至少保留结构断言兜底。

---

### 三、需确认项（无判断，留待上下文）

1. **hook 输出持久化边界**：AC-6 Given 列了「hook 日志」但验证方式未扫；实测 stop 链（29 / independent-review-gate.sh / l3-api / l2-detect）无 hook_log 落盘点，stderr 提示（含 env 名，D3 允许）默认只进 hook 协议输出。若 opencode 桥接层或宿主另有日志持久化，需确认其不含 env 名/token 值。

---

**Verdict**: pass

（5 × 🟡 Important 入 fix loop（T01/T02/T03/T06/T07/T11/T12 内解决）；4 × 🟢 Minor 建议写入 `.specs/l2l3-cross-platform/MINOR-DEFERRED.md`；无 🔴 Critical。）

---

## 主 agent 响应（Phase 3 fix loop · 2026-08-06）

> 说明：正文 R6 标题标 🟡 而 Verdict 总结归 🟢（4×Minor 清单含 R6-R9）。按总结归类：R6 按 🟢 处理（verify 文本级缺陷，直接修 TASK.md + MINOR 登记，不入实现 fix loop）。

### 🟡 R1 · T06 内联判定（Fixed in: TASK.md T06 action）
T06 action 已删除「轻量内联判定」选项，固定 source common.sh（沿用 L175/176 `${script_dir}/../stop/lib/common.sh` 相对 source 模式）调 fk_platform_is_opencode()。

### 🟡 R2 · T06 verify 恒真空转（Fixed in: TASK.md T06 verify）
verify 重写为可失败断言：`grep -q "fk_platform_is_opencode" ...` + `OPENCODE=1 bash flow-kit-resume.sh 2>&1 | grep -q "FLOW_KIT_L3_BASE_URL"`。直接执行（非 source）避开 `dirname $0` 陷阱；去掉 `|| true`；done 判据（banner 含指引行）现在被 verify 实际检查。

### 🟡 R3 · T01 verify set -e 吞 rc（Fixed in: TASK.md T01 verify）
verify 改为条件上下文捕获 rc：`if fk_resolve_api_credentials; then echo rc=0; else echo "rc=$?"; fi`，全空场景 rc=1 可观测，不再与崩溃退出码重合。

### 🟡 R4 · scheme 接口 + T11 header 断言（Fixed in: TASK.md T01 action + T11 action）
- 接口定死：第三个全局 `FK_API_AUTH_SCHEME`（bearer|x-api-key），T02/T03 统一按此选 header。
- T11 新增 scheme/header 断言：mock curl（PATH 前置 fake curl 捕获 -H）断言 Path2 → `x-api-key:`、Path1/3 → `authorization: Bearer`，AC-2 Path2 行为真实覆盖。

### 🟡 R5 · brooks-harness SKILL.md:26 分类登记（Fixed in: TASK.md 执行说明）
登记为 vendored 第三方组件（brooks-lint 插件），不在 L2/L3 派发域，登记不改，列入 v2。

### 🟢 R6 · T02 verify 自相矛盾（Fixed in: TASK.md T02 verify + MINOR-DEFERRED M8）
verify 改为排除注释行后断言零直读（`grep -vE '^[0-9]+:[[:space:]]*#'`），文件头 env 注释作为准确文档保留。

### 🟢 R7 · l2-detect 注释锚点（Fixed in: TASK.md T03 action + MINOR-DEFERRED M9）
T03 action 补 L10（模板注释）与 L126-127（env 文档头）两处注释同步。

### 🟢 R8 · AC-6 红线不在 verify（Fixed in: TASK.md T12 verify + MINOR-DEFERRED M10）
两条红线 grep 移入 T12 `<verify>` 元素（token 值模式扫全部含 INDEPENDENT-REVIEW-*.md；env 名模式豁免审查者产物），机器强制，不再靠 dev 自觉。

### 🟢 R9 · prompt 注释行弱模型（MINOR-DEFERRED M11 · 不修）
T07 采用注释行方案是 D4 设计取舍（prompt 最小 diff，box 并列双行会改变既有 CC 模板排版与结构断言基线）；结构断言（`category=` 子串）作兜底。增强（并列正文行）列为 v2 候选。

### 需确认项答复（hook 日志持久化边界）
已确认：stop 链无 hook_log 落盘点（stderr 提示只进 hook 协议输出，D3 允许含 env 名）；AC-6 验证方式扫的产物清单不含 hook 日志文件——若 opencode 桥接层另有日志持久化，其内容不在本 change 的 token 值红线扫描范围（bridge 层日志属平台层，登记说明）。

**Verdict 复核**：全部 🔴/🟡 已处置（TASK.md 修订完成），无遗留。

---

## L2 盲审（修订版）

> 盲审对象：TASK.md（修订版 · 4 任务 3 波次 delta）、REQUIREMENT.md（10 AC）、DESIGN.md（D1 平台翻转 + §2 双平台图）、CONTEXT.md（禁动清单）。独立复核，全部基于磁盘实测（common.sh L266-323 / transcript-parser.sh L98-104 / .flow-active / 两 bats 文件 @test 计数 / bats 二进制存在性 / fixtures 内容）。

### 🔴 R1 · TASK.md 重新引入 IR-2 R-4 已定稿消除的 `.input.category` 裸路径：opencode 归类表达式与 REQUIREMENT 矛盾且"实测"自证

**Severity**：🔴 Critical

**Symptom（症状）**：TASK.md:50（T02-rev 归类表达式 `(.input.category // .args.category // "general-purpose")`）与 TASK.md:83（T03-rev mock `{"type":"tool","tool":"task","input":{"category":"unspecified-high"}}`）均为**无 `state` 层**的裸 `input.category`；而修订后的 REQUIREMENT.md:51/101 与 DESIGN.md:83/242 已按 IR-2 R-4 修复统一为 `state.input.category`（AC-4 mock 实测形状 `{"state":{"input":{"category":...}}}`）。TASK.md:141 执行说明把定稿责任推给 4-dev"bats 实测"。

**Source（源头）**：IR-2 R-4 Remedy（"删掉 input.category 的裸路径表述"）；ADR-019 原则①（AC 必须确定性，行为不得靠执行者猜测）；TASK 与同 change REQUIREMENT 同层矛盾。

**Consequence（后果）**：真实 opencode task part 归类字段在 `state.input.category` 层（AC-4/AC-4b 自行声称的实测形状）→ T02-rev 表达式两分支均落空 → **opencode 全部 task part 归类回退 `general-purpose` 兜底**，`subagent-usage.txt` 统计静默失真——正是 R2 要修的缺陷换形状复发（IR-2 L299 已预言此路径）。T03-rev 的自编 mock 与暂定路径**自洽**（mock 也缺 `state` 层）→ bats 全绿假绿。仓库内无任何真实 opencode transcript jsonl 锚点（`find -name "*.jsonl"` 零命中，fixtures 仅 CC 形状）→ "以 bats 实测为准"无真实数据源可测，闭环于自我确认。

**Remedy（修补）**：TASK.md T02-rev 归类表达式**定稿**为 `state.input.category`（与 REQUIREMENT AC-4b 一致）：`(if .tool == "task" then (.state.input.category // .args.category // "general-purpose") else (.args.category // .args.subagent_type // "general-purpose") end)`；T03-rev mock 同步改为 AC-4 mock 形状 `{"type":"tool","tool":"task","state":{"input":{"category":"unspecified-high"}}}`；"以 bats 实测为准"降级为注记（若 4-dev 环境有真实 opencode 数据可复核，路径不同才允许反推修订 REQUIREMENT/DESIGN/TASK 三处并登记证据），**默认值以 AC-4b 为准，不留给执行期裁决**。T02-rev verify 亦应补测归类表达式（现 verify 只测过滤谓词不测归类分支，改错归类也绿）。

### 🟡 R2 · T01-rev verify 命令按字面不可执行：`env` 无法运行 shell 函数，且 common.sh `set -euo pipefail` 使首条失败即退出

**Severity**：🟡 Important

**Symptom（症状）**：TASK.md:31 verify 三场景均写作 `env -u <VAR> ... fk_resolve_api_credentials`——`env` 是外部二进制，**不能调用 shell 函数**，会以 `env: 'fk_resolve_api_credentials': No such file or directory` 失败（rc=127）。且 common.sh:6 自带 `set -euo pipefail`，source 后第一条 `env` 失败即令整个 `bash -c` 提前退出，场景 2/3 与 `echo "rc=$?"` 永不执行。三个场景中函数体一次都不会被调用；即使能调，`env VAR=...` 赋值也只作用于 exec 出的（不存在的）外部命令，`OPENCODE=1`/`FLOW_KIT_L3_*` 同样传不进去。

**Source（源头）**：bash 命令解析语义（`env` exec 外部命令 vs 函数）；common.sh:6 `set -euo pipefail`（实测）；IR-2 R-F-A1 同类教训（"断言按字面不可执行"）。

**Consequence（后果）**：AC-2 平台翻转（本 delta 核心）在 T01-rev 自身 verify 处**无有效机器验证**——按字面跑必败（假失败卡 T01）或执行者改代码迁就坏命令（假绿）。平台翻转的唯一真实门禁只剩 T03 bats 矩阵（有覆盖，故不升 🔴），但 T01 的独立烟测形同虚设。

**Remedy（修补）**：改为括号子 shell 内 unset + 直接调函数：`bash -c 'source hooks/stop/lib/common.sh; (unset ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY FLOW_KIT_L3_AUTH_TOKEN FLOW_KIT_L3_BASE_URL OPENCODE OPENCODE_BIN; fk_resolve_api_credentials; echo "rc=$?")'` 等三场景，并对 `FK_API_BASE_URL`/`FK_API_AUTH_SCHEME` 输出做**断言**（`[ "$FK_API_BASE_URL" = "$FLOW_KIT_L3_BASE_URL" ]` 式），不能只 echo 靠人眼看。

### 🟡 R3 · AC-6 红线 base64 模式 `{32,}` 对 task_progress.commit_sha 全长十六进制假阳性：自伤 gate

**Severity**：🟡 Important

**Symptom（症状）**：TASK.md:85/113（T03-rev + T04-rev 两条红线）token 值模式 `[A-Za-z0-9+/]{32,}={0,2}` 第二分支无锚定（`=sk-` 分支有前缀，base64 分支裸跑）——任意 ≥32 位连续 `[A-Za-z0-9+/]` 即命中。`.flow-active.goal.task_progress[].commit_sha` 若以全长 40-hex 写入（现 .flow-active 实测为 7 位缩写 `b8cda56`，无格式约束），40 位 hex 全在字符类内 → 红线 ① 假红。T03/T04 恰是 .flow-active 活跃写入期（本 delta 自加的 gate 先误伤自己）。

**Source（源头）**：AC-6 意图 = token 值（`=sk-` 前缀 / base64 带 `=` 尾缀）；ADR-019 原则① 确定性；base64 模式引用 REQUIREMENT.md:66 原文（同缺陷源头）。

**Consequence（后果）**：T03/T04 verify 及新增 bats 红线在写入全长 commit_sha 时确定性失败 → 阻断 pipeline 或逼执行者"规避"；红线失去威慑力（狼来了效应）。

**Remedy（修补）**：base64 分支加 `=` 锚定（`=[A-Za-z0-9+/]{32,}={0,2}`，与 `=sk-` 分支同构）；或显式排除 `[0-9a-f]{40}` git sha；并在 TASK 注明 task_progress.commit_sha 维持缩写（7 位）约定。REQUIREMENT.md:66 同模式同步修订。

### 🟢 R4 · T02-rev CC 分支归类序与 AC-4b 文字不一致（行为等价）

**Symptom**：AC-4b(REQUIREMENT:51) 文字"CC 形状下按 `args.subagent_type` 归类"；TASK:50 表达式 `.args.category // .args.subagent_type`（category 优先）。真实 CC `Agent` 工具 args 无 `category` 字段（实测 transcript-parser.sh:104 既有实现 + test_l2_dispatch_mode.bats:143 已钉 category-first），行为等价。
**Source**：REQUIREMENT:51 vs TASK:50。
**Consequence**：无行为后果；仅文档措辞不一致（弱模型执行者按文字实现时两种写法等价）。
**Remedy**：AC-4b 文字补"（`.args.category //` 兼容前缀，行为等价）"或 TASK 表达式删 `.args.category` 与既有测试对齐。

### 🟢 R5 · T03-rev "既有 17+7 用例保留不删" 与实测不符

**Symptom**：TASK.md:88 声称 17+7；实测 `grep -c @test`：test_l3_credential_resolution.bats=17、test_l2_dispatch_mode.bats=12（双源一致）。
**Source**：TASK.md:88 vs 磁盘实测。
**Consequence**：无执行影响（保留不删由 T04 全量回归兜底）；数值陈旧。
**Remedy**：顺手更新为 17+12。

### 🟢 R6 · T01-rev read_files 未列两调用方（L-031 教训强化）

**Symptom**：T01-rev read_files 仅 common.sh + DESIGN + REQUIREMENT；`fk_resolve_api_credentials` 的调用方 l3-api.sh:37 与 l2-detect.sh:193（实测均同源调用，契约稳定）未入 read_files。
**Source**：L-031（全仓锚点枚举）；R1 盲审（共享函数漏改类缺陷）。
**Consequence**：本次变更封闭在函数内部、调用方无签名/语义变更，无实际漏改风险。
**Remedy**：read_files 加 l3-api.sh + l2-detect.sh 两行（低成本防漂移）。

---

**Checklist 其余项核对结果**（无发现）：
- 依赖无环 ✓（T01→∅ / T02→∅ / T03→{T01,T02} / T04→T03，无环）
- write_files 边界 ✓（T01 common.sh / T02 transcript-parser.sh / T03 打包源 bats / T04 开发源 bats，无越界）
- 禁动合规 ✓（未触碰 package-flow-kit.sh / gate 核心链 / .done 协议 / correction-file.sh 签名 / 其余禁动条目）
- AC 覆盖 ✓（AC-2→T03 矩阵 ≥3；AC-4b→T02+T03 ≥2；AC-6→T03 两 bats + T04 verify 双断言；AC-1/3/4/5/7 由既有 29 用例保留 + T04 全量回归；AC-8→T04；AC-9 pipeline 级不在 TASK 范围）
- L-031 跨阶段 ✓（delta 实际改文件 = common.sh / transcript-parser.sh / 4 bats，与 TASK 声称一致；30-ai-analyze.sh 残留 ANTHROPIC 直读属 DESIGN §6 已登记例外）
- 粒度 ✓（T03-rev 最重 ~7 新用例，≤200 行边界内；T04-rev 全机械步骤）
- 机器可执行：T03/T04 verify ✓（bats 二进制实测存在；`-z "$output"` 断言已修 R-F-A1 陷阱；扫描范围不含审查报告已修 R-F-A2）；T01 verify ✗（R2）

**Verdict**: **fail**（🔴 R1：TASK 归类路径与 REQUIREMENT 矛盾 + 自证式实测闭环，执行前必须定稿 `state.input.category`；🟡 R2 的 T01 verify 按字面不可执行，须一并改写）

---

## 主 agent 响应（修订版 fix loop）

### 🔴 R1 → Fixed
TASK.md 3 处修订：
- T02-rev action L49-50：归类表达式 `.input.category // .args.category` → `state.input.category // .args.category`（与 AC-4/AC-4b + DESIGN D4 + §9.3 统一）
- T02-rev verify L54：mock `{"input":{"category":...}}` → `{"state":{"input":{"category":...}}}`
- T03-rev mock L83：同上同步改 `state.input.category`，注释改为「jq 路径定稿 `state.input.category`——与 AC-4 mock + AC-4b + D4 + §9.3 一致，IR-3 R-1 修复」
- 执行说明 L141：「以 bats 实测为准」改为「已定稿 `state.input.category`」

**验证**：grep `.input.category`（不含 state）全 TASK.md 零残留；`state.input.category` 命中 4 处（T02 action×2 + T02 verify mock + T03 mock）。

### 🟡 R2 → Fixed（round 2 · set +e 补丁）
TASK.md T01-rev verify L31 再次重写：每个子 shell 加 `set +e`（防 common.sh L6 `set -euo pipefail` 在 rc=1 时杀子 shell）+ scenes 2/3 FAIL 分支加 `exit 1`（防 `echo FAIL` 返回 0 的假绿）。

**实测**（cd flow-kit-bundle && bash -c '...'）：
- scene 1：`rc=1`（全 unset → 无凭证，函数正常返回 rc=1，`echo "rc=$?"` 执行成功）✅
- scene 2：`opencode-path3 OK`（FLOW_KIT_L3_AUTH_TOKEN=t + FLOW_KIT_L3_BASE_URL=u + OPENCODE=1 → Path3 命中，FK_API_BASE_URL=u）✅
- scene 3：`opencode-path1-fallback OK`（ANTHROPIC_AUTH_TOKEN=t + OPENCODE=1 + 无 Path3 → Path1 兜底，FK_API_AUTH_SCHEME=bearer）✅
- exit code = 0 ✅

**round 1 残留修复说明**：round 1 subshell pattern `(unset ...; fk_resolve_api_credentials; echo "rc=$?")` 在 `set -euo pipefail` 下当函数返回 rc=1（全 unset 场景）时子 shell 在函数调用处即死，`echo "rc=$?"` 永不执行（L2 round 2 实测确认）。round 2 加 `set +e` 在子 shell 内禁用 errexit，函数正常返回后 echo 执行。

### 🟡 R2 → ~~Fixed~~（round 1 已被 round 2 取代，见上）

### L2 复核 round 3（ses_022b45a79ffe3bDKpJ5bCEPYXC · 20s）
**Verdict: pass** — R2 round-3 fix 确认：三子 shell 全有 `set +e`（unset 后、函数前）+ scenes 2/3 FAIL 分支 `{ echo "..."; exit 1; }`（非假绿）；R1 `state.input.category` + R3 `=[A-Za-z0-9+/]` 零回归。
TASK.md T01-rev verify L31 重写为子 shell：
```
bash -c 'source hooks/stop/lib/common.sh; (unset ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY FLOW_KIT_L3_AUTH_TOKEN FLOW_KIT_L3_BASE_URL OPENCODE OPENCODE_BIN; fk_resolve_api_credentials; echo "rc=$?"); (unset ... OPENCODE OPENCODE_BIN; FLOW_KIT_L3_AUTH_TOKEN=t FLOW_KIT_L3_BASE_URL=u OPENCODE=1 fk_resolve_api_credentials; test "$?" -eq 0 -a "$FK_API_BASE_URL" = "u" && echo "opencode-path3 OK" || echo "opencode-path3 FAIL"); (unset FLOW_KIT_L3_AUTH_TOKEN OPENCODE OPENCODE_BIN; ANTHROPIC_AUTH_TOKEN=t OPENCODE=1 fk_resolve_api_credentials; test "$?" -eq 0 -a "$FK_API_AUTH_SCHEME" = "bearer" && echo "opencode-path1-fallback OK" || echo "FAIL")'
```
三场景全用 `(unset ...; fk_resolve_api_credentials)` 子 shell（env 不参与），场景 2/3 加 `test` 断言（不靠人眼 echo）。

**验证**：grep `env -u.*fk_resolve` 全 TASK.md 零残留。

### 🟡 R3 → Fixed
TASK.md 3 处（L85/L113/L120）base64 模式加 `=` 前缀：
`[A-Za-z0-9+/]{32,}={0,2}` → `=[A-Za-z0-9+/]{32,}={0,2}`
与 `=sk-` 分支同构（均需 `=` 前缀）。commit_sha 40-hex 在 JSON 中以 `": "b8cda56"` 形式存储（值前为 `"` 非 `=`），不命中。执行说明 L142 补 IR-3 R-3 修复说明。

**验证**：grep `A-Za-z0-9+/.*{32` 命中 4 行（3 行模式 + 1 行注释），全部含 `=[A-Za-z0-9+/]` 前缀。

### 🟢 R4 → Deferred（MINOR-DEFERRED M21）
CC 分支 `.args.category //` 优先 vs AC-4b 文字「按 subagent_type 归类」措辞不一致。行为等价（真实 CC Agent args 无 category 字段），既有测试已钉。v2 对齐措辞。

### 🟢 R5 → Deferred（MINOR-DEFERRED M22）
TASK.md「17+7」实测 17+12。数值陈旧，不影响执行。

### 🟢 R6 → Deferred（MINOR-DEFERRED M23）
T01-rev read_files 未列 l3-api.sh/l2-detect.sh 两调用方。本次变更封闭在函数内部无漏改风险，L-031 强化建议。
