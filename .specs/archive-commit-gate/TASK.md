# TASK · archive-commit-gate

> 阶段 3 任务拆解 · 基于 DESIGN.md v3.1（三层加固 D1-D8 + ADR-022）

## 波次划分

```
Wave 1 (parallel): T01[P], T03[P] → T02 (←T03 · **🟡R3：T02 串行 T03 后，非 Wave 1 并行**)
Wave 2 (parallel): T04[P] (←T02,T03), T05[P] (←T01), T06[P] (←T02,T03)
Wave 3:            T07 (←T04,T05,T06)
Wave 4:            T08 (←T07)
```

## 任务清单

<task id="T01" parallel="true" status="done" model-tier="standard">
  <name>新增 pre-commit hook 脚本（D2 make test 门禁）</name>
  <read_files>
    flow-kit-bundle/hooks/pre-commit/*
    flow-kit-bundle/hooks/stop/lib/common.sh
    .specs/CONTEXT.md
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/pre-commit/pre-commit.sh
  </write_files>
  <action>
    新建 pre-commit.sh（**L2 #8：shebang + set -euo pipefail + chmod +x**）：
    0. 文件头：#!/bin/bash + set -euo pipefail（仓库默认）
    1. PATH 补齐（D2 R9 修复）：source /etc/profile 2>/dev/null + source ~/.profile 2>/dev/null + [ -n "$NVM_DIR" ] && source "$NVM_DIR/nvm.sh" + export PATH="$HOME/.local/bin:$PATH"
    2. 无 Makefile → echo "[archive-commit-gate] no Makefile, skipping test gate" + exit 0（英文契约串，N1 修复）
    3. command -v npx 不可见 → echo warn + exit 0
    4. make test 非零退出 → echo "[archive-commit-gate] test failed, commit rejected" >&2 + exit 1
    5. make test 零退出 → exit 0
    6. chmod +x pre-commit.sh（L2 #8 · verify test -x 依赖）
  </action>
  <verify>bash -n flow-kit-bundle/hooks/pre-commit/pre-commit.sh && test -x flow-kit-bundle/hooks/pre-commit/pre-commit.sh</verify>
  <done>pre-commit.sh 存在、语法通过、可执行；四分支（无 Makefile/npx 不可见/test fail/test pass）逻辑齐全（对应 AC-2）</done>
  <depends_on></depends_on>
</task>

<task id="T02" status="done" model-tier="standard">
  <name>新增 Stop hook 模块 34（D3 归档后未 commit 检测）</name>
  <read_files>
    flow-kit-bundle/hooks/stop/34-archive-commit-check.sh
    flow-kit-bundle/hooks/stop/lib/common.sh
    flow-kit-bundle/hooks/stop/lib/correction-file.sh
    flow-kit-bundle/hooks/stop/lib/correction-types.sh
    flow-kit-bundle/hooks/stop/28-weak-model-compliance.sh
    flow-kit-bundle/hooks/stop/32-fallback-guard.sh
    .specs/CONTEXT.md
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/34-archive-commit-check.sh
  </write_files>
  <action>
    新建 34-archive-commit-check.sh：
    1. source common.sh + correction-file.sh + correction-types.sh
    2. module_enabled "archive_commit_check" || exit 0（28 号 guard 先例 · F8 snake_case）
    3. _check_archive_commit_body()：全用 $PROJECT_ROOT env（F1 修复 · 非 $1）
       a. flow_active="${PROJECT_ROOT}/.flow-active"
       b. pipeline 分支：[ "$(jq -r '.goal.scope//""' "$flow_active")" = "pipeline" ] && [ "$(jq -r '.goal.status//""' "$flow_active")" = "done" ] && [ -d "${PROJECT_ROOT}/.specs/archive" ]（F3-residual 修复 · AC-3 Given 三条件 · **L2 #2：${PROJECT_ROOT} 前缀**）
       c. 单阶段分支（goal null）：arch_dir=$(ls -t "${PROJECT_ROOT}/.specs/archive/" 2>/dev/null | head -1)；arch_mtime=$(stat -c %Y "${PROJECT_ROOT}/.specs/archive/$arch_dir" 2>/dev/null || echo 0)；last_commit_ts=$(cd "${PROJECT_ROOT}" && git log -1 --format=%ct 2>/dev/null || echo 0)；[ "$arch_mtime" -gt "$last_commit_ts" ]（F3 修复 git 锚点 · **L2 #2：全路径 ${PROJECT_ROOT} + cd + || echo 0，对齐 DESIGN D3**）
       d. 两分支都不满足 → return 0
       e. git status --porcelain 非空 → correction_file_write（F2 修复 · 2 参 path+json 含 type 字段 · 对齐 correction-file.sh:47 真签名）
       f. git status 干净 → type-guarded clear（F4 修复 · 对齐 write_model_missing_clear:132-144 非文件级 rm）
    4. run_check "archive_commit_check" "AC3" "" _check_archive_commit_body（F8 snake_case）
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/34-archive-commit-check.sh</verify>
  <done>34-archive-commit-check.sh 存在、语法通过；骨架含 module_enabled guard + run_check + _check_archive_commit_body 双模式检测 + type-guarded clear（对应 AC-3 · **L2 #10：AC-1→AC-3**）</done>
  <depends_on>T03</depends_on>
</task>

<task id="T03" parallel="true" status="done" model-tier="standard">
  <name>新增 CORRECTION_TYPE_ARCHIVE_UNCOMMITTED 常量（D5）</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/correction-types.sh
    .specs/CONTEXT.md
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/correction-types.sh
  </write_files>
  <action>
    在 correction-types.sh 常量区追加 `readonly CORRECTION_TYPE_ARCHIVE_UNCOMMITTED="archive-uncommitted"`（D5 · R10 · **L2 #7：readonly 对齐 CONTEXT 已锁约定 UPPER_SNAKE_CASE**）
  </action>
  <verify>grep -q 'CORRECTION_TYPE_ARCHIVE_UNCOMMITTED' flow-kit-bundle/hooks/stop/lib/correction-types.sh</verify>
  <done>常量定义存在（对应 AC-3 correction type 注册）</done>
  <depends_on></depends_on>
</task>

<task id="T04" parallel="true" status="pending" model-tier="standard">
  <name>注册 34 到 00-gate + stop-hook.json + HOOK_MODULE_NAMES（D3 接线）</name>
  <read_files>
    flow-kit-bundle/hooks/stop/00-gate.sh
    flow-kit-bundle/hooks/config/stop-hook.json
    flow-kit-bundle/hooks/stop/lib/common.sh
    .specs/CONTEXT.md
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/00-gate.sh
    flow-kit-bundle/hooks/config/stop-hook.json
    flow-kit-bundle/hooks/stop/lib/common.sh
  </write_files>
  <action>
    1. 00-gate.sh：L120 run_module "33-flow-active-integrity" 后、L123 "99-report" 前追加 run_module "${HOOK_BASE_DIR}/34-archive-commit-check.sh" "archive_commit_check"（F8 snake_case 第二参 · R1 修复）
    2. stop-hook.json：modules 追加 "archive_commit_check": {"enabled": true}（F8 snake_case key · R3 修复）
    3. common.sh HOOK_MODULE_NAMES 数组（L270）追加 "34-archive-commit-check"
  </action>
  <verify>grep -q '34-archive-commit-check' flow-kit-bundle/hooks/stop/00-gate.sh && grep -q 'archive_commit_check' flow-kit-bundle/hooks/config/stop-hook.json && grep -q '34-archive-commit-check' flow-kit-bundle/hooks/stop/lib/common.sh</verify>
  <done>34 号在三处注册（00-gate run_module + stop-hook.json 模板 + HOOK_MODULE_NAMES 数组），module_enabled 默认 false，模板条目使其对新安装 enabled（对应 AC-3 hook 注册链路 · **L2 #5 修正：默认 false 非 true**）</done>
  <depends_on>T02, T03</depends_on>
</task>

<task id="T05" parallel="true" status="pending" model-tier="standard">
  <name>install.sh pre-commit symlink 部署 + --yes flag + HOOK_MODULE_NAMES 同步（D1/D8/N2）</name>
  <read_files>
    flow-kit-bundle/install.sh
    flow-kit-bundle/lib/install_hooks.sh
    package-flow-kit.sh
    .specs/CONTEXT.md
  </read_files>
  <write_files>
    flow-kit-bundle/install.sh
    flow-kit-bundle/lib/install_hooks.sh
    flow-kit-bundle/lib/validate_staging.sh
    package-flow-kit.sh
  </write_files>
  <action>
    1. install.sh arg parse 追加 --yes → FLOW_KIT_YES=1（N2 修复 · D8 carrier 补齐）
    2. install_hooks.sh 追加 deploy_pre_commit() 函数（D1 · ADR-022 · R8 · 🔴#1 + 🔴N1 + 🔴R1 修复 · 变量对齐 $SCRIPT_DIR/$project · scope guard）：
       0. [ -d "${project}/.git" ] || return 0  # **🔴R1+S1 修复：基于 .git 存在性（非 scope）· install.sh:242 user-global project=$HOME 无 .git → skip · install.sh:218/252 project 含 .git → 部署（scope=user 时 hook_dst=USER_HOOKS_DIR ~/.claude/hooks/ · ADR-022 user 目标路径落盘 · symlink → $TARGET_PROJECT/.git/hooks/pre-commit）**
       a. local target="${project}/.git/hooks/pre-commit"（**N1：$project 是 install_hooks() 既有参数**）
       b. install_file "$SCRIPT_DIR/hooks/pre-commit/pre-commit.sh" "$hook_dst/pre-commit/pre-commit.sh"（**N1：$SCRIPT_DIR 非 $src** · $src 仅 install_file() local L23 作用域 · 🔴#1 先复制到安装目录 · install_file 仅 cp 无 chmod · 依赖 T01 step 6 chmod +x 源文件 + cp mode 继承 · **🟢R4 注释修正**）
       c. D8 既有冲突检测完整分支（**🟡N3 · 非 --yes 模式交互询问 · 对齐 DESIGN D8**）：
          [ -e "$target" ] && [ ! -L "$target" ] → 既有用户文件（非 flow-kit symlink）：
            [ "${FLOW_KIT_YES:-0}" = "1" ] → echo "[archive-commit-gate] existing pre-commit: $target, skipped" + return 0（AC-4 verify grep）
            else → read -p "flow-kit: 既有 pre-commit 存在，覆盖？(y/N) " ans；[ "$ans" = "y" ] || { echo skipped; return 0; }；rm -f "$target"
       d. ln -sf "$hook_dst/pre-commit/pre-commit.sh" "$target"（**N1：$target 非 $git_dir** · symlink → 已安装目录）
    3. **🔴R4 修复**：deploy_pre_commit 在 **install_hooks() 函数体内**（install_hooks.sh）调用——stop hooks 安装段之后追加 `deploy_pre_commit`（动态作用域下 $scope/$project/$hook_dst 可见 · scope guard 生效 · user 模式 scope=user → guard return 0 跳过 · project 模式正常部署）。**禁止**在 install.sh:218/242/252 调用点调用（$scope/$project/$hook_dst 是 install_hooks() local · 调用点不可见 → guard 空转 + $project/$hook_dst unset → 全模式 install abort）
    4. package-flow-kit.sh **Part C**（非 D · L88-103 · L2 #9 修正）：mkdir staging/hooks/pre-commit/ + 追加 `cp "$HOOK_SRC/pre-commit/"*.sh "$STAGING/hooks/pre-commit/"` glob 行（**声明禁动例外**：Part C 追加 pre-commit glob · 对齐 superpowers-v6-absorb Part F 例外先例）。模块 34 经 HOOK_MODULE_NAMES L99 loop 自动纳入。fallback 列表（L103-112）追加 "34-archive-commit-check"（L2 #11）+ install_hooks.sh:81 fallback 列表同步追加 "34-archive-commit-check"（**🟢N4：R12 半修复补齐**）
    5. validate_staging.sh:54 Part C pattern 列表追加 `"$BUNDLE_DIR/hooks/pre-commit/"*.sh`（**🔴R2：L-031 漏改类 · pre-commit.sh 落盘后 --validate / make check 必 fail**）+ KNOWN_SKIP（如有）同步
  </action>
  <verify>bash -n flow-kit-bundle/install.sh && bash -n flow-kit-bundle/lib/install_hooks.sh && grep -q 'FLOW_KIT_YES' flow-kit-bundle/install.sh && grep -q 'deploy_pre_commit' flow-kit-bundle/lib/install_hooks.sh && ! grep -q 'deploy_pre_commit' flow-kit-bundle/install.sh && grep -q 'pre-commit.*\.sh' package-flow-kit.sh && grep -q 'pre-commit' flow-kit-bundle/lib/validate_staging.sh</verify>
  <done>install.sh 支持 --yes flag + install_hooks.sh 含 deploy_pre_commit symlink 部署函数 + 既有冲突检测（对应 AC-2/AC-4）</done>
  <depends_on>T01</depends_on>
</task>

<task id="T06" parallel="true" status="pending" model-tier="standard">
  <name>flow-kit-resume.sh type-dispatch 追加 archive-uncommitted 分支（D4）</name>
  <read_files>
    flow-kit-bundle/hooks/session-start/flow-kit-resume.sh
    flow-kit-bundle/hooks/stop/lib/correction-types.sh
    .specs/CONTEXT.md
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/session-start/flow-kit-resume.sh
  </write_files>
  <action>
    在 flow-kit-resume.sh type-dispatch 的 l2-missing elif 分支（L147）后、else（L152）前，追加：
    elif [[ "$corr_type" == "archive-uncommitted" ]]; then
      local fc=$(jq -r '(.violations[0].files // (.violations | length) // "??")' "$compliance_correction_file")  # F6 jq 括号修复
      echo "⚠️ 归档后 git status 非干净（$fc 个文件未 commit）。执行 7-integration 步骤 5.1 归档 commit。"
      rm -f "$compliance_correction_file"  # 读后清（对齐 compliance 分支 L122 先例）
  </action>
  <verify>bash -n flow-kit-bundle/hooks/session-start/flow-kit-resume.sh && grep -q 'archive-uncommitted' flow-kit-bundle/hooks/session-start/flow-kit-resume.sh</verify>
  <done>flow-kit-resume.sh 含 archive-uncommitted elif 分支 + jq 括号修复 + 读后清（对应 AC-3 SessionStart banner 展示）</done>
  <depends_on>T02, T03</depends_on>
</task>

<task id="T07" status="pending" model-tier="standard">
  <name>7-integration.md 步骤 5.1 归档 commit 指令 + commit-protocol.md 分类移修改段（D6/R13）</name>
  <read_files>
    flow-kit-bundle/flow-kit/prompts/7-integration.md
    flow-kit-bundle/flow-kit/reference/commit-protocol.md
    .specs/CONTEXT.md
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/prompts/7-integration.md
    flow-kit-bundle/flow-kit/reference/commit-protocol.md
  </write_files>
  <action>
    1. 7-integration.md 步骤 5（归档）后追加步骤 5.1：归档 commit 指令（D6）
       - git add .specs/archive/<date>-<id>/ + 相关元数据文件（CHANGELOG/CONTEXT/STATE/LESSONS）
       - 按类型拆分原子提交（fix/docs/chore ≤3）
       - PCSC 硬检查：git status --porcelain 输出空
       - 弱模型防护：结构化自检清单（5.1 子步骤 + git status 验证 + 34 号兜底提示）
       - **记录归档起点 ARCHIVE_BASE_SHA=$(git rev-parse HEAD) 到 STATE.md**（D7 · AC-1 Given · **L2 #3 修复**：归档 mv 后、commit 前写入，AC-1 验证方式 `git log $ARCHIVE_BASE_SHA..HEAD` 依赖此锚点）
    2. commit-protocol.md：将「归档 commit 分类」从复用段移到修改段（R13 · 分类漂移修复 · 明确归档 commit 非任务级 commit）
  </action>
  <verify>grep -q '5\.1.*归档' flow-kit-bundle/flow-kit/prompts/7-integration.md && grep -q 'ARCHIVE_BASE_SHA' flow-kit-bundle/flow-kit/prompts/7-integration.md && grep -q '归档.*修改段\|修改段.*归档' flow-kit-bundle/flow-kit/reference/commit-protocol.md</verify>
  <done>7-integration 含步骤 5.1 归档 commit 指令 + commit-protocol.md 归档分类移到修改段（对应 AC-1/AC-4 prompt 层）</done>
  <depends_on>T04, T05, T06</depends_on>
</task>

<task id="T08" status="pending" model-tier="standard">
  <name>bats 回归测试（34 + pre-commit + resume 分支 + 基线 0 fail）</name>
  <read_files>
    test/*.bats
    flow-kit-bundle/hooks/stop/34-archive-commit-check.sh
    flow-kit-bundle/hooks/pre-commit/pre-commit.sh
    flow-kit-bundle/hooks/session-start/flow-kit-resume.sh
    .specs/CONTEXT.md
  </read_files>
  <write_files>
    test/test_archive_commit_gate.bats
  </write_files>
  <action>
    新建 test_archive_commit_gate.bats：
    1. 34-archive-commit-check.sh 骨架测试：module_enabled guard + run_check 回调 + 双模式检测 + correction_file_write 签名
    2. pre-commit.sh 四分支测试：无 Makefile skip / npx 不可见 skip / test fail reject / test pass
    3. flow-kit-resume.sh archive-uncommitted elif 分支测试
    4. 全量基线回归：npx bats test/ 输出 0 not ok（基线 692/692 · STATE.md test-failures-fixup-2026-08）
  </action>
  <verify>npx bats test/ > /tmp/acg-bats.out 2>&1; rc=$?; [ $rc -eq 0 ] && [ "$(grep -c '^not ok' /tmp/acg-bats.out)" = "0" ] && [ "$(grep -c '^ok ' /tmp/acg-bats.out)" -ge 692 ]</verify>
  <done>bats 全量 0 新增 fail（基线 692/692 不变 · 对应 AC-5）</done>
  <depends_on>T07</depends_on>
</task>

## 状态字段说明

- `status="pending"` → 任务待执行（4-dev 阶段逐个执行）
- `status="done"` → 任务完成（verify 通过 + T*-SUMMARY.md 已写）
- `parallel="true"` → 同波次可并行（[P] 标记）
- `model-tier="standard"` → 缺省模型层级（ADR-016）

## model-tier 说明

> ADR-016：task() 调度时 `[MODEL-TIER hint]: standard` 注入 dispatch prompt。
> - cheap → 快速模型（explore/librarian 级）
> - standard → 缺省（Sisyphus-Junior 级）
> - top → 高质量模型（Oracle 级）

## 阻塞日志

| 任务 | 阻塞原因 | 时间 | 解决 |
|------|----------|------|------|
| （无） | | | |

## Fix 任务区

> 盲审/测试发现的问题在此区追加 T-FIX-NN 编号任务。
