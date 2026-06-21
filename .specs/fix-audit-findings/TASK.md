# TASK: 修复审计发现

## Wave 1 [P]

```xml
<task id="T01" parallel="true" status="pending">
  <name>A1: Add PCSC to 0-change.md</name>
  <write_files>flow-kit-bundle/flow-kit/prompts/0-change.md</write_files>
  <verify>grep -c "Phase Completion Self-Check" flow-kit-bundle/flow-kit/prompts/0-change.md | xargs -I{} test {} -eq 1</verify>
</task>
<task id="T02" parallel="true" status="pending">
  <name>A2: Add auto_advance branch to 1/2/3 toll-gates</name>
  <write_files>flow-kit-bundle/flow-kit/prompts/1-requirement.md, 2-design.md, 3-task.md</write_files>
  <verify>for f in 1-requirement 2-design 3-task; do grep -c "已在.*阶段完成自检.*处理" flow-kit-bundle/flow-kit/prompts/$f.md; done</verify>
</task>
<task id="T03" parallel="true" status="pending">
  <name>B1+B2: 7-int PCSC add Sub-goal + PR + B3: 4-dev self-review</name>
  <write_files>flow-kit-bundle/flow-kit/prompts/7-integration.md, flow-kit-bundle/flow-kit/prompts/4-dev.md</write_files>
  <verify>grep -c "Sub-goal 汇总" flow-kit-bundle/flow-kit/prompts/7-integration.md</verify>
</task>
<task id="T04" parallel="true" status="pending">
  <name>C1: Fix Phase 4 PCG + A3: 4-dev option4 text + D1+D2 install</name>
  <write_files>flow-kit-bundle/flow-kit/GO.md, flow-kit-bundle/flow-kit/prompts/4-dev.md, flow-kit-bundle/lib/install_core.sh, flow-kit-bundle/install.sh</write_files>
  <verify>grep "SUMMARY" flow-kit-bundle/flow-kit/GO.md | grep -c "test -s"</verify>
</task>
```

## Wave 2
T05: Sync + test + repackage + commit + archive
