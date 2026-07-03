# REQUIREMENT: l3-review.sh 加固

- **Change ID**: l3-review-hardening
- **关联**: `@.specs/l3-review-hardening/CHANGE.md`

---

## 用户故事

- **US-1**: 作为 flow-kit 用户，我希望 L3 在 phase 6 能审查完整代码（含新增文件），以便不因 `git diff` 的局限误判 fail。
- **US-2**: 作为 flow-kit 用户，我希望 L3 在 phase 7 能看到所有归档产物，以便正确判断"产物是否齐全"。
- **US-3**: 作为 flow-kit 用户，我希望每次 L3 重跑后 review 文件只保留最新结果，以便不被旧版本误导。
- **US-4**: 作为使用 DeepSeek 端点的用户，我希望 L3 能正常工作，不因 content type / token / timeout / verdict 格式差异而失败。

## 验收准则（AC）

### AC-1 · Phase 6 git diff 含新增文件

- **Given** 项目有新增的 untracked `.sh` 或 `.bats` 文件（如 `33-flow-active-integrity.sh`）
- **When** L3 phase 6 收集 artifact
- **Then** `git ls-files --others --exclude-standard | grep -E '\.(sh|bats)$'` 的输出内容被追加到 `git diff HEAD` 之后，使模型能看到新文件内容
- **验证方式**: 构造含 untracked `.sh` 的临时 git repo，调 `l3_review_run 6`，确认 artifact 包含新文件内容

### AC-2 · Phase 7 传全部产物摘要

- **Given** `.specs/<id>/` 下有完整的 CHANGE/REQUIREMENT/DESIGN/TASK/TEST/REVIEW/INTEGRATION.md
- **When** L3 phase 7 收集 artifact
- **Then** artifact 包含目录清单 + 每个产物的前 3000 字符（缺失的标 `MISSING`）
- **验证方式**: bats 测试——构造完整产物目录，验证 artifact 含全部 7 个文件名

### AC-3 · L3 段幂等写入

- **Given** `INDEPENDENT-REVIEW-<N>.md` 已有 1 个 `## L3 盲审` 段
- **When** L3 重新运行同一 phase
- **Then** 旧 L3 段被移除，仅保留新写入的 1 个 L3 段
- **验证方式**: bats 测试——先写旧 L3 段，再跑 L3，确认文件只剩 1 个 `## L3 盲审`

### AC-4 · DeepSeek 双 block 内容提取

- **Given** API 返回 `content: [{type:"thinking",...}, {type:"text", text:"..."}]`
- **When** `l3-review.sh` 解析响应
- **Then** 提取 `type=="text"` 的 block 内容（非 `type=="thinking"`）
- **验证方式**: bats 测试——构造双 block JSON 响应，验证 `content` 变量取到 text block 内容

### AC-5 · 超时和 token 适配 DeepSeek

- **Given** 使用 DeepSeek 端点（thinking 模式）
- **When** L3 调 API
- **Then** `max_tokens=8000`（非 2000），`--max-time=90`（非 25）
- **验证方式**: grep `l3-review.sh` 确认这两个参数值

### AC-6 · 3 层 verdict 提取

- **Given** 模型可能返回 code-block JSON、raw JSON、或 mixed text+JSON
- **When** L3 提取 verdict
- **Then** 依次尝试：① code block 提取 ② 直接 jq 解析 ③ `grep -oP` 正则 fallback；三层均失败才报 "unknown"
- **验证方式**: bats 测试 3 种格式各一条 case

---

## 范围切分

### v1（本次必做）

- AC-1 ~ AC-6 全部 6 项修复
- bats 测试覆盖（≥6 cases）
- 运行时同步（bundle → `~/.claude/hooks/stop/lib/`）

### v2（下一轮考虑）

- l3-review.sh 重构——拆分为 prompt 构造 + API 调用 + 响应解析三个函数
- L3 模型选择从 env var + config 双源统一为单源

### out（永远不做）

- L3 实时触发（改 PreToolUse hook 同步调 L3）——已由 `pipeline-fallback-fix` F1 修复方案覆盖，不在本 change 范围
- L3 并行化（多阶段并发调 API）

---

## 非功能性需求

- **性能**: 每次 L3 调用耗时从 ~30s 增加到 ~90s（仅当使用 DeepSeek 端点时；Anthropic 原生端点不受影响）
- **兼容性**: 向后兼容——Anthropic 原生 API 仍走原代码路径（`content[0].text` 优先匹配）
- **可观测性**: verdict 提取失败时输出具体原因（"no text block found" / "no verdict in JSON" / "regex mismatch"）而非统一 "invalid verdict"

## 依赖与假设

- 依赖 `jq`、`curl`、`grep -P`（PCRE 正则，Linux 默认有）
- 假设 DeepSeek Anthropic-compatible API 的 content block 结构为 `[{thinking}, {text}]`，未来可能变化
- 假设 `git ls-files --others` 权限可用
