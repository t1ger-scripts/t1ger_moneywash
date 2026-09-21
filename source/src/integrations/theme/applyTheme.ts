import type {
    BrowserThemeConfig,
    ThemeVariableName,
} from './theme.types'

const themeVariables:
    Readonly<
        Partial<
            Record<
                keyof BrowserThemeConfig,
                ThemeVariableName
            >
        >
    > = {
    AccentColor: '--color-primary',
    AccentHoverColor: '--color-primary-hover',
    AccentDarkColor: '--color-primary-active',
    AccentSoftColor: '--color-primary-subtle',

    BodyColor: '--color-background',
    PanelColor: '--color-surface',
    PanelAltColor: '--color-surface-raised',
    CardColor: '--color-surface-hover',

    BorderColor: '--color-border-strong',
    BorderSoftColor: '--color-border',

    TextColor: '--color-text-primary',
    MutedTextColor: '--color-text-secondary',

    SuccessColor: '--color-success',
    WarningColor: '--color-warning',
    DangerColor: '--color-danger',
}

function isValidCssColor(value: string): boolean {
    return CSS.supports('color', value)
}

export function applyTheme(
    theme: BrowserThemeConfig | undefined,
): void {
    if (!theme) {
        return
    }

    const root = document.documentElement

    for (
        const [configKey, cssVariable]
        of Object.entries(themeVariables)
    ) {
        const value =
            theme[configKey as keyof BrowserThemeConfig]

        if (
            typeof value === 'string' &&
            cssVariable &&
            isValidCssColor(value)
        ) {
            root.style.setProperty(
                cssVariable,
                value.trim(),
            )
        }
    }
}