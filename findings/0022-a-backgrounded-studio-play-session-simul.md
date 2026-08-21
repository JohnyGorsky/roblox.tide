# FINDING 0022: A backgrounded Studio Play session simulates but does not render, so RenderStepped code never executes

**Project:** `roblox.tide`
**Status:** open
**Severity:** high
**Created:** 2026-08-21 18:52:50

**Symptom:** Measured in the running client during job 022 validation: over 2 seconds, RunService.Heartbeat fired 120 times and Stepped 121, while RenderStepped fired ZERO. RunService:IsRunning() was true throughout. The Studio window was in the background being driven over MCP, and RenderStepped is tied to rendering, so no frames means no callbacks.

Consequence: every RenderStepped-driven client effect is not merely slow to verify over MCP - it does not run at all, with no error anywhere. The symptom is an effect that looks broken. During job 022 the new compass card sat at Rotation 0 while the hull's heading moved, and it took three experiments to establish that the code was fine and the context was not.

This generalises finding 0012, which recorded the same thing for the Edit datamodel and drew the right conclusion already: prefer Heartbeat for anything that does not strictly need render timing, because it is the half that stays testable.

Confirmed to also affect job 021's HELM loop: faking the local VesselDriver attribute in the client produced no reaction at all (WalkSpeed stayed 16, AutoRotate stayed true, where the loop sets 0 and false). So the vessel cannot be hand-driven over MCP without a focused, rendering Studio window - which is why job 021 needed the VesselTestDrive attribute hook, and why that hook is more load-bearing than it looks.

Fixed for the compass in job 022: moved to Heartbeat. A GUI rotation needs no render-time precision.

NOT fixed for the helm loop. It polls input and was signed off by feel in job 021; changing its timing is a judgement call about input feel, not a mechanical fix. If it is ever moved, the argument is testability rather than correctness - and the counter-argument is that input polling on RenderStepped is the conventional Roblox shape.

Diagnostic recipe worth keeping - run this in the Client datamodel before believing any client-side effect is broken:

  local RunService = game:GetService('RunService')
  local r, h = 0, 0
  local c1 = RunService.RenderStepped:Connect(function() r += 1 end)
  local c2 = RunService.Heartbeat:Connect(function() h += 1 end)
  task.wait(2); c1:Disconnect(); c2:Disconnect()
  print(r, h)  -- 0, ~120 means the window is not rendering
**Where:** studio_game/StarterPlayerScripts/VesselClient.local.luau (helm loop); any RenderStepped-driven client code
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
