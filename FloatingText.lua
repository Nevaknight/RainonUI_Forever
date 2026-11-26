local _, ns = ...

local worldTextScale = "WorldTextScale_v2"
local hiddenWorldTextScale = 1000
local xpVisibilityPending

local function ApplyXPVisibility()
    local hide = ns.Enabled("hideFloatingXP")
    local previousScale = ns.db.worldTextScaleBeforeXP
    if not hide and not previousScale and not ns.db.honorTextBeforeXP then return end
    if InCombatLockdown() then
        xpVisibilityPending = true
        return
    end

    local honorCVar = "floatingCombatTextHonorGains_v2"
    local honor = ns.Number(C_CVar.GetCVar(honorCVar))
    local previousHonor = ns.db.honorTextBeforeXP
    if hide and honor and honor ~= 0 then
        if C_CVar.SetCVar(honorCVar, "0") then ns.db.honorTextBeforeXP = previousHonor or honor end
    elseif not hide and previousHonor and honor
        and (honor ~= 0 or C_CVar.SetCVar(honorCVar, tostring(previousHonor))) then
        ns.db.honorTextBeforeXP = nil
    end

    local current = C_CVar.GetCVar(worldTextScale)
    local scale = ns.Number(current)
    if not scale then return end
    if hide then
        -- Forever draws XP using the same world-text scale as other native popups.
        if scale ~= hiddenWorldTextScale and C_CVar.SetCVar(worldTextScale, tostring(hiddenWorldTextScale)) then
            ns.db.worldTextScaleBeforeXP = previousScale or current
        end
    elseif scale ~= hiddenWorldTextScale or C_CVar.SetCVar(worldTextScale, previousScale) then
        ns.db.worldTextScaleBeforeXP = nil
    end
end

ns.AddSetting("hideFloatingXP", "Скрыть опыт и почетные победы", ApplyXPVisibility, true, "general", {
    icon = 134944,
    wrapTitle = true,
    tooltip = "Скрывает всплывающий опыт и честь за почётные победы. Использует общий масштаб игрового текста. "
        .. "Может скрыть и другие штатные всплывающие надписи.",
})
ns.On("PLAYER_LOGIN", ApplyXPVisibility)
ns.On("PLAYER_REGEN_ENABLED", function()
    if not xpVisibilityPending then return end
    xpVisibilityPending = nil
    ApplyXPVisibility()
end)
