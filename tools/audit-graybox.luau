--!strict
-- Graybox audit for The Last Tide.
--
-- Run via the Studio MCP (execute_luau, datamodel: Edit) against either place. It reports every
-- placeholder in the live place and diffs it against the registry, so a grey block nobody wrote down
-- gets caught instead of quietly shipping.
--
-- Convention: assets/README.md ("Graybox placeholders")
-- Registry:   assets/registry/assets.yaml  (status: GRAYBOX, represents: <real asset id>)
--
-- KEEP REGISTERED IN SYNC: paste the registry ids into REGISTERED below when you add a graybox.
-- (Luau cannot read the repo, so this list is the one duplication the convention accepts - the audit
-- exists precisely to make the duplication self-correcting: a mismatch is reported, not hidden.)

local CollectionService = game:GetService("CollectionService")

local LOBBY_ID = 91870148721134
local GAME_ID = 100885379547959

-- id -> { represents, place, path }
local REGISTERED: { [string]: { represents: string, place: string, path: string } } = {
	["GB-LOBBY-DOCK"] = {
		represents = "ASSET-LOBBY-HARBOUR-DOCK",
		place = "lobby",
		path = "Workspace.GB_SpawnDock",
	},
}

local TAG = "Graybox"

-- Heuristics for "looks like a placeholder but is not tagged". Deliberately loose: this list is a
-- prompt to go and look, never an assertion.
local IGNORED_CLASSES = { Terrain = true, SpawnLocation = true, Seat = true, VehicleSeat = true }

local function looksLikePlaceholder(inst: Instance): (boolean, string)
	if not inst:IsA("BasePart") or IGNORED_CLASSES[inst.ClassName] then
		return false, "" -- engine-owned or functional, never a stand-in for art
	end
	local part = inst :: BasePart
	local name = part.Name:lower()
	if name:match("^gb[_%-]") then
		return true, "GB_ name prefix"
	end
	if name == "part" or name:match("^part%d*$") or name:match("^block%d*$") then
		return true, "default instance name"
	end
	if part.Material == Enum.Material.SmoothPlastic or part.Material == Enum.Material.Plastic then
		local c = part.Color
		local isGrey = math.abs(c.R - c.G) < 0.04 and math.abs(c.G - c.B) < 0.04
		if isGrey and part.Size.Magnitude > 8 then
			return true, "large untextured grey part"
		end
	end
	return false, ""
end

local placeId = game.PlaceId
local placeName: string
if placeId == GAME_ID then
	placeName = "game"
elseif placeId == LOBBY_ID then
	placeName = "lobby"
else
	return ("UNKNOWN PLACE placeId=%d - update the ids in this script."):format(placeId)
end

local out = { ("GRAYBOX AUDIT - %s place (placeId=%d)"):format(placeName:upper(), placeId), "" }
local tracked, untracked, missing, suspects = 0, 0, 0, 0

-- 1. what is tagged in the place
local seen: { [string]: boolean } = {}
local tagged = CollectionService:GetTagged(TAG)
if #tagged == 0 then
	table.insert(out, "No instances tagged '" .. TAG .. "' in this place.")
else
	for _, inst in ipairs(tagged) do
		-- The registry id is expected as an attribute, falling back to the instance name.
		local id = inst:GetAttribute("GrayboxId")
		local key = typeof(id) == "string" and id or inst.Name
		seen[key] = true
		local reg = REGISTERED[key]
		if reg then
			tracked += 1
			local wrongPlace = reg.place ~= placeName and (" [!] registry says place=" .. reg.place) or ""
			table.insert(out, ("TRACKED    %-22s -> %-26s %s%s"):format(
				key, reg.represents, inst:GetFullName(), wrongPlace))
		else
			untracked += 1
			table.insert(out, ("UNTRACKED  %-22s  NOT IN REGISTRY  %s"):format(key, inst:GetFullName()))
		end
	end
end

-- 2. registered for this place but absent
for id, reg in pairs(REGISTERED) do
	if reg.place == placeName and not seen[id] then
		missing += 1
		table.insert(out, ("MISSING    %-22s registered for %s, not found in the place (expected %s)"):format(
			id, reg.place, reg.path))
	end
end

-- 3. untagged suspects
table.insert(out, "")
for _, inst in ipairs(workspace:GetDescendants()) do
	if not CollectionService:HasTag(inst, TAG) then
		local isSuspect, why = looksLikePlaceholder(inst)
		if isSuspect then
			suspects += 1
			if suspects <= 25 then
				table.insert(out, ("UNTAGGED?  %-40s %s"):format(inst:GetFullName(), why))
			end
		end
	end
end
if suspects > 25 then
	table.insert(out, ("           ... and %d more suspects not listed"):format(suspects - 25))
end
if suspects == 0 then
	table.insert(out, "No untagged placeholder-looking parts found.")
end

table.insert(out, "")
table.insert(out, ("SUMMARY  %d tracked, %d UNTRACKED, %d missing, %d untagged suspects"):format(
	tracked, untracked, missing, suspects))
if untracked > 0 then
	table.insert(out, "-> Add the UNTRACKED ones to assets/registry/assets.yaml with a represents: field,")
	table.insert(out, "   and to REGISTERED in this script. An unregistered graybox is a mystery block.")
end
if missing > 0 then
	table.insert(out, "-> MISSING means the registry is stale, or the placeholder has not been built yet.")
end

return table.concat(out, "\n")
