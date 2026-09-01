# TEST.md · correction-hygiene-state-guard

## 本次测试范围声明

| 轮次 | 状态 | 范围 | 跳过理由（如跳过）|
|---|---|---|---|
| 第 1 轮 · 功能 | ✅ 必跑 | AC-1~AC-10 全覆盖（bats 764/764）| — |
| 第 2 轮 · 性能 | ✅ 必跑 | Stop hook 执行耗时预算 | — |
| 第 3 轮 · 安全 | ✅ 必跑 | 凭证模式扫描（AC-6）+ shellcheck（make lint）| — |
| 第 4 轮 · 兼容 | ✅ 必跑 | 双源一致性 + chisel_env 真实回放（AC-9 UAT）+ 老数据格式兼容 | — |
| 第 5 轮 · 可观测 | ✅ 必跑 | stderr 审计行（健康清零/退场/外来让位）| — |

后端/lib 项目：无 UI，第三轮 UI 审查不适用（flow-review 跳过第三轮）。

## 第 1 轮 · 功能测试

### AC → 测试矩阵

| AC | 类型 | 用例 | 状态 |
|---|---|---|---|
| AC-1 去重 | unit | test_correction_hygiene.bats AC-1（3 同键→1 保最新）+ T01 smoke | ✅ |
| AC-2 容量 | unit | AC-2（12 白名单→10 FIFO，compliance 不占配额）| ✅ |
| AC-3 健康清零 | integration | AC-3（合法 JSON 全通过→清 9 白名单，保 l2-missing/compliance）| ✅ |
| AC-4 退场 | e2e | AC-4a 纯 type rm+审计 / AC-4b 合并标签剥离保 violations | ✅ |
| AC-5 外来让位 | e2e | AC-5/6（YAML→no corrupt_json+1 note 幂等）+ NFR corrupt JSON（已更新至新 AC）| ✅ |
| AC-6 外来清空 | e2e | 同 AC-5/6 用例（type 剥离+清白名单+保留集合）| ✅ |
| AC-7 只读 | e2e | AC-7（sha256+mtime 不变）| ✅ |
| AC-8 回归 | 4 门 | make check：bats 764/764 + shellcheck 0 error + validate 302 项 0 漏配 + test 双源 diff 一致 | ✅ |
| AC-9 chisel_env | e2e | AC-9 合成 50 条收敛 + **UAT-1 真实回放**（见下）| ✅ |
| AC-10 compliance 保护 | unit | AC-10 三路径逐字节比对 + R1 写入保护 | ✅ |

### 覆盖率与边界

- 边界值用例 ≥ 3：纯 type 退化 rc1 / segment 不在 rc0 / missing+invalid+no-array 静默 / 空白名单全保 / 合成 50 条超容量
- 错误路径：invalid JSON correction → fail-open 不阻塞 Stop（T01 smoke + AC-5）

### 测试质量自检 · 6 维衰退风险（内置清单）

- [x] T1 晦涩：用例名含 AC 编号+场景描述
- [x] T2 脆弱：断言 jq 行为输出（计数/type/逐字节），非内部实现细节
- [x] T3 重复：每用例映射唯一 AC，无换姿势重复
- [x] T4 Mock 滥用：0 mock——全部真实子进程/source 驱动 33/29 主路径
- [x] T5 覆盖率幻觉：全部有真断言（计数/sha256/jq -c 字节比对），无空 expect
- [x] T6 架构错配：helper 单测（correction-file.sh 函数级）+ 主路径 e2e（29/33 子进程），层级匹配

## 第 2 轮 · 性能测试

预算：Stop hook 每次会话结束触发，单模块 <100ms（无硬门槛，REQUIREMENT 非功能段已声明"不设数值门槛、以不显著拖慢 Stop 为准"）。

| 路径 | 20 次均耗时 | 判定 |
|---|---|---|
| 健康清零路径（合法 JSON）| 41ms | ✅ 达标（含 bash 子进程+jq 启动开销）|
| 外来让位路径（YAML）| 24ms | ✅ 达标 |

对比基线：改造前 33 号同路径约 35-40ms（纯 jq append），新增 dedupe/trim 后增幅 <10%，无退步。

## 第 3 轮 · 安全测试

- 凭证模式扫描（AC-6 红线）：`sk-*/Bearer/ANTHROPIC` 三模式 grep 三个改动 hook 文件 + 2 个测试文件 → **0 命中** ✅
- shellcheck -S error（make lint）：0 error ✅（make check 第 2 门）
- 注入面：全部 jq --arg 参数化，无字符串拼接进 jq 程序体；rm 仅作用于 `$CORRECTION_FILE` 单文件（AC-4a 审计行先行）✅

## 第 4 轮 · 兼容性测试

- 双源一致性：`diff -r test/ flow-kit-bundle/test/` 零差异 + make check 第 4 门 test-sync ✅
- 老数据格式兼容：NFR "read-merge-write preserves existing violations"（28 号 compliance 混写场景）继续通过 ✅
- chisel_env 真实回放（UAT-1，见下）✅
- 跨 bash/jq 版本：依赖 jq ≥1.6（`test()`/`--arg`/`group_by`），与既有基线一致，无新增版本要求 ✅

### UAT-1 · chisel_env 真实数据回放（AC-9 真实世界证据）

```
前置：~/chisel_env/.flow-active（YAML，traceweave-skill-mining）+ 真实 correction
      （type=l2-missing+state-integrity，50 violations：43 corrupt_json +
       1 phase_artifact_missing + 6 pipeline_phase_artifact_missing）
步骤：原样拷贝至 fixture → 运行 flow-kit-bundle/hooks/stop/33-flow-active-integrity.sh
期望：首轮收敛——白名单 50 条清空（43+1+6 全为白名单类）、type 剥离为 l2-missing、恰 1 条 foreign_state note、
      .flow-active sha256 不变、stderr 输出让位提示、exit 0
结果：✅ 全部符合（n=50→1，type=l2-missing，foreign_state=1，AC-7 PASS，
      stderr="flow-active-integrity: .flow-active 非 flow-kit 状态文件（外来/损坏），已让位；
      foreign_state note 已写入 correction"）
```

## 第 5 轮 · 可观测性验证

- 健康清零：stderr `state-integrity cleared N items`（原文实测）✅
- l2 退场：stderr `[29-l2-retire] clearing l2-missing (was: <type>)` ✅
- 外来让位：stderr 中文提示（区分 YAML/损坏 JSON 措辞）✅
- 无 PII/密钥入日志：审计行仅含 type 标签与计数 ✅

## 回归测试登记

| 用例 | 文件 | 备注 |
|---|---|---|
| 10 条 hygiene 用例 | test/test_correction_hygiene.bats（双源）| T04 新增 |
| NFR corrupt JSON（更新）| test/test_flow_active_integrity.bats | 断言更新至 AC-5/6/7 |
| L-080（提名）| — | 29 号单测需 export CONFIG_FILE/PROJECT_ROOT/HOOK_BASE_DIR/HOOK_TMP_DIR；source 33 触发底部 implicit main 且 2>/dev/null 会吞审计行 |

## 结论

5 轮全绿。真实世界 UAT-1（chisel_env 50 条收敛）通过——本 change 的两个用户可见表象（只增不清 + corrupt_json 误报刷屏）均在真实数据上验证修复。
