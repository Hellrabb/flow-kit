# Minor Findings Deferred to Phase 7 Triage

> 来源：INDEPENDENT-REVIEW-1.md L2 盲审（2026-09-29）。按 Severity Gating 协议，🟢 不入 fix loop，phase 7 由用户 triage。

| # | Task | Finding ID | Description | Deferred reason | Date |
|---|------|------------|-------------|-----------------|------|
| M1 | （TEST 派生时） | R7 | AC-2 首断言「源文件不残留修改」在 AC-1 沙箱化后恒真；「kill 时点」无 sentinel 确定性构造，靠 sleep 撞时点会抖动 | Minor，不入 fix loop；TEST 阶段派生 AC-2 用例时按 Remedy 双断言 + sentinel 轮询落实即可，REQUIREMENT 层不改 | 2026-09-29 |
| M2 | （TEST 派生时 / 2-design） | R8 | 五处软判定口径待硬化：AC-10「计数或时长二选一」（应固定 PATH shim 计数法）、AC-9「或仅存行为语义断言」边界（应给残留白名单正则）、AC-11 阈值与白名单机制待 2-design 回填（Then 预设结论措辞届时修订）。注：AC-5 远端复核与依赖段 C5 顺序两处已在 L2 响应中就地硬化，不在此列 | Minor；其余硬化点在 2-design/TEST 阶段自然承接，REQUIREMENT 层不再返工 | 2026-09-29 |
| M3 | （7-integration） | L2-阶段2 · R13 | ARCHITECTURE.md 基线数字过时：§3「ADR 最大 027」vs 实有 028–032；§6 bats 基线 213 vs ≥1116；§2.1「Stop 链 14 模块」vs 实测 18 编号模块 | Minor，不入本 change fix loop；7-integration 与 ADR-030 决策 3 的 §2.2 增补行同提交更正，避免规格文档双改 | 2026-09-29 |
| M4 | （C14-f/D8 落地任务内） | L2-重审 · R5 | check-path-privacy.sh:93-95 三条 09b SELF_EXCLUDE 条目指向已归档死路径（实存 .specs/archive/2026-09-28-health-fix-2026-09b/）；:84 注释与实测漂移（REVIEW-3 现真名=0） | Minor；D8 配置化 09b 硬编码时同步删改死条目与注释（指向归档实址，或随 AC-4 脱敏完成直接移除豁免） | 2026-09-29 |
| M5 | （check-gate-sync 扩展任务内） | L2-重审 · R6 | 预设名第五载体 FLOW-KIT-用户指南.md（分发面枚举预设名）未入 §9.3 集合比对——已定：**五载体**（SKILL/bats/dsh JS/gate-helpers.sh:26/用户指南） | Minor；check-gate-sync 对指南同款名集合断言或显式豁免+登记，TASK 承接 | 2026-09-29 |
| M6 | （check-skills-sync 落地任务内） | L2-重审 · R7 | 14 对配对映射无常权威表，@see 派生配对检测不了置换错配 | Minor；TASK 定死映射（SKILL frontmatter `prompt:` 自声明或检查器内置 14 对表）+ 反向用例（交换两 @see 目标必红） | 2026-09-29 |
| M7 | （29-independent-review.sh C4 同批） | L2-重审 · R8 | 同文件其余 ||true 未逐位点 triage（:96,:97,:159,:214,:220,:232,:237,:250,:273,:281,:297,:304,:313），其中 :237 l2_dispatch_prompt 吞 L2 派发失败与 C4 同类 | Minor；TASK 附逐位点 triage（有意·Stop 链韧性/同类须修/v2），:237 建议同批修（前置捕获 + warning） | 2026-09-29 |
| M8 | （ADR-031 落地批） | L2-三审 · R6 | fk_resolve_phase vs flow-active-query 双「唯一入口」边界未声明 | Minor；ADR-031/§9.3 补一句：「hook 链内 phase 解析维持 fk_resolve_phase（common.sh，白名单登记）；链外脚本/Makefile 一律 flow-active-query.sh」 | 2026-09-29 |
| M9 | （7-integration） | L2-三审 · R7 | ARCHITECTURE §3「ADR 编号最大值 027」滞后（实至 032，028/029 亦未追认）——TD-041 撞号土壤 | Minor；7-integration 与 M3 同批更正（027→032 含追认）；A-evolve 清单加「取号前实跑 grep」 | 2026-09-29 |
| M10 | （TEST 派生时） | L2-三审 · R8 | AC-9 残留机检 pattern 只覆盖单引号 $content 形态（实测 2/32 位点，:1241 双引号形态盲区） | Minor；TEST 阶段判据放宽到双引号族或按 C6 32 处清单做位点对账（改后文本断言计数 = 0） | 2026-09-29 |
| M11 | （T09 AC-17 承接） | L2-阶段3 · R11 | AC-17②「裸仓并发 dry-run」验证夹具无落点（任何 task 的 write_files 均未建夹具） | Minor；T09 执行时 mktemp git init --bare 双并发 push --dry-run 钉住 flock 闸（夹具随测试建，不占常设文件） | 2026-09-29 |
| M12 | （4-dev 执行时） | L2-阶段3 · R12 | T01 write_files 冗余授权 gate-helpers/gate-checks-basic/gate-checks-review 三子库（任务只需 declare -f 断言与 mock 注入，写授权虚增冲突面） | Minor；4-dev 执行 T01 时三子库按 read-only 对待（write_files 收敛在 wave 执行器侧处理，不改 TASK 结构）；真需改时走 Fix 任务 | 2026-09-29 |
| M13 | （T16 执行时） | L2-阶段3 · R13 | 杂项锚漂移：l2-detect.sh 探针实为 :33（TASK 写 :35）；AC-7 溢价措辞「90+」vs 实测 mock ×72；T16 缺重写前净树断言（scrub-history.sh 未入 DESIGN 清单一项**已就地补登**） | Minor；dev 执行时以实测锚为准（:33 / ×72）；T16 启动前加 `git diff --stat` = 0 + `git status` 净树断言（防未提交改动被 filter-repo 吞） | 2026-09-29 |
| M14 | （7-integration） | L2-阶段3 · R14 | AC-13（总门禁 make check 全绿）与 AC-14（反哺销账）在 TASK 无显式归属任务（AC-16 Given 侧已实测成立：STATE.md:71 ✓ TD 基线 132 ✓） | Minor；AC-13 归 T16 后回归批（历史重写后全量 make check）；AC-14 归 7-integration 反哺批（TD-134…138 销账 + LESSONS）——两处归属在 4-dev wave 执行时口头声明即可，不改 TASK 结构 | 2026-09-29 |

---

## L2 r5 🟢 延后项（阶段 3 · 2026-09-29）

### M15 · T05 变量间接形态种子命令补全（R7）
- **位置**: TASK.md T05 action（变量间接形态入域）
- **观察**: 谓词已含变量间接形态，但种子示例仅 `X="$HOME/…"` 直赋值一种；实际存在子命令拼接形态（如 `dir=$(dirname "$0")` 后拼 `$dir/…`）。
- **处置**: T05 执行时以全变体谓词重扫为准，种子命令形态仅作参考——不阻塞，执行时自然覆盖。

### M16 · CHANGE C5 mock 计数口径标注（R8）
- **位置**: CHANGE.md C5 段（mock ×92）vs TASK.md T07（×72）vs L2 多轮实测（×72）
- **观察**: CHANGE 早期写作 ×92，后续实测收敛 ×72，TASK 与审查均已按 72 核对。
- **处置**: 7-integration 反哺批在 CHANGE C5 段补一行口径标注（92 为初稿统计、终值 72）——避免未来读者困惑。

### M17 · T12a 体量超限维持已登记处置（R9）
- **位置**: TASK.md T12a
- **观察**: 16 载体 + ≈52 条款超单任务 ≤200 行指引；步骤①侦查处置门槛 + T12b 反向门禁兜底已登记（L2 r4 R8）。
- **处置**: 维持现状——不拆分（拆分会破坏「侦查处置→薄壳化」原子性），执行时若发现体量失控再升级。

### M18 · T15 hook_integration 位点现状描述偏大（R10）
- **位置**: TASK.md T15 action（test_hook_integration.bats :17,:20-22,:31,:34-37「改行为断言或显式 skip」）
- **观察**: 实测这些位点现状已是显式 skip（打印原因），实际修复面 = 断言强化而非从零改写。
- **处置**: T15 执行时按实际现状收敛叙述——修复动作不变（强断言或维持 skip + 断言输出形态），不阻塞。

### M19 · D9 内 C10 卸载清理判据零任务承接（L3 阶段 3 m2）
- **位置**: DESIGN.md D9（:128 附近）子决策「卸载清理判据 = 安装清单文件化（install 记录 → uninstall 按单删，残留 diff=0）」
- **观察**: 该子决策是 D9 讨论卸载语义时顺带记录的方向，无任何 TASK 任务承接；且与 CHANGE C10（lint 语义化）同名异义，易混淆。
- **处置**: 显式 defer——v1 不做（不在本 change 范围），登记 TD 由 7-integration 反哺批评估是否立项 v2；本 change 内不作为验收项。

### M20 · REQUIREMENT AC-6「stderr 含告警」与 D6 module_output 通道措辞分歧（T02 执行偏差 ①）
- **位置**: REQUIREMENT.md AC-6 散文 vs DESIGN.md D6 + flow-kit-bundle/hooks/stop/lib/common.sh:177-182
- **观察**: T02 已按 D6 钦定通道（module_output → 写 $HOOK_TMP_DIR/independent-review.txt）断言文件内容，测试 4/4 绿；但 REQUIREMENT 散文写「stderr 含告警」，5-test 若按字面 stderr 断言会对不上。
- **处置**: 以 D6 为准（L2 阶段 2 多轮收敛钦定通道；REQUIREMENT 措辞为早期散文遗留）。5-test/L2 审查按 module_output 文件面判 AC-6；7-integration 反哺批在 REQUIREMENT 下一版对齐措辞（阶段 4 内不改 REQUIREMENT——R3.2）。

### M21 · 健康报告 D-3 勘误：validate_staging_coverage 非死代码（T14 执行发现）
- **位置**: .specs/health/2026-09-29-HEALTH.md D-3 名单；仓库根 package-flow-kit.sh:16（source）+:18（生产调用）
- **观察**: D-3 将 validate_staging_coverage 列为死代码候选，但健康扫描漏查仓库根脚本——package-flow-kit.sh（打包完整性门禁）生产调用它。T14 判定「留」正确；报告 D-3 该项失实。
- **处置**: T14 已在 CHANGE.md 14c 段登记判定；本条勘误归 7-integration 反哺批（HEALTH.md 为已交付报告不改写，勘误记录于此 + TD 侧评估是否更新 TD-138 名单口径——TD-138「死代码 7 处」计数随本勘误与 T14 判定实际收敛为 1 删 6 留）。

### M22 · 同构夹具生成器收敛（T03 自报 + L3 阶段 5 m1 扩面）
- **位置**: test/test_check_gate_sync.bats（FXC1:66 / FXB10:128 / FXB25:170 / FXB18:211）+ test/test_skills_sync.bats:32（FXS · T12b）+ test/test_gate_config_carriers.bats:63（FXC5 · T17）——全仓同族 6 处横跨 3 文件（mktemp -d + $SBX/fk 树 + cp 生产件形态）。
- **观察**: T03 执行时点 FXC1 为该文件第 4 个同构生成器（自报 defer 属实）；后续波次 T12b/T17 又各增 1 处，TEST.md 六维自检 T3 行「命中文件数 1」按文件内口径成立但低估现状（L3 阶段 5 m1 实测扩面）。
- **处置**: defer 到 v2——收敛为共享 helper（reference/ 下 fixtures.sh 或 bats load 机制）；六维 T3 严重度维持 🟡（无判据力损失，纯维护性债务）；镜像侧 flow-kit-bundle/test/ 同步收敛。

### M23 · check-gate-sync.sh 双判据域单文件增长（阶段 6 主审 R4 发现）
- **位置**: flow-kit-bundle/flow-kit/reference/check-gate-sync.sh——T07 键值对同步判据（34 对）与 T17 五载体集合判据 + 指南折算表同住一文件（本 change +618 行级改动）。
- **观察**: 两域各自成节、共享文件级头注释与 rc 汇总；当前规模仍自洽（check-gate-sync rc=0 + carriers 15 用例绿），但任一域再增长时头注释/rc 汇总/测试锚三处耦合面放大。
- **处置**: defer——下次任一判据域增长时拆分 check-gate-sync-pairs / -carriers 两入口（make target 不变，薄壳转发）；REVIEW.md 2.2 R4 条目为权威记录。
