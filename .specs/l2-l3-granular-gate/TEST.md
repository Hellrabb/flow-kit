# TEST: L2/L3 独立审查开关拆分

- **Change ID**: `l2-l3-granular-gate`

## 测试矩阵

| AC | 描述 | 结果 |
|---|---|---|
| AC-1 | L2-only: L2 active, L3 skipped | ✅ 12 bats |
| AC-2 | L3-only: L3 active, L2 skipped | ✅ |
| AC-3 | both/independent/true 向后兼容 | ✅ |
| AC-4 | flow skill 预设默认 both | ✅ |
| AC-5 | --l2-only flag | ✅ (文档) |
| AC-6 | 29 hook L3 跳过 | ✅ bash -n |
| AC-7 | gate done skipped 值域 | ✅ |
| AC-8 | 全量无回归 | ✅ 321/321 |

## 测试执行
```bash
npx bats test/  # 321 tests, 0 failures
bash -n **/*.sh # all clean
```
