-- Data/Camp.lua
-- PURE. Recipe categories that hold campsite recipes. Seen in game on 1.60.1:
-- each profession has a "Camping" subcategory. Category IDs make the check work in
-- any language; the name check catches professions not listed yet, and new IDs
-- found at runtime are remembered in TradebookDB.campCategories.

local _, ns = ...

local Camp = {}
ns.Camp = Camp

Camp.categoryIDs = {
    [2591] = 197, -- Tailoring > Camping
    [2714] = 185, -- Cooking > Camping
    [2514] = 333, -- Enchanting > Camping
    [2715] = 356, -- Fishing > Camping
}

Camp.categoryName = "Camping" -- enUS; other locales rely on IDs

-- Is this category (or its parent) a camping category?
-- known: optional table of extra IDs learned at runtime.
function Camp.IsCampCategory(categoryID, categoryName, parentID, known)
    if Camp.categoryIDs[categoryID] or Camp.categoryIDs[parentID] then return true end
    if known and (known[categoryID] or known[parentID]) then return true end
    return categoryName == Camp.categoryName
end
