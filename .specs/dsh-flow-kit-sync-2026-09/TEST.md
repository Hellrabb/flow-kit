# TEST — dsh-flow-kit-sync-2026-09（证据记录）

## 单元（插件）

```bash
node --test dsh-flow-kit/test/*.test.mjs
# tests 20 / pass 20 / fail 0
```

新增/变更断言：
- doctor correction 卫生报告（type + violations 去重 + model-missing message）
- /flow model 五级链落盘 + 回显新值（R1 回归：assert.match(result.text,…)、
  ✅ 已更新。 恰 1 次）

## 回归（bats，root test/ 与 flow-kit-bundle/test/ 双源一致）

```bash
bats test/        # 770 ok / 0 fail
```
- 定向：correction-hygiene 31 ok、flow-active-integrity、install-dsh-platform 2、
  test_fk_resolve_model 16 ok（五级链 L3-F/G/H + L2-F/G/H）

## 静态

- bash package-dsh-plugin.sh：node --check + bash -n 全量通过
- make lint：shellcheck（error 级）0 errors
- make check-test-sync：test/ ↔ flow-kit-bundle/test/ 双源一致

## vendor 零丢失

```bash
diff -rq flow-kit-bundle dist/dsh-flow-kit/vendor/flow-kit-bundle   # 空输出
```
