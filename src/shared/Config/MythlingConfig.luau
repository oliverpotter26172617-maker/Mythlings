--!strict
-- The species catalogue. Stat spreads are fractions of the rarity stat
-- budget (StatConfig.RarityBudgets) and must sum to 1 per species; a unit
-- test enforces it. Abilities resolve from the species element and growth
-- stage (see AbilityConfig).

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

export type SpeciesDef = {
	DisplayName: string,
	Element: string,
	Rarity: string,
	Spread: { HP: number, Attack: number, Defence: number, Speed: number },
}

local function species(
	displayName: string,
	element: string,
	rarity: string,
	hp: number,
	atk: number,
	def: number,
	spd: number
): SpeciesDef
	return {
		DisplayName = displayName,
		Element = element,
		Rarity = rarity,
		Spread = { HP = hp, Attack = atk, Defence = def, Speed = spd },
	}
end

local catalogue: { [string]: SpeciesDef } = {
	-- Flame
	Cindercub = species("Cindercub", "Flame", "Common", 0.28, 0.32, 0.20, 0.20),
	Scorchpup = species("Scorchpup", "Flame", "Uncommon", 0.26, 0.34, 0.20, 0.20),
	Pyrelynx = species("Pyrelynx", "Flame", "Rare", 0.24, 0.34, 0.18, 0.24),
	Emberwing = species("Emberwing", "Flame", "Epic", 0.24, 0.36, 0.16, 0.24),
	Infernyx = species("Infernyx", "Flame", "Legendary", 0.26, 0.38, 0.16, 0.20),

	-- Tide
	Dribblet = species("Dribblet", "Tide", "Common", 0.32, 0.24, 0.26, 0.18),
	Splashfin = species("Splashfin", "Tide", "Uncommon", 0.30, 0.26, 0.26, 0.18),
	Marewyrm = species("Marewyrm", "Tide", "Rare", 0.30, 0.28, 0.24, 0.18),
	Tidecaller = species("Tidecaller", "Tide", "Epic", 0.32, 0.28, 0.24, 0.16),
	Levyathan = species("Levyathan", "Tide", "Legendary", 0.34, 0.28, 0.24, 0.14),

	-- Terra
	Pebblit = species("Pebblit", "Terra", "Common", 0.30, 0.20, 0.34, 0.16),
	Mossback = species("Mossback", "Terra", "Uncommon", 0.32, 0.20, 0.34, 0.14),
	Boulderhorn = species("Boulderhorn", "Terra", "Rare", 0.32, 0.22, 0.34, 0.12),
	Verdantclaw = species("Verdantclaw", "Terra", "Epic", 0.30, 0.26, 0.32, 0.12),
	Terragon = species("Terragon", "Terra", "Legendary", 0.32, 0.26, 0.32, 0.10),

	-- Storm
	Sparkmote = species("Sparkmote", "Storm", "Common", 0.22, 0.28, 0.16, 0.34),
	Zaphare = species("Zaphare", "Storm", "Uncommon", 0.22, 0.28, 0.14, 0.36),
	Voltfox = species("Voltfox", "Storm", "Rare", 0.22, 0.30, 0.14, 0.34),
	Thunderoc = species("Thunderoc", "Storm", "Epic", 0.24, 0.32, 0.14, 0.30),
	Tempestrix = species("Tempestrix", "Storm", "Legendary", 0.24, 0.34, 0.14, 0.28),

	-- Shadow
	Gloomkit = species("Gloomkit", "Shadow", "Common", 0.24, 0.30, 0.18, 0.28),
	Murkling = species("Murkling", "Shadow", "Uncommon", 0.24, 0.32, 0.16, 0.28),
	Duskstalker = species("Duskstalker", "Shadow", "Rare", 0.22, 0.34, 0.16, 0.28),
	Nightmaw = species("Nightmaw", "Shadow", "Epic", 0.24, 0.36, 0.16, 0.24),
	Umbrageist = species("Umbrageist", "Shadow", "Legendary", 0.24, 0.36, 0.14, 0.26),

	-- Radiant
	Glimmote = species("Glimmote", "Radiant", "Common", 0.28, 0.24, 0.26, 0.22),
	Shinelet = species("Shinelet", "Radiant", "Uncommon", 0.28, 0.26, 0.26, 0.20),
	Dawnpiercer = species("Dawnpiercer", "Radiant", "Rare", 0.26, 0.30, 0.24, 0.20),
	Solarine = species("Solarine", "Radiant", "Epic", 0.28, 0.30, 0.24, 0.18),
	Luxarch = species("Luxarch", "Radiant", "Legendary", 0.30, 0.30, 0.24, 0.16),

	-- Mythic
	Aetherion = species("Aetherion", "Radiant", "Mythic", 0.28, 0.32, 0.22, 0.18),
	Chronowyrm = species("Chronowyrm", "Storm", "Mythic", 0.24, 0.32, 0.16, 0.28),
	Voidmaw = species("Voidmaw", "Shadow", "Mythic", 0.26, 0.36, 0.16, 0.22),
}

return TableUtil.deepFreeze({
	Species = catalogue,
})
