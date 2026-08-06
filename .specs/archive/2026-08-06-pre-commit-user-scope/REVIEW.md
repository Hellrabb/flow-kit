# REVIEW: pre-commit-user-scope

## review-package

- base: `b8cda56^`（pre-commit-user-scope 唯一 commit b8cda56 的父）
- commits: 1（b8cda56 fix(install): deploy_pre_commit guard 后移修复 user scope 源文件安装）
- diff: install_hooks.sh deploy_pre_commit guard 位置 + test_archive_commit_gate.bats +2 行为测试

## A. spec 合规

| AC | 实现 | 验证 |
|---|---|---|
| AC-1 (user scope) | install_file 无条件前置 + guard 后移 | bats user scope 测试正负断言 ✅ |
| AC-1 (project scope) | symlink 逻辑完全保留 | bats project scope 测试 symlink + readlink ✅ |
| AC-2 (回归锚点) | 项目级行为由 AC-1 覆盖 | 声明锚点 + 测试覆盖 ✅ |
| AC-3 (bats 全绿) | +2 行为测试 | 716 ok / 0 fail ✅ |

**out of scope 遵守**：pre-commit.sh 内容未碰 / core.hooksPath 未碰 / opencode 原生路径未碰。✅

## B. 代码质量 6 维

| 维度 | 评估 | 发现 |
|---|---|---|
| R1 可读性 | ✅ | guard 后移 + 2 行注释说明两段式语义（防回归）|
| R2 复杂度 | ✅ | deploy_pre_commit 保持单一职责（源文件安装 + symlink 接线）|
| R3 重复 | ✅ | install_file 沿用，无新重复 |
| R4 命名 | ✅ | 无新命名（沿用 deploy_pre_commit / install_file / $project / $hook_dst）|
| R5 测试覆盖 | ✅ | +2 行为测试（user scope 判别性 + project scope 回归）|
| R6 安全 | ✅ | 无新攻击面（guard 位置调整不改安全语义；conflict 检测保留）|

## C. UI

N/A（非前端项目）

## D. verdict

**pass**（0 🔴 / 0 🟡 / 全 🟢）

理由：bugfix 精准修复 guard 位置缺陷，符合 DESIGN §2 D1 两段式拆分设计；冲突检测逐字保留（git show 实证）；+2 判别性行为测试覆盖 AC-1；全量 bats 716/0 无回归。

## MINOR-DEFERRED triage

- P5-#2（冲突检测无行为测试）：保留依赖，低风险（冲突块逐字保留 + 全量回归）
- P5-#3（tmp 清理）：极小影响，可选改进
