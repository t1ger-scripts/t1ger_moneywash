import { computed, ref } from 'vue'
import { defineStore } from 'pinia'
import { useUiStore } from '@/shared/stores/ui.store'
import { failureMessage, installLocaleMessages } from '@/integrations/i18n'
import {
    postNui,
    NUI_CALLBACKS,
    type NuiResponse,
} from '@/integrations/nui'
import { splitRaidCash } from '../utils/raid.utils'
import type { RaidPayload, RaidResult } from '../raid.types'

/**
 * Raid evidence collection.
 *
 * The piles are fixed when the raid starts: the owner cannot touch the Safe
 * while a raid runs. Sealing the bag asks the server to finish the raid, and
 * the amount the server returns is what the officer sees as seized.
 */
export const useRaidStore = defineStore('raid', () => {
    const ui = useUiStore()

    const payload = ref<RaidPayload | null>(null)
    const packedIds = ref<number[]>([])
    const sealed = ref(false)
    const submitting = ref(false)
    const seized = ref(0)
    const error = ref('')

    let generation = 0
    let closeTimer: ReturnType<typeof setTimeout> | undefined

    const amount = computed(() => payload.value?.exposed ?? 0)
    const stackCount = computed(() => payload.value?.stackCount ?? 10)

    const piles = computed(() =>
        splitRaidCash(amount.value, stackCount.value),
    )

    const packedAmount = computed(() =>
        packedIds.value.reduce(
            (total, id) => total + (piles.value[id] ?? 0),
            0,
        ),
    )

    const allPacked = computed(() =>
        piles.value.length > 0 &&
        packedIds.value.length === piles.value.length,
    )

    /** While packing: what is in the bag. After sealing: what the server seized. */
    const displayAmount = computed(() =>
        sealed.value ? seized.value : packedAmount.value,
    )

    function format(value: number): string {
        const currency = payload.value?.currency ?? '$'
        const locale = payload.value?.locale ?? 'en'

        return `${currency}${Math.floor(
            Math.max(0, value),
        ).toLocaleString(locale)}`
    }

    function open(data: RaidPayload) {
        generation++
        clearTimeout(closeTimer)

        payload.value = data

        installLocaleMessages(data.locale, data.messages)

        packedIds.value = []
        sealed.value = false
        submitting.value = false
        seized.value = 0
        error.value = ''

        ui.open('raid')
    }

    function packPile(id: number): boolean {
        if (
            sealed.value ||
            submitting.value ||
            !Number.isInteger(id) ||
            id < 0 ||
            id >= piles.value.length ||
            packedIds.value.includes(id)
        ) return false

        packedIds.value.push(id)

        return true
    }

    /**
     * Asks the server to finish the raid. The seal only counts as done once
     * the server accepts it; a refusal resets the strip and shows an error.
     */
    async function sealBag(): Promise<boolean> {
        if (
            !payload.value ||
            !allPacked.value ||
            sealed.value ||
            submitting.value
        ) return false

        const version = ++generation

        submitting.value = true
        error.value = ''

        try {
            const response = await postNui<
                NuiResponse<RaidResult>
            >(NUI_CALLBACKS.raidFinish)

            if (version !== generation) return false

            if (!response.success || !response.data) {
                error.value = failureMessage(response)
                return false
            }

            seized.value = Math.max(0, Math.floor(response.data.seized))
            sealed.value = true

            // Leave the real amount on screen for a moment, then close.
            closeTimer = setTimeout(() => {
                if (version === generation) void close()
            }, 800)

            return true
        } catch {
            if (version === generation) error.value = failureMessage()

            return false
        } finally {
            if (version === generation) submitting.value = false
        }
    }

    function dismiss() {
        generation++
        clearTimeout(closeTimer)

        ui.close('raid')

        payload.value = null
        packedIds.value = []
        sealed.value = false
        submitting.value = false
        seized.value = 0
        error.value = ''
    }

    /** Closes the screen and tells Lua, so the mouse and keyboard are released. */
    async function close() {
        dismiss()

        try {
            await postNui(NUI_CALLBACKS.raidClose)
        } catch {
            // Resource shutdown also performs cleanup.
        }
    }

    return {
        payload,
        amount,
        stackCount,
        piles,
        packedIds,
        packedAmount,
        allPacked,
        displayAmount,
        sealed,
        submitting,
        error,
        format,
        open,
        packPile,
        sealBag,
        dismiss,
        close,
    }
})