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

---

## Module 2.1: Feeding, XP and stages

**Scope:** food shop, XP curves, stage transitions with VFX moments.

**Server/client split:** `GrowthService` sells food (BuyFood), consumes it
(FeedMythling) and owns `GrantXp`, the single XP entry point that the
battle rewards engine will reuse. Stage-ups respawn follower actors at the
new scale and push a StageUpEffect event; `GrowthController` plays the
particle burst and toast. Pure logic: `StatCalc` (stat formula and Power
score) and `GrowthLogic` (thresholds, multi-stage grants, purchase
validation). Config: `GrowthConfig` (food catalogue, stage thresholds).

**Remotes:** BuyFood (5/40pm), FeedMythling (6/60pm), StageUpEffect
(server to client).

**Tests:** StatCalc spec proves computed stats equal the config formula
for every stage, ratio checks between stages, Potential band scaling and
clamping. GrowthLogic spec covers thresholds, single and multi stage-up
ordering, no regression, negative XP rejection and food purchase
validation.

---

## Module 2.2: Breeding

**Scope:** pair selection UI, inheritance rolls, cooldowns with Gem skip,
2% Shiny mutation, bred eggs with sealed contents.

**Server/client split:** `BreedingService` validates pairs (ownership,
distinctness, Adult+, rested, egg storage), rolls the offspring at breed
time and seals it in the egg record's Outcome field, which
ProfileSanitiser strips from every client sync, so the reveal stays a
surprise and Potential stays hidden. Parents get the 6 hour cooldown;
SkipBreedCooldown charges Gems per hour remaining. HatchService now
honours bred eggs (own incubation length, no pity interaction).

**Remotes:** BreedMythlings, SkipBreedCooldown (burst 3, 20/min each).

**Tests:** 100,000-roll simulation holds element weighting, Shiny rate
and same-rarity upgrade rate within 0.5 percentage points and keeps
Potential inside the average plus or minus 15 band with the correct mean;
mixed-parent rarity splits 50/50 with no upgrades; Mythic cap; species
element fallback; full validateBreed and skipCost coverage.

---

## Module 3.1: Battle core

**Scope:** pure-Luau 3v3 simulation with cooldown abilities, the locked
damage formula, element wheel and manual/auto cast policies.

**Design:** `BattleSim` is a step-able simulation (0.1s ticks) with rng
injected. Auto units cast their strongest ready ability; manual (player)
units auto-fire only the basic Strike and cast abilities when queued via
queueCast, giving the auto-battler feel with manual triggers. Targeting
focuses the weakest enemy. After 150s an enrage ramp (+3% damage per
second) prevents stalemates; at the 240s cap the higher HP fraction wins.
Wheel: Flame>Terra>Storm>Tide>Flame, Shadow<->Radiant. Abilities are pure
data in AbilityConfig (Strike plus per-element Bolt/Nova/Frenzy unlocked
by stage).

**Tuning:** HpMultiplier 110 lands the duration distribution at p10 69s,
median 125s, p90 198s with 1.3% timeouts over random matchups.

**Tests:** element wheel coverage (every element exactly one advantage),
exact damage formula match, minimum 1 damage, manual cast gating and
queueing, cast rejection for unknown units/abilities, 1,000 random
battles with zero errors and median duration inside 90 to 180 seconds,
and timeout resolution by HP fraction.

---

## Module 3.2: Matchmaking + arenas

**Scope:** trophy-bracket queues with the Power-gap cap, instanced arena
platforms, real-time match hosting, manual ability casts, battle HUD.

**Server/client split:** `BattleService` owns Ranked and Casual queues,
pairs players via pure `MatchmakingLogic` (same bracket, Power ratio at
most 1.35, longest wait first), builds teams from follower rosters via
pure `TeamLogic`, hosts matches on a Heartbeat stepper, relays event
batches every 0.25s, teleports players to grid-instanced platforms 500
studs up and forfeits leavers. MatchEnded signal hands results to the
rewards engine (3.3). Client `BattleController` renders queue buttons,
HP bars, per-unit ability buttons (CastAbility) and the end screen.

**Remotes:** JoinQueue/LeaveQueue (3/20pm), CastAbility (10/120pm),
BattleStart/BattleEvents/BattleEnd (server to client).

**Tests:** bracket mapping and contiguity, Power-gap blocking (the
anti-stomp guarantee), self-match prevention, greedy pairing with wait
priority, leftovers, and TeamLogic team building and refusals.

**Smoke note:** two-client end-to-end ranked battle needs Studio
multi-client testing; logged for the GATE 1 report.

---

## Module 3.3: Rewards engine

**Scope:** Section 3.6 payout table, exactly, including streak bonus and
loss protection.

**Design:** `RewardsLogic.compute` is pure: coins (bracket multiplier and
+10%/win streak bonus capped at +50% for ranked wins), trophies (+25..35
win, -10..20 loss with a floor of 0), XP fractions (full/40%), Battle
Tokens per row, streak bookkeeping and loss protection (0 trophy cost on
losses after 3 straight). Draws pay the loss consolation with frozen
streaks. `RewardsService` listens to MatchEnded, applies the payout
through the audited currency gateway, grants team XP via
GrowthService:GrantXp and pushes an itemised BattleRewards event.

**Tests:** one describe block per table row plus streak cap, trophy
floor, loss protection activation and draw handling (15 assertions).
