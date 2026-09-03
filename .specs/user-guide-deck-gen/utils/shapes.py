# -*- coding: utf-8 -*-
"""utils/shapes.py — 东亚字体设置 + 文本框/段落/表格辅助。
遵循 ppt-diagram-pipeline skill font-east-asian.md：
  - python-pptx font.name 只写 a:latin，对 CJK 无效
  - 必须显式写 a:eaTypeface（ea 元素）才让中文字符按宋体渲染
  - 每次设 font.name 后须重设 ea（python-pptx 内部逻辑可能覆盖）
checklist P0-1：所有中文 run 必须有 a:ea=宋体。"""

from pptx.util import Pt, Inches, Emu
from pptx.oxml.ns import qn
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.dml.color import RGBColor
import theme


def set_font(run, en=None, zh=None, size=None, bold=None, italic=None, color=None):
    """设置 run 字体：英文 latin + 中文 ea + 尺寸/粗体/斜体/颜色。
    en/zh 默认用 theme.EN_FONT/ZH_FONT。"""
    en = en or theme.EN_FONT
    zh = zh or theme.ZH_FONT
    f = run.font
    f.name = en  # 写 a:latin
    if size is not None:
        f.size = Pt(size)
    if bold is not None:
        f.bold = bold
    if italic is not None:
        f.italic = italic
    if color is not None:
        f.color.rgb = RGBColor.from_string(color) if isinstance(color, str) else color
    # 强制重设 a:eaTypeface（先删旧再追加，schema 顺序：latin 在 ea 前）
    rPr = run._r.get_or_add_rPr()
    for ea in rPr.findall(qn('a:ea')):
        rPr.remove(ea)
    ea_el = rPr.makeelement(qn('a:ea'), {'typeface': zh})
    rPr.append(ea_el)
    # 同时确保 cs（complex script）也用同字体，避免混排回退
    for cs in rPr.findall(qn('a:cs')):
        rPr.remove(cs)
    cs_el = rPr.makeelement(qn('a:cs'), {'typeface': zh})
    rPr.append(cs_el)
    return run


def add_textbox(slide, left, top, width, height, anchor=MSO_ANCHOR.TOP):
    """加一个文本框，返回 text_frame（已设 word_wrap=True）。"""
    tb = slide.shapes.add_textbox(left, top, width, height)
    tf = tb.text_frame
    tf.word_wrap = True
    tf.vertical_anchor = anchor
    # 清掉首段默认 run 的样式由调用方管
    return tb, tf


def add_para(tf, text, first=False, size=theme.SIZE_BODY, bold=False,
             color=None, align=PP_ALIGN.LEFT, space_before=0, space_after=4,
             level=0, en=None, zh=None):
    """在 text_frame 里加一段（first=True 复用首段）。返回 run。"""
    p = tf.paragraphs[0] if first else tf.add_paragraph()
    p.alignment = align
    p.level = level
    if space_before:
        p.space_before = Pt(space_before)
    p.space_after = Pt(space_after)
    # 清掉旧 run
    for r in list(p.runs):
        r._r.getparent().remove(r._r)
    run = p.add_run()
    run.text = text
    set_font(run, en=en, zh=zh, size=size, bold=bold, color=color)
    return run


def add_runs(tf, segments, first=True, align=PP_ALIGN.LEFT, space_after=4):
    """一段里多 run（用于中英混排不同样式）。segments=[(text, dict), ...]。
    dict keys: size, bold, color, en, zh, italic。"""
    p = tf.paragraphs[0] if first else tf.add_paragraph()
    p.alignment = align
    p.space_after = Pt(space_after)
    for r in list(p.runs):
        r._r.getparent().remove(r._r)
    for text, kw in segments:
        run = p.add_run()
        run.text = text
        set_font(run, en=kw.get('en'), zh=kw.get('zh'),
                 size=kw.get('size', theme.SIZE_BODY),
                 bold=kw.get('bold', False),
                 italic=kw.get('italic'),
                 color=kw.get('color'))
    return p


def fill_cell(cell, text, size=theme.SIZE_TABLE, bold=False, color=None,
              fill=None, align=PP_ALIGN.LEFT):
    """填表格单元格（含字体 + 可选底色）。"""
    if fill is not None:
        cell.fill.solid()
        cell.fill.fore_color.rgb = RGBColor.from_string(fill) if isinstance(fill, str) else fill
    tf = cell.text_frame
    tf.word_wrap = True
    cell.vertical_anchor = MSO_ANCHOR.MIDDLE
    p = tf.paragraphs[0]
    p.alignment = align
    for r in list(p.runs):
        r._r.getparent().remove(r._r)
    run = p.add_run()
    run.text = text
    set_font(run, size=size, bold=bold, color=color)
