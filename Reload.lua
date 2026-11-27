local _, ns = ...
local button

local function InsertReloadButton(menu)
    if InCombatLockdown() then return end
    local first = menu.buttons and menu.buttons[1]
    if not menu:IsShown() or not ns.Enabled("reload") or not first or not first:GetTop() then
        button:Hide()
        return
    end

    local width, height = first:GetSize()
    local extraHeight = height + 12
    -- As in Retail, insert a row in the slot Blizzard just laid out first.
    for item in menu.buttonPool:EnumerateActive() do
        local anchor, target, targetPoint, offsetX, offsetY = item:GetPoint(1)
        if anchor and (not target or target == menu) then
            item:ClearAllPoints()
            item:SetPoint(anchor, menu, targetPoint, offsetX, offsetY - extraHeight)
        end
    end

    menu:SetHeight(menu:GetHeight() + extraHeight)

    -- Position against UIParent so the secure button does not protect the Esc menu itself.
    button:SetScale(first:GetEffectiveScale() / UIParent:GetEffectiveScale())
    button:SetSize(width, height)
    button:ClearAllPoints()
    button:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", first:GetLeft(), first:GetTop() + 12)
    button:SetAttribute("statehidden", nil)
    button:Show()
end

local function RefreshMenu()
    if button and GameMenuFrame:IsShown() and not InCombatLockdown() then
        GameMenuFrame:Layout()
    end
end

ns.AddSetting("reload", "Кнопка перезагрузки в меню игры", RefreshMenu)

local function SetupButton()
    local menu = GameMenuFrame
    if button or InCombatLockdown() or not (menu and menu.Layout and menu.buttonPool) then return end
    button = CreateFrame("Button", "RainonUIForeverReloadMenuButton", UIParent,
        "MainMenuFrameButtonTemplate,SecureActionButtonTemplate")
    -- GameMenuFrame raises itself within DIALOG when opened. Keep the click above it.
    button:SetFrameStrata("FULLSCREEN_DIALOG")
    button:Enable()
    button:EnableMouse(true)
    button:SetText("Перезагрузить UI")
    ns.ApplyUIFont(button:GetFontString())
    button:SetAttribute("type", "macro")
    button:SetAttribute("macrotext", "/reload")
    button:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
    button:Hide()
    RegisterStateDriver(button, "visibility", "[combat] hide")
    menu:HookScript("OnHide", function()
        if not InCombatLockdown() then button:Hide() end
    end)
    hooksecurefunc(menu, "Layout", InsertReloadButton)
end

local function RefreshAfterLoginOrCombat()
    SetupButton()
    RefreshMenu()
end

ns.On("PLAYER_LOGIN", RefreshAfterLoginOrCombat)
ns.On("PLAYER_REGEN_ENABLED", RefreshAfterLoginOrCombat)
