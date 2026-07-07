# TEST: L2/L3 双层审查结果合并写入

- **Change ID**: `dual-review-merge-fix`
- **关联**: `@.specs/dual-review-merge-fix/REQUIREMENT.md`、`@.specs/dual-review-merge-fix/TASK.md`

---

## 测试矩阵

### 功能测试（bats · 14 新增 + 346 回归）

| 轮次 | 覆盖 | 测试数 | 结果 |
|---|---|---|---|
| 新增专项 | `test_dual_review_merge.bats` — AC-1~AC-8 | 14 | ✅ 全部通过 |
| 全量回归 | `test/` 全部 bats | 346 | ✅ 全部通过，0 失败 |

**AC 覆盖明细**：

| AC | 测试项 | 状态 |
|---|---|---|
| AC-1 | 29 号 hook + PreToolUse 双路径 L2-wait | ✅ |
| AC-2 | L2-blind-review.md append-first 约束 | ✅ |
| AC-3 | l3-review.sh `>>` 追加保留 | ✅ |
| AC-4 | l3-review.sh .done deferred 逻辑存在 + 空 .done 拒绝 | ✅ |
| AC-5 | done-validation.sh phase_name 映射覆盖 {1,2,3,5,6,7} | ✅ |
| AC-6 | 6 prompt L3_verdict=skipped + append 指令 | ✅ |
| AC-7 | 29 号 hook l2_verdict=skipped | ✅ |
| AC-8 | .done KVP 值域：skipped 合法 / fake 拒绝 / 空文件拒绝 | ✅ |

### 其他测试维度（按项目类型裁剪）

| 维度 | 适用？ | 说明 |
|---|---|---|
| 性能 | N/A | 本 change 仅修改 hook/prompt 文件，不引入新运行时开销 |
| 安全 | N/A | 纯 Bash 脚本修复，无新增 API/网络端点/凭证处理 |
| 兼容 | ✅ | `done-validation.sh` 值域向后兼容；旧 `.done` 文件通过校验 |
| 可观测 | ✅ | 新增 stderr 日志（`L2 not yet complete` / `deferred`） |

---

## UAT 场景

| # | 场景 | 预期结果 | 验证方式 |
|---|---|---|---|
| UAT-1 | gate_config=both + L2 未完成 → Stop hook 触发 | L3 跳过，输出 "L2 not yet complete" | `grep` transcript |
| UAT-2 | gate_config=both + L2 完成 → transition | L3 前置运行，`.done` 含双方 verdict | `cat .done` |
| UAT-3 | gate_config=L2 → L2 子 agent 追加写入 | 文件含 L2 段，`.done` L3_verdict=skipped | `grep "L3_verdict=skipped" .done` |
| UAT-4 | gate_config=L3 → L3 运行 | `.done` L2_verdict=skipped | `grep "L2_verdict=skipped" .done` |
| UAT-5 | L2 子 agent 在已有 L3 段时追加 | L3 段内容不变，L2 段在末尾 | `grep -c "## L3 盲审"` 不变 |

---

> 本文件不引入新 AC。所有 AC 来源于 `REQUIREMENT.md`。
