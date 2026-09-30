# 独立审查 · 阶段 3

## L2 盲审

⚠️ 独立性受损（轻度 · 记录在案）：为核验 T06 脱敏范围而全仓 grep 真名字符串时，命中本 change 目录 INDEPENDENT-REVIEW-2.md:233 单行（该阶段 2 审查的 L-031 锚点核对结论行）——非主动读取、未读全文、未采信其任何判断；本报告全部结论均由本次独立扫描实测自证（各 Symptom 附实测命令与行号）。

**Verdict 速览**：fail —— 🔴×2。TASK 整体工程质量高（行号锚绝大多数实测精确、波次 DAG 无环、同 wave 零同文件冲突、R6 四条偏序全部正确编码），但存在两处 🔴：脱敏范围自破（R1）与 AC-12-b 无 task 承接（R2）。

**实测通过的锚点（抽样全过）**：29-independent-review.sh:200 `|| true` ✓（且 :203 已有 "backlog L3 failed for phase ${pn}" 报文——T02 删 3 字符即激活，方案成立）；independent-review-gate.sh :64/:65/:114 三处 `|| exit 0` ✓、:33-37 declare -f 范式 ✓、:42-46 source 三子库 ✓；auto-checkpoint.sh :5/:11 头注释 fail-open ✓、:64 ✓；common.sh:192 jq_atomic_write ✓（生产零调用 ✓）、:226 jq 断言范式 ✓；check-path-privacy.sh :72 PAT 强制尾斜杠 ✓、:89-95 SELF_EXCLUDE 六行含 4 条 09b 行 ✓、:102 ALLOWLIST_CHANGE 硬编码 09b ✓；Makefile :76 cp 非递归 vs :84 diff -rq 递归 ✓、:250-258 手搓 .flow-active 解析 ✓、AC-12-g 双锚实测=2 ✓、flow-active-query 现值=0 ✓；package-dsh-plugin.sh :183 --check 早退 ✓、:233 node --test ✓；pre-push.sh 全文 0 flock ✓、.git/hooks/pre-push 现状=裸 make check ✓；test_l3_pipeline_fix.bats:561-564 真空通过 ✓；test_hook_integration.bats :17,:20-22,:31,:34-37 grep 探针 ✓；test_l3_review_defects_2026_09.bats:88 硬编码 SHA be138c0 ✓；4-dev.md '1\.8 触发时 bats'=1 ✓、:99-106 内联表 ✓；l2-reviewer.md 198 行、:36-198 跨度恰 163 行 = L2-blind-review.md 全文 163 行 ✓；mock `"independent"` ×72（test/ 与镜像一致）✓；'L2-first 契约未满足' 全仓=4（生产 :138/:239 + 测试 :55-56 ×2，T11 数学 2→1/2→0 成立）✓；tarball ×2（27.6M/25.7M，均 gitignored——T15 纯文件系统删除，无 R7.3 越界）✓；skills 16 个 flow-* 目录 + 14 个 prompts，16−2 豁免（flow-go→GO.md 实存 ✓、flow-kit-install）=14 对 ✓；ADR-030/031/032 已建 ✓；STATE.md:71 C9 降级登记存在 ✓；TD 基线 CONTEXT.md =132 ✓；AC-4 前提实测 6 文件 30 行 ✓。

---

### 🔴 R1 · T06 脱敏范围自破：本 change 目录自身含真名，提交即毁 AC-4/AC-5/AC-13
**Severity**：🔴 Critical
**Symptom**：`.specs/health-fix-2026-09c/` 当前 untracked（`git status --porcelain` = `?? .specs/health-fix-2026-09c/`），但目录内实存真名：TASK.md:171（verify 锚自身内嵌 `/home/<realname>` 字面量）、write-done-1.sh:6,:9、write-done-2.sh:6（绝对路径）、INDEPENDENT-REVIEW-2.md:233。T06 的 write_files 只含 6 个既有 tracked 文件，不含上述任何一处。
**Source**：09b 先例（.specs/archive/…/INDEPENDENT-REVIEW-1/2.md 均已 tracked——正是 T06 自己的脱敏对象）；check-path-privacy.sh:87-88 头注释明文「此后新增的审查档一律不豁免……必须由本门禁就地判红」；AC-4/AC-5/US-3。
**Consequence**：T06 的 `git grep` verify 今日转绿只因 git grep 不扫 untracked 文件——绿色是假的。集成/归档阶段提交本目录后：AC-4 tracked=0 破、隐私门禁就地转红、AC-13 make check 全绿不可达；若发生在 T16 历史重写之后，真名 blob 重新进入远端历史，AC-5「任何 clone 拿不到」的保证作废，需再一次不可逆重写。
**Remedy**：T06 write_files 增补上述 4 文件（或删 write-done-*.sh）；TASK.md:171 verify 改运行时组装（如 `git grep -l "$HOME"` 或 `'/home/'…` 拼接），字面量不落任何 tracked 文件；INDEPENDENT-REVIEW-2.md:233 的引文同步占位化。

### 🔴 R2 · AC-12-b（C14-b 预设名多载体比对）无任何 task 承接
**Severity**：🔴 Critical
**Symptom**：AC-12-b 要求预设名集合在 SKILL ↔ bats ↔ dsh-flow-kit JS 三处比对为同一集合 + 任一载体注入漂移必红。实测 JS 载体真实存在（dsh-flow-kit/lib/flow-state.js:6 PRESET_MAP、:94-116 resolveGateConfig、:332-335 值归一），但 16 个 task 的 write_files 均不含 `dsh-flow-kit/**`；gate-helpers.sh:26（DESIGN 定义的第四载体）仅 T01 为 C12 断言而写、action 无 C14-b 内容；用户指南第五载体仅 T12 改 :1585 指名、无集合比对。
**Source**：阶段 3 checklist「覆盖完整性：所有 AC 是否有对应 task」；DESIGN 0.5.1 明列「dsh-flow-kit/lib/（……C14-b：预设名三载体对齐）」「gate-helpers.sh:26（C14-b 第四载体）」+ §9.3 五载体契约——L-031 第 4 类（DESIGN 列出且未覆盖）。
**Consequence**：AC-12-b 无实现者，阶段 5 派生用例即发现无交付或被迫静默跳过；JS 侧 PRESET_MAP 与 bash 侧预设名分叉无人拦——恰是本 change 要消灭的「mock/生产漂移被盖章一致」问题的镜像。
**Remedy**：新增 T17[C14-b 五载体预设名集合比对]：read = dsh-flow-kit/lib/flow-state.js + skills/flow/SKILL.md + test/test_gate_config_presets.bats + gate-helpers.sh + FLOW-KIT-用户指南.md；实现集合断言（挂 check-gate-sync 扩展）+ 反向控制用例（任一载体改一个预设名必红）；依赖 T07/T12，入 wave 4-5。

### 🟡 R3 · AC-15-① SKILL 侧机检锚恒绿：'commit-protocol' 在 flow-dev SKILL 实测 0 命中
**Severity**：🟡 Important
**Symptom**：`grep -c 'commit-protocol' flow-kit-bundle/skills/flow-dev/SKILL.md` = 0（全仓命中仅 4-dev.md:280/:284 @see、reference/commit-protocol.md 自身、test_archive_commit_gate.bats:144/154/155、用户指南:755、phase-prompt-template.md）。T11 action「flow-dev SKILL 13 处 commit-protocol 内联改引用」指向不存在的字面量；AC-15-① 的 SKILL 侧判据（两计数相等）0=0 恒真。
**Source**：判据鉴别力原则（REQUIREMENT 自家 AC-12-g 修订先例「恒绿零鉴别力」；AC 总则「反向控制=修好后必须能转红」）；AC-15-① 已修好另一个锚（'1.8 触发时 bats' 实测=1 ✓），SKILL 侧漏修。
**Consequence**：T11 ① 子项按锚执行=无事可做且判据绿；SKILL 与 commit-protocol.md 的语义重复段（:373 提交前 self-review、:407 diff 边界 verify、:469 原子提交 R4.1、:471 提交格式）继续双源漂移——C8 病灶不闭合。
**Remedy**：锚改内容锚（如删除段标题计数：`grep -c '原子提交\|diff 边界 verify\|提交前 self-review' flow-dev/SKILL.md` 删后=0，@see 行 ≥1）；action 改写为「删 :373-:477 与 reference/commit-protocol.md 重复的提交协议段，替换为 @see + 薄壳声明」。

### 🟡 R4 · AC-9 残留机检锚近恒绿：32 处清单无机器对账
**Severity**：🟡 Important
**Symptom**：AC-9/T10 done 的白名单机检 `grep -rn "grep -q '.*\$content" test/*.bats` 实测仅 2 命中（均在 test_l3_review_defects_2026_09.bats），与宣称的 32 处（18/6/4/3/1）零对应；真实源码文本断言形态是 `grep -q '<字面量>' "$HOOK_29"/"$L2_LIB"/"$GATE"/"$prompt"`（该文件 grep -q 总数=91，行为/文本混杂）。
**Source**：同 R3 恒绿判据类；「32 处」目前仅是断言数字，无清单可核。
**Consequence**：T10 done「grep -v 白名单后残留=0」空转变绿——漏改的文本断言不被发现，C6 修复面可能远小于 32 处而不自知；阶段 5 无法按 AC 派生可信用例。
**Remedy**：TASK 附 32 处「文件:行号」清单表；或重定义锚为「对生产路径变量（$HOOK*/​$L2_*/$GATE/$prompt）的 `grep -q` 行计数 ≥ 降幅阈值」并给基线值与目标值；T10 verify 加该计数断言。

### 🟡 R5 · C14-c 谓词与种子清单严重不符，且 verify 只复核一半谓词
**Severity**：🟡 Important
**Symptom**：CHANGE.md:389 称 11 文件命中 `[ ! -f "$HOME/.claude/…" ] ||` 软跳过族；实测该族全变体（`[ ! -f "$HOME`、`[ -d "$HOME`、正向 `[ -f "$HOME/.claude`）合计仅 2-3 文件（test_independent_review_model、test_l3_pipeline_fix）。种子名单成员 test_runtime_edit_guard.bats 实测为夹具 HOME 自包含（:29 `HOME_DIR="$TEST_TMPDIR/home"`），无机器态软跳过。T05 verify 只 grep 模式 1，模式 2 与更宽形态（skip 全集）无对账。
**Source**：L-031（不信清单、全仓重扫）；判据覆盖完整性。
**Consequence**：若真实「读机器态」形态宽于给定谓词，权威名单系统性漏项 → T15 漏修 → AC-12-c「11 位点逐项处置」口径失真；若 11 系高估，AC-12-c 的 Then 数字未随重核回写 REQUIREMENT（沿「机检修订」先例），阶段 5 按旧数字派生即误判。
**Remedy**：T05 action 增「谓词不完备性论证」义务（对 `grep -n 'skip' test/*.bats` 全集逐文件归类，给出谓词外例外）；verify 补模式 2 与 skip 面双计数；11→N 偏差除回写 CHANGE 外同步修订 REQUIREMENT AC-12-c（显式对账注记）。

### 🟡 R6 · AC-12-a 验证锚恒红：全仓 grep 不可满足
**Severity**：🟡 Important
**Symptom**：AC-12-a 要求 `grep -rn 'jq_atomic_write'` 全仓 = 0；实测 .specs 文档面现存 10+ 处（2026-09-29-HEALTH.md:800,:1056,:1066,:1133,:1151、CONTEXT.md:696 TD-138、07-01-FULL-SWEEP、07-21 TECH-BRIEF、07-24 三文件等）。TASK T14 verify 已自行收窄为 common.sh 内=0（正确但与 AC 判据分裂）。
**Source**：判据可满足性；「AC 是 TEST 阶段派生用例的唯一来源」——按字面派生必红。
**Consequence**：阶段 5 用例恒红，被迫临场裁量，破坏 AC 的确定性；或测试者反向放宽、开静默偏离先例。
**Remedy**：走既有「机检修订」流程改锚：`grep -rn 'jq_atomic_write' --include='*.sh' --include='*.bats' --include='Makefile' flow-kit-bundle/ test/ Makefile` = 0（文档面显式豁免），对账注记日期与理由。

### 🟡 R7 · T09 行号锚指向错误代码块：install_hooks.sh:291-301 不是 pre-push 逻辑
**Severity**：🟡 Important
**Symptom**：TASK T09 action「install_hooks.sh:291-301 换装为调用 pre-push.sh」——实测 :288-305 是 check-path-privacy.sh + allowlist 的 reference 部署块；pre-push 逻辑在 :95-137（is_flowkit_symlink :95-112、deploy_pre_push :118-137，其中 :126 已 `install_file "$SCRIPT_DIR/hooks/pre-push/pre-push.sh"`、:132-137 处理 .git/hooks/pre-push symlink/备份覆盖）。
**Source**：行号锚必须实测（L-031 精神）；R7.3 执行确定性。
**Consequence**：执行者按锚改错块（动 reference 部署逻辑=下游安装面回归）；且 install_hooks 侧「换装」的真实 delta 未定义——deploy_pre_push 既已安装 bundle 脚本，需改什么无判据，task 可能含幻影改动。
**Remedy**：锚改 :118-137；action 写明 delta：核实既有非 symlink .git/hooks/pre-push 的备份-覆盖路径是否满足（:120 注释），若已满足则 install_hooks.sh 移出 write_files，仅改本仓 .git/hooks/pre-push 实例。

### 🟡 R8 · T13 引用的种子工件不存在
**Severity**：🟡 Important
**Symptom**：T13 read_files 列 `.specs/health-fix-2026-09c/path-privacy-baseline/（种子）` 与 `flow-active-inline-whitelist.txt（种子）`——实测目录内均不存在（仅 CHANGE/DESIGN/REQUIREMENT/TASK/PROGRESS/两 review/write-done-*/点文件）。DESIGN 0.5.1 称两者为「种子副本」与仓库现状脱节。
**Source**：R7.3（read/write 清单与实际对账）；DESIGN「读序 常设 > 种子 > 双缺 fail-closed」——种子档缺失使该读序永远测不到中档。
**Consequence**：T13 开工即撞缺失输入：或被静默跳过（fail-open 复辟，与本 change 主題相反），或执行者自造种子与设计定稿分叉。
**Remedy**：要么先补种子（phase 2 欠账，按附录 A 谓词生成白名单种子、按运行时哈希流程备 baseline 种子），要么改 TASK/DESIGN 口径为「T13 运行时从零重建，种子档删除」，二选一并同步 DESIGN 0.5.1。

### 🟡 R9 · T12 粒度超标：四类关注点合并单 task，远超 200 行基线
**Severity**：🟡 Important
**Symptom**：T12 = 16 个 SKILL.md 薄壳化 + 新门禁 check-skills-sync.sh + Makefile 挂链 + 更名触点（test_quality_baseline 断言拆分、双份用户指南 :1585、pipeline-gates.md:4）+ 2 个新测试文件。D2 自认「16 文件大面积改写……触发词须逐字保留」（R1 风险，缓解=「每对改完跑 skill 加载冒烟」——巨型 task 内该缓解形同虚设）。
**Source**：阶段 3 checklist 任务粒度 ≤200 行；小步验证原则。
**Consequence**：16 文件批写出错时回滚面大、review 负担集中；frontmatter 逐字保留的冒烟验证在一次大提交里不可执行。
**Remedy**：拆 T12a（门禁+测试，先转红）/ T12b（薄壳化，可 4×4 分批）/ T12c（更名触点+文档）——保 R6-③「门禁与薄壳化同 wave」即可。

### 🟡 R10 · AC-1 并发双跑验证无任何 task 承载
**Severity**：🟡 Important
**Symptom**：T03 verify = `npx bats test/test_check_gate_sync.bats && make check-test-sync`，未含 AC-1 给出的双跑命令；done 行却宣称 AC-1/AC-2。T08 verify 的 `grep -c flock` 只证存在不证行为。
**Source**：verify 可验证性（行为证据优于静态存在）；AC-1 的核心承诺就是并发安全。
**Consequence**：按文件绿但 make 级并发（test-sync/镜像写竞争）仍可能互踩，缺陷后移到阶段 5 才爆，归因成本高。
**Remedy**：T03 或 T08 verify 追加 AC-1 原文双跑命令（`make check & … wait` 形态）+ `git status --porcelain` 断言。

### 🟢 R11 · AC-17② 行为用例（裸仓并发 dry-run 夹具）无落点
**Severity**：🟢 Minor
**Symptom**：AC-17 验证方式② 要求 bats 夹具（本地裸仓 + 双 dry-run + 状态断言）；T09 不新建/不修改任何测试文件，verify 仅 bash -n + grep。
**Source**：AC 覆盖完整性（①有 grep 覆盖，②悬空）。
**Consequence**：push 通路并发安全无行为用例。
**Remedy**：T09 write_files 增 test/test_pre_push_race.bats（或挂入既有 hooks 测试文件）。

### 🟢 R12 · T01 write_files 冗余授权
**Severity**：🟢 Minor
**Symptom**：T01 write_files 列 gate-helpers.sh / gate-checks-basic.sh / gate-checks-review.sh，但 action 无对应修改（declare -f 断言落 independent-review-gate.sh:42-46 source 侧，三子库本体不改）。
**Source**：R7.3 授权面最小化。
**Consequence**：授权面大于实际改动，diff 边界 verify 对照产生噪音。
**Remedy**：三子库移出 write_files（实现中确需改时再扩）。

### 🟢 R13 · 杂项锚点漂移与前置检查缺失
**Severity**：🟢 Minor
**Symptom**：① test_path_privacy_gate.bats 探针实在 :33（`PROBE="/home/""zz-path-pr""obe/"` 尾斜杠问题真实存在 ✓），TASK 写 :35；② REQUIREMENT AC-7 散文「mock 90+ 处」vs 实测/TASK/DESIGN ×72（判据两侧一致，仅散文不符）；③ T16 新增 scrub-history.sh 未入 DESIGN 0.5.1 新增模块清单；④ DESIGN R5「重写前 git status 必须净」未编码进 T16 action/verify。
**Source**：行号锚实测；R7.3 清单对账；R5 缓解措施落地。
**Consequence**：小：锚漂移致执行困惑；④缺前置净树检查，重写夹带未提交改动的风险无门禁。
**Remedy**：逐项改锚；T16 action 首步加 `git status --porcelain` 空断言。

### 🟢 R14 · AC-13/AC-14 归属未显式声明（AC-16 已核实成立）
**Severity**：🟢 Minor
**Symptom**：AC-13（make check 全绿 + 用例数 ≥1116）与 AC-14（STATE.md 销账 ≥14 行 + TD 增量登记）无专属 task，TASK 未声明由 6-review/7-integration 承接。AC-16 Given 实测已成立（STATE.md:71 存在 C9 降级登记；TD 基线 132 ✓）——AC-16 仅剩验证无实现，无缺口。
**Source**：AC 覆盖完整性的显式性。
**Consequence**：若后续阶段无内置兜底则漏检（低概率，flow-kit 管线通常在 6/7 阶段跑总门禁与反哺）。
**Remedy**：TASK 备注区加一行「AC-13 → 阶段 5；AC-14 → 阶段 7-integration」显式认领。

---

**Verdict**: fail

---

## 主 agent 响应（阶段 3 · 对 L2 盲审 · 2026-09-29）

> R1–R10（2🔴 + 8🟡）全部处置完毕；R11–R14（4🟢）登记 MINOR-DEFERRED M11–M14。

- **R1 🔴 Fixed in**：T06 write_files 补 `INDEPENDENT-REVIEW-2.md` / `write-done-1.sh` / `write-done-2.sh`；action 增 09c 目录同批脱敏（IR-2:233 占位化 + 两辅助脚本用毕删除 + 全目录复扫）；verify 改运行时拼接 `git grep -lF "$HOME"`=0 + 09c 目录（.done 除外）=0；本 TASK.md:171 原真名字面量已随 verify 改写就地消除。
- **R2 🔴 Fixed in**：新增 **T17[C14-b 五载体集合比对]**（write_files: check-gate-sync.sh / flow-state.js / gate-helpers.sh + 新测试 test_gate_config_carriers.bats + 镜像；←T07,T12b；Wave 5）；ACTION 含反向控制（任一载体预设名漂移 → rc≠0，bats 注入篡改钉住）；T16 依赖补 T17。
- **R3 Fixed in**：T11 action ① 改内容锚——'commit-protocol' 字面量实测 0 命中，重复段按 :373/:407/:469/:477 语义段定位，锚用段落特征而非字面量。
- **R4 Fixed in**：T10 action 增「C6 位点清单」节（文件:行号 逐位点回填）+ verify 加逐文件文本探针对账归零命令（`grep -v '# 行为断言' … | grep -cE "grep .*(-q|-c|-rl?).*flow-kit-bundle/(hooks|lib|flow-kit)/"` = 0），机检不依赖全仓单模式。
- **R5 Fixed in**：T05 action/verify 改**全变体谓词**（`[ ! -f "$HOME` + `[ -d "$HOME` 两模式合并去重对账）；权威声明「种子与谓词实测不符处以谓词为准」。
- **R6 Fixed in**：REQUIREMENT AC-12-a 机检域收窄为 `grep -rn 'jq_atomic_write' flow-kit-bundle/hooks/` = 0 + 对账标注（.specs 文档面不计，dist 打包再生不计）——与 T14 verify 对齐，判据可达。
- **R7 Fixed in**：T09 read_files 注明 install_hooks.sh **:95-137 只读参照**（is_flowkit_symlink:95 / deploy_pre_push:118 / install_file:126 已装 bundle 脚本 / symlink 幂等 :132-137——换装机制已存在）；write_files 删 install_hooks.sh；delta 收敛为 ① pre-push.sh 本体 flock ② .git/hooks/pre-push 实例确认/改调。DESIGN 0.5.1 同步改写（原 :291-301 为 check-path-privacy 部署块误标）。
- **R8 Fixed in**：T13 read_files 删两条不存在种子路径，action 改「**首建**常设文件」（DESIGN 附录 A 为唯一规范来源）；DESIGN 新增「首建说明」（种子层取消，读序 常设 > 双缺 fail-closed）并同步 :69/:122/:266 三处读序措辞。
- **R9 Fixed in**：T12 拆 **T12a**（16 SKILL 薄壳化，←T11）/ **T12b**（check-skills-sync.sh + Makefile 挂链 + test_skills_sync.bats，←T08,T12a）/ **T12c**（更名触点：test_quality_baseline 断言拆分 + 用户指南×2 + pipeline-gates.md:4，←T08）；波次图同步重排（Wave 4 = T12a+T12c，Wave 5 = T12b+T14+T15+T17，Wave 6 = T13，Wave 7 = T16）。
- **R10 Fixed in**：T03 verify 增并发双跑两实例 + `test -z "$(git diff --stat)"`（AC-1 双跑判据入 verify）。
- **R11–R14 → M11–M14**（MINOR-DEFERRED 已登记）：M11 = AC-17② 裸仓并发 dry-run 夹具（T09 承接）；M12 = T01 write_files 三子库冗余（4-dev 执行时按 read-only 处理）；M13 = 锚漂移杂项（:33 / ×72 / T16 净树断言；scrub-history.sh 已就地补登 DESIGN）；M14 = AC-13/14 归属显式声明（4-dev 执行时口头认领：AC-13 → T16 后回归批，AC-14 → 7-integration）。

> 独立性说明（回应对审者报告首行 ⚠️）：审者 grep 真名时意外命中 IR-2.md:233 属grep 通道泄漏而非指令污染，该行已列入 T06 脱敏面（R1 处置范围内）。

---

## L3 重审（deepseek-v4-flash-0731 外部模型 · 2026-09-30 01:36）

> 自动生成于 2026-09-30 01:36。由 l3-review.sh 写入。

### 审查结论

```json
{
  "critical": [],
  "major": [
    {
      "file": "TASK.md (T01 write_files + verify)",
      "issue": "T01 的 write_files 同时包含 test/test_fail_closed.bats 与 flow-kit-bundle/test/test_fail_closed.bats，但 verify 仅跑 npx bats test/test_fail_closed.bats && make check-test-sync；check-test-sync 是否校验镜像一致性未在 TASK 中定义，因而验证不足以保证双写镜像正确。",
      "why": "阶段评审要求 verify 可执行且能证伪；若 check-test-sync 只是复制或只校验一侧，flow-kit-bundle/test 下的镜像可能漏检，AC 覆盖不完整。",
      "fix": "verify 增加对 flow-kit-bundle/test/test_fail_closed.bats 的显式 bats 运行，或明确 check-test-sync 对镜像文件做逐字节/内容一致性断言。"
    },
    {
      "file": "TASK.md (T16 write_files 与 verify)",
      "issue": "T16 的 write_files 包含 ../backup-pre-scrub-20260929.bundle（仓外路径），且 verify 要求 git bundle verify，但仓外路径未受 flow-kit 工件变更管理约束，执行器若限制 write_files 于仓库内将无法落地/验证。",
      "why": "write_files 边界要求清晰不越界；跨出仓库根的写入路径与一般 write_files 语义冲突，且 bundle 由 git 命令产生而非“写入”文件，可能导致任务无法自动执行或验证失败。",
      "fix": "将 backup 路径明确为执行期产物（非 write_files 声明），verify 改为检查 bundle 存在且 verify rc=0，同时注明该文件可位于仓外。"
    },
    {
      "file": "TASK.md (T05 depends_on / 执行依赖)",
      "issue": "T05 被标注为 Wave 1 parallel，但 C14-c 权威名单是 T15 修复的依据（T15 ←T05），且 T05 的 verify 用 grep 对账本文件权威名单；名单节当前为空，T05 自身没有对“回填完成”的可证伪校验。",
      "why": "若 T05 执行后未回填或回填不完整，T15 将依据空名单继续，无法满足 AC-12-c 前置；verify 只输出 grep 结果供对账，未自动化判定权威名单已非空且与谓词一致。",
      "fix": "T05 verify 增加断言：本文件 C14-c 权威名单节非空、包含 11 个种子文件名、且与 grep 扫描结果排序后 diff 为空（或输出可机检的清单）。"
    }
  ],
  "minor": [
    {
      "file": "TASK.md (波次注释)",
      "issue": "Wave 5 注释写 T17 ←T07,T12b，但任务 T17 的 depends_on 仅 T07,T12b，未包含 T12a；若 T12b 依赖 T12a，则 T17 经 T12b 间接依赖 T12a，无明显环，但注释与 depends_on 字段的传递依赖未显式化，执行器若只按 depends_on 拓扑可接受。",
      "why": "依赖关系可读性弱，且“同 wave 内串行依赖”依赖执行器按 depends_on 处理，未在 T17 中显式列出 T12a 可能造成人工误解。",
      "fix": "在 T17 的 depends_on 中显式列出 T12a（或注明经 T12b 传递）。"
    },
    {
      "file": "TASK.md (T10 verify)",
      "issue": "T10 verify 的 grep 管道使用 `|| true` 包裹计数，导致文本探针归零断言即使 grep/count 失败也返回 0，可能掩盖未替换的探针。",
      "why": "verify 必须能证伪；对所有文本探针计数失败的情况，`|| true` 会吞掉非零 rc，使 AC-9 对账结果可能恒绿。",
      "fix": "移除 `|| true`，改为先输出计数再 test 计数 -eq 0（如 `count=$(...); echo $count; test \"$count\" -eq 0`）。"
    },
    {
      "file": "TASK.md (T15 write_files)",
      "issue": "T15 的 action 要求删除仓根 2 份陈旧 tarball，但 write_files 未列出删除操作或对应路径，且 verify 用 `ls *.tar.gz` 判零；删除动作在 write_files 边界外。",
      "why": "write_files 边界要求清晰；删除文件也应显式声明（如以 deleted_files 或 write_files 内注明删除），否则执行器可能不执行删除或误判越界。",
      "fix": "在 T15 中显式声明删除仓根两个 tarball 路径（或增加 deleted_files 字段），verify 保持为零。"
    },
    {
      "file": "TASK.md (T09 write_files)",
      "issue": "T09 的 write_files 包含 .git/hooks/pre-push，正文注释称其为例外依据，但 .git/hooks 通常不在仓库版本控制内；若执行器按工件路径写入，可能污染本地 git hooks 且不可由 change 管理追踪。",
      "why": "write_files 边界不清晰：.git/hooks/pre-push 是部署产物而非源码工件，与 flow-kit-bundle/hooks/pre-push/pre-push.sh 的源码修改混在一起。",
      "fix": "将 .git/hooks/pre-push 从 write_files 移出，改为验证/安装步骤（如确认 symlink 指向 bundle 脚本），或明确标记为本地部署产物。"
    }
  ],
  "verdict": "pass",
  "summary": "任务拆解覆盖全部 AC 且依赖图无环，write_files 基本在 DESIGN 触碰范围内，但 T05 空白名单可证伪性、T16 仓外写入语义、T10 verify 的 || true 吞错等需在细化中修正。"
}
```

L3_artifact_hash: 2c7509a1724f5e2cc5a9f4e20a8dfec9eb1a5743439f27ee32de4a8e184d722a

<!-- /L3-SECTION -->

---

## L2 盲审（重审 · 第 2 轮 · 阶段 3 · 2026-09-29）

**审查对象**：TASK.md（T01–T17 · 18 任务 · 7 波次）。本报告引用的每个行号/计数/字面量锚均在本仓实测（grep/sed/diff），未采信工件内任何「L2 R<N> 修订」标注为事实。

**实测核对通过项**（独立性记录，非发现）：DAG 无环、逐 wave write_files 交集为零（T17←T12b 同波串行已在 TASK.md:22 显式标注）；禁动清单零触碰（package-flow-kit.sh / brooks-lint / .gitignore / dist/ 不在任何 write_files；tarball 删除属 CHANGE 14i 显式授权）；mock `"independent"` 实测 = 72（TASK 锚正确；CHANGE :188 的 92 为陈旧数，不构成 TASK 缺陷）；T01–T04 全部行号锚实测吻合（independent-review-gate.sh:64/:65/:114、29-independent-review.sh:138/:239/:200、test_check_gate_sync.bats:15/:23/:58、check-path-privacy.sh:72 PAT 尾斜杠、Makefile:250-251 双锚计数 = 2、:76 cp vs :84 diff -rq、:106 check 链含 check-gate-sync）；Makefile 与 pre-push.sh 的 flock 当前均 = 0（T08/T09 锚有判别力）；skills 17 目录 = 16 个 flow-* + skills/flow；@see 现值 1 个 SKILL.md → T12a ≥13 锚有效；flow-dev SKILL 内 commit-protocol 命中 = 0（AC-15-① 计数相等判据 0=0 恒真的根源，实测在案）；l2-reviewer.md:36-198 与 L2-blind-review.md:1-163 diff = 0（163 行复制实证）；be138c0 实在 test_l3_review_defects_2026_09.bats:88；STATE.md:71 C9 降级登记在案（AC-16 判据已满足）；TD 基线 132 实测一致；4-dev.md:99-106 内联表 8 行实测存在、锚「1.8 触发时 bats」计数 = 1（有效）。

### L-031 四象限（跨文件一致性锚点全仓 grep）

| 锚点 | DESIGN §0.5.1 | TASK 承接 | 象限 |
|---|---|---|---|
| check-skills-sync 更名触点（test_quality_baseline.bats:26,29-30,34-35 / 用户指南:1585 / pipeline-gates.md:4，三处实测吻合） | 列出 | T12c | 列出且承接 ✅ |
| check-gate-sync.sh 自身 PAIRS 3 对 PCSC 判据（:36-41） | **漏列** | **未承接** | 漏列且未承接 🔴（→ R2） |
| flow-active-query 改调（Makefile:250-253 / gate:63-65 实测吻合） | 列出 | T13 | 列出且承接 ✅ |
| make check-flow-active-inline 门禁（DESIGN 附录 A 承诺） | 列出 | **未承接** | 列出且未承接 🟡（→ R8） |
| flock（Makefile test 闸 + pre-push.sh） | 列出 | T08/T09 | 列出且承接 ✅ |
| L2-first 契约未满足（实测 flow-kit-bundle/ = 4：生产 29-independent-review.sh:138/:239 + bundle 内镜像测试 ×2；test/ = 2） | 列出 | T11（生产抽函数 2→1 + 测试拼接构造 → 终态全仓 = 1 成立） | 列出且承接 ✅ |
| node --test（实测 package-dsh-plugin.sh:233 已有、Makefile 无） | 列出 | T08 名义承接，verify 锚恒绿 | 列出且承接但判据失效 🟡（→ R4） |

### 发现清单

**R1 🔴 C13 薄壳化丢弃 52 个 skill 独有强制条款；AC-11「两载体同小节集合」与 T12b comm=0 判据互斥**
- Symptom：TASK.md:327-329（T12a write_files 仅 `skills/flow-*/SKILL.md`，无任何 prompts 写权）；TASK.md:331-336（T12a action「16 个 SKILL.md 薄壳化（YAML 头 + @see 锚点）」无差异甄别步骤与清单）；TASK.md:353-355（T12b verify 判据 = 两载体归一化行集 comm = 0）；DESIGN.md:121（D2 代价段自认「skill 独有小节（52 处）需 TASK 列清单逐对甄别去留」——清单缺失）；REQUIREMENT.md:98（AC-11 Then「反向实例（### 步骤 2.6 只在 skill 载体）消除——**两载体同小节集合**」）；CHANGE.md:345（52 个 skill 独有小节 / 步骤 2.6 全量 bash -n 语法门禁为反例正文）。
- Source：D2 明示代价未兑现；D7-③ 否决「双判据并存」；AC-11 的集合断言以两载体都有正文为前提。
- Consequence：只存在于 skill 载体的强制条款（含步骤 2.6 全量 `bash -n` 语法门禁等 52 小节）随薄壳化静默丢失且无登记面；TEST 按 AC-11「同小节集合」派生与按 T12b comm=0 派生得到相反红绿，AC-11 无法收敛。
- Remedy：T12a 增「差异甄别清单」节（逐对列 skill 独有小节 × 去留：移植进对应 prompts / 显式豁免并登记）；T12a write_files 增 `flow-kit-bundle/flow-kit/prompts/*.md` 写权；REQUIREMENT AC-11 Then 按 D5 结构化判据（归一化行集相等）改写并加对账标注（同 AC-11/AC-12-a 既有修订格式）。

**R2 🔴 check-gate-sync 的 PAIRS 3 对逐行 diff 判据在 W4 薄壳化后必红，无任何任务承接其移除/迁移**
- Symptom：flow-kit-bundle/flow-kit/reference/check-gate-sync.sh:36-41（`PAIRS=("A-evolve|flow-evolve" "I-intel-scan|flow-intel" "L-restyle|flow-restyle")`，check_pair 判据 = 剥离 front-matter 后逐行 diff、注释自认「实测这 3 对 diff 恒为 6 行」）；T12a（TASK.md:331-336）恰好薄壳化 flow-evolve/flow-intel/flow-restyle 这 3 对的 skill 正文；TASK.md:356（T12b 注「修好后 check-gate-sync 因覆盖不足转红是预期行为」——只承认证红，未列转绿路径）；Makefile:106（check 链实测含 check-gate-sync）；test_quality_baseline.bats:35（`run bash check-gate-sync.sh` 断言由 T12c 保留在 check-gate-sync 侧）。
- Source：阶段 3 checklist 覆盖完整性；L-031 跨文件一致性（语义拆分时遗留旧判据无人认领）；AC-13（make check rc=0）。
- Consequence：W4 起该 3 对逐行 diff 输出数百行差异 → check-gate-sync 永久 rc≠0 → AC-13「make check 全绿」不可达；T12c 保留的运行断言恒红；T12b 的注把永久红误判为预期行为。
- Remedy：给 T12b（或 T17）增显式动作：从 check-gate-sync.sh 移除/迁移 PAIRS 3 对 PCSC 内容判据至 check-skills-sync（或改判 @see 结构锚存在性），T12c 断言拆分同步；verify 增 `make check-gate-sync` rc=0。

**R3 🟡 T10 verify 机检锚恒真（实测当前计数 = 0）**
- Symptom：TASK.md:282（verify 的 grep 管道）；实测 `grep -v '# 行为断言' <T10 五文件> | grep -cE "grep .*(-q|-c|-rl?).*flow-kit-bundle/(hooks|lib|flow-kit)/"` = 0——现有探针均以 `$变量`（$sec/$L3_API_LIB/$L2_LIB 等）为路径，无字面 `flow-kit-bundle/`，转换前后该 grep 都是 0。
- Source：阶段 3 checklist「判据不恒真不恒红」；TASK.md:280 自认「实测近恒绿」却仍保留该锚在 verify。
- Consequence：32 处文本断言转换整体不做也能过 verify；AC-9 白名单机制（正文清单 + 白名单计数）无任何机检把关。
- Remedy：verify 改为对「C6 位点清单」逐文件断言（每文件预期残留文本探针计数 = 白名单数，清单随 done 提交），或锚定实际探针形态（按清单基线 `grep -cE "grep -q '[^']*\\\$"` 逐文件计数）。

**R4 🟡 T08 的 node --test 锚恒绿 + AC-10 单跑计数无 verify**
- Symptom：TASK.md:225（verify `grep -n 'node --test' Makefile package-dsh-plugin.sh`）；实测该式今日即过——仅 package-dsh-plugin.sh:233 命中、Makefile 现无该字面量（grep 多文件任一命中即 rc=0）；REQUIREMENT.md:92（AC-10「PATH shim 计数文件行数 = 1」用例）未出现在任何 task 的 action/verify。
- Source：阶段 3 checklist 判据不恒真；AC-10 验证方式。
- Consequence：C14-e 的 make test 接线可整体不做仍过 verify；「make test 与 CI 单跑收敛」回归不可检测。
- Remedy：拆成单文件锚 `grep -n 'node --test\|package-dsh-plugin.*--check' Makefile`；T08（或 T01）增 PATH shim 计数 bats 用例并入 verify。

**R5 🟡 T05/T16 verify 全角括号粘连注释，命令不可原样执行（实测报错）**
- Symptom：TASK.md:146（T05 verify `sort -u（两模式输出合并去重后…）`）、TASK.md:485（T16 verify `git ls-remote --heads origin（终判 = …）`）；实测 `echo x | sort -u（两模式）` → `sort: 无效的选项`（全角括号被当作操作数粘连）。
- Source：阶段 3 checklist「每条 verify 可机器执行」。
- Consequence：verify 照抄必红（T05 第二段整段、T16 终判），执行者被迫临场改写判据 = 裁量回流，判据失去固定性。
- Remedy：注释移出命令串（`# 说明` 另起一行）；T16 终判落成可执行脚本（fresh-clone 逐 blob 扫描）挂入 verify。

**R6 🟡 T09 verify 缺 AC-17 两项核心判据**
- Symptom：TASK.md:248（verify 仅 bash -n + flock 计数 + make check-hooks-sync）；REQUIREMENT.md:150-152（AC-17 ① `.git/hooks/pre-push` 内容含 pre-push.sh 的 grep 断言 ② 本地裸仓并发双 dry-run bats 夹具）；check-hooks-sync 的镜像域不辖 `.git/hooks/`（T09 自述），flock 计数也不验证换装实效。
- Source：AC-17 验证方式；write_files 已含 `.git/hooks/pre-push` 却无对应判据。
- Consequence：换装核心交付与并发闸实效零验证；AC-17 ①② 空转。
- Remedy：verify 增内容断言（如 `grep -l 'pre-push/pre-push.sh' .git/hooks/pre-push`）；新建 test_pre_push_concurrency.bats（裸仓夹具 + 双 dry-run + git status 断言）入 write_files/verify。

**R7 🟡 T11 verify 缺 AC-15-①② 机检锚；AC-15-① 计数判据恒真未对账**
- Symptom：TASK.md:315（verify 仅 bats/lint/sync 类）；REQUIREMENT.md:135-136 已给出可用锚——`grep -c '1\.8 触发时 bats' 4-dev.md`（实测现值 = 1，删表后 = 0，判别力有效）、l2-reviewer 归一化行集 comm = 0（实测 :36-198 与 :1-163 diff = 0，复制段实在）；AC-15-① 的「commit-protocol 两计数相等」判据实测 0=0 恒真（flow-dev SKILL 命中 = 0），TASK T11 改用段落特征但 REQUIREMENT 未加对账标注（不同于 AC-11/AC-12-a 的修订格式）。
- Source：阶段 3 checklist verify 可验证性 + 覆盖完整性。
- Consequence：①删表 ②复制段消除 两项核心交付无 verify 把关；TEST 若按 AC-15-① 原文派生得到恒绿用例。
- Remedy：verify 追加两个 grep 锚；REQUIREMENT AC-15-① 判据按 T11 段落特征改写并加「修订（2026-09-29）」标注。

**R8 🟡 T13 缺正向锚；DESIGN 附录 A 承诺的 make check-flow-active-inline 无任务承接**
- Symptom：TASK.md:413（verify 仅负锚 `[ -f .flow-active …` 计数 = 0，实测当前 Makefile:250-251 计数 = 2、判别力有效）；REQUIREMENT.md:112（AC-12-g 明确**双锚**：另需 `grep -c 'flow-active-query' Makefile` ≥ 1 的正向锚，TASK 缺）；DESIGN.md:247（附录 A：「check 落地时由 `make check-flow-active-inline` 执行同款」）——全 TASK 无该 target 的创建者。
- Source：AC-12-g 双锚；DESIGN 附录 A 承诺；ADR-031 决策 2（白名单计数门禁）。
- Consequence：「删而不接」式修复可过 verify；白名单「只减不增」无 enforcement，flow-active 白名单回潮不可检测。
- Remedy：verify 补正向锚；T13 action 增「新建 make check-flow-active-inline 目标（执行附录 A 谓词 + 白名单比对）」挂入 check 链。

**R9 🟡 AC-13/AC-14 无任务承接（AC-16 已满足）**
- Symptom：TASK.md 18 个任务无销账/收口任务；实测 `.specs/STATE.md` `grep -c '已修复'` = 0（AC-14 要求 ≥14 行逐条销账）；AC-13 的「make check 全绿 + 用例数 ≥1116」收口、AC-14 的 TD 增量登记无 owner；AC-16 已在 STATE.md:71 登记（实测）✅ 不缺。
- Source：阶段 3 checklist「所有 AC 是否有 task 承接」；REQUIREMENT v1 反哺层（:163）。
- Consequence：4-dev 完成判据全绿后销账/收口仍欠账，风险后移到 7-integration 才暴露。
- Remedy：增 T18（反哺收口：STATE.md 逐条销账 ≥14、TD 增量对齐 132 基线、make check rc=0 + 用例计数 ≥1116），或并入 T16 收尾段并加 verify。

**R10 🟡 T03 action 缺 AC-2 kill 注入用例的编写排程，done 却声称**
- Symptom：TASK.md:100-104（action 仅 SKILL_REL/夹具化/teardown/备份）vs TASK.md:106（done「kill 注入 rc≠0」）vs REQUIREMENT.md:36（AC-2 验证方式「新增 bats 用例：注入 kill」）。
- Source：done↔action↔AC 三方对账。
- Consequence：done 判据引用未排程交付物；AC-2 中断回归网可能不落地。
- Remedy：action 增「新增 AC-2 用例：后台起 bats 子进程 + kill -TERM，断言 rc≠0 / git diff --stat = 0 / 输出含夹具路径」。

**R11 🟡 C14-c 权威源冲突 + 谓词第三模式无机检 + 变量间接形态逃逸**
- Symptom：REQUIREMENT.md:108（AC-12-c「全量清单以 HEALTH 报告附录 C 为准」= 11 文件）vs TASK.md:144（T05「种子与谓词实测不符处以**谓词**为准」）；实测谓词 `[ ! -f "$HOME` 命中仅 2 文件（test_independent_review_model.bats / test_l3_pipeline_fix.bats）、`[ -d "$HOME` = 0；test_l3_review_defects_2026_09.bats:973-974 的 `d="$HOME/.claude/hooks"; [ -d "$d" ] || skip` 变量间接形态不被谓词匹配（该处已是合规显式 skip，但同类形态若为静默豁免即漏检）；第三模式「HOME 夹具自包含豁免判定」无 grep 形式；test_guide_copy_parity.bats / test_install_dsh_platform.bats 含 HOME 安装态引用、既不在种子清单也不在 T15 write_files。
- Source：阶段 3 checklist 判据可机器执行；权威名单机制（CHANGE C14-c）。
- Consequence：权威名单口径二义（11 vs 2）；TEST 按 AC-12-c「11 文件不静默」派生与 TASK 名单冲突；豁免判定全凭执行时裁量。
- Remedy：REQUIREMENT AC-12-c 加对账标注（清单权威 = T05 谓词重算，HEALTH 附录 C 降级为种子）；T05 谓词补变量间接分支（同 DESIGN 附录 A 分支④手法：赋值行 `X="$HOME/…` → 下游 `[ -f "$X" ]` 同辖）；豁免判定落成可 grep 判据（夹具 `HOME=$TEST_TMPDIR` 前缀行）。

**R12 🟢 T16 漏 AC-5 步骤⑥显式排程**
- Symptom：TASK.md:478-485（action ⓪–⑤ 无「⑥ 删除 ../push-url-pre-scrub.tmp」）；REQUIREMENT.md:55（步骤⑥）。
- Consequence：含真实 URL 的仓外临时文件可能残留。
- Remedy：action 补⑥（用毕删，与 scrub-literals.tmp 同款）。

**R13 🟢 行号锚漂移（3 处实测）**
- Symptom：TASK.md:124（T04 引 test_path_privacy_gate.bats:35 探针——实测 :35 是注释行，PROBE 实在 :33）；TASK.md:494（T17 称 flow-state.js「:94-116 PRESET_MAP」——实测 PRESET_MAP 在 :20、resolveGateConfig 在 :95）；TASK.md:243（T09 引 install_hooks.sh :118/:126——deploy_pre_push 函数体实在 :124、install_file 定义在 :25（:126 为调用行），语义可辩护但建议核正）。
- Consequence：按行号定位错位，执行者需回读核对。
- Remedy：改「内容锚优先、行号附注」，执行前重跑定位 grep。

**R14 🟢 若干 verify 锚弱于 AC 域**
- Symptom：TASK.md:431（T14 verify 只 grep common.sh 单文件，AC-12-a 域为 flow-kit-bundle/hooks/ 全域）；TASK.md:382（T12c 对用户指南:1585 / pipeline-gates.md:4 的更新无 verify 锚）；TASK.md:462（T15 verify 只跑自写 5 文件中的 3 个，未跑 test_independent_review_model / test_runtime_edit_guard）。
- Consequence：弱覆盖，不阻塞判定。
- Remedy：verify 扩域/补锚。

**Verdict**: fail

---

## 主 agent 响应（阶段 3 · 对 L2 重审 r2 · 2026-09-29）

> R1–R11（2🔴 + 9🟡）全部 Fixed in；R12–R14（3🟢）就地修正（不另开 M 条目——均为行号锚/排程补句级）。

- **R1 🔴 Fixed in**：T12a 重构为两步——步骤 ① 段集 diff 清点 16 载体全部 skill-独有小节（≈52 条款），逐条处置（**并入对应权威 prompt**——write_files 补 `flow-kit-bundle/flow-kit/prompts/*.md` 写权——或**显式登记弃用**落 CHANGE C13 段含理由），处置清单回填新节「C13 skill-独有条款处置清单」（D2「TASK 列清单」兑现）；步骤 ② 薄壳化只在处置后进行；verify 增清单驱动逐字对账循环。REQUIREMENT AC-11 Then 判据同步对账：「两载体同小节集合」与薄壳 comm=0 **互斥**，更正为「载体映射完整 + 权威正文不双写」。
- **R2 🔴 Fixed in**：T12b write_files 补 `check-gate-sync.sh`；action 新增⑥「PAIRS 旧判据迁移」——:36-41 PAIRS 3 对（flow-evolve/flow-intel/flow-restyle）剥 front-matter 逐行 diff 判据在薄壳化后必红，同批摘除，一致性职责由 check-skills-sync 接管；verify 增 `make check-gate-sync` 回绿断言（AC-13 通路保住）。
- **R3 Fixed in**：T10 verify 重写——机检锚兼容 `$变量` 路径形态（`grep -E 'grep [^#]*(--quiet|-q|-c |-rl?|-rn )'` × 路径特征 `(/hooks/|/lib/|flow-kit|\.sh)`，实测当前计数非 0，判据非恒真）；白名单注释残留计数 ≥2（当前实测 = 2）；旧 `flow-kit-bundle/(hooks|lib|flow-kit)/` 字面锚废弃。
- **R4 Fixed in**：T08 verify 的 node --test 锚改 `grep -c 'node --test' Makefile` ≥1（Makefile 专属，当前 =0，改后非恒绿）；action 新增⑥ PATH shim 计数用例（新建 test/test_makefile_gates.bats + 镜像，write_files 已补）。
- **R5 Fixed in**：T05 与 T16 verify 的全角括号说明全部移出命令串（改 `# 对账` 注释行）——两处命令现可原样执行。
- **R6 Fixed in**：T09 verify 增 `grep -c 'flow-kit-bundle/hooks/pre-push' .git/hooks/pre-push` ≥1；action 新增③ 裸仓并发双 dry-run 夹具（AC-17②，原 M11 承接落点显式化）。
- **R7 Fixed in**：T11 verify 增三锚——删表锚 `grep -c '1\.8 触发时 bats' 4-dev.md` = 0（当前 =1，非恒真）+ 复制段归一化 comm=0（L2-blind-review ↔ l2-reviewer.md）+ 生产报文 `grep -c 'L2-first' 29-independent-review.sh` = 1（当前 =2）；done 注明 'commit-protocol' 双计数为恒真对账锚、判据力由删表锚承载。
- **R8 Fixed in**：T13 verify 增正锚 `grep -c 'flow-active-query' Makefile` ≥1（AC-12-g 双锚齐备）+ `make check-flow-active-inline`（DESIGN 附录 A 门禁，本任务挂链执行）。
- **R9 Fixed in**：TASK 文件头「AC 归属显式声明」——AC-13 → **T16 收尾步 ⑦**（重写后全量 make check 回绿 + 用例数 ≥1116 对账，verify 已含 make check）；AC-14 → **7-integration 反哺批**（载体 STATE.md/CONTEXT.md，非 TASK 任务，属阶段 7 职责）。
- **R10 Fixed in**：T03 action 新增 AC-2 kill 注入用例排程（SIGTERM/SIGKILL 注入 → rc≠0 + `git diff --stat`=0）。
- **R11 Fixed in**：REQUIREMENT AC-12-c 权威源修订——TASK T05 全变体谓词重算为唯一权威（HEALTH 附录 C 降为种子，偏差以重算为准），含变量间接形态（:973-974 实例入域）；T05 action/verify 同步（三模式机检 + 对账注释行）。
- **R12 就地修正**：T16 action 新增⑥ 清理步——删 ../scrub-literals.tmp 与 ../push-url-pre-scrub.tmp（verify 补 `test ! -f` 双断言）。
- **R13 就地修正**：三处行号锚校正——T01 PROBE :33；T17 read_files PRESET_MAP :20（原 :94-116）；T09/DESIGN deploy_pre_push :124（原 :118）。
- **R14 就地修正**：T14 verify 扩域 `grep -rn 'jq_atomic_write' flow-kit-bundle/hooks/` = 0（对齐 REQUIREMENT 收窄域）；T12c verify 增指南双锚（check-skills-sync / check-gate-sync 指名 ≥1）；T15 verify 补跑全部 5 个自写测试文件。

---

## L2 盲审（重审 · 第 3 轮 · 阶段 3 · 2026-09-29）

**方法与独立性声明**：仅读固化指令（L2-blind-review.md）+ TASK.md（596 行）/ REQUIREMENT / DESIGN / CHANGE / ADR-030/031/032 / CONTEXT 禁动清单（:495-534）；未读 INDEPENDENT-REVIEW-1/2、MINOR-DEFERRED 及任何既往审查完成标记文件。工件内「L2 r2 R<N> 修订」标注一律不复信，引用锚点全部本机重测。

**通过项（实测）**：
- 依赖 DAG 无环（W1 无依赖 / W2←W1 / W3←W1 / W4←W2,W3 / W5←W2,W4 / W6←W1,W5 / W7←W2,W5,W6）；T16 末位约束在位（:21）。
- AC-1…AC-17 全数承接：AC-11→T12a/b/c、AC-12-b→T17、AC-13→T16 步⑦、AC-14→7-integration（头注 :546 显式声明）；AC-16 Given 实测成立——STATE.md:71 同行含「C9 降级登记（AC-16 判据）」且含 v2；TD 基线 `grep -c '^| TD-' .specs/CONTEXT.md` = 132 与 AC-14 声明一致。
- R2 结构修复自洽：check-gate-sync.sh:36-41 实测 `PAIRS=( "A-evolve|flow-evolve" "I-intel-scan|flow-intel" "L-restyle|flow-restyle" )` + 剥 front-matter 逐行 diff 判据、PAIRS_TOTAL=14 常量单点——薄壳化后必红的前提成立；T12b 行动含同批摘除/迁移 + verify 含 `make check-gate-sync` 回绿。✓
- L-031 四象限（锚点 = check-gate-sync / check-skills-sync / flow-active-query / jq_atomic_write）：check-gate-sync 活性引用面（用户指南 root+bundle 副本、pipeline-gates.md:4、Makefile、test_quality_baseline 与 test_check_gate_sync 的 root+bundle 四份）全部落在 T12b/T12c/T03/T07 write_files 内，无孤儿触点无漏改；check-skills-sync / flow-active-query 当前仅存在于 .specs 文档面，生产引用将由 T12b/T12c/T13 落地，方向闭合；jq_atomic_write 生产面仅 common.sh:190（Usage 注释）+:192（定义）、零测试引用——T14 删除安全，verify 域收窄 flow-kit-bundle/hooks/ 与 REQUIREMENT AC-12-a 判据修订自洽。
- 抽样锚点全部命中：independent-review-gate.sh :33-37 declare -f 既有范式 / :42-46 三子库 source 无断言 / :64 放行保留与 :65 `jq empty … || exit 0` fail-open / :114 `command -v jq … || exit 0`；29-independent-review.sh:200 `|| true` 实测在位；Makefile:250-251 手搓解析（T13 负锚 `grep -cE 'done < \.flow-active|\[ -f \.flow-active \]' Makefile` 实测当前=2，非恒真）；dsh-flow-kit/lib/flow-state.js:20 `const PRESET_MAP = {`；gate-helpers.sh:26 select 值域+:29-30 case；用户指南:1585 预设名 17 项表述；4-dev.md:103 表行 7（`grep -c '1\.8 触发时 bats'` 实测=1→目标 0，有判据力）；仓根 2 tarball（27.6+25.7MB）实测在位；hooks/stop/lib/l2-detect.sh 实测存在（T11 抽取目标非新建）；comm 归一化交集实测=117→目标 0 可达；skills 含 @see 文件数实测=1→目标 ≥13 有判据力；prompts 顶层恰 14 个 .md，`prompts/*.md` glob 不触及 independent/L2-blind-review.md（禁动 checklist 条目不落入写权）；auto-checkpoint.sh 实测位于 hooks/pre-tool-use/（T01 写路径正确）。
- T10 新机检锚实测：探针残留计数当前=32（红→绿方向正确）；Makefile 四锚 `node --test`=0、`flock`=0、负锚=2、`flow-active-query`=0，均当前红→改后绿，无恒真。

### 发现清单

**R1 · T11 verify 第三锚「L2-first 计数=1」恒红不可达**

- **Severity**: 🔴 Critical（阻塞 toll-gate，入 fix loop）
- **Symptom**: TASK.md:323 `<verify>` 末锚 `test "$(grep -c 'L2-first' flow-kit-bundle/hooks/stop/29-independent-review.sh)" -eq 1`。实测当前计数 = **5**（:21 注释、:34 l2-missing jq 报文、:127 注释、:138/:239 module_output 警告对）。
- **Source**: T11 行动面只把 :138/:239 两份 `_l2_first_deny` 警告报文抽到 l2-detect.sh——:21/:34/:127 两处注释与 l2-missing 报文不在行动面，无法被该任务消除。
- **Consequence**: 终态计数 = 3 ≠ 1，T11 按规格完成后 verify 仍恒红 → T11 永远无法 done → W3 起下游 T12a→T12b→T13/T17→T16 全链阻塞。REQUIREMENT AC-15-③ 的原锚是全短语 `grep -rn 'L2-first 契约未满足' flow-kit-bundle/ | wc -l` = 1（抽取后唯一残留于 l2-detect.sh 内，可达），TASK 改写为短串+单文件+目标 1 时判据错位。
- **Remedy**: 锚改回 `test "$(grep -rn 'L2-first 契约未满足' flow-kit-bundle/ | wc -l)" -eq 1`，或收窄为 `grep -c 'deny reason: L2-first' 29-independent-review.sh` -eq 1；勿用裸短串 'L2-first' 计数。

**R2 · T12a verify 的 C13 清单对账循环结构坏死（回填即恒红）**

- **Severity**: 🔴 Critical（阻塞 toll-gate，入 fix loop；R1 轮「52 条款零蒸发」机检落空）
- **Symptom**: TASK.md:349 while 循环 `IFS='|' read -r _ clause dest _; do [ "$dest" = 并入 ] && grep -qF "$clause" … || exit 1; done`。
- **Source**: ① 列错位——C13 表为 4 数据列+行首空列（`| 条款摘录 | 出处载体 | 处置 | 理由 |`），IFS='|' 切分后 `dest` 收到第 2 列「出处载体」，真正的「处置」列落入尾部 `_`，`[ "$dest" = 并入 ]` 对任何行恒假；② `A && B || exit 1` 反转——条件为假即走 exit 1，表头行、分隔行、弃用行、乃至完全合规的并入行全部触发 exit 1。模拟实测（构造表头+分隔+1 条并入（条款原文确在目标 prompt）+1 条弃用，按 TASK 声明列格式）：rc=1。
- **Consequence**: 当前 C13 节是空占位所以 verify 空转通过；T12a 一旦履行回填义务 verify 立即恒红——任务两难：回填则 verify 不可过，不回填则 52 条款零蒸发无任何机检。TASK.md:558 承诺「『并入』条目由 T12a verify 逐字对账」不可兑现，R1 三方闭环（REQUIREMENT 判据修订 + T12a 两步 + verify 对账）在机器层断裂。
- **Remedy**: 循环重写：读满 4 字段（`read -r _ clause origin dest _`），用 `case "$dest" in *并入*) …;; esac` 前缀匹配处置列并显式跳过弃用行；输入侧过滤表头/分隔行（`grep -vE '^\|[-: ]|条款摘录|^\| #'`）；或改 awk -F'|' 按列号取数。

**R3 · T03 并发双跑 verify 不捕获实例 rc**

- **Severity**: 🟡 Important（task 内解决）
- **Symptom**: TASK.md:107 `(npx bats test/test_check_gate_sync.bats & npx bats test/test_check_gate_sync.bats & wait)`。
- **Source**: bash 无参 `wait` 实测恒返 0（`false & wait` → 0；`(true & false & wait)` → 0）——子任务失败不会传播。
- **Consequence**: AC-1「双跑**各自成功**，非仅不脏」在 verify 层失守：任一并发实例非零退出仍绿。REQUIREMENT AC-1 自己给出了正确范式（`wait $p1; r1=$?; wait $p2; r2=$?; exit $((r1+r2))`）但未沉到 TASK。
- **Remedy**: T03 verify 改用 pid 捕获 + 逐 wait + rc 求和范式；AC-1 的 make check 级双跑在 T16 ⑦ 回归批按 REQUIREMENT 原式执行。

**R4 · T12c（W4）预设名断言指向 W5 才创建的 check-skills-sync**

- **Severity**: 🟡 Important（task 内解决）
- **Symptom**: TASK.md:400「预设名断言归 check-skills-sync」；T12c 位于 Wave 4 且 depends_on 仅 T08，而 check-skills-sync.sh 由 T12b（Wave 5）创建。
- **Source**: 更名触点的断言迁移方向与门禁创建时序倒置：若「归」= 改指新门禁（test -x / 执行式断言），W4 执行时脚本不存在，`npx bats test/test_quality_baseline.bats` 必红。
- **Consequence**: T12c 无法在 W4 按其自身 verify 收口，或被迫在 W4 留下指向不存在文件的断言（合法红窗口扩大）；行动文本歧义（「摘除迁入 T12b 的 test_skills_sync.bats」与「原地改指」都读得通）。
- **Remedy**: T12c depends_on 补 T12b（移入 W5+），或行动文本明确为「预设名断言摘除、由 T12b 的 test_skills_sync.bats 承接，test_quality_baseline 仅保留 check-gate-sync 运行断言」。

**R5 · :20「同 wave 内零同文件冲突（见 Plan-Conflict Scan）」双重失实**

- **Severity**: 🟡 Important（task 内解决）
- **Symptom**: TASK.md:20 声明与 Wave 5 现实不符：T12b 与 T17 的 write_files 均含 flow-kit-bundle/flow-kit/reference/check-gate-sync.sh。
- **Source**: 冲突以 T17 depends_on T12b 的 wave 内串行缓解（:15 有注），但「同 wave=可并行」的普适表述因此不成立；且全文件无「Plan-Conflict Scan」节——引用悬空（全文件 grep 仅 :20 一处命中）。
- **Consequence**: 按字面并行调度 W5 会在 check-gate-sync.sh 上产生竞写；执行者/后续审查无法循引用核验冲突面。
- **Remedy**: :20 改述为「同 wave 可并行，唯 W5 的 T17 在 T12b 之后串行（同写 check-gate-sync.sh）」，并删除悬空的「见 Plan-Conflict Scan」或补该节。

**R6 · 头注「write_files 不含禁动清单」字面失实 + T15 write_files 漏列其删除的 2 tarball**

- **Severity**: 🟡 Important（task 内解决）
- **Symptom**: TASK.md:545 声明「write_files 严格在 DESIGN 0.5.1 触碰+新增范围内、不含禁动清单」；T15（:481）行动含删仓根 2 tarball，但其 write_files（10 个测试文件）不含 flow-kit-bundle.tar.gz 与 flow-kit-full-20260803-232437.tar.gz。
- **Source**: independent-review-gate.sh / 29-independent-review.sh（T01/T02/T11/T13 写）与 flow-kit-bundle.tar.gz（T15 删）均在 CONTEXT 禁动清单上；这些触碰各有 ADR/DESIGN 背书且方向与条目防护方向一致，但「不含禁动清单」的统称表述不真。删除文件同样是写操作，R7.3 diff 边界漏口。
- **Consequence**: 边界约束的自我声明不可机检采信；T15 执行时删 write_files 外文件构成违规或迫使执行者即时改规格。
- **Remedy**: 头注改为「触碰禁动条目均属 DESIGN 0.5.1 显式背书、方向为条目所防护方向」；T15 write_files 补两 tarball 路径。

**R7 · T12b 行动未携带 DESIGN D5 的 @see 可解析性与豁免登记判据**

- **Severity**: 🟢 Minor（入 MINOR-DEFERRED，不阻塞）
- **Symptom**: T12b action 只写「归一化行集比对 comm -12=0 + 覆盖率阈值」；DESIGN D5 另有「@see 锚点可解析（目标文件存在且标题/行锚命中，目标缺失 rc≠0）+ 豁免登记（flow-go→GO.md / flow-kit-install / skills/flow 不辖）」。
- **Source**: REQUIREMENT AC-11 的反向控制「删一个 prompt 小节必红」恰依赖锚点可解析性；TASK 层未列，执行者可能交付弱于 D5 的门禁。
- **Consequence**: AC-11 反向控制在实现层可能不可达，且不会被 T12b verify 发现（make check-skills-sync 照样绿）。
- **Remedy**: T12b action 显式补列 D5 全部判据（锚点可解析 + 豁免登记 + 反向用例入 test_skills_sync.bats）。

**R8 · T16 verify 缺 AC-13 用例计数锚**

- **Severity**: 🟢 Minor（入 MINOR-DEFERRED，不阻塞）
- **Symptom**: AC-13 的「用例 ≥1116」只出现在 T16 action/done 文字，verify 无对应机检。
- **Source**: verify = bundle verify + ls-remote + make check + test ! -f 双 tmp；`npx bats test/ --formatter tap | tail -1` 计数锚未入。
- **Consequence**: 用例数回退（净增不减红线）只能靠人工对账。
- **Remedy**: T16 verify 步⑦ 处补计数锚。

**R9 · T10 done 注「当前实测残留 = 2」与实测不符**

- **Severity**: 🟢 Minor（入 MINOR-DEFERRED，不阻塞）
- **Symptom**: `# 行为断言` 白名单注释在 5 个目标测试文件当前计数全 0，done 注却称「当前实测残留 = 2」。
- **Source**: 该「2」实指逃逸 -eq 0 正则的变量路径形态探针（r2 R3 修订语义），但文字写成「当前实测」，且未指明是哪 2 条。
- **Consequence**: 执行者可能为凑 `-ge 2` 白名单计数而刻意保留文本探针，与「32 处全部行为断言化」表述打架。
- **Remedy**: done 注改述为「预期保留 ≥2 条变量路径形态白名单（行动面列出具体行号）」。

**Verdict**: fail（🔴×2：R1 T11 verify 恒红锚；R2 T12a verify 对账循环坏死。修掉两红后其余 🟡 均可在 task 规格内就地解决，🟢 入 MINOR-DEFERRED。）

---

## 主 agent 响应（阶段 3 · 对 L2 重审 r3 · 2026-09-29）

> R1–R6（2🔴 + 4🟡）全部 Fixed in；R7–R9（3🟢）就地修正。两红均为 verify 层锚/循环改写，任务结构未动。

- **R1 🔴 Fixed in**：T11 verify 第三锚废弃裸词锚 `grep -c 'L2-first' 29-independent-review.sh -eq 1`（实测 5，:21/:34/:127 注释与 l2-missing 报文不在行动面，终态=3 恒红），改 REQUIREMENT AC-15-③ 原式全短语全仓锚：`grep -rn 'L2-first 契约未满足' --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=.codegraph . | wc -l -eq 1`；done 注同步记录废弃理由。
- **R2 🔴 Fixed in**：T12a verify 对账循环整体重写为 awk 管道——awk -F'|' 解析 4 列（条款摘录/出处载体/处置/理由），两侧 gsub 去首尾空白（修复 IFS='|' 下 dest 收第 2 列 + 前导空格污染 grep -qF 模式的双重坏死），输出 clause<TAB>dest 后 while IFS=$'\t' 循环 case 匹配：`并入→*` 取 `${dest#并入→}` 为目标路径逐字 grep -qF 命中、`弃用*` 跳过、其余 exit 1；表头与分隔行由 awk 侧 `$2 !~ /^[[:space:]]*(条款摘录|:?-)/` 过滤（同时修复旧 sed 区间 `/,/^## /p` 在节标题自匹配导致区间只含标题一行的恒真空洞，改用两端字面量 `/^## C13 skill-独有条款处置清单/,/^## C6 位点清单/`）。
- **R3 Fixed in**：T03 并发双跑改 `(A & p1=$!; B & p2=$!; wait "$p1" && wait "$p2")`——逐 pid wait 捕获各自 rc，任一失败整体 rc≠0（裸 wait 恒 0 废弃）。
- **R4 Fixed in**：T12c 移入 Wave 5、`depends_on T08, T12b`；action 改「预设名断言**迁入 T12b 已创建的 test_skills_sync.bats**（只迁移不新建载体）」；verify 增 `npx bats test/test_skills_sync.bats`；波次图同步（Wave 4 = T12a 单任务）。
- **R5 Fixed in**：:20 波次说明重写——删除悬空引用「见 Plan-Conflict Scan」（该节不存在），改为显式声明两处串行约束：Wave 5 内 T12b → T17（同写 check-gate-sync.sh）与 T12b → T12c（同写 test_skills_sync.bats）按 depends_on 串行。
- **R6 Fixed in**：头注「不含禁动清单」字面失实改为「交集全部为有出处的显式背书触碰（gate 核心链三文件 + Makefile = DESIGN 0.5.1 明列；2 tarball = CHANGE What 14e 授权）」；T15 write_files 补列 flow-kit-bundle.tar.gz 与 flow-kit-full-20260803-232437.tar.gz（删也是写）。
- **R7 就地修正**：T12b action 新增⑦「@see 可解析 + 豁免登记」——薄壳 @see 指向的 prompt 文件与小节标题 grep 命中（test_skills_sync.bats 反向控制：改 @see 指向不存在小节必红）；豁免载体（flow-go→GO.md / flow-kit-install / skills/flow 不辖）登记进白名单，白名单外覆盖率不足即 rc≠0（AC-11 反向控制实现层可达）。
- **R8 就地修正**：T16 verify 增 `test "$(grep -h '^@test' test/*.bats | wc -l)" -ge 1116`（AC-13 用例数机检锚）。
- **R9 就地修正**：T10 done 注删「当前实测残留=2」断言（实测白名单注释当前=0），改为「保留位点行号执行时回填 C6 位点清单并标注保留，预计 ≥2 条 $ 变量路径探针」。

---

## L2 盲审（重审 · 第 4 轮 · 阶段 3 · 2026-09-29）

**审查对象**：`.specs/health-fix-2026-09c/TASK.md`（601 行 · T01–T11/T12a-c/T13–T17 共 19 任务 · 7 波次）。**方法**：全程独立实测——所有锚点自行 grep/推演，未采信工件内「L2 r2/r3 R<N> 修订」标注为事实。

### 一、上轮修复核验（本轮必查三项）

1. **T11 verify 第三锚（TASK.md:323）实测恒红**：原样执行 `grep -rn 'L2-first 契约未满足' --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=.codegraph . | wc -l` → **当前 = 22**。分布：生产 29-independent-review.sh ×2（:138/:239）+ 根 test/test-l2-first-correction.bats ×2 + bundle 镜像 ×2 + `.specs` 文档面 ×17（TASK.md ×2——verify 与 done 自身、REQUIREMENT/CHANGE/HEALTH 各 1、INDEPENDENT-REVIEW-1/2/3 合计 8、archive 2、health/tmp 日志 2）。T11 行动面迁移后终态 = 22 −1（生产去重）−2（根测试拼接）−2（镜像拼接）= **17 ≠ 1**，残留全为 `.specs` 文档面——不在 T11 write_files 内、结构性不可清除。→ 🔴 R1。
2. **T12a verify 对账循环（TASK.md:349）推演**：构造 mock 表 7 案代入原样执行——并入命中 rc=0；并入未命中 rc=1；畸形 dest（如 `迁移→x`）rc=1；并入目标文件不存在 rc=1（fail-closed）；表头/`---`/`:---` 分隔/`>` 引用行均被 `$2 !~` 过滤；空节（当前真实 TASK.md 原样执行）零迭代 rc=0（占位期可接受）；**空子句行意外 fail-closed**（`IFS=$'\t'` 吞前导空字段→dest 错位落 `*` 分支 exit 1，实测 rc=1）。回填后语义成立。→ 🟢 R6 附显式化建议。
3. **上轮 🟡 修复抽查**：T03 并发双跑逐 pid `wait "$p1" && wait "$p2"`（TASK.md:107）✓ 逻辑等价捕捉双 rc（p1 败则链红；孤儿 p2 仅写 mktemp 夹具无害）；T12c 已移 Wave 5 `depends_on=T08,T12b`（TASK.md:408）✓；:20 两处串行约束声明原文在 ✓；T15 write_files 含 2 tarball（删除授权=CHANGE What 14e）✓；T16 verify 含 `-ge 1116`（TASK.md:514）且当前实测 `grep -h '^@test' test/*.bats | wc -l` = **1116**（恰为基线，无虚高）✓。

### 二、阶段 3 checklist 核对

- **粒度/波次/DAG**：19 任务 7 波 ✓；依赖边全部指向更早 wave，唯二同 wave 边（T12b→T12c、T12b→T17，均 Wave 5）已在 TASK.md:20 声明串行 ✓ 无环。同 wave 写冲突：W5 T12b/T17 同写 check-gate-sync.sh（已声明）；T12b/T12c 同写 test_skills_sync.bats（已声明，但 T12c write_files 缺列 → R2）；T12b 摘 PAIRS 波及 test_check_gate_sync.bats 无人承接 → R3。
- **verify 可执行性与可达性**（关键锚全部实测）：T11 删表锚 `1\.8 触发时 bats` 当前=1→0 ✓、comm 归一化当前=117→0 ✓、第三锚恒红（R1）；T13 双锚 `done < \.flow-active|\[ -f \.flow-active \]` Makefile 当前=2（:250-251）→0、`flow-active-query` 0→≥1 ✓；T14 `jq_atomic_write` hooks/ 当前=2（common.sh:190 注释+:192 定义，零调用方）→0 ✓；T09 flock/指名当前 0/0→≥1 ✓；T15 tarball 当前=2→0 ✓；T12a `@see` 当前=1（仅 flow-dev）→≥13（16 个 flow-* 目录实存）✓；T16 bundle verify/≥1116 ✓。T05 三谓词原样可执行（实测输出 2/0/0 个文件，判据力在人工对账+T15 消费，r2 R5 定型口径）✓。
- **覆盖完整性**：AC-1/2→T03、AC-3→T04、AC-4→T06、AC-5→T16、AC-6→T02、AC-7→T07、AC-8→T01、AC-9→T10、AC-10→T08、AC-11→T12a/b/c、AC-12a→T14/b→T17/c→T05+T15/d/e→T08/f/g→T13/h/i→T15、AC-13→T16⑦、AC-14→7-integration、AC-15→T11、AC-17→T09 ✓；AC-16 Given 侧独立复核成立（STATE.md:71 C9 降级登记实在、TD 基线 `grep -c '^| TD-' .specs/CONTEXT.md`=132）但 Then 侧无 verify 承接 → R9。
- **write_files∩禁动清单背书**：gate 核心链（independent-review-gate.sh/29-independent-review.sh=DESIGN §0.5.1 C4/C8/C12 明列）✓；check-gate-sync.sh 改动均为集合比对增强方向、未回退文本段 diff（禁动项方向一致）✓；2 tarball 删除（CHANGE What 14e+文件头声明；gitignore 产物）✓；.git/hooks/pre-push（CHANGE What 2）✓；common.sh 仅 :192（T14 action 自限）✓；PRESET_MAP 只追加不改名（T17 仅比对）✓；L2-blind-review.md 不在任何 write_files ✓；test/ 仅 .bats ✓。
- **L-031 四象限（3 锚）**：①全短语锚分布见 R1；②`check-gate-sync` 引用面（非 .specs）=test_quality_baseline.bats（T12c ✓）/test_check_gate_sync.bats（⚠R3）/用户指南×2（T12c ✓）/pipeline-gates.md:4（T12c ✓，实测该行即「单一源」声明行）/Makefile（T08/T12b/T17 ✓）；③`resolve_gate_config`=check-gate-sync.sh ×2（T07 定义点）/skills/flow/SKILL.md:136 文档性提及（T07 实装后语义不变，无需改）/test_gate_config_presets.bats ×36+镜像（T07 ✓）。`check-skills-sync` 名无生产占用 ✓。

### 三、发现清单

### 🔴 R1 · T11 verify 第三锚全仓口径恒红，阻断 T11 及全部下游链
- **Severity**: Critical
- **Symptom**: `.specs/health-fix-2026-09c/TASK.md:323`（verify 第三锚 `-eq 1`，scope=`.`）；`.specs/health-fix-2026-09c/TASK.md:324`（done 自称「REQUIREMENT AC-15-③ 原式」）
- **Source**: 实测全仓当前=22（分布见一.1）；终态=17，残留全在 `.specs` 文档面（含 TASK.md/REQUIREMENT.md 自身与本审查文件）。REQUIREMENT AC-15-③ 原式 scope=`flow-kit-bundle/`，实测当前=4、终态=1 恰可达——TASK 版把 scope 悄悄放宽为 `.` 却仍标 `-eq 1`。
- **Consequence**: T11 永不能转绿 → T12a→T12b→T12c/T17/T13→T16 全下游阻塞，fix-loop 空转；AC-15-③ 无法验收。
- **Remedy**: 锚 scope 收回 `flow-kit-bundle/`（与 REQUIREMENT 判据逐字一致；测试字面量拼接已保证镜像 0 命中，终态恰=1）。

### 🟡 R2 · T12c write_files 缺 test_skills_sync.bats 及其镜像（R7.3 越界）
- **Severity**: Important
- **Symptom**: `.specs/health-fix-2026-09c/TASK.md:396-402`（write_files 5 项不含该文件）vs `.specs/health-fix-2026-09c/TASK.md:404`（action「预设名断言迁入 T12b 已创建的 test_skills_sync.bats」）、`:406`（verify 直接 `npx bats test/test_skills_sync.bats` + `make check-test-sync` 强制镜像同步）、`:20`（「T12b→T12c（同写 test_skills_sync.bats）」）
- **Source**: 迁入即写；镜像不同步则 check-test-sync 必红。
- **Consequence**: 执行时要么写越界（违反 R7.3 声明边界）要么无法合规完成任务。
- **Remedy**: write_files 补 `test/test_skills_sync.bats` 与 `flow-kit-bundle/test/test_skills_sync.bats` 两行。

### 🟡 R3 · T12b 摘除 PAIRS 的测试面无人承接，假绿延迟至 T16 才爆
- **Severity**: Important
- **Symptom**: `.specs/health-fix-2026-09c/TASK.md:362-368`（T12b write_files 5 项不含 test_check_gate_sync.bats）；`test/test_check_gate_sync.bats:85-86`（隐藏 flow-evolve SKILL 断言转红）、`:114`（X-DRIFT-SKILL-ONLY 注入 flow-evolve 断言转红）、`:105/:167/:208`（遍历 flow-evolve/flow-intel/flow-restyle 的 PAIRS 用例）
- **Source**: T12b action ⑥ 明言摘除 check-gate-sync.sh:36-41 PAIRS 3 对判据（实测 PAIRS 块确在 :37-41）；上述用例断言的正是 PAIRS 漂移检测行为。
- **Consequence**: 摘除后这些用例必红；T12b verify（TASK.md:383）不跑该文件→当场假绿，红暴露在 T16 `make check`（历史重写任务、无该文件 write 授权、修复窗口最差）。
- **Remedy**: T12b write_files 补 `test/test_check_gate_sync.bats`+镜像（相关用例改挂 check-skills-sync），或并入 T12c 同批并补列。

### 🟡 R4 · T10 verify 白名单注释计数 `-ge 2` 硬编码预测值，与 done 自述矛盾
- **Severity**: Important
- **Symptom**: `.specs/health-fix-2026-09c/TASK.md:290`（verify 尾 `'# 行为断言'` 计数 `-ge 2`）vs 同任务 done（r3 R9 修订：「实测白名单注释当前=0，保留数以执行时清单为准」）
- **Source**: 实测当前 `# 行为断言` 计数=0；探针残留实测=32（`-eq 0` 锚可达 ✓）。`-ge 2` 把「预计 ≥2 条 $ 变量路径探针」的预测编码为硬门禁，而 done 又宣布保留数以执行时为准。
- **Consequence**: 合规终态若保留 0/1 条则恒红，唯一过关路径是造假白名单注释或故意不转换探针。
- **Remedy**: 删该子锚，或改为与「C6 位点清单」登记的保留行数对账（计数=登记值）。

### 🟡 R5 · T02 处方「删 3 字符」与 set -euo pipefail 矛盾，warning 无法打印
- **Severity**: Important
- **Symptom**: `.specs/health-fix-2026-09c/TASK.md` T02 action（「删 :200 的 `|| true`（3 字符）…走 module_output warning」）；`flow-kit-bundle/hooks/stop/29-independent-review.sh:13`（`set -euo pipefail`）、`:200`（`l3_review_run … || true` 后接 `local bl_rc=$?`）
- **Source**: 删 `|| true` 后裸命令失败即被 set -e 终止，`local bl_rc=$?` 与 warning 行永不执行——AC-6「warning 实际打印」不成立。DESIGN D6 的「rc 前置捕获」即为此而设，但 TASK 处方未落地。
- **Consequence**: 字面执行处方必被 T02 自身 bats 转红（可自纠），保证浪费一轮 fix-loop；done 断言「删 || true 后 warning 实际打印」按字面为假。
- **Remedy**: 处方改为 `bl_rc=0; l3_review_run … || bl_rc=$?`（D6 前置捕获的落地形态），同步修 done 措辞。

### 🟢 R6 · T12a 对账循环依赖 shell 语义巧合实现空子句 fail-closed
- **Severity**: Minor
- **Symptom**: `.specs/health-fix-2026-09c/TASK.md:349`（awk 循环）
- **Source**: 空子句行 rc=1 依赖 `IFS=$'\t'` 将前导空字段吞并致 dest 错位落 `*` 分支——结果安全但非显式设计。
- **Consequence**: 未来 IFS/read 语义调整可能翻转为静默通过（`grep -qF ""` 恒命中）。
- **Remedy**: awk 过滤条件显式加 `$2 !~ /^[[:space:]]*$/`（或循环内 `[ -n "$clause" ] || exit 1`）。

### 🟢 R7 · T17 对用户指南的只读对账与 T12c 写入存在未声明的同 wave 竞态
- **Severity**: Minor
- **Symptom**: `.specs/health-fix-2026-09c/TASK.md:539`（T17 ③「用户指南 :1585 枚举对账（只读，不符即红——T12c 已保证其指名正确）」）vs `:545`（T17 depends_on=T07,T12b，无 T12c 边）
- **Source**: T12c 与 T17 同 Wave 5 且均仅串行于 T12b，可并发；预设名集合不受指名更新影响，实害概率低。
- **Consequence**: 最坏情况 T17 读到 T12c 写到一半的指南产生伪红/伪绿。
- **Remedy**: 补 T12c→T17 串行声明或依赖边（或对账改为容忍中间态）。

### 🟢 R8 · T12a 体量超「单任务 ≤200 行」粒度指引
- **Severity**: Minor
- **Symptom**: `.specs/health-fix-2026-09c/TASK.md` T12a（16 载体薄壳化 + ≈52 条款逐条处置 + 2 个回填节）
- **Source**: 机械薄壳虽模板化，delta 行数必然超指引。
- **Consequence**: 单任务 review/回滚粒度变大。
- **Remedy**: 维持步骤①②两段门槛 + T12b 反向门禁兜底即可，登记残余风险（无需再拆）。

### 🟢 R9 · AC-16 Then 侧无任务 verify 承接
- **Severity**: Minor
- **Symptom**: `.specs/health-fix-2026-09c/TASK.md` 文件头备注（「AC-16 Given 已实测成立…仅剩验证」）——全 19 任务无一条 verify 覆盖 AC-16
- **Source**: 独立复核 Given 成立：`.specs/STATE.md:71` C9 降级登记在、TD 基线=132 ✓。Then 侧为纯只读检查，阶段 5 可从 REQUIREMENT 直推。
- **Consequence**: 验收口径依赖阶段 5 自行派生，TASK 层无显式锚。
- **Remedy**: T16 收尾步或 7-integration 备注显式认领一条 `grep -n 'C9' .specs/STATE.md` 锚。

**Verdict**: fail

---

## 主 agent 响应（阶段 3 · 对 L2 重审 r4 · 2026-09-29）

> R1–R5（1🔴 + 4🟡）全部 Fixed in；R6–R9（4🟢）就地修正。

- **R1 🔴 Fixed in**：T11 verify 第三锚 scope 收回 `flow-kit-bundle/`（REQUIREMENT AC-15-③ 原式口径）——全仓口径实测=22、终态=17（残留全为 .specs 文档面，含 verify/done 自身与本审查文件）结构性不可达已废弃；bundle 域实测当前=4、行动面迁移后终态=1 恰可达；done 注记录口径与废弃理由。
- **R2 Fixed in**：T12c write_files 补列 test/test_skills_sync.bats + 镜像（断言迁入载体，R7.3 边界闭合）。
- **R3 Fixed in**：T12b write_files 补列 test/test_check_gate_sync.bats + 镜像；action ⑥ 增「同批修 PAIRS 依赖用例（:85-86/:105/:114/:167/:208）」；verify 增跑该 bats——消除「当场假绿、T16 make check 才爆」的延迟红灯。
- **R4 Fixed in**：T10 verify 尾删硬编码 `-ge 2` 子锚（与 done「保留数以执行时清单为准」矛盾，合规保留 0/1 条即恒红诱发造假）；保留主锚（残留探针归零）+ C6 位点清单逐文件对账。
- **R5 Fixed in**：T02 action 处方改 D6 前置捕获——`bl_rc=0; l3_review_run … || bl_rc=$?`，失败分支走 module_output "warning" 且 rc 透传（原「裸删 3 字符」在 :13 set -euo pipefail 下 warning 永不打印，AC-6 不成立）；done 同步「前置捕获落地后 warning 实际打印且 rc 透传（非裸删）」。
- **R6 就地修正**：T12a awk 增 `if (c == "") next` 显式空子句过滤（空子句 fail-closed 原属 IFS 吞字段巧合，防 shell 语义漂移）。
- **R7 就地修正**：T17 depends_on 补 T12c 边（`T07, T12b, T12c`）+ 波次图 T17 标注同步——③「用户指南只读对账」隐含的 T12c→T17 顺序显式化，消除同 Wave 5 竞态。
- **R8 就地修正**：T12a done 增残余风险登记（单任务体量超 ≤200 行指引，靠步骤①侦查处置门槛 + T12b 反向门禁兜底）。
- **R9 就地修正**：AC 归属声明增「AC-16 Then → 7-integration 显式认领 grep 锚（C9 降级四项 v2 挂账在 STATE.md:71/CHANGE.md 存在性断言）」。

---

## L2 盲审（重审 · 第 5 轮 · 阶段 3 · 2026-09-29）

- 审查对象：`.specs/health-fix-2026-09c/TASK.md`（19 任务 7 波次版本）
- 方法：所有锚点均由本审查员当轮独立实测（grep/计数/可达性模拟），未采信 TASK.md 内任何「r2/r3/r4 R<N> 修订已验证」自述；未读取任何既往审查文件。
- 上一轮修复核验（5 项重点）实测结论：① T11 第三锚 bundle 域实测=4（29-independent-review.sh:138/:239 报文 ×2 + flow-kit-bundle/test/test-l2-first-correction.bats:55/:56 测试字面量 ×2），迁移终态=1 可达、当前红非恒真；comm 归一化锚当前=117、**去除 :36-198 复制段后模拟=0**（可达性已模拟证实）。② T02 处方 `bl_rc=0; cmd || bl_rc=$?` 在 :13 `set -euo pipefail` 下推演成立（|| 列表左支失败不触发 errexit，赋值返回 0，bl_rc 透传真实 rc，warning 分支复活）。③ T12b write_files 已补 test_check_gate_sync.bats+镜像且 verify 增跑 bats；T12c write_files 已补 test_skills_sync.bats+镜像且 verify 跑它——action/verify/write_files 三者一致。④ T10 verify 尾部 -ge 2 子锚已删，主锚实测当前=32（红）、白名单注释 5 文件各=0，终态 0 可达。⑤ T17 depends_on=T07,T12b,T12c 且波次图 :15 标注串行；T12a awk 含 `if (c == "") next` 空子句过滤，管道原样执行通过（空表现值=0 行）。
- 结构核验：DAG 无环（全部跨波依赖指向更早波次；同波串行约束 T12b→T12c、T12b→T17、T12c→T17 三处均已声明且波次图标注）；同波文件冲突除已声明串行外为零（Wave 5 五任务写面逐一比对）；AC-1…AC-17 全部有承接（AC-13→T16⑦、AC-14→7-integration、AC-16 Then→7-integration 头部显式声明；AC-16 Given 独立复核成立：STATE.md:71 C9 降级登记 ✓、TD 基线 132 ✓）；write_files∩禁动清单交集均有出处背书（gate 核心链三文件+Makefile=DESIGN 0.5.1；tarball×2 删除=CHANGE What 14e；.git/hooks/pre-push=CHANGE What 2；L2-blind-review.md 不在任何 write_files ✓）。
- L-031 通用项（两跨文件锚四象限）：锚 1 `check-gate-sync` 非 .specs 域 9 文件全部被 T03/T07/T08/T12b/T12c/T17 write_files 覆盖，DESIGN 更名触点 4 组全被 T12c 覆盖——象限③④=∅；锚 2 `.flow-active` 内联解析：Makefile:250-251（T13 改调）、independent-review-gate.sh:64 变量间接（T13 :63-65）、verify-claims.sh:40（tracked 仓根工具，落入 DESIGN 附录 A 谓词全域、处置=白名单登记，T13 白名单重建涵盖）——无漏列未改项。

### 🟡 R1 · T10 write_files 缺 TASK.md：「C6 位点清单」回填无写权
**Severity**：🟡 Important
**Symptom（症状）**：TASK.md:272-283（T10 write_files 仅 10 个测试文件）vs TASK.md:287-289（action：「DESIGN C6 32 处清单以『文件:行号』逐位点落**本文件**新增『C6 位点清单』节」）及 :292（done：「保留位点的具体行号执行时回填『C6 位点清单』」）。
**Source（源头）**：TASK.md:556 自注「read_files/write_files 是 R7.3 强约束」；同类回填任务 T05（TASK.md:140-143）与 T12a（:336-341）均正确列入 TASK.md。
**Consequence（后果）**：T10 执行到清单回填步即面临 R7.3 边界违规或跳过回填（后者使 verify 的「以本表为准」对账落空），执行期爆。
**Remedy（修补）**：T10 write_files 增补一行 `.specs/health-fix-2026-09c/TASK.md`（W3 无同波冲突）。

### 🟡 R2 · T14 write_files 缺 CHANGE.md：6 候选判定登记无写权
**Severity**：🟡 Important
**Symptom（症状）**：TASK.md:455-457（write_files 仅 common.sh）vs :459（action：「其余 6 个候选**在 CHANGE 14c 段登记**『测试专用是否设计意图』判定结论」）。
**Source（源头）**：R7.3 强约束（同 R1）；CHANGE C14-a 判定要求本身要求登记不静默。
**Consequence（后果）**：登记步无写权：违规写入或漏登记（违背「不静默」判据），AC-12-a 判定留痕落空。
**Remedy（修补）**：T14 write_files 增补 `.specs/health-fix-2026-09c/CHANGE.md`。

### 🟡 R3 · T12a write_files 缺 flow-kit/GO.md：flow-go 独有条款「并入」目标无写权（条件性）
**Severity**：🟡 Important
**Symptom（症状）**：TASK.md:336-341（write_files = `skills/flow-*/SKILL.md` + `flow-kit/prompts/*.md` + TASK/CHANGE）；DESIGN.md:124（D5：flow-go 权威正文 = `flow-kit/GO.md`）。实测 `flow-kit-bundle/flow-kit/GO.md` 存在，但两个 glob 均不辖它。
**Source（源头）**：DESIGN D5 豁免映射；C13 步骤①处置二分（并入对应权威载体 / 弃用登记）。
**Consequence（后果）**：若段集 diff 判定 flow-go 存在需并入的 skill-独有条款，执行器对其权威载体 GO.md 无写权 → 阻塞、R7.3 违规、或语义失真改记「弃用」；verify awk 的 `grep -qF "$clause" "${dest#并入→}"` 只读可查但写入面缺位。
**Remedy（修补）**：T12a write_files 增补 `flow-kit-bundle/flow-kit/GO.md`（一行保险；若执行时判定 flow-go 零独有条款则自然零触碰）。

### 🟡 R4 · T17 五载体比对语义未定义且指南载体只读：实测载体集已发散
**Severity**：🟡 Important
**Symptom（症状）**：TASK.md:544-548（action ①③：「JS 侧 PRESET_MAP 键集读取」「用户指南 :1585 枚举对账（只读，不符即红）」，未定义集合语义）；实测 dsh-flow-kit/lib/flow-state.js:20 起 PRESET_MAP 键集=9（all/design/full/integration/plan/requirement/review/task/test），而 FLOW-KIT-用户指南.md:1585 枚举=16+ 名（另含 code-only、design-review、requirement-review、spec-test、task-review、task-test、task-test-review、test-review 复合名/别名，自述「共 17 项（code-only 与 review 是同一映射的别名）」）。
**Source（源头）**：ADR-031 决策 4（JS 入域、五载体比对为替代闸）；TASK.md:546 对指南的保障仅援引「T12c 已保证其指名正确」——T12c（:411）只改 checker 指名字符串，不保证枚举集正确。
**Consequence（后果）**：若实现为严格集合相等，比对上线即红且指南侧无写权（T17 对指南只读）→ T17 阻塞；若实现为宽松包含，语义未写明则执行器自由裁量，反向控制（④）判据力存疑。
**Remedy（修补）**：T17 action 补一句比对语义（推荐：以 skills/flow/SKILL.md 的 PRESET_MAP 为权威全集，JS 键集/白名单枚举须为其子集且别名按指南自述折算；或复合名派生规则写死），或给 T17 增列用户指南写权用于枚举纠偏。

### 🟡 R5 · T16 verify 缺「本地全历史逐 blob 真名=0」机检锚：不可逆操作核心判据仅人工判读
**Severity**：🟡 Important
**Symptom（症状）**：TASK.md:521-522（verify = bundle verify + ls-remote + make check + 用例计数 + 两个临时文件缺席；AC-5 Then 的逐 blob 扫描仅存于「终判（人工判读）」注释行）。
**Source（源头）**：REQUIREMENT AC-5 Then（本地+远端逐 blob=0）；L2-blind-review 阶段 3「verify 可机器执行且判据有判别力」——make check 内的 check-path-privacy 只扫 tracked 工作区，不扫历史 blob。
**Consequence（后果）**：历史重写是全 change 唯一不可逆步骤，其核心隐私成果（filter-repo 是否真清干净）无机器判据；人工漏判即永久性真名泄漏入远端。
**Remedy（修补）**：verify 追加本地等价锚一行，如 `test "$(git grep -cF "$HOME" $(git rev-list --all) 2>/dev/null | wc -l)" -eq 0`（或 rev-list --objects + cat-file 批扫变体）；远端 clone 扫描保留人工判读可接受。

### 🟢 R6 · T14 删除范围宜显式含注释块
**Severity**：🟢 Minor
**Symptom（症状）**：TASK.md:459「删 :192 jq_atomic_write」；实测 common.sh:188-190 三行注释（含 `# Usage: jq_atomic_write ...` 字面量）+ :192 函数体；verify 锚 `grep -rn 'jq_atomic_write' flow-kit-bundle/hooks/ | wc -l -eq 0`（当前=2）。
**Source（源头）**：锚与删除范围须闭合（「只动 :192 附近」措辞可覆盖但未写明）。
**Consequence（后果）**：严格执行器只删函数体时锚剩 1 恒红，返工一轮。
**Remedy（修补）**：action 措辞改「删 :188-196（含 Usage 注释块与函数体）」。

### 🟢 R7 · T05 变量间接形态缺机器种子命令
**Severity**：🟢 Minor
**Symptom（症状）**：TASK.md:149-150 verify 三命令（`[ ! -f "$HOME` / `[ -d "$HOME` / `HOME夹具自包含`）均原样执行通过，但 action :145 声明的第 4 谓词分支（变量间接，赋值 `X="$HOME/…"` 下游同辖，如 test_l3_review_defects_2026_09.bats:973-974）无对应命令，纯人工判读。
**Source（源头）**：r2 R5 修订只要求「命令可原样执行」；变量间接确需语义判定，但可给种子。
**Consequence（后果）**：人工域偏大，重扫遗漏风险（正是 C14-c 要修的漂移面）。
**Remedy（修补）****：verify 增第 4 命令 `grep -rn '="\$HOME' test/*.bats | sort -u` 作人工对账种子。

### 🟢 R8 · mock "independent" 计数口径漂移（CHANGE 92 vs TASK 72 vs 实测 72）
**Severity**：🟢 Minor
**Symptom（症状）**：CHANGE.md C5 证据行 ×92；TASK.md:204（T07 action）×72；实测 `grep -c '"independent"' test/test_gate_config_presets.bats` = 72（与 TASK 一致）。
**Source（源头）**：证据表口径未标注（92 疑为不含引号宽口径或含镜像计数）。
**Consequence（后果）**：下游对账引用 CHANGE 行时误判工作量/漂移量。
**Remedy（修补）**：T07 执行时在 CHANGE C5 段补一行口径标注（72=带引号契约值形态）。

### 🟢 R9 · T12a 体量超 ≤200 行指引（维持已登记处置）
**Severity**：🟢 Minor
**Symptom（症状）**：T12a 触 16 SKILL + 14 prompts；TASK.md:352 已自登记残余风险（r4 R8）+ 步骤①侦查门槛 + T12b 反向门禁兜底。
**Source（源头）**：阶段 3 checklist 粒度指引 vs D2/D5 批量薄壳化的机械同构性。
**Consequence（后果）**：已缓解；再拆分会把「侦查-处置-薄壳」原子性打散。
**Remedy（修补）**：维持现状，无需行动。

### 🟢 R10 · T15 对 test_hook_integration.bats 修复面叙述偏大
**Severity**：🟢 Minor
**Symptom（症状）**：TASK.md:491 称 :17,:20-22,:31,:34-37「grep 探针改行为断言或显式 skip」；实测该 7 位点现状**已是** `|| skip "reason"` 显式跳过带原因（C14-h 判据已满足形态）。
**Source（源头）**：T05 权威名单才是修复面权威（TASK.md:490 亦如此声明）。
**Consequence（后果）**：无实质风险，仅 action 叙述与现状的冗余。
**Remedy（修补）**：执行时以 T05 名单为准，action 措辞可留待顺手修正。

**Verdict**: pass

---

## 主 agent 响应（阶段 3 · 对 L2 重审 r5 · 2026-09-29）

> **Verdict: pass（0🔴/5🟡/5🟢）**。5 🟡 全部 Fixed in；🟢 R6 就地修正（并入 T14 action 同批编辑），R7–R10 → MINOR-DEFERRED M15–M18。

- **R1 Fixed in**：T10 write_files 补 `.specs/health-fix-2026-09c/TASK.md`（「C6 位点清单」节回填需写权）。
- **R2 Fixed in**：T14 write_files 补 `.specs/health-fix-2026-09c/CHANGE.md`（14c 段 6 候选判定登记需写权）。
- **R3 Fixed in**：T12a write_files 补 `flow-kit-bundle/flow-kit/GO.md`（flow-go 权威正文载体，D5 豁免映射「并入」目标条件性补权）。
- **R4 Fixed in**：T17 action ③ 比对语义定死——权威全集 = JS PRESET_MAP 键集（实测 9）；指南枚举（16+，含复合名/别名）做**别名折算后的子集对账**（折算后 ⊇ PRESET_MAP 键集且无未知预设名，不要求严格相等）；折算表内置于 check-gate-sync 并随 test_gate_config_carriers 反向控制钉住，指南侧无写权不阻断。
- **R5 Fixed in**：T16 verify 增本地逐 blob 机检锚 `git grep -F "$HOME" $(git rev-list --all) | wc -l | grep -qx 0`——不可逆步骤的机器兜底，置于终判（全新 clone 逐 blob）之前。
- **R6 就地修正**：T14 action 删除范围写明含 :188-192 及注释块（否则锚剩 1）。
- **R7–R10 → M15–M18**：T05 子命令形态种子（M15）/ CHANGE mock 92→72 口径标注（M16，7-integration）/ T12a 体量维持已登记处置（M17）/ T15 hook_integration 叙述收敛（M18，执行时）。

---

## L3 盲审（阶段 3 · 2026-09-29）

**审查范围**：TASK.md（19 任务/7 波次）对 REQUIREMENT.md（AC-1…AC-17 + 2026-09-29 判据修订对账）、DESIGN.md（§0.5.1/D1–D9/附录 A/§9.2/§9.3/R5/R6）、CHANGE.md（What 0–16）、ADR-030/031/032、CONTEXT.md 禁动清单（:495-534）的跨工件一致性 + 执行安全性 + 验收可达性；全部引用锚本机独立实测，未读禁读文件。

### 发现清单
**critical（0）**：无。
**major（2）**：M1 T08⑤ verify 锚与 D8 接线机制矛盾（TASK.md:230 要求 Makefile 含 'node --test' 字面量≥1，实测=0；D8（DESIGN.md:127）设计为经 package-dsh-plugin.sh --check（:183→:233）间接挂载，check-dist（Makefile:419）已按此接线——锚不可经设计内改动满足，应改锚至 package-dsh-plugin.sh 内 --check 相对 :233 的位置序）。M2 部署根 hooks 镜像再同步无任务承接（REQUIREMENT.md:192 依赖④；T01/T02/T11/T14 目标全在 sync-hooks 镜像集、本机副本实存；仅 T09:257 跑 check-hooks-sync 只检不修，无任务排程 make hooks-sync → T09 verify 必红）。
**minor（8）**：m1 AC-12-b「三处」滞留（REQUIREMENT.md:107 vs 五载体）；m2 D9 C10 卸载安装清单孤儿子决策（DESIGN.md:128 零承接）；m3 ADR-032:17 l3-* 越域注明未履行；m4 读序三方分歧且 D3 误引 ADR-028（DESIGN.md:122 vs ADR-028:43/ADR-031:16/TASK:442）；m5 R5 重写前 git status 净未编码进 T16；m6 T16 write_files 漏列 ../scrub-literals.tmp 与 ../push-url-pre-scrub.tmp；m7 T17 计数陈旧（9/16+ vs 实测 17 键/17 项）；m8 R6③ 同 wave 缓解实为跨 wave（T12a W4/T12b W5）。

### 通过项
① AC 全落地（AC-13→T16⑦、AC-14/16→7-integration 显式声明）；② What 0–16 双向净；③ T16 安全主链（W7 最后、⓪先存 push-url、bundle verify 仓外永不删、全新 clone 逐 blob=0 终判）；④ 高风险 AC 抽验连线成立（AC-5/11/13/12-b/6/9）；⑤ 锚现状全部吻合（gate.sh :42-46/:63-65/:114、29-ir :198-206、PAT :72、AC-12-g 现值 2/0、bats 恰 1116、AC-15① 锚现值 1、L2-first 域现值 4）；⑥ 禁动清单遵守。

### 结论
承载完整、安全主链成立，但 2 个 major 均在 TASK 工件自身（不可达 verify 锚 + 必红无修复排程的门禁步骤），进阶段 4 前应修；预计 TASK.md 数行 + REQUIREMENT/DESIGN 各一处对账标注，修后可复审通过。

**L3 Verdict**: fail

（发现计数：critical 0 / major 2 / minor 8）

<!-- /L3-SECTION -->

## 主 agent 响应（阶段 3 · 对 L3 盲审 · 2026-09-29）

> **2 major + 8 minor 全部处置完毕**。M1/M2 + m1/m3–m8 全部 Fixed in；m2 经 MINOR-DEFERRED **M19** 显式 defer（非本 change 验收项）。评审 agent 两条写回通道均被守卫拦截属实——L3 段由编排侧（本会话 edit 工具）原样落盘，内容零改动，与 ADR-026 / .done 守卫的 fail-closed 设计一致。

- **M1 Fixed in**：T08 action ⑤ 重写——「package-dsh-plugin.sh 的 --check 分支重排，使 node --test（现 :233 段）在 --check 退出之前执行（AC-12-e）；Makefile 侧**不改动**（check-dist :419 已经 --check 间接挂载，D8/DESIGN.md:127）」；verify 锚从 `grep -c 'node --test' Makefile ≥1`（不可达，会逼出绕过 D8 的直连或注释塞字面量）改为 **package-dsh-plugin.sh 内位置序断言**：`ck`（`--check.*exit` 行号）与 `nt`（`node --test` 行号）均非空且 `test "$nt" -lt "$ck"`；done 注同步。
- **M2 Fixed in**：hooks-sync 从隐式假设显式编码为任务排程，四处落位——**T09** 新增 ④ `make hooks-sync`（write_files 补 `.claude/hooks/**` 再同步产物行；verify 改 `make hooks-sync && make check-hooks-sync`）；**T11** verify 尾追加同款 + done 注明 29-independent-review.sh / l2-detect.sh 属镜像集；**T14** verify 尾追加（common.sh 镜像）；**T16⑦** 终判前兜底收口 + verify 链前置 `make hooks-sync`。REQUIREMENT.md:192 依赖④ 补对账标注（T09④/T11/T14/T16⑦ 覆盖全部改 hooks 波次，check-hooks-sync 无先行漂移窗口）。
- **m1 Fixed in**：REQUIREMENT AC-12-b 补 2026-09-29 对账标注——「三处」为 09-20 巡检口径滞留，实际五载体（SKILL / test_gate_config_presets.bats / flow-state.js PRESET_MAP / check-gate-sync.sh 内建集合 / gate-helpers.sh:26 内联值域），统一由 T17 五载体集合比对承载，本处三处为其子集，判据不因载体数放宽。
- **m2 → M19**：MINOR-DEFERRED.md 新增 **M19**（D9 内 C10「卸载清理判据=安装清单文件化」孤儿子决策：v1 不做、7-integration 反哺批评估立项 v2、非本 change 验收项；并注明与 CHANGE C10（lint 语义化）同名异义）。
- **m3 Fixed in**：CHANGE.md 止血层 0=C12 段补 **ADR-032 越域注明**——stop/lib l3-* 三库 jq 断言为纵深加固，超出 AC-8 字面范围，按 ADR-032:17 显式登记出处，验收对账「超出 AC 的改动」以本条为据。
- **m4 Fixed in**：DESIGN.md D3 白名单读序改**三层「常设 > change 目录 > 双缺 fail-closed」**，对齐 ADR-028:43 与 ADR-031:16；并注明原「沿用 ADR-028 决策 1」系误引所引 ADR 原文（ADR-028 决策 1 本身即三层）。
- **m5 Fixed in**：T16 action 新增 ⓪a `git status --porcelain` 输出为空断言（工作树净，不净即中止——DESIGN R5 承接）；verify 链同步加 `test -z "$(git status --porcelain)"`。
- **m6 Fixed in**：T16 write_files 补列 `../scrub-literals.tmp` 与 `../push-url-pre-scrub.tmp`（⓪建⑥删的仓外临时文件）。
- **m7 Fixed in**：T17 action ③ 计数校正为 **17 键 / 17 项**（flow-state.js:20 起逐键实数；指南 :1585 自述 17），标注原 9 / 16+ 为陈旧计数（L2 r5 实测口径已过时）；比对判据本体不变。
- **m8 Fixed in**：DESIGN R6③ 缓解列措辞改「门禁文件紧随薄壳化（T12a W4 → T12b W5 紧邻跨 wave，偏序有界）」，与 TASK 波次图一致；风险列③（窗口内漂移无人拦）由该依赖边钉死为一波窗口。

---

## L3 盲审（重审 r2 · 阶段 3 · 2026-09-29）

- 审查对象：TASK.md（T01-T17 + 波次图 + 附录占位）↔ REQUIREMENT.md（AC-1…17）↔ DESIGN.md（D1-D9、§0.5.1、§5、附录 A）↔ CHANGE.md（What 0-16）↔ ADR-030/031/032 ↔ CONTEXT.md 禁动清单 :495-534；全部 verify 锚逐条本机实测。
- 发现计数：**critical 0 · major 2 · minor 6**
  - M1 TASK.md:207 T07 verify 恒真（三组件今日全绿实测；REQUIREMENT.md:72 AC-7 红锚 `grep -c '"independent"'`=72→0 未采纳）
  - M2 TASK.md:129 T04 verify 恒真（bats 35 ok + check-test-sync 今日全绿；AC-3 裸路径探针无前置红锚）
  - m3 TASK.md:149-150 T05 探针 B/C 今日 0 命中、C 为 T15 后置约定时序错位、rc 恒绿、并集 2/11 种子
  - m4 TASK.md:573 越权写声明不实（T06 09c 三文件 + test_makefile_gates/test_gate_config_carriers/GO.md 不在 DESIGN 0.5.1；实测证明写必要但无授权记录）
  - m5 读序矛盾：DESIGN :68/:69/:266 两层 vs :122 D3(m4)/ADR-031:16/实测代码 :97-102 三层；附录 A 自相矛盾
  - m6 五载体口径：REQUIREMENT :107 第五载体=check-gate-sync 内建 vs DESIGN :225/T17=用户指南
  - m7 T13 改 hooks 无自有 hooks-sync（TASK :452），REQUIREMENT :192「覆盖全部波次」过陈（W6→T16⑦ 漂移窗口，无门禁受损）
  - m8 T11 done 称「AC-15-① 已标注恒真」但 REQUIREMENT :135 无该标注（commit-protocol 实测 0，空真）
- 通过：AC 落点全、DAG 无环且与波次一致、两处同波串行已声明、T16 不可逆链完整（备份/净树/临时文件终判/新 clone 双分支/T16 最后）、15/17 锚实测红→绿可达、T06 锚与实测污染集全等、32/1116/17 键/163 行 diff=0/comm 119/TD=132 等对账数全部相符。

**L3 Verdict**: fail

<!-- /L3-SECTION -->

## 主 agent 响应（阶段 3 · 对 L3 重审 r2 · 2026-09-29）

> **2 major + 6 minor 全部 Fixed in**。两恒真锚按「取 REQUIREMENT 自带红锚」处方修复；四处口径/排程缺口就地补齐。

- **M1 Fixed in**：T07 verify 追加两红锚——`test "$(grep -c '"independent"' test/test_gate_config_presets.bats)" -eq 0`（实测 72→0）+ `test "$(grep -rn 'resolve_gate_config' flow-kit-bundle/ --include='*.sh' | wc -l)" -ge 1`（实测 0→≥1）；两锚直取 REQUIREMENT AC-7 验证式；done 注同步。
- **M2 Fixed in**：T04 action 用例名统一带 `T04:` 前缀（计数锚定名），verify 首锚 `test "$(grep -c '@test .*T04:' test/test_path_privacy_gate.bats)" -ge 1`（实测 0→≥1，对「新用例缺失」有检测力）；done 注同步。
- **m3 Fixed in**：T05 verify 补**探针 C（变量间接赋值形态）** `grep -rlF '="$HOME' test/*.bats | sort -u`（B 探针实测 0 命中、真实位点全在该形态）；注释明确**探针 D 'HOME夹具自包含' 为终态锚**（T15 落盘注释后才有命中，T05 时点 0 属预期，不入对账信号）。
- **m4 Fixed in**：TASK :573 声明改「原则 = 0.5.1 范围」+ 新增**TASK 阶段新增写权例外清单**六类，逐项标注授权出处（T06 三文件 L2 r2 R1 / 新测试×2 = 0.5.1 :66「随 TASK 定名」对冲 / GO.md = D5+L2 r5 R3 / .claude/hooks/** = L3 M2 / 双 tmp = AC-5⓪⑥ / TASK.md+CHANGE.md = L2 r5 R1/R2）——阶段 6 审查对账以本清单为据。
- **m5 Fixed in**：DESIGN :68/:69/:266 三处读序统一传播为三层「常设 > change 目录 > 双缺 fail-closed」，并逐处标注「change 种子副本取消 ≠ change 来源层取消」（与 ADR-028:43 / ADR-031:16 / check-path-privacy.sh:97-102 既有三层代码对齐；:69 原引代码作两层佐证系误读已更正）。
- **m6 Fixed in**：REQUIREMENT AC-12-b 对账标注改以 **DESIGN §9.3 为准**——五载体第五 = FLOW-KIT-用户指南.md :1585（17 项）；check-gate-sync.sh 内建集合为**实现载体**（承载折算表与比对逻辑）；T17 对账面覆盖并集不变。
- **m7 Fixed in**：T13 verify 尾追加 `make hooks-sync && make check-hooks-sync`（independent-review-gate.sh 属 sync 镜像集）；REQUIREMENT :192 依赖④ 对账更新为 T09④ + **T11/T13/T14** + T16⑦，覆盖含 W6 在内的全部改 hooks 波次。
- **m8 Fixed in**：REQUIREMENT AC-15-① 补**恒真对账锚标注**——commit-protocol 双计数锚在 SKILL 侧 0 命中时呈 0=0 空真，作用为防回归（残留非 @see 行即失配），判据力由删表锚与 ②③ 承载；T11 done 所引标注落位本条。

---

## L3 盲审（重审 r3 · 阶段 3 · 2026-09-29）

- 审查对象（全部实际读取）：TASK.md（628 行，T01–T17 + W1–W7 波次图 + 三个占位节 + :577 写权例外清单）· REQUIREMENT.md（196 行，AC-1…AC-17）· DESIGN.md（279 行，D1–D9、§0.5.1、R1–R8、§9.2/9.3、附录 A）· CHANGE.md（536 行，Why C1–C14 / What 0–16）· ADR-030/031/032（.specs/adr/030-reference-executable-checkers.md、031-flow-active-single-parser.md、032-fail-closed-unification.md，均 untracked）· CONTEXT.md 禁动清单 :495–534；背景 git status --porcelain = M .specs/{CONTEXT,LESSONS,STATE}.md + ?? 新件；防锚定纪律遵守（未读任何 IR-*/MINOR-DEFERRED/health 报告）。
- 发现计数：**critical 0 · major 0 · minor 6**
  1. [TASK.md:252 / :577④] T09 write_files 列 `.claude/hooks/**（make hooks-sync 镜像再同步产物）` 为幽灵路径——实测 `test -d .claude/hooks` 不存在；sync-hooks.sh:54-55 注释明言「2026-09-21 移除仓库级 .claude/hooks」，:56-62 DEST_ROOTS 六个部署根全部仓外（~/.claude/hooks、dist×2、node_modules×2、~/.config/opencode/hooks）⇒ make hooks-sync 永不产出仓内该路径，条目永不命中——修法：例外④与 T09 write_files 改列实际仓外部署根或删除该条。
  2. [TASK.md:577⑤ ↔ :519] 例外⑤仅授权双 tmp，漏列 T16 write_files 与 AC-5① 创建的 `../backup-pre-scrub-20260929.bundle`（仓外持久产物，不在 0.5.1 新增模块清单）——修法：⑤补列 bundle（出处 = AC-5① / T16 write_files）。
  3. [REQUIREMENT.md:68 + CHANGE.md:192/:307 + TASK.md:209] mock 计数三方口径不一致：REQ「90+」、CHANGE「现 92 处（漂移扩大 20 处）」、TASK「72」——实测 `grep -c '"independent"' test/test_gate_config_presets.bats` 今日 = **72**（与 09-22 基线同值）——修法：REQ AC-7 Given 与 CHANGE C5 统一为引号口径 72。
  4. [TASK.md:209] T07 verify 末锚 `grep -rn 'resolve_gate_config' … | wc -l ≥ 1` 单锚今日已绿（恒真）：今日 = 2，命中 check-gate-sync.sh:194/:225 两条**注释**行，无法承载 AC-7「不再是纯注释」语义（T07 整体检测力由前一锚 "independent"=0 今日 72 红保住）——修法：锚改非注释形态（如函数定义 `resolve_gate_config\(\)` 或去注释行后计数）。
  5. [TASK.md:149] T05 verify 四探针均为 `grep -rlF … | sort -u` 列表输出无断言（管道末位 sort rc=0，零命中也过），对「T05 未执行」零检测力；TASK 自注对账下放 T15（其锚今日红 tarball=2）——修法：加「C14-c 权威名单节非空」断言（`sed -n '/C14-c 权威名单/,/^## /p' TASK.md | grep -c '^|'` ≥ 种子数 11）。
  6. [TASK.md:577⑥] 例外⑥仅注 TASK.md(T10)/CHANGE.md(T14)，但 T05 write_files（:142-143 权威名单节）与 T12a write_files（C13 清单 :590-593 回填）同样写这两个文件（任务级已声明，无执行风险）——修法：⑥补注 T05/T12a 出处。
- 通过面（含实测对账数）：
  - **验收可达**：17 任务 verify 锚逐条本机实测，今日红锚 20+ 条全部确红（T01/T02 新 bats 不存在；T03 test_check_gate_sync.bats:19/:23/:39 实证 cp $SKILL.bak+mv…||true+sed -i 直写 tracked SKILL.md；T04 探针=0；T06 git grep -lF $HOME = **6** 文件 + 09c 非 .done = **3**；T07 = **72**；T08 flock Makefile=0、ck=183<nt=233；T09 flock=0、.git/hooks/pre-push 含 bundle 路径=0；T10 文本探针 = **32**（与 DESIGN C6「32 处」精确吻合）；T11 comm-12=**117**、'1.8 触发时 bats'=1、bundle 域报文=**4**；T12a @see 文件 =**1**/17；T12b/T12c/T13/T14/T15/T17 锚均红）；防回归锚（≥1116 用例实测 =**1116**、commit-protocol=0、指南 check-gate-sync ≥1）均已显式标注。
  - **跨工件一致性**：AC-1…17 全承接（AC-13→T16⑦、AC-14/AC-16 Then→7-integration 显式声明、AC-16 Given 成立 STATE.md:71）；What 0–16 双向无孤儿（What 14e ↔ T15 :471 一致）；T06 write_files 与今日真名文件精确对账（6 tracked + 09c 3 文件 = 例外①全集）；T17 五载体行号锚全中（flow-state.js:20 起 17 键、gate-helpers.sh:26、指南:1585「共 17 项」、check-gate-sync PAIRS_TOTAL=14、bats mirror）。
  - **执行安全**：T16 保护链完整（⓪a 净树断言→① bundle --all 备份+verify→② filter-repo develop+main 双分支实测在→③ reflog expire+gc→④ remote URL 存 ../push-url-pre-scrub.tmp 再重加→⑤ force push→⑥ 删临时带 test ! -f 双锚→⑦ hooks-sync+make check+≥1116 回归）；git-filter-repo 2.47.0 已装；本地逐 blob 锚今日实测 = **5578**（红，任务后应为 0）；T15 tarball 删除有 What 14e 显式授权，两 tarball 未跟踪，CONTEXT.md:502 禁动不涉删除、TD-125 本就建议清掉，.gitignore 禁动未触碰。
  - **结构自洽**：DAG 无环、18 条 depends_on 边全部前向；14 组 write_files 交集逐组核查全部被波次序或已声明串行覆盖（T12b→T12c 同写 test_skills_sync.bats、T12b→T17 同写 check-gate-sync.sh）。
  - **抽样核对**：~45 处生产行号锚全部命中；单文件 bats 基线绿（test_check_gate_sync 16 ok、test_gate_config_presets 34 ok），跑后树无新增脏。

**L3 Verdict**: pass

<!-- /L3-SECTION -->

## 主 agent 响应（阶段 3 · 对 L3 重审 r3 · 2026-09-29）

> **Verdict pass（critical 0 / major 0 / minor 6）—— 6 个 minor 全部 Fixed in**（小修，就地落盘）。阶段 3 L3 门经 r1（fail 2M+8m）→ r2（fail 2M+6m）→ r3（**pass** 6m）三轮收敛。

- **m1 Fixed in**：TASK T09 write_files 的 `.claude/hooks/**` 幽灵条目改为「仓外部署根 ×6（make hooks-sync 产物：~/.claude/hooks、~/.config/opencode/hooks、dist 两镜像、node_modules 两镜像）」并注明依据（仓库无 .claude/hooks，sync-hooks.sh:54-55 已移除、:56-62 DEST_ROOTS 全仓外）；例外清单④同步重写。
- **m2 Fixed in**：例外清单⑤补列 `../backup-pre-scrub-20260929.bundle`（出处 = AC-5① / T16 write_files；git bundle 备份仓外持久产物、永不删）。
- **m3 Fixed in**：mock 计数三方统一为**引号口径 72**（2026-09-29 复测）——REQUIREMENT AC-7 Given「90+」改「72 处（实测引号口径，原 90+ 系口径滞留）」；CHANGE C5「现 92 处/漂移扩大 20 处」改「2026-09-29 复测仍 72 处，无再扩大，原记系口径误计」（后果论证不变）；CHANGE :307（92→72）与 C5 修法②（90+→72）同步。
- **m4 Fixed in**：T07 verify 末锚改**函数定义形态** `grep -cE 'resolve_gate_config[[:space:]]*\(\)' flow-kit-bundle/flow-kit/reference/check-gate-sync.sh ≥ 1`——今日实测 = 0 红（现仅 :194 echo 串与 :225 注释、无定义），T07 落地定义后 ≥1 绿，与 AC-7「不再是纯注释」语义对齐；done 注同步记录口径演变（r2 M1 原锚→r3 m4 修订）。
- **m5 Fixed in**：T05 verify 头部追加两断言——占位句「待 T05 执行时以严格谓词重扫回填」计数 = 0（今日 = 1 红）+ 「C14-c 权威名单」节表行 ≥ 3（表头+分隔+≥1 数据行；今日 = 0 红）；原四探针保留为对账数据源（人工判读），检测力由断言承载。**不采用审者建议的「≥ 11 行」**——T05 全变体谓词重扫后行数是数据驱动的（种子与谓词不符处以谓词为准，可能少于 11），钉死 11 会把数据结论当判据，硬编码反噬（L-031 同型教训）。
- **m6 Fixed in**：例外清单⑥补注 T05（C14-c 权威名单节回填）与 T12a（C13 处置清单回填）对 TASK.md/CHANGE.md 的同授权写权（含 T05/T12a 偏差回写 CHANGE 同授权）。
