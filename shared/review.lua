-- ============================================================================
-- ACCOUNTANT REVIEW ("Review Books")
-- Owners hand stock-delivery receipts to an accountant to lower suspicion.
--
-- One "cycle of paperwork" = receipts covering the business's expectedRevenue
-- (units x LaunderDollarsPerUnit). Every tier gets the same deal in proportion.
-- ============================================================================

Config.Review = {
    Enable               = true,

    -- -------------------------------------------------------------------------
    -- REDUCTION
    -- -------------------------------------------------------------------------
    MaxReduction         = 15,  -- most suspicion one review can remove
    CyclesForMax         = 5,   -- cycles of paperwork needed to reach MaxReduction
    MinReduction         = 3,   -- a review must remove at least this much to be allowed
    FeePercent           = 20,  -- fee, as % of the business's expectedRevenue (same however many receipts)
    SkillImpact          = 30,  -- how much sloppy paperwork can cut the result, in % (0 = skill off)
    MaxReceiptsPerReview = 12,  -- most receipts in one folder

    -- -------------------------------------------------------------------------
    -- TIMING (real minutes)
    -- -------------------------------------------------------------------------
    Cooldown             = 60,  -- between completed reviews of the same business (resets on restart)
    PrepareTimeout       = 15,  -- an opened desk is discarded if the folder isn't sealed in this time
    MaxTime              = 20,  -- time to deliver the sealed folder to the accountant

    -- -------------------------------------------------------------------------
    -- ACCOUNTANT
    -- The office nearest to the player is used when the delivery starts. Add as many as you like.
    -- -------------------------------------------------------------------------
    Accountant           = {
        Model          = "a_m_m_business_01",
        Scenario       = "WORLD_HUMAN_CLIPBOARD",
        SpawnDistance  = 50.0,                         -- the ped exists only while a delivery player is this close
        TargetIcon     = "fa-solid fa-folder-open",
        TargetDistance = 2.0,

        Locations      = {
            -- EXAMPLE ONLY: replace with your own office coordinates
            vector4(-118.37, -607.95, 36.28, 252.0),
        },

        -- Map blip shown at the chosen office during the delivery
        Blip           = { Sprite = 1, Display = 4, Scale = 0.8, Color = 3, Route = true, RouteColor = 3, Label = "Accountant" },
    },

    -- -------------------------------------------------------------------------
    -- FOLDER (carried to the accountant, hidden while in a vehicle)
    -- Starting values: tune pos/rot in-game.
    -- -------------------------------------------------------------------------
    Folder               = {
        Prop      = { model = "prop_cs_folder_01", pos = { x = 0.1, y = 0.0, z = 0.0 }, rot = { x = 0.0, y = 0.0, z = 0.0 }, bone = 36029 },
        Animation = { dict = "amb@world_human_clipboard@male@idle_a", name = "idle_a", blendIn = 4.0, blendOut = 1.0, duration = -1, flag = 49 },
    },
}