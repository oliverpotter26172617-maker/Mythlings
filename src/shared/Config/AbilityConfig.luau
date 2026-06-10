--!strict
-- Ability data. Every Mythling has the neutral basic attack plus up to
-- three elemental ability slots unlocked by growth stage. Abilities are
-- pure data; the battle simulation is the generic runner.

local ElementConfig = require(script.Parent.ElementConfig)
local TableUtil = require(script.Parent.Parent.Util.TableUtil)

export type AbilityDef = {
	DisplayName: string,
	Power: number,
	CooldownSeconds: number,
	Element: string?,
}

local abilities: { [string]: AbilityDef } = {
	Strike = {
		DisplayName = "Strike",
		Power = 1.0,
		CooldownSeconds = 3.5,
		Element = nil,
	},
}

-- Slot templates applied per element. Slot order matches stage unlocks.
local slotTemplates = {
	{ Suffix = "Bolt", DisplayName = "%s Bolt", Power = 1.6, CooldownSeconds = 8 },
	{ Suffix = "Nova", DisplayName = "%s Nova", Power = 2.2, CooldownSeconds = 14 },
	{ Suffix = "Frenzy", DisplayName = "%s Frenzy", Power = 3.0, CooldownSeconds = 22 },
}

for _, element in ElementConfig.Order do
	for _, template in slotTemplates do
		abilities[element .. template.Suffix] = {
			DisplayName = string.format(template.DisplayName, element),
			Power = template.Power,
			CooldownSeconds = template.CooldownSeconds,
			Element = element,
		}
	end
end

-- Ability slots available at each growth stage (basic Strike is always
-- present and not listed).
local stageSlots: { [string]: number } = {
	Hatchling = 0,
	Juvenile = 1,
	Adult = 2,
	Alpha = 3,
}

local AbilityConfig = {
	Abilities = abilities,
	StageSlots = stageSlots,
	SlotSuffixes = { "Bolt", "Nova", "Frenzy" },
}

-- Ability ids a Mythling of this element and stage takes into battle.
function AbilityConfig.loadout(element: string, stage: string): { string }
	local result = { "Strike" }
	local slots = stageSlots[stage] or 0
	for index = 1, slots do
		table.insert(result, element .. AbilityConfig.SlotSuffixes[index])
	end
	return result
end

return TableUtil.deepFreeze(AbilityConfig)
