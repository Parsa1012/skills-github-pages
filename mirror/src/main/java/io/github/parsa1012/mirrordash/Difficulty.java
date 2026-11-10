package io.github.parsa1012.mirrordash;

/**
 * Difficulty presets. Every knob is a multiplier or a dp offset applied on top of the
 * {@link LevelConfig} curve, so the shape of the curve stays the same and only its feel
 * changes. Values were checked with tools/simulate_generation.py.
 */
public enum Difficulty {

    /** Slower rows, wider openings, more forgiving precision and plenty of easy rows. */
    EASY(0.85f, 1.15f, 8f, 0.55f, 0.65f, 0.50f, 6f, 1.10f),

    /** The curve as designed. */
    NORMAL(1.00f, 1.00f, 0f, 1.00f, 1.00f, 1.00f, 0f, 1.00f),

    /** Faster, denser, tighter openings and more sliding rows. */
    HARD(1.15f, 0.88f, -6f, 1.25f, 1.15f, 1.35f, -4f, 0.86f);

    private final float speedScale;
    private final float spacingScale;
    private final float gapBonusDp;
    private final float mismatchScale;
    private final float twoGapScale;
    private final float movingScale;
    private final float minWindowBonusDp;
    private final float jumpScale;

    Difficulty(float speedScale, float spacingScale, float gapBonusDp, float mismatchScale,
               float twoGapScale, float movingScale, float minWindowBonusDp, float jumpScale) {
        this.speedScale = speedScale;
        this.spacingScale = spacingScale;
        this.gapBonusDp = gapBonusDp;
        this.mismatchScale = mismatchScale;
        this.twoGapScale = twoGapScale;
        this.movingScale = movingScale;
        this.minWindowBonusDp = minWindowBonusDp;
        this.jumpScale = jumpScale;
    }

    public float speedScale() {
        return speedScale;
    }

    public float spacingScale() {
        return spacingScale;
    }

    public float gapBonus(float density) {
        return gapBonusDp * density;
    }

    public float mismatchScale() {
        return mismatchScale;
    }

    /** Two-gap rows both add variety and difficulty, so the chance scales with the preset. */
    public float twoGapScale() {
        return twoGapScale;
    }

    public float movingScale() {
        return movingScale;
    }

    public float minWindowBonus(float density) {
        return minWindowBonusDp * density;
    }

    /** Reachability budget: harder presets leave less time between rows, so smaller jumps. */
    public float jumpScale() {
        return jumpScale;
    }

    public int labelRes() {
        switch (this) {
            case EASY:
                return R.string.difficulty_easy;
            case HARD:
                return R.string.difficulty_hard;
            case NORMAL:
            default:
                return R.string.difficulty_normal;
        }
    }

    public static Difficulty fromName(String name) {
        if (name != null) {
            for (Difficulty value : values()) {
                if (value.name().equals(name)) {
                    return value;
                }
            }
        }
        return NORMAL;
    }
}
