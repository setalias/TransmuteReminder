# TransmuteReminder

A WoW: Forever addon that shows a "Check transmutes" reminder when your alchemy transmute cooldown is ready. No countdown bars, no timers on screen.

## How it works

- When you open your Alchemy window, the addon reads every recipe's cooldown. Recipes that share a cooldown become one entry. On Forever that means the Arcanite group (Arcanite, the elemental transmutes, Refined Scale of Onyxia and others) is one timer, while Iron to Gold and Mithril to Truesilver each have their own.
- When you cast a transmute or another tracked recipe, it re-reads them all, so every group stays correct.
- If the game gives no readable cooldown, it uses the length it saw last time, then a last-resort setting (default 36 hours, `/tmr hours <n>`).
- Viewing someone else's profession (a link or a guild crafter) is never scanned.
- When a cooldown ends, a small frame appears with which ones are ready. Left-click opens the recipe and dismisses it, right-click snoozes it, middle-click dismisses it. Drag it to move it.
- Cooldowns are saved account-wide, so the reminder also tells you which alts have something ready.
- Nothing is read or shown during combat.

## Features

- Custom reminder text (up to 40 characters), text color, font, and size
- Show text, icon, or both, with a choice of icons
- Background opacity, border, and a pulse or glow animation
- Optional sound, repeat reminder, snooze, and chat message
- Hide in combat, instances, or groups
- Alt reminders, with a checklist to choose which cooldowns to remind about (untick Iron to Gold if you only care about Arcanite)
- Minimap button and AddOn Compartment entry
- 10 second preview from the options panel

## Options

Options > AddOns > TransmuteReminder holds every setting above plus the command list. `/tmr options` opens it.

## Commands

- `/tmr` shows the current status
- `/tmr options` opens the options panel
- `/tmr test` previews the frame for 10 seconds
- `/tmr scan` scans the open Alchemy window and lists each recipe with its time left
- `/tmr whatsnext` shows the next cooldown to finish
- `/tmr reset` resets the frame position
- `/tmr clear` clears this character's stored cooldowns
- `/tmr lock` and `/tmr unlock` lock or unlock dragging
- `/tmr minimap` shows or hides the minimap button
- `/tmr alts` lists cooldowns on your other characters, `/tmr forget <name>` removes one
- `/tmr hours <n>` sets the last-resort cooldown length
- `/tmr scale <n>` sets the size from 0.5 to 3, `/tmr scale default` resets it
- `/tmr message <text>` sets the reminder text, `/tmr message default` restores it
- `/tmr debug` prints diagnostic info, `/tmr debug on` prints the spell ID of every cast

## Tests

`lua5.1 tests/run.lua` runs the addon against a mock of the WoW API. GitHub Actions runs it plus luacheck on every push.

## Install

Copy the `TransmuteReminder` folder into your WoW: Forever `Interface\AddOns` folder, then `/reload`.

## Releasing

Pushing a tag builds the addon with the BigWigs packager and uploads it to CurseForge.

1. Create the CurseForge project and add `## X-Curse-Project-ID: <id>` to `TransmuteReminder.toc`.
2. Add a `CF_API_KEY` secret in the repo's Settings, Secrets and variables, Actions.
3. Push a tag, for example `git tag v0.1.0 && git push origin v0.1.0`.

## Status

Early version. Cooldown reading on Forever is still being verified in game.
