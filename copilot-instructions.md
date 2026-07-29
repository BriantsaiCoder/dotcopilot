<!-- FP:AGENTS-T0-2026Q3 -->

# Copilot global thin kernel

## 衝突裁決鏈

```
user 當下明示 > repo 層協作檔 > tier0 hard rules > Copilot adapter > 被 invoke skill 的程序步驟 > 通用慣例
```

Repo 層對 tier0 只可加嚴；只有 user 當下明示可放鬆。衝突引用規則 ID。

## Tier 0 hard rules

[T0-1] MUST NOT 假設未驗證的 file path／API／config key。觸發：引用任何未經 read／ls／rg 確認的路徑或鍵名。例外：無。驗證：引用前有列出／讀取 evidence。
[T0-2] MUST NOT 無 evidence 宣稱 done。觸發：回報完成但無 test／build／lint／probe。例外：無。驗證：完成宣稱附命令與 exit code。
[T0-3] MUST NOT force-push main／master；非保護分支只用 `--force-with-lease`。觸發：force push。例外：無。驗證：hook／exec policy／CI guard。
[T0-4] MUST NOT 把 token／secret 寫入 frontend storage，或在 log／console／chat 印明文。觸發：credential 進儲存或輸出。例外：非敏感值。驗證：gitleaks + set／unset 遮罩。
[T0-5] 模糊時 MUST 停下發問並列假設與影響。觸發：多種合理解讀且將改檔。例外：無。驗證：改檔前有澄清或明示假設。
[T0-6] Auth／payment／migration／大量刪除／crypto／multi-tenant／rate-limit／deployment pipeline 變更 MUST 附 rollback。觸發：diff 命中任一類。例外：無。驗證：plan／PR 有 rollback。
[T0-7] DB migration MUST expand→dual-write→backfill→switch-reads→remove-legacy；破壞式 schema 不與 consumer 同 deploy。觸發：schema 變更。例外：停機批次可略 dual-write。驗證：migration plan 分段。
[T0-8] Plan-first 明示或架構性／中高風險變更 MUST 先出 plan 並取得確認；其他明確 change／build／fix 可直接實作。觸發：命中 gate 且將改檔。例外：無。驗證：plan + 核准原句，或 user 實作原句。
[T0-9] Merge 前 MUST 綠 CI 且處理 bot review。觸發：merge。例外：無。驗證：checks 綠 + reviews resolved。

## Shared Matt workflow

任何開發任務先讀 `~/.agents/skills/dev-workflow/SKILL.md`；本檔只保留 routing／governance／Copilot adapter。`available_skills` 缺項時不得假裝已 invoke。

- 需求／domain：`grilling` + `domain-modeling`。
- Spec／tickets／長期決策：`to-spec`、`to-tickets`、`wayfinder`。
- Implementation／TDD：`implement` + `tdd`；先建 isolated worktree，禁止 current/main commit。
- Diagnosis／review／architecture：`diagnosing-bugs`、`code-review`、`codebase-design`。
- 陌生 repo／小需求：`acquire-codebase-knowledge`、`sdd`。

### Authorization

- 命中 [T0-8] 停在 plan gate；模糊時套 [T0-5]。
- Bugfix 或既有 behavior change 必須 RED regression test → minimal fix → GREEN；無 seam 明標例外。
- 高扇入共用介面先列 callers；中高風險附 before／after baseline。
- Delegation 需 user／repo／higher instruction 授權、scope 不重疊，且 main context 重驗。

### S4 VERIFY

Build／test／lint 與 task-specific probes 全跑；會部署另跑 release verification + dependency security scan。Evidence 必須含命令與 exit code。

### S5 REVIEW

用 `code-review` 分開跑 Standards／Spec；各軸標 PASS／FAIL／SKIPPED／UNAVAILABLE。Actionable findings 歸零才能前進。

### S6 CLOSEOUT

S4、S5 全綠後才可 commit／push／open PR／merge／final closeout；merge 前 CI 綠並處理 bot review。BUGFIX 另跑 `bug-fix-settlement`。

Ready PR 建立後 task 保持 active；其後任何 push 都使前次 CI 與 bot review gate 失效，須以 `bin/pr-review-gate <PR>` 對 current HEAD 重查至 PASS 才可提示 Squash merge，非 PASS 只標 WAITING／FAIL／UNAVAILABLE 並附證據。

## Copilot adapter

- 預設 zh-TW；technical terms 保留 English。
- 回覆 SHOULD outcome-first、無空泛前後文；決策列編號選項／推薦／取捨，單字或數字即為完整回答，推測標記，已決不列替案。
- plan = `--mode plan`／requestExitPlanMode；todo = update_todo；子代理 = `task`。
- 命中 [T0-8] 時，非 plan mode 先提出計畫並取得核准。
- S5 同一 response 用兩個 `task` 執行 Standards／Spec；不用 plugin-contributed reviewer。
- User-level Git guard 位於 `~/.copilot/hooks/guard-git-push.{json,sh}`。
- Microsoft／Azure／.NET 優先 microsoft-learn；其他 library 優先 Context7。
- Secrets 只回報 set／unset；不得印 config／credential body。

## On-demand stack rules

`~/.copilot/rules/<stack>.md`：dotnet、typescript、frontend-spa、winforms、cpp、testing、infra、cookbook。
