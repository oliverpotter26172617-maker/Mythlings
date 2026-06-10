# Mythlings Security Notes

Red-team log per THE LOOP step 4. Every RemoteEvent/RemoteFunction gets an
entry: what the client can send, how it is validated, and its rate limit.

Standing rules enforced across all modules:

- The server never trusts a client-supplied identity. The acting player is
  always taken from the remote invocation, never from arguments.
- All currency mutations, random rolls (hatching, breeding, loot) and battle
  resolution happen on the server.
- Every remote has a per-player rate limit and strict argument validation;
  violations are logged and excess traffic is dropped.
- Config values are deep-frozen at load so no script can mutate tunables at
  runtime.

(Entries are appended per module from 0.3 onward.)

## Module 0.3: Remote framework

- Remotes can only exist if declared in `RemoteConfig` with an explicit
  burst and per-minute rate. `Net.HandleEvent`/`Net.HandleFunction` reject
  unregistered names at boot, so a rogue remote cannot ship unnoticed.
- Spam: token bucket per `remote:userId`. Throttled calls are dropped
  (Events) or answered with a polite refusal (Functions), and counted via
  `Net.GetViolationCounts()` for the hardening audit in 6.4.
- Garbage payloads: Guard validators reject wrong types, NaN/infinity,
  out-of-range numbers, oversized strings/tables/arrays and extra arguments
  before any handler runs.
- Spoofed identity: the acting player is the first parameter from
  OnServerEvent/OnServerInvoke. Handlers never accept a player or UserId
  from the argument list as the actor.
- Handler crashes are caught; RemoteFunctions return a generic error so
  internal messages never leak to clients. Intentional refusals use
  Net.Refuse, which is the only path for player-visible reasons.
- ProfileSync: server to client push only; the server attaches no
  OnServerEvent listener, so client sends on it are inert.

## Module 1.1: Egg purchases

- `BuyEgg(tierId)`: tier must be a string of 32 chars max and exist in
  EggConfig. Cost comes from config only; the client cannot name a price.
  Insufficient funds and full storage refuse before any mutation. No yields
  between validation and debit, so double-spend racing is impossible.
- Rate limit: burst 4, 30/min. Spam is throttled and counted.
- Hidden Potential and server ledgers never reach the client: ProfileSync
  payloads pass through ProfileSanitiser (unit tested).

## Module 1.2: Hatching

- All three hatch remotes take only an eggId string (16 chars max). Eggs
  are looked up in the caller's own profile, so hatching another player's
  egg is structurally impossible.
- Timer cheating: HatchesAt is set server-side from config; ClaimHatch
  compares against os.time() on the server. The client countdown is
  cosmetic.
- InstantFinishHatch computes the Gem cost server-side from time remaining
  and checks Mythling storage before charging, so Gems cannot be burned on
  a hatch that would then refuse.
- Incubation slots and storage limits are enforced from config plus the
  server-side pass cache, never from client state.
- Pity counters live in the profile and are only mutated by resolveHatch.

## Module 1.3: Followers

- `SetActiveMythlings(ids)`: array capped at MaxFollowers by both the
  Guard schema and roster validation; ids must exist in the caller's own
  collection; duplicates rejected. Other players' ids cannot appear since
  lookups are within the caller's profile.
- Actors get network ownership for follow physics only. They carry no
  authority over game state; position is cosmetic outside arenas (arena
  positions are server-checked in 6.4).

## Module 2.1: Growth

- BuyFood quantity is Guard-clamped to 1..MaxFoodPerPurchase as an integer;
  cost is config price times quantity computed server-side.
- FeedMythling requires owning both the Mythling and at least one of the
  food item; inventory decrements before XP grant, no yields between.
- XP only enters records via GrowthService:GrantXp, so stage state cannot
  desync from XP.

## Module 2.2: Breeding

- BreedMythlings takes two ids resolved inside the caller's own profile;
  no path exists to reference another player's Mythlings.
- The offspring is rolled server-side at breed time and stored in
  egg.Outcome, which ProfileSanitiser removes from ProfileSync payloads
  (unit tested), so clients cannot scout or reroll the result.
- Cooldowns are unix timestamps checked server-side; SkipBreedCooldown
  recomputes the price from time remaining and refuses on zero remaining,
  so free skips and price spoofing are impossible.

## Module 3.2: Arena

- JoinQueue mode is whitelisted via Guard.oneOf; team and Power are
  computed server-side from the profile. Trophies come from the profile,
  never the client.
- CastAbility: the unit must belong to the caller in their live match
  (UnitOwners map); the sim then validates ability ownership, readiness
  and that the unit is alive. Spamming is rate limited at 10 burst.
- Battle event payloads carry only public state (ids, HP, damage); hidden
  Potential and exact stats never replicate.
- Disconnecting mid-match forfeits; the opponent wins and the match
  record notes the forfeiter, so quit-dodging cannot dodge trophy loss.

## Module 3.4: Raids

- JoinRaid takes no arguments; the team, boss and party are entirely
  server-derived. Chest rolls happen server-side on clear only.
- CastAbility in raids goes through the same ownership check as arena
  matches (UnitOwners), so players cannot drive each other's units or
  the boss.
- Chest egg drops respect storage limits with a Coins fallback, so the
  storage cap cannot be bypassed via raids.

## Module 4.1: Monetisation

- ProcessReceipt grants through applyReceiptOnce: the ledger write
  happens before the grant, so duplicate receipt delivery (a Roblox
  guarantee you must handle) can never double-grant.
- Pass benefits are read from the server-side profile cache only; the
  client cannot claim a pass it does not own, and API failures never
  revoke a cached pass mid-session.
- Unknown ProductIds return NotProcessedYet and are logged.

## Module 4.2: Premium Nursery

- The client sends only a slot index (1..8 by Guard); price and species
  come from the server-derived weekly offer list, so price and species
  spoofing are impossible.
- Potential is rolled server-side with the hatch range; no purchase can
  exceed the free-path stat ceiling (unit tested as a build gate).

## Module 4.3: Battle Pass

- Claims send only (tier, track); both are Guard-whitelisted and
  validated against server-side XP and ownership. Double claims are
  rejected from profile state.
- Premium ownership is set exclusively by the receipt processor.

## Module 5.1: Housing

- PlaceFurniture takes Guard-clamped integers and whitelisted rotations;
  HousingLogic then enforces bounds, grid, overlap and tier caps. The
  out-of-bounds exploit is covered by a unit test.
- All furniture state lives in the owner's profile; guids are resolved
  in the caller's own Housing table, so editing someone else's plot is
  structurally impossible.
- Theme equipping checks ownership server-side; the VIP exclusive theme
  is only equippable while the VIP pass is cached true.

## Module 5.2: Income + visiting

- Income windows are server timestamps; claiming twice pays zero (unit
  tested). Rates come from config and the player's own roster.
- Visit bonuses require the target to be a Roblox friend present in the
  server; the once-per-pair-per-day ledger lives in the visitor profile
  so bonus farming with alt hopping is capped at 5 per day.

## Module 5.3: Cosmetics

- Equip requests validate layer, slot and ownership server-side; battle
  code never reads cosmetic state, so no cosmetic can influence combat
  (enforced by a same-seed battle identity test).
- Arena Shop purchases resolve the entry from the server-derived weekly
  rotation; only a slot index crosses the wire.

## Module 6.1: Quests and gifting

- Quest claims validate scope, activity, completion and double-claim
  server-side; quest selection is deterministic so clients cannot
  influence rolls.
- GiftEgg requires Roblox friendship, presence in the server and the
  per-friend daily cap recorded on the giver before granting. The
  receiver's storage limits apply through Grants (Coins fallback).
- The group bonus flag is set only from a server-side IsInGroup check.

## Module 6.4: Hardening audit

Full remote inventory at audit time. Every remote is registered in
RemoteConfig with a rate limit and validated arguments; the acting player
is always the engine-provided caller.

| Remote | Kind | Client args (validated) | Server checks |
|--------|------|--------------------------|---------------|
| BuyEgg | Function | tier string<=32 | tier exists, funds, egg storage |
| StartIncubation | Function | eggId<=16 | owned, not incubating, slot free |
| ClaimHatch | Function | eggId<=16 | owned, timer elapsed (server clock) |
| InstantFinishHatch | Function | eggId<=16 | owned, storage, server-priced Gems |
| SetActiveMythlings | Function | array<=3 of id<=16 | owned, unique, cap |
| BuyFood | Function | id<=32, int 1..20 | item exists, funds |
| FeedMythling | Function | ids<=16/32 | both owned, inventory>=1 |
| BreedMythlings | Function | two ids<=16 | owned, distinct, Adult+, rested, storage |
| SkipBreedCooldown | Function | id<=16 | owned, server-priced Gems, time remains |
| JoinQueue | Function | enum Ranked/Casual | team valid, not in match |
| LeaveQueue | Function | none | none needed |
| CastAbility | Function | unitId<=48, ability<=32 | unit owned in live match, sim validates readiness/aliveness |
| JoinRaid / LeaveRaid | Function | none | team valid, not already raiding |
| BuyNurseryMythling | Function | int 1..8 | weekly offer, Gems, storage, hatch-equal Potential roll |
| ClaimBattlePassTier | Function | int 1..50, enum track | reached, owned premium, claim-once |
| BuyPlotUpgrade | Function | none | next tier exists, funds |
| BuyPlotTheme / SetPlotTheme | Function | id<=32 | exists, owned/VIP, funds |
| BuyFurniture | Function | id<=32 | exists, funds |
| PlaceFurniture | Function | id<=32, ints +-100, rot enum | inventory, bounds, grid, overlap, cap |
| RemoveFurniture | Function | guid<=16 | exists on own plot |
| ClaimPlotIncome | Function | none | server-computed window, claim-once |
| VisitFriendPlot | Function | int>=1 | friendship, presence, daily pair cap |
| ClaimQuest | Function | enum scope, id<=32 | active, complete, claim-once |
| GiftEgg | Function | int>=1 | friendship, presence, daily pair cap |
| BuyCosmetic | Function | id<=32 | exists, purchasable, funds, not owned |
| EquipAvatarCosmetic | Function | slot<=16, id<=32? | slot/layer/ownership |
| EquipMythlingCosmetic | Function | ids + slot | mythling owned, slot/layer/ownership |
| BuyArenaShopItem | Function | int 1..8 | weekly slot, tokens, dupes |
| Server->client events | Event | n/a | no server listeners attached |

Hardening actions taken in this pass:

- Arena position enforcement: players are anchored on their pads and the
  server re-pins anyone drifting more than 8 studs during a match
  (exploiters own their character physics; the server now corrects it).
- Reviewed every numeric client input for clamps: quantities, tiers,
  slots, indexes and coordinates are all range-guarded; strings are all
  length-capped; remaining integers are ids validated by lookup.
- Confirmed no remote accepts a player identity, price, odds value, stat
  or reward amount from the client anywhere in the codebase.
- Net violation counters remain available via Net.GetViolationCounts()
  and all violations are warn-logged with player attribution.

## Post-gate additions

- UpdateSetting: key is whitelisted via Guard.oneOf and the value must
  be a boolean; nothing else in the profile is reachable.
- SeasonRollover and the hub world add no client-writable surface.
