#!/usr/bin/env bash
# Copilot CLI preToolUse hook — [T0-3] force-push 前置攔截（可 deny）
# 契約（自 CLI 1.0.70 bundle app.js 逐字驗證）：
#   stdin : {"sessionId","timestamp","cwd","toolName","toolArgs"}
#   stdout: {"permissionDecision":"deny","permissionDecisionReason":"..."} 攔截；無輸出＝放行
# 攔截 command literal 可判定的非 lease force／mirror；lease 只放行完整拼寫 + 明示 remote +
# 單一非保護 refspec 的 canonical 形狀。一般 push（含 main／--all）放行。
# Ceiling：不解析 Git config 的 remote.*.push／mirror 或 runtime shell expansion；由 repo pre-push、
# Tier 0 與 CI 疊加防護。
set -ufo pipefail

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '"%s"' "$s"
}

deny() {
  printf '{"permissionDecision":"deny","permissionDecisionReason":%s}\n' "$(json_escape "$1")"
  exit 0
}

INPUT="$(cat)"
SCAN_INPUT=${INPUT//$'\\\n'/}
SCAN_INPUT=${SCAN_INPUT//\"/}
SCAN_INPUT=${SCAN_INPUT//\'/}
SCAN_INPUT=${SCAN_INPUT//\\/}
SCAN_INPUT=${SCAN_INPUT//\$/}
SCAN_INPUT=${SCAN_INPUT//\(/}
SCAN_INPUT=${SCAN_INPUT//\)/}
parse_failure() {
  case "$SCAN_INPUT" in
    *git*push*) deny "[T0-3] jq 不可用或 payload 解析失敗，無法判定 push 目標，保守拒絕。請確認 jq 已安裝且在 PATH 中。" ;;
  esac
  exit 0
}

JQ="$(command -v jq 2>/dev/null || true)"
[ -n "$JQ" ] || parse_failure
printf '%s' "$INPUT" | "$JQ" -e 'type == "object"' >/dev/null 2>&1 || parse_failure
TOOL=$(printf '%s' "$INPUT" | "$JQ" -er '.toolName | select(type == "string" and length > 0)' 2>/dev/null) || parse_failure
case "$TOOL" in bash|shell|Bash) ;; *) exit 0 ;; esac

# toolArgs 可能是物件或 JSON 字串；兩者都必須解析成含 string command 的 object。
CMD=$(printf '%s' "$INPUT" | "$JQ" -er '
  .toolArgs
  | if type == "string" then fromjson else . end
  | if type == "object" then . else error("toolArgs must be object") end
  | .command
  | select(type == "string" and length > 0)
' 2>/dev/null) || parse_failure
SCAN_CMD=${CMD//$'\\\n'/}
SCAN_CMD=${SCAN_CMD//\"/}
SCAN_CMD=${SCAN_CMD//\'/}
SCAN_CMD=${SCAN_CMD//\\/}
SCAN_CMD=${SCAN_CMD//\$/}
SCAN_CMD=${SCAN_CMD//\(/}
SCAN_CMD=${SCAN_CMD//\)/}
case "$SCAN_CMD" in *git*push*) ;; *) exit 0 ;; esac
check_target() {
  case "$1" in
    :|*\**) deny "[T0-3] --force-with-lease 搭配 matching／wildcard refspec 無法排除保護分支，已保守拒絕。" ;;
  esac
  local target="${1##*:}"
  target="${target#refs/heads/}"
  [ -n "$target" ] || deny "[T0-3] --force-with-lease 的 refspec target 為空，無法排除保護分支，已保守拒絕。"
  if [ "$target" = @ ] || ! git check-ref-format --branch "$target" >/dev/null 2>&1; then
    deny "[T0-3] --force-with-lease 必須使用明確 branch ref，不接受 HEAD／@／revision shorthand。"
  fi
  case "$target" in
    main|master) deny "[T0-3] 禁止 force push（含 --force-with-lease）到 main/master。" ;;
  esac
}

check_seg() {
  local seg="$1" t
  local IFS=$' \t\n'
  local -a toks=() args=()
  read -r -a toks <<< "$seg"
  local i seen_git=0 seen_push=0 has_force=0 has_lease=0 lease_exact=0 other_option=0
  for ((i = 0; i < ${#toks[@]}; i++)); do
    t=${toks[i]}
    if (( ! seen_push )); then
      case "$t" in git|*/git|git.exe|*/git.exe) seen_git=1 ;; esac
      [[ $seen_git -eq 1 && "$t" == push ]] && seen_push=1
      continue
    fi
    case "$t" in
      --force-with-lease)                                 has_lease=1; lease_exact=1 ;;
      --force-with-lease=*|--force-w*)                    has_lease=1 ;;
      -f|--force|--force=*|--forc|--m*)                   has_force=1 ;;
      -[a-zA-Z0-9]*)                           if [[ "$t" == *f* ]]; then has_force=1; else other_option=1; fi ;;
      --*)                                     other_option=1 ;;
      +*)                                      has_force=1; args+=("${t#+}") ;;
      *)                                       args+=("$t") ;;
    esac
  done
  (( seen_push )) || return 0
  (( has_force )) && deny "[T0-3] 禁用非 lease force push（--force / -f / +refspec / --mirror）。非保護分支請改用 --force-with-lease。"
  (( has_lease )) || return 0
  (( lease_exact )) || deny "[T0-3] --force-with-lease 必須使用完整拼寫。"
  (( other_option )) && deny "[T0-3] --force-with-lease 只允許 canonical 形狀，不得混用其他 option。"
  (( ${#args[@]} == 2 )) || deny "[T0-3] --force-with-lease 必須明示 remote 與單一 refspec。"
  check_target "${args[1]}"
  return 0
}

# 複合命令切段（; | & 皆為段界），只檢查含 git push 的段
while IFS= read -r seg; do
  case "$seg" in *git*push*) check_seg "$seg" ;; esac
done < <(printf '%s\n' "$SCAN_CMD" | tr ';|&' '\n')
exit 0
