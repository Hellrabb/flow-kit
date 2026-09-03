# TASK — dsh-flow-kit-sync-2026-09（回顾拆解 · phase 3 L3 fail 已吸收）

## 约束与写权限（L3 修正版）

- write_files 白名单：常规目标 dsh-flow-kit/ 与 .specs/dsh-flow-kit-sync-2026-09/；
  豁免目标：dist/（构建）、~/.dsh/profiles/web|flowkit-test/node_modules（安装）、
  .specs/CHANGELOG.md 与 .specs/LESSONS.md（仓库级归档登记，仅 T8）；
  不触碰 .specs/CONTEXT.md 等禁动文件。
- 依赖图（线性无环）：T1→T2→T3→T4→T5→T6→T7→T8（每个 T[N] depends_on T[N-1]，无并行）。
- 线性依赖 T1→T8，无并行项（回顾补档）。

## AC 覆盖矩阵

| AC | 负责 Task |
|---|---|
| AC-1 打包一致性 | T5 |
| AC-2 /flow model 五级链 | T2 / T3 |
| AC-3 doctor 报告 | T2 / T3 |
| AC-4 版本与 files | T2 |
| AC-5 回归门禁 | T5 |
| AC-6 profile 集成 | T6 |

| Task | depends_on | 内容 | Verify（可执行命令） |
|---|---|---|---|
| T1 | — | 盘点 flow-kit 增量 4 sha 与 dist 差距 + 产出 T1-DIST-GAP.md | test -f .specs/dsh-flow-kit-sync-2026-09/T1-DIST-GAP.md && grep -q '2999024\|47c68ef' .specs/dsh-flow-kit-sync-2026-09/T1-DIST-GAP.md && for s in 9a81098 47c68ef 76261dc 2999024; do git merge-base --is-ancestor \$s HEAD || exit 1; done |
| T2 | T1 | flow-state.js doctor/model 实现 + version 0.2.0（AC-4） | node -e "const p=require('./dsh-flow-kit/package.json'); if(p.version!=='0.2.0')process.exit(1); ['vendor','skills','flow-kit','hooks','brooks-lint','docs'].forEach(d=>{if(!p.files.includes(d))process.exit(2)})"；行为正确性由 T3 的 node --test 断言承担 |
| T3 | T2 | 单测行为断言（AC-2/AC-3：node --test 驱动真实 runFlowCommand） | bash -o pipefail -c 'node --test dsh-flow-kit/test/flow-state.test.mjs 2>&1 | tee /tmp/fk-flow-test.log | grep -E "doctor reports correction|gate-config and model persist"' && grep -q 'L2: 凭证不落盘' dsh-flow-kit/test/flow-state.test.mjs && ! grep -q '^not ok' /tmp/fk-flow-test.log |
| T4 | T3 | 文档 §7 计数/§8/README/VERIFY | grep -n '770 用例全绿' dsh-flow-kit/DESIGN.md && grep -n '平台确认串声明' dsh-flow-kit/DESIGN.md && grep -n '同步 flow-kit 更新' dsh-flow-kit/README.md && grep -n 'round 5' dsh-flow-kit/VERIFY.md |
| T5 | T4 | 打包+vendor diff+回归门禁（AC-1/5） | 工作目录=仓库根；源 bundle 即仓库根 flow-kit-bundle/：bash package-dsh-plugin.sh && diff -rq flow-kit-bundle dist/dsh-flow-kit/vendor/flow-kit-bundle && make lint && make check-test-sync && test "$(grep -c '^ok ' <(bats test/))" -eq 770 |
| T6 | T5 | 两 profile 重装+挂载（AC-6：web + flowkit-test 双断言） | for prof in web flowkit-test; do grep -q 0.2.0 ~/.dsh/profiles/$prof/node_modules/dsh-flow-kit/package.json && dsh --profile $prof --dump-config 2>&1 | grep -q 'id: flow-kit' || exit 1; done |
| T7 | T6 | L2 盲审 ×6 阶段+修复 | for p in 1 2 3 5 6 7; do f=.specs/dsh-flow-kit-sync-2026-09/INDEPENDENT-REVIEW-\$p.md; grep -q '^## L2 盲审' "\$f" && grep -q '\*\*Verdict\*\*: pass' "\$f" || exit 1; done |
| T8 | T7 | L3 ×6 阶段+归档+CHANGELOG/LESSONS | 见下方附录命令（对入库工件断言，不依赖运行时文件） |

## 附录 · T8 机器校验（仓库根相对路径）

```bash
cd <repo-root>
# 6 个 gate 阶段（1/2/3/5/6/7；phase 4=dev 无独立审查 gate，故无 review-4）
for p in 1 2 3 5 6 7; do f=.specs/dsh-flow-kit-sync-2026-09/INDEPENDENT-REVIEW-$p.md;
  grep -q '^## L2 盲审' "$f" && grep -q '"verdict": "pass"' "$f" || { echo "phase $p missing/pending"; exit 1; }; done
test -f .specs/dsh-flow-kit-sync-2026-09/REVIEW.md
grep -q 'L-082' .specs/LESSONS.md
head -5 .specs/CHANGELOG.md | grep -q 'dsh-flow-kit-sync-2026-09'
# 归档六件套（REQUIREMENT/DESIGN/TASK/TEST/REVIEW/INTEGRATION + CHANGE + MINOR-DEFERRED）均存在
for f in CHANGE REQUIREMENT DESIGN TASK TEST REVIEW INTEGRATION MINOR-DEFERRED; do
  test -f .specs/dsh-flow-kit-sync-2026-09/$f.md || exit 1; done
```