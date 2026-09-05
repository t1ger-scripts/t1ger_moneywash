--- Opens the main menu when interacting with the Accountant NPC
function OpenAccountantMenu()
    local menuOptions = {}

    -- is reputation system enabled?
    local reputationSystem = Config.Reputation and Config.Reputation.Enable or false

    -- reputation option
    if reputationSystem then
        local rep = GetReputationData()

        menuOptions[#menuOptions+1] = {
            title = locale("menu_title.reputation"),
            description = string.format(locale("menu_description.reputation"), rep.title, rep.points),
            icon = Config.Reputation.MenuIcon,
            metadata = {
                {label = locale("menu_metadata.points"), value = rep.points},
                {label = locale("menu_metadata.level"), value = rep.title},
                {label = locale("menu_metadata.progress"), value = string.format("%s%%", rep.progress)},
            },
            progress = rep.progress,
            colorScheme = rep.color,
            readOnly = true,
        }
    end

    -- TODO: Street Contracts option
    -- TODO: Business Access option
    -- TODO: Books Cleaner Service option
    -- TODO: Transfer Business Ownership option

    -- return if no menu options
    if #menuOptions <= 0 then
        return
    end

    -- register context and show context
    lib.registerContext({
        id = "t1ger_moneywash:accountant:main",
        title = locale("menu_title.accountant_main"),
        options = menuOptions
    })
    lib.showContext("t1ger_moneywash:accountant:main")
end