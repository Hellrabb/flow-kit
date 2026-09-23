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
| **AC-8** 无退化 | T28（NFR 兼容性判据落点 + `rc=3` 不得当绿灯）、T29（全量 `make check` / bats ≥973 / 三门口禁 / 变更集非空守卫） | 0 not ok；三道副本一致性门禁 0 漂移 |

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
    <`package-flow-kit.sh`（只读 · `--validate` 的 SUT；**不在触碰清单**，不得修改）>
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
  <done>AC-3：拦截器本体存在、可执行（755 入库）、保留 `make check` 语义且 bash 3.2 兼容 —— AC-8 的 `test_quality_baseline.bats` 两条无 skip 断言可达；**被拒 ref 会被指名**（动态断言在 T19：四种 push 形态各须在报文里出现该 ref 名）</done>
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
    **审查档排除面与 T17 门禁的排除表同源（阶段 3 L3 M8）**：两者都是「逐条精确路径」，且 T17 的 verify 断言「`.specs/health-fix-2026-09b/` 下**实际存在**的每一份审查档都在门禁排除表内」（完备性），故后续阶段新增审查档时：门禁侧在 T17 变红并被显式追加、本 task 侧在复扫时同步追加（同一规则、两处判定），不会静默漂移。
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
    hits=$( { git -c core.quotepath=false ls-files -z | xargs -0 grep -HnE "$PAT" 2>/dev/null; printf '%s\n' "$u_hits"; } \
            | sort -u \
            | grep -vE '^(\.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-(1|2|3)\.md):' \
            | grep -vE '/home/(user|ubuntu|\.\.\.)/' );
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
  <done>AC-6 前置：排除表口径下「清单外命中 = 0」。**修复前基线（主 agent 2026-09-23 用本判据实测，共 14 行）**：`DESIGN.md` 1（`:215` 的 `/home/<acct>` 自造 fixture 字面）/ `T04-SUMMARY.md` 9（`:297` `:300`-`:305` `:314` `:316`）/ `T11-SUMMARY.md` 1（`:56`）/ `.specs/health/2026-09-22-FULL-SWEEP.md` 3（`:126` `:242` `:255`）；`REQUIREMENT` / `CHANGE` / `TASK` / `MINOR-DEFERRED` 各 0；审查档 40 = IR-1 22 + IR-2 18（按 D10′② 逐条精确路径豁免，协议禁改原文）。**未 tracked 面**（尚未 `git add` 的工件与同批健康档）由本 task 补扫后才可见 —— 原判据对该面完全失明（L-122 / L-129）。SUMMARY 的 10 行属下文 ⑦ 前向规则的存量债 ⇒ 就地脱敏、不豁免。满足 D10′①「脱敏先于冻结」</done>
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
    # 排除表完备性（阶段 3 L3 M8）：实际存在的审查档必须逐条列在门禁排除表内，否则后续阶段新增审查档会静默漂移
    n_ir=0; for f in $(ls .specs/health-fix-2026-09b/INDEPENDENT-REVIEW-*.md 2>/dev/null | sort); do
      n_ir=$((n_ir+1));
      grep -qF "$f" "$S" || { echo "🔴 排除表缺 $f（与 T13 的排除面漂移：审查档新增时须显式追加精确路径 —— 阶段 3 L3 M8）"; exit 1; };
    done;
    [ "$n_ir" -ge 1 ] || { echo "🔴 未枚举到任何审查档（枚举面失效 ⇒ 判据空转）"; exit 1; };
    # CHECK_REV 外部评估面双态（主 agent 2026-09-23 补 · L-131）：泄漏只存在于历史树、工作树干净 ⇒ rev 模式必须判红并给出扫描面与 file:line
    _cwd=$(pwd); _sbx2=$(mktemp -d /tmp/l3-rev-XXXXXX); git init -q "$_sbx2/r"; trap 'rm -rf "$_sbx2"' EXIT;
    mkdir -p "$_sbx2/r/flow-kit-bundle/flow-kit/reference";
    cp "$S" "$_sbx2/r/flow-kit-bundle/flow-kit/reference/";
    : > "$_sbx2/r/flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt";
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
      out=$(git $form 2>&1); rc=$?;
      [ "$rc" -ne 0 ] || { printf '%s\n' "$out"; echo "🔴 形态 [$form] 未被拦截（rc=$rc）"; exit 1; };
      printf '%s' "$out" | grep -qE '(^|[^[:alnum:]_])main([^[:alnum:]_]|$)' || { printf '%s\n' "$out"; echo "🔴 形态 [$form] 未指名泄漏 ref（main）"; exit 1; };
    done;
    out=$(git push origin --tags 2>&1); rc=$?;
    [ "$rc" -ne 0 ] || { printf '%s\n' "$out"; echo "🔴 形态 [push --tags] 未被拦截（rc=$rc）"; exit 1; };
    printf '%s' "$out" | grep -qE '(^|[^[:alnum:]_])v1([^[:alnum:]_]|$)' || { printf '%s\n' "$out"; echo "🔴 形态 [push --tags] 未指名泄漏 ref（v1）"; exit 1; };
    # 评估面判别子（主 agent 2026-09-23 补 · L-131）：工作树干净时，泄漏仅在 main 的历史树里 ⇒ 仍须被拒且指名 main
    git checkout -q develop;
    out=$(git push --all 2>&1); rc=$?;
    [ "$rc" -ne 0 ] || { printf '%s\n' "$out"; echo "🔴 工作树干净时泄漏分支被放行（评估面错位：扫了工作树而非被推送的树）"; exit 1; };
    printf '%s' "$out" | grep -qE '(^|[^[:alnum:]_])main([^[:alnum:]_]|$)' || { printf '%s\n' "$out"; echo "🔴 工作树干净时未指名 main（归因错位）"; exit 1; };
    mv .git/hooks/pre-push "$SBX/pre-push.off"; git push origin main >/dev/null 2>&1; rc_off=$?; mv "$SBX/pre-push.off" .git/hooks/pre-push;
    [ "$rc_off" -eq 0 ] || { echo "🔴 归因对照失败：摘掉 hook 后泄漏 push 仍 rc=$rc_off（拦截来源不明）"; exit 1; };
    git -C "$SBX/remote.git" update-ref -d refs/heads/main 2>/dev/null || true;
    git checkout -q develop; git push origin develop || { echo "🔴 干净 ref（develop）被误拦"; exit 1; };
    git -C "$SBX/remote.git" rev-parse --verify --quiet refs/heads/develop >/dev/null || { echo "🔴 干净 ref 未真正到达远端"; exit 1; }
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
  <done>AC-6①：pre-commit 仓库内源已接入新门禁且副本一致（修复前实测：`grep -cE 'path|隐私|leak'` 命中 0）</done>
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

<task id="T24" parallel="true" status="pending" model-tier="standard">
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
  <done>AC-1④ + AC-5：重建后的归档 `eval-echo=0` / `chisel=0`，且可注入的 `0.1.0` 已删除（修复前实测：0.1.0=2 处 eval-echo、0.2.0=2 处 eval-echo + 6 处 chisel）</done>
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

<task id="T27" parallel="true" status="pending" model-tier="standard">
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
    export LC_ALL=C; fail=0;
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
    outf=$(mktemp); npx bats test/ --formatter tap > "$outf" 2>&1; b_rc=$?;
    b_ok=$(grep -cE '^ok [0-9]+' "$outf"); b_no=$(grep -cE '^not ok [0-9]+' "$outf");
    echo "bats: rc=$b_rc ok=$b_ok not-ok=$b_no（基线 2026-09-23 实测 rc=0 / 973 ok / 0 not ok，skip 计入 ok 行）";
    grep -E '^not ok [0-9]+' "$outf" | head -5; rm -f "$outf";
    { [ "$b_rc" -eq 0 ] && [ "$b_no" -eq 0 ] && [ "$b_ok" -ge 973 ]; } || { echo "🔴 bats 回归（rc=$b_rc not-ok=$b_no ok=$b_ok）"; exit 1; }
  </verify>
  <done>AC-1①（归档面）+ AC-5①：逐个归档 `eval-echo=0` / `chisel=0` 且非 0 时判据必须非零退出；源测试 0 命中；bats 不退化 = TAP 行断言 `^not ok` 计数 0 且 `^ok` 计数 ≥ 973 且 rc=0（基线 2026-09-23 实测 973 ok / 0 not ok；修复前实测：两档各 2 处 eval-echo、0.2.0 六处 chisel）</done>
  <depends_on>T24</depends_on>
</task>

<task id="T28" parallel="true" status="pending" model-tier="top">
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
  <done>AC-8 的 NFR 侧：判据落点为 `Makefile` 目标（不落 `.sh` ⇒ 无自命中）、**rc=0 且输出不含 `SKIP:` 才通过**（rc=1 = 违规 ⇒ 非零退出；`SKIP:` 出现 ⇒ 判据未真正运行 ⇒ 非零退出，SKIP ≠ PASS；rc=3 泄漏 ⇒ 与 DESIGN §9.3 的包装语义不符 ⇒ 非零退出）、`make check` 接入可见；空集只作 ℹ️ 诊断（**不另设非空守卫** —— 全局 AC-8 非空守卫在 T29）。修复前：`case "$rc" in 0|1) : ;;` 把 rc=1 当通过 —— 阶段 3 L3 M3；语义与 DESIGN §9.3 对齐 + SKIP 可见性断言 —— 阶段 3 L3 M7</done>
  <depends_on>T02, T18</depends_on>
</task>

<task id="T29" parallel="false" status="pending" model-tier="top">
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
    跑全量质量门禁并留档：`make check` 全绿（含两道新门禁）、`npx bats test/` ≥ **973 ok / 0 not ok**、
    `check-test-sync` / `check-hooks-sync` / `check-dist` 仍 0 漂移。
    **必须显式处理 NFR 兼容性判据的三态**：变更集为空时它以 `exit 3`（SKIP）呈现 —— **不得把 SKIP 当绿灯**，
    故先用 `.change-base` 锚点断言变更集非空（守卫与 A 案同锚点）。
  </action>
  <verify>
    export LC_ALL=C;
    # C3：先证「两门禁已接线」再跑 make check —— 否则 T14/T18 未完成时 make check 会在**旧门禁集**上全绿（AC-8「无退化」被架空）
    make -n check 2>/dev/null | grep -q 'check-gate-sync' || { echo "🔴 check-gate-sync 未接入 make check（T14 未完成 ⇒ 全绿不含其实质）"; exit 1; };
    make -n check 2>/dev/null | grep -q 'check-path-privacy' || { echo "🔴 check-path-privacy 未接入 make check（T18 未完成 ⇒ 全绿不含其实质）"; exit 1; };
    make check || { echo "🔴 make check 未全绿"; exit 1; };
    outf=$(mktemp); npx bats test/ --formatter tap > "$outf" 2>&1; b_rc=$?;
    b_ok=$(grep -cE '^ok [0-9]+' "$outf"); b_no=$(grep -cE '^not ok [0-9]+' "$outf");
    echo "bats: rc=$b_rc ok=$b_ok not-ok=$b_no（基线 2026-09-23 实测 rc=0 / 973 ok / 0 not ok；skip 计入 ok 行）";
    grep -E '^not ok [0-9]+' "$outf" | head -5; rm -f "$outf";
    { [ "$b_rc" -eq 0 ] && [ "$b_no" -eq 0 ] && [ "$b_ok" -ge 973 ]; } || { echo "🔴 bats 回归（rc=$b_rc not-ok=$b_no ok=$b_ok）"; exit 1; };
    make check-test-sync >/dev/null && make check-hooks-sync >/dev/null && make check-dist >/dev/null || { echo "🔴 三道副本一致性门禁漂移"; exit 1; };
    BASE8="${FLOW_KIT_CHANGE_BASE:-$(cat .specs/health-fix-2026-09b/.change-base 2>/dev/null || true)}";
    [ -n "$BASE8" ] || { echo "🔴 AC-8：变更起点锚点未落档，无法判定变更集非空"; exit 1; };
    FILES=$( { git -c core.quotepath=false diff --name-only "$BASE8"; git -c core.quotepath=false ls-files -o --exclude-standard; } | grep -E '\.sh$' | sort -u );
    [ -n "$FILES" ] || { echo "🔴 AC-8 时点变更集为空（相对锚点 $BASE8）⇒ 兼容性判据 rc=3（未验证），不得当作通过"; exit 1; }
  </verify>
  <done>AC-8：`make check` 全绿、bats ≥973 ok / 0 not ok、三道副本一致性门禁 0 漂移、变更集非空（`rc=3` 未被当绿灯）</done>
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
- `package-flow-kit.sh` —— **不在任何 write_files**；T10 仅以 `bash package-flow-kit.sh --validate` 作为只读 SUT 调用。✅
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

```xml
<!-- 占位 -->
```
