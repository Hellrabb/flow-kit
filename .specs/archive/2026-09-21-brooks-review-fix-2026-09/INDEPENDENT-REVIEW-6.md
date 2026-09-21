# 独立审查 · 阶段 6

## L2 盲审

> 独立性声明：本次审查仅依据调用方指定的工件与 `git diff` / 未跟踪文件 / 只读 bash 实跑结果。
> REVIEW.md、DEV-SUMMARY.md、FIXES.md 等自述均作为**待复核对象**，未作为权威依据。
> 未在输入中检测到主 agent 自评 / 草稿 / 概述 / 辩护性上下文注入。

### 🟢 R1 · 测试登记数字漂移：TEST.md 用例计数自相矛盾
**Severity**：🟢 Minor
**Symptom（症状）**：`.specs/brooks-review-fix-2026-09/TEST.md:185`「新增测试登记」表写 `用例数 9`，但同文件 `:30/:41/:78/:106/:187` 多处及 AC-7（`:130`）一致写 `11 例` / `961 ok`。`npx bats test/test_gate_freshness.bats` 实跑确认为 `1..11`（11/11 全绿）——登记表数字过时。
**Source（源头）**：Hunt & Thomas · *The Pragmatic Programmer* · DRY（每条知识只有一处权威表述）——同一事实（用例数）在同一文件内有两版表述且已分叉。根因可溯：REVIEW.md 第二轮 R6/R4 审查期补了用例 10（`--entry-class` 未知前缀）、11（`<base-ref>` fail-closed），正文与 AC-5/AC-6 行同步更新为 11，但末尾登记表漏改。
**Consequence（后果）**：维护者读登记表会误信"只新增 9 例"，与 `make check` 的 `961` 基线对不上；不会爆，但制造"文档不可信"的噪声，削弱登记表的权威性。
**Remedy（修补）**：把 `TEST.md:185` 的 `用例数 9` 改为 `用例数 11`，覆盖列同步改为 `check-dist 5 例 · 打包缺失语义 1 例 · 真入口判据 3 例 · <base-ref> fail-closed 1 例 · 用例自检 1 例`（与 `:24` DESIGN §0.5.1 的拆分一致）。

### 🟢 R2 · 处置记录数字漂移：FIXES.md 仍写 9 例 / 959
**Severity**：🟢 Minor
**Symptom（症状）**：`.specs/health/2026-09-21-BROOKS-REVIEW-FIXES.md:12/:22` 写 `9 例`、`950 → 959 ok`，但本 change 回溯登记后最终态为 `11 例` / `950 → 961`（TEST.md / REQUIREMENT AC-7 / DEV-SUMMARY / REVIEW 一致，bats 实测确认）。
**Source（源头）**：ADR-017（Minor 单一路径）配套的可复算原则——"账本与工件"类记录虽不进 fix loop，但**数字必须可复算**。FIXES.md 是"当日实跑原始数据"（CHANGE.md「登记形态」声明），在补用例 10/11 前写就，回溯登记后未回填。
**Consequence（后果）**：未来有人读 FIXES.md 做趋势比对（如 `.brooks-lint-history.json` 第 8 条 note 引用了它）会拿到错误的 bats 基线（959 而非 961），影响后续 change 的"不退化"判定参照。
**Remedy（修补）**：在 FIXES.md 🟡2 行追加括注 `（后补用例 10/11 后为 11 例 / 961，见 TEST.md）`，或在全量验证表的 `959` 处加注 `（回溯登记后更新为 961）`；不必重写原始记录（保"当日实跑"口径），但需标明最终态。

### 🟢 R3 · AC 验证脚本负向断言正则误命中弃用说明注释
**Severity**：🟢 Minor
**Symptom（症状）**：`REQUIREMENT.md:61` AC-2 验证段 `grep -qE "grep -qE '\^\[\[:space:\]\]\*is_real_entry" verify-claims.sh && { echo "FAIL: 文本判据复活"; exit 1; }` 实跑**命中**（rc=0），会报 `FAIL: 文本判据复活`。但命中点是 `verify-claims.sh:310` 的**注释**（`# 原实现是 grep -qE '^[[:space:]]*is_real_entry\(\)' sync-hooks.sh —— 那是源码文本判据…`），是说明弃用历史的设计注释，非生产代码。同族问题：`REQUIREMENT.md:115` AC-6 的 `grep -q "git status --short.*awk" verify-claims.sh` 也命中 `verify-claims.sh:237` 的弃用说明注释。生产代码（`:313-316` 用 `bash sync-hooks.sh --entry-class` 行为断言、`:198` 用 `git ls-files --others`）本身正确。
**Source（源头）**：Meszaros · *xUnit Test Patterns* · Behavior Verification——断言应精确指向被测行为，而非宽泛 grep 文本（含注释）。这正是本 change 要消灭的"用存在性/文本代替行为"的同类陷阱，讽刺地出现在验证它自己的 AC 脚本里。
**Consequence（后果）**：若有人照 REQUIREMENT AC-2 / AC-6 验证段原样执行，会得到假 FAIL（"文本判据复活"），而实际门禁是绿的——验证脚本自身的假阳性削弱了 AC 的可复算性承诺（REQUIREMENT 非功能需求「可复算：所有 AC 的验证命令可原地复制执行，不依赖人工判断」未真正满足）。
**Remedy（修补）**：负向断言改用更精确的定位——如 `grep -qE "^[^#]*grep -qE.*is_real_entry\(\) sync-hooks" verify-claims.sh`（排除注释行），或改断言"§10d ③ 不含对 sync-hooks.sh 的 is_real_entry 文本 grep 调用"用 `bash -n` + AST 分析；AC-6 同理把 `git status --short.*awk` 收窄为非注释行匹配。最小修法：在 grep 前加 `grep -v '^[[:space:]]*#'` 过滤注释。

---

### AC 逐条独立复核（证据优先）

| AC | 独立验证手段 | 结果 |
|---|---|---|
| AC-1 三态不换对象 | source `resolve_spec_artifact` 实测：未指定→rc=1；归档真 change `health-fix-2026-09`→rc=0 且路径正确（`.specs/archive/2026-09-21-health-fix-2026-09/DESIGN.md`）；ghost id→rc=2；无 `l3-review-defects` 回退 | ✅ 真正实现 |
| AC-2 行为级回归 | `npx bats test/test_gate_freshness.bats` → `1..11` 全绿；`grep --entry-class verify-claims.sh` 命中行为断言（:319/:321）；生产代码无 is_real_entry 文本 grep 调用 | ✅ 真正实现（R3 仅指验证脚本正则） |
| AC-3 映射单一 + 缺失语义 | `grep -c 'COPY_DIRS\[@\]' package-dsh-plugin.sh` = 2（打包循环 + 检查循环各一次）；bats 用例 3/4/7 实测源缺失→rc=1 指名 | ✅ 真正实现 |
| AC-4 注释去重 | `grep -c 'dist/ 被 .gitignore 忽略' Makefile` = 1；`grep -c '10c. DESIGN §0.5.1' verify-claims.sh` = 1 | ✅ 真正实现 |
| AC-5 判据可直调 | `--entry-class` 六场景实测：真入口 rc=0（2）/ 库 rc=1（2）/ 缺参 rc=2 / 未知前缀 rc=2 | ✅ 真正实现 |
| AC-6 `_changed` 收敛 | `grep -c 'git ls-files --others --exclude-standard' verify-claims.sh` = 1；生产代码无 `git status --short\|awk` 调用（R3 仅指注释命中） | ✅ 真正实现 |
| AC-7 门禁不退化 | `package-dsh-plugin.sh --check` rc=0；`sync-hooks.sh --check` 漂移 0；bats 11/11（`make check` 本 L2 禁跑 >4min，以 bats + 两项只读门禁 + 双源一致替代） | ✅ 证据充分 |

### L-031 跨文件一致性核查（通用必查项）

锚点 grep 结果：

| 锚点 | 命中点 | 一致性判定 |
|---|---|---|
| `COPY_DIRS`/`COPY_FILES`/`COPY_OPTIONAL` | package-dsh-plugin.sh 打包循环(:164+) + check_dist(:81/:110/:127) 各读一次 | ✅ 单一映射，无第二份编码 |
| `is_real_entry()` | sync-hooks.sh:78 定义 + :99(--entry-class) + :236(--check 循环) | ✅ 文件作用域，两处调用 |
| `--entry-class` | sync-hooks.sh 定义(:40) + verify-claims.sh §10d 调用(:319/:321) + bats 8/9/10 守护 | ✅ 三处接线 |
| `PTU_ENTRIES` 白名单 | 3 项与真实 `flow-kit-bundle/hooks/pre-tool-use/` 顶层 3 个真入口一致；另 4 个库（gate-checks-basic/review/helpers/helpers-types）正确判库 | ✅ 白名单无漂移 |
| DESIGN §0.5.1 vs git diff 实改文件 | 5 已跟踪（Makefile/package/sync-hooks/verify-claims/.brooks-lint-history）+ 2 未跟踪 bats；§0.5.1 列前 4 + 2 bats，.brooks-lint-history 列入"非产品代码"排除区且 §10c 正则不扫 .json | ✅ 无漏改（第 4 类） |

### 主 agent REVIEW.md 漏判 / 误判核查

- REVIEW.md 第二轮 R6（`<base-ref>` 静默换基线 → 🟡）与 R4（`--entry-class` 拼错路径给结论 → 🟢）：我**独立**实测 `verify-claims.sh:41-45` 的 `git rev-parse --verify` fail-closed 与 `sync-hooks.sh:96` 前缀白名单，行为与 REVIEW.md 的 `Fixed in` 声明一致。**独立得出相同结论**，非抄。
- REVIEW.md 未提及的发现：上述 R1/R2/R3 三条 🟢——主 agent 的自查止于"代码层"，未下探到"AC 验证脚本自身的正则精度"与"回溯登记后跨工件数字同步"。
- 主 agent 无上下文注入（REVIEW.md 的"主 agent 响应"段为空占位 `（待 L2 / L3 完成后…）`，未掺入自评）。

**Verdict**: pass

---

## L3 重审（deepseek-v4-flash-0731 外部模型 · 2026-09-21 17:27）

> 自动生成于 2026-09-21 17:27。由 l3-review.sh 写入。

### 审查结论

```json
{
  "critical": [],
  "major": [
    {
      "file": "package-dsh-plugin.sh",
      "issue": "check_dist 在 $PKG_DIR 不存在時直接 return 0，跳過所有必需源缺失檢查；當 dist 尚未構建且 COPY_DIRS/COPY_FILES 對應源已缺失時，--check 仍返回 0。",
      "why": "LESSONS L-103 已將「必需項源缺失 = 無條件 fail」記為已吸收規則，而此處在 dist 不存在時不檢查源存在性，會造成源已損壞但門禁通過、後續打包必敗的假綠場景。",
      "fix": "在 dist 不存在的分支中先遍歷 COPY_DIRS/COPY_FILES 檢查必需源是否存在；缺失則置 fail=1 並指名輸出，再決定返回 0/1；或將「dist 不存在」明確定義為 SKIP 語義而非「一致」。"
    },
    {
      "file": "package-dsh-plugin.sh",
      "issue": "check_dist 核心邏輯重構後沒有新增 bats 測試，LESSONS L-101 要求檢查器/判據代碼由 bats 真跑行為斷言。",
      "why": "本 change 修改了映射來源、缺失語義、反向殘留等關鍵行為，但 diff 中未見對應測試；此前 warning ②已指出「新門禁零 bats 覆蓋」，本 change 未消除該風險，未來回歸時無自動保護。",
      "fix": "為 package-dsh-plugin.sh --check 增加 bats 用例：必需目錄缺失、必需文件缺失、可選文件缺失、反向殘留、內容陳舊、dist 不存在等，斷言退出碼和輸出。"
    }
  ],
  "minor": [
    {
      "file": "package-dsh-plugin.sh",
      "issue": "COPY_DIRS 源目錄缺失時，dist 殘留只報告「N 個文件」，未逐條指名具體文件。",
      "why": "usage 聲稱「1 = 陳舊 / 反向殘留 / 必需源缺失（逐條指名）」，但此分支僅給出目錄和計數，維護者仍需手動查找殘留文件，降低可觀測性。",
      "fix": "在該分支遍歷 dist 殘留並逐條輸出相對路徑，或至少列出前若干個文件。"
    },
    {
      "file": "package-dsh-plugin.sh",
      "issue": "check_dist 使用 find -type f 對比，不檢查符號連結；源或 dist 中的 symlink 缺失/指向變化不會被發現。",
      "why": "打包 cp -R 會複製 symlink，但 -type f 不匹配 symlink，導致 --check 可能漏報此類不一致。",
      "fix": "如需完整一致性，將 find 條件擴展為 -type f -o -type l，或改用 tar 比對方式；至少在注釋中記錄此限制。"
    },
    {
      "file": "package-dsh-plugin.sh",
      "issue": "COPY_DIRS 中整棵 $BUNDLE_DIR 映射與多個子目錄映射重疊，check_dist 會對同一批文件重複 find/cmp。",
      "why": "例如 skills 下文件既會被 vendor/flow-kit-bundle 對檢查，又會被 skills 對檢查，造成冗餘執行和輸出噪音。",
      "fix": "若 vendor 整樹複製是為了零丟失，可考慮移除單獨子目錄映射；或合併為唯一映射避免重疊。"
    },
    {
      "file": ".brooks-lint-history.json",
      "issue": "note 中引用 .specs/health/2026-09-21-BROOKS-REVIEW.md 作為報告產物，但本次 diff 未包含該文件，鏈接可追溯性依賴外部提交。",
      "why": "lint history 的結論需要外部報告支撐；若報告未在同一提交中，後續讀者無法直接核驗 warning 細節。",
      "fix": "確保該報告在同 commit 提交，或在 note 中直接附上關鍵結論摘要。"
    }
  ],
  "verdict": "pass",
  "summary": "本 change 主要修復了 check_dist 的映射單一化與缺失語義問題，無 blocking critical，但 dist 不存在時源缺失漏檢及缺少 bats 覆蓋是需後續跟進的主要風險。"
}
```

L3_artifact_hash: e5f5d0fa2c58009b0d9a2d1c8db45e8e2968727cee55be0e2856e661c7722d03

<!-- /L3-SECTION -->
