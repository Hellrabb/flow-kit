# 独立审查 · 阶段 3

## L2 盲审

### 审查概要

- **审查对象**: TASK.md（7 个 task，3 个 wave）
- **参考文件**: REQUIREMENT.md（9 条 AC）、DESIGN.md（D1~D7 决策）
- **依赖图**: 无环。Wave 1: T01[P]+T02[P]+T03[P] → Wave 2: T04[P]+T05[P] → Wave 3: T06[P]+T07[P]
- **AC 覆盖**: 9/9 AC 均有对应 task（覆盖矩阵完整）
- **禁动清单**: 所有 write_files 均未触碰 DESIGN §0.5.1 和 §9.5 禁动清单
- **任务粒度**: 7 个 task 预估变更量均 ≤ 150 行（最大为 T04 新 bats 文件），满足 ≤ 200 行约束

---

### 🟡 R1 · T02 verify 不可机器执行（exit code 被 echo 吞没）

**Symptom（症状）**: T02 verify 命令末尾的 `; echo "exit=$?"` 导致整个 verify 永远返回 exit 0。无论 auto-checkpoint.sh 执行成功（exit 0）、崩溃（exit 1）、还是被信号终止（exit >128），verify 都通过，因为它们的结果被 `echo` 的 exit 0 覆盖。
具体位置：TASK.md 第 71 行：
```
bash -n ... && echo '...' | bash ... auto-checkpoint.sh; echo "exit=$?"
```

**Source（源头）**: shell 的 `;` 分隔符使得最后一个命令是 `echo "exit=$?"`，而 echo 几乎从不失败。管道中 hook 的实际 exit code 仅被打印，不被断言。

验证：模拟 hook 以 exit 2 失败，verify 仍返回 0：
```
$ (exit 2) | cat; echo "exit=$?"; echo "overall=$?"
exit=2
overall=0          ← verify 返回 0，假装通过
```

**Consequence（后果）**: CI 自动化中 T02 verify 永远绿灯，hook 的运行时错误（jq parse 失败、source 路径错误、非零退出）会被静默漏过。done 标准承担了全部验证责任（4 个路径的人工检查），但 verify 本身形同虚设，不符合"每条 verify 可机器执行"的审查准则。

**Remedy（修补）**: 删除 `; echo "exit=$?"` 后缀。由于 hook 是 fail-open（exit 0），pipe 的 exit code 就是 hook 的 exit code——改为：
```
bash -n flow-kit-bundle/hooks/pre-tool-use/auto-checkpoint.sh && echo '{"tool_name":"Write","tool_input":{"file_path":"test.sh"}}' | bash flow-kit-bundle/hooks/pre-tool-use/auto-checkpoint.sh
```
若需要显式断言，可改为：
```
result=$(echo '{"tool_name":"Write","tool_input":{"file_path":"test.sh"}}' | bash flow-kit-bundle/hooks/pre-tool-use/auto-checkpoint.sh) || exit 1
```

---

### 🟡 R2 · T01 action 与 AC-9 Then 冲突（函数：删除 vs 保留）

**Symptom（症状）**: REQUIREMENT.md AC-9 的 Then 子句与 TASK.md T01 action 对 `checkpoint_dedup_check()` 函数和 `CHECKPOINT_DEDUP_WINDOW` 变量的处置方式相互矛盾。

| 文档 | checkpoint_dedup_check() | CHECKPOINT_DEDUP_WINDOW |
|---|---|---|
| REQUIREMENT AC-9 Then | "保留但不再被 checkpoint_write() 使用（供外部显式调用）" | "标记为 deprecated" |
| DESIGN D2 | "**删除** checkpoint_dedup_check() 函数和 CHECKPOINT_DEDUP_WINDOW 变量" | 同左 |
| TASK T01 action step 1, 3 | "删除整个 checkpoint_dedup_check() 函数定义（L62-98）" | "删除 CHECKPOINT_DEDUP_WINDOW 变量定义（L14-15）" |

**Source（源头）**: REQUIREMENT 在 DESIGN 之前撰写，DESIGN D2 做出了更彻底的决策（删除而非保留），但 REQUIREMENT AC-9 未被回溯更新以反映 D2 裁决。

**Consequence（后果）**: 若实现者仅阅读 REQUIREMENT.md 而不读 DESIGN.md 或 TASK.md，会保留 `checkpoint_dedup_check()` 函数体（死代码）和 deprecated 变量。虽然运行时行为仍正确（checkpoint_write 已移除调用），但代码库出现预期外的死代码残留。若实现者严格遵循 TASK.md（正确路径），则与 REQUIREMENT 所写的行为不一致。文档冲突造成实现歧义。

注：AC-9 的验证方式（grep 不包含调用 + bats 两次写入均返回 0）与两种处置方式均兼容——验证方式不区分"函数删除"与"函数保留但不调用"。

**Remedy（修补）**: 回修 REQUIREMENT.md AC-9 的 Then 子句，使其与 DESIGN D2 和 TASK T01 保持一致。将"保留但不再被...使用"改为"删除 checkpoint_dedup_check() 函数"；将"标记为 deprecated"改为"删除 CHECKPOINT_DEDUP_WINDOW 变量"。或至少在 TASK.md 中增加一条 note 标注该冲突已被 DESIGN D2 裁决。

---

### 🟢 R3 · T02 verify 仅覆盖 Write 路径（冒烟 vs 完整验证的落差）

**Symptom（症状）**: T02 verify 只发送 `tool_name":"Write"` 的 stdin，未覆盖 done 标准中列出的其余 3 个路径：Edit 触发、Read 不触发、无 .flow-active 时静默跳过。done 标准（人工检查）要求验证 4 个路径，但 verify（机器检查）只验证 1 个。

**Source（源头）**: TASK.md T02 verify 与 T02 done 标准的范围不对齐。verify 是对 "Write 路径 + bash -n 语法"的冒烟测试，done 是完整的人工验证清单。

**Consequence（后果）**: R1 修复后，T02 verify 仅保证"Write 场景不崩溃"，不保证 Edit 路径正确、Read 路径正确过滤、无 change 场景正确跳过。这些缺陷会在人工 done 检查时被发现，但在仅依赖 verify 的 CI 场景中会漏过。

**Remedy（修补）**: 选项 A（推荐）：将 done 标准的关键断言下沉到 T04 的 bats 测试中（T04 已列明覆盖 AC-1~AC-6 + AC-9），T02 verify 保留为冒烟检查并在注释中标注"完整验证见 T04 bats"。选项 B：扩展 T02 verify，增加 3 条管道测试覆盖 Edit/Read/no-change 路径。

---

**Verdict**: pass
（无 🔴 Critical；2 条 🟡 Major 均不影响功能正确性，可在实现前低成本修复）
