export function formatNumber(
    value: number,
    locale = 'en-US',
): string {
    return new Intl.NumberFormat(locale, {
        maximumFractionDigits: 0,
    }).format(value)
}

export function formatCurrency(
    value: number,
    currencySymbol: string,
    locale = 'en-US',
): string {
    return `${currencySymbol}${formatNumber(value, locale)}`
}