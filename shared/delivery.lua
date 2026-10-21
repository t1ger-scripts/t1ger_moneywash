-- Stock delivery mission: cancel rules, ranges, icons, props, blips, cargo damage and pickup locations
return {
    CancelCommand         = "cancelstock", -- Chat command to cancel an active mission
    CancelPenaltyPercent  = 10,            -- % of the paid cost lost on a manual cancel
    CancelCooldown        = 300,           -- Seconds before a new order is allowed after a cancel

    PickupDistance        = 25.0,          -- Range at which the pickup box spawns
    PickupTargetDistance  = 2.0,           -- Target range for the ground box and the handler delivery option
    VehicleTargetDistance = 3.5,           -- Target range for the vehicle load/unload options

    -- Target option icons
    Icons                 = {
        PickupTarget  = "fa-solid fa-hand",           -- Pick up the box
        LoadTarget    = "fa-solid fa-truck-ramp-box", -- Load the box into a vehicle
        UnloadTarget  = "fa-solid fa-hand",           -- Take the box out of a vehicle
        DeliverTarget = "fa-solid fa-dolly",          -- Deliver to the handler
    },

    -- Box prop carried in hand
    PickupObject          = { model = "prop_cs_cardbox_01", pos = { x = 0.0, y = -0.2, z = -0.1 }, rot = { x = 135.0, y = 0.0, z = 0.0 }, bone = 28422 },

    -- Animation played while carrying the box
    CarryAnimation        = { dict = "anim@heists@box_carry@", name = "idle", blendIn = 4.0, blendOut = 1.0, duration = -1, flag = 49 },

    -- Blip at the pickup location, removed on arrival
    PickupBlip            = { Sprite = 1, Display = 6, Scale = 0.7, Color = 5, Route = true, RouteColor = 5, Label = "Stock Pickup" },

    -- Blip at the business, from pickup until delivery
    DeliveryBlip          = { Sprite = 1, Display = 4, Scale = 0.8, Color = 2, Route = true, RouteColor = 2, Label = "Deliver Stock" },

    -- Marker above the ground box
    PickupMarker          = {
        Distance      = 20.0,                            -- Only drawn within this range
        Type          = 20,                              -- Marker type: docs.fivem.net/docs/game-references/markers
        Scale         = { x = 0.5, y = 0.5, z = 0.5 },
        ZOffset       = 1.0,                             -- Height above the box
        Rotation      = { x = 180.0, y = 0.0, z = 0.0 }, -- 180 on X flips the marker upside down
        Color         = { r = 255, g = 190, b = 40, a = 180 },
        BobUpAndDown  = true,
        FaceCamera    = false,
        Rotate        = false,
        RotationOrder = 2,
    },

    -- Cargo damage from vehicle collisions
    CollisionDamage       = {
        Enable              = true, -- false = no cargo damage
        MinDeductionPercent = 5,    -- Min % of current stock lost per collision
        MaxDeductionPercent = 15,   -- Max % of current stock lost per collision
        PingCooldown        = 3000, -- Ms between accepted collision reports per shipment
        MinImpactSpeed      = 5.0,  -- Min vehicle speed (m/s) for the client to report a hit
    },

    -- Cargo condition meter, shown from pickup until delivery
    DamageMeter           = {
        Enable           = true,
        Position         = "bottom-center", -- top-left, top-right, bottom-left, bottom-right, top-center, bottom-center
        Width            = 0.10,            -- Screen-relative (0.0-1.0)
        Height           = 0.02,
        Margin           = 0.02,
        BackgroundColor  = { r = 0,   g = 0,   b = 0,   a = 150 },
        FillColor        = { r = 46,  g = 204, b = 113, a = 220 }, -- Good condition
        WarningColor     = { r = 230, g = 126, b = 34,  a = 220 }, -- Mid condition
        DangerColor      = { r = 231, g = 76,  b = 60,  a = 220 }, -- Low condition
        WarningThreshold = 60,                                     -- % remaining below which WarningColor is used
        DangerThreshold  = 30,                                     -- % remaining below which DangerColor is used
    },

    -- Pickup spots, one picked at random per order (any business type)
    PickupLocations       = {
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
        vector4(2477.485840, 4122.843750, 38.008057, 28.346457),   -- Sandy Shores
        vector4(2564.347168, 4692.883301, 34.014648, 73.700790),   -- Sandy Shores
        vector4(1305.177979, 4312.773438, 37.654175, 266.456696),  -- Sandy Shores
        vector4(177.336258, 6399.666016, 31.318726, 308.976379),   -- Paleto
        vector4(-6.646149, 6307.358398, 31.217529, 28.346457),     -- Paleto
        vector4(-78.184616, 6265.134277, 31.352417, 325.984253),   -- Paleto
        vector4(-244.589005, 6061.964844, 31.841064, 150.236221),  -- Paleto
        vector4(-3147.942871, 1116.527466, 20.838135, 243.779526), -- Senora Freeway
    },
}