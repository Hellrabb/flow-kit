# 独立审查 · 阶段 1

> L2 盲审 · 盲审员独立执行 · 工件：REQUIREMENT.md（参考 CHANGE.md）· 2026-08-06

## L2 盲审

**Verdict**: fail（2 🔴 Critical）

---

### 🔴 R1 · AC-3 与 AC-6 直接矛盾 + AC-6 验证命令结构性失效：凭证红线可能假绿或与降级提示互斥

**Severity**：🔴 Critical
**Symptom（症状）**：
- REQUIREMENT.md AC-3 Then 要求降级提示**必须包含**字面串 `export FLOW_KIT_L3_BASE_URL + FLOW_KIT_L3_AUTH_TOKEN`；
- 同文件 AC-6 Then 要求「`.flow-active` 与任何 correction 文件内容」**不含** `BASE_URL` / `AUTH_TOKEN`。`FLOW_KIT_L3_BASE_URL` 与 `FLOW_KIT_L3_AUTH_TOKEN` 两个名字本身即匹配 `grep -E "AUTH_TOKEN|BASE_URL"`（子串命中）。
- 降级路径的既有载体就是 correction 文件（`correction-file.sh:104` 写 message、`l3-review.sh:60` echo 提示），AC-3 的 When 明确把「写 model-missing correction」列为提示出现位置 → 提示入 correction 即违反 AC-6，不入则 AC-3 的「提示信息」落点未定义。
- AC-6 验证命令 `grep -rE "AUTH_TOKEN|BASE_URL" .flow-active .specs/<id>/ --include="*.json"`：`--include="*.json"` 同样作用于命令行显式文件（GNU grep 语义），`.flow-active` 不匹配 `*.json` → **该文件从未被搜索**；真正的 correction 文件 `.flow-active.correction`（项目根、JSON、CONTEXT.md 登记）不在命令范围内 → AC-6 的 Then 范围（.flow-active + correction）有 2/3 未被验证。

**Source（源头）**：AC-3 vs AC-6 同文档自相矛盾；AC 可机器验证性（ADR-019 原则①「AC 必须确定性」）；AC-6 验证命令与既有 correction 文件约定（CONTEXT.md · `.flow-active.correction` 统一矫正文件 JSON 不入库）脱节。
**Consequence（后果）**：TEST 阶段按 AC-3 实现（提示入 correction）→ AC-6 bats 断言失败；按 AC-6 实现（correction 不含 env 名）→ AC-3 提示落点悬空、验证方式只能靠 grep 假绿。安全红线（凭证不落盘）的真实检查面（correction 文件）从未被测试覆盖 → 凭证泄露风险静默通过。
**Remedy（修补）**：REQUIREMENT 层三处必改：
1. AC-3 明确提示载体 = hook stderr/stdout + resume banner，**排除 correction message 字段**（或规定 correction message 只写 `FLOW_KIT_L3_* 未配置` 不写全名）；
2. AC-6 验证命令改为 `grep -rE "FLOW_KIT_L3_AUTH_TOKEN|FLOW_KIT_L3_BASE_URL|=sk-[A-Za-z0-9]" .flow-active .flow-active.correction .flow-active.interactive-ui-fix .specs/<id>/`（覆盖 correction + 去掉 `*.json` include 对 `.flow-active` 的误杀）；
3. 加一条 AC 显式声明「降级提示文本可含 env 变量名，但任何落盘文件不得含 env 名或 token 值」。

---

### 🔴 R2 · L-031 漏列：subagent_type 派发锚点全仓 ≥9 处，AC-4/AC-5 只覆盖 2 处 → opencode 下 prompt 路径 L2 派发仍挂起，AC-9 无法达成

**Severity**：🔴 Critical
**Symptom（症状）**：本 change 的跨文件一致性锚点是 subagent_type 派发模板与平台感知派发。全仓 grep 命中：
- `1-requirement.md:85`（qa-expert）· `2-design.md:239`（architect-reviewer）· `3-task.md:194`（architect-reviewer）· `5-test.md:52`（qa-expert）· `6-review.md:105`（code-reviewer）+ `:302`（oracle）· `7-integration.md:55`（architect-reviewer）· `l3-review.sh:212`（general-purpose）· `transcript-parser.sh:99`（general-purpose）· `l2-detect.sh:98`（`${agent_type}` 变量模板）
- REQUIREMENT v1 只覆盖 `l2-detect.sh` 派发指引生成段（AC-4）+ 分发包新增 **1 个** opencode reviewer agent 文件（AC-5）。prompt 层 6 个文件 8 处硬编码 `subagent_type: <名称>` **零提及**——既不在 v1 也不在 out 范围。
- AC-5 的验证是 `test -f flow-kit-bundle/.opencode/agent/<file>`（单文件），而实际派发名有 **5 种**（qa-expert / architect-reviewer / code-reviewer / oracle / general-purpose）。opencode 的 agent 定义无别名机制，1 个文件只覆盖 1 个名字。

**Source（源头）**：L-031 教训（跨文件批量修改点必须全仓枚举，不信单文件清单）；本 change 自身前提「opencode 下 subagent_type 路由挂起（agent=undefined）」；AC-9 承诺「每个开启阶段 L2+L3 双审有真实 .done 证据」。
**Consequence（后果）**：opencode 用户的主 agent 按 prompt 模板（6-review.md:105 等）派发 `subagent_type: code-reviewer` → 未定义 agent → 挂起/失败 → L2 审查静默缺失，且发生在本 change 声称修复的全部阶段（1/2/3/5/6/7）。AC-9 的 L2 腿在 prompt 驱动路径下**按现有范围不可达成**，pipeline 跑完也是假双层。
**Remedy（修补）**：REQUIREMENT 层补三选一（必须显式写死）：
1. 分发包新增 **5 个** agent 定义（qa-expert / architect-reviewer / code-reviewer / oracle / general-purpose，prompt 均引用 L2-blind-review）并列为 AC-5 验证文件清单（`test -f` 逐文件）；或
2. 将 6 个 prompt 的独立 review 调度段改为平台感知双模式（opencode → `task(category=...)`），并把 6 个 prompt 文件列入 v1 范围；或
3. 明确声明 prompt 层派发在 opencode 下走 l2-detect.sh 生成模板、5 个名字由 AC-5 全部覆盖。任一方案都必须把 9 处锚点写入范围清单（L-031）。

---

### 🟡 R3 · 平台检测信号与既有实现冲突：AC-3/AC-4 用 `OPENCODE=1`，既有代码锚点是 `OPENCODE_BIN`

**Severity**：🟡 Important
**Symptom（症状）**：AC-3/AC-4 的 Given 均写 `OPENCODE=1`；`l2-detect.sh:170-180` 既有平台判定用 `OPENCODE_BIN`（注释：「OPENCODE_BIN 是 opencode 运行时显式注入的 env（可靠信号）；不用 command -v opencode」）。全仓 `OPENCODE=1` 零命中。REQUIREMENT 依赖与假设声称「opencode 环境通过 OPENCODE=1 可识别（当前实测成立）」但未引证，也未与既有 OPENCODE_BIN 分支调和。
**Source（源头）**：L-031 锚点一致性；既有实现注释（l2-detect.sh:170-174）记载的设计决策；禁动清单「l2-detect.sh 为 L2 检测唯一入口」。
**Consequence（后果）**：若按 AC 实现 `OPENCODE=1` 分支而与既有 `OPENCODE_BIN` 分支并存 → 同一文件两套平台判定，运行时设置哪个变量决定走哪条路，行为分裂；若运行时实际只注入 OPENCODE_BIN，AC-3 的提示差异化永不触发 → AC-3 bats 测试全绿但生产失效（假绿）。
**Remedy（修补）**：REQUIREMENT 明确检测信号与既有锚点调和——统一为 `OPENCODE_BIN`（既有可靠信号）或并列声明「OPENCODE=1 与 OPENCODE_BIN 等价信号，任一命中即 opencode」，并把两处（l2-detect.sh:180 + 新增检测点）列入同步清单。

---

### 🟡 R4 · AC-7/AC-8 回归锚点事实错误：test_model_degradation.bats 实际 3 个用例，非 25

**Severity**：🟡 Important
**Symptom（症状）**：AC-7「既有 test_model_degradation.bats 25 用例全绿」、AC-8「含既有 25 个 L2/L3 相关用例无回归」。实测 `test/test_model_degradation.bats` 仅 3 个 @test（L33/43/54），`test_fk_resolve_model.bats` 10 个（CHANGE.md 影响面点名的另一锚点文件）。「25」在 test/ 下无对应物。
**Source（源头）**：AC 可机器验证性（ADR-019 原则①）；回归基线必须指向真实存在、可数清的用例集。
**Consequence（后果）**：TEST 阶段按「25 用例」核对时找不到目标 → 回归门要么被数字对不上卡住，要么被随便凑数放行 → 回归覆盖承诺失真。
**Remedy（修补）**：把 AC-7/AC-8 回归锚点改为可枚举集：「test_model_degradation.bats（3 用例）+ test_fk_resolve_model.bats（10 用例）全绿」，或给出 25 的真实出处（若指多文件合集，列出文件清单）。

---

### 🟡 R5 · AC-1/AC-2 未定义与 Path 2（ANTHROPIC_API_KEY legacy 路径）的优先级交互

**Severity**：🟡 Important
**Symptom（症状）**：`l3-api.sh:84-97` 存在 Path 2：`ANTHROPIC_API_KEY` 非空时用 **硬编码 `https://api.anthropic.com`**（忽略 base_url）+ `x-api-key` 头。AC-1/AC-2 只规定 `ANTHROPIC_BASE_URL/AUTH_TOKEN` vs `FLOW_KIT_L3_*` 的优先级，未规定 `FLOW_KIT_L3_AUTH_TOKEN` 与 legacy `ANTHROPIC_API_KEY` 并存时的行为。实测路径：opencode 用户 export 了 FLOW_KIT_L3_*，但 shell 残留 CC 时代的 `ANTHROPIC_API_KEY` → Path 1 空、Path 2 命中 → 请求打到 api.anthropic.com 且用错凭证。
**Source（源头）**：l3-api.sh 既有凭证链结构（Path 1/2）；CHANGE.md「向后兼容：ANTHROPIC_* 优先顺序保持」未覆盖 Path 2。
**Consequence（后果）**：opencode 下 L3 请求打到错误 endpoint → 401/404 → return 3 → 降级为空，AC-9 的「L3 真实拉起」在常见残留 env 场景下静默失败。
**Remedy（修补）**：AC 补充优先级表：`FLOW_KIT_L3_BASE_URL/AUTH_TOKEN` 生效时 **短路 Path 2**（或声明 Path 2 仅当全部新凭证为空时触发），并把 l3-api.sh Path 1/2 判定纳入 test_l3_credential_resolution.bats 用例矩阵。

---

### 🟡 R6 · 禁动清单冲突：AC-8 要求改 package-flow-kit.sh，未登记例外

**Severity**：🟡 Important
**Symptom（症状）**：AC-8「新 agent 定义文件在 Part A~F 覆盖范围内」+ v1 范围「package-flow-kit.sh（打包覆盖）」→ 必须修改 `package-flow-kit.sh` 打包段。CONTEXT.md 禁动清单：package-flow-kit.sh 仅 superpowers-v6-absorb 有一次性例外（Part D scripts/），本 change 未登记任何例外。
**Source（源头）**：CONTEXT.md 禁动清单 + 例外先例（superpowers-v6-absorb 登记方式）。
**Consequence（后果）**：4-dev 阶段主 agent 撞禁动 → 被拦或违规顺手改打包脚本 → 打包段意外破坏分发（L-012 打包完整性校验正是为此设的防线）。
**Remedy（修补）**：REQUIREMENT 或 DESIGN 阶段显式登记例外（仿 superpowers-v6-absorb：指明可改的 Part 段与新增 .opencode/ 覆盖点），并同步更新 CONTEXT.md 禁动清单。

---

### 🟢 R7 · AC-5 验证含未解析占位符 `<file>` + 「或等价目录」hedge

**Severity**：🟢 Minor
**Symptom（症状）**：AC-5 验证方式 `test -f flow-kit-bundle/.opencode/agent/<file>` 的 `<file>` 未定值；Then 含「（或等价 opencode 配置目录）」双重 hedge。R2 修复后该占位符必须落地为具体文件名清单。
**Source（源头）**：ADR-019 原则①「AC 必须确定性」。
**Consequence（后果）**：验证命令无法原样执行，需 TEST 阶段临场解释 → 断言漂移风险。
**Remedy（修补）**：随 R2 方案一并把 `<file>` 替换为具体文件名（如 `l2-reviewer.md`）。

---

### 🟢 R8 · AC-9 硬/软条件未拆

**Severity**：🟢 Minor
**Symptom（症状）**：AC-9 把「INDEPENDENT-REVIEW-N.md 含 L2+L3 段」（可确定性检查）与「.independent-review-N.done 真实产出（written_by 非 main-agent 伪造）」（软证据）混为一条 Then。
**Source（源头）**：ADR-019 原则①「条件 AC 拆 hard+soft」。
**Consequence（后果）**：TEST 阶段对 AC-9 的通过判定口径不一。
**Remedy（修补）**：拆两条：AC-9a 硬（文件存在 + grep L2/L3 段 + done 键齐全），AC-9b 软（written_by 审计，人工确认）。

---

### L-031 锚点扫描汇总

| 锚点 | 命中文件 | 本 change 覆盖 | 判定 |
|---|---|---|---|
| `subagent_type` 派发模板 | 1/2/3/5/6(×2)/7 prompts + l3-review.sh:212 + transcript-parser.sh:99 + l2-detect.sh:98（9 文件 10 处） | 仅 l2-detect.sh + 1 agent 文件 | 🔴 漏列（R2） |
| `ANTHROPIC_AUTH_TOKEN/BASE_URL`（L3 凭证） | l3-api.sh:20-21,69 · l3-review.sh:19-20 · l2-detect.sh:175,229 · 29:78 · resume:130 · correction-file.sh:104 · common.sh:243 · 30-ai-analyze.sh:96-97 | 仅 l3-api.sh（依赖清单）+ l2-detect.sh | 🟡 漏列：30-ai-analyze.sh 未声明 in/out |
| `OPENCODE` 平台信号 | 既有：l2-detect.sh:180（OPENCODE_BIN）；新 AC：OPENCODE=1（0 命中） | 未调和 | 🟡 R3 |
| `l3_review_run` return 3 | l3-review.sh:61（真实） | AC-3/AC-7 引用 | ✓ 锚点真实 |
| `_l3_call_api` | l3-api.sh:18（真实） | AC-1/AC-2 引用 | ✓ 锚点真实 |
| `fk_resolve_model` | common.sh:255（真实） | AC-7 引用 | ✓ 锚点真实 |
| 降级提示锚点 | l3-review.sh:60 · 29:78 · resume:130 · correction-file.sh:104 · l2-detect.sh:184（5 处） | 未枚举 | 🟡 漏列（并入 R1/R3 处理） |
| `test_model_degradation.bats` | 3 @test | AC-7 声称 25 | 🟡 R4 |
| `.opencode/agent/` | 分发包/仓库均不存在（新建） | AC-5 | 🟢 R7 |

---

**Verdict**: fail（2 🔴 Critical — R1 AC 矛盾+验证失效、R2 L-031 派发锚点漏列；5 🟡、2 🟢 见上）

---

## 主 agent 响应（L2 fix loop · 2026-08-06）

> 以下为对每条发现的处置。盲审原文保持不动。所有修订已落到 `.specs/l2l3-cross-platform/REQUIREMENT.md`。

| Finding | 处置 | 行动 |
|---|---|---|
| 🔴 R1 | **Fixed in:** REQUIREMENT.md AC-3 + AC-6 | AC-3 新增「载体边界」：提示文本可含 env 变量名（stderr/stdout/banner），correction message 只写 `FLOW_KIT_L3_* 未配置`；AC-6 验证命令重写：无 `--include` 过滤，显式覆盖 `.flow-active` / `.flow-active.correction` / `.flow-active.interactive-ui-fix` / `.specs/<id>/`，断言不含 4 个 env 完整名 + token 值模式；「提示可含 env 名、落盘文件一律不含」已写入 AC-6 Then |
| 🔴 R2 | **Fixed in:** REQUIREMENT.md AC-4 + AC-5 + v1 范围 | 9 文件 10 处派发锚点全量枚举进 AC-4 L-031 锚点清单；6 个 prompt 调度段 + l3-review.sh:212 + transcript-parser.sh:99 + l2-detect.sh:98 全部列入 v1 范围平台感知双模式；AC-5 落地具体文件名 `.opencode/agent/flow-kit-l2-reviewer.md` + 5 种派发名映射说明（remedy 方案 2 为主，agent 文件作增强） |
| 🟡 R3 | **Fixed in:** REQUIREMENT.md AC-3/AC-4 Given + v1 + 假设 | 平台信号统一为新增 `fk_platform_is_opencode()`（`OPENCODE_BIN` + `OPENCODE` 任一非空即真，覆盖 l2-detect.sh:175 既有锚点 + 本 change 实测 `OPENCODE=1`）；l2-detect.sh 既有 OPENCODE_BIN 分支统一改调此函数（列入 v1） |
| 🟡 R4 | **Fixed in:** REQUIREMENT.md AC-7/AC-8 | 回归锚点改为可枚举三文件合集：test_model_degradation.bats（3）+ test_fk_resolve_model.bats（10）+ test_independent_review_model.bats（12）= 25 用例，逐文件列名，不再引用无出处数字 |
| 🟡 R5 | **Fixed in:** REQUIREMENT.md AC-1/AC-2 | AC-2 新增完整优先级表：Path1 ANTHROPIC_AUTH_TOKEN+BASE_URL > Path3 FLOW_KIT_L3_* > Path2 ANTHROPIC_API_KEY（legacy 兜底仅当 Path1/3 全空）；`FLOW_KIT_L3_*` 生效短路 Path2（残留 CC env 不打错端点）；bats 优先级矩阵用例覆盖 Path1>Path3>Path2 全组合 |
| 🟡 R6 | **Fixed in:** REQUIREMENT.md AC-8 + v1 范围 | AC-8 增「禁动例外」行：改 package-flow-kit.sh 打包清单段前须在 DESIGN 阶段按 superpowers-v6-absorb 先例登记例外到 CONTEXT.md 禁动清单（指明可改 Part 段），未登记不得动手 |
| 🟢 R7 | **Fixed in:** REQUIREMENT.md AC-5 | `<file>` 占位符落地为 `flow-kit-l2-reviewer.md`，「或等价目录」hedge 删除。已登记 MINOR-DEFERRED.md（M1） |
| 🟢 R8 | **Fixed in:** REQUIREMENT.md AC-9 | 拆 AC-9a（硬：grep 可确定性检查 L2/L3 段 + done 6 键齐全 + gates passed）/ AC-9b（软：written_by 审计人工确认）。已登记 MINOR-DEFERRED.md（M2） |

**复核请求**: 请盲审员复核修订后的 `.specs/l2l3-cross-platform/REQUIREMENT.md`，确认 R1/R2 已闭环。

### 主 agent 响应 · 第 2 轮（R9/R10 处置 · 2026-08-06）

> L2 复核结论：**Verdict pass**（R1-R8 全部闭环，无未闭环 🔴）。复核发现 2 个新 🟡，已按 fix loop 立即修复：

| Finding | 处置 | 行动 |
|---|---|---|
| 🟡 R9 | **Fixed in:** REQUIREMENT.md AC-4 验证方式 | `grep subagent_type 确认无残留` 与「claude code 保持 subagent_type 回归」矛盾 → 改为结构断言：6 个 prompt 中 `subagent_type` 命中的每个文件必须同时含 `category=` 或平台判定标记（双模式共存判定） |
| 🟡 R10 | **Fixed in:** REQUIREMENT.md AC-6 验证方式 | grep 显式参数对不存在的 correction 文件 exit 2 假失败 → 加 `-s` + bats 内 `[[ $status -eq 1 ]]` 零命中断言；base64 模式补 `[A-Za-z0-9+/]{32,}={0,2}` 进 grep 与 Then 对齐 |

### L2 复核结论（盲审员第 2 轮输出 · 归档）

R1 ✅ / R2 ✅ / R3 ✅（🟢 注 l2-detect.sh:180 而非 :175，无行为影响）/ R4 ✅（25=3+10+12 实证）/ R5 ✅ / R6 ✅ / R7 ✅ / R8 ✅ → **Verdict: pass**（R9/R10 已由主 agent 修复，未阻塞 toll-gate）。

### L3 降级记录（用户放行注记 · 2026-08-06）

- **原因**：当前 opencode 会话进程未注入 L3 凭证（`FLOW_KIT_L3_BASE_URL` / `FLOW_KIT_L3_AUTH_TOKEN` 未 export；hook 子进程继承启动 env，会话内无法补充）。
- **影响**：Phase 1 无 L3 外部模型审查段；Stop hook 29 预期写 `model-missing` correction（优雅降级，不阻塞）。
- **用户决策**：toll-gate 1→2 选择「继续，L3 降级记录在案」——接受降级，transition 人工放行。
- **补验承诺**：v1 代码落地后，L3 真实拉起按 AC-9 在凭证可用会话做端到端验收（或由单元测试 test_l3_credential_resolution.bats 覆盖凭证解析链）。
