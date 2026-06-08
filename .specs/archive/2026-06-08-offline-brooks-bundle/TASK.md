# TASK: 打包脚本离线化 brooks-lint 分发

- **Change ID**: `offline-brooks-bundle`
- **关联**: `@.specs/offline-brooks-bundle/REQUIREMENT.md`、`@.specs/offline-brooks-bundle/DESIGN.md`

---

## 波次划分

```
Wave 1:  T01    （修改 Part F + 参数解析，约 30 行 diff）
Wave 2:  T02    （验证 5 条 AC）
```

> T02 依赖 T01 产出；无并行任务（本 change 只有一个写代码任务）。

---

## 任务清单

```xml
<task id="T01" parallel="false" status="done">
  <name>重构 Part F brooks-lint 打包逻辑：rsync 优先 + fallback git archive</name>
  <read_files>
    package-flow-kit.sh
    <!-- 读全文（590 行），重点 Part F L504-530 + 参数解析 L250-260 -->
    .specs/offline-brooks-bundle/DESIGN.md
    <!-- 读 ## 2.1 数据流 + ## 0.5.1 触碰模块 -->
    .specs/CONTEXT.md
    <!-- 读 禁动清单 + 命名约定 -->
  </read_files>
  <write_files>
    package-flow-kit.sh
    <!-- 仅改 Part F（L504-530）+ 参数解析段 -->
  </write_files>
  <action>
    1. 参数解析段（L250-260 附近）：新增 `--brooks-src)` flag 处理
       ```
       --brooks-src)   BROOKS_SRC="$2"; shift ;;
       ```
    2. Part F 段（L504-530）重写为：
       - 定义 `BROOKS_CACHE="$HOME/.claude/plugins/cache/brooks-lint-marketplace/brooks-lint"`
       - 检测 `BROOKS_SRC` 是否已设置（用户通过 --brooks-src 指定）
       - 否则检测 `$BROOKS_CACHE` 是否存在且非空
         - 是 → `VERSION=$(ls -1 "$BROOKS_CACHE" | sort -V | tail -1)`;
           rsync -a "$BROOKS_CACHE/$VERSION/" "$STAGING/brooks-lint/plugin/" --exclude='.git'
         - 否 → echo warn；回退到原有 git archive 逻辑
    3. F1（命令入口文件）部分保持不变（L510-520 附近的 cp brooks-*.md 逻辑）
    4. 日志输出明确标注来源：`本地缓存 vX.Y.Z` / `git archive（fallback）` / `--brooks-src`
    5. 遵循 .specs/CONTEXT.md 的命名约定（变量大写 snake_case / 缩进 2 空格）
    6. package-flow-kit.sh 顶部变量声明区新增 `BROOKS_SRC=""`
  </action>
  <verify>bash -n package-flow-kit.sh && echo "syntax OK" && grep -c "BROOKS_CACHE\|BROOKS_SRC\|rsync.*brooks-lint" package-flow-kit.sh</verify>
  <done>Part F 使用 rsync 从本地缓存打包；--brooks-src 参数可用；缓存不可用时 fallback git archive。对应 AC-1~AC-4。</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="false" status="done">
  <name>运行 5 条 AC 验证</name>
  <read_files>
    package-flow-kit.sh
    <!-- 验证 T01 修改结果 -->
    .specs/offline-brooks-bundle/REQUIREMENT.md
    <!-- 读 5 条 AC 验证命令 -->
  </read_files>
  <write_files>
    <!-- 不写文件。仅运行验证命令。 -->
  </write_files>
  <action>
    逐条执行 REQUIREMENT.md 中的 AC 验证：

    AC-1 · rsync 离线打包：
      模拟（dry-run）：确认 BROOKS_CACHE 路径存在 + rsync 命令语法正确
      `ls ~/.claude/plugins/cache/brooks-lint-marketplace/brooks-lint/`
    
    AC-2 · --brooks-src：
      `grep -n "brooks-src" package-flow-kit.sh` 确认参数解析存在
      `grep -n "BROOKS_SRC" package-flow-kit.sh` 确认变量被使用
    
    AC-3 · fallback git archive：
      `grep -c "git archive" package-flow-kit.sh` ≥ 1（fallback 路径未删除）
    
    AC-4 · 版本自动选择：
      `grep -c "sort -V" package-flow-kit.sh` ≥ 1
    
    AC-5 · 离线安装兼容：
      确认 install_brooks_lint() 函数未被修改（与 T01 前的版本一致）
      `git diff HEAD package-flow-kit.sh | grep -c "install_brooks_lint"` == 0
  </action>
  <verify>bash -n package-flow-kit.sh && echo "=== AC-1 ===" && ls ~/.claude/plugins/cache/brooks-lint-marketplace/brooks-lint/ && echo "=== AC-2 ===" && grep -c "brooks-src" package-flow-kit.sh && echo "=== AC-3 ===" && grep -c "git archive" package-flow-kit.sh && echo "=== AC-4 ===" && grep -c "sort -V" package-flow-kit.sh</verify>
  <done>5 条 AC 全部验证通过。对应 REQUIREMENT.md AC-1~AC-5。</done>
  <depends_on>T01</depends_on>
</task>
```

---

## 状态字段说明

- `status="done"` — 未开始
- `status="in_progress"` — 进行中
- `status="done"` — 已完成（verify 通过）

---

## 阻塞日志

| 任务 | 阻塞原因 | 待人工决策项 | 时间 |
|---|---|---|---|
|  |  |  |  |

---

## Fix 任务（来自 REVIEW / INTEGRATION）

```xml
<!-- 占位 -->
```
