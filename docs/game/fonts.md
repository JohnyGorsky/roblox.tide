# Typography / Font Direction

## Goal

Typography should feel **maritime, military, industrial and readable**, not playful/cartoonish.

## Recommended style families

Use Roblox-supported fonts available in the current project/runtime. Claude must verify actual available font faces in Studio before implementation.

### 1. Primary UI / body

Use a clean geometric sans-serif with high readability.

Desired character:
- neutral
- compact
- modern
- readable on mobile
- good at small sizes

Use for:
- inventory
- interaction prompts
- settings
- status panels
- descriptions

### 2. Instrument / radar font

Use a compact technical/monospace-like face where available.

Desired character:
- military electronics
- radar terminal
- numeric clarity

Use for:
- radar labels
- coordinates
- speed
- fuel
- system warnings
- generator values

Examples of treatment:

```text
RADAR MK II
RANGE 1.8 KM
CONTACT: UNKNOWN
BEARING 047
```

Prefer uppercase and slightly increased letter spacing.

### 3. Display/title font

Use a heavier condensed or industrial face for:
- game title
- major sea-stage cards
- boss/event names
- large warnings

Avoid using it for paragraphs.

## Hierarchy

### Major title
- heavy/condensed
- uppercase
- large
- minimal effects

### Section / system label
- uppercase
- medium weight
- slight letter spacing

### Body
- sentence case
- normal weight

### Instrument value
- monospaced/technical treatment
- strong number contrast

## Color usage

- default UI text: pale grey/off-white
- muted labels: Fog Grey `#8C9AA3`
- active radar: Radar Green `#52FF9A`
- warning: Warning Amber `#F2B544`
- critical: Danger Red `#D94B4B`

## Effects

Avoid:
- thick cartoon outlines
- rainbow gradients
- excessive glow

Allow:
- subtle shadow for readability
- restrained radar glow
- small distressed treatment for title art only

## Rule

Typography must support the atmosphere but never reduce gameplay readability.
