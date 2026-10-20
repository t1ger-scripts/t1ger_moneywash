-- Raid evidence collection (NUI).
--
-- PREVIEW STAGE: the UI is driven by a local fake raid (`preview`) so the
-- screen can be tested before any server logic exists. When the server
-- callbacks are added, only the two NUI callbacks at the bottom change -
-- the UI and OpenRaidUi stay as they are.

local preview = nil -- { exposed = number, finished = boolean, seized = number }

--- Loads the locale file for the UI (same rules as the cash counter).
---@return string localeName
---@return table messages
local function loadLocale()
    local resource = GetCurrentResourceName()
    local name = (Config.BusinessPortal or {}).Locale or GetConvar("ox:locale", "en")
    local raw = LoadResourceFile(resource, "locales/" .. name .. ".json")

    if not raw then
        name = "en"
        raw = LoadResourceFile(resource, "locales/en.json")
    end

    local ok, messages = pcall(json.decode, raw or "{}")
    return name, ok and messages or {}
end

--- Opens the raid UI.
---@param exposed number Exposed Safe cash at the start of the raid (> 0)
---@return boolean opened
function OpenRaidUi(exposed)
    if not BeginMoneywashUi("raid") then return false end

    local localeName, messages = loadLocale()

    ShowMoneywashUi("raid", "t1ger_moneywash:raid:open", {
        currency   = Config.Currency,
        locale     = localeName,
        messages   = messages,
        stackCount = Config.Police.Raid.StackCount,
        exposed    = exposed,
    })

    return true
end

-- -----------------------------------------------------------------------
-- Preview raid (fake data)
-- -----------------------------------------------------------------------

if Config.Debug then
    --- /raidtest [exposed]
    --- Opens the raid UI with fake data. Testing only.
    ---   /raidtest          -> 125000 exposed
    ---   /raidtest 500000   -> 500000 exposed
    ---   /raidtest 0        -> refused, like a real raid on an empty Safe
    RegisterCommand("raidtest", function(_, args)
        local exposed = math.max(0, math.floor(tonumber(args[1]) or 125000))

        if exposed <= 0 then
            _API.ShowNotification("Nothing to seize.", "error", {})
            return
        end

        preview = { exposed = exposed, finished = false, seized = 0 }

        if not OpenRaidUi(exposed) then
            preview = nil
        end
    end, false)
end

-- -----------------------------------------------------------------------
-- NUI callbacks (swap the preview for server callbacks later)
-- -----------------------------------------------------------------------

--- NUI: the officer bagged everything and sealed the bag.
--- Must answer { success, data = { seized } } with the amount really seized.
RegisterNUICallback("t1ger_moneywash:raid:finish", function(_, cb)
    if GetMoneywashUiScreen() ~= "raid" or not preview then
        cb({ success = false, reason = "no_raid" })
        return
    end

    if not preview.finished then
        preview.finished = true
        preview.seized   = preview.exposed
    end

    cb({ success = true, data = { seized = preview.seized } })
end)

--- NUI: the officer aborted (ESC), or the screen closed after finishing.
RegisterNUICallback("t1ger_moneywash:raid:close", function(_, cb)
    SendNUIMessage({ action = "t1ger_moneywash:raid:close" })
    CloseMoneywashUi("raid")

    if preview and preview.finished then
        _API.ShowNotification(("Seized %s"):format(FormatMoney(preview.seized)), "success", {})
    end

    preview = nil

    cb({ success = true })
end)