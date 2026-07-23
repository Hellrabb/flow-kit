# DESIGN — L2/L3 模型配置解耦（跨平台兼容）

> **路径约定**：源码树在 `flow-kit-bundle/` 下。本文件所有路径相对项目根（如 `flow-kit-bundle/hooks/stop/lib/common.sh`）。
> **阶段**：Phase 2 修订版（基于 REQUIREMENT.md「DESIGN.md 待修订点」+ 0.5 既有架构对齐 grep 查证）。

---

## §0 · 动机

**现状问题**：L2/L3 独立审查的模型选择硬依赖 Claude Code 专属环境变量：

- L3：`${ANTHROPIC_DEFAULT_HAIKU_MODEL:?}` — 变量未设时脚本直接终止（`l3-review.sh:623` / `29-independent-review.sh:59`，已 grep 确认）
- L2：`${ANTHROPIC_L2_MODEL:-claude-sonnet-5}` — 有 fallback，但 fallback 值在非 CC 平台不存在（`l2-detect.sh:215`，已 grep 确认）

**影响范围**：OpenCode、Codex CLI、Gemini CLI 等非 Claude Code 平台上，L2/L3 审查完全不可用。

**目标**：将模型配置从 Claude Code 环境变量解耦为三级优先级链，提供跨平台一致的配置方式；全部未配置时优雅降级（不崩溃、不阻塞 session）。

---

## §0.5 · 既有架构对齐（brownfield · 基于 grep 查证）

### 触碰的既有模块（全部已 grep/find 验证存在）

| 模块 | 现状 | 本次动作 |
|------|------|---------|
| `flow-kit-bundle/hooks/stop/lib/common.sh` | 既有 6 个 `fk_*` 函数（fk_resolve_phase 等）+ `jq_atomic_write`（:159） | **新增** `fk_resolve_model`（不冲突） |
| `flow-kit-bundle/hooks/stop/lib/l3-review.sh:623` | `${ANTHROPIC_DEFAULT_HAIKU_MODEL:?...}` | 替换 → `fk_resolve_model "L3"` + 降级 |
| `flow-kit-bundle/hooks/stop/lib/l2-detect.sh:215` | `${ANTHROPIC_L2_MODEL:-claude-sonnet-5}` | 替换 → `fk_resolve_model "L2"` + 降级（**移除 fallback**） |
| `flow-kit-bundle/hooks/stop/29-independent-review.sh:59` | `${ANTHROPIC_DEFAULT_HAIKU_MODEL:?...}` | 替换 → `fk_resolve_model "L3"` + 降级 |
| `flow-kit-bundle/hooks/stop/lib/correction-file.sh` | 既有 correction 读写 helper（`correction_file_exists` 等） | **沿用**（model-missing 写入参照既有模式） |
| `flow-kit-bundle/hooks/stop/lib/weak-model-compliance.sh` | 既有 `write_compliance_correction`（merge-write violations） | 不改（参照其写入模式设计 model-missing） |
| `flow-kit-bundle/hooks/session-start/flow-kit-resume.sh:89-127` | 收割逻辑仅认 `type=compliance + violations[]`（:92-95），其它 type 当异常删除（:123-127） | **扩展**：新增 model-missing 收割分支 |
| `flow-kit-bundle/skills/flow/SKILL.md` | 既有 /flow skill（子命令全内联：start/stop/phase/goal/gate-config/checkpoint） | 加 `/flow model` **内联段**（对齐 gate-config 模式） |

**会新增**：
- `flow-kit-bundle/skills/flow-model/SKILL.md`（**不新建**——/flow model 内联到 flow/SKILL.md，对齐既有模式，L2 R2）
- `flow-kit-bundle/test/test_fk_resolve_model.bats`（新测试）
- 扩展 `flow-kit-bundle/test/test_flow_kit_resume.bats`（model-missing 收割）

**不应该触碰**：`package-flow-kit.sh` / `install.sh` / `flow-kit-bundle/hooks/stop/00-gate.sh` / 其它无关 hook。

### 既有 ADR 对齐（关键）

- **ADR-006（l3-model-env-first · Accepted 2026-07-17）**：既有决策「L3 完全由 `ANTHROPIC_DEFAULT_HAIKU_MODEL` 定义，移除固定 fallback，env 未设则 `:?` 报错」。本次 **supersede** 该 ADR：扩展为三级链（env → FLOW_KIT_* → .flow-active）+ 优雅降级（不报错，写 correction 提示）。ADR-006 状态将标记 `Superseded by ADR-012`。L2 部分为本次新增（ADR-006 仅管 L3）。
- ADR-001~005 / 007~011（`.specs/adr/` 文件）：无冲突。
- ⚠️ **两套 ADR 编号体系（L2 R3 查证）**：`.specs/adr/` 文件（001-011，ADR-006=l3-env-first）与 `ARCHITECTURE.md:132-214` 注册表（max=ADR-009，ADR-006=protect-the-weakest）**编号错位**（既有项目问题）。本 DESIGN「Supersedes ADR-006」**特指 `.specs/adr/006-l3-model-env-first.md`**（文件级），**非** ARCHITECTURE.md 的 ADR-006（protect-the-weakest，语义无关）。ADR-012/013 写入 `.specs/adr/`；ARCHITECTURE.md 注册表同步留待 A-evolve 阶段（不在本 change v1）。
- ⚠️ **编号修正**：原 DESIGN 误用 ADR-011（已被 `pipeline-goal-no-g1-autoadvance` 占用）→ 改用 **ADR-012**（L2/L3 解耦）+ **ADR-013**（correction 策略）。

### 沿用 vs 引入

| 能力 | 决策 | 理由 |
|------|------|------|
| correction 读写 | **沿用** `correction-file.sh` helper | 既有抽象，model-missing 复用读写路径 |
| correction 写入策略 | **沿用** `_write_l2_missing_correction` 覆盖写模式（:24） | 既有 l2-missing 已是覆盖写，model-missing 一致 |
| 原子写 `.flow-active` | **沿用** `jq_atomic_write`（common.sh:159） | 既有 helper |
| `/flow` 命令分发 | **沿用** skill-based 路由（无 `commands/` 目录，全走 SKILL.md → AI 解释执行 jq） | 既有模式，L3 确认无 dispatcher 脚本 |
| 模型解析 | **引入新函数** `fk_resolve_model` | 既有无此抽象（三级链是新逻辑） |
| model-missing correction type | **引入新 type** | 既有仅有 compliance / l2-missing |

---

## §1 · 模型解析优先级链

新增两个 env var + `.flow-active` 两个配置字段，按优先级逐级 fallback。**每级取到非空值即停**。

### L3 模型

```
1. ANTHROPIC_DEFAULT_HAIKU_MODEL   ← 已有，CC 用户不变（优先级 1）
2. FLOW_KIT_L3_MODEL               ← 新增 env var（临时覆盖）
3. .flow-active.goal.l3_model      ← 新增配置字段（持久化）
4. 空 → 优雅降级
```

### L2 模型

```
1. ANTHROPIC_L2_MODEL              ← 已有
2. FLOW_KIT_L2_MODEL               ← 新增 env var
3. .flow-active.goal.l2_model      ← 新增配置字段
4. 空 → 优雅降级（⚠️ 移除既有 claude-sonnet-5 fallback，见 §8）
```

> **产品决策（REQUIREMENT US-2 确认）**：L2 不保留 `claude-sonnet-5` 第 4 级 fallback。纯跨平台——非 CC 平台该值不存在，CC 用户未设 `ANTHROPIC_L2_MODEL` 时降级提示。

---

## §2 · 公共函数 `fk_resolve_model` + 数据流

### 函数签名（R3.1：仅签名 + 逻辑，非完整实现）

```
fk_resolve_model <layer>  →  stdout: 模型名（空字符串表示全未配置）
  layer ∈ {"L3", "L2"}
  逻辑：按 §1 链逐级取非空值即停；读 .flow-active
  容错：用 ${PROJECT_ROOT:-} 防 set -u 未设崩溃；jq 读 .flow-active 失败 → 返回空（触发降级）
  纯查询函数：不写 correction、不发 API、return 0（即使返回空）
```

### 数据流图

```
 ┌─────────────────────────────────────────────────────────────┐
 │  caller: l3-review.sh / 29-independent-review.sh / l2-detect.sh │
 └──────────────────────┬──────────────────────────────────────┘
                        │ model=$(fk_resolve_model "L3"|"L2")
                        ▼
            ┌───────────────────────┐
            │  优先级链解析（§1）    │
            │  P1 env → P2 env      │
            │  → P3 .flow-active    │
            └───────────┬───────────┘
                        │
              ┌─────────┴─────────┐
              │                   │
        [ -n "$model" ]     [ -z "$model" ]
              │                   │
              ▼                   ▼
     ┌────────────────┐  ┌─────────────────────────┐
     │ 正常路径        │  │ 降级路径（caller 负责）   │
     │ _l3_call_api   │  │ ① 写 correction          │
     │ "$prompt"      │  │   (type=*-model-missing) │
     │ "$model"       │  │ ② stderr 配置提示        │
     │                │  │ ③ return（API 前·不发调用）│
     └────────────────┘  └─────────────────────────┘
                                  │
                                  ▼
                    ┌──────────────────────────┐
                    │ SessionStart resume.sh   │
                    │ 收割 model-missing type  │
                    │ → banner 配置提示（新）   │
                    └──────────────────────────┘
```

**关键边界**：`fk_resolve_model` 是纯查询函数（不 side-effect）；降级的 side-effect（写 correction / stderr / return）由 **caller** 负责。这保证函数可独立单元测试（source common.sh 即可，无 set -e 副作用）。

---

## §3 · 调用点改动

| 文件 | 当前 | 改为 |
|------|------|------|
| `l3-review.sh:623` | `local model="${ANTHROPIC_DEFAULT_HAIKU_MODEL:?...}"` | `local model; model=$(fk_resolve_model "L3")` + 降级检测 |
| `29-independent-review.sh:59` | `model="${ANTHROPIC_DEFAULT_HAIKU_MODEL:?...}"` | `model=$(fk_resolve_model "L3")` + 降级检测 |
| `l2-detect.sh:215` | `local model="${ANTHROPIC_L2_MODEL:-claude-sonnet-5}"` | `local model; model=$(fk_resolve_model "L2")` + 降级检测 |

### 降级检测（caller 侧，可观测后果 · 不依赖返回码）

> ⚠️ **不用 `return 3` 作降级信号**：`l3-review.sh` 已在 16 处用 `return 3` 为通用错误码（no artifact / HTTP 4xx·5xx / 校验失败，已 grep 确认 :326/356/372/383/492/498/566/603/616-619/660/666 等）。降级靠**可观测后果**区分：

```
# caller 伪代码（l3-review.sh / 29-independent-review.sh 降级段）
model=$(fk_resolve_model "L3")
if [[ -z "$model" ]]; then
  _write_model_missing_correction "L3"   # 写 .flow-active.correction（覆盖，见 §4）
  echo "[l3-review] L3 模型未配置。设置方式：export FLOW_KIT_L3_MODEL=... 或 /flow model l3=..." >&2
  return 3    # API 调用之前 return → 不发起 _l3_call_api（这是降级 vs 错误的关键区分）
fi
# 正常路径：content=$(_l3_call_api "$prompt_text" "$model") ...
```

**降级 vs 错误的区分**（AC-4 断言依据）：
- 降级：API 调用**之前** return + correction type=`*-model-missing`（独有标记）
- 错误：API 调用**之后** return 3 + 无 model-missing correction（HTTP 失败 / 无 artifact 等）

---

## §4 · 优雅降级 + correction 机制

### 4.1 correction 写入策略（产品决策：覆盖写 · 沿用 l2-missing 模式）

`.flow-active.correction` 是**单文件**，多 type 互相覆盖（既有 `_write_l2_missing_correction` 已是 `>` 覆盖写）。model-missing **沿用此模式**：

- 写入：`jq -n '{type:..., layer:..., message:...}' > .flow-active.correction`（覆盖）
- 语义：单文件单 type；**compliance 优先于 model-missing**（见下安全优先规则）——无 compliance 时最后写入者胜，compliance 在场时 model-missing 不覆盖
- **并发分析 + 安全优先规则（L2 R2）**：compliance（安全违规，每轮 Stop 写）与 model-missing（配置提示，L2/L3 降级写）可能并发。**非 CC 用户（本 change 目标受众）首启即降级，model-missing 持续**——若无条件覆盖会压住 compliance 安全 banner，构成对目标受众的安全可见性回归。
- **缓解（写入优先级：compliance > model-missing）**：model-missing 写入前检查当前 correction——若 type 为 `compliance` 且 `violations[]` 非空，**不覆盖**（保留安全信息）；compliance 写入**总是覆盖**（安全优先）。效果：非 CC 用户首启 model-missing → 检测到违规时 compliance 覆盖（安全可见）→ 用户配置模型后 model-missing 不再写、compliance 正常轮换。

### 4.2 model-missing correction schema

```
# L3 降级
{ "type": "l3-model-missing", "layer": "L3", "message": "L3 审查模型未配置。设置：export FLOW_KIT_L3_MODEL=<模型> 或 /flow model l3=<模型>" }

# L2 降级
{ "type": "l2-model-missing", "layer": "L2", "message": "L2 审查模型未配置。设置：export FLOW_KIT_L2_MODEL=<模型> 或 /flow model l2=<模型>" }
```

- **命名区分**（R4）：`l2-model-missing`（模型缺失）vs 既有 `l2-missing`（L2 盲审段缺失，`29-independent-review.sh:20`）—— 精确等值匹配，近形不混淆。
- **强制单一 lib 函数（L2 R2）**：`write_model_missing_correction <layer>`（新增到 `correction-file.sh`），内含 §4.1 compliance 优先检查。所有 caller（l3-review / l2-detect / 29-indep）**必须调用此函数**，禁止内联 jq -n（避免遗漏优先级检查 → 安全遮蔽回归）。配套 `write_model_missing_clear <layer>`（清除，见 §4.4）。

### 4.3 resume.sh 收割扩展 + `rm -f` 条件化（`flow-kit-resume.sh:89-128`）

**当前 bug（L2 R1 查证）**：`:127` 的 `rm -f "$compliance_correction_file"` 在内层 if/else（:95-126）**之外**——读完后**无条件删所有 type**（含自称「持久化」的 l2-missing，既有 bug）。DESIGN 必须重构为条件化删除，否则 AC-6「model-missing 持续提示」失败。

```
# resume.sh 重构伪代码（替换 :95-128）
if [[ "$corr_type" == "compliance" && "$corr_count" -gt 0 ]]; then
  # 既有：compliance banner（列 violations）
  rm -f "$file"           # compliance 读后清（一次性提示，既有语义）
elif [[ "$corr_type" == "l3-model-missing" ]]; then
  # 新：L3 配置 banner（grep message 含 FLOW_KIT_L3_MODEL）
  # 不 rm —— 持续提示直到用户配置模型
elif [[ "$corr_type" == "l2-model-missing" ]]; then
  # 新：L2 配置 banner
  # 不 rm —— 同上
elif [[ "$corr_type" == "l2-missing" ]]; then
  # 既有 l2-missing（L2 段缺失）—— 顺带修复其「持久化」声明：不 rm
  # 不 rm
else
  # 未知 type → 异常清除（既有）
  rm -f "$file"
fi
# ⚠️ 删除原 :127 的无条件 rm -f（已移入各分支）
```

**附带修复既有 bug**：l2-missing（`29-independent-review.sh:20` 自称「持久化记录」）此前被 :127 无条件删除，本次重构使其真正持久化（与注释声明一致）。

### 4.4 model-missing correction 清除时机（AC-6 退场 · L2 R1）

§4.3 只设计「写入 + 不删」（AC-6 入场）。**退场**（用户配置模型后清除，否则 banner 永久残留过时提示）：caller 正常路径（`fk_resolve_model` 返回非空）调用 `write_model_missing_clear <layer>`（§4.2 lib 函数）。

```
model=$(fk_resolve_model "L3")
if [[ -z "$model" ]]; then
  write_model_missing_correction "L3"   # 写入（降级·入场）
  echo "..." >&2; return 3
fi
write_model_missing_clear "L3"          # 清除（正常路径·退场·用户刚配置模型）
content=$(_l3_call_api "$prompt_text" "$model")
```

入场（§4.3 降级时写 + 不删持续提示）与退场（本节正常路径清）成对，构成 AC-6 完整生命周期。

---

## §5 · `/flow model` 配置命令

### 用法（DESIGN §5 全语法，已被 REQUIREMENT AC-5/5b/5c/5d 覆盖）

```
/flow model                    → 显示当前 L2/L3 模型配置（AC-5d）
/flow model l2=<model>         → 设置 L2 模型（AC-5）
/flow model l3=<model>         → 设置 L3 模型（AC-5）
/flow model l2=<m> l3=<m>      → 同时设置（AC-5b）
/flow model --clear l2         → 清除 L2 配置（AC-5c）
/flow model --clear l3         → 清除 L3 配置（AC-5c）
```

### 实现

- **内联 flow/SKILL.md（L2 R2）**：既有 /flow 子命令全内联 flow/SKILL.md（无独立子 skill）。/flow model 内联段指导 AI 读参数 → jq 读写 `.flow-active.goal.l2_model` / `l3_model`
- **无 dispatcher 脚本**：项目无 `commands/` 目录（已 find 确认），`/flow` 全走 SKILL.md（AI 解释执行），与既有 `/flow goal` / `/flow gate-config` 一致
- 原子写：jq `--arg` + `jq_atomic_write`（防注入 + 原子性）
- **`.goal` 字段边界（L2 R7 登记）**：`/flow model` 仅写 `.goal.l2_model` / `.goal.l3_model`（新增可选字段），**不触碰** `.goal.condition` / `gates` / `gate_config` / `phases_done` 等 `/flow goal` 管理的字段。两命令管不同子字段，无冲突——非绕过 `/flow goal`，而是平行的新配置维度。
- **跨平台说明**：`/flow model` 依赖 agent 平台 skill 路由（CC 增值）；非 CC 平台用 `FLOW_KIT_*` env var 或 jq 直写 `.flow-active`（US-1 跨平台核心不依赖此 skill）

### Skill 内联（非独立子 skill · L2 R2）

在 `flow-kit-bundle/skills/flow/SKILL.md`「## 子命令」加 `### /flow model` **内联段**（对齐既有 gate-config / goal / checkpoint 内联模式——既有 /flow 子命令全部内联此文件，无独立子 skill 路由，L2 R2 查证）。含显示 / 设置 / 合并 / --clear 全语法。**不新建 `flow-model/SKILL.md`**。

---

## §6 · `.flow-active` schema 扩展

新增两个可选字段：

```json
{
  "goal": {
    "l2_model": "deepseek-v4-pro",    // 新增 · 可选 · L2 审查模型
    "l3_model": "deepseek-v4-flash"   // 新增 · 可选 · L3 审查模型
  }
}
```

- 均可选——未设时走 env var / 降级
- 值域不校验（模型名由用户/供应商决定，flow-kit 不维护白名单）
- 向后兼容——不影响 gate_config / phases_done 等既有字段消费者

---

## §7 · 文件改动清单（订正路径前缀）

| 文件 | 改动 | 行数估计 |
|------|------|---------|
| `flow-kit-bundle/hooks/stop/lib/common.sh` | 新增 `fk_resolve_model` | +25 |
| `flow-kit-bundle/hooks/stop/lib/l3-review.sh` | :623 替换 `:?` → `fk_resolve_model` + 降级 | ~6 改 |
| `flow-kit-bundle/hooks/stop/lib/l2-detect.sh` | :215 替换 fallback → `fk_resolve_model` + 降级 | ~6 改 |
| `flow-kit-bundle/hooks/stop/29-independent-review.sh` | :59 替换 `:?` → `fk_resolve_model` + 降级 | ~4 改 |
| `flow-kit-bundle/hooks/session-start/flow-kit-resume.sh` | :89-127 扩展收割（+2 分支 model-missing） | +15 |
| `flow-kit-bundle/skills/flow/SKILL.md` | 加 `/flow model` **内联段**（对齐 gate-config，含 --clear/合并/显示） | +30 |
| `flow-kit-bundle/test/test_fk_resolve_model.bats` | 新增（AC-1/AC-3 全链 5 场景 × L2/L3） | +80 |
| `flow-kit-bundle/test/test_flow_kit_resume.bats` | 扩展（AC-6 model-missing 收割） | +20 |

总计约 **190 行净增**（含测试；/flow model 内联 flow/SKILL.md 而非独立 skill，省 ~20 行）。

---

## §8 · 兼容性（订正：CC 用户 L2 行为有变化）

| 场景 | 行为 |
|------|------|
| CC 用户设了 `ANTHROPIC_DEFAULT_HAIKU_MODEL`（L3） | 完全不变，优先级 1 命中 |
| CC 用户设了 `ANTHROPIC_L2_MODEL`（L2） | 完全不变，优先级 1 命中 |
| ⚠️ CC 用户**未设** `ANTHROPIC_L2_MODEL` | **行为变化**：当前 fallback 到 `claude-sonnet-5`，升级后降级提示（需显式配置）。这是有意的兼容性权衡（纯跨平台） |
| 第三方 API 用户在 `.flow-active` 配了模型 | 优先级 3 命中，一次配置持续生效 |
| 临时切换供应商 | `export FLOW_KIT_L3_MODEL=...` 覆盖，优先级 2 |
| 全未配置 | 优雅降级，输出配置提示，不阻塞 session |

> **原 DESIGN §8 错误已订正**：原声称「CC 用户完全不变」与 L2 fallback 移除矛盾。本次显式标注 L2 行为变化。

---

## §8.5 · 风险

### R1 · 实现风险：PROJECT_ROOT 依赖链
- **风险**：`fk_resolve_model` 读 `.flow-active` 依赖 `PROJECT_ROOT`。若某 caller 未设该变量，jq 读路径失败。
- **缓解**：`common.sh` 已在 `hook_init` 设 `PROJECT_ROOT`（既有约定）；函数内对 jq 失败容错（`2>/dev/null || echo ""` → 返回空 → 触发降级而非崩溃）。新增 bats 用例覆盖 `PROJECT_ROOT` 未设场景。

### R2 · 上线风险：L2 fallback 移除影响存量 CC 用户
- **风险**：未设 `ANTHROPIC_L2_MODEL` 的 CC 用户升级后 L2 审查从「用 claude-sonnet-5」变为降级，可能感知为回归。
- **缓解**：CHANGELOG / RELEASE 显式标注此行为变化；`.flow-active.correction` banner 引导配置；`install.sh` 升级提示列入 v2；降级不阻塞 session（仅提示），用户配置后立即恢复。

### R3 · 长期债务：correction 单文件 + compliance 优先规则
- **风险**：compliance 与 model-missing 并发覆盖。已由 §4.1 **compliance > model-missing 优先规则**缓解（model-missing 不覆盖在场 compliance）。
- **残留债务**：优先规则靠 `write_model_missing_correction` lib 函数（§4.2 强制）保证；若未来 caller 绕过 lib 内联写，可能回归安全遮蔽。缓解：code review 检查 caller 不内联。彻底解决（多 type 容器）列入 v2。

### R4 · 实现正确性 + 测试风险：lib 函数强制（非可选）
- **风险**：`write_model_missing_correction` 若由 caller 内联（而非强制 lib），(a) 任一 caller 遗漏 compliance 优先检查 → 安全遮蔽回归（L2 R2）；(b) `29-independent-review.sh` 顶层 `set -euo pipefail`，集成测试 source 会触发 set -e 链式退出。
- **缓解（升级为强制·非可选）**：`write_model_missing_correction` / `write_model_missing_clear` 作为 `correction-file.sh` 单一 lib 函数，所有 caller 调用（§4.2）——同时解决正确性（集中 compliance 优先检查）与可测性（lib 可独立 source）。单元层仅 source `common.sh` + `correction-file.sh`（安全）。

---

## §9 · ADR

### ADR-012：L2/L3 模型配置三级链（Supersedes ADR-006）

- **状态**：已确认（REQUIREMENT US-2 决策：移除 L2 fallback）
- **Supersedes**：ADR-006（l3-model-env-first）—— ADR-006「L3 完全由 `ANTHROPIC_DEFAULT_HAIKU_MODEL` 定义，未设 `:?` 报错」扩展为三级链 + 优雅降级。L2 部分为新增（ADR-006 仅管 L3）
- **决策**：三级优先级链 `ANTHROPIC_*` → `FLOW_KIT_*` → `.flow-active` → 空降级
- **备选**：纯 env var（跨 session 不便）/ 纯配置文件（临时切换麻烦）/ API 探测（延迟+权限）
- **代价**：~210 行（含测试）+ `.flow-active` 加 2 可选字段 + L2 fallback 移除（CC 行为变化）+ L3 不再 `:?` 报错（改降级）
- **理由**：跨平台兼容 + 支持临时/持久化两种配置 + 降级不阻塞 session（ADR-006 的 `:?` 报错在非 CC 平台体验差）

### ADR-013：model-missing correction 覆盖写策略

- **状态**：已确认（Phase 2 决策）
- **决策**：model-missing correction 沿用 `_write_l2_missing_correction` 覆盖写模式（单文件单 type，最后写入者胜）
- **备选**：多 type 容器 merge（改既有 helper，复杂）/ 单独文件隔离（多一状态文件）
- **代价**：compliance 与 model-missing 并发时互相覆盖（最后状态优先）
- **理由**：与既有 l2-missing 一致 + 改动最小 + model-missing 持续状态会稳定覆盖

---

## §10 · 架构沉淀建议（为 A-evolve 准备）

### 10.1 新增可复用抽象

- **`fk_resolve_model <layer>`**（`common.sh`）：三级优先级链模型解析。复用场景：(1) 未来其它依赖外部模型的 hook（如跨模型 spot-check）；(2) 非 CC 平台任何需要「env var → 配置文件 → 默认」三级 fallback 的配置项可参照此模式。

### 10.2 项目级技术决策

- **配置解耦模式**：flow-kit hook 中所有「Claude Code 专属 env var 硬依赖」应逐步迁移为 `ANTHROPIC_*` → `FLOW_KIT_*` → `.flow-active` 三级链（本 change 奠定模式，ADR-012，supersede ADR-006）。

### 10.3 跨模块契约

- **`.flow-active.correction` type 扩充**：新增 `l3-model-missing` / `l2-model-missing` 两个 type，与既有 `compliance` / `l2-missing` 并列。resume.sh 收割需识别全部 4 种 type。

### 10.4 禁动清单

- `fk_resolve_model` 必须保持**纯查询**（不写 correction / 不发 API / return 0）。降级 side-effect 由 caller 负责。破坏此契约会让单元测试失效（source 即执行）。

---

> 本 DESIGN 经 REQUIREMENT 阶段 5 轮 L2 + 4 轮 L3 review 反馈修订。Phase 2 产物待 L2/L3 review。
