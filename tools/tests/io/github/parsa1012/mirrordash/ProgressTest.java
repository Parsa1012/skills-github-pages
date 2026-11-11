package io.github.parsa1012.mirrordash;
import android.content.Context;
import android.content.SharedPreferences;
import java.util.HashMap;
import java.util.Map;

/** Unit tests the real preference and unlock logic without an Android device. */
public final class ProgressTest {
    private static final class Store implements SharedPreferences, SharedPreferences.Editor {
        final Map<String,Object> values = new HashMap<>();
        public boolean contains(String k) { return values.containsKey(k); }
        public int getInt(String k, int v) { return (Integer) values.getOrDefault(k, v); }
        public long getLong(String k, long v) { return (Long) values.getOrDefault(k, v); }
        public boolean getBoolean(String k, boolean v) { return (Boolean) values.getOrDefault(k, v); }
        public String getString(String k, String v) { return (String) values.getOrDefault(k, v); }
        public Editor edit() { return this; }
        public Editor putInt(String k, int v) { values.put(k,v); return this; }
        public Editor putLong(String k, long v) { values.put(k,v); return this; }
        public Editor putBoolean(String k, boolean v) { values.put(k,v); return this; }
        public Editor putString(String k, String v) { values.put(k,v); return this; }
        public void apply() {}
    }
    private static final class App extends Context {
        final Store store = new Store();
        public SharedPreferences getSharedPreferences(String name, int mode) { return store; }
    }
    private static void check(boolean value) { if (!value) throw new AssertionError(); }
    public static void main(String[] args) {
        App c = new App();
        c.store.putBoolean("sound_enabled", false);
        c.store.putInt("best_EASY", 200);
        GamePrefs.migrate(c);
        check(!GamePrefs.musicEnabled(c) && !GamePrefs.soundEnabled(c));
        GamePrefs.setSoundEnabled(c, true);
        check(GamePrefs.soundEnabled(c) && !GamePrefs.musicEnabled(c));
        check(GamePrefs.best(c, Difficulty.EASY) == 200 && GamePrefs.runs(c, Difficulty.EASY) == 0);
        check(!GamePrefs.recordRun(c, Difficulty.EASY, 100, 12, 32000));
        check(GamePrefs.recordRun(c, Difficulty.EASY, 250, 5, 47000));
        check(GamePrefs.runs(c, Difficulty.EASY) == 2 && GamePrefs.totalRows(c, Difficulty.EASY) == 17);
        check(GamePrefs.best(c, Difficulty.EASY) == 250 && GamePrefs.bestRows(c, Difficulty.EASY) == 12);
        check(GamePrefs.bestTime(c, Difficulty.EASY) == 47000 && GamePrefs.bestLevel(c, Difficulty.EASY) == 3);
        check(GamePrefs.best(c, Difficulty.HARD) == 0 && GamePrefs.runs(c, Difficulty.HARD) == 0);
        check(Progress.validStyle(1,149) == 0 && Progress.validStyle(1,150) == 1);
        check(Progress.validStyle(2,399) == 0 && Progress.validStyle(2,400) == 2);
        GamePrefs.setAppearance(c,false,1); check(GamePrefs.appearance(c,false)==1);
        GamePrefs.setAppearance(c,true,2); check(GamePrefs.appearance(c,true)==0);
        GamePrefs.recordRun(c, Difficulty.HARD, 400, 3, 5000);
        GamePrefs.setAppearance(c,true,2); check(GamePrefs.appearance(c,true)==2);
        check(GamePrefs.volume(c,true)==100 && GamePrefs.volume(c,false)==100);
        GamePrefs.setVolume(c,true,27); GamePrefs.setVolume(c,false,200);
        check(GamePrefs.volume(c,true)==27 && GamePrefs.volume(c,false)==100);
        GamePrefs.setVolume(c,false,-10); check(GamePrefs.volume(c,false)==0);
        GamePrefs.migrate(c); check(!GamePrefs.musicEnabled(c));
        System.out.println("Progress, migration and separate settings PASS");
    }
}
