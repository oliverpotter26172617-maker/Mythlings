# Mythlings Build Plan

This file is appended per module by THE LOOP. The design spec in the master
prompt is LOCKED and acknowledged: all rarities, odds, reward tables, economy
numbers, monetisation SKUs and guardrails are implemented as specified, with
every tunable living in `src/shared/Config` ModuleScripts. No redesigns.

---

## Module 0.1: Project scaffold

**Scope:** Rojo project, vendored dependencies, folder structure, lint and
format tooling, test runner, docs scaffold.

**Decisions forced by environment:**

- The Wally registry API (`api.wally.run`) is blocked by the network policy,
  so dependencies are vendored into `Packages/` from their upstream GitHub
  repositories: ProfileStore (MadStudioRoblox), GoodSignal (stravant),
  Trove (Sleitnick), Promise (evaera). `wally.toml` documents intended
  versions for later re-pinning.
- TestEZ cannot run here (no Roblox Studio on Linux), so `tools/run-tests.luau`
  is a TestEZ-API-compatible runner executed by Lune. Specs are written in
  TestEZ style (`describe`/`it`/`expect`) and remain runnable by real TestEZ
  in Studio.
- Shared logic modules use relative string requires (`require("./Foo")`),
  resolvable both by the Lune test loader and by the Roblox engine's
  require-by-string support.
- Selene cannot fetch the Roblox API dump (TLS interception), so a
  hand-maintained `roblox.yml` standard library lives in the repo root with
  `lua_versions: [luau]`.

**Files:** `default.project.json`, `selene.toml`, `roblox.yml`, `testez.yml`,
`stylua.toml`, `rokit.toml`, `wally.toml`, `.gitignore`, `Packages/*`,
`src/server/init.server.luau`, `src/client/init.client.luau`,
`src/shared/Util/TableUtil.luau` (+spec), `tools/run-tests.luau`, docs.

**Server/client split:** bootstrap scripts only; Services and Controllers
load via OnInit/OnStart lifecycle.

**Tests:** TableUtil spec exercises deepCopy, reconcile, count, deepFreeze
and proves the runner works end to end.
