<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, } from 'vue'
import {
  ArrowRightLeft,
  BriefcaseBusiness,
  Building2,
  MapPin,
  MapPinned,
  Trash2,
  TriangleAlert,
  UserRound,
  X,
} from '@lucide/vue'
import { toRoman } from '@/lib/format'
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

const nearbyPlayers = ref<NearbyPlayer[]>([
  { id: 24, name: 'John Doe', distance: 3.4 },
  { id: 71, name: 'Michael King', distance: 7.8 },
  { id: 38, name: 'Nadia Cruz', distance: 9.2 },
])

const isLoadingNearbyPlayers = ref(false)

let nearbyPlayersTimer: number | undefined

const selectedBusiness = ref<LocationView>()
const dialog = ref<'transfer' | 'abandon'>('transfer')
const selectedPlayerId = ref<number>()

const selectedPlayer = computed(() => {
  return nearbyPlayers.value.find(
    (player) => player.id === selectedPlayerId.value,
  )
})

function openTransfer(location: LocationView) {
  selectedBusiness.value = location
  selectedPlayerId.value = undefined
  dialog.value = 'transfer'
  isLoadingNearbyPlayers.value = true

  window.clearTimeout(nearbyPlayersTimer)

  // Local preview only.
  // Later, Lua will return the actual nearby players.
  nearbyPlayersTimer = window.setTimeout(() => {
    isLoadingNearbyPlayers.value = false
  }, 650)
}

function openAbandon(location: LocationView) {
  selectedBusiness.value = location
  dialog.value = 'abandon'
}

function closeDialog() {
  window.clearTimeout(nearbyPlayersTimer)

  selectedBusiness.value = undefined
  selectedPlayerId.value = undefined
  isLoadingNearbyPlayers.value = false
}

function handleModalEscape(event: KeyboardEvent) {
  if (event.key !== 'Escape' || !selectedBusiness.value) return

  event.preventDefault()
  event.stopImmediatePropagation()
  closeDialog()
}

function confirmTransfer() {
  if (!selectedBusiness.value || !selectedPlayer.value) return
  emit('transfer', {
    location: selectedBusiness.value,
    playerId: selectedPlayer.value.id,
    playerName: selectedPlayer.value.name,
  })
  closeDialog()
}

function confirmAbandon() {
  if (!selectedBusiness.value) return
  emit('abandon', selectedBusiness.value)
  closeDialog()
}

onMounted(() => {
  window.addEventListener('keydown', handleModalEscape, true)
})

onBeforeUnmount(() => {
  window.clearTimeout(nearbyPlayersTimer)
  window.removeEventListener('keydown', handleModalEscape, true)
})

</script>

<template>
  <main class="portfolio-view">
    <header class="portfolio-header">
      <div>
        <span class="eyebrow">OWNERSHIP LEDGER</span>
        <h1>My Portfolio</h1>
        <p>Manage your registered businesses and ownership actions.</p>
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
        <p>Manage available ownership actions.</p>
      </div>

      <div class="portfolio-list">
        <article v-for="location in businesses" :key="location.uid" class="portfolio-entry">
          <div class="portfolio-business-icon">
            <Building2 :size="20" />
          </div>

          <div class="portfolio-business-copy">
            <div class="portfolio-title-row">
              <strong>{{ location.brand }}</strong>
              <span>ACTIVE</span>
            </div>

            <div class="portfolio-meta">
              <span>{{ location.tier.label }}</span>
              <i aria-hidden="true" />
              <span>Tier {{ toRoman(location.tier.tier) }}</span>
              <i aria-hidden="true" />
              <span>Weight {{ location.tier.weight }}</span>
            </div>

            <small class="portfolio-location">
              <MapPin :size="12" />

              <span>
                {{ location.street ?? `Site ${String(location.id).padStart(2, '0')}` }}
                <template v-if="location.crossingStreet">
                  / {{ location.crossingStreet }}
                </template>
                <template v-if="location.zone">
                  · {{ location.zone }}
                </template>
              </span>
            </small>
          </div>

          <div class="portfolio-row-actions">
            <button class="portfolio-waypoint" type="button" title="Set waypoint" aria-label="Set waypoint"
              @click="emit('waypoint', location)">
              <MapPinned :size="16" />
            </button>
            <button class="portfolio-secondary" @click="openTransfer(location)">
              <ArrowRightLeft :size="15" /> Transfer Ownership
            </button>
            <button class="portfolio-danger-action" @click="openAbandon(location)">
              <Trash2 :size="14" /> Relinquish Holding
            </button>
          </div>
        </article>
      </div>
    </section>

    <section v-else class="portfolio-empty">
      <BriefcaseBusiness :size="28" />
      <h2>No businesses registered</h2>
      <p>Purchase your first business through the Marketplace.</p>
      <button class="portfolio-primary" @click="emit('navigateMarket')">Browse Marketplace</button>
    </section>

    <Transition name="modal-fade">
      <div v-if="selectedBusiness" class="modal-backdrop" @click.self="closeDialog">
        <section class="portfolio-modal" role="dialog" aria-modal="true"
          :aria-label="`${selectedBusiness.brand} ownership action`">
          <button class="modal-close" aria-label="Close" @click="closeDialog">
            <X :size="16" />
          </button>

          <template v-if="dialog === 'transfer'">
            <span class="modal-kicker">TRANSFER OWNERSHIP</span>
            <h2>Select a nearby player</h2>
            <p class="modal-description">The business will be transferred immediately after confirmation. No payment is
              included in this transfer.</p>

            <div v-if="isLoadingNearbyPlayers" class="nearby-player-loading" aria-label="Searching for nearby players">
              <div v-for="index in 3" :key="index" class="nearby-player-skeleton">
                <span class="nearby-skeleton-radio" />
                <span class="nearby-skeleton-avatar" />

                <span class="nearby-skeleton-copy">
                  <i />
                  <small />
                </span>
              </div>
            </div>

            <div v-else-if="nearbyPlayers.length === 0" class="nearby-player-empty">
              <span class="nearby-empty-icon">
                <UserRound :size="20" />
              </span>

              <strong>No nearby players</strong>

              <p>
                Another player must be nearby before ownership can be transferred.
              </p>
            </div>

            <div v-else class="nearby-player-list">
              <label v-for="player in nearbyPlayers" :key="player.id"
                :class="{ selected: selectedPlayerId === player.id }">
                <input v-model="selectedPlayerId" type="radio" name="nearby-player" :value="player.id" />

                <UserRound :size="16" />

                <span>
                  <strong>{{ player.name }}</strong>

                  <small>
                    Session ID {{ player.id }} ·
                    {{ player.distance.toFixed(1) }}m away
                  </small>
                </span>
              </label>
            </div>

            <div class="modal-footer-actions">
              <button class="portfolio-secondary" @click="closeDialog">Cancel</button>
              <button class="portfolio-primary" :disabled="isLoadingNearbyPlayers || !selectedPlayer"
                @click="confirmTransfer">
                Confirm Transfer
              </button>
            </div>
          </template>

          <template v-else>
            <div class="danger-icon">
              <TriangleAlert :size="24" />
            </div>
            <span class="modal-kicker danger">PERMANENT ACTION</span>
            <h2>Relinquish {{ selectedBusiness.brand }}?</h2>
            <p class="modal-description">This business will immediately return to the Marketplace. You will receive no
              refund.</p>

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
              <button class="portfolio-danger" @click="confirmAbandon">
                <Trash2 :size="14" /> Relinquish Permanently
              </button>
            </div>
          </template>
        </section>
      </div>
    </Transition>
  </main>
</template>
