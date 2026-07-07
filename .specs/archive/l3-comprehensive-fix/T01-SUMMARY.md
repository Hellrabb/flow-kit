# T01-SUMMARY: fk_resolve_phase() 统一 phase 解析函数

- **Task**: T01
- **状态**: done
- **改动**: `flow-kit-bundle/hooks/stop/lib/common.sh`（+25 行）

## verify 输出

```
FUNCTION_OK
T1 pipeline+4: Got: 4 (expect 4)      PASS
T2 single+1: Got: 1 (expect 1)        PASS
T3 pipeline+5+stale6: Got: 5 (expect 5) PASS
```

## 6 维自查

- R1 认知过载: 函数 25 行，单层逻辑，OK
- R2 变更传播: 仅 common.sh 新增函数，无越界
- R3 知识重复: 原 3 处内联 pipeline-aware 逻辑将由 T06/T07/T08 统一改用此函数
- R4 偶然复杂: 无——仅做 phase 解析
- R5 依赖混乱: 无——仅依赖 jq + .flow-active
- R6 领域扭曲: 无

## 越界检查

✅ 0 越界（仅修改 common.sh，在 T01 write_files 范围内）
