# T04-SUMMARY — 34 号三处注册

## 做了什么

在 3 处注册 module 34：
1. `00-gate.sh`：L123 后追加 `run_module "34-archive-commit-check.sh" "archive_commit_check"`
2. `stop-hook.json`：modules 追加 `"archive_commit_check": {"enabled": true, ...}`
3. `common.sh`：HOOK_MODULE_NAMES 数组追加 `34-archive-commit-check`

## verify

三处 grep 全 ✅。module_enabled 默认 false，模板条目使其对新安装 enabled（L2 #5 修正）。

## 越界检查

diff 仅含 3 处追加 → 0 越界 ✅
