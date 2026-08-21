# TODO 0008: Read socket positions from the authored hull model instead of spec offsets

**Project:** `roblox.tide`
**Status:** open
**Created:** 2026-08-21 20:06:48

Decided 2026-08-21: once the real ship model exists, the user places every fitting in Studio's editor and code only finds them. Today Vessel.build CREATES the Sockets attachments from spec.sockets Vector3 offsets and welds a box per fitting - scaffolding, registered as graybox GB-STARTER-LAUNCH.

The migration is small because the consumer side is already right: VesselServer looks every socket up by NAME (hull.Sockets.helm, damageControl). So the change is one rule - read the attachments the model already carries, and do not add a second positioning path. After it, spec.sockets declares only which sockets a class HAS (name + kind), with offsets surviving as a fallback for a hull with no authored attachments.

Do NOT do this before the real hull exists; there is nothing to read from yet, and refining the current offsets is wasted work.

Two traps for whoever does it: finding 0021 (the spec labels +Z as the bow while the hull drives toward -Z, so authored positions will mean what the artist saw), and the survives_the_restyle block on GB-STARTER-LAUNCH in assets/registry/assets.yaml - several compass properties look like styling and are decisions 0014/0023.

Physics stays derived from stated intent (draft, cruise, rudderLag, survivability) per decision 0009. This is about placement, not tuning.
