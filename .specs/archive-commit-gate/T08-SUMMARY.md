# T08-SUMMARY — bats 回归测试

## 做了什么

新建 `test/test_archive_commit_gate.bats`（22 tests）+ 同步 `flow-kit-bundle/test/`。

## 测试覆盖

- T01 pre-commit.sh: 无 Makefile skip + make test fail reject + bash -n syntax（3 tests）
- T02 34-archive-commit-check.sh: bash -n + module_enabled guard + run_check + 双模式 + type-guarded clear（5 tests）
- T03 CORRECTION_TYPE_ARCHIVE_UNCOMMITTED: 常量定义（1 test）
- T04 注册: 00-gate + stop-hook.json + HOOK_MODULE_NAMES（3 tests）
- T06 flow-kit-resume.sh: archive-uncommitted elif + jq 括号修复（2 tests）
- T05 install: --yes + deploy_pre_commit 定义 + 调用位置 + package Part C + validate_staging（5 tests）
- T07 prompt docs: 5.1 归档 commit + ARCHIVE_BASE_SHA + commit-protocol 分类（3 tests）

## verify

```
全量 bats: 705 ok / 9 fail (pre-existing)
baseline: 683 ok / 9 fail
delta: +22 ok / +0 fail ✅ AC-5
```

9 个 pre-existing fail 全是 install/install_hooks BW01 exit 127 + make lint 环境问题，非本次引入。

## 修复记录

- pre-commit.sh PATH 补齐段 source /etc/profile 导致 set -e 退出 → 改为文件存在性守卫 + 大括号分组 `||` true
- test/test_archive_commit_gate.bats 同步到 flow-kit-bundle/test/（AC-7 一致性）

## 越界检查

diff 含 test/test_archive_commit_gate.bats（新建）+ flow-kit-bundle/test/ 同步 + pre-commit.sh PATH 修复 → 全在 write_files + 既有 T01 边界内 ✅
