# TASK: quality-baseline

- **Change ID**: `quality-baseline`
- **关联**: `@.specs/quality-baseline/REQUIREMENT.md`、`@.specs/quality-baseline/DESIGN.md`
- **总计**: 7 tasks / 2 waves

---

## 波次划分

```
Wave 1 (parallel): T01[P] E-协议DRY  T02[P] F-Makefile  T03[P] G-smoke  T04[P] H-shellcheck  T05[P] I-test双源
Wave 2:            T06 bats测试  T07 docs
```

---

<task id="T01" parallel="true">
  <name>E：提取 pipeline-gates.md + check-gate-sync.sh + 4-dev 引用</name>
  <read_files>
    flow-kit-bundle/flow-kit/prompts/4-dev.md
    flow-kit-bundle/skills/flow-dev/SKILL.md
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/reference/pipeline-gates.md
    flow-kit-bundle/flow-kit/reference/check-gate-sync.sh
    flow-kit-bundle/flow-kit/prompts/4-dev.md
    flow-kit-bundle/skills/flow-dev/SKILL.md
  </write_files>
  <action>
    ① 创建 flow-kit/reference/pipeline-gates.md：提取 4-dev prompt 和 flow-dev skill 的共享 toll-gate 协议内容（PCSC 自检表 + auto_advance 分支 + Pipeline Toll-Gate 段），写成独立 markdown 片段。格式：`# Pipeline Toll-Gate 共享协议` + 各子段。

    ② 创建 flow-kit/reference/check-gate-sync.sh：校验脚本，diff 4-dev prompt 和 flow-dev skill 的 toll-gate 段（从 PCSC 到 Pipeline Toll-Gate 结束），一致 exit 0，漂移 exit 1 + 列出差异行号。

    ③ 更新 4-dev.md 和 flow-dev/SKILL.md：在 PCSC 自检表上方加一行 `> @see flow-kit/reference/pipeline-gates.md`，然后精简两文件中的重复协议段为引用注释（保留具体内容，加注释标注"协议源见 pipeline-gates.md"）。

    按 DESIGN D1/D2：首批仅做 4-dev，硬校验兜底。
  </action>
  <verify>test -f flow-kit-bundle/flow-kit/reference/pipeline-gates.md && test -f flow-kit-bundle/flow-kit/reference/check-gate-sync.sh && bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh; echo "exit=$?"</verify>
  <done>pipeline-gates.md 可被引用，check-gate-sync.sh 确认 4-dev prompt↔skill 一致</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true">
  <name>F：创建 Makefile + pre-push hook</name>
  <read_files>
    package-flow-kit.sh
  </read_files>
  <write_files>
    Makefile
    .git/hooks/pre-push
  </write_files>
  <action>
    ① 创建项目根 Makefile（方案 A）：
       - test: npx bats test/
       - lint: shellcheck -e SC1091 *.sh flow-kit-bundle/lib/*.sh flow-kit-bundle/hooks/stop/*.sh
       - check: test + lint + bash package-flow-kit.sh --validate + diff -rq test/ flow-kit-bundle/test/
       - all: check
       每个 target 用 @echo 标注步骤名。

    ② 创建 .git/hooks/pre-push：
       ```bash
       #!/bin/bash
       echo "🔍 pre-push: running make check..."
       make check
       ```
       加 chmod +x。
  </action>
  <verify>make test 2>&1 | grep -c "ok" && make check 2>&1 | tail -5</verify>
  <done>make test/lint/check/all 可用，pre-push hook 可执行</done>
  <depends_on></depends_on>
</task>

<task id="T03" parallel="true">
  <name>G：stop 链主脚本 smoke test</name>
  <read_files>
    flow-kit-bundle/hooks/stop/22-git.sh
    flow-kit-bundle/hooks/stop/24-session.sh
    flow-kit-bundle/hooks/stop/26-workflow.sh
    flow-kit-bundle/hooks/stop/99-report.sh
    flow-kit-bundle/hooks/stop/lib/common.sh
    flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh
  </read_files>
  <write_files>
    test/test_stop_chain.bats
  </write_files>
  <action>
    创建 test/test_stop_chain.bats，覆盖 4 个主脚本：
    - 22-git.sh: source 不报错 + has_git() 函数存在
    - 24-session.sh: source 不报错 + main() 函数存在
    - 26-workflow.sh: source 不报错 + get_workflow_state() 函数存在
    - 99-report.sh: source 不报错 + generate_report() 函数存在

    每个测试仅 source 脚本（在 subshell 中），检查 exit code = 0，不实际调用 main。
    按 DESIGN D5：轻量 smoke test，不 mock 外部状态。
  </action>
  <verify>npx bats test/test_stop_chain.bats --formatter tap</verify>
  <done>4 个 stop 链主脚本 source 不报错 + 关键函数存在</done>
  <depends_on></depends_on>
</task>

<task id="T04" parallel="true">
  <name>H：shellcheck 集成 + make lint</name>
  <read_files>
    flow-kit-bundle/lib/*.sh
    flow-kit-bundle/hooks/stop/*.sh
    flow-kit-bundle/hooks/session-start/*.sh
  </read_files>
  <write_files>
    Makefile
  </write_files>
  <action>
    ① 确认 shellcheck 可用（`which shellcheck || apt install -y shellcheck`）。
       shellcheck 不可用时 make lint 输出 WARNING 而非阻断。

    ② 在 Makefile 的 lint target 中：
       - shellcheck -e SC1091 *.sh
       - shellcheck -e SC1091 flow-kit-bundle/lib/*.sh
       - shellcheck -e SC1091 flow-kit-bundle/hooks/stop/*.sh
       - shellcheck -e SC1091 flow-kit-bundle/hooks/session-start/*.sh
       - 过滤输出：仅 error 级别；warning/style 通过但不阻断
       - grep -c "error" 输出，>0 则 exit 1

    ③ 按 DESIGN D6：仅 error 级别阻断，-e SC1091 忽略未跟踪 source。
  </action>
  <verify>make lint 2>&1; echo "exit=$?"</verify>
  <done>make lint 执行 shellcheck error 级别检查</done>
  <depends_on></depends_on>
</task>

<task id="T05" parallel="true">
  <name>I：test 双源 diff 集成到 make check</name>
  <read_files>
    test/
    flow-kit-bundle/test/
  </read_files>
  <write_files>
    Makefile
  </write_files>
  <action>
    在 Makefile 的 check target 中添加 test 双源一致性校验步骤：
    ```makefile
    check-test-sync:
    	@echo "🔍 test 双源一致性..."
    	@diff -rq test/ flow-kit-bundle/test/ || { echo "❌ test/ 与 flow-kit-bundle/test/ 不一致！"; exit 1; }
    	@echo "✅ test 双源一致"
    ```
    check target 依赖加 check-test-sync。
    如果 flow-kit-bundle/test/ 不存在（旧版 bundle），跳过并输出 WARNING。
  </action>
  <verify>diff -rq test/ flow-kit-bundle/test/ 2>&1; echo "exit=$?"</verify>
  <done>make check 包含 test 双源一致性检查</done>
  <depends_on></depends_on>
</task>

---

<task id="T06">
  <name>bats 测试：覆盖 AC-1~AC-7</name>
  <read_files>
    .specs/quality-baseline/REQUIREMENT.md
    Makefile
    flow-kit-bundle/flow-kit/reference/pipeline-gates.md
    flow-kit-bundle/flow-kit/reference/check-gate-sync.sh
  </read_files>
  <write_files>
    test/test_quality_baseline.bats
  </write_files>
  <action>
    创建 test/test_quality_baseline.bats：
    - AC-1: grep pipeline-gates.md 引用 in 4-dev prompt + skill
    - AC-2: bash check-gate-sync.sh exit 0
    - AC-3: make test / make lint / make check exit 0（或 skip 如 shellcheck 未装）
    - AC-4: test -x .git/hooks/pre-push && grep "make check"
    - AC-5: npx bats test/test_stop_chain.bats（T03 产出）
    - AC-6: shellcheck error count = 0（或 skip 如 shellcheck 未装）
    - AC-7: diff -rq test/ flow-kit-bundle/test/ exit 0
  </action>
  <verify>npx bats test/test_quality_baseline.bats --formatter tap</verify>
  <done>7 条 AC 全部有测试覆盖且通过</done>
  <depends_on>T01 T02 T03 T04 T05</depends_on>
</task>

<task id="T07">
  <name>文档收尾：CONTEXT + CHANGELOG 更新</name>
  <read_files>
    .specs/CONTEXT.md
    .specs/CHANGELOG.md
  </read_files>
  <write_files>
    .specs/CONTEXT.md
    .specs/CHANGELOG.md
  </write_files>
  <action>
    ① CONTEXT.md 术语表追加：pipeline-gates.md、check-gate-sync.sh、make check、pre-push hook、shellcheck。
    ② CONTEXT.md 已锁决策追加 E/D1/D2/D3 决策。
    ③ CHANGELOG.md 追加 quality-baseline 行。
  </action>
  <verify>grep -c "quality-baseline" .specs/CHANGELOG.md && grep -c "pipeline-gates\|check-gate-sync\|shellcheck\|Makefile" .specs/CONTEXT.md</verify>
  <done>CONTEXT.md 术语/决策更新，CHANGELOG 已追加</done>
  <depends_on>T06</depends_on>
</task>
