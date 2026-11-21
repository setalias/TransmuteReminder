-- TransmuteReminder: core logic
-- Tracks profession cooldowns (transmutes first, other long cooldowns found by
-- scanning the profession window), stores them account-wide so alts can be
-- reported, and decides when the reminder shows. The window itself is in Popup.lua.
--
-- Combat comes first: nothing here reads cooldowns, scans, or does work beyond a
-- cheap visibility check while you are in combat.

local ADDON_NAME, ns = ...

ns.DEFAULT_MESSAGE = "Check transmutes"
ns.MAX_MESSAGE_LENGTH = 40
ns.MIN_SCALE = 0.5
ns.MAX_SCALE = 3
ns.TRANSMUTE_KEY = "transmute"

local TRANSMUTE_KEY = ns.TRANSMUTE_KEY
local MIN_REAL_COOLDOWN = 120  -- seconds; shorter spell cooldowns are treated as global cooldowns
local CHECK_INTERVAL = 30      -- seconds between safety checks
local AUTO_SCAN_THROTTLE = 10  -- seconds between automatic profession scans
local TOLERANCE = 90           -- seconds; smaller differences are not announced again
local PREVIEW_SECONDS = 10

ns.DEFAULTS = {
    scale = 1,
    locked = false,
    display = "both",          -- both | text | icon
    icon = "recipe",
    textColor = { 1, 0.82, 0 },
    font = "default",
    bgAlpha = 0.85,
    border = true,
    animation = "pulse",       -- pulse | glow | none
    sound = "none",
    repeatMinutes = 0,         -- 0 = do not repeat
    snoozeMinutes = 10,        -- 0 = right-click dismisses
    chat = false,
    hideCombat = true,
    hideInstance = false,
    hideGroup = false,
    minimapHide = false,
    minimapAngle = 215,
    remindAlts = true,
    clickOpens = true,
    hours = 20,                -- fallback transmute cooldown if the game gives none
    debug = false,
}

local s, me, mykey -- settings, this character's record, its key

-- Runtime state (not saved)
ns.alerted = {}
ns.altsAlerted = false
ns.altsDismissed = false
ns.snoozeUntil = nil
ns.lastAlert = nil
ns.previewUntil = nil

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------

function ns.print(msg)
    print("|cff33ff99TransmuteReminder:|r " .. msg)
end
local print_msg = ns.print

local function is_secret(value)
    return issecretvalue ~= nil and issecretvalue(value)
end
ns.is_secret = is_secret

function ns.format_duration(seconds)
    seconds = math.max(0, math.floor(seconds))
    local d = math.floor(seconds / 86400)
    local h = math.floor((seconds % 86400) / 3600)
    local m = math.floor((seconds % 3600) / 60)
    if d > 0 then
        return string.format("%dd %dh", d, h)
    elseif h > 0 then
        return string.format("%dh %dm", h, m)
    end
    return string.format("%dm", m)
end

function ns.text_length(str)
    return (strlenutf8 and strlenutf8(str)) or #str
end

-- Pipes start escape codes in WoW text, so show them literally.
function ns.escape_pipes(str)
    return (str:gsub("|", "||"))
end

local function get_spell_name(spellID)
    if C_Spell and C_Spell.GetSpellName then
        return C_Spell.GetSpellName(spellID)
    end
    return (GetSpellInfo(spellID))
end

local function get_spell_texture(spellID)
    if C_Spell and C_Spell.GetSpellTexture then
        return C_Spell.GetSpellTexture(spellID)
    end
    if GetSpellTexture then return GetSpellTexture(spellID) end
    return nil
end

local function get_spell_cooldown(spellID)
    if C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(spellID)
        if info then return info.startTime, info.duration end
        return nil
    end
    if GetSpellCooldown then
        local start, duration = GetSpellCooldown(spellID)
        return start, duration
    end
    return nil
end

local function is_transmute_name(name)
    return type(name) == "string" and not is_secret(name) and name:find("^Transmut") ~= nil
end

local function short_name(ckey)
    local name, realm = ckey:match("^(.-)%-(.*)$")
    if name and realm == GetRealmName() then return name end
    return ckey
end

---------------------------------------------------------------------------
-- Saved data
--   TransmuteReminderAccountDB.settings  look and behavior, shared by all characters
--   TransmuteReminderAccountDB.chars     one record per character with its cooldowns
---------------------------------------------------------------------------

local function init_db()
    TransmuteReminderAccountDB = TransmuteReminderAccountDB or {}
    local acct = TransmuteReminderAccountDB
    acct.settings = acct.settings or {}
    acct.chars = acct.chars or {}

    s = setmetatable(acct.settings, { __index = ns.DEFAULTS })
    if type(rawget(s, "disabled")) ~= "table" then s.disabled = {} end

    mykey = (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
    me = acct.chars[mykey] or {}
    acct.chars[mykey] = me
    me.cooldowns = me.cooldowns or {}
    me.dismissed = me.dismissed or {}
    me.class = select(2, UnitClass("player"))

    -- Carry over data from the first version, which saved per character.
    local old = TransmuteReminderDB
    if type(old) == "table" and not old.migrated then
        if not acct.settingsMigrated then
            for _, k in ipairs({ "message", "scale", "point", "hours" }) do
                if old[k] ~= nil then s[k] = old[k] end
            end
            acct.settingsMigrated = true
        end
        if old.expiry and not me.cooldowns[TRANSMUTE_KEY] then
            me.cooldowns[TRANSMUTE_KEY] = {
                name = "Transmutes",
                expiry = old.expiry,
                spellID = old.spellID,
                recipeID = old.spellID,
            }
        end
        old.migrated = true
    end

    ns.acct, ns.s, ns.me, ns.mykey = acct, s, me, mykey
end

---------------------------------------------------------------------------
-- Settings that need validation
---------------------------------------------------------------------------

function ns.get_message()
    local m = s and s.message
    if type(m) == "string" and m ~= "" then return m end
    return ns.DEFAULT_MESSAGE
end

function ns.set_message(text)
    text = (text or ""):match("^%s*(.-)%s*$")
    if text == "" or text:lower() == "default" then
        s.message = nil
        print_msg(string.format("reminder text reset to \"%s\".", ns.DEFAULT_MESSAGE))
        ns.Preview()
        return true
    end
    local len = ns.text_length(text)
    if len > ns.MAX_MESSAGE_LENGTH then
        print_msg(string.format("that is %d characters. The limit is %d.", len, ns.MAX_MESSAGE_LENGTH))
        return false
    end
    s.message = text
    print_msg(string.format("reminder text set to \"%s\".", ns.escape_pipes(text)))
    ns.Preview()
    return true
end

function ns.get_scale()
    local n = s and tonumber(s.scale) or 1
    return math.min(ns.MAX_SCALE, math.max(ns.MIN_SCALE, n))
end

---------------------------------------------------------------------------
-- Cooldown records
---------------------------------------------------------------------------

local function sort_items(list)
    table.sort(list, function(a, b)
        if (a.char or "") ~= (b.char or "") then return (a.char or "") < (b.char or "") end
        local at, bt = a.key == TRANSMUTE_KEY, b.key == TRANSMUTE_KEY
        if at ~= bt then return at end
        return (a.name or "") < (b.name or "")
    end)
    return list
end

-- Every enabled cooldown for this character, ready or not.
function ns.own_items()
    local now = GetServerTime()
    local list = {}
    for key, e in pairs(me.cooldowns) do
        if not s.disabled[key] and type(e.expiry) == "number" then
            list[#list + 1] = {
                key = key,
                name = e.name or key,
                expiry = e.expiry,
                ready = e.expiry <= now,
                dismissed = me.dismissed[key] == e.expiry,
                icon = e.icon,
                recipeID = e.recipeID,
            }
        end
    end
    return sort_items(list)
end

function ns.ready_own()
    local list = {}
    for _, it in ipairs(ns.own_items()) do
        if it.ready and not it.dismissed then list[#list + 1] = it end
    end
    return list
end

-- Enabled cooldowns on the other characters.
function ns.alt_items()
    local now = GetServerTime()
    local list = {}
    for ckey, c in pairs(ns.acct.chars) do
        if ckey ~= mykey and type(c.cooldowns) == "table" then
            for key, e in pairs(c.cooldowns) do
                if not s.disabled[key] and type(e.expiry) == "number" then
                    list[#list + 1] = {
                        char = short_name(ckey),
                        charKey = ckey,
                        key = key,
                        name = e.name or key,
                        expiry = e.expiry,
                        ready = e.expiry <= now,
                    }
                end
            end
        end
    end
    return sort_items(list)
end

function ns.ready_alts()
    local list = {}
    for _, it in ipairs(ns.alt_items()) do
        if it.ready then list[#list + 1] = it end
    end
    return list
end

-- Every cooldown name known on any character, for the checklist in the options.
function ns.all_keys()
    local names = {}
    for _, c in pairs(ns.acct.chars) do
        if type(c.cooldowns) == "table" then
            for key, e in pairs(c.cooldowns) do
                names[key] = e.name or key
            end
        end
    end
    local list = {}
    for key, name in pairs(names) do list[#list + 1] = { key = key, name = name } end
    sort_items(list)
    return list
end

local function time_label(expiry)
    return date("%a %I:%M %p", expiry)
end

function ns.StatusLines()
    local lines = {}
    local now = GetServerTime()
    local own = ns.own_items()
    if #own == 0 then
        lines[1] = "No cooldown recorded yet. One is recorded when you cast a transmute or open your Alchemy window."
    else
        for _, it in ipairs(own) do
            if it.ready then
                lines[#lines + 1] = it.name .. ": ready"
            else
                lines[#lines + 1] = string.format("%s: ready in %s (%s)",
                    it.name, ns.format_duration(it.expiry - now), time_label(it.expiry))
            end
        end
    end
    local alts = ns.alt_items()
    for i, it in ipairs(alts) do
        if i > 8 then
            lines[#lines + 1] = string.format("...and %d more on other characters.", #alts - 8)
            break
        end
        if it.ready then
            lines[#lines + 1] = string.format("%s, %s: ready", it.char, it.name)
        else
            lines[#lines + 1] = string.format("%s, %s: ready in %s",
                it.char, it.name, ns.format_duration(it.expiry - now))
        end
    end
    return lines
end

function ns.KnownTransmutes()
    return me.transmutes or {}
end

function ns.set_cooldown(key, name, expiry, source, extra)
    local e = me.cooldowns[key] or {}
    e.name = name
    e.expiry = expiry
    if extra then
        for k, v in pairs(extra) do
            if v ~= nil then e[k] = v end
        end
    end
    me.cooldowns[key] = e
    me.dismissed[key] = nil
    ns.alerted[key] = nil
    ns.schedule(expiry)
    ns.Update()
    local label = (key == TRANSMUTE_KEY) and "transmute" or name
    print_msg(string.format("next %s ready in %s (%s).",
        label, ns.format_duration(expiry - GetServerTime()), source))
end

function ns.schedule(expiry)
    local remaining = expiry - GetServerTime()
    if remaining > 0 and remaining < 86400 * 30 then
        C_Timer.After(remaining + 1, ns.Update)
    end
end

function ns.ClearOwn()
    wipe(me.cooldowns)
    wipe(me.dismissed)
    wipe(ns.alerted)
    ns.Update()
end

---------------------------------------------------------------------------
-- Reading cooldowns from the game (never in combat)
---------------------------------------------------------------------------

-- Returns an expiry timestamp (server time) from a spell's cooldown, or nil.
local function read_expiry(spellID)
    if InCombatLockdown() then return nil end
    local start, duration = get_spell_cooldown(spellID)
    if not start or not duration then return nil end
    if is_secret(start) or is_secret(duration) then return nil end
    if duration < MIN_REAL_COOLDOWN or start <= 0 then return nil end
    local remaining = (start + duration) - GetTime()
    if remaining <= 0 then return nil end
    return GetServerTime() + remaining
end
ns.read_expiry = read_expiry

local function recipe_cooldown_seconds(recipeID)
    if not (C_TradeSkillUI and C_TradeSkillUI.GetRecipeCooldown) then return nil end
    local ok, cd = pcall(C_TradeSkillUI.GetRecipeCooldown, recipeID)
    if not ok or type(cd) ~= "number" or is_secret(cd) then return nil end
    return cd
end

local function after_transmute_cast(spellID, name)
    local expiry = read_expiry(spellID)
    local extra = { spellID = spellID, recipeID = spellID, icon = get_spell_texture(spellID) }
    if expiry then
        ns.set_cooldown(TRANSMUTE_KEY, "Transmutes", expiry, "read from game", extra)
        return
    end
    local hours = s.hours or 20
    ns.set_cooldown(TRANSMUTE_KEY, "Transmutes", GetServerTime() + hours * 3600,
        string.format("fallback of %s hours, game gave no cooldown", hours), extra)
end

local function on_cast(spellID)
    local name = get_spell_name(spellID)
    if s.debug then
        print_msg(string.format("cast: %s (%s)", tostring(name), tostring(spellID)))
    end
    if is_transmute_name(name) then
        -- Give the game a moment to apply the cooldown before reading it.
        C_Timer.After(1.5, function() after_transmute_cast(spellID, name) end)
    elseif type(name) == "string" and not is_secret(name) and me.cooldowns["r:" .. name] then
        C_Timer.After(1.5, function()
            local expiry = read_expiry(spellID)
            if expiry then
                ns.set_cooldown("r:" .. name, name, expiry, "read from game", { spellID = spellID })
            end
        end)
    end
end

---------------------------------------------------------------------------
-- Profession window scan
-- Picks up cooldowns that started before install, and any other recipe that
-- has a cooldown. Needs the profession window open.
---------------------------------------------------------------------------

local last_scan = 0
local scan_queued = false

-- Returns { name, id, icon, viaRecipe, viaSpell, remaining } for each transmute
-- recipe and each recipe currently on cooldown in the open profession.
local function collect()
    local results = {}

    if C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs and C_TradeSkillUI.GetRecipeInfo then
        local ok, ids = pcall(C_TradeSkillUI.GetAllRecipeIDs)
        if ok and type(ids) == "table" then
            for _, id in ipairs(ids) do
                local okInfo, info = pcall(C_TradeSkillUI.GetRecipeInfo, id)
                if okInfo and type(info) == "table" and type(info.name) == "string" and not is_secret(info.name)
                    and info.learned ~= false then
                    local viaRecipe = recipe_cooldown_seconds(id)
                    local viaSpell
                    local expiry = read_expiry(id)
                    if expiry then viaSpell = expiry - GetServerTime() end
                    local remaining = viaRecipe
                    if not remaining or remaining <= 0 then remaining = viaSpell end
                    if not remaining or remaining <= 0 then remaining = nil end
                    if is_transmute_name(info.name) or remaining then
                        results[#results + 1] = {
                            name = info.name, id = id, icon = info.icon,
                            viaRecipe = viaRecipe, viaSpell = viaSpell, remaining = remaining,
                        }
                    end
                end
            end
        end
    elseif GetNumTradeSkills and GetTradeSkillInfo then
        -- Classic-style API
        for i = 1, GetNumTradeSkills() do
            local name, kind = GetTradeSkillInfo(i)
            if kind ~= "header" and type(name) == "string" then
                local cd = GetTradeSkillCooldown and GetTradeSkillCooldown(i) or nil
                if cd and cd <= 0 then cd = nil end
                if is_transmute_name(name) or cd then
                    results[#results + 1] = { name = name, id = i, viaRecipe = cd, remaining = cd }
                end
            end
        end
    end

    return results
end

function ns.scan(manual)
    if not s then return end
    if InCombatLockdown() then
        if manual then print_msg("can't scan in combat.") end
        return
    end
    if not manual and (GetTime() - last_scan) < AUTO_SCAN_THROTTLE then return end
    last_scan = GetTime()

    local results = collect()
    local transmuteNames, firstTransmuteID = {}, nil
    local bestRem, bestRec
    local others = {}

    for _, r in ipairs(results) do
        if is_transmute_name(r.name) then
            transmuteNames[#transmuteNames + 1] = r.name
            firstTransmuteID = firstTransmuteID or r.id
            if r.remaining and (not bestRem or r.remaining < bestRem) then
                bestRem, bestRec = r.remaining, r
            end
        elseif r.remaining then
            others[#others + 1] = r
        end
    end

    -- A recipe that reports the same cooldown as the transmutes is sharing it
    -- (or is not really yours), so it is not tracked separately.
    if bestRem then
        local kept = {}
        for _, r in ipairs(others) do
            if math.abs(r.remaining - bestRem) <= TOLERANCE then
                me.cooldowns["r:" .. r.name] = nil
            else
                kept[#kept + 1] = r
            end
        end
        others = kept
    end

    if manual then
        if #results == 0 then
            print_msg("no transmute recipes or cooldowns found. Open your Alchemy window first.")
            return
        end
        print_msg(string.format("scan found %d recipes:", #results))
        for _, r in ipairs(results) do
            print_msg(string.format("  %s (%s): recipe cooldown=%s, spell cooldown=%s",
                r.name, tostring(r.id), tostring(r.viaRecipe), tostring(r.viaSpell)))
        end
    end

    if #transmuteNames > 0 then
        table.sort(transmuteNames)
        me.transmutes = transmuteNames
        me.recipeID = firstTransmuteID
    end

    local function apply(key, name, remaining, r)
        local expiry = GetServerTime() + remaining
        local e = me.cooldowns[key]
        local extra = { recipeID = r.id, icon = r.icon }
        -- Skip tiny differences so reopening the window does not repeat the message.
        if manual or not e or math.abs(e.expiry - expiry) > TOLERANCE then
            ns.set_cooldown(key, name, expiry, "scanned from profession window", extra)
        else
            e.recipeID = e.recipeID or r.id
            e.icon = e.icon or r.icon
        end
    end

    if bestRem then
        apply(TRANSMUTE_KEY, "Transmutes", bestRem, bestRec)
    end
    for _, r in ipairs(others) do
        apply("r:" .. r.name, r.name, r.remaining, r)
    end

    if manual and not bestRem and #others == 0 then
        print_msg("nothing is on cooldown, or the game gave no readable cooldown.")
    end
end

local function queue_scan()
    if scan_queued then return end
    scan_queued = true
    C_Timer.After(1, function()
        scan_queued = false
        ns.scan(false)
    end)
end

---------------------------------------------------------------------------
-- Alerts, snooze, dismiss
---------------------------------------------------------------------------

local SOUND_CHOICES = {
    { key = "none", name = "None" },
    { key = "alarm", name = "Alarm bell", kit = "ALARM_CLOCK_WARNING_3" },
    { key = "alarm2", name = "Alarm clock", kit = "ALARM_CLOCK_WARNING_2" },
    { key = "raid", name = "Raid warning", kit = "RAID_WARNING" },
    { key = "ready", name = "Ready check", kit = "READY_CHECK" },
    { key = "quest", name = "Quest complete", kit = "IG_QUEST_LIST_COMPLETE" },
    { key = "toast", name = "Toast", kit = "UI_BNET_TOAST" },
    { key = "ping", name = "Map ping", kit = "MAP_PING" },
    { key = "whisper", name = "Whisper", kit = "TELL_MESSAGE" },
}

-- Only sounds this client actually has.
function ns.available_sounds()
    local list = {}
    for _, c in ipairs(SOUND_CHOICES) do
        if not c.kit or (SOUNDKIT and SOUNDKIT[c.kit]) then
            list[#list + 1] = c
        end
    end
    return list
end

function ns.play_sound(key)
    for _, c in ipairs(SOUND_CHOICES) do
        if c.key == key and c.kit and SOUNDKIT and SOUNDKIT[c.kit] then
            PlaySound(SOUNDKIT[c.kit], "Master")
            return
        end
    end
end

local function alert(own, alts)
    ns.lastAlert = GetServerTime()
    if s.sound ~= "none" then ns.play_sound(s.sound) end
    if s.chat then
        local names = {}
        for _, it in ipairs(own) do names[#names + 1] = it.name end
        for _, it in ipairs(alts) do names[#names + 1] = it.char .. " (" .. it.name .. ")" end
        print_msg("ready: " .. table.concat(names, ", "))
    end
end

function ns.Dismiss()
    for _, it in ipairs(ns.ready_own()) do
        me.dismissed[it.key] = it.expiry
    end
    ns.altsDismissed = true
    ns.snoozeUntil = nil
    ns.previewUntil = nil
    ns.Update()
end

function ns.Snooze()
    local minutes = s.snoozeMinutes
    if not minutes or minutes <= 0 then
        ns.Dismiss()
        return
    end
    ns.snoozeUntil = GetServerTime() + minutes * 60
    ns.previewUntil = nil
    wipe(ns.alerted)
    ns.altsAlerted = false
    ns.lastAlert = nil
    ns.Update()
    C_Timer.After(minutes * 60 + 1, ns.Update)
    print_msg(string.format("snoozed for %d minutes.", minutes))
end

function ns.OpenProfession()
    if InCombatLockdown() then return false end
    local own = ns.ready_own()
    local id = (own[1] and own[1].recipeID) or me.recipeID
    if not id then return false end
    if C_TradeSkillUI and C_TradeSkillUI.OpenRecipe then
        return (pcall(C_TradeSkillUI.OpenRecipe, id))
    end
    return false
end

---------------------------------------------------------------------------
-- Deciding what to show
---------------------------------------------------------------------------

local function allowed_now()
    if s.hideCombat and InCombatLockdown() then return false end
    if s.hideInstance and IsInInstance() then return false end
    if s.hideGroup and IsInGroup() then return false end
    return true
end

local function set_popup(state)
    ns.lastState = state
    if ns.Popup_Set then ns.Popup_Set(state) end
end

function ns.Preview()
    if not s then return end
    ns.previewUntil = GetTime() + PREVIEW_SECONDS
    C_Timer.After(PREVIEW_SECONDS + 0.5, ns.Update)
    ns.Update()
end

function ns.Update()
    if not s then return end
    if ns.previewUntil and GetTime() >= ns.previewUntil then ns.previewUntil = nil end

    -- In combat with hiding on, do the minimum and stop.
    if s.hideCombat and InCombatLockdown() then
        set_popup(nil)
        return
    end

    if ns.previewUntil then
        local own = ns.ready_own()
        if #own == 0 then
            own = { { key = TRANSMUTE_KEY, name = "Transmutes" } }
        end
        set_popup({ own = own, alts = {}, preview = true })
        return
    end

    local now = GetServerTime()
    local own = ns.ready_own()
    local alts = (s.remindAlts and not ns.altsDismissed) and ns.ready_alts() or {}
    local snoozed = ns.snoozeUntil and now < ns.snoozeUntil
    if ns.snoozeUntil and not snoozed then ns.snoozeUntil = nil end

    local show = (#own > 0 or #alts > 0) and allowed_now() and not snoozed
    if not show then
        set_popup(nil)
        return
    end

    local need = false
    for _, it in ipairs(own) do
        if ns.alerted[it.key] ~= it.expiry then
            ns.alerted[it.key] = it.expiry
            need = true
        end
    end
    if #alts > 0 and not ns.altsAlerted then
        ns.altsAlerted = true
        need = true
    end
    if s.repeatMinutes > 0 and ns.lastAlert and (now - ns.lastAlert) >= s.repeatMinutes * 60 then
        need = true
    end
    if need then alert(own, alts) end

    set_popup({ own = own, alts = alts })
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")

events:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        init_db()
        ns.Popup_Create()

        local ok, err = pcall(ns.Options_Create)
        if not ok then print_msg("options panel failed to load: " .. tostring(err)) end
        ok, err = pcall(ns.Minimap_Create)
        if not ok then print_msg("minimap button failed to load: " .. tostring(err)) end

        self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        self:RegisterEvent("PLAYER_REGEN_DISABLED")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        self:RegisterEvent("GROUP_ROSTER_UPDATE")
        self:RegisterEvent("TRADE_SKILL_SHOW")
        self:RegisterEvent("TRADE_SKILL_LIST_UPDATE")

        for _, e in pairs(me.cooldowns) do
            if type(e.expiry) == "number" then ns.schedule(e.expiry) end
        end
        C_Timer.NewTicker(CHECK_INTERVAL, ns.Update)
        ns.Update()

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if InCombatLockdown() then return end
        local _, _, spellID = ...
        if spellID == nil or is_secret(spellID) then return end
        on_cast(spellID)

    elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_LIST_UPDATE" then
        queue_scan()

    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Out of combat again: refresh the transmute time from the game if we can.
        local e = me.cooldowns[TRANSMUTE_KEY]
        if e and e.spellID and e.expiry > GetServerTime() then
            local expiry = read_expiry(e.spellID)
            if expiry then e.expiry = expiry end
        end
        ns.Update()

    else
        -- PLAYER_REGEN_DISABLED, PLAYER_ENTERING_WORLD, ZONE_CHANGED_NEW_AREA, GROUP_ROSTER_UPDATE
        ns.Update()
    end
end)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

local function find_char(query)
    query = query:lower()
    for ckey in pairs(ns.acct.chars) do
        if ckey:lower() == query or short_name(ckey):lower() == query then return ckey end
    end
    return nil
end

SLASH_TRANSMUTEREMINDER1 = "/tmr"
SlashCmdList["TRANSMUTEREMINDER"] = function(input)
    if not s then return end
    local cmd, arg = (input or ""):match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()
    arg = arg:match("^%s*(.-)%s*$")

    if cmd == "test" then
        ns.Preview()
    elseif cmd == "options" or cmd == "config" then
        if ns.OpenOptions then ns.OpenOptions() end
    elseif cmd == "scan" then
        ns.scan(true)
    elseif cmd == "reset" then
        s.point = nil
        ns.Popup_ResetPosition()
        print_msg("position reset.")
    elseif cmd == "clear" then
        ns.ClearOwn()
        print_msg("stored cooldowns cleared for this character.")
    elseif cmd == "lock" or cmd == "unlock" then
        s.locked = (cmd == "lock")
        print_msg(s.locked and "position locked." or "position unlocked. Drag the reminder to move it.")
    elseif cmd == "minimap" then
        s.minimapHide = not s.minimapHide
        if ns.Minimap_Update then ns.Minimap_Update() end
        print_msg(s.minimapHide and "minimap button hidden." or "minimap button shown.")
    elseif cmd == "message" then
        if arg == "" then
            print_msg(string.format("reminder text is \"%s\". Use /tmr message <text> to change it, or /tmr message default to reset.",
                ns.escape_pipes(ns.get_message())))
        else
            ns.set_message(arg)
        end
    elseif cmd == "scale" then
        if arg == "" then
            print_msg(string.format("reminder size is %.1f. Use /tmr scale <%s to %s> to change it, or /tmr scale default to reset.",
                ns.get_scale(), ns.MIN_SCALE, ns.MAX_SCALE))
        elseif arg:lower() == "default" then
            s.scale = nil
            ns.Popup_ApplyScale()
            ns.Preview()
            print_msg("reminder size reset to 1.0.")
        else
            local n = tonumber(arg)
            if n and n >= ns.MIN_SCALE and n <= ns.MAX_SCALE then
                s.scale = n
                ns.Popup_ApplyScale()
                ns.Preview()
                print_msg(string.format("reminder size set to %.1f.", n))
            else
                print_msg(string.format("usage: /tmr scale <number from %s to %s>", ns.MIN_SCALE, ns.MAX_SCALE))
            end
        end
    elseif cmd == "hours" then
        local hours = tonumber(arg)
        if hours and hours > 0 then
            s.hours = hours
            print_msg(string.format("fallback cooldown set to %s hours.", hours))
        else
            print_msg("usage: /tmr hours <number>")
        end
    elseif cmd == "alts" then
        local alts = ns.alt_items()
        if #alts == 0 then
            print_msg("no cooldowns recorded on other characters yet.")
        else
            local now = GetServerTime()
            for _, it in ipairs(alts) do
                print_msg(string.format("  %s, %s: %s", it.char, it.name,
                    it.ready and "ready" or ("ready in " .. ns.format_duration(it.expiry - now))))
            end
        end
    elseif cmd == "forget" then
        local ckey = find_char(arg)
        if arg == "" then
            print_msg("usage: /tmr forget <character name>")
        elseif not ckey then
            print_msg("no saved character matches that name. Use /tmr alts to see who is saved.")
        elseif ckey == mykey then
            print_msg("that is this character. Use /tmr clear instead.")
        else
            ns.acct.chars[ckey] = nil
            ns.Update()
            print_msg(short_name(ckey) .. " forgotten.")
        end
    elseif cmd == "debug" then
        if arg == "on" then
            s.debug = true
            print_msg("debug on: every cast you make is printed with its spell ID.")
        elseif arg == "off" then
            s.debug = false
            print_msg("debug off.")
        else
            print_msg("debug state:")
            for key, e in pairs(me.cooldowns) do
                print_msg(string.format("  %s: expiry=%s spellID=%s recipeID=%s",
                    key, tostring(e.expiry), tostring(e.spellID), tostring(e.recipeID)))
            end
            print_msg("  C_TradeSkillUI present: " .. tostring(C_TradeSkillUI ~= nil))
            print_msg("  issecretvalue present: " .. tostring(issecretvalue ~= nil))
            local e = me.cooldowns[TRANSMUTE_KEY]
            if e and e.spellID then
                local start, duration = get_spell_cooldown(e.spellID)
                print_msg(string.format("  game cooldown: start=%s duration=%s secret=%s",
                    tostring(start), tostring(duration),
                    tostring(is_secret(start) or is_secret(duration))))
            end
            print_msg("  tip: open your Alchemy window and run /tmr scan to see what the game reports.")
        end
    else
        for _, line in ipairs(ns.StatusLines()) do print_msg(line) end
        print_msg("commands: /tmr options, test, scan, reset, clear, lock, unlock, minimap, message <text>, scale <n>, hours <n>, alts, forget <name>, debug [on|off]")
    end
end
