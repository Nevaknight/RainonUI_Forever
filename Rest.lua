local _, ns = ...
local key
local window
local BASE_CAP = 1.5
local BASE_RATE = 0.05 / (8 * 3600)
local LEGACY = 1.2

function ns.ProjectRest(snapshot, now)
    if not snapshot or snapshot.maxXP <= 0 then return end
    local factor = snapshot.wellRested and LEGACY or 1
    local cap = math.max(snapshot.xp, math.floor(snapshot.maxXP * BASE_CAP * factor))
    local perSecond = snapshot.maxXP * BASE_RATE * factor * (snapshot.resting and 1 or 0.25)
    local xp = math.min(cap, snapshot.xp + math.max(0, now - snapshot.at) * perSecond)
    return math.floor(xp), cap, math.max(0, (cap - xp) / perSecond)
end

local function Update()
    if not ns.db then return end
    key = UnitGUID("player")
    if not ns.Enabled("rest") or not key then return end
    local maxXP = ns.Number(UnitXPMax("player"))
    local raw = GetXPExhaustion()
    if issecretvalue and issecretvalue(raw) then return end
    local xp = ns.Number(raw)
    local maxLevel = (GetMaxPlayerLevel and GetMaxPlayerLevel()) or 60
    if not maxXP or maxXP <= 0 or (maxLevel and UnitLevel("player") >= maxLevel) then
        ns.db.rest[key] = nil
        return
    end
    local previous = ns.db.rest[key]
    local name, realm = ns.CharacterIdentity()
    local now = GetServerTime()
    local reading = {
        name = name,
        realm = realm,
        level = UnitLevel("player"),
        maxXP = maxXP,
        xp = xp or 0,
        at = now,
        resting = IsResting() and true or false,
        wellRested = ns.Enabled("wellRested"),
        samples = previous and previous.samples or {},
    }
    local last = reading.samples[#reading.samples]
    if not last or last.xp ~= reading.xp or last.level ~= reading.level or last.resting ~= reading.resting
        or last.wellRested ~= reading.wellRested or now - last.at >= 3600 then
        reading.samples[#reading.samples + 1] = {
            xp = reading.xp, maxXP = maxXP, at = now, level = reading.level,
            resting = reading.resting, wellRested = reading.wellRested,
        }
        if #reading.samples > 48 then table.remove(reading.samples, 1) end
    end
    ns.db.rest[key] = reading
end

local function UpdateWindow()
    if not window or not window:IsShown() then return end
    if not ns.Enabled("rest") then window:Hide(); return end
    local now = GetServerTime()
    local lines = {}
    for guid, character in pairs(ns.db.rest) do
        local xp, cap, seconds = ns.ProjectRest(character, guid == key and character.at or now)
        if xp and cap > 0 then
            local time = seconds > 0 and (" · до максимума ≈ %d ч."):format(math.ceil(seconds / 3600)) or ""
            lines[#lines + 1] = ("%s · %d / %d опыта%s"):format(character.name, xp, cap, time)
        end
    end
    table.sort(lines)
    window.rows:SetText(#lines > 0 and table.concat(lines, "\n") or "Замеров отдыха пока нет.")
    window:SetHeight(math.max(100, 50 + window.rows:GetStringHeight()))
end

function ns.ShowRest()
    if not ns.Enabled("rest") then return end
    if not window then
        window = CreateFrame("Frame", "RainonUIForeverRest", UIParent, "ButtonFrameTemplate")
        if ButtonFrameTemplate_HidePortrait then ButtonFrameTemplate_HidePortrait(window) end
        if ButtonFrameTemplate_HideButtonBar then ButtonFrameTemplate_HideButtonBar(window) end
        if window.Inset then window.Inset:Hide() end
        window:SetTitle("Отдых")
        window:SetWidth(440)
        window:SetPoint("CENTER")
        window:SetClampedToScreen(true)
        window.rows = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        window.rows:SetPoint("TOPLEFT", 12, -36)
        window.rows:SetPoint("TOPRIGHT", -12, -36)
        window.rows:SetJustifyH("LEFT")
        tinsert(UISpecialFrames, window:GetName())
    end
    Update()
    window:Show()
    UpdateWindow()
end

local function Refresh()
    Update()
    UpdateWindow()
end
ns.AddSetting("rest", "Отслеживать отдых", Refresh)
ns.AddSetting("wellRested", "Хороший отдых · 5/5 очков наследия", Refresh, true)
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_UPDATE_RESTING", "UPDATE_EXHAUSTION", "PLAYER_XP_UPDATE", "PLAYER_LOGOUT" }) do
    ns.On(event, Refresh)
end
