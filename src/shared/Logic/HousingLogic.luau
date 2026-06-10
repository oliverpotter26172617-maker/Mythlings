--!strict
-- Plot and furniture placement rules. Pure Luau.
-- Coordinates are in grid cells, integer, with (0, 0) at the plot centre.
-- Rotation is 0, 90, 180 or 270 degrees; 90/270 swap the footprint axes.

local HousingConfig = require(script.Parent.Parent.Config.HousingConfig)

local HousingLogic = {}

export type Placement = {
	ItemId: string,
	X: number,
	Z: number,
	Rotation: number,
}

local function footprint(item: HousingConfig.FurnitureDef, rotation: number): (number, number)
	if rotation == 90 or rotation == 270 then
		return item.Depth, item.Width
	end
	return item.Width, item.Depth
end

-- Inclusive cell bounds [minX, maxX], [minZ, maxZ] for a placement.
local function cellBounds(item: HousingConfig.FurnitureDef, x: number, z: number, rotation: number)
	local width, depth = footprint(item, rotation)
	return x, x + width - 1, z, z + depth - 1
end

local function overlaps(a1: number, a2: number, b1: number, b2: number): boolean
	return a1 <= b2 and b1 <= a2
end

-- Validates one placement against the plot tier and existing furniture.
function HousingLogic.canPlace(
	plotTier: number,
	existing: { [string]: Placement },
	itemId: string,
	x: number,
	z: number,
	rotation: number
): (boolean, string?)
	local item = HousingConfig.Furniture[itemId]
	if item == nil then
		return false, "That furniture does not exist."
	end
	local tier = HousingConfig.PlotTiers[plotTier]
	if tier == nil then
		return false, "Invalid plot."
	end
	if rotation ~= 0 and rotation ~= 90 and rotation ~= 180 and rotation ~= 270 then
		return false, "Furniture can only rotate in quarter turns."
	end
	if x % 1 ~= 0 or z % 1 ~= 0 then
		return false, "Furniture must sit on the grid."
	end

	-- Bounds: the whole footprint must fit inside the plot. Cells run from
	-- -half to half - 1 (a tier-16 plot spans cells -8..7).
	local half = tier.Cells / 2
	local minX, maxX, minZ, maxZ = cellBounds(item, x, z, rotation)
	if minX < -half or maxX >= half or minZ < -half or maxZ >= half then
		return false, "That spot is outside your plot."
	end

	-- Furniture cap for the tier.
	local count = 0
	for _ in existing do
		count += 1
	end
	if count >= HousingConfig.MaxFurniture[plotTier] then
		return false, "Your plot cannot hold any more furniture."
	end

	-- Collision sanity: no overlapping footprints.
	for _, placement in existing do
		local other = HousingConfig.Furniture[placement.ItemId]
		if other == nil then
			continue
		end
		local oMinX, oMaxX, oMinZ, oMaxZ = cellBounds(other, placement.X, placement.Z, placement.Rotation)
		if overlaps(minX, maxX, oMinX, oMaxX) and overlaps(minZ, maxZ, oMinZ, oMaxZ) then
			return false, "Something is already there."
		end
	end

	return true, nil
end

function HousingLogic.validateUpgrade(data: { [string]: any }): (boolean, string?, number?)
	local nextTier = data.Housing.PlotTier + 1
	local tier = HousingConfig.PlotTiers[nextTier]
	if tier == nil then
		return false, "Your plot is already at the largest size.", nil
	end
	if (data.Currencies.Coins or 0) < tier.UpgradeCoins then
		return false, `You need {tier.UpgradeCoins} Coins to upgrade your plot.`, nil
	end
	return true, nil, tier.UpgradeCoins
end

function HousingLogic.validateThemePurchase(data: { [string]: any }, themeId: string): (boolean, string?, number?)
	local theme = HousingConfig.Themes[themeId]
	if theme == nil then
		return false, "That theme does not exist.", nil
	end
	if theme.PriceGems < 0 then
		return false, "That theme is a VIP exclusive.", nil
	end
	if data.Housing.OwnedThemes and data.Housing.OwnedThemes[themeId] then
		return false, "You already own that theme.", nil
	end
	if (data.Currencies.Gems or 0) < theme.PriceGems then
		return false, `You need {theme.PriceGems} Gems for that theme.`, nil
	end
	return true, nil, theme.PriceGems
end

return HousingLogic
