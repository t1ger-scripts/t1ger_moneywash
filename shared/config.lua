Config = {}

Config.Debug = true -- set to false in production

Config.Currency = "$" -- currency symbol used in menus and notifications

--- Defines how dirty (unlaundered) money is represented on your server.
--- Supports account-based dirty money (e.g. black_money) or item-based
--- (stacked or metadata, e.g. markedbills). No logic files need changing.
Config.DirtyMoney = {
    useItem = true, -- false = use an account balance instead of an item
    account = "black_money", -- account type when useItem = false

    item = {
        name = "markedbills", -- dirty cash item name
        metadata = false, -- true if item uses metadata (e.g. qbcore markedbills)
        metadataTemplate = function(amount)
            return {worth = amount}
        end,
    },
}

--- Police interaction settings
Config.Police = {
    Jobs                  = {"police", "sheriff"}, -- jobs that can access police interactions
    RaidMinGrade          = 0, -- minimum grade required to raid a business
    DepositReviewMinGrade = 2, -- minimum grade required to review flagged bank deposits
}

--- The underground Accountant NPC - fixed location, sole purchase point for all businesses
Config.Accountant = {
    Model    = "a_m_m_business_01",
    Coords   = vec4(1360.285767, -1746.276978, 64.074707, 337.322845),
    Scenario = "WORLD_HUMAN_STAND_MOBILE",
    Blip = {
        enable  = true,
        name    = "???",
        sprite  = 280,
        display = 4,
        color   = 1,
        scale   = 0.8,
    },
    TargetIcon  = "fa-solid fa-money-bill-transfer",
    TargetLabel = "Talk",
}

--- Bank deposit settings
Config.BankDeposit = {
    ProcessingTime  = 10, -- real minutes for a deposit to clear into personal bank
    PoliceKeepMoney = true, -- true = confiscated funds go to police job account, false = vanish

    -- % chance a deposit is flagged based on business suspicion label at moment of teller interaction
    FlagChance = {
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

    Commands = {
        set    = {enable = true, name = "moneywash:rep:set"},
        add    = {enable = true, name = "moneywash:rep:add"},
        remove = {enable = true, name = "moneywash:rep:remove"},
    },

    -- Reputation point rewards per action
    -- enable = false to stop that action awarding points
    Rewards = {
        launder          = {enable = true, points = 10}, -- per successful launder action
        stockDelivery    = {enable = true, points = 5},  -- per completed stock delivery mission
        bankDeposit      = {enable = true, points = 5},  -- when a deposit clears into personal bank
        accountantReview = {enable = true, points = 15}, -- per completed records review
        businessPurchase = {enable = true, points = 50}, -- once per business type, first purchase only
    },

    -- Titles are purely cosmetic - the script checks points only
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

    ProgressColors = {
        {threshold = 0,   color = "#dc2626"},
        {threshold = 20,  color = "#f97316"},
        {threshold = 40,  color = "#facc15"},
        {threshold = 60,  color = "#84cc16"},
        {threshold = 80,  color = "#22c55e"},
        {threshold = 100, color = "#16a34a"},
    },
}