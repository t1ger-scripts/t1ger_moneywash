Config = {}

-- General settings
Config.Debug             = true  -- Debug prints (set to false in production)
Config.Currency          = "$"   -- Currency symbol in menus and notifications
Config.UseCharacterNames = true  -- true = character name, false = game name (e.g. transfer picker)
Config.AutosaveInterval  = 5     -- Minutes between automatic saves of businesses and reputation

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

Config.Contracts = require("shared/contracts") -- Launder contracts (shared/contracts.lua)

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
        cancelOrder    = "fa-solid fa-ban",
        reviewBooks    = "fa-solid fa-folder-open",
        safe           = "fa-solid fa-lock",
        safeCovered    = "fa-solid fa-shield-halved",
        safeExposed    = "fa-solid fa-triangle-exclamation",
        withdraw       = "fa-solid fa-building-columns",
        manage         = "fa-solid fa-gear",
        transfer       = "fa-solid fa-right-left",
        abandon        = "fa-solid fa-door-open",
    }
}

-- Handler and accountant peds say a line when you interact (GTA ambient speech, played by the ped's own voice)
-- A model without that line stays silent. Set a line to "" to turn only that one off
Config.PedReactions = {
    Enable           = true,
    HandlerGreeting  = "GENERIC_HOWS_IT_GOING",     -- Owner opens the Handler menu
    AccountantThanks = "GENERIC_THANKS", -- The folder is delivered
}

-- Web portal: UI colors, laptop target and auto-close range
Config.WebPortal = {
    -- Target option on laptop props
    Target        = {
        icon     = "fa-solid fa-globe", -- Target icon
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
        DangerColor        = "#ef6262",
    },
}

-- Stock economy: applies equally to every business type
-- Bigger tiers need and hold more stock because their expectedRevenue is higher, not because of per-tier values
Config.Stock = {
    LaunderDollarsPerUnit = 100, -- $ laundered per unit of stock consumed
    UnitPricePercent      = 15,  -- Price to buy 1 unit, as % of the value it represents (15 = $15 at 100 per unit)

    MaxCapacityCycles     = 3.0, -- Max stock capacity, in cycles' worth of consumption
    MinOrderPercent       = 1,   -- Smallest order, as % of max capacity
    MaxOrderPercent       = 50,  -- Largest single order, as % of max capacity

    ShowCycleReadiness    = true, -- false = hide the Cycle Readiness row (players aren't warned when stock stops covering them)

    Mission               = require("shared/delivery"), -- Delivery mission settings (shared/delivery.lua)
}

-- Suspicion: how fast it builds, how it's labelled and how it decays
Config.Suspicion = {
    -- Cycles of laundering a full allowance (expectedRevenue) with full stock needs to reach Critical (75), ignoring decay
    -- Gain per such cycle = 75 / this value (15 = 5 points per cycle). Higher = more forgiving
    CyclesUntilCritical = 15,

    -- % that full stock coverage reduces the gain (keep below 100)
    -- 80 = a fully stocked launder builds only 20% of an unstocked one's suspicion, before the penalty
    FullStockReduction  = 80,

    -- % extra suspicion gained by a business with no stock at all
    NoStockPenalty      = 50,

    -- Suspicion labels, from the threshold upwards
    Labels              = {
        { threshold = 0,  name = "Low",      color = "#22c55e" },
        { threshold = 25, name = "Moderate", color = "#facc15" },
        { threshold = 50, name = "High",     color = "#f97316" },
        { threshold = 75, name = "Critical", color = "#dc2626" },
    },

    ShowExactValue      = true, -- true = show the exact value, false = label only
    NotifyOnLabelChange = true, -- Warn the owner when a launder raises the label (decay never notifies)

    -- Hidden police roll per launder, using the resulting label. The player never sees the outcome
    NotificationChance  = {
        Low      = 0,   -- % chance police are notified (0 = no roll)
        Moderate = 10,
        High     = 35,
        Critical = 75,
        Max      = 100, -- Only at suspicion 100
    },

    -- Constant decay, always running. A business gaining less than this per cycle is safe long-term
    -- With full stock, the safe rate is about sqrt(decay / 25) of the cycle allowance
    Decay               = {
        OnlinePointsPerCycle  = 5, -- Suspicion removed per cycle while the owner is online
        OfflinePointsPerCycle = 2, -- Suspicion removed per cycle while the owner is offline
    },
}

-- Laundering: dirty cash -> cash counter -> Safe
Config.Laundering = {
    MaxPerBatch = 10000000, -- Most dirty cash that can be laundered in one go

    CashCounter = {         -- Cash counter shown when laundering
        StackCount      = 3,    -- Piles the amount is split into (1-10)
        AutoMoveToRight = false, -- true = a counted pile moves to the right tray automatically
    },
}

-- Withdraw: Safe -> cash counter -> cash bag
Config.Withdraw = {
    Item             = "t1ger_cashbag", -- Item the owner receives (see the README for the item definition)
    LimitOutstanding = true, -- true = a business can have at most its expectedRevenue out in uncashed bags (false = no limit)
    OutstandingHours = 24,   -- Bags older than this no longer count towards that limit (lost or thrown away bags)

    CashCounter      = {     -- Cash counter shown when withdrawing from the Safe
        StackCount      = 3,    -- Piles the amount is split into (1-10)
        AutoMoveToRight = false, -- true = a counted pile moves to the right tray automatically
    },
}

-- Deposit: cash bag -> ATM -> wait -> personal bank
Config.Deposit = {
    MinPolice      = 0,    -- On-duty police needed to start a deposit (0 = off)
    MaxActive      = 1,    -- Deposits one player can have processing at the same time
    ProcessingTime = 10,   -- Minutes before a deposit clears into the personal bank
    Tax            = 20,   -- % taken from a bag when it is paid into the bank (0 = off)
    SubmitDuration = 5000, -- Ms of the depositing progress bar
    Target         = { icon = "fa-solid fa-credit-card", distance = 2.0 }, -- ATM target icon and range
    Animation      = { dict = "amb@prop_human_atm@male@idle_a", clip = "idle_a" }, -- Played at the ATM

    Models         = {     -- ATM models used for deposits and police inspection
        "prop_atm_01",
        "prop_atm_02",
        "prop_atm_03",
        "prop_fleeca_atm",
    },
}

-- Review books: owners hand stock-delivery receipts to an accountant to lower suspicion
-- One "cycle of paperwork" = receipts covering the business's expectedRevenue (units x LaunderDollarsPerUnit)
Config.Review = {
    Enable               = true,

    MaxReduction         = 15,  -- Most suspicion one review can remove
    CyclesForMax         = 5,   -- Cycles of paperwork needed to reach MaxReduction
    MinReduction         = 3,   -- Min suspicion a review must remove to be allowed
    FeePercent           = 20,  -- Fee as % of the business's expectedRevenue (same for any receipt count)
    SkillImpact          = 30,  -- % sloppy paperwork can cut the result (0 = skill off)
    MaxReceiptsPerReview = 12,  -- Max receipts in one folder

    Cooldown             = 60,  -- Minutes between completed reviews of the same business (resets on restart)
    PrepareTimeout       = 15,  -- Minutes before an opened desk is discarded if the folder isn't sealed
    MaxTime              = 20,  -- Minutes to deliver the sealed folder
    CancelPenaltyPercent = 25,  -- % of the fee lost when the player drops the sealed folder

    -- Accountant ped where the folder is delivered
    Accountant           = {
        Model          = "s_f_m_shop_high",
        Scenario       = "WORLD_HUMAN_CLIPBOARD",
        SpawnDistance  = 50.0,                 -- Ped spawns when any player is this close
        TargetIcon     = "fa-solid fa-folder-open",
        TargetDistance = 2.0,
        Location       = vector4(-555.362610, -227.050537, 38.159668, 218.267715),
        Blip           = { Sprite = 1, Display = 4, Scale = 0.8, Color = 3, Route = true, RouteColor = 3, Label = "Accountant" }, -- Shown during delivery
    },

    -- Folder carried to the accountant (hidden in vehicles), tune pos/rot in-game
    Folder               = {
        Prop      = { model = "prop_cs_documents_01", pos = { x = 0.10, y = 0.03, z = 0.07 }, rot = { x = 35.0, y = 130.0, z = 0.0 }, bone = 36029 },
        Animation = { dict = "amb@world_human_clipboard@male@idle_a", name = "idle_a", blendIn = 4.0, blendOut = 1.0, duration = -1, flag = 49 },
    },
}

-- Reputation: points, admin commands, rewards and titles
Config.Reputation = {
    Enable            = true,

    CommandSuggestion = "Usage: /%s <playerId> <amount>", -- Command help text (%s = command name)

    -- Admin commands (enable = false turns one off)
    Commands          = {
        set    = { enable = true, name = "moneywash:rep:set" },
        add    = { enable = true, name = "moneywash:rep:add" },
        remove = { enable = true, name = "moneywash:rep:remove" },
    },

    -- Points per action (enable = false stops that action awarding points)
    Rewards           = {
        businessPurchase = { enable = true, points = 50 }, -- Per business purchase
        stockDelivery    = { enable = true, points = 5 },  -- Per completed stock delivery
        launder          = { enable = true, points = 10 }, -- Per successful launder
        cashBagDeposit   = { enable = true, points = 5 },  -- When a cash bag deposit clears into the bank
        accountantReview = { enable = true, points = 5 }, -- Per completed review delivery
    },

    -- Titles by points, cosmetic only (the script checks points)
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

-- Police: access, business raids and alert blips
Config.Police = {
    Jobs                  = { "police", "sheriff" }, -- Jobs with police access
    AlertNotifyDuration   = 10000,                   -- Alert notification time in ms

    -- Raid a business via the handler ped
    Raid                  = {
        Enable         = true,
        MinGrade       = 1,                                                      -- Min grade to raid
        RequireDuty    = true,                                                   -- true = officers must be on duty to raid
        Target         = { icon = "fa-solid fa-shield-halved", distance = 2.0 }, -- Target icon and range
        StackCount     = 10,                                                     -- Cash piles in the safe (1-20)
        MaxTime        = 5,                                                      -- Minutes until an unfinished raid is cancelled
        Cooldown       = 60,                                                     -- Minutes before the same business can be raided again (resets on restart)
        Margin         = 6.0,                                                    -- Extra distance (on top of the target range) the officer may move away before the raid is cancelled

        -- Suspicion after a raid (never raises it)
        -- "set": drops to Value if higher | "reduce": lowers by Value % of current
        SuspicionAfter = { Mode = "set", Value = 50 },
    },

    -- Inspect flagged deposits at an ATM
    ATM                   = {
        MinGrade = 2,                                                                   -- Min grade to inspect and confiscate
        RequireDuty = true,                                                             -- true = officers must be on duty to inspect and confiscate
        InspectDuration = 4000,                                                         -- Ms of the progress bar when pulling the transaction log
        SeizeDuration   = 3000,                                                         -- Ms of the progress bar when seizing a transfer
        Animation       = { dict = "amb@prop_human_atm@male@idle_a", clip = "idle_a" }, -- Played at the ATM
        Target   = { icon = "fa-solid fa-magnifying-glass-dollar", distance = 2.0 },    -- Target icon and range
    },

    -- Alerts by suspicion label, plus flagged and stolen-bag ATM deposits (Enable = false turns one off)
    -- Blip: BlipDuration is in seconds, BlipFlash makes it flash
    -- Texts: locales/en.json > notification.police_alert.<type>
    Alerts                = {
        Moderate = { Enable = true, BlipName = "Unusual activity",     BlipSprite = 108, BlipColour = 5,  BlipScale = 0.9, BlipFlash = false, BlipDuration = 30 },
        High     = { Enable = true, BlipName = "Suspicious business",  BlipSprite = 108, BlipColour = 47, BlipScale = 1.0, BlipFlash = false, BlipDuration = 30 },
        Critical = { Enable = true, BlipName = "High-risk laundering", BlipSprite = 108, BlipColour = 1,  BlipScale = 1.0, BlipFlash = true,  BlipDuration = 30 },
        Max      = { Enable = true, BlipName = "Exposed laundering",   BlipSprite = 108, BlipColour = 1,  BlipScale = 1.2, BlipFlash = true,  BlipDuration = 30 },
        Deposit  = { Enable = true, BlipName = "Flagged ATM deposit",  BlipSprite = 108, BlipColour = 1,  BlipScale = 1.0, BlipFlash = true,  BlipDuration = 30 },
        StolenDeposit = { Enable = true, BlipName = "Stolen cash deposit", BlipSprite = 108, BlipColour = 1, BlipScale = 1.0, BlipFlash = true, BlipDuration = 30 },
    },
}