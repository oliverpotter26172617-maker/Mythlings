--!strict
-- The six elements with display colours. The battle advantage wheel lives
-- in BattleConfig (Phase 3); this module is safe for client rendering use.

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

return TableUtil.deepFreeze({
	Order = { "Flame", "Tide", "Terra", "Storm", "Shadow", "Radiant" },

	Colours = {
		Flame = { R = 244, G = 81, B = 30 },
		Tide = { R = 3, G = 155, B = 229 },
		Terra = { R = 124, G = 179, B = 66 },
		Storm = { R = 255, G = 213, B = 79 },
		Shadow = { R = 94, G = 53, B = 177 },
		Radiant = { R = 255, G = 241, B = 118 },
	},
})
