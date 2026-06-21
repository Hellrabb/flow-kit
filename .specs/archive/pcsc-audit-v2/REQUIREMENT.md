# REQUIREMENT: PCSC/PG 双层防护全面审计

- **Change ID**: pcsc-audit-v2
- **关联**: `@.specs/pcsc-audit-v2/CHANGE.md`

---

## 用户故事

- **US-1**：作为 flow-kit 维护者，我想全面审计 PCSC/PG 双层防护的完整性，以便发现并修补所有遗漏的漏洞。

## 验收准则（AC）

### AC-1 · 四维度审计完成

- **Given** 已安装的 flow-kit（含 PCSC + PCG 改动）
- **When** 审计执行完成
- **Then** 审计报告覆盖 A/B/C/D 四个维度，每个维度至少 0 条发现
- **验证方式**: REVIEW.md 含四维度章节

### AC-2 · 发现分级

- **Given** 审计报告
- **When** 检查每个发现
- **Then** 每条发现标注严重度（🔴 Critical / 🟡 Major / 🟢 Minor）+ 具体文件位置 + 修复建议
- **验证方式**: 人工 review

### AC-3 · 非修复模式

- **Given** 审计发现 > 0 条
- **When** CHANGE 完成
- **Then** 不直接修改 prompt/GO.md——仅产出报告，等用户确认后另开 change 修复
- **验证方式**: `git diff` 无 prompt/GO.md 改动（除报告文件外）

---

## 范围切分

### v1（本次必做）
- A/B/C/D 四维度审计
- 逐文件深读 7 prompt + GO.md + test
- 检查 install 脚本
- 产出 REVIEW.md

### v2（下一轮考虑）
- 按审计报告逐项修复
- 补充测试覆盖
- 重新打包归档

### out（永远不做）
- 外部第三方审计工具集成
- CI 自动化审计流水线

## 非功能性需求

- **性能**: 无
- **安全**: 无
- **兼容性**: 审计不改变任何运行时行为
- **可观测性**: 审计报告为 markdown，人类可读
