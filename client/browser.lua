local function loadBrowserLocale()
    -- Change Config.Locale if your locale setting uses another name.
    local locale = Config.Locale or 'en'
    local localePath = ('locales/%s.json'):format(locale)
    local localeFile = LoadResourceFile(GetCurrentResourceName(), localePath)

    -- Fall back to English if the configured locale does not exist.
    if not localeFile and locale ~= 'en' then
        localeFile = LoadResourceFile(
            GetCurrentResourceName(),
            'locales/en.json'
        )
    end

    if not localeFile then
        print(('[t1ger_moneywash] Unable to load locale: %s'):format(localePath))
        return {}
    end

    local success, decoded = pcall(json.decode, localeFile)

    if not success or type(decoded) ~= 'table' then
        print(('[t1ger_moneywash] Invalid locale JSON: %s'):format(localePath))
        return {}
    end

    return decoded.browser_ui or {}
end

local browserLocale = loadBrowserLocale()

RegisterNUICallback('t1ger_moneywash:nui:ready', function(_, cb)
    SendNUIMessage({
        action = 't1ger_moneywash:browser:setConfig',

        data = {
            theme = {
                accentColor      = Config.BrowserUI.Theme.AccentColor,
                accentHoverColor = Config.BrowserUI.Theme.AccentHoverColor,
                accentDarkColor  = Config.BrowserUI.Theme.AccentDarkColor,

                bodyColor        = Config.BrowserUI.Theme.BodyColor,
                panelColor       = Config.BrowserUI.Theme.PanelColor,
                panelAltColor    = Config.BrowserUI.Theme.PanelAltColor,
                cardColor        = Config.BrowserUI.Theme.CardColor,
                borderColor      = Config.BrowserUI.Theme.BorderColor,

                textColor        = Config.BrowserUI.Theme.TextColor,
                mutedTextColor   = Config.BrowserUI.Theme.MutedTextColor,

                successColor     = Config.BrowserUI.Theme.SuccessColor,
                warningColor     = Config.BrowserUI.Theme.WarningColor,
                dangerColor      = Config.BrowserUI.Theme.DangerColor,
            },

            locale = browserLocale,
        }
    })

    cb({ ok = true })
end)