local _, ns = ...
local feature = "confirmBoESale"
local popup = "RAINONUI_FOREVER_CONFIRM_BOE_SALE"
local bindOnEquip = Enum.ItemBind.OnEquip
local watcher = CreateFrame("Frame")
local merchantOverlay, baganatorEvents
local watching, refreshQueued, refreshID = false, false, 0
local overlays = {}
local passThrough = { "LeftButton", "MiddleButton" }
for index = 4, 31 do passThrough[#passThrough + 1] = "Button" .. index end

local function CanSell()
    return ns.Enabled(feature) and MerchantFrame and MerchantFrame:IsShown() and not InCombatLockdown()
        and not InRepairMode() and not SpellIsTargeting()
end

local function GetBoE(bag, slot)
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if not info or info.isBound or info.hasNoValue or not info.hyperlink then return end
    local _, _, _, _, _, _, _, _, _, _, _, _, _, bindType = C_Item.GetItemInfo(info.hyperlink)
    if bindType == bindOnEquip then return info end
    local _, _, _, equipSlot = C_Item.GetItemInfoInstant(info.hyperlink)
    if (bindType == nil or (equipSlot and equipSlot ~= "")) and ITEM_BIND_ON_EQUIP then
        local tooltip = C_TooltipInfo.GetBagItem(bag, slot)
        for _, line in ipairs(tooltip and tooltip.lines or {}) do
            if line.leftText == ITEM_BIND_ON_EQUIP then return info end
        end
    end
end

local function ItemGUID(bag, slot)
    return C_Item.GetItemGUID(ItemLocation:CreateFromBagAndSlot(bag, slot))
end

local function ReadBagItem(bag, slot)
    if not bag or not slot then return end
    local info = GetBoE(bag, slot)
    if not info then return end
    return info, ItemGUID(bag, slot)
end

local function GetCursorSlot()
    if not CursorHasItem() then return end
    local location = C_Cursor.GetCursorItem()
    if location and location:IsBagAndSlot() then return location:GetBagAndSlot() end
end

local function CursorMatches(sale)
    local bag, slot = GetCursorSlot()
    return bag == sale.bag and slot == sale.slot and ItemGUID(bag, slot) == sale.guid
end

StaticPopupDialogs[popup] = {
    text = "Продать торговцу %s? Предмет станет персональным.",
    button1 = "Продать",
    button2 = "Не продавать",
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    showAlert = 1,
    OnAccept = function(_, sale)
        if not CanSell() then return end
        local info, guid = ReadBagItem(sale.bag, sale.slot)
        if not info or guid ~= sale.guid or info.hyperlink ~= sale.link or info.stackCount ~= sale.count then return end

        if not sale.fromCursor then
            if GetCursorInfo() or info.isLocked or MerchantFrame.selectedTab == 2 then return end
            C_Container.PickupContainerItem(sale.bag, sale.slot)
            local cursorType, cursorItemID = GetCursorInfo()
            if cursorType == "item" and cursorItemID == info.itemID then SellCursorItem() end
        elseif CursorMatches(sale) then
            SellCursorItem()
        end
    end,
    OnCancel = function(_, sale)
        if sale and sale.fromCursor and CursorMatches(sale) then ClearCursor() end
    end,
}

local function ConfirmSale(bag, slot, fromCursor)
    if StaticPopup_Visible(popup) then return end
    local info, guid = ReadBagItem(bag, slot)
    if not info or (not fromCursor and info.isLocked) then return end
    StaticPopup_Show(popup, info.hyperlink, nil, {
        bag = bag,
        slot = slot,
        guid = guid,
        link = info.hyperlink,
        count = info.stackCount,
        fromCursor = fromCursor,
    })
end

local inventory = Constants.InventoryConstants
local lastBag = inventory.NumBagSlots + inventory.NumReagentBagSlots
local function BagButtonSlot(button)
    if not button.GetBagID then return end
    local bag, slot = button:GetBagID(), button:GetID()
    if type(bag) == "number" and bag >= 0 and bag <= lastBag and type(slot) == "number" and slot > 0 then
        return bag, slot
    end
end

local function BagSaleClick(overlay, mouseButton)
    if mouseButton ~= "RightButton" or not CanSell() or MerchantFrame.selectedTab == 2
        or GetCursorInfo() or IsModifiedClick() then return end

    local bag, slot = BagButtonSlot(overlay:GetParent())
    ConfirmSale(bag, slot, false)
end

local function ShowBagOverlay(button)
    local overlay = overlays[button]
    if not overlay then
        -- Give only the sale click to our own button. Leave the bag button's scripts alone.
        overlay = CreateFrame("Button", nil, button)
        overlay:SetAllPoints(button)
        overlay:SetMouseClickEnabled(true)
        overlay:SetMouseMotionEnabled(false)
        overlay:SetPassThroughButtons(unpack(passThrough))
        overlay:RegisterForClicks("AnyUp")
        overlay:SetScript("OnClick", BagSaleClick)
        overlays[button] = overlay
    end
    overlay.refreshID = refreshID
    overlay:SetFrameLevel(button:GetFrameLevel() + 5)
    overlay:Show()
end

local function CheckBagButton(button)
    if button:IsForbidden() or not button:IsVisible() then return false end
    local bag, slot = BagButtonSlot(button)
    if not bag then return false end
    local info = GetBoE(bag, slot)
    if info and not info.isLocked then ShowBagOverlay(button) end
    return true
end

local function ScanBag(frame)
    if not frame or frame:IsForbidden() or not frame:IsVisible() then return end
    if CheckBagButton(frame) then return end
    for _, child in ipairs({ frame:GetChildren() }) do ScanBag(child) end
end

local function ScanBlizzardBag(frame)
    if not frame or frame:IsForbidden() or not frame:IsVisible() then return end
    for _, button in frame:EnumerateValidItems() do
        CheckBagButton(button)
    end
end

local function ScanBaganator()
    local skins = Baganator and Baganator.API and Baganator.API.Skins
    if not skins or not skins.GetAllFrames then return end
    -- Baganator exposes its backpack frames with the "backpack" tag.
    for _, details in ipairs(skins.GetAllFrames()) do
        if details.regionType == "ButtonFrame" and details.tags and tContains(details.tags, "backpack") then
            ScanBag(details.region)
        end
    end
end

local function ConfirmCursorSale()
    if not CanSell() then return end
    local bag, slot = GetCursorSlot()
    ConfirmSale(bag, slot, true)
end

local function ShowMerchantOverlay()
    if not merchantOverlay then
        merchantOverlay = CreateFrame("Frame", nil, MerchantFrame)
        merchantOverlay:SetAllPoints()
        merchantOverlay:EnableMouse(true)
        merchantOverlay:SetScript("OnReceiveDrag", ConfirmCursorSale)
        merchantOverlay:SetScript("OnMouseUp", ConfirmCursorSale)
    end
    merchantOverlay:SetFrameLevel(MerchantFrame:GetFrameLevel() + 10)
    merchantOverlay:Show()
end

local function Refresh()
    refreshID = refreshID + 1
    local canSell = watching and CanSell()
    if canSell and MerchantFrame.selectedTab ~= 2 and not GetCursorInfo() and not IsModifiedClick() then
        ScanBlizzardBag(ContainerFrameCombinedBags)
        for index = 1, (NUM_CONTAINER_FRAMES or 0) do
            ScanBlizzardBag(_G["ContainerFrame" .. index])
        end
        ScanBag(EUI_MainBagFrame)
        ScanBag(EUI_BagsWindowFrame)
        ScanBaganator()
    end

    for _, overlay in pairs(overlays) do
        if overlay.refreshID ~= refreshID then overlay:Hide() end
    end

    if canSell and ReadBagItem(GetCursorSlot()) then
        ShowMerchantOverlay()
    elseif merchantOverlay then
        merchantOverlay:Hide()
    end
end

local function QueueRefresh()
    if not watching or refreshQueued then return end
    refreshQueued = true
    C_Timer.After(0, function()
        refreshQueued = false
        if watching then Refresh() end
    end)
end

watcher:SetScript("OnEvent", function(_, event)
    if event == "CURSOR_CHANGED" or event == "MODIFIER_STATE_CHANGED" or event == "PLAYER_REGEN_DISABLED" then
        Refresh()
    else
        QueueRefresh()
    end
end)

local refreshEvents = {
    "BAG_OPEN", "BAG_CLOSED", "BAG_UPDATE_DELAYED", "GET_ITEM_INFO_RECEIVED", "CURSOR_CHANGED",
    "MODIFIER_STATE_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "MERCHANT_UPDATE",
}

local function SetWatching(active)
    if active == watching then return end
    watching = active
    if active then
        for _, event in ipairs(refreshEvents) do watcher:RegisterEvent(event) end
        baganatorEvents = Baganator and Baganator.CallbackRegistry
        if baganatorEvents then baganatorEvents:RegisterCallback("ViewComplete", QueueRefresh, watcher) end
        Refresh()
        QueueRefresh()
    else
        watcher:UnregisterAllEvents()
        if baganatorEvents then
            baganatorEvents:UnregisterCallback("ViewComplete", watcher)
            baganatorEvents = nil
        end
        Refresh()
        StaticPopup_Hide(popup)
    end
end

ns.AddSetting(feature, "Подтверждать продажу предметов, персональных при надевании", function()
    SetWatching(ns.Enabled(feature) and MerchantFrame and MerchantFrame:IsShown() or false)
end, true)

ns.On("MERCHANT_SHOW", function() SetWatching(ns.Enabled(feature) == true) end)
ns.On("MERCHANT_CLOSED", function() SetWatching(false) end)
