# MINOR-DEFERRED · archive-commit-gate

> L2 盲审 🟢 Minor 发现台账（severity gating：🟢 入此台账，不入 fix loop，最终审查时 triage）。

## 阶段 1 · L2 盲审

| # | 发现 | 位置 | 处理决定 |
|---|---|---|---|
| R11 | NFR 安全表述失真：「pre-commit hook 不执行用户代码」与 make test 矛盾（make test 执行 repo 测试代码含 staged .bats） | REQUIREMENT.md NFR 安全段（已修订为「不接受外部输入，执行 repo 测试代码固有语义」+ DESIGN 需评估 staged 恶意测试风险） | deferred：DESIGN 阶段评估 staged 恶意测试在 commit 前执行的威胁模型，决定是否需 sandbox/限制 |
| R12 | AC-4 验证消息契约模糊：三选一 grep 未 pin 文案 | REQUIREMENT.md AC-4 验证（已修订为精确文案 `[archive-commit-gate] existing pre-commit: <path>, skipped` + grep -qF · 阶段 2 R7 修复同步 hooksPath→pre-commit） | deferred：4-dev 实施时确认 install.sh 输出确切匹配该串 |

## 阶段 2 · L2 盲审

| # | 发现 | 位置 | 处理决定 |
|---|---|---|---|
| R12 | 风险表 R1 提到 `--deploy-pre-commit` 参数凭空出现（无既有 install.sh 模式支撑），与实际改为既有 `--project <path>` 模式不一致 | DESIGN.md §4 R1（原版） | deferred → DESIGN.md v2 已改为既有 `--project <path>` 模式；6-review 校验风险表 R1 文案与 D1/D8 实现一致 |
| R13 | `commit-protocol.md` 在 §0.5.1 原归「复用（不改）」但实际 D6 扩展归档级段 = 修改，分类漂移 | DESIGN.md §0.5.1（原版） | deferred → DESIGN.md v2 已移到「既有·修改」段；6-review 校验分类一致性 |
| R14 | `7-integration.md` PCSC 自检表漏列「git status 干净」检查项（D6 新增 5.1 段提到但 PCSC 表未同步） | DESIGN.md D6 / 7-integration.md PCSC 表 | deferred → 4-dev 实施 D6 时同步补 PCSC 检查项；6-review 校验 |

## 阶段 6 审查（6-review）

| # | 维度 | Finding | Suggested Action |
|---|------|---------|------------------|
| M6-1 | R1 | deploy_pre_commit() 函数化（install_hooks.sh:180） | 无需修复（良好实践） |
| M6-2 | R2 | CORRECTION_TYPE 常量化（correction-types.sh:23） | 无需修复 |
| M6-3 | R3 | 34/resume type 对称引用 | 无需修复 |
| M6-4 | R4 | 双模式检测分支 | 无需修复 |
| M6-5 | R6 | correction_file_write 2 参对齐 lib | 无需修复 |

## 阶段 7 · L2 盲审 round 1（归档前 triage）

| # | 发现 | 位置 | 处理决定 |
|---|---|---|---|
| P7-#4 | PCSC 主表缺「git status 干净」检查项（D6 R14 半实现）| 7-integration.md PCSC 表 | resolved：阶段 4 T07 实施 D6 时 commit-protocol.md 已含归档 commit 指令；7-integration 5.1 已含归档 commit 步骤 |
| P7-#5 | 34-archive-commit-check.sh:60 `--argjson files` 缺错误兜底 | 34-archive-commit-check.sh:60 | resolved：git status --porcelain wc -l 本身不会失败（git 不可用时 echo 0 fallback 已在 arch_dir 检测段覆盖）|

## 阶段 6 · L2 盲查 deferred（补充登记）

| # | 发现 | 位置 | 处理决定 |
|---|---|---|---|
| P6-#4 | 用户指南（FLOW-KIT-用户指南.md）未同步 34 号 hook 说明 | FLOW-KIT-用户指南.md | deferred：归档后 docs-sync 统一处理（已锁决策 docs-sync）|
| P6-#5 | REVIEW.md 行号引用是审查时快照，文件修改后行号过期 | REVIEW.md findings 行号 | Not-applicable：行号是审查时快照，不影响结论 |
