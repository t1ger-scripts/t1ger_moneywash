<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import AppSidebar from '@/components/AppSidebar.vue'
import BrowserChrome from '@/components/BrowserChrome.vue'
import BusinessMap from '@/components/BusinessMap.vue'
import LocationDetail from '@/components/LocationDetail.vue'
import LocationList from '@/components/LocationList.vue'
import PlaceholderView from '@/components/PlaceholderView.vue'
import TierRail from '@/components/TierRail.vue'
import { businessLocations, businessTiers } from '@/data/mock-businesses'
import { mockProfile, mockReputationLevels } from '@/data/mock-profile'
import { zoneFromCoordinates } from '@/lib/format'
import { nuiFetch } from '@/lib/nui'
import type { BusinessTier, LocationView } from '@/types/business'

const activeView = ref<'market' | 'portfolio'>('market')
const selectedType = ref('coffee_shop')
const selectedLocationId = ref<string>()
const query = ref('')
const reputation = ref(mockProfile.reputation)
const ownedLocationIds = ref([...mockProfile.ownedLocationIds])
const acquiredLocationIds = ref([...mockProfile.acquiredLocationIds])
const toast = ref('')
const visible = ref(true)

const locationViews = computed<LocationView[]>(() => {
  const tierMap = new Map(businessTiers.map((tier) => [tier.type, tier]))
  return businessLocations.map((location) => {
    const tier = tierMap.get(location.type)!

    const status = ownedLocationIds.value.includes(location.uid)
      ? 'active'
      : acquiredLocationIds.value.includes(location.uid)
        ? 'acquired'
        : 'available'

    return {
      ...location,
      tier,
      effectivePrice: location.price ?? tier.price,
      zone: zoneFromCoordinates(location.coords.x, location.coords.y),
      locked: reputation.value < tier.requiredPoints,
      status,
    }
  })
})

const availableCounts = computed<Record<string, number>>(() => {
  return Object.fromEntries(
    businessTiers.map((tier) => [
      tier.type,
      locationViews.value.filter(
        (location) =>
          location.type === tier.type &&
          location.status === 'available',
      ).length,
    ]),
  )
})

const displayedLocations = computed(() => {
  const needle = query.value.trim().toLowerCase()
  return locationViews.value.filter((location) => location.type === selectedType.value && (!needle || `${location.brand} ${location.street ?? ''} ${location.zone}`.toLowerCase().includes(needle)))
})

const mapLocations = computed(() => {
  return displayedLocations.value.filter(
    (location) =>
      !location.locked &&
      location.status === 'available',
  )
})

const selectedLocation = computed(() => locationViews.value.find((location) => location.uid === selectedLocationId.value))
const ownedLocations = computed(() => locationViews.value.filter((location) => ownedLocationIds.value.includes(location.uid)))
const portfolioWeight = computed(() => ownedLocations.value.reduce((total, location) => total + location.tier.weight, 0))
const activeTitle = computed(() => activeView.value === 'market' ? 'Marketplace' : 'My Portfolio')
const reputationLabel = computed(() => {
  return [...mockReputationLevels].reverse().find((level) => reputation.value >= level.points)?.label ?? mockReputationLevels[0].label
})
const currentReputationLevel = computed(() => {
  return [...mockReputationLevels].reverse().find((level) => reputation.value >= level.points) ?? mockReputationLevels[0]
})
const nextReputationLevel = computed(() => mockReputationLevels.find((level) => level.points > reputation.value))
const reputationProgress = computed(() => {
  if (!nextReputationLevel.value) return 100
  const range = nextReputationLevel.value.points - currentReputationLevel.value.points
  return Math.min(100, Math.max(0, ((reputation.value - currentReputationLevel.value.points) / range) * 100))
})

function selectTier(tier: BusinessTier) {
  selectedType.value = tier.type
  selectedLocationId.value = undefined
  query.value = ''
}

function closeUi() {
  visible.value = false
  void nuiFetch('close')
}

function reviewPurchase(location: LocationView) {
  toast.value = `Purchase review opened for ${location.brand}`
  window.setTimeout(() => { toast.value = '' }, 2800)
  void nuiFetch('reviewPurchase', { type: location.type, locationId: location.id })
}

function showToast(message: string) {
  toast.value = message
  window.setTimeout(() => { toast.value = '' }, 2800)
}

function setBusinessWaypoint(location: LocationView) {
  showToast(`Waypoint set for ${location.brand}`)
  void nuiFetch('setBusinessWaypoint', { type: location.type, locationId: location.id, coords: location.coords })
}

function transferBusiness(payload: { location: LocationView; playerId: number; playerName: string }) {
  ownedLocationIds.value = ownedLocationIds.value.filter((uid) => uid !== payload.location.uid)
  if (!acquiredLocationIds.value.includes(payload.location.uid)) {
    acquiredLocationIds.value.push(payload.location.uid)
  }
  showToast(`${payload.location.brand} transferred to ${payload.playerName}`)
  void nuiFetch('transferBusiness', { type: payload.location.type, locationId: payload.location.id, targetId: payload.playerId })
}

function abandonBusiness(location: LocationView) {
  ownedLocationIds.value = ownedLocationIds.value.filter((uid) => uid !== location.uid)
  showToast(`Ownership of ${location.brand} has been relinquished`)
  void nuiFetch('abandonBusiness', { type: location.type, locationId: location.id })
}

watch(reputation, (score) => {
  const selectedTier = businessTiers.find(
    (tier) => tier.type === selectedType.value,
  )

  if (!selectedTier || score >= selectedTier.requiredPoints) return

  const highestEligibleTier = [...businessTiers]
    .reverse()
    .find((tier) => score >= tier.requiredPoints)

  if (highestEligibleTier) {
    selectTier(highestEligibleTier)
  }
})
</script>

<template>
  <div v-if="visible" class="nui-stage">
    <div class="browser-window">
      <BrowserChrome :active-tab="activeTitle" @close="closeUi" />
      <div class="app-frame">
        <AppSidebar :active-view="activeView" :reputation="reputation" :reputation-label="reputationLabel"
          :reputation-progress="reputationProgress" :next-reputation-label="nextReputationLevel?.label"
          :character-name="mockProfile.characterName" :portfolio-count="ownedLocations.length"
          :portfolio-weight="portfolioWeight" :portfolio-limit="mockProfile.portfolioLimit"
          @navigate="activeView = $event as typeof activeView" @update:reputation="reputation = $event" />

        <main v-if="activeView === 'market'" class="market-view">
          <header class="market-header">
            <div>
              <span class="eyebrow">VERIFIED LISTINGS</span>
              <h1>Marketplace</h1>
              <p>Browse available business acquisitions and expand your portfolio.</p>
            </div>
          </header>

          <TierRail :tiers="businessTiers" :selected-type="selectedType" :reputation="reputation"
            :counts="availableCounts" @select="selectTier" />

          <section class="workspace">
            <LocationList :locations="displayedLocations" :selected-id="selectedLocationId" :query="query"
              @select="selectedLocationId = $event.uid" @update:query="query = $event" />
            <div class="map-stack">
              <BusinessMap :locations="mapLocations" :selected="selectedLocation"
                @select="selectedLocationId = $event.uid" />
              <LocationDetail :location="selectedLocation" :reputation="reputation"
                :owned="!!selectedLocation && ownedLocationIds.includes(selectedLocation.uid)"
                :portfolio-weight="portfolioWeight" :portfolio-limit="mockProfile.portfolioLimit"
                @close="selectedLocationId = undefined" @purchase="reviewPurchase" />
            </div>
          </section>
        </main>

        <PlaceholderView v-else :businesses="ownedLocations" :portfolio-weight="portfolioWeight"
          :portfolio-limit="mockProfile.portfolioLimit" @navigate-market="activeView = 'market'"
          @waypoint="setBusinessWaypoint" @transfer="transferBusiness" @abandon="abandonBusiness" />
      </div>
      <Transition name="toast">
        <div v-if="toast" class="app-toast">{{ toast }}</div>
      </Transition>
    </div>
  </div>
</template>
