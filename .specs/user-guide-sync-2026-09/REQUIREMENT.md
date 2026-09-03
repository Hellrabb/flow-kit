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

- **Given** 根目录指南文件
- **When** 打开文件头 5 行
- **Then** 版本行写作 `2026-09-03`，来源行仍指向 `https://github.com/hellrabbit/flow-kit/tree/develop`
- **验证方式**: `grep -n '^> 版本: 2026-09-03' FLOW-KIT-用户指南.md` 且 `grep -n 'github.com/hellrabbit/flow-kit/tree/develop' FLOW-KIT-用户指南.md`

### AC-2 · 过时硬事实清零（MD）

- **Given** 更新后的指南（根目录与 flow-kit-bundle 副本）
- **When** 检索过时表述
- **Then** 以下字符串在指南正文（归档目录除外）中不再出现：`20260713`、`17 个模块`、`三级优先级链`、`三级链`、`仅 Claude Code`（如原存在）；「Claude Code」作为平台名之一可保留但不得宣称独占
- **验证方式**: 对上述串 `grep -c` 结果 = 0（含 bundle 副本）

### AC-3 · 新事实就位（MD 内容完备性）

- **Given** 更新后的指南
- **When** 按 2026-09 功能集逐项检索
- **Then** 全部命中：
  a) §1 核心组件/平台说明不再写「为 Claude Code 提供…」独占表述；dsh 平台（dsh-flow-kit 插件）作为一等安装途径出现；
  b) §2 安装新增「dsh 插件安装」小节，含 `dsh-flow-kit` 包名与 `dsh plugin` 安装命令形态；
  c) §4 /flow 命令表 `/flow model` 行描述五级解析链语义与 `l2-default=` / `l3-default=` / `--clear`；
  d) §4 `/flow doctor` 行（或对应小节）描述 correction 卫生报告（读取 `.flow-active.correction`：type / violations 去重摘要 / check→rule 回退）；
  e) §7 Stop Hook 章节模块清单与现行 `hooks/config/stop-hook.json` 一致，至少含 33（状态完整性）与 34（archive-commit 门禁）号模块与 pre-commit 门禁说明；
  f) §7 L2/L3 模型配置节含 `FLOW_KIT_L3_DEFAULT_MODEL` / `l2-default=` 等五级链字段与「显式配置永远压过默认级」语义（与 .specs/CONTEXT.md 已锁决策 2026-09-03 一致）。
- **验证方式**: 每项一条 `grep -q`（见 TEST.md 固化命令清单；文件内不得出现`TODO`/「待补」占位）

### AC-4 · 根目录与 bundle 副本一致

- **Given** 根目录 `FLOW-KIT-用户指南.md` 与 `flow-kit-bundle/FLOW-KIT-用户指南.md`
- **When** 逐字节比较
- **Then** 两文件一致
- **验证方式**: `cmp -s FLOW-KIT-用户指南.md flow-kit-bundle/FLOW-KIT-用户指南.md && echo OK`

### AC-5 · PPTX 重生成与内容更新（用户指南 deck）

- **Given** 现有 19 页 `flow-kit-用户指南.pptx` 与 `.specs/archive/2026-07-31-user-guide-ppt-sync/gen/` 生成器
- **When** 运行生成器（更新后的 slides.json / 图表源）
- **Then** `flow-kit-用户指南.pptx` 重建成功：首页含日期 `2026-09-03`；decks 全文不再含 AC-2 过时串；含「dsh 插件」或等价页面/文案；模型配置 slide 描述五级链（含 `l2-default=` 等）；slide 数 = 生成器产出页数（≥19，由 DESIGN 定稿），无空 slide
- **验证方式**: python-pptx 提取文本断言 + 页数断言（命令固化于 TEST.md）；生成器源（slides.json 等）随 change 入库保证可重跑

### AC-6 · 渲染与可打开性验证

- **Given** 重建后的 pptx
- **When** LibreOffice headless 转 PDF
- **Then** 转换成功（exit 0）、PDF 页数 = pptx slide 数、无异常页（抽查 3 页渲染为 PNG 人工/审查可见）
- **验证方式**: `soffice --headless --convert-to pdf --outdir /tmp/ppt-check flow-kit-用户指南.pptx` + 页数断言 + pdftoppm/工具抽查

### AC-7 · 回归与改动边界

- **Given** 本 change 只应触碰文档/演示/change 产物
- **When** 运行仓库质量门禁并核对 git 改动集
- **Then** `make test`（bats 全量）0 fail；`git status --porcelain` 只含白名单路径（指南两副本、pptx、生成器源、`.specs/user-guide-sync-2026-09/` 与归档目标、CHANGELOG/STATE/LESSONS/CONTEXT 允许文件）
- **验证方式**: `make test 2>&1 | tail -1` + `git status --porcelain | wc -l` 与白名单对照

### AC-8 · 独立审查（L2+L3）闭环

- **Given** gate_config=all（阶段 1/2/3/5/6/7 均 both）
- **When** 每阶段产物就绪后执行独立审查
- **Then** 每阶段有 `INDEPENDENT-REVIEW-N.md`：含 `## L2 盲审` 段且 `**Verdict**: pass`；含 `## L3 重审`（外部模型 deepseek-v4-flash-0731，env 注入执行）且 verdict pass；若外部 API 不可用按 CHANGE.md 风险段**显式降挡记录**（写明原因），不允许静默跳过
- **验证方式**: 逐文件 `grep -q`（清单固化于 TEST.md）

### AC-9 · 归档与提交

- **Given** 全部产物与审查闭环
- **When** 阶段 7 集成
- **Then** 活动目录移至 `.specs/archive/2026-09-03-user-guide-sync-2026-09/`（六件套齐全：REQUIREMENT/DESIGN/TASK/TEST/REVIEW/INTEGRATION + CHANGE + 审查文件）；`.specs/STATE.md` 的 `last_change_archived` 更新；`.specs/CHANGELOG.md` 顶部新增本 change 行；提交信息为 Conventional Commits（如 `docs(user-guide-sync-2026-09): …`）
- **验证方式**: 文件存在性 + `git log -1 --format=%s` 断言 + STATE/CHANGELOG grep

---

## 范围切分

### v1（本次必做）

- CHANGE/REQUIREMENT/DESIGN/TASK/TEST/REVIEW/INTEGRATION + INDEPENDENT-REVIEW-N 全套产物与归档
- `FLOW-KIT-用户指南.md` 增量修订至 2026-09 功能集（AC-1/2/3）
- `flow-kit-bundle/FLOW-KIT-用户指南.md` 逐字节同步（AC-4）
- `.specs/CONTEXT.md` 术语表补 dsh 插件相关术语
- `flow-kit-用户指南.pptx` 生成器源更新 + 重生成 + 渲染验证（AC-5/6）
- 仓库回归门禁 + 改动白名单（AC-7）
- L2/L3 独立审查闭环（AC-8）
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

- **性能**: 指南保持单文件可整读规模（更新后 ≤ 90KB）；PPT 重建 + PDF 渲染单次 ≤ 120s（本机实测量级）
- **可访问性**: 无（文档/演示产物；PPT 字号沿用现有主题，不低于当前水平）
- **安全**: 指南与 PPT 不得出现真实凭证/API key/内部绝对用户路径；不新增指向私有地址的链接
- **兼容性**: Claude Code / dsh / OpenCode 三平台的描述不得互相矛盾；指南/bundle/PPT 三份内容事实一致；归档产物不动
- **可观测性**: 每项修订在 CHANGE/CHANGELOG 留痕；PPT 生成器源入库，日期等易变项尽量集中声明
- **可维护性**: 生成器命令可重跑（README 注释记录）；无 TODO/临时占位残留

## 依赖与假设

- 本机工具：python-pptx 1.0.2（已验证）、LibreOffice 24.2.7.2 headless（已验证）、graphviz 2.43（已验证）、bats via make test
- PPT 生成器源：`.specs/archive/2026-07-31-user-guide-ppt-sync/gen/`（slides.json 等当前可重跑；更新后的源继续入库）
- L3 外部审查：dsh-tui 进程已配置 `FLOW_KIT_L3_BASE_URL/AUTH_TOKEN/DEFAULT_MODEL/TIMEOUT/MAX_TOKENS/THINKING`；本会话执行时以 env 前缀注入，不外泄到文档
- 分支 `develop` 提交；归档日期以 2026-09-03 为准
