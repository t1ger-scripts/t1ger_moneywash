<script setup lang="ts">
import { h, nextTick, onBeforeUnmount, onMounted, ref, render, watch } from 'vue'
import { LocateFixed, Minus, Plus, RotateCcw, TriangleAlert } from '@lucide/vue'
import { useI18n } from 'vue-i18n'
import L from 'leaflet'

import type { BusinessLocation } from '@/domain/marketplace'
import { useMarketplaceStore } from '@/stores/marketplace.store'

import BusinessTypeIcon from './BusinessTypeIcon.vue'

type TileExtension = 'jpg' | 'png'

const MAXIMUM_MAP_ZOOM = 5
const SELECTED_LOCATION_ZOOM = 5
const OVERVIEW_ZOOM_OFFSET = 0.20

const { t } = useI18n()
const marketplaceStore = useMarketplaceStore()

const mapElement = ref<HTMLDivElement | null>(null)
const isLoading = ref(true)
const hasTileError = ref(false)

let map: L.Map | null = null
let satelliteLayer: L.TileLayer | null = null
let markerLayer: L.LayerGroup | null = null
let resizeObserver: ResizeObserver | null = null
let loadingTimeout: ReturnType<typeof setTimeout> | null = null

const renderedIconHosts: HTMLElement[] = []

const mapBounds = L.latLngBounds([
    [-4000, -5500],
    [8000, 6000],
])

const gtaCrs = Object.assign({}, L.CRS.Simple, {
    projection: L.Projection.LonLat,

    scale(zoom: number) {
        return 2 ** zoom
    },

    zoom(scale: number) {
        return Math.log(scale) / Math.LN2
    },

    distance(firstPoint: L.LatLng, secondPoint: L.LatLng) {
        return Math.hypot(
            secondPoint.lng - firstPoint.lng,
            secondPoint.lat - firstPoint.lat,
        )
    },

    transformation: new L.Transformation(
        0.02072,
        117.3,
        -0.0205,
        172.8,
    ),

    infinite: true,
})

function getLocationCoordinates(location: BusinessLocation): L.LatLngExpression {
    return [location.coordinates.y, location.coordinates.x]
}

function clearRenderedIcons() {
    for (const iconHost of renderedIconHosts) {
        render(null, iconHost)
    }

    renderedIconHosts.length = 0
}

function createMarkerIcon(
    location: BusinessLocation,
    isSelected: boolean,
): L.DivIcon {
    const markerElement = document.createElement('span')
    const iconHost = document.createElement('span')

    markerElement.classList.add('business-map-marker')

    markerElement.classList.add(
        location.ownership === 'ownedByPlayer'
            ? 'business-map-marker--owned'
            : 'business-map-marker--available',
    )

    if (isSelected) {
        markerElement.classList.add('business-map-marker--selected')
    }

    iconHost.classList.add('business-map-marker__icon')
    markerElement.append(iconHost)

    render(
        h(BusinessTypeIcon, {
            businessType: location.businessType,
            size: isSelected ? 19 : 17,
            strokeWidth: 2.35,
        }),
        iconHost,
    )

    renderedIconHosts.push(iconHost)

    const width = 40
    const height = 48

    return L.divIcon({
        className: 'business-map-marker-shell',
        html: markerElement,
        iconSize: [width, height],
        iconAnchor: [width / 2, height]
    })
}

function renderMarkers() {
    if (!map || !markerLayer) {
        return
    }

    markerLayer.clearLayers()
    clearRenderedIcons()

    for (const location of marketplaceStore.selectedTierLocations) {
        const isSelected =
            marketplaceStore.selectedLocationId === location.id

        const marker = L.marker(getLocationCoordinates(location), {
            icon: createMarkerIcon(location, isSelected),
            keyboard: true,
            riseOnHover: true,
        })

        marker.on('click', () => {
            marketplaceStore.selectLocation(location.id)
        })

        marker.addTo(markerLayer)
    }
}

function focusSelectedLocation(animated = true) {
    if (!map || !marketplaceStore.selectedLocation) {
        return
    }

    map.flyTo(
        getLocationCoordinates(marketplaceStore.selectedLocation),
        SELECTED_LOCATION_ZOOM,
        {
            animate: animated,
            duration: animated ? 0.75 : 0,
        },
    )
}

function showEntireMap(animated = true) {
    if (!map) {
        return
    }

    map.invalidateSize(false)

    const overviewZoom = map.getMinZoom()
    const zoomDistance = Math.abs(map.getZoom() - overviewZoom)
    const shouldAnimate = animated && zoomDistance <= 1

    map.setView(
        mapBounds.getCenter(),
        overviewZoom,
        {
            animate: shouldAnimate,
            duration: shouldAnimate ? 0.65 : 0,
        },
    )
}

function zoomIn() {
    map?.zoomIn()
}

function zoomOut() {
    map?.zoomOut()
}

function updateMinimumZoom() {
    if (!map) {
        return
    }

    map.invalidateSize(false)

    const fittedZoom = map.getBoundsZoom(
        mapBounds,
        false,
        L.point(12, 12),
    )

    const minimumZoom = Math.min(
        MAXIMUM_MAP_ZOOM,
        Math.max(0, fittedZoom + OVERVIEW_ZOOM_OFFSET),
    )

    map.setMinZoom(minimumZoom)
}

function clearLoadingTimeout() {
    if (!loadingTimeout) {
        return
    }

    clearTimeout(loadingTimeout)
    loadingTimeout = null
}

function loadSatelliteTiles(preferredExtension: TileExtension = 'jpg') {
    if (!map) {
        return
    }

    if (satelliteLayer) {
        satelliteLayer.remove()
        satelliteLayer = null
    }

    clearLoadingTimeout()

    isLoading.value = true
    hasTileError.value = false

    satelliteLayer = L.tileLayer(
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

    satelliteLayer.on('tileload', () => {
        clearLoadingTimeout()
        isLoading.value = false
        hasTileError.value = false
    })

    satelliteLayer.on('tileerror', (event: L.TileErrorEvent) => {
        const tile = event.tile as HTMLImageElement

        if (tile.dataset.fallbackAttempted === 'true') {
            return
        }

        tile.dataset.fallbackAttempted = 'true'

        const fallbackExtension: TileExtension =
            preferredExtension === 'jpg' ? 'png' : 'jpg'

        tile.src = tile.src.replace(
            /\.(jpg|png)$/,
            `.${fallbackExtension}`,
        )
    })

    satelliteLayer.addTo(map)
    satelliteLayer.bringToBack()

    loadingTimeout = setTimeout(() => {
        if (isLoading.value) {
            isLoading.value = false
            hasTileError.value = true
        }
    }, 7000)
}

function retryMapTiles() {
    loadSatelliteTiles('jpg')
}

function setMapInteractionState(isInteracting: boolean) {
    mapElement.value?.classList.toggle(
        'business-location-map__canvas--interacting',
        isInteracting,
    )
}

onMounted(async () => {
    await nextTick()

    if (!mapElement.value) {
        return
    }

    map = L.map(mapElement.value, {
        crs: gtaCrs,
        center: [0, 0],
        zoom: 3,
        minZoom: 0,
        maxZoom: MAXIMUM_MAP_ZOOM,
        zoomAnimation: true,
        fadeAnimation: true,
        markerZoomAnimation: true,
        zoomSnap: 0.25,
        zoomDelta: 0.5,
        zoomControl: false,
        attributionControl: false,
        maxBounds: mapBounds,
        maxBoundsViscosity: 1,
    })

    map.on('movestart', () => {
        setMapInteractionState(true)
    })

    map.on('moveend', () => {
        setMapInteractionState(false)
    })

    markerLayer = L.layerGroup().addTo(map)

    loadSatelliteTiles()
    renderMarkers()

    await nextTick()

    updateMinimumZoom()

    if (marketplaceStore.selectedLocation) {
        focusSelectedLocation(false)
    } else {
        showEntireMap(false)
    }

    resizeObserver = new ResizeObserver(() => {
        updateMinimumZoom()
    })

    resizeObserver.observe(mapElement.value)
})

watch(
    () => marketplaceStore.selectedTierLocations,
    () => {
        renderMarkers()

        if (marketplaceStore.selectedLocation) {
            focusSelectedLocation(false)
        } else {
            showEntireMap()
        }
    },
    {
        deep: true,
    },
)

watch(
    () => marketplaceStore.selectedLocationId,
    (selectedLocationId) => {
        renderMarkers()

        if (selectedLocationId) {
            focusSelectedLocation()
        } else {
            showEntireMap()
        }
    },
)

onBeforeUnmount(() => {
    clearLoadingTimeout()
    resizeObserver?.disconnect()
    clearRenderedIcons()
    map?.remove()

    resizeObserver = null
    markerLayer = null
    satelliteLayer = null
    map = null
})
</script>

<template>
    <section class="business-location-map" :aria-label="t('portal.map.ariaLabel')">
        <div ref="mapElement" class="business-location-map__canvas" />

        <div class="business-location-map__controls">
            <button type="button" class="business-location-map__control" :aria-label="t('portal.map.zoomIn')"
                :title="t('portal.map.zoomIn')" @click="zoomIn">
                <Plus :size="21" :stroke-width="2.2" />
            </button>

            <button type="button" class="business-location-map__control" :aria-label="t('portal.map.zoomOut')"
                :title="t('portal.map.zoomOut')" @click="zoomOut">
                <Minus :size="21" :stroke-width="2.2" />
            </button>

            <span class="business-location-map__control-divider" />

            <button type="button" class="business-location-map__control" :aria-label="t('portal.map.showEntireMap')"
                :title="t('portal.map.showEntireMap')" @click="showEntireMap()">
                <LocateFixed :size="20" :stroke-width="2.1" />
            </button>
        </div>

        <div v-if="isLoading" class="business-location-map__status" role="status">
            <span class="business-location-map__spinner" />

            <strong>{{ t('portal.map.loadingTitle') }}</strong>

            <span>{{ t('portal.map.loadingDescription') }}</span>
        </div>

        <div v-else-if="hasTileError" class="business-location-map__status" role="alert">
            <TriangleAlert :size="30" :stroke-width="1.8" />

            <strong>{{ t('portal.map.unavailableTitle') }}</strong>

            <span>{{ t('portal.map.unavailableDescription') }}</span>

            <button type="button" class="business-location-map__retry" @click="retryMapTiles">
                <RotateCcw :size="16" />
                {{ t('portal.map.retry') }}
            </button>
        </div>
    </section>
</template>

<style scoped lang="scss">
.business-location-map {
    position: relative;
    z-index: var(--z-index-map);
    isolation: isolate;
    min-width: 0;
    min-height: 0;
    overflow: hidden;
    border: var(--border-width) solid var(--color-border);
    border-radius: var(--radius-lg);
    background: var(--color-surface-raised);
    box-shadow: var(--shadow-surface);

    &__canvas {
        width: 100%;
        height: 100%;
        min-height: 34rem;
        background: var(--color-surface-raised);
    }

    &__controls {
        position: absolute;
        z-index: 500;
        top: var(--space-4);
        right: var(--space-4);
        display: flex;
        flex-direction: column;
        overflow: hidden;
        border: var(--border-width) solid var(--color-border-strong);
        border-radius: var(--radius-md);
        background: color-mix(in srgb,
                var(--color-surface) 94%,
                transparent);
        box-shadow: var(--shadow-surface);
        backdrop-filter: blur(12px);
    }

    &__control {
        display: grid;
        width: 2.85rem;
        height: 2.85rem;
        place-items: center;
        border: 0;
        color: var(--color-text-primary);
        background: transparent;
        cursor: pointer;
        transition:
            color var(--duration-fast) var(--ease-standard),
            background-color var(--duration-fast) var(--ease-standard);

        &:hover {
            color: var(--color-primary);
            background: var(--color-surface-hover);
        }

        &:focus-visible {
            position: relative;
            z-index: 1;
            outline: 2px solid var(--color-primary);
            outline-offset: -3px;
        }
    }

    &__control-divider {
        height: 1px;
        margin-inline: var(--space-2);
        background: var(--color-border);
    }

    &__status {
        position: absolute;
        z-index: 450;
        inset: 0;
        display: flex;
        align-items: center;
        justify-content: center;
        flex-direction: column;
        gap: var(--space-2);
        padding: var(--space-6);
        color: var(--color-text-muted);
        text-align: center;
        background: color-mix(in srgb,
                var(--color-surface-raised) 92%,
                transparent);

        strong {
            color: var(--color-text-primary);
            font-size: var(--font-size-lg);
        }
    }

    &__spinner {
        width: 2rem;
        height: 2rem;
        margin-bottom: var(--space-2);
        border: 3px solid var(--color-border-strong);
        border-top-color: var(--color-primary);
        border-radius: 50%;
        animation: map-spin 800ms linear infinite;
    }

    &__retry {
        display: inline-flex;
        align-items: center;
        gap: var(--space-2);
        margin-top: var(--space-2);
        padding: 0.6rem 0.9rem;
        border: 1px solid var(--color-primary);
        border-radius: var(--radius-md);
        color: var(--color-primary);
        background: transparent;
        cursor: pointer;
    }
}

.business-location-map__canvas {
    background-color: #000;

    :global(.leaflet-container img.leaflet-tile) {
        mix-blend-mode: screen;
    }
}

:global(.business-map-marker-shell) {
    border: 0;
    background: transparent;
}

:global(.business-map-marker) {
    position: relative;
    isolation: isolate;
    width: 2.5rem;
    height: 3rem;
    color: #ffffff;
    filter: drop-shadow(0 4px 6px rgb(0 0 0 / 55%));
    transform-origin: center bottom;
    transition:
        transform var(--duration-fast) var(--ease-standard),
        filter var(--duration-fast) var(--ease-standard);
}

:global(.business-map-marker::before) {
    position: absolute;
    z-index: 1;
    top: 0.2rem;
    left: 50%;
    width: 2rem;
    height: 2rem;
    border: 2px solid #ffffff;
    border-radius: 50% 50% 50% 0;
    background: var(--color-primary);
    box-shadow: inset 0 0 0 1px rgb(255 255 255 / 12%);
    content: '';
    transform: translateX(-50%) rotate(-45deg);
}

:global(.business-map-marker--owned::before) {
    background: var(--color-success);
}

:global(.business-map-marker--selected) {
    filter:
        drop-shadow(0 0 5px var(--color-primary)) drop-shadow(0 0 12px var(--color-primary));
    transform: scale(1.12);
}

:global(.business-map-marker--selected::before) {
    border-width: 2px;
    background: var(--color-primary);
}

:global(.business-map-marker--selected::after) {
    position: absolute;
    z-index: 0;
    top: -0.38rem;
    left: 50%;
    width: 3.2rem;
    height: 3.2rem;
    border: 2px solid color-mix(in srgb,
            var(--color-primary) 85%,
            #ffffff);
    border-radius: 50%;
    background: color-mix(in srgb,
            var(--color-primary) 16%,
            transparent);
    box-shadow:
        0 0 0 0.28rem rgb(47 129 247 / 14%),
        0 0 1rem rgb(47 129 247 / 75%);
    content: '';
    transform: translateX(-50%);
}

:global(.business-map-marker--owned.business-map-marker--selected) {
    filter:
        drop-shadow(0 0 5px var(--color-success))
        drop-shadow(0 0 12px var(--color-success));
}

:global(.business-map-marker--owned.business-map-marker--selected::before) {
    background: var(--color-success);
}

:global(.business-map-marker--owned.business-map-marker--selected::after) {
    border-color:
        color-mix(
            in srgb,
            var(--color-success) 85%,
            #ffffff
        );
    background:
        color-mix(
            in srgb,
            var(--color-success) 16%,
            transparent
        );
    box-shadow:
        0 0 0 0.28rem
            color-mix(
                in srgb,
                var(--color-success) 14%,
                transparent
            ),
        0 0 1rem
            color-mix(
                in srgb,
                var(--color-success) 75%,
                transparent
            );
}

:global(.business-map-marker__icon) {
    position: absolute;
    z-index: 2;
    top: 0.62rem;
    left: 50%;
    display: grid;
    place-items: center;
    transform: translateX(-50%);
}

@keyframes map-spin {
    to {
        transform: rotate(360deg);
    }
}
</style>