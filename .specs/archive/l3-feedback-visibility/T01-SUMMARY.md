# T01-SUMMARY · F3 — l3-review.sh：summary 提取 + 故障降级 + 格式化函数

- **Task ID**: T01
- **Change ID**: l3-feedback-visibility
- **状态**: ✅ done

---

## 做了什么

在 `flow-kit-bundle/hooks/stop/lib/l3-review.sh` 中完成 F3 全部改动：

1. **新增 `_l3_format_result()` 格式化函数**（第 35-41 行）：
   - 统一 `L3_RESULT:` 行输出格式，供 F1(PreToolUse) 和 F2(SessionStart) 共用
   - 签名：`_l3_format_result <verdict> <summary> <report_relative_path>`

2. **新增 summary 三层提取**（与既有 verdict 提取并列）：
   - Layer 1：JSON 代码块 → jq -r '.summary'
   - Layer 2：裸 JSON → jq -r '.summary'
   - Layer 3：grep 正则 → grep -oP '"summary"\s*:\s*"\K[^"]+'
   - 未提取到时默认空字符串

3. **新增第四层故障降级**：
   - verdict 为空或 "unknown" → verdict="error" + summary 固定为 "L3 结果解析失败（verdict 不可用）"
   - 利用 done-validation.sh:139 已接受的 error 值域

4. **值域扩展**：case 语句 `pass|fail` → `pass|fail|error`

5. **l3_write_done_marker() 扩展**：.done 增加 `L3_summary=${l3_summary}` 行

6. **l3_write_timeout_done() 扩展**：.done 增加 `L3_summary=L3 API 调用超时（30s）` 行

## 改动了哪些文件

| 文件 | 变更 | 说明 |
|---|---|---|
| `flow-kit-bundle/hooks/stop/lib/l3-review.sh` | +45 / -3 | F3 全部改动 |

## verify 输出

```
=== 1. bash -n syntax check ===
PASS

=== 2. _l3_format_result function exists ===
PASS

=== 3. L3_summary in .done writers ===
2  (both l3_write_done_marker + l3_write_timeout_done)
PASS

=== 4. verdict=error degradation logic ===
PASS: verdict=error found
PASS: fixed summary text found

=== 5. error in value domain case ===
PASS: error in case statement

=== 6. timeout .done has L3_summary ===
PASS
```

## 6 维自查

✅ **R1 认知过载**：每个提取层 ≤ 3 行，_l3_format_result 仅 3 行，无 > 50 行函数，嵌套 ≤ 3 层

✅ **R2 变更传播**：仅 l3-review.sh 改动；无越界文件

✅ **R3 知识重复**：verdict 和 summary 三层提取为有意的显式重复（DESIGN D3 决策："抽取公共函数为过度工程，v2 若 ≥3 字段再重构"），非疏忽

✅ **R4 偶然复杂**：_l3_format_result 仅 echo 一行，无"以后可能用到"的扩展点

✅ **R5 依赖混乱**：l3-review.sh 是共享 lib，不引入新依赖；_l3_format_result 放在本文件内避免跨文件 source 开销

✅ **R6 领域扭曲**：变量名 domain-appropriate（l3_verdict, l3_summary, _l3_format_result）

## 沿用既有抽象 grep

```
✅ 沿用既有抽象 grep（R6.4）：
- L3 API 调用：沿用 l3_review_run() / l3_review_with_timeout()（不改签名）
- verdict 提取：沿用三层 fallback 模式（代码块 → 纯JSON → grep），summary 用同模式并列
- .done 写入：沿用 key=value 格式（cat <<DONE_EOF），仅新增 L3_summary 行
- 值域校验：沿用既有 case 语句模式，扩展 pass|fail → pass|fail|error
```

## 越界检查（R6.5）

```
✅ 越界检查：
  - TASK write_files：1 项（l3-review.sh）
  - 实际 diff 涉及：1 项（l3-review.sh）
  - 越界：0
```

## 破坏性变更

未触发（仅新增代码，无 ≥ 5 行删除，未改公共函数签名）。
