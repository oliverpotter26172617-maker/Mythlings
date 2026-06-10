--!strict
-- Rarity tiers in ascending order, with UI colours and display copy.

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

local order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }

local indexByName: { [string]: number } = {}
for index, name in order do
	indexByName[name] = index
end

return TableUtil.deepFreeze({
	Order = order,
	IndexByName = indexByName,

	Colours = {
		Common = { R = 176, G = 190, B = 197 },
		Uncommon = { R = 102, G = 187, B = 106 },
		Rare = { R = 66, G = 165, B = 245 },
		Epic = { R = 171, G = 71, B = 188 },
		Legendary = { R = 255, G = 167, B = 38 },
		Mythic = { R = 239, G = 83, B = 80 },
	},
})
