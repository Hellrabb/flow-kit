# ============================================================================
# flow-kit 质量检查 Makefile
# 用法: make test | make lint | make check | make all
# ============================================================================
.PHONY: test lint check check-validate check-test-sync test-sync dup all hooks-sync check-hooks-sync verify-claims check-dist check-gate-sync check-path-privacy dsh-sync

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
check: test lint check-validate check-test-sync check-hooks-sync check-dist check-gate-sync check-path-privacy
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
