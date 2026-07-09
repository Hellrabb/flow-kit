# TASK: TD-010 jscpd 工具化 + TD-002 stop 链覆盖核实/补

- **Change ID**: td-test-infra
- **关联**: `@.specs/td-test-infra/REQUIREMENT.md`、`@.specs/td-test-infra/DESIGN.md`
- **总任务**: 4（Wave 1 并行 2 + Wave 2 串行 1 + Wave 3 串行 1）

## 波次划分

```
Wave 1 (parallel): T01[P], T02[P]
Wave 2:            T03 (depends on T02)
Wave 3:            T04 (depends on T01, T02, T03)
```

## 任务

```xml
<task id="T01" parallel="true">
  <name>Makefile 加 dup target（TD-010 · AC-1）</name>
  <read_files>
    Makefile
  </read_files>
  <write_files>
    Makefile
  </write_files>
  <action>
    在 Makefile 加 `dup:` target（独立，不进 `check` 依赖）。recipe：`command -v jscpd` 探测 → 已装则 `jscpd flow-kit-bundle/ --ignore '**/brooks-lint/**,**/brooks-tools/**,**/test/**,**/regression-demos/**'`（结果走 stdout，exit 0）；未装则 stderr 提示 + exit 0。沿用既有 `@`+`command -v` 范式（test/lint target）。
  </action>
  <verify>make dup; echo "exit=$?"; awk '/^dup:/{f=1;next} f&&/^[^[:space:]#].*:[^=]/{f=0} f' Makefile | grep -q -- '--ignore' && awk '/^dup:/{f=1;next} f&&/^[^[:space:]#].*:[^=]/{f=0} f' Makefile | grep -q brooks-lint && awk '/^dup:/{f=1;next} f&&/^[^[:space:]#].*:[^=]/{f=0} f' Makefile | grep -q brooks-tools && awk '/^dup:/{f=1;next} f&&/^[^[:space:]#].*:[^=]/{f=0} f' Makefile | grep -q '/test/' && awk '/^dup:/{f=1;next} f&&/^[^[:space:]#].*:[^=]/{f=0} f' Makefile | grep -q regression-demos</verify>
  <done>make dup exit 0（已装扫描/未装 skip）+ dup recipe 含 --ignore + brooks-lint/brooks-tools/regression-demos 模式（AC-1）</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true">
  <name>生成 TD-002 覆盖表 SUMMARY.md（AC-2）</name>
  <read_files>
    test/test_stop_chain.bats
    test/test_smoke_syntax.bats
    test/*.bats
    flow-kit-bundle/hooks/stop/*.sh
    .specs/td-test-infra/REQUIREMENT.md
  </read_files>
  <write_files>
    .specs/td-test-infra/SUMMARY.md
  </write_files>
  <action>
    读 test_stop_chain.bats（已覆盖 22/24/26/99 的 bash-n+shebang+grep 关键函数 · 内容层）+ test_smoke_syntax.bats（全 bash-n · 语法层已全覆盖 17 脚本）。grep stop 脚本目录确认哪些主脚本已有 grep 关键函数 smoke。生成 17 行覆盖表（列：脚本名 | 分类[business/coord/aggrep] | 状态[covered/partial/gap] | 对应 test 文件:行号）。covered=有 grep 关键函数 smoke / partial=仅 bash-n / gap=无。
  </action>
  <verify>test -f .specs/td-test-infra/SUMMARY.md && [ "$(grep -cE '^\| (00-|01-|2[0-9]-|3[0-9]-|99-)[a-z-]+ \| (business|coord|aggrep) \| (covered|partial|gap) \|' .specs/td-test-infra/SUMMARY.md)" -eq 17 ]</verify>
  <done>SUMMARY.md 含 17 行覆盖表（脚本名+分类+covered/partial/gap+test 引用）（AC-2）</done>
  <depends_on></depends_on>
</task>

<task id="T03" parallel="false">
  <name>给 [business] 缺口补 bash-n+grep smoke（AC-3 · 条件性）</name>
  <read_files>
    .specs/td-test-infra/SUMMARY.md
    test/test_stop_chain.bats
    flow-kit-bundle/hooks/stop/*.sh
  </read_files>
  <write_files>
    test/test_stop_chain.bats
    flow-kit-bundle/test/test_stop_chain.bats
  </write_files>
  <action>
    基于 T02 的 SUMMARY，给标 [business]+[partial/gap] 的脚本（缺 grep 关键函数 smoke 者）补 smoke（bash -n + shebang + grep 关键函数名），沿用 test_stop_chain.bats 既有范式（**非 source** · D2）。双源同步（test/ + flow-kit-bundle/test/）。止损：若某脚本 grep 关键函数失败需改脚本逻辑 → skip + 注明 + 列 v2（AC-3 止损条款）。
  </action>
  <verify>npx bats test/test_stop_chain.bats && diff -r test/ flow-kit-bundle/test/</verify>
  <done>补的 smoke bats 全绿 + 双源 diff -r 一致（AC-3）</done>
  <depends_on>T02</depends_on>
</task>

<task id="T04" parallel="false">
  <name>CONTEXT 校准 + 全量回归（AC-4）</name>
  <read_files>
    .specs/CONTEXT.md
    Makefile
    .specs/td-test-infra/SUMMARY.md
  </read_files>
  <write_files>
    .specs/CONTEXT.md
  </write_files>
  <action>
    更新 CONTEXT TD-010（「已纳入 SOP」→「已固化为 make dup target」）+ TD-002（覆盖结论 + ✅）。全量 bats 回归确认无退化。
  </action>
  <verify>grep -E 'TD-010|TD-002' .specs/CONTEXT.md && npx bats test/</verify>
  <done>CONTEXT TD-010/002 校准 + bats test/ 全绿 exit 0（AC-4）</done>
  <depends_on>T01, T02, T03</depends_on>
</task>
```
