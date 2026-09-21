<script setup lang="ts">
import { ref } from 'vue'

import {
  Building2,
  MapPin,
  ShoppingCart,
  X,
} from '@lucide/vue'

import {
  AppBadge,
  AppButton,
  AppIconButton,
  AppModal,
  AppProgressBar,
  AppSearchInput,
  AppSurface,
} from '@/design-system'

const searchQuery = ref('')
const purchaseModalOpen = ref(false)
</script>

<template>
  <main class="design-system-preview">
    <AppSurface
      class="design-system-preview__card"
      elevation="raised"
    >
      <header class="design-system-preview__header">
        <div class="design-system-preview__identity">
          <div class="design-system-preview__icon">
            <Building2 :size="24" />
          </div>

          <div>
            <span class="design-system-preview__eyebrow">
              Commercial Property Exchange
            </span>

            <h1>Los Santos Business Portal</h1>
          </div>
        </div>

        <AppIconButton label="Close">
          <X :size="19" />
        </AppIconButton>
      </header>

      <div class="design-system-preview__badges">
        <AppBadge tone="primary">Tier 2</AppBadge>
        <AppBadge tone="success">Owned</AppBadge>
        <AppBadge>$25,000</AppBadge>
      </div>

      <AppSearchInput
        v-model="searchQuery"
        label="Search businesses"
        placeholder="Search gas stations..."
      />

      <section class="design-system-preview__progress">
        <div class="design-system-preview__progress-header">
          <div>
            <span>Investor Score</span>
            <strong>1,840 / 2,750 pts</strong>
          </div>

          <AppBadge tone="primary">
            Verified Investor
          </AppBadge>
        </div>

        <AppProgressBar
          :value="1840"
          :maximum="2750"
          label="Investor Score"
        />
      </section>

      <div class="design-system-preview__actions">
        <AppButton
          size="large"
          @click="purchaseModalOpen = true"
        >
          <ShoppingCart :size="18" />
          Purchase Business
        </AppButton>

        <AppButton
          variant="secondary"
          size="large"
        >
          <MapPin :size="18" />
          Set Waypoint
        </AppButton>
      </div>
    </AppSurface>

    <AppModal
      :open="purchaseModalOpen"
      eyebrow="Final review"
      title="Confirm Business Purchase"
      @close="purchaseModalOpen = false"
    >
      <div class="purchase-preview">
        <div>
          <span>Business</span>
          <strong>LTD Gasoline</strong>
        </div>

        <div>
          <span>Acquisition Price</span>
          <strong>$25,000</strong>
        </div>

        <div>
          <span>Balance After Purchase</span>
          <strong>$59,250</strong>
        </div>
      </div>

      <template #footer>
        <AppButton
          variant="secondary"
          @click="purchaseModalOpen = false"
        >
          Cancel
        </AppButton>

        <AppButton>
          Confirm Purchase
        </AppButton>
      </template>
    </AppModal>
  </main>
</template>

<style scoped lang="scss">
.design-system-preview {
  display: grid;
  width: 100%;
  height: 100%;
  padding: var(--space-6);
  place-items: center;
  background: var(--color-background);

  &__card {
    width: min(46rem, 100%);
    padding: var(--space-8);
  }

  &__header {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: var(--space-6);
    margin-bottom: var(--space-6);
  }

  &__identity {
    display: flex;
    align-items: center;
    gap: var(--space-4);
  }

  &__icon {
    display: grid;
    width: 3rem;
    height: 3rem;
    flex: 0 0 auto;
    place-items: center;
    border-radius: var(--radius-md);
    background: var(--color-primary-subtle);
    color: var(--color-primary);
  }

  &__eyebrow {
    display: block;
    margin-bottom: var(--space-1);
    color: var(--color-text-secondary);
    font-size: var(--font-size-xs);
    font-weight: var(--font-weight-medium);
  }

  &__badges {
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-2);
    margin-bottom: var(--space-4);
  }

  &__progress {
    display: grid;
    gap: var(--space-3);
    margin-top: var(--space-6);
    padding: var(--space-5);
    border: var(--border-width) solid var(--color-border);
    border-radius: var(--radius-md);
    background: var(--color-background);
  }

  &__progress-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-4);

    div {
      display: grid;
      gap: var(--space-1);
    }

    span {
      color: var(--color-text-secondary);
      font-size: var(--font-size-xs);
    }

    strong {
      font-size: var(--font-size-sm);
    }
  }

  &__actions {
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-3);
    margin-top: var(--space-6);
  }
}

.purchase-preview {
  display: grid;
  gap: var(--space-3);

  div {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-4);
    padding-bottom: var(--space-3);
    border-bottom: var(--border-width) solid var(--color-border);
  }

  span {
    color: var(--color-text-secondary);
    font-size: var(--font-size-sm);
  }

  strong {
    color: var(--color-text-primary);
    font-size: var(--font-size-sm);
  }
}
</style>