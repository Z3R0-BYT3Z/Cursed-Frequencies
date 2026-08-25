require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISScrollingListBox"
require "LostFrequencies/Config"
require "LostFrequencies/Curses"

local Config = LostFrequencies.Config
local panel, status = nil, nil
local statusReceivedAt = 0
local protocolCompatible = false
local helloAttempts, helloTicks = 0, 0

local C = {
    bg = {r=0.020,g=0.020,b=0.026,a=0.98}, panel = {r=0.040,g=0.040,b=0.050,a=0.97},
    line = {r=0.18,g=0.18,b=0.22,a=0.90}, accent = {r=1.00,g=0.05,b=0.55,a=1},
    text = {r=0.92,g=0.92,b=0.95,a=1}, muted = {r=0.58,g=0.59,b=0.64,a=1},
    button = {r=0.038,g=0.038,b=0.048,a=0.96}, hover = {r=1.00,g=0.05,b=0.55,a=0.14},
}

local TAB_CURRENT, TAB_CURSES, TAB_HISTORY, TAB_ADMIN = "current", "curses", "history", "admin"

local function nowSeconds() return getTimestamp and getTimestamp() or os.time() end

local function clean(value)
    local text = string.gsub(tostring(value or ""), "[%c]", " ")
    return string.sub(text, 1, Config.maxAlertLength)
end

local function remaining()
    if not status then return "UNKNOWN" end
    local serverNow = tonumber(status.serverNow) or nowSeconds()
    local elapsed = math.max(0, nowSeconds() - statusReceivedAt)
    local seconds = math.max(0, (tonumber(status.endsAt) or 0) - (serverNow + elapsed))
    return string.format("%dd %02dh %02dm", math.floor(seconds/86400),
        math.floor((seconds%86400)/3600), math.floor((seconds%3600)/60))
end

local function addButton(self, x, y, w, label, callback)
    local button = ISButton:new(x, y, w, 30, label, self, callback)
    button:initialise(); button.font = UIFont.Small
    button.backgroundColor = C.button; button.backgroundColorMouseOver = C.hover
    button.borderColor = C.line; button.textColor = C.text
    self:addChild(button); return button
end

local function drawListItem(list, y, item, alt)
    local selected = list.selected == item.index
    local fill = selected and {0.23,0.07,0.16,0.95} or (alt and {0.065,0.058,0.07,0.95} or {0.045,0.040,0.05,0.95})
    list:drawRect(0,y,list:getWidth(),list.itemheight,fill[4],fill[1],fill[2],fill[3])
    if selected then list:drawRect(0,y,3,list.itemheight,1,C.accent.r,C.accent.g,C.accent.b) end
    list:drawText(tostring(item.text or ""),10,y+7,C.text.r,C.text.g,C.text.b,1,UIFont.Small)
    return y + list.itemheight
end


local CurseIndicator = ISPanel:derive("CursedFrequenciesStatusIndicator")
local curseIndicator = nil
local INDICATOR_SIZE = 64
local INDICATOR_RIGHT_OFFSET = 144
local INDICATOR_TOP = 118

local function harmfulSignalActive()
    if not protocolCompatible or type(status) ~= "table" or not status.curseId then return false end
    local curse = LostFrequencies.Curses[status.curseId]
    return curse ~= nil and curse.kind ~= "blessing" and (curse.stat ~= "none" or curse.weatherStage ~= nil)
end

function CurseIndicator:new()
    local sw = getCore():getScreenWidth()
    -- Vanilla moodles occupy the far-right HUD column. Keep this indicator in
    -- its own adjacent slot so hover targets and tooltip bars cannot overlap.
    local o = ISPanel.new(self, math.max(8, sw - INDICATOR_RIGHT_OFFSET),
        INDICATOR_TOP, INDICATOR_SIZE, INDICATOR_SIZE)
    o.backgroundColor = {r=0,g=0,b=0,a=0.00}
    o.borderColor = {r=0,g=0,b=0,a=0.00}
    o.moveWithMouse = false
    o.icon = getTexture("media/ui/CursedFrequencies/CursedFrequencyMoodle.png")
    return o
end

function CurseIndicator:prerender()
    self:setX(math.max(8, getCore():getScreenWidth() - INDICATOR_RIGHT_OFFSET))
    self:setY(INDICATOR_TOP)
    ISPanel.prerender(self)
    local intensity = tostring(status and status.intensityId or "active")
    local alpha = intensity == "faint" and 0.55 or 1.0
    if self.icon then
        -- Match the 64x64 vanilla moodle footprint. The previous 48x48 draw
        -- inside a 56px panel made this icon visibly smaller and shifted it
        -- four pixels down/right from the adjacent vanilla moodle.
        self:drawTextureScaled(self.icon,0,0,64,64,alpha,1,1,1)
    else
        self:drawTextCentre("CF",self.width/2,18,C.accent.r,C.accent.g,C.accent.b,1,UIFont.Medium)
    end
end

function CurseIndicator:render()
    ISPanel.render(self)
    if self:isMouseOver() and status then
        local label = tostring(status.curseName or "CURSED SIGNAL") .. " // " ..
            tostring(status.intensityName or "ACTIVE") .. " // " .. remaining()
        local width = math.max(250, getTextManager():MeasureStringX(UIFont.Small,label)+20)
        self:drawRect(-width-8,4,width,42,0.96,C.bg.r,C.bg.g,C.bg.b)
        self:drawText(label,-width+2,16,C.text.r,C.text.g,C.text.b,1,UIFont.Small)
    end
end

local function refreshCurseIndicator()
    if harmfulSignalActive() then
        if not curseIndicator then
            curseIndicator = CurseIndicator:new()
            curseIndicator:initialise()
            curseIndicator:addToUIManager()
        end
        curseIndicator:setVisible(true)
    elseif curseIndicator then
        curseIndicator:removeFromUIManager()
        curseIndicator = nil
    end
end

local function clearCurseIndicator()
    if curseIndicator then curseIndicator:removeFromUIManager(); curseIndicator=nil end
end
local CursePanel = ISPanel:derive("LostFrequenciesCommandCenter")

function CursePanel:new()
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    local w, h = math.min(520, sw-24), math.min(600, sh-24)
    local o = ISPanel.new(self, math.max(0,(sw-w)/2), math.max(0,(sh-h)/2), w, h)
    o.moveWithMouse = true; o.backgroundColor = C.bg; o.borderColor = C.line
    o.durationDays = 1; o.activeTab = TAB_CURRENT
    return o
end

function CursePanel:createChildren()
    ISPanel.createChildren(self)
    self.closeTop = addButton(self,self.width-44,10,28,"X",self.close)
    self.closeBottom = addButton(self,self.width-138,self.height-40,120,"CLOSE",self.close)
    self.refreshButton = addButton(self,18,self.height-40,110,"REFRESH",self.onRefresh)

    self.currentTabButton = addButton(self,16,70,117,"CURRENT",self.onCurrentTab)
    self.cursesTabButton = addButton(self,139,70,117,"CURSES",self.onCursesTab)
    self.historyTabButton = addButton(self,262,70,117,"HISTORY",self.onHistoryTab)
    self.adminTabButton = addButton(self,385,70,117,"ADMIN",self.onAdminTab)

    self.curseList = ISScrollingListBox:new(24,154,self.width-48,154)
    self.curseList:initialise(); self.curseList.itemheight=30; self.curseList.doDrawItem=drawListItem
    self.curseList.backgroundColor=C.panel; self.curseList.borderColor=C.line; self:addChild(self.curseList)
    for _, curse in ipairs(LostFrequencies.sortedCurses()) do self.curseList:addItem(curse.name, curse) end

    self.historyList = ISScrollingListBox:new(24,154,self.width-48,self.height-244)
    self.historyList:initialise(); self.historyList.itemheight=36; self.historyList.doDrawItem=drawListItem
    self.historyList.backgroundColor=C.panel; self.historyList.borderColor=C.line; self:addChild(self.historyList)

    local x, gap = 24, 8
    local buttonWidth = math.floor((self.width-56)/2)
    self.rerollButton=addButton(self,x,346,buttonWidth,"REROLL",self.onReroll)
    self.setButton=addButton(self,x+buttonWidth+gap,346,buttonWidth,"SET SELECTED",self.onSet)
    self.durationButton=addButton(self,x,382,buttonWidth,"DURATION: 1D",self.onDuration)
    self.remindButton=addButton(self,x+buttonWidth+gap,382,buttonWidth,"SEND REMINDER",self.onRemind)
    self.extendButton=addButton(self,x,418,buttonWidth,"EXTEND +1 DAY",self.onExtend)
    self.shortenButton=addButton(self,x+buttonWidth+gap,418,buttonWidth,"SHORTEN -1 DAY",self.onShorten)
    self.pauseButton=addButton(self,x,454,self.width-48,"PAUSE ROTATION",self.onPause)
    self.weatherButton=addButton(self,x,490,self.width-48,"WEATHER: AUTOMATIC",self.onWeatherToggle)
    self:updateHistory(); self:updateTabVisibility()
end

function CursePanel:updateHistory()
    if not self.historyList then return end
    self.historyList:clear()
    for _, entry in ipairs(status and status.history or {}) do
        local label = tostring(entry.curseName or "UNKNOWN") .. " // " .. tostring(entry.intensityName or "UNKNOWN") .. " // " .. tostring(entry.durationDays or 0) .. "D"
        self.historyList:addItem(label, entry)
    end
end

function CursePanel:updateTabVisibility()
    local isAdmin = status and status.isAdmin == true
    if (self.activeTab == TAB_ADMIN or self.activeTab == TAB_HISTORY) and not isAdmin then
        self.activeTab = TAB_CURRENT
    end

    self.historyTabButton:setVisible(true)
    self.adminTabButton:setVisible(true)
    self.historyTabButton.textColor = isAdmin and C.text or C.muted
    self.adminTabButton.textColor = isAdmin and C.text or C.muted

    self.curseList:setVisible(self.activeTab == TAB_CURSES or (self.activeTab == TAB_ADMIN and isAdmin))
    self.historyList:setVisible(self.activeTab == TAB_HISTORY and isAdmin)
    local adminVisible = self.activeTab == TAB_ADMIN and isAdmin
    for _, control in ipairs({self.rerollButton,self.setButton,self.durationButton,self.remindButton,
        self.extendButton,self.shortenButton,self.pauseButton,self.weatherButton}) do control:setVisible(adminVisible) end
end

function CursePanel:adminAccessRequired()
    local player = getPlayer and getPlayer() or nil
    local message = "ADMINISTRATOR ACCESS REQUIRED"
    print("[Cursed Frequencies] " .. message)
    if player and HaloTextHelper and HaloTextHelper.addText then
        HaloTextHelper.addText(player,message)
    end
end

function CursePanel:setTab(tab) self.activeTab=tab; self:updateTabVisibility() end
function CursePanel:onCurrentTab() self:setTab(TAB_CURRENT) end
function CursePanel:onCursesTab() self:setTab(TAB_CURSES) end
function CursePanel:onHistoryTab()
    if status and status.isAdmin == true then
        self:setTab(TAB_HISTORY)
    else
        self:adminAccessRequired()
    end
end
function CursePanel:onAdminTab()
    if status and status.isAdmin == true then
        self:setTab(TAB_ADMIN)
    else
        self:adminAccessRequired()
    end
end

function CursePanel:prerender()
    ISPanel.prerender(self)
    self:drawRect(0,0,self.width,62,1,C.panel.r,C.panel.g,C.panel.b)
    self:drawRect(0,61,self.width,1,1,C.line.r,C.line.g,C.line.b)
    self:drawRect(16,62,self.width-32,1,0.80,C.accent.r,C.accent.g,C.accent.b)
    self:drawRect(24,116,self.width-48,1,0.55,C.accent.r,C.accent.g,C.accent.b)
    self:drawRect(16,self.height-80,self.width-32,1,0.45,C.accent.r,C.accent.g,C.accent.b)
    self:drawText("CURSED FREQUENCIES",22,12,C.text.r,C.text.g,C.text.b,1,UIFont.Medium)
    self:drawText(protocolCompatible and "STATUS: ONLINE" or "STATUS: CONNECTING",22,36,
        protocolCompatible and 0.25 or 0.92,protocolCompatible and 0.85 or 0.50,protocolCompatible and 0.48 or 0.25,1,UIFont.Small)
    self:drawText("FREQUENCY " .. string.format("%.1f MHz",((status and status.frequency) or 102800)/1000),224,36,C.muted.r,C.muted.g,C.muted.b,1,UIFont.Small)
    self:drawText("BUILD 42",self.width-160,15,C.muted.r,C.muted.g,C.muted.b,1,UIFont.Small)

    local name = status and status.curseName or "CONNECTING..."
    local description = status and status.description or "Requesting the current transmission from the server."
    local descriptionLine1, descriptionLine2 = description, ""
    if #description > 38 then
        local split = description:sub(1,38):match(".*()%s") or 38
        descriptionLine1 = description:sub(1,split-1)
        descriptionLine2 = description:sub(split+1)
    end

    if self.activeTab == TAB_CURRENT then
        self:drawRect(24,122,self.width-48,self.height-220,0.95,C.panel.r,C.panel.g,C.panel.b)
        self:drawRectBorder(24,122,self.width-48,self.height-220,1,C.line.r,C.line.g,C.line.b)
        self:drawText("ACTIVE TRANSMISSION",44,138,C.muted.r,C.muted.g,C.muted.b,1,UIFont.Small)
        self:drawText(name,44,162,C.text.r,C.text.g,C.text.b,1,UIFont.Large)
        self:drawText(descriptionLine1,44,194,C.muted.r,C.muted.g,C.muted.b,1,UIFont.Small)
        self:drawText(descriptionLine2,44,216,C.muted.r,C.muted.g,C.muted.b,1,UIFont.Small)
        self:drawText("SIGNAL INTENSITY",44,246,C.muted.r,C.muted.g,C.muted.b,1,UIFont.Small)
        self:drawText(tostring(status and status.intensityName or "UNKNOWN"),44,270,C.accent.r,C.accent.g,C.accent.b,1,UIFont.Medium)
        self:drawText("TIME REMAINING",math.floor(self.width*0.53),246,C.muted.r,C.muted.g,C.muted.b,1,UIFont.Small)
        self:drawText(remaining(),math.floor(self.width*0.53),270,C.text.r,C.text.g,C.text.b,1,UIFont.Medium)
        self:drawText("DURATION",44,304,C.muted.r,C.muted.g,C.muted.b,1,UIFont.Small)
        self:drawText(tostring(status and status.durationDays or 0).." IRL DAY(S)",44,328,C.text.r,C.text.g,C.text.b,1,UIFont.Medium)
        self:drawText("ROTATION",math.floor(self.width*0.53),304,C.muted.r,C.muted.g,C.muted.b,1,UIFont.Small)
        self:drawText(tostring(status and status.paused and "PAUSED" or "ACTIVE"),math.floor(self.width*0.53),328,
            status and status.paused and 0.95 or 0.35,status and status.paused and 0.45 or 0.82,0.45,1,UIFont.Medium)
        self:drawText("EVENT ID: "..tostring(status and status.eventId or "pending"),44,378,C.muted.r,C.muted.g,C.muted.b,1,UIFont.Small)
        local weatherText = status and status.environmental and
            (status.weatherSuppressed and "SUPPRESSED" or (status.weatherActive and string.upper(tostring(status.weatherStage or "ACTIVE")) or "PENDING")) or "NOT WEATHER-BASED"
        self:drawText("WEATHER: " .. weatherText,44,410,C.muted.r,C.muted.g,C.muted.b,1,UIFont.Small)
        self:drawText("RADIO: " .. (status and status.radioConnected and "CONNECTED" or "OPTIONAL / OFFLINE"),44,434,C.muted.r,C.muted.g,C.muted.b,1,UIFont.Small)
    elseif self.activeTab == TAB_CURSES then
        self:drawText("AVAILABLE SIGNALS",24,118,C.muted.r,C.muted.g,C.muted.b,1,UIFont.Small)
        local selected=self.curseList.items[self.curseList.selected]
        local curse=selected and selected.item or nil
        local x=24
        self:drawText("SIGNAL PROFILE",x,330,C.muted.r,C.muted.g,C.muted.b,1,UIFont.Small)
        self:drawText(curse and curse.name or "SELECT A SIGNAL",x,356,C.text.r,C.text.g,C.text.b,1,UIFont.Large)
        local profileText = curse and curse.description or "Choose an entry to review its effect."
        local profileLine1, profileLine2 = profileText, ""
        if #profileText > 42 then
            local split = profileText:sub(1,42):match(".*()%s") or 42
            profileLine1 = profileText:sub(1,split-1)
            profileLine2 = profileText:sub(split+1)
        end
        self:drawText(profileLine1,x,392,C.muted.r,C.muted.g,C.muted.b,1,UIFont.Small)
        self:drawText(profileLine2,x,414,C.muted.r,C.muted.g,C.muted.b,1,UIFont.Small)
    elseif self.activeTab == TAB_HISTORY then
        self:drawText("PREVIOUS 20 TRANSMISSIONS",24,118,C.muted.r,C.muted.g,C.muted.b,1,UIFont.Small)
        if not status or #(status.history or {}) == 0 then self:drawText("No archived signals yet.",48,180,C.muted.r,C.muted.g,C.muted.b,1,UIFont.Medium) end
    elseif self.activeTab == TAB_ADMIN then
        self:drawText("SELECT SIGNAL",24,118,C.muted.r,C.muted.g,C.muted.b,1,UIFont.Small)
        self:drawText("SERVER-AUTHORIZED CONTROLS",24,324,C.muted.r,C.muted.g,C.muted.b,1,UIFont.Small)
        self:drawText("Weather controls apply only to environmental signals.",24,466,C.muted.r,C.muted.g,C.muted.b,1,UIFont.Small)
    end

    self:drawText(protocolCompatible and "SERVER SYNC: ONLINE" or "SERVER SYNC: CHECKING",18,self.height-64,
        protocolCompatible and 0.35 or 0.9,protocolCompatible and 0.8 or 0.45,protocolCompatible and 0.5 or 0.3,1,UIFont.Small)
    self:drawText("F8 / X TO CLOSE",self.width-172,self.height-64,C.muted.r,C.muted.g,C.muted.b,1,UIFont.Small)
end

function CursePanel:close() self:setVisible(false); self:removeFromUIManager(); panel=nil end
function CursePanel:onRefresh() sendClientCommand(Config.module,"status",{}) end
function CursePanel:onDuration()
    self.durationDays=(self.durationDays%3)+1
    self.durationButton:setTitle("DURATION: "..self.durationDays.."D")
end
function CursePanel:onReroll() sendClientCommand(Config.module,"reroll",{durationDays=self.durationDays}) end
function CursePanel:onSet()
    local item=self.curseList.items[self.curseList.selected]
    if item and item.item then sendClientCommand(Config.module,"set",{curseId=item.item.id,durationDays=self.durationDays}) end
end
function CursePanel:onRemind() sendClientCommand(Config.module,"remind",{}) end
function CursePanel:onExtend() sendClientCommand(Config.module,"extend",{}) end
function CursePanel:onShorten() sendClientCommand(Config.module,"shorten",{}) end
function CursePanel:onPause() sendClientCommand(Config.module,status and status.paused and "resume" or "pause",{}) end
function CursePanel:onWeatherToggle() sendClientCommand(Config.module,"weather_toggle",{}) end

local function openPanel()
    if panel then panel:close(); return end
    sendClientCommand(Config.module,"status",{})
    panel=CursePanel:new(); panel:initialise(); panel:addToUIManager()
end

local function showServerChatMessage(message)
    local displayed=false
    pcall(function()
        local chatClass=ChatManager
        if not chatClass and luajava and luajava.bindClass then
            chatClass=luajava.bindClass("zombie.chat.ChatManager")
        end
        local chat=chatClass and chatClass.getInstance and chatClass.getInstance()
        if chat and (not chat.isWorking or chat:isWorking()) then
            chat:showServerChatMessage(message)
            displayed=true
        end
    end)
    return displayed
end

local function showAlert(args)
    if type(args) ~= "table" then return end
    local text = clean(args.text); if text == "" then return end
    print("[Cursed Frequencies] " .. text)
    showServerChatMessage(text)
    local player = getPlayer and getPlayer() or nil
    if Config.options().showOverheadAlerts and player and HaloTextHelper and HaloTextHelper.addText then
        HaloTextHelper.addText(player,text)
    end
end

local function onServerCommand(module, command, args)
    if module ~= Config.module then return end
    if command == "alert" or command == "error" then showAlert(args)
    elseif command == "status" and type(args)=="table" then
        if args.isAdmin == nil and status then args.isAdmin = status.isAdmin end
        status=args; statusReceivedAt=nowSeconds(); protocolCompatible=tonumber(args.protocol)==Config.protocolVersion
        SurvivorLeagueCommunity = SurvivorLeagueCommunity or {}
        SurvivorLeagueCommunity.LostFrequenciesStatus = status
        if panel then
            if panel.pauseButton then panel.pauseButton:setTitle(status.paused and "RESUME ROTATION" or "PAUSE ROTATION") end
            if panel.weatherButton then panel.weatherButton:setTitle(status.weatherSuppressed and "WEATHER: RESTORE" or "WEATHER: STOP") end
            panel:updateHistory(); panel:updateTabVisibility()
        end
        refreshCurseIndicator()
    end
end

local function hello()
    helloAttempts=helloAttempts+1
    sendClientCommand(Config.module,"hello",{protocol=Config.protocolVersion,version=Config.version})
end

local function beginHello()
    protocolCompatible=false; helloAttempts=0; helloTicks=0; clearCurseIndicator(); hello()
end

local function retryHello()
    if protocolCompatible or helloAttempts>=10 then return end
    helloTicks=helloTicks+1
    if helloTicks>=60 then helloTicks=0; hello() end
end

local function onKeyPressed(key)
    if tonumber(key)==Config.options().interfaceKey then openPanel() end
end

Events.OnServerCommand.Add(onServerCommand)
Events.OnKeyPressed.Add(onKeyPressed)
if Events.OnCreatePlayer then Events.OnCreatePlayer.Add(beginHello) end
if Events.OnPlayerUpdate then Events.OnPlayerUpdate.Add(retryHello) end
