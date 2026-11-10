package io.github.parsa1012.mirrordash;

import android.content.Context;
import android.content.SharedPreferences;

/** Everything the game remembers between launches. */
public final class GamePrefs {

    private static final String PREFS_NAME = "mirror_dash";
    /** Record from versions 1.0-1.2, kept only to be migrated into the Normal record. */
    private static final String KEY_BEST_LEGACY = "best_score";
    private static final String KEY_BEST_PREFIX = "best_";
    private static final String KEY_MIGRATED = "records_split";
    private static final String KEY_SOUND = "sound_enabled";
    private static final String KEY_NIGHT = "night_mode";
    private static final String KEY_DIFFICULTY = "difficulty";
    private static final String KEY_LANG = "language";

    private GamePrefs() {
    }

    /**
     * Each difficulty keeps its own record. Before 1.3 there was a single record, so the old score remains stored but is not attributed to a tier because its difficulty is unknown.
     */
    public static void migrate(Context context) {
        SharedPreferences prefs = prefs(context);
        if (prefs.getBoolean(KEY_MIGRATED, false)) {
            return;
        }
        prefs.edit().putBoolean(KEY_MIGRATED, true).apply();
    }

    public static int best(Context context, Difficulty difficulty) {
        return prefs(context).getInt(bestKey(difficulty), 0);
    }

    /** Saves the score if it beats the record of that difficulty and reports whether it did. */
    public static boolean submitBest(Context context, Difficulty difficulty, int score) {
        if (score <= best(context, difficulty)) {
            return false;
        }
        prefs(context).edit().putInt(bestKey(difficulty), score).apply();
        return true;
    }

    public static boolean soundEnabled(Context context) {
        return prefs(context).getBoolean(KEY_SOUND, true);
    }

    public static void setSoundEnabled(Context context, boolean enabled) {
        prefs(context).edit().putBoolean(KEY_SOUND, enabled).apply();
    }

    public static boolean nightMode(Context context) {
        return prefs(context).getBoolean(KEY_NIGHT, true);
    }

    public static void setNightMode(Context context, boolean night) {
        prefs(context).edit().putBoolean(KEY_NIGHT, night).apply();
    }

    public static Difficulty difficulty(Context context) {
        return Difficulty.fromName(prefs(context).getString(KEY_DIFFICULTY, null));
    }

    public static void setDifficulty(Context context, Difficulty difficulty) {
        prefs(context).edit().putString(KEY_DIFFICULTY, difficulty.name()).apply();
    }

    public static Lang lang(Context context) {
        return Lang.fromName(prefs(context).getString(KEY_LANG, null));
    }

    public static void setLang(Context context, Lang lang) {
        prefs(context).edit().putString(KEY_LANG, lang.name()).apply();
    }

    private static String bestKey(Difficulty difficulty) {
        return KEY_BEST_PREFIX + (difficulty == null ? Difficulty.NORMAL : difficulty).name();
    }

    private static SharedPreferences prefs(Context context) {
        return context.getApplicationContext()
                .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
    }
}
