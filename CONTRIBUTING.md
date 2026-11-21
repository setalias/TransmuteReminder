# Contributing

Notes for working on TransmuteReminder. Bug reports and pull requests are welcome.

## Layout

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
