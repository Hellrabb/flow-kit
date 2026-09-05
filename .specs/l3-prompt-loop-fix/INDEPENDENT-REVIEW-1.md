# 独立审查 · 阶段 1

## L2 盲审

### 🟡 R1 · AC-6 副本数量自相矛盾：`md5sum`「四份」与括号内列举「五处」冲突
**Severity**：🟡 Important
**Symptom（症状）**：`REQUIREMENT.md:56` When 子句「`md5sum` **四份** `l3-prompt.sh`（`flow-kit-bundle/hooks/`、`.claude/hooks/`、`dist/dsh-flow-kit/hooks/`、`dist/dsh-flow-kit/vendor/flow-kit-bundle/hooks/`、`~/.claude/hooks/` **五处**含全局运行时）」——数字「四份」与括号内明确列举的五个路径冲突；`CHANGE.md:43` 验收线 3 同源写「四份副本 byte-level 一致」。
**Source（源头）**：ADR-019 写作原则「AC 必须确定性」；CONTEXT.md「AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC」。
**Consequence（后果）**：TEST 阶段无法确定 md5sum 断言的副本数量，回归基线断言含糊；实现/同步时按「四份」计数可能漏掉五处中的一处（尤其 `dist/dsh-flow-kit/vendor/` 与 `~/.claude/hooks/` 两个易漏副本），导致副本漂移。
**Remedy（修补）**：统一为五处路径（或明确拆分为「维护源 1 份 + 运行时部署 4 份」并分别命名）。同步修正 `CHANGE.md` 验收线 3 的「四份」为「五处」。before/after 示例：`md5sum 五处 l3-prompt.sh（flow-kit-bundle/hooks/、.claude/hooks/、dist/dsh-flow-kit/hooks/、dist/dsh-flow-kit/vendor/flow-kit-bundle/hooks/、~/.claude/hooks/）`。

### 🟡 R2 · AC-4 findings 提取源段未规格化：`## L3` 段是否含 severity 发现列表未验证
**Severity**：🟡 Important
**Symptom（症状）**：`REQUIREMENT.md:41` Given「INDEPENDENT-REVIEW-7.md 已含 `## L3` 段（**≥1 条 critical/major 发现**）」——带 severity 的结构化发现（critical/major）实际对应 L2 盲审的四要素+severity 输出格式（`## L2 盲审` 段），而 L3 外部模型的既有输出契约是 `L3_RESULT: verdict=<v> summary=<s> report=<p>` 单行（CONTEXT「L3_RESULT 格式」条目），非 severity 发现列表。
**Source（源头）**：CONTEXT.md「L3_RESULT 格式」+「severity gating」条目；`L2-blind-review.md` 输出格式（四要素 + Critical/Important/Minor）。
**Consequence（后果）**：若 `## L3` 段实际不含 severity 发现列表，AC-4 的「前轮 findings 提取」拿不到输入 → 功能无法实现或需额外解析外部模型自由文本；TEST fixture 可能构造出与生产文件结构不符的输入，测试假绿。
**Remedy（修补）**：AC-4 明确 findings 提取源段——是 `## L2 盲审` 段（含四要素发现）还是 `## L3` 段（含 verdict+summary）？若只有 L2 段含 severity 发现，Given 应改指 L2 段或改为「全文件含 ≥1 条 critical/major 发现（不限定段）」，并确认 L3 报告是否产生 severity 标记。

### 🟡 R3 · AC-4「主 agent 响应要点」提取粒度未规格化
**Severity**：🟡 Important
**Symptom（症状）**：`REQUIREMENT.md:43` Then「prompt 包含每条 critical/major 发现的单行摘要（`severity|file|issue` 形式）**与主 agent 响应要点**；前轮反馈注入总量 ≤ 800 字节」——「响应要点」的提取方式（前 N 字符 / 全文 / 逐条摘要）未定义；发现摘要与响应要点各自的 800B 内配额也未定。
**Source（源头）**：ADR-019「AC 必须确定性」；AC-5 依赖「无响应段」的对称分支，但响应段存在的「要点」粒度同样未规格化。
**Consequence（后果）**：TEST 无法精确断言「要点」内容与字节边界，`≤ 800 字节` 断言含糊；实现可能全文截断 `## 主 agent 响应` 段导致要点含噪声，或摘要+要点合计超限时无截断优先级。
**Remedy（修补）**：规格化响应提取（如「`## 主 agent 响应` 段前 200 字节」或「逐发现响应的单行摘要」），并明确 800B 内发现摘要与响应要点各自的配额或截断优先级（对齐「反馈优先截断」立场）。

### 🟢 R4 · AC-4 When 子句验证目标不唯一
**Severity**：🟢 Minor
**Symptom（症状）**：`REQUIREMENT.md:42` When「构建重审 prompt（`_l3_inject_context` **或其内部提取逻辑**）」——括号内的「或其内部提取逻辑」使验证目标函数不唯一。
**Source（源头）**：ADR-019「AC 必须确定性」；「AC 是 TEST 派生用例唯一来源」。
**Consequence（后果）**：TEST 不知道该断言哪个入口（`_l3_inject_context` 单元 vs `_l3_build_prompt` 端到端），可能两端各自写一半断言。
**Remedy（修补）**：指定唯一入口，如「调用 `_l3_build_prompt 7 <dir> <chars>` 构建完整重审 prompt」或「直接调用 `_l3_inject_context`」。

### 🟢 R5 · AC-3 Then 混入实现诊断细节
**Severity**：🟢 Minor
**Symptom（症状）**：`REQUIREMENT.md:36` Then「CHANGELOG 注入段出现（**当前因 `dirname ×2` 解析到 `.specs` 而静默丢失**）」——实现诊断（`dirname ×2`）混入 AC 的 Then 子句。
**Source（源头）**：ADR-019「范围决策属 DESIGN 非 REQUIREMENT」；AC 应陈述可观察结果而非实现机制。
**Consequence（后果）**：AC 与实现细节耦合，`dirname` 修复方式变更（如改为 `dirname ×3` 或等价逻辑）时 AC 措辞需连带修改；TEST 阶段可能误将实现细节当断言。
**Remedy（修补）**：Then 只保留可观察结果「CHANGELOG 注入段出现」，删除括号内实现诊断，将其移入 DESIGN 文档。

**Verdict**: pass

---

## 主 agent 响应

> phase 1 为文档型产物（已锁决策 [2026-07-07]：修代码优先协议仅对 5/6/7 阶段触发），故本阶段修复载体为 spec 文档本身。

- R1（四份/五处矛盾）：**Fixed in:** `.specs/l3-prompt-loop-fix/REQUIREMENT.md` AC-6 When/Then（「四份」→「五处」并逐一列举五路径）+ `.specs/l3-prompt-loop-fix/CHANGE.md` 验收线 3（「四份副本」→「五处副本（bundle 源 + 本地 + dist×2 + 全局运行时）」）。
- R2（AC-4 提取源未规格化）：**Fixed in:** `REQUIREMENT.md` AC-4 Given——提取源规格化为两类（`## L2 盲审` 段 🔴/🟡 Severity 条目；`## L3` 段 critical/major JSON 数组项），至少一类非空即可注入；验证方式同步改为「fixture 两类提取源各备一份」。
- R3（响应要点粒度/配额未定义）：**Fixed in:** `REQUIREMENT.md` AC-4 Then——响应要点 = 逐条 `Fixed in:` / `Tech-debt:` / `Not-applicable:` 分类标记行（非自由摘要），配额拆分：发现摘要 ≤600B + 响应要点 ≤200B = 总 ≤800B，对齐反馈优先截断立场。
- R4（When 验证目标不唯一）：**Not-applicable**（🟢 Minor，不入 fix loop）→ 已登记 `.specs/l3-prompt-loop-fix/MINOR-DEFERRED.md` M1；唯一验证入口（`_l3_build_prompt` 端到端 vs `_l3_inject_context` 单元）在 2-design 定夺，REQUIREMENT 层保持实现无关。
- R5（AC-3 Then 混入实现诊断）：**Not-applicable**（🟢 Minor，不入 fix loop）→ 已登记 `MINOR-DEFERRED.md` M2；`dirname ×2` 诊断细节将在 2-design 的 §0.5 触碰模块清单中安放。

---

## L3 重审（glm-5.3-flash 外部模型 · 2026-09-04 17:40）

> 自动生成于 2026-09-04 17:40。由 l3-review.sh 写入。

### 审查结论

```json
{"critical":[],"major":[{"file":"REQUIREMENT.md · AC-1","issue":"Given 仅规定 6 个 ≥3000B 产物（≥18000B），未规定 fixture 中 .specs/CHANGELOG.md 与 .specs/LESSONS.md 的最小尺寸；若二者合计 ≤2000B，总字节 <20000，根本不会触发截断，「即使总字节超限被截断」这一前提在测试中可能不成立","why":"该 AC 的核心主张（标题「截断顺序」、US-1）是注入段在截断后仍可见；AC 是 TEST 派生用例的唯一来源，若 Given 不保证截断必然发生，派生用例可在未截断路径上空洞通过，无法证明修复生效","fix":"在 Given 中显式规定 CHANGELOG.md 与 LESSONS.md 的最小字节数（如各 ≥1500B），使总字节确定 >20000；并在 Then 中增加对「已发生截断」这一前置事实的断言（如输出长度 ≤20000 或末尾截断标记存在）"},{"file":"REQUIREMENT.md · AC-4","issue":"「每条 critical/major 发现的单行摘要」「逐条分类标记行」是全量保证，但同时设 600B/200B/800B 硬配额；当前轮发现条数多、字节超配额时两个要求不可同时满足，AC 未定义溢出时的优先级或裁剪策略","why":"AC 是 TEST 唯一来源；fixture 条数不同会派生出互相矛盾的断言（全量存在 vs 字节上限），实现与测试都无法确定统一的通过标准","fix":"明确溢出策略并写入 Then，例如「按 critical>major（🔴>🟡）优先级取前 N 条，被裁剪时追加 (+k more) 标记，配额优先于全量」，使「每条」表述改为配额内的确定性规则"},{"file":"REQUIREMENT.md · AC-6","issue":"五处副本 md5sum 中的 ~/.claude/hooks/ 位于用户主目录，在 CI/新环境不存在或内容不一致；验证方式将 md5sum 与 bats 串联但未说明该 AC 是自动化用例还是发布手工步骤","why":"文末声明 AC 是 TEST 派生用例唯一来源；含 home 路径的断言不可移植，会导致用例在标准测试环境假失败或被迫跳过，破坏「全量 bats 无失败」的可自动化性","fix":"拆分验证：仓库内各副本一致性做成可自动化断言（bats 或脚本，仅覆盖 repo 内路径）；~/.claude/hooks/ 全局副本同步列为发布清单步骤，并在 AC 中显式标注为人工/发布验证，不计入 bats 用例"}],"minor":[{"file":"REQUIREMENT.md · AC-3","issue":"只断言 CHANGELOG 注入段出现，未同时断言 LESSONS.md；同一 dirname 解析缺陷对 LESSONS 同样生效，而 AC-1 在活动布局下两段都查，归档布局覆盖少一半","why":"US-3 主张归档与活动布局「行为一致」，单查 CHANGELOG 无法排除 LESSONS 段在归档布局下仍丢失的同型缺陷","fix":"Then 中补充 === LESSONS.md === 段标记断言"},{"file":"REQUIREMENT.md · AC-4","issue":"Given 将前轮审查文件写作 .specs/<id>/INDEPENDENT-REVIEW-7.md，但未说明它与 _l3_build_prompt 的 artifacts_dir 参数的相对位置（是否位于该目录内），也未定义多轮场景下的文件命名/定位规则；AC-3 的归档 fixture 是否同样注入前轮发现亦未覆盖","why":"审查文件是注入的唯一数据源，位置/命名不确定会直接影响 fixture 构造与归档补跑场景（US-3）的行为一致性","fix":"明确审查文件按 artifacts_dir 内定位（或给出查找规则与轮次命名约定），或将多轮命名与归档布局下的注入行为显式交由 DESIGN 并注明"},{"file":"REQUIREMENT.md · AC-4/AC-5","issue":"缺少「审查文件整体缺失或两类提取源皆空」的行为定义（首轮审查或空文件场景）：此时既不应注入摘要，也不应误标「主 agent 未响应」","why":"AC-5 仅覆盖「文件存在但无响应段」，空/缺失文件的标注与静默行为未定义，实现可能输出误导性标注","fix":"补充一条 AC：Given 审查文件缺失或提取源皆空，Then prompt 不含发现摘要且不含「主 agent 未响应」标注"},{"file":"REQUIREMENT.md · AC-2","issue":"验证断言「归档齐全行不含 SUMMARY」依赖定位到某一行，但未给出可 grep 的稳定锚点；且以中文字面「项目级」作断言与文案措辞强耦合","why":"行级定位模糊会让 TEST 阶段自行发明匹配规则，措辞微调即误报失败","fix":"为该 checklist 行定义稳定锚点（如行首标记或固定完整文案）写入 AC"},{"file":"REQUIREMENT.md · AC-6","issue":"以固定「770 pass」作为基线命题，任何无关区域的用例增删都会使该数量命题失效","why":"回归断言的稳定判据应是「无 fail」，硬编码总数造成与本次修复无关的脆弱耦合","fix":"Then 改为「全量 bats 无 fail/skip」，770 仅作为依赖与假设中的参考值"},{"file":"REQUIREMENT.md · 非功能性需求","issue":"字节配额（600/200/800B）下按字节截断未要求 UTF-8 字符边界安全，中文发现摘要可能在截断处产生非法字节序列","why":"注入内容与提取源均为中文场景，乱码会进入弱模型审查 prompt，重新引入误读风险","fix":"NFR 补充「截断须落在字符边界（或验证注入段为合法 UTF-8）」"}],"verdict":"pass","summary":"范围切分（v1/v2/out）合理、无明显蔓延，AC 总体可验证，但 AC-1 未保证截断前提、AC-4 全量保证与字节配额冲突、AC-6 依赖本机 home 路径不可自动化，三处 major 需在进入 TEST 前补齐。"}
```

L3_artifact_hash: ba5026f28f9d1f1dddff3c2507cf81034dac8aaa91cec3d6063703339baed2d9

---

## 主 agent 响应（L3 · 2026-09-04）

- **L3-Major-1**（AC-1 截断前提不保证）: **Fixed in:** `REQUIREMENT.md` AC-1 — Given 补 CHANGELOG/LESSONS 各 ≥1500B 下限（总字节确定 >20000），Then 增加「①总输出 ≤20000 字节（截断前置事实成立）②段标记仍出现」双断言
- **L3-Major-2**（AC-4 全量保证与配额矛盾）: **Fixed in:** `REQUIREMENT.md` AC-4 — Then 改为配额优先的确定性规则：critical > major 排序、配额内取前 N 条、溢出追加 `(+k more)` 标记；「每条注入」限定为配额内语义
- **L3-Major-3**（AC-6 home 路径不可移植 + 硬编码 770）: **Fixed in:** `REQUIREMENT.md` AC-6 — 拆分为仓库内四处副本 md5sum 自动化断言（计入 bats）+ `~/.claude/hooks/` 全局副本发布清单人工步骤；770 改为依赖假设参考值，Then 断言「无 fail/skip」
- **L3-Minor-1**（AC-3 缺 LESSONS 断言）: **Fixed in:** AC-3 Then 补 `=== LESSONS.md ===` 段标记断言
- **L3-Minor-2**（审查文件定位规则未定义）: **Fixed in:** AC-4 Given 补「位于 artifacts_dir 内、命名 INDEPENDENT-REVIEW-<phase>.md、多轮追加不换文件名」
- **L3-Minor-3**（缺失/空文件行为未定义）: **Fixed in:** 新增 AC-7（无审查文件或提取源皆空 → 静默，无摘要无标注）
- **L3-Minor-4**（AC-2 断言锚点不稳定）: **Fixed in:** AC-2 验证方式改为固定完整行文案锚定（非「项目级」子串匹配）
- **L3-Minor-5**（硬编码 770 基线）: **Fixed in:** 随 Major-3 一并处理（AC-6 + 依赖假设措辞）
- **L3-Minor-6**（UTF-8 字符边界）: **Fixed in:** 非功能性需求新增「健壮性」条目（截断落在字符边界，注入段须为合法 UTF-8）
