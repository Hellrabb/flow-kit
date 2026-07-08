# TASK: M-health eval 巡检收尾 — 修测试路径 + 点亮 lint 门禁 + 清 CONTEXT 空占位 + 清杂物

- **Change ID**: health-cleanup-2026-07-08
- **关联**: `@.specs/health-cleanup-2026-07-08/CHANGE.md`（最短路径 · 跳 REQUIREMENT/DESIGN · 纯 bug 修复）

---

## 波次划分

```
Wave 1 (parallel): T01[P], T02[P], T03[P], T04[P]
```

> 4 个 task 改动文件互不重叠（`test/*.bats` / `Makefile` / `.specs/CONTEXT.md` / 杂物清理），全并行，无依赖。

---

## 任务清单

```xml
<task id="T01" parallel="true" status="pending">
  <name>修 test_package_flow_kit.bats setup 路径多退一层（L-025 同源 · 假绿）</name>
  <read_files>
    test/test_package_flow_kit.bats
    .specs/LESSONS.md
  </read_files>
  <write_files>
    test/test_package_flow_kit.bats
  </write_files>
  <action>
    setup() 里 REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)" 多退了一层。
    本测试位于 repo 根 test/（非 flow-kit-bundle/test/），到 repo 根只需一层 ..；
    flow-kit-bundle/test/ 里的测试才需 ../..（L-025 记录的正是那批），本文件误抄了 ../..。
    结果 PKG_SCRIPT 指向 /home/hellrabbit/unisoc/package-flow-kit.sh（缺 flow-kit/ 层）→ run exit 127 →
    AC-1/AC-2/AC-3 实际没在验证真文件（bats 1.13 把 127 降级为 BW01 warning，故假绿）。
    改 "../.." → ".."。
    已查阅 L-025：本次差异是「本文件在 repo 根 test/ 而非 flow-kit-bundle/test/」，故用 .. 而非 ../..。
  </action>
  <verify>npx bats test/test_package_flow_kit.bats 2>&1 | tail -15</verify>
  <done>bats 全过且无 BW01（exit 127）warning；AC-1/AC-2/AC-3 真正验证 package-flow-kit.sh</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true" status="pending">
  <name>修 make lint 检测失效 + 扩覆盖 pre-tool-use + 修 6 个 shellcheck error</name>
  <read_files>
    Makefile
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    flow-kit-bundle/lib/install_brooks.sh
    flow-kit-bundle/lib/install_brooks_tools.sh
    flow-kit-bundle/lib/install_core.sh
    flow-kit-bundle/lib/install_hooks.sh
    flow-kit-bundle/lib/install_skills.sh
  </read_files>
  <write_files>
    Makefile
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    flow-kit-bundle/lib/install_brooks.sh
    flow-kit-bundle/lib/install_brooks_tools.sh
    flow-kit-bundle/lib/install_core.sh
    flow-kit-bundle/lib/install_hooks.sh
    flow-kit-bundle/lib/install_skills.sh
  </write_files>
  <action>
    分两步：
    1) 修 Makefile lint 检测：当前 SHELLCHECK := $(shell which shellcheck) + ifdef 在本环境失效
       （RTK proxy 改写 which → $(shell which) 返回空 → ifdef 判未装 → 误报 not installed 而跳过）。
       shellcheck 实际已装 /usr/bin/shellcheck 0.9.0。改用可靠检测：先验证 `$(shell command -v shellcheck)`
       与 target 内 `if command -v shellcheck` 哪种在 make 子 shell 可靠，选其一。
       同时把 lint 扫描覆盖从 {*.sh, lib/*.sh, hooks/stop/*.sh, hooks/session-start/*.sh}
       扩到含 hooks/pre-tool-use/*.sh（independent-review-gate.sh 在此，当前漏扫）。
    2) 修 6 个 shellcheck error（仅 error 级；117 个 warning/info 不在本 change 范围，记 TECH-DEBT）：
       - 5 个 install_*.sh line 1（install_brooks / brooks_tools / core / hooks / skills）
       - independent-review-gate.sh:68
       逐个 `shellcheck -S error <file>` 看具体 SC 编号修复（line 1 多为 SC2148 shebang 类，1-2 行改）。
  </action>
  <verify>make lint</verify>
  <done>make lint 真跑 shellcheck（不再误报 not installed）；6 个 error 清零（shellcheck -S error 全仓 0）；lint 覆盖含 pre-tool-use/</done>
  <depends_on></depends_on>
</task>

<task id="T03" parallel="true" status="pending">
  <name>清 CONTEXT.md 抽象索引空占位章节（435 → ≤~410）</name>
  <read_files>
    .specs/CONTEXT.md
    .specs/ARCHITECTURE.md
  </read_files>
  <write_files>
    .specs/CONTEXT.md
  </write_files>
  <action>
    删「既有抽象索引」下 6 个空占位章节（各仅 3 行「模式:未发现 / 路径:未发现 / 示例:无」）：
    HTTP 客户端 / 数据库访问 / 状态管理 / 自定义 hooks（前端）/ 错误处理 / Schema 迁移。
    这些是 intel-scan 通用模板生成的占位，flow-kit 是 bash 项目不适用。
    保留有内容章节：工具函数（8 行）/ flow-kit 核心抽象（35 行）/ 命名约定（4 行）/ 禁动清单（39 行）。
    「技术债」章节（0 行空）若空也删。
    不改 templates/CONTEXT.md 模板本身（影响所有项目，超范围）。
  </action>
  <verify>wc -l .specs/CONTEXT.md && grep -c '禁动清单' .specs/CONTEXT.md</verify>
  <done>CONTEXT.md 行数明显下降（435 → ≤~410，趋近 400 目标）；禁动清单 + flow-kit 核心抽象内容完好保留</done>
  <depends_on></depends_on>
</task>

<task id="T04" parallel="true" status="pending">
  <name>清杂物残留（null/ 误建目录 + tmp/bak 文件）</name>
  <read_files>
    .specs/null/.goal-snapshot.json
  </read_files>
  <write_files>
    （仅删除，无写入）
  </write_files>
  <action>
    删 4 项杂物（删前 git status 确认 untracked / 非修改中）：
    - .specs/null/（含 .goal-snapshot.json · change_id=null 时误写的 goal 快照 · 当前 goal=null 残留）
    - .specs/STATE.md.tmp（临时文件残留）
    - .specs/health/tmp/（health 巡检临时目录）
    - .specs/CONTEXT.md.bak-2026-07-08（M-health 巡检备份未清）
  </action>
  <verify>test ! -e .specs/null -a ! -e .specs/STATE.md.tmp -a ! -e .specs/health/tmp -a ! -e .specs/CONTEXT.md.bak-2026-07-08 && echo "✅ 杂物已清"</verify>
  <done>4 项杂物全部删除；git status 不含这些 untracked 文件</done>
  <depends_on></depends_on>
</task>
```

---

## 状态字段说明

- `status="pending"` — 未开始
- `status="in_progress"` — 进行中（同时只允许一个非 [P] 任务为此状态）
- `status="done"` — 已完成（verify 通过）
- `status="blocked"` — 阻塞（必须在下方「阻塞日志」记录）

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
