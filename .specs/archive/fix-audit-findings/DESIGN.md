# DESIGN: 修复审计发现

- **Change ID**: fix-audit-findings
- **技术栈**: 沿用 Bash + jq + bats

## 修改清单

| # | 文件 | 改动 |
|---|---|---|
| A1 | 0-change.md | 插入 PCSC 段 |
| A2 | 1/2/3 prompt | toll-gate 加 auto_advance 分支 |
| B1 | 7-int | PCSC 加 Sub-goal |
| C1 | GO.md | Phase 4 验证命令加 SUMMARY |
| A3 | 4-dev | 选项4 说明更新 |
| B2 | 7-int | PCSC 加"出 PR" |
| B3 | 4-dev | PCSC 细化 self-review |
| D1 | install_core.sh | sanity check |
| D2 | install.sh | --self-test flag |

## 风险
- R1: 改动分散（8 文件）→ 按文件分组并行修改
