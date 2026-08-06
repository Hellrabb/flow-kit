# T01-SUMMARY: deploy_pre_commit guard 位置修复 + 行为测试

## 做了什么

修复 `flow-kit-bundle/lib/install_hooks.sh` deploy_pre_commit() 函数的 guard 位置缺陷：

1. **install_file 无条件前置**：从 guard 之后移到 guard 之前，确保 user scope（project=$HOME 无 .git）也装源文件到 `$hook_dst/pre-commit/pre-commit.sh`
2. **guard 后移**：`[[ -d "${project}/.git" ]] || return 0` 移到 install_file 之后，只控制 symlink 创建段
3. **mkdir 拆分**：原 `mkdir -p "${project}/.git/hooks" "$hook_dst/pre-commit"` 拆为——install_file 内部 mkdir（$hook_dst/pre-commit）+ guard 后独立 `mkdir -p "${project}/.git/hooks"`
4. **冲突检测块逐字保留**：FLOW_KIT_YES check + read -p + rm -f 不变
5. **symlink 创建不变**：ln -sf 逻辑完全保留

补 2 个行为测试到 `test/test_archive_commit_gate.bats`（+ make test-sync 同步到 bundle）：
- user scope (no .git)：正向断言源文件存在 + 负面断言 ! -d ~/.git + ! -e ~/.git/hooks/pre-commit
- project scope (has .git)：正向断言源文件 + symlink + readlink 指向

## 为什么

archive-commit-gate 交付的 deploy_pre_commit guard 在函数最前面，导致 user scope 不仅跳过 symlink 创建，还跳过了源文件安装。违背 flow-kit「user scope 装源文件、project scope 接线」统一模式。

## 偏离 DESIGN 哪里

无偏离。DESIGN §2 D1 伪代码逐字实现。DESIGN §4 测试策略 2 个行为测试已补齐。

## 验证

- bash -n install_hooks.sh ✅
- verify 5 项 grep 全通过 ✅
- bats 新测试 4/4 ok（含 2 新行为 + 2 grep 级）✅
- 全量 bats 716 ok / 0 fail（+2 vs baseline 714）✅
- make check-test-sync 双源一致 ✅

## diff 边界

仅触碰 write_files 内文件：
- flow-kit-bundle/lib/install_hooks.sh（deploy_pre_commit L38-42 重排）
- test/test_archive_commit_gate.bats（+32 行 2 测试）
- flow-kit-bundle/test/test_archive_commit_gate.bats（make test-sync 自动同步）
