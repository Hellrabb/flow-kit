# 独立审查 · 阶段 2

> 盲审范围：`.specs/l2-l3-model-config/DESIGN.md`（参考 ADR-006/012/013、CONTEXT.md、ARCHITECTURE.md）。
> 方法：独立性硬约束——所有代码事实主张均由审查员本人对 `flow-kit-bundle/` 实跑 grep/sed 取证，不采信 DESIGN 内「已 grep 确认」标签。取证记录附于每条发现的 Source。

---

## L2 盲审（第 2 轮 re-review）

**审查对象**：DESIGN.md「Phase 2 修订版」+ ADR-012/013。第 1 轮 R1-R7 已被纳入修订（DESIGN 内多处「L2 R1/R2/R3/R7 查证」标注）。本轮独立 re-review 聚焦：修订是否到位、是否引入新问题、是否有遗漏。

**独立取证**（由审查员本人实跑，非采信 DESIGN「已 grep 确认」标签）：
- `flow-kit-resume.sh:127` 的 `rm -f` 确在内层 `if/else`（:95-125）之外、外层 `if [[ -f ]]`（:91）之内 → 无条件删所有 type（第 1 轮 R1 属实）
- `29-independent-review.sh:59` / `l3-review.sh:623` 的 `:?` 报错、`l2-detect.sh:215` 的 `:-claude-sonnet-5` fallback —— 均属实
- `grep -c "return 3" l3-review.sh` = **16**（DESIGN §3 现记 16，第 1 轮 R6 的「14」已修正）
- `common.sh:159 jq_atomic_write` 存在；`commands/` 目录不存在（DESIGN §5 属实）
- ADR 双轨：`.specs/adr/006=l3-model-env-first` vs `ARCHITECTURE.md:184 ADR-006=protect-the-weakest`；注册表 max=ADR-009（第 1 轮 R3 属实）；CONTEXT.md:83/84 已前置登记 `l2_model/l3_model` 与 priority chain 词条

**第 1 轮修订验证**：R1（rm-f 条件化，§4.3 伪代码已按 type 分支重构 ✓）、R2（§4.1 已加 compliance 优先级规则 ✓ 但见本轮 R2/R3）、R3（§0.5 已声明双轨 ✓）、R4（§9→§10 已改 ✓ 但见本轮 R4）、R5（§2 已用 `${PROJECT_ROOT:-}` ✓）、R6（14→16 已改 ✓）、R7（§5 已声明 .goal 边界 ✓）。核心修订到位。

但 re-review 发现降级子系统的 correction **生命周期**存在两处设计级缺口（本轮 R1/R2）+ 一处跨文档语义自相矛盾（R3），关乎 AC-4/AC-6 落地与非 CC 目标受众的安全可见性。无 🔴 Critical，以下 3 条 🟡 须进 phase 3 前补强。

---

### 🟡 R1 · model-missing correction 无清除时机——AC-6「持续提示直到用户配置模型」的退出条件未实现
**Symptom（症状）**：DESIGN §4.3（DESIGN.md:203-208）model-missing 分支声明「不 rm —— 持续提示直到用户配置模型」，但全 DESIGN 无任何路径在用户配置模型后清除残留的 model-missing correction：
- resume.sh model-missing 分支：不删（§4.3 伪代码）
- caller 正常路径（`fk_resolve_model` 返回非空）：§3 伪代码（DESIGN.md:161）仅 `content=$(_l3_call_api ...)`，不写也不清 correction
- compliance 写入会覆盖，但仅在 28 号检测到违规时；无违规则不发生

时序推演：T1 用户未配模型 → 降级写 l3-model-missing → SessionStart 显示 banner（不删）✓；T2 用户 `export FLOW_KIT_L3_MODEL=...` → 下一轮 l3-review 正常路径 → 不清 correction → 文件仍是 T1 的 l3-model-missing；T3 SessionStart → resume.sh 看到 l3-model-missing → **再次显示已过时的 banner（用户已配置）** ✗。
**Source（源头）**：AC-6 语义「持续提示**直到**用户配置模型」隐含退出条件（配置后停止提示）；DESIGN 只实现入场（写入 + 不删），未实现退场（配置后清除）。亦违背 ADR-008「SessionStart 注入消费」的文件生命周期闭环——correction 须有明确终态，而非依赖「被下一次 compliance 覆盖」的偶发清除。
**Consequence（后果）**：用户配置模型后 banner 永久残留，误以为配置未生效 → 反复配置 / 困惑（对非 CC 平台——本 change 目标受众——是显著体验回归）；AC-6 的「直到」退出语义未实现。衍生影响：§3「降级有 model-missing correction、错误无」的 AC-4 断言在跨轮场景失效——错误路径不清残留的 model-missing，会让一次降级后的所有错误轮都被误判为降级。
**Remedy（修补）**：DESIGN §3 正常路径伪代码补「模型解析成功后，清除本 layer 的残留 model-missing correction」：
```
model=$(fk_resolve_model "L3")
if [[ -n "$model" ]]; then
  _clear_model_missing_correction "L3"   # 新增：清过时提示（type 感知，只清本 layer）
  content=$(_l3_call_api "$prompt_text" "$model")
fi
```
并在 §4.3 补「model-missing 的终态：caller 正常路径负责清除（type 感知，只清本 layer），与 resume.sh 的『不删』形成闭环」。AC-6 bats 用例须覆盖「配置前显示 → 配置后消失」双向，不能只测「显示 + 不删」。

---

### 🟡 R2 · 安全优先规则（compliance > model-missing）实现位置未固定为单一 lib 函数——散弹枪手术风险
**Symptom（症状）**：DESIGN §4.1（DESIGN.md:179）安全优先规则要求「model-missing 写入前检查 correction——若 type=compliance 且 violations[] 非空则不覆盖」。但 §4.2（DESIGN.md:192）实现选项为「复用 correction-file.sh 的 helper（**若提供**）或 **caller 内联** jq -n」——允许 3 个 caller（l3-review / 29号 / l2-detect）各自内联「读 correction → 判 type → 决定覆盖」逻辑。
**Source（源头）**：散弹枪手术（Shotgun Surgery）反模式——同一正确性规则在 3 处重复；§9.4 禁动清单要求 `fk_resolve_model` 保持纯查询、side-effect 由 caller 负责，但安全优先检查恰恰是写 correction 的前置 side-effect 判断，更应封装而非散落。§8.5 R4 把「抽 lib 函数」列为**可选项**（「抽函数，**或**集成测试用 mock」）且归为「测试风险」——但安全优先是核心正确性逻辑，非测试便利。
**Consequence（后果）**：phase 3 若 3 caller 各自内联，任一处遗漏 compliance 检查即破坏优先级契约 → model-missing 覆盖 compliance → 安全 banner 被遮蔽（回到第 1 轮 R2 的安全可见性回归，且首当其冲是非 CC 目标受众）；后续修改优先级规则须同步改 3 处，易漏。
**Remedy（修补）**：DESIGN §4.2 删除「caller 内联」选项，强制 `write_model_missing_correction <layer>` 为 `correction-file.sh` 内单一 lib 函数，封装「检查 compliance 不覆盖 + 写入」原子逻辑，3 caller 统一调用。把 §8.5 R4 从「测试风险」提升为「正确性约束」并标注「必须抽函数，非可选」。

---

### 🟡 R3 · §4.1 与 §8.5 R3（及 ADR-013 Consequences）语义自相矛盾——「compliance 优先」vs「最后写入者胜 / model-missing 稳定覆盖 compliance」
**Symptom（症状）**：DESIGN §4.1（DESIGN.md:179）确立「写入优先级 compliance > model-missing：model-missing **不覆盖** compliance」。但两处仍未同步：
- DESIGN §8.5 R3（DESIGN.md:313-314）仍写「风险：compliance 与 model-missing 并发时互相覆盖（**最后写入者胜**）…缓解：model-missing 是持续状态会**稳定覆盖 compliance**…当前语义可接受（最后状态优先）」
- ADR-013 Consequences（013-correction-overwrite-strategy.md:29）：「compliance 与 model-missing 并发时互相覆盖（最后写入者胜）；model-missing 是持续状态…**多轮后稳定覆盖 compliance**，语义可接受」

§4.1 / ADR-013 Decision（013:21）说「不覆盖」，§8.5 R3 / ADR-013 Consequences 说「稳定覆盖」——同一文档 / ADR 内直接矛盾。两处显然是第 1 轮修订**前**的「最后写入者胜」措辞，§4.1 加安全优先规则后未回填。
**Source（源头）**：文档内部一致性原则。矛盾使 R2 缓解（§4.1）形同虚设——读者无法判断权威语义是「优先级」还是「最后写入者」。
**Consequence（后果）**：phase 3 实现者读 §8.5 R3 或 ADR-013 Consequences 会以为「最后写入者胜」是设计意图，从而**不实现** §4.1 的优先级检查——直接重新引入第 1 轮 R2 的安全遮蔽风险。这是用文档矛盾把已修复的设计缺陷又放回来的典型路径。
**Remedy（修补）**：同步修订 DESIGN §8.5 R3 + ADR-013 Consequences：删除「最后写入者胜 / model-missing 稳定覆盖 compliance」，改为「compliance 优先（model-missing 不覆盖已有 compliance，见 §4.1）；model-missing 仅在 correction 非 compliance 或 violations 为空时写入」。确保四处（§4.1 / §8.5 R3 / ADR-013 Decision / ADR-013 Consequences）语义一致后，再进 phase 3。

---

### 🟢 R4 · §10 子节号仍为 9.x（第 1 轮 R4 修复不彻底）
**Symptom（症状）**：第 1 轮 R4 把重复的「## §9」改为「## §10 · 架构沉淀建议」（DESIGN.md:343），但其下子节号仍是 `9.1` / `9.2` / `9.3` / `9.4`（DESIGN.md:345/351/355/359），未同步为 10.x。
**Source（源头）**：文档结构规范，章节号唯一含子节。
**Consequence（后果）**：无功能影响；§9（ADR）与 §10（架构沉淀）子节交叉引用歧义。
**Remedy（修补）**：9.1→10.1、9.2→10.2、9.3→10.3、9.4→10.4。

---

### 🟢 R5 · CONTEXT.md 禁动清单与新增字段不同步（A-evolve 待办登记）
**Symptom（症状）**：CONTEXT.md:83 已前置新增词条 `l2_model / l3_model`、:84 已加 `model resolution priority chain`，但 CONTEXT.md:396 禁动清单仍写「`.flow-active.goal` 字段——不允许手动编辑，必须通过 **/flow goal** 子命令操作」，未追加「l2_model/l3_model 须经 /flow model 操作」（DESIGN §5 已声明此边界，但 CONTEXT.md 禁动清单未同步，§10 也未登记此项 A-evolve 待办）。
**Source（源头）**：DESIGN §0.5 把 ARCHITECTURE.md 注册表同步留待 A-evolve；CONTEXT.md 禁动清单同属 A-evolve 范畴，第 1 轮 R7 要求在 §9.4 登记，但修订版 §10（原 §9.4）未显式列入。
**Consequence（后果）**：无实质风险（DESIGN §5 已约束）；但若 A-evolve 遗漏，后续弱模型 / 审查对「能否手 jq 改 l2_model」产生歧义（第 1 轮 R7 的残留）。
**Remedy（修补）**：DESIGN §10 禁动清单段补一条 A-evolve 待办：「CONTEXT.md:396 追加 `.flow-active.goal.l2_model/l3_model` 须经 `/flow model` 操作（与 .goal 其它字段经 /flow goal 并列，均禁手 jq）」。

---

**Verdict**: pass

核心三级链 + 纯查询函数抽象 + ADR 论证扎实，第 1 轮 7 条发现均已被纳入修订版（独立复核属实）。无 🔴 Critical。但本轮 re-review 发现降级子系统的 correction 生命周期有两处设计缺口（R1 model-missing 无清除时机 → AC-6 退出条件未实现；R2 安全优先规则实现位置未固定 → 散弹枪风险）+ 一处跨文档语义自相矛盾（R3 §4.1 vs §8.5 R3 / ADR-013 Consequences），这 3 条 🟡 直接关乎 AC-4/AC-6 落地与非 CC 目标受众的安全可见性，须在 phase 3 前于 DESIGN/ADR 内补强。2 条 🟢（子节号、禁动清单同步）为文档卫生。

---

## L3 重审（glm-5.1 外部模型 · 2026-07-23 02:25）

> 自动生成于 2026-07-23 02:25。由 l3-review.sh 写入。

### 审查结论

```json
```json
{
  "critical": [],
  "major": [
    {
      "file": "DESIGN §4.3 / flow-kit-resume.sh:89-128",
      "issue": "未能彻底修复既有 `.flow-active.correction` 的无条件删除 Bug，违背了 ADR-001（protect-the-weakest）的安全底线。",
      "why": "设计文档明确指出当前代码在 :127 执行 `rm -f` 会无差别删除所有的 correction。但 §4.3 提供的重构方案仅在 `if/elif` 内部对特定 type（如 compliance）执行了 `rm -f`，却未在 `else`（未知 type）分支，或当文件读取/解析失败时强制保留文件（例如未处理 `jq` 解析失败的情况）。如果产生了一个不在预期内的 type（如 l3-missing 旧拼写、或脏数据），进入 `else` 分支依然会被直接 `rm -f` 删掉，使得安全合规等关键信息丢失。",
      "fix": "在重构逻辑中，将“未知 type”及“解析失败”的兜底行为改为**安全保留**（mv 到 `.correction.unknown` 或忽略），严禁在无法明确判定 type 时执行 `rm -f`。"
    }
  ],
  "minor": [
    {
      "file": "DESIGN §4.1 / l3-review.sh",
      "issue": "降级时写 correction 操作与 Hook 生命周期存在时序上的矛盾。",
      "why": "L3/L2 审查均在 Stop hook 执行。Stop hook 执行完毕后，控制权立即交还给 Agent 或结束会话，随后触发 SessionStart 收割 `.correction`。在 Stop 阶段写入 `.correction` 供下一次 SessionStart 读取是可行的，但如果会话被强制中止或用户紧接着手动修改 `.flow-active`，覆盖逻辑（且只防 compliance）可能引发竞态。",
      "fix": "在 ADR-013 (correction 策略) 中明确声明该写入仅限于 Stop hook 阶段的安全重试边界，并要求在实现时复用 `jq_atomic_write` 保证写入原子性，避免半成品文件导致收割阶段 JSON 解析失败。"
    }
  ],
  "verdict": "fail",
  "summary": "架构设计清晰且对既有抽象把控得当，但未能彻底修复单文件覆盖的删除问题，存在违背「最弱环节保护」的高危安全回归，需修正重构兜底逻辑。"
}
```
```

L3_artifact_hash: b5d4ac1db921c25b47126e00c48da3463859051fd18e24358f8d9fe11e6c3528

---

## L3 重审（glm-5.1 外部模型 · 2026-07-23 02:38）

> 自动生成于 2026-07-23 02:38。由 l3-review.sh 写入。

### 审查结论

```json
```json
{
  "critical": [],
  "major": [
    {
      "file": "DESIGN.md §0.5",
      "issue": "ADR 决策依据缺失且核心决策未归档为 ADR：设计宣称 supersede ADR-006 并将引入 ADR-012/013，但在提供的 ADR 上下文与 DESIGN 正文中，完全缺乏这两个新增 ADR 的具体内容与决策权衡。此外，对于影响存量 CC 用户的不兼容变更（移除 L2 fallback 导致原有不报错的用户遭遇阻断），文中仅以一句“有意的兼容性权衡”带过，未在此将其正式确立为一项架构决策（ADR）。",
      "why": "DESIGN 阶段的核心是确立架构与产品决策。不兼容行为变更和降级机制（原本直接抛错/有 fallback，现改为写 correction 并 return 3）涉及深层次的契约变动，缺乏对应的 ADR 记录意味着该决策未经过严格审视，后续实现与测试将缺乏权威的验收基线。",
      "fix": "在 DESIGN 文件中显式补全 ADR-012（L2/L3 模型配置解耦）与 ADR-013（Correction 策略及降级行为）的完整内容，包括背景、决策、移除 L2 Fallback 的不兼容性权衡以及 supersede 机制的影响评估。"
    },
    {
      "file": "DESIGN.md §0.5 / §4.3",
      "issue": "修改既有跨模块契约引发连带超限：文中明确指出 `flow-kit-resume.sh:127` 的 `rm -f "$compliance_correction_file"` 是无条件删除的既有 bug，而为了满足 AC-6，本次修改将顺带修复该 bug 以实现 l2-missing 的“真正持久化”。然而在 §0.5 中却界定“触碰的既有模块...本次动作：扩展：新增 model-missing 收割分支”，且风险段未提及修复既有 bug 带来的行为变更风险。",
      "why": "修复既有 correction 生命周期 bug 是一项重大的跨模块契约变更。原本假定 correction（如 l2-missing）读后即焚的下游逻辑或测试，会因“顺带修复”而产生连锁失效或行为预期断裂。该修改扩大了本应聚焦于“解耦模型配置”的变更范围，属于深模块边界感知失误。",
      "fix": "在 §0.5 架构对齐表与 §8.5 风险段中，明确将“修复 resume.sh 无条件删除 bug 并变更 l2-missing 生命周期”标记为破坏性变更，并补充该既有契约修改对其他 correction 消费者的回归测试防御策略；或者严格克制本次修改，不修复既有 bug（改为只针对新增分支避免 rm）。"
    },
    {
      "file": "DESIGN.md §4.1",
      "issue": "correction 多模块并发写入存在严重时序竞态（TOCTOU），设计提供的缓解策略不足：文中提到 compliance 与 model-missing 可能并发，缓解方案是“model-missing 写入前检查当前 correction 若 type 为 compliance 则不覆盖”。这属于典型的 Check-Then-Act 漏洞。",
      "why": "如果在 model-missing 的 jq read 检测之后、write 覆盖之前，compliance 恰好写入文件，model-missing 的 `jq -n '{...}' > file` 仍会无条件覆盖掉 compliance，导致安全违规信息被遮蔽。文中声称要“沿用既有 l2-missing 覆盖写模式”，但引入并发优先级判定实际上突破了原有的覆盖写抽象边界。",
      "fix": "放弃在调用层进行 Check-Then-Act。若真存在高并发安全诉求，必须在底层 `correction-file.sh` 提供“基于 jq 原子 merge 写”（如 `jq -e 'if .type=="compliance" then . else $new end'`）的强一致函数，或者通过引入 `flock` 机制保证 correction 文件多进程互斥。"
    }
  ],
  "minor": [
    {
      "file": "DESIGN.md §8.5",
      "issue": "风险段内容被异常截断（Text truncated）：R2 上线风险的描述在“未设 `ANTHROP` 处戛然而止，后续缺失缓解措施与风险定级。",
      "why": "审查上下文残缺导致无法判断是否遗漏了关键风险定义。",
      "fix": "补齐关于 L2 fallback 移除对存量用户产生阻断影响的完整风险评估（概率、影响级别、回滚策略）。"
    },
    {
      "file": "DESIGN.md §4.3",
      "issue": "异常 type 的处理契约存在逻辑不一致：伪代码规定 `else` 分支针对未知 type 异常清除并 `rm -f "$file"`，但在随后紧接的注释中写明“⚠️ 删除原 :127 的无条件 rm -f（已移入各分支）”。",
      "why": "如果 rm -f 已严格移入各分支，那 else 分支中的 rm -f 既是该指令的体现也是必须的。注释的描述容易让实现者误解为 else 分支不应该执行 rm。",
      "fix": "修正注释表述为：“原 :127 的无条件 rm -f 已被拆解，合规分支执行 rm 读后清，未知分支执行 rm 异常清除，新增分支不执行 rm”。"
    }
  ],
  "verdict": "pass",
  "summary": "架构对齐查证详实，模块划分得当，但在 ADR 归档完整性、correction 并发竞态防范机制以及跨模块既有 bug 连带修复的风险声明上存在显著遗漏。"
}
```
```

L3_artifact_hash: 7debb60b7c76d46cf02a8dbcbf799ff87de13aad7dc3360bac1b4ef7930d8377
