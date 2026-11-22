# TransmuteReminder

A WoW: Forever addon that pops up a "Check transmutes" reminder when a transmute cooldown is ready. That's it.

## Features

- **Reminder only when ready.** A small frame appears when a cooldown ends and lists what is ready.
- **Knows which transmutes share a cooldown.** On Forever the Arcanite group (Arcanite and the elemental transmutes) is one timer, while Iron to Gold and Mithril to Truesilver each have their own. Each gets its own reminder.
- **Works for cooldowns started before install.** Open your Alchemy window once and the addon reads every cooldown from the game.
- **Other profession cooldowns too.** Any recipe on cooldown, such as Primal Mooncloth, is tracked when you open that profession.
- **Alts.** Cooldowns are saved account-wide, so any character, even one without Alchemy, reminds you when an alchemist alt has something ready.
- **Click to craft.** When a cooldown is ready the reminder turns green and shows what it will craft, with the result item's icon. Left-click crafts it. If your profession window is closed, the first click opens it to the recipe and the second click crafts, then the window closes again.
- **Pick your transmute.** Right-click to choose which recipe to craft for each cooldown, for example Arcanite or Earth to Water. Your choice is remembered. The menu also has Snooze, Dismiss and Open profession.
- **Reagent check.** If you're short on reagents the reminder turns red and lists what's missing, so you don't waste a click.
- **Shortcuts.** Shift-right-click snoozes, middle-click or Ctrl-click dismisses. Drag to move.
- **Customizable.** Reminder text (up to 40 characters), text color, font, size, icon, background opacity, border, and a pulse or glow animation.
- **Alerts.** Optional sound, repeat reminder, snooze length and chat message.
- **Stays out of the way.** Never reads or shows anything in combat. Optional hiding in instances or groups.
- **Choose what to track.** A checklist in the options to turn off any cooldown, for example Iron to Gold if you only care about Arcanite.
- Minimap button and AddOn Compartment entry.

## Getting started

1. Install the addon and log in.
2. Open your Alchemy window once on each alchemist. This records the current cooldowns.
3. Play as normal on any character. The reminder appears when a cooldown ends, whichever character you're on.

Settings are in Options > AddOns > TransmuteReminder, or type `/tmr options`.

## Commands

| Command | What it does |
| --- | --- |
| `/tmr` | Show every tracked cooldown, including your other characters |
| `/tmr options` | Open the options panel |
| `/tmr test` | Preview the reminder for 10 seconds |
| `/tmr scan` | Scan the open Alchemy window and list each transmute with its time left |
| `/tmr whatsnext` | Show the next cooldown to finish (your alts' if this character has none) |
| `/tmr alts` | List cooldowns on your other characters |
| `/tmr forget <name>` | Remove a character you no longer play |
| `/tmr clear` | Clear this character's stored cooldowns |
| `/tmr reset` | Reset the reminder position |
| `/tmr lock`, `/tmr unlock` | Lock or unlock dragging |
| `/tmr minimap` | Show or hide the minimap button |
| `/tmr message <text>` | Set the reminder text, or `/tmr message default` |
| `/tmr scale <n>` | Set the size from 0.5 to 3, or `/tmr scale default` |
| `/tmr hours <n>` | Set the manual cooldown, used when the game reports none |
| `/tmr debug [on\|off]` | Diagnostic info; `on` also prints recipe IDs and raw values |

## FAQ

**Do I need the addon installed when I cast the transmute?**
No. Open your Alchemy window and it picks up any cooldown already running.

**Why does Arcanite show as one reminder when I know several transmutes?**
On Forever many transmutes share one cooldown. The addon groups them so you get one reminder per timer, not one per recipe.

**Will I get reminders on characters that aren't alchemists?**
Yes. Cooldowns are shared across your account, so any character shows the reminder when an alchemist alt is ready. You can turn this off in the options.

**Why does the first click open my Alchemy window?**
WoW only lets addons craft while that profession's window is open. The first click opens it to the right recipe, the second crafts, and the addon closes the window afterwards. If the window is already open, one click crafts.

**Will viewing a guildmate's profession mess up my timers?**
No. Other players' professions are never read.

**What is the manual cooldown setting?**
A backup for the rare case the game doesn't report a cooldown. You shouldn't need to change it.

**Found a bug or have an idea?**
Open an issue on [GitHub](https://github.com/setalias/TransmuteReminder/issues).

## License

MIT. See [LICENSE](LICENSE).
