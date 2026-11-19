-- Core/Planner.lua
-- PURE. Leveling planner: a sure way to raise a profession from the current skill to a target
-- (normally the cap), one skill point at a time, as cheap as that can be.
--
-- Orange recipes always give a skill-up, so the plan uses them whenever one can give the point:
-- one craft per point, and following the plan gets you there. Only where no orange recipe is
-- left does it fall back to yellow or green (a chance, not a promise); those steps are marked
-- sure = false. At each skill point it picks, in this order:
--   1. an orange recipe you can make from what you have (bags and bank, nothing to buy). The
--      one whose materials are worth least goes first.
--   2. the cheapest orange recipe: what you'd buy at its price, plus OWNED_WEIGHT of the price
--      of what you have (using it up isn't quite free: it could make another point later).
--      Owned materials without a price count as free.
--   3. only when no orange recipe can give the point: the lowest expected cost per point of a
--      yellow or green one; chance (grey - skill) / (grey - yellow), the usual classic
--      estimate, expected crafts per point = 1 / chance; ties go to the higher chance.
--   Within each, recipes with materials to buy that have no price come after the priced ones
--   (fewest of those materials first).
-- The bill (step cost, total) only counts what you have to buy: owned materials are used first.
-- Consecutive points from the same recipe (and equally sure) are merged into one step.

local _, ns = ...

local Planner = {}
ns.Planner = Planner

Planner.OWNED_WEIGHT = 0.25 -- what using up a material you have counts, against buying it

-- PURE. Chance of a skill-up at `rank` for thresholds { yellow, green, grey }.
function Planner.Chance(t, rank)
    if not t then return 0 end
    local yellow, grey = t[1], t[3]
    if rank >= grey then return 0 end
    if rank < yellow then return 1 end
    if grey <= yellow then return 0 end
    return (grey - rank) / (grey - yellow)
end

-- opts:
--   rank, target          skill now, and where to stop (exclusive: plans rank .. target-1)
--   recipes               { recipeID, ... } candidates
--   thresholds(id)        { yellow, green, grey } or nil
--   reagents(id)          { { itemID, count }, ... }
--   price(itemID)         copper per item, or nil when unknown
--   inventory             { [itemID] = count } you have (used first, free); copied, not changed
--   learnAt(id)           optional: skill needed to learn it (recipes not known yet), or nil
--   noPrices              true: rank by number of materials instead of cost
-- Returns { steps = { { recipeID, from, to, crafts, cost, unpriced, learn, sure,
--                       materials = { [itemID] = { need, have } } (this step's share) } },
--           materials = { [itemID] = { need, have } }, cost, unpriced, reached, sure }
-- sure: every point from an orange recipe (a step's sure: that step's).
function Planner.Plan(opts)
    local inv = {}
    for k, v in pairs(opts.inventory or {}) do inv[k] = v end
    local startInv = {}
    for k, v in pairs(inv) do startInv[k] = v end

    -- Cost of `crafts` crafts of a recipe with the current inventory (without using it up).
    local function costOf(id, crafts)
        local total, unpricedUnits = 0, 0
        for _, r in ipairs(opts.reagents(id)) do
            local need = r.count * crafts
            local buy = math.max(0, need - (inv[r.itemID] or 0))
            if opts.noPrices then
                total = total + buy
            elseif buy > 0 then
                local p = opts.price(r.itemID)
                if p then total = total + p * buy else unpricedUnits = unpricedUnits + buy end
            end
        end
        return total, unpricedUnits > 0, unpricedUnits
    end

    -- Use up materials for `crafts` crafts (what you have first), adding to the totals.
    local function useUp(id, crafts, materials)
        for _, r in ipairs(opts.reagents(id)) do
            local need = r.count * crafts
            local m = materials[r.itemID]
            if not m then
                m = { need = 0, have = startInv[r.itemID] or 0 }
                materials[r.itemID] = m
            end
            m.need = m.need + need
            inv[r.itemID] = math.max(0, (inv[r.itemID] or 0) - need)
        end
    end

    -- For choosing: what `crafts` crafts cost to buy and what they use up of what you have
    -- (at its price; noPrices: numbers of materials), and the units to buy with no price.
    local function split(id, crafts)
        local buyCost, ownedValue, unpricedUnits = 0, 0, 0
        for _, r in ipairs(opts.reagents(id)) do
            local need = r.count * crafts
            local owned = math.min(need, inv[r.itemID] or 0)
            local buy = need - owned
            if opts.noPrices then
                buyCost, ownedValue = buyCost + buy, ownedValue + owned
            else
                local p = opts.price(r.itemID)
                if p then
                    buyCost, ownedValue = buyCost + p * buy, ownedValue + p * owned
                else
                    unpricedUnits = unpricedUnits + buy
                end
            end
        end
        return buyCost, ownedValue, unpricedUnits
    end

    local steps, materials = {}, {}
    local totalCost, anyUnpriced, allSure = 0, false, true
    local rank = opts.rank
    while rank < opts.target do
        local best, bestScore, bestOrange, bestChance, bestCrafts
        for _, id in ipairs(opts.recipes) do
            local learnAt = opts.learnAt and opts.learnAt(id)
            if not learnAt or learnAt <= rank then
                local t = opts.thresholds(id)
                local chance = Planner.Chance(t, rank)
                if chance > 0 then
                    local crafts = 1 / chance
                    local buyCost, ownedValue, unpricedUnits = split(id, crafts)
                    local orange = rank < t[1]
                    -- Tiers: 0 orange from what you have, 1 orange priced, 2 orange with
                    -- unpriced materials, 3 yellow/green priced, 4 yellow/green unpriced.
                    local tier, value
                    if orange and buyCost == 0 and unpricedUnits == 0 then
                        tier, value = 0, ownedValue
                    else
                        tier = (orange and 1 or 3) + (unpricedUnits > 0 and 1 or 0)
                        value = unpricedUnits * 1e9 + buyCost + ownedValue * Planner.OWNED_WEIGHT
                    end
                    local score = tier * 1e15 + value
                    local better = not best or score < bestScore - 1e-6
                    if not better and math.abs(score - bestScore) <= 1e-6 then
                        better = (orange and not bestOrange) or (orange == bestOrange and chance > bestChance)
                    end
                    if better then
                        best, bestScore, bestOrange, bestChance, bestCrafts = id, score, orange, chance, crafts
                    end
                end
            end
        end
        if not best then break end -- nothing gives skill-ups any more
        local bestCost, bestUnpriced = costOf(best, bestCrafts)
        useUp(best, bestCrafts, materials)
        local last = steps[#steps]
        if last and last.recipeID == best and last.sure == bestOrange then
            last.to = rank + 1
            last.crafts = last.crafts + bestCrafts
            last.cost = last.cost + bestCost
            last.unpriced = last.unpriced or bestUnpriced
        else
            steps[#steps + 1] = { recipeID = best, from = rank, to = rank + 1, crafts = bestCrafts,
                cost = bestCost, unpriced = bestUnpriced, learn = opts.learnAt and opts.learnAt(best) ~= nil,
                sure = bestOrange }
        end
        if not opts.noPrices then totalCost = totalCost + bestCost end
        anyUnpriced = anyUnpriced or bestUnpriced
        allSure = allSure and bestOrange
        rank = rank + 1
    end
    -- Each step's materials, on its own: what its whole crafts need, everything you have, and
    -- what to buy for just this step (earlier steps aren't counted; the totals below are the
    -- whole plan's).
    for _, s in ipairs(steps) do
        s.crafts = math.ceil(s.crafts - 1e-9)
        s.materials = {}
        for _, r in ipairs(opts.reagents(s.recipeID)) do
            local m = s.materials[r.itemID]
            if not m then
                m = { need = 0, have = startInv[r.itemID] or 0 }
                s.materials[r.itemID] = m
            end
            m.need = m.need + r.count * s.crafts
            m.buy = math.max(0, m.need - m.have)
        end
    end
    for _, m in pairs(materials) do
        m.need = math.ceil(m.need - 1e-9)
        m.buy = math.max(0, m.need - m.have)
    end
    return { steps = steps, materials = materials, cost = totalCost, unpriced = anyUnpriced,
        reached = rank, target = opts.target, sure = allSure }
end
