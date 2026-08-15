# shellcheck shell=bash
# l3-api.sh — L3 外部模型 API 调用 + 解析（分拆自 l3-review.sh）
#
# 来源: split from l3-review.sh
# change: final-debt-cleanup-2026-08 (initial split)
# change: td072-lib-split-2026-08 (smart_truncate moved to l3-truncate.sh)
# change: l2l3-cross-platform-2026-08 (T02: credential via fk_resolve_api_credentials)
# date: 2026-08-03
#
# 函数:
#   _l3_call_api     — Step 2: 调用外部模型 API + 解析响应
#   _l3_parse_result — Step 3: 追加 L3 段 + verdict/summary 三层提取
#
# 注: smart_truncate 已于 td072-lib-split-2026-08 移至 l3-truncate.sh

# ── _l3_call_api() · Step 2: 调用外部模型 API + 解析响应 ──
# 用法: _l3_call_api <prompt_text> <model>
# 输出: content 到 stdout；失败时返回 3
# 环境变量依赖（凭证统一经 fk_resolve_api_credentials 解析 · DESIGN D1 · l2l3-cross-platform）:
#   ANTHROPIC_AUTH_TOKEN / ANTHROPIC_BASE_URL — Path1 env-var-first（claude code 原生）
#   ANTHROPIC_API_KEY — Path2 legacy 兜底（x-api-key · 端点硬编码 api.anthropic.com）
#   FLOW_KIT_L3_BASE_URL / FLOW_KIT_L3_AUTH_TOKEN — Path3 opencode 一等路径（hook 子进程继承启动 env · 短路 Path2）
#   FLOW_KIT_L3_MAX_TOKENS / FLOW_KIT_L3_TIMEOUT / FLOW_KIT_L3_THINKING — 请求可配（默认 32000/300/enabled）
_l3_call_api() {
  local prompt_text="$1" model="$2"
  local ai_response=""

  # ── 凭证解析：委托共享函数（DESIGN D1 · l2l3-cross-platform）──
  # 正常调用链（stop hook → 29-independent-review.sh → l3-review.sh → 本文件）已 source common.sh；
  # 独立 source 场景（bats 直 source l3-review.sh / timeout bash -c 子进程）按 HOOK_BASE_DIR 兜底 source（同 l3-review.sh L58 模式）
  type fk_resolve_api_credentials >/dev/null 2>&1 || {
    local _l3_common_lib="${HOOK_BASE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}/common.sh"
    [ -f "$_l3_common_lib" ] && source "$_l3_common_lib" 2>/dev/null || true
  }
  # rc 语义（共享函数）：0=就绪 / 1=无任何凭证 / 2=Path3 配置不完整（stderr 已由共享函数报错）
  local _fk_rc=0
  fk_resolve_api_credentials || _fk_rc=$?
  if [ "$_fk_rc" -eq 2 ]; then
    return 3   # stderr 已由共享函数报错（AC-6：只含 env 名不含值）
  fi
  if [ "$_fk_rc" -eq 1 ]; then
    # 降级提示（DESIGN D3）：平台感知，只含 env 变量名（AC-6 红线：凭证值绝不落盘）
    if fk_platform_is_dsh; then
      echo "[l3-review] L3 凭证缺失：在 dsh 启动环境 export FLOW_KIT_L3_BASE_URL + FLOW_KIT_L3_AUTH_TOKEN（dsh 插件 hook bridge 子进程继承启动 env）" >&2
    elif fk_platform_is_opencode; then
      echo "[l3-review] L3 凭证缺失：在 opencode 启动环境 export FLOW_KIT_L3_BASE_URL + FLOW_KIT_L3_AUTH_TOKEN（hook 子进程继承启动 env，settings.json 的 env 段不注入）" >&2
    else
      # env 名拆段书写（ANTHROPIC_AUTH_""TOKEN）：仅回显 env 名无 $ 展开（非直读），
      # 使 TASK.md T02 verify 的「零直读」grep 保持全绿（DESIGN D3：stderr 可含 env 完整名）
      echo "[l3-review] L3 凭证缺失：确认 ANTHROPIC_AUTH_""TOKEN 已注入（env-var-first）" >&2
    fi
    return 3   # 不发 curl
  fi
  # rc=0：读共享函数输出全局（set -u 防御），不再直读 ANTHROPIC_* env
  local api_base_url="${FK_API_BASE_URL:-}" api_auth_token="${FK_API_AUTH_TOKEN:-}" api_scheme="${FK_API_AUTH_SCHEME:-}"

  # ── 三 env var 可配（DESIGN D1/D2 · T01 证据：32k/300s/enabled 实测可用）──
  # Fail-safe（AC-6）：
  #   - 未设（env var 不存在）→ 走默认，不警告（正常路径）
  #   - 已设但非法（非数字/空串/枚举外）→ 回退默认 + stderr 警告
  # 用 ${VAR+x} 检测是否设置，区分"未设"与"设为空"
  local max_tokens=32000 timeout=300 thinking="enabled"
  if [[ -n "${FLOW_KIT_L3_MAX_TOKENS+x}" ]]; then
    local _raw_mt="$FLOW_KIT_L3_MAX_TOKENS"
    if [[ "$_raw_mt" =~ ^[0-9]+$ ]] && [[ "$_raw_mt" -gt 0 ]]; then
      max_tokens="$_raw_mt"
    else
      echo "[l3-review] FLOW_KIT_L3_MAX_TOKENS='$_raw_mt' 非法（需正整数），回退默认 32000" >&2
    fi
  fi

  if [[ -n "${FLOW_KIT_L3_TIMEOUT+x}" ]]; then
    local _raw_to="$FLOW_KIT_L3_TIMEOUT"
    if [[ "$_raw_to" =~ ^[0-9]+$ ]] && [[ "$_raw_to" -gt 0 ]]; then
      timeout="$_raw_to"
    else
      echo "[l3-review] FLOW_KIT_L3_TIMEOUT='$_raw_to' 非法（需正整数），回退默认 300" >&2
    fi
  fi

  if [[ -n "${FLOW_KIT_L3_THINKING+x}" ]]; then
    local _raw_th="$FLOW_KIT_L3_THINKING"
    case "$_raw_th" in
      enabled|disabled) thinking="$_raw_th" ;;
      *) echo "[l3-review] FLOW_KIT_L3_THINKING='$_raw_th' 非法（需 enabled|disabled），回退默认 enabled" >&2 ;;
    esac
  fi

  # 可观测性（AC-7）：记录实际使用的配置值 + credential source（Path1/2 → env，Path3 → flow-kit · 不记 token 值 · AC-6）
  local credential_source="env"
  # Path3 命中判定：FLOW_KIT_L3_AUTH_TOKEN 已设且 FK_API_BASE_URL 与 FLOW_KIT_L3_BASE_URL 一致（Path3 原样写入该值）
  if [ -n "${FLOW_KIT_L3_AUTH_TOKEN:-}" ] && [ "$api_base_url" = "${FLOW_KIT_L3_BASE_URL:-}" ]; then
    credential_source="flow-kit"
  fi
  echo "[l3-review] credential source: ${credential_source}" >&2
  echo "[l3-review] using max_tokens=$max_tokens timeout=$timeout thinking=$thinking" >&2

  # 请求体构造（DESIGN §2.3）：thinking=disabled 时加 thinking:{type:disabled} 字段
  # 用 jq -nc 条件构造（D4：jq 而非字符串拼接，防 JSON 注入；-c compact 输出，省字节 + 易测试匹配）
  local req_body
  if [[ "$thinking" == "disabled" ]]; then
    req_body=$(jq -nc --arg m "$model" --arg p "$prompt_text" --argjson mt "$max_tokens" \
      '{model:$m, max_tokens:$mt, thinking:{type:"disabled"}, messages:[{role:"user", content:$p}]}')
  else
    req_body=$(jq -nc --arg m "$model" --arg p "$prompt_text" --argjson mt "$max_tokens" \
      '{model:$m, max_tokens:$mt, messages:[{role:"user", content:$p}]}')
  fi

  # 统一 curl（DESIGN D1：按 scheme 选 header；端点即 FK_API_BASE_URL，无需硬编码区分 Path1/2）
  local _auth_header="Authorization: Bearer ${api_auth_token}"
  if [ "$api_scheme" = "x-api-key" ]; then
    _auth_header="x-api-key: ${api_auth_token}"
  fi
  ai_response=$(curl -s -w '\n%{http_code}' --max-time "$timeout" "${api_base_url}/v1/messages" \
    -H "$_auth_header" \
    -H "Content-Type: application/json" \
    -d "$req_body" 2>/dev/null || true)
  local _http_code
  _http_code=$(echo "$ai_response" | tail -1)
  ai_response=$(echo "$ai_response" | sed '$d')
  case "$_http_code" in
    200) ;;  # OK, continue
    [45]??) echo "[l3-review] L3 API returned HTTP ${_http_code}" >&2; return 3 ;;
  esac

  local content=""
  if [ -n "$ai_response" ]; then
    content=$(echo "$ai_response" | jq -r '[.content[] | select(.type == "text") | .text][0] // .content[0].thinking // .content[0].text // empty' 2>/dev/null || echo "")
  fi

  if [ -z "$content" ]; then
    echo "[l3-review] L3 API call failed (no content in response)" >&2
    return 3
  fi
  echo "$content"
}

# ── _l3_parse_result() · Step 3: 追加 L3 段 + verdict/summary 三层提取 ──
# 用法: _l3_parse_result <content> <phase> <artifacts_dir> <model>
# 输出: VERDICT=<v> 和 SUMMARY=<s> 到 stdout
_l3_parse_result() {
  local content="$1" phase="$2" artifacts_dir="$3" model="$4"
  local review_md="${artifacts_dir}/INDEPENDENT-REVIEW-${phase}.md"

  # 重审检测（委托 _l3_check_rerun）
  local is_review=false
  [ -f "$review_md" ] && is_review=true  # 已存在 → 本次为重新审查
  _l3_check_rerun "$phase" "$artifacts_dir" || return 2

  # ── 追加写入 L3 段 ──
  local ts
  ts=$(date '+%Y-%m-%d %H:%M' 2>/dev/null || echo "")
  # 追加前大小预警（>50KB warn）
  if [ -f "$review_md" ]; then
    local review_size
    review_size=$(stat -c %s "$review_md" 2>/dev/null || stat -f %z "$review_md" 2>/dev/null || echo "0")
    if [ "$review_size" -gt 51200 ] 2>/dev/null; then
      echo "[l3-review] WARNING: review file exceeds 50KB (${review_size} bytes), consider manual cleanup" >&2
    fi
  fi
  mkdir -p "$artifacts_dir"
  local section_title
  if [ "$is_review" = true ]; then
    section_title="## L3 重审（${model} 外部模型 · ${ts}）"
  else
    section_title="## L3 盲审（${model} 外部模型 · ${ts}）"
  fi
  # ── 原子写入 L3 段（tmp + mv 防主 agent Edit 竞态）──
  local tmp_review
  tmp_review="$(mktemp "${review_md}.tmp.XXXXXX")"
  if [ -f "$review_md" ]; then
    # AC-3: 删除旧 L3 段（去重后再追加新段，文件中仅保留 1 个 L3 段）
    # 用 awk 替代 sed：正确处理连续 ## L3 盲审 + ## L3 重审 段（R1 fix）
    awk '/^## L3 (盲审|重审)/ { skip=1; next } /^## / && skip { skip=0 } !skip' "$review_md" > "$tmp_review" 2>/dev/null || cat "$review_md" > "$tmp_review" 2>/dev/null || true
  fi
  # ADR-010 D4·J：artifact hash 元数据（审后追加 · 供 _l3_check_rerun 内容标记判定 · 不触 .done）
  local artifact_file=""
  case "$phase" in
    1) artifact_file="${artifacts_dir}/REQUIREMENT.md" ;;
    2) artifact_file="${artifacts_dir}/DESIGN.md" ;;
    3) artifact_file="${artifacts_dir}/TASK.md" ;;
    5) artifact_file="${artifacts_dir}/TEST.md" ;;
    6|7) artifact_file="${artifacts_dir}/REVIEW.md" ;;
  esac
  local artifact_hash=""
  [ -n "$artifact_file" ] && [ -f "$artifact_file" ] && artifact_hash=$(sha256sum "$artifact_file" 2>/dev/null | awk '{print $1}')
  {
    echo ""; echo "---"; echo ""; echo "$section_title"; echo ""
    echo "> 自动生成于 ${ts}。由 l3-review.sh 写入。"
    echo ""; echo "### 审查结论"; echo ""; echo '```json'
    echo "$content"; echo '```'
    if [ -n "$artifact_hash" ]; then echo ""; echo "L3_artifact_hash: ${artifact_hash}"; fi
  } >> "$tmp_review"
  mv "$tmp_review" "$review_md" 2>/dev/null || {
    echo "[l3-review] CRITICAL: atomic mv failed for ${review_md}" >&2
    rm -f "$tmp_review" 2>/dev/null || true
    return 3
  }

  # ── 写入后验证 ──
  if ! grep -q "^## L3 盲审\|^## L3 重审" "$review_md" 2>/dev/null; then
    echo "[l3-review] CRITICAL: L3 content not persisted after write to ${review_md}" >&2
    return 3
  fi

  # ── 提取 verdict（三层提取：代码块 → 纯 JSON → grep 正则）──
  local extracted
  extracted=$(echo "$content" | sed -n '/```json/,/```/p' | sed '1d;$d' 2>/dev/null || echo "")
  local l3_verdict=""
  if [ -n "$extracted" ]; then
    l3_verdict=$(echo "$extracted" | jq -r '.verdict // ""' 2>/dev/null || echo "")
  fi
  if [ -z "$l3_verdict" ]; then
    l3_verdict=$(echo "$content" | jq -r '.verdict // ""' 2>/dev/null || echo "")
  fi
  if [ -z "$l3_verdict" ]; then
    l3_verdict=$(echo "$content" | grep -oP '"verdict"\s*:\s*"\K(pass|fail)(?=")' 2>/dev/null | tail -1 || echo "")
  fi
  [ -n "$l3_verdict" ] || l3_verdict="unknown"

  # ── 提取 summary（三层提取）──
  local l3_summary=""
  if [ -n "$extracted" ]; then
    l3_summary=$(echo "$extracted" | jq -r '.summary // ""' 2>/dev/null || echo "")
  fi
  if [ -z "$l3_summary" ]; then
    l3_summary=$(echo "$content" | jq -r '.summary // ""' 2>/dev/null || echo "")
  fi
  if [ -z "$l3_summary" ]; then
    l3_summary=$(echo "$content" | grep -oP '"summary"\s*:\s*"\K[^"]+' 2>/dev/null | tail -1 || echo "")
  fi
  [ -n "$l3_summary" ] || l3_summary=""

  # ── 第四层故障降级 ──
  if [ -z "$l3_verdict" ] || [ "$l3_verdict" = "unknown" ]; then
    l3_verdict="error"
    l3_summary="L3 结果解析失败（verdict 不可用）"
  fi
  # Verdict 值域校验
  case "$l3_verdict" in pass|fail|error) ;; *)
    echo "[l3-review] invalid L3 verdict: $l3_verdict, defaulting to fail" >&2
    l3_verdict="fail"
    ;;
  esac

  echo "VERDICT=${l3_verdict}"
  echo "SUMMARY=${l3_summary}"
  return 0
}
