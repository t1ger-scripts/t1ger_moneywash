Config.Suspicion = {

    -- -------------------------------------------------------------------------
    -- FORMULA CONFIGURATION
    -- Server owners configure behaviour through plain options.
    -- The script derives all raw formula values internally.
    -- -------------------------------------------------------------------------

    -- How many cycles of laundering a FULL allowance (expectedRevenue) with
    -- full stock it takes to reach Critical (75), ignoring decay.
    -- Gain per such cycle = 75 / this value (15 -> 5 points per cycle).
    -- Higher = more forgiving.
    CyclesUntilCritical = 15,

    -- How much full stock coverage reduces that gain, in percent.
    -- Higher = stock is more important. 80 means a fully stocked launder
    -- builds only 20% of the suspicion an unstocked one does (before the penalty).
    -- Keep below 100.
    FullStockReduction = 80,

    -- How much a business with NO stock at all gains extra, in percent.
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