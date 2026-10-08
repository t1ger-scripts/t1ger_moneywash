import type { LocaleMessages } from '@/integrations/i18n'

export interface CashCounterSettings {
    stackCount: number
    stackDurationMs: number
    autoMoveToRight: boolean
}

export interface CounterBatch {
    id: number
    amount: number
    durationMs: number
    remainingMs: number
    status: 'counting' | 'ready' | 'settling' | 'complete' | 'review'
}

export interface CashCounterPayload {
    businessId: number
    operation: string
    available: number
    currency: string
    locale: string
    messages: LocaleMessages
    titleKey: string
    successKey: string
    settings: CashCounterSettings
    batch?: CounterBatch
}

export interface CounterStatus {
    available: number
    batch?: CounterBatch
}