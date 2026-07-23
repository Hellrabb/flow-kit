# T07-SUMMARY — flow/SKILL.md 加 /flow model 内联段

## 做了什么
`flow/SKILL.md` 加 `### /flow model` 内联段（对齐既有 gate-config 模式，DESIGN §5 全语法）。

## 改了哪些文件
- `flow-kit-bundle/skills/flow/SKILL.md`（gate-config 段后、自动 checkpoint 段前插入）

## verify 输出
```
T07_VERIFY_OK（/flow model + --clear 内联段存在）
```

## 内容覆盖
- 全语法：显示（无参）/ `l2=<m>` / `l3=<m>` / `l2=<m> l3=<m>`（合并）/ `--clear l2|l3`
- 原子写 jq --arg + 临时文件 mv（防注入，bracket L-011）
- 优先级链提示（env var > .flow-active > 降级）
- 字段边界（仅 l2_model/l3_model，不碰 goal 其他字段）

## 越界检查（R6.5）
write_files: flow/SKILL.md | 实际 diff: flow/SKILL.md | 越界: 0 ✅
