local _, ns = ...

local portrait = "Interface\\AddOns\\RainonUI_Forever\\Media\\logo"
local tabs = {
    { key = "general", title = "Общие", icon = "Interface\\Icons\\INV_Misc_Gear_01" },
    { key = "characters", title = "Персонажи", icon = "Interface\\Icons\\Achievement_Character_Human_Male" },
    { key = "equipment", title = "Экипировка", icon = "Interface\\Icons\\INV_Chest_Chain_05" },
    { key = "professions", title = "Профессии", icon = 136249 },
    { key = "macros", title = "Макросы", icon = "Interface\\Icons\\ClassIcon_Paladin" },
}

local entryStyles = {
    minimap = { icon = "Interface\\Icons\\INV_Misc_Map_01" },
    reload = { title = "Кнопка перезагрузки", icon = "Interface\\Icons\\INV_Misc_PocketWatch_01" },
    rest = { icon = "Interface\\Icons\\Spell_Nature_Sleep" },
    stats = { title = "Сокращать строки", detail = "Бонусы экипировки", icon = "Interface\\Icons\\INV_Misc_Note_01" },
    statsMerge = { title = "Объединять бонусы", detail = "Равные урон и исцеление", icon = "Interface\\Icons\\Spell_Holy_HolyBolt" },
    statsColors = { title = "Окрашивать характеристики", icon = "Interface\\Icons\\INV_Inscription_InkOrange01" },
    crates = { detail = "Самый дешёвый набор по ценам Auctionator", icon = "Interface\\Icons\\INV_Crate_03" },
    auctionJunk = { title = "Мусор в Baganator", detail = "По разнице цен", icon = "Interface\\Icons\\INV_Misc_Coin_01" },
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
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title)
        if detail then GameTooltip:AddLine(detail, 1, 1, 1, true) end
        GameTooltip:Show()
    end)
    button:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

local function MakeEntry(button, title, detail, texture)
    button:SetHeight(54)

    -- Geometry of the square spellbook item in Blizzard_SpellBookItem.xml and ArtSet.Square.
    local slot = CreateFrame("Frame", nil, button)
    slot:SetSize(40, 40)
    slot:SetPoint("LEFT", 7, 1)

    local icon = button:CreateTexture(nil, "ARTWORK", nil, -1)
    icon:SetSize(36, 36)
    icon:SetPoint("CENTER", slot)
    icon:SetTexture(texture)
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
    end
end

local function MakeCheck(page, option, x, y, width, refresh)
    local style = entryStyles[option.key] or {}
    local check = CreateFrame("CheckButton", nil, page)
    check:SetWidth(width)
    check:SetPoint("TOPLEFT", x, y)
    MakeEntry(check, style.title or option.label, style.detail, style.icon or 134400)

    local box = check:CreateTexture(nil, "ARTWORK")
    box:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
    box:SetSize(23, 23)
    box:SetPoint("RIGHT", -1, 0)
    local mark = check:CreateTexture(nil, "OVERLAY", nil, 1)
    mark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    mark:SetAllPoints(box)
    check.Mark = mark
    SetTooltip(check, option.label, option.key == "statsMerge" and "Доступно при сокращении строк экипировки." or nil)
    check:SetScript("OnClick", function(self)
        ns.db.features[option.key] = not not self:GetChecked()
        if option.changed then option.changed() end
        refresh()
    end)
    return check
end

local function MakeTab(window, entry, index)
    local tab = CreateFrame("Button", nil, window)
    tab:SetSize(44, 35)
    tab:SetPoint("TOPLEFT", 73 + (index - 1) * 47, -37)
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

local function BuildMacrosPage(page)
    local name = "1.0_RainonUIF"
    local icon = 132347 -- Seal of Command
    local body = "/castsequence Seal of Command(Rank 4), Seal of Righteousness(Rank 3)"

    local button = CreateFrame("Button", nil, page)
    button:SetPoint("TOPLEFT", 0, firstRow)
    button:SetWidth(350)
    MakeEntry(button, "Чередование печатей", "Создать общий макрос (английский клиент)", icon)
    SetTooltip(button, "Чередование печатей", "После создания открой /macro и перетащи макрос на панель команд.")
    button:SetScript("OnClick", function()
        local prefix = "RainonUI — Forever: "
        if InCombatLockdown() then
            DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Выйди из боя, чтобы создать или обновить макрос.")
            return
        end

        local accountCount = GetNumMacros()
        local index
        for i = 1, accountCount do
            if GetMacroInfo(i) == name then
                index = i
                break
            end
        end
        if not index and accountCount >= Constants.MacroConsts.MAX_ACCOUNT_MACROS then
            DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Освободи место в общих макросах (/macro).")
            return
        end

        local ok, savedIndex
        if index then
            ok, savedIndex = pcall(EditMacro, index, name, icon, body)
        else
            ok, savedIndex = pcall(CreateMacro, name, icon, body, false)
        end
        if ok and savedIndex and savedIndex > 0 then
            local action = index and "обновлён" or "создан"
            DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Макрос " .. name .. " " .. action .. " в общих макросах (/macro).")
        else
            DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Не удалось сохранить макрос.")
        end
    end)
end

function ns.BuildOptions(settings, extraOptions)
    local window = CreateFrame("Frame", "RainonUIForeverOptions", UIParent, "PortraitFrameTemplate")
    window:SetSize(578, 590)
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

    window:SetTitle("RainonUI — Настройки")
    window:SetPortraitToAsset(portrait)

    -- Match the compact Forever book: the right-hand page includes the top seam.
    local parchment = window:CreateTexture(nil, "BACKGROUND", nil, 1)
    parchment:SetAtlas("spellbook-Page-Right-C60")
    parchment:SetPoint("TOPLEFT", 2, -16)
    parchment:SetPoint("BOTTOMRIGHT", -2, 4)

    local tabButtons, pages, pagesByKey = {}, {}, {}
    function window:SelectTab(key)
        for i, entry in ipairs(tabs) do
            local selected = entry.key == key
            pages[i]:SetShown(selected)
            tabButtons[i].Selected:SetShown(selected)
        end
    end

    for i, entry in ipairs(tabs) do
        local page = CreateFrame("Frame", nil, window)
        page:SetPoint("TOPLEFT", 68, -110)
        page:SetPoint("BOTTOMRIGHT", -42, 42)
        local heading = BookText(page, "SystemFont_Huge2", entry.title)
        heading:SetPoint("TOPLEFT")
        local divider = page:CreateTexture(nil, "ARTWORK")
        divider:SetAtlas("spellbook-divider")
        divider:SetHeight(11)
        divider:SetPoint("TOPLEFT", -22, -42)
        divider:SetPoint("TOPRIGHT", -10, -42)
        pages[i], pagesByKey[entry.key] = page, page
        tabButtons[i] = MakeTab(window, entry, i)
    end

    BuildMacrosPage(pagesByKey.macros)

    ns.BuildRestPage(pagesByKey.characters, BookText, firstRow)

    local checks = {}
    local dropdown, numberLabel = NumberOptions(pagesByKey.equipment)
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
    end

    local counts, junkOption = {}
    for _, option in ipairs(settings) do
        if option.key == "auctionJunk" then
            junkOption = option
        else
            local key = option.tab or "general"
            local index = counts[key] or 0
            local columns = key == "professions" and 1 or 2
            local x = (index % columns) * columnStep
            local y = firstRow - math.floor(index / columns) * rowStep
            local width = columns == 1 and 400 or columnWidth
            checks[option.key] = MakeCheck(pagesByKey[key], option, x, y, width, Refresh)
            counts[key] = index + 1
        end
    end

    local general = pagesByKey.general
    local generalY = firstRow - math.ceil((counts.general or 0) / 2) * rowStep
    if junkOption then
        local divider = general:CreateTexture(nil, "ARTWORK")
        divider:SetColorTexture(ink[1], ink[2], ink[3], 0.32)
        divider:SetHeight(1)
        divider:SetPoint("TOPLEFT", 0, generalY - 3)
        divider:SetPoint("TOPRIGHT", -4, generalY - 3)
        local junkY = generalY - 18
        checks.auctionJunk = MakeCheck(general, junkOption, 0, junkY, 400, Refresh)
        generalY = junkY - 53
    end
    for _, build in ipairs(extraOptions) do generalY = generalY - build(general, generalY, ink) end

    window:HookScript("OnShow", Refresh)
    window:SelectTab("general")
    return window
end
