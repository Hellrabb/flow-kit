# TASK: 用户指南与用户指南 PPT 同步至 2026-09 功能集

- **Change ID**: user-guide-sync-2026-09
- **关联**: `@.specs/user-guide-sync-2026-09/REQUIREMENT.md`、`@.specs/user-guide-sync-2026-09/DESIGN.md`

---

## 波次划分

```
Wave 1 (parallel): T01[P] MD 批次1（版本头/§1/§2）, T06[P] deck 生成器基建收尾+入库+基线渲染
Wave 2:            T02      MD 批次2（§4 命令表/§5 阶段7）
Wave 3:            T03      MD 批次3（§7 Stop Hook 大节 + §12 索引）
Wave 4 (parallel): T04[P]   MD 全量禁词/事实终检, T07[P] deck slides.json 20 页内容 + 首build
Wave 5 (parallel): T05[P]   bundle 同步 + cmp + make test 回归, T08[P] deck 终版校准 + 文本断言（deck_checks.py）
Wave 6:            T09      渲染验证（PDF 页数/PNG 抽查）
```

> 说明：MD 全部任务串行（同文件冲突）；T06 与 MD 任务并行；T07 依赖 T03（slides 文案须读 §4/§7 修订后文本，同口径引用，避免两处漂移），故排在 Wave 4 与 T04 并行（与 T04 写入对象不同文件；T07 只依赖 T03 后的文本，T04 的清理由 T08 终校兜底）；T08 在 T07 后校准并产出 deck_checks.py。
> AC-8 承接：规划链（1/2/3）的 L2/L3 门禁审查在 3-task 门禁处执行（INDEPENDENT-REVIEW-{1,2,3}.md，本 TASK 属规划链产物）；实施链 5/6/7 的审查在对应产物完成后执行（见 DESIGN D6）。

---

## 任务清单

<task id="T01" parallel="true" status="pending" model-tier="standard">
  <name>MD 批次1：版本头 + §1 平台化组件表 + §2 dsh 插件安装小节</name>
  <read_files>
    FLOW-KIT-用户指南.md（§1 前 60 行 + §2 至 3.1 前）
    flow-kit-bundle/hooks/config/stop-hook.json
    ~/.dsh/profiles/web/node_modules/dsh-flow-kit/package.json
  </read_files>
  <write_files>
    FLOW-KIT-用户指南.md
  </write_files>
  <action>
    1) 文件头：`> 版本: 2026-09-03`（替换 20260713），来源行保持 github.com/hellrabbit/flow-kit/tree/develop。
    2) §1「什么是 flow-kit」开头与核心组件表（现写「为 Claude Code 提供…」）：改为多平台表述——「为 Claude Code / DeepSeek Harness(dsh) / OpenCode 等 IDE 提供」；表格新增/改写一行 dsh 插件条目：dsh-flow-kit（dsh 插件 · 内容层 = flow-kit-bundle 拷贝 + cordis.patch.yml 挂载，提供同样 17 个 flow-* 技能）。Stop Hook 行按 D3 口径改为「12 逻辑模块（00-gate 入口 / 99-report 收尾为基础设施包装）＋ PreToolUse/SessionStart/pre-commit 门禁」。
    3) §2 安装：在「2.1 从 bundle 安装」前新增「2.0（或 2.1 前）dsh 插件安装」小节：仓库打包 `bash package-dsh-plugin.sh` → dist/dsh-flow-kit；`dsh plugin --profile &lt;profile&gt; add file:&lt;仓库路径&gt;/dist/dsh-flow-kit`（pnpm 转发，自动把声明 dsh.bundle 的包注册进 `dsh.profile.bundles`）；重启 `dsh --profile &lt;profile&gt;` 后 flow-* 技能与 /flow 命令挂载；更新方式 = 重跑打包 + `dsh plugin --profile &lt;profile&gt; update dsh-flow-kit`（必要时 install --force）+ 重启。不写绝对用户路径、不写版本号（版本跟随 dist 内 package.json）。
  </action>
  <verify>grep -q '^> 版本: 2026-09-03' FLOW-KIT-用户指南.md &amp;&amp; grep -q 'github.com/hellrabbit/flow-kit/tree/develop' FLOW-KIT-用户指南.md &amp;&amp; grep -q 'dsh plugin --profile' FLOW-KIT-用户指南.md &amp;&amp; grep -q 'dsh-flow-kit' FLOW-KIT-用户指南.md &amp;&amp; grep -c '20260713' FLOW-KIT-用户指南.md | grep -q '^0$'</verify>
  <done>对应 AC-1、AC-2（部分）、AC-3 a/b；版本行、平台化表述、dsh 安装小节就位</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="false" status="pending" model-tier="standard">
  <name>MD 批次2：§4 命令表（/flow model 五级链、doctor 报告、gate-config）+ §5 阶段 7 门禁</name>
  <read_files>
    FLOW-KIT-用户指南.md（§4 命令表与 4.1 goal 段、§5 阶段 7 段）
    flow-kit-bundle/hooks/stop/lib/common.sh（fk_resolve_model 注释，行 ~238-270）
    dsh-flow-kit/lib/flow-state.js（model/doctor 命令语义）
  </read_files>
  <write_files>
    FLOW-KIT-用户指南.md
  </write_files>
  <action>
    1) §4 命令表 `/flow model` 行改写为：`/flow model [l2=&lt;m&gt;] [l3=&lt;m&gt;] [l2-default=&lt;m&gt;] [l3-default=&lt;m&gt;] [--clear &lt;l2|l3|l2-default|l3-default&gt;]`——前两项写显式字段，后两项写站点级默认字段（五级链 tier-4/5），只触碰 4 个模型键，不影响 condition/gates/gate_config。
    2) `/flow doctor` 行（及若有的小节）补 correction 卫生报告语义：读 `.flow-active.correction`，输出 type + violations 去重摘要（check→rule 回退）、model-missing message、解析失败 fail-open（对应 ADR-024）。
    3) §4.1 `--gate-config` 示例/说明更新：值域 both(=L2+L3, 原 independent 别名)/L2/L3/off；支持预设名与数字列表；示例 JSON 用 `{"1-requirement":"both",...}` 替换残留 `"independent"`（若上下文讲旧值需注明兼容）。
    4) §5 阶段 7 流程文字补：提交前 pre-commit 门禁（make test 等）与归档提交完整性门禁（34-archive-commit-check · 归档产物与 CHANGE 范围核对）。
  </action>
  <verify>grep -q 'l2-default=' FLOW-KIT-用户指南.md &amp;&amp; grep -q 'l3-default=' FLOW-KIT-用户指南.md &amp;&amp; grep -q -- '--clear' FLOW-KIT-用户指南.md &amp;&amp; grep -q 'correction' FLOW-KIT-用户指南.md &amp;&amp; grep -q '34-archive-commit-check\|archive-commit' FLOW-KIT-用户指南.md &amp;&amp; grep -qE 'both|L2-only|L3-only|independent' FLOW-KIT-用户指南.md</verify>
  <done>对应 AC-3 c/d/f（命令语义）与 AC-3 e（门禁）；§4/§5 口径更新</done>
  <depends_on>T01</depends_on>
</task>

<task id="T03" parallel="false" status="pending" model-tier="standard">
  <name>MD 批次3：§7 Stop Hook 章节重写（模块清单/33-34/correction 卫生/五级模型链小节）+ §12 结构索引微调</name>
  <read_files>
    FLOW-KIT-用户指南.md（§7 全节 ~L840-960、§12 文件结构索引）
    flow-kit-bundle/hooks/config/stop-hook.json
    flow-kit-bundle/hooks/stop/lib/common.sh（fk_resolve_model 注释 + correction 类型）
  </read_files>
  <write_files>
    FLOW-KIT-用户指南.md
  </write_files>
  <action>
    1) §7 引言模块计数改写（D3 口径）：脚本链 00-gate/01-transcript + 20~34 号逻辑模块 + 99-report；config 层 12 个开关模块；门禁 = PreToolUse（independent-review gate + auto-checkpoint）+ SessionStart（恢复/报告提醒）+ pre-commit。
    2) 模块表按现行清单修正/补行：33-flow-active-integrity（.flow-active 完整性 + correction 卫生，ADR-024）、34-archive-commit-check（阶段 7 归档提交门禁）；删除已不存在的 31/32 职责描述若有冲突（以 2026-09 实物为准：31-auto-advance/32-fallback-guard 保留，其余编号如实）。
    3) correction 卫生小节（现有 ~L870-880 段落）扩展：类型 l2/l3-model-missing 与 compliance/state-integrity；SessionStart 收割语义；doctor 查看方式。
    4) L2/L3 模型配置小节（现有 ~L900-935 表格）重写为**五级解析链**：L3 = ANTHROPIC_DEFAULT_HAIKU_MODEL &gt; FLOW_KIT_L3_MODEL &gt; .goal.l3_model &gt; FLOW_KIT_L3_DEFAULT_MODEL &gt; .goal.l3_default_model（L2 对称：ANTHROPIC_L2_MODEL 起）；逐级非空即停；显式永远压过默认；凭证由 fk_resolve_api_credentials 独立判定（默认模型不改变无凭证跳过语义）；字段边界：只触碰 4 模型键。
    5) §12 文件结构索引：补 .flow-kit/ 运行时说明与「dsh 插件内同构路径（node_modules/dsh-flow-kit/flow-kit 等）」一句；.claude/hooks 树若列出旧模块名同步修正。
  </action>
  <verify>grep -q '33-flow-active-integrity\|33 号' FLOW-KIT-用户指南.md &amp;&amp; grep -q '34-archive-commit-check\|34 号' FLOW-KIT-用户指南.md &amp;&amp; grep -q 'FLOW_KIT_L3_DEFAULT_MODEL' FLOW-KIT-用户指南.md &amp;&amp; grep -q 'l3_default_model' FLOW-KIT-用户指南.md &amp;&amp; grep -c '三级优先级链\|三级链' FLOW-KIT-用户指南.md | grep -q '^0$' &amp;&amp; python3 -c "import json,sys; cfg=json.load(open('flow-kit-bundle/hooks/config/stop-hook.json'))['modules']; t=open('FLOW-KIT-用户指南.md',encoding='utf-8').read(); missing=[k for k in cfg if k not in t]; print('MISSING-KEYS',missing) if missing else None; sys.exit(1 if missing else 0)"</verify>
  <done>对应 AC-2（三级链清零）、AC-3 e/f（模块表与五级链小节）</done>
  <depends_on>T02</depends_on>
</task>

<task id="T04" parallel="true" status="pending" model-tier="standard">
  <name>MD 全量终检：禁词清零 + 链接/编号一致性自查</name>
  <read_files>
    FLOW-KIT-用户指南.md（全文件，分卷读取）
    flow-kit-bundle/hooks/config/stop-hook.json（模块编号表核对 · action c）
  </read_files>
  <write_files>
    FLOW-KIT-用户指南.md
  </write_files>
  <action>
    对全文扫查并修正：a) 禁词清单（20260713 / 17 个模块 / 三级优先级链 / 三级链 / 仅 Claude Code / 仅为 Claude Code / 只为 Claude Code）应 0 命中（保留「归档」等语境说明时不误伤：用精确串核查）；b) 文中章节互链锚点（#sec-*）与目录一致；c) 模块编号表与文件实物一一对应（读 stop-hook.json 再核对一遍表格行数）；d) 删除任何「待补/TODO」占位；e) 确认没有把「三级」误用于模型链以外的正确语境（如三层架构等不属禁词）。
  </action>
  <verify>for s in '20260713' '17 个模块' '三级优先级链' '三级链' '仅 Claude Code' '仅为 Claude Code' '只为 Claude Code'; do grep -c "$s" FLOW-KIT-用户指南.md | grep -q '^0$' || exit 1; done; grep -c 'TODO\|待补' FLOW-KIT-用户指南.md | grep -q '^0$' || exit 1; echo BANNED-CLEAN</verify>
  <done>对应 AC-2 全量清零与 AC-3 残留检查</done>
  <depends_on>T03</depends_on>
</task>

<task id="T05" parallel="true" status="pending" model-tier="standard">
  <name>bundle 副本同步 + 全量回归（make test）</name>
  <read_files>
    FLOW-KIT-用户指南.md
    flow-kit-bundle/FLOW-KIT-用户指南.md
  </read_files>
  <write_files>
    flow-kit-bundle/FLOW-KIT-用户指南.md
  </write_files>
  <action>
    根指南 cp 覆盖 flow-kit-bundle/FLOW-KIT-用户指南.md（打包脚本 §3 输入源），随后全量回归 make test（bats 770）确认文档改动不破坏任何测试。
  </action>
  <verify>cmp -s FLOW-KIT-用户指南.md flow-kit-bundle/FLOW-KIT-用户指南.md &amp;&amp; make test > /tmp/flowkit-make-test.log 2>&amp;1; rc=$?; tail -1 /tmp/flowkit-make-test.log; [ $rc -eq 0 ]</verify>
  <done>对应 AC-4 与 AC-7（回归部分）</done>
  <depends_on>T04</depends_on>
</task>

<task id="T06" parallel="true" status="pending" model-tier="standard">
  <name>deck 生成器基建：.specs/user-guide-deck-gen/（theme/layouts/build + 现 deck 基线渲染）</name>
  <read_files>
    .specs/archive/2026-07-31-user-guide-ppt-sync/gen/theme.py
    .specs/archive/2026-07-31-user-guide-ppt-sync/gen/masters.py
    .specs/archive/2026-07-31-user-guide-ppt-sync/gen/utils/*.py
    tools/pptx-light-sync.py
    .specs/user-guide-deck-gen/theme.py, layouts.py, build.py, README.md（核验对象）
    flow-kit-用户指南.pptx（只读 · 文本/样式取样）
  </read_files>
  <write_files>
    .specs/user-guide-deck-gen/theme.py
    .specs/user-guide-deck-gen/layouts.py
    .specs/user-guide-deck-gen/build.py
    .specs/user-guide-deck-gen/README.md
    /tmp/guide-deck-baseline/*.png（基线渲染，不入库）
  </write_files>
  <action>
    0) 现状：theme.py/layouts.py/build.py/README.md 骨架已在 DESIGN 收口前建好并通过冒烟（2026-09-03 会话 · smoke 输出 3 页 /tmp/guide-smoke.pptx）。本任务为**收尾核验 + 入库**：逐文件核验（build.py 含 python-pptx>=1.0.2/soffice 版本自检；layouts 实现 cover/band/table 布局且中文 run 走 utils.shapes.set_font 的 a:ea 设置；README 记录重跑命令与依赖版本），补齐遗漏后 git add 入库为新增 tracked 文件（杜绝「已存在但未跟踪」状态，见 L2 F3/R7）。
    1) 渲染现 19 页 deck 为基线 PNG（soffice → pdf → pdftoppm，放 /tmp/guide-deck-baseline/）供 T07 作者对齐版式（顶部色带/标题字号/正文布局）——已完成，留档可复跑。
    2) 重跑一次冒烟确认骨架可复现（2-3 个占位 slide，输出 /tmp/guide-smoke.pptx），不提交占位成品。
  </action>
  <verify>python3 -c "import sys; sys.path.insert(0,'.specs/user-guide-deck-gen'); import theme, layouts, build" &amp;&amp; test -s .specs/user-guide-deck-gen/README.md &amp;&amp; ls /tmp/guide-deck-baseline/*.png | wc -l | grep -qv '^0$' &amp;&amp; git ls-files --error-unmatch .specs/user-guide-deck-gen/theme.py .specs/user-guide-deck-gen/layouts.py .specs/user-guide-deck-gen/build.py .specs/user-guide-deck-gen/README.md</verify>
  <done>对应 AC-5 的可复现生成器前提（D4/D5 基建部分）</done>
  <depends_on></depends_on>
</task>

<task id="T07" parallel="true" status="pending" model-tier="top">
  <name>deck slides.json 内容：20 页全量（含五级链/dsh 插件/新模块口径）并首 build</name>
  <read_files>
    .specs/user-guide-deck-gen/theme.py, layouts.py, build.py
    flow-kit-用户指南.pptx（现 19 页文本逐页 dump，作为内容基线）
    /tmp/guide-deck-baseline/*.png（版式参考）
    FLOW-KIT-用户指南.md（§1/2/4/7 修订后文本，同口径引用）
  </read_files>
  <write_files>
    .specs/user-guide-deck-gen/slides.json
    flow-kit-用户指南.pptx（build 输出）
  </write_files>
  <action>
    编写 20 页 slides.json。页规划（与现 deck 对应关系）：
    1 cover（日期 2026-09-03 · github.com/hellrabbit/flow-kit）；2 什么是 flow-kit（平台化：CC/dsh/OC + dsh-flow-kit 插件条目 + 组件表）；3 核心概念（change-id/.flow-active/.specs）；4 整体架构（flow-* 委托斜杠命令平台中立 + hook 运行时口径 12 模块 + 门禁）；5 两大命令 /flow-go vs /flow（子命令含 model/gate-config/doctor correction）；6 8 阶段总览；7 阶段 0-1；8 阶段 2-2a；9 阶段 3-4；10 阶段 5-6；11 阶段 7（含 pre-commit + archive-commit 门禁行）；12 Pipeline Goal 时序；13 PCSC+PCG；14 L2/L3 模型配置五级链（替换旧三级链页：5 级字段 L2/L3 两列 + 「显式压过默认」「凭证独立判定」+ /flow model 命令含 l2-default/l3-default/--clear）；15 横向命令；16 Stop Hook 系统（12 逻辑模块 + 00/99 + PreToolUse/SessionStart/pre-commit · 33/34 号职责行）；17 brooks-lint；18 典型工作流 10 步；19 文件结构+Token 预算（补 .flow-kit/ 行）；20 新增页「dsh 插件化：安装与挂载」（打包→dsh plugin add→bundles 注册→重启→17 技能；更新=重打包+update+重启）。
    文本不得含禁词（20260713/17 个模块/三级优先级链/三级链/仅/仅为/只为 Claude Code）。日期统一 2026-09-03。build.py 输出根目录 pptx；本 task 只做「页数=20」快速自检（python-pptx 打开断言）；全文本断言（禁词 0/无空页/关键串/URL）由 T08 deck_checks.py 固化执行，不在二进制上 grep。
  </action>
  <verify>python3 .specs/user-guide-deck-gen/build.py &amp;&amp; python3 -c "from pptx import Presentation; p=Presentation('flow-kit-用户指南.pptx'); assert len(p.slides)==20, len(p.slides); print('slides=20 ok')"</verify>
  <done>对应 AC-5 页数=20 与内容初稿（全量断言由 T08 承接）</done>
  <depends_on>T06, T03</depends_on>
</task>

<task id="T08" parallel="true" status="pending" model-tier="standard">
  <name>deck 终版校准：与 MD 终稿同口径 + 文本断言脚本固化</name>
  <read_files>
    FLOW-KIT-用户指南.md（终稿 · §4/7 相关段）
    .specs/user-guide-deck-gen/slides.json
  </read_files>
  <write_files>
    .specs/user-guide-deck-gen/slides.json
    flow-kit-用户指南.pptx（build 输出）
    .specs/user-guide-deck-gen/deck_checks.py（断言脚本 · 入库）
  </write_files>
  <action>
    1) 逐页核对 slides.json 与 MD 终稿口径（模块数、五级链字段、命令示例、日期）；不一致处改 slides.json 重 build。
    2) 编写入库断言脚本 deck_checks.py：打开 pptx → 断言 20 页、首页含 2026-09-03 与 github.com/hellrabbit/flow-kit、**逐 slide 文本非空（无空页）**、禁词 0（含 仅/仅为/只为 Claude Code）、关键串 ≥1（l2-default=/l3-default=、dsh plugin、34 号/archive-commit 等价、五级）；exit 0 才通过。
  </action>
  <verify>python3 .specs/user-guide-deck-gen/deck_checks.py &amp;&amp; python3 -c "src=open('.specs/user-guide-deck-gen/deck_checks.py',encoding='utf-8').read(); need=('len(p.slides)==20','2026-09-03','l2-default=','dsh plugin','逐页文本非空'); missing=[k for k in need if k not in src]; assert not missing, missing; print('deck_checks-impl-ok')"</verify>
  <done>对应 AC-5 全部断言与 AC-6 前提（可打开）</done>
  <depends_on>T07, T03, T04</depends_on>
</task>

<task id="T09" parallel="true" status="pending" model-tier="standard">
  <name>渲染验证：soffice 转 PDF + 页数 + 3 页 PNG 抽查</name>
  <read_files>
    flow-kit-用户指南.pptx
  </read_files>
  <write_files>
    /tmp/ppt-render/*（不入库）
  </write_files>
  <action>
    soffice --headless --convert-to pdf（输出 /tmp/ppt-render/），页数必须 = 20；pdftoppm 抽首页/五级链页/Stop Hook 页转 PNG，人工/L2 审查可见；无崩溃与空白页。
  </action>
  <verify>soffice --headless --convert-to pdf --outdir /tmp/ppt-render flow-kit-用户指南.pptx &amp;&amp; pdfinfo /tmp/ppt-render/flow-kit-用户指南.pdf | awk '/^Pages:/ {if ($2!=20) {print "PDF_PAGES=" $2; exit 1}}' &amp;&amp; for n in 1 14 20; do pdftoppm -png -r 60 -f $n -l $n /tmp/ppt-render/flow-kit-用户指南.pdf /tmp/ppt-render/pg$n; test -s /tmp/ppt-render/pg$n-0$n.png -o -s /tmp/ppt-render/pg$n-01.png || exit 1; done</verify>
  <done>对应 AC-6（转换 exit 0 + PDF 页数 = 20 + 页 1/14/20 PNG 非空）</done>
  <depends_on>T08</depends_on>
</task>

<!-- 属性说明：
     parallel="true" — 可与其他并行 task 同 wave 执行
     status="pending|in_progress|done|blocked"
     model-tier="cheap|standard|top" — 调度 tier，缺省 standard（ADR-016）-->

---

## 状态字段说明

- status 更新随 4-dev 执行推进；同文件任务的串行约束由 depends_on 链保证。
- T01/T02/T03/T04 均只写 FLOW-KIT-用户指南.md（同文件 → 严格串行）；T07/T08 写 slides.json 与成品 pptx（串行）；T05/T06/T09 无冲突。

---

## 阻塞日志

| 任务 | 阻塞原因 | 待人工决策项 | 时间 |
|---|---|---|---|
|  |  |  |  |

---

## Fix 任务（来自 REVIEW / INTEGRATION）

> 此区域由 review/integration 阶段自动追加，编号 `T-FIX-XX`。

```xml
<!-- 占位 -->
```
