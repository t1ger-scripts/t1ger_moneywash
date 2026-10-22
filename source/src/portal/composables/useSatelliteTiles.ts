import { ref } from 'vue'
import L from 'leaflet'

import { MAXIMUM_MAP_ZOOM, mapBounds } from '@/portal/map/gtaMap'

type TileExtension = 'jpg' | 'png'

const LOADING_TIMEOUT_MS = 7000

/** Loads the satellite tiles onto a map and tracks whether they loaded. */
export function useSatelliteTiles(getMap: () => L.Map | null) {
    const isLoading = ref(true)
    const hasTileError = ref(false)

    let tileLayer: L.TileLayer | null = null
    let loadingTimeout: ReturnType<typeof setTimeout> | null = null

    function clearLoadingTimeout(): void {
        if (!loadingTimeout) return

        clearTimeout(loadingTimeout)
        loadingTimeout = null
    }

    /** Tiles may be .jpg or .png; if a tile fails, it is tried once with the other one. */
    function loadSatelliteTiles(preferredExtension: TileExtension = 'jpg'): void {
        const map = getMap()
        if (!map) return

        tileLayer?.remove()
        clearLoadingTimeout()

        isLoading.value = true
        hasTileError.value = false

        tileLayer = L.tileLayer(
            `./mapStyles/styleSatelite/{z}/{x}/{y}.${preferredExtension}`,
            {
                minZoom: 0,
                maxZoom: MAXIMUM_MAP_ZOOM,
                noWrap: true,
                updateWhenZooming: true,
                updateWhenIdle: false,
                updateInterval: 200,
                keepBuffer: 2,
                bounds: mapBounds,
            },
        )

        tileLayer.on('tileload', () => {
            clearLoadingTimeout()
            isLoading.value = false
            hasTileError.value = false
        })

        tileLayer.on('tileerror', (event: L.TileErrorEvent) => {
            const tile = event.tile as HTMLImageElement
            if (tile.dataset.fallbackAttempted === 'true') return

            tile.dataset.fallbackAttempted = 'true'

            const fallbackExtension: TileExtension = preferredExtension === 'jpg' ? 'png' : 'jpg'
            tile.src = tile.src.replace(/\.(jpg|png)$/, `.${fallbackExtension}`)
        })

        tileLayer.addTo(map)
        tileLayer.bringToBack()

        loadingTimeout = setTimeout(() => {
            if (!isLoading.value) return

            isLoading.value = false
            hasTileError.value = true
        }, LOADING_TIMEOUT_MS)
    }

    function retryMapTiles(): void {
        loadSatelliteTiles('jpg')
    }

    /** Call when the map is removed. */
    function disposeSatelliteTiles(): void {
        clearLoadingTimeout()
        tileLayer = null
    }

    return {
        isLoading,
        hasTileError,
        loadSatelliteTiles,
        retryMapTiles,
        disposeSatelliteTiles,
    }
}