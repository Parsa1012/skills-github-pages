package io.github.parsa1012.mirrordash;

import android.graphics.Color;

/**
 * Phase 1 game rules: two bodies mirrored around the vertical centre line.
 * The touch sets a target x, the left body follows it with a smooth lag and the
 * right body is always the exact mirror of the left one.
 */
public class GameEngine {

    /** Time constant of the position smoothing, in seconds. */
    private static final float SMOOTH_TIME = 0.08f;

    private static final float PLAYER_RADIUS_DP = 16f;
    private static final float PLAYER_BOTTOM_OFFSET_DP = 150f;
    private static final float START_PROGRESS = 0.3f;

    private final Player leftPlayer = new Player(Color.parseColor("#22D3EE"));
    private final Player rightPlayer = new Player(Color.parseColor("#F472B6"));

    private int width;
    private int height;
    private float density = 1f;

    private float targetX;
    private boolean touchActive;
    private double elapsedSeconds;

    public Player leftPlayer() {
        return leftPlayer;
    }

    public Player rightPlayer() {
        return rightPlayer;
    }

    public double elapsedSeconds() {
        return elapsedSeconds;
    }

    /** Called on every surface size change (and once at startup). */
    public void resize(int width, int height, float density) {
        boolean firstLayout = this.width == 0;
        this.width = width;
        this.height = height;
        this.density = density;

        float radius = PLAYER_RADIUS_DP * density;
        float y = height - PLAYER_BOTTOM_OFFSET_DP * density;

        leftPlayer.radius = radius;
        rightPlayer.radius = radius;
        leftPlayer.y = y;
        rightPlayer.y = y;

        if (firstLayout) {
            leftPlayer.x = clamp(width * START_PROGRESS, radius, width - radius);
        } else {
            leftPlayer.x = clamp(leftPlayer.x, radius, width - radius);
        }
        leftPlayer.resetTrail();
        rightPlayer.resetTrail();
        syncMirror();
    }

    /** Touch x in pixels. */
    public void setTouchX(float x) {
        if (width <= 0) {
            return;
        }
        touchActive = true;
        targetX = x;
    }

    public void update(double dt) {
        if (width <= 0 || height <= 0) {
            return;
        }
        elapsedSeconds += dt;

        float radius = leftPlayer.radius;
        float minX = radius;
        float maxX = width - radius;
        float goal = touchActive ? clamp(targetX, minX, maxX) : leftPlayer.x;

        // Frame-rate independent exponential smoothing.
        float t = (float) (1.0 - Math.exp(-dt / SMOOTH_TIME));
        leftPlayer.x = clamp(leftPlayer.x + (goal - leftPlayer.x) * t, minX, maxX);

        syncMirror();

        leftPlayer.pushTrail();
        rightPlayer.pushTrail();
    }

    private void syncMirror() {
        rightPlayer.x = width - leftPlayer.x;
    }

    private static float clamp(float value, float min, float max) {
        if (value < min) {
            return min;
        }
        if (value > max) {
            return max;
        }
        return value;
    }
}
