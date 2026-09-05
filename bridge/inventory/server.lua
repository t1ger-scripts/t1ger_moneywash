_API.Inventory = {}
_API.Stash = {}
_API.UseableItemCallbacks = {}

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
        local itemList = exports[_Inventory]:getItemsList()
        if not itemList or not itemList[item] then return end
        return itemList[item].label
    elseif _Inventory == "origen_inventory" then
        local itemInfo = exports.origen_inventory:Items(item)
        if not itemInfo then return end
        return itemInfo.label
    elseif _Inventory == "codem-inventory" then
        local itemList = exports[_Inventory]:GetItemList()
        if not itemList or not itemList[item] then return end
        return itemList[item].label
    elseif _Inventory == "ak47_inventory" or _Inventory == "ak47_qb_inventory" then
        local itemInfo = exports[_Inventory]:Items(item)
        if not itemInfo then return end
        return itemInfo.label
    elseif _Inventory == "tgiann-inventory" then
        local itemInfo = exports[_Inventory]:Items(item)
        if not itemInfo then return end
        return itemInfo.label
    elseif _Inventory == "custom" then 
        -- add custom function in here
    else
        -- fallback to framework method:
        return _API.GetItemLabel(item)
    end
end

--- Retrieves the quantity of a specified item in a player's inventory.
--- Rreturns the total count of the given item. If the inventory system is unsupported, it falls back to framework method: `_API.Player.GetItemCount`.
--- @param src number The player ID. Must be a valid number.
--- @param item string The name of the item to check. Must be a non-empty string.
--- @return number amount The quantity of the specified item. Returns 0 if the item is not found.
function _API.Inventory.GetItemCount(src, item)
    if type(src) ~= "number" then
        return error("[_API.Inventory.GetItemCount] Invalid source type. Must be a number equivalent to player ID")
    end
    
    if type(item) ~= "string" or item == "" then
        return error("[_API.Inventory.GetItemCount] Invalid item type. Must be a non-empty string for the item name")
    end

    if _Inventory == "ox_inventory" then
        return exports[_Inventory]:Search(src, "count", item) or 0
    elseif _Inventory == "qb-inventory" then
        return exports[_Inventory]:GetItemCount(src, item) or 0
    elseif _Inventory == "qs-inventory" then
        return exports[_Inventory]:GetItemTotalAmount(src, item) or 0
    elseif _Inventory == "core_inventory" then
        return exports[_Inventory]:getItemCount(src, item) or 0
    elseif _Inventory == "origen_inventory" then
        return exports[_Inventory]:getItemCount(src, item) or 0
    elseif _Inventory == "codem-inventory" then
        return exports[_Inventory]:GetItemsTotalAmount(src, item) or 0
    elseif _Inventory == "ak47_inventory" or _Inventory == "ak47_qb_inventory" then
        return exports[_Inventory]:GetAmount(src, item) or 0
    elseif _Inventory == "tgiann-inventory" then
        return exports[_Inventory]:Search(src, "count", item) or 0
    elseif _Inventory == "custom" then 
        -- add custom function in here
    else
        return _API.Player.GetItemCount(src, item)
    end
end

--- Checks if the player can carry a specified item and amount. If the inventory system is unsupported, it falls back to framework method: `_API.Player.CanCarryItem`.
--- @param src number The player ID.
--- @param item string The item name.
--- @param count number The quantity to check.
--- @return boolean canCarry `true` if the player can carry the item and count, `false` otherwise.
function _API.Inventory.CanCarryItem(src, item, count)
    if type(src) ~= "number" then
        return error("[_API.Inventory.CanCarryItem] Invalid source type. Must be a number equivalent to player ID")
    end
    
    if type(item) ~= "string" or item == "" then
        return error("[_API.Inventory.CanCarryItem] Invalid item type. Must be a non-empty string for the item name")
    end
    
    if type(count) ~= "number" then
        return error("[_API.Inventory.CanCarryItem] Invalid count type. Must be a number")
    end

    -- if parsed count is less or equal to 0 then return true
    if count <= 0 then return true end

    if _Inventory == "ox_inventory" then
        return exports[_Inventory]:CanCarryItem(src, item, count)
    elseif _Inventory == "qb-inventory" then
        return exports[_Inventory]:CanAddItem(src, item, count)
    elseif _Inventory == "qs-inventory" then
        return exports[_Inventory]:CanCarryItem(src, item, count)
    elseif _Inventory == "core_inventory" then
        return exports[_Inventory]:canCarry(src, item, count)
    elseif _Inventory == "codem-inventory" then
        -- codeM has no no export to check for this...
        return true
    elseif _Inventory == "origen_inventory" then
        return exports[_Inventory]:canCarryItem(src, item, count)
    elseif _Inventory == "ak47_inventory" or _Inventory == "ak47_qb_inventory" then
        return exports[_Inventory]:CanAddItem(src, item, count)
    elseif _Inventory == "tgiann-inventory" then
        return exports[_Inventory]:CanCarryItem(src, item, count)
    elseif _Inventory == "custom" then 
        -- add custom function in here
    else
        return _API.Player.CanCarryItem(src, item, count)
    end
end

--- Adds an item to the player's inventory. If the inventory system is unsupported, it falls back to framework method: `_API.Player.AddItem`.
--- @param src number The player ID.
--- @param item string The item name.
--- @param count number The amount to add.
--- @param metadata table|nil (optional) Additional item metadata, such as custom properties.
function _API.Inventory.AddItem(src, item, count, metadata)
    if type(src) ~= "number" then
        return error("[_API.Inventory.AddItem] Invalid source type. Must be a number equivalent to player ID")
    end
    
    if type(item) ~= "string" or item == "" then
        return error("[_API.Inventory.AddItem] Invalid item type. Must be a non-empty string for the item name")
    end
    
    if type(count) ~= "number" then
        return error("[_API.Inventory.AddItem] Invalid count type. Must be a number")
    end

    if _Inventory == "ox_inventory" then
        exports[_Inventory]:AddItem(src, item, count, metadata or false)
    elseif _Inventory == "qb-inventory" then
        exports[_Inventory]:AddItem(src, item, count, nil, metadata or false)
        if Framework == "qbcore" then
            TriggerClientEvent(_Inventory..":client:ItemBox", src, _FW[Framework].Shared.Items[item], "add", count)
        end
    elseif _Inventory == "qs-inventory" then 
        exports[_Inventory]:AddItem(src, item, count, nil, metadata or false)
    elseif _Inventory == "codem-inventory" then
        exports[_Inventory]:AddItem(src, item, count, nil, metadata or false)
    elseif _Inventory == "core_inventory" then
        exports[_Inventory]:addItem(src, item, count, metadata or false)
    elseif _Inventory == "origen_inventory" then
        exports[_Inventory]:addItem(src, item, count, metadata or false)
    elseif _Inventory == "ak47_inventory" or _Inventory == "ak47_qb_inventory" then
        exports[_Inventory]:AddItem(src, item, count, nil, metadata or false)
    elseif _Inventory == "tgiann-inventory" then
        return exports[_Inventory]:AddItem(src, item, count, nil, metadata or false)
    elseif _Inventory == "custom" then 
        -- add custom function in here
    else
        _API.Player.AddItem(src, item, count)
    end
end

--- Removes an item from the player's inventory. If the inventory system is unsupported, it falls back to framework method: `_API.Player.RemoveItem`.
--- @param src number The player ID.
--- @param item string The item name.
--- @param count number The amount to remove.
function _API.Inventory.RemoveItem(src, item, count)
    if type(src) ~= "number" then
        return error("[_API.Inventory.RemoveItem] Invalid source type. Must be a number equivalent to player ID")
    end
    
    if type(item) ~= "string" or item == "" then
        return error("[_API.Inventory.RemoveItem] Invalid item type. Must be a non-empty string for the item name")
    end
    
    if type(count) ~= "number" then
        return error("[_API.Inventory.RemoveItem] Invalid count type. Must be a number")
    end

    if _Inventory == "ox_inventory" then
        exports[_Inventory]:RemoveItem(src, item, count, metadata or false)
    elseif _Inventory == "qb-inventory" then
        exports[_Inventory]:RemoveItem(src, item, count, false)
        if Framework == "qbcore" then
            TriggerClientEvent(_Inventory..":client:ItemBox", src, _FW[Framework].Shared.Items[item], "remove", count)
        end
    elseif _Inventory == "qs-inventory" then
        exports[_Inventory]:RemoveItem(src, item, count, nil, metadata or false)
    elseif _Inventory == "codem-inventory" then
        exports[_Inventory]:RemoveItem(src, item, count, false)
    elseif _Inventory == "core_inventory" then
        exports[_Inventory]:removeItem(src, item, count)
    elseif _Inventory == "origen_inventory" then 
        exports[_Inventory]:removeItem(src, item, count, metadata or false)
    elseif _Inventory == "ak47_inventory" or _Inventory == "ak47_qb_inventory" then
        exports[_Inventory]:RemoveItem(src, item, count)
    elseif _Inventory == "tgiann-inventory" then
        return exports[_Inventory]:RemoveItem(src, item, count, nil, metadata or false)
    elseif _Inventory == "custom" then 
        -- add custom function in here
    else
        _API.Player.RemoveItem(src, item, count)
    end
end

---Registers a function to a useable item
---@param item string The name of the item
---@param cb func callback function
function _API.Inventory.RegisterUseableItem(item, cb)
    if _Inventory == "ox_inventory" then
        _API.UseableItemCallbacks[item] = cb
    else
        _API.RegisterUseableItem(item, cb)
    end
end

--- Event handler for used item on ox_inventory
AddEventHandler("ox_inventory:usedItem", function(src, itemName)
    local cb = _API.UseableItemCallbacks[itemName]
    if cb then
        cb(src, itemName)
    else
        if Bridge.Debug then
            print("[ox_inventory] No registered callback for item:", itemName)
        end
    end
end)

--- Function to create a new stash
--- @param id string The unique identifier for the stash
--- @param label string The label or name of the stash
--- @param slots number The number of slots available in the stash
--- @param weight number The maximum weight capacity of the stash
--- @param owner string|nil The owner of the stash (optional)
function _API.Stash.Create(id, label, slots, weight, owner)
    if _Inventory == "ox_inventory" then
        _API.Stash.Register(id, label, slots, weight, owner)
    elseif _Inventory == "qb-inventory" then
        exports[_Inventory]:CreateInventory(id, {label = label, maxweight = weight, slots = slots})
    elseif _Inventory == "origen_inventory" then
        _API.Stash.Register(id, label, slots, weight, owner)
    elseif _Inventory == "ak47_inventory" or _Inventory == "ak47_qb_inventory" then
        _API.Stash.Register(id, label, slots, weight, owner)
    elseif _Inventory == "tgiann-inventory" then
        _API.Stash.Register(id, label, slots, weight, owner)
    elseif _Inventory == "custom" then 
        -- add export/function to create a stash first time
    end
end

--- Function to register a stash
--- @param id string The unique identifier for the stash
--- @param label string The label or name of the stash
--- @param slots number The number of slots available in the stash
--- @param weight number The maximum weight capacity of the stash
--- @param owner string|nil The owner of the stash (optional)
function _API.Stash.Register(id, label, slots, weight, owner)
    if _Inventory == "ox_inventory" then
        exports[_Inventory]:RegisterStash(id, label, slots, weight, owner)
    elseif _Inventory == "qb-inventory" then
        exports[_Inventory]:RegisterInventory(id, {label = label, maxweight = weight, slots = slots})
    elseif _Inventory == "core_inventory" then
        exports[_Inventory]:openInventory(0, "stash-"..id:gsub("/",""):gsub(":",""):gsub("#",""), "stash", nil, nil, false)
    elseif _Inventory == "origen_inventory" then 
        exports[_Inventory]:registerStash(id, {
            label = label,
            slots = slots,
            weight = weight
        })
    elseif _Inventory == "ak47_inventory" or _Inventory == "ak47_qb_inventory" then
        exports[_Inventory]:LoadInventory(id, {label = label, maxWeight = weight, slots = slots, type = "stash"})
    elseif _Inventory == "tgiann-inventory" then
        exports[_Inventory]:RegisterStash(id, label, slots, weight, owner)
    elseif _Inventory == "custom" then
        -- add export/function to register stash (if needed) on server startup/restarts 
    end
end

--- Function to add an item directly into a stash
--- @param storageId string The identifier of the stash
--- @param item string The name of the item to add
--- @param amount number The quantity of the item to add
--- @return boolean success Whether the item was successfully added
--- @return any response Additional response information from the inventory system
function _API.Stash.AddItem(storageId, item, amount)
    local success, response = true, nil
    if _Inventory == "ox_inventory" then
        success, response = exports.ox_inventory:AddItem(storageId, item, amount)
    elseif _Inventory == "qb-inventory" then
        exports[_Inventory]:AddItem(storageId, item, amount)
    elseif _Inventory == "qs-inventory" then
        exports[_Inventory]:AddItemIntoStash("Stash_"..storageId, item, amount)
    elseif _Inventory == "core_inventory" then
        success = exports[_Inventory]:addItem("stash-"..storageId:gsub("/",""):gsub(":",""):gsub("#",""), item, tonumber(amount), {}, "stash")
    elseif _Inventory == "codem-inventory" then
        print("codem-inventory does not have have export/event to add item directly into a stash...")
        success = false
    elseif _Inventory == "origen_inventory" then
        success, response = exports[_Inventory]:addItem(storageId, item, amount)
    elseif _Inventory == "ak47_inventory" or _Inventory == "ak47_qb_inventory" then
        exports[_Inventory]:AddItem(storageId, item, amount)
    elseif _Inventory == "tgiann-inventory" then
        success = exports[_Inventory]:AddItemToSecondaryInventory("stash", storageId, item, amount)
    elseif _Inventory == "custom" then 
        -- add export/function to add item to stash
    end
    return success, response
end

-- Server event to open stash if no client exports/triggerserver events
RegisterServerEvent("t1ger_mechanic:server:openStash")
AddEventHandler("t1ger_mechanic:server:openStash", function(id, label, slots, weight, owner)
    local src = source
    if _Inventory == "qb-inventory" then
        local data = { label = label, maxweight = weight, slots = slots }
        exports[_Inventory]:OpenInventory(src, id, data)
    end
end)