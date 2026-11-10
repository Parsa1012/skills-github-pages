package io.github.parsa1012.mirrordash;

import android.app.Activity;
import android.content.pm.ActivityInfo;
import android.graphics.Typeface;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.StateListDrawable;
import android.os.Bundle;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

/**
 * Hosts the game surface and every overlay: main menu (with the logo), settings
 * (difficulty / day-night / sound), in-game HUD, pause panel and game-over panel.
 *
 * <p>Everything is built in code on purpose — there are no layout XML files, so the theme can
 * be swapped at runtime without a resource qualifier. Persian copy lives in TextViews so
 * Android handles shaping and bidi, and the whole UI is drawn with the bundled Vazirmatn
 * font. Buttons are plain TextViews with a state-list background: the platform Button style
 * applies its own insets and padding that misalign Persian glyphs.</p>
 *
 * <p>The layout direction is pinned to RTL because the interface is Persian only; on a phone
 * set to English the rows would otherwise be laid out left-to-right and read backwards.</p>
 */
public class GameActivity extends Activity {

    /** Theme switches recreate the activity; this flag makes the settings page come back. */
    private static boolean reopenSettingsAfterRecreate;

    private FrameLayout root;
    private GameView gameView;
    private MusicPlayer music;

    private Lang lang;
    private Strings strings;
    private TextView recordsText;
    private Theme theme;
    private Typeface typeRegular;
    private Typeface typeBold;

    private Difficulty difficulty;
    private boolean nightMode;
    private boolean soundEnabled;

    private LinearLayout hud;
    private TextView pauseButton;
    private TextView hudBest;

    private TextView hint;
    private boolean hintConsumed;

    private View scrim;
    private View menuOverlay;
    private TextView menuBest;
    private TextView menuDifficulty;

    private View settingsOverlay;
    private TextView chipEasy;
    private TextView chipNormal;
    private TextView chipHard;
    private TextView chipNight;
    private TextView chipDay;
    private TextView chipSoundOn;
    private TextView chipSoundOff;

    private LinearLayout pausePanel;
    private LinearLayout gameOverPanel;
    private TextView gameOverTitle;
    private TextView gameOverScore;
    private TextView gameOverRows;
    private TextView gameOverBest;

    private boolean pauseOnResume;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_PORTRAIT);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        GamePrefs.migrate(this);
        lang = GamePrefs.lang(this);
        strings = Strings.of(lang);
        getWindow().getDecorView().setLayoutDirection(lang.rtl() ? View.LAYOUT_DIRECTION_RTL : View.LAYOUT_DIRECTION_LTR);

        nightMode = GamePrefs.nightMode(this);
        soundEnabled = GamePrefs.soundEnabled(this);
        music = new MusicPlayer(this, soundEnabled);
        music.setScene(MusicPlayer.Scene.MENU);
        difficulty = GamePrefs.difficulty(this);
        theme = Theme.of(nightMode);
        // Same colour as the canvas, so rotation/recreate never flashes the platform grey.
        getWindow().setBackgroundDrawable(new GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                new int[] {theme.background, theme.background}));
        typeBold = Renderer.load(this, "fonts/Vazirmatn-Bold.ttf", Typeface.BOLD);
        typeRegular = Renderer.load(this, "fonts/Vazirmatn-Regular.ttf", Typeface.NORMAL);

        root = new FrameLayout(this);
        gameView = new GameView(this);
        gameView.setTheme(theme);
        gameView.setDifficulty(difficulty);
        gameView.setSoundEnabled(soundEnabled);
        root.addView(gameView, matchParent());

        buildHud();
        buildHint();
        buildScrim();
        buildMenu();
        buildSettings();
        buildPausePanel();
        buildGameOverPanel();

        gameView.setGameOverListener(new GameView.GameOverListener() {
            @Override
            public void onGameOver(int score, int rowsCleared) {
                showGameOver(score, rowsCleared);
            }
        });

        setContentView(root);
        hideSystemBars();
        refreshLabels();
        refreshSettingChips();

        if (reopenSettingsAfterRecreate) {
            reopenSettingsAfterRecreate = false;
            showSettings();
        }
    }

    // ------------------------------------------------------------------ menu / HUD

    private void buildHud() {
        hud = new LinearLayout(this);
        hud.setOrientation(LinearLayout.HORIZONTAL);
        hud.setGravity(Gravity.CENTER_VERTICAL);
        hud.setPadding(dp(14), dp(22), dp(14), 0);
        hud.setVisibility(View.GONE);

        pauseButton = new TextView(this);
        pauseButton.setText("II");
        pauseButton.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16);
        pauseButton.setTypeface(typeBold);
        pauseButton.setTextColor(theme.textSecondary);
        pauseButton.setGravity(Gravity.CENTER);
        pauseButton.setIncludeFontPadding(false);
        pauseButton.setPadding(dp(14), dp(9), dp(14), dp(9));
        pauseButton.setBackground(buttonBackground(theme.chipBackground, theme.panelStroke));
        pauseButton.setClickable(true);
        pauseButton.setFocusable(true);
        pauseButton.setContentDescription(strings.pauseDescription);
        pauseButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                showPause();
            }
        });
        hud.addView(pauseButton);

        hudBest = new TextView(this);
        hudBest.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13);
        hudBest.setTypeface(typeRegular);
        hudBest.setTextColor(theme.textMuted);
        hudBest.setGravity(Gravity.END);
        hudBest.setIncludeFontPadding(false);
        hud.addView(hudBest, new LinearLayout.LayoutParams(
                0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));

        FrameLayout.LayoutParams params = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        params.gravity = Gravity.TOP;
        root.addView(hud, params);
    }

    private void buildHint() {
        hint = new TextView(this);
        hint.setText(strings.hint);
        hint.setTextColor(theme.textSecondary);
        hint.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
        hint.setTypeface(typeRegular);
        hint.setIncludeFontPadding(false);
        hint.setGravity(Gravity.CENTER);
        hint.setVisibility(View.GONE);

        FrameLayout.LayoutParams params = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        params.gravity = Gravity.TOP | Gravity.CENTER_HORIZONTAL;
        params.topMargin = dp(110);
        root.addView(hint, params);
    }

    private void buildScrim() {
        scrim = new View(this);
        scrim.setBackgroundColor(theme.scrim);
        scrim.setClickable(true);
        scrim.setVisibility(View.GONE);
        root.addView(scrim, matchParent());
    }

    private void buildMenu() {
        FrameLayout overlay = new FrameLayout(this);
        overlay.setBackground(menuBackground());
        overlay.setClickable(true);
        menuOverlay = overlay;

        LinearLayout content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL);
        content.setGravity(Gravity.CENTER_HORIZONTAL);
        content.setPadding(dp(28), dp(16), dp(28), dp(16));

        ImageView logo = new ImageView(this);
        logo.setImageResource(R.drawable.logo);
        logo.setScaleType(ImageView.ScaleType.FIT_CENTER);
        logo.setContentDescription(strings.logoDescription);
        content.addView(logo, new LinearLayout.LayoutParams(dp(104), dp(104)));

        TextView title = label(strings.appName, 34, true, theme.textPrimary);
        content.addView(title, wrapWithTopMargin(10));

        TextView tagline = label(strings.tagline, 14, false, theme.playerBlue);
        content.addView(tagline, wrapWithTopMargin(6));

        menuBest = label(strings.bestLine, 14, true, theme.playerRed);
        content.addView(menuBest, wrapWithTopMargin(16));

        menuDifficulty = label(strings.difficultyLine, 12, false, theme.textMuted);
        content.addView(menuDifficulty, wrapWithTopMargin(6));

        TextView start = primaryAction(strings.start);
        LinearLayout.LayoutParams startParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(54));
        startParams.topMargin = dp(20);
        content.addView(start, startParams);
        start.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                startGame();
            }
        });

        TextView settings = secondaryAction(strings.settings);
        LinearLayout.LayoutParams settingsParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(50));
        settingsParams.topMargin = dp(10);
        content.addView(settings, settingsParams);
        settings.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                showSettings();
            }
        });

        FrameLayout.LayoutParams contentParams = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        contentParams.gravity = Gravity.CENTER;
        overlay.addView(content, contentParams);

        addMenuTools(overlay);
        root.addView(overlay, matchParent());
    }

    private void addMenuTools(FrameLayout overlay) {
        LinearLayout tools = new LinearLayout(this);
        tools.setOrientation(LinearLayout.HORIZONTAL);
        tools.setPadding(dp(12), dp(12), dp(12), 0);
        addTool(tools, "i", strings.infoDescription, () -> showTextDialog(strings.helpTitle, strings.helpBody));
        addTool(tools, "A", strings.languageDescription, () -> showLanguageDialog());
        addTool(tools, "@", strings.aboutDescription, () -> showTextDialog(strings.aboutTitle,
                strings.creatorLabel + ": " + strings.creatorName + "\n" + strings.emailLabel + ":\n" + strings.creatorEmail + "\n\n" + strings.aboutBody + "\n\n" + strings.versionLabel + ": 1.3"));
        FrameLayout.LayoutParams lp = new FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.TOP | Gravity.END);
        overlay.addView(tools, lp);
    }

    private void addTool(LinearLayout row, String text, String description, Runnable action) {
        TextView b = actionBase(text, 16, true);
        b.setContentDescription(description);
        b.setTextColor(theme.textPrimary);
        b.setBackground(buttonBackground(theme.chipBackground, theme.panelStroke));
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(dp(48), dp(48));
        lp.setMarginStart(dp(6));
        row.addView(b, lp);
        b.setOnClickListener(v -> action.run());
    }

    private void showTextDialog(String title, String body) {
        TextView message = label(body, 15, false, android.graphics.Color.rgb(30, 35, 45));
        message.setGravity(Gravity.START);
        message.setTextDirection(lang.rtl() ? View.TEXT_DIRECTION_RTL : View.TEXT_DIRECTION_LTR);
        message.setPadding(dp(22), dp(12), dp(22), dp(12));
        ScrollView scroller = new ScrollView(this);
        scroller.addView(message);
        android.app.AlertDialog dialog = new android.app.AlertDialog.Builder(this, android.app.AlertDialog.THEME_DEVICE_DEFAULT_LIGHT)
                .setTitle(title).setView(scroller).setPositiveButton(strings.close, (d, which) -> {}).create();
        dialog.setOnShowListener(d -> dialog.getWindow().getDecorView().setLayoutDirection(lang.rtl() ? View.LAYOUT_DIRECTION_RTL : View.LAYOUT_DIRECTION_LTR));
        dialog.show();
    }

    private void showLanguageDialog() {
        Lang[] languages = Lang.values();
        String[] names = new String[languages.length];
        for (int i = 0; i < languages.length; i++) names[i] = languages[i].nativeName();
        new android.app.AlertDialog.Builder(this, android.app.AlertDialog.THEME_DEVICE_DEFAULT_LIGHT).setTitle(strings.languageTitle)
                .setSingleChoiceItems(names, lang.ordinal(), (dialog, which) -> {
                    GamePrefs.setLang(this, languages[which]);
                    dialog.dismiss();
                    recreate();
                }).setNegativeButton(strings.close, (d, which) -> {}).show();
    }

    private String difficultyName(Difficulty d) {
        return d == Difficulty.EASY ? strings.easy : d == Difficulty.HARD ? strings.hard : strings.normal;
    }

    // ------------------------------------------------------------------- settings

    private void buildSettings() {
        FrameLayout overlay = new FrameLayout(this);
        overlay.setBackground(menuBackground());
        overlay.setClickable(true);
        overlay.setVisibility(View.GONE);
        settingsOverlay = overlay;

        ScrollView scroller = new ScrollView(this);
        scroller.setFillViewport(true);
        scroller.setClipToPadding(false);

        LinearLayout centring = new LinearLayout(this);
        centring.setOrientation(LinearLayout.VERTICAL);
        centring.setGravity(Gravity.CENTER);
        centring.setPadding(dp(20), dp(20), dp(20), dp(20));
        scroller.addView(centring, new ScrollView.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        LinearLayout card = card(theme, dp(340));
        card.setVisibility(View.VISIBLE);
        card.setAlpha(1f);
        card.setGravity(Gravity.CENTER_HORIZONTAL);
        card.setPadding(dp(20), dp(18), dp(20), dp(18));
        int screenWidth = getResources().getDisplayMetrics().widthPixels;
        centring.addView(card, new LinearLayout.LayoutParams(
                Math.min(dp(340), screenWidth - dp(40)),
                ViewGroup.LayoutParams.WRAP_CONTENT));

        TextView title = label(strings.settings, 20, true, theme.textPrimary);
        card.addView(title);

        chipEasy = chipLabel(strings.easy);
        chipNormal = chipLabel(strings.normal);
        chipHard = chipLabel(strings.hard);
        card.addView(sectionLabel(strings.difficulty), wrapWithTopMargin(16));
        card.addView(chipRow(chipEasy, chipNormal, chipHard), wrapWithTopMargin(8));

        chipNight = chipLabel(strings.night);
        chipDay = chipLabel(strings.day);
        card.addView(sectionLabel(strings.appearance), wrapWithTopMargin(16));
        card.addView(chipRow(chipNight, chipDay), wrapWithTopMargin(8));

        chipSoundOn = chipLabel(strings.on);
        chipSoundOff = chipLabel(strings.off);
        card.addView(sectionLabel(strings.sound), wrapWithTopMargin(16));
        card.addView(chipRow(chipSoundOn, chipSoundOff), wrapWithTopMargin(8));

        card.addView(sectionLabel(strings.records), wrapWithTopMargin(16));
        recordsText = label("", 13, false, theme.textSecondary);
        card.addView(recordsText, wrapWithTopMargin(8));
        TextView back = primaryAction(strings.back);
        LinearLayout.LayoutParams backParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(50));
        backParams.topMargin = dp(22);
        card.addView(back, backParams);
        back.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                hideSettings();
            }
        });

        chipEasy.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                selectDifficulty(Difficulty.EASY);
            }
        });
        chipNormal.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                selectDifficulty(Difficulty.NORMAL);
            }
        });
        chipHard.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                selectDifficulty(Difficulty.HARD);
            }
        });
        chipNight.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                selectNight(true);
            }
        });
        chipDay.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                selectNight(false);
            }
        });
        chipSoundOn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                selectSound(true);
            }
        });
        chipSoundOff.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                selectSound(false);
            }
        });

        overlay.addView(scroller, matchParent());
        root.addView(overlay, matchParent());
    }

    private TextView sectionLabel(String textRes) {
        TextView label = label(textRes, 12, false, theme.textMuted);
        label.setGravity(Gravity.CENTER);
        return label;
    }

    private TextView chipLabel(String textRes) {
        TextView chip = new TextView(this);
        chip.setText(textRes);
        chip.setGravity(Gravity.CENTER);
        chip.setTextSize(TypedValue.COMPLEX_UNIT_SP, 15);
        chip.setIncludeFontPadding(false);
        chip.setSingleLine(true);
        chip.setPadding(dp(6), dp(12), dp(6), dp(12));
        chip.setMinHeight(dp(46));
        chip.setClickable(true);
        chip.setFocusable(true);
        return chip;
    }

    private LinearLayout chipRow(TextView... chips) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        for (int i = 0; i < chips.length; i++) {
            LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
                    0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f);
            if (i > 0) {
                params.setMarginStart(dp(8));
            }
            row.addView(chips[i], params);
        }
        return row;
    }

    private void refreshSettingChips() {
        styleChip(chipEasy, difficulty == Difficulty.EASY);
        styleChip(chipNormal, difficulty == Difficulty.NORMAL);
        styleChip(chipHard, difficulty == Difficulty.HARD);
        styleChip(chipNight, nightMode);
        styleChip(chipDay, !nightMode);
        styleChip(chipSoundOn, soundEnabled);
        styleChip(chipSoundOff, !soundEnabled);
    }

    private void styleChip(TextView chip, boolean selected) {
        GradientDrawable shape = new GradientDrawable();
        shape.setCornerRadius(dp(13));
        shape.setColor(selected ? theme.primaryButtonBackground : theme.chipBackground);
        shape.setStroke(dp(1), selected ? theme.primaryButtonBackground : theme.panelStroke);
        chip.setBackground(shape);
        chip.setTextColor(selected ? theme.primaryButtonText : theme.textSecondary);
        chip.setTypeface(selected ? typeBold : typeRegular);
    }

    private void selectDifficulty(Difficulty value) {
        difficulty = value;
        GamePrefs.setDifficulty(this, value);
        gameView.setDifficulty(value);
        refreshSettingChips();
        refreshLabels();
    }

    private void selectSound(boolean enabled) {
        soundEnabled = enabled;
        GamePrefs.setSoundEnabled(this, enabled);
        gameView.setSoundEnabled(enabled);
        music.setEnabled(enabled);
        refreshSettingChips();
    }

    private void selectNight(boolean night) {
        if (night == nightMode) {
            return;
        }
        nightMode = night;
        GamePrefs.setNightMode(this, night);
        reopenSettingsAfterRecreate = true;
        recreate();
    }

    private void showSettings() {
        settingsOverlay.setVisibility(View.VISIBLE);
        settingsOverlay.setAlpha(0f);
        settingsOverlay.animate().alpha(1f).setDuration(180).start();
    }

    private void hideSettings() {
        settingsOverlay.animate().alpha(0f).setDuration(150)
                .withEndAction(new Runnable() {
                    @Override
                    public void run() {
                        settingsOverlay.setVisibility(View.GONE);
                    }
                }).start();
    }

    // ---------------------------------------------------------------- pause / over

    private void buildPausePanel() {
        LinearLayout panel = card(theme, dp(320));

        TextView title = label(strings.pausedTitle, 22, true, theme.textPrimary);
        panel.addView(title);

        TextView resume = primaryAction(strings.resume);
        panel.addView(resume, fullWidthButtonParams(20));
        resume.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                hidePause();
            }
        });

        TextView restart = secondaryAction(strings.restart);
        panel.addView(restart, fullWidthButtonParams(10));
        restart.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                hidePause();
                startGame();
            }
        });

        TextView menu = secondaryAction(strings.menu);
        panel.addView(menu, fullWidthButtonParams(10));
        menu.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                hidePause();
                goToMenu();
            }
        });

        pausePanel = panel;
        root.addView(panel, centeredPanelParams());
    }

    private void buildGameOverPanel() {
        LinearLayout panel = card(theme, dp(320));

        gameOverTitle = label(strings.gameOver, 22, true, theme.textPrimary);
        panel.addView(gameOverTitle);

        gameOverScore = label(strings.scoreLine, 24, true, theme.playerBlue);
        panel.addView(gameOverScore, wrapWithTopMargin(12));

        gameOverRows = label(strings.rowsLine, 13, false, theme.textSecondary);
        panel.addView(gameOverRows, wrapWithTopMargin(6));

        gameOverBest = label(strings.bestLine, 13, true, theme.playerRed);
        panel.addView(gameOverBest, wrapWithTopMargin(6));

        TextView again = primaryAction(strings.playAgain);
        panel.addView(again, fullWidthButtonParams(18));
        again.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                hideGameOver();
                startGame();
            }
        });

        TextView menu = secondaryAction(strings.menu);
        panel.addView(menu, fullWidthButtonParams(10));
        menu.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                hideGameOver();
                goToMenu();
            }
        });

        gameOverPanel = panel;
        root.addView(panel, centeredPanelParams());
    }

    // ---------------------------------------------------------------- shared views

    private TextView label(String textRes, float sizeSp, boolean bold, int color) {
        TextView view = new TextView(this);
        view.setText(textRes);
        view.setTextSize(TypedValue.COMPLEX_UNIT_SP, sizeSp);
        view.setTypeface(bold ? typeBold : typeRegular);
        view.setTextColor(color);
        view.setGravity(Gravity.CENTER);
        view.setIncludeFontPadding(false);
        view.setLineSpacing(dp(4), 1f);
        return view;
    }

    private LinearLayout card(Theme theme, int maxWidthPx) {
        LinearLayout panel = new LinearLayout(this);
        panel.setOrientation(LinearLayout.VERTICAL);
        panel.setGravity(Gravity.CENTER_HORIZONTAL);
        panel.setPadding(dp(22), dp(20), dp(22), dp(20));
        panel.setClickable(true);

        GradientDrawable background = new GradientDrawable();
        background.setColor(theme.panelBackground);
        background.setCornerRadius(dp(22));
        background.setStroke(dp(1), theme.panelStroke);
        panel.setBackground(background);

        int screenWidth = getResources().getDisplayMetrics().widthPixels;
        panel.setMinimumWidth(Math.min(maxWidthPx, screenWidth - dp(48)));

        panel.setVisibility(View.GONE);
        panel.setAlpha(0f);
        return panel;
    }

    private TextView primaryAction(String textRes) {
        TextView button = actionBase(textRes, 16, true);
        button.setTextColor(theme.primaryButtonText);
        button.setBackground(buttonBackground(theme.primaryButtonBackground,
                blend(theme.primaryButtonBackground, theme.primaryButtonText, 0.16f)));
        return button;
    }

    private TextView secondaryAction(String textRes) {
        TextView button = actionBase(textRes, 15, false);
        button.setTextColor(theme.secondaryButtonText);
        button.setBackground(buttonBackground(theme.secondaryButtonBackground,
                blend(theme.secondaryButtonBackground, theme.secondaryButtonText, 0.10f)));
        return button;
    }

    private TextView actionBase(String textRes, float sizeSp, boolean bold) {
        TextView button = new TextView(this);
        button.setText(textRes);
        button.setTextSize(TypedValue.COMPLEX_UNIT_SP, sizeSp);
        button.setTypeface(bold ? typeBold : typeRegular);
        button.setGravity(Gravity.CENTER);
        button.setIncludeFontPadding(false);
        button.setPadding(dp(14), dp(10), dp(14), dp(10));
        button.setClickable(true);
        button.setFocusable(true);
        return button;
    }

    private Drawable buttonBackground(int normal, int pressed) {
        StateListDrawable states = new StateListDrawable();
        states.addState(new int[] {android.R.attr.state_pressed}, roundedRect(pressed));
        states.addState(new int[] {android.R.attr.state_enabled}, roundedRect(normal));
        return states;
    }

    private Drawable roundedRect(int color) {
        GradientDrawable shape = new GradientDrawable();
        shape.setColor(color);
        shape.setCornerRadius(dp(14));
        shape.setStroke(dp(1), theme.panelStroke);
        return shape;
    }

    private GradientDrawable menuBackground() {
        return new GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM,
                new int[] {theme.menuOverlayTop, theme.menuOverlayBottom});
    }

    private static int blend(int from, int to, float amount) {
        int a = (int) (((from >> 24) & 0xFF) * (1f - amount) + ((to >> 24) & 0xFF) * amount);
        int r = (int) (((from >> 16) & 0xFF) * (1f - amount) + ((to >> 16) & 0xFF) * amount);
        int g = (int) (((from >> 8) & 0xFF) * (1f - amount) + ((to >> 8) & 0xFF) * amount);
        int b = (int) ((from & 0xFF) * (1f - amount) + (to & 0xFF) * amount);
        return (a << 24) | (r << 16) | (g << 8) | b;
    }

    private LinearLayout.LayoutParams fullWidthButtonParams(int topMarginDp) {
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(50));
        params.topMargin = dp(topMarginDp);
        return params;
    }

    private LinearLayout.LayoutParams wrapWithTopMargin(int topMarginDp) {
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        params.topMargin = dp(topMarginDp);
        return params;
    }

    private FrameLayout.LayoutParams centeredPanelParams() {
        FrameLayout.LayoutParams params = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        params.gravity = Gravity.CENTER;
        params.leftMargin = dp(20);
        params.rightMargin = dp(20);
        return params;
    }

    private FrameLayout.LayoutParams matchParent() {
        return new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT);
    }

    // ------------------------------------------------------------------------ flow

    private void startGame() {
        music.setScene(MusicPlayer.Scene.GAME);
        music.setPaused(false);
        menuOverlay.setVisibility(View.GONE);
        if (settingsOverlay.getVisibility() == View.VISIBLE) {
            hideSettings();
        }
        hideGameOver();
        pauseOnResume = false;
        hud.setVisibility(View.VISIBLE);
        if (!hintConsumed) {
            hint.setVisibility(View.VISIBLE);
            hint.setAlpha(1f);
            gameView.setOnFirstTouchListener(new Runnable() {
                @Override
                public void run() {
                    hideHint();
                }
            });
        }
        refreshLabels();
        gameView.startRun();
        gameView.resumeGame();
    }

    private void goToMenu() {
        music.setScene(MusicPlayer.Scene.MENU);
        hud.setVisibility(View.GONE);
        hint.setVisibility(View.GONE);
        menuOverlay.setVisibility(View.VISIBLE);
        scrim.setVisibility(View.GONE);
        gameView.showAttract();
        gameView.resumeGame();
        refreshLabels();
    }

    private void showPause() {
        GameEngine.State state = gameView.engine().state();
        if (state != GameEngine.State.PLAYING && state != GameEngine.State.COUNTDOWN) {
            return;
        }
        if (gameOverPanel.getVisibility() == View.VISIBLE) {
            return;
        }
        gameView.pauseGame();
        music.setPaused(true);
        hud.setVisibility(View.GONE);
        scrim.setVisibility(View.VISIBLE);
        fadeIn(scrim);
        panelIn(pausePanel);
    }

    private void hidePause() {
        music.setPaused(false);
        hideCard(pausePanel);
        hud.setVisibility(View.VISIBLE);
        gameView.resumeGame();
    }

    private void showGameOver(int score, int rowsCleared) {
        music.setScene(MusicPlayer.Scene.NONE);
        boolean record = GamePrefs.submitBest(this, difficulty, score);
        gameOverTitle.setText(record ? strings.newRecord : strings.gameOver);
        gameOverScore.setText(String.format(java.util.Locale.ROOT, strings.scoreLine, score));
        gameOverRows.setText(String.format(java.util.Locale.ROOT, strings.rowsLine, rowsCleared));
        gameOverBest.setText(String.format(java.util.Locale.ROOT, strings.bestLine, GamePrefs.best(this, difficulty)));

        hud.setVisibility(View.GONE);
        hideHint();
        scrim.setVisibility(View.VISIBLE);
        fadeIn(scrim);
        panelIn(gameOverPanel);
        refreshLabels();
    }

    private void hideGameOver() {
        hideCard(gameOverPanel);
    }

    private void hideHint() {
        if (hint.getVisibility() != View.VISIBLE) {
            return;
        }
        hintConsumed = true;
        hint.animate()
                .alpha(0f)
                .setDuration(450)
                .withEndAction(new Runnable() {
                    @Override
                    public void run() {
                        hint.setVisibility(View.GONE);
                    }
                })
                .start();
    }

    private void refreshLabels() {
        if (recordsText != null) {
            StringBuilder records = new StringBuilder();
            for (Difficulty d : Difficulty.values()) {
                if (records.length() > 0) records.append("\n");
                records.append(String.format(java.util.Locale.ROOT, strings.recordFor, difficultyName(d), GamePrefs.best(this, d)));
            }
            recordsText.setText(records.toString());
        }
        int best = GamePrefs.best(this, difficulty);
        if (menuBest != null) {
            menuBest.setText(String.format(java.util.Locale.ROOT, strings.bestLine, best));
        }
        if (hudBest != null) {
            hudBest.setText(String.format(java.util.Locale.ROOT, strings.bestLine, best));
        }
        if (menuDifficulty != null) {
            menuDifficulty.setText(String.format(java.util.Locale.ROOT, strings.difficultyLine, difficultyName(difficulty)));
        }
    }

    private void fadeIn(View view) {
        view.setAlpha(0f);
        view.animate().alpha(1f).setDuration(200).start();
    }

    private void panelIn(View panel) {
        panel.setVisibility(View.VISIBLE);
        panel.setAlpha(0f);
        panel.setScaleX(0.94f);
        panel.setScaleY(0.94f);
        panel.animate().alpha(1f).scaleX(1f).scaleY(1f).setDuration(220).start();
    }

    /** Fades a card out and only then hides the shared scrim behind it. */
    private void hideCard(final View panel) {
        panel.animate().alpha(0f).scaleX(0.94f).scaleY(0.94f).setDuration(150)
                .withEndAction(new Runnable() {
                    @Override
                    public void run() {
                        panel.setVisibility(View.GONE);
                        if (pausePanel.getVisibility() != View.VISIBLE
                                && gameOverPanel.getVisibility() != View.VISIBLE) {
                            scrim.setVisibility(View.GONE);
                        }
                    }
                }).start();
    }

    // ------------------------------------------------------------------- lifecycle

    @Override
    protected void onResume() {
        super.onResume();
        if (gameView != null) {
            gameView.start();
        }
        if (pauseOnResume) {
            pauseOnResume = false;
            showPause();
        }
        if (music != null) music.setForeground(true);
    }

    @Override
    protected void onPause() {
        if (music != null) music.setForeground(false);
        if (gameView != null) {
            GameEngine.State state = gameView.engine().state();
            if (state == GameEngine.State.PLAYING || state == GameEngine.State.COUNTDOWN) {
                gameView.pauseGame();
                pauseOnResume = true;
            }
            gameView.stop();
        }
        super.onPause();
    }

    @Override
    protected void onDestroy() {
        if (music != null) music.release();
        if (gameView != null) {
            gameView.release();
        }
        super.onDestroy();
    }

    @Override
    @SuppressWarnings("deprecation")
    public void onBackPressed() {
        if (settingsOverlay.getVisibility() == View.VISIBLE) {
            hideSettings();
            return;
        }
        if (menuOverlay.getVisibility() == View.VISIBLE) {
            super.onBackPressed();
            return;
        }
        if (gameOverPanel.getVisibility() == View.VISIBLE) {
            hideGameOver();
            goToMenu();
            return;
        }
        if (pausePanel.getVisibility() == View.VISIBLE) {
            hidePause();
            return;
        }
        showPause();
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) {
            hideSystemBars();
        }
    }

    @SuppressWarnings("deprecation")
    private void hideSystemBars() {
        View decor = getWindow().getDecorView();
        decor.setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                        | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY);
    }

    private int dp(float value) {
        return Math.round(TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_DIP, value, getResources().getDisplayMetrics()));
    }
}
