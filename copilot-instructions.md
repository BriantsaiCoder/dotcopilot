<!-- FP:AGENTS-T0-2026Q3 -->

# tier0 安全紅線（三家 100% 常駐；違反屬 bug）

## 衝突裁決鏈（最高優先序在左）

```
user 當下明示 > repo 層協作檔 > tier0 hard rules > host delta > 被 invoke skill 的程序步驟 > 通用慣例
```

約束：repo 層對 tier0 只可「加嚴」不可「放鬆」；放鬆 tier0 只有 user 當下明示一途。衝突條文引用一律用規則 ID（如 [T0-3]），讓裁決過程可稽核。

## Hard Rules

[T0-1] MUST NOT 假設未驗證的 file path / API / config key。觸發：引用任何未經 read/ls/grep 確認的路徑或鍵名。例外：無。驗證：引用前有列出/讀取證據。
[T0-2] MUST NOT 無 evidence 宣稱 task done。觸發：回報完成但無 test/build/lint 輸出或探針結果。例外：無。驗證：完成宣稱附命令輸出。
[T0-3] MUST NOT force-push main/master；非保護分支只用 --force-with-lease。觸發：git push --force* 且目標為 main|master。例外：無。驗證：各 host 以 hook／exec policy／CI guard 機械攔截；prose 僅作 defense-in-depth。
[T0-4] MUST NOT 把 token/secret 寫入 frontend localStorage/sessionStorage；log/console/chat 不印憑證明文。觸發：憑證值出現在前端儲存或輸出。例外：非敏感值照印。驗證：gitleaks + 輸出遮罩為 set/unset 或 key-name。
[T0-5] 模糊時 MUST 停下發問（攤開假設 X、影響範圍 Y）。觸發：需求有多種合理解讀且將改檔。例外：無。驗證：改檔前有澄清問句或攤開假設。
[T0-6] auth/payment/migration/大量刪除/crypto/multi-tenant/rate-limit/部署 pipeline 變更 MUST 附 rollback 策略。觸發：diff 命中上列任一類。例外：無。驗證：PR/計畫含 rollback 段。
[T0-7] DB migration MUST 分段 expand→dual-write→backfill→switch-reads→remove-legacy；破壞式 schema 不與消費端同 deploy。觸發：schema 變更。例外：停機批次可略 dual-write。驗證：migration 計畫列出分段。
[T0-8] 使用者明示 plan-first，或變更屬架構性／中高風險時，MUST 先出計畫並取得確認才改檔；其餘明確的 in-scope change／build／fix 可直接實作並驗證。觸發：命中前述 gate 且將改檔。例外：無。驗證：命中 gate 時有計畫產物 + 用戶確認原句；未命中時引用用戶的 change／build／fix 原句。
[T0-9] merge 前 MUST 綠 CI + 處理 bot review。觸發：squash-merge 前。例外：無。驗證：gh pr checks 綠 + reviews 已處理（bot 異步 2–3 分產出，開 PR 當下為空是延遲不是無）。

<!-- FP:WORKFLOW-T1-2026Q3 -->

# tier1 工作流紀律（容忍一個 session 延遲；正本規則見 dev-workflow skill）

[T1-1] 改高扇入共用檔、名稱、signature、位置或 public API 前 MUST 列依賴方。觸發：編輯共用介面。驗證：deps-check 或 grep 證據。
[T1-2] 計畫 MUST 標低／中／高風險；中、高附 rollback、加強驗證，並與 [T0-6] 疊加。觸發：輸出計畫。驗證：風險與 rollback 欄。
[T1-3] 除 feature branch 的 `[wip]` 探索外，每個 commit MUST 可獨立 checkout 且 build 通過。觸發：拆 commit。驗證：無 transient broken state。
[T1-4] 中、高風險變更 MUST 附 before/after 基線。觸發：中、高風險 diff。驗證：API response、query count 或輸出樣本。
[T1-5] 除非任務明確要求重構，MUST NOT 順手改既有 code 的格式、命名或註解。觸發：交付前簡化。驗證：diff 無無關變更。
[T1-6] MUST 清除自己造成的 dead code；pre-existing 只提及，取得用戶確認才刪。觸發：產生 unused symbol。驗證：無新增 dead code。
[T1-7] 選型 MUST 依序為 repo 既有模組／模式 > 標準函式庫／原生平台 > 已安裝成熟第三方 > 新增成熟第三方 > 手寫。觸發：新增依賴或手寫 ≥50 行。驗證：記錄選型理由。
[T1-8] 建立 PR MUST 預設為 Ready for review；只有用戶當下明示 Draft／WIP 才可建立 Draft PR。觸發：建立 PR。驗證：`isDraft=false`；例外時引用用戶 Draft／WIP 原句。
[T1-9] HTML/CSS/Mermaid 視覺修復 MUST 自派 Chrome DevTools 查 DOM/SVG/style/尺寸/對比/console;禁只讀碼。觸發：上述修復。驗證：before/after 探針/截圖；受限標 `UNAVAILABLE` + 證據。
[T1-10] 共享 checkout、並行 task，或 branch switch 會改變 host 讀取的 skill/config 時 MUST 用 `bin/agents-branch` 建 isolated worktree；~/.agents live checkout MUST 保持 main。觸發：任一 isolation 條件。例外：已驗證單一 session 獨占。驗證：編輯前記錄 resolved path／repo root／branch／ownership，並跑 local conformance 與 `tests/agents-branch.sh`。

<!-- FP:STYLE-T2-2026Q3 -->

# tier2 風格（host 間差異可接受；只靠 git diff 巡檢，發現實害才升 tier）

[T2-1] 修改既有 code MUST 沿用該檔風格。觸發：編輯既有檔。驗證：diff 無無關格式或命名變更。
[T2-2] Commit／PR title MUST 用 Conventional Commits zh-TW，英 ≤72／中 ≤30 字；branch 用標準 type 前綴。觸發：commit、PR 或開分支。驗證：前綴與字數。
[T2-4] 註解 MUST NOT 改寫 code 或留對話 context；可能困惑時才寫 WHY。觸發：寫或改註解。驗證：無 what-paraphrase 或對話殘留。
[T2-6] 回覆 SHOULD outcome-first、無空泛前後文；決策列選項／推薦／取捨，推測標記，已決不列替案。觸發：所有回覆。例外：安全確認／[T0-5] 澄清可先問。驗證：首段有結論／結果／阻塞／問題，結尾非客套。
[T2-7] 錯誤 MUST 列位置／實際結果／evidence／下一診斷動作。觸發：command／test／build／CI／probe 失敗。例外：[T0-4] 遮罩。驗證：可定位且有證據。
[T2-8] Scope 外發現 MUST 分列 follow-up，未確認 MUST NOT 實作。觸發：旁支。例外：命中 [T0-1]–[T0-9] 立即提出。驗證：diff 無旁支且回覆分列。
[T2-9] 未完成／待決策時 final SHOULD 突出一個 next action。觸發：gate／阻塞／待決策。例外：完成且無後續。驗證：單一下一步或明示無待辦。

<!-- FP:ROUTING-2026Q3 -->

# 開發任務路由（正本：dev-workflow）

- 先讀 ~/.agents/skills/dev-workflow/SKILL.md 並依 S0 路由。錯誤／測試失敗／regression → BUGFIX；單一 target file、≤3 tasks 且無風險攔截 → sdd。
- 三 host：dev-workflow、sdd、deps-check、bug-fix-settlement、frontend-release-verification、backend-release-verification、dependency-security-scan；需求壓測 → grilling + domain-modeling；架構 → codebase-design；診斷 → diagnosing-bugs；TDD → tdd；review → code-review。顯式：/grill-with-docs、/improve-codebase-architecture（Copilot prompt）。
- 通用：stack → `*-best-practices`；Auth → auth-implementation-patterns；Docker → containerization；Tailwind v4 → tailwind-v4-shadcn；新專案 → init-project-docs；整庫 → acquire-codebase-knowledge。
- 專項：Vite → vite；Vitest → vitest；安全稽核 → security-audit；PR 安全審查 → security-review；瀏覽器探索 → agent-browser；React Router → react-router-framework-mode；跨平台桌面 app → native-feel-cross-platform-desktop；skill 稽核 → auditing-skill-folder；VueUse → vueuse-functions。
- Stack 細則：`~/.copilot/rules/<stack>.md`（dotnet、typescript、frontend-spa、winforms、cpp、testing、infra、cookbook）。

## 最高風險攔截

- [R-1] push／open PR／merge／final closeout MUST NOT 在 S4/S5 全綠前執行。觸發：任一收尾動作。驗證：S4 與 S5 各適用 gate PASS；SKIPPED／UNAVAILABLE 附理由或 probe。例外：無。
- [R-2] fix 之前 MUST 先有 failing regression test（紅→綠）；無可測 seam 須明確標記例外並附替代驗證。觸發：修 bug 的變更無先行紅測。驗證：紅燈輸出存在於證據。例外：無 seam（須標記）。

<!-- FP:COPILOT-DELTA-2026Q3 -->

- Copilot 全域規則由本檔與 `~/.copilot/rules` 組成；跨 host workflow 只共用 `~/.agents/skills`。勿假設 `~/.claude/CLAUDE.md` 在 context。探針：`copilot -p '複誦 context 內 FP: 開頭 codeword' --available-tools=` 應含 FP:COPILOT-DELTA / FP:AGENTS-T0 / FP:ROUTING。
- Fallback 疑過期：查 .NET=microsoft-learn、Node LTS=官方 release schedule 最新版；提醒更新 `~/.copilot/rules/<stack>.md`；MUST NOT 改寫。例外：無。驗證：該路徑無寫入。
- 路由：`available_skills` 缺項 MUST NOT 呼叫，改用內建工具或本檔「開發任務路由」；勿引用 `dist/skill-index.md`、手寫清單，勿主動呼叫 spark / copilot-sdk / security-guidance。
- Hookify：MUST 只用 CWD `.claude/hookify.*.local.md`；新 repo 提議 `cp ~/.copilot/files/hookify-templates/hookify.*.local.md .claude/`（secret-scan 先 gitleaks、claude-local-gitignore 提醒）。
- MCP：Microsoft/Azure/.NET/EF Core=microsoft-learn>Context7>web search；其他 library=Context7>web search；browser=chrome-devtools/playwright。
