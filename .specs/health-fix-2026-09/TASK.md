# TASK: 堵住三个门禁盲区（打包件新鲜度 / lint 文件域 / exec 判据）

- **Change ID**: health-fix-2026-09
- **关联**: `@.specs/health-fix-2026-09/REQUIREMENT.md`（11 条 AC）、`@.specs/health-fix-2026-09/DESIGN.md`（8 决策 / 11 风险）

---

## 波次划分

```
Wave 0 (前置):      T00                       —— 重建 dist，使 AC-2 的 Given 成立
Wave 1:             T01[P], T03[P]            —— 并行（文件互不重叠）；T02 依赖 T01 故其后
Wave 1b:            T02                        —— Makefile（依赖 T01 的 --check 接口）
Wave 2 (parallel):  T04[P], T05[P]            —— 验证夹具 + F6 回归守护（T05 depends on T02）
Wave 3:             T06                       —— 理由注释（三载体，depends on T01/T02/T03）
Wave 4:             T07                       —— 全量回归取证（depends on 全部）
```

> 同 wave = 可并行；跨 wave = 必须顺序执行。
> **T00 是前置而非实现**：AC-2 的 Given 要求 dist 与源一致，当前 dist 已对齐（20:24 重建过），但 TEST 阶段会重跑，故单列一步固化该状态。

---

## 任务清单

```xml
<task id="T00" parallel="false" status="done" model-tier="cheap">
  <name>前置：重建 dist 使 AC-2 的 Given 成立</name>
  <read_files>
    package-dsh-plugin.sh
    dsh-flow-kit/README.md
    flow-kit-bundle/test/*
  </read_files>
  <write_files>
    dist/**
  </write_files>
  <action>
    跑 `bash package-dsh-plugin.sh` 重建 dist（其内部含 node 单测 + 语法校验，须 exit 0）。
    完成后用 `diff -rq flow-kit-bundle dist/dsh-flow-kit/vendor/flow-kit-bundle` 确认差异为 0。
    注意：dist/ 被 .gitignore 忽略，本任务不产生 git 可见改动 —— 这是预期的（见 DESIGN §0.5.3）。
  </action>
  <verify>
    bash package-dsh-plugin.sh || { echo "FAIL: 打包失败"; exit 1; }
    # 覆盖 dist 的【全部】复制产物，而非仅 vendor（L3 三轮 major1）
    for pair in "flow-kit-bundle/vendor:dist/dsh-flow-kit/vendor/flow-kit-bundle" \
                "flow-kit-bundle/hooks:dist/dsh-flow-kit/hooks" \
                "flow-kit-bundle/skills:dist/dsh-flow-kit/skills" \
                "flow-kit-bundle/flow-kit:dist/dsh-flow-kit/flow-kit" \
                "flow-kit-bundle/brooks-lint:dist/dsh-flow-kit/brooks-lint" \
                "dsh-flow-kit/lib:dist/dsh-flow-kit/lib"; do
      src="${pair%%:*}"; dst="${pair##*:}"; [ "$src" = "flow-kit-bundle/vendor" ] && src="flow-kit-bundle"
      diff -rq "$src" "$dst" >/dev/null || { echo "FAIL: $dst 与源不一致"; exit 1; }
    done
    echo "T00 OK（全产物一致）"
  </verify>
  <done>dist 重建成功且 vendor 与源差异为 0 → AC-2 的 Given 成立</done>
  <depends_on></depends_on>
</task>

<task id="T01" parallel="true" status="done" model-tier="standard">
  <name>给 package-dsh-plugin.sh 加 --check 新鲜度模式</name>
  <read_files>
    package-dsh-plugin.sh
    Makefile
    flow-kit-bundle/test/*
    flow-kit-bundle/**               <!-- --check 需枚举源侧全量以比对 -->
    dsh-flow-kit/**                  <!-- lib/ + package.json + README.md + DESIGN.md -->
    sync-hooks.sh                    <!-- 参考：镜像 sync-hooks.sh --check 的既有形状与输出体例 -->
  </read_files>
  <write_files>
    package-dsh-plugin.sh
  </write_files>
  <action>
    实现 DESIGN D1/D2/D3：新增 `--check` 模式，只读比对，**不重建、不改工作区**。
    ① 复用脚本第 1-5 步已有的源→dist 映射（**禁止另写一份映射表** —— 单一事实源，见 D2）；
    ② 逐文件 `cmp -s` 内容比对（**不比 mode** —— 构建时有意 chmod，见 §0.5.3，须写注释说明为何不比）；
    ③ 含反向残留检测（dist 有、源已无），沿用 sync-hooks.sh 既有语义；
    ④ `vendor/` 比对**包含 test/**（D3）；
    ⑤ dist 不存在 → 打印"请先跑 package-dsh-plugin.sh" + `exit 0`（优雅降级，与 make dup 处理 jscpd 缺失同款）；
    ⑥ 失败时**逐条指名文件路径**（NFR 可观测性：禁止只说 "check failed"）；
    ⑦ `--check` 必须在脚本顶部 `node -p`（:19）**之前**分流 —— 保证该模式不调用 node/npm（NFR 性能）。
  </action>
  <verify>
    set -u
    # ① 正向：一致时 exit 0 且不重建
    out=$(bash package-dsh-plugin.sh --check 2>&1); rc=$?
    [ "$rc" -eq 0 ] || { echo "FAIL: --check 非零退出（rc=$rc）"; exit 1; }
    echo "$out" | grep -q '==> packaging' && { echo "FAIL: --check 触发重建（参数被静默忽略 / 破坏只读语义）"; exit 1; }
    # ② 负向（AC-1 本任务的可证伪核心 · L3 三轮 C1 补）：改源 → 必须 exit 1 且指名该文件
    trap 'git checkout -- dsh-flow-kit/README.md' EXIT
    printf '\n<!-- T01 negative probe -->\n' >> dsh-flow-kit/README.md
    out2=$(bash package-dsh-plugin.sh --check 2>&1); rc2=$?
    [ "$rc2" -ne 0 ] || { echo "FAIL: 源改动后 --check 仍 exit 0（陈旧未被检出）"; exit 1; }
    echo "$out2" | grep -q 'README.md' || { echo "FAIL: 检出但未指名陈旧文件"; exit 1; }
    git checkout -- dsh-flow-kit/README.md
    # ③ 无参打包 0 回归
    bash package-dsh-plugin.sh >/dev/null 2>&1 || { echo "FAIL: 无参打包回归"; exit 1; }
    echo "T01 OK（正向 + 负向指名 + 无参回归）"
  </verify>
  <done>
    dist 与源一致时 exit 0 且**不重建**；无参打包行为 0 回归；改任一进入 dist 的源文件后 exit 1 且输出指名该文件路径 → AC-1 / AC-2 的机制就位
  </done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true" status="done" model-tier="standard">
  <name>Makefile：lint 改 find 全量枚举 + 输出 SCANNED_FILES + 挂 check-dist</name>
  <read_files>
    Makefile
    package-dsh-plugin.sh            <!-- 依赖 T01 提供的 --check 接口 -->
    flow-kit-bundle/hooks/stop/lib/common.sh
  </read_files>
  <write_files>
    Makefile
  </write_files>
  <action>
    实现 DESIGN D7 + F1 的挂载：
    ① `lint` target 的文件域由手写 glob 改为 `find` 全量枚举（覆盖现漏扫的 **7 个**脚本：install.sh /
       pre-commit.sh / check-gate-sync.sh / 4×regression-demos/*/check.sh）；
    ② 排除集严格按 REQUIREMENT **AC-4b 契约**逐项写（.git/node_modules/brooks-lint/brooks-tools/
       dist/.omo/.claude/.specs/test），**不得自行增删** —— AC-4c 会检测静默扩张；
    ③ **固定输出** `SCANNED_FILES: <n>` 及其后逐行路径，**严格按 REQUIREMENT AC-4「输出契约」**：
       **`./` 前缀相对路径**、逐行、以**空行结束**、`<n>` 等于路径行数（**不得**做 `--list-files`
       形式 —— 那会被 make 当 target 名；**不得**输出绝对路径或裸相对路径 —— 验收解析器只认 `./`）；
    ④ **保持 error 级门禁语义不变**（ADR-010 / D8）：扩面只让 warning 可见，不升级为 fail；
    ⑤ 新增 `check-dist` target（薄壳：调 `package-dsh-plugin.sh --check`）并挂进 `check:` 依赖，
       使其成为第 6 门。
  </action>
  <verify>
    # 依赖 T01：check-dist 的薄壳调 package-dsh-plugin.sh --check —— T01 未完成时本行会失败
    bash package-dsh-plugin.sh --check >/dev/null 2>&1 || { echo "FAIL: T01 的 --check 接口不可用"; exit 1; }
    set -u; make lint >/tmp/t02.log 2>&1 || { echo "FAIL: make lint 非零退出"; exit 1; }
    grep -qE '^SCANNED_FILES:' /tmp/t02.log || { echo "FAIL: 无 SCANNED_FILES 行"; exit 1; }
    # 契约：<n> 等于其后 ./ 前缀路径行数
    n=$(sed -n 's/^SCANNED_FILES: *//p' /tmp/t02.log | head -1)
    c=$(awk '/^SCANNED_FILES:/{f=1;next} f&&/^\.\//{k++;next} f&&/^$/{exit} END{print k+0}' /tmp/t02.log)
    [ "$n" = "$c" ] || { echo "FAIL: 声明 $n ≠ 实际 $c"; exit 1; }
    # 7 个漏扫脚本须全在清单内
    for f in flow-kit-bundle/install.sh flow-kit-bundle/hooks/pre-commit/pre-commit.sh \
             flow-kit-bundle/flow-kit/reference/check-gate-sync.sh \
             flow-kit-bundle/flow-kit/regression-demos/hallucination-guard/check.sh \
             flow-kit-bundle/flow-kit/regression-demos/scope-drift-guard/check.sh \
             flow-kit-bundle/flow-kit/regression-demos/strong-model-verbosity/check.sh \
             flow-kit-bundle/flow-kit/regression-demos/weak-model-interactive-ui/check.sh; do
      grep -qF "./$f" /tmp/t02.log || { echo "FAIL: 漏扫 $f"; exit 1; }
    done
    # check-dist 已挂进 check: 依赖
    make -n check 2>/dev/null | grep -q 'check-dist' || { echo "FAIL: check-dist 未挂进 check"; exit 1; }
    make check-dist || { echo "FAIL: check-dist 失败"; exit 1; }
    echo "T02 OK"
  </verify>
  <done>
    `make lint` 输出 SCANNED_FILES 行（**严格按 AC-4 输出契约：`./` 前缀相对路径 + 空行结束**）且覆盖 7 个此前漏扫脚本；
    `make check` 依赖含 check-dist → AC-3 / AC-4 / AC-4b / AC-4c 就位
  </done>
  <depends_on>T01</depends_on>
</task>

<task id="T03" parallel="true" status="done" model-tier="standard">
  <name>sync-hooks.sh：exec 判据收窄为真入口 + 检出时逐条指名</name>
  <read_files>
    sync-hooks.sh
    flow-kit-bundle/hooks/stop/lib/common.sh      <!-- HOOK_MODULE_NAMES 单一事实源 -->
    flow-kit-bundle/hooks/pre-tool-use/*
  </read_files>
  <write_files>
    sync-hooks.sh
  </write_files>
  <action>
    实现 DESIGN D4/D5/D6：
    ① exec 判据由「按目录」收窄为「**仅真入口**」：stop 主模块（复用 common.sh 的 HOOK_MODULE_NAMES，
       不另立清单）、session-start/*、pre-commit/*、pre-tool-use 的 **3 个真入口**
       （independent-review-gate / auto-checkpoint / runtime-edit-guard）；
    ② `pre-tool-use/` 下 4 个只被 `source` 的库（gate-helpers / gate-helpers-types /
       gate-checks-basic / gate-checks-review）**移出判据域** → 消除既有 **全部 5 处**误报（实测：5 处 = `.claude/hooks` 1 + `dist/.../vendor/.../hooks` 4，**无一例外全是这 4 个库的镜像副本**；L2 三轮 R7 更正了我先前"5→4"的错误说法）；
    ③ 检出时**逐条指名文件路径**（当前只有聚合计数 `⚠️ N 个 hook 入口缺可执行位`，无文件名 ——
       这是本 change 要补的能力缺口）；
    ④ 退出码**维持 advisory**（不升级为 fail，见 D5 理由：比对根含用户环境目录，升级会误红本仓 CI）；
    ⑤ 真入口白名单处加注释：「**新增 pre-tool-use 入口必须登记此处**」（R4/R6 的缓解）。
    ⑥ **不扩张判据域到源 bundle**（L2 R1 定案）。
  </action>
  <verify>
    set -u
    # ① AC-5 正向：健康态零告警（文件存在性显式断言，避免 grep 失败被当 0）
    make check-hooks-sync >/tmp/t03.log 2>&1; rc=$?; [ "$rc" -eq 0 ] || { echo "FAIL: rc=$rc"; exit 1; }
    [ -f /tmp/t03.log ] || { echo "FAIL: 日志未生成"; exit 1; }
    n=$(grep -c '缺可执行位' /tmp/t03.log || true); n=${n:-0}
    [ "$n" -eq 0 ] || { echo "FAIL: 仍有 $n 处误报"; exit 1; }
    # ② AC-6 反向（承重性 · 必须故障注入）：摘掉镜像副本真入口的 exec 位 → 须指名该文件
    # 覆盖多类真入口（L3 三轮 major4）：pre-tool-use / stop 主模块 / session-start / pre-commit
    for rel in pre-tool-use/independent-review-gate.sh stop/29-independent-review.sh \
               session-start/flow-kit-resume.sh pre-commit/pre-commit.sh; do
      F="dist/dsh-flow-kit/hooks/$rel"
      [ -f "$F" ] || { echo "FAIL: 镜像副本不存在 $F（先跑 T00）"; exit 1; }
      chmod -x "$F"
      make check-hooks-sync >/tmp/t03b.log 2>&1 || true
      chmod +x "$F"
      grep -q "$(basename "$F")" /tmp/t03b.log || { echo "FAIL: $rel 检出但未指名"; exit 1; }
    done
    echo "T03 OK（AC-5 零误报 + AC-6 四类真入口均指名）"
  </verify>
  <done>
    健康仓库上该计数为 **0**（AC-5）；摘掉镜像副本真入口的 exec 位后输出**指名该文件**（AC-6）→ AC-5 / AC-6 就位
  </done>
  <depends_on></depends_on>
</task>


<task id="T04" parallel="true" status="done" model-tier="standard">
  <name>落盘 AC 验证夹具 .specs/<id>/verify/ac*.sh</name>
  <read_files>
    .specs/health-fix-2026-09/REQUIREMENT.md      <!-- AC-1/3/4/4c/5/6 的脚本原文 -->
    Makefile
    package-dsh-plugin.sh
    sync-hooks.sh
  </read_files>
  <write_files>
    .specs/health-fix-2026-09/verify/ac1.sh
    .specs/health-fix-2026-09/verify/ac3.sh
    .specs/health-fix-2026-09/verify/ac4.sh
    .specs/health-fix-2026-09/verify/ac4c.sh
    .specs/health-fix-2026-09/verify/ac5.sh
    .specs/health-fix-2026-09/verify/ac6.sh
  </write_files>
  <action>
    把 REQUIREMENT 里 AC-1 / AC-3 / AC-4 / AC-4c / AC-5 / AC-6 的验证脚本**原样落盘**为可执行夹具
    （AC-8 要求）。硬性约束：
    ① **还原一律按目标是否被 git 跟踪区分**：AC-1/AC-3 目标被跟踪 → `git checkout -- <file>`；
       AC-6 目标在 dist/ 下被忽略 → `chmod +x`（`git checkout` 对忽略文件报错且不还原权限，已实测）；
    ② 每个脚本开头**断言 Given 前置**（AC-1/AC-3 先断基线绿；AC-6 先断基线无 exec 告警 + dist 已对齐 + 副本存在）；
    ③ 所有临时文件写 `/tmp`，`trap ... EXIT` 保证异常路径也还原。
    **禁止**在脚本里复制实现的枚举逻辑（AC-4 的教训：那等于把实现当判据）。
  </action>
  <verify>
    for f in .specs/health-fix-2026-09/verify/ac*.sh; do bash -n "$f" || exit 1; done; echo SYNTAX_OK
  </verify>
  <done>
    6 个夹具落盘且语法通过；TEST 阶段（5-test）逐个执行并留证 → AC-8 就位
  </done>
  <depends_on></depends_on>
</task>
<task id="T05" parallel="true" status="done" model-tier="cheap">
  <name>F6 回归守护：路径解析化 + 门数动态推导（F6 已在阶段 1 落地，本任务守其不回退）</name>
  <read_files>
    verify-claims.sh
    Makefile
    .specs/health-fix-2026-09/REQUIREMENT.md    <!-- AC-7 的期望值来源 -->
    .specs/archive/*l3-review-defects-2026-09/*  <!-- F6(a) 的 archive 回退目标 -->
  </read_files>
  <write_files>
    verify-claims.sh
  </write_files>
  <action>
    实现 REQUIREMENT v1 的 **F6**（本 change 的耦合项，不修则 AC-7 不可达）：
    ① `resolve_spec_artifact()` 已就位（live 优先 → archive 回退，两者皆无则显式失败）—— 复核其覆盖
       `:123` D= / `:137` M= / `:158` §0.5.1 三处；
    ② `:165` 的门数断言已改为从 `Makefile` 的 `check:` 依赖动态推导 —— 复核其正确性：
       T02 把 check-dist 挂进 check 后，输出应自动变为「**6 门**」，且**不得**再出现写死「五门」。
    **⚠️ 前提更正（L2 三轮 R2）**：F6 的两处修复**已在阶段 1 由 L2 R3 触发并落地**（`git status` 可见
    `M verify-claims.sh`，实测当前已 exit 0 / ✅13 ❌0 / 输出"make check 5 门全绿"）。
    故本任务**不是实现任务**，而是**回归守护**：
      · 它真正的价值在 T02 之后才体现 —— T02 把 check-dist 挂进 `check:` 后，门数应由 5 变 **6**，
        本任务断言该自动跟随**生效**（这正是 F6(b) 动态推导的验证点，也是 T07 的粗粒度断言覆盖不到的）；
      · 同时断言三处硬编码路径解析在归档态下**仍不回退**（不再出现 `§0.5.1 未列`）。
  </action>
  <verify>
    set -u
    make -n check 2>/dev/null | grep -q 'check-dist' || { echo "FAIL: T02 的 check-dist 未挂进 check"; exit 1; }
    bash verify-claims.sh >/tmp/t05.log 2>&1 || { echo "FAIL: verify-claims 非零退出"; tail -5 /tmp/t05.log; exit 1; }
    # 计数从实际输出提取（L3 三轮 C2：不硬编码）
    got=$(grep -oE '复验结果: ✅ [0-9]+  ❌ [0-9]+' /tmp/t05.log | tail -1)
    [ "$got" = "复验结果: ✅ 13  ❌ 0" ] || { echo "FAIL: 计数为「$got」≠「✅ 13  ❌ 0」"; exit 1; }
    # 门数须动态跟随（T02 加门后为 6），且不得残留写死的"五门"
    # 加固（L3 三轮 major3）：取 check: 目标后解析其依赖（忽略注释/空行），并容忍续行
    # 从 Makefile 的 check: 目标解析依赖数（含续行/注释/变量引用；遇配方行即停）
    gates=$(awk '/^check:/{inp=1;line=$0; if($0 ~ /\\$/) next; inp=0; next} inp{line=line" "$0; if($0 ~ /\\$/) next; inp=0} END{sub(/^check:[ \t]*/,"",line); gsub(/\\/," ",line); sub(/#.*/,"",line); n=split(line,a,/[ \t]+/); c=0; for(i=1;i<=n;i++) if(a[i]!="" && a[i] !~ /^\$/) c++; print c}' Makefile)
    grep -qE "make check ${gates} 门全绿" /tmp/t05.log || { echo "FAIL: 门数未跟随（期望 ${gates}）"; exit 1; }
    grep -q '五门' /tmp/t05.log && { echo "FAIL: 仍有写死『五门』"; exit 1; }
    echo "T05 OK（门数=${gates} 动态跟随）"
  </verify>
  <done>
    exit 0 且「复验结果: ✅ 13 ❌ 0」；第 10 项显示 `make check 6 门全绿`；无「五门」字样 → AC-7 ⑥ 就位
  </done>
  <depends_on>T02</depends_on>
</task>

<task id="T06" parallel="true" status="done" model-tier="cheap">
  <name>三载体的理由注释（可追溯锚点）</name>
  <read_files>
    Makefile
    sync-hooks.sh
    package-dsh-plugin.sh
  </read_files>
  <write_files>
    Makefile
    sync-hooks.sh
    package-dsh-plugin.sh
  </write_files>
  <action>
    实现 F5 / AC-9：在三个载体的**判据处**各加一条理由注释，解释「判据为何这样定」而非「做了什么」，
    且**必须含本 change 的锚点字符串 `health-fix-2026-09`**（AC-9 用它做可追溯判定）。
    - `Makefile`：lint 为何用 find 全量枚举、为何 error 级语义不变（引 ADR-010）、check-dist 为何存在
    - `sync-hooks.sh`：exec 判据为何只对真入口、为何维持 advisory 不升级 fail
    - `package-dsh-plugin.sh`：`--check` 为何只比内容不比 mode、为何不新建独立脚本（单一事实源）
  </action>
  <verify>
    set -u; c=0
    for f in Makefile sync-hooks.sh package-dsh-plugin.sh; do
      grep -q 'health-fix-2026-09' "$f" || { echo "FAIL: $f 缺 change-id 锚点"; exit 1; }
      # 语义：锚点所在注释须解释『为何这样定』（含理由关键词），不能只是塞个 change-id
      grep -A2 -E 'health-fix-2026-09' "$f" | grep -qiE '因为|所以|理由|why|reason|依据|避免|否则|ADR' \
        || { echo "FAIL: $f 的 change-id 注释未解释判据理由"; exit 1; }
      c=$((c+1))
    done
    [ "$c" -eq 3 ] || { echo "FAIL: 仅 $c/3"; exit 1; }
    echo "T06 OK（三载体锚点 + 理由语义）"
  </verify>
  <done>三载体均含可追溯理由注释（grep 计数为 3）→ AC-9 就位</done>
  <depends_on>T01,T02,T03</depends_on>
</task>

<task id="T07" parallel="true" status="done" model-tier="standard">
  <name>全量回归取证（AC-7）</name>
  <read_files>
    .specs/health-fix-2026-09/verify/*
    Makefile
  </read_files>
  <write_files>
    .specs/health-fix-2026-09/DEV-SUMMARY.md
  </write_files>
  <action>
    执行 REQUIREMENT AC-7 的六项断言并留证（bats 950/0/1 · lint error 0 · validate 漏配 0/源缺失 0 ·
    test 双源一致 · hooks-sync 漂移 0 · verify-claims 13/0），以及 AC-8 的工作区卫生断言。
    把命令、原始输出摘要、结论写入 DEV-SUMMARY.md。
    ⚠️ 若 bats 计数因本 change 合法增删用例而变化，**必须回写 REQUIREMENT AC-7** 并说明，不得静默改基线。
  </action>
  <verify>
    set -u
    make check >/tmp/t07_check.log 2>&1 || { echo "FAIL: make check 非零退出"; tail -20 /tmp/t07_check.log; exit 1; }
    bash verify-claims.sh >/tmp/t07_vc.log 2>&1 || { echo "FAIL: verify-claims 非零退出"; exit 1; }
    got=$(grep -oE '复验结果: ✅ [0-9]+  ❌ [0-9]+' /tmp/t07_vc.log | tail -1)
    [ "$got" = "复验结果: ✅ 13  ❌ 0" ] || { echo "FAIL: 计数「$got」"; exit 1; }
    # ── AC-7 六项（L3 三轮 C4 补：原 verify 只跑 make check，未逐项断言）──
    npx --yes bats@1.13.0 test/ >/tmp/t07_bats.log 2>&1 || true
    [ "$(grep -cE '^ok ' /tmp/t07_bats.log || true)" -eq 950 ] || { echo "FAIL: bats ok≠950"; exit 1; }
    [ "$(grep -cE '^not ok ' /tmp/t07_bats.log || true)" -eq 0 ] || { echo "FAIL: bats not ok≠0"; exit 1; }
    [ "$(grep -c '# skip' /tmp/t07_bats.log || true)" -eq 1 ] || { echo "FAIL: bats skip≠1"; exit 1; }
    make check-validate >/tmp/t07_val.log 2>&1 || { echo "FAIL: validate"; exit 1; }
    grep -qE '漏配 \(ERROR\): 0' /tmp/t07_val.log || { echo "FAIL: 漏配非0"; exit 1; }
    grep -qE '源缺失 \(WARNING\): 0' /tmp/t07_val.log || { echo "FAIL: 源缺失非0"; exit 1; }
    make check-test-sync >/dev/null 2>&1 || { echo "FAIL: 双源不一致"; exit 1; }
    make check-hooks-sync >/tmp/t07_hooks.log 2>&1 || { echo "FAIL: hooks-sync"; exit 1; }
    grep -qE '漂移 0' /tmp/t07_hooks.log || { echo "FAIL: 漂移非0"; exit 1; }
    # AC-2 回归：dist 与源一致
    diff -rq flow-kit-bundle dist/dsh-flow-kit/vendor/flow-kit-bundle >/dev/null || { echo "FAIL: dist 与源不一致（AC-2）"; exit 1; }
    # 取证产物必须真的落盘并含六项结论（L3 三轮 minor4）
    S=.specs/health-fix-2026-09/DEV-SUMMARY.md
    [ -s "$S" ] || { echo "FAIL: DEV-SUMMARY.md 未写入或为空"; exit 1; }
    grep -q 'AC-7' "$S" || { echo "FAIL: DEV-SUMMARY 未记录 AC-7"; exit 1; }
    echo "T07 OK"
  </verify>
  <done>AC-7 六项 + AC-8 全绿并有原始证据入 DEV-SUMMARY.md → AC-7 / AC-8 就位</done>
  <depends_on>T01,T02,T03,T04,T05,T06</depends_on>
</task>
```

> **⚠️ verify 运行时机（L3 三轮 C1 定案 · 强制）**：每条 `verify` 的语义是「**该 task 实现完成后**执行并通过」，
> **不是**「任务开始前的前置检查」。因此 verify 必然依赖本任务刚写入的行为 —— 在任务开始前跑它理应失败，
> 这正是 L-098「双向验证」的 (a) 侧（实现前失败）、(b) 侧（实现后通过）。请勿把 verify 当作"环境预检"。
> 例外：`T00` 为前置任务，其 verify 是幂等的状态确认（重建 + 断言 diff 为 0）。

> **注意**：`read_files` / `write_files` 是 R7.3 强约束。所有 `write_files` 均在 DESIGN `## 0.5.1`
> 「触碰模块 + 新增模块」范围内；**未触碰任何禁动清单文件**（`hooks/**` 运行时逻辑、`prompts/**`、
> `skills/**`、`brooks-lint/**`、`dsh-flow-kit/lib/*.js` 全部未列入 write_files）。

---

## AC ↔ Task 覆盖矩阵

| AC | 覆盖任务 | 说明 |
|---|---|---|
| AC-1 / AC-2 | T00, T01, T02 | check-dist 机制 + Given 前置 |
| AC-3 / AC-4 | T02 | lint find 枚举 + SCANNED_FILES 出口 |
| AC-4b / AC-4c | T02（契约）+ T04（ac4c 夹具） | 排除集契约 + 静默扩张检测 |
| AC-5 / AC-6 | T03（实现）+ T04（夹具） | exec 判据收窄 + 指名 + 承重性 |
| AC-7 | T05, T07 | 回归六项 + F6 复核 |
| AC-8 | T04, T07 | 夹具落盘 + 卫生断言 |
| AC-9 | T06 | 三载体理由注释 |

## 状态字段说明

- `status="pending"` — 未开始
- `status="in_progress"` — 进行中（同时只允许一个非并行任务为此状态）
- **`[P]` 标记**（定义 · L3 三轮 minor5 补）= **parallel**，与 XML 的 `parallel="true"` 同义，表示可与其他 `[P]` 任务同波次执行。二者一一对应：凡 XML 写 `parallel="true"` 即属同一 wave，凡写 `parallel="false"` 即独占 wave。
- `status="done"` — 已完成（verify 通过）
- `status="blocked"` — 阻塞（必须在「阻塞日志」记录）

## model-tier 字段说明（ADR-016）

- `cheap` — 简单/机械改动（T00 / T05 / T06）
- `standard` — 多文件/标准功能（T01 / T02 / T03 / T04 / T07）
- `top` — 架构/复杂逻辑（本 change 无 —— 三处修复均为判据层机械改动）

---

## 阻塞日志

| 任务 | 阻塞原因 | 待人工决策项 | 时间 |
|---|---|---|---|
| （无） | | | |

---

## Fix 任务（来自 REVIEW / INTEGRATION）

> 此区域由 review/integration 阶段自动追加，编号 `T-FIX-XX`。

```xml
<!-- 占位 -->
```
