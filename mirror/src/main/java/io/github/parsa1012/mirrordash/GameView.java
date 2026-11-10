package io.github.parsa1012.mirrordash;

import android.content.Context;
import android.graphics.Canvas;
import android.view.MotionEvent;
import android.view.SurfaceHolder;
import android.view.SurfaceView;

/**
 * Owns the render surface, the simulation thread and the touch input.
 *
 * <p>The simulation runs on a fixed 1/60s step fed by an accumulator (with the incoming
 * frame time clamped and a hard cap on steps per frame), so gameplay speed is identical on
 * 60, 90 and 120 Hz devices and a slow frame can never spiral into a longer one. The
 * renderer simply draws the latest simulated state.</p>
 */
public class GameView extends SurfaceView implements SurfaceHolder.Callback, Runnable {

    private static final double STEP_SECONDS = 1.0 / 60.0;
    private static final double MAX_FRAME_SECONDS = 0.25;
    private static final int MAX_STEPS_PER_FRAME = 5;
    private static final long FRAME_NANOS = 16_666_667L;

    private final SurfaceHolder surfaceHolder;
    private final GameEngine engine = new GameEngine();
    private final Renderer renderer = new Renderer();

    private Thread loopThread;
    private volatile boolean running;
    private volatile boolean restartRequested;
    private volatile float fps;

    private Runnable firstTouchListener;
    private GameOverListener gameOverListener;

    public interface GameOverListener {
        void onGameOver(int score, int rowsCleared);
    }

    public GameView(Context context) {
        super(context);
        surfaceHolder = getHolder();
        surfaceHolder.addCallback(this);
        setFocusable(true);
        setKeepScreenOn(true);
        renderer.setDensity(getResources().getDisplayMetrics().density);
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

    @Override
    public void surfaceCreated(SurfaceHolder holder) {
        start();
    }

    @Override
    public void surfaceChanged(SurfaceHolder holder, int format, int width, int height) {
        engine.resize(width, height, getResources().getDisplayMetrics().density);
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

    /** Asks the loop thread to reset the run on its next iteration. */
    public void restart() {
        restartRequested = true;
    }

    @Override
    public boolean onTouchEvent(MotionEvent event) {
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

    @Override
    public void run() {
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

            if (restartRequested) {
                restartRequested = false;
                engine.restart();
                accumulator = 0.0;
            }

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

            if (engine.consumeJustDied()) {
                final int score = engine.score();
                final int cleared = engine.rowsCleared();
                post(new Runnable() {
                    @Override
                    public void run() {
                        GameOverListener listener = gameOverListener;
                        if (listener != null) {
                            listener.onGameOver(score, cleared);
                        }
                    }
                });
            }

            Canvas canvas = null;
            try {
                canvas = surfaceHolder.lockCanvas();
                if (canvas != null) {
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
