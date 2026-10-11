-- Master List grouped by expansion and sorted alphabetically
local ADDON_VERSION = "2.1"

local EXPANSIONS = {
    {
        name = "--- Cataclysm Dungeons ---",
        dungeons = {
            "Lost City of the Tol'vir",
            "The Stonecore"
        }
    },
    {
        name = "--- Wrath of the Lich King Dungeons ---",
        dungeons = {
            "Ahn'kahet: The Old Kingdom",
            "Azjol-Nerub",
            "Drak'Tharon Keep",
            "Gundrak",
            "Halls of Lightning",
            "Halls of Stone",
            "The Nexus",
            "The Oculus",
            "Violet Hold",
            "Utgarde Keep",
            "Utgarde Pinnacle"
        }
    },
    {
        name = "--- The Burning Crusade Dungeons ---",
        dungeons = {
            "Auchenai Crypts",
            "Hellfire Ramparts",
            "Mana-Tombs",
            "Sethekk Halls",
            "Shadow Labyrinth",
            "The Arcatraz",
            "The Blood Furnace",
            "The Botanica",
            "The Mechanar",
            "The Shattered Halls",
            "The Slave Pens",
            "The Steamvault",
            "The Underbog"
        }
    }
}

local ADDON_PREFIX = "MyLockouts"
local partyLocks = {} 
local partyUsers = {} 

-- Helper function to gather local character lockouts
local function GetMyLockedDungeons()
    RequestRaidInfo()
    local locked = {}
    local numSaved = GetNumSavedInstances()
    
    for i = 1, numSaved do
        local name, id, reset, difficulty, isLocked, extended, maxPlayers, isRaid, maxPlayers2, difficultyName = GetSavedInstanceInfo(i)
        
        if isLocked and name then
            local cleanName = string.gsub(name, "%s*%([%a%d%s%+%-%_]+%)", "")
            cleanName = strtrim(string.lower(cleanName))
            cleanName = string.gsub(cleanName, "^the%s+", "")
            
            local isMythic = false
            if difficultyName and string.find(string.lower(difficultyName), "mythic") then
                isMythic = true
            elseif difficulty == 3 or difficulty == 23 then
                isMythic = true
            end

            if isMythic then
                locked[cleanName] = true
            end
        end
    end
    return locked
end

-- ============================================================================
-- UI & Window Setup
-- ============================================================================
local mainWindow = CreateFrame("Frame", "MyLockoutsMainWindow", UIParent)
mainWindow:SetSize(360, 460)
mainWindow:SetPoint("CENTER")
mainWindow:SetMovable(true)
mainWindow:EnableMouse(true)
mainWindow:RegisterForDrag("LeftButton")
mainWindow:SetScript("OnDragStart", mainWindow.StartMoving)
mainWindow:SetScript("OnDragStop", mainWindow.StopMovingOrSizing)
mainWindow:Hide()

mainWindow:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})

local titleText = mainWindow:CreateFontString(nil, "ARTWORK", "GameFontNormal")
titleText:SetPoint("TOP", mainWindow, "TOP", 0, -16)
titleText:SetText("|cff66ccffMy Lockouts Tracker (v" .. ADDON_VERSION .. ")|r")

local closeBtn = CreateFrame("Button", nil, mainWindow, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", mainWindow, "TOPRIGHT", -6, -6)

local scrollArea = CreateFrame("ScrollFrame", "MyLockoutsScrollFrame", mainWindow, "UIPanelScrollFrameTemplate")
scrollArea:SetPoint("TOPLEFT", mainWindow, "TOPLEFT", 18, -45)
scrollArea:SetPoint("BOTTOMRIGHT", mainWindow, "BOTTOMRIGHT", -38, 55)

local content = CreateFrame("Frame", nil, scrollArea)
content:SetSize(300, 750)
scrollArea:SetScrollChild(content)

local resultText = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
resultText:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
resultText:SetWidth(290)
resultText:SetJustifyH("LEFT")

local printChatBtn = CreateFrame("Button", nil, mainWindow, "GameMenuButtonTemplate")
printChatBtn:SetSize(140, 25)
printChatBtn:SetPoint("BOTTOMLEFT", mainWindow, "BOTTOMLEFT", 18, 16)
printChatBtn:SetText("Post to Chat")
printChatBtn:SetNormalFontObject("GameFontNormalSmall")

local refreshBtn = CreateFrame("Button", nil, mainWindow, "GameMenuButtonTemplate")
refreshBtn:SetSize(140, 25)
refreshBtn:SetPoint("BOTTOMRIGHT", mainWindow, "BOTTOMRIGHT", -18, 16)
refreshBtn:SetText("Refresh Data")
refreshBtn:SetNormalFontObject("GameFontNormalSmall")

-- ============================================================================
-- Data Processing & Display Logic
-- ============================================================================
local function BuildLockoutReport()
    RequestRaidInfo()
    local myLocks = GetMyLockedDungeons()
    local masterLockedMap = {}

    for d, _ in pairs(myLocks) do
        masterLockedMap[d] = true
    end

    for _, locks in pairs(partyLocks) do
        for d, _ in pairs(locks) do
            masterLockedMap[d] = true
        end
    end

    local report = "|cff00ff00=== Mythic 0 Group Lockouts Tracker (v" .. ADDON_VERSION .. ") ===|r\n"
    local availableList = {}
    
    for _, exp in ipairs(EXPANSIONS) do
        report = report .. "\n|cffffd100" .. exp.name .. "|r\n"
        local expansionHasAvailable = false
        
        for _, dungeonName in ipairs(exp.dungeons) do
            local lookupKey = strtrim(string.lower(dungeonName))
            lookupKey = string.gsub(lookupKey, "^the%s+", "")
            
            if not masterLockedMap[lookupKey] then
                table.insert(availableList, dungeonName)
                report = report .. "  |cff00ff00[+]|r " .. dungeonName .. "\n"
                expansionHasAvailable = true
            end
        end
        
        if not expansionHasAvailable then
            report = report .. "  |cffff5555None available (All locked)|r\n"
        end
    end

    report = report .. "\n|cffffd100=== Party Status ===|r\n"

    if GetNumRaidMembers() > 0 then
        for i = 1, GetNumRaidMembers() do
            local name, _, _, _, _, _, _, online = GetRaidRosterInfo(i)
            if name and online then
                if name == UnitName("player") then
                    report = report .. "  " .. name .. " (You): |cff00ff00Active|r\n"
                elseif partyUsers[name] then
                    report = report .. "  " .. name .. ": |cff00ff00Addon Found|r\n"
                else
                    report = report .. "  " .. name .. ": |cffff5555Unknown (No Addon)|r\n"
                end
            end
        end
    elseif GetNumPartyMembers() > 0 then
        report = report .. "  " .. UnitName("player") .. " (You): |cff00ff00Active|r\n"
        for i = 1, GetNumPartyMembers() do
            local unit = "party" .. i
            local name = UnitName(unit)
            if name then
                if partyUsers[name] then
                    report = report .. "  " .. name .. ": |cff00ff00Addon Found|r\n"
                else
                    report = report .. "  " .. name .. ": |cffff5555Unknown (No Addon)|r\n"
                end
            end
        end
    else
        report = report .. "  " .. UnitName("player") .. " (You): |cff00ff00Active|r\n"
        report = report .. "  |cff808080Not currently in a group.|r\n"
    end

    resultText:SetText(report)
    return availableList
end

-- Event Handling & Communication
local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
if RegisterAddonMessagePrefix then
    RegisterAddonMessagePrefix(ADDON_PREFIX)
end

frame:SetScript("OnEvent", function(self, event, prefix, text, channel, sender)
    if prefix ~= ADDON_PREFIX then return end
    local myName = UnitName("player")
    if sender == myName then return end

    if text == "REQ_DATA" then
        local myLocks = GetMyLockedDungeons()
        local lockString = ""
        for dungeon, _ in pairs(myLocks) do
            lockString = lockString .. dungeon .. ";"
        end
        SendAddonMessage(ADDON_PREFIX, "DATA:" .. lockString, channel)
    elseif string.find(text, "^DATA:") then
        local data = string.sub(text, 6)
        partyLocks[sender] = {}
        partyUsers[sender] = true
        
        for dungeon in string.gmatch(data, "([^;]+)") do
            partyLocks[sender][dungeon] = true
        end
        if mainWindow:IsShown() then
            BuildLockoutReport()
        end
    end
end)

local function RequestSync()
    partyLocks = {}
    partyUsers = {}
    local groupChannel = nil
    if GetNumRaidMembers() > 0 then
        groupChannel = "RAID"
    elseif GetNumPartyMembers() > 0 then
        groupChannel = "PARTY"
    end

    if groupChannel then
        SendAddonMessage(ADDON_PREFIX, "REQ_DATA", groupChannel)
    end

    local timerFrame = CreateFrame("Frame")
    local elapsed = 0
    timerFrame:SetScript("OnUpdate", function(self, e)
        elapsed = elapsed + e
        if elapsed >= 0.3 then
            self:SetScript("OnUpdate", nil)
            BuildLockoutReport()
        end
    end)
end

refreshBtn:SetScript("OnClick", function()
    RequestSync()
end)

printChatBtn:SetScript("OnClick", function()
    local available = BuildLockoutReport()
    local channel = GetNumRaidMembers() > 0 and "RAID" or (GetNumPartyMembers() > 0 and "PARTY" or nil)
    
    if channel then
        SendChatMessage("=== Mythic 0 Available Dungeons (Group Check) ===", channel)
        for _, d in ipairs(available) do
            SendChatMessage("- " .. d, channel)
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff[Mythic 0 Tracker]|r Not in a group to post chat.")
    end
end)

-- ============================================================================
-- Minimap Button Implementation
-- ============================================================================
local mmButton = CreateFrame("Button", "MyLockoutsMinimapButton", Minimap)
mmButton:SetSize(31, 31)
mmButton:SetFrameStrata("MEDIUM")
mmButton:SetFrameLevel(8)
mmButton:SetMovable(true)
mmButton:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -15, 0)

mmButton:SetNormalTexture("Interface\\Icons\\Spell_Holy_BlessingOfStrength")
mmButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local overlay = mmButton:CreateTexture(nil, "OVERLAY")
overlay:SetSize(53, 53)
overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
overlay:SetPoint("TOPLEFT", -11, 11)

mmButton:SetScript("OnClick", function(self, button)
    if button == "LeftButton" then
        if mainWindow:IsShown() then
            mainWindow:Hide()
        else
            mainWindow:Show()
            RequestSync()
        end
    end
end)

mmButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("My Lockouts Tracker (v" .. ADDON_VERSION .. ")", 1, 1, 1)
    GameTooltip:AddLine("Left-Click to open window.", 0.2, 1, 0.2)
    GameTooltip:Show()
end)

mmButton:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)

-- Slash Commands
SLASH_MYLOCKOUTS1 = "/lockouts"
SLASH_MYLOCKOUTS2 = "/mlock"
SlashCmdList["MYLOCKOUTS"] = function()
    if mainWindow:IsShown() then
        mainWindow:Hide()
    else
        mainWindow:Show()
        RequestSync()
    end
end