package io.github.parsa1012.mirrordash;

/** Purchasable colour pairs. Cosmetics never change collision geometry. */
public final class BallPalette {
    public static final int COUNT = 4;
    private BallPalette() {}
    public static boolean valid(int id) { return id >= 0 && id < COUNT; }
    public static int price(int id) {
        switch (id) { case 0: return 0; case 1: return 5; case 2: return 10; case 3: return 15; default: return -1; }
    }
    public static int left(int id, Theme theme) {
        switch (id) { case 1: return 0xffa96bff; case 2: return 0xff2be0ac; case 3: return 0xffffa33b; default: return theme.playerBlue; }
    }
    public static int right(int id, Theme theme) {
        switch (id) { case 1: return 0xff53e4d0; case 2: return 0xffff6fae; case 3: return 0xffa886ff; default: return theme.playerRed; }
    }
}
