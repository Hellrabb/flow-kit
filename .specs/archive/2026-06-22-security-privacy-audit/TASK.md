# TASK: 安全与隐私泄露全面审查 — 任务拆分

- **Change ID**: security-privacy-audit
- **关联**: `@.specs/security-privacy-audit/REQUIREMENT.md`、`@.specs/security-privacy-audit/DESIGN.md`
- **预计总耗时**: ~15-25 分钟（6 个并行扫描任务 + 1 个汇总任务）

---

## 波次划分

```
Wave 1 (parallel, 6 tasks): T01[P], T02[P], T03[P], T04[P], T05[P], T06[P]
  → 全部只读扫描，互不冲突，可完全并行

Wave 2 (1 task):            T07（depends on T01-T06）
  → 汇总所有扫描结果，生成 SECURITY-REPORT.md
```

---

## 任务清单

<task id="T01" parallel="true">
  <name>🔑 硬编码凭证扫描</name>
  <read_files>
    **/*.sh
    **/*.json
    **/*.yml
    **/*.yaml
    **/*.conf
    **/*.env
    **/*.md
    flow-kit-bundle/**/*.sh
    flow-kit-bundle/**/*.json
  </read_files>
  <write_files>
  </write_files>
  <action>
    对仓库全部文本文件运行硬编码凭证正则扫描（排除 .git/、node_modules/）。
    扫描模式：
    - api_key / apikey / secret / token / password / passwd / credential
    - private_key / access_key / auth_token
    - -----BEGIN.*PRIVATE KEY----- （PEM 格式密钥）
    - 赋值模式：key=value / key: value / 'key' => 'value'
    逐条审查命中项，区分：
    - 真实凭证（如 'my-secret-token-123' 字符串）→ 🔴 CRITICAL
    - 注释/示例/占位符（如 '# password here' / 'your-token-here'）→ ✅ FALSE_POSITIVE
    - 文档中的关键词提及（如 '使用 token 认证'）→ ✅ FALSE_POSITIVE
    结果以表格输出：文件路径 | 行号 | 匹配内容（脱敏）| 判定 | 理由
  </action>
  <verify>grep -rInE '(api[_]?key|apikey|secret|token|password|passwd|credential|private[_]?key|access[_]?key|auth[_]?token|BEGIN.*PRIVATE KEY)' --include='*.sh' --include='*.json' --include='*.yml' --include='*.yaml' --include='*.conf' --include='*.md' . | grep -v '.git/' | grep -v 'node_modules/' > /tmp/t01-hits.txt; echo "Hits: $(wc -l < /tmp/t01-hits.txt)"; echo "After excluding known-safe: $(grep -vcE '(Co-Authored-By|noreply@|README|CHANGELOG|CONTEXT|术语|定义)' /tmp/t01-hits.txt || echo 0)"</verify>
  <done>扫描完成，所有命中项已逐条标记为 ✅ FALSE_POSITIVE / 🟡 WARNING / 🔴 CRITICAL，输出命中表格</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true">
  <name>🏠 内部路径与个人目录泄露扫描</name>
  <read_files>
    **/*.sh
    **/*.json
    **/*.md
    **/*.yml
    **/*.yaml
    **/*.conf
  </read_files>
  <write_files>
  </write_files>
  <action>
    扫描全部文件中的路径引用（排除 .git/、flow-kit-bundle/ 深层）。
    扫描模式：
    - /home/ + 用户名（如 /home/hellrabbit、/home/ubuntu）
    - /Users/ + 用户名
    - /root/
    - /tmp/ + 随机字符串（非标准临时目录）
    - 127.0.0.1 / 192.168.x.x / 10.x.x.x / 172.16-31.x.x
    - 内部域名（.local / .internal / .lan）
    逐条审查：
    - 项目路径（如 /home/hellrabbit/unisoc/flow-kit/）→ 🟡 WARNING（公开后暴露用户目录结构）
    - 非项目路径 → 🔴 CRITICAL
    - 文档中作为示例的路径 → ✅ FALSE_POSITIVE
  </action>
  <verify>grep -rInE '(/home/|/Users/|/root/|hellrabbit|127\.0\.0\.1|192\.168\.|10\.[0-9]+\.[0-9]+\.|172\.(1[6-9]|2[0-9]|3[01])\.|\.local\b|\.internal\b|\.lan\b)' --include='*.sh' --include='*.json' --include='*.md' --include='*.yml' --include='*.yaml' . | grep -v '.git/' | grep -v 'flow-kit-bundle/' > /tmp/t02-hits.txt; echo "Hits: $(wc -l < /tmp/t02-hits.txt)"</verify>
  <done>扫描完成，所有命中路径已区分项目路径 vs 非项目路径，标注风险等级</done>
  <depends_on></depends_on>
</task>

<task id="T03" parallel="true">
  <name>📧 个人信息泄露扫描</name>
  <read_files>
    **/*.sh
    **/*.json
    **/*.md
    **/*.yml
  </read_files>
  <write_files>
  </write_files>
  <action>
    扫描全部文件中的个人信息（排除 .git/）。
    扫描模式：
    - 邮箱：grep -rInE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'
    - 手机号：grep -rInE '1[3-9][0-9]{9}'（中国大陆）
    - 身份证号：grep -rInE '[1-9][0-9]{5}(19|20)[0-9]{2}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])[0-9]{3}[0-9Xx]'
    逐条审查：
    - 公开邮箱（如 noreply@anthropic.com、开源社区公开邮箱）→ ✅ FALSE_POSITIVE
    - 私人邮箱 → 🔴 CRITICAL
    - 手机号/身份证号 → 🔴 CRITICAL
  </action>
  <verify>grep -rInE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' --include='*.sh' --include='*.json' --include='*.md' . | grep -v '.git/' > /tmp/t03-hits.txt; echo "Email hits: $(wc -l < /tmp/t03-hits.txt)"</verify>
  <done>扫描完成，所有个人信息命中项已逐条标记，私人信息标注为 CRITICAL</done>
  <depends_on></depends_on>
</task>

<task id="T04" parallel="true">
  <name>🐚 命令注入与路径遍历漏洞扫描</name>
  <read_files>
    **/*.sh
  </read_files>
  <write_files>
  </write_files>
  <action>
    扫描所有 Shell 脚本中的不安全模式（排除 flow-kit-bundle/ 深层 vendor）。
    注入检测：
    - eval / exec 使用（grep -rInE '\b(eval|exec)\s'）
    - 命令替换中的变量（grep -rInE '`[^`]*\$[^`]*`'）
    - 未加引号的变量展开（grep -rInE '\$\{[^}]+\}'）— 人工判断是否可被注入
    路径遍历：
    - ../ 拼接用户输入（检查是否有变量拼接到 ../ 路径中）
    - 动态命令构造（如 cmd="rm -rf $user_input"）
    逐条审查每个匹配项的上下文（读前后 5 行），判断：
    - 安全（固定值/内部变量/已验证输入）→ ✅ SAFE
    - 潜在风险 → 🟡 WARNING
    - 明确可注入 → 🔴 CRITICAL
  </action>
  <verify>grep -rInE '\b(eval|exec)\s' --include='*.sh' . | grep -v '.git/' | grep -v 'flow-kit-bundle/' > /tmp/t04-hits.txt; echo "eval/exec hits: $(wc -l < /tmp/t04-hits.txt)"</verify>
  <done>所有 eval/exec/动态命令均已审查上下文，标注安全判定，零可注入漏洞</done>
  <depends_on></depends_on>
</task>

<task id="T05" parallel="true">
  <name>🌐 第三方端点暴露扫描</name>
  <read_files>
    **/*.sh
    **/*.json
    **/*.md
    **/*.yml
  </read_files>
  <write_files>
  </write_files>
  <action>
    扫描全部文件中的 URL（排除 .git/、flow-kit-bundle/ 深层）。
    提取所有 http/https URL，去重后逐条验证：
    - 公开可达（github.com、npmjs.com、unpkg.com、raw.githubusercontent.com）→ ✅ PUBLIC
    - 内部地址（localhost、127.0.0.1、内网 IP、staging/dev 域名）→ 🔴 CRITICAL
    - 需要认证的 URL → 🟡 WARNING
    - 文档引用（如 README 中的链接）→ ✅ DOC_REFERENCE
    对可疑 URL 运行 curl -sI 验证可达性。
  </action>
  <verify>grep -rInoE 'https?://[a-zA-Z0-9._/~%?=&@:;#+-]+' --include='*.sh' --include='*.json' --include='*.md' . | grep -v '.git/' | grep -v 'flow-kit-bundle/' | sort -u > /tmp/t05-hits.txt; echo "Unique URLs: $(wc -l < /tmp/t05-hits.txt)"</verify>
  <done>所有 URL 已分类标注（PUBLIC / DOC_REFERENCE / WARNING / CRITICAL），无内部端点泄露</done>
  <depends_on></depends_on>
</task>

<task id="T06" parallel="true">
  <name>📜 Git 历史敏感信息扫描</name>
  <read_files>
    .git/** (via git log -p)
  </read_files>
  <write_files>
  </write_files>
  <action>
    使用 git log -p --all --full-history 扫描全部提交历史中的敏感模式。
    扫描关键词：
    - password / passwd / secret / token / api_key / credential
    - BEGIN.*PRIVATE KEY
    - @anthropic.com / @gmail.com / @qq.com 等邮箱域名（检查是否有非公开邮箱）
    - /home/hellrabbit / /Users/
    逐条审查历史命中：
    - 已在当前 HEAD 中删除的敏感信息 → 🔴 CRITICAL（需 git filter-branch 清理）
    - 仍在 HEAD 中但已标记 FALSE_POSITIVE（如 Co-Authored-By）→ ✅ 继承 T01-T03 判定
    - 开放源码中正常的 Co-Authored-By 行 → ✅ FALSE_POSITIVE
  </action>
  <verify>git log -p --all --full-history | grep -iEc '(password|passwd|secret|token|api[_]?key|credential|BEGIN.*PRIVATE|@anthropic\.com|@gmail\.com)' > /tmp/t06-hits.txt; echo "History hits: $(cat /tmp/t06-hits.txt)"</verify>
  <done>Git 历史扫描完成，所有历史命中项已审查，无残留敏感信息（或已标记 CRITICAL 待清理）</done>
  <depends_on></depends_on>
</task>

<task id="T07" parallel="false">
  <name>📋 汇总生成 SECURITY-REPORT.md</name>
  <read_files>
    /tmp/t01-hits.txt
    /tmp/t02-hits.txt
    /tmp/t03-hits.txt
    /tmp/t04-hits.txt
    /tmp/t05-hits.txt
    /tmp/t06-hits.txt
  </read_files>
  <write_files>
    .specs/security-privacy-audit/SECURITY-REPORT.md
  </write_files>
  <action>
    汇总 T01-T06 的扫描结果，生成格式化的 SECURITY-REPORT.md：
    1. 报告头：审查时间、扫描范围、审查人（AI + 人工确认）
    2. 六大维度每个维度一节：
       - 扫描命令
       - 命中数量
       - 发现项表格（文件 | 行号 | 内容脱敏 | 风险等级 | 判定理由）
       - 维度结论：✅ CLEAN / 🟡 WARNINGS ONLY / 🔴 CRITICAL FOUND
    3. 总结：总命中数、CRITICAL 数、WARNING 数、FALSE_POSITIVE 数
    4. 最终判定：
       - 零 CRITICAL → ✅ 可以安全 push
       - 有 CRITICAL → 🔴 必须先修复再 push，附修复建议清单
  </action>
  <verify>test -f .specs/security-privacy-audit/SECURITY-REPORT.md && echo "REPORT_EXISTS" && grep -c '🔴 CRITICAL' .specs/security-privacy-audit/SECURITY-REPORT.md</verify>
  <done>SECURITY-REPORT.md 生成完毕，包含六维度完整结果 + 最终 push 判定</done>
  <depends_on>T01, T02, T03, T04, T05, T06</depends_on>
</task>
