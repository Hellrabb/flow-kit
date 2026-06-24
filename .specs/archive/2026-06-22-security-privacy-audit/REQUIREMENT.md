# REQUIREMENT: 安全与隐私泄露全面审查

- **Change ID**: security-privacy-audit
- **关联**: `@.specs/security-privacy-audit/CHANGE.md`、`@.specs/CONTEXT.md`

---

## 用户故事

- **US-1**：作为仓库维护者，我想确保代码库中不存在硬编码的密钥/Token/密码，以便安全地 push 到公开仓库而不暴露凭证。
- **US-2**：作为仓库维护者，我想确保代码库中不包含内部路径、IP 地址和个人目录信息，以便公开后不暴露内部基础设施。
- **US-3**：作为仓库维护者，我想确保代码库中不含个人身份信息（邮箱、手机号、真实姓名），以便维护隐私安全。
- **US-4**：作为仓库维护者，我想确保 Shell 脚本中不存在命令注入和路径遍历漏洞，以便公开的代码不会成为攻击向量。
- **US-5**：作为仓库维护者，我想确保 Git 历史提交中不存在曾提交后又删除的敏感信息，以便完整的 clone 历史也是安全的。
- **US-6**：作为仓库维护者，我想确认所有第三方 API 端点和外部服务 URL 都是公开可用的（非内部地址），以便不暴露内部服务。

## 验收准则（AC）

每条用 Given / When / Then，必须可验证。

### AC-1 · 硬编码凭证扫描

- **Given** 仓库根目录下全部文本文件（`.sh`、`.json`、`.md`、hooks/、lib/、配置文件）
- **When** 运行凭证模式扫描（`grep -rInE '(api[_]?key|apikey|secret|token|password|passwd|credential|private[_]?key|access[_]?key|auth[_]?token)' --include='*.sh' --include='*.json' --include='*.md' --include='*.yml' --include='*.yaml' --include='*.conf' --include='*.env' .` ，排除 `.git/`、`node_modules/`、`flow-kit-bundle/`）
- **Then** 扫描结果为零匹配（或所有匹配项均为注释/示例/占位符，经人工确认后标记为 `✅ FALSE_POSITIVE`）
- **验证方式**: `grep -rInE '<pattern>' . | grep -v '.git/' | grep -v 'flow-kit-bundle/' | grep -v 'node_modules/'` 输出为空或仅有已标记误报

### AC-2 · 内部路径与个人目录泄露扫描

- **Given** 仓库根目录下全部文件
- **When** 运行路径泄露模式扫描（`grep -rInE '(/home/|/Users/|/root/|hellrabbit|/tmp/[a-zA-Z0-9]+)' --include='*.sh' --include='*.json' --include='*.md' .`，排除 `.git/`、`flow-kit-bundle/`）
- **Then** 项目相关路径（如 `/home/hellrabbit/unisoc/flow-kit` 项目路径）识别并标记；非项目路径（如个人临时目录、其他用户路径）标记为 🔴 需修复
- **验证方式**: `grep -rInE '<pattern>' . | grep -v '.git/' | grep -v 'flow-kit-bundle/'` 仅含项目路径或零匹配

### AC-3 · 个人信息泄露扫描

- **Given** 仓库根目录下全部文件
- **When** 运行个人信息模式扫描（邮箱正则 `[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}`、手机号正则 `1[3-9]\d{9}`、身份证正则 `\d{17}[\dXx]`，排除 `.git/`）
- **Then** 所有匹配项均为公开信息（如 `noreply@anthropic.com` 为公开的 Co-Authored-By 提交者）或开源社区公开邮箱；任何个人私密邮箱/手机号标记为 🔴 需修复
- **验证方式**: `grep -rInE '<email_pattern>' . | grep -v '.git/'` 仅含已知公开邮箱

### AC-4 · 命令注入与路径遍历漏洞扫描

- **Given** 仓库中所有 `.sh` 脚本文件
- **When** 运行不安全模式扫描（`grep -rInE '(eval\s|exec\s|system\s|subprocess|popen|\$\{[^}]+\$\{|`[^`]+\$)' --include='*.sh' .`）并手动审查每个匹配项；路径遍历检查（`grep -rInE '(\.\.\/|\.\.\\)' --include='*.sh' .` 检查是否拼接用户输入）
- **Then** `eval`/`exec` 等使用均有明确注释说明为何安全；无用户输入拼接到路径遍历的代码路径
- **验证方式**: 逐条审查每个匹配项的上下文，确认无注入风险

### AC-5 · Git 历史敏感信息扫描

- **Given** 完整的 Git 提交历史
- **When** 运行 `git log -p --all --full-history` 配合凭证/路径/个人信息正则扫描
- **Then** 历史提交中无敏感信息残留；如发现，执行 `git filter-branch` 或 `BFG Repo-Cleaner` 清理后重新验证
- **验证方式**: `git log -p --all | grep -iE '<credential_pattern>' | wc -l` 输出为 0

### AC-6 · 第三方端点暴露扫描

- **Given** 仓库根目录下全部文件
- **When** 扫描 URL 模式（`grep -rInE 'https?://[a-zA-Z0-9.-]+' --include='*.sh' --include='*.json' --include='*.md' .`），排除 `.git/`、`flow-kit-bundle/`）
- **Then** 所有匹配 URL 均为公开可访问地址（github.com、unpkg.com、npmjs.com 等）；无内部 staging/dev API 端点
- **验证方式**: 所有 URL 经 `curl -sI <url>` 验证为公开可达或为文档引用

---

## 范围切分

### v1（本次必做）

- AC-1 ~ AC-6 全部六项扫描
- 生成 `SECURITY-REPORT.md` 汇总所有发现
- 任何 🔴 Critical 发现 → 修复 → 重新扫描验证
- 更新 CONTEXT.md 术语表（安全审查相关术语）
- `.specs/security-privacy-audit/` 目录下全部产物

### v2（下一轮考虑，不本次）

- 自动化 CI/CD 安全扫描集成（pre-push hook / GitHub Action）
- 引入专业 SAST 工具（如 Semgrep、TruffleHog、Gitleaks）
- 代码签名与 SBOM 生成
- `flow-kit-bundle/` 下 vendor 副本的独立安全审查

### out（永远不做）

- 渗透测试 / 红队演练（本项目为 Bash 脚本分发仓库，无运行时服务）
- 第三方依赖漏洞扫描（本项目无外部运行时依赖）
- SOC2/ISO27001 合规认证（不适用于个人开源项目）

---

## 非功能性需求

- **性能**: 无（扫描为一次性离线操作，无性能约束）
- **可访问性**: 无（非前端项目）
- **安全**: 本次审查本身即为安全需求——审查过程不得引入新的敏感信息（审查报告中的路径需脱敏处理）
- **兼容性**: 扫描脚本需在 `bash 5.x` + `grep (GNU)` + `git 2.x` 环境运行
- **可观测性**: 审查结果输出到 `SECURITY-REPORT.md`，包含时间戳、扫描范围、每维度结果、误报标记

## 依赖与假设

- **依赖**: `grep`（GNU grep，支持 `-rInE`）、`git`（2.x，用于历史扫描）、`jq`（JSON 文件解析）
- **假设**: `flow-kit-bundle/` 目录为上游 vendor 副本，其内容不在本次审查范围（v2 独立处理）；`.git/` 内部对象文件不直接搜索（通过 `git log -p` 间接扫描）
- **假设**: 仓库中不含二进制文件需审查（`.tar.gz` 已在 `.gitignore` 排除）

---

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
