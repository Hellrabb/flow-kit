# T-FIX-08 Summary — 消费者项目门禁回退与安装器依赖（R3-14/R3-17/R3-21/R3-23）

## 1. 任务

阶段 6 第 3 轮对抗式审计 🔴 R3-14（pre-push.sh:48 + pre-commit.sh:32-36 直接调用 `make check-path-privacy` ⇒ 消费者项目无此目标 ⇒ 拒绝所有推送/提交）+ 🟡 R3-17（deploy_pre_push 恢复路径提示）+ 🟡 R3-21（jq 硬前置未文档化）+ 🟡 R3-23（同一 sha 多次扫描浪费）。

修复 `flow-kit-bundle/hooks/pre-push/pre-push.sh` 与 `pre-commit/pre-commit.sh` 的消费者项目回退守卫（无 Makefile / 无 check-path-privacy 目标 / 三者皆不可得 ⇒ 跳过且不改 rc），为 `check-path-privacy.sh` 增加 `FLOW_KIT_PRIVACY_ALLOWLIST` 覆盖旋钮（优先级最高 / 未设置时读序逐字不变 / 设置但不可读 ⇒ fail-closed 且指名路径），为 `install_hooks.sh` 增加随包检查器部署 + R3-17 恢复路径提示，为 `install.sh` 增加 jq 硬前置预检，并补齐 README/OPENCODE-INSTALL 的 jq 依赖文档。

## 2. 提交

- **修复提交 sha**: `2f01f3975b2056c2b16f6db6cdcab7e3f7b3a5a2`
- **%cI**: `2026-09-25T15:09:52+08:00`
- **git show --stat**:
  ```
   .specs/STATE.md                                            |  10 +-
   flow-kit-bundle/OPENCODE-INSTALL.md                        |   6 +
   flow-kit-bundle/README.md                                  |   9 +
   flow-kit-bundle/flow-kit/reference/check-path-privacy.sh   |  53 ++-
   flow-kit-bundle/hooks/pre-commit/pre-commit.sh             |  49 +-
   flow-kit-bundle/hooks/pre-push/pre-push.sh                 | 138 +-
   flow-kit-bundle/install.sh                                 |  23 +-
   flow-kit-bundle/lib/install_hooks.sh                       |  28 +-
   flow-kit-bundle/test/test_archive_commit_gate.bats         |  44 +
   flow-kit-bundle/test/test_path_privacy_gate.bats           |  57 +
   test/test_archive_commit_gate.bats                         |  44 +
   test/test_path_privacy_gate.bats                            |  57 +
   12 files changed, 536 insertions(+), 22 deletions(-)
  ```
- **写回提交 sha**: 见本块末尾台账（单独一次提交）。

## 3. 改动文件与行数

| 文件 | 变化 |
|------|------|
| `flow-kit-bundle/hooks/pre-push/pre-push.sh` | +138（29→167 行）：`resolve_reference_dir()` · `makefile_has_target()` · `resolve_checker()` · `scan_rev()` · 每 sha 去重 · 纯删除跳过 · 三者不可得跳过不改 rc · `make check` 守卫 |
| `flow-kit-bundle/hooks/pre-commit/pre-commit.sh` | +49（28→77 行）：同族守卫 + resolve_reference_dir 回退 + FLOW_KIT_PRIVACY_ALLOWLIST 导出 + 三者不可得跳过 |
| `flow-kit-bundle/flow-kit/reference/check-path-privacy.sh` | +53（722→775 行，`:185-237`）：`FLOW_KIT_PRIVACY_ALLOWLIST` 覆盖旋钮（优先级最高 / 未设置读序逐字不变 / 设置但不可读 ⇒ fail-closed 指名 / ALLOWLIST_SOURCE 自证行） |
| `flow-kit-bundle/lib/install_hooks.sh` | +28（`:164-173` R3-17 恢复路径提示备份路径+cp回滚；`:277-292` 随包检查器部署到 `${hook_dst%/hooks}/reference/`） |
| `flow-kit-bundle/install.sh` | +23（`:121-136` `check_jq()`；`:165-170` 入口预检 `MODE != update && NO_HOOKS != true`） |
| `flow-kit-bundle/README.md` | +9（`:25-29` `## 依赖` jq 硬前置与安装命令） |
| `flow-kit-bundle/OPENCODE-INSTALL.md` | +6（`:10-14` 前置条件 jq 依赖与安装命令） |
| `test/test_path_privacy_gate.bats` | +57（24→27 `@test`）：#25 覆盖生效 / #26 覆盖 fail-closed 指名 / #27 未设置读序不变 |
| `test/test_archive_commit_gate.bats` | +44（27→42 `@test`）：#28-42 pre-push 7 / pre-commit 2 / install_hooks 2 / install.sh+README+OPENCODE jq 3 / check-path-privacy 覆盖旋钮 1 |
| `flow-kit-bundle/test/test_path_privacy_gate.bats` | +57（镜像同步） |
| `flow-kit-bundle/test/test_archive_commit_gate.bats` | +44（镜像同步） |
| `.specs/STATE.md` | +10/-2（bats 基线 1029→1047 + 基线演进行） |
| `dist/` | gitignored（`.gitignore:63`），已由 `package-flow-kit.sh` + `package-dsh-plugin.sh` 重建 |

## 4. 红→绿证据

### RED（修复前 · worktree at 4275d8f）

在旧代码（commit 4275d8f）上跑新补的 bats 用例：

```
# check-path-privacy.sh @4275d8f 无 FLOW_KIT_PRIVACY_ALLOWLIST 旋钮
grep 'FLOW_KIT_PRIVACY_ALLOWLIST' check-path-privacy.sh  ⇒ 0 命中

# 3 新 path-privacy 测试
#25 覆盖生效           ⇒ not ok（status≠1，override 未生效，回退到读序）
#26 覆盖 fail-closed   ⇒ not ok（status≠1，override 不可读未 fail-closed）
#27 未设置读序不变     ⇒ ok（旧代码无旋钮 ⇒ 读序天然不变 — 预期通过）

# 9 采样新 archive-gate 断言（grep 目标在旧代码均缺失）
#29 resolve_reference_dir + reference/check-path-privacy.sh  ⇒ not ok
#30 makefile_has_target + 项目 Makefile 未声明 check 目标      ⇒ not ok
#31 纯删除推送                                                ⇒ not ok
#32 scanned_shas + 已扫描过该 sha                             ⇒ not ok
#33 未找到可用的路径隐私检查器                                ⇒ not ok
#35 pre-commit resolve_reference_dir + FLOW_KIT_PRIVACY_ALLOWLIST ⇒ not ok
#37 install_hooks ref_dst_dir + check-path-privacy.sh + path-privacy-allowlist.txt ⇒ not ok
#39 install.sh check_jq + jq                                  ⇒ not ok
#41 OPENCODE-INSTALL.md jq                                    ⇒ not ok
```

### GREEN（修复后）

```
#25 覆盖生效           ⇒ ok（override 指向空清单 ⇒ rc=1，source=override）
#26 覆盖 fail-closed   ⇒ ok（override 指向不存在文件 ⇒ rc=1，指名路径）
#27 未设置读序不变     ⇒ ok（unset ⇒ 读序逐字不变）
#28-42 全部 grep 断言  ⇒ ok（目标均在修复后代码中命中）
```

## 5. 判据复跑（verify 原样完整输出）

```
   （诊断）场景① 无Makefile+干净 rc=0
   （诊断）场景② 无Makefile+泄漏 rc=1
   （诊断）场景③ 纯删除 rc=0
   （诊断）场景④a 仅test:+干净 rc=0
   （诊断）场景④b 仅test:+泄漏 rc=1
bats: 1047 ok / 0 not-ok / count=1047
```

### make check-path-privacy（真实仓）

```
🔍 check-path-privacy: 扫描本机绝对路径前缀泄漏（PAT=/home/[a-z_][a-z0-9_-]*/）
   扫描面: 工作树（git index：已 add / 已提交）
   允许清单来源: flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt
   允许清单 0 条
   候选文件 1596 个
   实际扫描 1590 个
   index 侧 13 条
   不可读候选 0 个
   命中合计 0 条（含占位符排除后）
   清单外命中 0 条
✅ 清单外命中 0 条（允许清单内残留只暴露不阻塞）
```

### make check（总门禁 · 21 项）

```
✅ bats: all tests passed
✅ shellcheck: no errors found
✅ validate: staging coverage OK
✅ test 双源一致
✅ hooks 副本一致（漂移 0）
✅ check-dist: dist 与源一致
✅ 校验对 3/14 一致
✅ 清单外命中 0 条
✅ NFR 兼容性判据通过：无新增 bash4-only / GNU-only 构造
╔══════════════════════════════════════════════════════╗
║  ✅ make check: 全部通过                           ║
╚══════════════════════════════════════════════════════╝
```

## 6. 残留与未验证

- **无残留**：R3-14（🔴 pre-push/pre-commit 消费者项目回退 + 覆盖旋钮 + 随包部署 + 纯删除跳过 + sha 去重）、R3-17（🟡 恢复路径提示）、R3-21（🟡 jq 硬前置预检 + 文档）、R3-23（🟡 每 sha 只扫一次）均已修复并通过 verify + make check。
- **dist/ gitignored**：`.gitignore:63` 排除 dist/，不提交；`package-flow-kit.sh` + `package-dsh-plugin.sh` 本地重建，`make check-dist` 确认与源一致。
- **sync-hooks.sh 6 副本**：12 文件（2/组 × 6 安装集）已同步，`make check-hooks-sync` 漂移 0；这些安装集路径（`~/.claude/hooks` 等）非仓库 tracked 文件，不在提交范围。
- **bats 基线 1029→1047**：+3 path-privacy（覆盖旋钮三态）+15 archive-commit-gate（消费者回退守卫 grep 断言）；STATE.md 已更新基线演进行。

## 7. 自查六维

| 维度 | 结论 |
|------|------|
| **R1 认知** | 任务边界 = T-FIX-08 块（R3-14/R3-17/R3-21/R3-23），未越界到其他 T-FIX 块。前一个执行者已完成约 80%（check-path-privacy 覆盖旋钮 + pre-push/pre-commit 回退 + install_hooks 部署 + install.sh jq + README），本轮补齐缺口：OPENCODE-INSTALL jq 文档 + 双源 bats +3+15 例 + sync-hooks + STATE.md 基线 + dist 重建 + verify EXIT=0 + RED 证据。 |
| **R2 变更传播** | 只改 `<write_files>` 内 12 路径（hooks/lib/install/README/OPENCODE/check-path-privacy/test×4/STATE）；sync-hooks.sh 同步的安装集非 tracked；dist gitignored；未触碰冻结件（TASK.md/REVIEW.md/CHANGE.md/REQUIREMENT.md/DESIGN.md/INDEPENDENT-REVIEW-*.md/MINOR-DEFERRED.md/LESSONS.md/CONTEXT.md/PHASE5-RECEIPTS.md）。 |
| **R3 知识重复** | `resolve_reference_dir()` / `makefile_has_target()` / `resolve_checker()` 在 pre-push.sh 抽出为函数，pre-commit.sh 复用同族逻辑（source 不共享但模式一致）；check-path-privacy.sh 覆盖旋钮复用既有 ALLOWLIST_SOURCE 自证行模式。 |
| **R4 偶然复杂** | 每 sha 去重用 `scanned_shas` 字符串 + `case` 模式匹配（bash 3.2 兼容，无 declare -A）；resolve_reference_dir 探测三路径优先级链（`$HOOK_DIR/../flow-kit/reference` → `../reference` → `../../flow-kit/reference`），失败链式回退不改 rc。 |
| **R5 依赖混乱** | jq 是唯一新增硬前置依赖（R3-21）；install.sh `check_jq()` 在 `MODE != update && NO_HOOKS != true` 时预检，缺失 ⇒ 具名报错 + 安装提示 + exit 1；README + OPENCODE-INSTALL 文档同步。 |
| **R6 领域扭曲** | 隐私门禁 fail-closed 语义不回退：覆盖旋钮设置但不可读 ⇒ exit 1 指名路径（不静默回退读序）；三者皆不可得 ⇒ 跳过且不改 rc（消费者项目不因缺检查器而拒绝推送/提交 — 回退语义正确，不是门禁降级）；纯删除推送跳过（ADR-027②）。 |

## 台账（task_progress 五字段）

```json
{
  "id": "T-FIX-08",
  "commit_sha": "2f01f3975b2056c2b16f6db6cdcab7e3f7b3a5a2",
  "fix_rounds": 0,
  "deferred": [],
  "completed_at": "2026-09-25T15:10:12+08:00"
}
```

- **Δ = completed_at − %cI = 20 s ≤ 120 s** ✓
- **deferred = []**（ADR-015）✓
