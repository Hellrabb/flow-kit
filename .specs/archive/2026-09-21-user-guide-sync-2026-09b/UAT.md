# UAT — user-guide-sync-2026-09b

- **Change ID**: user-guide-sync-2026-09b
- **执行者**: 主 agent（脚本部分实跑）+ 待用户确认（人工部分）
- **关联**: `@.specs/user-guide-sync-2026-09b/{REQUIREMENT,TEST,DEV-SUMMARY}.md`

---

## A. 可脚本化 UAT（已实跑，rc 与输出见 TEST.md）

| # | 步骤 | 命令 | 期望 | 实测（含 rc） |
|---|---|---|---|---|
| UAT-1 | 四副本一致 | `md5sum` 四路径 \| `awk '{print $1}'` \| `sort -u` \| `wc -l` | `1` | ✅ rc=0；md5 唯一值 1 |
| UAT-2 | 打包件新鲜 | `bash package-dsh-plugin.sh --check` | rc=0 | ✅ `dist 与源一致` |
| UAT-3 | 已安装插件同步 | `make dsh-sync` + `diff -rq dist ↔ 已装 profile` | 差异 0 | ✅ rc=0 |
| UAT-4 | AC 断言矩阵 | `bash .specs/user-guide-sync-2026-09b/verify-ac.sh` | 失败 0 | ✅ rc=0；计数见 TEST.md §2（**权威输出**，本表不复制数字） |
| UAT-5 | 母本一致性 | `python3 .specs/user-guide-sync-2026-09b/check-appendix-superset.py` | 缺失 0 | ✅ rc=0；格数/跳过/缺失见 TEST.md §2 的实时输出 |
| UAT-6 | 改动边界 | `bash .specs/user-guide-sync-2026-09b/verify-boundary.sh` | rc=0 | ✅ rc=0（禁动域 0） |
| UAT-7 | deck 成品断言 | `python3 .specs/user-guide-deck-gen/deck_checks.py` | `deck_checks OK: 24 pages` | ✅ |
| UAT-8 | 副本守护 | `npx bats test/test_guide_copy_parity.bats` | 8/8 ok | ✅ |
| UAT-9 | 全量门禁 | `make check` | 六门全绿 rc=0 | ✅ |

---

## B. 人工 UAT（需用户确认）

- [ ] **UAT-B1** 打开 `flow-kit-用户指南.pptx`，翻到 **21–24 页**：
  - 21 页写明 `--global` **不含 hooks**、`--project` 配置仍走用户级、`make dsh-sync`（`DSH_PROFILE` 可覆盖）
  - 22 页写明 L3 凭证三 Path、**缺凭证会死锁**、熔断为**自动 bypass**、工件上限 **80000 字节**（÷3 ≈ 2.7 万汉字）
  - 23 页列出 `make check` 六门与三个单点命令
  - 24 页写明四副本一致性、同步顺序、版本口径 2026-09-21
- [ ] **UAT-B2** 通读 `FLOW-KIT-用户指南.md` 的 §2（安装）、§7（Stop Hook）、§12（文件结构）三处，确认与你的实际操作经验一致（尤其：配置只在用户级、`--global` 不装 hooks、LESSONS 是单文件）。
- [ ] **UAT-B3** 确认 README 的两处改动（安装示例 + dsh 插件段）符合你的预期口径。
- [ ] **UAT-B4** 确认 MINOR-DEFERRED（**M1–M28**，现行全部条目）里没有你认为**必须本轮修**的项：

| # | 摘要 |
|---|---|
| M1 | AC-7 的「溢出/缺字」目视判据无自动检测 |
| M2 | `deck_checks.py` 未接进 `make check` |
| M3 | 副本守护未提升为独立门禁 target |
| M4 | T02 变更面超 200 行软线（文档型任务的已知代价） |
| M5 | CHANGE.md「三处副本」措辞与 AC-5「四份」不一致 |
| M6 | deck-gen README 封面行裸 `\|` 的破表隐患（本轮已顺手处理） |
| M7 | 渲染字体为替代字体（本机无宋体/Times New Roman） |
| M8 | 「三轮审查」在 3 个**范围外**载体（`skills/flow-review/SKILL.md`、`flow-kit/README.md`、`templates/REVIEW.md:73`）仍存留 → 跟进 change `phase6-review-wording-2026-09` |
| M9 | D21「已废弃说明句」豁免口径未定义（无现存违规） |
| M10 | DESIGN §7 证据链引用不实（已修，留痕） |
| M17–M20 | 计数漂移自省 · 断言矩阵缺口 · 既有 bats 夹具写进仓库（根因） · T08 的 §5 强制项 |

---

## C. 结论

- 脚本化部分 **9/9 通过**（证据见 `TEST.md`）。
- 人工部分待用户确认；确认后进入阶段 6（REVIEW）与阶段 7（INTEGRATION）。
