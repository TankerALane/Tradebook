-- Core/Planner.lua
-- PURE. Leveling planner: the cheapest way to raise a profession from the current skill to a
-- target (normally the cap), one skill point at a time.
--
-- At each skill point it picks the recipe with the lowest expected cost per point:
--   chance of a skill-up: orange 100%; yellow and green (grey - skill) / (grey - yellow), the
--     usual classic estimate; grey 0. Expected crafts per point = 1 / chance.
--   cost of a craft, for choosing: every material at its unit price, also the ones in your
--     bags and bank (using them up isn't free: they could make another point or be sold).
--     Owned materials without a price count as free. The bill (step cost, total) only counts
--     what you have to buy: owned materials are used first.
--   orange first: a yellow or green recipe's expected cost is weighed up by ORANGE_BONUS, so
--     it only wins when it is clearly cheaper (a skill-up from it is never sure).
--   Unpriced materials to buy make the recipe unpriced: it's only picked when no priced
--     recipe can give the point.
-- Consecutive points from the same recipe are merged into one step.
-- Estimates, not guarantees: skill-ups are random.

local _, ns = ...

local Planner = {}
ns.Planner = Planner

Planner.ORANGE_BONUS = 4 / 3 -- yellow/green must be under 3/4 of orange's cost per point

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
-- Returns { steps = { { recipeID, from, to, crafts, cost, unpriced, learn } },
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

    -- What a craft uses up, for choosing: all its materials at their price (owned ones too).
    -- noPrices: the number of materials. Unpriced ones you'd have to buy make it unpriced.
    local function valueOf(id, crafts)
        local total, unpricedUnits = 0, 0
        for _, r in ipairs(opts.reagents(id)) do
            local need = r.count * crafts
            if opts.noPrices then
                total = total + need
            else
                local p = opts.price(r.itemID)
                if p then
                    total = total + p * need
                else
                    unpricedUnits = unpricedUnits + math.max(0, need - (inv[r.itemID] or 0))
                end
            end
        end
        return total, unpricedUnits > 0, unpricedUnits
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
                    local value, unpriced, unpricedUnits = valueOf(id, crafts)
                    local orange = rank < t[1]
                    if not orange then value = value * Planner.ORANGE_BONUS end
                    -- Recipes needing materials with no known price sort after every priced
                    -- one, fewest of those materials first; then value per point; then the
                    -- surer skill-up (orange, then the higher chance).
                    local score = (unpriced and (1e15 + unpricedUnits * 1e6) or 0) + value
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
    for _, s in ipairs(steps) do s.crafts = math.ceil(s.crafts - 1e-9) end
    for _, m in pairs(materials) do m.need = math.ceil(m.need - 1e-9) end
    return { steps = steps, materials = materials, cost = totalCost, unpriced = anyUnpriced,
        reached = rank, target = opts.target }
end
