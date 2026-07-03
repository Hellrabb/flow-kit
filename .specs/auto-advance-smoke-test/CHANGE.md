# CHANGE: auto_advance 冒烟测试

- **Change ID**: auto-advance-smoke-test
- **创建日期**: 2026-07-03
- **路径建议**: 最短
- **状态**: draft

## Why
验证 auto_advance=true 时 pipeline 自动推进是否正常工作。

## What
最小 change，仅用于观察 auto_advance 行为。不改任何文件。

## 影响面
- [ ] 影响 REQUIREMENT.md
- [ ] 影响 DESIGN.md
- [ ] 仅修复 bug

## 范围排除
- 不改任何源文件
- 不产生实际代码变更

## 验收线
- auto_advance=true 时 PCSC 全✅后自动 transition（不输出 toll-gate 提示）
- PCSC ❌时 pipeline 暂停并输出缺失清单
