# 独立审查 · 阶段 5

## L2 盲审（phase 5）

**审查时间**: 2026-08-06T16:20:00+08:00
**verdict**: pass

### 实证验证结果（先于发现呈现，作为判定依据）

1. `npx bats test/test_archive_commit_gate.bats --filter 'deploy_pre_commit'` → 4/4 ok（2 既有静态 grep + 2 新增行为测试）
2. `npx bats test/` 全量 → **716 ok / 0 not ok / exit 0**（写 /tmp/opencode/bats-full.log 复核：`grep -c '^not ok'` = 0，`grep -c '^ok '` = 716）
3. 新增 user scope 正向测试是**判别性测试**（非假绿）：修复前 guard `[[ -d .git ]] || return 0` 前置，user scope 直接 return → 源文件不装 → `[ -f "$tmp_home/.claude/hooks/pre-commit/pre-commit.sh" ]` 必失败。此测试在修复前真实红
4. 冲突块逐字保留实证：`git show b8cda56 -- flow-kit-bundle/lib/install_hooks.sh`，diff 仅含 guard 后移 + `mkdir` 行拆分为两处（`.git/hooks` 与 `$hook_dst/pre-commit` 分别由 mkdir / install_file 处理），`if [[ -e "$target" && ! -L "$target" ]]` → FLOW_KIT_YES skip / read -p / `ln -sf` 整块零改动
5. UAT-1 可执行性实证：`--platform`（install.sh:115）/ `--global`（:116）/ `--user`（:125）参数全部受支持，UAT-1 命令可直接运行
6. 修复后源码核对（install_hooks.sh L38-61）：L40 无条件 install_file（AC-1 Then 1）→ L43 guard 后移（AC-1 Then 2/3）→ L45-46 仅项目级 mkdir `.git/hooks` → L48-57 冲突检测 → L59 symlink。与 REQUIREMENT AC-1 逐条吻合

### 发现

#### #1 [🟢 Minor] 回归登记"既有 19 tests"数字不准确
**source**: TEST.md:54
**symptom**: 回归登记写"既有 19 tests 不变（test_archive_commit_gate.bats T01-T07 段）"，但实测该文件共 24 个 `@test`（`grep -c '@test'` = 24），既有 22 + 新增 2
**consequence**: 文档数字与事实不符，后续全量计数核对（714→716）时会造成基线困惑；不影响绿声明真实性（716/0 已实证），但属于可验证声明失真
**remedy**: 将"既有 19 tests 不变"改为"既有 22 tests 不变（T01-T07 段 22 条 + 新增 2 条）"，或删除具体数字改为"既有测试未修改"

#### #2 [🟢 Minor] AC-1 冲突检测分支无行为测试（已如实披露）
**source**: TEST.md:20
**symptom**: AC 矩阵"AC-1 (冲突检测)"标记"无行为测试（冲突块逐字保留 + 全量回归兜底）⚠️ 保留依赖"。实证冲突块在 b8cda56 中零改动，兜底成立；但 FLOW_KIT_YES=1 skip 与 read -p 交互覆盖两分支仍无行为断言（既有 `--yes flag present` 测试仅为静态 grep）
**consequence**: 若未来某 change 破坏冲突检测（如误删 read -p 分支），测试矩阵无任何行为测试能捕获，仅靠人工 UAT。当前风险低（本 change 未触碰该块），属存量测试缺口而非本次引入
**remedy**: 可接受（披露 + 实证兜底），建议在 MINOR-DEFERRED.md 登记；后续若改冲突块，需补 FLOW_KIT_YES=1 skip 行为测试

#### #3 [🟢 Minor] 新增测试断言失败路径不清理临时目录
**source**: test/test_archive_commit_gate.bats:131-143, 145-158
**symptom**: 两个新测试的 `rm -rf "$tmp_home"/"$tmp_repo"` 位于全部断言之后，bats 无 `set -e`，任一断言失败 → rm 不执行 → /tmp 泄漏
**consequence**: 测试失败时残留 mktemp 目录，长期积累 /tmp 垃圾；不影响测试正确性（bats 子 shell 隔离 export 不泄漏）
**remedy**: 用 `teardown()` 统一清理，或 `trap 'rm -rf "$tmp_home"' EXIT`；本文件既有测试同样模式，属存量风格，可合并到下次测试清理

### 合规核对（其余检查点）

- **AC 矩阵覆盖**：AC-1 user 正/负 ✓（#1 测试双断言：`! -d` + `! -e` 均实现，对应 AC-1 Then 2/3）、AC-1 project ✓（源文件 + `-L` + readlink 三断言，对应 AC-1 project Then 1/2）、AC-2 ✓（回归锚点声明，由 project 块覆盖，符合 REQUIREMENT 语义）、AC-3 ✓（716 ok / 0 not ok 实证）。AC-1 冲突检测缺失见 #2
- **测试真实性**：真实执行 `deploy_pre_commit()` + 真实文件系统断言，判别性测试修复前必红，无假绿
- **覆盖率数据**：baseline 714 → current 716 → delta +2，与全量实测 716/0 完全一致 ✓
- **范围声明 5 轮**：功能必跑 / 性能跳过（非热路径，符合 CONTEXT 安装脚本容忍度决策）/ 安全 N/A（无外部输入，read -p 为既有交互）/ 兼容 bash -n + bats / 可观测 N/A，理由均成立 ✓
- **六维自检 T1-T6**：全部 0 命中且理由与 change 类型一致（有源码修改 → T1 不触发；仅新增测试 → T2 不触发）✓
- **UAT-1**：Given/When/Then 可脚本化，参数实证受支持，预期行明确（修复前 ❌ missing）✓

**Verdict**: pass

---

## 主 agent 响应（L2 round 1 verdict=pass · 3🟢 全处置）

### 🟢 #1（回归登记 19 vs 22）→ Fixed
TEST.md L54 「既有 19」改为「既有 22」（实测 @test 计数：24 总 = 22 既有 + 2 新增）。

### 🟢 #2（冲突检测无行为测试）→ Deferred
入 MINOR-DEFERRED P5-#2。冲突块逐字保留（git show b8cda56 实证）+ 全量 716 回归兜底。

### 🟢 #3（tmp 清理）→ Deferred
入 MINOR-DEFERRED P5-#3。极小影响。
