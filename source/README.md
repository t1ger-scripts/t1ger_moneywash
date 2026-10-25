# t1ger_moneywash: NUI source

Vue 3 + Vite + TypeScript source of the screens (business portal, cash counter, raid, accountant review).
The built UI goes to `../web` and is what the resource loads. You only need this folder to change the UI.

## Build

```bash
npm ci
npm run build
```

`npm run build` type-checks first, then builds into `../web` (emptied on every build).

## Layout

- `src/portal`, `src/cash-counter`, `src/raid`, `src/review`: one folder per screen
- `src/shared`: the screen switcher and drag/seal helpers shared by the screens
- `src/integrations`: NUI messages and callbacks (`nui.ts`) and translations (`i18n.ts`)
- `public/images`: pictures. A business picture is named `<type>_<3-digit id>.webp`
- `public/mapStyles`: map tiles for the business map

All text comes from the Lua side (`shared/ui_text.lua`), never from this source.