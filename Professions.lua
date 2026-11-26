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

function ns.CreateTimerBox()
    local box = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    box:SetSize(218, 32)
    box:SetFrameStrata("HIGH")
    box:SetClampedToScreen(true)
    box:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    box:SetBackdropColor(0.04, 0.03, 0.02, 0.94)
    local label = box:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    label:SetPoint("CENTER")
    label:SetFont(ns.CYRILLIC_FONT, 16, "OUTLINE")
    return box, label
end

local function ApplyCraftTimer()
    if not ns.Enabled("craftTimer") then
        if craftTimer then craftTimer:UnregisterAllEvents() end
        HideCraftTimer()
        return
    end
    if not C_TradeSkillUI or not C_TradeSkillUI.GetRemainingRecasts then return end

    if not craftTimer then
        craftTimer, craftText = ns.CreateTimerBox()
        craftTimer:SetMovable(true)
        craftTimer:EnableMouse(true)
        craftTimer:RegisterForDrag("LeftButton")
        craftTimer:SetScript("OnDragStart", craftTimer.StartMoving)
        craftTimer:SetScript("OnDragStop", craftTimer.StopMovingOrSizing)
        craftTimer:SetScript("OnHide", craftTimer.StopMovingOrSizing)
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
        duration = 95 * 3600 },
    { key = "arcanite", spell = 17187, profession = 171, name = "Арканитовый слиток", icon = 134459,
        duration = 47 * 3600 },
}
local refreshPage, refreshTracker, refreshReminder, nextReminder

function ns.CurrentProfessionCharacter()
    local guid = UnitGUID("player")
    if not guid then return end
    ns.db.characters = ns.db.characters or {}
    local character = ns.db.characters[guid] or {}
    ns.db.characters[guid] = character
    character.professions = character.professions or {}
    character.name, character.realm = ns.CharacterIdentity()
    local class = select(2, UnitClass("player"))
    if not (issecretvalue and issecretvalue(class)) and class then character.class = class end
    return character
end

local function CooldownClass(character, guid, playerGUID, playerClass)
    if character.class then return character.class end
    if guid == playerGUID then return playerClass end
    local class
    if GetPlayerInfoByGUID and type(guid) == "string" and guid:match("^Player%-") then
        class = select(2, GetPlayerInfoByGUID(guid))
        if not (issecretvalue and issecretvalue(class)) and class then return class end
    end
    local api = Syndicator and Syndicator.API
    if api and api.GetCharacter and character.realm then
        local cached = api.GetCharacter(character.name .. "-" .. character.realm:gsub("%s+", ""))
        local details = cached and cached.details
        if details then return details.className end
    end
end

local function CooldownEntries(now, characters)
    local entries = {}
    local playerGUID = UnitGUID("player")
    local playerClass = select(2, UnitClass("player"))
    if issecretvalue and issecretvalue(playerClass) then playerClass = nil end
    for key, character in pairs(characters or {}) do
        if character.name and character.name ~= "" then
            for _, recipe in ipairs(recipes) do
                local snapshot = character[recipe.key]
                local readyAt = snapshot and ns.Number(snapshot.readyAt)
                if readyAt then
                    local class = CooldownClass(character, key, playerGUID, playerClass)
                    character.class = class
                    entries[#entries + 1] = {
                        recipe = recipe, character = key, name = character.name, class = class, readyAt = readyAt,
                    }
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
    local entries = CooldownEntries(now, ns.db.characters)
    if nextReminder then
        nextReminder:Cancel()
        nextReminder = nil
    end
    for _, entry in ipairs(entries) do
        if entry.readyAt > now then
            nextReminder = C_Timer.NewTimer(math.max(1, entry.readyAt - now), RefreshCooldowns)
            break
        end
    end
    if refreshPage then refreshPage(entries, now) end
    if refreshTracker then refreshTracker(entries, now) end
    if refreshReminder then refreshReminder(entries, now) end
end

local function CooldownText(readyAt, now)
    return readyAt <= now and "Готово" or date("%d.%m • %H:%M", math.ceil(readyAt))
end

local function BuildProfessionCooldownTracker(parent, heading)
    local tracker = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    tracker:SetWidth(294)
    tracker:SetClampedToScreen(true)
    tracker:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    tracker:SetBackdropColor(0.08, 0.057, 0.035, 0.97)
    local title = tracker:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText(heading or "Откаты профессий")
    local empty = tracker:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    empty:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -9)
    empty:SetPoint("RIGHT", -12, 0)
    empty:SetJustifyH("LEFT")
    empty:SetText("Открой алхимию или портняжное дело на персонаже с изученным рецептом.")

    local scroll = CreateFrame("ScrollFrame", nil, tracker, "ScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -31)
    scroll:SetPoint("BOTTOMRIGHT", -28, 9)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(254, 1)
    scroll:SetScrollChild(content)
    scroll:HookScript("OnScrollRangeChanged", function(_, _, range)
        scroll.ScrollBar:SetShown(range > 0)
        if scroll:GetVerticalScroll() > range then scroll:SetVerticalScroll(range) end
    end)

    local rows = {}
    local rowHeight = 36
    tracker:Hide()

    return tracker, function(entries, now)
        empty:SetShown(#entries == 0)
        scroll:SetShown(#entries > 0)
        tracker:SetHeight(#entries == 0 and 76 or 40 + math.min(#entries, 6) * rowHeight)
        for i, entry in ipairs(entries) do
            local row = rows[i]
            if not row then
                row = CreateFrame("Frame", nil, content)
                rows[i] = row
                row:SetSize(254, rowHeight)
                row:SetPoint("TOPLEFT", 0, -(i - 1) * rowHeight)
                row.icon = row:CreateTexture(nil, "ARTWORK")
                row.icon:SetSize(23, 23)
                row.icon:SetPoint("LEFT")
                row.status = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                row.status:SetPoint("TOPRIGHT", 0, -4)
                row.status:SetWidth(63)
                row.status:SetJustifyH("RIGHT")
                row.status:SetWordWrap(false)
                row.status:SetFont(ns.CYRILLIC_FONT, 13, "")
                row.day = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                row.day:SetPoint("BOTTOMRIGHT", 0, 4)
                row.day:SetWidth(63)
                row.day:SetJustifyH("RIGHT")
                row.day:SetTextColor(0.8, 0.75, 0.68)

                row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                row.name:SetPoint("TOPLEFT", 30, -4)
                row.name:SetPoint("RIGHT", row.status, "LEFT", -10, 0)
                row.name:SetFont(ns.CYRILLIC_FONT, 13, "")
                row.name:SetJustifyH("LEFT")
                row.name:SetWordWrap(false)
                row.item = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                row.item:SetPoint("BOTTOMLEFT", 30, 4)
                row.item:SetPoint("RIGHT", row.day, "LEFT", -10, 0)
                row.item:SetJustifyH("LEFT")
                row.item:SetFont(ns.CYRILLIC_FONT, 11, "")
                row.item:SetTextColor(0.8, 0.75, 0.68)
                row.item:SetWordWrap(false)

                local separator = row:CreateTexture(nil, "ARTWORK")
                separator:SetPoint("BOTTOMLEFT")
                separator:SetPoint("BOTTOMRIGHT")
                separator:SetHeight(1)
                separator:SetColorTexture(0.82, 0.69, 0.47, 0.15)
            end
            row.icon:SetTexture(entry.recipe.icon)
            row.name:SetText(entry.name)
            local color = entry.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[entry.class]
            if color then
                row.name:SetTextColor(color.r, color.g, color.b)
            else
                row.name:SetTextColor(1, 1, 1)
            end
            row.item:SetText(entry.recipe.name)
            local ready = entry.readyAt <= now
            local readyAt = math.ceil(entry.readyAt)
            row.status:SetText(ready and "Готово" or date("%H:%M", readyAt))
            if ready then
                row.status:SetTextColor(0.45, 1, 0.45)
            else
                row.status:SetTextColor(1, 0.82, 0.38)
            end
            row.day:SetText(date("%d.%m", readyAt))
            row:Show()
        end
        for i = #entries + 1, #rows do rows[i]:Hide() end
        content:SetHeight(math.max(1, #entries * rowHeight))
        scroll.ScrollBar:SetShown(#entries > 6)
    end
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
            row.status:SetText(CooldownText(entry.readyAt, now))
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

local function PositionCooldownTracker(tracker, parent)
    tracker:ClearAllPoints()
    local right, left = parent:GetRight(), parent:GetLeft()
    local gap = 60
    if right and GetScreenWidth() - right >= tracker:GetWidth() + gap then
        tracker:SetPoint("TOPLEFT", parent, "TOPRIGHT", gap, 0)
    elseif left and left >= tracker:GetWidth() + 8 then
        tracker:SetPoint("TOPRIGHT", parent, "TOPLEFT", -8, 0)
    else
        tracker:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -42, -44)
    end
end

local function BuildReadyWindow(preview)
    local frame, update = BuildProfessionCooldownTracker(UIParent, preview and "Откаты профессий — пример")
    local positionKey = "professionReadyPosition"
    local position = ns.db[positionKey]
    if position then
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", position.x, position.y)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, -160)
    end
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self:SetUserPlaced(false)
        local left, top = self:GetLeft(), self:GetTop()
        if not preview and left and top then
            ns.db[positionKey] = {
                x = left - (UIParent:GetLeft() or 0),
                y = top - (UIParent:GetBottom() or 0),
            }
        end
    end)
    frame:HookScript("OnHide", frame.StopMovingOrSizing)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 1)
    return frame, update, close
end

local readyWindow, updateReady, visibleReady
local function UpdateReadyWindow(entries, now)
    local ready = {}
    local dismissed = ns.db.professionReadyDismissed or {}
    for _, entry in ipairs(entries) do
        local key = entry.character .. ":" .. entry.recipe.key
        if ns.Enabled(entry.recipe.key) and entry.readyAt <= now and dismissed[key] ~= entry.readyAt then
            entry.reminderKey = key
            ready[#ready + 1] = entry
        end
    end
    visibleReady = ready
    if #ready == 0 then
        if readyWindow then readyWindow:Hide() end
        return
    end
    if not readyWindow then
        local close
        readyWindow, updateReady, close = BuildReadyWindow(false)
        close:SetScript("OnClick", function()
            ns.db.professionReadyDismissed = ns.db.professionReadyDismissed or {}
            for _, entry in ipairs(visibleReady) do
                ns.db.professionReadyDismissed[entry.reminderKey] = entry.readyAt
            end
            readyWindow:Hide()
        end)
    end
    updateReady(ready, now)
    readyWindow:Show()
end

ns.AddSetting("mooncloth", "Готовность луноткани", RefreshCooldowns, true, "professions", { icon = recipes[1].icon })
ns.AddSetting("arcanite", "Готовность арканита", RefreshCooldowns, true, "professions", { icon = recipes[2].icon })
ns.On("PLAYER_LOGIN", function()
    refreshReminder = UpdateReadyWindow
    if ns.db.characters and ns.db.characters[UnitGUID("player")] then ns.CurrentProfessionCharacter() end
    RefreshCooldowns()
end)

local tracker, pendingRead, professionOpen

local function HasOpenProfession()
    return professionOpen and ProfessionsFrame and ProfessionsFrame:IsVisible() and C_TradeSkillUI
end

local function ReadRecipeCooldown(trade, recipe)
    -- Some Forever builds expose only the spell cooldown.
    if trade.GetRecipeCooldown then
        local remaining = trade.GetRecipeCooldown(recipe.spell)
        if issecretvalue and issecretvalue(remaining) then return end
        remaining = ns.Number(remaining)
        if remaining then return math.max(0, remaining) end
    end
    if not C_Spell or not C_Spell.GetSpellCooldown then return end
    local info = C_Spell.GetSpellCooldown(recipe.spell)
    if not info or (issecretvalue and issecretvalue(info)) then return end
    local start, duration = ns.Number(info.startTime), ns.Number(info.duration)
    if not start or not duration then return end
    if start == 0 or duration <= 2 then return 0 end

    local remaining = start + duration - GetTime()
    -- Game uptime may wrap at 2^32 milliseconds.
    if remaining > duration + 1 then remaining = remaining % 4294967.296 end
    if remaining <= duration + 1 then return math.max(0, remaining) end
end

local function ReadCooldowns()
    if not HasOpenProfession() then return end
    local trade = C_TradeSkillUI
    if (trade.IsTradeSkillLinked and trade.IsTradeSkillLinked()) or (trade.IsTradeSkillGuild and trade.IsTradeSkillGuild()) then
        if tracker then tracker:Hide() end
        return
    end

    if not tracker then tracker, refreshTracker = BuildProfessionCooldownTracker(ProfessionsFrame) end
    PositionCooldownTracker(tracker, ProfessionsFrame)
    tracker:Show()
    if trade.GetBaseProfessionInfo and trade.GetRecipeInfo
        and (not trade.IsTradeSkillReady or trade.IsTradeSkillReady()) then
        local info = trade.GetBaseProfessionInfo()
        for _, recipe in ipairs(recipes) do
            if info and recipe.profession == info.professionID then
                local data = trade.GetRecipeInfo(recipe.spell)
                if not data or (issecretvalue and issecretvalue(data.learned)) or type(data.learned) ~= "boolean" then break end
                local character = ns.CurrentProfessionCharacter()
                if not character then break end
                if data.learned then
                    local ok, remaining = pcall(ReadRecipeCooldown, trade, recipe)
                    if ok and remaining then
                        local now = GetServerTime()
                        local previous = character[recipe.key]
                        local previousReadyAt = previous and ns.Number(previous.readyAt)
                        local readyAt = now + remaining
                        if remaining == 0 and previousReadyAt and previousReadyAt <= now then
                            readyAt = previousReadyAt
                        end
                        character[recipe.key] = { readyAt = readyAt, at = now }
                    end
                else
                    character[recipe.key] = nil
                end
                break
            end
        end
    end
    RefreshCooldowns()
end

local function CloseProfession()
    professionOpen = false
    if pendingRead then
        pendingRead:Cancel()
        pendingRead = nil
    end
    if tracker then tracker:Hide() end
end

local function ScheduleRead()
    if pendingRead or not HasOpenProfession() then return end
    pendingRead = C_Timer.NewTimer(0.6, function()
        pendingRead = nil
        ReadCooldowns()
    end)
end

ns.On("TRADE_SKILL_SHOW", function()
    professionOpen = true
    -- TRADE_SKILL_SHOW can arrive before Blizzard shows its frame.
    if pendingRead then pendingRead:Cancel() end
    pendingRead = C_Timer.NewTimer(0, function()
        pendingRead = nil
        ReadCooldowns()
    end)
end)
ns.On("TRADE_SKILL_CLOSE", CloseProfession)
for _, event in ipairs({ "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED",
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
            -- A successful craft gives us a deadline without querying the game.
            character[recipe.key] = { readyAt = now + recipe.duration, at = now }
            RefreshCooldowns()
            ScheduleRead()
            return
        end
    end
end)

local cooldownPreview, updateCooldownPreview, readyPreview, updateReadyPreview
function ns.ShowProfessionCooldownPreview(characters, readyOnly)
    local now = GetServerTime()
    if readyOnly then
        if not readyPreview then
            local close
            readyPreview, updateReadyPreview, close = BuildReadyWindow(true)
            close:SetScript("OnClick", function() readyPreview:Hide() end)
        end
        if cooldownPreview then cooldownPreview:Hide() end
        updateReadyPreview(CooldownEntries(now, characters), now)
        readyPreview:Show()
        return
    end
    if not cooldownPreview then
        local close
        cooldownPreview, updateCooldownPreview, close = BuildReadyWindow(true)
        close:SetScript("OnClick", function() cooldownPreview:Hide() end)
    end
    if readyPreview then readyPreview:Hide() end
    if ProfessionsFrame and ProfessionsFrame:IsVisible() then
        PositionCooldownTracker(cooldownPreview, ProfessionsFrame)
    end
    updateCooldownPreview(CooldownEntries(now, characters), now)
    cooldownPreview:Show()
end
