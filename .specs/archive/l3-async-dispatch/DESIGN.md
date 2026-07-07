# DESIGN — L3 独立审查异步化

- **Change ID**: l3-async-dispatch
- **对应需求**: REQUIREMENT.md v1

---

## § 0 既有架构对齐

本 change 在既有 hook 架构内执行，不新增模块、不改 ADR、不改跨模块契约。

- **受影响模块**: `independent-review-gate.sh`（PreToolUse hook）、`l3-review.sh`（Stop hook lib）
- **未受影响**: `29-independent-review.sh`（Stop hook，保持直接调 `l3_review_run`）、`flow-kit-resume.sh`（SessionStart F2 注入）、`l2-detect.sh`（L2 派发）

---

## § 1 决策清单

### D1 · L3 派发函数命名与位置

- **决定**: 在 `l3-review.sh` 末尾新增 `l3_dispatch_prompt()`，对标 `l2_detect.sh::l2_dispatch_prompt()`
- **理由**: 两个派发函数分别属于各自审查层级的 lib 文件，职责清晰；命名以 `l3_` 前缀区分作用域
- **替代方案**: 独立新文件 `l3-dispatch.sh`——否决，函数只有 1 个 (~65 行)，不符合「≥3 个共享函数才建 lib」的 CONTEXT.md 既决策略

### D2 · PreToolUse gate L3 分支重构

- **决定**: 将两处同步 L3 调用（both 路径 + L3-only 路径）合并为统一的异步派发块
- **理由**:
  - 旧代码：两段几乎相同的 ~55 行同步调用逻辑（both 路径 line 249-307 + L3-only 路径 line 310-357）
  - 新代码：先检查 `.done` 已存在 → 放行；否则 → 派发 + 拦截
  - 减少重复，且不与 30s timeout 耦合
- **流程**:
  ```
  if L2 done (or gate=L3-only):
    if L2-only gate → exit 0 (no L3 needed)
    
    # ══ Unified L3 async dispatch ══
    if .done exists and valid → F1 inject L3_RESULT → exit 0
    else → l3_dispatch_prompt >&2 → exit 2
  ```

### D3 · l3_dispatch_prompt() 输出格式

- **决定**: 完全对标 `l2_dispatch_prompt()` 的框线格式，输出到 stderr
- **内容**:
  - ╔══ 框线 header（阶段 + gate_config 值）
  - 子 agent 派发命令（`Agent({ subagent_type, description, prompt })`）
  - 手动 bash 备选命令
  - 参数说明（phase / change_id / specs_dir / L2_verdict / artifacts）
  - 重试提示
- **L2_verdict 参数来源**:
  - `gate_val=both` → 从 `INDEPENDENT-REVIEW-<N>.md` 提取 L2 verdict（pass/fail，默认 fail）
  - `gate_val=L3` → `skipped`（无 L2 前置）

### D4 · 不变项（明确列出，避免误改）

- `l3_review_run()` 函数签名和行为——完全不变
- `l3_review_with_timeout()` 保留（Stop hook 可继续使用）
- `.done` 文件 6 键 KVP 格式不变
- `fk_validate_done_marker` "transition" tier 校验逻辑不变
- F1（stdout L3_RESULT）和 F2（SessionStart banner）注入路径不变——只是在 gate 的调用时机从「同步 L3 后」变为「.done 已存在时」

---

## § 2 技术栈

不适用。纯 Bash 脚本改动，无新依赖、无新运行时。

---

## § 3 改动详情

### 3.1 l3-review.sh 新增: `l3_dispatch_prompt()`

```
位置: 文件末尾（l3_write_timeout_done 之后）
大小: ~65 行
输入: $1=phase, $2=change_id, $3=specs_dir, $4=gate_val
输出: 派发提示到 stdout（调用方重定向到 >&2）
返回: 0
```

### 3.2 independent-review-gate.sh 改动

```
删除: 两段同步 L3 调用代码（共 ~110 行）
  - both 路径: line 257-308 (l3_review_with_timeout 30 + handshake + F1)
  - L3-only 路径: line 312-357 (同上)

新增: 统一异步派发块（~35 行）
  - .done 已存在 → F1 注入 + 实效性校验 + exit 0
  - .done 不存在 → l3_dispatch_prompt >&2 + 拦截说明 + exit 2
```

---

## § 4 风险

| 风险 | 概率 | 影响 | 缓解 |
|---|---|---|---|
| agent 不理解派发提示格式，未正确派发 L3 子 agent | 低（格式与 L2 一致） | L3 审查未执行 | 拦截说明含 3 个备选方案；Stop hook 兜底 |
| gate 改动引入 bash 语法错误 | 低（bash -n 门禁） | hook 不可用 | 全量 bash -n + bats 测试 |
| L3-only 模式下的 L2_verdict=skipped 值被 l3_review_run 拒绝 | 低 | L3 审查失败 | `l3_review_run` 已接受 `skipped` 为合法值（line 172） |

---

## § 5 测试策略

- **现有测试**: `test_l3_feedback.bats` (38 tests)、`test_l2_l3_fix_compliance.bats` (43 tests) 覆盖 L3 功能——改动后应全绿
- **新增测试**: `test_l3_async_dispatch.bats`
  - AC-2: `.done` 存在时放行（mock `.done` 文件）
  - AC-3: `.done` 不存在时拦截 + 派发提示输出验证
  - AC-4: `l3_dispatch_prompt()` 输出格式验证（含框线 + 子 agent 命令 + 参数说明）
  - 边界: gate_val=L3 且无 L2 review 文件时的 L2_verdict=skipped

---

## § 9 架构沉淀建议

无需沉淀。本 change 不引入新模块、新 ADR、新跨模块契约。改动限制在两个既有文件内部。
