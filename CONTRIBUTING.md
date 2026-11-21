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

1. The CurseForge project ID (1822226) is set in `TransmuteReminder.toc` as `## X-Curse-Project-ID`.
2. Add a `CF_API_KEY` secret under the repo's Settings > Secrets and variables > Actions.

Each release:

1. Add a section for the new version at the top of `CHANGELOG.md`.
2. Tag and push, for example `git tag v0.1.1 && git push origin v0.1.1`.

# i'm helping
