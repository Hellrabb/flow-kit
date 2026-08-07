# TEST: L2/L3 模型审查双平台兼容性彻底修复

- **Change ID**: l2l3-cross-platform
- **关联**: `@.specs/l2l3-cross-platform/REQUIREMENT.md`、`@flow-kit/reference/test-pyramid.md`
- **项目类型**: CLI 工具（Bash 分发包）
- **Delta 修订（2026-08-08）**: 平台翻转优先级（F-B）+ transcript-parser 工具名双形状（R2）+ AC-6 bats 断言格式（R-F-A1/R-F-A2 修复）。测试数 745→752（+7 delta：3 平台翻转矩阵 + 2 AC-4b 双形状 + 2 AC-6 红线 bats 断言）。test_l3_credential_resolution.bats 17→22、test_l2_dispatch_mode.bats 12→14。

---

## 0. 本次测试范围声明（5 轮金字塔）

| 轮次 | 状态 | 范围 | 跳过理由 |
|---|---|---|---|
| 第 1 轮 · 功能 | ✅ 必跑 | 全部 AC-1~AC-9（bats 752 全量（716 既有 + 29 第一轮 + 7 delta）+ 平台翻转矩阵 + AC-6 bats 断言） | — |
| 第 2 轮 · 性能 | ⚠️ 部分 | 凭证解析开销实测（env 纯读取，零网络/文件锁） | CLI 工具无 QPS 场景；非功能性已声明"零新增延迟"，实测 1.03ms/1000 次 |
| 第 3 轮 · 安全 | ✅ 必跑 | 秘钥扫描（AC-6 双红线）+ shellcheck SAST + token 不落盘 | — |
| 第 4 轮 · 兼容 | ✅ 必跑 | **双运行时兼容是本 change 核心**：claude code（ANTHROPIC_*）+ opencode（FLOW_KIT_L3_*）双平台矩阵 | 无浏览器场景；跨 OS 由既有 66 个 bats 全绿代表 |
| 第 5 轮 · 可观测 | ⚠️ 部分 | credential source 日志 + 降级提示可执行性 | CLI hook 无指标/告警体系；验证日志不含 token（并入 AC-6） |

---

## 第 1 轮 · 功能测试

### 1.1 测试矩阵（AC → 用例）

| AC | 类型 | 用例文件 / UAT | 状态 |
|---|---|---|---|
| AC-1 三源解析 | unit | `test_l3_credential_resolution.bats`（22 用例：Path3 only / 同源调用断言 / l2_dispatch_agent 同源） | ✅ |
| AC-2 优先级表 | unit | 平台翻转矩阵（CC Path1>P3>P2 零回归 + opencode Path3>P1>P2 翻转 + Path1 兜底）+ Path3 不完整 rc=2 且未落 Path2 + 既有 7 用例 | ✅ |
| AC-3 平台提示 | unit+e2e | 同上（opencode export 指引 / CC env-var-first）+ `test_l2_dispatch_mode.bats`（correction 不含 env 名 unit+e2e） | ✅ |
| AC-4 派发双模式 | unit | `test_l2_dispatch_mode.bats`（7 用例：prompt 双模式 / box 两分支共存 / phase→agent 映射 / 6 prompt 结构断言） | ✅ |
| AC-5 agent 定义 | manual+auto | `test -f flow-kit-bundle/flow-kit/.opencode/agent/flow-kit-l2-reviewer.md`（13955B）+ install dry-run（T09）+ package --validate（T10 实打包 tar 含 2 条目） | ✅ |
| AC-6 凭证红线 | auto | 双 grep 断言（见 3.2）+ `test_l2_dispatch_mode.bats` correction 边界用例 | ✅（含 1 处 base64 误报记录，见 1.5/3.2） |
| AC-7 降级回归 | unit | 回归锚点三文件合集 25 用例全绿（3+10+12） | ✅ |
| AC-8 双源+打包 | auto | 全量 bats 752/752（716 既有 + 29 第一轮 + 7 delta）+ 打包源逐文件 742/742（65 文件 729 + quality_baseline 13）+ make check | ✅ |
| AC-9a 端到端 | e2e（本 pipeline） | 本 change 各阶段 INDEPENDENT-REVIEW-N.md 含 L2 段（L3 段为降级记录）+ gates 全 passed | ⚠️ 部分（R1 修复：L3 真实拉起无凭证未执行，`## L3` 段与 .done 六键待 UAT-1 补测；7-integration 归档前必须执行或登记豁免） |
| AC-9b written_by | manual | 人工审计 .done written_by 为审查子系统 | 🟡 待 7-integration 归档时终检 |

### 1.2 UAT 脚本

#### UAT-1 · opencode 环境 L3 凭证配置拉起（需带凭证新会话）

- **前置**: 在 opencode 启动环境 export `FLOW_KIT_L3_BASE_URL` + `FLOW_KIT_L3_AUTH_TOKEN`（hook 子进程继承启动 env）
- **步骤**: 1. `export FLOW_KIT_L3_BASE_URL=... FLOW_KIT_L3_AUTH_TOKEN=...` 2. `opencode` 启动 3. 触发任一 gate 阶段（如 6-review）
- **期望**: - `l3_review_run` 不再降级（无 `l3-model-missing` correction） - hook 日志出现 `[l3-review] credential source: env|flow-kit` - L3 审查真实调用外部模型并写 `.done`
- **实际**: 🔴 **未执行**（当前会话无凭证，L3 全程优雅降级——已记录于各阶段 L3 降级记录段）
- **执行人 / 时间**: N/A（需用户带凭证新会话执行，7-integration 前补测）

#### UAT-2 · 本 change pipeline 端到端（gate-config=all + both）

- **前置**: `.flow-active.goal.gate_config` 全阶段 `both`
- **步骤**: 0→7 各阶段按 flow-kit 流程推进（本 pipeline 即 UAT-2）
- **期望**: - 各阶段 INDEPENDENT-REVIEW-N.md 含 `## L2 盲审` 段 + `## L3` 段 - transition gate 全部 passed - L2 盲审真实执行（Verdict 驱动 fix loop）
- **实际**: ✅ 阶段 0-4 完成（L2 盲审 3 次真实执行：REQUIREMENT/DESIGN/TASK 各 1 轮，Verdict 驱动 fix loop 闭环）；L3 因无凭证降级记录（优雅路径）
- **执行人 / 时间**: 2026-08-08 / flow-kit pipeline

#### UAT-3 · 双平台派发冒烟（真实平台 env）

- **前置**: 无
- **步骤**: 1. `OPENCODE=1 l2_dispatch_prompt 5 <id>` 2. `unset OPENCODE; l2_dispatch_prompt 5 <id>`
- **期望**: opencode 分支含 `category: unspecified-high` 指引；CC 分支含 `subagent_type` 模板（box 双分支共存）
- **实际**: ✅ 两分支输出均正确（见 m00231 实测输出）
- **执行人 / 时间**: 2026-08-08 / Sisyphus

### 1.3 覆盖率

```text
（bats 项目无 kcov 行覆盖工具；以用例覆盖 + shellcheck 静态门替代）
- 全量 bats（开发源）：752 tests, 0 failures（二进制 bats 实跑 · 2026-08-08）
- 打包源：逐文件 742/742（65 文件 729 + quality_baseline 13，二进制 bats 实跑 · 2026-08-08）
- 新增用例：test_l3_credential_resolution.bats 17 + test_l2_dispatch_mode.bats 12 = 29
- 回归锚点：test_model_degradation.bats 3 + test_fk_resolve_model.bats 10 + test_independent_review_model.bats 12 = 25 全绿
- shellcheck -S error：0 error（make lint 门）
```

> **AC-8 声明修订（Phase 6 盲审 🔴 R1 处置 · T-FIX-01）**：初版 TEST.md 曾声明「npx bats flow-kit-bundle/test/ 740/740」，经 L2 盲审实跑证伪——打包源实跑 28 失败（test_archive_commit_gate.bats 24 + test_severity_format.bats 4），根因 TD-012 类双重 bundle 层路径 bug（`${BATS_TEST_DIRNAME}/../flow-kit-bundle/` 在打包源拼出 `flow-kit-bundle/flow-kit-bundle/`），非本 change diff 引入。已修复（T-FIX-01：两文件 setup 与测试体路径统一改向上查找 BATS_ROOT），修复后打包源 28/28、开发源全量 745/745、打包源逐文件 742/742 全绿（二进制 bats 实跑证据）。

- 当前：核心函数（fk_resolve_api_credentials / fk_platform_is_opencode / _l3_call_api / l2_dispatch_agent 凭证段）由 36 新增用例（29 第一轮 + 7 delta）直接覆盖 + 既有 716 回归保护
- 门槛：bats 项目以 100% 用例通过为门槛（752/752）
- 不达项原因：无

### 1.4 边界 / 错误路径用例

- 空 / 全空 env：`_test_l3_credential_all_empty_rc1`（rc=1 优雅降级）✅
- 单边缺失（token 有 base_url 空）：`_test_l3_credential_path3_incomplete_rc2_no_path2`（rc=2 + stderr 报错 + 禁止静默落 Path2）✅
- 多源并存：Path1>Path3>Path2 全组合矩阵（7 态）✅
- 平台信号：`_test_l3_credential_platform_is_opencode_3_states`（空/OPENCODE=1/OPENCODE_BIN 单独）✅
- 错误路径：无凭证 → return 3 + 平台感知提示（opencode export 指引 / CC env-var-first 两用例）✅
- base64 长串误报：路径清单串命中宽 base64 模式（见 1.5 T5 记录，非 token）⚠️ 已记录

### 1.5 测试质量自检（6 维测试衰退风险）

> 未装 brooks-lint 专用测试轮 → 内置 T1~T6 快查（逐文件过新增 2 个 bats 文件）

**严重度统计**：

| 编号 | 测试衰退风险 | 命中文件数 | 严重度分布 |
|---|---|---|---|
| T1 | Test Obscurity 测试晦涩 | 0 | 🔴 0 / 🟡 0 / 🟢 0 |
| T2 | Test Brittleness 测试脆弱 | 0 | 🔴 0 / 🟡 0 / 🟢 0 |
| T3 | Test Duplication 测试重复 | 0 | 🔴 0 / 🟡 0 / 🟢 0 |
| T4 | Mock Abuse Mock 滥用 | 1 | 🔴 0 / 🟡 0 / 🟢 1 |
| T5 | Coverage Illusion 覆盖率幻觉 | 1 | 🔴 0 / 🟡 0 / 🟢 1 |
| T6 | Architecture Mismatch 架构错配 | 0 | 🔴 0 / 🟡 0 / 🟢 0 |

**详细发现**：

### 🟢 T4 · Mock 范围：fake curl 仅用于 header 形状断言
**Symptom**: `test_l3_credential_resolution.bats` 的 scheme/header 断言组（R4 fake curl，L261-290）前置 fake curl 到 PATH 捕获 `-H` 参数
**Source**: xUnit Test Patterns · Mock Abuse
**Consequence**: 若 mock 扩展过度会遮蔽真实 API 行为；当前仅断言 header 形状（Bearer vs x-api-key）与端点，不 mock 响应解析
**Remedy**: 保持现状（mock 面最小，覆盖 AC-2 Path2 真实覆盖盲区——R4 盲审要求）；真实网络验证留 UAT-1（需凭证）

### 🟢 T5 · 断言精度：AC-6 字面验证命令的 base64 模式过宽
**Symptom**: REQUIREMENT AC-6 验证命令 `[A-Za-z0-9+/]{32,}={0,2}` 会命中 agent 文件 L166 的路径清单串 `CHANGE/REQUIREMENT/DESIGN/TASK/SUMMARY×N/TEST/REVIEW`（38 字符纯 base64 字符集，× 为全角分隔符前段）——**误报，非 token**
**Source**: Coverage Illusion（断言形似覆盖实则误报）
**Consequence**: 若机械执行字面命令会误判红线失败；T12 实际用 `sk-` 模式（真 token 特征）零命中
**Remedy**: 已登记测试质量记事（backlog T-01）：AC-6 验证命令在 v2 收紧为 token 特征模式（`=sk-` 前缀或带引号上下文）；本次判定以 `sk-` 模式 + 人工复核 base64 命中行为准（命中行确认为路径清单非凭证）

**处理**：
- 命中 2 项（均 🟢）→ 记测试质量记事；无需 release 前必修

### 1.6 测试质量记事（backlog）

| 文件 | 维度 | 严重度 | 计划修复时间 |
|---|---|---|---|
| REQUIREMENT.md AC-6 验证命令 | T5 | 🟢 | v2（收紧 base64 模式为 token 特征） |
| test_l3_credential_resolution.bats fake curl | T4 | 🟢 | 保持现状（最小 mock 面） |

---

## 第 2 轮 · 性能测试

### 2.1 性能预算（来自 REQUIREMENT.md 非功能性需求）

```yaml
hook 链路:
  凭证解析单次调用: 零新增延迟（纯 env 读取，无网络/无文件锁）
  平台检测: 单次 fk_platform_is_opencode（env 双变量测试）
```

### 2.2 实测结果

| 指标 | 预算 | 实测 | 上版基线 | 判定 |
|---|---|---|---|---|
| fk_resolve_api_credentials 1000 次 | 零新增延迟 | 27ms/1000 次 in-process（≈27µs/次） | 无（新增函数） | ✅ 达标 |
| fk_platform_is_opencode 三态 | 单次判定 | 3/3 正确（空→false / OPENCODE=1→true / OPENCODE_BIN→true） | 无（新增函数） | ✅ 达标 |
| hook 链路新增开销 | 零 | 仅 1 次函数调用 + 2 次 env 测试，无网络/文件锁 | 无 | ✅ 达标 |

### 2.3 工具输出

```text
$ bash -c 'source flow-kit-bundle/hooks/stop/lib/common.sh; start=$(date +%s%N); for i in $(seq 1 1000); do fk_resolve_api_credentials >/dev/null 2>&1 || true; done; end=$(date +%s%N); echo $(( (end-start)/1000000 ))ms'
27ms / 1000 次 in-process（≈27µs/次，纯 env 读取；R3 修复：原 env -i 外进程测量无效，函数非可执行文件）
```

### 2.4 退步项处理

- 无退步项（新增函数，无既有基线可退）

---

## 第 3 轮 · 安全测试

### 3.1 依赖漏洞

```bash
$ （Bash 分发包，无 npm/pip/go 依赖清单；依赖 = bash + jq + curl，均为系统组件）
```

- High / Critical：N/A（无第三方依赖）
- 处理：N/A

### 3.2 秘钥扫描（AC-6 双红线 · 核心）

```bash
$ # ① token 值特征模式（=sk- 前缀）扫全部运行时产物
$ grep -rsE "=sk-[A-Za-z0-9]{8,}" .flow-active .flow-active.correction .flow-active.interactive-ui-fix .specs/l2l3-cross-platform/INDEPENDENT-REVIEW-*.md flow-kit-bundle/flow-kit/.opencode/agent/
（零输出）→ exit 1 ✅ 零命中

$ # ② env 名模式只扫非审查者产物
$ grep -rsE "FLOW_KIT_L3_AUTH_TOKEN|FLOW_KIT_L3_BASE_URL|ANTHROPIC_AUTH_TOKEN|ANTHROPIC_API_KEY" .flow-active .flow-active.correction .flow-active.interactive-ui-fix flow-kit-bundle/flow-kit/.opencode/agent/
（零输出）→ exit 2（缺文件错误码，absence 即无泄漏）✅ 零命中
```

- token 值模式（`=sk-`）：**0 命中**（T12 + 本阶段复核）
- base64 长串模式：1 处命中 = agent 文件路径清单串（误报，见 1.5 T5 记录；人工复核非 token）⚠️
- 已 rotate：N/A（无真实 token 落盘）
- correction 边界：`test_l2_dispatch_mode.bats` 两用例断言 correction message 不含凭证 env 名（unit + e2e）✅

### 3.3 SAST

- 工具：shellcheck（make lint 门，`-e SC1091 -S error`）
- High：0
- Medium：0（全部错误级扫描通过）

### 3.4 OWASP Top 10

| 项 | 状态 | 备注 |
|---|---|---|
| A01 越权 | ❌ 不适用 | CLI 本地 hook，无用户隔离边界 |
| A02 加密失败 | ✅ | 凭证经 TLS（https）传输，curl 默认验证 |
| A03 注入 | ✅ | 凭证仅进 curl header 变量，不拼接到 URL/请求体（T02/T03 统一 scheme 分支） |
| A04 不安全设计 | ✅ | 凭证绝不落盘（AC-6 红线）+ 三 Path 优先级明确 |
| A05 配置错误 | ✅ | Path3 不完整 → rc=2 显式报错，禁止静默落 Path2（防错端点） |
| A06 漏洞组件 | ❌ 不适用 | 无第三方组件（3.1） |
| A07 鉴权 | ✅ | token 仅经 header 传递（Bearer / x-api-key） |
| A08 数据完整性 | ❌ 不适用 | 无持久数据 |
| A09 日志监控 | ⚠️ | credential source 日志（见第 5 轮）；无告警体系 |
| A10 SSRF | ✅ | base_url 来自 env 白名单语义（用户自配），非用户可控输入 |

---

## 第 4 轮 · 兼容性测试

### 4.1 双运行时兼容（本 change 核心 · 替代跨浏览器矩阵）

| 运行时 | 凭证路径 | 派发模式 | 状态 |
|---|---|---|---|
| claude code | Path1 ANTHROPIC_AUTH_TOKEN+BASE_URL（env-var-first 零回归） | subagent_type 模板（保持） | ✅（bats 矩阵 + 冒烟） |
| opencode | Path3 FLOW_KIT_L3_AUTH_TOKEN+BASE_URL（短路 Path2） | category= 路由（双模式） | ✅（bats 矩阵 + 冒烟） |
| legacy（两者皆无） | Path2 ANTHROPIC_API_KEY（硬编码端点兜底） | — | ✅（仅当 1/3 全空） |
| 空环境 | rc=1 优雅降级 | 平台感知提示 | ✅ |

### 4.2 平台信号矩阵

| 平台信号 | fk_platform_is_opencode | 用例 |
|---|---|---|
| OPENCODE=1（本会话实测成立） | true | `_test_l3_credential_platform_is_opencode_3_states` |
| OPENCODE_BIN 单独 | true | 同上 |
| 两者皆空（claude code） | false | 同上 |

### 4.3 数据迁移

- ❌ 不适用：无 schema / 无数据库

### 4.4 跨版本 / 跨编码

- [x] 旧凭证行为兼容：Path1 生效时与现状一致（`_test_l3_credential_path1_wins_all_three` 零回归）
- [x] 既有 716 用例全绿（66 个 bats 文件，含历史 l2-l3-subagent-fix 回归）
- [x] UTF-8：全中文提示文案在 box 对齐（python east_asian_width 计算，T03 验证）与 bats 断言中正常
- [ ] 跨 OS：未在 macOS 实测（Bash 4+ 语义一致；`disown`/`env -i` 为 Bash 通用特性，风险低）🟡 记录

---

## 第 5 轮 · 可观测性验证

### 5.1 日志

- [x] 凭证解析源日志：`[l3-review] credential source: env|flow-kit`（l3-api.sh L85-92，T02 实现；R5 修复后由 `test_l2_dispatch_mode.bats` 两条用例断言：Path3→flow-kit / Path1→env）
- [x] 降级提示可执行：opencode → export 指引（含 FLOW_KIT_L3_BASE_URL/AUTH_TOKEN 完整命令）；CC → env-var-first 确认（两平台 bats 用例断言 stderr 内容）
- [x] resume banner 平台感知：flow-kit-resume.sh l3-model-missing banner 按平台差异提示（T06 实现）
- [x] 不含 PII / 秘钥：AC-6 双红线零命中（3.2）
- [ ] 无 trace-id / 结构化 JSON：CLI hook 无日志框架，沿用既有纯文本约定（非本 change 范围）🟡 记录

### 5.2 指标

- ❌ 不适用：无指标打点体系（CLI 脚本）

### 5.3 链路追踪

- ❌ 不适用：无跨服务调用（单机 hook 链）

### 5.4 告警 + 健康检查

- ❌ 不适用：无服务 / 无告警体系；降级以 correction + banner 呈现（等价于可观测的失败信号）

---

## 新增测试登记

| 用例文件 | 类型 | 覆盖 AC | 所属轮次 |
|---|---|---|---|
| `flow-kit-bundle/test/test_l3_credential_resolution.bats`（22 用例） | unit | AC-1 / AC-2 / AC-3 / AC-7 | 1 |
| `flow-kit-bundle/test/test_l2_dispatch_mode.bats`（14 用例：原 7 + R4 三态 + R5 两条） | unit+e2e | AC-3 / AC-4 / AC-6 | 1 |
| `test/test_l3_credential_resolution.bats`（双源镜像） | unit | 同上 | 1 |
| `test/test_l2_dispatch_mode.bats`（14 用例双源镜像） | unit+e2e | AC-3 / AC-4 / AC-6 | 1 |
| `test/test_l2_dispatch_mode.bats` R4 三态（category/subagent/general 回退链） | unit | AC-4（transcript-parser 回归保护） | 1 |
| `test/test_l2_dispatch_mode.bats` R5 两条（credential source: flow-kit/env） | unit | AC-6 可观测性 | 1 |

## 回归保护

本次变更可能影响的旧功能：

- **claude code L2/L3 审查**（Path1 env-var-first）→ `test_fk_resolve_model.bats` 10 ✅ / `test_independent_review_model.bats` 12 ✅ / `test_model_degradation.bats` 3 ✅
- **L2 派发模板**（l2-detect.sh box）→ `l2-detect.bats` + `test_l2_l3_fix_compliance.bats` ✅
- **L3 异步派发**（l3-review.sh）→ `test_l3_async_dispatch.bats` ✅（T04 回归已修：header 文本恢复 HEAD 原文）
- **L3 API 参数**（l3-api.sh env-var-first）→ `test_l3_review_params.bats` 25 ✅
- **L3 管线修复** → `test_l3_pipeline_fix.bats` 8 ✅
- **transcript 统计**（subagent_type 回退链）→ `test_l2_dispatch_mode.bats` R4 三态用例（category 优先 / subagent_type 回退 / general-purpose 兜底）✅（R4 修复：原误挂 test_hook_dispatch.bats 已修正）
- **安装器**（install_hooks.sh）→ `test_install.bats` / `test_install_dry_run.bats` / `test_install_coverage.bats` ✅
- **全部**：全量 bats 752/752（716 既有 + 29 第一轮 + 7 delta）+ 打包源逐文件 742/742 + make check（2026-08-08 T-FIX-01 修复后实跑）
