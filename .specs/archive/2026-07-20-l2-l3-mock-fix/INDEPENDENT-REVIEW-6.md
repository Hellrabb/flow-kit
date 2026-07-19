# 独立审查 · 阶段 6

- **change-id**: l2-l3-mock-fix
- **审查员**: L2 独立盲审（code-reviewer 子 agent · 固化指令注入）
- **工件**: `git diff c00afb8..HEAD`（40 files +3640/-58 · 5 hook 源码 + 5 新测试 + 4 ADR + SPEC 文档）
- **参考（待复核对象）**: `.specs/l2-l3-mock-fix/REVIEW.md`（主 agent 结论：0/0/0 pass）
- **独立性声明**: 仅基于工件本身判断；未引用主 agent 自评作为权威；以下证据均可在 diff 中独立复现。

---

## L2 盲审

### 独立性核验

- 未检测到主 agent 上下文注入（prompt 仅含固化指令 + 工件路径 + REVIEW.md 路径，符合"待复核对象"标注）。
- REVIEW.md 仅作为"主 agent 漏判/误判"对照引用，不作为权威。

### 独立复现的关键事实（用于下列发现的证据）

实测命令（在 `flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh` 当前 HEAD 上 source 后直接调用）：

| 输入命令 | 新 `is_git_commit` | 旧正则 `(^|[[:space:]])git[[:space:]]+commit([[:space:]]|$)` | AC-H (e) 预期 |
|---|---|---|---|
| `$'echo start\ngit commit -m "x"\necho done'` | **false（不 deny）** | true（deny） | deny |
| `'git commit -m "x" 2> /tmp/err.log'` | **false（不 deny）** | true（deny） | deny |
| `$'git commit -F - <<EOF\nmsg\nEOF'` | **false（不 deny）** | true（deny） | deny（heredoc-body 文字含 `git commit` 时旧代码亦误拦；此行属真实 commit） |
| `'git commit -m "x" && git push'` | true（deny） | true（deny） | deny |
| `'echo "讨论 git commit 流程"'` | false（不 deny） | true（**旧误拦**） | not deny |

source-fail 实测：`HOOK_BASE_DIR=/tmp/nonexistent bash independent-review-gate.sh < git-commit-payload` → **exit 0**（gate 放行；header 注释却声明 "review gate 校验 = fail-close"）。

536 bats 真绿（独立复跑 `npx bats test/` → 536 ok / 0 fail / exit=0），与 REVIEW.md 一致；但 R1 的漏拦场景**无任何测试覆盖**（test-is-git-commit-structural.bats (d)(e) 均为单行无重定向/无 `\n` 命令）。

---

### 🔴 R1 · AC-H (e) 真实 git commit 带重定向/多行漏拦：spec 合规失败 + 主 agent 漏判

**Symptom（症状）**：`flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh` 的 `_command_has_write_context`（新增 helper）对**任意**含 `\n` / `<<` / `>file`（非 `/dev/null`）的命令一律返回 0（写字面量上下文），使 `is_git_commit` 直接 `return 1`（不 deny）。结果：
- `git commit -m "x" 2> /tmp/err.log`（真实 commit + stderr 重定向到文件）→ **不 deny**
- `$'echo a\ngit commit -m "b"'`（多行脚本中真实 commit）→ **不 deny**
- `git commit -F - <<EOF ... EOF`（真实 commit，message 从 heredoc 读）→ **不 deny**

REQUIREMENT.md AC-H (e) 明文要求 "真实 `git commit` 带前后管道/重定向/子 shell → **deny**"。当前实现对"重定向"与"多行"两个子类**不 deny**，AC-H (e) 未实现。

**Source（源头）**：
- REQUIREMENT AC-H (e) 字面 "重定向 → deny"（`.specs/l2-l3-mock-fix/REQUIREMENT.md:38-41`）。
- 固化指令严重度定义："🔴 Critical（... AC 未实现 / spec 合规失败）"。
- DESIGN D2 的"取舍代价"仅列出 "含 heredoc 的真实 git commit 漏拦（罕见）"——**未列出**"重定向漏拦"或"多行漏拦"，即此两路漏拦连 DESIGN 都未承认，更未经用户显式批准为 accepted-risk。
- 反规避约束（AC-H 硬约束）：本 AC 禁止用白/黑名单绕过；同理也不应通过过宽的 write-context 启发式绕过。

**Consequence（后果）**：
- 主 agent（或被诱导/越界的子 agent）写 Bash 工具调用时，只需 `git commit -m x 2> log` 或把 commit 嵌入多行脚本，即可**静默**绕过独立 review gate 提交。相比 `touch .done`（显式审计痕迹）或 `--no-verify`（hook 层独立），此路径**无任何日志/审计**，是漏洞而非 feature。
- REVIEW.md 表 1 声称 AC-H ✅ 合规、表 2 "6 维整体改善"、结论 "Verdict: pass"——三项均与实测矛盾。**主 agent 漏判**（未对照 AC-H (e) 重定向子类跑等价类测试；test-is-git-commit-structural.bats (e1)(e2)(e3) 全为单行无重定向/无 `\n` 命令，对漏拦零覆盖）。
- 立即可爆：任意主 agent 在 6-review 后阶段若用 `git commit > /tmp/log 2>&1`（极常见的 stderr/stdout 捕获模式）提交，gate 失效。

**Remedy（修补）**：三选一（优先 a）：
- **(a) 收紧 write-context 启发式**：仅当**实际存在 heredoc 起始 token**（正则 `<<[-]?[A-Z_]+\|<<[-]?['"][^'"]+['"]\|<<[-]?$`）或**重定向目标在被引号包裹的字符串内**时才判为 write-context；命令结构层（token0=git ∧ token1=commit）的判定应先于 mtime/redirect 启发式。具体：先 `_command_first_tokens` 拆分 → 对每个子命令独立查 `git commit` token 序列 → 命中即 deny，**再**用 write-context 作为 quoted-string 内 token 的去敏手段（而非整命令级 short-circuit）。
- **(b) 补 AC-H (e) 测试**：至少加 (e4) `git commit -m x 2> log`、(e5) `$'a\ngit commit -m b'`、(e6) `$'git commit -F - <<EOF\nm\nEOF'` 三例 deny 断言；当前测试对漏拦零覆盖，违反 AC-T "每个改动伴 ≥1 集成测试"。
- **(c) 显式放宽 AC 并更新 REQUIREMENT/CONTEXT**：若维护者确接受此 trade-off，须把 AC-H (e) 改为 "真实 git commit 带前后管道/`;`/`&&` → deny；重定向到非 /dev/null 文件、多行脚本中的 commit 暂不 deny（v2 收紧）"，并在 REVIEW.md 严重度汇总登记为 accepted-risk 🟡，而非宣称 0 Major。

---

### 🟡 R2 · AC-F source common.sh 失败时 fail-open：与 header "fail-close" 声明矛盾

**Symptom（症状）**：`independent-review-gate.sh:24-26` 新增：
```bash
COMMON_LIB="${HOOK_BASE_DIR}/../stop/lib/common.sh"
source "$COMMON_LIB" 2>/dev/null || true
```
若 source 失败（路径错、`HOOK_BASE_DIR` 异常、文件权限、common.sh 语法坏），`fk_phase_gate_key` 未定义；后续 `local phase_name="$(fk_phase_gate_key "$phase")"` 因 `local` 屏蔽 `set -e`（bash 经典坑）而**静默**得到空串 → `gate_val=""` → `_gate_check_l2/l3` 不 deny → **gate 完全失效但 exit 0**。实测 `HOOK_BASE_DIR=/tmp/nonexistent bash independent-review-gate.sh <git-commit-payload` → exit 0。

REVIEW.md 表 "fail 策略（D9）" 与源码 header 第 9 行明文 "review gate 校验 = fail-close"，但 source 失败这一上游错误未进入 fail-close 范畴，行为与声明直接矛盾。

**Source（源头）**：
- 源码注释自相矛盾：`independent-review-gate.sh:9` "review gate 校验 = fail-close" vs `:26` `source ... || true`（fail-open）。
- 经典防御编程原则（Clean Code / Fail-Fast）：security gate 失败应 fail-close，否则失败即为绕过。
- 固化指令"安全性 / Zero critical security issues"。
- ADR-007 未讨论 source 失败模式，DESIGN 风险表 R1（"D1 pure fn 破坏 v1 forward transition gate"）只考虑 pure fn 逻辑错，未考虑 source-load 错。

**Consequence（后果）**：
- 环境异常（hook bundle 路径被改、权限错、容器挂载差异、CI 中 `$0` 解析异常）下 gate **完全静默失效**，且无任何 stderr 输出（被 `2>/dev/null` 吞掉）。
- 老代码（inline `declare -A`）自包含、无此外部失败面；本次重构引入了新的失败面却用 `|| true` 吞掉，是**净倒退**。
- 爆期不定（视环境），但一旦爆即完全失守，且无日志可追溯。

**Remedy（修补）**：
```bash
source "$COMMON_LIB" || { echo "[ir-gate] CRITICAL: source common.sh failed ($COMMON_LIB) — fail-close" >&2; exit 2; }
[[ $(type -t fk_phase_gate_key) == function ]] || { echo "[ir-gate] fk_phase_gate_key missing — fail-close" >&2; exit 2; }
```
（或最低限度：删 `2>/dev/null`，让 source 失败时 stderr 外泄 + `set -e` 触发非零退出，由外层 dispatcher 兜底。）

---

### 🟢 R3 · AC-I "双管 (a) SessionStart banner" 未实装：DESIGN 超出实际交付

**Symptom（症状）**：DESIGN D3（第 70 行）承诺 "L2-first 顺序契约 + **双管缓解**：(a) `.flow-active.correction` hook 兜底（Stop D4 写 flag → **SessionStart banner**）"，即 writing-the-flag 与 reading-the-flag 两端都做。实际交付仅 writing 端：`29-independent-review.sh:_write_l2_missing_correction` 写入 `type:"l2-missing"`，但函数自身注释自承 "SessionStart flow-kit-resume.sh 当前**仅对 type=compliance 显示 banner**；l2-missing flag 作持久化记录 + **未来** SessionStart 扩展识别的载体（D3 双管 a 的 banner 部分**待 SessionStart 适配**）"。

即 reading 端不存在，用户/主 agent 在新一轮 session 启动时**看不到任何 banner 提示**，DESIGN 宣称的 "protect-the-weakest（多层）" 实际只剩单层（D4 stderr 瞬时提示）。

**Source（源头）**：
- DESIGN D3 双管 (a) 明文 "SessionStart banner"（`.specs/l2-l3-mock-fix/DESIGN.md:70`）。
- 固化指令"文档完整 / 架构沉淀"。ADR-009 未声明此 banner 为 v2。

**Consequence（后果）**：低烈度假阴性：若主 agent 错过 D4 stderr（Stop hook 输出极易被刷屏），下一 session 不会重新提醒，L2 可能持续漏派。当前 AC-I 子条 (a)(b)(c) 字面满足（CONTEXT.md 更新 + D4 提示 + module_output 日志），故非 spec 违规；但 DESIGN 文档与实际交付有差，未来维护者按 DESIGN 修改时会被误导。

**Remedy（修补）**：二选一：
- (a) 实装 SessionStart 对 `type=l2-missing` 的 banner（flow-kit-resume.sh 扩展 type 白名单）。
- (b) 更正 DESIGN D3 / ADR-009：把 "SessionStart banner" 标为 v2，v1 仅 writing 端，并在 CHANGE/REQUIREMENT 显式降级此 mitigation 层级（避免文档谎报）。

---

### 🟢 R4 · REVIEW.md "6 维整体改善 / 0 Major" 过度乐观：主 agent 漏判 R1/R2

**Symptom（症状）**：REVIEW.md 表 2（6 维）全 ✅、"严重度汇总 0 Critical 0 Major 0 Minor"、"Verdict: pass"。独立盲审得出 R1（🔴）+ R2（🟡）+ R3（🟢）+ 本 R4，至少 1 🔴 1 🟡。差距源于：
- 表 2 的 6 维分析未对照 AC-H (e) 重定向/多行等价类实测，仅做"helper 抽取 → 认知负荷下降"等抽象陈述，未跑反规避回归。
- 表 1 AC-H ✅ 基于 test-is-git-commit-structural.bats 全绿，但该测试对漏拦场景零覆盖（见 R1）——"绿"不等于"AC 真覆盖"。
- "fix 任务：无（0 Critical + 0 新 Major）"与实测不符。

**Source（源头）**：固化指令"对照主 agent 的 REVIEW.md，指出它**漏判或误判**的 🔴 项"；固化指令"证据优先于解释"。

**Consequence（后果）**：toll-gate 6→7 被错误放行；带已知 🔴 进入 phase 7（integration）会让集成测试在已被污染的 gate 基线上构建，后续定位成本指数上升。

**Remedy（修补）**：toll-gate 回退至 6，先解决 R1（a 或 c 二选一）+ R2（删 `|| true`），再重跑 L2/L3。

---

### 主 agent REVIEW.md 漏判/误判清单

- **主 agent 漏判**：AC-H (e) "重定向 → deny" 子类未实现（R1，🔴）。REVIEW.md 表 1 标 AC-H ✅、表 2 标 "R4 偶然复杂 ✅ 改善"，但未实测 `git commit > file` / `git commit 2> log` / 多行 commit。
- **主 agent 漏判**：AC-F source common.sh 的 fail-open 与 header "fail-close" 矛盾（R2，🟡）。REVIEW.md 表 2 "R5 依赖混乱 ✅ 无循环" 仅看依赖方向，未审失败模式。
- **主 agent 漏判**：AC-I DESIGN D3 的 SessionStart banner 未实装（R3，🟢）。REVIEW.md 表 1 标 AC-I ✅，但未对照 DESIGN 承诺的双管 (a) 端到端成立性。
- **主 agent 误判**：REVIEW.md "代码质量 6 维整体改善"——R1/R2 实为净倒退（安全性维度），结论过度乐观。

---

### 6 维独立评估（仅对本 change 触碰代码）

| 维度 | 独立判断 |
|---|---|
| R1 认知过载 | ✅ 改善（helper 抽取确实降低 is_git_commit 复杂度） |
| R2 变更传播 | ✅ 改善（pure fn 单一来源）+ ⚠️ 引入新传播面（gate.sh → source common.sh 失败模式） |
| R3 知识重复 | ✅ 改善（DRY：消除 2 处 declare） |
| R4 偶然复杂 | 🟡 **倒退**（write-context 启发式过宽，引入 R1 漏拦；`|| true` 吞 source 错） |
| R5 依赖混乱 | ⚠️ gate.sh 现新增 source 依赖 common.sh（pre-tool-use → stop/lib），跨 hook 子目录边界，旧代码自包含；DESIGN §2.2 称"方向一致 hook→lib"，但 pre-tool-use 与 stop 是不同 hook 类别，该断言偏乐观 |
| R6 领域扭曲 | ✅ 忠实（gate 领域语义未扭曲） |

---

**Verdict**: **fail**

存在 1 项 🔴 Critical（R1：AC-H (e) 重定向/多行子类未实现 + 主 agent 漏判），1 项 🟡 Major（R2：source fail-open 与声明矛盾），2 项 🟢 Minor（R3 banner 未实装、R4 REVIEW 过度乐观）。536 bats 虽真绿，但对 R1 漏拦场景零覆盖，AC-T 的"每个改动伴 ≥1 集成测试"对 AC-H (e) 重定向/多行子类未满足。

回退 toll-gate 6→7 至 R1（a 或 c）+ R2 修复后重审。独立性声明：本结论仅基于 git diff 与 REQUIREMENT/DESIGN 独立得出，未受主 agent REVIEW.md 影响。

---

## L2 重审（T-FIX 后 · 2026-07-19）

### 独立性核验

- 工件：`git diff 85628fe..57b2669`（T-FIX 改动）+ `git diff c00afb8..HEAD`（全 change）+ `.specs/l2-l3-mock-fix/REVIEW.md`（末段 "T-FIX 修复" 待复核）+ `T-FIX-SUMMARY.md`。
- REVIEW.md 末段「R1/R2 Fixed in ...」**仅作"待复核对象"**，不作为权威；以下结论均基于对当前 HEAD 源码独立 source 后调用 `is_git_commit` + `bash gate.sh < payload` 实测得出。
- 未检测到主 agent 自评注入：prompt 仅含"主 agent 自评 R1/R2 Fixed，**待你独立复核**"，措辞中性。

### 独立复现的关键事实（T-FIX 后）

实测（在 `/home/hellrabbit/unisoc/flow-kit/flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh` 当前 HEAD source 后直接调用 `is_git_commit` / 整体 `bash gate.sh < payload`）：

| 输入命令 | is_git_commit | gate.sh exit | 期望 | 判定 |
|---|---|---|---|---|
| `git commit -m "y" 2> /tmp/clog` | **0（deny）** | 2（deny + NFR-3 三要素 stderr） | deny | ✅ R1 修复 |
| `git commit -m "y" > /tmp/out` | **0（deny）** | — | deny | ✅ R1 修复 |
| `$'echo a\ngit commit -m "y"'` | **0（deny）** | — | deny | ✅ R1 修复 |
| `$'git commit -F - <<EOF\nmsg\nEOF'` | 1（不 deny） | — | not deny（已知限制） | ✅ e7 锁定 |
| `cat <<EOF\nreview 文本含 git commit 字符串\nEOF` | 1（不 deny） | — | not deny | ✅ BUG-H 不误拦 |
| `echo "讨论 git commit 流程"` | 1（不 deny） | — | not deny | ✅ 不误拦 |
| HOOK_BASE_DIR=/tmp/nonexistent bash gate.sh <git-commit-payload> | — | **2（fail-close）** + stderr "common.sh 加载失败...fk_phase_gate_key 未定义" | exit 2 | ✅ R2 修复 |
| HOOK_BASE_DIR 正确 + gate_config=both + 无 .done + git commit payload | — | 2（deny）+ NFR-3 三要素 stderr | exit 2 deny（gate 真工作） | ✅ 正常路径不退化 |
| 全套 bats | — | 541 ok / 0 fail / exit=0 | 541/0（+5 新测）| ✅ 与 T-FIX-SUMMARY 一致 |

上轮 R1/R2 两个 fail 证据点**已全部消失**（exit code 从 0 翻为 2 / is_git_commit 对重定向/多行返回 0）。下文聚焦 T-FIX 是否真实修复 + 是否引入新问题。

---

### 🟢 RR1 · 原 R1（🔴 AC-H(e) 重定向/多行漏拦）：真实修复，验证通过

**Symptom（症状）**：T-FIX-01 收紧 `_command_has_write_context`（gate.sh:117-121）为**只 heredoc(`<<`) → 写上下文**，移除原"多行(\n) / 重定向(> 非/dev/null) → 写上下文"两路。源码 diff 与 T-FIX-SUMMARY 声称一致；实测 `git commit 2>log` / 多行 git commit 均进入 `_command_first_tokens` token 判定 → 命中 `t0=git ∧ t1=commit` → return 0（deny）。AC-H (e) 的两个原本漏拦子类（重定向、多行）**已实现 deny**。

**Source（源头）**：AC-H (e) 字面要求（REQUIREMENT:39）；ADR-008（结构判定 + quoting 感知）。修复路径对应上轮 Remedy (a)：先 token 判定，write-context 仅作 quoted-string 内 token 的去敏。

**Consequence（后果）**：原 🔴 已消除；反规避 (f) 未破坏（token 序列判定，无字面 'git commit' 白黑名单——`grep` 断言 test 18 仍 pass）。补测 e4/e5/e6 覆盖三个原本漏拦等价类，e7 锁定 heredoc-message 已知限制防回归，AC-T 对 AC-H (e) 重定向/多行子类的"≥1 集成测试"现在满足。

**Remedy（修补）**：无需。修复采纳了上轮 Remedy (a) 的精确思路，且测试覆盖到位。

---

### 🟢 RR2 · 原 R2（🟡 source fail-open 与 fail-close 声明矛盾）：真实修复，验证通过

**Symptom（症状）**：T-FIX-02 在 `source "$COMMON_LIB" 2>/dev/null || true`（gate.sh:27）**之后**追加 `if ! declare -f fk_phase_gate_key >/dev/null 2>&1; then ... exit 2; fi`（gate.sh:30-33）。实测 `HOOK_BASE_DIR=/tmp/nonexistent-$$ bash gate.sh <git-commit-payload>` → exit 2 + stderr 含 "common.sh 加载失败" + "fk_phase_gate_key 未定义" + "fail-close"，与 T-FIX-SUMMARY 一致。gate.sh header :12 "review gate 校验 = fail-close" 现与实际行为一致。

**Source（源头）**：header 第 12 行声明；Clean Code Fail-Fast / Security gate fail-close 原则。

**Consequence（后果）**：原 🟡 已消除；`|| true` 保留（吞 source stderr 防 set -e 副作用）但**后置 `declare -f` 显式校验**把失败模式重新纳入 fail-close，逻辑闭环。正常路径（HOOK_BASE_DIR 正确）deny 行为不退化（实测 exit 2 + NFR-3 三要素 stderr）。

**Remedy（修补）**：无需。最低限度的 fail-close 检查，未引入新失败面。

---

### 🟢 RR3 · T-FIX-01 已知限制范围文档不完整：实际 bypass 面比 e7 锁定更广

**Symptom（症状）**：T-FIX-01 注释（gate.sh:116）+ e7 测试仅承认 **1 种** heredoc 已知限制：`git commit -F - <<EOF\nmsg\nEOF`（heredoc 作 commit message）。实测发现 `<<` 子串短路还覆盖**至少 2 种更现实**的真实 commit 漏拦：
- `git commit -m "$(cat <<EOM\nmulti-line msg\nEOM)"` —— 用 `$(...)` 命令替换 + heredoc 构造多行 message（agent 写多行 commit 的常见惯用法）→ `[[ "$cmd" == *"<<"* ]]` 命中 → write_context → return 1（**不 deny**）
- `cat <<EOF | xargs -I {} git commit -m {}` —— heredoc 管道喂 commit → 同理**不 deny**

二者**均为真实 commit**（不仅 `git commit -F - <<EOF` 这一种）。前置 l2-l3-mock-fix 引入 `<<` 短路前，旧正则 `(^|[[:space:]])git[[:space:]]+commit([[:space:]]|$)` 对二者均能 deny（实测复跑旧 regex 即可证实）。

**Source（源头）**：
- ADR-008 / T-FIX 注释 :116 与 e7 测试用例注释均只枚举 1 种 heredoc 限制；DESIGN §"取舍代价"亦同。文档对已知限制的**枚举不全**。
- AC-H (e) "子 shell" 子类（`$(...)` 是命令替换 = 子 shell 的一种）。

**Consequence（后果）**：低烈度。`<<` 短路是 l2-l3-mock-fix 为 BUG-H（写报告含敏感词不误拦）做的取舍，本身合法；但"已知限制"清单不完整会让未来维护者误以为 bypass 面只有 e7 一种，低估 residual risk。当前 v1 不要求根治（v2 加密签名路径已在 DESIGN §6 列明），但**文档枚举须诚实**。

**Remedy（修补）**：把注释/e7 用例说明扩展为枚举式："已知限制（含但不限于）：(i) `git commit -F - <<EOF`；(ii) `git commit -m "$(cat <<EOM ... EOM)"`；(iii) `cat <<EOF | xargs git commit`。三者皆因 `<<` 子串短路触发，v2 加密签名根治。" 可选补 1 个 bats 用例锁定 (ii) 当前 not-deny 行为防回归。

---

### 🟢 RR4 · REVIEW.md 顶部 verdict 与底部历史段措辞张力（非阻塞）

**Symptom（症状）**：REVIEW.md 顶部表「严重度汇总 0/0/0 + Verdict: pass」（行 90-98）未改，但行 106-123「L2 复核修正」已翻为 fail、行 127-142「T-FIX 修复」标 "待 L2/L3 复核"。读者首屏看到 pass，需向下滚动 ~100 行才看到已被翻转。三段并存（pass → fail → 待复核）作为审计史保留是合理的，但顶部缺一个 "⚠️ 本 verdict 已被下方 L2 复核翻转，以最新段为准" 的导航注记。

**Source（源头）**：固化指令「文档完整清晰」。

**Consequence（后果）**：极低。审计 trail 完整但首屏误导，可能让快速浏览者误以为 pass 仍生效。

**Remedy（修补）**：在 REVIEW.md 顶部 metadata 段加一行 "最新状态：T-FIX 后重审 pass（见末段 L2 重审）—— 顶部 Verdict: pass 是历史首轮结论，已被 L2 复核修正段翻转，再被 T-FIX 段重置"。

---

### 原 R3/R4 状态（不在 T-FIX 范围，保留登记）

- **原 R3 🟢**（SessionStart banner 未实装）：T-FIX 未触（scope 仅 R1/R2）。登记为 Tech-debt，DESIGN D3 双管 (a) reading 端待 SessionStart 适配。非阻塞。
- **原 R4 🟢**（首轮 REVIEW 过度乐观）：REVIEW.md 「L2 复核修正」段已自登 1 🔴 + 1 🟡，主 agent 漏判在文档层已纠正。T-FIX 段进一步如实登记。视为已 documentationally 解决。

---

### 6 维独立评估（仅对 T-FIX 触碰代码 = gate.sh helper + source + 新测）

| 维度 | 独立判断（T-FIX 增量） |
|---|---|
| R1 认知过载 | ✅ 进一步改善（`_command_has_write_context` 从 3 条件 → 1 条件，更直观） |
| R2 变更传播 | ✅ 改善（fail-close `declare -f` 检查是局部 + 显式，传播面小） |
| R3 知识重复 | — 不涉 |
| R4 偶然复杂 | ✅ 改善（移除重定向 regex + 多行短路两分支 → 单一 `<<` 判定，复杂度下降） |
| R5 依赖混乱 | — 不涉（未新增 source 边） |
| R6 领域扭曲 | ✅ 忠实（"重定向/多行真实 commit 须 deny" 是领域正确语义） |

T-FIX 在 6 维上**无倒退**（R4 偶然复杂度反而下降）。RR3 文档枚举不全不构成代码维倒退。

---

### 主 agent REVIEW.md「T-FIX 修复」段漏判/误判清单

- **无误判**：R1/R2 "Fixed in" 文件 + 行号 + 效果描述与独立实测一致；"20/20 + 全套 541/0 + 部署同步 md5" 与独立复跑 `npx bats test/` 一致。
- **轻度漏报**：RR3（heredoc 已知限制枚举不全，至少漏 2 种更现实的真实 commit bypass 模式）。属文档诚实度问题，非 spec 违规，不阻塞。
- **轻度文档张力**：RR4（顶部 verdict 与底部最新段不一致，无导航注记）。

---

**Verdict（T-FIX 后重审）**: **pass**

原 🔴 R1（AC-H(e) 重定向/多行漏拦）+ 原 🟡 R2（source fail-open）**两项阻塞项经独立实测确认真实修复**：
- R1：`is_git_commit` 对 `git commit 2>log` / `git commit >out` / 多行 commit 均返回 0（deny）；gate.sh 整体对 git-commit payload 在 gate_config=both + 无 .done 下 exit 2 deny。
- R2：HOOK_BASE_DIR 错 → exit 2 + stderr fail-close 告警；正常路径 deny 不退化。

全套 bats 541/0 真绿（独立复跑，无假绿）。RR3/RR4 两 🟢 非阻塞（建议下一轮顺手收紧文档枚举 + 顶部 verdict 导航注记，不强制）。原 R3 🟢（SessionStart banner）保留 Tech-debt。

可进 toll-gate 6→7。独立性声明：本重审结论仅基于 git diff + 当前 HEAD 源码独立 source 后实测，未受主 agent REVIEW.md「T-FIX 修复」段自评影响（该段作"待复核对象"处理）。

---

## L3 重审（glm-5.1 外部模型 · 2026-07-19 23:38）

> 自动生成于 2026-07-19 23:38。由 l3-review.sh 写入。

### 审查结论

```json
{"critical":[],"major":[],"minor":[],"verdict":"pass","summary":"前次发现的 R1/R2 缺陷已被针对性修复，且修复方案未引入新的认知过载或偶然复杂度，附带的新增测试有效覆盖了相关边界场景。"}
```

L3_artifact_hash: 94a0fd82850b613c03378df6d8588ab09783156c2e0d7c934b0da8ec12435dfc

---

## 主 agent 响应 L2 重审（2026-07-19 · RR3/RR4/原 R3）

> L2 重审 Verdict=**pass**（R1/R2 独立确认 Fixed）。3 项 🟢 Minor 处理：

### RR3 · heredoc << 短路覆盖 bypass（🟢）→ Fixed in
**Fixed in**: gate.sh:116 注释扩展（枚举 3 种 heredoc bypass：`-F - <<EOF` / 多行 message `$(cat <<EOM)` / 管道喂 commit，诚实登记 residual regression + v2 加密签名根治）+ test e8/e9 bats 锁定 not-deny 行为（防回归）

### RR4 · REVIEW.md 顶部 verdict 导航缺失（🟢）→ Fixed in
**Fixed in**: REVIEW.md 顶部加「状态演进」导航注记（最新状态以末段 L2 复核/T-FIX 为准；顶部 0/0/0 pass 为初审作废值）

### 原 R3 · SessionStart banner 未实装（🟢）→ Tech-debt
**Tech-debt**: DESIGN D3 双管 (a) reading 端待 SessionStart 适配。计划：后续 SessionStart hook 加 type=l2-missing banner。

注：bats heredoc cmd（e7-e9/c1）的警告是 bats run helper 对含 `<<` 命令的已知解析噪音（test_functions.bash:471），exit=0，测试全 pass，非测试缺陷。

### 元发现 · .done-6 L2_verdict=fail（l3-review.sh 提取 bug）→ Tech-debt
**Tech-debt**: .done-6 写入时 L2_verdict 取 INDEPENDENT-REVIEW-6.md 首个 `## L2 盲审`段（初审 fail），非 `## L2 重审`段（pass）。根因：l3-review.sh L2 verdict 提取取首个段。`fk_validate_done_marker` 仅校验 L2_verdict 值域（pass|fail|skipped）非必须 pass → gate 放行（commit/toll-gate 不阻塞）。语义错误（.done L2=fail 而 L2 重审 pass）。计划：独立 change 修 l3-review.sh L2 verdict 提取（取最新段 / `## L2 重审`优先）。非本 change 范围（gate hook 自身 bug）。
