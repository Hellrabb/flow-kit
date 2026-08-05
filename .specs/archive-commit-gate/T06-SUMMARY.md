# T06-SUMMARY — flow-kit-resume.sh archive-uncommitted 分支

## 做了什么

在 flow-kit-resume.sh type-dispatch 的 l2-missing elif 后追加 archive-uncommitted elif 分支：
- jq 括号修复（F6）：`(.violations[0].files // (.violations | length) // "??")`
- 读后清（对齐 compliance 分支 L122 先例）

## verify

bash -n ✅ + grep archive-uncommitted ✅

## 越界检查

diff 仅 flow-kit-resume.sh → 0 越界 ✅
