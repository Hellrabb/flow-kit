# T05-SUMMARY · 全量回归清扫 + AC-4/AC-7 端到端 + AC-1 组合层顺序固化

## 交付物
- `test/test_l3_pipeline_fix.bats`：新增 4 个 T05 端到端用例（组合调用复刻 l3-review.sh:81-104 组装 `out="$(_l3_inject_context …)$(_l3_build_prompt …)"`）+ 双源镜像

## 回归清扫结果
- T04 后全量 `make check` 一次全绿——段序重排未破坏既有断言（T03/T04 轮内已同步修复全部受影响锚点：AC-5 段头正则、phase6 sed 提取契约、jq 模板断言、bats:106-132 disclaimer 锚）
- 本任务无产品代码改动（符合 TASK 卡"只修断言锚点"预期——实际零修）

## 新增用例（固化行为，绿色到位）
1. AC-4 e2e mixed：双 critical 单行摘要在场 + L3(test/l2-dispatch.bats) 先于 L2(lib/l3-prompt.sh:26)（grep -bo 字节位比较）
2. AC-4 e2e overflow：30 条 🔴 fixture → `(+k more)` 折叠 + 未响应标注 + 折叠标记字节位 < CHANGELOG 段位
3. AC-1 组合层顺序：mixed 反馈段（摘要 + 尾部 disclaimer 完整存活）字节位 < CHANGELOG 段位
4. AC-7 e2e：empty fixture → 组合输出无摘要/无未响应/无 severity 行；目录缺失 → inject 空输出

## 六维自查
- ✅ verify：`bats test/` 全量 **799 ok / 0 fail / 0 skip**（AC-6 基线数确立）；`make check` 全绿
- ✅ diff 边界 ⊆ write_files：仅 test/test_l3_pipeline_fix.bats（+镜像）
- ✅ 沿用既有抽象：`_build_phase7_tree` fixture helper（T03 期建）；grep -bo 字节位比较手法（AC-1 既有）
- ✅ 禁动清单：未触碰产品代码与 .done/审查子系统
- ✅ 反馈优先协议（ADR-025）：顺序断言固化了"反馈先于工件承受截断"
- ✅ 无越界：git status 与 write_files 一致

## 基线记录
- 全量：799（本 change 累计新增 43：T01×7 + T02×7 + T03×11 + T04×5 + T05×4 + 修复改写既有 9）
- AC-6 断言口径：无 fail/skip（不锁固定总数）

## 勘误（phase 5 · L2 R1）

本 SUMMARY「全量 bats 801 ok / 0 fail / 0 skip」表述失实：bats TAP 的 skip 报告为行尾 `ok N ... # skip`，原统计口径未检出。实际 = 800 pass + 1 skip（`test/test_lessons_cleanup.bats:137`，既有、非本 change 引入）+ 0 fail。本 change 新增用例 39/39 全绿无 skip。详见 TEST.md §1.3（已修正）与 INDEPENDENT-REVIEW-5.md R1。
