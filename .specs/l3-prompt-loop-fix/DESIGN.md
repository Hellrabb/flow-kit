# DESIGN: l3-prompt-loop-fix

- **Change ID**: l3-prompt-loop-fix
- **关联**: `@.specs/l3-prompt-loop-fix/REQUIREMENT.md`、`@.specs/l3-prompt-loop-fix/CHANGE.md`、`@.specs/CONTEXT.md`、`@.specs/ARCHITECTURE.md`
- **作者**: AI（Architect 角色）+ 人工 review

---

## 0. 技术栈选定

> 已锁技术决策（CONTEXT.md「技术栈（团队级默认 / 已锁定）」）→ 本 change 沿用，不重选。

- **选定**: Bash + bats-core（团队已锁，纯 hook 脚本项目，无变栈场景）
- **前端 / 后端 / 数据库**: N/A（stop hook lib 内部函数修改）
- **部署**: 沿用 ADR-002（user-scope symlink + project-priority fallback）；本 change 同步 4 份副本（见 D8）
- **关键依赖**: bash 4+（既有）、jq（既有）、coreutils（head/od，既有）。**零新增依赖**
- **理由**: bugfix 性质（REQUIREMENT AC-1~AC-7 全部针对既有 bash 函数），引入新语言/运行时 = 负价值
- **明确排除**: Perl/Python 单行助手（禁新增解释器依赖——安装环境矩阵含精简容器）

---

## 0.5 既有架构对齐（brownfield 必填）

### 0.5.1 本次 change 触碰的既有模块

```
触碰模块（grep/ls/md5sum 实证清单）：
- flow-kit-bundle/hooks/stop/lib/l3-prompt.sh（157 行 · 唯一代码修改点：_l3_inject_context L26 / _l3_build_prompt L53 / phase 6 分支 L91-92 / phase 7 分支 L127-146 / 全部 13 处 head -c 位点）
- flow-kit-bundle/test/test_l3_pipeline_fix.bats（新增用例挂靠此文件 · 既有已引用 _l3_build_prompt）
- flow-kit-bundle/test/（**双源同步目标**：make test-sync 仅 cp test/*.bats **不含 fixtures 子目录**——fixtures 须显式 cp -r；make check 含 check-test-sync=diff -rq 递归双向，不同步则 pre-push 阻断 · phase-3 L2 R5 修正）
- test/fixtures/（新增 7 个 fixtures：l2-sample / l3-sample / mixed / no-response / empty / overflow / verdict-only · 同步至 flow-kit-bundle/test/fixtures/）
- .claude/hooks/stop/lib/l3-prompt.sh（同步副本 · md5=50ff9333 漂移=旧版死代码，bundle 已清理）
- dist/dsh-flow-kit/hooks/stop/lib/l3-prompt.sh + dist/dsh-flow-kit/vendor/flow-kit-bundle/hooks/stop/lib/l3-prompt.sh（同步副本 · 当前与 bundle 一致 96f430bd）
- ~/.claude/hooks/stop/lib/l3-prompt.sh（发布清单人工同步 · 当前与 bundle 一致 96f430bd）
- .specs/adr/025-l3-prior-feedback-injection.md（新增 ADR）
- .specs/CONTEXT.md（§9 沉淀，经 toll-gate 后追加）

禁动清单（与本次无关，不许"顺手"碰）：
- l3-review.sh / l3-api.sh / l3-done.sh / l3-truncate.sh（调度、凭证、.done、smart_truncate——本 change 不改它们的逻辑）
- 29-independent-review.sh（Gate 1/2 逻辑——Claim 3 已裁定为既定设计不修）
- common.sh fk_resolve_model / fk_resolve_api_credentials（ADR-023 域）
- correction-file 系（ADR-024 域）
- .specs/CHANGELOG.md / LESSONS.md 本体（只读注入源）
```

### 0.5.2 既有抽象沿用对照表

| 本次需要 | 既有有没有？路径 | 决定 |
|---|---|---|
| 前轮发现提取 | 无（.bak 版死代码 agent_response 已从 bundle 清除） | **新建** `_l3_extract_prior_findings`（理由：第一次有此需求；旧死代码证明曾有意图但从未接线） |
| UTF-8 边界截断 | `l3-truncate.sh:57 smart_truncate`（字符串级·字符计数·段落保留） | **不沿用，新建** `_l3_utf8_head_bytes`（理由：smart_truncate 语义是"markdown 段落保留截断"，输入是内存字符串、按 `${#text}` 字符计数；本次需要"文件级字节 cap + 多字节回退"，语义不同。v2 再评估统一） |
| 工件收集 + head -c 注入 | `_l3_build_prompt` 既有 7 文件循环 + phase 7 CHANGELOG/LESSONS 注入 | **沿用**（只改顺序与截断 helper） |
| 单行摘要格式 | 无 | **新建**（severity\|file\|summary 竖线分隔，与 hook 日志行风格一致） |
| md5sum 五处一致性校验 | test_hook_integration.bats 既有 md5 范式 | **沿用**（AC-6 扩展到本文件的五处） |
| bats fixtures 组织 | test/fixtures/（既有） | **沿用**（新增 fixtures：含 L2 段 / L3 段 / 无响应段三类样本审查文件） |

### 0.5.3 沿用模式 vs 引入新模式

```
- 函数命名：**沿用** _l3_ 前缀 + usage 注释头（l3-prompt.sh 既有风格）
- 截断语义：**沿用** 字节预算语义（max_chars 参数名与调用方 l3-review.sh:49 契约不变）+ **引入** UTF-8 回退（新 helper，最小侵入）
- prompt 段顺序：**引入新模式**（反馈段前置）→ 理由：AC-1 的确定性存活要求；这是本 change 的核心目的
- 测试：**沿用** bats + fixtures + helper sourcing 范式（test_l3_pipeline_fix.bats 既有结构）；**验证入口裁决（解 M1，phase-3 L2 R1 修正）：AC-1/2/3 断言走 `_l3_build_prompt` 单调用**（反馈段不在其输出内）；**AC-4/5/7 断言复刻 `l3-review.sh:81-104` 组装顺序**——`_l3_inject_context` 输出 + `_l3_build_prompt` 输出前后拼接的组合调用端到端（生产拼接层在 l3-review.sh `context_preamble`，禁动不改，测试同构复刻）；`_l3_extract_prior_findings` / `_l3_utf8_head_bytes|stream` 另配单元用例（AC 之外的加固层，非 AC 验证路径）
- 同步：**沿用** bundle 为唯一维护源 + 副本拷贝（已锁决策 [2026-06-16]）
```

---

## 1. 决策清单

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D1 | 反馈段置于 prompt **最前**：组装层既有 `context_preamble` 前置拼接（l3-review.sh:81/L103，**禁动不改**）保证反馈物理最前；`_l3_build_prompt` 自身段序调整为 **CHANGELOG/LESSONS → 7 文件循环 → checklist 收尾** | a) 仅调高 max_chars；b) CHANGELOG/LESSONS 挪到循环前但反馈仍在后 | a) 不解决确定性（预算再大也可能被 7 文件×3000B 挤掉尾部）；b) 只救 CHANGELOG 不救反馈——反馈才是打破假阳性循环的关键信息（Claim 2 根因） | prompt 结构变化，既有 bats 断言需按新顺序更新（R1） |
| D2 | 前轮发现以 `severity\|file\|一行摘要` 单行注入，critical 优先于 major，minor 不注入；摘要段配额 600B，溢出行折叠为 `(+k more)`。**字段映射（接口定义）**：L3 JSON 条目 → `severity`=所在数组键、`file`=`<file>` 字段、摘要=`<issue>` 首句；L2 行 → `severity`=🔴→critical / 🟡→major、`file`=Symptom 中的 path:line、摘要=R<x> 标题冒号后一句话。**排序** = severity 降序；同 severity 内 L3 先于 L2（最新轮优先）。**verdict 行保留（phase-3 L2 R7）**：L2/L3 verdict 行 + 含「审查上下文」disclaimer 行继续注入（l3-pipeline-fix-2026-07 D4 既有行为不回退；bats:106-132 既有断言锚向后兼容）。**边界矩阵（phase-3 L2 R8 · L3 Major-2 细化）**：findings 有+响应有 = 全注入；findings 有+响应无 = 摘要+未响应标注；findings 无+响应有 = verdict+响应要点（无标注）；findings 无+响应无但文件存在且 verdict 可解析 = 仅 verdict 行（前轮 fail 结论不静默丢弃）；文件缺失/空/verdict 不可解析 = 整段静默 | a) 全文注入 findings；b) 只注入计数 | REQUIREMENT AC-4 配额规则（总 ≤800B）；单行密度最高且与 hook 日志风格一致 | 细节有损——模型若需细节须要求查看审查文件原文（下一轮主 agent 可贴出） |
| D3 | 提取源两类：`## L2 盲审` 段的 `### 🔴/🟡 R<x>` 行；`## L3`（含 重审）段的 JSON findings 中 **`"critical"` / `"major"` 数组键**下的条目（severity 由数组键名隐式表达，无 `"severity"` 字段——`l3-prompt.sh:156` schema 实证）。**正则引擎约束**：仅 POSIX ERE + `LC_ALL=C` 按字节匹配 UTF-8 序列（emoji 锚点按字节字面量），禁用 `grep -P`（团队矩阵含 macOS BSD grep 与精简容器，见 ADR-019 语境）；fixtures 固化 emoji 行样本 | 只认 L3 段 | L2 与 L3 任一 tier 都可能触发重审循环；两类都可能是"前轮发现" | 解析器要处理两种格式（R2 风险，bats 固化两类样本兜底） |
| D4 | 响应检测锚定**审查文件内实际存在的三类标记**（提取器只读 INDEPENDENT-REVIEW-\<phase\>.md，不读 REVIEW.md）：① `## 主 agent 响应` 段头（本 change 起explicit化的约定，phase 1/2 已实践）；② `主 agent 反驳：` 段落标记（L2-blind-review.md:142 既有契约）；③ 行内 `(Fixed in|Tech-debt|Not-applicable):` 标记（实证格式 `- **R1** — Fixed in:`，见 INDEPENDENT-REVIEW-1/2.md 响应段；去 ^ 行首锚——真实分类行是列项中段标记，非行首；phase-3 L2 R2 修正）。命中任一 = 已响应，从命中处提取要点 ≤200B；三类皆无且存在前轮发现 → 标注「主 agent 未响应前次发现」。**假阴性语义显式接受**：三锚外自由措辞的响应会被标注"未响应"——宁漏报不误报（漏检响应的代价只是提示噪声，误检"已响应"才会掩盖真实悬置）；分类行协议随本 change 固化后收敛 | a) 只认 `## 主 agent 响应` 段头；b) 跳过注入（当前行为） | 段头未在任何 prompt 标准化（R2 发现）——只认段头会对历史文件（仅含「反驳」段）误判；REVIEW.md 的分类行不在提取范围（提取器读不到）；三类锚覆盖历史 + 新约定，无需改 prompts | prompt 侧段头标准化（5/6/7 prompt 响应指令统一措辞）显式移入 §6 不在范围——提取器不依赖它即可工作 |
| D5 | 归档布局检测：`artifacts_dir` 匹配 `*/.specs/archive/*` 时 `project_root` 取 `dirname ×3`，否则 `dirname ×2`（现状）。**适用两处同构位点**：phase 6 分支 `l3-prompt.sh:91-92` 与 phase 7 分支 `l3-prompt.sh:127-128`（同一表达式，一处修法两处套用；phase 6 无独立 AC，靠回归套件兜底） | a) `git rev-parse --show-toplevel`；b) 调用方传参 `project_root` | 路径推导与既有 dirname 模式一致、零新依赖、不破坏 `_l3_build_prompt <phase> <dir> <max>` 三参签名（test_l3_timeout 等既有测试直接调用）；a) 依赖 git 存在性，b) 改签名是破坏性变更 | 路径约定耦合（ARCHITECTURE §1.2 布局即约定，可接受；M2 结论） |
| D6 | checklist 措辞对齐归档约定：`SUMMARY` 改为 `T0x-SUMMARY（如已生成）`；`CHANGELOG 是否更新` 改为 `项目级 .specs/CHANGELOG.md 是否更新（CHANGELOG 不入归档目录，勿因归档目录缺失报错）` | a) 删掉 CHANGELOG 问句；b) 不动 checklist | 保留检查意图（CHANGELOG 更新仍是 phase 7 该查的）同时消除字面误报源（弱模型按字面读 ls 无 CHANGELOG 即报）；a) 丢失检查意图 | 无实质代价 |
| D7 | 新 helper 两变体：`_l3_utf8_head_bytes <max_bytes> <file>`（文件路径形，10 处：L60/66/73/80/86/106/122/132/139/143）与 `_l3_utf8_head_stream <max_bytes>`（stdin 流形，3 处：L115/118/145，含最终总预算截断）——先 `head -c`，若尾部字节落在多字节序列中间则回退 ≤5 字节至上一完整字符边界。**v1 覆盖 l3-prompt.sh 全部 13 处位点（grep 实证），验证锚点 = 改后 `grep -c 'head -c' l3-prompt.sh` 仅剩 helper 函数体内部** | a) 沿用 smart_truncate；b) `iconv -c` 管道 | 见 0.5.2——smart_truncate 语义不匹配；iconv 属新进程依赖且 -c 静默吞字符行为难断言。纯 bash + od 检查尾部 6 字节模式即可（NFR 健壮性要求）；部分替换会留断裂 UTF-8 尾巴（L2 R3 发现 · INDEPENDENT-REVIEW-2.md） | helper 自身需测试（UTF-8 边界用例）；最终总截断回退 ≤5B 不影响 AC-1 字节上限断言（输出 ≤ max_bytes 恒成立） |
| D8 | 同步策略：bundle 修改 → cp 覆盖 `.claude/hooks` + dist 两份 + `~/.claude` 四处；**测试双源同步：`make test-sync`（cp *.bats）+ fixtures 显式 `cp -r test/fixtures/. flow-kit-bundle/test/fixtures/`（make test-sync 不覆盖子目录 · phase-3 L2 R5）+ `make check-test-sync` 收口**；`.claude/hooks` 漂移（50ff9333）经 diff 确认为旧版死代码（bundle 已清理），直接覆盖 | a) 重跑 package-dsh-plugin.sh 再生 dist；b) 保留漂移人工合并；c) 只 make test-sync 不补 fixtures | diff 实证漂移=死代码残留，无未发布修改，覆盖安全；a) 打包脚本可能有其他副作用且耗时，b) 无价值（漂移内容是已删死代码），c) check-test-sync 用 diff -rq 递归比对，漏 fixtures 必炸 pre-push | dist 再生时序与本 change 无关（下次打包自然收敛） |

---

## 2. 数据流 / 架构图

```
Stop hook 29-independent-review.sh（不改）
  └─ l3-review.sh（不改调度；L81-82/L103-104 既有组装：context_preamble 前置拼接 ← 生产拼接层，禁动）
       └─ prompt = _l3_inject_context(...) 输出 + _l3_build_prompt(...) 输出（前后拼接，既有行为）
            │
            │  ① _l3_inject_context(phase, artifacts_dir)      ← 新逻辑（Step 0，经组装层物理置最前）
            │      ├─ 定位审查文件 INDEPENDENT-REVIEW-<phase>.md（artifacts_dir 内）
            │      ├─ _l3_extract_prior_findings()  → severity|file|摘要 单行集（critical>major，≤600B，溢出 +k more）
            │      ├─ 响应检测（三类锚任一命中）：`## 主 agent 响应` 段头 / `主 agent 反驳：` 段 / 行内 `(Fixed in|Tech-debt|Not-applicable):` 标记（实证格式 `- **R1** — Fixed in:`，去行首锚）→ 提取要点 ≤200B
            │      │    └─ 三类锚皆无且存在前轮发现 → 标注「主 agent 未响应前次发现」
            │      └─ 两者皆空 → 静默（AC-7）
            │
            │  ② _l3_build_prompt 自身段序（重排目标）：
            │      CHANGELOG/LESSONS 注入（phase 7，D5 修正后的 project_root，_l3_utf8_head_bytes 3000/2000）
            │      → 7 文件工件循环（既有，head -c 换 _l3_utf8_head_bytes）
            │      → checklist（D6 措辞）+ 尾部总预算截断改走 _l3_utf8_head_stream（max_chars 字节预算语义不变 · 属 D7 13 处位点之一 L145）
            │
            └─ prompt → l3-api.sh（不改）→ 外部模型
                       → 追加写 INDEPENDENT-REVIEW-<phase>.md 的 ## L3 段（不改）
                                  │
下一轮重审 ←── ① 再提取（闭环：反馈现在确定性进入 prompt）

外部输入（只读）：.specs/CHANGELOG.md、.specs/LESSONS.md、.specs/<id>/INDEPENDENT-REVIEW-*.md
边界（不触碰）：凭证解析 / 模型链 / .done 写入 / correction / Gate 逻辑
```

## 3. 关键状态机（如有）

N/A（无状态机变更；重审轮次推进由既有 l3-review.sh hash 比对逻辑管理，不改）。

## 4. ADR 索引

- `@.specs/adr/025-l3-prior-feedback-injection.md`（D1+D2+D4：L3 重审反馈注入协议——可逆性低：一旦弱模型依赖反馈信号，移除会复活假阳性循环）

## 5. 风险

| # | 风险 | 影响 | 概率 | 缓解 |
|---|---|---|---|---|
| R1 | prompt 段顺序变化破坏既有 bats 断言（test_l3_pipeline_fix / test_l3_review / test_hook_integration 等锚定旧结构） | 测试红 → 阻塞 770 基线 | 高 | 4-dev 前先跑全量 bats 记录受影响用例清单；只修断言锚点不改测试意图；同步更新五处副本后再跑（AC-6 断言无 fail/skip） |
| R2 | 提取器对两类格式（L2 🔴/🟡 行 / L3 JSON）解析脆弱——审查文件由模型生成，格式可能漂移 | 反馈段空 → 退化为现状（静默无反馈） | 中 | 提取失败即静默降级（AC-7 兜底）；bats 固化三类 fixtures 样本（L2 段 / L3 段 / 混合）；正则只锚定稳定结构（L2 段 `### 🔴`/`### 🟡` 行头；L3 段 `"critical"`/`"major"` 数组键名——无 `"severity"` 字段，`l3-prompt.sh:156` schema 实证） |
| R3 | `.claude/hooks` 副本覆盖丢失"看似漂移实为本地修改"的内容 | 未发布修改被冲掉 | 低 | diff 已实证漂移=旧版死代码（agent_response 残留）；覆盖前将 diff 存档到 `.specs/l3-prompt-loop-fix/sync-drift-20260904.patch` 留痕 |
| R4 | 长期债：字节预算语义仍是近似（UTF-8 混排下 20000B ≠ 20000 字符），反馈段前移只是让关键信息确定性存活，未根治预算语义混乱 | 未来新增尾部段仍可能被截 | 中 | v1 接受（REQUIREMENT v2 已列 smart_truncate 统一 + env 配额）；ADR-025 Consequences 显式记录 |
| R5 | D5 dirname×3 启发式隐含「archive 恒为一层嵌套」不变量（`.specs/archive/<id>/`）；未来布局分桶（如按日期加一层）会静默解析出错误 project_root → CHANGELOG/LESSONS 注入静默为空（落 AC-7 兜底，难排查） | 归档布局变更后 phase 7 注入退化 | 低 | ARCHITECTURE §1.2 布局约定为锚点；v2 收敛到调用方显式传参（D5 备选 b）；本 ADR-025 记录不变量 |
| R6 | 响应检测假阴性：主 agent 以三锚外措辞响应（自由文本无段头/反驳标记/分类行）→ 误标「未响应」注入下轮 prompt | 给下轮模型不实状态信号，诱发冗余响应噪声 | 低 | D4 显式接受「宁漏报不误报」语义（误检"已响应"才掩盖真实悬置）；分类行协议随本 change 固化后假阴性面收敛；R2 的 fixtures 覆盖三类锚正例 |

## 6. 不在范围

- Claim 3（Gate 2 `jq empty` fail-open）——已裁定为文档化既定设计（33 号接管），不修
- prompt 侧「## 主 agent 响应」段头标准化（在 5/6/7 prompt 响应指令中统一措辞）——提取器三重锚定不依赖它；ADR-025 已记录协议，prompt 措辞统一留给后续文档 change
- phase 6 归档布局重审的 git diff 错目录场景——D5 已顺带覆盖 L91-92 解析，但 phase 6 专属行为验证不在本轮 AC（触发场景近乎不发生：归档晚于 phase 6 .done）
- L3 模型链 / 凭证解析（ADR-023 域；opencode env 缺失问题属部署配置，非本 change 代码域）
- max_chars 环境变量化、smart_truncate 统一截断层（REQUIREMENT v2）
- l3-review.sh 调度与 .done 机制
- dist 再生流程（package-dsh-plugin.sh 时序）

---

## 9. 架构沉淀建议（供 `A-evolve` 同步用 · 软约束）

### 9.1 新增的可复用抽象

| 路径 | 能力 | 触发场景 | 复用建议 |
|---|---|---|---|
| `hooks/stop/lib/l3-prompt.sh :: _l3_extract_prior_findings` | 从 INDEPENDENT-REVIEW-*.md 提取前轮发现单行摘要（双 tier 格式） | 任何"重试需携带前轮反馈"的 hook 场景（如 L2 重审、AI 分析重跑） | 后续同类注入需求先复用它，不再各写解析器 |
| `hooks/stop/lib/l3-prompt.sh :: _l3_utf8_head_bytes` / `_l3_utf8_head_stream` | 文件级/stdin 级字节 cap + UTF-8 边界回退截断（两变体） | 所有对可能含中文的文件或流做 head -c 的 hook 代码 | **v1 已覆盖 l3-prompt.sh 全部 13 处位点；其余 lib 文件（l3-review.sh 等）的 head -c 渐进替换留给后续 change（v2 项）** |

### 9.2 新增 / 改变的项目级技术决策

| 决策 | 取值 | 影响范围 | 推翻代价 |
|---|---|---|---|
| L3 重审 prompt 段顺序 | 反馈段 > 项目级文档 > 工件 > checklist（关键信息前置） | l3-prompt.sh 全部阶段构造 | 低（纯顺序调整，但移除会复活假阳性循环——见 ADR-025） |

### 9.3 新增 / 修改的跨模块契约

N/A（_l3_build_prompt 三参签名不变；.done / correction / hook 链契约不变）。

### 9.4 新增 / 升级的依赖

无（零新增依赖）。

### 9.5 禁动清单变化

```
- 新增禁动：_l3_build_prompt 工件循环之后禁止追加任何"必要段"（新段必须前置于工件循环之前，
  或显式提高预算）——尾部追加 = 被字节截断确定性吞掉（本 change 的根因之一）
```

---

> 本文件不包含完整代码实现。函数签名、伪代码、接口定义可以；函数体不行。
