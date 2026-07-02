# TEST: 加固 toll-gate 不可绕过性 + 扩展 L2 独立审查到 3/5/7

- **Change ID**: gate-integrity
- **阶段**: 5-test
- **完成时间**: 2026-07-02 14:25
- **栈**: Bash + bats-core 1.13.0

---

## 本次测试范围声明

| 轮次 | 状态 | 范围 | 跳过理由（如跳过）|
|---|---|---|---|
| 第 1 轮 · 功能 | ✅ 必跑 | AC-1~6 全部 | — |
| 第 2 轮 · 性能 | ⚠️ 部分 | gate jq 耗时实测 | Bash hook 无 bundle/Lighthouse，只测 gate 增量耗时 |
| 第 3 轮 · 安全 | ✅ 必跑 | AC-1 六类威胁 UAT | 本 change 核心即安全（.done 真实性）|
| 第 4 轮 · 兼容 | ⚠️ 部分 | 旧 .done / 旧 goal tolerant read | 无浏览器/OS 矩阵，只测向后兼容 |
| 第 5 轮 · 可观测 | ✅ 必跑 | hook 拒绝时 stderr 可读原因 | AC 非功能"可观测性"项 |

---

## 第 1 轮 · 功能测试

### 1.1 测试矩阵（AC → 用例）

| AC | 类型 | 用例文件 / UAT | 状态 |
|---|---|---|---|
| AC-1（.done 真实性 6 类威胁）| unit + UAT | test_gate_integrity.bats（6 测试）+ regression-demos/{empty,forged,hijack,tampered,gate-config-tamper}/check.sh | ✅ |
| AC-2（transition 前置查 gate + 全链单一源）| UAT | regression-demos/skipped-subprocess/check.sh + pipeline-gates.md grep | ✅ |
| AC-3（3/5/7 L2 gate 接入 5 站点）| unit | test_gate_integrity.bats（4 测试 grep 5 站点）| ✅ |
| AC-4（gate-config 预设 / 数字映射）| unit | test_gate_config_presets.bats（39 tests 含 all/数字 3/5/7）| ✅ |
| AC-5（bats 覆盖 + 不回归）| regression | repo-root/test/ 全量 216 total | ✅（12 预存，0 新增）|
| AC-6（L3 机制实际生效 + 写入正确）| unit + 静态 | test_gate_integrity.bats（2 测试）+ 29号 grep | ✅ |

每条 AC ≥ 1 条覆盖，无空缺。

### 1.2 UAT 脚本（7 个威胁 demo · 全过）

| UAT | 威胁 | 前置 | 期望 | 实测 |
|---|---|---|---|---|
| UAT-empty | ① 空 .done | touch 空 .done | hook 拒（T1 非空）| ✅ 拒绝 |
| UAT-forged | ②③ 伪造 KVP + 无握手 | 伪造 .done，无 .flow-active.independent-review | hook 拒（T2+T3）| ✅ 拒绝 |
| UAT-hijack | ④ 跨 session 移花接木 | .done session_id ≠ 当前 | hook 拒（T3b）| ✅ 拒绝 |
| UAT-tampered | ⑤ 篡改 verdict | .done L2_verdict ≠ .md | hook 拒（T4）| ✅ 拒绝 |
| UAT-gate-config-tamper | ⑥ gate_config 篡改 | independent→false | hook 拒（D8 ⑥检测）| ✅ 拒绝 |
| UAT-skipped-subprocess | ③ 跳子进程 transition | 无合法 .done 请求 transition | hook 拒（gates[4→5] pending）| ✅ 拒绝 |
| UAT-exotic-escape | ③ exotic Bash 逃逸 | python-c 写握手 | v1 不挡（文档化，留 v2 加密）| ⚠️ 符合 v1 立场 |

### 1.3 覆盖率与边界

- 全量 `npx bats test/`（repo-root/test/）：**216 total, 204 pass, 12 fail（全预存：correction-file 8 + AC-7 一致性 1 + CF-01/02/03 3）**
- 本 change 新增 test_gate_integrity.bats：**21 tests 全过**（AC-1 6 威胁 + D9 正向 + AC-3 5 站点 + D7 6 向量 + D10 3 场景 + AC-6 2 检查）
- 边界用例：空 .done / 畸形 .flow-active / 缺握手 / session 不匹配 / verdict 不一致 / exotic 逃逸 / 纯读 vs 写信号——均覆盖
- **0 新增回归** ✅

### 1.4 测试质量自检 · 6 维测试衰退风险

| 维度 | 诊断 | test_gate_integrity.bats |
|---|---|---|
| T1 测试晦涩 | 测试名含 AC/威胁编号 + 场景描述 | ✅ 可读 |
| T2 测试脆弱 | 断言 return code（外部行为）非内部实现 | ✅ |
| T3 测试重复 | 每测不同威胁/向量 | ✅ |
| T4 Mock 滥用 | 无 mock，真实 source lib + 真实文件 | ✅ |
| T5 覆盖率幻觉 | 每测有 `[ $? -eq N ]` 实断言 | ✅ |
| T6 架构错配 | 函数单测（source lib）+ grep 静态，层级匹配 | ✅ |

命中 0 项。测试套质量良好。

---

## 第 2 轮 · 性能测试（部分）

gate 核心开销 = jq 读 .flow-active（PreToolUse 每次新进程）。

- `fk_independent_review_gate_active` 单次平均：**6ms/次**（100 次实测平均）
- G2 ADR 预期 ~2.4ms；实测 6ms（含 source lib + 2 次 jq）—— O(几 ms) 量级，不显著拖慢 transition（REQUIREMENT 非功能"性能"项满足）
- 无 bundle size / Lighthouse（Bash hook 项目不适用）

---

## 第 3 轮 · 安全测试

AC-1 六类威胁全 UAT 验证（见 1.2）：
- ①②④⑤⑥ v1 完全挡 ✅
- ③⑤-L3 常见写向量挡（D7 is_handshake_write 拦 > / >> / tee / cp / mv / sed -i / printf / dd / install / awk / heredoc）
- ③ exotic Bash 逃逸（python-c / base64 / 变量间接）v1 不挡，留 v2 加密签名（DESIGN §6 R12，exotic-escape demo 文档化）

---

## 第 4 轮 · 兼容性测试（部分）

- 旧 .done（`written_by=main-agent`，dogfood 历史产物）：phases_done 短路放行（G1 R11）。实测 .independent-review-1/2.done 靠 phases_done 短路接受 ✅
- 旧 goal 数据：tolerant read（jq `// empty` / `// "default"`）✅
- 无浏览器/OS 矩阵（Bash 项目不适用）

---

## 第 5 轮 · 可观测性验证

hook 拒绝时 stderr 输出可读原因（REQUIREMENT 非功能"可观测性"）：
- gate.sh 4 处 `⛔` 可读拒绝消息（path-guard D7 / ⑥检测 / commit / PR / 阶段切换）
- 每条含：拒绝原因 + 缺哪类证据 + hotfix 绕过路径（touch .done / gate-config off）
- 29号 L3 失败时 module_output 分级（info/warning/error）+ 可手动绕过提示

---

## 回归测试登记

- repo-root/test/ 全量：216 total / 204 pass / **12 预存 fail（非本 change）**
- bundle/test/ 本 change 新增：test_gate_integrity.bats（21）+ test_check_gate_sync.bats（T02）+ test_gate_config_presets.bats 扩展
- 预存失败分类：correction-file（8，correction 机制）+ AC-7 一致性（1，双 test/ 结构）+ CF-01/02/03（3，compliance correction）—— 均与本 change 无关

---

## 结论

**PASS** ✅

- AC-1~6 全部验证通过
- 0 新增回归（12 预存失败均为既有，非本 change）
- 6 维测试质量 0 命中
- 性能 / 兼容 / 可观测 非功能项满足
- v1 诚实边界（exotic Bash 逃逸 + ⑤-L2 .md 同篡 + ⑥ 强防）留 v2，已文档化

### 已知遗留（非阻塞，建议单独 change）

1. check-gate-sync PCSC 行数漂移（4-dev.md 9 vs flow-dev SKILL.md wrapper 8，预存 + check-gate-sync 提取粗放）
2. bundle/test/ 双重前缀路径问题（既有测试假设 repo-root/test/）
3. T14 verify 路径瑕疵（`cd flow-kit-bundle` 与路径假设矛盾）
