<script setup lang="ts">
import { Building2, ChevronRight, LockKeyhole, MapPin, Search } from '@lucide/vue'
import { money } from '@/lib/format'
import type { LocationView } from '@/types/business'

defineProps<{
  locations: LocationView[]
  selectedId?: string
  query: string
  ownedLocationIds: string[]
}>()

defineEmits<{
  select: [location: LocationView]
  'update:query': [query: string]
}>()
</script>

<template>
  <section class="location-panel">
    <div class="location-toolbar">
      <div>
        <span class="eyebrow">AVAILABLE BUSINESSES</span>
        <strong>{{ locations.length }} listings found</strong>
      </div>
      <label class="search-box">
        <Search :size="15" />
        <input :value="query" placeholder="Search brand or district" @input="$emit('update:query', ($event.target as HTMLInputElement).value)" />
      </label>
    </div>

    <div class="location-list">
      <button
        v-for="location in locations"
        :key="location.uid"
        class="location-card"
        :class="{ selected: selectedId === location.uid, locked: location.locked }"
        @click="$emit('select', location)"
      >
        <span class="location-icon"><Building2 :size="19" /></span>
        <span class="location-main">
          <span class="location-title-row">
            <strong>{{ location.brand }}</strong>
            <span v-if="ownedLocationIds.includes(location.uid)" class="owned-badge">ACTIVE</span>
          </span>
          <small><MapPin :size="12" /> {{ location.district }} · Site {{ String(location.id).padStart(2, '0') }}</small>
        </span>
        <span class="location-price">
          <LockKeyhole v-if="location.locked" :size="13" />
          <strong>{{ money.format(location.effectivePrice) }}</strong>
          <small>{{ location.tier.weight }} portfolio {{ location.tier.weight === 1 ? 'slot' : 'slots' }}</small>
        </span>
        <ChevronRight :size="16" class="card-chevron" />
      </button>

      <div v-if="!locations.length" class="empty-list">No locations match that search.</div>
    </div>
  </section>
</template>
