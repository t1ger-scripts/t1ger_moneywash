Config = {}

Config.Debug = true

Config.Currency = "$" -- Currency used for pricing

--- Defines how "dirty" (unlaundered) money is represented on your server.
--- Mirrors the same pattern used in t1ger_atmrobbery's Config.RewardDefaults.cash,
--- so servers using an account-based dirty money (e.g. 'black_money') or an item
--- (stacked or metadata-based, e.g. 'markedbills') both work without touching any logic.
Config.DirtyMoney = {
    useItem = true, -- set to false to use an account-based balance instead of an item
    account = "black_money", -- account type used when useItem = false (e.g. 'black_money', 'crypto')

    item = {
        name = "markedbills", -- name of your dirty cash item ('markedbills' is default in qbcore)
        metadata = false, -- set to true if your item requires metadata when given (e.g. qbcore markedbills)
        metadataTemplate = function(amount) -- customize what metadata looks like when dirty money is added
            return {worth = amount}
        end,
    }
}

-- Define your police jobs in here. Players with these jobs cannot interact with the Accountant NPC at all.
Config.PoliceJobs = {"police", "sheriff"}

Config.Accountant = { -- The main underground Accountant NPC (fixed location, hub for the entire operation)
    Model = "a_m_m_business_02", -- model of the accountant npc
    Coords = vec4(1345.87, -1723.55, 52.11, 230.0), -- coords for the npc
    Scenario = "WORLD_HUMAN_STAND_MOBILE", -- scenario to play
    Blip = {enable = true, name = "???", sprite = 280, display = 4, color = 1, scale = 0.8}, -- blip settings
    TargetIcon = "fa-solid fa-money-bill-transfer", -- icon shown when targeting the npc
}

--- Reputation system
Config.Reputation = {
    Enable = true, -- set to false to disable reputation system entirely
    MenuIcon = "fa-star", -- icon in the Accountant NPC menu
    AutosaveInterval = 5, -- auto save all reputation data for players every x minutes

    Commands = { -- commands to set, add and remove reputation points
        set = {enable = true, name = "moneywashrep:set"}, -- enable for admins? False only useable by server-console
        add = {enable = true, name = "moneywashrep:add"}, -- enable for admins? False only useable by server-console
        remove = {enable = true, name = "moneywashrep:remove"}, -- enable for admins? False only useable by server-console
    },
    CommandSuggestion = "Usage: /%s <playerId> <amount>", -- command suggestion/helper. %s is automatically calling `set`, `add` or `remove`

    Levels = { -- the script ONLY checks for reputation points. All the rank/titles are fictional
        [0] = "Novice",
        [250] = "Street Runner",
        [500] = "Cash Handler",
        [1000] = "Fixer's Associate",
        [1750] = "Front Runner",
        [2750] = "Money Man",
        [4000] = "Launderer",
        [5500] = "Silent Partner",
        [7500] = "Cartel Accountant",
        [10000] = "Underworld Broker",
        [15000] = "Kingpin",
        -- add or remove ranks as you like
    },

    ProgressColors = { -- Set up colors for progression in reputation menu option
        { threshold = 0, color = "#dc2626" },   -- Red
        { threshold = 20, color = "#f97316" },  -- Orange
        { threshold = 40, color = "#facc15" },  -- Yellow
        { threshold = 60, color = "#84cc16" },  -- Lime
        { threshold = 80, color = "#22c55e" },  -- Bright Green
        { threshold = 100, color = "#16a34a" }, -- Deep Green
    }
}

--- Runner Exchange: a fast, on-demand cash-for-clean-money exchange offered by the Accountant.
--- No ownership, no queue - just an instant trade of speed for a worse rate than any owned business.
Config.RunnerExchange = {
    Enable = true,
    MenuIcon = "fa-bolt", -- icon in accountant menu

    AmountLimits = {min = 500, max = 5000}, -- base min/max dirty cash per exchange

    TrustLimits = { -- reputation-gated increases to the max amount allowed per exchange
        [0] = 5000,
        [1000] = 7500,
        [2750] = 10000,
        [5500] = 15000,
        [10000] = 25000,
    },

    Commission = 30, -- flat % cut taken by the runner, regardless of reputation

    RequiredPolice = {enable = true, minimum = 1}, -- minimum on-duty police required to use this option

    Cooldown = {enable = true, duration = 4}, -- minutes, applies after ANY outcome (success/hustle/expire/cancel)

    Timer = {enable = true, duration = 180}, -- seconds to reach the runner before the exchange expires

    CancelPenalty = {enable = true, reputationLoss = 10}, -- reputation points lost if player manually cancels

    ReputationReward = 5, -- points earned per successful exchange

    RunnerLocations = require("shared/runnerlocations"), -- pool of possible runner spawn points

    RunnerModels = { -- pool of ped models, randomized per spawn
        "g_m_y_ballaeast_01",
        "g_m_y_lost_01",
        "a_m_y_hipster_01",
    },

    Hustle = {
        chance = 15, -- % chance runner tries to rob instead of paying
        weapons = { -- random weapon picked from this table when a hustle triggers
            "WEAPON_BAT",
            "WEAPON_KNIFE",
            "WEAPON_PISTOL",
            "WEAPON_SWITCHBLADE",
        },
    },
}