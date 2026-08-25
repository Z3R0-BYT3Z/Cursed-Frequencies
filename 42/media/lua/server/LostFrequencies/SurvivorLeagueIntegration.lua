require "LostFrequencies/Server"

local KEY = "LostFrequenciesProfiles"
local profiles, live = {}, {}

local function now() return getTimestamp and getTimestamp() or os.time() end
local function nameOf(player)
    local ok, value = pcall(function() return player:getUsername() end)
    return ok and string.lower(tostring(value or "")) or ""
end
local function data()
    profiles = ModData.getOrCreate(KEY)
    profiles.players = type(profiles.players)=="table" and profiles.players or {}
    profiles.events = type(profiles.events)=="table" and profiles.events or {}
    return profiles
end
local function active()
    local curse, state = LostFrequencies.ServerAPI.status()
    return curse, state, state and state.eventId and tostring(state.eventId) or nil
end
local function recordFor(player, eventId)
    local d, key = data(), nameOf(player)
    if key=="" then return nil,nil end
    d.players[key] = type(d.players[key])=="table" and d.players[key] or {experienced=0,survived=0,deaths=0,severeSurvived=0,badges={}}
    d.events[eventId] = type(d.events[eventId])=="table" and d.events[eventId] or {players={},kills=0,deaths=0,exposed=0}
    local event = d.events[eventId]
    if not event.players[key] then event.players[key]={seconds=0,kills=0,deaths=0,qualified=false}; event.exposed=event.exposed+1 end
    return d.players[key],event.players[key],event
end
local function tick()
    local curse,state,eventId=active(); if not curse or not eventId or state.paused then return end
    local players=getOnlinePlayers and getOnlinePlayers() or nil; if not players then return end
    for i=0,players:size()-1 do
        local player=players:get(i); local profile,entry,event=recordFor(player,eventId)
        if profile then
            entry.seconds=entry.seconds+60
            local kills=math.max(0,math.floor(tonumber(player:getZombieKills()) or 0))
            local session=live[nameOf(player)] or {kills=kills,eventId=eventId}
            if session.eventId~=eventId then session={kills=kills,eventId=eventId} end
            local delta=math.max(0,kills-session.kills); entry.kills=entry.kills+delta; event.kills=event.kills+delta; session.kills=kills
            live[nameOf(player)]=session
            if entry.seconds>=1800 then entry.qualified=true end
        end
    end
    ModData.transmit(KEY)
end
local function died(player)
    local _,_,eventId=active(); if not eventId or not player then return end
    local profile,entry,event=recordFor(player,eventId)
    if profile then profile.deaths=profile.deaths+1; entry.deaths=entry.deaths+1; event.deaths=event.deaths+1; ModData.transmit(KEY) end
end
local function ended(payload)
    local eventId=tostring(payload and payload.eventId or ""); local event=data().events[eventId]; if not event then return end
    local survivors=0
    for key,entry in pairs(event.players) do
        local profile=data().players[key]
        profile.experienced=profile.experienced+1
        if entry.qualified and entry.deaths==0 then
            profile.survived=profile.survived+1; survivors=survivors+1; profile.badges.signal_survivor=true
            if tostring(payload.intensityId)=="severe" then profile.severeSurvived=profile.severeSurvived+1; profile.badges.severe_signal=true end
            if tonumber(payload.durationDays)==3 then profile.badges.three_days_in_static=true end
            if profile.survived>=5 then profile.badges.frequency_resistant=true end
            if profile.survived>=10 then profile.badges.static_proof=true end
        end
    end
    event.survivors=survivors; event.endedAt=now(); ModData.transmit(KEY)
    print("[LostFrequenciesStats] | event=summary | event_id="..eventId.." | exposed="..tostring(event.exposed).." | deaths="..tostring(event.deaths).." | kills="..tostring(event.kills).." | survivors="..tostring(survivors))
end

LostFrequencies.ServerAPI.getPlayerProfile=function(username) return data().players[string.lower(tostring(username or ""))] end
LostFrequencies.ServerAPI.getEventStats=function(eventId) return data().events[tostring(eventId or "")] end
LostFrequencies.ServerAPI.getIntegrationHealth=function()
    return {survivorLeague=SurvivorLeagueCommunity~=nil,radio=MeeksRadio and MeeksRadio.ServerAPI~=nil,profiles=true,safeMode=true,version="0.5.2"}
end
SurvivorLeagueCommunity = SurvivorLeagueCommunity or {}
SurvivorLeagueCommunity.LostFrequenciesAPI = LostFrequencies.ServerAPI

Events.OnInitGlobalModData.Add(data)
if Events.EveryOneMinute then Events.EveryOneMinute.Add(tick) end
if Events.OnPlayerDeath then Events.OnPlayerDeath.Add(died) end
LostFrequencies.ServerAPI.addListener("CurseEnded",ended)
