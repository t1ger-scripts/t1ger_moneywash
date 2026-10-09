--- ============================================================================
--- Business Cycle
--- Global cycle timing. Starts at script start, never persisted to the DB.
--- ============================================================================

local CycleStartedAt = os.time()
local CurrentCycle   = 1 -- increments each time a cycle completes

--- @return number
function GetCurrentCycle()
    return CurrentCycle
end

--- Checks whether the cycle has completed and, if so, rolls it over.
--- Resets cycleLaundered for ALL businesses simultaneously.
function CheckGlobalCycle()
    local cycleDurationSeconds = Config.Business.CycleDuration * 60
    local now = os.time()

    if (now - CycleStartedAt) >= cycleDurationSeconds then
        CycleStartedAt = now
        CurrentCycle   = CurrentCycle + 1

        for id in pairs(GetAllBusinesses()) do
            UpdateBusiness(id, "cycleLaundered", 0)
        end

        if Config.Debug then
            print(("[MoneyWash] Cycle %d started — cycleLaundered reset for all businesses"):format(CurrentCycle))
        end
    end
end

--- Testing/admin: rolls the global cycle over immediately by backdating
--- CycleStartedAt, so CheckGlobalCycle's own logic does the reset.
function ForceGlobalCycle()
    CycleStartedAt = os.time() - (Config.Business.CycleDuration * 60)
    CheckGlobalCycle()
end