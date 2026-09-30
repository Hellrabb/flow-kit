# T10-SUMMARY — C6 行为断言替换 32 处（AC-9）

- 任务：T10（health-fix-2026-09c 阶段 4 DEV · parallel）
- 交付日：2026-09-29
- 范围：5 测试文件 × 双份（test/ 与 $FK_ROOT/flow-kit-bundle/test/ 镜像，逐字节相同）+ TASK.md「C6 位点清单」节回填
- 行号口径：T10 开工实文实测（Wave 1/2 后 DESIGN :51-54 的分布 18/6/4/3/1 已漂移为实测 9/14/4/3/1，总数 32 不变）

## 1. 32 处逐位点处置表

处置 legend：**行为化** = 沙箱夹具注入 + 行为观测（rc/stderr/stdout/产物文件）；**白名单** = 保留文本探针 + `# 行为断言` 注释（AC-9 机检白名单）。

| # | 文件:行号（开工实文） | 处置 | 改法 / 保留理由 |
|---|---|---|---|
| 1 | test_l3_review_defects_2026_09.bats:80 | 白名单 | AC2 归因清单探针（文档属性，无行为面可观测）→ 保留 + 注释 |
| 2 | test_l3_review_defects_2026_09.bats:328 | 行为化 | B1-R17 基线：_l2v 直跑断 fail（L2 层结论不被 L3 干扰） |
| 3 | test_l3_review_defects_2026_09.bats:330 | 行为化 | B1-R17 变异观测：覆盖 _l3_section_spans(){:;} 后 fk_extract_l2_verdict 翻 pass（读侧真消费段边界） |
| 4 | test_l3_review_defects_2026_09.bats:331 | 行为化 | B1-R17 strip 基线：_l3_strip_sections 真切段（L3 消失、L2 verdict 保留） |
| 5 | test_l3_review_defects_2026_09.bats:333 | 行为化 | B1-R17 strip 变异：空 spans 实现 → L3 段保留（写侧同源消费的因果自证） |
| 6 | test_l3_review_defects_2026_09.bats:957 | 行为化 | B5-R1：make -n 干跑观测 Makefile 配方真实接线（`bash sync-hooks.sh` 与 `--check` 变体），chmod 契约探针不动 |
| 7 | test_l3_review_defects_2026_09.bats:980 | 行为化 | B5-R3：沙箱双跑 <HOME>/.claude 部署树——stub lib 断言 BYTES=31337（P0-2/B3 导出链）+ 真 lib 预置熔断计数断言 bypass .done（L3_verdict=skipped / written_by=l3-bypass / 重审段 / 计数清理） |
| 8 | test_l3_review_defects_2026_09.bats:1795 | 行为化 | B12-R3 变异前置自证：与 :1796 合并为 `! cmp -s real mut`（sed 只删匹配行 ⟺ 两份内容不同 = 变异生效且生产真含该调用；生产无该调用则 sed 零命中 → cmp 相同 → 当场红，与原双计数等效） |
| 9 | test_l3_review_defects_2026_09.bats:1796 | 行为化 | 同上 |
| 10 | test_fix_l3_gate.bats:240 | 行为化 | _l3_parse_result 首跑（无既有文件）→ 盲审标题（is_review=false 行为面） |
| 11 | test_fix_l3_gate.bats:243 | 行为化 | 重审轮（既有评审文件）→ 重审标题 + L2 段保留 |
| 12 | test_fix_l3_gate.bats:247 | 行为化 | 追加语义：再跑一轮旧 L3 段被替换恒 1 段、不累积（旧 awk 覆写形态断言退役） |
| 13 | test_fix_l3_gate.bats:253 | 行为化 | _l3_write_done 直调：fail→rc1+.done 不落+NOT written stderr；pass→rc0+KVP 落盘+written stderr |
| 14 | test_fix_l3_gate.bats:256 | 行为化 | 同上（条件消息两探针合并为一组行为观测） |
| 15 | test_fix_l3_gate.bats:261 | 行为化 | >50KB 夹具（60000B 追加）真跑 → rc0 + stderr `WARNING: review file exceeds 50KB`（阈值行为面） |
| 16 | test_fix_l3_gate.bats:290 | 行为化 | _transition_apply 提取 0-change.md 过渡 jq 真跑：.phase=.goal.current_phase=1、门禁 passed=1 |
| 17 | test_fix_l3_gate.bats:295 | 行为化 | 同法 1-requirement.md → 2 |
| 18 | test_fix_l3_gate.bats:300 | 行为化 | 同法 2-design.md → 3 |
| 19 | test_fix_l3_gate.bats:305 | 行为化 | 同法 3-task.md → 4 |
| 20 | test_fix_l3_gate.bats:310 | 行为化 | 同法 5-test.md → 6 |
| 21 | test_fix_l3_gate.bats:315 | 行为化 | 同法 6-review.md → 7 |
| 22 | test_fix_l3_gate.bats:320 | 行为化 | 同法 4-dev.md（--arg next_phase 5）→ 5 |
| 23 | test_fix_l3_gate.bats:325 | 行为化 | 同法 pipeline-gates.md → 5 |
| 24 | test_l2_pretooluse_dispatch.bats:164 | 行为化 | AC-11 正常路径：写入成功 + 无 tmp.* 残留（tmp+mv 原子性观测） |
| 25 | test_l2_pretooluse_dispatch.bats:165 | 行为化 | mv(){return 1;} 注入 → rc3 + `CRITICAL: atomic mv failed` + 半成品不落盘 |
| 26 | test_l2_pretooluse_dispatch.bats:167 | 行为化 | _l3_has_section(){return 1;} 注入 → rc3 + `CRITICAL: L3 content not persisted` |
| 27 | test_l2_pretooluse_dispatch.bats:169 | 行为化 | _l3_write_done 防御：有 L2 无 L3 → rc3 + `.done deferred: L3 content not found` + .done 不落 |
| 28 | test_dual_review_merge.bats:49 | 行为化 | both 无 L2 段直调 _l3_write_done → rc0 + .done 不落 + `deferred (L2 not yet complete, gate_config=both)` stderr |
| 29 | test_dual_review_merge.bats:54 | 行为化 | deferred 防御路径：有 L2 无 L3 → rc3 + deferred 消息（测名同步改为 deferred path 行为描述） |
| 30 | test_dual_review_merge.bats:247 | 行为化 | `>>` 追加语义：既有内容（文件头+L2 段+verdict）逐字保留 + L3 段（重审标题）追加其后 |
| 31 | test_l3_lifecycle_wiring.bats:304 | 行为化 | E4 沙箱：stub l3_review_run 记录被调时可见的 FLOW_KIT_L3_MAX_ARTIFACT_BYTES=42424（=config 值；config_get→export 顺序/变量名断链则子进程见空或默认） |
| 32 | test_l3_lifecycle_wiring.bats:306 | 行为化 | 同上（两行顺序探针合并为一组导出值断言） |

**计数**：行为化 30 / 白名单保留 2（#1 :80 归因文档探针、B1-R17 段内新增的唯一来源守卫探针 `grep -c '^_l3_section_spans() {'`——单一定义点的结构性约束，无行为面）。

## 2. 夹具设计概述（5 类观测面）

1. **直调生产函数（bash -c "source …; fn …"）**：_l3_parse_result / _l3_write_done / fk_extract_l2_verdict / _l3_strip_sections 在 mktemp 工件目录上真跑，断言 rc/stderr/产物文件内容。用于 append/done 条件/50KB/deferred/AC-3 追加语义。
2. **函数级故障注入（source 后覆盖）**：`mv(){ return 1;}`、`_l3_has_section(){ return 1;}`、`_l3_section_spans(){ :;}`——原子写失败/持久化校验失败/段边界同源消费的因果链。非零 rc 一律 `rc=0; cmd || rc=$?` 前置捕获（Wave 1 教训：bats 体内 set -e）。
3. **29 号全链沙箱**：cp lib+29 号 → stub 或预置 .l3-attempts-N → config json + .flow-active fixture + INDEPENDENT-REVIEW-N.md（L2 段）+ REQUIREMENT.md → `env -u FLOW_KIT_L3_BASE_URL -u FLOW_KIT_L3_AUTH_TOKEN HOOK_BASE_DIR/PROJECT_ROOT/CONFIG_FILE/HOOK_TMP_DIR/FLOW_KIT_L3_MODEL=stub-model bash 29号`。观测：stub 模式记导出值（E4/B5-R3 P0-2 面）；bypass 模式断言 .done 凭证+审计段+计数清理（P0-1 面）。B5-R3 与 E4 同范式不同夹具值（31337/42424）。
4. **过渡 jq 提取器 + 真跑（_transition_apply）**：awk 提取文件中首个含 `.goal.current_phase` 与 `.phase =` 的单引号 jq 表达式，对夹具 .flow-active 用 jq 真执行（--arg 按文件变量注入），断言 .phase/.goal.current_phase/phases_done/gates。覆盖 8 prompts + 31-auto-advance（共 9 个位点文件；rollback 行不含 `.phase =` 不会被误抓，实测验证）。断言面 = prompt 附带的命令真的同步状态，而非文本形态。
5. **make -n / cmp 间接观测**：make -n 干跑看配方打印（构建系统接线行为）；`! cmp -s real mut` 替代 grep -c 双计数（sed 单编辑路径下 diff=变异生效，语义等效且更少文本耦合）。

## 3. verify 真实输出（脱敏；check-test-sync 按任务书跳过留编排者）

### 3a. bats 五文件全量

```
1..204
…（201 ok，含 29 个改写/涉及测试全部 ok）
not ok 55  B5-R2: 所有已存在的 hooks 副本与源一致（漂移=0 …）
not ok 91  B5-R5: 反向残留（源已删、副本仍在）可被发现；默认 advisory …
not ok 174 AC-1: 29-independent-review.sh contains L2-wait gating for both mode
```

### 3b. 锚定探针归零（verify 后半段）

```
$ grep -E 'grep [^#]*(--quiet|-q|-c |-rl?|-rn )' <5 文件> | grep -v '# 行为断言' | grep -cE '(/hooks/|/lib/|flow-kit|\.sh)'
COUNT=0
```

### 3c. 三处 not ok 的归因（T11 并行在途干扰，非本任务破坏，重跑一次仍红）

- **AC-1（dual_review :180，非本任务位点）**：grep 字面量 `L2 not yet complete` 于 bundle 29 号。T11 未提交 diff（git diff 实证）把两处该报文迁至 lib/l2-detect.sh::_l2_first_deny()（HEAD 含 2 处、工作树 0 处）。旁证：本任务行为化的 AC-4 断言（_l3_write_done stderr）不依赖 29 号文本，依然绿——正是 C6 行为化抗重构的实例。
- **B5-R2 / B5-R5**：sync-hooks.sh --check 报漂移 8 文件，全部为 T11 在途编辑面（flow-kit-l2-reviewer.md 平台级/复合载体 + hooks 镜像未重放）。镜像重放按任务书属编排者波末统一（不跑 make test-sync），波末 sync 后应自愈。B5-R5 失败残留的 .sync-hooks-orphan-test.sh 测试产物已清理。
- 证据命令：`git diff <29号>` 显示 deny 报文单点迁移注释（T11 AC-15-③）；`bash sync-hooks.sh --check` 输出「漂移 8 个文件」清单全落 T11 文件。

## 4. 偏差与说明

1. DESIGN :51-54 分布 18/6/4/3/1 与开工实文不符（Wave 1/2 已改过这些文件），实测 9/14/4/3/1，总数 32 一致；位点对账以 TASK.md「C6 位点清单」节（本表同源回填）为准。
2. 白名单实测 2 处（非旧硬编码值；任务块 done 已删硬编码，按实测回填）。
3. verify 链中 `make check-test-sync` 按任务书跳过（编排者波末统一跑）；五文件双份以 cmp 逐字节验证相同（5/5 OK）。
4. 改写中顺手把两处 `run --separate-stderr`（bats ≥1.5 才免警）改为 `rc=0; cmd || rc=$?` 手工捕获，消除 BW02 警告并与 Wave 1 纪律一致。
5. test_dual_review_merge.bats 的 AC-4 测名从「message exists in l3-review.sh」改为「.done deferred when L3 content missing (deferred path)」——断言意图不变（deferred 防御路径存在），观测面从文本换成行为。

## 5. 六维自查

1. **文件边界**：仅写 write_files 列 11 文件（5×test/ + 5×bundle/test/ + TASK.md「C6 位点清单」节）+ 本 SUMMARY；未动其他任务文件、未碰任务状态字段。✅
2. **git 纪律**：零 commit、零 stash；未改 .flow-active。✅
3. **用例意图保持**：32 处断言的对象行为逐一对应（盲审/重审、done 条件、50KB、原子写、deferred、追加语义、过渡同步、导出链、熔断出口、变异自证、归因文档）；仅 1 处测名微调（见偏差 5）。✅
4. **镜像一致**：五文件 test/ ↔ flow-kit-bundle/test/ cmp 逐字节相同（5/5 OK），未跑 make test-sync/check-test-sync。✅
5. **verify 真实**：bats 全量 1..204（201 ok / 3 not ok 均归因 T11 在途，含重跑与 git diff 证据）；锚定探针 COUNT=0；check-test-sync 留编排者。✅
6. **SUMMARY 规范**：无真名路径（$FK_ROOT/<HOME> 脱敏）；白名单行均带 `# 行为断言` 注释。✅
