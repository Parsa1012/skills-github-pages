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
        GameEngine noPowers = playing(GameEngine.Mode.ENDLESS, 5);
        check(!noPowers.activatePower(GameEngine.POWER_SHIELD), "no powers in endless");
        GameEngine shield = playing(GameEngine.Mode.STAGES, 1);
        check(!shield.activatePower(GameEngine.POWER_SLOW), "slow locked in stage 1");
        shield.setPaused(true);
        check(!shield.activatePower(GameEngine.POWER_SHIELD), "no activation while paused");
        shield.setPaused(false);
        check(shield.activatePower(GameEngine.POWER_SHIELD) && !shield.activatePower(GameEngine.POWER_SHIELD), "shield once");
        wall = new ObstacleRow(); wall.begin(shield.leftPlayer().y - 10, 28); shield.rows().add(wall);
        shield.update(1.0 / 60);
        check(shield.state() == GameEngine.State.PLAYING && !shield.shieldArmed(), "shield saves exactly one hit");
        shield.update(1.0 / 60);
        check(shield.state() == GameEngine.State.PLAYING, "saved obstacle does not instantly hit again");
        shield.rows().clear();
        wall = new ObstacleRow(); wall.begin(shield.leftPlayer().y - 10, 28); shield.rows().add(wall);
        shield.update(1.0 / 60);
        check(shield.state() == GameEngine.State.DYING, "second obstacle is lethal");
        shield.startRun(); set(shield, "state", GameEngine.State.PLAYING);
        check(shield.activatePower(GameEngine.POWER_SHIELD), "power reset on restart");

        GameEngine slow = playing(GameEngine.Mode.STAGES, 2);
        ObstacleRow sliding = new ObstacleRow(); sliding.begin(0, 28); sliding.setGap(0, 180, 360); slow.rows().add(sliding);
        check(slow.activatePower(GameEngine.POWER_SLOW), "slow unlocked in stage 2");
        slow.setPaused(true); float before = slow.slowRemaining(); slow.update(1);
        check(slow.slowRemaining() == before, "pause freezes power timer");
        slow.setPaused(false); slow.update(1.0 / 60);
        float slowDistance = sliding.y;
        GameEngine normal = playing(GameEngine.Mode.STAGES, 2);
        ObstacleRow baseline = new ObstacleRow(); baseline.begin(0, 28); baseline.setGap(0, 180, 360); normal.rows().add(baseline);
        normal.update(1.0 / 60);
        check(slowDistance > 0 && slowDistance < baseline.y * .6f, "slow reduces world speed");
        check(!slow.activatePower(GameEngine.POWER_SLOW), "slow is single use");
        check(!slow.activatePower(GameEngine.POWER_GUIDE), "guide locked until stage 3");

        GameEngine guide = playing(GameEngine.Mode.STAGES, 3);
        ObstacleRow split = new ObstacleRow(); split.begin(100, 28);
        split.setGap(0, 110, 80); split.setGap(1, 250, 80); guide.rows().add(split);
        float[] bounds = new float[2];
        check(!guide.guideWindow(bounds) && guide.activatePower(GameEngine.POWER_GUIDE), "guide must be activated");
        check(guide.guideWindow(bounds), "guide finds common safe opening");
        check(bounds[0] >= 86 && bounds[1] <= 134 && bounds[0] <= bounds[1], "guide accounts for both visible radii");
        split.waveOffset = 10;
        check(guide.guideWindow(bounds) && bounds[0] >= 96 && bounds[1] <= 124, "guide reflects current moving-gap positions");
        guide.setPaused(true); before = guide.guideRemaining(); guide.update(1);
        check(guide.guideRemaining() == before, "guide pauses");
        guide.setPaused(false);
        for (int i = 0; i < 300; i++) { guide.rows().clear(); set(guide, "distanceSinceSpawn", 0f); guide.update(1.0 / 60); }
        check(guide.guideRemaining() == 0 && !guide.guideWindow(bounds), "guide expires");

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
