# T02-SUMMARY — D2·H is_git_commit/is_gh_pr_create 结构判定

- **Task**: T02 (D2·H) — is_git_commit/is_gh_pr_create 改结构判定（BUG-H 根治）
- **Change**: l2-l3-mock-fix
- **关联**: ADR-008 / REQUIREMENT AC-H / DESIGN D2·R2/R3
- **状态**: ✅ verify 全绿（T02 单测 15/15 + 全套 520/1，AC-3 基线隔离）

## 改动清单

| 文件 | 改动 |
|---|---|
| flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh | 删旧正则 is_git_commit/is_gh_pr_create（`[[ =~ git commit ]]`，不识 quoting/heredoc = BUG-H 温床）→ 抽 2 helper + 结构判定（token 序列） |
| test/test-is-git-commit-structural.bats | 新建：15 测试（等价类 a-f + NFR-3） |
| flow-kit-bundle/test/test-is-git-commit-structural.bats | AC-7 一致性同步 |

## ADR-008 方案（结构判定，非正则剥离 bash 词法）

- `_command_has_write_context <cmd>`：含 `<<`/多行/`>`/`>>`（非 /dev/null）→ return 0（保守不 deny：heredoc/重定向内容可能是审查文本含敏感词）。fd 合并 `2>&1` 不算写文件
- `_command_first_tokens <cmd>`：引号感知 split `&|;`（单/双引号内分隔符不 split，保守）→ 各子命令前 3 token，输出 `t0|t1|t2`
- `is_git_commit`：`! write_context && 任一子命令 token0=git ∧ token1=commit` → deny
- `is_gh_pr_create`：同，`token0=gh ∧ token1=pr ∧ token2=create`
- **反规避 (f)**：token 序列判定（"git"/"commit" 分开 `==` 比较），无字面 `'git commit'` 白黑名单

## verify 结果

| 检查 | 结果 |
|---|---|
| T02 单测（等价类 a-f 各类 + NFR-3） | ✅ 15/15 pass |
| 全套 bats（1.8 破坏性变更回归） | ✅ 520 ok / 1 not ok（AC-3 基线） |
| INT-7（T01 forward transition deny） | ✅ 未被 T02 破坏 |
| 语法 `bash -n` gate.sh | ✅ OK |
| 反规避 (f) grep（源码无白黑名单字面量） | ✅ output 空 |
| NFR-3 deny stderr 三要素 | ✅ phase_name + .done 路径 + 阻断原因 |

## 6 维 self-review（内置快查 · 基于已验证证据）

1. **正确性** ✅：等价类 a-f 全覆盖（15 测试）+ 全套 520/1
2. **复用（reuse）** ✅：抽 2 helper（is_git_commit + is_gh_pr_create 共用，避免 DRY）+ 沿用 gate.sh source guard（:475）做单元测试范式（比集成 payload 精准）
3. **简单性** ✅：结构判定（token 序列）vs ADR-008 否决的"正则剥离 bash 词法"（脆弱，换行/eval/拼接绕过）
4. **效率** ✅：for 循环逐字符引号感知 split（NFR-1 由 T07 实测填阈值）
5. **可读性** ✅：helper 命名清晰（`_command_has_write_context`/`_command_first_tokens`）+ 注释标 ADR-008 + 反规避说明
6. **测试质量** ✅：等价类 a-f 各类覆盖 + 反规避 grep 静态断言 + NFR-3 集成（git commit final deny）

## 越界检查（R6.5 / R7.3）

- ✅ gate.sh + 2 test 在 T02 write_files 内
- ✅ flow-kit-bundle/test/ 副本 = AC-7 一致性同步（非范围扩展）
- ✅ 未改 deny_reason 标签（L2-R11 反驳：保留 `"git commit"` 可读标签，反规避 grep 已豁免）
- ✅ 未改 REQUIREMENT/DESIGN/其他 task 文件
- ✅ 未改 7 Gate 控制流（is_git_commit 仅改命令识别，_gate_deny_reason 调用不变）

## 沿用既有抽象 grep（1.4 · R6.4）

- `_command_has_write_context` / `_command_first_tokens` 新建（grep NOT-EXIST，无重复）
- is_git_commit/is_gh_pr_create 沿用函数名（改实现，不改 API/调用点）
- source guard（gate.sh:475 `BASH_SOURCE[0]==$0`）沿用 → 测试 source gate.sh 不触发 main

## 扫 LESSONS（1.5 · R1.8）

- **L-027**（bats 禁 `|tail`）：T02 verify 全程 `npx bats ...; echo "EXIT=$?"` 直接判 exit
- **L-010**（破坏性变更后立即验证）：改公共函数 is_git_commit 行为 = 破坏性变更 → 全套 bats 恢复验证（520/1）

## 破坏性变更（1.8 · R4.6）

- 改公共函数 is_git_commit/is_gh_pr_create 行为（正则 → 结构判定）
- grep 引用图：is_git_commit 调用点（gate.sh:412 `_gate_deny_reason` deny_reason 路径 + 测试）
- 回归覆盖：T02 单测（等价类 a-f）+ 全套 bats

## 遗留（非 T02 范围，记录供后续）

1. **AC-3 基线 fail**：与 T02 无关（已装副本 inode 隔离，见 T01-SUMMARY）
2. **子 shell 漏拦 tradeoff**：`$(git commit)` / `(git commit)` —— ADR-008 split 不处理 `()`/`$()`，归 v2（DESIGN §6 R12 exotic：python-c/base64/变量间接）
3. **sudo git commit 漏拦**：sudo 是首 token —— ADR-008 Consequences R2 已记录
4. **NFR-1 性能**：T07 实测 for 循环引号感知 split 开销（gate.sh PreToolUse 每次调用）
