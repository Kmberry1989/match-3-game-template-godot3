# AI Guide: Meaner Matcher (Godot Match-3 Project)

This document serves as a comprehensive guide to the "Meaner Matcher" project, a Match-3 game built with Godot 3.5+ and a Node.js WebSocket server. It details the architecture, core mechanics, and instructions for future expansion.

## 1. Project Overview

-   **Engine**: Godot 3.x (GLES2, Mobile-friendly)
-   **Genre**: Match-3 Puzzle Game with RPG/Multiplayer elements.
-   **Resolution**: 540x960 (Portrait).
-   **Backend**: Node.js WebSocket server (`ws` library) for simple lobby-based multiplayer.
-   **Key Features**:
    -   Classic Match-3 gameplay.
    -   Special Game Modes: Score, Down to Earth (Ingredients), Jailbreak (Meaner's Mischief), Exterminate (Boss Battle), Too Cool.
    -   Real-time Multiplayer (Co-op/Versus foundations).
    -   Firebase Integration (Auth, Database, Firestore - via `godot-firebase` addon).

## 2. Architecture & File Structure

### Core Directories
-   `Scenes/`: Contains all `.tscn` files.
    -   `Login.tscn`: Entry point. Handles authentication.
    -   `Menu.tscn`: Main menu.
    -   `Game.tscn`: The main game container.
    -   `GameUI.tscn`: HUD and UI overlays.
    -   `MultiplayerLobby.tscn`: Lobby for creating/joining rooms.
-   `Scripts/`: GDScript logic.
    -   `Grid.gd`: **THE CORE LOGIC**. Handles the board, input, matches, and game modes.
    -   `Game.gd`: Main game loop, audio, and achievement handling.
    -   `NetworkManager.gd`: Handles WebSocket signals and state.
    -   `PlayerManager.gd`: Autoload for player data (coins, level, etc.).
-   `Server/`: Node.js backend.
    -   `server.js`: Handles matchmaking, rooms, and signaling.
-   `addons/`:
    -   `godot-firebase`: Firebase SDK.
    -   `SimpleMultiplayer`: Custom multiplayer helper.

### Autoloads (Global Singletons)
Defined in `project.godot`:
1.  `Firebase`: Godot Firebase wrapper.
2.  `PlayerManager`: Manages user profile and persistence.
3.  `NetworkManager`: Handles low-level networking.
4.  `AudioManager`: Plays music and SFX.
5.  `SaveManager`: Local save data handling.
6.  `WebsocketClient` / `MultiplayerManager`: From SimpleMultiplayer addon.
7.  `LevelManager`: Loads level data and configurations.

## 3. Core Mechanics (`Grid.gd`)

The `Grid.gd` script is the heart of the game. It manages the 2D array of dots and the state machine.

### State Machine
-   `wait`: Input blocked (animations playing, matching occurring).
-   `move`: Input allowed (player can drag/swap).

### Match Logic
-   `match_at(i, j, color)`: Checks for horizontal and vertical matches of 3+.
-   `find_matches()`: Scans the entire grid.
-   `destroy_matches()`: Removes matched dots and triggers effects.
-   `collapse_columns()`: Makes dots fall into empty spaces.
-   `refill_columns()`: Spawns new dots at the top.

### Special Modes (Level Goals)
1.  **Score**: Reach a target score (`target_score`).
2.  **Down to Earth**: Bring ingredients (acorns, etc.) to the bottom row.
    -   Logic: `setup_down_to_earth()`, `_refresh_ready_columns()`.
3.  **Jailbreak (Meaner's Mischief)**: Free arrested dots.
    -   Logic: `_trigger_arrest_event()`, `_apply_arrest_overlay_if_needed()`.
4.  **Exterminate (Boss)**: Defeat a boss (2x2 tile entity).
    -   Logic: `setup_exterminate()`, `_on_boss_defeated()`, `_spawn_anvil()`.
5.  **Too Cool**: Clear dots wearing sunglasses.
    -   Logic: `_spawn_too_cool_dot()`, `_mark_too_cool_lines()`.

## 4. Multiplayer Architecture

### Client (`NetworkManager.gd`)
-   Connects to `ws://<server>:9090`.
-   Signals: `game_started`, `opponent_score_updated`, `waiting_for_opponent`.
-   Sends score updates via `send_score_update(score)`.

### Server (`server.js`)
-   **Matchmaking**: `find_match` adds players to a queue. Pairs them up and creates a room.
-   **Rooms**: Identified by 4-char codes.
-   **Synchronization**: Broadcasts `start_game` with a `seed` to ensure deterministic RNG on both clients (though `Grid.gd` needs to explicitly use this seed).

## 5. Expansion Guide

### How to Add a New Level
1.  Modify `Scripts/LevelManager.gd` (or the JSON/Resource file it loads).
2.  Define the level data:
    ```json
    {
      "goal_type": 0, // 0=Score, 1=DownToEarth, 2=Jailbreak, 3=Exterminate, 4=TooCool
      "target_score": 5000,
      "moves": 20,
      "ingredient_positions": [[3, 5]], // For DownToEarth
      "boss_health": 50 // For Exterminate
    }
    ```

### How to Add a New Powerup
1.  Create a new scene in `Scenes/Dots/` (e.g., `BombDot.tscn`).
2.  Update `Scripts/Grid.gd`:
    -   Add logic to `_on_dot_match_faded` or `destroy_matches` to trigger the powerup effect.
    -   Example: If `dot.type == "bomb"`, call `explode_area(grid_pos)`.

### How to Add a New Game Mode
1.  Add a new enum to `LevelManager.gd`: `GoalType.NEW_MODE`.
2.  Update `Grid.gd`:
    -   In `_ready()` or `setup_objectives()`, handle the initialization.
    -   Add a check function (e.g., `check_new_mode_win()`) called during `_on_dot_match_faded`.

### How to Improve Multiplayer
1.  **State Sync**: Currently, it mostly syncs scores. To sync the board:
    -   Server: Relay move commands (`swap: {x1, y1, x2, y2}`).
    -   Client: When receiving a swap command, execute it on the local grid.
    -   **Important**: Ensure `randomize()` is seeded with the server-provided seed.

## 6. Common Issues / Gotchas
-   **Z-Index**: Dots use `z_index` based on row to handle overlapping fall animations. `Grid.gd` manages this in `_verify_render_logic()`.
-   **Input**: Input is handled in `Grid._input`. It uses `_get_closest_dot_to_cursor()` which relies on physics collision shapes. Ensure Dot scenes have `Area2D` and `CollisionShape2D`.
-   **Async**: Many grid actions use `yield(timer, "timeout")`. Be careful with race conditions if animations overlap.

## 7. Future Tasks
-   [ ] Implement proper board synchronization for multiplayer (Shared Board vs. Split Screen).
-   [ ] Add "Daily Challenge" using Firebase Remote Config.
-   [ ] Polish the "Boss Battle" mechanics (animations, more attack types).
-   [ ] Refactor `Grid.gd` (currently 2300+ lines) into smaller components (e.g., `MatchController`, `InputController`).
