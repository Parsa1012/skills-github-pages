package io.github.parsa1012.mirrordash;

import android.content.Context;
import android.content.SharedPreferences;

/** Everything the game remembers between launches. */
public final class GamePrefs {

    private static final String PREFS_NAME = "mirror_dash";
    /** Legacy record from versions 1.0-1.2 remains untouched: its tier is unknown. */
    private static final String KEY_BEST_LEGACY = "best_score";
    private static final String KEY_BEST_PREFIX = "best_";
    private static final String KEY_MIGRATED = "records_split";
    private static final String KEY_SOUND = "sound_enabled";
    private static final String KEY_MUSIC = "music_enabled";
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
        if (!prefs.contains(KEY_MUSIC)) {
            prefs.edit().putBoolean(KEY_MUSIC, prefs.getBoolean(KEY_SOUND, true)).apply();
        }
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

    private static String statKey(Difficulty d, String stat) {
        return "stats_" + d.name() + "_" + stat;
    }

    /** Only completed runs are included; older score records remain untouched. */
    public static boolean recordRun(Context context, Difficulty d, int score, int rows, long millis) {
        SharedPreferences p = prefs(context);
        int safeScore = Math.max(0, score), safeRows = Math.max(0, rows);
        long safeTime = Math.max(0, millis);
        boolean record = safeScore > best(context, d);
        SharedPreferences.Editor edit = p.edit();
        if (record) edit.putInt(bestKey(d), safeScore);
        edit.putInt(statKey(d, "runs"), p.getInt(statKey(d, "runs"), 0) + 1);
        edit.putLong(statKey(d, "total_rows"), p.getLong(statKey(d, "total_rows"), 0) + safeRows);
        edit.putInt(statKey(d, "best_rows"), Math.max(p.getInt(statKey(d, "best_rows"), 0), safeRows));
        edit.putLong(statKey(d, "best_time"), Math.max(p.getLong(statKey(d, "best_time"), 0), safeTime));
        edit.putInt(statKey(d, "best_level"), Math.max(p.getInt(statKey(d, "best_level"), 0), 1 + safeRows / LevelConfig.ROWS_PER_LEVEL));
        edit.apply();
        return record;
    }

    public static int runs(Context c, Difficulty d) { return prefs(c).getInt(statKey(d, "runs"), 0); }
    public static long totalRows(Context c, Difficulty d) { return prefs(c).getLong(statKey(d, "total_rows"), 0); }
    public static int bestRows(Context c, Difficulty d) { return prefs(c).getInt(statKey(d, "best_rows"), 0); }
    public static long bestTime(Context c, Difficulty d) { return prefs(c).getLong(statKey(d, "best_time"), 0); }
    public static int bestLevel(Context c, Difficulty d) { return prefs(c).getInt(statKey(d, "best_level"), 0); }
    public static int highestScore(Context c) {
        int highest = 0;
        for (Difficulty d : Difficulty.values()) highest = Math.max(highest, best(c, d));
        return highest;
    }
    public static int volume(Context c, boolean music) {
        return Math.max(0, Math.min(100, prefs(c).getInt(music ? "volume_music" : "volume_sound", 100)));
    }
    public static void setVolume(Context c, boolean music, int value) {
        prefs(c).edit().putInt(music ? "volume_music" : "volume_sound", Math.max(0, Math.min(100, value))).apply();
    }
    public static int appearance(Context c, boolean background) {
        return Progress.validStyle(prefs(c).getInt(background ? "style_background" : "style_ball", 0), highestScore(c));
    }
    public static void setAppearance(Context c, boolean background, int style) {
        prefs(c).edit().putInt(background ? "style_background" : "style_ball", Progress.validStyle(style, highestScore(c))).apply();
    }

    public static boolean soundEnabled(Context context) {
        return prefs(context).getBoolean(KEY_SOUND, true);
    }

    public static void setSoundEnabled(Context context, boolean enabled) {
        prefs(context).edit().putBoolean(KEY_SOUND, enabled).apply();
    }

    /** On upgrade, inherit the old combined sound setting until the player changes music. */
    public static boolean musicEnabled(Context context) {
        return prefs(context).getBoolean(KEY_MUSIC, soundEnabled(context));
    }

    public static void setMusicEnabled(Context context, boolean enabled) {
        prefs(context).edit().putBoolean(KEY_MUSIC, enabled).apply();
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
