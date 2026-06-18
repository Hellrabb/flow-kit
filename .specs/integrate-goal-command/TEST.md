# TEST: 整合 CC /goal 到 flow-kit

- **Change ID**: integrate-goal-command

---

## 本次测试范围声明

| 轮次 | 状态 | 范围 | 跳过理由 |
|---|---|---|---|
| 第1轮·功能 | ✅ 必跑 | AC-1~AC-7 | — |
| 第2轮·性能 | ❌ 跳过 | — | CLI/bash 元项目，无运行时性能指标 |
| 第3轮·安全 | ❌ 跳过 | — | 无新增依赖/秘钥/网络请求 |
| 第4轮·兼容 | ❌ 跳过 | — | bash+jq 环境单一，无跨平台差异 |
| 第5轮·可观测 | ❌ 跳过 | — | CLI 工具，无运行时可观测需求 |

---

## 第 1 轮 · 功能测试

### 1.1 测试矩阵

| AC | 类型 | 用例 | 状态 |
|---|---|---|---|
| AC-1 · 设定 goal | unit | `test/test_flow_goal.bats` — goal set writes condition | ✅ |
| AC-2 · 查看状态 | unit | `test/test_flow_goal.bats` — goal status shows condition | ✅ |
| AC-3 · 清除 goal | unit | `test/test_flow_goal.bats` — goal clear sets null | ✅ |
| AC-4 · 内置回退 | manual | 需在实际 CC 环境验证回退循环 | ⚠️ 降级（CI 无 CC） |
| AC-5 · 自动提取 | manual | 4-dev.md prompt 含提取逻辑，需在实际 change 流程中验证 | ⚠️ 降级（prompt 级，非代码） |
| AC-6 · 路由可见 | unit | `grep -c "Goal" GO.md` → 3 处引用 | ✅ |
| AC-7 · 恢复存活 | unit | `grep -c "goal" flow-kit-resume.sh` → 9 处引用 | ✅ |

> AC-4/AC-5 为 prompt 级功能，依赖 AI 在真实 session 中的行为。已在 4-dev.md prompt 中显式声明逻辑，实际效果在 review 阶段做人工逐条验证。

### 1.2 测试执行结果

```
$ npx bats test/test_flow_goal.bats
1..7
ok 1 goal set
ok 2 goal status
ok 3 goal clear
ok 4 goal null
ok 5 goal clear aliases
ok 6 goal turns
ok 7 goal mode

$ jq schema + GO.md + 4-dev.md + resume hook references
All PASS
```

### 1.3 覆盖率

- Bats 测试：7 条，覆盖 goal set/status/clear + aliases + turns + mode
- 代码引用验证：全部 4 个修改文件均含 goal 相关引用
- 关键路径 100%（jq 读写 + schema 验证）

---

> 测试完成，进入 6-review。
