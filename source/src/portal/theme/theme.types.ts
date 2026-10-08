export interface PortalThemeConfig {
    PrimaryColor?: string
    PrimaryHoverColor?: string
    PrimaryActiveColor?: string
    PrimarySubtleColor?: string

    BackgroundColor?: string
    SurfaceColor?: string
    RaisedSurfaceColor?: string
    HoverSurfaceColor?: string

    BorderColor?: string
    StrongBorderColor?: string

    PrimaryTextColor?: string
    SecondaryTextColor?: string
    MutedTextColor?: string

    SuccessColor?: string
    SuccessSubtleColor?: string
    WarningColor?: string
    WarningSubtleColor?: string
    DangerColor?: string
    DangerSubtleColor?: string
}

export type ThemeVariableName = `--${string}`