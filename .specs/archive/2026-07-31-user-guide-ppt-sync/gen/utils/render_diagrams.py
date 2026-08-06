# -*- coding: utf-8 -*-
"""utils/render_diagrams.py — dot / mscgen 渲染 + 容差裁剪 + 比例折叠检查。
遵循 ppt-diagram-pipeline skill diagram-pipeline.md + layout-algorithm.md + checklist.md：
  - dot: `dot -Tpng -Gdpi=300 in.dot -o out.png`，DPI 300（checklist P1-3）
  - mscgen: `mscgen -F "Noto Sans CJK SC" -T png -o out.png in.msc`（必带 -F，否则中文 box/note 消失 P0-2）
  - mscgen 输出 PIL LANCZOS 3x 放大（字体偏小 P1-5）
  - dot/mscgen PNG 都跑 crop_whitespace（dot tolerance=10, mscgen tolerance=5 P0-3）
  - 渲染后检查宽高比：>3:1 太宽（加 rank=same 拆行）；<0.5:1 太高（改 rankdir=LR）；1:1~2:1 直接用（P0-4）
"""

import os, subprocess, sys
from PIL import Image

DIAG_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "diagrams")
CJK_FONT = "Noto Sans CJK SC"
BG_COLOR = (252, 253, 254)  # #FCFCFD，layout-algorithm.md 指定


def crop_whitespace(path, tolerance=10, keep=5):
    """容差裁剪白边：取左上角为背景色，RGB 最大差 > tolerance 视为内容像素，
    求 bounding box，保留 keep px 呼吸边距。覆盖原文件。"""
    img = Image.open(path).convert("RGB")
    bg = img.getpixel((0, 0))
    px = img.load()
    w, h = img.size
    left, top, right, bottom = w, h, 0, 0
    found = False
    for y in range(h):
        for x in range(w):
            p = px[x, y]
            if max(abs(p[0]-bg[0]), abs(p[1]-bg[1]), abs(p[2]-bg[2])) > tolerance:
                found = True
                if x < left: left = x
                if x > right: right = x
                if y < top: top = y
                if y > bottom: bottom = y
    if not found:
        return img.size
    left = max(0, left - keep)
    top = max(0, top - keep)
    right = min(w, right + keep)
    bottom = min(h, bottom + keep)
    img.crop((left, top, right, bottom)).save(path)
    return (right - left, bottom - top)


def render_dot(dot_path, png_path=None):
    if png_path is None:
        png_path = os.path.splitext(dot_path)[0] + ".png"
    subprocess.run(["dot", "-Tpng", "-Gdpi=300", dot_path, "-o", png_path], check=True)
    crop_whitespace(png_path, tolerance=10, keep=5)
    return png_path


def render_mscgen(msc_path, png_path=None):
    if png_path is None:
        png_path = os.path.splitext(msc_path)[0] + ".png"
    # P0-2：必带 -F CJK，否则中文消失
    subprocess.run(["mscgen", "-F", CJK_FONT, "-T", "png", "-o", png_path, msc_path], check=True)
    # P1-5：3x LANCZOS 放大
    img = Image.open(png_path)
    scaled = img.resize((img.width * 3, img.height * 3), Image.LANCZOS)
    scaled.save(png_path)
    crop_whitespace(png_path, tolerance=5, keep=5)
    return png_path


def aspect_ratio(png_path):
    img = Image.open(png_path)
    return img.width / img.height


def fold_verdict(ratio):
    if ratio > 3.0:
        return "TOO_WIDE (>3:1) — 加 rank=same 拆行或 rankdir=TB"
    if ratio < 0.5:
        return "TOO_TALL (<0.5:1) — 改 rankdir=LR 或拆列"
    return "OK (%.2f:1)" % ratio


def render_all():
    """渲染 diagrams/ 下所有 .dot / .msc，打印比例 + 折叠判定。"""
    print("=== 渲染图表 ===")
    for name in sorted(os.listdir(DIAG_DIR)):
        src = os.path.join(DIAG_DIR, name)
        if name.endswith(".dot"):
            try:
                out = render_dot(src)
                r = aspect_ratio(out)
                print(f"  {name} → {os.path.basename(out)}  ratio={r:.2f}:1  {fold_verdict(r)}")
            except Exception as e:
                print(f"  {name} FAIL: {e}")
        elif name.endswith(".msc"):
            try:
                out = render_mscgen(src)
                r = aspect_ratio(out)
                print(f"  {name} → {os.path.basename(out)}  ratio={r:.2f}:1  {fold_verdict(r)}")
            except Exception as e:
                print(f"  {name} FAIL: {e}")


if __name__ == "__main__":
    render_all()
