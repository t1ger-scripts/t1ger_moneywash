import type {
    PortalThemeConfig,
    ThemeVariableName,
} from './theme.types'

const themeVariables:
    Readonly<
        Partial<
            Record<
                keyof PortalThemeConfig,
                ThemeVariableName
            >
        >
    > = {
    PrimaryColor: '--color-primary',
    PrimaryHoverColor: '--color-primary-hover',
    PrimaryActiveColor: '--color-primary-active',
    PrimarySubtleColor: '--color-primary-subtle',

    BackgroundColor: '--color-background',
    SurfaceColor: '--color-surface',
    RaisedSurfaceColor: '--color-surface-raised',
    HoverSurfaceColor: '--color-surface-hover',

    BorderColor: '--color-border',
    StrongBorderColor: '--color-border-strong',

    PrimaryTextColor: '--color-text-primary',
    SecondaryTextColor: '--color-text-secondary',
    MutedTextColor: '--color-text-muted',

    SuccessColor: '--color-success',
    SuccessSubtleColor: '--color-success-subtle',
    WarningColor: '--color-warning',
    WarningSubtleColor: '--color-warning-subtle',
    DangerColor: '--color-danger',
    DangerSubtleColor: '--color-danger-subtle',
}

function isValidCssColor(value: string): boolean {
    return CSS.supports('color', value)
}

export function applyTheme(
    theme: PortalThemeConfig | undefined,
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
            theme[configKey as keyof PortalThemeConfig]

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