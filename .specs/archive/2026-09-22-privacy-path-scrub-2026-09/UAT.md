# UAT — privacy-path-scrub-2026-09

| # | 步骤 | 命令 | 期望 | 实测 |
|---|---|---|---|---|
| UAT-1 | 工作区零命中 | `git grep -lE '/home/<user>' -- . \| wc -l` | 0 | ✅ 0 |
| UAT-2 | 缓存/备份不再跟踪 | `git ls-files \| grep -cE '\.pyc$\|\.bak$'` | 0 | ✅ 0 |
| UAT-3 | 未推送区间零命中（对象级） | 逐提交 `git grep -F` 扫描 `origin/develop..develop` | 0 | ✅ 0 |
| UAT-4 | 门禁不退化 | `make check` | rc=0 | ✅ rc=0（14 个 ✅ 行） |
| UAT-5 | 归档件仍可复跑 | `bash .specs/archive/2026-09-21-user-guide-sync-2026-09b/verify-ac.sh` | 128/0 | ✅ 128/0 |
| UAT-6 | 安全网已移除 | `git rev-parse pre-scrub-backup`；`test -e /tmp/pre-scrub-backup.bundle` | 均失败 | ✅ 均已删除 |
| **UAT-7（未达成，需你决策）** | **已推送历史零命中** | `git log -S '/home/<user>' --oneline origin/develop` | 0 | ❌ **34 个提交 / 39 个文件仍命中**（含 6 pyc + 1 bak）——只能靠强推重写已推送历史 |

## 结论

- 约定范围（**未推送区间**）内：AC-1/AC-2/AC-3/AC-4/AC-5 **全部满足**。
- **已推送历史（≤ `origin/develop`）仍含本机绝对路径**，属本 change 显式排除项（强推重写会影响他人克隆；仓库 README 禁止对 main 强推）。是否处理需你拍板。
