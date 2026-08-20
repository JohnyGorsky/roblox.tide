--!strict
--[[
	AdminAllowlist - who is allowed to use the admin panel.

	🔴 THIS MODULE MUST NEVER MOVE TO ReplicatedStorage.
	It lives in ServerStorage so no client can read it. Moving it would tell every player exactly who
	the admins are, and is the first step toward a client that decides its own permissions.

	Keyed on UserId, NOT username. Roblox usernames are mutable: a username allowlist breaks the moment
	the account is renamed, and if the old name is later claimed by someone else, admin access transfers
	to a stranger. The name beside each id is a comment for humans only - nothing reads it.

	Changing this list requires a repo edit and a publish. That is deliberate: the list that grants god
	powers should be visible in `git diff`, not editable at runtime.

	Spec: docs/build/13-admin-tools.md
	Feature: docs/features/0012-admin-panel/
]]

local AdminAllowlist = {}

-- UserId -> label. The label appears in the audit log.
local ADMINS: { [number]: string } = {
	[5025640608] = "johnygorsky10", -- owner
}

--[[
	The single authorisation check. Every handler calls this, on every call.

	There is deliberately no caching, no "is admin" flag stored on the player, and no second code path:
	a cached answer is an answer that can be wrong, and a second path is a path that can drift.
]]
function AdminAllowlist.isAdmin(player: Player?): boolean
	if typeof(player) ~= "Instance" then
		return false
	end
	local p = player :: any
	if not p:IsA("Player") then
		return false
	end
	return ADMINS[p.UserId] ~= nil
end

--- Label for the audit log. Returns nil for non-admins.
function AdminAllowlist.labelFor(player: Player?): string?
	if not AdminAllowlist.isAdmin(player) then
		return nil
	end
	return ADMINS[(player :: Player).UserId]
end

--- Count, for the startup log line. Never exposes the ids themselves.
function AdminAllowlist.count(): number
	local n = 0
	for _ in pairs(ADMINS) do
		n += 1
	end
	return n
end

return AdminAllowlist
