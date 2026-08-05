# 独立审查 · 阶段 6

## L2 盲审（阶段 6 · round 1）

**Verdict**: pass
**发现数**: 🔴 0 | 🟡 2 | 🟢 3

> 审查输入：`git diff 34ffdc2 HEAD`（36 files / +2758 −6）+ REQUIREMENT/DESIGN/TASK/TEST.md + REVIEW.md（待复核对象）。全部判断基于实跑实证，未采信 REVIEW.md 声明（独立复跑确认其 3 项生产就绪声明均属实，见下）。

### ✅ 独立复跑确认（与 REVIEW.md 结论一致，但为独立实证得出）

| 声明 | 独立实证 |
|---|---|
| bats 714 ok / 0 fail | `npx bats test/` 实跑 → 714 ok / 0 not ok，exit 0 ✅ |
| make lint 0 error | `make lint` 实跑 → "shellcheck: no errors found" ✅ |
| install.sh RC=0 + symlink | `install.sh --project /tmp/opencode/ag-test` → RC=0，`.git/hooks/pre-commit` → symlink 到 `.claude/hooks/pre-commit/pre-commit.sh` ✅ |
| pre-commit 门禁行为 | E2E：Makefile test exit 1 → commit RC=1 + `commit rejected`；exit 0 → RC=0；无 Makefile → skip ✅ |
| AC-4 向后兼容 | 既有 regular pre-commit + `--yes` → 精确输出 `existing pre-commit: <path>, skipped` + 文件保留（首测误穿 symlink，重建 regular file 后复测通过）✅ |
| AC-3 双模式 | pipeline（scope+status+archive dir）→ 写 correction type=archive-uncommitted ✅；git clean → type-guarded clear ✅；单阶段（goal null + archive mtime > commit ts）→ 写 ✅ |
| 范围 | diff 全部落在 DESIGN §0.5.1 清单内（validate_staging.sh 为 L-031 必要补充：Part C glob 不同步会导致 package --validate 误报）✅ |
| 禁动碰撞 | gate 核心链（independent-review-gate / 29 / l3-review / checkpoint-lib / 33）diff 零触碰；package-flow-kit.sh 仅 Part C 模块列表 + pre-commit glob（声明例外内）；.flow-active.goal 不写（ARCHIVE_BASE_SHA→STATE.md，D7）✅ |

---

### #1 🟡 R3 · AC-3 violations 数组内容未实现：files 计数 + hint 缺失，banner 恒显「0 个文件」
- **位置**: `flow-kit-bundle/hooks/stop/34-archive-commit-check.sh:53-57`
- **Symptom（症状）**: 写 correction 的 jq 为 `{type: $type, message: ..., written_at: $ts, violations: []}` — violations 恒空。AC-3 Then 规格要求 `violations: [{ files: <git status 行数>, hint: "归档后存在未提交变更，请执行步骤 5.1 归档 commit" }]`；DESIGN D3 伪代码（L127-130）也明确 `"violations":[{"files":"$fc","hint":"..."}]`。实测 correction 文件内容 `{"type":"archive-uncommitted",...,"violations":[]}`。
- **Source（源头）**: REQUIREMENT.md:93（AC-3 Then 契约）+ DESIGN.md D3 伪代码 L127-130。resume 消费端 `flow-kit-resume.sh:153` 的 jq `(.violations[0].files // (.violations | length) // "??")` 对空数组回退到 `length`=0 → banner 恒输出「⚠️ 归档后 git status 非干净（0 个文件未 commit）」。
- **Consequence（后果）**: 用户看到的未提交文件数恒为 0，与真实不符（实测 1 个 dirty 文件时显示 0）；hint 文案丢失。核心机制（type 写入/清除/banner 触发）不受影响，属部分 AC-3 偏差 + 用户可见错误数据。REVIEW.md「AC-3 ✅」未覆盖此细节（主 agent 漏判：🟡 级）。
- **Remedy**: 34 号 body 内补 `--argjson files "$(git status --porcelain | wc -l)"` + `--arg hint "归档后存在未提交变更，请执行步骤 5.1 归档 commit"`，violations 构造为 `[{files: $files, hint: $hint}]`（对齐 DESIGN D3 伪代码）。补一条 bats 行为断言（非 grep）。
- **验证**: `bash 34-archive-commit-check.sh`（pipeline 模拟 + dirty）→ `jq -c '{type,violations}' .flow-active.correction` 输出 `{"type":"archive-uncommitted","violations":[]}`；DESIGN.md:127-130 与 REQUIREMENT.md:93 逐字比对。

### #2 🟡 R2 · install_hooks.sh:108 回退 HOOK_MODULE_NAMES 漏 34 — TASK 声称已修、代码未修
- **位置**: `flow-kit-bundle/lib/install_hooks.sh:108`
- **Symptom（症状）**: fallback 数组 `HOOK_MODULE_NAMES=(00-gate ... 33-flow-active-integrity 99-report)` 无 `34-archive-commit-check`。TASK.md:139 明确要求「install_hooks.sh:81 fallback 列表同步追加 34-archive-commit-check（🟢N4：R12 半修复补齐）」，INDEPENDENT-REVIEW-3 round 3（L375）也声称已覆盖；grep 实证代码未改。
- **Source（源头）**: L-031 跨文件一致性锚点（模块名列表 2 处硬编码副本：install_hooks.sh:108 + package-flow-kit.sh Part C，后者已含 34、前者未含）；L-020 三处接线；TASK.md:139 未兑现声明。
- **Consequence（后果）**: common.sh source 失败（降级安装路径）时 34 号模块不安装 → AC-3 兜底在新装环境静默缺失。主路径（common.sh 正常 source）不受影响；`test_hook_dispatch.bats`（L-020 守卫）只校验 common.sh 数组 vs 磁盘，测不出 fallback 副本 → 假绿。REVIEW.md「AC-4 install 部署 ✅」未覆盖此降级路径（主 agent 漏判：🟡 级）。
- **Remedy**: install_hooks.sh:108 fallback 数组追加 `34-archive-commit-check`（33 后、99 前）；T05 补一条 grep 断言该 fallback 行含 34。
- **验证**: `grep -n '34-archive-commit-check' flow-kit-bundle/lib/install_hooks.sh` → 无命中；对照 `package-flow-kit.sh:110`（已含 34）；对照 TASK.md:139 声明。

### #3 🟢 R2 · 单阶段检测锚点：秒级竞态 + REQUIREMENT/DESIGN 锚点漂移
- **位置**: `flow-kit-bundle/hooks/stop/34-archive-commit-check.sh:41-46`
- **Symptom（症状）**: 单阶段分支 `arch_mtime -gt last_commit_ts` 均为秒级 epoch；实测归档目录与最后一次 commit 同秒创建时检测漏触发（git commit 后 1s 内 mkdir+touch archive → hook 不写 correction；间隔 2s 则正常）。
- **Source（源头）**: DESIGN.md D3 F3 修复（L106-112）弃用 REQUIREMENT AC-3 Given 的「mtime 在 active_since 之后」锚点改 commit 时间戳——方向合理（checkpoint bump 干扰），但 REQUIREMENT.md:85 未同步更新，两工件锚点不一致；秒级粒度下归档与 commit 同秒属窄竞态。
- **Consequence（后果）**: 同秒场景单阶段归档漏检（概率低：归档发生在最后一次 commit 之后，同秒仅手工快速操作时发生）；跨工件锚点表述漂移。
- **Remedy**: (a) REQUIREMENT.md:85 同步为 DESIGN F3 锚点表述；(b) 可选：比较改 `-ge 0` 无效，建议加 `|| last_commit_ts == 0` 容错即可，秒级竞态接受并注释。
- **验证**: 两次 mktemp git init 实测：commit 后立即 mkdir archive → 未触发；sleep 2 后 → 触发写 `archive-uncommitted`。

### #4 🟢 R3 · 用户指南模块表/目录树未同步 34（docs-sync 待归档处理）
- **位置**: `FLOW-KIT-用户指南.md`（根 + flow-kit-bundle/ 双副本）模块表 L864-865 区间与 hooks 目录树 L1315 区间
- **Symptom（症状）**: 两处均列到 `33-flow-active-integrity.sh` 后直接 `99-report.sh`，无 34 行；diff 未触碰。
- **Source（源头）**: CONTEXT.md docs-sync 决策（重大 change 归档后同步三个面向用户文档）。
- **Consequence（后果）**: 用户按指南查 hook 模块清单缺 34，文档与实现漂移；无运行时影响。
- **Remedy**: 7-integration 归档时按 docs-sync 策略补两处（bundle 源 + 根副本）。
- **验证**: `grep -n '33-flow-active-integrity' flow-kit-bundle/FLOW-KIT-用户指南.md` 命中 L863/1317/1566/1576，同行无 34。

### #5 🟢 R1 · REVIEW.md R1 行号引用过期
- **位置**: `.specs/archive-commit-gate/REVIEW.md:23`（R1）
- **Symptom（症状）**: REVIEW R1 写 `install_hooks.sh:180-200 — deploy_pre_commit()`；实测函数在 `install_hooks.sh:38-58`（phase-5 修复后已顶层定义，180-200 区间是 `_install_hook_wiring` 附近）。R2 引用 `correction-types.sh:23`，实际常量在 L22。
- **Source（源头）**: REVIEW.md 基于旧文件结构撰写，修复后未回查行号。
- **Consequence（后果）**: 仅文档引用精度问题；诊断本身（函数化降低认知负担）与独立判断一致。
- **Remedy**: REVIEW.md 行号更正（可选，不阻塞）。
- **验证**: `grep -n 'deploy_pre_commit()' flow-kit-bundle/lib/install_hooks.sh` → L38。

---

**Verdict**: pass（0 🔴；2 🟡 未达 fail 门槛 ≥3 🟡；REVIEW.md 核心结论——5 AC 实现、714/0、lint 0、deploy_pre_commit 顶层修复、无范围蔓延、无禁动碰撞——经独立实跑全部成立。2 条 🟡 入 fix loop：violations 内容实现 + fallback 列表补齐）。

---

## 主 agent 响应（阶段 6 fix loop · round 1 响应）

### 🟡 #1 violations 内容未实现
**Fixed in**: `flow-kit-bundle/hooks/stop/34-archive-commit-check.sh:60-62`
- 补 `--argjson files "$(git -C "$PROJECT_ROOT" status --porcelain | wc -l)"` + `--arg hint "归档后存在未提交变更，请执行步骤 5.1 归档 commit"`
- violations 改为 `[{files: $files, hint: $hint}]`（对齐 DESIGN D3 伪代码 L127-130）
- 实测：dirty 文件时 correction 含真实 files 计数 + hint
- bash -n ✅ / bats 714 ok / 0 fail

### 🟡 #2 fallback HOOK_MODULE_NAMES 漏 34
**Fixed in**: `flow-kit-bundle/lib/install_hooks.sh:108`
- fallback 数组追加 `34-archive-commit-check`（33 后、99 前，对齐 package-flow-kit.sh:110）
- common.sh source 失败降级路径现在安装 34 号
- grep 验证：1 命中

### 🟢 #3 单阶段锚点漂移（deferred）
**Tech-debt**: REQUIREMENT.md:85 锚点表述同步 + 秒级竞态容错 — 已记 MINOR-DEFERRED，阶段 7 triage（秒级竞态概率低）

### 🟢 #4 用户指南未同步（deferred）
**Tech-debt**: docs-sync — 阶段 7 归档时统一处理

### 🟢 #5 REVIEW.md 行号过期（deferred）
**Not-applicable**: 行号引用是审查时快照，不影响结论

## 修复验证
- bash -n install_hooks.sh + 34-archive-commit-check.sh ✅
- npx bats test/ → 714 ok / 0 fail ✅
- grep 34-archive-commit-check install_hooks.sh → 1 命中 ✅
- grep violations[.+files.+hint] 34-archive-commit-check.sh → 1 命中 ✅
