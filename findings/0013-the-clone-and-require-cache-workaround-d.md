# FINDING 0013: The clone-and-require cache workaround does not cover a module's DEPENDENCIES, so a fresh clone can still load stale code

**Project:** `roblox.tide`
**Status:** open
**Severity:** med
**Created:** 2026-08-20 15:13:37

**Symptom:** Known already: Studio's Edit-session require cache serves the previously-required result for a ModuleScript that Studio Sync edited IN PLACE (the instance is reused, so its cache entry survives). The established workaround is to clone the ModuleScript and require the clone. What bit us in job 018 is that this only bypasses the cache for the module being cloned - the clone still resolves its own dependencies through ReplicatedStorage:WaitForChild, which returns the REAL instance and therefore the STALE cached require. Symptom: a freshly cloned LocalWeather threw 'attempt to call a nil value' on SeaStates.currentBlended, a function that plainly existed in the synced source. Workaround that does work: clone EVERY module in the dependency graph under a suffixed name, and gsub each clone's Source to rewrite its WaitForChild/FindFirstChild calls to the suffixed copies. Non-destructive, and it makes the whole graph fresh. Worth wrapping in a shared test helper rather than rewriting per test.
**Where:** MCP execute_luau, Edit datamodel - the clone-and-require workaround
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
