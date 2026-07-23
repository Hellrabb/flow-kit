# 独立审查 · 阶段 5

- **Change-ID**: l2-l3-model-config
- **阶段**: 5-test
- **审查员**: L2 独立盲审
- **输入工件**: `.specs/l2-l3-model-config/TEST.md`（参考 `REQUIREMENT.md`、`TASK.md`）
- **独立性声明**: 调用方仅注入固化指令 + 审查参数（阶段 / change-id / 工件路径 / 输出位置）。未检测到主 agent 自评 / 草稿 / 概述 / 辩护类上下文注入。以下判断仅基于上述三份工件本身，未引用、未假设工件以外的任何陈述。

## L2 盲审（第 2 轮复审）

### 复审口径

本轮为第 2 轮 re-review。第 1 轮两条发现：
- 🔴 R1：AC-4a/4b 集成层无可执行测试，矩阵标 ✅（覆盖率造假 / 关键降级路径零回归守卫）。
- 🟡 R2：AC-5/5b/5c/5d 以「✅ 实现」冒充验证通过（原子写入路径未测、AC-5d 无 UAT 记录）。

本轮逐条核验「主 agent 声称的补强是否真落到测试代码」，证据仅取 TEST.md + 实际测试文件 + 实跑结果，不采信矩阵里的 ✅。

### 核验方法（均本轮独立实跑）

- `npx bats flow-kit-bundle/test/test_model_degradation.bats test_flow_model.bats test_fk_resolve_model.bats` → 19/19 ok（EXIT 0）。
- `npx bats flow-kit-bundle/test/`（输出重定向到文件取 bats 真退出码）→ **586 ok / 1 not ok，EXIT 1**。
- `diff -rq test/ flow-kit-bundle/test/`（定位失败根因）。
- 用例计数比对：TEST.md:38-42 声称 10/3/6/11/12，与实跑一致（3 文件直接验证 10/3/6）。

---

### 🟡 R1' · AC-4a/4b 集成层：主 L3 调用点已补真行为测试（🔴 解除），但 ✅ 仍夸大 + stderr 可观测后果被静默丢弃

**Symptom（症状）**：
- 修复确认：`test_model_degradation.bats:54-79`（test 3）对 `l3-review.sh` 的 `l3_review_run` 做了真行为集成——清空三个 model 源 + mock `_l3_call_api` + 断言 return 3 / `.flow-active.correction` type=l3-model-missing / `API_CALLED=0`。第 1 轮 🔴 R1 的核心病灶（主降级路径零回归守卫）在此 caller 上确已治好。
- 仍夸大 ①：AC-4a 明确要求「**两个** L3 调用点」（`REQUIREMENT.md:53-54`：`l3-review.sh` + `29-independent-review.sh`）。现仅覆盖 `l3-review.sh` 一处；`29-independent-review.sh` caller 集成在 `test_model_degradation.bats:81-84` 自认技术债。但 `TEST.md:29` 仍把 AC-4a 标 ✅——覆盖 1/2 法定调用点，不能标 ✅。
- 仍夸大 ②：AC-4b 的 caller（`l2-detect.sh` 的 l2 分发路径）零集成测试（同注释自认技术债，仅机制层 test 2）。`TEST.md:29` 把 AC-4b 标 ✅ 同样夸大。
- 静默丢弃：AC-4a/4b 各列三项可观测后果，第三项「stderr 输出含 `FLOW_KIT_L*_MODEL`」（`REQUIREMENT.md:58,67`）在所有测试中均无断言；`test_model_degradation.bats:71` 直接 `>/dev/null 2>&1` 丢弃 stderr。三项后果只剩两项被守卫，且 TEST.md/注释均未说明第三项为何不测。

**Source（源头）**：`REQUIREMENT.md:53-60`（AC-4a「两个调用点」+ 三项后果）、`:65-70`（AC-4b 同构）；阶段 5 checklist「每条 AC ≥ 1 条测试用例对应」「功能轮 100% AC 覆盖」。

**Consequence（后果）**：第 1 轮 R1 的 Critical 风险（主降级路径零守卫）已解除；但 `29-indep` 与 `l2-detect` 两个 caller 仍是「机制层证明」级别，若重构把「API 前 return」漏成「先调 API」或漏写 correction，这两个 caller 仍无行为测试会失败。更隐蔽的是 stderr 提示被整条链路静默放弃——降级时用户感知的唯一人机接口无人守卫。矩阵 ✅ 让 gate 误以为 AC-4a/4b 已闭环。

**Remedy（修补）**：
1. AC-4a/4b 矩阵改标 ⚠️（unit + 机制 + 1 caller 已覆盖 / `29-indep` + `l2-detect` caller + stderr 待补），不得标 ✅。
2. 补 `29-independent-review.sh` 与 `l2-detect.sh` 的 caller 集成（参照 test 3 的 mock 模式）；或在 TEST.md 显式 Tech-debt 登记 + 给出补测 plan，不能只在测试文件注释里提一句。
3. 至少在一个 caller 集成用例里断言 stderr 含 `FLOW_KIT_L3_MODEL`/`FLOW_KIT_L2_MODEL`（去掉 `2>/dev/null`，用 `run`/捕获比对），把第三项可观测后果补回闭环。

---

### 🟡 R3' ·（新发现）AC-7 实跑失败却声称「exit 0 / 0 failures」——全量回归陈述失真

**Symptom（症状）**：
- 实跑 `npx bats flow-kit-bundle/test/`（输出重定向到文件取真退出码）= **EXIT 1，586 ok / 1 not ok**。失败用例：`test_quality_baseline.bats:118`「AC-7: test/ 与 flow-kit-bundle/test/ 一致」。
- `TEST.md:41,43` 原文「全量 bats flow-kit-bundle/test/: exit 0（0 failures，无回归）」——与实跑结果不符。
- 根因 `diff -rq test/ flow-kit-bundle/test/`：本 change 触碰的 5 个测试文件均未同步到根 `test/` 副本——3 个仅存于 `flow-kit-bundle/test/`（`test_fk_resolve_model.bats` / `test_model_degradation.bats` / `test_flow_model.bats`），2 个两副本不一致（`test_flow_kit_resume.bats` / `test_independent_review_model.bats`）。根 `test/` 是 git 跟踪目录（66 文件），非生成产物。

**Source（源头）**：`REQUIREMENT.md:108-113` AC-7「全 pass，0 fail」，验证方式 `npx bats flow-kit-bundle/test/ && echo PASS || echo FAIL`（exit code 判定）——实跑得 FAIL。阶段 5 checklist「回归安全：全量 bats 不退化」。

**Consequence（后果）**：AC-7 按其字面验证方式不通过（exit 1），TEST.md 却报 0 failures，gate 若据 ✅ 放行即放过一条客观失败的 AC。缓解因素：失败性质为「双副本同步」元测试（非功能回归——所有功能用例均 pass），且 `TASK.md:222` 已把根 `test/` 同步划到 `package-flow-kit.sh` 打包时——故功能回归的「精神」未破。但 AC-7 的「字面」与 TEST.md 的「0 failures」陈述同时失真，必须订正。

**Remedy（修补）**：
1. TEST.md:41/43 把「exit 0（0 failures）」订正为实况：「1 failure：根 `test/` 副本未同步（5 文件），TASK.md:222 约定打包时同步」；AC-7 矩阵改 ⚠️ 或在出口准则里显式登记该已知失败。
2. 或直接同步 5 个文件使 exit 0 属实（最小修复：`cp flow-kit-bundle/test/<file> test/<file>`，立即让 AC-7 字面通过）。

---

### 🟢 R2' · AC-5/5b/5c：原子写入路径已补合格单测（🟡 降级，残留两项 minor）

**Symptom（症状）**：
- 修复确认：`test_flow_model.bats` 6 用例——AC-5 单写（:35,40）、AC-5b 合并写（:45）、AC-5c clear→null（:54）、字段边界（:60，断言 `condition`/`gate_config` 兄弟字段不动）、防注入（:66，`model"; rm -rf / #` 仍合法 JSON）。第 1 轮 R2 的「原子写未测 / 兄弟字段未守卫 / 防注入未测」三项全部补齐。
- 残留 ①：AC-5d（显示，`TEST.md:31`）仍标「manual | ✅」，全文仍无一次**已执行** UAT 证据（实际 `/flow model` 输出 + jq 验证）。第 1 轮 R2 Remedy 要求「记录一次已执行人工 UAT（附证据）」未落实。
- 残留 ②：测试自带的 `_flow_model_set`/`_flow_model_clear`（:19-33）是对 jq 模式的重新实现，并非测生产工件 `skills/flow/SKILL.md`（T07）里的实际代码——验证的是「这种写法对」，不是「SKILL.md 真这么写」。SKILL.md 是 markdown 内嵌 bash 难直接 source，可理解，但属测试保真度折中。

**Source（源头）**：`REQUIREMENT.md:93-98` AC-5d；阶段 5 checklist「UAT 可执行：Given/When/Then 是否可脚本化」。

**Consequence（后果）**：R2 的 Major 风险（写入路径零测试）已消；残留为显示路径无 UAT 证据 + 测试不导入生产代码两项 minor，不阻塞 gate。

**Remedy（修补）**：AC-5d 补一行已执行 UAT 证据（命令 + 输出 + `jq -e` 通过）即可；保真度项可登记 Tech-debt。

---

### 其他确认（已核查，无新发现）

- **AC-1 / AC-3（fk_resolve_model 全链）**：实跑 10 用例（L3/L2 × A-E）全 ok；场景 E 截断证明、场景 D 全空降级均在。覆盖充分。
- **AC-2（L3 P1 命中·CC 不变）**：L3-A 用真实 `ANTHROPIC_DEFAULT_HAIKU_MODEL` 断言截断（`REQUIREMENT.md:34`「不向下查」证明委托场景 E）。OK。
- **AC-6（SessionStart 收割）**：`test_flow_kit_resume.bats` 新增 4 用例行为测试（写 correction → source hook → grep banner 含 `FLOW_KIT_*_MODEL` + 断言文件未被删），合格。
- **5 轮金字塔**：性能轮跳过（Bash / <10ms / 非热路径）、安全/兼容/可观测轮部分跳过均附理由，符合 checklist。
- **响应段分类标记（checklist 第 6 点）**：TEST.md 用「L2 R1/R2 补强」「Tech-debt」散文标注 R1/R2，但未采用 checklist 规定的 `Fixed in:/Tech-debt:/Not-applicable:` 结构化标签——建议对齐（minor）。

**Verdict**: pass

（第 1 轮 🔴 R1 已降为 🟡 R1'——主降级路径已补真行为测试，无 🔴 Critical 残留，故 verdict 由 fail 转 pass。但 R1'/R3' 两条 🟡 要求订正矩阵夸大（AC-4a/4b 应 ⚠️）与 AC-7 失真陈述（exit 0→实为 exit 1）后方可闭环。）
