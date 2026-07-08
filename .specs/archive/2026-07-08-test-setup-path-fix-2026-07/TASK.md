# TASK: 修 10+ 测试 setup 路径 + Makefile test 管道

- **Change ID**: test-setup-path-fix-2026-07
- **关联**: `@.specs/test-setup-path-fix-2026-07/DESIGN.md`

## 波次划分

```
Wave 1 (parallel): T01[P], T02[P], T03[P], T04[P], T05[P]  (修路径 + Makefile，不同文件)
Wave 2:            T06  (跑全量测试，迭代修暴露的真 fail)
```

## 任务清单

```xml
<task id="T01" parallel="true" status="pending">
  <name>修 HOOK_BASE_DIR/TEST_ROOT 模式测试（5 文件）</name>
  <read_files>test/test_correction_file.bats test/test_flow_active_integrity.bats test/test_l2_l3_fix_compliance.bats test/test_l3_async_dispatch.bats test/test_setup_integrity.bats .specs/LESSONS.md</read_files>
  <write_files>test/test_correction_file.bats test/test_flow_active_integrity.bats test/test_l2_l3_fix_compliance.bats test/test_l3_async_dispatch.bats test/test_setup_integrity.bats</write_files>
  <action>把 setup 的 HOOK_BASE_DIR/TEST_ROOT/BUNDLE_DIR 路径从 $(dirname)/../hooks 改为位置无关（向上查找 flow-kit-bundle/hooks）。逐文件确认 source 目标（correction-file.sh / hooks/stop / lib）。已查阅 L-025/L-027。</action>
  <verify>npx bats test/test_correction_file.bats test/test_flow_active_integrity.bats 2>&1 | tail -10</verify>
  <done>5 文件 source 成功，无 BW01 127</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true" status="pending">
  <name>修 BATS_TEST_DIRNAME/../hooks 模式测试（4 文件）</name>
  <read_files>test/done-skip.bats test/l2-detect.bats test/l3-truncation.bats test/phase-resolution.bats</read_files>
  <write_files>test/done-skip.bats test/l2-detect.bats test/l3-truncation.bats test/phase-resolution.bats</write_files>
  <action>把 source "${BATS_TEST_DIRNAME}/../hooks/..." 改为位置无关（向上查找 flow-kit-bundle/hooks/stop/lib）。目标：common.sh / l2-detect.sh / l3-review.sh。</action>
  <verify>npx bats test/done-skip.bats test/l2-detect.bats test/l3-truncation.bats test/phase-resolution.bats 2>&1 | tail -10</verify>
  <done>4 文件 source 成功，无 BW01 127</done>
  <depends_on></depends_on>
</task>

<task id="T03" parallel="true" status="pending">
  <name>修 test_l2_l3_granular_gate + test_dual_review_merge（done-validation + l3-review）</name>
  <read_files>test/test_l2_l3_granular_gate.bats test/test_dual_review_merge.bats</read_files>
  <write_files>test/test_l2_l3_granular_gate.bats test/test_dual_review_merge.bats</write_files>
  <action>DONE_VALIDATION_LIB / L3_LIB / DONE_VAL_LIB 路径改位置无关（向上查找 flow-kit-bundle/hooks/stop/lib/done-validation.sh + l3-review.sh）。这两个文件测 fk_validate_done_marker / fk_independent_review_gate_active（TD-011 相关，但本次只修路径不碰 gate 逻辑）。</action>
  <verify>npx bats test/test_l2_l3_granular_gate.bats 2>&1 | tail -10</verify>
  <done>2 文件 source 成功，fk_validate_done_marker 定义，无 BW01 127</done>
  <depends_on></depends_on>
</task>

<task id="T04" parallel="true" status="pending">
  <name>修 test_checkpoint + test_smoke_syntax（cp + REPO_ROOT）</name>
  <read_files>test/test_checkpoint.bats test/test_smoke_syntax.bats</read_files>
  <write_files>test/test_checkpoint.bats test/test_smoke_syntax.bats</write_files>
  <action>test_checkpoint 的 cp 路径 + test_smoke_syntax 的 REPO_ROOT 改位置无关（向上查找）。</action>
  <verify>npx bats test/test_checkpoint.bats test/test_smoke_syntax.bats 2>&1 | tail -10</verify>
  <done>2 文件无 BW01 127</done>
  <depends_on></depends_on>
</task>

<task id="T05" parallel="true" status="pending">
  <name>Makefile test target 管道复核 + 双源同步</name>
  <read_files>Makefile</read_files>
  <write_files>Makefile</write_files>
  <action>复核 Makefile test target：line 13 判定行已直接用 bats exit（正确）；line 12 展示行加注释或 pipefail 防混淆。AC-5 验证：临时注入 fail 测 make test 是否捕获。Wave 1 全部改完后，cp test/*.bats 同步到 flow-kit-bundle/test/（check-test-sync）。</action>
  <verify>make check-test-sync && make test</verify>
  <done>make test 判定可信（bats exit 1 时 make test fail）；双源一致</done>
  <depends_on>T01,T02,T03,T04</depends_on>
</task>

<task id="T06" parallel="false" status="pending">
  <name>跑全量测试，迭代修暴露的真 fail</name>
  <read_files>所有 test/*.bats + 对应被测 lib</read_files>
  <write_files>按发现的 fail 决定</write_files>
  <action>Wave 1 完成后跑 make test。修路径后 source 成功，之前被假绿掩盖的真 fail 会显现。逐个诊断：真 bug→修代码；断言过时→修测试；复杂→记 TD。迭代直到 make test 全绿。</action>
  <verify>make test && make check</verify>
  <done>make test 全绿（414 pass·0 BW01）+ make check 通过</done>
  <depends_on>T05</depends_on>
</task>
```

## 状态字段说明
- pending / in_progress / done / blocked

## 阻塞日志
| 任务 | 阻塞原因 | 待人工决策项 | 时间 |
|---|---|---|---|

## Fix 任务（来自 REVIEW / INTEGRATION）
```xml
<!-- 占位 -->
```
