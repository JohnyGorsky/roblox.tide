# Roadmap

## Stage 1 — Movement foundation
- generic Vessel foundation
- starter boat controller
- multiplayer authority
- basic ocean
- horizontal wrap
- camera

## Stage 2 — Core survival
- hull health/leaks
- repair
- fuel
- storage
- basic loot

## Stage 3 — Navigation
- radar Mk1
- POI contacts
- simple nautical chart
- logical sea progression
- **intro loading screen, per place** — todo 0009. Removes Roblox's default screen, preloads behind a
  progress bar, and holds for a beat *after* preload so texture streaming and lighting resolve behind it
  rather than popping in front of the player
- **in-transit teleport screen** — todo 0009. `TeleportService:SetTeleportGui`. The departure flow is a
  reserved-server teleport (Planned 0002), and a teleport with no screen is a black gap. Copy the shape from
  the Jungle game, which has both halves already

## Stage 4 — Time/weather
- day/dusk/night
- storm front
- rain/wind/lightning
- wave response

## Stage 5 — Threats
- shark
- pirate boat
- boarding
- first supernatural event

## Stage 6 — In-run vessel progression
- engine/hull/fuel
- generator
- radar levels
- lights
- hardpoints

## Stage 7 — Content library
- curated islands
- wrecks
- encounters
- rare POIs

## Stage 8 — Permanent progression
- ship parts/components
- Shipyard
- starting-vessel upgrades
- larger vessel projects
- deeper departure points

## Stage 9 — NPC crew
- basic crew roles
- station assignment
- task animation reuse
- simple order system
- crew progression later

## Stage 10 — Larger vessels
- Patrol Boat
- Trawler / Research Vessel
- Cutter
- sectional damage/interiors later

## Stage 11 — Meta progression and retention
- expedition results
- discoveries
- role mastery
- NPC crew development
- difficulty layers

## Stage 12 — Monetization/cosmetics
Only after the core loop and retention are proven.
