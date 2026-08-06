# DESIGN · archive-commit-gate

> 阶段 2 技术设计（v2 · L2 盲审 R1-R11 修复后）。

## 0. 技术栈选定

**锁定**：Bash（CONTEXT.md 已锁 · 与既有 hook 生态一致）。无前端、无数据库、无新依赖。

## 0.5 既有架构对齐（brownfield · grep 实证）

### 0.5.1 触碰模块清单（L2 盲审 R1/R3/R13/R14 修复后完整版）

**既有 · 修改**：
- `flow-kit-bundle/hooks/stop/00-gate.sh:120` — run_module 调度行（L120 `33-flow-active-integrity` 后、L123 `99-report` 前追加 `run_module "${HOOK_BASE_DIR}/34-archive-commit-check.sh" "archive_commit_check"`）。**关键**：00-gate.sh 硬编码逐行调度（L78-123），不迭代 HOOK_MODULE_NAMES → 必须显式加 run_module 行（L2 R1 🔴）
- `flow-kit-bundle/hooks/stop/lib/common.sh:270` — `HOOK_MODULE_NAMES` 数组（追加 `34-archive-commit-check`）
- `flow-kit-bundle/hooks/config/stop-hook.json` — modules 开关模板（追加 `"archive_commit_check": {"enabled": true}`）。**关键**：`module_enabled()` 默认 false（common.sh:25），无模板条目 → 34 号静默禁用（L2 R3 🟡）
- `flow-kit-bundle/hooks/stop/lib/correction-types.sh:20-21` — 新增 `readonly CORRECTION_TYPE_ARCHIVE_UNCOMMITTED="archive-uncommitted"`
- `flow-kit-bundle/hooks/session-start/flow-kit-resume.sh:149` — type-dispatch 新增 `archive-uncommitted` elif（插在 `l2-missing` 分支后、else L151 前；else 对未知 type rm -f 清文件——L2 R6 🟡）
- `flow-kit-bundle/flow-kit/prompts/7-integration.md:257` — 步骤 5 内新增 5.1 归档 commit 指导段 + PCSC 自检表新增「git status 干净」检查项（L2 R14 🟢）
- `flow-kit-bundle/flow-kit/reference/commit-protocol.md` — 扩展归档级段（不改任务级段）——移到修改段（L2 R13 🟢）
- `flow-kit-bundle/install.sh:218/242/252` — `install_hooks()` 调用点（追加 pre-commit symlink 部署）+ arg parse 追加 `--yes`→`FLOW_KIT_YES=1` flag（N2 修复：D8 非交互 carrier 缺失，install.sh 当前无此 flag）
- `flow-kit-bundle/lib/install_hooks.sh` — 追加 pre-commit symlink 部署函数 + HOOK_MODULE_NAMES 同步 + 既有冲突检测（D8）
- `package-flow-kit.sh:95-103` — Part D 自动纳入新模块

**既有 · 复用（不改）**：
- `correction-file.sh` — write/read/clear/exists 四函数（clear 是文件级 rm → 34 号须 type-guarded clear 对齐 `write_model_missing_clear()` correction-file.sh:132-144 先例——L2 R4 🟡）
- `common.sh:49` — `run_check(module, check_id, precondition_file, body_fn)` 4 参数回调（L2 R5 🟡）
- `32-fallback-guard.sh`（77 行）— 34 号结构先例
- `28-weak-model-compliance.sh:18` — `module_enabled || exit 0` guard 先例（34 号采用）

**新增**：
- `flow-kit-bundle/hooks/stop/34-archive-commit-check.sh` — Stop hook 新模块
- `flow-kit-bundle/hooks/pre-commit/pre-commit.sh` — git pre-commit hook
- `test/test_archive_commit_gate.bats` — 新增 bats（含 L2 R1 反向完整性：HOOK_MODULE_NAMES 每元素在 00-gate.sh 有对应 run_module 行）

**禁动（声明不碰）**：
- gate 核心链（independent-review-gate.sh + 29-independent-review.sh + fk_validate_done_marker）
- checkpoint-lib.sh
- `.flow-active.goal` 字段（AI 手编禁；hook 读有例外；**D7 不写 .flow-active.goal**——L2 R10 🟡）
- package-flow-kit.sh Part A-E/G
- PRESET_MAP / gate_config schema

### 0.5.2 对齐既有抽象

| 本次需要 | 既有抽象 | 决定 |
|---|---|---|
| Stop hook 模块骨架 | `run_check(module, check_id, precondition_file, body_fn)` | 沿用（body 函数 `_check_archive_commit_body`） |
| Stop hook 模块调度 | 00-gate.sh run_module 硬编码逐行 | 沿用（显式追加 run_module 行） |
| Stop hook 模块开关 | stop-hook.json + module_enabled | 沿用（模板加条目 + 28 号 guard） |
| correction 写入 | correction_file_write() | 沿用 |
| correction 清除 | correction_file_clear(path) 文件级 rm | **type-guarded**：先 read 判 type 才 clear（对齐 write_model_missing_clear） |
| correction type 常量 | correction-types.sh 集中登记 | 沿用（追加第 3 常量） |
| SessionStart banner | flow-kit-resume.sh type-dispatch（4 分支 + else rm） | 沿用（elif 插 l2-missing 后 else 前） |
| hook 部署 | install_hooks() | 沿用（追加 pre-commit 部署） |
| commit 协议 | commit-protocol.md | 扩展（归档级段） |

### 0.5.3 沿用模式 vs 引入新模式

- Stop hook 注册：**沿用** 00-gate.sh run_module + HOOK_MODULE_NAMES + stop-hook.json + run_check（五点接线）
- correction 机制：**沿用** + type-guarded clear
- git hook 部署：**引入新模式**（symlink to `.git/hooks/`，目标指向已安装 hooks 目录）

## 1. 技术决策

### D1 · git pre-commit hook 部署机制

**决策**：symlink `.git/hooks/pre-commit` → **已安装 hooks 目录**下 `pre-commit/pre-commit.sh`（user: `~/.claude/hooks/pre-commit/pre-commit.sh`；project: `${CLAUDE_PROJECT_DIR}/.claude/hooks/pre-commit/pre-commit.sh`）。

> **L2 R8 🟡 修复**：原指向 `flow-kit-bundle/`（打包源布局，目标项目无此目录）→ 悬空 symlink。改指向 install_hooks.sh 实际部署目标（与 stop/session-start hooks 同源）。

**备选**：A. core.hooksPath（全局覆盖·否决）；B. 复制（失同步·否决）。**选 symlink**：最小侵入 + 版本同步 + 幂等。**代价**：每项目部署 + Windows 需开发者模式。

### D2 · pre-commit hook make test 策略

**决策**：分层降级，不 fail-close 死锁。

```
pre-commit.sh 伪代码（L2 R9 🟡 PATH 增强）：
  source /etc/profile 2>/dev/null           # 系统级 PATH
  source ~/.profile 2>/dev/null              # 登录 shell PATH
  [ -n "$NVM_DIR" ] && source "$NVM_DIR/nvm.sh" 2>/dev/null   # nvm（.bashrc 常被 $- 守卫短路）
  export PATH="$HOME/.local/bin:$PATH"      # 显式补全
  if [ ! -f Makefile ]; then echo "[archive-commit-gate] no Makefile, skipping test gate"; exit 0; fi
  if ! command -v npx >/dev/null; then echo "[archive-commit-gate] npx 不可见，门禁跳过（warn）"; exit 0; fi
  make test                                  # 非零退出码拒绝 commit
```

### D3 · Stop hook 34 结构（L2 R2/R3/R4/R5 修复后完整版）

**决策**：检测 = 归档完成 AND git status 非干净。遵循 run_check 4 参数回调 API。

```
34-archive-commit-check.sh 伪代码（F1/F2/F3/F8 修复版）：
  module_enabled "archive_commit_check" || exit 0   # 28 号 guard（L2 R3 · F8: snake_case 对齐 11 key）

  _check_archive_commit_body() {
    # F1: run_check 零参回调（common.sh:55），PROJECT_ROOT env 由 common.sh:124 export
    local flow_active="${PROJECT_ROOT}/.flow-active"
    # 归档完成检测（双模式 · L2 R2 🔴：单阶段也覆盖）
    if jq -e '.goal' "$flow_active" >/dev/null 2>&1; then
      # F3-residual 修复：AC-3 Given 硬条件——scope==pipeline + status==done + archive dir 存在
      [ "$(jq -r '.goal.scope // ""' "$flow_active")" = "pipeline" ] || return 0
      [ "$(jq -r '.goal.status // ""' "$flow_active")" = "done" ] || return 0
      [ -d "${PROJECT_ROOT}/.specs/archive" ] || return 0
    else
      # F3: 单阶段锡点改用 git 最近 commit 时间（epoch 秒），不受 checkpoint bump 干扰
      local arch_dir arch_mtime last_commit_ts
      arch_dir=$(ls -t "${PROJECT_ROOT}/.specs/archive/" 2>/dev/null | head -1)
      [ -n "$arch_dir" ] || return 0
      arch_mtime=$(stat -c %Y "${PROJECT_ROOT}/.specs/archive/$arch_dir" 2>/dev/null || echo 0)
      last_commit_ts=$(cd "${PROJECT_ROOT}" && git log -1 --format=%ct 2>/dev/null || echo 0)
      [ "$arch_mtime" -gt "$last_commit_ts" ] || return 0
    fi
    # git status 检测
    local corr="${PROJECT_ROOT}/.flow-active.correction"
    if [ -z "$(cd "${PROJECT_ROOT}" && git status --porcelain 2>/dev/null)" ]; then
      # 干净 → type-guarded clear（L2 R4：对齐 write_model_missing_clear 先例）
      [ -f "$corr" ] && [ "$(jq -r '.type // ""' "$corr" 2>/dev/null)" = "$CORRECTION_TYPE_ARCHIVE_UNCOMMITTED" ] && correction_file_clear "$corr"
      return 0
    fi
    # 命中 → 写 correction（共存策略：现存其他 type 不覆盖）
    if [ -f "$corr" ]; then
      local cur=$(jq -r '.type // ""' "$corr" 2>/dev/null)
      [ "$cur" != "$CORRECTION_TYPE_ARCHIVE_UNCOMMITTED" ] && [ "$cur" != "" ] && {
        echo "[34] 现存 $cur correction，不覆盖" >&2; return 0; }
    fi
    local fc=$(cd "${PROJECT_ROOT}" && git status --porcelain 2>/dev/null | wc -l)
    # F2: correction_file_write 真签名 <path> <json_data> [strategy]（correction-file.sh:47）
    correction_file_write "$corr" \
      "{\"type\":\"$CORRECTION_TYPE_ARCHIVE_UNCOMMITTED\",\"violations\":[{\"files\":\"$fc\",\"hint\":\"归档后 git status 非干净，请 commit 残留文件\"}]}"
  }
  run_check "archive_commit_check" "AC3" "" _check_archive_commit_body
```

### D4 · flow-kit-resume type-dispatch（L2 R6 修复）

**决策**：l2-missing 分支后、else 前追加 elif。

```
flow-kit-resume.sh 伪代码（L149 后插入）：
  elif [[ "$corr_type" == "archive-uncommitted" ]]; then
    local fc=$(jq -r '(.violations[0].files // (.violations | length) // "??")' "$compliance_correction_file")
    echo "⚠️ 上次归档后 git status 非干净，请 commit 残留文件（$fc 个）"
    rm -f "$compliance_correction_file"   # 读后清
```

> **L2 R6 🟡 修复**：原读 `.file_count`（AC-3 无此字段）→ 改 `.violations[0].files`。**部署顺序**：34 号与 resume 同批发布。

### D5 · correction 常量

`correction-types.sh` 追加 `readonly CORRECTION_TYPE_ARCHIVE_UNCOMMITTED="archive-uncommitted"`。

### D6 · 7-integration 步骤 5.1 归档 commit 指导（L2 R11 修复）

```
7-integration.md 步骤 5.1（新增）：
  归档 mv 后，记录 ARCHIVE_BASE_SHA（git rev-parse HEAD）到 STATE.md。
  按类型拆分 commit（≤3）：
  - fix(<id>): 源码（.sh/.py/.ts 等非 .md 非产物）
  - docs(<id>): 归档产物（.specs/archive/）+ 非 .specs 的 .md（prompts/templates/reference）  ← R11 修复
  - chore(<id>): 元数据（.specs/CHANGELOG/CONTEXT/STATE/LESSONS）
  PCSC 自检表新增「git status 干净」检查项（R14）。
```

### D7 · ARCHIVE_BASE_SHA（L2 R10 修复）

**决策**：记录到 **STATE.md**（不写 .flow-active.goal）。

> **L2 R10 🟡 修复**：原 jq 写 .flow-active.goal.archive_base_sha 撞禁动（AI 手编 .flow-active.goal）+ 无消费方。AC-1 verify 用 bash 变量锚定，STATE.md 供人工查阅。

### D8 · 既有 .git/hooks/pre-commit 冲突处理（L2 R7 新增）

```
install_hooks.sh 伪代码（pre-commit 部署段）：
  local target="$git_dir/hooks/pre-commit" source="<已安装>/pre-commit/pre-commit.sh"
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    [ "${FLOW_KIT_YES:-0}" = "1" ] && { echo "[archive-commit-gate] existing pre-commit: $target, skipped"; return 0; }
    read -p "[archive-commit-gate] existing pre-commit at $target, overwrite? (y/N) " ans
    [ "$ans" = "y" ] || { echo "skipped"; return 0; }
    rm -f "$target"
  fi
  ln -s "$source" "$target"
```

## 2. 数据流 / 架构图

```
┌───────────────────────────────────────────────────────┐
│ 7-integration 步骤 5 归档                              │
│   mv .specs/<id>/ → archive/                           │
│   ↓ 5.1（新增）                                        │
│   ARCHIVE_BASE_SHA → STATE.md                          │
│   AI 按类型分组 commit（fix/docs/chore ≤3）            │
│   PCSC「git status 干净」检查项（新增）                │
└───────────────────┬────────────────────────────────────┘
                    │ AI 忘记 commit
                    ▼
┌───────────────────────────────────────────────────────┐
│ 00-gate.sh（L120.5 新增 run_module 34）                │
│   34-archive-commit-check.sh                           │
│     module_enabled guard                               │
│     归档检测（pipeline goal.status / 单阶段 mtime）    │
│     git status 非空 → correction(type=archive-uncommitted) │
│     干净 → type-guarded clear                          │
└───────────────────┬────────────────────────────────────┘
                    ▼
┌───────────────────────────────────────────────────────┐
│ SessionStart flow-kit-resume.sh                        │
│   type-dispatch archive-uncommitted elif（l2-missing 后）│
│   banner 提示 + 读后清                                 │
└───────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────┐
│ git commit（pre-commit 门禁 · 独立链路）               │
│   .git/hooks/pre-commit symlink → ~/.claude/hooks/...  │
│   PATH 补齐（/etc/profile + NVM_DIR + ~/.local/bin）   │
│   make test / no Makefile→skip / fail→reject      │
└───────────────────────────────────────────────────────┘
```

## 3. ADR

ADR-022 git hook 部署策略（`.specs/adr/022-git-hook-deployment.md`）。symlink 目标 = 已安装 hooks 目录。

## 4. 风险

| # | 风险 | 严重度 | 缓解 |
|---|---|---|---|
| R1 | user-scope 安装后目标项目 `.git/hooks/pre-commit` 未建 | 中 | install.sh `--project <path>` 模式部署（L2 R12 🟢：原 `--deploy-pre-commit` 凭空，改既有 `--project`） |
| R2 | Windows symlink 需开发者模式 | 低 | 检测 OSTYPE msys → fallback 复制 |
| R3 | make test 30-60s 拖慢 commit | 中 | v1 全量；v2 增量 |
| R4 | 34 与 32 时序 | 低 | **00-gate.sh run_module 插入位置**保证（L120 后、L123 前）（L2 R1 🔴：原说 HOOK_MODULE_NAMES 顺序保证依据错误） |
| R5 | 归档 commit 拆分弱模型跳过 | 中 | 5.1 结构化自检 + PCSC 检查项 + Stop hook 34 兜底 |
| R6 | staged 恶意测试（REQUIREMENT NFR 安全 L222 指令 DESIGN 评估） | 低 | pre-commit `make test` 运行 repo 测试代码是固有语义，非外部输入注入；install.sh `--project` 用户显式信任（F7 修复） |

## 5. 不在范围内

- 自动 push / commit msg lint / 增量测试（v2）
- 改 4-dev protocol / gate 核心链（CHANGE.md 排除）

> 单阶段归档检测（L2 R2）**已入 v1**（D3 双模式）。

## 9. 架构沉淀建议

### 9.1 N/A（全程复用既有抽象）

### 9.2 git hook 部署 = symlink to .git/hooks/（ADR-022 · 目标=已安装 hooks 目录）

### 9.3 pre-commit 部署契约：源 `hooks/pre-commit/<name>.sh` → install_hooks.sh 部署到 `~/.claude/hooks/pre-commit/` → `.git/hooks/<name>` symlink 指向已安装位置（L2 R8 🟡）

### 9.4 N/A

### 9.5 新增禁动：`.git/hooks/pre-commit` symlink + `pre-commit.sh` + `34-archive-commit-check.sh`
