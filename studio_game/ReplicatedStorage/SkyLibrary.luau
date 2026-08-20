--!strict
--[[
	SkyLibrary - the skies, as DATA.

	A Sky is six image ids and a handful of flags, so it is defined here in code rather than kept as
	instances in the place file. That means the whole set is version-controlled, diffable, and syncs like
	everything else - where a folder of Sky objects in ServerStorage would live only inside the .rbxl,
	invisible to git and impossible to review.

	Feature: docs/features/0011-sea-states/  ·  sourced in job 015
	Registry: assets/registry/assets.yaml

	--------------------------------------------------------------------------------------------------
	WHY THESE EXIST AT ALL

	Job 007 established that neither Fog nor Atmosphere can make Roblox's clear-day sky overcast: at
	Atmosphere Density 0.98 and Haze 4.5 the sky stayed bright blue. The sky is the dominant term in how
	the sea reads, so the cold-ocean art direction was simply unreachable without real sky art. This is
	that art.

	--------------------------------------------------------------------------------------------------
	PROVENANCE AND SAFETY

	All seven came from the free Creator Store, were inserted into an isolated ServerStorage quarantine,
	and were scanned for scripts before anything ran: ZERO LuaSourceContainers across all seven. The
	`Snow Skybox` asset also shipped Bloom, Blur and ColorCorrection effects, which were discarded - they
	would have trampled the lighting the sea states set.

	Free Creator Store assets are licensed for use **inside Roblox only**. We do not own them and must not
	re-use them outside Roblox.
]]

local Lighting = game:GetService("Lighting")

local SkyLibrary = {}

export type SkyDef = {
	id: string,
	label: string,
	up: string,
	dn: string,
	ft: string,
	bk: string,
	lf: string,
	rt: string,
	--[[
		Celestial bodies OFF is the default here, deliberately.

		An overcast sky with a sharp sun disc punched through it reads as broken - and a visible sun is
		most of what made the default sky feel like a holiday. Only skies that genuinely want a sun or
		moon should set this true.
	]]
	celestial: boolean,
	stars: number,
	sunSize: number,
	moonSize: number,
	source: string, -- creator + asset id, for the registry
	intent: string, -- what it is for
}

local function def(t: any): SkyDef
	t.celestial = if t.celestial == nil then false else t.celestial
	t.stars = t.stars or 0
	t.sunSize = t.sunSize or 0
	t.moonSize = t.moonSize or 0
	return t :: SkyDef
end

SkyLibrary.Skies = {
	SunlessBlue = def({
		id = "SunlessBlue",
		label = "Sunless Blue",
		up = "rbxassetid://591059642",
		dn = "rbxassetid://591059876",
		ft = "rbxassetid://591058104",
		bk = "rbxassetid://591058823",
		lf = "rbxassetid://591057861",
		rt = "rbxassetid://591057625",
		source = "Creator Store, free — Yourius, asset 591067775",
		intent = "Calm cold day. No sun disc: the original had celestial bodies on, turned off here.",
	}),

	SnowGrey = def({
		id = "SnowGrey",
		label = "Snow Grey (flat overcast)",
		up = "http://www.roblox.com/asset/?id=155674931",
		dn = "http://www.roblox.com/asset/?id=155674246",
		ft = "http://www.roblox.com/asset/?id=155657609",
		bk = "http://www.roblox.com/asset/?id=155657655",
		lf = "http://www.roblox.com/asset/?id=155657671",
		rt = "http://www.roblox.com/asset/?id=155657619",
		source = "Creator Store, free — DovysCleveri, asset 4604073339",
		intent = "The flattest grey available free. Authored for snow, borrowed for overcast working sea.",
	}),

	FogOnWater = def({
		id = "FogOnWater",
		label = "Fog on Water",
		up = "rbxassetid://15876639348",
		dn = "rbxassetid://15876592775",
		ft = "rbxassetid://15876640231",
		bk = "rbxassetid://15876597103",
		lf = "rbxassetid://15876638420",
		rt = "rbxassetid://15876595486",
		source = "Creator Store, free — Plasmaking0531, asset 15876671760",
		intent = "The most on-brief find: fog sitting on water. Choppy and closing-in weather.",
	}),

	AngryHeavens = def({
		id = "AngryHeavens",
		label = "Angry Heavens (storm)",
		up = "rbxassetid://2670915561",
		dn = "rbxassetid://2670916127",
		ft = "rbxassetid://2670915733",
		bk = "rbxassetid://2670915907",
		lf = "rbxassetid://2670916224",
		rt = "rbxassetid://2670916026",
		source = "Creator Store, free — alexutzu2001, asset 2670935816",
		intent = "Dark storm clouds. The Storm state.",
	}),

	BlackVoid = def({
		id = "BlackVoid",
		label = "Black Void (The Wall)",
		up = "http://www.roblox.com/asset/?id=156311666",
		dn = "http://www.roblox.com/asset/?id=156311666",
		ft = "http://www.roblox.com/asset/?id=156311666",
		bk = "http://www.roblox.com/asset/?id=156311666",
		lf = "http://www.roblox.com/asset/?id=156311666",
		rt = "http://www.roblox.com/asset/?id=156311666",
		source = "Creator Store, free — LuckyTux, asset 582303304",
		intent = "One black image on all six faces. Not scenery - a void, so The Wall's 330-stud fog has nothing behind it.",
	}),

	NightFog = def({
		id = "NightFog",
		label = "Night Fog",
		up = "rbxassetid://1370717782",
		dn = "rbxassetid://1370717336",
		ft = "rbxassetid://1370717438",
		bk = "rbxassetid://1370717244",
		lf = "rbxassetid://1370717567",
		rt = "rbxassetid://1370717698",
		source = "Creator Store, free — empIoyer, asset 1864839162",
		intent = "Night. For the day/night cycle (group 07), not a sea state.",
	}),

	ClassicRoblox = def({
		id = "ClassicRoblox",
		label = "Classic Roblox (fallback)",
		up = "rbxasset://sky/null_plainsky512_up.jpg",
		dn = "rbxasset://sky/null_plainsky512_dn.jpg",
		ft = "rbxasset://sky/null_plainsky512_ft.jpg",
		bk = "rbxasset://sky/null_plainsky512_bk.jpg",
		lf = "rbxasset://sky/null_plainsky512_lf.jpg",
		rt = "rbxasset://sky/null_plainsky512_rt.jpg",
		celestial = true,
		stars = 3000,
		sunSize = 21,
		moonSize = 11,
		source = "Engine built-in (rbxasset://), via Vallorum asset 339406852",
		intent = "Fallback. Engine-shipped files, so it needs no asset at all and cannot be moderated away.",
	}),
}

SkyLibrary.Order = {
	"SunlessBlue", "SnowGrey", "FogOnWater", "AngryHeavens", "BlackVoid", "NightFog", "ClassicRoblox",
}

function SkyLibrary.get(id: string): SkyDef?
	return (SkyLibrary.Skies :: any)[id]
end

--[[
	Apply a sky by id.

	Reuses one Sky instance named "Sky" rather than destroying and recreating it: swapping the six
	ContentIds on an existing Sky avoids a frame of no-sky, and avoids piling up orphans if this is called
	repeatedly from a slider.

	Pass nil to remove the sky entirely, which falls back to Roblox's procedural gradient.
]]
function SkyLibrary.apply(id: string?): (boolean, string)
	local existing = Lighting:FindFirstChildOfClass("Sky")

	if id == nil then
		if existing then
			existing:Destroy()
		end
		return true, "sky removed - procedural gradient"
	end

	local d = SkyLibrary.get(id)
	if not d then
		return false, ("unknown sky %q"):format(tostring(id))
	end

	local sky = existing
	if not sky then
		sky = Instance.new("Sky")
		sky.Name = "Sky"
		sky.Parent = Lighting
	end
	local s = sky :: Sky
	s.SkyboxUp = d.up
	s.SkyboxDn = d.dn
	s.SkyboxFt = d.ft
	s.SkyboxBk = d.bk
	s.SkyboxLf = d.lf
	s.SkyboxRt = d.rt
	s.CelestialBodiesShown = d.celestial
	s.StarCount = d.stars
	s.SunAngularSize = d.sunSize
	s.MoonAngularSize = d.moonSize
	s:SetAttribute("SkyId", d.id)
	return true, ("%s — %s"):format(d.label, d.intent)
end

--- Which sky is currently applied, if we set it.
function SkyLibrary.current(): string?
	local sky = Lighting:FindFirstChildOfClass("Sky")
	local id = sky and sky:GetAttribute("SkyId")
	return typeof(id) == "string" and id or nil
end

return SkyLibrary
