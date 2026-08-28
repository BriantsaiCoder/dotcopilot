#!/usr/bin/env bash
# 無硬編碼家目錄路徑掃描。本 repo 是異地備份供還原，換機時使用者名稱不同會讓 guard 與
# drift 偵測靜默失效。
#
# 為什麼從 ci.yml 搬出來成為獨立檔（2026-08-28）：原本是 ci.yml 內嵌的
#
#     if grep -rn -e '/Users/' -e '/home/[^/]' hooks/*.sh agents/ 2>/dev/null; then … fi
#
# 而 `agents/` 未入版控（`git ls-files --error-unmatch agents` rc=1），CI 的 checkout 裡根本
# 不存在。grep 對缺席的 operand 回 **rc=2**——即使它已經在 hooks/*.sh 裡找到命中並印了出來
# （GNU grep 的 suppressible_error() 無條件設 errseen，main() 結尾以 EXIT_TROUBLE=2 覆蓋；
# BSD grep 同）。rc=2 讓 `if` 為 false，錯誤訊息又被 `2>/dev/null` 吃掉，於是這道閘門在 CI 的
# checkout 形狀下自建立起就**恆綠**：實測在無 agents/ 的複本注入一行 `/Users/<user>/…` 到
# hooks/guard-git-push.sh，閘門完全沉默地放行。（本機因為有一個 gitignored 的 agents/ 目錄，
# operand 存在、rc 正常，所以這個缺陷在本機重現不出來——這正是它活下來的原因。）
#
# 缺的不是 pattern 也不是範圍，是「掃描自己失敗時被當成通過」這個 rc 三態沒有分辨，以及沒有
# 任何東西會在閘門死掉時出聲。所以搬成獨立檔並附 --selftest。
#
# 掃描範圍是 hooks/*.sh，加上 agents/（只在它入版控時）。**這不是全 repo 覆蓋**——下列
# tracked 檔目前都含硬編碼家目錄路徑且不在範圍內，逐項列出而非只提一項：
#   hooks/guard-git-push.json:7          "bash" 欄是裸絕對路徑
#   mcp-config.json:24                   MCP server 的 dll 路徑
#   permissions-config.json:3,10,17      三個 location key
#   tests/global-config-ownership.sh:256 `jq --arg home /Users/pochientsai` 斷言基準
# 其中 hooks/guard-git-push.json 是刻意排除：Codex 的等價設定是 shell 字串
# （"command": "bash \"$HOME/…\""，$HOME 會展開），但 Copilot 的 "bash" 欄是裸路徑，是否展開
# $HOME 無文件佐證。該 hook 是 [T0-3] force-push 防線，憑假設替換若不展開就是靜默拆防線，
# 比寫死更糟。其餘三處是既有缺口，收斂範圍是獨立的後續工作，不在本檔的宣稱裡。
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

PATTERNS=(-e '/Users/' -e '/home/[^/]')

# scan <目錄或檔案...> -> 0=乾淨 1=有命中（已印出）2=掃描失敗（已印出理由）
# -I：二進位檔只會印出「Binary file … matches」這種無 file:line 的行，對本用途是噪音。
scan() {
  local out rc=0
  out="$(grep -rnI "${PATTERNS[@]}" -- "$@" 2>&1)" || rc=$?
  case "$rc" in
    0)
      printf '%s\n' "$out"
      return 1
      ;;
    1)
      return 0
      ;;
    *)
      printf '掃描失敗（grep rc=%s），不當作通過：%s\n' "$rc" "$out" >&2
      return 2
      ;;
  esac
}

# run_scan <目錄或檔案...> -> 0=通過 1=擋下
# 把 scan 的 rc 三態轉成 CI 的通過／擋下，並印出對應訊息。獨立成函式是為了讓 --selftest
# 連這一層一起驗——原缺陷（掃描失敗被當成通過）可以原封不動地在這一層重新出現。
run_scan() {
  local rc=0
  scan "$@" || rc=$?
  case "$rc" in
    0)
      printf 'PASS: 無硬編碼家目錄路徑（範圍：%s）\n' "$*"
      return 0
      ;;
    1)
      printf '::error::發現硬編碼家目錄路徑，請改用 $HOME\n'
      return 1
      ;;
    *)
      printf '::error::硬編碼路徑掃描失敗，不當作通過\n'
      return 1
      ;;
  esac
}

# 掃描目標。判準是**入版控**而非目錄存在：本機有一個 gitignored 的 agents/（內容只有
# .DS_Store），用 `[ -d agents ]` 會讓本機與 CI 掃到不同的東西，且方向是「本機看起來有覆蓋、
# CI 實際沒有」。用 git ls-files 判定，則它哪天入版控時覆蓋會自動恢復，而不是靜默漏掉。
compute_targets() {
  targets=(hooks/*.sh)
  if git ls-files --error-unmatch agents >/dev/null 2>&1; then
    targets+=(agents)
  else
    printf 'SKIP: agents/ 未入版控，本次掃描範圍為 hooks/*.sh\n'
  fi
}

selftest_dir=
# trap 在函式回傳後才跑，所以清理路徑不能是函式的 local——那會在 EXIT 時 unbound 而讓
# `set -u` 在收尾噴 `unbound variable`（第一版實測過）。
cleanup_selftest() { [ -n "$selftest_dir" ] && rm -rf "$selftest_dir"; }

selftest() {
  local d pass=0 fail=0
  d="$(mktemp -d "${TMPDIR:-/tmp}/copilot-nhh.XXXXXX")" || exit 1
  selftest_dir="$d"
  trap cleanup_selftest EXIT
  mkdir -p "$d/clean" "$d/dirty"
  printf '#!/usr/bin/env bash\necho ok\n' > "$d/clean/a.sh"
  # fixture 用 /Users/example 而非真實使用者名稱：pattern 是 `/Users/`，鑑別力完全相同，
  # 但不會在 tests/ 底下多留一個真名字面（把掃描範圍擴到 tests/ 是已知的後續工作）。
  printf '#!/usr/bin/env bash\n# /Users/example/should-be-caught\n' > "$d/dirty/a.sh"

  check() { # $1=label $2=期望 rc $3=函式名 $4...=參數
    local label="$1" want="$2" fn="$3" got=0
    shift 3
    "$fn" "$@" >/dev/null 2>&1 || got=$?
    if [ "$got" -eq "$want" ]; then
      printf 'ok   %s (rc=%s)\n' "$label" "$got"
      pass=$((pass + 1))
    else
      printf 'FAIL %s: want rc=%s got rc=%s\n' "$label" "$want" "$got" >&2
      fail=$((fail + 1))
    fi
  }

  # scan 層：rc 三態本身。
  check 'scan 乾淨目錄回 0' 0 scan "$d/clean"
  check 'scan 有硬編碼路徑回 1' 1 scan "$d/dirty"
  # 這兩條才是本檔存在的理由：掃描目標不存在時，rc 必須是 2（大聲失敗）而不是 0（誤判
  # 乾淨）。搬出來之前的 ci.yml 內嵌版本在這兩條會拿到「靜默放行」。第二條額外證明錯誤
  # 優先於命中——不會因為「反正找到了」而蓋掉 rc=2。
  check 'scan 目標不存在時大聲失敗' 2 scan "$d/clean" "$d/does-not-exist"
  check 'scan 有命中但目標缺席仍算掃描失敗' 2 scan "$d/dirty" "$d/does-not-exist"

  # run_scan 層：rc 三態轉成通過／擋下。只驗 scan 不夠——同一個「失敗被當成通過」的缺陷
  # 可以只出現在這一層（把 `*)` 分支改成 return 0），而 scan 的四條仍然全綠。
  check 'run_scan 乾淨目錄通過' 0 run_scan "$d/clean"
  check 'run_scan 有硬編碼路徑擋下' 1 run_scan "$d/dirty"
  check 'run_scan 掃描失敗時擋下' 1 run_scan "$d/clean" "$d/does-not-exist"

  # 訊息鑑別力：掃描失敗與真命中必須印出互斥的 ::error::，否則排障者分不出「抓到了」與
  # 「儀器壞了」。只驗 rc 的話，把 `*)` 分支的訊息改成與 rc=1 相同也不會紅。
  local out
  out="$(run_scan "$d/clean" "$d/does-not-exist" 2>/dev/null)" || true
  case "$out" in
    *'掃描失敗，不當作通過'*)
      printf 'ok   run_scan 掃描失敗印出專屬訊息\n'
      pass=$((pass + 1))
      ;;
    *)
      printf 'FAIL run_scan 掃描失敗未印出專屬訊息，實得：%s\n' "$out" >&2
      fail=$((fail + 1))
      ;;
  esac

  printf '%s PASS / %s FAIL\n' "$pass" "$fail"
  [ "$fail" -eq 0 ]
}

# 未知參數必須大聲失敗。用 `if [ "$1" = --selftest ]` 再 fall-through 到正常掃描的話，
# ci.yml 的 selftest step 一旦把旗標拼錯（--selftst），會安靜降級成與前一個 step 完全相同的
# 掃描並回 rc=0——鑑別力步驟消失而 CI 全綠，正是本檔要消滅的失效類別。
case "${1:-}" in
  '')
    compute_targets
    run_scan "${targets[@]}"
    exit $?
    ;;
  --selftest)
    selftest
    exit $?
    ;;
  *)
    printf '未知參數：%s（本檔只接受無參數或 --selftest）\n' "$1" >&2
    exit 2
    ;;
esac
