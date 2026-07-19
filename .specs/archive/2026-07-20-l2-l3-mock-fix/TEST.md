# TEST: L2/L3 独立审查 gate 残留缺陷根治（F/H/I/J + K）

- **Change ID**: l2-l3-mock-fix
- **测试框架**: bats-core 1.13.0（npx）
- **全套结果**: **536 ok / 0 fail / exit=0**（T06 实测 @ 2026-07-19）

---

## 本次测试范围声明（步骤 0 · Bash gate hook 项目裁剪）

| 轮次 | 状态 | 范围 | 跳过理由（如跳过）|
|---|---|---|---|
| 第 1 轮 · 功能 | ✅ 必跑 | AC-F/H/I/J/K/T 全覆盖（单测 + 集成） | — |
| 第 2 轮 · 性能 | ✅ 必跑 | NFR-1 gate hook wall time（T07 实测） | — |
| 第 3 轮 · 安全 | ⚠️ 部分 | path traversal 防护 + bash -n（无依赖/秘钥/OWASP） | 纯 Bash hook，无 npm/pip 依赖、无秘钥处理、无 Web OWASP 面 |
| 第 4 轮 · 兼容 | ✅ 必跑 | NFR-2 bash 4.4+/5.x（T08 实测） | — |
| 第 5 轮 · 可观测 | ❌ 跳过 | — | CLI/hook 工具，无运行时服务/指标/告警/日志管道 |

---

## 第 1 轮 · 功能测试（Functional）

### 1.1 测试矩阵（AC → 用例）

| AC | 类型 | 用例文件 | 状态 |
|---|---|---|---|
| AC-F（pure fn 单一来源） | unit + integration | test-phase-gate-key-pure-fn.bats（逐 key=附录 oracle + git commit deny 三要素守护）；INT-7 forward deny 回归在 test_l2_pretooluse_dispatch.bats | ✅ |
| AC-H（is_git_commit 结构判定） | integration | test-is-git-commit-structural.bats（等价类 a-f + 反规避 grep） | ✅ |
| AC-I（L2-first 顺序契约） | integration | test-l2-first-correction.bats（两处 D4 门 + correction flag） | ✅ |
| AC-J（_l3_check_rerun 内容标记） | unit | test-l3-check-rerun-content-marker.bats（5 判定 + 1 regex fixture = 6 用例） | ✅ |
| AC-K（pipeline 不 advance） | integration | test-pipeline-no-g1-autoadvance.bats（两路径子进程跑 26-workflow） | ✅ |
| AC-T（全套真绿） | regression | `npx bats test/` → 536 ok / 0 fail | ✅ |

**每条 AC ≥ 1 覆盖 ✓**。NFR-3（deny stderr 三要素）并入 AC-F/H deny 场景断言（L2 R7）；AC-I D4 是 exit 0（L2-first 等待）非 deny、AC-J _l3_check_rerun 非 gate deny 路径 → NFR-3 不适用

### 1.2 UAT

无需 UAT（所有 AC 已自动化覆盖）。AC-K「pipeline goal + phase 1 + REQUIREMENT → .phase 不 advance」用子进程真跑 26-workflow.sh 验证（非 manual）。

### 1.3 覆盖率与边界

bats-core 无行覆盖率工具，以 **AC 覆盖率**替代（6/6 AC 全覆盖）。关键路径：
- `fk_phase_gate_key` 6 key（1/2/3/5/6/7）+ 边界（0/4 空/未知/非数字）全覆盖
- `is_git_commit`/`is_gh_pr_create` 等价类 a-f（含 heredoc/多行/写重定向不 deny + git commit deny + 反规避）
- `_l3_check_rerun` 5 判定（首次/skip/内容改/段缺/hash 缺）+ 1 regex fixture = 共 6 用例
- `26-workflow G1` 三路径（pipeline 不 advance / 单阶段 advance / 无 scope 默认单阶段）

**边界用例（≥3）**：空 phase / 非数字 phase / 无 goal.scope / heredoc git commit / timeout L3 段 / hash 行缺失 ✓

### 1.4 测试质量自检 · 6 维测试衰退风险（路径 B 内置清单）

| 维度 | 诊断 | 本 change 测试 |
|---|---|---|
| T1 测试晦涩 | 测名 Given/When/Then 结构 | ✅ 测名含场景（"pipeline goal + phase 1 → 不 advance"） |
| T2 测试脆弱 | 断言实现细节 vs 行为 | ✅ 断言外部行为（.phase 值 / exit code / stderr 三要素），非内部函数调用 |
| T3 测试重复 | 参数化 | ⚠️ AC-K 三路径结构相似但语义不同（advance/不 advance/默认），非冗余；可未来参数化 |
| T4 Mock 滥用 | mock 被测单元 | ✅ 子进程跑**真实** 26-workflow.sh + 真实 fixture（R5.2 禁 mock 屏蔽真实失败） |
| T5 覆盖率幻觉 | 空断言 | ✅ 断言具体值（`.phase=="1"`/`"2"`），非 toBeDefined |
| T6 架构错配 | 层级匹配 | ✅ hook 行为用集成测（子进程），pure fn 用单测，层级匹配 |

**命中 T3（部分）→ 技术债记事**（非 release 阻塞）。命中 < 3 项，无需 release 前必修。

---

## 第 2 轮 · 性能测试（NFR-1 · T07 实测）

| 项 | 值 |
|---|---|
| 方法 | 固定 deny payload（phase 1 + gate_config both + 无 .done + stdin git commit → exit 2），bash `time` ×3 中位数 |
| 重构前（7fb59e8^ · declare -A + is_git_commit 正则） | **53 ms** |
| 重构后（7fb59e8 · pure fn + 结构判定 helper） | **53 ms** |
| 差 | **0%**（< 30% 阈值 ✅） |

**通过标准**：差 0% 远 < 30%，重构对 gate hook 性能无显著影响。详见 DESIGN NFR 实测段。

> **精度说明（L2 R5）**：`time` 内建 ms 整数量化误差约 ±5ms，53 vs 53 不等价于真实差为 0，仅代表真实差量化到同一桶。本次以「< 30% 阈值」为通过判据（NFR-1 spec 要求 n=3 中位数），结论稳（远 < 阈值）；若需高精度可追加 hyperfine ≥10 次采样 + 标准差。

---

## 第 3 轮 · 安全测试（⚠️ 部分 · Bash hook）

| 项 | 结果 |
|---|---|
| 依赖漏洞扫描 | N/A（纯 Bash，无 npm/pip/cargo 依赖） |
| 秘钥扫描 | N/A（hook 不处理秘钥；ANTHROPIC_AUTH_TOKEN 仅赋值 + curl header，AC-9 守护不 echo/module_output） |
| SAST（bash -n） | ✅ gate.sh + common.sh 语法通过 |
| path traversal 防护 | ✅ `fk_independent_review_gate_active` change_id 正则 `^[a-z0-9][-a-z0-9]+$`（done-validation.sh）防 `../` 注入 |
| OWASP Top 10 | ❌ 不适用（Bash CLI hook，无 Web 攻击面） |

---

## 第 4 轮 · 兼容性测试（NFR-2 · T08 实测）

| 项 | 值 |
|---|---|
| 实测环境 | GNU bash 5.2.21（5.x ≥ 4.4 ✅） |
| 语法 | `bash -n` gate.sh + common.sh 通过 |
| pure fn 兼容性 | `case`（bash 2+ 原生）**不依赖 `declare -A`**（需 4+）→ 兼容性只增不减 |
| bash 4.4 档 | 当前环境仅 5.2 可实跑；4.4 由「不依赖 declare -A」论证保证 |
| 数据迁移（4.2） | N/A（纯 Bash，无 schema 变更） |
| 跨版本/编码 | change_id 正则限 kebab-case（ASCII），无 locale 依赖；AC-3 测 locale 敏感已记录（T08 verify 缺陷） |

---

## 第 5 轮 · 可观测性（❌ 跳过）

CLI/hook 工具，无运行时服务 / 业务 metric / 告警 / 分布式 trace / `/health`。hook 输出走 `module_output`（workflow.txt），属开发期可观测性，非生产监控。日志/指标/告警/健康检查清单均不适用。

---

## 步骤 N · 回归测试登记

本次新增/修复测试用例（供未来 grep）：
- `test/test-phase-gate-key-pure-fn.bats`（AC-F pure fn + INT-7 forward deny 回归）
- `test/test-is-git-commit-structural.bats`（AC-H 等价类 a-f）
- `test/test-l2-first-correction.bats`（AC-I 两处 D4 门 + correction）
- `test/test-l3-check-rerun-content-marker.bats`（AC-J 5 判定 + 1 regex fixture = 6 用例）
- `test/test-pipeline-no-g1-autoadvance.bats`（AC-K 两路径子进程跑 26-workflow）
- `test/test_independent_review_model.bats` AC-3 修测（l2-l3-test-defect 遗留 :? 强制）
- `flow-kit-bundle/test/` 副本（AC-7 一致性同步）

---

## 结论

5 轮裁剪完成：**功能✅（AC 6/6 + 全套 536/0）· 性能✅（0% 回归）· 安全⚠️部分（path traversal + bash -n）· 兼容✅（bash 5.2 + pure fn 不提版本）· 可观测❌（CLI 工具）**。所有必跑轮次通过，跳过轮次有理由（R5.4）。
