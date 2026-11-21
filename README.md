# TransmuteReminder

A WoW: Forever addon that shows a "Check transmutes" reminder when your alchemy transmute cooldown is ready. No countdown bars, no timers on screen.

## How it works

- When you cast a transmute, the addon reads the cooldown from the game and stores the time it ends.
- If the game gives no readable cooldown, it falls back to a set number of hours (default 20, change with `/tmr hours <n>`).
- When that time passes, a small frame appears. Click it to dismiss it. Drag it to move it.
- Cooldowns are only read outside combat, because Forever applies Midnight-style addon restrictions in combat.

## Commands

- `/tmr` shows the current status
- `/tmr test` shows the frame
- `/tmr reset` resets the frame position
- `/tmr clear` clears the stored cooldown
- `/tmr hours <n>` sets the fallback cooldown length
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
