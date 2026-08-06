# TASK: pre-commit-user-scope

## 波次规划

### Wave 1

```xml
<task id="T01" model-tier="standard" depends_on="">
  <action>
修复 `flow-kit-bundle/lib/install_hooks.sh` deploy_pre_commit() 函数（L38-58）：

1. 将 `install_file` 调用（当前 L43）移到 guard `[[ -d "${project}/.git" ]] || return 0`（当前 L39）之前
2. 删除 guard 前的 `mkdir -p "${project}/.git/hooks" "$hook_dst/pre-commit"`（L42）中的 `$hook_dst/pre-commit` 参数（install_file 内部已 mkdir）
3. 将 `mkdir -p "${project}/.git/hooks"` 移到 guard 之后（guard 通过后才执行）
4. 冲突检测块（L45-54）和 symlink 创建（L56-57）保持不变

修复后函数结构（DESIGN.md §2 D1 伪代码逐字实现）：
```bash
deploy_pre_commit() {
  # 1. 无条件装源文件
  install_file "$SCRIPT_DIR/hooks/pre-commit/pre-commit.sh" "$hook_dst/pre-commit/pre-commit.sh"

  # 2. 项目级才创建 symlink
  [[ -d "${project}/.git" ]] || return 0

  local target="${project}/.git/hooks/pre-commit"
  mkdir -p "${project}/.git/hooks"

  if [[ -e "$target" && ! -L "$target" ]]; then
    if [[ "${FLOW_KIT_YES:-0}" == "1" ]]; then
      echo "   [archive-commit-gate] existing pre-commit: $target, skipped"
      return 0
    fi
    local ans
    read -p "flow-kit: 既有 pre-commit 存在，覆盖？(y/N) " ans
    [[ "$ans" == "y" ]] || { echo "   skipped"; return 0; }
    rm -f "$target"
  fi

  ln -sf "$hook_dst/pre-commit/pre-commit.sh" "$target"
  echo "   ✅ pre-commit symlink → $target"
}
```

5. 在 `test/test_archive_commit_gate.bats` 新增两个行为测试（DESIGN.md §4）：
   - `deploy_pre_commit: user scope (no .git) installs source file only` — temp HOME 无 .git → assert 源文件存在 + ! -d ~/.git + ! -e ~/.git/hooks/pre-commit
   - `deploy_pre_commit: project scope (has .git) creates symlink → source` — temp repo with .git → assert 源文件 + symlink + readlink 指向
6. `make test-sync` 同步到 flow-kit-bundle/test/

注意：
- 禁止 DRY_RUN 模式测试（install_file DRY_RUN 只 echo 不创建文件，正向断言必然失败）
- test setup 需正确设置 SCRIPT_DIR + source install_hooks.sh + 设置 $project/$hook_dst 变量
  </action>
  <verify>
bash -n flow-kit-bundle/lib/install_hooks.sh && \
grep -q 'install_file.*pre-commit.*pre-commit' flow-kit-bundle/lib/install_hooks.sh && \
! grep -q 'mkdir -p.*\.git/hooks.*hook_dst/pre-commit' flow-kit-bundle/lib/install_hooks.sh && \
grep -q 'user scope.*no.*\.git' test/test_archive_commit_gate.bats && \
grep -q 'project scope.*has.*\.git' test/test_archive_commit_gate.bats && \
npx bats test/ && \
make check-test-sync
  </verify>
  <done>
T01-SUMMARY.md 记录：guard 位置调整 + mkdir 拆分 + 冲突块保留 + 2 行为测试 + 双源同步。bats 全绿。
  </done>
  <read_files>
flow-kit-bundle/lib/install_hooks.sh
flow-kit-bundle/hooks/pre-commit/pre-commit.sh
test/test_archive_commit_gate.bats
.specs/pre-commit-user-scope/DESIGN.md
.specs/pre-commit-user-scope/REQUIREMENT.md
  </read_files>
  <write_files>
flow-kit-bundle/lib/install_hooks.sh
test/test_archive_commit_gate.bats
flow-kit-bundle/test/test_archive_commit_gate.bats
.specs/pre-commit-user-scope/T01-SUMMARY.md
  </write_files>
</task>
```
