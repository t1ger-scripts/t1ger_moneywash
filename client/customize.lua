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
