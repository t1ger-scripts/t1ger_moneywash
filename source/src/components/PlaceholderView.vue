<script setup lang="ts">
import { computed, ref } from 'vue'
import {
  BriefcaseBusiness,
  Building2,
  ChevronDown,
  MapPin,
  Navigation,
  Send,
  Trash2,
  TriangleAlert,
  UserRound,
  X,
} from '@lucide/vue'
import type { LocationView } from '@/types/business'

interface NearbyPlayer {
  id: number
  name: string
  distance: number
}

defineProps<{
  businesses: LocationView[]
  portfolioWeight: number
  portfolioLimit: number
}>()

const emit = defineEmits<{
  navigateMarket: []
  waypoint: [location: LocationView]
  transfer: [payload: { location: LocationView; playerId: number; playerName: string }]
  abandon: [location: LocationView]
}>()

const nearbyPlayers: NearbyPlayer[] = [
  { id: 24, name: 'John Doe', distance: 3.4 },
  { id: 71, name: 'Michael King', distance: 7.8 },
  { id: 38, name: 'Nadia Cruz', distance: 9.2 },
]

const expandedBusinessId = ref<string>()
const selectedBusiness = ref<LocationView>()
const dialog = ref<'transfer' | 'abandon'>('transfer')
const selectedPlayerId = ref<number>()
const selectedPlayer = computed(() => nearbyPlayers.find((player) => player.id === selectedPlayerId.value))

function toggleBusiness(location: LocationView) {
  expandedBusinessId.value = expandedBusinessId.value === location.uid ? undefined : location.uid
}

function openTransfer(location: LocationView) {
  selectedBusiness.value = location
  selectedPlayerId.value = undefined
  dialog.value = 'transfer'
}

function openAbandon(location: LocationView) {
  selectedBusiness.value = location
  dialog.value = 'abandon'
}

function closeDialog() {
  selectedBusiness.value = undefined
  selectedPlayerId.value = undefined
}

function confirmTransfer() {
  if (!selectedBusiness.value || !selectedPlayer.value) return
  emit('transfer', {
    location: selectedBusiness.value,
    playerId: selectedPlayer.value.id,
    playerName: selectedPlayer.value.name,
  })
  expandedBusinessId.value = undefined
  closeDialog()
}

function confirmAbandon() {
  if (!selectedBusiness.value) return
  emit('abandon', selectedBusiness.value)
  expandedBusinessId.value = undefined
  closeDialog()
}
</script>

<template>
  <main class="portfolio-view">
    <header class="portfolio-header">
      <div>
        <span class="eyebrow">OWNERSHIP LEDGER</span>
        <h1>My Portfolio</h1>
        <p>Review your businesses and access ownership options.</p>
      </div>
      <div class="portfolio-capacity">
        <span>PORTFOLIO USAGE</span>
        <strong>{{ portfolioWeight }} <small>/ {{ portfolioLimit }}</small></strong>
      </div>
    </header>

    <section v-if="businesses.length" class="portfolio-content">
      <div class="portfolio-section-heading">
        <div>
          <span>REGISTERED BUSINESSES</span>
          <strong>{{ businesses.length }} {{ businesses.length === 1 ? 'business' : 'businesses' }}</strong>
        </div>
        <p>Select a business to view available actions.</p>
      </div>

      <div class="portfolio-list">
        <article
          v-for="location in businesses"
          :key="location.uid"
          class="portfolio-entry"
          :class="{ expanded: expandedBusinessId === location.uid }"
        >
          <button
            class="portfolio-card"
            :aria-expanded="expandedBusinessId === location.uid"
            @click="toggleBusiness(location)"
          >
            <div class="portfolio-business-icon"><Building2 :size="20" /></div>
            <div class="portfolio-business-copy">
              <div class="portfolio-title-row">
                <strong>{{ location.brand }}</strong>
                <span>ACTIVE</span>
              </div>
              <p>{{ location.tier.label }} · Tier {{ location.tier.tier }}</p>
              <small><MapPin :size="12" /> {{ location.district }} · Site {{ String(location.id).padStart(2, '0') }}</small>
            </div>
            <div class="portfolio-weight">
              <span>PORTFOLIO WEIGHT</span>
              <strong>Weight: {{ location.tier.weight }}</strong>
            </div>
            <ChevronDown :size="17" class="portfolio-chevron" />
          </button>

          <div v-if="expandedBusinessId === location.uid" class="portfolio-expanded">
            <div class="inline-ownership-summary">
              <div><span>TYPE</span><strong>{{ location.tier.label }}</strong></div>
              <div><span>TIER</span><strong>{{ location.tier.tier }}</strong></div>
              <div><span>DISTRICT</span><strong>{{ location.district }}</strong></div>
              <div><span>WEIGHT</span><strong>{{ location.tier.weight }}</strong></div>
            </div>

            <div class="inline-ownership-actions">
              <button class="portfolio-primary" @click="emit('waypoint', location)"><Navigation :size="15" /> Set Waypoint</button>
              <button class="portfolio-secondary" @click="openTransfer(location)"><Send :size="15" /> Transfer Ownership</button>
              <button class="portfolio-danger-link" @click="openAbandon(location)"><Trash2 :size="14" /> Relinquish Business</button>
            </div>
          </div>
        </article>
      </div>
    </section>

    <section v-else class="portfolio-empty">
      <BriefcaseBusiness :size="28" />
      <h2>No businesses owned</h2>
      <p>Purchase your first business through the Marketplace.</p>
      <button class="portfolio-primary" @click="emit('navigateMarket')">Browse Marketplace</button>
    </section>

    <Transition name="modal-fade">
      <div v-if="selectedBusiness" class="modal-backdrop" @click.self="closeDialog">
        <section class="portfolio-modal" role="dialog" aria-modal="true" :aria-label="`${selectedBusiness.brand} ownership action`">
          <button class="modal-close" aria-label="Close" @click="closeDialog"><X :size="16" /></button>

          <template v-if="dialog === 'transfer'">
            <span class="modal-kicker">TRANSFER OWNERSHIP</span>
            <h2>Select a nearby player</h2>
            <p class="modal-description">The business will be transferred immediately after confirmation. No payment is included in this transfer.</p>

            <div class="nearby-player-list">
              <label v-for="player in nearbyPlayers" :key="player.id" :class="{ selected: selectedPlayerId === player.id }">
                <input v-model="selectedPlayerId" type="radio" name="nearby-player" :value="player.id" />
                <UserRound :size="16" />
                <span><strong>{{ player.name }}</strong><small>Session ID {{ player.id }} · {{ player.distance.toFixed(1) }}m away</small></span>
              </label>
            </div>

            <div class="modal-footer-actions">
              <button class="portfolio-secondary" @click="closeDialog">Cancel</button>
              <button class="portfolio-primary" :disabled="!selectedPlayer" @click="confirmTransfer">Confirm Transfer</button>
            </div>
          </template>

          <template v-else>
            <div class="danger-icon"><TriangleAlert :size="24" /></div>
            <span class="modal-kicker danger">PERMANENT ACTION</span>
            <h2>Relinquish {{ selectedBusiness.brand }}?</h2>
            <p class="modal-description">This business will immediately return to the Marketplace. You will receive no refund.</p>

            <div class="abandon-warning">
              <strong>Everything associated with this business will be lost:</strong>
              <ul>
                <li>All funds remaining in the business account</li>
                <li>All remaining inventory and active orders</li>
                <li>All pending transactions and business activity</li>
              </ul>
            </div>

            <div class="modal-footer-actions">
              <button class="portfolio-secondary" @click="closeDialog">Keep Business</button>
              <button class="portfolio-danger" @click="confirmAbandon"><Trash2 :size="14" /> Relinquish Permanently</button>
            </div>
          </template>
        </section>
      </div>
    </Transition>
  </main>
</template>
