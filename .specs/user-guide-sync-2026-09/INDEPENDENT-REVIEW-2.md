# 独立审查 · 阶段 2

## L2 盲审

审查对象：`.specs/user-guide-sync-2026-09/` 下 DESIGN.md（全读）、REQUIREMENT.md、CHANGE.md（全读）；另按指令做了仓库实物核对（.gitignore / git status / archive gen slides.json / stop-hook.json / hooks/stop 33-34 / CONTEXT.md 锚点 / 根 pptx 页数）。

通过项（简要）：D1–D8 每行均有「备选 / 选择理由 / 取舍代价」，页数 20、config 键列 12 键、dsh 页无条件新增、生成器归属 `.specs/user-guide-deck-gen/` 与 REQUIREMENT/CHANGE 口径一致；archive gen slides.json=25（tech deck）与根 pptx=19 页基线属实；tools/ 与 `.specs/user-guide-ppt-sync/` 被 .gitignore:35-36 忽略、deck-gen 无 ignore 规则；AC-3e 的 12 个 stop-hook modules 键与 33/34 脚本名与实物一致；数据流/演进顺序图、ADR 索引（无新增 ADR 判定基于「纯文档、D1-D8 可逆」，成立）、§9.1/9.2 沉淀表基本符合模板；DESIGN 无整函数实现体（仅布局函数名/字段约定级描述）。

### 🟡 F1 · 风险表缺「实现/上线/长期债」分类列：模板分段要求未满足

**Severity**：🟡 Important

**Symptom（症状）**：DESIGN.md §5（L106-115）风险表 6 行只有「风险 / 影响 / 概率 / 缓解」四列，R1–R6 未按实现期 / 上线期 / 长期债三类显式分段或加类别字段；虽数量 ≥3，但类别维度缺失。

**Source（源头）**：设计模板对风险段的要求——≥3 条且分实现/上线/长期债（本 L2 核对要点）；DESIGN 自身 §9.2 已把 R5/R6 类问题定性为长期债，说明材料具备但未在风险表落列。

**Consequence（后果）**：风险缓解无法按阶段排期与验收；模板 toll-gate 判不合规；长期债（R5 生成器版本漂移、R6 三份副本漂移）不会被显式跟踪到归档后，退化为一次性缓解。

**Remedy（修补）**：给 R1–R6 补「类别」列或按三类分组（例如 R1/R2/R3→实现期、R4/R6→上线期、R5→长期债，R6 的 dist 刷新动作若保留则需同时入 scope，见 F3），确保三类各 ≥1 条。

### 🟡 F2 · R6 缓解措施引入 v1 scope / AC-7 白名单外的动作：包刷新与白名单冲突

**Severity**：🟡 Important

**Symptom（症状）**：DESIGN.md L115 R6 缓解写「INTEGRATION 在归档后重跑 package-dsh-plugin.sh 刷新 dist/插件 docs 副本」；但 REQUIREMENT.md L94-101 v1 范围与 L71-72 AC-7 白名单只含指南两副本、pptx、生成器源、change 产物等，未含 dist/插件文档输出；CHANGE.md「影响面」也写插件 docs 由「下次 package-dsh-plugin.sh 自动带入」。

**Source（源头）**：DESIGN §5 R6 vs REQUIREMENT AC-7 / v1 范围切分 vs CHANGE.md 影响面；本 change 的 0.5.1 禁动清单精神（不改运行时/打包链）。

**Consequence（后果）**：DEV/INTEGRATION 照缓解执行会产出 AC-7 白名单外的 git 变更 → AC-7 的 porcelain 断言 fail，或执行者因怕脏 diff 跳过缓解 → 插件 docs 旧口径风险又回到「无动作」状态，R6 缓解形同虚设。

**Remedy（修补）**：三选一并写进 DESIGN/REQUIREMENT：(a) 把「归档后重跑 package-dsh-plugin.sh 并提交 dist 插件 docs」显式加进 v1 scope + AC-7 白名单 + AC-9/INTEGRATION 步骤；(b) 删去该缓解、明确插件 docs 刷新归 v2/下次打包；(c) 标记 Not-applicable 并说明由哪个后续 change 承担。不能只留在风险表缓解列。

### 🟢 F3 · 新增清单与仓库实物有出入：deck-gen 未跟踪且 slides.json/deck_checks.py 尚不存在

**Severity**：🟢 Minor

**Symptom（症状）**：DESIGN.md L31-33 与 D4（L66）把 `.specs/user-guide-deck-gen/` 列为「本次新增（tracked）」，REQUIREMENT.md L55-58 AC-5/依赖段称生成器含 slides.json（20 页）+ build.py + deck_checks.py；仓库实物（find + git status）显示该目录现只有 build.py / layouts.py / theme.py / utils / README.md，无 slides.json、无 deck_checks.py，且 `git ls-files .specs/user-guide-deck-gen` 为空、porcelain 显示 `?? .specs/user-guide-deck-gen/`（未跟踪）。

**Source（源头）**：DESIGN 0.5.1 自称「实际清单，来自 grep/ls」与「本次新增（tracked）」；仓库 git 实物；REQUIREMENT AC-5 依赖假设。

**Consequence（后果）**：若清单按字面理解，AC-5 的 build.py 可复跑断言与 deck_checks.py 断言目前无对象可验；生成器文件若拖到后阶段才 git add，D7 的阶段提交记录会缺「新增 tracked」实据，归档六件套与源文件分家。

**Remedy（修补）**：把 0.5.1 措辞改为「本次新增（DEV 创建后 tracked）」并把 slides.json（20 页内容源）与 deck_checks.py 显式列入本 change 创建物清单；若现骨架是预研产物，则在 DESIGN 收口前的阶段提交中纳入跟踪，避免「已存在但未入库」状态延续到 TASK 拆解。

### 🟢 F4 · CONTEXT 术语表残留「三级链」旧口径，与 D3/AC-3f 的五级锁决策自相矛盾

**Severity**：🟢 Minor

**Symptom（症状）**：`.specs/CONTEXT.md:81` 仍写 fk_resolve_model「按三级优先级链解析 L2/L3 审查模型名」、L582 写「模型名沿用 fk_resolve_model 三级链」；同文件 L256 却已有 `[2026-09-03]` 已锁决策记录五级解析链。DESIGN.md D3（L65）与 REQUIREMENT.md AC-3f 以「CONTEXT 已锁决策 2026-09-03」为五级口径权威；DESIGN 0.5.1 对 CONTEXT 只列「术语表 · 已追加」，未覆盖上述残留行。

**Source（源头）**：DESIGN D3 / REQUIREMENT AC-3f 引用的权威源（CONTEXT L256）与 CONTEXT 自身术语行（L81/L582）矛盾；AC-2 的禁词 grep 只约束「指南正文」，不会捕获 CONTEXT 残留。

**Consequence（后果）**：权威文档自相矛盾，后续 docs-sync/生成器维护者可能把「三级链」旧措辞再次抄回指南或 TEST grep 锚点；本 change 的「旧口径已证伪」声明在 CONTEXT 层面并不彻底。

**Remedy（修补）**：把 CONTEXT L81/L582 两条术语行的口径并入本 change 触碰范围（与 L256 五级链措辞对齐，可标注「2026-09-03 起为五级，见已锁决策」），或显式在 DESIGN §0.5.1/范围排除中声明这两行不改并给出理由，不能留隐形矛盾。

**Verdict**: pass

## L2 重审（阶段 2 DESIGN · 快速复审）

核验：DESIGN.md 全读（142 行）；CONTEXT.md 相关词条 grep；仓库只读，无改动。

- F1 ✅ 风险表已含「类别」列：R1-3=实现期 / R4=上线期 / R5=长期债 / R6=上线期/长期债，六行齐全。
- F2 ✅ R6 缓解已注明：dist/ 被 .gitignore 忽略（.gitignore:29）、重跑不产生 git 变更、profile docs 随重装/重启生效（v2 记录）、CHANGELOG 标注。
- F3 ✅ 0.5.1 已改「DEV 创建后即 tracked，不滞留未入库状态」，且 slides.json（20 页）与 deck_checks.py 显式列入 T07/T08 创建入库物。
- F4 ✅ CONTEXT 词条已修正：L81 改「五级优先级链（2026-09-03 起含站点默认 tier-4/5）」、L84 五级+空串兜底、L251/L582 同步五级口径，与 L256 已锁决策一致；无「三级链」残留。
- 新增问题：无 Critical/Important，无 Minor 需改项。

**Verdict**: pass

---

## L3 重审（deepseek-v4-flash-0731 外部模型 · 2026-09-03 22:13）

> 自动生成于 2026-09-03 22:13。由 l3-review.sh 写入。

### 审查结论

```json
{
  "critical": [],
  "major": [
    {
      "file": "DESIGN (user-guide-sync-2026-09) §0.5.2 / D4",
      "issue": "声明式生成器被描述为“跨 change 长期维护居所”，但其输入 slides.json 内容与 layouts 大量耦合 tech-deck 的既有实现；设计未给出生成器与既有 tech-deck 生成器之间的依赖/复用边界（是拷贝还是共享模块），也未说明未来 MD 变更时如何保证 slides.json 与 MD 事实同步的机制（仅靠人工维护）。",
      "why": "这属于 brownfield 架构对齐的核心：若拷贝则形成双份布局代码长期漂移，若共享则与“沿用移植”表述矛盾；且 deck 内容源 slides.json 与 MD 之间无自动一致性校验，长期债 R5 只覆盖运行时依赖版本，未覆盖内容漂移。",
      "fix": "明确生成器与 tech-deck gen 的关系（拷贝基线版本+后续独立演进，或提取共享 layouts 包），并在 DESIGN 中补充 slides.json↔MD 事实一致性的校验手段（如关键数字从 MD grep 后注入 slides.json，或 TEST 中比对 slides.json 与 MD 断言清单）。"
    },
    {
      "file": "DESIGN §5 R6",
      "issue": "R6 把“插件 docs/ 依赖打包刷新”列为风险，但缓解只写“重跑 package-dsh-plugin.sh 刷新 dist 产物——dist/ 已被 .gitignore 忽略，重跑不产生 git 变更”。这没有验证 dist 刷新后插件 profile 内 docs 是否真的会被下次重装/重启读取，也未说明 AC-7 白名单与 dist 忽略之间的发布语义。",
      "why": "如果 dist 产物被 git 忽略，那么仓库内消费者（插件安装/打包）如何获得更新的 docs？仅靠用户本地重跑打包不可复现；若发布物实际是 dist 的未跟踪文件，则存在“仓库跟踪内容与交付内容不一致”的契约风险。",
      "fix": "明确 dist 产物的生成/分发路径（CI 或发布动作），或将“插件 docs 同步”纳入本 change 的验证范围（至少给出一次实际打包后 docs 生效的证据），否则将该风险升级为 out-of-scope 并显式记录遗留。"
    },
    {
      "file": "DESIGN §4 ADR 索引",
      "issue": "设计声明“D1-D8 均可在后续 change 推翻，代价低”，但 D4 新建 tracked 生成器并作为跨 change 长期维护居所，其推翻涉及既有生成器迁移与后续所有 deck 更新路径；D6 的 gate_config=all 审查流程若后续 change 不沿用则丧失连续性。将这类决策统一归为“无新增 ADR”削弱了决策的可追溯性。",
      "why": "ADR 的价值在于记录影响后续变更的决策边界；D4/D6 明显具有跨 change 影响，与“无不可逆决策”的断言冲突，审阅者无法判断这些决策的未来约束力。",
      "fix": "至少为 D4（生成器居所与复用契约）和 D6（强制审查链）单独立轻量 ADR，或在 DESIGN 中明确“哪些决策仅限本 change、哪些成为仓库约定”并写入 CONTEXT 已锁决策。"
    }
  ],
  "minor": [
    {
      "file": "DESIGN §0.5.1 禁动清单",
      "issue": "禁动清单列了“flow-kit-bundle/install.sh 等任何运行时实现”，但 D1 又规定 bundle 副本 = 机械 cp 同步，cp 会 touch flow-kit-bundle/FLOW-KIT-用户指南.md——该文件是否属于“任何运行时实现”的禁动范围未明确。",
      "why": "禁动清单与编辑动作存在字面冲突，执行者可能误判是否允许写 bundle 下的文件。",
      "fix": "明确禁动清单针对“运行时实现”，文档副本（FLOW-KIT-用户指南.md）在本 change 中显式允许写入，并保留在触碰清单中。"
    },
    {
      "file": "DESIGN §2 数据流图",
      "issue": "数据流图显示事实源经 MD 后 cp 到 bundle 副本，但 MD 的“逐节增量（D2）”与 deck 的 slides.json 之间没有箭头/校验连接，图中“校验”段只列出 MD grep 断言与 PPT 文本断言，未说明两套断言如何保证 MD 与 deck 事实一致。",
      "why": "同一事实（如模块数、命令字段）若在 MD 和 slides.json 分别维护，可能出现 MD 改对而 deck 漏改，与 D5 的 20 页重写风险直接相关。",
      "fix": "在数据流图中增加 slides.json ← MD 的事实抽取/一致性校验步骤，或在 TEST 中加 slides.json 与 MD grep 断言交叉比对。"
    },
    {
      "file": "DESIGN §5 R3",
      "issue": "R3 将 pre-commit make test 耗时列为高概率风险，但缓解只有“分组提交 + 后台 poll”，未评估若 make test 失败时的恢复路径（commit 被 hook 拒绝后阶段产物如何处理）。",
      "why": "高频提交策略下，hook 失败会阻塞阶段提交，影响 L2/L3 逐段审查节奏；风险缓解不完整。",
      "fix": "补充 hook 失败时的处理：可临时 --no-verify 并记录原因，或先本地跑测试再分组提交，并明确审计例外路径。"
    },
    {
      "file": "DESIGN §9.2 版本日期口径",
      "issue": "“单日期 2026-09-03 落在 MD 头与 deck 首页；变更时三处同改”未说明第三处具体是哪（bundle 副本？CONTEXT？），且“三处同改”与 9.1 的“只改 slides.json 重跑 build.py”存在操作歧义。",
      "why": "操作指引不一致会导致执行者漏改或重复改。",
      "fix": "明确三处 = 根 MD 头、bundle 副本 MD 头、slides.json 首页文本（deck 由 build 生成），并给出同步命令或检查断言。"
    }
  ],
  "verdict": "pass",
  "summary": "设计整体合理且 brownfield 对齐充分，D1-D8 决策大多有据可查，但生成器复用边界、dist 发布语义与 ADR 边界三处 major 问题需在实施前澄清，不构成阻断。"
}
```

L3_artifact_hash: 3f575a3ae2165c3b5a90cf5dc000aa6f81cc03467400b5e8f68ba7c6369cb32a
