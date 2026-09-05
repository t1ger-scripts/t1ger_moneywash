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

    -- Society/Shared Account for Job
    JobAccount = "auto", -- "auto" (auto-detect) or one of:
    -- "esx_addonaccount"
    -- "qb-banking"
    -- "qb-management"
    -- "Renewed-Banking"
    -- "tgg-banking"
    -- "okokBanking"
    -- "wasabi_banking"
    -- "fd_banking"
    -- "crm-banking"
    -- "snipe-banking"
    -- "RxBanking"

    -- Garage System Selection
    Garage = "auto", -- "auto" (auto-detect) or one of:
    -- "esx_garage"
    -- "qbx_garages"
    -- "qb-garages"
    -- "jg-advancedgarages"
    -- "cd_garage"
    -- "okokGarage"
    -- "codem-garage"
    -- "rcore_garage"
    -- "renzu_garage"
    -- "qs-advancedgarages"
    -- "ak47_garage"
    -- "loaf_garage"

    -- Vehicle Keys System Selection
    VehicleKeys = "auto", -- "auto" (auto-detect) or one of:
    -- "qbx_vehiclekeys"
    -- "qb-vehiclekeys"

    UseFrameworkVehicleProps = false, -- "use framework's vehicle properties or use my built-in improved vehicle properties"
    TrimPlates = true, -- trimplates is default in ESX/QBCore/Qbox inside vehicle props. 

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

-- List of pre-supported job account systems for given frameworks. Add your own for your framework below.
Bridge.CompatibleJobAccounts = {
    esx = {"esx_addonaccount", "okokBanking", "wasabi_banking", "crm-banking", "snipe-banking", "RxBanking"},
    qbox = {"Renewed-Banking", "tgg-banking", "fd_banking", "crm-banking", "RxBanking"},
    qbcore = {"qb-banking", "qb-management", "okokBanking", "wasabi_banking", "fd_banking", "crm-banking", "snipe-banking", "RxBanking"}
}

-- List of pre-supported garage systems. Add your garage system in here in case you are adding compatibility with an unsupported garage system.
Bridge.CompatibleGarages = {
    "esx_garage",
    "qbx_garages",
    "qb-garages",
    "jg-advancedgarages",
    "cd_garage",
    "okokGarage",
    "codem-garage",
    "rcore_garage",
    "renzu_garage",
    "qs-advancedgarages",
    "ak47_garage",
    "loaf_garage"
}

Bridge.CompatibleVehicleKeys = {
    "qbx_vehiclekeys",
    "qb-vehiclekeys",
    "t1ger_keys",
    "qs-vehiclekeys"
}