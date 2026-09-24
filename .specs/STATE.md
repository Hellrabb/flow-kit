# STATE — 项目状态

- **last_intel_scan**: `2026-06-17`
- **last_evolve_at**: `2026-07-08`（完整 · 两轮，扫 29/29 个 change）
- **last_architect_at**: `2026-07-08`（首跑 · 9 ADR + 模块清单 + 跨模块契约）
- **last_change_archived**: `user-guide-sync-2026-09b`（2026-09-21 · **文档/演示同步型 · pipeline 0→7** · `gate_config` 六阶段 `both` · 阶段 1/2/6 **L2+L3 双 pass**；阶段 3/5 的 L3 按框架熔断**透明结案**（`L3_verdict=skipped` + 审计段，findings 已逐轮处置，见 IR-3/IR-5）· bats **973** · `make check` **六门全绿 rc=0**（日志 `.specs/<id>/make-check.log`）· `verify-ac` **128/0**（AC-1 4 · AC-2 39 · AC-3 59 · AC-4 23 + 段外 3）· 母本集合断言 **59 格 / 跳过 21 / 缺失 0** · 四副本 md5 唯一 · deck 24 页 · LESSONS **L-106~L-109**）
- **last_change_archived_prev**: `brooks-review-fix-2026-09`（2026-09-21 · **守卫判据修复型 · 回溯登记**（代码先于 change 存在，pipeline from=6）· 触发 = 对 `health-fix-2026-09` 终态 diff 的 brooks-review 独立复核（3🟡+3🟢）· `gate_config={"6-review":"both"}` · 阶段 6 **L2 盲审 pass**（glm-5.2 子代理）+ **L3 外部模型 pass**（deepseek-v4-flash-0731；首轮 fail 抓出 1 🔴 `COPY_FILES` 源缺失漏判 → 已修，第二/四轮模型格式不合规判 error，第三轮 pass）· bats **964 ok / 0 not ok** · `make check` **6 门全绿** · `verify-claims` ✅14/❌0/⏭0（无活跃 change 时 ✅11/❌0/⏭3）· 打包等价性：重构后 dist 整树哈希与重构前逐字节相同 · LESSONS **L-101~L-105**（含 L-099 复发的事故条目））
- **last_change_archived_prev2**: `health-fix-2026-09`（2026-09-21 · 门禁判据修复型 · pipeline 0→7 `gate_config=all` · 阶段 1/3/5 各经 L2+L3（**三次熔断 bypass**，透明留痕）· 阶段 6 L2 **pass** + L3 **pass** · bats 950 ok/0 not ok/1 skip · `make check` **6 门全绿**（新增 check-dist）· `verify-claims` 14✅/0❌ · 11 个 AC 夹具实跑全 PASS · LESSONS L-090~L-100 · **ADR-027** 新增（原误编 010，与既有 010 冲突，已重编号））
- **last_change_archived_prev3**: `l3-review-defects-2026-09`（2026-09-18 · 缺陷修复型 · **未走 pipeline**（直接响应外部缺陷报告）· 报告 5 条复测全成立 + 新增 1 条 · 854 bats 0 fail · make check 五门全绿 · 6 副本漂移 0 · 无 L2/L3 独立审查记录）
- **last_change_archived_prev4**: `l3-prompt-loop-fix`（2026-09-05 · 缺陷修复型 · pipeline 0→7 gate_config=both · L2×6+L3×6 全 pass · 803 bats 0 fail · 五副本 md5 唯一 · LESSONS L-085~088）
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
- **test_framework**: `bats-core 1.13.0 (npx) · 1001 ok / 0 not ok / 0 skip（TAP plan 1..1001；2026-09-24 health-fix-2026-09b T-FIX-01 全量实测）`
  > 基线演进（2026-09-24 health-fix-2026-09b T-FIX-01 收口实测）：**1001 ok / 0 not ok / 0 skip** = T29 基线 976 + TD-053 常设回归网 25 例（test_path_privacy_gate.bats 9 + test_runtime_edit_guard.bats 9 + test_nfr_portability_gate.bats 7）；`npx bats --count test/` 同步为 1001。
  > 口径订正（2026-09-24 health-fix-2026-09b T29 收口实测）：T29 时点基线为 **976 ok / 0 not ok / 0 skip**（原「973 ok / 0 not ok / 1 skip」已过时——既有 test_lessons_cleanup.bats:137 的 AC-4 skip 已在本 change 前序 task 闭合，不再 skip）。
- **ci_cd**: `未检测到`

---

## 活跃变更（2026-09-22 更新）

- **当前活跃**：`health-fix-2026-09b`（phase 0 · 2026-09-22 开 · 阶段0 CHANGE 已出）
  - **目标**：收口 4 个 🔴 —— PC1 `eval` RCE（已复现）/ PC2 `settings.json` 截断为 0 字节（已复现）/
    P1 本地 `main` 泄漏重发路径 / AR2 prompt↔skill 坏门禁；另并入 P3 `chisel` 出厂泄漏、
    P6 前向隐私门禁、TC3/TC4/TC5 四处假绿测试
  - **依据**：`.specs/health/2026-09-22-FULL-SWEEP.md`（**首次五维**全量巡检 · 56/100 · 13🔴/34🟡/24🟢；
    维度 = 隐私 + 生产 R1-R6 + 测试 T1-T6 + 架构单一源 + 门禁）
  - **提案**：`.specs/health-fix-2026-09b/CHANGE.md`

- **⏸️ 已 park**：`privacy-path-scrub-2026-09`（停于 phase 3 · 在 phase 3 停滞 3 个 session `task: none`）
  - **已闭环（勿重做）**：tracked 文件 `/home/<redacted>` = **0**；`develop` / `origin/develop` / `origin/main`
    全对象 = **0**；`origin/develop` 已强推为 `534e3e8`；三处安全网**按设计删除**
    （`HISTORY-REWRITE-FULL.md:104` 要求 + `LESSONS` **L-110 ③** 给出理由）—— **非缺陷，勿重建**
  - **未完成目标已转入** `health-fix-2026-09b`：P1（本地 main）/ P3（chisel）/ P6（前向门禁）
  - ⚠️ **未决残留**：本地 `main` 仍使 8 个含 `/home/<redacted>` 的 blob **保持可达** →
    `gc --prune` 无法回收 → 逐字执行 `HISTORY-REWRITE-FULL.md:120` 的权威验证命令（`--batch-all-objects`）
    **实测返回 8，期望 0**。即该 change 自己声明的验收判据当前**不通过**

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
ARCHIVE_BASE_SHA=5a2e542111d07c81be6d167249509b1bfc23986a
