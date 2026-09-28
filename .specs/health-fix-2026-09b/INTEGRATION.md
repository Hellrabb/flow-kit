# INTEGRATION — health-fix-2026-09b（阶段 7 · 7-integration）

> 生成：2026-09-28 · 主 agent · HEAD 见各节标注 · 本文件是阶段 7 的收口记录（UAT / Goal 自检 / triage / 自检 11 项 / 归档计划）。

## 1. UAT（四条 · 端到端实跑）

| # | UAT 面 | 命令 | 本轮实测 | 判定 |
|---|---|---|---|---|
| ① | T19 隔离 bare remote 的 pre-push 拦截（四形态泄漏 + 干净 ref） | `reproduce-5-test.sh --criteria-only --only T19` | **rc=0**（36 行判据 · §U-1） | ✅ |
| ② | pre-commit 门禁显式调用两态 | 真泄漏探针（拼接构造 L-137）+ `bash .git/hooks/pre-commit` | **rc=1** · `命中合计 1 条` / `清单外命中 1 条` · 具名 `.zz-uat-probe.txt:1: see /home/zz-uat-probe/leak.txt here` · `[archive-commit-gate] path-privacy check failed, commit rejected`；清理后工作树干净 | ✅ |
| ③ | DSH 装载面阶段门拦截（沙箱等价复现 · 六态） | `reproduce-phase-gate.sh`（§U-2 内嵌） | **rc=0**：对照 0 门禁外 commit 成功 · A rc=2 + HEAD 未变 · B rc=0 且 commit 真生效 · B2/B3/B4 一律 rc=2 · C rc=0 | ✅ |
| ④ | 安装器覆盖完整性 | `bash package-flow-kit.sh --validate` | **期望覆盖 320 / 实际文件 326 · 🔴 漏配 0 · ⚠️ 源缺失 0** | ✅ |

> ② 的探针文件已在同一次调用内清理（`git rm --cached` + `rm -f`），收工 `git status --porcelain` 为空。② 的第一形态（无泄漏探针 `printf 'x\n'`）在现态**不会**判红（该探针不含路径字面）—— 与 `TEST.md` §1.2 记录的历史形态差异已如实登记（历史那条探针带泄漏字面）。

## 2. 顶层 Goal 条件自检（`goal.condition`）

`goal.condition` = 「收口 4 个 🔴（eval RCE / settings.json 截断 / 本地 main 泄漏重发 / 坏门禁）+ 隐私前向门禁 + 假绿测试」

| 条件项 | 落点 | 判定 |
|---|---|---|
| 🔴① eval RCE | AC-1（`T05`）· `runtime-edit-guard.sh` 的 `eval` 面归零 · `test_runtime_edit_guard.bats` 15 例（`T-FIX-19` 载荷注入 6 腿 · `R5-9` 闭合） | ✅ |
| 🔴② `settings.json` 截断 | AC-2（`T06`）· `install_hooks.sh` 两道 `command -v jq` 守卫 + fail-closed · `test_install_jq_guard.bats` 4 例（`T-FIX-15` · 含变异腿 · `R5-6` 闭合） | ✅ |
| 🔴③ 本地 main 泄漏重发 | AC-3（`T11`/`T19`）· pre-push 四形态拦截 + `test_pre_push_behavior.bats` 6 例（`T-FIX-16` · 真跑 hook · `R5-7` 闭合） | ✅ |
| 🔴④ 坏门禁 | AC-4（`T13`/`T18`）· `check-gate-sync.sh` 缺件 fail-closed + 双态腿（`T-FIX-18`）+ `T-FIX-25` 的 diff 机械故障行为级腿（`TD-104` 闭合） | ✅ |
| 隐私前向门禁 | AC-6（`T20`/`T22`/`T26`）· `check-path-privacy.sh` 三面（index/rev/磁盘侧）+ 常设网 35 例 + 归档排除（NFR 面） | ✅（**归档面的豁免策略待裁决** · `TD-114`） |
| 假绿测试 | AC-7（`T27`/`T29`）· 4 个假绿文件各含注入型用例（注入失败源 ⇒ 红）· `test_combined_metric.bats` / `test_auto_checkpoint.bats` / `test_independent_review_model.bats` / `test_lessons_cleanup.bats` | ✅ |

**结论**：`goal.condition` **全部满足**（4 🔴 全收口 + 隐私前向门禁在位 + 假绿测试已加严）；AC-8（跨 OS）保持 **⚠️ 有条件通过**（`TD-055` 开放 · 不属 `goal.condition` 条目）。

## 3. MINOR-DEFERRED Triage（12 条 · F9~F17 + S1~S3）

| # | 来源 | 本轮核验（HEAD `8c15383`） | 裁决 |
|---|---|---|---|
| 1 | `F9` `trap - EXIT` 清调用方 trap | `install_hooks.sh:54/:56/:60` **仍在**（注释自陈「install 路径无 EXIT trap」） | **登记 `TD-109`**（v2 = 保存/恢复） |
| 2 | `F10` deploy 函数动态作用域 | `deploy_pre_commit:69` / `deploy_pre_push:124` + `hook_dst:213/:222` **仍在** | **登记 `TD-110`**（v2 = 显式参数） |
| 3 | `F11` `install_hooks` 超长函数 | 实测 **290 行**（阶段 6 记录 247 行 ⇒ 增长） | **登记 `TD-111`**（v2 = 拆 4–5 子函数） |
| 4 | `F12` 生产件硬编码 change id | — | **既有 `TD-062`**（保留） |
| 5 | `F13` `test_combined_metric.bats` 尾换行 | 实测文件**以 `\n` 结尾** ⇒ 已修 | **本 change 内已闭合**（无需登记） |
| 6 | `F14` hook 家族枚举手抄 | `sync-hooks.sh` 相关引用 **17 处** | **登记 `TD-112`**（v2 = 单一清单 + 断言） |
| 7 | `F15` ADR 预算字面量 | `l3-prompt.sh:353`（`_adr_budget=18000`）· `:357`（`-lt 8`）**仍在** | **登记 `TD-113`**（v2 = 环境旋钮） |
| 8 | `F16` 守卫两种拒绝惯用法 | 实测 `exit 2` **7 处** / `return 1` **0 处** ⇒ 惯用法已统一（T05/`T-FIX-19` 轮次收敛） | **本 change 内已闭合** |
| 9 | `F17` AC-5 边界（`.specs/**` 含内部项目名） | — | **既有 `TD-063`**（保留） |
| 10 | `S1` `SELF_EXCLUDE` 归档/复制失真 | **本轮归档动作实际触发**（IR-1/2/3 含真实账号路径，归档后豁免失效 ⇒ 门禁会判红） | **登记 `TD-114`** + **须用户裁决**三条策略（见 §5） |
| 11 | `S2` `REVIEW.md` 例数声明错误 | `REVIEW.md:54` 现为表头（该声明随轮次重写消失） | **本 change 内已闭合** |
| 12 | `S3` 「AC-9」术语出处 | 说明性（AC-9 出自 `6-review.md`，不在 `REQUIREMENT.md`）—— 非缺陷 | **Not-a-defect**（不登记） |

**section 级 triage**（`MINOR-DEFERRED.md` 的其余 deferred 段）：早期阶段 2/3/4/5/6 的登记项（`:9` / `:38` / `:52`–`:79` / `:206` / `:643` / `:982` / `:1000` / `:1102` / `:1164` / `:1171` / `:1186` / `:1551`）**均已逐条映射到 `.specs/CONTEXT.md` 的 TD 表**（当前 **108 条** `TD-001…TD-114`，其中本 change 新增 `TD-062`…`TD-114`）⇒ 裁决 = **保留 TD（v2 承接）**，无孤儿条目。

## 4. 阶段完成自检（11 项 · `7-integration.md:113-131`）

| # | 项 | 状态 | 依据 |
|---|---|---|---|
| 1 | 全量自动化测试通过 | ✅ | `npx bats test/` = **1116 ok / 0 not ok** · `make check` **21 ✅ / 0 ❌**（HEAD `8c15383` · `/tmp/p6d/v26-make-check.log` 20:14:39→20:19:57） |
| 2 | UAT 引导已完成 | ✅ | §1（四条端到端实跑） |
| 3 | 失败诊断已完成（如有失败） | ✅ | 本轮无失败；历史失败（阶段 5 首跑 2 红 / 阶段 6 L3 三轮 fail）的诊断与回退链见 `MINOR-DEFERRED.md` 与 `INDEPENDENT-REVIEW-6.md` |
| 4 | LESSONS.md 提名已完成 | ✅ | 本 change 提名 `L-137`…`L-182`（含本轮 `L-180`/`L-181`/`L-182`）· 见 §6 的 CHANGELOG 同步 |
| 5 | 顶层 Goal 条件自检通过 | ✅ | §2（6/6 满足；AC-8 保持 ⚠️） |
| 6 | 上游阶段产物均存在 | ✅ | `CHANGE/REQUIREMENT/DESIGN/TASK/TEST/REVIEW.md` 齐备（change 目录共 69 个 `.md`） |
| 7 | 无 pending 的 `T-FIX-*` | ✅ | `grep -cE '^<task [^>]*status="pending"' TASK.md` = **0**（54 个 task 全 done） |
| 8 | 归档已完成（`.specs/<id>/` → `archive/` + STATE + CHANGELOG） | ⏳ **待执行** | 见 §5（须先裁决 `TD-114` 的归档面隐私策略） |
| 8a | CHANGELOG LESSONS 列已同步 | ⏳ **待执行** | 随 §8 的 CHANGELOG 行一并写入（本 change 提名的 L 编号列明） |
| 9 | Sub-goal 汇总 | ✅ N/A | `goal.phase_sub_goals` = `{}` |
| 10 | PR 已提交（如适用） | ✅ N/A | 本仓为本地分发件（无远端 PR 流程）；`pre-push` 门禁已由 T19/T-FIX-14 覆盖 |
| 11 | `.flow-active` 关键字段已落盘 | ✅ | `phase="7"` · `phases_done=["0"…"6"]` · `gates` 六门全 `passed` · `updated_at` = epoch int · `task_progress` len **54** · `33-flow-active-integrity.sh` rc=0 |

## 5. 归档计划与 `TD-114` 待裁决项

**归档目标**：`.specs/health-fix-2026-09b/` → `.specs/archive/2026-09-28-health-fix-2026-09b/`（含 `ARCHIVE-MANIFEST.txt`：文件 · 字节 · sha256 前缀 · 生成时间 · HEAD · 未提交项数）· 随后追加 `.specs/CHANGELOG.md` 行 · 更新 `.specs/STATE.md`（`last_change_archived` 链）· 单次归档 commit。

**阻塞点（`TD-114`）**：本 change 的 `INDEPENDENT-REVIEW-1/2/3.md` **含真实账号路径**（成文早于脱敏规则，现于其 change 目录路径被逐条精确豁免）；归档搬迁路径后豁免失效 ⇒ `make check-path-privacy` 会判红。三条候选策略：

| 策略 | 做法 | 利 | 弊 |
|---|---|---|---|
| ① 归档时就地脱敏 | 归档副本内把真实账号路径替换为 `<acct>`（原文在 git 历史保留） | 归档面自洽干净（与上一 change 归档 0 命中一致）· 豁免面不增长 | **改动受协议保护的审查档文本**（须随 manifest 显式披露） |
| ② 豁免随文件迁移 | 把 3 条 `SELF_EXCLUDE` 条目改指归档路径 | 不动审查档原文 | 豁免面**按 change 数线性增长**（每个归档 change 都可能要 3 条）· 与 T13/T17「永不无界」的初衷相悖 |
| ③ 判据面排除归档根 | 隐私门禁扫描面显式跳过 `.specs/archive/**`（归档快照 = 冻结历史） | 一次性规则 · 豁免面不增长 · 与 `T-FIX-23` 对 NFR 面的处置**同构** | 归档面成为**隐私盲区**（未来归档若含真实路径不会被发现）· 属「宽排除」 |

> 该决策属本 change 已两度裁决过的「豁免面策略」，故按协议**呈用户裁决**；裁决结果与理由将写入本文件 §5 与本 change 的 `MINOR-DEFERRED.md`，并据此更新 `TD-114` 的 v2 口径。
