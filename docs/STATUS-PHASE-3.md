# GATE 1 Status Report: Playable Vertical Slice

Date: 2026-06-10
Branch: `claude/mythlings-roblox-game-eopm8b`
Scope covered: Phase 0 (Foundation), Phase 1 (Hatch and collect),
Phase 2 (Growth and breeding), Phase 3 (Arena).

## Summary

All 12 modules from 0.1 through 3.4 are implemented, unit tested and
committed (one conventional commit per module). The vertical slice loop
is in place end to end on the server: buy egg (odds disclosed) -> incubate
with offline timers -> hatch with pity -> feed and stage up -> set a
follower team -> queue ranked/casual -> bracket-and-power matched battle
-> Section 3.6 payouts -> breed Adults -> sealed bred egg -> repeat.
Weekly boss raids with chest loot complete the phase.

## Test and build state

- 134 unit tests, 0 failures, across 17 spec files (Lune runner with a
  TestEZ-compatible API; specs remain runnable by TestEZ in Studio).
- `rojo build` produces a clean place file; selene and StyLua pass with
  zero warnings.
- Key acceptance simulations, all green:
  - Hatching: 10,000-roll pity simulation, zero guarantee violations;
    odds distribution within 1 point over 100,000 rolls.
  - Breeding: 100,000-roll inheritance simulation within 0.5 points on
    element weighting, Shiny rate and upgrade rate; Potential always in
    the average plus/minus 15 band.
  - Battles: 1,000 random 3v3 sims, zero errors.
  - Rewards: a test block per Section 3.6 table row.
  - Raids: chest distribution within 0.5 points over 50,000 chests.

## Battle-length telemetry (from the pure sim, 300 random matchups)

- p10: 69s, median: 125s, p90: 198s, timeouts at 240s cap: 1.3%.
- Target band 90 to 180 seconds: median comfortably inside; the enrage
  ramp (from 150s) keeps tails short.

## FPS and memory telemetry

Not measurable in this environment (no Roblox Studio on the Linux build
host). The design keeps budgets in hand:

- Follower actors are one ball part, two align constraints and one
  billboard each; physics is client-owned (zero server cost).
- Battles are simulated server-side as pure Luau; clients receive
  batched events four times a second, not per-tick replication.
- StreamingEnabled is on in the place file.

## Studio verification checklist for sign-off (manual, ~30 minutes)

1. Join/leave/rejoin: profile round-trips via the ProfileStore mock,
   BindToClose flushes on stop.
2. Buy a Basic egg from the shop; confirm the odds panel matches
   EggConfig and insufficient funds refuse politely.
3. Incubate, instant-finish with Gems, confirm reveal and pity counter.
4. Feed to Adult, watch the stage-up burst, set 3 followers, confirm
   50-actor FPS benchmark (acceptance for 1.3) on a mid-range device.
5. Two-client ranked match end to end: queue, teleport, manual casts,
   payout (acceptance for 3.2).
6. Four-client raid clear and chest grant (acceptance for 3.4).

## Known gaps and risks

- Placeholder art: Mythlings are coloured spheres; arenas are bare
  platforms. Art is out of scope for the agent but slots are isolated
  (MythlingSpawnService.buildActor, BattleService.buildArena).
- The Wally registry is unreachable from this environment, so
  dependencies are vendored (docs/BLOCKERS.md #1).
- FPS/memory acceptance numbers must come from the Studio checklist
  above before GATE 2.
- DECISIONS-NEEDED.md lists conservative defaults taken where the locked
  spec was silent (breeding upgrade chance, element wheel layout, reward
  edge cases). Overrides are one config edit each.

## Next (pending sign-off)

Phase 4: monetisation (products and passes with idempotent receipts,
Premium Nursery with free-path enforcement, Battle Pass), then housing,
cosmetics, retention, hardening and the launch checklist.
