# TASK: brooks-lint npm 工具离线打包

- **Change ID**: `bundle-packaging`
- **关联**: `@.specs/bundle-packaging/REQUIREMENT.md`、`@.specs/bundle-packaging/DESIGN.md`

---

## 波次划分

```
Wave 1 (parallel): T01[P], T02[P]
Wave 2:            T03 (depends on T01)
Wave 3:            T04 (depends on T01, T03)
Wave 4:            T05 (depends on T01, T02, T03, T04)
```

> T01/T02 互不冲突（一个建新文件，一个改打包脚本），可并行。T03 需要 T01 的接口定义。T04 需要 T01+T03 的最终行为。T05 全量集成验证。

---

## 任务清单

```xml
<task id="T01" parallel="true" status="pending">
  <name>新建 install_brooks_tools.sh 安装模块</name>
  <read_files>
    flow-kit-bundle/lib/install_brooks.sh
    flow-kit-bundle/lib/install_skills.sh
  </read_files>
  <write_files>
    flow-kit-bundle/lib/install_brooks_tools.sh
  </write_files>
  <action>
    创建 `flow-kit-bundle/lib/install_brooks_tools.sh`，由 install.sh source 调用。
    导出函数 `install_brooks_tools()`，实现：
    1. Node.js 可用性检测 (`command -v node`) → 缺失时输出提示并 return
    2. 从 `$SCRIPT_DIR/brooks-tools/` rsync 到 `~/.claude/tools/brooks-lint/`
    3. 为 4 个工具（depcheck/jscpd/knip/ts-prune）各生成一个 shim 到 `~/.local/bin/`
       shim 格式：
         #!/bin/sh
         exec ~/.claude/tools/brooks-lint/bin/<tool> "$@"
    4. 检测 `~/.local/bin` 是否在 PATH → 不在时输出添加 PATH 的提示
    5. 每个工具安装后输出 `✅ <tool> <version>` 或 `⚠️ <tool> 安装失败`
    6. 支持 `DRY_RUN` 模式（`${DRY_RUN:-false}`）→ 仅打印操作不执行

    沿用模式（见 D5/D3）：
    - 沿用 `install_brooks.sh` 的输出风格（`═══ 标题 ═══` + `   ✅/⚠️/ℹ️` 缩进）
    - 沿用 `install_brooks.sh` 的版本检测模式（jq 优先 + grep fallback）
    - 沿用 `install_skills.sh` 的 DRY_RUN 判断模式
    - 头注释写 `# 由 install.sh source，不可独立执行`
  </action>
  <verify>bash -n flow-kit-bundle/lib/install_brooks_tools.sh &amp;&amp; echo "PASS: syntax OK"</verify>
  <done>新文件语法检查通过；函数签名与 install.sh 调用方式一致；AC-6（Node.js 缺失提示）、AC-8（shim 生成）对应的安装逻辑就绪</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true" status="pending">
  <name>package-flow-kit.sh 新增 Part G（npm 工具打包）</name>
  <read_files>
    package-flow-kit.sh
  </read_files>
  <write_files>
    package-flow-kit.sh
  </write_files>
  <action>
    在 `package-flow-kit.sh` 中新增 Part G（npm 工具离线打包段），插入在 Part F 之后、打包 tar 之前。
    具体改动：

    1. **修改 L22 mkdir 行**：在 staging 目录创建列表末尾追加 `brooks-tools/packs`
    2. **新增 Part G 代码块**（约 50-70 行），实现：
       a. 检测 npm 可用性 (`command -v npm`) → 不可用时输出 `⚠️ npm 未安装，跳过 Part G`
       b. 循环 4 个工具（depcheck@1.4.7, jscpd@5.0.11, knip@6.17.1, ts-prune@0.10.3）
          - `npm pack <tool> --pack-destination=$STAGING/brooks-tools/packs/`
          - 失败时输出警告并 continue（不阻断整体打包）
       c. 解压每个 .tgz 到 `$STAGING/brooks-tools/extracted/<name>/`
       d. 合并各工具的 node_modules → `$STAGING/brooks-tools/node_modules/`
          合并各工具的 bin/ → `$STAGING/brooks-tools/bin/`
       e. 生成 `$STAGING/brooks-tools/manifest.json`：
          `{"tools":{"depcheck":"1.4.7","jscpd":"5.0.11","knip":"6.17.1","ts-prune":"0.10.3"},"platform":"linux-x64","node_min":"18.0.0"}`
       f. 输出 `✅ brooks-tools 打包完成 (<N> 文件, <SIZE>)`
    3. **修改 README heredoc**（L139-L167 区域）：
       - 内容清单加一行：`| brooks-lint 工具 | brooks-tools/ | depcheck/jscpd/knip/ts-prune 离线可用`
    4. **修改最终 echo 清单**（L280+ 区域）：
       - 追加一行：`🔧 brooks-tools（4 个 npm 工具离线包）`

    沿用模式：
    - 沿用 Part F 的 `BROOKS_SRC` / `BROOKS_CACHE` fallback 检测模式
    - 沿用 `echo "📦 Part X: ..."` + `echo "   ✅/⚠️ ..."` 风格
    - 版本号以变量定义在 Part G 顶部（方便后续升级），不硬编码散落在各处
  </action>
  <verify>bash -n package-flow-kit.sh &amp;&amp; echo "PASS: syntax OK" &amp;&amp; grep -q "Part G" package-flow-kit.sh &amp;&amp; echo "PASS: Part G exists"</verify>
  <done>语法检查通过；Part G 存在且包含 4 个工具的版本号；AC-5（打包产出 brooks-tools 目录）、AC-7（现有打包不退化——Part A-F 未变）</done>
  <depends_on></depends_on>
</task>

<task id="T03" status="pending">
  <name>install.sh 集成 brooks-tools 安装</name>
  <read_files>
    flow-kit-bundle/install.sh
    flow-kit-bundle/lib/install_brooks_tools.sh
    flow-kit-bundle/lib/install_brooks.sh
  </read_files>
  <write_files>
    flow-kit-bundle/install.sh
  </write_files>
  <action>
    修改 `flow-kit-bundle/install.sh`，集成 brooks-tools 安装流程：

    1. **新增 `check_node()` 函数**（在 usage() 之后）：
       - 检测 `command -v node` → 设置全局变量 `NODE_AVAILABLE=true/false`
       - 仅在 brooks-tools 安装前调用，不影响其他组件
    2. **新增 `--no-brooks-tools` flag**（在现有 `--no-brooks` 附近）：
       - usage() 帮助文本追加一行
       - 参数解析 case 块追加 `--no-brooks-tools` 分支
    3. **在 install_brooks_lint 调用之后，追加 brooks-tools 安装**：
       ```
       if [ "${NO_BROOKS_TOOLS:-false}" != true ]; then
         check_node
         if [ "$NODE_AVAILABLE" = true ]; then
           source "$SCRIPT_DIR/lib/install_brooks_tools.sh"
           install_brooks_tools
         else
           echo "⚠️ Node.js 未安装，跳过 brooks-lint 工具安装。"
           echo "   请先安装 Node.js ≥ 18：dnf module install nodejs:18"
         fi
       fi
       ```
    4. **确保错误处理一致**：Node.js 缺失不设 exit 1（不阻断其他组件安装）

    沿用模式（见 D5）：
    - 沿用现有 `--no-*` flag 命名和解析风格
    - 沿用 `source "$SCRIPT_DIR/lib/install_*.sh"` 模式
    - 不影响 `install_brooks_lint()` 的现有逻辑
  </action>
  <verify>bash -n flow-kit-bundle/install.sh &amp;&amp; echo "PASS: syntax OK" &amp;&amp; grep -q "check_node" flow-kit-bundle/install.sh &amp;&amp; echo "PASS: check_node integrated"</verify>
  <done>语法检查通过；--no-brooks-tools flag 可用；Node.js 缺失时输出提示且不阻断安装（AC-6）</done>
  <depends_on>T01</depends_on>
</task>

<task id="T04" status="pending">
  <name>bats 测试：install_brooks_tools.sh 单元测试 + 回归</name>
  <read_files>
    flow-kit-bundle/lib/install_brooks_tools.sh
    flow-kit-bundle/install.sh
    test/test_install.bats
    test/test_common.bats
    package-flow-kit.sh
  </read_files>
  <write_files>
    test/test_install_brooks_tools.bats
  </write_files>
  <action>
    新建 `test/test_install_brooks_tools.bats`，覆盖：

    1. **语法检查**：`bash -n lib/install_brooks_tools.sh` 通过
    2. **DRY_RUN 模式**：`DRY_RUN=true source lib/install_brooks_tools.sh; install_brooks_tools` 输出含 `[DRY-RUN]`
    3. **Node.js 缺失处理**：模拟 `command -v node` 返回非 0，验证函数 return 且输出含 `⚠️`
    4. **shim 生成**（DRY_RUN 模式）：验证输出含 4 个工具的 shim 路径（`~/.local/bin/depcheck` 等）
    5. **回归测试**：运行现有 `npx bats test/` 确保 72 tests 全通过（AC-7）

    沿用模式：
    - 沿用 `test_install.bats` 的 `setup()` / `teardown()` 结构
    - 沿用 `run` + `assert_success` / `assert_output --partial` 断言风格
    - 使用 bats `load` 机制复用 common 函数
  </action>
  <verify>npx bats test/test_install_brooks_tools.bats &amp;&amp; echo "PASS: new tests" &amp;&amp; npx bats test/ &amp;&amp; echo "PASS: regression 72 tests"</verify>
  <done>新测试全部通过；现有 72 tests 无退化（AC-7）</done>
  <depends_on>T01, T03</depends_on>
</task>

<task id="T05" status="pending">
  <name>端到端验证：打包 → 离线安装 → 工具可用</name>
  <read_files>
    package-flow-kit.sh
    flow-kit-bundle/install.sh
    flow-kit-bundle/lib/install_brooks_tools.sh
    .specs/bundle-packaging/REQUIREMENT.md
    .specs/bundle-packaging/DESIGN.md
  </read_files>
  <write_files>
  </write_files>
  <action>
  端到端验证（write_files 为空——仅执行验证命令，不修改文件）：

  1. **打包验证**（AC-5）：
     - 执行 `bash package-flow-kit.sh /tmp/brooks-pack-test`
     - 检查 tarball 存在 + 包含 `brooks-tools/` 目录
     - `tar tzf /tmp/brooks-pack-test/flow-kit-full-*.tar.gz | grep 'brooks-tools/' | wc -l` ≥ 20

  2. **安装 dry-run 验证**（AC-6）：
     - 解压 tarball 并执行 `./install.sh --global --dry-run`
     - 验证输出含 4 个工具的 [DRY-RUN] 安装提示

  3. **bats 全量回归**（AC-7）：
     - `npx bats test/` → 全部通过（含新增的 test_install_brooks_tools.bats）

  4. **手动清单对照**：
     - 对照 AC-1~AC-8 逐条确认已覆盖或当前验证环境下可等价验证
     - 记录无法在当前环境验证的 AC（如 AC-1~AC-4 需要真实的离线 Node.js 环境）→ 标记为"待目标环境验证"

  5. 清理临时测试目录
  </action>
  <verify>
    bash package-flow-kit.sh /tmp/brooks-pack-test &amp;&amp;
    tar tzf /tmp/brooks-pack-test/flow-kit-full-*.tar.gz | grep -c 'brooks-tools/' &amp;&amp;
    npx bats test/ &amp;&amp;
    echo "PASS: E2E verification"
  </verify>
  <done>AC-5/AC-6/AC-7 在当前环境验证通过；AC-1~AC-4 记录为"待目标环境验证"；测试临时目录已清理</done>
  <depends_on>T01, T02, T03, T04</depends_on>
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
