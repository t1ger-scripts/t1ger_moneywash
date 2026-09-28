import { computed } from 'vue'
import { defineStore } from 'pinia'
import { useUiStore } from './ui.store'
// Compatibility facade for existing marketplace components.
export const usePortalStore = defineStore('portal', () => {
    const ui = useUiStore()
    const isVisible = computed(() => ui.activeScreen === 'marketplace')
    return {
        isVisible,
        show: () => ui.open('marketplace'),
        hide: () => ui.close('marketplace'),
    }
})
