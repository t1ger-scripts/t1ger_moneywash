--- ============================================================================
--- Client Customize
--- OPEN FILE - safe to edit without touching core logic.
--- Swap out progress bars, skill checks and animations to match your server.
--- ============================================================================

--- Progress bar wrapper
--- Replace with your own progress bar resource if needed
--- @param options table ox_lib progressBar options
--- @return boolean completed (false if cancelled)
function ProgressBar(options)
    return lib.progressBar(options)
end

--- Skill check wrapper
--- Replace with your own minigame or skill check resource if needed
--- @param difficulty string|table ox_lib skillCheck difficulty
--- @param inputs table|nil key inputs
--- @return boolean passed
function SkillCheck(difficulty, inputs)
    return lib.skillCheck(difficulty, inputs or {'w', 'a', 's', 'd'})
end

--- Animation played when the player picks up a stock box at the pickup location
--- @return table { dict, clip, flag, duration }
function GetPickupAnimation()
    return {
        dict     = "anim@heists@ornate_bank@grab_cash",
        clip     = "grab",
        flag     = 49,
        duration = 3000,
    }
end

--- Animation played when the player drops off stock at the business
--- @return table { dict, clip, flag, duration }
function GetDropoffAnimation()
    return {
        dict     = "anim@heists@ornate_bank@grab_cash",
        clip     = "grab",
        flag     = 49,
        duration = 3000,
    }
end

--- Animation played when the player launders money at the Handler NPC
--- @return table { dict, clip, flag, duration }
function GetLaunderAnimation()
    return {
        dict     = "mp_common",
        clip     = "givetake1_a",
        flag     = 49,
        duration = 3000,
    }
end

--- Animation played when the player hands over the cash bag at the bank teller
--- @return table { dict, clip, flag, duration }
function GetDepositAnimation()
    return {
        dict     = "mp_common",
        clip     = "givetake1_a",
        flag     = 49,
        duration = 4000,
    }
end

--- Animation played during the accountant records review
--- @return table { dict, clip, flag, duration }
function GetReviewAnimation()
    return {
        dict     = "amb@world_human_clipboard@male@idle_a",
        clip     = "idle_a",
        flag     = 49,
        duration = 3000,
    }
end

--- Prop model used for the cash bag during bank deposit missions
--- @return string model name
function GetCashBagModel()
    return "prop_money_bag_01"
end

--- Prop model used for the stock box during supply missions
--- @return string model name
function GetStockBoxModel()
    return "prop_box_cardboard_02a"
end