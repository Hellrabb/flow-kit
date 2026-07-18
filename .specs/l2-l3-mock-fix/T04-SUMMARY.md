# T04-SUMMARY — D4·J _l3_check_rerun 内容标记 + artifact hash

- **Task**: T04 (D4·J) — _l3_check_rerun 改 ## L3 段内容标记 + artifact hash
- **Change**: l2-l3-mock-fix
- **关联**: ADR-010 / REQUIREMENT AC-J / DESIGN D4
- **状态**: ✅ verify 全绿（T04 单测 6/6 + 全套 531/1，AC-3 基线隔离）

## 改动清单

| 文件 | 改动 |
|---|---|
| flow-kit-bundle/hooks/stop/lib/l3-review.sh | `_l3_check_rerun`（:386）mtime 判定 → `^## L3 (盲审\|重审)` regex + artifact hash；删 review_mtime/artifact_mtime stat case 死代码。`_l3_parse_result`（L3 段写入块）追加 `L3_artifact_hash: <sha>` 元数据行 |
| test/test-l3-check-rerun-content-marker.bats | 新建：6 测试（regex fixture + 5 个判定用例） |
| flow-kit-bundle/test/test-l3-check-rerun-content-marker.bats | AC-7 一致性同步 |

## ADR-010 方案

- **regex 前缀匹配真实 token**：`^## L3 (盲审|重审)` 匹配 l3-review.sh 写的 `## L3 重审/盲审（模型·时间）`（回应 L3-task-R1 🔴：原 `(盲审|外部模型审查)$` 的 `$` 锚 + 臆造 token 零匹配真实标题）
- **artifact hash**：存 INDEPENDENT-REVIEW-N.md 末尾 `L3_artifact_hash: <sha256>` 元数据行（_l3_parse_result 审后追加，**不触 .done KVP**）
- **判定优先级**：hash 变→重审 / `## L3` 段缺失或空→重审 / hash 提取失败→重审+警告（保守降级）/ 否则 skip
- **touch 不触发**（hash 捕内容变更，非 mtime）

## verify 结果

| 检查 | 结果 |
|---|---|
| T04 单测（regex fixture + 首次/skip/内容改/段缺/hash 缺 5 判定） | ✅ 6/6 pass |
| 全套 bats（1.8 破坏性变更回归） | ✅ 531 ok / 1 not ok（AC-3 基线） |
| 语法 `bash -n` l3-review.sh | ✅ OK |

## 6 维 self-review（内置快查 · 基于已验证证据）

1. **正确性** ✅：6/6 单测 + 全套 531/1
2. **复用（reuse）** ✅：hash 计算的 case（phase→file）与 _l3_check_rerun 的 artifact_file case 一致；source lib 单元测试范式（_l3_check_rerun 独立，不依赖 common.sh）
3. **简单性** ✅：mtime stat 三 fallback（-c/-f/-r）删除 → sha256sum 单调用；net 删死代码
4. **效率** ✅：sha256sum 小文件 <1ms（ADR-010 Consequences）
5. **可读性** ✅：判定优先级注释 ①②③④ + regex 前缀匹配真实 token 说明
6. **测试质量** ✅：5 判定用例全覆盖（首次/skip/内容改/段缺/hash 缺）+ regex printf fixture（T04 verify 命令）

## 越界检查（R6.5 / R7.3）

- ✅ l3-review.sh + test 在 T04 write_files 内
- ✅ flow-kit-bundle/test/ 副本 = AC-7 同步（非范围扩展）
- ✅ **未改 `_l3_call_api`**（DESIGN § 0.5.1 禁动 · 回应 L2-R7）
- ✅ **未改 .done KVP 契约**（ADR-005 · hash 存 INDEPENDENT-REVIEW-N.md 非 .done）
- ✅ 未改 REQUIREMENT/DESIGN/其他 task 文件

## 沿用既有抽象 grep（1.4 · R6.4）

- `L3_artifact_hash` 新增元数据行（grep NOT-EXIST，无重复）
- 沿用 sha256sum + case phase→file 映射（与 _l3_write_done artifacts_list case 一致范式）
- regex `^## L3 (盲审|重审)` 与 l3-review.sh:461/529 自身段检测一致

## 扫 LESSONS（1.5 · R1.8）

- **L-027**（bats 禁 `|tail`）：T04 verify 直接判 exit
- **L-010**（破坏性变更后验证）：改 _l3_check_rerun/_l3_parse_result（公共 lib 行为）→ 全套 bats 恢复验证（531/1）

## 破坏性变更（1.8 · R4.6）

- 改 _l3_check_rerun 判定基（mtime → hash）+ _l3_parse_result 追加 hash 行（公共 lib 行为）
- grep 引用图：l3-review.sh 被 test_l3_review / test_l3_pipeline_fix / test_dual_review_merge 引用
- 回归覆盖：T04 单测 + 全套 bats（上述引用测试全过）

## 遗留（非 T04 范围）

1. **AC-3 基线 fail**（已装副本 inode 隔离，同 T01/T02/T03）
2. **hash 写入↔提取端到端**：_l3_parse_result 写 hash + _l3_check_rerun 读 hash 各自单元已覆盖；l3_review_run 全流程的 hash 写入→下次 _l3_check_rerun 判定集成，归 5-test 阶段（INT 级）
