# Changelog

## 0.2.0

- Split the addon into Core, Popup, and Options files.
- Cooldowns now save account-wide. Alts with a ready cooldown can trigger the reminder.
- Tracks other cooldown recipes besides transmutes, with a checklist to choose what to remind about.
- Click actions: left-click opens the recipe, right-click snoozes, middle-click dismisses.
- New look options: text color, font, icon choice, display mode, background opacity, border, pulse or glow animation.
- Optional sound, repeat reminder, snooze length, and chat message.
- Hide in combat, instances, or groups. No cooldown reads happen in combat.
- Minimap button, AddOn Compartment entry, lock option, 10 second preview.
- New commands: `/tmr lock`, `/tmr unlock`, `/tmr minimap`, `/tmr alts`, `/tmr forget`.
- Settings from 0.1.0 are migrated automatically.
- `/tmr scan` lists just the recipe names. Turn on `/tmr debug on` to see recipe IDs and cooldown values.

## 0.1.0

- First release for WoW: Forever.
- Shows a "Check transmutes" frame when the transmute cooldown is ready.
- Reads the cooldown from the game after you cast a transmute, with a configurable fallback.
- Scans the Alchemy window to pick up cooldowns started before install.
- Options panel under Options > AddOns with status, actions, and command help.
- Customizable reminder text, up to 40 characters, set in the options panel or with `/tmr message`.
- Adjustable reminder size (0.5x to 3x) with a slider in the options panel or `/tmr scale`.
- Commands: `/tmr`, `/tmr options`, `/tmr test`, `/tmr scan`, `/tmr reset`, `/tmr clear`, `/tmr hours <n>`, `/tmr message <text>`, `/tmr scale <n>`, `/tmr debug`.
