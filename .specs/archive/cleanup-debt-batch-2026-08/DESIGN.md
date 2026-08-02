# DESIGN · cleanup-debt-batch-2026-08

> **阶段**: 2-design · 2026-08-03
> **AI 版本**: GLM 5.2 (Sisyphus, OpenCode)

---

## § 0 · 技术栈

| 维度 | 选择 | 理由 |
|---|---|---|
| 语言 | Bash + awk + jq | 既有 |
| 测试 | bats-core 1.13.0 | 既有（657 测试基线） |
| 新依赖 | 无 | 全部修复用既有工具 |
| 风格 | `set -euo pipefail` / `fk_*` 公共 / `_fk_*` 私有 | 既有命名约定 |

## § 0.5 · 架构对齐

### 触碰的模块

| 模块 | 路径 | 触碰原因 |
|---|---|---|
| scripts/review-package | `flow-kit-bundle/flow-kit/scripts/review-package` | L-071 加 ref validation |
| package-flow-kit.sh | `package-flow-kit.sh` Part B | L-069 加 M-health.md cp 行 |
| 29 hook | `flow-kit-bundle/hooks/stop/29-independent-review.sh` | L-072 重排 |
| 4-dev.md | `flow-kit-bundle/flow-kit/prompts/4-dev.md` | L-068 压缩 |
| reference/ | `flow-kit-bundle/flow-kit/reference/{tdd-workflow,commit-protocol,checkpoint-protocol}.md` | L-068 抽取目标 |
| CONTEXT.md | `.specs/CONTEXT.md` 禁动清单 | L-072 exception 段 |
| bats tests | `test/test-{scripts-security,integration-smoke,l2-first-correction,4-dev-compress,package-validate}.bats` | 各 fix 配套测试 |

> **L-070 已确认非 bug**（INDEPENDENT-REVIEW-2 R1 + 实测 m00283）：`flow-kit-bundle/lib/validate_staging.sh::validate_staging_coverage()` L127-131 **已正确** `exit 1` 当 `ERRORS > 0`。本 change 不修改 validate_staging_coverage 函数体。

### 既有抽象 沿用

| 抽象 | 路径 | 用途 |
|---|---|---|
| `set -euo pipefail` | 全脚本 | 错误处理基线 |
| `fk_resolve_model "L3"` | hooks/stop/lib/common.sh | L-072 hook 检测 L3 model |
| `_write_l2_missing_correction()` | 29 hook 内 | L-072 重排后调用 |
| `validate_staging_coverage()` | `flow-kit-bundle/lib/validate_staging.sh` | L-069 间接（cp 行加到 caller package-flow-kit.sh）；函数体实测已正确 exit 1，**L-070 非 bug** |
| `@see reference/X.md` 片段引用 | 既有 GO.md / prompts | L-068 抽取后引用模式 |
| `git rev-parse --verify` | git 内置 | L-071 ref validation |

### 沿用 vs 引入模式决策

| 决策 | 沿用/引入 | 理由 |
|---|---|---|
| ref validation 实现 | 沿用 git rev-parse | 安全 API，无需自造 |
| validate exit code 模式 | 沿用 bash rc 约定 | 与 `set -e` 配合 |
| 29 hook 重排策略 | 引入"逻辑段顺序调整"模式 | 首次触碰 hook 内部逻辑顺序 |
| 4-dev.md 抽取策略 | 沿用 GO.md 压缩模式（superpowers-v6-absorb ADR-018） | 同套路 |
| AC-F4 git log 验证 | 引入 meta-AC 模式 | 首次验证 change-id 范围 |

## § 1 · 决策

### D1 · L-071 review-package ref validation 策略

**问题**: review-package 接受任意字符串作为 base/head 参数，不验证是否为合法 git ref。

**备选**:
- (a) `git rev-parse --verify "<ref>^{commit}"` — git 内置，安全
- (b) 正则白名单 — 容易漏（HEAD~1合法，但 `master@{1.week.ago}` 也合法）

**选 (a)**。理由：git rev-parse --verify 是 git 官方 ref 解析 API，覆盖所有合法 ref 语法（branch / tag / HEAD~N / reflog / sha），无需维护正则。失败返回非零 + stderr，与既有 `set -euo pipefail` 自然集成。

**代价**: 单次 git rev-parse 调用 ~5ms（本地），happy path 增 ≤10ms 满足 NFR。

**实现**:
```bash
# review-package L20-25 新增（在既有 git-dir check 后）
for ref in "$BASE" "$HEAD"; do
  if ! git rev-parse --verify "${ref}^{commit}" >/dev/null 2>&1; then
    echo "fatal: bad revision '${ref}'" >&2
    exit 1
  fi
done
```

### D2 · L-069 package validate M-health.md 漏配（L-070 已确认非 bug，移出范围）

**问题**: 
- (L-069) M-health.md 实际存在于 `flow-kit-bundle/flow-kit/prompts/M-health.md` 但 Part A-G 中无 cp 指令，validate_staging_coverage() 报漏配（WARNING 行：源缺失）。
- ~~(L-070) validate_staging_coverage() 即使发现 error 也最终 exit 0~~ — **已确认非 bug**（INDEPENDENT-REVIEW-2 R1 + 实测 m00283: `bash package-flow-kit.sh --validate; echo $?` → exit=0 + 0 ERROR + 2 WARNING）。函数体 `flow-kit-bundle/lib/validate_staging.sh:127-131` 已正确：
  ```bash
  if [ "$ERRORS" -gt 0 ]; then
    echo "❌ 校验失败"
    exit 1
  elif [ "$WARNINGS" -gt 0 ]; then ... exit 0
  else ... exit 0
  fi
  ```
  LESSONS.md L-070 需更新为 "已验证非 bug"。

**备选**:
- (L-069 a) 加到 Part B（prompts 段，与 0-change.md/1-requirement.md 等并列）
- (L-069 b) 加到 Part F（health 段，与 brooks-lint 健康检查相关）

**选 (L-069 a)**。理由：M-health.md 是 phase prompt（与 M-health skill 对应），属 `prompts/` 目录，Part B 已有 13 个 prompts 的 cp 列表，加一行最少改动。

**代价**: Part B 加一行 `install_file` 指令。

**实现**:
```bash
# package-flow-kit.sh Part B（prompts 段，紧邻 1-requirement.md / 2-design.md 等）末尾加:
install_file "flow-kit/prompts/M-health.md"
```

### D3 · L-072 29 hook reorder

**问题**: 29 hook 当前顺序 Gate1→Gate2→L3-model-missing(line 59-64)→...→L2-missing detection(line 181-185)。L3 short-circuit 在 L2 detection 之前，导致 L3-model-missing 时 L2-first 契约失效。

**备选**:
- (a) 直接把 L2-missing detection 段移到 L3-model-missing 检测之前
- (b) 在 L3-model-missing 时也调用 `_write_l2_missing_correction()` 备份
- (c) 完全重构 hook 为 "L2 detection always first" 单一原则

**选 (a)**。理由：
- (a) 最小改动，保留既有 L3 short-circuit 逻辑（仅在 L2 已完成时才检查 L3）
- (b) 双写 correction 文件可能 race（Stop hook 顺序写）
- (c) 重构 hook 核心逻辑风险大，禁动清单要求最小改动

**禁动清单 exception**: 29 hook 在 `.specs/CONTEXT.md` 禁动清单「independent-review-gate.sh + 29-independent-review.sh + fk_validate_done_marker — gate 校验核心链」段。本次改动属"内部逻辑顺序调整"，不动函数签名/接口/gate 行为。exception 段将写入 CONTEXT.md 禁动清单 cleanup-debt-batch-2026-08 子段，记录"L3 model check 段(L58-65) 与 L2 detection 段(L180-185) 顺序互换"（含语义描述 + 行号双标识，降低行号漂移失准风险）。

**代价**: 单文件改动，禁动清单 exception 增加 4-5 行。回归测试覆盖既有 AC-I(a)(b)(c) + 新增 AC-I(d)(e)。

**实现**:
```bash
# 29-independent-review.sh 结构调整:
# 原 line 59-64 (L3 model check) → 移到原 line 181-185 (L2 detection) 之后
# 原 line 181-185 (L2 detection) → 上移到 line 59 位置
# 即: L2 detection FIRST → L3 model check SECOND

# 验证场景矩阵:
# | L2 段存在 | L3 model 配置 | 旧行为            | 新行为 (期望)     |
# |-----------|---------------|-------------------|-------------------|
# | 否        | 否            | type=l3-model-missing | type=l2-missing (优先) |
# | 否        | 是            | type=l2-missing   | type=l2-missing (不变) |
# | 是        | 否            | type=l3-model-missing | type=l3-model-missing (不变) |
# | 是        | 是            | 继续 L3 调用      | 继续 L3 调用 (不变) |
```

### D4 · L-068 4-dev.md 压缩策略

**问题**: 4-dev.md 781 行，per-task reload 占 pipeline 总成本 ~40%。目标 ≤500 行。

**备选**:
- (a) 抽取段落为 reference/ 片段，4-dev.md 用 `@see` 引用
- (b) 整体重写 4-dev.md（高风险）
- (c) 仅删冗余（低效果，预计 -10%）

**选 (a)**。理由：与 ADR-018 GO.md 压缩同套路，已验证可行。

**抽取目标**（3 个新 reference 文件）:
- `reference/tdd-workflow.md`（约 120 行）: 4-dev.md `### 1.4`-`### 1.7`（TDD 红绿循环 + grep-before-code + 1.8 破坏性变更协议 + 1.8 恢复验证）
- `reference/commit-protocol.md`（约 90 行）: 4-dev.md `### 5.`（5 段提交协议 + 5-submit + commit message 格式）
- `reference/checkpoint-protocol.md`（约 45 行）: 4-dev.md `## 中途断点`（行 716-747：入场恢复 + 中途暂停 + 任务完成后 PROGRESS 清理）+ `### 1.0` 行 232-236 关键节点 checkpoint 摘要

> **R3 修正**: 原设计误标 "§ 8" 抽取源。4-dev.md 实际无 § 8，checkpoint 内容散落在 `## 中途断点`（h2）和 `### 1.0`（h3）。已在 INDEPENDENT-REVIEW-2 主 agent 响应中确认。

**4-dev.md 保留段**（约 240 行，基于 R3 修正后实际可抽取量重估）:
- 入场路由（约 30 行）
- task-brief 调用（约 15 行）
- model-tier 解析（约 25 行）
- task_progress 写入（约 20 行）
- `### 1.4`-`### 1.8` 单行 trigger（约 10 行，每个配 `@see reference/tdd-workflow.md`）
- `### 5.` 单行 trigger + commit 极简模板（约 15 行）
- `### 6.` task 完成提交（约 30 行）
- `## 中途断点` 单行 trigger（约 5 行）
- `### 7.1` + `### 7.2`（约 50 行，task_progress + Hook 兼容性，与 checkpoint 紧耦合，保留）
- phase 4 自检 + pipeline toll-gate（约 40 行）

**预期总行数**: ~240 + 几个 `@see` 行 ≈ 250 行（远低于 ≤500 目标，留缓冲）。

**grep anchors 保留**（与 AC-E2 一致 · R4 修正后层级）: 所有既有 `### 1.4` / `### 5.` / `### 6.` / `## 中途断点` 标题**保持原 h3/h2 层级不变**（仅段内容改为简短 trigger + `@see`），AC-E2 8 个 anchor 全过（已修 anchor 正则为实际层级）。

**代价**:
- 3 个新文件创建（reference/）
- 4-dev.md 大改（保结构 / 换内容）
- 既有 grep 测试需检查（确认 anchor 仍命中）

**向后兼容**: 既有用户读 4-dev.md 时仍能看到段标题（带 @see 跳转），不破坏既有习惯。每个 `@see` 行下加 "⚠️ 必须读取该文件，不可跳过" 提示弱模型（R9 缓解建议）。

### D5 · bats 测试新增策略

**问题**: 5 个 fix 各需配套测试。

**新增 5 个测试文件**:
- `test/test_scripts_security.bats` 扩展: SEC-5b unsuppress（L-071）+ 新增 SEC-7 ref injection 边界
- `test/test_package_validate.bats`（新）: AC-B1 + AC-C1 + AC-C2
- `test/test_l2_first_correction.bats` 扩展: AC-I(d) + AC-I(e)（L-072）
- `test/test_4_dev_compress.bats`（新）: AC-E1 行数 + AC-E2 8 anchors + AC-E3 reference cross-ref
- `test/test_overall_regression.bats`（新）: AC-F1 + AC-F2 + AC-F4

**估算**: +8 新测试，1 unsuppress（SEC-5b），目标全量 665+/665+ pass。

## § 2 · 数据流（仅 L-072 + L-068 关键流）

### L-072 correction file 数据流（重排后）

```
Stop hook 29 触发
  ↓
Gate 1: module_enabled → ✓
  ↓
Gate 2: flow-kit active → ✓
  ↓
[新顺序] D1: gate_config=both?
  ↓ yes
检查 ## L2 盲审 段存在?
  ↓ no
_write_l2_missing_correction()  → .flow-active.correction (type=l2-missing)
exit 0
  ↓ yes (L2 已完成)
[新位置] L3 model 配置检查 (原 line 59-64)
  ↓ empty
write_model_missing_correction L3 → .flow-active.correction (type=l3-model-missing)
exit 3
  ↓ configured
继续 L3 API 调用...
```

### L-068 4-dev.md 加载流（改造后）

```
4-dev phase 触发
  ↓
GO.md 路由到 prompts/4-dev.md (220 行)
  ↓
4-dev.md 入场读取（约 8KB，对比原 34KB - 76%）
  ↓
执行 task 时按需 @see 加载:
  - task TDD 阶段 → task-brief + @see reference/tdd-workflow.md (按需读)
  - task commit 阶段 → @see reference/commit-protocol.md (按需读)
  - checkpoint 触发 → @see reference/checkpoint-protocol.md (按需读)
  ↓
完成 → 写 T<N>-SUMMARY.md + 更新 task_progress
```

## § 3 · 状态机（仅 L-072）

### 29 hook correction file type 状态机

```
[初始] correction 文件不存在
  ↓
触发条件: phase N stop hook 29 执行
  ↓
判断 gate_config[N] ∈ {both, L2}
  ├─ no → 不写 correction（N/A）
  └─ yes ↓
       判断 ## L2 盲审 段存在?
       ├─ no → 写 type=l2-missing (终态)
       └─ yes ↓
            判断 L3 model 配置?
            ├─ no → 写 type=l3-model-missing (终态)
            └─ yes ↓
                 判断 L3 API 调用成功?
                 ├─ no → 写 type=l3-error (终态)
                 └─ yes → 不写 correction（success）
```

## § 4 · ADR 索引

本 change 不引入新 ADR（沿用既有）:
- ADR-009 (L2-first ordering contract) — L-072 实现 ADR-009 的完整化（修复既有 bug）
- ADR-017 (severity gating) — L-071 实现沿用
- ADR-018 (GO.md bootstrap compression) — L-068 沿用同套路

## § 5 · 风险

### R1 · L-072 hook 重排触发既有未发现边界

**类型**: 实现风险 · **概率**: LOW · **影响**: MEDIUM
- 29 hook 有多个 gate 顺序依赖（Gate1→Gate2→...→Gate7），重排可能触发未发现的路径
- **缓解**: 全量回归既有 AC-I(a)(b)(c) + 新增 AC-I(d)(e) 覆盖 4 场景矩阵

### R2 · L-068 reference 片段抽取后弱模型跳读

**类型**: 平台风险 · **概率**: MEDIUM · **影响**: HIGH
- 弱模型可能只读 4-dev.md 不跟进 @see 加载 reference 片段，导致漏关键步骤（如破坏性变更协议）
- **缓解**: 4-dev.md 入场段保留"关键操作硬约束"摘要（1-2 行），@see 是详细步骤的扩展

### R3 · ~~L-070 validate exit code 改动破坏既有 CI 假设~~（移出范围 · 已确认非 bug）

~~**类型**: 启动风险 · **概率**: LOW · **影响**: LOW~~
~~- 现无 CI（仅本地 Makefile），但若用户脚本假设 validate 总 exit 0，会破坏~~
~~- **缓解**: CHANGELOG 标注 "BREAKING: --validate now exits 1 on missing files"~~

**L-070 已确认非 bug**（INDEPENDENT-REVIEW-2 R1）。`validate_staging_coverage()` 早已正确 `exit 1` 当 ERRORS > 0。R3 失效。LESSONS.md L-070 标注为 "已验证非 bug"。

### R4 · L-069 M-health.md 放错 Part

**类型**: 长期风险 · **概率**: LOW · **影响**: LOW
- 若 Part B（prompts）和 Part F（health 目录）边界判断错，validate 仍可能报漏
- **缓解**: DESIGN 已选 Part B（M-health.md 实际位置 = prompts/），unit test AC-B1 验证

### R5 · AC-F4 git log 验证依赖 commit message

**类型**: 长期风险 · **概率**: MEDIUM · **影响**: LOW
- AC-F4 用 `git log --grep` 验证 change-id，要求所有 commit message 含 change-id
- **缓解**: TASK.md 中显式要求 commit message 格式 `<type>: <desc> [cleanup-debt-batch-2026-08]`

### R6 · gate_config=all 降级 L2

**类型**: 平台风险 · **概率**: HIGH · **影响**: LOW
- OpenCode 无 ANTHROPIC API，L3 不可用，已在 phase 1 触发降级
- **缓解**: 已降级为 L2-only（gate_config 全 6 phase = L2），与 superpowers-v6-absorb 同处理

## § 6 · 范围外

- 不改其他 hook 模块（仅 29）
- 不改 GO.md（已在 superpowers-v6-absorb 压缩）
- 不改 brooks-lint
- 不引入新 ADR
- 不改 gate_config schema
- 不修 L-058/060/062（archived lessons）
- 不修 L-063/066（需 live data）

## § 7 · AC-E1 兼容性确认

L-068 抽取后 4-dev.md 既不破坏 superpowers-v6-absorb 已有的 task-brief/model-tier/task_progress 调用，也不破坏 1.8 破坏性变更协议（移到 reference/tdd-workflow.md）。所有 AC-E1/E2/E3 测试可在 phase 4 实施后跑过。

## § 9 · 架构沉淀建议

### 新可复用抽象（4 个）

| 抽象 | 路径 | 用途 |
|---|---|---|
| `reference/tdd-workflow.md` | flow-kit-bundle/flow-kit/reference/ | TDD 协议共享片段，可被其他 prompt @see |
| `reference/commit-protocol.md` | flow-kit-bundle/flow-kit/reference/ | 提交协议共享片段 |
| `reference/checkpoint-protocol.md` | flow-kit-bundle/flow-kit/reference/ | checkpoint 协议共享片段 |
| `git rev-parse --verify` ref validation 模式 | review-package | 可被其他需要 ref 输入的脚本复用 |

### 项目级决策（5 项）

- 29 hook 内部段顺序调整属于"逻辑顺序调整"非"接口变更"，禁动清单允许
- 4-dev.md 抽取 reference 片段继承 ADR-018 GO.md 压缩模式
- M-health.md 属于 phase prompts（Part B）而非 health 目录（Part F）
- ~~validate_staging_coverage() 必须返回非零 exit code 当 error count > 0~~ — **已确认非 bug**，函数早已正确 exit 1
- AC-F4 meta-AC（git log 验证 change-id）模式可复用于未来批量 change

### 跨模块契约（4 项）

- review-package ref validation 失败时 stderr 输出格式: `fatal: bad revision '<ref>'`
- 29 hook L2-missing 优先于 L3-model-missing（D3 矩阵）
- 4-dev.md 段标题保留 grep anchor，内容可压缩为 @see
- validate 函数所有路径必须显式 exit 0 或 exit 1（不依赖隐式 rc）

### 新依赖（0）

无新外部依赖。

### 新禁动清单条目（4 项）

- `review-package` ref validation 段（L20-25 附近的 `git rev-parse --verify`）— 安全关键
- `29-independent-review.sh` L2 detection 段位置（必须在 L3 model check 之前）
- `4-dev.md` grep anchors（8 个）— 既有测试依赖
- ~~`package-flow-kit.sh::validate_staging_coverage()` exit code 语义（error → exit 1）~~ — 既有代码已正确，无变更

---

> Phase 2 自检: ✅ 5 决策 D1-D5 · ✅ 数据流 + 状态机 · ✅ 6 风险 · ✅ 范围外 · ✅ 5 沉淀建议 · ✅ AC-E1 兼容性 · ✅ 0 新 ADR
