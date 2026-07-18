# ADR-008: is_git_commit / is_gh_pr_create 结构判定（非正则剥离）

## Context
`is_git_commit`（gate.sh:111-113）当前 `[[ "$1" =~ (^|[[:space:]])git[[:space:]]+commit([[:space:]]|$) ]]`。不识 quoting/heredoc：`cat > f <<EOF ... git commit ... EOF` 的 heredoc 内容满足正则 → 误判（BUG-H 实跑复现，l2-l3-mock-fix phase 1 L2 写报告被拦，INDEPENDENT-REVIEW-1.md:9）。`is_gh_pr_create`（gate.sh:114-116）同结构同风险。

**L2-R-D2-1 + L3-critical 共识**：原"正则剥离 bash 词法（`_strip_command_literals`）"方案脆弱（换行/`eval`/拼接绕过 + 误杀合法拼接）+ 抽象层次错（正则模拟 bash 解析器）。改 **结构判定** 方向（L3-critical + L2 共识 + 用户定）。

## Decision
**结构判定**（不剥离 bash 词法）：
1. 命令含 heredoc（`<<`）/ 多行（`\n`）/ 写文件重定向（`>`/`>>` 到非 `/dev/null`）→ **不 deny**（判定为"写字面量上下文"，保守放行——heredoc/重定向内容可能是审查文本含敏感词）
2. 否则（单行执行命令）→ 按 `&&`/`||`/`;`/`|` split 子命令 → 各子命令取**前两 token** → 任一子命令满足 **token[0]=git AND token[1]=commit**（或 token[0]=gh AND token[1]=pr AND token[2]=create）→ **deny**。**判定是两/三 token 序列，非字面 'git commit' 字符串**（消除 L3 误读：`echo test | git commit -m` → split `|` → 子命令 `git commit -m` → token0=git ∧ token1=commit → deny ✓）

is_git_commit + is_gh_pr_create 共用结构判定逻辑（抽 helper `_command_has_write_context <cmd>` + `_command_first_tokens <cmd>`，避免 DRY 违反）。

**等价类**（AC-H (a)-(e)）：(a) 纯文本敏感子串 / (b) `echo "敏感子串"` / (c) heredoc·注释·变量展开 → 结构判定为非纯执行命令 → **不 deny**；(d) 真实 `git commit` / (e) `git commit`+管道 → 首 token git commit → **deny**。

**反规避约束（AC-H (f)）+ grep 锚点**（回应 L2-R-D2-AC-f）：实现禁白/黑名单列表。grep 断言用精确模式避开 `deny_reason="git commit"` 标签（gate.sh:417）+ 注释：
```
grep -nE '^[^#]*\b(git[[:space:]]+commit|gh[[:space:]]+pr[[:space:]]+create)\b' independent-review-gate.sh | grep -vE 'deny_reason=|^[0-9]+:[[:space:]]*#'
```
断言输出为空。或 deny_reason 标签改 `g__commit_deny` 消歧。AC-T 固化。

## Consequences
- ✅ 不剥离 bash 词法（简单稳，回应 L3-critical + L2-R-D2-1）
- ✅ 根治 BUG-H（heredoc 写报告不误拦）+ is_gh_pr_create 同步
- ✅ 反规避（无字面量列表）
- ⚠️ **tradeoff**：含 heredoc 的真实 git commit 漏拦（罕见，git commit 一般不伴 heredoc）；`sudo git commit` 漏拦（sudo 是首 token）—— 风险段 R2/R3 记录
- ⚠️ 子命令 split 不处理嵌套引号内的分隔符（保守：引号内 `&&` 不 split）—— 边界测试覆盖
- 备选否决：正则剥离（脆弱）；首 token 仅（漏拦 `&&` 后 git commit）；白名单（违反 AC-H (f)）
