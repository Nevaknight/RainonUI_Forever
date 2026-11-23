local _, ns = ...

local portrait = "Interface\\AddOns\\RainonUI_Forever\\Media\\logo"
local tabs = {
    { key = "general", title = "Общие", icon = "Interface\\Icons\\INV_Misc_Gear_01" },
    { key = "equipment", title = "Экипировка", icon = "Interface\\Icons\\INV_Chest_Chain_05" },
    { key = "characters", title = "Персонажи", icon = "Interface\\Icons\\Achievement_Character_Human_Male", feature = "rest" },
    { key = "macros", title = "Макросы", icon = "Interface\\Icons\\ClassIcon_Paladin" },
}

local entryStyles = {
    minimap = { icon = "Interface\\Icons\\INV_Misc_Map_01" },
    reload = { title = "Кнопка перезагрузки", icon = "Interface\\Icons\\INV_Misc_PocketWatch_01" },
    rest = { icon = "Interface\\Icons\\Spell_Nature_Sleep" },
    stats = { title = "Сокращать строки", detail = "Бонусы экипировки", icon = "Interface\\Icons\\INV_Misc_Note_01" },
    statsMerge = { title = "Объединять бонусы", detail = "Равные урон и исцеление", icon = "Interface\\Icons\\Spell_Holy_HolyBolt" },
    statsColors = { title = "Окрашивать характеристики", icon = "Interface\\Icons\\INV_Inscription_InkOrange01" },
    groupNeed = { title = "Кто выбрал «Нужно»", detail = "Групповая добыча", icon = 132386 },
    autoGreed = { title = "Автовыбор:", detail = "Не откажусь", icon = 133785 },
    dungeonLootRanks = { title = "Добыча", detail = "Рейтинг паладина", icon = "Interface\\Icons\\INV_Misc_Book_09",
        tooltip = "Показывает места для трёх спеков в подсказках предметов." },
    dungeonLootWindow = { title = "Добыча", detail = "Окно в подземелье", icon = "Interface\\Icons\\INV_Misc_Key_10",
        tooltip = "Открывает список добычи при входе в подземелье." },
    dungeonLootCatalog = { title = "Добыча", detail = "Все подземелья", icon = "Interface\\Icons\\INV_Misc_Book_11",
        tooltip = "Shift + ЛКМ по значку RainonUI у миникарты открывает каталог добычи." },
    updateNotice = { icon = "Interface\\Icons\\INV_Scroll_03",
        tooltip = "Показывает окно обновлений аддона при заходе в игру" },
    itemNotes = { title = "Личные подсказки", detail = "Предметы", icon = 134331 },
}

local ink = { 0.19, 0.10, 0.035 }
local columnWidth, columnStep = 222, 242
local firstRow, rowStep = -75, 68

local function BookText(parent, font, text)
    local label = parent:CreateFontString(nil, "OVERLAY", font)
    label:SetTextColor(unpack(ink))
    label:SetShadowOffset(0, 0)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    return label
end

local function SetTooltip(button, title, detail)
    button:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetText(title)
        if detail then GameTooltip:AddLine(detail, 1, 1, 1, true) end
        GameTooltip:Show()
    end)
    button:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

local function MakeEntry(button, title, detail, texture, atlas)
    button:SetHeight(54)

    -- Geometry of the square spellbook item in Blizzard_SpellBookItem.xml and ArtSet.Square.
    local slot = CreateFrame("Frame", nil, button)
    slot:SetSize(40, 40)
    slot:SetPoint("LEFT", 7, 1)

    local icon = button:CreateTexture(nil, "ARTWORK", nil, -1)
    icon:SetSize(36, 36)
    icon:SetPoint("CENTER", slot)
    if atlas then icon:SetAtlas(atlas) else icon:SetTexture(texture) end
    local mask = button:CreateMaskTexture()
    mask:SetAtlas("spellbook-item-spellicon-mask", false)
    mask:SetAllPoints(icon)
    icon:AddMaskTexture(mask)

    local shadow = button:CreateTexture(nil, "ARTWORK", nil, 1)
    shadow:SetAtlas("spellbook-item-iconframe-shadow")
    shadow:SetPoint("TOPLEFT", slot, "TOPLEFT", -12, 3)
    shadow:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", 2, -8)

    local border = button:CreateTexture(nil, "OVERLAY", nil, 1)
    border:SetAtlas("spellbook-item-iconframe")
    border:SetPoint("TOPLEFT", slot, "TOPLEFT", -11, 1)
    border:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", 1, -7)
    border:SetTexelSnappingBias(0)
    border:SetSnapToPixelGrid(false)

    local hover = button:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAtlas("spellbook-item-iconframe-hover")
    hover:SetAllPoints(slot)
    hover:SetBlendMode("ADD")
    hover:SetAlpha(0.25)
    hover:SetTexelSnappingBias(0)
    hover:SetSnapToPixelGrid(false)

    local label = BookText(button, "SystemFont_Large", title)
    local rightPad = button:IsObjectType("CheckButton") and 28 or 4
    local centerY = detail and 9 or 1
    label:SetPoint("LEFT", 56, centerY)
    label:SetPoint("RIGHT", -rightPad, centerY)
    if detail then
        local subtitle = BookText(button, "SystemFont_Med1", detail)
        subtitle:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
        subtitle:SetWidth(button:GetWidth() - 56 - rightPad)
        subtitle:SetWordWrap(false)
    end
end

local function MakeCheck(page, option, x, y, width, refresh)
    local style = option.style or entryStyles[option.key] or {}
    local check = CreateFrame("CheckButton", nil, page)
    check:SetWidth(width)
    check:SetPoint("TOPLEFT", x, y)
    MakeEntry(check, style.title or option.label, style.detail, style.icon or 134400, style.atlas)

    local box = check:CreateTexture(nil, "ARTWORK")
    box:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
    box:SetSize(23, 23)
    box:SetPoint("RIGHT", -1, 0)
    local mark = check:CreateTexture(nil, "OVERLAY", nil, 1)
    mark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    mark:SetAllPoints(box)
    check.Mark = mark
    SetTooltip(check, option.label, option.key == "statsMerge" and "Доступно при сокращении строк экипировки." or style.tooltip)
    check:SetScript("OnClick", function(self)
        ns.db.features[option.key] = not not self:GetChecked()
        if option.changed then option.changed() end
        refresh()
    end)
    return check
end

local function MakeTab(window, entry)
    local tab = CreateFrame("Button", nil, window)
    tab:SetSize(44, 35)
    tab:SetFrameLevel(window:GetFrameLevel() + 4)

    local icon = tab:CreateTexture(nil, "ARTWORK")
    icon:SetSize(32, 32)
    icon:SetPoint("BOTTOM", -1, 1)
    icon:SetTexture(entry.icon)

    local border = tab:CreateTexture(nil, "ARTWORK", nil, -1)
    border:SetAtlas("spellbook-Tab-Frame-C60", true)
    border:SetPoint("BOTTOM", 0, 1)

    -- The spellbook tab frame is open at the bottom. Use a full ring for selection.
    local selected = tab:CreateTexture(nil, "OVERLAY", nil, 1)
    selected:SetAtlas("UI-HUD-ActionBar-IconFrame-Mouseover")
    selected:SetSize(42, 42)
    selected:SetPoint("CENTER", icon)
    selected:SetVertexColor(1, 0.82, 0.14)
    selected:SetBlendMode("ADD")
    tab.Selected = selected

    tab:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
        window:SelectTab(entry.key)
    end)
    SetTooltip(tab, entry.title)
    return tab
end

local numberColors = { { "signed", "По знаку" }, { "stat", "Цвет характеристики" }, { "line", "Цвет строки" } }

local function NumberOptions(page)
    local label = BookText(page, "SystemFont_Med1", "Цвет чисел")
    label:SetPoint("TOPLEFT", columnStep + 8, firstRow - rowStep - 4)
    local dropdown = CreateFrame("DropdownButton", nil, page, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
    dropdown:SetWidth(206)
    dropdown:SetupMenu(function(_, menu)
        for _, entry in ipairs(numberColors) do
            local key, title = entry[1], entry[2]
            menu:CreateRadio(title, function() return ns.StatNumberColor() == key end, function()
                ns.db.statsNumberColor = key
            end)
        end
    end)
    SetTooltip(dropdown, "Цвет чисел", "В режиме «По знаку» плюс зелёный, минус красный, число без знака белое.")
    return dropdown, label
end

-- Spell IDs identify the entries across locales. Macro names must fit 16 characters including the prefix.
local livingAlly = "[@mouseover, help, nodead]"
local livingEnemy = "[@mouseover, harm, nodead]"
local deadAlly = "[@mouseover, help, dead]"
local paladinMacros = {
    [20271] = { suffix = "JUDGEMENT", target = livingEnemy },
    [1044] = { suffix = "BLESS_FREED", target = livingAlly, stopCasting = true },
    [19752] = { suffix = "DIVINE_INTER", target = livingAlly, stopCasting = true },
    [10278] = { suffix = "BLESS_PROT", target = livingAlly, stopCasting = true },
    [20729] = { suffix = "BLESS_SAC", target = livingAlly, stopCasting = true },
    [10308] = { suffix = "HAMMER_JUST", target = livingEnemy },
    [4987] = { suffix = "CLEANSE", target = livingAlly, stopCasting = true },
    [24239] = { suffix = "HAMMER_WRATH", target = livingEnemy },
    [10329] = { suffix = "HOLY_LIGHT", target = livingAlly },
    [20930] = { suffix = "HOLY_SHOCK", target = livingAlly .. livingEnemy },
    [10314] = { suffix = "EXORCISM", target = livingEnemy },
    [19943] = { suffix = "FLASH_LIGHT", target = livingAlly },
    [10310] = { suffix = "LAY_ON_HANDS", target = livingAlly, stopCasting = true },
    [1311595] = { suffix = "LIGHTS_VIGIL", target = livingAlly },
    [1328548] = { suffix = "OATH_LIGHT", target = livingAlly },
    [1152] = { suffix = "PURIFY", target = livingAlly },
    [20773] = { suffix = "REDEMPTION", target = deadAlly },
    [10326] = { suffix = "TURN_UNDEAD", target = livingEnemy },
}

local defaultSeals = { 20375, 21084 } -- Seal of Command, Seal of Righteousness
local paladinSealIDs = {
    21084, -- Seal of Righteousness
    21082, -- Seal of the Crusader
    20164, -- Seal of Justice
    20165, -- Seal of Light
    20166, -- Seal of Wisdom
    20375, -- Seal of Command
    1311649, -- Seal of Fury
}
local sealAlternateIDs = { [21084] = 20154, [1311649] = 1311656 }

local function PaladinSeals()
    local seals = {}
    for _, id in ipairs(paladinSealIDs) do
        local info = C_Spell.GetSpellInfo(id)
        local alternative = sealAlternateIDs[id]
        if not info and alternative then info = C_Spell.GetSpellInfo(alternative) end
        if info then seals[id] = info end
    end
    return seals
end

local function PaladinSpells()
    local spells = {}
    local _, class = UnitClass("player")
    if class ~= "PALADIN" then return spells end

    -- Match by the localized spell name so any learned rank of a listed spell qualifies.
    local macrosByName = {}
    for spellID, macro in pairs(paladinMacros) do
        local name = C_Spell.GetSpellName(spellID)
        if name then macrosByName[name] = macro end
    end
    local bank = Enum.SpellBookSpellBank.Player
    for index = 2, C_SpellBook.GetNumSpellBookSkillLines() do
        local line = C_SpellBook.GetSpellBookSkillLineInfo(index)
        if line and not line.shouldHide and not line.offSpecID then
            for slot = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
                local spell = C_SpellBook.GetSpellBookItemInfo(slot, bank)
                local macro = spell and macrosByName[spell.name]
                if macro and spell.itemType == Enum.SpellBookItemType.Spell and not spell.isPassive
                    and spell.spellID and not C_SpellBook.IsSpellBookItemLowRank(slot, bank) then
                    spells[spell.name] = {
                        name = spell.name,
                        spellID = spell.spellID,
                        iconID = spell.iconID,
                        macro = macro,
                    }
                end
            end
        end
    end
    return spells
end

local function AddSpellOptions(menu, spells, selected, choose)
    local keys = {}
    for key in pairs(spells) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return spells[a].name < spells[b].name end)
    menu:SetScrollMode(345)
    for _, key in ipairs(keys) do
        local spell = spells[key]
        local option = menu:CreateRadio(spell.name, function() return selected() == key end, function()
            choose(key)
        end)
        option:AddInitializer(function(row)
            row.fontString:SetFontObject(GameFontHighlight)
            local icon = row:AttachTexture()
            icon:SetSize(20, 20)
            icon:SetPoint("LEFT", row.fontString, "RIGHT", 6, 0)
            icon:SetTexture(spell.iconID or 134400)
            return row.fontString:GetUnboundedStringWidth() + 56, 24
        end)
    end
end

local function SavePaladinMacro(name, iconID, body, legacySpell)
    local prefix = "RainonUI — Forever: "
    if InCombatLockdown() then
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Выйди из боя, чтобы создать или обновить макрос.")
        return
    end

    local legacyName, legacyBody
    if legacySpell then
        legacyName = "RUIF-" .. legacySpell.spellID
        legacyBody = ("#showtooltip\n/cast [@mouseover,exists] %s"):format(legacySpell.name)
    end
    local accountCount = GetNumMacros()
    local index, oldIndex
    for i = 1, accountCount do
        local existingName, _, existingBody = GetMacroInfo(i)
        if existingName == name then
            index = i
            break
        end
        if legacySpell and not oldIndex and existingName and existingName:match("^RUIF%-%d+$")
            and (existingName == legacyName or existingBody == legacyBody) then
            oldIndex = i
        end
    end
    index = index or oldIndex
    if not index and accountCount >= Constants.MacroConsts.MAX_ACCOUNT_MACROS then
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Освободи место в общих макросах (/macro).")
        return
    end

    local ok, savedIndex
    if index then
        ok, savedIndex = pcall(EditMacro, index, name, iconID, body)
    else
        ok, savedIndex = pcall(CreateMacro, name, iconID, body, false)
    end
    if ok and savedIndex and savedIndex > 0 then
        local action = index and "обновлён" or "создан"
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. ("Макрос «%s» %s в общих макросах (/macro)."):format(name, action))
    else
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Не удалось сохранить макрос.")
    end
end

local function BuildMacrosPage(page)
    local selected
    local savedSeals = type(ns.db.macroSeals) == "table" and ns.db.macroSeals or defaultSeals
    local selectedSeals = { savedSeals[1], savedSeals[2] }
    local spells, seals = {}, {}
    local headingGap, dropdownGap, macroButtonWidth = 18, 7, 180
    local heading = BookText(page, "SystemFont_Large", "Основные способности")
    heading:SetPoint("TOPLEFT", 0, firstRow)
    heading:SetPoint("TOPRIGHT", 0, firstRow)
    local label = BookText(page, "SystemFont_Med1", "Изученная способность паладина")
    label:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -headingGap)
    label:SetPoint("TOPRIGHT", heading, "BOTTOMRIGHT", 0, -headingGap)

    local menu = CreateFrame("DropdownButton", nil, page, "WowStyle1DropdownTemplate")
    menu:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -dropdownGap)
    menu:SetPoint("TOPRIGHT", label, "BOTTOMRIGHT", 0, -dropdownGap)
    menu:SetHeight(26)
    menu:SetDefaultText("Выбери способность")

    local description = BookText(page, "GameFontHighlight", "")
    description:SetPoint("TOPLEFT", menu, "BOTTOMLEFT", 0, -dropdownGap)
    description:SetWidth(447)
    description:SetWordWrap(true)

    local button = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    button:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -14)
    button:SetSize(macroButtonWidth, 24)
    button:SetText("Создать макрос")

    local sealsHeading = BookText(page, "SystemFont_Large", "Печати")
    sealsHeading:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -26)
    local sealsLabel = BookText(page, "SystemFont_Med1",
        'Работает только для специализации "Воздаяние". Смена печатей на одной кнопке.')
    sealsLabel:SetPoint("TOPLEFT", sealsHeading, "BOTTOMLEFT", 0, -headingGap)
    sealsLabel:SetWidth(440)
    sealsLabel:SetWordWrap(true)
    local sealMenus = {}
    local sealPrompts = { "Первая печать", "Вторая печать" }
    local sealGap = 12
    for index = 1, #sealPrompts do
        local dropdown = CreateFrame("DropdownButton", nil, page, "WowStyle1DropdownTemplate")
        if index == 1 then
            dropdown:SetPoint("TOPLEFT", sealsLabel, "BOTTOMLEFT", 0, -dropdownGap)
        else
            dropdown:SetPoint("LEFT", sealMenus[1], "RIGHT", sealGap, 0)
        end
        dropdown:SetHeight(26)
        sealMenus[index] = dropdown
    end
    local function ResizeSealMenus(_, width)
        if width <= sealGap then return end
        local sealWidth = (width - sealGap) / 2
        for _, dropdown in ipairs(sealMenus) do dropdown:SetWidth(sealWidth) end
    end
    menu:HookScript("OnSizeChanged", ResizeSealMenus)
    ResizeSealMenus(menu, menu:GetWidth())

    local sealButton = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    sealButton:SetPoint("TOPLEFT", sealMenus[1], "BOTTOMLEFT", 0, -14)
    sealButton:SetSize(macroButtonWidth, 24)
    sealButton:SetText("Создать макрос печатей")

    local function RefreshSelection()
        local spell = spells[selected]
        button:SetEnabled(spell ~= nil)
        if spell then
            local text = ("«%s» применяется к подходящей цели под курсором."):format(spell.name)
            if spell.macro.stopCasting then text = text .. " Нажатие прерывает текущее заклинание." end
            description:SetText(text)
        elseif next(spells) then
            description:SetText("Выбери способность, чтобы увидеть, как сработает макрос.")
        else
            selected = nil
            description:SetText("В книге заклинаний пока нет доступных способностей паладина.")
        end
    end

    local function RefreshSealSelection()
        sealButton:SetEnabled(seals[selectedSeals[1]] ~= nil and seals[selectedSeals[2]] ~= nil)
    end

    menu:SetupMenu(function(_, root)
        AddSpellOptions(root, spells, function() return selected end, function(name)
            selected = name
            RefreshSelection()
        end)
    end)
    for index, dropdown in ipairs(sealMenus) do
        local slot = index
        dropdown:SetupMenu(function(_, root)
            AddSpellOptions(root, seals, function() return selectedSeals[slot] end, function(id)
                selectedSeals[slot] = id
                ns.db.macroSeals = { selectedSeals[1], selectedSeals[2] }
                RefreshSealSelection()
            end)
        end)
    end

    local function Refresh()
        spells, seals = PaladinSpells(), PaladinSeals()
        RefreshSelection()
        menu:GenerateMenu()
        local hasSeals = next(seals) ~= nil
        for index, dropdown in ipairs(sealMenus) do
            if not seals[selectedSeals[index]] then selectedSeals[index] = defaultSeals[index] end
            dropdown:SetDefaultText(hasSeals and sealPrompts[index] or "Нет данных о печатях")
            dropdown:SetEnabled(hasSeals)
            dropdown:GenerateMenu()
        end
        RefreshSealSelection()
    end
    page:HookScript("OnShow", Refresh)
    ns.On("SPELLS_CHANGED", function() if page:IsVisible() then Refresh() end end)

    button:SetScript("OnClick", function()
        local spell = PaladinSpells()[selected]
        if not spell then Refresh() return end
        local macro = spell.macro
        local name = "1.0_" .. macro.suffix
        -- An unqualified spell name uses the highest learned rank on both locales.
        local stopCasting = macro.stopCasting and "/stopcasting\n" or ""
        local body = ("#showtooltip %s\n%s/cast %s %s"):format(spell.name, stopCasting, macro.target, spell.name)
        SavePaladinMacro(name, spell.iconID or 134400, body, spell)
    end)
    sealButton:SetScript("OnClick", function()
        local first, second = seals[selectedSeals[1]], seals[selectedSeals[2]]
        if not (first and second) then Refresh() return end
        local body = ("#showtooltip\n/castsequence %s, %s"):format(first.name, second.name)
        SavePaladinMacro("1.0_SEALS", 134400, body)
    end)
end

function ns.CreateLootPanel(name, title, width, height)
    local window = CreateFrame("Frame", name, UIParent, "DefaultPanelFlatTemplate")
    window:SetSize(width, height)
    window:SetClampedToScreen(true)
    window:SetFrameStrata("DIALOG")
    window:SetToplevel(true)
    window:EnableMouse(true)
    window.TitleContainer.TitleText:SetText(title)
    local background = window.Bg:CreateTexture(nil, "ARTWORK")
    background:SetAllPoints(window.Bg)
    background:SetColorTexture(0.105, 0.08, 0.06, 1)
    local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 1, 0)
    close:SetScript("OnClick", function() window:Hide() end)
    window:Hide()
    return window, close
end

local function CreateBookWindow(name, width, height)
    local window = CreateFrame("Frame", name, UIParent, "PortraitFrameTemplate")
    window:SetSize(width, height)
    window:SetPoint("CENTER")
    window:SetClampedToScreen(true)
    window:SetFrameStrata("DIALOG")
    window:SetToplevel(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:Hide()
    tinsert(UISpecialFrames, window:GetName())

    window:SetTitle("RainonUI")
    window:SetPortraitToAsset(portrait)
    -- Align the logo with the portrait rim without moving the template's circular mask.
    window:SetPortraitTexCoord(0.04, 1.04, 0.025, 1.025)

    -- Match the compact Forever book: the right-hand page includes the top seam.
    local parchment = window:CreateTexture(nil, "BACKGROUND", nil, 1)
    parchment:SetAtlas("spellbook-Page-Right-C60")
    parchment:SetPoint("TOPLEFT", 2, -16)
    parchment:SetPoint("BOTTOMRIGHT", -2, 4)

    return window
end

function ns.BuildUpdateNotice(sections)
    local window = CreateBookWindow("RainonUIForeverUpdateNotice", 480, 300)
    local heading = BookText(window, "SystemFont_Huge2", "Новые функции")
    heading:SetPoint("TOPLEFT", 50, -42)
    local divider = window:CreateTexture(nil, "ARTWORK")
    divider:SetAtlas("spellbook-divider")
    divider:SetHeight(11)
    divider:SetPoint("TOPLEFT", 25, -79)
    divider:SetPoint("TOPRIGHT", -25, -79)

    local warning = BookText(window, "SystemFont_Med1",
        "Чтобы это сообщение не появлялось, отключи его в настройках аддона во вкладке «Общие».")
    warning:SetTextColor(0.68, 0.06, 0.06)
    warning:SetPoint("TOPLEFT", 34, -101)
    warning:SetWidth(412)
    warning:SetWordWrap(true)

    local y = -117 - warning:GetStringHeight()
    for _, section in ipairs(sections) do
        local title = BookText(window, "SystemFont_Large", section.title)
        title:SetPoint("TOPLEFT", 34, y)
        y = y - title:GetStringHeight() - 4
        local line = BookText(window, "SystemFont_Med1", section.text)
        line:SetPoint("TOPLEFT", 34, y)
        line:SetWidth(412)
        line:SetWordWrap(true)
        y = y - line:GetStringHeight() - 14
    end
    local close = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    close:SetSize(102, 25)
    close:SetPoint("BOTTOMRIGHT", -24, 16)
    close:SetText("Закрыть")
    close:SetScript("OnClick", function() window:Hide() end)
    window:SetHeight(-y + 45)
    return window
end

function ns.BuildOptions(settings, extraOptions)
    local window = CreateBookWindow("RainonUIForeverOptions", 578, 720)
    local tabButtons, pagesByKey = {}, {}
    local windowTabs = {}
    for _, entry in ipairs(tabs) do
        windowTabs[#windowTabs + 1] = entry
        if entry.key == "general" then
            for _, extra in ipairs(ns.tabsAfterGeneral or {}) do
                windowTabs[#windowTabs + 1] = extra
                entryStyles[extra.key] = { icon = extra.icon, tooltip = extra.tooltip }
            end
        end
    end
    if ns.ItemNotesTab then windowTabs[#windowTabs + 1] = ns.ItemNotesTab end
    local selectedKey = "general"
    function window:SelectTab(key)
        if not (tabButtons[key] and tabButtons[key]:IsShown()) then key = "general" end
        selectedKey = key
        for _, entry in ipairs(windowTabs) do
            local selected = entry.key == key
            pagesByKey[entry.key]:SetShown(selected)
            tabButtons[entry.key].Selected:SetShown(selected)
        end
    end
    local function RefreshTabs()
        local slot = 0
        for _, entry in ipairs(windowTabs) do
            local tab = tabButtons[entry.key]
            local visible = (not entry.toggle or ns.Enabled(entry.key))
                and (not entry.feature or ns.Enabled(entry.feature))
            if visible then
                tab:ClearAllPoints()
                tab:SetPoint("TOPLEFT", 73 + slot * 47, -37)
                slot = slot + 1
            end
            tab:SetShown(visible)
        end
        window:SelectTab(selectedKey)
    end

    for _, entry in ipairs(windowTabs) do
        local page = CreateFrame("Frame", nil, window)
        page:SetPoint("TOPLEFT", 68, -110)
        page:SetPoint("BOTTOMRIGHT", -42, 42)
        local heading = BookText(page, "SystemFont_Huge2", entry.title)
        heading:SetPoint("TOPLEFT")
        if entry.subtitle then
            local label = BookText(page, "GameFontHighlightSmall", entry.subtitle)
            label:SetPoint("TOPLEFT", 0, -29)
        end
        local divider = page:CreateTexture(nil, "ARTWORK")
        divider:SetAtlas("spellbook-divider")
        divider:SetHeight(11)
        divider:SetPoint("TOPLEFT", -22, -42)
        divider:SetPoint("TOPRIGHT", -10, -42)
        page.optionColumns = entry.columns or 2
        pagesByKey[entry.key] = page
        tabButtons[entry.key] = MakeTab(window, entry)
        if entry.build then entry.build(page, BookText, heading) end
    end

    BuildMacrosPage(pagesByKey.macros)

    ns.BuildRestPage(pagesByKey.characters, BookText, firstRow)

    local checks = {}
    local equipment = pagesByKey.equipment
    local dropdown, numberLabel = NumberOptions(equipment)
    local qualityMenus = {}
    local warning = "|cffff6962Выбери качество|r"
    local function AddQualityMenu(option, y)
        local feature = option.key
        local field = feature .. "Qualities"
        local menuButton = CreateFrame("DropdownButton", nil, equipment, "WowStyle1DropdownTemplate")
        menuButton:SetPoint("TOPLEFT", columnStep + 8, y - 12)
        menuButton:SetSize(206, 26)
        if feature ~= "autoGreed" then menuButton:EnableRegenerateOnResponse() end

        local function NeedsSelection()
            return ns.Enabled(feature) and not ns.HasLootQualitySelected(feature)
        end
        local captions = {}
        for quality = 2, 3 do
            local color = ITEM_QUALITY_COLORS[quality]
            captions[quality] = ("|cff%02x%02x%02x%s|r"):format(math.floor(color.r * 255 + 0.5),
                math.floor(color.g * 255 + 0.5), math.floor(color.b * 255 + 0.5), ns.LootQualityNames[quality])
        end
        local function RefreshQuality()
            local selected = {}
            for quality = 2, 3 do
                if ns.IsLootQualitySelected(feature, quality) then selected[#selected + 1] = captions[quality] end
            end
            local caption = #selected > 0 and table.concat(selected, ", ") or "Качество добычи"
            menuButton:OverrideText(NeedsSelection() and warning or caption)
            menuButton:SetEnabled(ns.Enabled(feature))
        end

        menuButton:SetupMenu(function(_, menu)
            local showWarning = NeedsSelection()
            if showWarning then menu:CreateTitle(warning) end
            for quality = 2, 3 do
                local value = quality
                menu:CreateCheckbox(captions[value], function()
                    return ns.IsLootQualitySelected(feature, value)
                end, function()
                    if type(ns.db[field]) ~= "table" then ns.db[field] = {} end
                    ns.db[field][value] = not ns.IsLootQualitySelected(feature, value)
                    if option.changed then option.changed() end
                    RefreshQuality()
                    -- Only a change to the warning needs a new menu. Keep open submenus for checkbox updates.
                    if feature == "autoGreed" and showWarning ~= NeedsSelection() then
                        menuButton:GenerateMenu()
                    end
                end)
            end
            if feature == "autoGreed" then
                menu:CreateDivider()
                local ignored = menu:CreateButton("Игнорировать автовыбор для:")
                for _, entry in ipairs(ns.AutoGreedIgnoreOptions) do
                    local key, title, icon = unpack(entry)
                    if type(key) == "number" then title = C_Item.GetItemNameByID(key) or title end
                    local option = ignored:CreateCheckbox(("|T%s:20:20|t  %s"):format(icon, title), function()
                        return ns.IsAutoGreedIgnored(key)
                    end, function()
                        ns.ToggleAutoGreedIgnored(key)
                    end)
                    option:AddInitializer(function(row)
                        row.fontString:SetFontObject(GameFontHighlight)
                        return row.fontString:GetUnboundedStringWidth() + 32, 24
                    end)
                end
            end
        end)
        qualityMenus[#qualityMenus + 1] = RefreshQuality
        RefreshQuality()
    end
    local function Refresh()
        for key, check in pairs(checks) do
            local enabled = ns.Enabled(key)
            check:SetChecked(enabled)
            check.Mark:SetShown(enabled)
        end
        local shorten, colors = ns.Enabled("stats"), ns.Enabled("statsColors")
        checks.statsMerge:SetEnabled(shorten)
        checks.statsMerge:SetAlpha(shorten and 1 or 0.45)
        dropdown:SetEnabled(colors)
        numberLabel:SetAlpha(colors and 1 or 0.45)
        for _, refreshQuality in ipairs(qualityMenus) do refreshQuality() end
        RefreshTabs()
    end

    local counts = {}
    for _, option in ipairs(settings) do
        local key = option.tab or "general"
        local index = counts[key] or 0
        local hasQualityMenu = option.key == "groupNeed" or option.key == "autoGreed"
        if hasQualityMenu and index % 2 == 1 then
            index = index + 1
        end
        local columns = pagesByKey[key].optionColumns
        local x = (index % columns) * columnStep
        local y = firstRow - math.floor(index / columns) * rowStep
        local width = columns == 1 and 400 or columnWidth
        checks[option.key] = MakeCheck(pagesByKey[key], option, x, y, width, Refresh)
        if hasQualityMenu then AddQualityMenu(option, y) end
        counts[key] = index + (hasQualityMenu and 2 or 1)
    end

    local general = pagesByKey.general
    local generalY = firstRow - math.ceil((counts.general or 0) / 2) * rowStep
    for _, build in ipairs(extraOptions) do generalY = generalY - build(general, generalY, ink) end

    window:HookScript("OnShow", Refresh)
    RefreshTabs()
    return window
end
