# DESIGN: 加固 toll-gate 不可绕过性 + 扩展 L2 独立审查到 3/5/7

- **Change ID**: gate-integrity
- **关联**: `@.specs/gate-integrity/REQUIREMENT.md`、`@.specs/CONTEXT.md`、`@.specs/gate-integrity/adr/`
- **作者**: AI（Architect 角色）+ 人工 review + L2/L3 盲审（3 轮）
- **修订史**:
  - a · L3 fail：critical#1/2/3 两层时机 + #4 D3 三层解析
  - b · L2-R1 fail：R1 多源 + R2 D7 握手（初选 A）+ R3-R7
  - c · L2-R2 fail：D7「绝对挡」证伪 → B'（常见向量挡 + L70 L103 重定义）+ R1/R2/R3-R10
  - d · L2-R3 fail：R1 AC-1 Then 对齐 + R2 ⑥ 提到 v1 检测（G3）+ R3 fail-close + R4 §0.5.1 + R7 Bash 向量 + R9 phases_done 合法通路

---

## 0. 技术栈选定

- **选定**: Bash（项目原有栈，meta/distribution）
- **测试**: bats-core 1.13.0（基线实测 213）
- **关键依赖**: `jq` / `curl`（L3 API）/ `set -euo pipefail`
- **理由**: 改 flow-kit 自身 Bash hook/prompt，沿用既有栈

---

## 0.5 既有架构对齐（brownfield · grep 实证）

### 0.5.1 本次 change 触碰的既有模块

```
触碰（既有，grep 实证）：
- flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh（:109,138 / :147 / PHASE_ARTIFACTS:47 / case 镜像 :117-119）
- flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh（:27 tool_name 早退 / :39 正则 / :58-60 case / :64-77 is_phase_write · 扩 matcher + path-guard + is_phase_write 拦 phases_done）
- flow-kit-bundle/hooks/stop/29-independent-review.sh（:33 / :61 / :166-181 / state_file :48 · 独占写握手）
- flow-kit-bundle/hooks/stop/lib/common.sh（CONFIG_FILE ✓已改 :87-93）
- flow-kit-bundle/hooks/lib/install_hooks.sh（PreToolUse matcher :136,:153 硬编码 "Bash" · 扩 ["Bash","Write","Edit"]）
- flow-kit-bundle/scripts/check-gate-sync.sh（当前文本段 diff · 本 change 重写为 set-diff · L2-R3 R4）
- flow-kit-bundle/flow-kit/reference/pipeline-gates.md（53 行，仅 4-dev · 扩全链）
- flow-kit-bundle/flow-kit/prompts/{3-task,5-test,7-integration}.md + independent/L2-blind-review.md
- ~/.claude/skills/flow/SKILL.md（PRESET_MAP :132-150）+ bundle skill 镜像

新增：
- flow-kit-artifacts.sh::fk_validate_done_marker（两层时机）
- independent-review-gate.sh::is_handshake_write（Bash 写向量检测 · 非穷尽）
- independent-review-gate.sh::fk_check_gate_config_tamper（⑥ 检测 · L2-R3 R2）
- .specs/<id>/.goal-snapshot.json（goal 创建快照 · ⑥ 检测载体 · 入库 · L2-R3 R2）
- test/regression-demos/（empty/forged/hijack/tampered/gate-config-tamper/skipped-subprocess/exotic-escape）
- test/test_gate_integrity.bats
- .specs/gate-integrity/adr/{G1,G2,G3,G4}.md

禁动：
- package-flow-kit.sh / flow-kit-bundle.tar.gz / .gitignore
```

### 0.5.2 既有抽象沿用对照表

| 本次需要 | 既有有没有？ | 决定 |
|---|---|---|
| .done 真实性校验 | 无（independent-review-gate.sh:54 纯 `[ -f ]`） | 新建 `fk_validate_done_marker`（两层） |
| 阶段 → phase_name 映射 | case 1/2/6（两处镜像） | 两处镜像同步扩 3/5/7（D6） |
| gate_config 读取 | jq .flow-active | 沿用 |
| L3 API + 握手写入 | curl + jq（29 号） | 沿用 + 独占写握手（D7） |
| PreToolUse matcher | 仅 "Bash" | 扩 ["Bash","Write","Edit"]（D7） |
| gate_config 篡改检测 | 无 | 新建快照 diff（D8） |
| PRESET_MAP 双源同步检测 | check-gate-sync.sh 文本段 diff | 重写为 set-diff（D3 · R4） |

### 0.5.3 沿用模式 vs 引入新模式

```
- hook 校验逻辑：沿用 bash + jq
- .done 格式：引入 KVP（旧空 .done 是威胁①）
- gate 阶段判定：引入动态读 gate_config（替代硬编码正则）
- 校验时机：引入两层（Tier 1/2）
- 威胁③锚点：引入"hook 独占写 + 常见写向量拦"（D7 · B'）→ 单机无绝对锚点，v1 best-effort
- 威胁⑥检测：引入".specs 快照 diff"（D8）→ 廉价检测入 v1，强防留 v1.5
- fail 策略：path-guard fail-open / 校验 fail-close（R3/R11）
```

---

## 1. 决策清单

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D1 | .done 强制 KVP + phases_done 短路 | 兼容空 | 空 .done 是威胁① | 旧 change 不兼容（短路兜底） |
| D2 | 每次 jq 读 gate_config（不缓存） | 缓存 | PreToolUse 每次新进程；实测 ~2.4ms/次 | O(2.4ms)/次 |
| D3 | PRESET_MAP 三层解析 + check-gate-sync 重写 set-diff（R4） | Bash 解析 SKILL.md | ① /flow skill 解析写 gate_config；② hook 只读 gate_config；③ bats 镜像 + check-gate-sync.sh **重写**（source + `declare -p PRESET_MAP` 提取键集，set-diff） | 双源需 check-gate-sync 兜底（v1 必做重写） |
| D4 | verdict 字符串绑定（v1） | 加密哈希 | 加密需可信源（v2） | ⑤-L2 留 v2 |
| D5 | SESSION_ID 跨会话锚点（④）+ D7 常见写向量握手（③⑤-L3 常见）+ D8 ⑥检测 | 绝对挡（证伪）/ 多文件（弃） | 见 D7/D8 | ③ exotic + ⑤-L2 留 v2；⑥ 强防留 v1.5 |
| D6 | phase_name **多源镜像**（5 站点）同步扩 3/5/7 | 声称"单一源"（失实） | grep 实证 5 站点 | 5 站点漂移（bats 兜底）；AC-3 Then 已补全 5 站点 |
| D7 | 29 号独占写握手 + PreToolUse 常见写向量拦（B'） | 绝对挡（证伪）/ 加密（v2） | matcher 扩 Bash+Write+Edit；is_handshake_write 拦 Write/Edit tool + Bash 重定向/cp/mv/sed/tee/printf（**非穷尽**）；29 号 hook 子进程独占写 | **v1 非绝对挡**：exotic Bash（python-c/dd/变量间接/base64）逃逸留 v2（L70 已 L103 重定义） |
| D8 | **⑥ gate_config 篡改检测（v1 · L2-R3 R2）** | "不防⑥"（循环论证 · 弃）/ 加密强防（v1.5） | goal 创建时写 `.specs/<id>/.goal-snapshot.json`（**入库**，绕过 .gitignore）；transition hook diff `.flow-active.goal.gate_config` 与快照，phase key 由 independent→false/缺失 → deny exit 2。agent 改快照留 git 证据（可观测） | 仅检测非强防；agent 同时改 .flow-active + 快照且 commit 不留痕可绕（v1.5 加密） |
| D9 | **fail 策略区分（L2-R3 R3）** | 一律 fail-open（混淆） | path-guard（is_handshake_write）**fail-open**（拦不住不卡 agent 工具流）；校验（fk_validate_done_marker T1-T4 + ⑥检测）**fail-close**（jq 不可用/source 失败/解析异常 → exit 2 deny + 可读错误）。agent 不能让 hook 内部出错来放行 | fail-close 要求 hook lib 稳定，bats 覆盖畸形输入 |
| D10 | **phases_done 合法写入通路（L2-R3 R9）** | 主 agent 自写（绕过风险） | 只有 transition hook 子进程（与 29 号独占写握手同模式）能写 `.goal.phases_done`；agent 经 Bash/Write/Edit 写该字段一律 deny（is_phase_write 扩拦）。合法 phase 推进走 hook 子进程，与 D7 自洽 | 主 agent 不能直接 jq 推进 phases_done，必须经 transition hook |

---

## 2. 数据流 / 架构图（两层时机 + D7 握手 + D8 ⑥检测 + D10 phases_done 通路）

```
  agent 写 .done ─────► PreToolUse: independent-review-gate.sh（matcher: Bash+Write+Edit）
   is_done_write?(拦 .phase= / .goal.current_phase= / .goal.phases_done=)
        │  commit/PR/transition?
        v
   Tier1: phases_done 短路 → T1 非空 → T2 KVP          │
        │ 放行 Write                                    ▼
                                              Tier1+2 全量：
                                              T1→T2→T3 握手(D7)→T3b session(④)
                                              →T4 verdict(⑤-L2)→⑥ gate_config 检测(D8)
                                                  │
                                            全过→放行 / 任一失败→deny exit 2

   path-guard(D7): Write/Edit tool 或 Bash 重定向/cp/mv/sed/tee/printf → .flow-active.independent-review → deny
                   29 号 hook 子进程直写 → 放行
   fail 策略(D9): path-guard fail-open / 校验 fail-close
   phases_done(D10): 仅 transition hook 子进程能写 .goal.phases_done
```

## 3. 关键状态机（.done 校验 · 两层时机 · fail 策略区分）

`fk_validate_done_marker <path> <phase> <change_id> <tier>`，`<tier>`=`write`/`transition`。

### Tier 1 · Write Gate（元数据快校验）

1. **phases_done 短路**：phase ∈ `phases_done[]` → 有效
2. **T1 空（①）**：`[ -s ]` + 行数 > MIN
3. **T2 KVP（②）**：解析 `phase=/change_id=/written_by=` 匹配
4. 全过 → 放行 Write

### Tier 2 · Transition 后置（产物已齐）

5. **T3 D7 握手锚点（③ + ⑤-L3 常见路径）**：`.flow-active.independent-review` 握手存在 + `written_by=stop-hook-29` + `verdict` 与 `.done` `L3_verdict` 一致 + `phase` 匹配
6. **T3b SESSION_ID 跨会话锚点（④）**：`.done` `session_id` 与当前会话一致；跨 session 合法推进由 phases_done 短路兜底
7. **T4 verdict 绑定（⑤-L2）**：.done `L2_verdict` 与 .md L2 段 Verdict 行比对
8. **⑥ gate_config 篡改检测（D8）**：diff `.flow-active.goal.gate_config` 与 `.specs/<id>/.goal-snapshot.json`，phase key 由 independent→false/缺失 → 无效
9. 全过 → 有效；任一失败 → deny exit 2

**fail 策略（D9 · L2-R3 R3）**：Tier 1/2 校验 + ⑥检测 = **fail-close**（jq 不可用 / source 失败 / 解析异常 → exit 2 deny + 可读错误，agent 不能靠制造 hook 内部错误放行）；D7 path-guard = **fail-open**（拦不住 Bash 写保护路径不卡 agent 工具流）。

**phases_done 合法写入通路（D10 · L2-R3 R9）**：`is_phase_write` 扩拦 `.goal.phases_done` 写信号——agent 经 Bash/Write/Edit 写该字段一律 deny；只有 transition hook 子进程能写（与 29 号独占写握手同模式）。合法 phase 推进走 hook 子进程，dogfood 本 change 自身 transition 也走此通路（不自卡）。

---

## 4. ADR 索引

- `@.specs/gate-integrity/adr/G1-done-authenticity.md`（.done KVP + D7 常见写向量握手 + 两层时机 + fail 策略）
- `@.specs/gate-integrity/adr/G2-dynamic-gate-config.md`（动态读 gate_config + case 多源镜像）
- `@.specs/gate-integrity/adr/G3-gate-config-tamper-detection.md`（⑥ gate_config 篡改 v1 检测 · L2-R3 R2 新增）
- `@.specs/gate-integrity/adr/G4-gate-config-357.md`（3/5/7 扩展 + `all` 预设 + check-gate-sync set-diff 重写）

---

## 5. 风险

| # | 风险 | 影响 | 概率 | 缓解 |
|---|---|---|---|---|
| R1 | 三处 done 校验不闭环 | 绕过口子 | 中 | bats 断言三处入口 |
| R2 | 29 号 HOOK_TMP_DIR 时序 | module_output 炸 | 中 | `[ -n "$HOOK_TMP_DIR" ]` 守卫 |
| R3 | dogfood 回归（本 change .done 受新校验） | 卡本 change | 中 | phases_done 短路 + DEV 前确认本 change .done 过校验；本 change transition 走 D10 hook 通路 |
| R4 | PRESET_MAP 双源漂移 | 预设不一致 | 中 | check-gate-sync.sh **重写** set-diff（v1 必做 · D3） |
| R5 | 威胁③⑤ v1 非绝对挡 | exotic Bash 逃逸 / .md 同篡 | 中 | v1 挡常见向量 + 审计链；v2 加密完全挡 |
| R6 | pipeline-gates 泛化破坏 4-dev | 契约回归 | 低 | 保留 4-dev 参考实例 |
| R7 | Tier 1/2 时机误配 | 死锁复发 | 中 | bats 断言 Write Gate 只 Tier 1；regression-demos/skipped-subprocess |
| R8 | **威胁⑥ gate_config 篡改**（L2-R3 R2/R6） | agent 关 gate 绕过 | 中 | **v1 检测**（D8 .specs 快照 diff · 非"载体不存在"——.specs 未 gitignore）；v1.5 加密强防。agent 同改 .flow-active + 快照且不留 git 痕可绕（残留） |
| R9 | PreToolUse matcher 扩面 | hook 挂了影响 agent Write/Edit | 中 | path-guard fail-open（D9） |
| R10 | phases_done 短路被 jq 绕过 | agent 塞 phase 短路 | 中 | is_phase_write 扩拦 `.goal.phases_done`（D10）；仅 hook 子进程能写 |
| R11 | **校验 fail-close 误伤**（L2-R3 R3） | hook lib 不稳定时 deny 合法 transition | 低 | bats 覆盖畸形 .flow-active 输入；fail-close 仅对校验段，path-guard 仍 fail-open |
| R12 | **exotic Bash 写向量逃逸**（L2-R3 R7） | python-c/dd/变量间接/base64 伪造握手 | 中 | v1 文档化不挡（regression-demos/exotic-escape 列举）；v2 加密完全挡 |

---

## 6. 不在范围

- L4 model_tier opt-out（v2）
- `.done` 加密签名 / 哈希强化（v2 · 完全挡 ③ exotic + ⑤-L2 + ⑥ 强防）
- review 子进程本身的 L3 证据链（v2）
- 12 个基线失败（预先存在）
- **威胁③ exotic Bash 逃逸**（v1 best-effort 不挡 · 留 v2 加密 · R12）
- **威胁⑥ 强防**（v1 仅检测 D8 · 强防留 v1.5 加密 · R8）

> 注：⑥ 已从"v1 不防"提升到"v1 检测"（D8 · L2-R3 R2）。原 R8"载体不存在"是循环论证（.specs 未 gitignore），已修正。

---

## 9. 架构沉淀建议（供 `A-evolve` 同步用）

### 9.1 新增的可复用抽象

| 路径 | 能力 | 复用建议 |
|---|---|---|
| `flow-kit-artifacts.sh::fk_validate_done_marker` | .done 真实性校验（两层） | 所有 gate 入口统一调用 |
| `independent-review-gate.sh::is_handshake_write` | Bash 写保护路径检测（非穷尽） | 凡需路径保护的 hook 沿用 |
| `independent-review-gate.sh::fk_check_gate_config_tamper` | gate_config 篡改检测 | 凡配置驱动的 gate 沿用 |
| `29 号::write_handshake` | hook 独占写握手 | 凡需 agent 难伪造证据沿用 |

### 9.2 新增 / 改变的项目级技术决策

| 决策 | 取值 | 影响范围 | 推翻代价 |
|---|---|---|---|
| .done 格式 | 强制 KVP（G1） | 所有 .done | 契约锁定 |
| gate 阶段判定 | 动态读 gate_config（G2） | 所有 gate 入口 | 回退硬编码 |
| 校验时机 | 两层（G1） | 所有 .done 校验 | 死锁复发 |
| 威胁③锚点 | D7 常见写向量握手（G1 · B'） | 路径保护 gate | 绝对挡需 v2 |
| 威胁⑥检测 | D8 .specs 快照 diff（G3） | 配置驱动 gate | 强防需 v1.5 加密 |
| PreToolUse matcher | Bash+Write+Edit（D7） | 所有 PreToolUse | 路径保护失效 |
| fail 策略 | 校验 fail-close / path-guard fail-open（D9） | 所有 hook | 混淆则要么卡死要么放行 |

### 9.3 新增 / 修改的跨模块契约

```
- .done KVP：phase / change_id / written_by=review-subagent / written_at / L2_verdict / L3_verdict / session_id / artifacts（空格分隔）
- .flow-active.independent-review 握手（D7 · 29 号独占写）：
    {phase, status:"done", verdict, l3_token, written_by:"stop-hook-29", written_at}
- D7 path-guard（三类写向量 · 非穷尽 · L2-R3 R7）：
    ① Write tool：file_path 含 .flow-active.independent-review → deny
    ② Edit tool：同上 → deny
    ③ Bash：命令匹配写该路径（> >> tee cp mv sed -i dd of= printf awk..> install heredoc）→ deny
    【非穷尽】exotic（python-c/变量间接/base64）v1 不挡，留 v2 加密
    fail-open：lib 失败 → exit 0（path-guard 段）
- .specs/<id>/.goal-snapshot.json 契约（D8 · ⑥检测 · 入库）：
    goal 创建时写 {gate_config: <副本>, created_at}；transition hook diff .flow-active.goal.gate_config 与此，phase key independent→false/缺失 → deny
- is_phase_write 扩展（D10）：拦 .phase= / .goal.current_phase= / .goal.phases_done（仅 transition hook 子进程能写 phases_done）
- fail 策略（D9）：校验段 fail-close（exit 2）/ path-guard 段 fail-open（exit 0）
- INDEPENDENT-REVIEW-N.md L2 段首行：`> session: <id>`
- check-gate-sync.sh（D3 · R4 重写）：source SKILL.md 代码块 + declare -p PRESET_MAP 提取键集 ↔ bats resolve_gate_config 支持集，set-diff 不等 exit 1
- gate_config 数字映射扩 3/5/7（G4）
```

### 9.4 新增 / 升级的依赖

无新增（沿用 jq / curl / bash）。

### 9.5 禁动清单变化

```
- 新增禁动：independent-review-gate.sh（is_handshake_write + is_phase_write 扩展 + fk_check_gate_config_tamper）/ 29 号（握手写入）/ flow-kit-artifacts.sh gate 校验
- 新增禁动：fk_validate_done_marker + <tier> 参数语义
- 新增禁动：common.sh CONFIG_FILE 回退 / 29 号 l3_token 哈希算法
- 新增禁动：install_hooks.sh PreToolUse matcher（改回仅 Bash = D7 失效）
- 新增禁动：.specs/<id>/.goal-snapshot.json（⑥ 检测载体 · 改坏 = ⑥ 检测失效）
- 新增禁动：check-gate-sync.sh set-diff 逻辑（改回文本段 diff = PRESET_MAP 漂移无兜底）
```

---

> 本文件不含完整代码实现。函数签名 / 伪代码可，函数体不可。

## Known Limitations

### Token Visibility in Process List

`ANTHROPIC_AUTH_TOKEN` is passed to `curl` via `-H "Authorization: Bearer ..."` flag,
making the token temporarily visible in `/proc/*/cmdline` and `ps aux` output during
the brief window when curl is executing. This is an inherent limitation of
shell-script-based API calls (29-independent-review.sh, 30-ai-analyze.sh).

Mitigations in place:
- Token is NOT echoed, logged, or passed to `module_output` (verified by AC-9 in test suite)
- The window of visibility is limited to the duration of the curl HTTP request (typically <5s)
- On systems with `hidepid=2` procfs mount option, `/proc/*/cmdline` is not readable by other users
- Token originates from an environment variable already present in the session

Future hardening (not planned for v1): pass token via `--header @-` heredoc or
environment-variable-based auth (`ANTHROPIC_API_KEY`) for the API path, avoiding
the command-line argument entirely.
