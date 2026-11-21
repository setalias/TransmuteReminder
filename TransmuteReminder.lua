-- TransmuteReminder
-- Shows a small "Check transmutes" frame when the alchemy transmute cooldown is ready.
-- Built for WoW: Forever. Only reads cooldowns outside combat, because Forever
-- applies Midnight-style addon restrictions (secret values) in combat.

local ADDON_NAME = ...

local FALLBACK_HOURS = 20      -- used only if the game gives no readable cooldown
local MIN_REAL_COOLDOWN = 120  -- seconds; anything shorter is treated as a global cooldown
local CHECK_INTERVAL = 30      -- seconds between ready checks

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

    local p = db.point
    frame:ClearAllPoints()
    if p then
        frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
    end

    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("CENTER")
    text:SetText("Check transmutes")
    frame.text = text

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
-- Events
---------------------------------------------------------------------------

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")

events:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        TransmuteReminderDB = TransmuteReminderDB or {}
        db = TransmuteReminderDB
        create_frame()

        self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")

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
        print_msg("commands: /tmr test, reset, clear, hours <n>, debug [on|off]")
    end
end
