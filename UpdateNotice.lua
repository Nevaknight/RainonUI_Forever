local _, ns = ...
local feature = "updateNotice"

-- Use the release version as the ID and leave sections empty for a release without news.
local announcementID = "0.6.0"
local sections = {
    { title = "Озвучка полей боя", text = "По умолчанию звучат действия Орды. Выбрать события для каждого поля боя можно в PvP → Озвучка → Выбрать звуки." },
    { title = "Укрепления Альтерака", text = "Таймеры показывают оставшиеся башни Орды и бункеры Альянса. Окно запоминает своё положение между входами в игру." },
    { title = "Окно разрола", text = "Броски игроков, выбравших «Нужно», идут от большего к меньшему. На полях боя работают штатные броски игры." },
}
local window, checked
local function VisibleSections()
    local visible = {}
    for _, section in ipairs(sections) do
        if type(section.text) == "string" and section.text:find("%S")
            and (not section.localLoot or ns.DungeonLootRanks) then
            visible[#visible + 1] = section
        end
    end
    return visible
end

function ns.ShowUpdateNotice(preview)
    local visible = VisibleSections()
    local hasNews = #visible > 0
    if not hasNews and not preview then return false end
    window = window or ns.BuildUpdateNotice(visible, feature)
    window:RefreshSetting()
    window:Show()
    return hasNews
end

ns.AddSetting(feature, "Новые функции", function()
    if window then window:RefreshSetting() end
end)

ns.On("PLAYER_ENTERING_WORLD", function()
    if checked or #VisibleSections() == 0 then return end
    checked = true
    local seen = ns.db.seenUpdateNotices
    if type(seen) ~= "table" then
        seen = {}
        ns.db.seenUpdateNotices = seen
    end
    if seen[announcementID] then return end
    if ns.isNewInstall or not ns.Enabled(feature) then
        seen[announcementID] = true
        return
    end

    C_Timer.After(2, function()
        if ns.Enabled(feature) then ns.ShowUpdateNotice() end
        seen[announcementID] = true
    end)
end)
