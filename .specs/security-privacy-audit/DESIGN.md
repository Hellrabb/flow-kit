# DESIGN: 安全与隐私泄露全面审查 — 审计方法论

- **Change ID**: security-privacy-audit
- **关联**: `@.specs/security-privacy-audit/REQUIREMENT.md`、`@.specs/CONTEXT.md`
- **作者**: AI（Architect 角色）+ 人工 review

---

## 0. 技术栈选定

> 本次为安全审计，不涉及软件开发。工具栈为系统原生工具。

- **选定**: 原生工具链（grep + git + jq + bash）
- **扫描引擎**: GNU grep（`-rInE`，PCRE 正则）
- **历史扫描**: `git log -p --all --full-history`
- **JSON 解析**: `jq`（1.6+）
- **报告输出**: Markdown（`SECURITY-REPORT.md`）
- **关键依赖**: `bash 5.x`、`grep (GNU)`、`git 2.x`、`jq 1.6+`
- **理由**: 项目为 Bash 脚本分发仓库，无运行时依赖，无需引入外部安全工具。原生工具零安装成本，`grep` 正则 + `git` 历史扫描覆盖全部六大风险维度。
- **明确排除**: TruffleHog / Gitleaks / Semgrep（v1 不引入外部依赖，v2 考虑集成）

---

## 0.5 既有架构对齐

> 本次为安全审计，不涉及代码修改或新模块开发。本段适用性有限。

### 0.5.1 本次 change 触碰的既有模块

```
扫描范围（仓库全部文件）：
- *.sh（所有 Shell 脚本）
- *.json（配置文件）
- *.md（文档）
- .claude/（Claude Code 配置）
- hooks/（Stop/SessionStart hooks）
- lib/（安装模块）
- flow-kit-bundle/（vendor 副本 — 有限扫描，仅检查非上游引入的敏感信息）

新增产物（非代码）：
- .specs/security-privacy-audit/SECURITY-REPORT.md

禁动清单（与本次无关，禁止修改）：
- package-flow-kit.sh
- flow-kit-bundle.tar.gz
- flow-kit-bundle/（vendor 内容，只读扫描不改动）
```

### 0.5.2 既有抽象沿用对照表

不适用 — 本 change 不引入新代码或修改既有代码。

### 0.5.3 沿用模式 vs 引入新模式

不适用 — 本 change 为一次性审计操作。

---

## 1. 决策清单

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D1 | 使用原生 grep + git 做扫描 | TruffleHog / Gitleaks / Semgrep | 零安装成本，仓库无外部依赖；`grep` 正则足够覆盖 Bash 脚本项目的六大维度 | 误报率偏高（需人工逐条确认）；v2 考虑引入专业工具降低噪音 |
| D2 | 扫描范围排除 `flow-kit-bundle/` 的深层扫描（仅做浅层凭证检查） | 全量扫描 vendor | `flow-kit-bundle/` 来自上游，非本项目引入；全量扫描会产生大量噪音且修复权限不在本 change | 可能遗漏 vendor 副本中的上游敏感信息（v2 独立审计） |
| D3 | 逐文件报告格式（Markdown 表格） | JSON / YAML 机器可读格式 | Markdown 可直接在 GitHub 阅读，人工 review 友好；表格支持按维度/风险等级筛选 | 不支持程序化消费（如 CI 集成）；v2 可加 JSON 输出 |
| D4 | 三级风险分类（🔴 Critical / 🟡 Warning / ✅ Clean） | CVSS 评分 / OWASP 分类 | 审计目标是"能不能 push"，三级足够做 go/no-go 决策；CVSS 过度工程化 | 无法与其他安全工具互通；够用 |
| D5 | Git 历史全量扫描（`git log -p --all`） | 仅扫描 HEAD | 公开仓库暴露全部历史；已删除但未重写的敏感信息仍需发现 | 扫描时间较长（仓库历史约 100+ commits），但可接受 |
| D6 | 扫描结果人工逐条确认（不可自动标记 Clean） | 脚本自动判定 | 安全审查不可自动化——正则误报（注释中的"password"、示例 token）必须人工判断 | 耗时长但不可妥协 |

## 2. 审计工作流

```
仓库全部文件 (排除 .git/ + flow-kit-bundle/ 深层)
       │
       ├──> 🔑 凭证扫描 (grep -rInE '<cred_pattern>')
       │         │
       │         └──> 逐条人工确认 → 标记 FALSE_POSITIVE / FINDING
       │
       ├──> 🏠 路径泄露扫描 (grep -rInE '<path_pattern>')
       │         │
       │         └──> 区分项目路径 vs 个人路径 → 标记
       │
       ├──> 📧 个人信息扫描 (grep -rInE '<pii_pattern>')
       │         │
       │         └──> 区分公开邮箱 vs 私人邮箱 → 标记
       │
       ├──> 🐚 注入风险扫描 (grep -rInE '<injection_pattern>')
       │         │
       │         └──> 审查每个 eval/exec 上下文 → 标记
       │
       ├──> 🌐 端点扫描 (grep -rInE 'https?://...')
       │         │
       │         └──> 验证每个 URL 公开可达性 → 标记
       │
       └──> 📜 Git 历史扫描 (git log -p --all)
                 │
                 └──> 历史 diff 全文关键词命中 → 标记
                          │
                          v
                    SECURITY-REPORT.md (汇总全部发现)
                          │
                          v
                    🔴 有 Critical? → 修复 → 重新扫描
                    无 Critical? → ✅ 可以 push
```

## 3. 发现项状态机

```
   [扫描命中]
       │
       v
   🔍 DISCOVERED ──人工审查──> ✅ FALSE_POSITIVE（注释/示例/占位符）
       │
       v
   🔴 CRITICAL    ← 硬编码真实密钥/个人手机号/内部生产URL
   🟡 WARNING     ← 项目路径（非敏感）/ 公开邮箱 / 无害 eval
   ✅ CLEAN       ← 零命中
       │
       v
   [记录到 SECURITY-REPORT.md]
       │
       v
   🔴 Critical → 修复 → 重新扫描 → CLEAN
   🟡 Warning → 记录理由 → 可接受风险 → CLEAN
```

## 4. ADR 索引

本 change 无不可逆技术决策。所有决策（D1-D6）均为本次审计的一次性选择，不绑定后续 change。

## 5. 风险

| # | 风险 | 影响 | 概率 | 缓解 |
|---|---|---|---|---|
| R1 | `grep` 正则漏报（复杂混淆的凭证无法用正则匹配） | 遗漏真实密钥 | 低（Bash 脚本中密钥通常为明文赋值，正则可覆盖） | 人工逐文件阅读关键脚本（`package-flow-kit.sh`、`install.sh`、hooks）作为补充 |
| R2 | 误报过多导致审查疲劳 | 人工确认质量下降 | 中（`password` 等常见词在注释/文档中频繁出现） | 正则尽量精确（如 `password\s*=\s*['"]\S+['"]` 匹配赋值而非注释）；每批标记后休息 |
| R3 | Git 历史扫描遗漏已 force-push 覆盖的内容 | 无法发现已销毁的敏感信息 | 低（本地 reflog 可能残留，但远程 clone 后不可见） | 确认当前 `git reflog` 中无异常；公开仓库只暴露 `git log` 可见历史 |
| R4 | `flow-kit-bundle/` 排除导致遗漏上游敏感信息 | 公开后暴露上游密钥 | 低（上游 flow-kit 为内部工具，无真实密钥） | 至少对 `flow-kit-bundle/` 做浅层凭证扫描（`grep -rInE 'api_key|secret|token' flow-kit-bundle/`） |
| R5 | 审查完成后又有新提交引入敏感信息 | Push 时 HEAD 干净但历史不干净 | 低 | `git log -p` 扫描全部历史而非仅 HEAD；push 前最后确认一次 |

> 至少 3 条；含实现风险 / 上线风险 / 长期债务各一条。

## 6. 不在范围

- 不引入 SAST/DAST 工具链（v2 考虑）
- 不对 `flow-kit-bundle/` 做深度代码审查（上游责任，v2 独立审计）
- 不修改任何源代码（除非发现 🔴 Critical → 修复 → 本 change 记录修复 diff）
- 不建立 CI/CD pre-push hook（v2 考虑）
- 不审查 `flow-kit-bundle.tar.gz` 二进制内容
- 不做运行时渗透测试（无可运行服务）

---

## 9. 架构沉淀建议

本 change 无架构层面沉淀建议。安全审计为一次性操作，不引入新的可复用抽象、技术决策或跨模块契约。

审查报告 `.specs/security-privacy-audit/SECURITY-REPORT.md` 归档后可供后续安全审查参考（作为基线）。
