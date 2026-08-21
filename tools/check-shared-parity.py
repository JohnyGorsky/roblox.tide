#!/usr/bin/env python3
"""check-shared-parity.py — the two places share source by COPY, so prove the copies match.

Roblox has no cross-place ReplicatedStorage. The Last Tide has two places, so every shared module exists
twice: once under studio_game/ and once under studio_lobby/. There is nothing in the engine, the sync tool
or git that notices when they drift.

WHY THIS EXISTS: during job 022 the lobby's AdminTools fell 12,234 bytes behind the game's and nobody
noticed for a whole job. It was found by accident, by reading a byte count. A silent divergence between two
copies of the same file is exactly the kind of bug that presents as "that tool works in one place and not
the other" and costs an afternoon.

Written in job 025 BEFORE the lobby's atmosphere modules were copied in, rather than after, on the grounds
that the duplication is about to get twelve times worse.

    tools/check-shared-parity.py            # check, and exit non-zero on any mismatch
    tools/check-shared-parity.py --fix      # copy game -> lobby for anything that differs

The game place is the source of truth: it is where the modules are developed and where the storm actually
runs. --fix therefore only ever copies game -> lobby, never the reverse.
"""

import filecmp
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GAME = ROOT / "studio_game"
LOBBY = ROOT / "studio_lobby"

# Files that must be byte-identical in both places, relative to each sync root.
#
# NOT everything is shared. The lobby deliberately has no StormFront: its storm is painted from static
# attributes and never advances, so shipping the clock would be shipping a front that eventually arrives.
SHARED = [
    "ServerStorage/AdminTools.luau",
    "ServerStorage/AdminAllowlist.luau",
    "ServerScriptService/AdminServer.server.luau",
    "StarterPlayerScripts/AdminClient.local.luau",
    # the sea
    "ReplicatedStorage/SeaStates.luau",
    "ReplicatedStorage/WaveField.luau",
    # sky and lighting
    "ReplicatedStorage/SkyLibrary.luau",
    "ReplicatedStorage/LocalWeather.luau",
    "ReplicatedStorage/DayNight.luau",
    # weather and storm visuals
    "ReplicatedStorage/StormVFX.luau",
    "ReplicatedStorage/CloudWallVFX.luau",
    "ReplicatedStorage/Lightning.luau",
    "ReplicatedStorage/LightningVFX.luau",
    # sound
    "ReplicatedStorage/AudioBed.luau",
    "ReplicatedStorage/StormAudio.luau",
    "ReplicatedStorage/Ambience.luau",
    # the client rig and the strike roller are generic - they read attributes and a remote, so both places
    # run the same file. Added in job 025 when the lobby got its atmosphere.
    "StarterPlayerScripts/WeatherClient.local.luau",
    "ServerScriptService/LightningServer.server.luau",
]


def main() -> int:
    fix = "--fix" in sys.argv
    same, differ, missing = [], [], []

    for rel in SHARED:
        g, lo = GAME / rel, LOBBY / rel
        if not g.exists():
            missing.append((rel, "absent from studio_game"))
            continue
        if not lo.exists():
            if fix:
                lo.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(g, lo)
                differ.append((rel, "created in studio_lobby"))
            else:
                missing.append((rel, "absent from studio_lobby"))
            continue
        # shallow=False: compare contents, not size+mtime. A same-size divergence is exactly the case
        # that would slip through, and it is cheap to rule out.
        if filecmp.cmp(g, lo, shallow=False):
            same.append(rel)
        elif fix:
            shutil.copy2(g, lo)
            differ.append((rel, "copied game -> lobby"))
        else:
            differ.append((rel, f"DIFFERS: game {g.stat().st_size} vs lobby {lo.stat().st_size} bytes"))

    for rel, note in missing:
        print(f"MISSING  {rel}  ({note})")
    for rel, note in differ:
        print(f"{'FIXED   ' if fix else 'DIFFERS '} {rel}  ({note})")
    print(f"\n{len(same)} identical, {len(differ)} {'fixed' if fix else 'differing'}, {len(missing)} missing")

    if not fix and (differ or missing):
        print("\nRun with --fix to copy game -> lobby. The game place is the source of truth.")
        return 1
    if missing:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
