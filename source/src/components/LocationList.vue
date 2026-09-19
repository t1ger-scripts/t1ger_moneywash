<script setup lang="ts">
import { nextTick, ref, watch } from 'vue'
import { Building2, ChevronRight, LockKeyhole, MapPin, Search } from '@lucide/vue'
import { money } from '@/lib/format'
import type { LocationView } from '@/types/business'

const props = defineProps<{
  locations: LocationView[]
  selectedId?: string
  query: string
  ownedLocationIds: string[]
}>()

defineEmits<{
  select: [location: LocationView]
  'update:query': [query: string]
}>()

const locationListEl = ref<HTMLElement | null>(null)

watch(
  () => props.selectedId,
  async (selectedId) => {
    if (!selectedId || !locationListEl.value) return

    await nextTick()

    const list = locationListEl.value

    const selectedCard = Array.from(
      list.querySelectorAll<HTMLElement>('[data-location-id]'),
    ).find((card) => card.dataset.locationId === selectedId)

    if (!selectedCard) return

    const listRect = list.getBoundingClientRect()
    const cardRect = selectedCard.getBoundingClientRect()

    const targetScroll =
      list.scrollTop +
      cardRect.top -
      listRect.top -
      (list.clientHeight - cardRect.height) / 2

    list.scrollTo({
      top: Math.max(0, targetScroll),
      behavior: 'smooth',
    })
  },
)
</script>

<template>
  <section class="location-panel">
    <div class="location-toolbar">
      <div>
        <span class="eyebrow">AVAILABLE LISTINGS</span>
        <strong>{{ locations.length }} listings available</strong>
      </div>
      <label class="search-box">
        <Search :size="15" />
        <input :value="query" placeholder="Search brand, street or zone"
          @input="$emit('update:query', ($event.target as HTMLInputElement).value)" />
      </label>
    </div>

    <div ref="locationListEl" class="location-list">
      <button v-for="location in locations" :key="location.uid" :data-location-id="location.uid" class="location-card"
        :class="{ selected: selectedId === location.uid, locked: location.locked }" @click="$emit('select', location)">
        <span class="location-icon">
          <Building2 :size="19" />
        </span>
        <span class="location-main">
          <span class="location-title-row">
            <strong>{{ location.brand }}</strong>
            <span v-if="ownedLocationIds.includes(location.uid)" class="owned-badge">ACTIVE</span>
          </span>
          <small class="listing-location">
            <MapPin :size="12" />

            <span>
              {{ location.street ?? location.zone }}
              <template v-if="location.crossingStreet">
                / {{ location.crossingStreet }}
              </template>
              <template v-if="location.street && location.zone">
                · {{ location.zone }}
              </template>
            </span>
          </small>
        </span>
        <span class="location-price">
          <LockKeyhole v-if="location.locked" :size="13" />
          <strong>{{ money.format(location.effectivePrice) }}</strong>
          <small>Weight: {{ location.tier.weight }}</small>
        </span>
        <ChevronRight :size="16" class="card-chevron" />
      </button>

      <div v-if="!locations.length" class="empty-list">No locations match that search.</div>
    </div>
  </section>
</template>
