# Combat balance reference

Reference notes from TJ's partner (game balance), added 2026-10-22. Not implemented in Age Three yet.

The code links point to the partner's `arx-combat` Rust prototype (`C:/Projects/arx-combat/src/engine.rs`), which is not on this machine or in this repo.

## 1. Counter bonuses

| Attacking unit | Target units | Damage multiplier |
|---|---|---:|
| Spearmen | Horse archers, lancers, knights, cataphracts | ×2.5 |
| Pikemen | Horse archers, lancers, knights, cataphracts | ×5 |
| Swordsmen | Spearmen, pikemen | ×1.25 |
| Axemen | Swordsmen, men-at-arms | ×2.6 |
| Crossbowmen | Swordsmen, men-at-arms, knights, cataphracts | ×2 |
| Lancers | Archers, longbowmen, crossbowmen | ×2 |
| Knights | Rams, scorpions, ballistae, catapults, trebuchets | ×1.25 |
| Ballistae | Rams, scorpions, ballistae, catapults, trebuchets | ×1.25 |

## 2. What else decides whether a counter works

- **Range:** ranged troops deal half damage beyond half their effective range, full damage closer in, and quarter damage at contact or within a non-ranged opponent's reach. A crossbowman's ×2 counter combined with the ×0.25 contact penalty gives ×0.5 overall.
- **Movement:** troops must reach their opponent, and longer-range troops may get attacks in before the enemy can reply.
- **Target selection:** troops follow targeting rules (section 3); a counter bonus does not make them pick that opponent.
- **Direction:** pikemen dealing extra damage to knights does not reduce the knights' return damage.

The range penalties are in the distance calculation (`arx-combat/src/engine.rs:636`).

**Rams:** normal damage against the five siege types (rams, scorpions, ballistae, catapults, trebuchets), but only 20% damage against every other troop type, including wagons. Walls and defensive structures use separate calculations.

## 3. Targeting

Fixed priorities, mainly set by whether the attacker is ranged or melee. Each troop type acts as one group and normally attacks one enemy group. Only surviving enemies within attack range are considered.

**Ranged troops** (archers, longbowmen, crossbowmen, horse archers, scorpions, ballistae, catapults, trebuchets):

1. Defensive firing structures first: garrison towers and fixed weapons, in their configured priority order.
2. Otherwise, enemy ranged troops: the group with the greatest combined attack power.
3. Otherwise, enemy melee troops: the fastest group. Equal speeds are resolved by combined attack power, then attack per soldier.

**Melee troops** (infantry, melee cavalry, rams):

1. Enemy troops before defensive firing structures.
2. Among troops, the nearest group.
3. If equally near, the group with the greatest combined attack power.
4. If still tied, a ranged group before a melee group, then the highest attack per soldier.

Any remaining tie uses the configured unit order, so the choice is repeatable. Source: targeting code (`arx-combat/src/engine.rs:568`).

## 4. Combined attack power

```
Surviving troops in that group × effective attack per soldier
```

It does not include counter bonuses, enemy armour, enemy life or predicted casualties.

Examples:

- Crossbowmen choose reachable enemy archers ahead of reachable cataphracts, even though they get a damage bonus against cataphracts.
- Pikemen can attack nearby swordsmen while cavalry is still farther away.

Targets are reconsidered as losses change: later friendly groups account for casualties already assigned by earlier attacks. An overwhelming-force exception lets a group clear a very small enemy group and continue to another target in the same turn.

Walls come last, once active defending troops and firing structures are cleared. With the gates closed, defending field troops are excluded from targeting.

So army composition affects both how much damage you deal and which enemies your troops spend their attacks on.
