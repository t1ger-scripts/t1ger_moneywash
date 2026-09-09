Config = {}

Config.Debug = true -- set to false in production

Config.Currency = "$" -- currency symbol used in menus and notifications

-- Jobs that cannot interact with the Accountant NPC or any business Handler NPC
Config.PoliceJobs = {"police", "sheriff"}

-- The underground Accountant NPC - fixed location, hub for all business purchases
Config.Accountant = {
    Model = "a_m_m_business_02", -- ped model
    Coords = vec4(1345.87, -1723.55, 52.11, 230.0), -- location and heading
    Scenario = "WORLD_HUMAN_STAND_MOBILE", -- idle animation
    Blip = {
        enable = true, -- show blip on map
        name = "???", -- blip label
        sprite = 280, -- blip icon
        display = 4, -- blip display type
        color = 1, -- blip color
        scale = 0.8, -- blip scale
    },
    TargetIcon = "fa-solid fa-money-bill-transfer", -- ox_target icon
    TargetLabel = "Talk", -- ox_target label
}

-- Reputation system
Config.Reputation = {
    Enable = true, -- set to false to disable entirely

    AutosaveInterval = 5, -- real minutes between automatic DB saves

    Commands = {
        set    = {enable = true, name = "moneywash:rep:set"}, -- set player reputation to exact value
        add    = {enable = true, name = "moneywash:rep:add"}, -- add reputation points to player
        remove = {enable = true, name = "moneywash:rep:remove"}, -- remove reputation points from player
    },

    -- Reputation titles, keyed by minimum points required
    -- The script checks points only - titles are purely cosmetic
    Levels = {
        [0]     = "Novice",
        [250]   = "Street Runner",
        [500]   = "Cash Handler",
        [1000]  = "Fixer's Associate",
        [1750]  = "Front Runner",
        [2750]  = "Money Man",
        [4000]  = "Launderer",
        [5500]  = "Silent Partner",
        [7500]  = "Cartel Accountant",
        [10000] = "Underworld Broker",
        [15000] = "Kingpin",
    },

    -- Colors shown on the reputation progress bar in menus
    ProgressColors = {
        {threshold = 0,   color = "#dc2626"}, -- Red
        {threshold = 20,  color = "#f97316"}, -- Orange
        {threshold = 40,  color = "#facc15"}, -- Yellow
        {threshold = 60,  color = "#84cc16"}, -- Lime
        {threshold = 80,  color = "#22c55e"}, -- Green
        {threshold = 100, color = "#16a34a"}, -- Deep Green
    },
}