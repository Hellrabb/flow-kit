# DESIGN: 修复 pipeline 诊断发现的全部问题

- **Change ID**: pipeline-fallback-fix
- **关联**: `@.specs/pipeline-fallback-fix/REQUIREMENT.md`、`@.specs/pipeline-fallback-fix/DIAGNOSIS.md`、`@.specs/CONTEXT.md`
- **作者**: AI（Architect 角色）+ 人工 review

---

## 0. 技术栈选定

- **语言/运行时**: Bash（`set -euo pipefail`），与项目既有栈一致
- **测试**: bats-core 1.13.0（npx）
- **关键依赖**: `jq`（JSON 操作）、`curl`（L3 API 调用）、`date`（时间戳）
- **理由**: 项目为 Bash 脚本分发包仓库，CONTEXT.md 已锁定，无新栈引入

---

## 0.5 既有架构对齐（brownfield 必填）

### 0.5.1 本次 change 触碰的既有模块

```
维护源（flow-kit-bundle/，唯一维护源；~/.claude/hooks/ 为 install.sh 安装的运行时副本）：

修改：
- flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh（~8500 字节 · P0-1 P0-3 P0-2）
- flow-kit-bundle/hooks/stop/29-independent-review.sh（~10700 字节 · P0-1 lib 抽取）
- flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh（~22500 字节 · P2-1 P2-2）
- flow-kit-bundle/skills/flow/SKILL.md（/flow gate-config + /flow goal --gate-config 快照同步 · P0-2）
- flow-kit-bundle/flow-kit/prompts/4-dev.md（auto_advance/fallback 段 + GO.md 去重 · P1-3）
- flow-kit-bundle/flow-kit/GO.md（mode 路由分支 · P1-3）

新增：
- flow-kit-bundle/hooks/stop/lib/l3-review.sh（NEW · L3 API 调用共享 lib · P0-1）
- flow-kit-bundle/hooks/stop/31-auto-advance.sh（NEW · auto_advance hook 兜底 · P1-1）
- flow-kit-bundle/hooks/stop/32-fallback-guard.sh（NEW · fallback hook 兜底 · P1-2）

Stop hook 模块编号依赖（执行顺序 = 编号顺序）：
  # 29 (L3 fallback) → 31 (auto_advance) → 32 (fallback guard)
  # 31 依赖 29 确保 .done 已写入；32 依赖 31 确保 phase 已最终化

禁动清单（与本次有关但需谨慎）：
- flow-kit-bundle/hooks/stop/lib/common.sh（共享常量/函数，31/32 号模块会 source）
- flow-kit-bundle/install.sh（需在 install_hooks.sh 中注册 31/32 号模块）
- flow-kit-bundle/lib/install_hooks.sh（hook 模块注册清单需追加 31 32）

禁动清单（本次不改）：
- flow-kit-bundle/hooks/stop/27-interactive-ui-check.sh（与本次无关）
- flow-kit-bundle/hooks/stop/28-weak-model-compliance.sh（与本次无关）
- flow-kit-bundle/hooks/stop/30-ai-analyze.sh（与本次无关，仅确认编号不冲突）
- flow-kit-bundle/package-flow-kit.sh（打包脚本核心逻辑，不改）
```

### 0.5.2 既有抽象沿用对照表

| 本次需要 | 既有有没有？路径 | 决定 |
|---|---|---|
| L3 API 调用 | `29-independent-review.sh` 中内联实现 | **抽取**为共享 lib `l3-review.sh`（P0-1/AC-1c） |
| .done 真实性校验 | `flow-kit-artifacts.sh` `fk_validate_done_marker()` | **沿用**，内部补字段检查（P2-1 P2-2） |
| gate 方向检测 | `independent-review-gate.sh` `is_phase_write()` | **沿用**，扩展为三向判定（P0-3/AC-3/AC-3a/AC-3b） |
| transition jq 命令模式 | 各 prompt toll-gate 段中的 jq 模板 | **沿用**，31-auto-advance.sh 复用相同 jq 模式 |
| hook 模块注册 | `install_hooks.sh` | **沿用**，追加 31 32 到 HOOK_MODULE_NAMES |
| 快照一致性检查 | `independent-review-gate.sh` D8 ⑥ | **沿用**，修复源端同步后不再误拦 |
| 环境变量鉴权 | `$ANTHROPIC_AUTH_TOKEN` + `$ANTHROPIC_BASE_URL` | **沿用**（AC-1 安全性要求） |

### 0.5.3 沿用模式 vs 引入新模式

```
- 错误处理：**沿用** `set -euo pipefail` + exit code 语义（所有新 hook 模块）
- API 调用：**沿用** curl + jq 解析（l3-review.sh 从 29 号模块抽取）
- 状态检测：**沿用** jq 读取 .flow-active 字段（31/32 号模块）
- 超时处理：**引入新模式** timeout 命令 + 降级策略（L3 前置场景特有，既有无此模式）
- 方向检测：**扩展**既有 is_phase_write 从二向（改/未改）到三向（前进/回退/no-op）
```

---

## 1. 决策清单

### P0-1 (F1) · L3 前置到 PreToolUse hook

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D1 | L3 API 调用从 Stop hook 移到 PreToolUse hook transition 拦截点同步执行 | A. 仍在 Stop hook 但解耦 L3 依赖（DIAGNOSIS 建议"L3未完成只警告"） B. L3 后置到下一阶段入口 C. **L3 前置到 PreToolUse（选定）** | A 削弱 gate 为建议，违背 gate-integrity 初衷；B L3 发现问题时已进入下一阶段需回退；C 在 transition 前完成 L2+L3 闭环，不削弱 gate，改动最小（抽取现有代码为 lib） | PreToolUse hook 增加 5-15s API 延迟；需 30s 超时降级（AC-1a）；Stop hook 兜底保留（AC-1b） |
| D2 | L3 API 调用逻辑抽取为共享 lib `l3-review.sh` | A. 复制粘贴到两处 B. 只在 PreToolUse hook 中实现，删 Stop hook L3 C. **抽取共享 lib（选定）** | A 导致代码重复，未来维护两处；B 丢失 Stop hook 兜底（session 异常终止时补跑 L3）；C 消除重复 + 保留兜底 | 需定义 lib 的公共函数签名（`l3_review_run()`），两处调用方 source 同一文件 |

**l3-review.sh 函数签名设计**：
```bash
# 主函数：执行 L3 外部模型审查 + 写入完整 .done 文件
# 参数: $1 = phase number (1-7)
#       $2 = change_id
#       $3 = artifacts_dir (.specs/<id>/)
#       $4 = L2_verdict (pass|fail, 从 INDEPENDENT-REVIEW-<N>.md L2 段解析)
# 行为: 
#   1. 调用外部模型 API 执行 L3 审查
#   2. L3 结果写入 INDEPENDENT-REVIEW-<N>.md 的 L3 段
#   3. 写入完整 6 键 .independent-review-<N>.done 文件
#      (phase/change_id/written_by/L2_verdict/L3_verdict/artifacts)
#   注: 握手文件即 .done 文件（与 AC-1/AC-7 统一），不引入额外握手文件
# 返回: 0 = pass, 1 = fail, 2 = timeout, 3 = API error
l3_review_run() { ... }

# 超时 + 降级 wrapper
l3_review_with_timeout() { ... }
```

**职责分配**：
- `l3_review_run()`: 负责 L3 API 调用 + 写入 `.done` 文件（含 `L2_verdict` 参数，确保 6 键完整）
- 调用方 `independent-review-gate.sh`: 负责从 `INDEPENDENT-REVIEW-<N>.md` 的 L2 段解析 verdict → 传入 `l3_review_run()` 的 `$4`；负责判定 gate 方向（前进/回退/no-op）
- Stop hook `29-independent-review.sh`: 兜底调用 `l3_review_run()`，与 PreToolUse 共享同一函数

**调用链变化**：
```
[旧] L2完成 → transition被拦 → 等session结束 → Stop hook 29 → L3 → 下个session写.done → transition
[新] L2完成 → transition被拦 → PreToolUse hook → l3-review.sh → L3完成 → 放行transition
                                     └─超时→降级→放行
                              Stop hook 29 → 检测L3缺失→补跑（兜底，session异常终止时）
```

---

### P0-2 (F2) · gate_config 快照同步

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D3 | `/flow gate-config` 和 `/flow goal --gate-config` 同时更新 `.goal-snapshot.json` | A. hook D8 ⑥ 移除快照检查 B. skill 不写快照，改 hook 容忍不一致 C. **skill 写快照 + hook 继续检查（选定）** | A 丢失篡改检测能力；B hook 不知道"合法变更"vs"篡改"的区别；C 单一写入点原则 — skill 负责同步，hook 只做检测 | skill.md 的 jq 命令增加 snapshot 写入步骤（+3 行）；`/flow goal` pipeline 路径增加相同逻辑 |
| D4 | 快照写入时机：skill 写 `.flow-active` 后立即同步 `.goal-snapshot.json` | A. hook 检测到不一致时自动修复 B. **skill 主动同步（选定）** | A 引入"hook 修复数据"的副作用——hook 应只读不写业务数据；B 写入点单一，时序明确 | 需确保 skill 写入原子性（先写 flow-active → 再写 snapshot，中间失败时 snapshot 可能滞后——但 hook D8 检测的是"key 从 independent 变为 off/缺失"，新写入场景不会触发） |

---

### P0-3 (F3) · Gate 区分前进/回退

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D5 | `is_phase_write` 增加方向判定：目标 < 当前 → 回退放行；目标 > 当前 → 前进查 gate；目标 == 当前 → no-op 放行 | A. 只区分"是否改 phase"不区分方向 B. 回退和前进都要求 .done C. **三向区分（选定）** | A 无法解决 F3；B pipeline 卡住后无法后退恢复；C 回退是恢复操作不应拦，no-op 是状态维护不应拦 | 增加 ~15 行判定逻辑；需从 jq 命令中提取目标 phase 值（解析 `current_phase = \"N\"` 模式） |

**方向判定伪代码**：
```bash
is_phase_write() {
  local target_phase=$(echo "$command" | grep -oP 'current_phase\s*=\s*"\K[0-7]')
  local current_phase=$(jq -r '.goal.current_phase' .flow-active)
  if [[ -z "$target_phase" ]]; then
    return 0  # 非 phase-write 命令（不包含 current_phase 赋值），放行不干扰
  fi
  if [[ "$target_phase" < "$current_phase" ]]; then return 0; fi  # 回退放行
  if [[ "$target_phase" == "$current_phase" ]]; then return 0; fi # no-op放行
  # target > current: 前进，继续检查 gate
  ...
}
```

---

### P1-1 (F4) · auto_advance hook 兜底

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D6 | 新增 `31-auto-advance.sh` Stop hook 模块，检测 `auto_advance=true` + PCSC 全✅ + gate 合规 → 自动 transition | A. 在 PreToolUse hook 中检测 B. 在现有 prompt 中加 L3 证据链强制自检 C. **Stop hook 新模块（选定）** | A PreToolUse 触发时机不匹配；B 仍是 prompt 驱动，弱模型可跳过；C Stop hook 的"会话结束"语义 = 阶段完成自然时机。**关键约束**：transition 前必须检查 `.independent-review-<N>.done` 有效（调用 `fk_validate_done_marker()`），确保 gate 合规——这是防止弱模型跳 L2 后仍被 auto_advance 推进的兜底 | 仅覆盖"会话正常结束"场景；中途不结束 session 的 pipeline 不会被自动推进——已知限制，符合 AC-4b。29 号模块在 31 之前执行（编号 29 < 31），29 补写 .done 后 31 才执行 transition，编号顺序保证 gate 合规前提 |
| D7 | PCSC 判定方式：v1 硬编码每阶段产物清单 | A. 解析 transcript 中的 PCSC 表格 B. grep prompt 文件中的 PCSC 段 C. **硬编码清单（选定）** | A transcript 格式不稳定；B v2 计划做（REQUIREMENT v2范围）；C v1 最简单可靠，产物清单从各 prompt PCSC 段手工提取一次 | 如果 prompt PCSC 段变更，需同步更新 hook 中硬编码清单（v2 自动化解决） |

**硬编码产物清单（v1）**：
```bash
declare -A PHASE_PRODUCTS
PHASE_PRODUCTS[4]="SUMMARY.md"  # 每 task 一个 SUMMARY
PHASE_PRODUCTS[5]="TEST.md"
PHASE_PRODUCTS[6]="REVIEW.md"
PHASE_PRODUCTS[7]=".independent-review-7.done"  # 阶段 7 done 标志
# phase 0-3 无 auto_advance（人工决策密集，不自动推进）
```

---

### P1-2 (F5) · Fallback hook 兜底

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D8 | 新增 `32-fallback-guard.sh` Stop hook 模块，检测 `mode=fallback` + phase 7 PCSC 全✅ → 标记 `goal.status=done` | A. 在 GO.md 中加 fallback 推进逻辑 B. 在 4-dev.md 中加强自检指令 C. **Stop hook 新模块（选定）** | A GO.md 是路由层，不负责状态变更；B prompt 驱动不可靠；C Stop hook 层兜底确保终点 | 仅覆盖终点（phase 7），中间阶段推进仍依赖 GO.md prompt 路由（已知限制，见 REQUIREMENT 覆盖边界声明） |

---

### P1-3 · GO.md mode 路由

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D9 | GO.md 添加 `mode=fallback` 路由分支，4-dev.md fallback 迭代描述改为 `@see GO.md § fallback` | A. 保持 fallback 迭代逻辑仅在 4-dev.md B. 同时在 GO.md 和 4-dev.md 维护 C. **GO.md 为主 + 4-dev @see（选定）** | A 当前状态（F5 根因）；B 重复维护 drift 风险；C 单一源 + 引用，消除 drift | GO.md 增加 ~20 行 fallback 路由段，4-dev.md 删除 ~30 行重复描述改为 2 行引用 |

---

### P2-1 (F6) · AC-5a ↔ hook 字段同步

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D10 | `.done` 文件统一为 6 键：`phase/change_id/written_by/L2_verdict/L3_verdict/artifacts` | A. 保持 5 键（不加 artifacts） B. 移除 written_by 简化 C. **6 键统一（选定）** | A AC-5a 要求 artifacts；B written_by 是防跳过子进程的关键字段；C 同时满足 AC-5a 和安全性 | 旧版 .done（5 键，缺 artifacts）在 Tier1 被拒（需重新审查），Tier2 识别为"需更新" |
| D11 | `fk_validate_done_marker()` Tier1 补 `artifacts=` + `L2_verdict`/`L3_verdict` 存在性检查 | A. 仅在 Tier2 检查 B. **Tier1 补检查（选定）** | A 对非 transition 操作（如 commit）存在绕过窗口；B 补上后 Tier1 即能拦截伪造 .done | Tier1 增加 ~10 行字段检查代码 |

---

### P2-2 · Tier1 补 L2/L3_verdict 检查

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D12 | Tier1 增加 `L2_verdict` 和 `L3_verdict` 键存在性 + 值合法性检查 | A. 保持 Tier1 不查 verdict B. **补 verdict 存在性 + 枚举值检查（选定）** | A 3 行伪造 .done 即可通过 Tier1（DIAGNOSIS T04 发现）；B 提升 Tier1 门槛 | 增加 ~15 行校验逻辑；Tier1 不比对 INDEPENDENT-REVIEW.md 中实际内容（那是 Tier2 职责，AC-8a） |
| D13 | 独立审查为 **existence-gate**（verdict fail 不阻塞 transition） | A. verdict=fail 阻塞 transition B. verdict 仅记录不阻塞（选定） | gate-integrity v1 的目标是确保审查**真实发生**（反空/假/跳过 .done），不是确保审查**通过**。verdict=fail 由人工评估后决定是否重做/跳过。与 CONTEXT `[2026-07-01]` gate-integrity v1 范围一致 | v2 若需将 verdict 纳入 gate 条件，需新增 .done 语义版本号以区分新旧行为。若 L2 大面积 false-positive fail，用户需手动绕过 |

---

## 2. 数据流 / 架构图

### 2.1 L3 前置调用链（P0-1 · F1 修复）

```
  Phase N 完成, PCSC ✅
        │
        v
  agent 执行 transition jq ──→ PreToolUse hook: independent-review-gate.sh
        │                              │
        │                              ├─ is_phase_write? 目标 > 当前?
        │                              │   ├─ 否(回退/no-op) → 放行
        │                              │   └─ 是(前进) → 继续检查
        │                              │
        │                              ├─ D8 ⑥ snapshot 一致性检查 (gate_config vs .goal-snapshot.json)
        │                              │   └─ 不一致 → 拦截: "gate_config 可能被篡改"
        │                              ├─ gate_config["N-xxxx"] = "independent"?
        │                              │   └─ 否 → 放行
        │                              │
        │                              ├─ .independent-review-N.done 有效?
        │                              │   ├─ 是 → 放行
        │                              │   └─ 否 → 检查 L2
        │                              │
        │                              ├─ INDEPENDENT-REVIEW-N.md L2 段存在?
        │                              │   └─ 否 → 拦截: "L2未完成"
        │                              │
        │                              ├─ L2 完成, L3 未完成 → source l3-review.sh
        │                              │   └─ l3_review_run(N, change_id, artifacts_dir)
        │                              │       ├─ 成功 → 写 L3 段 + 握手
        │                              │       ├─ 超时 → L3_verdict=timeout
        │                              │       └─ API错误 → L3_verdict=error
        │                              │
        │                              └─ L3 完成 → 放行 transition jq
        │
        v
  jq 执行成功, current_phase → N+1
```

### 2.2 gate_config 快照同步（P0-2 · F2 修复）

```
  /flow gate-config 6-review=independent
        │
        v
  skill.md 执行:
    1. jq 更新 .flow-active.goal.gate_config["6-review"] = "independent"
    2. jq 同步 .specs/<id>/.goal-snapshot.json.gate_config["6-review"] = "independent"
    3. 更新 .goal-snapshot.json.created_at = now
        │
        v
  后续 PreToolUse hook D8 ⑥:
    比对 .flow-active.goal.gate_config vs .goal-snapshot.json.gate_config
    └─ 一致 → 放行 ✓
```

### 2.3 Gate 方向判定（P0-3 · F3 修复）

```
  Bash command: jq '.goal.current_phase = "N"' ...
        │
        v
  is_phase_write() 提取 target_phase
        │
        ├─ target < current → ROLLBACK → 放行（不查 .done）
        ├─ target == current → NO-OP → 放行（状态维护）
        └─ target > current → FORWARD → 继续 gate 检查
                                    ├─ gate_config 开启? → 查 .done
                                    └─ gate_config 未开启 → 放行
```

### 2.4 auto_advance/fallback hook 兜底（P1-1 P1-2 · F4 F5 修复）

```
  Session 结束
        │
        v
  Stop hook 链执行:
        │
        ├─ 31-auto-advance.sh:
        │   ├─ auto_advance=true?
        │   │   └─ 否 → 跳过
        │   ├─ current_phase in {4,5,6,7}?
        │   │   └─ 否 → 跳过
        │   ├─ PCSC 全✅? (硬编码清单比对)
        │   │   └─ 否 → 输出缺失清单
        │   ├─ gate_config 对本阶段开启?
        │   │   └─ 是 → 检查 .independent-review-<N>.done 有效 (fk_validate_done_marker)
        │   │       └─ 否 → 输出告警，不 transition
        │   └─ 是 (gate满足或未开启) → 执行 transition jq → current_phase=N+1
        │
        └─ 32-fallback-guard.sh:
            ├─ mode=fallback?
            │   └─ 否 → 跳过
            ├─ current_phase=7 + PCSC全✅?
            │   └─ 否 → 跳过
            └─ 是 → goal.status = "done"
```

---

## 3. 关键状态机

### 3.1 Gate 方向判定状态机

```
                   ┌─────────────┐
                   │ Bash jq 含   │
                   │ current_phase│
                   └──────┬──────┘
                          │
                    is_phase_write()
                          │
                   ┌──────┴──────┐
                   │  比较 target │
                   │  vs current  │
                   └──────┬──────┘
                          │
          ┌───────────────┼───────────────┐
          │               │               │
    target < current  target == current  target > current
          │               │               │
      ROLLBACK          NO-OP          FORWARD
          │               │               │
      放行(0)          放行(0)      gate_config开启?
          │               │          ├─ 否 → 放行(0)
          │               │          └─ 是 → 查.done
          │               │                  │
          │               │            .done有效?
          │               │            ├─ 是 → 放行(0)
          │               │            └─ 否 → L2完成?
          │               │                    ├─ 否 → 拦截(1)
          │               │                    └─ 是 → L3前置 → 放行(0)
```

---

## 4. ADR 索引

本 change 涉及 1 个不可逆架构决策，写入 ADR：

- **ADR-002 · L3 独立审查调用策略**：将 L3 外部模型 API 调用从 Stop hook（会话结束触发）前置到 PreToolUse hook（transition jq 拦截点），Stop hook 保留为兜底。详见 `.specs/adr/002-l3-frontloading.md`

其余决策（D3-D12）为增量修正（字段补全、方向判定、hook 兜底），不构成独立的不可逆架构决策，仅在 DESIGN.md § 1 记录。

---

## 5. 风险

| # | 风险 | 类型 | 影响 | 概率 | 缓解 |
|---|---|---|---|---|---|
| R1 | **L3 API 调用延迟导致用户感知 transition 变慢** | 实现风险 | PreToolUse hook 中同步调外部模型 API，transition jq 执行时间从 <100ms 增至 5-15s，用户可能以为卡死 | 中 | hook 输出进度提示（"⏳ L3 独立审查中（外部模型）..."）；30s 超时降级（AC-1a）；可考虑后续版本加 `--skip-l3` flag |
| R2 | **L3 API 不可用时大批量超时降级** | 上线风险 | 外部模型 API 长时间不可用 → 所有 L3 路由均超时 → 降级为 timeout → L3 形同虚设 | 低 | 降级后 `L3_verdict=timeout` 明确标注；Stop hook 兜底可在 API 恢复后补跑；后续 session 可手动重跑 L3 |
| R3 | **31/32 号模块编号被后续 change 占用** | 实现风险 | 若后续 change 在本次合并前也新增了 31/32 号模块，合并时编号冲突 | 低 | 安装时 `install_hooks.sh` 检测冲突并报错；冲突时重编号（但概率低——当前最高编号 30） |
| R4 | **硬编码 PCSC 产物清单与 prompt 漂移** | 长期债务 | 若后续 change 修改了某阶段 prompt 的 PCSC 段（增删产物），31-auto-advance.sh 中的硬编码清单不同步 | 中 | v2 计划自动化解析 prompt PCSC 段（REQUIREMENT v2范围）；v1 在 hook 文件顶部注释标注同步要求，列出所有参照路径：
```
# 此清单需与以下 prompt 的 PCSC 段保持同步：
#   flow-kit-bundle/flow-kit/prompts/4-dev.md  § "阶段完成自检" 表
#   flow-kit-bundle/flow-kit/prompts/5-test.md  § "阶段完成自检" 表
#   flow-kit-bundle/flow-kit/prompts/6-review.md § "阶段完成自检" 表
#   flow-kit-bundle/flow-kit/prompts/7-integration.md § "阶段完成自检" 表
```
| R5 | **PreToolUse hook 中 source lib 的性能开销** | 实现风险 | 每次 Bash 命令都触发 PreToolUse hook，但 L3 API 调用仅发生在 transition jq 时（占总调用 <1%），其他调用仅快速判定后放行 | 极低 | `is_phase_write` 在 source l3-review.sh 之前执行，非 transition 场景直接放行不加载 lib |

---

## 6. 不在范围

- **auto_advance 的 PCSC 自检自动化**（v2：hook 自己 grep prompt PCSC 段判断全 ✅，替代 v1 硬编码清单，见 REQUIREMENT v2 范围）
- **L3 timeout 策略按模型 tier 区分**（v2：fast model 15s / full model 30s）
- **27-interactive-ui-check.sh 迁移到统一矫正文件**（v2）
- **多阶段累积 L3 发现汇总拦截**（v2：跨阶段 L3 问题在 PR/commit 时做累积检查）
- **全阶段 fallback hook 推进**（v2：phase 4→5→6→7 各阶段自动推进，不限于终点）
- **Stop hook 模块编号冲突自动检测/重编号**（v2）
- **install_hooks.sh 注册 31/32 号模块**（本 change 需做——属于 4-dev 实现范围，但设计层面显式列出依赖关系）
- **package-flow-kit.sh 打包验证自动包含新 hook 模块**（本 change 需做——属于 4-dev 实现范围，Part H 需含 31/32 + l3-review.sh）

---

## 9. 架构沉淀建议

### 9.1 新增的可复用抽象

| 路径 | 能力 | 触发场景 | 复用建议 |
|---|---|---|---|
| `flow-kit-bundle/hooks/stop/lib/l3-review.sh` | L3 外部模型 API 调用（模型选择、prompt 构建、超时处理、结果解析） | 独立审查 gate 的 L3 阶段；Stop hook 兜底 L3 | PreToolUse hook 和 Stop hook 均可 source 此 lib；未来若增加新的 L3 触发点，直接调用 `l3_review_run()` |

### 9.2 新增 / 改变的项目级技术决策

| 决策 | 取值 | 影响范围 | 推翻代价 |
|---|---|---|---|
| L3 调用策略 | PreToolUse hook 为主路径，Stop hook 为兜底 | 所有开启独立审查 gate 的阶段 | 中 — 需同时改 `independent-review-gate.sh` 和 `29-independent-review.sh` |
| gate 方向判定 | 三向：回退放行 / no-op放行 / 前进查 gate | 所有 pipeline transition | 低 — 仅 `is_phase_write()` 一处实现 |
| gate_config 快照一致性 | skill 主动同步，hook 只检测不修复 | `/flow gate-config` + `/flow goal --gate-config` | 低 — 两处 skill 调用点 |

### 9.3 新增 / 修改的跨模块契约

```
- l3-review.sh 公共函数签名: l3_review_run(phase, change_id, artifacts_dir) → exit_code
- .done 文件格式升级为 6 键（新增 artifacts=），向下兼容旧 5 键（Tier2 识别为"需更新"）
- is_phase_write() 返回值语义扩展: 0=放行, 1=拦截（前进且 gate 未满足）, 2=跳过(非 phase write)
```

### 9.4 禁动清单变化

```
- 新增禁动: flow-kit-bundle/hooks/stop/lib/l3-review.sh — 不允许绕过直接调 curl API（必须走 l3_review_run 封装）
- 新增禁动: .independent-review-<N>.done 文件 — 仅 l3_review_run()（PreToolUse/Stop hook）有写权限（延续 D7 path-guard 语义，路径不变）
```

### 9.5 依赖变动

无新增外部依赖。l3-review.sh 使用既有 `curl` + `jq`。
