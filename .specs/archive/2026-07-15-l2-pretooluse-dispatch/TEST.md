# TEST: L2 PreToolUse Dispatch + L3 写入管道修复

- **Change ID**: `l2-pretooluse-dispatch`
- **关联**: `@.specs/l2-pretooluse-dispatch/REQUIREMENT.md`
- **项目类型**: CLI / Shell 脚本（Bash）

---

## 0. 本次测试范围声明（5 轮金字塔）

| 轮次 | 状态 | 范围 | 跳过理由 |
|---|---|---|---|
| 第 1 轮 · 功能 | ✅ 必跑 | 全部 11 AC | — |
| 第 2 轮 · 性能 | ⚠️ 跳过 | — | CLI 脚本项目，性能关键路径为 hook 执行耗时（增量≤50ms），已在 NFR 约束中声明，非本轮重点 |
| 第 3 轮 · 安全 | ✅ 必跑 | API key 不硬编码 / Agent 权限边界 / 原子写入防篡改 | — |
| 第 4 轮 · 兼容 | ✅ 必跑 | 全量 bats 回归 / 语法检查 / 所有修改文件 bash -n | — |
| 第 5 轮 · 可观测 | ✅ 必跑 | `[l2-dispatch]` 日志 / `module_output` 记录 / hooks.log 追踪 | — |

---

## 第 1 轮 · 功能测试

### 1.1 测试矩阵（AC → 用例）

| AC | 类型 | 用例 | 状态 |
|---|---|---|---|
| AC-1 · L2 缺失硬拦截 | unit | `test_l2_pretooluse_dispatch.bats: AC-1` | ✅ |
| AC-2 · L2 完成放行 | unit | `test_l2_pretooluse_dispatch.bats: AC-2` | ✅ |
| AC-3 · both 独立判定 | unit | `test_l2_pretooluse_dispatch.bats: AC-3` | ✅ |
| AC-4 · gate_config 不含 L2 跳过 | unit | `l2_detect_missing()` 仅检查文件（不读 .flow-active） | ✅ |
| AC-5a · 自动派发触发 + 反馈 | integration | `test_l2_pretooluse_dispatch.bats: AC-5a` | ✅ |
| AC-5b · 派发失败降级 | unit | `test_l2_pretooluse_dispatch.bats: AC-5b` | ✅ |
| AC-5c · 派发结果写入 | integration | `test_l2_pretooluse_dispatch.bats: AC-5c` | ✅ |
| AC-6 · L3 PreToolUse 无回归 | regression | `test_gate_integrity.bats` 20/20 | ✅ |
| AC-7 · Stop hook L2 无回归 | regression | `test_stop_chain.bats` 31/31, `l2-detect.bats` 5/5 | ✅ |
| AC-8 · install_hooks 兼容 | verification | 手动验证 matcher `Bash\|Write\|Edit` 已覆盖 | ✅ |
| AC-9 · auto_advance 非阻塞 | unit | `test_l2_pretooluse_dispatch.bats: AC-9` | ✅ |
| AC-10 · L3 backlog 错误日志 | unit | `test_l2_pretooluse_dispatch.bats: AC-10` | ✅ |
| AC-11 · L3 原子写入 | unit | `test_l2_pretooluse_dispatch.bats: AC-11` | ✅ |

**覆盖率**: 11/11 AC = 100%

### 1.2 测试执行结果

```
$ FLOW_KIT_L2_MOCK=1 npx bats test/test_l2_pretooluse_dispatch.bats
1..12
ok 1 smoke: mock environment initializes
ok 2 AC-1: L2 missing triggers exit 2 for phase write
ok 3 AC-2: L2 completed returns 0 (pass)
ok 4 AC-3: gate_config=both L2 missing blocks even if L3 done
ok 5 AC-5a: auto-dispatch triggers with mock and returns 0
ok 6 AC-5b: dispatch fails gracefully without API credentials
ok 7 AC-5c: mock dispatch writes valid L2 review section
ok 8 AC-9: auto_advance mode does not block (agent still dispatched)
ok 9 AC-10: 29-independent-review.sh has no silent error suppression
ok 10 AC-11: l3-review.sh uses atomic write (tmp + mv)
ok 11 regression: l2_detect_missing signature unchanged
ok 12 regression: l2_dispatch_prompt still callable
```

---

## 第 2 轮 · 性能测试

⚠️ **跳过**。CLI 脚本项目，性能约束已在 NFR 声明（增量耗时 ≤50ms）。bats 测试在 <1s 内完成全部 12 用例。实际 hook 环境下的端到端耗时需在安装后实测。

---

## 第 3 轮 · 安全测试

| 检查项 | 方法 | 状态 |
|---|---|---|
| API key 不硬编码 | `grep -r 'sk-ant\|x-api-key.*=' flow-kit-bundle/hooks/` 无结果 | ✅ |
| Agent 权限边界 | `l2_dispatch_agent()` 仅写 `INDEPENDENT-REVIEW-<phase>.md`，不修改 .flow-active / gate_config / hook 脚本 | ✅ |
| 原子写入防竞态 | `l3-review.sh` 使用 `tmp + mv`（非裸 `>>`），写入后 grep 验证 | ✅ |
| dispatch 审计日志 | `[l2-dispatch]` 前缀 stderr 日志覆盖触发/成功/失败三种状态 | ✅ |

---

## 第 4 轮 · 兼容性测试

| 检查项 | 命令 | 结果 |
|---|---|---|
| 全语法检查 | `bash -n` × 4 文件 | ✅ 全部通过 |
| 新增 bats | `npx bats test/test_l2_pretooluse_dispatch.bats` | ✅ 12/12 |
| gate_integrity 回归 | `npx bats test/test_gate_integrity.bats` | ✅ 20/20 |
| l2_l3_granular_gate 回归 | `npx bats test/test_l2_l3_granular_gate.bats` | ✅ 12/12 |
| stop_chain 回归 | `npx bats test/test_stop_chain.bats` | ✅ 31/31 |
| l2-detect 回归 | `npx bats test/l2-detect.bats` | ✅ 5/5 |
| `l2_detect_missing()` 签名不变 | 函数参数与返回值未变 | ✅ |
| `l2_dispatch_prompt()` 仍可调用 | 函数签名与输出格式未变 | ✅ |

---

## 第 5 轮 · 可观测性测试

| 检查项 | 验证 | 状态 |
|---|---|---|
| `[l2-dispatch]` dispatch 成功日志 | `grep 'Agent dispatched for phase'` in stderr | ✅ |
| `[l2-dispatch]` dispatch 失败日志 | `grep 'dispatch failed'` in stderr | ✅ |
| `[l2-dispatch]` auto_advance 日志 | `grep 'auto_advance: L2 missing'` | ✅ |
| backlog 失败记录 | `module_output "warning" "IR" "backlog L3 failed"` | ✅ |
| hooks.log 引用 | `see hooks.log` 在错误消息中 | ✅ |
| L3 持久化验证 | `grep 'L3 content not persisted'` 写入后检查 | ✅ |

---

> AC 是 TEST 阶段派生用例的唯一来源。本文件不引入新 AC。
