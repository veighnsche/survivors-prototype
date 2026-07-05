# Survivors Prototype (Godot 4)

A work-in-progress **bullet-heaven / horde-survivor** game (Vampire Survivors / Halls of Torment / Death Must Die genre), built in **Godot 4.7 / GDScript**.

Placeholder art (drawn primitives) for now — sprite pass via a local ComfyUI pipeline is planned.

## Status

| Milestone | Scope | State |
|-----------|-------|-------|
| **M1 — Core Loop** | Centered player + scrolling world, auto-attack (nearest-target), enemy flood on an escalating timeline, contact damage, HP/death, infinite field | ✅ Done |
| **M2 — Progression** | XP gems (3 tiers) + idle-timer proximity merging, accelerating XP curve, hard-pause level-up, 3-card choice with Reroll/Banish, rarity weighting, first ability fork (Orbiting Blades ⟷ Damage Aura) with lockout | ✅ Done |
| **M3 — Depth** | Treasure chests + pickups (HP/magnet/bomb), weapon evolutions & synergies, expanded upgrade tree | ⏳ Planned |
| **Art pass** | Replace primitives with ComfyUI-generated sprites | ⏳ Planned |

## Design decisions locked so far

- **Camera:** player centered, world scrolls
- **Attack:** automatic, auto-targets nearest enemy (projectile)
- **Arena:** infinite open field (enemies recycle when far behind)
- **Gems:** 3 tiers (small 1 / med 5 / large 25 XP), fuse when left idle near each other; pickup-radius vacuum, **no** level-up vacuum
- **Level-up:** hard pause, 3 cards, Reroll (×3) + Banish (×2)
- **Classes:** none fixed — build emerges from upgrade choices; some picks lock out alternatives (medium-aggression forks)

## Run it

```bash
# macOS (Godot.app installed):
/Applications/Godot.app/Contents/MacOS/Godot --path .
# or open the folder in the Godot editor and press Play
```

**Controls:** WASD / arrows / left stick to move · attack is automatic · on level-up: `1`/`2`/`3` pick, `Q` reroll, `E` banish · `R` restarts after death.

## Project layout

```
project.godot        # Godot project config (main scene, window, input)
main.tscn            # Root scene (Node2D + game.gd); everything else is built in code
scripts/
  game.gd            # Run director: world, spawn timeline, gems+merging, XP/leveling, card flow
  player.gd          # Movement, auto-attack, contact damage, fork abilities
  enemy.gd           # Stat-driven beeline chaser
  projectile.gd      # Straight auto-attack shot
  gem.gd             # XP drop: idle/merge/attract/collect
  upgrades.gd        # Upgrade pool definitions (id/rarity/max/locks)
  card_screen.gd     # Level-up choice UI (runs while paused)
  background_grid.gd # Scrolling grid so motion reads on the empty field
  hud.gd             # XP bar, timer, HP, counts, death overlay
```

> ⚠️ **Tuning:** nearly every gameplay number is a first-pass placeholder. See the issue tracker — balance/feel items are labeled `tuning`.
