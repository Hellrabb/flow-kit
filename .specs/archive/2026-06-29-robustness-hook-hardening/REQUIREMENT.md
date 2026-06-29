# REQUIREMENT: 弱模型鲁棒性 Hook 化升级

- **Change ID**: `robustness-hook-hardening`
- **关联**: `@.specs/robustness-hook-hardening/CHANGE.md`、`@.specs/CONTEXT.md`

---

## 用户故事

- **US-1**：作为 flow-kit 用户，我想在每次会话停止时自动检测弱模型是否触碰了禁动文件/违反规则，以便在下次会话开始前就能矫正违规行为。
- **US-2**：作为 flow-kit 用户，我想系统验证模型是否完整填写了阶段自检表（无空白/跳过），以便确信模型没有偷懒跳过验证步骤。
- **US-3**：作为 flow-kit 用户，我想系统验证模型回复中引用的文件路径/API/字段名是否在工具调用历史中出现过，以便信任模型的证据链而非幻觉。
- **US-4**：作为 flow-kit 用户，我想所有矫正指令通过统一的矫正文件跨 session 传递，以便 SessionStart 一次性注入所有类型的矫正提示。

## 验收准则（AC）

每条用 Given / When / Then，必须可验证。

### AC-1 · L1 规则合规检测

- **Given** 一次会话刚停止，transcript 中存在模型回复，且回复中触碰了 CONTEXT.md 禁动清单中的文件路径或违反了 RULES.md/SYSTEM.md 中的通用禁动规则（如"禁止编造文件路径"、"禁止跳过 AskUserQuestion"等）
- **When** Stop hook 执行 `28-weak-model-compliance.sh` 的 L1 扫描
- **Then** 检测到违规 → 写入 `.flow-active.correction`（`type: "compliance"`, `layer: "L1"`, 含违规描述 + 文件路径行号 + 修复建议）；未检测到违规 → 不写入
- **验证方式**: `npx bats test/test_weak_model_compliance.bats` 中 L1 场景全部通过（≥ 3 个场景）

### AC-2 · L2 自检完整性检测

- **Given** 一次会话刚停止，模型回复中包含阶段自检表（如 Phase Completion Self-Check），其中存在空白行（未标记 ✅/❌）或被模型跳过未填
- **When** Stop hook 执行 `28-weak-model-compliance.sh` 的 L2 扫描
- **Then** 检测到未完成的自检表 → 写入 `.flow-active.correction`（`type: "compliance"`, `layer: "L2"`, 含缺失条目清单 + 补填要求）；所有自检表完整 → 不写入
- **验证方式**: `npx bats test/test_weak_model_compliance.bats` 中 L2 场景全部通过（≥ 3 个场景）

### AC-3 · L3 证据链真实性检测

- **Given** 一次会话刚停止，模型回复中引用了某个文件路径/API 名/字段名，但该引用在 transcript 的工具调用历史中从未出现（即模型未实际 grep/read 该路径，属幻觉引用）
- **When** Stop hook 执行 `28-weak-model-compliance.sh` 的 L3 扫描
- **Then** 检测到幻觉引用 → 写入 `.flow-active.correction`（`type: "compliance"`, `layer: "L3"`, 含幻觉路径 + 要求先 grep 验证的矫正指令）；所有引用均可溯源 → 不写入
- **验证方式**: `npx bats test/test_weak_model_compliance.bats` 中 L3 场景全部通过（≥ 3 个场景）

### AC-4 · 统一矫正文件读写

- **Given** Stop hook 完成 L1/L2/L3 扫描后有违规发现
- **When** 写入 `.flow-active.correction`
- **Then** 文件为合法 JSON，包含 `type: "compliance"` 字段、`layer`（L1/L2/L3）、`violations` 数组（每项含 `rule`/`location`/`fix`）、`written_at` 时间戳；同一 session 多次写入时合并而非覆盖；SessionStart 注入矫正后清除该文件（`rm -f .flow-active.correction`）
- **验证方式**: `npx bats test/test_weak_model_compliance.bats` 中矫正文件读写场景通过（≥ 2 个场景）

### AC-5 · SessionStart 识别并注入矫正

- **Given** 上次会话 Stop hook 写入了 `.flow-active.correction`（`type: "compliance"`）
- **When** 下次会话启动，SessionStart `flow-kit-resume.sh` 执行
- **Then** 检测到 `.flow-active.correction` 存在 → 解析 JSON → 在会话横幅中注入合规矫正指令（格式与 `interactive-ui-fix` 矫正 banner 一致，包含违规层级 + 具体修复动作）；注入后删除文件；若 JSON 解析失败 → 输出警告并删除损坏文件
- **验证方式**: 手动 UAT — 模拟写入矫正文件 → 启动新会话 → 确认横幅含矫正内容且文件已清除

### AC-6 · 现有测试无回归

- **Given** 新增 hook 模块 `28-weak-model-compliance.sh` + lib 文件 + 测试文件
- **When** 运行 `npx bats test/`
- **Then** 全部 194 个现有测试通过（不要求 194 精确数字——以当前 `npx bats test/ --formatter tap | grep -c '^ok '` 输出为准），新增测试计入总数
- **验证方式**: `npx bats test/` 零 fail

### AC-7 · 代码长度软指标

- **Given** hook 模块 `28-weak-model-compliance.sh` + lib `weak-model-compliance.sh` 实现完毕
- **When** 统计代码行数（不含空行和纯注释行）
- **Then** 主逻辑代码 ≤ 350 行（软指标——超出时人工判断是否可接受，不做硬阻断）
- **验证方式**: `cat <files> | grep -cvE '^\s*(#|$)'`

---

## 范围切分

### v1（本次必做）

- Stop hook 模块 `28-weak-model-compliance.sh`（协调层，调用 lib）
- Lib `weak-model-compliance.sh`：L1 规则合规扫描 + L2 自检完整性扫描 + L3 证据链真实性扫描
- 统一矫正文件 `.flow-active.correction`（JSON，`type: "compliance"`，`layer: L1/L2/L3`）
- SessionStart `flow-kit-resume.sh` 扩展：识别 `.flow-active.correction` 并注入矫正 banner
- bats 测试：L1/L2/L3 各 ≥ 3 个场景 + 矫正文件读写 ≥ 2 个场景（共 ≥ 11 个测试用例）
- 现有 194 tests 全部通过（无回归）

### v2（下一轮考虑，不本次）

- 将现有 `27-interactive-ui-check.sh` 迁移到统一 `.flow-active.correction` 格式（`type: "interactive-ui"`）
- L1 规则模式库扩展（从 RULES.md/SYSTEM.md 自动提取禁动规则，而非硬编码）
- L3 跨文件引用链验证（验证 A→B→C 引用链而非仅单跳）
- `.flow-active.correction` 的 retry_count 机制（连续 ≥ 3 次同类违规暂停提示人工介入，对标 `interactive-ui-fix` 的 retry 策略）
- L2 自检表模式自动发现（自动识别新 prompt 中新增的自检表格式，而非硬编码 PCSC 模板）

### out（永远不做）

- 实时检测（在模型生成过程中拦截）—— hook 只在 session 边界执行
- brooks-lint / gateflow 插件集成（本 change 仅覆盖 flow-kit 核心 hook 系统）
- L4 伪双轨（`model_tier` opt-out）—— 已在 weak-model-robustness 中明确归 v2
- 自动修复违规（hook 只检测+报告，不做代码变更）

---

## 非功能性需求

- **性能**: Stop hook 28 号模块在 transcript ≤ 5000 行时执行时间 ≤ 2 秒（grep 扫描为主，不做 NLP 分析）
- **可访问性**: 无
- **安全**: 矫正文件 `.flow-active.correction` 不入库（`.gitignore` 已有 `.*-fix` 模式覆盖）；仅读取 transcript 和 `.specs/` 下的规则文件，不访问网络或外部系统
- **兼容性**: Bash ≥ 4.0（与现有 hook 系统一致）；依赖 `jq`（JSON 处理，已在环境中有）；通用 grep/sed/awk（POSIX）
- **可观测性**: 每次违规写入矫正文件时在 transcript 末尾追加一行 `[28-weak-model-compliance] L1/L2/L3 violation detected → .flow-active.correction`；无违规时静默（不产生噪声）

## 依赖与假设

- **依赖**: Stop hook 链框架（`flow-kit-bundle/hooks/stop/lib/common.sh`）继续可用；SessionStart `flow-kit-resume.sh` 可安全扩展
- **依赖**: `jq` 已在目标环境安装（由 `install.sh` 环境检查覆盖）
- **依赖**: `27-interactive-ui-check.sh` 继续写入 `.flow-active.interactive-ui-fix`（v1 不改动 27 号模块），SessionStart 同时处理两个矫正文件（`.flow-active.interactive-ui-fix` + `.flow-active.correction`）
- **假设**: 弱模型的违规模式可以通过 grep 正则匹配捕获（不依赖 NLP/语义理解）
- **假设**: transcript 格式稳定（当前 CC transcript JSONL 格式），路径/工具调用可通过确定性模式提取
- **假设**: CONTEXT.md 禁动清单条目格式保持 `- \`<path>\`（说明）` 结构，可通过正则解析

---

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
