# TEST: 独立 review gate `.done` 作者性校验缺口修复

- **Change ID**: gate-done-authorship
- **关联**: `@.specs/gate-done-authorship/REQUIREMENT.md`、`@.specs/gate-done-authorship/DESIGN.md`

---

## 步骤 0 · 测试范围声明

| 轮次 | 适用？ | 说明 |
|------|--------|------|
| 1 功能测试 | ✅ | 22 test_gate_integrity.bats（AC-1 ~ AC-6）+ full regression 612 ok |
| 2 性能测试 | ⏭ | path-guard D7 同步执行，无新增延迟 |
| 3 安全测试 | ✅ | AC-1 forged/hijack/tampered 路径覆盖 + AC-6 payload 集成 + AC-4 L2-only 例外 |
| 4 兼容测试 | ⏭ | 非 UI/DB 项目 |
| 5 可观测性 | ✅ | path-guard 拦截日志写 hook log |

---

## 1. 功能测试

### test_gate_integrity.bats（22 tests · 全绿）

| 分类 | 测试 | 结果 |
|------|------|------|
| AC-1 .done 真实性 | empty-done / forged-done / hijack-mv / tampered-sed / gate-config-tamper / T4 L2 裁决不匹配（负向·R1补） | ✅ 6 ok |
| D9 正向 | 合法 .done（T4 L2 pass 一致）+ fail-close + 兼容 | ✅ 3 ok |
| D7 path-guard | > / >> / cp / sed -i → block · exotic python-c → 不挡 · 非.done → 放行 | ✅ 6 ok |
| AC-6 payload | gate_config=both → agent Bash 写 .done → deny exit 2 | ✅ 1 ok |
| AC-4 L2-only | gate_config=L2 → agent 写 .done → 放行 exit 0 | ✅ 1 ok |
| D10 phases_done | is_phase_write 2 用例 + 纯读放行 | ✅ 3 ok |
| AC-3/AC-6 其他 | 5站点 + 29号不dump | ✅ 3 ok |

### 全量回归

```
make test → 612 ok / 0 fail / exit 0 ✅
双源同步 diff 一致 ✅
```

---

## 3. 安全测试

| 攻击路径 | 对策 | 测试 | 结果 |
|---------|------|------|------|
| Bash cat heredoc 写 .done | _is_dotdone_write 命中 heredoc → return 0 | AC-1 ②③ | ✅ |
| mv 子目录 .done 到目标 | _is_dotdone_write 命中 mv → return 0 | AC-1 ④ | ✅ |
| sed -i 原地改 .done | _is_dotdone_write 命中 sed → return 0 | AC-1 ⑤ | ✅ |
| python -c exotic | v1 不挡（return 1）→ v2 加密签名 | D7 python-c | ✅ 记录 |
| gate_config=both → agent 写 .done | _gate_path_guard deny exit 2 | AC-6 payload | ✅ |
| gate_config=L2 → agent 写 .done | _gate_is_l2_only 放行 exit 0 | AC-4 L2-only | ✅ |
| l3_review_run 写 .done | 架构天然隔离（Stop hook ≠ PreToolUse） | 无需代码级放行 | ✅ 设计 |

---

## 5. 可观测性

path-guard 拦截时 cat >&2 输出拒绝原因（含被拦截路径 + 阶段号），写入 hook log。

---

## 测试质量自检

| 维度 | 状态 |
|------|------|
| AC 覆盖 | 7/7 AC 全覆盖 ✅ |
| 边界测试 | 双路径 + 非法值覆盖 ✅ |
| 回归安全 | 612 bats 0 fail ✅ |

---

> AC 是测试用例来源，本文件不再引入新 AC。测试结果来自 T04/T06。
