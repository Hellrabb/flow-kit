# REQUIREMENT: 加固 toll-gate 不可绕过性 + 扩展 L2 独立审查到 3/5/7

- **Change ID**: gate-integrity
- **关联**: `@.specs/gate-integrity/CHANGE.md`、`@.specs/CONTEXT.md`
- **修订**: 2026-07-01 · 基于 L2 盲审（`INDEPENDENT-REVIEW-1.md` R1-R7）修订

---

## 用户故事

- **US-1**：作为 pipeline goal 用户，我希望主 agent 无法通过伪造 `.done` / 跳过 review 子进程来绕过 toll-gate 与 L2/L3 门禁，以便全自动推进时的质量门禁真正生效而非形同虚设。
- **US-2**：作为 pipeline goal 用户，我希望 3-task / 5-test / 7-integration 阶段也具备 L2 独立审查能力（显式开启），以便这些阶段的输出有独立校验，而非 agent 自评自通过。

## 验收准则（AC）

每条 Given / When / Then，可机器验证。

### AC-1 · .done 真实性（5 类威胁 · 含 L3 实证攻击面）

- **Given** 阶段 gate 开启；`.done` 产出方 / 内容 / gate 配置存在以下任一无效情形：① 空文件（`touch`）；② 含伪造 review 证据；③ 主 agent 用 Write 自产（未经子 agent）；**④ 移花接木：复用旧阶段 / 其他 review / 其他 change 的合法 `.done` 到当前 goal/session**；**⑤ 混合篡改：用 Write 修改子 agent 已产出的合法内容**；**⑥ gate_config 篡改：agent 改 `.flow-active.goal.gate_config[phase]=false` 跳过整个 gate（L2-R3 R2 新增 · 廉价检测入 v1）**
- **When** 主 agent 尝试 transition / commit / PR
- **Then** hook 识别无效，拒绝。**需求约束（L103 重定义 2026-07-02c · v1 现实立场 · L2-R3 R1 对齐）**：① **T1/T2 元数据 + phases_done 短路**（挡①空 + ②KVP 伪造）；② **session_id 跨会话锚点**（挡④ 跨会话复用）；③ **D7 常见写向量握手锚点**（挡③ + ⑤-L3 **常见路径**：Write/Edit tool + Bash 重定向/cp/mv/sed/tee → `.flow-active.independent-review`）；④ **T4 字符串比对**（挡⑤-L2，.md 同篡 v1 靠比对提高成本）；⑤ **⑥ gate_config 篡改检测**（`.specs/<id>/.goal-snapshot.json` 入库快照 + transition diff，phase key 由 independent→false/缺失 → deny）。**v1 诚实边界**：③ exotic Bash 逃逸（python-c/dd/变量间接）+ ⑤-L2 .md 同篡——v1 靠常见向量挡 + 审计链，完全挡留 v2 加密签名。载体/算法由 DESIGN 定
- **验证方式**: `regression-demos/empty-done`（①）+ `forged-done`（②③）+ `hijack-done`（④）+ `tampered-done`（⑤）+ `gate-config-tamper`（⑥）+ bats

### AC-2 · transition 前置查 gate + 扩展单一源全链（威胁③ + 协议缺口 · R3）

- **Given** 阶段 gate 开启；主 agent 既未产合法 `.done` 也未派 review 子进程，请求 phase N→N+1 transition。现状 `pipeline-gates.md`（53 行）自述范围仅 4-dev，全链 gate key（0→1...6→7）的 transition 校验语义未定义
- **When** transition 执行
- **Then** ① transition 前置查 `goal.gates["N→N+1"]` 非 passed（无合法 `.done`）则拒绝推进；② 本 change 扩展 `pipeline-gates.md` 单一源覆盖全链 gate key 的 transition 校验语义，消除协议缺口
- **验证方式**: `regression-demos/skipped-subprocess/check.sh` + bats + `grep` 验证 `pipeline-gates.md` 含全链 gate 段

### AC-3 · 3/5/7 L2 gate 接入（扩 hook 阶段判定 · R4）

- **Given** gate-config 含 `3-task` / `5-test` / `7-integration` = independent（默认 off，用户显式开）。现状 `independent-review-gate.sh:39` 硬编码 `^(1|2|6)$`，`:57-60` case 仅映射 1/2/6
- **When** pipeline 推进经 3/5/7，主 agent 尝试 transition / commit / PR 且未写合法 `.done`
- **Then** gate 拦截（与 1/2/6 一致）。阶段判定正则 `^(1|2|6)$` 从**镜像 3 处**（`independent-review-gate.sh:39` / `29-independent-review.sh:33` / `flow-kit-artifacts.sh:109`）+ case phase_name 映射**镜像 2 处**（`independent-review-gate.sh:58-60` / `flow-kit-artifacts.sh:117-119`）**同步扩全 6 阶段**（1/2/3/5/6/7），阶段判定改动态读 `.flow-active.goal.gate_config`（含 3/5/7 即拦，与 AC-4 默认 off 一致）；bats 断言全 5 站点覆盖（L2-R3 R5）
- **验证方式**: bats（fixture：gate_config 含 3/5/7 → 门禁触发；`test_gate_config_presets.bats` 现有 20 tests 不破坏）+ 手动 UAT-1

### AC-4 · gate-config 预设 / 数字映射扩展（默认 off）

- **Given** `/flow goal --gate-config` 解析逻辑（PRESET_MAP + 数字映射，现仅 1/2/6）
- **When** 用户传 `full` → 仍只含 1/2/6；传 `1,2,3,5,6,7` → 含六阶段；新增 `all` 预设 → 含 1/2/3/5/6/7
- **Then** 数字映射扩 3→`3-task`、5→`5-test`、7→`7-integration`；`full` 不变（默认 off 含义）；新增 `all` 预设供显式开 3/5/7
- **验证方式**: bats（`test_gate_config_presets.bats` 扩展 + 新数字映射单测）

### AC-5 · bats 覆盖 + 不回归（基线 213 · R1 修正）

- **Given** AC-1~4 实现完成
- **When** 运行 `npx bats test/`
- **Then** 新增测试覆盖 .done 真实性 / transition 前置 gate / 3-5-7 gate / 预设扩展，全部通过；现有测试 0 回归（基线以 `test/` 实测为准 = **213 tests** @ 2026-07-01；`STATE.md` / `CONTEXT.md` 历史数字过时，不作基线）
- **验证方式**: `npx bats test/` exit 0；总数 = 213 + 新增

### AC-6 · L3 机制实际生效 + 写入正确（dogfood 实证 · 解死锁为机制验证）

- **Given** AC-1~5 假设 L3 实际运行。**现状（本 change dogfood 实测根因）**：`common.sh:89` `CONFIG_FILE` 默认 `${PROJECT_ROOT}/.claude/stop-hook.json`（项目级），本项目无此文件 → `module_enabled` 读不到返回 false → 29 号 Gate 1 `exit 0` → **L3 从未自动产出**（全局 `~/.claude/stop-hook.json` `enabled=true` 未被读，**非 enabled 问题**）。**叠加 L3 写入 bug**：L3 用 `>` 覆盖 `INDEPENDENT-REVIEW-N.md`（毁 L2 审计链）+ dump 原始 API JSON + 握手 `fail_count` 不随 verdict（`verdict=fail` 仍 `fail_count=0`）+ `module_output` 路径权限错
- **When** 修正 CONFIG_FILE 解析（项目级缺失回退 user-scope）+ 修 L3 写入（追加非覆盖 / 解析 JSON 不 dump / `fail_count` 随 verdict / `module_output` 路径）+ 验证
- **Then** ① `module_enabled` 能读到启用配置（CONFIG_FILE 回退或项目级文件提供）；② **L3 追加**到 `INDEPENDENT-REVIEW-N.md`（非覆盖 L2），仅写解析后报告（非原始 JSON）；③ 握手 `fail_count` 随 verdict（fail→≥1）；④ **机制验证用 Mock / 手动标记模拟 L3 产出验证连通性，不强制「L3 实际产出」作为 AC-6 通过条件**（解 AC-6↔AC-1 死锁，回应 L3-major）；⑤ bats 覆盖
- **验证方式**: Mock 连通性测试 + bats（CONFIG_FILE 回退 / L3 追加不覆盖 / `fail_count` 随 verdict）

---

## 质量约束（非 AC · DESIGN / DEV 执行依据）

- **结构刚性**（原 AC-7 降级 · R5）：新增 prompt 护栏属结构刚性（强模型也受益、不啰嗦），每段 ≤3 行（`wc -l` 可客观验证）。这是设计 / 实现约束，不是需求层 AC，避免污染 TEST 阶段自动化。

## 范围切分

### v1（本次必做）

- AC-1 .done 真实性（**L103 重定义 2026-07-02c**：v1 挡①②④完全 + ③⑤**常见写向量**挡[Write/Edit tool + Bash 重定向/cp/mv/sed/tee → 握手文件] + 审计链；③ exotic Bash 逃逸 + ⑤-L2 .md 同篡 留 v2 加密签名。原"主 agent 自产一律拒"经 L2-R2 R1/R6 证伪——单机无 agent 不可访问锚点）
- AC-2 transition 前置查 gate + 扩展 `pipeline-gates.md` 全链
- AC-3 3/5/7 L2 gate 接入（改 `independent-review-gate.sh`）
- AC-4 gate-config 预设 / 数字映射扩展（默认 off）
- AC-5 bats 覆盖 + 不回归
- AC-6 hook 实际接线 + L3 模块启用 + 生效验证（dogfood 发现 · 防 gate 空架）
- ≥3 regression-demo（empty-done / forged-done / skipped-subprocess）
- 质量约束（结构刚性）

### v2（下一轮考虑）

- L4 model_tier opt-out（强模型降级开关）
- `.done` 真实性的加密签名 / 内容哈希强化（v1 基础判定之上的更强防御；**v1 基础判定必做，不整体降级**）
- review 子进程本身的 L3 证据链（防 review agent 自己幻觉证据）

### out（永远不做）

- 重构 pipeline goal 整体语义 / toll-gate 概念模型
- 改 1/2/6 现有 L2 blind-review 触发机制
- 改 brooks-lint 集成路径

---

## 非功能性需求

- **性能**: 新 hook 校验不显著拖慢 transition（增量 ≤ 现有 hook 单次耗时量级；`time` 对比）
- **可访问性**: 无（非 UI）
- **安全**: `.done` 校验逻辑不可被主 agent 通过修改 hook 配置绕过（校验在 hook 层，agent 无法关 hook）
- **兼容性**: 旧 `.done` / 旧 goal 数据 tolerant read + detect-and-warn（不强制迁移）
- **可观测性**: hook 拒绝时输出可读原因（缺哪类证据 / 哪个 gate 未 passed）

## 风险（含 R7 升级）

- **transcript 边界可区分性**（R7 升级 · AC-1 落地基石）：AC-1 的"非子 agent 产出"判定依赖区分主 agent vs review 子 agent 的工具调用 / transcript。若 DESIGN 验证发现不可区分，AC-1 **block 不退化**（**不**降级为"静态字段校验"——静态字段正是 CHANGE 要消灭的 touch 漏洞；与范围 v1「不整体降级」一致），此时需回 REQUIREMENT 重定义 AC-1 的可验证信号。缓解：DESIGN 第一步优先验证子 agent 独立 session / agentId 可识别。
- **.done 真实性判定载体**（DESIGN 核心）：写入者标识 vs transcript 边界 vs 子 agent 握手，三选一或组合，DESIGN 定。
- **token 成本**：3/5/7 加 L2 后 pipeline 多三次盲审。默认 off（AC-4）已缓解。
- **向后兼容**：旧 `.done` / 旧 goal tolerant read + detect-and-warn。
- **meta 风险**：本 change 用 flow-kit 加固 flow-kit。6-review 开 `6-review=independent` 时"用自己的 L2 审自己写的 L2 机制"，REVIEW 阶段需注意证据链真实性。
- **鸡生蛋（AC-6 vs L3）·已解**：AC-6 验证 L3 生效，但 L3 生效是 AC-6 工作。**回应 L3-major**：AC-6 Then 改「机制验证」（Mock / 连通性），不强制 L3 实际产出作为 AC-6 通过条件。1-requirement 阶段已手动触发 L3 实证机制可跑（根因 = CONFIG_FILE 指向项目级缺失文件，已纳入 AC-6）。
- **L3 写入机制 bug**（dogfood 实证 · 纳入 AC-6 修复范围）：`>` 覆盖毁 L2 审计链 / dump 原始 API JSON / `fail_count` 不随 verdict / `module_output` 路径权限错。
- **AC-1 威胁③ v1 覆盖度（L103 重定义 · 2026-07-02c · L2-R2 R1/R6 证伪"绝对挡"）**：单机单环境下 hook 能写的 agent 经 Bash 都能写，**无 agent 不可访问锚点**。故 v1 改 **B'**（用户选）：D7 挡**常见写向量**（Write/Edit tool + Bash 重定向/cp/mv/sed/tee → `.flow-active.independent-review`）+ 多文件交叉审计链；**exotic Bash 逃逸**（`python -c`/`dd`/变量间接/base64）+ ⑤-L2 .md 同篡 留 v2 加密签名。SESSION_ID 锚点挡威胁④（跨会话复用）。L70 v1 scope 已同步重定义。

## 依赖与假设

- 依赖现有 hook：`29-independent-review.sh`、`independent-review-gate.sh`、`flow-kit-artifacts.sh`（PHASE_ARTIFACTS）
- 依赖 `@flow-kit/reference/pipeline-gates.md` 单一源协议（本 change 扩展其范围）
- 假设 `ANTHROPIC_DEFAULT_HAIKU_MODEL` env-var-first 配置可用（L3 外部模型审查）

---

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
