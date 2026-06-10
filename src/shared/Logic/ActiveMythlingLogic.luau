--!strict
-- Validation for the follower roster and formation offsets. Pure Luau.

local ActiveMythlingLogic = {}

export type ValidationResult = { Ok: boolean, Error: string? }

-- Checks a requested follower roster against the player's own collection.
function ActiveMythlingLogic.validateRoster(
	data: { [string]: any },
	mythlingIds: { string },
	maxFollowers: number
): ValidationResult
	if #mythlingIds > maxFollowers then
		return { Ok = false, Error = `You can have at most {maxFollowers} Mythlings out at once.` }
	end

	local seen: { [string]: boolean } = {}
	for _, mythlingId in mythlingIds do
		if type(mythlingId) ~= "string" then
			return { Ok = false, Error = "Invalid Mythling selection." }
		end
		if seen[mythlingId] then
			return { Ok = false, Error = "You cannot pick the same Mythling twice." }
		end
		seen[mythlingId] = true
		if data.Mythlings[mythlingId] == nil then
			return { Ok = false, Error = "You do not own that Mythling." }
		end
	end

	return { Ok = true }
end

-- Offset (x, z) behind the owner for the follower at slotIndex (1-based).
-- Slot 1 sits directly behind; later slots fan out left and right.
function ActiveMythlingLogic.formationOffset(slotIndex: number, distance: number, spacing: number): (number, number)
	local lane = math.ceil((slotIndex - 1) / 2)
	local side = if slotIndex % 2 == 0 then -1 else 1
	local x = if slotIndex == 1 then 0 else side * lane * spacing
	return x, distance + lane * (spacing * 0.5)
end

return ActiveMythlingLogic
