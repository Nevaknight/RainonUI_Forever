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

local settings = {}
local extraOptions = {}
function ns.AddSetting(key, label, changed, optIn, tab)
    settings[#settings + 1] = { key = key, label = label, changed = changed, optIn = optIn, tab = tab }
end

function ns.AddOptions(builder)
    extraOptions[#extraOptions + 1] = builder
end

function ns.Enabled(key)
    return ns.db and ns.db.features[key] == true
end

local panel, minimapButton
local iconPath = "Interface\\AddOns\\RainonUI_Forever\\Media\\logo"

function ns.ToggleOptions(tab)
    if not ns.db then return end
    panel = panel or ns.BuildOptions(settings, extraOptions)
    if tab then
        panel:SelectTab(tab)
        panel:Show()
    else
        panel:SetShown(not panel:IsShown())
    end
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
    button:RegisterForClicks("LeftButtonUp")
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

    button:SetScript("OnClick", function() ns.ToggleOptions() end)
    button:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        self:SetScript("OnUpdate", FollowCursor)
    end)
    local function StopDragging(self) self:SetScript("OnUpdate", nil) end
    button:SetScript("OnDragStop", StopDragging)
    button:SetScript("OnHide", StopDragging)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("RainonUI — Forever")
        GameTooltip:AddLine("ЛКМ — открыть настройки.", 1, 1, 1)
        GameTooltip:AddLine("Перетащи кнопку, чтобы изменить её положение.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Minimap:HookScript("OnSizeChanged", Place)
    Place()
    UpdateMinimapButton()
end

ns.On("ADDON_LOADED", function(name)
    if name ~= addon then return end
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
SlashCmdList.RAINONUIFOREVER = function(msg)
    ns.ToggleOptions(msg == "rest" and "characters" or nil)
end
