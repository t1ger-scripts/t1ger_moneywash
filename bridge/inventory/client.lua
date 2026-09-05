_API.Inventory = {}
_API.Stash = {}

--- Returns item label for a specified item name.
--- @param item string The name of the item to check. Must be a non-empty string.
--- @return string itemLabel The label of the specified item
function _API.Inventory.GetItemLabel(item)
    if type(item) ~= "string" or item == "" then 
        return error("[_API.Inventory.GetItemLabel] Invalid item type. Expected a non-empty string!")
    end

    if _Inventory == "ox_inventory" then
        local itemInfo = exports[_Inventory]:Items(item)
        if not itemInfo then return end
        return itemInfo.label
    elseif _Inventory == "qb-inventory" then
        local itemInfo = _FW[Framework].Shared.Items[item]
        if not itemInfo then return end
        return itemInfo.label
    elseif _Inventory == "qs-inventory" then
        local itemList = exports[_Inventory]:GetItemList()
        if not itemList or not itemList[item] then return end
        return itemList[item].label
    elseif _Inventory == "core_inventory" then
        -- no available exports
        return _API.GetItemLabel(item)
    elseif _Inventory == "origen_inventory" then
        -- exports deprecated
        return _API.GetItemLabel(item)
    elseif _Inventory == "codem-inventory" then
        local itemList = exports[_Inventory]:GetItemList()
        if not itemList or not itemList[item] then return end
        return itemList[item].label
    elseif _Inventory == "ak47_inventory" or _Inventory == "ak47_qb_inventory" then
        return exports[_Inventory]:GetItemLabel(item)
    elseif _Inventory == "tgiann-inventory" then
        return exports[_Inventory]:GetItemLabel(item)
    elseif _Inventory == "custom" then 
        -- add custom function in here
    else
        -- fallback to framework method:
        return _API.GetItemLabel(item)
    end
end

--- Returns true/false on whether player has specified count of item.
--- @param item string The name of the item to check. Must be a non-empty string.
--- @param count number The amount of the item to check. Must be a number.
--- @return boolean hasItem `true` if has specified count of item. `false` otherwise
function _API.Inventory.HasItem(item, count)
    if type(item) ~= "string" or item == "" then
        return error("[_API.Inventory.HasItem] Invalid item type. Must be a non-empty string for the item name")
    end

    if type(count) ~= "number" then
        return error("[_API.Inventory.HasItem] Invalid count type. Must be a number")
    end

    if _Inventory == "ox_inventory" then
        return exports[_Inventory]:Search("count", item) >= count
    elseif _Inventory == "qb-inventory" then
        return exports[_Inventory]:HasItem(item, count)
    elseif _Inventory == "qs-inventory" then
        local quantity = exports[_Inventory]:Search(item) or 0
        return quantity >= count
    elseif _Inventory == "core_inventory" then
        return exports[_Inventory]:hasItem(item, count)
    elseif _Inventory == "origen_inventory" then
        local quantity = exports[_Inventory]:Search("count", item) or 0
        return quantity >= count
    elseif _Inventory == "codem-inventory" then
        local userInventory = exports[_Inventory]:getUserInventory()
        local quantity = 0
        for _, itemData in pairs(userInventory) do
            if itemData.name == item then
                quantity = quantity + (itemData.amount or itemData.count or 0)
            end
        end
        return quantity >= count
    elseif _Inventory == "ak47_inventory" or _Inventory == "ak47_qb_inventory" then
        local hasItems, missingItems = exports[_Inventory]:HasItems({[tostring(item)] = count})
        return hasItems
    elseif _Inventory == "tgiann-inventory" then
        return exports[_Inventory]:Search("count", item) >= count
    elseif _Inventory == "custom" then 
        -- add custom function in here
    else
        -- fallback to framework method:
        return _API.HasItem(item, count)
    end
end

--- Function to open a stash inventory
--- @param id string The unique identifier for the stash
--- @param label string The label or name of the stash
--- @param slots number The number of slots available in the stash
--- @param weight number The maximum weight capacity of the stash
--- @param owner string|nil The owner of the stash (optional)
function _API.Stash.Open(id, label, slots, weight, owner)
    if _Inventory == "ox_inventory" then
        exports[_Inventory]:openInventory("stash", {id = id})
    elseif _Inventory == "qb-inventory" then
        TriggerServerEvent("t1ger_mechanic:server:openStash", id, label, slots, weight, owner)
        
        -- if using old qb-inventory, then comment out the TriggerServerEvent and uncomment the below events:

        --[[TriggerServerEvent("inventory:server:OpenInventory", "stash", id, {maxweight = weight, slots = slots})
        TriggerEvent("inventory:client:SetCurrentStash", id)]]

    elseif _Inventory == "qs-inventory" then
        TriggerServerEvent("inventory:server:OpenInventory", "stash", "Stash_"..id, {maxweight = weight, slots = slots})
        TriggerEvent("inventory:client:SetCurrentStash", "Stash_"..id)
    elseif _Inventory == "core_inventory" then
        TriggerServerEvent("core_inventory:server:openInventory", "stash-"..id:gsub("/",""):gsub(":",""):gsub("#",""), "stash", nil, nil)
    elseif _Inventory == "codem-inventory" then 
        TriggerServerEvent("codem-inventory:server:openstash", id, slots, weight, label)
    elseif _Inventory == "origen_inventory" then 
        exports[_Inventory]:openInventory('stash', id, {
            label = label
        })
    elseif _Inventory == "ak47_inventory" or _Inventory == "ak47_qb_inventory" then
        exports[_Inventory]:OpenInventory(id)
    elseif _Inventory == "tgiann-inventory" then
        exports[_Inventory]:OpenInventory("stash", id, {maxweight = weight, slots = slots})
    else
        -- add event/export in here to open stash
        error("[OpenStash] No Inventory configured to open stash...")
    end
end