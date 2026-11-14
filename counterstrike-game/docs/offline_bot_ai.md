# Offline arcade bot AI

The arena bot simulation is local-only. It uses scene physics, a shared map grid and `EventBus` signals; it has no networking, remote inference, telemetry or account dependency.

## Components

- `scripts/ai/arena_bot_brain.gd` is the finite-state decision core. It applies a fair response delay and chooses `PATROL`, `INVESTIGATE`, `ENGAGE`, `DEFEND`, `WAIT` or `RECOVER`; respawn remains a life-cycle state in the bot.
- `scripts/ai/arena_navigation_grid.gd` builds one shared, physics-sampled walkability grid per arena over multiple physics frames. A* searches avoid blocked cells and diagonal corner cutting, cache recent routes, and expose reachable-cell and recovery queries. If the grid is unavailable, each bot retains its local obstacle-steering fallback.
- `scripts/ai/arena_bot_difficulty.gd` holds the Easy, Normal and Hard decision settings. `balanced` is accepted as a legacy save value and normalized to Normal.
- `scripts/ai/arena_bot.gd` owns fictional perception (range plus unobstructed line of sight), local event memory, movement, arcade combat, and the state-specific actions.

## Fairness and Android budget

All difficulties use the same movement speed, sight range, projectile damage and fire cadence. Difficulty changes thinking cadence, target reaction delay, objective preference, pause length and a modest aim-error multiplier. Grid checks are shared and staggered across physics frames; bot perception and path requests are staggered per agent and route caching avoids repeated A* work. Current arena scenes contain four active bot actors including the ally.

## Debugging

Set an `ArenaBot` instance's exported `debug_ai` property to print state transitions and navigation failures. `ArenaBot.get_ai_debug_info()` returns state, difficulty, target visibility/memory, stuck duration and navigation readiness/failure. `ArenaNavigationGrid.get_debug_info()` returns build progress, walkable-cell count, grid size, route-cache size and the latest path failure. Enable `debug_navigation` on the grid to log when the shared grid is ready.

The runtime QA (`scripts/test/ci_runtime_qa.gd`) checks difficulty ordering, reaction timing, defensive/investigation/recovery decisions, grid completion and path validity alongside the existing gameplay checks.
