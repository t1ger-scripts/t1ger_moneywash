export const isFiveM = typeof window !== 'undefined' && 'invokeNative' in window

export async function nuiFetch<T = unknown>(event: string, data: unknown = {}): Promise<T | null> {
  if (!isFiveM) return null

  const resourceName = (window as typeof window & { GetParentResourceName?: () => string })
    .GetParentResourceName?.() ?? 't1ger_moneywash'

  const response = await fetch(`https://${resourceName}/${event}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data),
  })

  return response.json() as Promise<T>
}
