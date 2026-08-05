# CHANGE: 7-integration 归档后 commit 门禁（prompt + pre-commit hook + Stop hook 兜底）

- **Change ID**: archive-commit-gate
- **创建日期**: 2026-08-05
- **路径建议**: 完整（涉及 prompt + reference + install + 新 hook 模块）
- **状态**: draft

---

## Why（为什么做）

`7-integration.md` 步骤 5（归档）完成后**没有任何 git commit 步骤**——只做 `mv archive/` + CHANGELOG + STATE + L-013 双向校验。`commit-protocol.md`（来自 `cleanup-debt-batch-2026-08` L-068）是 4-dev **任务级**提交协议（每 task 完成后 commit + task_progress 记 commit_sha），与归档级 commit 无关。

**实证（l2-l3-subagent-fix · 2026-08-05）**：pipeline 0→7 全 pass、归档 mv 完成、CHANGELOG/STATE/LESSONS 全更新后，6 个文件未提交（源码修复 + archive/ 30 files + 元数据 4 文件）。用户主动问「git 都 commit 了嘛」才发现 gap——AI 做完归档步骤自然停止，不会 commit。

同时 `LESSONS.md` L-023（2026-08-03）记录「commit-time 测试门禁缺失」：commit `0c79f1c` 提交时 4 个 bats fail 已存在但被允许通过。建议 pre-commit hook 跑 `make test` 硬门禁，但至今未实施。

**用户判断**：「之前做过类似增强但效果一般」——指 commit-protocol.md 仅覆盖任务级，归档级无覆盖；且 commit 门禁（L-023）一直 deferred。

## What（做什么）

三层加固，闭合「归档后不 commit」+「commit 不跑测试」两个 gap：

1. **prompt 层**（7-integration.md）：步骤 5 归档后新增步骤 5.1「归档 commit」——按类型拆分（fix 源码修复 / docs 归档产物 / chore 元数据同步），复用 commit-protocol.md 的原子提交原则；PCSC 自检表新增「git status 干净」检查项（未 commit → PCSC ❌ → 禁止完成 pipeline）。
2. **门禁层**（pre-commit hook · L-023 闭合）：`make test` 硬门禁（bats 非零退出码 → 拒绝 commit）；通过 `install.sh` 部署 `core.hooksPath` 到 flow-kit 管理的 hooks 目录（`.git/hooks/` 不入仓库的解法）。
3. **Hook 兜底**（新 Stop hook 模块）：检测归档完成（`goal.status=done`）但 `git status` 非干净 → 写 correction file（type=archive-uncommitted），SessionStart 收割提示。

## 影响面

- [ ] 影响 `REQUIREMENT.md`
- [x] 影响 `DESIGN.md` / 引入新 ADR（pre-commit hook 部署策略 + Stop hook 模块边界需 ADR）
- [ ] 影响现有 AC（写出哪些）
- [ ] 影响数据模型 / 迁移
- [x] 影响外部 API 兼容性（pre-commit hook 改变用户 git commit 行为，需向后兼容）
- [ ] 仅修复 bug，无范围变化

## 范围排除（这次不做）

- 不改 4-dev commit-protocol.md（任务级提交协议保持不变）
- 不自动 push（push 是副作用，涉及 remote 权限/网络/CI 触发，归 v2）
- 不改 gate 核心链（independent-review-gate.sh + 29-independent-review.sh + fk_validate_done_marker 不触碰）
- 不加 commit message lint（Conventional Commits 格式校验归单独 change，本 change 只保证「commit 发生」）
- 不改其他 prompt 的 commit 指引（仅 7-integration 归档段）

## 验收线（粗粒度，不是 AC）

- 归档完成后 AI 自动执行 commit（不再依赖用户提醒），按类型拆分 ≤3 个原子提交
- commit 前自动跑 `make test`，bats fail 时拒绝 commit 并提示
- 归档后若 git status 非干净（AI 漏 commit），Stop hook 写 correction，下一会话 SessionStart 提示补 commit

## 风险与未知

- **pre-commit hook 部署**：`.git/hooks/` 不入仓库。需选部署策略——`git config core.hooksPath <flow-kit-managed-dir>`（推荐，install.sh 设置）vs symlink farm vs husky 等价物。各有取舍，DESIGN 阶段定。
- **`make test` 性能**：当前 692 bats，全套跑约 30-60s。pre-commit 每次跑全量可能影响 commit 体验。可选：只跑 `make check`（test+lint+打包校验）或按 staged files 增量。DESIGN 阶段权衡。
- **Stop hook 新模块编号**：当前 Stop 链 00-33 + 99。新模块编号待定（34-archive-commit-check.sh？），需与 33-flow-active-integrity 的 `.flow-active` 字段检测边界划分（33 查字段完整性，新模块查 git status）。
- **pipeline 模式 vs 单阶段模式**：归档 commit 步骤对单阶段模式（非 pipeline）是否适用？7-integration 在两种模式下都走步骤 5 归档，应统一覆盖。
- **commit 粒度自动化**：按类型拆分需要 AI 判断哪些文件属「源码」vs「归档产物」vs「元数据」。是否可机器化（git diff --stat 分类）？还是纯 prompt 指引？DESIGN 阶段定。

---

> 后续 AC 与设计细节进入 `REQUIREMENT.md` / `DESIGN.md`，本文件不再扩展。
