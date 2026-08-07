# T01-SUMMARY — common.sh 新增 fk_resolve_api_credentials + fk_platform_is_opencode

- **Change**: l2l3-cross-platform
- **Task**: T01
- **执行**: 2026-08-07
- **改动文件**: `flow-kit-bundle/hooks/stop/lib/common.sh`（唯一改动文件 · git diff: 59 insertions / 0 deletions）

## 做了什么

在 `common.sh` 的 `fk_resolve_model()`（L249-264）之后、`HOOK_MODULE_NAMES` 注册表（L325）之前插入两个公共函数：

1. **`fk_resolve_api_credentials()`**（L277-314 · DESIGN D1）— 三 Path 优先级凭证解析：
   - **Path1**：`ANTHROPIC_AUTH_TOKEN` 非空 → `FK_API_AUTH_TOKEN`=token、`FK_API_BASE_URL`=`ANTHROPIC_BASE_URL`（缺省 `https://api.anthropic.com`）、`FK_API_AUTH_SCHEME=bearer`，rc=0（claude code 原生主路径）
   - **Path3**：否则 `FLOW_KIT_L3_AUTH_TOKEN` 非空 → base_url 非空则 `FK_API_*`=对应值、`scheme=bearer`、rc=0（opencode 一等路径，**短路 Path2**）；base_url 空 → stderr 报「FLOW_KIT_L3_AUTH_TOKEN 已设但 FLOW_KIT_L3_BASE_URL 为空（Path3 配置不完整，rc=2）」+ rc=2，**禁止静默落 Path2**，且清空三个全局
   - **Path2**：否则 `ANTHROPIC_API_KEY` 非空 → token=key、base=`https://api.anthropic.com`（legacy 硬编码端点）、`FK_API_AUTH_SCHEME=x-api-key`、rc=0
   - 全空 → 清空三个全局 + rc=1
   - 所有 env 用 `${VAR:-}` 读取（set -u 兼容）；凭证不输出到 stdout，仅写全局变量（AC-6 红线：凭证完整名/值不落盘，stderr 只含 env 变量名）

2. **`fk_platform_is_opencode()`**（L321-323 · DESIGN D2）— `[ -n "${OPENCODE_BIN:-}" ] || [ -n "${OPENCODE:-}" ]`，任一非空返回 0（opencode），否则 1（claude code）。纯查询零副作用。

函数头注释：三 Path 优先级 + rc 语义 + credential source 日志约定 + AC-6 红线说明。

## 改动了哪些行

- L266-314：新增 `fk_resolve_api_credentials()`（头注释 L266-275 + 函数体 L277-314，38 行）
- L316-323：新增 `fk_platform_is_opencode()`（头注释 L316-320 + 函数体 L321-323，3 行）
- L325：原 `# ── Hook module registry` 注释（原 L266）被下推，**HOOK_MODULE_NAMES 数组本身未触碰**
- 全文件 350 → 409 行（+59 行，0 删除）

## verify 真实输出

### 官方 verify 命令（TASK.md 原样执行）

```
$ bash -c 'source flow-kit-bundle/hooks/stop/lib/common.sh; fk_platform_is_opencode >/dev/null; echo rc=$?'; bash -c 'source flow-kit-bundle/hooks/stop/lib/common.sh; if fk_resolve_api_credentials; then echo rc=0; else echo "rc=$?"; fi; echo "base=[${FK_API_BASE_URL:-}] scheme=[${FK_API_AUTH_SCHEME:-}]"'
rc=0
rc=1
base=[] scheme=[]
```

> `fk_platform_is_opencode` 返回 rc=0 是因为**当前会话就是 opencode 运行时**（env 已注入 OPENCODE 信号，`env | grep -cE '^(OPENCODE|OPENCODE_BIN)='` = 1）——函数如实检测，属正确行为；空环境下实测 rc=1（见下）。

### 三 Path 冒烟矩阵（`env -i` 隔离，逐项真实执行）

```
== 空环境 ==
rc=1
base=[] scheme=[]
  ^ expect rc=1 base=[] scheme=[]

== Path1（ANTHROPIC_AUTH_TOKEN + ANTHROPIC_BASE_URL）==
rc=0
base=[http://cc.example] scheme=[bearer]
  ^ expect rc=0 base=http://cc.example scheme=bearer

== Path3（仅 FLOW_KIT_L3_*）==
rc=0
base=[http://fk.example] scheme=[bearer]
  ^ expect rc=0 base=http://fk.example scheme=bearer

== Path3 短路 Path2（FLOW_KIT_L3_* + ANTHROPIC_API_KEY）==
rc=0
base=[http://fk.example] scheme=[bearer]
  ^ expect rc=0 base=http://fk.example scheme=bearer (NOT x-api-key)

== Path1 优先于 Path3（两组同时设）==
rc=0
base=[http://cc.example] scheme=[bearer]
  ^ expect rc=0 base=http://cc.example scheme=bearer

== Path2（仅 ANTHROPIC_API_KEY）==
rc=0
base=[https://api.anthropic.com] scheme=[x-api-key]
  ^ expect rc=0 base=https://api.anthropic.com scheme=x-api-key

== Path3 不完整（仅 FLOW_KIT_L3_AUTH_TOKEN）==
fk_resolve_api_credentials: FLOW_KIT_L3_AUTH_TOKEN 已设但 FLOW_KIT_L3_BASE_URL 为空（Path3 配置不完整，rc=2）
rc=2
base=[] scheme=[]
  ^ expect rc=2 + stderr error
```

### 其他验证

```
$ bash -n flow-kit-bundle/hooks/stop/lib/common.sh
syntax OK
$ shellcheck -e SC1091 -S error flow-kit-bundle/hooks/stop/lib/common.sh
shellcheck OK（0 error，repo 标准 -e SC1091 -S error）
```

## 6 维自查（每条 ≤30s）

| 维度 | 结果 | 证据 |
|---|---|---|
| R1 函数行数 | ✅ | fk_resolve_api_credentials 38 行函数体（头注释 10 行）；fk_platform_is_opencode 3 行。均远低于拆分阈值 |
| R6.5 越界 | ✅ | `git diff --numstat`：仅 common.sh 1 文件（59+/0-）；未改 REQUIREMENT.md / DESIGN.md / TASK.md |
| 重复（R6.4 沿用 grep） | ✅ | repo 全仓 grep `fk_resolve_api_credentials\|fk_platform_is_opencode` = 0 hits；`FK_API_BASE_URL\|FK_API_AUTH_TOKEN\|FK_API_AUTH_SCHEME` 在 common.sh 外 = 0 hits（无全局名冲突）；common.sh 无既有凭证解析（fk_resolve_model 是模型名解析，非凭证） |
| 依赖 | ✅ | 两函数仅用 bash 内建 `[ ]` 判定 + env 读取，零外部命令依赖（无 jq/curl/grep）；所有 env 读 `${VAR:-}` 兼容 set -u；rc 非零路径经条件上下文（if）调用，set -e 安全 |
| 破坏性变更 1.8 | ✅ 不触发 | 纯增量（0 删除、无公共签名变更），低于 5 行删除阈值 |
| 禁动清单 | ✅ | HOOK_MODULE_NAMES 数组本体未触碰（插入点在 L325 注释之前，L270-275 数组未移动）；未碰 gate 核心链 / correction-file.sh / 其他任何文件 |

## 备注

- **shellcheck shell=bash 指令未加**：common.sh 已有 `#!/bin/bash` shebang（L1），sibling 约定是仅无 shebang 的 lib（l3-api.sh / l3-prompt.sh / l3-done.sh / l3-truncate.sh）加该指令；带 shebang 的 12 个 lib 均无。加指令反而偏离仓库约定且冗余（SC2148 只针对无 shebang 文件）。
- `set -e` 与 rc 语义：空环境（rc=1）/ Path3 不完整（rc=2）时函数返回非零，直接裸调会在 `set -euo pipefail` 下退出脚本——这是设计预期，T02/T03 调用方必须用条件上下文（`if fk_resolve_api_credentials; then ...; fi`）捕获 rc（TASK.md R3 盲审已注明）。
- FK_API_* 三个全局未 export：仅 hook 进程内传递（T02/T03 source common.sh 后同进程读取），避免凭证泄漏到 curl 等子进程环境。
