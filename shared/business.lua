-- Revenue cycle duration in real minutes
-- One cycle = one in-game day (48 real minutes by default)
-- totalLaundered resets at the start of each new cycle
-- Suspicion, stock, safe balances and receipts persist through cycle changes
Config.Business = {

    -- Revenue cycle duration in real minutes
    -- Default: 48 (one GTA in-game day)
    CycleDuration = 48,

    -- Maximum total portfolio weight a single player can own across all businesses
    -- Casino alone (weight 6) maxes this out entirely
    PortfolioLimit = 6,

    -- Idle animation used by every Handler NPC regardless of tier
    HandlerScenario = "WORLD_HUMAN_STAND_IMPATIENT",

    -- Flat % tax deducted when a bank deposit clears into the player's personal bank
    -- Set to 0 to disable
    WithdrawalTax = 15,

    -- Global stock economy ratios - all stock values are derived from expectedRevenue
    -- using these ratios so server owners only need to set expectedRevenue per tier
    Stock = {
        costRatio        = 0.10, -- unit price = expectedRevenue * costRatio
        consumptionRatio = 0.01, -- stock consumed per $ laundered = expectedRevenue * consumptionRatio
        minOrderRatio    = 0.05, -- minimum units per order = expectedRevenue * minOrderRatio
        maxOrderRatio    = 0.50, -- maximum units per order = expectedRevenue * maxOrderRatio
    },

    -- The business ladder
    -- type         : internal key, must match a key in shared/business_locations.lua
    -- label        : display name shown in menus
    -- weight       : portfolio cost (total owned weight cannot exceed PortfolioLimit)
    -- requiredPoints: reputation points needed to unlock purchasing this tier
    -- price        : base purchase price in clean money from personal bank
    --                individual locations in business_locations.lua can override this
    -- npc          : ped model for the Handler NPC spawned after purchase
    -- expectedRevenue: maximum believable gross revenue per cycle
    --                  this is the single most important value per tier -
    --                  all stock economy values derive from it
    -- launderFee   : % of the laundered amount taken as a fee (remainder becomes clean money in Safe)
    Tiers = {
        [1] = {
            type             = "coffee_shop",
            label            = "Coffee Shop",
            weight           = 1,
            requiredPoints   = 0,
            price            = 15000,
            npc              = "s_m_y_waiter_01",
            expectedRevenue  = 3000,
            launderFee       = 25, -- % fee deducted from laundered amount
        },
        [2] = {
            type             = "gas_station",
            label            = "Gas Station",
            weight           = 1,
            requiredPoints   = 500,
            price            = 25000,
            npc              = "s_m_y_xmech_02",
            expectedRevenue  = 6000,
            launderFee       = 23,
        },
        [3] = {
            type             = "restaurant",
            label            = "Restaurant",
            weight           = 2,
            requiredPoints   = 1500,
            price            = 40000,
            npc              = "s_m_y_chef_01",
            expectedRevenue  = 10000,
            launderFee       = 22,
        },
        [4] = {
            type             = "laundromat",
            label            = "Laundromat",
            weight           = 2,
            requiredPoints   = 2750,
            price            = 55000,
            npc              = "s_m_o_busker_01",
            expectedRevenue  = 15000,
            launderFee       = 21,
        },
        [5] = {
            type             = "bar",
            label            = "Bar",
            weight           = 3,
            requiredPoints   = 4000,
            price            = 75000,
            npc              = "s_m_y_barman_01",
            expectedRevenue  = 22000,
            launderFee       = 20,
        },
        [6] = {
            type             = "nightclub",
            label            = "Nightclub",
            weight           = 3,
            requiredPoints   = 5500,
            price            = 100000,
            npc              = "s_m_y_clubbar_01",
            expectedRevenue  = 32000,
            launderFee       = 19,
        },
        [7] = {
            type             = "stripclub",
            label            = "Strip Club",
            weight           = 3,
            requiredPoints   = 7500,
            price            = 150000,
            npc              = "s_m_y_doorman_01",
            expectedRevenue  = 45000,
            launderFee       = 18,
        },
        [8] = {
            type             = "carwash",
            label            = "Car Wash",
            weight           = 5,
            requiredPoints   = 10000,
            price            = 250000,
            npc              = "s_m_y_winclean_01",
            expectedRevenue  = 65000,
            launderFee       = 17,
        },
        [9] = {
            type             = "casino",
            label            = "Casino",
            weight           = 6,
            requiredPoints   = 15000,
            price            = 750000,
            npc              = "s_m_y_casino_01",
            expectedRevenue  = 100000,
            launderFee       = 15,
        },
    },
}