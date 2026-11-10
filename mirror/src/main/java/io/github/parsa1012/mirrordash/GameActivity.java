package io.github.parsa1012.mirrordash;

import android.app.Activity;
import android.content.pm.ActivityInfo;
import android.content.res.ColorStateList;
import android.graphics.Color;
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
import android.widget.LinearLayout;
import android.widget.TextView;

/**
 * Hosts the game surface and the Persian overlay UI: menu, in-game HUD, pause panel and
 * game-over panel. All Persian text lives in TextViews so Android handles shaping and RTL;
 * the canvas only draws numbers and shapes.
 */
public class GameActivity extends Activity {

    private FrameLayout root;
    private GameView gameView;

    private LinearLayout hud;
    private TextView pauseButton;
    private TextView hudBest;

    private TextView hint;
    private boolean hintConsumed;

    private View scrim;
    private View menuOverlay;
    private TextView menuBest;
    private Button soundButton;

    private LinearLayout pausePanel;
    private LinearLayout gameOverPanel;
    private TextView gameOverTitle;
    private TextView gameOverScore;
    private TextView gameOverRows;
    private TextView gameOverBest;

    private boolean soundEnabled;
    private boolean pauseOnResume;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_PORTRAIT);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);

        root = new FrameLayout(this);
        gameView = new GameView(this);
        root.addView(gameView, matchParent());

        soundEnabled = GamePrefs.soundEnabled(this);
        gameView.setSoundEnabled(soundEnabled);

        buildHud();
        buildHint();
        buildScrim();
        buildMenu();
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
    }

    // --------------------------------------------------------------------- UI build

    private void buildHud() {
        hud = new LinearLayout(this);
        hud.setOrientation(LinearLayout.HORIZONTAL);
        hud.setGravity(Gravity.CENTER_VERTICAL);
        hud.setPadding(dp(14), dp(24), dp(18), 0);
        hud.setVisibility(View.GONE);

        pauseButton = new TextView(this);
        pauseButton.setText("II");
        pauseButton.setTextSize(TypedValue.COMPLEX_UNIT_SP, 18);
        pauseButton.setTypeface(Typeface.create(Typeface.MONOSPACE, Typeface.BOLD));
        pauseButton.setTextColor(Color.parseColor("#8B949E"));
        pauseButton.setGravity(Gravity.CENTER);
        pauseButton.setPadding(dp(10), dp(6), dp(10), dp(6));
        pauseButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                showPause();
            }
        });
        hud.addView(pauseButton);

        hudBest = new TextView(this);
        hudBest.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13);
        hudBest.setTextColor(Color.parseColor("#6E7681"));
        hudBest.setGravity(Gravity.END);
        LinearLayout.LayoutParams bestParams = new LinearLayout.LayoutParams(
                0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f);
        hud.addView(hudBest, bestParams);

        FrameLayout.LayoutParams params = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        params.gravity = Gravity.TOP;
        root.addView(hud, params);
    }

    private void buildHint() {
        hint = new TextView(this);
        hint.setText(R.string.hint);
        hint.setTextColor(Color.parseColor("#8B949E"));
        hint.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
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
        scrim.setBackgroundColor(Color.parseColor("#B3080F1A"));
        scrim.setClickable(true);
        scrim.setVisibility(View.GONE);
        root.addView(scrim, matchParent());
    }

    private void buildMenu() {
        FrameLayout overlay = new FrameLayout(this);
        GradientDrawable background = new GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                new int[] {Color.parseColor("#F20B0F1A"), Color.parseColor("#D90B0F1A")});
        overlay.setBackground(background);
        overlay.setClickable(true);
        menuOverlay = overlay;

        LinearLayout content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL);
        content.setGravity(Gravity.CENTER_HORIZONTAL);
        content.setPadding(dp(30), dp(28), dp(30), dp(28));

        TextView title = new TextView(this);
        title.setText(R.string.game_name);
        title.setTextSize(TypedValue.COMPLEX_UNIT_SP, 54);
        title.setTypeface(Typeface.DEFAULT_BOLD);
        title.setTextColor(Color.parseColor("#E6EDF3"));
        title.setGravity(Gravity.CENTER);
        content.addView(title);

        TextView tagline = new TextView(this);
        tagline.setText(R.string.tagline);
        tagline.setTextSize(TypedValue.COMPLEX_UNIT_SP, 15);
        tagline.setTextColor(Color.parseColor("#58A6FF"));
        tagline.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams taglineParams = wrapWithTopMargin(8);
        content.addView(tagline, taglineParams);

        menuBest = new TextView(this);
        menuBest.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
        menuBest.setTextColor(Color.parseColor("#F472B6"));
        menuBest.setGravity(Gravity.CENTER);
        content.addView(menuBest, wrapWithTopMargin(18));

        Button start = primaryButton(R.string.start_game);
        LinearLayout.LayoutParams startParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(54));
        startParams.topMargin = dp(26);
        content.addView(start, startParams);
        start.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                startGame();
            }
        });

        soundButton = secondaryButton(R.string.sound_on);
        LinearLayout.LayoutParams soundParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(46));
        soundParams.topMargin = dp(12);
        content.addView(soundButton, soundParams);
        soundButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                soundEnabled = !soundEnabled;
                GamePrefs.setSoundEnabled(GameActivity.this, soundEnabled);
                gameView.setSoundEnabled(soundEnabled);
                refreshLabels();
            }
        });

        TextView howTo = new TextView(this);
        howTo.setText(R.string.how_to);
        howTo.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13);
        howTo.setTextColor(Color.parseColor("#6E7681"));
        howTo.setGravity(Gravity.CENTER);
        howTo.setLineSpacing(dp(4), 1f);
        content.addView(howTo, wrapWithTopMargin(24));

        FrameLayout.LayoutParams contentParams = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        contentParams.gravity = Gravity.CENTER;
        overlay.addView(content, contentParams);

        root.addView(overlay, matchParent());
    }

    private void buildPausePanel() {
        LinearLayout panel = buildCard();

        TextView title = new TextView(this);
        title.setText(R.string.paused_title);
        title.setTextSize(TypedValue.COMPLEX_UNIT_SP, 24);
        title.setTypeface(Typeface.DEFAULT_BOLD);
        title.setTextColor(Color.parseColor("#E6EDF3"));
        title.setGravity(Gravity.CENTER);
        panel.addView(title);

        Button resume = primaryButton(R.string.resume);
        panel.addView(resume, fullWidthButtonParams(22));
        resume.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                hidePause();
            }
        });

        Button restart = secondaryButton(R.string.restart);
        panel.addView(restart, fullWidthButtonParams(12));
        restart.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                hidePause();
                startGame();
            }
        });

        Button menu = secondaryButton(R.string.menu);
        panel.addView(menu, fullWidthButtonParams(12));
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
        gameOverTitle.setTextSize(TypedValue.COMPLEX_UNIT_SP, 24);
        gameOverTitle.setTypeface(Typeface.DEFAULT_BOLD);
        gameOverTitle.setTextColor(Color.parseColor("#E6EDF3"));
        gameOverTitle.setGravity(Gravity.CENTER);
        panel.addView(gameOverTitle);

        gameOverScore = new TextView(this);
        gameOverScore.setTextSize(TypedValue.COMPLEX_UNIT_SP, 20);
        gameOverScore.setTextColor(Color.parseColor("#22D3EE"));
        gameOverScore.setGravity(Gravity.CENTER);
        panel.addView(gameOverScore, wrapWithTopMargin(14));

        gameOverRows = new TextView(this);
        gameOverRows.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
        gameOverRows.setTextColor(Color.parseColor("#8B949E"));
        gameOverRows.setGravity(Gravity.CENTER);
        panel.addView(gameOverRows, wrapWithTopMargin(6));

        gameOverBest = new TextView(this);
        gameOverBest.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
        gameOverBest.setTextColor(Color.parseColor("#F472B6"));
        gameOverBest.setGravity(Gravity.CENTER);
        panel.addView(gameOverBest, wrapWithTopMargin(6));

        Button again = primaryButton(R.string.play_again);
        panel.addView(again, fullWidthButtonParams(20));
        again.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                hideGameOver();
                startGame();
            }
        });

        Button menu = secondaryButton(R.string.menu);
        panel.addView(menu, fullWidthButtonParams(12));
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

    private LinearLayout buildCard() {
        LinearLayout panel = new LinearLayout(this);
        panel.setOrientation(LinearLayout.VERTICAL);
        panel.setGravity(Gravity.CENTER_HORIZONTAL);
        panel.setPadding(dp(26), dp(24), dp(26), dp(24));
        panel.setMinimumWidth(dp(250));
        panel.setClickable(true);

        GradientDrawable background = new GradientDrawable();
        background.setColor(Color.parseColor("#161B22"));
        background.setCornerRadius(dp(22));
        background.setStroke(dp(1), Color.parseColor("#233047"));
        panel.setBackground(background);

        panel.setVisibility(View.GONE);
        panel.setAlpha(0f);
        return panel;
    }

    private Button primaryButton(int textRes) {
        Button button = new Button(this);
        button.setText(textRes);
        button.setAllCaps(false);
        button.setTextSize(TypedValue.COMPLEX_UNIT_SP, 17);
        button.setTextColor(Color.parseColor("#08121F"));
        button.setBackgroundTintList(ColorStateList.valueOf(Color.parseColor("#22D3EE")));
        return button;
    }

    private Button secondaryButton(int textRes) {
        Button button = new Button(this);
        button.setText(textRes);
        button.setAllCaps(false);
        button.setTextSize(TypedValue.COMPLEX_UNIT_SP, 15);
        button.setTextColor(Color.parseColor("#E6EDF3"));
        GradientDrawable background = new GradientDrawable();
        background.setColor(Color.parseColor("#1B2430"));
        background.setCornerRadius(dp(14));
        background.setStroke(dp(1), Color.parseColor("#2A3A55"));
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

    // ------------------------------------------------------------------- flow

    private void startGame() {
        menuOverlay.setVisibility(View.GONE);
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
        if (gameView.engine().state() != GameEngine.State.PLAYING
                && gameView.engine().state() != GameEngine.State.COUNTDOWN) {
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
        if (soundButton != null) {
            soundButton.setText(soundEnabled ? R.string.sound_on : R.string.sound_off);
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

    // ------------------------------------------------------------- lifecycle

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
