Config = {}

Config.Debug = true   -- set to false in production

Config.Currency = "$" -- currency symbol used in menus and notifications

--- Defines how dirty (unlaundered) money is represented on your server.
--- Supports account-based dirty money (e.g. black_money) or item-based
--- (stacked or metadata, e.g. markedbills). No logic files need changing.
Config.DirtyMoney = {
    useItem = true,          -- false = use an account balance instead of an item
    account = "black_money", -- account type when useItem = false

    item = {
        name = "markedbills", -- dirty cash item name
        metadata = false,     -- true if item uses metadata (e.g. qbcore markedbills)
        metadataTemplate = function(amount)
            return { worth = amount }
        end,
    },
}

--- Police interaction settings
Config.Police = {
    Jobs                  = { "police", "sheriff" }, -- jobs that can access police interactions
    RaidMinGrade          = 0,                       -- minimum grade required to raid a business
    DepositReviewMinGrade = 2,                       -- minimum grade required to review flagged bank deposits
}

Config.Browser = {
    -- Ped/prop models that open the dark web browser on target interact
    -- Add any laptop, computer or phone model you want
    Models         = { "prop_monitor_01a", "prop_monitor_li", "prop_monitor_01d", "prop_monitor_04a", "prop_monitor_01c", "prop_laptop_lester", "prop_laptop_jimmy", "prop_laptop_lester2", "prop_laptop_01a", "h4_prop_h4_laptop_01a" },
    TargetDistance = 2.0,
    TargetIcon     = "fa-solid fa-terminal",
    TargetLabel    = "Access Network",
}

--- Bank deposit settings
Config.BankDeposit = {
    ProcessingTime  = 10,   -- real minutes for a deposit to clear into personal bank
    PoliceKeepMoney = true, -- true = confiscated funds go to police job account, false = vanish

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
    }

    ProgressColors   = {
        { threshold = 0,   color = "#dc2626" },
        { threshold = 20,  color = "#f97316" },
        { threshold = 40,  color = "#facc15" },
        { threshold = 60,  color = "#84cc16" },
        { threshold = 80,  color = "#22c55e" },
        { threshold = 100, color = "#16a34a" },
    },
}

Config.BrowserUI = {
    Theme = {
        AccentColor      = '#E7C30D',
        AccentHoverColor = '#F5D329',
        AccentDarkColor  = '#8F7910',

        BodyColor        = '#080908',
        PanelColor       = '#0E100F',
        PanelAltColor    = '#141713',
        CardColor        = '#111411',
        BorderColor      = '#282B27',

        TextColor        = '#F0F1ED',
        MutedTextColor   = '#858A82',

        SuccessColor     = '#76C97A',
        WarningColor     = '#D39A4C',
        DangerColor      = '#D65F58',
    }
}
