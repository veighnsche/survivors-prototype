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
project.godot          # Godot project config (main scene, window, autoloads)
scenes/                # main.tscn + main_menu.tscn; everything else is built in code
src/
  autoload/            # Config (global tuning), Fx, Save, Sim, RunLog singletons
  core/                # game.gd (run director), game_camera.gd
  player/              # player.gd (the caster), sim_bot.gd (headless pilot)
  cantrips/            # Cantrip base + ONE FILE PER basic attack (force_bolt, fireball...)
  skills/<family>/     # Skill base + ONE FILE PER card skill (nova, aegis, wisp...)
  families/            # Family base + one file per school (blast, ward, drain...)
  biomes/              # Biome base + one file per region + biome_map.gd (world layout)
  enemies/<biome>/     # Enemy base + ONE FILE PER creature (husk, roc, tunneler...)
  loot/                # xp_gem, gold_coin, chest, Booster base + one file per booster
  combat/              # projectile.gd (generic bolt; cantrips attach their riders)
  world/               # terrain streamers: obstacles, border walls, floor loot, ground
  fx/                  # ring_fx, chain_fx, damage_number, death_pop
  ui/                  # hud, card_screen, attack_panel, affinity_wheel, compass...
  meta/                # upgrades.gd (Vital card pool)
```

Each creature, cantrip, skill, biome, family, and loot object is its own class in
its own file; registries (`EnemyTypes`, `Cantrips`, `Families`, `Biomes`) map ids
to scripts, and the base classes (`Enemy`, `Cantrip`, `Skill`, `Booster`) hold the
shared plumbing. To add an enemy: subclass `Enemy` in `src/enemies/<biome>/`,
register it in `enemy_types.gd`, add it to a biome roster.

> ⚠️ **Tuning:** nearly every gameplay number is a first-pass placeholder. See the issue tracker — balance/feel items are labeled `tuning`.
