-- Revenue cycle duration in real minutes
-- One cycle = one in-game day (48 real minutes by default)
-- totalLaundered resets at the start of each new cycle
-- Suspicion, stock, safe balances and receipts persist through cycle changes
Config.Business = {

    -- Revenue cycle duration in real minutes
    -- Default: 48 (one GTA in-game day)
    CycleDuration = 48,

    -- Idle animation used by every Handler NPC regardless of tier
    HandlerScenario = "WORLD_HUMAN_STAND_IMPATIENT",

    -- Handler NPC interaction target
    HandlerTargetIcon     = "fa-solid fa-briefcase",
    HandlerTargetDistance = 2.0,

    -- Handler NPC map blip
    HandlerBlipSprite  = 375,
    HandlerBlipDisplay = 4,
    HandlerBlipScale   = 0.7,
    HandlerBlipColor   = 2,

    -- Icons shown for each option in the Handler NPC's main menu
    -- and its submenus
    MenuIcons = {
        overview    = "fa-solid fa-chart-line",
        launder     = "fa-solid fa-money-bill-wave",
        stock       = "fa-solid fa-boxes-stacked",
        viewStock   = "fa-solid fa-warehouse",
        orderStock  = "fa-solid fa-box",
        safe        = "fa-solid fa-lock",
        safeCovered = "fa-solid fa-shield-halved",
        safeExposed = "fa-solid fa-triangle-exclamation",
        bankDeposit = "fa-solid fa-building-columns",
        reviewBooks = "fa-solid fa-book",
        manage      = "fa-solid fa-gear",
        transfer    = "fa-solid fa-right-left",
        abandon     = "fa-solid fa-door-open",
    },

    -- Maximum distance (metres) between two players for a business transfer
    TransferDistance = 10.0,

    -- Global stock economy - every number below applies the same way to
    -- every business type. Bigger tiers naturally need/hold more stock
    -- because their expectedRevenue is bigger, not because anything here
    -- is set per-tier.
    Stock = {
        LaunderDollarsPerUnit = 100, -- $ laundered per 1 unit of stock consumed
        UnitPricePercent      = 15,  -- cost to BUY 1 unit, as % of the value it represents

        maxCapacityCycles = 3.0, -- total capacity = this many cycles' worth of consumption
        minOrderPercent   = 1,   -- smallest order = this % of total capacity
        maxOrderPercent   = 50,  -- largest single order = this % of total capacity
    },

    -- Stock delivery mission settings - see shared/stock_mission.lua
    StockMission = require("shared/stock_mission"),

    -- The business ladder
    -- type         : internal key, must match a key in shared/business_locations.lua
    -- label        : display name shown in menus
    -- requiredPoints: reputation points needed to unlock purchasing this tier
    -- npc          : ped model for the Handler NPC spawned after purchase
    -- expectedRevenue: maximum believable gross revenue per cycle
    --                  this is the single most important value per tier -
    --                  all stock economy values derive from it
    Tiers = {
        [1] = {
            type             = "coffee_shop",
            label            = "Coffee Shop",
            requiredPoints   = 0,
            npc              = "s_m_y_waiter_01",
            expectedRevenue  = 3000,
        },
        [2] = {
            type             = "gas_station",
            label            = "Gas Station",
            requiredPoints   = 500,
            npc              = "s_m_y_xmech_01",
            expectedRevenue  = 6000,
        },
        [3] = {
            type             = "restaurant",
            label            = "Restaurant",
            requiredPoints   = 1500,
            npc              = "s_m_y_chef_01",
            expectedRevenue  = 10000,
        },
        [4] = {
            type             = "laundromat",
            label            = "Laundromat",
            requiredPoints   = 2750,
            npc              = "s_m_o_busker_01",
            expectedRevenue  = 15000,
        },
        [5] = {
            type             = "bar",
            label            = "Bar",
            requiredPoints   = 4000,
            npc              = "s_m_y_barman_01",
            expectedRevenue  = 22000,
        },
        [6] = {
            type             = "nightclub",
            label            = "Nightclub",
            requiredPoints   = 5500,
            npc              = "s_m_y_clubbar_01",
            expectedRevenue  = 32000,
        },
        [7] = {
            type             = "stripclub",
            label            = "Strip Club",
            requiredPoints   = 7500,
            npc              = "s_m_y_doorman_01",
            expectedRevenue  = 45000,
        },
        [8] = {
            type             = "carwash",
            label            = "Car Wash",
            requiredPoints   = 10000,
            npc              = "s_m_y_winclean_01",
            expectedRevenue  = 65000,
        },
        [9] = {
            type             = "casino",
            label            = "Casino",
            requiredPoints   = 15000,
            npc              = "s_m_y_casino_01",
            expectedRevenue  = 100000,
        },
    },
}