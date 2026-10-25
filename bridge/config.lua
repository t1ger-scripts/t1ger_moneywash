Bridge = {
    -- Framework Selection
    Framework = "auto", -- "esx", "qbcore", "qbox", or "auto" (auto-detect)

    -- Inventory System Selection
    Inventory = "auto", -- "auto" (auto-detect) or one of:
    -- "ox_inventory"
    -- "qb-inventory"
    -- "qs-inventory"
    -- "core_inventory"
    -- "codem-inventory"
    -- "origen_inventory"
    -- "ak47_inventory" 
    -- "ak47_qb_inventory"
    -- "tgiann-inventory"

    -- Targeting System Selection
    Target = "auto", -- "ox_target", "qb-target", or "auto"

    -- Notifications System
    Notification = "ox_lib", -- "ox_lib", "esx", "qbcore" or modify functions inside bridge/notification/

    -- Debug Mode (Enables verbose logging)
    Debug = false
}

-- List of pre-supported inventories. Add your inventory in here in case you are adding compatibility with an unsupported inventory system.
Bridge.CompatibleInventories = {
    "ox_inventory",
    "qb-inventory",
    "qs-inventory",
    "core_inventory",
    "codem-inventory",
    "origen_inventory",
    "ak47_inventory",
    "ak47_qb_inventory",
    "tgiann-inventory"
}

-- List of pre-supported targeting systems. Add your targeting system in here in case you are adding compatibility with an unsupported targeting system.
Bridge.CompatibleTargets = {
    "ox_target",
    "qb-target"
}