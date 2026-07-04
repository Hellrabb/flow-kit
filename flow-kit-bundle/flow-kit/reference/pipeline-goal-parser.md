# Pipeline Goal 解析器

> 共享 reference — 由 `6-review.md`、`7-integration.md` 等阶段 prompt 引用。
> 提供从 `.flow-active` 提取 pipeline goal 字段的标准 jq 命令。

## jq 解析命令

```bash
jq -r '.goal | "\(.scope // "phase")|\(.start_phase // "4")|\(.current_phase // .start_phase // "4")|\(.phases_done // [] | join(","))|\(.auto_advance // false)"' .flow-active
```

## 输出格式

管道分隔符（`|`）格式，字段顺序：

| 位置 | 字段 | 取值 | 说明 |
|---|---|---|---|
| 1 | `scope` | `"pipeline"` / `"phase"` | goal 模式；缺失时默认 `"phase"` |
| 2 | `start_phase` | `"0"` ~ `"7"` | pipeline 起始阶段；缺失时默认 `"4"` |
| 3 | `current_phase` | `"0"` ~ `"7"` | 当前阶段；缺失时回退到 `start_phase` 或 `"4"` |
| 4 | `phases_done` | 逗号分隔列表，如 `"0,1,2,3"` | 已完成阶段；缺失时为空 |
| 5 | `auto_advance` | `"true"` / `"false"` | 是否自动推进；缺失时默认 `"false"` |

## 使用示例

```bash
# 解析 pipeline goal 状态
IFS='|' read -r scope start_phase current_phase phases_done_str auto_advance \
  < <(jq -r '.goal | "\(.scope // "phase")|\(.start_phase // "4")|\(.current_phase // .start_phase // "4")|\(.phases_done // [] | join(","))|\(.auto_advance // false)"' .flow-active)

if [[ "$scope" == "pipeline" ]]; then
  echo "Pipeline: $start_phase → $current_phase (done: $phases_done_str)"
else
  echo "单阶段 goal"
fi
```

## 维护

- 如果 `.flow-active` 的 `goal` 字段结构变更（如新增字段），需同步更新本文件
- 所有引用本文件的 prompt 自动获得更新，无需逐一修改
