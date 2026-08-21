# TODO 0005: Consider adding steering to lightning's fault pool

**Project:** `roblox.tide`
**Status:** open
**Created:** 2026-08-21 09:18:09

LightningServer's FAULTS list is { radar, generator, lights } and job 022 now consumes it. VesselDamage has a steering fault (rudder authority to 45%) that only the admin panel can currently inflict, and its own comment calls it a lightning-and-collision fault. Adding it to the pool would give it a natural source. Held back deliberately: the pool and FAULT_CHANCE are job 018's tuning, and a strike that hampers escape inside The Wall changes the 30-60s survival target that job 022 measured. Needs a judgement call on balance, ideally after the survival test has been run a few times with the current pool.
