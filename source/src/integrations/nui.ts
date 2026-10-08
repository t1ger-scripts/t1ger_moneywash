export const NUI_CALLBACKS = {
    uiReady: 't1ger_moneywash:ui:ready',

    cashStart: 't1ger_moneywash:cashCounter:start',
    cashConfirm: 't1ger_moneywash:cashCounter:confirm',
    cashStatus: 't1ger_moneywash:cashCounter:status',
    cashClose: 't1ger_moneywash:cashCounter:close',

    ready: 't1ger_moneywash:portal:ready',
    purchaseBusiness: 't1ger_moneywash:portal:purchaseBusiness',
    setBusinessWaypoint: 't1ger_moneywash:portal:setBusinessWaypoint',
    close: 't1ger_moneywash:portal:close',
} as const

export const NUI_MESSAGES = {
    cashOpen: 't1ger_moneywash:cashCounter:open',
    cashClose: 't1ger_moneywash:cashCounter:close',

    open: 't1ger_moneywash:portal:open',
    refresh: 't1ger_moneywash:portal:refresh',
    close: 't1ger_moneywash:portal:close',
} as const

export type NuiCallbackName =
    (typeof NUI_CALLBACKS)[keyof typeof NUI_CALLBACKS]

export type NuiMessageName =
    (typeof NUI_MESSAGES)[keyof typeof NUI_MESSAGES]

export interface NuiResponse<TData = undefined> {
    success: boolean
    reason?: string
    data?: TData
}

export interface NuiMessage<TData = unknown> {
    action: string
    data?: TData
}

const FALLBACK_RESOURCE_NAME = 't1ger_moneywash'

export function isFiveMEnvironment(): boolean {
    return typeof window.GetParentResourceName === 'function'
}

function getResourceName(): string {
    return window.GetParentResourceName?.() ?? FALLBACK_RESOURCE_NAME
}

export async function postNui<
    TResponse,
    TRequest extends object = Record<string, never>,
>(
    callbackName: NuiCallbackName,
    request = {} as TRequest,
): Promise<TResponse> {
    if (!isFiveMEnvironment()) {
        throw new Error(
            `NUI callback "${callbackName}" is unavailable outside FiveM.`,
        )
    }

    const response = await fetch(
        `https://${getResourceName()}/${callbackName}`,
        {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8',
            },
            body: JSON.stringify(request),
        },
    )

    if (!response.ok) {
        throw new Error(
            `NUI callback "${callbackName}" failed with status ${response.status}.`,
        )
    }

    return response.json() as Promise<TResponse>
}

export function onNuiMessage<TData>(
    messageName: NuiMessageName,
    handler: (data: TData) => void,
): () => void {
    const listener = (event: MessageEvent<NuiMessage<TData>>) => {
        const message = event.data

        if (!message || typeof message !== 'object') return
        if (message.action !== messageName) return

        handler(message.data as TData)
    }

    window.addEventListener('message', listener)

    return () => {
        window.removeEventListener('message', listener)
    }
}