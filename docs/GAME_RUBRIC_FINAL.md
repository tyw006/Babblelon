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
- **Penalty:** All pronunciation and complexity bonuses are negated (set to 0.0) when card is revealed during defense turn

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
- **Penalty:** If card is revealed during defense turn, all pronunciation and complexity bonuses are completely negated (set to 0.0)
- **Result:** Defense becomes ineffective, player takes full damage (100% damage multiplier)

### Defense Calculation
```
IF card revealed during defense turn:
  1. All bonuses = 0.0 (bonuses are negated)
  2. Final Damage Taken = Boss Base Attack × 1.0
ELSE:
  1. Multiplier = 1.0 + Pronunciation Bonus + Gated Complexity Bonus
  2. FinalMultiplier = clamp(Multiplier, 0.1, 1.0)
  3. Final Damage Taken = Boss Base Attack × FinalMultiplier
```

### Defense Examples
- **Card Revealed (New Logic):** Any pronunciation/complexity with card revealed = 1.0 → takes 15 HP damage (full damage)
- **Best Case:** Special Excellent + Level 5 + Not Revealed = clamp(1.0 - 0.7 - 0.2 + 0.0, 0.1, 1.0) = 0.1 → takes 1.5 HP damage
- **Example:** "Okay" regular defense on Level 3 = clamp(1.0 - 0.1 - 0.1, 0.1, 1.0) = 0.8 → takes 12 HP damage

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