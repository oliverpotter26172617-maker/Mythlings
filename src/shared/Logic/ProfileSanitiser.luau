--!strict
-- Builds the client-visible snapshot of a profile. Pure Luau.
--
-- Removed entirely: MigrationBackups, PurchaseLedger (server bookkeeping).
-- Redacted: each Mythling's hidden Potential value (the spec keeps it
-- hidden from players; it must never replicate).

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

local ProfileSanitiser = {}

local OMITTED_TOP_LEVEL = {
	MigrationBackups = true,
	PurchaseLedger = true,
}

function ProfileSanitiser.sanitise(data: { [string]: any }): { [string]: any }
	local snapshot = {}
	for key, value in data do
		if not OMITTED_TOP_LEVEL[key] then
			snapshot[key] = TableUtil.deepCopy(value)
		end
	end

	if snapshot.Mythlings then
		for _, mythling in snapshot.Mythlings do
			mythling.Potential = nil
		end
	end

	return snapshot
end

return ProfileSanitiser
