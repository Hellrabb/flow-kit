# REQUIREMENT: L3 审查工具超时/token 上限可配置化

- **Change ID**: l3-review-timeout-token
- **关联**: `@.specs/l3-review-timeout-token/CHANGE.md`、`@.specs/CONTEXT.md`

---

## 用户故事

- **US-1**：作为 flow-kit 用户，我想让 L3 审查工具的 `max_tokens` / `curl --max-time` / `thinking` 可通过 env var 配置，以便 deepseek-v4-pro 扩展思考模式不再因硬编码上限（8000 token / 90s）而吃满预算或超时。
- **US-2**：作为被 L3 审查卡住的 change（gate-done-authorship），我想让 L3 工具能承载大产物审查，以便 phase 3 的 L3 复核不再 rc=3 超时/空响应，pipeline 能继续推进。

---

## 验收准则（AC）

> **Mock 策略（R2 落地 · 贯穿 AC-1~AC-7）**：bats 用函数覆盖（stub）`_l3_call_api` 内的 `curl` 命令——在测试中定义 `curl()` shell 函数覆盖真实 curl，捕获传入的命令行参数 + 请求体 JSON 字符串并断言字段，不打真实网络。**禁止 stub 整个 `_l3_call_api` 函数**（那会让请求体断言沦为同义反复）——只 stub 内部的 `curl` 调用，保留 `_l3_call_api` 的请求体构造逻辑被测。此 mock 方式是 AC 的一部分，TEST 阶段不得自由裁量引入新设计。**适用范围**：仅限当前 `_l3_call_api` 内部用 curl 调用 HTTP 的实现版本；若未来重构改用其他 HTTP 客户端，mock 策略需同步更新（属 TEST 阶段设计决策，记录在 DESIGN.md § 测试策略）。

每条用 Given / When / Then，必须可验证。

### AC-1 · max_tokens 可配置 + 默认值提高（双路径）

- **Given** `l3-review.sh::_l3_call_api()` 原硬编码 `max_tokens:8000`（路径1 阿里云代理 L350 / 路径2 Anthropic 直连 L366），bats stub `curl` 捕获请求体
- **When** 不设 `FLOW_KIT_L3_MAX_TOKENS` env var，分别触发路径1（`ANTHROPIC_BASE_URL` + `ANTHROPIC_AUTH_TOKEN` 已设）与路径2（`ANTHROPIC_API_KEY` 已设、前两者未设）
- **Then** 两条路径捕获的请求体 JSON 均含 `"max_tokens":32000`（默认值提高，两路径一致）
- **验证方式**: `bats test/test_l3_review.bats` — stub curl，分别对路径1/路径2 各断言一次请求体含 `max_tokens":32000`

### AC-2 · FLOW_KIT_L3_MAX_TOKENS env var 覆盖（双路径）

- **Given** 设置 `FLOW_KIT_L3_MAX_TOKENS=16000`，bats stub `curl`
- **When** 分别触发路径1 与路径2
- **Then** 两条路径请求体均含 `"max_tokens":16000`（env var 覆盖默认值，两路径一致）
- **验证方式**: `FLOW_KIT_L3_MAX_TOKENS=16000 bats test/test_l3_review.bats`（stub curl 双路径断言）

### AC-3 · curl --max-time 可配置 + 默认值提高（双路径）

- **Given** 原硬编码 `curl --max-time 90`（路径1 L346 / 路径2 L362），bats stub `curl` 捕获命令行参数
- **When** 不设 `FLOW_KIT_L3_TIMEOUT` env var，分别触发路径1 与路径2
- **Then** 两条路径的 curl 命令行均含 `--max-time 300`（默认值提高，两路径一致）
- **验证方式**: `bats test/test_l3_review.bats` — stub curl，双路径断言命令行含 `--max-time 300`

### AC-4 · FLOW_KIT_L3_TIMEOUT env var 覆盖（双路径）

- **Given** 设置 `FLOW_KIT_L3_TIMEOUT=600`，bats stub `curl`
- **When** 分别触发路径1 与路径2
- **Then** 两条路径 curl 命令行均含 `--max-time 600`（env var 覆盖默认值，两路径一致）
- **验证方式**: `FLOW_KIT_L3_TIMEOUT=600 bats test/test_l3_review.bats`（stub curl 双路径断言）

### AC-5a · FLOW_KIT_L3_THINKING=enabled 显式设置（双路径）

- **Given** bats stub `curl` 捕获请求体
- **When** 显式设置 `FLOW_KIT_L3_THINKING=enabled`，分别触发路径1 与路径2
- **Then** 两条路径请求体均**不含** `thinking` 字段（保持 deepseek-v4-pro 默认扩展思考）
- **验证方式**: `FLOW_KIT_L3_THINKING=enabled bats test/test_l3_review.bats`（stub curl 双路径断言不含 thinking）
- **与未设的区别**：AC-5a 验证 enabled **显式设置**被正确读取处理（而非被忽略恰好默认一致）——通过对比"未设"基线（AC-5c）与"显式 enabled"（AC-5a），若两者行为一致且"显式 disabled"（AC-5b）不同，则证明 enabled 路径被执行

### AC-5b · FLOW_KIT_L3_THINKING=disabled 显式设置（双路径）

- **Given** bats stub `curl` 捕获请求体
- **When** 显式设置 `FLOW_KIT_L3_THINKING=disabled`，分别触发路径1 与路径2
- **Then** 两条路径请求体均含 `"thinking":{"type":"disabled"}`
- **验证方式**: `FLOW_KIT_L3_THINKING=disabled bats test/test_l3_review.bats`（stub curl 双路径断言含 thinking 字段）

### AC-5c · FLOW_KIT_L3_THINKING 未设（基线 · 双路径）

- **Given** bats stub `curl` 捕获请求体，**不设** `FLOW_KIT_L3_THINKING` env var
- **When** 分别触发路径1 与路径2
- **Then** 两条路径请求体均**不含** `thinking` 字段（默认行为等同 enabled）
- **验证方式**: `bats test/test_l3_review.bats`（stub curl 双路径断言不含 thinking，作为 AC-5a/5b 的对照基线）
- **边界声明（R8 落地）**：AC-5a/5b/5c 只断言工具侧请求体字段，不断言 API 侧是否实际不扩展思考（API 可能忽略该字段）——API 侧行为属"依赖与假设"，不进 Then

### AC-6 · Fail-safe：env var 非法值回退默认 + 告警（R3 落地 · 双路径）

- **Given** bats stub `curl` 捕获请求体 + 捕获 stderr，分别触发路径1 与路径2
- **When** 设置非法 env var 值（每条双路径各测一次）：
  - `FLOW_KIT_L3_MAX_TOKENS=abc`（非数字）→ 两路径请求体 `max_tokens` 均回退默认 `32000` + stderr 含警告
  - `FLOW_KIT_L3_MAX_TOKENS=`（空）→ 两路径同上回退
  - `FLOW_KIT_L3_TIMEOUT=xyz`（非数字）→ 两路径 curl `--max-time` 均回退默认 `300` + stderr 警告
  - `FLOW_KIT_L3_TIMEOUT=`（空）→ 两路径同上回退（R12 补）
  - `FLOW_KIT_L3_THINKING=yes`（非 `{enabled,disabled}` 枚举）→ 两路径请求体均不含 `thinking` 字段（按 enabled 默认处理）+ stderr 警告
  - `FLOW_KIT_L3_THINKING=`（空）→ 两路径同上按 enabled 默认 + 警告（R12 补）
- **Then** 非法值不透传给 API（不制造新 rc=3），两路径均回退默认 + hook log 警告，不崩溃
- **验证方式**: `FLOW_KIT_L3_MAX_TOKENS=abc bats test/test_l3_review.bats` 等 6 个非法值用例（stub curl 双路径断言回退 + grep stderr 警告）

### AC-7 · 可观测性：env var 覆盖值记入 hook log（R3 落地 · 双路径）

- **Given** bats stub `curl`，捕获 stderr，分别触发路径1 与路径2
- **When** 设置 `FLOW_KIT_L3_MAX_TOKENS=16000` + `FLOW_KIT_L3_TIMEOUT=600` + `FLOW_KIT_L3_THINKING=disabled`，分别触发路径1 与路径2
- **Then** 两路径 stderr 均含一行 `[l3-review] using max_tokens=16000 timeout=600 thinking=disabled`（覆盖值记录）
- **验证方式**: `bats test/test_l3_review.bats` — 双路径 grep stderr 断言配置记录行

### AC-8 · 全量 bats 回归 0 fail

- **Given** 本 change 所有代码修改完成
- **When** 执行 `make test`（等效 `npx bats test/`，make test 内部调用 npx bats test/）
- **Then** 全部测试通过，0 fail，exit code 0
- **验证方式**: `make test`，输出 `N ok, 0 fail`

### AC-10 · 静默错判验证（C3 落地 · R1b 强制验证）

- **Given** 本 change 实施后，`_l3_parse_result` 的 fallback 链（l3-review.sh:378 `[.content[]|select(.type=="text")|.text][0] // .content[0].thinking // .content[0].text // empty`）不改（Out of Scope）
- **When** 4-dev 用 enabled+32k 配置对大产物 prompt（如 gate-done-authorship phase 3 TASK.md）跑一次 L3 调用，打印 `.content[0]` 结构 + 提取的 content
- **Then** 
  - 若产出含 `type=text` block → content 提取 text（正常）
  - 若思考吃满预算无 text block，仅有 thinking block → **记录 `.content[0]` 字段名**（确认是否 `.thinking`/`.text`），**判定是否触发 fallback 静默错判**（提取思考内容当 verdict）
  - 若触发静默错判 → 记录为已知风险（DESIGN R2），建议后续 change 修 fallback（不阻塞本 change，本 change scope 仅参数可配）
- **验证方式**: 4-dev 手动执行 + 记录 `.content[0]` 结构到 T01-SUMMARY.md「实测证据」段。此 AC 为强制验证（非可选建议），确保最危险失效模式（静默错判）被实测覆盖

### AC-9 · 端到端冒烟（手动 · 非回归验收线 · R1 落地）

- **Given** 本 change 实施完成 + deepseek-v4-pro API 实时可用 + 任一已完成 phase 2（含 DESIGN.md 产物）的 change 存在
- **When** 手动 `source l3-review.sh && l3_review_run <phase> <change-id> <specs_dir> pass both`（用任意已 phase-2-done 的 change 的 phase + id + 路径）
- **Then** 返回 `rc ∈ {0,1}`（verdict=pass 或 fail）且 summary 非空，**非 rc=3**（超时/空响应）
- **验证方式**: 手动执行 + 检查 rc + summary 非空
- **降级声明（R1 落地）**：本 AC 依赖外部 deepseek API 实时可用，**非离线可验证，不纳入回归验收线**（AC-8 全量 bats 不含此项）。作为手动冒烟附录项，不影响本 change 的 spec 合规判定。当前解套场景：用 gate-done-authorship（phase 3 已 phase-2-done）验证

---

## 范围切分

### v1（本次必做）

- `_l3_call_api()` 的 `max_tokens` / `curl --max-time` / `thinking` 三项可配置化
- 默认值提高：max_tokens 8000→32000，timeout 90→300
- `FLOW_KIT_L3_THINKING` env var（默认 enabled，可切 disabled）
- 两处请求体（路径1 阿里云代理 / 路径2 Anthropic 直连）同步改
- 新增 bats stub curl 测试（双路径断言 + env var 覆盖 + Fail-safe + 可观测性）
- 全量 bats 回归 0 fail

### v2（下一轮考虑，不本次）

- TD-008：l3-review.sh 574 行拆分为 l3-detect/dispatch/truncate 子库（多职责重构）
- thinking budget 精细化（`thinking:{type:"enabled", budget_tokens:N}`，依赖 API 支持）
- L3 模型自动探测 + 非 thinking 模型推荐

### out（永远不做）

- 不改 L3 审查的 prompt 构建（`_l3_build_prompt`）
- 不改 L3 结果解析（`_l3_parse_result`）
- 不改 L3 重审/积压扫描（`_l3_check_rerun` / `_l3_scan_backlog`）
- 不改 gate 机制（gate-done-authorship 的 scope）
- 不换 L3 默认模型（保持 deepseek-v4-pro）

---

## 非功能性需求

- **性能**: L3 调用默认 timeout 提至 300s，单次 L3 审查最坏情况 ~5min（可接受，L3 非热路径）；env var 可下调。max_tokens 默认 8000→32000（4 倍）可能增加 API token 消耗成本，该成本已评估为可接受（L3 审查非高频操作），用户可通过 `FLOW_KIT_L3_MAX_TOKENS` env var 自行下调
- **可访问性**: 无（非 UI 项目）
- **安全**: 无新安全风险——env var 覆盖仅影响 L3 调用参数，不涉及凭证或路径
- **兼容性**: 
  - 向后兼容：不设 env var 时行为改变（max_tokens 8000→32000，timeout 90→300）——这是预期改进，非破坏性
  - 既有 L3 测试不受影响（断言行为而非具体数值）
- **可观测性**: env var 覆盖值记入 hook log（`[l3-review] using max_tokens=X timeout=Y thinking=Z`），对应 AC-7
- **Fail-safe**: env var 值非法（非数字 / 空 / 枚举非法）→ 回退默认值 + hook log 警告，不崩溃，对应 AC-6

---

## 依赖与假设

- **依赖**：
  - `flow-kit-bundle/hooks/stop/lib/l3-review.sh::_l3_call_api()`（L346/350/362/366 四处硬编码）
  - `test/test_l3_review.bats`（既有 L3 测试，需补 stub curl + env var 覆盖用例）
- **假设**：
  - deepseek-v4-pro API（阿里云代理 `token-plan.cn-beijing.maas.aliyuncs.com` + Anthropic 直连）均支持 `max_tokens` 参数调整
  - `thinking:{type:"disabled"}` 字段被 API 接受（L3 子 agent 实测：禁用后 58.4s 返回 3334 token 含 text block）——但 API 是否实际禁用思考属 API 侧行为，本 change 只保证请求体字段正确（R8 边界）
  - env var 覆盖遵循既有的 env-var-first config 策略（CONTEXT.md `[2026-07-01]` 已锁决策）
  - bats 可通过函数覆盖（stub）`curl` 命令捕获请求体/命令行参数（R2 mock 策略）

---

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
