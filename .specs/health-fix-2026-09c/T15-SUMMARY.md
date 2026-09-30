# T15-SUMMARY — C14-c/h/i 测试态修复（AC-12-c/h/i）

任务：TASK.md T15（health-fix-2026-09c 阶段4 DEV）。执行范围 = 5 文件软跳过显式化（T05 权威名单）+ 2 附加测试文件（hook_integration 探针改行为断言 / runtime_edit_guard 不动）+ 删仓根 2 个历史 tarball。增量落盘：每文件「编辑 → grep 回验 → bats 真跑 → cp 镜像 → cmp 验证」独立完成。

## 1. 逐文件修复表（权威名单 5 文件）

| # | 文件（repo 相对路径） | 变体 | 修复形态 | bats 实跑 |
|---|---|---|---|---|
| 1 | test/test_l3_pipeline_fix.bats（:561 起用例重写） | ① 真空通过 | `[ ! -f "$HOME/..." ] ||`（缺件反而绿）→ 前置存在性检查 + `skip "环境面残留：…（用户级安装未部署），跳过安装态副本比对"`；cmp 侧从 CWD 相对路径改为 BATS_TEST_FILENAME 向上根查找（复用同文件 :549 范式） | 全文件绿 |
| 2 | test/test_independent_review_model.bats（:174-176） | ① + 显式 skip | skip 原已打印原因（合规形态）；补注释：安装态环境探针，判定值取 $HOME 安装态属固有语义，终态合规。逻辑零改动 | 13/13 绿 |
| 3 | test/test_guide_copy_parity.bats（installed dsh plugin 用例） | ④+② 间接赋值 | skip 消息增强（点名 $inst 不存在 + profile 名）；新增 `checked` 计数器堵「循环零比对空转绿」：两 rel 均缺 ⇒ `skip "…在场但 docs/ 与 vendor/ 均缺失，零比对不可判绿"` | 8/8 绿（用例级；文件内另有 1 预存红项，见 §5 偏差①） |
| 4 | test/test_l3_review_defects_2026_09.bats（:66-68 / AC2 内层 / :1013-1016） | ④+②；另 be138c0 硬编码 | ① 基线 commit 改 git 按主题行动态反查：`base_rev=$(git log --format=%H --grep="复测并修复 L3 审查链报告 5 条缺陷" -1)`，缺失 ⇒ report 带 `base_rev=MISSING` ⇒ 外层显式红（原形 ls-tree 失败 2>/dev/null 静默 → base_empty 恒 0 → ③ 恒真）；② B5-R3 dep=$HOME 赋值后落注释（三处 skip 均已打印原因，合规终态） | 124 ok / 0 fail |
| 5 | test/test_flow_active_integrity.bats（AC-1 user-scope 用例头） | tilde 展开（名单⑤，非软跳过修复形） | 前置 `[ ! -d "$HOME/.claude/flow-kit/prompts" ]` ⇒ 显式 skip（原因=用户级安装未部署）；count==8 断言本体不变（保留硬失败向） | 19/19 绿 |

## 2. 附加文件（T15 任务块 5+2 中的"+2"）

| 文件 | 处置 |
|---|---|
| test/test_hook_integration.bats（INT-HOOK-1/2，原 :15-44） | 4 处 `grep -q "source.*…" \|\| skip` 探针 → **子壳 source 编排器 + 哨兵函数行为断言**（`declare -f _gate_path_guard/_gate_check_l2/_gate_do_transition`、`_l3_build_prompt/_l3_call_api/smart_truncate/_l3_write_done`）；仓库源件缺失改硬红。3/3 绿。INT-HOOK-3 的文件存在 skip（:62）不在 :15-38 辖区且已显式打印原因 → 不动 |
| test/test_runtime_edit_guard.bats | 种子残留、不在权威名单、无软跳过问题 → **不动**（如实记录） |

## 3. tarball 删除（授权 = CHANGE What 14e）

- flow-kit-bundle.tar.gz（27,598,893 B，6 月 22 日）— 已删
- flow-kit-full-20260803-232437.tar.gz（25,661,479 B，8 月 3 日）— 已删
- 二者均未被 git 跟踪（git ls-files 空）→ 删除无 porcelain 痕迹；`ls *.tar.gz | wc -l` = 0

## 4. verify 真实输出

```
$ npx bats test/test_hook_integration.bats test/test_l3_review_defects_2026_09.bats \
    test/test_l3_pipeline_fix.bats test/test_independent_review_model.bats \
    test/test_runtime_edit_guard.bats test/test_guide_copy_parity.bats \
    test/test_flow_active_integrity.bats
… 1..223
not ok 197 guide parity: 仓内四份副本（root + bundle + dist×2）md5 唯一值 = 1
# (其余 222 用例 ok；失败详情见 §5 偏差①)
$ make check-test-sync
🔍 make check-test-sync: test/ ↔ flow-kit-bundle/test/ ...
✅ test 双源一致        (rc=0)
$ test "$(ls *.tar.gz 2>/dev/null | wc -l)" -eq 0 && echo OK   # → OK（0 个 tarball）
```

整链 `&&` 因 bats 腿 rc=1 中断（197 号预存红项）；后两腿已单独执行并记录如上。

## 5. 偏差（如实）

1. **verify 1/223 红 — 预存 dist 指南漂移，非本任务改动所致**：root 与 bundle 的 FLOW-KIT-用户指南.md md5 一致（654dd693…，mtime 今日 00:19，工作区已修改，非 T15 所改）；dist/dsh-flow-kit/docs/ 与 vendor/ 两副本 md5 886d1c81…（mtime 昨日 12:20，未跟踪构建产物）→ 有人改了指南未跑 make dsh-sync。修复动作（cp 指南入 dist / make dsh-sync）不在 T15 write_files 授权内 → 不代修，上报编排者。
2. **行号漂移**：权威名单（2026-09-29 实测）记 B5-R3 于 :972-981，本次实修时位于 :996-1052——按任务块「行号以现文实测为准」处理。
3. **INT-HOOK-3 skip 保留**：文件存在性显式 skip（带原因），在 :15-38 辖区外，未动。
4. **并行兄弟任务痕迹**：porcelain 中 quality_baseline / skills_sync 测试文件、pipeline-gates.md、common.sh、指南 ×2、.specs 若干为兄弟任务（T12c 等）改动，非 T15 所写；T15 未动它们。
5. probe D（`grep -rlF 'HOME夹具自包含'`）终态 = 权威 5 文件 × 主/镜像共 10 命中，无多余文件。

## 6. 六维内置快查

| 维度 | 状态 |
|---|---|
| ① 任务边界（只 T15） | ✅ 未动 TASK.md/CHANGE/.flow-active，未 git commit |
| ② 写权限（5+2+镜像+SUMMARY+删 tarball） | ✅ 12 个测试文件改动全部在授权集内 |
| ③ 防虚构（每步 grep 回验 + 增量落盘） | ✅ 每文件编辑后即回验/真跑/落镜像，无攒批 |
| ④ 镜像一致（cmp 逐字节） | ✅ 6 文件 × 主/镜像全 cmp 通过，check-test-sync 绿 |
| ⑤ verify 真跑（禁全量 make test） | ✅ 只跑指定 7 文件链；唯一红项为预存 dist 漂移（§5①） |
| ⑥ 偏差如实上报 | ✅ §5 五条，含 verify 红项根因与不越权处置 |
