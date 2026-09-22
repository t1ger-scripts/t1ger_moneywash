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

function getLocationAddress(location: BusinessLocation): string {
    const { street, crossingRoad, zone } = location.address

    if (street && crossingRoad) {
        return `${street} / ${crossingRoad}`
    }

    return street || zone || ''
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

    const width = isSelected ? 46 : 38
    const height = isSelected ? 54 : 46

    return L.divIcon({
        className: 'business-map-marker-shell',
        html: markerElement,
        iconSize: [width, height],
        iconAnchor: [width / 2, height],
        tooltipAnchor: [0, -height + 4],
    })
}

function createMarkerTooltip(location: BusinessLocation): HTMLElement {
    const tooltip = document.createElement('span')
    const address = getLocationAddress(location)

    tooltip.textContent = address
        ? `${location.displayName} · ${address}`
        : location.displayName

    return tooltip
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
            title: location.displayName,
        })

        marker.bindTooltip(createMarkerTooltip(location), {
            direction: 'top',
            offset: [0, -4],
            opacity: 1,
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

    map.fitBounds(mapBounds, {
        animate: animated,
        duration: animated ? 0.65 : 0,
        padding: [12, 12],
    })
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

    const minimumZoom = Math.max(
        0,
        map.getBoundsZoom(mapBounds, true),
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

onMounted(async () => {
    await nextTick()

    if (!mapElement.value) {
        return
    }

    map = L.map(mapElement.value, {
        crs: gtaCrs,
        center: [0, 0],
        zoom: 3,
        minZoom: 1,
        maxZoom: MAXIMUM_MAP_ZOOM,
        zoomControl: false,
        attributionControl: false,
        maxBounds: mapBounds,
        maxBoundsViscosity: 1,
    })

    markerLayer = L.layerGroup().addTo(map)

    loadSatelliteTiles()
    renderMarkers()

    await nextTick()

    updateMinimumZoom()
    showEntireMap(false)

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
    <section class="business-location-map" :aria-label="t('marketplace.map.label')">
        <div ref="mapElement" class="business-location-map__canvas" />

        <div class="business-location-map__controls">
            <button type="button" class="business-location-map__control" :aria-label="t('marketplace.map.zoomIn')"
                :title="t('marketplace.map.zoomIn')" @click="zoomIn">
                <Plus :size="21" :stroke-width="2.2" />
            </button>

            <button type="button" class="business-location-map__control" :aria-label="t('marketplace.map.zoomOut')"
                :title="t('marketplace.map.zoomOut')" @click="zoomOut">
                <Minus :size="21" :stroke-width="2.2" />
            </button>

            <span class="business-location-map__control-divider" />

            <button type="button" class="business-location-map__control" :aria-label="t('marketplace.map.showAll')"
                :title="t('marketplace.map.showAll')" @click="showEntireMap()">
                <LocateFixed :size="20" :stroke-width="2.1" />
            </button>
        </div>

        <div v-if="isLoading" class="business-location-map__status" role="status">
            <span class="business-location-map__spinner" />

            <strong>{{ t('marketplace.map.loadingTitle') }}</strong>

            <span>{{ t('marketplace.map.loadingDescription') }}</span>
        </div>

        <div v-else-if="hasTileError" class="business-location-map__status" role="alert">
            <TriangleAlert :size="30" :stroke-width="1.8" />

            <strong>{{ t('marketplace.map.unavailableTitle') }}</strong>

            <span>{{ t('marketplace.map.unavailableDescription') }}</span>

            <button type="button" class="business-location-map__retry" @click="retryMapTiles">
                <RotateCcw :size="16" />
                {{ t('marketplace.map.retry') }}
            </button>
        </div>
    </section>
</template>

<style scoped lang="scss">
.business-location-map {
    position: relative;
    min-width: 0;
    min-height: 0;
    overflow: hidden;
    border: 1px solid var(--color-border-default);
    border-radius: var(--radius-lg);
    background: var(--color-surface-raised);
    box-shadow: var(--shadow-panel);

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
        border: 1px solid var(--color-border-strong);
        border-radius: var(--radius-md);
        background: color-mix(in srgb,
                var(--color-surface-overlay) 94%,
                transparent);
        box-shadow: var(--shadow-lg);
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
            color var(--transition-fast),
            background-color var(--transition-fast);

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
        background: var(--color-border-default);
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

:global(.business-map-marker-shell) {
    border: 0;
    background: transparent;
}

:global(.business-map-marker) {
    position: relative;
    display: grid;
    width: 2.35rem;
    height: 2.85rem;
    justify-items: center;
    padding-top: 0.52rem;
    color: #ffffff;
    filter: drop-shadow(0 4px 7px rgb(0 0 0 / 45%));
    transform-origin: center bottom;
    transition:
        transform var(--transition-fast),
        filter var(--transition-fast);
}

:global(.business-map-marker::before) {
    position: absolute;
    top: 0;
    left: 0;
    width: 2.35rem;
    height: 2.35rem;
    border: 2px solid #ffffff;
    border-radius: 50%;
    background: var(--color-primary);
    content: '';
}

:global(.business-map-marker::after) {
    position: absolute;
    bottom: 0.08rem;
    left: 50%;
    border-top: 0.9rem solid var(--color-primary);
    border-right: 0.53rem solid transparent;
    border-left: 0.53rem solid transparent;
    content: '';
    transform: translateX(-50%);
}

:global(.business-map-marker--owned::before) {
    background: var(--color-success);
}

:global(.business-map-marker--owned::after) {
    border-top-color: var(--color-success);
}

:global(.business-map-marker--selected) {
    filter:
        drop-shadow(0 0 6px var(--color-primary)) drop-shadow(0 0 14px var(--color-primary));
    transform: scale(1.18);
}

:global(.business-map-marker--selected::before) {
    border-width: 3px;
    background: var(--color-primary);
}

:global(.business-map-marker--selected::after) {
    border-top-color: var(--color-primary);
}

:global(.business-map-marker__icon) {
    position: relative;
    z-index: 1;
    display: grid;
    place-items: center;
}

:global(.leaflet-tooltip) {
    padding: 0.5rem 0.7rem;
    border: 1px solid var(--color-border-strong);
    border-radius: var(--radius-sm);
    color: var(--color-text-primary);
    font-family: var(--font-family-body);
    font-size: var(--font-size-sm);
    font-weight: var(--font-weight-semibold);
    background: var(--color-surface-overlay);
    box-shadow: var(--shadow-md);
}

:global(.leaflet-tooltip-top::before) {
    border-top-color: var(--color-surface-overlay);
}

@keyframes map-spin {
    to {
        transform: rotate(360deg);
    }
}
</style>