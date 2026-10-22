import { useI18n } from 'vue-i18n'

import { usePortalStore } from '@/portal/stores/portal.store'

/** Formats numbers and money for the UI language and the configured currency symbol. */
export function usePortalFormat() {
    const { locale } = useI18n()
    const portal = usePortalStore()

    function formatCount(value: number): string {
        return new Intl.NumberFormat(locale.value, { maximumFractionDigits: 0 }).format(value)
    }

    function formatMoney(value: number): string {
        return `${portal.currencySymbol}${formatCount(value)}`
    }

    return { formatCount, formatMoney }
}