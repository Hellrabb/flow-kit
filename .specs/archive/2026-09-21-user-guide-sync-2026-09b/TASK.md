# TASK: 用户指南与用户指南 PPT 同步至 2026-09-21 现状（第二轮）

- **Change ID**: user-guide-sync-2026-09b
- **关联**: `@.specs/user-guide-sync-2026-09b/REQUIREMENT.md`、`@.specs/user-guide-sync-2026-09b/DESIGN.md`

---

## 波次划分

```
Wave 1 (parallel): T01[P] 指南修订（上：§1–§5）      T03[P] README 口径核对与连改
Wave 2:            T02    指南修订（下：§6–§12+附录）      (depends on T01)
Wave 3 (parallel): T04[P] 四副本对齐                 T05[P] deck 扩页重建   (depends on T02)
Wave 4:            T06    副本一致性守护 bats 用例   (depends on T04)
Wave 5:            T07    全量验证 + 断言矩阵 + 渲染抽检   (depends on T04, T05, T06)
Wave 6:            T08    阶段 7 归档与收口（AC-11）        (depends on T07)
```

> 同 wave = 可并行；跨 wave = 必须顺序执行。
> **为什么 T01/T02 不能并行**：两者写同一个文件 `flow-kit-bundle/FLOW-KIT-用户指南.md`（写冲突），按「按文件冲突切」原则串行。

---

## 任务清单

```xml
<task id="T01" parallel="true" status="done" model-tier="standard">
  <name>指南修订（上）：§1 组件表 / §2 安装 / §3 核心概念 / §4 命令 / §5 生命周期</name>
  <read_files>
    flow-kit-bundle/FLOW-KIT-用户指南.md      <!-- 底稿（D1）· 唯一写入对象 -->
    flow-kit-bundle/install.sh
    flow-kit-bundle/lib/install_hooks.sh
    flow-kit-bundle/hooks/config/README.md
    flow-kit-bundle/skills/flow/SKILL.md
    flow-kit-bundle/flow-kit/templates/TASK.md
    flow-kit-bundle/flow-kit/prompts/6-review.md
    flow-kit-bundle/flow-kit/prompts/7-integration.md
    flow-kit-bundle/flow-kit/prompts/A-architect.md
    Makefile
    /tmp/guide-drift-report.md                <!-- 事实基线（一次性输入） -->
  </read_files>
  <write_files>
    flow-kit-bundle/FLOW-KIT-用户指南.md
  </write_files>
  <action>
    按漂移报告逐条定点修订底稿的 §1–§5 与 §10.7/§11 的对应条目：
    - §1 组件表：Stop Hook 配置载体口径（用户级）；17 技能计数保持
    - §2 安装：D01（--global 不含 hooks）/ D02（选项表补 --platform、--no-brooks-tools、--self-test、--brooks-src、--yes；--project 配置仍走用户级）/ D03（--hooks-only 含 .specs 模板）/ D04（更新入口改 make dsh-sync）/ D05（插件版本 v0.2.0 + npm 安装备选）/ N5
    - §3：D06（.flow-active 示例补 goal 字段）
    - §4：D07（/flow 子命令表补 gate-config、l2-review）/ D08（删 --sub-goal-N flag 假示例，改 env SUB_GOAL_N 与自动提取）/ D33（§10.7 阶段名 key 值域 both/L2/L3/off）/ D34（方式 C 改为用户级三平台路径，采用 bundle 副本既有措辞）
    - §5：D09（.specs/LESSONS.md）/ D10（阶段 7 产出无 ARCHIVE.md）/ D11（阶段 6 单轮合并审查，三处）/ D12（TASK XML 模板字段）/ D13（波次与 depends_on 语义）/ D14（严重度 Important vs Major）/ D15（34 号职责）
    - §11：按 RULES.md 核对（预期 0 改动，若发现漂移一并修正）
    改动须与漂移报告的「建议改法」一致；不确定的事实回到源码 grep 确认，禁止凭印象改写。
  </action>
  <verify>
    bash -c 'cd ~/unisoc/flow-kit && f=flow-kit-bundle/FLOW-KIT-用户指南.md && grep -q "^> 版本: 2026-09-21" "$f" && test "$(grep -c "\.specs/lessons/" "$f")" = 0 && grep -q "\.specs/LESSONS\.md" "$f" && grep -q "make dsh-sync" "$f" && ! grep -q "sub-goal-4" "$f" && grep -q "SUB_GOAL_4" "$f" && ! grep -q "三轮审查" "$f" && echo T01-verify-OK'
  </verify>
  <done>
    §1–§5 + §10.7 + §11 的 D01–D03、D05–D15、D33、D34 全部落地，逐条反例 grep 0 命中、正例 grep ≥1 命中（见附录 A）；AC-2/AC-3 的对应条目闭合。
    **口径（v4.5 · 阶段 3 L3）**：本任务的 `<verify>` 是**冒烟子集**；**完整锚点矩阵**由 T07 的 `bash .specs/user-guide-sync-2026-09b/verify-ac.sh`（129 条断言 × 四份副本）承担——两处不重复维护
  </done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="false" status="done" model-tier="standard">
  <name>指南修订（下）：§6 横向命令 / §7 Stop Hook / §9 ppt skill / §10 工作流 / §12 索引 / 附录</name>
  <read_files>
    flow-kit-bundle/FLOW-KIT-用户指南.md
    flow-kit-bundle/hooks/config/stop-hook.json
    flow-kit-bundle/hooks/config/README.md
    flow-kit-bundle/hooks/stop/lib/common.sh
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    flow-kit-bundle/hooks/stop/lib/l3-api.sh
    flow-kit-bundle/hooks/stop/lib/l3-done.sh
    flow-kit-bundle/hooks/stop/lib/done-validation.sh
    flow-kit-bundle/hooks/stop/29-independent-review.sh
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    flow-kit-bundle/lib/install_hooks.sh
    flow-kit-bundle/flow-kit/prompts/M-health.md
    flow-kit-bundle/flow-kit/prompts/L-restyle.md
    ~/.claude/skills/ppt-diagram-pipeline/SKILL.md   <!-- §9 归属核对（只读） -->
    .claude/l3.env.example
    README.md
    Makefile
    /tmp/guide-drift-report.md
  </read_files>
  <write_files>
    flow-kit-bundle/FLOW-KIT-用户指南.md
  </write_files>
  <action>
    按漂移报告逐条定点修订底稿的 §6–§12 与附录：
    - §6：D16（A-architect 产出 .specs/ARCHITECTURE.md + .specs/adr/）/ D17（L-restyle change-id 两种格式）/ D18（M-health 三档模式名）
    - §7：D19（删 pre_tool_use_gates 两条，改注占位块未消费）/ D20（independent_review.model 标废弃）/ D21（握手文件废弃 → .done 锚点）/ D22（熔断=自动 bypass 写 .done）/ D23（matcher Bash|Write|Edit + path-guard）/ D24（补 runtime-edit-guard 入口）/ D25（补 max_artifact_bytes=80000 字节 + ÷3）/ D26（SessionStart 补 archive-uncommitted）/ D27（补「L3 凭证（必配）」段：三 Path + 加载方式 + 死锁后果）/ D28（.done 6 键 KVP 契约）/ D29（真实性校验三威胁表按 Tier1/Tier2 改写）/ D30（L1616 三个假 config 键名改对）；新增 N1/N2/N8/N9/N10/N11 的承载小节
    - §9：D31（ppt-diagram-pipeline 不由 bundle 分发）/ D32（skill 文件 vs 生成 deck 工程结构）
    - §10：D33/D34 若 T01 未覆盖则在此收口；N3/N4/N6/N7 在合适位置承载（质量门禁六门 / hooks-sync / verify-claims / l2-review）
    - §12：D35（.flow-kit 只放状态）/ D36（项目级树删 stop-hook.json）/ D37（stop/lib 补 6 个新库）/ D38（pre-tool-use 补 runtime-edit-guard + 4 个 gate-* 库）/ D39（change 产物清单去 ARCHIVE.md、补 4 类）/ D40（全局树结构错位 + ~/.local/bin）
    - 附录：D41（预设名补到 17 个）/ D42（篡改检测范围限定）/ D43（分节「最后同步日期」统一）＋ AC-1 日期口径（三处均为 2026-09-21）
    禁止改动本任务范围外的章节；每条改动在 DEV-SUMMARY 里登记（finding → 行号 → 改动摘要）。
  </action>
  <verify>
    bash -c 'cd ~/unisoc/flow-kit && ! grep -q "ARCHIVE\.md" flow-kit-bundle/FLOW-KIT-用户指南.md && grep -q "max_artifact_bytes" flow-kit-bundle/FLOW-KIT-用户指南.md && grep -q "FLOW_KIT_L3_AUTH_TOKEN" flow-kit-bundle/FLOW-KIT-用户指南.md && grep -q "runtime-edit-guard" flow-kit-bundle/FLOW-KIT-用户指南.md && grep -q "2026-09-21" flow-kit-bundle/FLOW-KIT-用户指南.md && echo T02-verify-OK'
  </verify>
  <done>
    §6–§12 + 附录的 D16–D32、D35–D43 全部落地 + N1–N11 承载小节就位；三处日期统一 2026-09-21（AC-1）。
    **口径（v4.5 · 阶段 3 L3）**：本任务的 `<verify>` 是**冒烟子集**（5 个代表串）；完整矩阵见 T07 的 `verify-ac.sh`
  </done>
  <depends_on>T01</depends_on>
</task>

<task id="T03" parallel="true" status="done" model-tier="standard">
  <name>README / dsh README 口径核对与连改</name>
  <read_files>
    README.md
    dsh-flow-kit/README.md
    dist/dsh-flow-kit/README.md
    flow-kit-bundle/install.sh
    Makefile
    flow-kit-bundle/hooks/config/stop-hook.json
    .claude/l3.env.example
    .specs/CHANGELOG.md
  </read_files>
  <write_files>
    README.md
    dsh-flow-kit/README.md
  </write_files>
  <action>
    按 AC-8 逐条核对两份 README 的：安装入口与作用域（--global 是否含 hooks / --project 配置口径）、配置路径（用户级单一源）、工件上限单位（字节 · 80000）、L3 凭证与熔断、dsh 插件更新入口（make dsh-sync）、dsh 侧 README 与源的同步关系。
    **先跑基线再改（R7 修订）**：每条断言先执行一次并把输出记入 DEV-SUMMARY；命中数为 0（= 该项已就位）的条目记为「已就位，无需改」并登记基线输出，**不允许为满足断言而反向改坏正确文本**。
    断言口径（R7 修订）：
    - 根 `README.md`：允许用反向断言（`! grep -q "项目级.*stop-hook.json" README.md`）+ 正例 `80000`；
    - `dsh-flow-kit/README.md`：**只用锚定式正例**（如 `~/.dsh/stop-hook.json`、`2026-09-21` 统一口径），**禁止**施加裸 `项目级.*stop-hook.json` 反例——该文件 `:39` 存在合法的「不再写项目级 `<项目>/.flow-kit/stop-hook.json`」说明，裸反例会误伤。
    发现过时口径直接连改（用户 2026-09-21 授权），每条改动在 DEV-SUMMARY 记录「条目 / 旧措辞 / 新措辞 / 证据行号」。
    注意：`dist/dsh-flow-kit/README.md` 是 `dsh-flow-kit/README.md` 的拷贝产物，**不手工编辑**（改源后由打包再生；本轮 T04 走窄路径，如需刷新该 README 则并入 T04 的映射拷贝）。
  </action>
  <verify>
    bash -c 'cd ~/unisoc/flow-kit && grep -q "make dsh-sync" README.md && grep -q "80000" README.md && grep -q "2026-09-21" dsh-flow-kit/README.md && echo T03-verify-OK'
  </verify>
  <done>
    两份 README 的每条核对结论有记录（改/不改 + 证据）；AC-8 闭合
  </done>
  <depends_on></depends_on>
</task>

<task id="T04" parallel="true" status="done" model-tier="standard">
  <name>四副本对齐（根 / bundle / dist docs / dist vendor）</name>
  <read_files>
    flow-kit-bundle/FLOW-KIT-用户指南.md
    FLOW-KIT-用户指南.md
    package-dsh-plugin.sh
    dist/dsh-flow-kit/docs/FLOW-KIT-用户指南.md
    dist/dsh-flow-kit/vendor/flow-kit-bundle/FLOW-KIT-用户指南.md
  </read_files>
  <write_files>
    FLOW-KIT-用户指南.md
    dist/dsh-flow-kit/docs/FLOW-KIT-用户指南.md
    dist/dsh-flow-kit/vendor/flow-kit-bundle/FLOW-KIT-用户指南.md
    dist/dsh-flow-kit/README.md          <!-- T03 改了源 README 时的映射同步（R6） -->
  </write_files>
  <action>
    以 `flow-kit-bundle/FLOW-KIT-用户指南.md`（T02 后的定稿）为唯一源：
    1. **现场重测并记录基线**（不沿用设计期数字 —— R5 修订）：登记四份的 `md5sum`/`wc -l`/`mtime` 与 `git rev-parse HEAD`，再 `diff FLOW-KIT-用户指南.md flow-kit-bundle/FLOW-KIT-用户指南.md > /tmp/t04-diff.txt`，把 root-only / bundle-only 行数写入 DEV-SUMMARY，并**逐条归类**每个 hunk 为「根旧」或「bundle 独有」（判据见 DESIGN D1 冻结点定义；量级大是预期，未归类的 hunk 才是异常）
    2. `cp` 到根副本
    3. **窄路径再生 dist 两份**（R2 修订——**不**跑全量 `bash package-dsh-plugin.sh`，它会重写 `dist/dsh-flow-kit/{skills,flow-kit,hooks,brooks-lint,vendor}` 并另生成 `dist/dsh-flow-kit-0.2.0.tgz`，与 T04 的 `write_files` 白名单冲突且产物对 git 不可见）：
       ```bash
       cp flow-kit-bundle/FLOW-KIT-用户指南.md dist/dsh-flow-kit/docs/FLOW-KIT-用户指南.md
       cp flow-kit-bundle/FLOW-KIT-用户指南.md dist/dsh-flow-kit/vendor/flow-kit-bundle/FLOW-KIT-用户指南.md
       # T03 若改了 dsh-flow-kit/README.md，其 dist 副本同属映射范围，一并对齐：
       cmp -s dsh-flow-kit/README.md dist/dsh-flow-kit/README.md || cp dsh-flow-kit/README.md dist/dsh-flow-kit/README.md
       ```
       > **注意（v4.4 · 阶段 3 L2 R1）**：vendor 树含 `flow-kit-bundle/test/`，新增的守护用例**不在此步**镜像——该文件由 **T06**（Wave 4，晚于 T04）创建，镜像动作已整体移入 T06，避免「T04 镜像一个尚不存在的文件」。
       （目标路径取自 `package-dsh-plugin.sh:45` 的 `COPY_OPTIONAL` 映射，窄路径与门禁同源）
    4. `md5sum` 四份并留证据（唯一值 = 1）；**再**跑 `bash package-dsh-plugin.sh --check` 确认由红转绿（只读模式，无副作用）
    5. **`make dsh-sync`（R1 修订 · 必做）**：把 dist 推到已安装插件目录（`${DSH_PROFILE:-web}`），否则 `test/test_guide_copy_parity.bats` 的用例 6（installed copy when present）必红 → `make check` 第一门红。该步骤写的是**仓库外**插件目录，不进 `write_files`。**强制口径（v4.5 · 阶段 3 L3）**：本机已装插件时该步**必须执行**（不是可选）；仅当 `${DSH_PROFILE:-web}` 未安装插件时才允许跳过，且 T07 的 `make check` 会以 SKIP 形式体现。
    禁止手工编辑 dist 内的其他文件（其余打包件本轮不动）。
  </action>
  <verify>
    bash -c 'cd ~/unisoc/flow-kit && n=$(md5sum FLOW-KIT-用户指南.md flow-kit-bundle/FLOW-KIT-用户指南.md dist/dsh-flow-kit/docs/FLOW-KIT-用户指南.md dist/dsh-flow-kit/vendor/flow-kit-bundle/FLOW-KIT-用户指南.md | awk "{print \$1}" | sort -u | wc -l); [ "$n" -eq 1 ] && cmp -s dsh-flow-kit/README.md dist/dsh-flow-kit/README.md && bash package-dsh-plugin.sh --check && inst="$HOME/.dsh/profiles/${DSH_PROFILE:-web}/node_modules/dsh-flow-kit/docs/FLOW-KIT-用户指南.md"; if [ -f "$inst" ]; then cmp -s dist/dsh-flow-kit/docs/FLOW-KIT-用户指南.md "$inst" || { echo "SKIP: installed copy 未同步（先跑 make dsh-sync）"; }; else echo "SKIP: 未安装 dsh 插件，跳过 installed copy 比较"; fi && echo T04-verify-OK'
  </verify>
  <done>
    四份副本 md5 唯一；AC-5 闭合
  </done>
  <depends_on>T02</depends_on>
</task>

<task id="T05" parallel="true" status="done" model-tier="standard">
  <name>deck 扩页重建：slides.json 20→24 页 + deck_checks 断言同步 + 渲染验证</name>
  <read_files>
    .specs/user-guide-deck-gen/slides.json
    .specs/user-guide-deck-gen/build.py
    .specs/user-guide-deck-gen/layouts.py
    .specs/user-guide-deck-gen/theme.py
    .specs/user-guide-deck-gen/deck_checks.py
    .specs/user-guide-deck-gen/README.md
    flow-kit-bundle/FLOW-KIT-用户指南.md      <!-- 内容来源（T02 定稿） -->
  </read_files>
  <write_files>
    .specs/user-guide-deck-gen/slides.json
    .specs/user-guide-deck-gen/deck_checks.py
    .specs/user-guide-deck-gen/README.md
    .specs/user-guide-deck-gen/build.py
    .specs/user-guide-deck-gen/layouts.py
    flow-kit-用户指南.pptx
    .specs/user-guide-sync-2026-09b/render-preview/*
  </write_files>
  <action>
    按 DESIGN D3 扩页到 24 页：新增 4 张专页（① 安装面 ② L3 审查链：凭证/熔断/80000 字节 ③ 质量门禁：make check 六门 ④ 版本与副本口径），并同步刷新既有页中已漂移的内容（安装选项、单轮合并审查、用户级配置、gate_config 值域）。
    **同任务内同步更新 `deck_checks.py`（R3/R4/R5 修订）**：
    - ① `EXPECT_PAGES=24`；封面日期 `2026-09-21`；② **位置索引改为按标题查找**（`by_title = {t.splitlines()[0].strip(): t for _, t in items}`），禁止再用 `items[13]`/`items[19]` 这类硬编码下标；③ `KEY_STRINGS` 追加新专页关键串（至少：`FLOW_KIT_L3_AUTH_TOKEN`、`凭证`、`make check`、`check-dist`、`2026-09-21`）；④ 每张新专页加**按标题的 ≥1 关键串断言**（`assert "安装" in by_title["…"]` 形式），使「插入 4 页空壳」无法通过；⑤ `BANNED` 用**真实存在过的串**：`.specs/lessons/`、`项目级 stop-hook.json`、`三轮审查`、`20000 字节`、**`归档（ARCHIVE）`**（替换恒真的 `ARCHIVE.md`——该串在 slides.json 中 0 命中，加进去拦不住任何东西）
    - ⑥ **修 slides.json 现存的 D10/D39 残留**：`slides.json:287`（「归档（ARCHIVE）+ 34 号 …」）与 `:510`（「change 产物：…/ARCHIVE + T<N>-SUMMARY」）的 ARCHIVE 表述改为与指南 §5 阶段 7 对齐（`UAT.md` + `archive/<日期>-<id>/` + `ARCHIVE-MANIFEST.txt` + CHANGELOG/STATE）
    渲染验证：`soffice --headless --convert-to pdf` + `pdftoppm` 抽页（封面 + 3 张新专页 + 末页）→ PNG 存 `.specs/user-guide-sync-2026-09b/render-preview/`，人工确认无空页/无溢出/无缺字。
    **同步 `.specs/user-guide-deck-gen/README.md`（R7）**：`:28` 封面日期 `2026-09-03` → `2026-09-21`；`:32` 禁词清单按本轮新 BANNED 更新；`:23-25` layout 表若新增版式则补行；并把 `:28` 的 `hellrabb/flow-kit` 统一为 `hellrabbit/flow-kit`（与 `deck_checks.py` 的封面断言一致）。
    build.py / layouts.py 仅在确有必要时改（新增 layout 需同步 theme 基线）。
  </action>
  <verify>
    bash -c 'cd ~/unisoc/flow-kit && python3 .specs/user-guide-deck-gen/build.py >/dev/null && python3 .specs/user-guide-deck-gen/deck_checks.py && ! grep -qF "归档（ARCHIVE）" .specs/user-guide-deck-gen/slides.json && ! grep -qF "ARCHIVE.md" .specs/user-guide-deck-gen/slides.json && test "$(grep -o "ARCHIVE[A-Za-z.-]*" .specs/user-guide-deck-gen/slides.json | sort -u | tr -d "\n")" = "ARCHIVE-MANIFEST.txt" && test -n "$(ls .specs/user-guide-sync-2026-09b/render-preview/*.png 2>/dev/null)" && echo T05-verify-OK'
  </verify>
  <done>
    deck ≥24 页且 deck_checks 实跑通过；渲染抽检无版式事故；AC-6/AC-7 闭合
  </done>
  <depends_on>T02</depends_on>
</task>

<task id="T06" parallel="false" status="done" model-tier="cheap">
  <name>副本一致性守护：新增 test/test_guide_copy_parity.bats</name>
  <read_files>
    test/test_l3_pipeline_fix.bats            <!-- 既有 md5 一致性用例范式 -->
    test/test_gate_freshness.bats
    flow-kit-bundle/FLOW-KIT-用户指南.md
    package-dsh-plugin.sh
  </read_files>
  <write_files>
    test/test_guide_copy_parity.bats
    flow-kit-bundle/test/*.bats                        <!-- make test-sync 同步范围（本任务只新增 1 个文件，但该命令按目录同步） -->
    dist/dsh-flow-kit/vendor/flow-kit-bundle/test/test_guide_copy_parity.bats   <!-- vendor 树镜像（v4.4 · R1：本任务创建源文件后立即镜像） -->
  </write_files>
  <action>
    按 DESIGN D2 新增 1 个 bats 用例文件（`test/` 只允许 .bats）：
    - 用例 1：四份副本 md5 唯一（失败时指名哪两份不一致 + 给出修复命令）
    - 用例 2：版本日期口径（文首版本行 = 分节「最后同步日期」，且**两处相等**——**不二次写死具体日期**，与 DESIGN D2「封面日期 == 指南版本行日期」同口径 · v4 修订 · L2 R20）
    - 用例 3：guard 自身非恒绿——用夹具目录 + 注入 1 字节漂移验证比较逻辑真会失败（不依赖真实仓库被破坏）
    - 用例 4（**R3**）：deck 新鲜度——`flow-kit-用户指南.pptx` 页数 == `len(slides.json)`，且封面日期串 == 指南版本行日期（`python-pptx` 读取）
    - 用例 6（**R4/R5**）：`dist/` 缺席时 dist 相关断言**显式 SKIP 并打印原因**（不静默通过/不硬红）；
    - 用例 5b（deck 夹具非恒绿）：造 2 页 pptx vs 1 页 slides.json → 页数比较必须判失败
    - 用例 7（**R1 修订**）：`dist/` 缺席路径（只造 root+bundle 两份）注入 1 字节漂移 → 必须检出 + 指名
    - 用例 8（**阶段 2 L2 R23 修订**）：把 `deck_checks.py` 的**全部**断言接进 `make test`（页数/禁词/关键串/by_title 专页/封面/逐页非空）+ **title 级内容一致性**（slides.json 每页标题必须出现在 pptx 文本中）。注：这是**守护脚本内部**的断言接线（`test/` 目录由 `make test` 收集），**未新增任何 Makefile target**，与 M2「本轮不新增门禁 target」不冲突——M2 指的是把 deck 检查做成独立门禁 target；`~/.dsh/profiles/${DSH_PROFILE:-web}/node_modules/dsh-flow-kit/{docs,vendor}/FLOW-KIT-用户指南.md`（**守护域与 `Makefile:133-134` 的 `DSH_PROFILE ?= web` 同源**，不扫全部 profile · v4 修订 · L2 R20）**存在时**必须与 dist 一致（不存在则 SKIP）；失败信息附 `make dsh-sync`（**不得**建议直接 `cp` 到运行时副本）
    复用既有 `test_l3_pipeline_fix.bats` 中 **@test「in-repo copies share one md5」** 与 **@test「cmp-identical when present」** 的写法（按标题引用，不写行号）；不引入新依赖。
    **落盘后必须（三步）**：① `make test-sync`（同步到 `flow-kit-bundle/test/`）；② 自检 `diff -rq test/ flow-kit-bundle/test/` 无输出；③ **镜像到 vendor 树** `mkdir -p dist/dsh-flow-kit/vendor/flow-kit-bundle/test && cp flow-kit-bundle/test/test_guide_copy_parity.bats dist/.../test/`，再 `bash package-dsh-plugin.sh --check` 复绿——否则 `check-dist`（`make check` 第六门）会红（v4.4 · 阶段 3 L2 R1：镜像动作从 T04 移入本任务）。
  </action>
  <verify>
    bash -c 'cd ~/unisoc/flow-kit && npx bats test/test_guide_copy_parity.bats && make check-test-sync && diff -rq test/ flow-kit-bundle/test/ && cmp -s flow-kit-bundle/test/test_guide_copy_parity.bats dist/dsh-flow-kit/vendor/flow-kit-bundle/test/test_guide_copy_parity.bats && npx bats test/test_guide_copy_parity.bats --filter "vacuously green" && bash package-dsh-plugin.sh --check >/dev/null 2>&1 && echo T06-verify-OK'
  </verify>
  <done>
    **8 个用例**（1 四副本 md5 / 2 版本日期口径 / 3 夹具漂移检出 / 4 deck 页数+封面 / 5 deck 夹具非恒绿 / 6 installed copy when-present / 7 dist 缺席路径 / 8 deck content parity）实跑全绿；且经「注入漂移 → 变红 → 还原 → 复绿」实测（AC-10）
  </done>
  <depends_on>T04</depends_on>
</task>

<task id="T07" parallel="false" status="done" model-tier="standard">
  <name>全量验证：断言矩阵实跑 + make check 六门 + 渲染抽检 + 验收汇总</name>
  <read_files>
    .specs/user-guide-sync-2026-09b/*
    test/*
    Makefile
    /tmp/guide-drift-report.md
  </read_files>
  <write_files>
    .specs/user-guide-sync-2026-09b/TEST.md
    .specs/user-guide-sync-2026-09b/UAT.md
    .specs/user-guide-sync-2026-09b/verify-ac.sh
    .specs/user-guide-sync-2026-09b/verify-boundary.sh
    .specs/user-guide-sync-2026-09b/check-appendix-superset.py
    .specs/user-guide-sync-2026-09b/make-check.log
    .specs/user-guide-sync-2026-09b/bats-full.log          <!-- v4.5 · 阶段 5 L3：全量 TAP 逐用例日志 -->
    .specs/user-guide-sync-2026-09b/dev-summaries/*
  </write_files>
  <action>
    1. 逐条实跑附录 A 的正例/反例断言，把**实跑输出**记入 TEST.md 断言矩阵（禁止只写结论不写输出）
    2. `make check`（六门）全量实跑：**输出落盘** `.specs/user-guide-sync-2026-09b/make-check.log`（含 rc）；**另跑 `npx bats test/ --formatter tap > .specs/user-guide-sync-2026-09b/bats-full.log 2>&1`** 落盘逐用例 TAP（v4.5 · 阶段 5 L3：`make-check.log` 只有 `tail -3` 摘要，红时无法复算失败用例名）；同时记录耗时
    3. 反向抽查：随机抽 10 段现行正文人工核对是否与实现一致，把抽样范围与结论显式登记（缓解 D6 的抽样风险）
    4. 汇总每个 task 的 SUMMARY 到 `.specs/<id>/dev-summaries/`
    5. 记录 AC-1..AC-10 的逐条闭合证据（AC-11 由审查链闭合）
  </action>
  <verify>
    bash -c 'cd ~/unisoc/flow-kit && make check && bash .specs/user-guide-sync-2026-09b/verify-ac.sh >/dev/null && python3 .specs/user-guide-sync-2026-09b/check-appendix-superset.py >/dev/null && bash .specs/user-guide-sync-2026-09b/verify-boundary.sh >/dev/null && test -s .specs/user-guide-sync-2026-09b/bats-full.log && grep -qE '^1\.\.' .specs/user-guide-sync-2026-09b/bats-full.log && echo T07-verify-OK'
  </verify>
  <done>
    TEST.md 含逐条实跑证据 + make check 六门全绿（日志落盘）+ 反向抽查记录；AC-1..AC-10 逐条可复算（AC-11 由 T08 承载）
  </done>
  <depends_on>T04,T05,T06</depends_on>
</task>

<task id="T08" parallel="false" status="blocked" model-tier="standard">
  <name>阶段 7 归档与收口（AC-11 · 前置门禁 6→7 passed）</name>
  <read_files>
    .specs/user-guide-sync-2026-09b/**
    .specs/STATE.md
    .specs/CHANGELOG.md
    .specs/LESSONS.md
    .specs/archive/2026-09-21-brooks-review-fix-2026-09/ARCHIVE-MANIFEST.txt   <!-- 清单格式参照 -->
  </read_files>
  <write_files>
    .specs/archive/2026-09-21-user-guide-sync-2026-09b/*
    .specs/user-guide-sync-2026-09b/make-manifest.sh        <!-- 生成清单用 -->
    .specs/CHANGELOG.md
    .specs/STATE.md
    .specs/LESSONS.md
  </write_files>
  <action>
    **前置条件（硬约束 · v4.6 依阶段 3 L2 第七轮 R1 澄清语义）**：本 task 只能在**已进入阶段 7**（`jq -e '.goal.current_phase=="7" and .goal.gates["6→7"]=="passed"' .flow-active`）之后执行。
    注意口径：`gates["6→7"]="passed"` 表示「**阶段 6 的审查已通过、流水线已转入阶段 7**」（由阶段 6 收口时写入），**不是**「阶段 7 已完成」——本 task 正是阶段 7 的执行体，不存在因果倒置。 —— `mv` 产物目录会销毁阶段 4–7 与门禁自身依赖的活路径（`.goal-snapshot.json` 被 `independent-review-gate.sh` Gate 5 读取、审查锚点文件被 29 号写入与 AC-11 校验、`flow-kit-artifacts.sh` 的 phase 4–7 产物校验），提前归档会破坏审查链自身。
    阶段 7 收口（AC-11 的归档面）：
    1. **归档前**：确认**五个已过门禁阶段**（1/2/3/5/6）的审查锚点齐备；**阶段 7 自身的 L2/L3 是本 task 的前置动作**（先跑 `bash .specs/user-guide-sync-2026-09b/run-l3.sh 7 pass both` 并在 `INDEPENDENT-REVIEW-7.md` 写入 L2 段，再 `mv`）。
       > **外部依赖声明（v4.6 · 阶段 3 L2 第七轮 R2）**：审查锚点文件**不由任何 task 手工产出**——它由 `l3_review_run`（Stop hook 29 号 / 本仓库 `run-l3.sh`）在 L3 结案时写入；阶段 4 无独立审查（`gate_config` 只含 1/2/3/5/6/7）。缺失即中止归档（不得跳过）。
    2. **待 L2 段与主 agent 响应段定稿后**再生成清单（避免清单给仍会被写入的 IR 文件盖章 → hash 出生即失真 · v4.6 · 阶段 7 L2 R5），**先生成清单、后 mv**（v4.3：此前「先 mv 再生成」三序皆不可执行）：`bash .specs/user-guide-sync-2026-09b/make-manifest.sh .specs/user-guide-sync-2026-09b`（在**产物目录原位**生成；脚本自带「目标不存在即失败」与「条目 <10 即失败」双自检）
    3. `mv .specs/user-guide-sync-2026-09b .specs/archive/2026-09-21-user-guide-sync-2026-09b`
    4. `.specs/CHANGELOG.md` 核对本 change 行并**回填最终数字**（用例数 / 断言通过数 —— 现为 **8 用例 / 129 通过**（分段 4+39+60+23 = 126 + 段外 3）；**以 `verify-ac.sh` 实跑输出为准**，本行不写死）
    5. `.specs/STATE.md` 更新 `last_change_archived` 链（本 change + 前三项顺延）与 `test_framework` 计数
    6. `.specs/LESSONS.md` 核对 L-106~L-109 已入库；`UAT.md` 的 B 段标注「待用户确认」
    7. `git add -A` + 原子提交 ≤3 个（Conventional Commits：`docs(user-guide-sync-2026-09b): …`）
    8. 归档后保留目录的 `rm` **双重确认**（`7-integration` §5 口径）；MINOR-DEFERRED 交用户 triage
  </action>
  <verify>
    bash -c 'cd ~/unisoc/flow-kit && d=.specs/archive/2026-09-21-user-guide-sync-2026-09b && test -d "$d" && test "$(grep -c "B  sha256:" "$d/ARCHIVE-MANIFEST.txt")" -ge 10 && grep -qE "last_change_archived.*user-guide-sync-2026-09b" .specs/STATE.md && grep -qE "bats-core 1\.13\.0.*9[0-9]{2} tests" .specs/STATE.md && test "$(git -c core.quotepath=false status --porcelain | wc -l)" = 0 && echo T08-verify-OK'
  </verify>
  <done>
    AC-11 闭合：六阶段审查锚点齐备 → 清单（≥10 条目）→ 原件归档 → CHANGELOG 回填最终数字 → STATE `last_change_archived` → LESSONS → 提交后 `git status` 干净
  </done>
  <depends_on>T07</depends_on>
</task>
```


---

## 附录 A · 漂移条目 → 任务映射与断言（正例/反例）

> **母本声明（v4.5 · L2 R24/R1）**：本附录的**断言母本 = `REQUIREMENT.md` 的 AC-2 / AC-3 / AC-4 表**；附录 A 是它的**超集**（含 AC 表未列的 D 项与 deck/版本断言）。两者冲突时**以 AC 表为准**并回填本附录——阶段 5 的 TEST.md 含一条集合断言 `附录 A ⊇ AC-2/AC-3 表`（逐条比对锚点串，缺失即失败）。
> **约定**：反例 = 修订后**必须 0 命中**的旧措辞（字面 `grep -F`）；正例 = **必须 ≥1 命中**的新措辞（**字面串**；正则在格内标注 `regex:`）。
> 断言对象 = **四份副本各自满足**（T04 对齐后等价；对齐前只核 bundle）。
> 段落级断言（如 D26）必须限定在小节范围内，全文件 grep 视为无效判据。

| # | 严重度 | 任务 | 反例（=0） | 正例（≥1） |
|---|---|---|---|---|
| D01 | 🔴 | T01 | `核心引擎 + skills + brooks-lint + hooks` | `核心引擎 + skills + brooks-lint + brooks-tools` + `需再加 ` + `--user`（v4.1 · R37 回填为 AC 主表字面串） |
| D02 | 🟡 | T01 | （选项表缺项无旧措辞可反证，用条目计数断言） | `--platform`、`--no-brooks-tools`、`--self-test`、`--brooks-src`、`--yes`、`配置仍走用户级` |
| D03 | 🟡 | T01 | `仅安装 hooks（需配合 --project）` | `仅安装 hooks + \`.specs/STATE.md\` 模板`（**带回反引号** · v4.4 依阶段 3 L2 R3） |
| D04 | 🟡 | T01 | `若走 dsh plugin add/update 重装`（v4.6 · 阶段 7 L2 R1：与母本 REQUIREMENT 同串；旧首选路径句在四副本已 0 命中） | `make dsh-sync` |
| D05 | 🟢 | T01 | — | `v0.2.0` |
| D06 | 🟢 | T01 | — | `.flow-active` 示例含 `"goal"` |
| D07 | 🟡 | T01 | — | `/flow gate-config`、`/flow l2-review` |
| D08 | 🔴 | T01 | `--sub-goal-4` | `SUB_GOAL_4` 或 `自动提取` |
| D09 | 🔴 | T01 | `.specs/lessons/` | `.specs/LESSONS.md` |
| D10 | 🔴 | T01/T02 | `ARCHIVE.md` | `UAT.md` + `archive/<YYYY-MM-DD>-<change-id>/`（v4.3 依阶段 3 L2 R4 回填归档路径锚点） |
| D11 | 🔴 | T01 | `三轮审查` | `单轮合并审查` |
| D12 | 🟡 | T01 | `<title>任务标题</title>` | `<name>` + `<read_files>` + `<write_files>` |
| D13 | 🟡 | T01 | `只在同波次内` | `同波次内不应有` + `跨波次必须显式声明`（v4 · R27：与实现 `:623` 逐字一致） |
| D14 | 🟡 | T01 | `🟡 Major`（作为阶段 6 现行分级） | `Important` |
| D15 | 🟡 | T01 | `核对归档产物与 CHANGE 范围` | `归档后是否仍有未提交变更` |
| D16 | 🔴 | T02 | 项目根 `ARCHITECTURE.md`（产出语境） | `.specs/ARCHITECTURE.md` |
| D17 | 🟢 | T02 | `restyle-<target-tone>` | `restyle-<old>-to-<new>` |
| D18 | 🟡 | T02 | `- **标准**（默认）：全维诊断`（整句 · v4 对齐 AC） | `快速体检` + `完整审计` + `单维深挖` |
| D19 | 🔴 | T02 | `pre_tool_use_gates.auto_checkpoint` | `占位块` / `代码未消费` |
| D20 | 🔴 | T02 | `此字段仅作末级兜底` | `已废弃` + `l3-default=` |
| D21 | 🔴 | T02 | `.flow-active.independent-review` 握手 | `.independent-review-<phase>.done` |
| D22 | 🔴 | T02 | `允许手动绕过` + `手动 touch done` | `由子系统自动` + `L3_verdict=skipped`（两条都要命中）+ **白名单**：配置键行 `max_failures_before_bypass` 允许保留 |
| D23 | 🔴 | T02 | `matcher: `Bash`，`（仅 Bash） | `Bash|Write|Edit` + `path-guard` |
| D24 | 🟡 | T02 | — | `runtime-edit-guard` |
| D25 | 🟡 | T02 | — | `max_artifact_bytes` + `80000` |
| D26 | 🟡 | T02 | （**无反例锚点**：旧清单是列表结构 · v4.2 依 L3 critical 修订） | **段落级判据（命令本体）**：`awk '/^### SessionStart Hook/{f=1} f&&/^### /&&!/^### SessionStart Hook/{f=0} f' <指南>` 抽段后段内必须命中 `archive-uncommitted`（v4.3 回填） |
| D27 | 🟡 | T02 | — | `FLOW_KIT_L3_AUTH_TOKEN` + `门禁死锁`（或等价「不写 .done → 阻塞」） |
| D28 | 🟡 | T02 | `touch .specs/<id>/.independent-review-<phase>.done` | 6 键 KVP：`written_by` + `L2_verdict` + `L3_verdict` |
| D29 | 🟡 | T02 | `要求 > 0 字节`（作为唯一判据） | `Tier1` + `Tier2` + `≥6 行`（v4.4：三串在指南 §7 与 §12 的「.done 真实性校验」表内均落地） |
| D30 | 🟡 | T02 | `"31-auto-advance": true` | `31 号由 \`goal.auto_advance\` 驱动`（**单条字面锚点**：完整独有短语，改前 0 命中 · v4.2：不再拆成三段过程说明） |
| D31 | 🔴 | T02 | `随 flow-kit bundle 分发` | `不由 flow-kit bundle 分发` / `独立安装` |
| D32 | 🟡 | T02 | — | `skill 文件` 与 `生成的 deck 工程结构` 分列 |
| D33 | 🔴 | T01 | 旧表格行整格原文（**未转义原文见 REQUIREMENT AC-3 的表外代码块**；4 个旧值串单独不参与断言） | `both` + `L2` + `L3`（同句共现；`off` 不作断言） |
| D34 | 🔴 | T01 | `编辑 .claude/stop-hook.json`（旧「方式 C」指令句 · v4.4：原反例是正例子串，两向不可能同时成立） | `~/.dsh/stop-hook.json` + `~/.config/opencode/stop-hook.json` + `~/.claude/stop-hook.json`（三条**字面路径** · v4.3 回填） |
| D35 | 🟡 | T02 | `stop-hook 配置/报告`（.flow-kit 说明） | `只放运行时状态` / `只放状态` |
| D36 | 🟡 | T02 | `stop-hook.json           # stop hook 配置`（项目树中的该行 · **段落定位**：§12「项目级文件」树内） | `配置不在项目里` + `stop-hook.json`（v4.1/4.2 · R32/R37） |
| D37 | 🟡 | T02 | — | `l3-api.sh`、`l3-done.sh`、`l3-prompt.sh`、`l3-section.sh`、`l3-truncate.sh`、`runtime-adapter.sh` |
| D38 | 🟡 | T02 | — | `gate-helpers.sh`、`gate-checks-review.sh` |
| D39 | 🟡 | T02 | `ARCHIVE.md`（产物清单语境） | `PROGRESS.md`、`MINOR-DEFERRED.md`、`INDEPENDENT-REVIEW-` |
| D40 | 🟢 | T02 | `├── .local/bin/`（在 ~/.claude 树内） | `~/.local/bin/` |
| D41 | 🟡 | T02 | — | `requirement-review`、`spec-test`、`task-test`（预设名补全 ≥17） |
| D42 | 🟢 | T02 | — | 篡改检测范围限定句（阶段名 key / transition key 不在比对范围） |
| D43 | 🟢 | T02 | `2026-07-13` | `regex:^> 版本: 2026-09-21` · `regex:最后同步日期\*\*: 2026-09-21` |

### 候选新增项（N1–N11）断言

| # | 任务 | 断言（≥1 命中） |
|---|---|---|
| N1 L3 凭证 | T02 | `FLOW_KIT_L3_AUTH_TOKEN` · `ANTHROPIC_AUTH_TOKEN` · `l3.env` · `死锁` |
| N2 工件上限 | T02 | `max_artifact_bytes` · `80000` · `字节` |
| N3 门禁六门 | T02 | `check-dist` · `check-validate` · `check-hooks-sync` |
| N4 hooks 副本 | T02 | `hooks-sync` · `check-hooks-sync` |
| N5 dsh-sync | T01 | `make dsh-sync` · `DSH_PROFILE` |
| N6 verify-claims | T02 | `verify-claims` |
| N7 l2-review | T01 | `/flow l2-review` |
| N8 runtime-edit-guard | T02 | `runtime-edit-guard` |
| N9 path-guard 拒写 .done | T02 | `path-guard`（或「拒绝主 agent 直写 .done」等价表述） |
| N10 L3 段契约 + 前轮反馈优先 | T02 | `ADR-025`（配**用户可见后果**表述：重审优先看前轮反馈、超长工件按 UTF-8 边界截断；**不写内部契约标记** —— v3 修订 · L2 R8） |
| N11 ADR-026 载荷边界 | T02 | `ADR-026` + `不可信`（两条**字面锚点** · v4.3 依阶段 3 L2 R4 回填） |
| N12 副本守护（→ AC-10） | T06 | `test/test_guide_copy_parity.bats` 存在且实跑全绿 |

### deck 断言（T05）

| 断言 | 值 |
|---|---|
| `EXPECT_PAGES` | ≥ 24 |
| 封面日期串 | `2026-09-21` |
| 位置断言方式 | **按标题查找**（`by_title`），禁止硬编码下标（R3） |
| 新增专页 | 安装面 / L3 审查链 / 质量门禁 / 版本与副本口径——**每页一条按标题的关键串断言**（R5），不只是总数 |
| BANNED 扩充 | `.specs/lessons/`、`项目级 stop-hook.json`、`三轮审查`、`20000 字节`、`归档（ARCHIVE）`（**不用恒真的 `ARCHIVE.md`**，R4） |
| slides.json 残留 | `:287` / `:510` 的 `ARCHIVE` 表述改为与指南 §5 阶段 7 对齐（T05 verify 含 `! grep -q "ARCHIVE" slides.json`） |
| 注入验证 | 删任一专页标题 → deck_checks 变红 → 还原 → 复绿；改封面日期 → 同样两轮（实跑记录入 TEST.md） |

### 版本日期口径断言（AC-1 / D43 的机检口径 · R6 修订）

```bash
f=flow-kit-bundle/FLOW-KIT-用户指南.md
grep -q '^> 版本: 2026-09-21' "$f"                      # 版本行（唯一"版本口径"锚点）
grep -q '最后同步日期\*\*: 2026-09-21' "$f"              # 分节日期
test "$(grep -c '20260713\|2026-07-13' "$f")" = 0       # 旧版本号清零
grep -n '2026-09-03' "$f" | grep -v '起' | wc -l | grep -qx 0   # 09-03 只允许出现在「…起」历史锚点句
```

> **保留项登记（TEST.md 必录）**：`2026-09-03` 允许出现在**「2026-09-03 起 L2/L3 模型按 `fk_resolve_model` 五级解析链解析」这类历史陈述句**中——这是 ADR-012/013 的生效时间锚，**不得改写为 09-21、也不得删除**。**不登记行号**（v4 · R30：行号会随修订漂移，判据只约束「非历史句命中数 = 0」）。

---

## 状态字段说明

- `status="pending"` — 未开始
- `status="in_progress"` — 进行中（同时只允许一个非 [P] 任务为此状态）
- `status="done"` — 已完成（verify 通过）
- `status="blocked"` — 阻塞（必须在文件末尾「阻塞日志」记录）

---

## model-tier 字段说明（ADR-016）

- `model-tier="cheap"` — 1-2 文件 / 简单修改 → flash-tier
- `model-tier="standard"` — 多文件 / 标准功能 → pro-tier
- `model-tier="top"` — 架构 / review / 复杂逻辑 → top-tier

---

## 阻塞日志

| 任务 | 阻塞原因 | 待人工决策项 | 时间 |
|---|---|---|---|
| T08 | 硬前置「已进入阶段 7」（`current_phase=="7"` 且 `gates["6→7"]=="passed"`）尚未满足；本任务**不由 4-dev 波次执行**，改由 **阶段 7（7-integration）** 承接。**可复算判据**：`jq -e '.goal.current_phase=="7" and .goal.gates["6→7"]=="passed"' .flow-active` 返回 0 | 无（门禁满足即自动解锁） | 2026-09-21 |

---

## Fix 任务（来自 REVIEW / INTEGRATION）

> 此区域由 review/integration 阶段自动追加，编号 `T-FIX-XX`。

```xml
<!-- 占位 -->
```
