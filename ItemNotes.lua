local _, ns = ...
local categories = { { "junk", "Мусор" }, { "profession", "Профессия" }, { "quest", "Задания" }, { "other", "Прочее" } }
local valid = { junk = true, profession = true, quest = true, other = true }
local provider, providerName = "rainonui-notes", "RainonUI: личные подсказки"
local editor, refresh, selected

local function Personal()
    ns.db.itemNotes = ns.db.itemNotes or {}
    return ns.db.itemNotes
end

local function Author(id)
    return ns.db.useRainonNotes and ns.RainonItemNotes and ns.RainonItemNotes[id]
end

local function Plain(text)
    return (tostring(text or ""):gsub("|", "||"))
end

local function RefreshBags()
    local api = Baganator and Baganator.API
    if api and api.RequestItemButtonsRefresh then api.RequestItemButtonsRefresh() end
end

local function IsJunk(_, _, id)
    if not ns.Enabled("itemNotes") or not id then return false end
    local own, shared = Personal()[id], Author(id)
    return (own and own.category == "junk") or (shared and shared.category == "junk") or false
end

local function Save(id, text, category)
    id = tonumber(id)
    text = type(text) == "string" and text:match("^%s*(.-)%s*$") or ""
    if not id or id <= 0 or id ~= math.floor(id) or not valid[category] then return false end
    Personal()[id] = { text = text, category = category }
    RefreshBags()
    return true
end

local visible = { GameTooltip = true, ItemRefTooltip = true, ShoppingTooltip1 = true, ShoppingTooltip2 = true,
    ItemRefShoppingTooltip1 = true, ItemRefShoppingTooltip2 = true }
local marked = setmetatable({}, { __mode = "k" })
local function AddNotes(tip, item)
    if not ns.Enabled("itemNotes") or not tip or not visible[tip:GetName()] or tip:IsForbidden() then return end
    local id = item and ns.Number(item.id)
    if not id then
        local _, link = tip:GetItem()
        id = link and tonumber(link:match("item:(%d+)"))
    end
    if not id then return end
    local own, shared = Personal()[id], Author(id)
    if own and (not own.text or own.text == "") then own = nil end
    if shared and (not shared.text or shared.text == "") then shared = nil end
    if not own and not shared then return end
    local signature = id .. ":" .. (own and own.text or "") .. ":" .. (shared and shared.text or "")
    if marked[tip] == signature then return end
    marked[tip] = signature
    tip:AddLine(" ")
    tip:AddLine(providerName, 1, 0.82, 0)
    if own then
        if shared then tip:AddLine("Личная заметка", 0.65, 0.8, 1) end
        tip:AddLine(Plain(own.text), 1, 1, 1, true)
    end
    if shared then
        tip:AddLine("Заметка от Rainon", 0.65, 0.8, 1)
        tip:AddLine(Plain(shared.text), 1, 1, 1, true)
    end
    tip:Show()
end

local function ReadItemName(id)
    local name = C_Item.GetItemNameByID(id)
    if name and name ~= "" then return name end
    local getItemInfo = C_Item.GetItemInfo or GetItemInfo
    if getItemInfo then
        name = getItemInfo(id)
        if name and name ~= "" then return name end
    end
end

local function ItemName(id)
    local name = ReadItemName(id)
    if not name then C_Item.RequestLoadItemDataByID(id) end
    return name or ("Предмет " .. id)
end

local function ItemCaption(id, size)
    return ("|T%s:%d:%d|t %s"):format(C_Item.GetItemIconByID(id) or 134400, size or 24, size or 24, ItemName(id))
end

local function Build(page, bookText)
    local width, buttonHeight = 447, 24
    local function Text(parent, text, x, y, w, font)
        local f = bookText(parent, font or "GameFontHighlightSmall", text)
        f:SetPoint("TOPLEFT", x, y)
        if w then f:SetWidth(w) end
        return f
    end
    local function Button(parent, title, w, action)
        local f = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        f:SetSize(w, buttonHeight)
        f:SetText(title)
        f:SetScript("OnClick", action)
        return f
    end
    local function Help(frame, title)
        frame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
            GameTooltip:SetText(title)
            GameTooltip:Show()
        end)
        frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    local share = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    share:SetSize(22, 22)
    share:SetPoint("TOPLEFT", 0, -55)
    Text(page, "Использовать заметки от Rainon", 25, -61)
    share:SetChecked(ns.db.useRainonNotes == true)
    share:SetScript("OnClick", function(self)
        ns.db.useRainonNotes = not not self:GetChecked()
        RefreshBags()
    end)
    Text(page, "Выбери предмет через Shift + ЛКМ или кнопку «По ID».", 0, -87)
    local paddingLabel = bookText(page, "GameFontHighlightSmall", "Пр")
    local itemPadding = math.ceil(paddingLabel:GetUnboundedStringWidth())
    paddingLabel:Hide()
    local itemField = CreateFrame("Frame", nil, page, "BackdropTemplate")
    itemField:SetPoint("TOPLEFT", 0, -107)
    itemField:SetSize(width, 48)
    itemField:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    itemField:SetBackdropColor(0.12, 0.07, 0.025, 0.18)
    local chosenIcon = itemField:CreateTexture(nil, "ARTWORK")
    chosenIcon:SetSize(36, 36)
    chosenIcon:SetPoint("LEFT", itemPadding, 0)
    local chosen = bookText(itemField, "GameFontHighlightSmall", "Предмет не выбран")
    chosen:SetPoint("LEFT", itemField, "LEFT", itemPadding, 0)
    local font, fontSize, flags = chosen:GetFont()
    chosen:SetFont(font, fontSize * 2, flags)
    chosen:SetHeight(36)
    chosen:SetWordWrap(false)
    itemField:SetMouseMotionEnabled(true)
    itemField:SetScript("OnEnter", function(self)
        if not selected then return end
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetItemByID(selected)
        GameTooltip:Show()
    end)
    itemField:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local idRow = CreateFrame("Frame", nil, page)
    idRow:SetPoint("TOPLEFT", itemField, "BOTTOMLEFT", 0, -6)
    idRow:SetSize(width, buttonHeight)
    idRow:Hide()
    local idLabel = bookText(idRow, "GameFontHighlightSmall", "ID предмета")
    idLabel:SetPoint("LEFT")
    local idBox = CreateFrame("EditBox", nil, idRow, "InputBoxTemplate")
    idBox:SetPoint("LEFT", idLabel, "RIGHT", 12, 0)
    idBox:SetSize(110, buttonHeight)
    idBox:SetMaxLetters(24)
    idBox:SetAutoFocus(false)
    local idError = bookText(idRow, "GameFontHighlightSmall", "")
    idError:SetTextColor(0.68, 0.06, 0.06)

    local panel = CreateFrame("Frame", nil, page)
    panel:SetSize(width, 180)
    Text(panel, "Заметка (необязательно)", 0, 0)
    local input = CreateFrame("Frame", nil, panel, "ScrollingEditBoxTemplate")
    input:SetPoint("TOPLEFT", 8, -27)
    input:SetWidth(width - 32)
    local box = input:GetEditBox()
    box:SetFontObject("GameFontHighlight")
    box:SetMultiLine(true)
    box:SetMaxLetters(600)
    box:SetAutoFocus(false)
    local _, lineHeight = box:GetFont()
    box:SetSpacing(2)
    local inputHeight = math.ceil(lineHeight * 6 + 2 * 5)
    input:SetHeight(inputHeight)
    local border = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    border:SetPoint("TOPLEFT", 0, -20)
    border:SetSize(width, inputHeight + 14)
    border:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    border:SetBackdropColor(0.04, 0.03, 0.02, 0.8)
    input:SetFrameLevel(border:GetFrameLevel() + 1)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local controlsY = -inputHeight - 40
    local category = "other"
    local chooseCategory = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
    chooseCategory:SetPoint("TOPLEFT", 0, controlsY)
    chooseCategory:SetSize(width - 150, buttonHeight)
    chooseCategory:SetupMenu(function(_, menu)
        for _, entry in ipairs(categories) do
            local key, name = entry[1], entry[2]
            menu:CreateRadio(name, function() return category == key end, function() category = key end)
        end
    end)
    local panelHeight = inputHeight + 90
    panel:SetHeight(panelHeight)
    local heading = Text(page, "Мои заметки", 0, -175, width, "SystemFont_Large")
    local hint = Text(page, "Если ты пользуешься Baganator, зайди в настройки и выбери в пункте определения мусора «RainonUI: личные подсказки».", 0, -199, width)
    hint:SetWordWrap(true)
    local scroll = CreateFrame("ScrollFrame", nil, page, "ScrollFrameTemplate")
    scroll:SetPoint("BOTTOMRIGHT", -20, 0)
    local function LayoutEditor(show)
        local idOffset = idRow:IsShown() and buttonHeight + 12 or 0
        panel:SetPoint("TOPLEFT", 0, -165 - idOffset)
        panel:SetShown(show)
        local top = -175 - idOffset - (show and panelHeight or 0)
        heading:ClearAllPoints()
        heading:SetPoint("TOPLEFT", 0, top)
        hint:ClearAllPoints()
        hint:SetPoint("TOPLEFT", 0, top - 25)
        scroll:SetPoint("TOPLEFT", 0, top - 61)
    end
    local function HideIDEntry()
        idBox:ClearFocus()
        idRow:Hide()
    end
    local function ClearSelection()
        selected = nil
        HideIDEntry()
        box:ClearFocus()
        box:SetText("")
        chosenIcon:Hide()
        chosen:SetPoint("LEFT", itemField, "LEFT", itemPadding, 0)
        chosen:SetText("Предмет не выбран")
        category = "other"
        chooseCategory:GenerateMenu()
        LayoutEditor(false)
    end
    local actionWidth = 85
    local clear = Button(itemField, "Очистить", actionWidth, ClearSelection)
    clear:SetPoint("RIGHT", -itemPadding, 0)
    Help(clear, "Очистить выбранный предмет. Сохранённая запись останется в списке.")
    local byID = Button(itemField, "По ID", actionWidth, function()
        if idRow:IsShown() then
            HideIDEntry()
        else
            idBox:SetText("")
            idError:SetText("")
            idRow:Show()
            idBox:SetFocus()
        end
        LayoutEditor(selected ~= nil)
    end)
    byID:SetPoint("RIGHT", clear, "LEFT", -6, 0)
    chosen:SetPoint("RIGHT", byID, "LEFT", -8, 0)

    local function UpdateChosenItem(id)
        chosenIcon:SetTexture(C_Item.GetItemIconByID(id) or 134400)
        chosen:SetText(ItemName(id))
    end
    local function Select(id)
        HideIDEntry()
        selected = id
        local note = Personal()[id]
        category = note and note.category or "other"
        UpdateChosenItem(id)
        chosenIcon:Show()
        chosen:SetPoint("LEFT", chosenIcon, "RIGHT", 8, 0)
        box:SetText(note and note.text or "")
        box:SetCursorPosition(0)
        chooseCategory:GenerateMenu()
        LayoutEditor(true)
    end
    local function SelectByID()
        local id = tonumber(idBox:GetText():match("^%s*(%d+)%s*$"))
        if not id or id < 1 or id > 2147483647 then
            idError:SetText("Введи ID предмета.")
            return
        end
        if not C_Item.DoesItemExistByID(id) then
            idError:SetText("Предмет не найден.")
            return
        end
        if id == selected then
            HideIDEntry()
            LayoutEditor(true)
        else
            Select(id)
        end
        box:SetFocus()
    end
    local confirmID = Button(idRow, "Выбрать", actionWidth, SelectByID)
    confirmID:SetPoint("LEFT", idBox, "RIGHT", 8, 0)
    idError:SetPoint("LEFT", confirmID, "RIGHT", 8, 0)
    idBox:SetScript("OnEnterPressed", SelectByID)
    idBox:SetScript("OnEscapePressed", function()
        HideIDEntry()
        LayoutEditor(selected ~= nil)
    end)
    idBox:SetScript("OnTextChanged", function() idError:SetText("") end)
    editor = function(link)
        if not page:IsVisible() or not IsShiftKeyDown() then return end
        local id = type(link) == "string" and tonumber(link:match("item:(%d+)"))
        if id then Select(id) end
    end
    local save = Button(panel, "Сохранить", 116, function()
        if not Save(selected, box:GetText(), category) then return end
        ClearSelection()
        refresh()
    end)
    save:SetPoint("LEFT", chooseCategory, "RIGHT", 5, 0)
    local function Delete(id)
        if not id then return end
        Personal()[id] = nil
        if selected == id then ClearSelection() end
        RefreshBags()
        refresh()
    end
    local function DeleteButton(parent, anchor, getID)
        local f = CreateFrame("Button", nil, parent, "UIPanelCloseButton")
        f:SetSize(buttonHeight, buttonHeight)
        f:SetPoint("LEFT", anchor, "RIGHT", 3, 0)
        f:SetScript("OnClick", function() Delete(getID()) end)
        Help(f, "Удалить из личного списка")
        return f
    end
    DeleteButton(panel, save, function() return selected end)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(427, 1)
    scroll:SetScrollChild(content)
    scroll:HookScript("OnSizeChanged", function(_, w) content:SetWidth(w) end)
    scroll:HookScript("OnScrollRangeChanged", function(_, _, range)
        scroll.ScrollBar:SetShown(range > 0)
        if scroll:GetVerticalScroll() > range then scroll:SetVerticalScroll(range) end
    end)
    local measure = bookText(page, "GameFontNormal", "Профессия  ")
    local categoryWidth = math.ceil(measure:GetUnboundedStringWidth()) + 28
    measure:Hide()
    local rows, rowHeight = {}, 34
    refresh = function(loadedID)
        if type(loadedID) == "number" then
            if loadedID == selected then UpdateChosenItem(selected) end
            for _, row in ipairs(rows) do
                if row.id == loadedID and row:IsShown() then
                    row.name:SetText(ItemCaption(loadedID, buttonHeight))
                    break
                end
            end
            return
        end
        local ids = {}
        for id in pairs(Personal()) do ids[#ids + 1] = id end
        table.sort(ids)
        for index, id in ipairs(ids) do
            local row = rows[index]
            if not row then
                row = CreateFrame("Button", nil, content)
                rows[index] = row
                row.id = id
                row:SetHeight(rowHeight)
                row:SetPoint("TOPLEFT", 0, -(index - 1) * rowHeight)
                row:SetPoint("TOPRIGHT", 0, -(index - 1) * rowHeight)
                row.name = bookText(row, "GameFontHighlightSmall", "")
                row.name:SetFont(font, fontSize * buttonHeight / 18, flags)
                row.name:SetPoint("LEFT", 0, 0)
                row.name:SetWordWrap(false)
                row.drop = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
                row.drop:SetPoint("RIGHT", -27, 0)
                row.drop:SetSize(categoryWidth, buttonHeight)
                row.drop:SetupMenu(function(_, menu)
                    local itemID = row.id
                    for _, entry in ipairs(categories) do
                        local key, name = entry[1], entry[2]
                        menu:CreateRadio(name, function()
                            local note = Personal()[itemID]
                            return note ~= nil and note.category == key
                        end, function()
                            local note = Personal()[itemID]
                            if not note or row.id ~= itemID then return end
                            note.category = key
                            if selected == itemID then category = key chooseCategory:GenerateMenu() end
                            RefreshBags()
                        end)
                    end
                end)
                row.edit = Button(row, "Редактировать", 108, function() Select(row.id) box:SetFocus() end)
                row.edit:SetPoint("RIGHT", row.drop, "LEFT", -4, 0)
                row.name:SetPoint("RIGHT", row.edit, "LEFT", -5, 0)
                row.delete = DeleteButton(row, row.drop, function() return row.id end)
                row:SetScript("OnClick", function() Select(row.id) end)
                row:SetScript("OnEnter", function(self)
                    local note = Personal()[row.id]
                    if not note then return end
                    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
                    GameTooltip:SetText(ItemCaption(row.id))
                    for _, entry in ipairs(categories) do
                        if entry[1] == note.category then GameTooltip:AddLine(entry[2], 1, 1, 1) end
                    end
                    if note.text and note.text ~= "" then GameTooltip:AddLine(Plain(note.text), 1, 1, 1, true) end
                    GameTooltip:Show()
                end)
                row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            end
            row.id = id
            row.name:SetText(ItemCaption(id, buttonHeight))
            row.drop:GenerateMenu()
            row:Show()
        end
        for i = #ids + 1, #rows do rows[i]:Hide() end
        content:SetHeight(math.max(1, #ids * rowHeight))
    end
    page:HookScript("OnShow", refresh)
    page:HookScript("OnHide", function()
        HideIDEntry()
        LayoutEditor(selected ~= nil)
    end)
    ClearSelection()
    refresh()
end

local registered
local function Connect()
    local api = Baganator and Baganator.API
    if not registered and api and api.RegisterJunkPlugin then
        api.RegisterJunkPlugin(providerName, provider, IsJunk)
        registered = true
    end
end
ns.On("PLAYER_LOGIN", function()
    Connect()
    hooksecurefunc("HandleModifiedItemClick", function(link) if editor then editor(link) end end)
    for name in pairs(visible) do
        local tip = _G[name]
        if tip then tip:HookScript("OnTooltipCleared", function(self) marked[self] = nil end) end
    end
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, AddNotes)
    else
        for name in pairs(visible) do
            local tip = _G[name]
            if tip and tip:HasScript("OnTooltipSetItem") then tip:HookScript("OnTooltipSetItem", AddNotes) end
        end
    end
end)
ns.On("ADDON_LOADED", function(name) if name == "Baganator" then Connect() end end)
local function OnItemDataLoaded(id, success)
    if not success or not refresh then return end
    id = ns.Number(id)
    if not id or (id ~= selected and not Personal()[id]) then return end
    C_Timer.After(0, function()
        if ReadItemName(id) then refresh(id) end
    end)
end
ns.On("GET_ITEM_INFO_RECEIVED", OnItemDataLoaded)
ns.On("ITEM_DATA_LOAD_RESULT", OnItemDataLoaded)
ns.ItemNotesTab = { key = "itemNotes", title = "Предметы: личные подсказки", icon = 134331, build = Build, toggle = true }
ns.AddSetting("itemNotes", ns.ItemNotesTab.title, RefreshBags)
