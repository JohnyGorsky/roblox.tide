# Job #026: Radar Mk1: a station you stand at, a storm from astern, and circles where something might be

**Project**: `roblox.tide`
**Created**: 2026-08-21 23:05:24
**Status**: Requirements Gathering (intake)

## Requirements / goal

GAME-0002. Design captured in docs/features/0002-radar/feature.md from a concept mockup plus five corrections the user made 2026-08-21. Decisions 0004 (no permanent minimap) and 0019 (the radar owns the storm's number and dies inside The Wall) already govern it.

THE FIVE THINGS THAT DEFINE IT:
1. ON THE BOAT, NOT ON SCREEN - 'someone must watch rada constantly'. A physical station at the vessel spec's existing radar socket, offset (0, 6, 6). This is what makes radar a crew ROLE rather than a HUD element. The mockup's right-hand LIVE CONDITIONS panel therefore cannot be built as drawn - it is screen UI, and those readouts go on the console beside the scope.
2. THE STORM COMES FROM ONE SIDE - an arc across the ASTERN edge that closes inward, never a drifting cell. Lightning.ASTERN_BEARING is 180 and the whole 'a compass is enough to escape' argument rests on the escape direction being constant. Drawn as a wandering blob it would imply the crew could steer around it.
3. IT PINGS LIKE THE REAL THING - contacts refresh only when the beam sweeps over them and decay until the next pass (RULED 2026-08-21). Look away and the picture is genuinely stale, which is what makes 'must watch it constantly' mechanically true. Also makes a faster sweep a meaningful upgrade later. The audible ping needs one sourced sound; nothing in either registry has one.
4. EDGE CIRCLES - small hollow amber circles near the limit of range where something potentially is, resolving into a shaped labelled blip as you close. Confidence falls with distance. This is what gives the crew a reason to steer TOWARDS an unknown rather than only away from the storm.
5. A COLOUR LEGEND ON THE CONSOLE - green island, red storm with a hotter core, amber unknown, blue rings, pale own-ship. Self-lit like the compass (LightInfluence 0) or the one instrument you need at The Wall's brightness of 0.30 is the one you cannot read.

RULED 2026-08-21:
- Range 1,800 studs, as ONE constant so skills later change one number. Roughly a third of the storm's 4,200-stud cushion, so the front appears on the scope well before it is dangerous but not from the start. The mockup's 6.0 km will not fit - the corridor is only 5,500 studs long, so a 6 km scope would see past the end of the world.
- Contacts refresh on sweep and decay between passes.

WHAT MAKES THIS SHIPPABLE NOW: three real contacts already exist, so the contact system ships verified rather than stubbed. The start island (job 024), which RECEDES as the vessel travels north and so demonstrates the edge-circle resolution changing with distance. The four fuel barrels at 200-400 studs (job 023), which sit deep inside the confident radius and demonstrate the identified case. And the tender when it is away from the launch.

It also gives job 022's radar fault teeth for the first time: VesselFault_radar has been published and consumed by nothing, shipped as an honest stub, and lightning already rolls it on close strikes.

Hard constraints:
- Server-authoritative contact registry; the client only draws. A client that could add contacts could reveal the map.
- Decision 0019: the radar dies inside The Wall (StormIntensity 4). The numeric storm readout may show at any distance because 0019 gives the radar that number, but the visual arc only appears once the front is within range.
- Decision 0004: no permanent minimap. This is a station, and nothing about it may migrate to a screen.
- No heading readout anywhere (decision 0014). Bearing to a CONTACT is fine; the vessel's own heading is the compass's job.
- Heartbeat, not RenderStepped (finding 0022).
- Contacts discovered by TAG, never by instance path (finding 0020), so group 04's islands only have to tag themselves.

Out of scope: islands beyond the start island and sea POIs (group 04), nearest shelter (no shelter exists to moor at), named contacts (needs island identity), skills actually changing the range (progression, decisions 0008/0012 - the hook ships, the upgrade does not), and the audible ping asset.

ASSET NEEDED FROM THE USER - one sound, and a searchable spec: a radar/sonar sweep tick plus a contact ping. Short (under 1s), dry, mechanical rather than sci-fi, no reverb baked in, mono. Search terms: 'radar ping', 'sonar ping', 'radar sweep', 'submarine sonar blip'. Free sources per the asset policy: Pixabay or the Creator Store's Pro Sound Effects library. It mounts positionally at the station so it is audible at the radar and not across the deck.

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written
