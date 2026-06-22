# TASK: 补齐 PCSC 表两个缺失检查项

- **Change ID**: fix-pcsc-gaps
- **关联**: `@.specs/fix-pcsc-gaps/CHANGE.md`

---

## 波次划分

```
Wave 1 (parallel): T01[P], T02[P]
```

> 两个任务触及不同文件，无依赖，可并行。

---

## 任务清单

```xml
<task id="T01" parallel="true" status="done">
  <name>Gap1: 7-integration PCSC 新增 T-FIX 关闭检查行</name>
  <read_files>
    flow-kit-bundle/flow-kit/prompts/7-integration.md
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/prompts/7-integration.md
  </write_files>
  <action>
    在 7-integration PCSC 表（当前第 43-54 行）中新增一行检查项：
    "TASK.md 中所有 T-FIX-XX 任务状态 = done | grep -c 'T-FIX.*status=\"done\"' TASK.md 与 grep -c 'T-FIX.*status=\"pending\"' 一致（均为 0 pending） | ✅ / ❌"
    插入位置：在现有行 6（"全部上游阶段产物均存在"）和行 7（"归档已完成"）之间，编号为新的 row 7，原 7→8, 7a→8a, 8→9, 9→10。
    同步修改运行时副本 ~/.claude/flow-kit/prompts/7-integration.md。
  </action>
  <verify>grep -c 'T-FIX.*status' flow-kit-bundle/flow-kit/prompts/7-integration.md && grep -c 'T-FIX.*status' ~/.claude/flow-kit/prompts/7-integration.md</verify>
  <done>7-integration PCSC 表含 T-FIX 关闭检查行，两端文件一致</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true" status="done">
  <name>Gap2: 6-review PCSC 新增 CONTEXT 技术债写入检查行</name>
  <read_files>
    flow-kit-bundle/flow-kit/prompts/6-review.md
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/prompts/6-review.md
  </write_files>
  <action>
    在 6-review PCSC 表（当前第 99-107 行）中新增一行检查项：
    "技术债已同步到 CONTEXT.md（若 4.1 触发且有 🟡 Scheduled 产出） | 人工确认（检查 4.1 是否触发，若触发则 grep CONTEXT.md 技术债段确认新条目已追加） | ✅ / ❌ / N/A"
    插入位置：在现有行 6（"Gate 失败项已记录"）和行 7（"TEST.md 5 轮金字塔完整性已验证"）之间，编号为新的 row 7，原 7→8。
    同步修改运行时副本 ~/.claude/flow-kit/prompts/6-review.md。
  </action>
  <verify>grep -c '技术债已同步到 CONTEXT' flow-kit-bundle/flow-kit/prompts/6-review.md && grep -c '技术债已同步到 CONTEXT' ~/.claude/flow-kit/prompts/6-review.md</verify>
  <done>6-review PCSC 表含 CONTEXT 技术债写入检查行，两端文件一致</done>
  <depends_on></depends_on>
</task>
```

---

## Fix 任务（来自 REVIEW / INTEGRATION）

> 此区域由 review/integration 阶段自动追加，编号 `T-FIX-XX`。

```xml
<!-- 占位 -->
```
