# t1ger_moneywash browser UI

A standalone local-development frontend for the `t1ger_moneywash` FiveM resource. It provides a dark-web-style marketplace, reputation-gated tiers, all configured business locations, and an interactive GTA V map.

## Stack

- Vue 3 + TypeScript for components and typed business data
- Vite for fast local development and a static FiveM-ready build
- Leaflet for GTA-coordinate markers, zooming and panning
- Lucide Vue for icons

No web framework is required at runtime. `npm run build` produces static files in `../web`.

## Run locally

```bash
npm install
npm run dev
```

Open the local URL printed by Vite. Use the `Preview RP` slider to test locked and unlocked states. Select a tier, then click a listing or map marker to zoom to the site.

## Build for FiveM

```bash
npm run build
```

The output is written to the sibling `web/` directory, ready to be referenced by `fxmanifest.lua`:

```lua
ui_page 'web/index.html'

files {
    'web/index.html',
    'web/assets/**/*',
}
```

The NUI callbacks are already isolated in `src/lib/nui.ts`. Local development safely no-ops those requests. Later, replace the mock data with `window.postMessage` data sent by Lua and keep sensitive availability/ownership validation server-side.

## Map tiles

Local preview currently defaults to:

```text
https://www.gtamap.xyz/mapStyles/styleAtlas/{z}/{x}/{y}.jpg
```

Override it in `.env.local` with `VITE_MAP_TILES_URL`. For a production FiveM release, bundle the atlas tiles inside `public/mapStyles/` and set:

```text
VITE_MAP_TILES_URL=./mapStyles/styleAtlas/{z}/{x}/{y}.jpg
```

The GTA coordinate reference system and tile layout were adapted from [RiceaRaul/gta-v-map-leaflet](https://github.com/RiceaRaul/gta-v-map-leaflet), licensed under MIT. Keep its attribution/license if you copy a substantial portion of that project or distribute its tile package.

## Refresh mock data from Lua

During local prototyping, regenerate the typed mock source from the two configuration files:

```bash
node scripts/generate-mock-data.mjs /path/to/business.lua /path/to/business_locations.lua
```

The current supplied config generates 9 tiers and 96 location rows. The comment in `business_locations.lua` says 95, but the table currently contains 96.
