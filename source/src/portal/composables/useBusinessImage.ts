import { computed, ref, watch } from 'vue'

/** The picture of a business: its URL, or null when it has none or it failed to load. */
export function useBusinessImage(imageFileName: () => string | undefined) {
    const failed = ref(false)

    const imageSource = computed(() => {
        const fileName = imageFileName()?.trim()
        if (!fileName || failed.value) return null

        return `./images/businesses/${encodeURIComponent(fileName)}`
    })

    watch(imageFileName, () => {
        failed.value = false
    })

    function handleImageError(): void {
        failed.value = true
    }

    return { imageSource, handleImageError }
}