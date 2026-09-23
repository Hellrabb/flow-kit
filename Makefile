# ============================================================================
# flow-kit 质量检查 Makefile
# 用法: make test | make lint | make check | make all
# ============================================================================
.PHONY: test lint check check-validate check-test-sync test-sync dup all hooks-sync check-hooks-sync verify-claims check-dist check-gate-sync check-path-privacy check-nfr-portability check-nfr-portability-internals dsh-sync

# ── test: 跑全量 bats 测试 ──
test:
	@echo "🧪 make test: running bats..."
	@npx bats test/ --formatter tap 2>&1 | tail -3
	@npx bats test/ > /dev/null 2>&1 && echo "✅ bats: all tests passed" || { echo "❌ bats: some tests failed"; exit 1; }

# ── lint: shellcheck 静态分析（仅 error 级别）──
# 检测改为 recipe 内 command -v（原 $(shell which) 在 RTK proxy 等环境下不稳定，会误报 not installed）
# 文件域（health-fix-2026-09 · T02）—— **理由**：原为手写 glob，漏掉 7 个生产脚本
#   （install.sh / pre-commit.sh / check-gate-sync.sh / 4×regression-demos/*/check.sh）。
#   改为 `find` 全量枚举，排除集见下方 SCAN_EXCLUDES（该列表是**契约**，
#   定义在 REQUIREMENT AC-4b；AC-4c 会检测「静默扩张排除项」）。
#   **为什么用 find 而不是补 glob**：补 glob 是打补丁，下次再加目录仍会漏 —— 判据过窄的复发模式。
# 门禁语义（ADR-010 · DESIGN D8）：**保持 error 级**，扩面只让 warning 可见，不升级为 fail。
#   理由：warning 池含 **22 处** SC1090（shellcheck 无法跟踪动态 `source`；本 change 扩面前为 21 处，
#   扩面 +1 属新增扫描文件的既有告警暴露，非新引入）等 known-acceptable，
#   升级会让门禁长期红 → 被绕过 → 可信度归零，比没有更糟。
# SCANNED_FILES 出口（REQUIREMENT AC-4 输出契约）：正常运行固定输出一行
#   `SCANNED_FILES: <n>` + 逐行 `./` 前缀路径 + 空行结束。验收脚本只解析该出口，
#   不复制枚举逻辑（否则等于把实现当判据）。**不得**改成 `--list-files` 形式
#   —— 那会被 make 当作 target 名，不是合法调用。
SCAN_EXCLUDES = -not -path './.git/*' -not -path '*/node_modules/*' \
                -not -path '*/brooks-lint/*' -not -path '*/brooks-tools/*' \
                -not -path '*/dist/*' -not -path '*/.omo/*' \
                -not -path '*/.claude/*' -not -path '*/.specs/*' -not -path '*/test/*'

lint:
	@echo "🔍 make lint: shellcheck (error level only)..."
	@SCAN_TMP=$$(mktemp); find . -name '*.sh' $(SCAN_EXCLUDES) | sort > $$SCAN_TMP; \
	printf 'SCANNED_FILES: %s\n' "$$(wc -l < $$SCAN_TMP)"; \
	cat $$SCAN_TMP; echo ""; \
	if ! command -v shellcheck >/dev/null 2>&1; then \
		echo "⚠️  WARNING: shellcheck not installed. Run: sudo apt-get install -y shellcheck"; \
		echo "   Skipping lint (non-blocking)."; \
		rm -f $$SCAN_TMP; \
	else \
		ERR=0; \
		while IFS= read -r f; do \
			[ -f "$$f" ] || continue; \
			OUT=$$(shellcheck -e SC1091 "$$f" 2>&1) || true; \
			ERRS=$$(echo "$$OUT" | grep -ci "error" || true); \
			if [ "$$ERRS" -gt 0 ]; then \
				echo "❌ $$f: $$ERRS error(s)"; \
				echo "$$OUT" | grep -i "error"; \
				ERR=1; \
			fi; \
		done < $$SCAN_TMP; \
		rm -f $$SCAN_TMP; \
		if [ "$$ERR" -eq 0 ]; then \
			echo "✅ shellcheck: no errors found"; \
		else \
			echo "❌ shellcheck: errors found (see above)"; \
			exit 1; \
		fi; \
	fi

# ── check-validate: 打包完整性校验 ──
# 双行模式（对齐 test target · TD-012 教训）：L1 装饰管道（tail 精简输出）+ L2 权威直判（exit code）
check-validate:
	@echo "📦 make check-validate: package staging coverage..."
	@bash package-flow-kit.sh --validate 2>&1 | tail -5
	@bash package-flow-kit.sh --validate > /dev/null 2>&1 && echo "✅ validate: staging coverage OK" || { echo "❌ validate: coverage check failed"; exit 1; }

# ── test-sync: 同步 test/ → flow-kit-bundle/test/ ──
test-sync:
	@echo "🔄 make test-sync: test/ → flow-kit-bundle/test/ ..."
	@if [ ! -d flow-kit-bundle/test ]; then \
		echo "❌ flow-kit-bundle/test/ 不存在"; exit 1; \
	fi
	@cp test/*.bats flow-kit-bundle/test/ && echo "✅ test 双源已同步" || { echo "❌ 同步失败"; exit 1; }

# ── check-test-sync: test 双源一致性 ──
check-test-sync:
	@echo "🔍 make check-test-sync: test/ ↔ flow-kit-bundle/test/ ..."
	@if [ ! -d flow-kit-bundle/test ]; then \
		echo "⚠️  flow-kit-bundle/test/ 不存在，跳过"; \
	else \
		diff -rq test/ flow-kit-bundle/test/ && echo "✅ test 双源一致" || { echo "❌ test/ 与 flow-kit-bundle/test/ 不一致！请运行 make test-sync"; exit 1; }; \
	fi

# ── hooks-sync: flow-kit-bundle/hooks/ → 各安装副本（B5 单一源 → N 副本）──
# 2026-09-17 §B5：~/.claude/hooks 曾停在 2026-09-03，缺 P0-1/P0-2 修复，
# 导致「同一 change 换条运行路径结论不同」。修完源务必跑这条。
hooks-sync:
	@echo "🔄 make hooks-sync: flow-kit-bundle/hooks/ → 安装副本 ..."
	@bash sync-hooks.sh

# ── check-hooks-sync: 副本漂移机器检查（只读 · 有漂移 exit 1）──
check-hooks-sync:
	@echo "🔍 make check-hooks-sync: hooks 副本漂移检测 ..."
	@bash sync-hooks.sh --check

# ── verify-claims: 对「响应段里的可验证声明」做机械复验（2-design 期 L2 盲审 的根因治理）──
# 载体动态枚举 + 计数现场复算，避免"只核对了 2/9 份载体"这类复验不可复算的问题。
verify-claims:
	@echo "🔎 make verify-claims: 逐条机械复验 ..."
	@bash verify-claims.sh

# ── check: 全量质量门禁 ──
check: test lint check-validate check-test-sync check-hooks-sync check-dist check-gate-sync check-path-privacy check-nfr-portability
	@echo ""
	@echo "╔════════════════════════════════════════════════════╗"
	@echo "║  ✅ make check: 全部通过                           ║"
	@echo "╚════════════════════════════════════════════════════╝"

# ── check-gate-sync: prompt↔skill toll-gate 协议一致性门禁（health-fix-2026-09 · AC-4）──
# 薄壳：判据由 flow-kit-bundle/flow-kit/reference/check-gate-sync.sh（T08 定稿）承载，
#   target 只负责接线进 check: 先决条件并暴露失败 rc。
# 边界（T14 / DESIGN D5）：只接线、不新建聚合目标；check-path-privacy 接线属 T18，不在此。
check-gate-sync:
	@echo "🔍 make check-gate-sync: prompt↔skill 协议一致性检查 ..."
	@bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh

# ── check-path-privacy: 路径隐私门禁（health-fix-2026-09b · AC-6）──
# 薄壳：判据由 flow-kit-bundle/flow-kit/reference/check-path-privacy.sh（T17 定稿）承载，
#   target 只负责接线进 check: 先决条件并暴露失败 rc。
# 二值退出（0=通过 / 1=清单外命中≠0 或 fail-closed）；常设允许清单 T21 落档前预期 rc=1。
# 边界（T18 / DESIGN §1 D8 F2）：NFR 可移植性判据另立 check-nfr-portability（T28），不在此。
check-path-privacy:
	@echo "🔍 make check-path-privacy: 路径隐私（允许清单外命中 / fail-closed）检查 ..."
	@bash flow-kit-bundle/flow-kit/reference/check-path-privacy.sh

# ── check-nfr-portability: NFR 兼容性判据（health-fix-2026-09b · AC-8 NFR 侧 · T28）──
# 设计依据：DESIGN §1 D8 F2（落点裁决）、§3 退出码模型、§9.3 包装契约；REQUIREMENT NFR 兼容性判据；
#   ADR-028 决策 3（三态 + make 层映射）。
# 为什么是 Makefile recipe 内联而非 .sh 脚本（D8 F2 自排除边界 · 强制）：
#   A 案受检面 = `git diff <base> -- '*.sh'` 的新增行 + 新 .sh 文件。判据文本必然含被禁原语字面
#   （mapfile / readlink / stat -c 都在它的 grep 模式里）⇒ 若落成仓内 .sh，它会检到自己而**永久假红**。
#   Makefile 不是 *.sh ⇒ 天然在受检面之外，无需豁免表。这是 D8 F2 的自排除边界。
# 两层结构（ADR-028 R1 + DESIGN §9.3）：
#   ① check-nfr-portability-internals —— 内部判据，三态 rc ∈ {0, 1, 3}，可单独调用、可被 verify 抽取原样实跑。
#      0=通过；1=失败（报文含 file:line）；3=未验证（SKIP：锚点缺失或变更集为空）。
#   ② check-nfr-portability —— 包装层，对外 rc ∈ {0, 1}：0=通过（含把内部 3 映射为 SKIP: + exit 0）；
#      1=失败（原样透传）。包装层**不得**泄漏 rc=3（泄漏即实现偏离 §9.3）。
#   ② 挂进 check: 先决条件是**安全的**：包装层恒为 0/1（rc=3 已在内部被映射为 0），不撞 ADR-028 R1
#   （R1 禁的是「三态判据直接挂进 check:」，包装层是二值 ⇒ 合规）。
# rc=3 的语义（ADR-028 决策 3 / DESIGN §9.3）：「未验证 ≠ 通过」。SKIP ≠ PASS。
#   在 make check 里 rc=3 经包装映射为「打印 SKIP: … 后 exit 0」⇒ 非阻塞但必须可见。
#   AC-8 断言（§9.3）：在锚点在位、变更集非空时，输出不得含 SKIP: —— 出现 SKIP 只能是实现缺陷。
# 受检面（A 案 · REQUIREMENT NFR 段 R3 裁决）：
#   ADDED = git diff -U0 "$BASE" -- '*.sh' 的 ^+ 行（剔除 +++ 头）
#   NEWF  = git ls-files -o --exclude-standard 的 .sh 文件（含未跟踪新增 —— L-107：--name-only 看不到）
#   变更集为空（ADDED 与 NEWF 均空）⇒ rc=3（SKIP：未验证，非通过）
# 注释行剔除（L-101 / L-128）：负向断言必须排除注释行，否则注释里提到该原语即假红。
#   剥离口径全仓统一：grep -vE '^\+?[[:space:]]*#'（剥整行注释）。
# 可移植惯用法豁免（REQUIREMENT 第 6 轮订正 · 按成分删除）：
#   stat -c … || stat -f … 是本仓既有的正确跨平台写法 ⇒ 不得判红。豁免**必须按成分删除而非整行豁免**
#   —— 整行豁免会让同行真违规一起逃逸（实测 mapfile …; t=$(stat -c … || stat -f …) 被判 ✅ 假绿）。
#   做法：先 sed 删掉合规惯用法成分，再对剩余文本做违规匹配。已知边界：跨行书写的合规惯用法会假红。
# 禁用构造（新增行/新文件命中即违规）：
#   declare -A / mapfile / readarray / readlink -f / readlink -e / realpath / sed -i / grep -P / find -printf / GNU timeout
# 语法门禁：对「被修改文件 + 新增文件」整文件 bash -n（语法错误与哪一行引入无关，必须整文件查）。
# 失败输出必须含 file:line 定位（NFR 可观测性 · REQUIREMENT）。
# 兼容性：recipe 以 `bash -c` 显式承载判据（macOS /bin/sh=bash3.2、Linux /bin/sh=dash 均可跑；
#   避免 dash 不支持 <<<、不支持 [[ 等扩展）。判据自身**不用** mapfile（避免自相矛盾 · REQUIREMENT R2③）。
check-nfr-portability-internals:
	@bash -euo pipefail -c ' \
		_write_rc() { [ -n "$${NFR_RC_FILE:-}" ] && printf "%s\n" "$$1" > "$$NFR_RC_FILE" || true; }; \
		_report_viol() { \
			_pat="$$1"; _hdr="$$2"; \
			_found=0; \
			for _f in $$(git -c core.quotepath=false diff --name-only "$$BASE" -- "*.sh" 2>/dev/null | grep -E "\.sh$$" || true); do \
				[ -e "$$_f" ] || continue; \
				_tf=$$(mktemp); \
				git -c core.quotepath=false diff -U0 "$$BASE" -- "$$_f" 2>/dev/null | awk -v FN="$$_f" -v P="$$_pat" -v TF="$$_tf" '\'' \
					BEGIN { c=0; found=0 } \
					/^@@/ { match($$0, /\+[0-9]+/); c = substr($$0, RSTART+1, RLENGTH-1)+0; next } \
					/^\+\+\+/ { next } \
					/^\+/ { \
						line = substr($$0, 2); \
						if (line ~ /^[[:space:]]*#/) { c++; next } \
						gsub(/stat[[:space:]]+-c[^|]*\|\|[[:space:]]*stat[[:space:]]+-f[^|]*/, "", line); \
						if (line ~ P) { printf "%s:%d:%s\n", FN, c, line > "/dev/stderr"; found=1 } \
						c++ \
					} \
					END { if (found) print "1" > TF } \
				'\''; \
				[ -s "$$_tf" ] && _found=1; \
				rm -f "$$_tf"; \
			done; \
			for _nf in $$(git -c core.quotepath=false ls-files -o --exclude-standard 2>/dev/null | grep -E "\.sh$$" || true); do \
				[ -e "$$_nf" ] || continue; \
				_hits=$$(awk -v P="$$_pat" '\'' \
					/^[[:space:]]*#/ { next } \
					{ l=$$0; gsub(/stat[[:space:]]+-c[^|]*\|\|[[:space:]]*stat[[:space:]]+-f[^|]*/, "", l); if (l ~ P) printf "%d:%s\n", NR, $$0 } \
				'\'' "$$_nf" 2>/dev/null || true); \
				if [ -n "$$_hits" ]; then \
					printf "%s\n" "$$_hits" | while IFS= read -r _h; do \
						_ln=$$(printf "%s" "$$_h" | sed -n "s/^\([0-9]*\):.*/\1/p"); \
						_rest=$$(printf "%s" "$$_h" | sed -n "s/^[0-9]*://p"); \
						printf "%s:%s:%s\n" "$$_nf" "$$_ln" "$$_rest" >&2; \
					done; \
					_found=1; \
				fi; \
			done; \
			[ "$$_found" = "1" ] && { printf "%s\n" "$$_hdr" >&2; return 0; } || return 1; \
		}; \
		BASE="$${FLOW_KIT_CHANGE_BASE:-$$(cat .specs/health-fix-2026-09b/.change-base 2>/dev/null || true)}"; \
		if [ -z "$$BASE" ]; then \
			echo "SKIP: 变更起点锚点缺失（.change-base 不存在且 \$$FLOW_KIT_CHANGE_BASE 未设）—— NFR 判据无法界定新增行，未验证"; \
			_write_rc 3; exit 0; \
		fi; \
		if ! git -c core.quotepath=false rev-parse --verify --quiet "$${BASE}^{commit}" >/dev/null 2>&1; then \
			echo "🔴 FLOW_KIT_CHANGE_BASE 不是有效 commit: $$BASE"; _write_rc 1; exit 0; \
		fi; \
		ADDED=$$(git -c core.quotepath=false diff -U0 "$$BASE" -- "*.sh" | grep -E "^\+" | grep -v "^+++" || true); \
		NEWF=$$(git -c core.quotepath=false ls-files -o --exclude-standard | grep -E "\.sh$$" || true); \
		if [ -z "$$ADDED" ] && [ -z "$$NEWF" ]; then \
			echo "SKIP: 相对 $$BASE 无 .sh 新增（未验证，非通过）"; _write_rc 3; exit 0; \
		fi; \
		BAN="declare[[:space:]]+-A|mapfile|readarray|readlink[[:space:]]+-[fe]|\\brealpath\\b|stat[[:space:]]+-c|sed[[:space:]]+-i|grep[[:space:]]+-P|find[[:space:]].*-printf"; \
		if _report_viol "$$BAN" "🔴 新增行含 bash4-only / GNU-only 构造，命中位置（file:line）："; then \
			_write_rc 1; exit 0; \
		fi; \
		TMOUT="(^|[^-[:alnum:]_])timeout[[:space:]]"; \
		if _report_viol "$$TMOUT" "🔴 新增行含 GNU-only timeout（须探测 gtimeout 或声明 Linux-only），命中位置（file:line）："; then \
			_write_rc 1; exit 0; \
		fi; \
		CHK=$$( { git -c core.quotepath=false diff --name-only "$$BASE" -- "*.sh"; printf "%s\n" "$$NEWF"; } \
			| grep -E "\.sh$$" | sort -u | grep -v "^$$" || true ); \
		if [ -n "$$CHK" ]; then \
			SYN_FAIL=0; \
			while IFS= read -r fe; do \
				[ -e "$$fe" ] || continue; \
				if ! bash -n "$$fe" 2>/dev/null; then \
					echo "🔴 $$fe 语法错误"; SYN_FAIL=1; \
				fi; \
			done <<< "$$CHK"; \
			[ "$$SYN_FAIL" -eq 0 ] || { _write_rc 1; exit 0; }; \
		fi; \
		echo "✅ NFR 兼容性判据通过：无新增 bash4-only / GNU-only 构造，语法检查通过"; \
		_write_rc 0; exit 0; \
	'

# ── check-nfr-portability: 包装层（ADR-028 决策 3 / DESIGN §9.3 三态转译）──
# 对外 rc ∈ {0, 1}：内部 rc=0 ⇒ 透传 0；内部 rc=3 ⇒ 打印 SKIP: 后 exit 0（非阻塞但可见，SKIP≠PASS）；
#   内部 rc=1 ⇒ 透传 1（阻塞）。**不得**泄漏 rc=3（泄漏即实现偏离 §9.3）。
# 挂进 check: 先决条件安全：包装层恒为 0/1（rc=3 已在内部映射为 0），不撞 ADR-028 R1。
# 技术细节：make 在 recipe 失败时对外恒返回 rc=2（掩盖内部真实 1/3）。故内部判据把真实 rc 写入
#   $$NFR_RC 临时文件，包装层读该文件还原三态 —— 不依赖 make 的退出码（否则 1/3 不可区分，§9.3 包装失败）。
check-nfr-portability:
	@echo "🔍 make check-nfr-portability: NFR 兼容性判据（bash 3.2/macOS 可移植 · 三态包装）..."
	@NFR_OUT=$$(mktemp); NFR_RC=$$(mktemp); \
	export NFR_RC_FILE="$$NFR_RC"; \
	bash -euo pipefail -c ' \
		_write_rc() { [ -n "$${NFR_RC_FILE:-}" ] && printf "%s\n" "$$1" > "$$NFR_RC_FILE" || true; }; \
		_report_viol() { \
			_pat="$$1"; _hdr="$$2"; \
			_found=0; \
			for _f in $$(git -c core.quotepath=false diff --name-only "$$BASE" -- "*.sh" 2>/dev/null | grep -E "\.sh$$" || true); do \
				[ -e "$$_f" ] || continue; \
				_tf=$$(mktemp); \
				git -c core.quotepath=false diff -U0 "$$BASE" -- "$$_f" 2>/dev/null | awk -v FN="$$_f" -v P="$$_pat" -v TF="$$_tf" '\'' \
					BEGIN { c=0; found=0 } \
					/^@@/ { match($$0, /\+[0-9]+/); c = substr($$0, RSTART+1, RLENGTH-1)+0; next } \
					/^\+\+\+/ { next } \
					/^\+/ { \
						line = substr($$0, 2); \
						if (line ~ /^[[:space:]]*#/) { c++; next } \
						gsub(/stat[[:space:]]+-c[^|]*\|\|[[:space:]]*stat[[:space:]]+-f[^|]*/, "", line); \
						if (line ~ P) { printf "%s:%d:%s\n", FN, c, line > "/dev/stderr"; found=1 } \
						c++ \
					} \
					END { if (found) print "1" > TF } \
				'\''; \
				[ -s "$$_tf" ] && _found=1; \
				rm -f "$$_tf"; \
			done; \
			for _nf in $$(git -c core.quotepath=false ls-files -o --exclude-standard 2>/dev/null | grep -E "\.sh$$" || true); do \
				[ -e "$$_nf" ] || continue; \
				_hits=$$(awk -v P="$$_pat" '\'' \
					/^[[:space:]]*#/ { next } \
					{ l=$$0; gsub(/stat[[:space:]]+-c[^|]*\|\|[[:space:]]*stat[[:space:]]+-f[^|]*/, "", l); if (l ~ P) printf "%d:%s\n", NR, $$0 } \
				'\'' "$$_nf" 2>/dev/null || true); \
				if [ -n "$$_hits" ]; then \
					printf "%s\n" "$$_hits" | while IFS= read -r _h; do \
						_ln=$$(printf "%s" "$$_h" | sed -n "s/^\([0-9]*\):.*/\1/p"); \
						_rest=$$(printf "%s" "$$_h" | sed -n "s/^[0-9]*://p"); \
						printf "%s:%s:%s\n" "$$_nf" "$$_ln" "$$_rest" >&2; \
					done; \
					_found=1; \
				fi; \
			done; \
			[ "$$_found" = "1" ] && { printf "%s\n" "$$_hdr" >&2; return 0; } || return 1; \
		}; \
		BASE="$${FLOW_KIT_CHANGE_BASE:-$$(cat .specs/health-fix-2026-09b/.change-base 2>/dev/null || true)}"; \
		if [ -z "$$BASE" ]; then \
			echo "SKIP: 变更起点锚点缺失（.change-base 不存在且 \$$FLOW_KIT_CHANGE_BASE 未设）—— NFR 判据无法界定新增行，未验证"; \
			_write_rc 3; exit 0; \
		fi; \
		if ! git -c core.quotepath=false rev-parse --verify --quiet "$${BASE}^{commit}" >/dev/null 2>&1; then \
			echo "🔴 FLOW_KIT_CHANGE_BASE 不是有效 commit: $$BASE"; _write_rc 1; exit 0; \
		fi; \
		ADDED=$$(git -c core.quotepath=false diff -U0 "$$BASE" -- "*.sh" | grep -E "^\+" | grep -v "^+++" || true); \
		NEWF=$$(git -c core.quotepath=false ls-files -o --exclude-standard | grep -E "\.sh$$" || true); \
		if [ -z "$$ADDED" ] && [ -z "$$NEWF" ]; then \
			echo "SKIP: 相对 $$BASE 无 .sh 新增（未验证，非通过）"; _write_rc 3; exit 0; \
		fi; \
		BAN="declare[[:space:]]+-A|mapfile|readarray|readlink[[:space:]]+-[fe]|\\brealpath\\b|stat[[:space:]]+-c|sed[[:space:]]+-i|grep[[:space:]]+-P|find[[:space:]].*-printf"; \
		if _report_viol "$$BAN" "🔴 新增行含 bash4-only / GNU-only 构造，命中位置（file:line）："; then \
			_write_rc 1; exit 0; \
		fi; \
		TMOUT="(^|[^-[:alnum:]_])timeout[[:space:]]"; \
		if _report_viol "$$TMOUT" "🔴 新增行含 GNU-only timeout（须探测 gtimeout 或声明 Linux-only），命中位置（file:line）："; then \
			_write_rc 1; exit 0; \
		fi; \
		CHK=$$( { git -c core.quotepath=false diff --name-only "$$BASE" -- "*.sh"; printf "%s\n" "$$NEWF"; } \
			| grep -E "\.sh$$" | sort -u | grep -v "^$$" || true ); \
		if [ -n "$$CHK" ]; then \
			SYN_FAIL=0; \
			while IFS= read -r fe; do \
				[ -e "$$fe" ] || continue; \
				if ! bash -n "$$fe" 2>/dev/null; then \
					echo "🔴 $$fe 语法错误"; SYN_FAIL=1; \
				fi; \
			done <<< "$$CHK"; \
			[ "$$SYN_FAIL" -eq 0 ] || { _write_rc 1; exit 0; }; \
		fi; \
		echo "✅ NFR 兼容性判据通过：无新增 bash4-only / GNU-only 构造，语法检查通过"; \
		_write_rc 0; exit 0; \
	' >"$$NFR_OUT" 2>&1 || true; \
	rc=$$(cat "$$NFR_RC" 2>/dev/null || echo 2); \
	case "$$rc" in \
		0) cat "$$NFR_OUT"; rm -f "$$NFR_OUT" "$$NFR_RC" ;; \
		3) cat "$$NFR_OUT"; rm -f "$$NFR_OUT" "$$NFR_RC"; exit 0 ;; \
		1) cat "$$NFR_OUT" 1>&2; rm -f "$$NFR_OUT" "$$NFR_RC"; exit 1 ;; \
		*) cat "$$NFR_OUT" 1>&2; rm -f "$$NFR_OUT" "$$NFR_RC"; exit 1 ;; \
	esac

# ── check-dist: 打包件新鲜度门禁（health-fix-2026-09 · F1/D2/D3）──
# 为什么存在：dist/ 被 .gitignore 忽略 → **git 对它结构性失明**，改了源忘了重建
#   不会被任何既有门禁发现。2026-09-20 即因此发出一份把「字节」写成「字符」的 README
#   （用户按 60000 "字符" 配置，实得 60000 字节 ≈ 2 万汉字，与预期差 3 倍）。
# 为什么放在 package-dsh-plugin.sh 里而不是新建脚本：比对映射必须与打包步骤**同源**，
#   另写一份会漂移（DESIGN D2 / R2 风险）。本 target 只是薄壳。
# 只读契约：`--check` 不重建、不改工作区、不调 node/npm。
# NFR 性能 ≤2s —— **实测 0.61s**（中位数 ×3，逐文件 cmp 遍历 534 文件）。
#   注：设计期曾据 4 条 `diff -rq` 估为 13ms，**低估了逐文件遍历开销**（差 47×）；
#   以实测 0.61s 为准（见 TEST.md §2 第 2 轮）。
check-dist:
	@echo "📦 make check-dist: 打包件新鲜度检查 ..."
	@bash package-dsh-plugin.sh --check

# ── dsh-sync: 把 dist 插件同步到已安装的 dsh profile（插件代码 + 文档 + vendor + 测试）──
# 为什么需要：`sync-hooks.sh` 只镜像 `hooks/**`（+ prompts 树），插件的 **lib/*.js**、`docs/`、
#   `vendor/`、`test/` 都不在其中 → 会静默漂移（2026-09-21 实测漂移 17 处，其中
#   `hook-bridge.js` 旧版仍会物化**项目级** stop-hook.json，属于行为级不一致）。
# 安全前提（已实测）：安装目录内容 = dist 内容（无额外文件）→ 可用 `rsync -a --delete`。
# ⚠️ 走 pnpm 的 `dsh plugin --profile <p> add file:.../dist/dsh-flow-kit` 会覆盖本目录，
#    之后重跑本 target 即可。
DSH_PROFILE ?= web
DSH_PLUGIN_DIR = $(HOME)/.dsh/profiles/$(DSH_PROFILE)/node_modules/dsh-flow-kit

dsh-sync: check-dist
	@echo "🔄 make dsh-sync: dist/dsh-flow-kit → $(DSH_PLUGIN_DIR) ..."
	@if [ ! -d "$(DSH_PLUGIN_DIR)" ]; then \
		echo "⚠️  未安装 dsh 插件（$(DSH_PLUGIN_DIR) 不存在）→ 跳过（exit 0）"; \
	else \
		rsync -a --delete "$(CURDIR)/dist/dsh-flow-kit/" "$(DSH_PLUGIN_DIR)/" && \
		echo "✅ 已同步（$(DSH_PROFILE) profile）· pnpm 重装后请重跑本 target"; \
	fi

# ── dup: jscpd 重复率扫描（独立 · 不进 check · jscpd 未装 graceful skip · TD-010）──
dup:
	@echo "📊 make dup: jscpd 重复率扫描（排除第三方 brooks-lint/brooks-tools/test/regression-demos）..."
	@if ! command -v jscpd >/dev/null 2>&1; then \
		echo "⚠️  jscpd 未装（非必需）。跳过 dup（exit 0）。" >&2; \
	else \
		jscpd flow-kit-bundle/ --ignore '**/brooks-lint/**,**/brooks-tools/**,**/test/**,**/regression-demos/**'; \
	fi

# ── all: alias for check ──
all: check
