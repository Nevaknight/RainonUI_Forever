local _, ns = ...

local rules = {
    { "Урон от заклинаний", "increases damage done by magical spells and effects by up to (%d+)", "увеличивает урон от заклинаний и магических эффектов на (%d+)" },
    { "Исцеление заклинаниями", "increases healing done by spells and effects by up to (%d+)", "увеличивает исцеление от заклинаний и эффектов на (%d+)" },
    { "Вероятность критического удара", "improves your chance to get a critical strike by ([%d.,]+%%)", "повышает вероятность критического удара на ([%d.,]+%%)" },
    { "Вероятность критического удара", "improves your chance to get a critical strike with spells by ([%d.,]+%%)", "повышает вероятность критического эффекта заклинаний на ([%d.,]+%%)" },
    { "Вероятность критического удара", "improves your chance to get a critical strike with all spells and attacks by ([%d.,]+%%)", "повышает вероятность критического эффекта атак и заклинаний на ([%d.,]+%%)" },
    { "Вероятность попадания", "improves your chance to hit by ([%d.,]+%%)", "повышает вероятность попадания на ([%d.,]+%%)" },
    { "Вероятность попадания", "improves your chance to hit with spells by ([%d.,]+%%)", "повышает вероятность попадания заклинаниями на ([%d.,]+%%)" },
    { "Вероятность попадания", "improves your chance to hit with all spells and attacks by ([%d.,]+%%)", "повышает вероятность попадания атаками и заклинаниями на ([%d.,]+%%)" },
    { "Скорость", "improves your haste by ([%d.,]+%%)", "повышает скорость на ([%d.,]+%%)" },
    { "Скорость", "increases your attack and casting speed by ([%d.,]+%%)", "повышает скорость атаки и произнесения заклинаний на ([%d.,]+%%)" },
    { "Сила атаки", "increases attack power by (%d+)", "увеличивает силу атаки на (%d+)" },
    { "Сила атаки", "%+(%d+) attack power", "%+(%d+) к силе атаки" },
    { "Сила атаки дальнего боя", "increases ranged attack power by (%d+)", "увеличивает силу атаки дальнего боя на (%d+)" },
    { "Сила атаки дальнего боя", "%+(%d+) ranged attack power", "%+(%d+) к силе атаки дальнего боя" },
    { "Мана за 5 сек.", "restores (%d+) mana per 5 sec", "восполняет (%d+) ед%. маны раз в 5 сек" },
    { "Мана за 5 сек.", "restores (%d+) mana per 5 seconds", "восстанавливает (%d+) ед%. маны раз в 5 сек" },
    { "Здоровье за 5 сек.", "restores (%d+) health every 5 sec", "восполняет (%d+) ед%. здоровья раз в 5 сек" },
    { "Здоровье за 5 сек.", "restores (%d+) health per 5 sec", "восстанавливает (%d+) ед%. здоровья раз в 5 сек" },
    { "Максимум энергии", "increases your maximum energy by (%d+)", "увеличивает максимальный запас энергии на (%d+)" },
    { "Навык защиты", "increased defense %+(%d+)", "защита %+(%d+)" },
    { "Навык защиты", "increases defense by (%d+)", "повышает навык защиты на (%d+)" },
    { "Вероятность уклонения", "increases your chance to dodge an attack by ([%d.,]+%%)", "повышает вероятность уклонения на ([%d.,]+%%)" },
    { "Вероятность парирования", "increases your chance to parry an attack by ([%d.,]+%%)", "повышает вероятность парирования на ([%d.,]+%%)" },
    { "Вероятность блока", "increases your chance to block attacks with a shield by ([%d.,]+%%)", "повышает вероятность блокирования щитом на ([%d.,]+%%)" },
    { "Показатель блокирования щитом", "increases the block value of your shield by (%d+)", "увеличивает показатель блокирования щитом на (%d+)" },
    { "Проникновение заклинаний", "decreases the magical resistances of your spell targets by (%d+)", "снижает сопротивление магии целей ваших заклинаний на (%d+)" },
    { "Проникновение заклинаний", "your spells pierce (%d+) magical resistances?", "ваши заклинания игнорируют (%d+) ед%. сопротивления магии" },
}

local schools = { arcane = "тайной магии", fire = "огня", frost = "льда", holy = "света", nature = "сил природы", shadow = "тёмной магии",
    ["тайной магии"] = true, ["огня"] = true, ["льда"] = true, ["света"] = true, ["сил природы"] = true,
    ["темной магии"] = "тёмной магии", ["тёмной магии"] = true }

local weapons = { axes = "топорами", swords = "мечами", maces = "дробящим оружием", daggers = "кинжалами",
    bows = "луками", guns = "огнестрельным оружием", crossbows = "арбалетами", staves = "посохами",
    polearms = "древковым оружием", ["fist weapons"] = "кистевым оружием", ["two-handed axes"] = "двуручными топорами",
    ["two-handed swords"] = "двуручными мечами", ["two-handed maces"] = "двуручным дробящим оружием",
    unarmed = "кулачным боем", thrown = "метательным оружием", wands = "жезлами" }

local enemies = { beasts = "зверей", demons = "демонов", dragonkin = "драконов", elementals = "элементалей",
    giants = "великанов", humanoids = "гуманоидов", undead = "нежити", ["undead and demons"] = "нежити и демонов",
    ["demons and undead"] = "демонов и нежити" }

local function LegacyStat(text)
    local line = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("\194\160", " ")
    line = line:gsub("%s+", " "):match("^%s*(.-)%s*$"):gsub("[A-Z]", string.lower):gsub("%.$", "")
    local stat = line:match("^equip:%s*(.+)$") or line:match("^Экипировка:%s*(.+)$")
        or line:match("^экипировка:%s*(.+)$") or line:match("^Если на персонаже:%s*(.+)$")
        or line:match("^если на персонаже:%s*(.+)$") or line:match("^При надевании:%s*(.+)$")
        or line:match("^при надевании:%s*(.+)$")
    if not stat then return end
    for upper, lower in pairs({ ["У"]="у", ["П"]="п", ["В"]="в", ["З"]="з", ["С"]="с" }) do
        stat = stat:gsub("^" .. upper, lower)
    end
    for _, rule in ipairs(rules) do
        local amount = stat:match("^" .. rule[2] .. "$") or stat:match("^" .. rule[3] .. "$")
        if amount then return "+" .. amount .. " " .. rule[1] end
    end
    local amount = stat:match("^increases damage and healing done by magical spells and effects by up to (%d+)$")
        or stat:match("^увеличивает урон и исцеление от заклинаний и магических эффектов на (%d+)$")
        or stat:match("^увеличение урона и целительного действия магических заклинаний и эффектов не более чем на (%d+) ед%.?$")
    if amount then return "+" .. amount .. " Исцеление заклинаниями\n+" .. amount .. " Урон от заклинаний" end
    local heal, damage = stat:match("^increases healing done by up to (%d+) and damage done by up to (%d+) for all magical spells and effects$")
    if heal then return "+" .. heal .. " Исцеление заклинаниями\n+" .. damage .. " Урон от заклинаний" end
    local school, power = stat:match("^increases damage done by (%a+) spells and effects by up to (%d+)$")
    if not school then school, power = stat:match("^увеличивает урон от заклинаний (.-) на (%d+)$") end
    local schoolName = schools[school]
    if schoolName then return "+" .. power .. " Урон от заклинаний " .. (schoolName == true and school or schoolName) end
    local skill, bonus = stat:match("^increased (.-) %+(%d+)$")
    if weapons[skill] then return "+" .. bonus .. " к владению " .. weapons[skill] end
    local enemy, value = stat:match("^increases damage done to (.-) by magical spells and effects by up to (%d+)$")
    if enemies[enemy] then return "+" .. value .. " Урон от заклинаний против " .. enemies[enemy] end
    value, enemy = stat:match("^%+(%d+) attack power against (.-)$")
    if enemies[enemy] then return "+" .. value .. " Сила атаки против " .. enemies[enemy] end
end

local hues = {
    str = "c79c6e", agi = "abd473", sta = "ef5350", int = "69ccf0", spi = "ffe082",
    health = "ef5350", mana = "4fc3f7", ap = "ff8c42", crit = "ffd100", haste = "7fe3d4", hit = "ffa94d",
    sp = "c77dff", healing = "4ec9b0", penetration = "b39ddb",
    holy = "fff2b0", fire = "ff6b35", frost = "3fc7eb", nature = "4caf50", shadow = "a335ee", arcane = "ff7eb6",
    armor = "b0bec5", avoid = "64b5f6", mp5 = "4fc3f7", hp5 = "e57373", speed = "81c784",
}

-- Use the client's own formats to read the text, with Russian labels for our output.
local gameRules, labels
local function Escape(text)
    return (text:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
end

local function NumberPattern(format)
    local result, slots = {}, {}
    local offset = 1
    while offset <= #format do
        local start = format:find("%%", offset)
        if not start then
            result[#result + 1] = Escape(format:sub(offset))
            break
        end
        result[#result + 1] = Escape(format:sub(offset, start - 1))
        local token = format:sub(start)
        local code, position = token:match("^(%%(%d+)%$[%d%.%+%-]*[df])")
        code = code or token:match("^(%%[%d%.%+%-]*[df])")
        if code then
            slots[#slots + 1] = tonumber(position) or #slots + 1
            result[#result + 1] = "([%d.,]+)"
            offset = start + #code
        elseif token:sub(1, 2) == "%%" then
            result[#result + 1] = "%%"
            offset = start + 2
        else
            return
        end
    end
    if #slots > 0 and #slots <= 2 then return "^" .. table.concat(result) .. "$", slots end
end

local function StripEquip(text)
    local trigger = ITEM_SPELL_TRIGGER_ONEQUIP
    if type(trigger) == "string" and trigger ~= "" and text:find(trigger, 1, true) == 1 then
        return (text:sub(#trigger + 1):gsub("^%s+", ""))
    end
    local prefix, body = text:match("^([^:]+):%s*(.+)$")
    if prefix and (prefix:lower() == "equip" or prefix == "Если на персонаже" or prefix == "Экипировка"
        or prefix == "При надевании" or prefix == "если на персонаже" or prefix == "экипировка" or prefix == "при надевании") then
        return body
    end
end

local function BuildRules()
    gameRules, labels = {}, {}
    local function Alias(text, stat)
        if type(text) == "string" and text ~= "" then labels[text:lower()] = stat end
    end
    local function FormatAlias(format, stat, ...)
        if type(format) ~= "string" then return end
        local plain = format:gsub("%%%d+%$", "%%"):gsub("%%c", "")
        local ok, example = pcall(string.format, plain, 0, ...)
        if ok then Alias(example:gsub("[%+%-]?0", "", 1):match("^%s*(.-)%s*$"), stat) end
    end
    local function Stat(russian, hue, short, english)
        local stat = { label = russian, color = hues[hue] or hues.armor }
        Alias(russian, stat)
        Alias(english, stat)
        if short then
            Alias(_G["ITEM_MOD_" .. short .. "_SHORT"], stat)
            FormatAlias(_G["ITEM_MOD_" .. short], stat)
        end
        return stat
    end
    local function Rule(key, outputs, sign1, sign2)
        local format = _G["TOOLTIP_ITEM_STAT_" .. key]
        if type(format) ~= "string" then return end
        local pattern, slots = NumberPattern(StripEquip(format) or format)
        if pattern then
            gameRules[#gameRules + 1] = { pattern = pattern, slots = slots, outputs = outputs,
                signs = { sign1, sign2 or sign1 }, percent = format:find("%%", 1, true) and "%" or "" }
        end
    end
    local function Pair(key, stat)
        Rule(key .. "_INCREASE", { stat }, "+")
        Rule(key .. "_DECREASE", { stat }, "-")
    end

    local damage = Stat("Урон от заклинаний", "sp", "SPELL_DAMAGE_DONE", "Spell Damage")
    local heal = Stat("Исцеление заклинаниями", "healing", "SPELL_HEALING_DONE", "Spell Healing")
    local power = Stat("Сила заклинаний", "sp", "SPELL_POWER", "Spell Power")
    Pair("SPELL_DAMAGE", damage)
    Pair("SPELL_HEALING", heal)
    Rule("SPELL_POWER_INCREASE", { heal, damage }, "+")
    Rule("SPELL_POWER_DECREASE", { heal, damage }, "-")
    for _, healing in ipairs({ { "INCREASE", "+" }, { "DECREASE", "-" } }) do
        for _, damaging in ipairs({ { "INCREASE", "+" }, { "DECREASE", "-" } }) do
            Rule("SPELL_HEALING_" .. healing[1] .. "_DAMAGE_" .. damaging[1], { heal, damage }, healing[2], damaging[2])
        end
    end

    for _, entry in ipairs({
        { "ATTACK_POWER", "ATTACK_POWER", "Сила атаки", "ap", "Attack Power" },
        { "RANGED_ATTACK_POWER", "RANGED_ATTACK_POWER", "Сила атаки дальнего боя", "ap", "Ranged Attack Power" },
        { "CRIT_PERCENT", "CRIT_RATING", "Вероятность критического удара", "crit", "Critical Strike" },
        { "HIT_PERCENT", "HIT_RATING", "Вероятность попадания", "hit", "Hit" },
        { "EXPERTISE_PCT", "EXPERTISE_RATING", "Мастерство", "hit", "Expertise" },
        { "HASTE_PCT", "HASTE_RATING", "Скорость", "haste", "Haste" },
        { "DEFENSE", "DEFENSE_SKILL_RATING", "Навык защиты", "armor", "Defense" },
        { "DODGE_PCT", "DODGE_RATING", "Вероятность уклонения", "avoid", "Dodge" },
        { "PARRY_PCT", "PARRY_RATING", "Вероятность парирования", "avoid", "Parry" },
        { "BLOCK_CHANCE", "BLOCK_RATING", "Вероятность блока", "avoid", "Block Chance" },
        { "BLOCK_VALUE", "BLOCK_VALUE", "Показатель блокирования щитом", "avoid", "Shield Block Value" },
        { "MANA_REGEN", "POWER_REGEN0", "Мана за 5 сек.", "mp5", "Mana per 5 sec" },
        { "HEALTH_REGEN", "HEALTH_REGEN", "Здоровье за 5 сек.", "hp5", "Health per 5 sec" },
        { "SPELL_PENETRATION", "SPELL_PENETRATION", "Проникновение заклинаний", "penetration", "Spell Penetration" },
        { "ARMOR_PENETRATION", "ARMOR_PENETRATION_RATING", "Пробивание брони", "armor", "Armor Penetration" },
        { "ARMOR", "ARMOR", "Броня", "armor", "Armor" },
        { "SPELL_RESISTANCE_ALL_SCHOOLS", "RESISTANCE", "Сопротивление всем школам магии", "penetration", "All Resistances" },
    }) do
        local stat = Stat(entry[3], entry[4], entry[2], entry[5])
        Pair(entry[1], stat)
        if entry[1] == "ARMOR" then
            Alias(ARMOR, stat)
            FormatAlias(ARMOR_TEMPLATE, stat)
        elseif entry[1] == "BLOCK_VALUE" then
            FormatAlias(SHIELD_BLOCK_TEMPLATE, stat)
        elseif entry[1] == "SPELL_RESISTANCE_ALL_SCHOOLS" then
            FormatAlias(ITEM_RESIST_ALL, stat)
        end
    end
    for _, entry in ipairs({
        { "STRENGTH", "Сила", "str", "Strength" }, { "AGILITY", "Ловкость", "agi", "Agility" },
        { "STAMINA", "Выносливость", "sta", "Stamina" }, { "INTELLECT", "Интеллект", "int", "Intellect" },
        { "SPIRIT", "Дух", "spi", "Spirit" }, { "HEALTH", "Здоровье", "health", "Health" },
        { "MANA", "Мана", "mana", "Mana" },
    }) do
        Stat(entry[2], entry[3], entry[1], entry[4])
    end
    for i, entry in ipairs({
        { "HOLY", "света" }, { "FIRE", "огня" }, { "NATURE", "сил природы" },
        { "FROST", "льда" }, { "SHADOW", "тёмной магии" }, { "ARCANE", "тайной магии" },
    }) do
        local key, name = entry[1], entry[2]
        local hue = key:lower()
        Pair(key .. "_DAMAGE", Stat("Урон от заклинаний " .. name, hue, key .. "_DAMAGE_DONE"))
        Pair(key .. "_PENETRATION", Stat("Проникновение заклинаний " .. name, hue, key .. "_PENETRATION"))
        local resistance = Stat("Сопротивление магии " .. name, hue, nil, key:sub(1, 1) .. hue:sub(2) .. " Resistance")
        Alias(_G["RESISTANCE" .. i .. "_NAME"], resistance)
        FormatAlias(ITEM_RESIST_SINGLE, resistance, _G["SPELL_SCHOOL" .. i .. "_CAP"])
    end

    for _, entry in ipairs({
        { "AXES", "Владение топорами" }, { "SWORDS", "Владение мечами" }, { "MACES", "Владение дробящим оружием" },
        { "DAGGERS", "Владение кинжалами" }, { "BOWS", "Владение луками" }, { "CROSSBOWS", "Владение арбалетами" },
        { "GUNS", "Владение огнестрельным оружием" }, { "FIST_WEAPONS", "Владение кистевым оружием" },
        { "STAVES", "Владение посохами" }, { "POLEARMS", "Владение древковым оружием" }, { "WANDS", "Владение жезлами" },
        { "THROWN_WEAPONS", "Владение метательным оружием", "THROWN" }, { "DUAL_WIELDING", "Владение парным оружием", "DUAL_WIELD" },
        { "ALCHEMY", "Алхимия" }, { "BLACKSMITHING", "Кузнечное дело" }, { "COOKING", "Кулинария" },
        { "ENCHANTING", "Наложение чар" }, { "ENGINEERING", "Инженерное дело" }, { "FIRST_AID", "Первая помощь" },
        { "FISHING", "Рыбная ловля" }, { "HERBALISM", "Травничество" }, { "JEWELCRAFTING", "Ювелирное дело" },
        { "LEATHERWORKING", "Кожевничество" }, { "MINING", "Горное дело" }, { "SKINNING", "Снятие шкур" },
        { "TAILORING", "Портняжное дело" },
    }) do
        Pair("SKILL_" .. entry[1], Stat(entry[2], "armor", entry[3] or entry[1]))
    end
    Stat("Максимум энергии", "speed", nil, "Maximum Energy")
    return power
end

local function Colored(text, color)
    return "|cff" .. color .. text .. "|r"
end

local function Render(amount, stat, mode)
    if not mode or not stat.color then return amount .. " " .. stat.label end
    local sign = amount:sub(1, 1)
    if mode == "stat" then
        amount = Colored(amount, stat.color)
    elseif mode == "signed" then
        amount = Colored(amount, sign == "+" and "1eff00" or sign == "-" and "ff2020" or "ffffff")
    end
    return amount .. " " .. Colored(stat.label, stat.color)
end

local function ShortParts(text)
    local amount, label = text:match("^%s*([+%-]?[%d.,]+%%?)%s+(.+)%s*$")
    if not amount then label, amount = text:match("^%s*(.-)%s+([+%-]?[%d.,]+%%?)%s*$") end
    if amount and label then return amount, labels[label:lower()] end
end

local mergedStat
local function FormatLong(body, merge, color)
    for _, rule in ipairs(gameRules) do
        local first, second = body:match(rule.pattern)
        if first then
            local numbers, values, out = { first, second }, {}, {}
            for capture, slot in ipairs(rule.slots) do values[slot] = numbers[capture] end
            for i, stat in ipairs(rule.outputs) do
                local n = values[i] or values[1]
                if not n then return end
                values[i] = n
                out[i] = Render(rule.signs[i] .. n .. rule.percent, stat, color)
            end
            if #out == 2 and merge and values[1] == values[2] and rule.signs[1] == rule.signs[2] then
                return Render(rule.signs[1] .. values[1] .. rule.percent, mergedStat, color)
            end
            return table.concat(out, "\n")
        end
    end

    local fallback = LegacyStat("Equip: " .. body)
    if not fallback then return end
    local parts, amounts = {}, {}
    for line in fallback:gmatch("[^\n]+") do
        local amount, stat = ShortParts(line)
        parts[#parts + 1] = stat and Render(amount, stat, color) or line
        amounts[#amounts + 1] = amount or false
    end
    if merge and #parts == 2 and amounts[1] and amounts[1] == amounts[2] then
        return Render(amounts[1], mergedStat, color)
    end
    return table.concat(parts, "\n")
end

local function Prefix(text, format)
    local start = type(format) == "string" and format:match("^(.-)%%s$")
    if not start or start == "" then return end
    local pattern = Escape(start):gsub("%%%%d", "%%d+")
    return text:match("^(" .. pattern .. ")(.*)$")
end

function ns.FormatStat(text, shorten, merge, mode)
    if not gameRules then mergedStat = BuildRules() end
    local clean = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[%w_]+:", ""):gsub("|r", ""):gsub("\194\160", " ")
    local equip = StripEquip(clean)
    if equip then
        if shorten then return FormatLong(equip, merge, mode) end
        return
    end

    local prefix, body = Prefix(clean, ITEM_SET_BONUS_GRAY)
    if not prefix then prefix, body = clean:match("^(%(%d+%) [Ss]et:%s*)(.+)$") end
    if not prefix then prefix, body = clean:match("^(%(%d+%) Комплект:%s*)(.+)$") end
    local inactive = prefix ~= nil
    if not prefix then prefix, body = Prefix(clean, ITEM_SET_BONUS) end
    if not prefix then prefix, body = clean:match("^([Ss]et:%s*)(.+)$") end
    if not prefix then prefix, body = clean:match("^(Комплект:%s*)(.+)$") end
    if prefix then
        if not shorten then return end
        local output = FormatLong(body, merge, not inactive and mode)
        if output then
            local count = inactive and prefix:match("^%(%d+%) ")
            local label = (count or "") .. "Комплект: "
            return label .. output:gsub("\n", "\n" .. label)
        end
        return
    end

    if not mode then return end
    prefix, body = Prefix(clean, ENCHANTED_TOOLTIP_LINE)
    if not prefix then prefix, body = clean:match("^([Ee]nchanted:%s*)(.+)$") end
    if not prefix then prefix, body = clean:match("^(Чары:%s*)(.+)$") end
    local amount, stat = ShortParts(body or clean)
    if stat then return (prefix and "Чары: " or "") .. Render(amount, stat, mode) end
end

function ns.CompactStat(text)
    return ns.FormatStat(text, true, false, nil)
end

local visibleTooltips = {
    GameTooltip = true, ItemRefTooltip = true, ShoppingTooltip1 = true, ShoppingTooltip2 = true,
    ItemRefShoppingTooltip1 = true, ItemRefShoppingTooltip2 = true, LootHistoryExtraTooltip = true,
}

local cache, cacheKey, size = {}, nil, 0
local function Rewrite(tooltip)
    local shorten, colors = ns.Enabled("stats"), ns.Enabled("statsColors")
    if not (shorten or colors) or not tooltip or not tooltip.GetName then return end
    local ok, name = pcall(tooltip.GetName, tooltip)
    if not ok or not visibleTooltips[name] then return end
    local merge = shorten and ns.Enabled("statsMerge")
    local mode = colors and ns.StatNumberColor()
    local key = tostring(shorten) .. "/" .. tostring(merge) .. "/" .. tostring(mode)
    if cacheKey ~= key then cache, cacheKey, size = {}, key, 0 end

    local changed
    for i = 2, tooltip:NumLines() do
        local line = _G[name .. "TextLeft" .. i]
        local text = line and line:GetText()
        if type(text) == "string" and not (issecretvalue and issecretvalue(text)) and text:find("%d") then
            local short = cache[text]
            if short == nil then
                short = ns.FormatStat(text, shorten, merge, mode) or false
                if size >= 1000 then cache, size = {}, 0 end
                cache[text], size = short, size + 1
            end
            if short and short ~= text then
                line:SetText(short)
                changed = true
            end
        end
    end
    if changed and tooltip:IsShown() then tooltip:Show() end
end

function ns.StatNumberColor()
    local mode = ns.db and ns.db.statsNumberColor
    return (mode == "stat" or mode == "line") and mode or "signed"
end

ns.AddSetting("stats", "Сокращать строки экипировки", nil, nil, "equipment")
ns.AddSetting("statsMerge", "Объединять равные урон и исцеление", nil, true, "equipment")
ns.AddSetting("statsColors", "Окрашивать характеристики", nil, true, "equipment")
ns.On("PLAYER_LOGIN", function()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, Rewrite)
    else
        for name in pairs(visibleTooltips) do
            local tooltip = _G[name]
            if tooltip and tooltip:HasScript("OnTooltipSetItem") then tooltip:HookScript("OnTooltipSetItem", Rewrite) end
        end
    end
    if TooltipComparisonManager and TooltipComparisonManager.SetItemTooltip then
        hooksecurefunc(TooltipComparisonManager, "SetItemTooltip", function(manager, primary)
            local tips = manager.tooltip and manager.tooltip.shoppingTooltips
            if tips then Rewrite(tips[primary and 1 or 2]) end
        end)
    end
end)
