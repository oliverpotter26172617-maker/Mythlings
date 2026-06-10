# Mythlings Launch Checklist

## Listing copy (paste into the Creator Dashboard)

- **Title:** Mythlings 🥚 Hatch, Battle, Breed!
- **Icon concept:** a cracked glowing egg with a creature's eye visible
  inside, arena flames behind. (Commission per this brief; no asset in
  repo.)
- **Thumbnail slots:**
  1. Hatch reveal moment (Legendary colours, "1 in 111!").
  2. 3v3 arena battle with ability buttons visible.
  3. Decorated plot with followers and a Shiny.
- **Description:**

  > Hatch mysterious eggs, raise and breed your Mythlings, then take
  > them into the arena to climb the ranks!
  >
  > 🥚 Seven egg tiers with fully disclosed hatch odds
  > ⚔️ Real-time 3v3 battles with fair, power-matched opponents
  > 🧬 Breed Adults for stronger offspring and rare Shiny variants
  > 🏠 Decorate your plot and earn while you are away
  > 🎁 Daily rewards, quests, raids and a 50-tier season pass
  >
  > All randomised purchases show their exact odds before you buy.
  > Mythlings never sells power: every paid Mythling is also hatchable
  > free, and matchmaking always power-balances your opponent.

## Policy compliance

- [x] Paid random items: odds shown on the purchase UI, rendered from
  the same config the server rolls with (EggConfig).
- [x] No purchasable stat advantage (build-failing tests: Nursery
  ceiling, cosmetic whitelist, free-path availability).
- [ ] Age guidelines questionnaire: declare randomised paid items
  (eggs bought with Gems), no paid loot crates with real-world value,
  social features (chat, gifting), no user-generated content.
- [ ] Link the odds policy section of the description once the game
  page URL exists.

## Asset id wiring (required before purchases work)

- [ ] Create 4 Gem pack developer products + Battle Pass premium
  product; paste ids into `MonetisationConfig.DevProducts`.
- [ ] Create 5 game passes; paste ids into
  `MonetisationConfig.GamePasses`.
- [ ] Create the Roblox group; paste the id into `QuestConfig.GroupId`.

## Soft launch plan

- `LaunchConfig.SoftLaunch = true` for the limited phase; region and
  audience limiting happens through place visibility settings (in-game
  matchmaking is per-server so no extra region gate is needed).
- Watch D1/D7 retention (targets: D1 >= 35%, D7 >= 12%) on the
  analytics dashboards before touching monetisation tuning.

## Kill switches (live, no redeploy)

Write a table to DataStore `MythlingsLiveConfig`, key `Flags`; every
server applies it within 60 seconds:

```lua
-- Example: pause purchases and breeding during an incident.
{ PurchasesEnabled = false, BreedingEnabled = false }
```

Available flags: `PurchasesEnabled` (receipts held, not dropped),
`BreedingEnabled`, `MatchmakingEnabled`, `RaidsEnabled`.

## Pre-launch Studio verification (manual)

1. Data: join/leave/rejoin round-trip, BindToClose flush on stop.
2. Full loop: buy egg (odds panel), hatch (pity counter visible in
   profile), feed to Adult, set followers, ranked + casual battle,
   breed, hatch the bred egg.
3. Receipts: test purchase in Studio sandbox; replay safety is unit
   tested but confirm grant lands once.
4. Two-client ranked match and four-client raid end to end.
5. Device matrix: 60fps and under 1.5GB memory on a mid-range phone
   with 50 followers in view (Module 1.3 acceptance).
6. Onboarding funnel events visible on the Analytics dashboard.
