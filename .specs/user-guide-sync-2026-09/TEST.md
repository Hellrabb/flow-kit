# TEST: 用户指南与用户指南 PPT 同步至 2026-09 功能集

- **Change ID**: user-guide-sync-2026-09
- **关联**: `@.specs/user-guide-sync-2026-09/REQUIREMENT.md`、`DESIGN.md`、`TASK.md`

---

## 测试环境（本机实测基线）

- python-pptx 1.0.2 · LibreOffice 24.2.7.2 headless · graphviz 2.43 · pdfinfo/pdftoppm（poppler）· bats via make test
- 分支 develop · pre-commit 每次提交自动跑 make test（770 bats）

## 断言矩阵（每条对应 REQUIREMENT AC）

| # | AC | 命令（在仓库根执行） | 期望 | 结果 |
|---|---|---|---|---|
| T1 | AC-1 | A1（head -5 版本行/URL/无其他 8 位日期） | 命中 | ✅ 2026-09-03 |
| T2 | AC-2 | A2 禁词扫描（MD 两份） | 0 命中 | ✅ |
| T3 | AC-3 | A3 子项（a-g + config 键 12 键双向相等 A3e-OK 12） | 全过 | ✅ |
| T4 | AC-4 | `cmp -s`（T05 同步后） | exit 0 | ✅ |
| T5 | AC-5 | build.py + deck_checks.py | 20 页断言全过 | ✅ deck_checks OK |
| T6 | AC-6 | soffice→pdf Pages=20 + 页 1/14/20 PNG 非空 | 通过 | ✅ |
| T7 | AC-7 | make test 全量（pre-commit 每提交执行） | 0 fail | ✅ ×7 次提交均绿（b4035ef→318a759） |
| T8 | AC-8 | 每启用阶段 INDEPENDENT-REVIEW-N.md L2/L3 | 见 REVIEW 记录 | ✅（1/2/3 已 pass；5/6/7 见 REVIEW.md） |
| T9 | AC-9 | 归档清单/STATE/CHANGELOG/git log | 见 INTEGRATION | ⏳ 阶段 7 执行 |

## A1 · AC-1 命令

```bash
head -5 FLOW-KIT-用户指南.md | grep -E '^> 版本: 2026-09-03'
head -5 FLOW-KIT-用户指南.md | grep -q 'github.com/hellrabbit/flow-kit/tree/develop'
test "$(head -5 FLOW-KIT-用户指南.md | grep -oE '20[0-9]{6}' | grep -vx '20260903' | wc -l)" = "0"
```

## A2 · AC-2 禁词扫描（范围 = 根与 bundle MD）

```bash
for f in FLOW-KIT-用户指南.md flow-kit-bundle/FLOW-KIT-用户指南.md; do
  for s in '20260713' '17 个模块' '三级优先级链' '三级链' '仅 Claude Code' '仅为 Claude Code' '只为 Claude Code'; do
    grep -c "$s" "$f" | grep -q '^0$' || { echo "BANNED $s in $f"; exit 1; }
  done
done
grep -n '只为 Claude Code' FLOW-KIT-用户指南.md | wc -l | grep -q '^0$'
echo A2-OK
```

> slides.json / pptx 抽取文本的同清单检查 = deck_checks.py（BANNED 同列表，已含）；TODO/待补扫描见 A7b。

## A3 · AC-3 子项（根与 bundle 两份各跑）

```bash
# a) dsh 平台条目
grep -q 'DeepSeek Harness' FLOW-KIT-用户指南.md && grep -q 'dsh-flow-kit' FLOW-KIT-用户指南.md
# b) dsh 安装命令
grep -q 'dsh plugin --profile' FLOW-KIT-用户指南.md
# c) model 五级链命令字段
grep -qF 'l2-default=' FLOW-KIT-用户指南.md && grep -qF 'l3-default=' FLOW-KIT-用户指南.md && grep -qF -- '--clear' FLOW-KIT-用户指南.md
# d) doctor correction 报告
grep -qF '.flow-active.correction' FLOW-KIT-用户指南.md && grep -q 'violations' FLOW-KIT-用户指南.md
# e) config 键列 12 键 == stop-hook.json modules（python 双向相等：取指南表格「模块（config 键）」列非 — 单元格）
python3 - <<'PY'
import json, re, sys
cfg = set(json.load(open('flow-kit-bundle/hooks/config/stop-hook.json'))['modules'])
rows = []
for line in open('FLOW-KIT-用户指南.md', encoding='utf-8'):
    if '|' not in line or 'config 键' in line: continue
    cells = [c.strip() for c in line.strip().strip('|').split('|')]
    if len(cells) >= 4 and cells[2] not in ('—', '', '模块（config 键）'):
        rows.append(cells[2])
got = set(rows)
assert got == cfg, (got ^ cfg)
print('A3e-OK', len(got))
PY
# f) 五级链字段与决策
grep -qF 'FLOW_KIT_L3_DEFAULT_MODEL' FLOW-KIT-用户指南.md && grep -q '显式配置永远压过默认级' FLOW-KIT-用户指南.md && grep -q 'L2/L3 模型解析链加入站点级默认 tier' .specs/CONTEXT.md
# g) CONTEXT 术语块
grep -q 'user-guide-sync-2026-09 追加' .specs/CONTEXT.md
echo A3-OK
```

## A4 · 渲染与文件断言（AC-5/6 实跑命令，2026-09-03 实测）

```bash
python3 .specs/user-guide-deck-gen/build.py > /tmp/t5-build.log 2>&1 && tail -1 /tmp/t5-build.log
python3 .specs/user-guide-deck-gen/deck_checks.py
soffice --headless --convert-to pdf --outdir /tmp/ppt-render flow-kit-用户指南.pptx
pdfinfo /tmp/ppt-render/flow-kit-用户指南.pdf | awk '/^Pages:/ {print $2}'   # 期望 20
pdftoppm -png -r 70 -f 1 -l 1 /tmp/ppt-render/flow-kit-用户指南.pdf /tmp/ppt-render/p1 && test -s /tmp/ppt-render/p1-01.png
pdftoppm -png -r 70 -f 14 -l 14 /tmp/ppt-render/flow-kit-用户指南.pdf /tmp/ppt-render/p14 && test -s /tmp/ppt-render/p14-14.png
pdftoppm -png -r 70 -f 20 -l 20 /tmp/ppt-render/flow-kit-用户指南.pdf /tmp/ppt-render/p20 && test -s /tmp/ppt-render/p20-20.png
echo A4-OK
```

## A7 · 回归与边界（AC-7）

```bash
make test 2>&1 | tail -3          # 期望 0 fail
# 白名单外变更 0 行（阶段 5 提交前执行）
git status --porcelain | awk '{print $2}' | grep -vE '^(FLOW-KIT-用户指南.md|flow-kit-bundle/FLOW-KIT-用户指南.md|flow-kit-用户指南.pptx|.specs/user-guide-deck-gen/|.specs/user-guide-sync-2026-09/|.specs/CONTEXT.md|.specs/STATE.md|.specs/CHANGELOG.md|.specs/LESSONS.md)' | wc -l   # 期望 0
grep -nE 'TODO|待补' FLOW-KIT-用户指南.md | wc -l    # 期望 0
```

## 实跑记录（2026-09-03）

- A1 ✅（版本行/URL/8 位日期 0）
- A2 ✅（两份 MD 禁词 0）
- A3 ✅ a-d/f/g grep 全过；e：`A3e-OK 12 ['archive_commit_check','claude-md',…,'workflow']`（指南 §7 config 键列 == stop-hook.json modules 双向相等）
- A4 ✅ build 20 页 + deck_checks OK（20 pages / banned=0 / 无空页 / 关键串）+ soffice PDF Pages=20 + 页 1/14/20 PNG
- make test：每次 Conventional Commit 均经 pre-commit 钩子执行 770 bats 0 fail（7 次提交，含本文件提交）
- 渲染抽查：/tmp/ppt-render/pg1-01.png、pg14-14.png、pg20-20.png（describe-image 检查无溢出/截断）

## UAT（人工）

- [ ] 指南 §2.4 按步骤可在 dsh profile 装入插件（UAT-1 · 与本次 dist 重装一致）
- [ ] deck 页 1/14/20 渲染图人工过目（UAT-2 · 附 TEST 记录 PNG：/tmp/ppt-render/pg1-01.png 等）

---

> AC 是 TEST 阶段派生用例的唯一来源；本文件不引入新 AC。结果行在实跑后填 ✅/❌ 并附证据行。
