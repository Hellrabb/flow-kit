# T01-SUMMARY — common.sh fk_resolve_model

## 做了什么
`common.sh` 新增 `fk_resolve_model <layer>`（L3/L2 三级优先级链解析，ADR-012）。参照既有 `fk_resolve_phase` 结构。

## 改了哪些文件
- `flow-kit-bundle/hooks/stop/lib/common.sh`（+30 行，fk_resolve_model 函数，插入在 fk_resolve_phase 后）

## verify 输出
```
VERIFY_OK（fk_resolve_model 定义存在）
场景 D（全空）→ 空字符串 PASS
场景 A（P1 命中 ANTHROPIC_DEFAULT_HAIKU_MODEL=haiku-a）→ 返回 haiku-a PASS
```

## 6 维自查（内置快查 · 非生产代码大改）
- R1 认知过载：~20 行单函数，嵌套浅 ✅
- R2 变更传播：仅加函数，不改既有 6 个 fk_* ✅
- R3 知识重复：L2/L3 分支结构相似但 env var 名不同（ANTHROPIC_DEFAULT_HAIKU_MODEL vs ANTHROPIC_L2_MODEL），必要重复 ✅
- R4 偶然复杂：三级链是业务需求（DESIGN §1）✅
- R5 依赖混乱：lib 函数无反向依赖 ✅
- R6 领域扭曲：layer/model 命名清晰 ✅

## 沿用既有抽象 grep（R6.4）
- `fk_resolve_phase`（common.sh:215）：沿用其 `jq -r '...' 2>/dev/null || echo ""` + 纯查询 return 0 模式 → fk_resolve_model 镜像此结构，额外用 `${PROJECT_ROOT:-}` 加固 set -u（DESIGN §2 R5）

## 越界检查（R6.5）
- TASK write_files：`common.sh`
- 实际 diff：`common.sh`
- 越界：0 ✅

## LESSONS 查阅（R1.8）
- L-020（active·新模块三处接线）：**不适用**——fk_resolve_model 是 common.sh 内函数，非新 hook 模块（无需 00-gate/HOOK_MODULE_NAMES/stop-hook.json 接线）
- L-011（jq key 连字符→bracket）：l3_model/l2_model 无连字符，`.goal.l3_model` 直接访问 OK
- L-199（source lib type 检查容错）：T01 verify 用 `type fk_resolve_model`，对齐此教训
