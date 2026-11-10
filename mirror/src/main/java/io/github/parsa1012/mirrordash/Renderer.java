package io.github.parsa1012.mirrordash;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.DashPathEffect;
import android.graphics.Paint;
import android.graphics.RadialGradient;
import android.graphics.RectF;
import android.graphics.Shader;

/**
 * All drawing happens here. Paints, shaders and glow sprites are created once so
 * the game loop never allocates per frame.
 */
public class Renderer {

    private static final int COLOR_BG = Color.parseColor("#0B0F1A");
    private static final int COLOR_GRID = Color.parseColor("#141C2B");
    private static final int COLOR_AXIS = Color.parseColor("#2B3A55");
    private static final int COLOR_TEXT = Color.parseColor("#6E7681");

    private static final float GRID_STEP_DP = 48f;
    private static final int GLOW_SIZE_PX = 160;

    private final Paint gridPaint = new Paint();
    private final Paint axisPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint corePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint rimPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint trailPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint glowPaint = new Paint(Paint.FILTER_BITMAP_FLAG);
    private final Paint fpsPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final RectF glowBounds = new RectF();

    private Bitmap cyanGlow;
    private Bitmap pinkGlow;
    private float density = 1f;
    private boolean ready;

    public void setDensity(float density) {
        this.density = density > 0f ? density : 1f;
        init();
    }

    private void init() {
        gridPaint.setStyle(Paint.Style.STROKE);
        gridPaint.setColor(COLOR_GRID);
        gridPaint.setStrokeWidth(Math.max(1f, density));

        axisPaint.setStyle(Paint.Style.STROKE);
        axisPaint.setColor(COLOR_AXIS);
        axisPaint.setStrokeWidth(Math.max(1f, density));
        float dash = 7f * density;
        axisPaint.setPathEffect(new DashPathEffect(new float[] {dash, dash * 1.6f}, 0f));

        corePaint.setStyle(Paint.Style.FILL);

        rimPaint.setStyle(Paint.Style.STROKE);
        rimPaint.setColor(Color.argb(110, 255, 255, 255));
        rimPaint.setStrokeWidth(1.4f * density);

        trailPaint.setStyle(Paint.Style.FILL);

        fpsPaint.setColor(COLOR_TEXT);
        fpsPaint.setTextSize(11f * density);
        fpsPaint.setTypeface(android.graphics.Typeface.MONOSPACE);
        fpsPaint.setAntiAlias(true);

        glowPaint.setAntiAlias(true);

        cyanGlow = makeGlow(Color.parseColor("#22D3EE"));
        pinkGlow = makeGlow(Color.parseColor("#F472B6"));
        ready = true;
    }

    public void draw(Canvas canvas, GameEngine engine, float fps, boolean showDebug) {
        if (!ready) {
            init();
        }
        final int width = canvas.getWidth();
        final int height = canvas.getHeight();

        canvas.drawColor(COLOR_BG);

        // Background grid.
        float step = GRID_STEP_DP * density;
        for (float x = step; x < width; x += step) {
            canvas.drawLine(x, 0f, x, height, gridPaint);
        }
        for (float y = step; y < height; y += step) {
            canvas.drawLine(0f, y, width, y, gridPaint);
        }

        // Mirror axis.
        canvas.drawLine(width * 0.5f, 0f, width * 0.5f, height, axisPaint);

        Player left = engine.leftPlayer();
        Player right = engine.rightPlayer();

        drawTrail(canvas, left);
        drawTrail(canvas, right);
        drawBody(canvas, left, cyanGlow);
        drawBody(canvas, right, pinkGlow);

        if (showDebug) {
            canvas.drawText(String.format(java.util.Locale.US, "%.0f fps", fps),
                    12f * density, height - 14f * density, fpsPaint);
        }
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

        corePaint.setColor(player.color);
        canvas.drawCircle(player.x, player.y, player.radius, corePaint);
        canvas.drawCircle(player.x, player.y, player.radius, rimPaint);
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
