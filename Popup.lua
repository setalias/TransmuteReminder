-- TransmuteReminder: the reminder window, its tooltip, the minimap button, and the
-- AddOn Compartment entry.

local ADDON_NAME, ns = ...

ns.ICON_CHOICES = {
    { key = "recipe", name = "Recipe icon (automatic)" },
    { key = "alchemy", name = "Alchemy", texture = "Interface\\Icons\\Trade_Alchemy" },
    { key = "potion", name = "Potion", texture = "Interface\\Icons\\INV_Potion_54" },
    { key = "gem", name = "Diamond", texture = "Interface\\Icons\\INV_Misc_Gem_Diamond_01" },
    { key = "ingot", name = "Ingot", texture = "Interface\\Icons\\INV_Ingot_Thorium" },
    { key = "bell", name = "Bell", texture = "Interface\\Icons\\INV_Misc_Bell_01" },
}
ns.FONT_CHOICES = {
    { key = "default", name = "Default" },
    { key = "arial", name = "Arial Narrow", path = "Fonts\\ARIALN.TTF" },
    { key = "morpheus", name = "Morpheus", path = "Fonts\\MORPHEUS.TTF" },
    { key = "skurri", name = "Skurri", path = "Fonts\\SKURRI.TTF" },
}
ns.DISPLAY_CHOICES = {
    { key = "both", name = "Text and icon" },
    { key = "text", name = "Text only" },
    { key = "icon", name = "Icon only" },
}
ns.ANIM_CHOICES = {
    { key = "pulse", name = "Pulse" },
    { key = "glow", name = "Glow" },
    { key = "none", name = "None" },
}

local FALLBACK_ICON = "Interface\\Icons\\Trade_Alchemy"
local PAD, ICON_SIZE, GAP = 12, 28, 8
local SUB_WIDTH = 300

local f

local function find_choice(list, key)
    for _, c in ipairs(list) do
        if c.key == key then return c end
    end
    return list[1]
end

local function font_path()
    local c = find_choice(ns.FONT_CHOICES, ns.s.font)
    return c.path or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

local function icon_texture(item)
    local choice = find_choice(ns.ICON_CHOICES, ns.s.icon)
    if choice.key == "recipe" then
        return (item and item.icon) or FALLBACK_ICON
    end
    return choice.texture
end

---------------------------------------------------------------------------
-- Position and size
---------------------------------------------------------------------------

local function save_position()
    local point, _, relPoint, x, y = f:GetPoint()
    ns.s.point = { point, relPoint, x, y }
end

local function default_position()
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
end

function ns.Popup_ResetPosition()
    if f then default_position() end
end

-- Changes the size of the reminder while keeping it centered where it was.
function ns.Popup_ApplyScale()
    if not f then return end
    local scale = ns.get_scale()
    local cx, cy = f:GetCenter()
    local old = f:GetEffectiveScale()
    f:SetScale(scale)
    if cx and cy then
        local new = f:GetEffectiveScale()
        f:ClearAllPoints()
        f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx * old / new, cy * old / new)
        save_position()
    end
end

---------------------------------------------------------------------------
-- Tooltip (shared with the minimap button and the AddOn Compartment)
---------------------------------------------------------------------------

function ns.FillTooltip(tt, mode)
    tt:AddLine("TransmuteReminder", 1, 0.82, 0)
    for _, line in ipairs(ns.StatusLines()) do
        tt:AddLine(line, 1, 1, 1, true)
    end
    local known = ns.KnownTransmutes()
    if #known > 0 then
        local shown = {}
        for i = 1, math.min(#known, 8) do shown[i] = known[i] end
        local more = #known > 8 and string.format(" and %d more", #known - 8) or ""
        tt:AddLine(" ")
        tt:AddLine("Transmutes you know: " .. table.concat(shown, ", ") .. more, 0.7, 0.7, 0.7, true)
    end
    tt:AddLine(" ")
    local s = ns.s
    if mode == "popup" then
        if s.clickOpens then
            tt:AddLine("Left-click: open the recipe and dismiss", 0.6, 0.8, 1)
            tt:AddLine("Ctrl-click or middle-click: dismiss", 0.6, 0.8, 1)
        else
            tt:AddLine("Left-click or middle-click: dismiss", 0.6, 0.8, 1)
        end
        if s.snoozeMinutes > 0 then
            tt:AddLine(string.format("Right-click: snooze %d minutes", s.snoozeMinutes), 0.6, 0.8, 1)
        else
            tt:AddLine("Right-click: dismiss", 0.6, 0.8, 1)
        end
        if not s.locked then
            tt:AddLine("Drag: move", 0.6, 0.8, 1)
        end
    else
        tt:AddLine("Left-click: open options", 0.6, 0.8, 1)
        if mode == "minimap" then
            tt:AddLine("Right-click: show the reminder", 0.6, 0.8, 1)
        end
    end
end

---------------------------------------------------------------------------
-- The reminder window
---------------------------------------------------------------------------

local function set_animation(mode)
    if f.animMode == mode then return end
    f.animMode = mode
    f.pulse:Stop()
    f.glowAnim:Stop()
    f.glow:Hide()
    f.glow:SetAlpha(1)
    f:SetAlpha(1)
    if mode == "pulse" then
        f.pulse:Play()
    elseif mode == "glow" then
        f.glow:Show()
        f.glowAnim:Play()
    end
end

function ns.Popup_Create()
    local s = ns.s

    f = CreateFrame("Button", "TransmuteReminderFrame", UIParent, "BackdropTemplate")
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
    f:SetScale(ns.get_scale())

    local p = s.point
    f:ClearAllPoints()
    if p then
        f:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else
        default_position()
    end

    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(ICON_SIZE, ICON_SIZE)

    f.main = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.main:SetJustifyH("LEFT")
    f.main:SetWordWrap(false)

    f.sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.sub:SetJustifyH("LEFT")
    f.sub:SetWidth(SUB_WIDTH)

    -- Glow: a gold outline just outside the frame that fades in and out,
    -- so it never covers the text.
    f.glow = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.glow:SetPoint("TOPLEFT", -5, 5)
    f.glow:SetPoint("BOTTOMRIGHT", 5, -5)
    f.glow:SetFrameLevel(math.max(0, (f:GetFrameLevel() or 1) - 1))
    f.glow:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16 })
    f.glow:SetBackdropBorderColor(1, 0.82, 0.1, 1)
    f.glow:Hide()

    f.pulse = f:CreateAnimationGroup()
    f.pulse:SetLooping("BOUNCE")
    local pulseAlpha = f.pulse:CreateAnimation("Alpha")
    pulseAlpha:SetFromAlpha(1)
    pulseAlpha:SetToAlpha(0.45)
    pulseAlpha:SetDuration(0.9)

    f.glowAnim = f.glow:CreateAnimationGroup()
    f.glowAnim:SetLooping("BOUNCE")
    local glowAlpha = f.glowAnim:CreateAnimation("Alpha")
    glowAlpha:SetFromAlpha(0.1)
    glowAlpha:SetToAlpha(1)
    glowAlpha:SetDuration(1.1)

    f:SetScript("OnDragStart", function(self)
        if not ns.s.locked then self:StartMoving() end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        save_position()
    end)
    f:SetScript("OnClick", function(self, button)
        if ns.previewUntil then
            -- A preview from the options or /tmr test: just close it.
            ns.previewUntil = nil
            ns.Update()
            return
        end
        if button == "RightButton" then
            ns.Snooze()
        elseif button == "MiddleButton" then
            ns.Dismiss()
        else
            if ns.s.clickOpens and not IsControlKeyDown() then
                ns.OpenProfession()
            end
            ns.Dismiss()
        end
    end)
    f:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        ns.FillTooltip(GameTooltip, "popup")
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f:SetScript("OnHide", function(self)
        self.animMode = nil
        self.sig = nil
        self.pulse:Stop()
        self.glowAnim:Stop()
    end)

    f:Hide()
end

-- state is nil to hide, or { own = {...}, alts = {...}, preview = bool }.
function ns.Popup_Set(state)
    if not f then return end
    if not state then
        f:Hide()
        return
    end
    local s = ns.s

    local primary = state.own[1] or state.alts[1]
    local named = primary and not primary.transmute
    local mainText = named and ("Check " .. primary.name) or ns.get_message()

    -- Second line: which of this character's cooldowns are ready, then alts.
    local parts = {}
    local names = {}
    for _, it in ipairs(state.own) do
        if not it.fake and not (named and it == primary) then
            names[#names + 1] = ns.short_label(it)
        end
    end
    if #names > 0 then
        parts[#parts + 1] = (named and state.own[1] == primary and "Also ready: " or "Ready: ")
            .. table.concat(names, ", ")
    end
    if #state.alts > 0 then
        local order, byChar = {}, {}
        for _, it in ipairs(state.alts) do
            if not byChar[it.char] then
                byChar[it.char] = {}
                order[#order + 1] = it.char
            end
            table.insert(byChar[it.char], ns.short_label(it))
        end
        local chunks = {}
        for _, c in ipairs(order) do
            chunks[#chunks + 1] = c .. " (" .. table.concat(byChar[c], ", ") .. ")"
        end
        parts[#parts + 1] = "Alts: " .. table.concat(chunks, ", ")
    end
    local subText = table.concat(parts, "\n")

    local showText = s.display ~= "icon"
    local showIcon = s.display ~= "text"
    local color = s.textColor
    local path = font_path()
    local texture = icon_texture(primary)

    -- Skip the rebuild when nothing visible changed (the 30 second check calls this).
    local sig = table.concat({ mainText, subText, s.display, tostring(texture), path,
        color[1], color[2], color[3], s.bgAlpha, tostring(s.border), s.animation }, "\031")
    if f.sig == sig and f:IsShown() then return end
    f.sig = sig

    f.main:SetFont(path, 18, "OUTLINE")
    f.main:SetTextColor(color[1], color[2], color[3])
    f.main:SetText(ns.escape_pipes(mainText))
    f.sub:SetFont(path, 12, "")
    f.sub:SetText(ns.escape_pipes(subText))

    local subShown = showText and subText ~= ""
    local textW = showText and f.main:GetStringWidth() or 0
    if subShown then textW = math.max(textW, math.min(f.sub:GetStringWidth(), SUB_WIDTH)) end
    local textH = showText and f.main:GetStringHeight() or 0
    local subH = subShown and f.sub:GetStringHeight() or 0

    local leftX = PAD
    if showIcon then
        f.icon:SetTexture(texture)
        f.icon:ClearAllPoints()
        f.icon:SetPoint("LEFT", f, "LEFT", PAD, 0)
        f.icon:Show()
        leftX = PAD + ICON_SIZE + GAP
    else
        f.icon:Hide()
    end

    f.main:ClearAllPoints()
    f.sub:ClearAllPoints()
    if showText then
        f.main:Show()
        if subShown then
            f.main:SetPoint("TOPLEFT", f, "TOPLEFT", leftX, -PAD)
            f.sub:SetPoint("TOPLEFT", f.main, "BOTTOMLEFT", 0, -4)
            f.sub:Show()
        else
            f.main:SetPoint("LEFT", f, "LEFT", leftX, 0)
            f.sub:Hide()
        end
    else
        f.main:Hide()
        f.sub:Hide()
    end

    local contentH = math.max(showIcon and ICON_SIZE or 0, textH + (subShown and (subH + 4) or 0))
    local width = PAD * 2 + (showIcon and (ICON_SIZE + (showText and GAP or 0)) or 0) + textW
    f:SetSize(math.max(60, width), math.max(40, contentH + PAD * 2))

    f:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = s.border and "Interface\\Tooltips\\UI-Tooltip-Border" or nil,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0, 0, 0, s.bgAlpha)

    f:Show()
    set_animation(s.animation)
end

---------------------------------------------------------------------------
-- Minimap button
---------------------------------------------------------------------------

local function place_minimap_button(b)
    local rad = math.rad(ns.s.minimapAngle)
    local r = (Minimap:GetWidth() / 2) + 5
    b:ClearAllPoints()
    b:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * r, math.sin(rad) * r)
end

function ns.Minimap_Update()
    local b = ns.minimapButton
    if not b then return end
    if ns.s.minimapHide then
        b:Hide()
    else
        place_minimap_button(b)
        b:Show()
    end
end

function ns.Minimap_Create()
    local b = CreateFrame("Button", "TransmuteReminderMinimapButton", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")

    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(FALLBACK_ICON)
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", 7, -6)

    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    b:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            ns.Preview()
        elseif ns.OpenOptions then
            ns.OpenOptions()
        end
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        ns.FillTooltip(GameTooltip, "minimap")
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)

    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            ns.s.minimapAngle = math.deg(math.atan2(py / scale - my, px / scale - mx))
            place_minimap_button(self)
        end)
    end)
    b:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    ns.minimapButton = b
    ns.Minimap_Update()
end

---------------------------------------------------------------------------
-- AddOn Compartment (the globals are named in the TOC file)
---------------------------------------------------------------------------

function TransmuteReminder_OnAddonCompartmentClick()
    if ns.OpenOptions then ns.OpenOptions() end
end

function TransmuteReminder_OnAddonCompartmentEnter(_, menuButtonFrame)
    GameTooltip:SetOwner(menuButtonFrame, "ANCHOR_LEFT")
    ns.FillTooltip(GameTooltip, "compartment")
    GameTooltip:Show()
end

function TransmuteReminder_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end
