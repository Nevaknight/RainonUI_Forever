local _, ns = ...
local feature = "updateNotice"

-- Give each new announcement its own ID and replace its sections here.
local announcementID = "0.2.0"
local sections = {
    { title = "Общие", text = "Очень много всего добавил, наслаждайтесь кому будет полезно, если будут ошибки пишите. Должно работать на ру и еу клиенте без проблем." },
}
local window, checked

ns.AddSetting(feature, "Новые функции", function()
    if window and not ns.Enabled(feature) then window:Hide() end
end)

ns.On("PLAYER_ENTERING_WORLD", function()
    if checked then return end
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
        if ns.Enabled(feature) then
            local visible = {}
            for _, section in ipairs(sections) do
                if not section.localLoot or ns.DungeonLootRanks then visible[#visible + 1] = section end
            end
            window = ns.BuildUpdateNotice(visible)
            window:Show()
        end
        seen[announcementID] = true
    end)
end)
