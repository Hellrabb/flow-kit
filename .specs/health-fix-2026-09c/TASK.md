# TASK: 收口 13 个 🔴（health-fix-2026-09c）

- **Change ID**: health-fix-2026-09c
- **关联**: `@.specs/health-fix-2026-09c/REQUIREMENT.md`、`@.specs/health-fix-2026-09c/DESIGN.md`

---

## 波次划分

```
Wave 1 (parallel): T01[C12 fail-closed], T02[C4 告警恢复], T03[C1 沙箱化], T04[C2 正则], T05[C14-c 名单重核]
Wave 2 (parallel): T06[C3 短期脱敏](←T04), T07[C5+C11 闭环](←T03), T08[Makefile 五合一], T09[AC-17 pre-push]
Wave 3 (parallel): T10[C6 行为断言 32 处], T11[C8 载体收敛](←T02)
Wave 4 (parallel): T12a[SKILL 薄壳化](←T11)
Wave 5 (parallel): T12b[check-skills-sync 门禁](←T08,T12a), T12c[更名触点](←T08,T12b 串行约束见 depends), T14[C14-a 死代码], T15[C14-c/h/i 修复](←T05,T10), T17[C14-b 五载体比对](←T07,T12b,T12c 串行约束见 depends)
Wave 6:            T13[C14-f/g 基线 + flow-active-query](←T04, T12b)
Wave 7:            T16[C3 历史重写](←T06, T12b, T13, T15, T17)
```

> 同 wave = 可并行；跨 wave = 必须顺序执行。同 wave 内零同文件冲突，**除两处已声明的串行约束**（L2 r3 R5 修订 2026-09-29）：Wave 5 内 **T12b → T17**（同写 check-gate-sync.sh）与 **T12b → T12c**（同写 test_skills_sync.bats）按 `depends_on` 串行执行，不并行。
> **T16 必须最后**：历史重写后再产生新 commit 会破坏 filter-repo 成果。
> **T17 与 T12b 同 wave 但建了串行依赖（←T12b）**：check-gate-sync.sh 的五载体扩展须在 check-skills-sync 拆分落地后做，执行器按依赖序处理。

---

## 任务清单

```xml
<task id="T01" parallel="true" status="done" model-tier="standard">
  <name>C12 门禁运行期 fail-closed（AC-8）</name>
  <read_files>
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    flow-kit-bundle/hooks/pre-tool-use/gate-helpers.sh
    flow-kit-bundle/hooks/pre-tool-use/gate-checks-basic.sh
    flow-kit-bundle/hooks/pre-tool-use/gate-checks-review.sh
    flow-kit-bundle/hooks/pre-tool-use/auto-checkpoint.sh
    flow-kit-bundle/hooks/stop/lib/common.sh（:226 断言范式参照）
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    flow-kit-bundle/hooks/stop/lib/l3-prompt.sh
    flow-kit-bundle/hooks/stop/lib/l3-section.sh
    .specs/health-fix-2026-09c/DESIGN.md（D4）
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    flow-kit-bundle/hooks/pre-tool-use/gate-helpers.sh
    flow-kit-bundle/hooks/pre-tool-use/gate-checks-basic.sh
    flow-kit-bundle/hooks/pre-tool-use/gate-checks-review.sh
    flow-kit-bundle/hooks/pre-tool-use/auto-checkpoint.sh
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    flow-kit-bundle/hooks/stop/lib/l3-prompt.sh
    flow-kit-bundle/hooks/stop/lib/l3-section.sh
    test/test_fail_closed.bats
    flow-kit-bundle/test/test_fail_closed.bats
  </write_files>
  <action>
    按 D4：independent-review-gate.sh :65 与 :114 的 jq 缺失/非法 JSON 由 `|| exit 0` 改 exit 2 + 具名报文；
    :42-46 source 三子库后按 :33-37 既有 declare -f 范式补断言（函数缺失 → exit 2）；
    **:64 保留放行**（无状态文件 = 非管辖契约），转换点补注释固化；
    auto-checkpoint.sh 头注释 :5/:11「fail-open·不阻断」同步改写 + 其 fail-open 点转 fail-closed；
    l3-review/l3-prompt/l3-section 三库补 jq 存在性断言（对齐 common.sh:226）。
    新建 test_fail_closed.bats：jq 缺失注入（PATH shim）与非法 JSON 注入必须 exit 2。
  </action>
  <verify>npx bats test/test_fail_closed.bats && make check-test-sync</verify>
  <done>AC-8：三个注入面（jq 缺失/非法 JSON/子库函数缺失）全部 exit 2，反向控制转红</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true" status="done" model-tier="cheap">
  <name>C4 恢复积压 L3 失败告警（AC-6）</name>
  <read_files>
    flow-kit-bundle/hooks/stop/29-independent-review.sh
    flow-kit-bundle/hooks/stop/lib/common.sh（module_output 参照）
    .specs/health-fix-2026-09c/DESIGN.md（D6）
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/29-independent-review.sh
    test/test_l3_backlog_alarm.bats
    flow-kit-bundle/test/test_l3_backlog_alarm.bats
  </write_files>
  <action>
    :200 改 D6 前置捕获（L2 r4 R5 修订 2026-09-29——原处方「裸删 || true（3 字符）」与 :13 set -euo pipefail 矛盾：
    裸 l3_review_run 失败即终止脚本、warning 永不打印，AC-6 不成立）：`bl_rc=0; l3_review_run "$pn" "$change_id" "$spec_dir" "skipped" "both" $L3_BG_FLAG || bl_rc=$?`，
    失败分支走 module_output "warning" 级输出（对齐 AC-6 原文，非 error 级；00-gate.sh:71 兜底论据见 D6），
    rc 不吞（bl_rc 透传）。新建 test_l3_backlog_alarm.bats：注入 l3_review_run 失败必须产生 warning 输出且不吞 rc。
  </action>
  <verify>npx bats test/test_l3_backlog_alarm.bats && make check-test-sync</verify>
  <done>AC-6：:200 前置捕获落地后 warning 实际打印且 rc 透传（非裸删）</done>
  <depends_on></depends_on>
</task>

<task id="T03" parallel="true" status="done" model-tier="standard">
  <name>C1 测试沙箱化（AC-1 + AC-2）</name>
  <read_files>
    test/test_check_gate_sync.bats
    .specs/health-fix-2026-09c/DESIGN.md（0.5.2 F6 范式）
  </read_files>
  <write_files>
    test/test_check_gate_sync.bats
    flow-kit-bundle/test/test_check_gate_sync.bats
  </write_files>
  <action>
    :15 的 SKILL 改相对路径常量 SKILL_REL，三个 T02 用例内落到 $SBX/fk/flow-kit-bundle/skills/flow/SKILL.md
    （照搬同文件 F6 范式：flock + mktemp）；teardown 去掉 || true（还原失败必须报警）；备份路径带 $$/mktemp。
    **新增 AC-2 kill 注入用例（L2 r2 R10 修订 2026-09-29）**：夹具运行中注入 SIGTERM/SIGKILL → 断言 rc≠0
    且 `git diff --stat` = 0（防「沙箱化被回退」回归）。
    完成后 make test-sync 双写镜像。
  </action>
  <verify>npx bats test/test_check_gate_sync.bats && make check-test-sync && (npx bats test/test_check_gate_sync.bats & p1=$!; npx bats test/test_check_gate_sync.bats & p2=$!; wait "$p1" && wait "$p2") && test -z "$(git diff --stat)"</verify>
  <done>AC-1/AC-2：kill 注入 rc≠0；并发双跑两实例均绿且 git diff --stat = 0；mktemp 夹具路径在输出可见</done>
  <depends_on></depends_on>
</task>

<task id="T04" parallel="true" status="done" model-tier="standard">
  <name>C2 隐私正则收紧（AC-3）</name>
  <read_files>
    flow-kit-bundle/flow-kit/reference/check-path-privacy.sh
    test/test_path_privacy_gate.bats
    .specs/health-fix-2026-09c/DESIGN.md（D9-C2 门禁面）
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/reference/check-path-privacy.sh
    test/test_path_privacy_gate.bats
    flow-kit-bundle/test/test_path_privacy_gate.bats
  </write_files>
  <action>
    :72 PAT 从「必须尾斜杠」放宽为路径段边界形态；PLACEHOLDER_NAMES 扩全；头部注释补「下游误报处置入口」锚点。
    补 bats 用例钉住「裸 /home/&lt;realname&gt;（无尾斜杠）必须命中」——**用例名统一带 `T04:` 前缀（计数锚，L3 重审 r2 M2 修订 2026-09-29）**；修正 test_path_privacy_gate.bats:35 探针自带尾斜杠问题。
  </action>
  <verify>test "$(grep -c '@test .*T04:' test/test_path_privacy_gate.bats)" -ge 1 && npx bats test/test_path_privacy_gate.bats && make check-test-sync</verify>
  <done>AC-3：裸路径形态命中，占位名不误报（verify 首锚 = 新用例 T04: 前缀计数 今日 0→≥1，对「用例缺失」有检测力——L3 重审 r2 M2 修订）</done>
  <depends_on></depends_on>
</task>

<task id="T05" parallel="true" status="done" model-tier="cheap">
  <name>C14-c 软跳过名单重核固化（AC-12-c 前置）</name>
  <read_files>
    test/*.bats
    .specs/health-fix-2026-09c/CHANGE.md（C14-c 种子清单）
  </read_files>
  <write_files>
    .specs/health-fix-2026-09c/TASK.md
    .specs/health-fix-2026-09c/CHANGE.md
  </write_files>
  <action>
    以严格谓词**全变体**（软跳过模式：`[ ! -f "$HOME` / `[ -d` 安装态探测 / HOME 夹具自包含豁免判定 / **变量间接形态**——赋值 `X="$HOME/…"` 命中则下游 $X 读取同辖，如 test_l3_review_defects_2026_09.bats:973-974，L2 r2 R11 修订 2026-09-29）重扫
    test/*.bats + 镜像，固化权威名单写入本文件「C14-c 权威名单」节（HEALTH 附录 C 11/11 为种子，
    **种子与谓词实测不符处以谓词为准**——REQUIREMENT AC-12-c 已同步对账）；偏差回写 CHANGE.md C14-c 段登记。
  </action>
  <verify>test "$(grep -c '^> 待 T05 执行时以严格谓词重扫回填' .specs/health-fix-2026-09c/TASK.md)" -eq 0 && test "$(sed -n '/^## C14-c 权威名单/,/^## C13/p' .specs/health-fix-2026-09c/TASK.md | grep -c '^|')" -ge 3 && grep -rlF '[ ! -f "$HOME' test/*.bats | sort -u && grep -rlF '[ -d "$HOME' test/*.bats | sort -u && grep -rlF '="$HOME' test/*.bats | sort -u && grep -rlF 'HOME夹具自包含' test/*.bats | sort -u
  # 断言（L3 重审 r3 m5 修订 2026-09-29；波末收口修订 2026-09-30：锚定 '^>' blockquote 形态，消除本 verify 命令文本自引用）：占位句「待 T05 执行时…回填」清零（今日 = 1 红）+ 名单节表行 ≥3（表头+分隔+≥1 数据行；今日 = 0 红）——原四探针为无断言列表输出（零命中也过），检测力由本断言承载
  # 对账（人工判读，L2 r2 R5 修订——命令须可原样执行，说明移注释）：四探针（A 软跳过 / B 安装态探测 / C 变量间接赋值 / D 终态标记）输出合并去重后与本文件 C14-c 权威名单逐一对账
  # 探针 C 为变量间接形态（赋值 X="$HOME/…" 命中即下游同辖——L3 重审 r2 m3 修订 2026-09-29，B 探针实测 0 命中、真实位点全在 C 形态）
  # 探针 D 'HOME夹具自包含' 为终态锚：T15 落盘注释后才有命中，T05 时点 0 属预期，不入 T05 对账信号（同 m3）</verify>
  <done>权威名单固化，偏差已登记 CHANGE</done>
  <depends_on></depends_on>
</task>

<task id="T06" parallel="true" status="done" model-tier="standard">
  <name>C3 短期脱敏 tracked 30 行（AC-4 · 必须在 T04 后）</name>
  <read_files>
    .specs/health/2026-09-22-FULL-SWEEP.md
    .specs/archive/2026-09-28-health-fix-2026-09b/INDEPENDENT-REVIEW-1.md
    .specs/archive/2026-09-28-health-fix-2026-09b/INDEPENDENT-REVIEW-2.md
    .specs/STATE.md
    .specs/LESSONS.md
    .specs/CONTEXT.md
  </read_files>
  <write_files>
    .specs/health/2026-09-22-FULL-SWEEP.md
    .specs/archive/2026-09-28-health-fix-2026-09b/INDEPENDENT-REVIEW-1.md
    .specs/archive/2026-09-28-health-fix-2026-09b/INDEPENDENT-REVIEW-2.md
    .specs/STATE.md
    .specs/LESSONS.md
    .specs/CONTEXT.md
    .specs/health-fix-2026-09c/INDEPENDENT-REVIEW-2.md
    .specs/health-fix-2026-09c/write-done-1.sh
    .specs/health-fix-2026-09c/write-done-2.sh
  </write_files>
  <action>
    6 文件 30 行真名 → 既有脱敏定式 /home/&lt;acct&gt;。逐文件 git grep 定位后替换；只动真名行，不动其他内容。
    **本 change 目录同批脱敏（L2 R1 修订 2026-09-29）**：INDEPENDENT-REVIEW-2.md:233 真名 → /home/&lt;acct&gt;；
    write-done-1.sh / write-done-2.sh 两个辅助脚本**用毕删除**（含真名路径，无保留价值——.done 已落盘）；
    收尾对 09c 全目录跑真名 grep 复扫 = 0。
  </action>
  <verify>test "$(git grep -lF "$HOME" | wc -l)" -eq 0 && test "$(grep -rlF "$HOME" .specs/health-fix-2026-09c/ | grep -v '\.done$' | wc -l)" -eq 0</verify>
  <done>AC-4：tracked 面真名 = 0，且本 change 目录（即将入库面）真名 = 0</done>
  <depends_on>T04</depends_on>
</task>

<task id="T07" parallel="true" status="done" model-tier="top">
  <name>C5+C11 跨层闭环（AC-7 · 与 T03 同文件故串行）</name>
  <read_files>
    flow-kit-bundle/flow-kit/reference/check-gate-sync.sh
    test/test_gate_config_presets.bats
    test/test_check_gate_sync.bats
    .specs/health-fix-2026-09c/DESIGN.md（D1）
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/reference/check-gate-sync.sh
    test/test_gate_config_presets.bats
    test/test_check_gate_sync.bats
    flow-kit-bundle/test/test_gate_config_presets.bats
    flow-kit-bundle/test/test_check_gate_sync.bats
  </write_files>
  <action>
    按 D1：提取器 resolve_gate_config 定义于 check-gate-sync.sh，改读生产 .sh 文本（非 mock、非 shell source）；
    mock 契约值改 "both"（test_gate_config_presets.bats ×72）；提取器保留 {...} 值，比对键值对集合；
    反向控制：both→independent 篡改必须转红。镜像双写。
  </action>
  <verify>npx bats test/test_check_gate_sync.bats test/test_gate_config_presets.bats && make check-test-sync && make check-gate-sync && test "$(grep -c '"independent"' test/test_gate_config_presets.bats)" -eq 0 && test "$(grep -cE 'resolve_gate_config[[:space:]]*\(\)' flow-kit-bundle/flow-kit/reference/check-gate-sync.sh)" -ge 1</verify>
  <done>AC-7：双侧读同一生产实现，键值对集合比对 + 反向控制转红（verify 末两锚 = REQUIREMENT AC-7 自带红锚——mock '"independent"' 计数 72→0、resolve_gate_config 函数定义形态 0→≥1；**L3 重审 r2 M1 修订 2026-09-29**：原三组件今日全绿，对「任务未执行」零检测力；**L3 重审 r3 m4 修订**：原宽 grep 今日=2 命中的是 :194 echo 串与 :225 注释、无定义形态，改计 `resolve_gate_config()` 定义形态，今日=0 红）</done>
  <depends_on>T03</depends_on>
</task>

<task id="T08" parallel="true" status="done" model-tier="standard">
  <name>Makefile 门禁口径统一（AC-10 + AC-12-d/e + C1 加固）</name>
  <read_files>
    Makefile
    package-dsh-plugin.sh
    .specs/health-fix-2026-09c/DESIGN.md（D9）
  </read_files>
  <write_files>
    Makefile
    package-dsh-plugin.sh
    test/test_makefile_gates.bats
    flow-kit-bundle/test/test_makefile_gates.bats
  </write_files>
  <action>
    五合一：① C1 加固——test 目标加 flock 并发闸；② C7——test 与重复运行合并单次（--formatter tap | tee，
    ${PIPESTATUS[0]} 取 rc）；③ C10——lint 按 rc 判红 + 缺工具 fail-closed；④ C14-d——:76 test-sync 由
    cp test/*.bats 改递归（与 :84 diff -rq 口径对齐）；⑤ C14-e——package-dsh-plugin.sh 的 --check 分支
    重排，使 node --test（现 :233 段）在 --check 退出**之前**执行（AC-12-e）；Makefile 侧**不改动**——
    check-dist（:419）已经 `--check` 间接挂载（D8/DESIGN.md:127；**L3 阶段 3 M1 修订 2026-09-29：不在
    Makefile 写 'node --test' 字面量——原 verify 锚不可经设计内改动满足，会逼出绕过 D8 的直连或注释塞字**）。
    **⑥ AC-10 PATH shim 计数用例（L2 r2 R4 修订 2026-09-29）**：新建 test/test_makefile_gates.bats——
    shim 目录前置 PATH 计数 make test 单跑执行次数（计数文件行数 = 1），钉死「重复运行合并」判据。
  </action>
  <verify>make lint && test "$(grep -c flock Makefile)" -ge 1 && ck=$(grep -n -- '--check.*exit' package-dsh-plugin.sh | head -1 | cut -d: -f1) && nt=$(grep -n 'node --test' package-dsh-plugin.sh | head -1 | cut -d: -f1) && test -n "$ck" && test -n "$nt" && test "$nt" -lt "$ck" && npx bats test/test_makefile_gates.bats && make check-test-sync</verify>
  <done>AC-10 + AC-12-d/e：单跑不重复（shim 计数 =1 机检）、lint 语义化、test-sync 递归、JS 单测入门禁（e 的机检锚 = package-dsh-plugin.sh 内 --check 退出点在 node --test 之后的位置序断言——L3 阶段 3 M1 修订 2026-09-29）</done>
  <depends_on></depends_on>
</task>

<task id="T09" parallel="true" status="done" model-tier="standard">
  <name>AC-17 pre-push 并发闸 + 换装</name>
  <read_files>
    flow-kit-bundle/hooks/pre-push/pre-push.sh
    flow-kit-bundle/lib/install_hooks.sh（:95-137 pre-push 部署链 · 只读参照——L2 R7 修订 2026-09-29）
    .specs/health-fix-2026-09c/DESIGN.md（0.5.1 pre-push 条目）
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/pre-push/pre-push.sh
    .git/hooks/pre-push
    仓外部署根 ×6（make hooks-sync 产物：~/.claude/hooks、~/.config/opencode/hooks、dist 两镜像、node_modules 两镜像——L3 重审 r3 m1 修订 2026-09-29：仓库无 .claude/hooks（sync-hooks.sh:54-55 已移除），产物全部仓外不入库）
  </write_files>
  <action>
    pre-push.sh 本体内置 flock 并发闸（实测全文无 flock；F6 同款锁文件 + mktemp）。
    install_hooks.sh **只读确认**（L2 R7 修订；行号按 r2 R13 校正 2026-09-29）：pre-push 部署链——is_flowkit_symlink(:95) +
    deploy_pre_push(:124) + install_file(:126) 已装 bundle 脚本 + symlink 幂等(:132-137)，换装机制已存在，
    本任务不改 install_hooks.sh；delta = ① pre-push.sh 本体 flock；② 本仓 .git/hooks/pre-push 实例
    确认指向/改调 bundle 脚本（部署路径，CHANGE What 2 / C8-A6 项）。
    ③ 裸仓并发双 dry-run 夹具（AC-17②，M11 承接落点）：mktemp git init --bare ×1 + 两并发 push --dry-run 钉 flock。
    ④ `make hooks-sync` 部署根镜像再同步（REQUIREMENT.md:192 依赖④ 承接——**L3 阶段 3 M2 修订 2026-09-29**：
    W1 T01/T02 已改 bundle hooks，本任务先收口镜像再跑 check-hooks-sync，否则 verify 必红；后续 T11/T14
    再改 hooks 时各自 verify 重复本步骤，T16⑦ 终判前再收口一次，不再依赖隐式约定）。
  </action>
  <verify>bash -n flow-kit-bundle/hooks/pre-push/pre-push.sh && test "$(grep -c flock flow-kit-bundle/hooks/pre-push/pre-push.sh)" -ge 1 && test "$(grep -c 'flow-kit-bundle/hooks/pre-push' .git/hooks/pre-push)" -ge 1 && make hooks-sync && make check-hooks-sync</verify>
  <done>AC-17：push 通路并发污染关闭</done>
  <depends_on></depends_on>
</task>

<task id="T10" parallel="true" status="pending" model-tier="standard">
  <name>C6 行为断言替换 32 处（AC-9）</name>
  <read_files>
    test/test_l3_review_defects_2026_09.bats
    test/test_fix_l3_gate.bats
    test/test_l2_pretooluse_dispatch.bats
    test/test_dual_review_merge.bats
    test/test_l3_lifecycle_wiring.bats
    .specs/health-fix-2026-09c/DESIGN.md（C6 32 处清单）
  </read_files>
  <write_files>
    test/test_l3_review_defects_2026_09.bats
    test/test_fix_l3_gate.bats
    test/test_l2_pretooluse_dispatch.bats
    test/test_dual_review_merge.bats
    test/test_l3_lifecycle_wiring.bats
    flow-kit-bundle/test/test_l3_review_defects_2026_09.bats
    flow-kit-bundle/test/test_fix_l3_gate.bats
    flow-kit-bundle/test/test_l2_pretooluse_dispatch.bats
    flow-kit-bundle/test/test_dual_review_merge.bats
    .specs/health-fix-2026-09c/TASK.md（「C6 位点清单」节回填需写权——L2 r5 R1 修订 2026-09-29）
    flow-kit-bundle/test/test_l3_lifecycle_wiring.bats
  </write_files>
  <action>
    32 处源码文本断言改行为断言（先做 test_l3_review_defects 的 18 处）：grep 生产源码文本的探针
    改为沙箱夹具注入 + 行为观测；残留行必须带 `# 行为断言` 注释（AC-9 机检白名单）。
    **位点对账（L2 R4 修订 2026-09-29）**：DESIGN C6 32 处清单以「文件:行号」逐位点落本文件新增
    「C6 位点清单」节；verify 含清单对账——改后逐文件 grep 文本探针计数与清单位点数一致归零
    （白名单注释除外）；机检锚不依赖全仓 grep 单模式（实测近恒绿）。
  </action>
  <verify>npx bats test/test_l3_review_defects_2026_09.bats test/test_fix_l3_gate.bats test/test_l2_pretooluse_dispatch.bats test/test_dual_review_merge.bats test/test_l3_lifecycle_wiring.bats && make check-test-sync && test "$(grep -E 'grep [^#]*(--quiet|-q|-c |-rl?|-rn )' test/test_l3_review_defects_2026_09.bats test/test_fix_l3_gate.bats test/test_l2_pretooluse_dispatch.bats test/test_dual_review_merge.bats test/test_l3_lifecycle_wiring.bats | grep -v '# 行为断言' | grep -cE '(/hooks/|/lib/|flow-kit|\.sh)')" -eq 0</verify>
  <done>AC-9：32 处全部行为断言；残留探针（含 $ 变量路径形态——L2 r2 R3 修订 2026-09-29，旧锚实测恒真已废弃）全部带 `# 行为断言` 白名单注释（保留位点的具体行号执行时回填「C6 位点清单」并标注保留，预计 ≥2 条 $ 变量路径探针——L2 r3 R9 修订：删「当前实测残留=2」断言，实测白名单注释当前=0，保留数以执行时清单为准），按「C6 位点清单」逐文件对账</done>
  <depends_on></depends_on>
</task>

<task id="T11" parallel="true" status="pending" model-tier="standard">
  <name>C8 载体收敛三件（AC-15 · 29-independent-review.sh 故 ←T02）</name>
  <read_files>
    flow-kit-bundle/flow-kit/prompts/4-dev.md
    flow-kit-bundle/skills/flow-dev/SKILL.md
    flow-kit-bundle/flow-kit/.opencode/agent/flow-kit-l2-reviewer.md
    flow-kit-bundle/flow-kit/prompts/independent/L2-blind-review.md
    flow-kit-bundle/hooks/stop/lib/l2-detect.sh
    flow-kit-bundle/hooks/stop/29-independent-review.sh
    test/test-l2-first-correction.bats
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/prompts/4-dev.md
    flow-kit-bundle/skills/flow-dev/SKILL.md
    flow-kit-bundle/flow-kit/.opencode/agent/flow-kit-l2-reviewer.md
    flow-kit-bundle/hooks/stop/lib/l2-detect.sh
    flow-kit-bundle/hooks/stop/29-independent-review.sh
    test/test-l2-first-correction.bats
    flow-kit-bundle/test/test-l2-first-correction.bats
  </write_files>
  <action>
    ① 4-dev.md:99-106 删内联表改纯 @see pipeline-gates.md；flow-dev SKILL 的提交协议语义段改引用 + 头部薄壳声明
    （**内容锚**：'commit-protocol' 字面量在该 SKILL 实测 0 命中——L2 R3 修订 2026-09-29——重复段实在
    :373/:407/:469/:477，按语义段定位改写，锚用段落特征而非字面量）。
    ② l2-reviewer.md:36-198 的 163 行复制段改引用 L2-blind-review.md（源 = prompt）。
    ③ _l2_first_deny() 抽至 l2-detect.sh，29-independent-review.sh :138/:239 两处改调用（生产报文 2→1）；
    测试字面量拼接构造化（'L2-first ''契约未满足'）。
  </action>
  <verify>npx bats test/test-l2-first-correction.bats && make lint && make check-test-sync && test "$(grep -c '1\.8 触发时 bats' flow-kit-bundle/flow-kit/prompts/4-dev.md)" -eq 0 && test "$(comm -12 <(grep -vE '^[[:space:]]*$|^---$|^```' flow-kit-bundle/flow-kit/prompts/independent/L2-blind-review.md | sort -u) <(grep -vE '^[[:space:]]*$|^---$|^```' flow-kit-bundle/flow-kit/.opencode/agent/flow-kit-l2-reviewer.md | sort -u) | wc -l)" -eq 0 && test "$(grep -rn 'L2-first 契约未满足' flow-kit-bundle/ | wc -l)" -eq 1 && make hooks-sync && make check-hooks-sync</verify>
  <done>AC-15 ①②③（L2 r4 R1 修订 2026-09-29——第三锚 scope 收回 flow-kit-bundle/（REQUIREMENT AC-15-③ 原式口径）：全仓口径实测=22、迁移后终态=17（残留全为 .specs 文档面，含本 verify/done 自身），-eq 1 结构性不可达已废弃；bundle 域实测当前=4（:138/:239 报文 ×2 + 测试字面量 ×2），迁移后终态=1 恰可达；删表锚 '1.8 触发时 bats'=0（当前=1）与复制段归一化 comm=0 不变）；注：'commit-protocol' 双计数为恒真对账锚，判据力由删表锚承载，已在 REQUIREMENT AC-15-① 标注；本任务改 hooks（29-independent-review.sh + l2-detect.sh 属 sync 镜像集）——verify 尾 make hooks-sync 收口镜像（L3 阶段 3 M2 修订 2026-09-29）</done>
  <depends_on>T02</depends_on>
</task>

<task id="T12a" parallel="true" status="pending" model-tier="top">
  <name>C13 SKILL 薄壳化 16 载体 + skill 独有条款并入（AC-11 · T11 定范式后批量）（L2 R9 拆分 / R1 修订 2026-09-29）</name>
  <read_files>
    flow-kit-bundle/flow-kit/prompts/*.md
    flow-kit-bundle/skills/flow-*/SKILL.md
    .specs/health-fix-2026-09c/DESIGN.md（D2/D5 + 附录 A）
  </read_files>
  <write_files>
    flow-kit-bundle/skills/flow-*/SKILL.md
    flow-kit-bundle/flow-kit/prompts/*.md
    flow-kit-bundle/flow-kit/GO.md（flow-go 权威正文载体，D5 豁免映射的「并入」目标——L2 r5 R3 修订 2026-09-29 条件性补权）
    .specs/health-fix-2026-09c/TASK.md
    .specs/health-fix-2026-09c/CHANGE.md
  </write_files>
  <action>
    **步骤 ① 侦查（R1 修订——先清点后动手）**：段集 diff 列出 16 载体全部 skill-独有小节（≈52 条强制条款），
    逐条处置 = **并入对应权威 prompt**（补小节，prompts 写权本任务持有）或**显式登记弃用**（落 CHANGE C13 段，
    每条一句理由）；处置清单回填本文件「C13 skill-独有条款处置清单」节（D2「TASK 列清单」代价兑现）。
    **步骤 ② 薄壳化**：按 D2/D5——prompts 为权威载体；16 个 SKILL.md 薄壳化（YAML 头 + @see 可解析锚点，
    豁免映射 flow-go→GO.md、flow-kit-install、skills/flow 不辖）。flow-dev 薄壳声明沿用 T11 已定范式。
    薄壳化只允许发生在步骤 ① 处置完成之后（防止 52 条款静默蒸发）。
  </action>
  <verify>test "$(grep -l '@see' flow-kit-bundle/skills/flow-*/SKILL.md | wc -l)" -ge 13 && make lint && sed -n '/^## C13 skill-独有条款处置清单/,/^## C6 位点清单/p' .specs/health-fix-2026-09c/TASK.md | awk -F'|' '/^\|/ && $2 !~ /^[[:space:]]*(条款摘录|:?-)/ {c=$2; d=$4; gsub(/^[[:space:]]+|[[:space:]]+$/,"",c); gsub(/^[[:space:]]+|[[:space:]]+$/,"",d); if (c == "") next; print c "\t" d}' | while IFS=$'\t' read -r clause dest; do case "$dest" in 并入→*) grep -qF "$clause" "${dest#并入→}" || exit 1 ;; 弃用*) : ;; *) exit 1 ;; esac; done
  # 对账：处置清单每条「并入」类条款必须逐字命中权威 prompt（清单回填后命令可原样执行）</verify>
  <done>16 SKILL 薄壳化 + 52 条款处置（并入/弃用登记）零蒸发 + 豁免映射落实（覆盖门禁在 T12b）（残余风险登记 L2 r4 R8 2026-09-29：单任务体量超 ≤200 行指引，靠步骤①侦查处置门槛 + T12b 反向门禁兜底）</done>
  <depends_on>T11</depends_on>
</task>

<task id="T12b" parallel="false" status="pending" model-tier="top">
  <name>C13 check-skills-sync 覆盖门禁（AC-11）（L2 R9 拆分）</name>
  <read_files>
    flow-kit-bundle/flow-kit/reference/check-gate-sync.sh（同类参照）
    Makefile
    .specs/health-fix-2026-09c/DESIGN.md（D2/D5 + D7 归一化判据）
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/reference/check-skills-sync.sh
    flow-kit-bundle/flow-kit/reference/check-gate-sync.sh
    Makefile
    test/test_skills_sync.bats
    flow-kit-bundle/test/test_skills_sync.bats
    test/test_check_gate_sync.bats（PAIRS 用例同批修——L2 r4 R3 修订 2026-09-29）
    flow-kit-bundle/test/test_check_gate_sync.bats（同上，镜像）
  </write_files>
  <action>
    新建 reference/check-skills-sync.sh（独立可执行、二值 fail-closed，判据 = 归一化行集比对
    （grep -vE '^[[:space:]]*$|^---$|^```' + sort -u 后 comm -12 | wc -l = 0）
    + 覆盖率低于阈值 rc≠0）；Makefile 挂链 check-skills-sync。
    **⑥ PAIRS 旧判据迁移（L2 r2 R2 修订 2026-09-29，🔴 结构级）**：check-gate-sync.sh:36-41 PAIRS 3 对
    （flow-evolve/flow-intel/flow-restyle）的「剥 front-matter 逐行 diff」判据在 T12a 薄壳化后必红——
    同批摘除/迁移：该 3 对的 prompt↔SKILL 一致性职责由 check-skills-sync 覆盖门禁接管（挂链后
    `make check-gate-sync` 必须回绿，否则 AC-13 不可达）；check-gate-sync 保留 gate_config 侧职责
    （T17 随后扩展五载体，串行 ←T12b）。**同批修 test/test_check_gate_sync.bats 的 PAIRS 依赖用例**
    （:85-86/:105/:114/:167/:208——摘除后必红，L2 r4 R3 修订 2026-09-29：write_files 已补列该文件+镜像，
    verify 增跑 bats，消除「当场假绿、T16 make check 才爆」的延迟红灯）。
    **⑦ @see 可解析 + 豁免登记（L2 r3 R7 修订 2026-09-29，承接 DESIGN D5）**：薄壳 @see 锚必须可解析——
    指向的 prompt 文件与小节标题在权威载体 grep 命中（test_skills_sync.bats 反向控制：改任一 @see 指向不存在
    小节必须转红）；豁免载体显式登记进 check-skills-sync 白名单（flow-go→GO.md 映射、flow-kit-install、
    skills/flow 不辖），白名单外覆盖率不足即 rc≠0——AC-11 反向控制（删 prompt 小节必红）在实现层可达。
  </action>
  <verify>make check-skills-sync && make check-gate-sync && npx bats test/test_skills_sync.bats test/test_check_gate_sync.bats && make check-test-sync</verify>
  <done>AC-11 门禁侧：薄壳覆盖 + 覆盖率不足即 rc≠0；PAIRS 旧判据迁移完毕、check-gate-sync 回绿 + test_check_gate_sync.bats PAIRS 用例同批修（AC-13 通路保住）（L2 r4 R3/R2 修订 2026-09-29）</done>
  <depends_on>T08, T12a</depends_on>
</task>

<task id="T12c" parallel="true" status="pending" model-tier="standard">
  <name>C13 更名触点收敛（AC-11 配套）（L2 R9 拆分）</name>
  <read_files>
    test/test_quality_baseline.bats
    FLOW-KIT-用户指南.md
    flow-kit-bundle/flow-kit/reference/pipeline-gates.md
    .specs/health-fix-2026-09c/DESIGN.md（§0.5.1 更名触点组）
  </read_files>
  <write_files>
    test/test_quality_baseline.bats
    flow-kit-bundle/test/test_quality_baseline.bats
    test/test_skills_sync.bats（断言迁入载体——L2 r4 R2 修订 2026-09-29：action 明说迁入 + verify 跑它，补 R7.3 边界）
    flow-kit-bundle/test/test_skills_sync.bats（同上，镜像）
    FLOW-KIT-用户指南.md
    flow-kit-bundle/FLOW-KIT-用户指南.md
    flow-kit-bundle/flow-kit/reference/pipeline-gates.md
  </write_files>
  <action>
    更名触点同批（L2 r3 R4 修订 2026-09-29——T12c 移入 Wave 5、串行 ←T12b，消除 W4 断言指向 W5 才创建载体的时序倒置）：test_quality_baseline.bats:26,29-30,34-35 断言目标拆分——预设名断言**迁入 T12b 已创建的 test_skills_sync.bats**（本任务只做迁移不新建载体）、运行断言归 check-gate-sync；用户指南 :1585 指名更新（含副本）；pipeline-gates.md:4 引用更新（TD-030 存量只改引用）。
  </action>
  <verify>npx bats test/test_quality_baseline.bats && npx bats test/test_skills_sync.bats && test "$(grep -c 'check-skills-sync' FLOW-KIT-用户指南.md)" -ge 1 && test "$(grep -c 'check-gate-sync' FLOW-KIT-用户指南.md)" -ge 1 && make check-test-sync</verify>
  <done>更名触点全收敛，断言归属明确（指南指名锚 ≥1；预设名断言载体 = test_skills_sync.bats——L2 r3 R4 修订 2026-09-29）</done>
  <depends_on>T08, T12b</depends_on>
</task>

<task id="T13" parallel="true" status="pending" model-tier="top">
  <name>C14-f/g 基线常设化 + flow-active-query（AC-12-f/g · Makefile 故 ←T12）</name>
  <read_files>
    flow-kit-bundle/flow-kit/reference/check-path-privacy.sh
    Makefile
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    dsh-flow-kit/lib/flow-state.js
    .specs/health-fix-2026-09c/DESIGN.md（D3 + 附录 A + ADR-031）
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/reference/path-privacy-baseline.txt
    flow-kit-bundle/flow-kit/reference/flow-active-inline-whitelist.txt
    flow-kit-bundle/flow-kit/reference/check-path-privacy.sh
    flow-kit-bundle/lib/flow-active-query.sh
    Makefile
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    test/test_flow_active_query.bats
    flow-kit-bundle/test/test_flow_active_query.bats
  </write_files>
  <action>
    按 D3/附录 A：**首建**常设基线文件（L2 R8 修订 2026-09-29：09c 目录从未创建过种子副本，DESIGN 附录 A
    为唯一规范来源，本任务即首次落盘）：只存通用 PAT + 占位形态 + sha256 对账行，真名明文零 tracked；
    check-path-privacy.sh :89-95 SELF_EXCLUDE 与 :102 ALLOWLIST_CHANGE 解除 09b 硬编码（读序 常设>change>双缺 fail-closed）；
    新建 lib/flow-active-query.sh（.flow-active 统一解析入口）；Makefile:250-253 与 independent-review-gate.sh:63-65
    改调（不进白名单）；白名单按附录 A 谓词四分支（含 dsh-flow-kit JS 与变量间接）重建并回填 N。
  </action>
  <verify>npx bats test/test_flow_active_query.bats test/test_path_privacy_gate.bats && test "$(grep -cE 'done < \.flow-active|\[ -f \.flow-active \]' Makefile)" -eq 0 && test "$(grep -c 'flow-active-query' Makefile)" -ge 1 && make check-flow-active-inline && make check-test-sync && make hooks-sync && make check-hooks-sync</verify>
  <done>AC-12-f/g：硬编码解除、基线常设首建、双锚齐备（负锚 =0 + 正锚 flow-active-query ≥1——L2 r2 R8 修订）+ 附录 A 门禁 make check-flow-active-inline 挂链执行</done>
  <depends_on>T04, T12b</depends_on>
</task>

<task id="T14" parallel="true" status="pending" model-tier="cheap">
  <name>C14-a 死代码清除（AC-12-a）</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/common.sh
    .specs/health-fix-2026-09c/CHANGE.md（14c 判定要求）
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/common.sh
    .specs/health-fix-2026-09c/CHANGE.md（14c 段判定登记需写权——L2 r5 R2 修订 2026-09-29）
  </write_files>
  <action>
    删 :188-192 jq_atomic_write 及其 3 行注释块（L2 r5 R6 修订：含 :188-190 注释，否则锚剩 1）；其余 6 个候选在 CHANGE 14c 段登记「测试专用是否设计意图」
    判定结论（删或登记，不静默）。只动 :188-192 附近，common.sh 其余函数体禁动（TD-134 只读参照）。
  </action>
  <verify>make lint && test "$(grep -rn 'jq_atomic_write' flow-kit-bundle/hooks/ | wc -l)" -eq 0 && make hooks-sync && make check-hooks-sync</verify>
  <done>AC-12-a：jq_atomic_write 删除（域 = flow-kit-bundle/hooks/ 生产面，对齐 REQUIREMENT——L2 r2 R14 修订），其余 6 处判定登记</done>
  <depends_on></depends_on>
</task>

<task id="T15" parallel="true" status="pending" model-tier="standard">
  <name>C14-c/h/i 测试态修复（AC-12-c/h/i · 名单文件故 ←T05, T10）</name>
  <read_files>
    test/test_l3_pipeline_fix.bats
    test/test_hook_integration.bats
    test/test_l3_review_defects_2026_09.bats
    .specs/health-fix-2026-09c/TASK.md（C14-c 权威名单）
  </read_files>
  <write_files>
    test/test_l3_pipeline_fix.bats
    test/test_hook_integration.bats
    test/test_l3_review_defects_2026_09.bats
    test/test_independent_review_model.bats
    test/test_runtime_edit_guard.bats
    flow-kit-bundle/test/test_l3_pipeline_fix.bats
    flow-kit-bundle/test/test_hook_integration.bats
    flow-kit-bundle/test/test_l3_review_defects_2026_09.bats
    flow-kit-bundle/test/test_independent_review_model.bats
    flow-kit-bundle/test/test_runtime_edit_guard.bats
    flow-kit-bundle.tar.gz（删除授权 = CHANGE What 14e——L2 r3 R6 修订 2026-09-29：删也是写，补入边界）
    flow-kit-full-20260803-232437.tar.gz（同上）
  </write_files>
  <action>
    按 T05 权威名单修软跳过（显式 skip + 打印原因，或硬失败）；先修 test_l3_pipeline_fix.bats:561-564 真空通过；
    test_hook_integration.bats :17,:20-22,:31,:34-37 grep 探针改行为断言或显式 skip；
    test_l3_review_defects_2026_09.bats:88 硬编码 SHA be138c0 改 git 动态取或删断言；
    删仓根 2 份陈旧 tarball（27.6 MB + 25.7 MB）。
  </action>
  <verify>npx bats test/test_hook_integration.bats test/test_l3_review_defects_2026_09.bats test/test_l3_pipeline_fix.bats test/test_independent_review_model.bats test/test_runtime_edit_guard.bats && make check-test-sync && test "$(ls *.tar.gz 2>/dev/null | wc -l)" -eq 0</verify>
  <done>AC-12-c/h/i：软跳过显式化、SHA 动态化、tarball 清零（verify 覆盖全部 5 个自写测试文件——L2 r2 R14 修订 2026-09-29）</done>
  <depends_on>T05, T10</depends_on>
</task>

<task id="T16" parallel="false" status="pending" model-tier="top">
  <name>C3 历史重写（AC-5 · 不可逆 · 必须最后）</name>
  <read_files>
    .specs/health-fix-2026-09c/REQUIREMENT.md（AC-5 五步序列）
    .specs/health-fix-2026-09c/DESIGN.md（§9.2 main 提前 v1 行）
  </read_files>
  <write_files>
    .specs/health-fix-2026-09c/scrub-history.sh（执行脚本留痕）
    ../backup-pre-scrub-20260929.bundle（仓外备份）
    ../scrub-literals.tmp（仓外临时 · ⓪建⑥删——L3 阶段 3 m6 修订 2026-09-29 补列）
    ../push-url-pre-scrub.tmp（仓外临时 · ⓪建⑥删——L3 阶段 3 m6 修订 2026-09-29 补列）
  </write_files>
  <action>
    严格按 AC-5 五步：⓪ git remote get-url origin 存仓外 ../push-url-pre-scrub.tmp + 仓外组装真名字面量集
    ../scrub-literals.tmp（用毕删）；⓪a `git status --porcelain` 输出为空断言（工作树净——DESIGN R5 承接，
    **L3 阶段 3 m5 修订 2026-09-29**：不净即中止，防重写吞掉未提交改动）；① git bundle create ../backup-pre-scrub-20260929.bundle --all + verify；
    ② filter-repo develop 与孤儿 main 分别重写（--replace-text ../scrub-literals.tmp）；
    ③ reflog expire + gc --prune=now；④ 重加 remote（filter-repo 默认移除 origin）；
    ⑤ push --force origin develop main。Then：全新 clone（禁 --single-branch）逐 blob 扫描两分支 = 0。
    **⑥ 清理（L2 r2 R12 修订 2026-09-29）**：删除仓外临时文件 ../scrub-literals.tmp 与 ../push-url-pre-scrub.tmp（用毕即删，AC-5 步骤⑥ 显式排程）。
    **⑦ AC-13 回归批（L2 r2 R9 修订）**：重写完成后 `make hooks-sync` 收口镜像（**L3 阶段 3 M2 修订 2026-09-29**：
    W2-W6 期间 T11/T14 等已各自收口，此处终判前兜底）再全量 `make check` 必须回绿 + bats 用例总数 ≥1116 对账
    （AC-13 的任务侧 owner = 本任务收尾步；AC-14 反哺销账归 7-integration 阶段——见文件头备注）。
    执行脚本落 change 目录留痕。
  </action>
  <verify>git bundle verify ../backup-pre-scrub-20260929.bundle && git ls-remote --heads origin && test -z "$(git status --porcelain)" && git grep -F "$HOME" $(git rev-list --all) | wc -l | grep -qx 0 && make hooks-sync && make check && test "$(grep -h '^@test' test/*.bats | wc -l)" -ge 1116 && test ! -f ../scrub-literals.tmp && test ! -f ../push-url-pre-scrub.tmp
  # 终判（人工判读）= AC-5 Then：全新 clone（禁 --single-branch）逐 blob 扫描两分支真名 = 0
  # 本地逐 blob 机检锚（L2 r5 R5 修订 2026-09-29）：git grep -F "$HOME" 覆盖 rev-list --all 全历史——不可逆步骤的机器兜底，终判前先行</verify>
  <done>AC-5：远端两分支逐 blob 真名 = 0，备份 verify rc=0</done>
  <depends_on>T06, T12b, T13, T15, T17</depends_on>
</task>

<task id="T17" parallel="true" status="pending" model-tier="top">
  <name>C14-b gate_config 五载体集合比对（AC-12-b）（L2 R2 新增 2026-09-29）</name>
  <read_files>
    flow-kit-bundle/flow-kit/reference/check-gate-sync.sh
    dsh-flow-kit/lib/flow-state.js（:20 起 PRESET_MAP / resolveGateConfig——行号按 L2 r2 R13 校正 2026-09-29，原 :94-116 漂移）
    flow-kit-bundle/hooks/pre-tool-use/gate-helpers.sh（:26 内联值域）
    FLOW-KIT-用户指南.md（:1585 预设名枚举 · 只读对账——载体五）
    .specs/health-fix-2026-09c/DESIGN.md（ADR-031 决策 4 替代闸）
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/reference/check-gate-sync.sh
    dsh-flow-kit/lib/flow-state.js
    flow-kit-bundle/hooks/pre-tool-use/gate-helpers.sh
    test/test_gate_config_carriers.bats
    flow-kit-bundle/test/test_gate_config_carriers.bats
  </write_files>
  <action>
    五载体预设名集合比对（ADR-031 决策 4 替代闸）：① check-gate-sync.sh 内建 JS 侧 PRESET_MAP 键集读取
    （文本解析 flow-state.js，同 D1「读生产真源文本而非 source」哲学）；② gate-helpers.sh:26 内联值域与
    bash 侧预设集合一致；③ 用户指南 :1585 枚举对账（只读——**比对语义 L2 r5 R4 修订 2026-09-29**：权威全集 =
    JS PRESET_MAP 键集（实测 17 键——**L3 阶段 3 m7 修订 2026-09-29**：原「实测 9」为陈旧计数，flow-state.js:20 起逐键实数）；
    指南枚举（实测 17 项，含复合名/别名，指南 :1585 自述 17——同 m7 校正）做**别名折算后的子集对账**——折算后
    必须 ⊇ PRESET_MAP 键集且无未知预设名，不要求严格相等；折算表内置于 check-gate-sync 并随 testgate_config_carriers
    反向控制钉住，指南侧无写权不阻断）；④ 反向控制：任一载体增删预设名不同步 → check-gate-sync rc≠0（bats 注入篡改用例钉住）。
    新测试 test_gate_config_carriers.bats：正向五载体一致 + 反向逐载体篡改转红。
  </action>
  <verify>npx bats test/test_gate_config_carriers.bats && make check-gate-sync && make check-test-sync</verify>
  <done>AC-12-b：五载体集合比对门禁 + 反向控制转红</done>
  <depends_on>T07, T12b, T12c</depends_on>
</task>
```

> **注意**：`read_files` / `write_files` 是 R7.3 强约束。`write_files` 原则 = DESIGN `## 0.5.1` 触碰+新增范围，
> 与 CONTEXT.md 禁动清单的交集全部为**有出处的显式背书触碰**（L2 r3 R6 修订 2026-09-29）：gate 核心链三文件与 Makefile = DESIGN 0.5.1 明列；2 份陈旧 tarball = CHANGE What 14e 授权删除（T15 write_files 已列）——非「不含禁动清单」的字面零交集，而是每处触碰均有 DESIGN/CHANGE 背书并经独立审查核可。`.git/hooks/pre-push` 例外依据 = CHANGE What 2（C1 加固）+ DESIGN 0.5.1 pre-push 条目「换装只是部署路径」。
> **TASK 阶段新增写权例外清单（L3 重审 r2 m4 修订 2026-09-29——原「严格在 0.5.1 内」声明与下列实事不符，改为显式枚举授权出处）**：① `.specs/health-fix-2026-09c/{INDEPENDENT-REVIEW-2.md, write-done-1.sh, write-done-2.sh}`（T06——本 change 自身工件真名占位化，L2 r2 R1 授权：不写则 T06 脱敏锚恒红）；② `test/test_makefile_gates.bats` / `test/test_gate_config_carriers.bats`（T08/T17——0.5.1 测试清单 :66「随 TASK 定名」对冲的定名落点）；③ `flow-kit-bundle/flow-kit/GO.md`（T12a——D5 豁免映射 flow-go 权威正文条件性补权，L2 r5 R3）；④ **仓外部署根 ×6**（T09——make hooks-sync 再同步产物：~/.claude/hooks、~/.config/opencode/hooks、dist×2、node_modules×2；L3 阶段 3 M2 授权、重审 r3 m1 修订：仓库无 .claude/hooks，sync-hooks.sh:56-62 DEST_ROOTS 全仓外）；⑤ `../scrub-literals.tmp` / `../push-url-pre-scrub.tmp`（T16——AC-5 ⓪建⑥删仓外临时，L3 阶段 3 m6）与 **`../backup-pre-scrub-20260929.bundle`**（T16/AC-5①——git bundle 备份仓外持久产物、永不删，L3 重审 r3 m2 补列）；⑥ `.specs/health-fix-2026-09c/TASK.md`（T10——C6 位点清单回填，L2 r5 R1；T05——C14-c 权威名单节回填，L3 重审 r3 m6 补注；T12a——C13 处置清单回填，同源）与 `.specs/health-fix-2026-09c/CHANGE.md`（T14——14c 段登记，L2 r5 R2；T05/T12a 偏差回写同授权，L3 重审 r3 m6 补注）。
>
> **AC 归属显式声明（L2 r2 R9 修订 2026-09-29）**：AC-13（总门禁 make check 全绿 + 用例数 ≥1116）→ **T16 收尾步 ⑦**（历史重写后回归批）；AC-14（STATE.md 销账 ≥14 行 + TD-134…138 增量登记）→ **7-integration 反哺批**（本 change 阶段 7，载体 .specs/STATE.md + CONTEXT.md，非 TASK 任务）；AC-16 Then → **7-integration 显式认领 grep 锚**（C9 降级四项 v2 挂账在 STATE.md:71/CHANGE.md 存在性断言——L2 r4 R9 修订 2026-09-29，Given 侧已独立复核成立）。AC-16 Given 已实测成立（STATE.md:71 C9 降级登记 ✓ TD 基线 132 ✓），仅剩验证。

---

## C14-c 权威名单（T05 重核后回填 · 种子 = HEALTH 附录 C 11 文件）

> **实测时点**：2026-09-29（T05 执行 · 严格谓词四变体 + 逐文件内容判读；`test/` 与镜像 `flow-kit-bundle/test/` 11 个种子文件逐一 `cmp` 逐字节一致，探针命中同集）。
> **权威源声明（L2 r2 R11 修订 2026-09-29）**：本表（= T05 全变体谓词实测）为唯一权威；HEALTH 附录 C 为种子（宽口径 grep `\$HOME\|~/.claude\|~/.dsh\|~/.config/opencode` = 11 文件），偏差以本表为准（REQUIREMENT AC-12-c 已同步对账；偏差明细已登记 CHANGE.md C14-c 段「实测对账」）。
> **实测权威名单 = 5 文件**（种子 11 → 实测 5；6 文件豁免/不辖，见表后豁免清单）：

| 文件 | 命中形态 | 位点/行号 | 判定依据 |
|---|---|---|---|
| test/test_l3_pipeline_fix.bats | 变体① 软跳过真空通过 | :561-563（T06 用例） | `[ ! -f "$HOME/.claude/hooks/stop/lib/l3-prompt.sh" ] \|\| cmp -s flow-kit-bundle/… "$HOME/…"`——文件缺失 ⇒ 整体不执行且记 ok（真空通过）；存在 ⇒ 以**本机安装副本**当比较基准 ⇒ 同一提交异机绿/红不同（CHANGE 10b 点名先修位点） |
| test/test_independent_review_model.bats | 变体① 安装态读 + 已显式 skip | :172-183 | 读 `$HOME/.claude/stop-hook.json`（:172 注释自认「已安装环境」面——该文件仅存在于 $HOME 安装态）；:176-177 skip 已打印原因（**合规形态**），但 :182 判定值仍取自机器安装态 ⇒ 异机结果不同 |
| test/test_guide_copy_parity.bats | 变体④+② 变量间接 → `[ -d` 安装态探测 | :182-195 | `local inst="$HOME/.dsh/profiles/$prof/node_modules/dsh-flow-kit"`（:184）→ `[ -d "$inst" ] \|\| skip "…未安装…"`（:185）：赋值命中变体④、下游 `$inst` 读取同辖；存在时 :190 cmp 本机已安装副本。字面探针 B（`[ -d "$HOME`）0 命中——真实位点全在间接形态（印证 L3 重审 r2 m3） |
| test/test_l3_review_defects_2026_09.bats | 变体④+② 变量间接 → `[ -d` 安装态探测 | :972-981（B5-R3） | `local d="$HOME/.claude/hooks"`（:973）→ `[ -d "$d" ] \|\| skip "本机无 ~/.claude/hooks（用户级安装）"`（:974）——T05 任务块点名示例；:976-980 grep **本机安装** hooks。同文件 :989/:1328 的 `sed "s#\$HOME/.claude/hooks#$fake#"` 为夹具重定向（hermetic 改写），**不辖** |
| test/test_flow_active_integrity.bats | tilde 展开读安装态（内容判读辖 · 边界判定） | :60-70（AC-1 首用例） | `for f in ~/.claude/flow-kit/prompts/{…}`（:64）——`~` ≡ `$HOME` 展开，读机器安装态；无 skip，缺失 ⇒ count≠9 转红（**硬失败方向**的异机结果不同，同族不同向）。字面探针 A/B/C 均不命中，按「读文件内容判读，不是只跑 grep」以语义辖；处置方向 = hermetic 化或显式环境探针标注（非软跳过修复形）——已标 CHANGE 对账，可复核 |

> **豁免/不辖 6 文件**（种子成员，实测出局，四探针对账明示）：`test_install_jq_guard.bats`（:41-42 `mkdir -p "$HOME_DIR/.claude/hooks"; export HOME="$HOME_DIR"`——HOME 夹具自包含，变体③豁免；探针 C 命中即此夹具赋值）· `test_install_layout.bats`（:35-36 同形夹具，变体③豁免）· `test_runtime_edit_guard.bats`（HOME_DIR 夹具 + :49/:80 `HOME="$HOME_DIR"` 注入子进程，:18 自述「家目录一律以 $HOME 变量拼接」——变体③豁免；INDEPENDENT-REVIEW-3 同判）· `test_l3_lifecycle_wiring.bats`（:279-289 fake_home 锚定 hermetic，种子命中仅 :280 注释 `~/.dsh` 字面）· `test_stop_report_reminder.bats`（:11 自述 hermetic「不依赖宿主 ~/.claude/stop-hook.json」，种子命中仅注释字面）· `test_install_dsh_platform.bats`（:29 `[[ "$output" == *"$HOME/.dsh"* ]]`——$HOME 仅作输出断言期望串，无安装态文件读、无跳过）。
> **下游影响（供 T15 对账，非本任务改动面）**：实测名单含 `test_guide_copy_parity.bats` 与 `test_flow_active_integrity.bats`（均不在 T15 write_files 现集）；`test_runtime_edit_guard.bats` 豁免后无 C14-c 修复面（T15 verify 跑它不破坏，仅非修复对象）。T15 执行时按本表修订文件集。

---

## C13 skill-独有条款处置清单（T12a 步骤 ① 回填 · L2 r2 R1 修订 2026-09-29）

> 待 T12a 执行时以段集 diff（prompts vs skills/*/SKILL.md 归一化行集差集）逐条回填；
> 列格式 `| 条款摘录 | 出处载体 | 处置（并入→目标 prompt 路径 / 弃用） | 理由 |`；「并入」条目由 T12a verify 逐字对账命中权威 prompt，杜绝 52 条款静默蒸发。

---

## C6 位点清单（T10 执行时以「文件:行号」逐位点回填 · L2 阶段 3 R4 修订）

> T10 已回填（2026-09-29）。行号为 T10 开工实文实测值（Wave 1/2 后 DESIGN 行号有漂移，分布 18/6/4/3/1 → 实测 9/14/4/3/1，总数 32 不变）。
> 处置 legend：**行为化** = 沙箱夹具注入 + 行为观测（rc/stderr/stdout/产物文件）；**白名单** = 保留文本探针 + `# 行为断言` 注释（AC-9 机检白名单，实测保留 2 处）。
> verify 文本探针对账：32 处全部处置完毕，残留锚定行 0（白名单 2 行被 `grep -v '# 行为断言'` 排除）。

| # | 文件:行号（开工实文） | 处置 | 改法 / 保留理由 |
|---|---|---|---|
| 1 | test/test_l3_review_defects_2026_09.bats:80 | 白名单 | AC2 归因清单探针（文档属性，无行为面可观测）→ 保留 + 注释 |
| 2 | test/test_l3_review_defects_2026_09.bats:328 | 行为化 | B1-R17 基线：_l2v 直跑断 fail（L2 层结论） |
| 3 | test/test_l3_review_defects_2026_09.bats:330 | 行为化 | B1-R17 变异观测：覆盖 _l3_section_spans 后 L3 泄漏翻结论（读侧真消费段边界） |
| 4 | test/test_l3_review_defects_2026_09.bats:331 | 行为化 | B1-R17 strip 基线：_l3_strip_sections 真切段（L3 消失、L2 保留） |
| 5 | test/test_l3_review_defects_2026_09.bats:333 | 行为化 | B1-R17 strip 变异：空 spans 实现 → L3 段保留（写侧同源消费的因果自证） |
| 6 | test/test_l3_review_defects_2026_09.bats:957 | 行为化 | B5-R1：make -n 干跑观测配方真实接线（bash sync-hooks.sh / --check 变体） |
| 7 | test/test_l3_review_defects_2026_09.bats:980 | 行为化 | B5-R3：沙箱双跑 ~/.claude 部署树（stub 断言 BYTES=31337 导出链 + bypass 断言 skipped 凭证落盘） |
| 8 | test/test_l3_review_defects_2026_09.bats:1795 | 行为化 | B12-R3 变异自证：与 :1796 合并为 `! cmp -s real mut`（sed 只删匹配行 ⟺ diff=变异生效且生产真含该调用） |
| 9 | test/test_l3_review_defects_2026_09.bats:1796 | 行为化 | 同上（两行探针并一行 cmp 行为断言） |
| 10 | test/test_fix_l3_gate.bats:240 | 行为化 | _l3_parse_result 双跑：首写盲审标题（is_review=false 行为面） |
| 11 | test/test_fix_l3_gate.bats:243 | 行为化 | 重审轮：既有文件 → 重审标题 + L2 段保留 |
| 12 | test/test_fix_l3_gate.bats:247 | 行为化 | 追加语义：旧 L3 段被替换恒 1 段、不累积（awk 覆写形态断言退役） |
| 13 | test/test_fix_l3_gate.bats:253 | 行为化 | _l3_write_done fail → rc1 + .done 不落 + NOT written stderr；pass → rc0 + KVP 落盘 + written stderr |
| 14 | test/test_fix_l3_gate.bats:256 | 行为化 | 同上（条件消息两探针合并为一组行为观测） |
| 15 | test/test_fix_l3_gate.bats:261 | 行为化 | >50KB 夹具真跑 → stderr WARNING: review file exceeds 50KB（阈值行为面） |
| 16 | test/test_fix_l3_gate.bats:290 | 行为化 | _transition_apply 提取 0-change.md 过渡 jq 真跑：.phase/.goal.current_phase=1、门禁 passed |
| 17 | test/test_fix_l3_gate.bats:295 | 行为化 | 同法 1-requirement.md → 2 |
| 18 | test/test_fix_l3_gate.bats:300 | 行为化 | 同法 2-design.md → 3 |
| 19 | test/test_fix_l3_gate.bats:305 | 行为化 | 同法 3-task.md → 4 |
| 20 | test/test_fix_l3_gate.bats:310 | 行为化 | 同法 5-test.md → 6 |
| 21 | test/test_fix_l3_gate.bats:315 | 行为化 | 同法 6-review.md → 7 |
| 22 | test/test_fix_l3_gate.bats:320 | 行为化 | 同法 4-dev.md（$next_phase 注入 5）→ 5 |
| 23 | test/test_fix_l3_gate.bats:325 | 行为化 | 同法 pipeline-gates.md → 5 |
| 24 | test/test_l2_pretooluse_dispatch.bats:164 | 行为化 | AC-11 正常路径：写入成功 + 无 tmp 残留（原子性观测） |
| 25 | test/test_l2_pretooluse_dispatch.bats:165 | 行为化 | mv() 失败注入 → rc3 + CRITICAL atomic mv failed + 无半成品 |
| 26 | test/test_l2_pretooluse_dispatch.bats:167 | 行为化 | _l3_has_section 失败注入 → rc3 + CRITICAL not persisted |
| 27 | test/test_l2_pretooluse_dispatch.bats:169 | 行为化 | _l3_write_done 防御：有 L2 无 L3 → deferred rc3 + .done 不落 |
| 28 | test/test_dual_review_merge.bats:49 | 行为化 | both 无 L2 段直调 _l3_write_done → rc0 + .done 不落 + deferred (L2 not yet complete…) stderr |
| 29 | test/test_dual_review_merge.bats:54 | 行为化 | deferred 防御路径：有 L2 无 L3 → rc3 + .done deferred: L3 content not found |
| 30 | test/test_dual_review_merge.bats:247 | 行为化 | >> 追加语义：既有内容逐字保留 + L3 段追加其后（重审标题） |
| 31 | test/test_l3_lifecycle_wiring.bats:304 | 行为化 | E4 沙箱：stub l3_review_run 记录被调时可见导出值=42424（config_get→export 顺序的行为指纹） |
| 32 | test/test_l3_lifecycle_wiring.bats:306 | 行为化 | 同上（两行顺序探针合并为一组导出值断言） |

---

## 状态字段说明

- `status="pending|in_progress|done|blocked"`（同时只允许一个非 [P] 任务 in_progress；blocked 须记阻塞日志）

## model-tier 字段说明（ADR-016）

- `cheap` — 1-2 文件简单修改 · `standard` — 多文件标准 · `top` — 架构/复杂逻辑

---

## 阻塞日志

| 任务 | 阻塞原因 | 待人工决策项 | 时间 |
|---|---|---|---|
|  |  |  |  |

---

## Fix 任务（来自 REVIEW / INTEGRATION）

> 此区域由 review/integration 阶段自动追加，编号 `T-FIX-XX`。

```xml
<!-- 占位 -->
```
