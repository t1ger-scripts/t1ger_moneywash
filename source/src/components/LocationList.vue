<script setup lang="ts">
import { computed, nextTick, ref, watch } from 'vue'
import {
  Building2,
  ChevronRight,
  MapPin,
  Search,
} from '@lucide/vue'
import { money } from '@/lib/format'
import { t } from '@/lib/locale'
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
        <span class="eyebrow">
          {{ t('browser.listings.heading') }}
        </span>

        <strong>
          {{
            t(
              totalLocations === 1
                ? 'browser.listings.count_one'
                : 'browser.listings.count_many',
              {
                available: availableCount,
                total: totalLocations,
              },
            )
          }}
        </strong>
      </div>

      <label class="search-box">
        <Search :size="15" />

        <input
          :value="query"
          :aria-label="t('browser.listings.search_label')"
          :placeholder="t('browser.listings.search_placeholder')"
          @input="$emit('update:query', ($event.target as HTMLInputElement).value)"
        />
      </label>
    </div>

    <div ref="locationListEl" class="location-list">
      <!-- Selected tier has no configured locations -->
      <div v-if="totalLocations === 0" class="market-empty-state">
        <span class="market-empty-icon">
          <Building2 :size="21" />
        </span>

        <strong>
          {{ t('browser.listings.none_configured_title') }}
        </strong>

        <p>
          {{ t('browser.listings.none_configured_description') }}
        </p>
      </div>

      <!-- Search produced no matching results -->
      <div v-else-if="query.trim() && locations.length === 0" class="market-empty-state">
        <span class="market-empty-icon">
          <Search :size="21" />
        </span>

        <strong>
          {{ t('browser.listings.no_matches_title') }}
        </strong>

        <p>
          {{
            t('browser.listings.no_matches_description', {
              query: query.trim(),
            })
          }}
        </p>

        <button type="button" class="clear-search-button" @click="$emit('update:query', '')">
          {{ t('browser.listings.clear_search') }}
        </button>
      </div>

      <!-- Listings exist -->
      <template v-else>
        <!-- Locations exist, but all have been acquired -->
        <div v-if="availableCount === 0" class="market-availability-status" role="status">
          <span class="market-status-indicator" />

          <span class="market-status-copy">
            <strong>
              {{ t('browser.listings.fully_allocated_title') }}
            </strong>

            <small>
              {{ t('browser.listings.fully_allocated_description') }}
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
                {{ t('browser.listings.status_active') }}
              </span>

              <span v-else-if="location.status === 'acquired'" class="acquired-badge">
                {{ t('browser.listings.status_acquired') }}
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
            </template>

            <template v-else-if="location.status === 'active'">
              <strong class="listing-status active">
                {{ t('browser.listings.status_in_portfolio') }}
              </strong>
            </template>

            <template v-else>
              <strong class="listing-status acquired">
                {{ t('browser.listings.status_acquired') }}
              </strong>
            </template>
          </span>

          <ChevronRight v-if="location.status === 'available'" :size="16" class="card-chevron" />
        </button>
      </template>
    </div>
  </section>
</template>
