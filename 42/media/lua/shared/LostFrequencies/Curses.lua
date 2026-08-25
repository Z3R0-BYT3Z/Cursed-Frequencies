LostFrequencies = LostFrequencies or {}

-- Rates are applied once per real-world minute. They are intentionally modest
-- and stop cleanly when the curse changes; no permanent SandboxVars are edited.
LostFrequencies.Curses = {
    hollow_stomachs = {
        id = "hollow_stomachs",
        name = "HOLLOW STOMACHS",
        description = "Hunger grows faster while the signal remains active.",
        stat = "hunger",
        amount = 0.006,
    },
    parched_earth = {
        id = "parched_earth",
        name = "PARCHED EARTH",
        description = "Thirst grows faster while the signal remains active.",
        stat = "thirst",
        amount = 0.008,
    },
    sleepless_signal = {
        id = "sleepless_signal",
        name = "SLEEPLESS SIGNAL",
        description = "Fatigue accumulates more quickly.",
        stat = "fatigue",
        amount = 0.004,
    },
    heavy_air = {
        id = "heavy_air",
        name = "HEAVY AIR",
        description = "Exertion lingers and endurance recovers less effectively.",
        stat = "endurance",
        amount = -0.025,
    },
    red_static = {
        id = "red_static",
        name = "RED STATIC",
        description = "The transmission keeps survivors uneasy and alert.",
        stat = "panic",
        amount = 4,
        floor = 25,
    },
    aching_bones = {
        id = "aching_bones",
        name = "ACHING BONES",
        description = "An unexplained ache settles into every survivor.",
        stat = "pain",
        amount = 0.015,
    },
    black_sky = {
        id="black_sky", name="BLACK SKY",
        description="A hostile storm front blankets the region in rain, fog, and violent wind.",
        stat="none", amount=0, weatherStage="storm", radioProfile="emergency",
    },
    tropical_static = {
        id="tropical_static", name="TROPICAL STATIC",
        description="A violent tropical system carries the signal across the exclusion zone.",
        stat="thirst", amount=0.003, weatherStage="tropical", radioProfile="static",
    },
    whiteout = {
        id="whiteout", name="WHITEOUT",
        description="A freezing blizzard smothers roads, landmarks, and radio reception.",
        stat="fatigue", amount=0.002, weatherStage="blizzard", radioProfile="static",
    },
    dead_air = {
        id="dead_air", name="DEAD AIR",
        description="Only fragments and distant voices remain on the emergency frequency.",
        stat="fatigue", amount=0.0025, radioProfile="ghost",
    },
    clear_signal = { id="clear_signal", name="CLEAR SIGNAL", description="The hostile carrier wave has briefly fallen silent.", stat="none", amount=0, kind="blessing" },
    second_wind = { id="second_wind", name="SECOND WIND", description="The signal eases fatigue instead of feeding it.", stat="fatigue", amount=-0.003, kind="blessing" },
    quiet_frequency = { id="quiet_frequency", name="QUIET FREQUENCY", description="The static suppresses panic and steadies the mind.", stat="panic_relief", amount=-4, kind="blessing" },
    eye_of_the_storm = { id="eye_of_the_storm", name="EYE OF THE STORM", description="The carrier wave collapses and the imposed weather releases its grip.", stat="endurance", amount=0.015, kind="blessing", clearsWeather=true, radioProfile="clear" },
}

function LostFrequencies.sortedCurses(enabled)
    local result = {}
    for id, curse in pairs(LostFrequencies.Curses) do
        if not enabled or enabled[id] ~= false then result[#result + 1] = curse end
    end
    table.sort(result, function(a, b) return a.id < b.id end)
    return result
end
