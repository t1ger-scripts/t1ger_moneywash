-- ============================================================================
-- STOCK DELIVERY MISSION SETTINGS
-- Required directly from shared/business.lua as Config.Business.StockMission.
-- ============================================================================

return {
    CancelCommand        = "cancelstock", -- chat command to voluntarily cancel an active mission
    CancelPenaltyPercent = 10,            -- % of the paid cost forfeited on manual cancel
    CancelCooldown       = 300,           -- seconds before a new order can be placed after a cancel (gates re-rolling)

    PickupDistance    = 25.0, -- how close the player must be before the pickup box spawns
    PickupTargetDistance = 2.0,  -- interaction distance for targeting the box/vehicle

    -- Pickup box prop, attached to the player's hand during transport
    PickupObject = {
        model = "prop_cs_cardbox_01",
        pos   = { x = 0.0,   y = -0.2, z = -0.1 },
        rot   = { x = 135.0, y = 0.0,  z = 0.0  },
        bone  = 28422, -- attach bone index
    },

    -- Map blip shown at the pickup location until the player arrives
    PickupBlip = {
        Sprite     = 1,
        Display    = 4,
        Scale      = 0.8,
        Color      = 5,
        Route      = true, -- draw a GPS route line to the blip
        RouteColor = 5,
        Label = "Stock Pickup"
    },

    -- Cargo damage from vehicle collisions during transport
    CollisionDamage = {
        Enable              = true, -- set false to disable cargo damage entirely
        MinDeductionPercent = 5,     -- minimum % of current stock lost per confirmed collision
        MaxDeductionPercent = 15,    -- maximum % of current stock lost per confirmed collision
        PingCooldown        = 3000,  -- ms between accepted collision reports per shipment
        MinImpactSpeed      = 5.0,   -- client-side filter: vehicle speed (m/s) required to report a hit
    },

    -- Randomly selected for every stock order, regardless of business type.
    -- Add as many locations as you like.
    PickupLocations = {
        vector4(845.432983, -3205.714355, 6.010254, 175.748032),
        vector4(1245.085693, -3201.362549, 6.027100, 280.629913),
        vector4(647.024170, -3013.740723, 6.229248, 0.000000),
        vector4(267.349457, -3256.945068, 5.774414, 274.960632),
        vector4(116.386810, -2978.162598, 6.010254, 90.708656),
        vector4(32.057144, -2638.826416, 6.027100, 181.417328),
        vector4(-250.734070, -2598.936279, 5.993408, 175.748032),
        vector4(-515.854919, -2911.292236, 5.993408, 110.551186),
        vector4(-453.824158, -2275.529785, 7.594116, 266.456696),
        vector4(-677.367004, -2459.723145, 13.929688, 121.889763),
        vector4(830.940674, -1984.035156, 29.296753, 5.669291),
        vector4(502.404388, -654.197815, 24.747314, 272.125977),
        vector4(2477.485840, 4122.843750, 38.008057, 28.346457), -- sandy shores
        vector4(2564.347168, 4692.883301, 34.014648, 73.700790), -- sandy shores
        vector4(1305.177979, 4312.773438, 37.654175, 266.456696), -- sandy shores
        vector4(177.336258, 6399.666016, 31.318726, 308.976379), -- paleto
        vector4(-6.646149, 6307.358398, 31.217529, 28.346457), -- paleto
        vector4(-78.184616, 6265.134277, 31.352417, 325.984253), -- paleto
        vector4(-244.589005, 6061.964844, 31.841064, 150.236221), -- paleto
        vector4(-3147.942871, 1116.527466, 20.838135, 243.779526), -- Senora Freeway
    },
}