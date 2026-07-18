# T03-SUMMARY — D3·I L2-first 顺序契约 + 双管可观测性

- **Task**: T03 (D3·I) — L2-first 顺序契约文档化 + 双管（correction 兜底 + deny reason）
- **Change**: l2-l3-mock-fix
- **关联**: ADR-009 / REQUIREMENT AC-I / DESIGN D3
- **状态**: ✅ verify 全绿（T03 单测 5/5 + 全套 525/1，AC-3 基线隔离）

## 改动清单

| 文件 | 改动 |
|---|---|
| flow-kit-bundle/hooks/stop/29-independent-review.sh | 抽 `_write_l2_missing_correction` helper + 两处 D4 门（主门 + fallback）增强提示（派发指引 + deny reason）+ 写 correction flag(type=l2-missing) |
| .specs/CONTEXT.md | L2-first gating 术语增强（ADR-009 调度契约 + BUG-I 根因修正） |
| test/test-l2-first-correction.bats | 新建：5 测试（静态 grep helper/两门提示 + 实跑 29 验证 correction flag + module_output） |
| flow-kit-bundle/test/test-l2-first-correction.bats | AC-7 一致性同步 |

## ADR-009 双管方案

- **(a) correction flag**：29 D4 门退出写 `.flow-active.correction`(type=l2-missing) 作持久化日志（主 agent 未派 L2 时跨 Stop 累积记录）
- **(b) deny reason + 派发指引**：两处 D4 门提示从"L2 not yet complete"增强为含"主 agent 请派 L2 子 agent 并写入 ## L2 盲审 段"指引 + "deny reason: L2-first 契约未满足"

## verify 结果

| 检查 | 结果 |
|---|---|
| T03 单测（helper + 两门提示静态 grep + 实跑 29 correction flag + module_output） | ✅ 5/5 pass |
| 全套 bats（1.8 破坏性变更回归） | ✅ 525 ok / 1 not ok（AC-3 基线） |
| 语法 `bash -n` 29 | ✅ OK |
| 实跑 29 写 correction flag(type=l2-missing) | ✅ |
| 实跑 29 写 module_output 日志（independent-review.txt 含派发指引） | ✅ |

## ⚠️ SessionStart 兼容缺口（重要遗留）

- `flow-kit-resume.sh:96` 仅对 `type=="compliance" && violations>0` 显示 banner
- T03 写 `type=l2-missing` flag → SessionStart **不识别** → D3 双管 (a) 的 banner **不触发**
- **AC-I (a/b/c) 不依赖 banner**（契约文档化 CONTEXT.md + 29 提示增强 + 日志已满足），T03 满足 AC-I
- correction flag 作持久化记录 + 未来 SessionStart 扩展识别载体
- **建议**：后续 change 扩展 flow-kit-resume.sh 识别 type=l2-missing（或本次 T03 扩展 write_files 改 SessionStart——但越界 R6.5，未做）

## 6 维 self-review（内置快查 · 基于已验证证据）

1. **正确性** ✅：5/5 单测（含实跑 29）+ 全套 525/1
2. **复用（reuse）** ✅：抽 `_write_l2_missing_correction`（两处 D4 门共用，避免 DRY）+ 沿用 test_dual_review_merge 静态 grep 范式 + 实跑 29（FLOW_KIT_L2_MOCK）
3. **简单性** ✅：helper 封装 correction 写入，两处门一行调用
4. **效率** ✅：correction flag 仅 D4 退出时写（非每操作）；jq 写入轻量
5. **可读性** ✅：提示含派发指引 + deny reason + 指向 `.flow-active.correction`；helper 注释标 ADR-009 + SessionStart 兼容说明
6. **测试质量** ✅：静态 grep（helper + 两门提示）+ 实跑 29（correction flag 文件 + module_output 日志双断言）

## 越界检查（R6.5 / R7.3）

- ✅ 29 + CONTEXT.md + test 在 T03 write_files 内
- ✅ flow-kit-bundle/test/ 副本 = AC-7 同步（非范围扩展）
- ✅ 未改 REQUIREMENT/DESIGN/其他 task 文件
- ✅ 未改 7 Gate 控制流（D4 门是 29 内 L2-wait 检测，非 _run_review_gates Gate transition）
- ✅ 未改 SessionStart hook（不在 write_files，缺口记遗留）

## 沿用既有抽象 grep（1.4 · R6.4）

- `_write_l2_missing_correction` 新建（grep NOT-EXIST，无重复）
- 沿用 module_output（common.sh:144）+ jq correction 文件范式（flow-kit-resume.sh:90 既有关联）
- 沿用静态 grep 29 范式（test_dual_review_merge:158）

## 扫 LESSONS（1.5 · R1.8）

- **L-027**（bats 禁 `|tail`）：T03 verify 直接判 exit
- **L-010**（破坏性变更后验证）：改 29 D4 门（公共 Stop hook 行为）→ 全套 bats 恢复验证（525/1）

## 破坏性变更（1.8 · R4.6）

- 改 29 两处 D4 门提示 + 加 helper（公共 Stop hook 行为变更）
- grep 引用图：29 被 test_l3_pipeline_fix / test_dual_review_merge / test_stop_chain 静态 grep
- 回归覆盖：T03 单测 + 全套 bats（含上述静态 grep 29 测试，全过）

## 遗留（非 T03 范围，记录供后续）

1. **SessionStart banner 不识别 l2-missing**（见上，D3 双管 a 的 banner 部分需 flow-kit-resume.sh 适配）
2. **AC-3 基线 fail**（已装副本 inode 隔离，同 T01/T02）
3. **memory [[l3-model-unreliable]] BUG-I 描述待更新**（ADR-009 Consequences 同步建议：BUG-I 从"触发不可靠"改为"L2-first 调度契约"）
