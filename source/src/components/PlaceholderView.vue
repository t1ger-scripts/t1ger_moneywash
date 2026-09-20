<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
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
import { t } from '@/lib/locale'
import type { LocationView } from '@/types/business'

interface NearbyPlayer {
  id: number
  name: string
  distance: number
}

type ActionCompletion = (success: boolean) => void

type NearbyPlayersCompletion = (
  players: NearbyPlayer[],
) => void

defineProps<{
  businesses: LocationView[]
  portfolioWeight: number
  portfolioLimit: number
}>()

const emit = defineEmits<{
  navigateMarket: []
  waypoint: [location: LocationView]

  requestNearbyPlayers: [
    complete: NearbyPlayersCompletion,
  ]

  transfer: [
    payload: {
      location: LocationView
      playerId: number
      playerName: string
    },
    complete: ActionCompletion,
  ]

  abandon: [
    location: LocationView,
    complete: ActionCompletion,
  ]
}>()

const nearbyPlayers = ref<NearbyPlayer[]>([])
const isLoadingNearbyPlayers = ref(false)

const selectedBusiness = ref<LocationView>()
const dialog = ref<'transfer' | 'abandon'>('transfer')
const selectedPlayerId = ref<number>()

const isSubmittingOwnershipAction = ref(false)

const selectedPlayer = computed(() => {
  return nearbyPlayers.value.find(
    (player) => player.id === selectedPlayerId.value,
  )
})

function openTransfer(location: LocationView) {
  selectedBusiness.value = location
  selectedPlayerId.value = undefined
  nearbyPlayers.value = []
  dialog.value = 'transfer'
  isLoadingNearbyPlayers.value = true

  emit('requestNearbyPlayers', (players) => {
    if (
      selectedBusiness.value?.uid !== location.uid ||
      dialog.value !== 'transfer'
    ) {
      return
    }

    nearbyPlayers.value = players
    isLoadingNearbyPlayers.value = false
  })
}

function openAbandon(location: LocationView) {
  selectedBusiness.value = location
  dialog.value = 'abandon'
}

function closeDialog() {
  if (isSubmittingOwnershipAction.value) return

  selectedBusiness.value = undefined
  selectedPlayerId.value = undefined
  isLoadingNearbyPlayers.value = false
}

function handleModalEscape(event: KeyboardEvent) {
  if (event.key !== 'Escape' || !selectedBusiness.value) return

  event.preventDefault()
  event.stopImmediatePropagation()

  if (isSubmittingOwnershipAction.value) return

  closeDialog()
}

function confirmTransfer() {
  if (
    !selectedBusiness.value ||
    !selectedPlayer.value ||
    isSubmittingOwnershipAction.value
  ) {
    return
  }

  isSubmittingOwnershipAction.value = true

  emit(
    'transfer',
    {
      location: selectedBusiness.value,
      playerId: selectedPlayer.value.id,
      playerName: selectedPlayer.value.name,
    },
    (success) => {
      isSubmittingOwnershipAction.value = false

      if (success) {
        closeDialog()
      }
    },
  )
}

function confirmAbandon() {
  if (
    !selectedBusiness.value ||
    isSubmittingOwnershipAction.value
  ) {
    return
  }

  isSubmittingOwnershipAction.value = true

  emit(
    'abandon',
    selectedBusiness.value,
    (success) => {
      isSubmittingOwnershipAction.value = false

      if (success) {
        closeDialog()
      }
    },
  )
}

onMounted(() => {
  window.addEventListener('keydown', handleModalEscape, true)
})

onBeforeUnmount(() => {
  window.removeEventListener('keydown', handleModalEscape, true)
})
</script>

<template>
  <main class="portfolio-view">
    <header class="portfolio-header">
      <div>
        <span class="eyebrow">
          {{ t('browser.portfolio.eyebrow') }}
        </span>

        <h1>{{ t('browser.portfolio.title') }}</h1>

        <p>{{ t('browser.portfolio.description') }}</p>
      </div>

      <div class="portfolio-capacity">
        <span>{{ t('browser.portfolio.usage') }}</span>
        <strong>
          {{ portfolioWeight }}
          <small>/ {{ portfolioLimit }}</small>
        </strong>
      </div>
    </header>

    <section v-if="businesses.length" class="portfolio-content">
      <div class="portfolio-section-heading">
        <div>
          <span>{{ t('browser.portfolio.registered_businesses') }}</span>

          <strong>
            {{
              t(
                businesses.length === 1
                  ? 'browser.portfolio.business_count_one'
                  : 'browser.portfolio.business_count_many',
                { count: businesses.length },
              )
            }}
          </strong>
        </div>

        <p>{{ t('browser.portfolio.actions_description') }}</p>
      </div>

      <div class="portfolio-list">
        <article
          v-for="location in businesses"
          :key="location.uid"
          class="portfolio-entry"
        >
          <div class="portfolio-business-icon">
            <Building2 :size="20" />
          </div>

          <div class="portfolio-business-copy">
            <div class="portfolio-title-row">
              <strong>{{ location.brand }}</strong>
              <span>{{ t('browser.portfolio.status_active') }}</span>
            </div>

            <div class="portfolio-meta">
              <span>{{ location.tier.label }}</span>
              <i aria-hidden="true" />

              <span>
                {{
                  t('browser.portfolio.tier', {
                    tier: toRoman(location.tier.tier),
                  })
                }}
              </span>

              <i aria-hidden="true" />

              <span>
                {{
                  t('browser.portfolio.weight', {
                    weight: location.tier.weight,
                  })
                }}
              </span>
            </div>

            <small class="portfolio-location">
              <MapPin :size="12" />

              <span>
                {{
                  location.street ??
                  t('browser.portfolio.site', {
                    id: String(location.id).padStart(2, '0'),
                  })
                }}

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
            <button
              class="portfolio-waypoint"
              type="button"
              :data-tooltip="t('browser.portfolio.set_waypoint')"
              :aria-label="t('browser.portfolio.set_waypoint')"
              @click="emit('waypoint', location)"
            >
              <MapPinned :size="16" />
            </button>

            <button
              class="portfolio-secondary"
              type="button"
              @click="openTransfer(location)"
            >
              <ArrowRightLeft :size="15" />
              {{ t('browser.portfolio.transfer_action') }}
            </button>

            <button
              class="portfolio-danger-action"
              type="button"
              @click="openAbandon(location)"
            >
              <Trash2 :size="14" />
              {{ t('browser.portfolio.relinquish_action') }}
            </button>
          </div>
        </article>
      </div>
    </section>

    <section v-else class="portfolio-empty">
      <BriefcaseBusiness :size="28" />
      <h2>{{ t('browser.portfolio.empty_title') }}</h2>
      <p>{{ t('browser.portfolio.empty_description') }}</p>

      <button
        class="portfolio-primary"
        type="button"
        @click="emit('navigateMarket')"
      >
        {{ t('browser.portfolio.browse_marketplace') }}
      </button>
    </section>

    <Transition name="modal-fade">
      <div
        v-if="selectedBusiness"
        class="modal-backdrop"
        @click.self="closeDialog"
      >
        <section
          class="portfolio-modal"
          role="dialog"
          aria-modal="true"
          :aria-label="
            t('browser.portfolio.ownership_action_label', {
              business: selectedBusiness.brand,
            })
          "
        >
          <button
            class="modal-close"
            type="button"
            :disabled="isSubmittingOwnershipAction"
            :aria-label="t('browser.portfolio.close_label')"
            @click="closeDialog"
          >
            <X :size="16" />
          </button>

          <template v-if="dialog === 'transfer'">
            <span class="modal-kicker">
              {{ t('browser.portfolio.transfer.kicker') }}
            </span>

            <h2>{{ t('browser.portfolio.transfer.title') }}</h2>

            <p class="modal-description">
              {{ t('browser.portfolio.transfer.description') }}
            </p>

            <div
              v-if="isLoadingNearbyPlayers"
              class="nearby-player-loading"
              :aria-label="t('browser.portfolio.transfer.searching_label')"
            >
              <div
                v-for="index in 3"
                :key="index"
                class="nearby-player-skeleton"
              >
                <span class="nearby-skeleton-radio" />
                <span class="nearby-skeleton-avatar" />

                <span class="nearby-skeleton-copy">
                  <i />
                  <small />
                </span>
              </div>
            </div>

            <div
              v-else-if="nearbyPlayers.length === 0"
              class="nearby-player-empty"
            >
              <span class="nearby-empty-icon">
                <UserRound :size="20" />
              </span>

              <strong>{{ t('browser.portfolio.transfer.empty_title') }}</strong>

              <p>{{ t('browser.portfolio.transfer.empty_description') }}</p>
            </div>

            <div v-else class="nearby-player-list">
              <label
                v-for="player in nearbyPlayers"
                :key="player.id"
                :class="{ selected: selectedPlayerId === player.id }"
              >
                <input
                  v-model="selectedPlayerId"
                  type="radio"
                  name="nearby-player"
                  :value="player.id"
                />

                <UserRound :size="16" />

                <span>
                  <strong>{{ player.name }}</strong>

                  <small>
                    {{
                      t('browser.portfolio.transfer.player_details', {
                        id: player.id,
                        distance: player.distance.toFixed(1),
                      })
                    }}
                  </small>
                </span>
              </label>
            </div>

            <div class="modal-footer-actions">
              <button
                class="portfolio-secondary"
                type="button"
                :disabled="isSubmittingOwnershipAction"
                @click="closeDialog"
              >
                {{ t('browser.portfolio.transfer.cancel') }}
              </button>

              <button
                class="portfolio-primary"
                type="button"
                :disabled="
                  isLoadingNearbyPlayers ||
                  !selectedPlayer ||
                  isSubmittingOwnershipAction
                "
                @click="confirmTransfer"
              >
                <span
                  v-if="isSubmittingOwnershipAction"
                  class="action-button-spinner"
                />

                {{
                  isSubmittingOwnershipAction
                    ? t('browser.portfolio.transfer.processing')
                    : t('browser.portfolio.transfer.confirm')
                }}
              </button>
            </div>
          </template>

          <template v-else>
            <div class="danger-icon">
              <TriangleAlert :size="24" />
            </div>

            <span class="modal-kicker danger">
              {{ t('browser.portfolio.relinquish.kicker') }}
            </span>

            <h2>
              {{
                t('browser.portfolio.relinquish.title', {
                  business: selectedBusiness.brand,
                })
              }}
            </h2>

            <p class="modal-description">
              {{ t('browser.portfolio.relinquish.description') }}
            </p>

            <div class="abandon-warning">
              <strong>
                {{ t('browser.portfolio.relinquish.warning_title') }}
              </strong>

              <ul>
                <li>{{ t('browser.portfolio.relinquish.loss_funds') }}</li>
                <li>{{ t('browser.portfolio.relinquish.loss_inventory') }}</li>
                <li>{{ t('browser.portfolio.relinquish.loss_activity') }}</li>
              </ul>
            </div>

            <div class="modal-footer-actions">
              <button
                class="portfolio-secondary"
                type="button"
                :disabled="isSubmittingOwnershipAction"
                @click="closeDialog"
              >
                {{ t('browser.portfolio.relinquish.cancel') }}
              </button>

              <button
                class="portfolio-danger"
                type="button"
                :disabled="isSubmittingOwnershipAction"
                @click="confirmAbandon"
              >
                <span
                  v-if="isSubmittingOwnershipAction"
                  class="action-button-spinner danger-spinner"
                />

                <Trash2 v-else :size="14" />

                {{
                  isSubmittingOwnershipAction
                    ? t('browser.portfolio.relinquish.processing')
                    : t('browser.portfolio.relinquish.confirm')
                }}
              </button>
            </div>
          </template>
        </section>
      </div>
    </Transition>
  </main>
</template>
