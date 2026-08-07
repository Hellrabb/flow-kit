# T01-rev-SUMMARY — common.sh fk_resolve_api_credentials 平台翻转优先级

- **Change**: l2l3-cross-platform
- **Task**: T01-rev（delta · 在第一轮 T01 固定优先级基础上加平台感知翻转）
- **执行**: 2026-08-08
- **改动文件**: `flow-kit-bundle/hooks/stop/lib/common.sh`（本会话唯一改动文件 · 1 次 edit）

## 做了什么

在 `fk_resolve_api_credentials()`（DESIGN D1）顶部加平台感知分支，优先级随 `fk_platform_is_opencode()` 翻转：

- **opencode（fk_platform_is_opencode 真）**: **Path3 > Path1 > Path2** —— 残留 `ANTHROPIC_AUTH_TOKEN` 不压制 `FLOW_KIT_L3_*`
- **claude code（假）**: **Path1 > Path3 > Path2**（CC 零回归）
- **公共规则不变**：Path1/3 任一命中即短路 Path2；Path3 token 非空但 base_url 空 → rc=2 + stderr 报错，禁止静默落 Path2；Path2 仅当 Path1/3 全空
- **签名不变、rc 语义不变（0/1/2）、fk_platform_is_opencode 本体未触碰**

### 实现方式（DRY · 三全局清空每分支复用）

为满足「三全局清空逻辑每分支复用」且避免 Path1/Path3 两分支重复写 4 遍赋值块，抽取 3 个文件内私有辅助（`_fk_api_*` 前缀 · CONTEXT 私有函数约定）：

| 辅助 | 职责 |
|---|---|
| `_fk_api_try_path1()` | Path1 命中判定：`ANTHROPIC_AUTH_TOKEN` 非空 → 设置 FK_API_* 三全局 + return 0；未命中 return 1 |
| `_fk_api_try_path3()` | Path3 命中判定：`FLOW_KIT_L3_AUTH_TOKEN`+`FLOW_KIT_L3_BASE_URL` 均非空 → 设置 + return 0（短路 Path2）；全空 return 1；token 有 base_url 空 → stderr 报错 + `_fk_api_clear_outputs` + return 2 |
| `_fk_api_clear_outputs()` | 清空 FK_API_AUTH_TOKEN/BASE_URL/AUTH_SCHEME 三全局（rc=2 与 rc=1 分支复用，两平台共享） |

公共函数体只保留优先级编排：

```bash
fk_resolve_api_credentials() {
  if fk_platform_is_opencode; then
    _fk_api_try_path3 && return 0      # opencode: Path3 > Path1 > Path2
    [ "$?" -eq 2 ] && return 2
    _fk_api_try_path1 && return 0
  else
    _fk_api_try_path1 && return 0      # claude code: Path1 > Path3 > Path2（零回归）
    _fk_api_try_path3 && return 0
    [ "$?" -eq 2 ] && return 2
  fi
  # Path2（两平台共享 · 仅当 Path1/3 全空）+ 全空 rc=1 分支不变
  ...
}
```

rc=2 传播：`_fk_api_try_path3 && return 0` 失败时 `$?` 保留 1 或 2，`[ "$?" -eq 2 ] && return 2` 精确区分「全空(1)→继续」与「配置不完整(2)→短路返回」，两平台一致。`&&` 列表首命令与 `[ ]` 均在 errexit 豁免位（set -e 安全，与既有调用方条件上下文约定一致）。

## verify 真实输出（TASK.md 官方命令原样执行）

```
$ cd flow-kit-bundle && bash -c 'source hooks/stop/lib/common.sh; (unset ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY FLOW_KIT_L3_AUTH_TOKEN FLOW_KIT_L3_BASE_URL OPENCODE OPENCODE_BIN; set +e; fk_resolve_api_credentials; echo "rc=$?"); (unset ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY OPENCODE OPENCODE_BIN; set +e; FLOW_KIT_L3_AUTH_TOKEN=t FLOW_KIT_L3_BASE_URL=u OPENCODE=1 fk_resolve_api_credentials; test "$?" -eq 0 -a "$FK_API_BASE_URL" = "u" && echo "opencode-path3 OK" || { echo "opencode-path3 FAIL"; exit 1; }); (unset FLOW_KIT_L3_AUTH_TOKEN OPENCODE OPENCODE_BIN; set +e; ANTHROPIC_AUTH_TOKEN=t OPENCODE=1 fk_resolve_api_credentials; test "$?" -eq 0 -a "$FK_API_AUTH_SCHEME" = "bearer" && echo "opencode-path1-fallback OK" || { echo "FAIL"; exit 1; })'
rc=1
opencode-path3 OK
opencode-path1-fallback OK
```

### 扩展平台翻转矩阵（F-B 核心用例 · 双平台 × 三 Path 全组合 + rc=2 + 短路）

```
PASS CC both-P1P3 -> Path1 (rc=0 base=http://cc.example scheme=bearer)          # CC 零回归：Path1 仍压制 Path3
PASS opencode both-P1P3 -> Path3 (flip) (rc=0 base=http://fk.example scheme=bearer)  # 翻转：Path3 压制 Path1
PASS opencode P1 only -> Path1 fallback (rc=0 base=http://cc.example scheme=bearer)  # opencode 下 Path1 作 CC 残留回退
PASS CC P1 only -> Path1 (rc=0 base=http://cc.example scheme=bearer)
PASS CC P3-incomplete+P2 -> rc=2, no P2 fallback (rc=2 base=empty scheme=empty)     # Path2 未落（base 未被硬编码端点覆盖）
PASS opencode P3-incomplete+P2 -> rc=2, no P2 fallback (rc=2 base=empty scheme=empty)
stderr msg OK / globals cleared OK（rc=2 时 stderr 含「FLOW_KIT_L3_AUTH_TOKEN 已设但 FLOW_KIT_L3_BASE_URL 为空」+ 三全局清空）
PASS CC P2 only -> x-api-key (rc=0 base=https://api.anthropic.com scheme=x-api-key)
PASS opencode P2 only -> x-api-key (rc=0 base=https://api.anthropic.com scheme=x-api-key)
PASS all empty -> rc=1 (rc=1 base= scheme=)
```

> 说明：初跑矩阵时 2 例 FAIL 为测试 harness 自身隔离 bug（前一例遗留 `ANTHROPIC_AUTH_TOKEN=p1` 导出 + OPENCODE 未重新置位导致 Path1 先命中），修正隔离后全绿——非实现缺陷。

### 回归（既有 bats 双平台全绿）

```
$ bats test/test_l3_credential_resolution.bats test/test_l2_dispatch_mode.bats   # 29 tests
29/29 ok（含 17 条凭证优先级矩阵 + 平台提示 + scheme/header R4 断言 + l2 派发双模式）
$ bats test/test_common.bats flow-kit-bundle/test/test_l3_credential_resolution.bats  # 42 tests
42/42 ok
$ diff -q test/test_l3_credential_resolution.bats flow-kit-bundle/test/test_l3_credential_resolution.bats
dual-source sync OK
$ bash -n flow-kit-bundle/hooks/stop/lib/common.sh  →  syntax OK
$ shellcheck -e SC1091 -S error flow-kit-bundle/hooks/stop/lib/common.sh  →  OK（0 error）
```

> 既有 bats 的优先级矩阵用例 setup 统一 unset OPENCODE/OPENCODE_BIN → 全部走 CC 分支，与第一轮固定顺序行为完全一致，零回归；翻转仅影响「OPENCODE 信号存在 + Path1 与 Path3 并存」场景，正是 T01-rev 目标。

## 6 维 self-review（内置快查）

| 维度 | 结果 | 证据 |
|---|---|---|
| R1 函数行数 | ✅ | fk_resolve_api_credentials 编排体 20 行；私有辅助各 6-16 行；无超阈值函数 |
| R6.5 越界 | ✅ | 本会话仅 1 次 edit（common.sh）；`git diff --name-only` 18 个改动文件全部为同 change 其他任务（T02-rev/T03-rev/第一轮）产物，未由本会话触碰 |
| 重复（R6.4 沿用 grep） | ✅ | 三全局清空抽 `_fk_api_clear_outputs` 复用（rc=2/rc=1 × 两平台 4 处 → 1 处）；Path1/3 赋值块各 1 份定义；无新全局名冲突（FK_API_* 沿用第一轮既有输出契约） |
| 依赖 | ✅ | 仅 bash 内建 `[ ]` + env 读取 + 既有 `fk_platform_is_opencode`；零新外部命令；`${VAR:-}` 全量 set -u 兼容；非零 rc 经 `&&` 列表/`[ ]` 条件上下文传播，set -e 安全（与既有调用方 `|| _rc=$?` 约定一致） |
| 破坏性变更 1.8 | ✅ 不触发 | 纯增量（81+/0- vs HEAD；相对第一轮磁盘态为函数体重构），无签名变更、无删除、公共调用方（l3-api.sh / l2-detect.sh / resume）零改动 |
| 禁动清单 | ✅ | 仅 common.sh；HOOK_MODULE_NAMES / gate 核心链 / correction-file.sh / fk_platform_is_opencode 本体未触碰；无凭证落盘（见下） |

## 凭证红线（AC-6）

- 本任务未向任何运行时落盘文件写入凭证：无 .flow-active* / correction / 日志 / 报告写入；verify 使用官方命令内字面量（`t`/`u`）与测试夹具值（`p1`/`p2`），非真实凭证
- stderr 报错与 SUMMARY 仅含 env **变量名**（AC-6 载体边界允许：stderr/banner/规格文档可点名 env，token 值模式 `=sk-`/base64 未出现）
- FK_API_* 三全局不 export（仅 hook 进程内传递，防泄漏到 curl 子进程）

## 备注

- **TASK.md done 标记**：T01-rev `<done>` 已由 Phase 3 第二轮 TASK.md 预置（L32），文本与验收目标一致；按硬约束「不改 TASK.md」未重复写入，done 语义已满足。
- 相对第一轮磁盘态，函数体从「顺序 if 链」重构为「平台分支 + 私有辅助」：行为差异仅在 opencode + Path1&Path3 并存时 Path3 优先（F-B 目标），其余全部路径与第一轮逐字节等价。
