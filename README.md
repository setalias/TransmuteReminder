# TransmuteReminder

A WoW: Forever addon that pops up a small "Check transmutes" reminder when an alchemy transmute cooldown is ready. No countdown bars and no timers on screen: nothing shows until something is ready.

## Features

- **Reminder only when ready.** A small frame appears when a cooldown ends and lists what is ready.
- **Knows which transmutes share a cooldown.** On Forever the Arcanite group (Arcanite and the elemental transmutes) is one timer, while Iron to Gold and Mithril to Truesilver each have their own. Each gets its own reminder.
- **Works for cooldowns started before install.** Open your Alchemy window once and the addon reads every cooldown from the game.
- **Other profession cooldowns too.** Any recipe on cooldown, such as Primal Mooncloth, is tracked when you open that profession.
- **Alts.** Cooldowns are saved account-wide, so the reminder tells you when an alt has something ready.
- **Click actions.** Left-click opens the recipe in your profession window, right-click snoozes, middle-click dismisses. Drag to move.
- **Customizable.** Reminder text (up to 40 characters), text color, font, size, icon, background opacity, border, and a pulse or glow animation.
- **Alerts.** Optional sound, repeat reminder, snooze length and chat message.
- **Stays out of the way.** Never reads or shows anything in combat. Optional hiding in instances or groups.
- **Choose what to track.** A checklist in the options to turn off any cooldown, for example Iron to Gold if you only care about Arcanite.
- Minimap button and AddOn Compartment entry.

## Getting started

1. Install the addon and log in.
2. Open your Alchemy window once on each alchemist. This records the current cooldowns.
3. That's it. The reminder appears when a cooldown ends.

Settings are in Options > AddOns > TransmuteReminder, or type `/tmr options`.

## Commands

| Command | What it does |
| --- | --- |
| `/tmr` | Show the status of every tracked cooldown |
| `/tmr options` | Open the options panel |
| `/tmr test` | Preview the reminder for 10 seconds |
| `/tmr scan` | Scan the open Alchemy window and list each transmute with its time left |
| `/tmr whatsnext` | Show the next cooldown to finish |
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

## How it works

- Opening a profession window reads every learned recipe's cooldown. Recipes whose cooldowns match are grouped into one entry.
- Casting a tracked recipe re-reads all of them, so casting one transmute never overwrites another.
- If the game gives no readable cooldown, the addon uses the length it saw last time, then the manual cooldown setting (default 36 hours).
- Someone else's profession (a link or a guild crafter) is never scanned.

## Development

```
TransmuteReminder.toc   addon metadata and load order
Core.lua                cooldown tracking, grouping, events, slash commands
Popup.lua               reminder window, tooltip, minimap button
Options.lua             settings panel
tests/                  WoW API mock and test suite
```

- **Run the tests:** `lua5.1 tests/run.lua` from the repo root. It loads the addon against a mock of the WoW API.
- **Lint:** `luacheck Core.lua Popup.lua Options.lua` (config in `.luacheckrc`).
- **CI:** GitHub Actions runs both on every push and pull request.
- **Local testing in game:** copy the TOC and the three `.lua` files into `World of Warcraft\_forever_\Interface\AddOns\TransmuteReminder\`, then `/reload`.

## Releasing

Pushing a version tag runs the tests, then builds the addon with the BigWigs packager and uploads it to CurseForge. `@project-version@` in the TOC is replaced with the tag.

One-time setup:

1. Create the CurseForge project and add `## X-Curse-Project-ID: <id>` to `TransmuteReminder.toc`.
2. Add a `CF_API_KEY` secret under the repo's Settings > Secrets and variables > Actions.

Each release:

1. Move the "Unreleased" notes in `CHANGELOG.md` under the new version.
2. `git tag v0.1.0 && git push origin v0.1.0`
