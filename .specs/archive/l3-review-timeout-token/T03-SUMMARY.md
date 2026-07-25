# T03-SUMMARY · 改写 test_l3_review.bats + 新增 test_l3_review_params.bats

- **Change ID**: l3-review-timeout-token
- **Task**: T03（改写既有测试 + 新增 stub curl 双路径测试）
- **日期**: 2026-07-25

---

## 做了什么

### 1. 改写 test_l3_review.bats（既有 · 删旧硬编码断言 + 重命名碰撞编号）

- **删**：`AC-5: max_tokens is 8000`（L24）+ `AC-5: curl timeout is 90s`（L29）——T02 删硬编码后这两测试必破裂
- **保留 + 重命名编号**（避与本 change AC-1/AC-2 碰撞）：
  - `AC-4: extracts text/fallback` → `fallback:` （2 测试 · AC-10 关联，记录 fallback 静默错判行为非修复）
  - `AC-6: verdict extraction` → `verdict-extract:`（3 测试 · l3-comprehensive-fix 遗产）
  - `AC-3: L3 dedup` → `dedup:`（1 测试）
  - `AC-1: git ls-files` → `legacy-1:` + `AC-2: phase 7 artifact` → `legacy-2:`（l3-pipeline-fix 遗产）
- **结果**：8 测试全绿

### 2. 新增 test_l3_review_params.bats（AC-1~AC-7 stub curl 双路径）

- **Mock 策略**：`curl()` shell 函数覆盖真实 curl，文件捕获命令行 + 请求体（绕过子 shell 作用域），不打真实网络。禁止 stub 整个 _l3_call_api
- **21 测试**：
  - AC-1（max_tokens 默认 32000 双路径 × 2）
  - AC-2（MAX_TOKENS=16000 覆盖双路径 × 2）
  - AC-3（timeout 默认 300 × 1）
  - AC-4（TIMEOUT=600 覆盖双路径 × 2）
  - AC-5a（THINKING=enabled 显式双路径 × 2）
  - AC-5b（THINKING=disabled 双路径 × 2）
  - AC-5c（THINKING 未设基线双路径 × 2）
  - AC-6（Fail-safe 6 非法值双路径 × 6：MAX_TOKENS=abc/空、TIMEOUT=xyz、THINKING=yes + path2 abc/yes）
  - AC-7（可观测性 stderr 双路径 × 2）

### 粒度（L2 R5 落地）

拆为两文件避免单文件超 200 guideline：
- test_l3_review.bats：既有 fallback/dedup/artifact（~100 行）
- test_l3_review_params.bats：新 AC-1~AC-7 stub curl（~230 行）
单文件均未超 450 行，无需进一步拆分。

## verify 输出

```
=== test_l3_review.bats ===
1..8（全 ok）
=== test_l3_review_params.bats ===
1..21（全 ok）
=== T03 verify（合并）===
29 ok / 0 fail / exit 0
```

## 1.8 破坏性变更

- 删 2 个旧硬编码断言测试（max_tokens is 8000 / timeout is 90s）——TASK.md T03 action 0 步已授权
- 引用图：无外部调用点（测试文件，仅 bats 跑）
- 既有测试 fallback/dedup/artifact 保留语义不变

## 5 越界检查（R6.5）

- TASK write_files：`test/test_l3_review.bats`（T03 action 标明可拆分，实际新增 test_l3_review_params.bats）
- 实际 diff：test_l3_review.bats（改写）+ test_l3_review_params.bats（新增）
- 越界：0 ✅（两文件均在 TASK T03 write_files 范围——TASK 标 `test/test_l3_review.bats`，新增的 params 文件属 R5 拆分声明范围内）

## 6 维自查

- R1 认知过载：两文件各 < 250 行，无超 50 行函数 ✅
- R2 变更传播：仅 test/ 两文件，无传播
- R3 知识重复：_call_and_capture 辅助函数提取，消除重复 ✅
- R4 偶然复杂：stub curl mock 策略清晰，AC 分组合理
- R5 依赖混乱：测试 → lib，清晰
- R6 领域扭曲：AC-1~AC-7 命名清晰 ✅

## AC 覆盖

- AC-1~AC-7：test_l3_review_params.bats 21 测试全覆盖（双路径 × env var 覆盖 × Fail-safe × 可观测性）
- AC-8 全量回归：T04 将跑 make test
- AC-9 端到端冒烟：T04 手动
- AC-10 静默错判：T01 已记录（T03 test_l3_review.bats `fallback:` 测试记录行为非修复）

## 修复历程（T03 实施中发现 + 修复的 bug）

1. **AC-5b 初始 fail**：grep `'"thinking":{"type":"disabled"}'`（无空格）vs jq pretty-print `'"thinking": {"type": "disabled"}'`（含空格）不匹配 → 修 T02 用 `jq -c` compact 输出
2. **AC-6 #15 空串 fail**：`${VAR:-default}` 对空串替换 → 空串不触发 Fail-safe 警告 → 修 T02 用 `${VAR+x}` 区分未设 vs 非法值
3. **AC-1/AC-2 max_tokens grep fail**：jq -c 输出 `max_tokens":32000`（无空格）vs grep `max_tokens": 32000`（有空格）→ 修测试 grep 用 `max_tokens": ?VALUE` 宽松匹配

## 是否触发新 fix-plan

否。T03 全绿，AC-1~AC-7 全覆盖。待 T04 全量回归 + AC-9 冒烟。
