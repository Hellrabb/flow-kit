# 独立审查 · 阶段 2

## L2 盲审

### 🟡 R1 · 提取锚点字段名不存在：DESIGN R2 锚定 `"severity"`，但 L3 JSON schema 无此字段
**Severity**：🟡 Important
**Symptom（症状）**：DESIGN §5 R2 缓解策略写「正则只锚定稳定结构（`### 🔴`、`"severity"` 字段名）」，但 L3 段的实际 JSON schema（`flow-kit-bundle/hooks/stop/lib/l3-prompt.sh:156` 的 jq 构造、`l3-api.sh:_l3_parse_result` 原样写入的 content）是 `{"critical":[{"file","issue","why","fix"}],"major":[...],"minor":[...],"verdict","summary"}`——severity 由数组名 critical/major/minor 隐式表达，**不存在 `severity` 字段**。DESIGN D3 本身写的是「critical/major 字段」（正确），与 R2 的 `"severity"` 字段名自相矛盾。
**Source（源头）**：对照 `l3-prompt.sh:156` JSON schema 与 DESIGN D3/R2 的字段命名；ADR-025「单行摘要」规定 critical>major>minor 由数组名区分，无 severity 字段。
**Consequence（后果）**：提取器若按 R2 锚定 `"severity"`，对 L3 段 JSON 永远匹配不到任何 finding → L3 反馈提取静默降级为空 → 前轮 L3 发现不被注入 → 正是本 change 要打破的「反馈循环断裂」原样复现。AC-4（前轮发现注入）无法按现状实现。
**Remedy（修补）**：将 R2 锚点改为数组名 `critical`/`major`（或直接用 `jq -r '.critical[]?,.major[]?'` 解析），与 D3 措辞统一；删除 `"severity"` 字段名这一错误锚点。before: `正则只锚定（\`### 🔴\`、\`"severity"\` 字段名）` → after: `正则只锚定（\`### 🔴\`、L3 JSON 的 \`critical\`/\`major\` 数组名）`。

### 🟡 R2 · 提取目标段头未标准化：「## 主 agent 响应」仅存在于测试 fixture，真实产物中不存在
**Severity**：🟡 Important
**Symptom（症状）**：DESIGN D4/D5 与 AC-4/AC-5 依赖 `INDEPENDENT-REVIEW-<phase>.md` 中存在「## 主 agent 响应」段（无此段→标注「未响应」；从此段提取 `Fixed in:`/`Tech-debt:`/`Not-applicable:` 要点 ≤200B）。全仓 grep 确认该段头**只出现在测试 fixture** `test_l3_pipeline_fix.bats:117`，任何 prompt/template 均未要求主 agent 写此段头。主 agent 实际响应约定有二：(1) `L2-blind-review.md:142`「主 agent 反驳：<…>」段落标记（非 `## 主 agent 响应` 段头）；(2) `Fixed in:`/`Tech-debt:`/`Not-applicable:` 分类行写入 REVIEW.md（`6-review.md:143-145`、`5-test.md:99-101`、`7-integration.md:102-104`），而非 INDEPENDENT-REVIEW-N.md。
**Source（源头）**：对照 `flow-kit-bundle/flow-kit/prompts/` 全量（L2-blind-review.md / 5-test.md / 6-review.md / 7-integration.md）无「## 主 agent 响应」段头标准化；ADR-025 假定该段存在但未落为契约。
**Consequence（后果）**：若按现状实现，AC-5「无响应段→标注未响应」会对**每一次**审查触发（段头永不存在），即使主 agent 已通过「反驳」或 REVIEW.md 的 `Fixed in:` 行响应——产生误导性的「主 agent 未响应」标注；「响应要点」提取也恒为空，反馈质量进一步退化。
**Remedy（修补）**：二选一并在 DESIGN 显式落定：(a) 在相关 prompt（2-design/5-test/6-review/7-integration 的响应段指令）标准化「## 主 agent 响应」段头，要求主 agent 在 INDEPENDENT-REVIEW-N.md 追加该段；(b) 将提取源改为实际约定——「主 agent 反驳：」段落 + REVIEW.md 中的 `Fixed in:`/`Tech-debt:`/`Not-applicable:` 行。推荐 (a)（统一一处契约），并同步更新 `test_l3_pipeline_fix.bats:113-119` 的 mock fixture 使其与标准化后的真实产物一致。

### 🟡 R3 · 「先改 5 处 head -c」不可核验：实际 13 处位点，DESIGN 未枚举
**Severity**：🟡 Important
**Symptom（症状）**：DESIGN §9.1 与 D7 声称「本 change 先改 l3-prompt.sh 内 **5 处** head -c」，但该文件实际有 **13 处** `head -c` 位点（L60/66/73/80/86/106/115/118/122/132/139/143/145）。DESIGN 全文未枚举这 5 处具体是哪些，也未给出选择标准。
**Source（源头）**：`l3-prompt.sh` 全 13 处 `head -c` 与 DESIGN §9.1/D7 的「5 处」声明不符；L-031 教训（触碰清单不完整→漏改）。
**Consequence（后果）**：实现阶段无法核验完整性；若只改 5 处，剩余 8 处（含 phase1-5 工件 `head -c $max_chars`、phase6 REVIEW.md L122、phase7 最终 L145）对多字节中文内容仍产出断裂 UTF-8 → REQUIREMENT 非功能性需求「反馈注入与工件截断须落在 UTF-8 字符边界」只部分满足。L-031 式漏改风险。
**Remedy（修补）**：在 DESIGN 显式列出这 5 处位点（或给出选择标准，如「仅本次新增注入点：L132 循环/L139 CHANGELOG/L143 LESSONS/L145 最终/…」），并单独记录「本轮不改的 8 处及延后理由」。避免用「5 处」这类不可核验的模糊数字。

### 🟢 R4 · D5 project_root 修复范围未覆盖 phase 6 同构位点
**Severity**：🟢 Minor
**Symptom（症状）**：DESIGN D5 描述的归档布局 project_root 解析（`*/.specs/archive/*` → dirname×3）在 §0.5.1 触碰清单中只列「phase 7 分支 L127-146」。但 `_l3_build_prompt` 的 **phase 6 分支 L91-92** 用同一表达式 `project_root="$(dirname "$(dirname "$artifacts_dir")")"` 解析（用于 `git diff HEAD`）。D5 未说明该修复是否同样作用于 phase 6。
**Source（源头）**：`l3-prompt.sh:91-92`（phase 6）与 `l3-prompt.sh:127-128`（phase 7）同构的 project_root 解析；DESIGN D5/§0.5.1 未覆盖 phase 6。
**Consequence（后果）**：归档布局下 phase 6 L3 重审（经 29 号积压扫描触发）仍会在 `.specs` 目录跑 git diff（错目录）。实际触发概率低（归档发生在 phase 7 完成后，phase 6 的 .done 通常已存在），故定为 Minor，但 DESIGN 应显式声明其为 out-of-scope 而非静默遗漏。
**Remedy（修补）**：在 DESIGN §6「不在范围」补一句「phase 6 归档布局 project_root 不在本轮范围（理由：phase 6 重审晚于归档的场景几乎不发生）」；或若 D5 的实现抽成共享解析函数，则同步更新 §0.5.1 触碰清单把 L91-92 也列入。

**Verdict**: pass

---

## 主 agent 响应（L2）

- **R1** — Fixed in: `DESIGN.md` §5 R2 缓解措辞已改为锚定 `"critical"`/`"major"` **数组键名**并标注 `l3-prompt.sh:156` schema 实证（无 `"severity"` 字段）；D3 同步改写为「数组键下的条目」。与 D3/R2 统一，错误锚点已删除。
- **R2** — Fixed in: `DESIGN.md` D4 重写为**三重锚定**（`## 主 agent 响应` 段头 / `主 agent 反驳：` 段（L2-blind-review.md:142 既有契约）/ `^(Fixed in|Tech-debt|Not-applicable):` 分类行），提取器只读审查文件本体（不读 REVIEW.md——审查文件内分类行来自标准化响应段，phase 1/2 已实践）；prompt 侧段头标准化显式移入 §6 不在范围（提取器不依赖它）。§2 数据流图同步更新。选项 (b) 变体：采纳"锚定实际约定"，反驳段即为实际约定之一。
- **R3** — Fixed in: `DESIGN.md` D7 与 §9.1 改为**全量 13 处位点枚举**（file 形 10 处：L60/66/73/80/86/106/122/132/139/143 → `_l3_utf8_head_bytes`；stream 形 3 处：L115/118/145 → `_l3_utf8_head_stream`），验证锚点 = 改后 `grep -c 'head -c' l3-prompt.sh` 仅剩 helper 函数体内部；§0.5.1 触碰清单同步。
- **R4** — Fixed in: `DESIGN.md` D5 显式声明适用**两处同构位点**（phase 6 `l3-prompt.sh:91-92` + phase 7 `l3-prompt.sh:127-128`），§0.5.1 触碰清单已加 phase 6 分支；§6 补 phase 6 专属行为验证不在 AC 的说明。采纳 Remedy 第二路径（共享修法两处套用）。

---

## L3 重审（glm-5.3-flash 外部模型 · 2026-09-04 18:03）

> 自动生成于 2026-09-04 18:03。由 l3-review.sh 写入。

### 审查结论

```json
{"critical":[],"major":[{"file":"DESIGN §2 数据流 ④ vs §1 D7","issue":"§2 ④ 写「尾部字节截断（既有 head -c max_chars 保留，语义不变）」，而 D7 声明 v1 覆盖全部 13 处 head -c 位点、验证锚点为「改后 grep -c 'head -c' 仅剩 helper 函数体内」，且 stream 变体 L145 明确含「最终总预算截断」；§2 ③ 又写「head -c 换 _l3_utf8_head_bytes」。两处互斥：若最终截断保留裸 head -c，则 D7 的 grep 验证锚必然不成立；若按 D7 全替换，则 §2 ④ 措辞错误","why":"这是对核心修改点（可 grep 验证的锚点）的内部矛盾。实现者按 §2 ④ 字面执行会违反 D7 的验证条件，按 D7 执行则 §2 图与实现不符，4-dev 与后续审查无所适从","fix":"将 §2 ④ 改为「尾部字节截断（改走 _l3_utf8_head_stream，max_chars 字节预算语义不变）」，与 D7 的 13 处位点清单和 grep 验证锚统一"}],"minor":[{"file":"DESIGN §1 D7","issue":"D7 取舍栏引用「部分替换会留断裂 UTF-8 尾巴（R3 发现）」，但本文档 §5 的 R3 是「.claude/hooks 副本覆盖丢失本地修改」，与 UTF-8 截断无关（D1 引 R1、D3 引 R2 均能对上，唯 D7 引 R3 错位，疑为风险重编号后未同步）","why":"内部交叉引用失效会误导读者到错误风险条目查找该发现的依据，削弱 DESIGN 的证据链可信度","fix":"修正为正确的来源引用（应为前轮审查的 UTF-8 相关发现编号）或改为内联描述该发现"},{"file":"DESIGN §1 D5 / §5 风险表","issue":"D5 的 dirname ×3 启发式隐含「archive 目录固定为一层嵌套」假设（.specs/archive/<id>/artifacts）；若归档布局未来增加一层（如按日期分桶 .specs/archive/<date>/<id>/），×3 会静默解析出错误 project_root。该耦合在取舍栏被接受，但风险表 R1-R4 未收录","why":"静默错误路径推导会导致 CHANGELOG/LESSONS 注入静默为空（退化为 AC-7 静默），难排查且违背 R4 对「预算语义」同类长期债的记录标准","fix":"在 §5 增加一行风险（布局层级耦合，概率低/影响低，缓解=ARCHITECTURE §1.2 布局约定锚点 + v2 收敛到显式传参），或在 D5 中显式声明不变量「archive 恒为一层」"},{"file":"DESIGN §1 D4 / §5 风险表","issue":"响应检测三锚均为启发式：主 agent 若以三锚之外的措辞响应（如自由文本「采纳 R1 已修复」且无段头/反驳标记/分类行），会被误标「主 agent 未响应前次发现」并注入下一轮 prompt。R2 只覆盖 findings 提取降级，未覆盖响应检测的假阴性","why":"错误「未响应」标签会给下一轮审查模型注入不实状态信号，可能诱发冗余响应或对主 agent 的错误施压；与「打破假阳性循环」的目标相悖时反而制造新噪声","fix":"在 §5 补一行响应检测假阴性风险（概率低、影响=提示噪声），或在 D4 中显式声明接受的假阴性语义（宁漏报不误报）及其降级行为"},{"file":"DESIGN §0.5.2 / §1 D2-D3","issue":"L3 段 JSON 条目到 `severity|file|summary` 单行的字段映射未定义（JSON 条目含哪些字段、summary 取自哪一项、L2 🔴/🟡 行如何截取为单行）；同时 L2/L3 两类来源混排时的排序规则（除 severity 外 tier 间先后）未说明","why":"字段映射属接口级定义（文档允许且应当给出），缺失则实现者需自行读 l3-prompt.sh:156 schema 猜测，fixtures 与实现可能对不上同一契约","fix":"在 0.5.2「单行摘要格式」行或 D2 中补一句接口定义（如 L3 条目取 <file> 与 <issue> 首句；排序=severity 降序、同 severity 时 L3 先于 L2），并让三类 fixtures 按此映射固化"},{"file":"DESIGN §0 / §1 D3 / §5 R2","issue":"L2 锚点依赖多字节 emoji（### 🔴/🟡），提取器未声明 grep 方言/locale 约束；团队矩阵含 macOS（ADR-019 L-058 语境）与精简容器，BSD grep 无 -P，部分 locale 下 emoji 字节匹配行为不一","why":"正则引擎选择是实现自由度最大、平台差异最敏感的点，v1 不锁定则 macOS/容器可能出现 Linux CI 测不到的静默提取失败（恰好落入 AC-7 静默兜底，难以发现）","fix":"在 D3 或 R2 缓解栏声明约束：仅用 POSIX ERE / 按字节（LC_ALL=C）匹配 UTF-8 序列，禁用 grep -P；并在 fixtures 中固化 emoji 行样本"}],"verdict":"pass","summary":"决策链完整、证据锚点可验证、既有契约（三参签名/max_chars/五副本同步）保持良好，无撞架构项；核心问题是 §2 与 D7 在最终截断实现上的内部矛盾需统一，另有少量交叉引用失效、风险表缺口（D5 布局耦合、D4 假阴性）与接口级映射缺失。"}
```

L3_artifact_hash: 599fd6bbaaa32677548a1bc66826d4cd182e07987f141d1f72972c561026a277

---

## 主 agent 响应（L3）

- **Major-1（§2 ④ vs D7 矛盾）** — Fixed in: `DESIGN.md` §2 ④ 措辞改为「尾部总预算截断改走 _l3_utf8_head_stream（max_chars 字节预算语义不变 · 属 D7 13 处位点之一 L145）」，与 D7 的全量替换 + grep 验证锚统一。
- **Minor-1（D7 交叉引用错位）** — Fixed in: `DESIGN.md` D7 取舍栏「R3 发现」改为「L2 R3 发现 · INDEPENDENT-REVIEW-2.md」（指 13 位点枚举发现，非 §5 风险表 R3）。
- **Minor-2（D5 布局层级耦合未入风险表）** — Fixed in: `DESIGN.md` §5 新增 R5 行（概率低；缓解 = ARCHITECTURE §1.2 布局约定锚点 + v2 显式传参收敛 + ADR-025 记录不变量）。
- **Minor-3（D4 响应检测假阴性）** — Fixed in: `DESIGN.md` D4 显式声明「宁漏报不误报」接受语义 + §5 新增 R6 行。
- **Minor-4（字段映射未定义）** — Fixed in: `DESIGN.md` D2 补接口定义（L3 条目 severity=数组键/file/issue 首句；L2 行 🔴🟡→severity、Symptom path:line、R<x> 标题；排序 severity 降序 + 同级 L3 先于 L2）；fixtures 按此映射固化（R2 缓解栏）。
- **Minor-5（grep 方言约束）** — Fixed in: `DESIGN.md` D3 补正则引擎约束（POSIX ERE + LC_ALL=C 字节匹配、禁 grep -P、emoji 行样本入 fixtures）。
