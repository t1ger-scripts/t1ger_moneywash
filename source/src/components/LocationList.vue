<script setup lang="ts">
import { computed, nextTick, ref, watch } from 'vue'
import {
  Building2,
  ChevronRight,
  MapPin,
  Search,
} from '@lucide/vue'
import { money } from '@/lib/format'
import type { LocationView } from '@/types/business'

const props = defineProps<{
  locations: LocationView[]
  selectedId?: string
  query: string
  totalLocations: number
  availableCount: number
}>()

defineEmits<{
  select: [location: LocationView]
  'update:query': [query: string]
}>()

const availableCount = computed(() => {
  return props.locations.filter(
    (location) => location.status === 'available',
  ).length
})

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
        <strong>
          {{ availableCount }} of {{ totalLocations }}
          {{ totalLocations === 1 ? 'listing' : 'listings' }} available
        </strong>
      </div>
      <label class="search-box">
        <Search :size="15" />
        <input :value="query" placeholder="Search brand, street or zone"
          @input="$emit('update:query', ($event.target as HTMLInputElement).value)" />
      </label>
    </div>

    <div ref="locationListEl" class="location-list">
      <!-- Selected tier has no configured locations -->
      <div v-if="totalLocations === 0" class="market-empty-state">
        <span class="market-empty-icon">
          <Building2 :size="21" />
        </span>

        <strong>No listings configured</strong>

        <p>
          There are currently no registered locations for this business category.
        </p>
      </div>

      <!-- Search produced no matching results -->
      <div v-else-if="query.trim() && locations.length === 0" class="market-empty-state">
        <span class="market-empty-icon">
          <Search :size="21" />
        </span>

        <strong>No matching listings</strong>

        <p>
          No businesses match “{{ query.trim() }}”.
        </p>

        <button type="button" class="clear-search-button" @click="$emit('update:query', '')">
          Clear search
        </button>
      </div>

      <!-- Listings exist -->
      <template v-else>
        <!-- Locations exist, but all have been acquired -->
        <div v-if="availableCount === 0" class="market-availability-notice">
          <span class="availability-notice-icon">
            <Building2 :size="16" />
          </span>

          <span>
            <strong>No listings currently available</strong>
            <small>
              Every registered location in this category has been acquired.
            </small>
          </span>
        </div>

        <!-- Existing location cards -->
        <button v-for="location in locations" :key="location.uid" :data-location-id="location.uid" class="location-card"
          :class="{
            selected: selectedId === location.uid,
            locked: location.locked,
            unavailable: location.status !== 'available',
          }" :disabled="location.status !== 'available'" @click="$emit('select', location)">
          <span class="location-icon">
            <Building2 :size="19" />
          </span>

          <span class="location-main">
            <span class="location-title-row">
              <strong>{{ location.brand }}</strong>

              <span v-if="location.status === 'active'" class="owned-badge">
                ACTIVE
              </span>

              <span v-else-if="location.status === 'acquired'" class="acquired-badge">
                ACQUIRED
              </span>
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
            <template v-if="location.status === 'available'">
              <strong>{{ money.format(location.effectivePrice) }}</strong>
              <small>Weight: {{ location.tier.weight }}</small>
            </template>

            <template v-else-if="location.status === 'active'">
              <strong class="listing-status active">
                IN PORTFOLIO
              </strong>
            </template>

            <template v-else>
              <strong class="listing-status acquired">
                ACQUIRED
              </strong>
            </template>
          </span>

          <ChevronRight v-if="location.status === 'available'" :size="16" class="card-chevron" />
        </button>
      </template>
    </div>
  </section>
</template>
