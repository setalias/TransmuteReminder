-- TransmuteReminder
-- Shows a small "Check transmutes" frame when the alchemy transmute cooldown is ready.
-- Built for WoW: Forever. Only reads cooldowns outside combat, because Forever
-- applies Midnight-style addon restrictions (secret values) in combat.

local ADDON_NAME = ...

local FALLBACK_HOURS = 20      -- used only if the game gives no readable cooldown
local MIN_REAL_COOLDOWN = 120  -- seconds; anything shorter is treated as a global cooldown
local CHECK_INTERVAL = 30      -- seconds between ready checks
local DEFAULT_MESSAGE = "Check transmutes"
local MAX_MESSAGE_LENGTH = 40  -- characters; the reminder is a single line
local MIN_SCALE = 0.5
local MAX_SCALE = 3

local db
local frame

local function print_msg(msg)
    print("|cff33ff99TransmuteReminder:|r " .. msg)
end

local function is_secret(value)
    return issecretvalue ~= nil and issecretvalue(value)
end

local function format_duration(seconds)
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

local function get_spell_name(spellID)
    if C_Spell and C_Spell.GetSpellName then
        return C_Spell.GetSpellName(spellID)
    end
    return (GetSpellInfo(spellID))
end

local function get_spell_cooldown(spellID)
    if C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(spellID)
        if info then
            return info.startTime, info.duration
        end
        return nil
    end
    if GetSpellCooldown then
        local start, duration = GetSpellCooldown(spellID)
        return start, duration
    end
    return nil
end

local function is_transmute_name(name)
    return type(name) == "string" and name:find("^Transmut") ~= nil
end

---------------------------------------------------------------------------
-- Reminder frame
---------------------------------------------------------------------------

local function save_position()
    local point, _, relPoint, x, y = frame:GetPoint()
    db.point = { point, relPoint, x, y }
end

local function text_length(s)
    return (strlenutf8 and strlenutf8(s)) or #s
end

-- Pipes start escape codes in WoW text, so show them literally.
local function escape_pipes(s)
    return (s:gsub("|", "||"))
end

local function get_message()
    if db and type(db.message) == "string" and db.message ~= "" then
        return db.message
    end
    return DEFAULT_MESSAGE
end

local function apply_message()
    if not frame then return end
    frame.text:SetText(escape_pipes(get_message()))
    frame:SetWidth(math.max(120, frame.text:GetStringWidth() + 32))
end

local function get_scale()
    local s = db and tonumber(db.scale) or 1
    return math.min(MAX_SCALE, math.max(MIN_SCALE, s))
end

-- Changes the size of the reminder while keeping it centered where it was.
local function apply_scale()
    if not frame then return end
    local scale = get_scale()
    local cx, cy = frame:GetCenter()
    local old = frame:GetEffectiveScale()
    frame:SetScale(scale)
    if cx and cy then
        local new = frame:GetEffectiveScale()
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx * old / new, cy * old / new)
        save_position()
    end
end

local function create_frame()
    frame = CreateFrame("Button", "TransmuteReminderFrame", UIParent, "BackdropTemplate")
    frame:SetSize(190, 40)
    frame:SetFrameStrata("HIGH")
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.85)

    frame:SetScale(get_scale())

    local p = db.point
    frame:ClearAllPoints()
    if p then
        frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
    end

    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("CENTER")
    frame.text = text
    apply_message()

    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        save_position()
    end)
    frame:SetScript("OnClick", function(self)
        db.dismissed = true
        self:Hide()
    end)

    local pulse = frame:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local alpha = pulse:CreateAnimation("Alpha")
    alpha:SetFromAlpha(1)
    alpha:SetToAlpha(0.45)
    alpha:SetDuration(0.9)
    frame.pulse = pulse

    frame:SetScript("OnShow", function(self) self.pulse:Play() end)
    frame:SetScript("OnHide", function(self) self.pulse:Stop() end)

    frame:Hide()
end

local function check_ready()
    if not db or not frame then return end
    if not db.expiry then
        frame:Hide()
        return
    end
    if GetServerTime() >= db.expiry then
        if not db.dismissed then
            frame:Show()
        end
    else
        frame:Hide()
    end
end

---------------------------------------------------------------------------
-- Cooldown tracking
---------------------------------------------------------------------------

local function set_expiry(expiry, source)
    db.expiry = expiry
    db.dismissed = false
    check_ready()
    local remaining = expiry - GetServerTime()
    print_msg(string.format("next transmute ready in %s (%s).", format_duration(remaining), source))
end

-- Reads the remaining cooldown for a spell from the game. Returns an expiry
-- timestamp (server time) or nil if the game gave nothing usable.
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

local function on_transmute_cast(spellID)
    db.spellID = spellID
    db.spellName = get_spell_name(spellID)
    local expiry = read_expiry(spellID)
    if expiry then
        set_expiry(expiry, "read from game")
        return
    end
    local hours = db.hours or FALLBACK_HOURS
    set_expiry(GetServerTime() + hours * 3600, string.format("fallback of %d hours, game gave no cooldown", hours))
end

---------------------------------------------------------------------------
-- Profession window scan
-- Picks up cooldowns that started before the addon was installed. Needs the
-- profession window open, because the recipe list is only loaded then.
---------------------------------------------------------------------------

local AUTO_SCAN_THROTTLE = 10 -- seconds between automatic scans
local last_scan = 0
local scan_queued = false

local function recipe_cooldown_seconds(recipeID)
    if not (C_TradeSkillUI and C_TradeSkillUI.GetRecipeCooldown) then return nil end
    local ok, cd = pcall(C_TradeSkillUI.GetRecipeCooldown, recipeID)
    if not ok or type(cd) ~= "number" or is_secret(cd) then return nil end
    return cd
end

-- Returns a list of { name, id, viaRecipe, viaSpell } for every transmute recipe
-- in the open profession. Values are remaining seconds, or nil if unreadable.
local function collect_transmutes()
    local results = {}

    if C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs and C_TradeSkillUI.GetRecipeInfo then
        local ok, ids = pcall(C_TradeSkillUI.GetAllRecipeIDs)
        if ok and type(ids) == "table" then
            for _, id in ipairs(ids) do
                local okInfo, info = pcall(C_TradeSkillUI.GetRecipeInfo, id)
                if okInfo and type(info) == "table" and not is_secret(info.name) and is_transmute_name(info.name) then
                    local viaSpell
                    local expiry = read_expiry(id)
                    if expiry then viaSpell = expiry - GetServerTime() end
                    results[#results + 1] = {
                        name = info.name,
                        id = id,
                        viaRecipe = recipe_cooldown_seconds(id),
                        viaSpell = viaSpell,
                    }
                end
            end
        end
    elseif GetNumTradeSkills and GetTradeSkillInfo then
        -- Classic-style API
        for i = 1, GetNumTradeSkills() do
            local name, kind = GetTradeSkillInfo(i)
            if kind ~= "header" and is_transmute_name(name) then
                local cd = GetTradeSkillCooldown and GetTradeSkillCooldown(i) or nil
                results[#results + 1] = { name = name, id = i, viaRecipe = cd }
            end
        end
    end

    return results
end

local function scan_recipes(manual)
    if not db then return end
    if InCombatLockdown() then
        if manual then print_msg("can't scan in combat.") end
        return
    end
    if not manual and (GetTime() - last_scan) < AUTO_SCAN_THROTTLE then return end
    last_scan = GetTime()

    local results = collect_transmutes()

    if manual then
        if #results == 0 then
            print_msg("no transmute recipes found. Open your Alchemy window first.")
            return
        end
        print_msg(string.format("scan found %d transmute recipes:", #results))
        for _, r in ipairs(results) do
            print_msg(string.format("  %s (%s): recipe cooldown=%s, spell cooldown=%s",
                r.name, tostring(r.id), tostring(r.viaRecipe), tostring(r.viaSpell)))
        end
    end

    -- Shortest remaining cooldown among transmutes that are on cooldown.
    local best
    for _, r in ipairs(results) do
        local remaining = r.viaRecipe
        if not remaining or remaining <= 0 then remaining = r.viaSpell end
        if remaining and remaining > 0 and (not best or remaining < best) then
            best = remaining
        end
    end

    if best then
        local expiry = GetServerTime() + best
        -- Skip tiny differences so reopening the window doesn't repeat the message.
        if manual or not db.expiry or math.abs(db.expiry - expiry) > 90 then
            set_expiry(expiry, "scanned from profession window")
        end
    elseif manual then
        print_msg("no transmute is on cooldown, or the game gave no readable cooldown.")
    end
end

local function queue_scan()
    if scan_queued then return end
    scan_queued = true
    C_Timer.After(1, function()
        scan_queued = false
        scan_recipes(false)
    end)
end

---------------------------------------------------------------------------
-- Options panel (Options > AddOns > TransmuteReminder)
---------------------------------------------------------------------------

local settings_category

local function status_line()
    if not db or not db.expiry then
        return "No transmute cooldown recorded yet. It is recorded when you cast a transmute or open your Alchemy window."
    end
    local remaining = db.expiry - GetServerTime()
    if remaining > 0 then
        return "Next transmute ready in " .. format_duration(remaining) .. "."
    end
    return "Your transmute is ready."
end

local panel_refresh

local function make_button(parent, label, width, anchor, x, y, command)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 24)
    b:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x, y)
    b:SetText(label)
    b:SetScript("OnClick", function()
        SlashCmdList["TRANSMUTEREMINDER"](command)
        if panel_refresh then panel_refresh() end
    end)
    return b
end

local function create_options()
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then
        error("the Settings API is not available on this client")
    end

    local panel = CreateFrame("Frame")
    panel.name = "TransmuteReminder"

    -- The content is taller than the settings window, so it sits in a scroll frame.
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", -28, 4)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(600, 840)
    scroll:SetScrollChild(content)

    local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("TransmuteReminder")

    local desc = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetWidth(560)
    desc:SetJustifyH("LEFT")
    desc:SetText("Shows a \"Check transmutes\" reminder when your alchemy transmute cooldown is ready. "
        .. "No countdown bars. Click the reminder to dismiss it, drag it to move it.")

    local status = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    status:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -16)
    status:SetWidth(560)
    status:SetJustifyH("LEFT")

    local how_title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    how_title:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -20)
    how_title:SetText("How it works")

    local how = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    how:SetPoint("TOPLEFT", how_title, "BOTTOMLEFT", 0, -8)
    how:SetWidth(560)
    how:SetJustifyH("LEFT")
    how:SetText("When you cast a transmute, the addon reads the cooldown from the game and stores the time it ends.\n"
        .. "When you open your Alchemy window, it scans your transmutes and picks up cooldowns that started earlier.\n"
        .. "If the game gives no readable cooldown, it falls back to the number of hours set below.\n"
        .. "Cooldowns are only read outside combat.")

    local actions_title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    actions_title:SetPoint("TOPLEFT", how, "BOTTOMLEFT", 0, -20)
    actions_title:SetText("Actions")

    local b1 = make_button(content, "Show reminder", 140, actions_title, 0, -8, "test")
    local b2 = make_button(content, "Scan Alchemy window", 160, actions_title, 150, -8, "scan")
    local b3 = make_button(content, "Reset position", 130, actions_title, 320, -8, "reset")
    local b4 = make_button(content, "Clear cooldown", 130, actions_title, 460, -8, "clear")

    local hours_label = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    hours_label:SetPoint("TOPLEFT", b1, "BOTTOMLEFT", 0, -20)
    hours_label:SetText("Fallback cooldown (hours):")

    local hours_box = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    hours_box:SetSize(50, 20)
    hours_box:SetPoint("LEFT", hours_label, "RIGHT", 12, 0)
    hours_box:SetAutoFocus(false)
    hours_box:SetNumeric(false)
    hours_box:SetMaxLetters(5)
    hours_box:SetScript("OnEnterPressed", function(self)
        SlashCmdList["TRANSMUTEREMINDER"]("hours " .. (self:GetText() or ""))
        self:ClearFocus()
    end)
    hours_box:SetScript("OnEscapePressed", function(self)
        self:SetText(tostring(db.hours or FALLBACK_HOURS))
        self:ClearFocus()
    end)

    local msg_title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    msg_title:SetPoint("TOPLEFT", hours_label, "BOTTOMLEFT", 0, -24)
    msg_title:SetText("Reminder text")

    local msg_hint = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    msg_hint:SetPoint("TOPLEFT", msg_title, "BOTTOMLEFT", 0, -8)
    msg_hint:SetWidth(560)
    msg_hint:SetJustifyH("LEFT")
    msg_hint:SetText("The words shown when your transmute is ready. Up to " .. MAX_MESSAGE_LENGTH
        .. " characters. Press Enter to save.")

    local msg_box = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    msg_box:SetSize(320, 20)
    msg_box:SetPoint("TOPLEFT", msg_hint, "BOTTOMLEFT", 6, -10)
    msg_box:SetAutoFocus(false)
    msg_box:SetMaxLetters(MAX_MESSAGE_LENGTH)
    msg_box:SetScript("OnEnterPressed", function(self)
        local t = (self:GetText() or ""):match("^%s*(.-)%s*$")
        if t == "" then
            SlashCmdList["TRANSMUTEREMINDER"]("message default")
        else
            SlashCmdList["TRANSMUTEREMINDER"]("message " .. t)
        end
        self:SetText(get_message())
        self:ClearFocus()
    end)
    msg_box:SetScript("OnEscapePressed", function(self)
        self:SetText(get_message())
        self:ClearFocus()
    end)

    local msg_reset = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    msg_reset:SetSize(130, 24)
    msg_reset:SetPoint("LEFT", msg_box, "RIGHT", 12, 0)
    msg_reset:SetText("Reset to default")
    msg_reset:SetScript("OnClick", function()
        SlashCmdList["TRANSMUTEREMINDER"]("message default")
        msg_box:SetText(get_message())
        msg_box:ClearFocus()
    end)

    local size_title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    size_title:SetPoint("TOPLEFT", msg_title, "BOTTOMLEFT", 0, -90)
    size_title:SetText("Reminder size")

    local size_hint = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    size_hint:SetPoint("TOPLEFT", size_title, "BOTTOMLEFT", 0, -8)
    size_hint:SetWidth(560)
    size_hint:SetJustifyH("LEFT")
    size_hint:SetText("Drag the slider to make the reminder smaller or larger. It shows the reminder so you can preview it.")

    local size_slider = CreateFrame("Slider", nil, content)
    size_slider:SetOrientation("HORIZONTAL")
    size_slider:SetSize(260, 16)
    size_slider:SetPoint("TOPLEFT", size_hint, "BOTTOMLEFT", 6, -16)
    size_slider:SetMinMaxValues(MIN_SCALE, MAX_SCALE)
    size_slider:SetValueStep(0.1)
    size_slider:SetObeyStepOnDrag(true)
    local track = size_slider:CreateTexture(nil, "BACKGROUND")
    track:SetColorTexture(0.25, 0.25, 0.25, 0.9)
    track:SetHeight(4)
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")
    size_slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")

    local size_value = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    size_value:SetPoint("LEFT", size_slider, "RIGHT", 14, 0)

    local size_reset = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    size_reset:SetSize(130, 24)
    size_reset:SetPoint("LEFT", size_value, "RIGHT", 24, 0)
    size_reset:SetText("Reset size")

    local updating_slider = false
    local function show_scale(value)
        size_value:SetText(string.format("%.1fx", value))
    end
    size_slider:SetScript("OnValueChanged", function(self, value, userInput)
        if updating_slider then return end
        value = math.floor(value * 10 + 0.5) / 10
        show_scale(value)
        if userInput then
            db.scale = value
            apply_scale()
            db.dismissed = false
            frame:Show()
        end
    end)
    size_reset:SetScript("OnClick", function()
        db.scale = nil
        apply_scale()
        updating_slider = true
        size_slider:SetValue(1)
        updating_slider = false
        show_scale(1)
    end)

    local cmds_title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    cmds_title:SetPoint("TOPLEFT", size_title, "BOTTOMLEFT", 0, -70)
    cmds_title:SetText("Commands")

    local cmds = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    cmds:SetPoint("TOPLEFT", cmds_title, "BOTTOMLEFT", 0, -8)
    cmds:SetWidth(560)
    cmds:SetJustifyH("LEFT")
    cmds:SetSpacing(4)
    cmds:SetText("/tmr    Show the current status\n"
        .. "/tmr options    Open this panel\n"
        .. "/tmr test    Show the reminder now\n"
        .. "/tmr scan    Scan the open Alchemy window and print each transmute's cooldown\n"
        .. "/tmr reset    Reset the reminder position\n"
        .. "/tmr clear    Clear the stored cooldown\n"
        .. "/tmr hours <n>    Set the fallback cooldown length in hours\n"
        .. "/tmr message <text>    Set the reminder text (up to " .. MAX_MESSAGE_LENGTH .. " characters), or /tmr message default\n"
        .. "/tmr scale <n>    Set the reminder size from " .. MIN_SCALE .. " to " .. MAX_SCALE .. " (1 is normal), or /tmr scale default\n"
        .. "/tmr debug [on|off]    Print diagnostic info, or every cast's spell ID")

    panel.refresh = function()
        status:SetText(status_line())
        hours_box:SetText(tostring(db.hours or FALLBACK_HOURS))
        msg_box:SetText(get_message())
        updating_slider = true
        size_slider:SetValue(get_scale())
        updating_slider = false
        show_scale(get_scale())
    end
    panel_refresh = panel.refresh
    panel:SetScript("OnShow", panel.refresh)

    settings_category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(settings_category)
end

local function open_options()
    if settings_category and Settings.OpenToCategory then
        local ok = pcall(Settings.OpenToCategory, settings_category:GetID())
        if ok then return end
    end
    print_msg("the options panel is not available. Use /tmr for the command list.")
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")

events:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        TransmuteReminderDB = TransmuteReminderDB or {}
        db = TransmuteReminderDB
        create_frame()
        local ok, err = pcall(create_options)
        if not ok then
            print_msg("options panel failed to load: " .. tostring(err))
        end

        self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("TRADE_SKILL_SHOW")
        self:RegisterEvent("TRADE_SKILL_LIST_UPDATE")

        C_Timer.NewTicker(CHECK_INTERVAL, check_ready)
        check_ready()

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local _, _, spellID = ...
        if spellID == nil or is_secret(spellID) then return end
        local name = get_spell_name(spellID)
        if db.debug then
            print_msg(string.format("cast: %s (%s)", tostring(name), tostring(spellID)))
        end
        if is_transmute_name(name) then
            -- Give the game a moment to apply the cooldown before reading it.
            C_Timer.After(1.5, function() on_transmute_cast(spellID) end)
        end

    elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_LIST_UPDATE" then
        queue_scan()

    elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" then
        -- Refresh from the game when it is safe, so the stored time stays accurate.
        if db and db.spellID and db.expiry and GetServerTime() < db.expiry then
            local expiry = read_expiry(db.spellID)
            if expiry then db.expiry = expiry end
        end
        check_ready()
    end
end)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

SLASH_TRANSMUTEREMINDER1 = "/tmr"
SlashCmdList["TRANSMUTEREMINDER"] = function(input)
    if not db then return end
    local cmd, arg = (input or ""):match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()

    if cmd == "test" then
        db.dismissed = false
        frame:Show()
    elseif cmd == "options" or cmd == "config" then
        open_options()
    elseif cmd == "scan" then
        scan_recipes(true)
    elseif cmd == "reset" then
        db.point = nil
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
        print_msg("position reset.")
    elseif cmd == "clear" then
        db.expiry = nil
        db.dismissed = false
        frame:Hide()
        print_msg("stored cooldown cleared.")
    elseif cmd == "message" then
        arg = arg:match("^%s*(.-)%s*$")
        if arg == "" then
            print_msg(string.format("reminder text is \"%s\". Use /tmr message <text> to change it, or /tmr message default to reset.",
                escape_pipes(get_message())))
        elseif arg:lower() == "default" then
            db.message = nil
            apply_message()
            print_msg(string.format("reminder text reset to \"%s\".", DEFAULT_MESSAGE))
        else
            local len = text_length(arg)
            if len > MAX_MESSAGE_LENGTH then
                print_msg(string.format("that is %d characters. The limit is %d.", len, MAX_MESSAGE_LENGTH))
            else
                db.message = arg
                apply_message()
                print_msg(string.format("reminder text set to \"%s\".", escape_pipes(arg)))
            end
        end
    elseif cmd == "scale" then
        arg = arg:match("^%s*(.-)%s*$")
        if arg == "" then
            print_msg(string.format("reminder size is %.1f. Use /tmr scale <%s to %s> to change it, or /tmr scale default to reset.",
                get_scale(), MIN_SCALE, MAX_SCALE))
        elseif arg:lower() == "default" then
            db.scale = nil
            apply_scale()
            print_msg("reminder size reset to 1.0.")
        else
            local n = tonumber(arg)
            if n and n >= MIN_SCALE and n <= MAX_SCALE then
                db.scale = n
                apply_scale()
                db.dismissed = false
                frame:Show()
                print_msg(string.format("reminder size set to %.1f.", n))
            else
                print_msg(string.format("usage: /tmr scale <number from %s to %s>", MIN_SCALE, MAX_SCALE))
            end
        end
    elseif cmd == "hours" then
        local hours = tonumber(arg)
        if hours and hours > 0 then
            db.hours = hours
            print_msg(string.format("fallback cooldown set to %s hours.", hours))
        else
            print_msg("usage: /tmr hours <number>")
        end
    elseif cmd == "debug" then
        if arg == "on" then
            db.debug = true
            print_msg("debug on: every cast you make is printed with its spell ID.")
        elseif arg == "off" then
            db.debug = false
            print_msg("debug off.")
        else
            print_msg("debug state:")
            print_msg("  stored spell: " .. tostring(db.spellName) .. " (" .. tostring(db.spellID) .. ")")
            print_msg("  stored expiry: " .. tostring(db.expiry))
            print_msg("  fallback hours: " .. tostring(db.hours or FALLBACK_HOURS))
            print_msg("  C_TradeSkillUI present: " .. tostring(C_TradeSkillUI ~= nil))
            print_msg("  issecretvalue present: " .. tostring(issecretvalue ~= nil))
            if db.spellID then
                local start, duration = get_spell_cooldown(db.spellID)
                print_msg(string.format("  game cooldown: start=%s duration=%s secret=%s",
                    tostring(start), tostring(duration),
                    tostring(is_secret(start) or is_secret(duration))))
            end
            print_msg("  tip: open your Alchemy window and run /tmr scan to see what the game reports.")
            print_msg("  tip: /tmr debug on, then cast a transmute to see its spell ID.")
        end
    else
        if db.expiry then
            local remaining = db.expiry - GetServerTime()
            if remaining > 0 then
                print_msg("next transmute ready in " .. format_duration(remaining) .. ".")
            else
                print_msg("transmute is ready.")
            end
        else
            print_msg("no transmute cooldown recorded yet. It is recorded when you cast one.")
        end
        print_msg("commands: /tmr options, test, scan, reset, clear, hours <n>, message <text>, scale <n>, debug [on|off]")
    end
end
