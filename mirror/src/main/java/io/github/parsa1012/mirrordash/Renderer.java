package io.github.parsa1012.mirrordash;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.DashPathEffect;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.RadialGradient;
import android.graphics.RectF;
import android.graphics.Shader;
import android.graphics.Typeface;

import java.util.List;

/**
 * All canvas drawing. Paints, shaders, glow sprites and the typefaces are built once per
 * theme, so nothing is allocated per frame. Colours come from {@link Theme} and the Persian
 * font (Vazirmatn, subsetted to the glyphs the game needs) is bundled in assets.
 */
public class Renderer {

    private static final float GRID_STEP_DP = 48f;
    private static final int GLOW_SIZE_PX = 160;
    private static final float COUNTDOWN_SIZE_DP = 84f;

    private final Typeface typeBold;
    private final Typeface typeRegular;

    private final Paint gridPaint = new Paint();
    private final Paint axisPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint rowFillPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint rowEdgePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint corePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint rimPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint trailPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint particlePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint glowPaint = new Paint(Paint.FILTER_BITMAP_FLAG);
    private final Paint backgroundPaint = new Paint();
    private final Paint scorePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint floaterPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint countdownPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint flashPaint = new Paint();
    private final Paint debugPaint = new Paint(Paint.ANTI_ALIAS_FLAG);

    private final RectF rowRect = new RectF();
    private final RectF gapRect = new RectF();
    private final RectF glowBounds = new RectF();
    private final Path rowPath = new Path();

    private Theme theme = Theme.of(true);
    private Bitmap blueGlow;
    private Bitmap redGlow;
    private Bitmap blueSphere;
    private Bitmap redSphere;
    /**
     * The grid, the centre axis and the flat background never change between frames, so they
     * are painted once into this bitmap and blitted in one call: that is the difference
     * between ~30 line draws per frame and one copy, which is what keeps the frame budget.
     */
    private Bitmap background;
    private int backgroundWidth;
    private int backgroundHeight;
    private boolean backgroundNight;
    private float density = 1f;
    private boolean ready;

    private int displayedScore = -1;
    private String scoreText = "0";
    private float easedScore;
    private long lastDrawNanos;
    private int displayedFps = -1;
    private String fpsText = "";

    public Renderer(Context context) {
        typeBold = load(context, "fonts/Vazirmatn-Bold.ttf", Typeface.BOLD);
        typeRegular = load(context, "fonts/Vazirmatn-Regular.ttf", Typeface.NORMAL);
    }

    /** Never let a missing/corrupt font asset take the game down. */
    static Typeface load(Context context, String asset, int style) {
        try {
            return Typeface.createFromAsset(context.getAssets(), asset);
        } catch (RuntimeException e) {
            return Typeface.create(Typeface.SANS_SERIF, style);
        }
    }

    public void setTheme(Theme theme) {
        this.theme = theme == null ? Theme.of(true) : theme;
        ready = false;
        if (density > 0f) {
            init();
        }
    }

    public Theme theme() {
        return theme;
    }

    public void setDensity(float density) {
        this.density = density > 0f ? density : 1f;
        init();
    }

    private void init() {
        gridPaint.setStyle(Paint.Style.STROKE);
        gridPaint.setColor(theme.grid);
        gridPaint.setStrokeWidth(Math.max(1f, density));

        axisPaint.setStyle(Paint.Style.STROKE);
        axisPaint.setColor(theme.axis);
        axisPaint.setStrokeWidth(Math.max(1f, density));
        float dash = 7f * density;
        axisPaint.setPathEffect(new DashPathEffect(new float[] {dash, dash * 1.6f}, 0f));

        rowFillPaint.setStyle(Paint.Style.FILL);
        rowFillPaint.setColor(theme.rowFill);

        rowEdgePaint.setStyle(Paint.Style.STROKE);
        rowEdgePaint.setColor(withAlpha(theme.rowEdge, 140));
        rowEdgePaint.setStrokeWidth(1.6f * density);

        corePaint.setStyle(Paint.Style.FILL);

        rimPaint.setStyle(Paint.Style.STROKE);
        rimPaint.setColor(Color.argb(120, 255, 255, 255));
        rimPaint.setStrokeWidth(1.4f * density);

        trailPaint.setStyle(Paint.Style.FILL);
        particlePaint.setStyle(Paint.Style.FILL);
        glowPaint.setAntiAlias(true);
        flashPaint.setStyle(Paint.Style.FILL);

        scorePaint.setColor(theme.scoreText);
        scorePaint.setTextSize(36f * density);
        scorePaint.setTypeface(typeBold);
        scorePaint.setTextAlign(Paint.Align.CENTER);

        floaterPaint.setTextSize(16f * density);
        floaterPaint.setTypeface(typeBold);
        floaterPaint.setTextAlign(Paint.Align.CENTER);

        countdownPaint.setColor(theme.scoreText);
        countdownPaint.setTextSize(COUNTDOWN_SIZE_DP * density);
        countdownPaint.setTypeface(typeBold);
        countdownPaint.setTextAlign(Paint.Align.CENTER);
        countdownPaint.setAntiAlias(true);

        debugPaint.setColor(theme.textMuted);
        debugPaint.setTextSize(11f * density);
        debugPaint.setTypeface(typeRegular);

        blueGlow = makeGlow(theme.playerBlue);
        redGlow = makeGlow(theme.playerRed);
        blueSphere = makeSphere(theme.playerBlue, false);
        redSphere = makeSphere(theme.playerRed, true);
        backgroundPaint.setFilterBitmap(false);
        backgroundPaint.setDither(false);
        // Dropped, not recycled: the render thread may still be painting with the old bitmap.
        background = null;
        ready = true;
    }

    public void draw(Canvas canvas, GameEngine engine, float fps, boolean showDebug) {
        if (!ready) {
            init();
        }
        final int width = canvas.getWidth();
        final int height = canvas.getHeight();

        long now = System.nanoTime();
        float dt = lastDrawNanos == 0L ? 0.016f : (now - lastDrawNanos) / 1_000_000_000f;
        lastDrawNanos = now;
        if (dt < 0f || dt > 0.1f) {
            dt = 0.016f;
        }

        drawBackground(canvas, width, height);

        canvas.save();
        canvas.translate(engine.shakeX(), engine.shakeY());

        drawRows(canvas, engine.rows(), width);
        drawParticles(canvas, engine);

        Player left = engine.leftPlayer();
        Player right = engine.rightPlayer();
        drawTrail(canvas, left);
        drawTrail(canvas, right);
        drawBody(canvas, left, blueGlow);
        drawBody(canvas, right, redGlow);

        drawFloaters(canvas, engine);
        canvas.restore();

        drawFlash(canvas, engine.flash(), width, height);
        if (engine.state() != GameEngine.State.ATTRACT) {
            drawScore(canvas, engine.score(), width, dt);
        }
        drawCountdown(canvas, engine, width, height);

        if (showDebug) {
            int roundedFps = Math.round(fps);
            if (roundedFps != displayedFps) {
                displayedFps = roundedFps;
                fpsText = roundedFps + " fps";
            }
            canvas.drawText(fpsText, 12f * density, height - 14f * density, debugPaint);
        }
    }

    /** Blits the cached background, rebuilding it when the surface or the theme changes. */
    private void drawBackground(Canvas canvas, int width, int height) {
        if (background == null || backgroundWidth != width || backgroundHeight != height
                || backgroundNight != theme.night) {
            background = Bitmap.createBitmap(width, height, Bitmap.Config.RGB_565);
            backgroundWidth = width;
            backgroundHeight = height;
            backgroundNight = theme.night;
            Canvas target = new Canvas(background);
            target.drawColor(theme.background);
            drawGrid(target, width, height);
        }
        canvas.drawBitmap(background, 0f, 0f, backgroundPaint);
    }

    /** Only ever drawn into the cached background bitmap, never directly on screen. */
    private void drawGrid(Canvas canvas, int width, int height) {
        float step = GRID_STEP_DP * density;
        for (float x = step - 2f * step; x < width + 2f * step; x += step) {
            canvas.drawLine(x, -2f * step, x, height + 2f * step, gridPaint);
        }
        for (float y = step - 2f * step; y < height + 2f * step; y += step) {
            canvas.drawLine(-2f * step, y, width + 2f * step, y, gridPaint);
        }
        canvas.drawLine(width * 0.5f, -2f * step, width * 0.5f, height + 2f * step, axisPaint);
    }

    /**
     * Each row is one continuous wall with its openings punched out (even-odd path).
     * Drawing the solid pieces separately made the row read as floating pills.
     */
    private void drawRows(Canvas canvas, List<ObstacleRow> rows, int width) {
        float outerCorner = 6f * density;
        for (int i = 0; i < rows.size(); i++) {
            ObstacleRow row = rows.get(i);
            float top = row.y;
            float bottom = row.y + row.height;
            if (bottom < -20f * density || top > canvas.getHeight() + 20f * density) {
                continue;
            }

            rowPath.reset();
            rowPath.setFillType(Path.FillType.EVEN_ODD);
            rowRect.set(0f, top, width, bottom);
            rowPath.addRoundRect(rowRect, outerCorner, outerCorner, Path.Direction.CW);

            float gapCorner = row.height * 0.5f;
            for (int g = 0; g < row.gapCount; g++) {
                float center = row.currentGapCenter(g);
                float half = row.gapWidth[g] * 0.5f;
                gapRect.set(center - half, top, center + half, bottom);
                rowPath.addRoundRect(gapRect, gapCorner, gapCorner, Path.Direction.CW);
            }

            canvas.drawPath(rowPath, rowFillPaint);
            canvas.drawPath(rowPath, rowEdgePaint);
        }
    }

    private void drawParticles(Canvas canvas, GameEngine engine) {
        for (int i = 0; i < engine.particleCount; i++) {
            float life = engine.particleLife[i];
            float maxLife = engine.particleMaxLife[i];
            float fraction = maxLife > 0f ? life / maxLife : 0f;
            int alpha = (int) (255f * fraction * fraction);
            if (alpha <= 4) {
                continue;
            }
            particlePaint.setColor(withAlpha(engine.particleColor[i], alpha));
            canvas.drawCircle(engine.particleX[i], engine.particleY[i],
                    engine.particleRadius[i] * (0.4f + 0.6f * fraction), particlePaint);
        }
    }

    private void drawFloaters(Canvas canvas, GameEngine engine) {
        for (int i = 0; i < engine.floaterCount; i++) {
            float fraction = engine.floaterLife[i] / engine.floaterMaxLife[i];
            int alpha = (int) (255f * Math.min(1f, fraction * 1.6f));
            floaterPaint.setColor(withAlpha(engine.floaterColor[i], alpha));
            canvas.drawText("+5", engine.floaterX[i], engine.floaterY[i], floaterPaint);
        }
    }

    private void drawFlash(Canvas canvas, float flash, int width, int height) {
        if (flash <= 0.01f) {
            return;
        }
        flashPaint.setColor(withAlpha(theme.playerRed, (int) (90f * flash)));
        canvas.drawRect(0f, 0f, width, height, flashPaint);
    }

    private void drawScore(Canvas canvas, int score, int width, float dt) {
        if (score < easedScore) {
            easedScore = score;
        }
        easedScore += (score - easedScore) * Math.min(1f, dt * 9f);
        int shown = Math.round(easedScore);
        if (shown != displayedScore) {
            displayedScore = shown;
            scoreText = Integer.toString(shown);
        }
        canvas.drawText(scoreText, width * 0.5f, 74f * density, scorePaint);
    }

    private void drawCountdown(Canvas canvas, GameEngine engine, int width, int height) {
        if (engine.state() != GameEngine.State.COUNTDOWN) {
            return;
        }
        float remaining = engine.countdown();
        if (remaining <= 0f) {
            return;
        }
        int value = (int) Math.ceil(remaining / 0.35f);
        float fraction = remaining - (value - 1) * 0.35f;
        fraction = Math.max(0f, Math.min(1f, fraction / 0.35f));
        countdownPaint.setAlpha((int) (90f + 165f * fraction));
        canvas.drawText(Integer.toString(value), width * 0.5f, height * 0.42f, countdownPaint);
        countdownPaint.setAlpha(255);
    }

    private void drawTrail(Canvas canvas, Player player) {
        for (int i = 0; i < player.trailCount; i++) {
            int index = (player.trailHead - i + Player.TRAIL_LENGTH) % Player.TRAIL_LENGTH;
            float fade = 1f - (i / (float) Player.TRAIL_LENGTH);
            int alpha = (int) (70f * fade * fade);
            if (alpha <= 0) {
                continue;
            }
            trailPaint.setColor(withAlpha(player.color, alpha));
            canvas.drawCircle(player.trailX[index], player.trailY[index],
                    player.radius * (0.55f + 0.35f * fade), trailPaint);
        }
    }

    private void drawBody(Canvas canvas, Player player, Bitmap glow) {
        float glowRadius = player.radius * 3.1f;
        glowBounds.set(player.x - glowRadius, player.y - glowRadius,
                player.x + glowRadius, player.y + glowRadius);
        canvas.drawBitmap(glow, null, glowBounds, glowPaint);

        glowBounds.set(player.x - player.radius, player.y - player.radius, player.x + player.radius, player.y + player.radius);
        canvas.drawBitmap(player.color == theme.playerBlue ? blueSphere : redSphere, null, glowBounds, glowPaint);
        canvas.drawCircle(player.x, player.y, player.radius, rimPaint);
    }

    private Bitmap makeSphere(int color, boolean mirror) {
        int size = 128;
        Bitmap bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(bitmap);
        Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        float x = mirror ? 80f : 48f;
        paint.setShader(new RadialGradient(x, 43f, 82f,
                new int[] {Color.WHITE, color, Color.rgb(Color.red(color) / 4, Color.green(color) / 4, Color.blue(color) / 4)},
                new float[] {0f, 0.34f, 1f}, Shader.TileMode.CLAMP));
        canvas.drawCircle(64f, 64f, 63f, paint);
        return bitmap;
    }

    private Bitmap makeGlow(int color) {
        Bitmap bitmap = Bitmap.createBitmap(GLOW_SIZE_PX, GLOW_SIZE_PX, Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(bitmap);
        float center = GLOW_SIZE_PX * 0.5f;
        Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        paint.setShader(new RadialGradient(center, center, center,
                new int[] {withAlpha(color, 200), withAlpha(color, 70), withAlpha(color, 0)},
                new float[] {0f, 0.42f, 1f}, Shader.TileMode.CLAMP));
        canvas.drawCircle(center, center, center, paint);
        return bitmap;
    }

    private static int withAlpha(int color, int alpha) {
        int clamped = alpha < 0 ? 0 : (alpha > 255 ? 255 : alpha);
        return (color & 0x00FFFFFF) | (clamped << 24);
    }
}
