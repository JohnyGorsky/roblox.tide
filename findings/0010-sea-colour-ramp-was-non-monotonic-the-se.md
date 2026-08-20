# FINDING 0010: Sea colour ramp was non-monotonic - the sea brightened as it worsened

**Project:** `roblox.tide`
**Status:** fixed (2026-08-20) — Fixed in job 012. Choppy moved off Storm Teal (luminance 0.309, the lightest of the ocean colours and actually a shallow-water colour) onto an intermediate blue 15,42,58, and The Wall onto 8,20,30. The ramp now falls monotonically: 0.185, 0.185, 0.147, 0.106, 0.071 - verified by computing luminance per state. visual-design.md now lists the ocean colours darkest-first with measured luminances and an explicit warning that a colour's NAME is not a guide to where it belongs on a brightness ramp, which is what allowed the mistake.
**Severity:** med
**Created:** 2026-08-20 13:18:00

**Symptom:** Caught by screenshotting Dead Calm and Choppy back to back: Choppy looked LIGHTER and flatter than Dead Calm, which is the opposite of the intended progression. Confirmed numerically by computing luminance of each state's water colour: 0.185, 0.185, 0.309, 0.106, 0.106 - Choppy spiked to 0.309. Cause: Choppy used Storm Teal, which despite its name is the LIGHTEST of the three ocean palette colours (Abyss Navy 0.106, Deep Ocean 0.185, Storm Teal 0.309). Storm Teal belongs to shallow sheltered water - it is what the harbour correctly uses - not to a worsening sea. Fixed by giving Choppy an intermediate blue (15,42,58) and The Wall a colour darker than Abyss Navy (8,20,30), so the ramp now falls monotonically. Lesson worth keeping: a palette colour's NAME is not a reliable guide to where it belongs on a brightness ramp; compute the luminances when building any progression. The visual-design doc lists the ocean colours without saying which end of the ramp each belongs to, which is what allowed the mistake.
**Where:** _TODO: file / system_
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
