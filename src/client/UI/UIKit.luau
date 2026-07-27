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

-- Connects Activated with a re-entrancy guard. Handlers that Invoke the
-- server yield, and Activated refires during that yield, so a double tap on
-- a shop or claim button could fire the action twice. This drops presses
-- that arrive while a previous press is still being handled.
function UIKit.onActivated(button: GuiButton, handler: () -> ()): RBXScriptConnection
	local running = false
	return button.Activated:Connect(function()
		if running then
			return
		end
		running = true
		local ok, err = pcall(handler)
		running = false
		if not ok then
			warn(`UIKit.onActivated handler error: {err}`)
		end
	end)
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

-- Single shared, left-edge, vertically scrolling toolbar. Every panel toggle
-- lives here instead of at a fixed Y offset, so buttons reflow and the column
-- scrolls rather than falling off short or downscaled (mobile) viewports.
-- `order` fixes the vertical position (lower is higher up).
local toolbarColumn: any = nil

function UIKit.toolbarButton(text: string, colour: Color3, order: number): TextButton
	if toolbarColumn == nil then
		local Players = game:GetService("Players")
		local playerGui = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
		local gui = UIKit.create("ScreenGui", { Name = "Toolbar", ResetOnSpawn = false })
		gui.Parent = playerGui
		toolbarColumn = UIKit.create("ScrollingFrame", {
			Name = "Column",
			Size = UDim2.new(0, 122, 0.9, 0),
			Position = UDim2.new(0, 8, 0.05, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
		})
		toolbarColumn.Parent = gui
		local layout = UIKit.create("UIListLayout", {
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
		})
		layout.Parent = toolbarColumn
	end
	local button = UIKit.button(text, colour, {
		Size = UDim2.new(1, -6, 0, 40),
		LayoutOrder = order,
	})
	button.Parent = toolbarColumn
	return button
end

return UIKit
