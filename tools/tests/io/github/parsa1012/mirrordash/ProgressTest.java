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
    private static void check(boolean value, String message) { if (!value) throw new AssertionError(message); }
    public static void main(String[] args) {
        App c = new App();
        c.store.putBoolean("sound_enabled", false);
        c.store.putInt("best_EASY", 200);
        GamePrefs.migrate(c);
        check(!GamePrefs.helpSeen(c), "new install shows guide");
        GamePrefs.setHelpSeen(c); GamePrefs.migrate(c);
        check(GamePrefs.helpSeen(c), "guide acknowledgement persists");
        App existing = new App(); existing.store.putBoolean("records_split", true);
        GamePrefs.migrate(existing);
        check(GamePrefs.helpSeen(existing), "existing installations not interrupted by onboarding");
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
        check(GamePrefs.claimInitialStageBonus(c) && GamePrefs.coins(c) == 20);
        check(!GamePrefs.claimInitialStageBonus(c) && GamePrefs.coins(c) == 20);
        check(GamePrefs.completeStage(c, 4) == 0 && GamePrefs.unlockedStage(c) == 1);
        check(GamePrefs.completeStage(c, 1) == 20 && GamePrefs.unlockedStage(c) == 2 && GamePrefs.stageComplete(c, 1));
        check(GamePrefs.completeStage(c, 1) == 0 && GamePrefs.unlockedStage(c) == 2 && GamePrefs.coins(c) == 40);
        GamePrefs.completeStage(c, 2); GamePrefs.completeStage(c, 3);
        GamePrefs.completeStage(c, 4); GamePrefs.completeStage(c, 5);
        check(GamePrefs.unlockedStage(c) == 5 && GamePrefs.stageComplete(c, 5) && GamePrefs.coins(c) == 100);
        GamePrefs.completeStage(c, 99); check(GamePrefs.unlockedStage(c) == 5);
        GamePrefs.setReducedEffects(c, true); GamePrefs.setClearMarkers(c, true);
        GamePrefs.setSensitivity(c, 1000);
        check(GamePrefs.reducedEffects(c) && GamePrefs.clearMarkers(c) && GamePrefs.sensitivity(c) == 150);
        check(GamePrefs.best(c, Difficulty.EASY) == 250);
        GamePrefs.migrate(c); check(!GamePrefs.musicEnabled(c));
        check(BallPalette.COUNT == 54 && BallPalette.price(-1) == -1);
        check(BallPalette.price(1) == 15 && BallPalette.price(46) == 180 && BallPalette.price(53) == 390);
        check(BallPalette.requiredScore(46) == 560 && BallPalette.requiredScore(53) == 1120);
        for (int animal = 0; animal < 9; animal++) {
            check(BallPalette.available(4 + animal));
            check(!BallPalette.available(14 + animal) && !BallPalette.available(24 + animal));
        }
        App wallet = new App();
        check(GamePrefs.coins(wallet) == 0 && GamePrefs.ownsPalette(wallet, 0));
        check(!GamePrefs.buyOrSelectPalette(wallet, 1));
        GamePrefs.addCoins(wallet, 2000); GamePrefs.addCoins(wallet, -5);
        check(!GamePrefs.buyOrSelectPalette(wallet, 1), "record also required");
        GamePrefs.recordRun(wallet, Difficulty.EASY, 250, 3, 5000);
        check(GamePrefs.buyOrSelectPalette(wallet, 1) && GamePrefs.coins(wallet) == 1985);
        check(GamePrefs.buyOrSelectPalette(wallet, 1) && GamePrefs.coins(wallet) == 1985);
        check(GamePrefs.buyOrSelectPalette(wallet, 0) && GamePrefs.buyOrSelectPalette(wallet, 1));
        check(GamePrefs.selectedPalette(wallet) == 1 && GamePrefs.coins(wallet) == 1985);
        check(!GamePrefs.buyOrSelectPalette(wallet, -1));
        int normalId = 34, hardId = 37;
        check(!GamePrefs.buyOrSelectPalette(wallet, normalId), "normal record is separate from easy");
        GamePrefs.recordRun(wallet, Difficulty.NORMAL, BallPalette.requiredScore(normalId), 3, 5000);
        check(GamePrefs.buyOrSelectPalette(wallet, normalId), "matching normal record unlocks");
        check(!GamePrefs.buyOrSelectPalette(wallet, hardId), "hard record is separate from normal");
        GamePrefs.recordRun(wallet, Difficulty.HARD, BallPalette.requiredScore(hardId), 3, 5000);
        check(GamePrefs.buyOrSelectPalette(wallet, hardId), "matching hard record unlocks");
        check(!GamePrefs.buyOrSelectPalette(wallet, 53), "premium requires hard record");
        check(!GamePrefs.buyOrSelectPalette(wallet, 14), "removed variant cannot be newly purchased");
        App legacy = new App();
        legacy.store.putInt("coins", 10);
        legacy.store.putBoolean("palette_owned_14", true);
        legacy.store.putBoolean("palette_owned_24", true);
        legacy.store.putBoolean("palette_owned_40", true);
        legacy.store.putBoolean("palette_owned_46", true);
        legacy.store.putInt("palette_selected", 40);
        GamePrefs.migrate(legacy);
        check(GamePrefs.ownsPalette(legacy, 4) && GamePrefs.ownsPalette(legacy, 34), "duplicate ownership maps to one item");
        check(GamePrefs.selectedPalette(legacy) == 34, "selected item migrated");
        int expected = 10 + BallPalette.price(24) + BallPalette.price(46);
        check(GamePrefs.coins(legacy) == expected, "duplicate and removed premium refunded");
        check(!GamePrefs.buyOrSelectPalette(legacy, 14) && !GamePrefs.buyOrSelectPalette(legacy, 46), "removed items cannot be selected");
        GamePrefs.migrate(legacy); check(GamePrefs.coins(legacy) == expected, "migration runs only once");
        App selectedPremium = new App(); selectedPremium.store.putBoolean("palette_owned_47", true);
        selectedPremium.store.putInt("palette_selected", 47); GamePrefs.migrate(selectedPremium);
        check(GamePrefs.selectedPalette(selectedPremium) == 0 && GamePrefs.coins(selectedPremium) == BallPalette.price(47), "selected premium refunded and reset");
        for (int i = 0; i < BallPalette.COUNT; i++) {
            check(BallPalette.valid(i) && BallPalette.price(i) >= 0);
            check(!BallPalette.available(i) || i < 4 || BallPalette.assetIndex(i) >= 0 && BallPalette.assetIndex(i) < BallPalette.assetCount());
        }
        check(GamePrefs.appearance(c, false) == 1 && GamePrefs.appearance(c, true) == 2);
        check(GamePrefs.unlockedStage(c) == 5 && GamePrefs.best(c, Difficulty.EASY) == 250);
        System.out.println("Progress, migration and separate settings PASS");
    }
}
