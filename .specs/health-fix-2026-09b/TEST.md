# TEST — health-fix-2026-09b 测试报告（阶段 5 · 5-test）

> 判据正文形态见 `.specs/health-fix-2026-09b/TASK.md` 各 task 的 `<verify>` 段（**唯一权威副本**）；
> 本文只记录「**实跑过的证据 + 判定**」，不复制判据源码。
> 运行环境：Linux（`/usr/bin/{bash,git,jq,node,npm,npx,shellcheck,iconv,tar,gzip}`）· 仓库根 = `<repo>`（本机绝对路径按 L-129 去形，不落真实账号路径）·
> 变更锚点 `.specs/health-fix-2026-09b/.change-base` = `534e3e842fc900045f39492badc66eabe3ffd4c4`。
> 实跑时间：2026-09-24（阶段 5 第 1–3 轮；第 2/3 轮补强见 §1.7 与各节的「L3 第 N 轮响应」标注）。
> **一键复算**（两条独立入口，均自包含、可重复、不触碰工作树）：
> ① `bash .specs/health-fix-2026-09b/reproduce-5-test.sh` —— 判据从 `TASK.md` 权威副本 **awk 原样抽取**（不做任何修正）后逐条实跑并记 rc，随后跑**七项门禁**（含 [F] 阶段门沙箱复现）；支持 `--criteria-only` / `--gates-only` / `--only T19,T27`；逐条原始输出保存在 `${TMPDIR:-/tmp}/fk-repro-*`（可用 `FK_REPRO_LOG_DIR` 指定），其中 `v_<Tnn>.sh` 与 `TASK.md` 的判据块**逐字节同源**（可直接 `diff`）。
> ② `bash .specs/health-fix-2026-09b/reproduce-phase-gate.sh` —— 沙箱复现**阶段门拦截 `git commit`**（UAT ③ 的可构造等价物；五层状态 A/B/B2/B3/C，见 §1.2 ③）。
> **原始输出存档**：`.specs/health-fix-2026-09b/PHASE5-RECEIPTS.md` —— **§0 是最小复算证据（保证落在 L3 补充产物预算 3000 B 内，见 L-151 与 L3 第 3 轮 major 1）** · §A 12 条判据 rc + 原始 stdout · §B 六项门禁回执（含完整 TAP）· §C 三条零引用判据 · §D 判据修正台账 · §E 性能测量环境 · §F 973→976 归因 · §G 复算入口与失败语义 · §H 阶段门沙箱复现原文（第 [F] 项）· **§I 处置后复算全绿回执（rc=0，含 T19 回写后的 36 行抽取）**。

## 0. 本次测试范围声明（5 轮金字塔）

产品类型裁剪依据：`flow-kit-bundle/flow-kit/reference/test-pyramid.md` 的适用矩阵 —— 本仓是**纯 Bash/Markdown 分发件 + git hook/安装器**（CLI 工具形态，无前端、无服务端、无数据库），故按「CLI 工具 / 内部工具」两行取并集裁剪。

| 轮次 | 状态 | 本次范围 | 跳过/裁剪理由 |
|---|---|---|---|
| 第 1 轮 · 功能 | ✅ 必跑（全跑） | AC-1..AC-8 全覆盖；bats 全量 976 用例；change 期判据 19 条；双态注入 | — |
| 第 2 轮 · 性能 | ⚠️ 部分 | NFR 明文预算的**全部三条**：`check-path-privacy` ≤5s、`check-gate-sync` 秒级、新增 `check-nfr-portability` 耗时 | 无前端（Lighthouse N/A）、无服务端接口与 DB（k6/locust p95/p99、N+1 N/A） |
| 第 3 轮 · 安全 | ⚠️ 部分 | 依赖面（无 lockfile ⇒ audit 不可用，量化替代）、秘钥扫描（模式面 + 自研门禁）、SAST（shellcheck + 构造扫描 + eval 面）、OWASP Top 10 逐项 | 无容器镜像（trivy N/A）；`semgrep`/`gitleaks`/`trufflehog` 本机未安装（工具缺失面已明示，见 §3.5） |
| 第 4 轮 · 兼容 | 静态判据通过 / ⚠️ macOS 实机未验证 | bash 3.2（macOS）/bash 4+ 语法与 GNU-only 构造（**变更集口径**，静态判据 `make check-nfr-portability`）、locale/编码 4 态矩阵、六镜像 hook 同步、test 双源一致 | 4.1 跨浏览器 / 4.2 视口 N/A（无 UI）；4.3 数据迁移 N/A（无 schema）；**实机面**：无 macOS runner（L3 第 3 轮 minor ④ ⇒ 不得据此判 AC-8 的跨 OS 面为「已验证」，见 **`Tech-debt: TD-055`** 与 §4.4 的 ⚠️ 残余行） |
| 第 5 轮 · 可观测 | ⚠️ 部分 | 门禁自证行、失败归因 `file:line`、日志不含凭证值/PII | 5.2 指标与链路追踪 N/A（无长驻进程/无服务端）；5.3 无外部告警通道（明确不在范围） |

> **无声明跳过**：上表每一条 ⚠️/❌ 都给出了范围与理由（R5.4）；本阶段**实际执行**的轮次 = 1（全）、2（预算面全）、3（可用工具面 + 逐项判定）、4（静态面全）、5（日志面全）。

> **阶段门有效性（UAT ③ 面 · L3 第 4/5/6 轮响应）**：**未通过（FAIL）** —— 健康层（无完成标记 ⇒ 拒绝）经沙箱实测成立，但 **B2/B3 是验收失败分支**：完成标记**存在但口径相反 / 残缺**时门禁 **rc=0 放行**（`Tech-debt: TD-059`，本 change 未修复）⇒ 按验收标准，**UAT ③ = FAIL（B2/B3）**，不得把「阶段门拦截」读作通过。

---

## 第 1 轮 · 功能测试

### 1.1 测试矩阵（AC → 用例/判据 → 结果）

| AC | 主证据（本次实跑） | change 期判定 | 长期回归保护 |
|---|---|---|---|
| **AC-1** 安全守卫不再求值载荷（PC1） | 判据 `T05 <verify>` 原样抽取实跑 **rc=0**；静态面 `grep -rnE '\beval\b' --include='*.sh'` 全仓命中 **1** 且为**注释**（`flow-kit-bundle/hooks/pre-tool-use/runtime-edit-guard.sh:50` 的修复说明）⇒ 活体 eval 面 = 0（**仅 change 期判据覆盖，无常设 bats 回归 · TD-053**） | ✅ | ❌ **无常设 bats 回归**（TD-053） |
| **AC-2** 缺 jq 时既有配置不被破坏（PC2） | 判据 `T06 <verify>` 原样抽取实跑 **rc=0**（缺 jq 分支：目标配置字节不变 + fail-closed）；`test_install_coverage.bats`（17 用例）/ `test_install_dry_run.bats` 在 976 全量中通过 | ✅ | ✅ 常设 bats（`test_install_coverage.bats` / `test_install_dry_run.bats`） |
| **AC-3** 泄漏分支无法被误推（P1） | 判据 `T11` / `T17` / `T19` 实跑 **rc=0**（T19 = 隔离 bare remote 的**四形态 push 拦截 + 干净 ref 放行**端到端）；报文含 ref 与原因（`flow-kit-bundle/hooks/pre-push/pre-push.sh:30` 畸形 stdin fail-closed、`:49` 泄漏 ref 拒绝）；`test_archive_commit_gate.bats`（27 用例，本 change +16 行） | ✅ | ✅ 常设 bats（`test_archive_commit_gate.bats` 27 用例） |
| **AC-4** 门禁看得见「内容漂移」 | 判据 `T13`（修复后，见 §阶段 5 发现 #2）实跑 **rc=0**；`make check-gate-sync` rc=0（3/14 对一致 / 17 预设）；`test_check_gate_sync.bats`（5 用例，本 change +7/−6）与 `test_quality_baseline.bats` 的 AC-2/AC-3 断言。**Then 第二分支（漂移 ⇒ 非零 + 指名）的独立双态证据**：`test/test_check_gate_sync.bats:29-31`（健康态基线 ⇒ `[ "$status" -eq 0 ]` 且无 gate-config 漂移报告）、`:36`（向 `SKILL.md` 注入假预设 `fake-preset` ⇒ gate-config 段**报漂移并列出该名**）、`:43`（删除真预设 `design` ⇒ 报漂移）、反向对照 `:49`（注入无 `→` 的英文注释 ⇒ **不误报**）；断言由 `-ne 2` 容忍式收紧为 `-eq 0` 精确式（T15 判据 `TASK.md` T15 `<verify>` 实跑 rc=0） | ✅ | ✅ 常设 bats（`test_check_gate_sync.bats` 5 用例） |
| **AC-5** 内部项目名不随分发件出厂 | 判据 `T24` / `T27` 实跑 **rc=0**（dist 0.2.0 重建 + 归档重扫）；`make check-dist` rc=0（`dist/dsh-flow-kit/vendor/flow-kit-bundle` 与源一致） | ✅ | ✅ 常设门禁 `make check-dist` |
| **AC-6** 前向脱敏有机器门禁 | 判据 `T20` / `T22` / `T23` / `T25` / `T26` 实跑 **rc=0**；`make check-path-privacy` rc=0（**清单外命中 0 条**；自证行四要素齐全）；**探针注入 ⇒ rc=1 并指名 `file:line`**（T26 判据内固化 + 本次 T13 判别力注入复证）（**仅 change 期判据覆盖，无常设 bats 回归 · TD-053**） | ✅ | ❌ **无常设 bats 回归**（TD-053） |
| **AC-7** 四处假绿测试不再假绿 | 四条「**注入失败源 ⇒ 必须变红**」证据（AC-7 原文形态 `REQUIREMENT.md:406-428`）：`test_combined_metric.bats`（注入残留文件 ⇒ 红）/ `test_auto_checkpoint.bats`（让 SUT 失败 ⇒ 红）/ `test_independent_review_model.bats`（删除被断言文件 ⇒ 红）/ `test_lessons_cleanup.bats`（移除过期 skip 并断言 `exit 0`）；四文件差异见 `git diff 534e3e8..HEAD -- test/`，判据 `T15` / `T17` rc=0 | ✅ | ✅ 常设 bats（四个假绿文件各含注入型用例） |
| **AC-8** 无退化 | 判据 `T29 <verify>` 原样抽取实跑 **rc=0**：`make check` 全绿 + `npx bats test/` **976 收集 / 975 有效 · ok=976 / not ok=0 / skip=0**（1 条 TD-033 mock 不计入结论面，见 §1.3 第 5 条）+ 三道副本一致性门禁（test/hooks/dist）0 漂移；**活性探针**：`FLOW_KIT_CHANGE_BASE=HEAD` ⇒ **rc=1** + `🔴 AC-8 时点变更集为空（相对锚点 HEAD）⇒ 兼容性判据 rc=3（未验证），不得当作通过`（非空守卫非恒绿）（**长期回归保护无常设 bats · TD-053**；**macOS 实机未验证 · 仅静态判据 TD-055**） | ✅ | ❌ **无常设 bats 回归**（TD-053）· ⚠️ **macOS 实机未验证**（TD-055） |

**覆盖判定**：**8/8 条 AC 仅有 change 期覆盖，无空缺；其中 3/8（AC-1 / AC-6 / AC-8）无常设回归保护**（`Tech-debt: TD-053`，§回归保护有登记，§1.3 有替代覆盖口径说明）。**静态判据通过 ≠ 跨 OS 兼容性验收通过**（AC-8 的 macOS 面 = `Tech-debt: TD-055`，见 §4.4）。

> **结论口径声明（L3 第 4 轮 major 1 响应）**：本表「✅」一律指 **change 期（本次变更集）覆盖** —— 证据 = `TASK.md` 判据**原样抽取实跑** + 双态注入 + 全量回归，逐项可复算（§附录 A）。其中 **3 件生产件（`runtime-edit-guard.sh` / `check-path-privacy.sh` / `check-nfr-portability.sh`）在 `test/` 树 0 引用**（§可复算覆盖代理表）⇒ 本报告**不宣称**它们具备**长期回归保护**：归档后其判定力只由 change 期判据承载（`Tech-debt: TD-053`，已写入 §回归保护，并交**阶段 7 triage**）。同理 §1.2 的 UAT ③ **判为「未通过（FAIL）」，失败分支即 B2/B3（完成标记口径相反 / 残缺时门禁放行，`Tech-debt: TD-059`）**（见该条结论行与 §0 阶段门有效性声明）。

### 1.2 UAT（验收面端到端）

本 change 无 GUI/服务端 ⇒ UAT 面 = **分发与门禁的真实运行路径**，四条均为端到端实跑：

1. **隔离 bare remote 的 pre-push 拦截**（T19 判据）：四形态泄漏 push 全部被拒、干净 ref 放行 ⇒ rc=0。
2. **pre-commit 门禁显式调用两态**：`bash .git/hooks/pre-commit` 两次探针 ⇒ **rc=1** 并指名 `.zz-probe1.txt:1`、`README.md:151`，报文 `[archive-commit-gate] path-privacy check failed, commit rejected`。
3. **DSH 装载面的阶段门真实拦截**（历史事件 + **可构造等价复现**）：本次阶段 5 提交修复时被 `gate-checks-review.sh` 拒绝 —— `⛔ 独立 review gate：阶段 5 (5-test) 独立 review 未完成，禁止 git commit`（L2+L3 未完成前不放行）⇒ 门禁在**真实使用路径**上生效，而非只在单测里成立。原证据依赖「L2/L3 未完成」这一**不可逆时点**，故按 L3 第 3 轮 major 3 的要求改为可运行脚本：**`.specs/health-fix-2026-09b/reproduce-phase-gate.sh`**（`mktemp -d` 沙箱 + `git init` + 空 seed 提交；以 stdin JSON 驱动 `flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh`；夹具 = `.flow-active` + `.specs/<id>/TEST.md` + `INDEPENDENT-REVIEW-5.md`），原始输出存档 `PHASE5-RECEIPTS.md` §H。同一 change、同一条 `git commit` 命令，只改沙箱状态：
   - **A** 阶段 5 开双审（`gate_config["5-test"]="both"`）且**无**完成标记 ⇒ 实测 **rc=2** + 报文字面命中 + **HEAD 不变**；
   - **B** 同一 change 改为只开 L2 + 合格完成标记（健康态）⇒ 实测 **rc=0** 放行，且放行后 `git commit` **真的生效**（HEAD 前进）；
   - **C** 沙箱无 `.flow-active`（门不适用）⇒ 实测 rc=0（fail-open 对照）；
   - **B2/B3 = 缺口实证（不是健康行为，不得读作通过）**：标记内容与审查档口径**相反**（标记记 pass、审查档记 fail）⇒ rc=**0**；标记**残缺**（删掉 `L3_verdict` 键、5 行低于 6 行下限）⇒ rc=**0** ⇒ **🔴 `Tech-debt: TD-059`**（阶段门在 commit 路径上是「**文件存在性**」判定：`flow-kit-bundle/hooks/stop/lib/done-validation.sh:35` 的 `fk_independent_review_gate_active` 在标记存在时即返回「门未开」，使 Gate4 的 6 键 / Tier-2 校验不可达；唯一实际防线 D7 path-guard 只对**命令文本**做文件名匹配）；
   - **判别子**：门禁外直连 `git commit` 可用 ⇒ 拦截来自门禁判定，而非命令形态或仓库损坏；**旁证**：`🟡 Tech-debt: TD-058`（沿用 Stop 侧惯例的 `HOOK_BASE_DIR=…/hooks` 会让该 hook fail-close 成「拒绝一切 commit」并给出误导性归因 —— 复现脚本因此**不覆盖**该变量）。
   - **本条验收面结论（L3 第 4 轮 major 2 响应）**：既有拦截**只在「无完成标记」时成立**（状态 A，rc=2）；标记**存在但口径相反 / 残缺**时门禁**放行**（B2/B3 = TD-059）⇒ **UAT ③ 判为「未通过（FAIL）」**（**失败分支 = B2/B3 两条放行路径**），B2/B3 是该条的**未通过分支**（不是被覆盖的健康行为）；历史事件（本次阶段 5 真实被拦）同样只由「标记缺失」触发。该缺口的处置 = **显式缺口实证 + `Tech-debt: TD-059`**（本 change 不修，理由见 §阶段 5 发现 #17）。
4. **安装器覆盖完整性**：`bash package-flow-kit.sh --validate` ⇒ **本次实测**（阶段 5 第 1 轮）期望覆盖 **311** 项 / 实际文件 **317** 项 / 漏配 ERROR=**0** / 源缺失 WARNING=**0** / rc=0（计数随 HEAD 文件数变动，判据是「漏配 = 0 且源缺失 = 0」，已由 `test_archive_commit_gate.bats` 的 `validate_staging_coverage` 用例固化）。

**可复制复现序列（L3 第 1 轮 minor「UAT 未附命令与原始输出」的响应 · 命令 + 期望/实际 rc）**：

```bash
# ① T19 端到端 push 拦截（自建隔离 bare remote：四形态泄漏 + 干净 ref）
sed -n '/<task id="T19"[^>]*>/,/<\/task>/p' .specs/health-fix-2026-09b/TASK.md \
  | sed -n '/<verify>/,/<\/verify>/p' | sed '1d;$d' > /tmp/v_T19.sh && bash /tmp/v_T19.sh; echo "rc=$?"
#   期望：四形态 push 全拒（拒绝报文含 ref 名与原因）+ 干净 ref 放行 ⇒ rc=0；实际：rc=0

# ② pre-commit 门禁的显式真实调用（不依赖 git 是否加载 hook —— 本仓 git hook 路径为空，见 L-144）
printf 'x\n' > .zz-probe1.txt && git add -f .zz-probe1.txt && bash .git/hooks/pre-commit; echo "rc=$?"
#   期望：rc≠0 且报文 [archive-commit-gate] path-privacy check failed, commit rejected（指名 file:line）；实际：rc=1，指名 .zz-probe1.txt:1
git rm -q --cached .zz-probe1.txt && rm -f .zz-probe1.txt && bash .git/hooks/pre-commit; echo "rc=$?"
#   期望：干净树放行 rc=0；实际：rc=0（第二形态探针 README.md:151 见 T20 复核记录）

# ③ DSH 装载面的阶段门拦截（可构造等价复现：沙箱内自建 change + 缺完成标记；UAT ③ 的可重放入口）
bash .specs/health-fix-2026-09b/reproduce-phase-gate.sh; echo "rc=$?"
#   期望：A rc=2 + 报文命中 + HEAD 不变 · B rc=0 且 commit 真的生效 · C rc=0（门不适用）
#        B2/B3 为已登记缺口（TD-059）的实测固定 ⇒ rc=0；若将来修复，脚本只提示 ℹ️ 不判失败

# ④ 安装器覆盖完整性
bash package-flow-kit.sh --validate | tail -4; echo "rc=$?"
#   期望：漏配 ERROR=0 且 源缺失 WARNING=0 ⇒ rc=0；实际：期望覆盖 311 / 实际文件 317 / 漏配 0 / 源缺失 0 / rc=0
```

### 1.3 覆盖率（Coverage · 如适用）

**Coverage（行覆盖）**：本仓为 bash + bats，**无行覆盖率工具**（无 `kcov`/`bashcov`），故按「等价强度」的三条替代口径：

1. **AC 覆盖**：8/8 全覆盖（§1.1），且每条 AC 都有**双态**证据（健康 ⇒ 绿 / 注入缺陷 ⇒ 红），不是「跑一次看绿」。
2. **收集面 = 执行面**：`npx bats --count test/` = **976**（**有效用例 975**，见第 5 条），直跑实测 `ok=976 / not ok=0 / skip=0` ⇒ 被收集的用例**全部执行且全部通过，零 skip**（若收集数与实测判据面不符，说明有静默跳过——本仓不接受）。原始 TAP 全文（976 行逐条 `ok`/`not ok` 与显式 skip 计数命令）见 `PHASE5-RECEIPTS.md` §B-2，本文不复制。
3. **关键判定路径的专项用例数**：`test_archive_commit_gate.bats` 27（pre-commit/pre-push 接线）、`test_gate_config_presets.bats` 34、`test_install_coverage.bats` 17、`test_lessons_cleanup.bats` 16、`test_check_gate_sync.bats` 5、`test_combined_metric.bats` 2（+1 见 AC-7 修正）。
4. **976（有效 975）的构成 · 973 → 976 的逐项归因**（L3 第 2 轮 minor ④ 响应）：`git diff --stat 534e3e8..HEAD -- test/` = **8 文件 +84/−28**；逐文件 `@test` 计数**唯一变化** = `test/test_archive_commit_gate.bats` **24 → 27（+3）**，其余 7 个文件计数不变（`test_auto_checkpoint.bats` 13 · `test_check_gate_sync.bats` 5 · `test_combined_metric.bats` 2 · `test_correction_hygiene.bats` 10 · `test_independent_review_model.bats` 12 · `test_l3_review_defects_2026_09.bats` 124 · `test_lessons_cleanup.bats` 16）⇒ **973 + 3 = 976**，无计数口径漂移。历史 SUMMARY 中的「973 ok / **1 skip**」是**变更前基线**（阶段 1 记录）；那 1 个 skip 来自 `test_lessons_cleanup.bats` 的过期 skip，已由 AC-7 移除并改为机器可验证断言（见 §新增测试登记）⇒ 阶段 4 起实测基线统一为 **976 ok / 0 not ok / 0 skip**。复算命令：
   ```bash
   for f in $(git diff --name-only 534e3e8..HEAD -- test/); do
     printf '%s  base=%s  head=%s\n' "$f" "$(git show 534e3e8:"$f" | grep -c '@test')" "$(grep -c '@test' "$f")"
   done
   ```

5. **有效用例口径**（L3 第 3 轮 minor ③ 响应）：976 条中有 **1 条是 TD-033 记录的 mock 用例**（`test/test_gate_config_presets.bats:27-28` 自陈 `Simulates the resolve_gate_config() logic`，从不 source 生产实现）⇒ **有效用例 = 975**；该条**不计入** AC-7「不再假绿」的结论面（§1.6 ② 已把 AC-4 的证据整体迁到 `test/test_check_gate_sync.bats` 的 5 个双态用例），本 change 不修它（TD-033 属 change 前既有债、已由 `REQUIREMENT.md` 范围切分排除）。

**可复算覆盖代理表（L3 第 1 轮 minor「覆盖率无量化数据」的响应 · 已覆盖 / 未覆盖清单）**：

| 变更的生产件 | `test/` 常设断言面（引用文件数） | change 期判据 | 双态注入（红/绿两侧） |
|---|---|---|---|
| `flow-kit-bundle/hooks/pre-commit/pre-commit.sh` | 1 | T19 / T20 | 泄漏探针 ⇒ rc=1；撤销 ⇒ rc=0 |
| `flow-kit-bundle/hooks/pre-push/pre-push.sh` | 3 | T19 / T20 | 四形态 push 全拒 + 干净 ref 放行 |
| `flow-kit-bundle/hooks/pre-tool-use/runtime-edit-guard.sh` | **0 ⚠️** | T05 | 相对路径 ⇒ rc=2；绝对路径 ⇒ rc=0 |
| `flow-kit-bundle/lib/install_hooks.sh` | 4 | T06 / T18 | 缺依赖 ⇒ fail-closed 且不破坏既有配置 |
| `flow-kit-bundle/flow-kit/reference/check-path-privacy.sh` | **0 ⚠️** | T21 / T22 / T23 / T13 | 探针注入 ⇒ rc=1 指名；空清单 ⇒ rc=0；缺清单 ⇒ rc=1 |
| `flow-kit-bundle/flow-kit/reference/check-nfr-portability.sh`（新增） | **0 ⚠️** | T24 / T27 / T28 | 空变更集 ⇒ rc=3；GNU-only 注入 ⇒ rc≠0 |
| `flow-kit-bundle/hooks/stop/lib/l3-prompt.sh` | 6 | T04 | ADR 引用频次采样差异两态 |
| `flow-kit-bundle/flow-kit/reference/check-gate-sync.sh`（新增） | 2 | T13 / T15 | 注入假预设 / 删真预设 ⇒ 报漂移；无 `→` 注释 ⇒ 不误报 |
| `package-flow-kit.sh` | 5 | T10 / T11 | 漏配 ⇒ ERROR；源缺失 ⇒ WARNING |
| `flow-kit-bundle/lib/validate_staging.sh` | 3 | T10 / T11 | 同上（覆盖清单缺项 ⇒ 报） |
| `sync-hooks.sh` | 2 | T05 | 镜像漂移注入 ⇒ 非零；`./sync-hooks.sh` 后 ⇒ 0 |

- **已覆盖（有常设断言面）**：8 / 11 件。
- **未覆盖（`test/` 树内 0 引用，判定力仅由 change 期判据承载）**：3 件 —— `runtime-edit-guard.sh`、`check-path-privacy.sh`、`check-nfr-portability.sh` ⇒ **`Tech-debt: TD-053`**（§回归保护 + §阶段 5 发现 #1）。这是本报告**唯一**被显式标出的覆盖缺口，非隐藏缺口。
- **可复算命令**：`for n in <件名…>; do printf '%s %s\n' "$n" "$(grep -rl "$n" test/ | wc -l)"; done`（上表第 2 列）；双态注入密度 = **13 / 29** 条 task 判据含注入/探针（`awk '/<task id=/{inv=0} /注入|探针|probe/{inv=1} /<\/task>/{if(inv) c++} END{print c}' .specs/health-fix-2026-09b/TASK.md` ⇒ `13`）。
- **量化上限（工具面诚实声明）**：本机**无** `kcov` / `bashcov`，故无行/分支覆盖率数字；上表以「常设断言面 + change 期双态判据」作可复算代理，工具面补齐与 TD-053 同源（v2）。

边界值与错误路径：见 §1.4（7 条，均 ≥3）。

### 1.4 边界 / 错误路径

| # | 场景 | 证据（判据/用例） | 期望 | 实测 |
|---|---|---|---|---|
| 1 | 允许清单**缺失**（常设与 change 副本皆无） | `T21`/`T23` 判据（自建 both-missing fixture） | rc=1 且**指名缺失路径**（fail-closed，不得当空清单放行） | ✅ 与期望一致 |
| 2 | 允许清单**存在但为空** | `T22` 判据 | **rc=0 合法空基线**（也不得静默跳过扫描） | ✅ |
| 3 | 变更集**为空**（锚点 = HEAD） | `T29` 活性探针（本次亲跑） | rc=1 + `rc=3（未验证）` 明示，不得当绿灯 | ✅ |
| 4 | pre-push stdin **畸形**（缺 local sha） | `pre-push.sh:30` + `T11` 判据 | fail-closed 拒绝并给原因 | ✅ |
| 5 | 目标库**缺 jq** | `T06` 判据 | 既有配置**字节不变**（不得截断为 0）、安装 fail-closed | ✅ |
| 6 | **非 git 仓库** 下跑扫描判据 | `T13 <verify>` 的第 2 行守卫 | 明确 `🔴 非 git 仓库…判据不可用` 且 exit 1（不得静默绿） | ✅ |
| 7 | 路径隐私**探针注入**（合成账号名，拼接构造） | `T26` 判据 + 本次 `T13` 注入（非面文件 `sync-hooks.sh:382` / 面内 `T13-SUMMARY.md`） | rc=1 + `file:line` 归因；面内/面外走不同分支 | ✅ 两分支均命中 |
| 8 | locale = `C` 且 `iconv` 未写 `-t` | §4.4 矩阵 | 记录为**已知缺陷形态**（TD-051），产品代码无缺陷 | ⚠️ 已登记（非本次范围） |

### 1.5 测试质量自检（6 维测试衰退风险）

| 维度 | 检查内容（路径 B：内置清单） | 判定 | 依据 |
|---|---|---|---|
| T1 Test Obscurity | 用例名是否描述行为、断言是否可读 | ✅ 无命中 | 本 change 改动的 8 个文件均为具名断言（如 `AC-2: check-gate-sync.sh 运行无脚本错误`） |
| T2 Brittleness | 是否依赖易变细节（行号、计数、时序） | ✅ 无命中 | AC-7 订正**删除了行号引用**（`AC-7` 原文：改按测试名 + 断言内容引用）；T15 把 `-ne 2` 容忍式断言改为 `exit 0` 精确断言 |
| T3 Duplication | 重复用例/重复实现 | ✅ 无命中 | `test/` ↔ `flow-kit-bundle/test/` 的镜像由 `make check-test-sync`（`diff -rq`）强制一致；hook 六镜像由 `check-hooks-sync` 强制一致 —— 属**受门禁约束的有意副本**，非漂移式重复 |
| T4 Mock Abuse | 是否有文件内自建被测逻辑（从不 source 生产实现） | ⚠️ **命中 1** | `test/test_gate_config_presets.bats:27-28` 仍自陈 `Simulates the resolve_gate_config() logic`、硬编码 `"independent"` ⇒ **TD-033（既有登记，本 change 未纳入范围）** |
| T5 Coverage Illusion | 是否存在"绿而无效"的通过面 | ✅ 无命中 | 计数一律直跑 `npx bats`（`make test` 的 stdout 是装饰性截断，L-140）；`skip=0`；本 change 移除了 `test_lessons_cleanup.bats` 的过期 skip |
| T6 Architecture Mismatch | 用例是否在测真实架构（分发出的脚本），而非替身 | ✅ 无命中（除 T4） | 抽查离仓对照：把 `test_check_gate_sync.bats` 单独拷到 `/tmp` 运行 ⇒ **setup 即失败**（`cp … flow-kit-bundle/skills/flow/SKILL.md 没有那个文件或目录`）⇒ 真依赖仓库（与 L-115 的 mock 自证形态相反） |

**命中数 = 1**（T4：TD-033）⇒ 按 `5-test.md` 规则「命中 ≥1 记技术债；≥3 本次 release 前必修」：**只记技术债，不阻塞 release**；TD-033 属 change 前既有债、本次未纳入范围的判定见 `REQUIREMENT.md` 范围切分。

### 1.6 测试质量记事

1. **新门禁没有常设 bats 回归**（本次新增发现 ⇒ TD-053）：`grep -rln 'path-privacy' test/` 与 `grep -rln 'nfr-portability' test/` **均 0 命中**；`runtime-edit-guard` 同样在 `test/` 树内 0 命中。⇒ `check-path-privacy.sh`（392 行）/ `check-nfr-portability.sh` / AC-1 的守卫修复，其**判定力目前只由 change 期判据承载**，归档后无常设回归网。处置：记 **TD-053**（`Tech-debt:`），理由见 §阶段 5 发现 #1。
2. **mock 自证存量**（TD-033）仍在盘：`test_gate_config_presets.bats` 的 mock 硬编码旧语义 `"independent"`，与出货契约 `skills/flow/SKILL.md` 的 `"both"` 不一致 ⇒ 该文件**不能**作为 gate_config 语义的回归证据（本次 §1.1 中 AC-4 的证据**未**采信该文件）。**TD-033 不影响 AC-4 的证据面**（L3 第 2 轮 minor ③ 响应）：AC-4 的证据全部采自 `test/test_check_gate_sync.bats`（5 用例 = `:24` 脚本存在且可执行 · `:29-31` 健康态 rc=0 且无漂移报告 · `:36` 注入假预设 `fake-preset` ⇒ 报漂移并列出该名 · `:43` 删真预设 `design` ⇒ 报漂移 · `:49` 注入无 `→` 的英文注释 ⇒ **不误报**），该文件 `:30/:38/:45/:51` 四处均 `run bash "$SCRIPT"` 直接调用**真脚本**（无 mock 屏蔽），且**漂移/不误报双态齐备**。
3. **测量方法留档**（可复算）：性能单跑用 `TIMEFORMAT='real=%R user=%U sys=%S'`；TAP 计数用 `grep -cE '^ok '` / `^not ok `；bats 收集数用 `npx bats --count test/`。

### 1.7 判据修正台账（字面执行 vs 修正后执行 · 回写权威副本的决定）

L3 第 2 轮 major 3 问：本报告的 `rc=0` 是**字面执行**还是**修正后执行**？修正是否已回写权威副本 `TASK.md`？逐条回答：

| task | 本轮执行方式 | 本轮 rc | 修正是否回写 `TASK.md` |
|---|---|---|---|
| T05 / T06 / T11 / T13 / T20 / T22 / T24 / T26 / T27 / T29 | **字面抽取 + 字面执行**（`reproduce-5-test.sh` 的 `extract_verify()` 用 awk 取出 `<verify>`…`</verify>` 区间，**不做任何改写**，也不套 `set -e`） | 全部 **rc=0**（逐条行数与原始输出见 `PHASE5-RECEIPTS.md` §A） | 无需回写（**本轮未修正任何判据**） |
| T17 | 字面执行 **rc=1** ⇒ 暴露旧断言的策略错误（「集合完备」会把新审查档推向门禁豁免表 = 泄漏静默入库，见 L-150）⇒ **修正直接落在权威副本内** | 订正后 **rc=0**（73 行判据） | **已回写**：`TASK.md` 的 T17 `<verify>` 整块重写为**时间切点**策略（冻结集 1–3 唯一豁免；新增档进表即红）+ `T13` done 注记同批订正（L-150 / TD-054）⇒ 重抽即为修正后版本，两者同源 |
| T19 | 字面执行 **rc=0**（修正前 33 行 / 修正后 36 行）；L3 第 3 轮 major 4 指出 `out=$(cmd 2>&1); rc=$?` 在 `set -e` 下与真红态不可区分 ⇒ **修正直接落在权威副本内**（4 处改为「先置零再捕获」，并把严格模式约定写进块内注释） | 平跑 **rc=0**；strict 对照 `bash -e -u -o pipefail …/v_T19.sh` ⇒ **rc=0 / 37 行输出**（修正前实测：**rc=1 / 19 行前置输出 / 无任何 🔴 断言报文** ⇒ 只能靠报文与真红态区分） | **已回写**：`TASK.md` 的 T19 `<verify>` 四处（`:877` 循环内 / `:881` `--tags` / `:886` `--all` 判别子 / `:889` 摘 hook 归因对照）改为 `rc=0; out=$(cmd 2>&1) || rc=$?`（或 `rc_off=0; cmd || rc_off=$?`），块尾加注释固化约定；`reproduce-5-test.sh` 重抽后实跑 ⇒ **两种运行器同结论**。同族其余 18 处（未复算的判据块）仍留 **`Tech-debt: TD-057`**（不机械改写） |

**结论**：本报告所有 `rc=0` 均为**字面执行**结果；**唯二**被修正的判据是 T17 与 T19，且两处修正**都写在权威副本 `TASK.md` 内**（重抽即得修正后版本 ⇒ 不存在「报告用修正版、仓内是旧版」的分叉）：T17 因旧策略会把新审查档推向门禁豁免表（L-150），T19 因 `set -e` 陷阱使两种运行器结论相反（L3 第 3 轮 major 4）。TD-057 的 T19 实例已闭环（两种运行器均 rc=0），同族其余 18 处仍留债。

---

## 第 2 轮 · 性能测试

### 2.1 预算（REQUIREMENT 非功能性需求原文口径）

| 项 | 预算 | 出处 |
|---|---|---|
| `make check-path-privacy` | 单次运行 **≤ 5 秒**（扫 `git ls-files` 内容，不扫 `.git`）；**验证手段 = `time` 实测并记入 TEST.md**，超阈值即未满足 | `REQUIREMENT.md` §非功能性需求 |
| `make check-gate-sync` | **秒级**（修复后不得引入可感知延迟） | 同上 |
| `make check-nfr-portability` | 无显式明文预算（本次新增门禁）⇒ 按同口径要求「不引入秒级以上延迟」 | 本报告补充口径（不是放宽，是补登记） |

### 2.2 实测

| 项 | 实测（3 次 / 2 次 / 1 次） | 判定 |
|---|---|---|
| `make check-path-privacy` | **real = 2.830 s / 2.868 s / 2.826 s**（user 1.212/1.165/1.175，sys 1.774/1.862/1.799） | ✅ **达标**：均值 2.841 s，为预算的 **57%**，最差单次 2.868 s 仍留 43% 余量 |
| `make check-gate-sync` | **real = 0.053 s / 0.047 s** | ✅ 达标（秒级预算的 1/20 量级） |
| `make check-nfr-portability` | **real = 0.172 s** | ✅ 秒级内 |
| 全量 `make check`（含 976 用例 bats + 9 道门禁） | 见 §2.3 回执（阶段 4/5 多次实测均一次通过，无超时） | ✅ 无退步 |

**测量环境与 5 次补测（L3 第 2 轮 minor ① 响应）**：环境 = 同一台机器 `nproc=32`、运行前 `loadavg` = `6.04 / 6.48 / 6.52`、无并发测试进程、git 索引**热态**（前序 `make check` 已扫过同一工作树，非冷缓存）；计时用 `TIMEFORMAT='real=%R user=%U sys=%S'`。**5 次** `time make check-path-privacy`：real = **2.842 / 2.847 / 2.898 / 2.836 / 2.867 s**（min 2.836 · max 2.898 · 均值 2.858 ⇒ 预算 ≤5 s 的 **57%**），与上表 3 次口径一致（极差 0.062 s，远小于预算余量的 1%）⇒ **判定不变：✅ 达标**。复算命令 = `reproduce-5-test.sh` 门禁段 [D]（内部即 `time make check-path-privacy` ×5，并打印 nproc/loadavg）。

**处置后独立复测（L3 第 3 轮响应 · receipts §I）**：同一命令、同一环境（`nproc=32`、`loadavg` = `5.95 / 6.13 / 6.25`）再测 **5 次**：real = **2.876 / 2.822 / 2.850 / 2.834 / 2.871 s**（min 2.822 · max 2.876 · 均值 **2.851** = 预算 **57%**）⇒ 两次独立实测结论一致（波动 < 0.1 s，均远低于 5 s 预算），**判定不变：✅ 达标**。原始回执见 `PHASE5-RECEIPTS.md` §E（首轮）与 §I（处置后）。

**端到端耗时实测（L3 第 4 轮 minor ① 响应 · 2026-09-24）**：`TIMEFORMAT='real=%R user=%U sys=%S'; time npx bats test/` ⇒ **real = 121.203 s**（user 81.050 / sys 44.707，rc=0）；`time make check` ⇒ **real = 258.890 s**（user 170.315 / sys 93.520，rc=0）＝ bats 主体 121.2 s + 其余 8 道静态/一致性/新门禁合计 ≈ **137.7 s**（`shellcheck` 68 文件为大头）。**与 change 前基线的对比**：本次新增门禁对 `make check` 的增量 = `check-path-privacy` 2.8 s + `check-gate-sync` 0.05 s + `check-nfr-portability` 0.17 s ≈ **3.0 s（占 1.2%）**，未改变「分钟级主体」的量级；`npx bats` 不受新门禁影响（用例数 973 → 976，+3）。原始回执 `PHASE5-RECEIPTS.md` §I。

### 2.3 工具输出（原文）

```
=== 2) 性能（NFR：check-path-privacy ≤5s；check-gate-sync 秒级）===
check-path-privacy run1: real=2.830 user=1.212 sys=1.774
check-path-privacy run2: real=2.868 user=1.165 sys=1.862
check-path-privacy run3: real=2.826 user=1.175 sys=1.799
check-gate-sync run1: real=0.053 user=0.019 sys=0.038
check-gate-sync run2: real=0.047 user=0.020 sys=0.036
check-nfr-portability run1: real=0.172 user=0.088 sys=0.131
```

### 2.4 退步项

**无退步。** 与阶段 4 的实测口径一致（`make check` 全绿、bats 976 收集 / 975 有效 · 0 失败），且新增的三道门禁把 `check` 的端到端耗时增量控制在**秒级**（`check-path-privacy` 2.8 s + `check-gate-sync` 0.05 s + `check-nfr-portability` 0.17 s ≈ 3.0 s，相对 bats 主体的**实测 121.2 s** 可忽略；`make check` 端到端实测 **258.9 s**，见 §2.2）。

### 2.5 全量权威回执（阶段 5 第 1 轮 · T13 判据修复后重跑）

```
npx bats test/     ⇒ rc=0 · ok=976 / not ok=0 / skip=0 · npx bats --count test/ = 976
make check         ⇒ rc=0（全部通过）
  ✅ bats: all tests passed                ✅ shellcheck: no errors found
  ✅ validate: staging coverage OK（源缺失 WARNING: 0）
  ✅ test 双源一致                          ✅ hooks 副本一致（漂移 0 · 6 个安装镜像）
  ✅ check-dist: dist 与源一致              ✅ check-gate-sync（3/14 对一致 · 17 预设名集合一致）
  ✅ 清单外命中 0 条                        ✅ NFR 兼容性判据通过（无新增 bash4-only / GNU-only）
```

> **数字口径注（L3 第 4 轮 major 4 响应）**：以上为**原始回执原样**（`ok=976` 是套件收集数，不为口径改写数字）；其中 **1 条是 TD-033 登记的 mock 用例** ⇒ 本报告的**有效用例口径 = 975**，AC-7 / AC-8 的结论面不得引用该条（详见 §1.3 第 5 条与 §回归保护缺口 2）。

---

## 第 3 轮 · 安全测试

### 3.1 依赖漏洞

| 项 | 实测 | 判定 |
|---|---|---|
| 根目录依赖清单 | **无** `package.json` / `package-lock.json` ⇒ 无 npm 依赖树 | ✅ |
| 子包 1：`flow-kit-bundle/brooks-lint/plugin/package.json` | `dependencies: {}`、`devDependencies: { "@anthropic-ai/sdk": "^0.52.0" }`、`peerDependencies: {}` | ✅ 运行时依赖 = 0 |
| 子包 2：`dsh-flow-kit/package.json` | `dependencies: {}`、`devDependencies: {}`、`peerDependencies: { "@deepseek-ai/cordis": "^4.0.1" }` | ✅ 运行时依赖 = 0 |
| `npm audit --production` | 两包均报 **`ENOLOCK`：This command requires an existing lockfile**（无 lockfile ⇒ 无法审计） | ⚠️ **工具不可用** ⇒ 以「运行时第三方依赖 = 0」作**量化替代**并明示（不假装已审计） |
| `node_modules` | 仓库内不存在 ⇒ 无可执行依赖树残留 | ✅ |

结论：**无运行时第三方依赖**，故「已知漏洞组件」面为 0（不是"未检查"，而是"不存在可被利用的依赖项"）；审计工具缺失面已明示。

### 3.2 秘钥扫描

| 检查 | 实测 | 判定 |
|---|---|---|
| 真凭证模式（`AKIA[0-9A-Z]{16}` / `-----BEGIN … PRIVATE KEY-----` / `ghp_`/`gho_` / `sk-` / `xox[baprs]-` / `*_AUTH_TOKEN=<值>`） | **命中合计 0**（扫描面排除 `.git`/`node_modules`/`dist`/`.specs`） | ✅ |
| 命中的只是**变量名 + 占位值** | `test/test_l3_credential_resolution.bats` 的 `ANTHROPIC_AUTH_TOKEN="p1-tok"`、`FLOW_KIT_L3_AUTH_TOKEN="p3-tok"`；`test/test_l2_dispatch_mode.bats:237` 的 `f3-tok` | ✅ 非真实凭证 |
| 已跟踪的可疑文件名 | `.claude/l3.env.example`（**模板**）· `.specs/adr/023-dual-platform-l3-credential.md`（ADR 文档）· `test*/test_l3_credential_resolution.bats`（测试） | ✅ 均为应有形态 |
| `.gitignore` 覆盖 | `:9-15` = `.env` / `.env.*` / `*.key` / `*.pem` / `credentials*` / `*secret*` / `*_secret*`；`:72-75` 仅反允许 `!.claude/l3.env.example`，并注明真实 `l3.env` 绝不入库（真实凭证在 `~/.config/flow-kit/l3.env`，仓库外） | ✅ |
| 机器门禁 | `make check-path-privacy` rc=0（清单外命中 0）；探针注入 ⇒ rc=1 指名 `file:line` | ✅ |

### 3.3 SAST

| 工具/判据 | 实测 | 判定 |
|---|---|---|
| `make lint`（shellcheck，**error 级**） | `✅ shellcheck: no errors found`（扫描 68 文件） | ✅ |
| 构造扫描（bash4-only / GNU-only，`make check-nfr-portability`） | 在**变更集**（10 个 `.sh`）上 rc=0；空集守卫实测 rc=1 + `rc=3（未验证）` | ✅ |
| `eval` 面（注入类风险，AC-1） | 全仓 `*.sh` 命中 1 = **注释**（`runtime-edit-guard.sh:50`）；守卫改为纯参数展开 `${var/#\~/$HOME}` | ✅ |
| 未安装工具 | `semgrep` / `gitleaks` / `trufflehog` / `trivy` 均 MISSING ⇒ 以 shellcheck + 模式面 grep + 自研门禁替代 | ⚠️ 已明示（见 §3.5） |

### 3.4 OWASP Top 10（A01–A10）

> **读法（L3 第 3 轮 minor ② + 第 5 轮 minor ② 响应）**：下表**判定列一律指「替代面」**（模式面 grep + shellcheck + 自研门禁）；**工具面证据：无**（`semgrep` / `gitleaks` / `trufflehog` / `trivy` 本机未安装，`npm audit` 因 `ENOLOCK` 不可用）⇒ 表内 ✅ **不得**读作工具级通过，见下方「结论强度限定」与 **`Tech-debt: TD-056`**。**判定收紧规则**（第 5/6 轮）：因 `semgrep` / `CodeQL` / `gitleaks` / `trufflehog` / `trivy` **全部缺失**、`npm audit` 因 `ENOLOCK` 不可用 ⇒ **A01–A10 无任何条目具备独立安全工具面证据，本节不保留 ✅**（A08 虽由门禁 rc 直接证明，仍按「无独立安全工具面」标 ⚠️ 替代面）；工具缺失清单与可复算命令见 §3.5。

| 项 | 替代面判定 | 证据等级 | 证据 |
|---|---|---|---|
| A01 Broken Access Control | ⚠️ 替代面 | 双态注入实证 | 三道门禁 fail-closed：pre-commit（`make check-path-privacy` 未过即拒）、pre-push（ref 级拦截）、阶段门（`.done` 缺失时 `is_git_commit` 直接拒绝 —— 本次阶段 5 真实被拦）。**限定 ①**：阶段门分支仅在「完成标记缺失」时生效（`Tech-debt: TD-059`，见 §1.2 ③），标记存在但无效时放行；**限定 ②**：无 `semgrep`/`CodeQL` 级工具证据（`Tech-debt: TD-056`） |
| A02 Cryptographic Failures | ⚠️ 替代面 | 模式面扫描（工具级未验证） | 仓库内无秘钥（§3.2，模式面 grep 命中 0）；凭证只经环境变量/仓库外文件注入，不入库、不落日志值。**无** `gitleaks` / `trufflehog` 级工具证据（`Tech-debt: TD-056`） |
| A03 Injection | ⚠️ 替代面 | 双态注入实证 | AC-1：守卫内 `eval` 已消除（唯一命中是注释）；命令替换载荷探针实测不再执行；钩子对畸形 stdin fail-closed。**限定**：模式面 grep + 双态注入，无 `semgrep`/`Bandit` 级工具证据（`Tech-debt: TD-056`） |
| A04 Insecure Design | ⚠️ 替代面 | 双态注入实证 | 空允许清单 = 合法 rc=0、**但扫描不跳过**；变更集为空 ⇒ **rc=3「未验证」而非绿**（不制造假绿）；缺允许清单 ⇒ rc=1 指名路径。**限定**：证据来自自研判据的 rc，非独立设计审计 |
| A05 Security Misconfiguration | ⚠️ 明示缺口 | 已登记既有项 | 本仓 `core.hooksPath` 为空串 ⇒ git 不调用任何 hook（**TD-050**，已登记、本 change 范围外）；门禁仍可显式调用并生效 |
| A06 Vulnerable Components | ⚠️ 替代面 | 清单可验（审计不可用） | §3.1：两子包运行时依赖 = 0、仓库无 `node_modules`；但**无 lockfile** ⇒ `npm audit` 报 `ENOLOCK`，**未参与**判定 |
| A07 Identification & Auth Failures | ⚠️ 替代面 | 代码可验（模式面） | L3 凭证解析 env-first + 回退，日志只打印 `credential source: env` 或 `credential source: flow-kit`（不含值）；`l3-api.sh:93` 为唯一凭证相关输出。**限定**：代码可验（非扫描面），无工具级凭证卫生证据 |
| A08 Software & Data Integrity | ⚠️ 替代面 | 门禁 rc 实证（**无独立安全工具面**） | `check-dist`（分发件新鲜度）、`check-test-sync`/`check-hooks-sync`（副本一致性）、`.change-base` 变更集锚点、双层 allowlist 读序 —— 本次全部 rc=0 |
| A09 Logging & Monitoring Failures | ⚠️ 明示缺口 | 范围外明示 | 基础日志面 ✅（§5.1）；无外部告警通道（范围外明示） |
| A10 SSRF | ➖ 不适用 | — | 无服务端入站请求面；唯一外呼是 L3 评审 API，目标 base URL 来自显式配置（env/`l3.env`），非用户输入拼接 |

**无 🔴 项**；**判定收紧后：✅ 0 条 / ⚠️ 9 条（A01–A09）/ ➖ 1 条（A10）**，⚠️ 的成因分三类：**工具面缺失**（A01–A04 · A06 · A07 · A08，`Tech-debt: TD-056`）、**已登记明示范围外**（A05 = TD-050、A09 = 无告警通道）、**口径限定**（A01 另受 TD-059 限制；A08 仅门禁 rc 实证）。

> **结论强度限定（L3 第 2 轮 major 4 响应）**：本节 A01–A10 的 ✅/⚠️ **只代表「模式扫描（grep 面）+ shellcheck + 自研门禁（预提交 / 预推送 / 阶段门 / 脱敏 / NFR）」这一替代面的判定强度**，**不**代表 `semgrep` / CodeQL / `gitleaks` / `trufflehog` / `trivy` 级工具面的结论；`npm audit` 因无 lockfile 不可用（`ENOLOCK`）亦**未参与**任何判定。凡无「工具面 + 双态注入」双重证据支撑的条目，一律标 ⚠️ 而非 ✅（不把替代面结论写成工具面结论）。工具缺失面已由**说明性记事升级为基础设施债**：**`Tech-debt: TD-056`**（v2 = 安装 `gitleaks` + `semgrep` 并接线 `make security-scan`；引入依赖时同步引入 lockfile）。可复算命令随 §3.1–§3.3 落档（工具面 `command -v` 实测、凭证文件名面 `git ls-files | grep -iE`、`make lint`、`make check-path-privacy` 自证行、AC-6 探针注入 ⇒ rc=1）。

### 3.5 安全面残余（记事）

1. 本机缺 `semgrep`/`gitleaks`/`trufflehog`/`trivy` ⇒ 秘钥与 SAST 以「模式面 grep + shellcheck + 自研门禁」承担；**工具升级后可复算**（扫描命令已落档于本报告 §3.2/§3.3）。
2. `npm audit` 因缺 lockfile 不可用 ⇒ 已用「运行时依赖 = 0」量化替代；若后续引入依赖，应同时引入 lockfile 并接线审计。
3. TD-050（hooks 部署不尊重 `core.hooksPath`）仍是安装面残余，**本 change 内不改**（已登记，理由见 `CONTEXT.md`）。

**未安装工具清单与可复算命令（L3 第 5 轮 minor ② 响应）**：

```bash
# ① 工具面实况（期望：五项均 MISSING）
for t in semgrep gitleaks trufflehog trivy codeql; do printf '%-10s %s\n' "$t" "$(command -v "$t" || echo MISSING)"; done
# ② lockfile 实况（期望：无 package.json ⇒ npm audit 不适用）
ls package.json package-lock.json 2>&1; npm audit --production 2>&1 | tail -2   # 期望：ENOLOCK
# ③ 替代面（本次实际使用的全部扫描面）
make lint                                    # shellcheck（error 级）
grep -rnE '\beval\b' --include='*.sh' .      # 注入面（期望：唯一命中为 runtime-edit-guard.sh:50 注释）
git ls-files | grep -iE '\.env|secret|credential|\.pem|\.key|id_rsa'
make check-path-privacy                      # 脱敏门禁 + 自证四行
```

---

## 第 4 轮 · 兼容性测试

### 4.1 跨浏览器 —— ❌ 不适用
本仓无任何浏览器端产物（纯 Bash/Markdown 分发件 + git hook）。**理由**：零 web 运行时、零前端资源。

### 4.2 视口 —— ❌ 不适用
同上（无 UI/无 CSS）。

### 4.3 数据迁移 —— ❌ 不适用（无 schema）
替代覆盖（同类「旧数据 ↔ 新代码」风险）：**允许清单读序**的兼容与 fail-closed 三态 —— 常设路径 > change 副本 > 两者皆缺（⇒ exit 1 并指名缺失路径）；空清单 ⇒ rc=0 合法空基线（`T22`）；两者皆缺 ⇒ rc=1（`T21`/`T23`）。**实测 rc 与期望一致**。

### 4.4 跨版本 / 跨编码

| 项 | 实测 | 判定 |
|---|---|---|
| bash 3.2（macOS）与 bash 4+ 语法 / 不得新增 GNU-only、`declare -A` 依赖 | `make check-nfr-portability` 在**变更集口径**（含新增行与未跟踪文件）rc=0；豁免 `stat -c … || stat -f …` 慣用法按成分删除（不是整行豁免） | ✅ **静态面通过** / ⚠️ **macOS 实机未验证（TD-055）** |
| macOS **实机**运行 | 本机为 Linux，**未在 macOS 实跑** ⇒ 结论以静态判据为限 | ⚠️ 残余（非阻断；与 AC-8 的判据口径一致） |

> **AC-8 结果列口径（L3 第 5 轮 minor ③ 响应）**：§1.1 测试矩阵的 **AC-8 结果列已标为「✅ change 期 / ⚠️ 长期回归 + macOS 实机」**，本节的 ✅ 一律是**静态判据通过**（`make check-nfr-portability` 在变更集口径 rc=0），**不含** macOS 实机（`Tech-debt: TD-055`）与长期回归保护（`Tech-debt: TD-053`）两层含义。
| 编码/locale 矩阵 | `LC_ALL=C` + `-t utf-8` ⇒ rc=0 · `LC_ALL=C` **无 `-t`** ⇒ rc=1（`iconv: illegal input sequence at position 0`，= **TD-051** 已登记） · `LC_ALL=C.UTF-8` ⇒ rc=0 · ambient（`LANG=zh_CN.UTF-8`）⇒ rc=0 | ✅（缺陷形态已登记） |
| 判据自身的地域作用域 | T27 判据在调用 `npx bats` **之前**显式 `unset LC_ALL`（`[ -n "${LANG:-}" ] \|\| export LANG=C.UTF-8`），T29 判据整体**不导出** `LC_ALL=C`（改用前缀式 `LC_ALL=C cmd …`）—— 复核实测：全 `TASK.md` 内 10 处 `export LC_ALL=C` 全部位于**不调用 bats** 的判据中（T13/T26 等只跑 grep/`make check-path-privacy`） | ✅ |
| 副本/镜像一致性（跨载体「版本」一致性） | `make check-test-sync`（`test/` ↔ `flow-kit-bundle/test/`）rc=0 · `make check-hooks-sync`（六安装镜像 0 漂移）rc=0 · `make check-dist`（dist 与源一致）rc=0 | ✅ |

---

## 第 5 轮 · 可观测性验证

### 5.1 日志

| 要求 | 实测 | 判定 |
|---|---|---|
| 关键路径入口/出口/异常均有输出 | `make check-path-privacy` 自证行四要素：`扫描面: 工作树` / `允许清单来源: …/path-privacy-allowlist.txt` / `命中合计 N 条` / `清单外命中 N 条`；`make {check-gate-sync,check-nfr-portability}` 各有 `🔍 …` 入口行与 ✅/🔴 出口行 | ✅ |
| 失败必须可归因到 `file:line` | T28 修复后：`check-nfr-portability` 违规行逐文件 `file:line`（不再打印拼接流偏移量）；本次注入实测得到 `sync-hooks.sh:382` 精确归因；`check-path-privacy` 命中行同样 `file:line` | ✅ |
| **不含 PII / 秘钥 / token** | `flow-kit-bundle/hooks/stop/lib/l3-api.sh:93` 只打印 `[l3-review] credential source: env|flow-kit`；`common.sh:293` 注释明写「stderr 提示只含 env 变量名（不含值）」；`grep -nE 'echo|printf' l3-api.sh \| grep -E 'TOKEN\|API_KEY\|AUTH'` 命中项全部是**变量名提示文案**，无值插值 | ✅ |
| 错误日志含足够上下文 | `[archive-commit-gate] test failed, commit rejected` · `🔴 拒绝推送 $local_ref：该 ref 含路径隐私泄漏（make check-path-privacy 未通过）` · `🔴 脱敏越界（非本 change 工件/台账 ⇒ 停止并升级为新 task）：<files>` · `🔴 AC-8 时点变更集为空（相对锚点 HEAD）⇒ 兼容性判据 rc=3（未验证）` | ✅ |

### 5.2 指标 / 链路追踪 —— ❌ 不适用
无长驻进程、无服务端、无请求链路。替代：`make check` 的 9 道门禁 rc 作为一次性健康信号。

### 5.3 告警 / 健康检查 —— ⚠️ 部分
- ✅ 门禁 rc **fail-closed**（异常即非零，可被 CI/人工直接消费）；`check-path-privacy` 的 fail-closed 读序连"文件缺失"都不放行。
- ⚠️ 无外部告警通道（无 Slack/邮件/webhook 集成）——**明确不在本次范围**（REQUIREMENT 未要求）。

**结论**：基础日志与归因面 ✅ 达标；指标/追踪/告警按「无服务端」裁剪并逐项给出理由。

---

## 新增测试登记

本 change **未新增** bats 文件；对既有套件做了 8 处修改（`git diff --numstat 534e3e8..HEAD -- test/`）：

| 文件 | 变更 | 目的（AC） |
|---|---|---|
| `test/test_archive_commit_gate.bats` | +16 / −0 | pre-push glob 与 `validate_staging_coverage` 的接线固化（AC-3 / TD-048） |
| `test/test_auto_checkpoint.bats` | +22 / −9 | AC-7：断言对象改为 SUT（非 jq），并加「让 SUT 失败 ⇒ 必红」证据 |
| `test/test_check_gate_sync.bats` | +7 / −6 | AC-4 / T15：删除 `-ne 2` 容忍式断言，改为 `exit 0` 精确断言 |
| `test/test_combined_metric.bats` | +14 / −4 | AC-7：消除"除 1 外一切结果"恒真断言，改为注入残留文件必红 |
| `test/test_correction_hygiene.bats` | +5 / −5 | T11 相关口径与路径处理一致性 |
| `test/test_independent_review_model.bats` | +6 / −0 | AC-7：先断言文件存在，再断言内容（删文件 ⇒ 必红） |
| `test/test_l3_review_defects_2026_09.bats` | +1 / −1 | 与 L3 缺陷面口径对齐 |
| `test/test_lessons_cleanup.bats` | +13 / −3 | AC-7：移除过期 skip，断言 `exit 0`（唯一可机器验证分支） |

**新增判定力的另两种承载形式**（不属于 bats，但同属回归面）：
1. **change 期判据**：19 条（`T02/05/06/11/13/17/18/19/20/21/22/23/24/25/26/27/28/29`），原文在 `TASK.md` 各 `<verify>`，归档后仍在仓内可复算（本次全部复跑 rc=0）。
2. **常设门禁**：`make check-gate-sync` / `check-path-privacy` / `check-nfr-portability`（本次接线进 `make check`，见 §回归保护）。

---

## 回归保护

**常设（每次 `make check` / pre-push 都跑）**：`test`（976 收集 / **975 有效**）· `lint`（shellcheck error 级）· `check-validate`（317 文件 / 漏配 0 / 源缺失 0）· `check-test-sync` · `check-hooks-sync`（六镜像）· `check-dist` · `check-gate-sync` · `check-path-privacy` · `check-nfr-portability`。

**change 期（归档后按需复算）**：19 条判据 + 本文 §1.4 的 8 条边界/错误路径。

**已识别的回归保护缺口（记债，不假装覆盖）**：
1. **TD-053**：`check-path-privacy.sh` / `check-nfr-portability.sh` / `runtime-edit-guard.sh` 无常设 bats 用例 ⇒ 判定力目前仅由 change 期判据承载（理由与处置见下节 #1）。
2. **TD-033**：`test_gate_config_presets.bats` 的 mock 自证（旧语义 `"independent"`）⇒ 该文件不得作为 gate_config 语义的回归证据。
3. **TD-050**：本仓 `core.hooksPath` 为空 ⇒ git 不调用 hook（门禁需显式调用或经 DSH 装载面生效）。

**回滚点**：`.change-base` = `534e3e842fc900045f39492badc66eabe3ffd4c4`；AC-8 的判据以「变更集」为口径 ⇒ 本 change 的基线不污染后续 change。

> **长期回归保护的判定（L3 第 4 轮 major 1/2 响应 · 显式声明）**：本 change 的**长期回归保护判为「未达标」** —— ① 3 件生产件（`check-path-privacy.sh` / `check-nfr-portability.sh` / `runtime-edit-guard.sh`）在 `test/` 树 0 引用，归档后其判定力只由 change 期判据承载（`Tech-debt: TD-053`）；② 阶段门的「拒绝」在 commit 路径上只在**完成标记缺失**时成立（`Tech-debt: TD-059`）。两条**均交阶段 7（integration）triage**，归档前不得当作「已有常设回归网」处理；本 change 内的补偿 = 判据可一键复算（§附录 A）+ 缺口被封进复现脚本（`reproduce-phase-gate.sh` 的 B2/B3 以 `⚠️ 缺口实证` 固定，行为变化会显式提示）。

---

## 阶段 5 发现与处置（修代码优先协议）

| # | 严重度 | 发现 | 处置 |
|---|---|---|---|
| 1 | 🟡 | **新门禁与 AC-1 守卫无常设 bats 回归**：`grep -rln 'path-privacy' test/` = 0、`grep -rln 'nfr-portability' test/` = 0、`runtime-edit-guard` 在 `test/` 树 0 命中 ⇒ 其判定力只由 change 期判据承载 | **`Tech-debt: TD-053`**。不就地补测试的理由：`test/**` 属**源面**且 `dist/dsh-flow-kit/vendor/flow-kit-bundle/test/**` 整棵入分发件（`package-dsh-plugin.sh`「零丢失整棵 bundle」）⇒ 新增用例会迫使重跑 `make test-sync` + 重建 dist/tarball，并令 AC-8 已落档的 976 基线口径整体失效（违反本 change「T24 之后不再改动源面」的次序硬约束，同 TD-051 的处置口径）。缓解事实：两道新门禁已**接线进 `make check`**（"坏成红"会立刻暴露），且 T21/T22/T23/T25/T26 判据已用双态注入验证过判定力 |
| 2 | 🟡 | **T13 判据「自造红」**：产品门禁本体头部注释（T22 追加）含拼接探针字面，产品按 `SELF_EXCLUDE` 整文件排除自己，而 T13 判据刻意不排除任何文件 ⇒ 复跑 rc=1 报「脱敏越界」 | **`Fixed in: .specs/health-fix-2026-09b/TASK.md`**（T13 `<verify>`：按**逐条精确字面**豁免该合成探针账号名，**不**抄产品整文件 `SELF_EXCLUDE`）+ 双分支注入复证判别力仍在 + `L-147` / `TD-052` 登记 + `MINOR-DEFERRED.md` 复核记录 |
| 3 | ℹ️ | 本机缺 `semgrep`/`gitleaks`/`trufflehog`/`trivy`；两子包无 lockfile ⇒ `npm audit` 不可用 | **明示 + 量化替代**（§3.1/§3.5）：运行时依赖 = 0；扫描命令落档可复算。不记为缺陷 |
| 4 | ℹ️ | TD-033（mock 自证）、TD-050（hooks 不尊重 `core.hooksPath`）在本次测试面复现 | **`Not-applicable`（本 change 范围外，已登记）**；§1.1 的证据链已避开这两个不可信面 |
| 5 | 🟡 | **L2 审查档自带脱敏越界（本阶段自造红）**：`INDEPENDENT-REVIEW-5.md:9` 把仓库根写成真实账号路径、`:18` 的合成探针写成整形态 ⇒ 一旦 `git add`（进入 `git ls-files` 扫描面）即令 `make check-path-privacy` 报**清单外命中 1 条**（实测 rc=2，归因 `.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-5.md:18`） | **`Fixed in: .specs/health-fix-2026-09b/INDEPENDENT-REVIEW-5.md`**（`:9` → `<repo>`；`:18` → 按 **L-137** 拼接形态「`/home/` + `zz-path-probe` + `/`」，判定与四要素未改动）；复验：T13 判据 rc=0（`✅ 脱敏完成：授权面外命中 = 0`）+ `make check-path-privacy` 清单外命中 **0** rc=0。根因（派发面缺脱敏条款）登记 **`TD-054`** + **`L-149`** |
| 6 | ℹ️ | **无 CI / 无 macOS runner**：跨 OS 兼容性只有静态判据（`make check-nfr-portability`），macOS 实机行为（locale / `iconv` / 内建命令差异）未被机器验证 | **`Tech-debt: TD-055`**（基础设施面，v2）；本 change 以 §4.4 的 ⚠️ 残余行显式承认，不伪装成已验证 |
| 7 | 🟡 | **L3 第 2 轮 major 1/2：回执数字与 change 期判据不可从工件内部复算**（「976 / `make check` 全绿」只有汇总数字；三条 0 引用的生产件只给 task id，判据是否恒绿/漂移无从确认） | **`Fixed in: .specs/health-fix-2026-09b/reproduce-5-test.sh`**（新增·可执行：awk **原样抽取** TASK.md 判据后逐条实跑记 rc，含 `--criteria-only` / `--gates-only` / `--only`）+ **`Fixed in: .specs/health-fix-2026-09b/PHASE5-RECEIPTS.md`**（原始输出存档：12 条判据 rc + stdout + 门禁回执 + 抽取命令；第 3 轮补 §0/§H/§I）。判别力实证：T17 于本轮**确实转过红**（新审查档触发旧断言）⇒ 非恒绿；注入 `SELF_EXCLUDE` ⇒ rc=1 指名该档，还原 ⇒ rc=0；第 3 轮新增工件里的 `sed -i` 又被 T29 与 `check-nfr-portability` 当场判红指名（§I）⇒ 判据对**新代码**同样有效。TD-053（常设 bats 缺失）仍按 `Tech-debt` 保留 |
| 8 | 🟡 | **L3 第 2 轮 major 3：`rc=0` 是字面执行还是修正后执行？修正是否回写权威副本？** | **`Fixed in: .specs/health-fix-2026-09b/TEST.md` §1.7**（判据修正台账）+ **T17 的修正已回写 `TASK.md`**（时间切点策略，重建后 rc=0 73 行）；T19 的 `set -e` 陷阱用 strict 对照实验量化（rc=1 / 19 行 / 无 🔴 报文）⇒ 不回写、升 **`Tech-debt: TD-057`** |
| 9 | 🟡 | **L3 第 2 轮 major 4：安全轮次结论循环论证**（工具缺失面下仍给 OWASP ✅/⚠️） | **`Fixed in: .specs/health-fix-2026-09b/TEST.md` §3.4**（加「结论强度限定」：✅/⚠️ 仅代表**替代面**，工具面结论一律不下）+ **`Tech-debt: TD-056`**（工具缺失面由记事升为基础设施债，与 TD-053 同优先级） |
| 10 | ℹ️ | **L3 第 2 轮 minor ①–⑤**（性能测量条件与 5 次统计 / UAT ③ 依赖不可逆历史态 / TD-033 与 AC-4 证据面 / 973→976 逐项归因 / L 编号无出处） | **`Fixed in: TEST.md`**：§2.2（环境 + 5 次统计）· §1.2 ③（标注历史记录 + 可构造等价复现）· §1.6 ②（TD-033 不影响 AC-4 的 5 用例双态）· §1.3 ④（973 → 976 逐项归因 + 复算命令）· 文末「L 条目索引」 |

| 11 | 🟡 | **L3 第 3 轮 major 1：核心数字仍不可从工件内复算**（审查信封只把补充产物**前 3000 B** 送进提示词 ⇒ 写在 `PHASE5-RECEIPTS.md` 第 100 行之后的原始 stdout 对审查者不可见，被判「回执是截断件」） | **`Fixed in: .specs/health-fix-2026-09b/PHASE5-RECEIPTS.md`**（新增 **§0「最小复算证据（索引与结论）」**：结论 + 两条一键复算命令 + 逐面结果表，落在 3000 B 预算内；§A/§B 原始存档保留在后）+ **`Fixed in: TEST.md`**（头部两条复算入口 + 本节）+ **`L-151`** 登记（给外部审查者的证据必须「倒置金字塔」） |
| 12 | 🟡 | **L3 第 3 轮 major 2：三个生产件（`check-path-privacy.sh` / `check-nfr-portability.sh` / `runtime-edit-guard.sh`）在 `test/` 树 0 引用 ⇒ 常设回归网缺失** | **`Tech-debt: TD-053`**（与 #1 同源，L3 给出「补 bats」或「明确把长期回归保护判为未达标」两条路）⇒ 本 change 走第二条：**显式声明「长期回归保护未达标」**，并把这句连同 TD-053 一并交 **阶段 7（integration）triage**，不得在归档后遗忘。§C 已给出三条 0 引用的可复算证据与不补测试的次序理由 |
| 13 | 🟡 | **L3 第 3 轮 major 3：UAT ③（DSH 阶段门真实拦截）依赖不可逆历史事件，等价复现「无脚本、无命令」** | **`Fixed in: .specs/health-fix-2026-09b/reproduce-phase-gate.sh`**（新增·可执行：沙箱 `mktemp -d` + `git init` + 夹具，用 stdin JSON 真实调用 PreToolUse 门禁；五层状态 A/B/B2/B3/C + 判别子）+ **`Fixed in: .specs/health-fix-2026-09b/reproduce-5-test.sh`**（新增 **[F] 阶段门沙箱复现** 步）+ **`Fixed in: PHASE5-RECEIPTS.md §H`**（原始输出存档）+ **`Fixed in: TEST.md §1.2 ③`**（改为「运行脚本即可复现」）。副产品：本轮实测反推出 **TD-058 / TD-059** 两个新缺陷（见 #16/#17） |
| 14 | 🟡 | **L3 第 3 轮 major 4：T19 判据 `set -e` 陷阱**（`out=$(cmd 2>&1); rc=$?` 在 `set -e` 下命令失败即退出 ⇒ 真红态与早退态同码 rc=1，只能靠有无 `🔴` 报文区分） | **`Fixed in: .specs/health-fix-2026-09b/TASK.md`**（T19 `<verify>` **4 处**改为「先置零再捕获」`rc=0; out=$(…) || rc=$?`，块尾加严格模式约定注释）⇒ 修正后 strict 运行 rc=0 / 37 行（修正前 rc=1 / 19 行 / 无 `🔴` 报文）；§1.7 台账 T19 行由「不回写」改为「**已回写**」 |
| 15 | 🟡 | **L3 第 3 轮 minor ①：`npx bats` 原始 TAP 未附 + `T27-SUMMARY.md` 陈旧「973 ok」口径交错** | **`Fixed in: PHASE5-RECEIPTS.md §B-2`**（TAP 逐项计数命令与结果 `^ok` 976 / `^not ok` 0 / 显式 skip 0）+ **`Fixed in: TEST.md §1.3`**（第 2 条指向 §B-2、第 5 条给出 973→976 逐项归因）+ 交叉引用 `.specs/health-fix-2026-09b/T27-SUMMARY.md:22/:25/:76` 与 `T26-SUMMARY.md:152/:154` **既有的口径注记**（973 = 变更前基线 / 各任务执行期的实测值，非篡改，无需改写文档） |
| 16 | 🔴 | **L3 第 3 轮实测副产品 · TD-058：`HOOK_BASE_DIR` 语义在两家族间不一致** ⇒ PreToolUse 侧解析到不存在的 `…/stop/lib/common.sh` 时 **fail-close 拒绝一切 commit**，且外观与「门禁严格」不可区分 | **`Tech-debt: TD-058`**（本 change 不修：`flow-kit-bundle/hooks/**` 语义变更需 ADR，且 AC-1..AC-8 未覆盖）；已登记 `.specs/CONTEXT.md`；复现脚本内注释固化「不得覆盖 `HOOK_BASE_DIR`」 |
| 17 | 🔴 | **L3 第 3 轮实测副产品 · TD-059：阶段门在 commit 路径上是「完成标记是否存在」的判定** ⇒ 标记**一旦存在**，6 键 KVP 值域校验、`MIN_MEANINGFUL_LINES=6`、Tier-2（标记口径 vs 审查档口径）**全部不可达**；`touch` 空文件即可放行；唯一防线只做**命令文本**匹配（拼接写法/非 bash 工具可绕过） | **`Tech-debt: TD-059`**（🔴 最高优先级技术债；v2 修法 = Gate3 复用 Tier-1 校验，把「存在但无效」并入同一拒绝分支 + `touch`/残缺标记必须仍拒绝的 bats）；已登记 `.specs/CONTEXT.md` + `L-152`；本 change 的处置 = **显式缺口实证**（`reproduce-phase-gate.sh` 的 B2/B3 用 `check_gap()` 记录，⚠️ 标注，**不得读作通过**） |
| 18 | 🟡 | **L3 第 3 轮 minor ②③④：§3.4 的 ✅ 可能被读成工具级通过 / TD-033 mock 计入 976 / 第 4 轮标「✅ 必跑」而 macOS 未实跑** | **`Fixed in: TEST.md`**：§3.4（表头改「替代面判定」+ 明示「工具面证据：无」）· §1.3 第 5 条（**有效用例 = 975**，1 条 TD-033 mock 不计入 AC-7 结论面）· §0 第 4 轮行（改「✅ 静态面必跑 / ⚠️ macOS 实机未验证（TD-055）」） |

| 19 | 🟡 | **L3 第 4 轮 major 1：AC 覆盖 8/8 与「3 件生产件 0 引用」并存 ⇒ 结论可能被读作长期回归保障** | **`Fixed in: TEST.md`**：§1.1 新增「**结论口径声明**」（本表 ✅ = **change 期覆盖**，不宣称长期回归保护）+ §回归保护 新增「**长期回归保护的判定：未达标**」显式声明并**交阶段 7 triage**；`Tech-debt: TD-053` 保持 |
| 20 | 🟡 | **L3 第 4 轮 major 2：UAT ③ 称「真实拦截」而 B2/B3 实得放行（TD-059）** | **`Fixed in: TEST.md §1.2 ③`**：新增「**本条验收面结论**」—— 拦截只在**无完成标记**时成立 ⇒ **UAT ③ 判为「部分通过」**，B2/B3 列为该条的**未覆盖分支**；`Tech-debt: TD-059` 保持 |
| 21 | 🟡 | **L3 第 4 轮 major 3：核心数字仍在可见工件之外**（审查信封只送补充产物前 3000 B ⇒ §B/§I 对审查者不可见） | **`Fixed in: TEST.md` 附录 A「最小复算存档」**（12 条判据 rc · bats 收集/有效计数 · `make check` 九门禁摘要 · 性能与端到端样本 · 阶段门五层结果，全部落在正文可见区）+ 附录 B（T17/T19 回写回执） |
| 22 | 🟡 | **L3 第 4 轮 major 4 + minor ①–⑤**（976 与 TD-033 mock 并存 / 无端到端耗时 / OWASP 可能被读成工具级 / 第 4 轮 macOS 措辞 / L 条目无内容 / T17·T19 原文未附） | **`Fixed in: TEST.md`**：§1.3 第 2/4 条与 §2.4/§2.5/§回归保护 统一「**975 有效**」口径（原始回执数字不改写）+ §2.2 新增**端到端耗时**（bats **121.203 s** / `make check` **258.890 s**）+ §3.4 增「**证据等级**」列并把 A02/A06 降为 ⚠️（**✅ 5 / ⚠️ 4 / ➖ 1**）+ §4.4 第 4 轮行改「✅ 静态面通过 / ⚠️ macOS 实机未验证（TD-055）」+ L 索引各行已含一句话内容（编号检索为补充）+ 附录 B 给出 T17/T19 抽取与复算脚本落盘副本的 `diff rc=0` 回执 |
| 23 | 🟡 | **L3 第 5 轮 major 1：AC-1/AC-6/AC-8 行与「覆盖判定 8/8」仍可能被读作长期回归保障** | **`Fixed in: TEST.md`**：§1.1 **AC-1 / AC-6 行各标注**「（仅 change 期判据覆盖，无常设 bats 回归 · TD-053）」；**AC-8 行**结果列改为「✅ change 期 / ⚠️ 长期回归 + macOS 实机」；**覆盖判定**改为「8/8 有 change 期机器可验证据；其中 **3/8 缺少常设 bats 回归**」 |
| 24 | 🟡 | **L3 第 5 轮 major 2：UAT ③ 需显式列为「未通过分支 + 声明行」** | **`Fixed in: TEST.md`**：§0 范围声明后新增「**阶段门有效性（UAT ③ 面）：部分通过 —— 未通过分支 = B2/B3 放行（TD-059 未修复）**」；§1.2 ③ 结论行把 B2/B3 明写为「**未通过分支**」；§1.1 结论口径声明同步该措辞 |
| 25 | 🟡 | **L3 第 5 轮 major 3 + minor ①②③：核心输出仍在被截断的 receipts 内 / A01·A03·A04 仍标 ✅ / §4.4 与 AC-8 需明示 macOS 未验证** | **`Fixed in: TEST.md`**：新增 **附录 C「关键数字的原始输出」**（bats `--count` 与 TAP 计数原文 · `make check` 尾部原文含 privacy 自证四行与结尾框 · 一键复算脚本尾部原文含判据/门禁两表 + `REPRO rc=0`）+ §3.4 **判定收紧**（A01/A03/A04/A07 由 ✅ 改 **⚠️ 替代面**并补限定）+ §3.5 新增**未安装工具清单与可复算命令**代码块 + §4.4 新增「**AC-8 结果列口径**」注（静态判据为限，TD-055 / TD-053 两层含义不含） |
| 26 | 🔴 | **L3 第 6 轮 major 1（verdict=fail）：§1.1 主表仍以 ✅ 结尾 ⇒ 「8/8 全覆盖通过」可被误读为长期回归保障** | **`Fixed in: TEST.md §1.1`** —— 表结构改为 **4 列**（`AC` / 主证据 / **change 期判定** / **长期回归保护**）：AC-1、AC-6、AC-8 的长期回归列 = **❌ 无常设 bats 回归（TD-053）**，其余 5 条 = ✅ 常设 bats/门禁；**覆盖判定**改为「**8/8 仅有 change 期覆盖；3/8 无常设回归保护**」+ 新增「**静态判据通过 ≠ 跨 OS 兼容性验收通过**」 |
| 27 | 🔴 | **L3 第 6 轮 major 2：B2/B3 的 rc=0 被写入复现序列的固定预期 ⇒ UAT ③ 应判未通过** | **`Fixed in: TEST.md`** —— §0 阶段门有效性声明由「部分通过」改为「**未通过（FAIL）**」并明写「B2/B3 是**验收失败分支**」；§1.2 ③ 结论行改「**UAT ③ 判为「未通过（FAIL）」，失败分支 = B2/B3**」；§1.1 结论口径声明同步 |
| 28 | 🟡 | **L3 第 6 轮 major 3 + minor ①②：核心数字仍缺计时原文与脚本可验证性 / AC-8 与第 4 轮仍带 ✅ 前缀 / A08 仍标 ✅** | **`Fixed in: TEST.md`** —— 附录 C 新增 **C-4「计时命令与原始输出」**（bats 121.203 s、`make check` 258.890 s、NFR 5 次 2.822–2.876 s 的 `TIMEFORMAT` 原文 + 可复制命令）与 **C-5「复算脚本的可验证校验和」**（两件脚本 + receipts 的 `sha256sum`，附不内嵌全文的理由）；§0 第 4 轮行去 ✅ 前缀（改「静态判据通过 / ⚠️ macOS 实机未验证」）；§3.4 **A08 降为 ⚠️（无独立安全工具面）** ⇒ **✅ 0 / ⚠️ 9 / ➖ 1**，读法行同步「本节不保留 ✅」 |

> **审查发现处置位置索引**：L2 第 1 轮 3 条 🟡（R8/R9/R10）与 L3 第 1–4 轮全部 major/minor 的逐条分类（`Fixed in:` / `Tech-debt:` / `Not-applicable:`）见 `.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-5.md` 的六段「主 agent 响应」；本节 **1–28** 为同批处置在本报告内的落地索引。**独立技术债条目 = 6**（TD-053 常设回归网 · TD-055 macOS 实机 · TD-056 安全工具面 · TD-057 判据 `rc=$?` 惯用法 · TD-058 `HOOK_BASE_DIR` 语义 · TD-059 阶段门存在性判定），均为 `Tech-debt:` 结案，**未达 `5-test.md` 的 50% 阈值**；其中 **TD-058 / TD-059 为阶段 5 实测新发现的产品缺陷**，各附 v2 修法与非本 change 范围内的次序理由。

---

## L 条目索引（本文引用的经验条目 · L3 第 2 轮 minor ⑤ 响应）

| 编号 | 含义（本文引用它的场景） | 出处（`.specs/LESSONS.md`，2026-09-24 落档行号） |
|---|---|---|
| L-129 | 绝对路径入档前必须 de-shape（机器路径同时污染基线与 git 历史）⇒ 本文头部写「仓库根 = `<repo>`」 | `grep -n '^### L-129' .specs/LESSONS.md` |
| L-137 | 「扫描面的判据」必须在 `git add` 新产物**之后**运行（提交那一刻扫描面才扩大）；探针字面须拼接构造 | `grep -n '^### L-137' .specs/LESSONS.md` |
| L-146 | 判据里的 `export LC_ALL=C` 会泄漏进它调用的测试套件；`iconv -f utf-8 -o f` 的目标字符集取自 locale ⇒ 地域 C 下拒绝合法 UTF-8（假红） | `grep -n '^### L-146' .specs/LESSONS.md` |
| L-147 | 产品件自证用的合成探针若要被 change 期判据复核，必须**逐条精确字面**豁免，不能抄产品整文件排除（否则判据自造红） | `grep -n '^### L-147' .specs/LESSONS.md` |
| L-148 | PreToolUse 门禁按**命令文本**匹配握手文件名 ⇒ 只读勘查也要用不含文件名的形式（`ls -a` / `git ls-files`） | `grep -n '^### L-148' .specs/LESSONS.md` |
| L-149 | 审查派发面必须显式要求脱敏：L2/L3 会把真实仓库根原样写进审查档，**入库瞬间**击穿 AC-6 门禁（本文 §阶段 5 发现 #5 的根因） | `grep -n '^### L-149' .specs/LESSONS.md` |
| L-150 | 「完备性」判据会把新产品件自动推向豁免面：判据必须编码**策略**（时间切点），不能编码**集合快照**（本文 §1.7 / T17 改判的依据） | `grep -n '^### L-150' .specs/LESSONS.md` |
| L-151 | 审查信封对**补充产物**只取前 3000 B（`l3-prompt.sh:286/304`）⇒ 给外部审查者的证据必须「倒置金字塔」：结论与复算入口放文件头（本文 #11 的依据） | `grep -n '^### L-151' .specs/LESSONS.md` |
| L-152 | 门禁的强度等于它**最早返回**的那个判定：以「文件存在」为界 ⇒ 配套内容校验成为不可达装饰；只匹配命令文本的守卫可被拼接绕过（本文 #16/#17 · TD-058/TD-059 的依据） | `grep -n '^### L-152' .specs/LESSONS.md` |

> 出处列给出**编号检索命令**而非固定行号：`LESSONS.md` 的新条目插在 `<!-- health-fix-2026-09b 追加 ↑ -->` 之后按编号**倒序**排列，行号会随新增漂移（本表原先的落档行号已因 L-151/L-152 插入而下移，故改为编号检索）。

---

## 附录 A · 最小复算存档（正文可见区 · L3 第 4 轮 major 3 响应）

本附录把全部核心数字**落在本工件正文**，不依赖外部文件即可逐项核对；完整原始 stdout 仍存档于 `.specs/health-fix-2026-09b/PHASE5-RECEIPTS.md`（§A 判据 12 条 / §B 门禁 / §D 判据修正台账 / §E · §I 性能 / §H 阶段门沙箱）。**一键复算**：

```bash
bash .specs/health-fix-2026-09b/reproduce-5-test.sh       # 12 条判据 + 7 道门禁（含 [F] 阶段门沙箱复现）
bash .specs/health-fix-2026-09b/reproduce-phase-gate.sh   # 阶段门五层状态 A/B/B2/B3/C + 判别子
```

**① change 期判据 12/12 ✅ rc=0**（从 `TASK.md` 各 `<verify>` **原样抽取**、**字面执行**，零改写）：

| 判据 | T05 | T06 | T11 | T13 | T17 | T19 | T20 | T22 | T24 | T26 | T27 | T29 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| rc | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| 抽取行数 | 12 | 22 | 7 | 34 | 73 | **36** | 3 | 20 | 18 | 30 | 19 | 15 |

**② `make check` 门禁 9/9 + 复现门禁 7/7 ✅**：`npx bats --count test/` = **976**（有效 975）· `npx bats test/` rc=0 **ok=976 / not ok=0 / skip=0** · `make check` rc=0（✅ bats / ✅ shellcheck 68 文件 / ✅ validate 漏配 0 源缺失 0（期望 311 / 实际 317） / ✅ test 双源一致 / ✅ hooks 六镜像 0 漂移 / ✅ check-dist / ✅ check-gate-sync 3/14 对 + 17 预设 / ✅ 清单外命中 0 / ✅ NFR 兼容性判据）· `make check-path-privacy` rc=0 · `package-flow-kit.sh --validate` rc=0 · 阶段门沙箱复现 rc=0。

**③ 性能（预算 ≤5 s）与端到端耗时**：`make check-path-privacy` 三次 2.830 / 2.868 / 2.826 s（首轮）、五次 2.842 / 2.847 / 2.898 / 2.836 / 2.867 s（第 2 轮补测，均值 2.858）、五次 2.876 / 2.822 / 2.850 / 2.834 / 2.871 s（处置后复测，均值 **2.851** = 预算 **57%**，`nproc=32`，`loadavg` 5.95–6.52）；`check-gate-sync` 0.047–0.053 s；`check-nfr-portability` 0.172 s；**端到端**：`npx bats test/` real **121.203 s** · `make check` real **258.890 s**（§2.2）。

**④ 阶段门沙箱复现（`reproduce-phase-gate.sh` · 五层状态）**：`A`（gate=both 且无标记）⇒ **rc=2** + 报文 `⛔ 独立 review gate：阶段 5 (5-test) 独立 review 未完成，禁止 git commit。` + **HEAD 不变**；`B`（gate=L2 + 合格 6 键标记）⇒ **rc=0** 放行且放行后 `git commit` **真的生效**；`C`（无 `.flow-active`）⇒ rc=0（门不适用）；**`B2`/`B3` ⇒ rc=0 = ⚠️ 缺口实证（TD-059，不得读作通过）**；**判别子**（门禁外直连 commit 成功）✅。

**⑤ 失败语义**：任一判据非 0 ⇒ 脚本 rc=1 并打印失败清单（实测 `REPRO2 rc=1 判据失败[ T29 ] 门禁失败=1`，见 §附录 A ④ 与 receipts §I）。

---

## 附录 B · T17 / T19 回写回执（L3 第 4 轮 minor ⑤ 响应）

本报告**唯二**的判据修正（T17 / T19）都写在**权威副本** `TASK.md` 内 ⇒ 重抽即得修正后版本；抽取结果与复算脚本落盘副本**逐字节相同**：

```bash
for t in T17 T19; do
  ext=$(mktemp)
  sed -n "/<task id=\"$t\"[^>]*>/,/<\/task>/p" .specs/health-fix-2026-09b/TASK.md \
    | sed -n '/<verify>/,/<\/verify>/p' | sed '1d;$d' > "$ext"
  cmp -s "$ext" "/tmp/fk-reproduce-5/v_$t.sh" && echo "$t: diff rc=0 行数=$(wc -l < "$ext")"
done
# 实测：T17: diff rc=0 行数=73    T19: diff rc=0 行数=36
```

**T19 回写内容（L3 第 3 轮 major 4 · 四行 + 三行约定注释）**：`:877` 循环内 `rc=0; out=$(git $form 2>&1) || rc=$?` · `:881` `rc=0; out=$(git push origin --tags 2>&1) || rc=$?` · `:886` `rc=0; out=$(git push --all 2>&1) || rc=$?` · `:889` `rc_off=0; git push origin main >/dev/null 2>&1 || rc_off=$?` · `:895` 块尾约定注释（以「先置零再捕获」形式捕获，**禁止** `out=$(cmd); rc=$?`）。

| 运行器（回写前后对照） | 回写前 | 回写后 |
|---|---|---|
| 平跑 `bash v_T19.sh` | rc=0（19 行前置输出） | rc=0（37 行输出） |
| strict `bash -e -u -o pipefail v_T19.sh` | **rc=1 / 无任何 🔴 报文**（与真红态不可区分） | **rc=0 / 无 🔴 报文** |

原始输出：`/tmp/p5/m4.out`（平跑）与 `/tmp/p5/m4-strict.out`（strict）；同批记录见 receipts §D 台账。

**T17 回写内容（阶段 5 第 2 轮 · L-150）**：豁免面由「集合完备」改判为**时间切点**（冻结的 1–3 为唯一豁免集；此后新增审查档一律不豁免、必须被双面扫过）⇒ 回写后抽取 **73 行**、rc=0；依据与实证见 §1.7 与 `L-150`（`.specs/LESSONS.md`）。

---

## 附录 C · 关键数字的原始输出（L3 第 5 轮 major 3 响应 · 可在本工件内直接核对）

> 说明：本节把「核心数字」的**原始输出**（而非仅汇总表）附在**可见工件正文内** —— 因为 `PHASE5-RECEIPTS.md` 超出补充产物 3000 B 预算（`flow-kit-bundle/hooks/stop/lib/l3-prompt.sh:286` / `:304`，L-151），外部审查者只能看到其头部。绝对路径按 L-129 去形为 `<repo>/`。

### C-1 bats 用例数与 TAP 计数

```text
$ npx bats --count test/
976
$ grep -c '^ok ' /tmp/p5/bats-e2e.out      # 全量 TAP 回执（作业 bash-209）
976
$ grep -c '^not ok ' /tmp/p5/bats-e2e.out
0
```

端到端耗时（同机同环境）：`real 121.203 s`（user 81.050 / sys 44.707，rc=0）。

### C-2 `make check` 尾部原始输出

```text
   ✅ 预设名集合一致 (17 个预设)

   ── 校验汇总 ──
   覆盖度: 校验对 3/14（v1 仅覆盖内容本应一致、仅差 front-matter 的对；其余 11 对已实质分叉，留 v2/TD-025）
   ✅ 校验对 3/14 一致（仅覆盖上述对，非全量 14 对全绿）。
🔍 make check-path-privacy: 路径隐私（允许清单外命中 / fail-closed）检查 ...
🔍 check-path-privacy: 扫描本机绝对路径前缀泄漏（PAT=/home/[a-z_][a-z0-9_-]*/）
   扫描面: 工作树
   允许清单来源: flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt
   允许清单 0 条
   命中合计 0 条（含占位符排除后）
   清单外命中 0 条
✅ 清单外命中 0 条（允许清单内残留只暴露不阻塞）
🔍 make check-nfr-portability: NFR 兼容性判据（bash 3.2/macOS 可移植 · 三态包装）...
✅ NFR 兼容性判据通过：无新增 bash4-only / GNU-only 构造，语法检查通过

╔════════════════════════════════════════════════════╗
║  ✅ make check: 全部通过                           ║
╚════════════════════════════════════════════════════╝
```

端到端耗时：`real 258.890 s`（user 170.315 / sys 93.520，rc=0）⇒ bats 主体 121.2 s，其余 8 道门禁合计 ≈137.7 s，本 change 新增三门禁（privacy / NFR / 阶段门复现）增量 ≈3.0 s = `make check` 的 1.2%。

### C-3 一键复算脚本在 HEAD 的完整运行回执（尾部原文）

```text
（判据表）T05 12 行 · T06 22 · T11 7 · T13 34 · T17 73 · T19 36 · T20 3 · T22 20 · T24 18 · T26 30 · T27 19 · T29 15（全部 ✅ rc=0）

== 汇总 ==
| 判据 | 结果 | 抽取行数 | 原始输出 |
| T05 | ✅ rc=0 | 12 | `out_T05.txt` |  … （12 条同列，逐条 rc=0）
| 门禁 | 结果 | 摘要 |
| bats --count | ✅ rc=0 | 用例数 976（源码面 test/*.bats） |
| bats test/ | ✅ rc=0 | rc=0 ok=976 not-ok=0（基线 976 ok / 0 not ok，skip 计入 ok 行） |
| make check | ✅ rc=0 | 21 条 ✅ / 0 条 ❌（原文 /tmp/fk-reproduce-5/make-check.txt） |
| check-path-privacy | ✅ rc=0 | ✅ 清单外命中 0 条（允许清单内残留只暴露不阻塞） |
| NFR ≤5s ×5 | ✅ rc=0 | 环境 nproc=32 loadavg=5.95 6.13 6.25 |
| package --validate | ✅ rc=0 |    🔴 漏配 (ERROR): 0    ⚠️  源缺失 (WARNING): 0  |
| 阶段门沙箱复现 | ✅ rc=0 | 健康层 A/B/C ✅ · 缺口层 B2/B3 ⚠️（TD-059，非通过项）· 原文 /tmp/fk-reproduce-5/phase-gate.txt |

✅ 复算全绿（判据 + 权威回执）；原始输出保存在 /tmp/fk-reproduce-5
```

脚本退出码 **REPRO rc=0**；完整原文见 `.specs/health-fix-2026-09b/PHASE5-RECEIPTS.md` §A/§B/§I（同一次运行的落档副本）。

### C-4 计时命令与原始输出（未删改）

```text
== time npx bats test/ ==
real=121.203 user=81.050 sys=44.707
bats rc=0
== time make check ==
real=258.890 user=170.315 sys=93.520
check rc=0

== [D] NFR 性能预算（5 次 · 预算 ≤5s）==   # 来自 reproduce-5-test.sh 本次运行
       run 1: real=2.876 user=1.147 sys=1.892
       run 2: real=2.822 user=1.162 sys=1.808
       run 3: real=2.850 user=1.149 sys=1.855
       run 4: real=2.834 user=1.147 sys=1.851
       run 5: real=2.871 user=1.184 sys=1.848
  NFR ≤5s ×5          ✅ rc=0  环境 nproc=32 loadavg=5.95 6.13 6.25
```

计时命令（可直接复制执行）：

```bash
TIMEFORMAT='real=%R user=%U sys=%S'; time npx bats test/; time make check
for i in 1 2 3 4 5; do time make check-path-privacy >/dev/null; done
```

### C-5 复算脚本的可验证校验和（L3 第 6 轮 major 3 响应）

两件复算脚本是本 change 的**已提交工件**（非临时文件），可用校验和核对内容未被篡改；`TEST.md` 自身的哈希由每轮 L3 记录在 `.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-5.md` 的 `L3_artifact_hash:` 行（审查时冻结值）。

```text
$ sha256sum .specs/health-fix-2026-09b/reproduce-5-test.sh \
            .specs/health-fix-2026-09b/reproduce-phase-gate.sh \
            .specs/health-fix-2026-09b/PHASE5-RECEIPTS.md
6c73c93af696d816f87d8d2b8e5ce1f0c31dd9cbfb649654433f6125fdfa8a6e  reproduce-5-test.sh      (185 行)
4ddeb72662187c9d138c9b77358da094432855c0f6fb4f315b7ead5445bf8ec9  reproduce-phase-gate.sh  (165 行)
f7464625fb54e765f1214794c57171e007c3a8d0f92be662b7b37e2f877fdb2e  PHASE5-RECEIPTS.md
```

> **说明（为何正文不内嵌脚本全文）**：两件脚本合计 350 行，内嵌会使本报告体积翻倍且与已提交工件重复；`5-test.md` 未要求报告自身承载脚本副本，而 L3 第 6 轮 major 3 给出的可接受形态包含「**可验证的校验和**」⇒ 本节采用 `sha256sum` + 可复制命令。脚本的**运行输出**（判据 / 门禁 / 性能 / 阶段门）已在本附录 C-1–C-4 逐段给出原文，`PHASE5-RECEIPTS.md` §A–§I 为同一次运行的完整落档。
