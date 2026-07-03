# REQUIREMENT: 将 .flow-active 状态完整性纳入 L2/L3 检查

- **Change ID**: flow-active-integrity
- **关联**: `@.specs/flow-active-integrity/CHANGE.md`、`@.specs/CONTEXT.md`

---

## 用户故事

- **US-1**：作为 flow-kit 用户，我希望各阶段 prompt 自检表能提醒 AI 在状态变更后更新 `.flow-active`，以便 session 内 phase/task/goal 字段不会漂移。
- **US-2**：作为 flow-kit 用户，我希望 Stop hook 能在会话结束时自动验证 `.flow-active` 与磁盘产物的一致性，以便即使 AI 跳过了 L2 自检，漂移也能被系统级兜底捕获。

## 验收准则（AC）

每条用 Given / When / Then，必须可验证。

### 前置定义：gates 字段结构

`.flow-active.goal.gates` 为 JSON 对象，key 格式 `"N→N+1"`（N 为整数 0-6），value 为枚举 `"pending" | "passed" | "skipped"`。pipeline transition 时 jq 更新对应 gate 为 `"passed"`。示例：
```json
{"0→1":"passed","1→2":"passed","2→3":"pending","3→4":"pending","4→5":"pending","5→6":"pending","6→7":"pending"}
```

### 前置定义：PHASE_ARTIFACTS 引用

phase 与必须产物的映射定义在 `flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh` 的 `PHASE_ARTIFACTS` 关联数组中（如 phase 1 → `REQUIREMENT.md`、phase 2 → `DESIGN.md`、phase 3 → `TASK.md`、phase 4 → `*-SUMMARY.md`、phase 5 → `TEST.md`、phase 6 → `REVIEW.md`、phase 7 → 全产物）。L3 hook 交叉验证时从此数组查表，而非硬编码映射。

### AC-1 · L2 自检表 — 状态变更后确认写入

- **Given** AI 执行了 phase/task 切换操作（如 `/flow phase N`、`/flow task T<N>`、toll-gate transition）
- **When** 当前阶段完成，触发自检表
- **Then** 各阶段 prompt 的 PCSC（Phase Completion Self-Check）表含以下自检项：
  ```
  | N | .flow-active 关键字段（phase/task_id/change_id/updated_at）已通过 jq 写入磁盘 | test -s .flow-active && jq -e '.updated_at' .flow-active >/dev/null | ✅ / ❌ |
  ```
  覆盖范围：所有执行 phase/task 切换的阶段 prompt（0-change、1-requirement、2-design、3-task、4-dev、5-test、6-review、7-integration）+ GO.md transition 段
- **验证方式**: 每个阶段 prompt 文件中 grep 命中上述自检项的唯一锚点文本 `".flow-active 关键字段（phase/task_id/change_id/updated_at）已通过 jq 写入磁盘"`——总数 ≥ 9（8 个阶段 prompt + GO.md）

### AC-2 · L3 hook — phase 与产物目录对齐

- **Given** session 结束，`.flow-active` 中 `phase="2"` 且 `change_id="foo"`
- **When** Stop hook 28 号模块（或新增 33 号模块）执行 `.flow-active` 交叉验证
- **Then** 检测 `.specs/foo/` 下是否存在 phase 2 的必须产物（DESIGN.md）；若缺失 → 写入矫正文件 `.flow-active.correction`（type=state-integrity），列出缺失项
- **验证方式**: bats 测试——构造 `phase=2` + `change_id=test-change` + `.specs/test-change/DESIGN.md` 不存在的场景，验证 hook 输出含 "missing artifact" 检测结果

### AC-3 · L3 hook — change_id 与目录一致性

- **Given** `.flow-active.change_id = "foo"` 但 `.specs/foo/` 目录不存在（已归档/已删除/从未创建）
- **When** Stop hook 执行 `.flow-active` 交叉验证
- **Then** 检测到 change_id 指向不存在的目录 → 写入矫正文件，提示 "change_id 'foo' 无对应 .specs/ 目录，是否已归档但 change_id 未清除？"
- **验证方式**: bats 测试——构造 change_id 悬空 + change_id=null 但存在活跃产物目录两种场景

### AC-4 · L3 hook — pipeline goal 字段交叉验证

- **Given** `.flow-active.goal.scope = "pipeline"`，`phases_done = ["0","1"]`，`current_phase = 2`
- **When** Stop hook 执行交叉验证
- **Then** 逐项检查：
  - `phases_done` 中每个 phase（整数，但 JSON 中序列化为字符串 `"0"`/`"1"`/…）的产物均存在——查 `PHASE_ARTIFACTS`（见前置定义）获取该 phase 必须产物列表，逐一 `test -f .specs/<change_id>/<artifact>`
  - `current_phase`（整数，JSON 中序列化为字符串如 `"2"`）对应的前一个 gate `"<current_phase-1>→<current_phase>"`（即 `"1→2"`）状态为 `"passed"`
  - `gates` 中每条状态为 `"passed"` 的 key `"N→N+1"`，其左侧阶段 N 应出现在 `phases_done` 中
  - 任一不一致 → 写入矫正文件 `.flow-active.correction`（type=state-integrity，列出具体不一致字段）
- **验证方式**: bats 测试——构造 (a) phases_done 含 phase 但产物缺失、(b) gate passed 但 phases_done 无对应记录，两种场景各一条 case

### AC-5 · L3 hook — updated_at 时效性检测

- **Given** `.flow-active.updated_at` 为 Unix epoch 时间戳，距当前时间超过 24 小时
- **When** Stop hook 执行交叉验证
- **Then** 报告 "stale .flow-active" 警告（非阻塞），提示 "updated_at 超过 24h 未更新，可能漏维护"
- **验证方式**: bats 测试——构造旧时间戳场景，验证 hook 输出含 "stale" 关键词

### AC-6 · L3 hook — token_spent 未维护检测

- **Given** `.flow-active.token_spent = 0`，且本次 session 的 transcript 中至少包含一条对 `.flow-active` 的 `jq` 写入命令（匹配模式：grep `jq.*\.flow-active` transcript 命中 ≥1 条）
- **When** Stop hook 执行交叉验证
- **Then** 检测到 token_spent 未被更新（仍为初始值 0）→ 写入矫正文件，提示 "token_spent 未维护，仍为初始值"
- **验证方式**: bats 测试——构造 token_spent=0 + transcript 含 jq .flow-active 操作的场景，验证 hook 输出含 "token_spent" 关键词

> **注**：AC-2（phase-artifact 对齐）与 AC-4（pipeline goal 字段交叉验证）互补——AC-2 检查「当前 phase 产物是否存在」（单点检查），AC-4 检查「phases_done/gates/current_phase 三者自洽」（跨字段检查）。两者可能同时触发同一缺失（如 phase 2 产物缺失会被 AC-2 和 AC-4 同时报告），这是预期行为——冗余检测提高漏检率。

---

## 范围切分

### v1（本次必做）

- AC-1: L2 prompt 自检表加 .flow-active 确认项（覆盖全部 8 个阶段 prompt + GO.md transition 段）
- AC-2: L3 phase-artifact 对齐验证
- AC-3: L3 change_id 一致性验证
- AC-4: L3 pipeline goal 字段交叉验证
- AC-5: L3 updated_at 时效性检测
- AC-6: L3 token_spent 未维护检测
- 矫正文件输出（复用现有 `.flow-active.correction`，新增 type=state-integrity）
- bats 测试覆盖全部 6 条 AC 的检测逻辑

### v2（下一轮考虑，不本次）

- token_spent 自动统计：Stop hook 从 transcript 自动计算 token 消耗并更新（当前仅检测未维护，不自动统计）
- `/flow doctor` 扩展：自动修复检测到的简单漂移（如 change_id 清理、updated_at 刷新）
- 跨 session 趋势分析：多次漂移累计后触发升级告警

### out（永远不做）

- 实时文件监控（inotify/daemon）—— flow-kit 是 session 边界检查模型，不做常驻进程
- .flow-active JSON schema 变更——只加检查不改结构
- 自动修复漂移（v1 只检测+报告，修复留给人或 doctor 命令）

---

## 非功能性需求

- **性能**: Stop hook 新增检查 ≤ 200ms（不显著增加 session 结束延迟）
- **可靠性**: 以下异常场景必须容错处理，不崩溃、不阻断 Stop hook 链：jq 不可用（跳过检查）、`.flow-active` JSON 格式损坏（写入矫正文件 + 跳过）、`.specs/` 目录遍历失败（跳过该阶段检查）、`PHASE_ARTIFACTS` 未加载（回退到内置最小映射）
- **可访问性**: 无
- **安全**: 矫正文件内容不暴露敏感路径（仅记录 change_id / phase，不记录绝对路径）
- **兼容性**: 向后兼容——`.flow-active` 缺少新增字段时跳过对应检查，不报错
- **可观测性**: 每次检测到漂移时在矫正文件中记录时间戳 + 检测类型 + 具体不一致字段

## 依赖与假设

- 依赖现有 Stop hook 28 号模块（`weak-model-compliance.sh`）的矫正文件写入机制
- 依赖 `correction-file.sh` lib 的通用 JSON 写入函数
- 依赖 `flow-kit-artifacts.sh` 的 `PHASE_ARTIFACTS` 关联数组（用于 phase-artifact 对齐）
- 假设 `.flow-active` JSON 格式有效（无效时 hook 应容错跳过，不崩溃）
- 假设 transcript 文件在 Stop hook 执行时仍可读（用于 token_spent 检测）

---

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
