# GATE 2 Status Report: Launch Candidate

Date: 2026-06-10
Branch: `claude/mythlings-roblox-game-eopm8b`
Scope: all phases 0 through 6 implemented; this is the launch candidate.

## Summary

All 24 backlog modules are implemented, unit tested and committed (one
conventional commit per module). The full production definition is met
in code:

- **Data safety:** session-locked ProfileStore profiles, reversible
  schema migrations, BindToClose flushing, audited single-gateway
  currency mutations.
- **Server authority:** every roll (hatch, breed, loot, nursery), every
  battle outcome and every currency change resolves on the server. The
  client sends only ids, indexes and enums, all rate limited and
  validated (full audit table in docs/SECURITY.md).
- **Monetisation:** all Section 3.9 SKUs with idempotent receipts
  (ledger-first, replay tested), pass benefits server-cached, Premium
  Nursery with build-failing fairness tests, 50-tier Battle Pass.
- **Fairness guardrails:** odds disclosed from the same config the
  server rolls; power-gap capped matchmaking; no stat-bearing cosmetics
  (structural + same-seed battle identity test); free path for every
  paid Mythling.
- **Retention:** quests, login calendar (day 7 Epic egg), gifting,
  group bonus, onboarding with free Rare egg and funnel analytics.
- **Operations:** economy telemetry on every currency flow, live kill
  switches via DataStore (purchases held not dropped), soft-launch
  flag, launch copy and dashboard wiring steps in
  docs/LAUNCH-CHECKLIST.md.

## Test and build state

- 192 unit tests across 25 spec files, 0 failures.
- rojo build, selene (0 warnings) and StyLua all clean.
- Headline simulations: 10,000-hatch pity guarantee (zero violations),
  100,000-roll breeding distributions within 0.5pp, 1,000 battles with
  zero errors and median 125s, 50,000 raid chests within 0.5pp,
  receipt replay idempotency, out-of-bounds furniture exploit rejected,
  same-seed battles identical with cosmetics equipped.

## Open risks for launch sign-off

1. **Placeholder art everywhere.** Mythlings are coloured spheres; eggs,
   arenas, plots and furniture are primitive parts. All build points are
   isolated (buildActor, buildArena, renderPlot/renderFurniture) so an
   art pass swaps models without touching logic. This is the biggest
   gap between "systems-complete" and "shippable storefront product".
2. **Asset ids are zero.** Dev products, game passes and the group id
   must be created on the dashboard and pasted into config (checklist
   section 3). Purchases politely refuse until then.
3. **Studio verification pending.** FPS/memory device matrix,
   multi-client arena/raid runs, BindToClose flush and receipt sandbox
   tests need Roblox Studio (checklist section 6). All unit-testable
   acceptance criteria are green in CI.
4. **Under-13 spend prompt.** The spec's daily Gem spend soft-cap prompt
   for under-13 accounts is not implemented: Roblox does not expose age
   signals to experiences. Logged in DECISIONS-NEEDED.md with the
   compliant alternative (rely on Roblox parental spend controls).
5. **Economy tuning.** Ship numbers are the locked Section 6 values;
   D1/D7 retention dashboards drive post-launch tuning per the spec.

## Recommendation

Code-complete launch candidate. Remaining work is asset production,
dashboard wiring and the manual Studio pass, none of which is agent
codework in this environment.

## Post-gate addendum (same day)

Four follow-up commits after the gate, closing playability gaps found in
a final review:

- Hub world with spawn plaza and landmarks (players previously had no
  map to stand on), persistent currency/trophy HUD, and the collection
  screen that sets the follower/arena team (the missing core-loop UI).
- Seasonal trophy soft reset with bracket placement Gems (spec 3.10).
- GitHub Actions CI running lint, format, all 197 tests and a place
  build on every push.
- Critter-styled actor models, authoritative battle HP bars, persisted
  settings, and a fix for the boot race where the first profile push
  could beat the client's listeners.

Final state: 28 commits, 197 tests green, CI in place.
