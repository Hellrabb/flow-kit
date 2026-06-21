# REQUIREMENT: 修复审计发现

- **Change ID**: fix-audit-findings

## AC

### AC-1 · 🔴 A1 修复
- **Given** 0-change.md 无 PCSC
- **When** 修复后
- **Then** 0-change.md 包含 PCSC 段，产物：CHANGE.md + 五段完整性

### AC-2 · 🟡 A2 修复  
- **Given** 1/2/3 toll-gate 无 auto_advance 分支
- **When** 修复后
- **Then** 三段 toll-gate 均包含与 5/6 一致的 auto_advance 检查

### AC-3 · 🟡 B1 修复
- **Given** 7-int PCSC 缺 Sub-goal 汇总
- **When** 修复后  
- **Then** 含第 8 项 "Sub-goal 汇总已完成"

### AC-4 · 🟡 C1 修复
- **Given** Phase 4 PCG 只检查 TASK.md
- **When** 修复后
- **Then** 验证命令含 SUMMARY 文件检查

### AC-5 · 其余 5 项🟢 Minor 修复 + 全量测试通过

## v1: 9 项修复 | v2: 3 项可接受 | out: 新防护机制
