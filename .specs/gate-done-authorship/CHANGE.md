# CHANGE: 独立 review gate `.done` 作者性校验缺口（握手机制死代码）

- **Change ID**: gate-done-authorship
- **创建日期**: 2026-07-24
- **路径建议**: 完整
- **状态**: seed（已立项，未启动 pipeline）
- **来源**: l2-l3-model-config phase 6 review 期间发现（INDEPENDENT-REVIEW-6 主 agent 裁判段）

---

## Why（为什么做）

独立 review gate 的「`.done` 标志」机制存在**安全设计缺口**：Gate 3（`fk_independent_review_gate_active`）只要 `.done` 文件**存在**就短路放行 phase transition，**不校验 .done 由谁写入**。原本用于证明「.done 由 stop-hook 子进程（而非 agent）写入」的**握手机制（`.flow-active.independent-review`）已是死代码**——无生产代码写它，仅测试 fixture 写。结果是 agent 可自写一个结构合法的 `.done` 绕过 L3 外部模型审查。

不修会导致：独立 review gate 的「双层审查」保证可被主 agent 用一个伪造 `.done` 单方面绕过；L3 外部模型审查形同虚设（agent 想跳就跳）。

### 证据链（l2-l3-model-config 调查期间核实）

1. **握手写入是死的**：全 `flow-kit-bundle/hooks/` 无任何生产代码构造握手 JSON（`{"<phase>":{"status":"done","verdict":...,"written_by":"stop-hook-29",...}}`）。`stop-hook-29` 作为写入值只出现在 `test/regression-demos/` + `test_gate_integrity.bats` fixture + `done-validation.sh` 的**校验**端。`l3_review_run` 只写 `.done`，不碰握手。
2. **握手生命周期是死的**：`29-independent-review.sh` 对 `state_file` 只 **读（:68-74 幂等）+ 删（:125, :203-204）**，从不写。:202 注释明说「不再需要——l3_review_run 直接写 .done」。
3. **握手检查在 gate 主流程不可达**：`done-validation.sh` Tier 2（:140-149 T3 握手校验）要求握手文件 `written_by=stop-hook-29`。但 Gate 3（`fk_validate_done_marker` 之前）见 `.done` 存在即返回「未开启」→ `exit 0` 放行，**永远到不了 Tier 2**。实测：写合法 `.done` 后 `fk_independent_review_gate_active 6` 返回 rc=1（未开启→Gate 3 放行）。
4. **但 Tier 2 在单元测试层是活的**：`test_gate_integrity.bats` 4 个测试（AC-1 ②③ forged-done / ④ hijack / ⑤ tampered / D9 正向）主动写握手并断言 T3/T3b/T4 行为——编码了「.done 须由 stop-hook 作者证明」的安全意图。即：**意图（测试）与现实（gate 主流程）脱节**。

### 根因

Gate 3 的短路条件是 `.done` **存在性**，不是**作者性**。握手本该补作者性证明，但写入路径在历次 gate 重构（`1bd3d0a` L2/L3 拆分 / `189ca2a` gate-review 等）中演变为「l3_review_run 直接写 .done」的设计，握手写入被废弃但**校验 + 测试未同步清除**，留下「活校验 + 死写入 + 不可达」的不一致。

---

## What（做什么）· 两种候选方案（需 DESIGN 阶段定）

### 方案 A · 彻底废弃握手，改用 .done 作者性锚点（推荐方向）

承认 `.done` 是唯一 anchor，删除握手全部痕迹，并补上真正的作者性校验：
- `done-validation.sh`：删 Tier 2 T3 握手校验（:140-149）+ `[[ "$tier" == "transition" ]]` 死分支
- `29-independent-review.sh`：删 state_file 读/rm（:68-74, :125, :203-204）
- `independent-review-gate.sh` path-guard：**扩展 D7**，禁止 agent（Bash/Write/Edit）写 `.independent-review-*.done`，使 `.done` 成为 stop-hook 独占（新作者性锚点）
- **例外**：gate_config=`L2`（仅 L2）模式下协议要求**主 agent 写 .done**（6-review.md:129）→ path-guard 须在该模式放行 agent 写 .done（按 gate_config 条件放行，非全局禁）
- 改写 `test_gate_integrity.bats` 4 个握手测试为「.done 作者性」语义
- 改/删 `test/regression-demos/tampered-done/` + `exotic-escape/` 握手 demo

### 方案 B · 恢复握手写入 + 让 Tier 2 可达

让握手重新生效：
- `l3_review_run`（`_l3_write_done`）写 .done 时**同时写握手**（stop-hook-29 作者标记）
- 移除 `29:204` 的无条件 `rm -f state_file`（改条件清理：仅 transition 成功后清）
- 让 Gate 3 不再仅凭 .done 存在短路——须配合握手/Tier 2 验作者性
- 复杂度更高（涉及 Gate 3 短路语义改动 + 握手生命周期跨 session 保持）

> DESIGN 阶段须二选一并补威胁模型分析（agent 伪造 .done 的所有路径）。

---

## Out of Scope

- 不改 L2/L3 模型解析（那是 l2-l3-model-config 的 scope）
- 不改 gate_config 三值（L2/L3/both）语义
- 不触碰 `gate-review-fix` 的 13 条缺陷（独立 scope，可并行）

---

## 关联

- 发现于 `l2-l3-model-config` INDEPENDENT-REVIEW-6.md「主 agent 裁判」段（2026-07-24）
- 相关代码：`flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh`（Gate 1/3）、`flow-kit-bundle/hooks/stop/lib/done-validation.sh`（Tier 2）、`flow-kit-bundle/hooks/stop/29-independent-review.sh`（state_file 生命周期）、`flow-kit-bundle/hooks/stop/lib/l3-review.sh`（`_l3_write_done`）
- 记忆笔记：L3 模型不可靠（[[l3-model-unreliable]]）、gate 编排层须集成测试（[[gate-orchestration-integration-test]]）
