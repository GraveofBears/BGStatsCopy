-- BGStatsCopy.lua
local addonName = "BGStatsCopy"

-- Create main frame
local copyFrame = CreateFrame("Frame", "BGStatsCopyFrame", UIParent)
copyFrame:SetSize(500, 400)
copyFrame:SetPoint("CENTER")
copyFrame:SetFrameStrata("FULLSCREEN_DIALOG")
copyFrame:SetMovable(true)
copyFrame:EnableMouse(true)
copyFrame:RegisterForDrag("LeftButton")
copyFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
copyFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
copyFrame:Hide()

-- Background
local bg = copyFrame:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(0, 0, 0, 0.85)

-- Border
local border = copyFrame:CreateTexture(nil, "BORDER")
border:SetColorTexture(0.2, 0.2, 0.2, 0.9)
border:SetPoint("TOPLEFT", -2, 2)
border:SetPoint("BOTTOMRIGHT", 2, -2)

-- Title
local title = copyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -10)
title:SetText("Copy Battleground Stats")

-- Instruction text
local instruction = copyFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
instruction:SetPoint("TOP", title, "BOTTOM", 0, -5)
instruction:SetText("|cffffcc00Press Ctrl+C to copy, then ESC to close|r")
instruction:SetJustifyH("CENTER")

-- Close button
local closeBtn = CreateFrame("Button", nil, copyFrame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -5, -5)
closeBtn:SetScript("OnClick", function() copyFrame:Hide() end)

-- Scroll frame
local scrollFrame = CreateFrame("ScrollFrame", nil, copyFrame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 10, -50)
scrollFrame:SetPoint("BOTTOMRIGHT", -30, 40)

-- Edit box
local editBox = CreateFrame("EditBox", nil, scrollFrame)
editBox:SetSize(450, 320)
editBox:SetMultiLine(true)
editBox:SetAutoFocus(true)
editBox:SetFontObject(ChatFontNormal)
editBox:SetMaxLetters(0)
editBox:EnableKeyboard(true)
editBox:EnableMouse(true)
editBox:SetScript("OnEscapePressed", function() 
    copyFrame:Hide() 
end)
-- Keep focus when clicking inside
editBox:SetScript("OnMouseDown", function(self)
    self:SetFocus()
end)
scrollFrame:SetScrollChild(editBox)

-- Copy button
local copyBtn = CreateFrame("Button", nil, copyFrame, "UIPanelButtonTemplate")
copyBtn:SetSize(120, 25)
copyBtn:SetPoint("BOTTOM", 0, 10)
copyBtn:SetText("Re-select Text")
copyBtn:SetScript("OnClick", function()
    editBox:SetFocus()
    editBox:HighlightText(0)
    print("|cff00ff00Text re-selected!|r Press |cffffcc00Ctrl+C|r to copy")
end)

-- Copy button on scoreboard
local copyButton = CreateFrame("Button", "BGStatsCopyButton", UIParent, "UIPanelButtonTemplate")
copyButton:SetSize(100, 25)
copyButton:SetText("Copy Stats")
copyButton:Hide()

-- Extract stats function
local function ExtractBGStats()
    local output = {}
    
    -- Check if in BG
    local inInstance, instanceType = IsInInstance()
    print("|cff00ff00BGStatsCopy Debug:|r inInstance=" .. tostring(inInstance) .. ", type=" .. tostring(instanceType))
    
    if not inInstance or (instanceType ~= "pvp" and instanceType ~= "arena") then
        table.insert(output, "ERROR: Not in a battleground or arena")
        return table.concat(output, "\n")
    end
    
    -- Get battleground/map name
    local mapName = GetZoneText() or "Unknown Battleground"
    local dateTime = date("%Y-%m-%d %H:%M:%S")
    
    -- Request score update
    RequestBattlefieldScoreData()
    
    -- Get number of players
    local numScores = GetNumBattlefieldScores()
    print("|cff00ff00BGStatsCopy Debug:|r numScores=" .. numScores)
    
    if numScores == 0 then
        table.insert(output, "ERROR: No score data available")
        table.insert(output, "Make sure the scoreboard is open (Press H)")
        return table.concat(output, "\n")
    end
    
    -- Add metadata at top (these won't be part of the sortable table)
    table.insert(output, "Map:\t" .. mapName)
    table.insert(output, "Date:\t" .. dateTime)
    table.insert(output, "")
    
    -- Collect player data
    local allPlayers = {}
    
    for i = 1, numScores do
        local name, killingBlows, honorableKills, deaths, honorGained, faction, 
              race, class, classToken, damageDone, healingDone = GetBattlefieldScore(i)
        
        if name then
            table.insert(allPlayers, {
                team = faction == 0 and "Horde" or "Alliance",
                name = name,
                class = class or "Unknown",
                kb = killingBlows or 0,
                hk = honorableKills or 0,
                deaths = deaths or 0,
                honor = honorGained or 0,
                damage = damageDone or 0,
                healing = healingDone or 0
            })
        end
    end
    
    -- Create header row
    table.insert(output, "Team\tName\tClass\tKilling Blows\tHonorable Kills\tDeaths\tHonor\tDamage\tHealing")
    
    -- Add all player data
    for _, p in ipairs(allPlayers) do
        table.insert(output, string.format("%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d",
            p.team, p.name, p.class, p.kb, p.hk, p.deaths, p.honor, p.damage, p.healing))
    end
    
    return table.concat(output, "\n")
end

-- Show stats function
local function ShowStats()
    RequestBattlefieldScoreData()
    C_Timer.After(0.2, function()
        local stats = ExtractBGStats()
        editBox:SetText(stats)
        editBox:SetCursorPosition(0)
        copyFrame:Show()
        -- Immediately highlight and focus
        editBox:HighlightText()
        editBox:SetFocus()
        -- Print instruction
        print("|cff00ff00BGStatsCopy:|r Text selected! Press |cffffcc00Ctrl+C|r to copy")
    end)
end

-- Copy button click
copyButton:SetScript("OnClick", function()
    print("|cff00ff00BGStatsCopy:|r Button clicked!")
    ShowStats()
end)

-- Position copy button on scoreboard
local function PositionCopyButton()
    -- Try modern scoreboard first
    if PVPMatchScoreboard and PVPMatchScoreboard:IsShown() then
        copyButton:SetParent(PVPMatchScoreboard)
        copyButton:ClearAllPoints()
        copyButton:SetPoint("BOTTOMRIGHT", PVPMatchScoreboard, "BOTTOMRIGHT", -10, 10)
        copyButton:Show()
        return true
    end
    
    -- Try classic scoreboard
    if WorldStateScoreFrame and WorldStateScoreFrame:IsShown() then
        copyButton:SetParent(WorldStateScoreFrame)
        copyButton:ClearAllPoints()
        copyButton:SetPoint("BOTTOMRIGHT", WorldStateScoreFrame, "BOTTOMRIGHT", -10, 10)
        copyButton:Show()
        return true
    end
    
    -- Try end of match screen
    if PVPMatchResults and PVPMatchResults:IsShown() then
        copyButton:SetParent(PVPMatchResults)
        copyButton:ClearAllPoints()
        copyButton:SetPoint("BOTTOMRIGHT", PVPMatchResults, "BOTTOMRIGHT", -10, 10)
        copyButton:Show()
        return true
    end
    
    copyButton:Hide()
    return false
end

-- Event frame
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PVP_MATCH_COMPLETE")
events:RegisterEvent("PVP_MATCH_ACTIVE")

events:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        print("|cff00ff00BGStatsCopy|r loaded! Use |cffffcc00/bgcopy|r to copy stats")
    elseif event == "UPDATE_BATTLEFIELD_SCORE" or event == "PVP_MATCH_COMPLETE" or event == "PVP_MATCH_ACTIVE" then
        C_Timer.After(0.3, PositionCopyButton)
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1, PositionCopyButton)
    end
end)

-- Slash command
SLASH_BGSTATSCOPY1 = "/bgcopy"
SlashCmdList["BGSTATSCOPY"] = ShowStats

-- Hook scoreboard if it exists
if PVPMatchScoreboard then
    hooksecurefunc(PVPMatchScoreboard, "Show", function()
        C_Timer.After(0.5, PositionCopyButton)
    end)
end

-- Hook match results screen
if PVPMatchResults then
    hooksecurefunc(PVPMatchResults, "Show", function()
        C_Timer.After(0.5, PositionCopyButton)
    end)
end