#!/usr/bin/env bash
# Copilot CLI preToolUse hook — [T0-3] force-push 前置攔截（可 deny）
# 契約（自 CLI 1.0.70 bundle app.js 逐字驗證）：
#   stdin : {"sessionId","timestamp","cwd","toolName","toolArgs"}
#   stdout: {"permissionDecision":"deny","permissionDecisionReason":"..."} 攔截；無輸出＝放行
# 攔截：任何非 lease force push（--force / -f / +refspec）；任何 force 變體
#（含 --force-with-lease）推 main/master。放行：非保護分支 --force-with-lease、一般 push。
# 無明示 refspec 時以 payload cwd 解析當前分支；解析失敗保守拒絕（fail-closed）。
set -uf
JQ="$(command -v jq 2>/dev/null || echo /opt/homebrew/bin/jq)"
INPUT="$(cat)"
TOOL=$(printf '%s' "$INPUT" | "$JQ" -r '.toolName // empty' 2>/dev/null) || TOOL=""
case "$TOOL" in bash|shell|Bash) ;; *) exit 0 ;; esac
# toolArgs 可能是物件或 JSON 字串，兩者皆容
CMD=$(printf '%s' "$INPUT" | "$JQ" -r '
  (.toolArgs | if type=="string" then (try fromjson catch {}) else . end)
  | .command // empty' 2>/dev/null) || CMD=""
[ -z "$CMD" ] && exit 0
case "$CMD" in *git*push*) ;; *) exit 0 ;; esac
CWD=$(printf '%s' "$INPUT" | "$JQ" -r '.cwd // empty' 2>/dev/null) || CWD=""

deny() {
  printf '{"permissionDecision":"deny","permissionDecisionReason":%s}\n' \
    "$(printf '%s' "$1" | "$JQ" -R -s '.')"
  exit 0
}

check_seg() {
  local seg="$1" t target
  local IFS=$' \t\n'
  local -a toks=($seg) args=()
  local i seen_git=0 seen_push=0 has_force=0 has_lease=0
  for ((i = 0; i < ${#toks[@]}; i++)); do
    t=${toks[i]}
    if (( ! seen_push )); then
      [[ "$t" == git ]] && seen_git=1
      [[ $seen_git -eq 1 && "$t" == push ]] && seen_push=1
      continue
    fi
    case "$t" in
      --force-with-lease|--force-with-lease=*) has_lease=1 ;;
      -f|--force)                              has_force=1 ;;
      --*|-*)                                  : ;;
      +*)                                      has_force=1; args+=("${t#+}") ;;
      *)                                       args+=("$t") ;;
    esac
  done
  (( seen_push )) || return 0
  (( has_force )) && deny "[T0-3] 禁用非 lease force push（--force / -f / +refspec）。非保護分支請改用 --force-with-lease。"
  (( has_lease )) || return 0
  if (( ${#args[@]} >= 2 )); then
    target="${args[1]##*:}"      # refspec 可能是 src:dst，取 dst
  else
    target=$(git -C "${CWD:-.}" symbolic-ref --short HEAD 2>/dev/null || true)
    [[ -z "$target" ]] && deny "[T0-3] --force-with-lease 未明示 refspec 且無法解析當前分支，保守拒絕（請明示 origin <branch>）。"
  fi
  case "${target#refs/heads/}" in
    main|master) deny "[T0-3] 禁止 force push（含 --force-with-lease）到 main/master。" ;;
  esac
  return 0
}

# 複合命令切段（; | & 皆為段界），只檢查含 git push 的段
IFS=$'\n'
for seg in $(printf '%s' "$CMD" | tr ';|&' '\n\n\n'); do
  case "$seg" in *git*push*) check_seg "$seg" ;; esac
done
exit 0
