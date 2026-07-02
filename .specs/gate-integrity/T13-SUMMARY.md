# SUMMARY: T13 - test_gate_integrity.bats 主测试套（AC 1~6 + D7-D10）

- **Change ID**: gate-integrity
- **Task ID**: T13
- **完成时间**: 2026-07-02 14:02
- **AI 角色**: Dev

## 做了什么

新建 `test_gate_integrity.bats`（21 tests 全过）。覆盖：AC-1 六类威胁（empty/forged/hijack/tampered/gate-config-tamper，fk_validate_done_marker + fk_check_gate_config_tamper deny=return 2/1）+ D9 正向（合法→return 0）+ AC-3 5 站点（gate.sh/artifacts.sh 正则 + case grep）+ D7 path-guard 6 向量（重定向/追加/cp/sed-i 挡；python-c exotic + 非握手 放行）+ D10 phases_done 3 场景（写信号拦 + .phase= 不回归 + 纯读放行）+ AC-6（29号 不 dump + l3_token sha256）。

**关键修正**：bats `run` 在子 shell 不继承 setup source 的函数（→ 127），函数测试改为直接调用 + `$?` 断言；grep 类保留 run。setup 加 `export PROJECT_ROOT=$TEST_TMPDIR` 让 fk 函数读测试目录。

## 改动文件

| 文件 | 性质 | 说明 |
|---|---|---|
| flow-kit-bundle/test/test_gate_integrity.bats | 新建 | 21 tests，AC-1~6 + D7-D10 |

## verify

```text
$ npx bats test/test_gate_integrity.bats
1..21
ok 1-21（全过）
```

## 完成判定

- TASK.md 已勾选：是
