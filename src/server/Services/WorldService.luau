--!strict
-- Builds the hub world at server start: spawn plaza, paths to the
-- neighbourhood, and ambient lighting. Everything is procedural
-- placeholder geometry sized from config so an art pass can replace it
-- wholesale without touching other systems.

local Lighting = game:GetService("Lighting")

local WorldService = {}

local function part(props: { [string]: any }, parent: Instance): Part
	local instance = Instance.new("Part")
	instance.Anchored = true
	instance.CastShadow = false
	for key, value in props do
		(instance :: any)[key] = value
	end
	instance.Parent = parent
	return instance
end

function WorldService:OnInit()
	local hub = Instance.new("Folder")
	hub.Name = "Hub"
	hub.Parent = workspace

	-- Main plaza.
	part({
		Name = "Plaza",
		Size = Vector3.new(256, 4, 256),
		Position = Vector3.new(0, -2, 0),
		Material = Enum.Material.Grass,
		Color = Color3.fromRGB(106, 168, 79),
	}, hub)

	-- Spawn pad.
	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "Spawn"
	spawnLocation.Anchored = true
	spawnLocation.Size = Vector3.new(12, 1, 12)
	spawnLocation.Position = Vector3.new(0, 0.5, 0)
	spawnLocation.Material = Enum.Material.Marble
	spawnLocation.Color = Color3.fromRGB(238, 238, 238)
	spawnLocation.Duration = 0
	spawnLocation.Parent = hub

	-- Landmark stalls so the world reads as places, not buttons: the egg
	-- shop, the hatchery, the breeding den and the arena gate.
	local landmarks = {
		{ Name = "EggShopStall", Position = Vector3.new(-60, 6, -40), Colour = Color3.fromRGB(255, 196, 87) },
		{ Name = "HatcheryDome", Position = Vector3.new(60, 6, -40), Colour = Color3.fromRGB(102, 187, 106) },
		{ Name = "BreedingDen", Position = Vector3.new(-60, 6, 40), Colour = Color3.fromRGB(171, 71, 188) },
		{ Name = "ArenaGate", Position = Vector3.new(60, 6, 40), Colour = Color3.fromRGB(239, 83, 80) },
	}
	for _, landmark in landmarks do
		local stall = part({
			Name = landmark.Name,
			Size = Vector3.new(16, 12, 16),
			Position = landmark.Position,
			Material = Enum.Material.SmoothPlastic,
			Color = landmark.Colour,
		}, hub)

		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.new(0, 200, 0, 36)
		billboard.StudsOffset = Vector3.new(0, 8, 0)
		billboard.AlwaysOnTop = true
		billboard.MaxDistance = 200
		billboard.Parent = stall
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, 0, 1, 0)
		label.Font = Enum.Font.GothamBold
		label.TextSize = 18
		label.TextStrokeTransparency = 0.4
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.Text = string.gsub(landmark.Name, "(%l)(%u)", "%1 %2")
		label.Parent = billboard
	end

	-- Path towards the housing neighbourhood (plots start near 1000, 1000).
	part({
		Name = "NeighbourhoodPath",
		Size = Vector3.new(24, 1, 900),
		Position = Vector3.new(128, -0.5, 500),
		Orientation = Vector3.new(0, -14, 0),
		Material = Enum.Material.Cobblestone,
		Color = Color3.fromRGB(189, 189, 189),
	}, hub)

	-- Ambient look.
	Lighting.Ambient = Color3.fromRGB(120, 130, 150)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 150, 170)
	Lighting.Brightness = 2
	Lighting.ClockTime = 14.5
end

return WorldService
