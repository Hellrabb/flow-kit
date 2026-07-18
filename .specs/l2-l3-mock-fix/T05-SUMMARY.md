# T05-SUMMARY — D5·K 26-workflow.sh G1 pipeline goal 模式不 auto-advance

- **Task**: T05 (D5·K) — 26-workflow.sh G1 加 `goal.scope=pipeline` 守卫，pipeline 模式不 auto-advance .phase
- **Change**: l2-l3-mock-fix
- **关联**: ADR-011 / REQUIREMENT AC-K / DESIGN D5 / R4
- **状态**: ✅ verify 全绿（T05 单测 4/4 + 全套 535/1，AC-3 基线保持）

## 改动清单

| 文件 | 改动 |
|---|---|
| flow-kit-bundle/hooks/stop/26-workflow.sh | G1（:74-95）fk_auto_phase 调用前置 `goal_scope` 守卫：`jq -r '.goal.scope // "phase"'` → `goal_scope != "pipeline"` 才调 fk_auto_phase。pipeline 模式 next_phase 恒空 → 走 hint 分支不写 .phase（推进归 toll-gate）。fk_auto_phase 函数**不改** |
| test/test-pipeline-no-g1-autoadvance.bats | 新建：4 测（子进程真跑 26-workflow.sh + jq 断 .phase） |
| flow-kit-bundle/test/test-pipeline-no-g1-autoadvance.bats | AC-7 一致性同步 |

## ADR-011 方案

- **Decision**：26-workflow.sh G1 棪测 `goal.scope=pipeline` 时不调 fk_auto_phase 写 .phase —— 推进权归 toll-gate（/flow 人工 + 31-auto-advance.sh 完整 transition），避免 pipeline goal 在 review 未开阶段（fk_independent_review_gate_active=false）被 G1 静默推进，造 phase/current_phase 不一致（AC-K）
- **fk_auto_phase 函数不改**：保留单阶段 goal 用途，仅 26-workflow.sh G1 调用方加 scope 守卫
- **否决备选**：(i) G1 保留 auto-advance + 同步四字段 —— 违反 transition 单一写入点原则（与所修 bug 同型）；(iii) 删 fk_auto_phase —— 影响单阶段 goal，过激
- **单阶段/双模式分支**：pipeline 不 advance / 单阶段（scope=phase 或无 goal.scope）保留 auto-advance（测试覆盖两路径，R4）

## verify 结果

| 检查 | 结果 |
|---|---|
| T05 单测（AC-K-1 pipeline 不 advance / AC-K-2 单阶段 advance / AC-K-3 无 scope 默认单阶段 / 守卫特征） | ✅ 4/4 pass |
| 全套 bats（改公共 hook 后基线回归 · L-010） | ✅ 535 ok / 1 not ok（AC-3 基线 fail 237 model env-var · 非 T05 范围） |
| 语法 `bash -n` 26-workflow.sh | ✅ OK |

## 6 维 self-review（内置快查 · 基于已验证证据）

1. **正确性** ✅：4/4 单测 + 全套 535/1（AC-3 基线保持，未破坏）
2. **复用（reuse）** ✅：沿用 fk_auto_phase（不改函数）；goal_scope 读取范式同 fk_independent_review_gate_active 的 `jq -r '.goal.scope'` 双源读
3. **简单性** ✅：守卫仅 +1 jq 读取 + if 条件加 `&& "$goal_scope" != "pipeline"`（净 +3 行有效逻辑，无新抽象）
4. **效率** ✅：1 次 jq .goal.scope（<1ms，与既有 jq 读取同量级 · NFR-1 守护）
5. **可读性** ✅：守卫注释引 ADR-011 + AC-K + toll-gate 语义 + fk_auto_phase 不改声明
6. **测试质量** ✅：子进程真集成（export PROJECT_ROOT/HOOK_TMP_DIR/CONMFIG_FILE 跑 workflow 模块 enabled，真跑 26-workflow.sh + jq 断 .phase，非 mock）；两路径全覆盖（pipeline 不 advance / 单阶段 advance / 无 scope 默认）+ 守卫特征 grep

## 越界检查（R6.5 / R7.3）

- ✅ 26-workflow.sh + test 在 T05 write_files 内
- ✅ flow-kit-bundle/test/ 副本 = AC-7 同步（非范围扩展）
- ✅ **未改 fk_auto_phase 函数**（ADR-011 · 保留单阶段用途）
- ✅ **未改 transition 单一写入点**（31-auto-advance.sh / fk_auto_phase gate_active 保护未碰）
- ✅ **未改 7 Gate 控制流**（DESIGN § 0.5.1 禁动）
- ✅ 未改 REQUIREMENT/DESIGN/其他 task 文件

## 沿用既有抽象 grep（1.4 · R6.4）

- `goal_scope` 读取沿 fk_independent_review_gate_active 的 jq `.goal` 双源读范式（grep NOT-EXIST 新重复）
- fk_auto_phase 沿用不改（ADR-011 单一来源）
- 子进程测范式沿 test_l3_pipeline_fix（HOOK_BASE_DIR 自找 + source lib）+ test_pipeline_rollback（fixture + jq 断言）

## 扫 LESSONS（1.5 · R1.8）

- **L-027**（bats 禁 `|tail`/`;echo EXIT` 吞 exit code）：全套 bats 用 `> log; ec=$?` 存真 exit + `grep -c not ok` 提摘要，非吞 exit
- **L-010**（破坏性变更后验证）：改 26-workflow.sh G1（公共 hook）→ 全套 bats 恢复验证（535/1）

## 破坏性变更（1.8 · R4.6）

- 改 26-workflow.sh G1 auto-advance 调用条件（公共 hook 行为：pipeline goal 从「静默 advance」改为「不 advance」）
- grep 引用图：26-workflow.sh 被 test_stop_chain（smoke）/ test_flow_active_integrity 引用；G1 advance 被 .flow-active.goal.scope=pipeline 的 change 依赖
- 回归覆盖：T05 单测两路径 + 全套 bats（上述引用测全过）

## 遗留（非 T05 范围）

1. **AC-3 基线 fail**（已装副本 inode 隔离，同 T01/T02/T03/T04）
2. **fk_auto_phase 调 fk_independent_review_gate_active 在单独跑 26-workflow.sh 时未定义**：done-validation.sh 不被 26-workflow.sh source（真实 stop 链由 00-gate.sh 带入）；单独跑时未定义命令返 127=不拦（等价无 gate）。本 change fixture 无 gate_config 故不影响测；既有架构隐含依赖，非 T05 范围
3. **Wave 2 完成（T01-T05 全 done）**：下一步 T06 全套 bats（已隐含跑 · 535/1）→ T07 NFR-1 性能 → T08 NFR-2 兼容（串行）
