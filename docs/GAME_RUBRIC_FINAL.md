# Babblelon Game Rubric - Final Version

**Created:** December 19, 2024 at 3:47 PM PST  
**Status:** FINAL - Implementation Complete  
**Version:** 2.0

## Core Game Balance

- **Player HP:** 100
- **Boss HP:** 700
- **Boss Base Attack:** 15
- **Regular Attack Item Base:** 40
- **Special Attack Item Base:** 50

## ATTACK Rubric

### Base Multiplier
- **Base:** 1.0x

### Pronunciation Bonus (Additive)
| Rating | Bonus |
|--------|-------|
| Excellent | +0.6 |
| Good | +0.3 |
| Okay | +0.1 |
| Needs Improvement | 0.0 |

### Gated Complexity Bonus (Additive, if score >= 60)
| Complexity Level | Bonus |
|------------------|-------|
| 1 (Simplest) | +0.0 |
| 2 | +0.15 |
| 3 | +0.3 |
| 4 | +0.45 |
| 5 (Hardest) | +0.6 |

### Card Reveal Penalty
**Attack Turn:**
- **Penalty:** -0.2

**Defense Turn:**
- **Penalty:** Negates pronunciation and complexity bonuses up to a maximum of 20% (adds up to +0.2 to the multiplier). If total bonuses are -15%, the penalty is +15%. If total bonuses are -40%, the penalty is capped at +20%.

### Attack Calculation
```
Final Damage = Base Attack × (1.0 + Pronunciation Bonus + Gated Complexity Bonus - Reveal Penalty)
```

### Attack Examples
- **Worst Case:** Needs Improvement + Complex + Revealed = 40 × (1.0 + 0.0 + 0.0 - 0.2) = 32 damage
- **Best Case:** Excellent + Level 5 + Not Revealed = 40 × (1.0 + 0.6 + 0.6 - 0.0) = 88 damage
- **Example:** "Okay" pronunciation on Level 3 complexity = 40 × (1.0 + 0.1 + 0.3) = 56 damage

## DEFENSE Rubric

### Base Multiplier
- **Base:** 1.0x (represents taking 100% damage)

### Pronunciation Reduction Bonus (Subtractive)
| Rating | Regular Defense | Special Defense |
|--------|----------------|-----------------|
| Excellent | -0.5 | -0.7 |
| Good | -0.3 | -0.5 |
| Okay | -0.1 | -0.25 |
| Needs Improvement | 0.0 | 0.0 |

### Gated Complexity Reduction Bonus (Subtractive, if score >= 60)
| Complexity Level | Bonus |
|------------------|-------|
| 1 (Simplest) | -0.0 |
| 2 | -0.05 |
| 3 | -0.1 |
| 4 | -0.15 |
| 5 (Hardest) | -0.2 |

### Card Reveal Penalty (Defense Turn Only)
- **Penalty:** If the card is revealed during a defense turn, a penalty is applied. This penalty negates the player's pronunciation and complexity bonuses, but the negation is capped at 20% (a +0.2 adjustment).
- **Result:** High defense bonuses are reduced but not completely eliminated, making defense less effective but not entirely useless.

### Defense Calculation
```
IF card revealed during defense turn:
  1. Reveal Penalty = min(-(Pronunciation Bonus + Gated Complexity Bonus), 0.2)
  2. Multiplier = 1.0 + Pronunciation Bonus + Gated Complexity Bonus + Reveal Penalty
  3. FinalMultiplier = clamp(Multiplier, 0.1, 1.0)
  4. Final Damage Taken = Boss Base Attack × FinalMultiplier
ELSE:
  1. Multiplier = 1.0 + Pronunciation Bonus + Gated Complexity Bonus
  2. FinalMultiplier = clamp(Multiplier, 0.1, 1.0)
  3. Final Damage Taken = Boss Base Attack × FinalMultiplier
```

### Defense Examples
- **Card Revealed (Capped):** "Excellent" regular defense (-0.5) + Level 5 complexity (-0.2). Bonuses total -0.7. Penalty = min(0.7, 0.2) = +0.2. Multiplier = clamp(1.0 - 0.5 - 0.2 + 0.2, 0.1, 1.0) = 0.5. Damage = 15 * 0.5 = 7.5 HP.
- **Card Revealed (Full Negation):** "Okay" regular defense (-0.1) + Level 3 complexity (-0.1). Bonuses total -0.2. Penalty = min(0.2, 0.2) = +0.2. Multiplier = clamp(1.0 - 0.1 - 0.1 + 0.2, 0.1, 1.0) = 1.0. Damage = 15 * 1.0 = 15 HP.
- **Best Case (Not Revealed):** Special Excellent (-0.7) + Level 5 (-0.2). Multiplier = clamp(1.0 - 0.7 - 0.2, 0.1, 1.0) = 0.1. Damage = 15 * 0.1 = 1.5 HP.
- **Example (Not Revealed):** "Okay" regular defense (-0.1) on Level 3 (-0.1). Multiplier = clamp(1.0 - 0.1 - 0.1, 0.1, 1.0) = 0.8. Damage = 15 * 0.8 = 12 HP.

## Key Principles

1. **"Needs Improvement" Rule:** Always results in 0.0 bonus/penalty (neutral outcome)
2. **Pronunciation Gating:** Complexity bonuses only apply if pronunciation score >= 60
3. **Defense Clamp:** Final defense multiplier is clamped between 0.1 (10% damage) and 1.0 (100% damage)
4. **No Extra Damage:** Players never take more than 100% of boss base damage
5. **Item Type Matters:** Special items provide better defense bonuses than regular items

## Implementation Notes

- Backend calculations in `backend/services/pronunciation_service.py`
- Frontend models in `lib/models/assessment_model.dart`
- UI display in `lib/screens/boss_fight_screen.dart`
- All formulas are displayed in the flashcard popup for transparency 