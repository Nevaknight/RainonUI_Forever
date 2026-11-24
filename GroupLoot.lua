local _, ns = ...

local history = C_LootHistory
local rollStates = Enum.EncounterLootDropRollState
local rollTypes = Enum.LootRollType

ns.LootQualityNames = { [2] = "Необычное", [3] = "Редкое" }
ns.AutoGreedIgnoreOptions = {
    { "recipes", "Рецепты", "Interface\\Icons\\INV_Scroll_03" },
    { 20520, "Dark Rune", 136192 },
    { 12662, "Demonic Rune", 134417 },
    { 12843, "Corruptor's Scourgestone", 133445 },
}

function ns.IsAutoGreedIgnored(key)
    local ignored = ns.db and ns.db.autoGreedIgnored
    return type(ignored) == "table" and ignored[key] == true
end

function ns.ToggleAutoGreedIgnored(key)
    if type(ns.db.autoGreedIgnored) ~= "table" then ns.db.autoGreedIgnored = {} end
    ns.db.autoGreedIgnored[key] = not ns.IsAutoGreedIgnored(key) or nil
end

function ns.IsLootQualitySelected(feature, quality)
    local selected = ns.db and ns.db[feature .. "Qualities"]
    return ns.LootQualityNames[quality] ~= nil and type(selected) == "table" and selected[quality] == true
end

function ns.HasLootQualitySelected(feature)
    return ns.IsLootQualitySelected(feature, 2) or ns.IsLootQualitySelected(feature, 3)
end

local function SafeString(value)
    if type(value) == "string" and not (issecretvalue and issecretvalue(value)) then return value end
end

local roleIcons = {
    TANK = "|A:roleicon-tiny-tank:12:12|a ",
    HEALER = "|A:roleicon-tiny-healer:12:12|a ",
    DAMAGER = "|A:roleicon-tiny-dps:12:12|a ",
}

local function RoleIcon(guid)
    local unit = guid and UnitTokenFromGUID and SafeString(UnitTokenFromGUID(guid))
    local role = unit and UnitGroupRolesAssigned and SafeString(UnitGroupRolesAssigned(unit))
    return roleIcons[role] or ""
end

local panel, content
local rows, drops, updates = {}, {}, {}
local renderPending, preview
local rowHeight, contentWidth = 42, 288
local resultDuration = 3
local minPanelHeight = rowHeight + 38

local function BorderHeight(top, bottom)
    if not top or not bottom then return 0 end
    local _, _, _, _, topOffset = top:GetPoint()
    local _, _, _, _, bottomOffset = bottom:GetPoint()
    return top:GetHeight() + bottom:GetHeight() - (topOffset or 0) + (bottomOffset or 0) + 1
end

local function CreatePanel()
    local close
    panel, close = ns.CreateLootPanel("RainonUIForeverGroupLoot", "Кто выбрал «Нужно»", 312, minPanelHeight)
    local border = panel.NineSlice
    if border then
        -- Keep the original corner atlases and leave room for both side edges.
        minPanelHeight = math.max(minPanelHeight,
            BorderHeight(border.TopLeftCorner, border.BottomLeftCorner),
            BorderHeight(border.TopRightCorner, border.BottomRightCorner))
    end
    local position = ns.db.groupNeedPosition
    if position then
        panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", position.x, position.y)
    else
        panel:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -80, -140)
    end
    panel:SetMovable(true)
    close:SetScript("OnClick", function()
        for _, entry in pairs(drops) do entry.dismissed = true end
        preview = nil
        panel:Hide()
    end)
    local title = panel.TitleContainer
    title:EnableMouse(true)
    title:RegisterForDrag("LeftButton")
    title:SetScript("OnDragStart", function() panel:StartMoving() end)
    title:SetScript("OnDragStop", function()
        panel:StopMovingOrSizing()
        local left, top = panel:GetLeft(), panel:GetTop()
        if left and top then
            local x, y = left - (UIParent:GetLeft() or 0), top - (UIParent:GetBottom() or 0)
            panel:ClearAllPoints()
            panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
            ns.db.groupNeedPosition = { x = x, y = y }
        end
    end)
    panel:HookScript("OnHide", function() panel:StopMovingOrSizing() end)

    content = CreateFrame("Frame", nil, panel)
    content:SetPoint("TOPLEFT", 12, -30)
    content:SetSize(contentWidth, 1)
end

local function CreateRow()
    local row = CreateFrame("Frame", nil, content)
    row:SetWidth(contentWidth)
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetHyperlink(self.link)
        GameTooltip:AddLine(self.votes, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    row:HookScript("OnHide", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(30, 30)
    row.icon:SetPoint("TOPLEFT", 0, -2)
    row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.name:SetPoint("TOPLEFT", 36, -2)
    row.name:SetWidth(contentWidth - 36)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.voters = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.voters:SetPoint("TOPLEFT", 36, -19)
    row.voters:SetWidth(contentWidth - 36)
    row.voters:SetJustifyH("LEFT")
    row.voters:SetWordWrap(true)
    return row
end

local function DrawNeed()
    local entries = {}
    for key, entry in pairs(drops) do
        if ns.Enabled("groupNeed") and ns.IsLootQualitySelected("groupNeed", entry.quality) then
            if not entry.dismissed then entries[#entries + 1] = entry end
        else
            drops[key] = nil
        end
    end
    if preview then entries[#entries + 1] = preview end
    if #entries == 0 then
        if panel then panel:Hide() end
        return
    end
    table.sort(entries, function(a, b)
        if a.start ~= b.start then return a.start > b.start end
        return a.key < b.key
    end)
    if not panel then CreatePanel() end
    local height = 0
    for index, entry in ipairs(entries) do
        local row = rows[index] or CreateRow()
        rows[index] = row
        row.link, row.votes = entry.link, entry.votes
        row.name:SetText(entry.link)
        row.voters:SetText(entry.votes)
        local itemID = tonumber(entry.link:match("item:(%d+)"))
        row.icon:SetTexture(itemID and C_Item.GetItemIconByID(itemID) or 134400)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -height)
        local entryHeight = math.max(rowHeight, 24 + row.voters:GetStringHeight())
        row:SetHeight(entryHeight)
        height = height + entryHeight
        row:Show()
    end
    for index = #entries + 1, #rows do rows[index]:Hide() end
    content:SetHeight(height)
    panel:SetHeight(math.max(height + 38, minPanelHeight))
    panel:Show()
end

function ns.ShowGroupLootSample(link, votes)
    local sample = { link = link, votes = votes, key = "preview", start = math.huge }
    preview = sample
    DrawNeed()
    C_Timer.After(resultDuration, function()
        if preview ~= sample then return end
        preview = nil
        DrawNeed()
    end)
end

local function FindQuality(link)
    local quality = C_Item.GetItemQualityByID and ns.Number(C_Item.GetItemQualityByID(link))
    if quality then return quality end
    -- The complete link can already carry its quality before the item cache is ready.
    local color = link:match("^|c(%x%x%x%x%x%x%x%x)|Hitem:")
    if not color then return end
    for value in pairs(ns.LootQualityNames) do
        local info = ITEM_QUALITY_COLORS[value]
        if info and SafeString(info.hex) and info.hex:sub(-8):lower() == color:lower() then return value end
    end
end

local function UpdateDrop(encounterID, lootID, drop, now)
    local key = encounterID .. ":" .. lootID
    local old = drops[key]
    local link = drop and SafeString(drop.itemHyperlink)
    local quality = old and old.link == link and old.quality or link and FindQuality(link)
    if not ns.IsLootQualitySelected("groupNeed", quality) then
        drops[key] = nil
        return
    end
    local start, duration = ns.Number(drop.startTime), ns.Number(drop.duration)
    if not (start and duration and duration > 0) then return end
    local finished = drop.winner ~= nil or drop.allPassed == true
    local expires = start + duration
    -- Also show the result if the roll opened and closed in the same update batch.
    if finished then
        if not old and (now - start > 1 or expires <= now) then return end
        expires = old and old.finished and old.expires or now + resultDuration
    end
    if expires <= now then
        drops[key] = nil
        return
    end
    local names, voted = {}, 0
    local rollInfos = drop.rollInfos or {}
    for _, info in ipairs(rollInfos) do
        local state = ns.Number(info.state)
        if state and state ~= rollStates.NoRoll then voted = voted + 1 end
        if state == rollStates.NeedMainSpec or state == rollStates.NeedOffSpec then
            local name = SafeString(info.playerName)
            if name then
                names[#names + 1] = { name = name, class = SafeString(info.playerClass), guid = SafeString(info.playerGUID) }
            end
        end
    end
    table.sort(names, function(a, b) return a.name < b.name end)
    for index, voter in ipairs(names) do
        local color = RAID_CLASS_COLORS and voter.class and RAID_CLASS_COLORS[voter.class]
        local hex = color and color.colorStr
        local name = voter.name:gsub("|", "||")
        if hex then name = "|c" .. hex .. name .. "|r" end
        names[index] = RoleIcon(voter.guid) .. name
    end
    local entry = old or { key = key }
    entry.link, entry.quality, entry.start = link, quality, start
    entry.votes = ("%d/%d  Нужно: %s"):format(voted, #rollInfos, #names > 0 and table.concat(names, ", ") or "-")
    entry.finished = finished
    drops[key] = entry
    if entry.expires == expires then return end
    entry.expires = expires
    C_Timer.After(expires - now, function()
        if drops[key] == entry and entry.expires == expires then
            drops[key] = nil
            DrawNeed()
        end
    end)
end

local function RefreshNeed()
    if not (ns.Enabled("groupNeed") and ns.HasLootQualitySelected("groupNeed")) then
        wipe(updates)
        wipe(drops)
    end
    DrawNeed()
end

local function QueueHistory(encounterID, lootID)
    if not (ns.Enabled("groupNeed") and ns.HasLootQualitySelected("groupNeed")) then return end
    if not encounterID then return end
    -- One history query per changed drop or encounter, grouped across rapid votes.
    if not lootID then
        updates[encounterID] = true
    elseif updates[encounterID] ~= true then
        updates[encounterID] = updates[encounterID] or {}
        updates[encounterID][lootID] = true
    end
    if renderPending then return end
    renderPending = true
    C_Timer.After(0.1, function()
        renderPending = false
        local pending = updates
        updates = {}
        if not (ns.Enabled("groupNeed") and ns.HasLootQualitySelected("groupNeed")) then return end
        local now = ns.Number(history.GetLootHistoryTime())
        if not now then return end
        for id, changed in pairs(pending) do
            if changed == true then
                for _, drop in ipairs(history.GetSortedDropsForEncounter(id) or {}) do
                    local loot = ns.Number(drop.lootListID) or ns.Number(drop.lootListKey)
                    if loot then UpdateDrop(id, loot, drop, now) end
                end
            else
                for loot in pairs(changed) do
                    UpdateDrop(id, loot, history.GetSortedInfoForDrop(id, loot), now)
                end
            end
        end
        DrawNeed()
    end)
end

ns.AddSetting("groupNeed", "Групповая добыча: кто выбрал «Нужно»", RefreshNeed, true, "equipment")
ns.AddSetting("autoGreed", "Автовыбор: Не откажусь", nil, true, "equipment")

if history and history.GetSortedInfoForDrop and history.GetSortedDropsForEncounter and history.GetLootHistoryTime and rollStates then
    ns.On("LOOT_HISTORY_UPDATE_DROP", function(encounterID, lootID)
        QueueHistory(ns.Number(encounterID), ns.Number(lootID))
    end)
    ns.On("LOOT_HISTORY_UPDATE_ENCOUNTER", function(encounterID)
        QueueHistory(ns.Number(encounterID))
    end)
    ns.On("LOOT_HISTORY_CLEAR_HISTORY", function()
        wipe(updates)
        wipe(drops)
        DrawNeed()
    end)
end

if RollOnLoot and GetLootRollItemInfo then
    local pending = {}
    local recipeClass = Enum.ItemClass and Enum.ItemClass.Recipe or 9
    local getItemInfoInstant = C_Item.GetItemInfoInstant or GetItemInfoInstant
    local function CanRollOnItem(rollID)
        local link = GetLootRollItemLink and SafeString(GetLootRollItemLink(rollID))
        if not link or not getItemInfoInstant then return false end
        local id, _, _, _, _, itemClass = getItemInfoInstant(link)
        local class = ns.Number(itemClass)
        if not class or (class == recipeClass and ns.IsAutoGreedIgnored("recipes")) then return false end
        id = ns.Number(id) or tonumber(link:match("item:(%d+)"))
        return not ns.IsAutoGreedIgnored(id)
    end
    local function CanAutoGreed(rollID)
        if not (ns.Enabled("autoGreed") and ns.HasLootQualitySelected("autoGreed")) then return false end
        local _, _, _, quality, _, _, canGreed, _, _, _, _, _, canTransmog = GetLootRollItemInfo(rollID)
        return ns.IsLootQualitySelected("autoGreed", ns.Number(quality))
            and not (issecretvalue and (issecretvalue(canGreed) or issecretvalue(canTransmog)))
            and canGreed == true and canTransmog ~= true
    end

    ns.On("START_LOOT_ROLL", function(rollID, rollTime)
        rollID = ns.Number(rollID)
        if not rollID or pending[rollID] or not CanAutoGreed(rollID) then return end
        local token = {}
        pending[rollID] = token
        C_Timer.After(0, function()
            if pending[rollID] ~= token then return end
            if not CanAutoGreed(rollID) or not CanRollOnItem(rollID) then
                pending[rollID] = nil
                return
            end
            if GetLootRollTimeLeft and (ns.Number(GetLootRollTimeLeft(rollID)) or 0) <= 0 then
                pending[rollID] = nil
                return
            end
            -- Let the client's START_LOOT_ROLL handlers finish before voting.
            -- The client still handles any required confirmation.
            pcall(RollOnLoot, rollID, rollTypes and rollTypes.Greed or 2)
        end)
        C_Timer.After((ns.Number(rollTime) or 60000) / 1000 + 1, function()
            if pending[rollID] == token then pending[rollID] = nil end
        end)
    end)
    ns.On("CANCEL_LOOT_ROLL", function(rollID)
        rollID = ns.Number(rollID)
        if rollID then pending[rollID] = nil end
    end)
    ns.On("CANCEL_ALL_LOOT_ROLLS", function() wipe(pending) end)
end
