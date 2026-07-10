# ============================================================================
# flow-kit 质量检查 Makefile
# 用法: make test | make lint | make check | make all
# ============================================================================
.PHONY: test lint check check-validate check-test-sync test-sync dup all

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
check-validate:
	@echo "📦 make check-validate: package staging coverage..."
	@bash package-flow-kit.sh --validate 2>&1 | tail -5

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

# ── check: 全量质量门禁 ──
check: test lint check-validate check-test-sync
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
