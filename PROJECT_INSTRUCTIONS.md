# Project Overview: Meaner Matcher (Godot Match-3)

This document demonstrates my understanding of the "Meaner Matcher" project, a Match-3 game template built in Godot 3.5+.

## 1. Core Identity
- **Engine**: Godot 3.x (GLES2, Mobile-friendly).
- **Genre**: Match-3 Puzzle Game with RPG and Multiplayer elements.
- **Resolution**: 540x960 (Portrait).
- **Backend**: Node.js WebSocket server for lobby-based multiplayer.

## 2. Key Architecture

### Autoloads (Singletons)
The project relies heavily on Autoloads defined in `project.godot`:
- **`PlayerManager`**: Manages persistent user data (level, coins).
- **`NetworkManager`**: Handles low-level WebSocket communication.
- **`LevelManager`**: Central repository for level configurations and goals.
- **`AudioManager`**: Centralized audio control.
- **`Firebase`**: Integration for Auth and Database (via addon).

### Core Scripts
- **`Scripts/Grid.gd`**: The brain of the game. It handles:
    - **State Machine**: `wait` (animations/matching) vs `move` (input allowed).
    - **Match Logic**: Detecting horizontal/vertical matches, destroying dots, collapsing columns, and refilling.
    - **Input Handling**: Drag-and-drop swapping logic.
    - **Level Goals**: Logic for specific modes like `DOWN_TO_EARTH` (ingredients), `JAILBREAK` (freeing dots), and `EXTERMINATE` (boss battles).
- **`Scripts/Game.gd`**: The main game loop controller. It initializes the game, plays music, and handles global events like trophy unlocks.
- **`Scripts/NetworkManager.gd`**: Manages the WebSocket client. It handles connection states, signals (game start, score updates), and message parsing.

## 3. Game Mechanics

### The Grid
- The grid is a 2D array of Dot nodes.
- **Matching**: Matches of 3 or more trigger `destroy_matches()`.
- **Gravity**: `collapse_columns()` moves dots down into empty spaces.
- **Spawning**: `refill_columns()` creates new dots at the top.

### Game Modes (Level Goals)
Defined in `LevelManager.gd` and implemented in `Grid.gd`:
1.  **Score**: Standard target score.
2.  **Down to Earth**: Move specific "Ingredient" items to the bottom row.
3.  **Jailbreak**: "Meaner's Mischief" - free arrested dots.
4.  **Exterminate**: Boss battle mechanics (2x2 boss entity).
5.  **Too Cool**: Clear specific "cool" dots.

## 4. Multiplayer System
- **Architecture**: Client-Server using WebSockets.
- **Server**: Node.js server (`Server/server.js`) handles matchmaking and room creation.
- **Flow**:
    1.  Client connects via `NetworkManager`.
    2.  Lobby (`Scenes/Menu.tscn`) allows creating/joining rooms.
    3.  Server pairs players and sends `game_started` with a random seed.
    4.  **Synchronization**: Currently focuses on score updates (`opponent_score_updated`). Board state is local but seeded deterministically.

## 5. Directory Structure
- **`Scenes/`**: All `.tscn` files (UI, Game, Dots).
- **`Scripts/`**: All `.gd` logic files.
- **`Server/`**: Node.js backend code.
- **`addons/`**: Plugins (Godot Firebase, SimpleMultiplayer).
- **`Assets/`**: Sprites, Audio, Fonts.

## 6. How to Run
1.  **Client**: Open `project.godot` in Godot 3.x and run.
2.  **Server**: Navigate to `Server/`, run `npm install` then `npm start`.
3.  **Multiplayer**: Run two instances of the client to test matchmaking.
