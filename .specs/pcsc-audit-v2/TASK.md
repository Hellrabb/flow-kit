# TASK: PCSC/PG 双层防护全面审计

- **Change ID**: pcsc-audit-v2

---

## 波次划分

```
Wave 1: T01 (audit all files)
Wave 2: T02 (write REVIEW.md)
```

## 任务清单

```xml
<task id="T01" status="pending">
  <name>四维度深度审计 7 prompt + GO.md + install 脚本</name>
  <read_files>
    flow-kit-bundle/flow-kit/prompts/1-requirement.md
    flow-kit-bundle/flow-kit/prompts/2-design.md
    flow-kit-bundle/flow-kit/prompts/3-task.md
    flow-kit-bundle/flow-kit/prompts/4-dev.md
    flow-kit-bundle/flow-kit/prompts/5-test.md
    flow-kit-bundle/flow-kit/prompts/6-review.md
    flow-kit-bundle/flow-kit/prompts/7-integration.md
    flow-kit-bundle/flow-kit/GO.md
    test/test_phase_gate.bats
    flow-kit-bundle/lib/install_core.sh
    flow-kit-bundle/lib/install_hooks.sh
  </read_files>
  <write_files>
    （审计阶段不写文件——发现记录在内存中，由 T02 写入）
  </write_files>
  <action>
    A) prompt 逻辑漏洞：逐文件检查 PCSC 段与 toll-gate 的衔接、auto_advance 分支一致性、阻断规则措辞
    B) PCSC 覆盖完整性：对照每个 prompt 的原始步骤清单（自检/职责/约束），逐项核对 PCSC 表格
    C) GO.md PCG 盲区：检查 PCG 触发条件、回退路径交叉、change_id=null 的 guard
    D) install 脚本：grep prompt 文件路径引用，检查是否有遗漏的同步逻辑
  </action>
  <verify>审计发现已整理为结构化列表（按维度+严重度）</verify>
  <done>四维度审计完成，发现列表准备就绪</done>
  <depends_on></depends_on>
</task>

<task id="T02" status="pending">
  <name>撰写 REVIEW.md 审计报告</name>
  <read_files>
    （T01 的发现列表）
  </read_files>
  <write_files>
    .specs/pcsc-audit-v2/REVIEW.md
  </write_files>
  <action>
    将 T01 的发现整理为 REVIEW.md，结构：
    - 四维度章节（A/B/C/D）
    - 每条发现含：严重度 / 文件:行号 / 问题描述 / 修复建议
    - 末尾汇总表（按严重度排序）
  </action>
  <verify>test -f .specs/pcsc-audit-v2/REVIEW.md</verify>
  <done>AC-1, AC-2 满足</done>
  <depends_on>T01</depends_on>
</task>
```
