local _, ns = ...

local history = C_LootHistory
local rollStates = Enum.EncounterLootDropRollState
local rollTypes = Enum.LootRollType

ns.LootQualityNames = { [2] = "Необычное", [3] = "Редкое", [4] = "Эпическое" }
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

function ns.MaxLootQuality(feature)
    return feature == "groupNeed" and 4 or 3
end

function ns.IsLootQualitySelected(feature, quality)
    local selected = ns.db and ns.db[feature .. "Qualities"]
    return ns.LootQualityNames[quality] ~= nil and quality <= ns.MaxLootQuality(feature)
        and type(selected) == "table" and selected[quality] == true
end

function ns.HasLootQualitySelected(feature)
    for quality = 2, ns.MaxLootQuality(feature) do
        if ns.IsLootQualitySelected(feature, quality) then return true end
    end
    return false
end

local function SafeString(value)
    if type(value) == "string" and not (issecretvalue and issecretvalue(value)) then return value end
end

local winnerPrefix = "Победитель: "
local voteIconSize = 12
ns.GroupLootPreviewNames = {
    "Aurelianwind Dawnsentinel",
    "Seraphinmoon Silverwillow",
    "Eldermystara Frostwhisper",
    "Nightvaleron Shadowdagger",
    "Sylvanthorne Stormfeather",
}

local roleIcons = {
    TANK = "|A:roleicon-tiny-tank:12:12|a",
    HEALER = "|A:roleicon-tiny-healer:12:12|a",
    DAMAGER = "|A:roleicon-tiny-dps:12:12|a",
}

local function AssignedRole(info)
    local guid = SafeString(info.playerGUID)
    local unit = guid and UnitTokenFromGUID and SafeString(UnitTokenFromGUID(guid))
    return unit and UnitGroupRolesAssigned and SafeString(UnitGroupRolesAssigned(unit))
end

local function VoterIcon(role, class)
    if roleIcons[role] then return roleIcons[role] end
    if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
        return ("|A:classicon-%s:12:12|a"):format(class:lower())
    end
end

local function VoterName(info, name, getRole)
    local class = SafeString(info.playerClass)
    local color = RAID_CLASS_COLORS and class and RAID_CLASS_COLORS[class]
    local hex = color and color.colorStr
    name = name:gsub("|", "||")
    if hex then name = "|c" .. hex .. name .. "|r" end
    local icon = VoterIcon(getRole(info), class)
    return icon and (icon .. " " .. name) or name
end

function ns.BuildGroupLootVoteText(rollInfos, getRole, winner)
    getRole = getRole or AssignedRole
    local names, pending, voted = {}, {}, 0
    local winnerName = winner and SafeString(winner.playerName)
    local winnerGUID = winner and SafeString(winner.playerGUID)
    local winnerListed = false
    for _, info in ipairs(rollInfos) do
        local state = ns.Number(info.state)
        if state == rollStates.NoRoll then
            pending[#pending + 1] = VoterIcon(getRole(info), SafeString(info.playerClass)) or "|T134400:12:12|t"
        elseif state then
            voted = voted + 1
            if state == rollStates.NeedMainSpec or state == rollStates.NeedOffSpec then
                local name = SafeString(info.playerName)
                if name and name ~= "" then
                    names[#names + 1] = { name = name, info = info }
                    winnerListed = winnerListed or name == winnerName
                        or (winnerGUID and SafeString(info.playerGUID) == winnerGUID)
                end
            end
        end
    end
    if winnerName and winnerName ~= "" and not winnerListed then
        names[#names + 1] = { name = winnerName, info = winner }
    end
    table.sort(names, function(a, b) return a.name < b.name end)
    for index, voter in ipairs(names) do
        names[index] = VoterName(voter.info, voter.name, getRole)
    end
    local header
    if winnerName and winnerName ~= "" then
        header = winnerPrefix .. VoterName(winner, winnerName, getRole)
    else
        header = ("Голосование: %d/%d"):format(voted, #rollInfos)
        if #pending > 0 then header = header .. "  " .. table.concat(pending, " ") end
    end
    return #names > 0 and header .. "\n" .. table.concat(names, "\n") or header
end

local panel, scroll, content, grow, shrink
local rows, drops, updates = {}, {}, {}
local DrawNeed
local renderPending, preview
local historyGeneration, entryOrder = 0, 0
local rowCount = 0
local rowHeight = 42
local topInset, bottomInset = 30, 8
local panelInset, scrollBarInset, scrollBarGap = 12, 30, 4
local panelPadding = topInset + bottomInset
local textInset, textGap = 36, 3
local contentWidth, ballotWidth, textWidth, ballotSize, ballotFlags
local maxItemNameChars = #ns.GroupLootPreviewNames[1]
local itemNameEllipsis = "..."
local minVisibleRows, maxVisibleRows, resultDuration = 2, 10, 5
local maxRetainedDrops = 20
local minPanelHeight = rowHeight + panelPadding

local function KeepResults()
    return ns.db.groupNeedKeepOpen == true
end

function ns.GetGroupNeedScale()
    local percent = ns.Number(ns.db.groupNeedScalePercent) or 100
    return math.max(100, math.min(160, math.floor(percent / 10 + 0.5) * 10))
end

local function VisibleRows()
    local count = ns.Number(ns.db.groupNeedVisibleRows) or maxVisibleRows
    return math.max(minVisibleRows, math.min(maxVisibleRows, math.floor(count)))
end

local function PruneExpired()
    local now = history and history.GetLootHistoryTime and ns.Number(history.GetLootHistoryTime())
    if not now then return end
    for key, entry in pairs(drops) do
        if entry.expires <= now then drops[key] = nil end
    end
end

local function TrimRetainedResults(entries)
    local limit = maxRetainedDrops + (preview and #preview or 0)
    if not KeepResults() or #entries <= limit then return end
    local now = ns.Number(history.GetLootHistoryTime())
    for index = #entries, limit + 1, -1 do
        local entry = entries[index]
        if now and entry.expires <= now then
            drops[entry.key] = nil
        else
            -- Ignore further votes for an evicted roll until its existing timer expires.
            entry.dismissed = true
            entry.link, entry.votes = nil, nil
        end
        entries[index] = nil
    end
end

local function BorderHeight(top, bottom)
    if not top or not bottom then return 0 end
    local _, _, _, _, topOffset = top:GetPoint()
    local _, _, _, _, bottomOffset = bottom:GetPoint()
    return top:GetHeight() + bottom:GetHeight() - (topOffset or 0) + (bottomOffset or 0) + 1
end

local function PositionPanel()
    local scale = panel:GetScale()
    local position = ns.db.groupNeedPosition
    panel:ClearAllPoints()
    if position then
        panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", position.x / scale, position.y / scale)
    else
        panel:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -80 / scale, -140 / scale)
    end
end

local function UpdateScrollRange(range)
    scroll.ScrollBar:SetShown(range > 0)
    if scroll:GetVerticalScroll() > range then scroll:SetVerticalScroll(range) end
end

local function UpdatePanelHeight()
    if rowCount == 0 then return end
    local limit = VisibleRows()
    local screenHeight = (UIParent:GetHeight() - 24) / panel:GetScale()
    local wantedHeight = rows[math.min(limit, rowCount)].bottom + panelPadding
    local height = math.max(minPanelHeight, math.min(wantedHeight, screenHeight))
    if panel:GetHeight() ~= height then panel:SetHeight(height) end
    grow:SetEnabled(limit < maxVisibleRows)
    shrink:SetEnabled(limit > minVisibleRows)
    scroll:UpdateScrollChildRect()
    UpdateScrollRange(scroll:GetVerticalScrollRange())
end

local function ApplyScale()
    panel:SetScale(ns.GetGroupNeedScale() / 100)
    PositionPanel()
end

function ns.SetGroupNeedScale(percent)
    ns.db.groupNeedScalePercent = percent
    if panel then
        ApplyScale()
        UpdatePanelHeight()
    end
end

local function CreatePanel()
    local close
    local horizontalMargins = panelInset + textInset + scrollBarInset
    panel, close = ns.CreateLootPanel("RainonUIForeverGroupLoot", "", horizontalMargins, minPanelHeight)
    local measure = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    local _, baseSize, flags = measure:GetFont()
    ballotSize, ballotFlags = baseSize + 0.5, flags
    measure:SetFont(ns.CYRILLIC_FONT, ballotSize, ballotFlags)
    ballotWidth = 0
    for _, name in ipairs(ns.GroupLootPreviewNames) do
        local label = winnerPrefix .. roleIcons.DAMAGER .. " " .. name
        ballotWidth = math.max(ballotWidth, measure:GetUnboundedStringWidthForText(label))
    end
    -- Measure between letters so the font does not discard trailing spaces.
    local rightPadding = measure:GetUnboundedStringWidthForText("M  M") - measure:GetUnboundedStringWidthForText("MM")
    textWidth = math.ceil(ballotWidth + rightPadding)
    contentWidth = textInset + textWidth
    panel:SetWidth(horizontalMargins + textWidth)

    local border = panel.NineSlice
    if border then
        -- Keep the original corner atlases and leave room for both side edges.
        minPanelHeight = math.max(minPanelHeight,
            BorderHeight(border.TopLeftCorner, border.BottomLeftCorner),
            BorderHeight(border.TopRightCorner, border.BottomRightCorner))
    end
    ApplyScale()
    panel:SetMovable(true)
    close:SetScript("OnClick", function()
        for _, entry in pairs(drops) do entry.dismissed = true end
        PruneExpired()
        preview = nil
        scroll:SetVerticalScroll(0)
        panel:Hide()
    end)
    local function Resize(step)
        ns.db.groupNeedVisibleRows = math.max(minVisibleRows, math.min(maxVisibleRows, VisibleRows() + step))
        UpdatePanelHeight()
    end
    grow = ns.CreateLootSizeButton(panel, close, "RedButton-Expand", "RedButton-Expand-Disabled", function() Resize(1) end)
    shrink = ns.CreateLootSizeButton(panel, grow, "RedButton-Condense", "RedButton-Condense-disabled", function() Resize(-1) end)
    local title = panel.TitleContainer
    title:ClearAllPoints()
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", panelInset, -1)
    title:SetPoint("TOPRIGHT", shrink, "TOPLEFT", -4, -1)
    title:EnableMouse(true)
    title:RegisterForDrag("LeftButton")
    title:SetScript("OnDragStart", function() panel:StartMoving() end)
    title:SetScript("OnDragStop", function()
        panel:StopMovingOrSizing()
        local left, top = panel:GetLeft(), panel:GetTop()
        if left and top then
            local scale = panel:GetScale()
            ns.db.groupNeedPosition = {
                x = left * scale - (UIParent:GetLeft() or 0),
                y = top * scale - (UIParent:GetBottom() or 0),
            }
            PositionPanel()
        end
    end)
    panel:HookScript("OnHide", function() panel:StopMovingOrSizing() end)

    scroll = CreateFrame("ScrollFrame", nil, panel, "ScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", panelInset, -topInset)
    scroll:SetPoint("BOTTOMRIGHT", -scrollBarInset, bottomInset)
    local bar = scroll.ScrollBar
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", scrollBarGap, 0)
    bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", scrollBarGap, 0)
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(contentWidth, 1)
    scroll:SetScrollChild(content)
    scroll:HookScript("OnScrollRangeChanged", function(_, _, range) UpdateScrollRange(range) end)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local offset = self:GetVerticalScroll() - delta * 50
        self:SetVerticalScroll(math.max(0, math.min(offset, self:GetVerticalScrollRange())))
    end)
    UIParent:HookScript("OnSizeChanged", UpdatePanelHeight)
end

local function CreateRow()
    local row = CreateFrame("Frame", nil, content)
    row:SetWidth(contentWidth)
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetHyperlink(self.link)
        GameTooltip:AddLine(self.votes, 1, 1, 1, true)
        ns.UseCyrillicTooltipFont(GameTooltip)
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
    row.name:SetPoint("TOPLEFT", textInset, -2)
    row.name:SetWidth(textWidth)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.name:SetMaxLines(1)
    local _, nameSize, nameFlags = row.name:GetFont()
    row.name:SetFont(ns.CYRILLIC_FONT, nameSize, nameFlags)
    row.ballot = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.ballot:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -textGap)
    row.ballot:SetWidth(textWidth)
    row.ballot:SetJustifyH("LEFT")
    row.ballot:SetWordWrap(true)
    row.voters = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.voters:SetPoint("TOPLEFT", row.ballot, "BOTTOMLEFT", 0, -textGap)
    row.voters:SetWidth(textWidth)
    row.voters:SetJustifyH("LEFT")
    row.voters:SetWordWrap(true)
    row.ballot:SetFont(ns.CYRILLIC_FONT, ballotSize, ballotFlags)
    row.voters:SetFont(ns.CYRILLIC_FONT, ballotSize, ballotFlags)
    row.divider = row:CreateTexture(nil, "ARTWORK")
    row.divider:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")
    row.divider:SetHeight(6)
    row.divider:SetPoint("BOTTOMLEFT")
    row.divider:SetPoint("BOTTOMRIGHT")
    return row
end

local function DisplayItemName(link)
    return (link:gsub("(|h)%[(.-)%](|h)", function(open, name, close)
        local count, prefixEnd = 0, 0
        for nextByte in name:gmatch("[^\128-\191][\128-\191]*()") do
            count = count + 1
            if count > maxItemNameChars then
                name = name:sub(1, prefixEnd):gsub("%s+$", "") .. itemNameEllipsis
                break
            end
            if count <= maxItemNameChars - #itemNameEllipsis then prefixEnd = nextByte - 1 end
        end
        return open .. name .. close
    end, 1))
end

DrawNeed = function(resetScroll)
    local entries = {}
    for key, entry in pairs(drops) do
        if ns.Enabled("groupNeed") and ns.IsLootQualitySelected("groupNeed", entry.quality) then
            if not entry.dismissed then entries[#entries + 1] = entry end
        else
            drops[key] = nil
        end
    end
    for _, sample in ipairs(preview or {}) do entries[#entries + 1] = sample end
    if #entries == 0 then
        rowCount = 0
        if panel then
            scroll:SetVerticalScroll(0)
            panel:Hide()
        end
        return
    end
    table.sort(entries, function(a, b)
        if a.start ~= b.start then return a.start > b.start end
        return a.order > b.order
    end)
    TrimRetainedResults(entries)
    if not panel then CreatePanel() end
    local height = 0
    for index, entry in ipairs(entries) do
        local row = rows[index] or CreateRow()
        rows[index] = row
        if row.link ~= entry.link then
            if GameTooltip:IsOwned(row) then GameTooltip:Hide() end
            row.link = entry.link
            row.name:SetText(DisplayItemName(entry.link))
            row.hasIcon = nil
        end
        if not row.hasIcon then
            local itemID = tonumber(row.link:match("item:(%d+)"))
            local icon = itemID and C_Item.GetItemIconByID(itemID)
            row.hasIcon = icon ~= nil
            row.icon:SetTexture(icon or 134400)
        end
        if row.votes ~= entry.votes or not row.bottom then
            row.votes = entry.votes
            local ballot, voters = entry.votes:match("^([^\n]*)\n?(.*)$")
            local isWinner = ballot:sub(1, #winnerPrefix) == winnerPrefix
            row.ballot:SetWordWrap(not isWinner)
            row.ballot:SetFont(ns.CYRILLIC_FONT, ballotSize, ballotFlags)
            if isWinner then
                local width = row.ballot:GetUnboundedStringWidthForText(ballot)
                if width > ballotWidth then
                    local fit = (ballotWidth - voteIconSize) / (width - voteIconSize)
                    row.ballot:SetFont(ns.CYRILLIC_FONT, ballotSize * fit, ballotFlags)
                end
            end
            row.ballot:SetText(ballot)
            row.voters:SetText(voters)
            row.voters:SetShown(voters ~= "")
        end
        local textHeight = row.name:GetStringHeight() + textGap + row.ballot:GetStringHeight()
        if row.voters:IsShown() then textHeight = textHeight + textGap + row.voters:GetStringHeight() end
        local entryHeight = math.max(rowHeight, textHeight + 10)
        if row.top ~= height then
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -height)
            row.top = height
        end
        if row:GetHeight() ~= entryHeight then row:SetHeight(entryHeight) end
        height = height + entryHeight
        row.bottom = height
        row.divider:SetShown(index < #entries)
        row:Show()
    end
    for index = #entries + 1, #rows do rows[index]:Hide() end
    rowCount = #entries
    content:SetHeight(height)
    if not panel:IsShown() then panel:Show() end
    UpdatePanelHeight()
    if resetScroll then scroll:SetVerticalScroll(0) end
end

function ns.ShowGroupLootSample(links, votes)
    if type(links) == "string" then links = { links } end
    local sample = {}
    for index, link in ipairs(links) do
        sample[index] = {
            link = link, votes = type(votes) == "table" and votes[index] or votes,
            start = math.huge, order = -index,
        }
    end
    preview = sample
    DrawNeed(true)
    C_Timer.After(resultDuration, function()
        if preview ~= sample then return end
        sample.expired = true
        if not KeepResults() then
            preview = nil
            DrawNeed()
        end
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
    local key = historyGeneration .. ":" .. encounterID .. ":" .. lootID
    local old = drops[key]
    if old and old.dismissed then return end
    local link = drop and SafeString(drop.itemHyperlink)
    if not link and old and KeepResults() then return end
    local quality = old and old.link == link and old.quality or link and FindQuality(link)
    if not ns.IsLootQualitySelected("groupNeed", quality) then
        drops[key] = nil
        return
    end
    local start, duration = ns.Number(drop.startTime), ns.Number(drop.duration)
    if not (start and duration and duration > 0) then return end
    local finished = drop.winner ~= nil or drop.allPassed == true
    local deadline = start + duration
    -- Ignore old drops when history is replayed, but allow a roll that finished in the same batch.
    if not old and (deadline <= now or (finished and now - start > 1)) then return end
    local expires = deadline + resultDuration
    if finished then
        expires = old and old.finished and old.expires or now + resultDuration
    end
    if expires <= now and not (old and KeepResults()) then
        drops[key] = nil
        return
    end
    local entry = old
    if not entry then
        entryOrder = entryOrder + 1
        entry = { key = key, order = entryOrder }
    end
    entry.link, entry.quality, entry.start = link, quality, start
    entry.votes = ns.BuildGroupLootVoteText(drop.rollInfos or {}, nil, drop.winner)
    entry.finished = finished
    drops[key] = entry
    if entry.expires ~= expires then
        entry.expires = expires
        if expires > now then
            C_Timer.After(expires - now, function()
                if drops[key] == entry and entry.expires == expires and (entry.dismissed or not KeepResults()) then
                    drops[key] = nil
                    DrawNeed()
                end
            end)
        end
    end
    return not old
end

function ns.ToggleGroupNeedKeepOpen()
    ns.db.groupNeedKeepOpen = not KeepResults() or nil
    if not KeepResults() then
        PruneExpired()
        if preview and preview.expired then preview = nil end
    end
    DrawNeed()
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
        local newEntry = false
        for id, changed in pairs(pending) do
            if changed == true then
                for _, drop in ipairs(history.GetSortedDropsForEncounter(id) or {}) do
                    local loot = ns.Number(drop.lootListID) or ns.Number(drop.lootListKey)
                    if loot and UpdateDrop(id, loot, drop, now) then newEntry = true end
                end
            else
                for loot in pairs(changed) do
                    if UpdateDrop(id, loot, history.GetSortedInfoForDrop(id, loot), now) then newEntry = true end
                end
            end
        end
        DrawNeed(newEntry)
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
        historyGeneration = historyGeneration + 1
        if not KeepResults() then wipe(drops) end
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
