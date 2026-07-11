# TASK — L3 审计子系统健康修复

- **Change ID**: `health-fix-l3-2026-07`
- **关联**: `REQUIREMENT.md`（9 AC）、`DESIGN.md`（8 决策 + 7 图）

---

## 波次划分图

```
Wave 1 (基础设施 · 3 并行): T01[P] | T02[P] | T03[P]
Wave 2 (common.sh · 串行):   T04 (无依赖，独立文件)
Wave 3 (函数拆分 · 4 并行): T05[P] ← T04 | T06[P] ← T03 | T07[P] | T08[P]
Wave 4 (测试+回归 · 2 并行): T09[P] ← T06 | T10 ← T05..T09
```

## 任务清单

---

<task id="T01" parallel="true">
  <name>AC-2 解环：提取 correction-types.sh + 调整 source 依赖</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/correction-file.sh
    flow-kit-bundle/hooks/stop/lib/interactive-ui-check.sh
    flow-kit-bundle/hooks/stop/lib/weak-model-compliance.sh
    flow-kit-bundle/hooks/stop/lib/done-validation.sh
    flow-kit-bundle/hooks/stop/lib/common.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/correction-types.sh
    flow-kit-bundle/hooks/stop/lib/correction-file.sh
    flow-kit-bundle/hooks/stop/lib/interactive-ui-check.sh
    flow-kit-bundle/hooks/stop/lib/weak-model-compliance.sh
    flow-kit-bundle/hooks/stop/lib/done-validation.sh
  </write_files>
  <action>
    1. 新建 correction-types.sh（仅含 CORRECTION_TYPE_COMPLIANCE / CORRECTION_TYPE_INTERACTIVE_UI / CORRECTION_MAX_RETRY 三个 readonly 常量，零 source 外部依赖）
    2. 修改 interactive-ui-check.sh: 确认 source 改为 correction-types.sh（替代 correction-file.sh 的直接常量引用），保持 correction-file.sh 的函数调用不变
    3. 修改 weak-model-compliance.sh: 同上
    4. 修改 correction-file.sh: source correction-types.sh（如果它需要用到这些常量）
    5. 修改 done-validation.sh: source 路径从 correction-file.sh 调整为 correction-types.sh（被动变更）
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/lib/correction-types.sh && bash -n flow-kit-bundle/hooks/stop/lib/correction-file.sh && bash -n flow-kit-bundle/hooks/stop/lib/interactive-ui-check.sh && bash -n flow-kit-bundle/hooks/stop/lib/weak-model-compliance.sh && bash -n flow-kit-bundle/hooks/stop/lib/done-validation.sh && (grep -rl "source.*correction-file.sh" flow-kit-bundle/hooks/stop/lib/interactive-ui-check.sh flow-kit-bundle/hooks/stop/lib/weak-model-compliance.sh | grep -q . && echo "PASS: lib files still source correction-file.sh for I/O functions" || echo "INFO: check manually") && (for a in flow-kit-bundle/hooks/stop/lib/interactive-ui-check.sh flow-kit-bundle/hooks/stop/lib/weak-model-compliance.sh; do grep -q "source.*correction-file.sh" "$a" || { echo "FAIL: $a missing correction-file.sh source"; exit 1; }; done; echo "PASS: cross-source check OK")</verify>
  <done>AC-2: 三向依赖环消除，grep 交叉检测无相互引用，bash -n 全部通过</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true">
  <name>AC-6 DRY：创建 goal-parsing.md + 更新 6-review.md 和 7-integration.md</name>
  <read_files>
    flow-kit-bundle/flow-kit/prompts/6-review.md
    flow-kit-bundle/flow-kit/prompts/7-integration.md
    flow-kit-bundle/flow-kit/reference/pipeline-gates.md
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/reference/goal-parsing.md
    flow-kit-bundle/flow-kit/prompts/6-review.md
    flow-kit-bundle/flow-kit/prompts/7-integration.md
  </write_files>
  <action>
    1. 新建 goal-parsing.md：抽取 6-review 和 7-integration 中重复的 jq goal 解析逻辑（goal.scope / start_phase / current_phase / phases_done / gates），参考 pipeline-gates.md 的 @see 引用格式
    2. 修改 6-review.md：删除内联 jq goal 解析代码块，替换为 @see 引用 goal-parsing.md
    3. 修改 7-integration.md：同上
  </action>
  <verify>for f in flow-kit-bundle/flow-kit/prompts/6-review.md flow-kit-bundle/flow-kit/prompts/7-integration.md; do grep -q "goal.scope\|goal.current_phase\|goal.start_phase" "$f" && echo "FAIL: $f still contains jq goal parsing" && exit 1; done; echo "OK: both prompts cleaned"; make check 2>/dev/null || true</verify>
  <done>AC-6: 两个 prompt 不再含完整 jq goal 解析代码块，仅 @see 引用</done>
  <depends_on></depends_on>
</task>

<task id="T03" parallel="true">
  <name>AC-8 死代码 + self-sourcing 修复 + CONTEXT clean-up</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/transcript-parser.sh
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    flow-kit-bundle/hooks/stop/lib/interactive-ui-check.sh
    flow-kit-bundle/hooks/stop/lib/common.sh
    .specs/CONTEXT.md
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/transcript-parser.sh
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    .specs/CONTEXT.md
  </write_files>
  <action>
    1. 从 transcript-parser.sh 移除 estimate_tokens() 函数定义 + 关联注释块
    2. 修改 l3-review.sh:511：替换 source "$0" 为 source "$HOOK_BASE_DIR/lib/l3-review.sh" 绝对路径
    3. 确认 read_correction_file()（interactive-ui-check.sh）和 file_not_empty()（common.sh）无残留引用（TD-009 已于 2026-07-09 清理）
    4. 从 CONTEXT.md 清理窗口专列移除 3 条目（estimate_tokens / read_correction_file / file_not_empty）
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/lib/transcript-parser.sh && bash -n flow-kit-bundle/hooks/stop/lib/l3-review.sh && (grep -q 'source "\$0"' flow-kit-bundle/hooks/stop/lib/l3-review.sh && echo "FAIL: self-sourcing still present" && exit 1 || echo "PASS: no self-sourcing") && (for f in flow-kit-bundle/hooks/stop/lib/transcript-parser.sh flow-kit-bundle/hooks/stop/lib/interactive-ui-check.sh flow-kit-bundle/hooks/stop/lib/common.sh; do grep -Eq 'estimate_tokens|read_correction_file|file_not_empty' "$f" && echo "FAIL: $f contains dead function" && exit 1 || true; done; echo "PASS: dead functions cleared")</verify>
  <done>AC-8: self-sourcing 修复，estimate_tokens 移除，CONTEXT 清理窗口清空</done>
  <depends_on></depends_on>
</task>

---

<task id="T04">
  <name>AC-5 DRY：添加 PHASE_GATE_KEY_MAP + 替换 2 处硬编码</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/common.sh
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    flow-kit-bundle/hooks/stop/29-independent-review.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/common.sh
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    flow-kit-bundle/hooks/stop/29-independent-review.sh
  </write_files>
  <action>
    1. 在 common.sh 新增 declare -A PHASE_GATE_KEY_MAP（含 [1]="1-requirement" [2]="2-design" [3]="3-task" [5]="5-test" [6]="6-review" [7]="7-integration"），附注释说明 phase 0/4 有意排除及四层同步约束
    2. 替换 independent-review-gate.sh 中 2 处 case-esac phase_name 硬编码（L205-206 + L311-312）为 ${PHASE_GATE_KEY_MAP[$phase]:-}
    3. 检查 29-independent-review.sh 等其他文件是否有同类硬编码，如有则一并替换
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/lib/common.sh && bash -n flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh && npx bats test/test_common.bats --filter "PHASE_GATE_KEY_MAP\|phase_name" 2>/dev/null || npx bats test/test_common.bats</verify>
  <done>AC-5: PHASE_GATE_KEY_MAP 集中维护，至少 2 处硬编码替换为查表</done>
  <depends_on></depends_on>
</task>

---

<task id="T05" parallel="true">
  <name>AC-1 拆分 _gate_phase_transition() 122L → 3 子函数 + 编排器</name>
  <read_files>
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    flow-kit-bundle/hooks/stop/lib/l2-detect.sh
    flow-kit-bundle/hooks/stop/lib/done-validation.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
  </write_files>
  <action>
    按 DESIGN §2.2 拆分模式：
    1. 提取 _gate_check_l2() ~50L：L2 审查完成检测逻辑（review_md 存在性 + L2 section grep + skip_marker 检查 + l2_dispatch_prompt 生成）
    2. 提取 _gate_check_l3() ~55L：L3 审查完成检测 + .done 真实性校验 + fix-compliance 调用（phases 5/6/7）
    3. 提取 _gate_do_transition() ~40L：transition dispatch（format result + exit 0/2）
    4. _gate_phase_transition() 降级为 ~45L 编排器：is_phase_write 判定 → direction 判定 → 子函数调度
    保持现有 behavior（所有 gate 检查逻辑不变），仅改变函数组织结构
  </action>
  <verify>bash -n flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh && npx bats test/test_independent_review_gate.bats</verify>
  <done>AC-1: _gate_phase_transition 拆为 3 子函数 ≤ 60L + 编排器 ≤ 50L，bats 全通过</done>
  <depends_on>T04</depends_on>
</task>

<task id="T06" parallel="true">
  <name>AC-1 拆分 l3-review.sh 中 3 个子函数</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
  </write_files>
  <action>
    按 DESIGN §2.4/2.5/2.6 拆分模式：
    1. smart_truncate() 112L → ~30L 编排器 + _truncate_headers() ~25L + _truncate_artifacts() ~30L + _truncate_changelog() ~20L + _truncate_priority_fallback() ~20L
    2. _l3_parse_result() 82L → ~15L 编排器 + _l3_parse_verdict() ~25L + _l3_validate_result() ~25L + _l3_archive_result() ~20L
    3. _l3_build_prompt() 85L → ~20L 编排器 + _l3_build_system_prompt() ~25L + _l3_build_user_prompt() ~20L + _l3_build_artifact_context() ~20L
    l3_review_run() 主函数不拆（v1 保留，仅拆其调用的子函数）
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/lib/l3-review.sh && npx bats test/test_l3_review.bats 2>/dev/null || npx bats test/ --filter "l3"</verify>
  <done>AC-1: 3 函数拆分后每子函数 ≤ 60L，l3-review.sh bash -n 通过，L3 测试 0 fail</done>
  <depends_on>T03</depends_on>
</task>

<task id="T07" parallel="true">
  <name>AC-1 降级 fk_fix_compliance_check() 126L → 编排层</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/fix-compliance.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/fix-compliance.sh
  </write_files>
  <action>
    按 DESIGN §2.3 降级模式：
    1. fk_fix_compliance_check() 126L → ~40L 编排层
    2. 编排层调度既有子函数：fk_classify_findings() → fk_check_diff_only() → fk_verify_finding_fix()（循环调用）+ 结果汇总
    保持外部 API 签名不变（被 independent-review-gate 调用方不受影响）
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/lib/fix-compliance.sh && npx bats test/test_fix_compliance.bats</verify>
  <done>AC-1: fk_fix_compliance_check 降级为 ~40L 编排层，bats 全通过</done>
  <depends_on></depends_on>
</task>

<task id="T08" parallel="true">
  <name>AC-9 函数化 29-independent-review.sh → 3 子函数 + 编排层</name>
  <read_files>
    flow-kit-bundle/hooks/stop/29-independent-review.sh
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    flow-kit-bundle/hooks/stop/lib/l2-detect.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/29-independent-review.sh
  </write_files>
  <action>
    按 DESIGN §2.7 拆分模式（D8）：
    1. 提取 _check_l2_complete() ~25L：检测 INDEPENDENT-REVIEW-N.md 中 L2 section 存在性
    2. 提取 _resolve_gate_value() ~25L：从 gate_config 解析当前阶段的 gate 值（L2/L3/both）
    3. 提取 _dispatch_l3_review() ~25L：调用 l3_review_run() 并写入 INDEPENDENT-REVIEW-N.md 的 L3 段
    4. main 编排层 ~30L：依次调用三函数
    保持 Stop hook 行为不变
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/29-independent-review.sh && npx bats test/test_independent_review_gate.bats</verify>
  <done>AC-9: 3 函数提取完成，编排层 ≤ 30L，bash -n 通过</done>
  <depends_on></depends_on>
</task>

---

<task id="T09" parallel="true">
  <name>AC-7 新增 test_l3_timeout.bats（3 场景）</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    test/test_l3_review.bats
    test/test_common.bats
  </read_files>
  <write_files>
    test/test_l3_timeout.bats
  </write_files>
  <action>
    新增测试文件覆盖 3 个 timeout/error 场景——使用 curl stub 覆盖技术：
    1. L3 API 超时：stub curl 返回退出码 28 → 验证 verdict=timeout
    2. L3 API 网络错误：stub curl 返回退出码 7 → 验证 verdict=error
    3. timeout/error 后 .done 不写入：验证 .independent-review-N.done 文件不存在（或 mtime 不晚于测试开始时间）
    每个测试 @test 独立 setup/teardown，不污染其他测试
  </action>
  <verify>npx bats test/test_l3_timeout.bats</verify>
  <done>AC-7: 3 个 timeout/error 场景 bats 测试通过</done>
  <depends_on>T06</depends_on>
</task>

<task id="T10">
  <name>AC-3 + AC-4 全量回归：bash -n + bats test/</name>
  <read_files>
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    flow-kit-bundle/hooks/stop/29-independent-review.sh
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    flow-kit-bundle/hooks/stop/lib/fix-compliance.sh
    flow-kit-bundle/hooks/stop/lib/done-validation.sh
    flow-kit-bundle/hooks/stop/lib/common.sh
    flow-kit-bundle/hooks/stop/lib/correction-file.sh
    flow-kit-bundle/hooks/stop/lib/interactive-ui-check.sh
    flow-kit-bundle/hooks/stop/lib/weak-model-compliance.sh
    flow-kit-bundle/hooks/stop/lib/transcript-parser.sh
    flow-kit-bundle/hooks/stop/lib/correction-types.sh
    test/
  </read_files>
  <write_files></write_files>
  <action>
    最终验收门禁：
    1. bash -n 10 个修改的 .sh 文件，零报错
    2. npx bats test/ 全量执行，exit 0，0 failures
    3. （可选）time npx bats test/test_independent_review_gate.bats 性能对比 ≤ 200ms 差异
  </action>
  <verify>for f in flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh flow-kit-bundle/hooks/stop/29-independent-review.sh flow-kit-bundle/hooks/stop/lib/l3-review.sh flow-kit-bundle/hooks/stop/lib/fix-compliance.sh flow-kit-bundle/hooks/stop/lib/done-validation.sh flow-kit-bundle/hooks/stop/lib/common.sh flow-kit-bundle/hooks/stop/lib/correction-file.sh flow-kit-bundle/hooks/stop/lib/interactive-ui-check.sh flow-kit-bundle/hooks/stop/lib/weak-model-compliance.sh flow-kit-bundle/hooks/stop/lib/transcript-parser.sh flow-kit-bundle/hooks/stop/lib/correction-types.sh; do bash -n "$f" || echo "FAIL: $f"; done && npx bats test/</verify>
  <done>AC-3 + AC-4: npx bats test/ 全量通过 exit 0，bash -n 全文件零报错</done>
  <depends_on>T05, T06, T07, T08, T09</depends_on>
</task>

---

## 依赖图（汇总）

```
T01[P] ──┐
T02[P] ──┤
T03[P] ──┼──→ T04 ──→ T05[P] ────────────┐
          │         T06[P] ← T03 ──→ T09[P] ┤
          │         T07[P] ────────────────┤
          │         T08[P] ────────────────┤
          └────────────────────────────────┴──→ T10
```

## AC 覆盖矩阵

| AC | T01 | T02 | T03 | T04 | T05 | T06 | T07 | T08 | T09 | T10 |
|---|---|---|---|---|---|---|---|---|---|---|
| AC-1 长函数 ≤60L | | | | | ✅ | ✅ | ✅ | | | |
| AC-2 依赖环 | ✅ | | | | | | | | | |
| AC-3 零回归 | | | | | | | | | | ✅ |
| AC-4 bash -n | | | | | | | | | | ✅ |
| AC-5 DRY phase_name | | | | ✅ | | | | | | |
| AC-6 DRY jq goal | | ✅ | | | | | | | | |
| AC-7 timeout 测试 | | | | | | | | | ✅ | |
| AC-8 self-sourcing+死代码 | | | ✅ | | | | | | | |
| AC-9 29 号 hook | | | | | | | | ✅ | | |
