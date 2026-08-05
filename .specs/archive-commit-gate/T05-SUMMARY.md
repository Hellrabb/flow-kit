# T05-SUMMARY — install.sh pre-commit symlink 部署

## 做了什么

4 文件修改：
1. `install.sh`：arg parse 追加 `--yes → FLOW_KIT_YES=1`
2. `install_hooks.sh`：新增 `deploy_pre_commit()` 函数 + install_hooks() 体内调用
3. `package-flow-kit.sh`：Part C 追加 pre-commit glob cp + fallback 同步 34
4. `validate_staging.sh`：Part C pattern 追加 pre-commit glob

## deploy_pre_commit 设计

- scope guard: `[ -d "${project}/.git" ] || return 0`（🔴R1+S1 修复）
- install_file 复制 pre-commit.sh 到 $hook_dst/pre-commit/（$SCRIPT_DIR 非 $src）
- D8 冲突检测：既有非 symlink + FLOW_KIT_YES → skip / else read -p 交互
- ln -sf symlink → $target（ADR-022 目标=已安装 hooks 目录）
- 动态作用域：$project/$hook_dst 从 install_hooks() local 可见

## verify

全部 8 条 ✅（bash -n × 2 + FLOW_KIT_YES + deploy_pre_commit in install_hooks.sh + NOT in install.sh + pre-commit in package + validate_staging）

## 越界检查

diff 含 install.sh + install_hooks.sh + package-flow-kit.sh + validate_staging.sh → 全在 write_files 范围内 ✅
