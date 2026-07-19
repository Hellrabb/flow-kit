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
