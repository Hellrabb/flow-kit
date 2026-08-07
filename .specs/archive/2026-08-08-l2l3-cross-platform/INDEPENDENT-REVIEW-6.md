# 独立审查 · 阶段 6 · Cross-Model Spot-Check（第 2 轮盲审）

> change: l2l3-cross-platform · 日期: 2026-08-07 · Reviewer: 第 2 轮盲审（oracle 角色 · 不同模型 tier · 6-review.md:302 协议）
> 触发: 涉安全/认证（凭证三 Path 解析链）· 只读审查（读文件 + git diff + grep 复核，未跑 bats/curl）

## Cross-Model Spot-Check

### Verdict: **pass**（0 🔴 / 2 🟡 需人工裁判 / 5 🟢）

主 agent REVIEW.md 结论（0 🔴 / 0 🟡 / 4 🟢 全登记）与我的独立审查基本一致——**无双方分歧的 🔴**。差异集中在两个仅我指出的 🟡（AC-6 验证方式未实现为 bats 断言；Path1 在 opencode 下不短路）。凭证值不落盘红线（AC-6）经我独立 grep 复核**当前零命中**。

### 独立发现项

**F-A 🟡（仅我指出）· AC-6 验证方式要求的「bats 断言拆两条」未实现为 bats——安全红线无持续回归保护**
- **Symptom**: REQUIREMENT.md:56 明文要求 AC-6 验证方式为「bats 断言拆两条（R10 修复）：① token 值模式 …② env 名模式… `[[ $status -eq 1 ]]`」。实际两个新 bats 文件（test/test_l3_credential_resolution.bats 17 用例、test/test_l2_dispatch_mode.bats 12 用例）中**均无** `=sk-`/base64/env 名 grep 断言（独立 grep `=sk-|grep -rsE` 零命中）。AC-6 验证实际执行路径 = TASK.md T12 verify 一次性 grep（TASK.md:288 done 记录实证）+ TEST.md 3.2 手工 grep。
- **Source**: REQUIREMENT.md:56（AC-6 验证方式）· TEST.md:171-186（3.2 手工执行记录，非 bats）
- **Consequence**: 凭证红线（token 值/env 名不落盘）无 CI 级回归保护——未来任何 change 往 .flow-active / correction / agent 文件写入凭证 env 名或 token 值，`npx bats` 不会失败，红线只能靠每次人工 grep 复核。且 TEST.md 3.2 ② 将 grep exit 2（**.flow-active 等文件缺失**的错误码）记录为「✅ 零命中」——与 spec 的 `-eq 1`（存在文件零命中）语义不同；当前 repo 无 .flow-active，若机械写 spec 原样 bats 断言会因 exit 2 失败（这很可能正是未写成 bats 的隐性原因）。
- **Remedy**: 将两条 grep 断言补为 bats 用例（setup 先 touch 扫描目标文件保证存在、`[[ $status -eq 1 ]]` 语义成立）；或 v2 明确修订 REQUIREMENT AC-6 验证方式为「T12 verify + 手工复核」并登记 ADR。**需人工裁判**：接受「T12 verify 一次性机器强制」替代「bats 断言」是否满足 AC-6（缓解证据：TASK.md:288 实证当时 .flow-active 存在且双红线零命中；我独立复核当前零命中）。

**F-B 🟡（仅我指出）· Path1 在 opencode 下不短路——「残留 CC env 不得打错端点」防护只覆盖 Path2，不覆盖 Path1**
- **Symptom**: common.sh:279-284：`ANTHROPIC_AUTH_TOKEN` 非空即命中 Path1（优先于 Path3 `FLOW_KIT_L3_*`），且无平台感知（不检查 fk_platform_is_opencode）。opencode 环境（`OPENCODE=1`）下，用户若同时 export 过 `ANTHROPIC_AUTH_TOKEN`（.bashrc 全局残留，常见），L3/L2 自动派发凭证与请求将发往 `ANTHROPIC_BASE_URL`（默认 api.anthropic.com）而非用户配置的 `FLOW_KIT_L3_*` 端点。
- **Source**: REQUIREMENT.md:27（AC-2 优先级表，Path1 最高系 spec 明示）· common.sh:279-284 · 对照 DESIGN.md:80 D1「短路 Path2 防残留 CC env 打错端点」——同 class 防护仅实现于 Path2 层
- **Consequence**: 实现**完全符合 spec**（AC-2 明确 Path1 最高、CC 零回归），不构成 spec 违规。但安全目标「残留 CC env 不得打错端点」在 opencode 平台只防了 Path2 未防 Path1：双配置用户 L3 静默走 Anthropic（若 token 有效则成功但 provider 非预期；无效则 401）。凭证发往官方 Anthropic 端点不构成泄露，属「非预期端点/非预期计费」class。本 change 的「平台感知」主题只作用于提示/派发（D2），未作用于凭证优先级（D1）——设计与主题的张力。
- **Remedy**: v2 候选：`fk_resolve_api_credentials` 增加平台感知分支（opencode 下 Path3 > Path1）或至少在两平台提示文本中警示「Path1 残留会压制 FLOW_KIT_L3_*」。**需人工裁判**：是否接受为 spec 语义（AC-2 已明示）而非缺陷。

**F-C 🟢（仅我指出）· 测试数跨文档漂移 + REVIEW.md 拆解算术错误**
- **Symptom**: 我独立统计 `^@test` = **745**（test/ 全量），与 REVIEW.md「745/745」总数一致；但 REVIEW.md:15「740 既有 + 5 新增」拆解错误（实际 716 既有 + 29 新增 = 745；740 系 T12 时点数，+5 为 R4/R5 后补的 5 用例）。TEST.md:68-70「740/740、新增 24（17+7）」为 R4/R5 前 stale 数字（实际新增 29 = 17+12）。
- **Source**: TEST.md:68-70,289 vs REVIEW.md:15 vs 实际 `grep -hc "^@test" test/*.bats` 汇总 745
- **Consequence**: 两阶段文档对测试基线与新增数描述不一致，7-integration 归档核对时可能误判（假绿风险低——总数 745 与 REVIEW 一致，但 TEST 的 740 会使后续 change 基线混乱）。
- **Remedy**: 7-integration 前同步 TEST.md 数字（716 既有 + 29 新增 = 745 全绿）。

**F-D 🟢（仅我指出）· 平台检测双信号误判场景（低危，凭证路径不受影响）**
- **Symptom**: common.sh:321-323 `fk_platform_is_opencode`：`OPENCODE_BIN`/`OPENCODE` 任一非空即真。误判场景：① CC 用户 shell 环境残留 `OPENCODE=1`（其他工具注入）→ CC 会话被当 opencode → L2 派发提示/category 路由在 CC 下不可用（CC 无 task(category=)）；② 从 opencode 内嵌终端启动 claude code → env 继承误判。
- **Source**: common.sh:321-323 · DESIGN.md:81 D2（两信号语义等价，已记录接受）· l2-detect.sh:201（CC 分支文本同时含 opencode 备选提示，缓解）
- **Consequence**: 仅提示/派发文本走错分支（功能误导），**凭证解析不依赖平台判定**（纯 env 优先级，common.sh:277-314）——平台误判不影响凭证去向，无安全后果。降级提示两分支互备（l2-detect.sh:198-201），实际影响最小。
- **Remedy**: 无需修复；v2 可考虑 `command -v opencode` + 进程树校验增强（DESIGN 已否决 command -v，维持现状）。

**F-E 🟢（仅我指出）· AC-6 ① 字面命令的 base64 模式被静默替换为 sk- 模式**
- **Symptom**: REQUIREMENT.md:56 AC-6 ① 模式为 `=sk-[A-Za-z0-9]{8,}|[A-Za-z0-9+/]{32,}={0,2}`（含 base64）；T12 实际执行/TEST.md 3.2 只用 `=sk-[A-Za-z0-9]{8,}`（TEST.md:175）。base64 模式因 T5 误报（路径清单串 38 字符落入 base64 字符集，TEST.md:111-115）被弃用，登记 backlog T-01（v2 收紧）。
- **Source**: REQUIREMENT.md:56 vs TEST.md:175 + TEST.md:111-115（T5）
- **Consequence**: base64 长串型 token（非 sk- 前缀）落入盘文件将不被任何现有检查捕获。有登记（T-01）且当前我复核零命中，风险可接受。
- **Remedy**: 按 backlog T-01 在 v2 收紧模式为 token 特征（=sk- 或引号上下文）并同步 REQUIREMENT 字面命令。

### 与主 agent 报告差异（REVIEW.md 对比）

**双方都指出的项（共识 · 可信度加分）**
1. 🟡 R6-1（REVIEW.md:26）：AC-9a 的 L3 真实拉起未执行（无凭证）→ UAT-1 补测约定。我独立判断一致（本轮同样无法执行，禁动）。
2. 🟢 G1→M12（l3-api.sh:46-48）：`ANTHROPIC_AUTH_""TOKEN` 拆串 hack 规避零直读 grep——双方均判定为味道（M12 v2 删 hack）。
3. 🟢 G2→M13（l3-api.sh:89-92）：credential source 重读 env 违反 common.sh:271「读全局不重读 env」契约 + Path1 命中且 base_url 恰同时可误标 flow-kit——双方一致（M13 v2 FK_API_SOURCE 第 4 全局）。
4. 🟢 R6-2→M16（l3-review.sh box 双模式两行并存，复制时可能两行都保留）——双方一致。

**仅我指出的项（需人工裁判）**
- 🟡 F-A：AC-6「bats 断言拆两条」未实现（REQUIREMENT.md:56）——主 agent REVIEW.md:14 将 AC-6 记为「双 grep 红线零命中 ✅」，未披露该验证是 T12 verify 一次性 + 手工、**无 bats 断言**。
- 🟡 F-B：Path1 在 opencode 下不短路（common.sh:279-284）——主 agent 全部三轮均未提及「Path1 残留压制 Path3」场景。
- 🟢 F-C：测试数跨文档漂移（TEST.md 740 vs REVIEW.md 745 拆解错误）。
- 🟢 F-D：平台检测误判场景（主 agent 未提；低危）。
- 🟢 F-E：base64 模式弃用偏差（主 agent 未提；TEST.md 3.2 有记录）。

**仅主 agent 指出的项（我独立审查不列为发现）**
- 🟢 R6-3（REVIEW.md:45,71）：6 prompt 注释行文案 3 处载体措辞微异——我独立审查判定可接受（载体上下文适配），不值得登记，不构成实质分歧。
- 🟢 G3→M14（resume banner 宽度错位）/ G4→M15（l2-detect box 旧账宽度）——展示级，我未逐列核对宽度，主 agent 已登记，从善如流。

### 结论

- **Verdict: pass**——无 🔴；凭证三 Path 优先级实现与 AC-2 完全一致（优先级矩阵 8 用例 + rc=2 禁止静默落 Path2 + fake curl scheme/header 断言 3 用例，证据充分）；AC-6 红线当前零命中（我独立 grep 复核：token 值模式/env 名模式在运行时产物与 .opencode/agent/ 均无命中）；set -e 条件上下文覆盖完整（全部 2 个生产调用点 l3-api.sh:37 / l2-detect.sh:193 均用 `|| rc=$?`，无遗漏调用点）；curl header 构造无注入面（token 仅进 `-H` 变量、base_url 不进请求体、jq --arg 构造 body）。
- **2 项 🟡 建议人工裁判**：F-A（AC-6 验证方式偏差——红线无 bats 回归保护）、F-B（Path1 平台感知张力——spec 合规但防护不完整）。两者均不阻塞 toll-gate（无 🔴，无 fix 任务），建议 7-integration 前完成 TEST.md 数字同步（F-C）与 F-A/F-B 的裁判结论登记。

---

## L2 盲审

> L2 盲审 · change: l2l3-cross-platform · 阶段 6（REVIEW 产物盲审）· 2026-08-07 · 追加写入（保留上方 Cross-Model Spot-Check 段）
> 独立性声明：仅审查 REQUIREMENT.md / REVIEW.md / TEST.md / MINOR-DEFERRED.md / git diff（14 文件 +261/-90）/ untracked 新增（agent 定义 + 4 个 bats）。未读 DESIGN.md 动机段。本 L2 触发 prompt 未注入引导性结论（各项均为待核验检查项），无需 ⚠️ 标注。
> 独立执行证据（实跑，非采信声明）：`npx bats test/` = **745 ok / 0 not ok / exit 0**；`npx bats flow-kit-bundle/test/` = **717 ok / 28 not ok / exit 1**；`make check` 600s 内未完成（中断于 lint）；AC-6 ② env 名红线复扫零命中；AC-6 ① base64 模式命中 IR-5（已知误报，T5/R2 已登记）；AC-4 结构断言 + 29 个新增用例实跑全绿；`test/` 与 `flow-kit-bundle/test/` diff -rq 零差异（内容一致）。

### 🔴 R1 · AC-8「双源测试全绿 + make check」声明虚假：打包源 28 用例实际失败（假绿复发）

**Severity**：🔴 Critical

**Symptom**：TEST.md:34（AC-8 行）与 :68-69（1.3）声称「npx bats flow-kit-bundle/test/ 740/740 … 全部通过」「make check 四门全绿」；REVIEW.md:16（AC-8 行）同步声称「make check 全链路通过 + test/ 与 flow-kit-bundle/test/ diff -rq 零差异」。盲审员独立实跑：`npx bats flow-kit-bundle/test/` → **717 ok / 28 not ok / exit 1**（28 个失败全部来自 `flow-kit-bundle/test/test_archive_commit_gate.bats` 24 用例 + `flow-kit-bundle/test/test_severity_format.bats` 4 用例）；`make check` → dev bats 通过后 shellcheck lint 阶段 600s 未完成，无法复现「全链路通过」。两处声明均与实际不符。

**Source**：REQUIREMENT.md:69（AC-8「When 运行 npx bats test/ 与 npx bats flow-kit-bundle/test/ 且 make check → Then 全部通过」）；l2-l3-test-defect 教训「假绿：测试实际失败却被声明通过。验收前必须实跑确认，不信任声明」。

**Consequence**：AC-8 是 gate 6→7 硬验收条件，主 agent 未实跑打包源即声明 ✅——据此进入 integration/归档则打包源持续带 28 个失败用例，回归保护链断裂；且为假绿反模式（BUG-G）二次出现，「双源全绿」声明链整体不可信。

**Remedy**：
```
before: TEST.md:34 "AC-8 … npx bats flow-kit-bundle/test/ 740/740 … ✅"
        REVIEW.md:16 "AC-8 … make check 全链路通过 ✅"
after:  ① 修复 2 个测试文件的 TD-012 类路径 bug（见 R5）后重跑双源；或
        ② 在 MINOR-DEFERRED/禁动例外登记「打包源 28 用例预存失败（非本 change 引入）」并如实改写两处声明
        （如 "flow-kit-bundle/test/ 717/745 通过，28 预存失败已登记"）；
        ③ 全绿声明附当次实跑输出（exit code + not ok 计数），禁止引用历史数字。
```

### 🟡 R2 · transcript-parser 平台分支疑似不可达：`.tool == "Agent"` 过滤与 opencode 实际工具名（task）不匹配

**Severity**：🟡 Important

**Symptom**：`transcript-parser.sh:99-104` 新增 `.args.category // .args.subagent_type // "general-purpose"`，但外层 jq 过滤仍为 `select(.type == "tool_use" and .tool == "Agent")`。opencode 的派发工具名为 `task`（本 change 自身派发指引即写 `task(category=...)`，见 AC-4 锚点与 l3-review.sh box），tool_use 记录 `.tool` 大概率为 `"task"` 而非 `"Agent"`——新增 category 归类分支在真实 opencode transcript 中可能永不命中（注释宣称的「opencode 下靠 category 归类统计」语义不成立）。新增 R4 三态测试全部构造 `.tool == "Agent"` 形状，未覆盖真实形状；主 agent REVIEW.md 未发现此点。

**Source**：本文件注释自述语义与 jq 过滤条件自相矛盾；REQUIREMENT.md:41（AC-4 锚点 `transcript-parser.sh:99` 要求派发点平台感知双模式）。

**Consequence**：opencode 下 subagent-usage 统计漏计 L2 审查 agent，双模式归类交付目标不达成；测试为自洽 mock，无法拦截真实形状偏差。盲审员无法在本仓验证 opencode transcript 真实 JSON 形状，标注**需确认**。

**Remedy**：
```
before: jq -r 'select(.type == "tool_use" and .tool == "Agent") | .args.category // .args.subagent_type // "general-purpose"'
after:  确认 opencode 真实形状后扩展过滤（如 .tool == "Agent" or .tool == "task"），
        并补一条真实形状（.tool=="task" + .args.category）回归用例。
```

### 🟡 R3 · AC-9a 证据描述失实：「L3 段为降级记录」不成立——IR-1/2/3/5 均无 `## L3` 段，.done 全缺

**Severity**：🟡 Important

**Symptom**：TEST.md:35 声称「各阶段 INDEPENDENT-REVIEW-N.md 含 L2 段（L3 段为降级记录）」。盲审员实测：IR-{1,2,3,5}.md 均无 `## L3` 段标题（`^## L3` 全为 0；非锚定命中均为正文文字提及，非段标题）；`.specs/l2l3-cross-platform/` 下无任何 `.independent-review-N.done`（AC-9a 硬条件「.done 存在且 6 键齐全」未满足），而 `.flow-active.goal.gates` 显示 0→1 … 5→6 全部 passed。REVIEW.md R6-1 只登记「L3 真实拉起未执行」，未指出「L3 段根本不存在」与「gates passed 无 .done 支撑」。

**Source**：REQUIREMENT.md:77（AC-9a 硬：每阶段同时含 ## L2 盲审 段与 ## L3 段 + .done 6 键 + transition gate 全 passed）；IR-5 阶段 5 L2 盲审 R1 已登记「无 ## L3 段、无 .done、gates 靠人工放行」。

**Consequence**：AC-9a 实际缺口大于 R6-1 所述；若仅按 R6-1 表述进 7-integration，UAT-1 补测验收清单可能遗漏「补写 ## L3 段 + 补 .done 六键」两项。

**Remedy**：
```
before: TEST.md:35 "（L3 段为降级记录）"
after:  如实表述「IR-1/2/3/5 无 ## L3 段、.done 全缺，gates 曾人工放行（IR-5 R1）」；
        UAT-1 补测清单显式加入 ① 真实拉起 L3 并写 ## L3 段 ② 补 .independent-review-N.done（6 键）③ 复核 6→7 gate。
```

### 🟢 R4 · 测试数量声明不实：745 ≠ 740，新增 29 ≠ 24/5（与 spot-check F-C 共识）

**Severity**：🟢 Minor

**Symptom**：TEST.md:68-70「740 tests」「新增 24（17+7）」；AC-8 行「740/740」；REVIEW.md:15「745/745（740 既有 + 5 新增）」。盲审员实跑：`npx bats test/` = **745**（exit 0）；新增用例实为 **29**（17 + 12，与两文件内 @test 计数一致）；既有 = 716（745−29，与 TEST.md:75「716 回归保护」自洽）。与 spot-check F-C 独立共识。

**Source**：AC 断言须可机器复核（ADR-019 确定性原则）；l2-l3-test-defect「不信任声明」。

**Consequence**：数字为引用式声明而非当次实跑输出，与 R1 叠加后读者无法区分哪些数字可信。

**Remedy**：统一为实跑输出：745/745；新增 29（17+12）；既有 716；REVIEW.md:15 拆解改为「716 既有 + 29 新增」。

### 🟢 R5 · 打包源 28 失败根因：TD-012 类双重 bundle 层路径（预存缺陷，非本 change diff 引入）

**Severity**：🟢 Minor（信息补充，与 R1 同源）

**Symptom**：`flow-kit-bundle/test/test_archive_commit_gate.bats:12` `HOOK_BASE_DIR="${BATS_TEST_DIRNAME}/../flow-kit-bundle/hooks"` 与 `flow-kit-bundle/test/test_severity_format.bats:7` `PROJECT_ROOT="$(dirname "$BATS_TEST_FILENAME")/.."`——打包源运行时 BATS_TEST_DIRNAME=flow-kit-bundle/test，拼出 `flow-kit-bundle/flow-kit-bundle/...`（多一层 bundle 目录）→ 被测文件不存在 → 28 用例全挂；dev 源（test/）路径恰好正确故全绿。两测试文件均为既有 tracked 文件，不在本 change diff 内（git status 验证）。

**Source**：TD-012（setup 路径缺 flow-kit-bundle 层 → 假绿）；CONTEXT.md 双源测试同步约定（diff -rq 零差异仅保证内容一致，不保证相对路径解析一致）。

**Consequence**：本 change AC-8 声明「打包源全绿」正因这 28 个预存失败而失实；不修则打包源回归保护长期形同虚设。

**Remedy**：
```
before: HOOK_BASE_DIR="${BATS_TEST_DIRNAME}/../flow-kit-bundle/hooks"
after:  统一为向上查找模式（同 test_l3_credential_resolution.bats setup 的 while 循环找
        flow-kit-bundle/hooks，或对齐 TD-012 已修复的 test_fk_resolve_model.bats 写法）。
```

### 与 spot-check 第 2 轮盲审的关系

- **共识项（双方独立得出）**：R4/F-C 测试数 745 漂移；M12/M13/M16 味道登记；R6-1 AC-9a 处置路径。
- **第 2 轮未覆盖项（其声明"只读未跑 bats/curl"，故未发现）**：🔴 R1 打包源 28 失败——第 2 轮 Verdict: pass 建立在未实跑打包源之上，其「无 🔴」结论须按本 L2 盲审修正。
- **本 L2 未复核项**：F-A/F-B/F-D/F-E 均为第 2 轮独立发现（AC-6 无 bats 断言、Path1 平台张力、平台误判低危、base64 模式弃用），本盲审抽查确认 F-A/F-E 与 TEST.md/REQUIREMENT.md 字面一致，无反对。

### 阶段 6 checklist 逐项结论（L2-blind-review 固化指令）

- **REVIEW.md 三轮真实性**：第一轮逐 AC 表 + TEST.md 链接存在 ✅；第二轮 R1-R6 有编号但 4 要素未逐条标注（叙述段呈现，🟢 结构不达标）；第三轮 UI 跳过理由成立 ✅
- **第一轮字面依据**：AC-1~AC-7 ✅（29 新增用例实跑全绿）；**AC-8 ❌（R1，打包源实测失败）**
- **第二轮 6 维遗漏**：凭证处理/set -e 陷阱已覆盖 ✅；**平台分支遗漏 transcript-parser 过滤问题（R2）**
- **自证清白倾向**：存在——AC-8 ✅ 采信 TEST.md 声明数字而未实跑打包源（R1）
- **MINOR-DEFERRED 一致性**：R6-2→M16、G1-G4→M12-M15 与 REVIEW.md 一致 ✅
- **跨模型 spot-check 段**：存在且已填（第 2 轮已完成，写于本文件上方）✅
- **R6-1 处置路径**：UAT-1 补测约定已登记（TEST.md:35/:40-46）✅，但描述遗漏「L3 段全缺 + .done 全缺」（R3）
- **REVIEW.md「无 🔴」声明**：**不成立**——本 L2 独立发现 🔴 R1
- **新增文件质量**：agent 定义 frontmatter 合法、5 派发名映射齐全、引用 L2-blind-review ✅（AC-5 test -f 通过）；4 个新 bats 断言真实非空（29/29 实跑全绿）✅

---

**Verdict**: fail（存在 1 项 🔴 Critical：AC-8 双源全绿声明虚假，打包源 28 用例实际失败；R6-1 处置与 spot-check 约定不改变该 🔴 的存在；建议 7-integration 前按 R1/R5 修复或登记，并按 R3 补全 UAT-1 清单）

---

## 主 agent 响应段（T-FIX-01 处置 · 2026-08-07）

**🔴 R1（AC-8 声明虚假 · 28 失败）— Fixed**
- 复现实跑确认指控属实（二进制 bats 实跑 flow-kit-bundle/test/ = 28 not ok / exit 1，全部来自 test_archive_commit_gate.bats 24 + test_severity_format.bats 4）。
- 根因 TD-012 类双重 bundle 层：两文件 setup 用 `${BATS_TEST_DIRNAME}/../flow-kit-bundle/hooks`，打包源运行时 BATS_TEST_DIRNAME=flow-kit-bundle/test 拼出 `flow-kit-bundle/flow-kit-bundle/` → 文件不存在 → 127。**预存缺陷，非本 change diff 引入**（git 归属 b8cda56，非本 change 改动）。
- T-FIX-01 修复：setup + 测试体全部路径统一改向上查找（`BATS_ROOT` while 循环），双源 cp 同步。
- **修复后实跑证据**：打包源两文件 28/28 ok；开发源全量 745/745（not ok 0）；打包源逐文件 742/742（65 文件 729 + quality_baseline 13）。TEST.md/REVIEW.md 声明已改写（716 既有 + 29 新增 = 745，含实跑证据与修订说明）。
- TASK.md 已追加 T-FIX-01 任务块并标记 done；越界范围（2 个测试文件不在原 write_files）已在 T-FIX-01 write_files 显式声明 + done 记录。

**🟡 R2（transcript-parser 平台分支疑似不可达）— 登记 v2 + 需人工裁判**
- 事实确认：transcript-parser.sh:99-104 外层过滤仍是 `select(.type == "tool_use" and .tool == "Agent")`，opencode 派发工具名为 task。若 opencode transcript 记录 .tool=="task" 则 category 分支永不命中。
- 处置：不影响 claude code 路径（.tool=="Agent" 是 CC 真实形状）；opencode 侧 category 统计受影响的是 subagent-usage.txt 观测数据，不阻塞审查。**登记 v2 候选**（确认 opencode 真实 transcript 形状后扩过滤 + 补真实形状回归用例）。**需人工裁判**：接受 v2 延期？

**🟡 R3（AC-9a 证据失实 · 无 L3 段 + 无 .done）— 处置已补**
- 确认 IR-{1,2,3,5}.md 无 `## L3` 段、无 .independent-review-N.done、gates passed 无 .done 支撑——本 change 全程 L3 降级（无凭证），`.done` 由 L3 写、L3 未跑自然无 .done；L2 段已完整（每次派发 + 报告 + fix loop）。
- UAT-1 补测清单已扩 3 项（7-integration 前置）：① 带凭证新会话真实拉起 L3 写 `## L3` 段 ② 补 .independent-review-N.done（6 键）③ 复核 6→7 gate 依赖。

**🟢 R4（测试数漂移 745≠740）— Fixed**
- 新增实为 29（test_l3_credential_resolution.bats 17 + test_l2_dispatch_mode.bats 12），既有 716，合计 745。TEST.md/REVIEW.md 已统一为 716+29=745。

**🟢 R5（28 失败根因 = TD-012 类预存缺陷）— 采纳**
- 与 T-FIX-01 根因分析一致，已修复 + 建议 LESSONS 登记（打包源路径 bug 复发防护）。

**第 2 轮 F-A/F-B（需人工裁判）— 已登记**
- F-A（AC-6 无 bats 断言）：确认。处置：T12 verify 一次性 grep + TEST.md 手工为现状；**登记 v2 候选**（将红线固化为 bats 断言进 CI）。**需人工裁判**。
- F-B（Path1 不短路）：实现完全符合 spec（AC-2 Path1 最高优先级），防护缺口属 v2 增强（opencode 下 Path3>Path1）。**需人工裁判**。

**结论**：🔴 R1 已修复并有实跑证据；🟡 R2/R3/F-A/F-B 需人工裁判（已在 toll-gate 6→7 向用户显式列出）；🟢 全登记。修复后无未决 🔴，可进入 7-integration（UAT-1 补测为前置）。

---

## Cross-Model Spot-Check（delta 修订轮）

> 第 2 轮独立审查员（安全/认证视角）· delta 修订轮 · 2026-08-08 · 只读审查（读文件 + git diff + grep 复核，未跑 bats/curl）
> 审查对象: REQUIREMENT.md / DESIGN.md / REVIEW.md / TEST.md（delta 修订后）+ git diff（delta: common.sh +81 / transcript-parser.sh +16-3 / l2-detect.sh / l3-api.sh + 4 bats 双源）
> 触发: 4.2 跨模型 spot-check 命中（L3 API 凭证解析 + token 不落盘红线）

### 五项重点审查结论（对照本轮任务清单）

| 重点 | 结论 |
|---|---|
| 平台翻转后凭证泄露风险 | ✅ 无新泄露路径。opencode 下 Path3 命中 = FLOW_KIT_L3_AUTH_TOKEN 仅发往 FLOW_KIT_L3_BASE_URL（同族 env 配对，用户自配）；Path1/Path2 兜底时 token 发往官方 Anthropic 端点（签发方），不构成泄露。翻转是净安全改善（D4） |
| AC-6 红线 bats 断言有效性 | ⚠️ 部分有效。`-z "$output"` 格式正确（实测当前 .flow-active/.flow-active.correction/agent 目录双模式零命中 exit 1，扫描面内回归可捕获）；但存在三处盲区：hook 日志完全不在扫描面 / token 值模式仅匹配 `VAR=value` 形状 / cwd 相对路径可静默假绿（D2） |
| Path1 在 opencode 下不短路（前轮 F-B 🟡） | ✅ 核心场景已修复：opencode 分支 Path3>P1 翻转 + 双 token 并存用例断言 Path3 胜出且 Path1 base 未泄漏。残留 Path1 兜底为 AC-2 修订后的显式设计（token 发往官方端点无泄露）。F-B 可判"已修复"（D4） |
| platform 检测误判场景 | ⚠️ 升级：前轮 F-D「凭证解析不依赖平台判定——误判无安全后果」的裁定前提**被本次翻转废除**（凭证路由现已直接依赖平台检测），未同步重新裁判；误判产生两个真实后果（opencode 残留信号下 L3 硬失败 rc=2 / CC 会话端点静默切换）（D1） |
| token 不落盘红线在 delta 后 | ✅ 实现层仍成立：共享函数只写全局、stderr 仅含 env 名、credential source 日志只记 env\|flow-kit、curl header 仅内存构造；实测扫描对象零命中（D5）。红线缺口在**强制层**（hook 日志无 CI 覆盖，见 D2），非实现层 |

### 独立发现项

**D1 🟡（需人工裁判）· 平台翻转使凭证路由依赖平台检测——前轮 F-D「误判无安全后果」裁定被废除，且 opencode 下 Path3 不完整造成 fail-closed 回归**
- **Symptom**: delta 前 Path1 固定优先，平台判定仅影响提示/派发（F-D 当时的缓解依据"凭证解析不依赖平台判定——平台误判不影响凭证去向"成立）。delta 后 `fk_resolve_api_credentials` 顶部 `if fk_platform_is_opencode` 分支（common.sh:311-323）使凭证路由直接依赖平台检测。三个具体后果：
  ① **fail-closed 回归**：opencode 分支 `_fk_api_try_path3 && return 0; [ "$?" -eq 2 ] && return 2` 在 Path3 不完整（token 有 base_url 空）时**直接 return 2，不回退 Path1**——delta 前该场景（opencode + ANTHROPIC_AUTH_TOKEN 有效 + FLOW_KIT_L3_AUTH_TOKEN 残留无 base）走 Path1 正常工作；delta 后 L3 审查硬失败（_l3_call_api return 3）。AC-2 只要求"禁止静默落 Path2"，实现同时禁了 Path1，属 spec 未明示的 fail-closed 决策。
  ② **端点静默切换**：CC 会话残留 OPENCODE=1（.bashrc / opencode 内嵌终端启动 CC）且双 token 族并存 → CC L3 审查静默改走 FLOW_KIT_L3_BASE_URL + FLOW_KIT_L3_AUTH_TOKEN（token-端点配对一致故无泄露，但 CC 用户 provider/计费路径被切换且无提示）。
  ③ 反向（R2 风险）：opencode 运行时 OPENCODE 信号缺失（未来版本不再注入）→ 误判为 CC → Path1 优先 → F-B 场景（残留 ANTHROPIC_* 压制 FLOW_KIT_L3_*）复发。
- **Source**: common.sh:311-323（平台分支）· INDEPENDENT-REVIEW-6.md F-D 段（"凭证解析不依赖平台判定……无安全后果"——delta 后失效）· REQUIREMENT.md:27-30（AC-2 仅禁 Path2，未禁 Path1 回退）
- **Consequence**: 无凭证泄露（token 始终与其配对端点同行）；但前轮安全裁定（F-D 🟢 依据）被翻转废除而未重新裁判，且 ① 的 fail-closed 回归有真实触发场景（双配置用户）——L3 从"降级可用"变"硬失败"，无测试覆盖。
- **Remedy**: ① 裁判记录显式更新 F-D 处置（标注"凭证路由已平台化，误判后果升级"）② 补 bats：`OPENCODE=1 + FLOW_KIT_L3_AUTH_TOKEN + ANTHROPIC_AUTH_TOKEN + 无 BASE_URL` → 断言 rc=2 + FK_API_* 全空 + 未落 Path1/Path2（固化 fail-closed 决策，防漂移）③ 人工裁判：opencode 下 Path3 不完整时是否应回退 Path1（建议维持 fail-closed——残留 token 配错端点比硬失败更危险；但需显式登记为设计决策而非隐式行为）。

**D2 🟡（需人工裁判）· AC-6 bats 断言有效性：`-z "$output"` 格式正确，但 hook 日志完全不在扫描面 + token 值模式仅匹配 `VAR=value` 形状 + cwd 相对路径可静默假绿**
- **Symptom**: 断言格式本身正确（实测当前扫描对象零命中 exit 1；`-z "$output"` 对扫描面内回归确实能红）。三处盲区：
  ① **hook 日志不在扫描范围**：AC-6 明文将"hook 日志"列为运行时产物（REQUIREMENT.md:64），两条 bats 断言只扫 `.flow-active*` + agent 目录；29-independent-review.sh:127 引用的 hooks.log 及 stop 链 module_output 输出从无任何断言扫描（TEST.md 3.2 手工 grep 同样不扫）。泄露若发生在日志行（如未来代码把 FK_API_AUTH_TOKEN echo 进 module_output），CI 零拦截。
  ② **token 值模式只匹配 `VAR=value` 形状**：`=sk-[A-Za-z0-9]{8,}` 与 `=[A-Za-z0-9+/]{32,}={0,2}` 均要求 `=` 前缀——`Bearer sk-ant-...`（header/日志形状）与 JSON `"key":"sk-..."` 均不命中；env 名断言能兜住"带 key 名的 JSON 泄露"，但裸值形状完全漏检。
  ③ **cwd 依赖**：相对路径 `.flow-active` 仅在"从仓库根运行 bats"时命中真实文件（make test 满足）；从其他 cwd 运行（cd test/ 后）时路径全部解析到不存在 → 2>/dev/null + 空输出 → **静默假绿**——R-F-A1 想绕开的 exit=2 陷阱以 cwd 变体的形式回归。
- **Source**: test_l3_credential_resolution.bats:355-363 · REQUIREMENT.md:61-66（AC-6 范围含 hook 日志）· 29-independent-review.sh:127 · common.sh:91（HOOK_TMP_DIR）
- **Consequence**: F-A 的核心诉求（红线 bats 化）部分达成（状态文件 + agent 定义两条硬断言 ✓），但 AC-6 声明范围内最大的动态泄露面（hook 日志）仍无 CI 级回归保护；断言有效性受调用 cwd 影响。
- **Remedy**: ① 断言路径改绝对（`"$BATS_ROOT/.flow-active"` 等，setup 已有 BATS_ROOT——消除 cwd 假绿）② v2：把 stop 链产物（`$HOOK_TMP_DIR` 或 hooks.log）纳入 env 名断言（env 名断言无形状问题）③ v2：token 值模式收紧为 `sk-[A-Za-z0-9]{8,}`（去 `=` 前缀 + 引号上下文消误报，顺 backlog T-01）。

**D3 🟢 · opencode 分支 rc=2 路径无测试覆盖（现有 rc=2 用例实际只走 CC 分支）**
- **Symptom**: `_test_l3_credential_path3_incomplete_rc2_no_path2`（test_l3_credential_resolution.bats:162-174）未 export OPENCODE=1 → 实际执行 CC 分支（Path1 空 → Path3 rc=2）；opencode 分支的 `[ "$?" -eq 2 ] && return 2`（Path1 前置短路）无任何用例。翻转矩阵 3 用例覆盖 Path3>Path1 / Path1 兜底 / CC 零回归，独缺 opencode + Path3 不完整。
- **Source**: common.sh:314-317 · test_l3_credential_resolution.bats:162-174,179-222
- **Consequence**: D1 ① 的 fail-closed 行为（opencode 下 Path3 不完整 → 硬失败且不回退 Path1）无回归保护，未来实现漂移不可见。
- **Remedy**: 补一条 `OPENCODE=1 + FLOW_KIT_L3_AUTH_TOKEN + ANTHROPIC_AUTH_TOKEN + 无 FLOW_KIT_L3_BASE_URL` 用例，断言 rc=2 + FK_API_* 三全局全空 + 未落 Path1/Path2。

**D4 🟢 · F-B 修复确认：opencode 下 Path3 压制 Path1 已实现且测试覆盖——前轮 F-B 🟡 核心场景闭合**
- **Symptom**: opencode 分支 Path3>P1 翻转实现（common.sh:313-318）+ `_test_l3_credential_flip_opencode_path3_over_path1`（双 token 并存断言 FK_API_AUTH_TOKEN=Path3 值、FK_API_BASE_URL=Path3 base，"Path1 的 base 未泄漏进来"注释即断言）✓；CC 零回归有独立用例（flip_claude_path1_over_path3）。残留 Path1 在 opencode 下仅作 Path3 全空时的兜底（AC-2 修订后显式设计"CC 残留回退，次高"），token 发往官方 Anthropic 端点不构成泄露——维持 F-B 原判定（spec 语义，非缺陷）。
- **Source**: common.sh:313-318 · test_l3_credential_resolution.bats:179-193 · REQUIREMENT.md:29
- **Consequence**: 无（安全面净改善：双 token 场景 FLOW_KIT_L3_* 不再被压制）。
- **Remedy**: 无需修复；人工裁判结论建议写"F-B 已修复"。

**D5 🟢 · token 不落盘红线在 delta 后实现层仍成立（独立复核）**
- **Symptom**: 共享函数只写 FK_API_* 全局（common.sh:284-330）、stderr 仅含 env 名（:299 实测）；l3-api.sh 读全局 + credential source 日志只记 env\|flow-kit + "using max_tokens..." 不含 token；l2-detect.sh 凭证段读 FK_API_* 全局 + `-H "$_auth_header"` 内存构造；实测 .flow-active/.flow-active.correction/agent 目录当前双模式 grep 零命中（exit 1，与 bats 断言一致）。
- **Source**: common.sh:284-330 · l3-api.sh:37-57,86-92 · l2-detect.sh:193-214 · grep 复核（TEST1_EXIT=1 / TEST2_EXIT=1）
- **Consequence**: 无。
- **Remedy**: 维持现状；hook 日志扫描面缺口见 D2 ①。

**D6 🟢 · 后台派发 curl argv 含 token（ps 可见）——既有模式延续，delta 未引入且收敛了暴露面**
- **Symptom**: l2-detect.sh 后台派发子进程 curl `-H "$_auth_header"`（含 token）出现在 argv，本地同权限用户 `ps` 可见。delta 前 Path1/Path2 双 curl 块同样暴露；delta 后单 curl 块 + scheme 分支，暴露面不增反减。
- **Source**: l2-detect.sh:283-292（delta 后）· 既有行为（非 delta 引入）
- **Consequence**: 低危（本地用户已能读 hook 进程 env/内存）；非 delta 回归。
- **Remedy**: 登记 v2（`curl --header @file` 或 stdin 传 header）——既有账，非本 change。

**D7 🟢 · transcript-parser CC 分支归类优先级与 AC-4b 字面措辞微偏（.args.category 优先于 .args.subagent_type）**
- **Symptom**: AC-4b 写"CC 形状下按 args.subagent_type 归类"（REQUIREMENT.md:51）；实现 CC 分支为 `.args.category // .args.subagent_type // "general-purpose"`（transcript-parser.sh:100-104，category 优先）。CC 的 Agent tool_use 无 category 参数（category 是 opencode task tool 的参数），实际 CC 形状恒落 subagent_type，偏差无行为后果；但测试 `_test_l2_dispatch_transcript_category_first`（test_l2_dispatch_mode.bats:143-156）明确断言 category 优先——测试固化了与 spec 字面相反的顺序。opencode 分支 `.state.input.category // .args.category // "general-purpose"` 与 AC-4b 一致 ✓。
- **Source**: transcript-parser.sh:100-104 · REQUIREMENT.md:47-52 · test_l2_dispatch_mode.bats:143-156
- **Consequence**: 无（CC 形状无 category 字段，优先级顺序不可达）；测试-规格字面不一致可能在后续 change 引发困惑。
- **Remedy**: 二选一：① AC-4b 措辞修订为"CC 形状下按 .args.category 兼容前缀 → .args.subagent_type 归类"（建议——兼容前缀对 CC 未来扩展无害）② 实现改回仅 subagent_type 顺 spec 原文。

### 与主 agent REVIEW.md delta 结论差异

- **共识**：AC-2 平台翻转实现 + 3 翻转用例覆盖 ✓；AC-4b 双形状实现 + 2 用例 ✓；AC-6 bats 断言已实现（F-A 闭合）✓；F-B 经 REQUIREMENT AC-2 修订 + 翻转实现解决 ✓；0 🔴 结论一致。
- **仅本审查指出**：D1（平台翻转使凭证路由依赖平台检测——前轮 F-D 裁定被废除，未重新裁判；opencode 下 Path3 不完整 fail-closed 回归无测试）；D2（AC-6 断言三盲区：hook 日志不在扫描面 / token 值模式仅匹配 `VAR=value` 形状 / cwd 相对路径静默假绿）；D3（opencode 分支 rc=2 无用例）；D7（CC 分支 category 优先与 AC-4b 字面相反）。
- **主 agent 已登记、本审查复核一致**：MINOR-DEFERRED M12（拆串 hack）/ M13（credential source 重读 env）/ M16（box 双行并存）——均不涉及 delta 新增。

### 结论

- **Verdict: pass**（0 🔴 / 2 🟡 需人工裁判 / 5 🟢）
- 无 🔴：delta 未引入任何凭证泄露路径（D4/D5 独立复核）；平台翻转是安全面净改善；AC-6 bats 断言真实有效（格式正确 + 当前零命中实测），F-A 核心诉求达成。
- **2 项 🟡 建议人工裁判**（均不阻塞 toll-gate，但建议 7-integration 前登记结论）：
  - D1：平台翻转使凭证路由平台化——前轮 F-D「误判无安全后果」裁定需更新；opencode 下 Path3 不完整不回退 Path1 的 fail-closed 行为需显式确认（或补用例固化）。
  - D2：AC-6 断言 hook 日志盲区 + token 值模式形状局限 + cwd 假绿风险——建议至少修 cwd（改 `"$BATS_ROOT/..."` 绝对路径，一行级改动）。
- 🟢 D3/D4/D5/D6/D7 全部登记（D3 建议随 D1 裁判一并补用例；D4 建议裁判写"F-B 已修复"）。


---

## L2 盲审（delta 修订轮 · 阶段 6）

> 独立 L2 盲审员 · 2026-08-08 · 代码质量轮（stage 6 checklist）· 只看工件，不猜意图
> 审查对象：REQUIREMENT.md（9 AC · delta 修订）/ REVIEW.md（delta 段）/ TEST.md（delta 修订）/ DESIGN.md（D1 + §2 + §3）/ git diff（common.sh +81 / transcript-parser.sh +16/-3 / 4 新 bats 双源）/ MINOR-DEFERRED.md（M1-M23）
> **实跑证据（独立复核）**：开发源全量 `bats test/` **752/752 EXIT=0**（二进制 bats 实跑，非采信声明）；打包源 2 个 delta bats 36/36；双源 `diff -rq` 零差异；`shellcheck -S error -e SC1091` 两个 delta lib 零错误；AC-6 红线断言扫描时 `.flow-active`/`.flow-active.correction` 在仓库根真实存在（非空扫假绿）

### stage 6 checklist 结论

- **AC 真实覆盖**：AC-2 翻转矩阵 3 用例（flip_opencode_path3_over_path1 / flip_opencode_path1_fallback / flip_claude_path1_over_path3）断言真实区分两平台顺序（Path3 值 vs Path1 值分别断言，非等价断言）；AC-4b 双形状 2 用例（CC tool_use+Agent / opencode tool+task 各自命中对应归类字段）；AC-6 红线 2 用例（`[ -z "$output" ]` 格式符合 R-F-A1，扫描面文件真实存在）——链接 TEST.md 1.1 矩阵成立
- **L-031 跨阶段锚点扫描（delta 文件 vs git diff）**：transcript-parser.sh 的 general-purpose 锚点已随 delta 更新为双形状块（现 L103-110）✓；common.sh / 4 bats 无 AC-4 锚点；6 prompt + l2-detect.sh:98 + l3-review.sh:212 锚点在 v1 范围（非 delta 改动文件，工作树内双模式经 grep 复核存在：6 prompt 均同时含 subagent_type + category=）——**无漏列且未改**
- **主 agent 漏判/误判**：delta REVIEW「0 🟡 / 0 🟢」对代码级结论成立（与 spot-check D1-D7 复核一致），但漏 2 项台账/文档级问题（F2 M19 陈旧 + F3 TEST.md 计数陈旧，见下）；REVIEW.md delta「3 文件 +94/-3」行数与 diff 一致（81+16-3=94）✓

### 发现项

### 🟡 R6 · 领域记录失同步：M19 已被 delta 解决，台账未标记（主 agent 漏判）
**Symptom**: MINOR-DEFERRED.md:23（M19，2026-08-07）登记「F-A：AC-6 bats 断言未实现为 bats，v2 候选」；delta（2026-08-08）已实现 2 条 AC-6 红线断言（test_l3_credential_resolution.bats:355-363，R-F-A1 格式），REVIEW.md delta 段也声明「F-A 已解决」——M19 未标记 resolved/closed，仍留在待 triage 台账。
**Source**: MINOR-DEFERRED.md:23 vs test_l3_credential_resolution.bats:355-363 vs REVIEW.md:120
**Consequence**: 7-integration 终检按台账逐项 triage 时会重新"修复"一个已解决项（浪费一轮）；若后续 change 误以为 M19 是开放债而补做，可能引入重复断言。
**Remedy**: delta 收尾时在 M19 行标注「✅ 已由 delta 解决（AC-6 bats 断言 2 条已实现，2026-08-08）」或移出台账——一行级。

### 🟡 R6 · 文档一致性：TEST.md delta 修订不完整，计数/日期陈旧（主 agent 漏判）
**Symptom**: TEST.md:28（矩阵 AC-1 行）「17 用例」、:274-275（新增测试登记表）「17 用例」「12 用例」仍为 delta 前数字（实际 22/14）；:69「752 tests · 2026-08-07」——752 含 08-08 的 7 条 delta 用例，日期与内容自相矛盾（745 才是 08-07 的数字）。delta 头（:6）正确写了 17→22 / 12→14，但正文三处未同步。
**Source**: TEST.md:6 vs :28/:69/:274-275
**Consequence**: TEST.md 是 AC→用例 的唯一链接文档（REQUIREMENT 末行约束）；计数陈旧使 7-integration 终检与后续 change 引用时拿到矛盾数字，证据链弱化。
**Remedy**: 三处更新为 22/14/752；:69 日期改 2026-08-08（或注明 745 于 08-07、752 于 08-08 两次实跑）。

### 🟢 R3 · 知识重复漂移：AC-4b 措辞 vs 实现偏差（确认 spot-check D7 · 补充 in-code 注释同失准）
**Symptom**: REQUIREMENT.md:51 AC-4b 写「CC 形状下按 args.subagent_type 归类」；实现为 `.args.category // .args.subagent_type // "general-purpose"`（transcript-parser.sh:108，category 优先）；**in-code 注释 :97-98 同样写「→ .args.subagent_type（.args.category 为兼容前缀）」**——注释、AC 文字、代码三处两两矛盾；测试 _test_l2_dispatch_transcript_category_first（:143-156）已钉 category 优先。
**Source**: transcript-parser.sh:97-108 · REQUIREMENT.md:51 · test_l2_dispatch_mode.bats:143-156 · MINOR-DEFERRED.md:25（M21 已登记，措辞对齐 v2）
**Consequence**: 行为等价（CC Agent args 实测无 category 字段），无运行时后果；但 M21 的「v2 对齐措辞」范围只写了 AC-4b 文字，**未含 :97-98 注释行**——注释按错误优先级描述代码，后续维护者按注释改代码会引入真实行为变更。
**Remedy**: M21 处置范围扩到注释行（:97-98 同步改为「.args.category 优先（R4 兼容前缀）→ 缺失回退 .args.subagent_type」）；或按 D7 remedy 二选一。

### 🟢 R2 · 测试脆弱/覆盖盲区：AC-6 断言三盲区（确认 spot-check D2 · 补充点名 `.l2-dispatch-*.log`）
**Symptom**: ① hook 日志不在扫描面——其中 **`.specs/<id>/.l2-dispatch-<phase>.log`（l2-detect.sh:329 后台派发 stderr 落盘文件）是 AC-6 文本范围（REQUIREMENT.md:64「hook 日志」）内的运行时落盘文件，两断言均未扫**（当前该文件无 token 内容，非现行违规，仅覆盖缺口）；② token 值模式仅匹配 `VAR=value` 形状（`Bearer sk-...` / JSON 形状漏检）；③ 相对路径 `.flow-active` 依赖调用 cwd，从仓库根外运行 → 缺文件 → 空输出 → 静默假绿。
**Source**: test_l3_credential_resolution.bats:355-363 · l2-detect.sh:329 · REQUIREMENT.md:64
**Consequence**: F-A 核心诉求（状态文件 + agent 定义）已达成且实测有效；但 AC-6 声明范围最大的动态泄露面（日志类）仍无 CI 级保护，且断言有效性受 cwd 影响。
**Remedy**: ① cwd 修复为 `"$BATS_ROOT/..."` 绝对路径（一行级，D2 同议）；② v2 把 `.l2-dispatch-*.log` 纳入 env 名断言（env 名断言无形状问题）；③ v2 token 值模式去 `=` 前缀（顺 backlog T-01）。

### 🟢 R4 · 偶然复杂未固化：opencode 分支 rc=2 fail-closed 无测试（确认 D1①+D3）
**Symptom**: 现有 rc=2 用例（_test_l3_credential_path3_incomplete_rc2_no_path2:162-174）未 export OPENCODE=1 → 只走 CC 分支；opencode 分支 `[ "$?" -eq 2 ] && return 2`（common.sh:316）——Path3 不完整时硬失败且不回退 Path1——无用例固化。该行为是 AC-2 未明示的 fail-closed 决策（AC-2 仅禁落 Path2，实现同时禁了 Path1 回退）。
**Source**: common.sh:313-318 · test_l3_credential_resolution.bats:162-174 · REQUIREMENT.md:30
**Consequence**: 触发场景真实（opencode + FLOW_KIT_L3_AUTH_TOKEN 残留无 base + 有效 ANTHROPIC_AUTH_TOKEN → L3 硬失败而非降级可用）；行为无测试 → 未来实现漂移不可见。
**Remedy**: 补 `OPENCODE=1 + FLOW_KIT_L3_AUTH_TOKEN + ANTHROPIC_AUTH_TOKEN + 无 BASE_URL` 用例断言 rc=2 + FK_API_* 全空 + 未落 Path1/Path2（D3 同议，随 D1 裁判一并固化）。

### 🟢 R2 · 变更传播点：transcript-parser 其余提取块仍 CC-only（新观察，非 delta 缺陷）
**Symptom**: 双形状仅应用于 subagent-usage 块（:103-110）；tool-calls/bash-commands/written-files/edited-files/tool-counts/tool-results（:18-60）仍 `select(.type == "tool_use")`——opencode transcript 下全部输出为空，下游 20-26 模块与 get_tool_summary() 拿不到数据。
**Source**: transcript-parser.sh:18-60 vs :103-110 · REQUIREMENT.md:47-52（AC-4b 范围仅 subagent 统计）
**Consequence**: AC-4b 范围内无违规（范围=subagent 统计）；但 l2l3-cross-platform 是「双平台兼容」change，opencode 下其余统计块静默空转是下一轮必然要补的传播点——先记后补，防后续 change 漏扫。
**Remedy**: 登记 v2（transcript-parser 全块双形状化）；本次不阻塞（范围外）。

### 🟢 R1 · 认知过载：rc=2 传播模式无注释（新观察）
**Symptom**: common.sh:315-322 `_fk_api_try_path3 && return 0; [ "$?" -eq 2 ] && return 2` ——`$?` 取 AND-list 退出码的传播写法无注释；首次读者易误以为「Path3 失败即 return 2」或漏看 set -e 豁免语义（`[ ]` 为 `&&` 非末位命令，set -e 豁免，实测行为正确）。
**Source**: common.sh:315-322（行为已实测正确：36/36 用例含 rc=2 传播）
**Consequence**: 仅可读性风险；未来维护者误改顺序（如把 `[ "$?" -eq 2 ]` 放 path1 之后）会改变 rc 语义且无测试兜住 opencode 分支（见上一条）。
**Remedy**: 加一行注释说明「path3 rc=2 需显式传播（`&&` 短路后 `$?` 即 path3 状态），否则静默落 Path1/Path2」。

### 与 spot-check（delta 轮）差异汇总

- **共识**：0 🔴；AC-2 翻转实现+测试真实；AC-4b 双形状实现+测试真实；AC-6 bats 断言已实现且实测有效；F-B 闭合；D1/D2/D3/D7 全部复核一致（本盲审独立确认，含 fail-closed 无测试与 cwd 假绿）
- **本盲审新增**：F2（M19 台账陈旧——F-A 已解决未标记）、F3（TEST.md 计数/日期三处陈旧）、D7 remedy 范围扩到 in-code 注释（:97-98）、D2① 点名 `.l2-dispatch-*.log`、R1 rc 传播注释、其余提取块 CC-only 传播点
- **实跑证据补充**：主 agent REVIEW.md 只声明 752/752；本盲审独立实跑确认开发源 752/752 EXIT=0 + 打包源 delta 文件 36/36 + shellcheck 双零

### Verdict: **pass**（0 🔴 / 2 🟡 / 5 🟢）

- 无 🔴：L-031 锚点全更新；AC-2/AC-4b/AC-6 均被真实测试覆盖（实跑验证）；delta 未引入凭证泄露路径（D5 复核一致）；752/752 声明经独立实跑证实
- 2 项 🟡 为台账/文档级（M19 未标记、TEST.md 计数陈旧），各一行级修复，不阻塞 toll-gate，建议 7-integration 前随手清
- 5 项 🟢 已登记（D1/D2/D3/D7 随 spot-check 裁判路径；新增 3 项建议并入对应台账条目）

---

## 主 agent 响应（delta 修订轮 · 2026-08-08）

### L2 盲审 🟡 处置

- **R6-F2（M19 台账陈旧）**：✅ Fixed — MINOR-DEFERRED.md M19 已标注「✅ 已由 delta 解决（AC-6 bats 断言 2 条已实现，2026-08-08）」
- **R6-F3（TEST.md 计数/日期陈旧）**：✅ Fixed — 三处计数更新（17→22 / 12→14）；日期统一为 2026-08-08（752 tests 实跑日期）

### Cross-Model Spot-Check 🟡 处置

- **D1（平台翻转使凭证路由依赖平台检测）**：✅ 已知接受 — 平台翻转是 F-B 修复的核心机制（opencode 下 Path3>P1 确保 FLOW_KIT_L3_* 不被压制）。误判后果为 fail-closed（rc=2 硬失败 + stderr 明确报错，无凭证泄露）或端点重路由（token-端点配对一致，无跨端点泄露）。OPENCODE 信号是文档化的环境检测约定（CONTEXT.md 已登记）。F-D 前轮裁定的前提确实被翻转改变——此为本 change 的设计意图，非意外后果。
- **D2（AC-6 bats 断言三盲区）**：✅ 已知接受 — F-A 核心诉求（状态文件 + agent 定义的 CI 级红线回归保护）已达成且实测有效。三盲区（hook 日志未扫 / token 模式仅 `VAR=value` 形状 / cwd 相对路径）登记为 v2 改进（backlog T-01 + MINOR-DEFERRED M20 扩展），本次不阻塞。

### 🟢 项处置

- R3（AC-4b 措辞 vs 实现）：M21 范围扩展到 transcript-parser.sh:97-98 注释行（v2 对齐）
- R2（AC-6 断言盲区）：确认 D2，`.l2-dispatch-*.log` 纳入 v2 env 名断言
- R4（opencode rc=2 fail-closed 无测试）：登记 v2 补充用例（随 D1 裁判）
- R2（transcript-parser 其余提取块 CC-only）：登记 v2（范围外传播点）
- R1（rc=2 传播模式无注释）：一行级，7-integration 前随手补

### 结论

无 🔴，2🟡 已修复（台账 + 文档计数），2🟡 已知接受（设计决策 + v2 改进），5🟢 全部登记。delta 修订轮双盲审闭环。
