local _, ns = ...

local pix = {
    name = "Пикс Ксиззикс", englishName = "Pix Xizzix", description = "Выдаёт недельные задания",
    atlas = "raceicon-goblin-female",
    texture = 1662186, texCoords = { 1 / 512, 65 / 512, 265 / 512, 329 / 512 },
    map = 1434, x = 0.285, y = 0.759,
    raidMark = 6,
}
local weeklyQuests = {
    [96076] = {
        title = { ruRU = "Высокий спрос: эльфийские древности", enUS = "In Demand - Ancient Elven Curiosities" },
        destinations = {
            {
                journalKey = "Dire Maul: East", bossID = 11492,
                ruRU = { dungeon = "Забытый город - восточное крыло", item = "Сквернитовое семя" },
                enUS = { dungeon = "Dire Maul - East Wing", item = "Felvine Seed" },
            },
            {
                journalKey = "Dire Maul: West", bossID = 11486,
                ruRU = { dungeon = "Забытый город - западное крыло", item = "Древняя памятная реликвия" },
                enUS = { dungeon = "Dire Maul - West Wing", item = "Ancient Memento" },
            },
            {
                journalKey = "Dire Maul: North", bossID = 11501,
                ruRU = { dungeon = "Забытый город - северное крыло", item = "Розовенькое колечко с землекаменным алмазом" },
                enUS = { dungeon = "Dire Maul - North Wing", item = "Earthstone Diamond Pinky Ring" },
            },
        },
    },
    [96075] = {
        title = { ruRU = "Высокий спрос: документы Черной горы", enUS = "In Demand - Blackrock Legal Records" },
        destinations = {
            {
                journalKey = "Upper Blackrock Spire", bossID = 10363,
                ruRU = { dungeon = "Вершина Черной горы - верхняя часть", item = "Помилование Нефари" },
                enUS = { dungeon = "Upper Blackrock Spire", item = "Remit" },
            },
            {
                journalKey = "Lower Blackrock Spire", bossID = 9568,
                ruRU = { dungeon = "Вершина Черной горы - нижняя часть", item = "Лицензия инспектора" },
                enUS = { dungeon = "Lower Blackrock Spire", item = "Overseer's License" },
            },
            {
                journalKey = "Blackrock Depths", bossID = 9019,
                ruRU = { dungeon = "Глубины Черной горы", item = "Брачный контракт Бронзобородов" },
                enUS = { dungeon = "Blackrock Depths", item = "Bronzebeard Wedding Contract" },
            },
        },
    },
    [96087] = {
        title = { ruRU = "Высокий спрос: записи о чуме", enUS = "In Demand - Plague Records" },
        destinations = {
            {
                journalKey = "Scholomance", bossID = 1853,
                ruRU = { dungeon = "Некроситет", item = "Записи ректора" },
                enUS = { dungeon = "Scholomance", item = "Headmaster's Records" },
            },
            {
                journalKey = "Stratholme: Undead", bossID = 10440,
                ruRU = { dungeon = "Стратхольм - часть нежити", item = "Записи о поставках зерна" },
                enUS = { dungeon = "Stratholme - Undead Side", item = "Grain Shipment" },
            },
            {
                journalKey = "Stratholme: Living", bossID = 10813,
                ruRU = { dungeon = "Стратхольм - живая часть", item = "Переписка Датроана" },
                enUS = { dungeon = "Stratholme - Living Side", item = "Dathrohan's Correspondence" },
            },
        },
    },
    [96088] = {
        title = { ruRU = "Высокий спрос: реликвии титанов", enUS = "In Demand - Titan Relics" },
        destinations = {
            {
                journalKey = "Sunken Temple", bossID = 5709,
                ruRU = { dungeon = "Затонувший храм", item = "Слеза Изеры" },
                enUS = { dungeon = "Sunken Temple", item = "Ysera's Tear" },
            },
            {
                journalKey = "Blackmaw Hold", bossID = 247234,
                ruRU = { dungeon = "Крепость Черночревов", item = "Знак Ксавия" },
                enUS = { dungeon = "Blackmaw Hold", item = "Mark of Xavius" },
            },
            {
                journalKey = "Shaper's Terrace", bossID = 261809,
                ruRU = { dungeon = "Терраса Создателя", item = "Печать Фрейи" },
                enUS = { dungeon = "The Shaper's Terrace", item = "Freya's Sigil" },
            },
        },
    },
}
local russian = GetLocale() == "ruRU"
local locale = russian and "ruRU" or "enUS"

ns.PixWeeklyQuestGiver = pix

function ns.SetPixIcon(texture)
    if C_Texture.GetAtlasInfo(pix.atlas) then
        texture:SetAtlas(pix.atlas, false)
    else
        texture:SetTexture(pix.texture)
        texture:SetTexCoord(unpack(pix.texCoords))
    end
end

local markers = {}

function ns.WatchWorldMap(map, canvas, refresh)
    local watcher = CreateFrame("Frame")
    local wasShown, mapID, width, height, scale, alpha
    local timeSinceUpdate = 0
    -- Keep our pins on the canvas, but run their updates outside Blizzard's map callbacks.
    watcher:SetScript("OnUpdate", function(_, elapsed)
        timeSinceUpdate = timeSinceUpdate + elapsed
        if timeSinceUpdate < 1 / 30 then return end
        timeSinceUpdate = 0
        if not map:IsShown() then
            if wasShown then refresh() end
            wasShown = false
            return
        end

        local nextMapID = map:GetMapID()
        local nextWidth, nextHeight = canvas:GetSize()
        local nextScale, nextAlpha = canvas:GetScale(), map:GetGlobalAlpha()
        if not wasShown or nextMapID ~= mapID or nextWidth ~= width or nextHeight ~= height
            or nextScale ~= scale or nextAlpha ~= alpha then
            wasShown = true
            mapID, width, height, scale, alpha = nextMapID, nextWidth, nextHeight, nextScale, nextAlpha
            refresh()
        end
    end)
end

local function RefreshMarker(marker, location, map, canvas)
    if not marker.requested or not map:IsShown() or map:GetMapID() ~= location.map then
        marker:Hide()
        return
    end

    local width, height = canvas:GetSize()
    local scale = canvas:GetScale()
    if width <= 0 or height <= 0 or scale <= 0 then
        marker:Hide()
        return
    end
    marker:SetScale(1 / scale)
    marker:ClearAllPoints()
    marker:SetPoint("CENTER", canvas, "TOPLEFT", location.x * width * scale, -location.y * height * scale)
    marker:SetAlpha(map:GetGlobalAlpha())
    marker:Show()
end

local function CanUseMapMarker()
    if not InCombatLockdown() then return true end
    UIErrorsFrame:AddMessage("Сначала закончи бой.", 1, 0.2, 0.2)
    ns.PrintCombatMessage("Навигатор остановлен: закончите бой.")
    return false
end

local function PlayerIsNear(location)
    if ns.Number(C_Map.GetBestMapForUnit("player")) ~= location.map then return false end
    local position = C_Map.GetPlayerMapPosition(location.map, "player")
    if not position then return false end
    local x, y = position:GetXY()
    x, y = ns.Number(x), ns.Number(y)
    if not x or not y then return false end
    local dx, dy = x - location.x, y - location.y
    return dx * dx + dy * dy <= 0.04 * 0.04
end

local function CreateNavigatorMarker(location, map, canvas)
    local marker = CreateFrame("Button", nil, canvas, "RainonUIForeverNavigatorMarkerTemplate")
    local levels = map:GetPinFrameLevelsManager()
    marker:SetFrameLevel(levels:GetValidFrameLevel("PIN_FRAME_LEVEL_SUPER_TRACKED_QUEST"))
    marker:EnableMouse(true)
    marker:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    marker:SetAttribute("useOnKeyDown", false)
    if location.icon then
        marker.Icon:SetTexture(location.icon)
    else
        ns.SetPixIcon(marker.Icon)
    end

    local targetName = GetLocale() == "ruRU" and location.name or location.englishName
    local macro = ("/cleartarget\n/targetexact %s\n/tm [exists] ~%d"):format(targetName, location.raidMark)
    marker:SetScript("PreClick", function(self, button)
        if not CanUseMapMarker() or button ~= "LeftButton" then return end
        if not PlayerIsNear(location) then
            self:SetAttribute("type1", nil)
            return
        end
        local hasTarget = UnitExists("target")
        local restoreTarget = not (issecretvalue and issecretvalue(hasTarget)) and hasTarget
        self:SetAttribute("macrotext1", restoreTarget and (macro .. "\n/targetlasttarget [noexists]") or macro)
        self:SetAttribute("type1", "macro")
    end)
    marker:SetScript("PostClick", function(self, button)
        if button == "RightButton" and not InCombatLockdown() then
            self.requested = false
            self:Hide()
        end
    end)
    local function HideTooltip(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end
    marker:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(location.name)
        GameTooltip:AddLine(location.description, 1, 1, 1)
        GameTooltip:AddLine("ЛКМ - взять в цель и пометить (рядом)", 0.35, 1, 0.35, true)
        GameTooltip:AddLine("ПКМ - убрать значок с карты", 1, 1, 1)
        ns.StyleTooltipLines(GameTooltip)
        GameTooltip:Show()
    end)
    marker:SetScript("OnLeave", HideTooltip)
    marker:SetScript("OnHide", HideTooltip)
    marker:Hide()
    ns.WatchWorldMap(map, canvas, function() RefreshMarker(marker, location, map, canvas) end)
    return marker
end

function ns.OpenNavigatorMap(location)
    if not CanUseMapMarker() then return false end
    OpenWorldMap(location.map)
    local map = WorldMapFrame
    local canvas = map and map.ScrollContainer and map.ScrollContainer.Child
    if not canvas or not map:IsShown() then return end
    local marker = markers[location] or CreateNavigatorMarker(location, map, canvas)
    markers[location] = marker
    marker.requested = true
    RefreshMarker(marker, location, map, canvas)
    return true
end

function ns.OpenPixMap()
    return ns.OpenNavigatorMap(pix)
end

local reminder
local preview = false
local weeklyState
local weeklyReady
local dismissed = false
local enteredWorld = false
local refreshScheduled = false
local resetCheckScheduled = false

local function RemainingDungeons(destinations, objectives)
    local remaining = {}
    for _, destination in ipairs(destinations) do
        local finished = false
        -- The order in the journal can differ from the order of the dungeon list.
        for _, objective in pairs(objectives) do
            if objective.finished and objective.text:find(destination[locale].item, 1, true) then
                finished = true
                break
            end
        end
        if not finished then remaining[#remaining + 1] = destination end
    end
    return remaining
end

local function OpenDungeonBoss(destination)
    local journal = ForeverDungeonJournal_NS
    local journalWindow = ForeverDungeonJournalFrame
    if not (journal and journal.OpenBossPage and journalWindow) then
        print("[RainonUI] для этого действия требуется аддон DungeonJournal.")
        return
    end

    local dungeon = journal.DB and journal.DB[destination.journalKey]
    if dungeon and dungeon.bosses then
        for index, boss in ipairs(dungeon.bosses) do
            if boss.npcID == destination.bossID then
                journalWindow:Show()
                journalWindow:Raise()
                journal.OpenBossPage(destination.journalKey, index)
                return
            end
        end
    end
    print(russian and "[RainonUI] В DungeonJournal не найдена страница этого босса."
        or "[RainonUI] This boss was not found in DungeonJournal.")
end

local function CreateDungeonRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetWidth(278)
    local button = CreateFrame("Button", nil, row)
    button:SetSize(22, 22)
    button:SetPoint("LEFT")
    button:RegisterForClicks("LeftButtonUp")
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:SetScript("OnClick", function() OpenDungeonBoss(row.destination) end)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    if C_Texture.GetAtlasInfo("dungeon") then
        icon:SetAtlas("dungeon")
    else
        icon:SetTexture("Interface\\Icons\\INV_Misc_Rune_01")
    end
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(russian and "Открыть босса в журнале" or "Open boss in DungeonJournal")
        ns.StyleTooltipLines(GameTooltip)
        GameTooltip:Show()
    end)
    local function HideTooltip(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end
    button:SetScript("OnLeave", HideTooltip)
    button:SetScript("OnHide", HideTooltip)

    row.label = ns.CreateText(row, nil, "ARTWORK", "GameFontHighlightSmall")
    row.label:SetPoint("LEFT", button, "RIGHT", 6, 0)
    row.label:SetPoint("RIGHT")
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(true)
    return row
end

local function CreateReminder()
    local heading = russian and "Недельные задания" or "Weekly Quests"
    local window, close = ns.CreateLootPanel("RainonUIForeverQuestReminder", heading, 310, 108)
    local function PositionWindow()
        local position = ns.db.pixWeeklyReminderPosition
        window:ClearAllPoints()
        if position then
            window:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", position.x, position.y)
        else
            window:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
        end
    end
    PositionWindow()
    window:SetMovable(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self:SetUserPlaced(false)
        local left, top = self:GetLeft(), self:GetTop()
        if left and top then
            ns.db.pixWeeklyReminderPosition = {
                x = left - (UIParent:GetLeft() or 0),
                y = top - (UIParent:GetBottom() or 0),
            }
            PositionWindow()
        end
    end)
    window:HookScript("OnHide", window.StopMovingOrSizing)

    local message = ns.CreateText(window, nil, "ARTWORK", "GameFontHighlight")
    message:SetPoint("TOP", 0, -36)
    message:SetWidth(278)

    local turnIn = ns.CreateText(window, nil, "ARTWORK", "GameFontHighlightSmall")
    turnIn:SetPoint("TOP", message, "BOTTOM", 0, -8)
    turnIn:SetWidth(278)
    turnIn:SetText(russian and "Сдай задание Пикс Ксиззикс." or "Turn in the quest to Pix Xizzix.")
    local rows = {}

    local mapButton = ns.CreateTextButton(window, "UIPanelButtonTemplate")
    mapButton:SetSize(160, 24)
    mapButton:SetPoint("BOTTOM", 0, 12)
    mapButton:SetText(russian and "Показать на карте" or "Show on Map")
    local function Dismiss()
        if not preview then dismissed = true end
        preview = false
        window:Hide()
    end
    close:SetScript("OnClick", Dismiss)
    mapButton:SetScript("OnClick", function()
        if ns.OpenPixMap() then Dismiss() end
    end)

    function window:ShowQuestReminder(state, readyToTurnIn, objectives)
        local quest = weeklyQuests[state]
        preview = objectives ~= nil
        mapButton:SetShown(not quest)
        local remaining = {}
        if quest then
            local title = C_QuestLog.GetTitleForQuestID(state)
            message:SetText(title and title ~= "" and title or quest.title[locale])
            if not readyToTurnIn then
                remaining = RemainingDungeons(quest.destinations, objectives or C_QuestLog.GetQuestObjectives(state) or {})
            end
            local contentHeight = 0
            for index, destination in ipairs(remaining) do
                local row = rows[index] or CreateDungeonRow(window)
                rows[index] = row
                row.destination = destination
                row.label:SetText(destination[locale].dungeon)
                row:SetPoint("TOP", message, "BOTTOM", 0, -8 - contentHeight)
                local height = math.max(22, row.label:GetStringHeight())
                row:SetHeight(height)
                row:Show()
                contentHeight = contentHeight + height
            end
            if #remaining == 0 then contentHeight = turnIn:GetStringHeight() end
            self:SetHeight(36 + message:GetStringHeight() + 8 + contentHeight + 16)
        else
            message:SetText(russian and ("Возьми недельное задание у " .. pix.name .. ".")
                or ("Pick up the weekly quest from " .. pix.englishName .. "."))
            self:SetHeight(108)
        end
        turnIn:SetShown(quest ~= nil and #remaining == 0)
        for index = #remaining + 1, #rows do rows[index]:Hide() end
        self:Show()
    end
    return window
end

local function GetActiveWeeklyQuest()
    for id in pairs(weeklyQuests) do
        if C_QuestLog.IsOnQuest(id) then return id end
    end
end

function ns.GetWeeklyQuestReminder()
    reminder = reminder or CreateReminder()
    return reminder
end

local function GetWeeklyState(guid)
    if not guid then return nil end
    local completed = ns.db.pixWeeklyCompletedUntil
    if completed and (completed[guid] or 0) > GetServerTime() then return nil end

    for id in pairs(weeklyQuests) do
        if C_QuestLog.IsQuestFlaggedCompleted(id) then return nil end
    end
    return GetActiveWeeklyQuest() or "available"
end

local function CanCheckWeeklyQuests()
    return enteredWorld and ns.Enabled("questReminders") and UnitLevel("player") == 60
end

local function HideWeeklyDuringPlay()
    local _, instanceType = IsInInstance()
    return InCombatLockdown() or instanceType == "pvp" or instanceType == "arena"
end

local function RefreshReminder()
    if not CanCheckWeeklyQuests() then
        if reminder and not preview then reminder:Hide() end
        return
    end

    if not resetCheckScheduled then
        local seconds = ns.Number(C_DateAndTime.GetSecondsUntilWeeklyReset()) or 0
        resetCheckScheduled = true
        C_Timer.After(seconds > 0 and seconds + 2 or 30, function()
            resetCheckScheduled = false
            if seconds > 0 then dismissed = false end
            RefreshReminder()
        end)
    end

    local state = GetWeeklyState(UnitGUID("player"))
    local readyToTurnIn = weeklyQuests[state] ~= nil and C_QuestLog.IsComplete(state) == true
    if state ~= weeklyState or readyToTurnIn ~= weeklyReady then
        weeklyState = state
        weeklyReady = readyToTurnIn
        dismissed = false
    end
    if preview then return end
    if state and not dismissed and not HideWeeklyDuringPlay() then
        ns.GetWeeklyQuestReminder():ShowQuestReminder(state, readyToTurnIn)
    elseif reminder then
        reminder:Hide()
    end
end

local function ScheduleReminderRefresh()
    if refreshScheduled or not CanCheckWeeklyQuests() then return end
    refreshScheduled = true
    C_Timer.After(0.5, function()
        refreshScheduled = false
        RefreshReminder()
    end)
end

ns.AddSetting("questReminders", "Напоминания", function()
    dismissed = false
    RefreshReminder()
end, true, nil, { icon = 134944, detail = pix.description, tooltip = "Только для персонажей 60-го уровня." })

ns.On("PLAYER_ENTERING_WORLD", function()
    enteredWorld = true
    if not preview and reminder and HideWeeklyDuringPlay() then reminder:Hide() end
    ScheduleReminderRefresh()
end)
ns.On("PLAYER_REGEN_DISABLED", function()
    if reminder and not preview then reminder:Hide() end
end)
ns.On("PLAYER_REGEN_ENABLED", RefreshReminder)
ns.On("QUEST_LOG_UPDATE", ScheduleReminderRefresh)
ns.On("PLAYER_LEVEL_UP", function(level)
    if level == 60 and enteredWorld and ns.Enabled("questReminders") then
        C_Timer.After(0.5, RefreshReminder)
    end
end)
ns.On("QUEST_WATCH_UPDATE", function(questID)
    if weeklyQuests[ns.Number(questID)] then ScheduleReminderRefresh() end
end)
ns.On("QUEST_TURNED_IN", function(questID)
    if UnitLevel("player") ~= 60 or not weeklyQuests[ns.Number(questID)] then return end
    local guid = UnitGUID("player")
    local seconds = ns.Number(C_DateAndTime.GetSecondsUntilWeeklyReset())
    if guid and seconds and seconds > 0 then
        ns.db.pixWeeklyCompletedUntil = ns.db.pixWeeklyCompletedUntil or {}
        ns.db.pixWeeklyCompletedUntil[guid] = GetServerTime() + seconds
    end
    RefreshReminder()
end)

