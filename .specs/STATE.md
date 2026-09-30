# STATE — 项目状态

- **last_intel_scan**: `2026-06-17`
- **last_evolve_at**: `2026-07-08`（完整 · 两轮，扫 29/29 个 change）
- **last_architect_at**: `2026-07-08`（首跑 · 9 ADR + 模块清单 + 跨模块契约）
- **last_change_archived**: `health-fix-2026-09b`（2026-09-28 · **门禁判据/健壮性修复型 · pipeline 0→7 `gate_config=all`** · 阶段 6 五轮审查 + 六轮 fix 循环（4 次回退 4-dev）· 判据面 25/25 rc=0 · 门禁 7/7 + 8/8 · bats **1116**（起点 976）· `make check` **21 ✅ / 0 ❌** · AC-8 ⚠️ 有条件通过（`TD-055`）· 新增 `TD-062`…`TD-114`（53 条）· LESSONS **L-111…L-183**（73 条）· 归档时就地脱敏（`TD-114` 策略① · 映射见 `ARCHIVE-MANIFEST.txt`））
- **last_change_archived_prev**: `user-guide-sync-2026-09b`（2026-09-21 · **文档/演示同步型 · pipeline 0→7** · `gate_config` 六阶段 `both` · 阶段 1/2/6 **L2+L3 双 pass**；阶段 3/5 的 L3 按框架熔断**透明结案**（`L3_verdict=skipped` + 审计段，findings 已逐轮处置，见 IR-3/IR-5）· bats **973** · `make check` **六门全绿 rc=0**（日志 `.specs/<id>/make-check.log`）· `verify-ac` **128/0**（AC-1 4 · AC-2 39 · AC-3 59 · AC-4 23 + 段外 3）· 母本集合断言 **59 格 / 跳过 21 / 缺失 0** · 四副本 md5 唯一 · deck 24 页 · LESSONS **L-106~L-109**）
- **last_change_archived_prev2**: `brooks-review-fix-2026-09`（2026-09-21 · **守卫判据修复型 · 回溯登记**（代码先于 change 存在，pipeline from=6）· 触发 = 对 `health-fix-2026-09` 终态 diff 的 brooks-review 独立复核（3🟡+3🟢）· `gate_config={"6-review":"both"}` · 阶段 6 **L2 盲审 pass**（glm-5.2 子代理）+ **L3 外部模型 pass**（deepseek-v4-flash-0731；首轮 fail 抓出 1 🔴 `COPY_FILES` 源缺失漏判 → 已修，第二/四轮模型格式不合规判 error，第三轮 pass）· bats **964 ok / 0 not ok** · `make check` **6 门全绿** · `verify-claims` ✅14/❌0/⏭0（无活跃 change 时 ✅11/❌0/⏭3）· 打包等价性：重构后 dist 整树哈希与重构前逐字节相同 · LESSONS **L-101~L-105**（含 L-099 复发的事故条目））
- **last_change_archived_prev3**: `health-fix-2026-09`（2026-09-21 · 门禁判据修复型 · pipeline 0→7 `gate_config=all` · 阶段 1/3/5 各经 L2+L3（**三次熔断 bypass**，透明留痕）· 阶段 6 L2 **pass** + L3 **pass** · bats 950 ok/0 not ok/1 skip · `make check` **6 门全绿**（新增 check-dist）· `verify-claims` 14✅/0❌ · 11 个 AC 夹具实跑全 PASS · LESSONS L-090~L-100 · **ADR-027** 新增（原误编 010，与既有 010 冲突，已重编号））
- **last_change_archived_prev4**: `l3-review-defects-2026-09`（2026-09-18 · 缺陷修复型 · **未走 pipeline**（直接响应外部缺陷报告）· 报告 5 条复测全成立 + 新增 1 条 · 854 bats 0 fail · make check 五门全绿 · 6 副本漂移 0 · 无 L2/L3 独立审查记录）
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
- **test_framework**: `bats-core 1.13.0 (npx) · 1116 ok / 0 not ok / 0 skip（TAP plan 1..1116；2026-09-28 health-fix-2026-09b 第 6 轮 fix 循环 T-FIX-25 全量实测）`
  > 基线演进（2026-09-28 health-fix-2026-09b **第 6 轮 fix 循环**收口实测）：**1116 ok / 0 not ok / 0 skip** = T-FIX-13 基线 **1064** + **52**，逐段归因：**1064 → 1098**（`T-FIX-14`…`T-FIX-20`：安装形态/缺 jq/行为级 pre-push/隐私磁盘侧隔离与 rev 批量化/缺件 fail-closed/载荷注入/`$HOME` 回落 +34）· **1098 → 1108**（`T-FIX-21`/`T-FIX-22`：台账归一 + 阶段门标记有效性 + `.done` 两态 + ADR 截断 +10）· **1108 → 1114**（`T-FIX-23`：NFR 存量基线 ratchet 常设网 14 → 20 · +6）· **1114 → 1115**（`T-FIX-24`：`SELF_EXCLUDE` 豁免面冻结腿 · +1）· **1115 → 1116**（`T-FIX-25`：`check-gate-sync` diff 机械故障行为级腿 · +1）；`npx bats --count test/` 同步为 1116 · 有效用例 **1115**（= 1116 − 1 条 TD-033 mock）。
  > 基线演进（2026-09-27 health-fix-2026-09b T-FIX-13 收口实测）：**1064 ok / 0 not ok / 0 skip** = T-FIX-11 基线 1061 + T-FIX-13 bundle 形态「检查器在 + path-privacy-allowlist.txt 缺失」三态区分静态断言 3 例（test_archive_commit_gate.bats：pre-push 状态②具名 fail-closed·exit 2 独立致命路径·指名允许清单路径 · pre-push 状态②报文不复用「检查器缺失」措辞·归因区分 · pre-commit 状态②具名 fail-closed exit 1·指名允许清单路径）；`npx bats --count test/` 同步为 1064。
  > 基线演进（2026-09-25 health-fix-2026-09b T-FIX-11 收口实测）：**1061 ok / 0 not ok / 0 skip** = T-FIX-10 基线 1058 + T-FIX-11 不可读候选判定与 index 内容面口径 3 例（test_path_privacy_gate.bats：T-FIX-11① 已跟踪未 staged 删除·干净 rc=0 且「不可读候选 0 个」· T-FIX-11② 同删除态 index 含泄漏 rc≠0 且「清单外命中 [1-9]」· T-FIX-11③ gitlink 候选 mode 160000 无 blob rc≠0）；`npx bats --count test/` 同步为 1061。
  > 基线演进（2026-09-25 health-fix-2026-09b T-FIX-10 收口实测）：**1058 ok / 0 not ok / 0 skip** = T-FIX-09 基线 1054 + T-FIX-10 check-gate-sync 判据可信度判别式 4 例（test_check_gate_sync.bats：R3-18A 仅 skill 侧具名 · R3-18B 仅 prompt 侧具名 · R3-19 两侧预设同时清空不静默中止 · R3-20 PATH 影子 diff rc=2 不折算为一致）；`npx bats --count test/` 同步为 1058。
  > 基线演进（2026-09-25 health-fix-2026-09b T-FIX-09 收口实测）：**1054 ok / 0 not ok / 0 skip** = T-FIX-08 基线 1047 + T-FIX-09 NFR 禁构面/文件名面/锚点面回归钉 7 例（test_nfr_portability_gate.bats：R3-15 realpath 词边界 · R3-16 空格名 untracked · R3-16 空格名 tracked · R3-22 全量模式不退化 SKIP · R3-22 全量模式 fail-closed · R3-22 .flow-active 锚点选中 · R3-22 多锚点+坏 .flow-active 具名红）；`npx bats --count test/` 同步为 1054。
  > 基线演进（2026-09-25 health-fix-2026-09b T-FIX-08 收口实测）：**1047 ok / 0 not ok / 0 skip** = T-FIX-06 基线 1029 + T-FIX-08 路径隐私覆盖旋钮 3 例（test_path_privacy_gate.bats：覆盖生效 · 覆盖 fail-closed 指名 · 未设置读序不变）+ T-FIX-08 消费者项目 hook 回退守卫 15 例（test_archive_commit_gate.bats：pre-push 7 · pre-commit 2 · install_hooks 2 · install.sh/README/OPENCODE jq 3 · check-path-privacy 覆盖旋钮 1）；`npx bats --count test/` 同步为 1047。
  > 基线演进（2026-09-25 health-fix-2026-09b T-FIX-06 收口实测）：**1029 ok / 0 not ok / 0 skip** = T-FIX-04 基线 1025 + T-FIX-06 隐私门禁 0 实际扫描 fail-closed + mktemp 立即终止双态判据 4 例（test_path_privacy_gate.bats：F19 坏态/好态 2 · F20 坏态/好态 2）；`npx bats --count test/` 同步为 1029。
  > 基线演进（2026-09-24 health-fix-2026-09b T-FIX-04 收口实测）：**1025 ok / 0 not ok / 0 skip** = T-FIX-03 基线 1023 + T-FIX-04 check-gate-sync 缺对不得报全绿双态判据 2 例（test_check_gate_sync.bats：F6 好态完整夹具 rc=0 + 坏态缺一对 skill rc≠0 且不打印 ✅ 一致）；`npx bats --count test/` 同步为 1025。
  > 基线演进（2026-09-24 health-fix-2026-09b T-FIX-03 收口实测）：**1023 ok / 0 not ok / 0 skip** = T-FIX-02 基线 1012 + T-FIX-03 隐私门禁 fail-open 收敛双态判据 11 例（test_path_privacy_gate.bats：F1 坏态/好态 2 · F2 坏态①/坏态②/好态 3 · F3 坏态/好态 2 · F4 坏态/好态 2 · F5 静态/好态 2）；`npx bats --count test/` 同步为 1023。
  > 基线演进（2026-09-24 health-fix-2026-09b T-FIX-02 收口实测）：**1012 ok / 0 not ok / 0 skip** = T-FIX-01 基线 1001 + 阶段门标记有效性常设判据 11 例（test_review_gate_validity.bats：A 无标记 / B 6 键有效 / B2 口径相悖 / B3 touch 空 / B4 缺 L3_verdict / B5 值域非法 / C 无 .flow-active / gate 未开反面对照 / 函数级三例）；`npx bats --count test/` 同步为 1012。
  > 基线演进（2026-09-24 health-fix-2026-09b T-FIX-01 收口实测）：**1001 ok / 0 not ok / 0 skip** = T29 基线 976 + TD-053 常设回归网 25 例（test_path_privacy_gate.bats 9 + test_runtime_edit_guard.bats 9 + test_nfr_portability_gate.bats 7）；`npx bats --count test/` 同步为 1001。
  > 口径订正（2026-09-24 health-fix-2026-09b T29 收口实测）：T29 时点基线为 **976 ok / 0 not ok / 0 skip**（原「973 ok / 0 not ok / 1 skip」已过时——既有 test_lessons_cleanup.bats:137 的 AC-4 skip 已在本 change 前序 task 闭合，不再 skip）。
- **ci_cd**: `未检测到`

---

## 活跃变更（2026-09-29 更新）

- **当前活跃**：`health-fix-2026-09c`（phase 4 · 2026-09-29 开 · pipeline 1→7 `gate_config=all` 自动推进）
  - **目标**：修复 2026-09-29 Full Sweep 报告（`.specs/health/2026-09-29-HEALTH.md` · 55/100 · 4 新 🔴）全部 14 条发现（C1–C14）：C1 make check 并发互踩 / C2 隐私正则 / C3 tracked 30 行 + 历史重写 / C4 `|| true` 吞错 / C5+C11 跨层闭环 / C6 行为断言 / C7 单跑 / C8 载体 / C9 结构化 / C10 lint / C12 fail-closed / C13 权威载体 / C14 杂项
  - **阶段 1 已过门**：REQUIREMENT.md v2（AC-1…AC-17）· L2 盲审 pass（0🔴/6🟡/3🟢，全处置）· L3 盲审 pass（0 critical/2 major/4 minor，全 Fixed in）· `.independent-review-1.done` 用户手写（DSH 无宿主写入者·代行）
  - **阶段 2 已过门**：DESIGN.md（§0.5.1 触碰清单含更名触点 + 附录 A 白名单严格谓词 · D1–D9 决策）+ ADR-030/031/032 + REQUIREMENT v3 对齐 · **L2 三轮收敛 pass**（轮1 fail 🔴×2→修复；轮2 fail 🔴×1 真名基线入 tracked→修复；轮3 pass 0🔴/5🟡 全 Fixed）· **L3 盲审 pass**（7 major + 5 minor 全 Fixed：白名单常设化 ADR-028 读序 / 真名零 tracked sha256 对账 / 谓词四分支含 JS 与变量间接 / comm 归一化 / @see 可解析）· `.independent-review-2.done` 用户手写 · M1–M10 入 MINOR-DEFERRED.md
  - **阶段 3 已过门**：TASK.md（T01–T17 · 17 任务 7 波次 DAG · AC-1…17 全承接 · 写权例外清单六类显式授权）· **L2 五轮收敛 pass**（r1 fail 2🔴/8🟡→修复；r2 fail 2🔴/9🟡→修复；r3 fail 2🔴/4🟡→修复；r4 fail 1🔴/4🟡→修复；r5 pass 0🔴/5🟡/5🟢）· **L3 三轮 pass**（r1 fail 2major/8minor→修复；r2 fail 2major/6minor（两恒真锚）→修复；r3 pass 0critical/0major/6minor 全 Fixed in）· verify 锚 20+ 条今日实测红→执行后绿 · `.independent-review-3.done` 用户手写 · M11–M19 入 MINOR-DEFERRED.md
  - **C9 降级登记（AC-16 判据）**：C9 四项结构改造（`main()` 抽取 / `_l3_build_prompt` 201 行拆分 / Makefile 内嵌 bash 外迁 / `check-path-privacy.sh` 计数器收敛）**显式降级挂 v2**——理由：改造面大，与本 change 在同一批文件上的 C4/C6 修复叠加 churn，回归风险不成比例（CHANGE 风险表 :505 自认「须分期」）；承接去向 = v2（见 REQUIREMENT.md v2 表）
  - **提案**：`.specs/health-fix-2026-09c/CHANGE.md`

- **上一活跃（已归档）**：`health-fix-2026-09b` → `.specs/archive/2026-09-28-health-fix-2026-09b/`（终态见 `last_change_archived`）

- **⏸️ 已 park**：`privacy-path-scrub-2026-09`（停于 phase 3 · 在 phase 3 停滞 3 个 session `task: none`）
  - **已闭环（勿重做）**：tracked 文件 `/home/<acct>` = **0**；`develop` / `origin/develop` / `origin/main`
    全对象 = **0**；`origin/develop` 已强推为 `534e3e8`；三处安全网**按设计删除**
    （`HISTORY-REWRITE-FULL.md:104` 要求 + `LESSONS` **L-110 ③** 给出理由）—— **非缺陷，勿重建**
  - **未完成目标已转入** `health-fix-2026-09b`：P1（本地 main）/ P3（chisel）/ P6（前向门禁）
  - ⚠️ **未决残留**：本地 `main` 仍使 8 个含 `/home/<acct>` 的 blob **保持可达** →
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
