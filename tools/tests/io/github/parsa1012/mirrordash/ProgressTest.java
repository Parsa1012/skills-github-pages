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
        check(Progress.unlockedBetween(149,150) && Progress.unlockedBetween(399,400));
        check(!Progress.unlockedBetween(150,399) && !Progress.unlockedBetween(400,500));
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
        check(GamePrefs.unlockedStage(c) == 1 && !GamePrefs.stageComplete(c, 1));
        GamePrefs.completeStage(c, 4); check(GamePrefs.unlockedStage(c) == 1);
        GamePrefs.completeStage(c, 1); check(GamePrefs.unlockedStage(c) == 2 && GamePrefs.stageComplete(c, 1));
        GamePrefs.completeStage(c, 1); check(GamePrefs.unlockedStage(c) == 2);
        GamePrefs.completeStage(c, 2); GamePrefs.completeStage(c, 3);
        GamePrefs.completeStage(c, 4); GamePrefs.completeStage(c, 5);
        check(GamePrefs.unlockedStage(c) == 5 && GamePrefs.stageComplete(c, 5));
        GamePrefs.completeStage(c, 99); check(GamePrefs.unlockedStage(c) == 5);
        GamePrefs.setReducedEffects(c, true); GamePrefs.setClearMarkers(c, true);
        GamePrefs.setSensitivity(c, 1000);
        check(GamePrefs.reducedEffects(c) && GamePrefs.clearMarkers(c) && GamePrefs.sensitivity(c) == 150);
        check(GamePrefs.best(c, Difficulty.EASY) == 250);
        GamePrefs.migrate(c); check(!GamePrefs.musicEnabled(c));
        check(GamePrefs.coins(c) == 0 && GamePrefs.ownsPalette(c, 0));
        check(!GamePrefs.buyOrSelectPalette(c, 1));
        GamePrefs.addCoins(c, 12); GamePrefs.addCoins(c, -5);
        check(GamePrefs.buyOrSelectPalette(c, 1) && GamePrefs.coins(c) == 7);
        check(GamePrefs.buyOrSelectPalette(c, 1) && GamePrefs.coins(c) == 7);
        check(GamePrefs.buyOrSelectPalette(c, 0) && GamePrefs.buyOrSelectPalette(c, 1));
        check(GamePrefs.selectedPalette(c) == 1 && GamePrefs.coins(c) == 7);
        check(!GamePrefs.buyOrSelectPalette(c, 2) && !GamePrefs.buyOrSelectPalette(c, -1));
        check(GamePrefs.appearance(c, false) == 1 && GamePrefs.appearance(c, true) == 2);
        check(GamePrefs.unlockedStage(c) == 5 && GamePrefs.best(c, Difficulty.EASY) == 250);
        System.out.println("Progress, migration and separate settings PASS");
    }
}
