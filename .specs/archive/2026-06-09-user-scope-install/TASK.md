# TASK: 支持 flow-kit 核心引擎 user-scope 全局安装

- **Change ID**: `user-scope-install`
- **关联**: `@.specs/user-scope-install/REQUIREMENT.md`、`@.specs/user-scope-install/DESIGN.md`

---

## 波次划分

```
Wave 1 (parallel): T01[P], T02[P], T03[P]   ← 三个文件互不冲突
Wave 2:            T04                         ← 端到端验证 (depends on T01, T02)
```

> 同 wave = 可并行；跨 wave = 必须顺序执行。

---

## 任务清单

```xml
<task id="T01" parallel="true" status="done">
  <name>install.sh 新增 --user 安装模式</name>
  <read_files>
    flow-kit-bundle/install.sh
    flow-kit-bundle/config/settings-hooks.json
  </read_files>
  <write_files>
    flow-kit-bundle/install.sh
  </write_files>
  <action>
    在 install.sh 中实现 --user flag 的完整支持。具体改动：

    1. 参数解析（line 14-25）新增 --user 分支，设置 USER_MODE=true
    2. --help 输出新增 --user 说明
    3. 步骤 1/6（line 58-69）在 --user 模式下改行为：
       a. 如果 ~/.claude/flow-kit/ 不存在 → rsync 到 ${HOME}/.claude/flow-kit/
       b. 如果 ~/.claude/flow-kit/ 已存在 → warn "already exists, skipping"
       c. 无论 a 或 b → ln -s ${HOME}/.claude/flow-kit ${TARGET}/flow-kit
       d. 如果 ${TARGET}/flow-kit 已存在（物理目录或 symlink）→ warn "already exists, skipping symlink"
    4. 步骤 1 描述文案改为 "1/6: flow-kit core → ~/.claude/flow-kit/ (user-scope)"
    5. --dry-run 模式下对应输出 "(dry-run) rsync/ln -s ..."
    6. 验证段（line 173-182）增加 symlink 检查：ls -l flow-kit | grep '->.*\.claude/flow-kit'
    7. 沿用既有 dry() step() info() warn() err() ok() fail() 函数，不引入新辅助函数
    8. 遵循现有代码风格：set -euo pipefail、kebab-case 变量名（USER_MODE）、color codes
  </action>
  <verify>bash -n flow-kit-bundle/install.sh && echo "✅ syntax OK"</verify>
  <done>install.sh 支持 --user flag；bash -n 语法检查通过；覆盖 AC-1、AC-2、AC-5、AC-6</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true" status="done">
  <name>flow-go SKILL.md 新增两级文件查找</name>
  <read_files>
    flow-kit-bundle/skills/flow-go/SKILL.md
  </read_files>
  <write_files>
    flow-kit-bundle/skills/flow-go/SKILL.md
  </write_files>
  <action>
    在 flow-go SKILL.md 入口处（「第一步」之前）插入一个新的前置段：

    ```
    ## 第〇步 · 确定 flow-kit 根目录（两级查找）

    1. 检查项目根目录是否存在 `flow-kit/GO.md`
       → 存在（物理目录或 symlink）→ FLOW_KIT_ROOT = "flow-kit"
       → 使用项目级 flow-kit（允许项目锁定版本）
    2. 不存在 → 检查 `~/.claude/flow-kit/GO.md`
       → 存在 → FLOW_KIT_ROOT = "~/.claude/flow-kit"（使用 user-scope 全局安装）
       → 不存在 → 报错提示：
         "❌ 未找到 flow-kit 核心引擎。请运行: bash ~/flow-kit-bundle/install.sh --user <项目路径>"
    3. 后续所有 `flow-kit/` 路径引用替换为 `${FLOW_KIT_ROOT}/...`
    ```

    注意：
    - 此段需放在「第一步 · 读取项目状态」之前
    - 后续的「第四步 · 加载工件」中的 `flow-kit/` 路径全部改为 `${FLOW_KIT_ROOT}/...`
    - 「自检」部分的 Token 预算引用保持不变（它们引用的是 flow-kit/ 模式，运行时由 AI 替换为实际 FLOW_KIT_ROOT）
    - 断链 symlink 也可被 AI 检测到（`flow-kit/GO.md` 不存在即视为断链）
    覆盖 D2（project-priority fallback）+ R1（断链报错）缓解措施
  </action>
  <verify>
    检查 flow-go SKILL.md 中是否包含 "FLOW_KIT_ROOT" 关键词:
    grep -c "FLOW_KIT_ROOT" flow-kit-bundle/skills/flow-go/SKILL.md | xargs -I{} bash -c '[ {} -ge 3 ] && echo "✅ two-level lookup present" || echo "❌ missing"'
  </verify>
  <done>flow-go 入口检测到 FLOW_KIT_ROOT 变量；覆盖 AC-3、AC-4</done>
  <depends_on></depends_on>
</task>

<task id="T03" parallel="true" status="done">
  <name>更新 INSTALL.md 文档说明 --user 模式</name>
  <read_files>
    flow-kit-bundle/INSTALL.md
  </read_files>
  <write_files>
    flow-kit-bundle/INSTALL.md
  </write_files>
  <action>
    在 INSTALL.md「安装步骤」段之前新增一个「安装模式选择」小节：

    ```
    ### 安装模式

    | 模式 | 命令 | flow-kit 核心位置 | 适用场景 |
    |---|---|---|---|
    | 项目级（默认） | `bash install.sh <project>` | `<project>/flow-kit/`（物理目录） | 单项目、锁定版本、离线环境 |
    | 用户级（推荐） | `bash install.sh --user <project>` | `~/.claude/flow-kit/`（全局一份，项目 symlink） | 多项目、统一升级、新用户首次安装 |

    > **推荐 --user 模式**：升级 `~/.claude/flow-kit/` 一处，所有项目即时生效。
    > 如果项目需要锁定特定版本，在项目根目录放一个物理 `flow-kit/` 目录即可（project-priority fallback）。
    ```

    同时更新：
    1. 步骤 1 增加 --user 模式的说明
    2. 安装后验证增加 symlink 检查项
    3. 末尾添加 "clone 后需重跑 install.sh --user" 的注意事项（缓解 R1）
  </action>
  <verify>grep -c "\-\-user" flow-kit-bundle/INSTALL.md | xargs -I{} bash -c '[ {} -ge 2 ] && echo "✅ --user documented" || echo "❌ missing"'</verify>
  <done>INSTALL.md 含完整的 --user 模式文档；覆盖 AC-1 的用户可见文档</done>
  <depends_on></depends_on>
</task>

<task id="T04" parallel="false" status="done">
  <name>端到端验证：dry-run + 安装 + 回退</name>
  <read_files>
    flow-kit-bundle/install.sh
    flow-kit-bundle/skills/flow-go/SKILL.md
  </read_files>
  <write_files>
    <!-- 验证任务，不写生产文件 -->
  </write_files>
  <action>
    在 /tmp 下创建测试项目，完整验证 --user 模式的全部 AC：

    1. **AC-6 验证（向后兼容）**：
       - 在 /tmp/test-project-1（无 flow-kit/）执行 `bash install.sh --dry-run /tmp/test-project-1`
       - 确认输出不含 symlink，仍显示 `rsync → /tmp/test-project-1/flow-kit/`

    2. **AC-5 验证（dry-run）**：
       - 执行 `bash install.sh --dry-run --user /tmp/test-project-2`
       - 确认输出含 "(dry-run)" + "~/.claude/flow-kit" + "ln -s"

    3. **AC-1 验证（首次 --user）**：
       - 确认 ~/.claude/flow-kit/ 不存在
       - 执行 `bash install.sh --user /tmp/test-project-2`
       - 确认 ~/.claude/flow-kit/GO.md 存在
       - 确认 /tmp/test-project-2/flow-kit 为 symlink → ~/.claude/flow-kit

    4. **AC-2 验证（复用 user-scope）**：
       - ~/.claude/flow-kit/ 已存在，记录其 GO.md 的 md5sum
       - 执行 `bash install.sh --user /tmp/test-project-3`
       - 确认 ~/.claude/flow-kit/ GO.md md5sum 未变（未被覆盖）
       - 确认 /tmp/test-project-3/flow-kit 为新 symlink

    5. **AC-3 验证（项目级优先）**：
       - 在 /tmp/test-project-4 创建实体 flow-kit/ 目录 + 假的 GO.md
       - 验证 flow-go lookup 逻辑应检测到项目级 flow-kit/ 存在

    6. 清理测试项目
  </action>
  <verify>
    bash -c '
    # 综合验证脚本
    set -euo pipefail
    echo "=== AC-6: 默认模式 dry-run ==="
    bash ~/unisoc/flow-kit/flow-kit-bundle/install.sh --dry-run /tmp/test-ac6 2>&1 | grep -q "flow-kit core → /tmp/test-ac6/flow-kit" && echo "✅ AC-6 pass"

    echo "=== AC-5: --user dry-run ==="
    bash ~/unisoc/flow-kit/flow-kit-bundle/install.sh --dry-run --user /tmp/test-ac5 2>&1 | grep -q "ln -s" && echo "✅ AC-5 pass"

    echo "=== AC-1+2: 首次/复用 --user install ==="
    [ -f ~/.claude/flow-kit/GO.md ] && echo "✅ user-scope flow-kit exists"
    [ -L /tmp/test-ac5/flow-kit ] 2>/dev/null || echo "(dry-run — no symlink expected)"

    echo "=== Syntax checks ==="
    bash -n ~/unisoc/flow-kit/flow-kit-bundle/install.sh && echo "✅ install.sh syntax OK"

    echo "=== flow-go lookup check ==="
    grep -q "FLOW_KIT_ROOT" ~/unisoc/flow-kit/flow-kit-bundle/skills/flow-go/SKILL.md && echo "✅ flow-go has lookup"

    echo "=== INSTALL.md check ==="
    grep -q "\-\-user" ~/unisoc/flow-kit/flow-kit-bundle/INSTALL.md && echo "✅ INSTALL.md has --user doc"

    echo "ALL VERIFICATIONS PASSED"
    '
  </verify>
  <done>全部 6 条 AC 通过验证；覆盖 AC-1 到 AC-6</done>
  <depends_on>T01, T02</depends_on>
</task>
```

---

## 状态字段说明

- `status="pending"` — 未开始
- `status="in_progress"` — 进行中（同时只允许一个非 [P] 任务为此状态）
- `status="done"` — 已完成（verify 通过）
- `status="blocked"` — 阻塞（必须在文件末尾「阻塞日志」记录）

---

## 阻塞日志

| 任务 | 阻塞原因 | 待人工决策项 | 时间 |
|---|---|---|---|
|  |  |  |  |

---

## Fix 任务（来自 REVIEW / INTEGRATION）

> 此区域由 review/integration 阶段自动追加，编号 `T-FIX-XX`。

```xml
<!-- 占位 -->
```
