local _, ns = ...
local source = ns.DungeonLootRankSource
if not source then return end

local feature = "dungeonLootCatalog"
local width, leftColumn, columns, iconStep = 600, 210, 9, 36
local minHeight, defaultHeight, maxHeight, heightStep = 300, 460, 780, 80
local questionMark = 134400
local artWidth, homeArtRatio = leftColumn - 8, 2
local getItemInfoInstant = C_Item.GetItemInfoInstant or GetItemInfoInstant
local slots = {
    { "INVTYPE_HEAD", "Голова" },
    { "INVTYPE_NECK", "Шея" },
    { "INVTYPE_SHOULDER", "Плечи" },
    { "INVTYPE_CLOAK", "Спина" },
    { "INVTYPE_CHEST", "Грудь" },
    { "INVTYPE_WRIST", "Запястья" },
    { "INVTYPE_HAND", "Кисти рук" },
    { "INVTYPE_WAIST", "Пояс" },
    { "INVTYPE_LEGS", "Ноги" },
    { "INVTYPE_FEET", "Ступни" },
    { "INVTYPE_FINGER", "Кольца" },
    { "INVTYPE_TRINKET", "Аксессуары" },
    { "INVTYPE_WEAPONMAINHAND", "Оружие" },
    { "INVTYPE_WEAPONOFFHAND", "Левая рука" },
    { "INVTYPE_RELIC", "Реликвия" },
}
local slotAliases = {
    INVTYPE_ROBE = "INVTYPE_CHEST",
    INVTYPE_WEAPON = "INVTYPE_WEAPONMAINHAND",
    INVTYPE_2HWEAPON = "INVTYPE_WEAPONMAINHAND",
    INVTYPE_SHIELD = "INVTYPE_WEAPONOFFHAND",
    INVTYPE_HOLDABLE = "INVTYPE_WEAPONOFFHAND",
}
local maxRank = 1
for _, ranks in pairs(ns.DungeonLootRanks) do
    for _, rank in pairs(ranks) do maxRank = math.max(maxRank, rank) end
end
local window, scroll, content, specFilter, grow, shrink, empty, rankSlider
local slotFilter, slotRefreshQueued
local settings, entries
local RenderCatalog
local rows, pendingIcons, pendingSlots = {}, {}, {}
local allSpecs = { true, true, true }

local function ReadCatalog(journal)
    local tierSet = {}
    for _, set in ipairs(journal.ITEM_SETS or {}) do
        if set.id == 188 then -- Lightforge Armor, Paladin Tier 0
            for _, id in ipairs(set) do tierSet[id] = true end
            break
        end
    end

    local catalog = {}
    local art = journal.DUNGEON_HOME_ART or {}
    local crops = journal.DUNGEON_HOME_TEXCOORD or {}
    for key, entry in pairs(journal.DB) do
        if not entry.questChainPage and type(entry.bosses) == "table" and #entry.bosses > 0 then
            local items, tierDrops = source.dungeonItems(journal, key, entry, tierSet)
            if #items > 0 then
                catalog[#catalog + 1] = {
                    key = key,
                    name = source.dungeonName(journal, key),
                    art = art[key],
                    crop = crops[key],
                    items = items,
                    tierDrops = tierDrops,
                }
            end
        end
    end
    table.sort(catalog, function(a, b)
        if a.name == b.name then return a.key < b.key end
        return a.name < b.name
    end)
    return catalog
end

local function HideTooltip(button)
    if GameTooltip:IsOwned(button) then GameTooltip:Hide() end
end

local function ShowItemTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_CURSOR")
    GameTooltip:SetItemByID(button.rainonDungeonLootID)
    source.addRanks(GameTooltip)
    if button.tierZero then GameTooltip:AddLine("Комплект T0", 1, 0.82, 0) end
    local action = settings.favorites[button.rainonDungeonLootID] and "убрать из избранного" or "добавить в избранное"
    GameTooltip:AddLine("ПКМ — " .. action, 1, 0.82, 0)
    GameTooltip:Show()
end

local function UpdateBadge(button)
    local id = button.rainonDungeonLootID
    local favorite = id ~= nil and settings.favorites[id] == true
    button.badge:SetShown(id ~= nil)
    button.rank:SetShown(id ~= nil and not favorite)
    button.favorite:SetShown(favorite)
end

local function CreateCell(row)
    local button = CreateFrame("Button", nil, row)
    button:SetSize(32, 32)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.04, 0.03, 0.025, 0.92)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", 3, -3)
    button.icon:SetPoint("BOTTOMRIGHT", -3, 3)
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local border = button:CreateTexture(nil, "ARTWORK", nil, 1)
    border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    border:SetSize(53, 53)
    border:SetPoint("CENTER")
    local badge = button:CreateTexture(nil, "OVERLAY")
    button.badge = badge
    badge:SetColorTexture(0.08, 0.06, 0.04, 0.92)
    badge:SetSize(17, 14)
    badge:SetPoint("BOTTOMRIGHT", -2, 2)
    button.rank = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall", 1)
    button.rank:SetPoint("CENTER", badge)
    button.favorite = button:CreateTexture(nil, "OVERLAY", nil, 2)
    button.favorite:SetAtlas("auctionhouse-icon-favorite")
    button.favorite:SetSize(14, 13)
    button.favorite:SetPoint("CENTER", badge)
    button:RegisterForClicks("RightButtonUp")
    button:SetScript("OnClick", function(self)
        local id = self.rainonDungeonLootID
        if not id then return end
        settings.favorites[id] = not settings.favorites[id] or nil
        if settings.favoritesOnly then
            RenderCatalog()
        else
            -- The same item may be listed in more than one dungeon.
            for _, dungeonRow in ipairs(rows) do
                for _, cell in ipairs(dungeonRow.cells) do
                    if cell.rainonDungeonLootID == id then
                        UpdateBadge(cell)
                    end
                end
            end
            if GameTooltip:IsOwned(self) then ShowItemTooltip(self) end
        end
    end)
    button:SetScript("OnEnter", ShowItemTooltip)
    button:SetScript("OnLeave", HideTooltip)
    button:SetScript("OnHide", HideTooltip)
    return button
end

local function CreateRow()
    local row = CreateFrame("Frame", nil, content)
    row.background = row:CreateTexture(nil, "BACKGROUND")
    row.background:SetAllPoints()
    local divider = row:CreateTexture(nil, "ARTWORK")
    divider:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")
    divider:SetHeight(7)
    divider:SetPoint("BOTTOMLEFT", 0, -2)
    divider:SetPoint("BOTTOMRIGHT", 0, -2)
    row.art = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.art:SetPoint("TOPLEFT", 2, -1)
    row.art:SetPoint("BOTTOMLEFT", 2, 1)
    row.art:SetWidth(artWidth)
    row.shade = row:CreateTexture(nil, "ARTWORK")
    row.shade:SetAllPoints(row.art)
    row.shade:SetColorTexture(0.055, 0.04, 0.03, 0.52)
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.name:SetPoint("LEFT", 12, 0)
    row.name:SetWidth(artWidth - 22)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(true)
    row.name:SetShadowOffset(1, -1)
    row.name:SetMaxLines(3)
    row.cells = {}
    return row
end

local function FillCell(button, item)
    HideTooltip(button)
    button.rainonDungeonLootID = item and item.id
    button.tierZero = item and item.tierZero
    button:EnableMouse(item ~= nil)
    button.icon:SetShown(item ~= nil)
    UpdateBadge(button)
    if not item then return end

    button.rank:SetText(item.tierZero and "T0" or item.rank)
    local icon = C_Item.GetItemIconByID(item.id)
    button.icon:SetTexture(icon or questionMark)
    if not icon then
        local waiting = pendingIcons[item.id]
        if waiting then
            table.insert(waiting, button)
        else
            pendingIcons[item.id] = { button }
            C_Item.RequestLoadItemDataByID(item.id)
        end
    end
end

local function SetRowArt(row, entry, height)
    row.art:SetShown(entry.art ~= nil)
    row.shade:SetShown(entry.art ~= nil)
    if not entry.art then return end

    local left, right, top, bottom = 0, 1, 0, 1
    if entry.crop then left, right, top, bottom = unpack(entry.crop) end
    local targetRatio = artWidth / (height - 2)
    local textureWidth, textureHeight = right - left, bottom - top
    -- The journal's bundled home illustrations are 512 × 256.
    if textureWidth * homeArtRatio > textureHeight * targetRatio then
        local inset = (textureWidth - textureHeight * targetRatio / homeArtRatio) / 2
        left, right = left + inset, right - inset
    else
        local inset = (textureHeight - textureWidth * homeArtRatio / targetRatio) / 2
        top, bottom = top + inset, bottom - inset
    end
    row.art:SetTexture(entry.art)
    row.art:SetTexCoord(left, right, top, bottom)
end

local function DrawRow(entry, items, index, offset)
    local row = rows[index] or CreateRow()
    rows[index] = row
    row.name:SetText(entry.name)
    row.background:SetColorTexture(0, 0, 0, index % 2 == 1 and 0.24 or 0.08)

    local lines = math.ceil(#items / columns)
    local cellCount = lines * columns
    for position = 1, cellCount do
        local cell = row.cells[position]
        if not cell then
            cell = CreateCell(row)
            cell:SetPoint("TOPLEFT", leftColumn + ((position - 1) % columns) * iconStep,
                -9 - math.floor((position - 1) / columns) * iconStep)
            row.cells[position] = cell
        end
        FillCell(cell, items[position])
        cell:Show()
    end
    for position = cellCount + 1, #row.cells do row.cells[position]:Hide() end

    local height = 14 + lines * iconStep
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, -offset)
    row:SetSize(content:GetWidth(), height)
    SetRowArt(row, entry, height)
    row:Show()
    return height
end

local function MatchesSlot(id)
    local _, _, _, equipLoc = getItemInfoInstant(id)
    if equipLoc then return settings.slots[slotAliases[equipLoc] or equipLoc] end
    if pendingSlots[id] == nil then
        pendingSlots[id] = true
        if not pendingIcons[id] then C_Item.RequestLoadItemDataByID(id) end
    end
    return false
end

local function UpdateSlotCaption()
    local first, count = nil, 0
    for _, slot in ipairs(slots) do
        if settings.slots[slot[1]] then
            first = first or slot[2]
            count = count + 1
        end
    end
    local caption = first or "Все слоты"
    if count > 1 then caption = ("%s + %d"):format(caption, count - 1) end
    if settings.favoritesOnly then
        caption = count > 0 and ("Избранное + %d"):format(count) or "Избранное"
    end
    if settings.tierDungeonsOnly then
        caption = (first or settings.favoritesOnly) and ("T0 + " .. caption) or "T0"
    end
    slotFilter:OverrideText(caption)
end

local function SelectedSpecs()
    return settings.specs or allSpecs
end

RenderCatalog = function()
    pendingIcons = {}
    local favoritesOnly = settings.favoritesOnly == true
    local tierOnly = settings.tierDungeonsOnly
    rankSlider:SetShown(not favoritesOnly)
    local selected = SelectedSpecs()
    local filterSlots = next(settings.slots) ~= nil
    local top, visible = 0, 0
    for _, entry in ipairs(entries) do
        if not tierOnly or next(entry.tierDrops) then
            local items = {}
            for _, id in ipairs(entry.items) do
                local tierZero = entry.tierDrops[id]
                if (not tierOnly or tierZero) and (not favoritesOnly or settings.favorites[id]) then
                    local rank = tierZero and 0 or source.bestRank(id, selected)
                    if rank and (tierZero or ((favoritesOnly or rank <= settings.maximum)
                        and (not filterSlots or MatchesSlot(id)))) then
                        items[#items + 1] = { id = id, rank = rank, tierZero = tierZero }
                    end
                end
            end
            if #items > 0 then
                table.sort(items, function(a, b)
                    if a.rank == b.rank then return a.id < b.id end
                    return a.rank < b.rank
                end)
                visible = visible + 1
                top = top + DrawRow(entry, items, visible, top)
            end
        end
    end
    for index = visible + 1, #rows do rows[index]:Hide() end
    empty:SetShown(visible == 0)
    local names = {}
    for spec, name in ipairs(source.names) do
        if selected[spec] then names[#names + 1] = name end
    end
    specFilter:OverrideText(#names == #source.names and "Все специализации" or table.concat(names, ", "))
    UpdateSlotCaption()
    content:SetHeight(math.max(1, top))
    scroll:UpdateScrollChildRect()
    scroll:SetVerticalScroll(math.min(scroll:GetVerticalScroll(), scroll:GetVerticalScrollRange()))
    scroll.ScrollBar:SetShown(scroll:GetVerticalScrollRange() > 0)
end

local function ToggleSpec(spec)
    local selected, updated, count = SelectedSpecs(), {}, 0
    for index in ipairs(source.names) do
        local checked = selected[index] == true
        if index == spec then checked = not checked end
        if checked then
            updated[index] = true
            count = count + 1
        end
    end
    if count == 0 then return end
    settings.specs = count < #source.names and updated or nil
    RenderCatalog()
end

local function UpdateHeight()
    local ceiling = math.max(150, math.min(maxHeight, UIParent:GetHeight() - 24))
    local height = math.min(settings.height or defaultHeight, ceiling)
    window:SetHeight(height)
    grow:SetEnabled(height < ceiling)
    shrink:SetEnabled(height > minHeight)
    scroll:UpdateScrollChildRect()
end

local function ResizeWindow(step)
    settings.height = math.max(minHeight, math.min(maxHeight, window:GetHeight() + step))
    UpdateHeight()
end

local function CreateWindow()
    local close
    window, close = ns.CreateLootPanel("RainonUIForeverDungeonLootCatalog", "Добыча всех подземелий", width, defaultHeight)
    window:SetPoint("CENTER")
    window:SetMovable(true)
    window.TitleContainer:RegisterForDrag("LeftButton")
    window.TitleContainer:EnableMouse(true)
    window.TitleContainer:SetScript("OnDragStart", function() window:StartMoving() end)
    window.TitleContainer:SetScript("OnDragStop", function() window:StopMovingOrSizing() end)
    tinsert(UISpecialFrames, window:GetName())
    grow = ns.CreateLootSizeButton(window, close, "RedButton-Expand", "RedButton-Expand-Disabled", function()
        ResizeWindow(heightStep)
    end)
    shrink = ns.CreateLootSizeButton(window, grow, "RedButton-Condense", "RedButton-Condense-disabled", function()
        ResizeWindow(-heightStep)
    end)

    local filters = CreateFrame("Frame", nil, window)
    local dropdownWidth, controlY = 159, -7
    filters:SetPoint("TOPLEFT", 14, -32)
    filters:SetPoint("TOPRIGHT", -14, -32)
    filters:SetHeight(50)
    specFilter = CreateFrame("DropdownButton", nil, filters, "WowStyle1DropdownTemplate")
    specFilter:SetSize(dropdownWidth, 28)
    specFilter:SetPoint("LEFT", 0, controlY)
    specFilter:SetupMenu(function(_, menu)
        local all = menu:CreateRadio("Все специализации", function() return settings.specs == nil end, function()
            settings.specs = nil
            RenderCatalog()
        end)
        all:SetResponse(MenuResponse.Refresh)
        menu:CreateDivider()
        for index, name in ipairs(source.names) do
            local spec = index
            local option = menu:CreateCheckbox(name, function() return SelectedSpecs()[spec] == true end, function()
                ToggleSpec(spec)
            end)
            option:SetResponse(MenuResponse.Refresh)
        end
    end)

    slotFilter = CreateFrame("DropdownButton", nil, filters, "WowStyle1DropdownTemplate")
    slotFilter:SetSize(dropdownWidth, 28)
    slotFilter:SetPoint("LEFT", specFilter, "RIGHT", 6, 0)
    slotFilter:SetupMenu(function(_, menu)
        local reset = menu:CreateButton("Сбросить фильтр", function()
            settings.slots = {}
            settings.favoritesOnly = nil
            settings.tierDungeonsOnly = nil
            RenderCatalog()
        end)
        reset:SetResponse(MenuResponse.Refresh)
        local favorites = menu:CreateCheckbox("Избранное", function() return settings.favoritesOnly == true end, function()
            settings.favoritesOnly = not settings.favoritesOnly or nil
            RenderCatalog()
        end)
        favorites:SetResponse(MenuResponse.Refresh)
        local tier = menu:CreateCheckbox("T0", function() return settings.tierDungeonsOnly == true end, function()
            settings.tierDungeonsOnly = not settings.tierDungeonsOnly or nil
            RenderCatalog()
        end)
        tier:SetResponse(MenuResponse.Refresh)
        menu:CreateDivider()
        for _, slot in ipairs(slots) do
            local key, name = unpack(slot)
            local checkbox = menu:CreateCheckbox(name, function() return settings.slots[key] == true end, function()
                settings.slots[key] = not settings.slots[key] or nil
                RenderCatalog()
            end)
            checkbox:SetResponse(MenuResponse.Refresh)
        end
    end)

    rankSlider = CreateFrame("Frame", nil, filters, "MinimalSliderWithSteppersTemplate")
    rankSlider:SetPoint("LEFT", slotFilter, "RIGHT", 16, 0)
    rankSlider:SetPoint("RIGHT", -7, controlY)
    rankSlider:SetHeight(19)
    rankSlider.TopText:ClearAllPoints()
    rankSlider.TopText:SetPoint("BOTTOM", rankSlider, "TOP", 0, 1)
    local labels = MinimalSliderWithSteppersMixin.Label
    rankSlider:Init(settings.maximum, 1, maxRank, math.max(1, maxRank - 1), {
        [labels.Top] = function(value)
            local maximum = math.floor(value + 0.5)
            local range = maximum == 1 and "1" or ("1 - %d"):format(maximum)
            return "Рейтинг экипировки: " .. range
        end,
    })
    rankSlider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        local maximum = math.floor(value + 0.5)
        if maximum == settings.maximum then return end
        settings.maximum = maximum
        RenderCatalog()
    end)

    scroll = CreateFrame("ScrollFrame", nil, window, "ScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", filters, "BOTTOMLEFT", 0, -8)
    scroll:SetPoint("BOTTOMRIGHT", -30, 12)
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(width - 44, 1)
    scroll:SetScrollChild(content)
    scroll:HookScript("OnScrollRangeChanged", function(self, _, range)
        self.ScrollBar:SetShown(range > 0)
        if self:GetVerticalScroll() > range then self:SetVerticalScroll(range) end
    end)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local offset = self:GetVerticalScroll() - delta * 50
        self:SetVerticalScroll(math.max(0, math.min(offset, self:GetVerticalScrollRange())))
    end)
    empty = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    empty:SetPoint("TOPLEFT", scroll, "TOPLEFT", 8, -12)
    empty:SetText("Нет добычи по выбранным фильтрам.")
    window:HookScript("OnHide", function()
        specFilter:CloseMenu()
        slotFilter:CloseMenu()
        window:StopMovingOrSizing()
        for _, row in ipairs(rows) do
            for _, cell in ipairs(row.cells) do HideTooltip(cell) end
        end
    end)
end

function ns.ToggleDungeonLootCatalog()
    if not ns.Enabled(feature) then return end
    if window and window:IsShown() then
        window:Hide()
        return
    end
    local journal = ForeverDungeonJournal_NS
    if not journal or not journal.DB then
        print("RainonUI: для просмотра добычи включи ForeverDungeonJournal.")
        return
    end
    ns.db.dungeonLootCatalog = ns.db.dungeonLootCatalog or {}
    settings = ns.db.dungeonLootCatalog
    local savedRank = ns.Number(settings.maximum or settings.minimum) or maxRank
    settings.maximum = math.max(1, math.min(maxRank, math.floor(savedRank + 0.5)))
    settings.minimum = nil
    if type(settings.specs) ~= "table" or not next(settings.specs) then
        local legacySpec = ns.Number(settings.spec)
        settings.specs = source.names[legacySpec] and { [legacySpec] = true } or nil
    end
    settings.spec = nil
    if type(settings.slots) ~= "table" then settings.slots = {} end
    if type(settings.favorites) ~= "table" then settings.favorites = {} end
    pendingSlots = {}
    entries = ReadCatalog(journal)
    if not window then CreateWindow() end
    rankSlider:SetValue(settings.maximum)
    UpdateHeight()
    window:Show()
    RenderCatalog()
end

ns.AddSetting(feature, "Добыча всех подземелий", function()
    if window and not ns.Enabled(feature) then window:Hide() end
end, nil, "equipment")

ns.On("GET_ITEM_INFO_RECEIVED", function(id, success)
    local needsFilterRefresh = pendingSlots[id]
    if needsFilterRefresh then pendingSlots[id] = false end
    local buttons = pendingIcons[id]
    pendingIcons[id] = nil
    if not success then return end

    if buttons then
        local icon = C_Item.GetItemIconByID(id)
        if icon then
            for _, button in ipairs(buttons) do
                if button.rainonDungeonLootID == id then button.icon:SetTexture(icon) end
            end
        end
    end
    if needsFilterRefresh and not slotRefreshQueued and window:IsShown() and next(settings.slots) then
        slotRefreshQueued = true
        C_Timer.After(0, function()
            slotRefreshQueued = false
            if window:IsShown() and next(settings.slots) then RenderCatalog() end
        end)
    end
end)
