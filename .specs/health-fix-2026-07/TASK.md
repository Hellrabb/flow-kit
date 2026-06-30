# TASK: package-flow-kit.sh 孤儿 fi 修复 + bash -n 门禁加固

- **Change ID**: health-fix-2026-07
- **创建日期**: 2026-07-01
- **路径**: 最短（TASK → DEV → TEST → REVIEW → INTEGRATION）

## 波次划分

```
Wave 1 (parallel): T01[P] 删死代码, T04[P] flow-health 文档增补
Wave 2 (parallel): T02[P] package 回归测试 (depends T01), T03[P] 全量 bash -n smoke (depends T01)
```

依赖图（无环）：
```
T01 ──┬──> T02
      └──> T03
T04（独立）
```

> T02/T03 都依赖 T01：它们 assert `package-flow-kit.sh` 的语法合法，必须先删掉孤儿 `fi`。T04 是纯文档改动，不跑测试，与 T01 并行无冲突。

---

## 任务清单

```xml
<task id="T01" parallel="true" status="done">
  <name>删除 package-flow-kit.sh:581-587 孤儿 fi 残留碎片</name>
  <read_files>
    package-flow-kit.sh
    .specs/health-fix-2026-07/CHANGE.md
  </read_files>
  <write_files>
    package-flow-kit.sh
  </write_files>
  <action>
    删除 package-flow-kit.sh 末尾的 validate_staging_coverage() 残留碎片（581-587 行）：
    - 残留注释 `# validate_staging_coverage() — 校验 Part A~G staging 指令覆盖完整性`
    - `echo ""` / `echo "   ✅ 校验通过：所有文件均被 Part A~G 覆盖。"`（假成功输出）
    - `exit 0`
    - 孤儿 `fi`（无匹配 if）
    - 孤儿 `}`
    保留第 579 行 banner 结尾 `╝"` 与第 580 空行作为文件自然结尾。
    严禁触碰顶部 19-139 行的 validate_staging_coverage() 完整定义（--validate 功能依赖）。
    严禁顺手改其他部分。
  </action>
  <verify>bash -n package-flow-kit.sh && echo "AC-1 OK"</verify>
  <done>bash -n 零语法错误（对应 AC-1）；末尾不再是孤儿 fi/}。</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true" status="done">
  <name>新建 test/test_package_flow_kit.bats 回归测试（AC-1/2/3）</name>
  <read_files>
    package-flow-kit.sh
    test/test_quality_baseline.bats
    test/test_stop_chain.bats
    .specs/health-fix-2026-07/REQUIREMENT.md
  </read_files>
  <write_files>
    test/test_package_flow_kit.bats
  </write_files>
  <action>
    新建 bats 文件，沿用 test_quality_baseline.bats 的 @test/run/[ status ] 写法约定。至少 3 个用例：
    (1) AC-1：`run bash -n package-flow-kit.sh` → `[ "$status" -eq 0 ]`。
    (2) AC-2 语法结构断言：`run tail -n 10 package-flow-kit.sh` → 输出不含孤立的 `fi`/`}` 行；
        且 `run grep -c '✅ 校验通过：所有文件均被 Part A~G' package-flow-kit.sh` → 仅命中顶部函数内的合法出现（≤1，而非函数尾 + 文件尾双份）。
        注：完整端到端打包（Part F git archive + Part G npm pack）依赖网络/缓存，**自动化 bats 不跑真打包**，
        完整打包退出码留给 TEST 阶段手动 UAT（见 DESIGN D3）。
    (3) AC-3：`run bash package-flow-kit.sh --validate` → `[ "$status" -ne 2 ]`（退出 2=脚本错误才算失败；0/1 均正常）。
    沿用 test_stop_chain.bats 的临时目录手法（如需）。
  </action>
  <verify>bats test/test_package_flow_kit.bats</verify>
  <done>3 个用例全过（对应 AC-1/2/3 自动化部分）。</done>
  <depends_on>T01</depends_on>
</task>

<task id="T03" parallel="true" status="done">
  <name>新建 test/test_smoke_syntax.bats 全量 bash -n 门禁（AC-4）</name>
  <read_files>
    test/test_quality_baseline.bats
    .specs/health-fix-2026-07/REQUIREMENT.md
  </read_files>
  <write_files>
    test/test_smoke_syntax.bats
  </write_files>
  <action>
    新建 bats 文件。遍历所有生产 .sh 脚本，对每个断言 `bash -n` 退出 0。
    扫描范围（与 find 一致，排除第三方）：
      .claude/hooks/**/*.sh
      flow-kit-bundle/hooks/**/*.sh
      flow-kit-bundle/flow-kit/reference/*.sh
      flow-kit-bundle/flow-kit/regression-demos/*/check.sh
      flow-kit-bundle/lib/*.sh
      flow-kit-bundle/install.sh
      package-flow-kit.sh
    排除：brooks-lint/、brooks-tools/、.claude/plugins/、node_modules/、.git/
    实现：用 `find ... -print0 | while read -d ''` 在 setup 或单个 @test 里遍历，
      对每个文件 `run bash -n "$f"`，失败则打印文件名并 fail。
      推荐单 @test "all shell scripts pass bash -n" 聚合，失败信息含具体文件路径。
    沿用既有 bats 风格（test_quality_baseline.bats）。
  </action>
  <verify>bats test/test_smoke_syntax.bats</verify>
  <done>全量 smoke 通过：所有生产 .sh 的 bash -n 退出 0（对应 AC-4）。
    若有个别边角脚本暴露语法问题，作为本 change 附带修复项直接修（不另开 change），并在阻塞日志记录。</done>
  <depends_on>T01</depends_on>
</task>

<task id="T04" parallel="true" status="done">
  <name>flow-health SKILL.md 增补「bash -n 全量语法门禁」步骤（AC-5）</name>
  <read_files>
    flow-kit-bundle/skills/flow-health/SKILL.md
    .specs/health/2026-07-01-HEALTH.md
  </read_files>
  <write_files>
    flow-kit-bundle/skills/flow-health/SKILL.md
  </write_files>
  <action>
    在 flow-kit-bundle/skills/flow-health/SKILL.md（项目内源 · 与全局 ~/.claude 一致 · 改此进 git，
    打包分发时同步全局）增补：
    1. 在「步骤 2.5 冗余巡检」之后、「步骤 3 未装 brooks-lint」之前，新增「步骤 2.6 · 全量 bash -n 语法门禁」段：
       - 命令：`find . -name '*.sh' -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/brooks-lint/*' -not -path '*/brooks-tools/*' -not -path '*/.claude/plugins/*' -exec bash -n {} \;`
       - 判定：任一脚本语法错误 → 🔴 Critical（语法错误 = 脚本不可用，阻断 CI/自动化）
       - 写入健康报告「6 维生产代码风险」前的「语法门禁」小节
       - 说明来由：2026-06-30 健康报告 89/100 漏检 package-flow-kit.sh 孤儿 fi，根因是巡检流程无 bash -n 门禁
    2. 在文末「自检」清单加一条：`[ ] 步骤 2.6 bash -n 全量语法门禁已跑（任一错误 → 🔴 Critical）`
    不动其他步骤。保持 Markdown 结构与既有风格一致。
  </action>
  <verify>test "$(grep -c 'bash -n' flow-kit-bundle/skills/flow-health/SKILL.md)" -ge 2 &amp;&amp; echo "AC-5 OK"</verify>
  <done>SKILL.md 命中 bash -n ≥ 2（步骤段 + 自检条目）；新增步骤 2.6 存在（对应 AC-5）。</done>
  <depends_on></depends_on>
</task>
```

---

## 状态字段说明

- `status="pending"` —— 待执行（4-dev 阶段逐个领走）
- 完成后改为 `done`，阻塞改 `blocked` 并在「阻塞日志」记录

## 阻塞日志

> 执行中遇到阻碍时记录（任务 id + 原因 + 处置）。初始为空。

- **T02/T03 · review 发现（已处置）**：新增 `test/test_package_flow_kit.bats` + `test/test_smoke_syntax.bats` 后，`AC-7 (test/ 与 flow-kit-bundle/test/ 一致)` 首跑失败 —— TASK 拆解时漏了 `flow-kit-bundle/test/` 镜像同步约定（package-flow-kit.sh 打包要求 test/ 双份）。处置：`cp` 两文件到 `flow-kit-bundle/test/`，重跑 bats 181/181 全绿。**流程改进**：未来 3-task 新增 `test/*.bats` 时，write_files 应同时列 `test/` 与 `flow-kit-bundle/test/` 两份；或 3-task prompt 加「镜像文件检查」提示。

## Fix 任务（来自 REVIEW / INTEGRATION）

> 此区域由 review/integration 阶段自动追加，编号 `T-FIX-XX`。

```xml
<!-- 占位 -->
```
