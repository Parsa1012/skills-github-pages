# Audio assets

Arena ambience (`bgm_arena_ambience.wav`) and the soft movement step (`sfx_step_soft.wav`) are lightweight, original tones/noise synthesized specifically for this game. The existing Kenney-provided audio under `assets/kenney/audio/` is distributed with its accompanying `assets/kenney/LICENSE.md` (MIT). Gameplay audio is routed through `AudioManager`; music and effects use separate persisted settings, and repetitive one-shots are rate-limited.
