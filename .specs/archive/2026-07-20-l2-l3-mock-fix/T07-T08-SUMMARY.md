# T07-T08-SUMMARY — NFR 收尾（性能 + 兼容性实测填 DESIGN）

- **Tasks**: T07 (NFR-1 性能) + T08 (NFR-2 兼容性)
- **Change**: l2-l3-mock-fix
- **关联**: REQUIREMENT NFR-1/NFR-2 / DESIGN § NFR 实测结果 / R4
- **状态**: ✅ DESIGN NFR 段已填具体阈值（无文字占位符 · 回应 L3-minor）

## NFR-1 · 性能（T07 实测）

| 项 | 值 |
|---|---|
| 方法 | 固定 deny payload（phase 1 + gate_config[1-requirement]=both + 无 .done + stdin `git commit` → gate.sh exit 2 deny 路径，gate_active(1)=true），bash `time` ×3 取中位数 |
| 重构前（7fb59e8^ · declare -A + is_git_commit 正则） | **53 ms** |
| 重构后（7fb59e8 · pure fn fk_phase_gate_key + 结构判定 helper） | **53 ms** |
| 差 | **0%**（远 < 30% 阈值 · 回应 R4） |
| 结论 | 重构对 gate hook 性能无显著影响；pure fn case vs declare -A、结构判定 helper vs 正则，开销 μs 级，淹没在 ~53ms 总开销 |

## NFR-2 · 兼容性（T08 实测）

| 项 | 值 |
|---|---|
| 实测环境 | GNU bash 5.2.21（5.x 档，满足 4.4+） |
| 语法 | `bash -n` gate.sh + common.sh 通过 |
| pure fn 兼容性 | fk_phase_gate_key 用 `case`（bash 2+ 原生），**不依赖 `declare -A`**（需 bash 4+）；重构后 `declare -A PHASE_GATE_KEY_MAP` count=0（NFR-4 grep 守护）→ 兼容性**只增不减** |
| bash 4.4 档 | 当前环境仅 5.2，无法实跑 4.4；case 语法 bash 2+ 支持，4.4 兼容由「不依赖 declare -A」论证保证 |

## verify 结果

| 检查 | 结果 |
|---|---|
| T07: DESIGN 含「重构前/重构后」+ ms/% | ✅ PASS（53ms / 0%） |
| T08: bash -n gate.sh + common.sh + bash 4.4+ | ✅ 实质 PASS（bash 5.2 · BASH_VERSINFO 验证）；verify 命令本身 locale 误 FAIL（见遗留） |

## 改动清单

| 文件 | 改动 |
|---|---|
| .specs/l2-l3-mock-fix/DESIGN.md | 新增「NFR 实测结果」段（NFR-1 性能 53ms/0% + NFR-2 兼容 bash 5.2/case 不依赖 declare -A） |

## 遗留

1. **T08 verify 命令 locale 敏感**：`bash --version | grep 'version (4\.[4-9]|[5-9]\.)'` 在中文 locale 输出「版本 5.2.21」非「version」→ 误 FAIL。`LC_ALL=C` 下 PASS，`BASH_VERSINFO` 验证 5.2 ≥ 4.4 实质通过。建议 verify 改 locale-safe（`BASH_VERSINFO` 数组判定），非本 change 范围（属 TASK verify 命令设计）
2. **bash 4.4 档未实跑**：环境仅 5.2；4.4 兼容由「pure fn case 不依赖 declare -A」论证保证（case bash 2+ 支持，比 declare -A 的 4+ 要求更宽松）

## phase 4 总结

- **T01-T08 全 done**：5 gate bug（F/H/I/J/K）修复 + 全套 bats 536/0 真绿 + NFR 性能/兼容实测
- **commit**：7fb59e8（T01-T06 里程碑）+ 本次 NFR 收尾（T07/T08 DESIGN 段）待 commit
- **下一步**：5-test（测试阶段）/ 6-review（双轮审查）/ 直接 commit NFR 收尾
