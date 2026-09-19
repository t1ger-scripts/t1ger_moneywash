<script setup lang="ts">
import { nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import L from 'leaflet'
import { LocateFixed, Minus, Plus } from '@lucide/vue'
import type { LocationView } from '@/types/business'

const props = defineProps<{
  locations: LocationView[]
  selected?: LocationView
}>()

const emit = defineEmits<{ select: [location: LocationView] }>()
type MapStyle = 'atlas' | 'satellite'
type TileExtension = 'jpg' | 'png'

const mapEl = ref<HTMLElement | null>(null)
const mapStyle = ref<MapStyle>('atlas')
let map: L.Map | undefined
let markers = L.layerGroup()
let activeTileLayer: L.TileLayer | undefined

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
  const fallbackExtension: TileExtension = preferredExtension === 'jpg' ? 'png' : 'jpg'
  const layer = L.tileLayer(`./mapStyles/${folder}/{z}/{x}/{y}.${preferredExtension}`, {
    minZoom: 0,
    maxZoom,
    noWrap: true,
    keepBuffer: 2,
  })

  layer.on('tileerror', (event: L.TileErrorEvent) => {
    const tile = event.tile as HTMLImageElement
    if (tile.dataset.fallbackAttempted === 'true') return

    tile.dataset.fallbackAttempted = 'true'
    tile.src = tile.src.replace(`.${preferredExtension}`, `.${fallbackExtension}`)
  })

  return layer
}

function setMapStyle(style: MapStyle) {
  if (!map || (mapStyle.value === style && activeTileLayer)) return

  mapStyle.value = style
  if (activeTileLayer) map.removeLayer(activeTileLayer)

  const maxZoom = style === 'satellite' ? 8 : 5
  map.setMaxZoom(maxZoom)
  if (map.getZoom() > maxZoom) map.setZoom(maxZoom)

  activeTileLayer = style === 'atlas'
    ? createMixedTileLayer('styleAtlas', 5)
    : createMixedTileLayer('styleSatelite', 8)

  activeTileLayer.addTo(map)
}

function renderMarkers() {
  if (!map) return
  markers.clearLayers()

  props.locations.forEach((location) => {
    const selected = props.selected?.uid === location.uid
    const icon = L.divIcon({
      className: 'map-marker-shell',
      html: `<span class="map-marker${selected ? ' selected' : ''}${location.locked ? ' locked' : ''}"><i></i><b>${location.id}</b></span>`,
      iconSize: selected ? [40, 40] : [31, 31],
      iconAnchor: selected ? [20, 20] : [15, 15],
    })

    L.marker([location.coords.y, location.coords.x], { icon, title: location.brand })
      .bindTooltip(location.brand, { direction: 'top', offset: [0, -14], opacity: 1 })
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
    maxZoom: 8,
    zoomControl: false,
    attributionControl: false,
    maxBounds: [[-4000, -5500], [8000, 6000]],
    maxBoundsViscosity: 1,
  })

  setMapStyle('atlas')
  markers.addTo(map)
  renderMarkers()
  showAll()
})

watch(() => props.locations, () => { renderMarkers(); if (!props.selected) showAll() }, { deep: true })
watch(() => props.selected?.uid, () => { renderMarkers(); focusSelected() })

onBeforeUnmount(() => map?.remove())
</script>

<template>
  <section class="map-panel">
    <div ref="mapEl" class="leaflet-map" />
    <div class="map-label"><span class="live-pulse" /> LIVE SITE MAP</div>
    <div class="map-style-switch">
      <button type="button" :class="{ active: mapStyle === 'atlas' }" @click="setMapStyle('atlas')">Atlas</button>
      <button type="button" :class="{ active: mapStyle === 'satellite' }" @click="setMapStyle('satellite')">Satellite</button>
    </div>
    <div class="map-actions">
      <button title="Zoom in" @click="map?.zoomIn()"><Plus :size="17" /></button>
      <button title="Zoom out" @click="map?.zoomOut()"><Minus :size="17" /></button>
      <button title="Show all" @click="showAll"><LocateFixed :size="17" /></button>
    </div>
    <div class="map-legend">
      <span><i class="legend-dot available" /> Available</span>
      <span><i class="legend-dot selected" /> Selected</span>
      <span><i class="legend-dot locked" /> Restricted</span>
    </div>
  </section>
</template>
