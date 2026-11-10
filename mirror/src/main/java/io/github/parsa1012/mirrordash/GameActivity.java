package io.github.parsa1012.mirrordash;

import android.app.Activity;
import android.content.pm.ActivityInfo;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;

/**
 * Hosts the game surface and every overlay: main menu (with the logo), settings
 * (difficulty / day-night / sound), in-game HUD, pause panel and game-over panel.
 *
 * <p>Persian copy lives in TextViews so Android handles shaping and RTL, and the whole UI
 * is drawn with the bundled Vazirmatn font. All colours come from {@link Theme}, which is
 * read from preferences in {@link #onCreate}; switching the theme recreates the activity so
 * no view keeps a stale colour.</p>
 */
public class GameActivity extends Activity {

    /** Theme switches recreate the activity; this flag makes the settings page come back. */
    private static boolean reopenSettingsAfterRecreate;

    private FrameLayout root;
    private GameView gameView;

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

        nightMode = GamePrefs.nightMode(this);
        soundEnabled = GamePrefs.soundEnabled(this);
        difficulty = GamePrefs.difficulty(this);
        theme = Theme.of(nightMode);
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
        hud.setPadding(dp(14), dp(24), dp(18), 0);
        hud.setVisibility(View.GONE);

        pauseButton = new TextView(this);
        pauseButton.setText("II");
        pauseButton.setTextSize(TypedValue.COMPLEX_UNIT_SP, 18);
        pauseButton.setTypeface(typeBold);
        pauseButton.setTextColor(theme.textSecondary);
        pauseButton.setGravity(Gravity.CENTER);
        pauseButton.setPadding(dp(12), dp(8), dp(12), dp(8));
        pauseButton.setContentDescription(getString(R.string.pause_description));
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
        hud.addView(hudBest, new LinearLayout.LayoutParams(
                0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));

        FrameLayout.LayoutParams params = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        params.gravity = Gravity.TOP;
        root.addView(hud, params);
    }

    private void buildHint() {
        hint = new TextView(this);
        hint.setText(R.string.hint);
        hint.setTextColor(theme.textSecondary);
        hint.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
        hint.setTypeface(typeRegular);
        hint.setGravity(Gravity.CENTER);
        hint.setVisibility(View.GONE);

        FrameLayout.LayoutParams params = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        params.gravity = Gravity.TOP | Gravity.CENTER_HORIZONTAL;
        params.topMargin = dp(112);
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
        overlay.setBackground(new GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM,
                new int[] {theme.menuOverlayTop, theme.menuOverlayBottom}));
        overlay.setClickable(true);
        menuOverlay = overlay;

        LinearLayout content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL);
        content.setGravity(Gravity.CENTER_HORIZONTAL);
        content.setPadding(dp(28), dp(18), dp(28), dp(18));

        ImageView logo = new ImageView(this);
        logo.setImageResource(R.drawable.logo);
        logo.setScaleType(ImageView.ScaleType.FIT_CENTER);
        logo.setContentDescription(getString(R.string.logo_description));
        content.addView(logo, new LinearLayout.LayoutParams(dp(104), dp(104)));

        TextView title = new TextView(this);
        title.setText(R.string.app_name);
        title.setTextSize(TypedValue.COMPLEX_UNIT_SP, 34);
        title.setTypeface(typeBold);
        title.setTextColor(theme.textPrimary);
        title.setGravity(Gravity.CENTER);
        content.addView(title, wrapWithTopMargin(10));

        TextView tagline = new TextView(this);
        tagline.setText(R.string.tagline);
        tagline.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
        tagline.setTypeface(typeRegular);
        tagline.setTextColor(theme.primaryButtonBackground);
        tagline.setGravity(Gravity.CENTER);
        content.addView(tagline, wrapWithTopMargin(6));

        menuBest = new TextView(this);
        menuBest.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
        menuBest.setTypeface(typeBold);
        menuBest.setTextColor(theme.playerPink);
        menuBest.setGravity(Gravity.CENTER);
        content.addView(menuBest, wrapWithTopMargin(16));

        menuDifficulty = new TextView(this);
        menuDifficulty.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12);
        menuDifficulty.setTypeface(typeRegular);
        menuDifficulty.setTextColor(theme.textMuted);
        menuDifficulty.setGravity(Gravity.CENTER);
        content.addView(menuDifficulty, wrapWithTopMargin(6));

        Button start = primaryButton(R.string.start_game);
        LinearLayout.LayoutParams startParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(54));
        startParams.topMargin = dp(22);
        content.addView(start, startParams);
        start.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                startGame();
            }
        });

        Button settings = secondaryButton(R.string.settings);
        LinearLayout.LayoutParams settingsParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(48));
        settingsParams.topMargin = dp(10);
        content.addView(settings, settingsParams);
        settings.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                showSettings();
            }
        });

        TextView howTo = new TextView(this);
        howTo.setText(R.string.how_to);
        howTo.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12);
        howTo.setTypeface(typeRegular);
        howTo.setTextColor(theme.textMuted);
        howTo.setGravity(Gravity.CENTER);
        howTo.setLineSpacing(dp(4), 1f);
        content.addView(howTo, wrapWithTopMargin(20));

        FrameLayout.LayoutParams contentParams = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        contentParams.gravity = Gravity.CENTER;
        overlay.addView(content, contentParams);

        root.addView(overlay, matchParent());
    }

    // ------------------------------------------------------------------- settings

    private void buildSettings() {
        FrameLayout overlay = new FrameLayout(this);
        overlay.setBackground(new GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM,
                new int[] {theme.menuOverlayTop, theme.menuOverlayBottom}));
        overlay.setClickable(true);
        overlay.setVisibility(View.GONE);
        settingsOverlay = overlay;

        LinearLayout card = buildCard();
        card.setVisibility(View.VISIBLE);
        card.setAlpha(1f);
        card.setPadding(dp(22), dp(20), dp(22), dp(20));

        TextView title = new TextView(this);
        title.setText(R.string.settings);
        title.setTextSize(TypedValue.COMPLEX_UNIT_SP, 20);
        title.setTypeface(typeBold);
        title.setTextColor(theme.textPrimary);
        title.setGravity(Gravity.CENTER);
        card.addView(title);

        chipEasy = makeChip(R.string.difficulty_easy);
        chipNormal = makeChip(R.string.difficulty_normal);
        chipHard = makeChip(R.string.difficulty_hard);
        card.addView(sectionLabel(R.string.difficulty), wrapWithTopMargin(18));
        card.addView(chipRow(chipEasy, chipNormal, chipHard), wrapWithTopMargin(8));

        chipNight = makeChip(R.string.theme_night);
        chipDay = makeChip(R.string.theme_day);
        card.addView(sectionLabel(R.string.appearance), wrapWithTopMargin(18));
        card.addView(chipRow(chipNight, chipDay), wrapWithTopMargin(8));

        chipSoundOn = makeChip(R.string.on);
        chipSoundOff = makeChip(R.string.off);
        card.addView(sectionLabel(R.string.sound), wrapWithTopMargin(18));
        card.addView(chipRow(chipSoundOn, chipSoundOff), wrapWithTopMargin(8));

        Button back = primaryButton(R.string.back);
        LinearLayout.LayoutParams backParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(48));
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

        FrameLayout.LayoutParams cardParams = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        cardParams.gravity = Gravity.CENTER;
        cardParams.leftMargin = dp(20);
        cardParams.rightMargin = dp(20);
        overlay.addView(card, cardParams);

        root.addView(overlay, matchParent());
    }

    private TextView sectionLabel(int textRes) {
        TextView label = new TextView(this);
        label.setText(textRes);
        label.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13);
        label.setTypeface(typeRegular);
        label.setTextColor(theme.textMuted);
        label.setGravity(Gravity.CENTER);
        return label;
    }

    private TextView makeChip(int textRes) {
        TextView chip = new TextView(this);
        chip.setText(textRes);
        chip.setGravity(Gravity.CENTER);
        chip.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
        chip.setPadding(dp(10), dp(11), dp(10), dp(11));
        return chip;
    }

    private LinearLayout chipRow(TextView... chips) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        for (int i = 0; i < chips.length; i++) {
            LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
                    0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f);
            if (i > 0) {
                params.leftMargin = dp(8);
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
        GradientDrawable background = new GradientDrawable();
        background.setCornerRadius(dp(12));
        background.setColor(selected ? theme.primaryButtonBackground : theme.secondaryButtonBackground);
        background.setStroke(dp(1), selected ? theme.primaryButtonBackground : theme.panelStroke);
        chip.setBackground(background);
        chip.setTextColor(selected ? theme.primaryButtonText : theme.secondaryButtonText);
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
        LinearLayout panel = buildCard();

        TextView title = new TextView(this);
        title.setText(R.string.paused_title);
        title.setTextSize(TypedValue.COMPLEX_UNIT_SP, 22);
        title.setTypeface(typeBold);
        title.setTextColor(theme.textPrimary);
        title.setGravity(Gravity.CENTER);
        panel.addView(title);

        Button resume = primaryButton(R.string.resume);
        panel.addView(resume, fullWidthButtonParams(20));
        resume.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                hidePause();
            }
        });

        Button restart = secondaryButton(R.string.restart);
        panel.addView(restart, fullWidthButtonParams(10));
        restart.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                hidePause();
                startGame();
            }
        });

        Button menu = secondaryButton(R.string.menu);
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
        LinearLayout panel = buildCard();

        gameOverTitle = new TextView(this);
        gameOverTitle.setText(R.string.game_over);
        gameOverTitle.setTextSize(TypedValue.COMPLEX_UNIT_SP, 22);
        gameOverTitle.setTypeface(typeBold);
        gameOverTitle.setTextColor(theme.textPrimary);
        gameOverTitle.setGravity(Gravity.CENTER);
        panel.addView(gameOverTitle);

        gameOverScore = new TextView(this);
        gameOverScore.setTextSize(TypedValue.COMPLEX_UNIT_SP, 22);
        gameOverScore.setTypeface(typeBold);
        gameOverScore.setTextColor(theme.playerCyan);
        gameOverScore.setGravity(Gravity.CENTER);
        panel.addView(gameOverScore, wrapWithTopMargin(12));

        gameOverRows = new TextView(this);
        gameOverRows.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13);
        gameOverRows.setTypeface(typeRegular);
        gameOverRows.setTextColor(theme.textSecondary);
        gameOverRows.setGravity(Gravity.CENTER);
        panel.addView(gameOverRows, wrapWithTopMargin(6));

        gameOverBest = new TextView(this);
        gameOverBest.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13);
        gameOverBest.setTypeface(typeBold);
        gameOverBest.setTextColor(theme.playerPink);
        gameOverBest.setGravity(Gravity.CENTER);
        panel.addView(gameOverBest, wrapWithTopMargin(6));

        Button again = primaryButton(R.string.play_again);
        panel.addView(again, fullWidthButtonParams(18));
        again.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                hideGameOver();
                startGame();
            }
        });

        Button menu = secondaryButton(R.string.menu);
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

    private LinearLayout buildCard() {
        LinearLayout panel = new LinearLayout(this);
        panel.setOrientation(LinearLayout.VERTICAL);
        panel.setGravity(Gravity.CENTER_HORIZONTAL);
        panel.setPadding(dp(24), dp(22), dp(24), dp(22));
        panel.setMinimumWidth(dp(252));
        panel.setClickable(true);

        GradientDrawable background = new GradientDrawable();
        background.setColor(theme.panelBackground);
        background.setCornerRadius(dp(22));
        background.setStroke(dp(1), theme.panelStroke);
        panel.setBackground(background);

        panel.setVisibility(View.GONE);
        panel.setAlpha(0f);
        return panel;
    }

    private Button primaryButton(int textRes) {
        Button button = new Button(this);
        button.setText(textRes);
        button.setAllCaps(false);
        button.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16);
        button.setTypeface(typeBold);
        button.setTextColor(theme.primaryButtonText);
        button.setBackgroundTintList(android.content.res.ColorStateList.valueOf(
                theme.primaryButtonBackground));
        return button;
    }

    private Button secondaryButton(int textRes) {
        Button button = new Button(this);
        button.setText(textRes);
        button.setAllCaps(false);
        button.setTextSize(TypedValue.COMPLEX_UNIT_SP, 15);
        button.setTypeface(typeRegular);
        button.setTextColor(theme.secondaryButtonText);
        GradientDrawable background = new GradientDrawable();
        background.setColor(theme.secondaryButtonBackground);
        background.setCornerRadius(dp(14));
        background.setStroke(dp(1), theme.panelStroke);
        button.setBackground(background);
        button.setPadding(dp(12), dp(10), dp(12), dp(10));
        return button;
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
        params.leftMargin = dp(24);
        params.rightMargin = dp(24);
        return params;
    }

    private FrameLayout.LayoutParams matchParent() {
        return new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT);
    }

    // ------------------------------------------------------------------------ flow

    private void startGame() {
        menuOverlay.setVisibility(View.GONE);
        if (settingsOverlay.getVisibility() == View.VISIBLE) {
            hideSettings();
        }
        hideGameOver();
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
        gameView.pauseGame();
        hud.setVisibility(View.GONE);
        scrim.setVisibility(View.VISIBLE);
        fadeIn(scrim);
        panelIn(pausePanel);
    }

    private void hidePause() {
        hideCard(pausePanel);
        hud.setVisibility(View.VISIBLE);
        gameView.resumeGame();
    }

    private void showGameOver(int score, int rowsCleared) {
        boolean record = GamePrefs.submitBest(this, score);
        gameOverTitle.setText(record ? R.string.new_record : R.string.game_over);
        gameOverScore.setText(getString(R.string.score_line, score));
        gameOverRows.setText(getString(R.string.rows_line, rowsCleared));
        gameOverBest.setText(getString(R.string.best_line, GamePrefs.best(this)));

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
        int best = GamePrefs.best(this);
        if (menuBest != null) {
            menuBest.setText(getString(R.string.best_line, best));
        }
        if (hudBest != null) {
            hudBest.setText(getString(R.string.best_line, best));
        }
        if (menuDifficulty != null) {
            menuDifficulty.setText(getString(R.string.difficulty_line,
                    getString(difficulty.labelRes())));
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
    }

    @Override
    protected void onPause() {
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
