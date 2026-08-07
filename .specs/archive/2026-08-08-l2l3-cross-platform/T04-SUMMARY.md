# T04-SUMMARY — l3-review.sh 派发提示 box 双模式

- **Change**: l2l3-cross-platform
- **Task**: T04（parallel · 独立）
- **文件**: `flow-kit-bundle/hooks/stop/lib/l3-review.sh`（唯一改动文件）
- **执行日期**: 2026-08-07

## 做了什么

### 1. 派发提示 box 双模式（`l3_dispatch_prompt` 内 `cat <<DISPATCH_EOF` 块）

**锚点实测**：TASK.md 标注 L202-224，实际 box 位于 **L205-243**（行号漂移，以实际内容为准）。边框为 **64 显示列**（TASK 说的 68 为过时数字）。

原 box 单 `subagent_type` 行改为双模式并列两行 + 平台注释：

```
║      # claude code 平台: subagent_type 路由                  ║
║      subagent_type: "general-purpose",                       ║
║      # opencode 平台: task(category=...) 路由                ║
║      category: "unspecified-high",                           ║
```

- **claude code 分支保留**：`subagent_type: "general-purpose"`（原行原样）
- **opencode 分支新增**：`category: "unspecified-high"` + 注释行说明 `task(category=...)` 路由语义
- **宽度说明**：TASK 字面建议行 `category: "unspecified-high"（opencode 平台：task(category=...) 路由）` 展开后 71 显示列 > 62 内容区，无法单行容纳；故拆为「注释行 + category 行」两行结构（与 T03 l2-detect.sh 的「并列两行」同构），语义完整且边框不破。

### 2. box 边框宽度整体重对齐

原 box 多处破损（213/216/222 等行超 64 列，226/228 等行不足 64 列）。本次将整个 DISPATCH_EOF box 重排为**每行精确 64 显示列**（含 CJK/框线字符宽计算），并：

- 标题行 `L3 外部模型审查未完成` 压缩为 `L3 审查未完成`（原 72 列超宽，64 列装不下）
- 长命令行（`l3_review_run ...`）用 `\` 续行拆为多行
- `.md (追加 L3 段)` 改全角括号 `（追加 L3 段）` 对齐
- **验证**：box 区域 37 行全部 = 64 列（unicodedata east_asian_width 计算，0 处破损）

### 3. 文件头环境变量依赖注释（原 L18-22，现 L18-24）

在 ANTHROPIC_* 四行后追加两行：

```
#   FLOW_KIT_L3_BASE_URL   — L3 API endpoint（opencode 平台路径 · hook 子进程继承启动 env）
#   FLOW_KIT_L3_AUTH_TOKEN — L3 鉴权 token（opencode 平台路径 · 凭证不落盘）
```

## Verify 输出（真实执行）

```bash
$ bash -n flow-kit-bundle/hooks/stop/lib/l3-review.sh; echo "bash -n rc=$?"
bash -n rc=0

$ grep -n "category:" flow-kit-bundle/hooks/stop/lib/l3-review.sh
217:║      category: "unspecified-high",                           ║

$ grep -n "FLOW_KIT_L3_BASE_URL\|FLOW_KIT_L3_AUTH_TOKEN" flow-kit-bundle/hooks/stop/lib/l3-review.sh
23:#   FLOW_KIT_L3_BASE_URL   — L3 API endpoint（opencode 平台路径 · hook 子进程继承启动 env）
24:#   FLOW_KIT_L3_AUTH_TOKEN — L3 鉴权 token（opencode 平台路径 · 凭证不落盘）

$ sed -n '206,242p' flow-kit-bundle/hooks/stop/lib/l3-review.sh | <width-check>
sampled box lines 206-242: 37 all 64 cols
```

| 检查项 | 结果 |
|---|---|
| `bash -n` 语法 | ✅ rc=0 |
| `grep -n "category:"` | ✅ L217（box 内含 category 双模式分支） |
| 边框对齐（grep 抽样） | ✅ box 37 行全部 64 显示列，0 破损 |
| 文件头 env 注释 | ✅ FLOW_KIT_L3_BASE_URL / FLOW_KIT_L3_AUTH_TOKEN 两行已加 |
| diff 边界 | ✅ 仅 l3-review.sh 一个文件（git diff 确认） |
| 引号/字符串完整性 | ✅ box 是 heredoc 文本，无引号破坏，bash -n 通过佐证 |

## 6 维自查

1. **范围合规** — ✅ 仅改 `write_files` 指定文件 l3-review.sh；未触碰 .specs/ 下 REQUIREMENT/DESIGN、未碰 gate 核心链、未改其他 10 个并行任务文件
2. **语法安全** — ✅ `bash -n` rc=0；box 为 `cat <<DISPATCH_EOF` 字符串字面量，新增行不破坏引号
3. **done 满足** — ✅ L217 box 含双模式分支（subagent_type + category 并列两行）；边框 grep 抽样全 64 列未破损；bash -n 通过
4. **锚点准确性** — ✅ 按实际内容定位（L205-243 非 L202-224），TASK 中 68 列/行号均为过时数据，以实测 64 列为准
5. **可观测性/安全** — ✅ 仅文本模板改动；凭证 env 只出现在文件头文档注释，不涉及 token 值落盘
6. **测试** — ✅ verify 命令真实执行并贴输出（见上）；无新增逻辑故不新增 bats 用例（T11 为整体测试任务）

## 偏离 DESIGN/TASK 说明

- **宽度**：TASK 写「当前 68 字符宽」，实测边框 64 列（TASK 行号与尺寸均已漂移）。以 64 列为基准重排。
- **opencode 分支行格式**：TASK 字面建议「单行含注释」，因 71 列超宽改为「注释行 + category 行」两行并列（语义等价，边框不破）。
- **标题行**：原标题超宽（72 列），压缩「外部模型审查」为「审查」以对齐 64 列；含义保留。

未 commit（按要求）。
