Config = {}

-- General settings
Config.Debug             = true  -- Debug prints (set to false in production)
Config.Currency          = "$"   -- Currency symbol in menus and notifications
Config.UseCharacterNames = true  -- true = character name, false = game name (e.g. transfer picker)

-- Business settings: revenue cycle, business ladder and locations
-- cycleLaundered (memory only) resets each cycle; suspicion, stock, safe balances and receipts persist
Config.Business = {
    CycleDuration = 48, -- Cycle length in real minutes (48 = one in-game day)

    -- Business ladder
    -- type:            Internal key, must match a key in shared/locations.lua
    -- label:           Display name in menus
    -- requiredPoints:  Reputation needed to buy this tier
    -- npc:             Handler ped model spawned after purchase
    -- expectedRevenue: Max believable gross revenue per cycle (all stock economy values derive from it)
    Tiers = {
        [1] = { type = "coffee_shop", label = "Coffee Shop", requiredPoints = 0,     npc = "s_m_y_waiter_01",  expectedRevenue = 3000 },
        [2] = { type = "gas_station", label = "Gas Station", requiredPoints = 500,   npc = "s_m_y_xmech_01",   expectedRevenue = 6000 },
        [3] = { type = "restaurant",  label = "Restaurant",  requiredPoints = 1500,  npc = "s_m_y_chef_01",    expectedRevenue = 10000 },
        [4] = { type = "laundromat",  label = "Laundromat",  requiredPoints = 2750,  npc = "s_m_o_busker_01",  expectedRevenue = 15000 },
        [5] = { type = "bar",         label = "Bar",         requiredPoints = 4000,  npc = "s_m_y_barman_01",  expectedRevenue = 22000 },
        [6] = { type = "nightclub",   label = "Nightclub",   requiredPoints = 5500,  npc = "s_m_y_clubbar_01", expectedRevenue = 32000 },
        [7] = { type = "stripclub",   label = "Strip Club",  requiredPoints = 7500,  npc = "s_m_y_doorman_01", expectedRevenue = 45000 },
        [8] = { type = "carwash",     label = "Car Wash",    requiredPoints = 10000, npc = "s_m_y_winclean_01", expectedRevenue = 65000 },
        [9] = { type = "casino",      label = "Casino",      requiredPoints = 15000, npc = "s_m_y_casino_01",  expectedRevenue = 100000 },
    },

    Locations = require("shared/locations") -- all business locations, see shared/locations.lua
}

-- Business handler ped: idle animation, spawn range, target option and map blip
Config.HandlerNPC = {
    Scenario      = "WORLD_HUMAN_STAND_IMPATIENT", -- Idle animation
    SpawnDistance = 50.0,                          -- Ped spawn range
    TransferDistance = 10.0,                       -- Max distance between two players for a business transfer

    Target        = {
        icon     = "fa-solid fa-briefcase",        -- Target icon
        distance = 2.0,                            -- Target range
    },

    Blip          = {
        sprite  = 375,                             -- Blip sprite
        display = 4,                               -- Blip display mode
        scale   = 0.7,                             -- Blip size
        color   = 2,                               -- Blip color
    },

    -- Icons shown for each option in the Handler NPC's main menu and its submenus
    MenuIcons = {
        overview       = "fa-solid fa-chart-line",
        launder        = "fa-solid fa-money-bill-wave",
        stock          = "fa-solid fa-boxes-stacked",
        viewStock      = "fa-solid fa-warehouse",
        cycleReadiness = "fa-solid fa-gauge-high",
        orderStock     = "fa-solid fa-box",
        reviewBooks    = "fa-solid fa-folder-open",
        safe           = "fa-solid fa-lock",
        safeCovered    = "fa-solid fa-shield-halved",
        safeExposed    = "fa-solid fa-triangle-exclamation",
        bankDeposit    = "fa-solid fa-building-columns",
        manage         = "fa-solid fa-gear",
        transfer       = "fa-solid fa-right-left",
        abandon        = "fa-solid fa-door-open",
    }
}

-- Police access, business raids and alert blips
Config.Police = {
    Jobs                  = { "police", "sheriff" }, -- Jobs with police access
    DepositReviewMinGrade = 2,                       -- Min grade to review flagged deposits
    AlertNotifyDuration   = 10000,                   -- Alert notification time (ms)

    -- Raid a business via the handler ped
    Raid                  = {
        Enable         = true,
        MinGrade       = 1,                                                  -- Min grade to raid
        Target         = { icon = "fa-solid fa-shield-halved", distance = 2.0 }, -- Target icon and range
        StackCount     = 10,                                                 -- Cash piles in the safe (1-20)
        MaxTime        = 5,                                                  -- Minutes until an unfinished raid is cancelled
        Cooldown       = 60,                                                 -- Minutes before the same business can be raided again (resets on restart)

        -- Suspicion after a raid (never raises it)
        -- "set": drops to Value if higher | "reduce": lowers by Value % of current
        SuspicionAfter = { Mode = "set", Value = 50 },
    },

    -- Alerts per suspicion level (Enable = false turns one off)
    -- Texts: locales/en.json > notification.police_alert.<type>
    Alerts                = {
        Moderate = { Enable = true, BlipName = "Unusual activity",     BlipSprite = 108, BlipColour = 5,  BlipScale = 0.9, BlipFlash = false, BlipDuration = 30 },
        High     = { Enable = true, BlipName = "Suspicious business",  BlipSprite = 108, BlipColour = 47, BlipScale = 1.0, BlipFlash = false, BlipDuration = 30 },
        Critical = { Enable = true, BlipName = "High-risk laundering", BlipSprite = 108, BlipColour = 1,  BlipScale = 1.0, BlipFlash = true,  BlipDuration = 30 },
        Max      = { Enable = true, BlipName = "Exposed laundering",   BlipSprite = 108, BlipColour = 1,  BlipScale = 1.2, BlipFlash = true,  BlipDuration = 30 },
        Deposit  = { Enable = true, BlipName = "Flagged ATM deposit",  BlipSprite = 108, BlipColour = 1,  BlipScale = 1.0, BlipFlash = true,  BlipDuration = 30 },
    },
}

-- Web portal: locale, UI colors, laptop target and auto-close range
Config.WebPortal = {
    Locale        = "en",  -- Locale file in locales/

    -- Portal UI colors
    Theme         = {
        -- Primary
        PrimaryColor       = "#1687ff",
        PrimaryHoverColor  = "#3a9aff",
        PrimaryActiveColor = "#0a6fd8",
        PrimarySubtleColor = "rgb(22 135 255 / 14%)",

        -- Surfaces
        BackgroundColor    = "#07111f",
        SurfaceColor       = "#0c1a2a",
        RaisedSurfaceColor = "#102238",
        HoverSurfaceColor  = "#142b45",

        -- Borders
        BorderColor        = "#1d3854",
        StrongBorderColor  = "#2d5579",

        -- Text
        PrimaryTextColor   = "#f3f7fb",
        SecondaryTextColor = "#bdcadb",
        MutedTextColor     = "#8295ac",

        -- Status
        SuccessColor       = "#20c985",
        SuccessSubtleColor = "rgb(32 201 133 / 14%)",
        WarningColor       = "#f2b84b",
        WarningSubtleColor = "rgb(242 184 75 / 14%)",
        DangerColor        = "#ef6262",
        DangerSubtleColor  = "rgb(239 98 98 / 14%)",
    },

    -- Target option on laptop props
    Target        = {
        icon     = "fa-solid fa-building", -- Target icon
        distance = 2.0,                    -- Target range
        models   = {                       -- Props that open the portal
            "prop_laptop_lester",
            "prop_laptop_jimmy",
            "prop_laptop_lester2",
            "prop_laptop_01a",
            "h4_prop_h4_laptop_01a",
        },
    },

    CloseDistance = 6.0,   -- Portal closes if you move this far from where you opened it
}

    -- Global stock economy - every number below applies the same way to
    -- every business type. Bigger tiers naturally need/hold more stock
    -- because their expectedRevenue is bigger, not because anything here
    -- is set per-tier.
Config.Stock = {
    LaunderDollarsPerUnit = 100, -- $ laundered per 1 unit of stock consumed
    UnitPricePercent      = 15,  -- cost to BUY 1 unit, as % of the value it represents

    maxCapacityCycles     = 3.0, -- total capacity = this many cycles' worth of consumption
    minOrderPercent       = 1,   -- smallest order = this % of total capacity
    maxOrderPercent       = 50,  -- largest single order = this % of total capacity

    -- Set false to hide the Cycle Readiness row entirely (hardcore mode -
    -- players won't be told when their stock is about to stop covering them)
    ShowCycleReadiness    = true,

    Mission = require("shared/stock_mission"), -- Stock delivery mission settings - see shared/stock_mission.lua
}

--- Bank deposit settings
-- Flow: Safe -> cash counter -> go to any ATM -> submit -> wait -> personal bank
Config.BankDeposit = {
    ProcessingTime   = 10,  -- real minutes for a submitted deposit to clear into personal bank
    MissionTimeout   = 15,  -- real minutes to reach an ATM after the cash counter finishes
    InteractDistance = 2.0, -- how close the player must be to the ATM

    -- The only guaranteed fee in the laundering pipeline - paid once, when a Safe
    -- balance converts into real bank money. Set to 0 to disable.
    Tax              = 20,

    -- ATM models the owner deposits at and police inspect
    Models           = {
        "prop_atm_01",
        "prop_atm_02",
        "prop_atm_03",
        "prop_fleeca_atm",
    },

    SubmitDuration   = 5000, -- ms the "depositing" progress bar takes at the ATM
    Animation        = { dict = "amb@prop_human_atm@male@idle_a", clip = "idle_a" },

    TargetIcon       = "fa-solid fa-credit-card",
    PoliceTargetIcon = "fa-solid fa-magnifying-glass-dollar",

    -- % chance a deposit is flagged, by business suspicion label at the moment of submit
    FlagChance       = {
        Low      = 0,
        Moderate = 15,
        High     = 50,
        Critical = 95,
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

--- Reputation system
Config.Reputation = {
    Enable            = true,
    AutosaveInterval  = 5, -- real minutes between automatic DB saves

    CommandSuggestion = "Usage: /%s <playerId> <amount>",

    Commands          = {
        set    = { enable = true, name = "moneywash:rep:set" },
        add    = { enable = true, name = "moneywash:rep:add" },
        remove = { enable = true, name = "moneywash:rep:remove" },
    },

    -- Reputation point rewards per action
    -- enable = false to stop that action awarding points
    Rewards           = {
        launder          = { enable = true, points = 10 }, -- per successful launder action
        stockDelivery    = { enable = true, points = 5 },  -- per completed stock delivery mission
        bankDeposit      = { enable = true, points = 5 },  -- when a deposit clears into personal bank
        streetWash       = { enable = true, points = 10 }, -- per completed (not betrayed) street wash
        businessPurchase = { enable = true, points = 50 }, -- per business purchase
    },

    -- Titles are purely cosmetic - the script checks points only
    Levels            = {
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
}
