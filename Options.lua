-- TransmuteReminder: options panel (Options > AddOns > TransmuteReminder)
--
-- A canvas panel in a scroll frame. Each widget is an "item" with place(y),
-- which positions it and returns the next y, and an optional refresh(), which
-- reloads its value from the settings. refresh_all() runs when the panel opens
-- and when Core calls ns.Options_Refresh().

local ADDON_NAME, ns = ...

local settings_category

local X0 = 16
local WIDE = 560

local function choice_name(list, key)
    for _, c in ipairs(list) do
        if c.key == key then return c.name end
    end
    return list[1].name
end

function ns.Options_Create()
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then
        error("the Settings API is not available on this client")
    end
    local s = ns.s

    local panel = CreateFrame("Frame")
    panel.name = "TransmuteReminder"

    -- The content is taller than the settings window, so it sits in a scroll frame.
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", -28, 4)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(600, 1200)
    scroll:SetScrollChild(content)

    -- Each item places itself at the y it is given and returns the next y.
    local items = {}
    local function add(item)
        items[#items + 1] = item
        return item
    end

    local function layout()
        local y = -16
        for _, it in ipairs(items) do y = it.place(y) end
        content:SetHeight(-y + 24)
    end

    local function refresh_all()
        for _, it in ipairs(items) do
            if it.refresh then it.refresh() end
        end
        layout()
    end

    ---------------------------------------------------------------------
    -- Widget builders
    ---------------------------------------------------------------------

    local function text_block(template, text)
        local fs = content:CreateFontString(nil, "ARTWORK", template)
        fs:SetWidth(WIDE)
        fs:SetJustifyH("LEFT")
        fs:SetText(text)
        return add({
            fs = fs,
            place = function(y)
                fs:ClearAllPoints()
                fs:SetPoint("TOPLEFT", X0, y)
                return y - fs:GetStringHeight() - 8
            end,
        })
    end

    local function header(text)
        local fs = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        fs:SetText(text)
        add({
            place = function(y)
                fs:ClearAllPoints()
                fs:SetPoint("TOPLEFT", X0, y - 14)
                return y - 14 - 22
            end,
        })
    end

    local function check(label, get, set)
        local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
        local fs = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        fs:SetText(label)
        fs:SetPoint("LEFT", cb, "RIGHT", 2, 0)
        cb:SetScript("OnClick", function(self)
            set(self:GetChecked() and true or false)
        end)
        add({
            place = function(y)
                cb:ClearAllPoints()
                cb:SetPoint("TOPLEFT", X0 - 4, y)
                return y - 28
            end,
            refresh = function() cb:SetChecked(get() and true or false) end,
        })
    end

    -- A button that steps through a list when clicked (right-click steps back).
    local function cycle(label, list_fn, get, set, width)
        local b = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        b:SetSize(width or 300, 24)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        local function show()
            b:SetText(label .. ": " .. choice_name(list_fn(), get()))
        end
        b:SetScript("OnClick", function(_, button)
            local list = list_fn()
            local idx = 1
            for i, c in ipairs(list) do
                if c.key == get() then idx = i end
            end
            idx = idx + (button == "RightButton" and -1 or 1)
            if idx > #list then idx = 1 end
            if idx < 1 then idx = #list end
            set(list[idx].key)
            show()
        end)
        local item = add({
            button = b,
            place = function(y)
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", X0, y)
                return y - 30
            end,
            refresh = show,
        })
        return item
    end

    local function button_row(defs)
        local buttons = {}
        for _, d in ipairs(defs) do
            local b = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
            b:SetSize(d.width, 24)
            b:SetText(d.label)
            b:SetScript("OnClick", d.onclick)
            buttons[#buttons + 1] = { b = b, x = d.x }
        end
        add({
            place = function(y)
                for _, e in ipairs(buttons) do
                    e.b:ClearAllPoints()
                    e.b:SetPoint("TOPLEFT", X0 + e.x, y)
                end
                return y - 32
            end,
        })
    end

    local function slider(label, min, max, step, get, set, fmt)
        local lbl = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        lbl:SetText(label)

        local sl = CreateFrame("Slider", nil, content)
        sl:SetOrientation("HORIZONTAL")
        sl:SetSize(260, 16)
        sl:SetMinMaxValues(min, max)
        sl:SetValueStep(step)
        sl:SetObeyStepOnDrag(true)
        local track = sl:CreateTexture(nil, "BACKGROUND")
        track:SetColorTexture(0.25, 0.25, 0.25, 0.9)
        track:SetHeight(4)
        track:SetPoint("LEFT")
        track:SetPoint("RIGHT")
        sl:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")

        local val = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        val:SetPoint("LEFT", sl, "RIGHT", 14, 0)

        local updating = false
        sl:SetScript("OnValueChanged", function(_, value, userInput)
            if updating then return end
            value = math.floor(value / step + 0.5) * step
            val:SetText(string.format(fmt, value))
            if userInput then set(value) end
        end)
        add({
            place = function(y)
                lbl:ClearAllPoints()
                lbl:SetPoint("TOPLEFT", X0, y)
                sl:ClearAllPoints()
                sl:SetPoint("TOPLEFT", X0 + 6, y - 24)
                return y - 50
            end,
            refresh = function()
                updating = true
                sl:SetValue(get())
                updating = false
                val:SetText(string.format(fmt, get()))
            end,
        })
    end

    local function edit_row(label, get, apply, width, maxLetters, extra)
        local lbl = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        lbl:SetText(label)
        local box = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
        box:SetSize(width, 20)
        box:SetAutoFocus(false)
        if maxLetters then box:SetMaxLetters(maxLetters) end
        box:SetScript("OnEnterPressed", function(self)
            apply(self:GetText() or "")
            self:SetText(get())
            self:ClearFocus()
        end)
        box:SetScript("OnEscapePressed", function(self)
            self:SetText(get())
            self:ClearFocus()
        end)
        local extraBtn
        if extra then
            extraBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
            extraBtn:SetSize(extra.width, 24)
            extraBtn:SetText(extra.label)
            extraBtn:SetScript("OnClick", function()
                extra.onclick()
                box:SetText(get())
                box:ClearFocus()
            end)
        end
        add({
            place = function(y)
                lbl:ClearAllPoints()
                lbl:SetPoint("TOPLEFT", X0, y)
                box:ClearAllPoints()
                box:SetPoint("TOPLEFT", X0 + 6, y - 22)
                if extraBtn then
                    extraBtn:ClearAllPoints()
                    extraBtn:SetPoint("LEFT", box, "RIGHT", 12, 0)
                end
                return y - 52
            end,
            refresh = function()
                if not box:HasFocus() then box:SetText(get()) end
            end,
        })
    end

    ---------------------------------------------------------------------
    -- Content
    ---------------------------------------------------------------------

    local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    title:SetText("TransmuteReminder")
    add({
        place = function(y)
            title:ClearAllPoints()
            title:SetPoint("TOPLEFT", X0, y)
            return y - 30
        end,
    })

    text_block("GameFontHighlight",
        "Shows a reminder when a transmute or other profession cooldown is ready. No countdown bars. "
        .. "Recipes that share a cooldown are grouped into one entry. "
        .. "Left-click the reminder to open the recipe, right-click to snooze, drag to move it.")

    local status = text_block("GameFontNormal", "")
    status.refresh = function()
        status.fs:SetText(table.concat(ns.StatusLines(), "\n"))
    end

    -- Cooldown checklist (rows are built from whatever has been recorded)
    header("Cooldowns to remind about")
    local rows = {}
    local none = content:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    none:SetText("Nothing recorded yet. Open your Alchemy window on an alchemist.")
    local checklist = add({})
    checklist.refresh = function()
        local keys = ns.all_keys()
        for i, k in ipairs(keys) do
            local row = rows[i]
            if not row then
                row = {}
                row.cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
                row.fs = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                row.fs:SetPoint("LEFT", row.cb, "RIGHT", 2, 0)
                row.cb:SetScript("OnClick", function(self)
                    if self.key then
                        ns.s.disabled[self.key] = (not self:GetChecked()) or nil
                        ns.Update()
                    end
                end)
                rows[i] = row
            end
            row.cb.key = k.key
            if (k.count or 1) > 1 then
                row.fs:SetText(string.format("%s  |cff888888(shared by %d recipes)|r", ns.escape_pipes(k.name), k.count))
            else
                row.fs:SetText(ns.escape_pipes(k.name))
            end
            row.cb:SetChecked(not ns.s.disabled[k.key])
            row.cb:Show()
            row.fs:Show()
        end
        for i = #keys + 1, #rows do
            rows[i].cb.key = nil
            rows[i].cb:Hide()
            rows[i].fs:Hide()
        end
        checklist.count = #keys
    end
    checklist.place = function(y)
        local n = checklist.count or 0
        if n == 0 then
            none:Show()
            none:ClearAllPoints()
            none:SetPoint("TOPLEFT", X0, y)
            return y - 24
        end
        none:Hide()
        for i = 1, n do
            rows[i].cb:ClearAllPoints()
            rows[i].cb:SetPoint("TOPLEFT", X0 - 4, y - (i - 1) * 26)
        end
        return y - n * 26 - 4
    end

    header("Actions")
    button_row({
        { label = "Show reminder", width = 130, x = 0, onclick = function() ns.Preview() end },
        { label = "Scan Alchemy window", width = 160, x = 140, onclick = function() ns.scan(true); refresh_all() end },
        { label = "What's next", width = 120, x = 310, onclick = function() ns.WhatsNext() end },
    })
    button_row({
        { label = "Reset position", width = 130, x = 0, onclick = function() SlashCmdList["TRANSMUTEREMINDER"]("reset") end },
        { label = "Clear cooldowns", width = 160, x = 140, onclick = function()
            SlashCmdList["TRANSMUTEREMINDER"]("clear")
            refresh_all()
        end },
    })

    header("Text and icon")
    edit_row("Reminder text (up to " .. ns.MAX_MESSAGE_LENGTH .. " characters, press Enter to save)",
        function() return ns.get_message() end,
        function(text) ns.set_message(text) end,
        320, ns.MAX_MESSAGE_LENGTH,
        { label = "Reset to default", width = 130, onclick = function() ns.set_message("default") end })
    cycle("Show", function() return ns.DISPLAY_CHOICES end,
        function() return s.display end,
        function(k) s.display = k; ns.Preview() end)
    cycle("Icon", function() return ns.ICON_CHOICES end,
        function() return s.icon end,
        function(k) s.icon = k; ns.Preview() end)
    cycle("Font", function() return ns.FONT_CHOICES end,
        function() return s.font end,
        function(k) s.font = k; ns.Preview() end)

    local swatch = content:CreateTexture(nil, "ARTWORK")
    swatch:SetSize(20, 20)
    local colorBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    colorBtn:SetSize(130, 24)
    colorBtn:SetText("Text color...")
    local colorReset = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    colorReset:SetSize(130, 24)
    colorReset:SetText("Reset color")
    local function paint_swatch()
        local c = s.textColor
        swatch:SetColorTexture(c[1], c[2], c[3], 1)
    end
    colorBtn:SetScript("OnClick", function()
        local c = s.textColor
        local info = {
            r = c[1], g = c[2], b = c[3], hasOpacity = false,
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                s.textColor = { r, g, b }
                paint_swatch()
                ns.Preview()
            end,
            cancelFunc = function(prev)
                if type(prev) == "table" and prev.r then
                    s.textColor = { prev.r, prev.g, prev.b }
                    paint_swatch()
                    ns.Preview()
                end
            end,
        }
        if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow(info)
        else
            ns.print("the color picker is not available on this client.")
        end
    end)
    colorReset:SetScript("OnClick", function()
        s.textColor = nil
        paint_swatch()
        ns.Preview()
    end)
    add({
        place = function(y)
            colorBtn:ClearAllPoints()
            colorBtn:SetPoint("TOPLEFT", X0, y)
            swatch:ClearAllPoints()
            swatch:SetPoint("LEFT", colorBtn, "RIGHT", 10, 0)
            colorReset:ClearAllPoints()
            colorReset:SetPoint("LEFT", swatch, "RIGHT", 14, 0)
            return y - 32
        end,
        refresh = paint_swatch,
    })

    header("Look")
    slider("Size", ns.MIN_SCALE, ns.MAX_SCALE, 0.1,
        function() return ns.get_scale() end,
        function(v) s.scale = v; ns.Popup_ApplyScale(); ns.Preview() end,
        "%.1fx")
    slider("Background opacity", 0, 1, 0.05,
        function() return s.bgAlpha end,
        function(v) s.bgAlpha = v; ns.Preview() end,
        "%.2f")
    check("Show a border",
        function() return s.border end,
        function(v) s.border = v; ns.Preview() end)
    cycle("Animation", function() return ns.ANIM_CHOICES end,
        function() return s.animation end,
        function(k) s.animation = k; ns.Preview() end)
    check("Lock position (stops dragging)",
        function() return s.locked end,
        function(v) s.locked = v end)

    header("Alerts")
    cycle("Sound", function() return ns.available_sounds() end,
        function() return s.sound end,
        function(k) s.sound = k; ns.play_sound(k) end)
    slider("Repeat every (minutes, 0 = never)", 0, 30, 1,
        function() return s.repeatMinutes end,
        function(v) s.repeatMinutes = v end,
        "%d")
    slider("Snooze length on right-click (minutes, 0 = dismiss)", 0, 60, 5,
        function() return s.snoozeMinutes end,
        function(v) s.snoozeMinutes = v end,
        "%d")
    check("Also print a chat message when ready",
        function() return s.chat end,
        function(v) s.chat = v end)

    header("When to show")
    check("Hide in combat (recommended)",
        function() return s.hideCombat end,
        function(v) s.hideCombat = v; ns.Update() end)
    check("Hide in instances",
        function() return s.hideInstance end,
        function(v) s.hideInstance = v; ns.Update() end)
    check("Hide while in a group",
        function() return s.hideGroup end,
        function(v) s.hideGroup = v; ns.Update() end)
    check("Remind about cooldowns ready on other characters",
        function() return s.remindAlts end,
        function(v) s.remindAlts = v; ns.Update() end)
    check("Left-click opens the recipe",
        function() return s.clickOpens end,
        function(v) s.clickOpens = v end)
    check("Show the minimap button",
        function() return not s.minimapHide end,
        function(v) s.minimapHide = not v; ns.Minimap_Update() end)

    header("Manual cooldown")
    edit_row("Hours to use when the game doesn't report a cooldown",
        function() return tostring(s.hours) end,
        function(text)
            local n = tonumber(text)
            if n and n > 0 then s.hours = n end
        end,
        60, 5)

    header("Commands")
    text_block("GameFontHighlight",
        "/tmr    Show the current status\n"
        .. "/tmr options    Open this panel\n"
        .. "/tmr test    Show the reminder now\n"
        .. "/tmr scan    Scan the open Alchemy window and list each transmute with its time left\n"
        .. "/tmr whatsnext    Show the next cooldown to finish\n"
        .. "/tmr reset    Reset the reminder position\n"
        .. "/tmr clear    Clear this character's stored cooldowns\n"
        .. "/tmr lock, /tmr unlock    Lock or unlock the position\n"
        .. "/tmr minimap    Show or hide the minimap button\n"
        .. "/tmr message <text>    Set the reminder text, or /tmr message default\n"
        .. "/tmr scale <n>    Set the size from " .. ns.MIN_SCALE .. " to " .. ns.MAX_SCALE .. ", or /tmr scale default\n"
        .. "/tmr hours <n>    Set the manual cooldown in hours\n"
        .. "/tmr alts    List cooldowns recorded on other characters\n"
        .. "/tmr forget <name>    Remove a character you no longer play\n"
        .. "/tmr debug [on|off]    Print diagnostic info, or every cast's spell ID")

    panel.refresh = refresh_all
    panel:SetScript("OnShow", refresh_all)
    ns.Options_Refresh = function()
        if panel:IsVisible() then refresh_all() end
    end

    settings_category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(settings_category)
end

function ns.OpenOptions()
    if settings_category and Settings.OpenToCategory then
        local ok = pcall(Settings.OpenToCategory, settings_category:GetID())
        if ok then return end
    end
    ns.print("the options panel is not available. Use /tmr for the command list.")
end
