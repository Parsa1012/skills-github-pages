# Offline Equipment, Collision, and Match Systems

## Equipment data and loadouts

Equipment is authored as `ArenaEquipmentData` resources under `data/equipment/`. Each resource defines a stable ID, one slot (`CORE`, `MOBILITY`, or `UTILITY`), display copy, SVG icon, XP unlock threshold, balance rating, and bounded gameplay modifiers. `EquipmentManager` loads the catalog at startup, validates offline XP unlocks, persists the selected item per slot in `user://arena_settings.cfg`, and supplies a capped modifier dictionary to `PlayerController`. Adding an item is a new resource plus its icon; gameplay code does not need another item-specific branch.

The Arsenal page opens a touch-first loadout overlay with category tabs, scrollable choices, lock/unlock status, item icon, description, and stats. Core values are intentionally small; combined modifiers are capped at +15% health, 10% resistance, +8% movement, and 10–12% cooldown tuning. Gear is fictional arcade support technology; it does not add real-world equipment guidance.

## Collision and debugging

Players and bots use collision layer 2 (`Characters`) and mask 3 (`World | Characters`). Static environment bodies use layer 1 (`World`); objective areas use layer 4 (`Zones`) and monitor character bodies. Character movement continues through `CharacterBody3D.move_and_slide()` on fixed physics ticks. Player round respawns query the world collision space with the player capsule and reject candidates overlapping world geometry, then avoid nearby characters.

In debug builds, use F3 or the on-screen `COLLISIONS OFF/ON` button to toggle a runtime wireframe overlay. The overlay draws supported boxes, capsules, spheres, and cylinders and refreshes moving shapes at a low debug-only rate. It is not instantiated in release builds.

## Offline match state

`GameManager` owns the offline match phase, round index/count, team-round wins, round scores, aggregate scores, round timer, target score, and exactly-once career result persistence. The arena controller submits score awards and handles map-specific objectives; it cannot independently declare or duplicate a match result. Signals communicate round start/end, score, timer, phase transitions, and completion.

The Arena selection page has touch controls for mode-default/60/90/120/180/240-second rounds and one/three/five total rounds. The majority of configured rounds wins; the score target can end a round early, while the centralized timer resolves it at expiry. A two-second between-round break resets player/bot health and spawn state, scores, and capture zones. Match restart resets manager state before loading the selected arena; return-to-menu clears state and unpauses the tree.

## Verification

`scenes/test/ci_runtime_qa.tscn` includes runtime checks for equipment resource/icon data, XP unlock gating, bounded modifiers, three-round transitions, defeat/draw/restart state, Android-sized touch targets, layer/mask setup on both existing maps, collision debug geometry, map obstacle/perimeter movement, and existing pause/restart/menu interactions. The Android workflow performs a Godot import, rendered-scene smoke tests, and the runtime QA suite before export.
