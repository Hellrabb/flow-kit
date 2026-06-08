#!/bin/bash
# flow-kit-bundle installer — one-command setup for new projects
# Usage:
#   bash install.sh /path/to/project          # specify project
#   bash install.sh                            # use current directory
#   bash install.sh --dry-run /path/to/project # preview without changes
set -euo pipefail

BUNDLE_DIR="$(cd "$(dirname "$0")" && pwd)"
DRY_RUN=false

# ── Parse args ─────────────────────────────────────────────────────
TARGET=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help)
      echo "Usage: bash install.sh [--dry-run] [/path/to/project]"
      echo "  --dry-run   Preview what would be installed"
      echo "  /path/to    Target project (default: current directory)"
      exit 0
      ;;
    *) TARGET="$1"; shift ;;
  esac
done

TARGET="${TARGET:-$PWD}"
TARGET="$(cd "$TARGET" 2>/dev/null && pwd || echo "$TARGET")"

if [[ ! -d "$TARGET" ]]; then
  echo "ERROR: Target directory does not exist: $TARGET"
  exit 1
fi

# ── Colors ─────────────────────────────────────────────────────────
G='\033[0;32m' Y='\033[1;33m' R='\033[0;31m' N='\033[0m'
info()  { echo -e "${G}[✓]${N} $1"; }
warn()  { echo -e "${Y}[!]${N} $1"; }
err()   { echo -e "${R}[✗]${N} $1"; }
dry()   { $DRY_RUN && echo -e "  ${Y}(dry-run)${N} $1" && return 0; }
step()  { echo -e "\n${G}── $1 ──${N}"; }

# ── Preflight ──────────────────────────────────────────────────────
echo "╔══════════════════════════════════════════════╗"
echo "║   flow-kit-bundle installer                  ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "  Bundle : $BUNDLE_DIR"
echo "  Target : $TARGET"
echo "  Mode   : $($DRY_RUN && echo 'DRY-RUN' || echo 'LIVE')"
echo ""

if ! $DRY_RUN; then
  read -rp "  Continue? [Y/n] " yn
  [[ -n "$yn" && "$yn" != "y" && "$yn" != "Y" ]] && exit 0
fi

# ── 1. flow-kit core ───────────────────────────────────────────────
step "1/6: flow-kit core → ${TARGET}/flow-kit/"
if [[ -d "$TARGET/flow-kit" ]]; then
  warn "flow-kit/ already exists, skipping (delete it first to reinstall)"
else
  if $DRY_RUN; then
    info "(dry-run) rsync $BUNDLE_DIR/flow-kit/ → $TARGET/flow-kit/"
  else
    rsync -a "$BUNDLE_DIR/flow-kit/" "$TARGET/flow-kit/"
    info "flow-kit/ installed ($(find "$TARGET/flow-kit" -type f | wc -l) files)"
  fi
fi

# ── 2. Hooks ───────────────────────────────────────────────────────
step "2/6: hooks → ${TARGET}/.claude/hooks/"
if $DRY_RUN; then
  info "(dry-run) cp hooks → $TARGET/.claude/hooks/"
else
  mkdir -p "$TARGET/.claude/hooks"
  cp -r "$BUNDLE_DIR/hooks/"* "$TARGET/.claude/hooks/"
  chmod +x "$TARGET/.claude/hooks/stop/"*.sh
  chmod +x "$TARGET/.claude/hooks/stop/lib/"*.sh
  chmod +x "$TARGET/.claude/hooks/session-start/"*.sh
  info "hooks installed ($(find "$TARGET/.claude/hooks" -type f | wc -l) files)"
fi

# ── 3. Skills (global) ─────────────────────────────────────────────
step "3/6: skills → ~/.claude/skills/"
GLOBAL_SKILLS="${HOME}/.claude/skills"
if $DRY_RUN; then
  info "(dry-run) cp skills → $GLOBAL_SKILLS/"
else
  # Relax error handling: skills install is non-critical
  set +e
  mkdir -p "$GLOBAL_SKILLS"
  count=0; skipped=0
  for skill_dir in "$BUNDLE_DIR/skills/"*/; do
    name=$(basename "$skill_dir")
    if [[ -d "$GLOBAL_SKILLS/$name" ]]; then
      rm -rf "$GLOBAL_SKILLS/$name" 2>/dev/null || true
    fi
    if cp -r "$skill_dir" "$GLOBAL_SKILLS/$name" 2>/dev/null; then
      ((count++))
    else
      warn "Could not install skill: $name (permission issue?)"
      ((skipped++))
    fi
  done
  info "$count skills installed ($skipped skipped)"
  set -e
fi

# ── 4. Stop hook config ────────────────────────────────────────────
step "4/6: stop-hook.json → ${TARGET}/.claude/stop-hook.json"
if [[ -f "$TARGET/.claude/stop-hook.json" ]]; then
  warn ".claude/stop-hook.json exists, skipping"
else
  if $DRY_RUN; then
    info "(dry-run) cp config/stop-hook.json"
  else
    mkdir -p "$TARGET/.claude"
    cp "$BUNDLE_DIR/config/stop-hook.json" "$TARGET/.claude/stop-hook.json"
    info "stop-hook.json installed"
  fi
fi

# ── 5. Settings.json hooks ─────────────────────────────────────────
step "5/6: hook wiring → ${TARGET}/.claude/settings.json"
SETTINGS="$TARGET/.claude/settings.json"
if $DRY_RUN; then
  info "(dry-run) merge hooks into settings.json"
elif [[ -f "$SETTINGS" ]]; then
  # Check if hooks already wired
  if jq -e '.hooks.Stop' "$SETTINGS" >/dev/null 2>&1; then
    warn "settings.json already has hooks.Stop, skipping merge"
    echo "  Manually verify against config/settings-hooks.json"
  else
    # Merge: keep existing settings, add hooks
    jq '. + {hooks: input.hooks}' "$SETTINGS" "$BUNDLE_DIR/config/settings-hooks.json" > "$SETTINGS.tmp"
    mv "$SETTINGS.tmp" "$SETTINGS"
    info "hooks merged into settings.json"
  fi
else
  # No settings.json yet, create one with hooks
  mkdir -p "$(dirname "$SETTINGS")"
  cp "$BUNDLE_DIR/config/settings-hooks.json" "$SETTINGS"
  info "settings.json created with hook wiring"
fi

# ── 6. RTK.md (global, optional) ───────────────────────────────────
step "6/6: RTK.md → ~/.claude/RTK.md (optional)"
RTK_TARGET="${HOME}/.claude/RTK.md"
if $DRY_RUN; then
  info "(dry-run) cp RTK.md → $RTK_TARGET"
elif [[ -f "$RTK_TARGET" ]]; then
  warn "~/.claude/RTK.md exists, skipping"
else
  cp "$BUNDLE_DIR/RTK.md" "$RTK_TARGET"
  info "RTK.md installed"
fi

# ── Summary ────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║   Installation $($DRY_RUN && echo 'plan (dry-run)' || echo 'complete')                         ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
[[ "$DRY_RUN" == true ]] && echo "  Run without --dry-run to install." && exit 0

echo "  Next steps:"
echo "  1. cd $TARGET && claude"
echo "  2. Type /flow-go"
echo "  3. If new project: let flow-kit run intel-scan"
echo "  4. Start building with /flow-go <your idea>"
echo ""

# ── Verify ─────────────────────────────────────────────────────────
echo "Verification:"
ok() { echo "  ✅ $1"; }
fail() { echo "  ❌ $1 — check manually"; }
[[ -d "$TARGET/flow-kit" ]] && ok "flow-kit/" || fail "flow-kit/"
[[ -f "$TARGET/.claude/hooks/stop/00-gate.sh" ]] && ok "hooks/stop/00-gate.sh" || fail "hooks/stop/"
[[ -d "$GLOBAL_SKILLS/flow-go" ]] && ok "skills/flow-go" || fail "skills/flow-go"
[[ -f "$TARGET/.claude/stop-hook.json" ]] && ok "stop-hook.json" || fail "stop-hook.json"
jq -e '.hooks.Stop' "$SETTINGS" >/dev/null 2>&1 && ok "settings.json hooks wired" || fail "settings.json hooks"
