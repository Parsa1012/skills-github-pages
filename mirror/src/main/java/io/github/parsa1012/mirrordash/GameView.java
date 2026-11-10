package io.github.parsa1012.mirrordash;

import android.content.Context;
import android.graphics.Canvas;
import android.view.MotionEvent;
import android.view.SurfaceHolder;
import android.view.SurfaceView;

/**
 * Owns the render surface, the game loop thread and the touch input.
 * The loop runs at a fixed 60 Hz pace and feeds a capped delta time to the engine.
 */
public class GameView extends SurfaceView implements SurfaceHolder.Callback, Runnable {

    private static final long FRAME_NANOS = 16_666_667L;
    private static final double MAX_STEP_SECONDS = 1.0 / 20.0;

    private final SurfaceHolder surfaceHolder;
    private final GameEngine engine = new GameEngine();
    private final Renderer renderer = new Renderer();

    private Thread loopThread;
    private volatile boolean running;
    private volatile float fps;

    private Runnable firstTouchListener;

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
        long fpsWindowStart = lastFrame;
        int frames = 0;

        while (running) {
            long frameStart = System.nanoTime();
            double dt = (frameStart - lastFrame) / 1_000_000_000.0;
            lastFrame = frameStart;
            if (dt < 0) {
                dt = 0;
            } else if (dt > MAX_STEP_SECONDS) {
                dt = MAX_STEP_SECONDS;
            }

            engine.update(dt);

            Canvas canvas = null;
            try {
                canvas = surfaceHolder.lockCanvas();
                if (canvas != null) {
                    renderer.draw(canvas, engine, fps, BuildConfig.DEBUG);
                }
            } catch (Exception ignored) {
                // Surface went away mid-frame; the next loop iteration retries.
            } finally {
                if (canvas != null) {
                    try {
                        surfaceHolder.unlockCanvasAndPost(canvas);
                    } catch (Exception ignored) {
                        // Ignore: surface already destroyed.
                    }
                }
            }

            frames++;
            long windowLength = System.nanoTime() - fpsWindowStart;
            if (windowLength >= 500_000_000L) {
                fps = frames * 1_000_000_000f / windowLength;
                fpsWindowStart = System.nanoTime();
                frames = 0;
            }

            long remaining = FRAME_NANOS - (System.nanoTime() - frameStart);
            if (remaining > 0) {
                try {
                    Thread.sleep(remaining / 1_000_000L, (int) (remaining % 1_000_000L));
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    return;
                }
            }
        }
    }
}
