<script setup lang="ts">
import MarketplaceView from '@/features/marketplace/MarketplaceView.vue'
import { usePortalLifecycle } from '@/composables/usePortalLifecycle'
import { usePortalStore } from '@/stores/portal.store'

const portalStore = usePortalStore()

usePortalLifecycle()
</script>

<template>
  <div v-if="portalStore.isVisible" class="portal-root">
    <div class="portal-root__window">
      <MarketplaceView />
    </div>
  </div>
</template>

<style scoped lang="scss">
.portal-root {
  display: grid;
  width: 100vw;
  height: 100vh;
  overflow: hidden;
  place-items: center;
  background:
    radial-gradient(circle at 50% 38%,
      rgba(29, 33, 39, 0.74),
      rgba(4, 6, 8, 0.96) 70%);

  &__window {
    width: clamp(80vw, calc(20vw + 72rem), 92vw);
    height: clamp(80vh, calc(40vh + 27rem), 88vh);
    min-width: 0;
    min-height: 0;
    overflow: hidden;
    container-name: portal;
    container-type: inline-size;
    border: var(--border-width) solid var(--color-border-strong);
    border-radius: var(--radius-xl);
    background: var(--color-background);
    box-shadow: var(--shadow-modal);
  }
}

</style>