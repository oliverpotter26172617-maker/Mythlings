--!strict
-- Cosmetics catalogue. STAT NEUTRALITY IS STRUCTURAL: CosmeticDef has no
-- stat fields, and a unit test fails the build if any def gains a key
-- outside the whitelist below. Battle code never reads cosmetics.

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

export type CosmeticDef = {
	DisplayName: string,
	Layer: "Avatar" | "Mythling",
	Slot: string,
	PriceGems: number?, -- nil means not directly purchasable (tokens, raids, pass)
	Colour: { R: number, G: number, B: number }?,
}

-- The only keys a cosmetic may carry. Guards against stat creep.
local ALLOWED_KEYS = { "DisplayName", "Layer", "Slot", "PriceGems", "Colour" }

local catalogue: { [string]: CosmeticDef } = {
	-- Avatar layer
	WizardHat = { DisplayName = "Wizard Hat", Layer = "Avatar", Slot = "Hat", PriceGems = 80 },
	CrownOfFlames = { DisplayName = "Crown of Flames", Layer = "Avatar", Slot = "Hat", PriceGems = 200 },
	TamerCape = { DisplayName = "Tamer's Cape", Layer = "Avatar", Slot = "Cape", PriceGems = 120 },
	ArenaArmour = { DisplayName = "Arena Armour Skin", Layer = "Avatar", Slot = "ArmourSkin", PriceGems = 250 },

	-- Mythling layer
	TinyTopHat = { DisplayName = "Tiny Top Hat", Layer = "Mythling", Slot = "Hat", PriceGems = 60 },
	StarTrail = { DisplayName = "Star Trail", Layer = "Mythling", Slot = "Trail", PriceGems = 90 },
	EmberAura = {
		DisplayName = "Ember Aura",
		Layer = "Mythling",
		Slot = "Aura",
		PriceGems = 150,
		Colour = { R = 255, G = 112, B = 67 },
	},
	MoonAura = {
		DisplayName = "Moonlight Aura",
		Layer = "Mythling",
		Slot = "Aura",
		PriceGems = 150,
		Colour = { R = 159, G = 168, B = 218 },
	},
	RoseDye = {
		DisplayName = "Rose Shiny Dye",
		Layer = "Mythling",
		Slot = "Dye",
		PriceGems = 120,
		Colour = { R = 244, G = 143, B = 177 },
	},

	-- Earned only (raid chests, battle pass, arena shop): no Gem price.
	RaidAura = {
		DisplayName = "Raid Champion Aura",
		Layer = "Mythling",
		Slot = "Aura",
		Colour = { R = 255, G = 213, B = 79 },
	},
	SeasonAura = {
		DisplayName = "Season Aura",
		Layer = "Mythling",
		Slot = "Aura",
		Colour = { R = 128, G = 222, B = 234 },
	},
	GladiatorHelm = { DisplayName = "Gladiator Helm", Layer = "Avatar", Slot = "Hat" },
}

return TableUtil.deepFreeze({
	Catalogue = catalogue,
	AllowedKeys = ALLOWED_KEYS,
	AvatarSlots = { "Hat", "Cape", "ArmourSkin" },
	MythlingSlots = { "Hat", "Trail", "Aura", "Dye" },
})
