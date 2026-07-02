# T04-SUMMARY · regression-demos 创建（7 demo + check.sh + README）

- **Change**: gate-integrity
- **Task**: T04（Wave 1 · 并行 · 独立文件 · **Wave1 收尾**）
- **AC**: AC-1 ①-⑥ + AC-2 + exotic（威胁验收载体）
- **完成**: 2026-07-02

## 改动清单（9 文件，全新）

| 文件 | 角色 | 内容 |
|---|---|---|
| `test/regression-demos/README.md` | 总览 | 威胁→demo→hook→v1 立场映射表 + 运行说明 + v1 诚实边界 |
| `empty-done/setup.sh` | 场景生成器 | 威胁① 空 .done 到指定目录 |
| `empty-done/check.sh` | 验收① | 空 .done → 期望 T1 非空检查 deny |
| `forged-done/check.sh` | 验收②③ | 伪造 KVP + 无握手 → 期望 T2/T3 deny |
| `hijack-done/check.sh` | 验收④ | 移花接木（change_id 不匹配）→ 期望 T2/T3b deny |
| `tampered-done/check.sh` | 验收⑤ | 篡改 L3_verdict 与握手不一致 → 期望 T4 比对 deny |
| `gate-config-tamper/check.sh` | 验收⑥ | gate_config independent→false → 期望 fk_check_gate_config_tamper deny |
| `skipped-subprocess/check.sh` | 验收③+AC-2 | 无 .done transition → 期望 gates 前置查拒 |
| `exotic-escape/check.sh` | 验收 exotic | python-c 写握手 → 文档化 v1 不挡（best-effort）|

## 实现内容

### 威胁 → demo 映射（对齐 AC-1 验证方式 + REQUIREMENT 威胁编号）

| demo | 威胁 | 依赖 hook（Wave2 task）| v1 立场 |
|---|---|---|---|
| empty-done | ① 空 .done | fk_validate_done_marker T1（T06）| ✅ 挡 |
| forged-done | ②③ KVP 伪造 + Write 自产 | T2/T3（T06）+ is_handshake_write（T07）| ✅ 挡常见向量 |
| hijack-done | ④ 移花接木 | T2 change_id + T3b session_id（T06）| ✅ 挡 |
| tampered-done | ⑤ 篡改合法内容 | T4 verdict 比对（T06）+ is_handshake_write（T07）| ✅ 挡常见；⑤-L2 v1 提高成本 |
| gate-config-tamper | ⑥ gate_config 篡改 | fk_check_gate_config_tamper（T09）| ✅ 检测（D8）|
| skipped-subprocess | ③+AC-2 跳过子进程 transition | fk_validate_done_marker（T06）+ 前置查（T11）| ✅ 挡 |
| exotic-escape | exotic Bash 逃逸 | is_handshake_write（T07）| ⚠️ v1 不挡（R12）|

### PENDING 机制（Wave 协作设计）

每个 check.sh 检测其依赖的 hook 函数是否已实现（`grep -qE 'func[[:space:]]*\(\)'`）：
- **未实现（T04 当前）** → 输出 `⏳ PENDING`（exit 0，载体就位）+ 标注依赖 task
- **T06-T11 实现后** → 自动激活真验证（source hook lib + 调用 + 断言期望 exit 码）
- **T13** → test_gate_integrity.bats 整合全量断言

这是 Wave1（载体）→ Wave2（hook）→ Wave3（整合测试）的协作划分：T04 建场景 + 期望框架，不阻塞于 hook 实现。

### exotic-escape 特殊处理

v1 best-effort 立场：is_handshake_write 对 exotic 向量（python-c/base64/变量间接/dd）返回 false（放行）是**预期边界**，非 bug。check.sh 无论挡/不挡都 exit 0，文档化 v2 加密签名留待（DESIGN §6 · R12）。

## verify 结果

```
bash -n 语法检查：8/8 OK（7 check.sh + 1 setup.sh）
T04 verify（for d in */; do bash check.sh）：
  7 demo 全 ⏳ PENDING（符合预期：hook T05-T11 未实现，载体就位）
  exit 0（verify 容忍 PENDING）
```

每个 PENDING 明确标注：依赖的 T06/T07/T09/T11 + 威胁编号 + 待激活条件。

## 6 维自查（本 task 性质：威胁场景载体 + 断言框架，无生产代码）

| 维度 | 结论 |
|---|---|
| 沿用既有抽象（R6.4） | ✅ 复用 CONTEXT.md `regression-demo` 既有概念（每失败模式一 demo + check.sh）；check.sh 结构统一（SCRIPT_DIR/BUNDLE_ROOT 自定位 + trap 清理）|
| 一致性 | ✅ 7 demo 威胁编号与 REQUIREMENT AC-1 ①-⑥ + DESIGN §3 Tier 1/2 逐条对齐；v1 立场与 DESIGN §6 不在范围一致 |
| 向后兼容 | ✅ 全新目录，不碰既有文件；PENDING 机制不阻塞（exit 0）|
| 边界正确性 | ✅ 每个威胁 setup 场景与对应 Tier 校验呼应（①→T1 / ②③→T2T3 / ④→T3b / ⑤→T4 / ⑥→D8 / ③→前置查）|
| 测试覆盖 | ✅ 7 demo 覆盖 AC-1 全 6 威胁 + AC-2 + exotic；PENDING→激活→T13 整合三层 |
| 🔴 已修 / 🟡 已记 / 🟢 可省 | 🟢 无 🔴（载体框架，激活后由 T13 验证真行为）|

## LESSONS 查阅（R1.8）

- **L-015（🔴 active）**：已查阅。本 task 全新建 `test/regression-demos/`（开发资产，不部署到 ~/.claude/ 运行时），无运行时副本改动，L-015 N/A
- **L-014（🟢 active）**：已应用。check.sh 的 PENDING 检测 grep 用 `[[:space:]]*\(\)`（POSIX 类），避免 `\]` 字符类陷阱；demo 文件内 grep 无复杂字符类
- 无其他 active 条目命中

## 越界检查（R6.5）

```
git status（T04 范围）：全部 ?? （全新文件，0 修改既有）
  flow-kit-bundle/test/regression-demos/（9 文件：README + empty{setup,check} + 6 check）
```
- 改动文件 = write_files 列（9 文件完全匹配 TASK.md T04）
- **0 越界**：未改 hooks / 其他 task 文件 / 既有 test / 禁动清单

## 时序交接（Wave1 → Wave2）

- **Wave1 完成**：T01（PRESET_MAP）+ T02（check-gate-sync）+ T03（pipeline-gates）+ T04（regression-demos）全 done
- **下一步 Wave2**：T05（AC-3 阶段判定 + case 扩 3/5/7）起串行 hook 核心（T05→T11）
- **demo 激活**：T06 实现 fk_validate_done_marker 后，empty/forged/hijack/tampered/skipped 5 demo 自动激活；T07 is_handshake_write → forged/tampered/exotic；T09 fk_check_gate_config_tamper → gate-config-tamper
- **R1.4**：Wave2 每个 task 需 fresh session（建议 `/clear` + `/flow-go 继续`）
