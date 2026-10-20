import type { LocaleMessages } from '@/integrations/i18n'

export interface RaidDeposit {
    id: number
    x: number
    y: number
}

/** Sent by the client when a raid starts. */
export interface RaidPayload {
    currency: string
    locale: string
    messages: LocaleMessages
    /** Number of cash piles the exposed Safe money is split into. */
    stackCount: number
    /** Exposed Safe cash at the moment the raid started. */
    exposed: number
}

/** Returned by the raid:finish callback. */
export interface RaidResult {
    /** What the server really seized. This is the number that counts. */
    seized: number
}