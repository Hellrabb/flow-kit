# T07-SUMMARY — 7-integration 步骤 5.1 + commit-protocol 归档分类

## 做了什么

1. `7-integration.md`：步骤 5 后追加步骤 5.1（归档 commit 指令）
   - ARCHIVE_BASE_SHA 记录到 STATE.md（D7 · AC-1 Given 锚点 · L2 #3 修复）
   - 按类型拆分原子提交（fix/docs/chore ≤3）
   - PCSC 硬检查 git status --porcelain 空
   - 弱模型防护结构化自检清单
   - 34 号 hook 兜底提示

2. `commit-protocol.md`：追加归档 commit 分类段（R13 分类漂移修复 · 明确非任务级 commit）

## verify

grep 5.1 归档 ✅ + ARCHIVE_BASE_SHA ✅ + commit-protocol 归档分类 ✅

## 越界检查

diff 含 7-integration.md + commit-protocol.md → 全在 write_files 范围内 ✅
