-- Runs TransmuteReminder against tests/mock.lua. From the repo root: lua tests/run.lua
package.path = "tests/?.lua;" .. package.path
math.atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
local realprint = print
local M = require("mock")

local FILES = { "Core.lua", "Popup.lua", "Options.lua" }
local passed, failed = 0, 0
local function check(cond, msg)
    if cond then passed = passed + 1 else failed = failed + 1; realprint("FAIL: " .. msg) end
end
local function try(label, fn)
    local ok, err = xpcall(fn, debug.traceback)
    if ok then passed = passed + 1 else failed = failed + 1; realprint("ERROR in " .. label .. ": " .. tostring(err)) end
    return ok
end
local function popup() return _G.TransmuteReminderFrame end
local function slash(s) SlashCmdList["TRANSMUTEREMINDER"](s) end
local function printed(str)
    for _, p in ipairs(M.printed) do if p:find(str, 1, true) then return true end end
    return false
end
local function count(t) local n = 0; for _ in pairs(t) do n = n + 1 end return n end
local function has_key(list, k) for _, it in ipairs(list) do if it.key == k then return true end end return false end
local function scan(cds) M.recipeCooldowns = cds; slash("scan") end

-- ===== Old data is cleared on the data version bump =====
M.install()
TransmuteReminderAccountDB = {
    settings = { message = "Old text", disabled = { transmute = true } },
    chars = { ["Ayla-Area 52"] = { cooldowns = { transmute = { name = "Transmutes", expiry = 1 } } } },
}
local ns
try("load", function() ns = M.load(FILES) end)
try("login", function() M.fire(ns, "PLAYER_LOGIN") end)
check(ns.s.message == "Old text", "settings kept across version bump")
check(count(ns.me.cooldowns) == 0 and count(ns.s.disabled) == 0, "old cooldowns and checklist cleared")
check(TransmuteReminderAccountDB.version == ns.DATA_VERSION, "data version stored")
check(M.settingsRegistered and ns.minimapButton ~= nil, "options and minimap created")

-- ===== Fresh start: scan builds groups =====
M.install()
TransmuteReminderAccountDB = nil
ns = M.load(FILES)
M.fire(ns, "PLAYER_LOGIN")
check(not popup().__shown, "hidden at start")

-- Arcanite, Water to Air and Onyxia share 36h; Iron to Gold 1h; Mooncloth 4 days; unlearned ignored.
scan({ [111] = 130000, [777] = 130001, [666] = 130002, [222] = 3600, [333] = 345600, [888] = 50 })
local arc, itg, moon = ns.me.cooldowns["g:111"], ns.me.cooldowns["g:222"], ns.me.cooldowns["g:333"]
check(arc and arc.count == 3 and arc.transmute and arc.name == "Transmute: Arcanite", "Arcanite group has 3 recipes")
check(ns.me.recipes[666].group == "g:111", "Onyxia scale joins the Arcanite group")
check(itg and itg.count == 1 and itg.transmute, "Iron to Gold is its own group")
check(moon and not moon.transmute, "Mooncloth tracked as a non-transmute group")
check(ns.me.recipes[888] == nil, "unlearned recipe ignored")
check(count(ns.me.cooldowns) == 3, "exactly three groups")
check(printed("Transmute: Iron to Gold - 1h 0m"), "scan list shows time")
check(not printed("next "), "scan prints no next lines")
M.printed = {}
slash("whatsnext")
check(#M.printed == 1 and printed("next: Iron to Gold in 1h 0m"), "whatsnext shows only the soonest")

-- Reopening the window does not repeat messages
M.printed = {}
M.advance(20)
M.fire(ns, "TRADE_SKILL_SHOW"); M.advance(2); M.runTimers()
check(#M.printed == 0, "auto scan quiet when unchanged")

-- Someone else's profession is not scanned
M.linked = true
M.printed = {}
scan({ [111] = 5 })
check(printed("someone else"), "linked profession refused")
check(ns.me.cooldowns["g:111"].count == 3, "linked scan changed nothing")
M.linked = false

-- ===== Iron to Gold ready; Arcanite still tracked =====
M.advance(3600 + 5); M.runTimers()
check(popup().__shown, "popup shown when Iron to Gold is ready")
check(ns.lastState.own[1].key == "g:222", "Iron to Gold is the ready item")
check(popup().sub.__text == "Ready: Iron to Gold", "sub line names it: " .. tostring(popup().sub.__text))
M.printed = {}
slash("whatsnext")
check(printed("ready now: Iron to Gold."), "whatsnext reports ready items")
check(popup().main.__text == "Check transmutes", "main text is the message")

-- casting Iron to Gold re-reads everything and keeps Arcanite intact
M.spellCooldowns = {
    [222] = { GetTime(), 3600 },
    [111] = { GetTime() - 3605, 130000 }, [777] = { GetTime() - 3605, 130000 }, [666] = { GetTime() - 3605, 130000 },
}
local arcExpiry = ns.me.cooldowns["g:111"].expiry
M.printed = {}
M.fire(ns, "UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 222)
M.advance(2); M.runTimers()
check(not popup().__shown, "hidden after casting the ready transmute")
check(math.abs(ns.me.cooldowns["g:222"].expiry - (M.now() + 3598)) < 5, "Iron to Gold expiry updated")
check(math.abs(ns.me.cooldowns["g:111"].expiry - arcExpiry) < 30, "Arcanite expiry untouched by Iron to Gold cast")
check(ns.me.cooldowns["g:111"].count == 3, "Arcanite group intact")
check(printed("next Iron to Gold ready in 59m."), "clean cast message")
check(ns.me.recipes[222].duration == 3600, "duration remembered")

-- ===== Fallback uses the remembered duration =====
M.spellCooldowns = {}
M.advance(3700); M.runTimers()
M.printed = {}
M.fire(ns, "UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 222)
M.advance(2); M.runTimers()
check(math.abs(ns.me.cooldowns["g:222"].expiry - (M.now() - 2 + 3600)) < 5, "fallback uses last seen 1h duration")
check(printed("(estimated)"), "estimate is labeled")
check(ns.me.cooldowns["g:111"] ~= nil, "Arcanite group survives a fallback cast")

-- unknown first-time transmute with no data uses the hours setting
M.spells[999] = "Transmute: Brand New"
M.printed = {}
M.fire(ns, "UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 999)
M.advance(2); M.runTimers()
check(ns.me.cooldowns["g:999"] and math.abs(ns.me.cooldowns["g:999"].expiry - (M.now() - 2 + 36 * 3600)) < 5, "hours setting is the last resort")
-- known spell ID detection without an English name
M.spells[17187] = "Transmutation : Arcanite"
M.spells[17187] = "Arkanit"
M.spellCooldowns[17187] = { GetTime(), 5000 }
M.fire(ns, "UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 17187)
M.advance(2); M.runTimers()
check(ns.me.recipes[17187] and ns.me.recipes[17187].transmute, "known transmute ID detected without English name")
-- hearthstone ignored
local before = count(ns.me.recipes)
M.spellCooldowns[444] = { GetTime(), 1800 }
M.fire(ns, "UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 444)
M.advance(2); M.runTimers()
check(count(ns.me.recipes) == before, "hearthstone ignored")

-- ===== Separate timers ending a minute apart stay separate =====
slash("clear")
scan({ [222] = 3600, [777] = 3660 })
check(ns.me.cooldowns["g:222"] and ns.me.cooldowns["g:777"], "timers 60 seconds apart are separate groups")

-- ===== Clicks, snooze, dismiss =====
slash("clear")
check(count(ns.me.cooldowns) == 0, "clear empties groups")
scan({ [111] = 60, [777] = 60, [222] = 600 })
M.advance(70); M.runTimers()
check(popup().__shown and ns.lastState.own[1].key == "g:111", "Arcanite group ready")
local onclick = popup().__scripts["OnClick"]
try("left click", function() onclick(popup(), "LeftButton") end)
check(M.opened == 111, "left click opens the ready recipe")
check(not popup().__shown, "dismissed")
M.ticker()
check(not popup().__shown, "stays dismissed")
M.advance(600); M.runTimers()
check(popup().__shown and ns.lastState.own[1].key == "g:222", "Iron to Gold shows after Arcanite was dismissed")
try("right click", function() onclick(popup(), "RightButton") end)
check(not popup().__shown and ns.snoozeUntil, "snoozed")
M.advance(10 * 60 + 5); M.runTimers()
check(popup().__shown, "back after snooze")
try("middle click", function() onclick(popup(), "MiddleButton") end)
check(not popup().__shown, "middle click dismisses")

-- non-transmute primary uses its name
scan({ [333] = 30 })
M.advance(40); M.runTimers()
check(popup().main.__text == "Check Primal Mooncloth", "named main text for a non-transmute")
ns.s.disabled["g:333"] = true; ns.Update()
check(not popup().__shown, "unticked group not reminded")
ns.s.disabled["g:333"] = nil
ns.Dismiss()

-- redraw only on change
local f = popup()
ns.Popup_Set({ own = { { key = "x", name = "Transmute: Arcanite", transmute = true } }, alts = {} })
local sig = f.sig
f.main.__text = "tampered"
ns.Popup_Set({ own = { { key = "x", name = "Transmute: Arcanite", transmute = true } }, alts = {} })
check(f.sig == sig and f.main.__text == "tampered", "unchanged state skips the rebuild")
ns.Popup_Set(nil)

-- ===== Alerts and hiding =====
ns.s.sound = "alarm"; ns.s.chat = true; ns.s.repeatMinutes = 5
slash("clear")
M.sounds, M.printed = {}, {}
scan({ [222] = 30 })
M.advance(40); M.runTimers()
check(#M.sounds == 1 and printed("ready: Iron to Gold"), "sound and chat once")
M.ticker()
check(#M.sounds == 1, "no repeat before the interval")
M.advance(301); M.ticker()
check(#M.sounds == 2, "repeat after the interval")
ns.s.sound = "none"; ns.s.chat = false; ns.s.repeatMinutes = 0
M.combat = true; M.fire(ns, "PLAYER_REGEN_DISABLED")
check(not popup().__shown, "hidden in combat")
M.combat = false; M.fire(ns, "PLAYER_REGEN_ENABLED")
check(popup().__shown, "back after combat")
ns.s.hideInstance = true; M.inInstance = true; ns.Update()
check(not popup().__shown, "hidden in instance")
M.inInstance = false; ns.s.hideInstance = false
ns.s.hideGroup = true; M.inGroup = true; ns.Update()
check(not popup().__shown, "hidden in group")
M.inGroup = false; ns.s.hideGroup = false; ns.Update()
for _, mode in ipairs({ "text", "icon", "both" }) do
    ns.s.display = mode
    try("display " .. mode, function() ns.Popup_Set(ns.lastState) end)
end
for _, anim in ipairs({ "glow", "none", "pulse" }) do
    ns.s.animation = anim
    try("anim " .. anim, function() ns.Popup_Set(ns.lastState) end)
end
ns.Dismiss()

-- ===== Alts: per-cooldown dismissal =====
slash("clear")
scan({ [111] = 30, [222] = 600 })   -- main character: Arcanite soon, Iron to Gold later
M.charName = "Bob"
M.install({ keepTime = true })
ns = M.load(FILES)
M.fire(ns, "PLAYER_LOGIN")
M.advance(40); M.runTimers()
check(#ns.ready_alts() == 1 and ns.ready_alts()[1].key == "g:111", "alt Arcanite ready")
check(popup().__shown and popup().sub.__text:find("Ayla (Arcanite)", 1, true), "alt shown in sub line")
ns.Dismiss()
check(not popup().__shown, "alt reminder dismissed")
M.advance(600); M.runTimers()
check(popup().__shown and ns.ready_alts()[1].key == "g:222", "a later alt cooldown still reminds")
slash("alts")
check(printed("Iron to Gold (Ayla): ready"), "/tmr alts output")
-- a character with no professions: status lists alts, no "nothing recorded" line
local status = table.concat(ns.StatusLines(), "\n")
check(not status:find("No cooldowns recorded", 1, true) and status:find("(Ayla)", 1, true), "status on a character without cooldowns shows alts")
M.printed = {}
M.recipes = {}
slash("scan")
check(printed("no profession cooldowns found on this character"), "scan on a non-alchemist")
M.printed = {}
slash("whatsnext")
check(printed("(Ayla)"), "whatsnext falls back to alts")
slash("forget Ayla")
check(#ns.alt_items() == 0, "forgot Ayla")

-- ===== Options panel =====
local panel = M.category.panel
try("options show", function() panel.__scripts["OnShow"]() end)
local buttons, sliders, checks, boxes = 0, 0, 0, 0
for _, fr in ipairs(M.frames) do
    if fr.__template == "UIPanelButtonTemplate" and fr.__scripts["OnClick"] then
        for _, b in ipairs({ "LeftButton", "RightButton" }) do
            try("button", function() fr.__scripts["OnClick"](fr, b) end)
        end
        buttons = buttons + 1
    elseif fr.__template == "UICheckButtonTemplate" and fr.__scripts["OnClick"] then
        fr.__checked = true; try("check", function() fr.__scripts["OnClick"](fr) end)
        fr.__checked = false; try("check off", function() fr.__scripts["OnClick"](fr) end)
        checks = checks + 1
    elseif fr.__kind == "Slider" and fr.__scripts["OnValueChanged"] then
        try("slider", function() fr.__scripts["OnValueChanged"](fr, 1.3, true) end)
        sliders = sliders + 1
    elseif fr.__template == "InputBoxTemplate" and fr.__scripts["OnEnterPressed"] then
        fr.__text = "Hello there"
        try("box enter", function() fr.__scripts["OnEnterPressed"](fr) end)
        try("box escape", function() fr.__scripts["OnEscapePressed"](fr) end)
        fr.__focus = true; fr.__text = "typing"
        ns.Options_Refresh()
        check(fr.__text == "typing", "refresh does not overwrite a focused box")
        fr.__focus = false
        boxes = boxes + 1
    end
end
check(buttons >= 8 and sliders >= 4 and checks >= 6 and boxes >= 2,
    string.format("widgets: %d buttons, %d sliders, %d checks, %d boxes", buttons, sliders, checks, boxes))
try("color picker", function() M.pickerInfo.swatchFunc(); M.pickerInfo.cancelFunc({ r = 1, g = 0, b = 0 }) end)
try("open options", function() ns.OpenOptions() end)
check(M.openedCategory == 7, "settings opened")
check(ns.set_message(string.rep("x", 41)) == false and ns.set_message(string.rep("x", 40)) == true, "40 character limit")
ns.set_message("default")

-- ===== Every slash command runs =====
for _, c in ipairs({ "", "test", "options", "scan", "reset", "clear", "lock", "unlock", "minimap", "minimap",
    "message", "message Hi", "message default", "scale", "scale 2", "scale default", "scale 9",
    "hours", "hours 24", "whatsnext", "next", "alts", "forget", "forget nobody", "debug", "debug on", "scan", "debug off", "bogus" }) do
    try("slash '" .. c .. "'", function() slash(c) end)
end
local mb = ns.minimapButton
try("minimap", function()
    mb.__scripts["OnDragStart"](mb); mb.__scripts["OnUpdate"](); mb.__scripts["OnDragStop"](mb)
    mb.__scripts["OnClick"](mb, "LeftButton"); mb.__scripts["OnClick"](mb, "RightButton")
    mb.__scripts["OnEnter"](mb); mb.__scripts["OnLeave"](mb)
end)
try("compartment", function()
    TransmuteReminder_OnAddonCompartmentClick()
    TransmuteReminder_OnAddonCompartmentEnter("x", mb)
    TransmuteReminder_OnAddonCompartmentLeave()
end)
M.tooltipLines = {}
try("tooltip", function() ns.FillTooltip(GameTooltip, "popup") end)
check(#M.tooltipLines > 3, "tooltip filled")

realprint(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
