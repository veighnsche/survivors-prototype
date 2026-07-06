#!/usr/bin/env bash
# Balance matrix: every build x kiting/standing, headless, one table.
# Usage: ./balance_sim.sh [game-seconds per run]   (default 90)
# death_at = when a 100hp caster would have died; "survived" is the goal.
set -u
T="${1:-90}"
G="/Applications/Godot.app/Contents/MacOS/Godot"
cd "$(dirname "$0")"

printf "%-9s %-6s | %s\n" "BUILD" "MOVE" "RESULT"
printf -- "----------------------------------------------------------------------\n"
for fam in none blast ward drain control sight summon; do
  for move in kite stand; do
    env_args=(SIM=1 SIM_TIME="$T" SIM_SEED="${SEED:-777}")  # fixed seed: rows are comparable
    [ "$fam" != "none" ] && env_args+=(SIM_FAM="$fam")
    [ "$move" = "stand" ] && env_args+=(DBG_STAND=1)
    line=$(env "${env_args[@]}" "$G" --headless res://main.tscn 2>/dev/null | grep "SIM_RESULT" | sed 's/SIM_RESULT //')
    printf "%-9s %-6s | %s\n" "$fam" "$move" "${line:-RUN FAILED}"
  done
done
printf -- "----------------------------------------------------------------------\n"
echo "Red flags: death_at on kite (too hard) · huge kps gaps between builds ·"
echo "'survived' while standing (stand-still cheese) · kps ~0 (build can't kill)."
