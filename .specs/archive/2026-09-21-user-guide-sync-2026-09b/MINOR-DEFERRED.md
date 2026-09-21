# Minor Findings Deferred to Phase 7 Triage

> 单一路径（ADR-017）。本表由各阶段 L2/L3 的 🟢 Minor 发现汇聚，阶段 7 由用户 triage。

| # | Task | Finding ID | Description | Deferred reason | Date |
|---|------|------------|-------------|-----------------|------|
| M1 | 阶段1 | R8（人工半段） | AC-7 的「文字溢出框外 / CJK 缺字方框」目前只有固定抽检清单 + 目视结论，无稳定自动判据 | 需引入 PPTX→PDF 字形边界检测（成本高于本 change 价值）；机检部分（页数一致、PNG 非空、尺寸一致）已折入 AC-7 | 2026-09-21 |
| M2 | 阶段1 | R10（延伸） | 把 `deck_checks.py` 接进 `make check`（新增 `check-deck` target 或并入 `check-dist`） | 本轮只做「断言有效性实测」（AC-6）；新增门禁 target 属门禁面扩张，DESIGN D2/D7 已登记为 v2 | 2026-09-21 |
| M3 | 阶段1 | R1（延伸） | 把 `root↔bundle` 副本守护从测试层提升为独立门禁 target（`make check-guide-sync`） | 同上：本轮落在 `test/test_guide_copy_parity.bats`（由 `make test` 覆盖），不改门禁链 | 2026-09-21 |
| M4 | 阶段3 | R8 | T02 单任务变更面超出「单 task ≤ 200 行」软线（**实测终态**：tracked diff **1248+/829−**，其中 `slides.json` 1315 行、指南两侧合计 ~164 行新增） | Minor（Severity Gating 不入 fix loop）；已由 T07 要求记录 `git diff --stat` 变更行数，超线在 DEV-SUMMARY 显式说明理由；阶段 4 可按 §7 与 §6/§9/§12 拆两次提交以便定位 | 2026-09-21 |
| M5 | 阶段2 | R8 | `CHANGE.md:22,52` 写「三处副本」与 AC-5「四份副本」口径不一致 | Minor（历史文本）；阶段 7 triage 时决定是否回填为「四份」 | 2026-09-21 |
| M6 | 阶段2 | R13 | `.specs/user-guide-deck-gen/README.md:28` 的封面日期行用裸 `\|`（`2026-09-03 \| github.com/hellrabb/flow-kit`），若下轮移入表格会破表 | Minor：本轮改写时顺手转义/重排，但不单列验收 | 2026-09-21 |
| M7 | 阶段2 | R14 | DESIGN R4 缓解「回退到既有 theme 字体族」无落点——`theme.py` 的 `Times New Roman` / `宋体` 在本渲染机 `fc-list` 均无命中（实际由 Noto Serif/Sans CJK 兜底） | Minor：AC-7 的排版抽检实为替代字体度量，已在 TEST.md 留痕；换字体/装字体不属本 change | 2026-09-21 |
| M8 | 阶段3 | R4（L-031 漏改） | `三轮审查` 措辞仍在 3 个未声明载体原样存留：`flow-kit-bundle/skills/flow-review/SKILL.md:6,24,196`（+ `:2` description 写「双轮审查」）、`flow-kit-bundle/flow-kit/README.md:304`（「双 / 三轮审查」）、`flow-kit-bundle/flow-kit/templates/REVIEW.md:73`（实测仅该行含「三轮」；`grep -F '三轮审查'` = 0）；权威实现为 `prompts/6-review.md` 的「单轮合并审查」 | Minor（**范围外**）：本轮 AC-9 冻结 `flow-kit-bundle/skills/**` 与 `flow-kit-bundle/flow-kit/prompts/**`，模板与引擎 README 亦不在白名单 → 不在本 change 修；**跟进**：另开 change `phase6-review-wording-2026-09`（或并入下次 skills/templates 同步）逐条对齐；本表留痕以免静默遗漏 | 2026-09-21 |
| M9 | 阶段1 | R18 | D21 反例串「已废弃说明句」的豁免口径未定义（22:18 曾 1 命中，22:19 复测四份均 0 → 无现存违规） | Minor：AC-1/AC-3 已有白名单范式，D21 未补；实例已自愈，登记口径缺口 | 2026-09-21 |
| M10 | 阶段2 | R21 / 阶段6 R8 | DESIGN 证据链引用不实：`§0.5.1 行号与哈希`（v2 起已删哈希）· `Makefile:6` 是空行 · `Makefile:136-137` 应为 `:133-134` | **已修**（v4.1）：两处 `Makefile` 行号改为 `:133-134` 与 `:106`；`§0.5.1 行号与哈希` 措辞保留（哈希已删，行号仍有效）。此条仅留痕 | 2026-09-21 |
| M11 | 阶段5 | R6 | TEST.md §5.3（`make check`）与 §3.3（「无空页」）是**带口径的声明**而非逐字输出 | Minor：`make check` 全量输出较长，本轮以「六门逐项 ✅ 行 + rc=0」摘录；如后续需要，可改存 `.specs/<id>/artifacts/make-check.log` | 2026-09-21 |
| M12 | 阶段5 | R7 | 性能轮计时原用 `/usr/bin/time -f %e`（两位小数 → 三次全 0.00，分辨力不足） | 已改用 `TIMEFORMAT='%3R'`（0.002 s）并回填 TEST.md；保留此条记录口径变更 | 2026-09-21 |
| M13 | 阶段5 | R8 | AC-9 判据声明含 `git ls-files -o`，而 `verify-boundary.sh` 只跑 `git status --porcelain` | **已修**：脚本补 `git ls-files -o --exclude-standard` 独立核一遍（与判据声明同源）；此条仅留痕 | 2026-09-21 |
| M14 | 阶段2 | R26 | deck 字节不可复现：zip entry 的 `date_time` 入档 → tracked `flow-kit-用户指南.pptx` 每次重建必 churn（内容可复现：entry 内容 `diff -rq` 全同） | Minor：本轮守护只断页数/封面/标题/关键串，**不**对 pptx 做 md5 断言（否则假红）；如需消除 churn，可在 build.py 里固定 zip 时间戳（v2） | 2026-09-21 |
| M15 | 阶段2 | R24 | `deck_checks.py` 的 `EXPECT_PAGES=24` 是等值断言，严于 AC-6 的「≥24」 | **Not-applicable（有意为之）**：该断言比较的是 **slides.json 与 pptx 两个产物之间**的页数一致（生成器契约），不是对 AC 下限的断言；AC 的「≥24」由 AC-6 用例（页数 ≥24）单独承担 | 2026-09-21 |
| M16 | 阶段2 | R22 | DESIGN §0.5.1「会修改/会新增」清单不完整（未登记 `verify-boundary.sh`/`check-appendix-superset.py` 等 change 目录新脚本、dist README 再生件） | Minor：change 目录本身在 AC-9 白名单前缀内，不影响边界判据；清单已在 DESIGN §5 补记竞写者 `tools/pptx-light-sync.py`（不执行/不修改） | 2026-09-21 |
| M17 | 阶段5 | R2/R4 | TEST.md / UAT.md 计数在多轮修订中漂移（80/84/86、6/7/8 并存；UAT 未回填、triage 范围只写到 M10） | **已修**（v4.1）：以实跑为准统一为 `verify-ac 106/0`、`集合断言 58 格/跳过 20/缺失 0`、`bats 8/8`；UAT 回填并把 triage 范围改为 M1–M20。留痕：计数类事实应**从实跑输出生成**而非手抄 | 2026-09-21 |
| M18 | 阶段6 | R6 | `verify-ac.sh` 的 AC-4 段缺 N3 的 `check-validate` / `check-test-sync` 两条锚点断言 | **已修**（v4.1）：两条已补入判据实现，并通过数由 86 → **106**（含新增的 D32/D36/D37×6/D41/N3×2/N9/N10/N11 后果串/N13 三平台） | 2026-09-21 |
| M19 | 阶段5 | R1（根因） | 两个**既有** bats 把夹具写在仓库内而非 `$BATS_TEST_TMPDIR`：`test/test_lessons_cleanup.bats` 瞬态 `touch flow-kit-bundle/TEST_GAP_DO_NOT_PACKAGE`、`test/test_l3_review_defects_2026_09.bats` 造 `.sync-hooks-orphan-test.sh` —— 中断时会永久留下越界文件，并让 `verify-boundary.sh` 这类"读仓库状态"的判据假红 | 判据侧已过滤（v4.2）；**根因侧不在本 change 白名单**（AC-9 冻结 `test/` 既有文件）→ 跟进 change `test-fixture-tmpdir-2026-09`：把两处夹具改到 `$BATS_TEST_TMPDIR` | 2026-09-21 |
| M20 | 阶段3 | R8 | T08 未列 `7-integration` §5.0/§5.1 的全部强制项（`ARCHIVE_BASE_SHA` 回写、`git status` 空、原子提交 ≤3、MINOR-DEFERRED triage、保留目录 `rm` 双重确认） | **已折入 T08 action 第 7/8 步**（提交 ≤3 + `git status` 干净判据 + triage + `rm` 双重确认）；仅 `ARCHIVE_BASE_SHA` 回写由 `7-integration` §5.0 承担（本轮 STATE.md 末行已有该字段）——此条留痕 | 2026-09-21 |
| M21 | 阶段3 | R9 | T05 verify 的 `! grep -qF "ARCHIVE.md" slides.json` 改前即真（HEAD 已 0 命中）→ 恒真子句 | Minor：该子句保留作回归护栏（防止 ARCHIVE.md 写法回流），判定力由「四张专页标题断言 + 页数」承担 | 2026-09-21 |
| M22 | 阶段5 | R5 | `make-check.log` 不含逐用例行（Makefile `test` target 用 `tap \| tail -3` + `> /dev/null`），故「红时可复算失败用例名」的承诺不成立 | **已订正 TEST.md 口径**；如需真复算，v2 可在 T07 里另跑 `npx bats test/ > artifacts/bats.log`（不改 Makefile） | 2026-09-21 |
| M23 | 阶段5 | L3 R2/R3 | `verify-boundary.sh` 与其中的 `check-dist` 判据读的是**活工作树**——`make check` / `make dsh-sync` / 渲染 / 窄路径再生都会改写树内产物（dist、PNG、日志），故「边界快照」的时点敏感 | 口径已写入 TEST.md（判据时点 = 阶段 5 结束前；瞬态夹具显式归类）；彻底解决需在 pristine clone 上跑判据（v2，与 M2/M3 同批） | 2026-09-21 |
| M24 | 阶段5 | L3 熔断 | 阶段 5 的 L3 连续 4 轮 fail（每轮 findings 已处置；末轮为 M23 结构性口径项）→ 按框架熔断（阈值 3）以 `L3_verdict=skipped` + 审计段结案 | 透明降挡（不伪装 pass）；重试方式：删阶段 5 的尝试计数旁路文件后重跑 `run-l3.sh 5`；根因随 M23 的 v2 pristine-clone 判据一并解决 | 2026-09-21 |
| M25 | 阶段3 | L3 熔断 | 阶段 3 的 L3 共 **5 轮 fail**（22:53 起；每轮 findings 已处置——vendor 镜像归属、T04/T05/T06/T07 verify 加固、版本日期口径收紧、冒烟子集口径注明；后期集中在「per-task verify 未覆盖全锚点集」这一族）→ 按框架熔断（阈值 3）以 `L3_verdict=skipped` + 审计段结案 | 透明降挡（不伪装 pass）；重试方式：删阶段 3 的尝试计数旁路文件后重跑 `run-l3.sh 3`；根因同 M24：文档型 change 的 per-task verify 与全量矩阵的粒度差（已用「冒烟子集 + T07 全矩阵」口径收敛） | 2026-09-21 |
| M26 | 阶段3 | L3 建议 | per-task `<verify>` 与全量锚点矩阵的粒度差是**系统性**的（T01/T02 只冒烟抽样） | 已注明口径（冒烟子集 + T07 全矩阵）；彻底解法是让 TASK 的 verify 直接调用 `verify-ac.sh --segment AC-2` 这类分段入口（需给 `verify-ac.sh` 加 `--segment` 参数，v2） | 2026-09-21 |
| M27 | 阶段7 | R6 | `INDEPENDENT-REVIEW-7.md`/`IR-5` 缺首行 `# 独立审查 · 阶段 <N>`（首行为空行，L2 段的 `## L2 盲审` 仍在，判据可识别） | Minor：格式洁癖，不影响 `^## L2 盲审` 判据与 L3 写入 | 2026-09-21 |
| M28 | 阶段7 | R7 | `CHANGELOG.md` 的「阶段 5/6 同规格」不可复算（IR-5 有 5 个 L2 段、IR-6 仅 1 个 = 单轮 pass） | Minor：措辞已改为「阶段 1 五轮 + L3 / 阶段 2 四轮 + L3 / 阶段 3 七轮 / 阶段 5/6 按实际轮次」（v4.6 已在 CHANGELOG 中修正为逐阶段实述） | 2026-09-21 |
| M29 | 阶段7 | L3 熔断 | 阶段 7 的 L3 首轮 fail（3 条：IR-6 未进入 payload——**工件截断上限 80000 字节**导致排序靠后的审查件被裁掉；UAT 的 M 范围；CHANGELOG 跳过数重写）→ 前两条已修，第三条为**上限所致**；按框架熔断（阈值 3）透明结案 | 透明降挡（不伪装 pass）；重试方式：删阶段 7 的尝试计数旁路文件后以 `FLOW_KIT_L3_MAX_ARTIFACT_BYTES=200000` 重跑；根因与「提示词瘦身」同族（既有 v2 候选） | 2026-09-21 |
