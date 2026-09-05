_API.Target = {}

---Creates new targetable options for all Object entity types
---@param options table A list of target options, where each option is a table containing:
---   - label (string): The text displayed for the option.
---   - name (string): A unique identifier for the target option (only for ox_target).
---   - icon (string): The icon associated with the target option.
---   - distance (number): The maximum interaction distance.
---   - canInteract (function): A function(entity, distance) that determines if interaction is allowed.
---   - onSelect (function): A function(entity) triggered when the option is selected.
---   - event (string | nil): The event triggered instead of onSelect (if applicable).
function _API.Target.AddGlobalObject(options)
    if _Target == "ox_target" then
        local formattedOptions = {}
        for _, opt in ipairs(options) do
            table.insert(formattedOptions, {
                label = opt.label,
                name = opt.name,
                icon = opt.icon,
                distance = opt.distance,
                canInteract = function(entity, distance, coords, name, bone)
                    return opt.canInteract and opt.canInteract(entity, distance)
                end,
                onSelect = opt.onSelect and function(data)
                    opt.onSelect(data.entity)
                end or nil,
                event = opt.event or nil,
            })
        end
        exports[_Target]:addGlobalObject(formattedOptions)
    elseif _Target == "qb-target" then
        local formattedOptions = {}
        for _, opt in ipairs(options) do
            table.insert(formattedOptions, {
                event = opt.event or nil,
                icon = opt.icon,
                label = opt.label,
                action = opt.onSelect and function(entity)
                    opt.onSelect(entity)
                end or nil,
                canInteract = function(entity, distance, data)
                    return opt.canInteract and opt.canInteract(entity, distance)
                end,
            })
        end
        exports[_Target]:AddGlobalObject({
            options = formattedOptions,
            distance = options[1].distance
        })
    end
end

---Creates new targetable options for all Vehicle entity types.
---@param options table A list of target options, where each option is a table containing:
---   - label (string): The text displayed for the option.
---   - name (string): A unique identifier for the target option (only for ox_target).
---   - icon (string): The icon associated with the target option.
---   - distance (number): The maximum interaction distance.
---   - canInteract (function): A function(entity, distance) that determines if interaction is allowed.
---   - onSelect (function): A function(entity) triggered when the option is selected.
---   - event (string | nil): The event triggered instead of onSelect (if applicable).
function _API.Target.AddGlobalVehicle(options)
    if _Target == "ox_target" then
        local formattedOptions = {}
        for _, opt in ipairs(options) do
            table.insert(formattedOptions, {
                label = opt.label,
                name = opt.name,
                icon = opt.icon,
                distance = opt.distance,
                canInteract = function(entity, distance, coords, name, bone)
                    return opt.canInteract and opt.canInteract(entity, distance)
                end,
                onSelect = opt.onSelect and function(data)
                    opt.onSelect(data.entity)
                end or nil,
                event = opt.event or nil,
            })
        end
        exports[_Target]:addGlobalVehicle(formattedOptions)
    elseif _Target == "qb-target" then
        local formattedOptions = {}
        for _, opt in ipairs(options) do
            table.insert(formattedOptions, {
                event = opt.event or nil,
                icon = opt.icon,
                label = opt.label,
                action = opt.onSelect and function(entity)
                    opt.onSelect(entity)
                end or nil,
                canInteract = function(entity, distance, data)
                    return opt.canInteract and opt.canInteract(entity, distance)
                end,
            })
        end
        exports[_Target]:AddGlobalVehicle({
            options = formattedOptions,
            distance = options[1].distance
        })
    end
end

---Creates new targetable options for all Ped entity types (excluding players).
---@param options table A list of target options, where each option is a table containing:
---   - label (string): The text displayed for the option.
---   - name (string): A unique identifier for the target option (only for ox_target).
---   - icon (string): The icon associated with the target option.
---   - distance (number): The maximum interaction distance.
---   - canInteract (function): A function(entity, distance) that determines if interaction is allowed.
---   - onSelect (function): A function(entity) triggered when the option is selected.
---   - event (string | nil): The event triggered instead of onSelect (if applicable).
function _API.Target.AddGlobalPed(options)
    if _Target == "ox_target" then
        local formattedOptions = {}
        for _, opt in ipairs(options) do
            table.insert(formattedOptions, {
                label = opt.label,
                name = opt.name,
                icon = opt.icon,
                distance = opt.distance,
                canInteract = function(entity, distance, coords, name, bone)
                    return opt.canInteract and opt.canInteract(entity, distance)
                end,
                onSelect = opt.onSelect and function(data)
                    opt.onSelect(data.entity)
                end or nil,
                event = opt.event or nil,
            })
        end
        exports[_Target]:addGlobalPed(formattedOptions)
    elseif _Target == "qb-target" then
        local formattedOptions = {}
        for _, opt in ipairs(options) do
            table.insert(formattedOptions, {
                event = opt.event or nil,
                icon = opt.icon,
                label = opt.label,
                action = opt.onSelect and function(entity)
                    opt.onSelect(entity)
                end or nil,
                canInteract = function(entity, distance, data)
                    return opt.canInteract and opt.canInteract(entity, distance)
                end,
            })
        end
        exports[_Target]:AddGlobalPed({
            options = formattedOptions,
            distance = options[1].distance
        })
    end
end

---Creates new targetable options for a specific model or list of models.
---@param models number|string|Array<number|string> specific model number/string or array of models
---@param options table A list of target options, where each option is a table containing:
---   - label (string): The text displayed for the option.
---   - name (string): A unique identifier for the target option (only for ox_target).
---   - icon (string): The icon associated with the target option.
---   - distance (number): The maximum interaction distance.
---   - canInteract (function): A function(entity, distance) that determines if interaction is allowed.
---   - onSelect (function): A function(entity) triggered when the option is selected.
---   - event (string | nil): The event triggered instead of onSelect (if applicable).
function _API.Target.AddModel(models, options)
    if _Target == "ox_target" then
        local formattedOptions = {}
        for _, opt in ipairs(options) do
            table.insert(formattedOptions, {
                label = opt.label,
                name = opt.name,
                icon = opt.icon,
                distance = opt.distance,
                canInteract = function(entity, distance, coords, name, bone)
                    return opt.canInteract and opt.canInteract(entity, distance)
                end,
                onSelect = opt.onSelect and function(data)
                    opt.onSelect(data.entity)
                end or nil,
                event = opt.event or nil,
            })
        end
        exports[_Target]:addModel(models, formattedOptions)
    elseif _Target == "qb-target" then
        local formattedOptions = {}
        for _, opt in ipairs(options) do
            table.insert(formattedOptions, {
                event = opt.event or nil,
                icon = opt.icon,
                label = opt.label,
                action = opt.onSelect and function(entity)
                    opt.onSelect(entity)
                end or nil,
                canInteract = function(entity, distance, data)
                    return opt.canInteract and opt.canInteract(entity, distance)
                end,
            })
        end
        exports[_Target]:AddTargetModel(models, {
            options = formattedOptions,
            distance = options[1].distance
        })
    end
end

---Removes all options from the models list using appropriate identifiers for each target system.
---@param models number|string|Array<number|string> Model(s) to remove target options from.
---@param options table A table containing option names (ox_target) and option labels (qb-target).
function _API.Target.RemoveModel(models, options)
    if _Target == "ox_target" then
        exports[_Target]:removeModel(models, options.names)
    elseif _Target == "qb-target" then
        exports[_Target]:RemoveTargetModel(models, options.labels)
    end
end

---Creates new targetable options for a specific entity handle or list of entity handles
---@param entities number|number[] Specific entity handle or list of entity handles.
---@param options table A list of target options, where each option is a table containing:
---   - label (string): The text displayed for the option.
---   - name (string): A unique identifier for the target option (only for ox_target).
---   - icon (string): The icon associated with the target option.
---   - distance (number): The maximum interaction distance.
---   - canInteract (function): A function(entity, distance) that determines if interaction is allowed.
---   - onSelect (function): A function(entity) triggered when the option is selected.
---   - event (string | nil): The event triggered instead of onSelect (if applicable).
function _API.Target.AddLocalEntity(entities, options)
    if _Target == "ox_target" then
        local formattedOptions = {}
        for _, opt in ipairs(options) do
            table.insert(formattedOptions, {
                label = opt.label,
                name = opt.name,
                icon = opt.icon,
                distance = opt.distance,
                canInteract = function(entity, distance, coords, name, bone)
                    return opt.canInteract and opt.canInteract(entity, distance)
                end,
                onSelect = opt.onSelect and function(data)
                    opt.onSelect(data.entity)
                end or nil,
                event = opt.event or nil,
            })
        end
        exports[_Target]:addLocalEntity(entities, formattedOptions)
    elseif _Target == "qb-target" then
        local formattedOptions = {}
        for _, opt in ipairs(options) do
            table.insert(formattedOptions, {
                event = opt.event or nil,
                icon = opt.icon,
                label = opt.label,
                action = opt.onSelect and function(entity)
                    opt.onSelect(entity)
                end or nil,
                canInteract = function(entity, distance, data)
                    return opt.canInteract and opt.canInteract(entity, distance)
                end,
            })
        end
        exports[_Target]:AddTargetEntity(entities, {
            options = formattedOptions,
            distance = options[1].distance
        })
    end
end

---Removes all options from the entities list with the option names.
---@param entities number|number[] Specific entity handle or list of entity handles.
---@param options table A table containing option names (ox_target) and option labels (qb-target).
function _API.Target.RemoveLocalEntity(entities, options)
    if _Target == "ox_target" then
        exports[_Target]:removeLocalEntity(entities, options.names)
    elseif _Target == "qb-target" then
        exports[_Target]:RemoveTargetEntity(entities, options.labels)
    end
end