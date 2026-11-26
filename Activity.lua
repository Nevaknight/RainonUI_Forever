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
local reminder, hideTimer
local function HideReminder()
    if hideTimer then hideTimer:Cancel() end
    hideTimer = nil
    if reminder then reminder:Hide() end
end

function ns.ShowCoinReminder()
    HideReminder()
    if not reminder then
        local frame, label = ns.CreateTimerBox()
        reminder = frame
        frame:SetPoint("CENTER")
        local info = C_CurrencyInfo.GetCurrencyInfo(coinCurrency)
        label:SetFormattedText("|T%d:20:20|t Полутай босса!", info and info.iconFileID or coinFallbackIcon)
    end
    reminder:Show()
    hideTimer = C_Timer.NewTimer(10, HideReminder)
end

ns.AddSetting("bossCoin", "Напоминать о монетке босса", HideReminder, true, "general", {
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
    if reminder and reminder:IsShown() and not (issecretvalue and issecretvalue(message))
        and tonumber(message:match("currency:(%d+)")) == coinCurrency then HideReminder() end
end)
ns.On("PLAYER_LEAVING_WORLD", HideReminder)

local battlefields = {
    [489] = "Ущелье Песни Войны",
    [529] = "Низина Арати",
    [30] = "Альтеракская долина",
    [2997] = "Острова Чёрного Копья",
}
local active, entered, refreshJournal
local rankFaction = 2800
local function ReadRankTotal()
    local factions = C_MajorFactions
    if not (factions and factions.GetMajorFactionProgressionInfo and factions.GetTotalReputationForRenownLevel) then
        return
    end
    local info = factions.GetMajorFactionProgressionInfo(rankFaction)
    if (issecretvalue and issecretvalue(info)) or not info then return end
    local level, points = ns.Number(info.renownLevel), ns.Number(info.renownReputationEarned)
    if not (level and points) then return end
    local base = ns.Number(factions.GetTotalReputationForRenownLevel(rankFaction, level))
    if base then return base + points end
end

local rankTimer
local rankExitDelay = 5
local function UpdateRankPoints(row, final)
    if not row or not row.rankBefore or row.guid ~= UnitGUID("player") then return end
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

local function CheckRankAfterFinish(row)
    if not row.rankBefore then return end
    CancelRankCheck()
    UpdateRankPoints(row)
    rankTimer = C_Timer.NewTimer(2, function()
        rankTimer = nil
        if active == row then UpdateRankPoints(row) end
    end)
end

local function CheckRankAfterExit(row)
    if not row.rankBefore then return end
    CancelRankCheck()
    UpdateRankPoints(row)
    local delay = row.rankCheckUntil - GetServerTime()
    if delay <= 0 then return end
    rankTimer = C_Timer.NewTimer(delay, function()
        rankTimer = nil
        row.rankCheckUntil = nil
        local _, kind = GetInstanceInfo()
        if not active and kind ~= "pvp" and kind ~= "arena" then UpdateRankPoints(row, true) end
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
    CheckRankAfterFinish(active)
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
    if active and (active.result or active.rankFinished) then
        active.rankLeftAt = GetServerTime()
    end
    CancelRankCheck()
    PauseBattle()
end

local function SyncBattle()
    if not ns.db then return end
    local guid = UnitGUID("player")
    if not guid then return end
    local _, kind, _, _, _, _, _, map = GetInstanceInfo()
    local history = ns.db.battleHistory or {}
    -- A character can reload or switch characters before leaving the match.
    local last
    for i = #history, 1, -1 do
        if history[i].guid == guid then last = history[i]; break end
    end
    local inBattle = ns.Enabled("battleLog") and kind == "pvp"
    local runtime = inBattle and GetBattlefieldInstanceRunTime and ns.Number(GetBattlefieldInstanceRunTime())
    local start = runtime and runtime > 0 and GetServerTime() - math.floor(runtime / 1000)
    if last and last.open and (not inBattle or last.map ~= map
        or (last.started and start and math.abs(last.started - start) > 5)) then
        last.open = nil
        local now = GetServerTime()
        if ns.Enabled("battleLog") and kind ~= "pvp" and kind ~= "arena"
            and last.rankLeftAt and now - last.rankLeftAt <= rankExitDelay and last.rankBefore then
            last.rankCheckUntil = now + rankExitDelay
        end
        last.rankLeftAt = nil
    end
    if not inBattle then
        PauseBattle()
        if ns.Enabled("battleLog") and kind ~= "pvp" and kind ~= "arena"
            and last and last.rankCheckUntil and last.rankCheckUntil > GetServerTime() then
            CheckRankAfterExit(last)
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
        last = {guid = guid, name = ns.CharacterIdentity(), map = map, started = start,
            seconds = 0, honor = 0, rep = 0, open = true,
            recordedAt = GetServerTime(), rankBefore = ReadRankTotal()}
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
    if last.result or last.rankFinished then CheckRankAfterFinish(last) end
    ReadResult()
    if refreshJournal then refreshJournal() end
end

ns.AddSetting("battleLog", "Записывать поля боя", SyncBattle, true, "general", {
    wrapTitle = true, icon = 132485, tooltip = "Alt + ЛКМ по значку RainonUI открывает журнал полей боя.",
})
ns.On("PLAYER_ENTERING_WORLD", SyncBattle)
ns.On("PLAYER_LEAVING_WORLD", LeaveBattle)
ns.On("PLAYER_LOGOUT", LeaveBattle)
ns.On("PVP_MATCH_COMPLETE", function(winner)
    if not active or active.result or active.rankFinished then return end
    active.rankFinished = true
    RecordResult(winner)
    if not active.result then CheckRankAfterFinish(active) end
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
}
local results = {
    win = {"Победа", 0.61, 0.87, 0.55},
    loss = {"Поражение", 1, 0.54, 0.49},
    draw = {"Ничья", 0.83, 0.77, 0.66},
    unknown = {"—", 0.70, 0.65, 0.57},
}
local journal, samples, page, character, battlefield, battleDate
local characterFilter, battlefieldFilter, dateFilter
local pageSize, rowHeight, tableTop = 10, 35, 107
local minScale, maxScale, scaleStep = 60, 160, 10
local tableWidth = 0
for _, column in ipairs(columns) do tableWidth = tableWidth + column.width end

local function History()
    return samples or ns.db.battleHistory or {}
end

local function CharacterKey(row)
    return row.guid or row.name
end

local function BattlefieldName(map)
    return battlefields[map] or (map and ("Поле боя №" .. map) or "Неизвестное поле боя")
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
    return points < 0 and whole > 0 and ("−" .. digits) or digits
end

local function JournalText(parent, size, r, g, b)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetFont(ns.CYRILLIC_FONT, size, "")
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
            divider:SetSize(1, parent:GetHeight() - 10)
            divider:SetColorTexture(0.85, 0.71, 0.48, header and 0.30 or 0.20)
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
    row.cells.time:SetTextColor(1, 1, 1)
    row.cells.rank:SetTextColor(1, 1, 1)
    row.cells.rep:SetTextColor(1, 1, 1)
    row.cells.honor:SetTextColor(1, 1, 1)
    return row
end

local function CharacterColor(entry)
    local class = entry.class
    if not class and entry.guid then
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
    cells.rank:SetText(entry.rankPoints and Points(entry.rankPoints) or "—")
    cells.rep:SetText(Points(entry.rep))
    cells.honor:SetText(Points(entry.honor))
end

local menuFont = CreateFont("RainonUIForeverBattleJournalMenuFont")
menuFont:SetFont(ns.CYRILLIC_FONT, 14, "")

local function AddFilter(window, x, width, allText, selected, onSelect, keyFor, nameFor, compare)
    local dropdown = CreateFrame("DropdownButton", nil, window, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("TOPLEFT", x, -35)
    dropdown:SetSize(width, 28)
    if dropdown.Text then dropdown.Text:SetFontObject(menuFont) end
    dropdown:SetupMenu(function(_, menu)
        local function AddChoice(key, label)
            local option = menu:CreateRadio(label, function() return selected() == key end, function()
                onSelect(key)
                page = 1
                refreshJournal()
            end)
            option:AddInitializer(function(button)
                button.fontString:SetFontObject(menuFont)
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

local function BuildJournal()
    local window, close = ns.CreateLootPanel("RainonUIForeverBattleJournal", "Журнал полей боя", tableWidth + 32, 395)
    window:SetPoint("CENTER")
    window.TitleContainer.TitleText:SetFont(ns.CYRILLIC_FONT, 15, "")
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
        window:SetScale(scale / 100)
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

    local function PageButton(direction, x, step)
        local button = CreateFrame("Button", nil, window)
        button:SetPoint("BOTTOM", x, 12)
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
    status:SetPoint("BOTTOM", 0, 19)
    local empty = JournalText(window, 15, 0.83, 0.77, 0.66)
    empty:SetPoint("TOP", 0, -tableTop - 25)

    refreshJournal = function()
        if not window:IsShown() then return end
        local data = History()
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
        window:SetHeight(tableTop + math.max(2, math.min(pageSize, #filtered)) * rowHeight + (paged and 48 or 16))
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

function ns.OpenBattleJournal(preview)
    if not ns.db then return end
    if preview or not journal or samples ~= preview then
        character, battlefield, battleDate, page = nil, nil, nil, 1
    end
    samples = preview
    if not samples then FillHistoricalResults() end
    journal = journal or BuildJournal()
    journal.TitleContainer.TitleText:SetText(samples and "Журнал полей боя — пример" or "Журнал полей боя")
    journal:Show()
    characterFilter:GenerateMenu()
    battlefieldFilter:GenerateMenu()
    dateFilter:GenerateMenu()
    refreshJournal()
end
