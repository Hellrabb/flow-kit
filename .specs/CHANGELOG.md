# CHANGELOG

> 按日期倒序。每行：日期 / change-id / 摘要 / LESSONS 新增。
| 2026-08-05 | `l2-l3-subagent-fix` | 调查型 change：L2/L3 子 agent 派发双平台兼容性根因报告（ROOT-CAUSE.md 五段：3 根因 + 1 bug）+ 3 项 low 修复（①/flow model l2/l3 配置 · ②qa-expert sonnet→inherit · ③l2-detect.sh 凭证缺失平台感知降级提示）· 鉴别实验证伪「model 字段是根因」假设（subagent_type 路由 agent=undefined 与 model 无关 · qa-expert(sonnet) + architect-reviewer(inherit) 均超时）· 可用路径=category 路由（4s 实测 + 阶段 2/3/5/6 四次 L2 盲审成功 1m16s/4m23s/5m25s 等）· v2 项归档（D5-③gate 桥接 / ④L3 API 适配 / ⑤_fk_phase_direction 转义绕过 / ⑦agent 绑定）· 692/0 bats · pipeline 0→7 gate_config=all-L2 · 6 阶段 L2 盲审（1/2/3/5/6/7）全 pass · 核心交付：根因报告 + 证据链（EVIDENCE 1-5）+ 修复落点（l2-detect.sh + qa-expert.md + .flow-active.goal） | L-073, L-074 |
| 2026-08-04 | `health-fix-2026-08` | M-health 2026-08-03 Full Sweep (89/100) 修复 change · install_hooks.sh:97 user-scope PROJECT_DIR_NAME 回归（commit `0c79f1c` 双平台拆分遗留 · Fix A paths.sh 自加载守卫 · Fix B 正确拒绝—stop-hook.json 是 user-scope 运行时回退依赖 · Fix C header 文档化）· pipeline 0→7 gate_config=all（hotfixed to all-L2 per D7）· 3 oracle L2 (1/2/6) + 3 self-certified (3/5/7) + 3 retroactive oracle L2 → self-certify 3/3 WOULD-HAVE-FLAGGED（9+ findings · 全修）· 692/0 tests · health 89→99 · l3-api.sh split test 跟进 | L-064 (self-certify 系统性不如 oracle review · gate_config=all 不可 shortcut) |
| 2026-08-02 | `superpowers-v6-absorb` | 吸收 superpowers v6.0 经验：review-package + task-brief + terse + narration + severity gating + model-tier + plan-conflict-scan + GO.md 压缩 + 5 ADR | 待 phase 5 补 LESSONS |
| 2026-07-24 | `l2-l3-model-config` | L2/L3 审查模型配置解耦（ADR-012 supersedes ADR-006）：fk_resolve_model 三级优先级链（ANTHROPIC_* env > FLOW_KIT_L2/L3_MODEL > .flow-active.goal.l*_model > 空字符串降级）替代 3 caller 硬编码（l3-review/29-indep/l2-detect `:?`-终止 → fk_resolve_model + 降级写 correction type=l*-model-missing）+ /flow model 命令（SKILL.md jq 内联 写/合/clear/显示 · 字段边界守护不触碰 condition/gate_config）+ SessionStart 收割 model-missing banner（flow-kit-resume.sh 4 分支 + rm 条件化）+ ADR-013 correction 覆写策略（最后写入者胜·单文件单 type）· 6 hooks + 1 skill + 3 新 bats（test_fk_resolve_model 10 / test_model_degradation 3 / test_flow_model 6）+ resume/independent_review_model 改 · 全量 587 bats 0 fail · pipeline 0→7 gate_config=both（6-review L2 pass / L3 fail→主 agent 裁判「/flow model 无实现」为架构误报→过 · AC-5d 已执行 UAT 补证）· 握手 `.done` 作者性缺口另立 `gate-done-authorship` change | L-054 (gate .done 仅验存在不验作者·握手死代码), L-055 (L3 对 skill=实现 架构理解不足报「无实现」误报) |
| 2026-07-21 | `gate-review-fix` | /code-review max L2 盲审判定的 13 条 gate/review 缺陷修复：DRY fk_normalize_gate_val()+fk_extract_l2_verdict() 消除 8 处重复 + .tmp.$$→mktemp 竞态修复(3处) + _l3_write_done || true→显式case $rc + _gate_check_l3 auto_advance检测 + awk L3段去重(替代sed) + _l3_build_prompt fallback路径修正 + _gate_phase_filter→fk_resolve_phase() + gate_val→fk_normalize_gate_val(4处) + phase_name→fk_phase_gate_key() + l2_dispatch_agent mkdir -p防御 · 7 hooks + 4 tests×2双源 + 13 specs = 27 files, +2600/-149 · 34 bats 0 fail(连续3次)·全量 1128→1086(修复test_l2_pretooluse_dispatch/test-phase-gate-key双flow-kit-bundle/路径bug,-42预存失败)·38预存未修(test_gate_integrity/test-is-git-commit)·pipeline 0→7 gate_config=all(L2×5:L3×2)| — |
| 2026-07-20 | `health-debt-cleanup` | 健康巡检 4 项遗留消除（92→~96）：R6 `check_g*`→`_fk_check_*` 全仓重命名统一两套前缀（11 函数·26-workflow.sh+flow-kit-artifacts.sh）+ R1 install_hooks() 测试补齐不拆分（16 bats cases）+ T5 install 函数全覆盖 + R4 `_grep` 保留决策标注 · CONTEXT.md 追加命名约定段 + LESSONS.md L-052/L-053/观察→resolved · Phase 5/6/7 独立 L2 Agent 审查（5: 2C→fix→pass · 6: 2m→fix→pass · 7: 1M CHANGELOG→fix→pass）· 559 bats 0 fail · pipeline 0→7 gate_config=all · bash -n 63 脚本全过 | L-052, L-053 |
| 2026-07-20 | `l2-l3-mock-fix` | L2/L3 独立审查 gate 残留缺陷根治（F/H/I/J+K）：PHASE_GATE_KEY_MAP 抽 pure fn fk_phase_gate_key 单一来源(D1·ADR-007) + is_git_commit/is_gh_pr_create 改结构判定(quoting/heredoc感知·D2·ADR-008) + L2-first 顺序契约双管(D3·ADR-009) + _l3_check_rerun 改 ## L3 段内容标记+artifact hash(D4·ADR-010) + 26-workflow G1 pipeline goal 不 auto-advance(D5·ADR-011) + 6-review L2 捕 R1/R2 critical 回退修复(AC-H(e) 重定向漏拦 T-FIX-01 + source fail-close T-FIX-02) + AC-3 范围外基线修测 · 5 hook + 5 ADR + 8 bats files · 全套 bats 543/0 真绿 · pipeline 0→7 gate_config=all（6-review L2 经 fail→T-FIX→重审 pass 完整 gate cycle）| L-049 (local 屏蔽 set -e fail-open), L-050 (bundle 改动须 cp 同步部署), L-051 (L2 独立盲审捕主 agent 证实偏差) |
| 2026-07-15 | `l2-pretooluse-dispatch` | L2 PreToolUse 前置拦截 + L3 写入管道修复：_gate_check_l2 扩展（auto_advance检测 + auto-dispatch + 降级）+ l2_dispatch_agent() 异步Agent派发(Anthropic API)+ L3 backlog错误日志(去2>/dev/null)+ L3原子写入(tmp+mv)+ _l3_write_done防御 + test_l2_pretooluse_dispatch.bats 12 tests · 7 files, +294/-4 · 全量回归 80 bats 绿 · pipeline 0→7 gate_config=all | L-047 (L3内容丢失: 2>/dev/null吞错+非原子写入竞态), L-048 (L3触发时机: Stop hook依赖对话轮次边界导致连续推进session中L3滞后) |
| 2026-07-11 | `l3-pipeline-fix-2026-07` | L3管线5项限制修复 + Stop hook性能优化：git diff并集+token估算截断 + smart_truncate三遍扫描(尾部锚点+fallback) + 积压扫描(_l3_scan_backlog≤3限流) + 上下文注入(_l3_inject_context+免责声明) + L3 API异步化(L3_BACKGROUND=1 opt-in) + HTTP降级(curl -w状态码) + 15模块fk_perf_timing探针 + auto-checkpoint自引用竞态修复 · 33 files, +582/-115 · 482 bats 0 fail(-2,BW01重组) · pipeline 0→7 全L2+L3(phase1~6) | L-041 (auto-checkpoint自引用竞态), L-042 (--background默认sync安全) |
| 2026-07-11 | `health-fix-l3-2026-07` | L3 审计子系统健康修复（72→pass）：`_gate_phase_transition` 122L→45L编排器+3子函数 + `fk_fix_compliance_check` 126L→编排层 + correction-types.sh 解环三向依赖 + PHASE_GATE_KEY_MAP 消除3处phase_name硬编码 + goal-parsing.md DRY jq解析 + self-sourcing修复 + 死代码清理 + timeout测试补齐 · 16 files, +350/-97 · 469 bats 0 fail(+3) · pipeline 0→7 全L2+L3 | L-039 (`set -euo pipefail`下命令替换pipefail静默终止29号hook) |
| 2026-07-10 | `sweep-fix-2026-07-10` | Full Sweep 统一清理（评分 65→≥80）：l3_review_run 305→42行拆分（4子函数+编排器）+ independent-review-gate 285行无名块→7`_gate_*`+`_run_review_gates`编排器 + `run_check()` 消除30处check_enabled模板重复(-97%) + `write_failed_state`死代码移除 + CONTEXT.md命名约定7前缀文档化 + `_grep`保留决策(KEEP·防御性shim·证据链完整) + `_l3_check_rerun`重审检测提取 + DRY_RUN安装测试4条新增 · 12 files, +456/-415 · 466 bats 0 fail(+4) · pipeline 0→7 全L2 ×5 | L-034 (AC硬编码数陷阱), L-035 (Given污染下游), L-036 (heredoc引用退化), L-037 (exit-in-subfunction反模式), L-038 (verify不覆盖非代码产物) |
| 2026-07-10 | `auto-checkpoint-hook` | 自动 checkpoint PreToolUse hook：Write/Edit 前自动更新 `.flow-active.interrupt`（active_file + last_action + checkpoint_at），会话中断后 SessionStart 精准恢复。移除去重逻辑（`checkpoint_dedup_check()` + `CHECKPOINT_DEDUP_WINDOW`）。全阶段 0~7 启用，fail-open 不阻断工具。7 files, +136/-97（源码）+ 3 new files (hook + 2× tests) · +14 bats (454→468) · 全量 0 fail · pipeline 全 L2（HAIKU）· gate_config=all | L-032 |
| 2026-07-10 | `checkpoint-polish` | BW01 resume banner sourceable 函数（banner.sh 新 lib +123 lines · flow-kit-resume.sh -78 lines · 255→177 · -31%）+ BW02 CHANGELOG.md 格式统一（消除独立表头行 · 38 entries 紧凑 pipe）+ BW03 make test-sync 双源测试同步（Makefile +10 lines · test/ → bundle/test/）+ test_resume_banner.bats 7 tests · 462 bats 全量 0 fail · pipeline 0→7 全 L2 | L-033 |
| 2026-07-10 | `td-test-infra` | TD-010 jscpd 工具化（`make dup` target · 独立不进 check · 4 ignore 模式 brooks-lint/brooks-tools/test/regression-demos · 未装 graceful skip）+ TD-002 stop 链覆盖核实（SUMMARY 17 行：covered 5 [00/22/24/26/99] / partial 12 / gap 0）+ 补 6 [business] smoke（23/27/28/29/30/33 · bash-n+shebang+grep · 沿用 test_stop_chain 范式 · D2 结构层）· +18 bats（401→419）· 全量回归 0 fail · pipeline 全程关 L3 改 L2（L2 用 haiku）因 L3 死结 | L-030 |
| 2026-07-10 | `fix-l3-gate` | 修 L3 gate 机制三连异常（L-030）：(1) L3 重审——mtime 检测工件变更后追加 `## L3 重审` 段；(2) .done 条件写入——仅 `L3_verdict=pass` 写 .done，fail/timeout 不写；(3) transition .phase 四字段同步——9 处 transition jq（6 prompts + GO.md + 31-auto-advance.sh + 4-dev.md + pipeline-gates.md）全部加 `.phase` 字段。12 files, +94/-65, 22 bats tests, 441 全量回归 0 fail · pipeline 全 L2（L2 用 haiku） | L-030 resolved, L-031 |
| 2026-07-07 | `l2-l3-fix-compliance` | L2/L3 review 发现强制代码修复：双层防线杜绝 agent "文档敷衍"——Prompt 层修代码优先协议（5/6/7+L2-blind-review 含 `Fixed in:` 分类标记）+ Hook 层实效性校验（fix-compliance.sh lib · 纯文档 diff 检测 + 逐发现文件校验 · fail-closed · 仅 5/6/7 触发）+ CRITICAL fix（无声明绕过修复 · `missing*2>=total` 整数除法修复 · 单声明豁免修复 · 路径归一化）· 26 new bats · 34 gate tests 0 regressions | L-023 |
| 2026-07-07 | `l3-feedback-visibility` | L3 审查结果反馈可见性修复：F1 PreToolUse 路径 L3_RESULT stdout 输出（移除 2>/dev/null + 握手文件自动创建）+ F2 SessionStart 路径替换旧握手文件检测为 .done + L3 段检测（per-field banner 显示）+ F3 l3-review.sh summary 三层提取 + 第四层故障降级（verdict=error）+ _l3_format_result() 共享格式化函数 + gate_config 参数正确传播（6 参数 timeout wrapper）+ verdict 值域校验 · R1/R2/R3/R6 gate 逻辑修复（L3-only 独立分支/L2-only exit 0/L2-wait gate/类型守卫）· 38 bats 全绿 · 384 全量回归 0 regressions | L-022 |
| 2026-07-07 | `dual-review-merge-fix` | L2/L3 双层审查合并写入修复：D1 both L2-wait gating（29 hook + PreToolUse 双路径）+ D2 L3-only L2_verdict=skipped + D3 both .done defer + D4 append-first + L2-only KVP .done + done-validation skipped 值域 · 14 new bats · 346 全绿 | L-new-1 (5th param 传递链完整性), L-new-2 (phase_name 三处重复) |
| 2026-07-06 | `l2-l3-granular-gate` | L2/L3 独立审查开关拆分：gate_config 支持 L2/L3/both 三值 + fk_independent_review_gate_active tier 参数 + 29号 hook L3 跳过 + 6 prompts 适配 + flow skill --l2-only/--l3-only · 12 bats · 321 全绿 | — |
| 2026-07-05 | `health-fix-2026-07` (2nd) | 健康巡检修复：correction-file merge 策略 + jq goal 解析去重（pipeline-goal-parser.md）+ done-validation.sh 拆分 + validate_staging.sh 拆分 · 净 −223 行 · 309 bats 全绿 · full pipeline 0→7 | L-021, TD-005 |
| 2026-07-03 | `pipeline-fallback-fix` | **修复阶段**：完整修复 DIAGNOSIS.md 全部 6 发现（P0×3 + P1×3 + P2×2 = 9 项）。L3 前置 PreToolUse hook (l3-review.sh 共享lib) + gate_config 快照同步 + 三向 gate 方向判定 + auto_advance/fallback hook 兜底 (31/32 号模块) + .done 6键统一 + Tier1 verdict 检查 + GO.md fallback 路由 | L-016 |
| 2026-07-03 | `pipeline-fallback-fix` | 诊断 pipeline 自动推进 + 回退模式：0→7 全链路 dogfood 诊断，发现 6 个 🔴 → DIAGNOSIS.md 18K + 9 条修复建议 | L-016 |
| 2026-07-01 | `health-fix-2026-07` | 修复 `package-flow-kit.sh` 末尾孤儿 `fi`（581-587 残留碎片）导致 `bash -n` 失败 + 正常打包退出码非 0 · 新增 5 回归测试（AC-1~4：package 专项 + 全量 `bash -n` 门禁 smoke）· flow-health SKILL 增补步骤 2.6 全量语法门禁（AC-5，堵 2026-06-30 巡检盲区）· 181 bats 全绿 | — |
| 2026-06-29 | `robustness-hook-hardening` | 弱模型鲁棒性 Hook 化升级：Stop hook 28 号模块 L1+L2+L3 系统级事后验证 + 统一矫正文件 `.flow-active.correction` + SessionStart 矫正注入 · 283 行净逻辑代码 · 14 个新增 bats 测试 · 176 tests 全绿 | L-014 |
| 2026-06-29 | `lessons-cleanup` | 消除 LESSONS.md 三条活跃技术债：L-013 归档双向校验（清理工作目录+扫描孤儿change）+ L-012 打包完整性校验（--validate）+ L-010 1.8 破坏性变更自动 bats 验证 · 16 bats tests 全绿 | L-010/L-012/L-013 |
| 2026-06-29 | `quality-baseline` | 质量基础设施补强：E 协议 DRY（pipeline-gates.md + check-gate-sync.sh）+ F Makefile（test/lint/check/all）+ pre-push hook + G stop 链 smoke test（12 tests）+ H shellcheck 集成 + I test 双源 diff 校验 · 122 bats 全绿 | — |
| 2026-06-25 | `weak-model-robustness` | 提升 flow-kit 弱模型（幻觉多）鲁棒性 · L1+L2+L3 三层防御：RULES R3.5 禁跳反问 / R6.1 引用前证据链 / R7.4 动手前复述边界 + SYSTEM 原则节 + GO goal 锚定 + 4 prompts 反问gate/证据链/checkpoint/复述边界 · ADR-001 protect-the-weakest · 8 bats + 3 regression-demo check.sh · 102 bats 全绿 · 全链路 pipeline 0→7 | — |
| 2026-06-22 | `fix-pcsc-gaps` | 补齐 PCSC 表两个缺失检查项：7-integration 新增 T-FIX 关闭检查行 + 6-review 新增 CONTEXT 技术债写入检查行 | — |
| 2026-06-22 | `security-privacy-audit` | 安全与隐私泄露全面审查（push 前最后防线）：六大维度（凭证/路径/PII/注入/端点/Git历史）全量扫描 · 零🔴Critical 发现 · 60🟡WARNING（仅.specs/归档路径）· 判定：✅ 可安全 Push 公开仓库 · full pipeline 0→7 自动执行 | — |
| 2026-06-22 | `fix-shim-bin-path` | 修复 brooks-tools 离线安装失败（3 轮迭代）：① .js→wrapper + chmod 兜底 ② npm install 安装依赖 + jq 解析 bin 字段（兼容对象/字符串）③ printf 防注入 + 安全校验 · 4/4 工具 --version 通过 · bundle 27M (10699 文件) | — |
| 2026-06-22 | `docs-sync` | 三文档同步更新：FLOW-KIT-用户指南.md §8 新增 brooks-tools 离线打包 · README.md 结构树 + 快速开始修正 · flow-kit-ecosystem-guide.md 新增 PCSC/PG/Rollback/brooks-tools · 全局版本号 + 过时内容清理 | — |
| 2026-06-22 | `bundle-packaging` | brooks-lint npm 工具离线打包：package-flow-kit.sh 新增 Part G（npm pack 4 工具 + 依赖树）· install_brooks_tools.sh 新建（shim 生成 + PATH 检测）· install.sh 集成 check_node + --no-brooks-tools flag · 5 个 bats 测试 · 全链路 0→7 pipeline 自动执行 | — |
| 2026-06-22 | `docs-update` | 更新 FLOW-KIT-用户指南.md (+145行)：新增 §4.1 Goal 系统与 Pipeline 执行模型 | — |
| 2026-06-18 | `integrate-goal-command` | 整合 CC /goal 到 flow-kit：.flow-active goal 字段 + /flow goal 子命令（set/status/clear）+ GO.md/4-dev.md/resume hook 集成 + 内置回退 + AC 自动提取 + 7 bats 测试 | — |
| 2026-06-17 | `debt-cleanup` | 清理剩余技术债（3 合 1）：STAGING 前置校验 · CONFIG_FILE 覆盖修复 · jq bracket 引用防连字符解析 | L-005/L-009/L-011 resolved |
| 2026-06-17 | `bundle-packaging` | 修复打包脚本 Part E 漏 `lib/` 目录导致安装失败；打包 v20260617-171947 验证通过 | L-012 |
| 2026-06-16 | `health-fix` | 健康巡检修复（7 项技术债）：引入 bats-core 28 测试 · hooks 去重 · install.sh 拆分（517→202行+4 lib）· 魔法数字 readonly · 外部路径 fallback · settings.json 去重 · brooks-lint 动态版本号 | L-009 ~ L-011 |
| 2026-06-14 | `brooks-lint-hook-fix` | brooks-lint SessionStart hook 空 commands 目录容错：cp glob → for f + [ -f ] 保护；package-flow-kit.sh 安装后自动修补 hook | L-006 |
| 2026-06-10 | `fix-brooks-bundle-full` | 全包 offline brooks-lint 安装修复（5 合 1）：(1) installed_plugins.json 写 CC v2 格式 (2) installPath: marketplaces→cache (3) 双写 cache+marketplaces (4) known_marketplaces.json 注册 (5) 移除 F1 commands 防 skill 重复。含 --reinstall 全量清理。全量 E2E 测试通过 | — |
| 2026-06-09 | `user-scope-install` | 支持 flow-kit 核心引擎 user-scope 全局安装：install.sh --user + flow-go FLOW_KIT_ROOT 两级查找 + symlink 方案。修复 jq 退出码 5 导致 hooks 静默不安装的 bug | — |
| 2026-06-09 | `hook-user-scope` | Hook 系统 user scope 支持：--user flag + common.sh CONFIG_FILE 优先 ~/.claude/ + 全组件双 scope 审计（7/7 通过） | — |
| 2026-06-08 | `install-update-reinstall` | install.sh 增加 --update（版本比对智能跳过）和 --reinstall（清空重装），.flow-kit-version 版本标记 | — |
| 2026-06-08 | `offline-brooks-bundle` | 打包脚本 Part F 离线化：rsync 本地缓存替代 git archive（三级优先级：--brooks-src > 本地缓存 > git archive），自动版本选择 | — |
| 2026-06-08 | `init-git-repo` | 初始化 Git 仓库（main 分支 + Conventional Commits），建立 .gitignore / README / 技术债基线（LESSONS.md 5 条），同步 CONTEXT 和 STATE | L-001 ~ L-005 |
- **pipeline-goal** (2026-06-18): Goal 从单阶段自循环扩展到跨阶段 Pipeline — 6 files, +396/-15, 12 AC covered, review passed

## 2026-06-22 — pcsc-audit-v2

PCSC/PG 双层防护全面审计（12 项发现：1🔴 + 4🟡 + 7🟢）

| # | 严重度 | 维度 | 简述 |
|---|---|---|---|
| A1 | 🔴 | Logic | 0-change 没有 PCSC 段 |
| A2 | 🟡 | Logic | 1/2/3 toll-gate 缺少 auto_advance 分支 |
| B1 | 🟡 | Coverage | 7-integration 缺少 Sub-goal 汇总 |
| C1 | 🟡 | PCG | Phase 4 PCG 不检查 SUMMARY 文件 |
| D1 | 🟡 | Install | 安装脚本无文件级校验 |
| A3 | 🟢 | Logic | 4-dev 选项4说明过时 |
| B2 | 🟢 | Coverage | 7-integration 缺少出PR步骤 |
| B3 | 🟢 | Coverage | 4-dev PCSC 未显式检查 self-review |
| B4 | 🟢 | Coverage | 5-test 矩阵/UAT 子步骤未展开 |
| C2 | 🟢 | PCG | PCG 延迟到下次路由触发 |
| C3 | 🟢 | PCG | PCG 表无 phase 7 |
| D2 | 🟢 | Install | 无 post-install 自检 |

## [weak-model-interactive-ui] — 2026-06-29

### 变更摘要

弱模型交互式 UI 触发强化：hook 脚本为主防线 + prompt 轻量护栏为辅，确保弱模型在 flow-kit 交互 gate 处实际调用 `AskUserQuestion` / `EnterPlanMode` 工具。

### 新增

- `hooks/stop/27-interactive-ui-check.sh` — Stop hook 模块：检测弱模型是否跳过了交互 gate
- `hooks/stop/lib/interactive-ui-check.sh` — 交互 UI 检测逻辑库（GATE_MAP + 检测函数 + 矫正文件管理）
- `reference/interactive-ui-guard.md` — Prompt 层护栏参考模板
- `regression-demos/weak-model-interactive-ui/` — 回归演示（模拟 transcript + check.sh）
- `test/test_interactive_ui_check.bats` — 24 个 bats 测试
- `stop-hook.json` 新增 `interactive_ui_check` 模块开关

### 修改

- 8 个 prompt 文件（GO.md + 7 个阶段 prompt）— 13 处轻量护栏（≤3 行/点）
- `session-start/flow-kit-resume.sh` — 矫正文件检测 + 矫正 banner 注入
- `package-flow-kit.sh` — 新文件打包覆盖
- `CONTEXT.md` — 术语 + 已锁决策更新

### 架构决策

- 双层防线：hook 脚本（系统级不可绕过）+ prompt 护栏（预防 ~60% 跳过）
- GATE_MAP 集中维护 9 个交互 gate 关键词映射
- 矫正文件 `.flow-active.interactive-ui-fix`（不入库）跨 turn 传递
- 连续跳过 ≥3 次时停止自动矫正提示人工介入

### 测试基线

309/309 tests pass（29 new + 280 existing）
| 2026-07-01 | independent-review | L2 盲审 + L3 hook 强制独立 review（1/2/6 阶段，默认关闭）| — |
| 2026-07-01 | sweep-fix-2026-07 | 修复全量健康扫描 6 项技术债（hook列表去重/查表驱动/correction统一/bats安装/格式审计/注释） | — |
| 2026-07-01 | test-harden-sessionstart | SessionStart 测试从骨架升级为真实 hook 执行测试（7+5 用例） | — |
| 2026-07-02 | independent-review-gap | 补齐 L2/L3 独立审查 3/5/7 缺失：prompt 段 + PRESET_MAP + L2 checklist + 全链路同步 | L-016, L-017 |
| 2026-07-03 | flow-active-integrity | L2+L3 .flow-active 状态完整性检查：8 prompt PCSC + 33 号 hook 模块 + 19 bats tests | L-019, L-020 |
| 2026-07-03 | l3-review-hardening | l3-review.sh 6 项修复：F1 新文件/F2 全产物/F3 幂等/B1-B4 DeepSeek 兼容 | — |

## 2026-07-07 — l3-comprehensive-fix

### 修复 (fix)
- **L3 header 不匹配**: `flow-kit-resume.sh` grep `## L3 外部模型审查` → `## L3 盲审`（+ 旧 header 兼容）
- **L3 截断假阳性**: `l3-review.sh` 新增 `smart_truncate()` 智能截断（保留标题 + AC 行 + 截断上下文告知）
- **.done 重复触发**: `29-independent-review.sh` Gate 5 增加 "skipped" 日志 + pipeline-aware phase 检测
- **L2 自动拉起断裂**: 新建 `l2-detect.sh` lib，PreToolUse gate + Stop hook 双层 L2 检测 + AC-5 三选项交互

### 新增 (feat)
- `fk_resolve_phase()` — pipeline-aware 统一 phase 解析（`common.sh`）
- `l2-detect.sh` — L2 检测 + 一键派发命令生成 lib
- `smart_truncate()` — 智能截断算法（两遍扫描，保留标题 + AC 行）
- AC-5 交互：`FLOW_KIT_SKIP_L2` 环境变量 + `.skip-L2-<phase>` 标记文件

### 测试
- 25 new bats tests (phase-resolution / l2-detect / done-skip / done-validation / l3-header-detect / l3-truncation)
- 30KB L3 截断测试夹具 (`test/fixtures/l3-truncation-30k.md`)
- 全量回归 384 tests / 0 failures

### Prompt 加固
- 6 个阶段 prompt 的「独立 review 调度」段增加 L2 醒目标注


## 2026-07-09 · fix-gate-test-setup（修 TD-013 · test_gate_integrity 多重假绿）
setup 去 set+e + 补 HOOK_BASE_DIR（fk_validate_done_marker 加载）+ helper 补 artifacts= KVP + 17 条测试体改 run+$status + 范围外 skip 归因（#19/#20 TD-014 · #11/#12/#23 TD-016）。bats 18ok/5skip/0fail · make test 407 全绿 · 反向断言有效。降挡（无 L2/L3）完成。揭示 TD-016（断言债）+ 为 TD-014 提供可信测试基础。

## 2026-07-14 · user-guide-ppt-sync（用户指南同步 + PPT + 打包修复 + 离线 bundle）
**Commits**: `9d6e308`, `749ec36`
**范围**:
- FLOW-KIT-用户指南.md 同步至 20260713：+139/-34 行，模块数修正 (13→17)、Hook 表补全 (31/32/33)、PreToolUse 新增 auto-checkpoint、L3 异步化描述、§9 新增 ppt-diagram-pipeline skill 文档
- flow-kit-用户指南.pptx 生成：18 页 / 4 图表 (dot×3 + mscgen×1)
- 打包完整性修复：rsync 三路 exclude 对齐 (L272/L298/L290 git-archive)、validate_staging.sh find→command find、docs/ assets/ git rm (16 files)
- 全包离线 bundle: flow-kit-full-20260713-143435.tar.gz (26M)
- user-scope 同步：核心引擎 goal-parsing.md + 6-review.md + 7-integration.md + brooks-lint cache
**审查**: L2 DeepSeek-V4 + Haiku 两轮跨模型盲审（用户指南） + L2 Sonnet + Haiku 修复前/后四轮审查（打包修复） + 三方安全审查（主 agent + Sonnet + Haiku）
**LESSONS**: L-044（用户指南同步检查清单）、L-045（bundle validate 环境依赖）、L-046（L2 dispatch PreToolUse 方案设计）
| 2026-07-25 | l3-review-timeout-token | 修复 L3 工具硬编码 max_tokens:8000 + curl --max-time 90 致 deepseek-v4-pro 扩展思考吃满预算 → rc=3：三 env var 全可配（MAX_TOKENS/TIMEOUT/THINKING）+ Fail-safe + 可观测性 + jq -c。pipeline 0→7 gate_config=both。解套 gate-done-authorship。 | L-056 |
| 2026-07-25 | gate-done-authorship | 修复 gate .done 作者性安全缺口：方案 A——废弃握手，path-guard D7 扩展保护 .done（_is_dotdone_write + _gate_is_l2_only）+ 删 done-validation T3/T3b + 29 号改用 .done 幂等。23 tests + 613 bats 全绿。Pipeline 0→7 gate_config=both。被 l3-review-timeout-token 解套后完成 | L-057 |
| 2026-08-03 | `superpowers-absorb-followup-1` | L-064+L-065+L-067 测试补强（11 new bats + 2 fixed, 657/657 pass, 0 fail, 1 skip L-071） | L-069, L-070, L-071, L-072 |
| 2026-08-03 | cleanup-debt-batch-2026-08 | L-068/069/071/072 债务清理 · 4-dev.md 781→352 · review-package ref validation · 29 hook reorder · M-health.md cp | L-070 verified non-bug · TD-071-A/B new pre-existing |
| 2026-08-03 | final-debt-cleanup-2026-08 | 10 项积压债务一次性清理：L-058/060/062 (ADR-019 writing principles) + L-061 (ADR-020 OpenCode task snapshot) + L-063 (ADR-021 weak model degradation designed) + L-066 (AC-B4 combined metric test) + TD-071-A/B (verified non-bug) + TD-008 (l3-review.sh split 875→5 files) + TD-017 (l3_review_run split) + TD-018 (independent-review-gate.sh split 597→4 files) | LESSONS L-058/060/061/062/063 ✅ · TD-008/017/018 ✅ · 662/657 ok bats |
| 2026-08-03 | test-failures-fixup-2026-08 | 5 pre-existing bats fail 全部修复 (gate regex + 4-dev §1.8.4 + shellcheck SC2148) | TD-073/074 |
| 2026-08-03 | td072-lib-split-2026-08 | l3-api.sh + gate-helpers.sh 职责拆分（聚合入口模式）· 662→666 tests | - |
| 2026-08-04 | test-coverage-gap-2026-08 | 闭合 TD-002 v2 deferred：补 4 coord module smoke (01/20/21/25) + fk_auto_phase + fk_boundary_check unit tests (16 tests 新增) | L-058/060/062/063 闭合 |
| 2026-08-04 | debt-audit-resolve-2026-08 | 老债务审计：8 项已隐式解决（TD-004/005/019/020/021/022 + L-019/021/022 标记 ✅），新增 phase-prompt-template.md 文档化结构性 PCSC 模板 | TD-004/005/019/020/021/022 + L-019/021/022 |
| 2026-08-04 | debt-audit-resolve-2026-08 (round 2) | 4 项流程规范类债务技术闭合：L-015 PreToolUse guard / L-020 dispatch smoke / L-031 L2 cross-file grep / L-004 obsolete | L-015/020/031/004 |
| 2026-08-06 | archive-commit-gate | 归档流程完成后自动 commit 加入 flow-kit（pre-commit 门禁 + Stop hook 34 + SessionStart + install deploy + bats 714/0）| L-075,L-076,L-077 |
| 2026-08-06 | pre-commit-user-scope | deploy_pre_commit guard 后移修复 user scope 源文件安装（install_file 无条件前置 + guard 后移只控 symlink）| — |
