<script setup lang="ts">
import { Building2, MapPin, X } from '@lucide/vue'

import {
  AppBadge,
  AppButton,
  AppIconButton,
  AppSurface,
} from './design-system'
</script>

<template>
  <main class="design-system-preview">
    <AppSurface
      class="design-system-preview__card"
      elevation="raised"
    >
      <header class="design-system-preview__header">
        <div class="design-system-preview__icon">
          <Building2 :size="24" />
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

      <h1>Los Santos Business Portal</h1>

      <p>
        Commercial opportunities, verified ownership and secure acquisitions.
      </p>

      <div class="design-system-preview__actions">
        <AppButton size="large">
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
    width: min(42rem, 100%);
    padding: var(--space-8);
  }

  &__header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: var(--space-6);
  }

  &__icon {
    display: grid;
    width: 3rem;
    height: 3rem;
    place-items: center;
    border-radius: var(--radius-md);
    background: var(--color-primary-subtle);
    color: var(--color-primary);
  }

  &__badges {
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-2);
    margin-bottom: var(--space-4);
  }

  p {
    margin-top: var(--space-3);
    color: var(--color-text-secondary);
  }

  &__actions {
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-3);
    margin-top: var(--space-8);
  }
}
</style>