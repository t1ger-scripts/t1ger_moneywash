-- Launder contracts: started from payphones by players with dirty cash, no business needed
return {
    Target = { Icon = "fa-solid fa-phone", Distance = 1.5 }, -- Payphone target icon and range

    Models = {                                               -- Payphone props that get the target
        "prop_phonebox_01a",
        "prop_phonebox_01b",
        "prop_phonebox_01c",
        "prop_phonebox_02",
        "prop_phonebox_03",
        "prop_phonebox_04",
    },

    -- Contracts in menu order. Names and descriptions: locales/en.json > contract.<Id>
    List = {
        {
            Id                 = "street_handover",
            Icon               = "fa-solid fa-handshake",
            RequiredReputation = 0,    -- Reputation points needed to take the contract
            MinHandover        = 500,  -- Least dirty cash handed over at one drop
            MaxHandover        = 2500, -- Most dirty cash handed over at one drop (random between min and max)
            Cut                = 40,   -- % the contact keeps of every handover
        },
    },
}
