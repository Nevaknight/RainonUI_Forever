local _, ns = ...

local craftTimer, craftText, craftAnchor
local hookedProfessionsFrame
local currentCast, queuedCrafts, craftDuration

local function HideCraftTimer()
    currentCast, queuedCrafts = nil, nil
    if craftTimer then craftTimer:Hide() end
end

local function PositionCraftTimer()
    local profession = ProfessionsFrame
    if profession and profession ~= hookedProfessionsFrame then
        hookedProfessionsFrame = profession
        profession:HookScript("OnShow", function()
            craftAnchor = nil
            if craftTimer:IsShown() then PositionCraftTimer() end
        end)
    end

    local anchor = profession
    if not anchor or not anchor:IsVisible() then anchor = ERB_CastBarFrame end
    if not anchor or not anchor:IsVisible() then anchor = PlayerCastingBarFrame end
    if not anchor or not anchor:IsVisible() then anchor = UIParent end
    if anchor == craftAnchor then return end

    craftAnchor = anchor
    craftTimer:StopMovingOrSizing()
    craftTimer:ClearAllPoints()
    if anchor == profession then
        craftTimer:SetPoint("BOTTOMRIGHT", profession, "TOPRIGHT", -4, 6)
    elseif anchor == UIParent then
        craftTimer:SetPoint("CENTER", UIParent, "CENTER", 0, -140)
    else
        craftTimer:SetPoint("BOTTOM", anchor, "TOP", 0, 8)
    end
end

local function RefreshCraftTimer()
    local _, _, _, startMS, endMS, isCraft, castID = UnitCastingInfo("player")
    startMS, endMS = ns.Number(startMS), ns.Number(endMS)
    local now = GetTime()
    if not isCraft or not startMS or not endMS or endMS <= startMS or endMS <= now * 1000 then
        HideCraftTimer()
        return
    end

    if issecretvalue and issecretvalue(castID) then castID = nil end
    castID = castID or startMS
    if castID ~= currentCast then
        currentCast = castID
        -- The client counts only the repeats after the current cast.
        queuedCrafts = math.max(0, ns.Number(C_TradeSkillUI.GetRemainingRecasts()) or 0)
        craftDuration = (endMS - startMS) / 1000
    end
    local remaining = math.ceil(endMS / 1000 - now + queuedCrafts * craftDuration)
    craftText:SetFormattedText("До конца крафта %d:%02d", math.floor(remaining / 60), remaining % 60)
    PositionCraftTimer()
    craftTimer:Show()
end

local function ApplyCraftTimer()
    if not ns.Enabled("craftTimer") then
        if craftTimer then craftTimer:UnregisterAllEvents() end
        HideCraftTimer()
        return
    end
    if not C_TradeSkillUI or not C_TradeSkillUI.GetRemainingRecasts then return end

    if not craftTimer then
        craftTimer = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        craftTimer:SetSize(218, 32)
        craftTimer:SetFrameStrata("HIGH")
        craftTimer:SetClampedToScreen(true)
        craftTimer:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        craftTimer:SetBackdropColor(0.04, 0.03, 0.02, 0.94)
        craftTimer:SetMovable(true)
        craftTimer:EnableMouse(true)
        craftTimer:RegisterForDrag("LeftButton")
        craftTimer:SetScript("OnDragStart", craftTimer.StartMoving)
        craftTimer:SetScript("OnDragStop", craftTimer.StopMovingOrSizing)
        craftTimer:SetScript("OnHide", craftTimer.StopMovingOrSizing)
        craftText = craftTimer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        craftText:SetPoint("CENTER")
        craftText:SetFont(ns.CYRILLIC_FONT, 16, "OUTLINE")
        craftTimer:SetScript("OnEvent", RefreshCraftTimer)
        local elapsedSinceUpdate = 0
        craftTimer:SetScript("OnUpdate", function(_, elapsed)
            elapsedSinceUpdate = elapsedSinceUpdate + elapsed
            if elapsedSinceUpdate < 0.1 then return end
            elapsedSinceUpdate = 0
            RefreshCraftTimer()
        end)
    end
    craftTimer:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
    craftTimer:RegisterEvent("UPDATE_TRADESKILL_CAST_STOPPED")
    RefreshCraftTimer()
end

ns.AddSetting("craftTimer", "Таймер крафта", ApplyCraftTimer, true, "professions", {
    icon = 134377,
    detail = "Время до конца всей партии",
    tooltip = "Показывает время до готовности всей партии над окном профессии. Бокс можно перетащить.",
})
ns.On("PLAYER_LOGIN", ApplyCraftTimer)

local recipes = {
    { key = "mooncloth", spell = 18560, profession = 197, name = "Луноткань", icon = 132895,
        duration = 95 * 3600, frameName = "RainonUIForeverMooncloth", x = 0 },
    { key = "arcanite", spell = 17187, profession = 171, name = "Арканитовый слиток", icon = 134459,
        duration = 47 * 3600, frameName = "RainonUIForeverArcanite", x = 160 },
}
local refreshPage

function ns.CurrentProfessionCharacter()
    local guid = UnitGUID("player")
    if not guid then return end
    ns.db.characters = ns.db.characters or {}
    local character = ns.db.characters[guid] or {}
    ns.db.characters[guid] = character
    character.professions = character.professions or {}
    character.name, character.realm = ns.CharacterIdentity()
    return character
end

local function CooldownEntries(now)
    local entries = {}
    for _, character in pairs(ns.db.characters or {}) do
        if character.name and character.name ~= "" then
            for _, recipe in ipairs(recipes) do
                local snapshot = character[recipe.key]
                local readyAt = snapshot and ns.Number(snapshot.readyAt)
                if readyAt then
                    entries[#entries + 1] = { recipe = recipe, name = character.name, readyAt = readyAt }
                end
            end
        end
    end
    table.sort(entries, function(a, b)
        local timeA, timeB = math.max(a.readyAt, now), math.max(b.readyAt, now)
        if timeA ~= timeB then return timeA < timeB end
        if a.name ~= b.name then return a.name < b.name end
        return a.recipe.spell < b.recipe.spell
    end)
    return entries
end

local function RefreshCooldowns()
    local now = GetServerTime()
    local entries = CooldownEntries(now)
    for _, recipe in ipairs(recipes) do
        if recipe.frame then
            local names = {}
            if ns.Enabled(recipe.key) then
                for _, entry in ipairs(entries) do
                    if entry.recipe == recipe and entry.readyAt <= now then names[#names + 1] = entry.name end
                end
            end
            recipe.readyNames = names
            if names[1] then
                local suffix = #names > 1 and (" +%d"):format(#names - 1) or ""
                recipe.label:SetText(names[1] .. suffix .. "\n" .. recipe.name)
            end
            recipe.frame:SetShown(#names > 0)
        end
    end
    if refreshPage then refreshPage(entries, now) end
end

local function BuildCharacters(page, text, y)
    local heading = text(page, "SystemFont_Large", "Персонажи")
    heading:SetPoint("TOPLEFT", 0, y)
    local empty = text(page, "SystemFont_Med1", "Открой портняжное дело или алхимию на персонаже.")
    empty:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -12)

    local scroll = CreateFrame("ScrollFrame", nil, page, "ScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -10)
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

    local rows, rowHeight = {}, 24
    refreshPage = function(entries, now)
        if not page:IsVisible() then return end
        empty:SetShown(#entries == 0)
        scroll:SetShown(#entries > 0)
        content:SetWidth(math.max(1, scroll:GetWidth()))
        for i, entry in ipairs(entries) do
            local row = rows[i]
            if not row then
                row = CreateFrame("Frame", nil, content)
                rows[i] = row
                row:SetHeight(rowHeight)
                row:SetPoint("TOPLEFT", 0, -(i - 1) * rowHeight)
                row:SetPoint("TOPRIGHT", 0, -(i - 1) * rowHeight)
                row.name = text(row, "SystemFont_Med1", "")
                row.name:SetPoint("LEFT")
                row.name:SetWidth(155)
                row.item = text(row, "SystemFont_Med1", "")
                row.item:SetPoint("LEFT", row.name, "RIGHT", 4, 0)
                row.status = text(row, "SystemFont_Med1", "")
                row.status:SetPoint("RIGHT")
                row.item:SetPoint("RIGHT", row.status, "LEFT", -6, 0)
                row.name:SetWordWrap(false)
                row.item:SetWordWrap(false)
            end
            row.name:SetText(entry.name)
            row.item:SetText(entry.recipe.name)
            row.status:SetText(entry.readyAt <= now and "Готово" or date("%d.%m %H:%M", math.ceil(entry.readyAt)))
            row:Show()
        end
        for i = #entries + 1, #rows do rows[i]:Hide() end
        content:SetHeight(math.max(1, #entries * rowHeight))
        UpdateScrollbar()
    end
    page:HookScript("OnShow", RefreshCooldowns)
end

local professionIcon = "Interface\\Icons\\INV_SideTab_Professions_c60"
ns.AddSetting("professions", "Вкладка «Профессии»", nil, true, "general", {
    title = "Профессии", detail = "Показывать вкладку", icon = professionIcon,
})
ns.tabsAfterGeneral = ns.tabsAfterGeneral or {}
table.insert(ns.tabsAfterGeneral, {
    key = "professions", title = "Профессии", icon = professionIcon, columns = 1,
    toggle = true, afterSettings = BuildCharacters,
})

local function BuildReminder(recipe)
    local frame = CreateFrame("Frame", recipe.frameName, UIParent)
    recipe.frame = frame
    frame:SetSize(42, 42)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    local positionKey = recipe.key .. "Position"
    local pos = ns.db[positionKey] or { recipe.x, -160 }
    frame:SetPoint("CENTER", UIParent, "CENTER", pos[1], pos[2])
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(recipe.icon)
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    recipe.label = label
    label:SetPoint("TOP", frame, "BOTTOM", 0, -3)
    label:SetFont(ns.CYRILLIC_FONT, 13, "OUTLINE")

    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y = self:GetCenter()
        local cx, cy = UIParent:GetCenter()
        ns.db[positionKey] = { x - cx, y - cy }
    end)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetText(recipe.name .. " — можно изготовить")
        for _, name in ipairs(recipe.readyNames) do GameTooltip:AddLine(name, 1, 1, 1) end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

ns.AddSetting("mooncloth", "Готовность луноткани", RefreshCooldowns, true, "professions", { icon = recipes[1].icon })
ns.AddSetting("arcanite", "Готовность арканита", RefreshCooldowns, true, "professions", { icon = recipes[2].icon })
ns.On("PLAYER_LOGIN", function()
    for _, recipe in ipairs(recipes) do BuildReminder(recipe) end
    C_Timer.NewTicker(15, RefreshCooldowns)
    RefreshCooldowns()
end)

local function ReadCooldowns()
    local trade = C_TradeSkillUI
    if not (ProfessionsFrame and ProfessionsFrame:IsShown() and trade and trade.GetBaseProfessionInfo
        and trade.GetRecipeInfo and trade.GetRecipeCooldown) then return end
    if (trade.IsTradeSkillLinked and trade.IsTradeSkillLinked()) or (trade.IsTradeSkillGuild and trade.IsTradeSkillGuild()) then return end
    local info = trade.GetBaseProfessionInfo()
    if not info then return end

    for _, recipe in ipairs(recipes) do
        if recipe.profession == info.professionID then
            local data = trade.GetRecipeInfo(recipe.spell)
            if not data or type(data.learned) ~= "boolean" then return end
            local character = ns.CurrentProfessionCharacter()
            if not character then return end
            if data.learned then
                local ok, cooldown = pcall(trade.GetRecipeCooldown, recipe.spell)
                if not ok or (issecretvalue and issecretvalue(cooldown)) then return end
                local now = GetServerTime()
                character[recipe.key] = { readyAt = now + math.max(0, ns.Number(cooldown) or 0), at = now }
            else
                character[recipe.key] = nil
            end
            RefreshCooldowns()
            return
        end
    end
end

local pendingRead
local function ScheduleRead()
    if pendingRead then return end
    pendingRead = true
    C_Timer.After(0.6, function()
        pendingRead = nil
        ReadCooldowns()
    end)
end

for _, event in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED",
    "TRADE_SKILL_ITEM_CRAFTED_RESULT" }) do
    ns.On(event, ScheduleRead)
end
ns.On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spell)
    if unit ~= "player" then return end
    spell = ns.Number(spell)
    for _, recipe in ipairs(recipes) do
        if spell == recipe.spell then
            local character = ns.CurrentProfessionCharacter()
            if not character then return end
            local now = GetServerTime()
            -- Keep a deadline even if the profession window is closed at completion.
            character[recipe.key] = { readyAt = now + recipe.duration, at = now }
            RefreshCooldowns()
            ScheduleRead()
            return
        end
    end
end)

