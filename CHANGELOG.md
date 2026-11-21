# Changelog

## 0.2.0

- Recipes that share a cooldown are tracked as one group, and separate timers are tracked separately. The Arcanite group, Iron to Gold and Mithril to Truesilver each get their own reminder.
- Casting any tracked recipe re-reads every group, so casting one transmute no longer overwrites another.
- When the game gives no cooldown, the last length seen is used before the fallback setting (now 36 hours).
- Someone else's profession (link or guild crafter) is never scanned.
- Transmutes are recognized by recipe ID as well as name, so detection works on non-English clients.
- Cooldowns save account-wide. Alts with a ready cooldown can trigger the reminder, and dismissing one alt cooldown no longer hides later ones.
- The reminder lists which cooldowns are ready.
- Checklist in the options to choose which cooldowns to remind about.
- Click actions: left-click opens the recipe, right-click snoozes, middle-click dismisses.
- Look options: text color, font, icon choice, display mode, background opacity, border, pulse or glow animation.
- Optional sound, repeat reminder, snooze length and chat message.
- Hide in combat, instances or groups. No cooldown reads happen in combat.
- Minimap button, AddOn Compartment entry, lock option, 10 second preview.
- Shorter chat messages. `/tmr scan` lists each recipe with its time left; `/tmr debug on` shows recipe IDs and raw values.
- New commands: `/tmr lock`, `/tmr unlock`, `/tmr minimap`, `/tmr alts`, `/tmr forget`.

## 0.1.0

- First release for WoW: Forever.
- Shows a "Check transmutes" frame when the transmute cooldown is ready.
- Reads the cooldown from the game after you cast a transmute, with a configurable fallback.
- Scans the Alchemy window to pick up cooldowns started before install.
- Options panel under Options > AddOns with status, actions, and command help.
- Customizable reminder text, up to 40 characters, set in the options panel or with `/tmr message`.
- Adjustable reminder size (0.5x to 3x) with a slider in the options panel or `/tmr scale`.
- Commands: `/tmr`, `/tmr options`, `/tmr test`, `/tmr scan`, `/tmr reset`, `/tmr clear`, `/tmr hours <n>`, `/tmr message <text>`, `/tmr scale <n>`, `/tmr debug`.
