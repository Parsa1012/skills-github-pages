package io.github.parsa1012.mirrordash;

/**
 * One of the two mirrored bodies. Holds position, radius, colour and a short
 * trail history that the renderer fades out to make movement readable.
 */
public class Player {

    static final int TRAIL_LENGTH = 10;

    final float[] trailX = new float[TRAIL_LENGTH];
    final float[] trailY = new float[TRAIL_LENGTH];
    int trailCount;
    int trailHead;

    float x;
    float y;
    float radius;

    final int color;

    Player(int color) {
        this.color = color;
    }

    void pushTrail() {
        trailHead = (trailHead + 1) % TRAIL_LENGTH;
        trailX[trailHead] = x;
        trailY[trailHead] = y;
        if (trailCount < TRAIL_LENGTH) {
            trailCount++;
        }
    }

    void resetTrail() {
        trailCount = 0;
        trailHead = 0;
    }
}
