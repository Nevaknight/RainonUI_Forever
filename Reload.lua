local _, ns = ...
local button

local function AddButtonAboveMenu()
    if InCombatLockdown() then return end
    button:SetShown(ns.Enabled("reload") and GameMenuFrame:IsShown())
end

ns.AddSetting("reload", "Кнопка перезагрузки в меню игры", function()
    if button then AddButtonAboveMenu() end
end)

ns.On("PLAYER_LOGIN", function()
    if not GameMenuFrame then return end
    button = CreateFrame("Button", nil, GameMenuFrame, "MainMenuFrameButtonTemplate")
    button:SetSize(200, 35)
    button:SetPoint("BOTTOM", GameMenuFrame, "TOP", 0, 12)
    button:SetText("Перезагрузить интерфейс")
    button:SetScript("OnClick", ReloadUI)
    button:Hide()
    GameMenuFrame:HookScript("OnShow", AddButtonAboveMenu)
end)
ns.On("PLAYER_REGEN_DISABLED", function() if button then button:Hide() end end)
ns.On("PLAYER_REGEN_ENABLED", function() if button then AddButtonAboveMenu() end end)
