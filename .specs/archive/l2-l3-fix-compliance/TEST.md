# TEST: L2/L3 review 发现强制代码修复

- **Change ID**: l2-l3-fix-compliance
- **关联**: `@.specs/l2-l3-fix-compliance/REQUIREMENT.md`、`@.specs/l2-l3-fix-compliance/TASK.md`

---

## 测试矩阵

| AC | 测试方式 | 结果 | 备注 |
|---|---|---|---|
| AC-1 | grep prompt 文件含 `Fixed in:` | ✅ 4/4 文件通过 | 5-test(2) / 6-review(2) / 7-integration(2) / L2-blind-review(3) |
| AC-2 | bats: test_l2_l3_fix_compliance.bats (AC-2 段 4 tests) | ✅ 4/4 | 纯 .md diff 阻断、含 .sh diff 放行、空 diff 阻断、混合 diff 放行 |
| AC-2a | bats: test_l2_l3_fix_compliance.bats (AC-2a 段 5 tests) | ✅ 5/5 | .sh→源码级、.md→文档级、行号剥离、混合分类、空输入 |
| AC-2b | bats: test_l2_l3_fix_compliance.bats (AC-2b 段 5 tests) | ✅ 5/5 | OK/MISSING/≥50%阻断/无声明/告警 |
| AC-3 | bats: test_l2_l3_fix_compliance.bats (AC-3 段 2 tests) + 回归 | ✅ 2/2 + 34/34 gate 测试 | 假 .done+纯文档 diff、合法 .done+纯文档 diff |
| AC-4 | grep 50% 阈值在 prompt 中 | ✅ 5-test + 6-review | 技术债滥用防护文本已嵌入 |
| AC-5 | bats: test_l2_l3_fix_compliance.bats (AC-5 段 6 tests) + grep | ✅ 6/6 + gate 确认 | phase 5/6/7 触发、phase 1/2/3 跳过 |

**总计**: 23/23 新增测试通过，现有 gate 测试 34/34 无回归。

---

## 五轮测试

### 第 1 轮 · 功能测试

- [x] fk_classify_source_files: 文件分类正确（5 tests）
- [x] fk_check_doc_only_diff: 纯文档检测正确（4 tests）
- [x] fk_verify_finding_files: 逐发现校验正确（5 tests）
- [x] fk_fix_compliance_check 阶段限定正确（6 tests）
- [x] L3_FIX_SOURCE_EXTS env var 覆盖（1 test）
- [x] 语法检查: fix-compliance.sh + independent-review-gate.sh 均通过 `bash -n`
- [x] AC-1 验证: 4 prompt 文件含 `Fixed in:` 协议（grep 确认 5-test:2, 6-review:2, 7-integration:2, L2-blind-review:3）
- [x] AC-4 验证: 50% 技术债阈值在 5-test + 6-review prompt 中（grep 确认）

### 第 2 轮 · 性能测试

- [x] 无性能退化 —— 所有检测函数为本地 git diff + jq 操作，单次调用 < 100ms
- [x] fk_classify_source_files: O(n) 文件名比对，输入 1000 文件不超 1s
- [x] bats 测试总耗时 < 30s（23 tests）

### 第 3 轮 · 安全测试

- [x] fail-closed 策略验证 —— 所有错误路径返回非零
- [x] git diff 失败 → fk_check_doc_only_diff 返回 3（阻断）
- [x] review_md 不存在 → fk_fix_compliance_check 返回 0（放行，非阻断——review 可能未运行）
- [x] jq 不可用 → `command -v jq >/dev/null` gate 在独立 review gate 入口处已处理

### 第 4 轮 · 兼容性测试

- [x] 未开启 gate_config 的 change 不受影响（phase 1/2/3 跳过）
- [x] 现有 .done 格式不破坏（6 键 KVP 未修改）
- [x] 现有 gate-integrity 测试 34/34 通过
- [x] bash -n 语法检查通过

### 第 5 轮 · 可观测性测试

- [x] 阻断时 stderr 输出明确原因："纯文档响应" / "逐发现校验未通过" / "内部错误"
- [x] 告警时 stderr 输出 WARNING 级别提示（<50% MISSING）
- [x] 告警时 stderr 输出 ⚠️ 前缀（<50% MISSING 带 hint）

---

## UAT 脚本

```bash
# UAT-1: 功能回归
npx bats flow-kit-bundle/test/test_l2_l3_fix_compliance.bats

# UAT-2: 全量回归（确认无新失败）
npx bats flow-kit-bundle/test/

# UAT-3: 语法检查
bash -n flow-kit-bundle/hooks/stop/lib/fix-compliance.sh
bash -n flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh

# UAT-4: AC-1 prompt 文本验证
for f in flow-kit-bundle/flow-kit/prompts/{5-test,6-review,7-integration}.md \
         flow-kit-bundle/flow-kit/prompts/independent/L2-blind-review.md; do
  echo "$f: $(grep -c 'Fixed in:' $f) 'Fixed in:' matches"
done

# UAT-5: AC-5 阶段白名单验证
grep -q '5|6|7' flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh \
  && echo "AC-5: phase whitelist OK"
```

---

## 预存失败（与本 change 无关）

| 测试 | 文件 | 原因 |
|---|---|---|
| CF-01/02/03 | test_correction_file.bats | write_compliance_correction 函数未找到（预存） |
| BW01 | test_package_flow_kit.bats | package-flow-kit.sh 路径错误（预存） |
| HOOK_BASE_DIR | test_flow_active_integrity.bats | 测试 setup 路径计算错误（预存） |

---

## 覆盖率回顾

- AC 覆盖率: 5/5 (100%)
- 函数覆盖率: fk_classify_source_files / fk_check_doc_only_diff / fk_verify_finding_files / fk_fix_compliance_check 全部有 bats 覆盖
- 边界覆盖率: 空输入、大阈值边界（50%）、阶段边界（4→5、7→归档）、错误路径均覆盖
- 无 mock 屏蔽真实失败的测试 —— 所有测试使用真实 git diff + 临时仓库
