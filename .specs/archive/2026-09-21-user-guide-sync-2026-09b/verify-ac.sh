#!/usr/bin/env bash
# verify-ac.sh — AC-1..AC-8 的机械断言矩阵（user-guide-sync-2026-09b · 阶段 5 TEST）
#
# 用法：bash .specs/user-guide-sync-2026-09b/verify-ac.sh
# 判据：
#   反例（NEG）= 在**四份副本各自**都必须 0 命中
#   正例（POS）= 在**四份副本各自**都必须 ≥1 命中
#   字面匹配（grep -F），避免正则元字符误伤
set -uo pipefail
# 仓库根解析（v4.7）：逐级上溯找 package-dsh-plugin.sh —— 兼容 .specs/<id>/ 与 .specs/archive/<date>-<id>/ 两种落点
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
while [ "$ROOT_DIR" != "/" ] && [ ! -f "$ROOT_DIR/package-dsh-plugin.sh" ]; do ROOT_DIR="$(dirname "$ROOT_DIR")"; done
[ -f "$ROOT_DIR/package-dsh-plugin.sh" ] || { echo "❌ 未能定位仓库根（脚本：${BASH_SOURCE[0]}）" >&2; exit 2; }
cd "$ROOT_DIR" || exit 2

GUIDE="FLOW-KIT-用户指南.md"
COPIES=(
  "$GUIDE"
  "flow-kit-bundle/$GUIDE"
  "dist/dsh-flow-kit/docs/$GUIDE"
  "dist/dsh-flow-kit/vendor/flow-kit-bundle/$GUIDE"
)

PASS=0; FAIL=0
declare -A AC_PASS=() AC_FAIL=()   # v4.4：按 AC 分段计数，供 REPORT/REVIEW 直接引用（数字不再手抄）
declare -a FAILED_LINES=()

# 只对存在的副本断言（dist 缺席时按 DESIGN D2 的降级口径跳过该副本）
present_copies() {
  local c
  for c in "${COPIES[@]}"; do [ -f "$c" ] && printf '%s\n' "$c"; done
}

neg() { # <AC> <描述> <字面串>
  local ac="$1" desc="$2" pat="$3" c n bad=0
  while IFS= read -r c; do
    n="$(grep -cF -- "$pat" "$c" || true)"
    [ "$n" = "0" ] || { bad=1; FAILED_LINES+=("$ac 反例 残留($n) [$c]: $desc :: $pat"); }
  done < <(present_copies)
  if [ "$bad" = 0 ]; then PASS=$((PASS+1)); AC_PASS[$ac]=$(( ${AC_PASS[$ac]:-0} + 1 )); else FAIL=$((FAIL+1)); AC_FAIL[$ac]=$(( ${AC_FAIL[$ac]:-0} + 1 )); fi
}

pos() { # <AC> <描述> <字面串>
  local ac="$1" desc="$2" pat="$3" c n bad=0
  while IFS= read -r c; do
    n="$(grep -cF -- "$pat" "$c" || true)"
    [ "$n" -ge 1 ] || { bad=1; FAILED_LINES+=("$ac 正例 未命中 [$c]: $desc :: $pat"); }
  done < <(present_copies)
  if [ "$bad" = 0 ]; then PASS=$((PASS+1)); AC_PASS[$ac]=$(( ${AC_PASS[$ac]:-0} + 1 )); else FAIL=$((FAIL+1)); AC_FAIL[$ac]=$(( ${AC_FAIL[$ac]:-0} + 1 )); fi
}

echo "## 断言矩阵实跑（verify-ac.sh · $(date -Iseconds)）"
echo
echo "副本集合（存在者参与断言）："
present_copies | sed 's/^/  - /'
echo

# ── AC-2 · 14 条 🔴 ──
echo "### AC-2 · 14 条 🔴（反例 = 0 / 正例 ≥1 · 四份同验）"
neg AC-2 "D01 旧 --global 口径"      '核心引擎 + skills + brooks-lint + hooks'
pos AC-2 "D01 brooks-tools"          'brooks-tools'
pos AC-2 "D01 需再加 --user"          '需再加 `--user`'
neg AC-2 "D08 sub-goal flag"         '--sub-goal-4'
pos AC-2 "D08 SUB_GOAL_4"            'SUB_GOAL_4'
neg AC-2 "D09 lessons 目录"          '.specs/lessons/'
pos AC-2 "D09 LESSONS 单文件"        '.specs/LESSONS.md'
neg AC-2 "D10 ARCHIVE.md"            'ARCHIVE.md'
pos AC-2 "D10 UAT.md"                'UAT.md'
pos AC-2 "D10 归档路径占位"           'archive/<YYYY-MM-DD>-<change-id>/'
neg AC-2 "D11 三轮审查"              '三轮审查'
pos AC-2 "D11 单轮合并审查"          '单轮合并审查'
neg AC-2 "D16 项目根 ARCHITECTURE"   '项目根 `ARCHITECTURE.md`'
pos AC-2 "D16 .specs/ARCHITECTURE"   '.specs/ARCHITECTURE.md'
neg AC-2 "D19 auto_checkpoint 键"    'pre_tool_use_gates.auto_checkpoint'
pos AC-2 "D19 占位块未消费"          '占位块'
pos AC-2 "D19 代码未消费"            '代码未消费'
neg AC-2 "D20 旧兜底措辞"            '此字段仅作末级兜底'
pos AC-2 "D20 已废弃"                '已废弃'
pos AC-2 "D20 l3-default="           'l3-default='
neg AC-2 "D21 握手文件"              '.flow-active.independent-review'
pos AC-2 "D21 done 锚点"             '.independent-review-<phase>.done'
neg AC-2 "D22 允许手动绕过"          '允许手动绕过'
neg AC-2 "D22 手动 touch"            '手动 touch done'
pos AC-2 "D22 自动 bypass 语义"      '熔断降级（自动）'
pos AC-2 "D22 由子系统自动"            '由子系统自动'
pos AC-2 "D22 skipped 审计段"        'L3_verdict=skipped'
neg AC-2 "D23 仅 Bash matcher"       'matcher: `Bash`，gate_config'
pos AC-2 "D23 matcher 扩面"          'Bash|Write|Edit'
pos AC-2 "D23 path-guard"            'path-guard'
neg AC-2 "D31 随 bundle 分发"        '随 flow-kit bundle 分发'
pos AC-2 "D31 不由 bundle 分发"      '不由 flow-kit bundle 分发'
neg AC-2 "D33 旧值域整行"            '| `independent` / `true` / `off` / `false` |'
pos AC-2 "D33 both"                  '`both`'
pos AC-2 "D33 L2 档"                 '`L2`'
pos AC-2 "D33 L3 档"                 '`L3`'
neg AC-2 "D34 项目级配置源"          '编辑 .claude/stop-hook.json'
pos AC-2 "D34 dsh 用户级路径"        '~/.dsh/stop-hook.json'
pos AC-2 "D34 opencode 用户级路径"   '~/.config/opencode/stop-hook.json'

# ── AC-3 · 🟡/🟢 有旧措辞者 ──
echo
echo "### AC-3 · 过期项（反例 = 0 / 正例 ≥1）"
neg AC-3 "D03 hooks-only 旧口径"     '仅安装 hooks（需配合 --project）'
pos AC-3 "D03 hooks+specs 模板"      '仅安装 hooks + `.specs/STATE.md` 模板'
neg AC-3 "D04 旧首选更新路径"        '执行 `dsh plugin --profile <profile 名> update dsh-flow-kit`'
pos AC-3 "D04 make dsh-sync"         'make dsh-sync'
neg AC-3 "D12 旧 TASK 模板"          '<title>任务标题</title>'
pos AC-3 "D12 新 TASK 字段"          '<write_files>'
neg AC-3 "D13 波次语义写反"          '只在同波次内'
pos AC-3 "D13 波次语义纠正"          '同波次内不应有'
pos AC-3 "D13 跨波次声明"            '跨波次必须显式声明'
neg AC-3 "D14 Major 分级"            '🔴 Critical / 🟡 Major / 🟢 Minor'
pos AC-3 "D14 Important"             'Important'
neg AC-3 "D18 M-health 旧档位"       '- **标准**（默认）：全维诊断'
pos AC-3 "D18 快速体检"              '快速体检'
pos AC-3 "D18 完整审计"              '完整审计'
pos AC-3 "D18 单维深挖"              '单维深挖'
# D26：段落级断言 —— SessionStart 段内必须出现 archive-uncommitted（全文件级 grep 改前即绿，无效）
d26_bad=0
while IFS= read -r c; do
  if ! awk '/^### SessionStart Hook/{f=1} f&&/^### /&&!/^### SessionStart Hook/{f=0} f' "$c" | grep -qF 'archive-uncommitted'; then
    d26_bad=1; FAILED_LINES+=("AC-3 D26 段落级未命中（SessionStart 段）[$c]")
  fi
done < <(present_copies)
if [ "$d26_bad" = 0 ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi
neg AC-3 "D30 假 config 键"          '"31-auto-advance": true'
# ── v4.5 · 阶段 3 L2 R7：附录 A 中此前无任何脚本断言的锚点（D02/D05/D06/D07/D15/D17/D28/D35/D39/D40）──
pos AC-3 "D02 --platform"            '--platform'
pos AC-3 "D02 --no-brooks-tools"     '--no-brooks-tools'
pos AC-3 "D02 --self-test"           '--self-test'
pos AC-3 "D02 --brooks-src"          '--brooks-src'
pos AC-3 "D02 --yes"                 '--yes'
pos AC-3 "D02 配置仍走用户级"         '配置仍走用户级'
pos AC-3 "D05 插件版本"               'v0.2.0'
pos AC-3 "D06 goal 字段示例"          '"goal": {'
pos AC-3 "D07 gate-config 子命令"     '/flow gate-config'
pos AC-3 "D07 l2-review 子命令"       '/flow l2-review'
pos AC-3 "D15 归档后未提交"           '归档后是否仍有未提交变更'
pos AC-3 "D17 restyle 旧→新"          'restyle-<old>-to-<new>'
pos AC-3 "D17 restyle-vN"             'restyle-v<N>'
pos AC-3 "D28 written_by 键"          'written_by'
pos AC-3 "D28 L2_verdict 键"          'L2_verdict'
pos AC-3 "D28 artifacts 键"           'artifacts'
pos AC-3 "D35 只放运行时状态"         '只放运行时状态'
pos AC-3 "D35 不再生成也不再读取"      '不再生成也不再读取'
pos AC-3 "D39 PROGRESS.md"            'PROGRESS.md'
pos AC-3 "D39 MINOR-DEFERRED"         'MINOR-DEFERRED.md'
pos AC-3 "D39 审查报告命名"           'INDEPENDENT-REVIEW-'
pos AC-3 "D40 ~/.local/bin"           '~/.local/bin'
pos AC-3 "D40 brooks-tools shim"      'brooks-tools shim'
pos AC-3 "D30 31 号驱动源"            '31 号由 `goal.auto_advance` 驱动'
pos AC-3 "D32 skill 文件"            'skill 文件'
pos AC-3 "D32 生成工程结构"           '生成的 deck 工程结构'
neg AC-3 "D43 旧分节日期"            '最后同步日期**: 2026-07-13'
pos AC-3 "D43 新分节日期"            '最后同步日期**: 2026-09-21'
# D43 的正则在 AC-1 段用 grep -E 单独断言（字面 grep -F 不成立，见 AC 表标注 regex:）
pos AC-3 "D41 预设名补全"            'requirement-review'
pos AC-3 "D41 预设名补全2"           'spec-test'
pos AC-3 "D41 预设名补全3"           'task-test'
pos AC-3 "D29 Tier1 真实性校验"       'Tier1'
pos AC-3 "D29 Tier2 交叉比对"         'Tier2'
pos AC-3 "D29 六行门槛"               '≥6 行'
pos AC-3 "D37 l3-api.sh"             'l3-api.sh'
pos AC-3 "D37 l3-done.sh"            'l3-done.sh'
pos AC-3 "D37 l3-prompt.sh"          'l3-prompt.sh'
pos AC-3 "D37 l3-section.sh"         'l3-section.sh'
pos AC-3 "D37 l3-truncate.sh"        'l3-truncate.sh'
pos AC-3 "D37 runtime-adapter.sh"    'runtime-adapter.sh'
pos AC-3 "D37 gate-helpers.sh"       'gate-helpers.sh'
pos AC-3 "D38 gate-checks-review"    'gate-checks-review.sh'
pos AC-3 "D36 配置不在项目里"         '配置不在项目里'

# ── AC-1 · 日期口径 ──
echo
echo "### AC-1 · 版本与日期口径"
neg AC-1 "旧版本号"                  '20260713'
neg AC-1 "旧日期"                    '2026-07-13'
pos AC-1 "版本行"                    '> 版本: 2026-09-21'
pos AC-1 "分节日期"                  '最后同步日期**: 2026-09-21'
# regex 口径（AC 表标注 regex: 的两条）
while IFS= read -r c; do
  grep -qE '^> 版本: 2026-09-21' "$c" || { FAIL=$((FAIL+1)); FAILED_LINES+=("AC-1 regex 版本行未命中 [$c]"); }
  grep -qE '最后同步日期\*\*: 2026-09-21' "$c" || { FAIL=$((FAIL+1)); FAILED_LINES+=("AC-1 regex 分节日期未命中 [$c]"); }
done < <(present_copies)
c_bad=0
while IFS= read -r c; do
  n="$(grep -n '2026-09-03' "$c" | grep -vc '2026-09-03 起' || true)"
  [ "$n" = "0" ] || { c_bad=1; FAILED_LINES+=("AC-1 2026-09-03 出现在非历史句 [$c]: $n 处"); }
done < <(present_copies)
if [ "$c_bad" = 0 ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# ── AC-4 · 新增项锚点（N1–N11 的用户可见串）──
echo
echo "### AC-4 · 候选新增项（N1–N13）"
pos AC-4 "N1 凭证 env"               'FLOW_KIT_L3_AUTH_TOKEN'
pos AC-4 "N1 claude 凭证"            'ANTHROPIC_AUTH_TOKEN'
pos AC-4 "N1 模板"                   'l3.env'
pos AC-4 "N1 死锁后果"               '死锁'
pos AC-4 "N2 工件上限键"             'max_artifact_bytes'
pos AC-4 "N2 默认值"                 '80000'
pos AC-4 "N3 check-dist"             'check-dist'
pos AC-4 "N3 check-validate"         'check-validate'
pos AC-4 "N3 check-test-sync"        'check-test-sync'
pos AC-4 "N4 check-hooks-sync"       'check-hooks-sync'
pos AC-4 "N5 dsh-sync"               'make dsh-sync'
pos AC-4 "N5 DSH_PROFILE"            'DSH_PROFILE'
pos AC-4 "N6 verify-claims"          'verify-claims'
# N13 三平台口径（兼容性 NFR 的 AC 落点 · v4.2）
pos AC-4 "N13 claude 配置路径"        '~/.claude/stop-hook.json'
pos AC-4 "N13 dsh 配置路径"           '~/.dsh/stop-hook.json'
pos AC-4 "N13 opencode 配置路径"      '~/.config/opencode/stop-hook.json'
pos AC-4 "N7 l2-review"              '/flow l2-review'
pos AC-4 "N8 runtime-edit-guard"     'runtime-edit-guard'
pos AC-4 "N9 path-guard"             'path-guard'
pos AC-4 "N10 ADR-025"               'ADR-025'
pos AC-4 "N10 前轮反馈（后果句）"      '前轮反馈'
pos AC-4 "N11 ADR-026"               'ADR-026'
pos AC-4 "N11 不可信（后果句）"        '不可信'
# N1 安全反例：不得写入真实 token 形态（干净 → 计 PASS；命中 → 计 FAIL）
sec_bad=0
while IFS= read -r c; do
  if grep -nE '(sk-[A-Za-z0-9]{8,}|AUTH_TOKEN=.{16,})' "$c" >/dev/null 2>&1; then
    sec_bad=1; FAILED_LINES+=("AC-4 安全反例 命中疑似真实凭证 [$c]")
  fi
done < <(present_copies)
# v4.5 · 阶段 5 L3：安全反例**扩到凭证模板与三棵树**（精化模式排除 shell 变量引用，
# 否则 `AUTH_TOKEN="${ANTHROPIC_AUTH_TOKEN}"` 这类正常代码会被误报）
CRED_SCAN_PATHS=( ".claude/l3.env.example" "flow-kit-bundle" "dist/dsh-flow-kit" "dsh-flow-kit" )
cred_hits=0
for p in "${CRED_SCAN_PATHS[@]}"; do
  [ -e "$p" ] || continue
  h=$(grep -rlE "(AUTH_TOKEN=['\"]?[A-Za-z0-9_-]{20,}|sk-[A-Za-z0-9]{20,})" "$p" 2>/dev/null | wc -l)
  cred_hits=$((cred_hits + h))
done
[ "$cred_hits" = "0" ] || { sec_bad=1; FAILED_LINES+=("AC-4 安全反例：凭证模板/树内发现 $cred_hits 个疑似真实凭证形态文件"); }
if [ "$sec_bad" = 0 ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

echo
echo "### 分段计数（按 AC · 供 REPORT/REVIEW 直接引用）"
for k in AC-1 AC-2 AC-3 AC-4; do
  printf '  %-6s 通过 %-3s 失败 %s\n' "$k" "${AC_PASS[$k]:-0}" "${AC_FAIL[$k]:-0}"
done
echo
echo "### 结果"
echo "- 参与副本：$(present_copies | wc -l) 份（每条断言对**每一份存在的副本**各判一次）"
echo "- 段外单元：3（AC-1 regex 版本行/分节日期 合 1 · AC-1「2026-09-03 仅历史句」1 · AC-4 安全反例 1）——分段计数之和不含这 3 项"
echo "- 断言通过：$PASS"
echo "- 断言失败：$FAIL"
if [ "${#FAILED_LINES[@]}" -gt 0 ]; then
  echo
  echo "#### 失败明细"
  printf -- '- %s\n' "${FAILED_LINES[@]}"
fi
[ "$FAIL" = "0" ]
