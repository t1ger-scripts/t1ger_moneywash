-- Launder contracts: shifts of street handovers, started at a payphone by players with dirty cash
return {
    Target                 = { Icon = "fa-solid fa-phone", Distance = 1.5 }, -- Payphone target icon and range
    EndCommand             = "endshift",   -- Chat command that ends the shift (nil = no command)

    Models                 = {             -- Payphone props that get the target
        "prop_phonebox_01a",
        "prop_phonebox_01b",
        "prop_phonebox_01c",
        "prop_phonebox_02",
        "prop_phonebox_03",
        "prop_phonebox_04",
    },

    -- Places a contact can wait: standing height on the pavement, plus the heading
    Drops                  = {
        -- Los Santos:
        vec4(-75.349449, -1824.949463, 26.937744, 232.440948),
        vec4(296.320892, -2095.674805, 17.602905, 116.220474),
        vec4(-233.643951, -1489.450562, 32.953125, 269.291351),
        vec4(454.958252, -1910.241699, 24.848389, 136.062988),
        vec4(107.156052, -1562.597778, 29.599976, 243.779526),
        vec4(338.413177, -1279.318726, 31.942139, 113.385826),
        vec4(882.685730, -2360.136230, 30.206543, 320.314972),
        vec4(969.230774, -1724.505493, 30.796387, 96.377945),
        vec4(1384.800049, -2043.296753, 51.993408, 172.913391),
        vec4(1185.270386, -1406.505493, 35.126709, 263.622070),
        vec4(1134.065918, -480.197815, 66.012451, 181.417328),
        vec4(806.808777, -814.892334, 26.196289, 104.881889),
        vec4(434.729675, -657.151672, 28.757568, 79.370079),
        vec4(928.378052, -104.980217, 78.750977, 36.850395),
        vec4(341.802185, -211.516479, 54.217529, 70.866142),
        vec4(338.123077, 270.210999, 104.109863, 212.598419),
        vec4(-592.008789, 338.083527, 85.103271, 192.755920),
        vec4(-379.397797, -83.709885, 45.657837, 286.299194),
        vec4(-1353.863770, 241.331879, 59.912842, 351.496063),
        vec4(-1820.070312, 801.679138, 138.264526, 314.645660),
        vec4(-715.978027, -864.593384, 23.180176, 274.960632),
        vec4(-19.199997, -619.054932, 35.868164, 235.275589),
        vec4(-972.474731, -1579.529663, 5.167725, 201.259842),
        vec4(-1203.204346, -1478.083496, 4.375854, 221.102371),
        vec4(-1169.498901, -1170.632935, 5.622681, 277.795288),
        vec4(-1746.751587, -724.404419, 10.424927, 252.283463),
        vec4(-2186.175781, -406.562622, 13.120850, 249.448822),
        vec4(-1668.487915, -251.643951, 54.790527, 337.322845),
        vec4(-1073.551636, -475.345062, 36.660034, 158.740158),
        vec4(-66.553848, 906.395630, 235.706909, 170.078735),
        vec4(-2321.169189, 370.259338, 174.592651, 28.346457),
        vec4(-616.259338, -1790.452759, 23.702515, 257.952759),
        vec4(111.890114, -2576.136230, 5.993408, 229.606293),
        vec4(787.806580, -2960.426270, 6.027100, 79.370079),

        -- Sandy:
        vec4(1711.305542, 3782.901123, 34.772949, 212.598419),
        vec4(969.178040, 3624.751709, 32.363403, 289.133850),
        vec4(1190.413208, 2650.338379, 37.822754, 79.370079),

        -- Grapeseed:
        vec4(1780.470337, 4594.377930, 37.671021, 130.393707),
        vec4(2946.224121, 4634.360352, 48.539185, 19.842520),

        -- Paleto:
        vec4(430.615387, 6501.165039, 28.723755, 62.362206),
        vec4(11.802198, 6496.667969, 31.504028, 291.968506),
        vec4(-370.668121, 6058.404297, 31.487183, 317.480316),
        vec4(-767.037354, 5586.645996, 33.593384, 90.708656),

        -- Great Ocean High Way:
        vec4(-2223.995605, 4224.197754, 47.106934, 22.677164),
        vec4(-3148.707764, 1140.000000, 20.939209, 62.362206),
        vec4(-2955.072510, 385.595612, 15.008057, 252.283463),
    },

    MinHandover            = 500,          -- Least dirty cash handed over at one drop
    MaxHandover            = 5000,         -- Most dirty cash handed over at one drop (random between min and max)
    Cut                    = 30,           -- % the contact keeps of every handover
    PayoutAccount          = "cash",       -- Where the clean money is paid: "bank" or "cash"
    Cooldown               = 120,          -- Seconds before a new shift after ending it or disconnecting
    FirstDropDelay         = { 1, 3 },     -- Seconds from starting the shift to the first drop (random between the two)
    DropDelay              = { 5, 15 },   -- Seconds between drops after that (random between the two)
    DropTime               = 1200,         -- Seconds to reach a contact. Missing it ends the shift
    MinDropDistance        = 500.0,        -- Least distance from the player to a new drop
    MaxDropDistance        = 4000.0,       -- Furthest distance from the player to a new drop (if none fits, any free drop is used)

    Contacts               = {
        SpawnDistance    = 60.0,           -- The contact appears when the player is this close
        GreetingDistance = 4.0,           -- The contact greets the player at this range
        TargetIcon       = "fa-solid fa-sack-dollar", -- Handover target icon
        TargetDistance   = 2.0,            -- Handover target range
        LeaveTime        = 8,              -- Seconds the contact walks away before disappearing
        Handover         = { Duration = 5000 }, -- Negotiation progress bar (ms)
        Models           = { "a_m_y_hipster_01", "a_m_m_business_01", "a_m_y_downtown_01", "a_m_m_eastsa_01", "a_m_y_stbla_01", "a_m_y_vinewood_01" },
    },

    Blip                   = { Sprite = 280, Display = 4, Scale = 0.8, Color = 2, Route = true, RouteColor = 2, Label = "Contact" },

    Betrayal               = {
        Chance          = 100,              -- % chance a contact betrays at the end of a deal (50 for testing, 10 is a good live value)
        AttackChance    = 50,              -- % of betrayals where the contact attacks. Otherwise it flees
        Time            = 30,             -- Seconds to get the cash back. After that the contact has got away with it
        Health          = 200,             -- Contact health once it betrays
        Weapons         = { "WEAPON_KNIFE", "WEAPON_BAT", "WEAPON_PISTOL" }, -- An attacking contact carries one of these
        Blip            = { Sprite = 1, Display = 4, Scale = 0.7, Color = 1, Label = "Contact" }, -- Follows the contact while it runs
        CashModel       = "prop_cash_pile_01", -- Cash stack dropped where the contact dies
        TargetIcon      = "fa-solid fa-sack-dollar", -- Pick up target icon
        TargetDistance  = 2.0,             -- Pick up target range
    },
}