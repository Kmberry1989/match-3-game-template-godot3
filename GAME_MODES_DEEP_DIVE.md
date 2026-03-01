# Game Modes Deep Dive: Meaner Matcher

This document provides an in-depth explanation of the game modes in "Meaner Matcher", detailing their mechanics, win conditions, and code implementation in `Scripts/Grid.gd`.

## 1. Score Mode (`GoalType.SCORE`)
**Goal**: Reach a specific target score.

### Mechanics
- **Standard Gameplay**: Players match 3 or more dots to gain points.
- **Scoring**: Points are accumulated in the `score` variable in `Grid.gd`.
- **Win Condition**: `score >= target_score`.
- **Code Reference**:
    - `setup_objectives()`: Sets `objective_goal_count` to `target_score`.
    - `check_game_over_conditions()`: Checks if `score >= target_score`.
    - `_maybe_trigger_arrest_event()`: Randomly triggers "Meaner's Mischief" (Jailbreak event) *only* in Score mode to add difficulty.

## 2. Down to Earth (`GoalType.DOWN_TO_EARTH`)
**Goal**: Bring specific "Ingredient" items (e.g., acorns) to the bottom of the grid.

### Mechanics
- **Ingredients**: Special dot types that cannot be matched but can be swapped (horizontally only, mostly).
- **Spawning**: Defined in `LevelManager.gd` via `ingredient_positions`.
- **The Chest**: A chest spawns at the bottom center of the screen (`setup_down_to_earth`).
- **Collection**: When an ingredient reaches the bottom row (`height - 1`), it is "collected".
    - `_input()` checks if an ingredient is at `all_dots[mid_col][bottom_row]`.
    - `_play_ingredient_chest()` plays a collection animation and spawns coins.
- **Win Condition**: Collect all ingredients (`objective_goal_count <= 0`).
- **Code Reference**:
    - `setup_down_to_earth()`: Spawns the chest and places ingredients.
    - `_refresh_ready_columns()`: Tracks columns with ingredients.
    - `match_at()` / `can_move_create_match()`: Explicitly block ingredients from matching.

## 3. Jailbreak / Meaner's Mischief (`GoalType.JAILBREAK`)
**Goal**: Free an "arrested" dot or survive the arrest event.

### Mechanics
- **The Arrest**: A specific color is "arrested" (`_trigger_arrest_event`).
    - A siren overlay flashes (`_flash_siren_overlay`).
    - A random dot of that color is chosen as the `_arrested_dot`.
    - It gets a jail overlay and plays a "sad" animation.
- **The Countdown**: `_arrest_stage` counts down (3 -> 2 -> 1 -> 0).
- **Release**: The player must match the arrested dot to free it (`_jailbreak_release`).
- **Win Condition**:
    - In **Score Mode**: It's a mini-event; freeing the dot gives a bonus/achievement.
    - In **Jailbreak Mode**: The level goal is to free the dot. Win if `_arrest_active` is false and `_arrest_stage == 0`.
- **Code Reference**:
    - `_trigger_arrest_event(col)`: Starts the event.
    - `_jailbreak_release()`: Handles the logic when the arrested dot is matched.

## 4. Exterminate / Boss Battle (`GoalType.EXTERMINATE`)
**Goal**: Defeat the Boss (Mister Meaner).

### Mechanics
- **The Boss**: A 2x2 entity (`Scenes/BossMeaner.tscn`) that occupies grid space.
- **Boss Gravity**: The boss falls if the 2x2 area below it is empty (`_input` handles this special gravity).
- **Attacks**: Every 5 moves (`moves_since_boss_attack`), the boss attacks (`_slime_random_dots`), turning dots into slime/removing them.
- **Damage**: The player must drop "Anvils" on the boss.
    - **Anvils**: Spawn periodically (`_spawn_anvil`) at the top of the column above the boss.
    - They fall and hit the boss (`_on_anvil_impact`), dealing damage.
- **Win Condition**: Deplete the boss's health (`objective_goal_count <= 0` via `_on_boss_defeated`).
- **Code Reference**:
    - `setup_exterminate()`: Spawns the boss and clears the 2x2 area.
    - `_spawn_anvil()`: Logic for dropping anvils.
    - `_slime_random_dots()`: The boss's attack mechanic.

## 5. Too Cool (`GoalType.TOO_COOL`)
**Goal**: Match the "Cool Dude" (a dot wearing sunglasses).

### Mechanics
- **Cool Dot**: One random dot is marked as `is_too_cool` and gets a sunglasses overlay (`_spawn_too_cool_dot`).
- **Effect**: Matching the Cool Dot triggers a line clear effect (`_mark_too_cool_lines`), destroying the entire row and column.
- **Win Condition**: Match the Cool Dot (`objective_goal_count <= 0`).
- **Code Reference**:
    - `_spawn_too_cool_dot()`: Selects and marks the dot.
    - `_mark_too_cool_lines(pos)`: Implements the cross-clear powerup effect.

## 6. Avatar Rescue (`GoalType.AVATAR_RESCUE`)
**Status**: **Not Implemented**.
- Defined in `LevelManager.gd` enum but has no logic in `Grid.gd`.
- **Potential Implementation**: Could be similar to Jailbreak but with permanent unlocking of new avatars/skins upon completion.

## 7. Interlevel Bonus Games (Slot + Cognitive Modes)
**Goal**: Add casual bonus play between levels without interrupting core Match-3 progression.

### Trigger Rules
- Compute `completed_level = new_level - 1` in `Grid._on_level_up`.
- Queue `slot_machine` when `completed_level % 3 == 0` (milestone bonus).
- Consume at most one `bonus_games.meter_tokens` token and queue one cognitive game by rotation:
  - `shelf_sort` then `memory_pairs`, repeating.
- Maximum queue size is 2 games per transition (slot + one cognitive game).

### Flow
- `Grid._run_interlevel_bonus_queue()` executes queued games sequentially before `celebrate_stage_transition()`.
- `GameUI.play_bonus_game(game_id)` launches each bonus as a modal overlay on the active `CanvasLayer`.
- Each minigame emits `finished(result)` with payload fields such as:
  - `game_id`, `status`, `skipped`, optional `reward`, optional `reward_applied`.
- On skipped/error results, fallback reward is granted (`coins: 5`).

### Reward Routing
- All minigame rewards pass through `PlayerManager.apply_bonus_reward(reward, reason)`.
- Canonical reward shape:
  - `{"coins": int, "xp": int, "pending_bonus": {...}}`
- `PlayerManager` merges `pending_bonus` cleanly and persists updates.

### Persistent Bonus State
- New `PlayerManager.player_data["bonus_games"]` state:
  - `meter_tokens`
  - `cognitive_cycle_index`
  - `stats.slot`, `stats.shelf_sort`, `stats.memory_pairs`, `stats.skipped`
- Normalized automatically for new/existing saves.

### Minigames
- **Slot Machine** (`Scenes/BonusSlotMachine.tscn`)
  - Existing payout table retained.
  - Explicit `Skip` button added.
  - Emits structured result payload.
- **Shelf Sort** (`Scenes/BonusShelfSort.tscn`)
  - 3 shelves, 9 draggable cards, no timer, hint + skip.
  - Win reward: `coins 30`, `xp 80`, `pending_bonus.clear_rows = 1`.
- **Memory Pairs** (`Scenes/BonusMemoryPairs.tscn`)
  - 12 cards (6 pairs), 2-second preview, no timer, hint + skip.
  - Win reward: `coins 30`, `xp 80`, `pending_bonus.xp_multiplier = {mult: 2, matches: 1}`.
