require "LostFrequencies/Config"
require "LostFrequencies/Curses"

local Config = LostFrequencies.Config
local state = {}
local lastEffectAt = 0
local playerSessions = {}
local adminCooldowns = {}
local WEATHER_STAGE_HOURS = 48

LostFrequencies.Events = LostFrequencies.Events or {
    CurseActivated = {}, CurseReminder = {}, CurseExpiring = {}, CurseEnded = {}, CurseChanged = {},
}

local function nowSeconds() return getTimestamp and getTimestamp() or os.time() end

local function options()
    local opts = Config.options()
    if opts.maximumDurationDays < opts.minimumDurationDays then
        opts.minimumDurationDays, opts.maximumDurationDays = opts.maximumDurationDays, opts.minimumDurationDays
    end
    return opts
end

local function playerName(player)
    if not player then return "" end
    local ok, value = pcall(function() return player:getUsername() end)
    return ok and tostring(value or "") or ""
end

local function isAdmin(player)
    return player and string.lower(tostring(player:getAccessLevel() or "")) == "admin" or false
end

local function save()
    if ModData and ModData.transmit then ModData.transmit(Config.dataKey) end
end

local function localDay(now, opts)
    local shifted = now + (opts.utcOffset * 3600)
    return math.floor(shifted / 86400), math.floor((shifted % 86400) / 3600)
end

local function currentBoundary(now, opts)
    local dayKey, hour = localDay(now, opts)
    if hour < opts.activationHour then dayKey = dayKey - 1 end
    return dayKey, (dayKey * 86400) - (opts.utcOffset * 3600) + (opts.activationHour * 3600)
end

local function currentCurse()
    return state.activeCurseId and LostFrequencies.Curses[state.activeCurseId] or nil
end

local function climateManager()
    local ok, manager = pcall(function() return getClimateManager() end)
    return ok and manager or nil
end

local function weatherStageFor(curse)
    if not curse or not curse.weatherStage then return nil end
    if curse.weatherStage == "storm" then return WeatherPeriod.STAGE_STORM end
    if curse.weatherStage == "tropical" then return WeatherPeriod.STAGE_TROPICAL_STORM end
    if curse.weatherStage == "blizzard" then return WeatherPeriod.STAGE_BLIZZARD end
    return nil
end

local function stopOwnedWeather(reason)
    if state.weatherOwned ~= true then return false end
    local manager = climateManager()
    if manager then
        local ok, err = pcall(function() manager:stopWeatherAndThunder() end)
        if not ok then
            print("[Cursed Frequencies] Weather release failed: " .. tostring(err))
            return false
        end
    end
    state.weatherOwned = false
    state.weatherRefreshAt = nil
    state.weatherStoppedReason = tostring(reason or "ended")
    save()
    print("[Cursed Frequencies] Released owned weather: " .. state.weatherStoppedReason)
    return true
end

local function ensureSignalWeather(force)
    local curse = currentCurse()
    if not curse or not curse.weatherStage or state.weatherSuppressed == true then
        if state.weatherOwned == true then stopOwnedWeather(state.weatherSuppressed and "admin-suppressed" or "signal-ended") end
        return false
    end
    local now = nowSeconds()
    if not force and state.weatherOwned == true and now < (tonumber(state.weatherRefreshAt) or 0) then return true end
    local manager = climateManager()
    if not manager then
        print("[Cursed Frequencies] Climate manager unavailable")
        return false
    end
    local ok, err = pcall(function()
        manager:triggerCustomWeatherStage(weatherStageFor(curse), WEATHER_STAGE_HOURS)
    end)
    if not ok then
        print("[Cursed Frequencies] Weather activation failed: " .. tostring(err))
        return false
    end
    state.weatherOwned = true
    state.weatherRefreshAt = now + (options().weatherRefreshMinutes * 60)
    save()
    print("[Cursed Frequencies] Activated " .. tostring(curse.weatherStage) .. " weather for " .. curse.id)
    return true
end

local function emit(name, payload)
    for _, callback in ipairs(LostFrequencies.Events[name] or {}) do
        local ok, err = pcall(callback, payload)
        if not ok then print("[Cursed Frequencies] Integration callback failed for " .. name .. ": " .. tostring(err)) end
    end
end

local function remainingText(now)
    local seconds = math.max(0, (tonumber(state.endsAt) or now) - now)
    return string.format("%dd %02dh %02dm", math.floor(seconds / 86400),
        math.floor((seconds % 86400) / 3600), math.floor((seconds % 3600) / 60))
end

local function relay(kind, curse)
    if not options().relayLogging then return end
    print(table.concat({
        "[LostFrequencies]", "event=" .. tostring(kind), "event_id=" .. tostring(state.eventId or ""),
        "curse_id=" .. tostring(curse and curse.id or "none"),
        "curse_name=" .. tostring(curse and curse.name or "NONE"),
        "intensity=" .. tostring(state.intensityId or "active"),
        "duration_days=" .. tostring(state.durationDays or 0),
        "starts_at=" .. tostring(state.startsAt or 0), "ends_at=" .. tostring(state.endsAt or 0),
        "description=" .. tostring(curse and curse.description or "The signal is silent."),
    }, " | "))
end

local function radio(text, deliveryKey)
    local opts = options()
    if not opts.radioBroadcasts then return false end
    state.radioDeliveries = type(state.radioDeliveries) == "table" and state.radioDeliveries or {}
    local key = tostring(deliveryKey or "")
    if key ~= "" and state.radioDeliveries[key] then return true end
    if MeeksRadio and MeeksRadio.ServerAPI and type(MeeksRadio.ServerAPI.broadcast) == "function" then
        local cleanText = string.sub(tostring(text or ""), 1, Config.maxAlertLength)
        local ok, result = pcall(MeeksRadio.ServerAPI.broadcast, opts.frequency, "emergency", cleanText, "CURSED_FREQUENCIES")
        if ok and result then
            if key ~= "" then
                state.radioDeliveries[key] = nowSeconds()
                local count = 0
                for _ in pairs(state.radioDeliveries) do count = count + 1 end
                if count > 100 then state.radioDeliveries = { [key] = nowSeconds() } end
                save()
            end
            return true
        end
        if not ok then print("[Cursed Frequencies] Radio integration error: " .. tostring(result)) end
    end
    return false
end

local function alert(text, deliveryKey)
    local deliveredToRadio = radio(text, deliveryKey)
    -- Radio Frequencies already delivers its bulletin to global chat and
    -- persistent station history. Use the native alert only as a fallback so
    -- connected servers do not show the same transmission twice.
    if options().showGlobalAlert and not deliveredToRadio then
        sendServerCommand(Config.module, "alert", { text = text })
    end
end

local function payloadFor(player)
    local curse = currentCurse()
    return {
        protocol = Config.protocolVersion, version = Config.version, isAdmin = player and isAdmin(player) or nil,
        paused = state.paused == true, curseId = curse and curse.id or nil,
        curseName = curse and curse.name or "NO ACTIVE CURSE",
        description = curse and curse.description or "The signal is currently silent.",
        intensityId = state.intensityId or "active", intensityName = state.intensityName or "ACTIVE SIGNAL",
        intensityMultiplier = tonumber(state.intensityMultiplier) or 1,
        durationDays = tonumber(state.durationDays) or 0, startsAt = tonumber(state.startsAt) or 0,
        endsAt = tonumber(state.endsAt) or 0, serverNow = nowSeconds(), frequency = options().frequency,
        eventId = state.eventId, history = state.history or {},
        environmental = curse and curse.weatherStage ~= nil or false,
        weatherStage = curse and curse.weatherStage or nil,
        weatherActive = state.weatherOwned == true,
        weatherSuppressed = state.weatherSuppressed == true,
        radioConnected = MeeksRadio and MeeksRadio.ServerAPI and type(MeeksRadio.ServerAPI.broadcast) == "function" or false,
    }
end

local function pushStatus(player)
    if player then sendServerCommand(player, Config.module, "status", payloadFor(player))
    else sendServerCommand(Config.module, "status", payloadFor(nil)) end
end

local function activationText(curse)
    return string.format("[CURSED FREQUENCIES] DAILY CURSE: %s // %s // %d IRL DAY%s. %s",
        curse.name, state.intensityName or "ACTIVE SIGNAL", tonumber(state.durationDays) or 1,
        tonumber(state.durationDays) == 1 and "" or "S", curse.description)
end

local function reminderText(curse, period)
    return string.format("[CURSED FREQUENCIES] %s SIGNAL: %s remains active // %s remaining. %s",
        string.upper(period), curse.name, remainingText(nowSeconds()), curse.description)
end

local function chooseCurse(forcedId)
    local opts = options()
    if forcedId and LostFrequencies.Curses[forcedId] and opts.curseEnabled[forcedId] ~= false then
        return LostFrequencies.Curses[forcedId]
    end
    local candidates = LostFrequencies.sortedCurses(opts.curseEnabled)
    if #candidates == 0 then return nil end
    local harmful, blessings = {}, {}
    for _, curse in ipairs(candidates) do
        if curse.kind=="blessing" then blessings[#blessings+1]=curse else harmful[#harmful+1]=curse end
    end
    local blessingRoll = ZombRand and ZombRand(100) or math.random(0,99)
    if blessingRoll < 5 and #blessings>0 then candidates=blessings elseif #harmful>0 then candidates=harmful end
    local recent = {}
    if state.activeCurseId then recent[state.activeCurseId] = true end
    for index, entry in ipairs(state.history or {}) do
        if index > 3 then break end
        recent[entry.curseId] = true
    end
    local filtered = {}
    for _, curse in ipairs(candidates) do if not recent[curse.id] then filtered[#filtered + 1] = curse end end
    if #filtered > 0 then candidates = filtered end
    local index = ZombRand and (ZombRand(#candidates) + 1) or math.random(#candidates)
    return candidates[index]
end

local function chooseDuration(opts, forcedDays)
    if forcedDays then return math.max(1, math.min(3, math.floor(tonumber(forcedDays) or 1))) end
    local span = opts.maximumDurationDays - opts.minimumDurationDays + 1
    return opts.minimumDurationDays + (ZombRand and ZombRand(span) or math.random(0, span - 1))
end

local intensities = {
    { id = "faint", name = "FAINT SIGNAL", multiplier = 0.75 },
    { id = "active", name = "ACTIVE SIGNAL", multiplier = 1.00 },
    { id = "severe", name = "SEVERE SIGNAL", multiplier = 1.25 },
}

local function chooseIntensity(opts)
    if not opts.randomIntensity then return intensities[2] end
    local index = ZombRand and (ZombRand(#intensities) + 1) or math.random(#intensities)
    return intensities[index]
end

local function archiveCurrent(reason)
    local curse = currentCurse()
    if not curse then return end
    if curse.weatherStage then stopOwnedWeather(reason or "ended") end
    state.history = type(state.history) == "table" and state.history or {}
    table.insert(state.history, 1, {
        eventId = state.eventId, curseId = curse.id, curseName = curse.name,
        intensityName = state.intensityName, durationDays = state.durationDays,
        startsAt = state.startsAt, endsAt = state.endsAt, endedAt = nowSeconds(), reason = reason,
    })
    while #state.history > 20 do table.remove(state.history) end
    emit("CurseEnded", payloadFor(nil)); relay("ended", curse)
end

local function activate(curse, startsAt, durationDays, reason)
    if not curse then print("[Cursed Frequencies] No enabled curses; rotation skipped"); return false end
    local previous = currentCurse()
    if previous then archiveCurrent(reason or "changed") end
    local opts, intensity = options(), chooseIntensity(options())
    state.sequence = math.max(0, math.floor(tonumber(state.sequence) or 0)) + 1
    state.activeCurseId = curse.id
    state.durationDays = chooseDuration(opts, durationDays)
    state.startsAt = startsAt
    state.endsAt = startsAt + (state.durationDays * 86400)
    state.intensityId, state.intensityName, state.intensityMultiplier = intensity.id, intensity.name, intensity.multiplier
    state.eventId = "lf-" .. tostring(math.floor(startsAt)) .. "-" .. tostring(state.sequence)
    local activeDay, activeHour = localDay(nowSeconds(), opts)
    state.lastMorningDay = activeHour >= opts.activationHour and activeDay or nil
    state.lastEveningDay, state.expirationWarningSent = nil, false
    state.lastReason = tostring(reason or "schedule")
    state.weatherSuppressed = false
    if curse.clearsWeather then stopOwnedWeather("beneficial-signal") end
    if curse.weatherStage then ensureSignalWeather(true) end
    save(); alert(activationText(curse), state.eventId .. ":activation"); relay("activated", curse); emit("CurseActivated", payloadFor(nil))
    if previous then emit("CurseChanged", payloadFor(nil)) end
    pushStatus(nil)
    print("[Cursed Frequencies] Activated " .. curse.id .. " for " .. state.durationDays .. " day(s) via " .. state.lastReason)
    return true
end

local function sessionFor(player, now)
    local name = string.lower(playerName(player))
    local existing = playerSessions[name]
    if not existing or existing.player ~= player then
        existing = { player = player, graceUntil = now + (options().loginGraceMinutes * 60), welcomed = false }
        playerSessions[name] = existing
    end
    return existing
end

local function applyPlayerEffect(player, curse, now)
    if not player or not curse then return end
    local session = sessionFor(player, now)
    if now < session.graceUntil or (options().adminExempt and isAdmin(player)) then return end
    if curse.outdoorOnly then
        local outside = false
        local ok = pcall(function()
            local square = player:getSquare()
            outside = square ~= nil and square:isOutside()
        end)
        if not ok or not outside then return end
    end
    local stats = player:getStats()
    if not stats then return end
    local multiplier = tonumber(state.intensityMultiplier) or 1
    local amount = (tonumber(curse.amount) or 0) * multiplier
    if curse.stat == "hunger" then stats:add(CharacterStat.HUNGER, amount)
    elseif curse.stat == "thirst" then stats:add(CharacterStat.THIRST, amount)
    elseif curse.stat == "fatigue" then stats:add(CharacterStat.FATIGUE, amount)
    elseif curse.stat == "endurance" then stats:add(CharacterStat.ENDURANCE, amount)
    elseif curse.stat == "panic" then
        stats:set(CharacterStat.PANIC, math.max(stats:get(CharacterStat.PANIC), (tonumber(curse.floor) or 0) * multiplier) + amount)
    elseif curse.stat == "pain" then stats:add(CharacterStat.PAIN, amount) end
    if curse.stat == "panic_relief" then stats:add(CharacterStat.PANIC, amount) end
end

local function forEachPlayer(callback)
    if not getOnlinePlayers then return end
    local ok, players = pcall(getOnlinePlayers)
    if not ok or not players then return end
    for index = 0, players:size() - 1 do
        local player = players:get(index)
        local applied, err = pcall(callback, player)
        if not applied then print("[Cursed Frequencies] Player operation skipped: " .. tostring(err)) end
    end
end

local function welcomePlayers(now)
    forEachPlayer(function(player)
        local session = sessionFor(player, now)
        if not session.welcomed then session.welcomed = true; pushStatus(player) end
    end)
end

local function scheduledBroadcasts(now, opts, curse)
    local dayKey, hour = localDay(now, opts)
    if hour >= opts.activationHour and state.lastMorningDay ~= dayKey then
        state.lastMorningDay = dayKey
        alert(reminderText(curse, "morning"), state.eventId .. ":morning:" .. tostring(dayKey)); relay("morning-reminder-" .. tostring(dayKey), curse)
        emit("CurseReminder", payloadFor(nil)); save()
    end
    if hour >= opts.reminderHour and state.lastEveningDay ~= dayKey then
        state.lastEveningDay = dayKey
        local expiring = (tonumber(state.endsAt) or 0) - now <= 12 * 3600
        alert(reminderText(curse, expiring and "final evening" or "evening"), state.eventId .. ":evening:" .. tostring(dayKey))
        relay(expiring and ("expiring-" .. tostring(dayKey)) or ("evening-reminder-" .. tostring(dayKey)), curse)
        emit(expiring and "CurseExpiring" or "CurseReminder", payloadFor(nil)); save()
    end
end

local function tick()
    local opts = options()
    if not opts.enabled then
        if state.weatherOwned == true then stopOwnedWeather("mod-disabled") end
        return
    end
    local now = nowSeconds()
    welcomePlayers(now)
    if currentCurse() then ensureSignalWeather(false) end
    if state.paused == true then return end
    local _, boundary = currentBoundary(now, opts)
    if not currentCurse() or now >= (tonumber(state.endsAt) or 0) then
        activate(chooseCurse(), boundary, nil, "scheduled-rotation")
    end
    local curse = currentCurse()
    if not curse then return end
    ensureSignalWeather(false)
    scheduledBroadcasts(now, opts, curse)
    if now - lastEffectAt >= Config.effectIntervalSeconds then
        lastEffectAt = now
        forEachPlayer(function(player) applyPlayerEffect(player, curse, now) end)
    end
end

local function reject(player, reason) sendServerCommand(player, Config.module, "error", { text = tostring(reason) }) end

local function onClientCommand(module, command, player, args)
    if module ~= Config.module then return end
    args = type(args) == "table" and args or {}
    if command == "hello" then
        pushStatus(player)
        if tonumber(args.protocol) ~= Config.protocolVersion then reject(player, "Cursed Frequencies client/server version mismatch") end
        return
    elseif command == "status" then pushStatus(player); return end
    if not isAdmin(player) then return reject(player, "Administrator access required") end
    local adminKey, now = string.lower(playerName(player)), nowSeconds()
    if now - (tonumber(adminCooldowns[adminKey]) or 0) < 2 then return reject(player, "Admin command cooldown is active") end
    adminCooldowns[adminKey] = now
    local opts = options(); local _, boundary = currentBoundary(nowSeconds(), opts)
    if command == "reroll" then activate(chooseCurse(), boundary, tonumber(args.durationDays), "admin-reroll:" .. playerName(player))
    elseif command == "set" then
        local id, curse = tostring(args.curseId or ""), LostFrequencies.Curses[tostring(args.curseId or "")]
        if curse and opts.curseEnabled[id] ~= false then activate(curse, boundary, tonumber(args.durationDays), "admin-set:" .. playerName(player))
        else reject(player, "Unknown or disabled curse") end
    elseif command == "remind" and currentCurse() then alert(reminderText(currentCurse(), "admin"), state.eventId .. ":admin:" .. tostring(now)); relay("admin-reminder", currentCurse())
    elseif command == "extend" and currentCurse() then state.endsAt = state.endsAt + 86400; state.durationDays = state.durationDays + 1; save(); pushStatus(nil)
    elseif command == "shorten" and currentCurse() then state.endsAt = math.max(nowSeconds() + 60, state.endsAt - 86400); state.durationDays = math.max(1, state.durationDays - 1); save(); pushStatus(nil)
    elseif command == "weather_toggle" then
        if not currentCurse() or not currentCurse().weatherStage then reject(player, "Current signal does not control weather")
        elseif state.weatherSuppressed == true then state.weatherSuppressed = false; ensureSignalWeather(true); pushStatus(nil)
        else state.weatherSuppressed = true; stopOwnedWeather("admin:" .. playerName(player)); pushStatus(nil) end
    elseif command == "pause" then state.paused = true; save(); pushStatus(nil)
    elseif command == "resume" then state.paused = false; save(); pushStatus(nil) end
end

local function initialize()
    state = ModData.getOrCreate(Config.dataKey)
    if type(state.history) ~= "table" then state.history = {} end
    if type(state.radioDeliveries) ~= "table" then state.radioDeliveries = {} end
    state.sequence = math.max(0, math.floor(tonumber(state.sequence) or 0))
    tick(); ensureSignalWeather(false); save(); print("[Cursed Frequencies] v" .. Config.version .. " initialized")
end

local function disconnect(player)
    local name = string.lower(playerName(player))
    if name ~= "" then playerSessions[name], adminCooldowns[name] = nil, nil end
end

LostFrequencies.ServerAPI = LostFrequencies.ServerAPI or {}
function LostFrequencies.ServerAPI.status() return currentCurse(), state end
function LostFrequencies.ServerAPI.addListener(eventName, callback)
    if type(callback) ~= "function" or type(LostFrequencies.Events[eventName]) ~= "table" then return false end
    table.insert(LostFrequencies.Events[eventName], callback); return true
end
function LostFrequencies.ServerAPI.reroll(source, days)
    local opts = options(); local _, boundary = currentBoundary(nowSeconds(), opts)
    return activate(chooseCurse(), boundary, days, source or "integration-reroll")
end
function LostFrequencies.ServerAPI.setCurse(curseId, source, days)
    local curse = LostFrequencies.Curses[tostring(curseId or "")]
    if not curse or options().curseEnabled[curse.id] == false then return false end
    local opts = options(); local _, boundary = currentBoundary(nowSeconds(), opts)
    return activate(curse, boundary, days, source or "integration-set")
end

Events.OnInitGlobalModData.Add(initialize)
Events.OnClientCommand.Add(onClientCommand)
if Events.EveryOneMinute then Events.EveryOneMinute.Add(tick) else Events.OnTick.Add(tick) end
if Events.OnDisconnect then Events.OnDisconnect.Add(disconnect) end
