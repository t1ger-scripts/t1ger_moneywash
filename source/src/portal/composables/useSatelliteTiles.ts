import { ref } from 'vue'
import L from 'leaflet'

import { MAXIMUM_MAP_ZOOM, mapBounds } from '@/portal/map/gtaMap'

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

    /** Loads the satellite tiles onto the map. */
    function loadSatelliteTiles(): void {
        const map = getMap()
        if (!map) return

        tileLayer?.remove()
        clearLoadingTimeout()

        isLoading.value = true
        hasTileError.value = false

        tileLayer = L.tileLayer(
            `./mapStyles/styleSatelite/{z}/{x}/{y}.jpg`,
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

        tileLayer.addTo(map)
        tileLayer.bringToBack()

        loadingTimeout = setTimeout(() => {
            if (!isLoading.value) return

            isLoading.value = false
            hasTileError.value = true
        }, LOADING_TIMEOUT_MS)
    }

    function retryMapTiles(): void {
        loadSatelliteTiles()
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