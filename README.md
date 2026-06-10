# Mythlings 🥚 Hatch, Battle, Breed!

Hatch mysterious eggs, raise and breed your Mythlings, then take them into
the arena to climb the ranks.

A Roblox monster-collecting, breeding and arena-battling game. Server
authoritative throughout: hatching odds, breeding rolls, battle outcomes and
all currency changes are resolved on the server, never the client.

## Repository layout

```
default.project.json   Rojo project (builds the place file)
src/server             Server bootstrap + Services (game logic)
src/client             Client bootstrap + Controllers + UI
src/shared/Config      Every tunable number in the game (frozen at load)
src/shared/Logic       Pure Luau game logic, fully unit tested
src/shared/Types       Shared Luau type definitions
src/shared/Util        Small shared helpers
Packages               Vendored third-party modules (see wally.toml)
tools/run-tests.luau   Lune test runner (TestEZ-compatible API)
docs                   Plan, backlog, security and status reports
```

## Toolchain

Pinned in `rokit.toml`: Rojo 7.4.4, Lune 0.8.9, StyLua 2.0.2, selene 0.31.0.

```sh
rojo build -o Mythlings.rbxl   # build the place file
lune run tools/run-tests.luau  # run all unit tests
selene src/                    # lint
stylua --check src/ tools/     # format check
```

## House rules

- UK English in all player-facing copy. No em dashes in code comments or UI.
- All prices, drop rates and stat curves live in `src/shared/Config`.
- One conventional commit per completed module, files staged explicitly.
- Paid random items always display their odds before purchase (Roblox policy).
