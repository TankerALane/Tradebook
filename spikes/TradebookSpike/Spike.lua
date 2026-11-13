-- Tradebook Phase 0 spike. Throwaway code: probes the live Forever client and saves
-- the results in TradebookSpikeDB so they can be read from WTF after /reload or logout.
-- Nothing here is meant to ship.

local ADDON = ...
local MAX_EVENTS = 400

local db, char, charKey
local panel
local session = { started = 0, lastTrigger = nil, lastTriggerAt = 0, suspended = false, scanQueued = false }

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------

local function isSecret(v)
    return issecretvalue and issecretvalue(v) or false
end

local function resolve(path)
    local cur = _G
    for part in path:gmatch("[^%.]+") do
        if type(cur) ~= "table" then return nil end
        cur = cur[part]
    end
    return cur
end

-- Call a function by dotted path. Returns ok, packed results (or error / "missing").
local function call(path, ...)
    local fn = resolve(path)
    if type(fn) ~= "function" then return false, "missing" end
    local packed = { n = 0 }
    local function pack(ok, ...)
        packed.n = select("#", ...)
        for i = 1, packed.n do packed[i] = select(i, ...) end
        return ok
    end
    local ok = pack(pcall(fn, ...))
    if not ok then return false, tostring(packed[1]) end
    return true, packed
end

local function first(path, ...)
    local ok, res = call(path, ...)
    if ok then return res[1] end
    return nil
end

local function ser(v, depth, budget)
    depth = depth or 0
    budget = budget or { n = 0 }
    if isSecret(v) then return "<secret>" end
    local t = type(v)
    if t == "string" then return string.format("%q", v) end
    if t ~= "table" then return tostring(v) end
    if depth >= 3 then return "{...}" end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local out = {}
    for _, k in ipairs(keys) do
        budget.n = budget.n + 1
        if budget.n > 200 then out[#out + 1] = "..."; break end
        out[#out + 1] = tostring(k) .. "=" .. ser(v[k], depth + 1, budget)
    end
    return "{" .. table.concat(out, ", ") .. "}"
end

local function packStr(ok, res)
    if not ok then return "ERR " .. tostring(res) end
    local out = {}
    for i = 1, (res.n or #res) do out[#out + 1] = ser(res[i]) end
    return table.concat(out, " | ")
end

local function say(msg)
    print("|cffd9a54aTradebook Spike|r: " .. tostring(msg))
end

local function stamp()
    return date("%H:%M:%S") .. string.format(" +%.2f", GetTime() - session.started)
end

local function logEvent(line)
    if not db then return end
    local ev = db.events
    ev[#ev + 1] = stamp() .. " " .. line
    while #ev > MAX_EVENTS do table.remove(ev, 1) end
end

local function note(section, key, value)
    char[section] = char[section] or {}
    char[section][key] = value
end

---------------------------------------------------------------------------
-- 7. identity / play type
---------------------------------------------------------------------------

local function probeIdentity()
    local r = {}
    r.UnitFullName = packStr(call("UnitFullName", "player"))
    r.GetRealmName = packStr(call("GetRealmName"))
    r.GetNormalizedRealmName = packStr(call("GetNormalizedRealmName"))
    r.GetRealmID = packStr(call("GetRealmID"))
    local guid = first("UnitGUID", "player")
    r.UnitGUID = ser(guid)
    r.UnitClass = packStr(call("UnitClass", "player"))
    r.UnitRace = packStr(call("UnitRace", "player"))
    r.UnitLevel = packStr(call("UnitLevel", "player"))
    r.UnitFactionGroup = packStr(call("UnitFactionGroup", "player"))
    r.WOW_PROJECT_ID = ser(WOW_PROJECT_ID)
    r.GetBuildInfo = packStr(call("GetBuildInfo"))
    if guid and not isSecret(guid) then
        r.GetPlayerInfoByGUID = packStr(call("GetPlayerInfoByGUID", guid))
        r.BNetGameAccountByGUID = packStr(call("C_BattleNet.GetGameAccountInfoByGUID", guid))
    end
    r.BNGetInfo = packStr(call("BNGetInfo"))
    r.GetActiveGameMode = packStr(call("C_GameRules.GetActiveGameMode"))
    r.GetCurrentGameModeRecordID = packStr(call("C_GameRules.GetCurrentGameModeRecordID"))
    r.GetForeverExperiencePreset = packStr(call("C_GameRules.GetForeverExperiencePreset"))
    r.IsHardcoreActive = packStr(call("C_GameRules.IsHardcoreActive"))
    r.IsWarModeDesired = packStr(call("C_PvP.IsWarModeDesired"))
    r.IsWarModeActive = packStr(call("C_PvP.IsWarModeActive"))
    r.GetZonePVPInfo = packStr(call("GetZonePVPInfo"))
    -- Any global that might name the ruleset.
    for _, name in ipairs({ "GetRealmType", "IsRPRealm", "IsPvPRealm", "GetCurrentRuleset", "C_GameRules.GetRuleset",
        "C_RealmList.GetRealmInfo", "C_GameRules.GetCurrentRuleset", "IsRealmPvP" }) do
        r["has:" .. name] = type(resolve(name))
    end
    -- Active game rules by name (Enum.GameRule reverse lookup).
    local active = {}
    if type(Enum) == "table" and type(Enum.GameRule) == "table" then
        for name, value in pairs(Enum.GameRule) do
            local ok, res = call("C_GameRules.IsGameRuleActive", value)
            if ok and res[1] == true then active[#active + 1] = name end
        end
        table.sort(active)
        r.activeGameRules = table.concat(active, ",")
        local names = {}
        for name in pairs(Enum.GameRule) do
            if name:lower():find("pvp") or name:lower():find("rp") or name:lower():find("camp")
                or name:lower():find("profess") or name:lower():find("bank") or name:lower():find("legacy")
                or name:lower():find("craft") or name:lower():find("realm") or name:lower():find("rule") then
                names[#names + 1] = name
            end
        end
        table.sort(names)
        r.relevantGameRuleNames = table.concat(names, ",")
    else
        r.activeGameRules = "Enum.GameRule missing"
    end
    char.identity = r
end

---------------------------------------------------------------------------
-- 2/3. API surface and professions
---------------------------------------------------------------------------

local function listKeys(path)
    local t = resolve(path)
    if type(t) ~= "table" then return "missing" end
    local keys = {}
    for k, v in pairs(t) do keys[#keys + 1] = k .. (type(v) == "function" and "" or ":" .. type(v)) end
    table.sort(keys)
    return table.concat(keys, ",")
end

local function probeApis()
    local r = {}
    for _, ns in ipairs({ "C_TradeSkillUI", "C_Bank", "C_Traits", "C_Container", "C_Item", "C_Spell", "C_SpellBook",
        "C_SkillInfo", "C_ProfSpecs", "C_CraftingOrders", "C_GameRules", "C_MajorFactions" }) do
        r[ns] = listKeys(ns)
    end
    for _, name in ipairs({ "GetProfessions", "GetProfessionInfo", "ToggleProfessionsBook", "ShowProfessionsFrame",
        "OpenProfessionUIToSkillLine", "ProfessionsFrame_LoadUI", "ToggleLegacySystemUI", "CastSpellByName",
        "GetItemCount", "GetItemInfo", "GetTradeSkillLine", "GetNumTradeSkills", "GetTradeSkillInfo", "DoTradeSkill",
        "GetCraftInfo", "IsAddOnLoaded" }) do
        r["g:" .. name] = type(resolve(name))
    end
    r.bindingKey_TOGGLEPROFESSIONBOOK = packStr(call("GetBindingKey", "TOGGLEPROFESSIONBOOK"))
    r.bindingKey_TOGGLELEGACYSYSTEM = packStr(call("GetBindingKey", "TOGGLELEGACYSYSTEM"))
    r.LegacyConsts = ser(Constants and Constants.LegacyConsts)
    r.EnumProfession = ser(Enum and Enum.Profession)
    r.EnumBankType = ser(Enum and Enum.BankType)
    r.EnumBagIndex = ser(Enum and Enum.BagIndex)
    r.bankConsts = ser({ ITEM_INVENTORY_BANK_BAG_OFFSET = ITEM_INVENTORY_BANK_BAG_OFFSET,
        NUM_CHARACTER_BANK_SLOTS = NUM_CHARACTER_BANK_SLOTS, NUM_BANKBAGSLOTS = NUM_BANKBAGSLOTS,
        NUM_BANKGENERIC_SLOTS = NUM_BANKGENERIC_SLOTS, NUM_BAG_SLOTS = NUM_BAG_SLOTS,
        NUM_TOTAL_EQUIPPED_BAG_SLOTS = NUM_TOTAL_EQUIPPED_BAG_SLOTS })
    r.LibProfessionDB = ser(LibStub and LibStub("LibProfessionDB-1.0", true) and true or false)
    db.apis = r -- account-wide; same for every character
end

local function professionSpellID(spellOffset)
    if not spellOffset or not Enum.SpellBookSpellBank then return nil end
    local ok, res = call("C_SpellBook.GetSpellBookItemInfo", spellOffset + 1, Enum.SpellBookSpellBank.Player)
    if ok and type(res[1]) == "table" then return res[1].spellID end
    return nil
end

local function probeProfessions()
    local r = { slots = {} }
    local ok, res = call("GetProfessions")
    r.GetProfessions = packStr(ok, res)
    if ok then
        for i = 1, res.n do
            local idx = res[i]
            if idx then
                local okI, info = call("GetProfessionInfo", idx)
                local entry = { index = idx, raw = packStr(okI, info) }
                if okI then
                    entry.name, entry.rank, entry.max, entry.skillLine = info[1], info[3], info[4], info[7]
                    entry.spellID = professionSpellID(info[6])
                    if entry.skillLine then
                        entry.bySkillLine = packStr(call("C_TradeSkillUI.GetProfessionInfoBySkillLineID", entry.skillLine))
                        entry.displayName = packStr(call("C_TradeSkillUI.GetTradeSkillDisplayName", entry.skillLine))
                    end
                    if entry.spellID then
                        entry.canShowCraftingUI = packStr(call("C_TradeSkillUI.CanTradeSkillShowCraftingUI", entry.spellID))
                    end
                end
                r.slots[#r.slots + 1] = entry
            end
        end
    end
    local okAll, all = call("C_TradeSkillUI.GetAllProfessionTradeSkillLines")
    r.allTradeSkillLines = packStr(okAll, all)
    if okAll and type(all[1]) == "table" then
        local names = {}
        for _, id in ipairs(all[1]) do
            names[#names + 1] = id .. "=" .. tostring(first("C_TradeSkillUI.GetTradeSkillDisplayName", id))
        end
        r.allTradeSkillLineNames = table.concat(names, ", ")
    end
    -- Is recipe data readable with no profession window open?
    r.closed_IsTradeSkillReady = packStr(call("C_TradeSkillUI.IsTradeSkillReady"))
    r.closed_GetBaseProfessionInfo = packStr(call("C_TradeSkillUI.GetBaseProfessionInfo"))
    local okF, f = call("C_TradeSkillUI.GetFilteredRecipeIDs")
    r.closed_GetFilteredRecipeIDs = okF and ("count=" .. #(f[1] or {})) or packStr(okF, f)
    local okA, a = call("C_TradeSkillUI.GetAllRecipeIDs")
    r.closed_GetAllRecipeIDs = okA and ("count=" .. #(a[1] or {})) or packStr(okA, a)
    -- Recipes remembered from earlier scans: can we read them now?
    local remembered = {}
    for id in pairs(db.knownRecipeSamples or {}) do
        remembered[#remembered + 1] = id
        if #remembered >= 4 then break end
    end
    r.closed_readRemembered = {}
    for _, id in ipairs(remembered) do
        local info = first("C_TradeSkillUI.GetRecipeInfo", id)
        local schem = first("C_TradeSkillUI.GetRecipeSchematic", id, false)
        r.closed_readRemembered[tostring(id)] = string.format("info=%s schematic=%s output=%s",
            info and tostring(info.name) or "nil",
            schem and tostring(schem.name) .. "/" .. #(schem.reagentSlotSchematics or {}) .. "slots" or "nil",
            schem and tostring(schem.outputItemID) or "nil")
    end
    char.professions = r
    return r
end

---------------------------------------------------------------------------
-- 3/4/5. open trade skill scan
---------------------------------------------------------------------------

local function recipeLine(id)
    local info = first("C_TradeSkillUI.GetRecipeInfo", id)
    if not info then return id .. "|nil" end
    local cat = info.categoryID
    return table.concat({ id, tostring(info.name), tostring(cat), tostring(info.relativeDifficulty),
        info.learned and "L" or "U", tostring(info.numSkillUps), tostring(info.maxTrivialLevel),
        info.craftable and "C" or "-", tostring(info.sourceType), info.disabled and "D" or "-" }, "|")
end

local function categoryPath(catID)
    local parts, guard = {}, 0
    while catID and catID ~= 0 and guard < 6 do
        guard = guard + 1
        local c = first("C_TradeSkillUI.GetCategoryInfo", catID)
        if not c then break end
        table.insert(parts, 1, tostring(c.name) .. "#" .. catID)
        catID = c.parentCategoryID
    end
    return table.concat(parts, " > ")
end

local function sampleRecipe(id)
    local s = {}
    local info = first("C_TradeSkillUI.GetRecipeInfo", id)
    s.info = ser(info)
    local schem = first("C_TradeSkillUI.GetRecipeSchematic", id, false)
    if schem then
        local reag = {}
        for _, slot in ipairs(schem.reagentSlotSchematics or {}) do
            local r1 = slot.reagents and slot.reagents[1]
            reag[#reag + 1] = string.format("%sx%s(type=%s,req=%s)", tostring(r1 and r1.itemID),
                tostring(slot.quantityRequired), tostring(slot.reagentType), tostring(slot.required))
        end
        s.schematic = string.format("name=%s output=%s qty=%s-%s type=%s reagents=%s", tostring(schem.name),
            tostring(schem.outputItemID), tostring(schem.quantityMin), tostring(schem.quantityMax),
            tostring(schem.recipeType), table.concat(reag, ","))
    else
        s.schematic = "nil"
    end
    s.sourceText = packStr(call("C_TradeSkillUI.GetRecipeSourceText", id))
    s.cooldown = packStr(call("C_TradeSkillUI.GetRecipeCooldown", id))
    s.craftableCount = packStr(call("C_TradeSkillUI.GetCraftableCount", id))
    s.outputData = packStr(call("C_TradeSkillUI.GetRecipeOutputItemData", id))
    s.requirements = packStr(call("C_TradeSkillUI.GetRecipeRequirements", id))
    s.link = packStr(call("C_TradeSkillUI.GetRecipeLink", id))
    s.category = info and categoryPath(info.categoryID) or "?"
    return s
end

local function scanTradeSkill(reason)
    session.scanQueued = false
    local base = first("C_TradeSkillUI.GetBaseProfessionInfo")
    local child = first("C_TradeSkillUI.GetChildProfessionInfo")
    if not base or not base.professionID or base.professionID == 0 then
        logEvent("scan skipped (" .. tostring(reason) .. "): no open profession")
        return
    end
    local key = tostring(base.professionName or base.professionID)
    local s = { at = date("%Y-%m-%d %H:%M:%S"), reason = reason }
    s.base = ser(base)
    s.child = ser(child)
    s.childInfos = ser(first("C_TradeSkillUI.GetChildProfessionInfos"))
    s.ready = packStr(call("C_TradeSkillUI.IsTradeSkillReady"))
    s.linked = packStr(call("C_TradeSkillUI.IsTradeSkillLinked"))
    s.npcCrafting = packStr(call("C_TradeSkillUI.IsNPCCrafting"))
    s.showLearned = packStr(call("C_TradeSkillUI.GetShowLearned"))
    s.showUnlearned = packStr(call("C_TradeSkillUI.GetShowUnlearned"))
    s.nearFocus = base.profession and packStr(call("C_TradeSkillUI.IsNearProfessionSpellFocus", base.profession)) or "n/a"

    local okAll, all = call("C_TradeSkillUI.GetAllRecipeIDs")
    local okF, filtered = call("C_TradeSkillUI.GetFilteredRecipeIDs")
    local ids = (okAll and all[1]) or (okF and filtered[1]) or {}
    s.source = okAll and "GetAllRecipeIDs" or "GetFilteredRecipeIDs"
    s.countAll = okAll and #(all[1] or {}) or ("ERR " .. tostring(all))
    s.countFiltered = okF and #(filtered[1] or {}) or ("ERR " .. tostring(filtered))

    local learned, unlearned, cats, camp = 0, 0, {}, {}
    local lines = {}
    local firstLearned, firstUnlearned, firstCraftable = {}, {}, nil
    for _, id in ipairs(ids) do
        local info = first("C_TradeSkillUI.GetRecipeInfo", id)
        if info then
            if info.learned then learned = learned + 1 else unlearned = unlearned + 1 end
            local path = categoryPath(info.categoryID)
            cats[path] = (cats[path] or 0) + 1
            local lower = path:lower() .. " " .. tostring(info.name):lower()
            if lower:find("camp") or lower:find("blueprint") then
                camp[#camp + 1] = id
            end
            if info.learned and #firstLearned < 3 then firstLearned[#firstLearned + 1] = id end
            if not info.learned and #firstUnlearned < 3 then firstUnlearned[#firstUnlearned + 1] = id end
            if info.learned and info.craftable and not firstCraftable then
                local n = first("C_TradeSkillUI.GetCraftableCount", id)
                if n and n > 0 then firstCraftable = id end
            end
        end
        lines[#lines + 1] = recipeLine(id)
    end
    s.learned, s.unlearned = learned, unlearned
    s.categories = cats
    s.recipes = lines -- id|name|categoryID|difficulty|L/U|numSkillUps|maxTrivial|craftable|sourceType|disabled
    s.samples = {}
    for _, id in ipairs(firstLearned) do s.samples["L" .. id] = sampleRecipe(id) end
    for _, id in ipairs(firstUnlearned) do s.samples["U" .. id] = sampleRecipe(id) end
    s.campCandidates = {}
    for _, id in ipairs(camp) do s.campCandidates[tostring(id)] = sampleRecipe(id) end
    -- Cross-profession read: a recipe remembered from another profession.
    s.crossRead = {}
    for id, prof in pairs(db.knownRecipeSamples or {}) do
        if prof ~= key then
            local info = first("C_TradeSkillUI.GetRecipeInfo", id)
            s.crossRead[tostring(id)] = prof .. ": " .. (info and tostring(info.name) .. " learned=" .. tostring(info.learned) or "nil")
        end
    end
    db.knownRecipeSamples = db.knownRecipeSamples or {}
    if firstLearned[1] then db.knownRecipeSamples[firstLearned[1]] = key end

    char.scans = char.scans or {}
    char.scans[key] = s
    session.firstCraftable = firstCraftable
    -- Remember one reagent for the bank-count test.
    if firstCraftable and not db.sampleReagent then
        local schem = first("C_TradeSkillUI.GetRecipeSchematic", firstCraftable, false)
        local slot = schem and schem.reagentSlotSchematics and schem.reagentSlotSchematics[1]
        local r1 = slot and slot.reagents and slot.reagents[1]
        if r1 and r1.itemID then db.sampleReagent = r1.itemID end
    end
    if panel then panel:Refresh() end
    logEvent(string.format("scan %s (%s): ids=%d learned=%d unlearned=%d camp=%d via %s", key, tostring(reason),
        #ids, learned, unlearned, #camp, s.source))
    say(string.format("scanned %s: %d recipes (%d learned, %d unlearned), %d camp candidates.", key, #ids, learned,
        unlearned, #camp))
end

local function queueScan(reason)
    if session.scanQueued then return end
    session.scanQueued = true
    C_Timer.After(0.5, function() scanTradeSkill(reason) end)
end

---------------------------------------------------------------------------
-- 6. legacy
---------------------------------------------------------------------------

local function probeLegacy()
    local r = {}
    local consts = Constants and Constants.LegacyConsts
    local treeID = consts and consts.LEGACY_TREE_PROFESSIONS_ID or 1187
    local currencyID = consts and consts.LEGACY_POINTS_TRAIT_CURRENCY_ID or 4225
    local factionID = consts and consts.LEGACY_REWARD_TRACK_FACTION_ID or 2802
    r.treeID = treeID
    local configID = first("C_Traits.GetConfigIDByTreeID", treeID)
    r.configID = ser(configID)
    r.renown = packStr(call("C_MajorFactions.GetCurrentRenownLevel", factionID))
    r.majorFaction = packStr(call("C_MajorFactions.GetMajorFactionData", factionID))
    r.currencyInfo = packStr(call("C_CurrencyInfo.GetCurrencyInfo", currencyID))
    if configID then
        r.treeCurrency = packStr(call("C_Traits.GetTreeCurrencyInfo", configID, treeID, false))
        local okN, nodes = call("C_Traits.GetTreeNodes", treeID)
        r.nodeCount = okN and #(nodes[1] or {}) or packStr(okN, nodes)
        r.nodes = {}
        if okN then
            for i, nodeID in ipairs(nodes[1] or {}) do
                if i > 60 then break end
                local node = first("C_Traits.GetNodeInfo", configID, nodeID)
                if node then
                    local names = {}
                    for _, entryID in ipairs(node.entryIDs or {}) do
                        local entry = first("C_Traits.GetEntryInfo", configID, entryID)
                        local def = entry and entry.definitionID and first("C_Traits.GetDefinitionInfo", entry.definitionID)
                        local spellName = def and def.spellID and first("C_Spell.GetSpellName", def.spellID)
                        names[#names + 1] = tostring(def and def.overrideName or spellName)
                    end
                    r.nodes[#r.nodes + 1] = string.format("%d rank=%s/%s active=%s %s", nodeID, tostring(node.activeRank),
                        tostring(node.maxRanks), tostring(node.isActive), table.concat(names, "/"))
                end
            end
        end
    end
    char.legacy = r
end

---------------------------------------------------------------------------
-- 8. bank
---------------------------------------------------------------------------

local function countBag(bagID)
    local okS, slots = call("C_Container.GetContainerNumSlots", bagID)
    local n = okS and slots[1] or 0
    local stacks, items = 0, 0
    for slot = 1, n or 0 do
        local info = first("C_Container.GetContainerItemInfo", bagID, slot)
        if info then
            stacks = stacks + 1
            items = items + (info.stackCount or 1)
        end
    end
    return string.format("bag %s: slots=%s stacks=%d items=%d", tostring(bagID), tostring(n), stacks, items)
end

local function probeBank()
    local r = { at = date("%Y-%m-%d %H:%M:%S") }
    r.viewable = packStr(call("C_Bank.FetchViewableBankTypes"))
    r.anyViewable = packStr(call("C_Bank.AreAnyBankTypesViewable"))
    r.usePlayerBags = packStr(call("C_Bank.ShouldUsePlayerBagsInBank"))
    r.bags = {}
    if Enum.BankType then
        for name, bankType in pairs(Enum.BankType) do
            r[name .. ".canView"] = packStr(call("C_Bank.CanViewBank", bankType))
            r[name .. ".canUse"] = packStr(call("C_Bank.CanUseBank", bankType))
            r[name .. ".locked"] = packStr(call("C_Bank.FetchBankLockedReason", bankType))
            local okT, tabs = call("C_Bank.FetchPurchasedBankTabIDs", bankType)
            r[name .. ".tabs"] = packStr(okT, tabs)
            if okT and type(tabs[1]) == "table" then
                for _, bagID in ipairs(tabs[1]) do r.bags[#r.bags + 1] = name .. " " .. countBag(bagID) end
            end
        end
    end
    -- Classic-style bank container and bank bags.
    if Enum.BagIndex then
        for name, bagID in pairs(Enum.BagIndex) do
            if tostring(name):find("Bank") then r.bags[#r.bags + 1] = "BagIndex." .. name .. " " .. countBag(bagID) end
        end
    end
    char.bank = r
end

-- Can bank counts be read away from the bank? Compare GetItemCount variants for one item.
local function probeItemCount()
    local itemID = db.sampleReagent
    if not itemID then return end
    char.itemCount = {
        itemID = itemID,
        plain = packStr(call("C_Item.GetItemCount", itemID)),
        withBank = packStr(call("C_Item.GetItemCount", itemID, true)),
        withBankUsesReagent = packStr(call("C_Item.GetItemCount", itemID, true, false, true)),
        withAccount = packStr(call("C_Item.GetItemCount", itemID, true, false, true, true)),
        at = date("%Y-%m-%d %H:%M:%S") .. (session.bankOpen and " (bank open)" or " (bank closed)"),
    }
end

---------------------------------------------------------------------------
-- 1/9. replacing the default frame; key, micro button, spellbook, station
---------------------------------------------------------------------------

local function tradeSkillState()
    local base = first("C_TradeSkillUI.GetBaseProfessionInfo")
    return string.format("open=%s ready=%s", base and tostring(base.professionName) or "nil",
        tostring(first("C_TradeSkillUI.IsTradeSkillReady")))
end

local function restoreDefault()
    if ProfessionsFrame then
        ProfessionsFrame:SetAlpha(1)
        ProfessionsFrame:SetScale(1)
    end
end

local function applyMode(trigger)
    local mode = db.mode or "off"
    if mode == "off" or session.suspended or not ProfessionsFrame then return end
    if mode == "alpha" then
        ProfessionsFrame:SetAlpha(0)
    elseif mode == "scale" then
        ProfessionsFrame:SetAlpha(0)
        ProfessionsFrame:SetScale(0.01)
    elseif mode == "hide" then
        C_Timer.After(0, function()
            HideUIPanel(ProfessionsFrame)
            C_Timer.After(0.3, function() logEvent("after hide: " .. tradeSkillState()) end)
        end)
    end
    if panel then panel:Show() end
    logEvent(string.format("applied mode=%s trigger=%s %s", mode, tostring(trigger), tradeSkillState()))
end

local hookedFrame = false
local function onProfessionsFrameShow()
    local trigger = (GetTime() - session.lastTriggerAt < 1) and session.lastTrigger or "event/other"
    local book = ProfessionsFrame and ProfessionsFrame.BookPage and ProfessionsFrame.BookPage:IsShown()
    logEvent(string.format("ProfessionsFrame.Show trigger=%s bookPage=%s combat=%s %s", trigger, tostring(book),
        tostring(InCombatLockdown()), tradeSkillState()))
    if not hookedFrame and ProfessionsFrame then
        hookedFrame = true
        ProfessionsFrame:HookScript("OnHide", function()
            logEvent("ProfessionsFrame OnHide " .. tradeSkillState())
            restoreDefault()
            if panel and panel:IsShown() and (db.mode == "alpha" or db.mode == "scale") then panel:Hide() end
        end)
    end
    applyMode(trigger)
end

local function setTrigger(name)
    session.lastTrigger = name
    session.lastTriggerAt = GetTime()
    logEvent("trigger " .. name)
end

local function installHooks()
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("ProfessionsFrame.Show", onProfessionsFrameShow, session)
        EventRegistry:RegisterCallback("ProfessionsFrame.Hide", function() logEvent("EventRegistry ProfessionsFrame.Hide") end, session)
    end
    if type(ToggleProfessionsBook) == "function" then
        hooksecurefunc("ToggleProfessionsBook", function() setTrigger("ToggleProfessionsBook(key/micro)") end)
    end
    if type(ShowProfessionsFrame) == "function" then
        hooksecurefunc("ShowProfessionsFrame", function() logEvent("ShowProfessionsFrame called") end)
    end
    if ProfessionMicroButton then
        ProfessionMicroButton:HookScript("OnClick", function() setTrigger("ProfessionMicroButton") end)
    end
end

---------------------------------------------------------------------------
-- 2. crafting and opening a profession from addon code
---------------------------------------------------------------------------

local function craft(recipeID, qty, how)
    recipeID, qty = tonumber(recipeID), tonumber(qty) or 1
    if not recipeID then say("no recipe ID") return end
    local name = first("C_TradeSkillUI.GetRecipeInfo", recipeID)
    local before = tradeSkillState()
    if not first("C_TradeSkillUI.IsTradeSkillReady") then
        say("|cffff6060No profession is open.|r Open the recipe's profession first (spike mode alpha keeps it open behind this panel).")
    end
    local ok, err = call("C_TradeSkillUI.CraftRecipe", recipeID, qty)
    local line = string.format("CraftRecipe(%d, %d) via %s -> %s; %s; recipe=%s combat=%s", recipeID, qty, how,
        ok and "returned" or ("ERR " .. tostring(err)), before, name and tostring(name.name) or "nil",
        tostring(InCombatLockdown()))
    char.crafts = char.crafts or {}
    table.insert(char.crafts, date("%H:%M:%S") .. " " .. line)
    logEvent(line)
    say(line)
end

local function openTradeSkill(skillLineID, how)
    skillLineID = tonumber(skillLineID)
    if not skillLineID then say("no skill line ID") return end
    local ok, res = call("C_TradeSkillUI.OpenTradeSkill", skillLineID)
    local line = string.format("OpenTradeSkill(%d) via %s -> %s", skillLineID, how, packStr(ok, res))
    char.opens = char.opens or {}
    table.insert(char.opens, date("%H:%M:%S") .. " " .. line)
    logEvent(line)
    say(line)
end

---------------------------------------------------------------------------
-- spike panel
---------------------------------------------------------------------------

local function makeButton(parent, text, width)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 120, 22)
    b:SetText(text)
    return b
end

local function makeEdit(parent, width)
    local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    e:SetSize(width or 70, 20)
    e:SetAutoFocus(false)
    return e
end

local function firstProfession()
    local p = char.professions and char.professions.slots and char.professions.slots[1]
    return p
end

local function buildPanel()
    panel = CreateFrame("Frame", nil, UIParent, "BasicFrameTemplateWithInset")
    panel:SetSize(420, 330)
    panel:SetPoint("CENTER", 300, 0)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:SetFrameStrata("HIGH")
    panel:Hide()
    tinsert(UISpecialFrames, "TradebookSpikePanel")
    _G.TradebookSpikePanel = panel -- for UISpecialFrames (ESC); spike only

    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    panel.title:SetPoint("TOP", 0, -5)
    panel.title:SetText("Tradebook Spike")

    panel.status = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    panel.status:SetPoint("TOPLEFT", 14, -32)
    panel.status:SetWidth(390)
    panel.status:SetJustifyH("LEFT")

    local y = -70
    local lbl = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("TOPLEFT", 14, y)
    lbl:SetText("Recipe ID / qty:")
    panel.recipe = makeEdit(panel, 80)
    panel.recipe:SetPoint("LEFT", lbl, "RIGHT", 10, 0)
    panel.qty = makeEdit(panel, 40)
    panel.qty:SetPoint("LEFT", panel.recipe, "RIGHT", 10, 0)
    panel.qty:SetText("1")

    y = y - 30
    local craftBtn = makeButton(panel, "Craft (click)", 125)
    craftBtn:SetPoint("TOPLEFT", 14, y)
    craftBtn:SetScript("OnClick", function() craft(panel.recipe:GetText(), panel.qty:GetText(), "button click") end)
    local craftTimer = makeButton(panel, "Craft (timer)", 125)
    craftTimer:SetPoint("LEFT", craftBtn, "RIGHT", 6, 0)
    craftTimer:SetScript("OnClick", function()
        local id, q = panel.recipe:GetText(), panel.qty:GetText()
        C_Timer.After(1, function() craft(id, q, "C_Timer 1s after click (no hardware event)") end)
    end)
    local openDefault = makeButton(panel, "Open in default", 125)
    openDefault:SetPoint("LEFT", craftTimer, "RIGHT", 6, 0)
    openDefault:SetScript("OnClick", function()
        local id = tonumber(panel.recipe:GetText())
        session.suspended = true
        restoreDefault()
        local ok, err = call("C_TradeSkillUI.OpenRecipe", id)
        logEvent("OpenRecipe(" .. tostring(id) .. ") -> " .. packStr(ok, err))
    end)

    y = y - 30
    local defaultBtn = makeButton(panel, "Default UI", 125)
    defaultBtn:SetPoint("TOPLEFT", 14, y)
    defaultBtn:SetScript("OnClick", function()
        session.suspended = true
        restoreDefault()
        if ProfessionsFrame and not ProfessionsFrame:IsShown() and ShowProfessionsFrame then ShowProfessionsFrame() end
        logEvent("switched to Default UI " .. tradeSkillState())
        panel:Hide()
    end)
    local backBtn = makeButton(panel, "Back to spike", 125)
    backBtn:SetPoint("LEFT", defaultBtn, "RIGHT", 6, 0)
    backBtn:SetScript("OnClick", function()
        session.suspended = false
        applyMode("back button")
    end)
    local scanBtn = makeButton(panel, "Scan now", 125)
    scanBtn:SetPoint("LEFT", backBtn, "RIGHT", 6, 0)
    scanBtn:SetScript("OnClick", function() scanTradeSkill("button") end)

    y = y - 30
    local openBtn = makeButton(panel, "OpenTradeSkill (click)", 190)
    openBtn:SetPoint("TOPLEFT", 14, y)
    openBtn:SetScript("OnClick", function()
        local p = firstProfession()
        openTradeSkill(p and p.skillLine, "button click")
    end)
    local openTimer = makeButton(panel, "OpenTradeSkill (timer)", 190)
    openTimer:SetPoint("LEFT", openBtn, "RIGHT", 6, 0)
    openTimer:SetScript("OnClick", function()
        local p = firstProfession()
        C_Timer.After(1, function() openTradeSkill(p and p.skillLine, "C_Timer 1s after click") end)
    end)

    -- Secure fallback: our own secure button casting the profession spell.
    y = y - 30
    local cast = CreateFrame("Button", nil, panel, "SecureActionButtonTemplate, UIPanelButtonTemplate")
    cast:SetSize(190, 22)
    cast:SetPoint("TOPLEFT", 14, y)
    cast:RegisterForClicks("AnyUp", "AnyDown")
    cast:SetAttribute("type", "spell")
    cast:SetText("Cast profession (secure)")
    cast:HookScript("OnClick", function() setTrigger("secure cast button") end)
    panel.cast = cast

    -- Icon format test.
    y = y - 40
    local iconLbl = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    iconLbl:SetPoint("TOPLEFT", 14, y)
    iconLbl:SetText("Icon test:  PNG(.png)   PNG(no ext)   TGA")
    local paths = {
        "Interface\\AddOns\\TradebookSpike\\media\\icon_png.png",
        "Interface\\AddOns\\TradebookSpike\\media\\icon_png",
        "Interface\\AddOns\\TradebookSpike\\media\\icon_tga",
    }
    for i, p in ipairs(paths) do
        local t = panel:CreateTexture(nil, "ARTWORK")
        t:SetSize(40, 40)
        t:SetPoint("TOPLEFT", 120 + (i - 1) * 70, y - 16)
        t:SetColorTexture(1, 0, 1, 1) -- magenta shows if the file fails to load
        t:SetTexture(p)
    end

    function panel:Refresh()
        local p = firstProfession()
        self.status:SetText(string.format("mode=%s  %s\nfirst profession=%s (skillLine %s)  firstCraftable=%s",
            tostring(db.mode), tradeSkillState(), p and tostring(p.name) or "none", p and tostring(p.skillLine) or "-",
            tostring(session.firstCraftable)))
        if session.firstCraftable and self.recipe:GetText() == "" then
            self.recipe:SetText(tostring(session.firstCraftable))
        end
        if not InCombatLockdown() and p and p.spellID then
            self.cast:SetAttribute("spell", p.spellID)
        end
    end
    panel:SetScript("OnShow", panel.Refresh)
    panel:SetScript("OnHide", function()
        -- Closing the spike also closes the hidden default window, as Tradebook would.
        if ProfessionsFrame and ProfessionsFrame:IsShown() and (db.mode == "alpha" or db.mode == "scale")
            and not session.suspended then
            HideUIPanel(ProfessionsFrame)
        end
    end)
end

---------------------------------------------------------------------------
-- events
---------------------------------------------------------------------------

local LOGGED = {
    "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGING",
    "TRADE_SKILL_DATA_SOURCE_CHANGED", "TRADE_SKILL_DETAILS_UPDATE", "TRADE_SKILL_NAME_UPDATE", "SKILL_LINES_CHANGED",
    "NEW_RECIPE_LEARNED", "TRADE_SKILL_CRAFT_BEGIN", "TRADE_SKILL_ITEM_CRAFTED_RESULT", "UPDATE_TRADESKILL_CAST_STOPPED",
    "OPEN_RECIPE_RESPONSE", "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYERBANKSLOTS_CHANGED", "BANK_TABS_CHANGED",
    "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED", "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN", "UI_ERROR_MESSAGE",
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
    "TRAIT_CONFIG_UPDATED", "ADDON_LOADED",
}
local QUIET = { TRADE_SKILL_LIST_UPDATE = true, PLAYERBANKSLOTS_CHANGED = true, PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED = true }

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        session.started = GetTime()
        TradebookSpikeDB = TradebookSpikeDB or {}
        db = TradebookSpikeDB
        db.events = db.events or {}
        db.chars = db.chars or {}
        db.mode = db.mode or "off"
        local name, realm = UnitFullName("player")
        charKey = tostring(name) .. "-" .. tostring(realm or GetRealmName())
        db.chars[charKey] = db.chars[charKey] or {}
        char = db.chars[charKey]
        char.lastLogin = date("%Y-%m-%d %H:%M:%S")
        logEvent("---- login " .. charKey .. " build " .. select(2, GetBuildInfo()))
        for _, ev in ipairs(LOGGED) do pcall(f.RegisterEvent, f, ev) end
        installHooks()
        buildPanel()
        C_Timer.After(3, function()
            probeIdentity()
            probeApis()
            probeProfessions()
            probeLegacy()
            probeItemCount()
            say("probes saved. /tbs for commands. Mode: " .. tostring(db.mode))
        end)
        return
    end

    local unit = ...
    if event:find("^UNIT_SPELLCAST") and unit ~= "player" then return end
    if event == "ADDON_LOADED" then
        if unit ~= "Blizzard_Professions" and unit ~= "Blizzard_ProfessionsBook" and unit ~= "Blizzard_LegacySystem" then return end
    end
    if not QUIET[event] then
        local args = {}
        for i = 1, select("#", ...) do args[#args + 1] = ser((select(i, ...))) end
        logEvent(event .. "(" .. table.concat(args, ", ") .. ")")
    end
    if event == "TRADE_SKILL_SHOW" then
        if GetTime() - session.lastTriggerAt > 1 then setTrigger("TRADE_SKILL_SHOW (spellbook/station/cast)") end
        queueScan("show")
    elseif event == "TRADE_SKILL_LIST_UPDATE" or event == "TRADE_SKILL_DATA_SOURCE_CHANGED" then
        queueScan(event)
    elseif event == "TRADE_SKILL_CLOSE" then
        if panel then panel:Refresh() end
    elseif event == "SKILL_LINES_CHANGED" or event == "NEW_RECIPE_LEARNED" then
        probeProfessions()
    elseif event == "BANKFRAME_OPENED" then
        session.bankOpen = true
        C_Timer.After(1, function() probeBank(); probeItemCount() end)
    elseif event == "BANKFRAME_CLOSED" then
        session.bankOpen = false
        C_Timer.After(0.5, probeItemCount)
    elseif event == "TRAIT_CONFIG_UPDATED" then
        probeLegacy()
    end
end)

---------------------------------------------------------------------------
-- slash
---------------------------------------------------------------------------

SLASH_TRADEBOOKSPIKE1 = "/tbs"
SlashCmdList.TRADEBOOKSPIKE = function(msg)
    local cmd, a, b = strsplit(" ", (msg or ""):lower())
    if cmd == "mode" and (a == "off" or a == "alpha" or a == "scale" or a == "hide") then
        db.mode = a
        session.suspended = false
        if a == "off" then restoreDefault() end
        say("mode = " .. a)
    elseif cmd == "panel" then
        panel:SetShown(not panel:IsShown())
    elseif cmd == "scan" then
        scanTradeSkill("slash")
    elseif cmd == "craft" then
        craft(a, b, "slash command")
    elseif cmd == "open" then
        openTradeSkill(a or (firstProfession() and firstProfession().skillLine), "slash command")
    elseif cmd == "unlearned" then
        call("C_TradeSkillUI.SetShowLearned", true)
        call("C_TradeSkillUI.SetShowUnlearned", true)
        say("show learned+unlearned set; rescanning shortly")
        C_Timer.After(1.5, function() scanTradeSkill("unlearned toggle") end)
    elseif cmd == "report" then
        probeIdentity(); probeApis(); probeProfessions(); probeLegacy(); probeItemCount()
        say("probes refreshed. /reload to write them to disk.")
    elseif cmd == "reset" then
        TradebookSpikeDB = nil
        say("data cleared; /reload")
    else
        say("commands:")
        say("/tbs mode off|alpha|scale|hide  - how to treat the default Professions window")
        say("/tbs panel  - show the spike panel (craft, open, default UI, icon test)")
        say("/tbs scan  - scan the open profession   /tbs unlearned - include unlearned recipes")
        say("/tbs craft <recipeID> <qty>  /tbs open [skillLineID]  /tbs report  /tbs reset")
    end
end
