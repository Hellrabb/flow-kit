# 独立审查 · 阶段 1

---

## L2 盲审

### 🔴 R1 · CHANGE.md 拆分方案与 REQUIREMENT AC 直接冲突（目标文件与拆分函数不一致）
**Symptom（症状）**: `CHANGE.md:21` — 「提取 `_l3_call_api()` + `_l3_parse_result()` + 相关常量到新文件 `l3-callparse.sh`」；REQUIREMENT `AC-B1:46` / `AC-C1:66` — 「smart_truncate() 已移出 l3-api.sh 到 l3-truncate.sh」，且 `AC-A1:26` 的 4 文件清单（l3-api.sh / l3-truncate.sh / gate-helpers.sh / gate-helpers-types.sh）**不含 l3-callparse.sh**。
**Source（源头）**: 两份治理文档对「拆什么、拆到哪」定义不同。实证：磁盘上 `l3-truncate.sh` 已存在（54 行，仅含 `_l3_check_rerun()`），`smart_truncate()` 现定义于 `l3-api.sh:18`（跨 18–167 行，约 150 行）；而 `_l3_call_api()` 在 `l3-api.sh:168`、`_l3_parse_result()` 在 `l3-api.sh:264`。按 CHANGE.md 计划 l3-callparse.sh 必须新建；按 REQUIREMENT 计划该文件不存在、改为把 smart_truncate 塞进既有 l3-truncate.sh。两份文档无法同时执行。
**Consequence（后果）**: 实施者按任一文档执行都会违反另一文档的 AC。若按 CHANGE.md 建 l3-callparse.sh，AC-A1 的「4 文件已写入磁盘」与 AC-B1/AC-C1 的「smart_truncate 移至 l3-truncate.sh」不成立；若按 REQUIREMENT 只移 smart_truncate（150 行，l3-api 剩 ~222 行，算术上达标），则违反 CHANGE.md §1 的既定设计引用（§1.9(b)）。验收阶段必 fail 其一。
**Remedy（修补）**: 在进入下一阶段前仲裁：删除 CHANGE.md §1 的 l3-callparse.sh 方案或改写 REQUIREMENT AC-B1/AC-C1/AC-A1 至两份文档指向同一目标文件与同一组迁移函数。另注意 AC-C1 的「函数定义在新位置出现一次」grep 断言——l3-api.sh 头部注释（:9/:13/:14）现仍含 `smart_truncate` 字样，迁移后若注释残留会使精确计数断言脆弱，应改为 `grep -c '^smart_truncate()'` 或约定清理注释。

### 🔴 R2 · AC-A2「精确 662」与 v1 范围「新增 4 个 metrics 测试」自相矛盾，验收线不可达成
**Symptom（症状）**: `REQUIREMENT.md:33-34` — `When` 执行 `npx bats test/ 2>&1 | tail -3`，`Then` 输出含 `662 tests` 和 `0 failures`（「数字精确匹配，不接受范围」）；同文档 `:122` v1 范围明确「4 个新 metrics bats 测试」（AC-B1/B2/B3 验证方式均引用 `test_health_metrics.bats`）。
**Source（源头）**: 基线 662 是实施前状态（实测 `test/test_health_metrics.bats` 不存在，4 个测试纯新增）。新增 4 个测试后套件必然为 666，精确 662 断言必然失败。AC-A2 与 v1 范围在数字层面互斥，属「条件 AC 未拆 hard/soft」——违反 ADR-019 写作原则（AC 必须确定性、不得自相矛盾）。
**Consequence（后果）**: 无论实施与否：新增测试 → AC-A2 fail；不新增测试 → AC-B1/B2/B3 的验证测试不存在、v1 范围违约。验收判据自锁，change 不可收尾。
**Remedy（修补）**: 将 AC-A2 改为「`Then` 输出含 `0 failures` 且 `tests` 数 ≥ 662」（回归下限），精确 662 改为实施前快照断言或由 DESIGN 记录实施后实际数（666）再精确化。新增 4 个 metrics 测试作为独立 AC 断言，不混入同一行。

### 🔴 R3 · AC-B3「find 全目录 ≤250」与既有 5 个超限文件 + Out 范围冲突，按现状不可达成
**Symptom（症状）**: `REQUIREMENT.md:59-60` — `find flow-kit-bundle/hooks/stop/lib flow-kit-bundle/hooks/pre-tool-use -name '*.sh' -exec wc -l {} + | sort -rn | head -5`，`Then` 第一列所有数值 ≤ 250。
**Source（源头）**: 实测两个目录下 `head -5` 将命中（按行数降序）：`flow-kit-artifacts.sh` 374、`l3-api.sh` 372（本 change 拆分后下降）、`weak-model-compliance.sh` 353、`common.sh` 350、`l2-detect.sh` 302、`fix-compliance.sh` 302——其中 5 个文件（374/353/350/302/302）远超 250 且**不在本 change 拆分范围**（v1 仅拆 l3-api.sh + gate-helpers.sh；:127 v2 明确「TD-072 之外的 file-level 长度优化」留 v2，:130 Out 声明「任何调用方代码修改」）。
**Source（源头，续）**: AC-B3 的 find 范围（两目录全部 .sh）与范围决策（只拆 2 个文件）矛盾——AC 断言了整个目录树的属性，但 change 只负责其中 2 个文件的属性。
**Consequence（后果）**: 验收时 find 会输出 5+ 个超限既有文件，AC-B3 必 fail，且无法通过本 change 修复（会扩大范围违约 Out 声明）。
**Remedy（修补）**: 将 AC-B3 的 When 限定为本 change 触碰的文件集合（如 `for f in l3-api.sh l3-truncate.sh gate-helpers.sh gate-helpers-types.sh; do wc -l ...`），或明确「≤250 仅约束本次新建/变更文件」，并把「全目录 ≤250」改为长期目标项（关联既有超限文件的技术债），避免 AC 越界。

### 🔴 R4 · AC-C2「调用方不变更」与 AC-C3「orchestrator 新增 source gate-helpers-types.sh」互斥
**Symptom（症状）**: `REQUIREMENT.md:74` — AC-C2 `Then` 要求「调用方（如 independent-review-gate.sh、test_*.bats）不变更」；`REQUIREMENT.md:80` — AC-C3 `Then` 要求「independent-review-gate.sh sources gate-helpers.sh + **gate-helpers-types.sh** + gate-checks-basic.sh + gate-checks-review.sh」。US-3（:14）同时承诺「source + 调用语句不需修改」。
**Source（源头）**: 实测 `independent-review-gate.sh:42-46` 现仅 source gate-helpers.sh / gate-checks-basic.sh / gate-checks-review.sh（不含 gate-helpers-types.sh）。6 个谓词（`_is_dotdone_write` / `_gate_is_l2_only` / `is_phase_write` / `_fk_phase_direction` / `_command_has_write_context` / `is_git_commit`，全部存在于 gate-helpers.sh 现文件）移出后，orchestrator 要能调用它们只有两条路：(a) 直接 source 新文件 → 调用方文件被改，违反 AC-C2/US-3；(b) gate-helpers.sh 改为聚合入口（source + re-export）→ 调用方不变，但 AC-C3 的 source 清单则错误（不应列出 gate-helpers-types.sh）。两条路必然违反其中一个 AC。
**Source（源头，续）**: CONTEXT 既有「聚合入口模式」已给出本项目既定解法（主文件 source 子库 + re-export，外部调用方 source 路径零变更）——AC-C3 与既有模式相悖。
**Consequence（后果）**: 实施选择任意一条路径都会在 6-review 验收时被另一 AC 判 fail；4 个直接 source 这些 lib 的测试文件（test_gate_integrity / test_hook_integration / test_l2_pretooluse_dispatch / test_l3_pipeline_fix）也会连带失效或需改动。
**Remedy（修补）**: 二选一并同步修正：若采纳聚合入口模式（推荐，符合既有先例与 US-3），AC-C3 的 orchestrator source 清单改为「gate-helpers.sh（内部 source + re-export gate-helpers-types.sh）」；若坚持 orchestrator 直连子库，则删除 AC-C2「调用方不变更」与 US-3 的 source 不变承诺，并显式把「independent-review-gate.sh 加一行 source」列入 v1 变更范围。

### 🟡 R5 · AC-A1 验证方式引用不存在的已有测试文件
**Symptom（症状）**: `REQUIREMENT.md:29` — 「验证方式: bats 测试 `test_health_lints.bats::"bash -n passes on all hook libs"`（**已有**测试自动覆盖目录下全部 .sh）」。
**Source（源头）**: 实测 `test/` 下无 `test_health_lints.bats` 也无 `test_health_metrics.bats`（`ls test/test_health*` 为空）。bash -n 自动发现测试真实存在，但文件名与用例名是 `test/test_smoke_syntax.bats::"AC-4: 所有生产 .sh 脚本通过 bash -n 语法检查"`（实测其用 `find . -name '*.sh'` 全仓自动发现，新文件确实会被覆盖）。
**Consequence（后果）**: 实施者按 AC 查找 test_health_lints.bats 将扑空；「已有」标注误导后续验证阶段引用错误工件；bash -n 覆盖这一真实防线被错误归因。
**Remedy（修补）**: 将 AC-A1 验证方式改为引用实际存在的 `test/test_smoke_syntax.bats::AC-4`（或明示 test_health_lints.bats 为本 change 新建而非已有）。

### 🟡 R6 · AC-D1 全文件 grep 无法强制「禁动清单段」位置，易假绿
**Symptom（症状）**: `REQUIREMENT.md:87-88` — `When` 执行 `grep -E 'gate-helpers-types|gate-helpers\.sh|gate-checks-basic|gate-checks-review' .specs/CONTEXT.md`，`Then` 要求「4 个文件名均在禁动清单『hook 校验核心链』段出现」。
**Source（源头）**: grep 作用于整个 CONTEXT.md，而实测其中已有非禁动清单的命中行：技术债表 TD-018 行与术语表「hook lib split (gate)」行已含 `gate-helpers.sh` / `gate-checks-basic.sh` / `gate-checks-review.sh` 三个名称。即使禁动清单完全不更新，4 个名称中 3 个也已可命中；`gate-helpers-types.sh` 当前零命中——现状态即处于「3/4 命中但禁动清单全未更新」的假绿态。
**Consequence（后果）**: AC-D1 无法区分「文件名出现在技术债表/术语表」与「出现在禁动清单」，文档不同步（US-4 目标）在 grep 层不可验证，health 扫描复发的防护失效。
**Remedy（修补）**: 缩小 grep 范围到禁动清单段落锚点，例如 `sed -n '/## 禁动清单/,/## 项目结构/p' .specs/CONTEXT.md | grep -E ...`，使断言与实际位置强绑定。

### 🟢 R7 · CHANGE.md 行数基线陈旧（371/253，实测 372/254）
**Symptom（症状）**: `CHANGE.md:11-12` — 「l3-api.sh 371」「gate-helpers.sh 253」。
**Source（源头）**: 实测 `wc -l` 输出 l3-api.sh=372、gate-helpers.sh=254（尾行无换行符差异所致）。REQUIREMENT 的 AC-B1/B2 阈值以 `wc -l` 第一列为准（实测数），故 AC 本身不受影响，仅背景表数字过时。
**Consequence（后果）**: 差距列（-121/-103）与实际（-122/-104）不一致，数值核对时产生轻微困惑，不影响验收。
**Remedy（修补）**: CHANGE.md 行数表更新为实测值 372/254，或标注「wc -l 含尾换行」。

---

**Verdict**: fail

---

## 主 agent 响应

所有 7 个 finding 均为真实问题，已全部修复：

### R1（CHANGE↔REQUIREMENT 冲突）· Fixed
- **Fixed in**: `CHANGE.md:14-25` 重写为「smart_truncate → 既有 l3-truncate.sh」+「gate-helpers.sh 改聚合入口」方案，与 REQUIREMENT AC-B1/AC-C1/AC-A1 完全对齐。l3-callparse.sh 方案废弃（既有 l3-truncate.sh 容量充足，避免文件增殖）。
- **R1 附注「注释残留」**: 已记入 DESIGN todo，实施时清理 l3-api.sh 头部注释中的 smart_truncate 字样，AC-C1 grep 改用 `^smart_truncate()` 锚定函数定义。

### R2（662 vs 666 自相矛盾）· Fixed
- **Fixed in**: `REQUIREMENT.md:33-36` AC-A2 改为 `tests 数 ≥ 662 / 0 failures`，范围决策追加「AC-A2 数字: ≥662 / 0 fail（不精确匹配）」显式归因 ADR-019。

### R3（AC-B3 find 全目录 ≤250 与 Out 冲突）· Fixed
- **Fixed in**: `REQUIREMENT.md:55-60` AC-B3 重写为「本 change 触碰的 4 个 lib 文件 ≤ 250 行」，When 改为 4 文件 wc -l 循环；新增「范围说明」段标注既有 5 个超限文件（flow-kit-artifacts.sh / weak-model-compliance.sh / common.sh / l2-detect.sh / fix-compliance.sh）按 v2 处理。

### R4（AC-C2 vs AC-C3 互斥）· Fixed
- **Fixed in**: `REQUIREMENT.md:74-83` 采用聚合入口模式（CONTEXT.md 既有抽象）。AC-C2 改为「定义在新位置」（grep 函数定义次数）；AC-C3 改为「gate-helpers.sh 内部 source gate-helpers-types.sh + 外部调用方零直接 source」双断言。范围决策追加「聚合入口」条目归因既有先例。

### R5（AC-A1 引用不存在的测试文件）· Fixed
- **Fixed in**: `REQUIREMENT.md:29` AC-A1 验证方式改为 `test/test_smoke_syntax.bats::"AC-4: 所有生产 .sh 脚本通过 bash -n 语法检查"`（实测存在，自动发现全仓 .sh）。

### R6（AC-D1 全文件 grep 假绿）· Fixed
- **Fixed in**: `REQUIREMENT.md:87-90` AC-D1 When 改为 `sed -n '/## 既有抽象索引/,/## 项目结构/p' .specs/CONTEXT.md | grep -E ...` 段内锚定，规避技术债表/术语表的假绿命中。

### R7（行数基线陈旧）· Fixed
- **Fixed in**: `CHANGE.md:11-12` 行数表更新为实测 372/254。

**重新评审请求**: 已修复 4 🔴 + 2 🟡 + 1 🟢，请重新判定 verdict。
