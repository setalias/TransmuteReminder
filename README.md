# TransmuteReminder

A WoW: Forever addon that shows a "Check transmutes" reminder when your alchemy transmute cooldown is ready. No countdown bars, no timers on screen.

## How it works

- When you cast a transmute, the addon reads the cooldown from the game and stores the time it ends.
- If the game gives no readable cooldown, it falls back to a set number of hours (default 20, change with `/tmr hours <n>`).
- When you open your Alchemy window, it scans the transmute recipes and picks up cooldowns that started before the addon was installed. `/tmr scan` runs the scan by hand and prints what the game reports for each transmute.
- When that time passes, a small frame appears. Click it to dismiss it. Drag it to move it.
- Cooldowns are only read outside combat, because Forever applies Midnight-style addon restrictions in combat.

## Options

Options > AddOns > TransmuteReminder shows the commands, a status line, buttons for the common actions, the fallback cooldown setting, the reminder text, and the reminder size. `/tmr options` opens it.

## Commands

- `/tmr` shows the current status
- `/tmr options` opens the options panel
- `/tmr test` shows the frame
- `/tmr scan` scans the open Alchemy window and prints each transmute's cooldown
- `/tmr reset` resets the frame position
- `/tmr clear` clears the stored cooldown
- `/tmr hours <n>` sets the fallback cooldown length
- `/tmr scale <n>` sets the reminder size from 0.5 to 3 (1 is normal), `/tmr scale default` resets it
- `/tmr message <text>` sets the reminder text (up to 40 characters), `/tmr message default` restores "Check transmutes"
- `/tmr debug` prints diagnostic info, `/tmr debug on` prints the spell ID of every cast

## Install

Copy the `TransmuteReminder` folder into your WoW: Forever `Interface\AddOns` folder, then `/reload`.

## Releasing

Pushing a tag builds the addon with the BigWigs packager and uploads it to CurseForge.

1. Create the CurseForge project and add `## X-Curse-Project-ID: <id>` to `TransmuteReminder.toc`.
2. Add a `CF_API_KEY` secret in the repo's Settings, Secrets and variables, Actions.
3. Push a tag, for example `git tag v0.1.0 && git push origin v0.1.0`.

## Status

Early version. Cooldown reading on Forever is still being verified in game.
