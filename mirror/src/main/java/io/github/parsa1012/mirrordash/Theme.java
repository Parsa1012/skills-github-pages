package io.github.parsa1012.mirrordash;

import android.graphics.Color;

/**
 * Palette for the two looks of the game. One instance per look, created once, shared by the
 * canvas renderer and the Android overlay UI so both always agree on colours.
 *
 * <p>The two bodies are always "one blue, one red"; the exact shade changes with the theme so
 * both stay readable on a very dark and a very light background.</p>
 */
public final class Theme {

    /** Canonical body colours, also used as defaults before a theme is applied. */
    public static final int BLUE_NIGHT = Color.parseColor("#3B82F6");
    public static final int RED_NIGHT = Color.parseColor("#EF4444");
    public static final int BLUE_DAY = Color.parseColor("#2563EB");
    public static final int RED_DAY = Color.parseColor("#DC2626");

    public final boolean night;

    // Canvas
    public final int background;
    public final int grid;
    public final int axis;
    public final int rowFill;
    public final int rowEdge;
    public final int scoreText;
    public final int playerBlue;
    public final int playerRed;

    // Overlay UI
    public final int panelBackground;
    public final int panelStroke;
    public final int textPrimary;
    public final int textSecondary;
    public final int textMuted;
    public final int primaryButtonBackground;
    public final int primaryButtonText;
    public final int secondaryButtonBackground;
    public final int secondaryButtonText;
    public final int chipBackground;
    public final int scrim;
    public final int menuOverlayTop;
    public final int menuOverlayBottom;

    private Theme(boolean night, int background, int grid, int axis, int rowFill, int rowEdge,
                  int scoreText, int playerBlue, int playerRed, int panelBackground,
                  int panelStroke, int textPrimary, int textSecondary, int textMuted,
                  int primaryButtonBackground, int primaryButtonText,
                  int secondaryButtonBackground, int secondaryButtonText, int chipBackground,
                  int scrim, int menuOverlayTop, int menuOverlayBottom) {
        this.night = night;
        this.background = background;
        this.grid = grid;
        this.axis = axis;
        this.rowFill = rowFill;
        this.rowEdge = rowEdge;
        this.scoreText = scoreText;
        this.playerBlue = playerBlue;
        this.playerRed = playerRed;
        this.panelBackground = panelBackground;
        this.panelStroke = panelStroke;
        this.textPrimary = textPrimary;
        this.textSecondary = textSecondary;
        this.textMuted = textMuted;
        this.primaryButtonBackground = primaryButtonBackground;
        this.primaryButtonText = primaryButtonText;
        this.secondaryButtonBackground = secondaryButtonBackground;
        this.secondaryButtonText = secondaryButtonText;
        this.chipBackground = chipBackground;
        this.scrim = scrim;
        this.menuOverlayTop = menuOverlayTop;
        this.menuOverlayBottom = menuOverlayBottom;
    }

    private static final Theme NIGHT = new Theme(true,
            Color.parseColor("#0B0F1A"),   // background
            Color.parseColor("#141C2B"),   // grid
            Color.parseColor("#2B3A55"),   // axis
            Color.parseColor("#16233C"),   // row fill
            Color.parseColor("#2F81F7"),   // row edge
            Color.parseColor("#EAF2FF"),   // score
            BLUE_NIGHT,                    // player blue
            RED_NIGHT,                     // player red
            Color.parseColor("#161B22"),   // panel
            Color.parseColor("#233047"),   // panel stroke
            Color.parseColor("#E6EDF3"),   // text primary
            Color.parseColor("#9AA6B8"),   // text secondary
            Color.parseColor("#71809A"),   // text muted
            Color.parseColor("#3B82F6"),   // primary button bg
            Color.parseColor("#FFFFFF"),   // primary button text
            Color.parseColor("#1B2430"),   // secondary button bg
            Color.parseColor("#E6EDF3"),   // secondary button text
            Color.parseColor("#1E2836"),   // chip bg
            Color.parseColor("#B3080F1A"), // scrim
            Color.parseColor("#F20B0F1A"), // menu overlay top
            Color.parseColor("#D90B0F1A"));// menu overlay bottom

    private static final Theme DAY = new Theme(false,
            Color.parseColor("#F2F5FB"),
            Color.parseColor("#E3EAF5"),
            Color.parseColor("#C0CDE2"),
            Color.parseColor("#C9D8EF"),
            Color.parseColor("#2563EB"),
            Color.parseColor("#0F172A"),
            BLUE_DAY,
            RED_DAY,
            Color.parseColor("#FFFFFF"),
            Color.parseColor("#D3DDEE"),
            Color.parseColor("#0F172A"),
            Color.parseColor("#475569"),
            Color.parseColor("#6B7A93"),
            Color.parseColor("#2563EB"),
            Color.parseColor("#FFFFFF"),
            Color.parseColor("#E7EEF9"),
            Color.parseColor("#0F172A"),
            Color.parseColor("#EDF2FB"),
            Color.parseColor("#B8F0F4FB"),
            Color.parseColor("#F2F2F5FB"),
            Color.parseColor("#D9F2F5FB"));

    public static Theme of(boolean night) {
        return night ? NIGHT : DAY;
    }
}
