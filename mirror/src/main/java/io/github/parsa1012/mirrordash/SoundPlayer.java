package io.github.parsa1012.mirrordash;

import android.content.Context;
import android.media.AudioAttributes;
import android.media.SoundPool;

/**
 * Two short feedback sounds loaded into a SoundPool. Both WAV files are synthesised by
 * {@code tools/generate_sounds.py}; together they are about 22 KB.
 */
public class SoundPlayer {

    private final SoundPool pool;
    private final int tickId;
    private final int crashId;
    private volatile boolean enabled = true;
    private volatile float volume = 1f;

    public SoundPlayer(Context context) {
        AudioAttributes attributes = new AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_GAME)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build();
        pool = new SoundPool.Builder()
                .setMaxStreams(4)
                .setAudioAttributes(attributes)
                .build();
        tickId = pool.load(context, R.raw.tick, 1);
        crashId = pool.load(context, R.raw.crash, 1);
    }

    public void setEnabled(boolean enabled) {
        this.enabled = enabled;
    }

    public void setVolume(int percent) { volume = Math.max(0, Math.min(100, percent)) / 100f; }

    public boolean isEnabled() {
        return enabled;
    }

    public void playTick() {
        if (enabled) {
            pool.play(tickId, 0.35f * volume, 0.35f * volume, 1, 0, 1f);
        }
    }

    public void playCrash() {
        if (enabled) {
            pool.play(crashId, 0.9f * volume, 0.9f * volume, 2, 0, 1f);
        }
    }

    public void release() {
        pool.release();
    }
}
