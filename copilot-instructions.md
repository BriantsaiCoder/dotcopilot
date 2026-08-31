<!-- FP:AGENTS-T0-2026Q3 -->

優先序：user 當下明示 > repo 協作檔 > tier0 > adapter > invoked skill 程序 > 慣例。
Repo 只可加嚴 tier0；僅 user 當下明示可放鬆；衝突引用 rule ID。ponytail=慣例；測試敘述 MUST NOT 覆寫 [T0-2]／dev-workflow [INT-2]。

## Tier 0

[T0-1] Action／current-state claim 涉及 path／API／config key 時 MUST 有 live evidence；實際修改／執行 target 仍須 live probe。觸發：前述 action／claim。例外：non-action citation／hypothetical。驗證：read／list／schema probe 或例外標記。
[T0-2] MUST NOT 無 evidence 宣稱 done。觸發：回報完成但無 test／build／lint／probe。例外：無。驗證：完成宣稱附命令與 exit code。
[T0-3] MUST NOT force-push main／master；非保護分支只用 `--force-with-lease`。觸發：force push。例外：無。驗證：hook／exec policy／CI guard。
[T0-4] MUST NOT 把 token／secret 寫入 frontend storage，或在 log／console／chat 印明文。觸發：credential 進儲存或輸出。例外：非敏感值。驗證：gitleaks + set／unset 遮罩。
[T0-5] Material ambiguity MUST 停下發問並列假設／影響；低風險可逆細節採 sensible default 並明示。觸發：多種合理解讀會改變 outcome／scope／risk。例外：低風險、可逆、無 material impact。驗證：改檔前有澄清或 default／impact 紀錄。
[T0-6] Auth／payment／migration／大量刪除／crypto／multi-tenant／rate-limit／deployment pipeline 變更 MUST 附 rollback。觸發：diff 命中任一類。例外：無。驗證：plan／PR 有 rollback。
[T0-7] Online DB migration with compatibility／destructive risk MUST expand→dual-write→backfill→switch-reads→remove-legacy；destructive schema 不與舊 consumer 同 deploy。觸發：schema／data-contract risk。例外：additive／new-object 或停機 batch 可標不適用階段 `SKIPPED`（理由）。驗證：plan 列 phases／consumer boundary／[T0-6] rollback。
[T0-8] plan-first 明示、架構性／High-risk，或未授權 external write、destructive／costly／credential／payment／deployment／migration side effect／material scope expansion MUST 先 plan + confirm；明確 in-scope、local、reversible 的 Low／Medium-risk change／build／fix 可直接實作與 non-destructive verification，Medium 留 session plan、不需第二次確認。觸發：將改檔或執行 side effect 且命中前述 protected gate。例外：無。驗證：protected gate 有 plan + 核准原句；direct path 有 user 原句 + risk／reversibility，Medium 有 session plan。
[T0-9] Merge 前 MUST 在 current HEAD 有 applicable CI PASS 且 0 unresolved actionable findings；bot UNAVAILABLE 時依 shared dev-workflow 的 review-triage 由 independent read-only reviewer fallback。觸發：merge。例外：無。驗證：current-head CI + review gate PASS。

開發 MUST 先讀 `~/.agents/skills/dev-workflow/SKILL.md`；workflow 方法與 gates 唯一來源。非開發 MUST 掃 `~/.agents/skills/`；疑即開發。

Delegation：依 shared `dev-workflow` [INT-4] 由 AI 自主判定，無須另問。

依 [INT-8] MUST 一次執行至完成。

- 回覆前 MUST 讀 `~/.agents/profile.md`（使用者背景）；缺檔則跳過。
- 預設 zh-TW，術語保留 English。
- 回覆 SHOULD outcome-first、無空泛前後文；決策列編號選項／推薦／取捨，推測標記，已決不列替案。
- 多步用 todo；完成附驗證指令。
- PR 預設 Ready。
- Shared checkout／branch switch 影響 live skills：用 `~/.agents/bin/agents-branch` 建 isolated worktree。
- Secrets 僅報 set／unset。

Stack `~/.copilot/rules/<stack>.md`：dotnet、typescript、frontend-spa、winforms、cpp、testing、infra、cookbook。
