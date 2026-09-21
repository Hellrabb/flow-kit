# TASK: 绝对路径脱敏与历史清理

- **Change ID**: privacy-path-scrub-2026-09
- **关联**: `@.specs/privacy-path-scrub-2026-09/{REQUIREMENT,DESIGN}.md`

## 波次划分

```
Wave 1: T01 安全网（bundle + tag）
Wave 2: T02 前向脱敏（文本 + 代码语义化）
Wave 3: T03 停止跟踪缓存/备份 + .gitignore 追加
Wave 4: T04 提交（前向）
Wave 5: T05 历史重写（filter-branch）
Wave 6: T06 清理与验证（AC-1~AC-5）
Wave 7: T07 归档 + 安全网删除
```

> 本 change 为**机械型 + 破坏性（历史重写）**，各波次严格串行：后一步依赖前一步的干净状态。

## 任务清单

```xml
<task id="T01" parallel="false" status="pending" model-tier="cheap">
  <name>安全网：全量 bundle + 标签</name>
  <read_files>—</read_files>
  <write_files>/tmp/pre-scrub-backup.bundle（仓库外）</write_files>
  <action>git bundle create /tmp/pre-scrub-backup.bundle --all；git tag -f pre-scrub-backup；记录 HEAD 短哈希</action>
  <verify>test -s /tmp/pre-scrub-backup.bundle && git rev-parse --verify pre-scrub-backup >/dev/null && echo T01-OK</verify>
  <done>可回滚点已建立（AC-5 的前置）</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="false" status="pending" model-tier="standard">
  <name>前向脱敏：49 文件 ~ → ~（代码文件语义化）</name>
  <read_files>git grep -lE '~' -- .</read_files>
  <write_files>上述文件（文本）</write_files>
  <action>对 md/归档文本执行字面替换；对 .py 用 os.path.expanduser("~/…") 语义化；替换后逐文件 diff 复核</action>
  <verify>test "$(git grep -lE '~' -- . | wc -l)" = 0 && echo T02-OK</verify>
  <done>AC-1 满足（工作区零命中）</done>
  <depends_on>T01</depends_on>
</task>

<task id="T03" parallel="false" status="pending" model-tier="cheap">
  <name>停止跟踪 6×.pyc + 1×.bak，追加 .gitignore 规则</name>
  <read_files>.gitignore</read_files>
  <write_files>.gitignore（仅追加一行 *.bak）</write_files>
  <action>git rm --cached 上述 7 个文件；.gitignore 追加 *.bak（既有 *.pyc/__pycache__/ 不动）</action>
  <verify>test "$(git ls-files | grep -cE '\.pyc$|\.bak$')" = 0 && echo T03-OK</verify>
  <done>AC-2 满足</done>
  <depends_on>T02</depends_on>
</task>

<task id="T04" parallel="false" status="pending" model-tier="cheap">
  <name>前向提交（1 个原子提交）</name>
  <read_files>—</read_files>
  <write_files>—</write_files>
  <action>git add -A && git commit：chore(privacy-path-scrub-2026-09): 前向脱敏…</action>
  <verify>test "$(git -c core.quotepath=false status --porcelain | wc -l)" = 0 && echo T04-OK</verify>
  <done>干净工作区（历史重写前置条件）</done>
  <depends_on>T03</depends_on>
</task>

<task id="T05" parallel="false" status="pending" model-tier="standard">
  <name>历史重写：origin/develop..HEAD 文本替换 + 移除 pyc/bak</name>
  <read_files>—</read_files>
  <write_files>git 对象库（37 个提交）</write_files>
  <action>FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch --tree-filter '文本替换' -- origin/develop..HEAD；再 --index-filter 'git rm -r --cached --ignore-unmatch *.pyc *.bak'（顺序：先文本后路径）；产出 old→new 映射</action>
  <verify>test "$(git log origin/develop..HEAD --oneline | wc -l)" -ge 1 && echo T05-OK</verify>
  <done>历史区间已重写（AC-3 前半）</done>
  <depends_on>T04</depends_on>
</task>

<task id="T06" parallel="false" status="pending" model-tier="standard">
  <name>清理与全量验证（AC-1~AC-5）</name>
  <read_files>—</read_files>
  <write_files>.specs/privacy-path-scrub-2026-09/{history-rewrite-map.txt,IMPACTED-REFS.md}</write_files>
  <action>删 refs/original → reflog expire --expire=now --all → gc --prune=now；全历史 pickaxe 复核；make check；产出映射与影响清单</action>
  <verify>test "$(git log --all -S '~' --oneline | wc -l)" = 0 && make check >/dev/null 2>&1 && echo T06-OK</verify>
  <done>AC-3/AC-4/AC-5 满足</done>
  <depends_on>T05</depends_on>
</task>

<task id="T07" parallel="false" status="pending" model-tier="cheap">
  <name>归档 + 安全网删除</name>
  <read_files>—</read_files>
  <write_files>.specs/archive/&lt;日期&gt;-privacy-path-scrub-2026-09/*</write_files>
  <action>生成清单 → mv 入 archive → 删 tag pre-scrub-backup + /tmp bundle → 复核旧对象不可达 → 提交</action>
  <verify>git rev-parse --verify pre-scrub-backup 2>/dev/null; test $? -ne 0 && test ! -e /tmp/pre-scrub-backup.bundle && echo T07-OK</verify>
  <done>安全网已移除且旧对象不可达（AC-5）</done>
  <depends_on>T06</depends_on>
</task>
```

## 阻塞日志

| 任务 | 阻塞原因 | 待人工决策项 | 时间 |
|---|---|---|---|
| | | | |
