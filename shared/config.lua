Config = {}

Config.Debug = true

Config.Currency = "$" -- Currency used for pricing

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