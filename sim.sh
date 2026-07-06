#!/usr/bin/env bash
# Bounded single sim that CANNOT hang: hard OS-level timeout (perl alarm) wraps
# the in-engine wall cap, so a script error that stops the game from loading
# still returns control. Prints the key log lines, nothing else.
#
# Usage: ./sim.sh [SECONDS] [KEY=VAL ...]   e.g. ./sim.sh 15 SIM_BIOME=wilds SIM_FAM=control
set -u
WALL="${1:-15}"; shift || true
HARD=$((WALL + 12))
G="/Applications/Godot.app/Contents/MacOS/Godot"
cd "$(dirname "$0")"
perl -e 'alarm shift; exec @ARGV' "$HARD" \
  env SIM=1 SIM_TIME=999 SIM_WALL_MAX="$WALL" SIM_SEED="${SIM_SEED:-777}" "$@" \
  "$G" --headless res://main.tscn 2>&1 \
  | grep -viE "Godot Engine|Metal|Vulkan|ApplePersistence|^$" \
  | grep -E "SCRIPT ERROR|Parse Error|SIM_RESULT|threat_by|basic_casts|kills_by|insight_from|damage_by_type|WARDEN" \
  || echo "(no output — likely a load error above the grep, run raw to see)"
