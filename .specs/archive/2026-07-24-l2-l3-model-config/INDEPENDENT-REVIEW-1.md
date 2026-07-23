# 独立审查 · 阶段 1

## L2 盲审

> 审查人：独立审查员（L2 子 agent）
> 审查时间：2026-07-23（re-review · 第 5 轮）
> 审查范围：Phase 1 需求审查 — `.specs/l2-l3-model-config/REQUIREMENT.md`（参考 `CHANGE.md`；`DESIGN.md` 仅作 AC 可落地性交叉验证）

### 独立性声明

本轮盲审仅依据 REQUIREMENT.md 工件文本作判断。为独立评估「AC 可机器验证 / 可落地 / 依赖假设准确」，对 `flow-kit-bundle/hooks/`（`stop/lib/l3-review.sh`、`stop/lib/l2-detect.sh`、`stop/29-independent-review.sh`、`stop/lib/common.sh`、`session-start/flow-kit-resume.sh`）作了只读交叉取证——这是对 AC 实现可行性与依赖假设的独立核查，非引用任何作者自评、主 agent 反馈或既有 L2/L3 结论。下文 R1–R4 为独立推导。

### 第 4 轮发现复核（独立核对工件文本）

逐行独立核对 REQUIREMENT.md，确认第 4 轮 8 项发现已落地（非引用旧结论，均由本轮重新读码确认）：

- **R1（--clear / 合并写入无 AC）已解**：AC-5b（`/flow model l2=m-a l3=m-b` 合并写入，jq `and` 断言）+ AC-5c（`--clear l2`/`--clear l3`，`== null` 断言）已补齐。 ✓
- **R2（return 3 撞名）已解**：AC-4a/4b Then 明确「不依赖返回码唯一性，因 return 3 已被 l3-review.sh 复用为通用错误码」，改断言三项可观测后果。独立读码确认 `l3-review.sh` 在 14 处用 `return 3`（行 326/356/372/383/492/498/566/603/617/618/619/666/683/691），确为通用错误码，原 R2 判断属实、现规避得当。 ✓
- **R3（场景 B P3 取值未指定）已解**：AC-1/AC-3 场景 B 已显式列 `.flow-active.goal.l3_model=cfg-c` / `.l2_model=cfg-c`（P2、P3 同设不同值）。 ✓
- **R4（AC-2「不向下查」逻辑缺口）已解**：AC-2 Then 补注「优先级压制由 AC-1 场景 E 证明，本 AC 仅验证 P1 返回值正确」。 ✓
- **R5（模型名安全引用）已解**：非功能性「安全」已加「实现侧必须用 `jq --arg` 引用拼接，禁止裸插值」。 ✓
- **R6（/flow model 平台可用性 + 原子性）已解**：兼容性 NFR 补「非 CC 平台通过 `FLOW_KIT_*` env var 或 `.flow-active` 直写配置（不依赖 `/flow model` skill）」；AC-5 Then 把原子性降级为「实现约定」，AC 仅验最终写入。 ✓

另独立确认：前序 L3 提的「Given 与场景 D 冲突」「AC-7 grep 模式」「correction 临时文件」等均已由「逐场景独立 setup/teardown」「exit code 判定」「bats 对称覆盖」化解。

---

### 🟡 R1 · correction 收割机制并非「可复用」：resume.sh 仅显示 type=compliance，对其它 type 静默删除 + model-missing correction schema 未定义

**Symptom（症状）**：REQUIREMENT 两处声称可复用既有 correction 机制：
- v1 范围：`flow-kit-resume.sh 收割 l2-model-missing / l3-model-missing（复用既有 correction 读写机制）`
- 依赖与假设：`依赖既有 .flow-active.correction 读写机制（已由 … flow-kit-resume.sh 实现）`

但独立读码 `flow-kit-bundle/hooks/session-start/flow-kit-resume.sh:88-128`，收割逻辑为：

```
corr_type=$(jq -r '.type // "unknown"' …)
corr_count=$(jq -r '.violations | length // 0' …)
if [[ "$corr_type" == "compliance" && "$corr_count" -gt 0 ]]; then
  <输出合规 banner>
else
  echo "[flow-kit-resume] ⚠️ .flow-active.correction 格式异常（type=… count=…），已清除" >&2
fi
rm -f "$compliance_correction_file"
```

即 resume.sh 当前**只识别 `type=compliance` 且依赖 `.violations[]` 数组**；任何其它 type（含拟新增的 `l3-model-missing` / `l2-model-missing`）落入 else 分支，被当「格式异常」**写 stderr + 删除文件**，不会出 banner。模型缺失 correction 的 schema（是否含 `.violations[]`？字段集是什么？）在 REQUIREMENT 全文未定义。

**Source（源头）**：Phase 1 checklist「依赖与假设准确 / 风险识别」+ AC 可落地。需求层对既有机制的依赖声明必须与代码现状一致；「已由 resume.sh 实现」是可独立证伪的事实命题，读码证伪。

**Consequence（后果）**：(1) 依赖声明失真会误导 2-design 资源估算（误以为「只复用、零改 resume.sh」，实则要新增 type 分支 + 新 schema）。(2) 更危险：实现者若按「复用」理解，只加 model-missing 的**写**、忘加 resume.sh 的**读分支**，则 correction 一落地就被 else 分支静默删除——AC-4a/4b 的「写 correction」断言会过（写确实发生了，且发生在 resume 之前），而 AC-6「banner 输出」会挂；但「写得出、读不到」的因果断层跨在 AC-4 与 AC-6 之间，没有任何单一 AC 暴露它，须手工关联两个 AC 才能定位。(3) model-missing schema 未定义，2-design 须补，否则 4-dev 无据实现。

**Remedy（修补）**：(a) 把 v1 范围改为「resume.sh 新增 `l3-model-missing` / `l2-model-missing` 收割分支（当前 resume.sh 仅识别 `type=compliance`，新增 type 须扩 read 侧，非纯复用）」，并在「依赖与假设」订正为「correction 写机制可复用（`correction-file.sh`）；读侧 resume.sh 需新增 type 分支」。(b) 显式标注「model-missing correction schema 待 2-design 定义（至少含 `type` 字段；是否含提示文本 / 设置方法字段由 design 决定）」。(c) 在「风险与未知」补一条：「resume.sh 现有 else 分支对未知 type 做删除，新 type 必须在其前显式分支命中，否则 correction 被静默丢弃」。

---

### 🟢 R2 · AC-4a 集成层「source 两 caller」对编号 hook 不安全

**Symptom（症状）**：AC-4a 集成层写「分别 source 两 caller，断言上述三项可观测后果」，两个 caller 为 `lib/l3-review.sh` 与 `stop/29-independent-review.sh`。独立读码：`29-independent-review.sh` 是编号 hook，顶层即 `set -euo pipefail`（行 13）+ 顶层 `if` 控制流（行 44/62/70…）+ 顶层函数调用（行 144/180）。`source` 它等于执行整个 hook（含 gate 判定、工件收集、L2-verdict 提取、L3 调用），在测试壳里既缺上下文又会触发 `set -e` 链式退出。`lib/l3-review.sh` / `lib/l2-detect.sh` 同样带 `set -euo pipefail`（行 33/16）。

**Source（源头）**：AC 可落地——建议的验证机制应可行；编号 hook 的执行模型（顶层逻辑 + 严格模式）与 lib 文件（函数库，可 source）不同，AC 不应把两者并列统称「source 两 caller」。

**Consequence（后果）**：轻微。实现者若照字面 `source 29-independent-review.sh` 会撞墙；所幸 AC-4a 集成层已标「待 4-dev」，三项可观测后果（不调 API / correction type / stderr 提示）本身是清晰且可验的契约，换 mock 或抽 lib 函数即能落地，不阻塞需求审批。

**Remedy（修补）**：把 AC-4a/4b 集成层的「source 两 caller」改为「针对每个 caller 的降级路径做可观测后果断言（实现方式 4-dev 选：mock `_l3_call_api` / 抽 lib 函数 / bats stub）」，不指定 `source` 这一不可行机制。

---

### 🟢 R3 · AC-5c Then「回到 env var / 降级路径」未被验证方式覆盖

**Symptom（症状）**：AC-5c Then：「对应字段置空（null 或删除 key），回到 env var / 降级路径」。验证方式仅 `jq -e '.goal.l2_model == null' .flow-active && jq -e '.goal.l3_model == null' .flow-active`——只验字段被清，不验「回到 env var / 降级路径」（即 `fk_resolve_model L3` 在 clear 之后是否真的回退到下一优先级或空降级）。

**Source（源头）**：AC 内部一致性——Then 每个断言须有验证路径。这与第 4 轮 R4（AC-2「不向下查」缺验证）同型：Then 承诺了一个行为后果，验证方式却没覆盖。

**Consequence（后果）**：轻微。实现若 clear 后残留缓存或解析 bug 致未回退，此 AC 不失败；但 `/flow model --clear` 的核心价值正是「回退」，缺这一验使 AC-5c 退化为「字段清空」单点。

**Remedy（修补）**：验证方式补一步：clear 后在仅设 `FLOW_KIT_L3_MODEL=env-x` 时 `( fk_resolve_model L3 )` 返回 `env-x`、全空时返回空，证明链已回退。或把 Then 的「回到 env var / 降级路径」移出 AC（交 AC-1 场景 C/D 已覆盖的链逻辑），Then 只留「字段置空」。

---

### 🟢 R4 · 新增 `l2-model-missing` 与既有 `l2-missing` 名称近形，收割须用精确等值

**Symptom（症状）**：REQUIREMENT 拟新增 correction type `l2-model-missing` / `l3-model-missing`。独立读码发现既有 type `l2-missing`（`29-independent-review.sh:20`，语义为「gate_config=both 但 `## L2 盲审` 段缺失」）。两者语义不同、字符串也不同（精确等值下不撞），但仅差 `-model` 一段，近形易混。resume.sh 现用精确等值（`== "compliance"`），是正向先例。

**Source（源头）**：命名空间卫生 + 可维护性——近形 type 名配以子串 / 前缀匹配会误命中；需求层应把「精确等值」约定固化为要求，免得 4-dev 用 `grep l2-missing` 误覆盖 `l2-model-missing`。

**Consequence（后果）**：轻微。若 4-dev 收割误用子串匹配（如 `*l2-missing*`），会把「L2 审查段缺失」与「L2 模型未配」两类 correction 路由到同一 banner，提示文案错位。

**Remedy（修补）**：在 AC-6 或可观测性 NFR 补一句「type 匹配必须用精确等值（`== "l3-model-missing"`），禁止子串 / 前缀匹配，以区别于既有 `l2-missing`」。或在 2-design 评估是否改名（如 `l2-model-unset`）拉大编辑距离。

---

### 附录：检查通过项（独立核对）

- **优先级链结构**：AC-1/AC-3 五场景（A–E）覆盖每级决定 + P1/P2 压制（场景 B 显式 P3=cfg-c）+ P1>P2>P3（场景 E）+ 全空降级（场景 D，逐场景 setup 不与 Given 冲突）。 ✓
- **L3 双调用点**：AC-4a 显式列 `l3-review.sh`（原 :623，读码确认 `:?`）+ `29-independent-review.sh`（原 :59，读码确认 `:?`）。 ✓
- **L2 调用点**：AC-4b 指 `l2-detect.sh`（原 :215，读码确认 `${ANTHROPIC_L2_MODEL:-claude-sonnet-5}`）。 ✓
- **降级三可观测后果**：AC-4a/4b 用 correction type + stderr + 不调 API 三项，规避 return 3 撞名。 ✓
- **SessionStart 对称**：AC-6 两分支（l3/l2-model-missing）独立断言。 ✓
- **回归守卫**：AC-7 用 exit code 判定。 ✓
- **v1/v2/out 切分**：v2 推迟项有 ADR-011 依据；out 显式记录 fallback 移除决策。 ✓
- **兼容性权衡透明**：US-2 + NFR + out 三处一致承认 L2 fallback 移除的行为变化，无内部矛盾。 ✓
- **安全 NFR**：已要求 `jq --arg` 引用拼接，禁裸插值。 ✓
- **性能 NFR**：<10ms 声明合理（env read + 一次 jq，无网络 IO）。 ✓
- **依赖显式**：jq / common.sh source / PROJECT_ROOT（读码确认 common.sh:101 设 `PROJECT_ROOT`）/ correction 写机制（`correction-file.sh` 存在）。 ✓（读侧 resume.sh 见 R1）
- **REQUIREMENT 自标 DESIGN 缺陷**（§7 路径前缀、§8 兼容性表）独立核对属实。 ✓

---

**Re-review**: yes（第 5 轮独立盲审；新发现 1🟡 + 3🟢，无 🔴；第 4 轮 8 项发现经独立读码确认全部已解）

**Verdict**: **pass**

本轮未发现 🔴 Critical。1 项 🟡 Major（R1：correction 收割机制「可复用」声明与 resume.sh 现状不符——仅识别 `type=compliance`、对其它 type 静默删除；model-missing correction schema 未定义；「写得出 / 读不到」的因果断层跨在 AC-4 与 AC-6 之间，单一 AC 不暴露）建议进 2-design 前处理：订正依赖声明、定义 model-missing schema、把 resume.sh 改 read 侧纳入 v1。3 项 🟢 Minor 为精度 / 可落地性改进（source 编号 hook 不安全、AC-5c 回退未验、近形 type 名须精确等值）。经 5 轮迭代，REQUIREMENT 在 AC 完整性、范围切分、兼容性透明度上已达可批准水平；无 Critical，不阻塞需求审批。

---

## L3 重审（deepseek-v4-flash[1m] 外部模型 · 2026-07-22 02:37）

> 自动生成于 2026-07-22 02:37。由 l3-review.sh 写入。

### 审查结论

```json
{
  "critical": [
    {
      "file": "AC-1, AC-3",
      "issue": "Given 条件与场景 D 矛盾",
      "why": "AC-1 和 AC-3 均以 '.flow-active.goal.l3_model 已设为 from-config'（或 L2 对应）作为全局 Given，但场景 D 要求“全部未设置”，导致该场景无法同时满足 Given 与 When，测试不可执行。",
      "fix": "为每个场景独立声明 Given 条件，例如场景 D 的 Given 应为：所有环境变量未设置且 .flow-active.goal.l3_model 不存在或为空。"
    }
  ],
  "major": [
    {
      "file": "AC-5",
      "issue": "Then 描述混合了命令动作与结果状态",
      "why": "Then 中写“/flow model 无参显示当前配置”是一个命令调用，而非纯结果状态，容易混淆验收点。验证方式虽用 jq 检查了写入结果，但未验证“无参显示”行为。",
      "fix": "将 Then 拆分为两条：1) .flow-active.goal.l3_model 设为 'deepseek-v4-flash'；2) 运行 /flow model 无参时输出包含当前配置。或明确只验收写入结果。"
    }
  ],
  "minor": [
    {
      "file": "AC-6 验证方式",
      "issue": "验证方式使用了临时文件 /tmp/test-correction.json 而非实际 .flow-active.correction",
      "why": "验证方式与需求中 '写入 .flow-active.correction' 的表述不一致，可能引入测试环境差异。",
      "fix": "建议直接操作 .flow-active.correction 文件（如先写入再 source hook），或明确说明这是简化示例。"
    },
    {
      "file": "AC-7 验证方式",
      "issue": "grep 条件 '^[0-9]+ tests' 可能不匹配所有 bats 输出格式",
      "why": "bats 输出可能为 '1..N' 或 '# tests N'，grep 模式过于狭窄，可能导致假阴性。",
      "fix": "使用 exit code 检查（如 'npx bats test/ && echo PASS || echo FAIL'）更为可靠。"
    }
  ],
  "verdict": "fail",
  "summary": "AC-1 和 AC-3 的 Given 条件与场景 D 冲突，导致关键验收准则不可验证，判定为 critical 问题，整体 fail。"
}
```

L3_artifact_hash: a2ba83215f43344996e395308ce363ccf9936dab67951c58b4c6d8eb34f42327

---

## L3 重审（glm-5.1 外部模型 · 2026-07-23 01:01）

> 自动生成于 2026-07-23 01:01。由 l3-review.sh 写入。

### 审查结论

```json
{"critical":[{"file":"AC-4a, AC-4b, AC-6","issue":"AC 中引入了 `.flow-active.correction` 及对应的 `type` 字段，但在「范围切分」中完全缺失对该数据结构写入与读取机制的实现定义。","why":"如果没有任何代码实现 `.flow-active.correction` 的增删改查（例如新建一个专门的 correction 库），AC-4a/4b 中「写入 correction」的动作将无法执行，AC-6 也无法 grep 到对应内容。这属于核心功能在设计与交付切分上的断层，导致 AC 不可验证。","fix":"在「v1 范围」中明确补充底层实现项：新增/修改负责写入和解析 `.flow-active.correction` 文件的相关工具函数（如 `common.sh` 中的 helper），并在依赖假设中明确 correction 文件的读写格式。"}],"major":[{"file":"AC-4a, AC-4b","issue":"Then/验证方式 中要求「caller 不崩溃（不用 `:?` 终止）」并期望「返回码非 0」，但集成验证步骤明确标注了「待 4-dev 实现后」，导致当前 TEST 阶段无法进行闭环验证。","why":"工件自身声明「AC 是 TEST 阶段派生用例的唯一来源」，若底层实现（4-dev）未完成，集成层的 AC 在本轮交付中实际上是不可验证的，这会引发 TEST 阶段的阻塞或误判。","fix":"明确将 caller 的降级行为判定限制在纯单元测试层级（通过 mock 或者测试脚本直接模拟空值返回并断言后续行为），或者强制要求底层 caller 的降级实现必须在同一个 v1 scope 内完成并移除「待」字样。"},{"file":"AC-1, AC-3","issue":"优先级链测试场景中的 env var 设置表达式存在歧义与潜在的语法错误风险。","why":"诸如 `ANTHROPIC_DEFAULT_HAIKU_MODEL=""` 的内联声明在很多 shell 环境下并不等同于 unset（会被视为设置为空字符串），这会导致测试用例在执行 `fk_resolve_model` 时可能无法真实模拟「未设」与「设为空」的严格区分，或导致脚本执行报错。","fix":"将 AC 描述中的场景 A/C 的环境变量前置条件明确修改为使用 `unset ANTHROPIC_DEFAULT_HAIKU_MODEL`，以严格对齐「非空值即停」的逻辑判定。"},{"file":"AC-5","issue":"When 条件描述执行 `/flow model l3=deepseek-v4-flash`，但在 v1 范围内未见对该路由的底层解析实现说明。","why":"虽然 v1 提到修改 `skills/flow/SKILL.md` 加路由，但如果未明确底层接收 `/flow` 参数并执行 jq 写入的执行器实现，这个 AC 仍然可能悬空（仅靠提示词路由而缺乏执行脚本）。","fix":"在 v1 范围中明确指出是修改哪个具体的 dispatcher 脚本（如 `commands/flow.sh` 或类似执行脚本）来处理 `model` 子命令及参数解析，确保不仅有 Skill 层的路由，还有 code 层的落地。"}],"minor":[{"file":"AC-5","issue":"Then 要求「原子写，jq + 临时文件 mv」，验证方式仅使用了 `jq -e` 读取验证，未验证原子性。","why":"AC 声明要求测试可验证且无歧义，但提供的验证方式无法覆盖其声明的非功能性约束（原子性）。","fix":"在验证方式中补充关于原子性的断言，例如检查执行期间是否生成了 `.flow-active.tmp` 等临时文件且执行后已清除，或接受这是静态代码检查（Code Review）负责的部分，从 Then 中移除实现细节。"},{"file":"非功能性需求 / 依赖假设","issue":"假设 `common.sh` 已被所有调用点 source，但假设 `PROJECT_ROOT` 已设置。","why":"在解耦和独立组件的上下文中，过度依赖外部隐式状态可能削弱组件的独立测试性。","fix":"在 AC 的验证步骤（如 source common.sh 之前）明确显式导出或设置 `PROJECT_ROOT` 环境变量，确保测试用例的健壮性。"}],"verdict":"fail","summary":"核心业务数据结构（.flow-active.correction）在 AC 中被大量使用但在 v1 范围实现清单中完全缺失，存在严重的验证断层。"}
```

L3_artifact_hash: 9278d59570bf27ca243d9a408bb36727045fedb4c6d53d6556f21da788574b4a

---

## L3 重审（glm-5.1 外部模型 · 2026-07-23 01:26）

> 自动生成于 2026-07-23 01:26。由 l3-review.sh 写入。

### 审查结论

```json
{"critical":[],"major":[{"file":"AC-4a, AC-4b","issue":"集成层验证与代码实现机制自相矛盾：AC 文本要求「不崩溃（移除 :?）」并「写 .flow-active.correction」，但提供的具体实现机制（参照 weak-model-compliance.sh 的写法）与集成测试 setup 互相冲突。","why":"weak-model-compliance.sh 和 29-independent-review.sh 是运行期执行的脚本（含严格模式 set -e 和独立执行栈）。若像 AC-4a 集成层描述那样直接 `source` 这两个脚本，在脚本初始化期间会触发 set -e 或未定义变量错误导致测试崩溃；且若不 source，仅靠修改后的函数在单独的 bats 脚本执行子进程中直接写 `.flow-active.correction`，会违背既有文件锁/原子追加机制，产生竞态条件。","fix":"明确具体的降级写入封装机制：是提供独立的 `write_correction "type=l3-model-missing"` 辅助函数（单独被 caller 调用），还是通过 mock 命令拦截原有的 correction 机制；并且明确测试是通过 mock 源文件中的写动作，还是抽取代码到 lib 库供测试直接 source 调用，避免 source 独立脚本导致的模式冲突。"}],"minor":[{"file":"AC-5","issue":"Then 条件描述了具体的底层实现（jq + 临时文件 mv），而不是纯粹的用户可验证行为结果。","why":"验收标准应侧重于「结果」（原子性写入，读不到半成品），而非绑定具体的实现技术栈。耦合实现细节会导致后续重构技术栈时 AC 失效。","fix":"将 Then 描述改为：「更新前后和更新中 .flow-active 结构均保持完整（可被 jq 解析），且无残留的临时文件」等更具行为导向的验收描述。"},{"file":"AC-1, AC-3","issue":"场景 A 到 E 中均提到设置 P2/P3 为空，但 When 条件仅强调「逐场景独立 setup/teardown」，对 `.flow-active` 的清理动作定义不够显性。","why":"如果测试仅在当前目录操作，临时创建的 `.flow-active` 文件若 teardown 不彻底，容易污染其他测试用例。","fix":"在验证方式中明确强调：「使用 mktemp -d 创建临时工作目录，并 cd 到该目录下创建临时 .flow-active 文件」，确保环境绝对隔离。"}],"verdict":"pass","summary":"范围切分清晰，v1/v2/out 边界合理；虽存在部分 AC 验证方式与既有实现架构（直接 source 运行脚本）的执行模型冲突，但不造成系统级验收阻碍，标记为 pass 并要求在开发前澄清降级写入的测试边界。"}
```

L3_artifact_hash: 682559130a531ce5c25f1d05a2186271ef23dc3d4d32a6cea9b3c4bcac1d8e23
