#!/usr/bin/env bash
# luau-analyze.sh — run luau-lsp's analyzer over The Last Tide's Luau, using the binary and Roblox type
# defs bundled with the VS Code luau-lsp extension.
#
# WHY THIS EXISTS (job 022): Studio Sync had silently dropped (finding 0007) with a job's worth of code
# written and no way to check any of it. This catches syntax errors and type errors on disk, without
# Studio, in about a second — and it found a malformed string literal that would have failed at require
# time in a Play session, i.e. the slowest possible way to learn about it.
#
# Usage:
#   tools/luau-analyze.sh                       # both places
#   tools/luau-analyze.sh studio_game           # one place
#   tools/luau-analyze.sh path/to/File.luau ... # specific files
#
# ⚠️ EXPECTED NOISE, and do not chase it. There is no Rojo project here (Studio Sync is not Rojo), so
# there is no sourcemap and every cross-module `require` is reported as unknown:
#
#     TypeError: Unknown require: game/ReplicatedStorage/SeaStates
#     TypeError: Key 'Vessel' not found in external type 'ReplicatedStorage'
#     TypeError: Unknown type 'Expedition.Cause'      <- exported types from an unresolved require
#
# Those resolve fine at runtime. Filter them, and compare what is left against the committed version
# before assuming a diagnostic is yours:
#
#     git show HEAD:<file> > /tmp/base.luau && tools/luau-analyze.sh /tmp/base.luau
#
set -uo pipefail
cd "$(dirname "$0")/.."

LSP="$(ls -d "$HOME"/.vscode*/extensions/johnnymorganz.luau-lsp-*/bin/server.exe 2>/dev/null | sort -V | tail -1)"
if [[ -z "${LSP:-}" || ! -f "$LSP" ]]; then
  echo "ERROR: luau-lsp server.exe not found. Install the 'JohnnyMorganz.luau-lsp' VS Code extension." >&2
  exit 2
fi

DEFS="$(ls "$HOME"/AppData/Roaming/Code*/User/globalStorage/johnnymorganz.luau-lsp/globalTypes*.d.luau 2>/dev/null | sort -V | tail -1)"
if [[ -z "${DEFS:-}" || ! -f "$DEFS" ]]; then
  echo "ERROR: globalTypes.d.luau not found. Open a .luau file in VS Code once so the extension downloads it." >&2
  exit 2
fi

TARGETS=("$@")
if [[ ${#TARGETS[@]} -eq 0 ]]; then
  TARGETS=(studio_game studio_lobby)
fi

"$LSP" analyze --defs="$DEFS" --platform=roblox "${TARGETS[@]}" 2>&1 | grep -vE "^\[INFO\]|^\[WARN\]"
exit "${PIPESTATUS[0]}"
