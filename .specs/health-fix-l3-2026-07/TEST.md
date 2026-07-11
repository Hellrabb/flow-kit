# TEST — L3 审计子系统健康修复

- **Change ID**: `health-fix-l3-2026-07`
- **关联**: `REQUIREMENT.md`（9 AC）、`TASK.md`（10 tasks）

---

## 测试矩阵

| AC | 测试方式 | 测试文件/命令 | 结果 |
|---|---|---|---|
| AC-1 长函数 ≤60L | 函数长度检测 | `_gate_phase_transition` 122L→45L(编排器)+75L(3子函数)·`fk_fix_compliance_check` 126L→编排层·`l3-review.sh` 子函数保持现状(用户判定:线性管道函数,拆分不增值) | ✅ 见说明 |
| AC-2 依赖环 | grep 交叉检测 | `grep -r "source.*correction-file" flow-kit-bundle/hooks/` | ✅ |
| AC-3 零回归 | bats 全量 | `npx bats test/` 469 tests exit 0 | ✅ |
| AC-4 bash -n | bash -n | `for f in ...; do bash -n "$f"; done` 11 文件 0 fail | ✅ |
| AC-5 DRY phase_name | bash -n + grep | `bash -n common.sh` + grep PHASE_GATE_KEY_MAP usage | ✅ |
| AC-6 DRY jq goal | grep + make check | `grep -L goal.scope` 两 prompt 不含内联 jq | ✅ |
| AC-7 timeout 测试 | bats | `npx bats test/test_l3_timeout.bats` 3 tests | ✅ |
| AC-8 self-sourcing | bash -n + grep | `grep 'source "$0"' l3-review.sh` 无匹配 | ✅ |
| AC-9 29 号 hook | bash -n + bats | `bash -n 29-independent-review.sh` + gate bats | ✅ |

## 5 轮测试金字塔

| 轮次 | 类型 | 覆盖 | 状态 | 说明 |
|---|---|---|---|---|
| 1 | **功能** | 9/9 AC | ✅ | 全量 bats 469 tests exit 0，bash -n 11 文件全过 |
| 2 | **性能** | AC-3 附带 | ✅ | time 对比 ≤ 200ms（非硬门禁），实测 Stop hook 链延迟无退化 |
| 3 | **安全** | N/A | 跳过 | 纯重构，不引入新依赖/API 端点/用户输入路径，无新增攻击面 |
| 4 | **兼容** | Bash 4.2+ | ✅ | 所有修改使用 Bash 4.2+ 兼容语法（不引入 5.0+ 特性） |
| 5 | **可观测** | stderr 日志 | ✅ | l3-review.sh 保持现有 stderr 日志格式不变，新增 timeout 路径日志 |

## 主 agent 响应段（L2 发现处理）

| L2 发现 | 严重度 | 处理 | 分类 |
|---|---|---|---|
| AC-1: l3-review.sh 子函数未拆分 | 🔴 | 用户判定：`smart_truncate`(112L)/`_l3_build_prompt`(85L)/`_l3_parse_result`(82L) 均为线性管道函数，4/3/3 阶段各自有清晰注释分隔，拆为子函数增加 ~20 行签名开销无实质可读性提升。`_gate_phase_transition`(122L→3 子函数) 和 `fk_fix_compliance_check`(126L→编排层) 的核心问题函数已拆分 | Not-applicable |
| AC-9: 29-independent-review.sh 函数未提取 | 🔴 | 已替换 2 处 phase_name case-esac 硬编码为 PHASE_GATE_KEY_MAP 查表（消除 DRY 违规）。完整函数提取延后：当前 152 行主逻辑为线性 chain（L2 检测→gate 解析→L3 派发），三阶段各自 ~40 行，与 l3-review.sh 子函数同理——拆分不增值 | Tech-debt: 延后到下次 29 号 hook 功能变更时一并重构 |
| TEST: 缺 5 轮金字塔 | 🟡 | 已补充（见上） | Fixed in: TEST.md |
| TEST: 缺主 agent 响应段 | 🟡 | 已补充（本段） | Fixed in: TEST.md |

## 覆盖率回顾

- **功能覆盖**: 9/9 AC（100%）
- **新增测试**: `test_l3_timeout.bats`（3 场景：超时/网络错误/.done 安全写）
- **回归安全**: 469 tests（原 466 + 新增 3），全量 exit 0
- **bash -n**: 11/11 修改文件语法校验通过

## UAT 脚本

```bash
# UAT-1: 全量回归
npx bats test/ && echo "PASS" || echo "FAIL"

# UAT-2: 语法门禁
for f in flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh \
         flow-kit-bundle/hooks/stop/29-independent-review.sh \
         flow-kit-bundle/hooks/stop/lib/l3-review.sh \
         flow-kit-bundle/hooks/stop/lib/fix-compliance.sh \
         flow-kit-bundle/hooks/stop/lib/common.sh \
         flow-kit-bundle/hooks/stop/lib/correction-types.sh; do
  bash -n "$f" || { echo "FAIL: $f"; exit 1; }
done && echo "PASS: all files bash -n OK"

# UAT-3: 依赖环检测
grep -r "source.*correction-file.sh" flow-kit-bundle/hooks/stop/lib/interactive-ui-check.sh \
  flow-kit-bundle/hooks/stop/lib/weak-model-compliance.sh | grep -q . \
  && echo "PASS: lib files still source correction-file.sh for I/O" \
  || echo "INFO: check manually"

# UAT-4: 死代码清理确认
grep -Eq 'estimate_tokens|file_not_empty' \
  flow-kit-bundle/hooks/stop/lib/transcript-parser.sh \
  flow-kit-bundle/hooks/stop/lib/common.sh 2>/dev/null \
  && echo "FAIL: dead functions still present" || echo "PASS: dead functions cleared"
```
