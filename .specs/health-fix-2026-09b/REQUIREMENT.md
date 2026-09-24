# REQUIREMENT: 收口 4 个 🔴 + 隐私前向门禁 + 假绿测试

- **Change ID**: `health-fix-2026-09b`
- **关联**: `@.specs/health-fix-2026-09b/CHANGE.md`、`@.specs/CONTEXT.md`、`@.specs/health/2026-09-22-FULL-SWEEP.md`

---

## 用户故事

- **US-1**：作为 **flow-kit 的日常使用者**，我想让 hook 的安全守卫**不再对载荷做任何命令求值**，
  以便我写文件时不会被载荷里的命令替换注入执行任意命令。
- **US-2**：作为 **在未装 jq 的机器上安装 flow-kit 的人**，我想让安装**在缺依赖时安全中止且不改动既有配置**，
  以便我不丢失已有的 `settings.json`（含 `permissions.allow` 与既有 hooks）。
- **US-3**：作为 **仓库维护者**，我想让"隐私清理是否完成"有一条**可复算的判据**，
  以便我不靠人工确信、也不被"某个 ref 漏了"这类局部视角骗过。
- **US-4**：作为 **仓库维护者**，我想让 prompt↔skill 一致性门禁**真的能看见漂移**（既不是永久红灯、也不是永久假绿），
  以便我敢把它接进 `make check` 并信任它的结论。
- **US-5**：作为 **分发件的接收方**，我想让 bundle 与 npm 包里**不出现内部项目名**，
  以便不泄露雇主内部项目线索。
- **US-6**：作为 **仓库维护者**，我想让"前向脱敏"有**机器门禁**，
  以便新写的代码/文档不会再引入本机绝对路径或组织线索。
- **US-7**：作为 **依赖测试绿灯放行的人**，我想让绿灯**是真的**（不是恒真断言、不是 mock 自证、不是把失败 skip 掉），
  以便绿灯能作为放行依据。

## 验收准则（AC）

> ⚠️ **本表每条 AC 均已在写需求时**（2026-09-22）**实跑一次并确认"修复前不成立"** ——
> 依据本仓 `LESSONS` **L-090**（"AC 必须在写需求时就跑一次、确认它当前失败，否则无法区分
> '这条 AC 有证明力'与'它测试了不存在的东西'"）。实测值见文末「修复前实测行为」表。

### AC-1 · 安全守卫不再求值载荷（PC1）

- **Given** `flow-kit-bundle/hooks/pre-tool-use/runtime-edit-guard.sh` 被修复并同步到 `dist/` 与已安装副本
- **When** 以携带命令替换的载荷（`file_path` 含 `$(<命令>)`）驱动该 hook
- **Then** ① 全部 **7 个 `eval echo` 面**（源树 **1** + `sync-hooks.sh --list` 枚举的 **6 个 DEST_ROOT**）
  **以及 2 个分发归档**（`dist/dsh-flow-kit-*.tgz`，L2 C4 补）归零；
  ② 载荷中的命令**不被执行**（以"落盘哨兵文件不存在"为判据）；③ 正常的 `~` 展开**仍然生效**

- **验证方式（判据必须用精确 pattern · L2 第 2 轮 N1 证伪初版）**:
  ```bash
  export LC_ALL=C
  PAT='\$\([[:space:]]*eval[[:space:]]'
  # 源树（基线 1 ⇒ 断言当前必须非零退出）
  n=$(grep -rEn "$PAT" flow-kit-bundle/ | wc -l); echo "源树 eval-echo=$n"
  [ "$n" -eq 0 ] || { echo "🔴 源树仍有 eval-echo"; exit 1; }
  # 副本面：一律用 --list 的 ✅ 行枚举，禁止手工列路径
  # `mapfile` 是 bash4-only —— 与本文档 NFR「新代码不得新增此类依赖」自相矛盾（R6-2），
  #   故用 bash 3.2 兼容的数组累加（macOS 上 mapfile 会 command not found ⇒ AC-1 判据必然报红）
  DESTS=(); while IFS= read -r d; do DESTS+=("$d"); done \
      < <(bash sync-hooks.sh --list | grep -E '✅' | awk '{print $2}')
  [ "${#DESTS[@]}" -eq 6 ] || { echo "🔴 副本面枚举数=${#DESTS[@]} ≠ 6（枚举失效，判据不可信）"; exit 1; }
  n=$(for d in "${DESTS[@]}"; do grep -rEn "$PAT" "$d"; done | wc -l); echo "6 副本面 eval-echo=$n"
  [ "$n" -eq 0 ] || { echo "🔴 副本面仍有 eval-echo"; exit 1; }
  # L3 minor3：副本面是否会含第三方 vendored 散文（致假红）？—— 已实测，**6 个副本面全部为 `hooks/` 目录、
  #   内不含 brooks-lint 等 vendored 内容**（逐面 `grep -rl 'eval test case'` 命中均为 0）。
  #   故 v1 **无需**对副本面加 vendored 排除；但判据应保留一条守卫，防未来副本结构变化后静默失准：
  v=$(for d in "${DESTS[@]}"; do grep -rlE 'eval test case|brooks-lint' "$d" 2>/dev/null; done | wc -l)
  [ "$v" -eq 0 ] || { echo "🔴 副本面出现 vendored 内容（$v 个文件）—— 判据口径需重新评估"; exit 1; }
  ```
- **⚠️ 为何不能用 `\beval\b`（这是本轮被证伪的关键）**: 粗 pattern 在 4 个路径上实测返回 **111** 处，
  其中 **104 处来自 `dist/**/brooks-lint/**` 第三方 vendored 代码的英文散文**
  （`CONTRIBUTING.md` 的 "an eval test case"、`new_eval.md`、`eval-utils.mjs` 等），
  而本 change 的 out 段**锁死"不修改 vendored 代码"** ⇒ 沿用粗 pattern 时"期望 0"**永不可达**，
  唯一的"通过"路径是违反自己的 out 锁、或再次悄悄收窄判据。
  **基线口径（两个数字必须分开记，不可混用）**：精确 pattern → 源树 **1** / 6 副本面 **6** / 合计 **7**；
  粗 pattern → 4 路径 **111**（噪声 104）。
- **⚠️ 面数必须由工具枚举（L2 N1 第二处）**: 初版手列 4 个路径，实测**漏了 2 个 DEST_ROOT**
  （`~/.dsh/profiles/web/node_modules/dsh-flow-kit/hooks` 与
  `.../dsh-flow-kit/vendor/flow-kit-bundle/hooks`）—— 手工列表会随安装形态漂移，
  故一律以 `sync-hooks.sh --list` 的 ✅ 行（当前 **6** 条）为准。
  ```bash
  # ④ 分发归档面（L2 C4：此前**无任何门禁覆盖 .tgz 内容**）
  shopt -s nullglob; ARCHIVES=(dist/dsh-flow-kit-*.tgz); shopt -u nullglob
  [ "${#ARCHIVES[@]}" -gt 0 ] || { echo "🔴 未匹配到任何归档（glob 失效，判据不可信）"; exit 1; }   # R5
  for t in "${ARCHIVES[@]}"; do
      tar tzf "$t" >/dev/null 2>&1 || { echo "🔴 归档不可解析: $t"; exit 1; }   # R5：先证归档可解析
      n=$(tar xzOf "$t" | grep -acE '\$\([[:space:]]*eval[[:space:]]')
      echo "$t: eval-echo=$n"
      [ "$n" -eq 0 ] || { echo "🔴 已发布归档仍含可注入 hook"; exit 1; }
  done
  ```
- **⚠️ 归档面此前完全无门禁（L2 C4 · 严重度高于源树）**: 实测 `dist/dsh-flow-kit-0.1.0.tgz` 与
  `0.2.0.tgz` **各含 2 处** `$(eval echo …)` ⇒ **已发布的 npm 件同样带可注入 hook**；
  而 `make check-dist` **只比 staging 目录 vs 源、不校验 `.tgz` 内容**（`.tgz` 仅由打包路径产出）
  ⇒ 归档内容是**门禁盲区**。故必须在**源修复 + `sync-hooks.sh` 之后**重建归档，
  且**旧归档（`0.1.0`）的处置须显式决定**（删除 / 重建 / 记为已知残留）——
  保留未重建的旧版本等于继续分发一个可注入的发布件。处置方式由 **DESIGN 定义**。
- 哨兵法 PoC 须驱动**本机实际执行的那一份**（`~/.claude/hooks/pre-tool-use/runtime-edit-guard.sh`）——
  L2 已独立复现该副本**当前仍可被注入执行**；载荷 `file_path='$(touch <哨兵>)~/.claude/hooks/x.sh'`
  → 运行后 `test ! -e <哨兵>`。
- **正例必须可观测（L2 D2）**: 初版正例用 `file_path='~/.claude/hooks/x.sh'`，实测 **rc=0、输出 0 字节**
  —— 因 deny 只在"推导出的维护源存在"时才打印展开路径，而 `x.sh` 无维护源
  ⇒ Then③「`~` 展开仍生效」**既不能过也不能败**。改用**有维护源**的路径 + `cwd=仓根`，
  已实测 **rc=2、693 字节、输出含 `你正在编辑: /home/<user>/...`**：
  ```bash
  cd "$(git rev-parse --show-toplevel)"
  out=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"~/.claude/hooks/pre-tool-use/runtime-edit-guard.sh"}}' \
        | bash flow-kit-bundle/hooks/pre-tool-use/runtime-edit-guard.sh 2>&1); rc=$?
  [ "$rc" -eq 2 ] || { echo "🔴 正例 rc=$rc ≠ 2"; exit 1; }
  printf '%s' "$out" | grep -qE '你正在编辑: /' \
      || { echo "🔴 正例不可观测：~ 展开未被证明"; exit 1; }
  ```
- **注（修复载体）**: 本机实际执行的是**安装副本**，故修复**必须走 `sync-hooks.sh`**，
  并以 `make check-hooks-sync` 验证 6 个副本面（当前 rc=0）

### AC-2 · 缺 jq 时既有配置不被破坏（PC2）

- **Given** 存在一个已有内容的 `settings.json`（含 `permissions.allow` 与既有 hook），且 PATH 中**遮蔽 jq**
- **When** 运行安装流程
- **Then**（F1：初版此处与本文档自身判定**相反**，已订正）该 `settings.json`
  **未被截断为空、原 `permissions.allow` 与既有 hook 仍存活**，且安装以**非零退出**。
  **明确不是"字节数不变"** —— 对照态实测 **120 → 1162 字节**（安装器**合法地追加 hooks**，文件本就该增长）；
  若按"字节不变"断言，会把**合法行为**误判为破坏。
  **「可读缺依赖提示」半边 v1 不设断言**：实测该路径下失败态输出 `提及jq=0`，断言不成立（留 v2 或 DESIGN 复核）。
- **验证方式（R6-1 整段重写 · 全程沙箱，**绝不动真实 `$HOME`**）**:
  ```bash
  SBX=$(mktemp -d /tmp/l2-ac2-XXXXXX); mkdir -p "$SBX/home/.claude"
  printf '{"permissions":{"allow":["Bash(ls:*)"]},"hooks":{"Stop":[{"matcher":"","hooks":[{"type":"command","command":"true"}]}]}}' \
      > "$SBX/home/.claude/settings.json"

  # 影子 PATH：软链真实工具、**排除 jq**。
  #   ⚠️ 不能用 `PATH="/nonexistent:$PATH"` —— 实测 `command -v jq` 仍 → /usr/bin/jq（PATH 是查找序，非白名单）
  mkdir -p "$SBX/shadow"; IFS=':' read -ra __D <<< "$PATH"
  for d in "${__D[@]}"; do [ -d "$d" ] || continue
    for f in "$d"/*; do [ -e "$f" ] || continue
      b=$(basename "$f"); [ "$b" = "jq" ] && continue
      [ -e "$SBX/shadow/$b" ] || ln -s "$f" "$SBX/shadow/$b" 2>/dev/null || true
    done
  done

  # ⓪ 前提自检（缺此则判据会在"jq 存在"的正常态里空转 —— 这正是初版的病）
  PATH="$SBX/shadow" command -v jq >/dev/null 2>&1 && { echo "🔴 前提未满足：jq 仍可见"; exit 1; }
  PATH="$SBX/shadow" command -v mkdir >/dev/null 2>&1 || { echo "🔴 影子环境缺基础工具"; exit 1; }

  # 运行：**必须用这三个 flag**。实测 `--global` 单用会在 `install_brooks.sh:169` 中止，
  #   **根本到不了** `install_hooks.sh:251` 的截断行 ⇒ 判据会对目标缺陷假绿
  rc=0; HOME="$SBX/home" PATH="$SBX/shadow" \
      bash flow-kit-bundle/install.sh --global --no-brooks --user >"$SBX/out" 2>&1 || rc=$?

  # 断言（均已实测双态有区分力）
  [ "$rc" -ne 0 ] || { echo "🔴 缺 jq 时未非零退出（静默失败）"; exit 1; }        # 失败态127 / 对照0
  SET="$SBX/home/.claude/settings.json"; sz=$(wc -c < "$SET")
  [ "$sz" -gt 0 ] || { echo "🔴 settings.json 被截断为空"; exit 1; }            # 失败态0 / 对照1162
  grep -q 'Bash(ls:\*)' "$SET" || { echo "🔴 原 permissions.allow 丢失"; exit 1; }  # 失败态丢 / 对照存
  ```
- **⚠️ 断言语义更正（本轮实测推翻初版）**: 初版断言「字节数**不变**」是**错的** ——
  对照态（jq 正常）实测 **120 → 1162 字节**，因为安装器**合法地追加了 hooks**，文件本就该增长。
  正确的判别断言是「**未被截断为空 + 原 `permissions.allow` 存活**」。
  另**删去**「输出须提及 jq」这条 —— 实测该路径下失败态输出 `提及jq=0`，断言不成立。
- **⚠️ 判据必须真正触达缺陷现场（本轮新增定式 · 见 L-122）**: 实测三种 flag 组合的差异：
  `--global` → rc=127 但在 `install_brooks.sh:169` 中止、**未触及**截断行；
  `--global --no-brooks` → rc=0、**未截断**（未走 user-scope wiring）；
  `--global --no-brooks --user` → rc=127、**120→0 截断复现** ⇒ 只有这一组能命中缺陷现场。
  **凡判据涉及"某分支上的缺陷"，必须先用实测证明该路径真能到达该分支**，否则判据是对该缺陷的假绿。

### AC-3 · 泄漏分支无法被误推（P1 · v1 范围）

- **Given** 本地 `main` 仍携带前向脱敏前历史（本次**不清理**，见 v2）
- **Given（拦截载体 · 本轮补全 · L2 R11 判定为 Not resolved）** 拦截由 `pre-push` 钩子承担，
  其**安装必须随仓库可复现** —— 对照 P6 已记录的教训（`.git/hooks/pre-commit` 是指向仓库外的
  机器本地 symlink，**不随 clone 传播**）。
  **R5 订正（初版禁令句与 `ADR-022` 冲突且自身两 clause 互斥）**：初版此处写
  「`pre-push` **不得**采用同类不可复现载体」—— 但 `ADR-022` **已锁定** git hook 采用
  **symlink → 已安装 hooks 目录**，故该禁令**照字面执行等于未经声明地 supersede ADR-022**。
  现改为与 ADR-022 一致的口径：`pre-push` **沿用 ADR-022 的 symlink 机制**；
  "可复现"的定义是「**由 `install_hooks.sh` 部署 + `sync-hooks.sh --check` 校验**」，**不是**"clone 即有"。
  **另注（L2 阶段2 R3）**：仓内 `.git/hooks/pre-push` **已存在**（373 B，内容即 `make check`），
  其处置已在 `DESIGN.md` D3 显式裁决。
  具体载体（纳入某 `make` 目标 / 由 `install_hooks.sh` 部署并校验）由 **DESIGN 定义**。
  **L3 major2 订正**：初版此处还承诺"须有一条 verify 证明**在干净 clone 上拦截仍生效**"，
  但本条验证方式只有四形态实跑、**无干净 clone 判据**，且该 verify 已被
  `MINOR-DEFERRED.md` 记为 deferred ⇒ **Given 承诺与可执行判据脱节**。
  现**把该承诺移出 v1 的 Given**，改为边界声明：**v1 只验四形态被拦 / 干净 ref 放行；
  「干净 clone 复现」属 v2**（依赖 DESIGN 定载体，见 MINOR-DEFERRED 的 C7 行）"
- **When** 执行**四种** push 形态：① `git push origin main`（单 ref）② `git push --all`
  ③ `git push --mirror` ④ `git push --tags`
- **Then** 推送**被拦截**并给出可读原因（指出哪个 ref 含泄漏），**且**对不含泄漏的正常推送（如 `develop`）**不误拦**
- **验证方式**: 隔离环境（临时 bare remote）逐条实跑**上述四种**；断言泄漏 ref 被拒 + 干净 ref 放行。
  注：L2 已实测 `--dry-run` 三种形态**均会**调用 `pre-push` 且 stdin 收到 ref → 隔离验证环境本身可用

### AC-4 · 门禁能看见「内容漂移」而非只数行数（AR2）

- **Given** `check-gate-sync.sh` 的判据由「比行数」改为「**比内容**」；且**已接入 `make check`**
- **Given（比较对 · 本轮定稿 · 解决 L2 R3 与 N2）** 比较对 = 「**内容本应一致、仅平台 front-matter 不同**」
  的 prompt↔skill 载体对。**实测有 3 对满足**（`diff` 恒为 **6 行** = SKILL 独有的 YAML front-matter）：
  `A-evolve`↔`flow-evolve`（342/347 行）· `I-intel-scan`↔`flow-intel`（250/255）·
  `L-restyle`↔`flow-restyle`（192/197）。
  **明确排除两类**：① **PCSC 表** —— `reference/phase-prompt-template.md:144` 明写其属
  「**结构性文档化（不抽取）**」（phase-specific 内容占比高，**逐 phase 本就不应相同**），
  `:145` 方向是**参数化**而非单源化；② **hooks 镜像面** —— 已有 `check-hooks-sync` 专职守护，
  纳入本门禁属**重复覆盖**（L2 N2）。
- **约束修订（L2 N2 关键）** 前提由「两侧**逐字**一致」改为「**内容一致（仅平台 front-matter 可不同）**」——
  原措辞的字面口径会把上述 3 对**全部排除**（它们正差 front-matter），使 **US-4 失去 AC 载体**
- **Given（覆盖边界声明 · L2 C5）** v1 **只覆盖 3/14 对** —— 其余 11 对**已实质分叉**
  （最惨 `6-review`↔`flow-review` 仅 28 行交集），强行纳入会让门禁立刻变红且**无法收敛**。
  故 v1 的边界为 **3/14**，且须**要求门禁输出打印覆盖度**（如 `校验对 3/14`），
  以免 `check-gate-sync.sh:157` 的「✅ 所有校验对一致」被读成 **14 对全绿**。
  「14 对全量同步策略」属 v2（TD-025 的内容裁决：镜像 or 允许差异的精简版）。
- **When** ① 在健康仓库上运行 `make check`；② 对比较对 `(P, S)` 之一做**仅内容、行数不变**的改动
- **Then** ① `make check` 的**先决条件列表**中含 `check-gate-sync`，且健康态该门禁 `exit 0`；
  ② **行数不变的内容漂移必须报红并指名位置**
- **验证方式**:
  - 接线（F3：初版是陈述句、**无失败分支** —— 与 L-121① 自相矛盾，已补）:
    `make -n check | grep -q 'check-gate-sync' || { echo "🔴 check-gate-sync 未接入 make check"; exit 1; }`
    —— 用**干跑**天然排除注释命中
    （L2 R1 证伪初版：`grep -c 'check-gate-sync' Makefile` 实测为 **1** 而非 0，
    且唯一命中是 `Makefile:16` 的**注释**；`check:` 先决条件实为
    `test lint check-validate check-test-sync check-hooks-sync check-dist`，**确实未接线**。
    即初版判据"应 ≥1"**修复前已成立** ⇒ 恒真、无区分力，违反本条自身引用的 L-090）
  - 健康（F3：同上补失败分支）:
    `bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh || { echo "🔴 健康态门禁未通过"; exit 1; }`
  - 覆盖度（R6：C5 的防误读措施初版**无判据**）：健康态输出须含 **`校验对 3/14`**
    ```bash
    bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh | grep -q '校验对 3/14' \
        || { echo "🔴 未打印覆盖度 3/14（易被读成 14 对全绿）"; exit 1; }
    ```
  - 漂移（R6 + **F3 差分锚点**）：改比较对一侧的一行文案（**行数不变**）后重跑，
    须非 0 **且输出含 `文件:行号` 形态的定位**。
    **F3 关键补充**：仅断言"漂移后 rc≠0"**不充分** —— 一个**永久红**的门禁也能满足它。
    故必须先断言**未改动态 rc=0**（见上「健康」条），再做漂移并断言 rc≠0 ⇒ **两态构成差分**，
    永久红无法通过第一态。
    ```bash
    out=$(bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh); rc=$?
    [ "$rc" -ne 0 ] || { echo "🔴 内容漂移未报红"; exit 1; }
    # R6-4：初版 pattern `[^ ]+:[0-9]+` 过宽（时间戳/计数/巧合 `x:1` 均可满足）⇒ 收紧为
    #   「受检文件路径 + :行号」，即必须出现被改的那个文件名的定位
    printf '%s' "$out" | grep -qE '(prompts|skills)/[^ :]+:[0-9]+' \
        || { echo "🔴 报红但未指名「文件:行号」（Then② 未满足）"; exit 1; }
    ```
- **⚠️ 本条是最关键的 AC**：它直接证伪「只修正则」方案 —— 实测若只修正则，
  `4-dev`(8 行) vs `flow-dev`(8 行) 会因**行数相同**而通过，而那 8 行是
  `SKILL.md:156-163` 的**迁移框架表**（Prisma/Alembic/…），**与 PCSC 无关**
  ⇒ 证明「纯计数比较」语义盲。**该证伪例仍然成立**（它是"为什么必须比内容"的证据），
  但**不再作为比较对候选**（PCSC 已在上方排除）

### AC-5 · 内部项目名不再随分发件出厂（P3）

- **Given** `test/` 与 `flow-kit-bundle/test/` 中的 `chisel-*` 已替换为中性占位，且 npm 包已重建
- **When** 扫描三个分发面
- **Then** `test/`、`flow-kit-bundle/test/`、**重建后的 npm 包（逐个归档，禁通配）**
  三处 `chisel` 计数**均为 0**；**且**这两份 bats 仍全绿（证明是字面替换而非删测试）
- **⚠️ 判据必须能失败（L2 N3）**: 初版循环只 `echo` 计数、**无失败退出**，逐字跑输出
  `0.2.0.tgz: 6` 而整体 `rc=0` —— 即"有泄漏"时判据仍然绿。故循环内须**显式断言并 exit 1**
- **验证方式（必须能失败 · L2 N3）**: 归档面逐文件循环、禁通配，**且计数非 0 时必须退出非零**：
  ```bash
  fail=0
  for f in dist/dsh-flow-kit-*.tgz; do
    tar tzf "$f" >/dev/null 2>&1 || { echo "归档不可解析: $f"; exit 1; }   # 先证归档可解析
    n=$(tar xzOf "$f" | grep -ac chisel)
    echo "$f: chisel=$n"
    [ "$n" -eq 0 ] || fail=1                    # ← 关键：断言，而非只看输出
  done
  [ "$fail" -eq 0 ] || { echo "🔴 分发件仍含 chisel"; exit 1; }
  grep -rq chisel test/ flow-kit-bundle/test/ && { echo "🔴 源测试仍含 chisel"; exit 1; }
  bats test/                                    # 不退化
  ```
  **实测基线（2026-09-22）**: `dist/dsh-flow-kit-0.1.0.tgz` = **0** / `0.2.0.tgz` = **6**
  ⇒ 修复前该判据**必须非零退出**（初版只 `echo` 后整体 rc=0，故恒绿）。
- **⚠️ 为何禁通配（L2 R2 实测证伪初版）**: `dist/` 同时存在**两个**归档时，
  `tar xzOf dist/dsh-flow-kit-*.tgz` 展开为 2 个参数 → tar 把**第二个归档当成成员名** →
  实测 `tar: dist/dsh-flow-kit-0.2.0.tgz：归档中找不到`、rc=2、stdout **空** →
  `grep -ac` 输出 **0**。即初版 AC 的这条判据**构造成立即为绿、与包内容永久无关**；
  而同刻单文件形态实测为 **6**（预检表用的正是单文件形态 —— **实测与验收不是同一条命令**）

### AC-6 · 前向脱敏有机器门禁（P6）

- **Given** 新增 `make check-path-privacy` 并纳入 `make check` 与 pre-commit
- **When** ① 在 tracked 文件中插入**探针串**（拼接构造 —— 字面脱形见下）后运行；
  ② 在仓库当前状态运行，并与**冻结基线**（实现时落档的允许清单）比对
- **Then** ① **必须 fail 并指名该文件路径**；② 检查结果与**冻结基线一致**（`rc=0`）
  —— **不写"首跑"**：首跑不可复算（L2 R6），基线必须在实现阶段落档为文件
- **验证方式（判据形态已自检 · 修 L2 C1 + C2）**:
  ```bash
  export LC_ALL=C          # ← **必须锚定**：实测 make 的错误文案随 locale 变
                           #   （zh: 未识别的选项 / 没有规则可制作目标；C: unrecognized option / No rule to make target）

  # ⓪ 判据原语自检 —— 用 **locale 稳定原语**，不做错误文案匹配
  #    （D1 证伪初版：它匹配中文字面串，LC_ALL=C 下两分支同时失效 → 静默 no-op）
  make --help | grep -qw -- '--list' && { echo "🔴 make 竟支持 --list，判据前提已变"; exit 1; }
  #    实测：--list 不支持 → rc=1（zh 与 C 一致）
  make --help | grep -qw -- '--always-make' || { echo "🔴 原语自检失败：正例未命中"; exit 1; }
  #    实测：--always-make 支持 → rc=0（zh 与 C 一致）⇒ 反证上面那条 grep 判据本身有效
  rc=0; make -n check-path-privacy >/dev/null 2>&1 || rc=$?
  #    实测（/tmp 双态 fixture）：目标不存在 rc=2 / 目标存在 rc=0，zh 与 C 两 locale 一致
  case "$rc" in
    0) echo "✅ 目标已实现（继续后续断言）" ;;
    2) echo "ℹ️ make -n rc=2：目标不存在**或依赖缺失**（二者同码；按 DESIGN 确认预期态，不得直判为合法）" ;;
    *) { echo "🔴 rc=$rc 非预期，判据形态可疑"; exit 1; } ;;
  esac

  # ⓪′ 接线断言（D3：Given 承诺"纳入 make check"，初版却无判据 —— AC-4 对自己写了同型判据）
  make -n check | grep -q 'check-path-privacy' \
      || { echo "🔴 未接入 make check"; exit 1; }

  # ① 探针必须被抓住（**失败时也必须先恢复** —— D4：初版 exit 1 在 restore 之前，
  #    会把探针留在 tracked 的 .specs/CONTEXT.md 里）
  #    ① 字面脱形（R2）：探针**不得以连续字面**出现在 tracked 文本里，否则门禁会被自己的 AC 文本击穿。
  #    故用**拼接构造** —— 命令仍逐字可执行，但文档里取不到可命中的整串。
  #   R1 订正：初版写 `'/home/'"'zz-path-pr'"'obe/'` —— 中间的 "'zz-path-pr'" 是**双引号串**，
  #   其中的 ' 成了字面字符 ⇒ 逐字节产出 `/home/'zz-path-pr'obe/`（22B，含两个单引号），
  #   **不等于**原字面（21B）⇒ 对 D10 的 PAT 命中 0 ⇒ 探针抓不住 ⇒ AC-6① 永久红。
  #   正确写法用**相邻单引号段**拼接（shell 会拼接相邻引号串）：
  PROBE='/home/''zz-path-pr''obe/'
  #   R1 自检（L-120 口径）：探针**必须**被自家 PAT 命中；否则后续断言全是空的
  printf '%s\n' "$PROBE" | grep -qE '/home/[a-z_][a-z0-9_-]*/' \
      || { echo "🔴 探针形态自检失败：产出 [$PROBE] 不被 PAT 命中（AC-6① 将永久红）"; exit 1; }
  cp .specs/CONTEXT.md /tmp/probe-bak
  printf '\n<!-- probe: %s -->\n' "$PROBE" >> .specs/CONTEXT.md
  if make check-path-privacy; then
      cp /tmp/probe-bak .specs/CONTEXT.md
      { echo "🔴 未抓住探针"; exit 1; }
  fi
  cp /tmp/probe-bak .specs/CONTEXT.md

  # ② 自证式基线（**不引 make 长选项** —— C1 已证伪 --list）
  make check-path-privacy || { echo "🔴 门禁自身在健康态未通过（rc≠0）"; exit 1; }   # 期望 rc=0
  #   N8→R2 订正（两轮）：v1 只收第 1 类且排除通用占位符 ⇒ **目标态是「基线为空」**；
  #   但第 3 轮 R2 判定「空基线」**本身不是可接受终态** —— 它是「工件已脱敏」的**结果**，不是前提。
  #   故：**基线必须为空，且该"空"须由「工件已脱敏」保证**（而不是靠放宽判据去容纳残留）。
  #   ⇒ 门禁在基线非空时**不得**静默通过：非空即意味着存在**未被复核的残留**（除非在允许清单内）。
  test -f .specs/health-fix-2026-09b/path-privacy-allowlist.txt \
      || { echo "🔴 允许清单未落档（基线不可复算）"; exit 1; }
  #    N8 订正：此处初版写「pattern 用**非空**量词 `[1-9][0-9]*`」—— **已被本轮推翻**：
  #    空清单在 v1 是**合法且预期**的状态（基线条目数 = 0，见 DESIGN D10），故必须用 `[0-9]+`
  #    匹配任意条数；初版用非空量词正是"判据不可满足"的一例。
  #    R4：自报条数必须与**落档文件行数**绑定，否则"门禁不读清单/硬编码"态无法区分
  printed=$(make check-path-privacy | grep -oE '允许清单 [0-9]+ 条' | grep -oE '[0-9]+')
  filed=$(grep -cvE '^[[:space:]]*(#|$)' .specs/health-fix-2026-09b/path-privacy-allowlist.txt)
  echo "自报允许清单=$printed 条 / 落档有效行=$filed 行"
  [ "$printed" = "$filed" ] || { echo "🔴 自报条数($printed) ≠ 落档行数($filed)：门禁可能未真读清单"; exit 1; }
  #   N8 订正：删除「≥1」断言 —— 空清单在 v1 是**合法且预期**的状态（见 D10 的三态实测）
  #   F4：仅绑条数**不够** —— "硬编码同一个数、根本不读清单"的门禁可通过上述全部断言。
  #   故加**差分数断言**：改动 allowlist 后，门禁的对外表现必须随之改变。
  AL=.specs/health-fix-2026-09b/path-privacy-allowlist.txt; cp "$AL" /tmp/al-bak
  DIFF_PROBE='/home/''zz-path-pr''obe-differential/'   # R1 同型订正
  printf '\n%s\n' "$DIFF_PROBE" >> "$AL"
  n2=$(make check-path-privacy | grep -oE '允许清单 [0-9]+ 条' | grep -oE '[0-9]+') || true
  [ "${n2:-0}" -gt "$printed" ] || { echo "🔴 改清单后自报条数未变（$printed→${n2:-0}）：门禁未真读清单（硬编码）"; cp /tmp/al-bak "$AL"; exit 1; }
  cp /tmp/al-bak "$AL"
  make check-path-privacy | grep -qE '清单外命中 0 条' \
      || { echo "🔴 存在清单外命中"; exit 1; }

  # ③ pre-commit 载体 —— 断言**仓库内源**，不断言仓外 symlink（C2 已证伪）
  # R1：初版这两行是**裸命令**（无失败信号）—— 实测失败态下 `grep -q` rc=1 但两行块整体 rc=0
  #     ⇒ "已接入"与"完全没接"不可区分。每条断言都必须自带失败分支。
  grep -q 'check-path-privacy' flow-kit-bundle/hooks/pre-commit/pre-commit.sh \
      || { echo "🔴 pre-commit 源未接入 check-path-privacy"; exit 1; }
  bash sync-hooks.sh --check || { echo "🔴 副本漂移"; exit 1; }
  ```
- **⚠️ 判据原语必须 locale 锚定（L2 D1 · 同一失效类第 4 次复发）**: 初版步骤 ⓪ 用中文字面串
  匹配 `make` 的错误文案，实测三处失效：① 该命令**不带任何选项** ⇒ `未识别的选项` 分支
  **字面执行下不可达**，而 C1 的错误形态正是"选项非法" ⇒ **抓不住它被造出来要抓的东西**；
  ② `LC_ALL=C` 下两分支**同时失效**（`No rule to make target` / `unrecognized option` 均落入 fallback）
  ⇒ **静默 no-op**；③ 目标已实现时仍打印"目标尚未实现（预期）"，标签与事实相反。
  故改用**两个 locale 下均已实测稳定**的原语：`make --help | grep -qw`（能力探测）
  + `make -n <target>` 的 rc（存在性探测）。
- **⚠️ 判据必须经 fixture 双态验证（本轮新增的强制步骤 · 治本）**: 上述所有断言的原语，均已用一个
  `/tmp` 双态 fixture（`absent/` 无该目标、`present/` 有该目标）跑过对照，确认**成功态与失败态
  给出不同结果**；并以"空清单"边界验过 `[1-9][0-9]*` 优于 `[0-9]+`。
  **凡未经双态验证的判据不得写入本文件** —— 前三轮的 R1/N1/C1 与第 4 轮的 D1 均因跳过此步而复发。
- **⚠️ 改为「自证式输出」而非 `--list`（L2 C1 · 不可满足判据）**: 初版写
  `diff <(make check-path-privacy --list …) <allowlist>` —— 实测 `make: 未识别的选项 "--list"`、
  **rc=2、stdout 空**（GNU make 无该长选项，且选项解析在读 makefile **之前**，任何 Makefile 都救不回）
  ⇒ diff 对非空 allowlist 恒为 `0a1,2` / rc=1 ⇒ **"期望无差异"永不可达**。
  改为**由门禁自证**：打印「允许清单 N 条 / 清单外命中 M 条」+ `file:line`，`M≠0` 非零退出
  （同时满足 NFR「可观测性：失败必须指名具体文件/位置」）。允许清单落档
  `.specs/health-fix-2026-09b/path-privacy-allowlist.txt` 供人复核。

- **⚠️ 该基线文件是 4-dev 阶段的产物，当前不存在（L3 major1 指出）**: 实测
  `ls .specs/health-fix-2026-09b/path-privacy-allowlist.txt` → **No such file**。
  故 **AC-6② 的三条断言（`test -s` / 自报↔落档绑定 / 差分数）在本阶段不可执行** ——
  这是**显式声明的依赖缺口，不是隐藏的空判据**。生成方式（由 4-dev 实现门禁时一并产出并入库）：
  ```bash
  make check-path-privacy | grep -oE '[^ ]+:[0-9]+' | sort -u \
      > .specs/health-fix-2026-09b/path-privacy-allowlist.txt   # 冻结首跑基线
  # 随后人工复核：确认每条残留都属"已声明并接受"，再入库
  ```
  **TASK 阶段须把「生成并复核允许清单」列为 AC-6 的前置任务**，否则 AC-6 会在 5-test 因文件缺失而失败。
- **⚠️ 断言对象必须是仓库内源（L2 C2）**: 初版 ③ 用 `$(readlink -f .git/hooks/pre-commit)`，
  实测解析到**仓外** `/home/<acct>/.claude/hooks/pre-commit/pre-commit.sh`
  ⇒ **干净 clone 上假红、只改本机才真绿**。故改断言仓库内源
  `flow-kit-bundle/hooks/pre-commit/pre-commit.sh`（实测 `sync-hooks.sh:136` 的镜像清单已含
  `pre-commit/pre-commit.sh`，`--check` rc=0 ⇒ 可复现）。
  **并订正第 2 轮响应段的空头声称**：那句"载体须随仓库可复现"此前**只落在 AC-3**，
  AC-6 内并无对应文本 —— 这是**第 3 次**"声称已修但工件无该文本"（L2 C2 指出）。
- **⚠️ 初版自相矛盾已订正（L2 R5）**: 初版 When① 写"插入 `/home/<user>`"，与同一 AC 的
  ⚠️ 禁令**直接矛盾**（该形态被 9 个 tracked 文件用作脱敏占位符）。本轮已把 When① 一并改为畸形探针。
- **⚠️ 检测 pattern 由 DESIGN D10 定稿（N8）**：`PAT='/home/[a-z_][a-z0-9_-]*/'` ＋ 通用占位符排除表
  （`user` / `ubuntu` / `...`）。**三态实测**：探针命中 1 · `/home/<user>` 命中 0 · 真实路径命中 1；
  但 `/home/user/` **会**被 pattern 命中 ⇒ 必须叠加排除表，否则 9 个 tracked 文件的良性占位符全成噪声。
- **⚠️ 探针串不得用 `/home/<user>`（L2 R5）**: 该形态已被仓内 **9 个 tracked 文件**用作**脱敏占位符**
  （正是本 change 上游的产物）→ 按字面实现必然**"永久红"或"永不变红"二选一**。
  改用**不可能与既有占位符同形**的畸形探针，且**必须以拼接构造书写**（① 字面脱形：
  tracked 文本不得含可命中的连续整串）—— 即用**相邻单引号段**拼接：`'/home/''zz-path-pr''obe/'`
  （注意：**不是** `'/home/'` + `"'zz-path-pr'"` + `'obe/'` —— 中间用双引号会把单引号变成字面字符，
  R1 即此错）。
- **裁决（v1 · 解决 L2 R6 的 AC-6②↔AC-8 互斥）**: v1 采用 **允许清单 + 棘轮**（冻结首跑基线，只降不升），
  **不采用"先清残留再启用"**。理由：实测首跑残留**包含本 change 自己新写的**
  `.specs/CONTEXT.md:569` 与 `.specs/STATE.md` 的对应行（该两文件 HEAD 版本命中 0，均为**未提交工作区改动**；
  行号 `561`→`569` 系本轮追加 TD-039 所致 —— L2 N5 指出行号会随并发编辑漂移，
  故基线一律以**落档的允许清单文件**为准，不引行号），
  即"残留"并非稳定的外部存量 —— "先清后启用"会让本 AC **不可复算**（清完又会被自己写脏）。
  另：TD-031 列的 4 类模式（绝对路径 / `/Users` / 组织线索 / 私网 IP）v1 **只收第 1 类**，
  其余三类显式留给 v2；"组织线索无门禁"是本 AC 的**已知覆盖缺口**，不假装已覆盖。

### AC-7 · 四处假绿测试不再假绿（TC3/TC4/TC5）

- **Given** 四处假绿已修
- **When** 逐条以**能区分真假绿的手段**复核
- **Then**
  - `test_combined_metric.bats:31-32` 不再接受"除 1 外一切结果"（恒真消除）→ 以**注入残留文件**应判红为证
  - `test_auto_checkpoint.bats:208,221` 断言对象是 **SUT** 而非 jq → 以**让 SUT 失败**应判红为证
  - `test_independent_review_model.bats:81-89,136-141` **先断言文件存在** → 以**删除该文件**应判红为证
  - `test_lessons_cleanup.bats` 中 **AC-4 那条测试**（测试名 `AC-4: 模拟全量覆盖场景下 --validate exit = 0`）
    **必须移除 skip 并断言 `exit 0`**（收敛为唯一可机器验证分支）。
    **L3 minor1 订正**：初版用行号 `:137`，而预检表用 `:135` —— 二者指代不同
    （`:135` 是注释「暂时跳过」，`:137` 才是 `skip` 调用）⇒ **同一 AC 内不一致**。
    现统一改为**按测试名 + 断言内容引用**，不再引行号（抗行号漂移，与 AC-6 的口径一致）

> **R8 的 gap 现状已实测澄清（2026-09-22）**：`bash package-flow-kit.sh --validate` 在干净状态
> **exit=0**（工具自报：**期望覆盖 308 项 / 实际文件 314 项** / 漏配 ERROR=0 / 源缺失 WARNING=0；
> 初版此处误写"覆盖 314 项"，L2 N5 已订正 —— 308 与 314 是两个不同口径，不可混用）。
> 故该 skip 注释所称的
> 「当前仓库有已知 gap，exit=1 是预期行为」**已不成立** —— 原先保留的两种退路
> （"删除测试并开单"、"保留但标注未满足"）**均不再需要**，直接去 skip 即可。
> 这也说明：该 skip 长期掩盖的是一个**已经修好的 gap**，属"过期 skip"形态。
- **验证方式**: 逐条"注入失败源 → 必须变红"（**不是**只跑一次看绿）

### AC-8 · 无退化

- **Given** 上述全部修复落地
- **When** 跑全量质量门禁
- **Then** 全量 bats **≥ 973 ok / 0 not ok**；`make check` 全绿（含两道新门禁）；
  `make check-test-sync` / `check-hooks-sync` / `check-dist` **仍 0 漂移**
- **验证方式**: `make check`；`bats test/`；三道副本一致性门禁。
  **L3 minor2 补**：NFR 兼容性判据在**变更集为空**时以 **`exit 3`（SKIP，未验证）**呈现，
  而初版 AC-8 只列 `make check`/`bats`/三道门禁，**没有机制区分"已通过"与"未验证"** ⇒ 可能把 SKIP 当绿灯。
  故 AC-8 必须显式处理它：
  ```bash
  # 兼容性判据：0=通过 / 1=失败 / 3=未验证（SKIP）
  FILES=$( { git -c core.quotepath=false diff --name-only HEAD; \
             git -c core.quotepath=false ls-files -o --exclude-standard; } | grep -E '\.sh$' | sort -u )
  #   第 6 轮订正（口径统一）：AC-8 的守卫**必须与 A 案同锚点**，否则纯删除态会「SKIP 当绿灯」、
  #   增量提交后会假红且**归因相反**。故此处同样读 `.change-base`（而非 `HEAD`）。
  BASE8="${FLOW_KIT_CHANGE_BASE:-$(cat .specs/health-fix-2026-09b/.change-base 2>/dev/null || true)}"
  [ -n "$BASE8" ] || { echo "🔴 AC-8：变更起点锚点未落档，无法判定变更集非空"; exit 1; }
  FILES=$( { git -c core.quotepath=false diff --name-only "$BASE8"; \
             git -c core.quotepath=false ls-files -o --exclude-standard; } | grep -E '\.sh$' | sort -u )
  [ -n "$FILES" ] || { echo "🔴 AC-8 时点变更集为空（相对锚点 $BASE8）⇒ 兼容性判据 rc=3（未验证），不得当作通过"; exit 1; }
  ```
  即 **本 change 落地后必然有 `.sh` 变更** ⇒ AC-8 时点该集合不应为空；为空即说明变更未落地或已被提交，
  两种情形都**不构成"兼容性已验证"**。

---

## 范围切分

### v1（本次必做）

- **AC-1 ~ AC-8 全部**（PC1 / PC2 / P1 拦截 / AR2 / P3 / P6 / TC3-5 / 无退化）
- 新术语与已锁决策写入 `.specs/CONTEXT.md`（见下）
- 新债项 TD-026~038 已在 CONTEXT.md 登记（本次巡检已前置完成）

### v2（下一轮考虑，不本次）

- **清理本地 `main`，使权威验证（对象库 8 → 0）真正达成** —— 用户本次明确选择"先只加防护，暂不动 `main`"；
  故 `HISTORY-REWRITE-FULL.md:120` 的权威判据在 v1 结束时**仍为 8**
  （**这不是遗漏，是已知且被接受的残留**，见下方「已知未闭环项」）
- `prompts ↔ skills` 14 对双载体的**实质同步**（TD-025 内容裁决：镜像 or 允许差异的精简版）
- `reference/*-protocol.md` → `flow-dev/SKILL.md` 的静默内联（AR3，~290L）与 `L2-blind-review.md` 第三载体（AR4）
- PC3（pre-tool-use 子库 fail-open，潜在）与其余 🟡/🟢（PC4-PC15 · G2-G5 · TD-036）
- **上游巡检的 TC1 / TC2（L2 R9 指出在 v1/v2/out/已知未闭环项四处均无处置）**：
  - **TC1** `test/test_gate_config_presets.bats` 的 **mock 自证**（390 行 / 34 测试，离仓仍 34/34 全绿）
    + 断言已废弃语义 `"independent"`（72 处，出货契约已统一为 `"both"`）
  - **TC2** `check_gate_config_sync()` **只比名字不比値**（值漂移结构性失明）
  - **严重度冲突已裁决（新增假设 5）**：上游巡检记 🔴，而 `.specs/CONTEXT.md` 的 TD-033/034 记 🟡
    → **以巡检 🔴 为准**，DESIGN 阶段需将 TD-033/034 升级为 🔴 并说明为何不在 v1
    （理由：本 change 已含 TC3/TC4/TC5 三项测试修复，再并入 TC1/TC2 会使范围失控；
     但 TC2 的载体 `check-gate-sync.sh:106-124` **正是 AC-4 要改的同一文件** → DESIGN 必须显式声明
     "AC-4 只改判据、不改 `check_gate_config_sync` 的值比较"这一边界，避免被误认为顺带修了 TC2）

### out（永远不做）

- **不重建隐私"安全网"**（裸包 / `refs/backup/*` / 远端旧历史）—— `HISTORY-REWRITE-FULL.md:104`
  要求强推确认后删除，`LESSONS` **L-110 ③** 给出理由（"安全网自己就是最大的泄露面"）。
  **重建等于把泄露面请回来。**
- **不为通过门禁而删测试或放宽断言**（如把 `make check-path-privacy` 做成永远返回 0）
- **不修改 `brooks-lint` / `brooks-tools` 第三方 vendored 代码**
- **不改任何业务运行时语义**（本 change 只碰检查层/判据层/硬化层）

---

## 非功能性需求

- **性能**: 新增门禁 `make check-path-privacy` 单次运行 ≤ **5 秒**（扫 `git ls-files` 内容，不扫 `.git` 内部）；
  `check-gate-sync` 修复后仍为**秒级**。理由：二者要进 `make check`，不能拖慢日常门禁。
  **验证手段（L2 R10 补）**: `time make check-path-privacy` 实测并记入 TEST.md；
  超阈值即视为未满足（阈值必须实测留档，不能只写数字）。
- **可访问性**: 无
- **安全**:
  - AC-1 属**安全修复**：消除一处**已复现的任意代码执行**，必须**零功能回退**（`~` 展开语义保持）
  - AC-2 属**数据完整性修复**：缺依赖场景必须 **fail-closed 且不破坏既有数据**（禁止"先截断再失败"）
  - AC-3 属**纵深防御**：拦截须**精准**（不得把干净 ref 一并拦死，否则会被绕过或关闭）
- **兼容性**: 新增/修改的脚本须在 **bash 3.2（macOS）** 与 bash 4+（Linux）下均不产生语法错误；
  本次**不承担**修复既有 GNU-only `timeout` / bash4 `declare -A` 依赖（TD-035），但**新代码不得新增**此类依赖。
  **验证手段（L2 R10 补 —— 此前的致命缺口：`AC-8` 与 `make lint`（error 级）都检不出它，
  而 TD-035 记录的后果是 macOS 上整条 Stop hook 链静默 no-op）**:
  ```bash
  # 受检集 = 本 change 的**变更全集**（不写占位符 —— D6 指出初版留 `<本 change 新增/修改的脚本>` 未闭环）
  # 取法（L-107 教训：`git diff --name-only` 看不到新增/未跟踪文件）：
  # R2 修正：① 加 `HEAD` 以纳入 staged/已提交变更；② **空集守卫** —— $FILES 为空时
  #   `grep … $FILES` / `bash -n $FILES` 会**退化读 stdin**（实测可被管道输入"命中" rc=0）；
  #   ③ 每条断言自带失败分支；④ 判据自身**不用 mapfile**（避免自相矛盾）
  #   R6-3 边界声明：本判据在**变更未提交时**有效；提交后 `diff --name-only HEAD` 为空 ⇒ 显式 SKIP。
  #     若需在提交后复检，改用 `git diff --name-only <base>..HEAD`（本 change 的 base 由 DESIGN 定）
  #   F2 补充：① SKIP 以 **rc=3** 表达"未验证"，调用方（AC-8 / make check）**必须**把 3 与 0 区分；
  #     ② **自命中风险** —— 若本判据日后被落成变更集内的 `.sh` 脚本，它会检到自己而**永久假红**；
  #     故实现时应把该判据放在**不受本判据扫描的位置**（如 `Makefile` 目标或 `tools/`），DESIGN 需定此点
  # ═══ R3 裁决（A 案）：受检面 = 「**新增行 + 新文件**」，而非整文件 ═══
  #   依据：**本 AC 的 NFR 段**（「新代码不得新增」那一句 —— R7 第 6 轮订正：初版引 `:489-490`
  #   属**在用态悬空自指**，行号会随编辑漂移，故改内容定位）的语义是「**新代码不得新增**此类依赖」，而非「文件内不得存在」
  #   ⇒ A 案与该语义**等价**；整文件方案会命中既有正确/已登记项（实测 `sync-hooks.sh` 的
  #   `mapfile`×3 属 TD-035 known-acceptable，一编辑就 rc=1 ⇒ AC-8 不可达）。
  #   A 案已用双态 fixture 实跑验证：编辑 `sync-hooks.sh` 保留 3 处既有 `mapfile` + 只加非违规行 ⇒ rc=0 ✅；
  #   同场景整文件扫描 ⇒ rc=1（即 R3 原报缺陷）。
  #
  #   ① 锚点：**必须钉「变更起点 SHA」**，不得用裸 `HEAD` —— 实测 `git diff HEAD -- '*.sh'` 在无未提交改动时为 0 行，
  #      增量提交后受检集恒空 ⇒ A 会**静默空转**（假绿）。缺锚点即 fail-closed。
  #   R1（第 6 轮）：锚点**必须有落档机制**，否则判据会挡住自己（未设即 rc=1 ⇒ AC-8 不可达）。
  #   渠道优先级：环境变量 > **落档文件**（4-dev 首步写入并入库）> fail-closed。
  BASE="${FLOW_KIT_CHANGE_BASE:-$(cat .specs/health-fix-2026-09b/.change-base 2>/dev/null || true)}"
  [ -n "$BASE" ] || { echo "🔴 变更起点 SHA 未落档（环境变量未设且 .specs/health-fix-2026-09b/.change-base 不存在）—— 无法界定新增行，判据不可信"; exit 1; }
  git -c core.quotepath=false rev-parse --verify --quiet "${BASE}^{commit}" >/dev/null \
      || { echo "🔴 FLOW_KIT_CHANGE_BASE 不是有效 commit: $BASE"; exit 1; }
  #   ② 受检集：新增行（diff 的 + 侧，剔除 +++ 头）+ 新增文件全文
  ADDED=$(git -c core.quotepath=false diff -U0 "$BASE" -- '*.sh' | grep -E '^\+' | grep -v '^+++' || true)
  NEWF=$(git -c core.quotepath=false ls-files -o --exclude-standard | grep -E '\.sh$' || true)
  if [ -z "$ADDED" ] && [ -z "$NEWF" ]; then
      echo "⏭ SKIP：相对 $BASE 无 .sh 新增（**未验证**，非通过）"; exit 3
  fi
  #   ③ 注释行剔除（R6 / L-101：负向断言必须排除注释行，否则注释里提到该原语即假红）
  SCAN=$( { printf '%s\n' "$ADDED"; [ -n "$NEWF" ] && cat $NEWF; } | grep -vE '^\+?[[:space:]]*#' || true)
  #   ④ 判据 + **可移植惯用法豁免**：`stat -c … || stat -f …` 是本仓既有的**正确**跨平台写法
  #      （实测 bundle 内 12 行含 `stat -c`，其中 **10** 行同行含 `stat -f`）⇒ 不得判红。
  #      **第 6 轮订正：豁免必须按「成分删除」而非「整行豁免」** —— 整行豁免会让
  #      **同行出现的真违规一起逃逸**（实测 `mapfile …; t=$(stat -c … || stat -f …)` 被判 ✅ 假绿）；
  #      改为先用 `sed` 删掉**合规惯用法成分**，再对剩余文本做违规匹配（同例正确判 🔴）。
  #      已知边界：**跨行**书写的合规惯用法两法都会假红（豁免按行 ⇒ 无法覆盖），登记为已知限制。
  WL='stat[[:space:]]+-c[^|]*\|\|[[:space:]]*stat[[:space:]]+-f[^|]*'
  if printf '%s\n' "$SCAN" \
      | sed -E "s/$WL//g" \
      | grep -qE 'declare[[:space:]]+-A|mapfile|readarray|readlink[[:space:]]+-[fe]|\brealpath\b|stat[[:space:]]+-c|sed[[:space:]]+-i|grep[[:space:]]+-P|find[[:space:]].*-printf'; then
      # 报文补 file:line（第 6 轮）：初版只说"含…构造"却不给定位，与 NFR「失败须指名位置」冲突
      echo "🔴 新增行含 bash4-only / GNU-only 构造，命中位置："
      printf '%s\n' "$SCAN" | sed -E "s/$WL//g" \
          | grep -nE 'declare[[:space:]]+-A|mapfile|readarray|readlink[[:space:]]+-[fe]|\brealpath\b|stat[[:space:]]+-c|sed[[:space:]]+-i|grep[[:space:]]+-P|find[[:space:]].*-printf' >&2
      exit 1
  fi
  if printf '%s\n' "$SCAN" | grep -qE '(^|[^-[:alnum:]_])timeout[[:space:]]'; then
      { echo "🔴 新增行含 GNU-only timeout（须探测 gtimeout 或声明 Linux-only）"; exit 1; }
  fi
  #   ⑤ 语法门禁：对**被修改文件 + 新增文件**整文件 `bash -n`（语法错误与"哪一行引入"无关，必须整文件查）
  CHK=$( { git -c core.quotepath=false diff --name-only "$BASE" -- '*.sh'; printf '%s\n' "$NEWF"; } \
         | grep -E '\.sh$' | sort -u | grep -v '^$' || true)
  if [ -n "$CHK" ]; then
      while IFS= read -r fe; do
          [ -e "$fe" ] || continue          # 已删除的文件不交给 bash -n（实测删除态 rc=127 误报）
          bash -n "$fe" || { echo "🔴 $fe 语法错误"; exit 1; }
      done <<< "$CHK"
  fi
  ```
- **可观测性**: 两道新门禁失败时**必须指名具体文件/位置**（禁止只输出聚合计数 —— 本仓 `health-fix-2026-09` 已有先例：
  只报计数导致维护者无法处置）

## 依赖与假设

- **依赖**：`git`（`cat-file --batch-all-objects` 用于 P1 验证）、`shellcheck`、`bats-core`、`jq`（安装链路）
- **假设 1**：`origin/develop` 已为 `534e3e8`（重写后历史）—— 已实测确认，是 AC-3 不误拦 `develop` 的前提
- **假设 2**：`main` 与 `develop` 无共同祖先（`merge-base` rc=1）—— 已实测，故"拦截 `main` 的 push"
  不会影响 `develop` 的正常推送
- **假设 3**：`chisel` 替换不会与其它测试的期望字符串耦合 —— **待验证**（DESIGN/TASK 阶段需先
  `grep -rn chisel` 枚举全部消费方再替换）
- **假设 4（已撤回并更正 · L2 R7 证伪初版依据）**：初版称"PCSC 表的唯一语义源已裁决为
  `reference/pipeline-gates.md`"，**依据是误读** —— `phase-prompt-template.md:143` 说的是
  「已抽取：**Toll-gate 协议**（pipeline-gates.md）」，而紧邻的 **`:144` 明写**
  「⚠️ **结构性文档化（不抽取）**：**PCSC 表格** / 独立 review 调度 —— phase-specific 内容占比高，
  抽取反而增加复杂度」；`:145` 的未来方向也是**参数化 PCSC 表**，不是单源化。
  **更正后立场**：① PCSC 表**逐 phase 内容本就不应相同**（17 个载体），
  **不得**作为"应逐字一致"的比较对象，**移出 AR1/AC-4 范围**；
  ② AC-4 的比较对 `(P, S)` 由 **DESIGN 定义**，且须满足"两侧本应逐字一致"；
  ③ AR1（`pipeline-gates.md` ↔ `4-dev.md`）**降级**为：确认 toll-gate 协议段的引用一致性，
  不再主张"删内联 PCSC 表"
- **假设 5**：上游巡检的 🔴 **TC1（mock 自证）/ TC2（值盲视）** 与 TD-033/034 存在**严重度冲突**
  （巡检记 🔴，CONTEXT TD 记 🟡）—— 处置：两者是**同一组问题**的两种记法，
  以巡检 🔴 为准升级 TD-033/034，**但**因本 change 已含 TC3/TC4/TC5 三项测试修复，
  TC1/TC2 **显式留给 v2**（避免范围失控），并在「已知未闭环项」登记（L2 R9）

---

## 已知未闭环项（本次显式接受，禁止当成 bug 重报）

1. **对象库仍含 8 处 `/home/<acct>`** —— 因本地 `main` 未清理（用户决策）。
   `HISTORY-REWRITE-FULL.md:120` 的权威验证在 v1 结束后**仍为 8 ≠ 0**。已登记 v2。
2. **三处隐私安全网不存在** —— **按设计删除**（`:104` + L-110 ③），**非缺陷、勿重建**（已在 out 段锁定）。
3. **`unisoc` 存量 88 行 / 34 文件** —— 已声明残留（`HISTORY-REWRITE-FULL.md:136`），需产品决策"接受 or 改名"，本 change 不替用户决定。
4. **远端 GitHub 侧旧对象不可控** —— 强推后成不可达对象，服务端 gc 前按 SHA 可能短期可访问；
   `refs/pull/*` 若存在会继续固定。需向 GitHub Support 申请，**不在本机可控范围**（文档 `:128` 已自述）。
5. **上游巡检 TC1 / TC2（🔴）不在 v1** —— 见 v2 段；严重度以巡检 🔴 为准（假设 5），
   TD-033/034 待升级。**禁止**把"AC-4 改了 `check-gate-sync.sh` 判据"当作 TC2 已修的证据
   （两者改的是**同一文件的不同函数**）。
6. **TD-039（🔴 阻塞级 · dsh L2/L3 标题契约不一致）不在本 change 范围** —— 它是**本轮启用
   `gate_config=all` 后新发现的产品缺陷**（L3 门禁要求 `^## L2 盲审` 而官方 dsh 派发提示与固化
   prompt 均未要求 ⇒ `gate_config=both` 在 dsh 上到不了 L3）。已登记 CONTEXT **TD-039** + LESSONS **L-118**。
   **本轮会话的绕过方式**：L2 第 2 轮的派发参数里把段落标题设为 `## L2 盲审（第 2 轮）`（前缀即满足门禁）——
   这是**派发参数**而非手改审查文件，但**不构成修复**：固化 prompt 必须补该标题要求（TD-039 的 remedy ①）。
7. **`CONTEXT.md` 的"`grep eval` 应成为常设检查项"（L2 N6 → C6）——追溯不成立，已撤回原表述**：
   该段要求的是 `\beval\b` 的**常设门禁接线项**，而 AC-1 用的是**更窄的精确 pattern**
   且**本身不是门禁接线**（只是 AC 的验证方式）⇒ 第 2 轮所称"二者同一判据"**不准确**。
   已在 `.specs/health-fix-2026-09b/MINOR-DEFERRED.md` 登记 **TD-040**（区分"AC 级验证"与
   "常设门禁项入册"）。**本 change 不新增常设门禁项**（AC-1 的判据以验证方式形式存在）。

---

## 修复前实测行为（2026-09-22 · L-090 预检留档）

| AC | 判据命令 | 修复前实测 | 目标 | 有证明力 |
|---|---|---|---|---|
| AC-1 | `grep -rn '\beval\b' flow-kit-bundle/hooks/ \| wc -l` | **1**（`runtime-edit-guard.sh:46`） | 0 | ✅ |
| AC-1 | `grep -rEn '\$\([[:space:]]*eval[[:space:]]' flow-kit-bundle/ \| wc -l` ＋ `bash sync-hooks.sh --list \| grep -E '✅' \| awk '{print $2}'` 枚举 6 面 | **7 个面 = 7**（源树 1 + 6 DEST_ROOT，逐面各 1）—— **C3 订正：初版此格误记「8」，实测无任何命令产出 8** | 0 | ✅ |
| AC-1 | 粗 pattern `\beval\b`（**已废弃·仅存证**） | 4 路径 = **111**（噪声 104 来自 vendored brooks-lint 散文） | — | ❌ 不可用 |
| AC-1 | 分发归档面（C4 新增） | `dist/dsh-flow-kit-0.1.0.tgz` = **2** / `0.2.0.tgz` = **2** | 0 | ✅ |
| AC-2 | `grep -c mktemp flow-kit-bundle/lib/install_hooks.sh` | **0** | ≥1 | ✅ |
| AC-2 | 无 jq 时安装：`settings.json` 前后字节数（L2 已在 /tmp 沙箱 HOME 复现） | **122 B → 0 B**（jq rc=127）〔R10 口径：`CHANGE.md` 记 113 B 系**另一夹具**的同机制复现，两值非同一文件，均有效〕 | 字节与内容均不变 | ✅ |
| AC-2 | `grep -c 'command -v jq' flow-kit-bundle/lib/install_hooks.sh` | **1**（仅 `:211` 内联分支条件，非入口校验） | ≥2（入口+分支） | ✅ |
| AC-3 | 本地 `main` 可达对象含泄漏 | **8**（`main` 未配 upstream、无共同祖先） | 拦截生效 | ✅ |
| AC-4 | `bash check-gate-sync.sh; echo $?` | **1**（永久红） | 0 | ✅ |
| AC-4 | **真命令** `grep -c '^\| [0-9] \|'`（未转义，逐字可执行） | 实测 **352 / 549** —— ⚠️ **F5：此格原写"2/8"，那是被转义后的正则 `"^\| [0-9] \|"` 的结果（不可逐字执行）**；真命令证明比较对象**整体错位**（4-dev 的 352 行 vs flow-dev 的 549 行） | 比内容 | ✅ 结论不变，数值已订正 |
| AC-4 | `grep -c 'check-gate-sync' Makefile` | **1** —— ⚠️ **初版此格误记为 0**；实测唯一命中是 `Makefile:16` 的**注释**，`check:` 先决条件确实**未接线**（L2 R1） | 先决条件含该目标 | ✅（改用 `make -n check`） |
| AC-4 | `grep -n 'status.*-ne 2' test/test_check_gate_sync.bats` | **命中 `:30`**（容忍 exit 1） | `-eq 0` | ✅ |
| AC-5 | `grep -rc chisel flow-kit-bundle/test/` | **2 文件** | 0 | ✅ |
| AC-5 | 单文件 `tar xzOf dist/dsh-flow-kit-0.2.0.tgz \| grep -ac chisel` | **6** | 0 | ✅ |
| AC-5 | **glob 形态**（= 初版 AC 正文）`tar xzOf dist/dsh-flow-kit-*.tgz` | **0**（rc=2、stdout 空 —— **构造性假绿**，L2 R2） | 0 | ❌ 已废弃该形态 |
| AC-6 | `grep -c 'check-path-privacy' Makefile` | **0** | ≥1 | ✅ |
| AC-6 | `grep -cE 'path\|隐私\|leak' flow-kit-bundle/hooks/pre-commit/pre-commit.sh` | **0**（hook 内容只有 `make test`） | ≥1 | ✅ |
| AC-7 | `test_combined_metric.bats:32` 恒真断言 | **存在** `-eq 0 \|\| -eq 2` | 精确断言 | ✅ |
| AC-7 | `test_lessons_cleanup.bats` 的 **AC-4 测试**（按测试名定位，不引行号） | **存在** `skip` 调用（其上方注释为「暂时跳过」） | 去 skip 并断言 exit 0 | ✅ |
| AC-8 | `bats test/` | 973 ok / 0 not ok / 1 skip（**基线**） | ≥973 / 0 | ✅ |

> 结论：**全部 8 条 AC 在修复前均不成立**，无"测试了不存在的东西"的空 AC。
> 该预检同时暴露一处**范围张力**（已如实切分）：AC-3 的拦截与"权威验证 8→0"**不能同时作为 v1 的 AC** ——
> 后者需真正清理 `main`，属 v2。

---

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
