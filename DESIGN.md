# Design — working title TBD

A horde-survivor where **you start as nothing and the procedural world teaches you what to become.**
No weapons, no classes. You wander a patchwork of biomes; each biome's threats teach the magic
that counters them. Your path + your play carve you into a corner of a six-school Affinity Wheel.

> Status: **design locked, not yet built.** The current code still has the (to-be-removed) weapon
> system. Next engineering step is the teardown + tabula-rasa base.

## Core loop
Tabula rasa → wander → the random environment throws a specific threat at you → fighting it drops
**essence** that **unlocks** the family which counters that threat → **casting** that family deepens
it → biomes resist their own school, so an over-specialized build hits a wall and must adapt. Where
you walked = who you became.

## Two progression currencies
- **XP gems** (any enemy) → **Character level** → generic body stats (HP, cast speed, move, pickup). The neutral floor that keeps any build alive.
- **Essence** (colored to a biome's family) → fills that **family's Insight** → thresholds **unlock** then **tier up** its spells. Casting a family also trickles Insight in ("environment seeds, use deepens"). Essence is biome-locked, so **build = biomes visited.**

The **Affinity Wheel** (repurposed from the old weapon radar) shows each family's Insight as fill toward its colored corner.

## Biomes (organic noise blobs; the Commons surrounds spawn)
| Biome | Color | Threat (behavior) | Teaches | Resists / weak to |
|-------|-------|-------------------|---------|-------------------|
| The Commons | `#E2493B` red | Brawlers (melee rush) | Blast | weak to Blast |
| Thornreach | `#E0A02E` amber | Skirmishers (ranged kite) | Ward | resist ranged · weak to burst-close |
| The Wilds | `#3FCDE0` cyan | Beasts (fast packs) | Control | evasive · weak to slow/charm |
| The Barrows | `#6FB03A` green | Brutes (armored tanks) | Drain | resist burst · weak to DoT/drain |
| Cragspire | `#4C8DF0` blue | Flyers (divers) | Sight | elusive · weak to precision |
| The Hollow | `#9A54E4` violet | Swarmers (endless tide) | Summon | overwhelm · weak to zones |

Color does triple duty: the biome you see from afar, the essence it drops, its corner on the wheel.

## Families (each a viable solo build; all auto-cast and accumulate)
- **Blast** (artillery) — Arcane Bolt, Fireburst (AoE), Nova. Arcane dmg, rarely resisted.
- **Ward** (bulwark) — Aegis (shield), Deflect (bounce projectiles), Thorns (reflect). Reflected dmg.
- **Control** (puppeteer) — Frost Pulse (slow→freeze→shatter), Dread (fear), Charm. Shatter/frost.
- **Drain** (leech) — Siphon (lifesteal), Rot (DoT aura), Wither (armor-strip curse). Necrotic DoT.
- **Summon** (warlord) — Raise (slain enemies become minions), Familiar (pet), Hexfield (zones). Physical.
- **Sight** (seer) — True Bolt (homing crit), Foresight (dodge), Mark (+dmg taken). Precise/crit.

## Adaptation teeth (locked: yes, resistances)
Each biome's enemies resist their own family's damage and are weak to another's. An over-specialized
wheel meets a biome that punishes it → diversify (feed another biome's essence) or route around.
There's always an out: the neutral cantrip's arcane damage, and you can leave any biome.

## Balance approach
The system is largely **self-balancing**: the threat that endangers you also teaches its counter, so
you're never under-equipped for long (built-in dynamic difficulty). Real levers: the **learning lag**
(gap between meeting a threat and having its counter) vs the **threat ramp**, plus the Vital floor.
Guardrails against dead emergent builds: every family self-sufficient, synergies are bonuses not
requirements, Vital track guarantees baseline power.

**Method:** extend the existing sim into a **build-viability tester** — a bot follows different
threat-paths ("always chase brutes", "random wander"); every path must land in a viable survival band.
You can't hand-tune emergent builds, so you simulate paths.

## Tabula rasa start
One neutral cantrip — a weak **Force Bolt** (auto-fires nearest, arcane damage) — so you can fight
before any family unlocks.

## v1 scope
3 families / 3 biomes to prove the whole loop: **Blast (Commons)**, **Ward (Thornreach)**,
**Drain (Barrows)** — damage / defense / sustain, maximally distinct, most reuse of existing code.
Build order: (1) teardown weapons + tabula-rasa base, (2) biomes + essence + Affinity Wheel,
(3) the 3 families' spells + unlock/deepen, (4) resistances.
