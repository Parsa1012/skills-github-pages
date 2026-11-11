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
        ObstacleRow cleared = new ObstacleRow();
        cleared.begin(stage.leftPlayer().y + stage.leftPlayer().radius + 1, 28);
        stage.rows().add(cleared);
        stage.update(1.0 / 60);
        check(stage.stageCompleted() && stage.state() == GameEngine.State.GAME_OVER, "stage completion");
        check(stage.consumeJustDied() && !stage.consumeJustDied(), "single end event");
        stage.startRun();
        check(!stage.stageCompleted(), "reset stage state");
        System.out.println("Practice, collision and stages PASS");
    }
}
