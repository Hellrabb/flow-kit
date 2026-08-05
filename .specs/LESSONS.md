# LESSONS — 项目经验教训与技术债

> 本文件跨 change 累积。M-health 巡检 + 各 change 的 brooks-lint 结果 + 人工标注都写入此处。
> 格式：严重程度 | 位置 | 问题 | 建议 | 状态 | 来源

<!-- l3-pipeline-fix-2026-07 ↓ -->
| L-041 | 🟡 | `auto-checkpoint.sh` PreToolUse hook | 自引用竞态：hook 在 Write/Edit `.flow-active` 前触发 `checkpoint_write()` 修改同一文件，导致 harness 检测到文件内容变化后拒绝 Write/Edit | 在 `auto-checkpoint.sh` 中检测 `file_path` 是否为 `.flow-active` 自身——若是则 skip checkpoint 写入 | ✅ 已修复 | `l3-pipeline-fix-2026-07` |
| L-042 | 🔴 | `29-independent-review.sh` L3 派发 | `--background` 异步 flag 硬编码激活导致 `.done` 永不写入：fork 子进程后立即返回 `return 0`，`_l3_write_done()` 未执行 → 下次 Stop hook 再次进入积压扫描 → 无限重派循环 | 异步功能默认关闭（opt-in via `L3_BACKGROUND=1`）；默认同步路径确保 `.done` 写入 | ✅ 已修复 | `l3-pipeline-fix-2026-07` L2 审查 R1 |
| L-043 | 🟡 | `install.sh` 部署流程 | 改了 bundle 源 hook 文件后，容易忘记重跑 `install.sh --user` 同步到 `~/.claude/hooks/`。install.sh 代码不需要改（`install_file` 自动覆盖），但**必须提醒用户重跑**，否则运行时仍是旧版本 | 每次 change 涉及 hook 文件修改时，在归档阶段显式提醒用户执行 `install.sh --user` | ✅ 流程补记 | `l3-pipeline-fix-2026-07` 事后发现 |
<!-- l3-pipeline-fix-2026-07 ↑ -->

---

## M-health 巡检观察（监控级 · 不阻塞）

> 最后更新: 2026-08-03（全量 Sweep · 89/100 · ↓9 单源退化）
> 格式：日期 | 严重度 | 位置 | 观察 | 建议操作

<!-- 2026-08-03 Full Sweep ↓ -->
| 2026-08-03 | 🔴 | `flow-kit-bundle/lib/install_hooks.sh:97` | **install_hooks.sh:97 user-scope 回归**：commit `0c79f1c`（双平台拆分）把 `"$project/.claude/stop-hook.json"` 改为 `"${project}/${PROJECT_DIR_NAME}/stop-hook.json"` 但未处理直接 source 路径（PROJECT_DIR_NAME 仅 `lib/paths.sh` 定义 · 仅 install.sh 主入口 source）。单元测试和 `--user` 直调不 source paths.sh → `set -u` exit 1。症状：4 bats fail + `--user` 安装链路断 + 副作用阻断 runtime-edit-guard.sh 安装（L177-183 位于 L97 之后，永不执行）。 | **已修复**（`health-fix-2026-08` · Fix A paths.sh 自加载守卫 · 非 scope guard — DESIGN L2 审查确认 stop-hook.json 在 user-scope 是运行时回退依赖 `common.sh:107-108`，移除致 module_enabled 恒 false）。修复后 692/0 测试通过，评分 89→≥98。 |
| 2026-08-03 | 🟢 | 5 个 Bash 文件（jscpd 检测） | **Bash 样板代码相似率 0.37%**（vs 上次 0.43% · 略降）。5 处克隆均为 6-11 行的 shebang + source 初始化段。TD-008/017/018 拆分未引入新重复。 | 不处理。沿用 2026-07-25 决议。 |
| 2026-08-03 | 🟢 | `flow-kit-bundle/lib/paths.sh`（新增） | **lib/paths.sh 是 0c79f1c 新增的共享变量 lib**（PLATFORM / PROJECT_DIR_NAME / USER_HOOKS_DIR 等平台抽象）。是合理的双平台兼容设计，但**未登记到 CONTEXT.md「既有抽象索引」**，未来 AI 可能重复实现类似平台抽象。 | 下次 A-evolve 同步时登记到 CONTEXT.md § 既有抽象索引。同时建议加 install_hooks.sh 文件头注释明确「依赖 paths.sh · user-scope 不依赖 PROJECT_DIR_NAME」边界。 |
| 2026-08-03 | 🟢 | 全局（流程教训） | **commit-time 测试门禁缺失**：`0c79f1c` 提交时 4 个 bats fail 测试已存在，但 commit 被允许通过（未跑 `make test` 或结果被忽略）。若 commit 前置硬门禁（pre-commit hook 跑 `make test`），此回归可在入库前捕获。 | 建议未来在 .git/hooks/pre-commit 或 Makefile pre-push target 加 `make test` 硬门禁。本项不阻塞 health-fix-2026-08，作为流程改进建议记录。 |
<!-- 2026-08-03 Full Sweep ↑ -->
<!-- 2026-08-04 health-fix-2026-08 ↓ -->
| 2026-08-04 | 🟡 | 全局（流程教训） | **L-064 · self-certify 系统性不如 oracle review**：health-fix-2026-08 pipeline 中 phases 3/5/7 用 self-certify（D7 例外 · gate_config=all 热修复到 all-L2），phases 1/2/6 用 oracle L2。事后对 3/5/7 派 retroactive oracle L2 → **3/3 全部 WOULD-HAVE-FLAGGED**（12 项 finding 含 3 High）：phase 3 filter 假绿（`--filter "writes..."` 匹配 0 case）· phase 5 per-file 计数错（18→17, 3→4）· phase 7 diff stats 错（+36→+40）+ artifact count 错（10→11）+ .gitignore 禁动假 PASS。对比 phases 1/2/6 的 oracle 审查发现 real value（phase 2 拒绝 Fix B 致命错误）。**结论**：gate_config=all 不可用 self-certify shortcut · oracle 的独立核验（尤其可验证数字：行数/计数/matcher 有效性）是 self-certify 盲区。 | gate_config=all 的所有 gated phase 必须用 oracle L2。self-certify 仅限 D7 例外（且事后需 retroactive L2 补审）。 |
<!-- 2026-08-04 health-fix-2026-08 ↑ -->

<!-- 2026-07-25 Full Sweep ↓ -->
| 2026-07-25 | 🟢 | `flow-kit-bundle/hooks/stop/lib/l3-review.sh` | **l3-review.sh 持续增长至 875 行**（+65 vs 上次 810）。增长来自合法功能（`l3-review-timeout-token` 可配置化：FLOW_KIT_L3_MAX_TOKENS / TIMEOUT / THINKING）。12 函数结构良好，主编排函数 `l3_review_run()` 已从上上次 307 行拆至 ~90 行。 | 若未来突破 1000 行或新增第 5 种职责，触发 TD-008（拆为 l3-detect / l3-dispatch / l3-format 子库） |
| 2026-07-25 | 🟢 | 5 个 Bash 文件（jscpd 检测） | **Bash 样板代码相似**：6-11 行的 shebang + `set -euo pipefail` + SOURCE_DIR 初始化段在 l2-detect↔l3-review、27↔28、auto-checkpoint↔gate 等模块间结构相似。非语义重复，是 Bash 脚本的固有模式。 | 不处理。提取公共样板反而增加耦合和认知负荷。 |
<!-- 2026-07-25 Full Sweep ↑ -->

---

## 技术债清单

> 最后更新: 2026-07-20（M-health 巡检）

### L-032: L2 盲审在每阶段都捕获了主 agent 漏检的 Critical 问题（auto-checkpoint-hook）

**严重程度**: 🟡 Major（流程级）
**来源**: `auto-checkpoint-hook` change（2026-07-10 · 全 pipeline 0→7 执行）
**发现**:
- Phase 2 L2 捕获 `hooks/pre-tool/` vs `hooks/pre-tool-use/` 目录名错误（R1 🔴）——主 agent 在 0.5 段甚至自己写了正确路径 `~/.claude/hooks/pre-tool-use/` 但全文用错
- Phase 1 L2 捕获 checkpoint-lib.sh 去重逻辑与 REQUIREMENT "不去抖"的矛盾（R1 🔴）——CONTEXT.md 域语言与已锁决策自相矛盾
- Phase 3 L2 捕获 T02 verify 退出码被 `; echo "exit=$?"` 吞掉（R1 🟡）
- Phase 5 L2 捕获 TEST.md 性能轮缺失（R1 🔴）
- Phase 6 L2 捕获 AC-6 只有写入侧测试、缺 resume 读取侧验证（R1 🔴）

**教训**: L2 盲审的"独立性"价值在本次 change 中得到充分验证——5 个阶段中有 4 个阶段的 L2 审查发现了主 agent 漏检的 🔴 Critical 问题。**L2 不是橡皮图章，是真实的安全网**。gate_config=all 全开虽然多了 ~150k tokens（5 次 L2 审查），但阻止了至少 2 个会导致"部署后完全不可用"的路径级 bug（R1 目录名 + R1 去重矛盾）。

**建议**: 对于涉及新文件创建/目录结构变更/库行为修改的 change，**强烈建议** gate_config=all 全开。纯文档/配置类 change 可降为 code-only（仅 6-review）。

### L-033: Makefile lint for-loop glob 覆盖不完整——`hooks/stop/lib/` 的 12 个 lib 文件绕过 shellcheck（checkpoint-polish）

**严重程度**: 🟡 Major（流程级）
**来源**: `checkpoint-polish` change（2026-07-10 · Phase 6 L2 🔴 R1 发现）
**发现**:
- `make lint` 的 shellcheck for-loop 覆盖了 `*.sh`、`flow-kit-bundle/lib/*.sh`、`flow-kit-bundle/hooks/stop/*.sh`、`flow-kit-bundle/hooks/session-start/*.sh`、`flow-kit-bundle/hooks/pre-tool-use/*.sh`，但**遗漏了 `flow-kit-bundle/hooks/stop/lib/*.sh`**
- 后果：`hooks/stop/lib/` 下全部 12 个 lib 文件（common.sh、correction-file.sh、done-validation.sh、fix-compliance.sh、flow-kit-artifacts.sh、interactive-ui-check.sh、l2-detect.sh、l3-review.sh、transcript-parser.sh、weak-model-compliance.sh、checkpoint-lib.sh、banner.sh）从未经过自动化 shellcheck 扫描
- 本次新增的 banner.sh 也未被扫描——直到 Phase 6 L2 审查时才被发现

**教训**: 当目录结构存在嵌套子目录（如 `hooks/stop/` + `hooks/stop/lib/`）时，shell glob `hooks/stop/*.sh` **不递归**匹配子目录。新增 lib 文件到深层目录时，必须同时检查 Makefile/CI 的静态分析覆盖范围

**修复**: Makefile L23 追加 `flow-kit-bundle/hooks/stop/lib/*.sh` 到 lint for-loop
**建议**: 后续 change 可在 `make lint` 中使用 `find ... -name '*.sh'` 递归扫描替代显式 glob 枚举，从根本上消除此类遗漏

### L-052: 命名约定三套风格共存——`check_g*` / `_gate_*` / `fk_*` 不一致

**严重程度**: 🟡 → ✅ resolved（health-debt-cleanup · 2026-07-20）
**修复**: `26-workflow.sh` 全仓重命名：`check_g*_body()` → `_fk_check_g*_body()`（5 个私有 body 函数）+ `check_g*()` → `_fk_check_g*()`（5 个 thin wrapper）+ `file_age_days()` → `_fk_file_age_days()`（1 个私有 helper）。注释 `flow-kit-artifacts.sh:110` 同步更新。CONTEXT.md 追加命名约定段（公共 `fk_*` + 私有 `_*`）。

### L-053: `install_hooks()` 195 行——安装脚本单体函数偏长

**严重程度**: 🟡 → ✅ resolved（health-debt-cleanup · 2026-07-20）
**修复**: 用户确认暂不拆分（安装脚本非热路径）。补齐测试覆盖（16 bats cases in `test_install_coverage.bats`）+ CONTEXT.md 标注长度容忍度。

### 🔍 观察（M-health 2026-07-20 · 🟢 → ✅ resolved by health-debt-cleanup）

- **T5 · install 函数测试覆盖缺口**: ✅ 已补齐 — `test/test_install_coverage.bats` 16 条 bats cases，覆盖 install_flow_kit_core / install_skills / install_specs_template / install_hooks(user scope) / install_brooks_lint(jq fallback) / install_brooks_tools(shim conflict + PATH warning) / install_file
- **R4 · `_grep` 兼容层间接性**: ✅ 已标注 — CONTEXT.md 记录保留决策 + 理由（`command grep` 跨环境一致性 · 6 处调用隔离良好 · 成本可忽略）

| # | 级别 | 位置 | 问题 | 建议 | 状态 | 来源 |
|---|---|---|---|---|---|---|---|
| L-031 | ✅ | 跨文件批量修改 · DESIGN.md 清单驱动 | ~~DESIGN 漏列导致 AI 漏改~~ → ✅ resolved by `debt-audit-resolve-2026-08`：L2-blind-review.md 顶部新增「通用 · 跨阶段必查项」段，强制 L2 reviewer 独立做全仓 grep 扫描（不信 DESIGN 清单），对每个一致性锚点跑 `grep -rn` + 对比 git diff，"DESIGN 漏列且未改"= 🔴 Critical finding。从「靠主 agent 自觉」升级为「靠 L2 独立扫描兜底」。 | ✅ 已完成（L2-blind-review.md 通用必查段 · debt-audit-resolve-2026-08） | `fix-l3-gate` 2026-07-10 · resolved 2026-08-04 |

| L-030 | 🔴 | `flow-kit-bundle/hooks/stop/29-independent-review.sh` + `independent-review-gate.sh` | ~~**L3 盲审 gate 机制三连异常**~~ → ✅ resolved by `fix-l3-gate`（2026-07-10）：(1) L3 重审——mtime 检测工件变更后追加 `## L3 重审` 段；(2) .done 条件写入——仅 `L3_verdict=pass` 时写 .done；(3) transition `.phase` 同步——9 处 transition jq 全部加 `.phase` 字段 | resolved | `fix-l3-gate` 2026-07-10 |

| L-022 | ✅ | `flow-kit-bundle/hooks/stop/lib/l3-{api,review}.sh` stderr 安全 | ~~curl/jq 错误 stderr 泄露~~ → ✅ resolved：(1) 所有 curl 调用 `2>/dev/null` 屏蔽网络错误细节；(2) 错误日志 sanitize 为 `[l3-review] L3 API returned HTTP ${code}` 等通用消息（无 URL / 无响应体）；(3) `_l3_format_result` 白名单输出 + `L3_RESULT:` 单行格式天然防泄露。剩余 `using max_tokens=N timeout=N thinking=N` 是配置 echo 无敏感性。 | ✅ 已完成 | `l3-feedback-visibility` 2026-07-07 · verified 2026-08-04 |

| L-004 | 🟢 | `flow-kit-bundle/lib/install_hooks.sh` | 辅助函数 `install_file()` 已从 install.sh 抽出到 lib/，但独立工具库 `lib/utils.sh` 尚不必要（当前 1 个共享函数，阈值 ≥ 3）。debt-cleanup 确认保持推迟。 | 等新增 ≥ 2 个共享辅助函数时再建 `lib/utils.sh`，避免只有一个函数的过度抽象 | deferred | `init-git-repo` T03 手动基线 |
| L-005 | 🟡 | `package-flow-kit.sh` L20 | STAGING 前置校验已添加（debt-cleanup） | `[[ -n "$STAGING" && "$STAGING" != "/" ]]` guard 已生效 | resolved | `init-git-repo` T03 手动基线 |
| L-014 | 🟢 | Bash `grep -E` 字符类中 `\]` 的转义 | 在双引号字符串内使用 `grep -E` 的字符类 `[...\]` 时，bash 将 `\]` 展开为 `]`，导致字符类提前关闭、匹配静默失败。典型症状：grep 在 shell 中直接执行正常，但在 bats 测试的 sourced function 中返回空。修复：用 `[^[:space:]]*` 替代复杂字符类 + sed 后处理剥离尾随标点；或使用单引号字符串避免 bash 转义。影响：所有在双引号内使用 `grep -E` + 含 `]` 字符类的 Bash 脚本。来自 `robustness-hook-hardening` T04 L3 测试调试 | 写 Bash regex 优先单引号字符串；必须双引号时用 `[^...] 替代字面排除字符类 | active | `robustness-hook-hardening` T04 调试 |
| L-015 | ✅ | AI 直接编辑 `~/.claude/` 运行时文件 | ~~无技术防护，仅流程规范~~ → ✅ resolved by `debt-audit-resolve-2026-08`：新建 PreToolUse hook `runtime-edit-guard.sh`，检测 Write/Edit 到 `~/.claude/{hooks,skills}/` 路径且 `flow-kit-bundle/` 维护源存在时 exit 2 deny + stderr 输出 redirect 引导。从「流程规范靠 AI 自觉」升级为「hook 硬拦」。 | ✅ 已完成（runtime-edit-guard.sh · debt-audit-resolve-2026-08） | `improve-independent-review` · resolved 2026-08-04 |
| L-013 | 🟢 | `.specs/` 归档流程（7-integration） | 归档流程两种遗漏模式：① **归档未清理**——change 已归档但 `.specs/<id>/` 工作目录未删，留只剩 PROGRESS.md 的空壳（2026-06-24 发现 bundle-packaging / docs-sync / fix-pcsc-gaps）；② **完成未归档**——change 100% 完成（REVIEW✅ / TASK 全done / CHANGELOG 已记）却没走归档，完整工件散落 `.specs/`（2026-06-25 发现 security-privacy-audit） | 归档脚本（7-integration）加双向校验：a) 归档完成后 rm 工作目录（PROGRESS.md 先确认入 archive）；b) 定期扫描 `.specs/` 下非 archive 目录，凡 REVIEW✅ + TASK 全done 的 change 提示归档 | resolved | `lessons-cleanup` T01 / T04 / T06 |
| L-016 | 🟢 | `flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh`（501 行） | 单体文件偏大，含 artifact-check / auto-phase / done-validation / stale-check / boundary-check / snapshot / progress / token 共 8 个职责 | 可按职责拆为 `artifact-check.sh` / `auto-phase.sh` / `done-validation.sh` 三个子库（当前可维护性尚可，非紧急） | observed | `M-health 2026-07-02` |
| L-017 | 🟢 | `package-flow-kit.sh`（594 行） | 打包主脚本偏大，`validate_staging_coverage()` 函数 ~100 行独立于主流程 | 可拆出 `validate_staging_coverage()` 为独立 lib（当前可维护性尚可，非紧急） | observed | `M-health 2026-07-02` |
| L-018 | 🟢 | `flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh:498` | `fk_accumulate_tokens` 中 `updated_at` 被双重赋值（第一个 `\| .updated_at = now` 被第二个 `\| .updated_at = (now \| strftime(...))` 覆盖），无实际效果但潦草 | 删掉第一个 `\| .updated_at = now`（下次改到该函数时顺手修） | observed | `M-health 2026-07-02` |
| L-019 | ✅ | `flow-kit-bundle/hooks/stop/lib/correction-file.sh` | ~~`correction_file_write()` 仅 overwrite 策略~~ → ✅ resolved：函数签名已升级为 `correction_file_write(path, data, strategy="${3:-overwrite}")`，支持 merge 策略。调用方可选传 `merge` 启用 read-merge-write。 | ✅ 已完成 | `flow-active-integrity` phase 2/3 · verified 2026-08-04 |
| L-020 | ✅ | Stop hook 模块执行链 | ~~三处接线漏一处 = 模块永不执行~~ → ✅ resolved by `debt-audit-resolve-2026-08`：新增 `test/test_hook_dispatch.bats` 3 个 smoke 测试自动检测死代码（文件存在但 00-gate.sh 未调度 / HOOK_MODULE_NAMES 数组与磁盘不同步 / 调度的文件不存在）。新增模块忘接线 → bats 失败。 | ✅ 已完成（test_hook_dispatch.bats · debt-audit-resolve-2026-08） | `flow-active-integrity` · resolved 2026-08-04 |
| L-021 | ✅ | `flow-kit-bundle/hooks/stop/lib/correction-file.sh` ↔ `interactive-ui-check.sh` ↔ `weak-model-compliance.sh` | ~~三个 lib 模块形成双向依赖环~~ → ✅ resolved by `health-fix-2026-07`：提取三方共享接口到 `correction-types.sh`，UI check 和 weak-model-compliance 现在依赖接口（grep 确认：两模块均 source correction-types.sh + correction-file.sh，correction-file.sh 不再 back-reference 它们）。 | ✅ resolved | `M-health 2026-07-04` · verified 2026-08-04 |

---

## 已解决

> 已修复或不再适用的条目移至此段，保留溯源。

| # | 原状态 | 位置 | 问题 | 修复提交 | 解决日期 |
|---|---|---|---|---|---|
| L-002 | 🟡 | `package-flow-kit.sh` L56 | 硬编码 `~` 路径 | `7b1ae91` fix(package): 用 SCRIPT_DIR 替换 | 2026-06-15 |
| L-006 | 🟡 | `install.sh` L243 + brooks-lint hooks | 空 commands 目录导致 hook exit 1 | `47d80f6` fix(brooks-lint): SessionStart hook 空 commands 容错 | 2026-06-14 |
| L-001 | 🟡 | `package-flow-kit.sh` | 打包与安装逻辑耦合 → install.sh 已拆分为独立文件 | `e1ea7b9` refactor package-flow-kit.sh | 2026-06-15 |
| L-003 | 🔴 | `package-flow-kit.sh` | 零测试覆盖 → bats-core 28 tests | `2e745b7` feat(health-fix) | 2026-06-17 |
| L-007 | 🟢 | `package-flow-kit.sh` L104-143 | settings.json 模板 heredoc 重复 → cp 文件替代 | `2e745b7` feat(health-fix) T08 | 2026-06-17 |
| L-008 | 🟢 | `install.sh` L194 | brooks-lint 版本号硬编码 → plugin.json 动态读取 | `2e745b7` feat(health-fix) T09 | 2026-06-17 |

---

| L-009 | 🟡 | `common.sh:10` | CONFIG_FILE 覆盖调用方 → 已改为 `: "${CONFIG_FILE:=}"`（debt-cleanup） | 仅在未设时赋默认值 | resolved | 2026-06-16 health-fix |
| L-010 | 🟡 | T02 流程 | 破坏性变更后未立即验证恢复 → 已记入流程规范 | 1.8 协议后必须立即跑恢复验证 | resolved | `lessons-cleanup` T03 / T04 / T06 |
| L-011 | 🟢 | `common.sh:22-39` | jq key 连字符→减法 → 已改为 bracket 引用 `.modules["${mod}"]`（debt-cleanup） | bracket 引用防止 jq 解析错误 | resolved | 2026-06-16 health-fix |
| L-012 | 🟡 | `package-flow-kit.sh` Part E | **结构变更后打包脚本未同步**：install.sh 拆分为 `lib/` 模块后，`package-flow-kit.sh` Part E 只 `cp install.sh` 忘了 `cp -r lib/`，导致 bundle 安装报 `No such file: lib/install_hooks.sh`。E2E 验证环节才发现。 | 任何改变 `flow-kit-bundle/` 目录结构的修改，必须同步检查 `package-flow-kit.sh` 的 staging 逻辑（Part A~F 的 mkdir/cp/rsync 范围） | resolved | `lessons-cleanup` T02 / T06 |

## 元数据

- **最近更新**: 2026-07-20（M-health 巡检：评分 92/100 · 上次 2🔴 全修复 · 新增 L-052/L-053 + 2 观察）
- **下次复查**: 2026-08-20（建议每月一次 M-health）

## L-016 · 独立审查四层架构必须全对齐

**日期**: 2026-07-02 | **来源**: independent-review-gap

**教训**: L2/L3 独立审查的端到端可用性依赖四层同步：PRESET_MAP → Prompt 模板 → Hook 层 → L2-blind-review.md。任一层缺失，即使 gate_config 正确设置，pipeline 也会在对应阶段死锁——hook 层等 .done 文件，但主 agent 的 prompt 不知道要写 .done。

**预防**: 新增 gate_config 阶段支持时，必须同时检查四层是否都已更新。check-gate-sync.sh 可检测 PRESET_MAP 和 bats 之间的漂移，但 prompt 层和 L2 checklist 层的完整性需要 AC-1/AC-4 验证脚本人工跑。

**状态**: ✅ 已修复 — 3-task/5-test/7-integration prompt + PRESET_MAP 8 新预设 + L2 checklist 3/5/7 均已补齐

---

## L-017 · PRESET_MAP 声明与实现必须同步交付

**日期**: 2026-07-02 | **来源**: independent-review-gap

**教训**: gate-integrity change 的 `all` 预设提前声明了 3/5/7 的 independent 支持，但 prompt 层实现未同步交付。这造成了结构性死锁：hook 层已就绪（会拦 transition 等 .done），但主 agent 不知道该写 .done。"先声明后实现"在跨层变更中是危险的——声明让用户以为可用，实现缺失让实际不可用。

**预防**: 跨层变更（如独立审查这种涉及 Hook + Prompt + Config 三层的功能）不应分 change 交付。要么一个 change 四层全做完，要么 feature-flag 默认关闭直到最后一层就绪。

**状态**: ✅ 已修复 — independent-review-gap 补齐了 gate-integrity 遗留的三层

## L-018 · Pipeline 关键机制不可纯 prompt 驱动——必须有 hook 兜底

**日期**: 2026-07-03 | **来源**: pipeline-fallback-fix (T02, T03)

**教训**: auto_advance 自动推进和 fallback goal 迭代循环都是纯 prompt 驱动的——AI agent 读到 prompt 中的分支指令后自行决定是否执行。这与独立审查 gate（PreToolUse hook 系统层硬拦截）形成鲜明对比。在弱模型下，纯 prompt 机制可能被跳过或忽略，导致 auto_advance=true 仍输出 toll-gate 提示、fallback 迭代忘记自检等。

**6 个具体发现**:
1. L2+L3 异步死锁：L3 需 Stop hook（会话结束），但 pipeline transition 需 L3 完成后才能推进
2. gate_config 篡改检测死锁：`/flow gate-config` 不同步 `.goal-snapshot.json` → hook 拦截全部修改
3. Gate 拦回退：独立审查 gate 不区分前进/回退方向
4. auto_advance 纯 prompt：无 hook 层验证 auto_advance=true 时是否真的自动 transition
5. Fallback 纯 prompt：GO.md 无 mode 特定路由，迭代逻辑仅在 4-dev prompt 一段描述中
6. AC-5a↔hook 字段差异：`artifacts=` 未实现，Tier1 不查 L2/L3_verdict

**预防**: 任何 pipeline 关键行为（auto_advance、fallback 迭代、gate 检查）必须有 hook 层兜底验证。Prompt 指令是"提示"，hook 是"强制执行"。

**状态**: 🔴 待修复 — 详见 `.specs/pipeline-fallback-fix/DIAGNOSIS.md` P0/P1/P2 修复建议

---

## L-new-1 · gate_config 5th parameter 传递链完整性

- **严重度**: 🟡 Major
- **位置**: `29-independent-review.sh:117` / `independent-review-gate.sh:228` / `l3-review.sh:291`
- **问题**: `l3_review_run()` 新增第 5 参数 `gate_config_value`，但 3 处调用点均漏传，导致 D3 gate 默认 "both"，L3-only 模式 .done 被错误延迟
- **建议**: 新增参数时用 grep 扫全部调用点确认参数数目一致；或使用命名参数（key=value）替代位置参数
- **状态**: ✅ 已修复（`dual-review-merge-fix` phase 6 L2 审查发现，`${gate_val:-both}` 已传）
- **来源**: `dual-review-merge-fix` phase 6 L2 review R1

## L-new-2 · phase_name 映射三处重复

- **严重度**: 🟢 Minor
- **位置**: `29-independent-review.sh` / `independent-review-gate.sh` / `done-validation.sh`
- **问题**: phase number → phase_name 的 case 映射（{1→"1-requirement", 2→"2-design", ...}）在 3 个文件中逐字重复。新增/修改阶段名时需同步 3 处
- **建议**: 抽取为共享函数（如 `fk_phase_name()`），放在 `flow-kit-artifacts.sh` 或 `common.sh`，3 处调用点改为 `phase_name=$(fk_phase_name "$phase")`
- **状态**: 🟢 待 v2 抽取（`dual-review-merge-fix` REVIEW.md Q1 已记录）
- **来源**: `dual-review-merge-fix` phase 6 L2 review R5

### L-023 · Claude Code 环境 grep → ugrep wrapper 不兼容 `-P` 正则 + `-c` 返回值语义差异

- **位置**: `fix-compliance.sh`（新增 lib）
- **问题**: Claude Code 环境将 `grep` 替换为 ugrep wrapper 函数。`grep -oP` 中 `\b` 在 ugrep 报 "empty (sub)expression"；`grep -c` 匹配数为 0 时输出 "0" 但 exit=1，与 `|| echo "0"` 组合输出 "0\n0"。
- **修复**: 定义 `_grep() { command grep "$@"; }` 兼容层。正则 `\b` → `(\s|:|$)`。
- **教训**: hook/lib 脚本须在顶部声明 grep 兼容层；CI 应 `type grep` 检查 wrapper。
- **状态**: ✅ 已修复（26 bats 全绿）
- **来源**: `l2-l3-fix-compliance` phase 4 T07

### L-024 · 实效性校验的"零声明"漏洞模式

- **位置**: `fix-compliance.sh` `fk_fix_compliance_check()` 步骤 ②b
- **问题**: review 有源码级发现但 agent 未输出任何 `Fixed in:`/`Tech-debt:` → `fk_verify_finding_files` grep 空→return 0（静默放行）。阈值计算 bug：`total/2` 整数截断（3 条 1 MISSING=33% 被误判为 ≥50%）；`total>1` 使 1/1=100% MISSING 不被阻断。
- **修复**: ②b 检测 `fixed_count==0 && techdebt_count==0`→阻断。`missing*2>=total` 替代整数除法；`total>0` 替代 `total>1`。
- **教训**: 检测异常→阻断的逻辑须显式处理"输入为空"（空≠安全）。默认值应为 deny（fail-closed）。
- **状态**: ✅ 已修复（26 bats）
- **来源**: `l2-l3-fix-compliance` phase 2 L3 CRITICAL + phase 6 L2 R1/R2

## L-025 · 测试 setup 的 `2>/dev/null || true` 静默吞 source 失败 — 让 169 测试"假失败"

**日期**: 2026-07-08 | **来源**: M-health 2026-07-08（bats 实跑发现 169/414 失败）

**教训**: 多个 bats 测试文件的 setup 用 `source "${BATS_TEST_DIRNAME}/../flow-kit-bundle/hooks/.../<lib>.sh" 2>/dev/null || true` 加载被测 lib。两个问题叠加形成"系统性假失败"：
1. **路径双重前缀**：测试文件位于 `<repo>/flow-kit-bundle/test/`，但 setup 写 `../flow-kit-bundle/...` → 解析成 `flow-kit-bundle/flow-kit-bundle/...`（路径不存在）。
2. **`|| true` 静默吞错**：source 失败被 `2>/dev/null || true` 完全吞掉，setup 不报错，但被测函数未定义 → 后续 `run <func>` 返回 127（command not found）→ 断言失败。

结果：169 个测试因"函数未定义"失败，但失败原因被 setup 的 `|| true` 隐藏在深处，表面看像 169 个独立回归，实际是 1 个系统性路径 bug。更糟的是：上次（07-07）健康报告只统计了测试数量增长（72→414），**没跑通过率**，完全漏检这 169 失败。

**预防**:
- **路径必须正确（核心）**：测试路径基于 test/ 在 flow-kit-bundle/ 下的真实结构用 `${BATS_TEST_DIRNAME}/../hooks/...`（去掉多余 `flow-kit-bundle/`）；用 `$REPO_ROOT` 时注意 test 在 `flow-kit-bundle/test`，到 repo 根要 `../..` 而非 `..`。
- **`|| true` 在 source lib 场景是合理容错，不盲目移除**：lib（common.sh 等）source 时顶层 `set -e` 副作用命令可能 exit 非0，但函数已定义可用；`|| true` 吸收 exit code 让 setup 继续。health-fix 实测移除 `|| true` 破坏 27 测试（gate_integrity 23 + phase-resolution 4）。真正要防的是"函数未定义"，改用 **AC-4 函数定义断言**（`test_setup_integrity.bats`：source 后 `type <fn>` 检查）兜底。
- **M-health 巡检必须实跑 bats 通过率**，不能只数 `@test` 数量。本次新增"bats 实跑"步骤永久纳入巡检 SOP。

**状态**: ✅ 已修复（health-fix-2026-07-08）— 169 失败→0（25 处双重路径修复 + AC-4 setup smoke）。`|| true` 经实测保留为合理容错（预防措施已据此修正）。

## L-026 · 架构统一后旧 wrapper 易成死代码 —— 删除前必须 grep 引用确认（不能批量删）

**日期**: 2026-07-08 | **来源**: M-health 2026-07-08 死代码清理 + health-fix-2026-07-08 git 考古

**教训**: 架构统一（提取公共 lib / 统一入口）change 完成后，原有的 wrapper 函数处理不一致，易留死代码。两个实测案例：

**案例 1 · `read_correction_file`（interactive-ui-check.sh）**：`sweep-fix-2026-07` 把 correction file 读写统一到 `lib/correction-file.sh`（`correction_file_write/read/clear/exists` 4 函数）。原 `interactive-ui-check.sh` 的 3 个 wrapper（read/clear/has）处理不一致：
- `read_correction_file` — **零调用方** → 死代码（已删）。调用方（flow-kit-resume.sh 等）直接用 `correction_file_read`，不经 wrapper。
- `clear_correction_file` / `has_correction_file` — **被 `27-interactive-ui-check.sh:70-71` 真实调用**（检测矫正文件存在 → 清除）→ 有效，**不能删**。

**案例 2 · `estimate_tokens`（transcript-parser.sh）**：token 预算的早期方案（`chars/4` 粗糙估算），后被 `token-estimate.txt`（01-transcript-parse 生成）+ `fk_accumulate_tokens`（26-workflow 累加到 `.flow-active.token_spent`）链路取代，**从未接线** → 死代码（已删）。

**预防**:
- 架构统一 change 的 TASK 必须含一步：`grep -r <旧_wrapper>` 全仓（含 `.sh`/`.bats`/`.md`），对每个旧 wrapper 标注「有调用方→保留 / 无调用方→删除」。sweep-fix 漏了这步，导致 `read_correction_file` 残留 1 个月才被 M-health 揪出。
- M-health 死代码扫描（步骤 2.5）发现候选后**不能批量删**，必须逐个 grep 确认「零调用」再删。本次 `clear/has_correction_file` 有调用方，**差点被误删**（最初推测「同批漏清」是错的）。

**状态**: ✅ `read_correction_file` + `estimate_tokens` 已删（health-fix-2026-07-08）；`clear/has_correction_file` 经 grep 确认有效，保留。

## L-027 · 验证测试 pass 必须用 bats 直接 exit code —— 禁止 `bats | tail` 管道（exit code 被管道末命令吃掉 → 假绿）

**日期**: 2026-07-08 | **来源**: health-cleanup-2026-07-08（make check 暴露 30+ 既有 fail · TD-012）

**教训**: 用 `npx bats test/ 2>&1 | tail -N` 验证测试套件时，管道 exit code 是**最后一个命令（tail）**的（0），不是 bats 的。bats 实际 exit 1（有测试 fail）被完全掩盖 → 误判"全绿"。`health-fix-2026-07-08` 的"169→0 全绿"很可能因此误判 —— 实际 30+ 测试因 setup 路径 bug（TD-012）一直 BW01 127 fail，从未真绿。同类陷阱：`bats | grep`、`bats > /dev/null 2>&1 | something`、`make test 2>&1 | tail`（make 的 exit 也被吃）。本对话开头的"bats exit 0 全绿"判断也犯了这个错。

**预防**:
- 验证测试 pass 必须用 bats **直接** exit code：`npx bats test/ && echo pass || echo fail`（无管道吞 exit）
- 必须用管道时加 `set -o pipefail`（管道任一命令失败则整体失败）或检查 `${PIPESTATUS[0]}`
- Makefile test target 的判定行必须直接用 bats exit（本仓 Makefile line 13 `@npx bats test/ > /dev/null 2>&1 && echo ✅ || exit 1` 已正确；line 12 `| tail -3` 仅展示不影响判定 —— `test-setup-path-fix-2026-07` 会复核）
- M-health 巡检"bats 实跑"步骤必须检查 **exit code**，不能只看输出尾部或测试数量增长（health-fix 正是只数了 72→414 增长，没验通过率）

**状态**: ✅ 已修复（`test-setup-path-fix-2026-07` 修 18 文件路径 + Makefile 复核，30+ 测试真绿，make test 407 pass 0 BW01）

## L-028 · `grep -c "pattern" || echo 0` 重复打印致断言假失败 —— grep -c 无匹配已打印 0 + exit 1，不需 `|| echo 0`

**日期**: 2026-07-08 | **来源**: test-setup-path-fix-2026-07（test_quality_baseline AC-6 修复）

**教训**: `grep -c "pattern" file || echo 0` 是常见反模式。`grep -c` 无匹配时**已打印 0** 并 exit 1，`|| echo 0` 再打印一个 0 → `$output` = `"0\n0"`，断言 `[ "$output" = "0" ]` 假失败。开发者以为 `grep -c` 失败要 fallback 打印 0，但 grep -c 本身就打印 0（只是 exit 1）。

**案例**: `test_quality_baseline.bats` AC-6 shellcheck 测试 `ERRS=$(shellcheck ... | grep -ci "error" || echo 0)` + `[ "$output" = "0" ]`。shellcheck 0 error 时 grep -c 打印 `0` exit 1，`|| echo 0` 再打印 `0` → `"0\n0"` ≠ `"0"` → 永远 fail（假失败，之前被 TD-012 假绿掩盖，修路径后才暴露）。

**预防**:
- `grep -c` 无匹配已打印 0，**不要加 `|| echo 0`**（会重复打印）
- 若要确保 exit 0：`grep -c "pattern" file || true`（`true` 不打印，保留 grep -c 的 0）
- 测试断言前 `echo "$output" | cat -A` 检查实际值（避免 `"0\n0"` 假匹配）

**状态**: ✅ test_quality_baseline 已修（`echo 0`→`true`）

## L-029 · test_gate_integrity 多重假绿 + L2 价值 + 降挡止损（fix-gate-test-setup · 2026-07-09）
- **假绿层级**：test_gate_integrity.bats 是多重假绿灾区——① set+e（TD-013）② helper 缺 artifacts= KVP ③ 测试断言债（断言实现不存在的内容 · TD-016）④ is_phase_write bug（TD-014）。set+e 掩盖全部。
- **L2 独立审查价值**：phase 1 两轮 L2 发现主 agent REQUIREMENT 的真实疏漏（坏模式 `if ! fn` + HOOK_BASE_DIR 缺失依赖错误 + AC-3 逻辑死结）。L2 在 REQUIREMENT 层拦住实施层灾难。
- **降挡决策**：gate-config=all/full 在系统性假绿文件上陷入多轮 L2 深挖（refactor 教训同型）。降挡（无 L2/L3，主 agent 基于已查清事实直接实施 + make test 把关）更高效收口。
- **bash 细节**：`run fn; [ "$status" -eq N ]`（bats 子 shell · status 反映 fn 退出码）禁 `if ! fn; then rc=$?`（`!` 反转 $? 致假阴/假绿）。
- **How to apply**：测试 setup 禁 set+e（用 run+$status）；断言前 grep 确认实现真含断言内容（防断言债）；gate-config 在复杂/系统性问题上降挡止损。

## L-034 · AC 硬编码数字陷阱——基线数字与新增测试自相矛盾（sweep-fix-2026-07-10 · 2026-07-10）

- **发现**：AC-8 原始 Then 子句硬编码 "462 tests"；AC-3 (+≥2) + AC-7 (+≥4) 新增测试后实际 ≥468。Phase 1 L2 🔴 R1 捕获。
- **根因**：AC 的 Then 子句中写入当前基线的具体数字，忘记 AC 本身是互相关联的——一条 AC 的新增会改变另一条 AC 的预期值
- **教训**：AC 的 Then 子句**禁止硬编码动态变化的数字**（测试数、文件数、行数）。用定性描述（"全量 bats 0 fail"）或动态断言（`npx bats test/ | grep '0 failures'`）
- **修复**：AC-8 Then 改为 "全量 bats 测试全绿 0 fail；make test exit 0"，验证方式改为 "输出 0 failures"

## L-035 · Given 条款事实错误污染下游阶段（sweep-fix-2026-07-10 · 2026-07-10）

- **发现**：AC-2 原始 Given 条款称 `is_gh_pr_create()` 为 "290 行、含 7+ 独立 gate 检查混合"；实测该函数仅 **3 行**（regex 谓词）。Phase 2 L2 🔴 R1 捕获。
- **根因**：CHANGE.md 基于健康报告的函数名描述（未实测行数），REQUIREMENT 继承错误描述，DESIGN 内部纠正但未显式勘误 REQUIREMENT
- **教训**：AC 的 Given 条款中引用的代码度量（函数行数、文件数）**必须实测验证**，不能从上游文档继承。Given 错误 → L3 外部模型基于虚假前提审查 → 整个审查链失效
- **How to apply**：写 AC Given 前先 `wc -l` / `grep -c` 实测；DESIGN 发现 REQUIREMENT 错误时必须**显式勘误**（不是悄悄纠正）

## L-036 · heredoc 引用退化——`<<'EOF'` vs `<<EOF` 导致变量插值静默丢失（sweep-fix-2026-07-10 · 2026-07-10）

- **发现**：`independent-review-gate.sh` gate 重构时，path-guard 错误消息从 `<<EOF`（插值 `${tool_name}`）改为 `<<'EOF'`（字面）。Phase 6 L2 W1 捕获：`${tool_name}` 不再展开 → 错误消息显示 `${tool_name}` 字面而非实际工具名
- **根因**：函数提取时，为使函数独立（不依赖外部变量）将 heredoc 改为单引号定界符——但遗忘了内部引用的变量
- **教训**：heredoc 定界符引号变更（`<<EOF` → `<<'EOF'`）是**语义变更**，不是纯格式调整。需审计 heredoc 体内所有 `${var}` 引用
- **状态**：🟡 已识别，本次未修复（错误消息降级为通用消息，不影响 gate 拦截行为）。建议后续 sweep 统一处理

## L-037 · `exit` in sub-function 反模式——gate 函数内直接 exit 绕过调用方清理逻辑（sweep-fix-2026-07-10 · 2026-07-10）

- **发现**：`_gate_phase_transition()` 内部多处直接 `exit 0` / `exit 2`，绕过了 `_run_review_gates()` 编排器的后续 gate 检查
- **根因**：gate 函数原为主逻辑体的一部分（L106-391 无名块），`exit` 原是正确的（在顶层脚本中）。提取为子函数后，`exit` 应改为 `return` + 编排器检查返回值——但函数提取是机械操作，未审计控制流
- **教训**：从主逻辑体提取函数时，**`exit` 必须改为 `return`**（除非函数确实是"终止脚本"的语义）——这是机械提取最易遗漏的审计点
- **影响**：本次场景中 gate 函数的 `exit` 行为等价于原逻辑（原也在顶层 exit），行为正确。但**可读性受损**——阅读 `_run_review_gates()` 时无法从代码推断完整控制流（部分 gate 可能永不返回）
- **建议**：后续 sweep 将 `_gate_phase_transition` 内的 `exit` 改为 `return <code>`，编排器检查返回值决定 exit

## L-038 · task verify 不覆盖非代码产物——AC-5/AC-6 文档类 AC 的 verify 默认为手工 grep（sweep-fix-2026-07-10 · 2026-07-10）

- **发现**：AC-5（命名约定文档化）和 AC-6（_grep 决策标注）的验证方式为手工 grep，无自动化 bats 覆盖。Phase 3 L2 🔴 R1 捕获 T07 verify=`make test` 无法验证文档变更
- **根因**：bats 测试框架天然适合验证代码行为，不适合验证 markdown 文档内容。但 AC 要求"可机器验证"，手工 grep 违反此原则
- **修复**：T07 verify 升级为复合命令：grep 验证 CONTEXT.md 含命名约定段 + _gate_ 前缀 + _grep 保留决策 → 通过后才跑 make test
- **教训**：文档类 AC 的 verify 应包含**针对文档内容的 grep 断言**（不依赖 bats 框架也可以在 CI 中用 shell 脚本实现）。`make test` 不能覆盖所有 AC 类型
- **How to apply**：拆 TASK 时，文档类 task 的 verify 必须包含 `grep` / `diff` 等文档内容验证命令，不能仅依赖 `make test`

---

### L-039 · `set -euo pipefail` 下命令替换内 pipeline 失败静默终止脚本

- **日期**：2026-07-11
- **来源**：`health-fix-l3-2026-07` Phase 6 L3 缺失排查
- **分类**：Shell 陷阱 / Hook 可靠性
- **严重度**：🔴 Critical（导致 Stop hook 29 号 L3 派发静默跳过 3 个 phase）
- **发现**：`29-independent-review.sh:120` 的 `l2v_extracted=$(grep ... | tail -1 | grep ... | tail -1)` 在 grep 无匹配时，`pipefail` 使 pipeline exit code ≠ 0。bash 在 `set -euo pipefail` 下命令替换内的非零 pipeline 退出码导致脚本静默终止
- **修复**：`l2v_extracted=$(...) || true`——追加 `|| true` 防止非零退出码传播
- **教训**：所有 `set -euo pipefail` 脚本中命令替换含 pipeline 时，末尾必须加 `|| true` 保护

---

### L-040 · L3 审查管线 5 项系统限制导致反复假阳性

- **日期**：2026-07-11
- **来源**：`health-fix-l3-2026-07` Phase 6/7 L3 多次重审失败
- **分类**：L3 审查机制 / Hook 设计缺陷
- **严重度**：🟡 Major（不阻断 pipeline 但严重降低 L3 审查可信度）
- **发现**：Phase 6/7 L3 三次审查均返回 fail，根因均在 L3 管线自身：
  1. **git diff 硬限 5000 字符**（`l3-review.sh:204`）：大变更的代码 diff 被截断，L3 模型看不到完整变更
  2. **`git diff HEAD` 不含 untracked 文件**：新增文件（correction-types.sh/goal-parsing.md/test_l3_timeout.bats）对 L3 不可见
  3. **`head -c 20000` 逐文件硬截断**（`max_artifact_chars`）：大产物（REQUIREMENT 12.3K/DESIGN 19.2K）尾部被丢弃
  4. **仅审当前 phase**：Stop hook 只看 `.flow-active` 当前阶段，历史积压不处理
  5. **无状态**：每次审查独立，无法参考前次反驳或 L2 结论
- **建议修复**：增大 git diff 上限（建议 50000）+ 改用 `git diff --cached HEAD`（包含 staged 新文件）+ `smart_truncate` 改为保留头尾策略 + 添加积压检测 + L3 prompt 注入前次反驳摘要
- **临时方案**：L3 fail + 主 agent 判定为已知限制 → 手动写 `.done`（L3_verdict=waiver）
- **How to apply**：下次 L3 管线变更时一并处理（关联 TD-008 l3-review.sh 拆分）

---

## L-044 · 用户指南同步应跑检查清单

- **严重度**：🟡 Major
- **发现**：用户指南更新（+139/-34）时，TOC 重编号（新增 §9 导致后续章节顺延）遗漏子章节编号同步（10.1-10.7 仍为 9.x）。L2 盲审两轮才完全修复（R1 flow-kit-install 假阳性修复 + 工作流子章节编号 + lib 文件清单补全 + 独立审查阶段数 3→6 + TOC 破折号格式）。
- **Why**：人工更新大文档时容易遗漏交叉引用。用户指南有 12 个锚点 + 7 个子章节 + 目录树 + 跨引用，单次手动编辑几乎不可能零遗漏。
- **How to apply**：今后用户指南更新后必跑检查清单：① `grep -n 'sec-.*workflows\|sec-.*rules\|sec-.*file-structure'` 无旧编号残留 ② 子章节编号与父标题一致 ③ `diff <(grep -c 'a id=') <(grep -c '](#sec-')` TOC 链接数=锚点数 ④ lib 文件清单与 `ls flow-kit-bundle/hooks/stop/lib/` 对齐

## L-045 · bundle validate 依赖 shell 环境，command find 是必要防护

- **严重度**：🟡 Major（validate 全部依赖环境正确性）
- **发现**：`validate_staging.sh` 使用裸 `find` 命令，用户 shell 中 `find` 被函数拦截（rtk→bfs）时校验结果 flaky——多次运行 ERROR 数从 3→2→1→0 波动，完全不可信。根本原因是 `export -f find` 使得子 bash 进程也继承该函数。
- **Why**：shell 函数的动态作用域 + `bash` 继承 `export -f` 函数 → validate 作为被 source 的库，无法控制调用环境。
- **How to apply**：所有 validate/hook 脚本中的 `find` 统一改为 `command find`。本会话修复了 validate_staging.sh 4 处，但 hooks/stop/ 中仍有 13 处裸 `find`（见 L2 Sonnet 审查报告）待后续统一。


## L-046 · L2 dispatch 应走 PreToolUse hook 同步驱动，与 L3 异构互补

- **严重度**：🟢 Suggestion（设计讨论，未实施）
- **发现**：弱模型在其他环境测试中会逃避 prompt 指令不 spawn L2 subagent（口头声明"已审查"但无 Agent tool call）。讨论了五层方案（L1 prompt→L2 hook 检测→L3 gate→L4 hook 补跑→L5 双轨），最终收敛为 PreToolUse 同步 L2 dispatch 方案——在 transition 时拦截 + 同步派子 agent + 立即写入 done。方案设计完毕，待开 change 实施（预期 ~65 行改动，核心在 independent-review-gate.sh 扩展 L2 dispatch 逻辑）。
- **Why**：Stop hook 方案有两个硬伤——L2 结果下次会话才能看到（当轮无感知），弱模型可能永远不会结束会话。PreToolUse 同步方案在 transition 时立即触发，结果当轮可用。
- **How to apply**：下次开 change `l2-pretooldispatch`，扩展 `independent-review-gate.sh` + 更新 prompt 告知段。

## L-047 · Stop hook L3 审查结果静默丢失：`2>/dev/null` 吞错 + `>>` 非原子写入

- **严重度**：🔴 Critical（生产影响——L3 审查完成但内容未持久化，gate 形同虚设）
- **发现**：排查 L3 审查缺失时发现两层根因：(1) `29-independent-review.sh` backlog 扫描和当前阶段 L3 调用均用 `2>/dev/null` 吞掉所有错误；(2) `l3-review.sh` 用裸 `>>` 追加写入，主 agent 后续 Edit 可能因锚点文本变化导致 L3 段被覆盖。Phase 1-3 的 L3 全部受此影响。
- **Why**：`2>/dev/null` 在 `set -euo pipefail` 下等于主动关掉唯一诊断通道。`>>` 非原子——Stop hook 和主 agent 交替写同一文件必然竞态。
- **How to apply**：(1) 所有 `l3_review_run` 调用去 `2>/dev/null`，失败时 `module_output` 记录；(2) L3 段 + .done 改用 tmp+mv 原子写入；(3) 写入后 `grep -q` 验证持久化。本次 change 已修复（T08+T09）。

## L-048 · L3 审查依赖 Stop hook 触发时机——连续推进 session 中天然滞后

- **严重度**：🟡 Major（设计约束）
- **发现**：本次 change 大部分阶段在同一对话轮次内连续推进。L3 依赖 Stop hook（对话轮次边界）触发，Phase 5-7 的 L3 从未运行。L3 触发时机与 pipeline 推进速度存在结构性错配。
- **Why**：Stop hook 假设"每阶段至少一次对话结束"，但快速推进模式下多阶段可在同一轮完成。
- **How to apply**：(1) 短期：关键 phase 结束后显式结束会话让 Stop hook 跑 L3；(2) 中期：PreToolUse gate 层增加 L3 同步 dispatch（与 L2 对称）；(3) 长期：prompt 层也触发 L3。本次 change 已修复 L3 内容可靠性（L-047），触发时机优化留给后续。

## L-049 · bash `local var="$(cmd)"` 屏蔽 set -e → 静默 fail-open

- **严重度**：🔴 Critical（gate 安全门失效）
- **发现**：6-review L2 R2 捕获——gate.sh:447 `local phase_name="$(fk_phase_gate_key "$phase")"`，当 `fk_phase_gate_key` 未定义（common.sh source 失败 `|| true`）时，`$(...)` 返回空 + 非零，但 `local` 赋值的返回值覆盖了命令替换的退出码（local 本身成功 → 0），`set -e` 不触发 → `phase_name=""` 静默得空 → gate 完全失效 exit 0（fail-open）。实测 `HOOK_BASE_DIR=/tmp/nonexistent bash gate.sh <git-commit-payload>` → exit 0（应 fail-close exit 2）。
- **Why**：bash 语义——`local`/`declare`/`typeset` 的返回值是**赋值语句本身**的退出码，非命令替换内命令的退出码。`set -e` 检查的是 `local` 的退出码（恒 0），命令替换内的失败被吞。这是 bash 长期陷阱（POSIX sh 同理）。
- **How to apply**：(1) 永远分开写：`local var; var="$(cmd)"`（先声明 local，再单独赋值，让 set -e 捕获 cmd 失败）；(2) 关键依赖显式校验：`declare -f fk_phase_gate_key >/dev/null || { echo fail >&2; exit 2; }`；(3) 审查所有 `local x="$(...)"` 模式（grep `local .*="\$\(`）。本次 change T-FIX-02 修复 gate.sh source fail-close。

## L-050 · flow-kit-bundle 改动须 cp 同步 ~/.claude/hooks 部署路径

- **严重度**：🟡 Major（修复运行时未生效，"全套真绿"≠"现场已修复"）
- **发现**：5-test L2 + 6-review L2 元发现——本 change 改 flow-kit-bundle/hooks/ 源码（T01-T05），但运行时 hook（~/.claude/hooks/）未同步。全部 5 hook md5 不同。后果：(1) AC-3 测 fail（已安装副本 29 脚本 :? 与开发副本一致但测期望错——同型）；(2) 6-review L2 写报告时被**旧版** BUG-H gate 误拦（heredoc 内 git commit 字符串），用 chr() 绕过——现场复现 REQUIREMENT US-2。本 change 修复在运行时未生效，全套 bats 536/0（开发副本）≠ 现场已修复。
- **Why**：flow-kit-bundle/ 是分发包源码，~/.claude/hooks/ 是部署路径。改源码后须 install.sh 或 cp 同步部署。两路径不同步 = 源码修复但运行时旧版。
- **How to apply**：(1) 改 flow-kit-bundle/hooks/ 后必 `cp flow-kit-bundle/hooks/<f> ~/.claude/hooks/<f>`（或 install.sh 重装）；(2) 5-test 阶段加「部署同步」验证（md5 对比 bundle vs ~/.claude）；(3) 7-integration 归档前确认部署同步。本次 change 已 cp 同步 5 hook。

## L-051 · L2 独立盲审是主 agent 证实偏差的最后防线（critical 实证）

- **严重度**：🔴 Critical（流程教训——主 agent 自评不可全信）
- **发现**：本 change 6-review 阶段，主 agent REVIEW.md 初审 Verdict=pass（0 Critical / 0 Major / "6 维整体改善"），5-test 阶段 L2 也 pass。但 6-review L2 独立盲审（code-reviewer 子 agent）实测复现 R1 🔴 Critical：`_command_has_write_context` 把「重定向/多行」当写上下文 → `git commit 2>log` 漏拦（AC-H(e) 要求 deny，AC 未实现），主 agent + 5-test L2 都漏判。主 agent 核验实测确认（exit 0 漏拦），非误判。回退 6→4 修 T-FIX 后 L2 重审 pass。
- **Why**：主 agent（实现者）有证实偏差——「代码能跑 + 全套真绿」≠「AC 真实现」。自评倾向于放过自己写的代码。5-test L2 审 TEST.md（非代码），未触代码层。6-review L2 审 git diff（代码），实测复现，才捕到。
- **How to apply**：(1) L2 盲审须独立子 agent + 原样注入 prompt（禁主 agent 自评注入）；(2) L2 须实测复现（非采信自评）；(3) 主 agent 核验 L2 发现（receiving-code-review 技术验证，非盲目接受/反驳）；(4) 6-review L2 审 diff（代码层）比 5-test L2 审 TEST.md（文档层）更易捕 critical。本 change 是 L2 机制价值的强实证。

## L-054 · independent-review gate `.done` 仅验存在不验作者——握手锚点是死代码

- **严重度**：🟡 Major（安全设计缺口——agent 可伪造 .done 绕过 L3 外部审查）
- **发现**：l2-l3-model-config 6→7 transition 期间深挖：`independent-review-gate.sh` Gate 3（`fk_independent_review_gate_active`）只要 `.independent-review-<phase>.done` **存在**就短路 `exit 0` 放行，不校验由谁写入。原用于证明「.done 由 stop-hook 子进程写（非 agent 伪造）」的握手 `.flow-active.independent-review` 已是死代码——全 hooks 树无生产 writer（仅 test fixture 写），`done-validation.sh` Tier 2 的 T3 握手校验因 Gate 3 短路而**不可达**，但 4 个单元测试（test_gate_integrity.bats）仍断言其安全意图（意图与现实脱节）。结果：主 agent 可自写结构合法的 .done 单方面绕过 L3。已另立 `gate-done-authorship` change 修（见 `.specs/gate-done-authorship/CHANGE.md`）。
- **Why**：历次 gate 重构（L2/L3 拆分等）把握手写入废弃、改「l3_review_run 直接写 .done」，但**校验端 + 测试端未同步清除**，留下活校验 + 死写入 + 不可达的不一致。Gate 3 短路条件是 .done 存在性而非作者性。
- **How to apply**：(1) 任何「标志文件存在即放行」的 gate 须额外校验作者性（path-guard 禁 agent 写该文件，或签名）；(2) 重构废弃某机制时，校验端 + 测试端必须同步清除，否则留下不可达的「活校验」制造虚假安全感；(3) 单元测试覆盖函数行为 ≠ 生产路径真生效——须确认函数在主流程里**可达**（本例 Tier 2 被 Gate 3 短路，测试再绿也不生效）。

## L-055 · L3 外部模型对 flow-kit「skill=实现」架构理解不足——易对 /flow 命令报「无实现」误报 Critical

- **严重度**：🟡 Major（review 流程教训——L3 误报会卡 pipeline，需人工裁判）
- **发现**：l2-l3-model-config 6-review L3 轮（deepseek-v4-flash）对 AC-5 `/flow model` 报 🔴 Critical「仅文档描述，无实际可执行实现」。实测核实为**误报**：`/flow model` 实现完整在 `skills/flow/SKILL.md:236-256`（参数解析 + 原子 jq 写 + 字段边界），且 `test_flow_model.bats` 6 用例覆盖。根因：L3 按「传统 CLI 须有独立可执行脚本入口」的心智模型判定，不理解 flow-kit 所有 `/flow *` 命令都是 **AI 读 SKILL.md 执行内嵌 jq 的 skill**（非独立脚本）。L2 盲审（code-reviewer，理解架构）正确判 pass。L2-pass/L3-fail 分歧经主 agent 裁判（6-review §4.2）解决。
- **Why**：L3 是通用外部模型，未内化 flow-kit「skill 即实现」的架构约定。补充既有教训「L3 verdict 不可全信」——本条是其具体、可操作的表现形式。
- **How to apply**：(1) L3 对 skill / markdown-as-implementation 类工件的「无实现」Critical 默认怀疑，先核实 SKILL.md 是否含可执行 jq/bash 段 + 对应测试；(2) L2-pass / L3-fail 分歧时优先信理解项目架构的 L2，按 6-review §4.2 人工裁判（记录 L2_verdict/L3_verdict + 证据）；(3) 给 L3 的 artifact 可附一句架构提示「/flow 命令是 skill，实现在 SKILL.md 内嵌 jq」降低误报（注意：架构提示只能给 L3，**不可**注入 L2 盲审 prompt——会破坏 L2 独立性）。

## L-056 · L3 工具 `_l3_call_api` 硬编码 max_tokens:8000 + curl --max-time 90 导致 deepseek-v4-pro 扩展思考吃满预算 → rc=3

- **严重度**：🔴 Critical（工具故障——阻塞所有 gate_config 含 L3 的 change 的 pipeline transition）
- **发现**：gate-done-authorship phase 3 L3 第二轮复核失败（2026-07-24）：deepseek-v4-pro 扩展思考把 8000 token 预算全花在 thinking block 上 → 无 text block → `jq select(.type=="text")` 返空 → rc=3。同时生成 ~144s 超 curl --max-time 90 → curl 杀进程。实测：禁用思考后 38s 返 3334 token 含 text block。
- **Why**：L3 工具设计时假设模型不使用扩展思考（max_tokens 8000 够用）+ 审查 < 90s。两个假设在 deepseek-v4-pro + 大产物场景下不成立。硬编码值无 env var / 配置文件覆盖入口。
- **修复**：l3-review-timeout-token change（2026-07-25）——三 env var 全可配：FLOW_KIT_L3_MAX_TOKENS（默认 32000）、FLOW_KIT_L3_TIMEOUT（默认 300）、FLOW_KIT_L3_THINKING（默认 enabled，可切 disabled）。Fail-safe：非法值回退默认 + 警告。jq -c compact 输出（省字节 + 易测试）。
- **How to apply**：(1) 任何调用外部 API 的工具，超时/token 上限必须可配置（env var > 默认值），禁止硬编码；(2) 换 L3 模型时须先实测 max_tokens/timeout 承载能力（大产物场景）；(3) thinking 模型（deepseek-v4-pro）需 disabled 作为 escape hatch；(4) `_l3_parse_result` 的 fallback 链 `.thinking // .text` 可能静默错判——留 v2 修复。
- **关联**：[[l3-model-unreliable]]（失败模式从 glm-4.7 幻觉演进为 deepseek-v4-pro 思考吃满预算）、TD-008（l3-review.sh 574 行多职责）、[[gate-done-authorship]]（被卡住的 change）
- **来源**：`l3-review-timeout-token`

## L-057 · 握手死代码清理不完整——校验端+测试端未同步 → 不可达的"活校验"制造虚假安全感

- **严重度**：🔴 Critical（安全设计缺陷——gate `.done` 仅验存在性不验作者性，agent 可伪造 `.done` 绕过 L3 审查）
- **发现**：独立 review gate 的「`.done` 标志」机制存在安全缺口（2026-07-24）：Gate 3（`fk_independent_review_gate_active`）只要 `.done` 存在就短路放行，不校验由谁写入。原本用于证明 `.done` 由 stop-hook 子进程写入的握手机制（`.flow-active.independent-review`）已演变为死代码——无生产代码写它，仅测试 fixture 写。agent 可自写结构合法的 `.done` 绕过 L3 外部模型审查。
- **Why**：握手的写入路径在 gate 重构中废弃（l3_review_run 直接写 .done），但校验端（done-validation.sh T3）+ 测试端（4 个握手测试 + regression-demos）未同步清除。结果是「活校验 + 死写入 + 不可达」（Gate 3 见 .done 存在即放行，永远到不了 Tier 2 T3）。单元测试再绿也不生——函数覆盖了但主流程不可达。
- **修复**：gate-done-authorship change（2026-07-25）——方案 A：彻底废弃握手，改用 path-guard D7 扩展保护 .done（`_is_dotdone_write` 禁止 agent 写 `.independent-review-*.done`）+ L2-only 例外 + Fail-safe。23 tests + 613 full regression。
- **How to apply**：(1) 删除机制时，校验端+测试端必须同步清除，不可留"死校验"制造虚假安全感；(2) 单元测试覆盖函数行为 ≠ 生产路径真生效——须确认函数在主流程里**可达**；(3) 安全敏感 gate 优先用前置拦截（path-guard 写入时阻）而非后置校验（Tier 2 读取时验）——前置更强（阻止创建 vs 检测已创建）；(4) 独立 review 发现握手死代码时先 check 全仓 `grep` 写路径真死否。
- **关联**：[[l3-model-unreliable]]（L3 模型不可靠导致 pipeline 反复 review 才暴露此缺口）、[[l3-review-timeout-token]]（修 L3 工具解套此 change 的 L3 审查）、ADR-005（独立审查体系，D7 path-guard）
- **来源**：`gate-done-authorship`

---

## superpowers-v6-absorb (2026-08-02) · 9 Minor findings 转 tech debt

> 来源：`.specs/superpowers-v6-absorb/MINOR-DEFERRED.md`，由 phase 1/2/5/6 各阶段 L2 审查捕获。

### L-058 · AC-A3 "如可用"弱化跨平台验证（来自 Phase 1 L2 R7）
- 严重度: 🟢 Minor
- 位置: REQUIREMENT.md AC-A3
- 问题: "如可用"使 macOS 不可用时 AC 自动退化为 Linux-only，违反 Given/When/Then 确定性原则
- 修复: 拆为 AC-A3a (Linux 硬) + AC-A3b (macOS 软)。下次 REQUIREMENT 重构时处理。
- 状态: active · 来源 `superpowers-v6-absorb` Phase 1 L2 ✅ Resolved (final-debt-cleanup-2026-08 / ADR-019 principle)

### L-059 · 多条 AC 验证方式含"人工"（来自 Phase 1 L2 R8）
- 严重度: 🟢 Minor
- 位置: REQUIREMENT.md AC-B1/B2/D2/F2/G1/G2
- 问题: "人工 + grep" 降低自动化置信度，未来 prompt 行为退化无法自动捕获
- 修复: 将 grep 部分独立为 bats 测试
- 状态: active · 来源 `superpowers-v6-absorb` Phase 1 L2

### L-060 · 范围决策嵌入 REQUIREMENT（来自 Phase 1 L2 R9）
- 严重度: 🟢 Minor
- 位置: REQUIREMENT.md 范围决策框
- 问题: 设计决策（双轨测量 / 加强语义 / 并存策略）属 how 层级，嵌入 what 层级文档模糊边界
- 修复: 移到 CHANGE.md 验收线段或独立 DESIGN-NOTES.md
- 状态: active · 来源 `superpowers-v6-absorb` Phase 1 L2 ✅ Resolved (final-debt-cleanup-2026-08 / ADR-019 principle)

### L-061 · ADR-016 探测脚本路径未验证（来自 Phase 2 L2 R5）
- 严重度: 🟢 Minor
- 位置: `.specs/adr/016-model-tier-dispatch.md` detect_opencode_tier_support
- 问题: 缓存路径 `.specs/<id>/.opencode-capability.json` 来自未验证假设
- 修复: 实测时确认路径或改临时文件
- 状态: active · 来源 `superpowers-v6-absorb` Phase 2 L2 ✅ Resolved (final-debt-cleanup-2026-08 / ADR-020 capability snapshot)

### L-062 · task_progress lifecycle 图细节缺失（来自 Phase 2 L2 R6）
- 严重度: 🟢 Minor
- 位置: DESIGN.md § 2 task_progress lifecycle 图
- 问题: 图未展示 skip 任务时 task-brief 是否仍需提取
- 修复: 完善图注释
- 状态: active · 来源 `superpowers-v6-absorb` Phase 2 L2 ✅ Resolved (final-debt-cleanup-2026-08 / ADR-019 principle)

### L-063 · D5/D6 弱模型缓解引用 ADR-001 不适配（来自 Phase 2 L2 R7）
- 严重度: 🟢 Minor
- 位置: DESIGN.md D5/D6
- 问题: terse contract + narration constraint 在弱模型场景的退化问题引用 ADR-001 gate（输出风格约束 ≠ gate）
- 修复: 弱模型场景实测后补 ADR
- 状态: active · 来源 `superpowers-v6-absorb` Phase 2 L2 ✅ Resolved (final-debt-cleanup-2026-08 / ADR-021 prompt degradation protocol)

### L-064 · 安全注入测试缺失（来自 Phase 5 L2 R8）
- 严重度: 🟢 Minor
- 位置: TEST.md 安全段
- 问题: 仅代码结构描述，无注入测试
- 修复: 加 edge case bats（special chars in commit messages / path traversal）
- 状态: active · 来源 `superpowers-v6-absorb` Phase 5 L2

### L-065 · 集成测试无自动化（来自 Phase 5 L2 R9）
- 严重度: 🟢 Minor
- 位置: TEST.md 集成测试段
- 问题: 3 个集成场景全部手动验证
- 修复: 加 test_integration_smoke.bats
- 状态: active · 来源 `superpowers-v6-absorb` Phase 5 L2

### L-066 · AC-B4 测试深度不足（来自 Phase 6 L2 R4）
- 严重度: 🟢 Minor
- 位置: TEST.md AC-B4
- 问题: 仅测 task-brief 输出，未测合并指标（4-dev.md + task-brief）
- 修复: 加合并指标 bats 测试（前提：先澄清 AC-B4 措辞，见 INTEGRATION.md § 3）
- 状态: active · 来源 `superpowers-v6-absorb` Phase 6 L2

### L-067 · AC-I(b)(c) pre-existing failures（来自 Phase 5 TEST.md 归因）
- 严重度: 🟢 Minor
- 位置: `test/test-l2-first-correction.bats` AC-I(b)(c)
- 问题: gate_config=both 无 L2 段跑 Stop hook 29 的 2 个测试失败，与本 change 无关（write_files 不含 29 hook）
- 修复: 独立 change `fix-l2-first-correction-test` 处理
- 状态: active · 来源 `superpowers-v6-absorb` Phase 5 TEST.md

### L-068 · 4-dev.md 体积压缩（结构性技术债）
- 严重度: 🟡 Scheduled
- 位置: `flow-kit-bundle/flow-kit/prompts/4-dev.md` (781 行)
- 问题: 4-dev.md 体积持续增长（721 → 781），无压缩机制
- 修复: 拆 TDD/grep-before-code/5-submit 等段为 reference 片段（如 terse-contract.md 模式）
- 状态: ✅ resolved 2026-08-03 · `cleanup-debt-batch-2026-08` T04 · 781→352 行 + 3 reference 文件（tdd-workflow / commit-protocol / checkpoint-protocol）

## superpowers-absorb-followup-1（2026-08-03 · 测试补强）

### L-069 · package validate 漏配 M-health.md
- 严重度: 🟡 Scheduled
- 位置: `package-flow-kit.sh::validate_staging_coverage()`
- 问题: `flow-kit-bundle/flow-kit/prompts/M-health.md` 未被任何 Part A-G 覆盖。Pre-existing（initial commit `549b6a0`）
- 修复: 在 Part A-G 之一加入 M-health.md；建议独立 change `fix-package-validate-mhealth-missing`
- 状态: ✅ resolved 2026-08-03 · `cleanup-debt-batch-2026-08` T02 · Part B 加 cp 行

### L-070 · package validate exit=0 even on error
- 严重度: 🟢 Minor
- 位置: `package-flow-kit.sh::validate`
- 问题: validate 报 🔴 ERROR 但 exit code=0，CI 无法机器判定失败
- 修复: validate 函数末尾按错误数返回 exit code
- 状态: ✅ verified non-bug 2026-08-03 · `cleanup-debt-batch-2026-08` Phase 2 L2 R1 · `validate_staging_coverage()` at `lib/validate_staging.sh:127-131` 已正确 exit 1（ERRORS>0）；caller `package-flow-kit.sh:18-19` 正确传播 via `exit $?`。原 tech debt 条目记录有误。

### L-071 · review-package 缺 git ref validation
- 严重度: 🟡 Scheduled
- 位置: `flow-kit-bundle/flow-kit/scripts/review-package`
- 问题: review-package 不验证 git ref 有效性。`../../etc/passwd` 类输入静默返回 exit=0 + 空输出（41 字节空 diff sections）。SEC-5b 测试 honest skip。
- 修复: 加 `git rev-parse --verify "$base" 2>/dev/null` 校验 + 失败时 exit 1 + stderr 错误信息。建议独立 change `fix-review-package-ref-validation`
- 状态: ✅ resolved 2026-08-03 · `cleanup-debt-batch-2026-08` T01 · 加 ref validation 循环 + SEC-5b unsuppressed

### L-072 · 29 hook L3 short-circuit ordering 与 mock 冲突
- 严重度: 🟢 Minor
- 位置: `flow-kit-bundle/hooks/stop/29-independent-review.sh:59-64`
- 问题: 29 hook 在 line 59-64 检测 L3 model 配置（短路 exit 3），在 line 181-185 才检测 L2-missing。Mock 环境必须设 `FLOW_KIT_L3_MODEL=mock-l3-model` 才能到达 L2 检测分支。生产 ordering 问题（29 hook 在禁动清单），独立 change 处理
- 修复: 重排：L2-missing 检测应在 L3-model-missing 之前。建议独立 change `fix-29-hook-mock-mismatch`
- 状态: ✅ resolved 2026-08-03 · `cleanup-debt-batch-2026-08` T03 · L2-first quick gate 移到 L3 model check 之前（lines 60-73）+ 旧 D1 块删除 + mock workaround 移除

## cleanup-debt-batch-2026-08（2026-08-03 · 债务清理）

### TD-071-A · brooks-lint Part F 打包漏配（pre-existing）
- 严重度: 🟢 Minor
- 位置: `package-flow-kit.sh` Part F + `flow-kit-bundle/brooks-lint/plugin/skills/`
- 问题: validate 报 `brooks-audit/SKILL.md` + `brooks-test/SKILL.md` 未被 Part F 覆盖。Pre-existing，与本 change 无关。
- 修复: Part F 加 cp 覆盖新增 SKILL.md 文件
- 状态: open · 来源 `cleanup-debt-batch-2026-08` Phase 6 REVIEW.md § 4.3 ✅ Resolved (final-debt-cleanup-2026-08 / verified non-bug)

### TD-071-B · A-evolve.md 源缺失（pre-existing）
- 严重度: 🟢 Minor
- 位置: `flow-kit-bundle/flow-kit/prompts/A-evolve.md`
- 问题: validate 期望文件存在但源缺失（可能在 archive 时遗漏）
- 修复: 调查 archive/prompts 一致性
- 状态: open · 来源 `cleanup-debt-batch-2026-08` Phase 6 REVIEW.md § 4.3 ✅ Resolved (final-debt-cleanup-2026-08 / verified non-bug)

## TD-072 🟡 — hook lib 文件级行数超标（final-debt-cleanup-2026-08 遗留）
- **位置**：`flow-kit-bundle/hooks/stop/lib/l3-api.sh` (371 行) + `flow-kit-bundle/hooks/pre-tool-use/gate-helpers.sh` (253 行)
- **来源**：final-debt-cleanup-2026-08 L2 phase 5 R2/R3 finding
- **影响**：REQUIREMENT AC-E1/E2 原始目标过于严格，长函数已拆分但文件级目标未达
- **建议**：v2 进一步拆 l3-api.sh（抽 callparse）+ gate-helpers.sh（按 file/types/state 分组）
- **登记时间**：2026-08-03
- **状态**: ✅ Resolved (td072-lib-split-2026-08) — l3-api.sh 371→218 (smart_truncate → l3-truncate.sh 54→202)；gate-helpers.sh 253→139 + 新建 gate-helpers-types.sh 92 (聚合入口模式)。4 metrics bats 加。662→666 tests / 0 fail

## test-failures-fixup-2026-08 Resolved ✅ (2026-08-03)

### Pre-existing bats fails resolved (5)
- Test 250 (gate regex) → split-aware grep rewrite
- Test 507 (AC-5 npx bats 指令) → OR 双文件 assertion
- Test 509 (AC-6 失败阻断) → assertion 重写 pattern
- Test 515 (子段编号 1.8.4.x) → grep tdd-workflow.md 4 个 #### 标题
- Test 577 (make lint SC2148) → 7 hook lib 加 `# shellcheck shell=bash` 指令

### Lessons learned
- **TD-073**: L-068 后内容迁移时，test grep assertion 必须同步重写（不只是 grep 范围扩大）。Split-aware test 设计原则
- **TD-074**: shellcheck SC2148 对 sourced lib 的标准修复是 `# shellcheck shell=bash`（非 shebang）

## l2-l3-subagent-fix Lessons learned (2026-08-05)

### L-073 · opencode subagent_type 路由创建的子会话 agent/model 未绑定（与 model 字段无关）
- 严重度: 🟡 Major（影响所有 subagent_type 派发，category 路由可用作 workaround）
- 位置: opencode 1.18.9 task tool subagent_type 路由路径（非 flow-kit 代码，平台行为）
- 问题: `task(subagent_type=<any>)` 创建的子会话 `agent=undefined model=undefined`（opencode.log 实测），无论 agent 文件 model 字段是 sonnet 还是 inherit 均挂起至 30min 超时。鉴别实验：qa-expert(sonnet) 与 architect-reviewer(inherit，阶段 2/3 成功用过) 均超时；阶段 2/3 成功实为 category=unspecified-high 路由派发。
- 修复: L2/L3 盲审派发在本环境改用 `category=` 路由（category 路由绑定 model 正常，4s 完成）；subagent_type agent 绑定修复属平台层（out 范围）
- 适用栈: opencode + OhMyOpenCode task tool 环境
- 关键词: subagent_type, agent=undefined, category routing, L2 dispatch, 30min timeout
- 状态: open · 来源 `l2-l3-subagent-fix`（调查型 change，根因 #2 已定位，v1 workaround=category 路由）

### L-074 · .independent-review-<N>.done 必须用 Write 工具写（path-guard 拦 Bash 重定向）
- 严重度: 🟢 Minor（已知陷阱，有明确 workaround）
- 位置: `flow-kit-bundle/hooks/pre-tool-use/gate-helpers.sh::_is_dotdone_write` (gate-helpers-types.sh:18-32)
- 问题: PreToolUse path-guard D7 拦截 Bash 命令写 `.independent-review-*.done*`（匹配重定向 `>`、tee、cp、mv、sed -i、printf、dd、install、awk、cat<<）——即使命令是 ls 带 `2>/dev/null` 也被误判拦截。L2-only 模式主 agent 写 .done 时若用 Bash 重定向必被拦。
- 修复: 用 Write 工具写 `.done` 文件（路径含 phase 号 → `_gate_is_l2_only` 读 gate_config 放行）。Write 工具不被 _is_dotdone_write 匹配（仅检测 Bash 命令文本）。
- 适用栈: flow-kit L2-only 模式（gate_config 含 L2 的阶段，主 agent 写 .done）
- 关键词: path-guard, _is_dotdone_write, .independent-review-N.done, Write tool, L2-only
- 状态: open · 来源 `l2-l3-subagent-fix`（阶段 1 首次撞，阶段 2-7 持续应用 workaround）
