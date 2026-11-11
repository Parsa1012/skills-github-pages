package android.graphics;
public final class Color {
    public static int parseColor(String color) { return (int) Long.parseLong(color.substring(1), 16); }
}
