import { ref } from 'vue'
import { defineStore } from 'pinia'

export const usePortalStore = defineStore('portal', () => {
    const isVisible = ref(false)

    function show(): void {
        isVisible.value = true
    }

    function hide(): void {
        isVisible.value = false
    }

    return {
        isVisible,
        show,
        hide,
    }
})