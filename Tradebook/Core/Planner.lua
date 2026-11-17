-- Core/Planner.lua
-- PURE. Leveling planner: the cheapest way to raise a profession from the current skill to a
-- target (normally the cap), one skill point at a time.
--
-- At each skill point it picks, in this order:
--   1. an orange recipe you can make from what you have (bags and bank, nothing to buy): a sure
--      skill-up for free. The one whose materials are worth least goes first.
--   2. otherwise the lowest expected cost per point:
--        chance of a skill-up: orange 100%; yellow and green (grey - skill) / (grey - yellow),
--          the usual classic estimate; grey 0. Expected crafts per point = 1 / chance.
--        cost: what you'd buy at its price, plus OWNED_WEIGHT of the price of what you have
--          (using it up isn't quite free: it could make another point later). Owned materials
--          without a price count as free.
--        a yellow or green recipe's cost is weighed up by ORANGE_BONUS (a skill-up from it is
--          never sure); ties go to orange, then the higher chance.
--      Unpriced materials to buy make the recipe unpriced: it's only picked when no priced
--      recipe can give the point.
-- The bill (step cost, total) only counts what you have to buy: owned materials are used first.
-- Consecutive points from the same recipe are merged into one step.
-- Estimates, not guarantees: skill-ups are random.

local _, ns = ...

local Planner = {}
ns.Planner = Planner

Planner.ORANGE_BONUS = 4 / 3 -- yellow/green must be under 3/4 of orange's cost per point
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
-- Returns { steps = { { recipeID, from, to, crafts, cost, unpriced, learn,
--                       materials = { [itemID] = { need, have } } (this step's share) } },
--           materials = { [itemID] = { need, have } }, cost, unpriced, reached }
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
    local totalCost, anyUnpriced = 0, false
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
                    local score
                    if orange and buyCost == 0 and unpricedUnits == 0 then
                        score = -1e15 + ownedValue -- 1. orange from what you have
                    else
                        local value = buyCost + ownedValue * Planner.OWNED_WEIGHT
                        if not orange then value = value * Planner.ORANGE_BONUS end
                        -- Recipes needing materials with no known price sort after every
                        -- priced one, fewest of those materials first.
                        score = (unpricedUnits > 0 and (1e15 + unpricedUnits * 1e6) or 0) + value
                    end
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
        if last and last.recipeID == best then
            last.to = rank + 1
            last.crafts = last.crafts + bestCrafts
            last.cost = last.cost + bestCost
            last.unpriced = last.unpriced or bestUnpriced
        else
            steps[#steps + 1] = { recipeID = best, from = rank, to = rank + 1, crafts = bestCrafts,
                cost = bestCost, unpriced = bestUnpriced, learn = opts.learnAt and opts.learnAt(best) ~= nil }
        end
        if not opts.noPrices then totalCost = totalCost + bestCost end
        anyUnpriced = anyUnpriced or bestUnpriced
        rank = rank + 1
    end
    -- Each step's materials: what its whole crafts need, and how many of them you have, taking
    -- from what you have in step order (whole crafts, so a step never shows a fraction of an
    -- item as missing that the totals say you have).
    local left = {}
    for k, v in pairs(startInv) do left[k] = v end
    for _, s in ipairs(steps) do
        s.crafts = math.ceil(s.crafts - 1e-9)
        s.materials = {}
        for _, r in ipairs(opts.reagents(s.recipeID)) do
            local need = r.count * s.crafts
            local have = math.min(need, left[r.itemID] or 0)
            left[r.itemID] = (left[r.itemID] or 0) - have
            local m = s.materials[r.itemID]
            if m then
                m.need, m.have = m.need + need, m.have + have
            else
                s.materials[r.itemID] = { need = need, have = have }
            end
        end
    end
    for _, m in pairs(materials) do m.need = math.ceil(m.need - 1e-9) end
    return { steps = steps, materials = materials, cost = totalCost, unpriced = anyUnpriced,
        reached = rank, target = opts.target }
end
