-- TransmuteReminder: click-to-craft and the right-click menu.
--
-- Blizzard only lets addons craft while that profession's window is open. So
-- the first left-click opens the profession to the chosen recipe, and the next
-- left-click crafts it. If the addon opened the window, it closes it again once
-- the craft goes through.
--
-- Each cooldown group remembers which of its recipes to craft (for the Arcanite
-- group: Arcanite, Earth to Water, and so on). The right-click menu changes it.
-- Nothing here runs in combat.

local _, ns = ...

ns.focusKey = nil         -- cooldown group the player picked in the menu; shown first
ns.awaitingCraft = nil    -- recipe whose window we opened; the next click crafts it
ns.openedForCraft = nil   -- recipe we opened the window for, so we can close it after
ns.tradeOpen = false      -- a profession window is open

---------------------------------------------------------------------------
-- Recipe details (captured while the profession window is open)
---------------------------------------------------------------------------

local function item_icon(itemID)
    if C_Item and C_Item.GetItemIconByID then
        local ok, icon = pcall(C_Item.GetItemIconByID, itemID)
        if ok and icon then return icon end
    end
    if GetItemIcon then return GetItemIcon(itemID) end
end

local function item_name(itemID)
    if C_Item and C_Item.GetItemNameByID then
        local ok, name = pcall(C_Item.GetItemNameByID, itemID)
        if ok and type(name) == "string" then return name end
    end
    if GetItemInfo then
        local name = GetItemInfo(itemID)
        if type(name) == "string" then return name end
    end
end

local function item_count(itemID)
    local fn = (C_Item and C_Item.GetItemCount) or GetItemCount
    if not fn then return nil end
    local ok, n = pcall(fn, itemID)
    if ok and type(n) == "number" then return n end
end

-- The result item and reagents of a recipe, or nil. Called by the scan.
function ns.recipe_details(id)
    local ui = C_TradeSkillUI
    if not (ui and ui.GetRecipeSchematic) then return nil end
    local ok, sch = pcall(ui.GetRecipeSchematic, id, false)
    if not ok or type(sch) ~= "table" then return nil end
    local d = {}
    if type(sch.outputItemID) == "number" then
        d.output = sch.outputItemID
        d.outIcon = item_icon(sch.outputItemID)
    end
    local reagents = {}
    for _, slot in ipairs(sch.reagentSlotSchematics or {}) do
        local r = type(slot.reagents) == "table" and slot.reagents[1]
        local need = slot.quantityRequired or 0
        if r and type(r.itemID) == "number" and need > 0 and slot.required ~= false then
            reagents[#reagents + 1] = { itemID = r.itemID, count = need }
        end
    end
    if #reagents > 0 then d.reagents = reagents end
    return d
end

---------------------------------------------------------------------------
-- Groups and picks
---------------------------------------------------------------------------

local function me() return ns.me end

-- Learned recipes sharing a cooldown group, the representative first.
function ns.GroupRecipes(key)
    local entry = me().cooldowns[key]
    local repID = entry and entry.recipeID
    local list = {}
    for id, rec in pairs(me().recipes) do
        if rec.group == key then list[#list + 1] = { id = id, rec = rec } end
    end
    table.sort(list, function(a, b)
        if a.id == repID then return true end
        if b.id == repID then return false end
        return (a.rec.name or "") < (b.rec.name or "")
    end)
    return list
end

-- The recipe left-click crafts for a cooldown group.
function ns.GetPick(key)
    local picks = me().picks
    local id = picks and picks[key]
    local rec = id and me().recipes[id]
    if rec and rec.group == key then return id end
    local entry = me().cooldowns[key]
    return entry and entry.recipeID
end

function ns.SetPick(key, id)
    me().picks[key] = id
    ns.focusKey = key
    ns.awaitingCraft = nil
    ns.Update()
end

-- Display name and icon for a recipe: the result item when known.
function ns.RecipeDisplay(id)
    local rec = me().recipes[id] or {}
    local name = rec.output and item_name(rec.output)
    if not name then
        name = ns.short_label({ name = rec.name or tostring(id), transmute = rec.transmute })
    end
    return name, rec.outIcon or rec.icon
end

-- Reagents you are short of: list of { name, have, need }. Empty when you have
-- everything; nil when the reagents are not known.
function ns.MissingReagents(id)
    local rec = me().recipes[id]
    if not rec or not rec.reagents then return nil end
    local missing = {}
    for _, r in ipairs(rec.reagents) do
        local have = item_count(r.itemID)
        if have and have < r.count then
            missing[#missing + 1] = { name = item_name(r.itemID) or ("item " .. r.itemID), have = have, need = r.count }
        end
    end
    return missing
end

-- What left-click would craft for the reminder's main item, or nil.
function ns.CraftInfo(item)
    local s = ns.s
    if not (s and s.clickCrafts) or not item or item.fake or item.char then return nil end
    local id = ns.GetPick(item.key)
    if not id then return nil end
    local name, icon = ns.RecipeDisplay(id)
    local missing = ns.MissingReagents(id)
    return {
        id = id,
        name = name,
        icon = icon,
        transmute = item.transmute,
        missing = (missing and #missing > 0) and missing or nil,
        awaiting = ns.awaitingCraft == id,
    }
end

---------------------------------------------------------------------------
-- Crafting
---------------------------------------------------------------------------

local function recipe_in_open_window(id)
    if not ns.tradeOpen then return false end
    if ProfessionsFrame and ProfessionsFrame.IsShown and not ProfessionsFrame:IsShown() then return false end
    local ui = C_TradeSkillUI
    if ui and ui.GetAllRecipeIDs then
        local ok, ids = pcall(ui.GetAllRecipeIDs)
        if ok and type(ids) == "table" then
            for _, rid in ipairs(ids) do
                if rid == id then return true end
            end
        end
    end
    return false
end

local function open_recipe(id)
    if C_TradeSkillUI and C_TradeSkillUI.OpenRecipe then
        return (pcall(C_TradeSkillUI.OpenRecipe, id))
    end
    return false
end

local function missing_text(missing)
    local parts = {}
    for _, m in ipairs(missing) do
        parts[#parts + 1] = string.format("%s (%d/%d)", m.name, m.have, m.need)
    end
    return table.concat(parts, ", ")
end
ns.missing_text = missing_text

-- Left-click on the reminder. Returns true if it handled the click.
function ns.Craft(item)
    if InCombatLockdown() then return true end
    local info = ns.CraftInfo(item)
    if not info then return false end

    if info.missing then
        ns.print("missing reagents for " .. info.name .. ": " .. missing_text(info.missing) .. ".")
        open_recipe(info.id)
        return true
    end

    if not recipe_in_open_window(info.id) then
        if open_recipe(info.id) then
            ns.awaitingCraft = info.id
            ns.openedForCraft = info.id
            ns.Update()
        else
            ns.print("couldn't open the profession window. Open it yourself and click again.")
        end
        return true
    end

    ns.awaitingCraft = nil
    local ok, err = pcall(C_TradeSkillUI.CraftRecipe, info.id, 1)
    if not ok then
        ns.print("crafting failed: " .. tostring(err))
    end
    ns.Update()
    return true
end

-- Called by Core after a successful cast.
function ns.OnCraftCast(spellID)
    if ns.openedForCraft and spellID == ns.openedForCraft then
        ns.openedForCraft = nil
        if C_TradeSkillUI and C_TradeSkillUI.CloseTradeSkill then
            pcall(C_TradeSkillUI.CloseTradeSkill)
        end
    end
end

function ns.OnTradeSkillClosed()
    ns.tradeOpen = false
    ns.awaitingCraft = nil
    ns.openedForCraft = nil
    ns.Update()
end

---------------------------------------------------------------------------
-- Right-click menu
---------------------------------------------------------------------------

local function icon_text(icon, text)
    if icon then return "|T" .. icon .. ":16:16:0:0|t " .. text end
    return text
end

function ns.OpenMenu(owner)
    if InCombatLockdown() then return end
    if not (MenuUtil and MenuUtil.CreateContextMenu) then
        ns.Snooze()
        return
    end
    local s = ns.s
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle("TransmuteReminder")
        local own = ns.ready_own()
        for _, it in ipairs(own) do
            local recipes = ns.GroupRecipes(it.key)
            if #recipes > 0 and s.clickCrafts then
                root:CreateDivider()
                root:CreateTitle((it.transmute and "Transmute" or ns.short_label(it)) .. ": choose what to craft")
                for _, r in ipairs(recipes) do
                    local name, icon = ns.RecipeDisplay(r.id)
                    local missing = ns.MissingReagents(r.id)
                    local label = icon_text(icon, ns.escape_pipes(name))
                    if missing and #missing > 0 then
                        label = label .. "  |cffff6666(missing reagents)|r"
                    end
                    local key, id = it.key, r.id
                    root:CreateRadio(label,
                        function() return ns.GetPick(key) == id end,
                        function() ns.SetPick(key, id) end)
                end
            end
        end
        root:CreateDivider()
        if s.snoozeMinutes > 0 then
            root:CreateButton(string.format("Snooze %d minutes", s.snoozeMinutes), function() ns.Snooze() end)
        end
        root:CreateButton("Dismiss", function() ns.Dismiss() end)
        if #own > 0 then
            root:CreateButton("Open profession", function() ns.OpenProfession() end)
        end
        root:CreateButton("Options", function() ns.OpenOptions() end)
    end)
end
