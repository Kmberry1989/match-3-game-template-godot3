# Gameplay Improvement Suggestions

Based on a deep analysis of `Grid.gd` and the project structure, here are targeted suggestions to elevate "Meaner Matcher" from a template to a polished game.

## 1. Core Mechanics: "Juice" & Powerups
The current implementation handles basic matches (3) and has a "Sunglasses" board clear, but lacks standard Match-3 depth.

-   **Implement Match-4/5 Powerups**:
    -   **Line Bomb (Match 4)**: Clears a row or column.
    -   **Color Bomb (Match 5)**: Destroys all dots of a specific color.
    -   **Area Bomb (T/L Shape)**: Explodes in a 3x3 radius.
    -   *Implementation*: Modify `find_matches()` to detect shape patterns before destroying dots. Instantiate a special `PowerupDot` instead of just clearing the matched dots.

-   **Combo System**:
    -   Currently, `combo_counter` increases score.
    -   *Suggestion*: Visual feedback for combos (e.g., "Double!", "Triple!" floating text).
    -   *Mechanic*: Higher combos could charge a "Meaner Meter" faster (see below).

## 2. Visual Polish ("Juice")
Match-3 games live or die by how "satisfying" they feel.

-   **Screen Shake**: Add a subtle screen shake when large matches or bombs explode.
-   **Particle Effects**: The `MatchParticles.tscn` exists, but consider adding:
    -   Trail renderers for falling dots.
    -   Explosion effects for powerups.
    -   "Link" effects when dragging to swap.
-   **Animations**:
    -   Add a "bounce" effect when dots land after falling (`Tween.TRANS_BOUNCE`).
    -   Animate the grid background or borders based on the level theme.

## 3. Multiplayer Enhancements
The current multiplayer is passive (score racing).

-   **Attack Mechanics**:
    -   When a player clears a large combo (e.g., 4+ lines), send "Garbage" or "Lock" blocks to the opponent's board.
    -   *Implementation*: `NetworkManager` sends an `attack` event. `Grid.gd` receives it and converts random dots into "Locked" dots that require an adjacent match to break.
-   **Shared Board Mode**:
    -   Instead of two separate boards, have both players manipulate the *same* board in real-time.
    -   *Challenge*: Handling race conditions (server authority required).

## 4. Progression & RPG Elements
You have a `PlayerManager` and `LevelManager`, which is a great foundation.

-   **Unlockable Abilities**:
    -   Allow players to equip 1-2 active skills (e.g., "Hammer": destroy 1 dot, "Shuffle": reshuffle board).
    -   Cooldowns based on moves or matches made.
-   **Decor/Base Building**:
    -   Use the "Coins" to buy cosmetic upgrades for a "Home Base" scene.

## 5. New Game Modes
-   **Time Attack**: Score as much as possible in 60 seconds.
-   **Move Limit Puzzle**: Clear specific "Jelly" tiles (background tiles) within X moves.
-   **Duel**: Turn-based multiplayer where players take turns on the same board (easier to sync than real-time shared board).

## 6. Technical Improvements
-   **Input Handling**: The current `_input` logic relies on physics raycasting (`intersect_point`). For a grid, simple math (`pixel_to_grid`) is often more robust and performant than physics collisions for every click.
-   **Object Pooling**: If you add many particles/projectiles, implement an object pool to avoid constant `instance()` and `queue_free()` calls.
