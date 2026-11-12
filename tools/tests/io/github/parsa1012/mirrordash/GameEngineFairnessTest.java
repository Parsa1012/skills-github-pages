package io.github.parsa1012.mirrordash;

import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.Random;

/** Executes the real generator (not a reimplementation) across screens, densities and levels. */
public final class GameEngineFairnessTest {
    private static final float EPS = .08f;
    private static void check(boolean ok, String message) {
        if (!ok) throw new AssertionError(message);
    }
    public static void main(String[] args) throws Exception {
        Method spawn = GameEngine.class.getDeclaredMethod("spawnRow", float.class);
        Method maxTravel = GameEngine.class.getDeclaredMethod("maxTravelFor", float.class);
        Field rng = GameEngine.class.getDeclaredField("random");
        spawn.setAccessible(true); maxTravel.setAccessible(true); rng.setAccessible(true);
        long count = 0, waves = 0, together = 0, pulseSingle = 0, pulseDouble = 0;
        for (Difficulty d : Difficulty.values()) {
            for (int widthDp : new int[]{280, 320, 360, 411, 600}) {
                for (float density : new float[]{1f, 2f, 3f}) {
                    for (float level : new float[]{1, 4, 8, 16, 32}) {
                        GameEngine e = new GameEngine();
                        float width = widthDp * density;
                        e.resize((int) width, (int) (780 * density), density);
                        e.setDifficulty(d);
                        ((Random) rng.get(e)).setSeed(1234567L + widthDp + (int) level);
                        Float prev = null;
                        for (int i = 0; i < 400; i++) {
                            spawn.invoke(e, level);
                            ObstacleRow row = e.rows().get(e.rows().size() - 1);
                            String where = d + " width=" + widthDp + " density=" + density + " level=" + level + " row=" + i;
                            if (prev != null) check(Math.abs(row.windowCenter - prev) <= (float) maxTravel.invoke(e, level) + EPS * density, "unreachable " + where);
                            prev = row.windowCenter;
                            if (row.gapCount == 1) together++;
                            if (row.wave) waves++;
                            if (row.pulse && row.gapCount == 1) pulseSingle++;
                            if (row.pulse && row.gapCount == 2) pulseDouble++;
                            check(!(row.wave && row.pulse), "combined movement " + where);
                            for (float phase : new float[]{-1f, 0, 1f}) {
                                row.waveOffset = phase * row.waveAmplitude;
                                row.pulseOffset = phase * row.pulseAmplitude;
                                float offset = row.waveOffset + row.pulseOffset;
                                int n = row.segments(width);
                                // Shared openings permit two visibly separated balls, not only overlapping ones.
                                float x = row.gapCount == 1 ? width / 2f - 24f * density : row.windowCenter;
                                for (int j = 0; j < n; j++) {
                                    float left = row.segmentEdges[j * 2], right = row.segmentEdges[j * 2 + 1];
                                    for (float bodyX : new float[]{x, width - x}) {
                                        check(bodyX + (16f - EPS) * density <= left || bodyX - (16f - EPS) * density >= right,
                                                "visible ball doesn't fit " + where + " phase=" + offset / density);
                                    }
                                }
                            }
                            e.rows().clear(); count++;
                        }
                    }
                }
            }
        }
        check(waves > 0 && together > 0 && pulseSingle > 0 && pulseDouble > 0, "missing pattern coverage");
        System.out.println("Real Java generator PASS: " + count + " rows; shared=" + together + ", sliding=" + waves + ", breathing single=" + pulseSingle + ", breathing double=" + pulseDouble);
    }
}
