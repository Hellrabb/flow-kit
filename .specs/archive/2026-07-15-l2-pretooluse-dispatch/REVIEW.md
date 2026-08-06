# REVIEW: L2 PreToolUse Dispatch + L3 写入管道修复

- **Change ID**: `l2-pretooluse-dispatch`
- **关联**: `@.specs/l2-pretooluse-dispatch/REQUIREMENT.md`、`@.specs/l2-pretooluse-dispatch/DESIGN.md`、`@.specs/l2-pretooluse-dispatch/TASK.md`、`@.specs/l2-pretooluse-dispatch/TEST.md`

---

## 变更概览

| 文件 | 变更类型 | 行数 |
|---|---|---|
| `hooks/stop/lib/l2-detect.sh` | 新增 `l2_dispatch_agent()` 函数 | +140 |
| `hooks/pre-tool-use/independent-review-gate.sh` | 重构 `_gate_check_l2()` | ~+60 |
| `hooks/stop/29-independent-review.sh` | 去 `2>/dev/null` 错误吞没 | ~+7 |
| `hooks/stop/lib/l3-review.sh` | 原子写入 + 写入后验证 | ~+20 |
| `test/test_l2_pretooluse_dispatch.bats` | 新测试文件 | +160 |
| `test/fixtures/l2-dispatch/` | 5 个 mock fixture | +50 |

---

## Spec 合规检查

| AC | 实现 | 测试 | 状态 |
|---|---|---|---|
| AC-1 | `_gate_check_l2` exit 2 逻辑 | ✅ bats | ✅ |
| AC-2 | `l2_detect_missing()` 返回 0 | ✅ bats | ✅ |
| AC-3 | both 独立判定 | ✅ bats | ✅ |
| AC-4 | gate_val != L2/both → return 0 | 隐含 | ✅ |
| AC-5a | `l2_dispatch_agent()` → exit 2 | ✅ bats | ✅ |
| AC-5b | dispatch 失败 → `l2_dispatch_prompt` 降级 | ✅ bats | ✅ |
| AC-5c | mock 模式写 INDEPENDENT-REVIEW | ✅ bats | ✅ |
| AC-6 | L3 回归 | gate_integrity 20/20 | ✅ |
| AC-7 | Stop hook L2 回归 | stop_chain 31/31, l2-detect 5/5 | ✅ |
| AC-8 | install_hooks 兼容 | matcher 已验证 | ✅ |
| AC-9 | auto_advance 非阻塞 | ✅ bats | ✅ |
| AC-10 | backlog 错误日志 | ✅ bats | ✅ |
| AC-11 | L3 原子写入 | ✅ bats | ✅ |

**覆盖**: 11/11 AC = 100%

---

## 代码质量 6 维衰退风险

| 维度 | 评估 | 说明 |
|---|---|---|
| R1 认知过载 | ✅ 低 | 每个函数 ≤80 行，职责清晰（检测/派发/降级/拦截分段） |
| R2 变更传播 | ✅ 低 | `l2_dispatch_agent()` 独立函数，仅被 `_gate_check_l2` 调用 |
| R3 知识重复 | ⚠️ 中 | Agent API 调用模式与 `l3-review.sh::_l3_call_api()` 重复（D6 承认此取舍，SYNC-POINT 标记缓解） |
| R4 偶然复杂 | ✅ 低 | mock 模式通过 `FLOW_KIT_L2_MOCK=1` 简单开关控制 |
| R5 依赖混乱 | ✅ 低 | PreToolUse → hooks/stop/lib/ 方向合法，`l2_detect_missing()` 保持无 .flow-active 依赖 |
| R6 领域扭曲 | ✅ 低 | 命名遵循项目约定（`l2_` 前缀、`_gate_` 前缀） |

---

## 禁动清单交叉验证

| 禁动项 | 修改？ | 状态 |
|---|---|---|
| `auto-checkpoint.sh` | 否 | ✅ |
| `29-independent-review.sh` | ✅ T08（已授权） | ✅ 仅去 `2>/dev/null` + 加日志 |
| `l3-review.sh` | ✅ T09（已授权） | ✅ 仅原子写入 + 写入后验证 |
| `correction-file.sh` | 否 | ✅ |
| `.flow-active` schema | 否 | ✅ |
| `_gate_phase_transition` 编排逻辑 | 否 | ✅ |
| 校验顺序 | 否 | ✅ |

---

## 已知债务

- D6 模板同步漂移（shell heredoc vs L2-blind-review.md）— SYNC-POINT 标记缓解，v2 考虑数据文件读取
- L2/L3 顺序执行反馈延迟（both 均缺失时两轮交互）— DESIGN §6 已知限制
- `_l3_scan_backlog` 最大 3/轮 限制 — 严重积压时分多次 Stop hook 补齐

---

## Verdict

**pass** — 全部 11 AC 覆盖，全量回归绿，禁动清单无越界，无新增 🔴 风险。
