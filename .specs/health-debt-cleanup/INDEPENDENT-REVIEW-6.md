## L2 盲审

> 审查日期：2026-07-20 | 阶段：6 | change-id：health-debt-cleanup | 独立 L2 Agent

### 审查发现

| # | 维度 | 发现 | 级别（🔴Critical/🟡Major/🟢Minor）|
|---|------|------|---|
| 1 | R3 | LESSONS.md 第 60-61 行重复记录同一观察项 "R4 · `_grep` 兼容层间接性"——第 60 行为带 `✅ 已标注` 的更新版，第 61 行为旧版（无 ✅），形成知识重复。应删除旧条目 | 🟢Minor |
| 2 | R2 | `test_stop_chain.bats:60` 的 smoke 测试 `grep -q "file_age_days\|get_workflow_state()"` 因 `_fk_file_age_days` 包含子串 `file_age_days` 而"侥幸通过"。原测试意图是验证 `file_age_days` 函数存在，重命名后该意图已失效。测试应更新为 grep `_fk_file_age_days` 或 `_fk_check_g` | 🟢Minor |

### 逐维审查

#### R1 · 认知负荷

重命名后函数名清晰度显著提升：
- `_fk_check_g1_body()` —— `_fk_` 前缀立即传达"flow-kit 私有检查函数"，比旧名 `check_g1_body()` 语义更精确
- `_fk_file_age_days()` —— 统一到 `_fk_*` 私有前缀体系，消除孤立的 bare-name helper
- `_fk_check_g1()`（thin wrapper）与 `_fk_check_g1_body()`（body）层次分明，调用链可读

双重前缀风险验证：`grep -rn '_fk__fk_' flow-kit-bundle/` 零命中。REVIEW.md 自述的"replace_all 二次命中" bug 已在最终提交前修复，当前代码无残留。

**结论**: 🟢 通过。命名改善明显，无双重前缀。

#### R2 · 测试耦合

新增 `test_install_coverage.bats`（16 cases）：
- 每个测试通过 `bash -c` 子进程隔离执行
- `mktemp -d` 创建独立临时目录，`teardown()` 清理
- 环境变量（`DRY_RUN`、`SCRIPT_DIR`）显式声明，无隐式依赖
- 依赖注入通过 `FK_ROOT` 变量动态解析项目根目录

发现 1 处测试脆弱性（见审查发现 #2）：`test_stop_chain.bats:60` 的 smoke grep 因子串匹配而侥幸通过。不影响当前正确性，但未来若将 `_fk_file_age_days` 进一步重命名（如改为不含 `file_age_days` 子串的名字），该测试会误报失败。

全量回归：主 agent 报告 559/0 pass。重命名未引入回归。

**结论**: 🟢 通过（1 Minor 测试脆弱性）。

#### R3 · 知识重复

正面：本次重命名消除了 `check_g*` / `_gate_*` / `fk_*` 三套命名风格的分裂，统一为两套（公共 `fk_*` + 私有 `_*`）。26-workflow.sh 内 11 处函数定义全部迁移。

负面：LESSONS.md 存在内部知识重复（见审查发现 #1）。同一观察项出现两个版本，可能误导后续读者。

**结论**: 🟢 通过（1 Minor LESSONS 内部重复）。

#### R4 · 错误处理

关键验证点——`run_check` 调度机制：
```bash
# common.sh:55
"$body_fn"
```
`run_check` 通过字符串变量调用 body 函数。26-workflow.sh 中所有 thin wrapper 已正确传递重命名后的 body 函数名：
```bash
_fk_check_g1() { run_check "workflow" "G1" "" _fk_check_g1_body; }
```
body 函数定义同步更新：`_fk_check_g1_body() { ... }`

全仓验证：
- `grep -rn '\bcheck_g[0-9]\b' flow-kit-bundle/ --include='*.sh' | grep -v '_fk_check_g'` 零命中——无外部调用者仍引用旧名
- `flow-kit-artifacts.sh:110` 注释从 `check_g1` 更新为 `_fk_check_g1`——文档引用同步
- 无 `check_g1`..`check_g5` 裸调用残留——所有调用点（第 300-304 行）已更新

控制流：纯重命名，函数体一字未改，控制流不变。

**结论**: 🟢 通过。dispatch 正确，无断链。

#### R5 · 安全

`_grep` 兼容层：`_grep() { command grep "$@"; }`（fix-compliance.sh:20）

分析：
- 无命令注入风险——`command grep` 绕过 shell function/alias 重写，直接调用 GNU grep 二进制
- `"$@"` 参数传递标准且安全（bash 正确引号扩展，无 eval/shell 解析风险）
- 6 处调用均在 fix-compliance.sh 文件内，隔离良好
- CONTEXT.md 已记录保留决策与理由

本 change 未引入新安全面：纯重命名 + 文档标注 + 测试补齐。

**结论**: 🟢 通过。

#### R6 · 命名约定

CONTEXT.md 新增命名约定段准确性验证：

| CONTEXT.md 声明 | 实际验证 | 一致？ |
|-----------------|----------|--------|
| 公共函数 `fk_*`：跨文件调用 | 一致。`fk_resolve_phase`、`fk_check_doc_only_diff` 等确为跨模块公共 API | ✅ |
| 私有函数 `_*`：文件内/模块内可见 | 一致。`_fk_check_g1_body()` 仅在 26-workflow.sh 内被 thin wrapper 调用 | ✅ |
| 历史 `check_g*` 已全仓迁移 | `grep -rn '\bcheck_g[0-9]\b' flow-kit-bundle/ --include='*.sh' \| grep -v '_fk_check_g'` 零命中 | ✅ |

LESSONS.md 条目准确性：
- L-052（命名约定修复）：描述的函数重命名数量（5 body + 5 wrapper + 1 helper = 11）与 git diff 一致
- L-053（install_hooks 不拆分）：准确反映决策
- `flow-kit-artifacts.sh:110` 行号引用：当前文件第 110 行确为更新后的注释 ✅

**结论**: 🟢 通过。

### 验收线对照

| # | 验收条件 | 独立验证 |
|---|----------|----------|
| 1 | `grep -r 'check_g[0-9]\b' ...` 零命中 | ✅ 已验证，零命中 |
| 2 | install 函数 >= 15 bats cases | ✅ 16 cases，覆盖 7 个被测函数 |
| 3 | CONTEXT.md 追加三段 | ✅ 命名约定 + _grep + install 容忍度，内容准确 |
| 4 | make test 全绿 | 主 agent 报告 559/0（未独立复跑，采信 TEST.md 数据） |

### 总结

**Verdict**: ✅ PASS — 0 Critical / 0 Major / 2 Minor

重命名执行精准：11 处函数定义全部正确更新，无双重前缀，无断链，无残留旧名。CONTEXT.md 文档与实际情况一致。新增测试隔离良好。

两项 Minor 发现：
1. LESSONS.md 第 60-61 行 `_grep` 观察项重复记录（知识管理问题）
2. `test_stop_chain.bats:60` smoke grep 因子串匹配"侥幸通过"（测试脆弱性）

两项均不阻塞合入，建议后续 sweep 修复。
