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
    ShowExactValue = true,

    -- Warn the owner when a launder pushes the business into a higher label
    -- (e.g. Low -> Moderate). Downward changes from decay never notify.
    NotifyOnLabelChange = true,

    -- -------------------------------------------------------------------------
    -- POLICE NOTIFICATION
    -- One hidden roll per launder action using resulting suspicion label.
    -- Player is never informed of the outcome.
    -- Max applies only when suspicion has reached 100 (guaranteed by default).
    -- -------------------------------------------------------------------------
    NotificationChance = {
        Low      = 0,  -- no roll at Low suspicion
        Moderate = 10, -- % chance police are notified
        High     = 35,
        Critical = 75,
        Max      = 100, -- suspicion at 100
    },

    -- -------------------------------------------------------------------------
    -- DECAY
    -- Constant decay, always running. Whatever a business launders per cycle
    -- that gains less than this is effectively "safe" long-term.
    -- With full stock, safe rate ~= sqrt(decay / 25) of the cycle allowance.
    -- -------------------------------------------------------------------------
    Decay = {
        OnlinePointsPerCycle  = 5, -- suspicion removed per cycle while owner is online
        OfflinePointsPerCycle = 2, -- suspicion removed per cycle while owner is offline
    },
}