local addon, ns = ...
ns.ADDON = addon

function ns.CharacterIdentity()
    local name, surname = UnitName("player")
    if not (RegionalUniqueNamesEnabled and RegionalUniqueNamesEnabled()) then return name, GetRealmName() end
    if surname and surname ~= "" then name = name .. " " .. surname end
    local isPvP = C_GameRules.IsGameRuleActive(Enum.GameRule.PvPRuleset)
    local isRP = C_GameRules.IsGameRuleActive(Enum.GameRule.RPRuleset)
    local isHC = C_GameRules.IsGameRuleActive(Enum.GameRule.HardcoreRuleset)
    return name, (isPvP and (isRP and "RPPvP" or "PvP")) or (isRP and "RP") or (isHC and "HC") or "PvE"
end

local events = CreateFrame("Frame")
local handlers = {}
function ns.On(event, callback)
    if not handlers[event] then
        handlers[event] = {}
        events:RegisterEvent(event)
    end
    table.insert(handlers[event], callback)
end
events:SetScript("OnEvent", function(_, event, ...)
    for _, callback in ipairs(handlers[event]) do callback(...) end
end)

function ns.Number(value)
    if issecretvalue and issecretvalue(value) then return nil end
    return tonumber(value)
end

ns.CYRILLIC_FONT = "Fonts\\FRIZQT___CYR.TTF"

local tooltipFonts = setmetatable({}, { __mode = "k" })

local function RestoreTooltipFonts(tooltip)
    local fonts = tooltipFonts[tooltip]
    for line, font in pairs(fonts) do
        line:SetFont(unpack(font))
        fonts[line] = nil
    end
end

function ns.UseCyrillicTooltipFont(tooltip, referenceFont)
    local line = _G[tooltip:GetName() .. "TextLeft" .. tooltip:NumLines()]
    if not line then return end
    local fonts = tooltipFonts[tooltip]
    if not fonts then
        fonts = {}
        tooltipFonts[tooltip] = fonts
        tooltip:HookScript("OnTooltipCleared", RestoreTooltipFonts)
    end
    local font, size, flags = line:GetFont()
    fonts[line] = fonts[line] or { font, size, flags }
    if referenceFont then font, size, flags = referenceFont:GetFont() end
    line:SetFont(ns.CYRILLIC_FONT, size, flags)
end

local settings = {}
local extraOptions = {}
function ns.AddSetting(key, label, changed, optIn, tab, style)
    settings[#settings + 1] = { key = key, label = label, changed = changed, optIn = optIn, tab = tab, style = style }
end

function ns.AddOptions(builder)
    extraOptions[#extraOptions + 1] = builder
end

function ns.Enabled(key)
    return ns.db and ns.db.features[key] == true
end

local panel, minimapButton
local iconPath = "Interface\\AddOns\\RainonUI_Forever\\Media\\logo"

function ns.PrintCombatMessage(message, alwaysShow)
    if not DEFAULT_CHAT_FRAME then return end
    local _, instanceType = IsInInstance()
    -- Like Ellesmere, keep these combat notices out of chat in raids and PvP instances.
    if not alwaysShow and (instanceType == "raid" or instanceType == "pvp" or instanceType == "arena") then return end
    DEFAULT_CHAT_FRAME:AddMessage("|cffff6060[RainonUI]|r " .. message)
end

function ns.ToggleOptions(tab)
    if not ns.db then return end
    if InCombatLockdown() then
        ns.PrintCombatMessage("Настройки можно открыть после боя.")
        return
    end
    panel = panel or ns.BuildOptions(settings, extraOptions)
    if tab then
        panel:SelectTab(tab)
        panel:Show()
    else
        panel:SetShown(not panel:IsShown())
    end
end

ns.On("PLAYER_REGEN_DISABLED", function()
    if panel and panel:IsShown() then
        panel:Hide()
        ns.PrintCombatMessage("Настройки закрыты: начался бой.")
    end
end)

function ns.RefreshOptions()
    if panel and panel:IsShown() then panel:RefreshSettings() end
end

local function AddMinimapBinding(binding, description)
    GameTooltip:AddDoubleLine("|cff01b0e3" .. binding .. "|r", "|cfffbfdfe" .. description .. "|r")
end

local function UpdateMinimapButton()
    if minimapButton then minimapButton:SetShown(ns.Enabled("minimap")) end
end

ns.AddSetting("minimap", "Иконка у миникарты", UpdateMinimapButton)

local function CreateMinimapButton()
    if not Minimap then return end

    local button = CreateFrame("Button", "RainonUIForeverMinimapButton", Minimap)
    minimapButton = button
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(20, 20)
    background:SetPoint("TOPLEFT", 7, -5)
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", 7, -5)
    icon:SetTexture(iconPath)

    local ring = button:CreateTexture(nil, "OVERLAY")
    ring:SetSize(53, 53)
    ring:SetPoint("TOPLEFT")
    ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    local function Place()
        local angle = math.rad(ns.Number(ns.db.minimapAngle) or 205)
        local x, y = math.cos(angle), math.sin(angle)
        if GetMinimapShape and GetMinimapShape() == "SQUARE" then
            local edge = math.max(math.abs(x), math.abs(y))
            x, y = x / edge, y / edge
        end
        button:ClearAllPoints()
        button:SetPoint("CENTER", Minimap, "CENTER", x * (Minimap:GetWidth() / 2 + 5), y * (Minimap:GetHeight() / 2 + 5))
    end

    local function FollowCursor()
        local x, y = Minimap:GetCenter()
        local scale = Minimap:GetEffectiveScale()
        if not x or not scale or scale <= 0 then return end
        local cursorX, cursorY = GetCursorPosition()
        ns.db.minimapAngle = math.deg(math.atan2(cursorY / scale - y, cursorX / scale - x)) % 360
        Place()
    end

    button:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "LeftButton" then
            if InCombatLockdown() then
                if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
                ns.PrintCombatMessage("Сначала закончи бой.", true)
                return
            end
            if ns.ToggleDungeonLootCatalog and ns.Enabled("dungeonLootCatalog") and IsShiftKeyDown() then
                if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
                ns.ToggleDungeonLootCatalog()
            elseif ns.OpenBattleJournal and IsAltKeyDown() then
                if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
                if ns.Enabled("pvp") then ns.OpenBattleJournal() end
            else
                ns.ToggleOptions()
            end
            return
        end
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
        if ns.ItemNotesTab and ns.Enabled("itemNotes") and IsShiftKeyDown() then
            ns.ToggleOptions("itemNotes")
        elseif ns.OpenLootTests and IsAltKeyDown() then
            ns.OpenLootTests()
        elseif ns.OpenCurrentDungeonLoot then
            ns.OpenCurrentDungeonLoot()
        end
    end)
    button:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        self:SetScript("OnUpdate", FollowCursor)
    end)
    local function StopDragging(self) self:SetScript("OnUpdate", nil) end
    button:SetScript("OnDragStop", StopDragging)
    button:SetScript("OnHide", StopDragging)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetText("RainonUI — Forever")
        AddMinimapBinding("ЛКМ", "Открыть настройки")
        if ns.OpenCurrentDungeonLoot then AddMinimapBinding("ПКМ", "Добыча текущего подземелья") end
        if ns.ItemNotesTab and ns.Enabled("itemNotes") then
            AddMinimapBinding("Shift + ПКМ", ns.ItemNotesTab.title)
        end
        if ns.OpenBattleJournal and ns.Enabled("pvp") then
            AddMinimapBinding("Alt + ЛКМ", "Журнал полей боя")
        end
        if ns.OpenLootTests then AddMinimapBinding("Alt + ПКМ", "Тестовые окна") end
        if ns.ToggleDungeonLootCatalog and ns.Enabled("dungeonLootCatalog") then
            AddMinimapBinding("Shift + ЛКМ", "Добыча всех подземелий")
        end
        AddMinimapBinding("Перетаскивание", "Переместить значок")
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Minimap:HookScript("OnSizeChanged", Place)
    Place()
    UpdateMinimapButton()
end

ns.On("ADDON_LOADED", function(name)
    if name ~= addon then return end
    ns.isNewInstall = RainonUIForeverDB == nil
    RainonUIForeverDB = RainonUIForeverDB or {}
    ns.db = RainonUIForeverDB
    ns.db.features = ns.db.features or {}
    ns.db.rest = ns.db.rest or {}
    ns.db.restCharacters = ns.db.restCharacters or {}
    for _, option in ipairs(settings) do
        if ns.db.features[option.key] == nil then
            ns.db.features[option.key] = not option.optIn
        end
    end
end)

ns.On("PLAYER_LOGIN", CreateMinimapButton)

SLASH_RAINONUIFOREVER1 = "/rsf"
SLASH_RAINONUIFOREVER2 = "/rainon"
SlashCmdList.RAINONUIFOREVER = function(msg)
    ns.ToggleOptions(msg == "rest" and "characters" or nil)
end
