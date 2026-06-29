# ============================================================================
# flow-kit 质量检查 Makefile
# 用法: make test | make lint | make check | make all
# ============================================================================
.PHONY: test lint check check-validate check-test-sync all

SHELLCHECK := $(shell which shellcheck 2>/dev/null)

# ── test: 跑全量 bats 测试 ──
test:
	@echo "🧪 make test: running bats..."
	@npx bats test/ --formatter tap 2>&1 | tail -3
	@npx bats test/ > /dev/null 2>&1 && echo "✅ bats: all tests passed" || { echo "❌ bats: some tests failed"; exit 1; }

# ── lint: shellcheck 静态分析（仅 error 级别）──
lint:
	@echo "🔍 make lint: shellcheck (error level only)..."
ifndef SHELLCHECK
	@echo "⚠️  WARNING: shellcheck not installed. Run: sudo apt-get install -y shellcheck"
	@echo "   Skipping lint (non-blocking)."
else
	@ERR=0; \
	for f in *.sh flow-kit-bundle/lib/*.sh flow-kit-bundle/hooks/stop/*.sh flow-kit-bundle/hooks/session-start/*.sh; do \
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
	fi
endif

# ── check-validate: 打包完整性校验 ──
check-validate:
	@echo "📦 make check-validate: package staging coverage..."
	@bash package-flow-kit.sh --validate 2>&1 | tail -5

# ── check-test-sync: test 双源一致性 ──
check-test-sync:
	@echo "🔍 make check-test-sync: test/ ↔ flow-kit-bundle/test/ ..."
	@if [ ! -d flow-kit-bundle/test ]; then \
		echo "⚠️  flow-kit-bundle/test/ 不存在，跳过"; \
	else \
		diff -rq test/ flow-kit-bundle/test/ && echo "✅ test 双源一致" || { echo "❌ test/ 与 flow-kit-bundle/test/ 不一致！请同步。"; exit 1; }; \
	fi

# ── check: 全量质量门禁 ──
check: test lint check-validate check-test-sync
	@echo ""
	@echo "╔════════════════════════════════════════════════════╗"
	@echo "║  ✅ make check: 全部通过                           ║"
	@echo "╚════════════════════════════════════════════════════╝"

# ── all: alias for check ──
all: check
