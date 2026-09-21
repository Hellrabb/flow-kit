#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""deck_checks.py — flow-kit-用户指南.pptx 成品断言（user-guide-sync-2026-09b · T05）。

断言：页数=24；封面含 2026-09-21 与仓库 URL；逐页文本非空（无空页）；
禁词 0（与 FLOW-KIT-用户指南.md AC-2 同清单，均为历史上真实出现过的串）；
关键页**按标题寻址**（不再用 items[13]/items[19] 这类硬编码下标——扩页会位移）；
每张新专页有 ≥1 条按标题的关键串断言（插空壳页无法通过）；deck 全文含关键串。
"""
import sys
from pathlib import Path
from pptx import Presentation

ROOT = Path(__file__).resolve().parents[2]            # .../flow-kit/.specs/user-guide-deck-gen -> flow-kit 根
PPTX = ROOT / "flow-kit-用户指南.pptx"
BANNED = ["20260713", "17 个模块", "三级优先级链", "三级链",
          "仅 Claude Code", "仅为 Claude Code", "只为 Claude Code",
          ".specs/lessons/", "项目级 stop-hook.json", "三轮审查",
          "20000 字节", "归档（ARCHIVE）"]
KEY_STRINGS = ["l2-default=", "l3-default=", "dsh plugin", "五级", "archive-commit", "34 号",
               "FLOW_KIT_L3_AUTH_TOKEN", "凭证", "make check", "check-dist",
               "2026-09-21", "80000"]
EXPECT_PAGES = 24

# 关键页标题（按标题寻址的锚点；改标题即断言失败，属预期）
T_MODEL = "L2/L3 模型配置：五级解析链"
T_DSH = "dsh 插件化：安装与挂载"
T_INSTALL = "安装面：作用域与入口"
T_L3 = "L3 审查链：凭证 · 熔断 · 工件上限"
T_MAKE = "质量门禁：make check 六门"
T_COPY = "版本与副本口径"


def slide_texts():
    prs = Presentation(str(PPTX))
    out = []
    for i, slide in enumerate(prs.slides, 1):
        texts = []
        for sh in slide.shapes:
            if sh.has_text_frame and sh.text_frame.text.strip():
                texts.append(sh.text_frame.text.strip())
            if sh.has_table:
                for row in sh.table.rows:
                    for cell in row.cells:
                        if cell.text.strip():
                            texts.append(cell.text.strip())
        out.append((i, "\n".join(texts)))
    return out


def main():
    items = slide_texts()
    assert len(items) == EXPECT_PAGES, f"pages={len(items)}"
    full = "\n".join(t for _, t in items)

    import json as _json
    slides_src = _json.dumps(_json.load(open(Path(__file__).resolve().parent / "slides.json", encoding="utf-8")), ensure_ascii=False)
    for b in BANNED:
        assert b not in full, f"banned found: {b}"
        assert b not in slides_src, f"banned in slides.json: {b}"
    # 阶段 7 产出不得写成「归档（ARCHIVE）」或 ARCHIVE.md（旧口径）；
    # 合法的归档清单文件名 ARCHIVE-MANIFEST.txt 允许出现（与指南 §5 一致）
    assert "归档（ARCHIVE）" not in slides_src, "slides.json 残留「归档（ARCHIVE）」旧表述"
    assert "ARCHIVE.md" not in slides_src, "slides.json 残留 ARCHIVE.md"

    # 按标题寻址（每页首行 = band 标题 / cover 大标题）
    by_title = {t.splitlines()[0].strip(): t for _, t in items}
    assert len(by_title) == len(items), "存在重复标题，按标题寻址会丢页"

    page1, p1text = items[0]
    assert "2026-09-21" in p1text, "cover date missing"
    assert "hellrabbit/flow-kit" in p1text, "cover url missing"

    for i, t in items:
        assert t.strip(), f"empty slide: {i}"

    p_model = by_title[T_MODEL]
    assert "l2-default=" in p_model and "l3-default=" in p_model, "model page five-tier fields missing"
    assert "五级" in p_model, "model page five-tier wording missing"

    p_dsh = by_title[T_DSH]
    assert "dsh plugin" in p_dsh, "dsh page install command missing"
    assert "/flow doctor" in p_dsh, "dsh page doctor self-check missing"

    # 新专页（21~24）逐页按标题断言：插空壳页无法通过
    p_install = by_title[T_INSTALL]
    assert "make dsh-sync" in p_install, "install page dsh-sync missing"
    assert "--global" in p_install and "不含 hooks" in p_install, "install page scope wording missing"
    assert "v0.2.0" in p_install, "install page plugin version missing"

    p_l3 = by_title[T_L3]
    assert "FLOW_KIT_L3_AUTH_TOKEN" in p_l3, "l3 page credential var missing"
    assert "凭证" in p_l3, "l3 page credential wording missing"
    assert "80000" in p_l3, "l3 page artifact limit missing"
    assert "max_failures_before_bypass" in p_l3, "l3 page bypass threshold missing"
    assert ".done" in p_l3, "l3 page deadlock wording missing"

    p_make = by_title[T_MAKE]
    assert "make check" in p_make, "make-check page command missing"
    assert "check-dist" in p_make, "make-check page check-dist missing"
    assert "hooks-sync" in p_make, "make-check page hooks-sync missing"
    assert "verify-claims" in p_make, "make-check page verify-claims missing"

    p_copy = by_title[T_COPY]
    assert "2026-09-21" in p_copy, "copy page date missing"
    assert "md5" in p_copy, "copy page md5 wording missing"
    assert "test/test_guide_copy_parity.bats" in p_copy, "copy page guard test missing"

    for k in KEY_STRINGS:
        assert k in full, f"key string missing in deck: {k}"

    print(f"deck_checks OK: {EXPECT_PAGES} pages, banned=0, all pages non-empty, "
          f"{len(by_title)} titles addressable, keys present")


if __name__ == "__main__":
    main()
