package io.github.parsa1012.mirrordash;

import android.app.Activity;
import android.content.pm.ActivityInfo;
import android.content.res.ColorStateList;
import android.graphics.Color;
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
 * Hosts the game surface plus the Persian overlay UI (hint and game-over panel).
 * Phase 3 will replace this overlay with the full menu, pause screen and juice.
 */
public class GameActivity extends Activity {

    private GameView gameView;
    private TextView hint;
    private View scrim;
    private LinearLayout panel;
    private TextView panelTitle;
    private TextView scoreLine;
    private TextView rowsLine;
    private TextView bestLine;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_PORTRAIT);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);

        gameView = new GameView(this);

        FrameLayout root = new FrameLayout(this);
        root.addView(gameView, matchParent());

        hint = new TextView(this);
        hint.setText(R.string.hint);
        hint.setTextColor(Color.parseColor("#8B949E"));
        hint.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
        hint.setGravity(Gravity.CENTER);
        FrameLayout.LayoutParams hintParams = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        hintParams.gravity = Gravity.TOP | Gravity.CENTER_HORIZONTAL;
        hintParams.topMargin = dp(96);
        root.addView(hint, hintParams);

        scrim = new View(this);
        scrim.setBackgroundColor(Color.parseColor("#B3080F1A"));
        scrim.setClickable(true);
        scrim.setVisibility(View.GONE);
        root.addView(scrim, matchParent());

        panel = buildPanel();
        FrameLayout.LayoutParams panelParams = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        panelParams.gravity = Gravity.CENTER;
        panelParams.leftMargin = dp(24);
        panelParams.rightMargin = dp(24);
        root.addView(panel, panelParams);

        gameView.setOnFirstTouchListener(new Runnable() {
            @Override
            public void run() {
                hideHint();
            }
        });
        gameView.setGameOverListener(new GameView.GameOverListener() {
            @Override
            public void onGameOver(int score, int rowsCleared) {
                showGameOver(score, rowsCleared);
            }
        });

        setContentView(root);
        hideSystemBars();
    }

    private LinearLayout buildPanel() {
        LinearLayout container = new LinearLayout(this);
        container.setOrientation(LinearLayout.VERTICAL);
        container.setGravity(Gravity.CENTER_HORIZONTAL);
        container.setPadding(dp(26), dp(24), dp(26), dp(24));
        container.setMinimumWidth(dp(250));
        container.setClickable(true);

        GradientDrawable background = new GradientDrawable();
        background.setColor(Color.parseColor("#161B22"));
        background.setCornerRadius(dp(22));
        background.setStroke(dp(1), Color.parseColor("#233047"));
        container.setBackground(background);
        container.setAlpha(0f);
        container.setVisibility(View.GONE);

        panelTitle = new TextView(this);
        panelTitle.setText(R.string.game_over);
        panelTitle.setTextColor(Color.parseColor("#E6EDF3"));
        panelTitle.setTextSize(TypedValue.COMPLEX_UNIT_SP, 24);
        panelTitle.setGravity(Gravity.CENTER);
        container.addView(panelTitle);

        scoreLine = statText(20, "#22D3EE", 14);
        container.addView(scoreLine);

        rowsLine = statText(14, "#8B949E", 6);
        container.addView(rowsLine);

        bestLine = statText(14, "#F472B6", 6);
        container.addView(bestLine);

        Button again = new Button(this);
        again.setText(R.string.play_again);
        again.setAllCaps(false);
        again.setTextSize(TypedValue.COMPLEX_UNIT_SP, 17);
        again.setTextColor(Color.parseColor("#08121F"));
        again.setBackgroundTintList(ColorStateList.valueOf(Color.parseColor("#22D3EE")));
        LinearLayout.LayoutParams buttonParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(52));
        buttonParams.topMargin = dp(20);
        container.addView(again, buttonParams);
        again.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                startNewRun();
            }
        });

        return container;
    }

    private TextView statText(int sizeSp, String color, int topMarginDp) {
        TextView view = new TextView(this);
        view.setTextSize(TypedValue.COMPLEX_UNIT_SP, sizeSp);
        view.setTextColor(Color.parseColor(color));
        view.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        params.topMargin = dp(topMarginDp);
        view.setLayoutParams(params);
        return view;
    }

    private void showGameOver(int score, int rowsCleared) {
        boolean record = ScoreStore.submitBest(this, score);
        int best = ScoreStore.best(this);

        panelTitle.setText(record ? R.string.new_record : R.string.game_over);
        scoreLine.setText(getString(R.string.score_line, score));
        rowsLine.setText(getString(R.string.rows_line, rowsCleared));
        bestLine.setText(getString(R.string.best_line, best));

        hideHint();
        scrim.setVisibility(View.VISIBLE);
        scrim.setAlpha(0f);
        scrim.animate().alpha(1f).setDuration(200).start();

        panel.setVisibility(View.VISIBLE);
        panel.setAlpha(0f);
        panel.setScaleX(0.94f);
        panel.setScaleY(0.94f);
        panel.animate().alpha(1f).scaleX(1f).scaleY(1f).setDuration(220).start();
    }

    private void startNewRun() {
        scrim.animate().alpha(0f).setDuration(160)
                .withEndAction(new Runnable() {
                    @Override
                    public void run() {
                        scrim.setVisibility(View.GONE);
                    }
                }).start();
        panel.animate().alpha(0f).scaleX(0.94f).scaleY(0.94f).setDuration(160)
                .withEndAction(new Runnable() {
                    @Override
                    public void run() {
                        panel.setVisibility(View.GONE);
                    }
                }).start();
        gameView.restart();
    }

    private void hideHint() {
        if (hint.getVisibility() != View.VISIBLE) {
            return;
        }
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

    private FrameLayout.LayoutParams matchParent() {
        return new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT);
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (gameView != null) {
            gameView.start();
        }
    }

    @Override
    protected void onPause() {
        if (gameView != null) {
            gameView.stop();
        }
        super.onPause();
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
