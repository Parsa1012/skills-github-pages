package io.github.parsa1012.mirrordash;

/**
 * Base tuning table for the difficulty curve. {@link Difficulty} scales these numbers, and
 * the row pattern (together / apart) is produced by {@link GameEngine}.
 *
 * <p>Every gameplay number lives here so balancing never requires touching the engine.
 * The tables describe levels 1..5; past level 5 the values keep moving linearly with
 * {@code perLevel} steps until they hit a hard bound. Values are in dp and multiplied
 * by the display density on the way out.</p>
 */
public final class LevelConfig {

    /** Rows cleared per difficulty level. */
    public static final int ROWS_PER_LEVEL = 6;

    private static final float[] SPEED_DP = {190f, 240f, 290f, 340f, 390f};
    private static final float[] SPACING_DP = {300f, 280f, 260f, 240f, 220f};
    private static final float[] GAP_DP = {96f, 92f, 88f, 84f, 80f};

    private static final float SPEED_PER_LEVEL_DP = 50f;
    private static final float SPACING_PER_LEVEL_DP = -15f;
    private static final float GAP_PER_LEVEL_DP = -3f;

    private static final float SPEED_CAP_DP = 470f;
    private static final float SPACING_FLOOR_DP = 230f;
    private static final float GAP_FLOOR_DP = 78f;

    /** Geometry shared by every row. */
    public static final float ROW_HEIGHT_DP = 28f;
    public static final float SINGLE_GAP_EXTRA_DP = 46f;
    public static final float MIN_WINDOW_DP = 34f;
    public static final float MOVING_ROW_MIN_WINDOW_DP = 44f;
    public static final float WAVE_AMPLITUDE_DP = 22f;
    public static final float WAVE_PERIOD_SECONDS = 2.4f;
    public static final float EDGE_MARGIN_DP = 6f;
    /** Solid pieces thinner than this look like rendering noise, so the generator avoids them. */
    public static final float MIN_SLIVER_DP = 14f;

    private LevelConfig() {
    }

    /** Continuous difficulty level, e.g. 2.375 after 11 cleared rows. */
    public static float levelOf(int rowsCleared) {
        return 1f + rowsCleared / (float) ROWS_PER_LEVEL;
    }

    public static float rowSpeed(float density, float level) {
        return sample(SPEED_DP, level, SPEED_PER_LEVEL_DP, SPEED_CAP_DP, true) * density;
    }

    public static float rowSpacing(float density, float level) {
        return sample(SPACING_DP, level, SPACING_PER_LEVEL_DP, SPACING_FLOOR_DP, false) * density;
    }

    public static float gapWidth(float density, float level) {
        return sample(GAP_DP, level, GAP_PER_LEVEL_DP, GAP_FLOOR_DP, false) * density;
    }

    public static float rowHeight(float density) {
        return ROW_HEIGHT_DP * density;
    }

    public static float singleGapWidth(float density, float level) {
        return gapWidth(density, level) + SINGLE_GAP_EXTRA_DP * density;
    }

    public static float minWindow(float density) {
        return MIN_WINDOW_DP * density;
    }

    public static float minSliver(float density) {
        return MIN_SLIVER_DP * density;
    }

    public static float movingMinWindow(float density) {
        return MOVING_ROW_MIN_WINDOW_DP * density;
    }

    public static float waveAmplitude(float density) {
        return WAVE_AMPLITUDE_DP * density;
    }

    /**
     * How far the two gaps of a row may be off from a perfect mirror. A larger mismatch
     * means a narrower safe position for the player, so it grows with the level.
     */
    public static float maxMismatch(float density, float level) {
        float budget = gapWidth(density, level) - minWindow(density);
        if (budget <= 0f) {
            return 0f;
        }
        return budget * (0.35f + 0.65f * clamp01((level - 1f) / 5f));
    }

    /** Chance that a row's gaps slide sideways. Introduced at level 4. */
    public static float movingChance(float level) {
        if (level < 4f) {
            return 0f;
        }
        return Math.min(0.28f, 0.12f * (level - 3f));
    }

    public static float clamp01(float value) {
        if (value < 0f) {
            return 0f;
        }
        return value > 1f ? 1f : value;
    }

    private static float sample(float[] table, float level, float perLevel, float bound, boolean cap) {
        int last = table.length - 1;
        float value;
        if (level <= 1f) {
            value = table[0];
        } else if (level >= table.length) {
            value = table[last] + perLevel * (level - table.length);
        } else {
            int index = (int) Math.floor(level) - 1;
            float fraction = level - (index + 1);
            value = table[index] + (table[index + 1] - table[index]) * fraction;
        }
        return cap ? Math.min(value, bound) : Math.max(value, bound);
    }
}
