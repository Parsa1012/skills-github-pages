package io.github.parsa1012.mirrordash;

import java.lang.reflect.Field;

/** Tests run isolation, collision feedback and stage completion using the real engine. */
public final class ModesTest {
    private static void check(boolean ok, String message) { if (!ok) throw new AssertionError(message); }
    private static void set(Object target, String field, Object value) throws Exception {
        Field f = target.getClass().getDeclaredField(field); f.setAccessible(true); f.set(target, value);
    }
    private static GameEngine playing(GameEngine.Mode mode, int stage) throws Exception {
        GameEngine engine = new GameEngine();
        engine.resize(360, 780, 1);
        engine.configureRun(mode, stage);
        engine.startRun();
        set(engine, "state", GameEngine.State.PLAYING);
        return engine;
    }
    private static int getInt(Object target, String field) throws Exception {
        Field f = target.getClass().getDeclaredField(field); f.setAccessible(true); return f.getInt(target);
    }
    public static void main(String[] args) throws Exception {
        GameEngine practice = playing(GameEngine.Mode.PRACTICE, 1);
        ObstacleRow wall = new ObstacleRow();
        wall.begin(practice.leftPlayer().y - 10, 28);
        practice.rows().add(wall);
        practice.update(1.0 / 60);
        check(practice.state() == GameEngine.State.PLAYING, "practice must survive collision");
        check(practice.consumeImpact() && practice.impactTimer() > 0, "practice impact feedback");
        practice.update(1.0 / 60);
        check(!practice.consumeImpact(), "same row must not trigger repeatedly");
        GameEngine endless = playing(GameEngine.Mode.ENDLESS, 1);
        wall = new ObstacleRow(); wall.begin(endless.leftPlayer().y - 10, 28); endless.rows().add(wall);
        endless.update(1.0 / 60);
        check(endless.state() == GameEngine.State.DYING && endless.hitBall() != 0, "fatal impact");
        GameEngine stage = playing(GameEngine.Mode.STAGES, 2);
        check(stage.stageGoal() == 20, "stage goal");
        set(stage, "rowsCleared", 19);
        set(stage, "rowsSpawned", 20);
        set(stage, "finishY", 0f);
        ObstacleRow cleared = new ObstacleRow();
        cleared.begin(stage.leftPlayer().y + stage.leftPlayer().radius + 1, 28);
        stage.rows().add(cleared);
        stage.update(1.0 / 60);
        check(stage.rowsCleared() == 20 && !stage.stageCompleted(), "last row is not the finish line");
        set(stage, "finishY", stage.leftPlayer().y + stage.leftPlayer().radius - 1);
        stage.update(1.0 / 60);
        check(stage.stageCompleted() && stage.state() == GameEngine.State.GAME_OVER, "finish crossing completes stage");
        check(stage.consumeJustDied() && !stage.consumeJustDied(), "single end event");
        stage.startRun();
        check(!stage.stageCompleted() && Float.isNaN(stage.finishY()), "reset stage state");

        GameEngine lastCollision = playing(GameEngine.Mode.STAGES, 1);
        set(lastCollision, "rowsCleared", 15);
        set(lastCollision, "rowsSpawned", 15);
        set(lastCollision, "finishY", lastCollision.leftPlayer().y + lastCollision.leftPlayer().radius);
        wall = new ObstacleRow(); wall.begin(lastCollision.leftPlayer().y - 10, 28); lastCollision.rows().add(wall);
        lastCollision.update(1.0 / 60);
        check(!lastCollision.stageCompleted() && lastCollision.state() == GameEngine.State.DYING, "collision takes priority over finish");

        GameEngine capped = playing(GameEngine.Mode.STAGES, 1);
        set(capped, "rowsSpawned", 15);
        set(capped, "distanceSinceSpawn", 10000f);
        capped.update(1.0 / 60);
        check(capped.rows().isEmpty() && !Float.isNaN(capped.finishY()), "finish replaces new obstacles");
        capped.update(1.0 / 60);
        check(capped.rows().isEmpty(), "no obstacles after finish");
        GameEngine coins = playing(GameEngine.Mode.STAGES, 1);
        set(coins, "rowsSpawned", 3); set(coins, "distanceSinceSpawn", 10000f);
        coins.update(1.0 / 60);
        check(coins.coinVisible(0), "coin spawns after fourth row");
        Field xs = GameEngine.class.getDeclaredField("coinX"), ys = GameEngine.class.getDeclaredField("coinY");
        xs.setAccessible(true); ys.setAccessible(true);
        ((float[]) xs.get(coins))[0] = coins.rightPlayer().x;
        ((float[]) ys.get(coins))[0] = coins.rightPlayer().y;
        coins.rows().clear(); set(coins, "distanceSinceSpawn", 0f);
        coins.setPaused(true); coins.update(1.0 / 60);
        check(coins.coinVisible(0), "paused coin remains");
        coins.setPaused(false); coins.update(1.0 / 60);
        check(!coins.coinVisible(0) && coins.collectedCoins() == 1, "right ball collects");
        check(coins.consumeCoinEvents() == 1 && coins.consumeCoinEvents() == 0, "event delivered once");
        set(coins, "rowsSpawned", 7); set(coins, "distanceSinceSpawn", 10000f); coins.update(1.0 / 60);
        check(coins.coinVisible(0), "next coin spawns");
        ((float[]) xs.get(coins))[0] = coins.leftPlayer().x;
        ((float[]) ys.get(coins))[0] = coins.leftPlayer().y;
        coins.rows().clear(); set(coins, "distanceSinceSpawn", 0f); coins.update(1.0 / 60);
        check(coins.consumeCoinEvents() == 1 && coins.collectedCoins() == 2, "left ball collects");
        coins.startRun(); check(!coins.coinVisible(0) && coins.collectedCoins() == 0, "restart clears transient coins");
        for (GameEngine.Mode mode : new GameEngine.Mode[]{GameEngine.Mode.ENDLESS, GameEngine.Mode.PRACTICE}) {
            GameEngine noCoins = playing(mode, 1);
            for (int i = 0; i < 8; i++) { set(noCoins, "distanceSinceSpawn", 10000f); noCoins.update(1.0 / 60); }
            for (int i = 0; i < noCoins.coinSlots(); i++) check(!noCoins.coinVisible(i), "coins only in stages");
        }
        java.lang.reflect.Method sweep = GameEngine.class.getDeclaredMethod("sweptCircle",
                float.class, float.class, float.class, float.class, float.class);
        sweep.setAccessible(true);
        check((Boolean) sweep.invoke(null, -40f, 0f, 40f, 0f, 10f), "fast crossing collected");
        check(!(Boolean) sweep.invoke(null, -40f, 11f, 40f, 11f, 10f), "outside circle not collected");
        java.lang.reflect.Method speed = GameEngine.class.getDeclaredMethod("speedFor", float.class);
        speed.setAccessible(true);
        float previous = 0;
        for (int number = 2; number <= 5; number++) {
            GameEngine difficultyCheck = playing(GameEngine.Mode.STAGES, number);
            float value = (Float) speed.invoke(difficultyCheck, 8f);
            check(value > previous, "stage speeds strictly increase through stage 5");
            previous = value;
        }

        java.lang.reflect.Method hitRect = GameEngine.class.getDeclaredMethod("circleHitsRect",
                float.class, float.class, float.class, float.class, float.class, float.class, float.class);
        hitRect.setAccessible(true);
        check((Boolean) hitRect.invoke(null, 5f, 5f, 2f, 0f, 0f, 10f, 10f), "inside wall collides");
        check((Boolean) hitRect.invoke(null, 12f, 5f, 2f, 0f, 0f, 10f, 10f), "tangent collides");
        check(!(Boolean) hitRect.invoke(null, 12.1f, 5f, 2f, 0f, 0f, 10f, 10f), "outside edge does not collide");
        check(!(Boolean) hitRect.invoke(null, 12f, 12f, 2f, 0f, 0f, 10f, 10f), "outside corner does not collide");

        // Exercise the entire real spawn/scroll/finish pipeline at each stage and difficulty.
        // Neutralise collision geometry so this tests progression, not human touch accuracy.
        for (Difficulty difficulty : Difficulty.values()) {
            for (int number = 1; number <= 5; number++) {
                GameEngine run = new GameEngine();
                run.resize(360, 780, 1);
                run.setDifficulty(difficulty);
                run.configureRun(GameEngine.Mode.STAGES, number);
                run.startRun();
                boolean sawFinish = false;
                for (int tick = 0; tick < 60 * 180 && run.state() != GameEngine.State.GAME_OVER; tick++) {
                    for (ObstacleRow row : run.rows()) {
                        row.gapCount = 1; row.gapCenter[0] = 180; row.gapWidth[0] = 360;
                        row.wave = false; row.pulse = false;
                    }
                    run.update(1.0 / 60);
                    if (!Float.isNaN(run.finishY())) sawFinish = true;
                    check(getInt(run, "rowsSpawned") <= run.stageGoal(), "spawn count capped");
                    if (run.stageCompleted()) {
                        check(sawFinish && run.rowsCleared() == run.stageGoal(), "win only after all rows and finish");
                    }
                }
                check(run.stageCompleted() && sawFinish, "complete real stage " + number + " " + difficulty);
                check(run.consumeJustDied() && !run.consumeJustDied(), "one completion event");
            }
        }
        System.out.println("Practice, collision and stages PASS");
    }
}
