# Changelog

## Unreleased

- Click to craft: left-click the reminder to craft. If the profession window is closed, the first click opens it to the recipe and the second crafts, then the window closes again.
- Right-click menu to choose which recipe each cooldown crafts (for example Arcanite or Earth to Water), with result item icons. Your choice is remembered per character.
- The reminder turns green and shows the result item when a click will craft, or red with the missing reagents.
- Snooze moved to the right-click menu and Shift-right-click. Middle-click or Ctrl-click dismisses.
- New option to turn click-to-craft off and keep the old open-the-recipe behavior.

## 0.1.0

First release for WoW: Forever.

- Shows a reminder when a transmute or other profession cooldown is ready. No countdown bars.
- Groups recipes that share a cooldown, so the Arcanite group, Iron to Gold and Mithril to Truesilver each get their own reminder.
- Reads cooldowns from the Alchemy window, including ones started before install, and re-reads them after each cast.
- Uses the last cooldown length seen when the game reports none, then a manual setting (default 36 hours).
- Never scans someone else's profession (link or guild crafter).
- Saves cooldowns account-wide, so any character, including ones without Alchemy, reminds you when an alt's cooldown is ready.
- Left-click opens the recipe, right-click snoozes, middle-click dismisses.
- Options panel: reminder text, color, font, size, icon, background, border, animation, sound, repeat, snooze, chat message, hiding in combat, instances or groups, and a checklist of cooldowns to track.
- Minimap button and AddOn Compartment entry.
- `/tmr whatsnext` shows the next cooldown to finish, falling back to your alts on characters with none.
- Commands: `/tmr`, `options`, `test`, `scan`, `whatsnext`, `alts`, `forget`, `clear`, `reset`, `lock`, `unlock`, `minimap`, `message`, `scale`, `hours`, `debug`.
