<script setup lang="ts">
import MarketplaceView from '@/features/marketplace/MarketplaceView.vue'
import { usePortalLifecycle } from '@/composables/usePortalLifecycle'
import { usePortalStore } from '@/stores/portal.store'

const portalStore = usePortalStore()

usePortalLifecycle()
</script>

<template>
  <div v-if="portalStore.isVisible" class="portal-root">
    <MarketplaceView />
  </div>
</template>

<style scoped lang="scss">
.portal-root {
  width: 100vw;
  height: 100vh;
  overflow: hidden;
  background: var(--color-background);
}
</style>