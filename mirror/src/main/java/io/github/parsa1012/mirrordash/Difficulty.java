package io.github.parsa1012.mirrordash;

/**
 * Difficulty presets. Every knob is a multiplier or a dp offset applied on top of the
 * {@link LevelConfig} curve, so the shape of the curve stays the same and only its feel
 * changes. Values were checked with tools/simulate_generation.py.
 */
public enum Difficulty {

    /** Slower rows, wider openings, gentler jumps between rows and plenty of breathers. */
    EASY(0.88f, 1.14f, 6f, 0.72f, 0.55f, 5f, 0.95f, 0.55f),

    /** The curve as designed. */
    NORMAL(1.00f, 1.00f, 0f, 1.00f, 1.00f, 0f, 1.00f, 0.62f),

    /** Faster, denser, tighter openings, wider swings and more sliding rows. */
    HARD(1.15f, 0.88f, -6f, 1.20f, 1.15f, -4f, 1.10f, 0.72f);

    private final float speedScale;
    private final float spacingScale;
    private final float gapBonusDp;
    private final float mismatchScale;
    private final float movingScale;
    private final float minWindowBonusDp;
    private final float apartScale;
    private final float switchChance;

    Difficulty(float speedScale, float spacingScale, float gapBonusDp, float mismatchScale,
               float movingScale, float minWindowBonusDp, float apartScale,
               float switchChance) {
        this.speedScale = speedScale;
        this.spacingScale = spacingScale;
        this.gapBonusDp = gapBonusDp;
        this.mismatchScale = mismatchScale;
        this.movingScale = movingScale;
        this.minWindowBonusDp = minWindowBonusDp;
        this.apartScale = apartScale;
        this.switchChance = switchChance;
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

    public float movingScale() {
        return movingScale;
    }

    public float minWindowBonus(float density) {
        return minWindowBonusDp * density;
    }

    /**
     * How wide the "apart" rows may pull the bodies towards the edges. Bigger values mean the
     * pair has to travel further sideways between rows.
     */
    public float apartScale() {
        return apartScale;
    }

    /** Base chance that the next row flips between "together" and "apart". */
    public float switchChance() {
        return switchChance;
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
