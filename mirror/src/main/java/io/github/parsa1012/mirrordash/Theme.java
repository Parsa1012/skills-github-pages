package io.github.parsa1012.mirrordash;

import android.graphics.Color;

/**
 * Palette for the two looks of the game. One instance per look, created once, shared by the
 * canvas renderer and the Android overlay UI so both always agree on colours.
 */
public final class Theme {

    public final boolean night;

    // Canvas
    public final int background;
    public final int grid;
    public final int axis;
    public final int rowFill;
    public final int rowEdge;
    public final int scoreText;
    public final int playerCyan;
    public final int playerPink;

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
    public final int scrim;
    public final int menuOverlayTop;
    public final int menuOverlayBottom;

    private Theme(boolean night, int background, int grid, int axis, int rowFill, int rowEdge,
                  int scoreText, int playerCyan, int playerPink, int panelBackground,
                  int panelStroke, int textPrimary, int textSecondary, int textMuted,
                  int primaryButtonBackground, int primaryButtonText,
                  int secondaryButtonBackground, int secondaryButtonText,
                  int scrim, int menuOverlayTop, int menuOverlayBottom) {
        this.night = night;
        this.background = background;
        this.grid = grid;
        this.axis = axis;
        this.rowFill = rowFill;
        this.rowEdge = rowEdge;
        this.scoreText = scoreText;
        this.playerCyan = playerCyan;
        this.playerPink = playerPink;
        this.panelBackground = panelBackground;
        this.panelStroke = panelStroke;
        this.textPrimary = textPrimary;
        this.textSecondary = textSecondary;
        this.textMuted = textMuted;
        this.primaryButtonBackground = primaryButtonBackground;
        this.primaryButtonText = primaryButtonText;
        this.secondaryButtonBackground = secondaryButtonBackground;
        this.secondaryButtonText = secondaryButtonText;
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
            Color.parseColor("#22D3EE"),   // player cyan
            Color.parseColor("#F472B6"),   // player pink
            Color.parseColor("#161B22"),   // panel
            Color.parseColor("#233047"),   // panel stroke
            Color.parseColor("#E6EDF3"),   // text primary
            Color.parseColor("#9AA6B8"),   // text secondary
            Color.parseColor("#6E7681"),   // text muted
            Color.parseColor("#22D3EE"),   // primary button bg
            Color.parseColor("#08121F"),   // primary button text
            Color.parseColor("#1B2430"),   // secondary button bg
            Color.parseColor("#E6EDF3"),   // secondary button text
            Color.parseColor("#B3080F1A"), // scrim
            Color.parseColor("#F20B0F1A"), // menu overlay top
            Color.parseColor("#D90B0F1A"));// menu overlay bottom

    private static final Theme DAY = new Theme(false,
            Color.parseColor("#F2F5FB"),
            Color.parseColor("#E1E8F4"),
            Color.parseColor("#C0CDE2"),
            Color.parseColor("#C9D8EF"),
            Color.parseColor("#2563EB"),
            Color.parseColor("#0F172A"),
            Color.parseColor("#0891B2"),
            Color.parseColor("#DB2777"),
            Color.parseColor("#FFFFFF"),
            Color.parseColor("#D3DDEE"),
            Color.parseColor("#0F172A"),
            Color.parseColor("#475569"),
            Color.parseColor("#7A8699"),
            Color.parseColor("#0EA5E9"),
            Color.parseColor("#FFFFFF"),
            Color.parseColor("#E7EEF9"),
            Color.parseColor("#0F172A"),
            Color.parseColor("#B8F2F5FB"),
            Color.parseColor("#F2F2F5FB"),
            Color.parseColor("#D9F2F5FB"));

    public static Theme of(boolean night) {
        return night ? NIGHT : DAY;
    }
}
