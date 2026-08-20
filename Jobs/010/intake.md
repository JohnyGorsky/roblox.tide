# Job #010: Give the lobby water and remove both baseplates

**Project**: `roblox.tide`
**Created**: 2026-08-20 10:17:28
**Status**: Requirements Gathering (intake)

## Requirements / goal

The game place already has its ocean; the lobby is still a bare baseplate. Make the lobby a sheltered harbour water body per docs/systems/places (calm water, visibly not the open sea), remove the default baseplate, and keep fog inside the water so no edge shows - the lobby currently has FogEnd 5000, which would reveal the edge of any water smaller than that. Because the lobby has CharacterAutoLoads true, deleting its baseplate would drop every joining player into the sea, so a temporary spawn dock is needed. Build that dock as a REGISTERED GRAYBOX - tagged in Studio, entered in assets.yaml with a represents field - which also exercises the graybox register end to end for the first time, the one verification item left open from job 005.

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written
