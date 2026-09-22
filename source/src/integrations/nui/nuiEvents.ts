export const NUI_CALLBACKS = {
    ready: 't1ger_moneywash:portal:ready',
    purchaseBusiness: 't1ger_moneywash:portal:purchaseBusiness',
    setBusinessWaypoint: 't1ger_moneywash:portal:setBusinessWaypoint',
    close: 't1ger_moneywash:portal:close',
} as const

export const NUI_MESSAGES = {
    open: 't1ger_moneywash:portal:open',
    refresh: 't1ger_moneywash:portal:refresh',
    close: 't1ger_moneywash:portal:close',
} as const

export type NuiCallbackName =
    (typeof NUI_CALLBACKS)[keyof typeof NUI_CALLBACKS]

export type NuiMessageName =
    (typeof NUI_MESSAGES)[keyof typeof NUI_MESSAGES]