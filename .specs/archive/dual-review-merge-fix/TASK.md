# TASK: L2/L3 双层审查结果合并写入

- **Change ID**: `dual-review-merge-fix`
- **关联**: `@.specs/dual-review-merge-fix/REQUIREMENT.md`、`@.specs/dual-review-merge-fix/DESIGN.md`

---

## 波次划分

```
Wave 1 (parallel): T01[P], T02[P], T03[P], T04[P], T05[P]  — 所有文件独立，无共享写入
Wave 2:            T06（bats 测试）                           — depends on T01-T05
Wave 3:            T07（全量回归 + 打包校验）                  — depends on T06
```

---

## 任务清单

```xml
<task id="T01" parallel="true" status="pending">
  <name>修复 29-independent-review.sh：L2-wait gating + L3-only skipped 默认值</name>
  <read_files>
    flow-kit-bundle/hooks/stop/29-independent-review.sh
    flow-kit-bundle/hooks/stop/lib/common.sh
    flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    flow-kit-bundle/hooks/stop/lib/done-validation.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/29-independent-review.sh
  </write_files>
  <action>
    D1（L2-wait gating）：在 Gate 4（幂等检查）之后、L3 调用之前，新增检查：
    - 读 gate_config 的当前阶段值（沿用 fk_independent_review_gate_active()）
    - 若 gate_config="both" 且 INDEPENDENT-REVIEW-&lt;N&gt;.md 缺少 "## L2 盲审" 段
      → 输出 "[independent-review] L3 skipped (L2 not yet complete, gate_config=both)" 
      → exit 0（不调 l3_review_run，不写 .done）
    
    D2（L3-only 默认值修正）：在提取 L2_verdict 段（line 78-82），当 gate_config="L3" 时：
    - l2_verdict 默认值从 "fail" 改为 "skipped"
    - gate_config="both" 时保持 "fail"（保守默认）

    沿用：fk_independent_review_gate_active() 的 tier 判定（done-validation.sh）、
    l3-review.sh 的追加写入逻辑、common.sh 的 module_enabled/config_get
  </action>
  <verify>grep -q "L2 not yet complete" hooks/stop/29-independent-review.sh &amp;&amp; grep -q 'l2_verdict.*skipped' hooks/stop/29-independent-review.sh &amp;&amp; echo "OK"</verify>
  <done>AC-1（both 模式 L3 等 L2）+ AC-7（L3-only L2_verdict=skipped）对应的 hook 层代码已修改</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true" status="pending">
  <name>修复 l3-review.sh：both 模式 L2 未完成时不写 .done</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    flow-kit-bundle/hooks/stop/lib/done-validation.sh
    flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
  </write_files>
  <action>
    D3（both 模式 .done 门控）：
    - l3_review_run() 新增第 5 个参数：gate_config_value（"L2"|"L3"|"both"）
    - 在写入 L3 段到 review 文件后、写 .done 前，检查：
      若 gate_config_value="both" 且 review 文件中 L2 段不存在
      → 仅写 L3 段（追加模式），不写 .done，返回 0
      → 输出 "[l3-review] L3 content appended but .done deferred (L2 not yet complete, gate_config=both)"
    
    参数向后兼容：第 5 参数为空时默认 "both"（保守），保持现有 Stop hook 调用不变。

    沿用：既有 awk 剥离 + >> 追加逻辑（line 174-198，已正确处理）、
    6 键 KVP .done 写入格式（line 225-252）、
    原子 tmp→mv 写入（line 249）
  </action>
  <verify>grep -q "L2 not yet complete" flow-kit-bundle/hooks/stop/lib/l3-review.sh &amp;&amp; grep -q "deferred" flow-kit-bundle/hooks/stop/lib/l3-review.sh &amp;&amp; grep -q "&gt;&gt;" flow-kit-bundle/hooks/stop/lib/l3-review.sh &amp;&amp; echo "OK"</verify>
  <done>AC-4（both 模式仅一方完成时不写 .done）+ AC-3（L3 append 逻辑保持不变）对应的 l3-review.sh 代码已修改</done>
  <depends_on></depends_on>
</task>

<task id="T03" parallel="true" status="pending">
  <name>修复 independent-review-gate.sh：PreToolUse forward 分支 L2-wait</name>
  <read_files>
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    flow-kit-bundle/hooks/stop/lib/done-validation.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
  </write_files>
  <action>
    D1 PreToolUse 路径（AC-1 要求覆盖双执行点）：
    在 forward 分支的 L3 前置调用前（line 189-216），增加：
    - 读 gate_config 的当前阶段值
    - 若 gate_config="both" 且 review 文件缺少 "## L2 盲审" 段
      → 输出 "[independent-review-gate] L3 front-loading skipped (L2 not yet complete, gate_config=both)"
      → 继续 deny（不调 l3_review_with_timeout，阻断 transition）
    - 若 gate_config ≠ "both" 或 L2 段存在 → 继续现有 L3 前置逻辑

    沿用：_fk_phase_direction() 方向判定、is_phase_write() 检测、
    fk_independent_review_gate_active() 的 gate 判定、
    l3_review_with_timeout() 的同步 L3 调用
  </action>
  <verify>grep -q "L2 not yet complete" flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh &amp;&amp; echo "OK"</verify>
  <done>AC-1 的 PreToolUse 执行点已加 L2-wait 检查</done>
  <depends_on></depends_on>
</task>

<task id="T04" parallel="true" status="pending">
  <name>修复 L2-blind-review.md：明确追加写入语义</name>
  <read_files>
    flow-kit-bundle/flow-kit/prompts/independent/L2-blind-review.md
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/prompts/independent/L2-blind-review.md
  </write_files>
  <action>
    D4（L2 append-first 策略）：
    在 "## 与主 agent 的关系" 段末尾新增 "## 文件写入约束" 段：
    - 若 INDEPENDENT-REVIEW-&lt;N&gt;.md 已存在：
      1. 先用 Read 工具读取全文
      2. 将你的 L2 段追加到文件末尾（不覆盖已有内容，尤其是已有的 L3 段）
      3. 在 L2 段开头加分隔符 "---" 与上文区分
    - 若文件不存在：新建，首行加 "# 独立审查 · 阶段 &lt;N&gt;"
    - 约束：禁止使用 Write 工具覆写已有文件——必须先读、后追加

    保留既有内容不变（独立性硬约束、四要素输出格式、各阶段 checklist）
  </action>
  <verify>grep -q "文件写入约束" flow-kit-bundle/flow-kit/prompts/independent/L2-blind-review.md &amp;&amp; grep -q "先读、后追加" flow-kit-bundle/flow-kit/prompts/independent/L2-blind-review.md &amp;&amp; echo "OK"</verify>
  <done>AC-2（L2 追加写入不覆写 L3）对应的固化盲审指令已修改</done>
  <depends_on></depends_on>
</task>

<task id="T05" parallel="true" status="pending">
  <name>修复 6 个阶段 prompt：L2 调度段 append + L2-only KVP .done</name>
  <read_files>
    flow-kit-bundle/flow-kit/prompts/1-requirement.md
    flow-kit-bundle/flow-kit/prompts/2-design.md
    flow-kit-bundle/flow-kit/prompts/3-task.md
    flow-kit-bundle/flow-kit/prompts/5-test.md
    flow-kit-bundle/flow-kit/prompts/6-review.md
    flow-kit-bundle/flow-kit/prompts/7-integration.md
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/prompts/1-requirement.md
    flow-kit-bundle/flow-kit/prompts/2-design.md
    flow-kit-bundle/flow-kit/prompts/3-task.md
    flow-kit-bundle/flow-kit/prompts/5-test.md
    flow-kit-bundle/flow-kit/prompts/6-review.md
    flow-kit-bundle/flow-kit/prompts/7-integration.md
  </write_files>
  <action>
    每个阶段 prompt 的 "独立 review 调度" 段做两处修改：

    A. L2 调度段（输出指令）：在 "输出" 行末尾追加：
    "若文件已存在（含 L3 段），先读全文，将 L2 段追加到末尾再 Write；禁止直接覆写已有文件。"
    与 T04 的 L2-blind-review.md append-first 指令一致。

    B. "写 done" 段：替换 touch 指令为条件分支：
    - gate_config="both" 或 "L3"：done 由 l3-review.sh 写入（无需主 agent 操作）
    - gate_config="L2"（仅 L2）：主 agent 写 6 键 KVP .done：
      ```bash
      cat &gt; .specs/&lt;id&gt;/.independent-review-&lt;N&gt;.done &lt;&lt;'DONE_EOF'
      phase=&lt;N&gt;
      change_id=&lt;id&gt;
      written_by=main-agent
      L2_verdict=&lt;pass|fail，从 review 文件提取&gt;
      L3_verdict=skipped
      artifacts=REQUIREMENT.md,CHANGE.md,INDEPENDENT-REVIEW-&lt;N&gt;.md
      DONE_EOF
      ```

    6 个文件改动完全一致，按阶段号替换 &lt;N&gt; 和 artifacts 列表。
    沿用：各 prompt 的既有 L2/L3 调度结构、done-validation.sh 的 KVP 格式
  </action>
  <verify>for f in 1-requirement 2-design 3-task 5-test 6-review 7-integration; do
  grep -q "L2_verdict" flow-kit-bundle/flow-kit/prompts/$f.md &amp;&amp; \
  grep -q "L3_verdict=skipped" flow-kit-bundle/flow-kit/prompts/$f.md &amp;&amp; \
  grep -q "追加" flow-kit-bundle/flow-kit/prompts/$f.md || { echo "FAIL: $f"; exit 1; }
done &amp;&amp; echo "OK: all 6 prompts"</verify>
  <done>AC-6（L2-only KVP .done）+ AC-2（append 指令）对应的 6 个 prompt 已全部修改</done>
  <depends_on></depends_on>
</task>

<task id="T06" parallel="false" status="pending">
  <name>编写 bats 测试：覆盖 AC-1~AC-8 三种模式</name>
  <read_files>
    test/test_common.bats
    hooks/stop/lib/done-validation.sh
    hooks/stop/lib/l3-review.sh
    hooks/stop/29-independent-review.sh
    hooks/pre-tool-use/independent-review-gate.sh
  </read_files>
  <write_files>
    test/test_dual_review_merge.bats
  </write_files>
  <action>
    新增 test/test_dual_review_merge.bats，覆盖：

    AC-1（both L2-wait）：模拟 gate_config=both + 无 L2 段 → L3 跳过
    AC-2（L2 append）：模拟已有 L3 段 → L2 追加后 L3 段仍在
    AC-3（L3 append）：模拟已有 L2 段 → L3 追加后 L2 段仍在
    AC-4（both .done defer）：模拟仅 L2 完成 → .done 不存在
    AC-6（L2-only KVP .done）：模拟 gate_config=L2 → .done 含 L3_verdict=skipped
    AC-7（L3-only skipped）：模拟 gate_config=L3 + 无 L2 → .done L2_verdict=skipped
    AC-8（value domain）：空 .done → fk_validate_done_marker 返回 2；skipped 值域 → 返回 0

    测试策略：mock 函数隔离（不依赖实际 API 调用），用 fixture 目录 + 临时 .flow-active 模拟 gate_config 状态。
    沿用：test_common.bats 的 setup/teardown 模式、bats-assert 风格
  </action>
  <verify>set -o pipefail; npx bats test/test_dual_review_merge.bats --formatter tap 2&gt;&amp;1 | tail -5; exit $?</verify>
  <done>所有新增 bats 测试通过，AC-1~AC-8 全覆盖</done>
  <depends_on>T01, T02, T03, T04, T05</depends_on>
</task>

<task id="T07" parallel="false" status="pending">
  <name>全量回归测试 + 打包校验</name>
  <read_files>
    test/
    Makefile
    package-flow-kit.sh
  </read_files>
  <write_files>
  </write_files>
  <action>
    1. 运行全量 bats：`npx bats test/` — 确保无回归（346 tests 全部通过）
    2. 运行 make lint：`make lint` — shellcheck 无新 error
    3. 运行打包校验：`bash package-flow-kit.sh --validate` — 新文件在 Part 清单中
    4. 若 test_dual_review_merge.bats 未在 Part 中，追加到 package-flow-kit.sh 的 test 文件列表
  </action>
  <verify>set -o pipefail; npx bats test/ 2&gt;&amp;1 | tail -3 &amp;&amp; make lint 2&gt;&amp;1 | tail -3</verify>
  <done>全量测试通过 + lint 通过 + 打包校验通过（AC-1~AC-8 全覆盖且无回归）</done>
  <depends_on>T06</depends_on>
</task>
```

---

## 状态字段说明

- `status="pending"` — 未开始
- `status="in_progress"` — 进行中（同时只允许一个非 [P] 任务为此状态）
- `status="done"` — 已完成（verify 通过）
- `status="blocked"` — 阻塞（必须在文件末尾「阻塞日志」记录）

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
