# TASK: l3-review.sh 加固

- **Change ID**: l3-review-hardening
- **关联**: `@.specs/l3-review-hardening/REQUIREMENT.md`

---

## 波次划分

```
Wave 1 (parallel): T01[P], T02[P]
Wave 2:            T03 (depends on T01, T02)
```

---

## 任务清单

```xml
<task id="T01" parallel="true" status="pending">
  <name>l3-review.sh 全部 6 项修复</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    flow-kit-bundle/hooks/stop/lib/common.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
  </write_files>
  <action>
    在 l3-review.sh 中实施 6 项修复：

    F1 (phase 6 git diff 含新文件):
    - artifact 收集段：git diff HEAD 后追加 git ls-files --others --exclude-standard
    - 仅追加 .sh/.bats 文件内容（各 ≤5000 chars）

    F2 (phase 7 全产物):
    - artifact 收集段：替换为目录清单 + for 循环读取 CHANGE/REQUIREMENT/DESIGN/TASK/TEST/REVIEW/INTEGRATION 各 ≤3000 chars

    F3 (L3 幂等):
    - 写入前 awk '/^## L3 盲审/{stop=1} !stop{print}' 剥离已有 L3 段

    B1 (双 block 提取):
    - content extraction: jq '[.content[]|select(.type=="text")|.text][0] // .content[0].thinking // ...'

    B2 (max_tokens): 2000 → 8000
    B3 (timeout): --max-time 25 → 90

    B4 (3层 verdict):
    - Layer1: sed code block → jq .verdict
    - Layer2: jq .verdict on raw content
    - Layer3: grep -oP '"verdict"\s*:\s*"\K(pass|fail)"'
    - 均失败 → "unknown"
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/lib/l3-review.sh && grep -c 'max_tokens:8000' flow-kit-bundle/hooks/stop/lib/l3-review.sh && grep -c 'max-time 90' flow-kit-bundle/hooks/stop/lib/l3-review.sh</verify>
  <done>6 项修复全部在 l3-review.sh 中生效，语法通过，参数验证通过</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true" status="pending">
  <name>创建 test_l3_review.bats — 覆盖 AC-1~AC-6</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    test/test_correction_file.bats
  </read_files>
  <write_files>
    test/test_l3_review.bats
  </write_files>
  <action>
    编写 bats 测试覆盖 6 条 AC：

    AC-1: 临时 git repo + untracked .sh → 验证 artifact 含新文件内容
    AC-2: 构造完整产物目录 → 验证 artifact 含全部 7 个文件名
    AC-3: 先写旧 L3 段 → 跑 L3 → 确认只剩 1 个 L3 段
    AC-4: 构造双 block JSON 响应 → 验证提取到 text block
    AC-5: grep 验证 max_tokens=8000 + --max-time=90
    AC-6: 3 种 verdict 格式各一条 case（code block / raw JSON / mixed text）

    使用 setup() 创建临时环境，teardown() 清理。
  </action>
  <verify>npx bats test/test_l3_review.bats --print-output-on-failure</verify>
  <done>≥6 test cases 通过，覆盖 AC-1~AC-6</done>
  <depends_on></depends_on>
</task>

<task id="T03" status="pending">
  <name>同步 runtime + L3 端到端验证</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    .specs/flow-active-integrity/INDEPENDENT-REVIEW-*.md
  </read_files>
  <write_files>
    ~/.claude/hooks/stop/lib/l3-review.sh
    .specs/flow-active-integrity/INDEPENDENT-REVIEW-*.md
  </write_files>
  <action>
    1. cp l3-review.sh → ~/.claude/hooks/stop/lib/ (sync runtime)
    2. 清理 flow-active-integrity 的重复 L3 段（awk 剥离后只保留最新）
    3. 删除旧 .done 文件
    4. 对 flow-active-integrity 全 6 阶段重跑 L3
    5. 验证全部 6 阶段 verdict 不再有误报
  </action>
  <verify>npx bats test/test_l3_review.bats && for f in .specs/flow-active-integrity/INDEPENDENT-REVIEW-*.md; do echo "$f: $(grep -c '## L3 盲审' $f) L3 sections"; done</verify>
  <done>runtime 已同步；flow-active-integrity 各 phase 只有 1 个 L3 段；verdict 无误报</done>
  <depends_on>T01, T02</depends_on>
</task>
```

---

## 阻塞日志

| 任务 | 阻塞原因 | 待人工决策项 | 时间 |
|---|---|---|---|
|  |  |  |  |
