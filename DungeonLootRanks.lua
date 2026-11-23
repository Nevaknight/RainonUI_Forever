local _, ns = ...
local feature = "dungeonLootRanks"
local windowFeature = "dungeonLootWindow"
local ranks = ns.DungeonLootRanks
local locale = GetLocale()
local specNames = { "Воздаяние", "Свет", "Защита" }
local specIcons = { 135873, 135920, 135893 }
local entryFont = GameFontHighlight
local questionMark = 134400
local tooltipNames = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2",
    "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2" }
local itemTooltips, marked = {}, setmetatable({}, { __mode = "k" })
local tooltipFonts = setmetatable({}, { __mode = "k" })
-- These two summoned sources are mentioned by the journal but have no loot rows.
local stratholmeSmiths = {
    ["Stratholme: Living"] = { name = "Crimson Hammersmith", npcID = 11120, loot = { { 276404 } } },
    ["Stratholme: Undead"] = { name = "Black Guard Swordsmith", npcID = 11121, loot = { { 276456 } } },
}

local allSpecs = { true, true, true }

local function SelectedSpecs()
    local selected = ns.db.dungeonLootSpecs
    if type(selected) == "table" then
        for spec in ipairs(specNames) do
            if selected[spec] == true then return selected end
        end
    end
    return allSpecs
end

local function ToggleSpec(spec)
    local selected, updated = SelectedSpecs(), {}
    for index in ipairs(specNames) do
        local keep = selected[index] == true
        if index == spec then keep = not keep end
        if keep then updated[index] = true end
    end
    if not next(updated) then return false end
    ns.db.dungeonLootSpecs = updated
    return true
end

local function BestRank(id, selected)
    local best
    for spec = 1, #specNames do
        local rank = ranks[id][spec]
        if selected[spec] == true and rank and (not best or rank < best) then best = rank end
    end
    return best
end

local function AddSpecLine(tooltip, spec, rank)
    tooltip:AddLine(("|T%d:20:20:0:0|t %s: Рейтинг %d"):format(specIcons[spec], specNames[spec], rank),
        244 / 255, 140 / 255, 186 / 255)
    local line = _G[tooltip:GetName() .. "TextLeft" .. tooltip:NumLines()]
    if not line then return end
    local fonts = tooltipFonts[tooltip] or {}
    tooltipFonts[tooltip] = fonts
    fonts[line] = fonts[line] or { line:GetFont() }
    local _, size, flags = entryFont:GetFont()
    line:SetFont("Fonts\\FRIZQT___CYR.TTF", size, flags)
end

local function ClearRanks(tooltip)
    marked[tooltip] = nil
    local fonts = tooltipFonts[tooltip]
    if not fonts then return end
    for line, font in pairs(fonts) do line:SetFont(unpack(font)) end
    tooltipFonts[tooltip] = nil
end

local function AddRanks(tooltip, data)
    if not itemTooltips[tooltip] or tooltip:IsForbidden() then return end
    local owner = tooltip:GetOwner()
    local fromWindow = owner and owner.rainonDungeonLootID
    local id = data and ns.Number(data.id)
    if not id then
        local _, link = tooltip:GetItem()
        if type(link) == "string" and not (issecretvalue and issecretvalue(link)) then
            id = tonumber(link:match("item:(%d+)"))
        end
    end
    id = id or fromWindow
    if not id or not ranks[id] or marked[tooltip] == id then return end
    if id ~= fromWindow and not ns.Enabled(feature) then return end
    marked[tooltip] = id

    local itemRanks, ordered = ranks[id], {}
    for spec in ipairs(specNames) do
        if itemRanks[spec] then ordered[#ordered + 1] = spec end
    end
    table.sort(ordered, function(a, b)
        if itemRanks[a] == itemRanks[b] then return a < b end
        return itemRanks[a] < itemRanks[b]
    end)
    tooltip:AddLine(" ")
    tooltip:AddLine("RainonUI: трекер по wowtbc", 1, 0.82, 0)
    for _, spec in ipairs(ordered) do AddSpecLine(tooltip, spec, itemRanks[spec]) end
end

local panel, scroll, content, bossFilter, empty
local rows = {}
local currentDungeon, refreshPending, pendingPortraits, Refresh
local rowWidth, columns, itemStep = 0, 0, 38
local windowPadding, positioned
local minBosses, defaultBosses, maxBosses = 3, 5, 10
local rowCount
local displayedDungeon, displayedJournal, bossEntries, RenderDungeon
local trackedJournal
local bankOpen, bankKey
local russianNames = {
    ["Crimson Hammersmith"] = "Молотобоец из Багрового Легиона",
    ["Black Guard Swordsmith"] = "Оружейник Черной Стражи",
    ["Jarien and Sothos"] = "Джариен и Сотос",
    ["Mor Grayhoof"] = "Мор Серое Копыто",
    ["Kormok"] = "Кормок",
    ["Gordok Tribute Chest"] = "Сундук с данью Гордока",
    ["Venomridge"] = "Ядогорб",
    ["Direhorn Matriarch"] = "Дикорог-матриарх",
    ["Snowtalon"] = "Снежнокоготь",
    ["Vitrix"] = "Витрикс",
    ["Tidemistress Ca'zass"] = "Повелительница приливов Ка'засс",
    ["Katerina the Cleaner"] = "Катерина Чистильщица",
    ["Withermaw"] = "Сухозев",
}

local function ClientContent(journal)
    return journal.ContentLocales and journal.ContentLocales[locale]
end

local function DungeonName(journal, key)
    local content = ClientContent(journal)
    local entry = content and content.dungeons and content.dungeons[key]
    return entry and entry.name or key
end

local function BossName(journal, boss)
    local content = ClientContent(journal)
    local name = content and content.bosses and content.bosses[boss.name]
    if name and (locale ~= "ruRU" or name ~= boss.name) then return name end
    if locale ~= "ruRU" then return boss.name end
    if russianNames[boss.name] then return russianNames[boss.name] end
    local npc = boss.npcID
    local saved = ForeverDungeonJournalDB and ForeverDungeonJournalDB.clientNames
    saved = saved and saved[locale]
    name = saved and saved.bosses and saved.bosses[npc]
    if name and name ~= boss.name then return name end
    if npc and C_TooltipInfo and C_TooltipInfo.GetHyperlink then
        local link = ("unit:Creature-0-0-0-0-%d-0000000000"):format(npc)
        local ok, data = pcall(C_TooltipInfo.GetHyperlink, link)
        local line = ok and data and data.lines and data.lines[1]
        if line and TooltipUtil and TooltipUtil.SurfaceArgs then pcall(TooltipUtil.SurfaceArgs, line) end
        name = line and line.leftText
        if not (issecretvalue and issecretvalue(name)) and type(name) == "string" and name ~= ""
            and name ~= boss.name and name ~= UNKNOWNOBJECT and name ~= UNKNOWN and name ~= RETRIEVING_DATA then
            return name
        end
    end
    return "Имя загружается"
end

local function DrawPortrait(journal, dungeon, boss, texture)
    texture:SetTexCoord(0, 1, 0, 1)
    if journal.SetBossPortrait and journal.SetBossPortrait(texture, dungeon, boss) then return true end
    texture:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
    return false
end

local function ActiveRun(journal)
    local log = journal.RunLog
    local run = log and log.IsInside and log.IsInside() and log.Current and log.Current()
    if run and not (run.test or run.closed or run.outside) then return run end
end

local function UpdateKilledBosses()
    if not panel or not panel:IsShown() then return end
    local run = ActiveRun(displayedJournal)
    local killed = {}
    if run and run.dungeon == displayedDungeon then
        for _, kill in ipairs(run.kills or {}) do
            if kill.b then killed[kill.b] = true end
        end
    end
    for index = 1, rowCount do
        local row = rows[index]
        row.killed:SetShown(killed[row.bossName] == true)
    end
end

local function ScheduleRefresh()
    if refreshPending then return end
    refreshPending = true
    C_Timer.After(0.4, Refresh)
end

local function WatchRunLog(journal)
    if trackedJournal == journal or not journal.RunLogChanged then return end
    local run = ActiveRun(journal)
    local lastDungeon = run and run.dungeon
    hooksecurefunc(journal, "RunLogChanged", function()
        UpdateKilledBosses()
        local currentRun = ActiveRun(journal)
        local dungeon = currentRun and currentRun.dungeon
        if dungeon ~= lastDungeon then
            lastDungeon = dungeon
            if ns.Enabled(windowFeature) then ScheduleRefresh() end
        end
    end)
    trackedJournal = journal
end

local function HiddenBosses(dungeon)
    local filters = ns.db.dungeonLootHiddenBosses
    return filters and filters[dungeon]
end

local function SetBossHidden(dungeon, name, hidden)
    ns.db.dungeonLootHiddenBosses = ns.db.dungeonLootHiddenBosses or {}
    local filters = ns.db.dungeonLootHiddenBosses
    filters[dungeon] = filters[dungeon] or {}
    filters[dungeon][name] = hidden and true or nil
end

local function ScanBag(items, bag)
    local slots = ns.Number(C_Container.GetContainerNumSlots(bag)) or 0
    for slot = 1, slots do
        local id = ns.Number(C_Container.GetContainerItemID(bag, slot))
        if ranks[id] then items[id] = true end
    end
    return slots
end

local function BankSnapshot()
    if not bankKey then
        local guid = UnitGUID("player")
        if not (issecretvalue and issecretvalue(guid)) and type(guid) == "string" then bankKey = guid end
    end
    local banks = ns.db.dungeonLootBanks
    if not bankOpen then return banks and banks[bankKey] end

    local bank, slots = {}, 0
    for tab = 1, 9 do
        local bag = Enum.BagIndex["CharacterBankTab_" .. tab]
        if bag then slots = slots + ScanBag(bank, bag) end
    end
    if slots == 0 then return banks and banks[bankKey] end
    if bankKey then
        ns.db.dungeonLootBanks = banks or {}
        ns.db.dungeonLootBanks[bankKey] = bank
    end
    return bank
end

local function RefreshOwnership()
    if not bankOpen and (not panel or not panel:IsShown()) then return end
    local bank = BankSnapshot()
    if not panel or not panel:IsShown() then return end
    local bags = {}
    for bag = 0, NUM_BAG_SLOTS or 4 do ScanBag(bags, bag) end
    if Enum.BagIndex.ReagentBag then ScanBag(bags, Enum.BagIndex.ReagentBag) end
    for index = 1, rowCount do
        for _, button in ipairs(rows[index].items) do
            if button:IsShown() then
                local id = button.rainonDungeonLootID
                local inBank = bank and bank[id]
                if not bank then
                    local all = ns.Number(C_Item.GetItemCount(id, true, false, false, false)) or 0
                    local carried = ns.Number(C_Item.GetItemCount(id)) or 0
                    inBank = all > carried
                end
                local owned = bags[id] or inBank
                button.check:SetShown(not not owned)
                button.rank:SetShown(not owned)
            end
        end
    end
end

local function VisibleBosses()
    return math.max(minBosses, math.min(maxBosses, math.floor(ns.Number(ns.db.dungeonLootVisibleBosses) or defaultBosses)))
end

local function PinWindowTop()
    local left, top = panel:GetLeft(), panel:GetTop()
    if not left or not top then return end
    left = left - (UIParent:GetLeft() or 0)
    top = top - (UIParent:GetBottom() or 0)
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    return top
end

local function UpdateHeight()
    local count = VisibleBosses()
    local fullHeight = rowCount > 0 and rows[rowCount].bottom or 38
    local visibleHeight = rowCount > 0 and rows[math.min(rowCount, count)].bottom or fullHeight
    local top = positioned and PinWindowTop()
    local available = top and (top - 12) or (UIParent:GetHeight() - 24)
    local panelHeight = math.max(windowPadding + 1, math.min(visibleHeight + windowPadding, available))
    panel:SetHeight(panelHeight)
    scroll:UpdateScrollChildRect()
    local range = scroll:GetVerticalScrollRange()
    if scroll:GetVerticalScroll() > range then scroll:SetVerticalScroll(range) end
    scroll.ScrollBar:SetShown(fullHeight + windowPadding > panelHeight)
end

local function HideTooltip(button)
    if GameTooltip:IsOwned(button) then GameTooltip:Hide() end
end

local function CreatePanel()
    panel = ns.CreateLootPanel("RainonUIForeverDungeonLoot", "RainonUI", rowWidth + 44, 280)
    panel:SetPoint("TOP", UIParent, "TOP", 0, -36)
    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    tinsert(UISpecialFrames, panel:GetName())

    panel.dungeonTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    local title = panel.dungeonTitle
    title:SetPoint("TOPLEFT", 14, -34)
    title:SetPoint("TOPRIGHT", -14, -34)
    title:SetHeight(33)
    title:SetJustifyH("LEFT")
    title:SetJustifyV("TOP")
    title:SetWordWrap(true)
    title:SetMaxLines(2)

    local filterRow = CreateFrame("Frame", nil, panel)
    local filterTop = 72
    filterRow:SetPoint("TOPLEFT", 14, -filterTop)
    filterRow:SetPoint("TOPRIGHT", -16, -filterTop)
    local filterLabel = filterRow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    filterLabel:SetText("В")
    local filterHeight = 24 + math.floor(filterLabel:GetStringHeight() / 2 + 0.5)
    filterRow:SetHeight(filterHeight)
    filterLabel:SetPoint("LEFT")
    filterLabel:SetText("Фильтр боссов:")
    bossFilter = CreateFrame("DropdownButton", nil, filterRow, "WowStyle1DropdownTemplate")
    bossFilter:SetPoint("LEFT", filterLabel, "RIGHT", 8, 0)
    bossFilter:SetPoint("RIGHT")
    bossFilter:SetHeight(filterHeight)
    local caption = bossFilter.Text
    if caption then
        caption:ClearAllPoints()
        caption:SetPoint("LEFT", bossFilter, "LEFT", 9, 0)
        caption:SetPoint("RIGHT", bossFilter, "RIGHT", -29, 0)
        caption:SetJustifyV("MIDDLE")
    end
    local divider = panel:CreateTexture(nil, "ARTWORK")
    divider:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")
    divider:SetHeight(7)
    divider:SetPoint("TOPLEFT", filterRow, "BOTTOMLEFT", -2, -6)
    divider:SetPoint("TOPRIGHT", filterRow, "BOTTOMRIGHT", 4, -6)
    local scrollGap, bottomPadding = 16, 12
    windowPadding = filterTop + filterHeight + scrollGap + bottomPadding
    bossFilter:SetupMenu(function(_, menu)
        if not bossEntries then return end
        local dungeon, journal = displayedDungeon, displayedJournal
        local reset = menu:CreateButton("Сбросить фильтр", function()
            if ns.db.dungeonLootHiddenBosses then ns.db.dungeonLootHiddenBosses[dungeon] = nil end
            ns.db.dungeonLootSpecs = nil
            RenderDungeon()
        end)
        reset:SetResponse(MenuResponse.Refresh)
        local specs = menu:CreateButton("Специализация")
        for index, name in ipairs(specNames) do
            local spec = index
            specs:CreateCheckbox(name, function() return SelectedSpecs()[spec] == true end, function()
                if ToggleSpec(spec) then RenderDungeon() end
            end)
        end
        local size = menu:CreateButton("Размер окна")
        for count = minBosses, maxBosses do
            local value = count
            size:CreateRadio(("%d - %s"):format(value, value < 5 and "босса" or "боссов"), function()
                return VisibleBosses() == value
            end, function()
                ns.db.dungeonLootVisibleBosses = value
                UpdateHeight()
            end)
        end
        menu:CreateDivider()
        menu:SetScrollMode(300)
        for _, entry in ipairs(bossEntries) do
            local boss = entry.boss
            local function Checked()
                local hidden = HiddenBosses(dungeon)
                return not (hidden and hidden[boss.name])
            end
            local option = menu:CreateCheckbox(BossName(journal, boss), Checked, function()
                SetBossHidden(dungeon, boss.name, Checked())
                RenderDungeon()
            end)
            option:AddInitializer(function(button)
                button.fontString:SetFontObject(entryFont)
                local icon = button:AttachTexture()
                button.rainonBossIcon = icon
                icon:SetSize(20, 20)
                icon:SetPoint("LEFT", button.fontString, "RIGHT", 6, 0)
                DrawPortrait(journal, dungeon, boss, icon)
                return button.fontString:GetUnboundedStringWidth() + 56, 24
            end)
            option:AddResetter(function(button)
                if journal.ReleasePortrait and button.rainonBossIcon then
                    journal.ReleasePortrait(button.rainonBossIcon)
                end
                button.rainonBossIcon = nil
            end)
        end
    end)
    empty = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    empty:SetPoint("TOPLEFT", filterRow, "BOTTOMLEFT", 0, -25)
    empty:SetPoint("RIGHT", -14, 0)
    empty:SetJustifyH("LEFT")
    empty:SetWordWrap(true)
    panel:HookScript("OnHide", function()
        pendingPortraits = nil
        bossFilter:CloseMenu()
        panel:StopMovingOrSizing()
        local journal = ForeverDungeonJournal_NS
        for _, row in ipairs(rows) do
            if journal and journal.ReleasePortrait then journal.ReleasePortrait(row.portrait) end
            for _, button in ipairs(row.items) do HideTooltip(button) end
        end
    end)
    scroll = CreateFrame("ScrollFrame", nil, panel, "ScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", filterRow, "BOTTOMLEFT", 0, -scrollGap)
    scroll:SetPoint("BOTTOMRIGHT", -30, bottomPadding)
    content = CreateFrame("Frame", nil, scroll)
    content:SetHeight(1)
    scroll:SetScrollChild(content)
    scroll:HookScript("OnScrollRangeChanged", function(_, _, range)
        scroll.ScrollBar:SetShown(range > 0)
        if scroll:GetVerticalScroll() > range then scroll:SetVerticalScroll(range) end
    end)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local offset = self:GetVerticalScroll() - delta * 60
        self:SetVerticalScroll(math.max(0, math.min(offset, self:GetVerticalScrollRange())))
    end)
end

local function CreateRow()
    local row = CreateFrame("Frame", nil, content)
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.name:SetPoint("TOPLEFT", 0, -2)
    row.name:SetJustifyH("LEFT")
    row.bossButton = CreateFrame("Button", nil, row)
    row.bossButton:SetSize(32, 32)
    row.bossButton:SetPoint("TOPLEFT", 0, -21)
    row.bossButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    row.bossButton:SetScript("OnClick", function(self)
        local journal = ForeverDungeonJournal_NS
        local journalWindow = _G.ForeverDungeonJournalFrame
        if not (self.bossIndex and journal and journal.OpenBossPage and journalWindow) then return end
        panel:Hide()
        journalWindow:Show()
        journal.OpenBossPage(self.dungeon, self.bossIndex)
    end)
    row.portrait = row.bossButton:CreateTexture(nil, "ARTWORK")
    row.portrait:SetAllPoints()
    row.killed = row.bossButton:CreateTexture(nil, "OVERLAY", nil, 2)
    row.killed:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
    row.killed:SetPoint("CENTER")
    row.killed:SetSize(22, 22)
    local divider = row:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(0.66, 0.55, 0.38, 0.55)
    divider:SetSize(1, 30)
    divider:SetPoint("TOPLEFT", 39, -22)
    row.items = {}
    return row
end

local function CreateItem(row)
    local button = CreateFrame("Button", nil, row)
    button:SetSize(32, 32)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local badge = button:CreateTexture(nil, "OVERLAY", nil, 1)
    badge:SetColorTexture(0.08, 0.06, 0.04, 0.92)
    badge:SetSize(17, 16)
    badge:SetPoint("BOTTOMRIGHT", 1, -1)
    button.rank = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall", 2)
    button.rank:SetPoint("CENTER", badge)
    button.rank:SetTextColor(1, 0.89, 0.65)
    button.check = button:CreateTexture(nil, "OVERLAY", nil, 2)
    button.check:SetSize(16, 16)
    button.check:SetPoint("CENTER", badge)
    button.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetItemByID(self.rainonDungeonLootID)
        AddRanks(GameTooltip)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", HideTooltip)
    button:SetScript("OnHide", HideTooltip)
    return button
end

local function RankedItems(journal, dungeon, boss, extraLoot)
    local ids, seen = {}, {}
    local shared = journal.GetBossSharedLoot and journal.GetBossSharedLoot(dungeon, boss)
    for _, loot in ipairs({ boss.loot or {}, shared or {}, extraLoot or {} }) do
        for _, item in ipairs(loot) do
            local id = item[1]
            if ranks[id] and not seen[id] then
                ids[#ids + 1] = id
                seen[id] = true
            end
        end
    end
    return ids
end

ns.DungeonLootRankSource = {
    names = specNames,
    dungeonName = DungeonName,
    bestRank = BestRank,
    addRanks = AddRanks,
    dungeonItems = function(journal, dungeon, entry)
        local ids, seen = {}, {}
        local function AddLoot(boss)
            for _, id in ipairs(RankedItems(journal, dungeon, boss)) do
                if not seen[id] then
                    ids[#ids + 1] = id
                    seen[id] = true
                end
            end
        end
        for _, boss in ipairs(entry.bosses) do AddLoot(boss) end
        if stratholmeSmiths[dungeon] then AddLoot(stratholmeSmiths[dungeon]) end
        return ids
    end,
}

local function FilterItems(items, selected)
    local ids, filteredRanks = {}, {}
    for _, id in ipairs(items) do
        local rank = BestRank(id, selected)
        if rank then
            ids[#ids + 1] = id
            filteredRanks[id] = rank
        end
    end
    table.sort(ids, function(a, b)
        if filteredRanks[a] == filteredRanks[b] then return a < b end
        return filteredRanks[a] < filteredRanks[b]
    end)
    return ids, filteredRanks
end

RenderDungeon = function()
    local journal, dungeon = displayedJournal, displayedDungeon
    local hidden = HiddenBosses(dungeon)
    local selected = SelectedSpecs()
    local count, enabledBosses, top, retry = 0, 0, 0, {}
    for _, entry in ipairs(bossEntries) do
        local boss = entry.boss
        local ids, filteredRanks
        if not (hidden and hidden[boss.name]) then
            enabledBosses = enabledBosses + 1
            ids, filteredRanks = FilterItems(entry.items, selected)
        end
        if ids and #ids > 0 then
            count = count + 1
            local row = rows[count] or CreateRow()
            rows[count] = row
            local height = 22 + math.ceil(#ids / columns) * itemStep
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -top)
            row:SetSize(rowWidth, height)
            local name = BossName(journal, boss)
            row.bossName = boss.name
            row.name:SetText(name)
            row.bossButton.dungeon, row.bossButton.bossIndex = dungeon, entry.index
            row.bossButton:EnableMouse(entry.index ~= nil)
            if not DrawPortrait(journal, dungeon, boss, row.portrait) or name == "Имя загружается" then retry[row] = boss end
            for index, id in ipairs(ids) do
                local button = row.items[index] or CreateItem(row)
                row.items[index] = button
                button:ClearAllPoints()
                button:SetPoint("TOPLEFT", 46 + ((index - 1) % columns) * itemStep,
                    -21 - math.floor((index - 1) / columns) * itemStep)
                HideTooltip(button)
                button.rainonDungeonLootID = id
                button.rank:SetText(filteredRanks[id])
                local icon = C_Item.GetItemIconByID(id)
                button.icon:SetTexture(icon or questionMark)
                if not icon then C_Item.RequestLoadItemDataByID(id) end
                button:Show()
            end
            for index = #ids + 1, #row.items do row.items[index]:Hide() end
            row:Show()
            top = top + height
            row.bottom = top
        end
    end
    pendingPortraits = nil
    for index = count + 1, #rows do
        local row = rows[index]
        if journal.ReleasePortrait then journal.ReleasePortrait(row.portrait) end
        row:Hide()
    end
    rowCount = count
    empty:SetText(enabledBosses == 0 and "Нет выбранных боссов" or "Для выбранных специализаций добычи нет")
    empty:SetShown(count == 0)
    bossFilter:OverrideText(enabledBosses == #bossEntries and "Все боссы"
        or ("Выбрано %d из %d"):format(enabledBosses, #bossEntries))
    content:SetHeight(math.max(1, top))
    UpdateHeight()
    scroll:SetVerticalScroll(0)
    panel:Show()
    if not positioned then positioned = PinWindowTop() ~= nil end
    UpdateKilledBosses()
    RefreshOwnership()
    if next(retry) then
        pendingPortraits = retry
        C_Timer.After(8, function()
            if pendingPortraits ~= retry then return end
            pendingPortraits = nil
            for row, boss in pairs(retry) do
                row.name:SetText(BossName(journal, boss))
                DrawPortrait(journal, dungeon, boss, row.portrait)
            end
        end)
    end
end

local function ShowDungeon(journal, dungeon, entry)
    local entries, largest = {}, 0
    local function AddBoss(boss, index, extraLoot)
        local ids = RankedItems(journal, dungeon, boss, extraLoot)
        if #ids == 0 then return end
        entries[#entries + 1] = { boss = boss, index = index, items = ids }
        largest = math.max(largest, #ids)
    end
    local smith = stratholmeSmiths[dungeon]
    for index, boss in ipairs(entry.bosses or {}) do
        if smith and (boss.npcID == smith.npcID or boss.name == smith.name) then
            AddBoss(boss, index, smith.loot)
            smith = nil
        else
            AddBoss(boss, index)
        end
    end
    if smith then AddBoss(smith) end
    if #entries == 0 then return false end
    columns = math.max(5, math.min(6, largest + 2))
    rowWidth = 46 + columns * itemStep
    displayedJournal, displayedDungeon, bossEntries = journal, dungeon, entries
    WatchRunLog(journal)
    if not panel then CreatePanel() end
    panel:SetWidth(rowWidth + 44)
    panel.dungeonTitle:SetText(DungeonName(journal, dungeon))
    content:SetWidth(rowWidth)
    bossFilter:GenerateMenu()
    RenderDungeon()
    return true
end

function ns.ShowDungeonLoot(dungeon)
    local journal = ForeverDungeonJournal_NS
    local entry = journal and journal.DB and journal.DB[dungeon]
    return entry and ShowDungeon(journal, dungeon, entry)
end

local function WingFromMap(journal, wings)
    if not (wings and journal.DUNGEON_MAPS and C_Map and C_Map.GetBestMapForUnit) then return end

    local mapID = ns.Number(C_Map.GetBestMapForUnit("player"))
    if not mapID then return end
    local match
    for _, wing in ipairs(wings) do
        local map = journal.DUNGEON_MAPS[wing]
        for _, floor in ipairs(map and map.floors or {}) do
            if floor.uiMapID == mapID then
                if match and match ~= wing then return end
                match = wing
            end
        end
    end
    return match
end

local function SpireWingFromText(journal, instanceName)
    local function Match(text)
        if issecretvalue and issecretvalue(text) then return end
        if text == DungeonName(journal, "Lower Blackrock Spire") then return "Lower Blackrock Spire" end
        local wing = journal.WingFromText and journal.WingFromText(text)
        if wing == "Lower Blackrock Spire" or wing == "Upper Blackrock Spire" then return wing end
    end
    return Match(instanceName) or Match(GetRealZoneText and GetRealZoneText())
        or Match(GetSubZoneText and GetSubZoneText())
end

local function CurrentLootDungeon(journal)
    local dungeon = journal.CurrentDungeon()
    local instanceName, _, _, _, _, _, _, rawInstanceID = GetInstanceInfo()
    local instanceID = ns.Number(rawInstanceID)
    if dungeon and (instanceID ~= 229 or dungeon ~= "Lower Blackrock Spire") then return dungeon end

    local wings = journal.RunLogWingGroups and journal.RunLogWingGroups[instanceID]
    local mapWing = WingFromMap(journal, wings)
    if mapWing then return mapWing end

    local run = ActiveRun(journal)
    if run and run.map and journal.DB and journal.DB[run.dungeon] and (not instanceID or run.map == instanceID) then
        if not dungeon then return run.dungeon end
        -- The journal defaults to Lower Spire for the shared entrance. Confirmed Upper Spire wins over that default.
        if run.wingConfirmed and run.dungeon == "Upper Blackrock Spire" then
            return SpireWingFromText(journal, instanceName) or run.dungeon
        end
    end
    return dungeon
end

function ns.OpenCurrentDungeonLoot()
    local journal = ForeverDungeonJournal_NS
    if not journal or not journal.CurrentDungeon then
        print("RainonUI: для просмотра добычи включи ForeverDungeonJournal.")
        return
    end
    local inside, kind = IsInInstance()
    if not inside or (kind ~= "party" and kind ~= "raid") then
        print("RainonUI: ПКМ открывает добычу внутри подземелья.")
        return
    end
    local dungeon = CurrentLootDungeon(journal)
    if not dungeon then
        print("RainonUI: не удалось определить подземелье или его крыло.")
    elseif not ns.ShowDungeonLoot(dungeon) then
        print("RainonUI: в этом подземелье нет добычи с рейтингом.")
    elseif ns.Enabled(windowFeature) then
        currentDungeon = dungeon
    end
end

Refresh = function()
    refreshPending = false
    local inside, kind = IsInInstance()
    local journal = ForeverDungeonJournal_NS
    local dungeon
    if ns.Enabled(windowFeature) and inside and (kind == "party" or kind == "raid") and journal and journal.CurrentDungeon then
        WatchRunLog(journal)
        dungeon = CurrentLootDungeon(journal)
    end
    if dungeon == currentDungeon then return end
    currentDungeon = dungeon
    if panel then panel:Hide() end
    if dungeon then ns.ShowDungeonLoot(dungeon) end
end

local function SettingChanged()
    if ns.Enabled(windowFeature) then
        ScheduleRefresh()
    else
        currentDungeon = nil
        if panel then panel:Hide() end
    end
end

ns.AddSetting(feature, "Рейтинг добычи для паладина", nil, nil, "equipment")
ns.AddSetting(windowFeature, "Окно добычи в подземелье", SettingChanged, nil, "equipment")
ns.On("BAG_UPDATE_DELAYED", RefreshOwnership)
ns.On("BANKFRAME_OPENED", function()
    bankOpen = true
    RefreshOwnership()
end)
ns.On("PLAYERBANKSLOTS_CHANGED", RefreshOwnership)
ns.On("BANKFRAME_CLOSED", function()
    bankOpen = false
    RefreshOwnership()
end)
ns.On("PLAYER_ENTERING_WORLD", ScheduleRefresh)
ns.On("ZONE_CHANGED_NEW_AREA", ScheduleRefresh)
ns.On("ZONE_CHANGED", ScheduleRefresh)
ns.On("ZONE_CHANGED_INDOORS", ScheduleRefresh)
ns.On("ADDON_LOADED", function(name)
    if name == "ForeverDungeonJournal" then ScheduleRefresh() end
end)
ns.On("GET_ITEM_INFO_RECEIVED", function(id, success)
    if not success or not ranks[id] or not panel or not panel:IsShown() then return end
    local icon = C_Item.GetItemIconByID(id)
    if not icon then return end
    for _, row in ipairs(rows) do
        if row:IsShown() then
            for _, button in ipairs(row.items) do
                if button:IsShown() and button.rainonDungeonLootID == id then button.icon:SetTexture(icon) end
            end
        end
    end
end)
ns.On("PLAYER_LOGIN", function()
    local processor = TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
    for _, name in ipairs(tooltipNames) do
        local tooltip = _G[name]
        if tooltip then
            itemTooltips[tooltip] = true
            tooltip:HookScript("OnTooltipCleared", ClearRanks)
            if not processor and tooltip:HasScript("OnTooltipSetItem") then
                tooltip:HookScript("OnTooltipSetItem", AddRanks)
            end
        end
    end
    if processor then processor(Enum.TooltipDataType.Item, AddRanks) end
end)
