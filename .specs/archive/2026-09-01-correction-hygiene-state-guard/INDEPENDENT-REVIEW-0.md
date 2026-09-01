# 独立审查 · 阶段 0（gate 0→1）

> 审查对象：`.specs/correction-hygiene-state-guard/CHANGE.md`（draft）
> 审查方式：独立盲审。只依据工件 + 全仓 grep/实测验证，未与作者沟通。
> 审查日期：2026-08-31
> 审查员：独立盲审（gate 0→1）

---

## 0. 验证方法说明

- **代码锚点**：`flow-kit-bundle/hooks/stop/33-flow-active-integrity.sh`、`flow-kit-bundle/hooks/stop/29-independent-review.sh`、`flow-kit-bundle/hooks/stop/lib/correction-file.sh`、`flow-kit-bundle/hooks/session-start/flow-kit-resume.sh`、`flow-kit-bundle/hooks/stop/28-weak-model-compliance.sh`（L-031：跨文件锚点全仓 grep + 实读核对）。
- **运行时证据**：`/home/hellrabbit/chisel_env/`（非本仓库，为 CHANGE 所述现场）实测 `.flow-active` 与 `.flow-active.correction`。

### 已核实的工件声明（pass 依据）

| CHANGE 声明 | 验证结果 | 证据 |
|---|---|---|
| ① 33号 `_fai_append_violation` 只增不清（L249-263） | ✅ 属实 | 函数定义 `33-flow-active-integrity.sh:249-288`，追加逻辑 `jq '.violations += [$entry]'` 在 L276；全函数无去重/清除/上限 |
| ① 29号 l2-missing flag（L24-30）无清除路径 | ✅ 属实 | `29-independent-review.sh:24-30` 仅写不清；`flow-kit-resume.sh:163-167` 明确"保留不删"；全仓无 `write_l2_missing_clear`；对比 `write_model_missing_clear`（`correction-file.sh:132-145`）存在 |
| ① 50 条 violation = 43 corrupt_json + 6 artifact_missing + 1 | ✅ 实测完全吻合 | `chisel_env/.flow-active.correction`：`type: l2-missing+state-integrity`，50 条 = corrupt_json 43 + pipeline_phase_artifact_missing 6 + phase_artifact_missing 1 |
| ② .flow-active 为 YAML（外来状态） | ✅ 实测属实 | `chisel_env/.flow-active` 首行 `change_id: traceweave-skill-mining`（YAML），`jq empty` 报 `parse error: Invalid numeric literal` |
| ② jq 静默短路：29 L38 / 33 L25 | ✅ 属实 | `29:38` `jq empty ... \|\| exit 0`；`33:25` `if ! jq empty ... then 追加 corrupt_json; return 0` |
| ③ 影响面文件真实存在 | ✅ 属实 | `33-flow-active-integrity.sh` / `29-independent-review.sh` / `lib/correction-file.sh` 均存在；`test/test_correction_hygiene.bats` 尚未创建（新增项，合理） |
| ⑤ 回归基线 752+ | ✅ 不虚报 | 实测 `test/` 772 个 `@test`、`flow-kit-bundle/test/` 772 个（当前数 > 声明的 752 基线） |
| ⑦ 无实现细节越界 | ✅ 通过 | 全文描述行为（去重/容量/退场/yield），无 jq/代码片段 |

---

## Findings

### 🔴 Critical

无。

---

### 🟡 Important（入 fix loop）

#### F-1 · 验收线 AC3 与 What 机制互斥：YAML 场景下 "state-integrity 类清空" 无对应实现路径

- **Symptom**：CHANGE.md:41（AC3）承诺「YAML .flow-active + 陈旧 correction（50 条）输入 → 新 hook 首轮收敛（**state-integrity 类清空** + 恰 1 条 foreign-state note）」；但 CHANGE.md:14（F1 健康清零）触发条件为「当 .flow-active 为**合法 flow-kit JSON** 且本轮全部检查通过时清空」；CHANGE.md:17（F2）对外来文件只写「跳过 pipeline 检查 + 一条去重的 foreign-state note」，未声明清除既有 state-integrity 条目。
- **Source**：F1 健康清零的触发前提（合法 flow-kit JSON）与 AC3 的场景输入（YAML 外来文件）互斥——YAML 下 F1 永不触发；F2 只追加 note 不清理。三处（F1/F2/AC3）对「陈旧 state-integrity 条目在 YAML 场景下如何消失」的约定断裂。
- **Consequence**：按当前 What 实现，AC3 无法通过（50 条陈旧 violation 在 YAML 场景下无任何清除路径，与 Why 目标「陈旧 correction 让每次查看都像 L2 缺失」直接冲突）；若为过 AC3 硬实现「外来时清空 state-integrity」，则产生 What 未声明的行为。
- **Remedy**：在 F1 或 F2 显式补充一条：检测为外来（非 flow-kit）状态文件时，一并清空既有 state-integrity 类 violation（这些条目本就源自对 YAML 的误判），并同步到 AC3 表述；或在 AC3 中改期望为「state-integrity 类不再新增 + foreign-state note 单条化」。

#### F-2 · 影响面与 F2 范围不一致：同型 `jq empty || exit 0` 的 31/32/34 号未列入亦未显式排除

- **Symptom**：CHANGE.md:17（F2）声明「29/33 号（**及读取 .flow-active 的其他 stop 模块**）在 jq empty 失败时不再静默 exit 0…改为 foreign-state note」；CHANGE.md:22-26（影响面）仅列 33/29/correction-file.sh/bats。全仓 grep 实测：`jq empty ... || exit 0` 静默短路模式同样存在于 `31-auto-advance.sh:25`、`32-fallback-guard.sh:27`、`34-archive-commit-check.sh:28`。
- **Source**：F2 措辞「其他 stop 模块」与影响面清单不一致——要么影响面低报（漏 31/32/34），要么 F2 范围含糊（「其他」未界定为哪些）。
- **Consequence**：若 31/32/34 也按 F2 各写 foreign-state note，AC3「恰 1 条 foreign-state note」在多模块场景下不成立（需跨模块去重，未声明）；若实际只改 29/33，F2 文本误导实现与验收。另注：31/32 是 pipeline 专用模块，外来状态跳过本是期望行为，未必需要 note。
- **Remedy**：在 F2 显式界定「其他 stop 模块」清单（建议：31/32/34 对外来状态保持静默跳过为期望行为、不写 note，仅 33 号写；或明确列入影响面），并在影响面勾选同步。

#### F-3 · 触碰 gate 核心链禁动（29-independent-review.sh）未登记例外

- **Symptom**：CHANGE.md:23（影响面）修改 `29-independent-review.sh`（jq 失败 yield + l2-missing 退场）；`.specs/CONTEXT.md` 禁动清单「`independent-review-gate.sh` + `29-independent-review.sh` + `fk_validate_done_marker` — gate 校验核心链」，仅 `cleanup-debt-batch-2026-08`（L-072 fix）有一次性例外（允许重排 L58-65/L181-185）。本 CHANGE 全篇未提及该禁动条目、未申请例外。
- **Source**：禁动清单对核心链修改要求显式例外登记（先例：cleanup-debt-batch-2026-08 例外条款的格式），CHANGE 静默把 29 号纳入修改范围；范围排除（CHANGE.md:33）只排除了 independent-review-gate.sh / fk_validate_done_marker / 00-gate.sh，独留 29 号在范围内且无例外声明。
- **Consequence**：违反项目既有约定（八项核对第 ⑧ 条）；后续 6-review / gate 可能因禁动清单拦截；与既有例外机制不一致。
- **Remedy**：在「范围排除」或新增「例外登记」段，仿 cleanup-debt-batch-2026-08 格式登记：本 change 允许修改 29 号的 jq-fail yield 分支与 l2-missing 退场逻辑，其余 gate 校验核心链部分保持禁动。

#### F-4 · F1 健康清零的 state-integrity 类枚举遗漏 `change_id_null_with_dirs`

- **Symptom**：CHANGE.md:14 健康清零清单 = corrupt_json / change_id_dangling / phase_artifact_missing / pipeline_* / stale_updated_at / token_spent_unmaintained；33号 实际写入的 check 名（`33-flow-active-integrity.sh:26,68,79,116,146,163,178,200,219`）= corrupt_json / change_id_dangling / **change_id_null_with_dirs** / phase_artifact_missing / pipeline_phase_artifact_missing / pipeline_gate_not_passed / pipeline_gate_phase_mismatch / stale_updated_at / token_spent_unmaintained。`change_id_null_with_dirs`（L79）未列入。
- **Source**：枚举清单与 33号 真实 check 名集合比对，漏 1 项。
- **Consequence**：陈旧 change_id_null_with_dirs violation 不会被健康清零清除，Why 目标「陈旧 correction 让每次查看都像 L2 缺失」对该类 violation 未达成。
- **Remedy**：补列 `change_id_null_with_dirs`，或说明其不属于 state-integrity 类的理由。

#### F-5 · F1 去重/容量上限作用域未界定，可能误删 compliance 类型 violation（与 ADR-013 compliance-priority 冲突）

- **Symptom**：CHANGE.md:13「`_fai_append_violation` 增加去重（同 check+field 只保留最新一条）与容量上限（violations ≤ 10 条，FIFO 淘汰）」未声明作用域。实测 `.flow-active.correction` 的 `violations[]` 数组由 33号（state-integrity）与 28号（compliance，`28-weak-model-compliance.sh:54,65,76` write_compliance_correction）**混写同一数组**（实测 type=l2-missing+state-integrity 共存于同一文件）。
- **Source**：去重 key（check+field）与 FIFO 淘汰作用于整个 violations[] 数组时，会跨类型比较/淘汰——compliance 条目（L1/L2/L3 合规安全信息）可能被 state-integrity 的同名 check 去重，或被容量上限 FIFO 逐出。
- **Consequence**：违反 ADR-013 compliance-priority（model-missing 写入时都刻意保留 compliance 信息，`correction-file.sh:93-94,117`）；弱模型合规矫正信息（保护安全的数据）可能被本 change 的去重/容量逻辑误删。风险段（CHANGE.md:43-48）只覆盖「健康清零过早」，未覆盖此交互。
- **Remedy**：在 F1 显式限定去重与容量仅作用于 state-integrity 类条目（按 check 名前缀或 type 分段），并纳入风险段；或改为按 type 分段存储。

---

### 🟢 Minor（登记）

#### M-1 · `_fai_append_violation` 行号范围不精确

- **Symptom**：CHANGE.md:7 声明「L249-263」；实测函数定义为 `33-flow-active-integrity.sh:249-288`，L263 仅为 read-merge-write 的 if 条件行，真正的追加语句 `.violations += [$entry]` 在 L276。
- **Source**：行号范围只覆盖函数头部，未覆盖追加逻辑所在行。
- **Consequence**：核验时可复现性略降；行为声明本身（只增不清）经验证属实，不影响结论。
- **Remedy**：改为「L249-288」或「`_fai_append_violation` 函数（L249+）」。

#### M-2 · 「12 天」与实测时间跨度不符（17 天）

- **Symptom**：CHANGE.md:7-8 称「12 天累积 50 条 / 46 次/12 天」；实测 `chisel_env/.flow-active.correction` 的 detected_at 跨度 2026-08-14T02:25:47 → 2026-08-31T00:58:26 = **17 天**。50 条的数量与分类完全吻合（见验证表），但天数口径不一致。
- **Source**：现场数据统计窗口与 CHANGE 表述差异（可能「12 天」为 46 次 Stop 的统计窗口，与 oldest violation 起始日不同）。
- **Consequence**：Why 数据引用口径轻微不一致，不影响缺陷成立性。
- **Remedy**：统一口径或注明统计窗口。

#### M-3 · 外来格式的写入源待 DESIGN 确认（chisel-skill 文档与运行时矛盾）

- **Symptom**：CHANGE.md:8 称 chisel-skill「有自己的 YAML 状态约定」；实测运行时 `chisel_env/.flow-active` 确为 YAML（属实），但 chisel-skill 自身文档 `SKILL.md:142` 声明「.flow-active — 当前 change/phase/task 状态（**JSON**）」，`SKILL.md:137` 亦写「.flow-active JSON 状态文件」。
- **Source**：chisel-skill 文档与运行时写入格式不一致（文档过时或另有 YAML 写入源，如 auto-checkpoint.sh 或外部流程）。
- **Consequence**：CHANGE 结论（运行时为 YAML）正确，但「YAML 状态约定」的归属描述与 chisel-skill 官方文档冲突；2-design 阶段需确认 YAML 实际写入者，避免「外来格式一律让位」策略在写入源切换（YAML→JSON）时误判为合法 flow-kit 文件。
- **Remedy**：DESIGN 阶段核实 YAML 写入源并记录；CHANGE 措辞可改为「chisel_env 运行时实测 .flow-active 为 YAML（与 chisel-skill 文档声明的 JSON 不一致）」更严谨。

#### M-4 · 影响面中 correction-file.sh 标注「如需共享去重 helper」为条件性

- **Symptom**：CHANGE.md:24「`lib/correction-file.sh`（如需共享去重 helper）」；禁动清单「`hooks/stop/lib/correction-file.sh` 4 函数签名 — 修改需同步更新 interactive-ui-check.sh + weak-model-compliance.sh」。
- **Source**：影响面条目带条件（「如需」），未定死是否落盘；新增 helper（非改 4 签名）不触发同步要求，但若演进为改签名则需同步两调用方。
- **Consequence**：影响面可判定性略降；在 gate 1 前需定夺是否新增 helper。
- **Remedy**：将「如需」改为确定项（新增 `correction_file_dedupe` 之类的新函数、不改 4 签名），或在 1-requirement 定案。

---

## 八项核对汇总

| # | 核对项 | 结论 |
|---|---|---|
| ① | Why 具体且可追溯 | ✅ 主体成立（行号锚点 + 实测 50 条数据完全吻合）；M-1/M-2 行号与天数口径微调 |
| ② | What 与 Why 逐条对齐 | ⚠️ F-4（枚举漏项）、F-5（作用域未定）；其余对齐 |
| ③ | 影响面勾选无高报低报 | ⚠️ F-2（"其他 stop 模块"未入影响面）；所列文件均真实存在 |
| ④ | 范围排除无内部矛盾 | ✅ 排除项与影响面（分发包 + 运行时部署）一致，无矛盾 |
| ⑤ | 验收线可判定且 What 全追溯 | ⚠️ F-1（AC3 的 state-integrity 清空无 What 机制支撑）；基线 752+ 实测 772 不虚报 |
| ⑥ | 风险段覆盖已知未知 | ⚠️ F-5（去重/容量与 compliance 交互未覆盖）；四大已知风险均已覆盖 |
| ⑦ | 无实现细节越界 | ✅ 通过 |
| ⑧ | 与项目既有约定无冲突 | ⚠️ F-3（29 号 gate 核心链禁动未登记例外）；命名/双源/测试约定无冲突 |

---

## Verdict

**pass**（无 🔴 Critical；5 项 🟡 Important 入 fix loop，建议 gate 1 前处理 F-1/F-3/F-5）

工件核心事实经独立实测全部成立（50 条 violation 构成、YAML 外来格式、只增不清机制、l2-missing 无退场），Why/What 主干可信。阻塞性缺陷不存在；但 AC3 与 What 的机制互斥（F-1）、gate 核心链禁动例外缺失（F-3）、去重容量对 compliance 安全数据的作用域未定（F-5）三项需在进入 1-requirement 前闭环。

---

## 主 agent 响应（2026-08-31 · fix loop）

> 盲审原文保持原样，以下为主 agent 对每条发现的处置。不改盲审结论。

- **F-1 ✅ Fixed in CHANGE.md**：F2 补充「外来判定时**一并清空既有 state-integrity 类 violation**（源自对非 JSON 文件的误判，外来接管后全部失效）」——AC3 的「state-integrity 类清空」现在有对应 What 机制（清空条件 = 外来判定，与 F1 健康清零的合法 JSON 条件正交，两路径均可达清空）。
- **F-2 ✅ Fixed in CHANGE.md**：F2 范围收窄为「**29/33 号**」；范围排除段新增显式条目「不改 31/32/34 的 `jq empty || exit 0` 静默跳过——pipeline 专用模块，外来状态跳过是期望行为，不写 note（避免多模块每 Stop 重复 note）」。AC3「恰 1 条 foreign-state note」在单写入者（33 号）下成立。
- **F-3 ✅ Fixed in CHANGE.md**：新增「## 例外登记」段，仿 cleanup-debt-batch-2026-08 格式——29 号允许修改 jq 失败分支（L36-40 yield）与新增 l2-missing 退场，其余 gate 核心链部分保持禁动；33 号条款（「无关 change」）已说明本 change 属"有关"修改并登记说明保持审计链完整。
- **F-4 ✅ Fixed in CHANGE.md**：健康清零枚举补 `change_id_null_with_dirs`，并注明「完整枚举对齐 33 号实际写入的 9 种 check 名」。
- **F-5 ✅ Fixed in CHANGE.md**：F1 去重/容量显式限定作用域「仅 state-integrity 类条目（以 33 号自身写入的 check 名集合界定），compliance 类条目（28 号写入）不参与去重与容量淘汰（ADR-013 compliance-priority）」；风险段新增第 5 条「去重/容量误伤 compliance 条目」及缓解。
- **M-1 ✅ Fixed**（Why 行号改 L249-288，追加语句 L276）；**M-2 ✅ Fixed**（12 天 → 17 天 2026-08-14→08-31）；**M-3 ✅ Fixed**（Why 措辞改为「运行时实测 YAML，与 chisel-skill 文档 SKILL.md:142 声明的 JSON 不一致，实际写入源待 2-design 确认」）；**M-4 ✅ 定案**（影响面改为「新增共享去重 helper 函数，不改既有 4 函数签名，不触发两调用方同步要求」）。
- 需确认项（M-3）答复：YAML 写入源核实列入 2-design 必查项（auto-checkpoint.sh / chisel-skill 运行时 / 外部流程三方排查），「外来格式一律让位」策略在写入源切回 JSON 时天然安全（合法 JSON 即受 pipeline 管辖）。

---

## L2 复核（第 2 轮 · 2026-08-31）

> 复核对象：CHANGE.md 修订版（全文）+ 上段主 agent fix 响应。只依据文件内容判定，不采信声明本身。

### 逐条核验（对照第 1 轮 Symptom/Remedy）

- **F-1 ✅ Fixed**：CHANGE.md:17（F2）已补「外来判定 → 跳过 pipeline 检查 + **一并清空既有 state-integrity 类 violation**（这些条目源自对非 JSON 文件的误判，外来接管后全部失效）」。AC3（:47）「state-integrity 类清空 + 恰 1 条 foreign-state note」现由 F2 外来清空路径支撑；F1 健康清零（:14，触发前提=合法 flow-kit JSON）与 F2（触发前提=外来判定）两路径正交，均可达清空。AC3 与 What 重新对齐，第 1 轮互斥解除。
- **F-2 ✅ Fixed**：CHANGE.md:17 F2 范围收窄为「**29/33 号**」，删除原「（及读取 .flow-active 的其他 stop 模块）」含糊措辞；范围排除（:35）新增显式条目「不改 31-auto-advance.sh / 32-fallback-guard.sh / 34-archive-commit-check.sh 的 `jq empty || exit 0` 静默跳过——三者是 pipeline 专用模块，外来状态时静默跳过本就是期望行为，不写 foreign-state note（避免多模块每 Stop 重复 note）」。与第 1 轮全仓 grep 实测（31:25 / 32:27 / 34:28）逐一对上。AC3「恰 1 条」在单写入者 + foreign-state 去重（同 check 只写一次）语义下成立。
- **F-3 ✅ Fixed**：CHANGE.md:38-41 新增「## 例外登记（禁动清单冲突声明 · 仿 cleanup-debt-batch-2026-08 格式）」——29 号允许修改 jq 失败分支（L36-40 yield 改造）与新增 l2-missing 退场逻辑（对齐 `write_model_missing_clear` 范式），其余 gate 校验核心链部分（.done 校验、gate 判定语义）保持禁动；33 号「不应被无关 change 修改」条款已声明本 change 属"有关"修改并登记。格式（例外=范围+理由+期限声明）与 cleanup-debt-batch 先例对齐。
- **F-4 ✅ Fixed**：CHANGE.md:14 健康清零枚举补 `change_id_null_with_dirs`，并注明「完整枚举对齐 33 号实际写入的 9 种 check 名」。逐项清点：corrupt_json / change_id_dangling / change_id_null_with_dirs / phase_artifact_missing / pipeline_phase_artifact_missing / pipeline_gate_not_passed / pipeline_gate_phase_mismatch / stale_updated_at / token_spent_unmaintained = 恰 9 种，与第 1 轮实测 check 名集合（L26/68/79/116/146/163/178/200/219）完全一致。
- **F-5 ✅ Fixed**：CHANGE.md:13 去重/容量显式限定「**作用域仅限 state-integrity 类条目**（以 33 号自身写入的 check 名集合界定），compliance 类条目（28 号写入）不参与去重与容量淘汰（ADR-013 compliance-priority）」；风险段（:54）新增「去重/容量误伤 compliance 条目」条目及缓解（按 check 名集合界定 + compliance 条目原样保留）。第 1 轮指出的风险段空白已补。

### 新矛盾检查（AC↔What、影响面↔范围排除）

- **AC↔What**：AC1（:45）五项（去重/容量/健康清零/l2-missing 退场/foreign-state 单条化）全部有对应 What 机制（:13-17）。AC1 l2-missing 触发仅列「IR 含 L2 段」子集，What（:15）增「或 gate 非 both」且与风险段（:51）一致——AC 为 What 的可满足子集，非矛盾。AC3（:47）YAML 首轮收敛（清空 + 恰 1 note）+ 后续零新增，均被 F2（:17）机制覆盖且可判定。
- **影响面↔范围排除**：影响面（:22-26）列 33/29/correction-file.sh/bats/部署面；范围排除（:28-36）排除 YAML 解析、chisel-skill 仓库、.flow-active schema、gate 核心链（independent-review-gate.sh / fk_validate_done_marker / 00-gate.sh）、30-ai-analyze.sh、31/32/34；例外登记（:38-41）覆盖 29 号的禁动冲突。无低报/高报、无交叉矛盾。
- **M-1..M-4 处置核验**：Why:7 行号改「L249-288，追加语句在 L276」、天数改「17 天（2026-08-14 → 2026-08-31）」；Why:8 措辞改「运行时实测 .flow-active 为 YAML 格式（与 chisel-skill 自身文档 SKILL.md:142 声明的「JSON」不一致，实际写入源待 2-design 确认）」；影响面 :24 correction-file.sh 条目由「如需」改为确定项（「新增共享去重 helper 函数，不改既有 4 函数签名，不触发两调用方同步要求」）。全部落实。

### 复核中检查的边界点（均判定非新问题）

1. F2（:17）「不再静默 exit 0 / 不再追加 corrupt_json」为 29/33 两模块行为的合述（第 1 轮实测：29:38 静默 exit 0、33:25 追加 corrupt_json）——非新引入矛盾。
2. AC1 与 What 的 l2-missing 触发条件为子集关系，AC 表述仍可判定、可满足——非矛盾。

### L2 复核 Verdict

**pass**（5 项 🟡 F-1..F-5 全部真实修复，修复未引入新 🔴/🟡；4 项 🟢 M-1..M-4 全部落实；AC 与 What 重新对齐，影响面与范围排除一致）
