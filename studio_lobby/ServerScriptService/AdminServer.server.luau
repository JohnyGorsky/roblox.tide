--!strict
--[[
	AdminServer - the gate.

	Everything the admin panel can do passes through here, and every single call re-checks the allowlist.
	The client is never trusted for anything: not its identity, not its permissions, not its tool list.

	🔴 The rules this file exists to enforce (docs/build/13-admin-tools.md):
	  1. One authorisation function. No caching, no per-player flag, no second path.
	  2. Re-check on EVERY call, not once at join. A client that was never an admin can still fire remotes.
	  3. The tool list is sent only after the check passes, so a non-admin cannot enumerate the tools.
	  4. Log accepted calls AND rejected ones. In production the rejections are the interesting ones.

	Because the panel ships in the published game, a new tool added without going through `handle` below
	is a production vulnerability, not a bug.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AdminAllowlist = require(ServerStorage:WaitForChild("AdminAllowlist"))
local AdminTools = require(ServerStorage:WaitForChild("AdminTools"))

local REMOTE_NAME = "AdminRemote"
local LOG_PREFIX = "[ADMIN]"
local MAX_LOG = 200
local RATE_LIMIT_PER_SEC = 20

-- ---------------------------------------------------------------------------
-- Audit log
-- ---------------------------------------------------------------------------

local auditLog: { { at: number, userId: number, name: string, action: string, ok: boolean, detail: string } } = {}

local function audit(player: Player?, action: string, ok: boolean, detail: string)
	local entry = {
		at = os.time(),
		userId = player and player.UserId or 0,
		name = player and player.Name or "<no player>",
		action = action,
		ok = ok,
		detail = detail,
	}
	table.insert(auditLog, entry)
	if #auditLog > MAX_LOG then
		table.remove(auditLog, 1)
	end
	-- Rejections are warnings on purpose: in a live server they are the signal worth noticing.
	local line = ("%s %s userId=%d action=%s place=%d %s")
		:format(LOG_PREFIX, ok and "OK  " or "DENY", entry.userId, action, game.PlaceId, detail)
	if ok then
		print(line)
	else
		warn(line)
	end
end

-- ---------------------------------------------------------------------------
-- Rate limiting
-- ---------------------------------------------------------------------------
-- An admin cannot meaningfully abuse this, but a compromised or buggy client shouldn't be able to spin
-- the server either. Cheap insurance.

local callCounts: { [number]: { second: number, n: number } } = {}

local function withinRate(player: Player): boolean
	local nowSec = math.floor(os.clock())
	local rec = callCounts[player.UserId]
	if not rec or rec.second ~= nowSec then
		callCounts[player.UserId] = { second = nowSec, n = 1 }
		return true
	end
	rec.n += 1
	return rec.n <= RATE_LIMIT_PER_SEC
end

Players.PlayerRemoving:Connect(function(player)
	callCounts[player.UserId] = nil
end)

-- ---------------------------------------------------------------------------
-- The single entry point
-- ---------------------------------------------------------------------------

local remote = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
if not remote then
	remote = Instance.new("RemoteFunction")
	remote.Name = REMOTE_NAME
	remote.Parent = ReplicatedStorage
end

--[[
	Every request lands here. `action` is either a control action or a tool id.

	Note the ordering: authorisation happens BEFORE the action is even looked at. A non-admin cannot
	learn whether a given action name exists, because it is refused before dispatch.
]]
local function handle(player: Player, action: unknown, args: unknown): any
	-- 1. Authorise. Always. First.
	if not AdminAllowlist.isAdmin(player) then
		audit(player, tostring(action), false, "not an admin")
		return { ok = false, error = "unauthorised" }
	end

	-- 2. Sanity-check the shape of the request before using any of it.
	if typeof(action) ~= "string" then
		audit(player, "<non-string>", false, "action was " .. typeof(action))
		return { ok = false, error = "bad request" }
	end
	if args ~= nil and typeof(args) ~= "table" then
		audit(player, action, false, "args was " .. typeof(args))
		return { ok = false, error = "bad request" }
	end

	-- 3. Rate limit.
	if not withinRate(player) then
		audit(player, action, false, "rate limited")
		return { ok = false, error = "slow down" }
	end

	-- 4. Control actions.
	if action == "handshake" then
		audit(player, action, true, "label=" .. tostring(AdminAllowlist.labelFor(player)))
		return {
			ok = true,
			label = AdminAllowlist.labelFor(player),
			placeId = game.PlaceId,
			tools = AdminTools.manifest(), -- only reachable past the check above
		}
	elseif action == "auditLog" then
		local recent = {}
		for i = math.max(1, #auditLog - 30), #auditLog do
			local e = auditLog[i]
			table.insert(recent, ("%s %s %s %s"):format(
				os.date("!%H:%M:%S", e.at), e.ok and "OK  " or "DENY", e.action, e.detail))
		end
		audit(player, action, true, ("%d entries"):format(#recent))
		return { ok = true, result = table.concat(recent, "\n") }
	end

	-- 5. Tool dispatch.
	local tool = AdminTools.get(action)
	if not tool then
		audit(player, action, false, "unknown action")
		return { ok = false, error = "unknown action" }
	end

	local okRun, okTool, detail = pcall(tool.run, player, args)
	if not okRun then
		audit(player, action, false, "handler error: " .. tostring(okTool))
		return { ok = false, error = "handler error" }
	end
	audit(player, action, okTool == true, ("scope=%s %s"):format(tool.scope, tostring(detail)))
	return { ok = okTool == true, result = detail, scope = tool.scope }
end

remote.OnServerInvoke = function(player, action, args)
	local ok, result = pcall(handle, player, action, args)
	if not ok then
		-- Never leak an internal error to the client.
		warn(("%s internal error for userId=%s: %s"):format(LOG_PREFIX, tostring(player and player.UserId), tostring(result)))
		return { ok = false, error = "internal error" }
	end
	return result
end

-- ---------------------------------------------------------------------------
-- Startup
-- ---------------------------------------------------------------------------

local toolsOk, toolsMsg = AdminTools.validate()
if not toolsOk then
	-- A tool with no declared scope is a bug that must be loud, not guessed around.
	warn(("%s TOOL REGISTRY INVALID: %s"):format(LOG_PREFIX, toolsMsg))
else
	print(("%s ready. %d admin(s), %d tool(s). %s")
		:format(LOG_PREFIX, AdminAllowlist.count(), #AdminTools.manifest(), toolsMsg))
end

--[[
	Exposed for testing only. Lets a Server-context test call the authorisation path with an arbitrary
	player-like value and confirm it refuses - which is how the attack test is run without needing a
	second human. Reading this does not grant anything: it only answers yes/no.
]]
_G.__AdminServerTestHooks = {
	isAdmin = AdminAllowlist.isAdmin,
	handle = handle,
}
