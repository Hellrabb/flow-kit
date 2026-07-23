# REQUIREMENT: L2/L3 模型配置解耦（跨平台兼容）

- **Change ID**: l2-l3-model-config
- **关联**: `@.specs/l2-l3-model-config/CHANGE.md`、`@.specs/l2-l3-model-config/DESIGN.md`、`@.specs/CONTEXT.md`
- **路径约定**：源码树在 `flow-kit-bundle/` 下，所有 AC 验证命令的路径相对项目根（如 `flow-kit-bundle/hooks/stop/lib/common.sh`）。DESIGN.md §7 的 `hooks/...` 前缀实际指 `flow-kit-bundle/hooks/...`

---

## 用户故事

- **US-1**：作为非 Claude Code 平台的 flow-kit 用户，我想通过 env var 或配置文件设置 L2/L3 审查模型，以便独立审查在任何平台上都能正常工作（跨平台核心靠 `FLOW_KIT_*` env var + `.flow-active` 直写，不依赖 agent 平台 skill）。
- **US-2**：作为 Claude Code 用户，我想**已设置的** `ANTHROPIC_*` 环境变量行为完全不变（优先级 1 命中）。⚠️ **已知行为变化**：本次移除 L2 的 `claude-sonnet-5` 硬编码 fallback（当前 `l2-detect.sh:215` 的 `${ANTHROPIC_L2_MODEL:-claude-sonnet-5}`）。未设 `ANTHROPIC_L2_MODEL` 的 CC 用户升级后，L2 审查将从「用 claude-sonnet-5」变为「降级提示」——需显式配置。此为产品决策（见「DESIGN.md 待修订点」）。

## 验收准则（AC）

每条用 Given / When / Then，必须可验证。

### AC-1 · L3 模型优先级链解析（全链覆盖）

- **Given** 逐场景独立设置前置条件（每场景独立 setup/teardown）
- **When** 调用 `fk_resolve_model "L3"`，分别覆盖五个场景：
  - 场景 A：`ANTHROPIC_DEFAULT_HAIKU_MODEL=haiku-a`（P2/P3 为空）→ 返回 `haiku-a`（优先级 1）
  - 场景 B：`ANTHROPIC_DEFAULT_HAIKU_MODEL=""` + `FLOW_KIT_L3_MODEL=gpt-4o-mini` + `.flow-active.goal.l3_model=cfg-c` → 返回 `gpt-4o-mini`（优先级 2 命中，证明压制 P3）
  - 场景 C：前两级空 + `.flow-active.goal.l3_model=from-config` → 返回 `from-config`（优先级 3）
  - 场景 D：三个源全空 → 返回空字符串（降级）
  - 场景 E（US-2 关键）：三级同设不同值（`ANTHROPIC_DEFAULT_HAIKU_MODEL=p1` + `FLOW_KIT_L3_MODEL=p2` + `.flow-active.goal.l3_model=p3`）→ 返回 `p1`（优先级 1 命中，证明「不向下查」）
- **Then** 每级取到非空值即停（场景 E 证明压制链生效）
- **验证方式**: bats 用例 `flow-kit-bundle/test/test_fk_resolve_model.bats`（每场景独立断言）

### AC-2 · L3 最高优先级命中（CC 用户不变）

- **Given** `ANTHROPIC_DEFAULT_HAIKU_MODEL=claude-haiku-4-5` 已设置
- **When** 调用 `fk_resolve_model "L3"`
- **Then** 返回 `claude-haiku-4-5`（「不向下查」的完整证明由 AC-1 场景 E 承担；本 AC 仅验证 P1 返回值正确）
- **验证方式**: `source flow-kit-bundle/hooks/stop/lib/common.sh && ANTHROPIC_DEFAULT_HAIKU_MODEL=claude-haiku-4-5 model=$(fk_resolve_model "L3") && [ "$model" = "claude-haiku-4-5" ]`

### AC-3 · L2 模型优先级链解析（全链覆盖，无 fallback）

- **Given** 逐场景独立设置前置条件（每场景独立 setup/teardown）
- **When** 调用 `fk_resolve_model "L2"`，分别覆盖五个场景：
  - 场景 A：`ANTHROPIC_L2_MODEL=sonnet-a`（P2/P3 为空）→ 返回 `sonnet-a`（优先级 1）
  - 场景 B：`ANTHROPIC_L2_MODEL=""` + `FLOW_KIT_L2_MODEL=gpt-5` + `.flow-active.goal.l2_model=cfg-c` → 返回 `gpt-5`（优先级 2 命中，证明压制 P3）
  - 场景 C：前两级空 + `.flow-active.goal.l2_model=from-config` → 返回 `from-config`（优先级 3）
  - 场景 D：三个源全空 → 返回空字符串（降级；**注意**：相对当前代码有变化，当前 fallback 到 `claude-sonnet-5`，新链不再 fallback）
  - 场景 E：三级同设不同值 → 返回 P1（优先级 1 命中）
- **Then** 每级取到非空值即停；**无第 4 级 fallback**（产品决策）
- **验证方式**: bats 用例 `flow-kit-bundle/test/test_fk_resolve_model.bats`

### AC-4a · L3 优雅降级（可观测后果，两个调用点）

- **Given** L3 模型三个源全空
- **When** **两个** L3 调用点各自调用 `fk_resolve_model "L3"` 得到空字符串：
  - `flow-kit-bundle/hooks/stop/lib/l3-review.sh`（原 `:623`）
  - `flow-kit-bundle/hooks/stop/29-independent-review.sh`（原 `:59`）
- **Then** 每个 caller 均产生**可观测降级后果**（不依赖返回码唯一性，因 `return 3` 已被 l3-review.sh 复用为通用错误码）：
  1. **不发起 API 调用**（降级在 `_l3_call_api` 之前 return；集成测试 mock `_l3_call_api` 验证未被触发，或验证无新 `INDEPENDENT-REVIEW-N.md` 写入）
  2. 写 `.flow-active.correction` 含 `type=l3-model-missing`（降级独有标记，普通错误无此 type）
  3. stderr 输出含 `FLOW_KIT_L3_MODEL` 配置提示
- **验证方式**:
  - 单元层：`(unset ANTHROPIC_DEFAULT_HAIKU_MODEL; unset FLOW_KIT_L3_MODEL; source flow-kit-bundle/hooks/stop/lib/common.sh; m=$(fk_resolve_model "L3"); [ -z "$m" ] && echo PASS)`
  - 集成层（待 4-dev）：分别 source 两 caller，断言上述三项可观测后果（关键：`type=l3-model-missing` 区分降级 vs `return 3` 的其他错误含义）

### AC-4b · L2 优雅降级（可观测后果）

- **Given** L2 模型三个源全空
- **When** `flow-kit-bundle/hooks/stop/lib/l2-detect.sh`（原 `:215`）调用 `fk_resolve_model "L2"` 得到空字符串
- **Then** 产生可观测降级后果：不发起 API 调用 + 写 `.flow-active.correction` 含 `type=l2-model-missing` + stderr 含 `FLOW_KIT_L2_MODEL` 提示
- **验证方式**:
  - 单元层：`(unset ANTHROPIC_L2_MODEL; unset FLOW_KIT_L2_MODEL; source flow-kit-bundle/hooks/stop/lib/common.sh; m=$(fk_resolve_model "L2"); [ -z "$m" ] && echo PASS)`
  - 集成层（待 4-dev）：source `l2-detect.sh`，断言三项可观测后果

### AC-5 · `/flow model` 单字段写入（L2 + L3 对称）

- **Given** `.flow-active` 已存在
- **When** 分别执行 `/flow model l3=deepseek-v4-flash` 与 `/flow model l2=deepseek-v4-pro`
- **Then** 各自原子写入（实现约定：jq `--arg` + 临时文件 mv，AC 验证最终写入正确）`.flow-active.goal.l3_model` / `.goal.l2_model`
- **验证方式**: `jq -e '.goal.l3_model=="deepseek-v4-flash"' .flow-active && jq -e '.goal.l2_model=="deepseek-v4-pro"' .flow-active`

### AC-5b · `/flow model` 合并写入

- **Given** `.flow-active` 已存在
- **When** 执行 `/flow model l2=m-a l3=m-b`（DESIGN §5 合并语法）
- **Then** 两个字段同一次操作写入：`.goal.l2_model=m-a` + `.goal.l3_model=m-b`
- **验证方式**: `jq -e '.goal.l2_model=="m-a" and .goal.l3_model=="m-b"' .flow-active`

### AC-5c · `/flow model --clear` 清除配置

- **Given** `.flow-active.goal.l2_model` 与 `.goal.l3_model` 均已设值
- **When** 分别执行 `/flow model --clear l2` 与 `/flow model --clear l3`
- **Then** 对应字段置空（`null` 或删除 key），回到 env var / 降级路径
- **验证方式**: `jq -e '.goal.l2_model == null' .flow-active && jq -e '.goal.l3_model == null' .flow-active`

### AC-5d · `/flow model` 无参显示当前配置

- **Given** `.flow-active.goal` 含 l2_model + l3_model
- **When** 执行 `/flow model`（无参）
- **Then** 终端输出包含两个模型当前值
- **验证方式**: 人工验收（显示行为非关键路径）

### AC-6 · SessionStart 收割 model-missing correction（需扩展收割逻辑）

- **Given** `.flow-active.correction` 含 `type=l3-model-missing` **或** `type=l2-model-missing`
- **When** SessionStart 触发 `flow-kit-bundle/hooks/session-start/flow-kit-resume.sh`
- **Then** banner 输出模型配置提示（含对应设置方法）
- **⚠️ 关键约束（L2 R1 查证）**：当前 `resume.sh:92-95` 收割逻辑**仅认 `type=compliance` + `.violations[]` schema**；model-missing（及其它非 compliance type）落入 else 分支被当「格式异常」+ 删文件，不出 banner。故 v1 **必须扩展 resume.sh 收割逻辑**识别 model-missing type（非「复用既有」）。model-missing correction schema（字段集）待 2-design 定义，须与既有 `type=l2-missing`（语义=L2 盲审段缺失，`29-independent-review.sh:20`）**精确等值区分**，避免近形碰撞
- **验证方式**: bats 用例 `flow-kit-bundle/test/test_flow_kit_resume.bats`，对称覆盖两分支：写入 model-missing correction → source hook → grep banner 输出含对应 `FLOW_KIT_*_MODEL` + **断言文件未被当异常删除**

### AC-7 · 现有测试全绿（无回归）

- **Given** 改动完成
- **When** 运行全量 bats
- **Then** 全 pass，0 fail
- **验证方式**: `npx bats flow-kit-bundle/test/ && echo PASS || echo FAIL`（exit code 判定）

---

## 范围切分

### v1（本次必做）

- `flow-kit-bundle/hooks/stop/lib/common.sh` 新增 `fk_resolve_model`（L3 + L2 优先级链，无 fallback）
- `flow-kit-bundle/hooks/stop/lib/l3-review.sh`（原 `:623`）替换 `:?` → `fk_resolve_model "L3"` + 降级（API 前 return + correction）
- `flow-kit-bundle/hooks/stop/lib/l2-detect.sh`（原 `:215`）替换 fallback → `fk_resolve_model "L2"` + 降级
- `flow-kit-bundle/hooks/stop/29-independent-review.sh`（原 `:59`）替换 `:?` → `fk_resolve_model "L3"` + 降级
- `flow-kit-bundle/hooks/session-start/flow-kit-resume.sh` **扩展收割逻辑**识别 `l2-model-missing` / `l3-model-missing` type（当前 `:92-95` 仅认 `compliance` + `.violations[]`，需新增分支；**非复用**）
- `flow-kit-bundle/skills/flow/SKILL.md` 加 `/flow model` 路由
- `flow-kit-bundle/skills/flow-model/SKILL.md` 新增 skill，覆盖 DESIGN §5 全部语法（设置 / 合并 / --clear / 显示）
- 新增 bats `flow-kit-bundle/test/test_fk_resolve_model.bats`（AC-1/AC-3 全链）+ 扩展 `test_flow_kit_resume.bats`（AC-6）

### v2（下一轮考虑，不本次）

- 模型名白名单校验（值域不校验，由用户/供应商决定）
- API 自动探测（调 `/v1/models`）— ADR-011 已排除
- `install.sh` 安装时自动检测当前平台可用模型并推荐配置

### out（永远不做）

- 在 flow-kit 内置硬编码模型名映射表
- 修改 `package-flow-kit.sh` 打包流程
- 保留 `claude-sonnet-5` 作为 L2 第 4 级 fallback（产品决策：纯跨平台，已移除）

---

## 非功能性需求

- **性能**: `fk_resolve_model` 仅 env var 读取 + 一次 jq 调用，无网络/IO，调用开销 < 10ms
- **可访问性**: 无
- **安全**: 模型名不校验值域（由用户/供应商负责）；**实现侧必须用 `jq --arg` 引用拼接，禁止裸插值**（防 shell/JSON 注入）；错误模型名导致 API 失败由 caller 降级处理
- **兼容性**: 已设 `ANTHROPIC_*` 的 CC 用户优先级 1 命中，行为不变；未设 `ANTHROPIC_L2_MODEL` 的 CC 用户**行为有变化**（见 US-2）；非 CC 平台通过 `FLOW_KIT_*` env var 或 `.flow-active` 直写配置（**不依赖 `/flow model` skill**，该 skill 依赖 agent 平台 skill 路由，是 CC 平台增值）；全未配置时优雅降级
- **可观测性**: 降级写 `.flow-active.correction`（复用既有机制，新增 model-missing type）+ stderr 提示；SessionStart 收割 banner

## 依赖与假设

- 依赖 `jq` 解析 `.flow-active`（已存在）
- **correction 机制现状（L2 R1 查证，订正先前「可复用」声明）**：
  - **写入侧**已存在：`weak-model-compliance.sh`（type=compliance，schema `{type, violations[]}`）、`29-independent-review.sh`（type=l2-missing，schema `{type, phase, change_id, message}`）—— model-missing 写入可参照这两种模式
  - **收割侧（resume.sh）不认 model-missing**：`:92-95` 仅处理 `type=compliance + violations[]`，其它 type 当异常删除。故 v1 必须**扩展收割逻辑**，并定义 model-missing schema（待 2-design）
- 假设 `common.sh` 已被 3 个调用点 source（当前已满足）
- 假设 `PROJECT_ROOT` 在调用 `fk_resolve_model` 时已设置（common.sh 已设）

---

## DESIGN.md 待修订点（2-design 阶段处理）

1. **§8 兼容性表错误**：声称「CC 用户完全不变」与 US-2 矛盾。L2 fallback（`claude-sonnet-5`）被 §1 链移除，未设 `ANTHROPIC_L2_MODEL` 的 CC 用户行为变化。需修正 §8 + 标注为有意权衡。
2. **§7 路径前缀**：文件清单 `hooks/...` 实际为 `flow-kit-bundle/hooks/...`。需补前缀或注明 CWD。
3. **§1 已正确**：L2 三级链 + 空降级（产品决策确认移除 fallback）。
4. **§5 已被 REQUIREMENT AC-5/5b/5c/5d 完整覆盖**：设置 / 合并 / --clear / 显示四类语法均有 AC 守卫。
5. **§4 降级 correction 机制需补设计（L2 R1）**：DESIGN §4 声称「写 correction + SessionStart 收割」，但未说明 resume.sh 收割逻辑需扩展（当前仅认 compliance）。2-design 须补：(a) model-missing correction schema 定义（区分既有 `l2-missing`=L2 段缺失）；(b) resume.sh 收割分支扩展设计；(c) caller 降级在 API 前 return（不发起调用）以区别于 `return 3` 的通用错误。
6. **§3 `return 3` 撞名**：DESIGN §3 示例降级用 `return 3`，但 l3-review.sh 已 14 处用 `return 3` 为通用错误码。2-design 须明确降级信号靠可观测后果（correction type + 不发起 API），不靠返回码。

---

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
