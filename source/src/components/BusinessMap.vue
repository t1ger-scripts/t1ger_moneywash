<script setup lang="ts">
import { nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import L from 'leaflet'
import { LocateFixed, Minus, Plus, RotateCcw, TriangleAlert, } from '@lucide/vue'
import { t } from '@/lib/locale'
import type { LocationView } from '@/types/business'

const props = defineProps<{
  locations: LocationView[]
  selected?: LocationView
}>()

const emit = defineEmits<{ select: [location: LocationView] }>()
type TileExtension = 'jpg' | 'png'
const MAXIMUM_MAP_ZOOM = 5

const mapEl = ref<HTMLElement | null>(null)

const isMapLoading = ref(true)
const hasMapError = ref(false)

let successfulTileLoads = 0
let failedTileLoads = 0
let mapLoadTimer: number | undefined
let activeTileLayer: L.TileLayer | undefined

let map: L.Map | undefined
let markers = L.layerGroup()
let resizeObserver: ResizeObserver | undefined

const mapBounds = L.latLngBounds([
  [-4000, -5500],
  [8000, 6000],
])

const gtaCrs = Object.assign({}, L.CRS.Simple, {
  projection: L.Projection.LonLat,
  scale: (zoom: number) => 2 ** zoom,
  zoom: (scale: number) => Math.log(scale) / Math.LN2,
  distance: (a: L.LatLng, b: L.LatLng) => Math.hypot(b.lng - a.lng, b.lat - a.lat),
  transformation: new L.Transformation(0.02072, 117.3, -0.0205, 172.8),
  infinite: true,
})

function createMixedTileLayer(
  folder: string,
  maxZoom: number,
  preferredExtension: TileExtension = 'jpg',
) {
  const fallbackExtension: TileExtension =
    preferredExtension === 'jpg' ? 'png' : 'jpg'

  const layer = L.tileLayer(
    `./mapStyles/${folder}/{z}/{x}/{y}.${preferredExtension}`,
    {
      minZoom: 0,
      maxZoom,
      noWrap: true,
      keepBuffer: 2,
    },
  )

  layer.on('tileload', () => {
    successfulTileLoads += 1
  })

  layer.on('tileerror', (event: L.TileErrorEvent) => {
    const tile = event.tile as HTMLImageElement

    if (tile.dataset.fallbackAttempted === 'true') {
      failedTileLoads += 1
      return
    }

    tile.dataset.fallbackAttempted = 'true'
    tile.src = tile.src.replace(
      `.${preferredExtension}`,
      `.${fallbackExtension}`,
    )
  })

  layer.on('load', () => {
    if (successfulTileLoads > 0) {
      window.clearTimeout(mapLoadTimer)

      isMapLoading.value = false
      hasMapError.value = false
      return
    }

    if (failedTileLoads > 0) {
      window.clearTimeout(mapLoadTimer)

      isMapLoading.value = false
      hasMapError.value = true
    }
  })

  return layer
}

function loadSatelliteTiles() {
  if (!map) return

  window.clearTimeout(mapLoadTimer)

  isMapLoading.value = true
  hasMapError.value = false
  successfulTileLoads = 0
  failedTileLoads = 0

  if (activeTileLayer) {
    map.removeLayer(activeTileLayer)
  }

  activeTileLayer = createMixedTileLayer(
    'styleSatelite',
    MAXIMUM_MAP_ZOOM,
  )

  activeTileLayer.addTo(map)

  mapLoadTimer = window.setTimeout(() => {
    if (successfulTileLoads > 0) {
      isMapLoading.value = false
      hasMapError.value = false
      return
    }

    isMapLoading.value = false
    hasMapError.value = true
  }, 6000)
}

function updateMinimumZoom() {
  if (!map) return

  map.invalidateSize({ pan: false })

  const minimumZoom = map.getBoundsZoom(mapBounds, true)

  map.setMinZoom(minimumZoom)

  if (map.getZoom() < minimumZoom) {
    map.setZoom(minimumZoom)
  }
}

function renderMarkers() {
  if (!map) return
  markers.clearLayers()

  props.locations.forEach((location) => {
    const selected = props.selected?.uid === location.uid
    const markerId = String(location.id).padStart(2, '0')

    const icon = L.divIcon({
      className: 'map-marker-shell',
      html: `
    <span class="map-pin${selected ? ' selected' : ''}${location.locked ? ' locked' : ''}">
      <svg viewBox="0 0 32 42" aria-hidden="true">
        <path
          class="map-pin-shape"
          d="M16 1C7.7 1 1 7.7 1 16c0 11 15 25 15 25s15-14 15-25C31 7.7 24.3 1 16 1Z"
        />
        <text
          class="map-pin-id"
          x="16"
          y="16"
          text-anchor="middle"
          dominant-baseline="middle"
        >${markerId}</text>
      </svg>
    </span>
  `,
      iconSize: selected ? [31, 41] : [26, 35],
      iconAnchor: selected ? [16, 40] : [13, 34],
    })

    const locationLabel = location.street
      ? `${location.brand} · ${location.street}`
      : `${location.brand} · ${location.zone}`

    L.marker([location.coords.y, location.coords.x], {
      icon,
      title: locationLabel,
    })
      .bindTooltip(locationLabel, {
        direction: 'top',
        offset: [0, -32],
        opacity: 1,
      })
      .on('click', () => emit('select', location))
      .addTo(markers)
  })
}

function focusSelected(animated = true) {
  if (!map || !props.selected) return
  map.flyTo([props.selected.coords.y, props.selected.coords.x], 5, { animate: animated, duration: 0.75 })
}

function showAll() {
  if (!map || !props.locations.length) return
  const bounds = L.latLngBounds(props.locations.map((item) => [item.coords.y, item.coords.x]))
  map.fitBounds(bounds, { padding: [48, 48], maxZoom: 4, animate: true })
}

onMounted(async () => {
  await nextTick()
  if (!mapEl.value) return

  map = L.map(mapEl.value, {
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

  updateMinimumZoom()

  resizeObserver = new ResizeObserver(() => {
    updateMinimumZoom()
  })

  resizeObserver.observe(mapEl.value)

  loadSatelliteTiles()
  markers.addTo(map)
  renderMarkers()
  showAll()
})

watch(() => props.locations, () => { renderMarkers(); if (!props.selected) showAll() }, { deep: true })
watch(() => props.selected?.uid, () => { renderMarkers(); focusSelected() })

onBeforeUnmount(() => {
  window.clearTimeout(mapLoadTimer)
  resizeObserver?.disconnect()
  map?.remove()
})
</script>

<template>
  <section class="map-panel">
    <div ref="mapEl" class="leaflet-map" />
    <Transition name="map-state" mode="out-in">
      <div v-if="isMapLoading" key="loading" class="map-loading-state" role="status">
        <span class="map-loading-spinner" />

        <span>
          <strong>{{ t('browser.map.loading_title') }}</strong>
          <small>{{ t('browser.map.loading_description') }}</small>
        </span>
      </div>

      <div v-else-if="hasMapError" key="error" class="map-error-state" role="alert">
        <span class="map-error-icon">
          <TriangleAlert :size="18" />
        </span>

        <span>
          <strong>{{ t('browser.map.unavailable_title') }}</strong>
          <small>
            {{ t('browser.map.unavailable_description') }}
          </small>
        </span>

        <button type="button" @click="loadSatelliteTiles">
          <RotateCcw :size="13" />
          {{ t('browser.map.retry') }}
        </button>
      </div>
    </Transition>

    <div class="map-label">
      <span class="live-pulse" />
      {{ t('browser.map.label') }}
    </div>

    <div class="map-actions">
      <button :title="t('browser.map.zoom_in')" @click="map?.zoomIn()">
        <Plus :size="17" />
      </button>

      <button :title="t('browser.map.zoom_out')" @click="map?.zoomOut()">
        <Minus :size="17" />
      </button>

      <button :title="t('browser.map.show_all')" @click="showAll">
        <LocateFixed :size="17" />
      </button>
    </div>

    <div class="map-legend">
      <span>
        <i class="legend-dot available" />
        {{ t('browser.map.legend_available') }}
      </span>

      <span>
        <i class="legend-dot selected" />
        {{ t('browser.map.legend_selected') }}
      </span>

      <span>
        <i class="legend-dot locked" />
        {{ t('browser.map.legend_score_required') }}
      </span>
    </div>
  </section>
</template>
