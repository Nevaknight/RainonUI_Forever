local _, ns = ...

local timers, samples, landmarks = {}, {}, {}
local rows, headings = {}, {}
local panel, instance, preview, dismissed
local grow, shrink, scaleText
local minScale, maxScale, scaleStep = 60, 160, 10
local minimumWidth, sideInset, firstRowTop = 310, 12, 36
local colors = {
    alliance = {0.18, 0.42, 0.78}, horde = {0.66, 0.19, 0.16}, neutral = {0.61, 0.44, 0.16},
}
local groups = {"score", "alliance", "horde", "neutral"}
local titles = {score = "Победа", alliance = "Альянс", horde = "Орда"}
local icons = {start = 136106, flag = 134420, alliance = 132486, horde = 132485, neutral = 136001}
-- Slots from Blizzard widgets 1645 (Arathi) and 7860 (Darkspear).
-- Each faction has its own slot order. State 1 is the contested objective.
local arathiSlots = {[32] = 1, [22] = 2, [27] = 3, [17] = 4, [37] = 5,
    [39] = 1, [19] = 2, [29] = 3, [24] = 4, [34] = 5}
local darkspearSlots = {
    alliance = {[8771] = 2, [8768] = 3, [8772] = 4, [8773] = 5},
    horde = {[8773] = 2, [8772] = 3, [8768] = 4, [8771] = 5},
}

local function ObjectiveAtlas(map, side, index, poiID)
    local kit, slot
    if map == 529 then
        kit, slot = "ab_capPts", arathiSlots[index]
    elseif map == 2997 and darkspearSlots[side] then
        kit, slot = "di_capPts", darkspearSlots[side][poiID]
    end
    if slot then
        return ("%s-%sIcon%d-state1"):format(kit, side == "alliance" and "left" or "right", slot)
    end
end

local function SetRowIcon(texture, timer)
    local atlas = ObjectiveAtlas(timer.map, timer.side, timer.poiIcon, timer.poiID)
    if not (atlas and C_Texture.GetAtlasInfo(atlas)) then atlas = timer.atlas end
    if atlas and not C_Texture.GetAtlasInfo(atlas) then atlas = nil end
    if atlas then
        texture:SetAtlas(atlas)
    elseif timer.poiIcon then
        texture:SetTexture(136441) -- Interface\Minimap\POIIcons
        texture:SetTexCoord(C_Minimap.GetPOITextureCoords(timer.poiIcon))
    else
        texture:SetTexture(icons[timer.key] or icons[timer.side])
        texture:SetTexCoord(0, 1, 0, 1)
    end
end

local function ScalePercent(value)
    return math.max(minScale, math.min(maxScale, math.floor((tonumber(value) or 100) + 0.5)))
end

local function ApplyScale()
    local percent = ScalePercent(ns.db.battleTimerScale)
    panel:SetScale(percent / 100)
    grow:SetEnabled(percent < maxScale)
    shrink:SetEnabled(percent > minScale)
    scaleText:SetFormattedText("%d%%", percent)
end

local function GetRow(index)
    if rows[index] then return rows[index] end
    local row = CreateFrame("StatusBar", nil, panel)
    rows[index] = row
    row:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.15, 0.12, 0.10, 1)
    row.icon = row:CreateTexture(nil, "OVERLAY")
    row.icon:SetSize(18, 18)
    row.icon:SetPoint("LEFT", 2, 0)
    row.clock = ns.CreateText(row, nil, "OVERLAY", "GameFontHighlight")
    ns.ApplyUIFont(row.clock, 13, "OUTLINE")
    row.clock:SetPoint("RIGHT", -5, 0)
    row.clock:SetJustifyH("RIGHT")
    row.label = ns.CreateText(row, nil, "OVERLAY", "GameFontHighlight")
    ns.ApplyUIFont(row.label, 13, "OUTLINE")
    row.label:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
    row.label:SetPoint("RIGHT", row.clock, "LEFT", -8, 0)
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(true)
    row.label:SetNonSpaceWrap(true)
    return row
end

local function FitPanelCorners(panel)
    local border = panel.NineSlice
    if not (border and NineSliceUtil) then return end
    local layout = NineSliceUtil.GetLayout(border:GetFrameLayoutType())
    if not layout then return end
    local corners = {}
    for _, key in ipairs({"TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner"}) do
        local texture = border[key]
        local info = C_Texture.GetAtlasInfo(layout[key].atlas)
        if not (texture and info and (info.file or info.filename)) then return end
        corners[#corners + 1] = {texture = texture, info = info, height = texture:GetHeight()}
    end

    panel:HookScript("OnSizeChanged", function(_, _, height)
        -- The metal corners include long side strips. Shorten those strips
        -- while keeping each corner's outer end and leaving room for the edges.
        local available = height + layout.TopLeftCorner.y - layout.BottomLeftCorner.y - 2
        local topHeight, bottomHeight = corners[1].height, corners[3].height
        local top = math.min(topHeight, available - math.min(bottomHeight, available * 0.30))
        local bottom = math.min(bottomHeight, available - top)
        for i, corner in ipairs(corners) do
            local info, texture = corner.info, corner.texture
            local visible = i <= 2 and top or bottom
            local uvHeight = (info.bottomTexCoord - info.topTexCoord) * visible / corner.height
            local first = i <= 2 and info.topTexCoord or info.bottomTexCoord - uvHeight
            texture:SetTexture(info.file or info.filename)
            texture:SetTexCoord(info.leftTexCoord, info.rightTexCoord, first, first + uvHeight)
            texture:SetHeight(visible)
        end
    end)
end

local function Draw(layoutChanged)
    local now = GetTime()
    local list = preview and samples or timers
    for i = #list, 1, -1 do
        if list[i].ends and list[i].ends <= now then
            table.remove(list, i)
            layoutChanged = true
        end
    end
    if preview and #list == 0 then
        preview = nil
        return Draw(true)
    end
    if #list == 0 or dismissed then
        if panel then panel:Hide() end
        return
    end
    if not panel then
        local close
        panel, close = ns.CreateLootPanel("RainonUIForeverBattleTimers", "", minimumWidth, firstRowTop)
        panel:SetPoint("TOP", UIParent, "TOP", 230, -175)
        panel:SetMovable(true)
        panel:RegisterForDrag("LeftButton")
        panel:SetScript("OnDragStart", panel.StartMoving)
        panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
        panel:HookScript("OnHide", panel.StopMovingOrSizing)
        close:ClearAllPoints()
        close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, 0)
        FitPanelCorners(panel)
        close:SetScript("OnClick", function()
            dismissed = true
            preview = nil
            wipe(samples)
            panel:Hide()
        end)
        local function ChangeScale(step)
            ns.db.battleTimerScale = ScalePercent(ScalePercent(ns.db.battleTimerScale) + step)
            ApplyScale()
            Draw(true)
        end
        grow = ns.CreateLootSizeButton(panel, close, "RedButton-Expand", "RedButton-Expand-Disabled", function()
            ChangeScale(scaleStep)
        end)
        shrink = ns.CreateLootSizeButton(panel, grow, "RedButton-Condense", "RedButton-Condense-disabled", function()
            ChangeScale(-scaleStep)
        end)
        scaleText = ns.CreateText(panel, nil, "OVERLAY", "GameFontHighlightSmall")
        scaleText:SetPoint("RIGHT", shrink, "LEFT", -8, 0)
        ApplyScale()
        for side, title in pairs(titles) do
            local heading = ns.CreateText(panel, nil, "OVERLAY", "GameFontNormal")
            ns.ApplyUIFont(heading, 14, "OUTLINE")
            heading:SetText(title)
            headings[side] = heading
        end
        local elapsed = 0
        panel:SetScript("OnUpdate", function(_, delta)
            elapsed = elapsed + delta
            if elapsed >= 0.1 then
                elapsed = 0
                Draw()
            end
        end)
        layoutChanged = true
    end
    if layoutChanged then
        table.sort(list, function(a, b)
            if a.ends ~= b.ends then return (a.ends or 0) < (b.ends or 0) end
            return a.label < b.label
        end)
        local count, top = 0, firstRowTop
        local screenWidth = UIParent:GetWidth() / panel:GetScale() - 2 * sideInset
        local rowWidth, clockWidth = 0, 0
        local measure = GetRow(1)
        for _, timer in ipairs(list) do
            rowWidth = math.max(rowWidth, measure.label:GetUnboundedStringWidthForText(timer.label))
            if timer.ends then
                local seconds = math.ceil(timer.ends - now)
                local clock = ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
                clockWidth = math.max(clockWidth, measure.clock:GetUnboundedStringWidthForText(clock))
            end
        end
        -- Keep space for changing digits without shifting the label between updates.
        clockWidth = math.ceil(math.max(clockWidth, measure.clock:GetUnboundedStringWidthForText("000:00"))) + 4
        local contentWidth = math.ceil(rowWidth) + 25 + 8 + clockWidth + 5
        local width = math.min(screenWidth, math.max(minimumWidth, contentWidth + 2 * sideInset))
        panel:SetWidth(width)
        for _, group in ipairs(groups) do
            local heading = headings[group]
            if heading then heading:Hide() end
            for _, timer in ipairs(list) do
                local section = timer.key == "score" and "score" or timer.side
                if section == group then
                    if heading and not heading:IsShown() then
                        heading:SetPoint("TOPLEFT", panel, "TOPLEFT", sideInset, -top)
                        heading:Show()
                        top = top + math.max(19, math.ceil(heading:GetStringHeight()) + 4)
                    end
                    count = count + 1
                    local row = GetRow(count)
                    row.timer = timer
                    row:SetPoint("TOPLEFT", panel, "TOPLEFT", sideInset, -top)
                    row:SetWidth(width - 2 * sideInset)
                    row.clock:SetWidth(timer.ends and clockWidth or 1)
                    row:SetMinMaxValues(0, timer.total)
                    row:SetStatusBarColor(unpack(colors[timer.side]))
                    row.label:SetText(timer.label)
                    SetRowIcon(row.icon, timer)
                    row:Show()
                    local height = math.max(20, math.ceil(row.label:GetStringHeight()) + 4)
                    row:SetHeight(height)
                    top = top + height + 3
                end
            end
        end
        for i = count + 1, #rows do
            rows[i].timer = nil
            rows[i]:Hide()
        end
        panel:SetHeight(top + 9)
        panel:Show()
    end
    for _, row in ipairs(rows) do
        if not row.timer then break end
        if row.timer.ends then
            local remaining = row.timer.ends - now
            local seconds = math.ceil(remaining)
            row:SetValue(remaining)
            row.clock:SetFormattedText("%d:%02d", math.floor(seconds / 60), seconds % 60)
        else
            row:SetValue(row.timer.total)
            row.clock:SetText("")
        end
    end
end

local function SetTimer(key, label, seconds, side, total, poi, poiID, hold)
    local active = hold or (seconds and seconds > 0)
    local entry
    for i, timer in ipairs(timers) do
        if timer.key == key then
            if active and (not timer.ends or timer.ends > GetTime()) then
                entry = timer
            else
                table.remove(timers, i)
            end
            break
        end
    end
    if active then
        if seconds and (not entry or not entry.ends or (poi and entry.side ~= side) or key == "flag") then
            dismissed = nil
        end
        if not entry then
            entry = {key = key}
            timers[#timers + 1] = entry
        end
        if key == "score" and entry.label == label then total = entry.total end
        entry.label, entry.side = label, side or "neutral"
        entry.map, entry.poiID = instance, poiID
        entry.poiIcon, entry.atlas = poi and poi.textureIndex, poi and poi.atlasName
        entry.ends = seconds and GetTime() + seconds
        entry.total = seconds and math.max(total or seconds, seconds) or 1
    end
    if not poi then Draw(true) end
end

function ns.ShowBattleTimerPreview(examples)
    samples = examples
    preview = true
    dismissed = nil
    Draw(true)
end

function ns.RefreshBattleTimerLayout()
    if panel and panel:IsShown() then Draw(true) end
end

local attacks = {
    [17] = "alliance", [19] = "horde", [22] = "alliance", [24] = "horde",
    [27] = "alliance", [29] = "horde", [32] = "alliance", [34] = "horde",
    [37] = "alliance", [39] = "horde",
}
-- Graveyards, towers and the remaining map symbols used by Forever objectives.
for _, pair in ipairs({{4, 14}, {9, 12}, {137, 139}, {142, 144}, {147, 149}, {152, 154},
    {208, 209}, {213, 214}, {218, 219}}) do
    attacks[pair[1]], attacks[pair[2]] = "alliance", "horde"
end
local alteracMines = {[2] = "horde", [3] = "alliance"}
local objectiveMaps = {[529] = 1461, [30] = 1459}
local captureSeconds = {[529] = 60, [30] = 300, [2997] = 60}
local function UpdateObjective(poi, id, now, duration)
    local icon, name = poi.textureIndex, poi.name
    local side = attacks[icon]
    local mine = instance == 30 and alteracMines[icon]
    local previous = landmarks[name]
    local changed = not previous or previous.icon ~= icon
    local state = changed and {icon = icon} or previous
    landmarks[name] = state
    local seconds
    if side then
        local readSeconds = C_AreaPoiInfo.GetAreaPOISecondsLeft
        seconds = readSeconds and ns.Number(readSeconds(id))
        if seconds and seconds > 0 and seconds <= duration then
            state.ends = now + seconds
        elseif changed then
            -- Start immediately for attacks observed on the first map update as well.
            state.ends = now + duration
        end
        seconds = state.ends and state.ends - now
    end
    SetTimer(name, name, seconds, side or mine, duration, poi, id, mine)
end

local function ReadObjectives()
    local map = C_Map.GetBestMapForUnit("player") or objectiveMaps[instance]
    if not map then return end
    local now = GetTime()
    -- Updates can arrive before all map markers are visible. A partial list
    -- does not mean an objective was defended or that its countdown restarted.
    for _, id in ipairs(C_AreaPoiInfo.GetAreaPOIForMap(map) or {}) do
        local poi = C_AreaPoiInfo.GetAreaPOIInfo(map, id)
        if poi and poi.name and poi.textureIndex then
            UpdateObjective(poi, poi.areaPoiID or id, now, captureSeconds[instance])
        end
    end
    Draw(true)
end

-- Forever uses the same resource widget on Arathi and Darkspear. Only Arathi
-- has independent team clocks determined by the number of controlled bases.
local scoreWidget, baseWidget = 7467, 1645
local intervals = {12, 9, 6, 3, 1}
local projections = {}
local islandTick

local function Captured(icons)
    local count = 0
    for _, icon in ipairs(icons) do
        if ns.Number(icon.iconState) == 2 then count = count + 1 end
    end
    return count
end

local function ArathiRate(side, score, bases, now)
    local last = projections[side]
    if not last or last.bases ~= bases or last.score ~= score then
        last = {score = score, bases = bases, at = now}
        projections[side] = last
    end
    return bases == 5 and 30 or 10, intervals[bases], last.at
end

local function DisplayForecast(goal, aScore, hScore, aGain, hGain, aInterval, hInterval, aAt, hAt)
    local now = GetTime()
    local function Seconds(score, gain, interval, at)
        if not interval or gain <= 0 then return math.huge end
        return math.max(0, at + math.ceil((goal - score) / gain) * interval - now)
    end
    local a = Seconds(aScore, aGain, aInterval, aAt)
    local h = Seconds(hScore, hGain, hInterval, hAt)
    local remaining = math.min(a, h)
    if remaining == math.huge or remaining <= 0 then SetTimer("score"); return end
    local function Final(score, gain, interval, at)
        if not interval or gain <= 0 then return score end
        return math.min(goal, score + gain * math.floor((now + remaining - at) / interval + 0.0001))
    end
    local side = a == h and "neutral" or (a < h and "alliance" or "horde")
    local label = ("%s  %d - %d"):format(titles[side] or "Ничья",
        Final(aScore, aGain, aInterval, aAt), Final(hScore, hGain, hInterval, hAt))
    SetTimer("score", label, remaining, side)
end

local function ReadScore()
    local bar = C_UIWidgetManager.GetDoubleStatusBarWidgetVisualizationInfo(scoreWidget)
    local goal = bar and ns.Number(bar.leftBarMax)
    local a = bar and ns.Number(bar.leftBarValue)
    local h = bar and ns.Number(bar.rightBarValue)
    if not goal or goal <= 0 or not a or not h or bar.shownState == 0 or a >= goal or h >= goal then
        islandTick = nil
        wipe(projections)
        SetTimer("score")
        return
    end
    local now = GetTime()
    if instance == 529 then
        local bases = C_UIWidgetManager.GetDoubleStateIconRowVisualizationInfo(baseWidget)
        if not bases or not bases.leftIcons or not bases.rightIcons then SetTimer("score"); return end
        local ag, ai, at = ArathiRate("alliance", a, Captured(bases.leftIcons), now)
        local hg, hi, ht = ArathiRate("horde", h, Captured(bases.rightIcons), now)
        DisplayForecast(goal, a, h, ag, hg, ai, hi, at, ht)
        return
    end

    -- Darkspear sends the two team updates together or a few frames apart.
    -- Measure from score changes, never from unrelated widget notifications.
    local tick = islandTick
    if not tick then islandTick = {a = a, h = h}; return end
    if tick.a == a and tick.h == h then return end
    local da, dh = a - tick.a, h - tick.h
    tick.a, tick.h = a, h
    if da > 65 or dh > 65 or da < 0 or dh < 0 then
        -- A flag delivery is a one-off bonus. Wait for fresh resource ticks.
        islandTick = {a = a, h = h}
        SetTimer("score")
        return
    end
    if not tick.at or now - tick.at > 0.5 then
        tick.interval = tick.at and math.floor(now - tick.at + 0.5)
        tick.at, tick.ag, tick.hg = now, da, dh
    else
        tick.ag, tick.hg = tick.ag + da, tick.hg + dh
    end
    if tick.interval then
        DisplayForecast(goal, a, h, tick.ag, tick.hg, tick.interval, tick.interval, tick.at, tick.at)
    end
end

local events = CreateFrame("Frame")
local function Stop()
    events:UnregisterAllEvents()
    wipe(timers)
    wipe(landmarks)
    wipe(projections)
    islandTick = nil
    wipe(samples)
    instance, preview, dismissed = nil, nil, nil
    Draw()
end

function ns.SyncBattleTimers()
    local _, kind, _, _, _, _, _, map = GetInstanceInfo()
    if kind ~= "pvp" or not ns.IsForeverBattlefield(map) or not ns.Enabled("pvp") or not ns.Enabled("battleTimers") then Stop(); return end
    if C_PvP and C_PvP.IsMatchComplete and C_PvP.IsMatchComplete() then Stop(); return end
    if instance == map then return end
    Stop()
    instance = map
    if captureSeconds[map] then
        events:RegisterEvent("AREA_POIS_UPDATED")
        ReadObjectives()
    end
    if map == 529 or map == 2997 then
        events:RegisterEvent("UPDATE_UI_WIDGET")
        events:RegisterEvent("UPDATE_ALL_UI_WIDGETS")
        ReadScore()
    end
    if map == 489 or map == 2997 then
        events:RegisterEvent("CHAT_MSG_BG_SYSTEM_ALLIANCE")
        events:RegisterEvent("CHAT_MSG_BG_SYSTEM_HORDE")
    end
end

events:SetScript("OnEvent", function(_, event, arg)
    if event == "AREA_POIS_UPDATED" then
        ReadObjectives()
    elseif event == "UPDATE_ALL_UI_WIDGETS" or (event == "UPDATE_UI_WIDGET" and arg
        and (arg.widgetID == scoreWidget or (instance == 529 and arg.widgetID == baseWidget))) then
        ReadScore()
    elseif event == "CHAT_MSG_BG_SYSTEM_ALLIANCE" or event == "CHAT_MSG_BG_SYSTEM_HORDE" then
        if type(arg) == "string" and not (issecretvalue and issecretvalue(arg))
            and (arg:find("captured the", 1, true) or arg:find("захватил", 1, true)) then
            SetTimer("flag", "Возвращение флагов", instance == 2997 and 23 or 12)
        end
    end
end)

ns.On("START_TIMER", function(kind, seconds, total)
    if kind ~= 0 or not ns.Enabled("pvp") or not ns.Enabled("battleTimers") then return end
    if not instance then ns.SyncBattleTimers() end
    if instance then SetTimer("start", "До начала боя", seconds, "neutral", total) end
end)
ns.On("PLAYER_ENTERING_WORLD", ns.SyncBattleTimers)
ns.On("PVP_MATCH_ACTIVE", ns.SyncBattleTimers)
ns.On("PLAYER_LEAVING_WORLD", Stop)
ns.On("PVP_MATCH_COMPLETE", Stop)
ns.AddSetting("battleTimers", "Таймеры поля боя", ns.SyncBattleTimers, true, "pvp", {
    icon = 136106, tooltip = "Показывает отсчёт до старта и таймеры целей поля боя. Окно можно перетащить мышью. Стрелки в окне меняют масштаб.",
})
