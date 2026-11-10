package io.github.parsa1012.mirrordash;

import android.content.Context;
import android.media.AudioManager;
import android.media.MediaPlayer;
import android.util.Log;

/** One looping track at a time, owned and called by the activity on the main thread. */
final class MusicPlayer implements AudioManager.OnAudioFocusChangeListener {
    enum Scene { NONE, MENU, GAME }

    private final Context context;
    private final AudioManager audio;
    private MediaPlayer player;
    private Scene scene = Scene.NONE;
    private boolean enabled;
    private boolean foreground;
    private boolean paused;
    private boolean hasFocus;
    private boolean transientLoss;

    MusicPlayer(Context context, boolean enabled) {
        this.context = context.getApplicationContext();
        this.audio = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
        this.enabled = enabled;
    }

    void setScene(Scene next) {
        if (scene != next) {
            releasePlayer();
            scene = next;
            paused = false;
        }
        update();
    }

    void setEnabled(boolean value) {
        enabled = value;
        update();
    }

    void setForeground(boolean value) {
        foreground = value;
        update();
    }

    void setPaused(boolean value) {
        paused = value;
        update();
    }

    @SuppressWarnings("deprecation")
    private void update() {
        if (!enabled || !foreground || paused || scene == Scene.NONE) {
            pausePlayer();
            abandonFocus();
            return;
        }
        if (transientLoss) return;
        if (!hasFocus) {
            if (audio == null || audio.requestAudioFocus(this, AudioManager.STREAM_MUSIC,
                    AudioManager.AUDIOFOCUS_GAIN) != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) return;
            hasFocus = true;
        }
        try {
            if (player == null) {
                player = MediaPlayer.create(context, scene == Scene.MENU
                        ? R.raw.menu_music : R.raw.game_music);
                if (player == null) {
                    abandonFocus();
                    return;
                }
                player.setLooping(true);
                player.setVolume(0.55f, 0.55f);
                player.setOnErrorListener((mp, what, extra) -> {
                    Log.w("TwinBallsMusic", "Playback error " + what + "/" + extra);
                    releasePlayer();
                    abandonFocus();
                    return true;
                });
            }
            if (!player.isPlaying()) player.start();
        } catch (IllegalStateException e) {
            Log.w("TwinBallsMusic", "Could not play music", e);
            releasePlayer();
            abandonFocus();
        }
    }

    private void pausePlayer() {
        if (player != null) {
            try {
                if (player.isPlaying()) player.pause();
            } catch (IllegalStateException e) {
                releasePlayer();
            }
        }
    }

    @SuppressWarnings("deprecation")
    private void abandonFocus() {
        if (hasFocus && audio != null) audio.abandonAudioFocus(this);
        hasFocus = false;
        transientLoss = false;
    }

    private void releasePlayer() {
        if (player != null) {
            player.release();
            player = null;
        }
    }

    @Override
    public void onAudioFocusChange(int change) {
        if (change == AudioManager.AUDIOFOCUS_GAIN) {
            hasFocus = true;
            transientLoss = false;
            update();
        } else if (change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT
                || change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK) {
            transientLoss = true;
            pausePlayer();
        } else if (change == AudioManager.AUDIOFOCUS_LOSS) {
            pausePlayer();
            hasFocus = false;
            transientLoss = false;
        }
    }

    void release() {
        foreground = false;
        releasePlayer();
        abandonFocus();
    }
}
