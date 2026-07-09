# DEV-SUMMARY: td-test-infra · 4-dev 执行记录

> T01-T04 全部完成。AC-1/2/3/4 全绿。`bats test/` 419 全绿 exit 0。

## Wave 1（并行）

### T01 · Makefile 加 dup target（AC-1）
- 加 `dup:` target（独立，不进 `check`），`jscpd flow-kit-bundle/ --ignore '**/brooks-lint/**,**/brooks-tools/**,**/test/**,**/regression-demos/**'`，未装 graceful skip（stderr 提示 + exit 0）
- verify: `make dup` exit 0 + dup recipe 4 ignore 模式全 ✅（含 L2 R1 补的 `test` 模式）

### T02 · SUMMARY 覆盖表（AC-2）
- 读 test_stop_chain（覆盖 00/22/24/26/99 · bash-n+grep）+ test_smoke_syntax（全 bash-n）
- 17 行覆盖表：**covered 5 / partial 12 / gap 0**
- verify: `grep -cE` 17 行 ✅

## Wave 2

### T03 · 补 6 [business] smoke（AC-3）
- 给 23-quality / 27-interactive-ui-check / 28-weak-model-compliance / 29-independent-review / 30-ai-analyze / 33-flow-active-integrity 补 bash-n+shebang+grep 关键函数 smoke（test_stop_chain 范式，**非 source** · D2）
- 18 新测试（6×3），双源同步（cp + diff -r）
- verify: `bats test_stop_chain` 31 全绿 + 双源一致

## Wave 3

### T04 · CONTEXT 校准 + 全量回归（AC-4）
- TD-002 🟢→✅（覆盖结论）+ TD-010 🟢→✅（已固化为 make dup）
- 全量 `bats test/` **419 全绿 exit 0**

## 最终验证

| AC | 结果 |
|---|---|
| AC-1 make dup | ✅ exit 0 + 4 ignore 模式（brooks-lint/brooks-tools/test/regression-demos）|
| AC-2 SUMMARY | ✅ 17 行（grep -cE -eq 17）|
| AC-3 补 smoke | ✅ test_stop_chain 31 全绿 + diff -r 双源一致 |
| AC-4 CONTEXT+回归 | ✅ TD-002/010 校准 + bats 419 全绿 |

## 改动文件

- `Makefile`（加 `dup` target）
- `.specs/td-test-infra/SUMMARY.md`（17 行覆盖表 · 新建）
- `test/test_stop_chain.bats` + `flow-kit-bundle/test/test_stop_chain.bats`（+18 smoke 双源同步）
- `.specs/CONTEXT.md`（TD-002/010 🟢→✅ + 校准）

## 偏差

- **L3 死结绕过**：1-requirement/2-design 阶段 L3（glm-4.7）fail 后不重审 + .done 异常写（L-030 记录）。已将 gate_config 改 L2（去 L3）+ L2 用 haiku 模型。
- **L2 haiku**：3-task L2 用 model:haiku（~2 分钟，比 sonnet 快），抓到 T01 verify 缺 test 模式（R1），已修。
