local _, ns = ...

local timers, landmarks = {}, {}
local live = {name = "RainonUIForeverBattleTimers", rows = {}, headings = {}}
local previews, previewCount = {}, 0
local instance, dismissed
local Draw
local minScale, maxScale, scaleStep = 60, 160, 10
local minimumWidth, sideInset, firstRowTop, sectionGap = 310, 12, 36, 6
local colors = {
    alliance = {0.18, 0.42, 0.78}, horde = {0.66, 0.19, 0.16}, neutral = {0.61, 0.44, 0.16},
}
local groups = {"score", "alliance", "horde", "neutral"}
local titles = {score = "Победа", alliance = "Альянс", horde = "Орда"}
local icons = {start = 136106, flag = 134420, alliance = 132486, horde = 132485, neutral = 136001}
local towerSides = {"alliance", "horde"}
local towerIcons = {alliance = 11, horde = 10}
local towerLimit = 4
-- Slots from Blizzard widgets 1645 (Arathi audio) and 7860 (Darkspear icons).
local arathiSlots = {[32] = 1, [22] = 2, [27] = 3, [17] = 4, [37] = 5,
    [39] = 1, [19] = 2, [29] = 3, [24] = 4, [34] = 5}
local darkspearSlots = {
    alliance = {[8771] = 2, [8768] = 3, [8772] = 4, [8773] = 5},
    horde = {[8773] = 2, [8772] = 3, [8768] = 4, [8771] = 5},
}

local function SetMapIcon(texture, index)
    texture:SetTexture(136441) -- Interface\\Minimap\\POIIcons
    texture:SetTexCoord(C_Minimap.GetPOITextureCoords(index))
end

local function SetRowIcon(texture, timer)
    if timer.map == 529 and timer.poiIcon then
        SetMapIcon(texture, timer.poiIcon)
        return
    end
    local sideSlots = timer.map == 2997 and darkspearSlots[timer.side]
    local slot = sideSlots and sideSlots[timer.poiID]
    local atlas = slot and ("di_capPts-%sIcon%d-state1"):format(timer.side == "alliance" and "left" or "right", slot)
    if not (atlas and C_Texture.GetAtlasInfo(atlas)) then atlas = timer.atlas end
    if atlas and C_Texture.GetAtlasInfo(atlas) then
        texture:SetAtlas(atlas)
    elseif timer.poiIcon then
        SetMapIcon(texture, timer.poiIcon)
    else
        texture:SetTexture(icons[timer.key] or icons[timer.side])
        texture:SetTexCoord(0, 1, 0, 1)
    end
end

local function ScalePercent(value)
    return math.max(minScale, math.min(maxScale, math.floor((tonumber(value) or 100) + 0.5)))
end

local function ApplyScale(view, scale)
    local percent = ScalePercent(ns.db.battleTimerScale)
    view.panel:SetScale(scale or percent / 100)
    view.grow:SetEnabled(percent < maxScale)
    view.shrink:SetEnabled(percent > minScale)
    view.scaleText:SetFormattedText("%d%%", math.floor((scale or percent / 100) * 100 + 0.5))
end

local function RestorePanelPosition(view)
    local saved = ns.db.battleTimerPositions
    local position = saved and saved[view.name]
    if not position then return false end
    local panel = view.panel
    local scale = panel:GetScale()
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", position.x / scale, position.y / scale)
    return true
end

local function SavePanelPosition(view)
    local panel = view.panel
    panel:StopMovingOrSizing()
    local left, top = panel:GetLeft(), panel:GetTop()
    if not (left and top) then return end
    local scale = panel:GetScale()
    local saved = ns.db.battleTimerPositions or {}
    ns.db.battleTimerPositions = saved
    saved[view.name] = {
        x = left * scale - (UIParent:GetLeft() or 0),
        y = top * scale - (UIParent:GetBottom() or 0),
    }
    RestorePanelPosition(view)
end

local function GetRow(view, index)
    if view.rows[index] then return view.rows[index] end
    local row = CreateFrame("StatusBar", nil, view.panel)
    view.rows[index] = row
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

local function CreateTowerRow(panel, side)
    local row = CreateFrame("Frame", nil, panel)
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.15, 0.12, 0.10, 1)
    row.faction = ns.CreateText(row, nil, "OVERLAY", "GameFontNormal")
    row.faction:SetPoint("LEFT", 7, 0)
    row.faction:SetText(titles[side])
    row.faction:SetTextColor(unpack(colors[side]))
    row.status = ns.CreateText(row, nil, "OVERLAY", "GameFontHighlight")
    row.status:SetPoint("LEFT", row.faction, "LEFT", 88, 0)
    row.status:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.status:SetJustifyH("CENTER")
    row.status:SetWordWrap(false)
    row.segments = {}
    for i = 1, towerLimit do
        local fill = row:CreateTexture(nil, "ARTWORK")
        fill:SetColorTexture(unpack(colors[side]))
        local icon = row:CreateTexture(nil, "OVERLAY")
        icon:SetSize(18, 18)
        icon:SetPoint("CENTER", fill)
        SetMapIcon(icon, towerIcons[side])
        row.segments[i] = {fill = fill, icon = icon}
    end
    return row
end

local function DrawTowerRows(view, width, top)
    if not view.towers then
        for _, row in pairs(view.towerRows or {}) do row:Hide() end
        return top
    end
    view.towerRows = view.towerRows or {}
    local trackStart, gap, height = 95, 3, 22
    local segmentWidth = (width - trackStart - 4 - (towerLimit - 1) * gap) / towerLimit
    for _, side in ipairs(towerSides) do
        local row = view.towerRows[side] or CreateTowerRow(view.panel, side)
        view.towerRows[side] = row
        row:SetPoint("TOPLEFT", view.panel, "TOPLEFT", sideInset, -top)
        row:SetSize(width, height)
        local remaining = view.towers[side]
        row.status:SetText(remaining == 0 and "Все башни уничтожены" or "Ожидание данных карты")
        row.status:SetShown(not remaining or remaining == 0)
        for i, segment in ipairs(row.segments) do
            segment.fill:SetPoint("TOPLEFT", row, "TOPLEFT", trackStart + (i - 1) * (segmentWidth + gap), -2)
            segment.fill:SetSize(segmentWidth, height - 4)
            local standing = remaining ~= nil and i <= remaining
            segment.fill:SetShown(standing)
            segment.icon:SetShown(standing)
        end
        row:Show()
        top = top + height + gap
    end
    return top
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

local function CreateView(view)
    local panel, close = ns.CreateLootPanel(view.name, view.title or "", minimumWidth, firstRowTop)
    view.panel = panel
    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", function() SavePanelPosition(view) end)
    panel:HookScript("OnHide", panel.StopMovingOrSizing)
    close:ClearAllPoints()
    close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, 0)
    FitPanelCorners(panel)
    close:SetScript("OnClick", function()
        panel:Hide()
        if view == live then
            dismissed = true
        else
            view.examples = nil
            previewCount = previewCount - 1
            if previewCount == 0 then Draw(true) end
        end
    end)
    local function ChangeScale(step)
        ns.db.battleTimerScale = ScalePercent(ScalePercent(ns.db.battleTimerScale) + step)
        ns.RefreshBattleTimerLayout()
    end
    view.grow = ns.CreateLootSizeButton(panel, close, "RedButton-Expand", "RedButton-Expand-Disabled", function()
        ChangeScale(scaleStep)
    end)
    view.shrink = ns.CreateLootSizeButton(panel, view.grow, "RedButton-Condense", "RedButton-Condense-Disabled", function()
        ChangeScale(-scaleStep)
    end)
    view.scaleText = ns.CreateText(panel, nil, "OVERLAY", "GameFontHighlightSmall")
    view.scaleText:SetPoint("RIGHT", view.shrink, "LEFT", -8, 0)
    if view.title then
        local header = panel.TitleContainer
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -1)
        header:SetPoint("TOPRIGHT", view.shrink, "TOPLEFT", 0, -1)
        local title = header.TitleText
        title:ClearAllPoints()
        title:SetAllPoints(header)
        title:SetJustifyH("CENTER")
        title:SetJustifyV("MIDDLE")
        title:SetWordWrap(false)
        view.titleButtonsWidth = 16 + close:GetWidth() + view.grow:GetWidth() + view.shrink:GetWidth()
    end
    ApplyScale(view)
    if view == live and not RestorePanelPosition(view) then panel:SetPoint("TOP", UIParent, "TOP", 230, -175) end
    for side, title in pairs(titles) do
        local heading = ns.CreateText(panel, nil, "OVERLAY", "GameFontNormal")
        ns.ApplyUIFont(heading, 14, "OUTLINE")
        heading:SetText(title)
        view.headings[side] = heading
    end
    if view == live then
        local elapsed = 0
        panel:SetScript("OnUpdate", function(_, delta)
            elapsed = elapsed + delta
            if elapsed >= 0.1 then
                elapsed = 0
                Draw()
            end
        end)
    end
end

local function DrawView(view, list, now, layoutChanged)
    if #list == 0 and not view.towers then
        if view.panel then view.panel:Hide() end
        return
    end
    if not view.panel then
        CreateView(view)
        layoutChanged = true
    end
    local panel, rows, headings = view.panel, view.rows, view.headings
    if layoutChanged then
        table.sort(list, function(a, b)
            if a.ends ~= b.ends then return (a.ends or 0) < (b.ends or 0) end
            return a.label < b.label
        end)
        local count, top = 0, firstRowTop
        local screenWidth = UIParent:GetWidth() / panel:GetScale() - 2 * sideInset
        local rowWidth, clockWidth = 0, 0
        local measure = GetRow(view, 1)
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
        local titleWidth = 0
        if view.title then
            local scaleWidth = view.scaleText:GetUnboundedStringWidthForText("888%") + 8
            titleWidth = panel.TitleContainer.TitleText:GetUnboundedStringWidth() + view.titleButtonsWidth + 2 * scaleWidth
        end
        local width = math.min(screenWidth, math.max(minimumWidth, titleWidth, contentWidth + 2 * sideInset))
        panel:SetWidth(width)
        top = DrawTowerRows(view, width - 2 * sideInset, top)
        for _, group in ipairs(groups) do
            local heading = headings[group]
            if heading then heading:Hide() end
            for _, timer in ipairs(list) do
                local section = timer.key == "score" and "score" or timer.side
                if section == group then
                    if heading and not heading:IsShown() then
                        if count > 0 or view.towers then top = top + sectionGap end
                        heading:SetPoint("TOPLEFT", panel, "TOPLEFT", sideInset, -top)
                        heading:Show()
                        top = top + math.max(19, math.ceil(heading:GetStringHeight()) + 4)
                    end
                    count = count + 1
                    local row = GetRow(view, count)
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

Draw = function(layoutChanged)
    if previewCount > 0 or dismissed or not ns.Enabled("battleTimers") then
        if live.panel then live.panel:Hide() end
        return
    end
    local now = GetTime()
    for i = #timers, 1, -1 do
        if timers[i].ends and timers[i].ends <= now then
            table.remove(timers, i)
            layoutChanged = true
        end
    end
    DrawView(live, timers, now, layoutChanged)
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

local function LayoutPreviews()
    local columns, gap = {}, 18
    for _, view in ipairs(previews) do
        if view.examples then
            DrawView(view, view.examples, 0, true)
            local column = columns[view.column] or {width = 0, height = 0, views = {}}
            columns[view.column] = column
            column.width = math.max(column.width, view.panel:GetWidth())
            column.height = column.height + view.panel:GetHeight() + gap
            column.views[#column.views + 1] = view
        end
    end
    local width, height = -gap, 0
    for i = 1, 3 do
        local column = columns[i]
        if column then
            width = width + column.width + gap
            height = math.max(height, column.height - gap)
        end
    end
    local screenWidth, screenHeight = UIParent:GetWidth(), UIParent:GetHeight()
    local scale = math.min(ScalePercent(ns.db.battleTimerScale) / 100,
        (screenWidth - 48) / width, (screenHeight - 56) / height)
    local x = (screenWidth / scale - width) / 2
    local top = (screenHeight / scale - height) / 2
    for i = 1, 3 do
        local column = columns[i]
        if column then
            local y = top
            for _, view in ipairs(column.views) do
                ApplyScale(view, scale)
                if not RestorePanelPosition(view) then
                    view.panel:ClearAllPoints()
                    view.panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, -y)
                end
                y = y + view.panel:GetHeight() + gap
            end
            x = x + column.width + gap
        end
    end
end

function ns.ShowBattleTimerPreview(battlegrounds)
    previewCount = #battlegrounds
    for i, battlefield in ipairs(battlegrounds) do
        local view = previews[i]
        if not view then
            view = {name = "RainonUIForeverBattleTimerPreview" .. i, title = battlefield.title,
                rows = {}, headings = {}}
            previews[i] = view
        end
        view.examples, view.column, view.towers = battlefield.timers, battlefield.column, battlefield.towers
    end
    Draw(true)
    LayoutPreviews()
end

function ns.RefreshBattleTimerLayout()
    if live.panel then
        ApplyScale(live)
        RestorePanelPosition(live)
    end
    if previewCount > 0 then
        LayoutPreviews()
    elseif live.panel and live.panel:IsShown() then
        Draw(true)
    end
end

UIParent:HookScript("OnSizeChanged", function()
    if previewCount > 0 then LayoutPreviews() end
end)

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
-- Horde-contested AreaPOI IDs in Forever. Their textures identify the matching Horde widget slot.
local arathiSoundNames = {
    [1613] = "Stables", [1618] = "Blacksmith", [1623] = "LumberMill", [1628] = "GoldMine", [1633] = "Farm",
}
local arathiSoundSlots, arathiHordeStates = {}, {}
local battleSoundFolder = "Interface\\AddOns\\RainonUI_Forever\\Media\\Sounds\\"

ns.BattleVoiceFactions = {
    {key = "Alliance", label = "Действия Альянса"},
    {key = "Horde", label = "Действия Орды"},
}
ns.BattleVoiceOptions = {
    attack = "Атака точки",
    pointCapture = "Захват точки",
    flagPickup = "Поднятие флага",
    flagCapture = "Сдача флага",
}
ns.BattleVoiceMaps = {
    {id = 529, label = "Низина Арати", events = {"attack", "pointCapture"}},
    {id = 2997, label = "Острова Чёрного Копья", events = {"attack", "pointCapture", "flagPickup", "flagCapture"}},
    {id = 489, label = "Ущелье Песни Войны", events = {"flagPickup", "flagCapture"}},
}
local voiceMaps = {}
for _, battlefield in ipairs(ns.BattleVoiceMaps) do voiceMaps[battlefield.id] = battlefield end

local voiceAvailability = {
    Alliance = {flagPickup = true, flagCapture = true},
    Horde = {attack = true, pointCapture = true, flagPickup = true, flagCapture = true},
}

local function VoiceProfile(create)
    local guid = UnitGUID("player")
    if not ns.db or not guid or (issecretvalue and issecretvalue(guid)) then return end
    local profiles = ns.db.battleVoiceProfiles
    if not profiles and create then
        profiles = {}
        ns.db.battleVoiceProfiles = profiles
    end
    if not profiles then return end
    if not profiles[guid] and create then profiles[guid] = {} end
    return profiles[guid]
end

function ns.BattleVoiceAvailable(side, event)
    return voiceAvailability[side] and voiceAvailability[side][event] == true
end

function ns.BattleVoiceEnabled(side, event, map)
    if event and not ns.BattleVoiceAvailable(side, event) then return false end
    local profile = VoiceProfile()
    local key = event or "enabled"
    local mapSettings = map and profile and profile.maps and profile.maps[map]
    local mapSide = mapSettings and mapSettings[side]
    local enabled = mapSide and mapSide[key]
    if enabled ~= nil then return enabled end
    local setting = profile and profile[side]
    enabled = setting and setting[key]
    if enabled ~= nil then return enabled end
    return event ~= nil or side == "Horde"
end

function ns.SetBattleVoiceEnabled(side, event, enabled, map)
    if event and not ns.BattleVoiceAvailable(side, event) then return end
    local profile = VoiceProfile(true)
    if not profile then return end
    if map then
        profile.maps = profile.maps or {}
        profile.maps[map] = profile.maps[map] or {}
        profile = profile.maps[map]
    end
    profile[side] = profile[side] or {}
    profile[side][event or "enabled"] = enabled
    local _, kind, _, _, _, _, _, activeMap = GetInstanceInfo()
    if kind == "pvp" and (not map or map == activeMap) then ns.SyncBattleTimers() end
end

local function HasVoiceForMap(map)
    local battlefield = voiceMaps[map]
    if not battlefield then return false end
    for _, faction in ipairs(ns.BattleVoiceFactions) do
        local side = faction.key
        if ns.BattleVoiceEnabled(side, nil, map) then
            for _, event in ipairs(battlefield.events) do
                if ns.BattleVoiceEnabled(side, event, map) then return true end
            end
        end
    end
    return false
end

local function MatchEngaged()
    return C_PvP and C_PvP.GetActiveMatchState and ns.Number(C_PvP.GetActiveMatchState()) == 3
end

local function CanPlayArathiSound()
    return MatchEngaged() and C_PvP.GetActiveMatchDuration
        and (ns.Number(C_PvP.GetActiveMatchDuration()) or 0) >= 20
end

local function PlayBattleSound(side, event, name)
    if ns.BattleVoiceEnabled(side, nil, instance) and ns.BattleVoiceEnabled(side, event, instance) then
        PlaySoundFile(battleSoundFolder .. name .. ".mp3", "Master")
    end
end

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
    local soundPoint = instance == 529 and arathiSoundNames[id]
    if soundPoint then
        local slot = arathiSlots[icon]
        if slot then arathiSoundSlots[slot] = soundPoint end
        if previous and changed and seconds and seconds > 0 and CanPlayArathiSound() then
            PlayBattleSound("Horde", "attack", "Arathi_Horde_Attack_" .. soundPoint)
        end
    end
end

local destroyedTowerSides, contestedTowerSides = {}, {}
for side, towers in pairs({
    alliance = {{1352, 1353, 1354}, {1355, 1356, 1357}, {1380, 1381, 1382}, {1389, 1390, 1391}},
    horde = {{1377, 1378, 1379}, {1405, 1406, 1407}, {1528, 1529, 1530}, {1362, 1363, 1364}},
}) do
    for _, ids in ipairs(towers) do
        destroyedTowerSides[ids[1]] = side
        contestedTowerSides[ids[2]], contestedTowerSides[ids[3]] = side, side
    end
end
local intactTowerSides = {[11] = "alliance", [10] = "horde"}
local destroyedTowers = {}

local function UpdateTowerCounts(standing)
    local lost = {alliance = 0, horde = 0}
    for _, side in pairs(destroyedTowers) do lost[side] = lost[side] + 1 end
    for _, side in ipairs(towerSides) do
        local remaining = towerLimit - lost[side]
        local visible = 0
        for _ in pairs(standing[side]) do visible = visible + 1 end
        if live.towers[side] ~= nil or remaining == 0 or visible == remaining then
            live.towers[side] = remaining
        end
    end
end

local function ReadObjectives()
    local map = C_Map.GetBestMapForUnit("player") or objectiveMaps[instance]
    if not map then return end
    local now = GetTime()
    local standing = live.towers and {alliance = {}, horde = {}}
    -- Updates can arrive before all map markers are visible. A partial list
    -- does not mean an objective was defended or that its countdown restarted.
    for _, id in ipairs(C_AreaPoiInfo.GetAreaPOIForMap(map) or {}) do
        local poi = C_AreaPoiInfo.GetAreaPOIInfo(map, id)
        local poiID = poi and poi.areaPoiID or id
        if standing and destroyedTowerSides[id] then destroyedTowers[id] = destroyedTowerSides[id] end
        if poi and poi.name and poi.textureIndex then
            if standing and not destroyedTowerSides[poiID] then
                local side = contestedTowerSides[poiID] or intactTowerSides[poi.textureIndex]
                if side then standing[side][poi.name] = true end
            end
            UpdateObjective(poi, poiID, now, captureSeconds[instance])
        end
    end
    if standing then UpdateTowerCounts(standing) end
    Draw(true)
end

-- Forever uses the same resource widget on Arathi and Darkspear. Only Arathi
-- has independent team clocks determined by the number of controlled bases.
local scoreWidget, arathiBaseWidget, darkspearBaseWidget = 7467, 1645, 7860
local darkspearHordeStates = {}
local darkspearSoundPoints = {
    [darkspearSlots.horde[8768]] = "Camp",
    [darkspearSlots.horde[8771]] = "Ruins",
    [darkspearSlots.horde[8772]] = "Tower",
    [darkspearSlots.horde[8773]] = "Cove",
}
local intervals = {12, 9, 6, 3, 1}
local projections = {}
local islandTick

local function ReadArathiCaptures(bases)
    if not bases or bases.shownState == 0 or not bases.rightIcons then return end
    local audible = CanPlayArathiSound()
    for slot, info in ipairs(bases.rightIcons) do
        local state = ns.Number(info.iconState)
        if state then
            local previous = arathiHordeStates[slot]
            arathiHordeStates[slot] = state
            local point = arathiSoundSlots[slot]
            -- A defended point can return directly to Horde control without a Horde attack.
            if audible and point and previous == 1 and state == 2 then
                PlayBattleSound("Horde", "pointCapture", "Arathi_Horde_Capture_" .. point)
            end
        end
    end
end

local function ReadDarkspearSounds()
    local bases = C_UIWidgetManager.GetDoubleStateIconRowVisualizationInfo(darkspearBaseWidget)
    if not bases or bases.shownState == 0 or not bases.rightIcons then return end
    local audible = MatchEngaged()
    for slot, point in pairs(darkspearSoundPoints) do
        local info = bases.rightIcons[slot]
        local state = info and ns.Number(info.iconState)
        if state then
            local previous = darkspearHordeStates[slot]
            darkspearHordeStates[slot] = state
            if audible and previous ~= nil then
                if state == 1 and previous ~= 1 then
                    PlayBattleSound("Horde", "attack", "Darkspear_Horde_Attack_" .. point)
                elseif state == 2 and previous == 1 then
                    PlayBattleSound("Horde", "pointCapture", "Darkspear_Horde_Capture_" .. point)
                end
            end
        end
    end
end

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
    local bases
    if instance == 529 then
        bases = C_UIWidgetManager.GetDoubleStateIconRowVisualizationInfo(arathiBaseWidget)
        ReadArathiCaptures(bases)
    end
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

local function ReadFlagAction(message)
    if type(message) ~= "string" or (issecretvalue and issecretvalue(message)) then return end
    message = message:gsub("[A-Z]", string.lower)
    if message:match("captured the [^!]*flag%f[%A]") or message:find("захватил флаг", 1, true)
        or message:find("захватила флаг", 1, true) then
        return "Capture"
    end
    if message:match("flag was picked up by ") or message:match("picked up the [^!]*flag%f[%A]")
        or message:find("has taken the flag", 1, true) or message:find("несет флаг", 1, true)
        or message:find("несёт флаг", 1, true) or message:find("взял флаг", 1, true)
        or message:find("взяла флаг", 1, true) or message:find("захватывает флаг", 1, true) then
        return "Pickup"
    end
end

local events = CreateFrame("Frame")
local function Stop()
    events:UnregisterAllEvents()
    wipe(timers)
    wipe(landmarks)
    wipe(projections)
    wipe(arathiSoundSlots)
    wipe(arathiHordeStates)
    wipe(darkspearHordeStates)
    wipe(destroyedTowers)
    live.towers = nil
    islandTick = nil
    for _, view in ipairs(previews) do
        if view.panel then view.panel:Hide() end
        view.examples = nil
    end
    previewCount = 0
    instance, dismissed = nil, nil
    Draw()
end

function ns.SyncBattleTimers()
    local _, kind, _, _, _, _, _, map = GetInstanceInfo()
    if kind ~= "pvp" or not ns.IsForeverBattlefield(map) or not ns.Enabled("pvp")
        or not (ns.Enabled("battleTimers") or HasVoiceForMap(map)) then
        Stop()
        return
    end
    if C_PvP and C_PvP.IsMatchComplete and C_PvP.IsMatchComplete() then Stop(); return end
    if instance == map then
        Draw(true)
        return
    end
    Stop()
    instance = map
    if map == 30 then live.towers = {} end
    if captureSeconds[map] then
        events:RegisterEvent("AREA_POIS_UPDATED")
        ReadObjectives()
    end
    if map == 529 or map == 2997 then
        events:RegisterEvent("UPDATE_UI_WIDGET")
        events:RegisterEvent("UPDATE_ALL_UI_WIDGETS")
        ReadScore()
        if map == 2997 then ReadDarkspearSounds() end
    end
    if map == 489 or map == 2997 then
        events:RegisterEvent("CHAT_MSG_BG_SYSTEM_ALLIANCE")
        events:RegisterEvent("CHAT_MSG_BG_SYSTEM_HORDE")
    end
end

events:SetScript("OnEvent", function(_, event, arg)
    if event == "AREA_POIS_UPDATED" then
        ReadObjectives()
    elseif event == "UPDATE_ALL_UI_WIDGETS" or (event == "UPDATE_UI_WIDGET" and arg) then
        local widgetID = arg and arg.widgetID
        if event == "UPDATE_ALL_UI_WIDGETS" or widgetID == scoreWidget
            or (instance == 529 and widgetID == arathiBaseWidget) then
            ReadScore()
        end
        if instance == 2997 and (event == "UPDATE_ALL_UI_WIDGETS" or widgetID == darkspearBaseWidget) then
            ReadDarkspearSounds()
        end
    elseif (instance == 489 or instance == 2997)
        and (event == "CHAT_MSG_BG_SYSTEM_ALLIANCE" or event == "CHAT_MSG_BG_SYSTEM_HORDE") then
        local action = ReadFlagAction(arg)
        if action then
            local faction = event == "CHAT_MSG_BG_SYSTEM_ALLIANCE" and "Alliance" or "Horde"
            local eventKey = action == "Capture" and "flagCapture" or "flagPickup"
            PlayBattleSound(faction, eventKey, "Flag_" .. faction .. "_" .. action)
            if action == "Capture" then
                SetTimer("flag", "Возвращение флагов", instance == 2997 and 23 or 12)
            end
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
ns.AddSetting("battleTimers", "Таймеры поля боя", ns.SyncBattleTimers, false, "pvp", {
    icon = 136106, tooltip = "Показывает отсчёт до старта и таймеры целей поля боя. Окно можно перетащить мышью. Стрелки в окне меняют масштаб.",
})
