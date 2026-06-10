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

---

## Module 0.2: Data layer

**Scope:** ProfileStore session-locked profiles, schema versioning with
reversible migrations, profile template covering currencies, mythlings,
eggs, inventory, housing, cosmetics, stats, pity counters, passes,
purchase ledger, battle pass and settings.

**Server/client split:** all server. `DataService` owns sessions and is the
single mutation point for currencies (MutateCurrency, with mandatory reason
string for auditing). Shared: `ProfileSchema` (template + migrations, pure)
and `PlayerConfig` (tunables).

**Tests:** ProfileSchema spec covers template freshness, required sections,
ordered migration application, no-op at current version, rejection of
newer-version profiles, missing-step failure, and reversible field backups.

**Smoke note:** join/leave/rejoin round-trip and BindToClose flush rely on
ProfileStore's session lock and internal BindToClose hook; verify in Studio
with the mock store (auto-selected when RunService:IsStudio()).

---

## Module 0.3: Remote framework

**Scope:** typed remote wrapper with registration, per-player token-bucket
rate limits and Guard argument validation middleware.

**Server/client split:** `server/Lib/Net` creates remotes from
`Config/RemoteConfig` (unknown names are a hard error), wraps handlers with
rate limit + validation + violation logging, and envelopes every
RemoteFunction response as { Ok, Data?, Error? }. `client/Lib/NetClient`
mirrors it. Pure logic extracted to `Logic/RateLimiter` (token bucket,
injectable clock) and `Logic/Guard` (validators).

**Remotes created:** ProfileSync (server to client only).

**Tests:** RateLimiter spec proves a 100-call spam burst is cut to the
configured burst capacity, refill over time, per-key independence and
backwards-clock robustness. Guard spec covers NaN/infinity rejection,
ranges, enums, oversized payload bombs and tuple validation.

---

## Module 1.1: EggConfig + odds UI

**Scope:** all seven egg tiers with locked prices, hatch timers and odds
tables; server-side purchase flow; pre-purchase odds panel.

**Server/client split:** `EggService.BuyEgg` (RemoteFunction) validates via
pure `EggShopLogic` then debits through DataService and appends the egg
record. Client `EggShopController` renders the shop and the odds panel
directly from `EggConfig`, so displayed odds cannot drift from rolled odds.
`DataService:Sync` pushes sanitised snapshots (`ProfileSanitiser` strips
MigrationBackups, PurchaseLedger and every hidden Potential value).

**Remotes:** BuyEgg (Function, burst 4, 30/min).

**Config:** EggConfig (tiers, pity threshold 50 to Epic+, instant hatch
0.4 Gems/min), RarityConfig, MythlingConfig (33 species), StatConfig.

**Tests:** ConfigValidation spec fails the build on odds not summing to
100, unknown rarities, tiers that cannot honour pity, spreads not summing
to 1, or rarities without species. EggShopLogic spec covers insufficient
Coins/Gems, unknown tier, storage full and exact cost reporting.
ProfileSanitiser spec proves Potential never replicates.

---

## Module 1.2: Hatch system

**Scope:** timestamp-based incubation with offline progression, pity
counters per tier, instant finish for Gems, hatch reveal UI.

**Server/client split:** `HatchService` owns StartIncubation, ClaimHatch
and InstantFinishHatch (all RemoteFunctions). Eggs store HatchesAt as a
unix timestamp so progress continues offline and across servers. Rolls use
`HatchLogic.hatch` with the server RNG; reveal payloads omit Potential.
Client `HatchController` shows slots, live countdowns (server clock via
GetServerTimeNow), instant finish cost preview from config, and the reveal.

**Remotes:** StartIncubation, ClaimHatch (burst 4, 30/min),
InstantFinishHatch (burst 3, 20/min).

**Tests:** 10,000-hatch simulation proves the pity guarantee (max Epic+
gap stays under the threshold of 50), an unlucky-roll test proves the
guarantee fires exactly at the threshold, distribution test holds odds
within 1 point over 100,000 rolls, element bias steers 50% of species
rolls, instant finish pricing matches ceil(minutes x 0.4) with a 1 Gem
floor, and MythlingFactory builds correct Hatchling records.

---

## Module 1.3: Mythling instancing

**Scope:** follower actors for owned Mythlings, stage-based scaling,
roster selection with ownership validation.

**Server/client split:** `MythlingSpawnService` spawns lightweight
part-based actors (placeholder art), scales them by StageScales, colours
by element/rarity, marks Shiny with neon, then hands network ownership to
the owner. `MythlingFollowController` (client) drives AlignPosition goals
each Heartbeat using shared formation maths, so the server spends nothing
on follow physics and replication is native. Roster changes go through
SetActiveMythlings with pure validation (`ActiveMythlingLogic`).

**Remotes:** SetActiveMythlings (Function, burst 4, 30/min).

**Tests:** roster validation (ownership, duplicates, cap, empty) and
formation offsets.

**Smoke note:** the 50-concurrent-actor 60fps benchmark needs Roblox
Studio; the design keeps per-actor cost to one ball part, two align
constraints and one billboard. Benchmark logged for the GATE 1 report.
