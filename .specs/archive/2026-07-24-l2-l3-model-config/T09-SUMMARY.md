# T09-SUMMARY — test_fk_resolve_model.bats（AC-1/AC-2/AC-3 全链）

## 做了什么
新建 `test_fk_resolve_model.bats`，10 用例（L3 A-E + L2 A-E），覆盖 AC-1/AC-2/AC-3 全链。

## 改了哪些文件
- `flow-kit-bundle/test/test_fk_resolve_model.bats`（新建，10 用例）

## verify 输出
```
1..10 全 ok（L3-A..E + L2-A..E）
```

## 场景覆盖
- **场景 A（AC-2 专项）**：export 真实 P1（ANTHROPIC_DEFAULT_HAIKU_MODEL / ANTHROPIC_L2_MODEL）+ 设 P2/P3 值 → 断言返回 P1（证明截断，CC 用户优先级 1 不变）
- B（P2 压 P3）/ C（P3 命中）/ D（全空降级→空）/ E（三级同设→P1）
- 每用例独立 setup（mktemp -d PROJECT_ROOT + unset env），teardown 清理，无污染

## 越界检查（R6.5）
write_files: test_fk_resolve_model.bats（新建）| 实际: 同 | 越界: 0 ✅
