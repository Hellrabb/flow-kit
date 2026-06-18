# TEST: pipeline-goal

- **Change ID**: pipeline-goal
- **测试日期**: 2026-06-18
- **项目类型**: meta / Bash 脚本（无传统测试框架，测试聚焦 jq 表达式 + prompt 协议一致性）

---

## 本次测试范围声明

| 轮次 | 状态 | 范围 | 说明 |
|---|---|---|---|
| 第 1 轮 · 功能 | ✅ 必跑 | jq 表达式验证 | 全部 pipeline goal jq 操作 |
| 第 2 轮 · 协议一致性 | ✅ 必跑 | prompt 一致性 | toll-gate / auto_advance / rollback / phases_done |
| 第 3 轮 · 向后兼容 | ✅ 必跑 | 单阶段 goal | 无 scope 字段的行为不变 |
| 第 4 轮 · 数据 | ❌ 跳过 | — | 无数据库 schema 变更 |
| 第 5 轮 · 性能 | ❌ 跳过 | — | 纯 prompt 变更，无性能影响 |

---

## 第 1 轮 · jq 表达式验证 ✅

| 测试 | 命令 | 结果 |
|---|---|---|
| GO.md pipeline extraction | jq pipeline fields | `pipeline\|4\|\|false\|active\|0` ✅ |
| 4-dev transition 4→5 | jq current_phase="5" phases_done+=["4"] | `{current_phase: "5", phases_done: ["4"], gate: "passed"}` ✅ |
| 6-review rollback | jq current_phase="4" phases_done-=["5","6"] | `{current_phase: "4", phases_done: []}` ✅ |
| 7-integration complete | jq status="done" phases_done+=["7"] | `{status: "done", phases_done: ["7"]}` ✅ |
| gate_config bracket | jq gate_config["6-review"]["perf-regression"] | `"critical"` ✅ |

## 第 2 轮 · 协议一致性 ✅

| 检查项 | 预期 | 结果 |
|---|---|---|
| Toll-gate 覆盖 3 个过渡点 | 4-dev ≥ 1, 5-test ≥ 1, 6-review ≥ 1 | 4-dev:2, 5-test:3, 6-review:2 ✅ |
| auto_advance 判定 | 4-dev + 5-test + 6-review | 4-dev:4, 5-test:2, 6-review:2 ✅ |
| phases_done 更新 | 全部 4 个 prompt | 4-dev:4, 5-test:5, 6-review:4, 7-int:2 ✅ |
| Phase rollback | 5-test + 6-review | 5-test:4, 6-review:6 ✅ |
| SKILL.md / GO.md schema 一致 | pipeline 字段一致 | SKILL.md:13, GO.md:5 ✅ |

## 第 3 轮 · 向后兼容 ✅

| 测试 | 结果 |
|---|---|
| 单阶段 goal（无 scope 字段）→ `(.goal.scope // "phase")` 返回 `"phase"` | ✅ |
| `/flow goal` 无 --pipeline → 写入旧格式（无 pipeline 字段）| ✅ |
| `/flow goal clear` → goal=null（清除所有字段）| ✅ |
| 旧版 .flow-active 被新版 GO.md 读取不报错（`//` 默认值）| ✅ |

## UAT

- [ ] 人工验收：设定 pipeline goal → 4-dev 展示横幅 → toll-gate 暂停 → 进入 5-test
- [ ] 人工验收：5-test → 6-review → 7-integration 全流程
- [ ] 人工验收：门禁失败 → pipeline 暂停 → 回退到 4-dev

---

## 覆盖率回顾

- jq 表达式覆盖率：5/5 核心操作（100%）
- prompt 协议一致性：4/4 prompt（100%）
- AC 覆盖：12/12（全部 4-dev 端实现，人工验收待跑）
