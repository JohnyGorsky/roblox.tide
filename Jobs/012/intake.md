# Job #012: Wave field: HeightAt / NormalAt for the sea surface

**Project**: `roblox.tide`
**Created**: 2026-08-20 12:19:51
**Status**: Requirements Gathering (intake)

## Requirements / goal

Group 01 job 2, and the first P0 task under the agreed order (sea, then atmosphere, then boat). Build the shared deterministic function that answers how high the sea is at a point and which way the surface tilts, so the vessel, debris, spray and wake all sample one definition instead of guessing. Feature GAME-0014. Roblox terrain water waves are a rendering effect that moves nothing, so the sea has two independent truths - the visual swell the player watches and the physical swell that moves the boat - and if they disagree the hull visibly climbs crests that are not there. SeaStates already carries a per-state wave block for exactly this reason; this job consumes it. Hard requirements: deterministic from a synchronised clock (Workspace:GetServerTimeNow) so server and clients agree with zero replication traffic; driven by the active sea state so all five feel different; smooth on a state change so nothing gets launched or submerged; cheap enough for 8-12 samples per frame; safe outside the ocean extent. Includes the calibration step that must not be skipped - measure the apparent amplitude and wavelength of the RENDERED water per state and fit the field to it, recording the measured numbers as comments, because the visual wave shape cannot be changed and so the maths must be fitted to the visuals rather than the reverse. Two known mismatches to decide rather than discover: terrain water has no controllable wave direction while ours does, and choppiness/directionSpread have no visual counterpart at all so they can only ever be felt through the boat. Out of scope: buoyancy and any force application - that is GAME-0001. Deliverable includes a debug grid of markers that sit on the sampled surface, screenshotted in all five states, since markers that float or sink are the proof that the field and the visuals disagree.

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written
