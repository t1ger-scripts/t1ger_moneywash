import { defineStore } from 'pinia'
import { ref } from 'vue'
export type UiScreen = 'marketplace' | 'cash-counter' | null
export const useUiStore = defineStore('ui', () => {
    const activeScreen = ref<UiScreen>(null)
    function open(screen: Exclude<UiScreen, null>) {
        activeScreen.value = screen
    }
    function close(screen: Exclude<UiScreen, null>) {
        if (activeScreen.value === screen) activeScreen.value = null
    }
    return { activeScreen, open, close }
})
