# T03-SUMMARY · _l3_inject_context 四象限注入矩阵

## 交付物
- `flow-kit-bundle/hooks/stop/lib/l3-prompt.sh`：`_l3_inject_context` 重写（L168-259，~90 行）
- `test/test_l3_pipeline_fix.bats`：6 个 T03 用例（Q1-Q4 + AC-7 + 配额）+ `_inject_fixture` helper

## TDD 证据（fix_rounds = 1）
- RED：6/6 失败（旧实现无条件「已响应」声明、无发现注入、无配额）
- GREEN：重写后 28/28 全绿（含既有 AC-5 bats:106-132 锚）

## 行为矩阵（D2/D3/D4）
| findings | 响应 | 注入内容 |
|---|---|---|
| 有 | 有 | verdict + 摘要(≤600B, (+k more) 折叠) + 响应要点(≤200B) |
| 有 | 无 | verdict + 摘要 + 「主 agent 未响应前次发现」标注 |
| 无 | 有 | verdict + 响应要点 |
| 无 | 无（verdict 可解析）| 仅 verdict 行 |
| 文件缺失/空 或 皆不可提取 | — | 整段静默（AC-7）|

## 关键实现点
- 三锚响应检测：`^## 主 agent 响应` 段头 / `主 agent 反驳：` 段 / 行内 `(Fixed in|Tech-debt|Not-applicable):`（grep -E 不锚行首，兼容 `- **R1** — Fixed in:` 格式）
- 摘要配额：逐行累加字节 >600B 即止，`(+N more)` 折叠剩余
- 响应要点：分类标记行 `；` 连接 ≤200B（head -8 上限）
- 删除旧版无条件「主 agent 已响应前次发现」声明（假声明根因）
- verdict 提取逻辑保持原样（`**Verdict**: ` / `"verdict":"..."` 两形态）
- `[ -s ]` 替代 `[ -f ]`（空文件静默）；`LC_ALL=C` 字节语义

## 六维自查
- ✅ verify：bats 28/28；`make check` 全绿（双源一致）
- ✅ diff ⊆ write_files：l3-prompt.sh + test_l3_pipeline_fix.bats
- ✅ 沿用抽象：`_l3_extract_prior_findings`（T02）；无新依赖
- ✅ 禁动清单：未触 l3-review.sh 调用关系 / done / 29 号 / common.sh
- ✅ 无吞错反模式：grep 容错均在设计内（畸形输入降级为静默/跳过）
- ✅ 注释：函数头矩阵 = 调用方依赖的契约文档 + D 编号可追溯锚
