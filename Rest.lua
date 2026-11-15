local _, ns = ...
local key
local refreshPage
local BASE_CAP = 1.5
local BASE_RATE = 0.05 / (8 * 3600)
local LEGACY = 1.2

function ns.ProjectRest(snapshot, now)
    if not snapshot or snapshot.maxXP <= 0 then return end
    local factor = snapshot.wellRested and LEGACY or 1
    local cap = math.max(snapshot.xp, math.floor(snapshot.maxXP * BASE_CAP * factor))
    local perSecond = snapshot.maxXP * BASE_RATE * factor * (snapshot.resting and 1 or 0.25)
    local xp = math.min(cap, snapshot.xp + math.max(0, now - snapshot.at) * perSecond)
    return math.floor(xp), cap, math.max(0, (cap - xp) / perSecond)
end

local function NameKey(name, realm)
    return "name:" .. name .. ":" .. (realm or "")
end

local function RememberCharacter(guid, name, realm, level)
    if not name then return end
    local roster = ns.db.restCharacters
    local qualified, unqualified = NameKey(name, realm), NameKey(name)
    local character = roster[guid] or roster[qualified] or roster[unqualified] or {}
    roster[guid] = character
    roster[qualified], roster[unqualified] = nil, nil
    character.name = name
    character.realm = realm or character.realm
    character.level = level or character.level
    return character
end

local function AddNamedCharacter(name, realm, level)
    if not name then return end
    local roster = ns.db.restCharacters
    for _, character in pairs(roster) do
        if character.name == name and (not realm or not character.realm or realm == character.realm) then
            character.realm = character.realm or realm
            character.level = character.level or level
            return
        end
    end
    roster[NameKey(name, realm)] = { name = name, realm = realm, level = level }
end

local function MergeKnownCharacters()
    for guid, character in pairs(ns.db.characters or {}) do
        if not ns.db.restCharacters[guid] then
            RememberCharacter(guid, character.name, character.realm, character.level)
        end
    end
    for guid, snapshot in pairs(ns.db.rest) do
        local character = ns.db.restCharacters[guid] or RememberCharacter(guid, snapshot.name, snapshot.realm, snapshot.level)
        if character then
            character.level = character.level or snapshot.level
            if character.wellRested == nil then character.wellRested = snapshot.wellRested end
        end
    end
    local api = Syndicator and Syndicator.API
    if api and api.GetAllCharacters and api.GetCharacter then
        for _, fullName in ipairs(api.GetAllCharacters()) do
            local cached = api.GetCharacter(fullName)
            local details = cached and cached.details
            if details then AddNamedCharacter(details.character, details.realm, details.level) end
        end
    end
    if ns.GetLocalCharacterNames then
        local name = ns.CharacterIdentity()
        for _, knownName in ipairs(ns.GetLocalCharacterNames(name)) do
            AddNamedCharacter(knownName)
        end
    end
end

local function Update(loggingOut)
    if not ns.db then return end
    key = UnitGUID("player")
    if not key then return end
    local name, realm = ns.CharacterIdentity()
    local level = ns.Number(UnitLevel("player"))
    local character = RememberCharacter(key, name, realm, level and level > 0 and level or nil)
    if not character or not level or level <= 0 then return end

    local previous = ns.db.rest[key]
    if character.wellRested == nil and previous then character.wellRested = previous.wellRested end

    local maxLevel = (GetMaxPlayerLevel and GetMaxPlayerLevel()) or 60
    character.atMaxLevel = level >= maxLevel
    if not ns.Enabled("rest") or character.paused or character.removed then return end
    if character.atMaxLevel then
        ns.db.rest[key] = nil
        return
    end

    local maxXP = ns.Number(UnitXPMax("player"))
    if not maxXP or maxXP <= 0 then return end
    local raw = GetXPExhaustion()
    if issecretvalue and issecretvalue(raw) then return end
    local xp = ns.Number(raw)
    if loggingOut and xp == nil and previous and previous.level == level then
        xp = previous.xp
    end
    local now = GetServerTime()
    local reading = {
        name = name,
        realm = realm,
        level = level,
        maxXP = maxXP,
        xp = xp or 0,
        at = now,
        resting = IsResting() and true or false,
        wellRested = character.wellRested == true,
        samples = previous and previous.samples or {},
    }
    local last = reading.samples[#reading.samples]
    if not last or last.xp ~= reading.xp or last.level ~= reading.level or last.resting ~= reading.resting
        or last.wellRested ~= reading.wellRested or now - last.at >= 3600 then
        reading.samples[#reading.samples + 1] = {
            xp = reading.xp, maxXP = maxXP, at = now, level = reading.level,
            resting = reading.resting, wellRested = reading.wellRested,
        }
        if #reading.samples > 48 then table.remove(reading.samples, 1) end
    end
    ns.db.rest[key] = reading
end

local function Refresh()
    Update()
    if refreshPage then refreshPage() end
end

local ROW_HEIGHT = 63

local function MakeRestRow(content, index, bookText)
    local row = CreateFrame("Frame", nil, content)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
    row:SetPoint("TOPRIGHT", -4, -(index - 1) * ROW_HEIGHT)

    row.name = bookText(row, "SystemFont_Large", "")
    row.name:SetPoint("TOPLEFT")
    row.name:SetMaxLines(1)
    row.level = bookText(row, "SystemFont_Large", "")
    row.level:SetPoint("LEFT", row.name, "RIGHT", 5, 0)

    row.wellRested = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.wellRested:SetSize(22, 22)
    row.wellRested:SetPoint("LEFT", row.level, "RIGHT", 6, 0)
    row.wellRested:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Хороший отдых")
        GameTooltip:AddLine("У этого персонажа вложено 5/5 очков наследия в «Хороший отдых».", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    row.wellRested:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.wellRested:SetScript("OnClick", function(self)
        local enabled = not not self:GetChecked()
        row.character.wellRested = enabled
        local snapshot = ns.db.rest[row.guid]
        if snapshot then snapshot.wellRested = enabled end
        if row.guid == key then Update() end
        refreshPage()
    end)

    row.amount = bookText(row, "SystemFont_Med1", "")
    row.amount:SetPoint("TOPRIGHT", 0, -3)
    row.amount:SetJustifyH("RIGHT")

    local bar = CreateFrame("StatusBar", nil, row)
    bar:SetHeight(11)
    bar:SetPoint("TOPLEFT", 3, -25)
    bar:SetPoint("TOPRIGHT", -3, -25)
    bar:SetMinMaxValues(0, 1)
    local background = bar:CreateTexture(nil, "BACKGROUND")
    background:SetColorTexture(0.16, 0.09, 0.05, 0.85)
    background:SetAllPoints()

    local fill = bar:CreateTexture(nil, "ARTWORK")
    fill:SetAtlas("UI-HUD-ExperienceBar-Fill-Rested")
    bar:SetStatusBarTexture(fill)

    local rim = bar:CreateTexture(nil, "OVERLAY")
    rim:SetAtlas("UI-HUD-ExperienceBar-Frame")
    rim:SetPoint("TOPLEFT", -3, 3)
    rim:SetPoint("BOTTOMRIGHT", 3, -3)
    row.bar = bar

    row.status = bookText(row, "SystemFont_Med1", "")
    row.status:SetPoint("TOPLEFT", 0, -43)
    return row
end

local function CharacterEntries(includeRemoved)
    local entries = {}
    for guid, character in pairs(ns.db.restCharacters) do
        if includeRemoved or not character.removed then
            local name = character.name
            if character.realm and character.realm ~= "" then
                name = ("%s (%s)"):format(name, character.realm)
            end
            entries[#entries + 1] = { guid = guid, name = name, character = character }
        end
    end
    return entries
end

local function ByName(a, b)
    if a.name ~= b.name then return a.name < b.name end
    return a.guid < b.guid
end

local function AddCharacterDropdown(page)
    local dropdown = CreateFrame("DropdownButton", nil, page, "WowStyle1DropdownTemplate")
    dropdown:SetDefaultText("Управление списком")
    dropdown:SetWidth(194)
    dropdown:SetPoint("TOPRIGHT", -4, -1)
    dropdown:SetupMenu(function(_, menu)
        local entries = CharacterEntries(true)
        if #entries == 0 then
            menu:CreateButton("Нет персонажей"):SetEnabled(false)
            return
        end
        table.sort(entries, ByName)

        local removed = {}
        local visibleCount = 0
        for _, entry in ipairs(entries) do
            local character, guid = entry.character, entry.guid
            if character.removed then
                removed[#removed + 1] = entry
            else
                visibleCount = visibleCount + 1
                local submenu = menu:CreateButton(entry.name)
                local tracking = submenu:CreateCheckbox("Отслеживать отдых", function()
                    return not character.paused
                end, function()
                    character.paused = not character.paused or nil
                    if guid == key and not character.paused then Update() end
                    refreshPage()
                    return MenuResponse.Refresh
                end)
                tracking:SetSelectionIgnored()
                submenu:CreateButton("Удалить из списка", function()
                    character.removed = true
                    refreshPage()
                    return MenuResponse.CloseAll
                end)
            end
        end

        local maxRows = 12
        if #removed > 0 then
            local submenu = menu:CreateButton("Удалённые из списка")
            if #removed > maxRows then submenu:SetScrollMode(maxRows * 20) end
            for _, entry in ipairs(removed) do
                local character, guid = entry.character, entry.guid
                submenu:CreateButton("Вернуть: " .. entry.name, function()
                    character.removed = nil
                    if guid == key then Update() end
                    refreshPage()
                    return MenuResponse.CloseAll
                end)
            end
            visibleCount = visibleCount + 1
        end
        if visibleCount > maxRows then menu:SetScrollMode(maxRows * 20) end
    end)
end

function ns.BuildRestPage(page, bookText, top)
    local message = bookText(page, "SystemFont_Med1", "")
    message:SetPoint("TOPLEFT", 0, top)

    local scroll = CreateFrame("ScrollFrame", nil, page, "ScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, top)
    scroll:SetPoint("BOTTOMRIGHT", -24, 0)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    scroll:HookScript("OnSizeChanged", function(_, width) content:SetWidth(math.max(1, width)) end)
    local function UpdateScrollbar()
        local range = scroll:GetVerticalScrollRange()
        scroll.ScrollBar:SetShown(range > 0)
        if scroll:GetVerticalScroll() > range then scroll:SetVerticalScroll(range) end
    end
    scroll:HookScript("OnScrollRangeChanged", UpdateScrollbar)

    local rows = {}
    refreshPage = function()
        if not page:IsVisible() then return end
        local tracking = ns.Enabled("rest")
        local now = GetServerTime()
        local entries = CharacterEntries(false)
        for _, entry in ipairs(entries) do
            local character = entry.character
            local snapshot = ns.db.rest[entry.guid]
            entry.showBar = tracking and not character.paused and not character.atMaxLevel
            if entry.showBar and snapshot and snapshot.level == character.level then
                entry.xp, entry.cap, entry.seconds = ns.ProjectRest(snapshot, entry.guid == key and snapshot.at or now)
            end
        end
        table.sort(entries, function(a, b)
            local xpA, xpB = a.xp or -1, b.xp or -1
            if xpA ~= xpB then return xpA > xpB end
            return ByName(a, b)
        end)

        local hasEntries = #entries > 0
        message:SetText(tracking and "Пока нет известных персонажей." or "Включи «Отслеживать отдых» во вкладке «Общие».")
        message:SetShown(not tracking or not hasEntries)
        scroll:SetPoint("TOPLEFT", 0, tracking and top or top - 25)
        scroll:SetShown(hasEntries)
        local width = math.max(1, scroll:GetWidth())
        content:SetWidth(width)

        for i, entry in ipairs(entries) do
            local row = rows[i] or MakeRestRow(content, i, bookText)
            rows[i] = row
            local character = entry.character
            row.guid, row.character = entry.guid, character
            row.name:SetText(entry.name)
            row.level:SetFormattedText("ур. %s", character.level or "?")
            local maxNameWidth = width - row.level:GetUnboundedStringWidth() - 182
            row.name:SetWidth(math.min(row.name:GetUnboundedStringWidth() + 1, math.max(1, maxNameWidth)))
            row.wellRested:SetChecked(character.wellRested == true)

            local xp, cap, seconds = entry.xp, entry.cap, entry.seconds
            row.bar:SetShown(entry.showBar)
            row.status:SetShown(tracking)
            row.amount:SetShown(xp ~= nil)
            if xp then
                row.amount:SetFormattedText("%s / %s опыта", BreakUpLargeNumbers(xp), BreakUpLargeNumbers(cap))
                row.bar:SetMinMaxValues(0, cap)
                row.bar:SetValue(xp)
                local status = seconds > 0 and ("До максимума: около %d ч."):format(math.ceil(seconds / 3600))
                    or "Отдых накоплен"
                row.status:SetText(entry.guid == key and status or ("Оценка вне игры. " .. status))
            else
                row.bar:SetMinMaxValues(0, 1)
                row.bar:SetValue(0)
                if character.paused then
                    row.status:SetText("Отслеживание выключено")
                elseif character.atMaxLevel then
                    row.status:SetText("Максимальный уровень")
                else
                    row.status:SetText("Первый замер при входе на персонажа")
                end
            end
            row:Show()
        end
        for i = #entries + 1, #rows do rows[i]:Hide() end
        content:SetHeight(math.max(1, #entries * ROW_HEIGHT))
        UpdateScrollbar()
    end

    AddCharacterDropdown(page)

    local elapsed = 0
    page:SetScript("OnShow", function()
        elapsed = 0
        MergeKnownCharacters()
        Refresh()
    end)
    page:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed < 60 then return end
        elapsed = elapsed % 60
        refreshPage()
    end)
end

ns.AddSetting("rest", "Отслеживать отдых", Refresh)
ns.On("PLAYER_LOGOUT", function() Update(true) end)
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_UPDATE_RESTING", "UPDATE_EXHAUSTION", "PLAYER_XP_UPDATE" }) do
    ns.On(event, Refresh)
end
