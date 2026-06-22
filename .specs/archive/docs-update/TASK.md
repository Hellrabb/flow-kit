# TASK: 更新说明文档以同步近期修改

- **Change ID**: docs-update
- **关联**: `@.specs/docs-update/REQUIREMENT.md`、`@.specs/docs-update/DESIGN.md`

---

## 波次划分

```
Wave 1 (parallel): T01[P], T02[P]         ← 调研（只读，无冲突）
Wave 2 (sequential): T03 → T04 → T05 → T06 → T07  ← 写文档（同文件，顺序执行）
Wave 3: T08                                  ← 最终验证 + README
```

## 任务

### Wave 1 — 调研

<task id="T01" parallel="true">
  <name>扫描近期归档 CHANGE，提取需文档化的功能清单</name>
  <read_files>
    .specs/archive/pipeline-goal/DESIGN.md
    .specs/archive/goal-pipeline-phase0/DESIGN.md
    .specs/archive/pcsc-audit-v2/DESIGN.md
    .specs/archive/phase-skip-fix/DESIGN.md
    .specs/archive/pipeline-rollback-phase0/DESIGN.md
    .specs/archive/fix-pipeline-rollback/DESIGN.md
    .specs/archive/fix-audit-findings/DESIGN.md
    .specs/archive/goal-auto-extract/DESIGN.md
    .specs/archive/integrate-goal-command/DESIGN.md
    .specs/CONTEXT.md
  </read_files>
  <write_files>
  </write_files>
  <action>
    扫描 9 个近期归档 CHANGE 的 DESIGN.md（重点读 § 9 架构沉淀 + § 1 决策清单），
    对照 CONTEXT.md 术语表，生成一份"需文档化功能清单"：
    - 功能名称（如 pipeline goal --from 0）
    - 关键概念（如 toll-gate / PCSC / PCG / auto_advance / rollback）
    - 来源 change（哪个归档 CHANGE 引入的）
    - 优先级（必写 / 建议写）
    输出为临时笔记（不写入正式产物），供 T03-T07 使用。
  </action>
  <verify>清单至少覆盖 5 个功能 + 关联到对应归档 CHANGE</verify>
  <done>清单内容被 T03-T07 各任务引用</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true">
  <name>分析既有用户指南结构，确定插入点和过时内容</name>
  <read_files>
    FLOW-KIT-用户指南.md
    README.md
  </read_files>
  <write_files>
  </write_files>
  <action>
    通读 FLOW-KIT-用户指南.md（977 行），产出：
    1. 章节结构图（现有标题层级）
    2. 4 个新专节的插入位置建议（pipeline goal / PCSC-PG / rollback / goal auto-extract）
    3. 过时内容清单（被新机制替代的旧描述，标注行号范围）
    4. README.md 是否需要更新的判断
  </action>
  <verify>插入位置建议至少覆盖 4 个新功能；过时内容清单至少 1 项</verify>
  <done>结构分析被 T03-T08 引用</done>
  <depends_on></depends_on>
</task>

### Wave 2 — 写文档（同文件 FLOW-KIT-用户指南.md，顺序执行避免冲突）

<task id="T03">
  <name>新增 pipeline goal 全链路专节</name>
  <read_files>
    FLOW-KIT-用户指南.md
    .specs/CONTEXT.md
    .specs/docs-update/REQUIREMENT.md
  </read_files>
  <write_files>
    FLOW-KIT-用户指南.md
  </write_files>
  <action>
    在 FLOW-KIT-用户指南.md 中新增 pipeline goal 专节，覆盖：
    - `/flow goal --pipeline --from <n>` 命令语法
    - 全链路执行链：0→1→2→3→4→5→6→7（从任意阶段起步）
    - toll-gate 阶段过渡暂停模型（暂停点 + 用户确认）
    - auto_advance 自动推进模式
    - gate_config 自定义门禁配置
    - 子目标（phase_sub_goals）语法
    术语以 CONTEXT.md 为准。插入位置参考 T02 分析结果。
    新增节预计 ≤ 80 行。
  </action>
  <verify>grep -c "pipeline" FLOW-KIT-用户指南.md 返回 ≥ 5；grep -c "toll-gate" FLOW-KIT-用户指南.md 返回 ≥ 3</verify>
  <done>AC-1 通过 — pipeline goal 完整用法已被文档化</done>
  <depends_on>T01, T02</depends_on>
</task>

<task id="T04">
  <name>新增 PCSC/PG 双层防护专节</name>
  <read_files>
    FLOW-KIT-用户指南.md
    .specs/CONTEXT.md
  </read_files>
  <write_files>
    FLOW-KIT-用户指南.md
  </write_files>
  <action>
    在 FLOW-KIT-用户指南.md 中新增 PCSC/PG 双层防护专节，覆盖：
    - PCSC（Phase Completion Self-Check）：各阶段 prompt 内置的产物自检段
    - PCG（Phase Completion Gate）：GO.md 路由层的独立产物检查门禁
    - 双层防护工作原理（PCSC 先自检 → toll-gate → PCG 再检查）
    - artifact verification 机制（`test -f` 产物存在性验证）
    - 阶段跳过漏洞修复说明
    术语以 CONTEXT.md 为准。新增节预计 ≤ 60 行。
  </action>
  <verify>grep -c "PCSC\|PCG\|双层防护\|Phase Completion" FLOW-KIT-用户指南.md 返回 ≥ 5</verify>
  <done>AC-2 通过 — PCSC/PG 双层防护已被文档化</done>
  <depends_on>T01, T03</depends_on>
</task>

<task id="T05">
  <name>新增 pipeline rollback 智能回退专节</name>
  <read_files>
    FLOW-KIT-用户指南.md
    .specs/CONTEXT.md
  </read_files>
  <write_files>
    FLOW-KIT-用户指南.md
  </write_files>
  <action>
    在 FLOW-KIT-用户指南.md 中新增 pipeline rollback 专节，覆盖：
    - 失败分类表（按阶段/严重度分类）
    - 动态下界机制（根据失败类型决定回退到哪个阶段）
    - jq 通用化回退方案
    新增节预计 ≤ 50 行。
  </action>
  <verify>grep -c "rollback\|回退" FLOW-KIT-用户指南.md 返回 ≥ 3</verify>
  <done>AC-3 通过 — pipeline rollback 已被文档化</done>
  <depends_on>T01, T04</depends_on>
</task>

<task id="T06">
  <name>新增 goal 自动提取专节</name>
  <read_files>
    FLOW-KIT-用户指南.md
    .specs/CONTEXT.md
  </read_files>
  <write_files>
    FLOW-KIT-用户指南.md
  </write_files>
  <action>
    在 FLOW-KIT-用户指南.md 中新增 goal 自动提取专节，覆盖：
    - goal 自动提取机制（从 REQUIREMENT.md AC 自动生成）
    - native 模式（CC ≥ v2.1.139 原生 /goal）vs fallback 模式（内置 prompt 驱动）
    - goal 生命周期（设定 → 迭代 → 满足 → 清除）
    新增节预计 ≤ 50 行。
  </action>
  <verify>grep -c "goal.*自动\|自动.*提取\|auto.*extract" FLOW-KIT-用户指南.md 返回 ≥ 3</verify>
  <done>AC-4 通过 — goal 自动提取已被文档化</done>
  <depends_on>T01, T05</depends_on>
</task>

<task id="T07">
  <name>修正过时内容 + 术语一致性对齐</name>
  <read_files>
    FLOW-KIT-用户指南.md
    .specs/CONTEXT.md
  </read_files>
  <write_files>
    FLOW-KIT-用户指南.md
  </write_files>
  <action>
    修正 FLOW-KIT-用户指南.md 中的过时内容：
    1. 逐条检查 T02 标记的过时内容，确认是否仍生效
    2. 将已被新机制替代的旧描述替换为准确的当前行为描述
    3. 全文术语一致性检查：确保使用的术语与 CONTEXT.md 定义一致
       （抽查 5 个核心术语：toll-gate / PCSC / PCG / pipeline goal / auto_advance）
    4. 确保没有将已废弃行为描述为当前行为
  </action>
  <verify>人工通读确认：(a) T02 过时清单中的所有项已处理 (b) 5 个核心术语抽查通过</verify>
  <done>AC-5 + AC-6 通过 — 术语一致，无过时内容</done>
  <depends_on>T02, T06</depends_on>
</task>

### Wave 3 — 最终验证

<task id="T08">
  <name>README 更新 + 全量 AC 验证</name>
  <read_files>
    FLOW-KIT-用户指南.md
    README.md
    .specs/docs-update/REQUIREMENT.md
  </read_files>
  <write_files>
    README.md
  </write_files>
  <action>
    1. 检查 README.md 是否需要更新（参考 T02 判断）
       - 如需要：更新概要描述，确保与用户指南一致
    2. 运行全量 AC 验证（所有 grep 命令）：
       - AC-1: grep -c "pipeline" FLOW-KIT-用户指南.md
       - AC-2: grep -c "PCSC\|PCG\|双层防护\|Phase Completion" FLOW-KIT-用户指南.md
       - AC-3: grep -c "rollback\|回退" FLOW-KIT-用户指南.md
       - AC-4: grep -c "goal.*自动\|auto.*extract" FLOW-KIT-用户指南.md
    3. 统计新增行数，确保文档未过度膨胀（目标 ≤ 1200 行）
  </action>
  <verify>所有 AC-1~AC-4 grep 验证通过；文档总行数 ≤ 1300</verify>
  <done>全部 6 条 AC 通过，文档更新完成</done>
  <depends_on>T07</depends_on>
</task>
