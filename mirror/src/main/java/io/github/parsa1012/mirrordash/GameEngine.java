package io.github.parsa1012.mirrordash;

import android.graphics.Color;

import java.util.ArrayList;
import java.util.List;
import java.util.Random;

/**
 * Game rules.
 *
 * <p>Two bodies are mirrored around the vertical centre line: the left one follows the
 * touch input with a short smoothing lag, the right one is always {@code width - left}.
 * Rows of hazards scroll down; a row only allows the pair to survive inside a narrow
 * x-window, and every row is generated so that window exists and is reachable from the
 * previous row's window. That is what makes the difficulty fair instead of random.</p>
 */
public class GameEngine {

    /** Time constant of the position smoothing, in seconds. */
    private static final float SMOOTH_TIME = 0.08f;

    private static final float PLAYER_RADIUS_DP = 16f;
    private static final float PLAYER_BOTTOM_OFFSET_DP = 150f;
    private static final float START_PROGRESS = 0.3f;

    /** Collision radius is a little smaller than the drawn one so deaths feel fair. */
    private static final float COLLISION_FORGIVENESS = 0.85f;

    private static final float FIRST_ROW_DELAY_SECONDS = 0.6f;
    private static final int MAX_ROWS = 10;
    private static final int MAX_SPAWN_ATTEMPTS = 48;
    private static final int BREATHER_EVERY_ROWS = 7;

    private static final int POINTS_PER_SECOND = 10;
    private static final int POINTS_PER_ROW = 5;

    private final Player leftPlayer = new Player(Color.parseColor("#22D3EE"));
    private final Player rightPlayer = new Player(Color.parseColor("#F472B6"));

    private final List<ObstacleRow> rows = new ArrayList<>(MAX_ROWS);
    private final Random random = new Random();

    private int width;
    private int height;
    private float density = 1f;

    private float targetX;
    private boolean touchActive;

    private double elapsedSeconds;
    private double runSeconds;
    private float distanceSinceSpawn;
    private int rowsCleared;
    private int rowsSinceBreather;
    private float lastWindowCenter = -1f;

    private int score;
    private boolean gameOver;
    private boolean justDied;
    private boolean initialised;

    public Player leftPlayer() {
        return leftPlayer;
    }

    public Player rightPlayer() {
        return rightPlayer;
    }

    public List<ObstacleRow> rows() {
        return rows;
    }

    public int score() {
        return score;
    }

    public boolean isGameOver() {
        return gameOver;
    }

    public float level() {
        return LevelConfig.levelOf(rowsCleared);
    }

    public int rowsCleared() {
        return rowsCleared;
    }

    /** Returns true exactly once after the run ended, so the UI can show its overlay. */
    public boolean consumeJustDied() {
        if (!justDied) {
            return false;
        }
        justDied = false;
        return true;
    }

    /** Called on every surface size change and once at startup. */
    public void resize(int width, int height, float density) {
        this.width = width;
        this.height = height;
        this.density = density;

        float radius = PLAYER_RADIUS_DP * density;
        float y = height - PLAYER_BOTTOM_OFFSET_DP * density;
        leftPlayer.radius = radius;
        rightPlayer.radius = radius;
        leftPlayer.y = y;
        rightPlayer.y = y;

        if (!initialised) {
            initialised = true;
            restart();
        } else {
            leftPlayer.x = clamp(leftPlayer.x, radius, width - radius);
            rightPlayer.x = width - leftPlayer.x;
        }
    }

    /** Resets the run and generates a fresh seed. */
    public void restart() {
        random.setSeed(System.nanoTime());
        rows.clear();
        rowsCleared = 0;
        rowsSinceBreather = 0;
        runSeconds = 0.0;
        score = 0;
        gameOver = false;
        justDied = false;
        lastWindowCenter = -1f;
        touchActive = false;

        if (width > 0) {
            float radius = leftPlayer.radius > 0 ? leftPlayer.radius : PLAYER_RADIUS_DP * density;
            leftPlayer.x = clamp(width * START_PROGRESS, radius, width - radius);
            rightPlayer.x = width - leftPlayer.x;
        }
        leftPlayer.resetTrail();
        rightPlayer.resetTrail();

        float speed = LevelConfig.rowSpeed(density, 1f);
        float spacing = LevelConfig.rowSpacing(density, 1f);
        distanceSinceSpawn = spacing - speed * FIRST_ROW_DELAY_SECONDS;
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
        if (gameOver) {
            return;
        }

        runSeconds += dt;
        float level = level();
        float speed = LevelConfig.rowSpeed(density, level);
        float spacing = LevelConfig.rowSpacing(density, level);

        updatePlayers(dt);
        moveRows(dt, speed);
        maybeSpawn(dt, speed, spacing, level);

        if (collides()) {
            gameOver = true;
            justDied = true;
        }
        score = computeScore();
    }

    private void updatePlayers(double dt) {
        float radius = leftPlayer.radius;
        float minX = radius;
        float maxX = width - radius;
        float goal = touchActive ? clamp(targetX, minX, maxX) : leftPlayer.x;

        // Frame-rate independent exponential smoothing.
        float t = (float) (1.0 - Math.exp(-dt / SMOOTH_TIME));
        leftPlayer.x = clamp(leftPlayer.x + (goal - leftPlayer.x) * t, minX, maxX);
        rightPlayer.x = width - leftPlayer.x;

        leftPlayer.pushTrail();
        rightPlayer.pushTrail();
    }

    private void moveRows(double dt, float speed) {
        for (int i = rows.size() - 1; i >= 0; i--) {
            ObstacleRow row = rows.get(i);
            row.y += speed * dt;
            row.updateWave(elapsedSeconds);

            if (!row.scored && row.y > leftPlayer.y + leftPlayer.radius) {
                row.scored = true;
                rowsCleared++;
            }
            if (row.y > height + row.height) {
                rows.remove(i);
            }
        }
    }

    private void maybeSpawn(double dt, float speed, float spacing, float level) {
        distanceSinceSpawn += speed * dt;
        if (rows.size() >= MAX_ROWS || distanceSinceSpawn < spacing) {
            return;
        }
        distanceSinceSpawn = 0f;
        spawnRow(level);
    }

    // ---------------------------------------------------------------- generation

    private void spawnRow(float level) {
        ObstacleRow row = new ObstacleRow();
        row.begin(-LevelConfig.rowHeight(density), LevelConfig.rowHeight(density));

        boolean breather = rowsSinceBreather >= BREATHER_EVERY_ROWS || lastWindowCenter < 0f;
        boolean wantsTwoGaps = !breather && random.nextFloat() < LevelConfig.twoGapChance(level);

        boolean built;
        if (breather) {
            built = trySingleGap(row, level) || tryEasyMirror(row, level);
            rowsSinceBreather = 0;
        } else if (wantsTwoGaps) {
            built = tryTwoGaps(row, level);
        } else {
            built = trySingleGap(row, level) || tryTwoGaps(row, level);
        }

        if (!built && !tryEasyMirror(row, level)) {
            buildFallback(row, level);
        }
        if (!breather) {
            rowsSinceBreather++;
        }

        rows.add(row);
        lastWindowCenter = row.windowCenter;
    }

    /**
     * A row with one opening: both bodies have to share it, so the only feasible position
     * is the screen centre. That makes it the natural "breather" row.
     */
    private boolean trySingleGap(ObstacleRow row, float level) {
        float gapWidth = LevelConfig.singleGapWidth(density, level);
        float minWindow = LevelConfig.minWindow(density);
        float margin = LevelConfig.EDGE_MARGIN_DP * density;
        if (gapWidth >= width - 2f * margin) {
            return false;
        }
        float maxOffset = Math.max(0f, (gapWidth - minWindow) * 0.5f);
        float maxJump = LevelConfig.maxJump(width, level);
        float windowCenter = width * 0.5f;
        float anchor = lastWindowCenter < 0f ? windowCenter : lastWindowCenter;

        if (Math.abs(windowCenter - anchor) > maxJump) {
            return false;
        }
        for (int attempt = 0; attempt < MAX_SPAWN_ATTEMPTS; attempt++) {
            float center = windowCenter + (random.nextFloat() * 2f - 1f) * maxOffset;
            float windowWidth = gapWidth - Math.abs(2f * center - width);
            if (windowWidth < minWindow) {
                continue;
            }
            row.begin(-row.height, row.height);
            row.setGap(0, center, gapWidth);
            row.windowCenter = windowCenter;
            row.windowWidth = windowWidth;
            return true;
        }
        return false;
    }

    /**
     * The main row type: two openings whose centres are almost mirrored. The gap between
     * the "almost" is the mistake budget the player has to split between the two bodies.
     */
    private boolean tryTwoGaps(ObstacleRow row, float level) {
        float gapWidth = LevelConfig.gapWidth(density, level);
        float minWindow = LevelConfig.minWindow(density);
        float margin = LevelConfig.EDGE_MARGIN_DP * density;
        float amplitude = LevelConfig.waveAmplitude(density);
        float inset = gapWidth * 0.5f + margin + amplitude;
        if (inset * 2f >= width) {
            return false;
        }
        float maxMismatch = Math.min(LevelConfig.maxMismatch(density, level), gapWidth - minWindow);
        float maxJump = LevelConfig.maxJump(width, level);
        float movingMinWindow = LevelConfig.movingMinWindow(density);
        float movingChance = LevelConfig.movingChance(level);

        for (int attempt = 0; attempt < MAX_SPAWN_ATTEMPTS; attempt++) {
            float first = inset + random.nextFloat() * (width - 2f * inset);
            float error = (random.nextFloat() * 2f - 1f) * maxMismatch;
            float second = width - first + error;
            if (second < inset || second > width - inset) {
                continue;
            }
            float windowWidth = gapWidth - Math.abs(error);
            if (windowWidth < minWindow) {
                continue;
            }
            float windowCenter = first - error * 0.5f;
            float anchor = lastWindowCenter < 0f ? width * 0.5f : lastWindowCenter;
            if (Math.abs(windowCenter - anchor) > maxJump) {
                continue;
            }

            row.begin(-row.height, row.height);
            row.setGap(0, first, gapWidth);
            row.setGap(1, second, gapWidth);
            row.windowCenter = windowCenter;
            row.windowWidth = windowWidth;
            if (windowWidth >= movingMinWindow && random.nextFloat() < movingChance) {
                row.enableWave(amplitude, LevelConfig.WAVE_PERIOD_SECONDS,
                        random.nextFloat() * 6.2831855f);
            }
            return true;
        }
        return false;
    }

    /** Perfectly mirrored gaps: the widest possible safe window, always fair. */
    private boolean tryEasyMirror(ObstacleRow row, float level) {
        float gapWidth = LevelConfig.gapWidth(density, level);
        float margin = LevelConfig.EDGE_MARGIN_DP * density;
        float half = gapWidth * 0.5f + margin;
        if (half * 2f >= width) {
            return false;
        }
        float anchor = lastWindowCenter < 0f ? width * 0.5f : lastWindowCenter;
        float center = clamp(anchor, half, width - half);

        row.begin(-row.height, row.height);
        row.setGap(0, center, gapWidth);
        row.setGap(1, width - center, gapWidth);
        row.windowCenter = center;
        row.windowWidth = gapWidth;
        return true;
    }

    private void buildFallback(ObstacleRow row, float level) {
        float gapWidth = LevelConfig.singleGapWidth(density, level);
        float half = Math.min(gapWidth * 0.5f, width * 0.5f);
        float anchor = lastWindowCenter < 0f ? width * 0.5f : lastWindowCenter;
        float center = clamp(anchor, half, width - half);

        row.begin(-row.height, row.height);
        row.setGap(0, center, gapWidth);
        row.setGap(1, width - center, gapWidth);
        row.windowCenter = center;
        row.windowWidth = gapWidth;
    }

    // ------------------------------------------------------------------ collision

    private boolean collides() {
        float radius = leftPlayer.radius * COLLISION_FORGIVENESS;
        float playerTop = leftPlayer.y - radius;
        float playerBottom = leftPlayer.y + radius;

        for (int i = 0; i < rows.size(); i++) {
            ObstacleRow row = rows.get(i);
            float top = row.y;
            float bottom = row.y + row.height;
            if (bottom < playerTop || top > playerBottom) {
                continue;
            }
            int segments = row.segments(width);
            for (int s = 0; s < segments; s++) {
                float left = row.segmentEdges[s * 2];
                float right = row.segmentEdges[s * 2 + 1];
                if (circleHitsRect(leftPlayer.x, leftPlayer.y, radius, left, top, right, bottom)
                        || circleHitsRect(rightPlayer.x, rightPlayer.y, radius, left, top, right, bottom)) {
                    return true;
                }
            }
        }
        return false;
    }

    /**
     * Classic closest-point circle/rectangle test: clamp the centre to the rectangle and
     * compare the squared distance with the squared radius.
     */
    private static boolean circleHitsRect(float cx, float cy, float radius,
                                          float left, float top, float right, float bottom) {
        float closestX = clamp(cx, left, right);
        float closestY = clamp(cy, top, bottom);
        float dx = cx - closestX;
        float dy = cy - closestY;
        return dx * dx + dy * dy <= radius * radius;
    }

    private int computeScore() {
        return (int) (runSeconds * POINTS_PER_SECOND) + rowsCleared * POINTS_PER_ROW;
    }

    private static float clamp(float value, float min, float max) {
        if (value < min) {
            return min;
        }
        return value > max ? max : value;
    }
}
