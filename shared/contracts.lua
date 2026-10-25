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
        vec4(195.17, -933.77, 30.69, 150.0),  -- Legion Square
        vec4(298.0, -584.4, 43.26, 70.0),     -- Pillbox Hill
        vec4(373.9, 326.9, 103.57, 255.0),    -- Clinton Avenue
        vec4(-47.4, -1757.5, 29.42, 50.0),    -- Davis
        vec4(118.4, -1920.3, 21.32, 270.0),   -- Grove Street
        vec4(-707.5, -914.3, 19.22, 90.0),    -- Little Seoul
        vec4(-1487.5, -379.4, 40.16, 135.0),  -- Morningwood
        vec4(-1850.1, -1231.9, 13.02, 320.0), -- Del Perro Pier
        vec4(1135.8, -982.3, 46.42, 275.0),   -- Mirror Park
        vec4(-3038.9, 585.9, 7.91, 20.0),     -- Chumash
        vec4(547.4, 2671.0, 42.16, 100.0),    -- Harmony
        vec4(1961.1, 3740.7, 32.34, 300.0),   -- Sandy Shores
        vec4(2678.9, 3280.5, 55.24, 240.0),   -- Senora Freeway
        vec4(1698.4, 4924.0, 42.06, 325.0),   -- Grapeseed
    },

    MinHandover            = 500,          -- Least dirty cash handed over at one drop
    MaxHandover            = 2500,         -- Most dirty cash handed over at one drop (random between min and max)
    Cut                    = 40,           -- % the contact keeps of every handover
    Cooldown               = 120,          -- Seconds before a new shift after ending it or disconnecting
    FirstDropDelay         = { 3, 5 },     -- Seconds from starting the shift to the first drop (random between the two)
    DropDelay              = { 15, 30 },   -- Seconds between drops after that (random between the two)
    DropTime               = 600,          -- Seconds to reach a contact. Missing it ends the shift
    MinDropDistance        = 400.0,        -- Least distance from the player to a new drop

    Contacts               = {
        SpawnDistance    = 60.0,           -- The contact appears when the player is this close
        GreetingDistance = 10.0,           -- The contact greets the player at this range
        Models           = { "a_m_y_hipster_01", "a_m_m_business_01", "a_m_y_downtown_01", "a_m_m_eastsa_01", "a_m_y_stbla_01", "a_m_y_vinewood_01" },
        Scenarios        = { "WORLD_HUMAN_STAND_IMPATIENT", "WORLD_HUMAN_SMOKING", "WORLD_HUMAN_STAND_MOBILE", "WORLD_HUMAN_HANG_OUT_STREET" },
    },

    Blip                   = { Sprite = 280, Display = 4, Scale = 0.8, Color = 1, Route = true, RouteColor = 1, Label = "Contact" },
}