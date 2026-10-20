import { defineStore } from 'pinia'
import { useUiStore } from '@/shared/stores/ui.store'

export const useReviewStore = defineStore('review', () => {
    const ui = useUiStore()

    function open() {
        ui.open('review')
    }

    function dismiss() {
        ui.close('review')
    }

    return {
        open,
        dismiss,
    }
})