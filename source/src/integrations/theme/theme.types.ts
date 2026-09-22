export interface PortalThemeConfig {
    AccentColor?: string
    AccentHoverColor?: string
    AccentDarkColor?: string
    AccentSoftColor?: string

    BodyColor?: string
    PanelColor?: string
    PanelAltColor?: string
    CardColor?: string

    BorderColor?: string
    BorderSoftColor?: string

    TextColor?: string
    MutedTextColor?: string

    SuccessColor?: string
    WarningColor?: string
    DangerColor?: string
}

export type ThemeVariableName = `--${string}`