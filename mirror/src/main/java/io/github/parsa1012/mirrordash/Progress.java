package io.github.parsa1012.mirrordash;

/** Cosmetic unlock policy. Scores and appearance are deliberately independent of gameplay. */
public final class Progress {
    private Progress() {}
    public static int threshold(int style) {
        switch (style) { case 1: return 150; case 2: return 400; default: return 0; }
    }
    public static boolean unlockedBetween(int oldScore, int newScore) {
        return (oldScore < threshold(1) && newScore >= threshold(1))
                || (oldScore < threshold(2) && newScore >= threshold(2));
    }
    public static int validStyle(int style, int highestScore) {
        return style >= 0 && style <= 2 && highestScore >= threshold(style) ? style : 0;
    }
}
