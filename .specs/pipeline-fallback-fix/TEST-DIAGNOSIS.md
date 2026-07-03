# TEST: 诊断 pipeline 自动推进 + 回退模式

- **Change ID**: pipeline-fallback-fix
- **关联**: `@.specs/pipeline-fallback-fix/REQUIREMENT.md`、`@.specs/pipeline-fallback-fix/TASK.md`

---

## 本次测试范围声明

| 轮次 | 状态 | 范围 | 跳过理由 |
|---|---|---|---|
| 第 1 轮 · 功能 | ✅ 必跑 | AC 覆盖验证 + DIAGNOSIS.md 证据完整性 | — |
| 第 2 轮 · 性能 | ❌ 跳过 | — | 纯诊断任务，无运行时/无应用 |
| 第 3 轮 · 安全 | ❌ 跳过 | — | 无依赖变更、无新增代码、无部署产物 |
| 第 4 轮 · 兼容 | ❌ 跳过 | — | 无前端/无 DB schema/无 API |
| 第 5 轮 · 可观测 | ❌ 跳过 | — | 无运行时/无日志/无监控 |

---

## 第 1 轮 · 功能测试

### 1.1 测试矩阵

| AC | 类型 | 验证方式 | 状态 |
|---|---|---|---|
| AC-1 (auto_advance 推进) | manual | T02 独立分支验证，DIAGNOSIS.md T02 段 | ⏸ 待 T02 执行 |
| AC-2 (PCSC ❌ 阻塞) | manual | T02 独立分支验证 | ⏸ 待 T02 执行 |
| AC-3 (toll-gate 交互) | manual | 当前 change 各阶段 toll-gate 观察 → DIAGNOSIS.md T01 段 | ✅ 已观察 phase 0→4 |
| AC-4 (done 文件写入) | manual | T04 .done 变体验证 | ⏸ 待 T04 执行 |
| AC-5 (done 真实性) | manual | T04 伪造 .done 测试 | ⏸ 待 T04 执行 |
| AC-5a (done 内容规范) | manual | T04 结构化字段校验 | ⏸ 待 T04 执行 |
| AC-6a (hook 拦截 jq) | manual | Phase 1→2 拦截事件已记录 → DIAGNOSIS.md | ✅ 已确认 hook 拦截生效 |
| AC-6b (toll-gate 拒绝) | manual | 待后续阶段观察 | ⏸ |
| AC-7 (fallback 触发) | manual | T03 fallback 模拟 | ⏸ 待 T03 执行 |
| AC-8 (fallback toll-gate 一致) | manual | T03 fallback vs native 对比 | ⏸ 待 T03 执行 |
| AC-9 (fallback 终止) | manual | T03 全阶段完成观察 | ⏸ 待 T03 执行 |
| AC-10 (fallback 不提前停) | manual | T03 中间阶段观察 | ⏸ 待 T03 执行 |
| AC-11 (诊断证据完整性) | manual | T05 汇总时逐 ❌/⚠️ AC 检查 a/b/c | ⏸ 待 T05 执行 |
| AC-12 (native 完成行为) | manual | 当前 change 到达 phase 7 时观察 | ⏸ 待 phase 7 |

### 1.2 已确认的发现

根据 DIAGNOSIS.md 已记录的观察：

| 发现 | AC 关联 | 状态 |
|---|---|---|
| 🔴 L2+L3 异步死锁：独立审查 gate 需要 L3（Stop hook）但 pipeline transition 需要 L3 完成后才能推进 | AC-6a, AC-3 | ❌ 单会话内无法完成 |
| 🔴 gate_config 篡改检测死锁：`/flow gate-config` 不同步 `.goal-snapshot.json` → hook 拦截所有修改工具 | AC-6a | ❌ 需人工外部修复 |
| ✅ Phase 0→1 toll-gate 正常 | AC-3 | ✅ |
| ✅ Phase 2→3 transition 正常（死锁修复后）| AC-3 | ✅ |
| ✅ Phase 3→4 transition 正常 | AC-3 | ✅ |
| ✅ Phase 4→5 transition 正常 | AC-3 | ✅ |

### 1.3 测试质量自检（6 维）

诊断任务无测试代码。本维度不适用（N/A）。

---

## 回归测试登记

无新增/修改测试用例（本次为纯诊断，不改代码，不触及 test/ 目录）。

---

## 已知限制

- T02/T03/T04 尚未执行，对应的 AC 状态为 ⏸
- 当前 change 的 auto_advance=false，AC-1/AC-2 依赖 T02 独立分支验证
- AC-12（native 完成行为）需等到 phase 7 完成后才能判定
