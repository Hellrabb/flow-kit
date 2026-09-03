# user-guide-deck-gen — flow-kit-用户指南.pptx 生成器

> 建立于 user-guide-sync-2026-09（2026-09-03）。本目录 tracked 入库，跨 change 维护。

## 重跑命令

```bash
python3 .specs/user-guide-deck-gen/build.py            # 输出根目录 flow-kit-用户指南.pptx（读 slides.json）
python3 .specs/user-guide-deck-gen/build.py --smoke    # 冒烟测试 → /tmp/guide-smoke.pptx
python3 .specs/user-guide-deck-gen/deck_checks.py      # 成品断言（页数/日期/禁词/关键串）· T08 后存在
```

## 依赖（本机锁定）

- python-pptx >= 1.0.2（build 自检）
- LibreOffice >= 24.2（仅渲染验证：`soffice --headless --convert-to pdf` + pdftoppm 抽页）
- Pillow（保留自 tech-deck gen utils，layouts 未直接使用）

## 版式（slides.json 字段）

| layout | 用途 | 字段 |
|---|---|---|
| cover | 封面 | title / subtitle / taglines[] / date |
| band | 内容页（主） | title / subtitle / bullets[]（t 文本 · lvl 层级 · c 色键或 hex · bold · size · sb/sa）· note |
| table | 表格页 | title / subtitle / header[] / rows[][]（首行如为数据行则不加表头：见 header 用法）|

配色/字体继承 theme.py（深蓝 1F3A5F / 中蓝 2E86AB / 宋体 + Times New Roman · 16:9 12191695×6858000 EMU）。
日期统一写 `2026-09-03 | github.com/hellrabb/flow-kit` 封面行与内容页无需重复。

## 禁词（与 FLOW-KIT-用户指南.md 同清单）

20260713 / 17 个模块 / 三级优先级链 / 三级链 —— deck_checks.py 会拦截。
