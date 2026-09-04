# REQUIREMENT: 用户指南与用户指南 PPT 同步至 2026-09 功能集

- **Change ID**: user-guide-sync-2026-09
- **关联**: `@.specs/user-guide-sync-2026-09/CHANGE.md`、`@.specs/CONTEXT.md`

---

## 用户故事

- **US-1**：作为 flow-kit 新用户（Claude Code / dsh / OpenCode 任一平台），我想按官方指南安装并开始一个 change，以便指南描述的目录结构、命令行为与 2026-09 实际版本一致、不会把旧 hook 模块数与旧模型链当新用法。
- **US-2**：作为已有用户，我想在指南里找到 dsh 插件化安装/挂载、五级模型链（含站点默认 tier）与 `/flow doctor` correction 卫生报告的准确说明，以便在 DSH 上正确配置审查模型并排查矫正状态。
- **US-3**：作为分享者，我想拿到与指南同源、日期/数字不冲突的 19+ 页用户指南 PPT，以便汇报时不被「17 模块 / 三级链 / 20260713」等过时信息误导。
- **US-4**：作为仓库维护者，我想让 `FLOW-KIT-用户指南.md` 与其 `flow-kit-bundle/` 副本保持逐字节一致、PPT 生成源可重跑，以便后续打包（package-flow-kit.sh / package-dsh-plugin.sh §3）不会带出漂移副本。

## 验收准则（AC）

每条用 Given / When / Then，必须可验证。

### AC-1 · 版本头与日期更新

- **Given** 根目录指南文件 `FLOW-KIT-用户指南.md`
- **When** 打开文件头 5 行
- **Then** 版本行写作 `版本: 2026-09-03`，来源行仍指向 `https://github.com/hellrabbit/flow-kit/tree/develop`；文件头 5 行内不出现其他 `20[0-9]{6}` 形式日期
- **验证方式**: `head -5 FLOW-KIT-用户指南.md | grep -E '^> 版本: 2026-09-03'` 且 `head -5 FLOW-KIT-用户指南.md | grep -q 'github.com/hellrabbit/flow-kit/tree/develop'`；无其他 8 位日期：`head -5 FLOW-KIT-用户指南.md | grep -oE '20[0-9]{6}' | grep -vx '20260903' | wc -l` 输出为 0（2026-09-03 带连字符不匹配 `20[0-9]{6}`，故只需排除无连字符变体）

### AC-2 · 过时硬事实清零（MD）

- **Given** 更新后的指南（根目录与 flow-kit-bundle 副本）
- **When** 在既定检索范围内检索过时表述
- **Then** 以下字符串在检索范围内不再出现：`20260713`、`17 个模块`、`三级优先级链`、`三级链`、`仅 Claude Code`、`仅为 Claude Code`；「Claude Code」作为平台名之一可保留，但不得以「仅/只为 Claude Code」类表述宣称独占
- **检索范围**（AC-2/AC-3/AC-5 统一口径）：`FLOW-KIT-用户指南.md`（根）、`flow-kit-bundle/FLOW-KIT-用户指南.md`、`.specs/user-guide-deck-gen/slides.json`、重建后 `flow-kit-用户指南.pptx` 的 python-pptx 抽取文本。豁免：`.specs/archive/`、`.specs/<旧 change>/历史产物`（AC-9 归档旧版工件含历史字样属预期，不作检索对象）。
- **验证方式**: 对上述串 `grep -c` 结果 = 0（根 + bundle 两份 MD 均查）；加查 `grep -n '只为 Claude Code'` = 0。slides.json 与重建后 pptx 抽取文本的同清单检查由 `.specs/user-guide-deck-gen/deck_checks.py` 承接（其禁词清单 = 本 AC 列表；TEST.md 复跑 deck_checks.py 并断言 exit 0）

### AC-3 · 新事实就位（MD 内容完备性）

- **Given** 更新后的指南
- **When** 按 2026-09 功能集逐项检索
- **Then** 全部命中：
  a) §1 核心组件/平台说明不再写「为 Claude Code 提供…」独占表述；dsh 平台（dsh-flow-kit 插件）作为一等安装途径出现；
  b) §2 安装新增「dsh 插件安装」小节，含 `dsh-flow-kit` 包名与 `dsh plugin` 安装命令形态；
  c) §4 /flow 命令表 `/flow model` 行描述五级解析链语义与 `l2-default=` / `l3-default=` / `--clear`；
  d) §4 `/flow doctor` 行（或对应小节）描述 correction 卫生报告（读取 `.flow-active.correction`：type / violations 去重摘要 / check→rule 回退）；
  e) §7 Stop Hook 章节模块清单与现行 `hooks/config/stop-hook.json` 的 modules 键集合**双向相等**：以 json 为唯一权威源（本 change 不改该文件，out 范围），指南模块表 **config 键列** 与 json 12 键集合（claude-md/memory/git/quality/session/project/workflow/interactive_ui_check/weak_model_compliance/flow_active_integrity/archive_commit_check/independent_review）完全一致（无多余/无缺失），并注明 00/01 与 99 为基础设施脚本；33 号 = flow_active_integrity、34 号 = archive_commit_check（对应 hooks/stop/33-flow-active-integrity.sh 与 34-archive-commit-check.sh）；含 pre-commit 门禁说明；
  f) §7 L2/L3 模型配置节含 `FLOW_KIT_L3_DEFAULT_MODEL` / `l2-default=` 等五级链字段与「显式配置永远压过默认级」语义（与 .specs/CONTEXT.md 已锁决策 2026-09-03 一致，且该决策条目存在可 grep）；
  g) `.specs/CONTEXT.md` 术语表含本 change 追加块（标记行 `user-guide-sync-2026-09 追加`）至少 3 条术语（dsh-flow-kit / doctor correction 卫生报告 / archive-commit 门禁 / tier-4/5 站点级默认模型）。
- **验证方式**（对根目录与 bundle 两份 MD 各跑一遍）：
  a) `grep -q 'DeepSeek Harness'` 且 `grep -q 'dsh-flow-kit'`（dsh 平台条目出现）；
  b) `grep -q 'dsh plugin --profile'` 且 `grep -q 'dsh-flow-kit'`；
  c) `grep -qF 'l2-default='` 且 `grep -qF 'l3-default='` 且 `grep -qF -- '--clear'`；
  d) `grep -qF '.flow-active.correction'` 且 `grep -q 'violations'`；
  e) python 断言（规则：指南模块表含表头单元格 `config 键`，取其列值集合；与 `hooks/config/stop-hook.json` modules 键集合做双向相等，json 解析失败/缺字段即 exit 1），另逐条 grep 子句 00-gate/99-report/33-flow-active-integrity/34-archive-commit-check/pre-commit；
  f) `grep -qF 'FLOW_KIT_L3_DEFAULT_MODEL'` 且 `grep -qF 'l2-default='` 且 `grep -q '显式配置永远压过默认级'`，并 `grep -q 'L2/L3 模型解析链加入站点级默认 tier' .specs/CONTEXT.md`；
  g) `grep -q 'user-guide-sync-2026-09 追加' .specs/CONTEXT.md` 且术语表行数 ≥3（dsh-flow-kit/doctor correction 卫生报告/archive-commit 门禁/tier-4/5 至少出现 3 个）。
  另：文件内 `grep -nE 'TODO|待补'` 命中数 = 0；全部断言清单同步固化于 TEST.md（TEST 阶段逐条复跑）

### AC-4 · 根目录与 bundle 副本一致

- **Given** 根目录 `FLOW-KIT-用户指南.md` 与 `flow-kit-bundle/FLOW-KIT-用户指南.md`
- **When** 逐字节比较
- **Then** 两文件一致
- **验证方式**: `cmp -s FLOW-KIT-用户指南.md flow-kit-bundle/FLOW-KIT-用户指南.md && echo OK`（顺序约定：先完成根目录修订，再 cp 同步 bundle 副本，最后统一跑 AC-2/3/4；cmp 失败即同步未完成）

### AC-5 · PPTX 重生成与内容更新（用户指南 deck）

- **Given** 现有 19 页 `flow-kit-用户指南.pptx`，以及本 change 新建的 tracked 生成器 `.specs/user-guide-deck-gen/`（slides.json 20 页内容源 + build.py；注意：`.specs/archive/2026-07-31-user-guide-ppt-sync/gen/` 是 **25 页技术设计 deck** 的生成器，仅作布局参考，不是用户指南 deck 源）
- **When** 运行 `python3 .specs/user-guide-deck-gen/build.py`
- **Then** `flow-kit-用户指南.pptx` 重建成功且 **slide 数 = 20**：首页（页 1）含日期 `2026-09-03`；deck 全文不含 AC-2 过时串；含「dsh 插件化安装与挂载」专页（**页 20**，无条件内容要求）；模型配置 slide（**页 14**）描述五级链（含 `l2-default=` 等）；无空 slide（判据：deck_checks.py 逐页抽取文本长度 > 0）
- **验证方式**: `python3 .specs/user-guide-deck-gen/build.py` 后运行 `python3 .specs/user-guide-deck-gen/deck_checks.py`（断言：20 页 / 首页日期 / 页 20 含 dsh 插件 / 页 14 含五级链字段 / 逐页文本非空 / 禁词 0；随生成器入库）

### AC-6 · 渲染与可打开性验证

- **Given** 重建后的 pptx
- **When** LibreOffice headless 转 PDF
- **Then** 转换成功（exit 0）、PDF 页数 = pptx slide 数 = 20、无异常页；抽查页固定 = 首页 / 模型配置（五级链）页 / dsh 插件页（pdftoppm exit 0 且 PNG 非空）
- **验证方式**: `soffice --headless --convert-to pdf --outdir /tmp/ppt-check flow-kit-用户指南.pptx && pdfinfo /tmp/ppt-check/flow-kit-用户指南.pdf | awk '$1=="Pages" && $2!=20 {exit 1}'` + 对页 1/14/20 各 `pdftoppm -f <n> -l <n>`（exit 0 且 PNG 非空）+ deck_checks.py 逐页文本非空断言

### AC-7 · 回归与改动边界

- **Given** 本 change 只应触碰文档/演示/change 产物
- **When** 运行仓库质量门禁并核对 git 改动集
- **Then** `make test`（bats 全量）0 fail；`git status --porcelain` 的**每一行**路径都命中白名单（前缀白名单：FLOW-KIT-用户指南.md、flow-kit-bundle/FLOW-KIT-用户指南.md、flow-kit-用户指南.pptx、.specs/user-guide-deck-gen/、.specs/user-guide-sync-2026-09/、.specs/CONTEXT.md、.specs/STATE.md、.specs/CHANGELOG.md、.specs/LESSONS.md）
- **验证方式**: `make test 2>&1 | tail -1`；路径集合比对（非白名单行数 = 0）在阶段 5 提交前执行；阶段 7 的 `.specs/archive/2026-09-03-user-guide-sync-2026-09/` 迁移以 AC-9 为准（白名单仅约束阶段 5 提交前状态）；AC-9 提交完成后 `git status --porcelain` 应为空（归档后的 dist 产物刷新不入库）

### AC-8 · 独立审查（L2+L3）闭环

- **Given** gate_config=all（阶段 1/2/3/5/6/7 均 both）
- **When** 每启用阶段（1/2/3/5/6/7；阶段 4 无独立审查 gate）产物就绪后执行独立审查
- **Then** 每启用阶段有 `INDEPENDENT-REVIEW-N.md`（N ∈ {1,2,3,5,6,7}）：含 `## L2 盲审` 段且 `**Verdict**: pass`；含 `## L3 重审`（外部模型 deepseek-v4-flash-0731，env 注入执行）且 verdict pass。降挡规则（仅限外部 API 不可用：连续调用失败/超时）：须在对应文件写 `## L3 降挡记录`（原因/时间/重试条件），此时 AC-8 通过条件 = L2 pass + 降挡记录合规；**不允许无记录静默跳过**
- **验证方式**: 逐文件 `grep -q`（清单固化于 TEST.md）；L3 verdict pass 或存在合规降挡记录

### AC-9 · 归档与提交

- **Given** 全部产物与审查闭环
- **When** 阶段 7 集成
- **Then** 活动目录移至 `.specs/archive/2026-09-03-user-guide-sync-2026-09/`（文件清单：CHANGE/REQUIREMENT/DESIGN/TASK/TEST/REVIEW/INTEGRATION.md + INDEPENDENT-REVIEW-{1,2,3,5,6,7}.md + MINOR-DEFERRED.md）；`.specs/STATE.md` 的 `last_change_archived` 更新；`.specs/CHANGELOG.md` 顶部新增本 change 行；`.specs/LESSONS.md` 有本 change 记录或显式「无新增 LESSONS」说明；提交信息为 Conventional Commits（如 `docs(user-guide-sync-2026-09): …`）
- **验证方式**: 文件存在性 + `git log --format=%s 78ec779..HEAD | grep -c '^docs(user-guide-sync-2026-09)'` 等于该区间提交数（全部提交均为本 change Conventional Commit 前缀）+ STATE/CHANGELOG grep

---

## 范围切分

### v1（本次必做）

- CHANGE/REQUIREMENT/DESIGN/TASK/TEST/REVIEW/INTEGRATION + INDEPENDENT-REVIEW-N 全套产物与归档
- `FLOW-KIT-用户指南.md` 增量修订至 2026-09 功能集（AC-1/2/3）
- `flow-kit-bundle/FLOW-KIT-用户指南.md` 逐字节同步（AC-4）
- `.specs/CONTEXT.md` 术语表补 dsh 插件相关术语
- `flow-kit-用户指南.pptx` 生成器源更新 + 重生成 + 渲染验证（AC-5/6）
- 仓库回归门禁 + 改动白名单（AC-7）
- L2/L3 独立审查闭环（AC-8）与 MINOR-DEFERRED.md 登记（ADR-017）
- 归档 + STATE/CHANGELOG/LESSONS + Conventional Commits 提交（AC-9）

### v2（下一轮考虑，不本次）

- `flow-kit-技术设计.pptx` 同步 2026-09 架构（含 dsh 插件四层同步契约）——需要技术设计受众确认
- `flow-kit-ecosystem-guide.md` / 根 `README.md` 一致性对齐（docs-sync 决策 2026-06-22 的另外两份）
- dsh-flow-kit 插件自身 README/DESIGN 的更细同步（本 change 只保证 docs/ 指南副本路径随打包更新）
- 上游 minor：`common.sh:238`「3-tier」注释头修正（MINOR-DEFERRED D1 同类）
- 指南英文版 / PPT 视觉全面改版

### out（永远不做）

- 任何运行时行为改动（flow-kit-bundle/hooks、dsh-flow-kit/lib、skills、prompts 一律不动）
- 改写归档历史（`.specs/archive/` 只读）
- 把指南重写成仅 dsh 单一平台教程（保持三平台通用）
- PPT 生成器工程化大重构（模板系统/自动 diff 等）

---

## 非功能性需求

- **性能**: 无硬性性能指标（用户明确无具体性能要求）——指南保持单文件可整读规模、PPT 重建/渲染单次完成即可；≤90KB 与 ≤120s 仅作参考量级记录（2026-09-04 triage 软化，非门禁）
- **可访问性**: 无（文档/演示产物；PPT 字号沿用生成器模板现有字号常量，本 change 不引入字号字段改动点，可 diff 验证）
- **安全**: 指南与 PPT 不得出现真实凭证/API key/内部绝对用户路径；不新增指向私有地址的链接
- **兼容性**: Claude Code / dsh / OpenCode 三平台的描述不得互相矛盾；指南/bundle/PPT 三份内容事实一致；归档产物不动
- **可观测性**: 每项修订在 CHANGE/CHANGELOG 留痕；PPT 生成器源入库，日期等易变项尽量集中声明
- **可维护性**: 生成器命令可重跑（README 注释记录）；无 TODO/临时占位残留
- **NFR 验证口径**: 性能无门禁——TEST 阶段在 TEST.md 记录实测耗时供后续回归参考（2026-09-04 triage：用户无硬性性能要求，不做超时 fail）；工具版本校验由 build.py 自检 + TEST 依赖清单承担；安全自动断言 = 检索范围内无 `sk-sp-` 前缀与绝对 `/home/hellrabbit` 路径（grep 命中数 0）；可访问性/兼容性为人工检查清单（deck 字号常量 diff、三平台表述一致性，见 REVIEW 检查项），明示不纳入自动 gate

## 依赖与假设

- 本机工具：python-pptx 1.0.2（已验证）、LibreOffice 24.2.7.2 headless（已验证）、graphviz 2.43（已验证）、bats via make test
- 用户指南 deck 生成器源：`.specs/user-guide-deck-gen/`（本 change 新建并入库；slides.json 20 页 + build.py + deck_checks.py）。`.specs/archive/2026-07-31-user-guide-ppt-sync/gen/` 为技术设计 deck（25 页）生成器，仅布局参考
- L3 外部审查：dsh-tui 进程已配置 `FLOW_KIT_L3_BASE_URL/AUTH_TOKEN/DEFAULT_MODEL/TIMEOUT/MAX_TOKENS/THINKING`；本会话执行时以 env 前缀注入，不外泄到文档
- 分支 `develop` 提交；归档日期以 2026-09-03 为准
