package io.github.parsa1012.mirrordash;

import android.content.Context;
import android.graphics.Canvas;
import android.os.Build;
import android.os.Process;
import android.view.HapticFeedbackConstants;
import android.view.MotionEvent;
import android.view.SurfaceHolder;
import android.view.SurfaceView;

/**
 * Owns the render surface, the simulation thread, touch input and the audio/haptic feedback.
 *
 * <p>The simulation runs on a fixed 1/60s step fed by an accumulator (with the incoming frame
 * time clamped and a hard cap on steps per frame), so gameplay speed is identical on 60, 90
 * and 120 Hz devices and a slow frame can never spiral into a longer one.</p>
 *
 * <p>State changes requested by the UI thread are queued as flags and applied on the loop
 * thread, so the engine is only ever mutated from one thread.</p>
 */
public class GameView extends SurfaceView implements SurfaceHolder.Callback, Runnable {

    private static final double STEP_SECONDS = 1.0 / 60.0;
    private static final double MAX_FRAME_SECONDS = 0.25;
    private static final int MAX_STEPS_PER_FRAME = 5;
    private static final long FRAME_NANOS = 16_666_667L;

    private final SurfaceHolder surfaceHolder;
    private final GameEngine engine = new GameEngine();
    private final Renderer renderer;
    private final SoundPlayer sound;

    private Thread loopThread;
    private volatile boolean running;
    private volatile boolean startRequested;
    private volatile GameEngine.Mode requestedMode = GameEngine.Mode.ENDLESS;
    private volatile int requestedStage = 1;
    private volatile boolean attractRequested;
    private volatile int pauseRequest;
    private volatile float fps;

    private Runnable firstTouchListener;
    private GameOverListener gameOverListener;

    /** The surface was (re)created, so the next frame must be painted even while paused. */
    private boolean forceFrame = true;
    private boolean lastPaused;

    public interface GameOverListener {
        void onGameOver(int score, int rowsCleared, long millis);
    }

    public GameView(Context context) {
        super(context);
        surfaceHolder = getHolder();
        surfaceHolder.addCallback(this);
        setFocusable(true);
        setKeepScreenOn(true);
        renderer = new Renderer(context);
        renderer.setDensity(getResources().getDisplayMetrics().density);
        sound = new SoundPlayer(context);
    }

    public void setOnFirstTouchListener(Runnable listener) {
        this.firstTouchListener = listener;
    }

    public void setGameOverListener(GameOverListener listener) {
        this.gameOverListener = listener;
    }

    public GameEngine engine() {
        return engine;
    }

    public void setSoundEnabled(boolean enabled) {
        sound.setEnabled(enabled);
    }

    public void playUiClick() { sound.playClick(); }
    public void playUiMenu() { sound.playMenu(); }
    public void playUiUnlock() { sound.playUnlock(); }

    public void setSoundVolume(int percent) { sound.setVolume(percent); }
    public void setClearMarkers(boolean value) { renderer.setClearMarkers(value); }
    public void setAppearance(int ball, int background) { renderer.setAppearance(ball, background); }

    /** Switches the palette used by both the canvas and the bodies. */
    public void setTheme(Theme theme) {
        renderer.setTheme(theme);
        engine.applyTheme(theme);
    }

    public void setDifficulty(Difficulty difficulty) {
        engine.setDifficulty(difficulty);
    }

    /** Starts a real run (countdown, then hazards). Safe to call from the UI thread. */
    public void startRun(GameEngine.Mode mode, int stage) {
        requestedMode = mode;
        requestedStage = stage;
        startRequested = true;
    }

    /** Returns to the idle menu scene. Safe to call from the UI thread. */
    public void showAttract() {
        attractRequested = true;
    }

    public void pauseGame() {
        pauseRequest = 1;
    }

    public void resumeGame() {
        pauseRequest = 2;
    }

    @Override
    public void surfaceCreated(SurfaceHolder holder) {
        forceFrame = true;
        start();
    }

    @Override
    public void surfaceChanged(SurfaceHolder holder, int format, int width, int height) {
        engine.resize(width, height, getResources().getDisplayMetrics().density);
        forceFrame = true;
    }

    @Override
    public void surfaceDestroyed(SurfaceHolder holder) {
        stop();
    }

    public void start() {
        if (running) {
            return;
        }
        running = true;
        loopThread = new Thread(this, "mirror-game-loop");
        loopThread.start();
    }

    public void stop() {
        running = false;
        Thread thread = loopThread;
        loopThread = null;
        if (thread != null) {
            try {
                thread.join(1000L);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        }
    }

    /** Frees the SoundPool; the view cannot be reused afterwards. */
    public void release() {
        stop();
        sound.release();
    }

    @Override
    public boolean onTouchEvent(MotionEvent event) {
        // While the pause menu is up (or once the run is over) the finger must not drag the
        // bodies around, otherwise the pair teleports when play resumes.
        if (engine.isPaused() || engine.state() == GameEngine.State.GAME_OVER
                || engine.state() == GameEngine.State.DYING) {
            return true;
        }
        switch (event.getActionMasked()) {
            case MotionEvent.ACTION_DOWN:
                if (getParent() != null) {
                    getParent().requestDisallowInterceptTouchEvent(true);
                }
                Runnable listener = firstTouchListener;
                if (listener != null) {
                    firstTouchListener = null;
                    listener.run();
                }
                engine.setTouchX(event.getX());
                return true;
            case MotionEvent.ACTION_MOVE:
                engine.setTouchX(event.getX());
                return true;
            case MotionEvent.ACTION_POINTER_DOWN:
            case MotionEvent.ACTION_POINTER_UP:
                // Keep control on the primary pointer.
                engine.setTouchX(event.getX(0));
                return true;
            default:
                return true;
        }
    }

    private void applyPendingCommands() {
        if (attractRequested) {
            attractRequested = false;
            engine.enterAttract();
        }
        if (startRequested) {
            startRequested = false;
            engine.configureRun(requestedMode, requestedStage);
            engine.startRun();
        }
        int request = pauseRequest;
        if (request != 0) {
            pauseRequest = 0;
            engine.setPaused(request == 1);
        }
    }

    private void pumpFeedback() {
        if (engine.consumeImpact()) {
            sound.playCrash();
            post(new Runnable() {
                @Override
                public void run() {
                    performHapticFeedback(HapticFeedbackConstants.LONG_PRESS);
                }
            });
        }
        int passes = engine.consumeRowPasses();
        for (int i = 0; i < passes && i < 3; i++) {
            sound.playTick();
        }
    }

    /**
     * Hardware canvas when the platform has one: the rows are paths and the bodies are
     * scaled bitmaps, and both are dramatically cheaper through the GPU than through the
     * software rasteriser. Falls back silently on API 21-25.
     */
    private Canvas lockSurface() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                Canvas hardware = surfaceHolder.lockHardwareCanvas();
                if (hardware != null) {
                    return hardware;
                }
            } catch (RuntimeException ignored) {
                // Locked elsewhere or unsupported: use the software path below.
            }
        }
        return surfaceHolder.lockCanvas();
    }

    @Override
    public void run() {
        // Draw at display priority so a busy UI thread cannot starve the game loop.
        Process.setThreadPriority(Process.THREAD_PRIORITY_DISPLAY);
        long lastFrame = System.nanoTime();
        long nextDeadline = lastFrame;
        long fpsWindowStart = lastFrame;
        int framesInWindow = 0;
        double accumulator = 0.0;

        while (running) {
            long frameStart = System.nanoTime();
            double frameSeconds = (frameStart - lastFrame) / 1_000_000_000.0;
            lastFrame = frameStart;
            if (frameSeconds < 0.0) {
                frameSeconds = 0.0;
            } else if (frameSeconds > MAX_FRAME_SECONDS) {
                frameSeconds = MAX_FRAME_SECONDS;
            }
            accumulator += frameSeconds;

            applyPendingCommands();

            int steps = 0;
            while (accumulator >= STEP_SECONDS && steps < MAX_STEPS_PER_FRAME) {
                engine.update(STEP_SECONDS);
                accumulator -= STEP_SECONDS;
                steps++;
            }
            if (steps == MAX_STEPS_PER_FRAME) {
                // Dropped behind (e.g. after a hiccup): drop the backlog instead of spiralling.
                accumulator = 0.0;
            }

            pumpFeedback();

            if (engine.consumeJustDied()) {
                final int score = engine.score();
                final int cleared = engine.rowsCleared();
                final long millis = engine.runMillis();
                post(new Runnable() {
                    @Override
                    public void run() {
                        GameOverListener listener = gameOverListener;
                        if (listener != null) {
                            listener.onGameOver(score, cleared, millis);
                        }
                    }
                });
            }

            boolean pausedNow = engine.isPaused();
            boolean repaint = !pausedNow || pausedNow != lastPaused || forceFrame;
            lastPaused = pausedNow;
            Canvas canvas = null;
            if (repaint) {
                try {
                    canvas = lockSurface();
                    if (canvas != null) {
                        forceFrame = false;
                        renderer.draw(canvas, engine, fps, BuildConfig.DEBUG);
                    }
                } catch (Exception ignored) {
                    // Surface went away mid frame; retry on the next iteration.
                } finally {
                    if (canvas != null) {
                        try {
                            surfaceHolder.unlockCanvasAndPost(canvas);
                        } catch (Exception ignored) {
                            // Surface already destroyed.
                        }
                    }
                }
            }

            framesInWindow++;
            long windowLength = System.nanoTime() - fpsWindowStart;
            if (windowLength >= 500_000_000L) {
                fps = framesInWindow * 1_000_000_000f / windowLength;
                fpsWindowStart = System.nanoTime();
                framesInWindow = 0;
            }

            // Pace to a 60 Hz deadline grid so timing errors do not accumulate.
            nextDeadline += FRAME_NANOS;
            long now = System.nanoTime();
            long remaining = nextDeadline - now;
            if (remaining > 0L) {
                try {
                    Thread.sleep(remaining / 1_000_000L, (int) (remaining % 1_000_000L));
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    return;
                }
            } else if (-remaining > FRAME_NANOS) {
                nextDeadline = now;
            }
        }
    }
}
