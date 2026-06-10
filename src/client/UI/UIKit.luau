--!strict
-- Tiny helpers for code-built UI. Keeps controllers readable and mobile
-- scaling consistent (everything is Scale-based, no Offset-only layouts).

local UIKit = {}

function UIKit.create(className: string, props: { [string]: any }, children: { Instance }?): any
	local instance = Instance.new(className) :: any
	for key, value in props do
		instance[key] = value
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if className == "ScreenGui" then
		UIKit.applyMobileScale(instance)
	end
	return instance
end

-- Mobile scaling: shrinks UI gently on small viewports so offset-sized
-- buttons stay reachable on phones. Applied to every ScreenGui UIKit makes.
function UIKit.applyMobileScale(screenGui: ScreenGui)
	local scale = Instance.new("UIScale")
	scale.Name = "MobileScale"
	scale.Parent = screenGui

	local camera = workspace.CurrentCamera
	local function update()
		if camera == nil then
			return
		end
		local viewport = camera.ViewportSize
		local shortest = math.min(viewport.X, viewport.Y)
		-- 720p and up: full size. Small phones: down to 75%.
		scale.Scale = math.clamp(shortest / 720, 0.75, 1)
	end
	update()
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
end

UIKit.Palette = {
	Panel = Color3.fromRGB(34, 40, 49),
	PanelLight = Color3.fromRGB(48, 56, 66),
	Accent = Color3.fromRGB(255, 196, 87),
	Positive = Color3.fromRGB(102, 187, 106),
	Negative = Color3.fromRGB(239, 83, 80),
	Text = Color3.fromRGB(238, 238, 238),
	TextDim = Color3.fromRGB(170, 178, 189),
}

function UIKit.rounded(radius: number?): UICorner
	return UIKit.create("UICorner", { CornerRadius = UDim.new(0, radius or 8) })
end

function UIKit.label(text: string, textSize: number, props: { [string]: any }?): TextLabel
	local label = UIKit.create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Text = text,
		TextSize = textSize,
		TextColor3 = UIKit.Palette.Text,
		TextScaled = false,
		TextWrapped = true,
	})
	for key, value in props or {} do
		(label :: any)[key] = value
	end
	return label
end

function UIKit.button(text: string, colour: Color3, props: { [string]: any }?): TextButton
	local button = UIKit.create("TextButton", {
		AutoButtonColor = true,
		BackgroundColor3 = colour,
		Font = Enum.Font.GothamBold,
		Text = text,
		TextSize = 16,
		TextColor3 = Color3.fromRGB(20, 24, 28),
	})
	UIKit.rounded():Clone().Parent = button
	for key, value in props or {} do
		(button :: any)[key] = value
	end
	return button
end

return UIKit
