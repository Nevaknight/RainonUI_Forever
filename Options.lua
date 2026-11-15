local _, ns = ...

local tabs = {
    { key = "general", title = "Общие", icon = "Interface\\AddOns\\RainonUI_Forever\\Media\\logo" },
    { key = "equipment", title = "Экипировка", icon = "Interface\\Icons\\INV_Chest_Chain_05" },
    { key = "professions", title = "Профессии", icon = 136249 },
}

local function MakeCheck(page, option, x, y, refresh)
    local check = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    check:SetSize(26, 26)
    check:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
    local label = check:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", check, "RIGHT", 4, 0)
    label:SetText(option.label)
    check:SetScript("OnClick", function(self)
        ns.db.features[option.key] = self:GetChecked() and true or false
        if option.changed then option.changed() end
        refresh()
    end)
    return check, label
end

local function MakeTab(window, entry, index, select)
    local tab = CreateFrame("Button", nil, window)
    tab:SetSize(36, 36)
    tab:SetPoint("TOPRIGHT", window, "TOPLEFT", 1, -56 - (index - 1) * 42)
    tab:SetFrameLevel(window:GetFrameLevel() + 2)

    local background = tab:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0, 0, 0, 0.85)

    local icon = tab:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", -2, 2)
    icon:SetTexture(entry.icon)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local border = tab:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    border:SetSize(60, 60)
    border:SetPoint("CENTER")

    local selected = tab:CreateTexture(nil, "OVERLAY", nil, 1)
    selected:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    selected:SetBlendMode("ADD")
    selected:SetAllPoints()
    tab.Selected = selected

    local hover = tab:CreateTexture(nil, "HIGHLIGHT")
    hover:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    hover:SetBlendMode("ADD")
    hover:SetAllPoints()

    tab:SetScript("OnClick", function()
        if SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB then PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB) end
        select(index)
    end)
    tab:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(entry.title)
        GameTooltip:Show()
    end)
    tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return tab
end

local numberColors = { { "signed", "По знаку" }, { "stat", "Цвет характеристики" }, { "line", "Цвет строки" } }

local function NumberOptions(page)
    local label = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", 304, -84)
    label:SetText("Цвет чисел")
    local dropdown = CreateFrame("DropdownButton", nil, page, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("LEFT", label, "RIGHT", 12, 0)
    dropdown:SetWidth(190)
    dropdown:SetupMenu(function(_, menu)
        for _, entry in ipairs(numberColors) do
            local key, title = entry[1], entry[2]
            menu:CreateRadio(title, function() return ns.StatNumberColor() == key end, function()
                ns.db.statsNumberColor = key
            end)
        end
    end)
    dropdown:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Цвет чисел")
        GameTooltip:AddLine("Плюс зелёный, минус красный, число без знака белое.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    dropdown:HookScript("OnLeave", function() GameTooltip:Hide() end)
    return dropdown, label
end

function ns.BuildOptions(settings, extraOptions)
    local window = CreateFrame("Frame", "RainonUIForeverOptions", UIParent, "BasicFrameTemplateWithInset")
    window:SetSize(620, 590)
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

    local title = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -5)
    title:SetText("RainonUI — Forever")

    local tabButtons, pages, pagesByKey = {}, {}, {}
    local function SelectTab(index)
        for i, page in ipairs(pages) do
            page:SetShown(i == index)
            tabButtons[i].Selected:SetShown(i == index)
        end
    end

    for i, entry in ipairs(tabs) do
        local page = CreateFrame("Frame", nil, window)
        page:SetPoint("TOPLEFT", 12, -27)
        page:SetPoint("BOTTOMRIGHT", -12, 12)
        local heading = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        heading:SetPoint("TOPLEFT", 6, -8)
        heading:SetText(entry.title)
        pages[i], pagesByKey[entry.key] = page, page
        tabButtons[i] = MakeTab(window, entry, i, SelectTab)
    end

    local subheading = pagesByKey.equipment:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    subheading:SetPoint("TOPLEFT", 6, -36)
    subheading:SetText("Упрощённые характеристики")

    local checks, checkLabels, restButton = {}, {}
    local dropdown, numberLabel = NumberOptions(pagesByKey.equipment)
    local function Refresh()
        for key, check in pairs(checks) do check:SetChecked(ns.Enabled(key)) end
        local shorten, colors = ns.Enabled("stats"), ns.Enabled("statsColors")
        checks.statsMerge:SetEnabled(shorten)
        checkLabels.statsMerge:SetAlpha(shorten and 1 or 0.45)
        dropdown:SetEnabled(colors)
        numberLabel:SetAlpha(colors and 1 or 0.45)
        if restButton then restButton:SetEnabled(ns.Enabled("rest")) end
    end

    local statPositions = { stats = { 4, -51 }, statsMerge = { 4, -78 }, statsColors = { 276, -51 } }
    local generalY = -43
    for _, option in ipairs(settings) do
        local key = option.tab or "general"
        local x, y = 4, -43
        if key == "equipment" then
            x, y = unpack(statPositions[option.key])
        elseif key == "general" then
            y = generalY
            generalY = generalY - 29
        end
        checks[option.key], checkLabels[option.key] = MakeCheck(pagesByKey[key], option, x, y, Refresh)
    end

    local general = pagesByKey.general
    for _, build in ipairs(extraOptions) do generalY = generalY - build(general, generalY) end
    if ns.ShowRest then
        restButton = CreateFrame("Button", nil, general, "UIPanelButtonTemplate")
        restButton:SetSize(138, 24)
        restButton:SetPoint("TOPLEFT", 6, generalY - 4)
        restButton:SetText("Показать отдых")
        restButton:SetScript("OnClick", function()
            if ns.Enabled("rest") then
                window:Hide()
                ns.ShowRest()
            end
        end)
    end

    window:HookScript("OnShow", Refresh)
    SelectTab(1)
    return window
end
