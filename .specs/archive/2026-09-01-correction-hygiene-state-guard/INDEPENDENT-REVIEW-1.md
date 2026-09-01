# 独立审查 · 阶段 1

## L2 盲审

- **change-id**：correction-hygiene-state-guard
- **阶段**：1（1-requirement）
- **审查日期**：2026-09-01
- **审查员**：L2 独立盲审员（固化指令模式）
- **工件**：`REQUIREMENT.md`（10 条 AC）· 参考 `CHANGE.md`（修订版）
- **独立性声明**：输入仅含两份工件文件路径与其内容，无主 agent 自评/草稿/概述/辩护注入。

---

### 0. 跨文件一致性核验（L-031 闭合 · 锚点 grep）

对本 change 引用的所有既有代码锚点逐一 `grep -rn` 核实（阶段 1 无代码 diff，核验「引用是否真实存在且描述一致」）：

| 锚点 | 声称 | 实测 | 结论 |
|---|---|---|---|
| `_fai_append_violation` | 33-flow-active-integrity.sh L249-288（追加语句 L276） | 定义于 L249 ✓；9 处调用 L26/68/79/116/146/163/178/200/219 ✓；merge 写 `.violations += [$entry]` L277 ✓ | 列出且已存在 |
| AC-3 的 9 种 check 名 | corrupt_json / change_id_dangling / change_id_null_with_dirs / phase_artifact_missing / pipeline_phase_artifact_missing / pipeline_gate_not_passed / pipeline_gate_phase_mismatch / stale_updated_at / token_spent_unmaintained | 与 9 处调用实传 check 名逐字一致 | 列出且已存在 |
| 33 号 `jq empty` | L25 | L25 `if ! jq empty "$flow_active"` ✓ | 列出且已存在 |
| 29 号 `jq empty` | L38 | L38 `jq empty ... || exit 0` ✓ | 列出且已存在 |
| 29 号 l2-missing 写入 | L24-30 | `_write_l2_missing_correction()` L24-30，`jq -n >` **覆盖写**（无 violations[] 数组）✓ | 列出且已存在 |
| 31/32/34 静默跳过 | `jq empty \|\| exit 0` | 31 号 L25 / 32 号 L27 / 34 号 L28 全部一致 ✓ | 列出且已存在 |
| `write_model_missing_clear` | 既有退场范式 | correction-file.sh:132，**文件级** `rm -f`（`.type` 精确匹配才删）✓ | 列出且已存在 |
| correction-file.sh 4 函数 | 不改签名 | exists(L16)/read(L25)/write(L47)/clear(L83) ✓ | 列出且已存在 |
| 28 号 compliance 混写同文件 | `.flow-active.correction` violations[] 混写 | weak-model-compliance.sh:61 `COMPLIANCE_CORRECTION_FILE="${project_root}/.flow-active.correction"` + L111 `correction_file_write ... "merge"` ✓ | 列出且已存在 |
| ADR-013 | AC-10 依据 | `.specs/adr/013-correction-overwrite-strategy.md` 存在，但见 R5 | 存在但引述偏差 |
| bats 基线 | 基线 752+，实测当前 772 | test/ 与 flow-kit-bundle/test/ 均 772 `@test`（双源一致）✓ | 列出且已存在 |

**L-031 结论**：无「漏列且未改」锚点，无 🔴 Critical；但锚点核实暴露 3 处规格内部矛盾/陷阱（R1/R2/R3）与 2 处引述不精确（R4/R5），详见下。

---

### 1. 发现清单

### 🟡 R1 · CHANGE.md F2 与 AC-5/AC-6 对 29 号外来路径行为描述冲突：同一行为三处三种说法

**Severity**：🟡 Important

**Symptom（症状）**：
- `CHANGE.md:17`（F2）：「**29/33 号**在 `jq empty` 失败时**不再静默 exit 0** …改为：跳过 pipeline 检查 + 一并清空既有 state-integrity 类 violation + 写 foreign-state note + stop-hook-report 提示一次」——把完整外来处理（清空+写 note）同时归给 29 号和 33 号。
- `CHANGE.md:35`（范围排除）与 `CHANGE.md:79`（v1 范围）：「29 号：jq 失败 yield 改造（**静默退出，不写 correction**）」。
- `REQUIREMENT.md:42`（AC-5 And）：「29 号同条件下静默退出（**不写任何 correction**）」+ `REQUIREMENT.md:48`（AC-6）：「When **33 号**执行外来让位处理」。
- 三处对 29 号在外来路径是否参与「清空 + 写 note」给出冲突答案：F2=参与，v1 范围/AC-5=不参与。

**Source（源头）**：`CHANGE.md:17` vs `CHANGE.md:35,79` vs `REQUIREMENT.md:42,48` 相互矛盾；AC-9「恰含 1 条 foreign-state note」依赖唯一写 note 方。

**Consequence（后果）**：2-design/4-dev 按 CHANGE.md F2（权威参考）实现 → 29 号也写 note/清空 → 违反 AC-5 验收契约，且双模块写 note 依赖去重兜底（脆弱）；按 AC-5 实现 → 与 F2 文字不符，review 时来回拉锯。AC-9「恰含 1 条」的成立前提（唯一写 note 方）被模糊化。该矛盾在 6-review 前不暴露则进 fix loop 返工。

**Remedy（修补）**：以 AC-5（验收契约）为准统一文案——外来让位的全部动作（跳过+清空+写 note）归 33 号；29 号仅保留「静默退出」；同步改写 CHANGE.md:17 F2 的「29/33 号」为「33 号（29 号保持静默）」并注明 29 号的 yield 改造仅是显式化既有 `exit 0` 行为（对照：现状 L38 已是 `jq empty || exit 0`，本次改动面应写明）。

---

### 🟡 R2 · AC-6「仅保留去重后的 foreign-state note」与 AC-3/AC-10 的保留集合冲突：外来路径下 l2-missing/compliance 去留未定义

**Severity**：🟡 Important

**Symptom（症状）**：
- `REQUIREMENT.md:48`（AC-6 Then）：「既有 state-integrity 类 violation 一并清空…**仅保留去重后的 foreign-state note**」。
- 字面读 = 外来清空后 correction **只剩** foreign-state note → compliance 也被清 → 直接违反 `REQUIREMENT.md:72`（AC-10：「compliance 类条目…不被清空」，且 AC-10 When 显式涵盖「外来清空任一逻辑执行」）；也与 `REQUIREMENT.md:29`（AC-3 健康清零保留 l2-missing / model-missing / foreign-state / compliance）的保留集合不一致。
- 缓和读（「state-integrity 类内仅剩 foreign-state note，其余类型保留」）与 AC-10 自洽，但该读法要求 l2-missing 在外来路径保留——REQUIREMENT 未在任何 AC 中写明外来路径的 l2-missing 处理；AC-9 输入的第 50 条（推测 l2-missing，见 R4）在收敛后是保留还是清除，决定 violations 数组终态长度是 2 还是 1，直接影响 AC-9 bats 断言。

**Source（源头）**：`REQUIREMENT.md:48` vs `REQUIREMENT.md:29,72`；AC-9（`REQUIREMENT.md:64-66`）依赖该保留集合未定义。

**Consequence（后果）**：4-dev 按字面实现 AC-6 会写一个清空全文件的外来分支 → 违反 AC-10 且误删 l2-missing 持久化记录；bats 断言与实现错位（假绿或假红）。属验收契约内部矛盾，应在进入 2-design 前消除。

**Remedy（修补）**：AC-6 改为显式枚举外来清空的保留集合，例如「清空 state-integrity 类 violation（9 种 check 名）；l2-missing / model-missing / compliance / foreign-state 保留」，并在 AC-9 的 Given 中写明第 50 条的类型及其终态（保留/清除），使「恰含 1 条 foreign-state note + violations 长度」的断言可机器判定。

---

### 🟡 R3 · AC-1 去重使 AC-2 的 10 条容量上限触发条件不可达：FIFO 成为死功能

**Severity**：🟡 Important

**Symptom（症状）**：
- AC-1（`REQUIREMENT.md:15-17`）去重键 = `check`+`field`；已逐一核实 9 个 check 名的 `field` 实参**全部为常量**（.flow-active / .flow-active.change_id ×2 / .flow-active.phase / .flow-active.goal.phases_done / .flow-active.goal.gates ×2 / .flow-active.updated_at / .flow-active.token_spent，见 33-flow-active-integrity.sh 调用点）。
- 故去重后 state-integrity 类最多 9 个互异 (check,field) 键；AC-2（`REQUIREMENT.md:21-23`）的触发条件「写入第 11 条」需 ≥11 个互异键——**实际不可能出现**，FIFO 淘汰永不触发。
- CHANGE.md:45（验收线 1）同时要求去重 + 容量两条 bats 用例——容量用例只能靠绕过 AC-1 的造假 fixture（同 check 不同 field）构造，与真实 9-check 场景脱节。

**Source（源头）**：`REQUIREMENT.md:15-23`（AC-1/AC-2）相互作用；33-flow-active-integrity.sh 的固定 field 实参（实测）。

**Consequence（后果）**：容量逻辑与测试为不可达死代码，浪费实现与维护成本；更危险的是——若 4-dev 为让容量「可用」而放宽去重范围或改动 field 传参，可能破坏 AC-1 的收敛语义。验收契约内部不自洽，toll-gate 前应裁掉或重新定位。

**Remedy（修补）**：三选一并在 REQUIREMENT 写明：(a) 删除 AC-2 容量上限（YAGNI，去重已足够收敛）；(b) 保留为不可达 backstop，AC 明示「防御性上限，当前 9-check 场景不可达，测试用合成 fixture」；(c) 若真需要容量语义，将阈值降至去重后可达的边界（如 >9）或扩去重作用域。同时规定去重与容量的执行顺序（先去重后 FIFO，或相反）。

---

### 🟢 R4 · AC-9 Given 第 50 条 violation 类型未指明：fixture 不确定

**Severity**：🟢 Minor

**Symptom（症状）**：`REQUIREMENT.md:64`「陈旧 correction（50 条，含 43 条重复 corrupt_json + 6 条陈旧 artifact_missing + 1 条）」——43+6+1=50 算术自洽，但「+ 1 条」的类型悬空；`CHANGE.md:7` 同样表述。

**Source（源头）**：`REQUIREMENT.md:64`；从 `CHANGE.md:7` 上下文可推断为 l2-missing flag，但未显式声明。

**Consequence（后果）**：bats fixture 构造不确定；配合 R2 的保留集合未定义，收敛后数组长度断言（1 或 2）有歧义。

**Remedy（修补）**：补全为「+ 1 条 l2-missing」，并在 AC-9 Then 中写明其终态（配合 R2 修复）。

---

### 🟢 R5 · 「ADR-013 compliance-priority」引述不精确：该术语与数组级保留策略均不在 ADR-013 中

**Severity**：🟢 Minor

**Symptom（症状）**：`CHANGE.md:13,54` 与 `REQUIREMENT.md:68,109` 以「ADR-013 compliance-priority」作为 AC-10（compliance 条目数组级原样保留）的依据；实测 `.specs/adr/013-correction-overwrite-strategy.md` 全文无「compliance-priority」术语，其决策是**文件级** type 覆盖优先级「compliance > model-missing」（model-missing 不覆盖在场 compliance），不涉及 violations[] 数组内条目去重/保留。

**Source（源头）**：`.specs/adr/013-correction-overwrite-strategy.md`（全文核实）；`REQUIREMENT.md:68,109`。

**Consequence（后果）**：2-design 按 ADR 字面检索不到依据，或误以为数组级保留已有 ADR 背书而跳过论证；AC-10 的合规性论证薄弱。

**Remedy（修补）**：改引述为「沿 ADR-013 的 compliance 优先精神」并注明「violations[] 数组级条目保留为本 change 新决策（2-design 需独立论证）」。

---

### 🟢 R6 · 非功能需求「性能 <50ms（不设硬门槛）」自相矛盾：数值无约束力

**Severity**：🟢 Minor

**Symptom（症状）**：`REQUIREMENT.md:101`「Stop hook 单模块增量耗时 < 50ms（不设硬门槛，延续既有 hook 链性能基线）」——给出数值又随即声明不设硬门槛。

**Source（源头）**：`REQUIREMENT.md:101`；阶段 1 检查项「非功能性需求是否完整/可验证」。

**Consequence（后果）**：性能 NFR 不可机器验证，等于未写；后续无法据此判定退化。

**Remedy（修补）**：二选一——写死可测阈值（如「Stop 单模块增量 ≤50ms，bats 计时断言」）或改为纯软目标表述（去掉数值，如「延续既有 hook 链性能基线，无新网络调用」）。

---

### 2. 已核查通过项（非发现）

- **AC 可机器验证性**：AC-1~AC-10 全部 Given/When/Then 三段齐全，无「系统应该正常工作」类空话；每条均可由 bats 或单条 shell 命令断言（AC-8 直接落到 `npx bats + make check` 四门 + `diff -rq` 双源零差异，AC-7 落到 mtime/内容不变 + grep yq/pyyaml）。
- **范围切分**：v1/v2/out 边界干净。v1 仅 33 号/29 号/correction-file.sh 新 helper + 新 bats + 部署；v2（30 号凭证链/跨模块去重/分段存储/YAML 协商）与 out（YAML 解析、chisel-skill、JSON schema、gate 核心链、31/32/34）均显式列出且理由充分（31/32/34 静默跳过本就是期望行为，不写 note 防多模块刷屏）。无悄悄塞进 v1 的范围蔓延。
- **AC-5 与 AC-9 自洽性（写 note 单条化）**：AC-5「同 check 只写一次」与 AC-9「恰含 1 条 foreign-state note + 后续 Stop 零新增」在去重键 = check 名下自洽（R2 澄清保留集合后完全可机器验证）。
- **NFR 完整性**：安全（不写/删/转外来文件 + 凭证不落盘）、兼容性（双平台 md5 校验 + JSON schema 不变）、可观测性（stderr 审计行 + note 保留原始错误文本）齐备；容量由 AC-2 覆盖（其可达性见 R3）。
- **禁动清单合规**：33 号「不应被无关 change 修改」与 29 号 gate 核心链禁动——CHANGE.md 例外登记段（L38-41）按 cleanup-debt-batch-2026-08 格式登记，声明「其余 gate 校验核心链部分保持禁动」，合规。

**Verdict**: pass

---

## 主 agent 响应（2026-09-01 · fix loop）

> 盲审原文保持原样，以下为主 agent 对每条发现的处置。不改盲审结论。

- **R1 ✅ Fixed in CHANGE.md + REQUIREMENT.md**：F2 改为「外来让位的全部动作归 **33 号**单一 actor（跳过+清空+写 note）；**29 号保持静默退出**（exit 0 行为显式化，不写 correction、不参与清空）」，与 AC-5 And（29 号静默）一致；AC-9「恰 1 条 note」成立前提（唯一写 note 方）恢复。
- **R2 ✅ Fixed in REQUIREMENT.md**：AC-6 显式保留集合「l2-missing / model-missing / compliance / foreign-state 条目全部保留，恰好新增 1 条 foreign-state note」——与 AC-3/AC-10 保留集合一致；AC-9 已配套写明第 50 条（l2-missing）终态保留，violations 终态断言可机器判定。
- **R3 ✅ Fixed in REQUIREMENT.md**：AC-2 改为「防御性 backstop」——保留 FIFO 逻辑（防未来动态 field），明示当前 9-check 场景不可达，bats 用合成 fixture（同 check 不同 field 构造 11+ 条）验证；并规定执行顺序（先去重后 FIFO）。避免死功能歧义且保留安全网。
- **R4 ✅ Fixed**（AC-9 补「1 条 l2-missing」+ 终态）；**R5 ✅ Fixed**（引述改「沿 ADR-013 精神」+ 数组级保留标注为新决策）；**R6 ✅ Fixed**（性能 NFR 去数值，改纯软目标）。
- 需确认项（R3 三选一）答复：选 (b) 保留为不可达 backstop + 合成 fixture，理由：9-check 常量为现状而非契约，未来动态 field（如新增带参数的 check）会自然触发容量语义，保留安全网成本极低。

---

## L2 复核（第 2 轮）

- **日期**：2026-09-01
- **输入**：修订版 REQUIREMENT.md（112 行）+ CHANGE.md（60 行）+ INDEPENDENT-REVIEW-1.md「主 agent 响应」段
- **核验方式**：逐条对照修订文本 + 对既有代码锚点（correction-file.sh:132 write_model_missing_clear、33 号 L271-273 type 合并）做二轮 grep 核实。只依据文件内容判定。

### R1-R6 逐条状态

- **R1: ✅ Fixed** — CHANGE.md:17-18（F2）已改「33 号单一 actor（跳过+清空+写 note）；29 号保持静默退出（exit 0 行为显式化，不写 correction、不参与清空）」；与 AC-5 And（REQUIREMENT.md:43）及 v1 范围（REQUIREMENT.md:81）三处一致，AC-9「恰 1 条 note」前提恢复。
- **R2: ✅ Fixed** — AC-6（REQUIREMENT.md:49）显式保留集合「l2-missing / model-missing / compliance / foreign-state 全部保留，恰好新增 1 条 foreign-state note」，与 AC-3（L30）/AC-10（L73）保留集合一致；AC-9（L65-67）第 50 条类型（l2-missing）与终态已写明。
- **R3: ✅ Fixed** — AC-2（REQUIREMENT.md:19-24）改为「防御性 backstop」+ 明示当前 9-check 场景不可达 + 合成 fixture（同 check 不同 field）+ 执行顺序（先 AC-1 去重、后 AC-2 FIFO）。
- **R4: ✅ Fixed** — AC-9 Given 补「+ 1 条 l2-missing」并写明终态保留。
- **R5: ❌ 部分（🟢 Minor）** — REQUIREMENT.md AC-10 标题/依据注（L69/L74）与 CHANGE.md:55（风险段）已改为「沿 ADR-013 精神 + 数组级保留为新决策」；但 **CHANGE.md:13（F1）仍残留原引述「（ADR-013 compliance-priority）」**——该术语实测不在 ADR-013 全文，R5 的整改未覆盖 F1 行。
- **R6: ✅ Fixed** — 性能 NFR（REQUIREMENT.md:103）已去数值，改纯软目标「延续既有 hook 链性能基线（无新网络/子进程开销，不设数值硬门槛）」。

### 新发现（修复引入/暴露的矛盾）

### 🟡 R7 · AC-4 的 l2-missing 退场机制与 AC-6/AC-9 新建的共存状态不兼容：混合文件中退场永不触发（或误删全文件）

**Severity**：🟡 Important

**Symptom（症状）**：
- AC-4（REQUIREMENT.md:36）引用「对齐 `write_model_missing_clear` 既有范式」——该函数（correction-file.sh:132）语义为 **type 精确匹配 + 文件级 rm**（`[[ "$cur_type" == "$mtype" ]] && rm -f "$path"`，二轮 grep 核实）。
- 但 AC-6/AC-9（REQUIREMENT.md:49,67）经 R2 修复后**显式要求 l2-missing 与 violations[] 共存**（外来路径保留 + 终态含 l2-missing）。共存态的既有实现机制是 33 号 type 合并标签（33-flow-active-integrity.sh L271-273：type="l2-missing" 文件被 33 号追加后变为 `"l2-missing+state-integrity"`，二轮 grep 核实）。
- 矛盾：混合文件中 `cur_type` 恒为 `"l2-missing+state-integrity"` ≠ `"l2-missing"` → 精确匹配永不命中 → **AC-4 退场永不触发**；若 4-dev 为「修好」改用 contains 匹配，`rm -f` 会连 state-integrity/compliance 条目一并删除（违反 AC-10、丢失健康清零语义）。
- 该矛盾非仅外来边角：**正常路径同样触发**——29 号写 l2-missing 后，下一轮 33 号追加任一 state-integrity violation 即产生合并标签，此后 l2-missing 退场失效。这正是 change 的 Why（CHANGE.md:7「l2-missing 无确定性清除路径」）要消灭的缺陷在混合态下的残留形态。

**Source（源头）**：`REQUIREMENT.md:36`（AC-4）vs `REQUIREMENT.md:49,67`（AC-6/AC-9）；`correction-file.sh:132`（write_model_missing_clear 精确匹配文件级 rm，实测）；`33-flow-active-integrity.sh:271-273`（type 合并标签，实测）。

**Consequence（后果）**：AC-9 验收场景（恰是 chisel_env 真实场景）通过后，l2-missing 仍无退场路径——验收线 1 的「l2-missing 退场」bats 只能测纯 l2-missing 文件（type 精确命中），测不到真实混合态；进入 4-dev 后按错误机制实现则需 6-review 返工。属本轮修复直接引入的契约内矛盾，须在 2-design 前消除。

**Remedy（修补）**：AC-4 显式定义混合文件的退场语义：(a) type 判定改用**前缀/包含匹配**（`"l2-missing"` 为前缀或含 `l2-missing` 组件）；(b) 清除动作改为**标签级剥离 + 条目级操作**（`"l2-missing+state-integrity"` → 剥离前缀剩 `"state-integrity"`，violations[] 保留），**禁止**沿用 write_model_missing_clear 的整文件 rm（注明该范式仅适用单 type 文件，与混合态差异须在 AC 中显式声明）。

---

### 🟢 R8 · AC-6「恰好新增 1 条 foreign-state note」在 外来→JSON→外来 再接管边角与 AC-5 去重语义冲突

**Severity**：🟢 Minor

**Symptom（症状）**：AC-6（REQUIREMENT.md:49）「correction 中**恰好新增 1 条**去重后的 foreign-state note」为无条件表述；但 AC-3（L30）保留 foreign-state 于健康清零、AC-5（L42）去重「同 check 只写一次」——若 correction 已携带上一外来期的 foreign-state note（后因 flow-kit JSON 回归而残留，再被外来接管），则再接管时按去重语义应**新增 0 条**（替换/不动），AC-6 的「恰好新增 1 条」不成立。

**Source（源头）**：`REQUIREMENT.md:49`（AC-6）vs `REQUIREMENT.md:42`（AC-5 去重）与 `REQUIREMENT.md:30`（AC-3 保留 foreign-state）。

**Consequence（后果）**：bats 若按 AC-9 fixture（无历史 foreign-state note）构造则测不出该边角；实现若无条件「+1」则破坏去重（同 check 两条）或覆盖替换而非保留，数组长度断言在再接管场景失真。影响面小（边角），但 AC-6 措辞应加条件限定。

**Remedy（修补）**：AC-6 改「correction 中 foreign-state note 收敛为恰好 1 条（不存在时新增、已存在时替换保留，数组不增加）」或加前提「Given correction 无既有 foreign-state note」。

---

### 复核结论

- R1/R2/R3/R4/R6 全部落实；R5 部分落实（🟢，CHANGE.md:13 残留一处原引述，不影响 pass/fail 判定）。
- R2 修复（AC-6/AC-9 显式共存态）**新引入** R7（🟡）：AC-4 退场机制与共存态不兼容，正常路径即触发，属契约内未闭合矛盾。
- R8（🟢）为再接管边角措辞问题，不入 fix loop，记入 MINOR-DEFERRED.md 即可。

**Verdict**: fail —— 存在未修复 🟡（R7，本轮新引入且未处置）；阻塞 toll-gate，要求先修 R7（AC-4 混合态退场语义）再进入 2-design。R8 顺带改写，R5 的 CHANGE.md:13 残留一并清理。

---

## 主 agent 响应（第 2 轮 · 2026-09-01）

> 盲审原文保持原样，以下为主 agent 对复核轮 R5 残留 / R7 / R8 的处置。

- **R5 残留 ✅ Fixed in CHANGE.md**：CHANGE.md F1 第 1 条（L13 附近）残留的「(ADR-013 compliance-priority)」已改为「沿 ADR-013 compliance 优先精神；数组级条目保留为本 change 新决策」——与 AC-10/风险段三处引述一致。
- **R7 ✅ Fixed in REQUIREMENT.md**：AC-4 重写——匹配改为 `contains("l2-missing")`（覆盖 33 号 merge 产出的合并标签 `l2-missing+state-integrity`，L271-273 已核实）；清除语义二分：type 纯 `l2-missing` → 整文件 rm（对齐 write_model_missing_clear 范式），type 合并标签 → 剥离 l2-missing 段（type 改回 state-integrity，violations[] 保留）；stderr 审计记录清除前 type。AC-6 同步补 type 标签剥离（外来清空后合并标签剥离为 l2-missing）；AC-9 终态同步。
- **R8 ✅ 登记 MINOR-DEFERRED M8**（triaged）：「恰好新增」限定首轮（AC-9 已写首轮收敛），再接管场景由 AC-5 去重保证 note 不重复——2-design 按 AC-9 首轮 + AC-5 去重实现。

---

## L2 复核（第 3 轮）

- **日期**：2026-09-01
- **输入**：修订版 REQUIREMENT.md（AC-4/AC-6/AC-9）+ CHANGE.md（F1 段）+ INDEPENDENT-REVIEW-1.md「主 agent 响应（第 2 轮）」段 + MINOR-DEFERRED.md
- **核验方式**：逐条对照修订文本 + grep 全仓确认残留引述 + 与 33 号 merge 逻辑（L271-273 合并标签）交叉比对。只依据文件内容判定。

### R5-R8 逐条状态

- **R5 残留: ✅ Fixed** — `grep -rn "compliance-priority"` 于 CHANGE.md **0 匹配**；F1（CHANGE.md:13）已改「（沿 ADR-013 compliance 优先精神；数组级条目保留为本 change 新决策）」，与 AC-10 依据注（REQUIREMENT.md:75）及风险段（CHANGE.md:55）三处口径一致。残留匹配仅存于历史审查记录（INDEPENDENT-REVIEW-0/1 原文与 MINOR-DEFERRED M6），非现行规格。
- **R7: ✅ Fixed** — AC-4（REQUIREMENT.md:34-37）已改为 `contains("l2-missing")` 匹配（Given 显式列两种形态：纯 `l2-missing` 独立条目 + 33 号 merge 产出的 `l2-missing+state-integrity` 合并标签），清除语义二分：纯 type → 整文件 rm（对齐 `write_model_missing_clear`，单 type 文件场景适用，29 号覆盖写无 violations[] 故不误伤 compliance）；合并标签 → 剥离 l2-missing 段（type 改回 `state-integrity`，violations[] 保留）+ 清除动作写一行 stderr 审计（记录清除前 type）。AC-6（REQUIREMENT.md:50）同步 type 剥离语义（外来清空后合并标签剥离为 `l2-missing`，violations[] 清空——因其中全是 state-integrity 类）；AC-9（REQUIREMENT.md:68）终态同步（l2-missing 独立条目保留 + 恰 1 条 foreign-state note）。与 33 号 L271-273 合并标签逻辑自洽。
- **R8: ✅ 已登记 MINOR-DEFERRED M8** — MINOR-DEFERRED.md:14 M8 状态 triaged（「恰好新增」限定首轮 + 再接管由 AC-5 去重兜底），处置合理。

### 新矛盾检查（未发现 🔴）

- **AC-4 vs AC-6/AC-9 保留集合**：剥离方向相反（AC-4 合并→`state-integrity` 清 l2-missing 段；AC-6 合并→`l2-missing` 清 state-integrity 段）但情境互补（AC-4 = 正常路径 L2 段已写退场；AC-6/AC-9 = 外来接管清空），不构成矛盾。
- **AC-4 vs AC-3**：作用域不重叠——AC-3 健康清零仅清 state-integrity 类 9 种 check 并保留 l2-missing（REQUIREMENT.md:30），AC-4 由 29 号负责 l2-missing 退场，无交集。唯一未显式定义点：正常路径合并标签文件经 AC-3 清空 violations 后 type 未同步剥离（仍 `l2-missing+state-integrity`），但 contains 匹配仍命中、l2-missing 语义保留，无功能影响，属 2-design 实现细节，不构成 fail 条件。
- **AC-4 vs AC-5**：外来路径（jq 失败）29 号静默退出不执行退场 → l2-missing 保留，与 AC-6/AC-9 终态一致。

### 复核结论

- R5 残留 / R7 / R8 全部落实；无未修复 🟡，无新引入 🔴。
- 本轮修复未引入新矛盾（仅一处无功能影响的实现细节留 2-design）。

**Verdict**: pass
