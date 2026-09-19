<script setup lang="ts">
import { computed, ref, watch, onBeforeUnmount, onMounted } from 'vue'
import {
  CircleCheck,
  CircleX,
  Info,
  TriangleAlert,
  X,
} from '@lucide/vue'
import AppSidebar from '@/components/AppSidebar.vue'
import BrowserChrome from '@/components/BrowserChrome.vue'
import BusinessMap from '@/components/BusinessMap.vue'
import LocationDetail from '@/components/LocationDetail.vue'
import LocationList from '@/components/LocationList.vue'
import PlaceholderView from '@/components/PlaceholderView.vue'
import TierRail from '@/components/TierRail.vue'
import PurchaseModal from '@/components/PurchaseModal.vue'
import BootstrapLoading from '@/components/BootstrapLoading.vue'
import HelpCenter from '@/components/HelpCenter.vue'
import {
  businessLocations as mockBusinessLocations,
  businessTiers as mockBusinessTiers,
} from '@/data/mock-businesses'
import {
  mockProfile,
  mockReputationLevels,
} from '@/data/mock-profile'
import { zoneFromCoordinates } from '@/lib/format'
import { isFiveM, nuiFetch } from '@/lib/nui'
import type {
  BrowserSnapshot,
  BrowserTheme,
  BusinessLocation,
  BusinessTier,
  LocationView,
  ReputationLevel,
} from '@/types/business'

const activeView = ref<'market' | 'portfolio'>('market')
const selectedType = ref('coffee_shop')
const selectedLocationId = ref<string>()
const query = ref('')

const businessTiers = ref<BusinessTier[]>(
  isFiveM ? [] : [...mockBusinessTiers],
)

const businessLocations = ref<BusinessLocation[]>(
  isFiveM ? [] : [...mockBusinessLocations],
)

const reputationLevels = ref<ReputationLevel[]>(
  isFiveM ? [] : [...mockReputationLevels],
)

const characterName = ref(
  isFiveM ? '' : mockProfile.characterName,
)

const reputation = ref(
  isFiveM ? 0 : mockProfile.reputation,
)

const balance = ref(
  isFiveM ? 0 : mockProfile.balance,
)

const portfolioLimit = ref<number>(
  isFiveM ? 0 : mockProfile.portfolioLimit,
)

const purchaseReview = ref<LocationView>()

const ownedLocationIds = ref(
  isFiveM ? [] : [...mockProfile.ownedLocationIds],
)

const acquiredLocationIds = ref(
  isFiveM ? [] : [...mockProfile.acquiredLocationIds],
)

const isHelpCenterOpen = ref(false)

interface ActionResponse {
  success: boolean
  message?: string
  reason?: string
  data?: BrowserSnapshot
}

type ActionCompletion = (success: boolean) => void

const isPurchasing = ref(false)

type ToastVariant = 'success' | 'warning' | 'error' | 'info'

interface ToastMessage {
  id: number
  message: string
  variant: ToastVariant
}

const toast = ref<ToastMessage>()

const toastTitles: Record<ToastVariant, string> = {
  success: 'Completed',
  warning: 'Attention required',
  error: 'Action unsuccessful',
  info: 'Information',
}

let toastTimer: number | undefined

const visible = ref(!isFiveM)
const isBootstrapping = ref(!isFiveM)
const bootstrapError = ref(false)

let bootstrapTimer: number | undefined

const locationViews = computed<LocationView[]>(() => {
  const tierMap = new Map(
    businessTiers.value.map((tier) => [tier.type, tier]),
  )

  return businessLocations.value.flatMap((location) => {
    const tier = tierMap.get(location.type)

    if (!tier) {
      return []
    }

    const status =
      location.status ??
      (
        ownedLocationIds.value.includes(location.uid)
          ? 'active'
          : acquiredLocationIds.value.includes(location.uid)
            ? 'acquired'
            : 'available'
      )

    return [{
      ...location,
      tier,
      effectivePrice: location.price ?? tier.price,
      zone:
        location.zone ??
        zoneFromCoordinates(
          location.coords.x,
          location.coords.y,
        ),
      locked: reputation.value < tier.requiredPoints,
      status,
    }]
  })
})

const availableCounts = computed<Record<string, number>>(() => {
  return Object.fromEntries(
    businessTiers.value.map((tier) => [
      tier.type,
      locationViews.value.filter(
        (location) =>
          location.type === tier.type &&
          location.status === 'available',
      ).length,
    ]),
  )
})

const selectedTierLocations = computed(() => {
  return locationViews.value.filter(
    (location) => location.type === selectedType.value,
  )
})

const displayedLocations = computed(() => {
  const needle = query.value.trim().toLowerCase()

  if (!needle) {
    return selectedTierLocations.value
  }

  return selectedTierLocations.value.filter((location) => {
    const searchableText = [
      location.brand,
      location.street,
      location.crossingStreet,
      location.zone,
      String(location.id),
    ]
      .filter(Boolean)
      .join(' ')
      .toLowerCase()

    return searchableText.includes(needle)
  })
})

const availableListingCount = computed(() => {
  return selectedTierLocations.value.filter(
    (location) => location.status === 'available',
  ).length
})

const mapLocations = computed(() => {
  return displayedLocations.value.filter(
    (location) =>
      !location.locked &&
      location.status === 'available',
  )
})

const selectedLocation = computed(() => locationViews.value.find((location) => location.uid === selectedLocationId.value))

watch(
  [
    selectedLocationId,
    displayedLocations,
    () => selectedLocation.value?.status,
  ],
  ([selectedId, visibleLocations, status]) => {
    if (!selectedId) return

    const remainsVisible = visibleLocations.some(
      (location) => location.uid === selectedId,
    )

    if (!remainsVisible || status !== 'available') {
      selectedLocationId.value = undefined
    }
  },
)

const ownedLocations = computed(() => locationViews.value.filter((location) => ownedLocationIds.value.includes(location.uid)))
const portfolioWeight = computed(() => ownedLocations.value.reduce((total, location) => total + location.tier.weight, 0))
const activeTitle = computed(() => activeView.value === 'market' ? 'Marketplace' : 'My Portfolio')
const reputationLabel = computed(() => {
  return [...reputationLevels.value]
    .reverse()
    .find((level) => reputation.value >= level.points)
    ?.label ?? reputationLevels.value[0]?.label ?? ''
})

const currentReputationLevel = computed(() => {
  return [...reputationLevels.value]
    .reverse()
    .find((level) => reputation.value >= level.points) ??
    reputationLevels.value[0]
})

const nextReputationLevel = computed(() => {
  return reputationLevels.value.find(
    (level) => level.points > reputation.value,
  )
})

const reputationProgress = computed(() => {
  const current = currentReputationLevel.value
  const next = nextReputationLevel.value

  if (!current || !next) {
    return 100
  }

  const range = next.points - current.points

  return Math.min(
    100,
    Math.max(
      0,
      (
        (reputation.value - current.points) /
        range
      ) * 100,
    ),
  )
})

async function waitForLocalAction(delay = 750) {
  if (isFiveM) return

  await new Promise<void>((resolve) => {
    window.setTimeout(resolve, delay)
  })
}

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
  purchaseReview.value = location
}

async function confirmPurchase(location: LocationView) {
  if (isPurchasing.value) return

  const currentLocation = locationViews.value.find(
    item => item.uid === location.uid,
  )

  const cannotPurchase =
    !currentLocation ||
    currentLocation.status !== 'available' ||
    currentLocation.locked ||
    ownsBusinessType(currentLocation.type) ||
    balance.value < currentLocation.effectivePrice ||
    portfolioWeight.value + currentLocation.tier.weight >
      portfolioLimit.value

  if (cannotPurchase || !currentLocation) {
    purchaseReview.value = undefined

    showToast(
      'This acquisition can no longer be completed.',
      'error',
    )

    return
  }

  isPurchasing.value = true

  try {
    const [response] = await Promise.all([
      nuiFetch<ActionResponse>('purchaseBusiness', {
        type: currentLocation.type,
        locationId: currentLocation.id,
      }),
      waitForLocalAction(),
    ])

    if (isFiveM) {
      if (!response || !response.success) {
        throw new Error(
          response?.message ??
            'The acquisition could not be completed.',
        )
      }

      if (response.data) {
        applyBrowserSnapshot(response.data)
      } else {
        purchaseReview.value = undefined
        selectedLocationId.value = undefined
        void nuiFetch('retryBootstrap')
      }

      showToast(
        `${currentLocation.brand} has been added to your portfolio.`,
        'success',
      )

      return
    }

    // Local browser preview only.
    balance.value -= currentLocation.effectivePrice

    if (!ownedLocationIds.value.includes(currentLocation.uid)) {
      ownedLocationIds.value.push(currentLocation.uid)
    }

    acquiredLocationIds.value =
      acquiredLocationIds.value.filter(
        uid => uid !== currentLocation.uid,
      )

    purchaseReview.value = undefined
    selectedLocationId.value = undefined

    showToast(
      `${currentLocation.brand} has been added to your portfolio.`,
      'success',
    )
  } catch (error) {
    const message =
      error instanceof Error
        ? error.message
        : 'The acquisition could not be completed.'

    showToast(message, 'error')
  } finally {
    isPurchasing.value = false
  }
}

function showToast(
  message: string,
  variant: ToastVariant = 'info',
  duration = 3200,
) {
  window.clearTimeout(toastTimer)

  toast.value = {
    id: Date.now(),
    message,
    variant,
  }

  toastTimer = window.setTimeout(() => {
    toast.value = undefined
  }, duration)
}

function closeToast() {
  window.clearTimeout(toastTimer)
  toast.value = undefined
}

function ownsBusinessType(type: string) {
  return ownedLocations.value.some(
    (location) => location.type === type,
  )
}

async function setBusinessWaypoint(location: LocationView) {
  try {
    const response = await nuiFetch<ActionResponse>(
      'setBusinessWaypoint',
      {
        type: location.type,
        locationId: location.id,
        coords: location.coords,
      },
    )

    if (isFiveM && (!response || !response.success)) {
      throw new Error(
        response?.message ??
          'The waypoint could not be set.',
      )
    }

    showToast(
      `Waypoint set for ${location.brand}.`,
      'success',
    )
  } catch (error) {
    const message =
      error instanceof Error
        ? error.message
        : 'The waypoint could not be set.'

    showToast(message, 'error')
  }
}

async function transferBusiness(
  payload: {
    location: LocationView
    playerId: number
    playerName: string
  },
  complete: ActionCompletion,
) {
  try {
    const [response] = await Promise.all([
      nuiFetch<ActionResponse>('transferBusiness', {
        type: payload.location.type,
        locationId: payload.location.id,
        targetId: payload.playerId,
      }),
      waitForLocalAction(),
    ])

    if (isFiveM && (!response || !response.success)) {
      throw new Error(
        response?.message ??
        'The ownership transfer could not be completed.',
      )
    }

    ownedLocationIds.value = ownedLocationIds.value.filter(
      (uid) => uid !== payload.location.uid,
    )

    if (!acquiredLocationIds.value.includes(payload.location.uid)) {
      acquiredLocationIds.value.push(payload.location.uid)
    }

    showToast(
      `${payload.location.brand} was transferred to ${payload.playerName}.`,
      'success',
    )

    complete(true)
  } catch (error) {
    const message =
      error instanceof Error
        ? error.message
        : 'The ownership transfer could not be completed.'

    showToast(message, 'error')
    complete(false)
  }
}

async function abandonBusiness(
  location: LocationView,
  complete: ActionCompletion,
) {
  try {
    const [response] = await Promise.all([
      nuiFetch<ActionResponse>('abandonBusiness', {
        type: location.type,
        locationId: location.id,
      }),
      waitForLocalAction(),
    ])

    if (isFiveM && (!response || !response.success)) {
      throw new Error(
        response?.message ??
        'The business could not be returned to the Marketplace.',
      )
    }

    ownedLocationIds.value = ownedLocationIds.value.filter(
      (uid) => uid !== location.uid,
    )

    acquiredLocationIds.value = acquiredLocationIds.value.filter(
      (uid) => uid !== location.uid,
    )

    showToast(
      `${location.brand} has been returned to the Marketplace.`,
      'warning',
    )

    complete(true)
  } catch (error) {
    const message =
      error instanceof Error
        ? error.message
        : 'The business could not be returned to the Marketplace.'

    showToast(message, 'error')
    complete(false)
  }
}

function handleEscapeKey(event: KeyboardEvent) {
  if (event.key !== 'Escape') return

  if (purchaseReview.value) {
    if (!isPurchasing.value) {
      purchaseReview.value = undefined
    }

    return
  }

  if (selectedLocationId.value) {
    selectedLocationId.value = undefined
    return
  }

  closeUi()
}

function applyBrowserTheme(theme?: BrowserTheme) {
  if (!theme) return

  const root = document.documentElement

  const variables: Array<[string, string | undefined]> = [
    ['--accent', theme.AccentColor],
    ['--accent-hover', theme.AccentHoverColor],
    ['--accent-dark', theme.AccentDarkColor],
    ['--bg', theme.BodyColor],
    ['--panel', theme.PanelColor],
    ['--panel-2', theme.PanelAltColor],
    ['--panel-3', theme.CardColor],
    ['--line', theme.BorderColor],
    ['--text', theme.TextColor],
    ['--muted', theme.MutedTextColor],
    ['--success', theme.SuccessColor],
    ['--warning', theme.WarningColor],
    ['--danger', theme.DangerColor],
  ]

  for (const [variable, value] of variables) {
    if (value) {
      root.style.setProperty(variable, value)
    }
  }
}

function applyBrowserSnapshot(snapshot: BrowserSnapshot) {
  businessTiers.value = snapshot.tiers
  businessLocations.value = snapshot.locations
  reputationLevels.value = snapshot.reputationLevels

  characterName.value = snapshot.profile.characterName
  reputation.value = snapshot.profile.reputation
  balance.value = snapshot.profile.balance
  portfolioLimit.value = snapshot.profile.portfolioLimit

  ownedLocationIds.value = snapshot.locations
    .filter((location) => location.status === 'active')
    .map((location) => location.uid)

  acquiredLocationIds.value = snapshot.locations
    .filter((location) => location.status === 'acquired')
    .map((location) => location.uid)

  const selectedTier = snapshot.tiers.find(
    (tier) =>
      tier.type === selectedType.value &&
      tier.unlocked !== false,
  )

  if (!selectedTier) {
    selectedType.value =
      snapshot.tiers.find((tier) => tier.unlocked !== false)
        ?.type ?? ''
  }

  selectedLocationId.value = undefined
  purchaseReview.value = undefined
  query.value = ''

  applyBrowserTheme(snapshot.settings.theme)

  bootstrapError.value = false
  isBootstrapping.value = false
}

function handleNuiMessage(event: MessageEvent) {
  const message = event.data

  if (!message || typeof message.action !== 'string') {
    return
  }

  switch (message.action) {
    case 't1ger_moneywash:browser:open':
      visible.value = true
      activeView.value = 'market'
      selectedLocationId.value = undefined
      purchaseReview.value = undefined
      isHelpCenterOpen.value = false
      bootstrapError.value = false
      isBootstrapping.value = true
      break

    case 't1ger_moneywash:browser:loading':
      bootstrapError.value = false
      isBootstrapping.value = true
      break

    case 't1ger_moneywash:browser:bootstrap':
      if (message.data) {
        applyBrowserSnapshot(
          message.data as BrowserSnapshot,
        )
      }
      break

    case 't1ger_moneywash:browser:error':
      isBootstrapping.value = false
      bootstrapError.value = true
      break

    case 't1ger_moneywash:browser:close':
      visible.value = false
      selectedLocationId.value = undefined
      purchaseReview.value = undefined
      isHelpCenterOpen.value = false
      break
  }
}

function startBootstrap() {
  isBootstrapping.value = true
  bootstrapError.value = false

  window.clearTimeout(bootstrapTimer)

  if (isFiveM) {
    return
  }

  bootstrapTimer = window.setTimeout(() => {
    bootstrapError.value = false
    isBootstrapping.value = false
  }, 900)
}

function retryBootstrap() {
  isBootstrapping.value = true
  bootstrapError.value = false

  if (isFiveM) {
    void nuiFetch('retryBootstrap')
    return
  }

  startBootstrap()
}

onMounted(() => {
  window.addEventListener('keydown', handleEscapeKey)
  window.addEventListener('message', handleNuiMessage)

  if (isFiveM) {
    void nuiFetch('ready')
  } else {
    startBootstrap()
  }
})

onBeforeUnmount(() => {
  window.clearTimeout(bootstrapTimer)
  window.clearTimeout(toastTimer)

  window.removeEventListener('keydown', handleEscapeKey)
  window.removeEventListener('message', handleNuiMessage)
})

watch(reputation, (score) => {
  const selectedTier = businessTiers.value.find(
    (tier) => tier.type === selectedType.value,
  )

  if (!selectedTier || score >= selectedTier.requiredPoints) return

  const highestEligibleTier = [...businessTiers.value]
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
        <BootstrapLoading v-if="isBootstrapping" />

        <template v-else-if="bootstrapError">
          <section class="bootstrap-error">
            <div class="bootstrap-error-icon">!</div>
            <span class="eyebrow">CONNECTION ERROR</span>
            <h2>Unable to load brokerage data</h2>
            <p>
              Ledger Capital could not retrieve the current listings and account
              information.
            </p>
            <button class="portfolio-primary" type="button" @click="retryBootstrap">
              Retry
            </button>
          </section>
        </template>

        <template v-else>
          <AppSidebar :active-view="activeView" :reputation="reputation" :reputation-label="reputationLabel"
            :reputation-progress="reputationProgress" :next-reputation-label="nextReputationLevel?.label"
            :character-name="characterName" :portfolio-count="ownedLocations.length" :portfolio-weight="portfolioWeight"
            :portfolio-limit="portfolioLimit" @navigate="activeView = $event as typeof activeView"
            @open-help="isHelpCenterOpen = true" @update:reputation="reputation = $event" />

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
                :total-locations="selectedTierLocations.length" :available-count="availableListingCount"
                @select="selectedLocationId = $event.uid" @update:query="query = $event" />
              <div class="map-stack">
                <BusinessMap :locations="mapLocations" :selected="selectedLocation"
                  @select="selectedLocationId = $event.uid" />
                <LocationDetail :location="selectedLocation" :reputation="reputation" :balance="balance" :owns-type="selectedLocation
                  ? ownsBusinessType(selectedLocation.type)
                  : false
                  " :portfolio-weight="portfolioWeight" :portfolio-limit="portfolioLimit"
                  @close="selectedLocationId = undefined" @purchase="reviewPurchase" />
              </div>
            </section>
          </main>

          <PlaceholderView v-else :businesses="ownedLocations" :portfolio-weight="portfolioWeight"
            :portfolio-limit="portfolioLimit" @navigate-market="activeView = 'market'" @waypoint="setBusinessWaypoint"
            @transfer="transferBusiness" @abandon="abandonBusiness" />
        </template>
      </div>

      <HelpCenter v-if="isHelpCenterOpen" @close="isHelpCenterOpen = false" />

      <Transition name="modal-fade">
        <PurchaseModal v-if="purchaseReview" :location="purchaseReview" :reputation="reputation" :balance="balance"
          :portfolio-weight="portfolioWeight" :portfolio-limit="portfolioLimit"
          :owns-type="ownsBusinessType(purchaseReview.type)" :processing="isPurchasing"
          @close="!isPurchasing && (purchaseReview = undefined)" @confirm="confirmPurchase" />
      </Transition>
      <Transition name="toast" mode="out-in">
        <div v-if="toast" :key="toast.id" class="app-toast" :class="`toast-${toast.variant}`" role="status"
          aria-live="polite">
          <span class="app-toast-icon">
            <CircleCheck v-if="toast.variant === 'success'" :size="17" />

            <TriangleAlert v-else-if="toast.variant === 'warning'" :size="17" />

            <CircleX v-else-if="toast.variant === 'error'" :size="17" />

            <Info v-else :size="17" />
          </span>

          <span class="app-toast-copy">
            <strong>{{ toastTitles[toast.variant] }}</strong>
            <small>{{ toast.message }}</small>
          </span>

          <button type="button" class="app-toast-close" aria-label="Dismiss notification" @click="closeToast">
            <X :size="14" />
          </button>
        </div>
      </Transition>
    </div>
  </div>
</template>
