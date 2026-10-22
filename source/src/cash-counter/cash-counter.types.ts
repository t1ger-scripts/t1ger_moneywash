import type { LocaleMessages } from '@/integrations/i18n'

/** Optional: anything Lua leaves out falls back to the UI default. */
export interface CashCounterSettings {
    stackCount?: number
    autoMoveToRight?: boolean
}

/** Sent by Lua when OpenCashCounter is called. */
export interface CashCounterPayload {
    amount: number
    currency?: string
    locale: string
    messages: LocaleMessages
    settings?: CashCounterSettings
}

export type CounterPhase = 'idle' | 'counting' | 'collect'

export interface CashPile {
    id: number
    amount: number
    slot: number
}