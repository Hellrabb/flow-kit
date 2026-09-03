# DESIGN: 用户指南与用户指南 PPT 同步至 2026-09 功能集

- **Change ID**: user-guide-sync-2026-09
- **关联**: `@.specs/user-guide-sync-2026-09/REQUIREMENT.md`、`@.specs/CONTEXT.md`、`@.specs/ARCHITECTURE.md`（meta/distribution 仓库 · 无传统技术栈）
- **作者**: AI（Architect 角色）+ 人工 review

---

## 0. 技术栈选定

- **选定**：既有仓库工具链（无新运行时依赖）
- **前端/后端/数据库/部署**：N/A（本仓库为 flow-kit 分发包/meta 仓库）
- **关键依赖**：python-pptx 1.0.2（本机已验证）· LibreOffice 24.2.7.2 headless（渲染验证）· graphviz 2.43（仅现有 tech-deck 图表，本 change 不新增图表）· bats via make test
- **理由**：CONTEXT「已锁技术决策」无相关冲突；文档/演示产物不需要引入新栈
- **明确排除**：不做在线文档站 / Sphinx / docsify；不做 PPT 模板工程化框架（out 范围）

---

## 0.5 既有架构对齐（brownfield 必填）

### 0.5.1 本次 change 触碰的既有模块

```
触碰文件（实际清单，来自 grep/ls）：
- FLOW-KIT-用户指南.md（根 · 唯一编辑源 · 70KB / 1300+ 行）
- flow-kit-bundle/FLOW-KIT-用户指南.md（打包副本 · 现与根逐字节一致）
- flow-kit-用户指南.pptx（根 · 19 页 · 7/25 基线）
- .specs/archive/2026-07-31-user-guide-ppt-sync/gen/（tech-deck 生成器 · 只读参考，本次不写）
- .specs/CONTEXT.md（术语表 · 已追加）

本次新增（DEV 创建后即 tracked，不滞留未入库状态）：
- .specs/user-guide-deck-gen/ —— 用户指南 deck 声明式生成器（本 change 创建：theme.py/layouts.py/build.py/README.md 已建；slides.json（20 页内容源）与 deck_checks.py 由 T07/T08 创建后入库），跨 change 长期维护居所
- .specs/user-guide-sync-2026-09/* —— 本 change 产物（后归档）

禁动清单（与本次无关）：
- flow-kit-bundle/hooks/、flow-kit-bundle/skills/、dsh-flow-kit/lib/、flow-kit-bundle/install.sh 等任何运行时实现
- .specs/archive/ 全部既有归档
- flow-kit-技术设计.pptx、flow-kit-ecosystem-guide.md、根 README.md、dsh-flow-kit/README.md、dsh-flow-kit/DESIGN.md
```

### 0.5.2 既有抽象沿用对照表

| 本次需要 | 既有有没有？路径 | 决定 |
|---|---|---|
| 用户指南 deck 生成 | 无独立可复现生成器（现 deck 为 7/14-7/25 临时脚本 + tools/pptx-light-sync.py 微调产物，tools/ 不入库） | **新建**声明式生成器（理由：deck 需要长期随 MD 演进，见 D4） |
| 生成器布局/主题代码 | tech-deck 生成器 `.specs/archive/2026-07-31-user-guide-ppt-sync/gen/`（theme.py/masters.py/utils/shapes.py，同 16:9 与色系） | **沿用移植**（拷贝适配，不发明新主题体系） |
| MD↔bundle 副本同步 | 现状手动 cp 保持一致（历史提交均 SAME） | 沿用：编辑后 `cp` 同步 + `cmp` 断言（D1） |
| 渲染验证 | 本机 LibreOffice headless + pdftoppm | 沿用（首次用，本 change 固化命令） |
| L2/L3 独立审查 | 仓库 hooks/prompt 既有（L2-blind-review.md / l3-review.sh） | 沿用 + gate_config=all |

### 0.5.3 沿用模式 vs 引入新模式

- 内容修订：**沿用**「章节级增量编辑」模式（docs-sync / l2-l3-model-config 的先例），不整文重写
- PPT 交付：**引入新模式**——声明式 slides.json + 布局函数（tech-deck 已验证同模式），理由：deck 无既有可复现源，21 项 slide 级修订必须可 diff/可复跑
- 术语沉淀：**沿用** CONTEXT.md 术语表区块追加（跨 change 长期累积约定）

---

## 1. 决策清单

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D1 | 指南 MD 唯一编辑源 = 根文件；bundle 副本 = 机械 cp 同步 + `cmp -s` 断言（AC-4） | 以 bundle 为源 / 双源手工维护 | 根文件是用户可见文档 & 打包脚本 §3 从 bundle 拷入插件 docs/；单向 cp 简单可验证 | 每次改指南必须记得 cp（由 TASK/自检清单兜底） |
| D2 | MD 修订为章节级增量（版本头/§1 组件与平台/§2 安装/§4 命令表/§7 Stop Hook 与模型链/§12 结构索引），禁止全局重写 | 全文重写 / 仅加附录 | 70KB 文档大部分仍准确；增量 diff 可审、回归风险小；AC-2 过时串清零 + AC-3 新事实就位均可断言 | 章节内仍有措辞不统一风险（review 兜底） |
| D3 | 数字/事实口径以仓库实物为准：Stop Hook 描述 = 「12 逻辑模块（config 键）+ 00-gate/99-report 基础设施 + PreToolUse/SessionStart/pre-commit 门禁」，skills = 17 个 flow-*；五级链字段/顺序以 `common.sh fk_resolve_model` 注释与 CONTEXT 已锁决策 2026-09-03 条为准 | 沿用旧口径（17 模块/三级链） | 旧口径已证伪；实物口径可从 config/脚本直接复核 | 口径更新波及多处表格（TASK 拆行处理） |
| D4 | 新建 tracked 生成器 `.specs/user-guide-deck-gen/`：slides.json（内容）+ layouts（沿用 tech-deck masters 家族移植 + 用户指南版式函数）+ build.py → 输出根目录 `flow-kit-用户指南.pptx`；本 change 首建并承担 19→20 页重建 | 就地 python-pptx 打补丁脚本（pptx-light-sync 式） | 20 页级内容更新在补丁脚本里不可读/易脆；声明式源可 diff、可复跑、未来 change 可继续维护；与 tech-deck 同构 | 首次重建需对齐既有视觉（先渲染基线 PNG 对照，见 R1 缓解）；生成器代码量 ~600-800 行 |
| D5 | 新 deck 页数 = 20：s14 模型链页改写为五级链；s2/s4 平台化组件表述；s5 命令表补 model/gate-config/doctor 报告；s11 阶段 7 补 pre-commit/archive-commit；s16 Stop Hook 页按 D3 口径重写；新增 1 页「dsh 插件化安装与挂载」 | 不加页只改文字 / 大改版式 | 加 1 页承载 dsh 平台（本 change 最重要新受众）；其余页在原文上改，保视觉连续 | 页数断言从 19 → 20（TEST 固化） |
| D6 | L2/L3 门禁按 gate_config=all 逐阶段走：规划链（1/2/3）产物在 DEV 前完成审查闭环，实施链（5-test/6-review/7-integration）在对应产物后审查；审查文件 `INDEPENDENT-REVIEW-N.md`（L2 段 + L3 段）落 change 目录 | 全链结束后一次补审 / 仅 L2 | 与 dsh-flow-kit-sync-2026-09 补审规格一致且错误早发现；REQUIREMENT AC-8 要求 | 每阶段多一轮外部模型调用（预算已含） |
| D7 | 提交纪律：每阶段完成即 Conventional Commit（`docs(user-guide-sync-2026-09): …`）；pre-commit 自动 make test（770 bats · 数分钟）由分组提交吸收 | 最后一次性大提交 | 阶段 diff 供 L2 盲审逐段引用（如 2999024..HEAD 先例）；失败回退粒度小 | 提交次数多 + hook 耗时 |
| D8 | 归档目标 `.specs/archive/2026-09-03-user-guide-sync-2026-09/`（git mv + 六件套 + 审查文件），STATE/CHANGELOG/LESSONS 同步 | 就地留 `.specs/<id>/` | 仓库 archive 惯例（STATE.md last_change_archived 链） | 归档后引用路径变长（历史先例同） |

---

## 2. 数据流 / 架构图

```
[事实源]                         [编辑源]                      [产物]
hooks/config/stop-hook.json ─┐
flow-kit-bundle/*（实物）   ─┼─► FLOW-KIT-用户指南.md(根) ──cp──► flow-kit-bundle/FLOW-KIT-用户指南.md
common.sh fk_resolve_model ─┘        │                             （下次打包自动进插件 docs/）
                                      │ 逐节增量（D2）
                                      ▼
                            .specs/user-guide-deck-gen/slides.json + layouts
                                      │ build.py（python-pptx）
                                      ▼
                            flow-kit-用户指南.pptx (20 页 · 2026-09-03)

校验：
  MD：grep 断言（版本/禁词/新事实） + cmp 副本 + make test 回归
  PPT：build 后 python-pptx 文本断言 + LibreOffice→PDF 页数/渲染抽查
审查：
  gate_config=all ─► INDEPENDENT-REVIEW-{1,2,3,5,6,7}.md（L2 子代理盲审 + L3 外部模型）
归档：git mv .specs/user-guide-sync-2026-09 → .specs/archive/2026-09-03-user-guide-sync-2026-09 + STATE/CHANGELOG
```

## 3. 关键状态机（如有）

N/A（文档 change 无运行时状态机）。演进顺序：规划链（0→1→2→3，L2/L3 门禁）→ 实施（DEV：MD 先行 → deck 源 → build → 渲染）→ TEST 断言 → REVIEW（5/6/7 门禁）→ INTEGRATION 归档提交。

## 4. ADR 索引

- 无新增 ADR（本 change 不改运行时、无不可逆决策；D1-D8 均可在后续 change 推翻，代价低）
- 沿用并**只做文档化**（不 supersede）：ADR-012/013（模型解析链）、ADR-024（correction 卫生）、docs-sync 已锁决策（2026-06-22 三文档同步策略）
- 归档参考：`.specs/archive/2026-09-03-dsh-flow-kit-sync-2026-09/`（内容同步型 change 的产物与审查规格范本）

## 5. 风险

| # | 类别 | 风险 | 影响 | 概率 | 缓解 |
|---|---|---|---|---|---|---|
| R1 | 实现期 | 重建 deck 视觉与原 19 页不一致（新生成器布局偏差） | 用户观感差 / 审查 fail | 中 | DEV 前先渲染现 deck 基线 PNG；布局函数沿用 tech-deck 家族 + pptx-light-sync 已知版式参数（16:9 · 顶部色带 · 宋体/Times New Roman）；TEST 抽 3 页 PNG 对照 |
| R2 | 实现期 | MD 事实漏改/口径不一致（模块数、命令字段等散布多处） | AC-2/3 不达标 | 中 | TASK 按 D3 口径逐表拆行；TEST 固化 grep 断言清单；L2 盲审逐段核 diff |
| R3 | 实现期 | pre-commit make test（770 bats）耗时数分钟、高频提交时拖慢且流式输出污染工具结果 | 进度慢/误判卡死 | 高 | 分组提交（每阶段 1-2 次）；提交用后台等 poll（避开流式截断问题）；只依赖最终 git log 判定 |
| R4 | 上线期 | 本会话（web host）无 `FLOW_KIT_L3_*` env，hook 自动路径 L3 会降级 | gate 未真正 L3 | 中 | L3 审查显式 env 注入调用 l3-review.sh（dsh-tui 进程已配值）；结果落 INDEPENDENT-REVIEW-N.md L3 段；若 API 不可用按 CHANGE 风险段显式降挡记录 |
| R5 | 长期债 | 生成器依赖本机 python-pptx/PIL/LibreOffice 版本漂移（CI 缺失） | 未来重跑失败 | 低 | build.py 开头版本自检（pptx>=1.0、soffice 存在）；README 记录锁定版本与重跑命令 |
| R6 | 上线期/长期债 | 指南/bundle/插件 docs 三份副本漂移（本 change 同步前两份；插件 docs/ 依赖打包刷新） | 插件内 doc 暂时旧 | 中 | INTEGRATION 归档后重跑 package-dsh-plugin.sh 刷新 dist 产物——dist/ 已被 .gitignore 忽略（.gitignore:29），重跑**不产生 git 变更**、与 AC-7 白名单无冲突；插件 profile 内 docs 随用户下次重装/重启生效（v2 记录）；CHANGELOG 标注 |

## 6. 不在范围

- `flow-kit-技术设计.pptx` 与 tech-deck 生成器（slides.json 25 页）不动
- flow-kit-ecosystem-guide.md / 根 README / 插件 README/DESIGN 的同步（v2）
- 视觉重设计、deck 模板工程化、图表新增（dot/mscgen）
- 指南国际化、平台分版
- 任何运行时实现修复（含 common.sh 注释头 minor）

---

## 9. 架构沉淀建议（本 change 完成后供 `A-evolve` 同步用 · 软约束）

### 9.1 新增的可复用抽象（建议 append 到 CONTEXT「既有抽象索引」段）

| 路径 | 能力 | 触发场景 | 复用建议 |
|---|---|---|---|
| `.specs/user-guide-deck-gen/` | 用户指南 deck 声明式生成器（slides.json + layouts + build.py，输出根 pptx） | 任何未来指南 deck 内容更新（新功能同步/日期刷新） | 只改 slides.json 与必要布局，重跑 build.py；不要再用一次性 python-pptx 脚本改成品 |

### 9.2 新增 / 改变的项目级技术决策

| 决策 | 取值 | 影响范围 | 推翻代价 |
|---|---|---|---|
| 用户指南 deck 生成器居所 | `.specs/user-guide-deck-gen/`（tracked · 跨 change 维护，不入 tools/ 忽略区） | 所有未来指南 deck 更新 | 低（纯工具代码，可迁移） |
| 指南/bundle/PPT 三者的版本日期口径 | 单日期 2026-09-03 落在 MD 头与 deck 首页；变更时三处同改 | 本仓库文档维护 | 低 |

### 9.3/9.4/9.5：N/A（无跨模块契约、无依赖变动、无禁动清单变动）
