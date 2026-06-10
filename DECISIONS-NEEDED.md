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
