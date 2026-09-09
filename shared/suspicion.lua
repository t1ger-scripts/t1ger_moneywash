Config.Suspicion = {

    -- -------------------------------------------------------------------------
    -- FORMULA CONFIGURATION
    -- Server owners configure behaviour through plain options.
    -- The script derives all raw formula values internally.
    -- -------------------------------------------------------------------------

    -- How many full expectedRevenue launder actions with full stock
    -- before reaching Critical suspicion (75).
    -- Lower = riskier, Higher = more forgiving
    CyclesUntilCritical = 3,

    -- Percentage suspicion reduction when business has full stock coverage
    FullStockReduction = 50,

    -- Percentage suspicion increase when business has no stock at all
    NoStockPenalty = 50,

    -- -------------------------------------------------------------------------
    -- LABELS
    -- -------------------------------------------------------------------------
    Labels = {
        {threshold = 0,  name = "Low",      color = "#22c55e"},
        {threshold = 25, name = "Moderate",  color = "#facc15"},
        {threshold = 50, name = "High",      color = "#f97316"},
        {threshold = 75, name = "Critical",  color = "#dc2626"},
    },

    -- Show exact suspicion value instead of label
    -- Default: false (label only)
    ShowExactValue = false,

    -- -------------------------------------------------------------------------
    -- POLICE NOTIFICATION
    -- One hidden roll per launder action using resulting suspicion label.
    -- Player is never informed of the outcome.
    -- -------------------------------------------------------------------------
    NotificationChance = {
        Low      = 0,  -- no roll at Low suspicion
        Moderate = 10, -- % chance police are notified
        High     = 35,
        Critical = 75,
    },

    -- -------------------------------------------------------------------------
    -- DECAY
    -- Decay begins after one full cycle of inactivity (no launder actions).
    -- Any launder action restarts the inactivity clock.
    -- Stock orders and bank deposits do not count as activity.
    -- -------------------------------------------------------------------------
    Decay = {
        InactivityPeriod     = 1,  -- full cycles of inactivity before decay begins
        OnlinePointsPerCycle = 15, -- suspicion removed per cycle while owner is online
        OfflinePointsPerCycle = 5, -- suspicion removed per cycle while owner is offline
    },

    -- -------------------------------------------------------------------------
    -- RAIDS
    -- -------------------------------------------------------------------------

    -- Suspicion value after a raid resolves
    -- Not zero (would allow raids as a free reset)
    -- Not 100 (would trap business in permanent raid cycle)
    PostRaidReset = 50,

    -- Real minutes between suspicion crossing 100 and police dispatch firing
    -- Gives an attentive owner a reaction window
    RaidDelay = 3,

    -- Raid history escalation - tracked per location regardless of ownership changes
    RaidHistory = {
        WindowDays           = 14, -- rolling window in real days
        TempCloseAfterRaids  = 3,  -- raids within window before temporary closure
        TempCloseDuration    = 24, -- real hours the business stays closed
        SeizeAfterRaids      = 5,  -- raids within window before permanent seizure
    },

    -- -------------------------------------------------------------------------
    -- ACCOUNTANT RECORDS REVIEW
    -- The only active suspicion reduction method currently available.
    -- Once per revenue cycle per business.
    -- -------------------------------------------------------------------------
    AccountantReview = {
        MinReduction  = 5,  -- minimum suspicion points removed per review
        MaxReduction  = 30, -- maximum suspicion points removed per review
        Cooldown      = 1,  -- revenue cycles before review can be used again

        -- Police notification chance during review (lower than launder actions
        -- since this is a legitimate business activity)
        NotificationChance = {
            Low      = 0,
            Moderate = 5,
            High     = 20,
            Critical = 50,
        },
    },
}