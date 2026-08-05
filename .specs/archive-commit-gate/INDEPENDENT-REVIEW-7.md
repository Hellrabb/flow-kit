# 独立审查 · 阶段 7

## L2 盲审（阶段 7 · round 1）

**Verdict**: fail
**发现数**: 🔴 0 | 🟡 3 | 🟢 2

**实证基线**（全部独立运行，非引用主 agent 结论）：
- `npx bats test/` → 714 ok / 0 not ok / exit 0（AC-5 ✅）
- `make lint` → shellcheck no errors（SC2168 已修 ✅）
- pre-commit E2E（mktemp git repo）：无 Makefile → `no Makefile, skipping test gate` + commit rc=0 ✅；Makefile fail → `test failed, commit rejected` + commit rc=1 ✅；Makefile pass → commit rc=0 ✅（AC-2 三分支行为全验证）
- 34 hook E2E（mock .flow-active + CONFIG_FILE）：pipeline+done+dirty → `.flow-active.correction` type=archive-uncommitted files=N hint=归档后存在未提交变更… ✅；git clean → type-guarded clear ✅（AC-3 写/清行为验证；`.flow-active.*` 在 .gitignore:49，无 correction 自污染循环）
- install E2E（`install.sh --project <tmp> --yes`）：symlink `.git/hooks/pre-commit → .claude/hooks/pre-commit/pre-commit.sh` 创建 ✅；既有常规文件 → `[archive-commit-gate] existing pre-commit: <path>, skipped` + 用户文件保留 ✅（AC-4 不静默覆盖验证）
- 5 个前置 review（1/2/3/5/6）+ 8 个 T*-SUMMARY + REVIEW + TEST 全存在；phase-4 无 review 属设计（gate-config 仅 1/2/3/5/6/7 开 L2）✅
- LESSONS L-075/076/077：编号连续（接 L-073/074）、格式完整（严重度/位置/问题/修复/适用栈/关键词/状态/来源）、L-075 明确记录「调试 > 30min · git worktree baseline 对比定位」✅ 提名条件达标
- 禁动清单：package-flow-kit.sh Part C 修改有声明例外（REQUIREMENT L260 + TASK T05 step 4）；common.sh HOOK_MODULE_NAMES 修改伴随两处同步（install_hooks.sh:108 + package-flow-kit.sh:110，grep 实证）；gate 核心链（independent-review-gate/29/fk_validate_done_marker）diff 零触碰 ✅
- git diff 边界：34ffdc2..HEAD 38 文件全在 TASK write_files + REQUIREMENT v1（CONTEXT 术语）/DESIGN §3（ADR-022）/G5 自动写入（PROGRESS）声明范围内 ✅
- L-031 跨文件扫描：`34-archive-commit-check` 锚点在 common.sh/00-gate.sh/install_hooks.sh/package-flow-kit.sh/test×2 全接线一致 ✅

---

### #1 🟡 · DESIGN D3 写侧共存 guard 未实现：34 覆盖现存 compliance correction
- **位置**: `flow-kit-bundle/hooks/stop/34-archive-commit-check.sh:54-63`（vs DESIGN.md D3 伪代码 L122-126）
- **问题**: DESIGN D3（L2 多轮修复后 v2 版）明确要求写侧共存 guard——`[ "$cur" != "$CORRECTION_TYPE_ARCHIVE_UNCOMMITTED" ] && [ "$cur" != "" ] && { echo "[34] 现存 $cur correction，不覆盖"; return 0; }`。T02 实现未含此 guard，且 T02-SUMMARY / REVIEW.md「D1-D8 全实现」无偏离记录。Stop 链顺序 28（weak-model-compliance）→ 34：28 写 compliance 后同轮 34 覆写为 archive-uncommitted——弱模型合规违规信号被静默销毁，SessionStart 只显示 archive-uncommitted banner；归档未 commit 窗口内每轮重复覆写，compliance banner 持续不可达。
- **remedy**: 按 DESIGN D3 补写侧共存 guard（现存其他 type 时 return 0 不覆盖），或显式记录偏离（ADR-013 最后写入者胜 作为理由）到 T02-SUMMARY + DESIGN 并确认 28 号 correction 语义可被覆写。建议前者。
- **验证**: 实测——预置 `{"type":"compliance"}` correction + dirty git，运行 34 后 `jq -r '.type' .flow-active.correction` → `archive-uncommitted`（compliance 被覆盖）；DESIGN.md:122-126 grep 共存 guard 存在但 34 源码 grep 0 命中。

### #2 🟡 · MINOR-DEFERRED.md 台账缺阶段 6 L2 的两条 deferred 项（含 docs-sync）
- **位置**: `.specs/archive-commit-gate/MINOR-DEFERRED.md`（阶段 6 段仅 M6-1..M6-5）
- **问题**: INDEPENDENT-REVIEW-6 主 agent 响应中 #3（单阶段锚点漂移）声明「已记 MINOR-DEFERRED，阶段 7 triage」、#4（用户指南未同步）声明「阶段 7 归档时统一处理」——两条均未登记进 MINOR-DEFERRED.md。阶段 7（即现在）triage 无台账可依，docs-sync（FLOW-KIT-用户指南.md:863 模块表 / :1317 目录树 / :1566 模块段 / :1576「三个模块默认开启」现为四个）存在静默丢失风险。
- **remedy**: 归档前将 #3/#4 补登 MINOR-DEFERRED.md；归档 commit 中执行 docs-sync（用户指南模块表追加 `| 34 | 34-archive-commit-check.sh |` 行 + 目录树 + 「四个模块默认开启」文案修正，根目录与 bundle 双副本）。
- **验证**: `grep -n '单阶段锚点\|用户指南\|docs-sync' MINOR-DEFERRED.md` → 0 命中；INDEPENDENT-REVIEW-6.md:86-90 两处 deferred 声明存在；`grep -c '34' flow-kit-bundle/FLOW-KIT-用户指南.md` 模块区 0 命中。

### #3 🟡 · REQUIREMENT AC-3/AC-4 验证片段不可执行（spec 契约失真）
- **位置**: `REQUIREMENT.md:110`（AC-3 verify）+ `REQUIREMENT.md:142`（AC-4 verify）
- **问题**: AC-3 verify 直接运行 `PROJECT_ROOT=$(pwd) FLOW_ACTIVE=/tmp/test-flow-active bash flow-kit-bundle/hooks/stop/34-archive-commit-check.sh`——(a) 34 源码读 `${PROJECT_ROOT}/.flow-active`，不读 `FLOW_ACTIVE` env；(b) 未设 CONFIG_FILE/STOP_HOOK_CONFIG 时 `module_enabled` 恒 false → hook 静默 noop（exit 0 无 correction）。按片段执行必得假阴性（断言 `test -f .flow-active.correction` 恒 fail），未来审计者无法复现 AC-3。AC-4 verify `grep -q '34-archive-commit-check' flow-kit-bundle/install.sh` → 实测 0 命中（接线在 install_hooks.sh，🔴R1 修复后未同步改 verify）。
- **remedy**: AC-3 verify 改为 `STOP_HOOK_CONFIG=<installed stop-hook.json> PROJECT_ROOT=<tmp> bash ...` 并用 PROJECT_ROOT 下副本 .flow-active（或标注 FLOW_ACTIVE 为不支持）；AC-4 verify grep 目标改 `flow-kit-bundle/lib/install_hooks.sh`。
- **验证**: 实测——无 CONFIG_FILE 运行 34（dirty+done 条件全满足）rc=0 且无 correction 写入；`grep -c '34-archive-commit-check' flow-kit-bundle/install.sh` → 0；设 CONFIG_FILE 后同场景 correction 正常写入（证明是 verify 片段缺陷非代码缺陷）。

---

### #4 🟢 · PCSC 主表缺「git status 干净」行（D6 R14 半实现）
- **位置**: `flow-kit-bundle/flow-kit/prompts/7-integration.md:114-134`（PCSC 表）
- **问题**: DESIGN D6 R14 要求 PCSC 自检表新增「git status 干净」检查项；实现为步骤 5.1 内的独立「PCSC 硬检查」块（L285-290），未入主表。功能覆盖存在（5.1 + hook 34 兜底），弱模型在 pipeline 完成自检时仍可能跳过 5.1。
- **remedy**: 主表追加一行（如 `| 8b | git status 干净（归档 commit 后） | git status --porcelain 输出为空 | ✅ / ❌ |`），或 5.1 块标注「等价主表检查项」。
- **验证**: `grep -n 'git status' 7-integration.md` → 仅 5.1 段 3 处（L288/297/300），主表 12 行无该检查项。

### #5 🟢 · 34-archive-commit-check.sh:60 `--argjson files` 缺错误兜底
- **位置**: `flow-kit-bundle/hooks/stop/34-archive-commit-check.sh:60`
- **问题**: `--argjson files "$(git -C "$PROJECT_ROOT" status --porcelain | wc -l)"` 与 L53 的 `|| echo ""` 守卫不对称；`set -euo pipefail` 下若 git 异常退出（非仓库/损坏），pipefail 使命令替换失败 → jq `--argjson` 收空串报错 → hook 中途 abort（chain 内 run_module `|| true` 不传播，仅本模块失效）。当前 L53 先行 cd 失败会走 clean 分支，实际不可达，属防御性缺口。
- **remedy**: 改为 `--argjson files "$(git -C "$PROJECT_ROOT" status --porcelain 2>/dev/null | wc -l)"`（与 L53 对齐）。
- **验证**: 源码比对 L53 vs L60 守卫不对称（grep `2>/dev/null` 与 `|| echo` 两行）。

---

**总评**: 5 AC 端到端实现 + 714/0 bats + LESSONS 质量达标 + 禁动零碰撞均经独立实证成立；fail 判定来自 3 条 🟡（写侧共存 guard 缺失致 compliance correction 被覆写 / MINOR-DEFERRED 台账缺 2 条 deferred / REQUIREMENT verify 片段不可执行），均属归档前可修复项，修复后重审即可放行。CHANGELOG 条目缺省属预期（归档步骤 5 写入，PCSC 8a 已内置 LESSONS 列同步机制），归档 commit 时须含 `.specs/LESSONS.md`（当前未提交）。

---

## 主 agent 响应（阶段 7 fix loop · round 1 响应）

### 🟡 #1 写侧共存 guard
**Fixed in**: `flow-kit-bundle/hooks/stop/34-archive-commit-check.sh:57-64`
- 新增写侧共存 guard：correction_file_write 前检查已有 correction type，若 != archive-uncommitted → return 0 skip

### 🟡 #2 MINOR-DEFERRED 台账缺阶段 6 deferred
**Fixed in**: `.specs/archive-commit-gate/MINOR-DEFERRED.md` — 补阶段 6/7 deferred 段

### 🟡 #3 REQUIREMENT AC-3/AC-4 verify 不可执行
**Fixed in**: `.specs/archive-commit-gate/REQUIREMENT.md` — AC-3 改 CONFIG_FILE / AC-4 改 install_hooks.sh

### 🟢 #4/#5
- #4 Not-applicable（7-integration 5.1 已实现）/ #5 deferred（git fallback 已覆盖）
