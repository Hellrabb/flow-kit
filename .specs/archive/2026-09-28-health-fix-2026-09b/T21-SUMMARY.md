# T21-SUMMARY — R8 落地 + AC-6 基线冻结：常设权威清单 + change 副本 + 读序双态

- change-id: `health-fix-2026-09b`
- task: T21（Wave 5，parallel，model-tier `top`）
- depends_on: T17（check-path-privacy.sh 实现）, T18（Makefile target）
- status: done

## 结论

T21 已完成 D10′③ 四步冻结顺序，落档常设权威副本 + change 副本双份允许清单（合法的「脱敏背书的空清单」），R8 读序双态（清单在位 rc=0 / 两者皆缺 fail-closed rc=1 指名路径）均经实跑验证。

## 交付物

| 路径 | 用途 | sha256 |
|---|---|---|
| `flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt` | 常设权威副本（不受 change 归档影响，R8 定级裁决 · ADR-028 决策 1）。check-path-privacy.sh 读序首选源。 | `c491ceeacbd3fc6ac041d019cc7e612619f27d9d8c757d5ee3230e119ecedf0f` |
| `.specs/health-fix-2026-09b/path-privacy-allowlist.txt` | change 副本（与本 change 同生命周期，归档后失效，R8 定级裁决）。读序次选源。 | `72ff005cca6aa642d2d1f435a3c0783f6eee8b2b3f7c8f6cb0377e3a9ab4326d` |

两份清单当前有效条目数均为 **0**（comment-only）。空清单由 T13 工件脱敏背书（tracked 文件中真实账号路径 = 0），非弱化判据所致。

## 判据实跑

### 提取的 `<verify>` 块（逐字，已剥 4 空格 XML 缩进）

```bash
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
```

### 完整输出 + rc

```
🔍 make check-path-privacy: 路径隐私（允许清单外命中 / fail-closed）检查 ...
🔍 check-path-privacy: 扫描本机绝对路径前缀泄漏（PAT=/home/[a-z_][a-z0-9_-]*/）
   扫描面: 工作树
   允许清单来源: flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt
   允许清单 0 条
   命中合计 0 条（含占位符排除后）
   清单外命中 0 条
✅ 清单外命中 0 条（允许清单内残留只暴露不阻塞）
自报=0 / 常设有效行=0
rc=0
```

**rc=0** — 全部断言通过：两份清单在位、`make check-path-privacy` rc=0、自报条数(0) = 落档有效行(0)、打印含 `清单外命中 0 条`、两者皆缺 fail-closed rc=1 且报文含 `path-privacy-allowlist.txt`。

## 门禁输出

| 门禁 | rc | 关键输出 |
|---|---|---|
| `make test` | 0 | 973 ok / 0 not ok / 1 skip（baseline 匹配） |
| `make lint` | 0 | `✅ shellcheck: no errors found` |
| `make check-hooks-sync` | 0 | `✅ hooks 副本一致（漂移 0）`（48 镜像） |
| `bash sync-hooks.sh --check` | 0 | `✅ hooks 副本一致（漂移 0）` |
| `make check-path-privacy` | 0 | `允许清单 0 条` / `清单外命中 0 条`（清单在位态） |

## 判别力 / 反例

实跑中实际触发的失败分支（逐条记录）：

1. **both-missing fail-closed（rc=1）** — T21 `<verify>` 块通过 `trap` 移走两份清单后直接跑 `check-path-privacy.sh`；独立复跑（复制到 `/tmp` 后移走）确认：rc=1，报文 `🔴 允许清单缺失（fail-closed，不得当空清单放行）：` + 两路径 + `扫描面: 工作树`，报文含 `path-privacy-allowlist.txt`。此为 pre-T21 既有态（baseline fact），T21 落档后仍保持。
2. **self-report-count vs filed-line-count 一致性** — `printed=0` 与 `filed=$(grep -cvE '^[[:space:]]*(#|$)' "$A")=0` 相等（均 0），断言通过；未触发 mismatch 分支（mismatch 会 rc=1 退出）。
3. **`清单外命中` 非零态** — 未触发（当前 `清单外命中 0 条`）。判别力来源：scanner 对 tracked 内容跑 PAT + 占位符排除 + 自排除后命中合计 = 0；若插入 REQUIREMENT AC-6① 的「相邻单引号拼接」探针形态（本文件不复现其字面量，以免被自身门禁计为清单外命中；该形态在 REQUIREMENT 中以源文本安全写法给出）会变成非零命中并 rc=1（由 T19 e2e 在 fixture 层验证）。

> 修复轮 1 记录（fix_rounds=1）：首次交付 `f315b64` 的 T21-SUMMARY.md:75 含合成探针字面量，提交变 tracked 后被自身门禁计为 `清单外命中 1 条`。根因为判据运行时机——跑判据时该文件未 tracked ⇒ 扫描面隐形；`git commit` 扩大扫描面那一刻暴露。修复：改为不落字面量的描述。新纪律 L-137：扫描面相关判据必须在 `git add` 新产物之后再跑。
4. **file-missing-from-standing-path（仅常设缺，change 在位）** — 未单独触发；R8 读序 = 常设 > change，常设缺则读 change（script `:93-95`）。此分支在 T21 verify 块未单独断言，但 R8 读序逻辑由 both-missing 分支间接覆盖（both-missing 是读序的 fail-closed 兜底）。
5. **file-missing-from-change-copy（仅 change 缺，常设在位）** — 未单独触发；常设在位即首选常设，change 缺不影响。同上由读序逻辑覆盖。

## 6 维自查

- **正确性**：两份清单格式合规（comment-only，`grep -cvE '^[[:space:]]*(#|$)'` = 0 有效行）；读序双态（在位 rc=0 / 皆缺 rc=1 指名路径）实跑通过；自报条数 = 落档有效行 = 0；`清单外命中 0 条` 实跑成立。空清单由 T13 脱敏背书（独立 grep 排除 INDEPENDENT-REVIEW-{1,2,3}.md 后 tracked 真实账号路径 = 0），非弱化判据所致。
- **完整性**：D10′③ 四步全部执行（① T13 脱敏确认 → ② git add 两份清单 → ③ 复扫断言非排除命中=0 → ④ 冻结落档）；两份清单均已落档；R3 棘轮（只降不升）在清单头注释中声明；R8 读序双态均已验证。
- **回归**：make test 973 ok / 0 not ok / 1 skip（与 baseline 完全匹配）；make lint / check-hooks-sync / sync-hooks --check 均 rc=0；check-path-privacy 在 both-missing 态保持 rc=1（pre-T21 既有态未被破坏）。
- **可维护性**：清单头注释说明格式、读序、棘轮规则、T13 脱敏背书来源；新增审查档须显式追加精确路径到 SELF_EXCLUDE（禁宽通配，D10′②）；change 副本注释说明归档后失效、常设副本为唯一长期源。
- **安全与隐私**：本 SUMMARY 及两份清单均不含真实本地账号路径（`/home/<acct>/` 占位）；未写入任何会变成新隐私命中的字面扫描目标；commit message 不含真实账号路径。审查档中的真实账号路径由 SELF_EXCLUDE 逐条精确路径豁免（D10′②），非宽通配。
- **文档一致性**：T21 status 已由 `pending` 翻为 `done`（TASK.md :902 单属性单行）；DESIGN R8（:372）/ D10′（:217, :476）/ REQUIREMENT AC-6② 的读序双态、四步冻结顺序、空清单合法性均与实跑结果一致；T13-SUMMARY（脱敏完成）/ T17-SUMMARY（check-path-privacy.sh 实现）的状态与 T21 前置依赖匹配。

## 遗留

无 T21 自身遗留。下游依赖：
- T22（empty-baseline self-check，depends_on T21）：将写 check-path-privacy.sh 的空基线自检。
- T23（standing-allowlist self-validation，depends_on T21,T22）：将写 ADR-028 + check-path-privacy.sh + allowlist（受控临时）+ CONTEXT.md。
- T19（AC-3 e2e 四表推送拦截，depends_on T11,T12,T16,T17,T18,T21,T22,T23,T26）：fixture 须复制真实 gate 脚本 + **冻结的允许清单**（本 T21 产物）。
