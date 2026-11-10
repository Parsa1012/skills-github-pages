package io.github.parsa1012.mirrordash;

/**
 * One horizontal row of hazards that scrolls down towards the player band.
 *
 * <p>A row is described by its gaps rather than its solid parts: the solid segments are
 * derived on demand, which keeps generation simple (gaps are what the fairness maths
 * cares about) and gives the renderer and the collision check the same geometry.</p>
 */
public class ObstacleRow {

    static final int MAX_GAPS = 2;

    final float[] gapCenter = new float[MAX_GAPS];
    final float[] gapWidth = new float[MAX_GAPS];
    int gapCount;

    float y;
    float height;
    boolean scored;

    /** Feasible player x-window this row allows, used for fairness and jump limiting. */
    float windowCenter;
    float windowWidth;

    boolean wave;
    float waveAmplitude;
    float wavePeriod;
    float wavePhase;
    float waveOffset;

    /** Scratch output for {@link #segments(float)}: left/right pairs. */
    final float[] segmentEdges = new float[(MAX_GAPS + 1) * 2];

    private final float[] sortedCenter = new float[MAX_GAPS];
    private final float[] sortedWidth = new float[MAX_GAPS];

    void begin(float y, float height) {
        this.y = y;
        this.height = height;
        this.gapCount = 0;
        this.scored = false;
        this.wave = false;
        this.waveOffset = 0f;
        this.waveAmplitude = 0f;
        this.wavePeriod = 1f;
        this.wavePhase = 0f;
        this.windowCenter = 0f;
        this.windowWidth = 0f;
    }

    void setGap(int index, float center, float width) {
        gapCenter[index] = center;
        gapWidth[index] = width;
        if (index + 1 > gapCount) {
            gapCount = index + 1;
        }
    }

    void enableWave(float amplitude, float period, float phase) {
        wave = true;
        waveAmplitude = amplitude;
        wavePeriod = period > 0.05f ? period : 1f;
        wavePhase = phase;
    }

    void updateWave(double elapsedSeconds) {
        if (!wave) {
            waveOffset = 0f;
            return;
        }
        double phase = elapsedSeconds * (2.0 * Math.PI / wavePeriod) + wavePhase;
        waveOffset = (float) (Math.sin(phase) * waveAmplitude);
    }

    /** Gap centre in screen space, including the wave offset. */
    float currentGapCenter(int index) {
        return gapCenter[index] + waveOffset;
    }

    /**
     * Builds the solid segments of the row into {@link #segmentEdges} and returns how many
     * there are. Callers must not hold on to the array across rows.
     */
    int segments(float screenWidth) {
        for (int i = 0; i < gapCount; i++) {
            sortedCenter[i] = gapCenter[i] + waveOffset;
            sortedWidth[i] = gapWidth[i];
        }
        // Two gaps at most: a tiny insertion sort keeps the segment builder simple.
        for (int i = 0; i < gapCount - 1; i++) {
            for (int j = 0; j < gapCount - 1 - i; j++) {
                if (sortedCenter[j] > sortedCenter[j + 1]) {
                    float center = sortedCenter[j];
                    sortedCenter[j] = sortedCenter[j + 1];
                    sortedCenter[j + 1] = center;
                    float width = sortedWidth[j];
                    sortedWidth[j] = sortedWidth[j + 1];
                    sortedWidth[j + 1] = width;
                }
            }
        }

        int count = 0;
        float cursor = 0f;
        for (int i = 0; i < gapCount; i++) {
            float left = clamp(sortedCenter[i] - sortedWidth[i] * 0.5f, 0f, screenWidth);
            float right = clamp(sortedCenter[i] + sortedWidth[i] * 0.5f, 0f, screenWidth);
            if (left > cursor) {
                segmentEdges[count * 2] = cursor;
                segmentEdges[count * 2 + 1] = left;
                count++;
            }
            if (right > cursor) {
                cursor = right;
            }
        }
        if (cursor < screenWidth) {
            segmentEdges[count * 2] = cursor;
            segmentEdges[count * 2 + 1] = screenWidth;
            count++;
        }
        return count;
    }

    private static float clamp(float value, float min, float max) {
        if (value < min) {
            return min;
        }
        return value > max ? max : value;
    }
}
