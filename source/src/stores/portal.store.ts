import { ref } from 'vue'
import { defineStore } from 'pinia'

export const usePortalStore = defineStore('portal', () => {
    const isVisible = ref(false)
    const isLoading = ref(false)
    const errorMessage = ref<string | null>(null)

    function show(): void {
        isVisible.value = true
        isLoading.value = false
        errorMessage.value = null
    }

    function hide(): void {
        isVisible.value = false
        isLoading.value = false
        errorMessage.value = null
    }

    function showLoading(): void {
        isVisible.value = true
        isLoading.value = true
        errorMessage.value = null
    }

    function showError(message: string): void {
        isVisible.value = true
        isLoading.value = false
        errorMessage.value = message
    }

    return {
        isVisible,
        isLoading,
        errorMessage,
        show,
        hide,
        showLoading,
        showError,
    }
})