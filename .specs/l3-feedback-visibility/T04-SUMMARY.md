# T04-SUMMARY · bats 测试覆盖 AC-1~6 + 安全验证

- **Task ID**: T04
- **Change ID**: l3-feedback-visibility
- **状态**: ✅ done

---

## 做了什么

新建 `test/test_l3_feedback.bats`，25 个测试用例覆盖全部 6 条 AC：

| 场景 | 测试数 | 覆盖 |
|------|--------|------|
| 1. _l3_format_result() 格式化 | 4 | D6 共享格式化函数 |
| 2. AC-1 格式精确断言 | 3 | AC-1 grep 正则 + 大小写 + 相对路径 |
| 3. AC-6 畸变降级 | 2 | verdict=error + 不泄露原始 JSON |
| 4. .done KVP 扩展 | 2 | L3_summary 读写 + 缺失降级 |
| 5. F1 stdout 精确断言 | 1 | AC-1 完整格式验证 |
| 6. F2 SessionStart 检测 | 3 | .done+review md 双重检测 + 否定用例 |
| 7. AC-4 全模式兼容 | 4 | L2-only / off / L3-only / both |
| 9. AC-5 exit code | 2 | timeout/error 均返回 0 |
| 10. stderr 安全 | 4 | 不含 URL/API key/绝对路径/JSON 片段 |

## verify 输出

```
npx bats test/test_l3_feedback.bats --formatter tap
1..25
ok 1 _l3_format_result: 正常 verdict + summary + report
ok 2 _l3_format_result: 空 summary
... (全部 25 个)
ok 25 Security: L3_RESULT 行不含 API 响应原文 JSON 片段
0 failures
```

## 6 维自查

✅ **R1 认知过载**：每个测试 ≤ 10 行，setup/teardown 复用

✅ **R2 变更传播**：仅新增 test/test_l3_feedback.bats，无越界

✅ **R3 知识重复**：使用与 test_common.bats 相同的 bats-core 风格

✅ **R4 偶然复杂**：直接测试函数行为，无 mock 框架

✅ **R5 依赖混乱**：source 路径使用相对 BATS_TEST_FILENAME 解析，无硬编码绝对路径

✅ **R6 领域扭曲**：测试命名对应 AC 编号，描述中文清晰

## 越界检查

```
✅ 越界检查：
  - TASK write_files：1 项（test/test_l3_feedback.bats）
  - 实际 diff 涉及：1 项（test/test_l3_feedback.bats）
  - 越界：0
```
