# T23 SUMMARY · 常设清单自校验（格式校验 + 排除表绑定 + ADR-028 四规则）

- **Change**: `health-fix-2026-09b`（phase 4 DEV）
- **Task**: T23 · model-tier `top` · depends_on T21, T22
- **AC-6 常设清单自校验**：L3 #4 major③ fix 闭合

## 结论

T23 闭合 L3 #4 major③：「R8 将权威清单落常设路径，但清单被误改/篡改/与排除表不同步时校验机制缺失」。
ADR-028 追加四条自校验规则（格式校验 / 内容校验 / 原子更新 / 棘轮只降不升）+ 排除表绑定双态断言；
`check-path-privacy.sh` 实现规则 ①（格式校验，违例 rc=1 指名清单路径 + 行号 + 内容）。
T23 verify 全部判别力分支实测成立：畸形行被拒并指名 `file:line:content`、清单内探针不被自身判据误命中（排除生效）、清单外探针必须命中（排除未过度放宽）、`/home/<user>/` 占位符形态 rc=0。

## 交付物

| 文件 | 状态 | sha256 | 行数 before→after |
|---|---|---|---|
| `flow-kit-bundle/flow-kit/reference/check-path-privacy.sh` | 修改 | `c68a8502a421a67b22acd3946cd3ca6f0ff42c26b3e4f02f7559fc10fb4388f0` | 325→392（+67 行，纯增 0 删） |
| `.specs/adr/028-gate-baseline-allowlist.md` | 修改（staged `A`，T23 是 ADR-028 owner） | `87196d2ae8b0752810ec54c1732549f7e10a54cd80d516b5dff357a74cd62e6b` | staged-new→197（追加「常设清单自校验规则」段 + 四规则 + 排除表双态断言） |
| `.specs/health-fix-2026-09b/T23-SUMMARY.md` | 新增 | — | 0→N |
| `.specs/health-fix-2026-09b/TASK.md` | 修改（仅 T23 `status="pending"`→`"done"`） | — | — |

### check-path-privacy.sh diff 摘要（纯增 67 行）

新增 `validate_allowlist_format()` 函数（约 50 行）+ 调用点（约 4 行）+ 注释块（约 13 行）。
- 函数签名：`validate_allowlist_format <al_path> <al_file>`（al_path=清单路径名用于报文归因，al_file=临时文件）
- 逐行读清单：跳过空行/纯空白行、整行注释（`#` 首字符）、HTML 注释标记（`<!--` 首字符，探针/标记行非有效条目）；
  其余行剥尾随 `# 理由` 注释后判 `<路径>:<行号>`：含冒号 + 冒号后纯数字 + 冒号前非空 ⇒ 通过；违例 ⇒ 打印
  `🔴 允许清单格式违例（ADR-028 规则 ① · file:token 语法）：` + `   清单: <path>` + `   <lineno>: <content>`，return 1。
- 调用点在 `ALLOWLIST_COUNT` 之前（畸形行必须先被拦截，否则会被计入有效条目）。
- 退出码契约保持 `0|1`（脚本内 `return 1`/`exit 1`；make 层映射非零为 2，T18 分层 Makefile 断言依赖不变）。
- bash 3.2 兼容：无 `mapfile`/`declare -A`/`readlink -f/-e`/GNU-only flags/新依赖；用 `case` + 参数展开做格式判定。

## 判据实跑（T23 verify · verbatim）

判据来源：`/tmp/vblocks/v_T23.sh`（byte-identical 重抽取经 `cmp` 确认：`cmp /tmp/v_T23_reextracted.sh /tmp/vblocks/v_T23.sh` ⇒ MATCH，2153 bytes）。

```
$ bash /tmp/vblocks/v_T23.sh
$ echo $?
0
```

verify 块在所有断言通过时静默退出（rc=0，无输出）。verify 块含 7 道断言：
1. ADR-028 含 `file:token|格式校验` ✓
2. ADR-028 含 `原子|mktemp` ✓
3. 门禁绑定 `path-privacy-allowlist.txt` ✓
4. 畸形行 `ZZ-BAD-LINE-NO-COLON` ⇒ rc≠0 且报文指名清单路径 + 行号/内容 ✓
5. 清单内探针（verify 块以字符串拼接生成，源文本不构成连续 PAT 命中）⇒ rc=0（排除生效，未自命中）✓
6. 清单外探针（同上，写入 `.specs/CONTEXT.md`）⇒ rc≠0（排除未过度放宽）✓
7. `cmp -s` 证明 `$A`（常设清单）与 `.specs/CONTEXT.md` 逐字节恢复 ✓

verify 块的受控临时写纪律：先 `cp` 备份（`/tmp/al-fmt-bak` / `/tmp/al-probe-bak`）→ `trap … EXIT` 在首次写入之前安装 → 末段 `cmp -s` 逐字节断言恢复。运行后 `git status --short` 对这两个 tracked 文件无 `M`。

## 门禁与回归输出

| 门禁/回归 | rc | 说明 |
|---|---|---|
| `make lint`（shellcheck） | 0 | `✅ shellcheck: no errors found` |
| `make check-hooks-sync` | 0 | `✅ hooks 副本一致（漂移 0）` |
| `bash sync-hooks.sh --check` | 0 | `✅ hooks 副本一致（漂移 0）` |
| `make check-path-privacy` | 0 | `清单外命中 0 条` / `允许清单 0 条` |
| `make test` | 0 | 基线 973 ok / 0 not ok / 1 skip（见下方实测） |
| `bash /tmp/vblocks/v_T23.sh` | 0 | 本 task 判据 |
| `bash /tmp/vblocks/v_T22.sh` | 0 | 空基线自检未回归 |
| `bash /tmp/vblocks/v_T21.sh` | 0 | R8 读序双态未回归 |
| `bash /tmp/vblocks/v_T18.sh` | 0 | make check 接线未回归 |
| `bash /tmp/vblocks/v_T17.sh` | **1**（**pre-existing**，非本 task 引入） | 见下方「遗留」 |

## 判别力与反例

本 task 改动**新增**的判别分支 = 规则 ① 格式校验。实测 5 个分支（含既有分支的回归确认）：

| 分支 | 注入 | 期望 rc | 实测 rc | 报文关键行 |
|---|---|---|---|---|
| **A** 合法注释-only 清单 | 无（baseline） | 0 | 0 | `清单外命中 0 条` |
| **B** 畸形行（无冒号） | `printf 'ZZ-BAD-LINE-NO-COLON\n' >> $A` | ≠0 | 2（make 映射） | `清单: …path-privacy-allowlist.txt` / `17: ZZ-BAD-LINE-NO-COLON` |
| **C** 清单内探针 | verify 探针（字符串拼接形态，写入 `$A`） | 0 | 0 | （自排除生效，清单文件不在扫描面） |
| **D** 清单外探针 | 同上写入 `.specs/CONTEXT.md` | ≠0 | 2 | `.specs/CONTEXT.md:707:` + 探针标记行 / `清单外命中 1 条` |
| **E** 占位符形态 | `/home/<user>/`（`<` 不在字符类 ⇒ 不命中 PAT） | 0 | 0 | `清单外命中 0 条` |

**关键反例对照（placeholder-vs-real probe pair）**：
- 占位符 `/home/user/`（`user` 在 PLACEHOLDER_NAMES 内）⇒ 逐命中占位符判定 `line_all_hits_placeholder` 返回真 ⇒ 整行跳过 ⇒ rc=0（既有 T22 逻辑，未改）。
- 真名探针（verify 块以 `'/home/''zz-path-pr''obe/'` 拼接生成，`zz-`+`path-probe` 不在 PLACEHOLDER_NAMES）⇒ 不跳过 ⇒ 命中。
- 这对探针证明占位符排除是**逐命中**判定（L-133），不是整行宽排除。

**改动前 B 分支行为（缺陷证据）**：`ZZ-BAD-LINE-NO-COLON` 被旧实现 `grep -cvE '^[[:space:]]*(#|$)'` 计为有效条目（`允许清单 1 条`）⇒ rc=0（畸形行被静默吞掉 ⇒ 信任根 fail-open）。T23 修复后在 `ALLOWLIST_COUNT` 之前拦截。

## 6 维自查

- **正确性**：格式校验在 `ALLOWLIST_COUNT` 之前执行（畸形行先被拦截）；`<!--` 标记行跳过（非有效条目，与探针协议一致）；退出码 `0|1` 不变；bash 3.2 兼容（无 bash4/GNU-only 构造）。
- **完整性**：ADR-028 四规则全落（格式/内容/原子/棘轮）+ 排除表双态断言；`<write_files>` 四个产物全交付（ADR-028、check-path-privacy.sh、T23-SUMMARY、TASK.md status flip）。
- **回归**：v_T22/v_T21/v_T18 全 rc=0；make test rc=0；check-hooks-sync/sync-hooks --check rc=0；check-path-privacy rc=0。v_T17 为 pre-existing 失败（见遗留）。
- **可维护性**：diff 纯增 67 行 0 删，可 review；函数注释说明判别力双态与 verify 固化点；ADR-028 规则段每条含「理由」段。
- **安全与隐私**：自撰散文无 `/home/<真实账号>/` 字面（self-scan ADR-028 = 0 命中；check-path-privacy.sh 命中均为 SELF_EXCLUDE 内的 `zz-path-probe`/`user` 占位符）；commit message 无 live 路径。
- **文档一致性**：ADR-028 四规则与 task `<action>` 四条逐条对应（① 格式 / ② 内容 / ③ 原子 / ④ 棘轮）+ 排除表双态断言与 verify 块分支 C/D 对应。

## 遗留

- **`bash /tmp/vblocks/v_T17.sh` rc=1（pre-existing，非本 task 引入）**：v_T17 的「清单缺失态 rc=1」断言（`bash "$S"` 后 `[ "$rc" -eq 1 ]`）在 T21 冻结常设清单后**失效**——清单已存在且 0 条（合法空基线），gate 正确返回 rc=0，但 v_T17 的该断言仍期望 rc=1（stale）。实测：stash 本 task 改动后 v_T17 仍 rc=1（同一失败点），证明非本 task 回归。该 stale 断言属 v_T17 自身待修，不在 T23 写面；本 task 改动（格式校验）不触及「清单缺失 fail-closed」路径，未使该 stale 断言恶化。v_T17 后续断言（CHECK_REV rev 模式、占位符逐命中粒度、自证行格式）因前序 `exit 1` 未触达，状态未知。
