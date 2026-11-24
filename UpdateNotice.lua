local _, ns = ...
local feature = "updateNotice"

-- Use the release version as the ID and leave sections empty for a release without news.
local announcementID = "0.2.0"
local sections = {
    { title = "Общие", text = "Очень много всего добавил, наслаждайтесь кому будет полезно, если будут ошибки пишите. Должно работать на ру и еу клиенте без проблем." },
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

function ns.ShowUpdateNotice()
    if not window then
        local visible = VisibleSections()
        if #visible == 0 then return false end
        window = ns.BuildUpdateNotice(visible)
    end
    window:Show()
    return true
end

ns.AddSetting(feature, "Новые функции", function()
    if window and not ns.Enabled(feature) then window:Hide() end
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
