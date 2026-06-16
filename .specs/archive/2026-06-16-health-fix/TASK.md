# TASK: 健康巡检修复 — 消除技术债 + 引入测试

- **Change ID**: `health-fix`
- **关联**: `@.specs/health-fix/REQUIREMENT.md`、`@.specs/health-fix/DESIGN.md`

---

## 波次划分

```
Wave 1 (parallel): T01[P], T02[P]                              ← 基础设施 + 清理
Wave 2 (parallel): T03[P], T04[P]   (depends on T01)          ← 写测试（TDD: 先写测试再重构）
Wave 3:            T05              (depends on T04)           ← 最大重构，单独跑避免冲突
Wave 4 (parallel): T06[P], T07[P], T08[P], T09[P]             ← 独立小修复，不同文件无冲突
```

> 同 wave = 可并行；跨 wave = 必须顺序执行。

---

## 任务清单

```xml
<task id="T01" parallel="true" status="done">
  <name>安装 bats-core + 创建 test/ 目录骨架</name>
  <read_files>
    flow-kit-bundle/install.sh
    flow-kit-bundle/hooks/stop/lib/common.sh
  </read_files>
  <write_files>
    test/test_common.bats
    test/test_install.bats
  </write_files>
  <action>
    1. 检查 bats 是否已安装（which bats || apt install bats）
    2. 创建 test/ 目录
    3. 生成 test/test_common.bats 骨架（含 bats_require_minimum_version + jq 检测 + skip 逻辑）
    4. 生成 test/test_install.bats 骨架（含 setup/teardown + SCRIPT_DIR 路径解析）
    两个骨架文件只有框架代码（setup/teardown/helper），不含具体测试用例。
    见 DESIGN D1。
  </action>
  <verify>bats test/ 2>&amp;1 | grep -E '^0 tests|^[0-9]+ tests'</verify>
  <done>AC-1: bats test/ 可运行（即使 0 个测试通过）</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true" status="done">
  <name>删除 .claude/hooks/ 目录（hooks 去重）</name>
  <read_files>
    .claude/hooks/
    package-flow-kit.sh
    flow-kit-bundle/install.sh
  </read_files>
  <write_files>
    .claude/hooks/stop/00-gate.sh
    .claude/hooks/stop/01-transcript-parse.sh
    .claude/hooks/stop/20-claude-md.sh
    .claude/hooks/stop/21-memory.sh
    .claude/hooks/stop/22-git.sh
    .claude/hooks/stop/23-quality.sh
    .claude/hooks/stop/24-session.sh
    .claude/hooks/stop/25-project.sh
    .claude/hooks/stop/26-workflow.sh
    .claude/hooks/stop/30-ai-analyze.sh
    .claude/hooks/stop/99-report.sh
    .claude/hooks/stop/lib/common.sh
    .claude/hooks/stop/lib/flow-kit-artifacts.sh
    .claude/hooks/stop/lib/transcript-parser.sh
    .claude/hooks/session-start/flow-kit-resume.sh
    .claude/hooks/session-start/stop-report-reminder.sh
  </read_files>
  <action>
    1. 确认 flow-kit-bundle/hooks/ 下同名文件与 .claude/hooks/ 完全相同（已通过 diff 验证）
    2. 删除 .claude/hooks/ 目录（rm -rf）
    3. 确认 package-flow-kit.sh Part C 已从 flow-kit-bundle/hooks 读取（line 64: HOOK_SRC="$SCRIPT_DIR/flow-kit-bundle/hooks" — 无需改）
    4. 确认 install.sh 的 install_hooks() 从 $SCRIPT_DIR/hooks/ 读取（即 bundle 内 hooks/ — 无需改）
    见 DESIGN D3。
  </action>
  <verify>test ! -d .claude/hooks &amp;&amp; echo "PASS"</verify>
  <done>AC-4: .claude/hooks/ 目录已删除，hooks 唯一源为 flow-kit-bundle/hooks/</done>
  <depends_on></depends_on>
</task>

<task id="T03" parallel="true" status="done">
  <name>编写 test_common.bats 测试用例</name>
  <read_files>
    test/test_common.bats
    flow-kit-bundle/hooks/stop/lib/common.sh
  </read_files>
  <write_files>
    test/test_common.bats
  </write_files>
  <action>
    在 T01 骨架基础上填充测试用例，覆盖 6 个核心函数：
    - config_get: happy path (返回值/默认值) + 边界（文件不存在/空值）
    - module_enabled: true/false/不存在
    - check_enabled: 模块禁用/启用+checks 空/指定 check
    - is_subagent: SubagentStop 事件/PARENT_SESSION 非空/正常 Stop
    - file_not_empty: 存在非空/不存在/空文件
    - line_count: 正常文件/不存在文件
    每个函数至少 1 个 happy-path + 1 个边界用例。
    setup() 中构造临时 CONFIG_FILE（jq 写 stop-hook.json）。
    无 jq 时 skip 全部测试并输出原因。
    见 AC-2。
  </action>
  <verify>bats test/test_common.bats --formatter tap | grep -c '^ok '</verify>
  <done>AC-2: ≥ 6 个函数的 bats 测试通过</done>
  <depends_on>T01</depends_on>
</task>

<task id="T04" parallel="true" status="done">
  <name>编写 test_install.bats 测试用例</name>
  <read_files>
    test/test_install.bats
    flow-kit-bundle/install.sh
    flow-kit-bundle/hooks/config/stop-hook.json
    flow-kit-bundle/hooks/config/settings.json
  </read_files>
  <write_files>
    test/test_install.bats
  </write_files>
  <action>
    在 T01 骨架基础上填充测试用例，覆盖 10 个参数：
    - --global: 输出含 "flow-kit 核心已安装"
    - --project: 指定临时目录，验证 hooks 文件写入
    - --update: 版本相等时跳过；版本更新时执行
    - --reinstall: 输出含 "清理既有安装"
    - --dry-run: 输出含 [DRY-RUN]，不创建实际文件
    - --no-hooks: 输出不含 "安装 Hook"
    - --no-skills: 输出不含 "技能已安装"
    - --no-brooks: 输出不含 "brooks-lint"
    - --hooks-only: 输出含 "Hook" 不含 "flow-kit 核心"
    - --user: hooks 写入 ~/.claude/hooks/ 而非项目 .claude/
    所有测试使用 bats temp dir（BATS_TEST_TMPDIR）+ --dry-run 模式（不写实际文件）。
    见 AC-3。
  </action>
  <verify>bats test/test_install.bats --formatter tap | grep -c '^ok '</verify>
  <done>AC-3: 10 个参数各至少 1 个测试通过</done>
  <depends_on>T01</depends_on>
</task>

<task id="T05" status="done">
  <name>拆分 install.sh 为 lib/ 模块</name>
  <read_files>
    flow-kit-bundle/install.sh
    test/test_install.bats
    .specs/health-fix/DESIGN.md
  </read_files>
  <write_files>
    flow-kit-bundle/install.sh
    flow-kit-bundle/lib/install_core.sh
    flow-kit-bundle/lib/install_skills.sh
    flow-kit-bundle/lib/install_brooks.sh
    flow-kit-bundle/lib/install_hooks.sh
  </write_files>
  <action>
    从 install.sh 提取 4 个模块文件：
    1. lib/install_core.sh: install_flow_kit_core() 函数（原 lines 148-165）
    2. lib/install_skills.sh: install_skills() 函数（原 lines 170-184）
    3. lib/install_brooks.sh: install_brooks_lint() 函数（原 lines 189-336）
       → 含 D7 动态版本号读取（见 T09）
    4. lib/install_hooks.sh: install_hooks() + install_specs_template() + 辅助函数（原 lines 19-143 + 341-454）
    主脚本 install.sh 保留：shebang + set -euo pipefail + 变量声明 + usage() + 参数解析 + source lib/* + 调度逻辑（≤ 150 行）。
    所有 lib source 使用 "$SCRIPT_DIR/lib/xxx.sh" 绝对路径。
    保持 --dry-run 输出与拆分前完全一致。
    见 DESIGN D2。
  </action>
  <verify>diff &lt;(bash flow-kit-bundle/install.sh --global --dry-run 2&gt;&amp;1 | sed 's/^.*[DRY-RUN]//') &lt;(git show HEAD:flow-kit-bundle/install.sh 2&gt;/dev/null | bash /dev/stdin --global --dry-run 2&gt;&amp;1 | sed 's/^.*[DRY-RUN]//') ; bats test/test_install.bats</verify>
  <done>AC-5: install.sh ≤ 150 行 + 4 个 lib 文件 ≤ 200 行 + --dry-run 等价 + 测试通过</done>
  <depends_on>T04</depends_on>
</task>

<task id="T06" parallel="true" status="done">
  <name>魔法数字替换为 readonly 命名常量</name>
  <read_files>
    .claude/hooks/stop/24-session.sh
    .claude/hooks/session-start/flow-kit-resume.sh
    .claude/hooks/stop/lib/flow-kit-artifacts.sh
    .claude/hooks/stop/23-quality.sh
    flow-kit-bundle/hooks/stop/24-session.sh
    flow-kit-bundle/hooks/session-start/flow-kit-resume.sh
    flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh
    flow-kit-bundle/hooks/stop/23-quality.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/24-session.sh
    flow-kit-bundle/hooks/session-start/flow-kit-resume.sh
    flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh
    flow-kit-bundle/hooks/stop/23-quality.sh
  </write_files>
  <action>
    在各文件顶部（set -euo pipefail 之后）添加 readonly 常量，替换函数体中直接使用的裸数字：
    - 24-session.sh: SECS_PER_MIN=60, SECS_PER_HOUR=3600, LONG_SESSION_SECS=7200, TOKEN_WARNING_THRESHOLD=100000, HIGH_USAGE_COUNT=20, GP_WARNING_COUNT=3, WEEKLY_HEAVY_THRESHOLD=20
    - flow-kit-resume.sh: STALE_SESSION_HOURS=72
    - flow-kit-artifacts.sh: MIN_MEANINGFUL_LINES=3
    - 23-quality.sh: TRIVIAL_CHANGE_LINES=50
    只修改 flow-kit-bundle/hooks/ 下的文件（唯一源）。
    不改变任何逻辑行为。
    见 DESIGN D5。
  </action>
  <verify>grep -c 'readonly' flow-kit-bundle/hooks/stop/24-session.sh flow-kit-bundle/hooks/session-start/flow-kit-resume.sh flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh flow-kit-bundle/hooks/stop/23-quality.sh</verify>
  <done>AC-6: 4 个文件中所有裸数字阈值已替换为 readonly 命名常量</done>
  <depends_on>T04</depends_on>
</task>

<task id="T07" parallel="true" status="done">
  <name>修复 package-flow-kit.sh 外部路径依赖</name>
  <read_files>
    package-flow-kit.sh
    flow-kit-bundle/flow-kit/GO.md
    flow-kit-bundle/brooks-lint/plugin/.claude-plugin/plugin.json
  </read_files>
  <write_files>
    package-flow-kit.sh
  </write_files>
  <action>
    为 Part A（flow-kit 核心）、Part B（skills）、Part F（brooks-lint）添加本地 fallback：
    - Part A (line 29): 优先检查 $SCRIPT_DIR/flow-kit-bundle/flow-kit/GO.md 是否存在，存在则 rsync 本地副本；否则走原逻辑（git archive ~/.claude/flow-kit）
    - Part B (line 49): 优先检查 $SCRIPT_DIR/flow-kit-bundle/skills/ 是否有 flow-*/ 目录，有则 cp 本地副本；否则走原逻辑
    - Part F (line 252): 保持现有 fallback 链（--brooks-src > 本地缓存 > git archive），增加 $SCRIPT_DIR/flow-kit-bundle/brooks-lint/plugin 作为最终 fallback
    每次 fallback 时 echo 日志标明使用了哪个源。
    见 DESIGN D4。
  </action>
  <verify>mv ~/.claude/flow-kit ~/.claude/flow-kit.bak 2&gt;/dev/null; bash package-flow-kit.sh /tmp/test-export 2&gt;&amp;1 | grep -E 'fallback|本地副本|本地'; mv ~/.claude/flow-kit.bak ~/.claude/flow-kit 2&gt;/dev/null; echo "PASS"</verify>
  <done>AC-7: 无 ~/.claude/flow-kit 时自动 fallback 到本地 flow-kit-bundle/flow-kit/</done>
  <depends_on>T04</depends_on>
</task>

<task id="T08" parallel="true" status="done">
  <name>settings.json 模板去重</name>
  <read_files>
    package-flow-kit.sh
    flow-kit-bundle/hooks/config/settings.json
  </read_files>
  <write_files>
    package-flow-kit.sh
  </write_files>
  <action>
    package-flow-kit.sh Part D (lines 104-143):
    删除 heredoc (cat > "$STAGING/hooks/config/settings.json" << 'SETEOF' ... SETEOF)
    替换为: cp "$SCRIPT_DIR/flow-kit-bundle/hooks/config/settings.json" "$STAGING/hooks/config/"
    确认 flow-kit-bundle/hooks/config/settings.json 的内容与当前 heredoc 一致。
    见 DESIGN D6。
  </action>
  <verify>grep -c 'cat &gt; "\$STAGING/hooks/config/settings.json"' package-flow-kit.sh | grep '^0$'</verify>
  <done>AC-8: package-flow-kit.sh 不再包含 settings.json heredoc，改为 cp 文件</done>
  <depends_on>T04</depends_on>
</task>

<task id="T09" parallel="true" status="done">
  <name>brooks-lint 版本号动态读取</name>
  <read_files>
    flow-kit-bundle/install.sh
    flow-kit-bundle/brooks-lint/plugin/.claude-plugin/plugin.json
    flow-kit-bundle/lib/install_brooks.sh
  </read_files>
  <write_files>
    flow-kit-bundle/lib/install_brooks.sh
  </write_files>
  <action>
    在 install_brooks.sh（T05 拆分后的模块）中：
    1. 读取 brooks-lint/plugin/.claude-plugin/plugin.json 的 version 字段
    2. 优先用 jq: BROOKS_VERSION=$(jq -r '.version' "$SCRIPT_DIR/brooks-lint/plugin/.claude-plugin/plugin.json")
    3. fallback（无 jq）: grep + sed 提取 version 字段
    4. 用 $BROOKS_VERSION 拼接路径: plugin_dst=".../brooks-lint/$BROOKS_VERSION"
    当前硬编码 1.3.0 在 install.sh line 194 — T05 拆分后该行会移入 lib/install_brooks.sh。
    见 DESIGN D7。
  </action>
  <verify>source flow-kit-bundle/lib/install_brooks.sh 2&gt;/dev/null; echo "PASS: $(echo $BROOKS_VERSION)"; grep -c '1\.3\.0' flow-kit-bundle/install.sh flow-kit-bundle/lib/install_brooks.sh | grep '^0$'</verify>
  <done>AC-9: install.sh + lib/install_brooks.sh 不含硬编码版本号 '1.3.0'</done>
  <depends_on>T04</depends_on>
</task>
```

---

## 状态字段说明

- `status="pending"` — 未开始
- `status="in_progress"` — 进行中
- `status="done"` — 已完成（verify 通过）
- `status="blocked"` — 阻塞

---

## 阻塞日志

| 任务 | 阻塞原因 | 待人工决策项 | 时间 |
|---|---|---|---|
|  |  |  |  |

---

## Fix 任务（来自 REVIEW / INTEGRATION）

```xml
<!-- 占位 -->
```
