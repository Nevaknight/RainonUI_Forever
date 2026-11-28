local _, ns = ...

-- Encounter IDs for Forever dungeon bosses that award currency 3469, from NovaInstanceTracker.
local coinEncounters = {
    [329] = {2797, 472, 2798, 474, 476, 475, 477, 478, 480, 479, 481, 482, 483, 484},
    [289] = {2805, 2804, 2811, 2809, 2813, 2810, 2803, 2802, 2808, 2812, 2807, 2806, 2801},
    [230] = {235, 232, 234, 236, 237, 238, 239, 242, 244, 2790},
    [429] = {343, 344, 345, 346, 350, 347, 348, 349, 361, 368},
    [229] = {3062, 3063, 3068, 3069, 267, 268, 269, 270, 271, 274, 273, 275},
    [2974] = {3315, 3316, 3322, 3323, 3327, 3334, 3336},
    [3001] = {3498, 3499, 3501, 3500, 3507, 3502},
    [109] = {3582, 3589, 3588, 3586, 3583, 3584},
}
local coinCurrency, coinFallbackIcon = 3469, 133799
local reminder, reminderLabel, hideTimer
local reminderX, reminderY, reminderDragging
local showing
local reminderQueue = {}

local function FitReminder(box, label)
    box:SetWidth(math.ceil(label:GetUnboundedStringWidth()) + 24)
end

local function CreateReminderBox()
    local box, label = ns.CreateTimerBox()
    box:SetHeight(box:GetHeight() * 1.5)
    label:SetWordWrap(false)
    return box, label
end

local function WriteReminder(box, label, alert)
    label:SetFormattedText("|T%d:20:20|t %s", alert.icon, alert.text)
    label:SetTextColor(unpack(alert.color))
    FitReminder(box, label)
end

local DismissReminder
local function StartReminderTimer()
    if hideTimer then hideTimer:Cancel() end
    hideTimer = C_Timer.NewTimer(showing.seconds or 10, function()
        hideTimer = nil
        DismissReminder()
    end)
end

local function StopReminderDrag()
    if not reminderDragging then return end
    reminderDragging = nil
    reminder:StopMovingOrSizing()
    local x, y = reminder:GetCenter()
    local centerX, centerY = UIParent:GetCenter()
    if x and y and centerX and centerY then
        reminderX, reminderY = x - centerX, y - centerY
    end
end

local function ShowReminder(alert)
    if not reminder then
        reminder, reminderLabel = CreateReminderBox()
        reminder:SetMovable(true)
        reminder:RegisterForDrag("LeftButton")
        reminder:SetScript("OnDragStart", function(box)
            if not showing or not showing.movable then return end
            reminderDragging = true
            if hideTimer then
                hideTimer:Cancel()
                hideTimer = nil
            end
            box:StartMoving()
        end)
        reminder:SetScript("OnDragStop", function()
            if not reminderDragging then return end
            StopReminderDrag()
            StartReminderTimer()
        end)
    end
    StopReminderDrag()
    showing = alert
    if alert.greenMark and not alert.preview then
        ns.db.markWarningsThisLogin[alert.key] = true
    end
    local movable = alert.movable == true
    reminder:EnableMouse(movable)
    reminder:ClearAllPoints()
    reminder:SetPoint("CENTER", UIParent, "CENTER", movable and reminderX or 0, movable and reminderY or 0)
    WriteReminder(reminder, reminderLabel, alert)
    reminder:Show()
    StartReminderTimer()
end

DismissReminder = function()
    StopReminderDrag()
    if hideTimer then hideTimer:Cancel() end
    hideTimer, showing = nil, nil
    if reminder then reminder:Hide() end
    local nextAlert = table.remove(reminderQueue, 1)
    if nextAlert then ShowReminder(nextAlert) end
end

local function QueueReminder(alert, preview)
    if preview then
        if showing and not showing.preview then table.insert(reminderQueue, 1, showing) end
        alert.preview = true
        ShowReminder(alert)
        return
    end
    if not showing then
        ShowReminder(alert)
    elseif showing.key == alert.key and not showing.preview then
        ShowReminder(alert)
    else
        for i, queued in ipairs(reminderQueue) do
            if queued.key == alert.key then reminderQueue[i] = alert; return end
        end
        reminderQueue[#reminderQueue + 1] = alert
    end
end

local function ClearReminder(key, preservePreview)
    for i = #reminderQueue, 1, -1 do
        if reminderQueue[i].key == key then table.remove(reminderQueue, i) end
    end
    if showing and showing.key == key and not (preservePreview and showing.preview) then
        DismissReminder()
    end
end

local function HideBossReminder()
    ClearReminder("boss")
end

function ns.ShowCoinReminder()
    local info = C_CurrencyInfo.GetCurrencyInfo(coinCurrency)
    QueueReminder({key = "boss", icon = info and info.iconFileID or coinFallbackIcon,
        text = "Полутай босса!", color = {1, 0.82, 0}})
end

ns.AddSetting("bossCoin", "Напоминать о монетке босса", HideBossReminder, true, "general", {
    title = "Напоминать о монетке", detail = "После убийства босса", wrapTitle = true, icon = coinFallbackIcon,
    tooltip = function()
        local info = C_CurrencyInfo.GetCurrencyInfo(coinCurrency)
        local icon = info and info.iconFileID or coinFallbackIcon
        if not (info and info.name) then return end
        local name = info.name
        return ("После убийства боссов с которых можно получить |T%d:16:16|t %s будет показывать напоминание.")
            :format(icon, name)
    end,
})
ns.On("ENCOUNTER_END", function(encounter, _, _, _, success)
    if not ns.Enabled("bossCoin") or ns.Number(success) ~= 1 then return end
    local _, kind, _, _, _, _, _, map = GetInstanceInfo()
    if kind ~= "party" then return end
    for _, id in ipairs(coinEncounters[map] or {}) do
        if id == ns.Number(encounter) then
            ns.ShowCoinReminder()
            return
        end
    end
end)
ns.On("CHAT_MSG_CURRENCY", function(message)
    if type(message) == "string" and not (issecretvalue and issecretvalue(message))
        and tonumber(message:match("currency:(%d+)")) == coinCurrency then HideBossReminder() end
end)
ns.On("PLAYER_LEAVING_WORLD", HideBossReminder)

-- Forever uses the same mark item for Alliance and Horde on each battlefield.
local battlefields = {
    [489] = {name = "Ущелье Песни Войны", mark = 20558, icon = 134420, Alliance = 890, Horde = 889},
    [529] = {name = "Низина Арати", mark = 20559, icon = 133282, Alliance = 509, Horde = 510},
    [30] = {name = "Альтеракская долина", mark = 20560, icon = 133308, Alliance = 730, Horde = 729},
    [2997] = {name = "Острова Чёрного Копья", mark = 274895, icon = 133279, Alliance = 2799, Horde = 2798},
}

function ns.IsForeverBattlefield(map)
    return battlefields[map] ~= nil
end

local markOrder = {489, 529, 30, 2997}
local rankMaps = {489, 529, 2997}
local honorCurrency = 1792
local allianceIcon = "Interface\\Icons\\Achievement_PVP_A_16"
local alertColors = {{0.46, 1, 0.48}, {1, 0.30, 0.28}}
local journal

local function PvPEnabled(feature)
    return ns.Enabled("pvp") and ns.Enabled(feature)
end

local function MarkIcon(field)
    return C_Item.GetItemIconByID and C_Item.GetItemIconByID(field.mark) or field.icon
end

local function MarkCount(field)
    if field and C_Item.GetItemCount then
        return ns.Number(C_Item.GetItemCount(field.mark, true, false, false, false))
    end
end

local function PvPAlert(key, icon, tier, amount)
    return {key = key, icon = icon, color = alertColors[tier],
        movable = key == "honor" or tier == 2, greenMark = amount ~= nil and tier == 1,
        seconds = amount and tier == 1 and 30 or nil,
        text = amount and ("%s %d / 30"):format(tier == 2 and "Потрать жетоны!" or "Жетоны", amount)
            or (tier == 2 and "Потрать валюту!" or "Потратить валюту?")}
end

local function CheckAlert(guid, key, icon, amount, warningAt, urgentAt)
    if amount == nil then return end
    local saved = ns.db.pvpWarnings
    if not saved then saved = {}; ns.db.pvpWarnings = saved end
    local states = saved[guid] or {}
    saved[guid] = states
    local tier = amount >= urgentAt and 2 or (amount >= warningAt and 1 or 0)
    local previous = states[key] or 0
    states[key] = tier
    if tier > previous then
        QueueReminder(PvPAlert(key, icon, tier))
    elseif tier < previous then
        ClearReminder(key, true)
    end
end

local urgentMarks, lastMarks = {}, {}

function ns.RefreshActivityReminderLayout()
    if reminder then FitReminder(reminder, reminderLabel) end
    for _, notice in pairs(urgentMarks) do FitReminder(notice.box, notice.label) end
end

local function ShowUrgentMark(index, alert)
    local notice = urgentMarks[alert.key]
    if not notice then
        local box, label = CreateReminderBox()
        notice = {box = box, label = label}
        urgentMarks[alert.key] = notice
        box:SetPoint("TOP", UIParent, "CENTER", 0, -32 - (index - 1) * (box:GetHeight() + 4))
        box:SetMovable(true)
        box:EnableMouse(true)
        box:RegisterForDrag("LeftButton")
        box:SetScript("OnDragStart", box.StartMoving)
        box:SetScript("OnDragStop", box.StopMovingOrSizing)
        box:SetScript("OnHide", box.StopMovingOrSizing)
    end
    WriteReminder(notice.box, notice.label, alert)
    notice.box:Show()
end

local function ClearMarkAlerts()
    wipe(lastMarks)
    for _, notice in pairs(urgentMarks) do notice.box:Hide() end
    for i = #reminderQueue, 1, -1 do
        if reminderQueue[i].greenMark then table.remove(reminderQueue, i) end
    end
    if showing and showing.greenMark and not showing.preview then DismissReminder() end
end

local function CheckMarkAlerts()
    if not PvPEnabled("pvpMarkAlert") then return end
    local shown = ns.db.markWarningsThisLogin
    if not shown then
        shown = {}
        ns.db.markWarningsThisLogin = shown
    end
    for index, map in ipairs(markOrder) do
        local field = battlefields[map]
        local key = field.mark
        local amount = MarkCount(field)
        if amount and amount ~= lastMarks[map] then
            local previous = lastMarks[map]
            lastMarks[map] = amount
            if amount >= 25 then
                ClearReminder(key, true)
                ShowUrgentMark(index, PvPAlert(key, MarkIcon(field), 2, amount))
            else
                local notice = urgentMarks[key]
                if notice then notice.box:Hide() end
                if amount < 20 then
                    ClearReminder(key, true)
                elseif not shown[key] and (not previous or previous < 20) then
                    QueueReminder(PvPAlert(key, MarkIcon(field), 1, amount))
                end
            end
        end
    end
end

local function CheckHonorAlert(currencyID)
    if not PvPEnabled("pvpHonorAlert") then return end
    if type(currencyID) == "number" and ns.Number(currencyID) ~= honorCurrency then return end
    local guid = UnitGUID("player")
    local info = C_CurrencyInfo.GetCurrencyInfo(honorCurrency)
    if guid and info then
        CheckAlert(guid, "honor", info.iconFileID or 2173919,
            ns.Number(info.quantity), 20000, 23000)
    end
end

function ns.ShowPvPAlertPreview(honor, urgent)
    local field = battlefields[529]
    local icon = honor and 2173919 or field.icon
    QueueReminder(PvPAlert(honor and "honor" or field.mark, icon, urgent and 2 or 1,
        not honor and (urgent and 25 or 20) or nil), true)
end

ns.AddSetting("pvpMarkAlert", "Лимит жетонов", function()
    if ns.Enabled("pvpMarkAlert") then
        CheckMarkAlerts()
    else
        ClearMarkAlerts()
    end
end, false, "pvp", {
    icon = battlefields[529].icon,
    tooltip = "От 20 жетонов - 30 секунд один раз за вход. От 25 - пока жетонов не станет меньше 25. Лимит - 30.",
})
ns.AddSetting("pvpHonorAlert", "Лимит чести", function()
    if ns.Enabled("pvpHonorAlert") then CheckHonorAlert() else ClearReminder("honor", true) end
end, false, "pvp", {
    icon = 2173919, tooltip = "Напоминания при 20 000 и 23 000 очках чести.",
})
ns.On("PLAYER_ENTERING_WORLD", function(initialLogin)
    if initialLogin then
        ns.db.markWarningsThisLogin = nil
        wipe(lastMarks)
    end
    CheckMarkAlerts()
end)
ns.On("PLAYER_LOGIN", function() CheckHonorAlert() end)
ns.On("CURRENCY_DISPLAY_UPDATE", CheckHonorAlert)

local active, entered, refreshJournal
local rankFaction = 2800
local function ReadRankProgress()
    local factions = C_MajorFactions
    if not (factions and factions.GetMajorFactionProgressionInfo and factions.GetTotalReputationForRenownLevel) then
        return
    end
    local info = factions.GetMajorFactionProgressionInfo(rankFaction)
    if (issecretvalue and issecretvalue(info)) or not info then return end
    local level, points = ns.Number(info.renownLevel), ns.Number(info.renownReputationEarned)
    if not (level and points) then return end
    local base = ns.Number(factions.GetTotalReputationForRenownLevel(rankFaction, level))
    if not base then return end
    local capRank = ns.Number(info.currentWeekProgressiveMaxLevel)
    local cap = capRank and ns.Number(factions.GetTotalReputationForRenownLevel(rankFaction, capRank))
    return {level = level, points = points, total = base + points, cap = cap, capRank = capRank,
        nextRank = ns.Number(info.renownLevelThreshold)}
end

local function ReadRankTotal()
    local progress = ReadRankProgress()
    return progress and progress.total
end

local function UpdateBattleMarks(row)
    if not PvPEnabled("battleLog") or not row or row.markBefore == nil or row.guid ~= UnitGUID("player") then return end
    local count = MarkCount(battlefields[row.map])
    if count then
        local gained = math.max(0, count - row.markBefore)
        if row.marks == nil or gained > row.marks then
            row.marks = gained
            if refreshJournal then refreshJournal() end
        end
    end
end

ns.On("BAG_UPDATE_DELAYED", function()
    if active and (active.result or active.rankFinished) then UpdateBattleMarks(active) end
    CheckMarkAlerts()
end)

local rankTimer
local rankExitDelay = 5
local function UpdateRankPoints(row, final)
    if not PvPEnabled("battleLog") or not row or row.map == 30 or not row.rankBefore or row.guid ~= UnitGUID("player") then return end
    local total = ReadRankTotal()
    if not total or total < row.rankBefore then return end
    local points = total - row.rankBefore
    if (points > 0 or final) and row.rankPoints ~= points then
        row.rankPoints = points
        if refreshJournal then refreshJournal() end
    end
end

local function CancelRankCheck()
    if rankTimer then
        rankTimer:Cancel()
        rankTimer = nil
    end
end

local function CheckRewardsAfterFinish(row)
    if not row.rankBefore and row.markBefore == nil then return end
    CancelRankCheck()
    UpdateRankPoints(row)
    UpdateBattleMarks(row)
    rankTimer = C_Timer.NewTimer(2, function()
        rankTimer = nil
        if active == row then
            UpdateRankPoints(row)
            UpdateBattleMarks(row)
        end
    end)
end

local function CheckRewardsAfterExit(row)
    if not row.rankBefore and row.markBefore == nil then return end
    CancelRankCheck()
    UpdateRankPoints(row)
    UpdateBattleMarks(row)
    local delay = row.rankCheckUntil - GetServerTime()
    if delay <= 0 then return end
    rankTimer = C_Timer.NewTimer(delay, function()
        rankTimer = nil
        if not PvPEnabled("battleLog") then return end
        row.rankCheckUntil = nil
        local _, kind = GetInstanceInfo()
        if not active and kind ~= "pvp" and kind ~= "arena" then
            UpdateRankPoints(row, true)
            UpdateBattleMarks(row)
        end
    end)
end

local function Elapsed(row)
    return row.seconds + (row == active and entered and math.max(0, GetTime() - entered) or 0)
end

local function RecordResult(winner)
    if not active or active.result then return end
    winner = ns.Number(winner)
    if winner ~= 0 and winner ~= 1 and winner ~= 2 then return end
    if winner == 2 then
        active.result = "draw"
    else
        local team = GetBattlefieldArenaFaction and ns.Number(GetBattlefieldArenaFaction())
        if team ~= 0 and team ~= 1 then
            local score = C_PvP and C_PvP.GetScoreInfoByPlayerGuid and C_PvP.GetScoreInfoByPlayerGuid(active.guid)
            team = score and ns.Number(score.faction)
        end
        if team ~= 0 and team ~= 1 then return end
        active.result = winner == team and "win" or "loss"
    end
    active.seconds = math.floor(Elapsed(active))
    entered = nil
    CheckRewardsAfterFinish(active)
    if refreshJournal then refreshJournal() end
end

local function ReadResult()
    if not active or active.result then return end
    local winner = GetBattlefieldWinner and ns.Number(GetBattlefieldWinner())
    if winner == nil and C_PvP and C_PvP.IsMatchComplete and C_PvP.GetActiveMatchWinner
        and C_PvP.IsMatchComplete() then
        winner = C_PvP.GetActiveMatchWinner()
    end
    RecordResult(winner)
end

local function PauseBattle()
    if active then active.seconds = math.floor(Elapsed(active)) end
    active, entered = nil, nil
    if refreshJournal then refreshJournal() end
end

local function LeaveBattle()
    ReadResult()
    UpdateRankPoints(active)
    UpdateBattleMarks(active)
    if active and (active.result or active.rankFinished) then
        active.rankLeftAt = GetServerTime()
    end
    CancelRankCheck()
    PauseBattle()
end

local function SyncBattle()
    if not ns.Enabled("pvp") then return end
    local guid = UnitGUID("player")
    if not guid then return end
    local _, kind, _, _, _, _, _, map = GetInstanceInfo()
    local history = ns.db.battleHistory or {}
    -- A character can reload or switch characters before leaving the match.
    local last
    for i = #history, 1, -1 do
        if history[i].guid == guid then last = history[i]; break end
    end
    local inBattle = ns.Enabled("battleLog") and kind == "pvp" and ns.IsForeverBattlefield(map)
    local runtime = inBattle and GetBattlefieldInstanceRunTime and ns.Number(GetBattlefieldInstanceRunTime())
    local start = runtime and runtime > 0 and GetServerTime() - math.floor(runtime / 1000)
    if last and last.open and (not inBattle or last.map ~= map
        or (last.started and start and math.abs(last.started - start) > 5)) then
        last.open = nil
        local now = GetServerTime()
        if ns.Enabled("battleLog") and kind ~= "pvp" and kind ~= "arena"
            and last.rankLeftAt and now - last.rankLeftAt <= rankExitDelay and (last.rankBefore or last.markBefore ~= nil) then
            last.rankCheckUntil = now + rankExitDelay
        end
        last.rankLeftAt = nil
    end
    if not inBattle then
        PauseBattle()
        if ns.Enabled("battleLog") and kind ~= "pvp" and kind ~= "arena"
            and last and last.rankCheckUntil and last.rankCheckUntil > GetServerTime() then
            CheckRewardsAfterExit(last)
        else
            CancelRankCheck()
        end
        return
    end
    if last then
        last.rankCheckUntil, last.rankLeftAt = nil, nil
    end
    CancelRankCheck()
    if not last or not last.open then
        PauseBattle()
        local progress = map ~= 30 and ReadRankProgress() or nil
        last = {guid = guid, name = ns.CharacterIdentity(), map = map, started = start,
            seconds = 0, honor = 0, rep = 0, open = true,
            recordedAt = GetServerTime(), rankBefore = progress and progress.total,
            rankCap = progress and progress.cap, markBefore = MarkCount(battlefields[map])}
        history[#history + 1] = last
        ns.db.battleHistory = history
    end
    last.started = last.started or start
    if not last.class then
        local class = select(2, UnitClass("player"))
        if not (issecretvalue and issecretvalue(class)) then last.class = class end
    end
    if active ~= last then
        active = last
        entered = not last.result and GetTime() or nil
    end
    if last.result or last.rankFinished then CheckRewardsAfterFinish(last) end
    ReadResult()
    if refreshJournal then refreshJournal() end
end

ns.AddSetting("battleLog", "Записывать поля боя", SyncBattle, false, "pvp", {
    wrapTitle = true, icon = "Interface\\Icons\\INV_Misc_Book_11",
    tooltip = "Alt + ЛКМ по значку RainonUI открывает журнал полей боя.",
})
ns.AddSetting("pvpRankPanel", "Панель ранга PvP", function()
    if refreshJournal then refreshJournal() end
end, false, "pvp", {
    atlas = "UI-Character-Info-Honor-Icon-3", tooltip = "Показывает ранг, валюту и репутацию слева от журнала полей боя.",
})
ns.AddSetting("pvpAutoGossip", "Автодиалог распорядителей", nil, false, "pvp", {
    icon = "Interface\\GossipFrame\\GossipGossipIcon",
    tooltip = "Выбирает первый пункт при разговоре с четырьмя распорядителями полей боя в Штормграде.",
})

local battlemasters = {
    [7410] = true,   -- Thelman Slatefist
    [15008] = true,  -- Lady Hoteshem
    [263349] = true, -- James Battlewing
    [14981] = true,  -- Elfarran
}
local gossipOpen, gossipTimer, selectedGossipNPC
local function SelectBattlemasterOption()
    if not PvPEnabled("pvpAutoGossip") then return true end
    local guid = UnitGUID("npc")
    if (issecretvalue and issecretvalue(guid)) or type(guid) ~= "string" then return end
    local npcID = tonumber(guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
    if not (npcID and battlemasters[npcID]) or guid == selectedGossipNPC then return true end

    local options = C_GossipInfo.GetOptions()
    local first, firstIndex
    for _, option in ipairs(options) do
        local index = ns.Number(option.orderIndex)
        if index and (not firstIndex or index < firstIndex) then
            first, firstIndex = option, index
        end
    end
    if not first or ns.Number(first.status) ~= Enum.GossipOptionStatus.Available then return end

    -- A hidden gossip window with this flag is handled by Blizzard's own auto-selection.
    if #options == 1 and first.selectOptionWhenOnlyOption and not C_GossipInfo.ForceGossip()
        and C_GossipInfo.GetNumAvailableQuests() == 0 and C_GossipInfo.GetNumActiveQuests() == 0
        and not (GossipFrame and GossipFrame:IsShown()) then return end
    selectedGossipNPC = guid
    C_GossipInfo.SelectOptionByIndex(firstIndex)
    return true
end

local function CheckGossipOnNextFrame()
    if not gossipOpen or gossipTimer or not PvPEnabled("pvpAutoGossip") then return end
    gossipTimer = C_Timer.NewTimer(0, function()
        gossipTimer = nil
        if SelectBattlemasterOption() or not gossipOpen or gossipTimer then return end
        -- The NPC token or option list can arrive after GOSSIP_SHOW.
        gossipTimer = C_Timer.NewTimer(0.15, function()
            gossipTimer = nil
            SelectBattlemasterOption()
        end)
    end)
end

local function CloseGossip(continuing)
    gossipOpen = nil
    if gossipTimer then
        gossipTimer:Cancel()
        gossipTimer = nil
    end
    if not continuing then selectedGossipNPC = nil end
end

ns.On("GOSSIP_SHOW", function()
    if not PvPEnabled("pvpAutoGossip") then return end
    gossipOpen = true
    CheckGossipOnNextFrame()
end)
ns.On("GOSSIP_OPTIONS_REFRESHED", CheckGossipOnNextFrame)
ns.On("GOSSIP_CLOSED", CloseGossip)
ns.On("BATTLEFIELDS_SHOW", function() CloseGossip(true) end)
ns.On("BATTLEFIELDS_CLOSED", CloseGossip)
ns.On("PLAYER_LEAVING_WORLD", CloseGossip)

local function ApplyPvPSetting()
    ns.SyncBattleTimers()
    if ns.Enabled("pvp") then
        CheckMarkAlerts()
        CheckHonorAlert()
        if ns.Enabled("battleLog") then SyncBattle() end
        return
    end

    ClearMarkAlerts()
    if journal then journal:Hide() end
    CloseGossip()
    CancelRankCheck()
    for i = #reminderQueue, 1, -1 do
        if reminderQueue[i].key ~= "boss" then table.remove(reminderQueue, i) end
    end
    if showing and showing.key ~= "boss" then DismissReminder() end

    -- End unfinished observations so a new baseline is taken on re-enable.
    if active then active.seconds = math.floor(Elapsed(active)) end
    active, entered = nil, nil
    for _, row in ipairs(ns.db.battleHistory or {}) do
        row.open, row.rankLeftAt, row.rankCheckUntil = nil, nil, nil
    end
end

ns.AddSetting("pvp", "ПвП функции", ApplyPvPSetting, false, "general", {
    icon = allianceIcon,
    tooltip = "При выключении скрывает вкладку и отключает таймеры, озвучку, запись боёв, предупреждения и автодиалог.",
})
ns.tabsAfterGeneral = ns.tabsAfterGeneral or {}
table.insert(ns.tabsAfterGeneral, {
    key = "pvp", title = "PvP", icon = allianceIcon, columns = 1, toggle = true,
    afterSettings = ns.BuildBattleVoiceOptions,
})
ns.On("PLAYER_ENTERING_WORLD", SyncBattle)
ns.On("PLAYER_LEAVING_WORLD", LeaveBattle)
ns.On("PLAYER_LOGOUT", LeaveBattle)
ns.On("PVP_MATCH_COMPLETE", function(winner)
    if not active or active.result or active.rankFinished then return end
    active.rankFinished = true
    RecordResult(winner)
    if not active.result then CheckRewardsAfterFinish(active) end
end)
ns.On("UPDATE_BATTLEFIELD_SCORE", ReadResult)

-- Match the client's message format, including locales that reorder its arguments.
local function AmountPattern(format)
    -- The game can expand a Russian declension before sending the chat event.
    format = format:gsub("|3%-%d+%((%%s)%)", "%1")
    local pattern = format:gsub("([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")
    local index = 0
    pattern = pattern:gsub("%%(%d*)%%?%$?([ds])", function(position, kind)
        index = index + 1
        if kind == "s" then return ".-" end
        if (tonumber(position) or index) == 2 then return "(%d+)" end
        return "%d+"
    end)
    return "^" .. pattern .. "$"
end
local repPatterns = {}
for _, key in ipairs({"FACTION_STANDING_INCREASED", "FACTION_STANDING_INCREASED_BONUS",
    "FACTION_STANDING_INCREASED_ACH_BONUS", "FACTION_STANDING_INCREASED_DOUBLE_BONUS",
    "FACTION_STANDING_INCREASED_ACCOUNT_WIDE", "FACTION_STANDING_DECREASED",
    "FACTION_STANDING_DECREASED_ACCOUNT_WIDE"}) do
    if _G[key] then
        repPatterns[#repPatterns + 1] = { pattern = AmountPattern(_G[key]),
            sign = key:find("DECREASED") and -1 or 1 }
    end
end
local function ReadableMessage(message)
    return active and not (issecretvalue and issecretvalue(message)) and type(message) == "string"
end
ns.On("CHAT_MSG_COMBAT_FACTION_CHANGE", function(message)
    if not ReadableMessage(message) then return end
    for _, pattern in ipairs(repPatterns) do
        local amount = tonumber((message:match(pattern.pattern)))
        if amount then active.rep = active.rep + pattern.sign * amount; break end
    end
    if refreshJournal then refreshJournal() end
end)
ns.On("CHAT_MSG_COMBAT_HONOR_GAIN", function(message)
    if not ReadableMessage(message) then return end
    -- Honor messages can include a colored player link before the actual award.
    local plain = message:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|H.-|h.-|h", ""):gsub("|r", "")
    local amount = plain:match("(%d+[.,]%d+)%D*$") or plain:match("(%d+)%D*$")
    if amount then active.honor = active.honor + tonumber((amount:gsub(",", "."))) end
    if refreshJournal then refreshJournal() end
end)

local columns = {
    {key = "name", title = "Персонаж", width = 164},
    {key = "map", title = "Поле боя", width = 207},
    {key = "result", title = "Результат", width = 112, centered = true},
    {key = "time", title = "Время", width = 80, centered = true},
    {key = "rank", title = "Очки ранга", width = 108, centered = true},
    {key = "rep", title = "Репутация", width = 103, centered = true},
    {key = "honor", title = "Очки чести", width = 114, centered = true},
    {key = "marks", title = "Валюта", width = 90, centered = true},
}
local results = {
    win = {"Победа", 0.61, 0.87, 0.55},
    loss = {"Поражение", 1, 0.54, 0.49},
    draw = {"Ничья", 0.83, 0.77, 0.66},
    unknown = {"-", 0.70, 0.65, 0.57},
}
local samples, sampleRank, page, character, battlefield, battleDate
local characterFilter, battlefieldFilter, dateFilter
local pageSize, rowHeight, tableTop = 14, 35, 107
local minScale, maxScale, scaleStep = 60, 160, 10
local tableWidth = 0
for _, column in ipairs(columns) do tableWidth = tableWidth + column.width end

local function History()
    if samples then return samples end
    local history = {}
    for _, row in ipairs(ns.db.battleHistory or {}) do
        if row.map == nil or ns.IsForeverBattlefield(row.map) then
            history[#history + 1] = row
        end
    end
    return history
end

local function CharacterKey(row)
    return row.guid or row.name
end

local function BattlefieldName(map)
    return (battlefields[map] and battlefields[map].name) or (map and ("Поле боя №" .. map) or "Неизвестное поле боя")
end

local noDate = "Без даты"
local function FillNovaResults(history, matches)
    for _, match in ipairs(matches) do
        if match.type == "bg" and match.enteredTime
            and (match.faction == 0 or match.faction == 1)
            and (match.winningFaction == 0 or match.winningFaction == 1) then
            local closest, distance, tied
            for _, row in ipairs(history) do
                local timestamp = row.recordedAt or row.started
                if timestamp and row.name == match.playerName and row.map == match.instanceID then
                    -- The old log used the match's start, Nova uses the player's entry.
                    local gap = math.abs(timestamp - match.enteredTime)
                    local limit = row.recordedAt and 10 or 60
                    if gap <= limit then
                        if not distance or gap < distance then
                            closest, distance, tied = row, gap, false
                        elseif gap == distance then
                            tied = true
                        end
                    end
                end
            end
            if closest and not tied then
                closest.class = closest.class or match.classEnglish
                if not closest.result and not closest.open then
                    closest.result = match.faction == match.winningFaction and "win" or "loss"
                end
            end
        end
    end
end

local function FillHistoricalResults()
    local history = ns.db.battleHistory
    if not history then return end
    local nova = NITdatabase and NITdatabase.global
    local _, realm = ns.CharacterIdentity()
    -- Nova calls the Hardcore ruleset "Hardcore"; RainonUI calls it "HC".
    local realmData = nova and nova[realm == "HC" and "Hardcore" or realm]
    if realmData and realmData.instances then
        FillNovaResults(history, realmData.instances)
    end
    local cached = ns.LocalNovaMatches and ns.LocalNovaMatches[realm]
    if cached then FillNovaResults(history, cached) end
end

local function BattleDate(row)
    local timestamp = row.recordedAt or row.started
    return timestamp and date("%Y-%m-%d", timestamp) or noDate
end

local function DateLabel(key)
    if key == noDate then return noDate end
    local year, month, day = key:match("^(%d+)%-(%d+)%-(%d+)$")
    return day .. "." .. month .. "." .. year
end

local function Duration(seconds)
    seconds = math.floor(seconds)
    local hours, minutes = math.floor(seconds / 3600), math.floor(seconds / 60) % 60
    if hours > 0 then return ("%d:%02d:%02d"):format(hours, minutes, seconds % 60) end
    return ("%d:%02d"):format(minutes, seconds % 60)
end

local function Points(points)
    local whole = math.floor(math.abs(points) + 0.5)
    local digits = tostring(whole):reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", "")
    return points < 0 and whole > 0 and ("-" .. digits) or digits
end

local function JournalText(parent, size, r, g, b)
    local label = ns.CreateText(parent, nil, "OVERLAY", "GameFontHighlight")
    ns.ApplyUIFont(label, size, "")
    label:SetTextColor(r, g, b)
    return label
end

local function Fill(parent, r, g, b, alpha)
    local texture = parent:CreateTexture(nil, "BACKGROUND")
    texture:SetAllPoints()
    texture:SetColorTexture(r, g, b, alpha)
    return texture
end

local function MakeCells(parent, header)
    local cells, x = {}, 0
    for index, column in ipairs(columns) do
        local cell = header and JournalText(parent, 13, 0.87, 0.75, 0.55)
            or JournalText(parent, 14, 0.96, 0.93, 0.85)
        cell:SetPoint("TOPLEFT", x + 12, -2)
        cell:SetPoint("BOTTOMRIGHT", parent, "TOPLEFT", x + column.width - 12, -parent:GetHeight() + 2)
        cell:SetJustifyH(column.centered and "CENTER" or "LEFT")
        cell:SetJustifyV("MIDDLE")
        local wrap = not header and not column.centered
        cell:SetWordWrap(wrap)
        cell:SetMaxLines(wrap and 2 or 1)
        if header then cell:SetText(column.title) end
        cells[column.key] = cell
        x = x + column.width
        if index < #columns then
            local divider = parent:CreateTexture(nil, "BORDER")
            divider:SetPoint("TOPLEFT", x, -5)
            divider:SetSize(2, parent:GetHeight() - 10)
            divider:SetColorTexture(0.85, 0.71, 0.48, header and 0.44 or 0.31)
        end
    end
    return cells
end

local function MakeRow(window, index)
    local row = CreateFrame("Frame", nil, window)
    row:SetSize(tableWidth, rowHeight)
    row:SetPoint("TOPLEFT", 16, -tableTop - (index - 1) * rowHeight)
    Fill(row, 0.67, 0.51, 0.28, index % 2 == 0 and 0.045 or 0.095)
    local line = row:CreateTexture(nil, "BORDER")
    line:SetPoint("BOTTOMLEFT")
    line:SetPoint("BOTTOMRIGHT")
    line:SetHeight(1)
    line:SetColorTexture(0.67, 0.51, 0.28, 0.20)
    row.cells = MakeCells(row)
    row.markIcon = row:CreateTexture(nil, "ARTWORK")
    row.markIcon:SetSize(16, 16)
    row.markIcon:SetPoint("LEFT", row.cells.marks, "LEFT", 14, 0)
    row.markCount = JournalText(row, 14, 0.96, 0.93, 0.85)
    row.markCount:SetPoint("LEFT", row.markIcon, "RIGHT", 5, 0)
    row.cells.time:SetTextColor(1, 1, 1)
    row.cells.rank:SetTextColor(1, 1, 1)
    row.cells.rep:SetTextColor(1, 1, 1)
    row.cells.honor:SetTextColor(1, 1, 1)
    return row
end

local function CharacterColor(entry)
    local class = entry.class
    if not samples and not class and entry.guid then
        if entry.guid == UnitGUID("player") then
            class = select(2, UnitClass("player"))
        elseif GetPlayerInfoByGUID then
            class = select(2, GetPlayerInfoByGUID(entry.guid))
        end
        if issecretvalue and issecretvalue(class) then class = nil end
        entry.class = class
    end
    return class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
end

local function DrawRow(row, entry)
    local cells = row.cells
    cells.name:SetText(entry.name)
    local color = CharacterColor(entry)
    if color then
        cells.name:SetTextColor(color.r, color.g, color.b)
    else
        cells.name:SetTextColor(0.96, 0.93, 0.85)
    end
    cells.map:SetText(BattlefieldName(entry.map))
    if entry.result == "win" or entry.result == "loss" then
        cells.map:SetTextColor(unpack(results[entry.result], 2))
    else
        cells.map:SetTextColor(0.96, 0.93, 0.85)
    end
    local result = results[entry.result] or results.unknown
    cells.result:SetText(result[1])
    cells.result:SetTextColor(unpack(result, 2))
    cells.time:SetText(Duration(Elapsed(entry)))
    cells.rank:SetText(entry.map ~= 30 and entry.rankPoints and Points(entry.rankPoints) or "-")
    cells.rep:SetText(Points(entry.rep))
    cells.honor:SetText(Points(entry.honor))
    local field = battlefields[entry.map]
    if field and entry.marks ~= nil then
        local icon = samples and field.icon or MarkIcon(field)
        cells.marks:SetText("")
        row.markIcon:SetTexture(icon)
        row.markIcon:Show()
        row.markCount:SetText(Points(entry.marks))
        row.markCount:Show()
    else
        row.markIcon:Hide()
        row.markCount:Hide()
        cells.marks:SetText("-")
    end
end

local function AddFilter(window, x, width, allText, selected, onSelect, keyFor, nameFor, compare)
    local dropdown = CreateFrame("DropdownButton", nil, window, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("TOPLEFT", x, -35)
    dropdown:SetSize(width, 28)
    ns.SetupTextMenu(dropdown, function(_, menu)
        local function AddChoice(key, label)
            local option = menu:CreateRadio(label, function() return selected() == key end, function()
                onSelect(key)
                page = 1
                refreshJournal()
            end)
            option:AddInitializer(function(button)
                ns.ApplyMenuFont(button.fontString, 14, "")
                return button.fontString:GetUnboundedStringWidth() + 36, 24
            end)
        end
        AddChoice(nil, allText)
        local seen, choices = {}, {}
        for _, row in ipairs(History()) do
            local key = keyFor(row)
            if not seen[key] then
                seen[key] = true
                choices[#choices + 1] = {key = key, name = nameFor(row)}
            end
        end
        table.sort(choices, compare or function(a, b) return a.name < b.name end)
        for _, choice in ipairs(choices) do AddChoice(choice.key, choice.name) end
        if #choices > 10 then menu:SetScrollMode(264) end
    end)
    return dropdown
end

local rankPanelWidth, rankPanelGap, rankPanelMinHeight = 308, 8, 622

local function RankTitle(rank, faction)
    if rank <= 0 then return PVP_RANK_0_NAME or "Без ранга" end
    local first = Enum and Enum.PvPRanks and Enum.PvPRanks.Rank_1
    if GetText and first then
        local key = ("PVP_RANK_%d_%d"):format(first + rank - 1, faction == "Alliance" and 1 or 0)
        local title = GetText(key, UnitSex("player"))
        if title and title ~= "" and title ~= key then return title end
    end
    return ("Ранг %d"):format(rank)
end

local function EstimateMatches(history, guid, progress)
    local remaining = progress.cap - progress.total
    local byMap = {}
    for _, map in ipairs(rankMaps) do byMap[map] = {} end
    for _, row in ipairs(history) do
        local map, outcome = byMap[row.map], row.result
        local gain = row.rankPoints
        -- A payout at the cap can be smaller than the match's normal reward.
        if map and (not guid or row.guid == guid) and (outcome == "win" or outcome == "loss")
            and gain and gain > 0
            and (not row.rankCap or not row.rankBefore or row.rankBefore + gain < row.rankCap) then
            local stats = map[outcome] or {total = 0, count = 0}
            stats.total, stats.count = stats.total + gain, stats.count + 1
            map[outcome] = stats
        end
    end
    local best, estimates = {}, {}
    for _, id in ipairs(rankMaps) do
        local counts = {map = id}
        estimates[#estimates + 1] = counts
        for _, outcome in ipairs({"win", "loss"}) do
            local stats = byMap[id][outcome]
            local count = remaining <= 0 and 0 or (stats and math.ceil(remaining * stats.count / stats.total))
            counts[outcome] = count
            if count and (not best[outcome] or count < best[outcome]) then best[outcome] = count end
        end
    end
    table.sort(estimates, function(a, b)
        local aw, bw = a.win or math.huge, b.win or math.huge
        if aw ~= bw then return aw < bw end
        return a.map < b.map
    end)
    return best, estimates
end

local function CenterJournalTitle(window, size)
    local header = window.TitleContainer
    header:ClearAllPoints()
    header:SetPoint("TOPLEFT", window, "TOPLEFT", 30, -1)
    header:SetPoint("TOPRIGHT", window, "TOPRIGHT", -30, -1)
    local title = header.TitleText
    title:ClearAllPoints()
    title:SetAllPoints(header)
    title:SetJustifyH("CENTER")
    title:SetJustifyV("MIDDLE")
    ns.ApplyUIFont(title, size, "")
end

local function BuildRankPanel(window)
    local pane = CreateFrame("Frame", nil, window, "DefaultPanelFlatTemplate")
    pane:SetWidth(rankPanelWidth)
    pane:SetPoint("TOPRIGHT", window, "TOPLEFT", -rankPanelGap, 0)
    pane:SetPoint("BOTTOMRIGHT", window, "BOTTOMLEFT", -rankPanelGap, 0)
    pane:EnableMouse(true)
    CenterJournalTitle(pane, 14)
    pane.TitleContainer.TitleText:SetText("Ранг PvP")
    Fill(pane.Bg, 0.105, 0.08, 0.06, 1)
    local ring = CreateFrame("Cooldown", nil, pane)
    ring:SetSize(76, 76)
    ring:SetPoint("TOP", 0, -29)
    ring:SetReverse(true)
    ring:SetRotation(math.pi)
    ring:SetHideCountdownNumbers(true)
    ring:SetDrawEdge(false)
    ring:SetDrawBling(false)
    ring:SetSwipeTexture("Interface\\PVPFrame\\pvpqueue-sidebar-honorbar-fill", 1, 1, 1, 1)
    local crest = ring:CreateTexture(nil, "BACKGROUND")
    crest:SetPoint("CENTER")
    crest:SetSize(57, 57)
    local border = ring:CreateTexture(nil, "BORDER")
    border:SetPoint("CENTER", 0, -0.5)
    border:SetSize(116, 103)
    border:SetAtlas("UI-Character-Info-Honor-Bar")
    local badge = ring:CreateTexture(nil, "ARTWORK")
    badge:SetSize(36, 42)
    badge:SetPoint("CENTER")
    ring:Pause()
    local function Line(y, size, r, g, b)
        local label = JournalText(pane, size, r, g, b)
        label:SetPoint("TOPLEFT", 12, y)
        label:SetPoint("TOPRIGHT", -12, y)
        label:SetJustifyH("CENTER")
        label:SetWordWrap(false)
        return label
    end
    local rank = Line(-111, 14, 1, 0.82, 0.41)
    rank:SetWordWrap(true)
    rank:SetMaxLines(2)
    local points = Line(-145, 12, 0.88, 0.83, 0.74)
    local caption = Line(-164, 12, 1, 0.82, 0.41)
    local bar = CreateFrame("StatusBar", nil, pane)
    bar:SetPoint("TOPLEFT", 17, -182)
    bar:SetPoint("TOPRIGHT", -17, -182)
    bar:SetHeight(19)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.58, 0.38, 0.12)
    Fill(bar, 0.08, 0.06, 0.045, 1)
    local progressText = JournalText(bar, 12, 1, 1, 1)
    progressText:SetPoint("CENTER")
    local estimates = Line(-212, 13, 0.96, 0.92, 0.83)
    local estimateHover = CreateFrame("Frame", nil, pane)
    estimateHover:SetAllPoints(estimates)
    estimateHover:EnableMouse(true)
    local sortedEstimates, targetRank
    local function ShowEstimates()
        if not sortedEstimates then return end
        GameTooltip:SetOwner(estimateHover, "ANCHOR_CURSOR")
        GameTooltip:SetText(("До ранга %d"):format(targetRank))
        GameTooltip:AddDoubleLine("Поле боя", "Побед / Поражений")
        for _, counts in ipairs(sortedEstimates) do
            GameTooltip:AddDoubleLine(battlefields[counts.map].name,
                ("%s / %s"):format(counts.win and Points(counts.win) or "-", counts.loss and Points(counts.loss) or "-"))
        end
        ns.StyleTooltipLines(GameTooltip)
        GameTooltip:Show()
    end
    estimateHover:SetScript("OnEnter", ShowEstimates)
    estimateHover:SetScript("OnLeave", function() GameTooltip:Hide() end)
    estimateHover:SetScript("OnHide", function()
        if GameTooltip:IsOwned(estimateHover) then GameTooltip:Hide() end
    end)

    local function Section(label, y)
        local divider = pane:CreateTexture(nil, "OVERLAY")
        divider:SetPoint("TOPLEFT", 13, y)
        divider:SetPoint("TOPRIGHT", -13, y)
        divider:SetHeight(2)
        divider:SetColorTexture(0.85, 0.71, 0.48, 0.52)
        Line(y - 9, 13, 1, 0.82, 0.41):SetText(label)
    end
    Section("Валюта персонажа", -236)

    local function CurrencyRow(name, y)
        local icon = pane:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 14, y)
        icon:SetSize(16, 16)
        local amount = JournalText(pane, 12, 1, 1, 1)
        amount:SetPoint("RIGHT", pane, "TOPRIGHT", -14, y - 8)
        amount:SetWidth(44)
        amount:SetJustifyH("RIGHT")
        local label = JournalText(pane, 11, 0.91, 0.87, 0.78)
        label:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        label:SetPoint("RIGHT", amount, "LEFT", -5, 0)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
        label:SetText(name)
        return {icon = icon, amount = amount}
    end

    local honorRow = CurrencyRow("Очки чести", -266)
    local markRows = {}
    for i, map in ipairs(markOrder) do
        markRows[map] = CurrencyRow(battlefields[map].name, -266 - i * 23)
    end

    local function RefreshWallet()
        local preview = sampleRank and sampleRank.wallet
        local honor = not samples and C_CurrencyInfo.GetCurrencyInfo(honorCurrency)
        local quantity = honor and ns.Number(honor.quantity) or preview and preview.honor
        honorRow.icon:SetTexture(honor and honor.iconFileID or 2173919)
        honorRow.amount:SetText(quantity and Points(quantity) or "-")
        for _, map in ipairs(markOrder) do
            local row, field = markRows[map], battlefields[map]
            local count = not samples and MarkCount(field) or preview and preview.marks[field.mark]
            row.icon:SetTexture(samples and field.icon or MarkIcon(field))
            row.amount:SetText(count and Points(count) or "-")
        end
    end

    Section("Репутация на полях боя", -386)
    local reputationRows = {}
    for i, map in ipairs(markOrder) do
        local y = -416 - (i - 1) * 48
        local name = JournalText(pane, 12, 0.96, 0.92, 0.83)
        name:SetPoint("TOPLEFT", 15, y)
        name:SetPoint("TOPRIGHT", -15, y)
        name:SetJustifyH("LEFT")
        name:SetWordWrap(false)

        local progress = CreateFrame("StatusBar", nil, pane)
        progress:SetPoint("TOPLEFT", 15, y - 18)
        progress:SetPoint("TOPRIGHT", -15, y - 18)
        progress:SetHeight(17)
        progress:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        Fill(progress, 0.17, 0.13, 0.09, 1)
        local value = JournalText(progress, 11, 1, 1, 1)
        value:SetPoint("CENTER")
        reputationRows[map] = {name = name, bar = progress, value = value}
    end

    local function RefreshReputation()
        local faction
        if samples then
            faction = sampleRank and sampleRank.faction
        else
            faction = UnitFactionGroup("player")
        end
        local preview = sampleRank and sampleRank.reputation
        for _, map in ipairs(markOrder) do
            local field, row = battlefields[map], reputationRows[map]
            local data
            if samples then
                data = preview and preview[map]
            elseif faction and field[faction] and C_Reputation and C_Reputation.GetFactionDataByID then
                data = C_Reputation.GetFactionDataByID(field[faction])
            end
            if issecretvalue and issecretvalue(data) then data = nil end
            local reaction = data and ns.Number(data.reaction)
            local start = data and ns.Number(data.currentReactionThreshold)
            local finish = data and ns.Number(data.nextReactionThreshold)
            local standing = data and ns.Number(data.currentStanding)
            local name = data and data.name
            if issecretvalue and issecretvalue(name) then name = nil end
            row.name:SetText(name or field.name)
            local color = reaction and FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
            row.bar:SetStatusBarColor(color and color.r or 0.30, color and color.g or 0.58, color and color.b or 0.35)
            local label = reaction and _G["FACTION_STANDING_LABEL" .. reaction]
            if reaction == 8 then
                row.bar:SetMinMaxValues(0, 1)
                row.bar:SetValue(1)
                row.value:SetText(label or "Превознесение")
            elseif start and finish and standing and finish > start then
                local cap = finish - start
                local value = math.max(0, math.min(cap, standing - start))
                row.bar:SetMinMaxValues(0, cap)
                row.bar:SetValue(value)
                row.value:SetFormattedText("%s%s / %s", label and label .. " - " or "", Points(value), Points(cap))
            else
                row.bar:SetMinMaxValues(0, 1)
                row.bar:SetValue(0)
                row.value:SetText("-")
            end
        end
    end

    -- Read faction updates only while the live panel is open.
    local function RefreshRank()
        local progress = sampleRank
        if not samples then progress = ReadRankProgress() end
        ring:SetShown(progress ~= nil)
        if not progress then
            rank:SetText("Ранг недоступен")
            points:SetText("")
            caption:SetText("")
            bar:Hide()
            estimates:SetText("")
            estimateHover:Hide()
            return
        end
        local faction = progress.faction or (not samples and UnitFactionGroup("player"))
        local side = faction == "Horde" and "Horde" or "Alliance"
        crest:SetAtlas("UI-Character-Info-Honor-Bar-BG-" .. side)
        badge:SetAtlas("UI-Character-Info-Honor-Icon-" .. (progress.level > 0 and progress.level or side))
        if CooldownFrame_SetDisplayAsPercentage then
            local ratio = progress.nextRank and progress.nextRank > 0 and progress.points / progress.nextRank or 1
            CooldownFrame_SetDisplayAsPercentage(ring, math.max(0, math.min(1, ratio)))
        end
        local title = RankTitle(progress.level, faction)
        local level = ("Ранг %d"):format(progress.level)
        rank:SetText(progress.level <= 0 and title or (title == level and level or (level .. " - " .. title)))
        if progress.nextRank and progress.nextRank > 0 then
            points:SetFormattedText("До нового ранга  %s / %s", Points(progress.points), Points(progress.nextRank))
        else
            points:SetFormattedText("Очки ранга  %s", Points(progress.total))
        end
        local cap = progress.cap
        if not cap or cap <= 0 or not progress.capRank then
            caption:SetText("Предел недели недоступен")
            bar:Hide()
            estimates:SetText("")
            estimateHover:Hide()
            return
        end
        caption:SetFormattedText("Предел недели - ранг %d", progress.capRank)
        bar:SetMinMaxValues(0, cap)
        bar:SetValue(math.min(progress.total, cap))
        progressText:SetFormattedText("%s / %s", Points(progress.total), Points(cap))
        bar:Show()
        local guid = not samples and UnitGUID("player") or nil
        local best, sorted = EstimateMatches(History(), guid, progress)
        sortedEstimates, targetRank = sorted, progress.capRank
        estimates:SetFormattedText("Побед %s   /   Поражений %s", best.win and Points(best.win) or "-",
            best.loss and Points(best.loss) or "-")
        estimateHover:Show()
        if GameTooltip:IsOwned(estimateHover) then ShowEstimates() end

    end

    pane:SetScript("OnEvent", function(_, event, id)
        if samples or not ns.Enabled("pvp") then return end
        if event == "UPDATE_FACTION" or (event == "MAJOR_FACTION_RENOWN_LEVEL_CHANGED" and ns.Number(id) == rankFaction) then
            RefreshRank()
            if event == "UPDATE_FACTION" then RefreshReputation() end
        elseif event == "BAG_UPDATE_DELAYED" or event == "BANKFRAME_OPENED" or event == "PLAYERBANKSLOTS_CHANGED"
            or (event == "CURRENCY_DISPLAY_UPDATE" and (id == nil or ns.Number(id) == honorCurrency)) then
            RefreshWallet()
        end
    end)
    pane:SetScript("OnShow", function(self)
        if not samples then
            self:RegisterEvent("UPDATE_FACTION")
            self:RegisterEvent("MAJOR_FACTION_RENOWN_LEVEL_CHANGED")
            self:RegisterEvent("BAG_UPDATE_DELAYED")
            self:RegisterEvent("BANKFRAME_OPENED")
            self:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
            self:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
        end
    end)
    pane:SetScript("OnHide", pane.UnregisterAllEvents)
    return pane, function()
        RefreshRank()
        RefreshWallet()
        RefreshReputation()
    end
end

local function BuildJournal()
    local window, close = ns.CreateLootPanel("RainonUIForeverBattleJournal", "Журнал полей боя", tableWidth + 32, tableTop + 2 * rowHeight + 16)
    window:SetPoint("CENTER")
    local rankPanel, refreshRankPanel, shownRankPanel
    CenterJournalTitle(window, 15)
    window:SetMovable(true)
    local title = window.TitleContainer
    title:EnableMouse(true)
    title:RegisterForDrag("LeftButton")
    title:SetScript("OnDragStart", function() window:StartMoving() end)
    title:SetScript("OnDragStop", function() window:StopMovingOrSizing() end)
    window:SetScript("OnHide", window.StopMovingOrSizing)
    tinsert(UISpecialFrames, window:GetName())

    local grow, shrink
    local scale = math.max(minScale, math.min(maxScale, ns.Number(ns.db.battleJournalScale) or 100))
    local function ApplyScale()
        local sideWidth = shownRankPanel and rankPanelWidth + rankPanelGap or 0
        local fitWidth = UIParent:GetWidth() / (window:GetWidth() + sideWidth + 12)
        local fitHeight = UIParent:GetHeight() / (window:GetHeight() + 12)
        window:SetScale(math.min(scale / 100, fitWidth, fitHeight))
        grow:SetEnabled(scale < maxScale)
        shrink:SetEnabled(scale > minScale)
    end
    local function ChangeScale(step)
        scale = math.max(minScale, math.min(maxScale, scale + step))
        ns.db.battleJournalScale = scale
        ApplyScale()
    end
    grow = ns.CreateLootSizeButton(window, close, "RedButton-Expand", "RedButton-Expand-Disabled", function()
        ChangeScale(scaleStep)
    end)
    shrink = ns.CreateLootSizeButton(window, grow, "RedButton-Condense", "RedButton-Condense-disabled", function()
        ChangeScale(-scaleStep)
    end)
    ApplyScale()

    local filterGap = 8
    local filterWidth = (tableWidth - filterGap * 2) / 3
    local filterStep = filterWidth + filterGap
    characterFilter = AddFilter(window, 16, filterWidth, "Все персонажи",
        function() return character end, function(key) character = key end, CharacterKey, function(row) return row.name end)
    battlefieldFilter = AddFilter(window, 16 + filterStep, filterWidth, "Все поля боя",
        function() return battlefield end, function(key) battlefield = key end,
        function(row) return row.map or 0 end, function(row) return BattlefieldName(row.map) end)
    dateFilter = AddFilter(window, 16 + 2 * filterStep, filterWidth, "Все даты",
        function() return battleDate end, function(key) battleDate = key end, BattleDate,
        function(row) return DateLabel(BattleDate(row)) end, function(a, b)
            return a.key ~= noDate and (b.key == noDate or a.key > b.key)
        end)

    local header = CreateFrame("Frame", nil, window)
    header:SetSize(tableWidth, 32)
    header:SetPoint("TOPLEFT", 16, -tableTop + header:GetHeight())
    Fill(header, 0.28, 0.22, 0.14, 0.85)
    MakeCells(header, true)

    local rows, filtered = {}, {}
    for i = 1, pageSize do rows[i] = MakeRow(window, i) end

    local pageFooterHeight = 50
    local pagination = CreateFrame("Frame", nil, window)
    pagination:SetSize(132, 24)
    pagination:SetPoint("CENTER", window, "BOTTOM", 0, (pageFooterHeight + 8) / 2)
    local function PageButton(direction, x, step)
        local button = CreateFrame("Button", nil, window)
        button:SetPoint("CENTER", pagination, "CENTER", x, 0)
        button:SetSize(24, 24)
        local art = "Interface\\Buttons\\UI-SpellbookIcon-" .. direction .. "Page"
        button:SetNormalTexture(art .. "-Up")
        button:SetPushedTexture(art .. "-Down")
        button:SetDisabledTexture(art .. "-Disabled")
        button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        button:SetScript("OnClick", function()
            page = page + step
            refreshJournal()
        end)
        return button
    end
    local back = PageButton("Prev", -54, -1)
    local nextPage = PageButton("Next", 54, 1)
    local status = JournalText(window, 13, 0.83, 0.77, 0.66)
    status:SetPoint("CENTER", pagination, "CENTER")
    local empty = JournalText(window, 15, 0.83, 0.77, 0.66)
    empty:SetPoint("TOP", 0, -tableTop - 25)

    refreshJournal = function()
        if not window:IsShown() then return end
        local data = History()
        local showRankPanel = samples and sampleRank ~= nil or (not samples and ns.Enabled("pvpRankPanel"))
        if shownRankPanel ~= showRankPanel then
            shownRankPanel = showRankPanel
            local sideWidth = showRankPanel and rankPanelWidth + rankPanelGap or 0
            window:StopMovingOrSizing()
            window:SetClampRectInsets(-sideWidth, 0, 0, 0)
            window:ClearAllPoints()
            window:SetPoint("CENTER", UIParent, "CENTER", sideWidth / 2, 0)
        end
        if showRankPanel and not rankPanel then
            rankPanel, refreshRankPanel = BuildRankPanel(window)
        end
        if rankPanel then rankPanel:SetShown(showRankPanel) end
        if showRankPanel then refreshRankPanel() end
        wipe(filtered)
        for i = #data, 1, -1 do
            local row = data[i]
            if (not character or CharacterKey(row) == character)
                and (not battlefield or (row.map or 0) == battlefield)
                and (not battleDate or BattleDate(row) == battleDate) then
                filtered[#filtered + 1] = row
            end
        end
        local pages = math.max(1, math.ceil(#filtered / pageSize))
        page = math.max(1, math.min(page, pages))
        local paged = pages > 1
        back:SetShown(paged)
        nextPage:SetShown(paged)
        status:SetShown(paged)
        back:SetEnabled(page > 1)
        nextPage:SetEnabled(page < pages)
        status:SetFormattedText("%d / %d", page, pages)
        empty:SetShown(#filtered == 0)
        empty:SetText(#data == 0 and "Записей о полях боя пока нет" or "По этим фильтрам записей нет")
        for i, row in ipairs(rows) do
            local entry = filtered[(page - 1) * pageSize + i]
            row:SetShown(entry ~= nil)
            if entry then DrawRow(row, entry) end
        end
        local fullPageRows = math.min(pageSize, #filtered)
        local height = tableTop + math.max(2, fullPageRows) * rowHeight + (paged and pageFooterHeight or 16)
        if showRankPanel then height = math.max(rankPanelMinHeight, height) end
        window:SetHeight(height)
        ApplyScale()
    end

    local elapsed = 0
    window:SetScript("OnUpdate", function(_, delta)
        if not entered or samples then return end
        elapsed = elapsed + delta
        if elapsed < 1 then return end
        elapsed = 0
        for i, row in ipairs(rows) do
            if filtered[(page - 1) * pageSize + i] == active then
                row.cells.time:SetText(Duration(Elapsed(active)))
                break
            end
        end
    end)
    return window
end

function ns.OpenBattleJournal(preview, previewRank)
    if not ns.db or (not preview and not ns.Enabled("pvp")) then return end
    if preview or not journal or samples ~= preview then
        character, battlefield, battleDate, page = nil, nil, nil, 1
    end
    samples, sampleRank = preview, previewRank
    if not samples then FillHistoricalResults() end
    journal = journal or BuildJournal()
    journal.TitleContainer.TitleText:SetText(samples and "Журнал полей боя - пример" or "Журнал полей боя")
    if journal:IsShown() then journal:Hide() end
    journal:Show()
    characterFilter:GenerateMenu()
    battlefieldFilter:GenerateMenu()
    dateFilter:GenerateMenu()
    refreshJournal()
end
