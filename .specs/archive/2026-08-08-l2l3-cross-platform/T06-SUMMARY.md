# T06-SUMMARY — flow-kit-resume.sh l3-model-missing banner 平台感知凭证指引

- **Change**: l2l3-cross-platform
- **Task**: T06
- **执行**: 2026-08-07
- **改动文件**: `flow-kit-bundle/hooks/session-start/flow-kit-resume.sh`（唯一改动文件 · git diff: 11 insertions / 0 deletions）

## 做了什么

`l3-model-missing` correction banner（原 L123-134）按平台差异化，**claude code 分支文本零改动**（done 准则），opencode 分支追加凭证指引：

1. **common.sh source**（沿用本文件 L175/176 既有相对 source 模式）：
   ```bash
   script_dir="$(cd "$(dirname "$0")" && pwd)"
   common_lib="${script_dir}/../stop/lib/common.sh"
   [ -f "$common_lib" ] && source "$common_lib" 2>/dev/null || true
   ```
   置于 l3-model-missing 分支顶部（`script_dir` 首次定义于此，L174/L203 的既有定义不受影响——重复赋值语义等价）。

2. **平台判定**（D2 单点封装，禁止内联 `[[ -n $OPENCODE ]]`）：`if fk_platform_is_opencode; then` 包裹 4 行新增（1 分隔行 + 3 指引行，均对齐 52 字符内容区，与 `export FLOW_KIT_L3_MODEL` 行同宽）：
   ```
   ║                                                    ║
   ║    同时确保 opencode 启动环境已 export                      ║
   ║    FLOW_KIT_L3_BASE_URL + FLOW_KIT_L3_AUTH_TOKEN   ║
   ║    （hook 子进程继承启动 env）                              ║
   ```
   - env 完整名（`FLOW_KIT_L3_BASE_URL` / `FLOW_KIT_L3_AUTH_TOKEN`）落在 resume banner 内 —— 符合 **DESIGN D3** 载体边界（banner 可含 env 完整名；correction message 只写 `FLOW_KIT_L3_* 未配置`，凭证不落盘红线未触碰——本任务不动 correction 写入侧）。
   - 平台语义（D2）：`fk_platform_is_opencode` = `OPENCODE_BIN` 或 `OPENCODE` 任一非空 → opencode；否则 claude code（走 `export FLOW_KIT_L3_MODEL` + `/flow model l3=` 原指引）。
3. **l2-model-missing banner（原 L135-145）未触碰**；`FLOW_KIT_L3_BASE_URL` 全文件仅 1 处（l3 分支新增行）。

## verify 真实输出

TASK 原样命令（裸跑）：空 stdin + 仓库根 cwd 下 `.flow-active` 不存在 → 脚本 L33 提前 `exit 0`，banner 不打印，`grep -q` 不命中（rc=1）。此为**环境性**（无 .flow-active 场景），非代码缺陷——TASK 已预见并允许「构造场景后断言式 verify」。构造完整场景后全部断言真实通过：

```
── ① bash -n ──
PASS: syntax ok
── ② grep 调用点 ──
PASS: call site present
── ③ 构造运行时场景 ──（/tmp/opencode/t06-proj/.flow-active + .flow-active.correction type=l3-model-missing）
── ④ opencode 分支（OPENCODE=1，断言含 FLOW_KIT_L3_BASE_URL）──
PASS: opencode banner 含凭证指引
── ⑤ CC 分支（env -u OPENCODE -u OPENCODE_BIN，断言不含 FLOW_KIT_L3_BASE_URL）──
PASS: CC banner 无凭证行
PASS: CC banner 保留原指引（export FLOW_KIT_L3_MODEL + /flow model l3=）
```

> 注：会话 shell 本身带 `OPENCODE=1`，首轮 CC 断言误判为含凭证行——用 `env -u OPENCODE -u OPENCODE_BIN` 剥离后确认 CC 分支正确回退原文本（见下方排查记录）。

## 排查记录

- ⑤ 首轮失败（CC 输出含凭证行）→ 排查发现 shell 环境已 export `OPENCODE=1`，`bash script` 继承该变量 → "CC 运行"实为 opencode 运行。非代码问题；`env -u` 剥离后 PASS。
- T01 依赖：**T01 已落地**（`fk_platform_is_opencode()` 存在于 common.sh:321-323，T01-SUMMARY 确认），本任务调用点可正常工作；`if fk_platform_is_opencode; then` 在条件上下文中对 set -e 免疫，即使函数缺失也不会炸脚本（回退 CC 分支），故并行执行安全。

## done 准则核对

| 准则 | 结果 |
|---|---|
| opencode 下 banner 含 FLOW_KIT_L3_BASE_URL/AUTH_TOKEN 指引行 | ✅ ④ PASS |
| CC 下文本不变（原指引 + 无凭证行） | ✅ ⑤ PASS（diff 0 删除，纯 11 行新增且全在 if 块内） |
| 仅改 flow-kit-resume.sh | ✅ git diff 单文件 |
| l2-model-missing banner 不动 | ✅ 未触碰 |
