# Decisions Needed

Genuine spec gaps found while implementing. A conservative default has been
picked for each so work never stalls; sign-off or overrides welcome.

(None yet.)

## 2.2 Breeding interpretation details

The locked spec says offspring "rarity rolls with a +1 tier chance bonus
if both parents are same rarity" without exact numbers. Conservative
defaults shipped (all in `BreedingConfig`):

- Base offspring rarity: one parent's rarity at even chance.
- SameRarityUpgradeChance = 15% (+1 tier, capped at Mythic).
- Parent element share = 80% of the element roll, split between parents.
- Bred egg incubation = 180 minutes.
- Cooldown Gem skip = 8 Gems per hour remaining (floor 1).

## 3.1 Element wheel layout

The spec asks for a rock-paper-scissors advantage wheel over six elements
without naming the pairs. Shipped (in `BattleConfig.Wheel`):
Flame beats Terra, Terra beats Storm, Storm beats Tide, Tide beats Flame,
and Shadow and Radiant beat each other. Every element has exactly one
advantage (enforced by a unit test).

## 3.3 Reward edge interpretations

- Win streak bonus reads "+10% per streak, caps at +50%": implemented as
  +10% per consecutive win before this one (first win of a run has no
  bonus; the cap lands from the sixth consecutive win).
- Loss protection reads "after 3 straight losses, next loss costs 0":
  implemented as every loss while the streak stays at 3+ costs 0 until a
  win resets it (the player-friendly reading).
- Draws (dead-even timeout) pay the loss consolation row, move no
  trophies and freeze both streaks.

## 4.1 Dev product scope

Instant hatch, breeding skip and raid retries are implemented as Gem
sinks (the spec prices instant hatch in Gems), so the only consumable
Robux products are the four Gem packs and the Battle Pass premium
unlock. A direct "instant hatch" Robux product would need a purchase
context handshake; deferred unless wanted. Raids are freely retryable,
so a paid raid retry has nothing to unlock; omitted.
