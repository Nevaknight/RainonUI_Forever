local _, ns = ...
local soundFolder = "Interface\\AddOns\\RainonUI_Forever\\Media\\Sounds\\"

ns.FlightArrivalSounds = {
    { "alice", "Алиса: Внимание!", "RainonUI_Attention.ogg" },
    { "alexstrasza", "Алекстраза", "VO_100_Alexstrasza_the_Life-Binder_14_F.ogg" },
}

function ns.GetFlightArrivalSound()
    local selected = ns.db.flightArrivalSoundChoice
    for _, sound in ipairs(ns.FlightArrivalSounds) do
        if sound[1] == selected then return sound end
    end
    return ns.FlightArrivalSounds[2]
end

function ns.PlayFlightArrivalSound()
    PlaySoundFile(soundFolder .. ns.GetFlightArrivalSound()[3], "Master")
end

local ticker, onTaxi
local function StopWatching()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
    onTaxi = nil
end

local function CheckFlight()
    if UnitOnTaxi("player") then
        onTaxi = true
    elseif onTaxi then
        StopWatching()
        if ns.Enabled("flightArrivalSound") then ns.PlayFlightArrivalSound() end
    end
end

local function WatchFlight()
    if not ns.Enabled("flightArrivalSound") then return end
    if ticker then
        CheckFlight()
    else
        onTaxi = UnitOnTaxi("player")
        ticker = C_Timer.NewTicker(0.25, CheckFlight)
    end
end

local function Apply()
    StopWatching()
    if UnitOnTaxi("player") then WatchFlight() end
end

ns.AddSetting("flightArrivalSound", "Звук прилёта", Apply, false, nil, {
    icon = 132915, detail = "После перелёта у распорядителя полётов",
})
ns.On("PLAYER_ENTERING_WORLD", function()
    if UnitOnTaxi("player") then WatchFlight() end
end)
ns.On("PLAYER_LEAVING_WORLD", StopWatching)
ns.On("PLAYER_CONTROL_LOST", WatchFlight)
ns.On("PLAYER_CONTROL_GAINED", function()
    if not ticker then return end
    CheckFlight()
    if not onTaxi then StopWatching() end
end)
