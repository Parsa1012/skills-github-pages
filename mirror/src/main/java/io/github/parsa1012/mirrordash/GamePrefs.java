package io.github.parsa1012.mirrordash;

import android.content.Context;
import android.content.SharedPreferences;

/** The two things worth persisting: the best score and the sound preference. */
public final class GamePrefs {

    private static final String PREFS_NAME = "mirror_dash";
    private static final String KEY_BEST = "best_score";
    private static final String KEY_SOUND = "sound_enabled";

    private GamePrefs() {
    }

    public static int best(Context context) {
        return prefs(context).getInt(KEY_BEST, 0);
    }

    /** Saves the score if it beats the stored record and reports whether it was a record. */
    public static boolean submitBest(Context context, int score) {
        int current = best(context);
        if (score <= current) {
            return false;
        }
        prefs(context).edit().putInt(KEY_BEST, score).apply();
        return true;
    }

    public static boolean soundEnabled(Context context) {
        return prefs(context).getBoolean(KEY_SOUND, true);
    }

    public static void setSoundEnabled(Context context, boolean enabled) {
        prefs(context).edit().putBoolean(KEY_SOUND, enabled).apply();
    }

    private static SharedPreferences prefs(Context context) {
        return context.getApplicationContext()
                .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
    }
}
