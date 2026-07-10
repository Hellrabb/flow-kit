# REVIEW: 自动 checkpoint hook

- **Change ID**: `auto-checkpoint-hook`
- **审查日期**: 2026-07-10

---

## 变更概览

```
6 files changed, +136/-97（源码）
3 files new（hook + 2× tests）
10 files new（.specs/ 产物）
全量回归: 454 bats / 0 fail
```

---

## 1. Spec 合规

| AC | 验证 |
|---|---|
| AC-1 (Write checkpoint) | ✅ `auto-checkpoint.sh:68` — Write stdin → checkpoint_write() |
| AC-2 (Edit checkpoint) | ✅ `auto-checkpoint.sh:37` — Edit 同路径触发 |
| AC-3 (无 change 跳过) | ✅ `auto-checkpoint.sh:72` — change_id null → exit 0 |
| AC-4 (非 Write/Edit 不触发) | ✅ `auto-checkpoint.sh:66` — tool_name case 过滤 |
| AC-5 (Fail-open) | ✅ `auto-checkpoint.sh:76,80` — 所有异常路径 exit 0 |
| AC-6 (恢复精度) | ✅ 三字段写入 + bats 验证 ISO8601 格式 |
| AC-7 (文档) | ✅ SKILL.md 新增自动机制说明段 |
| AC-8 (安装) | ✅ install_hooks.sh 文件复制 + JSON 接线 |
| AC-9 (去重移除) | ✅ checkpoint-lib.sh 删除 dedup 函数 + 22 tests 验证 |

**结论**: 9/9 AC 全部覆盖，无遗漏。

---

## 2. 代码质量

### 正面

- **Fail-open 防御深度**：3 层保护 —— jq 不可用 (`command -v`) → exit 0、lib 找不到 → stderr + exit 0、checkpoint_write 失败 → stderr + exit 0
- **source-safe 模式**：`auto-checkpoint.sh` 采用 `BASH_SOURCE[0] == "${0}"` 守卫，与 `independent-review-gate.sh` 同模式
- **lib 路径三级 fallback**：安装路径 → 开发目录结构 → 同目录（测试 flat layout）
- **原子写入继承**：jq → .tmp → validate → mv（checkpoint-lib.sh 内置）
- **去重彻底删除**：D2 决策 clean cut，无 deprecated 死代码残留
- **测试双路径覆盖**：AC-5 fail-open 覆盖 Write + Edit 双路径

### 潜在关注点

- `_auto_ck_resolve_lib()` 的三级路径查找在安装后的生产环境中总是命中第一级（`$HOOK_BASE_DIR/../stop/lib/checkpoint-lib.sh`），第二三级是保险——合理
- `install_hooks.sh` 新增的 auto-checkpoint 注册代码与 gate 注册代码高度相似（~25 行重复）。**判断**：不抽公共函数——两个 hook 的 matcher/命令路径/日志消息都不同，抽函数需要 4+ 参数不如直写清晰。**不建议重构**。

---

## 3. 设计对齐

| DESIGN 决策 | 实现验证 |
|---|---|
| D1 (pre-tool) | ✅ `auto-checkpoint.sh` PreToolUse hook |
| D2 (删除 dedup) | ✅ `checkpoint-lib.sh` 无 `checkpoint_dedup_check` + `CHECKPOINT_DEDUP_WINDOW` |
| D3 (全阶段) | ✅ 仅检查 `change_id` 非 null，不限 phase |
| D4 (fail-open) | ✅ 所有异常路径 exit 0 |
| D5 (failing_check="") | ✅ `checkpoint_write "$file" "编辑 $file" ""` |
| D6 (matcher: Write\|Edit) | ✅ `install_hooks.sh:161` matcher: `"Write|Edit"` |
| D7 (gate 共存) | ✅ 两个 hook 独立注册、不同 matcher、串行执行 |

---

## 4. 风险回顾

| DESIGN 风险 | 当前状态 |
|---|---|
| R1 (stdin 协议) | ✅ 已验证 `tool_input.file_path` 字段名（gate 脚本生产使用） |
| R2 (jq 竞态) | ✅ 原子写入 + PreToolUse 串行；454 bats 0 fail |
| R3 (dedup 死代码) | ✅ 已彻底删除；test_checkpoint.bats 改写验证 |
| R4 (install_hooks.sh) | ✅ PreToolUse 键不存在时 jq 创建 |

---

## 5. 主 agent 审查结论

**Verdict: pass**

9/9 AC 覆盖、DESIGN D1-D7 全部对齐、454 bats 0 fail、无禁动清单越界、无死代码残留。

**建议进入 7-integration**。
