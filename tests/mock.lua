-- Minimal WoW API mock to run TransmuteReminder's files and exercise the main flows.
local M = {}

local function newobj(kind)
    local o = { __kind = kind, __scripts = {}, __text = "", __shown = true, __checked = false, __value = 0 }
    return setmetatable(o, { __index = function(t, k)
        if type(k) == "string" and k:sub(1, 2) ~= "__" then
            return function(self, ...) return M.method(self, k, ...) end
        end
    end })
end

function M.method(self, k, ...)
    local a = { ... }
    if k == "SetScript" then self.__scripts[a[1]] = a[2]; return end
    if k == "GetScript" then return self.__scripts[a[1]] end
    if k == "SetText" then self.__text = a[1]; return end
    if k == "GetText" then return self.__text end
    if k == "GetStringWidth" then return #tostring(self.__text) * 8 end
    if k == "GetStringHeight" then return 14 end
    if k == "Show" then self.__shown = true; return end
    if k == "Hide" then self.__shown = false; return end
    if k == "IsShown" or k == "IsVisible" then return self.__shown end
    if k == "HasFocus" then return self.__focus or false end
    if k == "GetFrameLevel" then return 5 end
    if k == "SetChecked" then self.__checked = a[1]; return end
    if k == "GetChecked" then return self.__checked end
    if k == "SetValue" then self.__value = a[1]; return end
    if k == "GetValue" then return self.__value end
    if k == "GetCenter" then return 500, 400 end
    if k == "GetEffectiveScale" then return 1 end
    if k == "GetWidth" then return 140 end
    if k == "GetPoint" then return "CENTER", nil, "BOTTOMLEFT", 500, 400 end
    if k == "GetColorRGB" then return 0.2, 0.4, 0.6 end
    if k:match("^Create") or k == "GetThumbTexture" then return newobj(k) end
    if k == "RegisterEvent" or k == "RegisterUnitEvent" then
        self.__events = self.__events or {}
        self.__events[a[1]] = true
        return
    end
    return nil
end

function M.install(opts)
    opts = opts or {}
    local now = opts.keepTime and M.now() or 1800000000
    local clock = opts.keepTime and 1000 + (now - 1800000000) or 1000
    M.now = function() return now end
    M.advance = function(sec) now = now + sec; clock = clock + sec end

    M.timers = {}
    C_Timer = {
        After = function(sec, fn) table.insert(M.timers, { at = now + sec, fn = fn }) end,
        NewTicker = function(sec, fn) M.ticker = fn; return {} end,
    }
    M.runTimers = function()
        local ran = true
        while ran do
            ran = false
            for i = #M.timers, 1, -1 do
                local t = M.timers[i]
                if t.at <= now then
                    table.remove(M.timers, i)
                    t.fn()
                    ran = true
                end
            end
        end
    end

    GetServerTime = function() return now end
    GetTime = function() return clock end
    date = function(fmt, t) return "Sat 02:15 AM" end
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
    strlenutf8 = function(s) return #s end
    STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"

    M.combat = false
    M.inInstance = false
    M.inGroup = false
    InCombatLockdown = function() return M.combat end
    IsInInstance = function() return M.inInstance end
    IsInGroup = function() return M.inGroup end
    IsControlKeyDown = function() return M.ctrl or false end
    UnitName = function() return M.charName or "Ayla" end
    GetRealmName = function() return "Area 52" end
    UnitClass = function() return "Mage", "MAGE" end
    GetCursorPosition = function() return 600, 400 end

    M.printed = {}
    print = function(msg) table.insert(M.printed, msg) end
    M.lastPrinted = function() return M.printed[#M.printed] end

    UIParent = newobj("UIParent")
    Minimap = newobj("Minimap")
    GameTooltip = newobj("GameTooltip")
    M.tooltipLines = {}
    GameTooltip.AddLine = function(self, text) table.insert(M.tooltipLines, text) end
    ColorPickerFrame = newobj("ColorPickerFrame")
    ColorPickerFrame.SetupColorPickerAndShow = function(self, info) M.pickerInfo = info end

    M.frames = {}
    CreateFrame = function(kind, name, parent, template)
        local o = newobj(kind)
        o.__name = name
        o.__template = template
        table.insert(M.frames, o)
        if name then _G[name] = o end
        return o
    end

    SlashCmdList = {}
    M.settingsRegistered = false
    Settings = {
        RegisterCanvasLayoutCategory = function(panel, name)
            local cat = { GetID = function() return 7 end, panel = panel }
            M.category = cat
            return cat
        end,
        RegisterAddOnCategory = function(cat) M.settingsRegistered = true end,
        OpenToCategory = function(id) M.openedCategory = id end,
    }

    SOUNDKIT = { ALARM_CLOCK_WARNING_3 = 1, RAID_WARNING = 2, READY_CHECK = 3 }
    M.sounds = {}
    PlaySound = function(id, channel) table.insert(M.sounds, { id, channel }) end

    -- Spell and tradeskill data
    M.spells = { [111] = "Transmute: Arcanite", [222] = "Transmute: Iron to Gold", [333] = "Primal Mooncloth",
        [444] = "Hearthstone", [666] = "Refined Scale of Onyxia", [777] = "Transmute: Water to Air" }
    M.spellCooldowns = {}  -- spellID -> {start, duration} in GetTime() terms
    C_Spell = {
        GetSpellName = function(id) return M.spells[id] end,
        GetSpellTexture = function(id) return 100000 + id end,
        GetSpellCooldown = function(id)
            local c = M.spellCooldowns[id]
            if c then return { startTime = c[1], duration = c[2], isEnabled = true } end
            return { startTime = 0, duration = 0, isEnabled = true }
        end,
    }
    M.recipes = {
        { id = 111, name = "Transmute: Arcanite", icon = 135001 },
        { id = 222, name = "Transmute: Iron to Gold", icon = 135002 },
        { id = 333, name = "Primal Mooncloth", icon = 135003 },
        { id = 555, name = "Elixir of Giants", icon = 135005 },
        { id = 666, name = "Refined Scale of Onyxia", icon = 135006 },
        { id = 777, name = "Transmute: Water to Air", icon = 135007 },
        { id = 888, name = "Transmute: Not Learned", icon = 135008, learned = false },
    }
    M.linked = false
    M.recipeCooldowns = {}  -- recipeID -> seconds remaining
    M.opened = nil
    C_TradeSkillUI = {
        GetAllRecipeIDs = function()
            local ids = {}
            for _, r in ipairs(M.recipes) do ids[#ids + 1] = r.id end
            return ids
        end,
        GetRecipeInfo = function(id)
            for _, r in ipairs(M.recipes) do
                if r.id == id then return { name = r.name, icon = r.icon, learned = r.learned ~= false } end
            end
        end,
        GetRecipeCooldown = function(id) return M.recipeCooldowns[id] end,
        OpenRecipe = function(id) M.opened = id end,
        IsTradeSkillLinked = function() return M.linked end,
        IsTradeSkillGuild = function() return false end,
    }
end

function M.load(files)
    local ns = {}
    for _, path in ipairs(files) do
        local f = assert(io.open(path)):read("*a")
        local chunk, err = (loadstring or load)(f, "@" .. path)
        assert(chunk, err)
        chunk("TransmuteReminder", ns)
    end
    return ns
end

function M.fire(ns, event, ...)
    -- find the Core event frame: the first frame with OnEvent script
    for _, fr in ipairs(M.frames) do
        local h = fr.__scripts["OnEvent"]
        if h and fr.__events and fr.__events[event] then h(fr, event, ...) return end
    end
    error("no handler for " .. event)
end

return M
