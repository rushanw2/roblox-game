# Roblox Development Rules

This project uses **Rojo** and **Luau** (`default.project.json`). Follow these rules for all code and architectural changes.

## 1. Strict Luau Typing
- Always place `--!strict` at the top of every `.luau` file.
- Explicitly type all function parameters and return values.
- Prefer explicit type annotations and exported types (`export type ...`) for shared data structures and module APIs.

## 2. Rojo File & Directory Conventions
Follow the project layout defined in `default.project.json`:
- **Server scripts** (`*.server.luau`): Place in `src/server/` (maps to `ServerScriptService.Server`).
- **Client scripts** (`*.client.luau`): Place in `src/client/` (maps to `StarterPlayer.StarterPlayerScripts.Client`).
- **ModuleScripts** (`*.luau`): Place shared modules in `src/shared/` (maps to `ReplicatedStorage.Shared`). Server-only or client-only helper modules may also live alongside their callers in `src/server/` or `src/client/` as `*.luau` files when not meant for the opposite side.

## 3. Strict Server Authority
- Never trust client input for currency, damage, inventory, progression, cooldowns, or game state changes.
- Treat client remotes (`RemoteEvent` / `RemoteFunction`) strictly as intent requests; validate permissions, ownership, bounds, types, and state entirely on the server before mutating authoritative data or replicating effects.

## 4. Modular Architecture
- Keep systems modular by placing reusable logic in `ModuleScript`s (`*.luau`) rather than cramming everything into `init.server.luau` or `init.client.luau`.
- Entry-point scripts (`src/server/init.server.luau`, `src/client/init.client.luau`) should stay thin—primarily bootstrapping and wiring together dedicated feature/system modules.

## 5. Verification
- After creating, renaming, moving, or editing scripts, verify the Rojo project structure and instance mapping by running:
  ```sh
  rojo sourcemap default.project.json
  ```
