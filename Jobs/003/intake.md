# Job #003: Align the sync layout with what Studio Sync actually does

**Project**: `roblox.tide`
**Created**: 2026-08-19 22:41:19
**Status**: Requirements Gathering (intake)

## Requirements / goal

MCP-verified sync probes proved the job 002 layout wrong. Evidence: a probe written to studio_game/StarterPlayerScripts/ arrived as StarterPlayer.StarterPlayerScripts, while the same probe in studio_game/StarterPlayer/StarterPlayerScripts/ never arrived - Studio Sync uses a FLAT layout at the sync root, not Rojo's nested StarterPlayer/ form. This also explains the two folders logged as stray in finding 0000: Studio Sync created them itself, so they are canonical and the nested ones I created are the dead ones. Further findings: ServerScriptService receives nothing (three probes failed to arrive there) while ReplicatedStorage and StarterPlayerScripts sync fine, so the sync scope is partial; a plain .luau becomes a ModuleScript and .client.luau becomes a Script with RunContext=Client, while .module.luau is not a recognised suffix and keeps the literal name '_ProbeD.module'; deletions propagate correctly. The lobby place is NOT synced at all - its probe never arrived. Work: flatten the layout in both sync roots, fix the two Rojo project files and .jobconfig.json, record the verified script-naming conventions and the partial scope in docs/systems/places/README.md, update the tide-project skill, and close finding 0000 with the real explanation.

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written
