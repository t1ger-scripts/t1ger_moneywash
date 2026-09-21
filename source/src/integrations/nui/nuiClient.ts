import type { NuiCallbackName, NuiMessageName } from './nuiEvents'
import type { NuiMessage } from './nui.types'

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