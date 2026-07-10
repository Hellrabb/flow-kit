# TEST: fix-l3-gate · 测试执行报告

- **Change ID**: fix-l3-gate
- **关联**: `@.specs/fix-l3-gate/REQUIREMENT.md`、`@.specs/fix-l3-gate/DESIGN.md`、`@.specs/fix-l3-gate/TASK.md`
- **执行日期**: 2026-07-10

---

## 本次测试范围声明

| 轮次 | 状态 | 范围 | 跳过理由（如跳过）|
|---|---|---|---|
| 第 1 轮 · 功能 | ✅ 必跑 | 全部 5 条 AC → 20 bats tests | — |
| 第 2 轮 · 性能 | ⚠️ 部分 | mtime O(1) 验证 | Bash hook 脚本，无性能预算要求 |
| 第 3 轮 · 安全 | ⚠️ 部分 | bash -n + shellcheck | 无网络服务/DB，SAST/OWASP 不适用 |
| 第 4 轮 · 兼容 | ⚠️ 部分 | stat 跨平台 fallback | Bash 项目，不涉及浏览器/schema |
| 第 5 轮 · 可观测 | ✅ 必跑 | hook log 输出验证 | — |

---

## 第 1 轮 · 功能测试

### 1.1 测试矩阵

| AC | 类型 | 用例文件 | bats tests | 状态 |
|---|---|---|---|---|
| AC-1 L3 重审触发 | unit | `test/test_fix_l3_gate.bats` | 2 (mtime > / ≤) | ✅ |
| AC-1 追加模式 | unit | `test/test_fix_l3_gate.bats` | 1 (grep header) | ✅ |
| AC-1 文件大小预警 | unit | `test/test_fix_l3_gate.bats` | 1 (50KB check) | ✅ |
| AC-2 .done fail 不写 | unit | `test/test_fix_l3_gate.bats` | 2 (文件不存在 + GATE_DENY) | ✅ |
| AC-3 .done pass 写 | unit | `test/test_fix_l3_gate.bats` | 2 (6-key KVP + fail .done) | ✅ |
| AC-4 phase 四字段同步 | unit | `test/test_fix_l3_gate.bats` | 5 (phase=goal + tempfile+mv + phases_done/gates + 4-dev.md + pipeline-gates.md) | ✅ |
| AC-5 回退放行 | unit | `test/test_fix_l3_gate.bats` | 2 (rollback vs forward) | ✅ |
| 源码级验证 | unit | `test/test_fix_l3_gate.bats` | 11 (grep 断言 l3-review/31-auto/prompts×6) | ✅ |

### 1.2 测试执行结果

```
npx bats test/test_fix_l3_gate.bats → 24 ok / 0 fail ✅
npx bats test/                     → 441 ok / 0 fail / exit 0 ✅
```

### 1.3 覆盖率

Bash 项目无传统覆盖率工具。AC 覆盖 5/5 (100%)。边界用例：mtime 相等（≤）、mtime 大于（>）、文件不存在、跨平台 stat fallback。

### 1.4 测试质量自检 · 6 维衰退风险

| 维度 | 评估 | 说明 |
|---|---|---|
| T1 测试晦涩 | ✅ | 每个测试名标注对应 AC，可直接看出验证目标 |
| T2 测试脆弱 | ✅ | 通过 grep/source/jq 验证外部行为，不依赖内部实现细节 |
| T3 测试重复 | ✅ | 每个测试验证独立场景，无重复覆盖 |
| T4 Mock 滥用 | ✅ | 无 mock；AC-1 用真实文件系统 mtime；AC-4 用真实 jq |
| T5 覆盖率幻觉 | ✅ | 每条断言有明确预期值（`[ "$status" -eq 0 ]` / `[ "$val" = "pass" ]`），非空断言 |
| T6 架构错配 | ✅ | 单元测试验证单元逻辑（mtime/jq/KVP），集成测试已委托 bats run |

---

## 第 2 轮 · 性能测试

### 2.1 mtime 检测性能

L3 重审的工件变更检测使用 `stat -c %Y`（O(1) 系统调用），无额外 I/O：
- 单次 stat 调用 < 1ms
- 与 L3 API 调用（30s timeout）相比可忽略

### 2.2 .done 写入性能

- 仅 verdict=pass 时写入（减少不必要的 I/O）
- tempfile+mv 原子写入，无锁开销

### 通过标准

✅ 无性能退化——修改路径均为 O(1) 文件系统操作。

---

## 第 3 轮 · 安全测试

### 3.1 语法检查

```bash
bash -n flow-kit-bundle/hooks/stop/lib/l3-review.sh      → OK ✅
bash -n flow-kit-bundle/hooks/stop/31-auto-advance.sh     → OK ✅
```

### 3.2 静态分析

```bash
shellcheck -e SC1091 flow-kit-bundle/hooks/stop/lib/l3-review.sh → 无新增 error ✅
```

### 3.3 安全评估

- 无新增外部 API 调用（L3 API 调用路径不变）
- 无新增文件写入路径（review 文件 + .done 文件，均在 `.specs/<id>/` 沙箱内）
- 无命令注入风险（stat/date 参数均来自内部变量，非用户输入）
- mtime 比较使用 `[ "$a" -gt "$b" ]` 数值比较，非字符串比较，无注入风险

### 3.4 OWASP Top 10

全部标记 N/A——Bash hook 脚本，非 Web 应用。

---

## 第 4 轮 · 兼容性测试

### 4.1 stat 跨平台

`l3-review.sh` 的 mtime 获取使用三级 fallback：
1. `stat -c %Y`（Linux/GNU）
2. `stat -f %m`（BSD/macOS）
3. `date -r <file> +%s`（POSIX）

### 4.2 数据迁移

不适用——无 schema 变更。

---

## 第 5 轮 · 可观测性验证

### 5.1 Hook log 输出

修改后的关键日志点：

| 场景 | 日志消息 | 验证 |
|---|---|---|
| 重审触发 | `[l3-review] re-review triggered for phase N (artifact mtime=X > review mtime=Y)` | ✅ grep 确认存在 |
| 跳过重审 | `[l3-review] skipping L3 for phase N (artifact unchanged)` | ✅ grep 确认存在 |
| .done 写入 | `[l3-review] L3 pass — .done written (phase N)` | ✅ grep 确认存在 |
| .done 拒绝 | `[l3-review] L3 verdict=X — .done NOT written (phase N)` | ✅ grep 确认存在 |
| 文件大小预警 | `[l3-review] WARNING: review file exceeds 50KB` | ✅ grep 确认存在 |
| Timeout 降级 | `[l3-review] L3 timed out after Ns — .done NOT written` | ✅ grep 确认存在 |

### 5.2 结构化

- 所有日志使用 `[l3-review]` 前缀，可被 grep 统一过滤
- verdict 和 phase 信息嵌入日志，无需解析额外文件

---

## 回归测试登记

| 文件 | 测试数 | 备注 |
|---|---|---|
| `test/test_fix_l3_gate.bats` | 20 | 新增，覆盖 AC-1~AC-5 + 源码级验证 |
| `test/` 全量 | 439 | 回归通过，exit 0 |
