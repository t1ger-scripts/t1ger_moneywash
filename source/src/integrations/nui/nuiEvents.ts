export const NUI_CALLBACKS = {
    ready: 't1ger_moneywash:browser:ready',
    purchaseBusiness: 't1ger_moneywash:browser:purchaseBusiness',
    setBusinessWaypoint: 't1ger_moneywash:browser:setBusinessWaypoint',
    close: 't1ger_moneywash:browser:close',
} as const

export const NUI_MESSAGES = {
    open: 't1ger_moneywash:browser:open',
    refresh: 't1ger_moneywash:browser:refresh',
    close: 't1ger_moneywash:browser:close',
} as const

export type NuiCallbackName =
    (typeof NUI_CALLBACKS)[keyof typeof NUI_CALLBACKS]

export type NuiMessageName =
    (typeof NUI_MESSAGES)[keyof typeof NUI_MESSAGES]