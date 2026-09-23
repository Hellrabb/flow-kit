# T22 空基线双态自检固化 — SUMMARY

## 结论
空基线双态自检固化为 `check-path-privacy.sh` 内联断言与注释（state a 空清单⇒合法 rc=0、state b 清单外命中⇒rc=1），逻辑零改动、退出码二值不变。

## 交付物
| 交付物 | 路径 | sha256 | 行数 before→after |
|---|---|---|---|
| 门禁脚本（固化空基线双态断言 + 注释） | `flow-kit-bundle/flow-kit/reference/check-path-privacy.sh` | `50e25eea39a491271496fc38cbe8468adbd4c1b93f3ecb07d61314448b7b3fa5` | 297 → 325（+28 行纯注释，无逻辑改动） |
| 本 SUMMARY | `.specs/health-fix-2026-09b/T22-SUMMARY.md` | 见 git blob | — |
| TASK.md T22 状态翻转 | `.specs/health-fix-2026-09b/TASK.md` | 仅 `status="pending"`→`status="done"` 一属性 | — |

固化形式（3 处注释块，零可执行代码改动）：
1. 文件头 docstring（第 9-25 行）：完整双态契约 + fix 原文来源（INDEPENDENT-REVIEW-2 末段 L3 #4 major②）+ 双态判别力说明。
2. `ALLOWLIST_COUNT` 统计处（第 126-130 行）：fixate「空基线（文件存在、0 条）」与「文件缺失（fail-closed rc=1）」的严格区分 —— 空基线继续扫描、不跳过、不报错。
3. 终端出口处（第 317-322 行）：fixate state (a) rc=0 与 state (b) rc=1 两个出口点。

## 判据实跑（T22 verify block，逐字实跑）

提取命令（与指令一致，路径以 `<repo>` 代指仓库根）：
```
python3 -c "import re;s=open('<repo>/.specs/health-fix-2026-09b/TASK.md',encoding='utf-8').read();b=re.search(r'<task id=\"T22\".*?</task>',s,re.S).group(0);v=re.search(r'\n  <verify>\n(.*?)\n  </verify>',b,re.S).group(1);open('/tmp/t22v.sh','w',encoding='utf-8').write('\n'.join(l[4:] if l.startswith('    ') else l for l in v.split('\n'))+'\n')"
```
重提取后 `cmp -s /tmp/t22v.sh /tmp/vblocks/v_T22.sh` ⇒ `IDENTICAL`（字节一致）。

实跑：
```
$ bash /tmp/t22v.sh; echo "rc=$?"
rc=0
```
rc=0（健康态：自报「允许清单 N 条」、`清单外命中 0 条`；真实形态探针（`/home/''zz-path-pr''obe/` 拼接构造）⇒ rc=1 并被抓住；`/home/<user>/` 占位符形态 ⇒ rc=0；同行真名+占位（L-133 排除粒度）⇒ rc=1 且 `file:line` 归因含 `CONTEXT.md`；所有分支均经备份+trap 恢复，末行 `cmp -s .specs/CONTEXT.md /tmp/l133-bak` 通过 ⇒ tracked 文件无残留）。

判据实跑后 `git status --short` 确认 `.specs/CONTEXT.md` 未被修改（无 `M`）。

## 门禁输出（六道，逐字 rc）
| 门禁 | rc | 关键输出 |
|---|---|---|
| `make test` | 0 | 973 ok / 0 not ok / 1 skip（基线一致） |
| `make lint` | 0 | shellcheck clean |
| `make check-hooks-sync` | 0 | 副本一致性无漂移 |
| `bash sync-hooks.sh --check` | 0 | 镜像面无漂移、无 orphan |
| `make check-path-privacy` | 0 | `允许清单 0 条`、`清单外命中 0 条`、`✅ 清单外命中 0 条` |
| `bash /tmp/vblocks/v_T21.sh`（T21 回归） | 0 | 读序双态 fail-closed 不破（两份清单皆缺 ⇒ rc=1 且指名路径；清单在位 ⇒ rc=0） |

## 判别力与反例
| 分支 | 期望 | 修复前（T22 前） | 修复后（T22 后） |
|---|---|---|---|
| 空基线健康态（清单 0 条、无泄漏） | rc=0、自报「允许清单 0 条」「清单外命中 0 条」 | 行为正确但未固化（无注释、无断言文本，违反 INDEPENDENT-REVIEW-2 major② fix「需补双态自检断言文本」） | rc=0 + 注释固化 state (a)；verify 逐字实跑通过 |
| 真实形态探针（拼接构造 `/home/''zz-path-pr''obe/`） | rc=1 | 行为正确（T17 已实现扫描+清单外命中 rc=1） | rc=1 不变；注释固化 state (b) |
| `/home/<user>/` 占位符形态 | rc=0 | 行为正确（`<` 不在字符类内） | rc=0 不变 |
| 同行真名+占位（L-133 排除粒度） | rc=1 + `file:line` 归因 | 行为正确（T17 修复轮 1+2 已实现逐命中占位符判定） | rc=1 + 归因 `CONTEXT.md` 不变 |
| 空清单被误当错误 | 应 rc=0 | 不发生（脚本逻辑正确） | 注释显式禁止（state a 注释：「空清单既不得被当作错误，也不得静默跳过扫描」） |
| 空清单被静默跳过扫描 | 应仍扫描、泄漏⇒rc=1 | 不发生（扫描循环不依赖 ALLOWLIST_COUNT） | 注释显式禁止（同上） |

修复前「行为正确但未固化」= INDEPENDENT-REVIEW-2 major② 判定的缺口：「工件没有给出替代断言的文本」「若没有双态自检，门禁可能在空清单下永远绿或永远红」。T22 的修复 = 把既有正确行为固化为可读断言文本与注释，补齐该缺口。

## 6 维自查
- **正确性**：脚本逻辑零改动（diff 纯注释）；`bash -n` clean；退出码二值（`exit 0`/`exit 1`，无 rc=3/SKIP）；T21 读序 fail-closed 未碰（`exit 1` 仍在文件缺失分支）。
- **完整性**：三处固化点覆盖双态契约的完整文本（头 docstring）+ 两个出口点（ALLOWLIST_COUNT 区分空/缺失、终端 exit 0/exit 1）；verify block 逐字实跑 rc=0。
- **回归**：`make test` 973/0/1 不变；T21 verify rc=0 不破；`make check-path-privacy` rc=0；`make check-hooks-sync`/`sync-hooks.sh --check` rc=0。
- **可维护性**：注释标注来源（INDEPENDENT-REVIEW-2 major② fix、T22、health-fix-2026-09b、2026-09-23）；后续维护者可据注释理解空基线为何合法（前提=工件已脱敏）。
- **安全与隐私**：本 SUMMARY 不含 live `/home/<name>/` 字面（探针以相邻单引号段 `/home/''zz-path-pr''obe/` 呈现，L-137）；CONTEXT.md 探针由 verify block 的 trap+cmp 保证逐字节复原。
- **文档一致性**：固化文本与 INDEPENDENT-REVIEW-2 major② fix 原文（line 1931「沙箱注入 `/home/<acct>/x` 必须 rc=1、`/home/<user>/` 必须 rc=0」）语义一致；与 DESIGN D10 三态实测、REQUIREMENT AC-6② N8 订正（量词 `[0-9]+`）一致。

## 遗留
无。T22 写面仅 `check-path-privacy.sh` + 本 SUMMARY + TASK.md 状态翻转，均已完成。T23（常设清单自身校验）depends_on T22，可在本 task 落定后开工。
