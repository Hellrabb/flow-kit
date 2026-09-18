# ============================================================================
# flow-kit 质量检查 Makefile
# 用法: make test | make lint | make check | make all
# ============================================================================
.PHONY: test lint check check-validate check-test-sync test-sync dup all hooks-sync check-hooks-sync verify-claims

# ── test: 跑全量 bats 测试 ──
test:
	@echo "🧪 make test: running bats..."
	@npx bats test/ --formatter tap 2>&1 | tail -3
	@npx bats test/ > /dev/null 2>&1 && echo "✅ bats: all tests passed" || { echo "❌ bats: some tests failed"; exit 1; }

# ── lint: shellcheck 静态分析（仅 error 级别）──
# 检测改为 recipe 内 command -v（原 $(shell which) 在 RTK proxy 等环境下不稳定，会误报 not installed）
# 覆盖补 pre-tool-use/（原漏扫 independent-review-gate.sh）
lint:
	@echo "🔍 make lint: shellcheck (error level only)..."
	@if ! command -v shellcheck >/dev/null 2>&1; then \
		echo "⚠️  WARNING: shellcheck not installed. Run: sudo apt-get install -y shellcheck"; \
		echo "   Skipping lint (non-blocking)."; \
	else \
		ERR=0; \
		for f in *.sh flow-kit-bundle/lib/*.sh flow-kit-bundle/hooks/stop/*.sh flow-kit-bundle/hooks/stop/lib/*.sh flow-kit-bundle/hooks/session-start/*.sh flow-kit-bundle/hooks/pre-tool-use/*.sh; do \
			[ -f "$$f" ] || continue; \
			OUT=$$(shellcheck -e SC1091 "$$f" 2>&1) || true; \
			ERRS=$$(echo "$$OUT" | grep -ci "error" || true); \
			if [ "$$ERRS" -gt 0 ]; then \
				echo "❌ $$f: $$ERRS error(s)"; \
				echo "$$OUT" | grep -i "error"; \
				ERR=1; \
			fi; \
		done; \
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
check: test lint check-validate check-test-sync check-hooks-sync
	@echo ""
	@echo "╔════════════════════════════════════════════════════╗"
	@echo "║  ✅ make check: 全部通过                           ║"
	@echo "╚════════════════════════════════════════════════════╝"

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
