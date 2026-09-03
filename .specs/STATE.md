# STATE — 项目状态

- **last_intel_scan**: `2026-06-17`
- **last_evolve_at**: `2026-07-08`（完整 · 两轮，扫 29/29 个 change）
- **last_architect_at**: `2026-07-08`（首跑 · 9 ADR + 模块清单 + 跨模块契约）
- **last_change_archived**: `user-guide-sync-2026-09`（2026-09-03 · 内容同步型 · 6 阶段（1/2/3/5/6/7）L2+L3 全 pass · 770/0 bats · 指南 2026-09-03 + deck 20 页重建）
- **last_evolve_promoted**:
  - auto-checkpoint-hook
  - 2026-06-08-init-git-repo
  - 2026-06-08-offline-brooks-bundle
  - 2026-06-09-user-scope-install
  - 2026-06-16-health-fix
  - 2026-06-18-integrate-goal-command
  - 2026-06-22-bundle-packaging
  - 2026-06-25-weak-model-robustness
  - 2026-06-29-lessons-cleanup
  - 2026-06-29-quality-baseline
  - 2026-06-29-robustness-hook-hardening
  - 2026-07-01-health-fix-2026-07
  - 2026-07-01-improve-independent-review
  - 2026-07-01-independent-review
  - 2026-07-01-sweep-fix-2026-07
  - 2026-07-02-independent-review-gap
  - dual-review-merge-fix
  - flow-active-integrity
  - gate-integrity
  - goal-pipeline-phase0
  - l2-l3-fix-compliance
  - l2-l3-granular-gate
  - l3-comprehensive-fix
  - l3-feedback-visibility
  - phase-skip-fix
  - pipeline-fallback-fix
  - pipeline-goal
  - pipeline-rollback-phase0
  - user-guide-update
  - weak-model-interactive-ui
- **context_file**: `.specs/CONTEXT.md`
- **detected_stack**: `Bash 脚本项目（flow-kit 分发包仓库）— 无传统技术栈（无框架/无 DB/无前端/无后端）`
- **project_type**: `meta / distribution`
- **git_repo**: `true`
- **default_branch**: `main`
- **commit_convention**: `Conventional Commits`
- **test_framework**: `bats-core 1.13.0 (npx) · 657 tests (656 pass + 1 skip L-071) / 2 fail pre-existing AC-I b/c · 32 new tests from superpowers-v6-absorb)`
- **ci_cd**: `未检测到`

---

## 待办备忘（来自 superpowers-v6-absorb 后续技术债）

### 顺手修（下次相关 change 实施时一并做 · 不需独立 pipeline）

- **L-058** · AC-A3 "如可用" 弱化 → 下次改 `1-requirement.md` prompt 时拆为 AC-A3a (Linux 硬) + AC-A3b (macOS 软)
- **L-060** · 范围决策嵌入 REQUIREMENT → 下次写 REQUIREMENT 时把"双轨测量 / spot-check 语义 / task_progress vs SUMMARY"3 段从 REQUIREMENT.md 移到 CHANGE.md 验收线段
- **L-062** · task_progress lifecycle 图细节 → 下次改 `4-dev.md` 时在 DESIGN.md 图注释加"skip task 时 task-brief 不调用，task_progress 该项写 `{id, skipped: true}` 或省略"

### 待触发清单（需实测数据 · 不能闭门造车）

- **L-063** · D5/D6 弱模型场景退化 → 触发条件：用 minimax-m2.7 / qwen3.6-35b-a3b 实际跑一次 pipeline，观察 terse contract / narration constraint 是否被忽略。**实测前不加护栏**（违反 superpowers v6 反对的"重复唠叨"）
- **L-066** · AC-B4 测试深度 → 触发条件：先在下次 REQUIREMENT 改造时澄清 AC-B4 措辞（明确"task-brief 输出 ≤15KB" vs "4-dev.md + task-brief ≤15KB"），然后补测试

### 计划修（独立 change · 已开工）

- **superpowers-absorb-followup-1** (in pipeline · 2026-08-03 起) — 覆盖 L-064 (安全注入测试) + L-065 (集成测试自动化) + L-067 (AC-I b/c pre-existing 修复)
- **compress-4-dev-prompt** (queue · 大改造) — 覆盖 L-068 (4-dev.md 781→≤500，5 段抽到 reference/)

### 单独验证（需 OpenCode task tool 实测机会）

- **L-061** · ADR-016 探测脚本路径 → 触发条件：4-dev.md 实施时实际跑 `detect_opencode_tier_support`，确认 `.specs/<id>/.opencode-capability.json` 写入路径对
