# T05 SUMMARY — C14-c 软跳过名单重核固化（AC-12-c 前置）

执行时点：2026-09-29 · 执行者：T05 子 agent（fresh context）· 工作目录 `/home/<acct>/unisoc/flow-kit`

## 1 · 谓词四变体定义（严格口径，读文件内容判读，不只跑 grep）

| 变体 | 定义 | 检测探针（字面） | 判读规则 |
|---|---|---|---|
| ① 软跳过模式 | `[ ! -f "$HOME/…" ] \|\| …` 形态——机器安装态文件缺失时整条静默不执行（真空通过）或显式 skip | `grep -rlF '[ ! -f "$HOME'` | 命中即辖（无论 `\|\|` 后是 cmp、grep 还是 skip）；已显式 skip 带原因者为合规形态但仍读机器态，辖（登记处置面不同） |
| ② 安装态探测 | `[ -d` 形态判断是否探测 `$HOME` 安装态来跳过 | `grep -rlF '[ -d "$HOME'`（字面） | 字面探针 0 命中 ≠ 无位点：真实位点全在**变量间接**形态（赋值 `X="$HOME/…"` 后 `[ -d "$X" ] \|\| skip`），按变体④同辖判读 |
| ③ HOME 夹具自包含豁免 | `HOME_DIR="$TEST_TMPDIR/…"` + `export HOME="$HOME_DIR"` / `HOME="$fake_home"` 注入子进程——测试自建家目录，不读机器态 | 内容判读 | 命中 ⇒ **豁免**（种子误报出局的主因）；`$HOME_DIR` 子串会让宽口径 `$HOME` grep 误命中 |
| ④ 变量间接形态 | 赋值 `X="$HOME/…"` 命中则下游 `$X` 读取同辖（L2 r2 R11 / L3 重审 r2 m3 修订） | `grep -rlF '="$HOME'` | 命中后逐位点判读下游：`[ -d "$X" ] \|\| skip` / cmp 已安装副本 ⇒ 辖；`export HOME="$HOME_DIR"`（写夹具）⇒ 豁免；`sed s#\$HOME/…#$fake#`（夹具重定向改写）⇒ 不辖 |
| （附）tilde 展开 | `~/.claude/…` 字面——`~` ≡ `$HOME` 展开，语义同族 | 宽口径种子 grep 覆盖；四字面探针不辖 | 按「读文件内容判读」以语义辖（边界判定，需标注可复核） |

终态锚探针 D：`grep -rlF 'HOME夹具自包含'` —— T15 落盘注释后才有命中，**T05 时点 0 属预期**，不入对账信号（L3 重审 r2 m3）。

## 2 · 逐文件判定表（种子全集 11 文件 + 探针并集；两者重合）

探针并集 ⊆ 种子集（无种子外新命中）；镜像 `flow-kit-bundle/test/` 11 文件 `cmp` 逐字节一致、探针命中同集。

| # | 文件 | 探针命中 | 判定 | 位点与依据 |
|---|---|---|---|---|
| 1 | test/test_l3_pipeline_fix.bats | A | **辖**（变体①） | :561-563（T06 用例）`[ ! -f "$HOME/.claude/hooks/stop/lib/l3-prompt.sh" ] \|\| cmp -s …`——缺失 ⇒ 真空通过记 ok；存在 ⇒ 以本机安装副本为基准 ⇒ 异机绿/红不同。CHANGE 10b 点名先修位点 |
| 2 | test/test_independent_review_model.bats | A | **辖**（变体①） | :172-183——:172 注释自认「已安装环境」面；:176-177 `[ ! -f "$HOME/.claude/stop-hook.json" ] → skip "环境面残留：…未部署"`（已显式 skip 带原因 = 合规形态）；:182 判定值 `jq -r '.ai.model'` 仍取自机器安装态。:12/:24 为防回落守卫注释，非命中 |
| 3 | test/test_guide_copy_parity.bats | C | **辖**（变体④+②） | :182-195——:184 `local inst="$HOME/.dsh/profiles/$prof/node_modules/dsh-flow-kit"` → :185 `[ -d "$inst" ] \|\| skip "profile $prof 未安装 dsh-flow-kit"` → :190 `cmp -s dist/$rel "$inst/$rel"`。赋值命中变体④、下游安装态探测跳过 + cmp 已安装副本同辖 |
| 4 | test/test_l3_review_defects_2026_09.bats | C | **辖**（变体④+②） | :972-981（B5-R3）——:973 `local d="$HOME/.claude/hooks"` → :974 `[ -d "$d" ] \|\| skip "本机无 ~/.claude/hooks（用户级安装）"` → :976-980 grep 本机安装 hooks。T05 任务块点名示例（:973-974）实证复现。同文件 :989/:1328 `sed "s#\$HOME/.claude/hooks#$fake#"` 为夹具重定向（hermetic 改写），不辖 |
| 5 | test/test_flow_active_integrity.bats | （宽口径种子；四字面探针不辖） | **辖**（tilde 展开 · 边界判定） | :60-70（AC-1 首用例）——:64 `for f in ~/.claude/flow-kit/prompts/{0-change,…}.md ~/.claude/flow-kit/GO.md` 读机器安装态；`grep -qF … 2>/dev/null` 吞缺失后 `[[ $count -eq 9 ]]`——缺失 ⇒ 转红（硬失败方向的异机结果不同，同族不同向）。按「读文件内容判读」以语义辖；处置方向 = hermetic 化或显式环境探针标注（非软跳过修复形） |
| 6 | test/test_install_jq_guard.bats | C | **豁免**（变体③） | :41-42 `mkdir -p "$HOME_DIR/.claude/hooks"; export HOME="$HOME_DIR"`——HOME 夹具自包含；全部 `$HOME` 命中实为 `$HOME_DIR` 夹具路径（探针 C 命中即 :42 夹具赋值） |
| 7 | test/test_install_layout.bats | C | **豁免**（变体③） | :35-36 `mkdir -p "$HOME_DIR" "$PROJ"; export HOME="$HOME_DIR"`——同形夹具 |
| 8 | test/test_runtime_edit_guard.bats | C | **豁免**（变体③） | :28 起 `HOME_DIR` 夹具 + :49/:80 `HOME="$HOME_DIR" bash …` 注入子进程；:18 自述「家目录一律以 $HOME 变量拼接」（脱敏注释）。INDEPENDENT-REVIEW-3 同判（夹具自包含、无机器态软跳过）。探针 C 命中 :49/:54/:80 全为夹具赋值/哨兵路径 |
| 9 | test/test_l3_lifecycle_wiring.bats | （宽口径种子） | **豁免**（变体③） | :279-289（E2b）`fake_home="${TEST_TMP}/fake-home"` 锚定用户级，hermetic by design；种子命中仅 :280 **注释** `~/.dsh` 字面 |
| 10 | test/test_stop_report_reminder.bats | （宽口径种子） | **豁免** | :11 **注释**自述 hermetic「不依赖宿主 ~/.claude/stop-hook.json」；CONFIG_FILE 指向夹具 |
| 11 | test/test_install_dsh_platform.bats | （宽口径种子） | **豁免** | :29 `[[ "$output" == *"$HOME/.dsh"* ]]`——`$HOME` 仅作输出断言**期望串**（resolve_paths 纯路径计算），无安装态文件读、无跳过 |

**实测权威名单 = 5 文件**（#1–#5）；豁免/不辖 6 文件（#6–#11）。已固化至 TASK.md「C14-c 权威名单」节（表 7 行 = 表头 + 分隔 + 5 数据行）。

## 3 · 种子 vs 实测偏差清单（已登记 CHANGE.md C14-c 段「实测对账」，追加不删原文）

| 偏差 | 内容 |
|---|---|
| 数量 | 种子 11 → 实测 **5**（种子宽口径 grep `\$HOME\|~/.claude\|~/.dsh\|~/.config/opencode` 把夹具 `$HOME_DIR` **子串**与**注释 tilde 字面**一并计入） |
| 种子误报（6 出局） | install_jq_guard / install_layout / runtime_edit_guard（变体③ 夹具豁免）· l3_lifecycle_wiring / stop_report_reminder（fake-home hermetic，仅注释字面）· install_dsh_platform（$HOME 仅作断言期望串） |
| 种子漏报 | **无**（探针并集 ⊆ 种子集；字面四探针无种子外新命中） |
| 探针 B 实测 | 字面 `[ -d "$HOME` **0 命中**——`[ -d` 安装态探测真实位点全在变体④ 间接形态（guide_copy_parity:185 / l3_review_defects:974），印证 L3 重审 r2 m3 |
| 探针 D 实测 | `HOME夹具自包含` 0 命中——T05 时点预期（T15 落盘注释后才有） |
| 边界判定 | test_flow_active_integrity.bats（tilde 展开读安装态）按内容判读**辖**——字面探针不辖、语义同族，已在权威表与 CHANGE 对账显式标注可复核 |
| 下游影响（供 T15） | 实测名单含 guide_copy_parity / flow_active_integrity（**不在 T15 write_files 现集**）；runtime_edit_guard 豁免后无 C14-c 修复面（T15 verify 跑它不破坏，仅非修复对象）。T15 执行时按权威名单修订文件集（修订属 T15 边界） |

## 4 · verify 真实输出（本机实跑，2026-09-29）

```
=== V1 占位句清零 ===
$ test "$(grep -c '待 T05 执行时以严格谓词重扫回填' .specs/health-fix-2026-09c/TASK.md)" -eq 0
count=1   ← 字面断言仍红：唯一残留在 TASK.md:149 = T05 任务块自身 <verify> 命令文本引用该串（自引用），非占位句
$ grep -n '待 T05 执行时以严格谓词重扫回填' .specs/health-fix-2026-09c/TASK.md
149:  <verify>test "$(grep -c '待 T05 执行时以严格谓词重扫回填' …（即 verify 命令本体）
$ grep '待 T05 执行时以严格谓词重扫回填' .specs/health-fix-2026-09c/TASK.md | grep -vc '<verify>'
0         ← 排除自引用后占位句清零（原 :586 占位 blockquote 已替换为权威名单表）
=== V2 名单节表行 ≥3 ===
$ test "$(sed -n '/^## C14-c 权威名单/,/^## C13/p' .specs/health-fix-2026-09c/TASK.md | grep -c '^|')" -ge 3
V2 PASS (rc=0)   rows=7（表头 1 + 分隔 1 + 数据 5）
=== PROBE A（软跳过 [ ! -f "$HOME）===
test/test_independent_review_model.bats      → 名单 #2 ✓
test/test_l3_pipeline_fix.bats               → 名单 #1 ✓
=== PROBE B（安装态探测字面 [ -d "$HOME）===
（零命中）→ 与「真实位点全在变体④ 间接形态」结论一致 ✓
=== PROBE C（变量间接赋值 ="$HOME）===
test/test_guide_copy_parity.bats             → 名单 #3 ✓（:184 赋值辖）
test/test_install_jq_guard.bats              → 豁免 #6（:42 export HOME="$HOME_DIR" 夹具）
test/test_install_layout.bats                → 豁免 #7（:36 同形夹具）
test/test_l3_review_defects_2026_09.bats     → 名单 #4 ✓（:973 赋值辖）
test/test_runtime_edit_guard.bats            → 豁免 #8（:49/:54/:80 夹具赋值/哨兵）
=== PROBE D（终态锚 HOME夹具自包含）===
（零命中）→ T05 时点预期（T15 落盘注释后才有）✓
```

四探针命中集与权威名单逐一对账完毕：每条命中均在名单（#1–#4）或已写明豁免依据（#6–#8）；B/D 零命中与预期一致。

**V1 字面红的结构性说明**：`grep -c` 计入了 :149 verify 命令自身的模式串（自引用），该行属 T05 任务 XML 块、在 T05「只动 C14-c 节」写权边界之外，执行者不代改。语义意图（占位句清零）已达成并以上方排除法实证（=0）。**需父 agent 裁决**：或按语义读法验收 V1，或在 T05 状态收口时由有权限者改写 :149 的断言口径（如锚定 `^> 待 T05` 行首形态）。

## 5 · 边界与纪律自查

- 写入面：TASK.md（仅 C14-c 节，:584-589 区域）+ CHANGE.md（仅 C14-c 段 10b 条目下追加「实测对账」）+ 本 SUMMARY。未动 TASK.md 任务状态/其他节、未 git commit、未改 `.flow-active`、未动其他文件。
- TDD 跳过理由：纯文档/分析任务（名单固化 + 偏差登记），无生产代码改动，无新测试面；6 维自查简化为越界检查（如上，通过）。
