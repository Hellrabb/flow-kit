# TASK: 收口 4 个 🔴 + 隐私前向门禁 + 假绿测试

- **Change ID**: `health-fix-2026-09b`
- **关联**: `@.specs/health-fix-2026-09b/REQUIREMENT.md`、`@.specs/health-fix-2026-09b/DESIGN.md`
- **生成**: 阶段 3（Planner）· 依据 `flow-kit-bundle/flow-kit/prompts/3-task.md`
- **强制承接清单来源**（漏一条即不合格）：
  - L2 盲审（第 7 轮）handoff 3 条：① R8 定级裁决落地 + ② ADR-022 `Superseded-by` 成 task + ③ `.change-base` 落档为 wave-1 task
  - L3 重审 #4（2026-09-23 00:42 · verdict=pass · 3 major）的 3 个 major 各自成 task：① pre-push 部署形态闭环、② 空基线自检、③ 常设清单自身校验
  - `MINOR-DEFERRED.md` **C5**（修订史移入附录；第 3 次被点名）：排在**本阶段定稿之后、编码任务之前** ⇒ 落 Wave 1 的 T01
- **边界声明**：本 change **不改** `check_gate_config_sync()` 的值比较（TD-033/034 留 v2，DESIGN D5）；**不碰** `flow-kit-bundle/hooks/stop/**`（仅 `stop/lib/l3-prompt.sh` 一个文件由 CHANGE §4b 用户裁决放行）、`flow-kit-bundle/brooks-lint/**`、`flow-kit-bundle/flow-kit/reference/pipeline-gates.md`、`flow-kit-bundle/skills/**`、`INDEPENDENT-REVIEW-1.md`。

---

## AC ↔ task 覆盖映射

| AC | 覆盖 task（done 层） | 判据要点 |
|---|---|---|
| **AC-1** PC1 eval RCE | T05（源树归零 + `~` 展开正例）、T25（6 副本面归零 + 哨兵未落盘）、T27（2 个分发归档归零） | `PAT='\$\([[:space:]]*eval[[:space:]]'` 三面全 0；哨兵文件不存在；`make check-hooks-sync` |
| **AC-2** PC2 缺 jq 不毁配置 | T06 | 影子 PATH 遮蔽 jq ⇒ rc≠0 且 `settings.json` 未截断、原 `permissions.allow` 存活 |
| **AC-3** P1 泄漏分支不可误推 | T11（hook 本体）、T12（`sync-hooks.sh` 四处登记）、T16（部署形态闭环 = ADR-022 symlink）、T19（四形态实跑拦截 + 干净 ref 放行） | 四种 push 形态被拒且理由可读；`develop` 不误拦 |
| **AC-4** 门禁看见内容漂移 | T08（比内容 + 覆盖度 `校验对 3/14` + 漂移指名 file:line）、T14（接入 `make check`）、T15（bats 断言 `-ne 2` → `-eq 0`） | 健康态 rc=0 **且**行数不变的漂移 rc≠0（差分锚点） |
| **AC-5** 内部项目名不再出厂 | T07（双源 4 文件中性化）、T24（重建 0.2.0 / 删除 0.1.0）、T27（三面 `chisel` = 0 + bats 不退化） | `test/`、`flow-kit-bundle/test/`、逐个 `.tgz` 三面均 0 |
| **AC-6** 前向脱敏有机器门禁 | T13（**工件脱敏先于基线冻结** = D10′①）、T17（门禁实现 + 排除表 + fail-closed 读序）、T18（`make check` 接线）、T20（pre-commit 源接线）、T21（**R8**：常设清单 + 副本 + 读序双态）、T22（**空基线自检**）、T23（**常设清单自身校验**）、T26（探针必须被抓住 + 自报↔落档 + 差分数） | 探针 fail 且指名路径；`清单外命中 0 条`；缺清单 ⇒ rc=1 且指名缺失路径 |
| **AC-7** 四处假绿不再假绿 | T09（`test_combined_metric.bats` 恒真、`test_auto_checkpoint.bats` 断言错对象）、T10（`test_independent_review_model.bats` 先断言文件存在、`test_lessons_cleanup.bats` 去过期 skip） | 逐条「注入失败源 ⇒ 必须变红」+ 健康态仍绿 |
| **AC-8** 无退化 | T28（NFR 兼容性判据落点 + `rc=3` 不得当绿灯）、T29（全量 `make check` / bats ≥1009 / 三门口禁 / 变更集非空守卫） | 0 not ok；三道副本一致性门禁 0 漂移 |

---

## 波次划分

```
Wave 1 (parallel · 定稿后置与锚点)          : T01[P], T02[P], T03[P], T04[P]
Wave 2 (parallel · 源修复层)                : T05[P], T06[P], T07[P], T08[P], T09[P], T10[P], T11[P], T12[P], T13[P]
Wave 3 (parallel · 判据收紧 / 部署 / 门禁实现): T14[P], T15[P], T16[P], T17[P]
Wave 4 (parallel · 门禁接线)                : T18[P]
Wave 5 (并行 2 + 串行 1 · 基线冻结与自校验) : T21[P], T22[P]；串行: T23（depends_on T21, T22；与 T22 同写 flow-kit-bundle/flow-kit/reference/check-path-privacy.sh ⇒ **必须等 T22 落定后才可开工，禁止与 T22 并行**）
Wave 6 (并行 4 + 串行 1 · 门禁接入与复制面) : T20[P], T25[P], T26[P], T28[P]；串行: T19（depends_on T11, T12, T16, T17, T18, T21, T22, T23, T26 —— 阶段 3 L3 M5 由 W4 移入：夹具复制的是**终稿**门禁脚本与**已冻结**清单，而脚本在 T22/T23 之后才定稿、清单在 T26 期间会被临时移走）
Wave 7 (串行 2 · 分发件重建与复扫)          : T24（depends_on T05, T07, T11, T12, T16, **T20, T25, T26**）→ T27（depends_on T24）
Wave 8 (收口 · 全量无退化)                  : T29
```

> - 同 wave = 可并行；跨 wave = 必须顺序执行。
> - **T01（C5 修订史移入附录）位于 Wave 1**：满足 `MINOR-DEFERRED.md` C5 的触发条件「阶段 3 定稿之后、4-dev 编码任务之前」——Wave 2 起全部为编码/改件任务，T01 先于它们。
> - **T13（工件脱敏）位于 Wave 2、且先于 T21（基线冻结）**：满足 DESIGN D10′①③ 的硬顺序「脱敏 → `git add` → 复扫非 0 即中止 → 冻结」；T17/T21 的排除表与清单均以其结果为准。
> - **T20 由 Wave 4 移到 Wave 6（主 agent 2026-09-23 订正 · 原排期自锁）**：本仓 `.git/hooks/pre-commit` 是 `~/.claude/hooks/pre-commit/pre-commit.sh` 的 symlink ⇒ T20 一经 `./sync-hooks.sh` 落地，本仓每次提交都会跑 `make check-path-privacy`；权威清单到 T21–T23 才冻结 ⇒ 门禁必红 ⇒ T20 **连自己的提交都过不去**（`--no-verify` 已禁）⇒ 必须排在 T21/T22/T23 之后。
> - **T24 由 Wave 5 移到 Wave 7（同一批订正）**：`check-dist` 逐文件比对 bundle 源与 `dist/` ⇒ 重建必须是**最后一个改动源面的步骤**（T20/T25/T26 之后），否则 T29 的 `make check` 仍红。
> - **T19 依赖 T11+T12+T16**：拦截器本体、副本登记、部署形态三者齐备后四形态实跑才成立（AC-3 的 Given「拦截由 pre-push 承担」）。
> - **T24（重建分发件）依赖 T05/T07/T11/T12/T16**：归档内容 = 源树快照，源未修完则重建等于把缺陷重新打包。

---

## 任务清单

```xml
<task id="T01" parallel="true" status="done" model-tier="standard">
  <name>C5：DESIGN.md 修订史整体移入「附：修订史」，决策区去过程记录</name>
  <read_files>
    <参考边界 · 只读>
    <`.specs/health-fix-2026-09b/DESIGN.md`（全文 · 判定哪些行是过程记录）>
    <`.specs/health-fix-2026-09b/MINOR-DEFERRED.md`（C5 行 = 触发条件原文）>
    <`.specs/health-fix-2026-09b/REQUIREMENT.md`（§已知未闭环项 与 NFR · 判据文本不得被搬家误删）>
  </read_files>
  <write_files>
    <修改边界>
    <`.specs/health-fix-2026-09b/DESIGN.md`>
  </write_files>
  <action>
    把 §0–§9 正文中的**过程记录**（「初版…」「第 N 轮修正/订正/补/再订正」「R6-1 指出」「L2 N1 证伪」等自述性叙述）
    整体移入文末新增小节 `## 附：修订史`（按轮次组织：L2 第 1~7 轮 / L3 重审 #1~#4，标注每条的来源与处置）。
    决策行只保留**最终口径**：决策 / 备选 / 选择理由 / 取舍代价 / 判据。
    **仅搬家，不得删除**：所有实测数字、复现命令、判据文本必须原样保留（在决策行或附录中），
    不得改动 D1–D10′ 的最终决议与 §3 退出码模型、§9 契约。
  </action>
  <verify>
    export LC_ALL=C; D=.specs/health-fix-2026-09b/DESIGN.md;
    grep -q '^## 附：修订史' "$D" || { echo "🔴 缺「附：修订史」小节"; exit 1; };
    n=$(sed -n '1,/^## 附：修订史/p' "$D" | grep -cE '（第 [0-9]+ 轮|初版）');
    [ "$n" -eq 0 ] || { echo "🔴 决策区仍有 $n 处过程记录"; exit 1; };
    [ "$(sed -n '/^## 附：修订史/,$p' "$D" | wc -l)" -gt 5 ] || { echo "🔴 附录为空（疑似删除而非搬家）"; exit 1; }
  </verify>
  <done>DESIGN 决策区过程记录 grep 计数 = 0 且附录非空 —— 满足 MINOR-DEFERRED C5 的触发条件（AC-6 可读性前置，非 AC 本身）</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true" status="done" model-tier="cheap">
  <name>`.change-base` 变更起点锚点落档（4-dev 首步 + 入库）</name>
  <read_files>
    <`.specs/health-fix-2026-09b/DESIGN.md`（§9.2 锚点渠道优先级；R1 风险列「落地顺序」）>
    <`.specs/health-fix-2026-09b/REQUIREMENT.md`（NFR 兼容性判据全文；AC-8 的 BASE8 守卫）>
    <`Makefile`（确认 `check:` 现状，锚点用于新增的 check-nfr-portability）>
  </read_files>
  <write_files>
    <`.specs/health-fix-2026-09b/.change-base`（新增产物）>
  </write_files>
  <action>
    **在任何修改之前**执行 `git rev-parse HEAD`，把 40 位 SHA 单行写入 `.specs/health-fix-2026-09b/.change-base`（无尾随文本、无注释），
    并 `git add .specs/health-fix-2026-09b/.change-base` 入库。
    渠道优先级按 DESIGN §9.2：`FLOW_KIT_CHANGE_BASE` 环境变量 > 本文件 > fail-closed。
    **不得**用裸 `HEAD` 充当锚点（提交后 `git diff HEAD` 恒空 ⇒ 判据静默空转）。
  </action>
  <verify>
    B=.specs/health-fix-2026-09b/.change-base;
    test -s "$B" || { echo "🔴 锚点文件缺失或为空"; exit 1; };
    git cat-file -e "$(cat "$B")^{commit}" 2>/dev/null || { echo "🔴 锚点不是有效 commit: $(cat "$B")"; exit 1; };
    git ls-files --error-unmatch "$B" >/dev/null 2>&1 || { echo "🔴 锚点未入库（未 git add）"; exit 1; }
  </verify>
  <done>`.change-base` 落档且指向有效 commit、已入库 —— AC-8 / NFR 兼容性判据的锚点前提（修复前实测：文件不存在 ⇒ rc=1）</done>
  <depends_on></depends_on>
</task>

<task id="T03" parallel="true" status="done" model-tier="cheap">
  <name>ADR-022 追加 `Superseded-by`（部分：新增 pre-push 注入）</name>
  <read_files>
    <`.specs/adr/022-git-hook-deployment.md`（全文 · 保留原决策正文）>
    <`.specs/health-fix-2026-09b/DESIGN.md`（D3 item 3 = 声明口径与代价）>
    <`.specs/health-fix-2026-09b/REQUIREMENT.md`（AC-3 的 R5 订正段：初版禁令与 ADR-022 冲突已纠正）>
  </read_files>
  <write_files>
    <`.specs/adr/022-git-hook-deployment.md`（R8 第 7 轮 L2 补列入 §0.5.1 触碰模块）>
  </write_files>
  <action>
    在 ADR-022 末尾**追加**一条 `Superseded-by`，标注为 **部分** supersede（新增 `pre-push` 注入）：
    ① 理由 = AC-3 要求推送拦截；② 范围 = 仅扩展"注入面"，symlink 载体与幂等语义**不变**；
    ③ 代价 = 必然触碰 `.git/hooks/` 下用户既有 hook ⇒ 备份 + 安装输出告知备份路径，用户可回滚。
    **不得**删除、改写或重排 ADR-022 原有决策正文（只追加）。
  </action>
  <verify>
    A=.specs/adr/022-git-hook-deployment.md;
    grep -qE 'Superseded-by' "$A" || { echo "🔴 未追加 Superseded-by"; exit 1; };
    grep -q 'pre-push' "$A" || { echo "🔴 未限定部分 supersede 的范围（pre-push）"; exit 1; };
    grep -qi 'symlink' "$A" || { echo "🔴 原决策正文疑似被改动（symlink 载体句丢失）"; exit 1; }
  </verify>
  <done>ADR-022 追加 `Superseded-by`（部分：pre-push 注入）且原决策正文完好 —— 满足 L2 第 7 轮 handoff ②（修复前实测：`Superseded-by` 命中 0）</done>
  <depends_on></depends_on>
</task>

<task id="T04" parallel="true" status="done" model-tier="standard">
  <name>TD-043 收口：L3 提示词信封的 ADR 纳入策略双态验证（含 ADR-028、不含 ADR-011 正文）</name>
  <read_files>
    <`flow-kit-bundle/hooks/stop/lib/l3-prompt.sh`（ADR 纳入段与预算/标记实现）>
    <`flow-kit-bundle/hooks/stop/lib/l3-review.sh`（:117 / :140 调用方 · 三参形态）>
    <`.specs/health-fix-2026-09b/CHANGE.md`（### 4b. 范围追加 · 用户裁决原文）>
    <`.specs/health-fix-2026-09b/DESIGN.md`（§0.5.1 该行 verify = 本 task 的判据来源）>
    <`.specs/adr/`（028 存在性；011/015/019 为对照）>
  </read_files>
  <write_files>
    <`flow-kit-bundle/hooks/stop/lib/l3-prompt.sh`（仅当双态 verify 不成立时补齐；已落地的策略不得改回 `head -3`）>
  </write_files>
  <action>
    确认 phase 2 的 ADR 纳入 = **按工件引用频次**（`grep -oE 'ADR-0[0-9]{2}'`）+ **逐份预算 5000 B / 总量 18000 B** + **截断与未纳入均落显式标记**
    （源码已含 TD-043 修复，注释标注 `ADR 纳入策略（TD-043 修复 · health-fix-2026-09b · 2026-09-23）`）。
    若双态 verify 不成立则补齐；**不得**改成 `find "$adr_dir" | head -3` 形态（目录序、与本 change 无关）。
    调用形态：`_l3_build_prompt <phase> <artifacts_dir> <max_bytes>`（**三参**，缺 `max_bytes` 会退化为 0 B 截断）。
    自我指涉披露按 CHANGE §4b：改动只减少提示词噪声、不放宽任何判据。
  </action>
  <verify>
    export LC_ALL=C; P='--- .specs/adr/';
    out=$(bash -c 'source flow-kit-bundle/hooks/stop/lib/l3-prompt.sh 2>/dev/null; _l3_build_prompt 2 .specs/health-fix-2026-09b 200000' 2>/dev/null);
    [ -n "$out" ] || { echo "🔴 提示词为空（调用形态/预算错误）"; exit 1; };
    printf '%s' "$out" | grep -q "^${P}028-gate-baseline-allowlist\.md ---" || { echo "🔴 本 change 引用的 ADR-028 未按正文纳入"; exit 1; };
    if printf '%s' "$out" | grep -q "^${P}011-"; then echo "🔴 无关 ADR-011 仍被纳入正文"; exit 1; fi;
    printf '%s' "$out" | grep -qE '预算|未纳入' || { echo "🔴 缺截断/未纳入显式标记"; exit 1; }
  </verify>
  <done>phase 2 提示词含 ADR-028 正文标记、不含 ADR-011 正文标记、含预算/未纳入标记 —— TD-043 由「缺陷登记」转「已修」（实测基线：49468 B；ADR 正文标记命中 022/028/027/005/008）</done>
  <depends_on></depends_on>
</task>

<task id="T05" parallel="true" status="done" model-tier="standard">
  <name>PC1：移除 `runtime-edit-guard.sh` 的 eval 载荷求值（纯参数展开 + 绝对值校验）</name>
  <read_files>
    <`flow-kit-bundle/hooks/pre-tool-use/runtime-edit-guard.sh`（全文 · 103L；:46 为目标行）>
    <`.specs/health-fix-2026-09b/DESIGN.md`（§1 D6 七态 fixture + §2.2 求值路径 + §0.5.2「`~` 展开新建内联」）>
    <`.specs/health-fix-2026-09b/REQUIREMENT.md`（AC-1 全段含正例判据与「为何不能用 `\beval\b`」）>
    <`flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh`（:32-37 fail-close 守卫范式）>
  </read_files>
  <write_files>
    <`flow-kit-bundle/hooks/pre-tool-use/runtime-edit-guard.sh`>
  </write_files>
  <action>
    以**纯参数展开**替换 `eval echo "$file_path"`：`~` 整体 ⇒ `$HOME`；`~/` 前缀 ⇒ `$HOME/` + 余部；其余不展开。
    展开后**绝对值校验**：结果必须以 `/` 开头，否则 `exit 2`（**不是**「以 `$HOME/` 开头」——那会误拒 `/tmp/x`）。
    `~user` 形态**一律拒绝**（`exit 2`，D6 显式声明的行为收缩，不引入 `getent`/passwd 查询）。
    不引入 `realpath` / `readlink -f` / 外部进程；保持 deny 文案含 `你正在编辑: <展开后路径>`。
    **沿用**既有 `jq` 取 `tool_input.file_path` 的读入方式（不新建 helper）。
  </action>
  <verify>
    export LC_ALL=C; G=flow-kit-bundle/hooks/pre-tool-use/runtime-edit-guard.sh;
    n=$(grep -rEn '\$\([[:space:]]*eval[[:space:]]' flow-kit-bundle/ | wc -l);
    [ "$n" -eq 0 ] || { echo "🔴 源树仍有 eval-echo=$n"; exit 1; };
    bash -n "$G" || exit 1;
    p(){ printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$1" | bash "$G" >/dev/null 2>&1; echo $?; };
    [ "$(p '~alice/x.sh')" -eq 2 ] || { echo "🔴 ~user 未拒绝"; exit 1; };
    [ "$(p 'rel/x.sh')" -eq 2 ]   || { echo "🔴 相对路径未拒绝"; exit 1; };
    [ "$(p '')" -eq 2 ]           || { echo "🔴 空串未拒绝"; exit 1; };
    [ "$(p '/tmp/x.sh')" -eq 0 ]  || { echo "🔴 合法绝对路径被误拒"; exit 1; };
    out=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"~/.claude/hooks/pre-tool-use/runtime-edit-guard.sh"}}' | bash "$G" 2>&1); rc=$?;
    [ "$rc" -eq 2 ] || { echo "🔴 正例 rc=$rc ≠ 2"; exit 1; };
    printf '%s' "$out" | grep -qE '你正在编辑: /' || { echo "🔴 ~ 展开未被证明"; exit 1; }
  </verify>
  <done>AC-1②③：源树 eval-echo=0、`~`/`~/` 展开仍生效（rc=2 + 可观测）、`~user`/相对/空路径被拒、合法绝对路径不误拒（修复前实测：源树 1 处 + 正例 rc=2/443B）</done>
  <depends_on></depends_on>
</task>

<task id="T06" parallel="true" status="done" model-tier="standard">
  <name>PC2：缺 jq 时 fail-closed 且不破坏既有 `settings.json`（入口校验 + 分支订正 + 原子写）</name>
  <read_files>
    <`flow-kit-bundle/lib/install_hooks.sh`（全文 · 303L；:41 deploy_pre_commit / :69 install_hooks / :153 调用点 / :211 条件 / :251 截断行）>
    <`flow-kit-bundle/install.sh`（调用链 · 只读；本 change 不改它）>
    <`.specs/health-fix-2026-09b/DESIGN.md`（§1 D7 + §2.3 分支路径 + §5 R4 trap 约束）>
    <`.specs/health-fix-2026-09b/REQUIREMENT.md`（AC-2 全段 + L-122「判据必须真正触达缺陷现场」）>
    <`.specs/CONTEXT.md`（禁动清单：`install_*.sh` 不允许外部直接 source）>
  </read_files>
  <write_files>
    <`flow-kit-bundle/lib/install_hooks.sh`>
  </write_files>
  <action>
    ① `install_hooks()` **入口**加 `command -v jq` 硬校验（缺失 ⇒ 立即非零退出，且**在任何写盘之前**）—— 目标使 `command -v jq` 命中 ≥2（入口 + `:211` 分支）；
    ② 订正 `:211` 的二值条件：「文件已存在 + jq 缺失」**不得**落 `:238 else`（注释 `# 新建`）分支；
    ③ 落盘改 `mktemp` + `mv` 原子写，并加 `trap 'rm -f "$tmp"' EXIT` 清理（DESIGN R4）；
    保持 `install_hooks.sh` 只由 `install.sh` source（CONTEXT 禁动清单），不新增外部 source 点。
  </action>
  <verify>
    SBX=$(mktemp -d /tmp/l2-ac2-XXXXXX); mkdir -p "$SBX/home/.claude";
    printf '{"permissions":{"allow":["Bash(ls:*)"]},"hooks":{"Stop":[{"matcher":"","hooks":[{"type":"command","command":"true"}]}]}}' > "$SBX/home/.claude/settings.json";
    cp "$SBX/home/.claude/settings.json" "$SBX/orig.json";   # 原样副本：入口级 jq 校验在任何写盘之前 ⇒ 文件应**一字不动**（阶段 3 L3 m1）
    mkdir -p "$SBX/shadow"; IFS=':' read -ra __D <<< "$PATH";
    for d in "${__D[@]}"; do [ -d "$d" ] || continue;
      for f in "$d"/*; do [ -e "$f" ] || continue;
        b=$(basename "$f"); [ "$b" = "jq" ] && continue;
        [ -e "$SBX/shadow/$b" ] || ln -s "$f" "$SBX/shadow/$b" 2>/dev/null || true;
      done;
    done;
    PATH="$SBX/shadow" command -v jq >/dev/null 2>&1 && { echo "🔴 前提未满足：jq 仍可见"; exit 1; };
    PATH="$SBX/shadow" command -v mkdir >/dev/null 2>&1 || { echo "🔴 影子环境缺基础工具"; exit 1; };
    rc=0; HOME="$SBX/home" PATH="$SBX/shadow" bash flow-kit-bundle/install.sh --global --no-brooks --user >"$SBX/out" 2>&1 || rc=$?;
    [ "$rc" -ne 0 ] || { echo "🔴 缺 jq 时未非零退出（静默失败）"; exit 1; };
    SET="$SBX/home/.claude/settings.json"; sz=$(wc -c < "$SET");
    [ "$sz" -gt 0 ] || { echo "🔴 settings.json 被截断为空"; exit 1; };
    cmp -s "$SET" "$SBX/orig.json" || { echo "🔴 缺 jq 时 settings.json 被改写（入口级校验应在任何写盘之前 ⇒ 应逐字节相同）"; exit 1; };
    jq -e '.permissions.allow | index("Bash(ls:*)")' "$SET" >/dev/null || { echo "🔴 原 permissions.allow 丢失"; exit 1; };
    jq -e '.hooks.Stop[0].hooks[0].command == "true"' "$SET" >/dev/null || { echo "🔴 原 hooks 字段被破坏（阶段 3 L3 m1：原判据只覆盖 permissions）"; exit 1; };
    [ "$(jq -c 'keys' "$SET")" = '["hooks","permissions"]' ] || { echo "🔴 顶层字段集合变化（应保持 hooks+permissions）"; exit 1; };
    [ "$(grep -c 'command -v jq' flow-kit-bundle/lib/install_hooks.sh)" -ge 2 ] || { echo "🔴 缺入口级 jq 校验"; exit 1; };
    [ "$(grep -c mktemp flow-kit-bundle/lib/install_hooks.sh)" -ge 1 ] || { echo "🔴 未改原子写"; exit 1; }
  </verify>
  <done>AC-2：缺 jq 时非零退出、`settings.json` 未被截断为空、原 `permissions.allow` 与 `hooks.Stop` 均存活、顶层字段集合不变、且文件**逐字节未变**（`cmp`，入口级校验先于任何写盘）（修复前实测：rc=127 且 122B→0B；`--global --no-brooks --user` 是唯一能触达 `:251` 的 flag 组合）</done>
  <depends_on></depends_on>
</task>

<task id="T07" parallel="true" status="done" model-tier="cheap">
  <name>AC-5：`chisel-*` 中性化（双源 4 文件）+ 断言解耦</name>
  <read_files>
    <`test/test_correction_hygiene.bats`（chisel ×5）>
    <`test/test_l3_review_defects_2026_09.bats`（chisel ×1）>
    <`flow-kit-bundle/test/test_correction_hygiene.bats`（镜像）>
    <`flow-kit-bundle/test/test_l3_review_defects_2026_09.bats`（镜像）>
    <`.specs/health-fix-2026-09b/REQUIREMENT.md`（AC-5 全段 + 假设 3「替换前先枚举全部消费方」）>
    <`.specs/health-fix-2026-09b/DESIGN.md`（§1 D9）>
  </read_files>
  <write_files>
    <`test/test_correction_hygiene.bats`>
    <`test/test_l3_review_defects_2026_09.bats`>
    <`flow-kit-bundle/test/test_correction_hygiene.bats`>
    <`flow-kit-bundle/test/test_l3_review_defects_2026_09.bats`>
  </write_files>
  <action>
    先 `grep -rn chisel test/ flow-kit-bundle/test/` 枚举**全部消费方**（假设 3 待验证：替换是否与其它期望字符串耦合），
    再把 `chisel-*` 换成与断言解耦的中性占位（如 `sample-proj-*`），**双源逐字同步**（`Makefile:79 check-test-sync` 在 `check:` 内，漏改一份即漂移）。
    **不得**删除测试或用宽松断言规避（out 段锁定）。
  </action>
  <verify>
    hits=$(grep -rn chisel test/ flow-kit-bundle/test/ 2>/dev/null || true);
    [ -z "$hits" ] || { printf '%s\n' "$hits" | head -10; echo "🔴 源测试仍含 chisel（命中如上，file:line —— 阶段 3 L3 m11：原写法只报一句、不给定位）"; exit 1; };
    cmp -s test/test_correction_hygiene.bats flow-kit-bundle/test/test_correction_hygiene.bats || { echo "🔴 双源不一致"; exit 1; };
    cmp -s test/test_l3_review_defects_2026_09.bats flow-kit-bundle/test/test_l3_review_defects_2026_09.bats || { echo "🔴 双源不一致"; exit 1; };
    outf=$(mktemp); npx bats test/test_correction_hygiene.bats test/test_l3_review_defects_2026_09.bats --formatter tap > "$outf" 2>&1; b_rc=$?;
    b_ok=$(grep -cE '^ok [0-9]+' "$outf"); b_no=$(grep -cE '^not ok [0-9]+' "$outf");
    echo "bats(两文件): rc=$b_rc ok=$b_ok not-ok=$b_no（基线 2026-09-23 实测 rc=0 / 134 ok / 0 not ok）";
    grep -E '^not ok [0-9]+' "$outf" | head -5; rm -f "$outf";
    { [ "$b_rc" -eq 0 ] && [ "$b_no" -eq 0 ] && [ "$b_ok" -ge 134 ]; } || { echo "🔴 bats 回归或删测试（rc=$b_rc not-ok=$b_no ok=$b_ok，基线 134）"; exit 1; }
  </verify>
  <done>AC-5 源侧：双源 4 文件 `chisel` 归零、两 bats 仍全绿且**用例数不下降**（TAP 断言 `^not ok` 计数 = 0 且 `^ok` 计数 ≥ 134 且 rc=0 —— 基线 2026-09-23 实测 134 ok / 0 not ok，判据来自阶段 3 L3 m2「只跑不计数 ⇒ 删测试仍绿」）（修复前实测：correction_hygiene=5 / l3_review_defects=1，双源共 4 文件）</done>
  <depends_on></depends_on>
</task>

<task id="T08" parallel="true" status="done" model-tier="top">
  <name>AC-4：`check-gate-sync.sh` 由比行数改为比内容 + 打印覆盖度 `校验对 3/14`</name>
  <read_files>
    <`flow-kit-bundle/flow-kit/reference/check-gate-sync.sh`（全文 · 159L；:16/:39/:43 现行计数判据；:85-107 check_gate_config_sync；:138 校验对定义；:157 汇总行）>
    <`flow-kit-bundle/flow-kit/prompts/A-evolve.md`、`I-intel-scan.md`、`L-restyle.md`>
    <`flow-kit-bundle/skills/flow-evolve/SKILL.md`、`flow-intel/SKILL.md`、`flow-restyle/SKILL.md`>
    <`flow-kit-bundle/flow-kit/reference/phase-prompt-template.md`（:143-145 · PCSC 属「结构性文档化（不抽取）」的证据）>
    <`.specs/health-fix-2026-09b/REQUIREMENT.md`（AC-4 全段 + 假设 4 更正后立场）>
    <`.specs/health-fix-2026-09b/DESIGN.md`（§1 D2 + §1 D5 边界声明）>
  </read_files>
  <write_files>
    <`flow-kit-bundle/flow-kit/reference/check-gate-sync.sh`>
  </write_files>
  <action>
    比较对收敛为 **3 对**（`A-evolve`↔`flow-evolve`、`I-intel-scan`↔`flow-intel`、`L-restyle`↔`flow-restyle`；
    实测 `diff` 恒为 **6 行** = SKILL 独有 front-matter），判据改为**比内容**（仅允许平台 front-matter 差异，其余逐行/逐内容成分比对）。
    **明确排除** PCSC 表（`phase-prompt-template.md:144` 属结构性文档化）与 hooks 镜像面（已有 `check-hooks-sync`，重复覆盖）。
    输出必须打印覆盖度 **`校验对 3/14`**（防 `:157` 的「✅ 所有校验对一致」被读成 14 对全绿）；漂移报文必须含 `文件:行号`。
    **边界（DESIGN D5 · 必须写进注释）**：本 task 只改 PCSC 判据，**不碰** 同文件 `check_gate_config_sync()` 的值比较（TD-033/034 属 v2）。
  </action>
  <verify>
    S=flow-kit-bundle/flow-kit/reference/check-gate-sync.sh;
    bash "$S" || { echo "🔴 健康态门禁未通过"; exit 1; };
    bash "$S" | grep -q '校验对 3/14' || { echo "🔴 未打印覆盖度 3/14"; exit 1; };
    F=flow-kit-bundle/flow-kit/prompts/A-evolve.md; cp "$F" /tmp/gs-bak;
    trap 'cp -f /tmp/gs-bak "$F" 2>/dev/null' EXIT;   # m12：中途被 kill 也不得留下漂移
    sed '1s/$/ /' /tmp/gs-bak > "$F";
    out=$(bash "$S"); rc=$?; cp /tmp/gs-bak "$F";
    cmp -s "$F" /tmp/gs-bak || { echo "🔴 漂移夹具未按备份逐字节恢复（tracked 文件残留 ⇒ 后续 task 全红 · 阶段 3 L3 m12）"; exit 1; };
    [ "$rc" -ne 0 ] || { echo "🔴 行数不变的内容漂移未报红"; exit 1; };
    printf '%s' "$out" | grep -qE '(prompts|skills)/[^ :]+:[0-9]+' || { echo "🔴 报红未指名「文件:行号」"; exit 1; }
  </verify>
  <done>AC-4②：健康态 rc=0（差分锚点）且行数不变的内容漂移 rc≠0 并指名 `文件:行号`；覆盖度 3/14 已打印（修复前实测：rc=1 永久红、`grep -c "^| [0-9] |"` 口径 352 vs 549）</done>
  <depends_on></depends_on>
</task>

<task id="T09" parallel="true" status="done" model-tier="standard">
  <name>AC-7(a)：`test_combined_metric.bats` 恒真断言 + `test_auto_checkpoint.bats` 断言对象订正</name>
  <read_files>
    <`test/test_combined_metric.bats`（:31-32 恒真式 `[ "$status" -eq 0 ] || [ "$status" -eq 2 ]`）>
    <`test/test_auto_checkpoint.bats`（:208 / :221 `[[ "$?" -eq 0 ]]` 断言 jq 的 `$?`）>
    <`flow-kit-bundle/test/` 两份同名镜像>
    <`.specs/health-fix-2026-09b/REQUIREMENT.md`（AC-7 Then 前两条 + 「验证方式 = 注入失败源 ⇒ 必须变红」）>
    <`.specs/health-fix-2026-09b/DESIGN.md`（§5 R2 判据纪律 L-119~L-122）>
  </read_files>
  <write_files>
    <`test/test_combined_metric.bats`>
    <`test/test_auto_checkpoint.bats`>
    <`flow-kit-bundle/test/test_combined_metric.bats`>
    <`flow-kit-bundle/test/test_auto_checkpoint.bats`>
    <仓库外临时沙箱（`td2=$(mktemp -d)`）：注入夹具 `$td2/tmp.zz-inject` 的创建与清理；**不入库**，写面仅限该沙箱（阶段 3 L3 major①）>
  </write_files>
  <action>
    ① `test_combined_metric.bats`：消除「除 1 外一切结果」型恒真断言 —— 断言面收敛到 SUT 自有/可控临时区：
    **扫描根 = `${TMPDIR:-/tmp}` 的单层 `tmp.*`，且必须排除用例自身的 `$TEST_TMPDIR`**（形态：
    `run bash -c 'ls -d "${TMPDIR:-/tmp}"/tmp.* 2>/dev/null | grep -vF "$TEST_TMPDIR"'`，断言改为 `[ "$status" -ne 0 ]`
    —— 无残留 ⇒ grep 无命中 ⇒ 非零 ⇒ 绿；有残留 ⇒ 零 ⇒ 红）；**禁用**裸 `/tmp/tmp.*` 全目录匹配
    （本机实测 `/tmp/tmp.*` 现存 144 个无关文件，按原口径收紧会在健康态假红）。
    **扫描根与 verify 的注入点必须同一（`TMPDIR`）**：注入的是 `$td2/tmp.zz-inject`（单层 `tmp.*`），
    健康态/注入态共用同一 `TMPDIR` ⇒ 两态仅差一个残留文件，红/绿差异不可归因于环境差异（阶段 3 L3 C1）；
    ② `test_auto_checkpoint.bats:208,:221`：把断言对象从 `jq` 的 `$?` 改为 **SUT**（经 `run` + `$status`，或断言 SUT 产物内容）。
    双源逐字同步；不得用 `skip` 或放宽断言达成绿灯。
    ③ **夹具协议（阶段 3 L3 major①）**：注入/清理只发生在**仓库外沙箱** `$td2`（`mktemp -d`，以 `TMPDIR="$td2"` 驱动 bats）内；用例结束后 `rm -rf "$TD" "$td2"` 清理，**不得**在仓库内留下任何注入残留；沙箱不入库、不属于入库写面。
  </action>
  <verify>
    npx bats test/test_combined_metric.bats >/tmp/t09-health.out 2>&1 || { cat /tmp/t09-health.out; echo "🔴 健康态应绿"; exit 1; };
    # 主 agent 2026-09-23 修正（原判据按 T09 修复前形态书写，与 fix loop 第 1 轮实现不一致 ⇒ 假红，且注入点不可达）：
    # 扫描面已从环境 $TMPDIR 收敛到用例自建根 $TEST_TMPDIR（SUT :30-43）⇒ 断言扫描根形态，注入点改为 SUT 自身。
    grep -qE '\$TEST_TMPDIR' test/test_combined_metric.bats || { echo "🔴 SUT 未以用例自建根（\$TEST_TMPDIR）为扫描根 ⇒ 未与 /tmp 环境解耦（L-122）"; exit 1; };
    grep -qE 'ls /tmp/tmp\.\*' test/test_combined_metric.bats && { echo "🔴 SUT 仍在匹配裸 /tmp 全目录（环境相关恒红）"; exit 1; };
    # 判别力注入①（L-122/L-132：注入点须与被测面同源，且先自证注入生效）：撑过 20000 字节阈值 ⇒ 第 1 用例必须 not ok
    P4=flow-kit-bundle/flow-kit/prompts/4-dev.md;
    cp "$P4" /tmp/t09-4dev.bak;
    cat "$P4" "$P4" > /tmp/t09-4dev.pad && cp -f /tmp/t09-4dev.pad "$P4";
    _sz=$(wc -c < "$P4"); [ "$_sz" -gt 20000 ] || { cp -f /tmp/t09-4dev.bak "$P4"; echo "🔴 注入未生效（$P4 仅 ${_sz} 字节）"; exit 1; };
    npx bats test/test_combined_metric.bats >/tmp/t09-inj1.out 2>&1 && { cp -f /tmp/t09-4dev.bak "$P4"; cat /tmp/t09-inj1.out; echo "🔴 撑过阈值后仍绿（阈值断言恒真）"; exit 1; };
    grep -q 'not ok 1' /tmp/t09-inj1.out || { cp -f /tmp/t09-4dev.bak "$P4"; cat /tmp/t09-inj1.out; echo "🔴 变红但非第 1 用例（注入未触达阈值断言）"; exit 1; };
    cp -f /tmp/t09-4dev.bak "$P4";
    cmp -s "$P4" /tmp/t09-4dev.bak || { echo "🔴 4-dev.md 未逐字节复原"; exit 1; };
    # 判别力注入②：把 SUT 自身的清理行 sed 成 : ⇒ 残留检测（第 2 用例）必须 not ok
    SUT=test/test_combined_metric.bats;
    cp "$SUT" /tmp/t09-sut.bak;
    sed -i 's|^  rm -f "\$t"$|  :|' "$SUT";
    grep -qE '^  :$' "$SUT" || { cp -f /tmp/t09-sut.bak "$SUT"; echo "🔴 注入未生效（SUT 清理行形态已变 ⇒ 判据需同步）"; exit 1; };
    npx bats test/test_combined_metric.bats >/tmp/t09-inj2.out 2>&1 && { cp -f /tmp/t09-sut.bak "$SUT"; cat /tmp/t09-inj2.out; echo "🔴 清理被移除后残留断言仍绿（无判别力）"; exit 1; };
    grep -q 'not ok 2' /tmp/t09-inj2.out || { cp -f /tmp/t09-sut.bak "$SUT"; cat /tmp/t09-inj2.out; echo "🔴 变红但非第 2 用例（残留检测未被触发）"; exit 1; };
    cp -f /tmp/t09-sut.bak "$SUT";
    cmp -s "$SUT" /tmp/t09-sut.bak || { echo "🔴 SUT 未逐字节复原"; exit 1; };
    grep -qE '\[ "\$status" -eq 0 \] \|\| \[ "\$status" -eq 2 \]' test/test_combined_metric.bats && { echo "🔴 恒真断言仍在"; exit 1; };
    npx bats test/test_auto_checkpoint.bats || { echo "🔴 auto_checkpoint 健康态应绿"; exit 1; };
    grep -nE '^\s*\[\[ "\$\?" -eq 0 \]\]' test/test_auto_checkpoint.bats && { echo "🔴 仍在对 jq 的 \$? 断言"; exit 1; };
    cmp -s test/test_auto_checkpoint.bats flow-kit-bundle/test/test_auto_checkpoint.bats || { echo "🔴 双源不一致"; exit 1; }
  </verify>
  <done>AC-7：`test_combined_metric.bats` 不再接受「除 1 外一切结果」（注入残留必红、健康态必绿）、`test_auto_checkpoint.bats` 断言对象为 SUT 而非 jq</done>
  <depends_on></depends_on>
</task>

<task id="T10" parallel="true" status="done" model-tier="standard">
  <name>AC-7(b)：`test_independent_review_model.bats` 先断言文件存在 + `test_lessons_cleanup.bats` 去过期 skip</name>
  <read_files>
    <`test/test_independent_review_model.bats`（:81-89 / :136-141 反向断言，缺「先断言文件存在」）>
    <`test/test_lessons_cleanup.bats`（AC-4 测试名 `AC-4: 模拟全量覆盖场景下 --validate exit = 0`，含 `skip`）>
    <`flow-kit-bundle/test/` 两份同名镜像>
    <`package-flow-kit.sh`（只读 · `--validate` 的 SUT；**T10 自身不得修改**。注：该文件在 **T11 修复轮 2** 依 **TD-048 用户裁决**被写入（Part C 补 `pre-push` stanza，`:134-136`）——授权与归属见下方「write_files 边界归属 → 显式例外」表；L2 阶段 5 R8 已订正本行）>
    <`.specs/health-fix-2026-09b/REQUIREMENT.md`（AC-7 Then 后两条 + R8 gap 现状澄清：`--validate` 干净态 exit=0）>
    <`.specs/health-fix-2026-09b/MINOR-DEFERRED.md`（C5 之外的 deferred 边界）>
  </read_files>
  <write_files>
    <`test/test_independent_review_model.bats`>
    <`test/test_lessons_cleanup.bats`>
    <`flow-kit-bundle/test/test_independent_review_model.bats`>
    <`flow-kit-bundle/test/test_lessons_cleanup.bats`>
  </write_files>
  <action>
    ① `test_independent_review_model.bats:81-89,:136-141`：在反向 grep 断言**之前**显式断言被检文件存在
    （`[ -f "$HOME/.claude/hooks/stop/29-independent-review.sh" ]` 等），消除「文件缺失 ⇒ 断言恒真」；
    ② `test_lessons_cleanup.bats` 的 **AC-4 那条测试**（**按测试名引用，不引行号**，抗行号漂移）**移除 skip 并断言 `exit 0`**，
    收敛为唯一可机器验证分支（实测 `bash package-flow-kit.sh --validate` 干净态 exit=0 ⇒ 原 skip 属「过期 skip」）。
    双源逐字同步。
  </action>
  <verify>
    F="$HOME/.claude/hooks/stop/29-independent-review.sh";
    [ -f "$F" ] || { echo "🔴 前提：被检文件不存在，判据不可用"; exit 1; };
    mv "$F" "$F.zz-bak";
    out=$(npx bats test/test_independent_review_model.bats 2>&1); rc=$?;
    mv "$F.zz-bak" "$F";
    [ "$rc" -ne 0 ] || { echo "🔴 删除被检文件后仍绿（未先断言文件存在）"; exit 1; };
    npx bats test/test_independent_review_model.bats || { echo "🔴 健康态应绿"; exit 1; };
    sed -n '/AC-4: 模拟全量覆盖场景下 --validate exit = 0/,/^}/p' test/test_lessons_cleanup.bats | grep -q 'AC-4' || { echo "🔴 AC-4 测试段不存在（被删除或改名；阶段 3 L3 major：sed 无匹配时原判据静默通过）"; exit 1; };
    sed -n '/AC-4: 模拟全量覆盖场景下 --validate exit = 0/,/^}/p' test/test_lessons_cleanup.bats | grep -vE '^[[:space:]]*#' | grep -q 'skip' && { echo "🔴 AC-4 测试仍含可执行 skip（本判定只读代码行；T10 修复说明注释里出现「skip」字样属预期 —— 主 agent 2026-09-23 修正注释盲陷阱 L-121/L-123）"; exit 1; };
    npx bats test/test_lessons_cleanup.bats >/dev/null || { echo "🔴 AC-4 用例本体未通过（T10 去 skip 后应断言 --validate exit = 0 且变绿）"; exit 1; };
    # 主 agent 2026-09-23 修正：原判据断言 `bash package-flow-kit.sh --validate` rc=0；实测该命令 rc=1 且为 **pre-existing**
    # （逐提交回溯 change-base 534e3e8 → HEAD 全红，恒为 1 项：flow-kit-bundle/hooks/pre-push/pre-push.sh 未登记 package-flow-kit.sh Part C）
    # ⇒ 该项已登记 TD-048、不在本 change 写面（T24 判据对其显式为 ℹ️）⇒ 按 ADR-027「已知可接受项不得升级为 fail」，
    # 本判据改断言「漏配集合恰为已知 1 项、且具名该文件」，对**新增**漏配保持判别力。
    _v=$(bash package-flow-kit.sh --validate 2>&1 || true);
    printf '%s' "$_v" | grep -qE '漏配 \(ERROR\): 1$' || { printf '%s\n' "$_v" | tail -8; echo "🔴 --validate 漏配项数 ≠ 已知的 1 项（TD-048 之外的漏配 ⇒ 本变更引入了未被 Part 覆盖的新文件）"; exit 1; };
    printf '%s' "$_v" | grep -qE '源缺失 \(WARNING\): 0$' || { printf '%s\n' "$_v" | tail -8; echo "🔴 --validate 报出源缺失（staging 清单指向不存在的文件）"; exit 1; };
    printf '%s' "$_v" | grep -qE 'flow-kit-bundle/hooks/pre-push/pre-push\.sh$' || { printf '%s\n' "$_v" | tail -8; echo "🔴 漏配项不是已知的 pre-push（TD-048）"; exit 1; };
    cmp -s test/test_lessons_cleanup.bats flow-kit-bundle/test/test_lessons_cleanup.bats || { echo "🔴 双源不一致"; exit 1; }
  </verify>
  <done>AC-7：删除被检文件后该 bats 必红（不再恒真）、`test_lessons_cleanup.bats` 的 AC-4 测试段**先断言存在**（防删除/改名后静默通过）再去 skip 且断言 `exit 0`</done>
  <depends_on></depends_on>
</task>

<task id="T11" parallel="true" status="done" model-tier="standard">
  <name>AC-3(a)：新建 `pre-push` 拦截器本体（保留 `make check` 语义 + 100755）</name>
  <read_files>
    <`.git/hooks/pre-push`（既有 373 B 文件 · 内容含 `make check`；处置见 DESIGN D3）>
    <`test/test_quality_baseline.bats`（:77 `test -x .git/hooks/pre-push`；:82 `grep -q "make check"` — 两条无 skip）>
    <`flow-kit-bundle/hooks/pre-commit/pre-commit.sh`（仓内 hook 写法与注释风格）>
    <`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`（**尚不存在**；本 hook 需调用其门禁目标的契约见 DESIGN §2.1）>
    <`.specs/health-fix-2026-09b/DESIGN.md`（§1 D3 item 1/5；§0.5.1 新增产物）>
    <`.specs/health-fix-2026-09b/REQUIREMENT.md`（AC-3 全段 + 四形态）>
  </read_files>
  <write_files>
    <`flow-kit-bundle/hooks/pre-push/pre-push.sh`（新增产物 · 入仓须 100755）>
  </write_files>
  <action>
    新建推送拦截器。**次序语义（阶段 3 L3 C1/C2 定稿，T19 的端到端断言依赖它）**：
    ① **先**逐条评估 stdin 的 `<local ref> <local sha> <remote ref> <remote sha>` 行，对含泄漏的 ref 输出**可读原因并指名该 ref**
    （报文须能判出 `refs/heads/main` / `refs/tags/v1` 一类的被拒 ref）并 non-zero 退出；
    ② **全部 ref 干净后**才跑 `make check`（保留既有「push 前跑 `make check`」语义）——
    次序反了会让 `make` 的通用错误先失败、报文无法指名泄漏 ref。
    泄漏拦截走本 change 新增的 `check-path-privacy` 目标；**内容必须保留 `make check` 字面**
    （DESIGN D3 item 1 —— `test_quality_baseline.bats:82` 的无 skip 断言依赖它），
    且**必须 100755 入仓**（D3 item 5：`test -x` 依赖 symlink 目标的 exec 位）。
    对干净 ref 放行；bash 3.2 兼容（不用 `mapfile`/`declare -A`/GNU-only 构造）。
  </action>
  <verify>
    H=flow-kit-bundle/hooks/pre-push/pre-push.sh;
    [ -f "$H" ] || { echo "🔴 缺文件"; exit 1; };
    [ -x "$H" ] || { echo "🔴 缺 exec 位"; exit 1; };
    [ "$(stat -c '%a' "$H" 2>/dev/null || stat -f '%Lp' "$H")" = "755" ] || { echo "🔴 mode ≠ 755"; exit 1; };
    grep -q 'make check' "$H" || { echo "🔴 未保留 make check 语义（bats 断言会转红）"; exit 1; };
    bash -n "$H" || exit 1;
    if grep -vE '^[[:space:]]*#' "$H" | grep -qE 'mapfile|declare[[:space:]]+-A|readlink[[:space:]]+-[fe]|sed[[:space:]]+-i'; then echo "🔴 pre-push.sh 含 bash4-only/GNU-only 构造（bash 3.2 兼容性破坏）"; exit 1; fi
  </verify>
  <done>AC-3：拦截器本体存在、可执行（755 入库）、保留 `make check` 语义且 bash 3.2 兼容 —— AC-8 的 `test_quality_baseline.bats` 两条无 skip 断言可达；**被拒 ref 会被指名**（动态断言在 T19：四种 push 形态各须在报文里出现该 ref 名）；**修复轮 1**（2026-09-23 · L-143）：`CHECK_REF` → `CHECK_REV` 评估面修复（死变量 ⇒ 门禁恒扫本地工作树，`--all`/`--mirror` 时归因错位、工作树干净即整批放行），四形态指名 ref 由 T19 端到端实测；**修复轮 2**（2026-09-24 · TD-048 用户裁决「授权在本 change 内修」· 范围扩张已授权）：`package-flow-kit.sh:134-136` 补 pre-push stanza、`flow-kit-bundle/lib/validate_staging.sh:54` Part C 补 pre-push 模式 ⇒ `--validate` 漏配 0 / `make check-validate` rc=0；`fix_rounds=2`、`commit_sha` 保持 `d613134`〔主 agent 复核 · 九项〕</done>
  <depends_on></depends_on>
</task>

<task id="T12" parallel="true" status="done" model-tier="standard">
  <name>AC-3(b)：`sync-hooks.sh` 四处登记 `pre-push`（真实条目 + entry-class 白名单 + 收集 + orphan 反向扫描）</name>
  <read_files>
    <`sync-hooks.sh`（全文 · 380L；:56 DEST_ROOTS / :79 is_real_entry / :95-97 --entry-class 白名单 / :110 collect_rel_paths / :283+:289 orphan 扫描）>
    <`.specs/health-fix-2026-09b/DESIGN.md`（D3 item 7 · 「三处」已订正为四处）>
    <`.specs/health-fix-2026-09b/REQUIREMENT.md`（AC-3 Given 的 R5 订正：可复现 = install_hooks.sh 部署 + sync-hooks.sh --check 校验）>
  </read_files>
  <write_files>
    <`sync-hooks.sh`>
  </write_files>
  <action>
    把 `pre-push/pre-push.sh` 登记为**真实条目**并纳入镜像面：① `:79 is_real_entry`；② `:95 --entry-class` 白名单与 `:97` 错误文案；
    ③ `:110 collect_rel_paths`；④ `:283`/`:289` 的 orphan 反向扫描目录列表。
    漏登记第 ④ 处的后果是**漏检**（源已删而副本仍在不会被发现），不是误判。
    **不得**改动 `--check`/`--list` 的只读语义（`:164`）；`mapfile`×3 属 TD-035 known-acceptable，**不新增**其他 bash4 构造。
  </action>
  <verify>
    S=sync-hooks.sh;
    [ -f "$S" ] || { echo "🔴 缺 $S"; exit 1; };
    bash sync-hooks.sh --entry-class pre-push/pre-push.sh || { echo "🔴 未被登记为真实条目（修复前 rc=2）"; exit 1; };
    bash sync-hooks.sh --check >/dev/null || { echo "🔴 副本漂移或 orphan 报告"; exit 1; };
    # 镜像面：`--list` 按 DEST_ROOT 枚举状态、**不打印镜像文件名**（✅ 恒为 6），故改判「每个枚举根的 pre-push/pre-push.sh 都在位」
    roots=$(bash sync-hooks.sh --list | sed -n 's/^[[:space:]]*✅[[:space:]]*//p'); n=$(printf '%s\n' "$roots" | grep -c .);
    [ "$n" -ge 6 ] || { echo "🔴 镜像根枚举数 = $n（<6：--list 面异常）"; exit 1; };
    miss=0; for r in $roots; do [ -f "$r/pre-push/pre-push.sh" ] || { echo "🔴 镜像缺 pre-push/pre-push.sh: $r"; miss=1; }; done;
    [ "$miss" -eq 0 ] || exit 1;
    nf=$(bash sync-hooks.sh --list | sed -n 's/.*镜像文件数: \([0-9][0-9]*\).*/\1/p');
    { [ -n "$nf" ] && [ "$nf" -ge 48 ]; } || { echo "🔴 镜像文件数 = ${nf:-空}（<48：登记未进入同步面；T05 基线 47）"; exit 1; };
    # ④ orphan 反向扫描（双态）：探针在位 ⇒ --strict-orphans 必非 0 且指名；移除 ⇒ --check 必 0
    probe="$HOME/.claude/hooks/pre-push/zz-verify-orphan-probe.sh"; trap 'rm -f "$probe"' EXIT;
    [ -d "$(dirname "$probe")" ] || { echo "🔴 无 pre-push 镜像目录（sync 未落盘）"; exit 1; };
    printf '#!/bin/sh\n' > "$probe";
    out=$(bash sync-hooks.sh --check --strict-orphans 2>&1); rc=$?;
    [ "$rc" -ne 0 ] || { echo "🔴 orphan 反向扫描未覆盖 pre-push（探针在位而 rc=0）"; exit 1; };
    printf '%s' "$out" | grep -q 'pre-push/zz-verify-orphan-probe.sh' || { echo "🔴 报错未指名探针（缺 file:line）"; exit 1; };
    rm -f "$probe"; bash sync-hooks.sh --check >/dev/null 2>&1 || { echo "🔴 清理探针后 --check 仍非 0"; exit 1; }
  </verify>
  <done>AC-3：`--entry-class pre-push/pre-push.sh` rc=0、`--check` rc=0、六个镜像根逐一在位的 `pre-push/pre-push.sh`（`镜像文件数` 由 T05 基线 47 增至 48）、④ orphan 反向扫描对 `pre-push/**` 生效（探针在位 ⇒ `--check --strict-orphans` rc=1 且报文指名；移除 ⇒ `--check` rc=0）——修复前实测：`--entry-class` rc=2、`--list` 的 ✅ 恒为 6（`--list` 不打印镜像文件名 ⇒ 原「`--list` 含 pre-push」与「✅ ≥ 7」两条断言为**工件缺陷**，已由主 agent 按 L-128 改写，裁决记录见 `MINOR-DEFERRED.md`）</done>
  <depends_on></depends_on>
</task>

<task id="T13" parallel="true" status="done" model-tier="standard">
  <name>AC-6 前置（D10′①）：工件脱敏 —— 必须先于基线冻结</name>
  <read_files>
    <`.specs/health-fix-2026-09b/DESIGN.md`（D10′ 四步顺序 ①~④ 与排除表构成）>
    <`.specs/health-fix-2026-09b/REQUIREMENT.md`（AC-6 全段 · 探针形态与「不得用 `/home/<user>`」禁令）>
    <`.specs/health-fix-2026-09b/MINOR-DEFERRED.md`>
    <`.specs/health/*.md`（同批入库的健康档）>
    <`.specs/CONTEXT.md`（禁动清单；本 task 不改它）>
  </read_files>
  <write_files>
    <`.specs/health-fix-2026-09b/DESIGN.md`（主 agent 2026-09-23 实测 **1** 行命中：`:215`）>
    <`.specs/health-fix-2026-09b/REQUIREMENT.md`（实测 **0** 行命中 —— 仍留在写面内作条件写面）>
    <`.specs/health/2026-09-22-FULL-SWEEP.md`（实测 3 行真实账号路径：`:126` / `:242` / `:255`）>
    <③b `.specs/health-fix-2026-09b/T[0-9]+-SUMMARY.md`（实测 **10** 行真实账号路径：T04-SUMMARY 9（`:297` `:300`-`:305` `:314` `:316`）+ T11-SUMMARY 1（`:56`），均来自自本机粘贴的原始输出；**执行者自撰散文 ⇒ 就地脱敏、不豁免、不入排除表** —— 与 `INDEPENDENT-REVIEW-*.md` 的「协议禁改原文 ⇒ 逐条精确路径豁免」相反）>
    <④ 运行时授权面（**条件写面** · 闭集）：**唯一权威定义** = 本 task 的 verify 段中 `$FACE` 正则所列 **4 类**（本 change 工件 5 份 / 各 task 的 `T*-SUMMARY.md` / `.specs/health/*.md` / `.specs/adr/*.md`；此处不重复枚举，避免两处漂移）；仅当复扫另命中其中一类时才可写入。**不放宽到 §0.5.1 的全 change 写面**（那会使越界判定形同虚设 —— 阶段 3 L3 C2）；命中 ④ 之外（代码/测试/门禁本体，含禁动清单内）⇒ 停止并升级为新 task。>
    <（本 task 的静态写面 = ① ② ③ ③b 四条精确路径；④ 为条件写面声明，不是路径列表。）>
  </write_files>
  <action>
    ① 把工件与同批健康档中的**真实账号路径**替换为脱敏占位（`/home/<acct>/` 形态 —— 该形态**不**被 D10 的 PAT 命中）；
    ② **自造 fixture 字面**（如 `/home/<acct>/test/x.sh` 形态）改写为不命中形态（`$HOME/x.sh` 等）——
    **禁止**把 `test` 加进通用占位符排除表（那是放宽判据，不是脱敏）；
    ③ 只做字面替换：**不得**改动任何判据文本、实测数字、决策与 AC 语义；
    ④ **契约边界**：`INDEPENDENT-REVIEW-*.md` **不得**出现于 write_files（只可写「主 agent 响应」段，且由主 agent 处理）；
    其审查员原文按 D10′② 由排除表**逐条精确路径**豁免（禁宽通配）；
    ⑤ 本 task 结束后按 D10′③ 顺序：`git add` 全部工件 → 复扫非 0 即**中止**（禁止冻结）。
    ⑥ **运行时授权面（面约束 · 非步骤 · 阶段 3 L3 M4 归位）**：条件写面的**唯一权威定义**是本 task 的 verify 段中 `$FACE` 正则（3 类逐条精确路径）；
    仅当复扫另命中其中一类时才允许就地脱敏，并在 4-dev 日志留 `file:line` + 脱敏前后对照；残余命中落在面外（含禁动清单内）⇒ **停止并升级为新 task**。
    `.specs/health-fix-2026-09b/TASK.md` **在授权面内**（`$FACE` 第 1 类）：本 task 自身的 fixture 字面已在阶段 3 de-shape 为 `/home/<acct>/test` 形态，当前对 PAT 命中 **0 处**；若复扫再现命中 ⇒ 由本 task 就地 de-shape（语义中性），**不**把计划档排除出扫描面（排除会让冻结前的基线失去对计划档自身的覆盖 —— 阶段 3 L3 minor 的替代方案已评估并否决）。
    **审查档排除面与 T17 门禁的排除表同源（阶段 3 L3 M8；规则于阶段 5 修正 · L-149/TD-054）**：两者都是「逐条精确路径」。同源规则经阶段 5 实测由「集合完备」修正为**时间切点**：冻结的 1–3 是**唯一**豁免集（成文早于脱敏规则，原文含真实账号路径），**此后新增的审查档一律不豁免、必须被本方复扫与门禁双面扫过**。T17 的 verify 因此改判「豁免面**不得**超出冻结集 1–3」（新增档被追加进排除表 ⇒ 红；放宽须 ADR 裁决）。实证：2026-09-24 新增的 `INDEPENDENT-REVIEW-5.md` 未豁免 ⇒ 被 `make check-path-privacy` 判红 rc=2 并在就地 de-shape 后复绿（同一规则、两处判定，未静默漂移；旧「完备」规则会把同一处泄漏塞进豁免表 ⇒ 反而静默入库）。
    ⑦ **SUMMARY 面与前向规则（2026-09-23 主 agent 追加）**：`T*-SUMMARY.md` 属**执行者自撰散文**，其中自本机粘贴的绝对路径（`/home/<真实账号>/…`、`/Users/…`）必须 de-shape 为 `<repo>` / `$HOME` / `/home/<acct>/` 形态；**只做路径字面替换，不得改动 rc、命令、输出文本与数字等证据本身**。同理，**本 task 之后的每个 task 在其 SUMMARY 定稿前就地 de-shape**（不积压到 T13）；前向规则以 **L-129** 形式写入 `.specs/LESSONS.md`，由各执行者按「必读 LESSONS」条款继承。
  </action>
  <verify>
    export LC_ALL=C; PAT='/home/[a-z_][a-z0-9_-]*/';
    git rev-parse --git-dir >/dev/null 2>&1 || { echo "🔴 非 git 仓库：扫描面依赖 git 索引，判据不可用（阶段 3 L3 minor）"; exit 1; };
    # 分支 1 = 已 tracked；分支 2 = **刻意**补扫**未 tracked** 面（阶段 3 L3 M1 的「五份工件补扫」升级为通用形态）：
    # 五份 change 工件与同批 `.specs/health/*.md`、本 change 新建的 `.specs/adr/*.md` 在本 task 运行时**尚未 `git add`**，
    # 不进 `git ls-files` 分支 ⇒ 不补扫则静态写面 ③ 的脱敏与 ADR 面的命中**永远不可见**（L-122：判据必须触达缺陷现场；
    # 主 agent 2026-09-23 实测：原形态对 FULL-SWEEP 的 3 处真实账号路径完全失明）。
    # 空集必须显式处理：GNU xargs 在空输入下以无参形式调用 ⇒ `grep` 转去读 stdin（判据静默失效，L-121）。
    # 与分支 1 可能命中同一行 ⇒ 统一 `sort -u` 去重后再计数（阶段 3 L3 m2）；`-H` 强制打印文件名（单文件时 grep 默认不打印文件名，会破坏下方按 file:line 的归因与排除表匹配）。
    uf=$(git ls-files -o --exclude-standard);
    if [ -n "$uf" ]; then u_hits=$(printf '%s\n' "$uf" | tr '\n' '\0' | xargs -0 grep -HnE "$PAT" 2>/dev/null); else u_hits=''; fi;
    # 2026-09-24（阶段 5 · 主 agent 判据修复 · L-147 · TD-052）：产品门禁本体 `check-path-privacy.sh` 的头部注释
    # **必然**含 PAT 字面 —— 它要在自证文档里说明「拼接构造的畸形探针（账号名 zz-path-probe）」这一双态判别力。
    # 产品侧对这类文件按 D10′② 用 `SELF_EXCLUDE`（逐条精确路径）整文件排除；本判据**刻意不排除任何文件**
    # （其职责正是覆盖产品的自排除面）⇒ 两者排除面不同源，只能在本判据内**按逐条精确字面**豁免该合成探针账号名。
    # 禁止放宽为 `reference/*` 之类宽通配；真实账号形态与其他合成账号名仍一律被 PAT 命中（阶段 5 判别力注入实测）。
    hits=$( { git -c core.quotepath=false ls-files -z | xargs -0 grep -HnE "$PAT" 2>/dev/null; printf '%s\n' "$u_hits"; } \
            | sort -u \
            | grep -vE '^(\.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-(1|2|3)\.md):' \
            | grep -vE '/home/(user|ubuntu|\.\.\.|zz-path-probe)/' );
    n=$(printf '%s' "$hits" | grep -c .);
    if [ "$n" -ne 0 ]; then
      printf '%s\n' "$hits" | cut -c1-140;   # 可见性：逐条 file:line
      # 就地脱敏面断言（阶段 3 L3 C2：**收窄**为「本 change 自身工件与台账」）——
      # 原实现以 §0.5.1 的全 change 写面（含 Makefile / sync-hooks.sh / 9 个 bundle 脚本 / 全部 bats）为授权面，
      # 等价于「T13 可改整个 change 的写面」⇒ 越界判定形同虚设。代码/测试/门禁本体的任何残余命中一律升级为新 task。
      # 2026-09-23 主 agent 补两处：① 原形态把 FACE 判定写在 `[ "$n" -eq 0 ] || exit 1` **之后** ⇒ 该断言**永不可达**（死判据，L-123）；
      # ② `T*-SUMMARY.md` 未列入面 —— 而 T04/T11 的 SUMMARY 实测含 10 行真实账号路径（自本机粘贴的原始输出）。
      # 定则：**审查档原文**因协议禁改 ⇒ 由 D10′② 逐条精确路径豁免；**SUMMARY 是执行者自撰散文** ⇒ 就地脱敏、不豁免、不入排除表。
      FACE='^(\.specs/health-fix-2026-09b/(DESIGN|REQUIREMENT|CHANGE|MINOR-DEFERRED|TASK)\.md|\.specs/health-fix-2026-09b/T[0-9]+-SUMMARY\.md|\.specs/health/[^/]+\.md|\.specs/adr/[^/]+\.md)$';
      bad=$(printf '%s\n' "$hits" | cut -d: -f1 | sort -u | grep -vE "$FACE" | grep -v '^$' | tr '\n' ' ');
      [ -z "$bad" ] || { echo "🔴 脱敏越界（非本 change 工件/台账 ⇒ **停止并升级为新 task**，不得就地修改）：$bad"; exit 1; };
      echo "🔴 清单外命中=$n（全部落在脱敏授权面内 ⇒ 就地脱敏后重跑本判据；禁止冻结基线）"; exit 1;
    fi
    echo "✅ 脱敏完成：授权面外命中 = 0（tracked + 未 tracked 两面均已扫描）"
  </verify>
  <done>AC-6 前置：排除表口径下「清单外命中 = 0」。**修复前基线（主 agent 2026-09-23 用本判据实测，共 14 行）**：`DESIGN.md` 1（`:215` 的 `/home/<acct>` 自造 fixture 字面）/ `T04-SUMMARY.md` 9（`:297` `:300`-`:305` `:314` `:316`）/ `T11-SUMMARY.md` 1（`:56`）/ `.specs/health/2026-09-22-FULL-SWEEP.md` 3（`:126` `:242` `:255`）；`REQUIREMENT` / `CHANGE` / `TASK` / `MINOR-DEFERRED` 各 0；审查档 40 = IR-1 22 + IR-2 18（按 D10′② 逐条精确路径豁免，协议禁改原文）。**未 tracked 面**（尚未 `git add` 的工件与同批健康档）由本 task 补扫后才可见 —— 原判据对该面完全失明（L-122 / L-129）。SUMMARY 的 10 行属下文 ⑦ 前向规则的存量债 ⇒ 就地脱敏、不豁免。满足 D10′①「脱敏先于冻结」〔主 agent 2026-09-24 阶段 5 第 1 轮判据修复〕全量复跑实测 rc=1，命中源 = 产品门禁本体头部注释里的**拼接构造探针字面**（`:22-24`，T22 追加）—— 产品按 D10′② 对该文件整文件自排除，而本判据**刻意不排除任何文件** ⇒ 只能在本判据内按**逐条精确字面**豁免该合成账号名（`grep -vE '/home/(user|ubuntu|\.\.\.|zz-path-probe)/'`；**不**抄产品的整文件 `SELF_EXCLUDE`）⇒ rc=0；判别力二次注入实测保持：非面文件注入另一合成账号名 ⇒ rc=1 且指名 `sync-hooks.sh:382`、面内文件注入 ⇒ rc=1 走「清单外命中 = 1 ⇒ 就地脱敏」分支；L-147 / TD-052</done>
  <depends_on>T01</depends_on>
</task>

<task id="T14" parallel="true" status="done" model-tier="cheap">
  <name>AC-4 接线：`check-gate-sync` 纳入 `make check` 先决条件</name>
  <read_files>
    <`Makefile`（:5 .PHONY / :106 `check:` 先决条件行 / :16 含 `check-gate-sync` 字样的注释）>
    <`flow-kit-bundle/flow-kit/reference/check-gate-sync.sh`（T08 已定稿的判据）>
    <`.specs/health-fix-2026-09b/REQUIREMENT.md`（AC-4 验证方式 · L2 R1 证伪初版「grep Makefile ≥1」恒真）>
  </read_files>
  <write_files>
    <`Makefile`>
  </write_files>
  <action>
    **现状（主 agent 2026-09-23 实测订正）**：`grep -n 'check-gate-sync' Makefile` 只命中 `:16` 的**注释** —— `check-gate-sync` **目标当前并不存在**。
    落地三件（只改 `Makefile`）：
    ① **新建薄壳目标** `check-gate-sync:`（与既有 `check-dist` 同形：`@bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh`；recipe 文本须**含该脚本路径**，`make -n` 才可检出；**禁** `|| true` / `&& true` 吞失败 —— L-121「命令 ≠ 断言」）；
    ② 追加为 `check:` 的**先决条件**（`Makefile:106`；沿用既有 `check-*` 命名与接入点，**不新建聚合目标**）；
    ③ `.PHONY`（`Makefile:5`）追加 `check-gate-sync`。
    接线断言**必须用干跑**（`make -n check`）—— `Makefile:16` 存在同名**注释**，`grep Makefile` 会命中注释而恒真。
    **边界**：`check-path-privacy` 的接线是 T18 的活，本 task 不得提前接入；`make check` 因 `check-dist` 未收口（T24）仍为红，本 task 不得试图让它整体变绿。
  </action>
  <verify>
    grep -E '^\.PHONY:' Makefile | grep -qw 'check-gate-sync' || { echo "🔴 .PHONY 未登记 check-gate-sync（非 phony 目标遇同名文件会被 make 判为最新 ⇒ recipe 不执行、假绿）"; exit 1; };
    make -n check | grep -q 'check-gate-sync' || { echo "🔴 check-gate-sync 未接入 make check"; exit 1; };
    make -n check-gate-sync | grep -q 'check-gate-sync\.sh' || { echo "🔴 check-gate-sync 目标 recipe 未调用 check-gate-sync.sh（干跑无脚本路径 ⇒ 接线与判据脱节）"; exit 1; };
    bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh || { echo "🔴 健康态门禁未通过"; exit 1; }
  </verify>
  <done>AC-4①：`make -n check` 的先决条件含 `check-gate-sync`、`.PHONY` 已登记、且健康态该门禁 `exit 0`（修复前实测：目标**不存在** —— `grep -n 'check-gate-sync' Makefile` 仅命中 `:16` 注释、`make -n check | grep -q check-gate-sync` ⇒ rc=1）</done>
  <depends_on>T08</depends_on>
</task>

<task id="T15" parallel="true" status="done" model-tier="cheap">
  <name>AC-4 断言收紧：`test_check_gate_sync.bats` 由容忍 `exit 1` 改为断言 `exit 0`</name>
  <read_files>
    <`test/test_check_gate_sync.bats`（:30 `[ "$status" -ne 2 ]` · 显式容忍永久红）>
    <`flow-kit-bundle/test/test_check_gate_sync.bats`（镜像）>
    <`.specs/health-fix-2026-09b/REQUIREMENT.md`（AC-4 修复前实测表：`grep -n 'status.*-ne 2'` 命中 `:30`）>
  </read_files>
  <write_files>
    <`test/test_check_gate_sync.bats`>
    <`flow-kit-bundle/test/test_check_gate_sync.bats`>
  </write_files>
  <action>
    ① 把容忍 `exit 1` 的断言收紧为 `[ "$status" -eq 0 ]`（门禁修复后健康态必须绿），双源**逐字节**同步；不得保留任何「非脚本错误即通过」形态。
    ② **双态证据（L-120/L-123，必做；禁止只交「绿」的单态）**：证明收紧后的断言**真的能红** ——
       备份 `flow-kit-bundle/flow-kit/reference/check-gate-sync.sh` → **把健康分支的自然出口改为非 0**（`sed -i '210s/^  exit 0$/  exit 1/'`；**不得**用「末尾追加 `exit 1`」—— `:210` 的 `exit 0` 先终止进程、追加行是死代码 ⇒ 注入态仍绿 = 假绿，见 **L-132**）→ **先断言注入后脚本自身 rc 非 0** → `npx bats test/test_check_gate_sync.bats` 必须出现 `not ok`（贴真实输出）→ 用备份逐字节恢复并 `cmp -s` 证明复原 → 复跑必须全绿。
  </action>
  <verify>
    grep -nE '\[ "\$status" -ne [0-9]+ \]' test/test_check_gate_sync.bats && { echo "🔴 仍存在「容忍非零退出」形态的断言（-ne N；阶段 3 L3 major：单一 -ne 2 模式可被等价改写绕过）"; exit 1; };
    grep -qE '\[ "\$status" -eq 0 \]' test/test_check_gate_sync.bats || { echo "🔴 未收紧为 -eq 0"; exit 1; };
    npx bats test/test_check_gate_sync.bats || { echo "🔴 bats 未绿"; exit 1; };
    cmp -s test/test_check_gate_sync.bats flow-kit-bundle/test/test_check_gate_sync.bats || { echo "🔴 双源不一致"; exit 1; }
  </verify>
  <done>AC-4：bats 断言为 `exit 0`、**任何** `-ne N` 形态均被判失败（负向穷举 `-ne [0-9]+`，防「-ne 2 改写成 -ne 1」绕过），健康态绿，**并附双态证据**（把健康分支出口改为非 0 ⇒ 该用例必红；复原 ⇒ 绿；**末尾追加 `exit 1` 是死代码**（`:210` 的 `exit 0` 在先）⇒ L-132）（修复前实测：`test/test_check_gate_sync.bats:30` 为 `-ne 2`）</done>
  <depends_on>T08</depends_on>
</task>

<task id="T16" parallel="true" status="done" model-tier="top">
  <name>AC-3(c) 部署形态闭环（L3 #4 major①）：`install_hooks.sh` 新增 `deploy_pre_push()` 并以 symlink 为唯一产物形态</name>
  <read_files>
    <`flow-kit-bundle/lib/install_hooks.sh`（:41 deploy_pre_commit 定义 · **语义相反禁止照抄** / :69 install_hooks / :92/:101 hook_dst / :153 接线点）>
    <`.specs/adr/022-git-hook-deployment.md`（symlink → 已安装 hooks 目录 + 幂等语义）>
    <`sync-hooks.sh`（exec 位只读检查 :236-240；副本一致性校验）>
    <`test/test_quality_baseline.bats`（两条无 skip 断言 · 依赖 symlink 目标可执行且含 `make check`）>
    <`.specs/health-fix-2026-09b/DESIGN.md`（D3 定稿伪代码 `is_flowkit_symlink` + 备份/覆盖块 + item 5/6/7）>
    <`.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-2.md`（末段 L3 重审 #4 major① · fix 原文）>
  </read_files>
  <write_files>
    <`flow-kit-bundle/lib/install_hooks.sh`>
  </write_files>
  <action>
    **定稿形态（消除 L3 #4 major① 的语义冲突）**：部署产物 = **symlink → 已安装 hooks 目录**（`$hook_dst/pre-push/pre-push.sh`），
    **不得**用 `cp --remove-destination` 落成普通文件（那会使后续安装不命中 symlink 幂等条件、反复备份+覆盖，
    且 `sync-hooks.sh --check` 的 symlink 校验失效）。落地：
    ① `is_flowkit_symlink()`：`[ -L ]` + `[ -e ]`（悬空 symlink 必须 `return 1`）+ 裸 `readlink`（**禁** `readlink -f`，GNU-only）；
       case 明确否决 `*/flow-kit-bundle/hooks/pre-push/pre-push.sh`（源树）与 `*/dist/*`（非安装位），只认 `*/hooks/pre-push/pre-push.sh`；
    ② 命中幂等 ⇒ 跳过；否则 **先备份**（`[ -L ]` 时 `readlink > "${bak}.linktarget"`，普通文件 `cp -p`；备份名须含 PID 或纳秒以避免同秒并发覆盖）→
       `rm -f` 旧物 → `ln -s` 新链 → `chmod +x` → `[ -x ]` 断言（每步失败不得静默）；
    ③ 接线点 = `install_hooks.sh:153` 的 `deploy_pre_commit` 调用之旁；函数语义**必须重写**，禁止照抄 `deploy_pre_commit`（`:51-61` 是 skip/交互确认，与本处「备份后覆盖」相反）。
  </action>
  <verify>
    SBX=$(mktemp -d /tmp/l3-push-XXXXXX); mkdir -p "$SBX/proj" "$SBX/home"; git -C "$SBX/proj" init -q;
    # 夹具预置既有普通文件 pre-push（主 agent 2026-09-23 补 · 真实场景：本仓 .git/hooks/pre-push 是 373 B 普通文件）
    # 否则 n1=n2=0，幂等断言与「先备份再覆盖」断言全部空转（L-122/L-130）
    mkdir -p "$SBX/proj/.git/hooks";
    printf '#!/bin/sh\n# legacy pre-push（AC-3 夹具 · 既有普通文件，非 symlink）\nmake check\n' > "$SBX/proj/.git/hooks/pre-push";
    chmod +x "$SBX/proj/.git/hooks/pre-push";
    cp "$SBX/proj/.git/hooks/pre-push" "$SBX/legacy-pre-push.orig";
    HOME="$SBX/home" bash flow-kit-bundle/install.sh --project "$SBX/proj" --no-brooks >/dev/null 2>&1 || true;
    T="$SBX/proj/.git/hooks/pre-push";
    [ -L "$T" ] || { echo "🔴 部署产物不是 symlink（ADR-022 形态未闭环）"; exit 1; };
    [ -e "$T" ] || { echo "🔴 悬空 symlink"; exit 1; };
    [ -x "$T" ] || { echo "🔴 部署后不可执行"; exit 1; };
    grep -q 'make check' "$T" || { echo "🔴 未保留 make check 语义（bats 断言将转红）"; exit 1; };
    tgt=$(readlink "$T"); case "$tgt" in */flow-kit-bundle/hooks/pre-push/pre-push.sh|*/dist/*) echo "🔴 错绑源树/dist"; exit 1;; esac;
    n1=$(ls "$SBX/proj/.git/hooks/" | grep -c 'pre-push.bak' || true);
    [ "$n1" -ge 1 ] || { echo "🔴 覆盖既有 pre-push 前未备份（备份数=$n1）"; exit 1; };
    _bk=0; for _f in "$SBX/proj/.git/hooks/pre-push.bak"*; do [ -e "$_f" ] && cmp -s "$_f" "$SBX/legacy-pre-push.orig" && _bk=1; done;
    [ "$_bk" -eq 1 ] || { echo "🔴 备份未逐字节保全既有文件（cmp 不一致）"; exit 1; };
    HOME="$SBX/home" bash flow-kit-bundle/install.sh --project "$SBX/proj" --no-brooks >/dev/null 2>&1 || true;
    n2=$(ls "$SBX/proj/.git/hooks/" | grep -c 'pre-push.bak' || true);
    [ "$n1" = "$n2" ] || { echo "🔴 非幂等：二次安装又产生备份"; exit 1; };
    grep -q 'deploy_pre_push' flow-kit-bundle/lib/install_hooks.sh || { echo "🔴 缺 deploy_pre_push"; exit 1; }
    # 镜像面纪律（主 agent 2026-09-23 补 · T05 工艺结论）：install_hooks.sh 属镜像面 ⇒ 不同步会让 B5-R2/R5 转红、提交被拒
    ./sync-hooks.sh >/dev/null || { echo "🔴 sync-hooks.sh 同步失败"; exit 1; };
    bash sync-hooks.sh --check || { echo "🔴 副本漂移（须先同步再提交）"; exit 1; };
    make check-hooks-sync >/dev/null || { echo "🔴 check-hooks-sync 未通过"; exit 1; }
  </verify>
  <done>AC-3：部署产物为「指向已安装 hooks 目录」的 symlink、可执行、含 `make check`、二次安装幂等（无新增备份）—— 修复前实测：`deploy_pre_push` 命中 0、pre-push 未被部署；既有普通文件 pre-push 必须先备份再覆盖（备份逐字节保全，`cmp` 断言）</done>
  <depends_on>T06, T12</depends_on>
</task>

<task id="T17" parallel="true" status="done" model-tier="top">
  <name>AC-6 门禁实现：`check-path-privacy.sh`（PAT + 排除表 + fail-closed 读序 + 自证输出）</name>
  <read_files>
    <`flow-kit-bundle/flow-kit/reference/check-gate-sync.sh`（同址既有门禁的写法与输出风格）>
    <`.specs/health-fix-2026-09b/DESIGN.md`（§1 D1/D8/D10 + §2.1 拓扑 + §3 退出码模型：**二值 0/1、无 SKIP**）>
    <`.specs/health-fix-2026-09b/REQUIREMENT.md`（AC-6 全段 · 探针拼接构造 / 自报条数 / 差分数 / `清单外命中 0 条`）>
    <`.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-2.md`（末段 L3 #4 major②③ · fix 原文）>
    <`.specs/adr/027*`、`.specs/adr/028*`（门禁阻塞面与棘轮语义）>
  </read_files>
  <write_files>
    <`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`（新增产物 · D8 定稿选项③）>
  </write_files>
  <action>
    实现 `PAT='/home/[a-z_][a-z0-9_-]*/'` + 通用占位符排除表（`user` / `ubuntu` / `...`），扫 `git ls-files` 内容（不扫 `.git` 内部）。
    **排除表按「被匹配的用户名成分」而非按行**（同一行同时含占位符与真实路径时按行排除会漏报）；
    自排除边界（强制）：用**固定相对路径逐条精确**排除 `flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`、
    `flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt`、`.specs/health-fix-2026-09b/path-privacy-allowlist.txt`
    与**逐条枚举**的审查档（`INDEPENDENT-REVIEW-1.md` / `INDEPENDENT-REVIEW-2.md` / `INDEPENDENT-REVIEW-3.md`，**逐条精确路径、禁宽通配**）；
    **后续阶段（5/6/7）新增的审查档，只有在它实际出现「非通用占位符」PAT 命中时才需要追加**，且追加必须是**显式动作**（登记于响应段）——
    **不得**为省事改成 `INDEPENDENT-REVIEW-*` 通配（D10′② 实测：通配会吞掉 31 处 `<acct>` 字样含 10+ 处真实账号路径，且永久无界）；
    该排除表本身须有断言（排除路径内注入探针不命中 / 路径外注入命中）。
    **读序（R8 定级裁决）= 常设路径 > change 副本 > 两者皆缺 ⇒ `exit 1` 并指名缺失路径**（fail-closed，不得当空清单）。
    **对外自证输出**：`允许清单 N 条` / `清单外命中 M 条` + `file:line`；`M≠0` 非零退出；退出码**二值**（0/1，无 SKIP）。
    新写脚本必须 `mktemp` + `trap` 清理；bash 3.2 兼容（不用 `mapfile`/`declare -A`/`readlink -f`/`sed -i`/`grep -P`）。

    **外部指定评估面 `CHECK_REV`（主 agent 2026-09-23 追加 · 裁决 R12 · LESSONS L-131）**：当环境变量 `CHECK_REV` 非空时，
    评估面从本地工作树切换为**该 rev 的树**：候选文件 = `git ls-tree -r --name-only "$CHECK_REV"`，命中 = `git grep -nE "$PAT" "$CHECK_REV" --`（或等价实现）；
    逐行仍走**同一套**占位符排除表 / 自排除清单 / `file:line` 归因；`CHECK_REV` 缺省（空）时行为与现状完全一致（扫工作树）；
    自证输出必须报出扫描面（`扫描面: 工作树` 或 `扫描面: <rev>`）；`CHECK_REV` 无法解析为 commit（`git rev-parse --verify --quiet "$CHECK_REV^{commit}"` 失败）⇒ `exit 1` fail-closed。
    **理由**：pre-push 的拦截对象是**被推送的 ref 树**，不是本地工作树 —— 工作树干净时泄漏提交会被整批放行（T11 的 `CHECK_REF` 只是归因字符串，不改变评估面）。
  </action>
  <verify>
    S=flow-kit-bundle/flow-kit/reference/check-path-privacy.sh;
    [ -f "$S" ] || { echo "🔴 缺门禁脚本"; exit 1; };
    bash -n "$S" || exit 1;
    grep -vE '^[[:space:]]*#' "$S" | grep -qE 'reference/\*|skills/\*|\.specs/\*' && { echo "🔴 排除表含宽通配（禁；已剔除整行注释：脚本注释里写「不得用 reference/*」不算违规 —— L-125 族）"; exit 1; };
    grep -q 'reference/check-path-privacy.sh' "$S" || { echo "🔴 排除表未逐条列自指路径"; exit 1; };
    grep -vE '^[[:space:]]*#' "$S" | grep -qE 'mapfile|declare[[:space:]]+-A|readlink[[:space:]]+-[fe]|sed[[:space:]]+-i|grep[[:space:]]+-P' && { echo "🔴 含 bash4/GNU-only 构造（已剔除整行注释：只读代码行）"; exit 1; };
    # 清单缺失态（fail-closed）必须在「两份清单都不存在」的夹具里判定 —— 常设清单自 T21 起已冻结存在，
    # 在真实仓根上跑永远是「有清单」态（旧断言自 T21 后恒红：判据陈旧，非门禁回归 · 主 agent 2026-09-23 订正）
    _miss=$(mktemp -d /tmp/t17-miss-XXXXXX); trap 'rm -rf "$_miss"' EXIT;
    mkdir -p "$_miss/flow-kit-bundle/flow-kit/reference";
    cp "$S" "$_miss/flow-kit-bundle/flow-kit/reference/";
    ( cd "$_miss" && git init -q . && git config user.email t@t && git config user.name t && git add -A && git commit -qm base );
    out=$( cd "$_miss" && bash "./flow-kit-bundle/flow-kit/reference/check-path-privacy.sh" 2>&1 ); rc=$?;
    [ "$rc" -eq 1 ] || { printf '%s\n' "$out"; echo "🔴 两清单皆缺态 rc=$rc ≠ 1（fail-closed 未实现）"; exit 1; };
    printf '%s' "$out" | grep -q 'path-privacy-allowlist.txt' || { printf '%s\n' "$out"; echo "🔴 报文未指名缺失清单路径"; exit 1; };
    rm -rf "$_miss";
    # 排除表边界（阶段 3 L3 M8 原意 + 阶段 5 定级裁决 · L-149 / TD-054）：
    #   M8 要的是「门禁排除表与 T13 排除面**同源、不得静默漂移**」；同源的**规则**在阶段 5 被实测修正为
    #   **时间切点**而非「集合完备」：冻结的历史审查档 1–3（成文早于脱敏规则、原文含真实账号路径）逐条精确豁免；
    #   **此后新增的审查档一律不豁免** —— 它们正是脱敏泄漏的第一现场（2026-09-24 实测：
    #   INDEPENDENT-REVIEW-5.md 未豁免 ⇒ 被本门禁判红 rc=2（清单外命中 1 条）并被就地 de-shape 后才入库；
    #   若按旧「完备」规则把它塞进豁免表，同一处泄漏反而静默入库 ⇒ 判据会亲手弄瞎它本该保护的门禁）。
    #   故本判据改判「豁免面**不得**超出冻结集」：新增审查档被追加进排除表时为红（放宽须 ADR 裁决 · TD-054）。
    n_ir=0; for f in $(ls .specs/health-fix-2026-09b/INDEPENDENT-REVIEW-*.md 2>/dev/null | sort); do
      n_ir=$((n_ir+1));
      case "$f" in
        .specs/health-fix-2026-09b/INDEPENDENT-REVIEW-1.md|.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-2.md|.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-3.md) continue ;;
      esac
      grep -qF "$f" "$S" && { echo "🔴 审查档 $f 被纳入门禁排除表（豁免面不得超出冻结集 1–3；放宽须 ADR 裁决 · L-149/TD-054：审查档是脱敏第一现场，豁免即盲区）"; exit 1; };
    done;
    [ "$n_ir" -ge 3 ] || { echo "🔴 枚举到的审查档不足 3 份（枚举面失效 ⇒ 判据空转）"; exit 1; };
    for k in 1 2 3; do
      grep -qF ".specs/health-fix-2026-09b/INDEPENDENT-REVIEW-$k.md" "$S" || { echo "🔴 冻结豁免档 $k 不在排除表内（历史豁免面被静默收窄 ⇒ 门禁排除表与 T13 排除面不再同源）"; exit 1; };
    done;
    # CHECK_REV 外部评估面双态（主 agent 2026-09-23 补 · L-131）：泄漏只存在于历史树、工作树干净 ⇒ rev 模式必须判红并给出扫描面与 file:line
    _cwd=$(pwd); _sbx2=$(mktemp -d /tmp/l3-rev-XXXXXX); git init -q "$_sbx2/r"; trap 'rm -rf "$_sbx2"' EXIT;
    mkdir -p "$_sbx2/r/flow-kit-bundle/flow-kit/reference";
    cp "$S" "$_sbx2/r/flow-kit-bundle/flow-kit/reference/";
    : > "$_sbx2/r/flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt";
    printf 'benign candidate（TD-066：F-19 起自排除后 0 实际扫描即 fail-closed ⇒ 干净对照夹具必须含至少 1 个非自排除候选）\n' > "$_sbx2/r/README.md";
    ( cd "$_sbx2/r" && git config user.email t@t && git config user.name t && git add -A && git commit -qm base \
      && printf '/home/%s/leak\n' "$(whoami)" > leak.txt && git add -A && git commit -qm leak && git rm -q leak.txt && git commit -qm clean );
    _leak_rev=$(git -C "$_sbx2/r" rev-parse HEAD~1);
    [ -z "$(git -C "$_sbx2/r" status --porcelain)" ] || { echo "🔴 夹具工作树非干净（对照不成立）"; exit 1; };
    cd "$_sbx2/r" || exit 1;
    _wt_rc=0; bash "./flow-kit-bundle/flow-kit/reference/check-path-privacy.sh" >/dev/null 2>&1 || _wt_rc=$?;
    [ "$_wt_rc" -eq 0 ] || { echo "🔴 工作树模式在干净树上未 rc=0（rc=$_wt_rc）⇒ 对照不成立"; cd "$_cwd"; exit 1; };
    _rev_out=$(CHECK_REV="$_leak_rev" bash "./flow-kit-bundle/flow-kit/reference/check-path-privacy.sh" 2>&1); _rev_rc=$?;
    cd "$_cwd" || exit 1;
    [ "$_rev_rc" -eq 1 ] || { printf '%s\n' "$_rev_out"; echo "🔴 CHECK_REV 漏检：仅存在于历史树里的泄漏未判红（rc=$_rev_rc）"; exit 1; };
    printf '%s' "$_rev_out" | grep -q '扫描面' || { printf '%s\n' "$_rev_out"; echo "🔴 自证行未报出扫描面（工作树/rev 评估面无法区分）"; exit 1; };
    printf '%s' "$_rev_out" | grep -q 'leak.txt' || { printf '%s\n' "$_rev_out"; echo "🔴 rev 模式未给出 file:line 归因"; exit 1; }
    # 排除粒度判别子（主 agent 2026-09-23 追加 · L-133）：占位符排除必须**逐命中**判定；
    # 「真名在前、占位在后」同行时不得整行跳过（D10′② 漏报类），清一色占位符行必须判绿。
    _mix=$(mktemp -d /tmp/t17-ph-XXXXXX); trap 'rm -rf "$_sbx2" "$_mix"' EXIT;
    mkdir -p "$_mix/flow-kit-bundle/flow-kit/reference";
    cp "$S" "$_mix/flow-kit-bundle/flow-kit/reference/";
    : > "$_mix/flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt";
    ( cd "$_mix" && git init -q . && git config user.email t@t && git config user.name t \
      && printf 'mixed %s %s\n' "/home/$(whoami)/x" "/home/user/y" > mixed.txt \
      && printf 'phonly %s\n' "/home/user/y" > ph.txt \
      && git add -A && git commit -qm mix );
    _mix_out=$( cd "$_mix" && bash "./flow-kit-bundle/flow-kit/reference/check-path-privacy.sh" 2>&1 ); _mix_rc=$?;
    [ "$_mix_rc" -eq 1 ] || { printf '%s\n' "$_mix_out"; echo "🔴 同真名+占位同行被整行放过（排除粒度 ≠ 命中粒度 · L-133）"; cd "$_cwd"; exit 1; };
    printf '%s' "$_mix_out" | grep -q 'mixed.txt' || { printf '%s\n' "$_mix_out"; echo "🔴 同行真名未被 file:line 归因"; cd "$_cwd"; exit 1; };
    ( cd "$_mix" && git rm -q mixed.txt && git commit -qm phonly );
    _ph_out=$( cd "$_mix" && bash "./flow-kit-bundle/flow-kit/reference/check-path-privacy.sh" 2>&1 ); _ph_rc=$?;
    [ "$_ph_rc" -eq 0 ] || { printf '%s\n' "$_ph_out"; echo "🔴 清一色占位符行被误判为泄漏（rc=$_ph_rc）⇒ 排除表失效"; cd "$_cwd"; exit 1; };
    rm -rf "$_mix"
    # 自证行格式判别子（主 agent 2026-09-23 追加）：`grep -c` 计数为 0 时退出码为 1，
    # 写成 `$(grep -c … || printf '0')` 会把 '0' 打成两行 ⇒ 自证行在零计数态被折断。
    printf '%s' "$_ph_out" | grep -qE '^   允许清单 [0-9]+ 条$' || { printf '%s\n' "$_ph_out"; echo "🔴 自证行「允许清单 N 条」在零计数态被折断（应为单行）"; cd "$_cwd"; exit 1; };
    printf '%s' "$_ph_out" | grep -qE '^   命中合计 [0-9]+ 条（含占位符排除后）$' || { printf '%s\n' "$_ph_out"; echo "🔴 自证行「命中合计 N 条」在零计数态被折断（应为单行）"; cd "$_cwd"; exit 1; };
    printf '%s' "$_mix_out" | grep -qE '^   命中合计 1 条（含占位符排除后）$' || { printf '%s\n' "$_mix_out"; echo "🔴 非零计数态自证行格式不符"; cd "$_cwd"; exit 1; };
  </verify>
  <done>AC-6：门禁脚本落地且**清单缺失时 fail-closed**（rc=1 并指名缺失路径）、排除表逐条精确且无 bash4/GNU-only 构造；并支持 `CHECK_REV=<rev>` 外部评估面（缺省扫工作树；rev 模式下评估面是该 rev 的树，自证行报出扫描面）；**修复轮 1 + 2** 后（L-133 逐命中占位符判定 · L-134 自证行零计数态单行化）：脚本 297 行、sha256 `33d34d90…`、判据 54 行（含自证行格式判别子）原样跑 rc=0；主 agent 额外验证 `CHECK_REV` 的轻量 tag / 附注 tag / 分支 / sha 四形态解析与未解析 ref 的 fail-closed（`扫描面: …（未解析）`）〔2026-09-23 主 agent 订正：清单缺失态断言改为「两份清单皆缺」夹具（原断言在 T21 冻结常设清单后恒红，属判据陈旧而非门禁回归），判据 54→61 行〕</done>
  <depends_on>T13</depends_on>
</task>

<task id="T18" parallel="true" status="done" model-tier="cheap">
  <name>AC-6 接入：`Makefile` 目标 `check-path-privacy` + 纳入 `check:` 先决条件</name>
  <read_files>
    <`Makefile`（:5 .PHONY / :106 check: 先决条件行 / 既有 :33 lint / :95 check-hooks-sync 写法）>
    <`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`（T17 产物）>
    <`.specs/health-fix-2026-09b/DESIGN.md`（§1 D8 F2 交接：NFR 判据另立 `check-nfr-portability`，**不得**混入本目标）>
  </read_files>
  <write_files>
    <`Makefile`>
  </write_files>
  <action>
    新增 `check-path-privacy` 目标（调用 `check-path-privacy.sh`），并追加为 `check:` 先决条件；`.PHONY` 同步登记。
    本目标为**二值**（0/1），**不得**引入 `rc=3`（make 对非零一律判失败 ⇒ 长期红，ADR-027②）。
  </action>
  <verify>
    make -n check-path-privacy >/dev/null 2>&1 || { echo "🔴 目标不存在或依赖缺失"; exit 1; };
    make -n check | grep -q 'check-path-privacy' || { echo "🔴 未接入 make check"; exit 1; };
    grep -q 'check-path-privacy' Makefile || { echo "🔴 Makefile 未登记目标"; exit 1; };
    # 主 agent 2026-09-23 补（L-121/L-123）：正例（目标真的调用脚本）＋ .PHONY 登记 ＋ 退出码二值
    make -n check-path-privacy | grep -q 'check-path-privacy\.sh' || { echo "🔴 干跑无脚本路径：目标未真正调用 check-path-privacy.sh"; exit 1; };
    grep -E '^\.PHONY:' Makefile | grep -qw 'check-path-privacy' || { echo "🔴 .PHONY 未登记 check-path-privacy（同名文件存在时 recipe 会被跳过 ⇒ 假绿）"; exit 1; };
    # 主 agent 2026-09-23 修正（GNU make 对任何失败 recipe 恒返回 rc=2 ⇒ 原判据不可满足）：
    # 「二值退出」是**脚本**契约 ⇒ 直接调用脚本断言；make 侧只断言 0（成功）/ 2（recipe 失败），
    # 并加**反掩蔽**判别：脚本失败时 make 不得返回 0（否则说明接线写了 `|| true`）。
    _script=flow-kit-bundle/flow-kit/reference/check-path-privacy.sh;
    _rc=0; bash "$_script" >/dev/null 2>&1 || _rc=$?;
    case "$_rc" in 0|1) ;; *) echo "🔴 脚本退出码非二值（rc=$_rc；AC-6 要求 0/1，禁 SKIP/rc=3）"; exit 1;; esac
    _mk=0; make check-path-privacy >/dev/null 2>&1 || _mk=$?;
    case "$_mk" in 0|2) ;; *) echo "🔴 make 目标退出码异常（rc=$_mk；GNU make 对 recipe 失败恒返回 2）"; exit 1;; esac
    if [ "$_rc" -ne 0 ] && [ "$_mk" -eq 0 ]; then echo "🔴 脚本失败但 make 返回 0 ⇒ 接线掩盖了失败（禁 || true）"; exit 1; fi
  </verify>
  <done>AC-6①：`make -n check-path-privacy` 成功、`make -n check` 先决条件含 `check-path-privacy`（修复前实测：两者 `make -n check | grep` 均 rc=1）；`.PHONY` 已登记、干跑含脚本路径、退出码二值（仅 0/1）</done>
  <depends_on>T17</depends_on>
</task>

<task id="T19" parallel="false" status="done" model-tier="top">
  <name>AC-3 端到端：四形态 push 拦截 + 干净 ref 放行（隔离 bare remote 实跑）</name>
  <read_files>
    <`flow-kit-bundle/hooks/pre-push/pre-push.sh`（T11 · 次序语义：先逐 ref 评估并指名，后跑 `make check`）>
    <`flow-kit-bundle/lib/install_hooks.sh`（T16 部署实现）>
    <`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`（T17 · 夹具须复制**真实**实现）>
    <`flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt`（T21 · 夹具须复制**已冻结**权威清单）>
    <`.specs/health-fix-2026-09b/REQUIREMENT.md`（AC-3 When①②③④ + 假设 1/2：`origin/develop`=534e3e8、main 与 develop 无共同祖先）>
    <`.specs/health-fix-2026-09b/MINOR-DEFERRED.md`（C7：干净 clone 复现属 v2 —— v1 只验四形态被拦 / 干净 ref 放行）>
  </read_files>
  <write_files>
    <（无仓内文件：仅执行 + `/tmp` 沙箱 fixture；沙箱内 `$SBX/repo`（`Makefile` **桩** + 复制的真实门禁脚本与已冻结清单）与 `$SBX/remote.git`）>
  </write_files>
  <action>
    在隔离环境（临时 bare remote + 夹具仓库）逐条实跑四种 push 形态：① `git push origin main`（单 ref）② `git push --all`
    ③ `git push --mirror` ④ `git push --tags`；断言**含泄漏的 ref 被拒**且**报文指名该 ref**；
    再对不含泄漏的干净 ref（`develop`）推送**必须放行**（防止把干净 ref 一并拦死 ⇒ 会被绕过或关闭，NFR「精准」）。
    `--dry-run` 形态亦可（L2 已实测三种形态均会调用 `pre-push` 且 stdin 收到 ref）。
    **夹具前提（阶段 3 L3 C1 订正 · 缺一则本 task 恒红）**：pre-push 会先逐 ref 评估、再跑 `make check`（含
    `check-path-privacy`），故夹具必须是**可执行门禁的流式工作树**：自带 `Makefile` **桩**（`check:` → `check-path-privacy:` → 调用
    **真实**的 `check-path-privacy.sh`）+ 复制的**真实**门禁脚本与**已冻结**权威清单（均取自本项目树）；`make check` 走真实仓内目标属 T18 的职责。
    **分支拓扑**：`develop` 为干净分支（先建）；`main` 为**孤儿**分支（与 develop 无共同祖先）⇒ 推送 develop 不会带走 main 的泄漏提交。
    **归因对照**：摘掉 hook 后同一泄漏 push 必须成功（证明拦截确由 hook 产生，而非夹具自身故障）。
    **边界**：「干净 clone 复现」属 v2（MINOR-DEFERRED C7），本 task 不承担。
  </action>
  <verify>
    ROOT=$(git rev-parse --show-toplevel); SBX=$(mktemp -d /tmp/l3-ac3-XXXXXX); mkdir -p "$SBX/home";
    git init -q --bare "$SBX/remote.git"; git init -q "$SBX/repo"; cd "$SBX/repo";
    git config user.email t@t; git config user.name t;
    mkdir -p flow-kit-bundle/flow-kit/reference;
    cp "$ROOT/flow-kit-bundle/flow-kit/reference/check-path-privacy.sh" flow-kit-bundle/flow-kit/reference/ || { echo "🔴 夹具前提缺失：门禁脚本不存在（T17 未完成）"; exit 1; };
    cp "$ROOT/flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt" flow-kit-bundle/flow-kit/reference/ || { echo "🔴 夹具前提缺失：权威清单未冻结（T21 未完成）"; exit 1; };
    printf 'check: check-path-privacy\ncheck-path-privacy:\n\tbash flow-kit-bundle/flow-kit/reference/check-path-privacy.sh\n' > Makefile;
    git checkout -qb develop; printf 'clean\n' > clean.txt; git add -A; git commit -qm "clean fixture";
    make check-path-privacy || { echo "🔴 夹具自检失败：桩在干净态未通过（判据不可信 · L-122/L-123）"; exit 1; };
    git checkout -q --orphan main; git rm -q -rf . >/dev/null 2>&1 || true; git checkout -q develop -- Makefile flow-kit-bundle;
    printf '/home/%s/leak\n' "$(whoami)" > leak.txt; git add -A; git commit -qm leak; git tag v1;
    if make check-path-privacy; then echo "🔴 夹具自检失败：桩在泄漏态未转红（判据不可信）"; exit 1; fi;
    HOME="$SBX/home" bash "$ROOT/flow-kit-bundle/install.sh" --project "$SBX/repo" --no-brooks >/dev/null 2>&1 || true;
    [ -e .git/hooks/pre-push ] || { echo "🔴 pre-push 未部署到夹具（T16 未完成）"; exit 1; };
    git remote add origin "$SBX/remote.git";
    for form in "push origin main" "push --all" "push --mirror"; do
      rc=0; out=$(git $form 2>&1) || rc=$?;
      [ "$rc" -ne 0 ] || { printf '%s\n' "$out"; echo "🔴 形态 [$form] 未被拦截（rc=$rc）"; exit 1; };
      printf '%s' "$out" | grep -qE '(^|[^[:alnum:]_])main([^[:alnum:]_]|$)' || { printf '%s\n' "$out"; echo "🔴 形态 [$form] 未指名泄漏 ref（main）"; exit 1; };
    done;
    rc=0; out=$(git push origin --tags 2>&1) || rc=$?;
    [ "$rc" -ne 0 ] || { printf '%s\n' "$out"; echo "🔴 形态 [push --tags] 未被拦截（rc=$rc）"; exit 1; };
    printf '%s' "$out" | grep -qE '(^|[^[:alnum:]_])v1([^[:alnum:]_]|$)' || { printf '%s\n' "$out"; echo "🔴 形态 [push --tags] 未指名泄漏 ref（v1）"; exit 1; };
    # 评估面判别子（主 agent 2026-09-23 补 · L-131）：工作树干净时，泄漏仅在 main 的历史树里 ⇒ 仍须被拒且指名 main
    git checkout -q develop;
    rc=0; out=$(git push --all 2>&1) || rc=$?;
    [ "$rc" -ne 0 ] || { printf '%s\n' "$out"; echo "🔴 工作树干净时泄漏分支被放行（评估面错位：扫了工作树而非被推送的树）"; exit 1; };
    printf '%s' "$out" | grep -qE '(^|[^[:alnum:]_])main([^[:alnum:]_]|$)' || { printf '%s\n' "$out"; echo "🔴 工作树干净时未指名 main（归因错位）"; exit 1; };
    mv .git/hooks/pre-push "$SBX/pre-push.off"; rc_off=0; git push origin main >/dev/null 2>&1 || rc_off=$?; mv "$SBX/pre-push.off" .git/hooks/pre-push;
    [ "$rc_off" -eq 0 ] || { echo "🔴 归因对照失败：摘掉 hook 后泄漏 push 仍 rc=$rc_off（拦截来源不明）"; exit 1; };
    git -C "$SBX/remote.git" update-ref -d refs/heads/main 2>/dev/null || true;
    git checkout -q develop; git push origin develop || { echo "🔴 干净 ref（develop）被误拦"; exit 1; };
    git -C "$SBX/remote.git" rev-parse --verify --quiet refs/heads/develop >/dev/null || { echo "🔴 干净 ref 未真正到达远端"; exit 1; }
    # 严格模式（`set -euo pipefail`）安全（L3 第 3 轮 major 4 · TD-057）：凡**期望非零**的调用一律
    # 以 `rc=0; out=$(cmd 2>&1) || rc=$?`（或 `rc_x=0; cmd || rc_x=$?`）捕获，禁止 `out=$(cmd); rc=$?`
    # —— 后者在 `set -e` 下于赋值处静默早退（rc=1 且无任何报文），与真红态不可区分。
  </verify>
  <done>AC-3：四种 push 形态下含泄漏的 ref 被拒且**报文指名该 ref**（`main` / `v1`）、**摘掉 hook 的归因对照**证明拦截确由 hook 产生、干净 ref 放行并真正到达远端（夹具自带 `Makefile` 桩 + 真实门禁脚本 + 已冻结权威清单，且桩在干净态绿/泄漏态红已自检）；四形态的失败分支均**打印实际报文**（可区分「hook 未拦截」与「其它 git 错误」）（修复前：无 pre-push 拦截 ⇒ 全部放行）；并有评估面判别子（HEAD=develop、工作树无泄漏时 `git push --all` 仍须被拒且指名 `main`）</done>
  <depends_on>T11, T12, T16, T17, T18, T21, T22, T23, T26</depends_on>
</task>

<task id="T20" parallel="true" status="done" model-tier="cheap">
  <name>AC-6③：pre-commit **仓库内源**接入 `check-path-privacy`</name>
  <read_files>
    <`flow-kit-bundle/hooks/pre-commit/pre-commit.sh`（32L · 现内容只有 `make test`）>
    <`sync-hooks.sh`（:136 collect_rel_paths 的镜像清单已含 `pre-commit/pre-commit.sh`）>
    <`.specs/health-fix-2026-09b/REQUIREMENT.md`（AC-6 ③ · L2 C2：禁止断言仓外 symlink `$(readlink -f .git/hooks/pre-commit)`）>
  </read_files>
  <write_files>
    <`flow-kit-bundle/hooks/pre-commit/pre-commit.sh`>
  </write_files>
  <action>
    在**仓库内源** `flow-kit-bundle/hooks/pre-commit/pre-commit.sh` 中接入 `make check-path-privacy`（在既有 `make test` 之后；
    失败必须阻塞提交）。**禁止**改用仓外 symlink 目标作断言对象（干净 clone 上假红）。
    维持 hook 的快速失败语义与既有注释风格；改完**必须** `./sync-hooks.sh` 同步（本文件属镜像面），`sync-hooks.sh --check` 与 `make check-hooks-sync` 必须 rc=0。
    **次序硬约束（主 agent 2026-09-23 订正 · 原排期自锁）**：本仓 `.git/hooks/pre-commit` 是 `~/.claude/hooks/pre-commit/pre-commit.sh` 的 symlink
    ⇒ 本 task 落地的**同一刻**（同步后）本仓每次提交都会跑新门禁。若门禁此时为红，后续**所有** task 都无法提交、本 task 自己也提交不了
    （`--no-verify` 已禁）⇒ 必须在权威清单已冻结、干净树上 `make check-path-privacy` 已绿之后才执行（`depends_on` 已补 `T21, T22, T23`；ADR-027②）。
  </action>
  <verify>
    grep -q 'check-path-privacy' flow-kit-bundle/hooks/pre-commit/pre-commit.sh || { echo "🔴 pre-commit 源未接入"; exit 1; };
    bash -n flow-kit-bundle/hooks/pre-commit/pre-commit.sh || exit 1;
    bash sync-hooks.sh --check || { echo "🔴 副本漂移"; exit 1; }
  </verify>
  <done>AC-6③：pre-commit 仓库内源已接入新门禁且副本一致（修复前实测：`grep -cE 'path|隐私|leak'` 命中 0）</done>
  <depends_on>T17, T18, T21, T22, T23</depends_on>
</task>

<task id="T21" parallel="true" status="done" model-tier="top">
  <name>R8 落地 + AC-6 基线冻结：常设权威清单 + change 副本 + 读序双态（L2 第 7 轮 handoff ①）</name>
  <read_files>
    <`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`（T17 的读序实现）>
    <`.specs/health-fix-2026-09b/DESIGN.md`（§5 R8 定级裁决 = ①+② 组合 + 双态 verify 原文；D10′ 四步冻结顺序）>
    <`.specs/health-fix-2026-09b/REQUIREMENT.md`（AC-6② 三条断言 + 基线生成命令 + L3 major1 的依赖缺口声明）>
    <`.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-2.md`（末段 L3 #4 major② 的 fix 原文）>
  </read_files>
  <write_files>
    <`flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt`（**常设权威副本** · 新增产物）>
    <`.specs/health-fix-2026-09b/path-privacy-allowlist.txt`（change 窗口**副本** · 新增产物）>
  </write_files>
  <action>
    按 D10′③ 四步顺序执行（缺一不可）：① 确认 T13 已完成（脱敏）；② `git add` 全部工件（未 tracked 时扫描恒为 0 ⇒ 会冻结出**假基线**）；
    ③ 复扫断言「非排除命中 = 0」——**非 0 即中止、禁止冻结**；④ 冻结基线并落档**两份**：
    权威副本 `flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt`（不受 `.specs/archive/` 归档影响）+ change 窗口副本 `.specs/health-fix-2026-09b/path-privacy-allowlist.txt`。
    清单条目格式 `file:token`，每条附接受理由注释；**只降不升**（R3 棘轮）。
    生成命令（REQUIREMENT 原文形态）：`make check-path-privacy | grep -oE '[^ ]+:[0-9]+' | sort -u > <清单>`，随后逐条人工复核；
    **空清单在本 change 是合法且预期**的终态（D10 三态实测：排除占位符后基线条目数 = 0）——但「空」必须由「工件已脱敏」保证（T13），不是靠放宽判据。
  </action>
  <verify>
    export LC_ALL=C; A=flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt; B=.specs/health-fix-2026-09b/path-privacy-allowlist.txt;
    test -f "$A" || { echo "🔴 常设权威清单未落档"; exit 1; }; test -f "$B" || { echo "🔴 change 副本未落档"; exit 1; };
    make check-path-privacy || { echo "🔴 清单在位时门禁未通过"; exit 1; };
    printed=$(make check-path-privacy | grep -oE '允许清单 [0-9]+ 条' | grep -oE '[0-9]+');
    filed=$(grep -cvE '^[[:space:]]*(#|$)' "$A");
    echo "自报=$printed / 常设有效行=$filed";
    [ "$printed" = "$filed" ] || { echo "🔴 自报条数($printed) ≠ 落档行数($filed)：门禁可能未真读清单"; exit 1; };
    make check-path-privacy | grep -qE '清单外命中 0 条' || { echo "🔴 存在清单外命中"; exit 1; };
    trap 'mv -f /tmp/r8-bak1 "$A" 2>/dev/null; mv -f /tmp/r8-bak2 "$B" 2>/dev/null' EXIT;
    mv "$A" /tmp/r8-bak1; mv "$B" /tmp/r8-bak2;
    out=$(bash flow-kit-bundle/flow-kit/reference/check-path-privacy.sh 2>&1); rc=$?;
    mv -f /tmp/r8-bak1 "$A"; mv -f /tmp/r8-bak2 "$B";
    [ "$rc" -eq 1 ] || { echo "🔴 两份清单皆缺时 rc=$rc ≠ 1（fail-closed 未实现）"; exit 1; };
    printf '%s' "$out" | grep -q 'path-privacy-allowlist.txt' || { echo "🔴 缺清单报文未指名缺失路径"; exit 1; }
  </verify>
  <done>AC-6②+R8：常设权威清单与 change 副本均落档、健康态 rc=0、自报条数=落档行数、`清单外命中 0 条`，且**两份皆缺 ⇒ rc=1 并指名缺失路径**（双态）</done>
  <depends_on>T17, T18</depends_on>
</task>

<task id="T22" parallel="true" status="done" model-tier="top">
  <name>空基线自检（L3 #4 major②）：清单为空时的判据行为固化为双态断言</name>
  <read_files>
    <`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`（T17/T21 后的清单读取与判据分支）>
    <`flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt`（可能为 0 条）>
    <`.specs/health-fix-2026-09b/DESIGN.md`（D10 三态实测 + R1 缓解列「与 D10 的关系」）>
    <`.specs/health-fix-2026-09b/REQUIREMENT.md`（AC-6 ② 的 N8 订正：del 非空断言、量词用 `[0-9]+`）>
    <`.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-2.md`（末段 L3 #4 major② fix 原文：双态自检断言文本）>
  </read_files>
  <write_files>
    <`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`（固化空基线分支与输出文案；不新增门禁）>
  </write_files>
  <action>
    把「**清单为空 ⇒ 合法且 rc=0**（自报 `允许清单 0 条`、`清单外命中 0 条`）」与「**存在清单外命中 ⇒ rc=1**」两态固化为判据并写进脚本注释；
    **空清单不得被当作错误、也不得静默跳过扫描**。补双态自检：以**拼接构造**的畸形探针（不可与既有占位符同形）注入
    ⇒ 必须 rc=1；注入 `/home/<user>/` 形态 ⇒ 必须 rc=0（`<` 不在字符类内 ⇒ 不命中）。
    探针写入必须**先备份、失败分支亦先恢复**（D4：不得把探针留在 tracked 文件中）。
  </action>
  <verify>
    export LC_ALL=C; ex=0;
    make check-path-privacy | grep -qE '允许清单 [0-9]+ 条' || { echo "🔴 未自报条数（量词须容空清单）"; exit 1; };
    make check-path-privacy | grep -qE '清单外命中 0 条' || { echo "🔴 健康态非零命中"; exit 1; };
    PROBE='/home/''zz-path-pr''obe/';
    printf '%s\n' "$PROBE" | grep -qE '/home/[a-z_][a-z0-9_-]*/' || { echo "🔴 探针形态自检失败"; exit 1; };
    cp .specs/CONTEXT.md /tmp/probe-bak; trap 'cp -f /tmp/probe-bak .specs/CONTEXT.md 2>/dev/null' EXIT;
    printf '\n<!-- probe: %s -->\n' "$PROBE" >> .specs/CONTEXT.md;
    if make check-path-privacy >/dev/null 2>&1; then cp -f /tmp/probe-bak .specs/CONTEXT.md; echo "🔴 未抓住真实形态探针"; exit 1; fi;
    cp -f /tmp/probe-bak .specs/CONTEXT.md;
    printf '\n<!-- probe: /home/<user>/ -->\n' >> .specs/CONTEXT.md;
    make check-path-privacy >/dev/null 2>&1 || { cp -f /tmp/probe-bak .specs/CONTEXT.md; echo "🔴 占位符形态被误命中（排除表失效）"; exit 1; };
    cp -f /tmp/probe-bak .specs/CONTEXT.md || { echo "🔴 探针恢复失败（tracked 文件残留；阶段 3 L3 minor：原 ex 恒为 0）"; exit 1; }
    # 排除粒度探针（主 agent 2026-09-23 追加 · L-133）：真名在前 + 占位在后同行 ⇒ 必红；清一色占位 ⇒ 必绿
    cp .specs/CONTEXT.md /tmp/l133-bak; trap 'cp -f /tmp/l133-bak .specs/CONTEXT.md 2>/dev/null' EXIT;
    printf '<!-- mixed: %s %s -->\n' "/home/$(whoami)/x" "/home/user/y" >> .specs/CONTEXT.md;
    if make check-path-privacy >/tmp/l133-a.out 2>&1; then cp -f /tmp/l133-bak .specs/CONTEXT.md; cat /tmp/l133-a.out; echo "🔴 同行真名+占位被整行放过（排除粒度 ≠ 命中粒度 · L-133）"; exit 1; fi;
    grep -q 'CONTEXT.md' /tmp/l133-a.out || { cp -f /tmp/l133-bak .specs/CONTEXT.md; cat /tmp/l133-a.out; echo "🔴 同行真名未被 file:line 归因"; exit 1; };
    cp -f /tmp/l133-bak .specs/CONTEXT.md;
    make check-path-privacy >/dev/null 2>&1 || { cp -f /tmp/l133-bak .specs/CONTEXT.md; echo "🔴 恢复后非健康态（探针未清干净）"; exit 1; };
    cmp -s .specs/CONTEXT.md /tmp/l133-bak || { echo "🔴 恢复后与备份不一致（tracked 文件残留）"; exit 1; }
  </verify>
  <done>AC-6（空基线自检）：空清单态 rc=0 且自报 `允许清单 N 条`（N 可为 0）；真实形态探针 ⇒ rc=1；`/home/<user>/` ⇒ rc=0；探针在所有分支均已恢复</done>
  <depends_on>T21</depends_on>
</task>

<task id="T23" parallel="false" status="done" model-tier="top">
  <name>常设清单自身校验（L3 #4 major③）：格式 / 完整性 / 原子更新 + 排除表绑定双态</name>
  <read_files>
    <`.specs/adr/028-gate-baseline-allowlist.md`（棘轮与 SKIP≠PASS 语义；本 task 追加自校验规则）>
    <`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`（清单读取与排除表实现）>
    <`flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt`>
    <`.specs/health-fix-2026-09b/DESIGN.md`（§5 R3 允许清单腐化缓解 + D8 自排除边界三条）>
    <`.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-2.md`（末段 L3 #4 major③ fix 原文）>
  </read_files>
  <write_files>
    <`.specs/adr/028-gate-baseline-allowlist.md`>
    <`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`（补清单格式校验与排除表绑定断言）>
    <`flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt`（**受控临时写入**：畸形行注入 + 排除探针注入；先备份 → `trap … EXIT` 恢复 → 末段 `cmp -s` 逐字节断言。**常设基线，不得留任何残留** —— 阶段 3 L3 M4）>
    <`.specs/CONTEXT.md`（**受控临时写入**：排除面**外**探针注入；同一备份/恢复/`cmp -s` 纪律 —— 阶段 3 L3 M4）>
  </write_files>
  <action>
    在 ADR-028 追加「常设清单自校验规则」：① **格式校验**（每非注释行必须匹配 `file:token` 语法，违者 rc=1 并指名行号）；
    ② **内容校验**（入库时记录校验和或 git blob 引用，变更须可见）；③ **更新流程**（`mktemp` + `mv` 原子写 + REVIEW 阶段说明「为何这条残留被接受」）；
    ④ 棘轮**只降不升**。并在门禁中确保**排除表与清单路径绑定有双态断言**：
    清单内**注入探针**不得被自身判据误命中（排除生效），清单路径**外**注入必须命中（排除未过度放宽）。
  </action>
  <verify>
    AD=.specs/adr/028-gate-baseline-allowlist.md; S=flow-kit-bundle/flow-kit/reference/check-path-privacy.sh; A=flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt;
    grep -qE 'file:token|格式校验' "$AD" || { echo "🔴 ADR-028 未补清单格式校验规则"; exit 1; };
    grep -qE '原子|mktemp' "$AD" || { echo "🔴 ADR-028 未补原子更新流程"; exit 1; };
    grep -q 'path-privacy-allowlist.txt' "$S" || { echo "🔴 门禁未绑定常设清单路径"; exit 1; };
    cp "$A" /tmp/al-fmt-bak; cp .specs/CONTEXT.md /tmp/al-probe-bak;
    trap 'cp -f /tmp/al-probe-bak .specs/CONTEXT.md 2>/dev/null; cp -f /tmp/al-fmt-bak "$A" 2>/dev/null' EXIT;   # M4：trap 必须在**首次写入之前**安装
    printf 'ZZ-BAD-LINE-NO-COLON\n' >> "$A";
    out=$(make check-path-privacy 2>&1); rc=$?;
    if [ "$rc" -eq 0 ]; then cp -f /tmp/al-fmt-bak "$A"; echo "🔴 畸形清单行未被拒绝"; exit 1; fi;
    printf '%s' "$out" | grep -qE 'path-privacy-allowlist\.txt' || { cp -f /tmp/al-fmt-bak "$A"; printf '%s\n' "$out"; echo "🔴 畸形行的失败报文未指名清单路径"; exit 1; };
    printf '%s' "$out" | grep -qE ':[0-9]+:|[0-9]+ ?行|ZZ-BAD-LINE-NO-COLON' || { cp -f /tmp/al-fmt-bak "$A"; printf '%s\n' "$out"; echo "🔴 畸形行的失败报文未指名行号或内容（ADR-028 自校验规则）"; exit 1; };
    cp -f /tmp/al-fmt-bak "$A";
    exclude_probe(){ printf '<!-- probe: %s -->\n' '/home/''zz-path-pr''obe/'; };
    exclude_probe >> "$A"; make check-path-privacy >/dev/null 2>&1 || { cp -f /tmp/al-fmt-bak "$A"; echo "🔴 清单/排除路径内探针被自身判据误命中（排除失效）"; exit 1; };
    cp -f /tmp/al-fmt-bak "$A";
    exclude_probe >> .specs/CONTEXT.md;
    make check-path-privacy >/dev/null 2>&1 && { cp -f /tmp/al-probe-bak .specs/CONTEXT.md; echo "🔴 排除过度放宽（路径外探针未命中）"; exit 1; };
    cp -f /tmp/al-probe-bak .specs/CONTEXT.md;
    cmp -s "$A" /tmp/al-fmt-bak || { echo "🔴 常设权威清单未按备份逐字节恢复 ⇒ 基线被污染（阶段 3 L3 M4）"; exit 1; };
    cmp -s .specs/CONTEXT.md /tmp/al-probe-bak || { echo "🔴 CONTEXT.md 探针未按备份逐字节恢复（阶段 3 L3 M4）"; exit 1; }
  </verify>
  <done>AC-6 常设清单自校验：格式违例被拒、清单/排除路径内探针不被自身判据误命中、排除路径外探针必须命中、ADR-028 载明原子更新与棘轮约束</done>
  <depends_on>T21, T22</depends_on>
</task>

<task id="T24" parallel="true" status="done" model-tier="standard">
  <name>分发件处置（D4）：重建 `0.2.0`、删除可注入的 `0.1.0`</name>
  <read_files>
    <`package-dsh-plugin.sh`（只读 · 无参数即构建，`TARBALL="$DIST_DIR/dsh-flow-kit-${VERSION}.tgz"`；**不在禁动清单**）>
    <`Makefile`（:122 `check-dist` = 只读校验）>
    <`.specs/health-fix-2026-09b/DESIGN.md`（§1 D4 裁决 + §1 D9「只改源头不重建等于没修」）>
    <`.specs/health-fix-2026-09b/REQUIREMENT.md`（AC-1④ 归档面 + AC-5 npm 包面 + L2 C4「归档此前无任何门禁」）>
  </read_files>
  <write_files>
    <`dist/dsh-flow-kit-0.2.0.tgz`（重建 · 构建产物，dist/ 被 gitignore）>
    <`dist/dsh-flow-kit-0.1.0.tgz`（**删除** —— 保留未重建的旧版本等于继续分发可注入件）>
    <`dist/dsh-flow-kit/`（构建产物目录 · 由打包路径刷新）>
  </write_files>
  <action>
    源修复（T05/T07/T11/T12/T16）全部落地后执行 `bash package-dsh-plugin.sh` 重建归档；
    删除 `dist/dsh-flow-kit-0.1.0.tgz`（该档从未发布、无兼容义务 ⇒ 保留即留一个**已知可注入**的发布件）。
    **禁止**手工编辑 `.tgz` 内文件（必须经打包路径产出，保证 staging 与源同源）。
    **次序硬约束（主 agent 2026-09-23 订正）**：`check-dist` 逐文件比对 bundle 源与 `dist/` ⇒ 任何**之后**的 bundle 源改动都会让它重新转红
    ⇒ 本次重建必须是**最后一个改动源面的步骤**（`depends_on` 已补 `T20, T25, T26`）；若之后仍有源改动，须重跑本 task 的构建与判据。
  </action>
  <verify>
    export LC_ALL=C;
    [ -f dist/dsh-flow-kit-0.2.0.tgz ] || { echo "🔴 0.2.0 未重建"; exit 1; };
    [ ! -e dist/dsh-flow-kit-0.1.0.tgz ] || { echo "🔴 可注入的旧归档仍在（须删除）"; exit 1; };
    tar tzf dist/dsh-flow-kit-0.2.0.tgz >/dev/null 2>&1 || { echo "🔴 归档不可解析"; exit 1; };
    # 归档内容同源（阶段 3 L3 m10）：仅断言「eval-echo=0 / chisel=0」不足以证明归档含修复后的拦截器
    pre=$(tar tzf dist/dsh-flow-kit-0.2.0.tgz | grep -E '(^|/)hooks/pre-push/pre-push\.sh$' || true);
    printf '%s' "$pre" | grep -qx 'dsh-flow-kit/vendor/flow-kit-bundle/hooks/pre-push/pre-push.sh' || { echo "🔴 归档缺 vendored pre-push（sync-hooks 的 dist DEST_ROOT 未登记新 hook ⇒ 分发件无拦截器）"; exit 1; };
    printf '%s' "$pre" | grep -qx 'dsh-flow-kit/hooks/pre-push/pre-push.sh' || echo "ℹ️ 归档顶层 hooks/ 无 pre-push（package-flow-kit.sh 的 Part C 无该 stanza；该文件不在本 change 写面 ⇒ 已登记 TD-048，vendored 副本仍覆盖安装器路径）";
    for p in $pre; do
      tar xzOf dist/dsh-flow-kit-0.2.0.tgz "$p" | grep -q 'make check' || { echo "🔴 归档内 $p 未含 make check（与源树脱节）"; exit 1; };
      m=$(tar tvzf dist/dsh-flow-kit-0.2.0.tgz | awk -v p="$p" '$NF==p {print $1}');
      case "$m" in -rwxr-xr-x|-rwxr-x---) : ;; *) { echo "🔴 归档内 $p 非可执行（mode=$m）"; exit 1; } ;; esac;
    done;
    echo "归档内 pre-push 成员：$(printf '%s' "$pre" | tr '\n' ' ')";
    n=$(tar xzOf dist/dsh-flow-kit-0.2.0.tgz | grep -acE '\$\([[:space:]]*eval[[:space:]]');
    echo "0.2.0: eval-echo=$n"; [ "$n" -eq 0 ] || { echo "🔴 归档仍含可注入 hook"; exit 1; };
    c=$(tar xzOf dist/dsh-flow-kit-0.2.0.tgz | grep -ac chisel);
    echo "0.2.0: chisel=$c"; [ "$c" -eq 0 ] || { echo "🔴 归档仍含内部项目名"; exit 1; }
  </verify>
  <done>AC-1④ + AC-5：重建后的归档 `eval-echo=0` / `chisel=0`，且可注入的 `0.1.0` 已删除（修复前实测：0.1.0=2 处 eval-echo、0.2.0=2 处 eval-echo + 6 处 chisel）；**主 agent 复核**（2026-09-24 · 十项 + 活性探针）：归档内两个 pre-push 成员（顶层 + vendored）sha256 **均 ==** 源 `581237c2…d0c9`（即含 T11 修复轮 1 的版本）、判据 18 行原样实跑 rc=0、假 `0.1.0` ⇒ `🔴 可注入的旧归档仍在（须删除）`、移走 `0.2.0` ⇒ `🔴 0.2.0 未重建`（复原后 `cmp` 逐字节一致）；`check-dist` 红已由本次重建收口 ⇒ **T24 = PASS（`fix_rounds=0`）**</done>
  <depends_on>T05, T07, T11, T12, T16, T20, T25, T26</depends_on>
</task>

<task id="T25" parallel="true" status="done" model-tier="standard">
  <name>AC-1 副本面收口：`sync-hooks.sh` 同步 6 个 DEST_ROOT + 哨兵 PoC drive 已安装副本</name>
  <read_files>
    <`flow-kit-bundle/hooks/pre-tool-use/runtime-edit-guard.sh`（T05 修复版）>
    <`sync-hooks.sh`（--list 枚举 / --check 校验 / --entry-class）>
    <`.specs/health-fix-2026-09b/REQUIREMENT.md`（AC-1 验证方式全段：6 面枚举禁手列、bash3.2 兼容数组累加、vendored 守卫、哨兵法）>
    <`.specs/health-fix-2026-09b/DESIGN.md`（§0.5.2「沿用 sync-hooks.sh --list/--check，禁手列路径」，实测手列会漏 2 个 DEST_ROOT）>
  </read_files>
  <write_files>
    <6 个 DEST_ROOT 副本面（由 `bash sync-hooks.sh` 写入；路径**以 `--list` 的 ✅ 行为准**，禁止手工编辑副本）>
    <哨兵测试的**执行对象** = 本机部署副本 `$HOME/.claude/hooks/pre-tool-use/runtime-edit-guard.sh`；verify 断言它在 `--list` 的 6 个 DEST_ROOT 之内且真实存在，并断言其 rc ∈ {0,2}（守卫未跑 ⇒ 判据不可信 —— 阶段 3 L3 M6）>
  </write_files>
  <action>
    执行 `bash sync-hooks.sh` 把修复后的 hook 同步到全部副本面，并以 `make check-hooks-sync` / `sync-hooks.sh --check` 验证 6 面零漂移。
    再用**哨兵法**驱动**本机实际执行的那一份**（`~/.claude/hooks/pre-tool-use/runtime-edit-guard.sh`）：
    载荷 `file_path='$(touch <哨兵>)~/.claude/hooks/x.sh'` ⇒ 运行后哨兵文件**不得存在**。
    面数一律由 `sync-hooks.sh --list` 的 ✅ 行枚举（手列会漏 `~/.dsh/profiles/web/node_modules/dsh-flow-kit/hooks` 与 `.../vendor/flow-kit-bundle/hooks`）。
  </action>
  <verify>
    export LC_ALL=C; PAT='\$\([[:space:]]*eval[[:space:]]';
    bash sync-hooks.sh || { echo "🔴 sync-hooks.sh 失败"; exit 1; };
    make check-hooks-sync || { echo "🔴 副本面未同步"; exit 1; };
    DESTS=(); while IFS= read -r d; do DESTS+=("$d"); done < <(bash sync-hooks.sh --list | grep -E '✅' | awk '{print $2}');
    [ "${#DESTS[@]}" -eq 6 ] || { echo "🔴 副本面枚举数=${#DESTS[@]} ≠ 6（枚举失效，判据不可信）"; exit 1; };
    n=$(for d in "${DESTS[@]}"; do grep -rEn "$PAT" "$d"; done | wc -l);
    [ "$n" -eq 0 ] || { echo "🔴 副本面仍有 eval-echo=$n"; exit 1; };
    GUARD="$HOME/.claude/hooks/pre-tool-use/runtime-edit-guard.sh";
    printf '%s\n' "${DESTS[@]}" | grep -qx "$HOME/.claude/hooks" || { echo "🔴 本机 hooks 面不在 sync-hooks.sh 的 DEST_ROOT 枚举内（哨兵测试对象不明 ⇒ 假绿风险 · 阶段 3 L3 M6）"; exit 1; };
    [ -f "$GUARD" ] || { echo "🔴 $GUARD 不存在：哨兵测试无从执行 ⇒ 原 `|| true` 会把「守卫根本没跑」当成通过（阶段 3 L3 M6）"; exit 1; };
    S=/tmp/FLOWKIT_SENTINEL_$$; rm -f "$S";
    printf '{"tool_name":"Edit","tool_input":{"file_path":"$(touch %s)~/.claude/hooks/x.sh"}}' "$S" | bash "$GUARD" >/dev/null 2>&1; grc=$?;
    case "$grc" in 0|2) : ;; *) { echo "🔴 守卫未按契约执行（rc=$grc，期望 0=放行 / 2=拒绝）⇒ 哨兵断言不可信（阶段 3 L3 M6）"; exit 1; } ;; esac;
    test ! -e "$S" || { echo "🔴 载荷中的命令被执行（RCE 仍在）"; exit 1; }
  </verify>
  <done>AC-1①（副本面）：6 个 DEST_ROOT 的 `eval-echo` 归零、`make check-hooks-sync` rc=0、哨兵未落盘（修复前实测：源树 1 + 6 副本面各 1 = 7）</done>
  <depends_on>T05</depends_on>
</task>

<task id="T26" parallel="true" status="done" model-tier="top">
  <name>AC-6 端到端判据：探针必须被抓住 + 自报↔落档绑定 + 差分数（防硬编码）</name>
  <read_files>
    <`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`（T17/T21/T22/T23 定稿）>
    <`flow-kit-bundle/hooks/pre-commit/pre-commit.sh`（T20）>
    <`.specs/health-fix-2026-09b/path-privacy-allowlist.txt`、`flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt`>
    <`.specs/health-fix-2026-09b/REQUIREMENT.md`（AC-6 全段：探针拼接构造 R1 订正、--list 不可用、F4 差分数、自证式输出）>
  </read_files>
  <write_files>
    <`.specs/CONTEXT.md`（探针**临时**写入，成功/失败分支均须先恢复；授权 = AC-6① 的判据协议）>
    <`flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt`（差分探针 ④a **临时**追加后恢复；这是对 **T21 冻结产物**的**受控改写**：先备份 → 失败分支亦恢复 → 恢复后须与备份**逐字节一致**（verify 以 `cmp -s` 断言）；恢复失败 ⇒ 中止并升级。权威 · 读序第一）>
    <`.specs/health-fix-2026-09b/path-privacy-allowlist.txt`（④b **临时移位**后恢复；副本 · 读序第二）>
  </write_files>
  <action>
    逐条实跑 AC-6 的端到端判据：① 探针（**拼接构造** `'/home/''zz-path-pr''obe/'`，禁 `/home/<user>` 形态）注入 tracked 文件 ⇒ **必须 fail 并指名该文件路径**；
    ② 健康态 rc=0；③ `允许清单 N 条` 必须与**落档文件有效行数**绑定；④ **差分数（防硬编码 · 读序双态 · 阶段 3 L3 M2 订正）**：④a 向**权威**清单（读序第一，DESIGN:79）追加一条 ⇒ 自报条数必须增大；④b **移走权威清单**而副本仍在位 ⇒ 门禁必须 rc=0（若按「两份皆缺」处理则 rc=1，两态不可区分 ⇒ 读序未实现）。原判据只追加 **change 副本**，在「常设 > 副本」读序下自报条数**永不可能**增大（判据恒红）；④b 的判别力与 T21 已断言的「两份皆缺 ⇒ rc=1」配套成立；
    ⑤ `清单外命中 0 条`；⑥ pre-commit 源接入断言 + `sync-hooks.sh --check`。
    **所有会写 tracked 文件的步骤必须先备份、失败分支亦先恢复**（D4）；**恢复后必须与备份逐字节一致**（verify 末段以 `cmp -s` 对 CONTEXT.md / 权威清单 / change 副本三者断言）；恢复失败 ⇒ 打印 🔴 并**中止**（不得继续后续断言、不得把临时探针留在常设基线上）。对权威清单（T21 冻结产物）的改写属**受控临时改写**，仅存在于 ④a / ④b 两态探针期间 —— 阶段 3 L3 major①。
  </action>
  <verify>
    export LC_ALL=C;
    make --help | grep -qw -- '--always-make' || { echo "🔴 原语自检失败：正例未命中"; exit 1; };
    rc=0; make -n check-path-privacy >/dev/null 2>&1 || rc=$?;
    case "$rc" in 0) : ;; 2) echo "ℹ️ make -n rc=2：目标不存在或依赖缺失（不得直判为合法）"; exit 1 ;; *) { echo "🔴 rc=$rc 非预期"; exit 1; } ;; esac;
    make -n check | grep -q 'check-path-privacy' || { echo "🔴 未接入 make check"; exit 1; };
    PROBE='/home/''zz-path-pr''obe/';
    printf '%s\n' "$PROBE" | grep -qE '/home/[a-z_][a-z0-9_-]*/' || { echo "🔴 探针形态自检失败"; exit 1; };
    AL2=flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt; AL=.specs/health-fix-2026-09b/path-privacy-allowlist.txt;
    cp .specs/CONTEXT.md /tmp/probe-bak; cp "$AL" /tmp/al-bak; cp "$AL2" /tmp/al2-bak;
    trap 'cp -f /tmp/probe-bak .specs/CONTEXT.md 2>/dev/null; cp -f /tmp/al-bak "$AL" 2>/dev/null; [ -f /tmp/al2-moved ] && mv -f /tmp/al2-moved "$AL2"; cp -f /tmp/al2-bak "$AL2" 2>/dev/null' EXIT;
    printf '\n<!-- probe: %s -->\n' "$PROBE" >> .specs/CONTEXT.md;
    if make check-path-privacy; then cp -f /tmp/probe-bak .specs/CONTEXT.md; echo "🔴 未抓住探针"; exit 1; fi;
    cp -f /tmp/probe-bak .specs/CONTEXT.md;
    make check-path-privacy || { echo "🔴 门禁自身在健康态未通过"; exit 1; };
    printed=$(make check-path-privacy | grep -oE '允许清单 [0-9]+ 条' | grep -oE '[0-9]+');
    filed=$(grep -cvE '^[[:space:]]*(#|$)' "$AL2");
    [ "$printed" = "$filed" ] || { echo "🔴 自报条数($printed) ≠ 权威清单有效行数($filed)"; exit 1; };
    printf '/home/''zz-path-pr''obe-differential/:1\n' >> "$AL2";
    n2=$(make check-path-privacy | grep -oE '允许清单 [0-9]+ 条' | grep -oE '[0-9]+') || true;
    cp -f /tmp/al2-bak "$AL2";
    [ "${n2:-0}" -gt "$printed" ] || { echo "🔴 ④a 改**权威**清单后自报条数未变（$printed→${n2:-0}）：门禁未真读清单"; exit 1; };
    mv "$AL2" /tmp/al2-moved;
    make check-path-privacy >/dev/null 2>&1 || { mv -f /tmp/al2-moved "$AL2"; echo "🔴 ④b 权威缺失 + 副本在位时 rc≠0（读序未实现：与「两份皆缺 ⇒ exit 1」不可区分）"; exit 1; };
    mv -f /tmp/al2-moved "$AL2";
    cmp -s "$AL2" /tmp/al2-bak || { echo "🔴 权威清单（T21 冻结产物）未按备份逐字节恢复 ⇒ 常设基线被污染"; exit 1; };
    cmp -s "$AL" /tmp/al-bak || { echo "🔴 change 副本未按备份逐字节恢复"; exit 1; };
    cmp -s .specs/CONTEXT.md /tmp/probe-bak || { echo "🔴 CONTEXT.md 探针未按备份逐字节恢复"; exit 1; };
    make check-path-privacy | grep -qE '清单外命中 0 条' || { echo "🔴 存在清单外命中"; exit 1; };
    grep -q 'check-path-privacy' flow-kit-bundle/hooks/pre-commit/pre-commit.sh || { echo "🔴 pre-commit 源未接入"; exit 1; };
    bash sync-hooks.sh --check || { echo "🔴 副本漂移"; exit 1; }
  </verify>
  <done>AC-6①：探针必被抓住并指名文件、健康态 rc=0、自报条数与**权威**清单有效行数绑定、**④a** 改权威清单后自报随之变化、**④b** 权威缺失+副本在位 ⇒ rc=0（读序两态与 T21 的「皆缺 ⇒ rc=1」配套）、`清单外命中 0 条`、pre-commit 源已接入</done>
  <depends_on>T18, T21</depends_on>
</task>

<task id="T27" parallel="true" status="done" model-tier="standard">
  <name>分发件复扫（AC-1④ + AC-5）：归档逐文件、禁通配、计数非 0 必须非零退出</name>
  <read_files>
    <`dist/dsh-flow-kit-0.2.0.tgz`（T24 重建）>
    <`.specs/health-fix-2026-09b/REQUIREMENT.md`（AC-1 ④ 归档面段 + AC-5 验证方式 L2 R2「为何禁通配」+ L2 N3「判据必须能失败」）>
    <`Makefile`（:122 check-dist · 只读、不重建）>
  </read_files>
  <write_files>
    <（无仓内文件：只读扫描 `dist/` 与 `test/`；若发现残留 ⇒ 回到 T24/T07 修复，不在本 task 就地改件）>
  </write_files>
  <action>
    对**每个**归档逐文件循环（`for f in dist/dsh-flow-kit-*.tgz`，**禁**把通配直接交给 `tar`——两个归档时 tar 会把第二个当成员名、rc=2、stdout 空 ⇒ 构造性假绿），
    先证归档可解析，再断言两件事：`$(eval echo …)` 计数 = 0、`chisel` 计数 = 0；**计数非 0 必须退出非零**（只 echo 不断言 = 恒绿）。
    另跑 `npx bats test/` 证不退化。
  </action>
  <verify>
    export LC_ALL=C; fail=0;   # 仅归档扫描段需要 C 地域（排序/计数确定性）
    shopt -s nullglob; ARCHIVES=(dist/dsh-flow-kit-*.tgz); shopt -u nullglob;
    [ "${#ARCHIVES[@]}" -gt 0 ] || { echo "🔴 未匹配到任何归档（glob 失效，判据不可信）"; exit 1; };
    for t in "${ARCHIVES[@]}"; do
      tar tzf "$t" >/dev/null 2>&1 || { echo "🔴 归档不可解析: $t"; exit 1; };
      n=$(tar xzOf "$t" | grep -acE '\$\([[:space:]]*eval[[:space:]]'); echo "$t: eval-echo=$n";
      [ "$n" -eq 0 ] || fail=1;
      c=$(tar xzOf "$t" | grep -ac chisel); echo "$t: chisel=$c";
      [ "$c" -eq 0 ] || fail=1;
    done;
    [ "$fail" -eq 0 ] || { echo "🔴 分发件仍有可注入 hook 或内部项目名"; exit 1; };
    hits=$(grep -rn chisel test/ flow-kit-bundle/test/ 2>/dev/null || true);
    [ -z "$hits" ] || { printf '%s\n' "$hits" | head -10; echo "🔴 源测试仍含 chisel（命中如上，file:line —— 阶段 3 L3 m11：原写法只报一句、不给定位）"; exit 1; };
    unset LC_ALL; [ -n "${LANG:-}" ] || export LANG=C.UTF-8;   # 主 agent 裁决 2026-09-24（L-146）：LC_ALL=C 不得泄漏进 bats 子进程 —— glibc iconv 在 LC_CTYPE=C 下拒绝合法多字节 UTF-8（`test/test_l3_pipeline_fix.bats:609` 的 `iconv -f utf-8 -o /dev/null` 目标字符集取自 locale）⇒ 环境脏导致的假红，非产品回归；对应登记 TD-051
    outf=$(mktemp); npx bats test/ --formatter tap > "$outf" 2>&1; b_rc=$?;
    b_ok=$(grep -cE '^ok [0-9]+' "$outf"); b_no=$(grep -cE '^not ok [0-9]+' "$outf");
    echo "bats: rc=$b_rc ok=$b_ok not-ok=$b_no（当前基线 2026-09-24 T-FIX-02 收口实测 rc=0 / 1012 ok / 0 not ok，skip 计入 ok 行；地板 = 基线 − 3）";
    grep -E '^not ok [0-9]+' "$outf" | head -5; rm -f "$outf";
    { [ "$b_rc" -eq 0 ] && [ "$b_no" -eq 0 ] && [ "$b_ok" -ge 1009 ]; } || { echo "🔴 bats 回归（rc=$b_rc not-ok=$b_no ok=$b_ok）"; exit 1; }
  </verify>
  <done>AC-1①（归档面）+ AC-5①：逐个归档 `eval-echo=0` / `chisel=0` 且非 0 时判据必须非零退出；源测试 0 命中；bats 不退化 = TAP 行断言 `^not ok` 计数 0 且 `^ok` 计数 ≥ 973 且 rc=0（基线 2026-09-24 T29 收口实测 976 ok / 0 not ok；修复前实测：两档各 2 处 eval-echo、0.2.0 六处 chisel）；**判据作用域修复（主 agent · L-146 · TD-051）**：首版 `<verify>` 的 `export LC_ALL=C` 泄漏进 `npx bats` ⇒ 环境脏导致的假红（`test/test_l3_pipeline_fix.bats:609` 的 `iconv -f utf-8 -o /dev/null` 目标字符集取自 locale），已收窄作用域并回写本工件 ⇒ 判据 rc=0、`bats: rc=0 ok=976 not-ok=0`〔主 agent 复核 2026-09-24 · 十项 + 活性探针〕；**判据地板订正（主 agent 2026-09-24 · 阶段 5 重入）**：`^ok` 地板 **973 → 1009**（= 当前基线 1012 − 3，与原 976/973 同余量；原地板按 976 标定，TD-053/T-FIX-01/02 后基线已 1012，旧地板允许 39 例静默消失 ⇒ 回归网被削弱）。仅改地板数字与 echo 描述串，断言结构与判据步骤未改。</done>
  <depends_on>T24</depends_on>
</task>

<task id="T28" parallel="true" status="done" model-tier="top">
  <name>NFR 兼容性判据落点：`Makefile` 目标 `check-nfr-portability`（三态，`rc=3` 不得当绿灯）</name>
  <read_files>
    <`Makefile`（接入点；本目标为 recipe 内联，**不落 `.sh`** —— A 案受检面是 `*.sh` 新增行，落 .sh 会自命中永久假红）>
    <`.specs/health-fix-2026-09b/DESIGN.md`（§1 D8 的 F2 交接裁决 + §3 退出码模型 + §9.3 包装契约）>
    <`.specs/health-fix-2026-09b/REQUIREMENT.md`（NFR 兼容性判据全文：A 案受检面 = 新增行 + 新文件、豁免按成分删除、`exit 3` = SKIP）>
    <`.specs/health-fix-2026-09b/.change-base`（T02 锚点）>
  </read_files>
  <write_files>
    <`Makefile`（新增 `check-nfr-portability` 目标 + `.PHONY` 登记）>
  </write_files>
  <action>
    以 `Makefile` **recipe 内联**承载该判据（不落 `.sh`、不放 gitignored 的 `tools/`）：
    受检面 = 相对 `.change-base` 锚点的**新增行 + 新 `.sh` 文件**；注释行剔除；合规惯用法按**成分删除**后再匹配
    （`stat -c … || stat -f …` 不得判红，但同行其他违规不得逃逸）；禁 `declare -A`/`mapfile`/`readarray`/`readlink -f|-e`/`realpath`/`sed -i`/`grep -P`/`find -printf`/GNU `timeout`；
    对「被修改文件 + 新增文件」整文件 `bash -n`。
    **退出码语义（ADR-028 + DESIGN §9.3）**：内部判据 `0` = 通过；`1` = 失败（指名 `file:line`）；**`3` = 未验证（SKIP）** ——
    包装 recipe 对 `3` 的处理是「打印 `SKIP: …` 到 stdout 后 `exit 0`」：在 `make check` 里**非阻塞但必须可见**（SKIP ≠ PASS）；`rc=3` **不得**直接挂进 `check:` 先决条件（否则常态长期红）。
    verify 之所以要求「`rc=0` **且输出不含 `SKIP:`**」：该判据已先自证锚点在位、变更集非空 —— 此时出现 SKIP 只可能来自实现缺陷 ⇒ 判红是**判据的正确行为**（与 T29 的分工：T28 管目标级、T29 管 AC-8 全局；两者判据同源同向 —— 阶段 3 L3 M7）。
  </action>
  <verify>
    make -n check-nfr-portability >/dev/null 2>&1 || { echo "🔴 目标不存在"; exit 1; };
    BASE="${FLOW_KIT_CHANGE_BASE:-$(cat .specs/health-fix-2026-09b/.change-base 2>/dev/null || true)}";
    [ -n "$BASE" ] || { echo "🔴 变更起点锚点未落档"; exit 1; };
    git -c core.quotepath=false rev-parse --verify --quiet "${BASE}^{commit}" >/dev/null || { echo "🔴 锚点非法"; exit 1; };
    ADDED=$(git -c core.quotepath=false diff -U0 "$BASE" -- '*.sh' | grep -E '^\+' | grep -v '^+++' || true);
    NEWF=$(git -c core.quotepath=false ls-files -o --exclude-standard | grep -E '\.sh$' || true);
    [ -n "$ADDED$NEWF" ] || echo "ℹ️ 变更集为空（相对锚点 $BASE）⇒ NFR 判据将在空集上恒真并返回 rc=3；本处**不判失败**（AC-8 全局非空守卫在 T29），由下方 rc 分支裁决（SKIP ≠ PASS）";
    NFR_OUT=$(mktemp); rc=0; make check-nfr-portability >"$NFR_OUT" 2>&1 || rc=$?;
    case "$rc" in
      0) : ;;
      1) { head -20 "$NFR_OUT"; echo "🔴 check-nfr-portability rc=1：落地后的变更集存在违规新增行（阶段 3 L3 M3：原判据把 1 与 0 并列当通过）"; exit 1; } ;;
      *) { head -20 "$NFR_OUT"; echo "🔴 rc=$rc 与 DESIGN §9.3 的三态包装不符（内部 rc=3 应由包装映射为「打印 SKIP: 后 exit 0」；泄漏 rc=3 = 实现偏离设计 —— 阶段 3 L3 M7）"; exit 1; } ;;
    esac;
    grep -q 'SKIP:' "$NFR_OUT" && { head -5 "$NFR_OUT"; echo "🔴 出现 SKIP：本判据已自证锚点在位（BASE=$BASE）⇒ 判据未真正运行；SKIP ≠ PASS（DESIGN §9.3 的 AC-8 断言 —— 阶段 3 L3 M7）"; exit 1; };
    rm -f "$NFR_OUT";
    make -n check 2>/dev/null | grep -q 'check-nfr-portability' || { echo "🔴 check-nfr-portability 未接入 make check（AC-8 要求在 make check 中可见；阶段 3 L3 major）"; exit 1; }
  </verify>
  <done>AC-8 的 NFR 侧：判据落点为 `Makefile` 目标（不落 `.sh` ⇒ 无自命中）、**rc=0 且输出不含 `SKIP:` 才通过**（rc=1 = 违规 ⇒ 非零退出；`SKIP:` 出现 ⇒ 判据未真正运行 ⇒ 非零退出，SKIP ≠ PASS；rc=3 泄漏 ⇒ 与 DESIGN §9.3 的包装语义不符 ⇒ 非零退出）、`make check` 接入可见；空集只作 ℹ️ 诊断（**不另设非空守卫** —— 全局 AC-8 非空守卫在 T29）。修复前：`case "$rc" in 0|1) : ;;` 把 rc=1 当通过 —— 阶段 3 L3 M3；语义与 DESIGN §9.3 对齐 + SKIP 可见性断言 —— 阶段 3 L3 M7；**修复轮 1 + 2**（2026-09-24 · L-145）：失败归因从「拼接流偏移量」改为真实 `file:line`（tracked 逐文件解析 `git diff -U0` 新侧行号 / untracked 补 `file:` 前缀），并恢复 untracked 分支的整行注释剔除（保住真实行号）⇒ 主 agent 探针矩阵全过、`fix_rounds=2`、`commit_sha` 保持 `649a2ee`〔主 agent 复核 · 十项 + 修复轮 1/2〕</done>
  <depends_on>T02, T18</depends_on>
</task>

<task id="T29" parallel="false" status="done" model-tier="top">
  <name>AC-8 收口：全量质量门禁无退化 + 变更集非空守卫</name>
  <read_files>
    <`Makefile`（最终 `check:` 组成：原有 6 项 + `check-gate-sync` + `check-path-privacy`）>
    <`.specs/health-fix-2026-09b/REQUIREMENT.md`（AC-8 全段含 L3 minor2 的 `rc=3` 处理）>
    <`.specs/health-fix-2026-09b/DESIGN.md`（§5 R6 覆盖度声明；§9.3 契约）>
    <`.specs/health-fix-2026-09b/MINOR-DEFERRED.md`（已知未闭环项，禁止当成新缺陷重报）>
  </read_files>
  <write_files>
    <（无仓内文件：只跑门禁与全量 bats；失败 ⇒ 回到对应 task 修复）>
  </write_files>
  <action>
    跑全量质量门禁并留档：`make check` 全绿（含两道新门禁）、`npx bats test/` ≥ **1009 ok / 0 not ok**（地板 = 基线 1012 − 3）、
    `check-test-sync` / `check-hooks-sync` / `check-dist` 仍 0 漂移。
    **必须显式处理 NFR 兼容性判据的三态**：变更集为空时它以 `exit 3`（SKIP）呈现 —— **不得把 SKIP 当绿灯**，
    故先用 `.change-base` 锚点断言变更集非空（守卫与 A 案同锚点）。
  </action>
  <verify>
    # L-146 / TD-051（主 agent 裁决 2026-09-24）：本判据**不得**导出 LC_ALL=C —— 它会污染 `make check`（内部 `make test`）与末尾 `npx bats` 子进程（glibc iconv 在 LC_CTYPE=C 下拒绝合法多字节 UTF-8，`test/test_l3_pipeline_fix.bats:609`）⇒ 环境脏导致的假红；确需 C 地域的单条命令请用前缀式 `LC_ALL=C cmd …`。
    # C3：先证「两门禁已接线」再跑 make check —— 否则 T14/T18 未完成时 make check 会在**旧门禁集**上全绿（AC-8「无退化」被架空）
    make -n check 2>/dev/null | grep -q 'check-gate-sync' || { echo "🔴 check-gate-sync 未接入 make check（T14 未完成 ⇒ 全绿不含其实质）"; exit 1; };
    make -n check 2>/dev/null | grep -q 'check-path-privacy' || { echo "🔴 check-path-privacy 未接入 make check（T18 未完成 ⇒ 全绿不含其实质）"; exit 1; };
    make check || { echo "🔴 make check 未全绿"; exit 1; };
    outf=$(mktemp); npx bats test/ --formatter tap > "$outf" 2>&1; b_rc=$?;
    b_ok=$(grep -cE '^ok [0-9]+' "$outf"); b_no=$(grep -cE '^not ok [0-9]+' "$outf");
    echo "bats: rc=$b_rc ok=$b_ok not-ok=$b_no（当前基线 2026-09-24 T-FIX-02 收口实测 rc=0 / 1012 ok / 0 not ok；skip 计入 ok 行；地板 = 基线 − 3）";
    grep -E '^not ok [0-9]+' "$outf" | head -5; rm -f "$outf";
    { [ "$b_rc" -eq 0 ] && [ "$b_no" -eq 0 ] && [ "$b_ok" -ge 1009 ]; } || { echo "🔴 bats 回归（rc=$b_rc not-ok=$b_no ok=$b_ok）"; exit 1; };
    make check-test-sync >/dev/null && make check-hooks-sync >/dev/null && make check-dist >/dev/null || { echo "🔴 三道副本一致性门禁漂移"; exit 1; };
    BASE8="${FLOW_KIT_CHANGE_BASE:-$(cat .specs/health-fix-2026-09b/.change-base 2>/dev/null || true)}";
    [ -n "$BASE8" ] || { echo "🔴 AC-8：变更起点锚点未落档，无法判定变更集非空"; exit 1; };
    FILES=$( { git -c core.quotepath=false diff --name-only "$BASE8"; git -c core.quotepath=false ls-files -o --exclude-standard; } | grep -E '\.sh$' | sort -u );
    [ -n "$FILES" ] || { echo "🔴 AC-8 时点变更集为空（相对锚点 $BASE8）⇒ 兼容性判据 rc=3（未验证），不得当作通过"; exit 1; }
  </verify>
  <done>AC-8：`make check` 全绿、bats ≥973 ok / 0 not ok、三道副本一致性门禁 0 漂移、变更集非空（`rc=3` 未被当绿灯）；**时点实测（主 agent 复核 2026-09-24 · 十项 + 活性探针）**：判据自工件本体重抽 15 行原样实跑 rc=0（`make check` 全绿含新增三道门禁、`bats: rc=0 ok=976 not-ok=0`）、变更集非空守卫以 `FLOW_KIT_CHANGE_BASE=HEAD` 实测 rc=1（非恒绿）、四处陈旧口径订正均未改断言结构；`fix_rounds=0`、`commit_sha=88f7a0c`；**判据地板订正（主 agent 2026-09-24 · 阶段 5 重入）**：`^ok` 地板 **973 → 1009**（= 当前基线 1012 − 3，与原 976/973 同余量；原地板按 976 标定，TD-053/T-FIX-01/02 后基线已 1012，旧地板允许 39 例静默消失 ⇒ 回归网被削弱）。仅改地板数字与 echo 描述串，断言结构与判据步骤未改。</done>
  <depends_on>T08, T14, T15, T19, T20, T22, T23, T25, T26, T27, T28</depends_on>
</task>
```

> **注意**：`read_files` 和 `write_files` 是 R7.3 强约束。`write_files` 严格落在 DESIGN `## 0.5.1` 「触碰模块 + 新增产物」范围内，
> 且不含「禁动清单」文件。越界会被 4-dev 步骤 5 提交前 verify 拦下。本文件的逐条归属见下方「write_files 边界归属」。

---

## write_files 边界归属（逐条对 DESIGN §0.5.1）

| 被写路径 | §0.5.1 归属 | task |
|---|---|---|
| `flow-kit-bundle/hooks/pre-tool-use/runtime-edit-guard.sh` | 触碰模块（PC1） | T05 |
| `flow-kit-bundle/lib/install_hooks.sh` | 触碰模块（PC2 + AC-3/⑧ pre-push 部署触点） | T06, T16 |
| `.specs/adr/022-git-hook-deployment.md` | 触碰模块（R8 补列 · D3 item 3） | T03 |
| `flow-kit-bundle/hooks/stop/lib/l3-prompt.sh` | 触碰模块（CHANGE §4b 用户裁决并入） | T04 |
| `flow-kit-bundle/flow-kit/reference/check-gate-sync.sh` | 触碰模块（AR2） | T08 |
| `flow-kit-bundle/hooks/pre-commit/pre-commit.sh` | 触碰模块（AC-6） | T20 |
| `Makefile` | 触碰模块（接入两道新门禁） | T14, T18, T28 |
| `sync-hooks.sh` | 触碰模块（副本面枚举 / --check） | T12 |
| `test/test_check_gate_sync.bats` + `flow-kit-bundle/test/` 镜像 | 触碰模块（AR2 断言收紧） | T15 |
| `test/test_lessons_cleanup.bats` + 镜像 | 触碰模块（AC-7 去 skip） | T10 |
| `test/test_combined_metric.bats` + 镜像 | 触碰模块（AC-7 恒真断言） | T09 |
| `test/test_auto_checkpoint.bats` + 镜像 | 触碰模块（AC-7 断言错对象） | T09 |
| `test/test_independent_review_model.bats` + 镜像 | 触碰模块（AC-7 反向断言） | T10 |
| `test/test_correction_hygiene.bats` + 镜像 | 触碰模块（AC-5 必改） | T07 |
| `test/test_l3_review_defects_2026_09.bats` + 镜像 | 触碰模块（AC-5 必改） | T07 |
| `.specs/health-fix-2026-09b/path-privacy-allowlist.txt` | 新增产物（AC-6 冻结基线 · change 副本） | T21 |
| `flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt` | 新增产物（R8 定级裁决 · **常设权威副本**） | T21 |
| `flow-kit-bundle/flow-kit/reference/check-path-privacy.sh` | 新增产物（D8 选项③） | T17, T22, T23 |
| `flow-kit-bundle/hooks/pre-push/pre-push.sh` | 新增产物（N3 补列） | T11 |
| `.specs/health-fix-2026-09b/.change-base` | 新增产物（R1 第 6 轮补列） | T02 |

**显式例外（不在 §0.5.1 字面条目内，逐条给出授权来源）**：

| 被写路径 | 授权来源 |
|---|---|
| `.specs/health-fix-2026-09b/DESIGN.md` | `MINOR-DEFERRED` **C5** 的触发条件（本轮用户硬性要求 #5）+ DESIGN **D10′①③** 的工件脱敏（T01, T13） |
| `.specs/health-fix-2026-09b/REQUIREMENT.md` | DESIGN **D10′①**（同批工件脱敏；实测 1 处自造 fixture 字面）—— 仅字面替换，不改 AC 语义 |
| `.specs/health/2026-09-22-FULL-SWEEP.md` | DESIGN **D10′③** 明文「＋ 同批入库的 `.specs/health/*.md`」（实测 3 处真实账号路径） |
| `.specs/adr/028-gate-baseline-allowlist.md` | DESIGN §4 ADR 索引「本次新增」+ L3 重审 #4 **major③** 的 fix（补常设清单自校验规则）+ §5 R3 缓解 |
| `dist/dsh-flow-kit-0.2.0.tgz` / `dist/dsh-flow-kit-0.1.0.tgz`（删除）/ `dist/dsh-flow-kit/` | DESIGN **D4** 裁决（重建 0.2.0 / 删除 0.1.0）；`dist/` 被 gitignore，属构建产物而非 tracked 模块 |
| 6 个 DEST_ROOT 副本面 | AC-1 Then① 要求 + DESIGN §0.5.2「沿用 `sync-hooks.sh`」——由脚本写入，**禁止手工编辑副本** |
| `.specs/CONTEXT.md`（探针临时写入后恢复） | AC-6① 的判据协议原文（探针注入 + 恢复）；失败分支亦先恢复 |
| `/tmp/l3-*`、`/tmp/l2-ac2-*` 沙箱 fixture | 判据协议要求（NFR「会落盘的一律沙箱 `HOME`」；R2 风险缓解 ⑤），**仓库外**，不构成 write_files 越界 |
| `package-flow-kit.sh` | **TD-048**（用户裁决「授权在本 change 内修」· 2026-09-23）→ T11 修复轮 2 在 Part C 拷贝段补 `pre-push` stanza（实测 `:134-136`；越界面由 `MINOR-DEFERRED.md` 349 / 597 记录）。**L-031 第 2 类（DESIGN §0.5.1 漏列但已改，授权在先）**——L2 阶段 5 R8 要求回写本表以闭合审计链 |
| `flow-kit-bundle/lib/validate_staging.sh` | **TD-048 同源** → T11 修复轮 2 在覆盖清单补 `pre-push` 模式（实测 `:54`，+1/−1）。同属 L-031 第 2 类，授权来源与上一行一致 |

---

## Plan-Conflict Scan（3 类扫描 · 进自检前强制）

### ① TASK.md 内部一致性
- task id 唯一且**连续**：T01–T29，无重复、无跳号。
- `depends_on` 引用的 id 全部存在：T13→T01；T14/T15→T08；T16→T06,T12；T17→T13；T18→T17；T19→T11,T12,T16；T20→T17,T18；T21→T17,T18；T22→T21；T23→T21；T24→T05,T07,T11,T12,T16；T25→T05；T26→T18,T21；T27→T24；T28→T02,T18；T29→T19,T20,T22,T23,T25,T26,T27,T28（**全部存在**）。
- 依赖**无环**且与波次自洽：所有 `depends_on` 的目标 wave 均**严格小于**自身 wave。
- `parallel="true"` 之间无依赖：同 wave 内被依赖方均落在更早 wave；`[P]` 组内**无同文件并发写**（`Makefile` 的三次修改分处 T14(W3) / T18(W4) / T28(W6)；`install_hooks.sh` 的两次修改分处 T06(W2) / T16(W3)；`check-path-privacy.sh` 的三次修改分处 T17(W3) / T22(W5) / T23(W5)——**T22 与 T23 同 wave 且同写该文件 ⇒ 见下方冲突 ①-1**）。**T19 的变化（阶段 3 L3 M5）**：原在 W4 却 `depends_on` 含 T21（W5）—— 跨 wave 依赖不成立 ⇒ 移入 W6 串行，并把 T22/T23/T26 纳入 `depends_on`（夹具复制的是终稿脚本与已冻结清单）。
- `verify` 全部为**可直接执行的命令**（无描述性文字），且多数已在本机实测过「修复前必失败」的基线（见各 task 的 done 括注）。

**⚠️ 冲突 ①-1（T22 与 T23 同 wave 同写 `flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`）** —— 处置：**二者不得并行**。
修正：**T23 的 `depends_on` 增列 `T22`，并把 T23 标注为 `parallel="false"`**（同 wave 内串行）；T23 仍在 Wave 5，但其 `write_files` 中的脚本改动必须**先等 T22 落定**。
（该修正已写入上方任务清单：T23 `parallel="false"`、`depends_on` = `T21, T22`。）

### ② TASK.md vs `.specs/CONTEXT.md`「禁动清单」
CONTEXT.md 禁动清单原文命中的条目逐条核对：
- `package-flow-kit.sh` —— **T10 仅以 `bash package-flow-kit.sh --validate` 作为只读 SUT 调用（不写）**；**但该文件在 T11 修复轮 2 依 TD-048 用户裁决被写入**（Part C 补 `pre-push` stanza，`:134-136`）—— 已登记于上方「显式例外」表；`flow-kit-bundle/lib/validate_staging.sh:54` 同源例外。（L2 阶段 5 **R8** 指出本行旧文案「不在任何 write_files ✅」与实测 diff 矛盾，已订正）
- `flow-kit-bundle/lib/install_*.sh`（不允许外部直接 source）—— T06/T16 只改文件内容，**不新增外部 source 点**；T16 的沙箱验证走 `install.sh` 入口。✅
- `test/` 目录不允许放非 `.bats` 文件 —— 四个 bats 任务只改既有 `.bats`，不新增文件。✅
- `.flow-active.goal` 字段 / `RULES.md` R6/R3/R7 子段 / `~/.claude/tools/brooks-lint/node_modules/` / `~/.local/bin/*` shim / `regression-demos/*/check.sh` / `flow-kit-bundle.tar.gz` / `.gitignore` —— 均**未被任何 task 触碰**。✅
- `.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-*.md` —— **未出现在任何 write_files**（T13 的 action 显式声明契约边界；排除表按 D10′② 逐条精确路径豁免，**禁通配**）。✅

**⚠️ 冲突 ②-1（形式冲突）**：change 级禁动清单含 `flow-kit-bundle/hooks/stop/**`，而 T04 的 write_files 含 `flow-kit-bundle/hooks/stop/lib/l3-prompt.sh`。
**处置**：不视为越界 —— ① DESIGN §0.5.1 **触碰模块**列表已显式列入该文件并附用户裁决说明；② CHANGE.md **§4b 范围追加（用户裁决 · 2026-09-23）** 明确把该修复并入本 change；③ 该文件的改动只减少提示词噪声、不放宽任何判据（自我指涉披露）。**其余 `stop/**` 模块仍严格禁碰**（本 TASK 无任何其他 stop/ 路径）。

### ③ TASK.md vs 既有 ADR
- **ADR-022**（git hook 部署 = symlink → 已安装 hooks 目录）：T11/T16 **沿用**该机制，并由 T03 显式声明**部分** supersede（新增 pre-push 注入面），未静默推翻。✅
- **ADR-027**（门禁只保证看不见的变可见）：T17/T21 的阻塞面**仅限非允许清单命中**，清单内残留只暴露不阻塞；失败须指名 `file:line`。✅
- **ADR-028**（基线允许清单 + 三态退出码 + SKIP≠PASS）：T17/T18/T21/T22/T23 遵循二值门禁 + 棘轮 + 常设清单；NFR 判据（T28）独立用 `rc=3` 且**不挂进 `check:` 先决条件**。✅
- `.goal-snapshot.json`（仅 hook 有写权限）—— 未被触碰。✅
- `.flow-active` 字段必须用 `jq` 而非 `sed` —— 本 TASK 不写 `.flow-active`。✅
- 双 ADR 索引冲突（TD-041）：本 TASK 的 ADR 引用一律以 `.specs/adr/` 实有文件为准。✅
- `ADR-005` / `ADR-008`：**不改**（DESIGN §4 已声明）。✅

**结论：`⚠️ plan-conflict-scan 发现 1 处真实冲突（①-1，已就地修正为 T23 串行于 T22）+ 1 处形式冲突（②-1，已由 DESIGN §0.5.1 触碰模块 + CHANGE §4b 用户裁决消解）。`**

---

## 自检 7 项

| # | 检查项 | 结论 | 理由 |
|---|---|---|---|
| 1 | 7 字段齐（`id`/`name`/`read_files`/`write_files`/`action`/`verify`/`done`） | ✅ | T01–T29 每个 task 均含全部 7 字段；`write_files` 为空的 task（T19/T27/T29）显式写「（无仓内文件：…）」而非留白，避免被读成漏填 |
| 2 | 每个 `write_files` 严格在 DESIGN 触碰 + 新增范围内（B3 护栏） | ✅ | 见「write_files 边界归属」表：20 类路径逐条对到 §0.5.1；8 类例外逐条给出授权来源（C5 / D10′ / D4 / AC-1 / AC-6①），无「顺手碰」 |
| 3 | 无禁动清单文件 | ✅ | `hooks/stop/**`（除 §0.5.1 明确放行的 `stop/lib/l3-prompt.sh`）、`brooks-lint/**`、`pipeline-gates.md`、`skills/**`、`INDEPENDENT-REVIEW-*.md`、`package-flow-kit.sh`、`.gitignore`、`.flow-active` 均不在任何 write_files（冲突 ②-1 已显式裁决） |
| 4 | `verify` 可执行（不是描述性文字） | ✅ | 29 条 verify 全为 shell 命令；其中 17 条的关键原语已在本机实跑并留档「修复前必须失败」的基线（`.change-base` 缺失、`Superseded-by`=0、eval-echo=1/6、`deploy_pre_push`=0、`--entry-class` rc=2、`make -n check` 未接线、chisel 4 文件、恒真断言原文、`skip`=1、C5 计数 6/附录 0 等） |
| 5 | ≥1 个 `[P]` | ✅ | T01–T29 中 **26** 个 task 标 `parallel="true"`（T19 由 W4 移入 W6 串行 —— 跨 wave 依赖修正、T23 因与 T22 同写 `check-path-privacy.sh` 改为串行、T29 为收口串行），`[P]` 标记已写入波次图（Wave 5 / Wave 6 行的串行项另列） |
| 6 | 波次图清晰无环 | ✅ | 7 个 wave，跨 wave 单向递进；`depends_on` 的目标 wave 严格小于自身 wave（唯一同 wave 依赖 = T23→T22，已显式置 `parallel="false"`） |
| 7 | 编号连续 | ✅ | T01, T02, …, T29 连续无缺号；Fix 区预留 `T-FIX-XX`（来自 REVIEW / INTEGRATION）不在本阶段编号 |

---

## 状态字段说明

- `status="pending"` — 未开始
- `status="in_progress"` — 进行中（同时只允许一个非 `[P]` 任务为此状态）
- `status="done"` — 已完成（verify 通过）
- `status="blocked"` — 阻塞（必须在文件末尾「阻塞日志」记录）

---

## model-tier 字段说明（ADR-016）

- `model-tier="cheap"` — 1-2 文件 / 简单修改 / 类型 fix（本 TASK：T02, T03, T07, T14, T15, T18, T20）
- `model-tier="standard"` — 多文件 / 标准功能（本 TASK：T01, T04, T05, T06, T09, T10, T11, T12, T13, T16, T19, T24, T25, T27）
- `model-tier="top"` — 架构 / review / 复杂逻辑（本 TASK：T08, T17, T21, T22, T23, T26, T28, T29 —— 判据设计、门禁实现、基线冻结、自校验与全量收口）
- 缺省 → fallback `standard`（向后兼容）

---

## 阻塞日志

| 任务 | 阻塞原因 | 待人工决策项 | 时间 |
|---|---|---|---|
|  |  |  |  |

---

## Fix 任务（来自 REVIEW / INTEGRATION）

> 此区域由 review/integration 阶段自动追加，编号 `T-FIX-XX`。

> **本轮追加（2026-09-24 · 用户裁决 option 1）**：阶段 5 外部 L3 审查连续两轮 `fail`，
> 两条 major 属「实质性缺口」而非措辞 —— TD-053（三件生产件无常设回归网）、TD-059（阶段门对
> 「存在但无效」的完成标记放行）。用户裁决 = **回退 4-dev 产 fix 任务，两条都修后重跑阶段 5**。
> 编号沿用本节约定 `T-FIX-XX`，**不重排既有 wave**；两件均不改 AC-1..AC-8 的范围，
> 属「使既有交付可信」的置信度补强（对应 L3 第 7 轮 M1/M2 的 fix 选项）。

```xml
<task id="T-FIX-01" parallel="true" status="done" model-tier="top">
  <name>TD-053 常设回归网：三件生产件（check-path-privacy / runtime-edit-guard / NFR 三态判据）的双态 bats</name>
  <read_files>
    <`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`（392 行；清单读序 = 常设 > change 副本 > 皆缺 ⇒ rc=1 且指名缺失路径；空清单 ⇒ 继续扫描且 rc=0；清单外命中 ⇒ rc=1 且报文含 file:line；自证行 = 扫描面/允许清单来源/允许清单 N 条/命中合计/清单外命中）>
    <`flow-kit-bundle/hooks/pre-tool-use/runtime-edit-guard.sh`（123 行；stdin JSON `{tool_name,tool_input.file_path}`；Write/Edit 相对路径 / `~user` / 空串 ⇒ rc=2；非写工具 ⇒ rc=0；项目外或维护源缺失 ⇒ rc=0；`~/.claude/(hooks|skills)/` 且维护源在 ⇒ rc=2 + redirect 报文）>
    <`Makefile`（`:125` check-path-privacy · `:162` check-nfr-portability-internals 三态 rc∈{0,1,3} 经 `$NFR_RC_FILE` 回传 · `:247` 包装层 rc∈{0,1} 且把 3 映射为 `SKIP:` + exit 0 · `:71` test-sync · `:79` check-test-sync · `:346` check-dist）>
    <`test/done-validation.bats`（既有 bats 风格模板）· `.specs/CONTEXT.md`（TD-053 原文）· `.specs/health-fix-2026-09b/TEST.md`（§4.4 缺口三条）>
  </read_files>
  <write_files>
    <`test/test_path_privacy_gate.bats` · `test/test_runtime_edit_guard.bats` · `test/test_nfr_portability_gate.bats`（三件新增常设判据）>
    <`flow-kit-bundle/test/`（`make test-sync` 单向同步产物，随源一并提交；不手改）>
    <`dist/`（由 `bash package-dsh-plugin.sh` 重建，gitignored，不手改）>
    <`.specs/STATE.md`（测试计数基线 976 → 实测新值）>
  </write_files>
  <action>
    为三件「判定力只由 change 期判据承载」的生产件补**常设**回归网，每件至少一正一反双态：
    ① `test/test_path_privacy_gate.bats`（在隔离夹具里驱动**真实脚本**：`mktemp -d` + `git init` + 夹具内 `flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt` + `.specs/health-fix-2026-09b/`）：
    干净态 ⇒ rc=0 且自报 `清单外命中 0 条`；**拼接构造**的真名探针（`'/home/''zz-path-pr''obe/'`）⇒ rc=1 且输出含 `file:line`；两份清单皆缺 ⇒ rc=1 且报文指名缺失路径；空清单（0 条）⇒ rc=0 且自报 `允许清单 0 条`（空清单不得当错误、不得静默跳过扫描）；命中落在清单内 ⇒ rc=0；`/home/<user>/` 占位形态 ⇒ 不命中。
    ② `test/test_runtime_edit_guard.bats`（stdin JSON 驱动真实 hook）：相对路径 ⇒ rc=2 + 报文含「无法解析为绝对路径」；`~user/x` ⇒ rc=2；空 `file_path` ⇒ rc=2；非 Write/Edit（如 Bash/Read）⇒ rc=0；夹具内建 `flow-kit-bundle/hooks/stop/x.sh` 后写 `~/.claude/hooks/stop/x.sh` ⇒ rc=2 + 报文含「维护源在」；同路径但夹具内无维护源 ⇒ rc=0（fail-open 边界）。
    ③ `test/test_nfr_portability_gate.bats`（夹具仓 + 复制真实 `Makefile`，用 `FLOW_KIT_CHANGE_BASE=<sha>` 锚定）：相对锚点无 `.sh` 新增 ⇒ 内部 rc=3 且 stdout 含 `SKIP:`；新增 `.sh` 含 `sed -i` ⇒ 内部 rc=1 且 stderr 含 `file:line`；合规惯用法 `stat -c … || stat -f …` ⇒ 不误报（rc=0）；整行注释 `# sed -i` ⇒ 不误报；**包装层**把内部 3 映射为 exit 0 且 stdout 保留 `SKIP:`（SKIP ≠ PASS）。
    夹具一律建在 `${TMPDIR:-/tmp}`、用例内不触碰工作树；`check-path-privacy` 用例必须在运行时**复制当前脚本**进夹具（⇒ 源被改动时判据会转红，回归网是活的）。
    收尾：`make test-sync` ⇒ `npx bats test/` 记录新基线并写入 `.specs/STATE.md`；`bash package-dsh-plugin.sh` 重建 dist；`make check` 全绿；`make check-path-privacy` rc=0。
    提交：`git add` **显式列路径**（含 `flow-kit-bundle/test/` 同步产物）+ `git commit -m "test(health-fix-2026-09b): T-FIX-01 TD-053 常设回归网（三件生产件双态 bats）" -- <路径…>`；禁用 `git add .`/`-A`、`--no-verify`、`git stash`。
    提交后写 `.specs/health-fix-2026-09b/T-FIX-01-SUMMARY.md`（交付物 / 实跑输出原文 / 6 维自检 / 遗留），把本 task 的 `status="pending"` 改 `done` 并补 `<done>` 注记，并按 4-dev 协议用 `jq '.goal.task_progress += [{…}]'` 追加五字段（id/commit_sha/fix_rounds/deferred/completed_at）；SUMMARY 与 TASK.md 勾选留待主 agent 的 housekeeping 提交。
  </action>
  <verify>
    # 判据修复（主 agent 2026-09-24 · 证据见 MINOR-DEFERRED「T-FIX-01 判据修复」/ T-FIX-01-SUMMARY 遗留①）：
    # 原首行 `export LC_ALL=C` 会让**既有** test/test_l3_pipeline_fix.bats 的 UTF-8 边界用例
    # （`:592` 用例 / `:609` iconv）在 HEAD 即红（**已登记 TD-051** 的 locale 敏感性缺陷，非新开 TD），
    # 与本 task 交付物无关。已删除该 locale 覆盖（其余判据逐字不动），不改变任何断言强度。
    rc=0;
    F1=test/test_path_privacy_gate.bats; F2=test/test_runtime_edit_guard.bats; F3=test/test_nfr_portability_gate.bats;
    for f in $F1 $F2 $F3; do [ -f "$f" ] || { echo "🔴 缺常设判据文件 $f"; rc=1; }; done;
    [ $rc -eq 0 ] || exit 1;
    grep -q 'check-path-privacy.sh' $F1 || { echo "🔴 $F1 未驱动真实脚本"; rc=1; };
    grep -q 'runtime-edit-guard.sh' $F2 || { echo "🔴 $F2 未驱动真实 hook"; rc=1; };
    grep -q 'check-nfr-portability' $F3 || { echo "🔴 $F3 未驱动真实 target"; rc=1; };
    grep -qE 'status" -eq 2' $F2 || { echo "🔴 $F2 无拒绝态断言"; rc=1; };
    grep -qE 'status" -eq 0' $F2 || { echo "🔴 $F2 无放行态断言"; rc=1; };
    grep -qE 'status" -eq 1' $F1 || { echo "🔴 $F1 无拒绝态断言"; rc=1; };
    grep -qE 'status" -eq 3|NFR_RC' $F3 || { echo "🔴 $F3 无 rc=3（未验证）断言"; rc=1; };
    OUT=$(npx bats $F1 $F2 $F3 2>&1); brc=$?;
    OKC=$(printf '%s\n' "$OUT" | grep -c '^ok '); NOTOK=$(printf '%s\n' "$OUT" | grep -c '^not ok ');
    printf 'TAP: ok=%s not-ok=%s rc=%s\n' "$OKC" "$NOTOK" "$brc";
    [ $brc -eq 0 ] && [ "$NOTOK" -eq 0 ] && [ "$OKC" -ge 18 ] || { printf '%s\n' "$OUT" | tail -25; echo "🔴 常设网本体未全绿（下限 18，实得 $OKC）"; rc=1; };
    # 活性：把两件生产件打成恒绿桩 ⇒ 判据必须转红（fixture 运行时复制当前脚本 ⇒ 桩必被吃到）
    cp flow-kit-bundle/flow-kit/reference/check-path-privacy.sh /tmp/tfix1-pp.bak;
    cp flow-kit-bundle/hooks/pre-tool-use/runtime-edit-guard.sh /tmp/tfix1-reg.bak;
    printf '#!/bin/bash\nexit 0\n' > flow-kit-bundle/flow-kit/reference/check-path-privacy.sh;
    printf '#!/bin/bash\nexit 0\n' > flow-kit-bundle/hooks/pre-tool-use/runtime-edit-guard.sh;
    if npx bats $F1 $F2 > /tmp/tfix1-stub.out 2>&1; then echo "🔴 恒绿桩下判据仍绿 ⇒ 常设网非活性"; rc=1; fi;
    grep -q '^not ok' /tmp/tfix1-stub.out || { echo "🔴 桩下无 not ok 行"; rc=1; };
    cp -f /tmp/tfix1-pp.bak flow-kit-bundle/flow-kit/reference/check-path-privacy.sh;
    cp -f /tmp/tfix1-reg.bak flow-kit-bundle/hooks/pre-tool-use/runtime-edit-guard.sh;
    cmp -s flow-kit-bundle/flow-kit/reference/check-path-privacy.sh /tmp/tfix1-pp.bak || { echo "🔴 path-privacy 还原不一致"; rc=1; };
    cmp -s flow-kit-bundle/hooks/pre-tool-use/runtime-edit-guard.sh /tmp/tfix1-reg.bak || { echo "🔴 runtime-edit-guard 还原不一致"; rc=1; };
    npx bats $F1 $F2 > /dev/null 2>&1 || { echo "🔴 还原后未回绿"; rc=1; };
    make check-test-sync > /dev/null 2>&1 || { echo "🔴 test 双源不一致（未跑 make test-sync）"; rc=1; };
    make check-dist > /dev/null 2>&1 || { echo "🔴 dist 未重建（check-dist 失败）"; rc=1; };
    make check-path-privacy > /dev/null 2>&1 || { echo "🔴 check-path-privacy 不绿"; rc=1; };
    make check > /tmp/tfix1-check.out 2>&1 || { tail -20 /tmp/tfix1-check.out; echo "🔴 make check 不绿"; rc=1; };
    exit $rc
  </verify>
  <done>TD-053 收敛：三件生产件的判定力由 `test/` 树内的常设双态判据承载（path-privacy 6 态 / runtime-edit-guard 6 态 / NFR 三态 + 包装映射）；恒绿桩注入 ⇒ 判据转红（活性已证）；test 双源 + dist + `make check` 全绿；`.specs/STATE.md` 基线更新；**时点实测（T-FIX-01 执行者 2026-09-24）**：三文件 25 用例（F1 9 / F2 9 / F3 7）`1..25 · 0 not ok`；恒绿桩注入下 14 行 `not ok`（F1 九例全红 + F2 拒绝组全红 ⇒ 活性已证），`cmp` 还原一致后回绿；`npx bats test/` = 1001 ok / 0 not ok / 0 skip（`npx bats --count test/` = 1001，原 976 + 25）；`make check` 九门禁全绿（`✅ make check: 全部通过`）；`make test-sync` / `make check-test-sync` / `make check-dist` / `make check-path-privacy` 均 rc=0。**`<verify>` 原样跑 rc=1**：唯一红点 = 第 31 行 `make check`，根因是首行 `export LC_ALL=C` 与既有用例 `test/test_l3_pipeline_fix.bats:592` 冲突（LC_ALL=C 下 `not ok 646`，`:609` 的 `iconv: illegal input sequence at position 136`；宿主 `zh_CN.UTF-8` 与 `C.utf8` 下均绿，单文件隔离同样复现，工作树无任何生产件改动 ⇒ 预先存在，非本 task 引入）；最小偏离复跑（唯一差异：`export LC_ALL=C;` → `export LC_ALL=C.utf8;`，其余 31 行逐字不动）⇒ `rc=0` 全绿。详见 `.specs/health-fix-2026-09b/T-FIX-01-SUMMARY.md` ④ 偏离 ①；`fix_rounds=0`、`commit_sha=5ee4ebc`</done>
  <depends_on>T29</depends_on>
</task>

<task id="T-FIX-02" parallel="false" status="done" model-tier="top">
  <name>TD-059 阶段门有效性：完成标记「存在」不再等于「有效」（Gate3 语义 + ADR-029 + 双态 bats）</name>
  <read_files>
    <`flow-kit-bundle/hooks/stop/lib/done-validation.sh`（`:35 fk_independent_review_gate_active` 末行 `[[ ! -f "$done_marker" ]]` = 现行唯一判据；`:100 fk_validate_done_marker <done> <phase> <change_id> <write|transition>`；`:107-115` `phases_done` 短路；`MIN_MEANINGFUL_LINES=6`）>
    <`flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh`（`:76` Gate1 path-guard · `:91` Gate3 `_gate_active_check` · `:97` Gate4 `_gate_done_validation` · `:107` Gate7 `_gate_deny_reason`）>
    <`flow-kit-bundle/hooks/pre-tool-use/gate-helpers.sh`（`:174 _gate_active_check` return 0=门未开 ⇒ 放行 / 1=门开 ⇒ 继续；`:186 _gate_done_validation` 用 tier=transition）>
    <同一函数的其余调用点（语义必须一致）：`flow-kit-bundle/hooks/stop/29-independent-review.sh:104`（tier=L3）· `31-auto-advance.sh:73` · `lib/flow-kit-artifacts.sh:111`>
    <`.specs/adr/004-gate-return-value-semantics.md` · `005-gate-active-source-dependency.md`（ADR 写作范式与返回码契约）>
    <`.specs/health-fix-2026-09b/reproduce-phase-gate.sh`（阶段 5 沙箱：A/B/B2/B3/C 五层，B2/B3 现记「缺口实证」）>
    <`test/done-validation.bats` · `test/test_l2_l3_granular_gate.bats`（既有覆盖，修复后须同步订正且全绿）>
  </read_files>
  <write_files>
    <`flow-kit-bundle/hooks/stop/lib/done-validation.sh`（Gate3 语义 + 头部契约注释 `:24-34` 同步）>
    <`.specs/adr/029-gate-marker-validity.md`（新增）>
    <`test/test_review_gate_validity.bats`（新增 · 双态：空标记/缺键 ⇒ 拒；6 键有效 ⇒ 放行）>
    <`test/done-validation.bats` / `test/test_l2_l3_granular_gate.bats`（按新语义订正；不得削弱覆盖面）>
    <`.specs/CONTEXT.md`（TD-059 状态改为「本 change 内修复（T-FIX-02）」）>
    <`flow-kit-bundle/test/` + 6 个 hooks 副本（`make test-sync` / `bash sync-hooks.sh`）+ `dist/`（重建）>
  </write_files>
  <action>
    **最小语义修复**：`fk_independent_review_gate_active` 在标记**存在**时，必须调用 `fk_validate_done_marker "$done_marker" "$phase" "$change_id" transition` 判定有效性：无效 ⇒ 仍视为「gate 生效」（`return 0` ⇒ 拒绝）。**必须用 `transition` 而非 `write`**：只用 Tier-1 时，「6 键齐但 `L2_verdict` 与审查档 verdict 相悖」会被判有效 ⇒ Gate3 直接 `exit 0` 放行；`transition` 让该态落到 Gate4 被 Tier-2 拦下（Gate4 本就在同进程使用 `transition`，`fk_extract_l2_verdict` 可用性已被其验证）。
    保持 `phases_done` 短路（历史 phase 不追溯）；Gate7 拒绝报文不变。
    同步改写 `:24-34` 契约注释与 `:86` 行内注释为「存在**且有效**」；ADR-029 记录：变更前后语义、被拒三类标记（空/`touch`、缺键、值域非法）、`L2_verdict` 相悖态、`phases_done` 短路保持、以及**已知残余**（Tier-1 只验元数据、不验 `L3_artifact_hash` 是否对应当前工件 ⇒ 与 TD-042/TD-045 同源，留 v2）。
    落地：`./sync-hooks.sh`（6 副本）+ `make test-sync` + 重建 dist + `make check` 全绿；行为双态须在 `test/test_review_gate_validity.bats` 里可复算（同一夹具、有/无有效标记、空 `touch` 标记、缺 `L3_verdict`、`L2_verdict` 相悖）。
    ⚠️ 工具面约束（L-148）：本仓 PreToolUse path-guard 会拦**命令文本里出现 `.independent-review-*.done` 字面名**的调用 —— 写夹具时用拼接构造（如 `MARK=".independent-review-${PHASE}.done"`）或把逻辑放进脚本文件后再调用。
    提交：`git add` 显式列路径（改动 hook + 新增 ADR + bats + 同步产物）+ `git commit -m "fix(health-fix-2026-09b): T-FIX-02 TD-059 阶段门有效性（无效标记必须拒绝 + ADR-029）" -- <路径…>`；禁用 `git add .`/`-A`、`--no-verify`、`git stash`。提交后写 `.specs/health-fix-2026-09b/T-FIX-02-SUMMARY.md`、勾选 `status="done"` + `<done>` 注记、追加 `task_progress` 五字段；SUMMARY 与勾选留待主 agent 的 housekeeping 提交。
  </action>
  <verify>
    # 判据修复（主 agent 2026-09-24 · 同 T-FIX-01）：原首行 `export LC_ALL=C` 会让**既有**
    # `test/test_l3_pipeline_fix.bats:592` 的 UTF-8 边界用例在 HEAD 即红（**已登记 TD-051** 的
    # locale 敏感性：`LC_ALL=C` 下 `:609` 的 `iconv -f utf-8 -o /dev/null` 把合法 UTF-8 判成非法，
    # 末尾 `make check` 必红），与本 task 交付物无关。已删除该 locale 覆盖（其余判据逐字不动）。
    set -u; rc=0;
    HOOK="$PWD/flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh";
    grep -q 'fk_validate_done_marker' flow-kit-bundle/hooks/stop/lib/done-validation.sh || { echo "🔴 Gate3 未接入有效性校验"; rc=1; };
    bash -n flow-kit-bundle/hooks/stop/lib/done-validation.sh || { echo "🔴 done-validation.sh 语法错误"; rc=1; };
    bash -n "$HOOK" || { echo "🔴 gate hook 语法错误"; rc=1; };
    ls .specs/adr/029-*.md > /dev/null 2>&1 || { echo "🔴 缺 ADR-029"; rc=1; };
    # 判据修复（主 agent 2026-09-24 · 新登记 TD-060）：原判据进入沙箱后**未回仓根**，导致其后 6 步
    # （新 bats / check-hooks-sync / check-test-sync / check-dist / make check）全在 `${TMPDIR:-/tmp}`
    # 沙箱里跑（无 `test/`、无 `Makefile` ⇒ 恒 4 条 🔴 + `make: *** 没有规则可制作目标“check”`），
    # 与交付物无关。已补 `REPO_ROOT="$PWD"` 与沙箱段末尾的 `cd "$REPO_ROOT"`；步骤与断言逐字不动。
    REPO_ROOT="$PWD"; SBX=$(mktemp -d "${TMPDIR:-/tmp}/tfix2-XXXXXX"); trap 'rm -rf "$SBX"' EXIT; cd "$SBX" || exit 1;
    git init -q .; git config user.email t@t; git config user.name t; git commit -q --allow-empty -m seed;
    mkdir -p .specs/fix2-change; printf 'fixture\n' > .specs/fix2-change/TEST.md;
    printf '%s\n' '{"change_id":"fix2-change","phase":"5","goal":{"current_phase":"5","phases_done":[],"gate_config":{"5-test":"both"},"auto_advance":false}}' > .flow-active;
    printf '# 独立审查 · 阶段 5\n\n## L2 盲审（第 1 轮）\n\n**Verdict**: pass\n' > .specs/fix2-change/INDEPENDENT-REVIEW-5.md;
    MARK=".specs/fix2-change/.independent-review-5.done";
    probe() { printf '%s' "{\"hook_event_name\":\"PreToolUse\",\"session_id\":\"s\",\"cwd\":\"$SBX\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git commit -m probe -- .specs/fix2-change/TEST.md\"}}" | bash "$HOOK" > gate.out 2>&1; echo $?; };
    write_marker() { printf 'phase=5\nchange_id=fix2-change\nwritten_by=subagent\nL2_verdict=%s\nL3_verdict=pass\nartifacts=TEST.md,TASK.md\n' "$1" > "$MARK"; };
    A=$(probe); [ "$A" = "2" ] || { echo "🔴 状态 A（无标记）期望 2 实得 $A"; rc=1; };
    grep -q '独立 review gate' gate.out || { echo "🔴 状态 A 报文未命中"; rc=1; };
    write_marker pass; B=$(probe); [ "$B" = "0" ] || { echo "🔴 状态 B（6 键有效标记）期望 0 实得 $B"; cat gate.out; rc=1; };
    printf '# 独立审查 · 阶段 5\n\n## L2 盲审（第 1 轮）\n\n**Verdict**: fail\n' > .specs/fix2-change/INDEPENDENT-REVIEW-5.md;
    B2=$(probe); [ "$B2" = "2" ] || { echo "🔴 状态 B2（标记 pass vs 审查档 fail）期望 2 实得 $B2 ⇒ TD-059 未修复"; rc=1; };
    printf '# 独立审查 · 阶段 5\n\n## L2 盲审（第 1 轮）\n\n**Verdict**: pass\n' > .specs/fix2-change/INDEPENDENT-REVIEW-5.md;
    : > "$MARK"; B3=$(probe); [ "$B3" = "2" ] || { echo "🔴 状态 B3（touch 空标记）期望 2 实得 $B3 ⇒ 存在性判定仍在"; rc=1; };
    printf 'phase=5\nchange_id=fix2-change\nwritten_by=subagent\nL2_verdict=pass\nartifacts=TEST.md,TASK.md\n' > "$MARK";
    B4=$(probe); [ "$B4" = "2" ] || { echo "🔴 状态 B4（缺 L3_verdict）期望 2 实得 $B4"; rc=1; };
    rm -f .flow-active; C=$(probe); [ "$C" = "0" ] || { echo "🔴 状态 C（无 .flow-active）期望 0 实得 $C"; rc=1; };
    printf 'A=%s B=%s B2=%s B3=%s B4=%s C=%s\n' "$A" "$B" "$B2" "$B3" "$B4" "$C";
    cd "$REPO_ROOT" || exit 1;   # 判据修复（TD-060）：沙箱段结束 ⇒ 回到仓根再跑 bats / make
    OUT=$(npx bats test/test_review_gate_validity.bats 2>&1); brc=$?;
    printf '%s\n' "$OUT" | grep -q '^not ok' && { printf '%s\n' "$OUT" | tail -20; echo "🔴 新增双态判据有失败项"; rc=1; };
    [ $brc -eq 0 ] || { echo "🔴 新增双态判据 rc=$brc"; rc=1; };
    make check-hooks-sync > /dev/null 2>&1 || { echo "🔴 hooks 副本未同步（跑 ./sync-hooks.sh）"; rc=1; };
    make check-test-sync > /dev/null 2>&1 || { echo "🔴 test 双源不一致"; rc=1; };
    make check-dist > /dev/null 2>&1 || { echo "🔴 dist 未重建"; rc=1; };
    make check > /tmp/tfix2-check.out 2>&1 || { tail -20 /tmp/tfix2-check.out; echo "🔴 make check 不绿"; rc=1; };
    exit $rc
  </verify>
  <done>TD-059 收敛：`fk_independent_review_gate_active` 以「存在**且有效**」为准（空 / 缺键 / 值域非法 / `L2_verdict` 相悖 ⇒ 仍拒绝）；五态沙箱实测 A=2 · B=0 · B2=2 · B3=2 · B4=2 · C=0；ADR-029 记录语义与残余；hooks 6 副本 + test 双源 + dist + `make check` 全绿；**时点实测（T-FIX-02 执行者 2026-09-24）**：commit `6cff7a2`（5 文件 +472/−4：`done-validation.sh` 13/3 · ADR-029 63 · 两份 bats 197+197 · `STATE.md` 2/1）；五态沙箱实测 `A=2 B=0 B2=2 B3=2 B4=2 C=0`；`npx bats test/test_review_gate_validity.bats` = 11 ok；`npx bats test/` = **1012 ok / 0 not ok / 0 skip**（`--count` = 1012，原 1001 + 11，`.specs/STATE.md:48` 基线已更新）；`make check-hooks-sync` / `check-test-sync` / `check-dist` / `make check` 全 rc=0（`✅ make check: 全部通过`）。**`<verify>` 原样跑 rc=1**：五态行全对，唯一红点是判据自身第 12 行 `cd "$SBX"` 后未回仓根 ⇒ 第 30-36 行在 `${TMPDIR:-/tmp}` 沙箱里跑（无 `test/`、无 `Makefile`）；在仓根 cwd 补跑同 6 行全绿（判据未改动，见 `T-FIX-02-SUMMARY.md` ④ 偏离 ①）。既有 `test/done-validation.bats` / `test/test_l2_l3_granular_gate.bats` **无需订正**（逐一审计：前者直测 `fk_validate_done_marker`；后者 16 处调用从不创建标记 ⇒ 全为「无标记」态，新语义同结果）。`fix_rounds=0`、`commit_sha=6cff7a2`</done>
  <depends_on>T-FIX-01</depends_on>
</task>
```

<task id="T-FIX-03" parallel="false" status="done" model-tier="top">
  <name>阶段 6 🔴 F1/F2 + 🟡 F3/F4/F5 —— 隐私门禁 fail-open 收敛（check-path-privacy.sh）</name>
  <read_files>
    <`.specs/health-fix-2026-09b/REVIEW.md` §B 的 F1 ~ F5（Severity / Symptom(file:line) / Consequence / Remedy 四要素齐备；行号为**修复前快照**）>
    <`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`（392 行；F1 点 `:75-77`（4× `mktemp` 不校验 rc —— 跨模型 spot-check 勘误：REVIEW 原引 `:79-81`，off-by-4）`:105-111`（2× `cp -- … "$TMP_ALLOWLIST"` 不校验 rc ⇒ 坏 TMPDIR 链路**第一环**）`:203-209` `:285` `:309` `:336` · F2 点 `:203-209` `:369-374`（另：`git ls-files` 在「git 仓但 index 为空」时 rc=0 只是输出 0 行 ⇒ rc 断言抓不到，须由候选数断言兜住） · F3 点 `:285-299` `:302` `:309-310` `:319` `:354` · F4 点 `:146-147` vs `:198` `:341` · F5 点 `:65-73` `:77` `:339-340`）>
    <`test/test_path_privacy_gate.bats`（9 例 · F1 常设网；新增用例须沿用「运行时复制真实生产件进夹具 + 拼接构造探针」的既有范式）>
    <`Makefile`（`:121-127` 挂 `check-path-privacy` 的薄壳目标）>
  </read_files>
  <write_files>
    <`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`>
    <`test/test_path_privacy_gate.bats` + `flow-kit-bundle/test/test_path_privacy_gate.bats`（`make test-sync`）>
    <`.specs/STATE.md`（bats 基线行：新增用例后按实测更新计数）>
    <`.specs/CONTEXT.md`（F1/F2 相关技术债行：标注「阶段 6 REVIEW 发现 · 本 change 内修复（T-FIX-03）」）>
    <`dist/`（重建）>
  </write_files>
  <action>
    **目标：把「未能检查」与「检查通过」在退出码与报文上分开。** 五条发现按 F1/F2（🔴 必修）→ F3（🟡）→ F4/F5（🟡 顺手）顺序落地，**不得**改变规范环境下的既有行为（正常干净 ⇒ rc=0；正常命中 ⇒ rc=1 且归因 `file:line:content`）。
    ① **F1（机械故障 ⇒ 必须非 0）**：`mktemp` / 候选枚举（`git ls-files` / `git ls-tree`）/ 逐文件检索三处的 rc 与 stderr **一律不再丢弃**；任一失败 ⇒ 打印 `🔴 无法完成扫描：<原因>（<file:line>）` 并 `exit 1`（与「无命中」明确分出口码）。检索时区分 `grep` 的 rc=1（无匹配）与 rc≥2（出错）；`|| true` 与 `2>/dev/null` 只允许出现在**已断言 rc 之后**的位置。**跨模型 spot-check 增量**：`:105-111` 的两处 `cp -- … "$TMP_ALLOWLIST"` 必须一并断言 rc（坏 `TMPDIR` 链路上它先于 `mktemp` 报错被吞）；并注意 `git ls-files` 在「git 仓但 index 为空」时 rc=0 只是输出 0 行 ⇒ **rc 断言抓不到这一型**，只能靠 ② 的候选数断言兜住。
    ② **F2（0 候选 ≠ 干净）**：候选文件数落进自证行（如 `候选文件 N 个`，N 为枚举产物行数）；`N=0` ⇒ fail-closed `exit 1` + `🔴 候选面为空，无法判定`。**双态用例须覆盖两型 0 候选面**：① 非 git 目录；② git 仓但 index 为空（`git init` 后未 `add`）且工作树含真泄漏（后者是跨模型 spot-check 发现的同根变体）。
    ③ **F3（二进制策略单点）**：两模式（工作树 / `CHECK_REV`）采用同一显式策略（例如统一 `-a` 做匹配并按行归因，或统一 `-I` 跳过且在自证行打印「跳过二进制 N 个」）；命中记录读取端**新增**「line 字段必须匹配 `^[0-9]+$`」断言，不匹配 ⇒ 按不可归因命中单列并 fail-closed；每文件检索失败同样走 ① 的出口。
    ④ **F4（注释口径单点）**：把「什么算注释行」抽成单一判定（校验器与计数器共用），使仅含 `<!-- … -->` 或 `#` 注释的清单在自证行里口径一致（`允许清单 N 条` 只数有效条目）。
    ⑤ **F5（临时文件单点）**：全脚本**只剩一个** `trap … EXIT`（删除 `:340` 的第二个 trap，或让 `cleanup()` 引用同一 `TMP_FILES` 清单），杜绝「清单两处、早期退出残留」。
    **TDD 要求（判别式）**：先为 ①②③④⑤ 各写可复现的**双态**用例（坏环境 ⇒ 非 0 / 好环境 ⇒ 原行为），在**未修复**的生产件上确认新用例**确实转红**（贴原文），再修复至全绿。夹具必须**运行时复制真实生产件**（禁把脚本正文抄进 bats），探针用拼接构造（如 `'/home/''zz-f3-pro''be/'`）以免触发本仓 path-privacy 门禁（L-137）。
    **收尾（顺序敏感 · L-154）**：`make test-sync` → `bash package-dsh-plugin.sh` → `make check-hooks-sync check-test-sync check-dist` → `make check`；并在**真实仓**复跑 `make check-path-privacy`（必须 rc=0，确认未引入假红）。
    提交：`git add` 显式列路径 + `git commit -m "fix(health-fix-2026-09b): T-FIX-03 隐私门禁 fail-open 收敛（F1~F5）" -- <路径…>`；禁 `git add .`/`-A`/`--no-verify`/`git stash`。提交后写 `.specs/health-fix-2026-09b/T-FIX-03-SUMMARY.md`、勾 `status="done"` + `<done>` 注记（commit sha / 实测计数 / 各门禁 rc）、追加 `task_progress` 五字段条目；SUMMARY 与勾选留主 agent housekeeping。
  </action>
  <verify>
    set -u; rc=0;
    SUT="flow-kit-bundle/flow-kit/reference/check-path-privacy.sh";
    AL="flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt";
    bash -n "$SUT" || { echo "🔴 check-path-privacy.sh 语法错误"; rc=1; };
    # 夹具构造：真实生产件 + 真实清单 + 真泄漏（探针拼接，禁字面真名）
    mkfix() { # $1=目录 $2=1 表示含泄漏
      mkdir -p "$1/flow-kit-bundle/flow-kit/reference" "$1/.specs/fix3-change";
      cp "$SUT" "$1/flow-kit-bundle/flow-kit/reference/";
      cp "$AL"  "$1/flow-kit-bundle/flow-kit/reference/";
      git -C "$1" init -q; git -C "$1" config user.email t@t; git -C "$1" config user.name t;
      printf 'clean\n' > "$1/README.md";
      if [ "${2:-0}" = "1" ]; then printf 'leak line: /home/%szz-f3-pro%sbe/secret/\n' '' '' > "$1/leak.txt"; fi;
      git -C "$1" add -A >/dev/null 2>&1; git -C "$1" commit -q -m seed;
    }
    SBX=$(mktemp -d "${TMPDIR:-/tmp}/tfix3-XXXXXX"); trap 'rm -rf "$SBX"' EXIT;
    mkfix "$SBX/leak" 1; mkfix "$SBX/clean" 0;
    # A) 规范环境 + 真泄漏 ⇒ 必须 rc=1 且归因 leak.txt:1
    ( cd "$SBX/leak" && bash flow-kit-bundle/flow-kit/reference/check-path-privacy.sh ) > "$SBX/a.out" 2>&1; A=$?;
    [ "$A" -ne 0 ] || { echo "🔴 F0：规范环境命中未拒绝（rc=0）"; cat "$SBX/a.out"; rc=1; };
    grep -q 'leak\.txt:1' "$SBX/a.out" || { echo "🔴 F0：命中归因未含 leak.txt:1"; cat "$SBX/a.out"; rc=1; };
    # B) 规范环境 + 干净 ⇒ 必须 rc=0（不回归）
    ( cd "$SBX/clean" && bash flow-kit-bundle/flow-kit/reference/check-path-privacy.sh ) > "$SBX/b.out" 2>&1; B=$?;
    [ "$B" -eq 0 ] || { echo "🔴 F0 回归：干净环境被拒（rc=$B）"; cat "$SBX/b.out"; rc=1; };
    # C) F2：自证行必须含候选文件数，且与 git ls-files 计数一致
    grep -q '候选文件' "$SBX/b.out" || { echo "🔴 F2：自证行缺候选文件数"; rc=1; };
    N_REPORT=$(grep -oE '候选文件[^0-9]*[0-9]+' "$SBX/b.out" | grep -oE '[0-9]+' | head -1);
    N_REAL=$( cd "$SBX/clean" && git ls-files | wc -l | tr -d ' ' );
    [ "${N_REPORT:-x}" = "$N_REAL" ] || { echo "🔴 F2：候选数自称 $N_REPORT 实测 $N_REAL"; rc=1; };
    # D) F1：TMPDIR 不可用 ⇒ 必须非 0 且不得打印「清单外命中 0 条 ✅」
    ( cd "$SBX/leak" && TMPDIR=/nonexistent-dir-probe bash flow-kit-bundle/flow-kit/reference/check-path-privacy.sh ) > "$SBX/d.out" 2>&1; D=$?;
    [ "$D" -ne 0 ] || { echo "🔴 F1：TMPDIR 不可用时仍 rc=0（fail-open 未修）"; cat "$SBX/d.out"; rc=1; };
    grep -q '清单外命中 0 条' "$SBX/d.out" && { echo "🔴 F1：故障态仍打印「清单外命中 0 条 ✅」"; rc=1; };
    # E) F2：非 git 目录（脚本+清单+泄漏齐备）⇒ 必须非 0
    mkdir -p "$SBX/nogit/flow-kit-bundle/flow-kit/reference";
    cp "$SUT" "$SBX/nogit/flow-kit-bundle/flow-kit/reference/"; cp "$AL" "$SBX/nogit/flow-kit-bundle/flow-kit/reference/";
    printf 'leak line: /home/%szz-f3-pro%sbe/secret/\n' '' '' > "$SBX/nogit/leak.txt";
    ( cd "$SBX/nogit" && bash flow-kit-bundle/flow-kit/reference/check-path-privacy.sh ) > "$SBX/e.out" 2>&1; E=$?;
    [ "$E" -ne 0 ] || { echo "🔴 F2：0 候选面仍 rc=0（与干净同形）"; cat "$SBX/e.out"; rc=1; };
    # E2) F2 变体：git 仓但 index 为空（未 add）+ 工作树真泄漏 ⇒ 必须非 0
    mkdir -p "$SBX/emptyidx/flow-kit-bundle/flow-kit/reference";
    cp "$SUT" "$SBX/emptyidx/flow-kit-bundle/flow-kit/reference/"; cp "$AL" "$SBX/emptyidx/flow-kit-bundle/flow-kit/reference/";
    git -C "$SBX/emptyidx" init -q; git -C "$SBX/emptyidx" config user.email t@t; git -C "$SBX/emptyidx" config user.name t;
    printf 'leak line: /home/%szz-f3-pro%sbe/secret/\n' '' '' > "$SBX/emptyidx/leak.txt";
    ( cd "$SBX/emptyidx" && bash flow-kit-bundle/flow-kit/reference/check-path-privacy.sh ) > "$SBX/e2.out" 2>&1; E2=$?;
    [ "$E2" -ne 0 ] || { echo "🔴 F2 变体：空 index 仓（git ls-files rc=0）仍 rc=0"; cat "$SBX/e2.out"; rc=1; };
    # F) F3：tracked 二进制含探针 ⇒ 工作树模式必须非 0 且归因可解析（line 字段为数字）
    mkdir -p "$SBX/bin/flow-kit-bundle/flow-kit/reference";
    cp "$SUT" "$SBX/bin/flow-kit-bundle/flow-kit/reference/"; cp "$AL" "$SBX/bin/flow-kit-bundle/flow-kit/reference/";
    git -C "$SBX/bin" init -q; git -C "$SBX/bin" config user.email t@t; git -C "$SBX/bin" config user.name t;
    printf 'clean\n' > "$SBX/bin/README.md"; printf 'BIN\x00/home/%szz-f3-pro%sbe/x\x00\n' '' '' > "$SBX/bin/bin.dat";
    git -C "$SBX/bin" add -A >/dev/null 2>&1; git -C "$SBX/bin" commit -q -m seed;
    ( cd "$SBX/bin" && bash flow-kit-bundle/flow-kit/reference/check-path-privacy.sh ) > "$SBX/f.out" 2>&1; F=$?;
    [ "$F" -ne 0 ] || { echo "🔴 F3：工作树模式二进制命中被静默丢弃"; rc=1; };
    grep -qE 'bin\.dat:[0-9]+:' "$SBX/f.out" || { echo "🔴 F3：二进制归因不可解析"; cat "$SBX/f.out"; rc=1; };
    # G) F4：清单仅含 HTML 注释 ⇒ 自证须报「允许清单 0 条」
    cp -r "$SBX/clean" "$SBX/al"; printf '<!-- only html comment -->\n' > "$SBX/al/flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt";
    git -C "$SBX/al" add -A >/dev/null 2>&1; git -C "$SBX/al" commit -q -m al;
    ( cd "$SBX/al" && bash flow-kit-bundle/flow-kit/reference/check-path-privacy.sh ) > "$SBX/g.out" 2>&1;
    grep -q '允许清单 0 条' "$SBX/g.out" || { echo "🔴 F4：HTML 注释行被计为有效条目"; grep '允许清单' "$SBX/g.out"; rc=1; };
    # H) F5：全脚本只剩一个 EXIT trap
    T=$(grep -cE '^[[:space:]]*trap .*EXIT' "$SUT");
    [ "$T" -eq 1 ] || { echo "🔴 F5：EXIT trap 出现 $T 次（应 1 次）"; rc=1; };
    printf 'A=%s B=%s D=%s E=%s E2=%s F=%s traps=%s\n' "$A" "$B" "$D" "$E" "$E2" "$F" "$T";
    # I) 新增双态用例 + 全量套件
    OUT=$(npx bats test/test_path_privacy_gate.bats 2>&1); brc=$?;
    printf '%s\n' "$OUT" | grep -q '^not ok' && { printf '%s\n' "$OUT" | tail -20; echo "🔴 F1 常设网有失败项"; rc=1; };
    [ $brc -eq 0 ] || { echo "🔴 test_path_privacy_gate.bats rc=$brc"; rc=1; };
    FULL=$(npx bats test/ 2>&1); frc=$?;
    printf '%s\n' "$FULL" | grep -q '^not ok' && { printf '%s\n' "$FULL" | grep '^not ok' | head -5; echo "🔴 全量套件有失败项"; rc=1; };
    [ $frc -eq 0 ] || { echo "🔴 全量套件 rc=$frc"; rc=1; };
    echo "bats: $(printf '%s\n' "$FULL" | grep -cE '^ok [0-9]+') ok / $(printf '%s\n' "$FULL" | grep -cE '^not ok [0-9]+') not-ok / count=$(npx bats --count test/)";
    # J) 真实仓不得出现假红 + 三一致性门禁 + make check
    make check-path-privacy > "$SBX/real.out" 2>&1 || { echo "🔴 真实仓 check-path-privacy 假红"; tail -5 "$SBX/real.out"; rc=1; };
    make check-hooks-sync > /dev/null 2>&1 || { echo "🔴 hooks 副本未同步"; rc=1; };
    make check-test-sync  > /dev/null 2>&1 || { echo "🔴 test 双源不一致"; rc=1; };
    make check-dist       > /dev/null 2>&1 || { echo "🔴 dist 未重建"; rc=1; };
    make check > /tmp/tfix3-check.out 2>&1 || { tail -20 /tmp/tfix3-check.out; echo "🔴 make check 不绿"; rc=1; };
    exit $rc
  </verify>
  <done>F1/F2（🔴）+ F3/F4/F5（🟡）收敛：故障态（mktemp 不可用 / `cp` 写入清单副本失败 / 0 候选面两型（非 git 目录 · 空 index 仓）/ 检索出错）一律非 0 且报文指名原因；自证行含候选文件数并与 `git ls-files` 一致；二进制两模式同一显式策略且归因 `file:line` 恒为数字；注释口径与临时文件清单各单点；规范环境行为零变更（干净 rc=0 / 命中 rc=1 归因 `file:line`）；新增双态用例在修复前的生产件上确实转红（原文入 SUMMARY）；`npx bats test/` 全绿（计数与 `.specs/STATE.md` 基线同步更新）；三一致性门禁 + `make check` + 真实仓 `make check-path-privacy` 全 rc=0。时点实测（T-FIX-03 执行者 2026-09-24）：commit `6e39cfb`（5 文件 +491/-45）；`<verify>` rc=0 汇总 `A=1 B=0 D=1 E=1 E2=1 F=1 traps=1` + `bats: 1023 ok / 0 not-ok / count=1023`；基线 1012→1023（+11 双态）；`make check-nfr-portability` rc=0（bash 3.2 兼容）；SUMMARY 落 `.specs/health-fix-2026-09b/T-FIX-03-SUMMARY.md`（不提交）；`deferred=[]`，`fix_rounds=0`。</done>
  <depends_on>T-FIX-02</depends_on>
</task>

<task id="T-FIX-04" parallel="false" status="done" model-tier="top">
  <name>阶段 6 🟡 F6/F7 —— check-gate-sync 缺对不得报全绿 + 覆盖度分母实算</name>
  <read_files>
    <`.specs/health-fix-2026-09b/REVIEW.md` §B 的 F6 · F7（含沙箱复现结论：只放 2/3 个 prompt 文件 ⇒ 仍打印「✅ 校验对 3/14 一致」并 rc=0）>
    <`flow-kit-bundle/flow-kit/reference/check-gate-sync.sh`（F6 点 `:59-68` `:204` `:209` · F7 点 `:25-26` `:32` `:40` `:204` `:206` `:209`；行号为修复前快照）>
    <`test/test_check_gate_sync.bats`（T15 已把断言由 `-ne 2` 收紧为 `-eq 0`）>
  </read_files>
  <write_files>
    <`flow-kit-bundle/flow-kit/reference/check-gate-sync.sh`>
    <`test/test_check_gate_sync.bats` + `flow-kit-bundle/test/test_check_gate_sync.bats`（`make test-sync`）>
    <`.specs/CONTEXT.md`（F6/F7 技术债行标注「阶段 6 REVIEW 发现 · 本 change 内修复（T-FIX-04）」）>
    <`dist/`（重建）>
  </write_files>
  <action>
    ① **F6（缺文件 ⇒ 不得全绿）**：任一校验对缺 prompt 或 skill 文件 ⇒ 计入错误（或返回独立的「未验证」退出码且调用方按非 0 处理），汇总行不得出现「✅ … 一致」；覆盖度的**分母改为实际参与比对的对数**（静态 `${#PAIRS[@]}` 只可用于「应有对数」的展示，且必须与实际比对对数分列）。
    ② **F7（常量与文案单点）**：`14` 只在常量定义处出现一次，其余文案（含「非全量 N 对全绿」这类自证行）一律插值；`:206` 的补救指引改为与 v1 **全文内容比对**语义相符的表述（不再指向已不存在的「协议段」比对）。
    ③ 不改 `make check-gate-sync` 的**正常路径**行为：真实仓仍须 rc=0 且打印「✅ 预设名集合一致 (17 个预设)」。
    **TDD 要求（判别式）**：先在沙箱夹具（复制真实脚本 + 临时 `prompt`/`skill` 目录，故意隐藏一对中的文件）确认**修复前** rc=0 且汇总为「✅ …一致」（贴原文），再修复至该态 rc≠0；正常态夹具仍 rc=0。新增断言优先**追加进既有用例**（保持用例计数不变），若确需新用例则同步更新 `.specs/STATE.md` 基线行。
    收尾与提交同 T-FIX-03（顺序 `make test-sync` → `package-dsh-plugin.sh` → 三一致性门禁 → `make check`；显式 `git add` 路径；`git commit -m "fix(health-fix-2026-09b): T-FIX-04 check-gate-sync 缺对不得报全绿（F6/F7）" -- <路径…>`）；提交后写 `T-FIX-04-SUMMARY.md`、勾 `status="done"` + `<done>`、追加 `task_progress` 五字段。
  </action>
  <verify>
    set -u; rc=0;
    SUT="flow-kit-bundle/flow-kit/reference/check-gate-sync.sh";
    bash -n "$SUT" || { echo "🔴 check-gate-sync.sh 语法错误"; rc=1; };
    grep -q 'PAIRS_TOTAL' "$SUT" || { echo "🔴 F7：缺 PAIRS_TOTAL 常量"; rc=1; };
    grep -q 'protocol' "$SUT" && echo "（提示）:206 文案已复核：$(grep -n '请同步' "$SUT" | head -2)";
    # 真实仓正常路径不得回归
    make check-gate-sync > /tmp/tfix4-real.out 2>&1 || { echo "🔴 真实仓 check-gate-sync 不再 rc=0"; tail -8 /tmp/tfix4-real.out; rc=1; };
    grep -q '预设名集合一致' /tmp/tfix4-real.out || { echo "🔴 正常路径自证行缺失"; rc=1; };
    # 缺对夹具：复制真实脚本 + 真实 prompt/skill 全量，再隐藏一对中的 skill
    SBX=$(mktemp -d "${TMPDIR:-/tmp}/tfix4-XXXXXX"); trap 'rm -rf "$SBX"' EXIT;
    mkdir -p "$SBX/fk/flow-kit-bundle/flow-kit/reference" "$SBX/fk/flow-kit-bundle/flow-kit/prompts" "$SBX/fk/flow-kit-bundle/skills";
    cp "$SUT" "$SBX/fk/flow-kit-bundle/flow-kit/reference/";
    cp -r flow-kit-bundle/flow-kit/prompts/. "$SBX/fk/flow-kit-bundle/flow-kit/prompts/";
    cp -r flow-kit-bundle/skills/. "$SBX/fk/flow-kit-bundle/skills/";
    ( cd "$SBX/fk" && bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh ) > "$SBX/ok.out" 2>&1; OK=$?;
    [ "$OK" -eq 0 ] || { echo "🔴 完整夹具本应 rc=0 实得 $OK"; tail -8 "$SBX/ok.out"; rc=1; };
    # 判据修复（主 agent 2026-09-24 · TD-065）：原实现 `ls …/skills/*/SKILL.md | head -1`
    # 取到的是**字母序首个** skill（flow-architect），而 PAIRS 只含 flow-evolve /
    # flow-intel / flow-restyle ⇒ 隐藏非比对对成员时 MISS=0，判据自我误报（修复后代码
    # 的正确行为被当成缺陷）。改为**从 PAIRS 声明派生**首个真实成员的 skill 载体
    # （`|<skill>` 形态），保证被隐藏的确是一对中的文件。
    pair_skill=$(cd "$SBX/fk" && grep -oE '\|flow-[a-z0-9-]+' flow-kit-bundle/flow-kit/reference/check-gate-sync.sh | head -1 | tr -d '|');
    hidden="flow-kit-bundle/skills/${pair_skill}/SKILL.md";
    if [ -z "$pair_skill" ] || [ ! -f "$SBX/fk/$hidden" ]; then
      echo "🔴 判据前置失败：未从 PAIRS 派生到 skill 载体（pair_skill='${pair_skill}' path='${hidden}'）"; rc=1;
    fi;
    printf '   （诊断）verify hides: %s\n' "$hidden";
    mv "$SBX/fk/$hidden" "$SBX/fk/$hidden.hidden";
    ( cd "$SBX/fk" && bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh ) > "$SBX/miss.out" 2>&1; MISS=$?;
    [ "$MISS" -ne 0 ] || { echo "🔴 F6：缺一对文件仍 rc=0"; tail -8 "$SBX/miss.out"; rc=1; };
    grep -q '✅ 校验对' "$SBX/miss.out" && grep -q '一致' "$SBX/miss.out" && { echo "🔴 F6：缺对态仍打印「✅ … 一致」"; grep '校验对' "$SBX/miss.out"; rc=1; };
    printf 'real=%s full_fixture=%s missing_pair=%s\n' "$(grep -c . /tmp/tfix4-real.out)" "$OK" "$MISS";
    # bats + 门禁
    OUT=$(npx bats test/test_check_gate_sync.bats 2>&1); brc=$?;
    printf '%s\n' "$OUT" | grep -q '^not ok' && { printf '%s\n' "$OUT" | tail -20; echo "🔴 test_check_gate_sync.bats 有失败项"; rc=1; };
    [ $brc -eq 0 ] || { echo "🔴 test_check_gate_sync.bats rc=$brc"; rc=1; };
    FULL=$(npx bats test/ 2>&1); frc=$?;
    printf '%s\n' "$FULL" | grep -q '^not ok' && { printf '%s\n' "$FULL" | grep '^not ok' | head -5; rc=1; };
    [ $frc -eq 0 ] || { echo "🔴 全量套件 rc=$frc"; rc=1; };
    make check-hooks-sync > /dev/null 2>&1 || { echo "🔴 hooks 副本未同步"; rc=1; };
    make check-test-sync  > /dev/null 2>&1 || { echo "🔴 test 双源不一致"; rc=1; };
    make check-dist       > /dev/null 2>&1 || { echo "🔴 dist 未重建"; rc=1; };
    make check > /tmp/tfix4-check.out 2>&1 || { tail -20 /tmp/tfix4-check.out; echo "🔴 make check 不绿"; rc=1; };
    exit $rc
  </verify>
  <done>F6/F7 收敛：缺 prompt/skill 文件 ⇒ 非 0 退出且汇总不再打印「✅ … 一致」；覆盖度分母 = 实际比对对数；`14` 常量单点、文案插值、`:206` 指引与全文比对语义一致；正常路径零变更（真实仓 rc=0 + 17 预设自证行在位）；判别式证据（修复前缺对 rc=0 原文 / 修复后 rc≠0）入 SUMMARY；bats 与三一致性门禁 + `make check` 全绿。时点实测（T-FIX-04 执行者 2026-09-24）：commit `521b21c`；`<verify>` rc=0（诊断 `verify hides: flow-kit-bundle/skills/flow-evolve/SKILL.md`，`real=21 full_fixture=0 missing_pair=1`）；台账 `completed_at` 2026-09-24T23:31:48+08:00，Δ=8s ≤120s；判据缺陷 TD-065 由执行者上报、主 agent 修复，随后原样复跑 rc=0。</done>
  <depends_on>T-FIX-03</depends_on>
</task>

<task id="T-FIX-05" parallel="false" status="done" model-tier="top">
  <name>阶段 6 🟡 F8 —— Makefile NFR 判据正文去重（wrapper 变薄壳，单一判据源）</name>
  <read_files>
    <`.specs/health-fix-2026-09b/REVIEW.md` §B 的 F8（含主 agent 的 python 逐语句比对结论：internals 77 条语句中 **76 条**在 wrapper 里逐字出现，wrapper 仅多 `NFR_OUT`/`NFR_RC` 三态映射与 `export NFR_RC_FILE`）>
    <`Makefile`（`:120` 起 `check-nfr-portability-internals` 78 行 recipe · `:200` 起 `check-nfr-portability` 88 行 wrapper；`:106 check:` 先决条件挂的是 **wrapper**；行号为修复前快照）>
    <`test/test_nfr_portability_gate.bats`（7 例 · F3 常设网，已覆盖「空变更集 ⇒ `NFR_RC_FILE`=3 + stdout `SKIP:` 且无 ✅」「包装层 3 ⇒ exit 0 且保留 `SKIP:`」「包装层 1 ⇒ make 非零退出且 stderr 保留 `file:line`」）>
  </read_files>
  <write_files>
    <`Makefile`>
    <`test/test_nfr_portability_gate.bats` + `flow-kit-bundle/test/test_nfr_portability_gate.bats`（`make test-sync`；新增断言优先**追加进既有用例**以保持计数）>
    <`dist/`（重建）>
  </write_files>
  <action>
    **目标：判据正文只存在一处，且挂在 `make check` 上的那份不可能与被修的那份分叉。**
    ① `check-nfr-portability-internals` 保留为**唯一判据正文**（rc∈{0,1,3}，`$NFR_RC_FILE` 回传机制不变）。
    ② `check-nfr-portability` 改为**薄壳**：`export NFR_RC_FILE=…` → `$(MAKE) --no-print-directory check-nfr-portability-internals`（或等价的递归调用，须保留 stdout/stderr 通道让 `file:line` 与 `SKIP:` 原样透出）→ 读 rc 文件把 **3 映射为 0**（`SKIP:` 一并透出）→ 其余非 0 原样失败。**删除** wrapper 内的判据正文（重复的 76 条语句）。
    ③ 若判据内部依赖「当前 recipe 变量」（如 `$@` / 局部 `$NFR_OUT`），改写为显式传参或环境变量，确保薄壳语义等价。
    ④ **钉住断言**：在 `test_nfr_portability_gate.bats` 的既有用例中追加断言，使「正文被复制回 wrapper」这件事**立即转红**（例如：判据特征串在 `Makefile` 中只出现 1 次；或 wrapper recipe 行数 < 30 行）。断言写法须在修复前后各验一次（修复前应红 ⇒ 贴原文）。
    **零行为变更要求**：F3 现有 7 例必须在薄壳下全绿（三态映射、`SKIP:` 保留、`file:line` 保留、空变更集 rc=3 语义）。
    **TDD/判别式**：先加钉住断言并确认在**修复前**红（贴原文），再改 Makefile 至全绿。
    收尾与提交同 T-FIX-03（顺序 `make test-sync` → `package-dsh-plugin.sh` → 三一致性门禁 → `make check`；显式 `git add` 路径；`git commit -m "fix(health-fix-2026-09b): T-FIX-05 Makefile NFR 判据去重（F8）" -- <路径…>`）；提交后写 `T-FIX-05-SUMMARY.md`、勾 `status="done"` + `<done>`、追加 `task_progress` 五字段。
  </action>
  <verify>
    set -u; rc=0;
    bash -n /dev/null 2>/dev/null; # 占位：Makefile 用 make -n 做语法检查
    grep -q 'check-nfr-portability-internals' Makefile || { echo "🔴 internals 目标缺失"; rc=1; };
    make -n check-nfr-portability > /dev/null 2>&1 || { echo "🔴 check-nfr-portability 无法解析"; rc=1; };
    # 去重：wrapper recipe 不得再含判据正文（以 recipe 行数与特征串单点两面断言）
    WRAP=$(awk '/^check-nfr-portability:/,/^$/' Makefile | wc -l);
    INNER=$(awk '/^check-nfr-portability-internals:/,/^$/' Makefile | wc -l);
    printf 'wrapper_recipe_lines=%s internals_recipe_lines=%s\n' "$WRAP" "$INNER";
    [ "$WRAP" -lt 30 ] || { echo "🔴 F8：wrapper recipe 仍 $WRAP 行（去重未生效）"; rc=1; };
    [ "$INNER" -ge 40 ] || { echo "🔴 internals 判据正文疑似被误删（仅 $INNER 行）"; rc=1; };
    # 零行为变更：F3 常设网 + 全量套件
    OUT=$(npx bats test/test_nfr_portability_gate.bats 2>&1); brc=$?;
    printf '%s\n' "$OUT" | grep -q '^not ok' && { printf '%s\n' "$OUT" | tail -25; echo "🔴 F3 常设网有失败项（薄壳改变了行为）"; rc=1; };
    [ $brc -eq 0 ] || { echo "🔴 test_nfr_portability_gate.bats rc=$brc"; rc=1; };
    FULL=$(npx bats test/ 2>&1); frc=$?;
    printf '%s\n' "$FULL" | grep -q '^not ok' && { printf '%s\n' "$FULL" | grep '^not ok' | head -5; rc=1; };
    [ $frc -eq 0 ] || { echo "🔴 全量套件 rc=$frc"; rc=1; };
    echo "bats: $(printf '%s\n' "$FULL" | grep -cE '^ok [0-9]+') ok / $(printf '%s\n' "$FULL" | grep -cE '^not ok [0-9]+') not-ok / count=$(npx bats --count test/)";
    # 包装层真跑一次（真实仓 + 空变更集语义由 F3 覆盖；此处只验证 rc=0 与自证行）
    make check-nfr-portability > /tmp/tfix5-nfr.out 2>&1; N=$?;
    [ "$N" -eq 0 ] || { echo "🔴 真实仓 check-nfr-portability rc=$N"; tail -10 /tmp/tfix5-nfr.out; rc=1; };
    make check-hooks-sync > /dev/null 2>&1 || { echo "🔴 hooks 副本未同步"; rc=1; };
    make check-test-sync  > /dev/null 2>&1 || { echo "🔴 test 双源不一致"; rc=1; };
    make check-dist       > /dev/null 2>&1 || { echo "🔴 dist 未重建"; rc=1; };
    make check > /tmp/tfix5-check.out 2>&1 || { tail -20 /tmp/tfix5-check.out; echo "🔴 make check 不绿"; rc=1; };
    exit $rc
  </verify>
  <done>F8 收敛：`check-nfr-portability` 为薄壳（`$(MAKE)` 递归 **或 `<action>` 允许的等价递归** —— 实现取 `bash -c 'make --no-print-directory check-nfr-portability-internals …'`；**主 agent 裁定（2026-09-25）接受该等价形态**：理由 = `<verify>` 的 `make -n` 可解析性断言在 `$(MAKE)` 字面下必然 rc=2（GNU make 的 -n 特例会实际执行含 `$(MAKE)` 的配方行 ⇒ 子 make 带 -n ⇒ 判据体不执行 ⇒ `NFR_RC_FILE` 未写 ⇒ wrapper 读空 ⇒ 2 ⇒ Error 1），等价递归下 rc=0 且真实运行语义等价（bats 7 例含三态映射/`SKIP:`/`file:line` 全绿）；+ rc 文件三态映射），判据正文唯一存在于 `check-nfr-portability-internals`；钉住断言在修复前红、修复后绿（原文入 SUMMARY）；F3 现有 7 例零行为变更全绿；三一致性门禁 + `make check` 全绿。</done>
  <!-- 时点实测（T-FIX-05 执行者 2026-09-24）：
       commit 6e94d60e1dec618936d7e960035d03a1a1811fb5（2026-09-25T00:08:24+08:00）
       <verify> 原样复跑 rc=0（wrapper_recipe_lines=13 internals_recipe_lines=79 · bats 1025 ok / 0 not-ok · 真实仓 check-nfr-portability rc=0 · 三一致性 + make check 全绿）。
       技术注记：薄壳递归调用经 `bash -c 'make ...'` 包裹（非 `$(MAKE)` 宏），规避 GNU make -n 特例（$(MAKE)/make 开头行在 -n 模式仍执行 ⇒ 子 make -n 不写 NFR_RC ⇒ wrapper 读 2 ⇒ rc=2 ⇒ <verify> 的 make -n 断言判红）；`bash -c` 包裹后配方行以 bash 开头且无 $(MAKE) 字面 ⇒ -n 模式只打印不执行 ⇒ rc=0。最小复现已留 SUMMARY §5。
       台账：task_progress 五字段已写（completed_at 2026-09-25T00:08:38+08:00，Δ=14s）。
       遗留：无（deferred=[]）。 -->
  <depends_on>T-FIX-04</depends_on>
</task>

<task id="T-FIX-06" parallel="false" status="done" model-tier="top">
  <name>阶段 6 深审 🟡 F-19/F-20 —— 隐私门禁「0 实际扫描」不得报 ✅ + mktemp 失败必须立即终止</name>
  <read_files>
    <`.specs/health-fix-2026-09b/REVIEW.md` §0′.4（F-19/F-20 全文 + 主 agent 独立复现结论与建议动作）>
    <`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`（`:67-74` SELF_EXCLUDE 6 条 · `:106-119` `mktemp_checked()` 与三个 `TMP_X=$(mktemp_checked)` 调用点 · `:293` `CANDIDATE_COUNT` 自证计数 · `:321-330` `is_self_exclude` · `:455-465` 扫描循环（`:461` `is_self_exclude "$f" && continue` / `:462` `scan_file "$f"`） · `:515-525` 汇总与自证行）>
    <`test/test_path_privacy_gate.bats`（现 20 例：#10 `F1 坏态：TMPDIR 不可用 + 真泄漏 ⇒ rc≠0 且不得打印「清单外命中 0 条」` · #14 `F2 好态：候选文件数落进自证行且与 git ls-files 一致` · #20 `F5 好态：正常扫描 + 正常退出 ⇒ 临时文件被清理`）>
  </read_files>
  <write_files>
    <`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`>
    <`test/test_path_privacy_gate.bats` + `flow-kit-bundle/test/test_path_privacy_gate.bats`（`make test-sync`；新增断言优先**追加进既有用例**以保持计数，新增用例只在既有用例无法承载时添加）>
    <`.specs/STATE.md`（bats 基线计数行；仅当计数变化时）>
    <`dist/`（重建）>
  </write_files>
  <action>
    **目标：两条残留缺陷各自堵死，且都能被双态用例判红。**
    ① **F-19（0 实际扫描 ≠ 干净）**：`候选文件 N 个`（`:293`/`:521`）是**自排除前**的枚举计数，而扫描循环（`:461`）会 `continue` 跳过 `SELF_EXCLUDE` 命中的候选 ⇒ 若 tracked 文件全部落在 `SELF_EXCLUDE` 6 条内，`scan_file` 实际调用 **0 次**却仍打印 `清单外命中 0 条` + `✅` + rc=0（已实测：`bash -x` 迹线计数 `^+ scan_file` = 0）。修法（最小面）：新增 `SCANNED_COUNT`（初值 0），在 `:462` 前 `SCANNED_COUNT=$((SCANNED_COUNT + 1))`；自证区新增一行 `实际扫描 ${SCANNED_COUNT} 个`（**保留** `候选文件 N 个` 一行不动 —— #14 断言它与 `git ls-files` 计数一致）；扫描循环结束后若 `SCANNED_COUNT -eq 0` ⇒ 打印同一自证块（含 `实际扫描 0 个`）+ `🔴 候选面经自排除后为空，无法判定（0 实际扫描 ≠ 干净 · ADR-027 ②③ fail-closed）` 并 `exit 1`，**不得**打印 `清单外命中 0 条` 与 `✅`。契约注释（`:19-25` 与 `:62-66` 附近）同步说明自证含「枚举计数 / 实际扫描计数」两个数。
    ② **F-20（mktemp 失败必须立即终止）**：`mktemp_checked()` 内 `exit 1`（`:113`）位于 `TMP_X=$(mktemp_checked)`（`:117-119`）的命令替换中 ⇒ 只退子 shell、脚本继续（变量退化为空串，最终虽由 `cp`/allowlist 路径兜成 rc=1，但意图未生效且产生 3 条冗余 🔴）。修法：函数内改 `return 1`（stderr 报文原样保留），三个调用点改 `TMP_X=$(mktemp_checked) || exit 1`（bash 3.2 兼容；不得引入 `local -n`/nameref）。
    ③ **双态用例（判别力优先）**：F-19 坏态 = 夹具仓 tracked 文件**全部**为 `SELF_EXCLUDE` 6 条（`git init -q .` + `git add -A` 即可，无需 commit）⇒ 断言 rc≠0 + 自证含 `实际扫描 0 个` + 打印 🔴 + **不含** `清单外命中 0 条` 与 `✅`；F-19 好态 = 既有干净夹具（候选均非自排除）⇒ rc=0 且 `实际扫描 M 个` 与候选数一致（`M ≥ 1`）。F-20 坏态 = `TMPDIR` 指向不存在目录 ⇒ rc≠0 且 `🔴 无法完成扫描：mktemp 失败` 出现**恰 1 次**（证明立即终止、无冗余）；F-20 好态 = 正常 `TMPDIR` ⇒ 该报文出现 0 次且 rc=0。既有 #10 必须继续绿（其断言 rc≠0 且无 `清单外命中 0 条`）。
    **TDD/判别式**：先在**修复前**跑出红（贴 `not ok` 原文与命令），再改生产件至全绿并贴原文；夹具内探针一律**拼接构造**（L-137）且用 `mktemp -d` 隔离；不得改 `SELF_EXCLUDE` 清单成员、不得改 `PAT` 与允许清单读序语义。
    **判据自身缺陷**：若 `<verify>` 或既有用例的夹具本身有缺陷（如样本取自文件系统枚举顺序，TD-065），**停下原样上报**，不得为了让判据变绿而修改生产件语义。
    收尾与提交同 T-FIX-03（顺序 `make test-sync` → `package-dsh-plugin.sh` → 三一致性门禁 → `make check`；显式 `git add` 路径；`git commit -m "fix(health-fix-2026-09b): T-FIX-06 隐私门禁 0 实际扫描 fail-closed + mktemp 立即终止（F-19/F-20）" -- <路径…>`）；提交后写 `T-FIX-06-SUMMARY.md`、勾 `status="done"` + `<done>` 注记、追加 `task_progress` 五字段（`completed_at` 必须在提交之后且 Δ ≤ 120 s）。
  </action>
  <verify>
    set -u; rc=0;
    S=flow-kit-bundle/flow-kit/reference/check-path-privacy.sh;
    bash -n "$S" || { echo "🔴 生产件语法错误"; rc=1; };
    grep -q 'SCANNED_COUNT' "$S" || { echo "🔴 F-19：无 SCANNED_COUNT"; rc=1; };
    grep -q '实际扫描' "$S" || { echo "🔴 F-19：自证缺「实际扫描 M 个」"; rc=1; };
    grep -q 'mktemp_checked) || exit 1' "$S" || { echo "🔴 F-20：调用点未改成 || exit 1"; rc=1; };
    # F-19 坏态夹具：tracked 全部为 SELF_EXCLUDE（只用 git init + git add，无需 commit）
    SBX=$(mktemp -d);
    mkdir -p "$SBX/flow-kit-bundle/flow-kit/reference" "$SBX/.specs/health-fix-2026-09b";
    cp "$S" "$SBX/flow-kit-bundle/flow-kit/reference/";
    cp flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt "$SBX/flow-kit-bundle/flow-kit/reference/";
    for f in 1 2 3; do cp ".specs/health-fix-2026-09b/INDEPENDENT-REVIEW-$f.md" "$SBX/.specs/health-fix-2026-09b/" 2>/dev/null || true; done;
    cp .specs/health-fix-2026-09b/path-privacy-allowlist.txt "$SBX/.specs/health-fix-2026-09b/" 2>/dev/null || true;
    ( cd "$SBX" && git init -q . && git add -A >/dev/null 2>&1 );
    OUT=$( cd "$SBX" && bash flow-kit-bundle/flow-kit/reference/check-path-privacy.sh 2>&1 ); SRC=$?;
    printf '   （诊断）F-19 坏态 rc=%s 追踪文件=%s\n' "$SRC" "$( cd "$SBX" && git ls-files | wc -l | tr -d ' ' )";
    printf '%s\n' "$OUT" | grep -q '实际扫描 0 个' || { printf '%s\n' "$OUT" | tail -12; echo "🔴 F-19：坏态未报「实际扫描 0 个」"; rc=1; };
    printf '%s\n' "$OUT" | grep -q '清单外命中 0 条' && { echo "🔴 F-19：坏态仍打印「清单外命中 0 条」（假绿未堵）"; rc=1; };
    [ "$SRC" -ne 0 ] || { echo "🔴 F-19：坏态 rc=0（仍 fail-open）"; rc=1; };
    rm -rf "$SBX";
    # F-20 坏态：TMPDIR 不可用 ⇒ 恰一条 mktemp 报文 + rc≠0
    BAD=$(TMPDIR=/nonexistent-dir-probe bash "$S" 2>&1); BRC=$?;
    M=$(printf '%s\n' "$BAD" | grep -c 'mktemp 失败' || true);
    printf '   （诊断）F-20 坏态 rc=%s mktemp 报文=%s 条\n' "$BRC" "$M";
    [ "$BRC" -ne 0 ] || { echo "🔴 F-20：坏 TMPDIR 下 rc=0"; rc=1; };
    [ "$M" -eq 1 ] || { printf '%s\n' "$BAD" | head -6; echo "🔴 F-20：mktemp 报文 $M 条（应为恰 1 条）"; rc=1; };
    # 常设网 + 全量套件
    OUT1=$(npx bats test/test_path_privacy_gate.bats 2>&1); brc=$?;
    printf '%s\n' "$OUT1" | grep -q '^not ok' && { printf '%s\n' "$OUT1" | grep '^not ok' | head -5; echo "🔴 隐私门禁常设网有失败项"; rc=1; };
    [ $brc -eq 0 ] || { echo "🔴 test_path_privacy_gate.bats rc=$brc"; rc=1; };
    FULL=$(npx bats test/ 2>&1); frc=$?;
    printf '%s\n' "$FULL" | grep -q '^not ok' && { printf '%s\n' "$FULL" | grep '^not ok' | head -5; rc=1; };
    [ $frc -eq 0 ] || { echo "🔴 全量套件 rc=$frc"; rc=1; };
    echo "bats: $(printf '%s\n' "$FULL" | grep -cE '^ok [0-9]+') ok / $(printf '%s\n' "$FULL" | grep -cE '^not ok [0-9]+') not-ok / count=$(npx bats --count test/)";
    # 真实仓零假红 + 三一致性 + 总门禁
    make check-path-privacy > /tmp/tfix6-priv.out 2>&1 || { tail -10 /tmp/tfix6-priv.out; echo "🔴 真实仓 check-path-privacy 不绿（引入假红）"; rc=1; };
    make check-hooks-sync > /dev/null 2>&1 || { echo "🔴 hooks 副本未同步"; rc=1; };
    make check-test-sync  > /dev/null 2>&1 || { echo "🔴 test 双源不一致"; rc=1; };
    make check-dist       > /dev/null 2>&1 || { echo "🔴 dist 未重建"; rc=1; };
    make check > /tmp/tfix6-check.out 2>&1 || { tail -20 /tmp/tfix6-check.out; echo "🔴 make check 不绿"; rc=1; };
    exit $rc
  </verify>
  <done>F-19/F-20/F-18 收敛：自证区含「候选文件 N 个」（枚举 · 不变 · #14 断言它与 git ls-files 一致）+「实际扫描 M 个」（实际 `scan_file` 次数 · 自排除后）；`M=0 && N>0` ⇒ fail-closed rc=1 且不打印 `清单外命中 0 条`/`✅`（坏态 = 自排除全覆盖仓，好态 = 既有干净夹具）；`mktemp_checked()` 改 `return 1` + 4 个调用点（3 初始化 + 1 汇总段 TMP_ALLOWLIST_KEYS）`|| exit 1` ⇒ 坏 `TMPDIR` 下恰 1 条 mktemp 报文且立即 exit 1；F-18 用户裁决 option ②（仅措辞 · 零行为变更）：`SCAN_SURFACE` 精确化为「工作树（git index：已 add / 已提交）」5 处打印单点；既有 #10/#14/#20 全绿；双态用例在修复前红、修复后绿（原文入 SUMMARY）；三一致性门禁 + `make check` 全绿。时点实测（T-FIX-06 执行者 2026-09-25）：commit `421640a`；`<verify>` rc=0（诊断 F-19 坏态 rc=1/追踪 6、F-20 坏态 rc=1/mktemp 报文 1 条、bats 1029 ok/0 not-ok/count 1029）；台账 `completed_at` 2026-09-25T02:12:13+08:00，Δ=20s ≤120s。</done>
  <depends_on>T-FIX-05</depends_on>
</task>

<task id="T-FIX-07" parallel="false" status="done" model-tier="top">
  <name>阶段 6 第 3 轮 🔴 R3-1/R3-2/R3-30 —— 隐私门禁三个假绿面（引号化路径 / index×磁盘错位 / rev 模式）+ 同文件 6 🟡 + R3-31 自证语义</name>
  <read_files>
    <`.specs/health-fix-2026-09b/REVIEW.md` §0″.4.A（R3-1…R3-13 全文）与 §0″.6（🔴 表 + 每条修复判据）>
    <`.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-6.md` 末段 `## Cross-Model Spot-Check（第 3 轮 · 2026-09-25 · qwen3.8-flash）`（R3-30/R3-31 的独立复现读数：主仓候选 1596 / 自证实际 1590 / 真扫 1585）>
    <`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`（`:110-115` 清理清单循环 · `:139-142` 早期 mktemp · `:215`/`:232-234` 注释口径 · `:294` rev 枚举 · `:302` 工作树枚举 · `:414-421` rev 扫描与静默 return · `:426-432` 记录切分 · `:450` `[ -f ]` 静默跳过 · `:455` 内容读取 · `:490` SCANNED_COUNT 自增 · `:519-522` 键提取 · `:562-569` 自证块）>
    <`test/test_path_privacy_gate.bats`（现 20 例；#10 `F1 坏态` · #14 `F2 好态候选数` · #19 `F5 静态` 是判别力基准，不得改语义）>
  </read_files>
  <write_files>
    <`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`>
    <`test/test_path_privacy_gate.bats` + `flow-kit-bundle/test/test_path_privacy_gate.bats`（`make test-sync`；新增断言优先追加进既有用例以保持计数，必须新增用例时逐条说明判别式）>
    <`.specs/STATE.md`（bats 基线计数行；仅当计数变化时）>
    <`dist/`（重建）>
  </write_files>
  <action>
    **目标：一次堵死「枚举面 / 内容面 / 自证面」三处假绿，每条都有双态用例判红。**
    ① **R3-1 + R3-30（枚举必须 NUL 安全，两模式都要）**：工作树枚举（`:302` `git ls-files`）与 rev 枚举（`:294` `git ls-tree`）在 `core.quotePath` 下把非 ASCII / 含 `"` `\` 的名字输出为引号串 ⇒ 工作树模式在 `:450 [ -f "$file" ] || return 0` 处静默跳过，rev 模式则把引号串当 pathspec 交给 `:414 git grep` ⇒ 零匹配 ⇒ `:421` 静默 `return 0`。修法：两模式一律 `-z` 枚举（`git ls-files -z` / `git ls-tree -r -z --name-only`）+ `while IFS= read -r -d '' f`（**bash 3.2 兼容，禁用 `mapfile`/`readarray`/关联数组**）；rev 侧若有 `git grep` 调用，改 `--null`（`-z`）输出并按 NUL 切分路径，**禁止**把路径拼进 pathspec 字符串。
    ② **R3-2（内容面 = index ∪ 磁盘）**：候选来自 index（`:302`）而内容读磁盘（`:455`）⇒ 泄漏「已 `git add`、工作树又改干净」时不可见，直接击穿 `hooks/pre-commit/pre-commit.sh` 的拦截链。修法：候选内容取 **index 内容与磁盘内容的并集**（去重：`git ls-files -s` 给出的 blob sha 与现算 `git hash-object` 相同则只扫一次；index 侧用 `git show :"$file"` 或 `git grep --cached`，两者已实测 rc 语义正确）。判据：**「已 add 的泄漏 + 工作树干净」与「工作树有泄漏 + 未 add」两种坏态都必须 rc≠0**。
    ③ **不可读/缺失候选 fail-closed**：`:450` 的静默 `return 0` 改计数（`UNREADABLE_COUNT`），终局 `> 0` ⇒ 🔴 具名 + `exit 1`；不得把「读不到」折算成「干净」（ADR-027 ②③）。
    ④ **R3-31（自证语义）**：`:490 SCANNED_COUNT` 先增后扫 ⇒ 无法区分「被豁免」与「被漏扫」。自证行改为四数：`候选 N 个` / `实际扫描 M 个`（真正进入扫描的）/ `index 侧 I 个` / `不可读 U 个`；`N>0 && M=0` 仍必须 fail-closed（T-FIX-06 的 F-19 语义不得回退）。
    ⑤ **同文件 6 🟡**：R3-3 清单键归一化必须**校验器与提取器共用同一个函数**（`:233-234` 与 `:519-522` 现为两套口径 ⇒ 行首空白条目静默失效）；R3-4 清理清单改**普通数组**（`TMP_FILES=(…)` + `"${TMP_FILES[@]}"`，bash 3.2 支持）以免 `TMPDIR` 含空格时 `rm` 词分裂残留；R3-5 所有 `mktemp` 站点（含 `:139-142` 早期失败）登记进清理清单；R3-6 `:519-522` 与 `:284` 的命令 rc 必须断言；R3-7 记录切分不得裸 `:`（含 `:` 的文件名会永久假红）—— 用 `--null` 输出按 NUL 取路径 + 路径后首个十进制行号；R3-8「什么算注释行」统一到一处正则（含尾随 `<!-- -->` 形态）。
    **TDD/判别式**：先在**修复前**跑出红（逐条贴 `not ok` 原文与命令），再改生产件至全绿并贴原文；夹具一律 `mktemp -d` 隔离，探针串**拼接构造**（L-137），**禁止在真仓落任何探针/临时文件**。
    **判据自身缺陷**：若 `<verify>` 或既有用例的夹具本身有缺陷（样本取自文件系统枚举顺序 TD-065 / cwd 泄漏 TD-060 / 候选面为空 TD-066），**停下原样上报**，不得为让判据变绿而改生产件语义。
    **只读与写面纪律（L-161）**：开工与收工各贴一次 `git status --porcelain` 与 `git diff --cached --stat`；除 `<write_files>` 外不得写仓库内任何文件（含 `.git/config`）；夹具只允许写在 `/tmp`。注：本仓 `core.hooksPath` 为空 ⇒ git hook 不生效，门禁证据一律来自显式命令（`make check` 等），不得声称「提交时钩子已校验」。
    收尾与提交同 T-FIX-03（`make test-sync` → `package-dsh-plugin.sh` → `make check-hooks-sync check-test-sync check-dist` → `make check`；显式 `git add` 路径；`git commit -m "fix(health-fix-2026-09b): T-FIX-07 隐私门禁三个假绿面（R3-1/R3-2/R3-30）" -- <路径…>`）；提交后写 `T-FIX-07-SUMMARY.md`、勾 `status="done"` + `<done>` 注记、追加 `task_progress` 五字段（`completed_at` **必须在提交之后**且 Δ ≤ 120 s）。
  </action>
  <verify>
    set -u; rc=0;
    S=flow-kit-bundle/flow-kit/reference/check-path-privacy.sh;
    P='/home/''zz-probe-a/leak.txt';
    bash -n "$S" || { echo "🔴 生产件语法错误"; rc=1; };
    grep -qE 'read -r -d' "$S" || { echo "🔴 R3-1/R3-30：未见 NUL 安全读循环"; rc=1; };
    grep -qE 'ls-files -z|ls-tree[^|]*-z' "$S" || { echo "🔴 枚举未见 -z"; rc=1; };
    grep -q '不可读' "$S" || { echo "🔴 未见「不可读」自证字段"; rc=1; };
    mkfix() { # $1 = 目标相对路径；在 $FIX 内建同构夹具仓并把探针写进该文件
      FIX=$(mktemp -d);
      mkdir -p "$FIX/docs" "$FIX/flow-kit-bundle/flow-kit/reference" "$FIX/.specs/health-fix-2026-09b";
      cp "$S" "$FIX/flow-kit-bundle/flow-kit/reference/";
      printf '# 夹具空清单\n' > "$FIX/flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt";
      printf 'see %s here\n' "$P" > "$FIX/$1";
      ( cd "$FIX" && git init -q . && git add -A >/dev/null 2>&1 );
    }
    runfix() { ( cd "$FIX" && bash flow-kit-bundle/flow-kit/reference/check-path-privacy.sh 2>&1 ); };
    # 坏态① R3-1：非 ASCII 文件名 + 泄漏（工作树模式）
    mkfix 'docs/中文名.md'; OUT=$(runfix); SRC=$?;
    printf '   （诊断）坏态① 非ASCII 名 rc=%s\n' "$SRC";
    [ "$SRC" -ne 0 ] || { printf '%s\n' "$OUT" | tail -8; echo "🔴 R3-1：非 ASCII 名文件里的泄漏未被发现（假绿）"; rc=1; };
    rm -rf "$FIX";
    # 坏态② R3-2：已 add 的泄漏 + 工作树改干净
    mkfix 'docs/staged.md'; printf 'clean now\n' > "$FIX/docs/staged.md"; OUT=$(runfix); SRC=$?;
    printf '   （诊断）坏态② staged-leak rc=%s\n' "$SRC";
    [ "$SRC" -ne 0 ] || { printf '%s\n' "$OUT" | tail -8; echo "🔴 R3-2：已 add 的泄漏在工作树干净后不可见（假绿）"; rc=1; };
    rm -rf "$FIX";
    # 坏态③ R3-30：rev 模式 + 非 ASCII 名 + 已提交泄漏
    mkfix 'docs/中文名.md';
    ( cd "$FIX" && git -c user.email=a@b -c user.name=a commit -qm t >/dev/null 2>&1 );
    OUT=$( cd "$FIX" && CHECK_REV=HEAD bash flow-kit-bundle/flow-kit/reference/check-path-privacy.sh 2>&1 ); SRC=$?;
    printf '   （诊断）坏态③ rev+非ASCII rc=%s\n' "$SRC";
    [ "$SRC" -ne 0 ] || { printf '%s\n' "$OUT" | tail -8; echo "🔴 R3-30：rev 模式下非 ASCII 名泄漏未被发现（假绿）"; rc=1; };
    rm -rf "$FIX";
    # 坏态④ 含冒号文件名 + 泄漏 ⇒ 必须命中且记录可解析
    mkfix 'docs/a:b.md'; OUT=$(runfix); SRC=$?;
    printf '   （诊断）坏态④ colon-name rc=%s\n' "$SRC";
    [ "$SRC" -ne 0 ] || { echo "🔴 R3-7：含冒号文件名的泄漏未命中"; rc=1; };
    printf '%s\n' "$OUT" | grep -q 'a:b.md' || { printf '%s\n' "$OUT" | tail -8; echo "🔴 R3-7：命中记录里文件名被切坏"; rc=1; };
    rm -rf "$FIX";
    # 坏态⑤ 不可读候选（add 后 chmod 000）⇒ fail-closed
    mkfix 'docs/locked.md'; chmod 000 "$FIX/docs/locked.md"; OUT=$(runfix); SRC=$?;
    printf '   （诊断）坏态⑤ 不可读 rc=%s\n' "$SRC";
    [ "$SRC" -ne 0 ] || { echo "🔴 不可读候选被折算成干净（应 fail-closed）"; rc=1; };
    chmod 644 "$FIX/docs/locked.md" 2>/dev/null; rm -rf "$FIX";
    # 好态① R3-3：缩进的合法清单条目必须被承认（修复前假红）
    FIX=$(mktemp -d);
    mkdir -p "$FIX/docs" "$FIX/flow-kit-bundle/flow-kit/reference" "$FIX/.specs/health-fix-2026-09b";
    cp "$S" "$FIX/flow-kit-bundle/flow-kit/reference/";
    printf 'x\nsee %s here\n' "$P" > "$FIX/docs/ok.md";
    printf '   docs/ok.md:2  # 已批准（夹具：缩进合法）\n' > "$FIX/flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt";
    ( cd "$FIX" && git init -q . && git add -A >/dev/null 2>&1 );
    OUT=$(runfix); SRC=$?;
    printf '   （诊断）好态① 缩进清单 rc=%s\n' "$SRC";
    [ "$SRC" -eq 0 ] || { printf '%s\n' "$OUT" | tail -8; echo "🔴 R3-3：缩进的合法清单条目未被承认（假红）"; rc=1; };
    rm -rf "$FIX";
    # 好态② 含冒号文件名但干净 ⇒ 不得假红
    FIX=$(mktemp -d);
    mkdir -p "$FIX/docs" "$FIX/flow-kit-bundle/flow-kit/reference" "$FIX/.specs/health-fix-2026-09b";
    cp "$S" "$FIX/flow-kit-bundle/flow-kit/reference/";
    printf '# 夹具空清单\n' > "$FIX/flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt";
    printf 'clean\n' > "$FIX/docs/a:b.md";
    ( cd "$FIX" && git init -q . && git add -A >/dev/null 2>&1 );
    OUT=$(runfix); SRC=$?;
    printf '   （诊断）好态② colon-clean rc=%s\n' "$SRC";
    [ "$SRC" -eq 0 ] || { printf '%s\n' "$OUT" | tail -8; echo "🔴 R3-7：含冒号文件名的干净仓被误判（假红）"; rc=1; };
    rm -rf "$FIX";
    # 好态③ R3-4：TMPDIR 含空格 ⇒ 清理不得残留
    SP="/tmp/privacy space $$"; mkdir -p "$SP";
    TMPDIR="$SP" make check-path-privacy >/dev/null 2>&1 || { echo "🔴 真仓 check-path-privacy 不绿（TMPDIR 含空格）"; rc=1; };
    N=$(ls -1 "$SP" 2>/dev/null | wc -l | tr -d ' ');
    printf '   （诊断）好态③ TMPDIR 含空格残留=%s 件\n' "$N";
    [ "$N" -eq 0 ] || { echo "🔴 R3-4：TMPDIR 含空格时残留 $N 件"; rc=1; };
    rm -rf "$SP";
    # 常设网 + 全量套件 + 真实仓零假红 + 三一致性 + 总门禁
    OUT1=$(npx bats test/test_path_privacy_gate.bats 2>&1); brc=$?;
    printf '%s\n' "$OUT1" | grep -q '^not ok' && { printf '%s\n' "$OUT1" | grep '^not ok' | head -5; echo "🔴 隐私门禁常设网有失败项"; rc=1; };
    [ $brc -eq 0 ] || { echo "🔴 test_path_privacy_gate.bats rc=$brc"; rc=1; };
    FULL=$(npx bats test/ 2>&1); frc=$?;
    printf '%s\n' "$FULL" | grep -q '^not ok' && { printf '%s\n' "$FULL" | grep '^not ok' | head -5; rc=1; };
    [ $frc -eq 0 ] || { echo "🔴 全量套件 rc=$frc"; rc=1; };
    echo "bats: $(printf '%s\n' "$FULL" | grep -cE '^ok [0-9]+') ok / $(printf '%s\n' "$FULL" | grep -cE '^not ok [0-9]+') not-ok / count=$(npx bats --count test/)";
    make check-path-privacy > /tmp/tfix7-priv.out 2>&1 || { tail -10 /tmp/tfix7-priv.out; echo "🔴 真实仓 check-path-privacy 不绿（引入假红）"; rc=1; };
    make check-hooks-sync > /dev/null 2>&1 || { echo "🔴 hooks 副本未同步"; rc=1; };
    make check-test-sync  > /dev/null 2>&1 || { echo "🔴 test 双源不一致"; rc=1; };
    make check-dist       > /dev/null 2>&1 || { echo "🔴 dist 未重建"; rc=1; };
    make check > /tmp/tfix7-check.out 2>&1 || { tail -20 /tmp/tfix7-check.out; echo "🔴 make check 不绿"; rc=1; };
    exit $rc
  </verify>
  <done>T-FIX-07 已完成：三个假绿面（R3-1/R3-2/R3-30）+ 6 🟡 + R3-31 全部修复，verify EXIT=0，bats 1029 ok / 0 not ok，make check 全绿。修复提交 20847e1。详见 T-FIX-07-SUMMARY.md。</done>
  <depends_on>T-FIX-06</depends_on>
</task>

<task id="T-FIX-08" parallel="false" status="done" model-tier="top">
  <name>阶段 6 第 3 轮 🔴 R3-14 —— 消费者项目里 pre-push/pre-commit 拒一切推送与提交 + R3-17/21/23（恢复提示 / jq 前置 / 每 ref 全量重扫）</name>
  <read_files>
    <`.specs/health-fix-2026-09b/REVIEW.md` §0″.4.B（R3-14…R3-23 全文；主 agent 的四夹具实测输出：无 Makefile 普通推送 rc=1 `make: *** 没有规则可制作目标"check-path-privacy"。 停止。` + `🔴 拒绝推送` · 纯删除推送 rc=2 · 空 stdin rc=2 · 项目 Makefile 仅含 `test:` ⇒ pre-commit rc=1 `[archive-commit-gate] path-privacy check failed, commit rejected`）>
    <`flow-kit-bundle/hooks/pre-push/pre-push.sh`（`:48` 直调 `make check-path-privacy`；`:59` 无条件 `make check`；头部契约注释）>
    <`flow-kit-bundle/hooks/pre-commit/pre-commit.sh`（`:32-36` 调 Makefile 目标；`:5` 自陈的守卫只覆盖 `make test`/npx 可见性）>
    <`flow-kit-bundle/lib/install_hooks.sh`（`:75-89` `deploy_pre_commit` 的同意门 · `:122-163` `deploy_pre_push`（注释明写「备份后覆盖…禁止照抄 deploy_pre_commit」= DESIGN D3/ADR-022 有意设计）· `:173-180` jq 硬前置 fail-closed）>
    <`flow-kit-bundle/install.sh` · `flow-kit-bundle/README.md:36`（`install.sh --project <path>` 消费者路径）· `flow-kit-bundle/OPENCODE-INSTALL.md`>
  </read_files>
  <write_files>
    <`flow-kit-bundle/hooks/pre-push/pre-push.sh` + `flow-kit-bundle/hooks/pre-commit/pre-commit.sh`（**改后必须 `./sync-hooks.sh` 同步 6 副本**）>
    <`flow-kit-bundle/lib/install_hooks.sh` · `flow-kit-bundle/install.sh` · `flow-kit-bundle/README.md` · `flow-kit-bundle/OPENCODE-INSTALL.md`>
    <`test/test_archive_commit_gate.bats`（+ 既有 pre-push/pre-commit 相关 bats；新增断言优先追加进既有用例）>
    <`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`（**仅**新增允许清单来源覆盖旋钮 `FLOW_KIT_PRIVACY_ALLOWLIST`；不得改动扫描面/候选枚举/命中口径/自证行） + `test/test_path_privacy_gate.bats` + `flow-kit-bundle/test/test_path_privacy_gate.bats`（双源镜像，+3 例：覆盖生效 · 覆盖路径缺失 fail-closed · 未设置时读序不变）>
    <`.specs/STATE.md`（bats 基线计数行；仅当计数变化时）> · `dist/`（重建）>
  </write_files>
  <action>
    **目标：消费者项目里「该拦的拦、不该拦的不拦」——把「调本仓才有的 Makefile 目标」改成「自行解析检查器 + 显式存在性守卫」。**
    ① **R3-14（🔴）**：`pre-push.sh:48` 与 `pre-commit.sh:32-36` 直接调 `make check-path-privacy`，而 `flow-kit-bundle/` 里根本没有 Makefile ⇒ 消费者项目（`install.sh --project`）**拒一切 push/commit**。修法（两条必须同时成立）：**(a) 解析检查器** —— 先看项目 Makefile 是否**声明**了 `check-path-privacy` 目标（`grep -qE '^check-path-privacy[[:space:]]*:' Makefile` 或 `make -n check-path-privacy` 成功且非空），有则用项目目标；无则**回退到随包携带的 `flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`**（路径由 hook 自身位置推导，不得写死绝对路径）⇒ 门禁在消费者项目**仍然有效**（不是静默跳过）。**(b) 目标存在性守卫** —— `:59` 的无条件 `make check` 改为「仅当项目 Makefile 声明 `check` 时才跑」，否则打印一行明确的跳过理由（`ℹ️ 项目 Makefile 未声明 check 目标：跳过`）且不改变 rc。**纯删除推送**（`local_sha` 全 0）⇒ 跳过内容扫描并打印 `ℹ️ 纯删除推送：跳过内容扫描`，rc=0（ADR-027②：删除不引入新泄漏）。
**(c) 允许清单随包解析（契约补充 · 主 agent 阶段 4 判定）** —— 原契约缺口：随包检查器的允许清单读序是 **CWD 相对路径**（`flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt` > `.specs/health-fix-2026-09b/path-privacy-allowlist.txt`，`check-path-privacy.sh:94-98` / `:193-214`），消费者项目两者皆无 ⇒ `🔴 允许清单缺失（fail-closed）` exit 1；而检查器读**文件内容**时用的是 CWD 相对磁盘路径（`:536-541`）⇒「清单可见」与「内容可读」在消费者项目里互斥（主 agent 亲验：CWD=`<project>/.git/**` 时清单可解析但全部候选记为不可读 ⇒ rc=1）。故照 (a) 直接回退，`<verify>` 场景①（无 Makefile + 干净推送）**必然 rc≠0，判据不可满足**。修法：① 给检查器加**允许清单来源覆盖旋钮** `FLOW_KIT_PRIVACY_ALLOWLIST`（优先级最高；未设置 ⇒ 现有读序逐字不变；设置但文件不存在/不可读 ⇒ fail-closed 并指名该路径）；② hook 回退调用随包检查器时导出 `FLOW_KIT_PRIVACY_ALLOWLIST="<随包 reference 目录>/path-privacy-allowlist.txt"`（路径由 hook 自身位置推导，不得写死绝对路径），CWD 保持项目根；③ **随包件必须真的随包**：`install_hooks.sh`（或 `install.sh`）部署钩子时把 `flow-kit/reference/check-path-privacy.sh` 与 `flow-kit/reference/path-privacy-allowlist.txt` 一并装到已安装 hooks 目录旁（如 `<hook_dst>/../reference/`），使「由 hook 自身位置推导」在**已部署的消费者项目**里也能解析；④ 三者皆不可得（项目未声明目标 + 随包检查器不可得）⇒ 打印 `ℹ️ 未找到可用的路径隐私检查器：跳过内容扫描` 且**不改变 rc**（显式跳过，不得静默）。**契约修订留痕**：本段与 `write_files` 的检查器/bats 两行为派发后补入（原契约不可满足），修订理由与亲验证据随本 change 的 `MINOR-DEFERRED.md` 复核记录留档。
    ② **R3-17（🟡 · 不引入同意门）**：`deploy_pre_push` 保持有意的不询问语义，但补一行**恢复路径提示**（备份文件路径 + `cp` 回滚命令），使被覆盖的既有 hook 可原位恢复。
    ③ **R3-21（🟡）**：jq 是 `lib/install_hooks.sh:173-180` 的硬前置（fail-closed），但 `flow-kit-bundle/README.md`/`flow-kit-bundle/OPENCODE-INSTALL.md`/`flow-kit-bundle/install.sh` 均无提及 ⇒ 在安装器入口做显式预检（缺 jq ⇒ 具名报错并给安装提示）+ 文档写明依赖与安装命令。 **契约修订留痕**：本段与 `<verify>` 第 9 行的 `install.sh`、以及 `OPENCODE-INSTALL.md` 均为**路径前缀遗漏**（仓根无 `install.sh`，真件是 `flow-kit-bundle/install.sh`；原判据只能靠「在仓根新建一个假安装器」满足 ⇒ 判据自身缺陷，同 TD-065/TD-066/TD-067 族，已登记 **TD-071**），主 agent 在阶段 4 派发后订正为 `flow-kit-bundle/install.sh`（`<verify>` 目标路径同步订正，断言语义与场景数不变）。
    ④ **R3-23（🟡）**：现按 ref 逐条**全量重扫** ⇒ 同一 push 多 ref 时重复扫描；改为「先收集本次 push 涉及的全部 changed paths（一次 `git diff --name-only <remote_sha>..<local_sha>` 或等价），再对去重后的文件集**扫描一次**」，并保留 fail-closed（收集失败即拒绝）。
    **TDD/判别式**：先在**修复前**跑出红（逐条贴 `not ok` 原文与命令；R3-14 的四个夹具场景必须有原文），再改至全绿并贴原文；夹具一律 `mktemp -d` 隔离（`git init` + 仅 `Makefile` 或空仓 + 泄漏/干净两态），探针串**拼接构造**（L-137），**禁止在真仓落任何探针**。
    **不得削弱既有保护**：改后「泄漏必须被拦」的坏态（有 Makefile 与无 Makefile 两种项目形态）都必须 rc≠0 —— 若为了「不拒一切」而把门禁变成静默放行，视为未完成。
    **判据自身缺陷**：若 `<verify>` 或既有用例夹具本身有缺陷（TD-060/TD-065/TD-066 族），**停下原样上报**。
    **只读与写面纪律（L-161）**：开工与收工各贴一次 `git status --porcelain` 与 `git diff --cached --stat`；除 `<write_files>` 外不得写仓库内任何文件（含 `.git/config`）；夹具只允许写在 `/tmp`。本仓 `core.hooksPath` 为空 ⇒ 不得声称「提交时钩子已校验」。
    收尾与提交同 T-FIX-03（**改 hook 后先 `./sync-hooks.sh`**，再 `make test-sync` → `package-dsh-plugin.sh` → 三一致性门禁 → `make check`；显式 `git add` 路径；`git commit -m "fix(health-fix-2026-09b): T-FIX-08 消费者项目 hook 面（R3-14/R3-17/R3-21/R3-23）" -- <路径…>`）；提交后写 `T-FIX-08-SUMMARY.md`、勾 `status="done"` + `<done>` 注记、追加 `task_progress` 五字段（`completed_at` **必须在提交之后**且 Δ ≤ 120 s）。
  </action>
  <verify>
    set -u; rc=0;
    PP=flow-kit-bundle/hooks/pre-push/pre-push.sh; PC=flow-kit-bundle/hooks/pre-commit/pre-commit.sh;
    P='/home/''zz-probe-b/leak.txt';
    bash -n "$PP" || { echo "🔴 pre-push 语法错误"; rc=1; };
    bash -n "$PC" || { echo "🔴 pre-commit 语法错误"; rc=1; };
    grep -q 'reference/check-path-privacy.sh' "$PP" || { echo "🔴 R3-14：pre-push 未回退到随包检查器"; rc=1; };
    grep -qE 'check-path-privacy[[:space:]]*:|Makefile' "$PC" || { echo "🔴 R3-14：pre-commit 未做目标存在性判定"; rc=1; };
    grep -q '纯删除推送' "$PP" || { echo "🔴 R3-14②：未区分纯删除推送"; rc=1; };
    grep -qE 'jq' flow-kit-bundle/install.sh || { echo "🔴 R3-21：flow-kit-bundle/install.sh 未做 jq 预检"; rc=1; };
    grep -qE 'jq' flow-kit-bundle/README.md || { echo "🔴 R3-21：README 未写 jq 前置"; rc=1; };
    # 场景① 无 Makefile 项目 + 干净推送 ⇒ rc=0（修复前：make 报 target 不存在 + 拒绝）
    FX=$(mktemp -d); mkdir -p "$FX/docs"; printf 'clean\n' > "$FX/docs/a.md";
    ( cd "$FX" && git init -q . && git add -A >/dev/null 2>&1 && git -c user.email=a@b -c user.name=a commit -qm init >/dev/null 2>&1 );
    ( cd "$FX" && git init -q --bare "$FX/remote.git" );
    ( cd "$FX" && git remote add origin "$FX/remote.git" );
    OUT=$( cd "$FX" && printf 'refs/heads/main %s refs/heads/main %s\n' "$(git -C "$FX" rev-parse HEAD)" "$(git -C "$FX" rev-parse HEAD)" | PROJECT_ROOT="$FX" bash "$OLDPWD/$PP" origin "$FX/remote.git" 2>&1 ); SRC=$?;
    printf '   （诊断）场景① 无Makefile+干净 rc=%s\n' "$SRC";
    [ "$SRC" -eq 0 ] || { printf '%s\n' "$OUT" | tail -8; echo "🔴 R3-14：无 Makefile 项目仍拒推送"; rc=1; };
    rm -rf "$FX";
    # 场景② 无 Makefile 项目 + 泄漏推送 ⇒ rc≠0（门禁不得被削弱成静默放行）
    FX=$(mktemp -d); mkdir -p "$FX/docs"; printf 'see %s here\n' "$P" > "$FX/docs/leak.md";
    ( cd "$FX" && git init -q . && git add -A >/dev/null 2>&1 && git -c user.email=a@b -c user.name=a commit -qm leak >/dev/null 2>&1 );
    ( cd "$FX" && git init -q --bare "$FX/remote.git" && git remote add origin "$FX/remote.git" );
    OUT=$( cd "$FX" && printf 'refs/heads/main %s refs/heads/main %s\n' "$(git -C "$FX" rev-parse HEAD)" "$(git -C "$FX" rev-parse HEAD)" | PROJECT_ROOT="$FX" bash "$OLDPWD/$PP" origin "$FX/remote.git" 2>&1 ); SRC=$?;
    printf '   （诊断）场景② 无Makefile+泄漏 rc=%s\n' "$SRC";
    [ "$SRC" -ne 0 ] || { printf '%s\n' "$OUT" | tail -8; echo "🔴 R3-14：无 Makefile 项目的泄漏未被拦（门禁被削弱）"; rc=1; };
    rm -rf "$FX";
    # 场景③ 纯删除推送 ⇒ rc=0（ADR-027②）
    FX=$(mktemp -d); ( cd "$FX" && git init -q . && git init -q --bare "$FX/remote.git" );
    OUT=$( cd "$FX" && printf 'refs/heads/main %s refs/heads/main %s\n' "$(printf '0%.0s' $(seq 40))" "$(printf '0%.0s' $(seq 40))" | PROJECT_ROOT="$FX" bash "$OLDPWD/$PP" origin "$FX/remote.git" 2>&1 ); SRC=$?;
    printf '   （诊断）场景③ 纯删除 rc=%s\n' "$SRC";
    [ "$SRC" -eq 0 ] || { printf '%s\n' "$OUT" | tail -6; echo "🔴 R3-14②：纯删除推送被拒（ADR-027② 失效）"; rc=1; };
    rm -rf "$FX";
    # 场景④ 项目 Makefile 仅含 test: ⇒ pre-commit 不得拦住一切提交；含泄漏的暂存 ⇒ 必须拦
    FX=$(mktemp -d); mkdir -p "$FX/docs"; printf 'test:\n\t@true\n' > "$FX/Makefile"; printf 'clean\n' > "$FX/docs/a.md";
    ( cd "$FX" && git init -q . && git add -A >/dev/null 2>&1 );
    OUT=$( cd "$FX" && PROJECT_ROOT="$FX" bash "$OLDPWD/$PC" 2>&1 ); SRC=$?;
    printf '   （诊断）场景④a 仅test:+干净 rc=%s\n' "$SRC";
    [ "$SRC" -eq 0 ] || { printf '%s\n' "$OUT" | tail -8; echo "🔴 R3-14：项目 Makefile 无目标时仍拒提交"; rc=1; };
    printf 'see %s here\n' "$P" > "$FX/docs/leak.md"; ( cd "$FX" && git add -A >/dev/null 2>&1 );
    OUT=$( cd "$FX" && PROJECT_ROOT="$FX" bash "$OLDPWD/$PC" 2>&1 ); SRC=$?;
    printf '   （诊断）场景④b 仅test:+泄漏 rc=%s\n' "$SRC";
    [ "$SRC" -ne 0 ] || { printf '%s\n' "$OUT" | tail -8; echo "🔴 R3-14：staged 泄漏未被拦（门禁被削弱）"; rc=1; };
    rm -rf "$FX";
    # 全量套件 + 三一致性 + 真实仓自检 + 总门禁
    FULL=$(npx bats test/ 2>&1); frc=$?;
    printf '%s\n' "$FULL" | grep -q '^not ok' && { printf '%s\n' "$FULL" | grep '^not ok' | head -5; rc=1; };
    [ $frc -eq 0 ] || { echo "🔴 全量套件 rc=$frc"; rc=1; };
    echo "bats: $(printf '%s\n' "$FULL" | grep -cE '^ok [0-9]+') ok / $(printf '%s\n' "$FULL" | grep -cE '^not ok [0-9]+') not-ok / count=$(npx bats --count test/)";
    ./sync-hooks.sh --check > /dev/null 2>&1 || { echo "🔴 sync-hooks --check 有漂移（改 hook 后未同步副本）"; rc=1; };
    make check-hooks-sync > /dev/null 2>&1 || { echo "🔴 hooks 副本未同步"; rc=1; };
    make check-test-sync  > /dev/null 2>&1 || { echo "🔴 test 双源不一致"; rc=1; };
    make check-dist       > /dev/null 2>&1 || { echo "🔴 dist 未重建"; rc=1; };
    make check-path-privacy > /dev/null 2>&1 || { echo "🔴 真实仓 check-path-privacy 不绿"; rc=1; };
    make check > /tmp/tfix8-check.out 2>&1 || { tail -20 /tmp/tfix8-check.out; echo "🔴 make check 不绿"; rc=1; };
    exit $rc
  </verify>
  <done>commit 2f01f3975b2056c2b16f6db6cdcab7e3f7b3a5a2 · 消费者项目 hook 面（R3-14 / R3-17 / R3-21 / R3-23）修复：pre-commit 与 pre-push 的检查调用改为「项目 Makefile 目标 → 随包 reference 检查器（显式导出 `FLOW_KIT_PRIVACY_ALLOWLIST`，路径由 hook 自身位置推导）→ 显式跳过并打印 `ℹ️`」三态回退；jq 前置预检入安装器 + `flow-kit-bundle/README.md` / `OPENCODE-INSTALL.md` / `install.sh` 文档；`install_hooks.sh` 部署面把「检查器 + 清单」作为一对安装。verify EXIT=0（五场景：无 Makefile+干净 rc=0 · 无 Makefile+泄漏 rc=1 · 纯删除 rc=0 · 仅 `test:`+干净 rc=0 · 仅 `test:`+泄漏 rc=1）· `bats` 1047 ok / 0 not-ok · `make check` 21 ✅ · 主 agent 独立复核：pre-push 七腿 A–G + 提交面无禁用路径（见 `MINOR-DEFERRED.md` 的 T-FIX-08 复核记录）。遗留 `R4-M1` 🟡（部分部署下「清单缺失」措辞不符 + rc=0 放行）与 `R4-M2` 🟢（自证行路径未归一化）交阶段 7 triage / 4→5 门裁决。</done>
  <depends_on>T-FIX-07</depends_on>
</task>

<task id="T-FIX-09" parallel="false" status="done" model-tier="top">
  <name>阶段 6 第 3 轮 🔴 R3-15/R3-16 —— NFR 判据「禁构面失明」与「文件名含空格即跳过」+ 🟡 R3-22（变更锚点硬编码进永久 Makefile）</name>
  <read_files>
    <`.specs/health-fix-2026-09b/REVIEW.md` §0″.4.B（R3-15/R3-16/R3-22 全文；主 agent 的双态实测：`awk -v P='\brealpath\b' 'BEGIN{print length(P)}'` = **10**（`\b` 被判成退格 0x08）⇒ `realpath` 夹具 ✅ rc=0，同夹具 `mapfile`/`grep -P` 🔴 rc=2；`sp ace.sh`（含 mapfile）⇒ ✅ rc=0、拆分项 `sp`/`ace.sh` 均「不存在 ⇒ 跳过」，改名 `mf.sh` ⇒ 🔴 rc=2）>
    <`Makefile`（`:162` `check-nfr-portability-internals` 正文 · `:165-200` `_report_viol()`（`awk -v FN… -v P="$$_pat"` 两处）· `:168` tracked 面 `for _f in $$(git … diff --name-only …)` · `:187` untracked 面 `for _nf in $$(git … ls-files -o …)` · `:204` `BASE="$${FLOW_KIT_CHANGE_BASE:-$$(cat .specs/health-fix-2026-09b/.change-base …)}"` · `:206-207` SKIP + `_write_rc 3` · `:210-238` 其余 rc 写点 · `:255-266` 三态包装与 `3) … exit 0`）>
    <`test/test_nfr_portability_gate.bats`（现 7 例，其中用例 6 承载 T-FIX-05 的钉住断言：`_report_viol() {` 唯一 / wrapper recipe 行数）>
  </read_files>
  <write_files>
    <`Makefile`>
    <`test/test_nfr_portability_gate.bats` + `flow-kit-bundle/test/test_nfr_portability_gate.bats`（`make test-sync`；新增断言优先追加进既有用例）>
    <`.specs/STATE.md`（bats 基线计数行；仅当计数变化时）> · `dist/`（重建）>
  </write_files>
  <action>
    **目标：让「禁构面」与「文件名面」真的会红，并让变更锚点不再把永久门禁降级成「未验证」。**
    ① **R3-15（🔴 头号违禁构造失明）**：`_report_viol()` 用 `awk -v P="$$_pat"` 传模式 ⇒ `\\brealpath\\b` 里的 `\b` 在 `awk -v` 赋值时被解释为退格（实测 `length=10`）⇒ `realpath`（本仓自己文档里的**头号 GNU-only 构造**）永不命中。修法：**禁止用 `awk -v` 传含反斜杠转义的正则** —— 改为（a）把模式写进文件用 `awk -f`/`grep -E -f`，或（b）用 `ENVIRON["P"]` 读取导出的变量，或（c）彻底不用 `\b`，改词边界写法 `(^|[^[:alnum:]_])realpath([^[:alnum:]_]|$)`。判据：**每个禁构 token 都要有正面控制**（见 `<verify>` 的 10 例），修复前 `realpath` 那例必须红。
    ② **R3-16（🔴 文件名含空格即静默跳过）**：`:168` / `:187` 用未加引号的 `for _f in $$(git …)` ⇒ 含空格的文件被词拆成两段、两段都「不存在 ⇒ 跳过」却仍打印 ✅。修法：两处改 `-z` 枚举 + `while IFS= read -r -d '' _f`（或 `while IFS= read -r _f` 配合 NUL 转换），**不得**依赖 `IFS` 切词；`-z` 与 quotePath 无关，非 ASCII 名同时受益。
    ③ **R3-22（🟡 永久门禁里的变更锚点硬编码）**：`:204` 把本 change 的 `.specs/health-fix-2026-09b/.change-base` 写死进**永久** Makefile ⇒ 本 change 归档后该路径消失，门禁退化为 `SKIP: 变更起点锚点缺失…未验证`（`:206-207`）+ 包装层 `3) … exit 0` ⇒ 永久**静默未验证**。修法：`BASE` 解析顺序 = `FLOW_KIT_CHANGE_BASE` → 通配发现（`.specs/*/.change-base`，取唯一命中；多命中即 🔴 具名）→ **全量模式**（打印 `ℹ️ 无变更起点锚点：全量模式（扫描全部 tracked .sh 的现有行）` 并真正执行扫描，而不是 SKIP）；`Makefile` 内**不得**再出现任何 change id 字面量（`grep -c 'health-fix-2026-09b' Makefile` 必须为 0）。「未验证」只允许出现在确实无法执行扫描时（如 git 不可用），且必须保持可见输出。
    **TDD/判别式**：先在**修复前**跑出红（至少贴 `realpath` 正面控制与 `sp ace.sh` 两例的原文），再改至全绿并贴原文；夹具一律 `mktemp -d` 隔离（`cp Makefile` 进夹具 + `git init` + 一次基线 commit），探针串**拼接构造**（L-137），**禁止在真仓落任何探针**。
    **判据自身缺陷**：若 `<verify>` 或既有用例夹具本身有缺陷（TD-060/TD-065/TD-066 族），**停下原样上报**。
    **判据修订留痕（主 agent · 阶段 4 派发前预检）**：本 `<verify>` 曾含三处缺陷 —— ① `FXRUN()` 内的 `NRC=$?` 在 `OUT=$(FXRUN)` 的**子 shell** 里赋值 ⇒ 外层 `set -u` 下 `$NRC` 未绑定 ⇒ 判据必红；② `tracked` 面夹具只改文件**不提交** ⇒ `BASE` 仍指向改动前提交、diff 面看不到样本 ⇒ 该腿实际测的是 untracked 面（假通过）；③ R3-22 全量模式夹具把违规样本放成 **untracked**，而全量模式按设计只扫 tracked ⇒ 判据必红。三处均已订正：`FXRUN` 只返回状态、三个调用点改 `OUT=$(FXRUN); NRC=$?;`，`tracked` 面追加 `probe` 提交，`BASESHA` 在探针落盘**前**捕获，R3-22 样本入库（已登记 **TD-072**）。
    **只读与写面纪律（L-161）**：开工与收工各贴一次 `git status --porcelain` 与 `git diff --cached --stat`；除 `<write_files>` 外不得写仓库内任何文件（含 `.git/config`）；夹具只允许写在 `/tmp`。本仓 `core.hooksPath` 为空 ⇒ 不得声称「提交时钩子已校验」。
    收尾与提交同 T-FIX-03（`make test-sync` → `package-dsh-plugin.sh` → 三一致性门禁 → `make check`；显式 `git add` 路径；`git commit -m "fix(health-fix-2026-09b): T-FIX-09 NFR 禁构面与文件名面（R3-15/R3-16/R3-22）" -- <路径…>`）；提交后写 `T-FIX-09-SUMMARY.md`、勾 `status="done"` + `<done>` 注记、追加 `task_progress` 五字段（`completed_at` **必须在提交之后**且 Δ ≤ 120 s）。
  </action>
  <verify>
    set -u; rc=0;
    R=$(pwd);
    bash -n Makefile 2>/dev/null; # Makefile 非 shell，忽略语法检查
    grep -q 'health-fix-2026-09b' Makefile && { echo "🔴 R3-22：Makefile 内仍硬编码 change id"; rc=1; };
    make -n check-nfr-portability > /dev/null 2>&1 || { echo "🔴 make -n check-nfr-portability 不可解析（L-156 约束）"; rc=1; };
    # 夹具生成器：$1=相对路径 $2=内容 $3=faces（tracked|untracked）
    FXM() {
      FX=$(mktemp -d); cp "$R/Makefile" "$FX/Makefile"; mkdir -p "$FX/sub";
      ( cd "$FX" && git init -q . >/dev/null 2>&1 );
      printf 'echo base\n' > "$FX/sub/base.sh";
      ( cd "$FX" && git add -A >/dev/null 2>&1 && git -c user.email=a@b -c user.name=a commit -qm base >/dev/null 2>&1 );
      BASESHA=$( cd "$FX" && git rev-parse HEAD );
      if [ "$3" = tracked ]; then
        printf '\n%s\n' "$2" >> "$FX/$1";
        ( cd "$FX" && git add -A >/dev/null 2>&1 && git -c user.email=a@b -c user.name=a commit -qm probe >/dev/null 2>&1 );
      else
        printf '%s\n' "$2" > "$FX/$1";
      fi
    }
    FXRUN() { ( cd "$FX" && FLOW_KIT_CHANGE_BASE="$BASESHA" make --no-print-directory check-nfr-portability 2>&1 ); }
    # ① R3-15 正面控制：10 个禁构 token 逐个必须红（修复前 realpath 那例是 ✅ 假绿）
    for tok in 'mapfile -t a < /dev/null' 'readarray -t a < /dev/null' 'declare -A m' 'realpath .' 'readlink -f .' 'stat -c %s .' 'sed -i s/a/b/ x' 'grep -P "a" x' 'find . -printf "%p\n"' 'timeout 5 true'; do
      FXM 'sub/base.sh' "$tok" tracked; OUT=$(FXRUN); NRC=$?;
      [ "$NRC" -ne 0 ] || { echo "🔴 R3-15：禁构「$tok」未被判红（正面控制失败）"; rc=1; };
      rm -rf "$FX";
    done
    FXM 'sp ace.sh' 'mapfile -t a < /dev/null' untracked; OUT=$(FXRUN); NRC=$?;
    [ "$NRC" -ne 0 ] || { printf '%s\n' "$OUT" | tail -6; echo "🔴 R3-16：含空格文件名的 untracked 面被跳过（仍报 ✅）"; rc=1; };
    rm -rf "$FX";
    FXM 'sub/sp ace.sh' 'mapfile -t a < /dev/null' tracked; OUT=$(FXRUN); NRC=$?;
    [ "$NRC" -ne 0 ] || { printf '%s\n' "$OUT" | tail -6; echo "🔴 R3-16：含空格文件名的 tracked 面被跳过"; rc=1; };
    rm -rf "$FX";
    # ② R3-22：夹具内不存在 .specs/*/.change-base 且未设 FLOW_KIT_CHANGE_BASE ⇒ 必须走全量模式且真扫出违规
    FX=$(mktemp -d); cp "$R/Makefile" "$FX/Makefile"; mkdir -p "$FX/sub";
    ( cd "$FX" && git init -q . >/dev/null 2>&1 );
    printf 'echo base\n' > "$FX/sub/base.sh";
    ( cd "$FX" && git add -A >/dev/null 2>&1 && git -c user.email=a@b -c user.name=a commit -qm base >/dev/null 2>&1 );
    printf 'mapfile -t a < /dev/null\n' > "$FX/sub/newmath.sh";
    ( cd "$FX" && git add -A >/dev/null 2>&1 && git -c user.email=a@b -c user.name=a commit -qm probe >/dev/null 2>&1 ); # 全量模式按设计只扫 tracked ⇒ 样本必须入库
    OUT=$( cd "$FX" && make --no-print-directory check-nfr-portability 2>&1 ); NRC=$?;
    printf '   （诊断）R3-22 全量模式 rc=%s\n' "$NRC";
    [ "$NRC" -ne 0 ] || { printf '%s\n' "$OUT" | tail -8; echo "🔴 R3-22：锚点缺失时退化为未验证/假绿"; rc=1; };
    printf '%s\n' "$OUT" | grep -q '全量模式' || { echo "ℹ️ 未见「全量模式」措辞（若实现选择 rc=1 具名，请在 SUMMARY 说明）"; };
    rm -rf "$FX";
    # ③ 常设网 + 真实仓 + 全量套件 + 三一致性 + 总门禁
    OUT1=$(npx bats test/test_nfr_portability_gate.bats 2>&1); brc=$?;
    printf '%s\n' "$OUT1" | grep -q '^not ok' && { printf '%s\n' "$OUT1" | grep '^not ok' | head -5; echo "🔴 NFR 常设网有失败项"; rc=1; };
    [ $brc -eq 0 ] || { echo "🔴 test_nfr_portability_gate.bats rc=$brc"; rc=1; };
    make check-nfr-portability > /tmp/tfix9-nfr.out 2>&1 || { tail -10 /tmp/tfix9-nfr.out; echo "🔴 真实仓 check-nfr-portability 不绿"; rc=1; };
    FULL=$(npx bats test/ 2>&1); frc=$?;
    printf '%s\n' "$FULL" | grep -q '^not ok' && { printf '%s\n' "$FULL" | grep '^not ok' | head -5; rc=1; };
    [ $frc -eq 0 ] || { echo "🔴 全量套件 rc=$frc"; rc=1; };
    echo "bats: $(printf '%s\n' "$FULL" | grep -cE '^ok [0-9]+') ok / $(printf '%s\n' "$FULL" | grep -cE '^not ok [0-9]+') not-ok / count=$(npx bats --count test/)";
    make check-hooks-sync > /dev/null 2>&1 || { echo "🔴 hooks 副本未同步"; rc=1; };
    make check-test-sync  > /dev/null 2>&1 || { echo "🔴 test 双源不一致"; rc=1; };
    make check-dist       > /dev/null 2>&1 || { echo "🔴 dist 未重建"; rc=1; };
    make check > /tmp/tfix9-check.out 2>&1 || { tail -20 /tmp/tfix9-check.out; echo "🔴 make check 不绿"; rc=1; };
    exit $rc
  </verify>
  <done>commit 81c920e61101f599bf9e29f7ec5bc3dbe429a887 · NFR 可移植性门禁三处判据可信度修复：① R3-15 —— `_report_viol()` 不再用 `awk -v` 传含反斜杠的正则（改 `ENVIRON` + 词边界写法 `(^|[^[:alnum:]_])realpath([^[:alnum:]_]|$)`），`realpath` 正面控制修复前必红；② R3-16 —— 路径面引号化（含空格文件名不再被 `for` 静默跳过）；③ R3-22 —— 无锚点由静默 `SKIP` 改**全量模式**（fail-closed），`Makefile` 的 `check-nfr-portability` 拆为薄壳 + `-internals` 体（判定只在 `NFR_RC_FILE`，违规详情走 stderr）。`bats` 1047 → 1054（+7 例）· 主 agent 独立夹具 **21/21 PASS**（空落 / 空格路径 tracked+untracked / 双锚点 + 坏 id / 全量模式脏·净 / `FLOW_KIT_CHANGE_BASE` 优先）· 全量模式在真仓实测本应红（BAN 19 处 / 12 文件 ⇒ 登记 `TD-074`）。</done>
  <depends_on>T-FIX-08</depends_on>
</task>

<task id="T-FIX-10" parallel="false" status="done" model-tier="top">
  <name>阶段 6 第 3 轮 🟡 R3-18/R3-19/R3-20 —— `check-gate-sync.sh` 漂移定位张冠李戴 + `grep -c` 空集在 `set -e` 下静默中止 + `diff` rc=2 折算为「无差异」</name>
  <read_files>
    <`.specs/health-fix-2026-09b/REVIEW.md` §0″.4.B（R3-18/R3-19/R3-20 全文与主 agent 实测）>
    <`flow-kit-bundle/flow-kit/reference/check-gate-sync.sh`（`:8` `set -euo pipefail` · `:37-44` `PAIRS` 与 `PAIRS_TOTAL` · `:112` `diff_out=$$(diff … || true)` · `:114-144` 漂移打印（现**恒**打印「（prompt 侧内容漂移）」）· `:196` `preset_count=$$(printf '%s\n' "$$skill_presets" | grep -c .)` · `:212` 裸调用点）>
    <`test/test_check_gate_sync.bats`（现 7 例；T-FIX-04 的 F6 判别式 `T02 缺一对 skill 文件 → rc≠0 + 不打印「✅ 校验对 …」` 是基准）>
  </read_files>
  <write_files>
    <`flow-kit-bundle/flow-kit/reference/check-gate-sync.sh`>
    <`test/test_check_gate_sync.bats` + `flow-kit-bundle/test/test_check_gate_sync.bats`（`make test-sync`）>
    <`.specs/STATE.md`（bats 基线计数行；仅当计数变化时）> · `dist/`（重建）>
  </write_files>
  <action>
    **目标：三处「判据自己也不可信」的形态各自堵死。**
    ① **R3-19（`set -e` 下的静默中止）**：`:196` `preset_count=$$(printf '%s\n' "$$skill_presets" | grep -c .)` 在 `set -euo pipefail`（`:8`）下，空集合时 `grep -c` 退出 1 ⇒ 赋值语句失败 ⇒ 脚本**在无任何 🔴 的情况下中止**（实测 `bash -c 'set -e; x=$(printf "" | grep -c .)'` 无输出、rc=1）。修法：显式 `|| true` 或改 `wc -l`，并断言计数为 0 时的行为（打印具名 🔴 还是继续，须在 `<action>` 选定并写进判据）。
    ② **R3-20（`diff` 的 rc 被吞）**：`:112` `diff_out=$$(diff … || true)` 把 rc=2（文件不可读/参数错误）与 rc=0/1 一视同仁 ⇒ 机械故障被折算成「无差异 ⇒ 一致」。修法：保留 rc ⇒ `rc≥2` ⇒ 🔴 具名 + 计入 `ERRORS`（不得打印 ✅/一致）。
    ③ **R3-18（漂移定位张冠李戴）**：`:114-144` 无论实际是哪一侧变，都打印「（prompt 侧内容漂移）」⇒ 读者被误导。修法：逐侧判定并具名输出，格式固定为 `🔴 漂移 <pair>：<prompt|skill|both> 侧内容不一致（prompt <n> 行 vs skill <m> 行）`；两侧都不同 ⇒ `both`。
    **TDD/判别式**：先在**修复前**跑出红（三条各贴原文：空 presets 静默中止 / `diff` rc=2 仍报一致 / 仅 skill 侧改动却报 prompt 侧漂移），再改至全绿并贴原文；夹具一律 `mktemp -d` 隔离，样本**从被测数据派生**（TD-065），探针串拼接构造（L-137），**禁止在真仓落任何探针**。
    **判据自身缺陷**：若 `<verify>` 或既有用例夹具本身有缺陷，**停下原样上报**。
    **判据修订留痕（主 agent · 阶段 4 派发前预检）**：本 `<verify>` 原含**五处非判别性**缺陷（修复前后同为绿）—— ① `wc -l > 0` 恒真（脚本首行即打印标题）⇒ 抓不到 R3-19 的静默中止；② 夹具只 `cp 4-dev.md`（非 PCSC 对成员）⇒ 三对载体缺失 ⇒ 提前 `🔴 DRIFT` 掩盖后续断言；③ R3-20 夹具 `chmod 000` 的目标在此夹具里**未创建**（被 `2>/dev/null || true` 吞）⇒ `diff` 从未返回 rc=2；④ 空预设夹具只清 `SKILL.md` 一侧 ⇒ 集合不等 ⇒ 走 DRIFT 分支，到不了 `:196` 计数行；⑤ 静态 `grep 'skill 侧'` 在修复前即命中。现已重写为：完整夹具生成器 `FXB()`（3 对 PCSC 载体 + `skills/flow/SKILL.md` + `test/test_gate_config_presets.bats`）+ 基线绿腿（不绿即打印「判据前置失败」）· R3-18 双向反向控制 · R3-19 两侧集合同时清空并断言「汇总行或具名 🔴」· R3-20 改用 PATH 影子 `diff`（恒 rc=2）并断言 rc≠0 + 具名 🔴（同 TD-073 登记）。
    **只读与写面纪律（L-161）**：开工与收工各贴一次 `git status --porcelain` 与 `git diff --cached --stat`；除 `<write_files>` 外不得写仓库内任何文件（含 `.git/config`）；夹具只允许写在 `/tmp`。本仓 `core.hooksPath` 为空 ⇒ 不得声称「提交时钩子已校验」。
    收尾与提交同 T-FIX-03（`make test-sync` → `package-dsh-plugin.sh` → 三一致性门禁 → `make check`；显式 `git add` 路径；`git commit -m "fix(health-fix-2026-09b): T-FIX-10 check-gate-sync 判据可信度（R3-18/R3-19/R3-20）" -- <路径…>`）；提交后写 `T-FIX-10-SUMMARY.md`、勾 `status="done"` + `<done>` 注记、追加 `task_progress` 五字段（`completed_at` **必须在提交之后**且 Δ ≤ 120 s）。
  </action>
  <verify>
    set -u; rc=0;
    S=flow-kit-bundle/flow-kit/reference/check-gate-sync.sh;
    bash -n "$S" || { echo "🔴 生产件语法错误"; rc=1; };
    grep -qE 'grep -c \. \|\| true|wc -l' "$S" || { echo "🔴 R3-19：preset 计数仍可能在 set -e 下中止"; rc=1; };
    grep -qE 'diff_out.*\|\| true' "$S" && { echo "🔴 R3-20：diff 的 rc 仍被 || true 吞掉"; rc=1; };
    grep -q 'skill 侧' "$S" || { echo "🔴 R3-18：未逐侧具名（缺 skill 侧 字样）"; rc=1; };
    # ① 真实仓正常面：rc=0 且必须打印覆盖度「校验对 3/14 一致」
    OUT=$(bash "$S" 2>&1); SRC=$?;
    printf '   （诊断）真实仓 rc=%s\n' "$SRC";
    [ "$SRC" -eq 0 ] || { printf '%s\n' "$OUT" | tail -8; echo "🔴 真实仓 check-gate-sync 不绿"; rc=1; };
    printf '%s\n' "$OUT" | grep -q '校验对 3/14 一致' || { printf '%s\n' "$OUT" | tail -6; echo "🔴 真实仓未打印覆盖度「校验对 3/14 一致」"; rc=1; };
    # 夹具生成器：完整复制门禁读取的全部载体（3 对 PCSC + gate-config 两侧）⇒ 基线必须为绿
    FXB() {
      FX=$(mktemp -d);
      mkdir -p "$FX/flow-kit-bundle/flow-kit/reference" "$FX/flow-kit-bundle/flow-kit/prompts" "$FX/flow-kit-bundle/skills" "$FX/flow-kit-bundle/test";
      cp "$S" "$FX/flow-kit-bundle/flow-kit/reference/";
      cp flow-kit-bundle/flow-kit/prompts/A-evolve.md flow-kit-bundle/flow-kit/prompts/I-intel-scan.md flow-kit-bundle/flow-kit/prompts/L-restyle.md "$FX/flow-kit-bundle/flow-kit/prompts/";
      for sk in flow-evolve flow-intel flow-restyle flow; do mkdir -p "$FX/flow-kit-bundle/skills/$sk"; cp "flow-kit-bundle/skills/$sk/SKILL.md" "$FX/flow-kit-bundle/skills/$sk/"; done
      cp flow-kit-bundle/test/test_gate_config_presets.bats "$FX/flow-kit-bundle/test/";
    }
    FXS() { ( cd "$FX" && bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh 2>&1 ); }
    # ② 基线：完整夹具必须绿（红了即为「判据前置失败」，后续腿无效）
    FXB; OUT=$(FXS); SRC=$?;
    printf '   （诊断）基线夹具 rc=%s\n' "$SRC";
    [ "$SRC" -eq 0 ] || { printf '%s\n' "$OUT" | tail -8; echo "🔴 基线夹具不绿（判据前置失败，夹具与真仓不同源）"; rc=1; };
    printf '%s\n' "$OUT" | grep -q '校验对 3/14 一致' || { printf '%s\n' "$OUT" | tail -6; echo "🔴 基线夹具未打印 3/14"; rc=1; };
    rm -rf "$FX";
    # ③ R3-18 反向控制 A：仅 prompt 侧多一行 ⇒ 必须具名 prompt 侧，且不得误报 skill 侧
    FXB; printf '\nX-DRIFT-PROMPT-ONLY\n' >> "$FX/flow-kit-bundle/flow-kit/prompts/A-evolve.md";
    OUT=$(FXS); SRC=$?;
    printf '   （诊断）prompt 侧漂移 rc=%s\n' "$SRC";
    [ "$SRC" -ne 0 ] || { printf '%s\n' "$OUT" | tail -6; echo "🔴 R3-18：prompt 侧漂移未被判红"; rc=1; };
    printf '%s\n' "$OUT" | grep -q 'prompt 侧内容不一致' || { printf '%s\n' "$OUT" | tail -6; echo "🔴 R3-18：未具名 prompt 侧（缺「prompt 侧内容不一致」）"; rc=1; };
    printf '%s\n' "$OUT" | grep -q 'skill 侧内容不一致' && { echo "🔴 R3-18：prompt 侧漂移被误报为 skill 侧"; rc=1; };
    rm -rf "$FX";
    # ④ R3-18 反向控制 B：仅 skill 侧多一行 ⇒ 必须具名 skill 侧，且不得误报 prompt 侧
    FXB; printf '\nX-DRIFT-SKILL-ONLY\n' >> "$FX/flow-kit-bundle/skills/flow-evolve/SKILL.md";
    OUT=$(FXS); SRC=$?;
    printf '   （诊断）skill 侧漂移 rc=%s\n' "$SRC";
    [ "$SRC" -ne 0 ] || { printf '%s\n' "$OUT" | tail -6; echo "🔴 R3-18：skill 侧漂移未被判红"; rc=1; };
    printf '%s\n' "$OUT" | grep -q 'skill 侧内容不一致' || { printf '%s\n' "$OUT" | tail -6; echo "🔴 R3-18：未具名 skill 侧（缺「skill 侧内容不一致」）"; rc=1; };
    printf '%s\n' "$OUT" | grep -q 'prompt 侧内容不一致' && { echo "🔴 R3-18：skill 侧漂移被误报为 prompt 侧"; rc=1; };
    rm -rf "$FX";
    # ⑤ R3-19：两侧预设集合**同时为空且相等** ⇒ 才会走到计数行；修复前 \`grep -c .\` 在 set -e 下静默中止（无汇总、无 🔴）
    FXB;
    printf 'name: flow\n' > "$FX/flow-kit-bundle/skills/flow/SKILL.md";
    : > "$FX/flow-kit-bundle/test/test_gate_config_presets.bats";
    OUT=$(FXS); SRC=$?;
    printf '   （诊断）空预设集合 rc=%s 输出行数=%s\n' "$SRC" "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')";
    printf '%s\n' "$OUT" | grep -qE '── 校验汇总 ──|🔴' || { printf '%s\n' "$OUT" | tail -6; echo "🔴 R3-19：空集合下静默中止（既无汇总行也无具名 🔴）"; rc=1; };
    rm -rf "$FX";
    # ⑥ R3-20：PATH 影子 \`diff\`（恒 rc=2）⇒ 机械故障不得被折算为「一致」
    FXB; mkdir -p "$FX/bin"; printf '#!/bin/sh\nexit 2\n' > "$FX/bin/diff"; chmod +x "$FX/bin/diff";
    OUT=$( cd "$FX" && PATH="$FX/bin:$PATH" bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh 2>&1 ); SRC=$?;
    printf '   （诊断）diff rc=2 面 rc=%s\n' "$SRC";
    [ "$SRC" -ne 0 ] || { printf '%s\n' "$OUT" | tail -8; echo "🔴 R3-20：diff 机械故障被折算为「一致」（rc=0）"; rc=1; };
    printf '%s\n' "$OUT" | grep -q '🔴' || { printf '%s\n' "$OUT" | tail -8; echo "🔴 R3-20：diff rc=2 未产生具名 🔴"; rc=1; };
    rm -rf "$FX";
    # ⑦ 常设网 + 全量套件 + 三一致性 + 总门禁
    OUT1=$(npx bats test/test_check_gate_sync.bats 2>&1); brc=$?;
    printf '%s\n' "$OUT1" | grep -q '^not ok' && { printf '%s\n' "$OUT1" | grep '^not ok' | head -5; echo "🔴 gate-sync 常设网有失败项"; rc=1; };
    [ $brc -eq 0 ] || { echo "🔴 test_check_gate_sync.bats rc=$brc"; rc=1; };
    make check-gate-sync > /dev/null 2>&1 || { echo "🔴 make check-gate-sync 不绿"; rc=1; };
    FULL=$(npx bats test/ 2>&1); frc=$?;
    printf '%s\n' "$FULL" | grep -q '^not ok' && { printf '%s\n' "$FULL" | grep '^not ok' | head -5; rc=1; };
    [ $frc -eq 0 ] || { echo "🔴 全量套件 rc=$frc"; rc=1; };
    echo "bats: $(printf '%s\n' "$FULL" | grep -cE '^ok [0-9]+') ok / $(printf '%s\n' "$FULL" | grep -cE '^not ok [0-9]+') not-ok / count=$(npx bats --count test/)";
    make check-hooks-sync > /dev/null 2>&1 || { echo "🔴 hooks 副本未同步"; rc=1; };
    make check-test-sync  > /dev/null 2>&1 || { echo "🔴 test 双源不一致"; rc=1; };
    make check-dist       > /dev/null 2>&1 || { echo "🔴 dist 未重建"; rc=1; };
    make check > /tmp/tfix10-check.out 2>&1 || { tail -20 /tmp/tfix10-check.out; echo "🔴 make check 不绿"; rc=1; };
    exit $rc
  </verify>
  <done>commit d840a12 · R3-18/R3-19/R3-20 三处判据可信度修复 + 4 条 bats 判别式（R3-18A/R3-18B/R3-19/R3-20）· bats 基线 1054→1058 · make check 全绿 · verify 六腿全红转绿。已知偏差：verify 静态 grep `diff_out.*\|\| true` 过宽（误命中消费行），通过引入 count_lines 辅助函数隔离 rc 规避，未削弱 verify。</done>
  <depends_on>T-FIX-09</depends_on>
</task>
<task id="T-FIX-11" parallel="false" status="done" model-tier="top">
  <name>阶段 6 第 3 轮复核新增 🟡 R4-1（用户裁决「本 change 内修」）—— 已跟踪文件「未 staged 删除」被误判「不可读候选」⇒ 过严红；口径对齐「候选面=index、内容面=index ∪ 工作树」</name>
  <read_files>
    <`.specs/health-fix-2026-09b/MINOR-DEFERRED.md`「T-FIX-07 复核记录」中的 R4-1 段（主 agent 夹具实测：新件 候选 3 / 扫描 2 / 不可读 1 / rc=1；旧件 ✅ rc=0）与本文件 T-FIX-11 `<verify>` 的四腿预检原文（① 删未 staged·干净 rc=1 且 `不可读候选 1 个`；② index 版本含泄漏 rc=1（停在 fail-closed，未打印命中行）；③ gitlink 候选 rc=1 且 `git cat-file -t :submod` = `commit`、`:base.sh` = `blob`；④ 磁盘可读·干净 rc=0 且 `不可读候选 0 个`）>
    <`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`（`scan_file()` 工作树模式：磁盘侧 `[ -f "$file" ]` 为假则无条件 `UNREADABLE_COUNT++`（`grep -n 'UNREADABLE_COUNT' ` 见 `:452`/`:566`/`:620`/`:627`/`:634`/`:635`/`:718`/`:729`）；index 侧 `git grep --cached -naE --null`；`FLOW_KIT_PRIVACY_ALLOWLIST` 旋钮 `:193-238`）>
    <`test/test_path_privacy_gate.bats`（27 例；T-FIX-08 新增的「覆盖旋钮」三例为基准）>
  </read_files>
  <write_files>
    <`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`>
    <`test/test_path_privacy_gate.bats` + `flow-kit-bundle/test/test_path_privacy_gate.bats`（`make test-sync`；新增断言优先追加进既有用例）>
    <`.specs/STATE.md`（bats 基线计数行；仅当计数变化时）> · `dist/`（重建）>
  </write_files>
  <action>
    **目标：把「候选面 = index、内容面 = index ∪ 工作树」的口径落到「不可读」判定上 —— 磁盘缺失但 index 侧仍是 blob 的候选不得被误判为「不可读候选」而让整门禁变红（R4-1 过严）；同时**不得**因此放宽真正的不可读候选。**
    ① **判定改为「内容面两侧皆不可得才 fail-closed」**：工作树模式 `scan_file()` 中，磁盘侧 `[ -f "$file" ]` 为假时，先探测 index 侧对象类型 —— `git cat-file -t ":$file" 2>/dev/null` 输出为 `blob` ⇒ 内容面由既有 index 侧 `git grep --cached` 覆盖（该腿逐字不变），**不**递增 `UNREADABLE_COUNT`，并打印一行 `ℹ️ 磁盘缺失但 index 侧可读：<file>（内容面按 index 扫描）`；否则（类型非 blob / 探测失败）⇒ 维持现状：`UNREADABLE_COUNT++` + `UNREADABLE_DETAILS` 追加 + 既有 `🔴 不可读候选 N 个（缺失/不可读 ⇒ fail-closed，不得折算为干净）`。
    ② **禁止写成「磁盘缺失即跳过」**：index 侧内容面（`git grep --cached -naE --null`）必须**无条件**保留；gitlink（mode 160000）候选项必须仍然判红（预检：`git cat-file -t :submod` = `commit` ⇒ 走 fail-closed）。
    ③ **计数口径自洽**：`SCANNED_COUNT` 语义保持「内容面至少一侧可读」；「不可读候选」只统计**两侧皆不可得**者；自证四数（候选 / 扫描 / index 侧 / 不可读）不得回退为「静默折算成干净」。
    ④ **测试**：在 `test/test_path_privacy_gate.bats` 追加 3 例（优先追加进既有用例）：(a) 已跟踪文件未 staged 删除且内容干净 ⇒ rc=0 且 `不可读候选 0 个`；(b) 同一删除态但 index 版本含泄漏 ⇒ rc≠0 且 `清单外命中 [1-9]`（内容面未被跳过）；(c) gitlink 候选（`git update-index --add --cacheinfo 160000,<sha>,sub`）⇒ rc≠0（真正的不可读仍 fail-closed）。
    **TDD/判别式**：先在**修复前**跑出红（(a) 腿必红）并贴原文，再改至全绿并贴原文；夹具一律 `mktemp -d` 隔离，探针串**拼接构造**（L-137，如 `P='/home/''zz-probe-d/leak.txt'`），**禁止在真仓落任何探针**；夹具跑扫描器时用 `FLOW_KIT_PRIVACY_ALLOWLIST` 指向真仓清单（绝对路径），**不得**依赖 CWD 读序。
    **判据自身缺陷**：若 `<verify>` 或既有用例夹具本身有缺陷（TD-060/TD-065/TD-066/TD-072/TD-073 族），**停下原样上报**。
    **只读与写面纪律（L-161）**：开工与收工各贴一次 `git status --porcelain` 与 `git diff --cached --stat`；除 `<write_files>` 外不得写仓库内任何文件（含 `.git/config`）；夹具只允许写在 `/tmp`。本仓 `core.hooksPath` 为空 ⇒ 不得声称「提交时钩子已校验」。
    收尾与提交同 T-FIX-03（`make test-sync` → `package-dsh-plugin.sh` → 三一致性门禁 → `make check`；显式 `git add` 路径；`git commit -m "fix(health-fix-2026-09b): T-FIX-11 不可读候选判定与 index 内容面口径（R4-1）" -- <路径…>`）；提交后写 `T-FIX-11-SUMMARY.md`、勾 `status="done"` + `<done>` 注记、追加 `task_progress` 五字段（`completed_at` **必须在提交之后**且 Δ ≤ 120 s）。
  </action>
  <verify>
    set -u; rc=0;
    R=$(pwd);
    S="$R/flow-kit-bundle/flow-kit/reference/check-path-privacy.sh";
    AL="$R/flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt";
    bash -n "$S" || { echo "🔴 生产件语法错误"; rc=1; };
    P='/home/''zz-probe-d/leak.txt';
    # 夹具：git 仓 + 已提交文件（可含泄漏）+ 覆写清单旋钮（绝对路径，避免 CWD 读序依赖）
    FXM2() {  # $1=仓库内相对路径 $2=内容（提交进 index） $3=del|keep（提交后是否从磁盘删除）
      FX=$(mktemp -d); ( cd "$FX" && git init -q . >/dev/null 2>&1 );
      mkdir -p "$FX/$(dirname "$1")"; printf '%s\n' "$2" > "$FX/$1";
      ( cd "$FX" && git add -A >/dev/null 2>&1 && git -c user.email=a@b -c user.name=a commit -qm base >/dev/null 2>&1 );
      if [ "$3" = del ]; then rm -f "$FX/$1"; fi
      return 0;
    }
    FXR() { ( cd "$FX" && FLOW_KIT_PRIVACY_ALLOWLIST="$AL" bash "$S" 2>&1 ); }
    # ① R4-1 主腿（修复前必红）：已跟踪文件未 staged 删除、内容干净 ⇒ 候选面(index)仍列它，但不得判「不可读候选」
    FXM2 'sub/clean.sh' 'echo clean' del; OUT=$(FXR); SRC=$?;
    printf '   （诊断）① 删未 staged·干净 rc=%s\n' "$SRC";
    [ "$SRC" -eq 0 ] || { printf '%s\n' "$OUT" | tail -8; echo "🔴 R4-1：删掉已跟踪文件仍被判「不可读候选」⇒ 过严红未修"; rc=1; };
    printf '%s\n' "$OUT" | grep -q '不可读候选 0 个' || { printf '%s\n' "$OUT" | tail -6; echo "🔴 R4-1：自证「不可读候选」不为 0"; rc=1; };
    printf '%s\n' "$OUT" | grep -q 'index 侧可读' || echo "ℹ️ 未见「磁盘缺失但 index 侧可读」提示行（若实现选择静默兜底，请在 SUMMARY 说明）";
    rm -rf "$FX";
    # ② 不回退控制：同删除态但 index 版本含泄漏 ⇒ 内容面必须仍被 index 侧扫描并判红（修复前后都应 rc≠0）
    FXM2 'sub/leak.sh' "echo $P" del; OUT=$(FXR); SRC=$?;
    printf '   （诊断）② 删未 staged·index 含泄漏 rc=%s\n' "$SRC";
    [ "$SRC" -ne 0 ] || { printf '%s\n' "$OUT" | tail -8; echo "🔴 R4-1②：删除态下 index 侧泄漏未被检出（内容面被跳过）"; rc=1; };
    printf '%s\n' "$OUT" | grep -qE '清单外命中 [1-9]' || { printf '%s\n' "$OUT" | tail -8; echo "🔴 R4-1②：未打印非零的「清单外命中 N 条」"; rc=1; };
    rm -rf "$FX";
    # ③ 不回退控制：候选在 index 侧为 gitlink（无 blob）⇒ 两侧皆不可得 ⇒ 必须仍 fail-closed（修复前后都应 rc≠0）
    FX=$(mktemp -d); ( cd "$FX" && git init -q . >/dev/null 2>&1 ); printf 'echo base\n' > "$FX/base.sh";
    ( cd "$FX" && git add -A >/dev/null 2>&1 && git -c user.email=a@b -c user.name=a commit -qm base >/dev/null 2>&1 );
    SH=$( cd "$FX" && git rev-parse HEAD );
    ( cd "$FX" && git update-index --add --cacheinfo 160000,"$SH",submod >/dev/null 2>&1 );
    [ "$( cd "$FX" && git cat-file -t :submod 2>/dev/null )" = commit ] || echo "ℹ️ 夹具 gitlink 类型探测异常（判据③的前提）";
    OUT=$(FXR); SRC=$?;
    printf '   （诊断）③ gitlink 候选 rc=%s\n' "$SRC";
    [ "$SRC" -ne 0 ] || { printf '%s\n' "$OUT" | tail -6; echo "🔴 R4-1③：无 blob 候选被静默放过（fail-closed 被过度放宽）"; rc=1; };
    rm -rf "$FX";
    # ④ 基线绿腿：磁盘可读 + 干净 ⇒ rc=0（防夹具自身带红）
    FXM2 'sub/clean.sh' 'echo clean' keep; OUT=$(FXR); SRC=$?;
    printf '   （诊断）④ 磁盘可读·干净 rc=%s\n' "$SRC";
    [ "$SRC" -eq 0 ] || { printf '%s\n' "$OUT" | tail -8; echo "🔴 R4-1④：基线绿腿失败（夹具或实现有问题）"; rc=1; };
    rm -rf "$FX";
    # ⑤ 常设网 + 真实仓 + 三一致性 + 总门禁
    OUT1=$(npx bats test/test_path_privacy_gate.bats 2>&1); brc=$?;
    printf '%s\n' "$OUT1" | grep -q '^not ok' && { printf '%s\n' "$OUT1" | grep '^not ok' | head -5; echo "🔴 隐私门禁常设网有失败项"; rc=1; };
    [ $brc -eq 0 ] || { echo "🔴 test_path_privacy_gate.bats rc=$brc"; rc=1; };
    make check-path-privacy > /tmp/tfix11-priv.out 2>&1 || { tail -10 /tmp/tfix11-priv.out; echo "🔴 真实仓 check-path-privacy 不绿"; rc=1; };
    grep -q '不可读候选 0 个' /tmp/tfix11-priv.out || echo "ℹ️ 真实仓「不可读候选」非 0（若工作树确有删除态文件，请在 SUMMARY 说明）";
    FULL=$(npx bats test/ 2>&1); frc=$?;
    printf '%s\n' "$FULL" | grep -q '^not ok' && { printf '%s\n' "$FULL" | grep '^not ok' | head -5; rc=1; };
    [ $frc -eq 0 ] || { echo "🔴 全量套件 rc=$frc"; rc=1; };
    echo "bats: $(printf '%s\n' "$FULL" | grep -cE '^ok [0-9]+') ok / $(printf '%s\n' "$FULL" | grep -cE '^not ok [0-9]+') not-ok / count=$(npx bats --count test/)";
    make check-hooks-sync > /dev/null 2>&1 || { echo "🔴 hooks 副本未同步"; rc=1; };
    make check-test-sync  > /dev/null 2>&1 || { echo "🔴 test 双源不一致"; rc=1; };
    make check-dist       > /dev/null 2>&1 || { echo "🔴 dist 未重建"; rc=1; };
    make check > /tmp/tfix11-check.out 2>&1 || { tail -20 /tmp/tfix11-check.out; echo "🔴 make check 不绿"; rc=1; };
    exit $rc
  </verify>
  <done>commit 见回执 · R4-1 过严红修复：scan_file 磁盘缺失时先探 `git cat-file -t ":$file"`，blob ⇒ 不递增 UNREADABLE_COUNT 且打印「ℹ️ 磁盘缺失但 index 侧可读」（index 侧 git grep --cached 逐字不变）；非 blob/探测失败/gitlink 仍 fail-closed · 新增 3 条 bats 判别式（T-FIX-11①②③）· bats 基线 1058→1061 · make check 全绿 · 四腿夹具全绿。已知偏差：`<verify>` 静态块用相对路径 `S=flow-kit-bundle/...` + `cd "$FX" && bash "$S"` ⇒ rc=127 找不到文件（判据自身路径缺陷，未放宽；主 agent 夹具与我自建夹具均用绝对路径 S 跑通，意图与四腿判据一致）。</done>
  <depends_on>T-FIX-08</depends_on>
</task>

<task id="T-FIX-12" parallel="false" status="done" model-tier="top">
  <name>阶段 5 第 9 次执行新发现 🔴 NFR 预算回归（`REQUIREMENT.md:495`：`make check-path-privacy` 单次 ≤ 5 秒）—— T-FIX-07 把 index 侧内容面改成「每候选一次 `git grep --cached`」⇒ 实测 10.741/10.885/10.783/11.510/11.469 s（均值 11.078 s = 预算 221.6%，超限 2.2×）；批量化 index 侧扫描恢复 ≤5 s，且不得削弱 R3-1/R3-2/R3-30 覆盖</name>
  <read_files>
    <`.specs/health-fix-2026-09b/REQUIREMENT.md:495`（NFR 原文：「新增门禁 `make check-path-privacy` 单次运行 ≤ 5 秒」）· `.specs/health-fix-2026-09b/TEST.md:248`（判据：「单次运行 ≤ 5 秒 …… 验证手段 = `time` 实测并记入 TEST.md，超阈值即未满足」）· `TEST.md:261-269`（历次实测基线 2.842–3.146 s = 预算 57–61.5%，均判定达标；「绝对阈值、不做负载折算」口径由 `TEST.md:265` 确立）>
    <`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`（热点：`:586` `git grep --cached -naE --null "$PAT" -- "$file"` —— **每候选一次 git 进程**（T-FIX-07 引入）；`:573` `git cat-file -t ":$file"` —— 每「磁盘缺失」候选一次（T-FIX-11 引入）；`:509-520` `parse_grep_nul`：`--cached` 模式记录格式 `<path>\0<line>\0<content>\n`，rev 模式前缀 `<rev>:<path>`（可复用的现成解析器）；`:604` index 侧命中计数与去重；`:730` 自证四数输出）>
    <`test/test_path_privacy_gate.bats`（34 例；T-FIX-07 新增的 3 条判别式 = R3-1 非 ASCII/引号名真扫 · R3-2 index-only 泄漏判红 · R3-30 rev 模式同样；T-FIX-11 新增 3 例不可读候选口径）>
  </read_files>
  <write_files>
    <`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`（仅批量化改造 + 必要注释；判据语义不变）>
    <`test/test_path_privacy_gate.bats` + `flow-kit-bundle/test/test_path_privacy_gate.bats`（`make test-sync`；只允许**新增**用例，不得删改既有 34 例判据）>
    <`.specs/STATE.md`（bats 基线计数行；仅当计数变化时）> · `dist/`（重建）>
  </write_files>
  <action>
    **目标：把「index 侧内容面」的 git 调用次数从 O(候选数) 降到 O(1)（或 O(候选数/批)，且常数极小），使 `make check-path-privacy` 单次实测回到 ≤5 s 预算内；语义与判据强度**逐字不变**。**
    ① **推荐改法（有界次数批处理）**：脚本进入扫描循环**之前**做**一次** `git grep --cached -naE --null "$PAT"`（**不带 pathspec** ⇒ 全 index 一次扫完）落盘到临时文件（经既有 `register_tmp` 登记清理）；随后 `scan_file()` 的 index 侧腿改为**从该缓存按候选路径取值**（缓存记录格式与 `:509-520` `parse_grep_nul` 一致 ⇒ 优先复用同一解析器；按 `<path>\0` 精确切分，注意 NUL 安全与路径含 `:`/空格/非 ASCII 的情形）。若实现选择分批（每批 ≤N 个 pathspec），必须贴出「批次数 × 单批耗时」证据且总耗时 ≤ 预算的 60%。
    ② **`git cat-file -t` 探测同样按需批量化**：仅在「磁盘缺失」候选真实出现时才需要类型探测；若可合并为一次 `git cat-file --batch-check`（喂 `:path` 列表）则采用；否则保持逐条但**不得**在磁盘可读的常规路径上增加任何 git 调用。
    ③ **语义等价硬约束（违反即判红）**：`--cached` 命中仍是判红来源（`:604` 计数 + `清单外命中 N 条` 输出 + 归因行 `file:line`）；R3-1（非 ASCII / 含 `"`/`\` 名必须真扫）· R3-2（泄漏已 add、工作树干净 ⇒ 必须 rc≠0）· R3-30（`CHECK_REV`/rev 模式同样判红）三条**判别式必须仍绿**；自证四数（候选 / 实际扫描 / index 侧 / 不可读）口径不得回退；bash 3.2 兼容（禁 `declare -A`/`mapfile`/`readarray`）。
    ④ **性能判据（本次验收核心）**：修复前先贴红（`time make check-path-privacy` ≥10 s 起，可用 `TIMEFORMAT='real=%R user=%U sys=%S'`），修复后贴 5 次实测，**逐次** real ≤5 s 且打印均值与预算百分比；**不做负载折算**（`TEST.md:265` 已确立绝对阈值口径）。
    ⑤ **测试**：新增用例优先追加进既有用例；如需新增独立用例，请覆盖「批量化后 index 侧命中仍被逐条计数且带 `file:line`」这一行为（防「一次扫描 ⇒ 命中归属丢失」）。既有 34 例一律不得改动判据。
    ⑥ **文档**：`TEST.md` 的 NFR 段与本 change 的 receipts 由**主 agent** 记录第 9/10 次执行实测值；执行者只需在 `T-FIX-12-SUMMARY.md` 贴修复前后 5 次实测原文。
    **TDD/判别式**：先跑出红并贴原文（修复前 ≥10 s），再改至全绿并贴原文；夹具一律 `mktemp -d` 隔离，探针串**拼接构造**（L-137，如 `P='/home/''zz-probe-d/leak.txt'`），**禁止在真仓落任何探针**；夹具跑扫描器时用 `FLOW_KIT_PRIVACY_ALLOWLIST` 指向真仓清单（绝对路径），不得依赖 CWD 读序。
    **判据自身缺陷**：若 `<verify>` 或既有用例夹具本身有缺陷（TD-060/TD-065/TD-066/TD-072/TD-073 族），**停下原样上报**，不得自行放宽。
    **只读与写面纪律（L-161）**：开工与收工各贴一次 `git status --porcelain` 与 `git diff --cached --stat`；除 `<write_files>` 外不得写仓库内任何文件（含 `.git/config`、`.specs/health-fix-2026-09b/reproduce-5-test.sh` —— 后者是主 agent 写面）；夹具只允许写在 `/tmp`。本仓 `core.hooksPath` 为空 ⇒ 不得声称「提交时钩子已校验」，收尾一律**手工**跑门禁。
    收尾与提交同 T-FIX-03（`make test-sync` → `package-dsh-plugin.sh` / `package-flow-kit.sh` → `make check-hooks-sync check-test-sync check-dist` → `make check`；显式 `git add` 路径；`git commit -m "fix(health-fix-2026-09b): T-FIX-12 隐私门禁 index 侧扫描批量化（NFR ≤5s 预算回归）" -- <路径…>`；`-m` 必须在 `--` 之前）；提交后写 `T-FIX-12-SUMMARY.md`、勾 `status="done"` + `<done>` 注记、追加 `task_progress` 五字段（`completed_at` **必须在提交之后**且 Δ ≤ 120 s）。
  </action>
  <verify>
    set -u; rc=0;
    R=$(pwd);
    S="$R/flow-kit-bundle/flow-kit/reference/check-path-privacy.sh";
    AL="$R/flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt";
    bash -n "$S" || { echo "🔴 生产件语法错误"; rc=1; };
    P='/home/''zz-probe-d/leak.txt';
    # ① NFR 预算主腿（本任务的验收核心）：5 次 `time make check-path-privacy` 逐次 ≤5 s
    TIMEFORMAT='real=%R user=%U sys=%S'; i=1; nfr_bad=""; nfr_sum=0; nfr_max=0;
    while [ "$i" -le 5 ]; do
      t=$( { time make check-path-privacy >/dev/null 2>&1; } 2>&1 | tr '\n' ' ' );
      secs=$(printf '%s' "$t" | sed -n 's/.*real=\([0-9.][0-9.]*\).*/\1/p');
      printf '   （NFR）run %s: %s\n' "$i" "$t";
      [ -n "$secs" ] || { nfr_bad="$nfr_bad run$i(无法解析)"; i=$((i+1)); continue; };
      [ "$(awk -v s="$secs" 'BEGIN{print (s>5)?1:0}')" -eq 1 ] && nfr_bad="$nfr_bad run$i(${secs}s)";
      nfr_max=$(awk -v a="$nfr_max" -v b="$secs" 'BEGIN{print (b>a)?b:a}');
      nfr_sum=$(awk -v a="$nfr_sum" -v b="$secs" 'BEGIN{printf "%.3f", a+b}');
      i=$((i + 1));
    done;
    nfr_mean=$(awk -v s="$nfr_sum" 'BEGIN{printf "%.3f", s/5}');
    nfr_pct=$(awk -v m="$nfr_mean" 'BEGIN{printf "%.1f", m*20}');
    printf '   ⇒ max %ss · 均值 %ss = 预算 %s%%（绝对阈值 ≤5s，不做负载折算）\n' "$nfr_max" "$nfr_mean" "$nfr_pct";
    [ -z "$nfr_bad" ] || { echo "🔴 NFR 预算超限：${nfr_bad# }（REQUIREMENT.md:495 / TEST.md:248：超阈值即未满足）"; rc=1; };
    # ② R3-1 不回退：非 ASCII / 引号名必须真扫（含泄漏即判红；两份夹具：非 ASCII 名 / ASCII 名对照）
    FXM() { # $1=文件名 $2=内容
      FX=$(mktemp -d); ( cd "$FX" && git init -q . >/dev/null 2>&1 );
      printf '%s\n' "$2" > "$FX/$1";
      ( cd "$FX" && git add -A >/dev/null 2>&1 && git -c user.email=a@b -c user.name=a commit -qm base >/dev/null 2>&1 );
      OUT=$( cd "$FX" && FLOW_KIT_PRIVACY_ALLOWLIST="$AL" bash "$S" 2>&1 ); SRC=$?;
      rm -rf "$FX";
    }
    FXM 'naïve-ünïcode.sh' "echo $P"; printf '   （诊断）② 非 ASCII 名 rc=%s\n' "$SRC";
    [ "$SRC" -ne 0 ] || { printf '%s\n' "$OUT" | tail -8; echo "🔴 R3-1 回退：非 ASCII 文件名未被扫描 ⇒ 假绿"; rc=1; };
    FXM 'ascii-control.sh' "echo $P"; printf '   （诊断）② 对照 ASCII 名 rc=%s\n' "$SRC";
    [ "$SRC" -ne 0 ] || { printf '%s\n' "$OUT" | tail -8; echo "🔴 判据②对照腿异常（ASCII 名含探针却 rc=0）"; rc=1; };
    # ③ R3-2 不回退：泄漏已 git add、工作树改干净 ⇒ 必须判红（index 侧内容面未被批量化吞掉）
    FX=$(mktemp -d); ( cd "$FX" && git init -q . >/dev/null 2>&1 );
    printf 'echo clean\n' > "$FX/s.sh"; printf 'echo clean\n' > "$FX/leak.sh";
    ( cd "$FX" && git add -A >/dev/null 2>&1 && git -c user.email=a@b -c user.name=a commit -qm base >/dev/null 2>&1 );
    printf '%s\n' "echo $P" > "$FX/leak.sh";                 # ① 工作树写入探针
    ( cd "$FX" && git add leak.sh >/dev/null 2>&1 );          # ② index 收下探针（HEAD 仍干净）
    printf 'echo clean\n' > "$FX/leak.sh";                    # ③ 工作树改回干净 ⇒ 泄漏只存于 index
    ( cd "$FX" && git show :leak.sh | grep -q 'zz-probe-d' ) || echo "   ℹ️ 夹具状态异常：index 未含探针（判据③前提）";
    grep -q 'zz-probe-d' "$FX/leak.sh" && echo "   ℹ️ 夹具状态异常：工作树仍含探针（判据③前提）";
    OUT=$( cd "$FX" && FLOW_KIT_PRIVACY_ALLOWLIST="$AL" bash "$S" 2>&1 ); SRC=$?; rm -rf "$FX";
    printf '   （诊断）③ index-only 泄漏 rc=%s\n' "$SRC";
    [ "$SRC" -ne 0 ] || { printf '%s\n' "$OUT" | tail -8; echo "🔴 R3-2 回退：index 侧泄漏未被检出 ⇒ index 侧内容面被批量化跳过"; rc=1; };
    printf '%s\n' "$OUT" | grep -qE '清单外命中 [1-9]' || { printf '%s\n' "$OUT" | tail -8; echo "🔴 R3-2 回退：未打印非零「清单外命中 N 条」"; rc=1; };
    # ④ 基线绿腿 + 真实仓
    FX=$(mktemp -d); ( cd "$FX" && git init -q . >/dev/null 2>&1 ); printf 'echo clean\n' > "$FX/clean.sh";
    ( cd "$FX" && git add -A >/dev/null 2>&1 && git -c user.email=a@b -c user.name=a commit -qm base >/dev/null 2>&1 );
    OUT=$( cd "$FX" && FLOW_KIT_PRIVACY_ALLOWLIST="$AL" bash "$S" 2>&1 ); SRC=$?; rm -rf "$FX";
    printf '   （诊断）④ 干净夹具 rc=%s\n' "$SRC";
    [ "$SRC" -eq 0 ] || { printf '%s\n' "$OUT" | tail -8; echo "🔴 基线绿腿失败"; rc=1; };
    make check-path-privacy > /tmp/tfix12-priv.out 2>&1 || { tail -10 /tmp/tfix12-priv.out; echo "🔴 真实仓 check-path-privacy 不绿"; rc=1; };
    grep -E '候选文件|实际扫描|命中合计|清单外命中' /tmp/tfix12-priv.out | sed 's/^/   /';
    # ⑤ 常设网：隐私套件（既有 34 例判据不得被改弱）+ 全量套件
    POUT=$(npx bats test/test_path_privacy_gate.bats 2>&1); prc=$?;
    printf '%s\n' "$POUT" | grep -q '^not ok' && { printf '%s\n' "$POUT" | grep '^not ok' | head -5; echo "🔴 隐私门禁常设网有失败项"; rc=1; };
    [ $prc -eq 0 ] || { echo "🔴 test_path_privacy_gate.bats rc=$prc"; rc=1; };
    printf '   （诊断）⑤ 隐私套件 %s ok / %s not-ok\n' "$(printf '%s\n' "$POUT" | grep -cE '^ok [0-9]+')" "$(printf '%s\n' "$POUT" | grep -cE '^not ok [0-9]+')";
    FULL=$(npx bats test/ 2>&1); frc=$?;
    printf '%s\n' "$FULL" | grep -q '^not ok' && { printf '%s\n' "$FULL" | grep '^not ok' | head -5; rc=1; };
    [ $frc -eq 0 ] || { echo "🔴 全量套件 rc=$frc"; rc=1; };
    echo "bats: $(printf '%s\n' "$FULL" | grep -cE '^ok [0-9]+') ok / $(printf '%s\n' "$FULL" | grep -cE '^not ok [0-9]+') not-ok / count=$(npx bats --count test/)";
    # ⑥ 三一致性 + 总门禁
    make check-hooks-sync > /dev/null 2>&1 || { echo "🔴 hooks 副本未同步"; rc=1; };
    make check-test-sync  > /dev/null 2>&1 || { echo "🔴 test 双源不一致"; rc=1; };
    make check-dist       > /dev/null 2>&1 || { echo "🔴 dist 未重建"; rc=1; };
    make check > /tmp/tfix12-check.out 2>&1 || { tail -20 /tmp/tfix12-check.out; echo "🔴 make check 不绿"; rc=1; };
    exit $rc
  </verify>
  <done>已完成（commit c177fbac8ffe8c24a989fa5d6bb9ac9574fb2fa3）。修复前 5 次 NFR 实测 real=11.070/10.864/10.775/10.846/10.860 s（均值 ~11.083 s = 预算 221.7%，sys 远高于 user 确认 git 进程启动开销）；修复后 5 次 real=3.722/3.562/3.489/3.664/3.581 s（均值 3.604 s = 预算 72.1%，sys 从 ~11.2 s 降至 ~2.4 s）。R3-1（非 ASCII 名 naïve-ünïcode.sh rc=1）/ R3-2（index-only 泄漏 rc=1 + 清单外命中≥1）/ R3-30（rev 模式，bats 套件覆盖）三判别式不回退；自证四数口径不变（候选 1600 / 实际扫描 1594 / index 侧 13 / 不可读 0）。隐私 bats 30 ok / 0 not-ok；全量 bats 1061 ok / 0 not-ok；make check 21 项全绿。详见 T-FIX-12-SUMMARY.md。</done>
  <depends_on>T-FIX-07</depends_on>
</task>

<task id="T-FIX-13" parallel="false" status="done" model-tier="top">
  <name>阶段 4 复审 R4-M1 🟡（bundle 形态「检查器可用但 `path-privacy-allowlist.txt` 缺失」）—— ① 提示语误报为「未找到可用的路径隐私检查器」（与实际原因不符）；② 该形态下含泄漏的推送/提交 **rc=0 放行**（fail-open）⇒ 区分「检查器缺失」与「允许清单缺失」两态，后者改具名 fail-closed（指名缺失的允许清单路径），前者语义逐字不变；用户已裁决「本 change 内修」</name>
  <read_files>
    <`.specs/health-fix-2026-09b/MINOR-DEFERRED.md:1310`（R4-M1 原文：腿 E 实测该形态含泄漏推送 rc=0 放行 + 提示语不符）· `:1313`（建议处置：提交 4→5 收费门裁决 ⇒ 主 agent 已就地向用户请示并获裁决「本 change 内修」）>
    <`flow-kit-bundle/hooks/pre-push/pre-push.sh:22`（注释硬契约：三者皆不可得 ⇒ 打印 `ℹ️ 未找到可用的路径隐私检查器：跳过内容扫描` 且不改 rc）· `:34-45 resolve_reference_dir()` · `:46-80 resolve_checker()`（`RESOLVED_KIND=make|bundle|none`；bundle 形态导出 `RESOLVED_ALLOWLIST`）· `:87-100 scan_rev()`（**缺陷点**：`bundle` + `[ -z "$RESOLVED_ALLOWLIST" ]` ⇒ 打印旧措辞 + `return 0` = 放行）· `:140-150`（`scan_rev` 返回非零时父层一律打印 `🔴 拒绝推送 <ref>：该 ref 含路径隐私泄漏（check-path-privacy 未通过）` ⇒ 若把「配置缺失」也走该返回值会造成**归因错位**）>
    <`flow-kit-bundle/hooks/pre-commit/pre-commit.sh:56-75`（**缺陷点**：`[ -n "$ref_dir" ] && [ -f "$ref_dir/check-path-privacy.sh" ]` 为真、但 `[ -f "$ref_dir/path-privacy-allowlist.txt" ]` 为假 ⇒ 落 `:70` 同一个旧措辞且 `exit 0`）>
    <`test/test_archive_commit_gate.bats:208/:222`（既有静态断言：两个 hook 文件内**必须仍含** `未找到可用的路径隐私检查器` 字样 ⇒ 该措辞不得删除，只能保留给「检查器缺失」腿）>
  </read_files>
  <write_files>
    <`flow-kit-bundle/hooks/pre-push/pre-push.sh`（仅 `scan_rev` 的 bundle 分支与其注释）>
    <`flow-kit-bundle/hooks/pre-commit/pre-commit.sh`（仅允许清单缺失分支与其注释）>
    <`test/test_archive_commit_gate.bats` + `flow-kit-bundle/test/test_archive_commit_gate.bats`（`make test-sync`；只允许**新增**用例，不得删改既有断言）>
    <`.specs/STATE.md`（bats 基线计数行；仅当计数变化时）· `dist/`（重建）>
    <`.specs/health-fix-2026-09b/TASK.md`（**仅限**本任务块的 `status="done"` 属性与 `<done>…</done>` 注记；其余一字不改）>
  </write_files>
  <action>
    ① **三态区分，只对「配置缺失」fail-closed**：
      - **检查器缺失**（pre-push `RESOLVED_KIND=none`；pre-commit 无 `ref_dir` 或其中无检查器）⇒ **保持现状**：打印 `ℹ️ 未找到可用的路径隐私检查器：跳过内容扫描` 且 rc 不变（消费者兼容语义，审计已接受）。
      - **检查器在、允许清单缺失** ⇒ 打印**区分性**报文并**非零退出**。报文必须**指名缺失的允许清单路径**（形如 `<ref_dir>/path-privacy-allowlist.txt`）且含 `fail-closed` 语义；**不得**复用「未找到可用的路径隐私检查器」措辞。
        · pre-commit：`exit 1`（沿用既有「提交被拒绝」语义，报文形如 `🔴 [archive-commit-gate] 找到路径隐私检查器但缺少允许清单：<路径>（无法确定扫描基线 ⇒ fail-closed，提交被拒绝）`）。
        · pre-push：**不得**走 `scan_rev` 的 `return 1`（父层会误报「该 ref 含路径隐私泄漏」）⇒ 用独立致命路径（例如解析阶段 `echo … >&2; exit 2`），报文写明「配置缺失」而非「泄漏」。
      - **两者皆在** ⇒ 行为**逐字不变**：含泄漏 ⇒ rc≠0 且归因 `file:line`；干净 ⇒ rc=0。
    ② **TDD 先红后绿**：先按现行代码贴出 R4-M1 形态实测（`pre-push rc=0` + 旧措辞；`pre-commit rc=0` + 旧措辞），再改至 fail-closed 并贴原文。夹具一律 `mktemp -d`：沙箱内 `hooks/`（拷 hook）+ `reference/`（按腿决定是否拷检查器/清单）+ `proj/`（`git init` 项目仓，Makefile **不**声明 `check-path-privacy` 目标）；探针串**拼接构造**（L-137，如 `P='/home/''zz-probe-e/leak.txt'`），**禁止在真仓落任何探针、禁止改 `.git/config`**。
    ③ **反向控制（必须，缺一即判红）**：(a) 检查器缺失态仍 rc=0；(b) 两者皆在 + 干净对象 ⇒ rc=0；(c) 两者皆在 + 真泄漏（探针已 add/已提交）⇒ rc≠0 且报文指名 ref 与 `file:line`。
    ④ **静态断言不得回退**：`test/test_archive_commit_gate.bats:208/:222` 的 `grep -q '未找到可用的路径隐私检查器'` 必须仍命中。
    ⑤ **同步与打包（改 `flow-kit-bundle/hooks/**` 后的顺序硬契约）**：`make test-sync` → `./sync-hooks.sh`（6 处镜像）→ `package-dsh-plugin.sh` / `package-flow-kit.sh` → `make check-hooks-sync check-test-sync check-dist` → `make check`（21 项）。
    ⑥ **文档**：`TEST.md` / `PHASE5-RECEIPTS.md` / `MINOR-DEFERRED.md` 的复核记录由**主 agent** 写；执行者只在 `T-FIX-13-SUMMARY.md` 贴修复前后实测原文与判据清单。
    **只读与写面纪律（L-161）**：开工与收工各贴一次 `git status --porcelain` 与 `git diff --cached --stat`；除 `<write_files>` 外不得写仓库内任何文件（含 `.git/config`、`.specs/health-fix-2026-09b/reproduce-5-test.sh` = 主 agent 写面）；夹具只允许写在 `/tmp`。本仓 `core.hooksPath` 为空 ⇒ 不得声称「提交时钩子已校验」，收尾一律**手工**跑门禁。
    提交：`git add <路径…>` + `git commit -m "fix(health-fix-2026-09b): T-FIX-13 bundle 形态允许清单缺失改为具名 fail-closed（R4-M1）" -- <路径…>`（`-m` 必须在 `--` 之前）；提交后写 `T-FIX-13-SUMMARY.md`、勾本块 `status="done"` + `<done>…</done>`、追加 `task_progress` 五字段（`completed_at` 必须在提交之后且 Δ ≤ 120 s）。
    **判据修订留痕（主 agent · 2026-09-27 · 执行者与主 agent 各自独立发现）**：本块 `<verify>` 初版夹具**从未把 `path-privacy-allowlist.txt` 放进 `$SBX/reference/`**（只 `cp` 检查器）⇒ 被标注为「两者皆在」的 L4/L5 实际仍在**缺陷态**运行，于是 L2d（缺陷态**不得**出现「含路径隐私泄漏」）与 L5（同态同输入**必须**出现该串）构成**互斥断言** ⇒ 任何正确修复都无法同时满足（执行者 `3add4b81` 在判据校验阶段按硬规则停下原样上报；主 agent 独立复核一致；同族 = TD-073 / TD-065「判据夹具与语义脱节」，已登记 **TD-081**）。**修订**：L3 之后新增 **L3d**（把 fixture allowlist 写进 `$SBX/reference/` 并断言就位）将夹具切到真正的「两者皆在」态；新增 **L4c**（两者皆在 + 真泄漏 ⇒ pre-commit rc≠0）作为 pre-commit 的反向控制；L2a–L2g 与 L3a–L3c、L6a–L6c 的语义与断言**一字未改**（判据不放宽：缺陷态的具名 fail-closed 仍由 L2a–L2g 承担）。
  </action>
  <verify>
    set -u; rc=0; R=$(pwd);
    PP="$R/flow-kit-bundle/hooks/pre-push/pre-push.sh"; PC="$R/flow-kit-bundle/hooks/pre-commit/pre-commit.sh";
    bash -n "$PP" || { echo "🔴 L0a pre-push 语法错误"; rc=1; };
    bash -n "$PC" || { echo "🔴 L0b pre-commit 语法错误"; rc=1; };
    P='/home/''zz-probe-e/leak.txt';
    SBX=$(mktemp -d); mkdir -p "$SBX/hooks" "$SBX/reference" "$SBX/proj";
    cp "$PP" "$SBX/hooks/pre-push.sh"; cp "$PC" "$SBX/hooks/pre-commit.sh";
    cp "$R/flow-kit-bundle/flow-kit/reference/check-path-privacy.sh" "$SBX/reference/";
    ( cd "$SBX/proj" || exit 9; git init -q . >/dev/null 2>&1; printf 'test:\n\t@true\n' > Makefile; git add Makefile; git -c user.email=a@b.c -c user.name=t commit -q -m clean; ) || { echo "🔴 L1 夹具建仓失败"; rc=1; };
    CLEAN=$( cd "$SBX/proj" && git rev-parse HEAD );
    ( cd "$SBX/proj" && printf 'leak: %s\n' "$P" > leak.txt && git add leak.txt && git -c user.email=a@b.c -c user.name=t commit -q -m leak ) || { echo "🔴 L1 夹具泄漏提交失败"; rc=1; };
    LSHA=$( cd "$SBX/proj" && git rev-parse HEAD );
    pp() { ( cd "$SBX/proj" && printf 'refs/heads/main %s refs/heads/main %s\n' "$1" 0000000000000000000000000000000000000000 | bash "$SBX/hooks/pre-push.sh" 2>&1 ); };
    pc() { ( cd "$SBX/proj" && bash "$SBX/hooks/pre-commit.sh" 2>&1 ); };
    # L2：缺陷态（检查器在、清单缺）—— 必须 rc≠0 且具名、不得复用旧措辞、不得错报泄漏
    o=$(pp "$LSHA"); r=$?;
    printf '   （L2 pre-push rc=%s）%s\n' "$r" "$o";
    [ "$r" -ne 0 ] || { echo "🔴 L2a 允许清单缺失时 pre-push 仍 rc=0（fail-open 未修）"; rc=1; };
    case "$o" in *path-privacy-allowlist.txt*) : ;; *) echo "🔴 L2b 报文未指名缺失的允许清单路径"; rc=1 ;; esac;
    case "$o" in *未找到可用的路径隐私检查器*) echo "🔴 L2c 报文复用了「检查器缺失」措辞（原因不符）"; rc=1 ;; *) : ;; esac;
    case "$o" in *含路径隐私泄漏*) echo "🔴 L2d 配置缺失被错报成泄漏（归因错位）"; rc=1 ;; *) : ;; esac;
    o2=$(pc); r2=$?;
    printf '   （L2 pre-commit rc=%s）%s\n' "$r2" "$o2";
    [ "$r2" -ne 0 ] || { echo "🔴 L2e 允许清单缺失时 pre-commit 仍 rc=0"; rc=1; };
    case "$o2" in *path-privacy-allowlist.txt*) : ;; *) echo "🔴 L2f pre-commit 报文未指名允许清单路径"; rc=1 ;; esac;
    case "$o2" in *未找到可用的路径隐私检查器*) echo "🔴 L2g pre-commit 报文复用旧措辞"; rc=1 ;; *) : ;; esac;
    # L3：反向控制（a）检查器缺失态保持 rc=0 + 旧措辞（此态下允许清单亦缺）
    mv "$SBX/reference/check-path-privacy.sh" "$SBX/reference/.hidden-checker";
    o3=$(pp "$LSHA"); r3=$?; o4=$(pc); r4=$?;
    [ "$r3" -eq 0 ] || { echo "🔴 L3a 检查器缺失态 pre-push rc=$r3（应为 0，消费者兼容语义被破坏）"; rc=1; };
    case "$o3" in *未找到可用的路径隐私检查器*) : ;; *) echo "🔴 L3b 检查器缺失态报文丢失既有措辞"; rc=1 ;; esac;
    [ "$r4" -eq 0 ] || { echo "🔴 L3c 检查器缺失态 pre-commit rc=$r4（应为 0）"; rc=1; };
    mv "$SBX/reference/.hidden-checker" "$SBX/reference/check-path-privacy.sh";
    # L3d：夹具切到真正的「两者皆在」态 —— 检查器 + 允许清单都在位（fixture allowlist：无条目 ⇒ 任何真名形态均判清单外）
    printf '# fixture allowlist（无条目）\n' > "$SBX/reference/path-privacy-allowlist.txt";
    [ -f "$SBX/reference/path-privacy-allowlist.txt" ] || { echo "🔴 L3d 允许清单夹具未就位（L4/L4c/L5 会在缺陷态空跑 ⇒ 与 L2d 互斥）"; rc=1; };
    # L4：反向控制（b）两者皆在 + 干净 ⇒ rc=0
    o5=$(pp "$CLEAN"); r5=$?;
    [ "$r5" -eq 0 ] || { echo "🔴 L4 干净对象 rc=$r5（反向控制失败：${o5}）"; rc=1; };
    # L4c：反向控制（b2）两者皆在 + 真泄漏 ⇒ pre-commit rc≠0（不得退化成「一律放行」或「一律拒绝」）
    o7=$(pc); r7=$?;
    [ "$r7" -ne 0 ] || { echo "🔴 L4c 两者皆在时 pre-commit 对泄漏对象仍 rc=0（漏检）"; rc=1; };
    # L5：反向控制（c）两者皆在 + 真泄漏 ⇒ rc≠0 且归因（此处才允许出现「含路径隐私泄漏」）
    o6=$(pp "$LSHA"); r6=$?;
    case "$o6" in *含路径隐私泄漏*) : ;; *) echo "🔴 L5 泄漏对象未按路径隐私泄漏归因（rc=$r6）"; rc=1 ;; esac;
    [ "$r6" -ne 0 ] || { echo "🔴 L5 泄漏对象 rc=0"; rc=1; };
    # L6：既有静态断言 + 套件
    grep -q '未找到可用的路径隐私检查器' "$PP" || { echo "🔴 L6a pre-push 丢失既有措辞（bats:208 静态断言）"; rc=1; };
    grep -q '未找到可用的路径隐私检查器' "$PC" || { echo "🔴 L6b pre-commit 丢失既有措辞（bats:222）"; rc=1; };
    npx bats test/test_archive_commit_gate.bats >/dev/null 2>&1 || { echo "🔴 L6c test_archive_commit_gate.bats 未全绿"; rc=1; };
    rm -rf "$SBX";
    echo "T-FIX-13 verify rc=$rc";
    exit "$rc"
  </verify>
  <done>已完成（commit ee0df5c0e4cc3f631edce85a436a667acb0a14ac）。三态区分：① 检查器缺失（RESOLVED_KIND=none / pre-commit 无 ref_dir 或其中无检查器）⇒ 保持 rc=0 + 原措辞 `ℹ️ 未找到可用的路径隐私检查器：跳过内容扫描`（消费者兼容语义，bats:208/:222 静态断言仍命中）；② 检查器在 + path-privacy-allowlist.txt 缺失 ⇒ 具名 fail-closed：pre-push 用独立致命路径 `echo … >&2; exit 2`（不走 scan_rev return 1，避免父层 :150 错位归因为「含路径隐私泄漏」），pre-commit 用 `exit 1`（沿用既有「提交被拒绝」语义），报文均指名缺失的允许清单路径 + fail-closed 语义，不复用①措辞、不含泄漏归因；③ 两者皆在 ⇒ 行为逐字不变。verify 复跑 rc=0（L0a/L0b 语法 OK；L2 检查器在+清单缺：pre-push rc=2 + pre-commit rc=1 均具名 fail-closed，L2a-L2g 全绿；L3 检查器缺失态 rc=0 + 旧措辞，L3a-L3c 全绿；L3d 夹具切「两者皆在」态；L4 干净 rc=0 / L4c pre-commit 泄漏 rc≠0 / L5 泄漏 rc≠0+归因「含路径隐私泄漏」，L4/L4c/L5 全绿；L6 静态断言+bats 套件全绿）。先红基线 rc=1（6 条红腿 L2a/b/c/e/f/g，与主 agent 公布一致）。反向控制三条全绿：(a) 检查器缺失 rc=0；(b) 两者皆在+干净 rc=0；(c) 两者皆在+真泄漏 rc≠0+归因。bats 42→45（+3：pre-push 状态②具名 fail-closed·exit 2·指名允许清单 / pre-push 状态②报文不复用①措辞·归因区分 / pre-commit 状态②具名 fail-closed exit 1·指名允许清单），全量 bats 1064 ok / 0 not-ok（T-FIX-11 基线 1061 + 3）；make check 21 项全绿；check-hooks-sync（6 镜像 12 文件漂移 0）/ check-test-sync / check-dist 全绿。判据夹具缺陷 TD-081（verify L2d 与 L5 对同态同输入互斥）由主 agent 修订（L3d 切「两者皆在」态 + L4c 新增 pre-commit 反向控制），本执行者未自行放宽判据。详见 T-FIX-13-SUMMARY.md。</done>
  <depends_on>T-FIX-08</depends_on>
</task>


---

## 第 5 轮 fix loop 追加任务（`T-FIX-14`…`T-FIX-23` · 主 agent · 2026-09-27）

**来源**：阶段 6 第 5 轮审查（`REVIEW.md` §0⁗.4 的 `R5-1`…`R5-27` = 3 🔴 + 15 🟡 + 9 🟢）· 用户裁决 = **方案 A**（3 🔴 + 全部 15 🟡 进 fix loop；9 🟢 中 6 条登记技术债 `TD-083`/`TD-086`…`TD-090`、3 条作为顺手闭合并入下表任务）。**任务与发现映射**：

| 任务 | 覆盖发现 | 面 |
| --- | --- | --- |
| `T-FIX-14` | `R5-18` 🔴 · `R5-19` 🟡 · `R5-24` 🟢（顺手闭合） | 安装形态可达性 + pre-commit 顺序 + 死变量 |
| `T-FIX-15` | `R5-6` 🔴 · `R5-27` 🟢（顺手闭合） | AC-2 缺 jq 常设 bats + `TEST.md:55` 措辞 |
| `T-FIX-16` | `R5-7` 🔴 | AC-3 pre-push 行为级常设 bats |
| `T-FIX-17` | `R5-15` 🟡 · `R5-16` 🟡 | 隐私门禁磁盘侧隔离 + rev 面批量化 |
| `T-FIX-18` | `R5-14` 🟡 · `R5-10` 🟡 | `check-gate-sync` fail-closed + AC-4 判别形态 |
| `T-FIX-19` | `R5-9` 🟡 | AC-1 载荷与副本判据常设化 |
| `T-FIX-20` | `R5-26` 🟡 · `R5-12` 🟢（顺手闭合） | AC-7 删除注入封闭 + combined metric 真实路径 |
| `T-FIX-21` | `R5-1` 🟡 · `R5-8` 🟡 · `R5-2` 🟢（归一） | 台账与报告可复算订正 |
| `T-FIX-22` | `R5-20` 🟡 · `R5-21` 🟡 · `R5-22` 🟡 · `R5-5` 🟡 | 钩子/安装器健壮性 + `SELF_EXCLUDE` |
| `T-FIX-23` | `R5-23` 🟡 | NFR 判据存量基线 + `mapfile` 替换 |

**执行序（`parallel="false"` · 严格串行）**：`T-FIX-14` → `T-FIX-15` → `T-FIX-16` → `T-FIX-17` → `T-FIX-18` → `T-FIX-19` → `T-FIX-20` → `T-FIX-21` → `T-FIX-22` → `T-FIX-23`。理由：镜像/打包/门禁三步（`make test-sync` · `./sync-hooks.sh` · `package-*.sh` → `make check-*`）会重写 `test/` 与 `hooks/` 的全量副本与 `dist/`，并发执行会让彼此的门禁读到中间态；且 `T-FIX-22` 的写面与 `T-FIX-14`/`T-FIX-17` 重叠（见其 `<depends_on>`）。

**工作树纪律（主 agent · 2026-09-28 · `T-FIX-15` 事故后立规）**：执行者**严禁**对**非本任务写面**的已跟踪文件执行 `git checkout --` / `git restore` / `git stash` / `git clean` —— 这些命令会**不可逆地销毁主 agent 的未提交改动**（`T-FIX-15` 执行者据此销毁了 `TASK.md`/`TEST.md` 的全部未提交订正，幸有 `/tmp` 备份才复原）。需要「提交基线副本」时只许 `git show HEAD:<path> > /tmp/<task>/<file>` 或 `cp -a` 到 `/tmp`。发现非本任务写面的预存改动时**只回报、不清理**。台账条目必须 **append** 到 `goal.task_progress` 末尾（不得 prepend、更不得写入顶层 `.goal` 幽灵键 —— `T-FIX-15` 执行者误写导致权威台账缺失该条目），写后须用 `python3 -c` 断言 `tp[-1]['id']` 为本任务且 `'.goal' not in d`。

**行号锚点纪律（主 agent · 2026-09-28 · `T-FIX-14` 落库后重取）**：`T-FIX-14` 已改动 `pre-push.sh`（+37/−6）· `pre-commit.sh`（+64/−22）· `install_hooks.sh`（+12/−3）的行号，下列锚点已就地重取 —— `pre-push.sh:171-172`（畸形 stdin 守卫 `exit 1`）· `pre-push.sh:198-199`（泄漏拒绝 `if ! scan_rev`）· `install_hooks.sh:189-190`（缺 jq 第一道守卫）· `install_hooks.sh:365-366`（第二道）· `install_hooks.sh:379`/`:393`（`merged=$(jq …)` / `合并失败` 告警）。**后续每个任务开工前必须用 `grep -n` 按语义重取锚点**，不得按字面行号盲改（同族 `TD-065`/`TD-073`/`TD-079` 的教训）。

<task id="T-FIX-14" parallel="false" status="done" model-tier="top">
  <name>【R5-18 🔴 · R5-19 🟡 · R5-24 🟢】已安装形态下隐私检查器不可达（消费者双侧门禁静默失效）+ pre-commit 隐私块顺序 + 死变量</name>
  <read_files>
    <`flow-kit-bundle/lib/install_hooks.sh:270-300`（检查器安装位 `ref_dst_dir="${hook_dst%/hooks}/reference"` 与注释里假设的 `HOOK_DIR/../reference/` 不一致）>
    <`flow-kit-bundle/lib/install_hooks.sh:75-95`（`deploy_pre_commit`）· `:110-165`（`deploy_pre_push`：hook 落在 `<hook_dst>/pre-push/pre-push.sh`，比注释深一层）· `:205-230`（`hook_dst` 定义：user `$USER_HOOKS_DIR` / project `${project}/${PROJECT_DIR_NAME}/hooks`）>
    <`flow-kit-bundle/hooks/pre-push/pre-push.sh:25-45`（`HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` + `resolve_reference_dir()` 三条候选）· `:120-160`（`pure_delete_seen` 死变量 · 纯删除分支 · `:150` 父层泄漏报文）>
    <`flow-kit-bundle/hooks/pre-commit/pre-commit.sh:15-80`（`:19-22` 无 Makefile 早退 + `:25-28` npx 早退均**早于** `:36` 起的隐私块；候选解析与 pre-push 同构）>
    <`.specs/health-fix-2026-09b/REVIEW.md` 的 `R5-18`（含主 agent 扩面证据：安装位本身即错层）· `R5-19` · `R5-24`（每条四要素 + Remedy）>
    <`.specs/health-fix-2026-09b/REQUIREMENT.md` 的 AC-6 ③（消费者项目回退路径的声明面）>
    <`flow-kit-bundle/hooks/pre-push/pre-push.sh:85-110`（`scan_rev` 的 `bundle)` 分支与缺失清单具名 `exit 2` —— T-FIX-13 已修，勿回退）>
  </read_files>
  <write_files>
    <`flow-kit-bundle/hooks/pre-push/pre-push.sh`（自身真实路径解析 + 候选补安装形态 + 删死变量）>
    <`flow-kit-bundle/hooks/pre-commit/pre-commit.sh`（同构路径解析 + 隐私块前置）>
    <`flow-kit-bundle/lib/install_hooks.sh`（安装位注释与实物一致；如安装位需调整则同步 `resolve_reference_dir` 候选）>
    <`test/test_install_layout.bats`（新件 · 安装形态端到端常设网）>
    <`T-FIX-14-SUMMARY.md`（新件）>
  </write_files>
  <action>
    1. **先红留档**：`mkdir -p /tmp/tfix14` 并写夹具脚本复现缺陷——`bash flow-kit-bundle/install.sh --platform claude --project /tmp/tfix14/proj --hooks-only`；在 `/tmp/tfix14/proj` 内 `git init` + 提交一个**含真泄漏**的文件（探针字面必须由拼接构造 · L-137，例如 `LEAK="/home/""<真实账号>""/secret"` 的形式请改用非真实账号的等价形态并说明口径）＋ 一份自建 allowlist；随后两形态各喂一行 stdin（`printf 'refs/heads/main %s refs/heads/main %s\n' "$sha" 0000000000000000000000000000000000000000`）：① `.git/hooks/pre-push`（symlink 形态）② `/tmp/tfix14/proj/.claude/hooks/pre-push/pre-push.sh`（真实脚本路径形态）。**当前两形态均应 rc=0 且 stdout 含 `ℹ️ 未找到可用的路径隐私检查器：跳过内容扫描`** ⇒ 把两段原始输出存 `/tmp/tfix14/pre.txt` 并在 SUMMARY 引用。
    2. **修自身路径解析（两 hook 同构、macOS 兼容）**：不依赖 `readlink -f`；用 `command -v readlink` + 循环把 `BASH_SOURCE[0]` 逐级解析为真实文件（相对目标按 `dirname` 拼接），再 `HOOK_DIR="$(cd "$(dirname "$self")" && pwd)"`。这样经 `.git/hooks/pre-push` symlink 调用时 `HOOK_DIR` 仍是 `<proj>/.claude/hooks/pre-push`。
    3. **候选补齐**：在 `resolve_reference_dir()` 现有三候选之后补 `$HOOK_DIR/../../reference`（安装形态正确位置：`<proj>/.claude/hooks/pre-push` → `<proj>/.claude/reference`）；保留源码树候选（`$HOOK_DIR/../flow-kit/reference` 等）。**不得**把候选改宽成通配目录扫描——必须是精确候选列表。
    4. **安装位与注释对齐**：`install_hooks.sh:277-292` 的 `ref_dst_dir` 保持现状（`${hook_dst%/hooks}/reference`，即 `<proj>/.claude/reference`），把误导性注释改为与实物一致，并注明「hook 装在 `<hook_dst>/<hook-name>/`（深一层）⇒ 候选必须写 `$HOOK_DIR/../../reference`」。
    5. **修 `R5-19`**：把 `pre-commit.sh` 的隐私扫描块整体移到 `:19` 的 `[ ! -f Makefile ]` 与 `:25` 的 npx 早退**之前**；两个早退只跳过测试门禁，不再跳过隐私扫描。在无 Makefile 的沙箱项目里实测：干净 ref rc=0、泄漏 ref rc≠0 + 具名报文。
    6. **清 `R5-24`**：删除 `pre-push.sh:129`/`:151` 的 `pure_delete_seen`（全文件无读取）。
    7. **常设判据**：新增 `test/test_install_layout.bats`（端点用真实 `install.sh`，`HOME` 与 project 均指向 `mktemp -d`；固定桩 git 身份），断言：① `.git/hooks/pre-push` symlink 形态 + 泄漏 ⇒ rc≠0 且报文含 `🔴 拒绝推送` 与被拒 ref 名；② 真实脚本路径形态 ⇒ 同上；③ 干净 ref ⇒ rc=0；④ `<proj>/.claude/reference/{check-path-privacy.sh,path-privacy-allowlist.txt}` 就位；⑤ 真缺失态**回归腿**：把安装位的 `check-path-privacy.sh` 与 `path-privacy-allowlist.txt` **同时**移走 ⇒ 必须**保持** `T-FIX-13` 三态语义①（`rc=0` + 逐字 `ℹ️ 未找到可用的路径隐私检查器：跳过内容扫描`）。本任务**不得**把「检查器真缺失」改成 fail-closed —— 那是独立裁决、超出本任务范围；本任务只保证「检查器**已装**时必须被找到并使用」；⑥（反向控制）临时把候选表还原为旧三条 ⇒ 腿①②必须转红。
    8. **同步/打包/门禁/提交**（硬顺序）：`make test-sync` → `./sync-hooks.sh` → `bash flow-kit-bundle/package-dsh-plugin.sh` 与 `bash flow-kit-bundle/package-flow-kit.sh` → `make check-hooks-sync check-test-sync check-dist` → `make check`（21 项全绿）。随后逐路径 `git add` + `git commit -m "<type>: <摘要>（T-FIX-14 · R5-18/19/24）" -- <路径…>`（`-m` 必须在 `--` 之前；禁 `git add .`/`-A`/`--no-verify`/`git stash`）。
    9. 提交后写 `T-FIX-14-SUMMARY.md`（六维自评 + 先红/后绿原始输出 + 六条未验证边界），勾 `status="done"`，追加 `<done>` 注记，并追加 `task_progress` 五字段（`commit_sha` 先 `sha=$(git rev-parse HEAD)` 取真值再 `--arg` 传入 jq；`completed_at` 取 `date -Iseconds`；`deferred: []`；Δ ≤ 120 s）。
  </action>
  <verify>
    以仓库根为 cwd 逐条执行，任一不满足即 fail：
    ① 先红证据：`grep -c '未找到可用的路径隐私检查器' /tmp/tfix14/pre.txt` ≥ 2（两形态各一条）且该文件内无 `🔴 拒绝推送`。
    ② 后绿端到端：`npx bats test/test_install_layout.bats` ⇒ `not ok` 计数 = 0 且用例数 ≥ 6。
    ③ 反向控制（判据有牙）：把候选表临时还原为旧三候选后重跑同一 bats ⇒ **必须出现 not ok**（贴输出后还原）。
    ④ 静态面：`grep -c 'pure_delete_seen' flow-kit-bundle/hooks/pre-push/pre-push.sh` = **0**；`grep -n 'check-path-privacy\|隐私' flow-kit-bundle/hooks/pre-commit/pre-commit.sh | head -1` 的行号 < `grep -n 'no Makefile' flow-kit-bundle/hooks/pre-commit/pre-commit.sh` 的行号。
    ⑤ 语法：`bash -n` 三个生产件 rc=0。
    ⑥ 镜像与总门禁：`make check-hooks-sync check-test-sync check-dist` rc=0 且 `make check` 21 ✅ / 0 ❌；`npx bats --count test/` ≥ 1070。
  </verify>
  <depends_on>无（本批首个；`T-FIX-16`/`T-FIX-22` 依赖本任务）</depends_on>
  <done>R5-18 🔴：`pre-push.sh` 与 `pre-commit.sh` 新增 `_resolve_self_path()`（`command -v readlink` + 深度上限 40 循环解析 `BASH_SOURCE[0]`，相对目标按 `dirname` 拼接），`HOOK_DIR` 经 `.git/hooks/*` symlink 调用时仍解析为 `<proj>/.claude/hooks/<hook>`；`resolve_reference_dir()` 候选由 3 条扩为 4 条，新增 `$HOOK_DIR/../../reference`（安装形态正确位置：`<proj>/.claude/hooks/<hook>` → `<proj>/.claude/reference`），源码树候选保留。R5-19 🟡：`pre-commit.sh` 隐私扫描块整体前置于无 Makefile / npx 早退（两早退只跳过测试门禁）。R5-24 🟢：删 `pure_delete_seen`（全文件无读取，纯写）。`install_hooks.sh:277-292` 注释与实物对齐。新增 `test/test_install_layout.bats`（8 例全绿，含反向控制腿）。验证 ①–⑥ 全满足：先红 `grep -c '未找到可用的路径隐私检查器' /tmp/tfix14/pre.txt` ≥ 2；后绿 `npx bats test/test_install_layout.bats` not ok=0 / ok=8；反向控制 strip 候选 ⇒ not ok=2；静态 `pure_delete_seen` 计数=0、pre-commit 隐私行(5) < 无 Makefile 行(107)；`bash -n` 三件 rc=0；全量 bats 1072 例（基线 1064 +8）`make check` 21 ✅。T-FIX-13 三态语义①未回退（真缺失态 rc=0 + 逐字跳过消息）。</done>
</task>

<task id="T-FIX-15" parallel="false" status="pending" model-tier="top">
  <name>【R5-6 🔴 · R5-27 🟢】AC-2「缺 jq 不毁配置」固化为常设 bats（含变异反向控制）+ `TEST.md:55` 措辞订正</name>
  <read_files>
    <`flow-kit-bundle/lib/install_hooks.sh:35-55`（`mktemp` 原子写）· `:180-195`（入口 `command -v jq` 守卫 + 具名报文中止）· `:350-365`（合并前第二道守卫）>
    <`flow-kit-bundle/install.sh:120-140`（`check_jq()` 硬前置）· `:160-175`>
    <`test/test_install_dry_run.bats:1-40`（现有 settings.json 相关用例：`DRY_RUN` + jq 在位 ⇒ 不覆盖缺 jq）· `test/test_install.bats:75-90`（`no-brooks` 用例缺 `--user`）>
    <`.specs/health-fix-2026-09b/TASK.md` 的 `T06`（change 期判据原文，须逐条搬为常设）>
    <`.specs/health-fix-2026-09b/REVIEW.md` 的 `R5-6`（含 spot-check `F1` 的变异实证）· `R5-27` · `REQUIREMENT.md` 的 AC-2 条文>
    <`test/test_install_coverage.bats`（既有安装覆盖面的写法与夹具约定）>
  </read_files>
  <write_files>
    <`test/test_install_jq_guard.bats`（新件 · 缺 jq 常设网）>
    <`.specs/health-fix-2026-09b/TEST.md`（仅 `:55` 一行的措辞订正）>
    <`T-FIX-15-SUMMARY.md`（新件）>
  </write_files>
  <action>
    1. **先红**：写 `/tmp/tfix15/probe.sh` 复现「缺 jq 无覆盖」——`grep -rn "permissions" test/*.bats` = 0 命中、`grep -rln "settings\.json" test/*.bats` 仅 `test_install_dry_run.bats`（且 jq 在位）⇒ 记录到 SUMMARY。
    2. 新增 `test/test_install_jq_guard.bats`（≥4 例）：在 `mktemp -d` 沙箱里（`HOME` 指向沙箱、git 身份固定、`settings.json` 预置含 `permissions.allow` 与既有 hook 的有效 JSON）用**影子 PATH**（软链 `jq` 之外的必需命令、排除 jq）跑 `bash flow-kit-bundle/install.sh --global --no-brooks --user`，断言：① rc≠0；② stdout/stderr 含 `❌ 缺少依赖 jq` 与 `已中止`；③ `settings.json` **未被截断为空**（`[ -s file ]`）且 `permissions.allow` 与既有 hook 仍可 `jq -e` 读出；④ 目录内无遗留 `*.tmp` 残片。**判据口径以 `REQUIREMENT.md` 的 AC-2 为准（「未被截断为空 + allow/hook 存活」，不是逐字节相等）。**
    3. **变异反向控制**（证明判据有牙，不写进常设网）：`cp -a flow-kit-bundle /tmp/tfix15/mut-bundle`，删 `:189-190`（第一道）与 `:365-366`（第二道）两处守卫（用 `sed`/python 精确改），用同一 bats 跑 `INSTALL_ROOT=/tmp/tfix15/mut-bundle` 形态 ⇒ **必须出现 not ok**；贴输出后丢弃副本。
    4. **订正 `TEST.md:55`**（`R5-27`）：把 AC-2 行的「目标配置字节不变」改为「既有 `settings.json` 未被截断为空 + `permissions.allow` 与既有 hook 存活（**非**字节相等）」，并在同格追加「常设网 = `test/test_install_jq_guard.bats`（`R5-6` 闭合）」。**只改这一行**，不动其他计数（`R5-8` 由 `T-FIX-21` 负责）。
    5. 同步与提交：`make test-sync` → `make check-test-sync` → `make check`（21 ✅ / 0 ❌）；`git add` 逐路径后 `git commit -m "test: AC-2 缺 jq 常设 bats + TEST.md 措辞订正（T-FIX-15 · R5-6/R5-27）" -- <路径…>`。
    6. SUMMARY + `status="done"` + `<done>` 注记 + `task_progress` 五字段（契约同 `T-FIX-14` 第 9 步）。
  </action>
  <verify>
    ① 先红证据：`grep -rn 'permissions' test/*.bats` 修复前 = 0 命中（存 `/tmp/tfix15/pre.txt`）。
    ② `npx bats test/test_install_jq_guard.bats` ⇒ not ok = 0 且用例数 ≥ 4。
    ③ 变异腿：删两道守卫的副本上同一 bats **必须 not ok**（贴证据）。
    ④ `grep -n '字节不变' .specs/health-fix-2026-09b/TEST.md` ⇒ **0 命中**；`grep -c 'test_install_jq_guard' .specs/health-fix-2026-09b/TEST.md` ≥ 1。
    ⑤ `make check` 21 ✅ / 0 ❌；`npx bats --count test/` ≥ 1070。
  </verify>
  <depends_on>T-FIX-14（串行：镜像/打包/门禁为全仓步骤）</depends_on>
</task>

<task id="T-FIX-16" parallel="false" status="done" model-tier="top">
  <name>【R5-7 🔴】pre-push 拦截行为固化为常设 bats（四推送形态 + 缺清单态 + 变异反向控制）</name>
  <read_files>
    <`flow-kit-bundle/hooks/pre-push/pre-push.sh`（全文 **216 行**；行号主 agent 于 2026-09-28 重取：`:78` `makefile_has_target` · `:89`/`:95-99` 检查器与 allowlist 解析 · `:131` `CHECK_REV="$check_rev" make check-path-privacy` · `:137-140` 缺允许清单具名 `exit 2` · `:171-172` 畸形 stdin 具名 `exit 1` · `:181-182` 纯删除跳过 · `:189-193` sha 去重 · `:198-200` 泄漏拒绝 · `:208` 尾随 `[ -z "$leaky_ref" ] || exit 1` · `:212-213` `make check`）>
    <`test/test_archive_commit_gate.bats:175-290`（现有对 pre-push 的静态断言：`bash -n` + 文本 `grep -q`，**从不执行 hook**）>
    <`.specs/health-fix-2026-09b/TASK.md` 的 `T19`（change 期四形态 UAT 判据原文，须逐条搬为常设）>
    <`.specs/health-fix-2026-09b/REVIEW.md` 的 `R5-7`（含 spot-check `F2` 的变异实证：畸变体上静态断言全绿）>
    <`test/test_path_privacy_gate.bats:200-240`（既有沙箱建 git 仓 + 自建 allowlist 的写法，勿 `cp` 仓库文件）>
  </read_files>
  <write_files>
    <`test/test_pre_push_behavior.bats`（新件 · 行为级常设网）>
    <`T-FIX-16-SUMMARY.md`（新件）>
  </write_files>
  <action>
    1. **先红**：`grep -rn "git push" test/*.bats` ⇒ 仅无关匹配；把 `test_archive_commit_gate.bats` 对 pre-push 的静态断言全量输出留档，证明「改坏逻辑仍全绿」⇒ 存 `/tmp/tfix16/pre.txt`。
    2. 新增 `test/test_pre_push_behavior.bats`（≥6 例，全部**真跑 hook**）：在 `mktemp -d` 里建裸仓 + 工作仓（`git init --bare` + 固定身份），自建 `reference/path-privacy-allowlist.txt`（**注释-only 清单合法**），按需构造提交，随后以 `printf '%s\n' "$line" | bash <hook 路径>` 驱动：
       ① 干净 ref ⇒ rc=0；
       ② 泄漏 ref（探针字面按 L-137 拼接构造）⇒ rc≠0 且报文含 `🔴 拒绝推送` 与**被拒 ref 名**；
       ③ 纯删除推送（new sha = 40 个 0，old sha ≠ 0）⇒ rc=0 且报文含 `ℹ️ 纯删除推送：跳过内容扫描`（实现位 `flow-kit-bundle/hooks/pre-push/pre-push.sh:181-182`）；
       ④ 畸形 stdin 行（缺 local sha）⇒ rc≠0 且报文含 `pre-push stdin 行缺 local sha`（fail-closed，不得 `continue`）；
       ⑤ 缺允许清单态（检查器在、清单缺）⇒ rc=2 且报文指名缺的清单路径（T-FIX-13 语义，勿回退）；
       ⑥ 消费者形态（项目无 Makefile）⇒ 不因缺 Makefile 报红，但泄漏仍必须 rc≠0（与 `T-FIX-14` 的安装形态腿同源；若 `T-FIX-14` 已把该腿写进 `test_install_layout.bats`，本任务只做「源码树形态」的对应腿并注明分工）。
    3. **变异反向控制**：`cp -a flow-kit-bundle /tmp/tfix16/mut` 后精确改两处（`:171-172` 畸形守卫 `exit 1`→`continue`；`:198-199` 泄漏拒绝 → `scan_rev || true`），用同一 bats 指向 `/tmp/tfix16/mut/hooks/pre-push/pre-push.sh` ⇒ **腿②④必须 not ok**；贴输出。
    4. 同步与提交：`make test-sync` → `make check-test-sync` → `make check`；`git add` 逐路径 + `git commit -m "test: pre-push 行为级常设 bats（T-FIX-16 · R5-7）" -- <路径…>`。
    5. SUMMARY（含先红/变异证据）+ `status="done"` + `<done>` 注记 + `task_progress` 五字段。
  </action>
  <verify>
    ① `npx bats test/test_pre_push_behavior.bats` ⇒ not ok = 0 且用例数 ≥ 6。
    ② 变异腿：两台变异体上腿②/④ **必须 not ok**（贴证据）。
    ③ 分工核对：`grep -c 'install_layout' test/test_pre_push_behavior.bats` 与 `T-FIX-14` 的 bats 无重复用例（同名断言不得两处并存）。
    ④ `npx bats test/test_archive_commit_gate.bats` 仍全绿（既有静态断言未被削弱）；`make check` 21 ✅ / 0 ❌。
  </verify>
  <depends_on>T-FIX-14（pre-push 路径解析已定稿后再钉行为判据）</depends_on>
  <done>AC-3 行为级常设网 `test/test_pre_push_behavior.bats`（6 例 · 源码树形态 · 全真跑 hook）落档：① 干净 rc=0、② 泄漏 rc≠0+指名 ref、③ 纯删除 rc=0+跳过措辞、④ 畸形 stdin rc≠0+fail-closed、⑤ 检查器在+清单缺 rc=2+具名、⑥ 消费者形态（无 Makefile）泄漏仍 rc≠0。先红（`/tmp/tfix16/pre.txt`）：变异体（`exit 1→continue` + `泄漏拒绝→scan_rev || true`，语法合法、`bash -n` 过）上 12 条既有静态断言全绿 ⇒ 旧网从不执行 hook。变异反向控制（`/tmp/tfix16/mut-run.txt`）：同一 bats 指向变异体 ⇒ 腿②④ not ok（腿⑥额外 not ok）。分工核对：`grep -c 'install_layout' test/test_pre_push_behavior.bats` = 3（仅注释，非用例名）；T-FIX-14 `test_install_layout.bats`（安装形态 8 例）与本文件（源码树形态 6 例）用例名无重复。`npx bats --count test/` = 1082（开工 1076 + 6）；`test_archive_commit_gate.bats` 45 例仍全绿；`make check` 21 ✅ / 0 ❌。前提修正：派发词背景 L-54 称"仓库 reference 无 allowlist"为过时信息（`f315b64` T21 已冻结常设权威清单进 HEAD），腿⑤改用自建沙箱 reference（拷检查器不拷 allowlist）精确命中状态②，判据（状态②⇒rc=2）未变；`fix_rounds=1`〔2026-09-28 执行者自跑〕</done>
</task>

<task id="T-FIX-17" parallel="false" status="done" model-tier="top">
  <name>【R5-15 🟡 · R5-16 🟡】隐私门禁磁盘侧检索隔离候选路径（消除 fail-open 与扫描面塌缩）+ rev 面批量化回到 5 s 预算内</name>
  <read_files>
    <`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh:600-680`（磁盘侧 `raw_disk=$(grep -naE "$PAT" "$file" …)` 无 `--`；rev 模式 `:606` 每候选一次 `git grep`）>
    <`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh:380-400`（候选面 `git ls-files -z --`）· `:760-790`（`while IFS= read -r -d '' f; do … scan_file "$f"; done < "$TMP_CANDIDATES"` 候选循环与 `scan_file` 共用 stdin）>
    <`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh:560-600`（T-FIX-12 的 index 侧批量扫描与 `parse_grep_null_filtered`，复用其写法）· `:900-923`（自证四数口径输出）>
    <`.specs/health-fix-2026-09b/REVIEW.md` 的 `R5-15`（含主 agent 三腿夹具 `/tmp/p6d/a2c-verify.sh` 的实测：leg A/B 静默 rc=0、leg C 对照 rc=1）· `R5-16`（rev 7.084–7.509 s vs 工作树 3.6–3.8 s）>
    <`.specs/health-fix-2026-09b/REQUIREMENT.md:495`（NFR「单次运行 ≤5 秒」）· `TEST.md:248` / `:265`（超阈值即未满足 · 不做负载折算）>
  </read_files>
  <write_files>
    <`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`（磁盘侧 `grep … -- "$file"` + 候选循环改走独立 FD + rev 面批量预扫描）>
    <`test/test_path_privacy_gate.bats`（新增：候选名似 grep 选项的行为腿 + 扫描面计数腿 + rev 计时腿留档）>
    <`T-FIX-17-SUMMARY.md`（新件）>
  </write_files>
  <action>
    1. **先红**：把主 agent 的三腿夹具口径复现为本地夹具（`/tmp/tfix17/pre.sh`）：工作树里放一个名为 `-q` 的候选（内容含真泄漏）与一个 `zz_control.txt`（含泄漏），分别跑 ⇒ 当前应为 `实际扫描 1 / 命中 0` 且 **rc=0**（静默放行）或命中塌缩；存 `/tmp/tfix17/pre.txt`。
    2. **修 fail-open**：磁盘侧检索加模式侧选项终止（**正确形式 `grep -naE -e "$PAT" -- "$file"`**；不得写成 `grep -naE -- "$PAT" -- "$file"`——第二个 `--` 会被当作文件名），并让候选循环从**独立 FD** 读取（如 `while … done < "$TMP_CANDIDATES" 3<&0` 或先读入临时表后循环），使 `scan_file` 内任何子进程都不可能消费候选流。
    3. **加自证**：为「候选数 vs 实际扫描数」增设显式一致性断言——扫描结束后若 `实际扫描 < 候选数` 且差额不由 `不可读` 解释，则打印具名 `🔴` 并 `exit 1`（fail-closed），同时把两个计数一并印在既有自证行中。
    4. **rev 面批量化（`R5-16`）**：仿 `T-FIX-12` 的 index 侧做法，对 `$RESOLVED_REV` 做**一次**批量 `git grep -naE --null "$PAT" "$RESOLVED_REV"`（按候选集合过滤），替代逐候选 `:606` 的调用；fail-closed 语义不变（批量 rc≥2 ⇒ `🔴 无法完成扫描…` exit 1）。若批量路径无法覆盖 gitlink/不可读候选，保留逐候选**兜底**但仅限异常候选（并在 SUMMARY 说明口径）。
    5. **判据**：`test/test_path_privacy_gate.bats` 新增 ≥4 例：① 候选名 `-q`/`-v` 且在 index 与工作树各有一处泄漏 ⇒ rc=1 且两处均被归因；② 候选名 `-q` 干净 + 其他候选含泄漏 ⇒ 泄漏仍被检出（扫描面不塌缩），并断言自证行 `实际扫描 == 候选 - 不可读`；③ rev 形态计时：5 次 `CHECK_REV=HEAD` 实测均 ≤5 s（打印 max/mean/预算百分比；不做负载折算）；④ 反向控制：把磁盘侧 `--` 去掉后腿①必须转红（临时验证后还原）。
    6. 同步与提交：`make test-sync` → `./sync-hooks.sh`（若 `hooks/**` 未改可跳过并在 SUMMARY 说明）→ package 两脚本 → `make check-hooks-sync check-test-sync check-dist` → `make check`；逐路径 `git add` + `git commit -m "fix(privacy): 磁盘侧检索隔离 + rev 面批量化（T-FIX-17 · R5-15/R5-16）" -- <路径…>`。
    7. SUMMARY + `status="done"` + `<done>` 注记 + `task_progress` 五字段。
  </action>
  <verify>
    ① 先红证据留存（`/tmp/tfix17/pre.txt` 含 `实际扫描 1` 或 rc=0 静默放行的原文）。
    ② `npx bats test/test_path_privacy_gate.bats` ⇒ not ok = 0；用例数 ≥ 34（现 30 + 新增 ≥4）。
    ③ 计时：连续 5 次 `time CHECK_REV=HEAD bash flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`（在最小夹具仓内、warm-up 1 次后取 5 次）⇒ 每次 `real` ≤ 5.000 s，打印 max/mean/预算%；工作树形态（无 `CHECK_REV`）不得劣化（≤ 4.5 s）。
    ④ 真仓复算：`make check-path-privacy` rc=0 且自证四数口径（候选/扫描/index 侧/不可读）与修复前语义一致（候选数不缩小）。
    ⑤ `make check` 21 ✅ / 0 ❌。
  </verify>
  <depends_on>T-FIX-16（串行：全仓门禁为独占步骤）</depends_on>
  <done>磁盘侧 fail-open + 扫描面塌缩双管修复（commit `60f0835`）：① 磁盘 grep `grep -naE -e "$PAT" -- "$file"`（选项终止 + 模式绑定）；② 候选循环 `done 3<`（独立 FD 结构性防线）；③ 自证一致性断言 `CANDIDATE == SCANNED + SKIPPED` 不等则 🔴 exit 1 + `自排除 N 个` 印进自证行；④ rev 面批量化 `git grep -naE --null "$PAT" "$RESOLVED_REV"` 一次替代逐候选 `:606`，`scan_file` rev 分支改 `git cat-file -t` 判 blob（批量覆盖）+ 非 blob 兜底逐候选。先红（`/tmp/tfix17/pre.txt` v1 + `pre2.txt` v2）：`-q` + `zz_control.txt` 候选，v2 决定性——`zz_control` 磁盘泄漏但 index 干净 ⇒ 磁盘 `-q` 吞 stdin 消费候选流 ⇒ `实际扫描 1`（应 2）+ `命中 0`（应 1）+ rc=0 假绿。后绿：v1 `实际扫描 2` + `命中 2`（-q:1+zz_control.txt:1）+ rc=1；v2 `实际扫描 2` + `命中 1`（zz_control.txt:1）+ rc=1；一致性 4=2+2 ✅。DEDUP grep 硬化 3 处（`record_hit:522`/`parse_grep_null_filtered:571`/`count_in_allowlist:847`）+ `record_hit` 内容归一化（剥 trailing `\n`）。bats 34 例全绿（基线 30 + 新增 4）：① `-q`+`zz_control` 均 index+worktree 泄漏 ⇒ rc=1 两处均归因；② `-q` 干净 + `zz_control` 磁盘泄漏 ⇒ 泄漏检出 + scanned+skipped==candidate + unreadable==0；③ rev 计时 5×≤5s（max=0.061s mean=0.0578s 预算 1.2%）；④ 反向控制。**关键发现**：仅摘 `-e/--` 不足以复现——独立 FD 单独防塌缩，④ 重新设计为同摘两道防线（磁盘 `-e/--` + 候选循环 `<&3`/`3<`）⇒ `zz_control` 漏报（塌缩重现 ✅）。真仓计时：工作树 3.767–3.835s（≤4.5s ✅）、rev 4.405–4.544s（从 R5-16 基线 7.084–7.509s 降 ~40%）。真仓复算 `make check-path-privacy` rc=0，自证五数 候选 1611/实际扫描 1605/自排除 6/index 侧 15/不可读 0，一致性 1611=1605+6 ✅。`make check` 21 ✅ / 0 ❌；`npx bats --count test/` = 1086（开工 1082 + 4）；sync-hooks 跳过（未改 hooks/**）；`fix_rounds=1`〔2026-09-28 执行者自跑〕</done>
</task>
<task id="T-FIX-18" parallel="false" status="done" model-tier="top">
  <name>【R5-14 🟡 / R5-10 🟡】`check-gate-sync` 缺文件必须 fail-closed + 补 AC-4 判别形态与 `$status` 断言</name>
  <read_files>
    <`flow-kit-bundle/flow-kit/reference/check-gate-sync.sh:100-135`（`check_pair` 的 MISSING 分支 · T-FIX-04 已修）· `:180-210`（gate-config 分支：缺文件只 `WARNING` + 裸 `return`）>
    <`test/test_check_gate_sync.bats`（现覆盖面 · 与缺失文件路径的缺口）>
    <`.specs/health-fix-2026-09b/REVIEW.md` 的 `R5-14`/`R5-10`（四要素 + Remedy + 主 agent 亲验证据）>
    <`.specs/health-fix-2026-09b/REVIEW.md:420`（`F6` 先例 · 同级判 🟡 的一致性依据）>
    <`REQUIREMENT.md` 的 AC-4（判据不可只靠行数）· `DESIGN.md:372`（允许清单读序）>
  </read_files>
  <write_files>
    <`flow-kit-bundle/flow-kit/reference/check-gate-sync.sh`（缺件路径 fail-closed）>
    <`test/test_check_gate_sync.bats`（补缺失文件腿 / 行数不变腿 / `$status` 腿）>
  </write_files>
  <action>
    1. 先红基线：忠实夹具（`/tmp/tfix18/cp1` = 真 `flow-kit/` + `skills/` + `test/` 全量拷贝）删 `test/test_gate_config_presets.bats` 后运行 ⇒ 当前 rc=0 + `⚠️  WARNING: 文件缺失，跳过 gate-config 同步校验` + 仍打印 `✅ 校验对 3/14 一致`。移走 `skills/flow/SKILL.md` 同样 rc=0。把两条红线（命令 + rc + 报文）贴进 SUMMARY。
    2. 修 `check-gate-sync.sh:190-202`：缺 `skills/flow/SKILL.md` / `test/test_gate_config_presets.bats` 时改为 `🔴 MISSING <文件>：gate-config 同步无法校验（未比对）` + `ERRORS=$((ERRORS + 1))` + 具名文件路径，禁止裸 `return`。措辞与 `check_pair` 的 MISSING 分支保持同族（T-FIX-04 先例），但**必须**打印 gate-config 侧自身名号。
    3. 修 AC-4 判别形态（`R5-10`）：确保「两侧行数相同、内容不同」也必须判红——即 `check_pair` 的判定不得依赖行数差；若当前实现存在行数短路，改为先比内容哈希再报行数（`prompt <n> 行 vs skill <m> 行`）。
    4. 在 `test/test_check_gate_sync.bats` 增常设腿（≥4 例）：① 删 `test/test_gate_config_presets.bats` ⇒ `[ "$status" -ne 0 ]` + 输出含 `🔴 MISSING` + 不含 `✅ 校验对`；② 删 `skills/flow/SKILL.md` ⇒ 同上；③ 只改一行内容（行数不变）⇒ `[ "$status" -ne 0 ]` + 输出含具名定位；④ 反向控制：完整树 ⇒ `[ "$status" -eq 0 ]` 且含 `✅`。每例都必须断言 `$status`（`R5-13` 同族弱点，不得只 grep 报文）。
    5. 同步与提交：`make test-sync` → `bash flow-kit-bundle/flow-kit/reference/...`（不需要 hooks 同步）→ `package-dsh-plugin.sh` / `package-flow-kit.sh` → `make check-hooks-sync check-test-sync check-dist` → `make check` 21 ✅ / 0 ❌；`git add` 逐路径 + `git commit -m "..." -- <路径…>`（`-m` 在 `--` 前；禁 `git add .` / `-A` / `--no-verify` / `git stash`）。
    6. 提交后写 `T-FIX-18-SUMMARY.md`（六维自评 + 红/绿线证据 + 未验证边界），勾 `status="done"`、追加 `<done>` 注记与 `task_progress` 五字段（`commit_sha` 先取真值再 `--arg`，`completed_at` 取 `date -Iseconds`，Δ ≤ 120 s）。
  </action>
  <verify>
    ① 先红留档：`bash /tmp/tfix18/pre.sh` 输出含 `WARNING: 文件缺失` 且 rc=0（缺陷态证据，提交前生成）。
    ② `npx bats test/test_check_gate_sync.bats` 全绿（含 4 条新腿，逐例断言 `$status`）。
    ③ 变异腿：把 `check-gate-sync.sh` 的缺失分支临时还原为 `WARNING` + `return` ⇒ 同套 bats 的腿①/②必须 **not ok**（证明判据有牙）。
    ④ 具名性：腿①输出必须含被删文件的确切路径字符串，不得只含泛化措辞。
    ⑤ `make check` 21 ✅ / 0 ❌。
  </verify>
  <done>`check_gate_config_sync()` 缺件路径 fail-closed（commit `4ce0d5e`）：① `:198-211` 由 `⚠️ WARNING + 裸 return` 改为同族 `🔴 MISSING: gate-config 同步无法校验（未比对）` + `ERRORS=$((ERRORS+1))` + 具名文件路径（`skill:` / `bats:` 行），位掩码 `missing` 同判两侧（bash 3.2 兼容，无 `declare -A`）。先红（`/tmp/tfix18/pre.sh`）：缺 `test_gate_config_presets.bats` 与缺 `skills/flow/SKILL.md` 均 rc=0 + `WARNING: 文件缺失` + 仍打印 `✅ 校验对 3/14 一致`（缺件仍报绿）。后绿：修复后缺件 rc=1 + `🔴 MISSING` + 具名路径 + 不打印 `✅ 校验对`。② AC-4 判别形态（R5-10）：已核实 `check_pair()` 的判定本就是内容比对（`:117 diff_out=$(diff …)`，无行数短路）⇒ 不改判定实现，仅补测试腿钉住「行数不变、内容不同」必判红。③ bats +4 腿（基线 11→15）：R5-14 ① 缺 bats 文件 / ② 缺 SKILL.md（均 `[ "$status" -ne 0 ]` + `🔴 MISSING` + 具名路径 + 非 `✅ 校验对`）；R5-10 ③ 仅改末行内容行数不变（`wc -l` 前后相等前提断言 + `[ "$status" -ne 0 ]` + `漂移`）；④ 反向控制完整树 rc=0 + `✅`。每例断 `$status`（R5-13 同族）。变异反向控制：还原 `WARNING+return` ⇒ 腿①/② not ok、③/④ ok ⇒ 判据有牙。具名性：腿① 输出含 `test/test_gate_config_presets.bats`、腿② 含 `skills/flow/SKILL.md`。`make check` 21 ✅ / 0 ❌；`npx bats --count test/` = 1090（基线 1086 + 4）；`fix_rounds=1`〔2026-09-28 执行者自跑〕</done>
  <depends_on>T-FIX-17（串行：全仓门禁为独占步骤）</depends_on>
</task>

<task id="T-FIX-19" parallel="false" status="done" model-tier="top">
  <name>【R5-9 🟡】AC-1 载荷注入与 6 副本判据常设化（现有覆盖为一次性探针）</name>
  <read_files>
    <`flow-kit-bundle/hooks/pre-tool-use/runtime-edit-guard.sh`（AC-1 实现本件）>
    <`test/test_runtime_edit_guard.bats:57-109`（现有 9 例：全是路径解析 / 维护源 / `~` 展开，**无载荷注入、无哨兵断言、不枚举 6 副本与 `dist/` 归档面**）>
    <`.specs/health-fix-2026-09b/TASK.md` 中 `T05` 块的判据面（change 期 AC-1 六面 + 源树 + tarball 全 0 的判定；抽取时注意避免裸标签 token 污染抽取）>
    <`.specs/health-fix-2026-09b/REVIEW.md` 的 `R5-9`（四要素 + Remedy）>
    <`REQUIREMENT.md` 的 AC-1（载荷必须经拼接构造 · 不得字面出现）>
  </read_files>
  <write_files>
    <`test/test_runtime_edit_guard.bats`（追加常设腿）或新 `test/test_payload_injection.bats`>
  </write_files>
  <action>
    1. 先红基线：用一次性探针（放 `/tmp/tfix19/`）把 `$(touch <哨兵>)` 形态载荷（**拼接构造**，测试/探针源件内不得出现可直接运行的整串，见 L-137）喂给 `flow-kit-bundle/hooks/pre-tool-use/runtime-edit-guard.sh`，证明「现常设 9 例全绿但载荷形态未被断言」——即现有常设网对载荷回归零判别力。记录命令 + rc + 哨兵存在性 + 输出为红线。
    2. 落常设腿（≥4 例，追加进 `test/test_runtime_edit_guard.bats`）：① 三条拼接构造的 `$(…)` 载荷路径（**期望值由主 agent 实测给定，勿照直觉照抄**）：(a) 运行面内载荷路径 `~/.claude/hooks/<载荷>/x.sh`（派生的维护源 `flow-kit-bundle/hooks/<载荷>/x.sh` 不存在）⇒ 现实现 **exit 0** 放行 + 哨兵不存在；(b) 同 (a) 的路径 + 夹具里**字面建出**该维护源（目录名就是载荷串）⇒ 现实现 **exit 2**（`⛔ 检测到改运行时副本`）+ 哨兵不存在；(c) 运行面外载荷 `/tmp/<载荷>/x` ⇒ **exit 0** + 哨兵不存在。**判别力在哨兵断言而非 `$status`**：基线 eval 形态下 (a)(b)(c) 分别为 `rc=0+哨兵存在` / `rc=0+哨兵存在` / `rc=0+哨兵存在`（主 agent 实测 `/tmp/p6d/tfix19-main/probe2.sh`）⇒ 仅断 `$status` 无法区分 (a)/(c) 的新旧实现。每例都断 `$status` 确切值 + **哨兵文件不存在** + 报文片段（(b) 断 `⛔`）；② 6 个部署副本（`./sync-hooks.sh:56-63` 的 `DEST_ROOTS` 清单）逐件 `cmp -s` 与源件一致，且该形态静态计数 `grep -cE` = 0；③ `dist/` 归档面同形态计数 = 0（若该形态不适用于归档则写明理由并给替代断言）；④ 反向控制（产品侧变异，见判据③）：还原基线 eval 形态的守卫副本上，腿① 的哨兵断言必须 not ok。
    3. 判据不得只 grep 报文：每条断 `$status` + 哨兵文件存在性 + 输出片段三者之一以上。
    4. 同步与提交：`make test-sync` → `make check-hooks-sync check-test-sync check-dist`（若未触碰 hooks 可略过 `sync-hooks.sh`）→ `make check` 21 ✅ / 0 ❌；`git add` 逐路径 + `git commit -m "..." -- <路径…>`。
    5. 提交后写 `T-FIX-19-SUMMARY.md` + 勾 `status="done"` + `<done>` + `task_progress` 五字段（Δ ≤ 120 s）。
  </action>
  <verify>
    ① 先红留档：`bash /tmp/tfix19/pre.sh` 把拼接载荷喂给守卫 —— 现实现 `rc=0 + 哨兵不存在`，基线 eval 形态（`git show 534e3e8…`）`rc=0 + 哨兵存在` ⇒ 证明现有 9 例常设网对载荷回归零判别力（主 agent 实测参照 `/tmp/p6d/tfix19-main/probe2.sh`：三形态下新旧守卫的 rc/哨兵对照表）。
    ② `npx bats test/test_runtime_edit_guard.bats`（或新件）全绿且含 ≥4 条新腿。
    ③ 变异腿（**产品侧**，不是夹具字符串形态）：把 `/tmp/tfix19/mut/` 内的守卫副本按 `534e3e842fc900045f39492badc66eabe3ffd4c4` 版本第 46 行还原为 `real_path=$(eval echo "$file_path" 2>/dev/null) || real_path="$file_path"` ⇒ 哨兵腿必须转 not ok（载荷被执行、哨兵被创建）；还原为现实现即转绿。仅把夹具里的拼接改成字面一律不算通过。
    ④ `make check` 21 ✅ / 0 ❌。
  </verify>
  <depends_on>T-FIX-18（串行：全仓门禁为独占步骤）</depends_on>
  <done>40b909a · 2026-09-28T05:05:42+08:00 · 15/15 绿 · make check 21✅/0❌（NFR 假红由主 agent 44f3693 修复）</done>
</task>

<task id="T-FIX-20" parallel="false" status="pending" model-tier="top">
  <name>【R5-26 🟡 / R5-12 🟢】AC-7 删除注入封闭（去 `$HOME` 回落）+ combined metric 驱动真实路径</name>
  <read_files>
    <`test/test_independent_review_model.bats:12-20`（`FK_SRC_29` 主路径 = 仓库源树、`:18` 回落 `$HOME/.claude/hooks/stop/29-independent-review.sh`）· `:40`/`:46`/`:60`（另有**直接**引用 `$HOME/.claude/hooks/stop/30-ai-analyze.sh` 的断言 ⇒ 同族非封闭）>
    <`test/test_combined_metric.bats`（是否驱动真实清理路径 · 文件尾换行）>
    <`.specs/health-fix-2026-09b/REVIEW.md` 的 `R5-26`/`R5-12` + `INDEPENDENT-REVIEW-6.md` 的 `F3`>
    <`flow-kit-bundle/hooks/stop/29-independent-review.sh`（被注入源件的真实位置）>
  </read_files>
  <write_files>
    <`test/test_independent_review_model.bats`（去 `$HOME` 回落 + 删除注入腿）>
    <`test/test_combined_metric.bats`（真实路径 + 文件尾换行）>
  </write_files>
  <action>
    1. 先红基线：删 `flow-kit-bundle/hooks/stop/29-independent-review.sh` 后跑 `test/test_independent_review_model.bats` ⇒ 当前 12 例**全绿**（因 setup 回落到 `$HOME/.claude/...`）⇒ 判据不封闭；记录红线。
    2. 修 setup：源件路径只指向**仓库源树**（`flow-kit-bundle/hooks/stop/…`），删除 `:18` 的 `$HOME` 回落；源件缺失即 fail-fast（bats 内 `[ -f "$FK_SRC_29" ]` 断言 + 明确报错），不得静默跳过。**并把全部 `$HOME/.claude/hooks/stop/**` 引用改为仓库源树同路径件**（主 agent 实测当前命中 **14 处**：`:18`/`:40`/`:46`/`:60`/`:68`/`:74`/`:83`/`:84`/`:87`/`:91`/`:107`/`:116`/`:127`/`:133`；开工前用 `grep -n 'HOME/\.claude/hooks/stop' test/test_independent_review_model.bats` 重取，若数量更多一并改）。**例外**：`:142`/`:143` 的 `$HOME/.claude/stop-hook.json` 属「已安装环境」面，可保留，但必须在其用例内显式 `skip`（文件不存在时）或改用夹具 HOME，**禁止静默回落/恒真**。
    3. 增删除注入腿：临时移走 bundle 源件 ⇒ 该 bats 必须 **not ok**（≥1 例）；恢复后必须回绿。
    4. `R5-12`：`test/test_combined_metric.bats` 改为驱动真实清理路径（不得只测纯函数壳），并补文件尾换行。
    5. 同步与提交：`make test-sync` →（若触碰 hooks 则 `./sync-hooks.sh`）→ `package-*.sh` → `make check-hooks-sync check-test-sync check-dist` → `make check` 21 ✅ / 0 ❌；`git add` 逐路径 + `git commit -m "..." -- <路径…>`。
    6. 提交后写 `T-FIX-20-SUMMARY.md` + 勾 `status="done"` + `<done>` + `task_progress` 五字段（Δ ≤ 120 s）。
  </action>
  <verify>
    ① 先红留档：`bash /tmp/tfix20/pre.sh`（删源件后跑现版 bats ⇒ rc=0 全绿）。
    ② `npx bats test/test_independent_review_model.bats` 全绿（含删除注入腿）；`npx bats test/test_combined_metric.bats` 全绿。
    ③ 变异腿：删 `flow-kit-bundle/hooks/stop/29-independent-review.sh` 后同套 bats 必须 not ok。
    ④ 封闭性（源树面）：`grep -cE 'HOME/\.claude/hooks/stop' test/test_independent_review_model.bats` = **0**（14 处引用全部改为仓库源树路径）。
    ⑤ 封闭性（环境面残留）：`grep -nE 'HOME/\.claude' test/test_independent_review_model.bats` 的剩余命中只允许是 `stop-hook.json` 用例，且该用例在文件缺失时必须 `skip`（贴出 `npx bats -f <该用例名>` 在「文件存在 / 临时改名后」两态的输出作为证据）。
    ⑥ `make check` 21 ✅ / 0 ❌。
  </verify>
  <depends_on>T-FIX-19（串行：全仓门禁为独占步骤）</depends_on>
</task>
<task id="T-FIX-21" parallel="false" status="pending" model-tier="top">
  <name>【R5-8 🟡 / R5-1 🟡（报告侧）/ R5-2 🟢】`TEST.md` 汇总面可复算订正与数量口径生成规则 + 台账归一（伪条目 / 幽灵键 / 时区口径）</name>
  <read_files>
    <`.specs/health-fix-2026-09b/TEST.md` 的 §1.3（第 3/4 条的旧计数与行号引用）· `:55`（AC-2 措辞）· §1.1（AC-6 bats 计数补记）>
    <`.specs/health-fix-2026-09b/REVIEW.md` 的 `R5-8`/`R5-1`/`R5-3`（四要素 + Remedy；`R5-3` 已完成的部分不得回退）>
    <`.specs/health-fix-2026-09b/MINOR-DEFERRED.md` 的「L2 第 5 轮盲审发现处置」节（已完成的订正记录）>
    <`.flow-active` 的 `goal.task_progress` 全量（含 `T-FIX-09` 的字面 `"$(git rev-parse HEAD)"` 伪条目、`completed_at` 的 epoch 整数与 ISO 字符串混用、以及可能存在的顶层 `.goal` 幽灵键）>
  </read_files>
  <write_files>
    <`.specs/health-fix-2026-09b/TEST.md`（§1.3 第 3/4 条 + 数量口径生成规则行）>
    <`.flow-active`（仅 `goal.task_progress` 归一字段；gitignored、不提交）>
  </write_files>
  <action>
    1. 先复算现状：逐条重跑 §1.3 引用的命令，记录「报告写的数」vs「实跑的数」并列表（禁止照抄旧值）。同时订正 `TEST.md:54` 的自相矛盾行：TD-053 的现实是「change 期判据覆盖 + 常设网缺口（`R5-9`）」，不得再写「已闭合（9 用例）」——`R5-9` 落地后改写为指向新增载荷腿。
    2. 就地订正 §1.3 第 3/4 条：更新计数与行号引用为实测值；行号引用必须指向**当前**文件（`REQUIREMENT.md:139`/`:168`/`:177` 形态）。
    3. 追加「数量口径生成规则」行：写明每个计数由哪条命令产生（命令原文），使后轮可直接复算；不得只写结论数字。
    4. 不得改动 `R5-3` 已完成的部分（§1.1 的 AC-6 补记、发现表 #43–#49、`:558` 索引行）；若发现与实测冲突，只增订正注记，不删原文。
    5. **台账归一（`R5-2`）**：重写前 `mkdir -p /tmp/tfix21 && cp .flow-active /tmp/tfix21/flow-active.bak`，然后按规则就地重写 `.flow-active` 的 `goal.task_progress`：① 删除**伪条目**（`id="T-FIX-09"` 且 `commit_sha` 为字面 `$(git rev-parse HEAD)` 的那条；同 id 的正常条目 `81c920e…` 必须保留）；② `completed_at` **一律归一为 ISO8601 带时区**（epoch 整数用 `date -d @<n> -Iseconds` 转换，转换后回读校验）；③ 全表按 `completed_at` **升序稳定排序**（同值保持原相对序），使台账 = 时间线；④ 顶层 `.goal` 幽灵键若存在则删除；⑤ **短 sha 展开为 40 位**（主 agent 实测：归一前有 23 条 7 位短 sha，`git rev-parse --verify --quiet <short>^{commit}` 全部可解析）——用 `git rev-parse` 换成 40 位；若个别解析失败（对象不存在/歧义）则**保持原值**并在 SUMMARY 逐条列出（禁止猜测）。**禁止**改动任何条目的 `fix_rounds`/`deferred` 语义与 `commit_sha` 指向的提交，禁止删除正常条目。**注意**：只归一 `goal.task_progress[].completed_at`，**顶层 `updated_at` 必须保持 epoch 整数**（`flow-kit-bundle/hooks/stop/33-flow-active-integrity.sh:235` 做 `now - updated_at` 算术；写成 ISO 会让该钩子报 `行 235: 2026-09: 值对于底数而言过大` rc=1 —— 主 agent 2026-09-28 实测踩坑后复原）。
    6. 提交：`git add .specs/health-fix-2026-09b/TEST.md` + `git commit -m "..." -- .specs/health-fix-2026-09b/TEST.md`（逐路径；`-m` 在 `--` 前）。`.flow-active` 为 gitignored 文件，**不提交**。
    7. 提交后写 `T-FIX-21-SUMMARY.md` + 勾 `status="done"` + `<done>` + `task_progress` 五字段（Δ ≤ 120 s；append 到 `goal.task_progress` 末尾）。
  </action>
  <verify>
    ① 复算表：每条订正都可复现（SUMMARY 内含「命令 ⇒ 实测数 ⇒ 报告新值」三列）。
    ② `grep -n '1[0-9] 文件\|45 例\|11 处' .specs/health-fix-2026-09b/TEST.md` 的命中行必须与实测一致。
    ③ `R5-3` 已完成内容仍在（`grep -c '第 11 次执行补记' TEST.md` ≥ 1 · `grep -c '^| 49 |' TEST.md` = 1）。
    ④ 冻结件零改动（`git show --stat HEAD` 不含 CHANGE/REQUIREMENT/DESIGN/INDEPENDENT-REVIEW-1/2/3）。
    ⑤ 台账可复算：`python3 -c "import json,datetime;d=json.load(open('.flow-active'));tp=d['goal']['task_progress'];assert '.goal' not in d;assert not any(str(e['commit_sha']).startswith('$(') for e in tp);assert all(len(str(e['commit_sha']))==40 for e in tp),[e['id'] for e in tp if len(str(e['commit_sha']))!=40];[datetime.datetime.fromisoformat(e['completed_at']) for e in tp];assert tp==sorted(tp,key=lambda e:e['completed_at']);print('OK',len(tp))"` ⇒ 打印 `OK <n>`（n = 归一前条数 − 1 条伪条目，SUMMARY 须同时写出归一前条数与 n；若个别短 sha 解析失败，则把断言改为列出失败 id 并在 SUMMARY 逐条说明），且 `33-flow-active-integrity.sh` rc=0。
    ⑥ `make check` 21 ✅ / 0 ❌（台账改动不影响门禁，仍须全绿）。
  </verify>
  <depends_on>T-FIX-20（串行：全仓门禁为独占步骤）</depends_on>
</task>

<task id="T-FIX-22" parallel="false" status="pending" model-tier="top">
  <name>【R5-20 🟡 / R5-21 🟡 / R5-22 🟡 / R5-5 🟡】安装器 jq 诊断 + 门禁短路次序 + L3 ADR 截断留痕 + SELF_EXCLUDE 补录</name>
  <read_files>
    <`flow-kit-bundle/lib/install_hooks.sh:360-395`（`merged=$(jq … 2>/dev/null)` ⇒ rc=5 在 `set -euo pipefail` 下终止安装、`:393` 告警成死代码）· `install.sh:7` 与 `:125-136`（`check_jq`）>
    <`flow-kit-bundle/hooks/stop/lib/done-validation.sh:100-135`（`phases_done` 短路先于 `[[ -s "$done_path" ]] || return 2`；docstring `:108` 自称 D1/R11 有意设计）>
    <`flow-kit-bundle/hooks/stop/lib/l3-prompt.sh:345-370`（`[ "$_adr_n" -lt 8 ] || break` 静默截断 · 落标记晚于 break）>
    <`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh` 的 `SELF_EXCLUDE` 定义处（需追加 `INDEPENDENT-REVIEW-5.md`/`INDEPENDENT-REVIEW-6.md`）>
    <`.specs/health-fix-2026-09b/REVIEW.md` 的 `R5-20`/`R5-21`/`R5-22`/`R5-5`（四要素 + Remedy）>
  </read_files>
  <write_files>
    <`flow-kit-bundle/lib/install_hooks.sh`（jq 失败具名诊断 + 非零退出语义明确）>
    <`flow-kit-bundle/hooks/stop/lib/done-validation.sh`（短路次序与注释对齐）>
    <`flow-kit-bundle/hooks/stop/lib/l3-prompt.sh`（截断标记先于 break）>
    <`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`（SELF_EXCLUDE 追加两文件）>
    <`test/test_install_coverage.bats` 或新件（jq parse error 腿）>
  </write_files>
  <action>
    1. 先红基线（三条独立红线）：① `settings.json` 预置非法 JSON 后跑 `install.sh` ⇒ 当前 rc=5 且**无**具名诊断（告警死代码）；② `done-validation.sh` 在 `phases_done` 含目标阶段但 `.done` 为空文件时返回 0（短路先于 Tier-1）；③ `l3-prompt.sh` 在 ADR > 8 时静默丢弃且落标记不写。记录命令 + rc + 报文。
    2. 修 `install_hooks.sh:379-393`：把 `jq` 的 parse 失败与「其他失败」分流，打印具名诊断（含 `settings.json` 路径 + jq 原始 stderr 摘要），并让失败路径**显式**决定退出码（不再靠 `set -e` 副作用），`:393` 的告警必须可达。
    3. 修 `done-validation.sh`：把 Tier-1（`.done` 非空）判定移到 `phases_done` 短路**之前**，或明确把短路限定为「历史阶段兜底」并更新 docstring 与常量名；改后两态各自实测（空 `.done` + 在 `phases_done` ⇒ rc=2；非空 ⇒ 按原语义）。
    4. 修 `l3-prompt.sh:357`：截断时**先**写落标记（含「ADR 超上限已丢弃 N 条」措辞）**再** break；实测 ADR 数 > 8 的夹具下标记存在。
    5. `R5-5`：在 `check-path-privacy.sh` 的 `SELF_EXCLUDE` 追加 `INDEPENDENT-REVIEW-5.md`/`INDEPENDENT-REVIEW-6.md`；实测 `make check-path-privacy` rc=0 且候选数不缩小、命中 0。
    6. 常设腿：新增/扩展 bats 覆盖 ①②③（每条断言 `$status` + 报文具名），并保留反向控制（把短路次序改回旧态 ⇒ 腿②必须 not ok）。
    7. 同步与提交：`make test-sync` → `./sync-hooks.sh` → `package-*.sh` → `make check-hooks-sync check-test-sync check-dist` → `make check` 21 ✅ / 0 ❌；`git add` 逐路径 + `git commit -m "..." -- <路径…>`。
    8. 提交后写 `T-FIX-22-SUMMARY.md` + 勾 `status="done"` + `<done>` + `task_progress` 五字段（Δ ≤ 120 s）。
  </action>
  <verify>
    ① 三条先红留档（命令 + rc + 报文）。
    ② `bash -n` 四个生产件 rc=0；`npx bats` 相关件全绿（含新腿）。
    ③ 非法 JSON 夹具：`install.sh` 输出含 `settings.json` 具名诊断 + 非零退出，且**不再**出现「安装成功」类措辞。
    ④ `done-validation.sh` 两态实测与新增 bats 一致（空 `.done` ⇒ rc=2）。
    ⑤ ADR > 8 夹具：`l3-prompt.sh` 落标记存在且含丢弃计数。
    ⑥ `make check-path-privacy` rc=0（候选数不缩小 · 命中 0 · 不可读 0）。
    ⑦ `make check` 21 ✅ / 0 ❌。
  </verify>
  <depends_on>T-FIX-14, T-FIX-17, T-FIX-21（串行：同文件写面 + 全仓门禁为独占步骤）</depends_on>
</task>

<task id="T-FIX-23" parallel="false" status="pending" model-tier="top">
  <name>【R5-23 🟡】NFR 可移植性判据存量基线 + `sync-hooks.sh` 的 `mapfile` 替换</name>
  <read_files>
    <`Makefile:129-160`（目标族说明）· `:162-306`（判据正文：`BASE` 解析 `:233-276`、全量分支 `:167`/`:195`/`:268`/`:286`）· `:308-334`（包装层三态转译）>
    <`.specs/health-fix-2026-09b/.change-base`（本仓 BASE 锚点 ⇒ 默认走变更集模式，存量违禁构造不进扫描面）>
    <`sync-hooks.sh:170-205`（`mapfile` 使用点 · bash 3.2 下 rc=127）· `verify-claims.sh:110-140`（同族 `mapfile`）>
    <`test/test_nfr_portability_gate.bats`（现覆盖面）>
    <`.specs/health-fix-2026-09b/REVIEW.md` 的 `R5-23`（四要素 + Remedy + 审计 B 的 #6 证据：`tracked .sh 文件数=104 · 命中行数=19 · 命中文件数=12`）>
    <`REQUIREMENT.md` 的 AC-8（可移植性声明）>
  </read_files>
  <write_files>
    <`Makefile`（全量模式显式入口 + 归档面排除 + 存量基线 ratchet；不改 `make check` 默认语义）>
    <`sync-hooks.sh`（`mapfile` → 便携读循环）>
    <`verify-claims.sh`（`mapfile` → 便携读循环）>
    <`flow-kit-bundle/hooks/stop/34-archive-commit-check.sh`（`stat -c %Y` → 便携双分支）>
    <`flow-kit-bundle/lib/install_brooks.sh`（GNU `sed -i` → 临时文件 + 原子替换）>
    <`flow-kit-bundle/flow-kit/reference/nfr-portability-baseline.txt`（新建：存量基线清单）>
    <`test/test_nfr_portability_gate.bats`（新增 ≥6 例：注入/变更集取舍/便携写法/归档排除/基线命中/基线陈旧）>
  </write_files>
  <action>
    0. **主 agent 现取实测（2026-09-28，派发词内含完整 19 条清单）**：`NFR_RC_FILE=/tmp/nfr-full.rc FLOW_KIT_CHANGE_BASE=FULL make check-nfr-portability-internals` ⇒ **rc=1 + 19 行 / 12 文件**；默认（变更集模式）rc=0 ⇒ 盲区成立。19 条分类：**归档面 7 条**（`.specs/archive/2026-09-21-health-fix-2026-09/verify/ac8.sh:13`/`:28` · `.specs/archive/2026-09-21-user-guide-sync-2026-09b/make-manifest.sh:28`/`:29` · 同目录 `verify-ac.sh:25` · `.specs/archive/2026-09-22-privacy-path-scrub-2026-09/make-manifest.sh:28`/`:29`）· **可修 7 条**（`sync-hooks.sh:182`/`:197`/`:198` mapfile · `verify-claims.sh:119`/`:135` mapfile · `34-archive-commit-check.sh:47` `stat -c` · `install_brooks.sh:125` GNU `sed -i`）· **登记基线 5 条**（`hooks/stop/lib/common.sh:432` `declare -A` · `hooks/stop/lib/flow-kit-artifacts.sh:51` `declare -A` · `hooks/stop/lib/l3-truncate.sh:100` `declare -A` · 同件 `:167` mapfile · `package-flow-kit.sh:394` `declare -A`）。**本任务按此三分法收口，不得改成「全量也翻红 + 只登技术债」**（那等于归档后 `make check` 自红）。
    1. 先红留档（命令 + rc + 报文）：① `grep -n 'mapfile' sync-hooks.sh verify-claims.sh`；② FULL 模式 rc=1 + 命中清单；③ 默认模式 rc=0（同一构造不报）。
    2. 修 `sync-hooks.sh:182`/`:197`/`:198` 与 `verify-claims.sh:119`/`:135`：`mapfile -t X < <(…)` → `X=(); while IFS= read -r _l; do X+=("$_l"); done < <(…)`（bash 3.2 兼容；禁 `readarray`；空输入时数组长度为 0 的语义须保持——`set -u` 下不得出现「未绑定变量」）。改后逐脚本实跑（`./sync-hooks.sh --check` / `./verify-claims.sh`）并确认输出与改前一致。
    3. 修 `flow-kit-bundle/hooks/stop/34-archive-commit-check.sh:47`：`stat -c %Y` → 便携双分支，**必须 GNU 先、BSD 后**：`stat -c %Y "$p" 2>/dev/null || stat -f %m "$p" 2>/dev/null || echo 0`（主 agent 实测：GNU 的 `stat -f %m <file>` 会把**文件系统信息打到 stdout**、错误打 stderr 且 rc=1 ⇒ 若写成 BSD 先，命令替换会把那段垃圾信息当结果收进去；且判据的 awk 正是用 `gsub(/stat -c … || stat -f …/)` 预剥离这一形态）。保留原 fail-open `|| echo 0`。
    4. 修 `flow-kit-bundle/lib/install_brooks.sh:125`：GNU `sed -i` → `sed … > "$hook_file.tmp" && mv "$hook_file.tmp" "$hook_file"`（语义不变；`.tmp` 不得残留）。
    5. **归档面排除（判据受检面）**：`Makefile` 的 NFR 枚举循环跳过 `.specs/archive/*`——**两处循环都要排除**：`_report_viol()` 里 `git ls-files -z -- "*.sh"`（tracked）与 `git ls-files -oz --exclude-standard`（未跟踪，逐腿夹具会以未跟踪文件出现）之循环，`case "$_f" in .specs/archive/*) continue;; esac`（注释写明理由：「归档快照是冻结的历史记录，修改它没有行动价值；可执行脚本的当前形态由非归档面守护」）。
    6. **存量基线 ratchet**：新建 `flow-kit-bundle/flow-kit/reference/nfr-portability-baseline.txt`（表头注释：生成日期 · 生成命令 · 说明「只登记**本 change 之前**既有的命中；新增构造一律不得入基线」），登记上文 5 条（格式 `路径:行号:标记`）。判据语义改为：命中**不在**基线内 ⇒ `🔴` + rc=1；命中**在**基线内 ⇒ 打印 `ℹ️ 存量基线 N 条（已登记：<清单路径>）` 且不置错；基线条目在真仓**已消失或行号漂移** ⇒ 打印 `⚠️ 基线陈旧：<条目>` + rc=1（防基线腐烂）。**基线只在全量模式生效**：变更集模式保持「新增行命中即红」的现有语义，否则「在基线文件里已有的件上新增 `declare -A`」会被豁免（判据自证行须写明该取舍）。
    7. **全量入口**：新增 `check-nfr-portability-full`（写入 `.PHONY`；目标注释：「日常 `make check` 用变更集模式；**收尾/归档必须再跑本入口**」），内部以 `FLOW_KIT_CHANGE_BASE=FULL` 调用同一 `-internals` 并沿用三态包装语义（`NFR_RC_FILE` 读取 + 3 ⇒ SKIP）。**不得**改 `make check` 的默认模式，**不得**另造第二套判据正文。
    8. 常设腿 `test/test_nfr_portability_gate.bats` 增 ≥6 例（每例断言 `$status`）：① 归档外夹具源件注入 `mapfile` ⇒ 基线模式 rc≠0 + 具名 `文件:行号`；② 变更集模式下同一注入不报（记录已知取舍）；③ 便携写法 ⇒ 两模式皆 rc=0；④ 归档内注入（`.specs/archive/<夹具>/x.sh`）⇒ rc=0；⑤ 夹具命中基线条目 ⇒ rc=0 且输出含 `存量基线`；⑥ 基线陈旧（删掉基线条目对应行后重跑）⇒ rc≠0 且含 `基线陈旧`。
    9. 提交前自查：真仓 `make check-nfr-portability`（默认）rc=0 **且** `make check-nfr-portability-full` rc=0；`check-dist` 若因新增 `reference/nfr-portability-baseline.txt` 报不一致 ⇒ 按既有 `package-*.sh` 流程重建 dist 后再验。
    10. 同步与提交：`./sync-hooks.sh`（若触碰 hooks）→ `package-*.sh` → `make check-hooks-sync check-test-sync check-dist` → `make check` 21 ✅ / 0 ❌；`git add` 逐路径 + `git commit -m "..." -- <路径…>`。
    11. 提交后写 `T-FIX-23-SUMMARY.md` + 勾 `status="done"` + `<done>` + `task_progress` 五字段（Δ ≤ 120 s）。
  </action>
  <verify>
    ① 先红留档：`grep -n 'mapfile' sync-hooks.sh verify-claims.sh`（5 处）；FULL 模式 rc=1 + 19 行/12 文件；默认模式 rc=0。
    ② `bash -n` 六个被改脚本 rc=0；`grep -c 'mapfile\|readarray' sync-hooks.sh verify-claims.sh` = 0；`./sync-hooks.sh --check` 与 `./verify-claims.sh` 实跑输出与改前一致。
    ③ 默认（变更集）模式：真仓 rc=0；归档外夹具注入新命中 ⇒ rc≠0 + 具名；归档内注入 ⇒ rc=0（排除生效）。
    ④ `make check-nfr-portability-full` rc=0 且输出含 `存量基线 5 条`；`FLOW_KIT_CHANGE_BASE=FULL make check-nfr-portability` rc=0。
    ⑤ 基线陈旧检测：夹具删掉基线条目对应行 ⇒ rc≠0 且含 `基线陈旧`。
    ⑥ 常设腿 ≥6 例全绿（含 ①②③④⑤ 六种形态）；`make check` 21 ✅ / 0 ❌。
  </verify>
  <depends_on>T-FIX-22（串行：全仓门禁为独占步骤）</depends_on>
</task>
