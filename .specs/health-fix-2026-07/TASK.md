# TASK: 2026-07 健康修复

- **Change ID**: `health-fix-2026-07`
- **关联**: `@.specs/health-fix-2026-07/REQUIREMENT.md`、`@.specs/health-fix-2026-07/DESIGN.md`

---

## 波次划分

```
Wave 1 (parallel): T01[P], T02[P], T03[P], T04[P]
```

全部 4 个任务无共享 `write_files`，可完全并行执行。

---

## 任务列表

---

<task id="T01" parallel="true">
  <name>correction-file merge 策略升级</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/correction-file.sh
    flow-kit-bundle/hooks/stop/lib/interactive-ui-check.sh
    flow-kit-bundle/hooks/stop/lib/weak-model-compliance.sh
    test/test_correction_file.bats
    test/test_interactive_ui_check.bats
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/correction-file.sh
    flow-kit-bundle/hooks/stop/lib/interactive-ui-check.sh
    flow-kit-bundle/hooks/stop/lib/weak-model-compliance.sh
  </write_files>
  <action>
    1. correction_file_write() 新增 merge 策略：
       - 第三个参数 strategy ∈ {"overwrite"(default), "merge"}
       - merge 逻辑：jq 读现有 .violations → 按 gate_type+tool 去重 → 追加新条目 → 写回
    2. interactive-ui-check.sh 的 write_correction_file() 将 "overwrite" 改为 "merge"
    3. weak-model-compliance.sh 的 write_compliance_violations() 将 "overwrite" 改为 "merge"
    4. correction-file.sh:6 注释更新：去除误导性双向暗示，明确写"correction-file.sh 是被依赖的叶子模块"
  </action>
  <verify>make test</verify>
  <done>AC-1, AC-2: merge 策略生效 + test_correction_file.bats + test_interactive_ui_check.bats 全过</done>
  <depends_on></depends_on>
</task>

---

<task id="T02" parallel="true">
  <name>done-validation.sh 拆分（flow-kit-artifacts.sh 子库提取）</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh
    flow-kit-bundle/hooks/stop/29-independent-review.sh
    flow-kit-bundle/hooks/stop/31-auto-advance.sh
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    test/test_flow_artifacts.bats
    test/test_gate_integrity.bats
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/done-validation.sh
    flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh
  </write_files>
  <action>
    1. 新建 done-validation.sh（~140 行）：
       - 从 flow-kit-artifacts.sh 搬入 fk_independent_review_gate_active（lines ~105-148）
       - 搬入 _fk_done_kvp（lines ~150-159）
       - 搬入 fk_validate_done_marker（lines ~161-245）
       - 文件头加注释："通过 flow-kit-artifacts.sh 聚合入口加载，不建议直接 source"
    2. flow-kit-artifacts.sh 顶部新增 source 行：
       source "${HOOK_BASE_DIR}/lib/done-validation.sh" 2>/dev/null || true
    3. 从 flow-kit-artifacts.sh 删除已搬出的 3 个函数定义
    4. 调用方（29/31/pre-tool-use）不改动——聚合入口保持向后兼容
  </action>
  <verify>make test</verify>
  <done>AC-5, AC-6: test_flow_artifacts.bats + test_gate_integrity.bats 全过；调用方 grep 确认无 source 路径变更</done>
  <depends_on></depends_on>
</task>

---

<task id="T03" parallel="true">
  <name>jq pipeline goal 解析共享 reference 提取</name>
  <read_files>
    flow-kit-bundle/flow-kit/prompts/6-review.md
    flow-kit-bundle/flow-kit/prompts/7-integration.md
    flow-kit-bundle/flow-kit/reference/
    package-flow-kit.sh
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/reference/pipeline-goal-parser.md
    flow-kit-bundle/flow-kit/prompts/6-review.md
    flow-kit-bundle/flow-kit/prompts/7-integration.md
    package-flow-kit.sh
  </write_files>
  <action>
    1. 新建 pipeline-goal-parser.md：
       含 jq 解析命令 + 输出字段说明（scope/start_phase/current_phase/phases_done/auto_advance）
       + 使用示例（管道分隔符格式的解析方式）
    2. 6-review.md:22 内联 jq 替换为引用：
       "解析逻辑见 @flow-kit/reference/pipeline-goal-parser.md。"
    3. 7-integration.md:19 同样替换
    4. package-flow-kit.sh Part A staging 清单新增 pipeline-goal-parser.md
  </action>
  <verify>grep -L 'goal.*scope.*start_phase.*current_phase.*phases_done.*gates' flow-kit-bundle/flow-kit/prompts/6-review.md flow-kit-bundle/flow-kit/prompts/7-integration.md && echo "AC-3: jq inline blocks removed" && bash package-flow-kit.sh --validate</verify>
  <done>AC-3, AC-4: 两个 prompt 不再含内联 jq goal 解析块 + --validate 通过</done>
  <depends_on></depends_on>
</task>

---

<task id="T04" parallel="true">
  <name>validate_staging.sh 拆分（package-flow-kit.sh 函数提取）</name>
  <read_files>
    package-flow-kit.sh
  </read_files>
  <write_files>
    flow-kit-bundle/lib/validate_staging.sh
    package-flow-kit.sh
  </write_files>
  <action>
    1. 新建 flow-kit-bundle/lib/validate_staging.sh（~122 行）：
       - 从 package-flow-kit.sh 搬入 validate_staging_coverage() 函数（lines 19-140）
       - 用 BASH_SOURCE[0] 自定位 BUNDLE_DIR（而非依赖调用方 $SCRIPT_DIR）
       - 文件头加 #!/bin/bash + set -euo pipefail
    2. package-flow-kit.sh：
       - 顶部新增 source "$SCRIPT_DIR/flow-kit-bundle/lib/validate_staging.sh"
       - 删除原 validate_staging_coverage() 函数定义
       - Part C（或新增 Part）staging 清单新增 lib/validate_staging.sh
    3. --validate 入口处保留调用 validate_staging_coverage（现在来自 sourced lib）
  </action>
  <verify>diff <(bash package-flow-kit.sh --validate 2>&1) <(git stash && bash package-flow-kit.sh --validate 2>&1; git stash pop) && echo "AC-7: output identical"</verify>
  <done>AC-7: --validate 输出与改动前一致</done>
  <depends_on></depends_on>
</task>

---

## 全局验证（所有 T01-T04 完成后）

```bash
# 全量测试
make test

# 包完整性
bash package-flow-kit.sh --validate

# 双源同步
make check-test-sync

# 依赖方向验证（确认 correction-file 仍是叶子）
for f in correction-file.sh; do
  for other in interactive-ui-check.sh weak-model-compliance.sh; do
    c=$(grep -c "source.*$other" flow-kit-bundle/hooks/stop/lib/$f 2>/dev/null || echo 0)
    [ "$c" -gt 0 ] && echo "FAIL: $f sources $other" || echo "OK: $f -> $other = 0"
  done
done
```
