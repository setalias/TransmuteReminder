-- luacheck config: WoW addon code (Lua 5.1). The WoW API is huge, so reads of
-- undefined globals are allowed; writes are limited to the names below.
std = "lua51"
max_line_length = false
exclude_files = { "tests/**", ".release/**" }
ignore = {
    "113",          -- accessing an undefined global (the WoW API)
    "212",          -- unused argument (event handlers)
    "211/ADDON_NAME",
}
globals = {
    "TransmuteReminderAccountDB",
    "SLASH_TRANSMUTEREMINDER1",
    "SlashCmdList",
    "TransmuteReminder_OnAddonCompartmentClick",
    "TransmuteReminder_OnAddonCompartmentEnter",
    "TransmuteReminder_OnAddonCompartmentLeave",
}
