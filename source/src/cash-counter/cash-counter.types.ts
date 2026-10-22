import type { LocaleMessages } from '@/integrations/i18n'

export interface CashCounterSettings {
    stackCount: number
    stackDurationMs: number
    autoMoveToRight: boolean
}

/** Sent by Lua when OpenCashCounter is called. */
export interface CashCounterPayload {
    amount: number
    currency: string
    locale: string
    messages: LocaleMessages
    settings: CashCounterSettings
}

export type CounterPhase = 'idle' | 'counting' | 'collect'

export interface CashPile {
    id: number
    amount: number
    slot: number
}