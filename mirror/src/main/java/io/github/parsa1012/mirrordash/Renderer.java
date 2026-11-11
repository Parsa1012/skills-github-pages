package io.github.parsa1012.mirrordash;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
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

    private final SkinArt skinArt;
    private final Typeface typeBold;
    private final Typeface typeRegular;

    private final Paint gridPaint = new Paint();
    private final Paint axisPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint rowFillPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint markerPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint rowEdgePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint skinPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
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
    private final Paint orbPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint coinTextPaint = new Paint(Paint.ANTI_ALIAS_FLAG);

    private final RectF rowRect = new RectF();
    private final RectF gapRect = new RectF();
    private final Path rowPath = new Path();
    private final Paint shimmerPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final RectF glowBounds = new RectF();

    private Theme theme = Theme.of(true);
    private Bitmap blueGlow;
    private Bitmap redGlow;
    private Bitmap blueSphere;
    private Bitmap redSphere;
    private volatile boolean clearMarkers;
    public void setClearMarkers(boolean value) { clearMarkers = value; }
    private volatile int ballPalette;
    private int cachedPalette = -1;
    public void setBallPalette(int id) { ballPalette = BallPalette.valid(id) ? id : 0; }
    private volatile int ballStyle;
    private volatile int sceneStyle;
    private int cachedSceneStyle = -1;
    private int cachedStage = -1;
    private final android.content.res.Resources resources;
    private Bitmap stageScene;
    private final Bitmap nightScene;
    private final Bitmap dayScene;
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
        skinArt = new SkinArt(context);
        resources = context.getResources();
        nightScene = BitmapFactory.decodeResource(context.getResources(), R.drawable.scene_night);
        dayScene = BitmapFactory.decodeResource(context.getResources(), R.drawable.scene_day);
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

    public void setAppearance(int ball, int scene) {
        ballStyle = Math.max(0, Math.min(2, ball));
        sceneStyle = Math.max(0, Math.min(2, scene));
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
        markerPaint.setColor(theme.night ? 0xFFEAF2FF : 0xFF173861);
        markerPaint.setStyle(Paint.Style.STROKE);
        markerPaint.setStrokeWidth(Math.max(1.5f, 1.6f * density));
        markerPaint.setStrokeCap(Paint.Cap.ROUND);

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

        cachedPalette = -1;
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
        if (cachedPalette != ballPalette) {
            int selected = ballPalette;
            int left = BallPalette.left(selected, theme), right = BallPalette.right(selected, theme);
            blueGlow = makeGlow(left); redGlow = makeGlow(right);
            blueSphere = makeSkinSphere(selected, left, false);
            redSphere = makeSkinSphere(selected, right, true);
            cachedPalette = selected;
        }
        final int width = canvas.getWidth();
        final int height = canvas.getHeight();

        long now = System.nanoTime();
        float dt = lastDrawNanos == 0L ? 0.016f : (now - lastDrawNanos) / 1_000_000_000f;
        lastDrawNanos = now;
        if (dt < 0f || dt > 0.1f) {
            dt = 0.016f;
        }

        int stage = engine.mode() == GameEngine.Mode.STAGES && engine.state() != GameEngine.State.ATTRACT ? engine.stageNumber() : 0;
        drawBackground(canvas, width, height, stage);

        canvas.save();
        canvas.translate(engine.shakeX(), engine.shakeY());

        int rowColor = stage == 2 ? 0xff745036 : stage == 3 ? 0xff204d6b : stage == 4 ? 0xff583b76 : stage == 5 ? 0xff304a82 : theme.rowFill;
        rowFillPaint.setColor(rowColor);
        boolean darkStage = stage >= 2;
        rowEdgePaint.setColor(darkStage ? 0xffc9e9ff : withAlpha(theme.rowEdge, 140));
        markerPaint.setColor(darkStage ? 0xffffffff : (theme.night ? 0xFFEAF2FF : 0xFF173861));
        markerPaint.setStrokeWidth((clearMarkers ? 3.5f : 1.6f) * density);
        drawRows(canvas, engine.rows(), width, darkStage, !engine.reducedEffects());
        drawFinishLine(canvas, engine, width);
        drawCoins(canvas, engine);
        if (!engine.reducedEffects()) drawParticles(canvas, engine);

        Player left = engine.leftPlayer();
        Player right = engine.rightPlayer();
        if (!engine.reducedEffects()) { drawTrail(canvas, left); drawTrail(canvas, right); }
        drawBody(canvas, left, blueGlow, blueSphere);
        drawBody(canvas, right, redGlow, redSphere);
        if (!engine.reducedEffects()) drawFloaters(canvas, engine);
        if (engine.impactTimer() > 0) {
            markerPaint.setColor(Color.WHITE);
            markerPaint.setStrokeWidth(3f * density);
            float x = engine.impactX(), y = engine.impactY(), r = 14f * density;
            canvas.drawCircle(x, y, r, markerPaint);
            canvas.drawLine(x-r, y-r, x+r, y+r, markerPaint);
            canvas.drawLine(x-r, y+r, x+r, y-r, markerPaint);
            markerPaint.setColor(theme.night ? 0xFFEAF2FF : 0xFF173861);
            markerPaint.setStrokeWidth(Math.max(1.5f, 1.6f * density));
        }
        canvas.restore();

        drawFlash(canvas, engine.flash(), width, height);
        if (engine.state() != GameEngine.State.ATTRACT) {
            scorePaint.setColor(stage >= 2 ? Color.WHITE : theme.scoreText);
            drawScore(canvas, engine.score(), width, dt);
        }
        if (engine.mode() == GameEngine.Mode.STAGES && engine.state() != GameEngine.State.ATTRACT) {
            debugPaint.setColor(stage >= 2 ? Color.WHITE : theme.textPrimary);
            debugPaint.setTextSize(15f * density);
            canvas.drawText(engine.rowsCleared() + " / " + engine.stageGoal(), 12f * density, height - 40f * density, debugPaint);
        }
        countdownPaint.setColor(stage >= 2 ? Color.WHITE : theme.scoreText);
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

    /** Gold coin with a high-contrast dollar sign; never affects obstacle geometry. */
    private void drawCoins(Canvas canvas, GameEngine engine) {
        for (int i = 0; i < engine.coinSlots(); i++) {
            if (!engine.coinVisible(i)) continue;
            float x = engine.coinX(i), y = engine.coinY(i), r = engine.coinRadius();
            if (y < -r * 3 || y > canvas.getHeight() + r * 3) continue;
            if (!engine.reducedEffects()) {
                orbPaint.setColor(0x44ffce33); canvas.drawCircle(x, y, r * 1.8f, orbPaint);
            }
            orbPaint.setColor(0xffffd34b); canvas.drawCircle(x, y, r, orbPaint);
            orbPaint.setStyle(Paint.Style.STROKE);
            orbPaint.setStrokeWidth(Math.max(1f, density));
            orbPaint.setColor(0xffa66a08); canvas.drawCircle(x, y, r * .82f, orbPaint);
            orbPaint.setStyle(Paint.Style.FILL);
            coinTextPaint.setColor(0xff6d4300);
            coinTextPaint.setTypeface(Typeface.DEFAULT_BOLD);
            coinTextPaint.setTextAlign(Paint.Align.CENTER);
            coinTextPaint.setTextSize(r * 1.45f);
            canvas.drawText("$", x, y - (coinTextPaint.ascent() + coinTextPaint.descent()) / 2f, coinTextPaint);
        }
    }

    /** A checkered finish travels with the world and is never a collision obstacle. */
    private void drawFinishLine(Canvas canvas, GameEngine engine, int width) {
        float y = engine.finishY();
        if (Float.isNaN(y) || y < -30f * density || y > canvas.getHeight() + 30f * density) return;
        float cell = 12f * density;
        for (int row = 0; row < 2; row++) {
            for (int col = 0; col * cell < width; col++) {
                rowFillPaint.setColor((row + col) % 2 == 0 ? Color.WHITE : 0xFF17213A);
                float x = col * cell;
                canvas.drawRect(x, y + row * cell, Math.min(width, x + cell), y + (row + 1) * cell, rowFillPaint);
            }
        }
    }

    /** Blits the cached background, rebuilding it when the surface or the theme changes. */
    private void drawBackground(Canvas canvas, int width, int height, int stage) {
        if (background == null || backgroundWidth != width || backgroundHeight != height
                || backgroundNight != theme.night || cachedSceneStyle != sceneStyle || cachedStage != stage) {
            background = Bitmap.createBitmap(width, height, Bitmap.Config.RGB_565);
            backgroundWidth = width;
            backgroundHeight = height;
            backgroundNight = theme.night;
            cachedSceneStyle = sceneStyle;
            if (cachedStage != stage) {
                if (stageScene != null) { stageScene.recycle(); stageScene = null; }
                int res = stage == 2 ? R.drawable.stage_desert : stage == 3 ? R.drawable.stage_city : stage == 4 ? R.drawable.stage_fantasy : stage == 5 ? R.drawable.stage_space : 0;
                if (res != 0) stageScene = BitmapFactory.decodeResource(resources, res);
                cachedStage = stage;
            }
            Canvas target = new Canvas(background);
            target.drawColor(theme.background);
            Bitmap scene = stageScene != null ? stageScene : (theme.night ? nightScene : dayScene);
            if (scene != null) {
                Paint backdropPaint = new Paint(Paint.FILTER_BITMAP_FLAG);
                target.drawBitmap(scene, null, new RectF(0, 0, width, height), backdropPaint);
            } else {
                drawGrid(target, width, height);
            }
            if (stageScene != null) target.drawColor(0x66050a15);
            if (stageScene == null && cachedSceneStyle > 0) {
                Paint accent = new Paint(Paint.ANTI_ALIAS_FLAG);
                int color = cachedSceneStyle == 1 ? 0xFF5595FF : 0xFFBD6EF5;
                int alpha = theme.night ? 56 : 35;
                float radius = width * 0.8f;
                for (int side = 0; side < 2; side++) {
                    float cx = side == 0 ? 0 : width;
                    accent.setShader(new RadialGradient(cx, height * .45f, radius,
                            new int[]{withAlpha(color, alpha), withAlpha(color, 0)}, null, Shader.TileMode.CLAMP));
                    target.drawCircle(cx, height * .45f, radius, accent);
                }
            }
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
    private void drawRows(Canvas canvas, List<ObstacleRow> rows, int width, boolean darkStage, boolean effects) {
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
                float half = row.currentGapWidth(g) * 0.5f;
                gapRect.set(center - half, top, center + half, bottom);
                rowPath.addRoundRect(gapRect, gapCorner, gapCorner, Path.Direction.CW);
            }

            canvas.drawPath(rowPath, rowFillPaint);
            canvas.drawPath(rowPath, rowEdgePaint);
            if (effects && row.shimmer) {
                // A subtle travelling glint confined to one solid segment; no gameplay changes.
                int segments = row.segments(width);
                int best = -1; float longest = 0f;
                for (int k = 0; k < segments; k++) {
                    float length = row.segmentEdges[k * 2 + 1] - row.segmentEdges[k * 2];
                    if (length > longest) { longest = length; best = k; }
                }
                if (best >= 0 && longest > 20f * density) {
                    float left = row.segmentEdges[best * 2], right = row.segmentEdges[best * 2 + 1];
                    float margin = Math.min(longest * .2f, 8f * density);
                    float phase = (float) ((Math.sin(row.y / (70f * density)) + 1.0) * .5);
                    float x = left + margin + (right - left - 2f * margin) * phase;
                    shimmerPaint.setColor(0x88ddfaff);
                    shimmerPaint.setStrokeWidth(2f * density);
                    canvas.drawLine(x, top + row.height * .25f, x, bottom - row.height * .25f, shimmerPaint);
                }
            }
            if ((row.wave || row.pulse) && top > canvas.getHeight() * .30f && top < canvas.getHeight() * .8f) {
                markerPaint.setColor(0xfffef8d9);
                canvas.drawLine(0, top - 3f * density, width, top - 3f * density, markerPaint);
                markerPaint.setColor(darkStage ? Color.WHITE : (theme.night ? 0xFFEAF2FF : 0xFF173861));
            }
            if (row.wave || row.pulse) {
                int count = row.segments(width);
                float bestLeft = 0f, bestRight = 0f;
                for (int k = 0; k < count; k++) {
                    float l = row.segmentEdges[2 * k], r = row.segmentEdges[2 * k + 1];
                    if (r - l > bestRight - bestLeft) { bestLeft = l; bestRight = r; }
                }
                if (bestRight - bestLeft >= 30f * density) {
                    float x = (bestLeft + bestRight) * .5f, y = (top + bottom) * .5f;
                    float h = 4f * density, w = 6f * density;
                    if (row.wave) { // side-facing chevrons: gaps slide sideways
                        canvas.drawLine(x - w, y, x - w + h, y - h, markerPaint);
                        canvas.drawLine(x - w, y, x - w + h, y + h, markerPaint);
                        canvas.drawLine(x + w, y, x + w - h, y - h, markerPaint);
                        canvas.drawLine(x + w, y, x + w - h, y + h, markerPaint);
                    } else { // vertical bars: opening breathes
                        canvas.drawLine(x - w / 2f, y - h, x - w / 2f, y + h, markerPaint);
                        canvas.drawLine(x + w / 2f, y - h, x + w / 2f, y + h, markerPaint);
                    }
                }
            }
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
            float radius = player.radius * (BallPalette.premium(ballPalette) ? .35f : .55f + .35f * fade);
            canvas.drawCircle(player.trailX[index], player.trailY[index], radius, trailPaint);
            if (BallPalette.premium(ballPalette) && i % 3 == 0) {
                trailPaint.setColor(withAlpha(0xffffffff, alpha * 2));
                canvas.drawCircle(player.trailX[index], player.trailY[index] - player.radius * .45f, radius * .3f, trailPaint);
            }
        }
    }

    private void drawBody(Canvas canvas, Player player, Bitmap glow, Bitmap sphere) {
        float glowRadius = player.radius * 3.1f;
        glowBounds.set(player.x - glowRadius, player.y - glowRadius,
                player.x + glowRadius, player.y + glowRadius);
        canvas.drawBitmap(glow, null, glowBounds, glowPaint);

        glowBounds.set(player.x - player.radius, player.y - player.radius, player.x + player.radius, player.y + player.radius);
        canvas.drawBitmap(sphere, null, glowBounds, glowPaint);
        int style = ballStyle;
        if (style > 0) {
            skinPaint.setStyle(Paint.Style.STROKE);
            skinPaint.setColor(Color.argb(style == 1 ? 125 : 180, 255, 255, 255));
            skinPaint.setStrokeWidth(Math.max(1f, density));
            if (style == 1) {
                canvas.drawCircle(player.x, player.y, player.radius * .74f, skinPaint);
            } else {
                glowBounds.set(player.x - player.radius * .79f, player.y - player.radius * .42f,
                        player.x + player.radius * .79f, player.y + player.radius * .42f);
                canvas.drawOval(glowBounds, skinPaint);
                canvas.drawCircle(player.x, player.y, player.radius * .55f, skinPaint);
            }
        }
    }

    /** Prepare the masked image once per palette, never clip or tessellate during gameplay. */
    private Bitmap makeSkinSphere(int id, int color, boolean mirror) {
        Bitmap sphere = makeSphere(color, mirror);
        Bitmap result = Bitmap.createBitmap(128, 128, Bitmap.Config.ARGB_8888);
        Canvas target = new Canvas(result);
        target.save();
        target.clipPath(skinArt.outline(id, 64f, 64f, 63f));
        target.drawBitmap(sphere, 0, 0, glowPaint);
        skinArt.image(target, id, 64f, 64f, 63f);
        target.restore();
        Paint outline = new Paint(Paint.ANTI_ALIAS_FLAG);
        outline.setStyle(Paint.Style.STROKE); outline.setColor(0x99ffffff); outline.setStrokeWidth(2f);
        target.drawPath(skinArt.outline(id, 64f, 64f, 63f), outline);
        sphere.recycle();
        return result;
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
