interface FiveMWindow extends Window {
  GetParentResourceName?: () => string
  invokeNative?: (...args: unknown[]) => unknown
}

const nuiWindow =
  typeof window !== 'undefined'
    ? window as FiveMWindow
    : undefined

export const isFiveM =
  typeof nuiWindow?.GetParentResourceName === 'function'

export async function nuiFetch<T = unknown>(
  event: string,
  data: unknown = {},
): Promise<T | null> {
  if (!isFiveM || !nuiWindow) {
    return null
  }

  const resourceName =
    nuiWindow.GetParentResourceName?.() ??
    't1ger_moneywash'

  const response = await fetch(
    `https://${resourceName}/${event}`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: JSON.stringify(data),
    },
  )

  return response.json() as Promise<T>
}