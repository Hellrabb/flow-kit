# T02-SUMMARY · _l3_extract_prior_findings 前轮发现提取器

## 交付物
- `flow-kit-bundle/hooks/stop/lib/l3-prompt.sh`：新增 `_l3_extract_prior_findings <review_md>`（~95 行，位于 utf8 helpers 与 `_l3_inject_context` 之间）
- `test/test_l3_pipeline_fix.bats`：新增 7 个 T02 用例（L260-312）
- `test/fixtures/independent-review-{l2-sample,l3-sample,mixed-sample,no-response,empty,overflow,verdict-only}.md` + 双源镜像

## TDD 证据（fix_rounds = 2）
- RED：7 用例 6 失败（empty/missing 平凡通过）
- GREEN-1：实现后发现两处缺陷——① `$nl` 声明前使用（JSON 段行分隔丢失）② bats 用例路径缺 `$FIXTURE_DIR` 前缀（RED 期笔误，`/independent-review-*.md` 恒不存在）
- GREEN-2：修正后 22/22 全绿；`#16` 断言放宽（`lib/l3-prompt.sh:137|` → 去尾管道：Symptom 原文为区间 `137-141`，保留区间忠实于源）

## 行为要点（D2/D3）
- L3 源：`## L3*` 段 ``` 围栏 JSON → `(.critical[]?/.major[]?)` 数组键即 severity；issue 取 `split("。")[0]` 首句；`gsub("\\|";"/")` 防字段污染
- L2 源：`## L2*` 段 `### 🔴/🟡 R<x> · 主题：一句话` + `**Symptom（症状）**：path:line ...` → emoji 字节序列 case 匹配（`printf '\xf0\x9f\x94\xb4'`）
- 排序：critical > major；同 severity L3 先于 L2；minor 不提取
- 每行 >200B 截 `${l:0:197}…`；文件缺失/两源皆空 → 空输出（AC-7 静默语义由调用方 T03 使用）
- `LC_ALL=C` 字节语义；`[ -f ]` 前置守卫

## 六维自查
- ✅ verify：`bats test/test_l3_pipeline_fix.bats` 22/22；`make check` 全绿（含 check-test-sync 双源）
- ✅ diff 边界 ⊆ write_files：l3-prompt.sh + test_l3_pipeline_fix.bats + test/fixtures/（TASK.md T02 声明集）
- ✅ 沿用既有抽象：utf8 helpers 不涉；jq 提取复用仓库 jq 依赖；无新依赖
- ✅ 禁动清单：未触碰 l3-review.sh / done 文件 / l3-truncate.sh / 29 号 / common.sh
- ✅ 无 `as any` 类 Bash 反模式：无 `2>/dev/null` 吞错于关键路径（jq 提取处容错属设计——畸形 JSON 降级为跳过）
- ✅ 注释：函数头块 = 文件既有约定；emoji 字节魔数注释必要

## 越界检查
`git status`：l3-prompt.sh / test_l3_pipeline_fix.bats / test/fixtures/×7 / flow-kit-bundle/test/ 镜像 ×8 —— 与 write_files 一致，无越界
