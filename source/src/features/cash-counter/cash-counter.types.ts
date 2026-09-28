import type { LocaleMessages } from '@/integrations/localization/localization.types'
export interface CounterBatch {
    id: number
    amount: number
    durationMs: number
    remainingMs: number
    status: 'counting' | 'complete' | 'review'
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
    batch?: CounterBatch
}
export interface CounterStatus {
    available: number
    batch?: CounterBatch
}
