--!strict
-- Builds Mythling profile records. Pure Luau.

local MythlingConfig = require(script.Parent.Parent.Config.MythlingConfig)

local MythlingFactory = {}

export type MythlingRecord = {
	SpeciesId: string,
	Rarity: string,
	Element: string,
	Potential: number,
	Shiny: boolean,
	Stage: string,
	Xp: number,
	CreatedAt: number,
	LastFedAt: number,
	BreedCooldownUntil: number,
	Nickname: string?,
	Cosmetics: { [string]: string },
	Housed: boolean,
}

function MythlingFactory.create(args: {
	SpeciesId: string,
	Potential: number,
	Shiny: boolean?,
	Now: number,
}): MythlingRecord
	local species = MythlingConfig.Species[args.SpeciesId]
	assert(species ~= nil, `unknown species {args.SpeciesId}`)

	return {
		SpeciesId = args.SpeciesId,
		Rarity = species.Rarity,
		Element = species.Element,
		Potential = args.Potential,
		Shiny = args.Shiny == true,
		Stage = "Hatchling",
		Xp = 0,
		CreatedAt = args.Now,
		LastFedAt = 0,
		BreedCooldownUntil = 0,
		Nickname = nil,
		Cosmetics = {},
		Housed = false,
	}
end

return MythlingFactory
