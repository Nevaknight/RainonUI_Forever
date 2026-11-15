local _, ns = ...

local function AuctionAPI()
    return Auctionator and Auctionator.API and Auctionator.API.v1
end

local watchingScans
local function WatchScans()
    if watchingScans or not ns.db or not (Auctionator and Auctionator.EventBus) then return end
    local scanEvents = {}
    local browse = Auctionator.IncrementalScan and Auctionator.IncrementalScan.Events
    local full = Auctionator.FullScan and Auctionator.FullScan.Events
    if browse and browse.ScanComplete then scanEvents[#scanEvents + 1] = browse.ScanComplete end
    if full and full.ScanComplete then scanEvents[#scanEvents + 1] = full.ScanComplete end
    if #scanEvents == 0 then return end

    Auctionator.EventBus:Register({
        ReceiveEvent = function()
            local _, realm = ns.CharacterIdentity()
            if not realm then return end
            ns.db.crateAuctionScans = ns.db.crateAuctionScans or {}
            ns.db.crateAuctionScans[realm] = time()
        end,
    }, scanEvents)
    watchingScans = true
end

local function ScanLabel()
    local label = "Цены аукциона: "
    local _, realm = ns.CharacterIdentity()
    local recorded = ns.db.crateAuctionScans and ns.Number(ns.db.crateAuctionScans[realm])
    if recorded and recorded > 0 then
        return label .. date("%d.%m.%Y %H:%M", recorded)
    end

    local saved = AUCTIONATOR_SAVEDVARS
    local browse = saved and ns.Number(saved.TimeOfLastBrowseScan) or 0
    local full = saved and ns.Number(saved.TimeOfLastReplicateScan) or 0
    local started = math.max(browse, full)
    if started > 0 then
        return label .. date("%d.%m.%Y %H:%M", started)
    end
    return label .. "нет данных"
end

local function CheapestBundle(bundles, api)
    if not (api and api.GetAuctionPriceByItemID) then return end
    local best, total
    for _, bundle in ipairs(bundles) do
        local ok, unitPrice = pcall(api.GetAuctionPriceByItemID, ns.ADDON, bundle.id)
        unitPrice = ok and ns.Number(unitPrice)
        if unitPrice and unitPrice > 0 then
            local cost = unitPrice * bundle.quantity
            if not total or cost < total then best, total = bundle, cost end
        end
    end
    return best, total
end

local function AddCrateLines(tooltip, id)
    local bundles = id and ns.Crates[id]
    if not bundles or not ns.Enabled("crates") then return end

    local api = AuctionAPI()
    local best, total = CheapestBundle(bundles, api)
    tooltip:AddLine("RainonUI:", 1, 0.82, 0)
    if best then
        local texture = ns.Number(C_Item.GetItemIconByID(best.id)) or 134400
        local item = ("|T%d:16:16:0:0|t %s × %d"):format(texture, best.name, best.quantity)
        tooltip:AddDoubleLine(item, C_CurrencyInfo.GetCoinTextureString(math.floor(total)), 1, 1, 1, 1, 1, 1)
        tooltip:AddLine("     " .. best.nameEn, 0.55, 0.55, 0.55, true)
    else
        tooltip:AddLine("Нет цены. Обнови аукцион.", 1, 1, 1)
    end

    local scan = ScanLabel()
    if best and api.GetAuctionAgeByItemID then
        local ok, age = pcall(api.GetAuctionAgeByItemID, ns.ADDON, best.id)
        age = ok and ns.Number(age)
        if age and age > 0 then scan = scan .. (" · цена %d дн. назад"):format(age) end
    end
    tooltip:AddLine(scan, 0.75, 0.75, 0.75, true)
end

ns.AddSetting("crates", "Стоимость наполнения ящиков", nil, nil, "professions")
ns.On("ADDON_LOADED", function(name)
    if name == "Auctionator" then WatchScans() end
end)
ns.On("PLAYER_LOGIN", function()
    WatchScans()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tip, data)
            AddCrateLines(tip, data and ns.Number(data.id))
        end)
    else
        for _, tooltip in ipairs({ GameTooltip, ItemRefTooltip }) do
            if tooltip:HasScript("OnTooltipSetItem") then
                tooltip:HookScript("OnTooltipSetItem", function(tip)
                    local _, link = tip:GetItem()
                    AddCrateLines(tip, link and tonumber(link:match("item:(%d+)")))
                end)
            end
        end
    end
end)
