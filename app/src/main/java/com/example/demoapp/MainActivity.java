package com.example.demoapp;

import android.app.Activity;
import android.content.res.ColorStateList;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.os.Build;
import android.os.Bundle;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;

/**
 * A tiny demo app with no third-party dependencies, built only with the Android framework.
 * It shows a tap counter, a reset button and a few device facts, which makes it easy to verify
 * that the generated APK installs and runs correctly on a real device.
 */
public class MainActivity extends Activity {

    private int taps = 0;
    private TextView counterView;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(buildUi());
    }

    @Override
    protected void onSaveInstanceState(Bundle outState) {
        super.onSaveInstanceState(outState);
        outState.putInt("taps", taps);
    }

    @Override
    protected void onRestoreInstanceState(Bundle savedInstanceState) {
        super.onRestoreInstanceState(savedInstanceState);
        taps = savedInstanceState.getInt("taps", 0);
        updateCounter();
    }

    private View buildUi() {
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setGravity(Gravity.CENTER);
        root.setPadding(dp(24), dp(32), dp(24), dp(32));

        GradientDrawable background = new GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                new int[] {Color.parseColor("#0D1117"), Color.parseColor("#1B2430")});
        root.setBackground(background);

        LinearLayout card = new LinearLayout(this);
        card.setOrientation(LinearLayout.VERTICAL);
        card.setGravity(Gravity.CENTER_HORIZONTAL);
        card.setPadding(dp(24), dp(28), dp(24), dp(28));
        card.setBackground(rounded(Color.parseColor("#161B22"), 20));
        root.addView(card, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT));

        TextView title = new TextView(this);
        title.setText("Demo APK");
        title.setTextColor(Color.parseColor("#58A6FF"));
        title.setTextSize(TypedValue.COMPLEX_UNIT_SP, 28);
        title.setGravity(Gravity.CENTER);
        card.addView(title);

        TextView subtitle = new TextView(this);
        subtitle.setText("Built automatically by GitHub Actions");
        subtitle.setTextColor(Color.parseColor("#8B949E"));
        subtitle.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
        subtitle.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams subtitleParams = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT);
        subtitleParams.topMargin = dp(6);
        card.addView(subtitle, subtitleParams);

        counterView = new TextView(this);
        counterView.setTextColor(Color.WHITE);
        counterView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 64);
        counterView.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams counterParams = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT);
        counterParams.topMargin = dp(24);
        card.addView(counterView, counterParams);

        TextView counterLabel = new TextView(this);
        counterLabel.setText("taps");
        counterLabel.setTextColor(Color.parseColor("#8B949E"));
        counterLabel.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16);
        counterLabel.setGravity(Gravity.CENTER);
        card.addView(counterLabel);

        Button tapButton = makeButton("Tap me", "#238636");
        tapButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                taps++;
                updateCounter();
            }
        });
        card.addView(tapButton, buttonParams());

        Button resetButton = makeButton("Reset", "#30363D");
        resetButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                taps = 0;
                updateCounter();
            }
        });
        card.addView(resetButton, buttonParams());

        TextView deviceInfo = new TextView(this);
        deviceInfo.setText("Android " + Build.VERSION.RELEASE
                + "  ·  API " + Build.VERSION.SDK_INT
                + "\n" + Build.MANUFACTURER + " " + Build.MODEL
                + "\nversion " + BuildConfig.VERSION_NAME);
        deviceInfo.setTextColor(Color.parseColor("#6E7681"));
        deviceInfo.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12);
        deviceInfo.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams infoParams = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT);
        infoParams.topMargin = dp(28);
        root.addView(deviceInfo, infoParams);

        updateCounter();
        return root;
    }

    private void updateCounter() {
        if (counterView != null) {
            counterView.setText(String.valueOf(taps));
        }
    }

    private Button makeButton(String label, String color) {
        Button button = new Button(this);
        button.setText(label);
        button.setAllCaps(false);
        button.setTextColor(Color.WHITE);
        button.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16);
        button.setBackgroundTintList(ColorStateList.valueOf(Color.parseColor(color)));
        return button;
    }

    private LinearLayout.LayoutParams buttonParams() {
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT);
        params.topMargin = dp(16);
        return params;
    }

    private GradientDrawable rounded(int color, float radiusDp) {
        GradientDrawable drawable = new GradientDrawable();
        drawable.setColor(color);
        drawable.setCornerRadius(dp(radiusDp));
        return drawable;
    }

    private int dp(float value) {
        return Math.round(TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_DIP, value, getResources().getDisplayMetrics()));
    }
}
