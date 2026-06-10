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

---

## Module 3.4: Boss raids

**Scope:** weekly rotating boss, co-op lobby, raid chest loot.

**Server/client split:** `RaidService` runs a lobby (launches at 4
players or after 15s with at least 1), merges every member's team into
one side of the sim against the weekly boss (pure `RaidLogic` derives the
boss from unix week, no stored state), steps raids on Heartbeat, reuses
the BattleStart/Events/End wire format and the CastAbility remote, pays
the Section 3.6 raid row via RewardsService and rolls the chest per
player on a clear. Egg drops that cannot fit storage fall back to Coins.
Leaving a live raid forfeits only the leaver's rewards.

**Tests:** rotation determinism and full cycle coverage, chest drop
distribution within 0.5 points of configured weights over 50,000 chests,
four-player parties clearing the boss in at least 20 of 30 seeded sims,
and boss ability ids resolving in AbilityConfig.

**Smoke note:** live 4-player co-op run needs Studio multi-client
testing; logged for the GATE 1 checklist.

---

## Module 4.1: Products + passes

**Scope:** all Section 3.9 SKUs: four Gem packs, Battle Pass premium
product, and the VIP / Hatch Speed / Triple Hatch / Auto-Hatch / Extra
Storage passes, with idempotent receipts.

**Design:** `MonetisationLogic.applyReceiptOnce` records the ReceiptId in
the profile ledger before granting, so replayed receipts grant exactly
once even across a mid-grant crash. `MonetisationService` owns
ProcessReceipt, refreshes the pass cache on join and on purchase
(ownership only ever turns on; API failures never revoke), pays the VIP
daily Gem stipend once per UTC day and runs the Auto-Hatch loop. Pass
benefits wired: VIP +25% on Coin sources (battle rewards), Hatch Speed
divides incubation time, Triple Hatch and Extra Storage were already
config-driven, Auto-Hatch claims finished eggs and cycles Basic eggs.
Asset ids ship as 0 ("coming soon" client-side) until the dashboard ids
are pasted into MonetisationConfig.

**Tests:** receipt idempotency (replay, independence, crash-during-grant),
VIP coin multiplier, hatch time division, daily stipend gating.

---

## Module 4.2: Premium Nursery

**Scope:** weekly rotating direct-purchase Mythlings (2 Epics + 1
Legendary per week) for Gems, with the locked fairness constraints.

**Design:** offers derive from the unix week index in pure NurseryLogic,
so the rotation needs no stored state and client/server always agree.
Purchases use the same MythlingFactory and the same 1..100 Potential roll
as hatching: there is no purchasable stat advantage, only access. The
spec's three guardrails hold by construction and by test: identical stat
ceiling, Power brackets apply (Nursery Mythlings are ordinary records),
and free-path availability from the Mythic egg.

**Remotes:** BuyNurseryMythling (burst 3, 20/min).

**Tests:** the build fails if any Nursery species is missing from the
Mythic egg's free pool or if a record carries its own stat fields;
rotation determinism, week-over-week change, Epic/Legendary-only
offers, and purchase validation (bad index, short Gems, full storage).

---

## Module 4.3: Battle Pass

**Scope:** 50 tiers, free and premium tracks, 8-week seasons, claim UI.

**Design:** season index derives from a configured epoch (no stored
season state); `ensureSeason` rolls profiles over exactly once and wipes
prior progress. Pass XP flows through RewardsService for ranked, casual
and raid outcomes, so every battle feeds the pass from one place.
Claims validate tier reach, premium ownership and double-claim through
pure `BattlePassLogic`; rewards grant via the shared Grants lib (egg
drops fall back to Coins when storage is full). Premium unlocks via the
799 Robux product receipt (4.1). Progress and claims live in the
profile, so they persist across sessions by construction.

**Remotes:** ClaimBattlePassTier (burst 6, 60/min).

**Tests:** season boundary maths, single rollover semantics, tier
mapping with the final-tier cap, XP accumulation, claim-once, unreached
and premium gating, independent track claims, nonsense tier rejection,
and both reward tracks fully populated for all 50 tiers.

---

## Module 5.1: Plots

**Scope:** plot allocation, four size tiers, themes (Cloud Isle is VIP
only), grid-snap furniture with bounds, ownership, rotation and collision
validation, full persistence.

**Server/client split:** `HousingService` allocates neighbourhood slots,
renders plot floors and furniture from the profile, and owns all seven
housing remotes. Placement is validated by pure `HousingLogic.canPlace`
(grid integers, quarter-turn rotations, footprint fully inside the tier
bounds, no overlap, per-tier furniture cap). Client UI scans for the
first legal spot for convenience but the server re-validates everything.
Removing furniture returns it to inventory.

**Tests:** the out-of-plot exploit placement is rejected at every edge
including extreme coordinates, the same spot legalises after an upgrade,
off-grid and bad rotations refuse, overlap versus adjacency, rotated
footprint swapping, tier caps, upgrade fund/top-tier validation and
theme purchase rules (VIP exclusivity included).

---

## Module 5.2: Idle income + visiting

**Scope:** housed Mythlings generate Coins, doubled while recently fed;
friend-visit daily bonus for both players.

**Design:** pure `IncomeLogic`: income accrues per housed (active roster)
Mythling at config rates by rarity, doubled within the 24h fed window
(never-fed Mythlings never qualify), capped at 12 hours unclaimed.
`claim` stamps the window so the same period can never pay twice; the
first ever claim starts the clock without paying. Visits pay both
players once per distinct friend per UTC day, visitor-capped at 5/day,
validated against Roblox friendship server-side. VIP multiplies the
income payout. Feeding now stamps LastFedAt.

**Remotes:** ClaimPlotIncome, VisitFriendPlot (burst 3, 20/min each).

**Tests:** exact config-rate accrual, fed doubling, the 12 hour cap,
unowned Mythlings paying nothing, double-claim paying zero, first-claim
clock start, per-friend-per-day visits with the daily cap and reset.

---

## Module 5.3: Cosmetics + Arena Shop

**Scope:** avatar and Mythling cosmetic layers, equip system, the
rotating Battle Token Arena Shop.

**Design:** stat neutrality is structural: CosmeticDef has no stat
fields and a build-failing test rejects any key outside the whitelist
(DisplayName, Layer, Slot, PriceGems, Colour). Battle code never reads
cosmetics; a test proves teams and full same-seed battles are identical
dressed or not. Equipping validates layer/slot/ownership via pure
CosmeticsLogic. Earned-only cosmetics (raid, pass, arena shop) carry no
Gem price and refuse direct purchase. The Arena Shop rotates three
weekly slots over a pool of cosmetics, rare food and eggs, all spending
Battle Tokens. Auras, dyes (Shiny only) and hats render on follower
actors as light/colour/part accents.

**Remotes:** BuyCosmetic, EquipAvatarCosmetic, EquipMythlingCosmetic,
BuyArenaShopItem.

**Tests:** whitelist build gate, team/battle identity with cosmetics,
buy and equip validation across layers and slots, shop rotation and
pool reference integrity.

---

## Module 6.1: Quests, calendar, gifting, group bonus

**Scope:** 3 daily and 5 weekly quests, 7-day escalating login calendar
(day 7 guaranteed Epic egg), friend gifting (1 Basic egg per friend per
day) and the +10% group membership Coin bonus.

**Design:** quest sets roll deterministically from the day/week stamp
(no stored RNG state); progress flows through QuestService:ReportProgress
from battles, hatches, feeds, breeds, income claims and gifts; claims
validate and grant via the shared Grants lib. The calendar auto-claims on
the first join of each UTC day; day 7 grants a sealed Epic-outcome egg.
The group bonus folds into the single coinMultiplier alongside VIP and
caches on join (GroupId ships as 0 until the real group exists). All
quest state persists in the profile.

**Remotes:** ClaimQuest, GiftEgg, CalendarReward (server to client).

**Tests:** deterministic rolling and reroll-on-stamp-change, metric
progress with target caps, claim-once and unfinished/unknown refusals,
no progress on claimed quests, calendar once-per-day cycling through all
seven days with day 7 as the Epic egg, and per-friend-per-day gifting
with daily reset.

---

## Module 6.2: Onboarding

**Scope:** guided new-player flow ending in the free Rare egg hatch and
a first casual battle, with funnel analytics at every step.

**Design:** the free Rare egg (sealed Rare outcome, 2 minute hatch)
lands the moment a fresh profile loads. Steps complete from the same
metric pipeline quests use (hatch, feed, set team, battle), so there is
one reporting path; completion grants 500 Coins towards the session-one
earnings target. Every step transition logs to the Roblox onboarding
funnel via the pcall-guarded Analytics wrapper, so analytics can never
break gameplay. A client banner shows the current step until the flow
ends.

**Tests:** flow start semantics, ordered walk to completion, immunity
to out-of-order and unknown metrics, completed/unstarted no-ops, and
config sanity (every actionable step has a completion metric).

---

## Module 6.3: Analytics + telemetry

**Scope:** economy dashboard coverage and gameplay telemetry.

**Design:** DataService:MutateCurrency is the single gateway for every
currency change, so one Analytics.economy call there covers every Gem
and Coin source and sink in the game, keyed by the mandatory audit
reason and bucketed into IAP/Shop/Gameplay transaction types.
Onboarding funnel steps were wired in 6.2; battle duration telemetry
logs per match for pacing dashboards. All analytics calls are
pcall-guarded and can never break gameplay.

---

## Module 6.5: Performance pass

**Scope:** network, render and UI scaling work within this environment;
device profiling deferred to the Studio checklist.

**Done:**
- ProfileSync coalescing: bursts of profile mutations now cost one
  snapshot push per 0.2s per player instead of one per mutation.
- Mobile UI scaling: every UIKit ScreenGui carries a viewport-driven
  UIScale (down to 75% on small phones), updating on viewport changes.
- Render flags on all dynamically created world parts (follower bodies,
  furniture, arena floors): CastShadow off, CanTouch/CanQuery off where
  collision is unused.
- Already in place from earlier modules: StreamingEnabled, single-part
  actors with client-owned physics, batched battle events (4/s), stage
  scale handled by one part resize (LOD-equivalent for placeholder art),
  billboard MaxDistance 60.

**Deferred to Studio (GATE 2 checklist):** device FPS/memory profile,
StreamingEnabled radii tuning against real map assets.

---

## Module 6.6: Launch checklist

**Scope:** launch copy, policy compliance notes, asset id wiring steps,
soft-launch flag and live kill switches.

**Design:** `LaunchConfig` holds operational defaults; `LiveConfig`
polls a DataStore document every 60s so flags flip across the fleet
without a redeploy. Kill switches wired: PurchasesEnabled holds receipts
unprocessed (Roblox redelivers, no paid purchase is dropped),
BreedingEnabled, MatchmakingEnabled and RaidsEnabled refuse politely at
their remotes. docs/LAUNCH-CHECKLIST.md carries the listing copy,
odds-policy description, age questionnaire notes, dashboard wiring and
the manual Studio verification list.

---

## Post-gate polish sprint

### P1: Hub world + currency HUD
WorldService builds a spawn plaza with a SpawnLocation, landmark stalls
for the shop/hatchery/den/arena and a path towards the neighbourhood,
plus ambient lighting; without it players spawned into the void.
HudController shows Coins, Gems, Battle Tokens and Trophies live from
profile snapshots.

### P2: Collection UI
CollectionController lists every owned Mythling (rarest first, Shiny
flagged), lets players pick up to three as followers/arena team via
SetActiveMythlings, and completes the onboarding SetTeam step. This was
the missing link in the core loop UI.

### P3: Seasonal trophy reset (spec 3.10)
SeasonLogic applies a once-per-season rollover aligned to the Battle
Pass season: placement Gems by final bracket and a 50% trophy soft
reset, with a client toast. Brand new profiles stamp the season without
a reward. Unit tested (placement, idempotency, bracket coverage).

### P4: Continuous integration
GitHub Actions workflow runs selene, StyLua, the full Lune test suite
and a rojo build on every push and pull request with the pinned
toolchain versions.

### P5: Critter models, HUD fix, settings
Follower actors gained eyes and per-element accents (crest, fin, rocky
brow or halo mote) at five cheap parts max, replacing plain spheres.
Battle HUD HP bars now read authoritative MaxHp from the start payload.
Settings (Music, Sfx, LowQuality) persist via a whitelisted
UpdateSetting remote with a client panel; the SFX toggle gates the
shared click sound.
