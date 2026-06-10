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
