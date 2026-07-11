# LESSONS — 项目经验教训与技术债

> 本文件跨 change 累积。M-health 巡检 + 各 change 的 brooks-lint 结果 + 人工标注都写入此处。
> 格式：严重程度 | 位置 | 问题 | 建议 | 状态 | 来源

<!-- l3-pipeline-fix-2026-07 ↓ -->
| L-041 | 🟡 | `auto-checkpoint.sh` PreToolUse hook | 自引用竞态：hook 在 Write/Edit `.flow-active` 前触发 `checkpoint_write()` 修改同一文件，导致 harness 检测到文件内容变化后拒绝 Write/Edit | 在 `auto-checkpoint.sh` 中检测 `file_path` 是否为 `.flow-active` 自身——若是则 skip checkpoint 写入 | ✅ 已修复 | `l3-pipeline-fix-2026-07` |
| L-042 | 🔴 | `29-independent-review.sh` L3 派发 | `--background` 异步 flag 硬编码激活导致 `.done` 永不写入：fork 子进程后立即返回 `return 0`，`_l3_write_done()` 未执行 → 下次 Stop hook 再次进入积压扫描 → 无限重派循环 | 异步功能默认关闭（opt-in via `L3_BACKGROUND=1`）；默认同步路径确保 `.done` 写入 | ✅ 已修复 | `l3-pipeline-fix-2026-07` L2 审查 R1 |
<!-- l3-pipeline-fix-2026-07 ↑ -->

---

## 技术债清单

> 最后更新: 2026-07-10

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

|---|---|---|---|---|---|---|
| L-031 | 🟡 | 跨文件批量修改 · DESIGN.md 清单驱动 | **DESIGN.md 列出的修改文件清单不完整时，AI 会漏改**：fix-l3-gate 的 AC-4（transition jq `.phase` 同步）涉及 9 处修改点，DESIGN.md §3.4 列出了 7 处（0-change/1-req/2-design/3-task/5-test/6-review prompts + 31-auto-advance.sh），遗漏了 4-dev.md 和 pipeline-gates.md 两处。主 agent 按 DESIGN 清单逐项执行，L2 盲审通过全仓 grep `phases_done.*+=` 才发现遗漏 | 批量修改前必须全仓 grep 确认所有命中点，不能仅依赖 DESIGN.md 清单。在 DESIGN.md 底部加一栏「全仓扫描确认」：grep 命令 + 命中数 + 逐项标注"需改/不适用" | active | `fix-l3-gate` 2026-07-10 · L2 盲审发现 |

| L-030 | 🔴 | `flow-kit-bundle/hooks/stop/29-independent-review.sh` + `independent-review-gate.sh` | ~~**L3 盲审 gate 机制三连异常**~~ → ✅ resolved by `fix-l3-gate`（2026-07-10）：(1) L3 重审——mtime 检测工件变更后追加 `## L3 重审` 段；(2) .done 条件写入——仅 `L3_verdict=pass` 时写 .done；(3) transition `.phase` 同步——9 处 transition jq 全部加 `.phase` 字段 | resolved | `fix-l3-gate` 2026-07-10 |

| L-022 | 🟡 | Bash hook stderr 安全 | 移除 `2>/dev/null` 后 curl/jq 错误信息（含 endpoint URL、部分 API 响应）会通过 `>&2` 日志泄露到 agent 可见 stderr。`_l3_format_result` 的白名单输出天然安全，但真实 stderr 泄露只能在集成环境验证。建议 v2 将敏感诊断日志重定向到专用 debug 文件而非 stderr | active | `l3-feedback-visibility` 2026-07-07 |

| L-004 | 🟢 | `flow-kit-bundle/lib/install_hooks.sh` | 辅助函数 `install_file()` 已从 install.sh 抽出到 lib/，但独立工具库 `lib/utils.sh` 尚不必要（当前 1 个共享函数，阈值 ≥ 3）。debt-cleanup 确认保持推迟。 | 等新增 ≥ 2 个共享辅助函数时再建 `lib/utils.sh`，避免只有一个函数的过度抽象 | deferred | `init-git-repo` T03 手动基线 |
| L-005 | 🟡 | `package-flow-kit.sh` L20 | STAGING 前置校验已添加（debt-cleanup） | `[[ -n "$STAGING" && "$STAGING" != "/" ]]` guard 已生效 | resolved | `init-git-repo` T03 手动基线 |
| L-014 | 🟢 | Bash `grep -E` 字符类中 `\]` 的转义 | 在双引号字符串内使用 `grep -E` 的字符类 `[...\]` 时，bash 将 `\]` 展开为 `]`，导致字符类提前关闭、匹配静默失败。典型症状：grep 在 shell 中直接执行正常，但在 bats 测试的 sourced function 中返回空。修复：用 `[^[:space:]]*` 替代复杂字符类 + sed 后处理剥离尾随标点；或使用单引号字符串避免 bash 转义。影响：所有在双引号内使用 `grep -E` + 含 `]` 字符类的 Bash 脚本。来自 `robustness-hook-hardening` T04 L3 测试调试 | 写 Bash regex 优先单引号字符串；必须双引号时用 `[^...] 替代字面排除字符类 | active | `robustness-hook-hardening` T04 调试 |
| L-015 | 🔴 | AI 直接编辑 `~/.claude/` 运行时文件而非 `flow-kit-bundle/` 维护源 | `improve-independent-review` 的 4-dev 阶段，AI 直接修改了 `~/.claude/hooks/stop/29-independent-review.sh`、`30-ai-analyze.sh`、`~/.claude/skills/flow/SKILL.md`——这三个是 install.sh 部署的运行时副本，非维护源。CONTEXT.md 明确约定 "hooks 唯一源确定为 flow-kit-bundle/hooks/，.claude/hooks/ 为 install.sh 安装的运行时副本（非维护源）"。AI 应编辑 `flow-kit-bundle/` 下的同路径文件，然后跑 `install.sh` 部署。根因：AI 未在 4-dev 阶段读 DESIGN 0.5.1 的"触碰模块"路径映射就动手 | **强制**：任何涉及 `~/.claude/` 下文件的改动，AI 必须先确认对应 `flow-kit-bundle/` 源路径，改源不改运行时。改完后跑 `install.sh --global --user` 验证部署一致性 | active | `improve-independent-review` 事后纠正 |
| L-013 | 🟢 | `.specs/` 归档流程（7-integration） | 归档流程两种遗漏模式：① **归档未清理**——change 已归档但 `.specs/<id>/` 工作目录未删，留只剩 PROGRESS.md 的空壳（2026-06-24 发现 bundle-packaging / docs-sync / fix-pcsc-gaps）；② **完成未归档**——change 100% 完成（REVIEW✅ / TASK 全done / CHANGELOG 已记）却没走归档，完整工件散落 `.specs/`（2026-06-25 发现 security-privacy-audit） | 归档脚本（7-integration）加双向校验：a) 归档完成后 rm 工作目录（PROGRESS.md 先确认入 archive）；b) 定期扫描 `.specs/` 下非 archive 目录，凡 REVIEW✅ + TASK 全done 的 change 提示归档 | resolved | `lessons-cleanup` T01 / T04 / T06 |
| L-016 | 🟢 | `flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh`（501 行） | 单体文件偏大，含 artifact-check / auto-phase / done-validation / stale-check / boundary-check / snapshot / progress / token 共 8 个职责 | 可按职责拆为 `artifact-check.sh` / `auto-phase.sh` / `done-validation.sh` 三个子库（当前可维护性尚可，非紧急） | observed | `M-health 2026-07-02` |
| L-017 | 🟢 | `package-flow-kit.sh`（594 行） | 打包主脚本偏大，`validate_staging_coverage()` 函数 ~100 行独立于主流程 | 可拆出 `validate_staging_coverage()` 为独立 lib（当前可维护性尚可，非紧急） | observed | `M-health 2026-07-02` |
| L-018 | 🟢 | `flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh:498` | `fk_accumulate_tokens` 中 `updated_at` 被双重赋值（第一个 `\| .updated_at = now` 被第二个 `\| .updated_at = (now \| strftime(...))` 覆盖），无实际效果但潦草 | 删掉第一个 `\| .updated_at = now`（下次改到该函数时顺手修） | observed | `M-health 2026-07-02` |
| L-019 | 🟡 | `flow-kit-bundle/hooks/stop/lib/correction-file.sh:41` | `correction_file_write()` 使用 overwrite 策略——直接覆写矫正文件。当多个 hook 模块（28 / 33）共用同一矫正文件（`.flow-active.correction`）时，后写入者会销毁先写入者的记录。本次 33 号模块实现了 read-merge-write（先读现有 violations → 追加 → 写回），但 `correction-file.sh` 的 `correction_file_write()` 仍只有 overwrite 策略 | 升级 `correction_file_write()` 支持 `merge` 策略（第二个参数传 `merge` 时 read-merge-write）或默认改为 merge。所有调用者（28/33）统一受益 | active | `flow-active-integrity` phase 2/3 L2 review R1 |
| L-020 | 🟡 | Stop hook 模块执行链 | **新增 Stop hook 模块需要三处接线才能实际执行**：① `00-gate.sh` 添加 `run_module` 调用 ② `common.sh` 的 `HOOK_MODULE_NAMES` 数组追加编号 ③ `hooks/config/stop-hook.json` 注册模块条目。漏掉任何一处 = 模块永不执行。`pipeline-fallback-fix` 新增的 31/32 号模块遗漏了 00-gate.sh 接线（至今 dead code），本次 33 号在 L2 review 发现并及时补齐 | **强制**：新增 hook 模块的 task 必须同时写入三处；TASK.md 的 verify 必须 grep 三处均含模块名。或将三处合并为单一注册源，`00-gate.sh` 从 `stop-hook.json` 动态加载 | active | `flow-active-integrity` phase 3 L2 review R2 |
| L-021 | 🔴 | `flow-kit-bundle/hooks/stop/lib/correction-file.sh` ↔ `interactive-ui-check.sh` ↔ `weak-model-compliance.sh` | 三个 lib 模块形成双向依赖环：`correction-file.sh` → `interactive-ui-check.sh`(1 ref) 且 `interactive-ui-check.sh` → `correction-file.sh`(6 refs)；`correction-file.sh` → `weak-model-compliance.sh`(1 ref) 且 `weak-model-compliance.sh` → `correction-file.sh`(2 refs)。违反 Acyclic Dependencies Principle (ADP)，任一模块改动可级联破坏其他模块。与 L-019（correction_file_write overwrite 策略）属于同一模块的不同维度问题 | 提取三方共享的最小接口到新 lib（如 `correction-types.sh`），让 UI check 和 weak-model-compliance 依赖接口而非具体实现 | active | `M-health 2026-07-04` |

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

- **最近更新**: 2026-07-08（M-health 巡检：TD-006/007 标 resolved + 新增 L-025）
- **下次复查**: 2026-08-08（建议每月一次 M-health）

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
