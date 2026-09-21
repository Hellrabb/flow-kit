#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""check-appendix-superset.py — 集合断言：TASK 附录 A ⊇ REQUIREMENT 的 AC-2/AC-3 锚点表。

母本 = REQUIREMENT.md 的 AC-2 / AC-3 表格（v4 · L2 R24）；附录 A 是超集。
判定口径（避免把解释性文字当锚点）：
  对 AC 表的每一行，从「反例」「正例」两格里各取**候选锚点**（反引号片段，
  长度 ≥ 4 且不含 `（`、`：`、`|`、`**` 这类说明性标记）；
  每格至少要有 **1 个候选锚点出现在 TASK.md** 中，否则记一条缺失。
退出码：0 = 全命中；1 = 有缺失（打印缺失清单）。
"""
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent          # v4.7：兼容 .specs/<id>/ 与 .specs/archive/<date>-<id>/
ROOT = HERE
while ROOT != ROOT.parent and not (ROOT / "package-dsh-plugin.sh").exists():
    ROOT = ROOT.parent
REQ = HERE / "REQUIREMENT.md"
TASK = HERE / "TASK.md"

req = REQ.read_text(encoding="utf-8")
task = TASK.read_text(encoding="utf-8")


def norm(x: str) -> str:
    """去掉 markdown 转义与反引号，便于跨表格比较锚点（表格里反引号需转义，形式会不同）。"""
    return x.replace("\\", "").replace("`", "")

rows = [ln for ln in req.splitlines() if re.match(r"^\|\s*(?:D\d+|N\d+)\b", ln)]  # v4.4：\b 使 "| N1 L3 凭证…" 这类行也被扫到
NOISE = ("（", "：", "|", "**", "）", "\n")
# 纯行号/路径引用（如 ":750/:761/:770"、":89"）不是锚点，单独过滤
LINEREF = re.compile(r"^[:0-9/\s]+$")

missing: list[str] = []
checked = 0
skipped: list[str] = []
for ln in rows:
    # v4.4：按**未转义的** | 切格（Markdown 表格里的 \| 是内容，不是分隔符）
    body = ln.strip()
    body = body[1:] if body.startswith("|") else body
    body = body[:-1] if body.endswith("|") else body
    cells = [x.strip() for x in re.split(r"(?<!\\)\|", body)]
    if len(cells) < 3:
        continue
    did = cells[0]
    for label, cell in (("反例", cells[1]), ("正例", cells[2])):
        # 先剥掉括号注释（注释里的文件名 / 变量名是**说明**，不是锚点），
        # 再把转义反引号（\`）换成占位符，避免整格被正则漏抽（v4 · 阶段 5 L2 R3）
        cell_n = re.sub(r"（[^）]*）", "", cell).replace("\\`", "\x00")
        cands = [s.replace("\x00", "`").strip() for s in re.findall(r"`([^`]+)`", cell_n)]
        cands = [s for s in cands if len(s) >= 3 and not any(n in s for n in NOISE) and not LINEREF.match(s)]
        if not cands:
            skipped.append(f"{did} {label}")   # 无可抽锚点（注释格/纯描述格）——显式计数，不静默跳过
            continue
        checked += 1
        # v4.1 · 阶段 1 L2 第五轮 R37：由「任一候选命中」改为**逐锚点等值**（每个候选都必须命中），
        # 否则真缺失会被同格的其它候选吸收掉。
        for c_ in cands:
            if norm(c_) not in norm(task):
                missing.append(f"{did} {label}: {c_}")

print(f"检查单元格：{checked} 个；跳过（无可抽锚点）：{len(skipped)} 个；附录 A 缺失：{len(missing)} 个")
if skipped:
    print("  跳过明细：" + " · ".join(skipped))
for m in missing:
    print(f"  MISSING: {m}")
sys.exit(1 if missing else 0)
