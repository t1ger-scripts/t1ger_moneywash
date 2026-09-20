# t1ger_moneywash Browser UI

Source files for the Ledger Capital business brokerage interface included with `t1ger_moneywash`.

The interface allows players to browse available business listings, review locations on an interactive GTA V map, purchase eligible businesses, and manage their existing portfolio. Runtime data is supplied by the FiveM resource; the frontend does not contain authoritative ownership, balance, reputation, or availability data.

## Technology

- Vue 3
- TypeScript
- Vite
- Leaflet
- Lucide Vue
- Inter variable font

The compiled UI is static and does not require Node.js on the production FiveM server. Node.js is only required when editing and rebuilding the source.

## Requirements

- Node.js 20 or newer
- npm
- A complete installation of `t1ger_moneywash`

## Install dependencies

Open a terminal inside the `source` directory and run:

```bash
npm install
```

Dependencies only need to be installed again after deleting `node_modules`, changing `package.json`, or updating the package versions.

## Build the UI

From the `source` directory, run:

```bash
npm run build
```

The build performs TypeScript validation and writes the compiled interface directly to the resource's sibling `web/` directory.

```text
t1ger_moneywash/
├─ source/
├─ web/
├─ client/
├─ server/
├─ shared/
└─ locales/
```

The existing contents of `web/` are cleared before every successful build because `vite.config.ts` uses:

```ts
build: {
  outDir: '../web',
  emptyOutDir: true,
}
```

After building, restart `t1ger_moneywash` and clear the FiveM client cache if an older build continues to appear.

Do not manually edit generated files inside `web/assets/`. Their filenames contain build hashes and all manual changes will be overwritten by the next build. Make changes inside `source/src/` and rebuild instead.

## Development commands

```bash
# Start the Vite development server
npm run dev

# Validate TypeScript and create the production build
npm run build

# Preview the most recent production build
npm run preview
```

The production interface starts hidden and expects its data and visibility events from FiveM. Opening the Vite page directly may therefore display an empty page. The shipped source intentionally contains no mock players, businesses, ownership records, balances, or reputation data.

For reliable testing, build the interface and open it through the configured computer or laptop target inside FiveM.

## Source structure

```text
source/
├─ src/
│  ├─ assets/
│  │  └─ main.css              # Global styling and responsive layout
│  ├─ components/              # Vue interface components
│  ├─ lib/
│  │  ├─ format.ts             # Currency and display formatting
│  │  ├─ locale.ts             # Runtime translation helpers
│  │  └─ nui.ts                # FiveM NUI request helper
│  ├─ types/
│  │  └─ business.ts           # Shared TypeScript interfaces
│  ├─ App.vue                  # UI state, NUI events, and page composition
│  └─ main.ts                  # Vue application entry point
├─ public/
│  └─ mapStyles/
│     └─ styleSatelite/        # Local satellite map tiles
├─ index.html
├─ package.json
├─ tsconfig.json
└─ vite.config.ts
```

## Configuration

### Browser access

Computer and laptop models that open the interface are configured in:

```lua
Config.Browser.Models
```

The same section controls the target label, target icon, interaction distance, and ownership-transfer distance.

The resource also exposes `OpenBrowser` and `CloseBrowser` from the client, allowing the interface to be opened by another compatible resource.

### Theme colors

Customers do not need to rebuild the UI to change the standard theme colors. Edit:

```lua
Config.BrowserUI.Theme
```

The configured colors are sent to the interface during bootstrap and applied as CSS variables at runtime.

Available values include:

- Accent, hover, and dark accent colors
- Body, panel, alternate panel, and card colors
- Border, primary text, and muted text colors
- Success, warning, and danger colors

Additional structural design changes should be made in `source/src/assets/main.css`.

### Currency

The currency symbol displayed by the interface uses:

```lua
Config.Currency
```

Changing the symbol does not require rebuilding the UI.

## Localization

All customer-facing browser text is stored in:

```text
locales/en.json
```

To create another language:

1. Copy `locales/en.json`.
2. Rename the copy to the required locale, for example `da.json`.
3. Translate the values without changing the JSON keys or placeholders.
4. Configure the server locale, for example:

```cfg
setr ox:locale "da"
```

English is always loaded as the fallback. The selected locale is merged over English, so untranslated or missing keys continue to display the English value.

Placeholders such as `{business}`, `{player}`, `{current}`, and `{limit}` must remain unchanged in translated strings.

Business-type labels and reputation titles can also be translated through the corresponding `browser.business_types` and `browser.reputation_levels` entries. Unknown custom types fall back to the label supplied by Lua.

## Map tiles

The interface uses a local Leaflet tile layer stored under:

```text
source/public/mapStyles/styleSatelite/
```

The tile loader supports a mixture of `.jpg` tiles and `.png` fallback tiles. Preserve the existing zoom, `x`, and `y` directory structure when replacing or modifying the tiles.

Files placed in `source/public/` are copied into `web/` during every build. Large tile collections will therefore increase the resource download size for connecting players.

The GTA V map implementation was inspired by [RiceaRaul/gta-v-map-leaflet](https://github.com/RiceaRaul/gta-v-map-leaflet). Ensure that any third-party map assets you distribute comply with their applicable license and attribution requirements.

## NUI integration

Browser lifecycle and game integration are handled by the resource's Lua files. The frontend communicates through `source/src/lib/nui.ts` and listens for NUI messages in `App.vue`.

Important rules when extending the interface:

- Treat all frontend data as untrusted.
- Keep purchases, transfers, relinquishing, balances, reputation requirements, and ownership validation server-side.
- Return a fresh browser snapshot after state-changing actions.
- Use localized reason codes for action failures instead of hardcoded frontend messages.
- Keep `base: './'` in `vite.config.ts`; relative asset paths are required by FiveM NUI.
- Never place credentials, secrets, or authoritative game logic in Vue, JavaScript, HTML, or CSS files.

## Common issues

### The UI is blank in a normal browser

This is expected in the production source. The interface remains hidden until FiveM sends the browser-open event and bootstrap data.

### Changes do not appear in FiveM

Confirm that `npm run build` completed successfully, that the new files exist in `web/`, and that `t1ger_moneywash` was restarted. If necessary, clear the FiveM client cache.

### The map is blank but markers are visible

Confirm that the satellite tiles exist under `source/public/mapStyles/styleSatelite/`, rebuild the UI, and verify that the corresponding files were copied to `web/mapStyles/styleSatelite/`.

### TypeScript prevents the build

Run:

```bash
npx vue-tsc -b
```

Resolve the reported error before rebuilding. Avoid bypassing type checking because malformed NUI data can otherwise fail silently at runtime.

## Support and licensing

This source is provided as part of the source-code edition of `t1ger_moneywash` and remains subject to the license and distribution terms attached to the purchase.

Do not redistribute, resell, or publicly publish the source or compiled map assets unless your license explicitly permits it.

For product support, use the official T1GER Scripts support channels and include any relevant client/server console errors when reporting an issue.
