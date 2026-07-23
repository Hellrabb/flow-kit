# 独立审查 · 阶段 3

## L2 盲审

- **审查对象**：`.specs/l2-l3-model-config/TASK.md`（v2）
- **参考**：`.specs/l2-l3-model-config/REQUIREMENT.md`、`.specs/l2-l3-model-config/DESIGN.md`
- **审查日期**：2026-07-23（第 2 轮 re-review）
- **独立性声明**：未检测到主 agent 上下文注入；以下结论仅基于上述三工件 + 对源码/测试的 grep 查证。
- **v1 → v2 处置追踪**：v1 R1（🔴 T04↔AC-3 互斥）已被 T11 **部分**修复（AC-3 的 29-indep 分支），见 R1'；v1 R2（🟡 T08 引用不存在的 flow-gate-config/SKILL.md）**已修复**（T08 删、T07 改内联，forbidden list 显式禁止独立 skill）；v1 R5（🟢 T10 同步 :99 既有断言）**已采纳**（T10 action 含「同步检查既有 :99 行断言」）；v1 R3/R4（🟢）**未采纳**，降级保留为 R4'/R5'。

### 🟡 R1' · T11 只迁移 AC-3 的 29-indep 分支，静默丢弃 v1 R1 remedy 中的 AC-1 更新

**Symptom（症状）**：v1 R1 的 Remedy 明确要求**两处**改动：(a) AC-3（29-indep `:?` 断言，line 49-51）改为 `fk_resolve_model` 契约；(b) AC-1（`grep -c 'ANTHROPIC_DEFAULT_HAIKU_MODEL' >= 1`，line 24-26）的 grep 目标改为断言 `fk_resolve_model` 存在。v2 T11 `<action>` 只写了 (a)（「既有 AC-3 段（:45-56）……改为 fk_resolve_model 契约」），完全未提 (b)。查源码 `29-independent-review.sh` 当前仅有 **2 处** `ANTHROPIC_DEFAULT_HAIKU_MODEL` 字面量：`:57`（注释「完全由 ANTHROPIC_DEFAULT_HAIKU_MODEL 定义」）+ `:59`（`:?` 行）。T04 替换 `:59` 后，AC-1 仅靠 `:57` 这条**已过时的注释**机械过关——该注释声称「完全由 ANTHROPIC_DEFAULT_HAIKU_MODEL 定义」，T04 后此命题为假（29-indep 不再直接读 env var，改调 `fk_resolve_model`）。若实现者顺手清理这条与代码矛盾的注释（良好实践），AC-1 grep 计数 → 0，AC-1 红，AC-7 连锁 fail。

**Source（源头）**：v1 R1 Remedy（本审查链前序产物，原文「AC-1 的 grep 目标改为断言 fk_resolve_model 存在而非裸 env var 字面量」）+ 阶段 3 checklist「覆盖完整性：所有被改动破坏的既有测试必须有对应修复 task」。T11 `<name>` 自我定位为「L2 R1」修复，但 scope 只覆盖 R1 remedy 的一半。

**Consequence（后果）**：T04+T11 后 AC-7 是否可达取决于实现者是否清理 `:57` 注释——不可预测。若清理（应然做法，注释与代码矛盾），AC-1 红、AC-7 fail，本 change 仍无法收尾。即便不清理，AC-1 也是「靠过时注释假绿」，掩盖 29-indep 已不再直接读 env var 的事实——未来任何接触者都被误导。

**Remedy（修补）**：T11 `<action>` 追加一步：「同步更新 AC-1（line 23-27）：将 `grep -c 'ANTHROPIC_DEFAULT_HAIKU_MODEL' >= 1` 改为 `grep -c 'fk_resolve_model' >= 1`（与 v1 R1 remedy 原文一致），断言 29-indep 调用 fk_resolve_model 而非裸 env var」。T11 已含该文件 write_files（两处副本：`flow-kit-bundle/test/` + `test/`），无新 task、无额外行数成本。

---

### 🟡 R2' · T11 未处理 AC-3 @test 块内的 30-ai-analyze.sh 断言——覆盖静默丢失风险

**Symptom（症状）**：`test_independent_review_model.bats:45-56` 的 AC-3 `@test` 块含**两个** `run`+断言对：line 49-51 断言 `29-independent-review.sh`，line 53-55 断言 `30-ai-analyze.sh`（均 `grep -cE 'ANTHROPIC_DEFAULT_HAIKU_MODEL:[-?]' >= 1`）。查源码 `30-ai-analyze.sh:92` 确有 `${ANTHROPIC_DEFAULT_HAIKU_MODEL:-$(config_get '.ai.model' "deepseek-v4-flash")}`，30 断言当前 pass。**关键：`30-ai-analyze.sh` 不在本 change 任何 task 的 write_files 内**（grep TASK.md / DESIGN.md / REQUIREMENT.md 三文件 `30-ai-analyze` 均 0 匹配），其 `:-` 模式不变，30 断言语义上仍应成立。但 T11 `<action>` 只描述改 29 分支，对 30 分支去留只字未提——若实现者把整个 @test body 重写为只测 `fk_resolve_model`（29-indep），30-ai-analyze.sh 的 env-var-first 覆盖被静默丢弃，无任何 review 信号。

**Source（源头）**：阶段 3 checklist「覆盖完整性 + verify 可验证性」+ 任务指令须消解歧义（不能让实现者猜 scope 边界）。v1 R1 Remedy 末尾原本留了「需确认：30-ai-analyze.sh……若不改，其断言保留即可」——v2 T11 把这个开放问题直接删掉，既未确认也未保留指引。

**Consequence（后果）**：两种结局完全取决于实现者对 T11 模糊 scope 的解读：(a) 保守地只替换 29 行、保留 30 行 → 无损；(b) 重写整个 @test → 30-ai-analyze.sh 的 env-var-first 契约失去自动化守卫，未来 30 脚本若误改无回归保护。任务文档不应把覆盖去留交给实现者掷硬币。

**Remedy（修补）**：T11 `<action>` 显式加一句：「保留 AC-3 @test 内 30-ai-analyze.sh 的 `:-` 断言不变（30 不在本 change 范围，见 forbidden list；T11 仅改 29-indep 分支）」。或更彻底：把 AC-3 拆成两个 @test——「AC-3a: 29-indep 用 fk_resolve_model」「AC-3b: 30-ai-analyze.sh 仍 env-var-first（:-）」，从结构上消除歧义。

---

### 🟡 R3' · T11 verify 继承「测试读 `$HOME/.claude/hooks/` 安装副本」依赖，未标注 install 前置

**Symptom（症状）**：`test_independent_review_model.bats` 全文 **11 处** `run grep ... "$HOME/.claude/hooks/stop/..."`——读的是**安装副本**而非源码树。`setup()`（line 5-11）只做 `mktemp -d` + 存还原 env var，**无 install.sh 调用、无 cp/ln 同步**。对照同仓 peer 测试 `test_common.bats:8-14`、`test_flow_kit_resume.bats:11-19` 均用「向上查找 `flow-kit-bundle/hooks/` 目录」模式读源码树，本测试是异类。T11 `<verify>` 写 `npx bats flow-kit-bundle/test/test_independent_review_model.bats && echo PASS`，但新断言（`grep fk_resolve_model`）只有在安装副本已被刷新（源码 → `$HOME/.claude/`）后才命中；`install.sh` 在 forbidden list（不改），也无任何 task 负责刷新安装。

**Source（源头）**：阶段 3 checklist「verify 可验证性：每条 verify 是否可机器执行」——verify 须自包含、可复现，不应依赖未声明的 out-of-band 步骤。v1 R3 已对 T03/T04 verify 强度提过同类意见（verify 证不了它声称证的）。

**Consequence（后果）**：两种方向的误导：(a) 实现者按 T11 verify 跑 bats，若安装副本陈旧（仍是旧版 29-indep，无 `fk_resolve_model`），新断言 grep 计数 0 → T11 verify **假红**（代码对了测试却红）；(b) 反之若安装副本是旧的、仍含 `:?`，旧 AC-3 断言反而**假绿**——代码错了测试却绿。verify 的 PASS/FAIL 信号失真，无法证 AC-7。注：本测试当前能在仓里 pass，说明 dev 流程**隐式**保持 install 同步——但这是未文档化的默契，T11 不应依赖它而不声明。

**Remedy（修补）**：二选一（T11 action 加一步）：
- **方案 A（推荐·对齐 peer·一劳永逸）**：把 `test_independent_review_model.bats` 的路径解析从 `$HOME/.claude/hooks/` 迁移为「向上查找 `flow-kit-bundle/hooks/`」（复用 `test_common.bats:8-14` 的 setup 模式），让测试读源码树，install 无关——同时消除本测试所有 11 处 install 时序依赖；
- **方案 B（最小改动·保留现状）**：T11 `<verify>` 前置加一行 `bash install.sh --sync-only >/dev/null 2>&1 || true`（或 verify 备注显式说明「跑 bats 前须先 install.sh 刷新 `$HOME/.claude/`」），让 install 前置可见。

---

### 🟢 R4' ·（v1 R3 未采纳）AC-4a/4b 的 task verify 仍仅 grep token，未标注「行为断言延迟至 4-dev」

**Symptom（症状）**：v1 R3 建议 T03/T04/T05 的 `<done>` 加一行标注「AC-4 可观测后果的集成断言在 4-dev」。v2 TASK.md 未采纳——T03/T04/T05 的 `<done>` 仍是「降级 API 前 return」等接线描述，无集成层次声明。REQUIREMENT AC-4a（line 59-61）已写「集成层（待 4-dev）」，但 TASK.md 任何位置未回显该延迟，下游读 TASK 无法知悉 AC-4 在本阶段只到接线层。

**Source（源头）**：阶段 3 checklist「verify 可验证性 + 显式声明覆盖层次」。

**Consequence（后果）**：实现者/复审者读 T03/T04 verify 易误判 AC-4 已闭环；实际降级三要件（不发 API + correction type=l3-model-missing + stderr 提示）到 4-dev 才有断言。风险可控（REQUIREMENT 已声明延迟），但 TASK 缺交叉引用，4-dev 遗漏时无兜底信号。

**Remedy（修补）**：T03/T04/T05 `<done>` 各加一句「AC-4 集成断言在 4-dev（source caller + mock `_l3_call_api`），本 task verify 仅证调用点接线」。零代码改动。

---

### 🟢 R5' ·（v1 R4 未采纳）AC-5/5b/5c 仍无自动化测试，T07 verify 仅 grep token

**Symptom（症状）**：v1 R4 建议 T08（v2 已重组为 T07）verify 追加 jq 文档自检或显式标注人工验收。v2 T07 `<verify>` 仍只是 `grep -q '/flow model' flow/SKILL.md && grep -q '\-\-clear' && echo OK`——只证字面量存在，不证 jq 语法正确、不证写入。AC-5/5b/5c（REQUIREMENT line 72-91）有机器可执行 jq 断言（`jq -e '.goal.l3_model=="..."'`）但无 bats task 守卫。AC-5d 已显式「人工验收（显示行为非关键路径）」，AC-5/5b/5c 未声明人工却也无自动 task——AC 覆盖矩阵只写「T07（人工验收显示）」，把 5/5b/5c 与 5d 混同为人工。

**Source（源头）**：阶段 3 checklist「覆盖完整性」。

**Consequence（后果）**：AC-5/5b/5c 的写入正确性（jq `--arg` 防注入、`jq_atomic_write` 原子写、`l2=<m> l3=<m>` 合并语法）在 v1 无任何自动化守卫，回归靠人工。风险可控（skill 非关键路径，跨平台核心靠 env var / `.flow-active` 直写），但应显式知情而非默许。

**Remedy（修补）**：T07 verify 追加「文档自检」——把 SKILL.md 示范的 jq 片段抽出对临时 `.flow-active` 跑一遍 + `jq -e` 断言（验文档里的 jq 语法正确，非验 AI 路由）；或 AC 覆盖矩阵显式标注「AC-5/5b/5c = 人工验收（同 AC-5d）」，不再与「显示」混淆。

---

**Verdict**: pass

v1 的 🔴 R1（T04 完成标准与既有 `test_independent_review_model.bats` AC-3 互斥、AC-7 在 v1 逻辑上不可达）已被 v2 T11 在 **AC-3 的 29-indep 分支**上修复——严格阻断性的 🔴（AC-3 使 AC-7 必然失败）已消除，v2 无新增 🔴。剩余 5 条均为 🟡/🟢：R1'/R2'/R3' 是 T11 修复的**范围不完整**（AC-1 更新被静默丢弃、AC-3 的 30 分支去留歧义、install 前置未声明），R4'/R5' 是 v1 遗留 🟢 改进项未采纳。**强烈建议合入 R1'/R2'/R3' 后再进 4-dev**——否则 AC-7 在「实现者清理 `:57` 过时注释」（R1'）或「安装副本陈旧」（R3'）两种常见场景下仍会假红/假绿，复审信号不可信。R4'/R5' 可并行在 4-dev 收尾时补。

---

### 附：已核验通过的事实（无发现，备查 · v2 复核）

- **v1 R2（🟡 T08 引用不存在的 flow-gate-config/SKILL.md）已修复**：v2 删除 T08，T07 改为 flow/SKILL.md 内联段；TASK.md forbidden list 显式「⚠️ 不新建 `flow-model/SKILL.md` 独立子 skill」；DESIGN §0.5/§5 已订正为「内联（对齐 gate-config 模式）」。
- **v1 R5（🟢 T10 同步 :99 既有断言）已采纳**：v2 T10 action 含「同步检查既有 :99 行断言（l2-missing 持久化）与新 T06 行为一致」。
- **T11 双副本同步到位**：`flow-kit-bundle/test/test_independent_review_model.bats` 与 `test/test_independent_review_model.bats` 两份副本均存在且当前 byte-identical（`diff -q` 无输出）；T11 read_files / write_files 均列两份；全局回归命令 `npx bats flow-kit-bundle/test/ && npx bats test/` 覆盖两份。
- 行号准确性（v2 复核）：`l3-review.sh:623`、`29-independent-review.sh:59`（+ `:57` 过时注释）、`l2-detect.sh:215`、`flow-kit-resume.sh:89-128` 均与 TASK/DESIGN 一致。
- common.sh 现有 6 个 `fk_*` 函数 + `jq_atomic_write:159`，T01「不冲突」声明属实。
- `correction-file.sh` 为 LEAF 模块（自带注释声明、不 source 任何依赖、不设 `set -euo pipefail`），T02 verify `source correction-file.sh && type write_model_missing_correction` 可独立成立。
- `29-independent-review.sh:13` 确含 `set -euo pipefail`，DESIGN §8.5 R4 可测性论证成立。
- `l3-review.sh` 含 16 处 `return 3`，DESIGN §3「降级不靠返回码」论证成立。
- 波次依赖图无环（v2 复核）：Wave 1 {T01, T02} → Wave 2 {T03←T01+T02, T04←T01+T02, T05←T01+T02, T06←T02, T07 无依赖} → Wave 3 {T09←T01, T10←T06, T11←T04}。T08 编号空缺为 v2 删除所致（非遗漏）。
- Wave 2 五个 task 的 write_files 互不冲突（l3-review.sh / 29-indep / l2-detect.sh / flow-kit-resume.sh / flow/SKILL.md 均不同文件），`[P]` 标注合理。
- 单 task 行数估计均 ≤ 80 行（DESIGN §7 总计 ~190 行净增），远低于 200 行粒度阈值。
- T09 read_files 所列 `test_flow_active_integrity.bats` 存在；T10 read_files 所列 `test_flow_kit_resume.bats` 存在；T11 read_files 所列两份 `test_independent_review_model.bats` 均存在。
- `l2-detect.bats`（两份副本）不引用 `claude-sonnet-5` / `ANTHROPIC_L2_MODEL`，T05 移除 fallback 不破坏该既有测试。
- `30-ai-analyze.sh:92` 确含 `${ANTHROPIC_DEFAULT_HAIKU_MODEL:-$(config_get '.ai.model' "deepseek-v4-flash")}`，且不在本 change 任何 task 的 write_files 内（TASK / DESIGN / REQUIREMENT 三文件 grep `30-ai-analyze` 均 0 匹配）——30 分支断言语义不变，但 T11 须显式保留（见 R2'）。

---

## L3 重审（glm-5.1 外部模型 · 2026-07-23 11:44）

> 自动生成于 2026-07-23 11:44。由 l3-review.sh 写入。

### 审查结论

```json
{"critical":[{"file":"flow-kit-bundle/hooks/stop/lib/correction-file.sh","issue":"T02 要求的 compliance 优先 + 原子写动作无法被有效验证和证伪","why":"任务声明使用 jq 的 `if .type==\"compliance\"...` 条件进行单次原子合并防 TOCTOU，或使用 flock。但其 verify 命令仅检查了函数是否定义（`type ... >/dev/null`），根本没有检查实现代码中是否包含所要求的安全机制。如果执行 Agent 为了简便采用普通的覆盖写入（非原子操作），不仅能轻松通过 verify，还会引入潜在的竞态条件违反 AC-4 要求，且当前 verify 无法防御此错误实现。","fix":"在 T02 的 verify 中加入对实现机制的静态校验，例如：`grep -q 'compliance' correction-file.sh && grep -qE 'flock|if .type == \"compliance\"' correction-file.sh`。"}],"major":[{"file":"Wave 3 依赖划分","issue":"Wave 3 中 T09 和 T11 在逻辑上缺乏对其实际需要被执行（read）的代码依赖，割裂了测试与其目标代码的波次联系。","why":"波次说明标明 T09 仅依赖 T01，T11 仅依赖 T04。但 T09 的目的是测试全链路优先级解析（AC-1），其读取了 common.sh 必须依赖 T01。同理，T11 修改 test_independent_review_model.bats 测试用例，测试目标对象是 T04 修改后的 29-independent-review.sh。由于 T11 verify 中执行了 `npx bats test/test_independent_review_model.bats`，若它与 T04 并行执行，测试将会失败（找不到修改后的脚本或行为）。这说明测试 Task 必须强依赖于对应实现 Task 的完成。波次图只列出了部分依赖，会造成并行执行时的时序谬误。","fix":"明确在 T09 和 T11 的 <depends_on> 中补全对相关实现脚本修改（T03/T04/T05）的依赖关系，或将测试全部移至实现完成后的独立波次。"},{"file":"flow-kit-bundle/hooks/stop/lib/l3-review.sh","issue":"T03 的 verify 断言缺少对错误降级和清理路径的覆盖","why":"T03 的动作明确要求在空模型时调用 `write_model_missing_correction \"L3\"` 并在 API 调用前 return，正常时调 clear。但其 verify 仅用 `grep -q 'fk_resolve_model \"L3\"'` 和检查是否移除 `:?`。如果执行 Agent 忘记写降级 return 或 clear 函数，验证依然通过，导致不符合 AC-4a 的降级要求。","fix":"在 verify 中补充对降级写入函数的 grep 检查：`grep -q 'write_model_missing_correction \"L3\"' flow-kit-bundle/hooks/stop/lib/l3-review.sh && ...`。"}],"minor":[{"file":"全局","issue":"波次划分中 Wave 2 包含了 T03/T04/T05/T06/T07 标注为 parallel，但 depends_on 表明它们分别依赖 Wave 1 的产物。","why":"虽然通过依赖图保证了无环且有拓扑序，但在执行引擎中若未严格阻断 Wave 并行池，可能导致在 T01 尚未完成时 T03 开始执行。","fix":"确保执行器按 Wave 顺序依次解锁，而非仅依靠 depends_on 盲跑。"}],"verdict":"fail","summary":"测试用例验证手段存在致命缺陷（T02 verify 无法覆盖防竞态条件），且部分测试任务（T09/T11）缺少对其被测代码修改节点的显式依赖，导致无法完全证伪。"}
```

L3_artifact_hash: b41c5f2a5ab57b929b23af2e48010cf0f5f8c3ef82ddf078b43934f52f610e8a

---

## L3 重审（glm-5.1 外部模型 · 2026-07-23 11:55）

> 自动生成于 2026-07-23 11:55。由 l3-review.sh 写入。

### 审查结论

```json
{"critical":[{"file":"test_fk_resolve_model.bats (隐含测试用例)","issue":"AC 矩阵错误归属与测试覆盖缺失（AC-2）","why":"T09 的测试用例声称覆盖了「AC-1/AC-3 全链 5 场景」，且 AC 矩阵将 AC-2（L3 P1 命中）的覆盖任务也指派给了 T01+T09。然而，T09 明确未包含「L3 专属的 P1 (ANTHROPIC_DEFAULT_HAIKU_MODEL) 命中」的独立或有效覆盖验证。若 T09 中的场景 A（P1 命中）没有使用真实的 `ANTHROPIC_DEFAULT_HAIKU_MODEL` 环境变量进行隔离测试，而是直接赋值给 `FLOW_KIT_*` 或降级参数，则会导致 AC-2 完全失效（未被证伪）。这直接违反了 verify 是否能证伪且覆盖全 AC 的审查重点。","fix":"修改 T09 的 action，明确要求增加针对 L3 P1 变量 `ANTHROPIC_DEFAULT_HAIKU_MODEL` 命中且截断后续链路的专项用例，确保与 AC-2 矩阵描述严格对齐。"}],"major":[],"minor":[{"file":"T03, T04, T05","issue":"verify 命令仅执行 grep 静态文本检查，无法验证真实的降级行为和 API 拦截。","why":"虽然静态检查满足一定的防退步要求，但对于涉及状态变更和 API 阻断的关键逻辑（DESIGN §3），仅靠 grep 无法证伪「API 调用前 return」是否真实生效。","fix":"在对应的测试 task (T09/T10/T11) 中补充动态 source 执行测试，模拟空模型时调用相关 lib，断言不会触发实际的 API 请求且输出了明确的降级 correction。"},{"file":"T02","issue":"action 描述中关于原子写的实现逻辑有潜在歧义。","why":"action 提到使用 `jq 'if .type==\"compliance\"...'` 单次原子操作，这只能针对当前 JSON 文件整体替换，但如果文件不存在或本身格式损坏，单靠 jq 无法直接实现安全容错。","fix":"建议在 action 中明确：执行原子 jq 覆盖前，必须确保目标 correction 文件已存在且具备合法的 JSON 根结构（可借助既有的 ensure 函数），避免静默失败。"},{"file":"T07","issue":"人工验收 AC-5 缺乏自动化验证约束。","why":"/flow model 的行为完全依赖人工 prompt，verify 仅有简单的 grep 确认文本存在，如果 SKILL.md 中的指令逻辑写错（例如漏掉 --clear 参数解析），无法在 CI 中提前发现。","fix":"考虑在 T09 或新建一个测试中，通过正则匹配加强对 SKILL.md 中 /flow model 语法的结构化检查。"}],"verdict":"fail","summary":"AC 覆盖矩阵存在严重遗漏（AC-2 实际未被有效测试覆盖），导致 T09 无法证伪核心优先级链路，判定为 fail。"}
```

L3_artifact_hash: e85de61d169ad060060ebc6cf749848d1f2a29f2b2cdc159fca5daa64338ea12

---

## L3 重审（glm-5.1 外部模型 · 2026-07-23 13:13）

> 自动生成于 2026-07-23 13:13。由 l3-review.sh 写入。

### 审查结论

```json
{"critical":[{"file":"T11","issue":"read_files/write_files 路径错乱且包含执行无关的文件","why":"T11 的 read_files 和 write_files 包含 `test/test_independent_review_model.bats`（根目录）及 `flow-kit-bundle/hooks/stop/30-ai-analyze.sh`，且将根目录的测试文件列为 write 目标。这违反了严格的 `flow-kit-bundle/` 路径约定和 write_files 清晰边界。同时，30-ai-analyze.sh 属于无关模块，在本任务范围内 read 此文件不仅越界，且存在破坏隔离原则的风险。","fix":"从 read_files 移除 `flow-kit-bundle/hooks/stop/30-ai-analyze.sh`。将 read_files 和 write_files 严格限制在 `flow-kit-bundle/` 体系内（即移除所有对根目录 `test/` 路径的声明），确保边界绝对清晰。"}],"major":[{"file":"T11","issue":"测试验证命令 (verify) 严重违反了项目路径约定","why":"工件首部的「路径约定」明确声明 `verify 命令相对项目根`。在项目根目录下，工件期望测试文件位于 `flow-kit-bundle/test/` 目录下。但 T11 的 verify 命令执行了 `npx bats test/test_independent_review_model.bats`（根目录的 test 文件夹），这不仅与全局约束矛盾，也与其解析到 flow-kit-bundle 下的 read/write 结构不符，必将导致命令执行失败。","fix":"将 T11 的 verify 命令修改为仅针对 `flow-kit-bundle/test/` 下的文件执行：`npx bats flow-kit-bundle/test/test_independent_review_model.bats && echo PASS`。"}],"minor":[{"file":"全局依赖","issue":"任务波次划分（Wave 划分）遗漏了 T08 的编号声明，且 T11 声明依赖缺失","why":"波次划分代码块中列出 Wave 1 到 Wave 3 的所有任务，但直接从 T07 跳到了 T09，没有任何关于 T08 被移除的说明，这可能引起任务追踪歧义。另外，T11 的描述表明其需要同时更新 AC-1 和 AC-3 断言，而 T11 的 depends_on 仅为 T04，若 T11 需要覆盖 T05（L2模型）的降级断言逻辑，依赖链不够严密。","fix":"在波次划分说明中补充简短注释 `T08 已合并至 T07` 以消除编号缺失困惑。评估并视情况在 T11 的 depends_on 中追加 T05 以确保依赖闭环。"}],"verdict":"fail","summary":"T11 的文件读写边界严重越界且 verify 命令路径矛盾，导致破坏路径约定并必将引发执行失败，判定 fail。"}
```

L3_artifact_hash: 0ec379dafcd8e63d62203146ea2b37ecc0a3e6274ae4bf02a3cec3eec0c042e5

---

## L3 重审（glm-5.1 外部模型 · 2026-07-23 13:23）

> 自动生成于 2026-07-23 13:23。由 l3-review.sh 写入。

### 审查结论

```json
```json
{
  "critical": [
    {
      "file": "T11",
      "issue": "verify 命令完全无法证伪（不可执行），严重违反阶段3独立审查标准。verify 使用 `npx bats ... && echo PASS`，但在前置任务 T04 完成后，30-ai-analyze.sh 的 :- 硬依赖被保留，导致测试断言必然失败。然而，由于缺少真正的失败拦截逻辑（例如断言数量或特定 grep 字符串），该 verify 无法将此失败状态与“未更新注释”等逻辑错误区分开。更重要的是，T11 的 action 明确要求覆盖两处完全不同路径（29-indep.sh 和 30-ai-analyze.sh）的断言，但 verify 脚本却完全无法验证实现者是否完整保留了两者。",
      "why": "verify 阶段的铁律是可执行且能证伪。如果实现者在重构 @test 块时删掉了对 30-ai-analyze.sh 的原断言分支，或者破坏了注释修改，verify 无法捕获此失效。 bats 测试如果不检查内部断言计数或具体输出，即使存在代码错误也可能诡异地通过（例如误删了 fail 的断言块），这会放行严重的回归风险。",
      "fix": "在 verify 命令中增加对测试文件内部实质内容的强制校验。例如：`npx bats flow-kit-bundle/test/test_independent_review_model.bats && grep -q 'fk_resolve_model' ... && grep -q '30-ai-analyze' ... && echo PASS`。以此确保实现者确实重构了 29-indep 并原样保留了 30-ai-analyze 的测试逻辑。"
    },
    {
      "file": "T02",
      "issue": "verify 命令存在严重的正则表达式语法错误与逻辑漏洞，导致命令根本无法成功执行（语法报错退出码非0），或者被单引号截断后引发异常行为。",
      "why": "在 `grep -qE 'flock|if .type == .compliance.' ...` 中，`.` 被当作正则的任意字符匹配，而最致命的是未转义的点 `compliance.` 紧跟在单引号闭合前。这会被 Shell 解析为匹配 `compliance` 加任意字符，如果原本意图是匹配 jq 语法中的 `.compliance` 字段，这种写法既不精确也极易导致语法解析失败或非预期匹配。",
      "fix": "修正正则表达式，转义 jq 语法中的点并明确字符串边界。例如使用 fgrep 或 grep -F 配合确切的 jq 代码片段，如：`grep -qF 'if .type=="compliance" and (.violations|length>0) then' flow-kit-bundle/hooks/stop/lib/correction-file.sh && ...`"
    }
  ],
  "major": [],
  "minor": [],
  "verdict": "fail",
  "summary": "存在致命缺陷：T11 的测试验证无法防住断言丢失的代码变更，T02 的 verify 因严重正则语法错误根本不可执行，触发了 verify 可证伪性的红线。"
}
```
```

L3_artifact_hash: 8ee420f84b4717123898fdcd0874796fd0046ddec1af862e0c045f5c664b1c2d

---

## L3 重审（glm-5.1 外部模型 · 2026-07-23 13:37）

> 自动生成于 2026-07-23 13:37。由 l3-review.sh 写入。

### 审查结论

```json
{"critical":[],"major":[{"file":"flow-kit-bundle/test/test_flow_kit_resume.bats","issue":"Wave 并发执行时，T06 和 T10 同处于一个波次（Wave 3），但 T10 在 depends_on 中明确声明依赖 T06，属于波次划分与依赖图产生的严重冲突。","why":"按照并行执行约定，Wave 3 内的 T06 和 T10 会同时写文件并执行。T10 会在 T06（被测件修改）完成前执行，此时旧版 resume.sh 中 rm -f 是无条件的，会导致 T10 中新增的“model-missing 不被删除”断言直接失败（文件总是被删），使 verify 命令无法通过。","fix":"修正波次划分，将 T10 移至 Wave 4（或将其从 Wave 3 移出），确保 T10 仅在 T06 完全落地并提交后执行。"}],"minor":[{"file":"T09","issue":"test_fk_resolve_model.bats 的场景 A 意图测试“P1 环境变量优先级”，但在行动描述中“unset 对应 env var”的表述存在歧义。","why":"若在测试场景 A 中 unset 掉 P1 变量，将无法验证“P1 命中截断”的 AC-2 要求；若不 unset 则易与其他场景发生环境污染。","fix":"在 T09 action 中明确：在 setup 阶段通过 mktemp 实现严格作用域隔离，针对场景 A 显式 export 真实 P1 变量并断言不发生向下的穿透。"},{"file":"T02","issue":"T02 的 verify 命令尝试检查文件内部是否包含 'flock' 或 'if .type=="compliance"'。","why":"Shell 的 grep 命令解析包含双引号的模式时极易因为未转义导致语法错误或静默失败，从而削弱验证拦截效能。","fix":"建议在 verify 命令中对模式中的双引号进行转义，例如 grep -qF 'if .type==\"compliance\"'，或采用更稳健的匹配方式。"}],"verdict":"pass","summary":"任务拆解完整覆盖 REQUIREMENT 全部 AC，依赖无环且边界清晰，但因 Wave 3 将存在依赖的 T06/T10 放在同一并发层会导致严重的测试时序与执行失败（Major），修复并发划分即可通过。"}
```

L3_artifact_hash: e617d9747ab460774b3ee2dcd6b28ffe848cb35c07f45bad96ca732161a2ae2f
