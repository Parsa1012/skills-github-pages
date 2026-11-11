package io.github.parsa1012.mirrordash;

/** Stable cosmetic IDs: 0-3 are the original items; 4-53 are the new collection. */
public final class BallPalette {
    public static final int COUNT = 54;
    private static final int[] COLORS = {0xffa96bff, 0xff25c99e, 0xffff9c35, 0xff448cff,
            0xfff26da5, 0xffffd14b, 0xff53d6da, 0xffde6954, 0xff9c82f2, 0xffb3e05b};
    private static final String[] ASSETS = {"dragon", "lion", "leopard", "cat", "tiger", "wolf", "fox", "panda", "bear", "rabbit",
            "soccer", "volleyball", "tennis", "basketball", "baseball", "eightball",
            "fire", "moon", "star", "diamond", "crown", "planet", "lightning", "crystal"};
    private BallPalette() {}
    public static boolean valid(int id) { return id >= 0 && id < COUNT; }
    public static int price(int id) {
        if (!valid(id)) return -1;
        if (id == 0) return 0;
        if (id < 4) return 30 + id * 20;
        if (id < 34) return 100 + ((id - 4) / 10) * 90 + ((id - 4) % 10) * 8;
        if (id < 46) return 180 + ((id - 34) / 6) * 100 + ((id - 34) % 6) * 12;
        return 600 + (id - 46) * 100;
    }
    public static Difficulty requiredDifficulty(int id) {
        if (id < 4) return Difficulty.EASY;
        if (id < 34) return Difficulty.values()[(id - 4) / 10];
        if (id < 46) return id < 40 ? Difficulty.NORMAL : Difficulty.HARD;
        return Difficulty.HARD;
    }
    public static int requiredScore(int id) {
        if (!valid(id) || id == 0) return 0;
        if (id < 4) return id * 50;
        if (id < 34) return 100 + ((id - 4) % 10) * 30 + ((id - 4) / 10) * 100;
        if (id < 46) return 250 + ((id - 34) % 6) * 40 + ((id - 34) / 6) * 150;
        return 700 + (id - 46) * 100;
    }
    public static int assetIndex(int id) {
        if (id >= 4 && id < 34) return (id - 4) % 10;
        if (id >= 34 && id < 46) return 10 + (id - 34) % 6;
        if (id >= 46 && id < COUNT) return 16 + id - 46;
        return -1;
    }
    public static String assetName(int index) { return ASSETS[index]; }
    public static int assetCount() { return ASSETS.length; }
    public static boolean premium(int id) { return id >= 46 && id < COUNT; }
    public static int left(int id, Theme theme) {
        if (id == 0) return theme.playerBlue;
        if (id == 1) return 0xffa96bff;
        if (id == 2) return 0xff2be0ac;
        if (id == 3) return 0xffffa33b;
        return COLORS[((id - 4) % 10 + ((id - 4) / 10) * 3) % COLORS.length];
    }
    public static int right(int id, Theme theme) {
        if (id == 0) return theme.playerRed;
        if (id == 1) return 0xff53e4d0;
        if (id == 2) return 0xffff6fae;
        if (id == 3) return 0xffa886ff;
        return COLORS[((id - 4) % 10 + ((id - 4) / 10) * 3 + 5) % COLORS.length];
    }
}
