# T13-SUMMARY — C14-f/g 基线常设化 + flow-active-query 唯一解析入口（AC-12-f/g）

change: health-fix-2026-09c · Wave 6 · 单任务（无兄弟并行）
前置：T04(863c82a) ✓ / T12b(eca69ff) ✓
规范源：TASK.md T13 块（:429-458）+ DESIGN.md D3/§9.3/§9.5/附录 A + ADR-031 + ADR-028

---

## 1. 交付物清单（对照 write_files）

| 文件 | 动作 | 说明 |
|---|---|---|
| flow-kit-bundle/flow-kit/reference/path-privacy-baseline.txt | 首建 | 判据形态基线（PAT + 占位表 + sha256 对账行，真名零明文） |
| flow-kit-bundle/flow-kit/reference/flow-active-inline-whitelist.txt | 首建 | 内联解析存量白名单（427 条实测回填） |
| flow-kit-bundle/flow-kit/reference/check-path-privacy.sh | 修改 | 09b 硬编码解除 + 白名单三层读序 |
| flow-kit-bundle/lib/flow-active-query.sh | 首建 | .flow-active 唯一解析入口（+x） |
| Makefile | 修改 | internals 块改调 + 新 target check-flow-active-inline 挂链 |
| flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh | 修改 | :78-84 解析块改调（+ :15 注释去谓词命中） |
| test/test_flow_active_query.bats + 镜像 | 首建×2 | 14 用例 rc 契约回归网 |
| （偏差）test/test_path_privacy_gate.bats + 镜像 | 修改×2 | 4 用例随 SUT 语义演进（见 §7 偏差 1） |

## 2. 基线/白名单实测回填账（不抄 DESIGN 旧数）

**flow-active-inline-whitelist.txt = 427 条**（附录 A 严格谓词四分支合并去重后实测；生成
管道与 make check-flow-active-inline recipe 逐字同源 ⇒ 条目与命中行零漂移）：

- A. 测试夹具（test/ + flow-kit-bundle/test/ 镜像）：**360 条**（auto_checkpoint 29×2、
  flow_model 16×2、checkpoint 16×2、gate_integrity 13×2、flow_artifacts 13×2、
  correction_hygiene 12×2、flow_kit_resume 10×2、flow_active_integrity 6×2、
  fail_closed/l2_pretooluse_dispatch/l3_review_defects/phase-resolution/pipeline-no-g1 5×2 等）
- B. JS 存量（dsh-flow-kit/ 三文件）：**16 条**（flow-state.js 12 + l2-review.js 2 + index.js 2）
  —— ADR-031 决策 4：JS 侧无法直调 bash 入口；替代闸 = §9.3 gate_config 预设名五载体集合比对
- C. hooks 存量：**43 条**（common.sh 5、flow-kit-artifacts.sh 5、auto-checkpoint.sh 5、
  flow-kit-resume.sh 4、l3-review/done-validation/34-archive/29-independent/26-workflow/
  gate-helpers-types/gate-checks-basic 各 2、余 13 文件各 1）
- D. 根工具与回归演示：**8 条**（verify-claims.sh:41 存量 jq 解析 + regression-demos 3 脚本 +
  flow-kit/regression-demos 1）

改码消除的命中（不进白名单，符合 §9.5）：Makefile :313 while-read 1 条（改调后行内含
flow-active-query 自排除）、gate :78-84 jq 内联 4 条（改调）、gate :15 注释命中 1 条（措辞改
「状态档」）、check-path-privacy.sh FA_QUERY 调用 0 条（无字面）。

**path-privacy-baseline.txt**：PAT 与 PLACEHOLDER_NAMES 与 check-path-privacy.sh 源码逐字
diff 一致；5 行 sha256 对账（L_home / L_home_slash / L_pwd / L_pwd_slash / L_remote），派生
规则写在文件内供 T16 同机重算对账；真名明文 grep 0 条。

**check-path-privacy.sh SELF_EXCLUDE 冻结集 6→2**（本脚本 + 常设 allowlist）；09b 死豁免
4 条（change 副本 + INDEPENDENT-REVIEW-1/2/3.md）解除——09b 已归档，路径在盘 GONE，零影响。
grep 'health-fix-2026-09b' 本文件 = 0（AC-12-f 机检锚）。

## 3. 三层读序设计（两处门禁同口径，ADR-028 :43）

两门禁（check-path-privacy 允许清单 / check-flow-active-inline 白名单）统一读序：

1. **常设**（flow-kit-bundle/flow-kit/reference/ 下同名文件）——入库基线，不受 change 归档影响；
2. **唯一非归档 change 副本**（.specs/*/ 下同名文件，排除 .specs/archive/*，恰 1 个才用）；
3. **双缺 fail-closed**：exit 1 具名报文（常设路径 + change 层 pattern），不得当空清单放行；
   空清单（剥注释后无条目）同样转红（附录 A）。

check-path-privacy 的 change 层路径额外经 flow-active-query 取活动 change_id 解析
（.specs/<active-id>/path-privacy-allowlist.txt）；query 不可用（旧布局安装）或 id 缺失时
优雅降级到 glob 唯一枚举；多候选无 active id ⇒ 视同 change 层缺失走双缺报文。

## 4. 两调用点改调 diff 摘要

**Makefile check-nfr-portability-internals（原 :311-314）**：
`_active_id=""` + while-read case 解析 →
`_aq_rc=0; _active_id="$$(bash flow-kit-bundle/lib/flow-active-query.sh '.change_id' 2>/dev/null)" || _aq_rc=$$?`
rc2 ⇒ 🔴 fail-closed 报文 + _write_rc 1 + exit 0；rc1 ⇒ _active_id=""（非管辖语义）。
:316 起 change-base 锚点回退逻辑未动。

**independent-review-gate.sh（原 :78-84）**：
flow_file 探针 + jq empty 校验 →
`fa_query` 双候选探测（${HOOK_BASE_DIR}/../../lib/ 与 ../../vendor/flow-kit-bundle/lib/，
源树/vendor/插件包三布局实测可解析）→ 都缺 = 旧式安装：stderr 单行警告 + exit 0（等价
「非管辖放行」，C12 保留语义，零内联解析）→ `flow-active-query.sh --root <cwd> --print-file`
rc0 续走 / rc1 exit 0 / rc2 exit 2（报文含「非法 JSON」+ 透传 query stderr——AC-8② 断言锚）。
下游 _gate_phase_filter / _gate_tamper_detect / _gate_phase_transition 继续用 $flow_file，未动。

两调用点均不进白名单（行内含 flow-active-query 即自排除）——§9.5 禁动三条第 2 条遵守。

## 5. verify 真实输出（任务块原文照跑）

```
npx bats test/test_flow_active_query.bats test/test_path_privacy_gate.bats
  → 53/53 ok（query 14 + path-privacy 39；尾部 ok 51/52/53 为 T04 节）
test "$(grep -cE 'done < \.flow-active|\[ -f \.flow-active \]' Makefile)" -eq 0 → 负锚 =0 ✓
test "$(grep -c 'flow-active-query' Makefile)" -ge 1 → 正锚 =2 ✓（AC-12-g 双锚齐备）
make check-flow-active-inline
  → ✅ 内联解析存量豁免 427 条 / 谓词命中 427 行，全部登记在案
make check-test-sync → ✅ test 双源一致
make hooks-sync → ✅ 已同步 4 个文件（4 个存在的 DEST_ROOTS）
make check-hooks-sync → ✅ hooks 副本一致（漂移 0）
编排者补验：make lint → ✅ shellcheck: no errors found（RC=0）
            make check-path-privacy → ✅ 候选 1660 / 实际扫描 1658 / 自排除 2 /
              命中 0 / 清单外 0（与改前逐项一致——基线语义零劣化）
连带探测：check-validate / check-gate-sync / check-skills-sync / check-nfr-portability 全绿
  （check-nfr-portability 全量模式：存量基线 5 条，无新增 bash4-only/GNU-only）
```

## 6. 六维自检

| 维 | 判据 | 结果 |
|---|---|---|
| 任务块逐项 | action 五要素（首建基线/白名单、解除硬编码、新建入口、两调用点改调、N 实测回填） | 全 ✓ |
| AC 对齐 | AC-12-f（硬编码解除+常设首建）/ AC-12-g（双锚+门禁挂链） | ✓（done 条件逐字满足） |
| 边界纪律 | 只写 write_files + SUMMARY；未 commit；未触 .flow-active（全程只读）/TASK 状态/REQUIREMENT/DESIGN/skills/prompts；§9.5 三条未违 | ✓（偏差 1 见 §7） |
| 测试活性 | 新网 14 用例覆盖 rc 0/1/2 × 显/隐 × 覆盖旋钮（--root/FLOW_ACTIVE_FILE/jq 缺失 PATH 剥离）；SUT 运行时复制非桩；--separate-stderr 防假绿 | ✓ |
| 文档过账 | 本 SUMMARY + 白名单/基线文件头注释自描述（格式/读序/ratchet/派生规则） | ✓ |
| verify 真跑 | §5 全绿；偏差与移交如实登记 | ✓ |

## 7. 偏差与移交

1. **write_files 外改动（必要偏差）**：test/test_path_privacy_gate.bats + 镜像共 4 用例随
   SUT 语义演进更新（双层缺失报文改 pattern 断言；ALLOW_CHANGE_REL 改夹具自选
   .specs/fixture-change/；T-FIX-24 冻结集 6→2、伪条目去 09b 形态）。不改则任务块 verify
   第 1 项与 check-test-sync 必红——verify 命令本身强制了该同步。
2. **gate :15 注释**：「.flow-active 非法 JSON」→「状态档非法 JSON」（gate 在 write_files 内；
   消除谓词命中使 gate 生产面 0 命中，未入白名单）。
3. **dist 未重建（移交编排者）**：check-dist 红 9 条（3 缺失新文件 ×2 布局 + check-path-
   privacy.sh 陈旧 ×2 + test 镜像陈旧/缺失 ×2 + lib 新文件缺失 1）。任务说明「dist 归编排者」；
   波末 `bash package-dsh-plugin.sh` 重建即绿（注意先 make test-sync 已做）。
4. **用户级安装 gate 探针（移交后续 change）**：~/.claude/hooks 布局无 lib/ 兄弟目录 ⇒
   gate 走「旧式安装」放行腿（= 原非管辖语义，零内联解析，行为不劣化）。真正收敛需扩
   install_hooks.sh/sync-hooks.sh 分发 lib/（两者不在 write_files，禁改）。dist/vendor 布局
   已实测可解析（hooks/../lib/ 在场）。
5. **verify-claims.sh:41 存量解析**：白名单 D 类登记（不在 write_files，禁改），后续 change 收敛。
6. 全量 make test（flock fd9 并发闸）归编排者波末；本任务定向 bats 全绿。
