# GitHub Copilot Instructions for Match-3 Game Template

## Overview
This repository is a Godot-based Match-3 game template that includes a lightweight multiplayer feature using WebSockets. The architecture is designed to facilitate easy integration of gameplay mechanics, UI management, and network communication.

## Big Picture Architecture
- **Scenes**: The main scenes are located in the `Scenes/` directory, including `Game.tscn` for the main gameplay and `GameUI.tscn` for the user interface. Each scene is composed of various nodes that represent game elements.
- **Scripts**: Core gameplay logic is implemented in the `Scripts/` directory. Key scripts include:
  - `Grid.gd`: Manages the game grid, including match detection and state management.
  - `GameUI.gd`: Handles the user interface elements and player information display.
  - `PlayerManager.gd`: Manages player data and interactions.
  - `NetworkManager.gd`: Manages WebSocket connections and multiplayer interactions.

## Developer Workflows
- **Running the Game**: Open `Scenes/Game.tscn` in the Godot editor and press Play (F5) to start the game.
- **Testing Multiplayer**: Run the Node.js server located in `Server/` using `npm install` followed by `npm start`. Ensure the server URL is configured in the project settings.
- **Debugging**: Use the Godot debugger to inspect runtime errors and variable states. Check the output console for WebSocket connection issues.

## Project-Specific Conventions
- **Node Structure**: Use `get_node_or_null()` to safely access nodes, preventing runtime errors if nodes are missing.
- **Signals**: Utilize signals for communication between scripts, such as `game_started` in `NetworkManager.gd` to trigger game start events.
- **Exported Variables**: Use `export` for variables that need to be configurable in the Godot editor, such as grid dimensions and offsets.

## Integration Points
- **WebSocket Communication**: The `NetworkManager.gd` script handles all WebSocket interactions, emitting signals for game state changes and player actions.
- **Player Management**: The `PlayerManager.gd` script maintains player data and communicates with the `AudioManager.gd` for sound effects.
- **Level Management**: The `Grid.gd` script integrates with `LevelManager.gd` to manage level objectives and player progress.

## Examples
- **Creating a New Dot**: In `Grid.gd`, new dots are instantiated from preloaded scenes, ensuring efficient memory usage and quick access.
- **Handling Player Input**: The `GameUI.gd` script updates player information dynamically based on events emitted from the `PlayerManager.gd`.

## Conclusion
This document serves as a guide for AI coding agents to navigate and understand the structure and workflows of the Match-3 game template. For further assistance, refer to the specific scripts and scenes mentioned above.
- Repair obvious identifier typos (`self_modulate` → `modulate`). Example: `Background.gd`.

Risky changes to avoid without confirmation
- Global time API normalization (Time.* → OS.*) — may break compatibility with target Godot version. Ask which Godot version is used before changing.
- Renaming exported properties or scene node names — will break scene references; update scenes accordingly.

Examples to reference when coding
- Spawn and avoid immediate matches: see `Grid.gd` spawn loop which re-rolls a dot if it creates a match (limit 100 tries).
- Dot visuals: `Dot.gd` uses `create_shadow()`, `start_floating()` and `start_pulsing()` to drive continuous visual behavior — create similar patterns for new visual nodes.

If you add or change scenes
- Keep exported property names intact (width, height, offset, y_offset) to preserve scene compatibility.
- When moving or renaming nodes referenced by `get_node()` calls (e.g., `game_ui = get_node("../GameUI")`), update all call sites.

Guidance for Code Review by AI
- Prefer small, local edits. Run the project in Godot after changes to catch API/scene binding issues.
- When changing Time/OS APIs, include a short compatibility note and run the game to validate no static errors appear.

Questions for maintainers
- Which Godot engine version is the canonical target for this project (3.x or 4.x)?

If anything above is unclear or you want more detail (engine version normalization plan, or an automated repo-wide pass for the "safe" edits listed), tell me and I will iterate.
