# -*- coding: utf-8 -*-
"""layouts.py — flow-kit 用户指南 deck 布局函数（2026-09 重建）。

版式约定（对齐 2026-07 既有 19 页 deck 的视觉语言 + 统一化）：
- cover：亮蓝纯色背景（accent）· 白色大标题左对齐 · 标题下细白分隔线 · 副题/要点 · 底部小字号日期与仓库链接
- band（内容页主布局）：白底 · 顶部深蓝（primary）色带含白色标题 + 浅蓝副题 · 正文多级项目符号
- table：band 头部 + 表格（表头 primary 白字，隔行 light_bg）
所有中文 run 经 utils.shapes.set_font 显式写 a:ea=宋体（P0-1 检查项）。
"""
import theme
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.enum.shapes import MSO_SHAPE
from pptx.util import Inches, Pt
from utils import shapes


def _rect(slide, left, top, w, h, color, line=False):
    sp = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, left, top, w, h)
    sp.fill.solid()
    sp.fill.fore_color.rgb = theme.rgb(color)
    if not line:
        sp.line.fill.background()
    sp.shadow.inherit = False
    return sp


def _blank(prs):
    return prs.slides.add_slide(prs.slide_layouts[6])


def _color(c):
    return theme.HEX_COLORS.get(c, c)


def layout_cover(prs, spec):
    s = _blank(prs)
    _rect(s, -Inches(0.06), -Inches(0.06), theme.SLIDE_W + Inches(0.12), theme.SLIDE_H + Inches(0.12), "accent")
    title = spec.get("title", "Flow-Kit 用户指南")
    subtitle = spec.get("subtitle", "")
    taglines = spec.get("taglines", [])
    date = spec.get("date", "")
    # 标题（左上，白，粗）
    tb, tf = shapes.add_textbox(s, Inches(0.9), Inches(1.5), theme.SLIDE_W - Inches(2.2), Inches(1.2))
    shapes.add_para(tf, title, first=True, size=44, bold=True, color=_color("white"), space_after=0)
    # 细分隔线
    _rect(s, Inches(0.95), Inches(2.75), Inches(4.2), Pt(2.2), "white")
    # 副题
    tb2, tf2 = shapes.add_textbox(s, Inches(0.9), Inches(3.1), theme.SLIDE_W - Inches(2.2), Inches(1.0))
    shapes.add_para(tf2, subtitle, first=True, size=theme.SIZE_SUBTITLE, color=_color("white"), space_after=6)
    for t in taglines:
        shapes.add_para(tf2, t, size=theme.SIZE_BODY - 2, color="FFFFFF", space_after=3)
    # 底部日期/链接
    tb3, tf3 = shapes.add_textbox(s, Inches(0.9), theme.SLIDE_H - Inches(0.75), Inches(9), Inches(0.4))
    shapes.add_para(tf3, date, first=True, size=theme.SIZE_SMALL, color="D9ECF5", space_after=0)

    return s


def _band_header(s, spec):
    """顶部深蓝 band：白标题 + 浅蓝副题。"""
    bar = _rect(s, 0, 0, theme.SLIDE_W, Inches(1.15), "primary")
    tb, tf = shapes.add_textbox(s, Inches(0.6), Inches(0.08), theme.SLIDE_W - Inches(1.2), Inches(1.0), MSO_ANCHOR.MIDDLE)
    shapes.add_para(tf, spec.get("title", ""), first=True, size=theme.SIZE_TITLE, bold=True,
                    color=_color("white"), space_after=0)
    if spec.get("subtitle"):
        shapes.add_para(tf, spec["subtitle"], size=theme.SIZE_SMALL + 1, color="A8C4E0", space_before=1, space_after=0)
    return s


def layout_band(prs, spec):
    s = _blank(prs)
    _band_header(s, spec)
    body = spec.get("bullets") or spec.get("body") or []
    tb, tf = shapes.add_textbox(s, Inches(0.75), Inches(1.5), theme.SLIDE_W - Inches(1.5), theme.SLIDE_H - Inches(1.9))
    first = True
    for b in body:
        text = b.get("t", "")
        if not text:
            continue
        shapes.add_para(tf, text, first=first, size=b.get("size", theme.SIZE_BODY),
                        bold=b.get("bold", False), color=_color(b.get("c", "primary")),
                        level=b.get("lvl", 0),
                        space_before=b.get("sb", 2), space_after=b.get("sa", 5))
        first = False
    if spec.get("note"):
        shapes.add_para(tf, spec["note"], size=theme.SIZE_SMALL, color=_color("muted"), space_before=8, space_after=0)
    return s


def layout_table(prs, spec):
    s = _blank(prs)
    _band_header(s, spec)
    rows = spec.get("rows") or []
    cols = spec.get("cols") or []
    header = spec.get("header") or []
    if not cols and rows:
        cols = list(range(len(rows[0]))) if rows else []
    n_rows, n_cols = len(rows), (len(cols) if cols else len(header))
    if n_rows and n_cols:
        tbl_shape = s.shapes.add_table(n_rows, n_cols, Inches(0.7), Inches(1.5),
                                       theme.SLIDE_W - Inches(1.4), theme.SLIDE_H - Inches(2.2))
        table = tbl_shape.table
        for ri, row in enumerate(rows):
            for ci, val in enumerate(row):
                cell = table.cell(ri, ci)
                bold = ri == 0 and not header
                fill = "primary" if (ri == 0 and not header) else ("light_bg" if ri % 2 == 0 else None)
                shapes.fill_cell(cell, str(val), size=theme.SIZE_SMALL + 1, bold=bold,
                                 color=_color("white") if (ri == 0 and not header) else None,
                                 fill=theme.HEX_COLORS.get(fill, fill) if fill else None,
                                 align=PP_ALIGN.LEFT if ci == 0 else PP_ALIGN.LEFT)
    return s


LAYOUTS = {
    "cover": layout_cover,
    "band": layout_band,
    "table": layout_table,
}
