# -*- coding: utf-8 -*-
"""theme.py — flow-kit 技术设计 PPT 配色 + 字体 + 尺寸。
遵循 ppt-diagram-pipeline skill：英文 Times New Roman / 中文 宋体 / 代码 JetBrains Mono。
配色用 HEX_COLORS 统一管理，禁止硬编码（checklist P1-1）。"""

from pptx.util import Inches, Pt, Emu
from pptx.dml.color import RGBColor

# 16:9，与现有 flow-kit-用户指南.pptx 一致（12191695 x 6858000 EMU）
SLIDE_W = Inches(13.333)
SLIDE_H = Inches(7.5)

# 配色（HEX，无 #）
HEX_COLORS = {
    "primary":   "1F3A5F",  # 深蓝（标题/封面）
    "accent":    "2E86AB",  # 中蓝（主内容/节点）
    "success":   "2A9D8F",  # 青绿（hook 扩展/正面）
    "warning":   "E9A23B",  # 琥珀（兜底/人工确认）
    "danger":    "C7463B",  # 红（降级/拒）
    "dark_text":  "1A1A2E",
    "muted":     "6C757D",
    "light_bg":  "F4F6F8",
    "note_bg":   "FFF9E6",  # 便签黄
    "white":     "FFFFFF",
    "line":      "D4DAE3",
}

# 字体方案（skill font-east-asian.md）
EN_FONT = "Times New Roman"
ZH_FONT = "宋体"
CODE_FONT = "JetBrains Mono"

# 字号
SIZE_TITLE = 30
SIZE_SUBTITLE = 18
SIZE_H1 = 26
SIZE_H2 = 20
SIZE_BODY = 16
SIZE_SMALL = 12
SIZE_CODE = 13
SIZE_TABLE = 12

# 边距
MARGIN_X = Inches(0.5)
MARGIN_Y = Inches(0.45)
CONTENT_W = SLIDE_W - 2 * MARGIN_X


def rgb(name):
    return RGBColor.from_string(HEX_COLORS[name])
