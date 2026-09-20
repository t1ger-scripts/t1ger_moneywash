import { shallowRef } from 'vue'

export type LocaleDictionary = Record<string, unknown>

type LocaleVariable = string | number
type LocaleVariables = Record<string, LocaleVariable>

const englishFallback: LocaleDictionary = {
    browser: {
        brand: {
            name: 'Ledger Capital',
            subtitle: 'Business Brokerage',
        },

        chrome: {
            close: 'Close browser',
            tab_suffix: 'Ledger Capital',
            protocol: 'https://',
            domain: 'ledgercapital.com',
            secure_session: 'Secure Session',
            path_marketplace: 'marketplace',
            path_portfolio: 'portfolio',
        },

        navigation: {
            primary_label: 'Primary navigation',
            marketplace: 'Marketplace',
            portfolio: 'My Portfolio',
            help_center: 'Help Center',
        },

        account: {
            heading: 'Your Account',
            membership_status: 'Membership Status',
            investor_score: 'Investor Score',
            progress_to: 'Progress to {level}',
            maximum_status: 'Maximum status achieved',
            portfolio_usage: 'Portfolio Usage',
        },
    },
}

const activeLocales =
    shallowRef<LocaleDictionary>({})

function resolveLocaleValue(
    dictionary: LocaleDictionary,
    path: string,
): unknown {
    return path.split('.').reduce<unknown>(
        (current, segment) => {
            if (
                !current ||
                typeof current !== 'object' ||
                Array.isArray(current)
            ) {
                return undefined
            }

            return (
                current as Record<string, unknown>
            )[segment]
        },
        dictionary,
    )
}

function replaceVariables(
    value: string,
    variables: LocaleVariables,
): string {
    return value.replace(
        /\{([a-zA-Z0-9_]+)\}/g,
        (match, variable: string) => {
            const replacement = variables[variable]

            return replacement === undefined
                ? match
                : String(replacement)
        },
    )
}

export function setLocales(
    locales?: LocaleDictionary,
) {
    activeLocales.value =
        locales && typeof locales === 'object'
            ? locales
            : {}
}

export function t(
    key: string,
    variables: LocaleVariables = {},
): string {
    const runtimeValue = resolveLocaleValue(
        activeLocales.value,
        key,
    )

    const fallbackValue = resolveLocaleValue(
        englishFallback,
        key,
    )

    const value =
        typeof runtimeValue === 'string'
            ? runtimeValue
            : typeof fallbackValue === 'string'
                ? fallbackValue
                : key

    return replaceVariables(value, variables)
}