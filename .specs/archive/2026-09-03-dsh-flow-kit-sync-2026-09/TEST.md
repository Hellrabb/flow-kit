# TEST — dsh-flow-kit-sync-2026-09（证据记录 · phase 5 L3 fail 已吸收：UAT/mock/覆盖口径）

## 单元（实测 exit 0，2026-09-03）

```bash
node --test dsh-flow-kit/test/*.test.mjs   # # tests 20 / pass 20 / fail 0
```

覆盖：doctor 三形状（state-integrity violations[].check 去重；compliance 
violations[].rule 含空 check 回退；model-missing 无 violations 有 message）；
/flow model 五级链落盘 + 回显新值 + --clear + 仅 4 键（断言在
dsh-flow-kit/test/flow-state.test.mjs）。

## 回归（2026-09-02 实测全量）

```bash
bats test/    # 770 ok / 0 fail（顶层 68 文件 770 @test；weak-model-robustness 8 例非递归排除，口径自洽）
```

定向逐文件（实测 10+19+2+16=47 ok）：bats test/test_correction_hygiene.bats \
test/test_flow_active_integrity.bats test/test_install_dsh_platform.bats \
test/test_fk_resolve_model.bats

## 静态（实测 exit 0）

- make lint（shellcheck error 级 0 错误）；make check-test-sync（diff -rq test/
  flow-kit-bundle/test/ 空输出）
- bash package-dsh-plugin.sh 内置 node --check + bash -n 全量 0 失败
- vendor 零丢失：diff -rq flow-kit-bundle dist/dsh-flow-kit/vendor/flow-kit-bundle 空输出

## AC → 测试映射

| AC | 覆盖 |
|---|---|
| AC-1 打包一致性 | package-dsh-plugin.sh exit 0 + vendor diff 空（上文） |
| AC-2 /flow model | flow-state.test.mjs model 用例（回显新值/4 键/--clear） |
| AC-3 doctor | flow-state.test.mjs doctor 用例（check/rule/message 三形状） |
| AC-4 版本/files | node -e 校验 version=0.2.0 + files 六项（T2 verify，exit 0） |
| AC-5 回归门禁 | 上文 bats 770 + make lint + check-test-sync |
| AC-6 profile 集成 | INTEGRATION.md dump-config 摘要（profile 为本地状态） |

## Mock 声明

无 mock 屏蔽：单测驱动真实 runFlowCommand 文件 I/O（tempProject 真实临时目录）；
bats 跑真实 shell 链；未使用 FLOW_KIT_L2_MOCK（仅 hook 套件测试约定）；L2 盲审为
真实独立子代理、L3 为真实外部 API（deepseek-v4-flash-0731 · HTTP 200）。

## UAT（真实执行回放）

1. /flow doctor：无 correction → 卫生良好；三类 correction → type/violations 摘要
   （单测驱动真实 I/O 断言即回放）
2. /flow model l2-default=X l3-default=Y → .goal 落盘 + 回显新值（同上前置）
3. web / flowkit-test 两 profile：pnpm install 后 dump-config 含 id: flow-kit
   （inject: commands+skills+systemPrompt，INTEGRATION.md 摘要）
4. gate 提交流程：868f362 / 0981bd7 与补审提交经 PreToolUse 全链（done 校验）通过

## 覆盖率口径

本仓无行覆盖率工具（node --test TAP，无 c8/nyc 集成，属既有工程结构）；覆盖口径
= AC→用例映射表 + 770 bats 全量回归，非本 change 引入缺口。
