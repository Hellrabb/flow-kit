# DESIGN: 独立 review gate `.done` 作者性校验缺口修复

- **Change ID**: gate-done-authorship
- **关联**: `@.specs/gate-done-authorship/REQUIREMENT.md`、`@.specs/CONTEXT.md`、`@.specs/ARCHITECTURE.md`
- **作者**: AI（Architect 角色）+ 人工 review

---

## 0. 技术栈选定

> Bash 脚本项目（flow-kit 分发包仓库），无传统技术栈。CONTEXT.md 已锁定技术决策，跳过技术栈选型。

- **语言/运行时**: Bash（`set -euo pipefail`）
- **测试**: bats-core 1.13.0（`npx bats`）
- **静态分析**: shellcheck（error 级别，`-e SC1091`）
- **关键依赖**: jq（JSON 处理）、curl（L3 API 调用，本 change 不涉）
- **理由**: 项目既有栈，本 change 不引入新语言/框架/依赖
- **明确排除**: 无（纯 Bash 修复，无需选栈）

---

## 0.5 既有架构对齐（brownfield 必填 · 来自 2-design 步骤 0.5）

### 0.5.1 本次 change 触碰的既有模块

```
触碰模块（grep 出来的实际清单）：
- flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh（既有 · path-guard D7 + Gate 1/3/4/5/6/7）
- flow-kit-bundle/hooks/stop/lib/done-validation.sh（既有 · fk_validate_done_marker Tier 1/2）
- flow-kit-bundle/hooks/stop/29-independent-review.sh（既有 · L3 审查触发 + state_file 生命周期）
- flow-kit-bundle/hooks/stop/lib/l3-review.sh（既有 · _l3_write_done，不涉及握手写入修改）

新增模块：
- 无（纯修改既有 hook 模块）

禁动清单（与本次无关，AI 不许"顺手"碰）：
- flow-kit-bundle/hooks/stop/lib/l2-detect.sh（L2 检测/派发，不涉及）
- flow-kit-bundle/hooks/stop/lib/common.sh（fk_resolve_phase 等公共函数，不涉及）
- flow-kit-bundle/hooks/stop/lib/correction-file.sh（矫正文件管理，不涉及）
- flow-kit-bundle/hooks/stop/lib/fix-compliance.sh（实效性校验，不涉及）
- flow-kit-bundle/hooks/session-start/（SessionStart hook，不涉及）
- flow-kit-bundle/lib/（安装脚本 lib，不涉及）
- package-flow-kit.sh（打包脚本，不涉及）
```

### 0.5.2 既有抽象沿用对照表

| 本次需要 | 既有有没有？路径 | 决定 |
|---|---|---|
| path-guard 写保护机制 | `_gate_path_guard()` — `independent-review-gate.sh:176-199` | **沿用并扩展**：保护目标从握手文件改为 .done 文件，保留 Bash/Write/Edit matcher 机制 |
| .done 结构合法性校验 | `fk_validate_done_marker()` — `done-validation.sh:96` | **沿用**：Tier 1 元数据快校验保留（非空 + KVP + 值域）；Tier 2 T3 握手段删除 |
| L3 审查幂等检查 | state_file 读取 — `29-independent-review.sh:68-74` | **替换**：改用 `.done` 文件存在性判断（更简洁且不依赖握手文件） |
| gate_config 值读取 | `jq -r '.goal.gate_config[...]'` | **沿用**：新增 L2-only 例外判定需读 gate_config，沿用既有 jq 模式 |
| regex-in-variable 风格 | `local re='...'; [[ "$c" =~ $re ]]` | **沿用**：新增 `_is_dotdone_write()` 遵循此约定 |
| Fail-safe 模式 | fail-close（deny on error）— `done-validation.sh:94` | **沿用**：path-guard + done-validation 均 fail-close |

### 0.5.3 沿用模式 vs 引入新模式

```
- path-guard 写保护：**沿用** D7 path-guard 机制（PreToolUse matcher + Bash/Write/Edit 拦截）
  仅改变保护目标：.flow-active.independent-review（握手）→ .independent-review-*.done（作者性锚点）
- done 校验：**沿用** Tier 1 元数据快校验（非空 + KVP + 值域）
  删除 Tier 2 T3 握手校验——作者性前置到 path-guard（写入时拦截）
- L3 幂等：**改用** .done 文件存在性判断（替换 state_file 读取）
  理由：握手文件已废弃，.done 是唯一 anchor
- 命名约定：**沿用** `_is_*` 前缀（私有的布尔谓词函数）+ `_gate_*` 前缀（gate 检查步骤）
```

---

## 1. 决策清单

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D1 | **方案 A：彻底废弃握手，path-guard D7 扩展** | 方案 B：恢复握手写入 + 让 Tier 2 可达 | 握手写入已是死代码（无生产代码写 `written_by=stop-hook-29`），恢复需改 Gate 3 短路语义 + state_file 跨 session 生命周期管理，复杂度远高于方案 A。path-guard D7 已有 Bash/Write/Edit 三通道拦截机制，扩展保护目标即可 | exotic write 路径（perl -i / python -c）留 v2 加密签名；L2-only 例外需显式处理 |
| D2 | **作者性前置到 path-guard（写入时拦截），删除后置 T3** | 保留 T3 改为验 .done 作者性（不验握手） | 前置拦截更强：阻止 .done 被创建 → 不存在即 Gate 3 继续拦。后置校验仅检测已创建的 .done，不如前置 | 若 path-guard 被绕过（hook bug / 环境异常），无后置**作者性**兜底（Tier 1 元数据校验仍提供格式有效性基础防护，但不验证写入者身份）——缓解：fail-safe 规范要求 hook 错误 deny |
| D3 | **L2-only 例外：fail-open（gate_config 读取失败时放行）** | fail-close（读取失败拦截） | L2-only 模式用户的生产路径不应因配置读取问题死锁；path-guard 的安全目标是防 agent 绕过 L3（非 L2-only 场景） | gate_config 读取失败时 agent 可在 L2-only 场景写 .done（风险为零——L2-only 本就允许 agent 写）。**both/L3 模式读取失败 → 误放**：理论缺口，但端到端不可利用——transition 的 jq phase 写也需要 .flow-active 可读，agent 使 .flow-active 不可读后无法完成自身 transition（自废武功）；且 T5（symlink）/T6（改 hook 代码）威胁已 out-of-scope 同类（需文件系统级完整性校验） |
| D4 | **29 号 hook 幂等改用 .done 文件存在性** | 保留 state_file 读取（方案 B） | .done 是唯一 anchor（方案 A），存在即表示 L3 已完成；state_file 是握手专用，废弃后不存在 | 若 .done 被手动删除（非正常路径），可能重复触发 L3——但重跑 L3 是幂等的（追加 ## L3 重审 段） |
| D5 | **_is_dotdone_write() 覆盖同 is_handshake_write() 的写路径** | 从头设计新的写检测 | is_handshake_write 的写路径覆盖（redirect / tee / cp / mv / sed -i / heredoc 等）经过多轮 review（TD-015 / TD-011 / BUG-H），成熟可靠。仅需改文件名匹配模式 | .done 文件名含 phase 号（glob `*.independent-review-*.done`），匹配比握手文件名（精确 `.flow-active.independent-review`）稍复杂 |
| D6 | **不新增 ADR（本 change 属既有 ADR-005 的扩展）** | 新增 ADR-011（gate .done 作者性模型） | ADR-005（独立审查体系）的决策文本中引用 D7 path-guard 机制。D7 的实际定义在 `independent-review-gate.sh` 的 `_gate_path_guard()` 函数中。本 change 仅改变 D7 的保护目标（握手 → .done），不改变 D7 机制本身——属于 ADR-005 scope 内演进，不需要新 ADR | 若后续 path-guard 保护目标扩展到其他敏感文件（v2），届时可新增 ADR |

---

## 2. 数据流 / 架构图

### 2.1 修改前（握手时代 · 存在安全缺口）

```
agent 写 .done ──→ Gate 3（fk_independent_review_gate_active）
                    │  仅查 .done 存在性
                    │  .done 存在 → "未开启" → exit 0 放行  ❌
                    │
                    └──→ 永远到不了 Tier 2 T3 握手校验
                         （Gate 3 先短路放行了）

l3_review_run ──→ 写 state_file（握手 · 已废弃）
              ──→ _l3_write_done() 写 .done
              ──→ done-validation T3 验握手（测试层活着，生产不可达）

29-independent-review.sh:
  :68-74 读 state_file（幂等）    ← 死代码
  :203-204 rm state_file（清理）  ← 死代码
```

### 2.2 修改后（方案 A · 作者性前置）

```
┌─────────────────────────────────────────────────────────┐
│ PreToolUse hook（independent-review-gate.sh）            │
│                                                         │
│  agent 写 .independent-review-*.done                     │
│    │                                                    │
│    ├── Write/Edit tool ──→ file_path match *.done       │
│    │     ├── gate_config=L2 → 放行 ✅ (L2-only 例外)     │
│    │     └── 否则 → exit 2 deny ❌                       │
│    │                                                    │
│    └── Bash tool ──→ _is_dotdone_write(cmd)             │
│          ├── gate_config=L2 → 放行 ✅                    │
│          └── 否则 → exit 2 deny ❌                       │
│                                                         │
│  l3_review_run 写 .done（Stop hook 进程）                │
│    └── 不经过 PreToolUse → 天然放行 ✅                    │
│                                                         │
│  29-independent-review.sh:                               │
│    幂等检查改用 .done 存在性（不再读 state_file）         │
│    rm -f state_file 行删除                               │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ transition 时 done-validation（done-validation.sh）       │
│                                                         │
│  fk_validate_done_marker(done_path, phase, cid, tier)   │
│    │                                                    │
│    ├── phases_done 短路（历史 .done 放行）               │
│    ├── Tier 1 元数据快校验                               │
│    │   ├── 非空（挡 touch 空文件）                       │
│    │   ├── KVP: phase/change_id/written_by 存在          │
│    │   ├── L2_verdict/L3_verdict 值域校验                │
│    │   └── artifacts 非空 + 逗号分隔                     │
│    │                                                    │
│    └── Tier 2 transition 后置                           │
│        ├── ~~T3 握手校验~~（删）                         │
│        ├── ~~T3b SESSION_ID~~（删）                      │
│        └── T4 L2_verdict vs INDEPENDENT-REVIEW-N.md 比对 │
│             （保留 · L2-first gating 调度契约）           │
└─────────────────────────────────────────────────────────┘
```

### 2.3 .done KVP 格式说明

本 change 涉及的 `.done` 文件实际 8 键（与 ARCHITECTURE.md § 4.1 契约一致）：

```
phase=<N>
change_id=<id>
written_by=<review-subagent|l3-review-run|main-agent>
written_at=<ISO8601>
L2_verdict=pass|fail|skipped
L3_verdict=pass|fail|timeout|error|skipped
session_id=<uuid>
artifacts=<空格分隔路径列表>
```

> "6 键 KVP"术语为历史简称（指核心 6 键 phase/change_id/written_by/L2_verdict/L3_verdict/artifacts），不含元数据字段 `written_at`/`session_id`。本 change 不改此格式。

### 2.4 威胁模型覆盖

| # | 绕过路径 | 对策 | 覆盖 |
|---|---------|------|------|
| T1 | Bash/Write/Edit 直接写 .done | path-guard D7 拦截（`_is_dotdone_write` + Write/Edit matcher） | ✅ v1 |
| T2 | 子目录写后 mv 到目标 | path-guard 拦截 mv 目标匹配 `*.independent-review-*.done` | ✅ v1 |
| T3 | sed -i 原地修改 .done | path-guard 拦截 sed -i 目标匹配 | ✅ v1 |
| T4 | git checkout 恢复旧 .done | path-guard 不拦截 git checkout（非 Write/Edit/Bash 写操作） | ⚠️ out — 旧 .done 对应旧 session，phases_done 短路放行，非安全漏洞 |
| T5 | symlink 指向伪造 .done | done-validation 读 .done 内容验 KVP（symlink 目标内容不可控） | ⚠️ out — 需文件系统级完整性校验 |
| T6 | 修改 hook 代码关闭 path-guard | 超出本 change 范围（需代码完整性校验） | ⚠️ out |
| T7 | L2-only 模式下伪造 L3_verdict | done-validation Tier 1 验 L3_verdict=skipped（L2-only 模式下应为 skipped） | ✅ v1（Tier 1 值域校验） |

---

## 3. 关键状态机

无。本 change 不引入新状态机。path-guard D7 扩展是纯拦截逻辑（匹配 → deny/放行），不涉及状态流转。

---

## 4. ADR 索引

本 change 不新增 ADR。触及既有 ADR-005（独立审查体系）的 D7 path-guard 定义——将保护目标从 `.flow-active.independent-review`（握手文件）扩展为 `.independent-review-*.done`（.done 文件），不改变 D7 的 Bash/Write/Edit 三通道 matcher 机制。D7 的实际实现定义在 `independent-review-gate.sh` 的 `_gate_path_guard()` 函数中。

> 详见 ARCHITECTURE.md § 3 ADR-005。

---

## 5. 风险

| # | 风险 | 影响 | 概率 | 缓解 |
|---|---|---|---|---|
| R1 | **实现风险**：`_is_dotdone_write()` glob 匹配遗漏 exotic write 路径（perl -i / python -c） | agent 可绕过 path-guard 写 .done | 低 | glob 覆盖 is_handshake_write 已验证的 9 种写路径（含 dd of=）；exotic 路径留 v2 加密签名（CHANGE.md Scope 边界已声明） |
| R2 | **上线风险**：L2-only 模式 gate_config 读取失败导致误拦 | L2-only 用户 pipeline 死锁 | 低 | fail-open：gate_config 读取失败时放行（L2-only 本身就允许 agent 写 .done）。both/L3 模式读取失败 → 误放为理论缺口，但端到端不可利用（见 D3 取舍代价） |
| R3 | **上线风险**：L3 审查子进程（l3_review_run）写 .done 时文件名匹配被误拦 | pipeline 死锁 | 极低 | l3_review_run 在 Stop hook 进程内运行，不经过 PreToolUse——path-guard 天然不拦截。但需确认 install 后的 hook 接线不改变此假设 |
| R4 | **长期债务**：T3 删除后 Tier 2 transition 后置无独立作者性校验（仅前置 path-guard + Tier 1 格式校验） | path-guard 被绕过时无后置作者性兜底 | 低 | 前置拦截（写入时阻止）强于后置校验（读取时检测）。Tier 1 仍提供非空/KVP/值域格式校验。Fail-safe 规范确保 hook 错误 → deny。留 v2 考虑在 done-validation 加独立作者性校验（如验 `.done` 的 inode/mtime 与 hook 执行时间窗对齐） |
| R5 | **兼容性风险**：既有 .done 文件（由 l3_review_run 写入）的 `written_by` 值不统一（有 "stop-hook-29"、有 "l3-review-run"） | done-validation Tier 1 校验 broken | 极低 | Tier 1 仅检查 `written_by` 非空（`[[ -n "$k_wby" ]]`），不检查具体值——方案 A 不改此行为。.done 实际 8 键格式（含 written_at/session_id）见 § 2.3 |

---

## 6. 不在范围

- L2/L3 模型解析逻辑（那是 `l2-l3-model-config` 的 scope）
- gate_config 三值（L2/L3/both）语义修改
- `gate-review-fix` 的 13 条缺陷（独立 scope，可并行）
- `correction_file_write` 同款 fixed-tmp race 全 lib 一致性修复（v2）
- path-guard D7 扩展至其他敏感文件（如 `.flow-active` 字段写入保护，v2）
- exotic write 路径的加密签名防护（v2）
- Tier 2 新增独立作者性校验（如 inode/mtime 对齐，v2）
- 代码完整性校验（防 agent 修改 hook 代码关闭 path-guard，out of scope）

---

## 9. 架构沉淀建议（本 change 完成后供 `A-evolve` 同步用 · 软约束）

### 9.1 新增的可复用抽象

本 change 不新增 lib/ 级别抽象。`_is_dotdone_write()`（path-guard 内私有函数）属模块内部实现，无跨模块复用价值。

### 9.2 新增 / 改变的项目级技术决策

| 决策 | 取值 | 影响范围 | 推翻代价 |
|---|---|---|---|
| `.done` 作者性锚点 | path-guard D7 保护 `.independent-review-*.done`（替代握手 `state_file`） | 所有使用独立 review gate 的 change（1/2/3/5/6/7 阶段） | 低（回退到方案 B 恢复握手写入即可） |

### 9.3 新增 / 修改的跨模块契约

```
- path-guard D7 保护目标变更：.flow-active.independent-review → .independent-review-*.done
- done-validation T3 握手校验段删除（Tier 2 transition 后置不再依赖握手文件）
- 29-independent-review.sh 幂等检查：state_file 读取 → .done 文件存在性
```

### 9.4 新增 / 升级的依赖

无。

### 9.5 禁动清单变化

```
- 新增禁动：flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh 的 _is_dotdone_write() —
  后续 change 修改此函数须同步更新 test_gate_integrity.bats 的 path-guard 测试用例
- 解禁：无（is_handshake_write 删除后相关禁动条目自动失效）
```

---

> 本文件不包含完整代码实现。函数签名、伪代码、接口定义可以；函数体不行。
