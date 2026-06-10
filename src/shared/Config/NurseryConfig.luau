--!strict
-- Premium Nursery (Section 3.9, locked constraints):
-- (a) Nursery Mythlings are created by the same factory and stat formula
--     as hatched ones, so they share the exact stat ceiling.
-- (b) Matchmaking Power brackets apply to them like any other Mythling.
-- (c) Every species sold here must also be obtainable free from the
--     Mythic egg; a build-failing test enforces it.

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

return TableUtil.deepFreeze({
	-- Gems prices by rarity of the offered species.
	Prices = {
		Epic = 350,
		Legendary = 800,
	},

	-- Rotation pools. Each week offers two Epics and one Legendary.
	EpicPool = { "Emberwing", "Tidecaller", "Verdantclaw", "Thunderoc", "Nightmaw", "Solarine" },
	LegendaryPool = { "Infernyx", "Levyathan", "Terragon", "Tempestrix", "Umbrageist", "Luxarch" },

	EpicsPerWeek = 2,
	LegendariesPerWeek = 1,
})
