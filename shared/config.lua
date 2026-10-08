Config = {}

Config.Debug = true   -- set to false in production

Config.Currency = "$" -- currency symbol used in menus and notifications

-- true = prefer the player's in-game character name where one is shown
-- (e.g. the business transfer picker); false = always use their game name
Config.UseCharacterNames = true

--- Police interaction settings
Config.Police = {
    Jobs                  = { "police", "sheriff" }, -- jobs that can access police interactions
    RaidMinGrade          = 0,                       -- minimum grade required to raid a business
    DepositReviewMinGrade = 2,                       -- minimum grade required to review flagged bank deposits

    RaidTargetIcon        = "fa-solid fa-shield-halved",
    RaidTargetDistance    = 2.0,
}

Config.BusinessPortal = {
    Locale = "en",

    -- Runtime portal colors. Changes only require a resource restart.
    Theme = {
        -- Primary interaction colors
        PrimaryColor       = "#1687ff",
        PrimaryHoverColor  = "#3a9aff",
        PrimaryActiveColor = "#0a6fd8",
        PrimarySubtleColor = "rgb(22 135 255 / 14%)",

        -- Application surfaces
        BackgroundColor    = "#07111f",
        SurfaceColor       = "#0c1a2a",
        RaisedSurfaceColor = "#102238",
        HoverSurfaceColor  = "#142b45",

        -- Borders
        BorderColor       = "#1d3854",
        StrongBorderColor = "#2d5579",

        -- Typography
        PrimaryTextColor   = "#f3f7fb",
        SecondaryTextColor = "#bdcadb",
        MutedTextColor     = "#8295ac",

        -- Status colors
        SuccessColor       = "#20c985",
        SuccessSubtleColor = "rgb(32 201 133 / 14%)",
        WarningColor       = "#f2b84b",
        WarningSubtleColor = "rgb(242 184 75 / 14%)",
        DangerColor        = "#ef6262",
        DangerSubtleColor  = "rgb(239 98 98 / 14%)",
    },

    -- Computer and laptop models that provide access to the business portal
    Models = {
        "prop_monitor_01a",
        "prop_monitor_li",
        "prop_monitor_01d",
        "prop_monitor_04a",
        "prop_monitor_01c",
        "prop_laptop_lester",
        "prop_laptop_jimmy",
        "prop_laptop_lester2",
        "prop_laptop_01a",
        "h4_prop_h4_laptop_01a",
    },

    TargetDistance   = 2.0,
    TargetIcon       = "fa-solid fa-building",
}

--- Bank deposit settings
Config.BankDeposit = {
    ProcessingTime  = 10,   -- real minutes for a deposit to clear into personal bank
    PoliceKeepMoney = true, -- true = confiscated funds go to police job account, false = vanish

    -- The only guaranteed fee in the entire laundering pipeline - paid once,
    -- when a Safe balance converts into real bank money. Set to 0 to disable.
    Tax = 30,

    -- % chance a deposit is flagged based on business suspicion label at moment of teller interaction
    FlagChance      = {
        Low      = 0,
        Moderate = 15,
        High     = 50,
        Critical = 95,
    },
}

--- Reputation system
Config.Reputation = {
    Enable           = true,
    AutosaveInterval = 5, -- real minutes between automatic DB saves

    Commands         = {
        set    = { enable = true, name = "moneywash:rep:set" },
        add    = { enable = true, name = "moneywash:rep:add" },
        remove = { enable = true, name = "moneywash:rep:remove" },
    },

    -- Reputation point rewards per action
    -- enable = false to stop that action awarding points
    Rewards          = {
        launder          = { enable = true, points = 10 }, -- per successful launder action
        stockDelivery    = { enable = true, points = 5 },  -- per completed stock delivery mission
        bankDeposit      = { enable = true, points = 5 },  -- when a deposit clears into personal bank
        accountantReview = { enable = true, points = 15 }, -- per completed records review
        businessPurchase = { enable = true, points = 50 }, -- once per business type, first purchase only
    },

    -- Titles are purely cosmetic - the script checks points only
    Levels = {
        [0]     = "Unverified",
        [250]   = "Registered",
        [500]   = "Active Operator",
        [1000]  = "Established Operator",
        [1750]  = "Verified Investor",
        [2750]  = "Accredited Investor",
        [4000]  = "Senior Operator",
        [5500]  = "Portfolio Manager",
        [7500]  = "Commercial Investor",
        [10000] = "Institutional Buyer",
        [15000] = "Premium Member",
    },

    ProgressColors   = {
        { threshold = 0,   color = "#dc2626" },
        { threshold = 20,  color = "#f97316" },
        { threshold = 40,  color = "#facc15" },
        { threshold = 60,  color = "#84cc16" },
        { threshold = 80,  color = "#22c55e" },
        { threshold = 100, color = "#16a34a" },
    },
}

Config.CashCounter = {
    -- Number of piles used to represent the selected amount.
    -- Whole number between 1 and 20.
    StackCount = 3,

    -- Time spent counting EACH pile, in milliseconds.
    StackDurationMs = 1000,

    -- Automatically place a finished pile on the right tray.
    -- Loading the next pile remains manual.
    AutoMoveToRight = false,

    -- Maximum permitted amount for one batch.
    MaxAmount = 10000000,

    -- Maximum distance from the business handler.
    InteractionDistance = 5.0,
}