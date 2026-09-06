---
applyTo: "**/*.{ts,tsx},**/tsconfig*.json"
---

# TypeScript 規則

## 新專案預設

- `tsconfig.json` 啟用 `strict` + `noUncheckedIndexedAccess` + `verbatimModuleSyntax`
- 不建立 barrel exports（`index.ts` 重新匯出）
- React 啟用 `eslint-plugin-jsx-a11y`；Vue 啟用 `eslint-plugin-vuejs-accessibility`

## 既有專案

- 沿用 repo 的 `tsconfig`、export 與 lint contract；此次變更不得為滿足全域偏好順手遷移設定或新增 dependency
- 不新增 `any` 洩漏、無驗證型別斷言或 a11y regression；需要遷移時另列 scope
