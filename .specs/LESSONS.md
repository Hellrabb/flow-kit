# LESSONS — 项目经验教训与技术债

> 本文件跨 change 累积。M-health 巡检 + 各 change 的 brooks-lint 结果 + 人工标注都写入此处。
> 格式：严重程度 | 位置 | 问题 | 建议 | 状态 | 来源

---

## 技术债清单

| # | 严重程度 | 位置 | 问题 | 建议 | 状态 | 来源 |
|---|---|---|---|---|---|---|
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

- **最近更新**: 2026-06-16（health-fix 归档）
- **下次复查**: 2026-07-16（建议每月一次 M-health）

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
