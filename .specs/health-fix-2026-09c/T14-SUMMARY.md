# T14 Summary — C14-a 死代码清除（AC-12-a）

Change: health-fix-2026-09c · 任务: T14（删 `jq_atomic_write` + 6 候选判定登记）
所有路径为仓库相对路径。

## 1. 删除定位

- 文件: `flow-kit-bundle/hooks/stop/lib/common.sh`（TASK.md 的 `flow-kit-bundle/hooks/lib/common.sh` 为简写，实路径含 `stop/`）。
- 实际删除范围: 原 :189-196 = 3 行注释（`# Atomically apply a jq filter...` / `# Usage: jq_atomic_write '<jq filter>' <target_file>` / `# Returns: 0 on success, 1 on failure (file unchanged)`）+ 5 行函数体（`jq_atomic_write() { ... }`），共 8 行。TASK.md 写 ":188-192 附近"，行号有漂移（L2 r5 R6 已预判含注释块），按现文定位删除，保留 line_count 与 Git helpers 段之间单个空行。
- 删后回验: `sed -n '183,196p'` 显示 File helpers → Git helpers 直接相邻；`bash -n` 语法 OK。

## 2. 6 候选判定表（详见 CHANGE.md 14c 段 · 全部「留」· 零追加删除）

| # | 候选 | 位置（体量） | 生产调用 | 测试触点 | 判定 | 一句理由 |
|---|---|---|---|---|---|---|
| 1 | `checkpoint_clear` | hooks/stop/lib/checkpoint-lib.sh:70（7 行） | 0（同库 `checkpoint_write` 被 pre-tool-use/auto-checkpoint.sh:112 调用） | test_checkpoint.bats（域外） | 留 | 库自标 DESIGN D6 禁动清单；删须连动域外测试，挂后续 change |
| 2 | `correction_file_read` | hooks/stop/lib/correction-file.sh:25（22 行） | 0（同库 write/clear/exists 生产在用：34-archive-commit-check.sh:75、interactive-ui-check.sh、weak-model-compliance.sh） | test_correction_file.bats（域外） | 留 | 读路径从未接线（非设计意图），单删收益小且测试域外 |
| 3 | `fk_validate_flow` | hooks/stop/lib/flow-kit-artifacts.sh:188（15 行） | 0（同库 fk_artifact_check/fk_auto_phase/fk_boundary_check 被 26-workflow.sh:67/84/130 调用） | test_flow_artifacts.bats（域外） | 留 | 校验函数从未接线（非设计意图），测试域外 |
| 4 | `l3_review_with_timeout` | hooks/stop/lib/l3-review.sh:200 | 0（生产直调 `l3_review_run`：29-independent-review.sh:211/337 + `$L3_BG_FLAG`；wrapper 从未接线） | test_hook_integration.bats:55 · test_l3_review_defects_2026_09.bats:463/1016/1893（**T15 边界→只登记不代改**）· test_l3_lifecycle_wiring.bats:312（域外 stub） | 留 | 非设计意图死代码；stub 面在 T15 手里，删除须 T15 协同 |
| 5 | `smart_truncate` | hooks/stop/lib/l3-truncate.sh:69（146 行） | 0（截断走 `_l3_build_prompt`+`max_bytes`/`head -c`：l3-review.sh:121/144） | test_l3_pipeline_fix.bats:61-80（AC-3 · T15 边界）· test_hook_integration.bats:55（T15）· l3-truncation.bats:31/37 · test_lib_split_metrics.bats:46-52（位置断言，域外） | 留 | 复杂度 Top10 最佳删除标的；断言面横跨 T15 边界内外，须专门 change 统一收口 |
| 6 | `validate_staging_coverage` | lib/validate_staging.sh:17（138 行） | **1（D-3 勘误）**：仓库根 package-flow-kit.sh:10 source + :18 调用 | test_archive_commit_gate.bats:136 · test_lessons_cleanup.bats:155 · test_package_flow_kit.bats:33（域外） | 留 | **不是死代码**（打包完整性门禁，生产接线）；D-3 名单漏查根目录打包脚本，登记勘误 |

## 3. verify 真实输出（均实际执行）

1. `make lint` → `✅ shellcheck: no errors found`，rc=0。
2. `grep -rn 'jq_atomic_write' flow-kit-bundle/hooks/ | wc -l` → `0`（AC-12-a 达成；删前该域 2 命中 = common.sh:190 注释 + :192 定义）。
3. `make hooks-sync` → `✅ 已同步 4 个文件`（~/.claude/hooks、dist/dsh-flow-kit/hooks、dist/dsh-flow-kit/vendor/.../hooks、~/.config/opencode/hooks 各 1 文件 = common.sh；两个 dsh 运行时 node_modules 副本已一致——与 dist 同物理文件），rc=0。
4. `make check-hooks-sync` → 6/6 副本 `✅`，`✅ hooks 副本一致（漂移 0）`，rc=0。
5. 定向 bats：`grep -rl jq_atomic_write test/` 无命中 → common.sh 本次改动无受影响用例，无需定向跑（全量 make test 按 T14 禁令未跑，遵守 flock 互锁纪律）。

## 4. 域外引用清单（jq_atomic_write）

- **test/ 域**：零引用（健康报告「连测试都不调」属实）⇒ 无镜像双写需求。
- **.specs 文档面 ~14 处**：2026-09-29-HEALTH.md:800/1056/1066/1133/1151 · CONTEXT.md:696（TD-138）· LESSONS.md:804 · health/2026-07-01-FULL-SWEEP.md:36/260 · health/2026-07-01-POST-SWEEP.md:23 · archive/2026-07-21-gate-review-fix/TECH-BRIEF.md:109 · archive/2026-07-24-l2-l3-model-config/{DESIGN,INDEPENDENT-REVIEW-2,INDEPENDENT-REVIEW-3,TASK}.md · archive/2026-07-01-sweep-fix-2026-07/{DESIGN,INDEPENDENT-REVIEW-2}.md · 本 change REQUIREMENT/DESIGN/TASK/INDEPENDENT-REVIEW-2/3——均为历史台账/规格记录，按 REQUIREMENT AC-12-a R6（2026-09-29 对账）豁免机检，已在 14c 段登记，不代改。
- **dist/dsh-flow-kit/** 2 份副本：已随 `make hooks-sync` 同步清零（亦属「随打包再生不计」面）。
- **T15 的 7 个测试文件**：零命中（jq_atomic_write 无测试引用；l3_review_with_timeout/smart_truncate 的测试触点属 6 候选判定，只登记不代改）。

## 5. 偏差与报告项

1. **D-3 名单勘误（重要，报编排者）**：`validate_staging_coverage` 并非死代码——仓库根 `package-flow-kit.sh:10` source + `:18` 调用。健康报告「生产零调用」漏查根目录打包脚本。CONTEXT.md TD-138 与 HEALTH D-3 的该项应勘误（本任务无该文件写权）。
2. 6 候选判定全部「留」而非「删」：T14 write 边界仅 common.sh；4 个候选的删除须连动 T14/T15 域外测试文件，2 个（l3_review_with_timeout / smart_truncate）的断言/stub 面在 **T15 write 边界内**——为避免兄弟冲突只登记不代改。结论均已登记 CHANGE 14c，非静默。
3. TASK.md 简写路径 `flow-kit-bundle/hooks/lib/common.sh` 实为 `flow-kit-bundle/hooks/stop/lib/common.sh`；":188-192" 行号漂移按现文 :189-196 定位。
4. 未跑全量 `make test`（T14 禁令，T12c/T15 并行 flock 互锁）；受影响定向 bats 面为零。
5. `make hooks-sync` 同步了仓外用户级副本（~/.claude/hooks 等）——该 target 本身即部署同步动作，属任务指令要求。

## 6. 改动文件

- `flow-kit-bundle/hooks/stop/lib/common.sh`（删 8 行）
- `.specs/health-fix-2026-09c/CHANGE.md`（14c 段 +12 行：落地记录 + 6 候选判定表）
- `.specs/health-fix-2026-09c/T14-SUMMARY.md`（本文件）
